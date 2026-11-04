// Bộ lập lịch notify (spec P6b §2–§3). Chu kỳ 15 phút: dọn, giữ thiết bị
// (server_kinds, lease), lượt `due` (bù sau khi khởi động lại) và lượt
// `upcoming` (xếp giờ vào hàng đợi). Nhịp 1 phút: người nào tới giờ thì đọc lại
// dữ liệu MỚI và chạy lượt `due`. Nội dung luôn do helper tính lúc gửi; quá
// `validUntil` thì không gửi (kiểm lại ngay trước MỖI lần gửi, kể cả lần đầu).
//
// Không trùng: mỗi lần gửi trước hết GIÀNH một dòng push_deliveries có id cố
// định (deliveryIdFor, cùng công thức với dòng giành trước của đăng ký).
// RECORD_NOT_UNIQUE nghĩa là đã có người giành: bỏ qua. `sent_at` chỉ ghi sau
// khi push service nhận.
//
// Dòng đã giành mà không gửi được (T11a(3)):
// - chắc chắn CHƯA tới push service (429/5xx hết lượt hay hoãn, quá hạn/lease
//   trước lần gửi, auth, lỗi thiết bị, kênh chưa có, options/tin hỏng) → xoá
//   dòng, để nhịp hay chu kỳ sau giành lại khi mục còn hiệu lực;
// - không rõ (mạng, hết giờ, lỗi nội bộ, sender trả kết quả lạ) → GIỮ dòng: thà
//   thiếu một lần còn hơn gửi hai lần (★10). Dòng có sent_at rỗng nên không bao
//   giờ hiện "Đã gửi".
//
// Thử lại 429/5xx: tối đa hai lần (★10). Chờ ≤ MAX_INCHAIN_RETRY_MS thì ngủ ngay
// trong chuỗi; dài hơn thì nhả dòng và hẹn nhịp phút sau (sau Retry-After) giành
// lại. Chờ mà quá validUntil thì thôi. Sau một 429/5xx, các lần gửi còn lại tới
// cùng push host trong lượt này bị bỏ qua (ngắt theo host) và hẹn nhịp sau.
//
// Nhật ký chỉ có băm id người dùng và 8 ký tự đầu id thiết bị; không bao giờ
// có endpoint, khoá, tiêu đề hay nội dung.

import { deliveryIdFor, serverKindsFor } from './devices.mjs';
import { hashUserId } from './log.mjs';
import {
  AUTH_WINDOW_MS, CYCLE_MS, DAILY_CAP, DELIVERY_KEEP_DAYS, FAILURES_TO_PRUNE, HORIZON_MS, LEASE_MARGIN_MS, LEASE_MS,
  LEASE_RENEW_BELOW_MS, MAX_INCHAIN_RETRY_MS, RETRY_FLOORS_MS, STALE_DEVICE_DAYS, TICK_MS, USER_CONCURRENCY,
} from './limits.mjs';
import { validInfo } from './planner.mjs';
import { buildPlanRequest } from './requests.mjs';
import { pushTopic, pushUrgency, ttlSeconds } from './webpush.mjs';

const DAY_MS = 86_400_000;
// Lỗi không rõ đã tới push service hay chưa: giữ dòng đã giành.
const AMBIGUOUS = new Set(['network', 'timeout', 'internal', 'bad_result']);

/// Giờ Directus (có thể thiếu đuôi múi) thành ms UTC, hoặc NaN.
function ms(value) {
  if (typeof value !== 'string' || value === '') return Number.NaN;
  return Date.parse(/(?:Z|[+-]\d\d:?\d\d)$/i.test(value) ? value : `${value}Z`);
}
const iso = (t) => new Date(t).toISOString();
const short = (deviceId) => String(deviceId).slice(0, 8);
const kindsOf = (d) => (Array.isArray(d.server_kinds) ? d.server_kinds : []);
const sameKinds = (a, b) => a.length === b.length && a.every((k) => b.includes(k));

/// Push host của thiết bị (cho bộ ngắt theo host và cờ auth); không bao giờ ghi log.
function hostOf(device) {
  try {
    return new URL(device.endpoint).host;
  } catch {
    return `channel:${device.channel}`;
  }
}

function groupBy(list, key) {
  const out = new Map();
  for (const x of list) {
    const k = key(x);
    if (!out.has(k)) out.set(k, []);
    out.get(k).push(x);
  }
  return out;
}

/// Chạy [fn] trên từng phần tử, tối đa [limit] cùng lúc.
async function eachLimited(list, limit, fn) {
  let next = 0;
  const worker = async () => {
    while (next < list.length) await fn(list[next++]);
  };
  await Promise.all(Array.from({ length: Math.min(limit, list.length) }, worker));
}

export function createScheduler({
  directus, planner, senders, config, now = () => new Date(), log = () => {},
  setInterval = globalThis.setInterval, clearInterval = globalThis.clearInterval,
  sleep = (t) => new Promise((r) => setTimeout(r, t)), userConcurrency = USER_CONCURRENCY,
}) {
  let chain = Promise.resolve();
  const waitingRun = { cycle: null, tick: null }; // việc đã xếp nhưng chưa chạy: gộp lời gọi trùng
  let stopped = false;
  let timers = [];
  let lastCycleAt = null;
  let lastInfo = null;
  const authAt = new Map(); // push host -> lần cuối trả 401/403 (ms)
  // deliveryId -> { used, notBefore, validUntil }: lần thử lại đã dùng của mục bị hoãn.
  const retries = new Map();
  const queue = new Map(); // userId -> giờ (ms UTC) tăng dần trong 24 giờ tới
  const t = () => now().getTime();

  /// Mọi việc chạy trên MỘT chuỗi promise, nên chu kỳ và nhịp không bao giờ chồng nhau.
  function enqueue(name, fn) {
    if (waitingRun[name]) return waitingRun[name];
    const p = chain.then(async () => {
      waitingRun[name] = null;
      if (stopped) return;
      try {
        await fn();
      } catch (e) {
        log({ event: `${name}_failed`, error: e?.code ?? e?.name ?? 'error' });
      }
    });
    waitingRun[name] = p;
    chain = p;
    return p;
  }

  /// Hẹn người [userId] cho nhịp phút ở [times] (gộp, tăng dần, không trùng).
  function requeue(userId, ...times) {
    const merged = new Set([...(queue.get(userId) ?? []), ...times]);
    queue.set(userId, [...merged].sort((a, b) => a - b));
  }

  // ─── Đọc dữ liệu một người (một lần cho cả hai lượt) ──────────────────────

  async function load(userId, info) {
    const settings = await directus.readSettings(userId, info.settingsFields);
    if (!settings) return null; // ★6: chưa có dòng cài đặt thì không gửi gì
    const since = iso(t() - DELIVERY_KEEP_DAYS * DAY_MS);
    const [data, deliveries] = await Promise.all([
      directus.readUserData(userId, info.fields),
      directus.deliveriesOfUser(userId, since),
    ]);
    return { settings, data, deliveries: [...(deliveries ?? [])] };
  }

  /// Thiết bị server của người đó, đọc MỚI (seed, mode, lease hiện tại); bỏ máy
  /// sắp bị dọn (lỗi ≥ 5, lâu không thấy).
  async function freshDevices(userId, nowMs) {
    const staleBefore = nowMs - STALE_DEVICE_DAYS * DAY_MS;
    return ((await directus.devicesOfUser(userId)) ?? []).filter((d) => d.user === userId && d.mode === 'server'
      && (d.failure_count ?? 0) < FAILURES_TO_PRUNE && !(ms(d.last_seen_at) < staleBefore));
  }

  /// Gọi helper cho một múi: `{ items }`, `'bad_tz'`, hoặc null (đã log).
  async function planZone(userId, tz, mode, loaded, nowUtc = now().toISOString()) {
    let reply;
    try {
      reply = await planner.plan(buildPlanRequest({
        userId, nowUtc, tz, mode,
        settings: loaded.settings, deliveries: loaded.deliveries, data: loaded.data,
      }));
    } catch (e) {
      log({ event: 'plan_failed', user: hashUserId(userId), mode, error: e?.code ?? e?.name ?? 'error' });
      return null;
    }
    if (reply?.ok === true && Array.isArray(reply.items)) return { items: reply.items };
    if (reply?.error === 'bad_tz') return 'bad_tz';
    log({ event: 'plan_failed', user: hashUserId(userId), mode, error: reply?.error ?? 'bad_reply' });
    return null;
  }

  async function planAll(userId, zones, mode, loaded) {
    const out = new Map();
    for (const tz of zones.keys()) out.set(tz, await planZone(userId, tz, mode, loaded));
    return out;
  }

  /// Helper không nhận múi của máy: máy đó không còn loại nào do server lo
  /// (quay về lịch cục bộ khi lease nó thấy hết hạn). Máy khác vẫn chạy.
  async function dropBadZone(devices) {
    for (const d of devices) {
      if (kindsOf(d).length === 0) continue;
      await directus.updateDevice(d.id, { server_kinds: [] });
      d.server_kinds = [];
      log({ event: 'bad_tz', device: short(d.id) });
    }
  }

  // ─── Gửi ─────────────────────────────────────────────────────────────────

  /// Còn được gửi lúc [nowMs]: lease còn (trừ biên 5 phút) và at ≤ now < validUntil.
  const sendable = (device, item, nowMs) => nowMs < ms(device.lease_until) - LEASE_MARGIN_MS
    && ms(item.atUtc) <= nowMs && nowMs < ms(item.validUntilUtc);

  const eligible = (device, item, nowMs) => !device.removed && device.mode === 'server'
    && kindsOf(device).includes(item.kind) && sendable(device, item, nowMs);

  /// Gửi, thử lại 429/5xx theo ★10. Kết quả lạ (không phải đối tượng) thành
  /// failed 'bad_result' (không rõ đã gửi chưa).
  async function attemptSend(sender, device, message, item, deliveryId, run) {
    const options = () => ({ ttlSeconds: ttlSeconds(item.validUntilUtc, now()), topic: pushTopic(item.kind, item.key), urgency: pushUrgency(item.kind) });
    const validUntil = ms(item.validUntilUtc);
    let used = retries.get(deliveryId)?.used ?? 0;
    retries.delete(deliveryId);
    for (;;) {
      // Lần giành (hay lần chờ) có thể lâu: kiểm lại hạn và lease ngay trước MỖI lần gửi.
      if (!sendable(device, item, t())) return { status: 'expired' };
      const result = await sender.send(device, message, options());
      if (result === null || typeof result !== 'object' || typeof result.status !== 'string') {
        return { status: 'failed', code: 'bad_result', deviceFault: false };
      }
      if (result.status !== 'retry') return result;
      run.brokenHosts.add(hostOf(device));
      if (used >= RETRY_FLOORS_MS.length) return { status: 'exhausted', code: result.code };
      const delay = Math.max(RETRY_FLOORS_MS[used], Number.isFinite(result.retryAfterMs) ? result.retryAfterMs : 0);
      used += 1;
      const at = t() + delay;
      if (at >= validUntil) return { status: 'expired', code: result.code }; // chờ xong thì đã hết hạn: không chờ
      if (delay > MAX_INCHAIN_RETRY_MS) {
        retries.set(deliveryId, { used, notBefore: at, validUntil });
        return { status: 'deferred', code: result.code, at };
      }
      await sleep(delay);
    }
  }

  async function release(deliveryId) {
    try {
      await directus.deleteDelivery(deliveryId);
    } catch {
      // Không xoá được: dòng nằm lại, tệ nhất là thiếu một lần gửi.
    }
  }

  async function deliver(userId, device, item, deliveryId, loaded, run) {
    const message = {
      v: 1, deliveryId, notificationId: item.id, kind: item.kind, key: item.key,
      title: item.title, body: item.body, payload: item.payload, ackUrl: `${config.publicUrl}/push/ack`,
    };
    const sender = senders.senderFor(device.channel);
    const result = sender
      ? await attemptSend(sender, device, message, item, deliveryId, run)
      : { status: 'failed', code: 'unsupported_channel', deviceFault: false };
    const { status } = result;
    log({ event: 'push', user: hashUserId(userId), device: short(device.id), kind: item.kind, status, code: result.code ?? null });

    if (status === 'sent') {
      const at = now().toISOString();
      await directus.updateDelivery(deliveryId, { sent_at: at });
      await directus.updateDevice(device.id, { last_success_at: at, failure_count: 0 });
      device.failure_count = 0;
      loaded.deliveries.push({ id: deliveryId, user: userId, kind: item.kind, key: item.key, at: item.atUtc, sent_at: at });
      return;
    }
    if (status === 'gone') {
      await directus.deleteDevices([device.id]);
      device.removed = true;
      return;
    }
    if (status === 'failed' && result.deviceFault === true) {
      const failures = (device.failure_count ?? 0) + 1;
      if (failures >= FAILURES_TO_PRUNE) {
        await directus.deleteDevices([device.id]);
        device.removed = true;
      } else {
        await directus.updateDevice(device.id, { failure_count: failures });
        device.failure_count = failures;
      }
      await release(deliveryId);
      return;
    }
    // Lỗi phía server hoặc tạm thời: không bao giờ đụng thiết bị.
    if (status === 'failed' && result.code === 'auth') {
      authAt.set(hostOf(device), t());
      log({
        event: 'push_auth_failing', level: 'error', device: short(device.id),
        message: 'push service từ chối VAPID (401/403): kiểm khoá VAPID của dịch vụ',
      });
    }
    if (status === 'failed' && AMBIGUOUS.has(result.code)) return; // giữ dòng: gửi tối đa một lần
    await release(deliveryId);
    if (status === 'deferred') requeue(userId, result.at);
  }

  /// Lượt `due`: gửi mục đến hạn tới từng máy đủ điều kiện, giành trước.
  async function sendDue(userId, zones, plans, loaded, run) {
    const dayAgo = t() - DAY_MS;
    // ★8: chỉ dòng ĐÃ GỬI (sent_at) trong 24 giờ; dòng giành trước của đăng ký không tính.
    const counted = new Set(loaded.deliveries
      .filter((d) => d.sent_at != null && ms(d.sent_at) > dayAgo)
      .map((d) => `${d.kind}|${d.key}`));
    const known = new Set(loaded.deliveries.map((d) => d.id));
    for (const [tz, devices] of zones) {
      const plan = plans.get(tz);
      if (!plan || plan === 'bad_tz') continue;
      for (const item of plan.items) {
        for (const device of devices) {
          if (!eligible(device, item, t())) continue;
          const deliveryId = deliveryIdFor(device.id, item.kind, item.key);
          if (known.has(deliveryId)) continue; // đã giành (kể cả giành trước của đăng ký)
          const pending = retries.get(deliveryId);
          if (pending && pending.notBefore > t()) {
            requeue(userId, pending.notBefore); // chưa qua Retry-After: không giành
            continue;
          }
          if (run.brokenHosts.has(hostOf(device))) {
            requeue(userId, t() + 1); // host vừa 429/5xx: để nhịp phút sau
            continue;
          }
          const pair = `${item.kind}|${item.key}`;
          if (!counted.has(pair) && counted.size >= DAILY_CAP) {
            log({ event: 'cap_reached', user: hashUserId(userId), kind: item.kind });
            continue;
          }
          // Chạy đua đã chấp nhận (T11a(3)): nếu đăng ký giành trước (shownToday) đúng
          // lúc ta đang giữ dòng này, nó nhận RECORD_NOT_UNIQUE và bỏ qua; nếu sau đó
          // ta nhả dòng (chắc chắn chưa gửi), lượt sau có thể gửi lại mục máy đã tự hiện.
          // Hẹp (hai yêu cầu trong cùng vài giây) và tệ nhất là một thông báo trùng.
          const claimed = await directus.claimDelivery({
            id: deliveryId, user: userId, device: device.id, notification_id: item.id,
            kind: item.kind, key: item.key, title: item.title, body: item.body, at: item.atUtc, sent_at: null,
          });
          known.add(deliveryId);
          if (!claimed) continue;
          counted.add(pair);
          await deliver(userId, device, item, deliveryId, loaded, run);
        }
      }
    }
  }

  // ─── Chu kỳ ──────────────────────────────────────────────────────────────

  /// Giữ thiết bị: server_kinds theo vân tay helper (rỗng nếu múi hỏng), và
  /// gia hạn lease khi còn dưới 5 giờ cho máy khoẻ ở múi mà lượt due LẬP ĐƯỢC
  /// (có dòng cài đặt và helper trả ok). Không lập được thì không gia hạn: lease
  /// hết và app tự lo như P6a, thay vì cả hai bên cùng im (T11a(1), T11b).
  /// Một PATCH mỗi máy, chỉ khi cần.
  async function maintain(devices, badZones, okZones, info, nowMs) {
    for (const d of devices) {
      const bad = badZones.has(d.timezone);
      const kinds = bad ? [] : serverKindsFor({ seedFingerprint: d.seed_fingerprint, enabled: config.enabled, helperFingerprint: info.fingerprint });
      const patch = {};
      if (!sameKinds(kindsOf(d), kinds)) patch.server_kinds = kinds;
      const lease = ms(d.lease_until);
      if (okZones.has(d.timezone) && kinds.length > 0 && (d.failure_count ?? 0) === 0 && !(lease - nowMs >= LEASE_RENEW_BELOW_MS)) {
        patch.lease_until = iso(nowMs + LEASE_MS);
      }
      if (Object.keys(patch).length === 0) continue;
      await directus.updateDevice(d.id, patch);
      Object.assign(d, patch);
      if (bad && patch.server_kinds) log({ event: 'bad_tz', device: short(d.id) });
    }
  }

  async function cycleUser(userId, info, run) {
    const nowMs = t();
    queue.delete(userId); // dựng lại từ đầu; lượt due bên dưới hẹn lại các mục đang chờ thử lại
    const devices = await freshDevices(userId, nowMs);
    if (devices.length === 0) return;
    const zones = groupBy(devices, (d) => d.timezone);
    const loaded = await load(userId, info);
    const due = loaded ? await planAll(userId, zones, 'due', loaded) : new Map();
    const badZones = new Set([...due].filter(([, r]) => r === 'bad_tz').map(([tz]) => tz));
    const okZones = new Set([...due].filter(([, r]) => r !== null && r !== 'bad_tz').map(([tz]) => tz));
    await maintain(devices, badZones, okZones, info, nowMs);
    if (!loaded) return;
    await sendDue(userId, zones, due, loaded, run);

    // Lượt upcoming lập từ ĐẦU chu kỳ, không phải sau lượt due (có thể đã chờ
    // thử lại): mục tới hạn trong lúc đó vẫn vào hàng đợi và nhịp phút kế tiếp
    // gửi ngay. Upcoming chỉ quyết định KHI NÀO; lượt due lúc đó tính lại từ dữ liệu mới.
    const times = [];
    for (const [tz, zoneDevices] of zones) {
      if (badZones.has(tz)) continue;
      const plan = await planZone(userId, tz, 'upcoming', loaded, iso(nowMs));
      if (!plan || plan === 'bad_tz') continue;
      const live = zoneDevices.filter((d) => !d.removed && d.mode === 'server');
      for (const it of plan.items) {
        const at = ms(it.atUtc);
        if (at > nowMs && at <= nowMs + HORIZON_MS && live.some((d) => kindsOf(d).includes(it.kind))) times.push(at);
      }
    }
    if (times.length > 0) requeue(userId, ...times);
  }

  async function runCycle() {
    const nowMs = t();
    try {
      await directus.deleteDeliveriesBefore(iso(nowMs - DELIVERY_KEEP_DAYS * DAY_MS));
    } catch (e) {
      log({ event: 'prune_failed', error: e?.code ?? 'error' });
    }
    for (const [id, r] of retries) if (r.validUntil <= nowMs) retries.delete(id);
    if (!config.enabled) {
      // Công tắc tắt: không gửi, không gia hạn; lease cũ hết hạn và app quay về cục bộ.
      queue.clear();
      retries.clear();
      lastCycleAt = now();
      return;
    }

    const listed = ((await directus.listServerDevices()) ?? []).filter((d) => d.mode === 'server');
    const staleBefore = nowMs - STALE_DEVICE_DAYS * DAY_MS;
    const doomed = listed.filter((d) => (d.failure_count ?? 0) >= FAILURES_TO_PRUNE || ms(d.last_seen_at) < staleBefore);
    if (doomed.length > 0) {
      try {
        await directus.deleteDevices(doomed.map((d) => d.id));
      } catch (e) {
        log({ event: 'prune_failed', error: e?.code ?? 'error' });
      }
    }
    const live = listed.filter((d) => !doomed.includes(d));

    let info = null;
    try {
      info = await planner.info();
    } catch {
      info = null;
    }
    if (!validInfo(info)) {
      // Không gia hạn, không gửi: lease hết hạn thì app tự lo như P6a.
      log({ event: 'helper_down' });
      return;
    }
    lastInfo = info;

    // Danh sách chỉ để biết AI có máy; mỗi người đọc lại máy của mình ngay trước khi xử lý.
    const users = [...new Set(live.map((d) => d.user))];
    for (const u of [...queue.keys()]) if (!users.includes(u)) queue.delete(u);
    const run = { brokenHosts: new Set() };
    await eachLimited(users, userConcurrency, async (userId) => {
      try {
        await cycleUser(userId, info, run);
      } catch (e) {
        log({ event: 'user_failed', user: hashUserId(userId), error: e?.code ?? e?.name ?? 'error' });
      }
    });
    lastCycleAt = now();
  }

  // ─── Nhịp phút ──────────────────────────────────────────────────────────

  async function tickUser(userId, run) {
    const devices = await freshDevices(userId, t());
    if (devices.length === 0) return;
    const loaded = await load(userId, lastInfo);
    if (!loaded) return;
    const zones = groupBy(devices, (d) => d.timezone);
    const plans = await planAll(userId, zones, 'due', loaded);
    for (const [tz, r] of plans) if (r === 'bad_tz') await dropBadZone(zones.get(tz));
    await sendDue(userId, zones, plans, loaded, run);
  }

  async function runTick() {
    if (!config.enabled || !lastInfo) return;
    const nowMs = t();
    const due = [...queue].filter(([, times]) => times[0] <= nowMs).map(([u]) => u);
    const run = { brokenHosts: new Set() };
    await eachLimited(due, userConcurrency, async (userId) => {
      try {
        await tickUser(userId, run);
      } catch (e) {
        log({ event: 'user_failed', user: hashUserId(userId), error: e?.code ?? e?.name ?? 'error' });
      } finally {
        // Giờ đã qua bỏ khỏi hàng đợi dù lỗi: chu kỳ sau (lượt due) bù lại.
        const rest = (queue.get(userId) ?? []).filter((x) => x > nowMs);
        if (rest.length > 0) queue.set(userId, rest);
        else queue.delete(userId);
      }
    });
  }

  return {
    cycle: () => enqueue('cycle', runCycle),
    tick: () => enqueue('tick', runTick),
    start() {
      stopped = false;
      const p = enqueue('cycle', runCycle);
      timers = [setInterval(() => enqueue('cycle', runCycle), CYCLE_MS), setInterval(() => enqueue('tick', runTick), TICK_MS)];
      return p;
    },
    /// Huỷ hẹn giờ; trả promise xong khi việc đang chạy (và đã xếp) kết thúc.
    stop() {
      stopped = true;
      for (const h of timers) clearInterval(h);
      timers = [];
      return chain;
    },
    get lastCycleAt() { return lastCycleAt; },
    /// `'auth_failing'` khi BẤT KỲ push host nào trả 401/403 (VAPID bị từ chối) trong
    /// AUTH_WINDOW_MS vừa qua, còn không thì `'ok'`; cho /healthz.
    get pushStatus() {
      const nowMs = t();
      for (const [host, at] of authAt) if (nowMs - at >= AUTH_WINDOW_MS) authAt.delete(host);
      return authAt.size > 0 ? 'auth_failing' : 'ok';
    },
  };
}
