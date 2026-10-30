// Bộ lập lịch notify (spec P6b §2–§3). Chu kỳ 15 phút: dọn, giữ thiết bị
// (server_kinds, lease), lượt `due` (bù sau khi khởi động lại) và lượt
// `upcoming` (xếp giờ vào hàng đợi). Nhịp 1 phút: người nào tới giờ thì đọc lại
// dữ liệu MỚI và chạy lượt `due`. Nội dung luôn do helper tính lúc gửi; quá
// `validUntil` thì không gửi.
//
// Không trùng: mỗi lần gửi trước hết GIÀNH một dòng push_deliveries có id cố
// định (deliveryIdFor, cùng công thức với dòng giành trước của đăng ký).
// RECORD_NOT_UNIQUE nghĩa là đã có người giành: bỏ qua. `sent_at` chỉ ghi sau
// khi push service nhận.
//
// Dòng đã giành mà không gửi được:
// - chắc chắn CHƯA tới push service (429/5xx hết lượt thử, auth, lỗi thiết bị,
//   kênh chưa có, options/tin hỏng) → xoá dòng, để chu kỳ sau thử lại khi mục
//   còn hiệu lực;
// - không rõ (mạng, hết giờ, lỗi nội bộ) → GIỮ dòng: thà thiếu một lần còn hơn
//   gửi hai lần (★10). Dòng có sent_at rỗng nên không bao giờ hiện "Đã gửi".
//
// Nhật ký chỉ có băm id người dùng và 8 ký tự đầu id thiết bị; không bao giờ
// có endpoint, khoá, tiêu đề hay nội dung.

import { deliveryIdFor, serverKindsFor } from './devices.mjs';
import { hashUserId } from './log.mjs';
import {
  CYCLE_MS, DAILY_CAP, DELIVERY_KEEP_DAYS, FAILURES_TO_PRUNE, HORIZON_MS, LEASE_MARGIN_MS, LEASE_MS, LEASE_RENEW_BELOW_MS,
  RETRY_FLOORS_MS, STALE_DEVICE_DAYS, TICK_MS, USER_CONCURRENCY,
} from './limits.mjs';
import { buildPlanRequest } from './requests.mjs';
import { pushTopic, pushUrgency, ttlSeconds } from './webpush.mjs';

const DAY_MS = 86_400_000;
// Lỗi không rõ đã tới push service hay chưa: giữ dòng đã giành.
const AMBIGUOUS = new Set(['network', 'timeout', 'internal']);

/// Giờ Directus (có thể thiếu đuôi múi) thành ms UTC, hoặc NaN.
function ms(value) {
  if (typeof value !== 'string' || value === '') return Number.NaN;
  return Date.parse(/(?:Z|[+-]\d\d:?\d\d)$/i.test(value) ? value : `${value}Z`);
}
const iso = (t) => new Date(t).toISOString();
const short = (deviceId) => String(deviceId).slice(0, 8);
const kindsOf = (d) => (Array.isArray(d.server_kinds) ? d.server_kinds : []);
const sameKinds = (a, b) => a.length === b.length && a.every((k) => b.includes(k));

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

const validInfo = (info) => info?.ok === true && typeof info.fingerprint === 'string'
  && info.fields !== null && typeof info.fields === 'object' && typeof info.settingsFields === 'string';

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
  let pushStatus = 'ok';
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

  function eligible(device, item, nowMs) {
    return !device.removed
      && device.mode === 'server'
      && kindsOf(device).includes(item.kind)
      && nowMs < ms(device.lease_until) - LEASE_MARGIN_MS
      && ms(item.atUtc) <= nowMs && nowMs < ms(item.validUntilUtc);
  }

  async function sendWithRetry(sender, device, message, item) {
    const options = () => ({ ttlSeconds: ttlSeconds(item.validUntilUtc, now()), topic: pushTopic(item.kind, item.key), urgency: pushUrgency(item.kind) });
    let result = await sender.send(device, message, options());
    for (const floor of RETRY_FLOORS_MS) {
      if (result?.status !== 'retry') break;
      await sleep(Math.max(floor, Number.isFinite(result.retryAfterMs) ? result.retryAfterMs : 0));
      // Không bao giờ gửi sau validUntil, kể cả khi đang thử lại.
      if (t() >= ms(item.validUntilUtc)) return { status: 'expired', code: result.code };
      result = await sender.send(device, message, options());
    }
    return result;
  }

  async function release(deliveryId) {
    try {
      await directus.deleteDelivery(deliveryId);
    } catch {
      // Không xoá được: dòng nằm lại, tệ nhất là thiếu một lần gửi.
    }
  }

  async function deliver(userId, device, item, deliveryId, loaded) {
    const message = {
      v: 1, deliveryId, notificationId: item.id, kind: item.kind, key: item.key,
      title: item.title, body: item.body, payload: item.payload, ackUrl: `${config.publicUrl}/push/ack`,
    };
    const sender = senders.senderFor(device.channel);
    const result = sender
      ? await sendWithRetry(sender, device, message, item)
      : { status: 'failed', code: 'unsupported_channel', deviceFault: false };
    const status = result?.status ?? 'failed';
    log({ event: 'push', user: hashUserId(userId), device: short(device.id), kind: item.kind, status, code: result?.code ?? null });

    if (status === 'sent') {
      const at = now().toISOString();
      pushStatus = 'ok';
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
      pushStatus = 'auth_failing';
      log({
        event: 'push_auth_failing', level: 'error', device: short(device.id),
        message: 'push service từ chối VAPID (401/403): kiểm khoá VAPID của dịch vụ',
      });
    }
    if (status === 'failed' && AMBIGUOUS.has(result.code)) return; // giữ dòng: gửi tối đa một lần
    await release(deliveryId);
  }

  /// Lượt `due`: gửi mục đến hạn tới từng máy đủ điều kiện, giành trước.
  async function sendDue(userId, zones, plans, loaded) {
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
          const pair = `${item.kind}|${item.key}`;
          if (!counted.has(pair) && counted.size >= DAILY_CAP) {
            log({ event: 'cap_reached', user: hashUserId(userId), kind: item.kind });
            continue;
          }
          const claimed = await directus.claimDelivery({
            id: deliveryId, user: userId, device: device.id, notification_id: item.id,
            kind: item.kind, key: item.key, title: item.title, body: item.body, at: item.atUtc, sent_at: null,
          });
          known.add(deliveryId);
          if (!claimed) continue;
          counted.add(pair);
          await deliver(userId, device, item, deliveryId, loaded);
        }
      }
    }
  }

  // ─── Chu kỳ ──────────────────────────────────────────────────────────────

  /// Giữ thiết bị: server_kinds theo vân tay helper (rỗng nếu múi hỏng), và
  /// gia hạn lease cho máy khoẻ khi còn dưới 5 giờ. Một PATCH mỗi máy, chỉ khi cần.
  async function maintain(devices, badZones, info, nowMs) {
    for (const d of devices) {
      const bad = badZones.has(d.timezone);
      const kinds = bad ? [] : serverKindsFor({ seedFingerprint: d.seed_fingerprint, enabled: config.enabled, helperFingerprint: info.fingerprint });
      const patch = {};
      if (!sameKinds(kindsOf(d), kinds)) patch.server_kinds = kinds;
      const lease = ms(d.lease_until);
      if (kinds.length > 0 && (d.failure_count ?? 0) === 0 && !(lease - nowMs >= LEASE_RENEW_BELOW_MS)) {
        patch.lease_until = iso(nowMs + LEASE_MS);
      }
      if (Object.keys(patch).length === 0) continue;
      await directus.updateDevice(d.id, patch);
      Object.assign(d, patch);
      if (bad && patch.server_kinds) log({ event: 'bad_tz', device: short(d.id) });
    }
  }

  async function cycleUser(userId, devices, info) {
    const nowMs = t();
    const zones = groupBy(devices, (d) => d.timezone);
    const loaded = await load(userId, info);
    const due = loaded ? await planAll(userId, zones, 'due', loaded) : new Map();
    const badZones = new Set([...due].filter(([, r]) => r === 'bad_tz').map(([tz]) => tz));
    await maintain(devices, badZones, info, nowMs);
    if (!loaded) {
      queue.delete(userId);
      return;
    }
    await sendDue(userId, zones, due, loaded);

    // Lượt upcoming lập từ ĐẦU chu kỳ, không phải sau lượt due (có thể đã chờ
    // thử lại): mục tới hạn trong lúc đó vẫn vào hàng đợi và nhịp phút kế tiếp
    // gửi ngay. Upcoming chỉ quyết định KHI NÀO; lượt due lúc đó tính lại từ dữ liệu mới.
    const times = new Set();
    const from = nowMs;
    for (const [tz, zoneDevices] of zones) {
      if (badZones.has(tz)) continue;
      const plan = await planZone(userId, tz, 'upcoming', loaded, iso(nowMs));
      if (!plan || plan === 'bad_tz') continue;
      const live = zoneDevices.filter((d) => !d.removed && d.mode === 'server');
      for (const it of plan.items) {
        const at = ms(it.atUtc);
        if (at > from && at <= from + HORIZON_MS && live.some((d) => kindsOf(d).includes(it.kind))) times.add(at);
      }
    }
    if (times.size > 0) queue.set(userId, [...times].sort((a, b) => a - b));
    else queue.delete(userId);
  }

  async function runCycle() {
    const nowMs = t();
    try {
      await directus.deleteDeliveriesBefore(iso(nowMs - DELIVERY_KEEP_DAYS * DAY_MS));
    } catch (e) {
      log({ event: 'prune_failed', error: e?.code ?? 'error' });
    }
    if (!config.enabled) {
      // Công tắc tắt: không gửi, không gia hạn; lease cũ hết hạn và app quay về cục bộ.
      queue.clear();
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

    const byUser = groupBy(live, (d) => d.user);
    for (const u of [...queue.keys()]) if (!byUser.has(u)) queue.delete(u);
    await eachLimited([...byUser], userConcurrency, async ([userId, devices]) => {
      try {
        await cycleUser(userId, devices, info);
      } catch (e) {
        log({ event: 'user_failed', user: hashUserId(userId), error: e?.code ?? e?.name ?? 'error' });
      }
    });
    lastCycleAt = now();
  }

  // ─── Nhịp phút ──────────────────────────────────────────────────────────

  async function tickUser(userId) {
    const devices = ((await directus.devicesOfUser(userId)) ?? []).filter((d) => d.user === userId && d.mode === 'server');
    if (devices.length === 0) return;
    const loaded = await load(userId, lastInfo);
    if (!loaded) return;
    const zones = groupBy(devices, (d) => d.timezone);
    const plans = await planAll(userId, zones, 'due', loaded);
    for (const [tz, r] of plans) if (r === 'bad_tz') await dropBadZone(zones.get(tz));
    await sendDue(userId, zones, plans, loaded);
  }

  async function runTick() {
    if (!config.enabled || !lastInfo) return;
    const nowMs = t();
    const due = [...queue].filter(([, times]) => times[0] <= nowMs).map(([u]) => u);
    await eachLimited(due, userConcurrency, async (userId) => {
      try {
        await tickUser(userId);
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
    /// `'ok'` hoặc `'auth_failing'` (push service từ chối VAPID), cho /healthz.
    get pushStatus() { return pushStatus; },
  };
}
