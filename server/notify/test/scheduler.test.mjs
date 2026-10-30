import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createScheduler } from '../src/scheduler.mjs';
import { createDirectus } from '../src/directus.mjs';
import { deliveryIdFor, deviceIdFor } from '../src/devices.mjs';
import { hashUserId } from '../src/log.mjs';
import { CYCLE_MS, KINDS, MAX_INCHAIN_RETRY_MS, TICK_MS, USER_CONCURRENCY } from '../src/limits.mjs';
import { pushTopic, pushUrgency } from '../src/webpush.mjs';
import { DIRECTUS, SERVICE_TOKEN, errorResponse, fakeDirectus, fakeFetch } from './fakes.mjs';

const T0 = Date.parse('2026-10-30T02:00:00.000Z');
const MIN = 60_000;
const H = 60 * MIN;
const DAY = 24 * H;
const iso = (ms) => new Date(ms).toISOString();
const COLLECTIONS = ['drill_logs', 'timer_sessions', 'schedule_slots', 'cue_equipment', 'pool_matches', 'bu_tests', 'bu_drill_results'];
const FIELDS = Object.fromEntries(COLLECTIONS.map((c, i) => [c, `id,f${i}`]));
const SETTINGS_FIELDS = 'id,recommendation,maintenance,schedule,streak,prefs_updated_at,last_seen_cat,last_seen_drill_id,last_seen_at,timezone,user_created';

const MOZ = 'https://updates.push.services.mozilla.com/wpush/v2';
function device(n, over = {}, host = 'https://fcm.googleapis.com/fcm/send') {
  const endpoint = `${host}/dev-${n}`;
  return {
    id: deviceIdFor(endpoint), user: 'user-a', channel: 'web', platform: 'web', endpoint, key_p256dh: 'p', key_auth: 'a',
    timezone: 'Asia/Ho_Chi_Minh', seed_fingerprint: 'fp1', mode: 'server', server_kinds: [...KINDS],
    // Còn 5,5 giờ: chưa tới ngưỡng gia hạn, nên chu kỳ không PATCH gì.
    lease_until: iso(T0 + 5.5 * H), last_seen_at: iso(T0 - DAY), failure_count: 0, created_at: iso(T0 - 2 * DAY),
    ...over,
  };
}
const settingsRow = (user) => ({
  id: user, recommendation: true, maintenance: true, schedule: true, streak: true,
  last_seen_cat: null, last_seen_drill_id: null, last_seen_at: null, timezone: 'Asia/Ho_Chi_Minh', user_created: user,
});
function item(n, over = {}) {
  return {
    id: 100 + n, kind: 'schedule', key: `schedule:2026-10-30:${n}`,
    at: '2026-10-30T08:55:00.000', atUtc: iso(T0 - 5 * MIN),
    validUntil: '2026-10-30T09:55:00.500', validUntilUtc: iso(T0 + 55 * MIN + 500),
    title: `t${n}`, body: `b${n}`, payload: `p${n}`,
    ...over,
  };
}
const dueOnly = (items) => (req) => ({ ok: true, items: req.mode === 'due' ? items : [] });

function harness({
  devices = [device(1)], settings = [settingsRow('user-a')], deliveries = [], plan = () => ({ ok: true, items: [] }),
  enabled = true, fingerprint = 'fp1', send = () => ({ status: 'sent' }), extra = {},
} = {}) {
  let clock = T0;
  const fake = fakeDirectus({
    filters: true,
    items: { push_devices: devices, notification_settings: settings, push_deliveries: deliveries, ...extra },
  });
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fakeFetch({ directus: fake }), sleep: async () => {} });
  const planCalls = [];
  const planner = {
    healthy: true,
    infoCalls: 0,
    info: async () => {
      planner.infoCalls += 1;
      return { ok: true, fingerprint, kinds: [...KINDS], fields: FIELDS, settingsFields: SETTINGS_FIELDS };
    },
    plan: async (req) => {
      planCalls.push(structuredClone(req));
      return plan(req);
    },
    close() {},
  };
  const sent = [];
  const sender = {
    send: async (dev, msg, opts) => {
      sent.push({ device: dev.id, msg, opts, at: clock });
      return send(dev, msg, opts, sent.length);
    },
  };
  const senders = { senderFor: (ch) => (ch === 'web' ? sender : null) };
  const logs = [];
  const sleeps = [];
  const intervals = [];
  const cleared = [];
  const s = createScheduler({
    directus, planner, senders,
    config: { enabled, publicUrl: 'https://notify.test' },
    now: () => new Date(clock),
    log: (l) => logs.push(l),
    sleep: async (ms) => { sleeps.push(ms); clock += ms; },
    setInterval: (fn, ms) => { intervals.push({ fn, ms }); return intervals.length; },
    clearInterval: (h) => { cleared.push(h); },
  });
  return {
    s, fake, planner, planCalls, sent, logs, sleeps, intervals, cleared,
    advance: (ms) => { clock += ms; },
    get now() { return clock; },
    rows: (c) => fake.items[c] ?? [],
    calls: (method, coll) => fake.calls.filter((c) => c.method === method && c.path.startsWith(`/items/${coll}`)),
  };
}

const deviceRow = (h, id) => h.rows('push_devices').find((d) => d.id === id);

// ─── Gửi đúng mục đến hạn ────────────────────────────────────────────────────

test('nhịp đến hạn: gửi đúng mục at ≤ now < validUntil, ghi sent_at, đúng TTL/Topic/Urgency', async () => {
  const d = device(1);
  const h = harness({
    devices: [d],
    plan: dueOnly([
      item(1),
      item(2, { atUtc: iso(T0 + 10 * MIN) }), // chưa tới giờ
      item(3, { kind: 'streak', key: 'streak:2026-10-30' }),
    ]),
  });
  await h.s.cycle();
  assert.deepEqual(h.sent.map((x) => x.msg.key), ['schedule:2026-10-30:1', 'streak:2026-10-30']);
  const first = h.sent[0];
  const deliveryId = deliveryIdFor(d.id, 'schedule', 'schedule:2026-10-30:1');
  assert.deepEqual(first.msg, {
    v: 1, deliveryId, notificationId: 101, kind: 'schedule', key: 'schedule:2026-10-30:1',
    title: 't1', body: 'b1', payload: 'p1', ackUrl: 'https://notify.test/push/ack',
  });
  // validUntil lẻ 500 ms: TTL vẫn là số nguyên giây.
  assert.deepEqual(first.opts, { ttlSeconds: 55 * 60, topic: pushTopic('schedule', 'schedule:2026-10-30:1'), urgency: pushUrgency('schedule') });
  assert.ok(Number.isInteger(first.opts.ttlSeconds));
  assert.equal(h.sent[1].opts.urgency, 'high');
  const row = h.rows('push_deliveries').find((r) => r.id === deliveryId);
  assert.deepEqual(row, {
    id: deliveryId, user: 'user-a', device: d.id, notification_id: 101, kind: 'schedule', key: 'schedule:2026-10-30:1',
    title: 't1', body: 'b1', at: iso(T0 - 5 * MIN), sent_at: iso(T0),
  });
  assert.equal(deviceRow(h, d.id).last_success_at, iso(T0));
  assert.equal(deviceRow(h, d.id).failure_count, 0);
  assert.equal(h.s.lastCycleAt.toISOString(), iso(T0));
  // Mỗi múi một lần gọi helper cho mỗi lượt, đúng dạng yêu cầu.
  assert.deepEqual(h.planCalls.map((r) => r.mode), ['due', 'upcoming']);
  assert.equal(h.planCalls[0].nowUtc, iso(T0));
  assert.equal(h.planCalls[0].tz, 'Asia/Ho_Chi_Minh');
  assert.deepEqual(h.planCalls[0].prefs, { recommendation: true, maintenance: true, schedule: true, streak: true });
});

test('quá validUntil (máy chủ vừa sống lại): không gửi', async () => {
  const h = harness({ plan: dueOnly([item(1, { atUtc: iso(T0 - 2 * H), validUntilUtc: iso(T0 - MIN) }), item(2, { validUntilUtc: iso(T0) })]) });
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.deepEqual(h.rows('push_deliveries'), [], 'không giành dòng cho mục hết hạn');
});

test('thử lại sau 429/5xx không bao giờ gửi khi đã quá validUntil', async () => {
  // Hết hạn sau 3 giây: lần chờ 2 giây còn kịp; lần chờ 8 giây sẽ qua hạn nên không chờ, nhả dòng.
  const h = harness({
    plan: dueOnly([item(1, { validUntilUtc: iso(T0 + 3000) })]),
    send: () => ({ status: 'retry', code: 503, retryAfterMs: 1000 }),
  });
  await h.s.cycle();
  assert.equal(h.sent.length, 2);
  assert.deepEqual(h.sleeps, [2000]);
  assert.deepEqual(h.rows('push_deliveries'), []);
  h.advance(TICK_MS);
  await h.s.tick();
  assert.equal(h.sent.length, 2);
});

test('giành chậm (POST giành lâu) đẩy now qua validUntil: không gửi, nhả dòng', async () => {
  const h = harness({ plan: dueOnly([item(1, { validUntilUtc: iso(T0 + 10_000) })]) });
  h.fake.reply = ({ method, path }) => {
    if (method === 'POST' && path === '/items/push_deliveries') h.advance(30_000); // 429 lặp / hết giờ chờ ở Directus
    return undefined;
  };
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.deepEqual(h.rows('push_deliveries'), [], 'dòng giành được nhả (chắc chắn chưa gửi)');
});

test('lease sắp hết (trừ 5 phút) ngay trước lần gửi: không gửi, nhả dòng', async () => {
  const d = device(1, { lease_until: iso(T0 + 6 * MIN), failure_count: 1 });
  const h = harness({ devices: [d], plan: dueOnly([item(1)]) });
  h.fake.reply = ({ method, path }) => {
    if (method === 'POST' && path === '/items/push_deliveries') h.advance(2 * MIN);
    return undefined;
  };
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.deepEqual(h.rows('push_deliveries'), []);
});

test('Retry-After vượt validUntil: không chờ, không gửi lại, nhả dòng', async () => {
  const h = harness({
    plan: dueOnly([item(1, { validUntilUtc: iso(T0 + 4000) })]),
    send: () => ({ status: 'retry', code: 429, retryAfterMs: 5000 }),
  });
  await h.s.cycle();
  assert.equal(h.sent.length, 1);
  assert.deepEqual(h.sleeps, []);
  assert.deepEqual(h.rows('push_deliveries'), []);
});

test(`Retry-After dài hơn ${MAX_INCHAIN_RETRY_MS} ms: không ngủ trong chuỗi, nhả dòng, nhịp sau (đã qua Retry-After) gửi lại`, async () => {
  assert.equal(MAX_INCHAIN_RETRY_MS, 5000);
  const h = harness({
    plan: dueOnly([item(1)]),
    send: (_d, _m, _o, n) => (n === 1 ? { status: 'retry', code: 429, retryAfterMs: 90_000 } : { status: 'sent' }),
  });
  await h.s.cycle();
  assert.equal(h.sent.length, 1);
  assert.deepEqual(h.sleeps, []);
  assert.deepEqual(h.rows('push_deliveries'), []);
  h.advance(TICK_MS);
  await h.s.tick(); // mới 60 s < 90 s: chưa gửi lại, không giành
  h.advance(10_000);
  await h.s.cycle(); // chu kỳ lúc 70 s cũng chưa được gửi sớm
  assert.equal(h.sent.length, 1);
  assert.equal(h.calls('POST', 'push_deliveries').length, 1);
  h.advance(6 * MIN - 70_000); // chu kỳ sau Retry-After thì gửi lại
  await h.s.cycle();
  assert.equal(h.sent.length, 2);
  assert.equal(h.sent[1].at, T0 + 6 * MIN);
  assert.equal(h.rows('push_deliveries')[0].sent_at, iso(T0 + 6 * MIN));
});

// ─── Không trùng: giành rồi mới gửi ──────────────────────────────────────────

test('hai nhịp chạy chồng / khởi động lại giữa lúc gửi: dòng đã giành thì không gửi lần hai', async () => {
  // (a) Tiến trình khác giành ngay trước ta: POST trả RECORD_NOT_UNIQUE.
  const a = harness({ plan: dueOnly([item(1)]) });
  a.fake.reply = ({ method, path }) => (method === 'POST' && path === '/items/push_deliveries' ? errorResponse(400, 'RECORD_NOT_UNIQUE') : undefined);
  await a.s.cycle();
  assert.deepEqual(a.sent, []);

  // (b) Khởi động lại sau khi đã giành nhưng chưa ghi sent_at: dòng có sẵn, không gửi.
  const d = device(1);
  const id = deliveryIdFor(d.id, 'schedule', 'schedule:2026-10-30:1');
  const b = harness({
    devices: [d], plan: dueOnly([item(1)]),
    deliveries: [{ id, user: 'user-a', device: d.id, notification_id: 101, kind: 'schedule', key: 'schedule:2026-10-30:1', title: 't1', body: 'b1', at: iso(T0 - 5 * MIN), sent_at: null }],
  });
  await b.s.cycle();
  assert.deepEqual(b.sent, []);

  // (c) Hai chu kỳ và một nhịp gọi chồng nhau: chạy nối đuôi, gửi đúng một lần.
  const c = harness({ plan: dueOnly([item(1)]) });
  await Promise.all([c.s.cycle(), c.s.cycle(), c.s.tick(), c.s.cycle()]);
  assert.equal(c.sent.length, 1);
});

test('dòng giành trước của đăng ký (shownToday: sent_at rỗng, notification_id 0) không bao giờ được gửi', async () => {
  const d = device(1);
  const id = deliveryIdFor(d.id, 'schedule', 'schedule:2026-10-30:1');
  const h = harness({
    devices: [d], plan: dueOnly([item(1), item(2)]),
    deliveries: [{ id, user: 'user-a', device: d.id, notification_id: 0, kind: 'schedule', key: 'schedule:2026-10-30:1', title: '', body: '', at: iso(T0 - 3 * H), sent_at: null }],
  });
  await h.s.cycle();
  assert.deepEqual(h.sent.map((x) => x.msg.key), ['schedule:2026-10-30:2']);
  assert.equal(h.calls('POST', 'push_deliveries').length, 1, 'không thử giành lại dòng đã có');
});

test('loại không thuộc server_kinds của máy, hoặc lease hết (trừ 5 phút): không gửi', async () => {
  // Seed khác helper: máy tự lo gợi ý, server_kinds không có recommendation.
  const noRec = device(1, { seed_fingerprint: 'other-seed', server_kinds: ['maintenance', 'schedule', 'streak'] });
  // failure_count > 0 nên chu kỳ không gia hạn: lease còn 4 phút < biên 5 phút.
  const leaseEnding = device(2, { lease_until: iso(T0 + 4 * MIN), failure_count: 1 });
  const noLease = device(3, { lease_until: null, failure_count: 1 });
  const local = device(4, { mode: 'local' });
  const ok = device(5, { lease_until: iso(T0 + 6 * MIN), failure_count: 1 });
  const rec = item(1, { kind: 'recommendation', key: 'rec:2026-10-30' });
  const h = harness({ devices: [noRec, leaseEnding, noLease, local, ok], plan: dueOnly([rec]) });
  await h.s.cycle();
  assert.deepEqual(h.sent.map((x) => x.device), [ok.id]);
  assert.deepEqual(deviceRow(h, noRec.id).server_kinds, ['maintenance', 'schedule', 'streak']);
});

test('PUSH_ENABLED=false: không gửi, không gia hạn lease, vẫn dọn delivery cũ', async () => {
  const d = device(1, { lease_until: iso(T0 + H) });
  const h = harness({
    enabled: false, devices: [d], plan: dueOnly([item(1)]),
    deliveries: [
      { id: 'old', user: 'user-a', at: iso(T0 - 31 * DAY), sent_at: iso(T0 - 31 * DAY) },
      { id: 'new', user: 'user-a', at: iso(T0 - 29 * DAY), sent_at: iso(T0 - 29 * DAY) },
    ],
  });
  await h.s.cycle();
  h.advance(TICK_MS);
  await h.s.tick();
  assert.deepEqual(h.rows('push_deliveries').map((r) => r.id), ['new']);
  assert.deepEqual(h.sent, []);
  assert.equal(h.planner.infoCalls, 0);
  assert.equal(h.planCalls.length, 0);
  assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
  assert.equal(deviceRow(h, d.id).lease_until, iso(T0 + H));
});

test('chưa có notification_settings: không gửi gì cho người đó', async () => {
  const h = harness({ settings: [], plan: dueOnly([item(1)]) });
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.equal(h.planCalls.length, 0);
  for (const c of COLLECTIONS) assert.equal(h.calls('GET', c).length, 0, `không đọc ${c}`);
});

test('helper trả bad_data: bỏ người đó, ghi log plan_failed, người khác vẫn được gửi', async () => {
  const da = device(1);
  const db = device(2, { user: 'user-b' });
  const dc = device(3, { user: 'user-c' });
  const h = harness({
    devices: [da, db, dc],
    settings: [settingsRow('user-a'), settingsRow('user-b'), settingsRow('user-c')],
    plan: (req) => {
      if (req.userId === 'user-a') return { ok: false, error: 'bad_data', collection: 'drill_logs' };
      if (req.userId === 'user-c') throw Object.assign(new Error('timeout'), { code: 'timeout' });
      return { ok: true, items: req.mode === 'due' ? [item(1)] : [] };
    },
  });
  await h.s.cycle();
  assert.deepEqual(h.sent.map((x) => x.device), [db.id]);
  const failed = h.logs.filter((l) => l.event === 'plan_failed');
  assert.ok(failed.some((l) => l.user === hashUserId('user-a') && l.error === 'bad_data'));
  assert.ok(failed.some((l) => l.user === hashUserId('user-c') && l.error === 'timeout'));
  assert.doesNotMatch(JSON.stringify(h.logs), /user-a|user-c/);
  assert.ok(h.s.lastCycleAt, 'chu kỳ vẫn xong');
});

// ─── Trần ngày ───────────────────────────────────────────────────────────────

test('trần 12 (kind,key) mỗi 24 giờ mỗi người: mục thứ 13 không giành, không gửi', async () => {
  const items = Array.from({ length: 13 }, (_, i) => item(i + 1));
  const h = harness({ plan: dueOnly(items) });
  await h.s.cycle();
  assert.equal(h.sent.length, 12);
  assert.equal(h.rows('push_deliveries').length, 12);
  assert.ok(!h.rows('push_deliveries').some((r) => r.key === 'schedule:2026-10-30:13'));
  assert.ok(h.logs.some((l) => l.event === 'cap_reached' && l.user === hashUserId('user-a')));
});

test('trần chỉ tính dòng đã có sent_at trong 24 giờ; dòng giành trước không tính; cùng (kind,key) ở hai máy tính một', async () => {
  const d1 = device(1);
  const d2 = device(2);
  const sentRows = Array.from({ length: 10 }, (_, i) => ({
    id: `s${i}`, user: 'user-a', device: d1.id, notification_id: i, kind: 'maintenance', key: `m:${i}`, title: 't', body: 'b',
    at: iso(T0 - 2 * H), sent_at: iso(T0 - 2 * H),
  }));
  const preClaims = Array.from({ length: 5 }, (_, i) => ({
    id: `pc${i}`, user: 'user-a', device: d1.id, notification_id: 0, kind: 'streak', key: `x:${i}`, title: '', body: '',
    at: iso(T0 - H), sent_at: null,
  }));
  const yesterday = { id: 'y', user: 'user-a', device: d1.id, notification_id: 9, kind: 'streak', key: 'y', title: 't', body: 'b', at: iso(T0 - 25 * H), sent_at: iso(T0 - 25 * H) };
  const h = harness({
    devices: [d1, d2], deliveries: [...sentRows, ...preClaims, yesterday],
    plan: dueOnly([item(1), item(2), item(3)]),
  });
  await h.s.cycle();
  // 10 đã gửi + 2 mới = 12; mục 3 bị chặn. Mỗi mục tới cả hai máy.
  assert.deepEqual(h.sent.map((x) => x.msg.key).sort(), ['schedule:2026-10-30:1', 'schedule:2026-10-30:1', 'schedule:2026-10-30:2', 'schedule:2026-10-30:2']);
});

// ─── Kết quả gửi (hợp đồng deviceFault) ─────────────────────────────────────

test('404/410: xoá thiết bị ngay', async () => {
  for (const code of [404, 410]) {
    const d = device(1);
    const h = harness({ devices: [d], plan: dueOnly([item(1), item(2)]), send: () => ({ status: 'gone', code }) });
    await h.s.cycle();
    assert.equal(deviceRow(h, d.id), undefined);
    assert.equal(h.sent.length, 1, 'không gửi tiếp tới máy đã xoá');
  }
});

test('503 hai lần rồi 201: gửi được, chờ theo Retry-After, failure_count về 0', async () => {
  const d = device(1, { failure_count: 2 });
  const h = harness({
    devices: [d], plan: dueOnly([item(1)]),
    send: (_d, _m, _o, n) => (n < 3 ? { status: 'retry', code: 503, retryAfterMs: n === 1 ? 5000 : 1000 } : { status: 'sent' }),
  });
  await h.s.cycle();
  // Lần thử lại 1 chờ 5 s trong chuỗi; lần 2 phải chờ 8 s (> 5 s) nên hoãn sang nhịp sau.
  assert.equal(h.sent.length, 2);
  assert.deepEqual(h.sleeps, [5000]);
  h.advance(TICK_MS);
  await h.s.tick();
  assert.equal(h.sent.length, 3);
  // TTL tính lại ở mỗi lần thử, luôn là số nguyên.
  assert.deepEqual(h.sent.map((x) => x.opts.ttlSeconds), [3300, 3295, 3235]);
  assert.equal(deviceRow(h, d.id).failure_count, 0);
  const row = h.rows('push_deliveries')[0];
  assert.equal(row.sent_at, iso(T0 + 65_000));
});

test('429/5xx hết lượt thử: không đụng thiết bị, nhả dòng giành để chu kỳ sau thử lại', async () => {
  const d = device(1);
  let down = true;
  const h = harness({
    devices: [d], plan: dueOnly([item(1)]),
    send: () => (down ? { status: 'retry', code: 503, retryAfterMs: 0 } : { status: 'sent' }),
  });
  await h.s.cycle();
  assert.equal(h.sent.length, 2);
  assert.deepEqual(h.sleeps, [2000]);
  h.advance(TICK_MS);
  await h.s.tick(); // lần thử lại thứ hai (đã hoãn 8 s): vẫn 503 → hết lượt
  assert.equal(h.sent.length, 3);
  assert.equal(deviceRow(h, d.id).failure_count, 0);
  assert.deepEqual(h.rows('push_deliveries'), []);
  assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
  h.advance(TICK_MS);
  await h.s.tick(); // hết lượt thì không xếp lại: các nhịp sau không gửi thêm
  assert.equal(h.sent.length, 3);
  down = false;
  h.advance(CYCLE_MS);
  await h.s.cycle();
  assert.equal(h.sent.length, 4);
  assert.equal(h.rows('push_deliveries')[0].sent_at, iso(h.now));
});

test('lỗi mạng / hết giờ: không thử lại, không đụng thiết bị, giữ dòng giành (gửi tối đa một lần)', async () => {
  for (const code of ['network', 'timeout']) {
    const d = device(1);
    const h = harness({ devices: [d], plan: dueOnly([item(1)]), send: () => ({ status: 'failed', code, deviceFault: false }) });
    await h.s.cycle();
    assert.equal(h.sent.length, 1);
    assert.deepEqual(h.sleeps, []);
    assert.equal(deviceRow(h, d.id).failure_count, 0);
    assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
    assert.equal(h.rows('push_deliveries').length, 1);
    assert.equal(h.rows('push_deliveries')[0].sent_at, null);
    h.advance(CYCLE_MS);
    await h.s.cycle();
    assert.equal(h.sent.length, 1, 'không gửi lại ở chu kỳ sau');
  }
});

test('failed deviceFault:true: failure_count +1, nhả dòng giành', async () => {
  const d = device(1);
  const h = harness({ devices: [d], plan: dueOnly([item(1)]), send: () => ({ status: 'failed', code: 400, deviceFault: true }) });
  await h.s.cycle();
  assert.equal(deviceRow(h, d.id).failure_count, 1);
  assert.deepEqual(h.rows('push_deliveries'), []);
});

test('failed deviceFault:false (auth): không đụng thiết bị, cờ push=auth_failing, log ồn không lộ bí mật; gửi được thì về ok', async () => {
  const d1 = device(1);
  const d2 = device(2);
  let auth = true;
  const h = harness({
    devices: [d1, d2], plan: dueOnly([item(1)]),
    send: () => (auth ? { status: 'failed', code: 'auth', deviceFault: false } : { status: 'sent' }),
  });
  assert.equal(h.s.pushStatus, 'ok');
  await h.s.cycle();
  assert.equal(h.s.pushStatus, 'auth_failing');
  for (const d of [d1, d2]) assert.equal(deviceRow(h, d.id).failure_count, 0);
  assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
  const loud = h.logs.filter((l) => l.event === 'push_auth_failing');
  assert.ok(loud.length >= 1);
  assert.equal(loud[0].level, 'error');
  assert.doesNotMatch(JSON.stringify(h.logs), /fcm\.googleapis|dev-1|user-a/);
  auth = false;
  h.advance(CYCLE_MS + MIN);
  await h.s.cycle();
  assert.equal(h.s.pushStatus, 'ok', 'không có auth nào trong 15 phút qua');
  assert.equal(h.sent.filter((x) => x.msg.key === 'schedule:2026-10-30:1').length, 4);
});

test('pushStatus: auth_failing nếu BẤT KỲ push host nào trả auth trong 15 phút qua, không lật theo host khác', async () => {
  const moz = device(1, {}, MOZ);
  const fcm = device(2);
  const h = harness({
    devices: [moz, fcm],
    plan: (req) => ({ ok: true, items: req.mode === 'due' ? [item(Math.floor((Date.parse(req.nowUtc) - T0) / MIN) + 1, { validUntilUtc: iso(T0 + 2 * H) })] : [] }),
    send: (dev) => (dev.endpoint.startsWith(MOZ) ? { status: 'failed', code: 'auth', deviceFault: false } : { status: 'sent' }),
  });
  await h.s.cycle(); // moz trả auth rồi fcm gửi được ngay sau đó
  assert.ok(h.sent.some((x) => x.device === fcm.id), 'fcm gửi sau moz');
  assert.equal(h.s.pushStatus, 'auth_failing');
  h.advance(10 * MIN);
  h.fake.items.push_devices = h.fake.items.push_devices.filter((d) => d.id === fcm.id); // moz thôi nhận
  await h.s.cycle();
  assert.ok(h.sent.some((x) => x.device === fcm.id && x.at === h.now), 'host fcm vừa gửi được');
  assert.equal(h.s.pushStatus, 'auth_failing', 'auth của moz mới 10 phút');
  h.advance(6 * MIN);
  assert.equal(h.s.pushStatus, 'ok', 'auth cuối đã quá 15 phút');
});

test('host push trả 429/5xx: bỏ các lần gửi còn lại tới host đó trong nhịp này, host khác vẫn gửi; nhịp sau gửi nốt', async () => {
  const f1 = device(1);
  const f2 = device(2);
  const m1 = device(3, {}, MOZ);
  let fcmDown = true;
  const h = harness({
    devices: [f1, f2, m1], plan: dueOnly([item(1), item(2)]),
    send: (dev) => (dev.endpoint.startsWith(MOZ) || !fcmDown ? { status: 'sent' } : { status: 'retry', code: 503, retryAfterMs: 0 }),
  });
  await h.s.cycle();
  const fcmCalls = h.sent.filter((x) => x.device !== m1.id);
  // Một mục tới f1: lần đầu + một lần thử lại 2 s trong chuỗi, rồi ngắt host fcm cho cả lượt.
  assert.equal(fcmCalls.length, 2);
  assert.equal(new Set(fcmCalls.map((x) => `${x.device}|${x.msg.key}`)).size, 1);
  assert.deepEqual(h.sent.filter((x) => x.device === m1.id).map((x) => x.msg.key), ['schedule:2026-10-30:1', 'schedule:2026-10-30:2']);
  assert.equal(h.calls('POST', 'push_deliveries').length, 3, 'không giành cho máy bị ngắt host');
  fcmDown = false;
  h.advance(TICK_MS);
  await h.s.tick();
  const delivered = h.rows('push_deliveries').filter((r) => r.sent_at);
  assert.equal(delivered.length, 6, 'nhịp sau gửi nốt cả bốn lần tới fcm');
});

test('sender trả giá trị không phải đối tượng: không ném, giữ dòng (không rõ), các mục khác vẫn gửi', async () => {
  const h = harness({ plan: dueOnly([item(1), item(2)]), send: (_d, msg) => (msg.key.endsWith(':1') ? undefined : { status: 'sent' }) });
  await h.s.cycle();
  assert.equal(h.sent.length, 2);
  assert.ok(!h.logs.some((l) => l.event === 'user_failed'));
  const rows = Object.fromEntries(h.rows('push_deliveries').map((r) => [r.key, r.sent_at]));
  assert.deepEqual(rows, { 'schedule:2026-10-30:1': null, 'schedule:2026-10-30:2': iso(T0) });
});

test('kênh chưa có sender (fcm): không gửi, không đụng thiết bị', async () => {
  const d = device(1, { channel: 'fcm', endpoint: null });
  const h = harness({ devices: [d], plan: dueOnly([item(1)]) });
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.equal(deviceRow(h, d.id).failure_count, 0);
  assert.ok(h.logs.some((l) => l.event === 'push' && l.code === 'unsupported_channel'));
  assert.equal(h.calls('POST', 'push_deliveries').length, 1);
  assert.deepEqual(h.rows('push_deliveries'), [], 'nhả dòng: chắc chắn chưa gửi');
});

test('failure_count lên 5: xoá thiết bị; last_seen_at quá 60 ngày: xoá ở chu kỳ', async () => {
  const flaky = device(1, { failure_count: 4 });
  const h = harness({ devices: [flaky], plan: dueOnly([item(1)]), send: () => ({ status: 'failed', code: 400, deviceFault: true }) });
  await h.s.cycle();
  assert.equal(deviceRow(h, flaky.id), undefined);

  const five = device(1, { failure_count: 5 });
  const stale = device(2, { last_seen_at: iso(T0 - 61 * DAY) });
  const fresh = device(3, { last_seen_at: iso(T0 - 59 * DAY) });
  const g = harness({ devices: [five, stale, fresh], plan: dueOnly([item(1)]) });
  await g.s.cycle();
  assert.deepEqual(g.rows('push_devices').map((d) => d.id), [fresh.id]);
  assert.deepEqual(g.sent.map((x) => x.device), [fresh.id]);
});

// ─── Lease, server_kinds, múi giờ ────────────────────────────────────────────

test('chu kỳ gia hạn lease 6 giờ cho máy khoẻ, không gia hạn máy có lỗi; chỉ PATCH khi còn dưới 5 giờ', async () => {
  const healthy = device(1, { lease_until: iso(T0 + H) });
  const faulty = device(2, { lease_until: iso(T0 + H), failure_count: 1 });
  const plenty = device(3, { lease_until: iso(T0 + 5.5 * H) });
  const none = device(4, { lease_until: null });
  const h = harness({ devices: [healthy, faulty, plenty, none] });
  await h.s.cycle();
  assert.equal(deviceRow(h, healthy.id).lease_until, iso(T0 + 6 * H));
  assert.equal(deviceRow(h, none.id).lease_until, iso(T0 + 6 * H));
  assert.equal(deviceRow(h, faulty.id).lease_until, iso(T0 + H));
  assert.equal(deviceRow(h, plenty.id).lease_until, iso(T0 + 5.5 * H));
  assert.deepEqual(h.calls('PATCH', 'push_devices').map((c) => c.path).sort(), [`/items/push_devices/${healthy.id}`, `/items/push_devices/${none.id}`].sort());
  // Chu kỳ sau 15 phút: không máy nào cần PATCH (R-F5).
  h.advance(CYCLE_MS);
  await h.s.cycle();
  assert.equal(h.calls('PATCH', 'push_devices').length, 2);
});

test('dấu vân tay helper đổi: chu kỳ sửa server_kinds của máy', async () => {
  const oldSeed = device(1, { seed_fingerprint: 'fp1' });
  const newSeed = device(2, { seed_fingerprint: 'fp2', server_kinds: ['maintenance', 'schedule', 'streak'] });
  const h = harness({ devices: [oldSeed, newSeed], fingerprint: 'fp2' });
  await h.s.cycle();
  assert.deepEqual(deviceRow(h, oldSeed.id).server_kinds, ['maintenance', 'schedule', 'streak']);
  assert.deepEqual(deviceRow(h, newSeed.id).server_kinds, [...KINDS]);
});

test('helper bad_tz cho múi của máy: server_kinds [] cho máy đó, không gia hạn, log tiền tố id; máy khác vẫn gửi; chu kỳ sau không khôi phục', async () => {
  const bad = device(1, { timezone: 'Asia/Saigonn', lease_until: iso(T0 + H) });
  const good = device(2);
  const h = harness({
    devices: [bad, good],
    plan: (req) => (req.tz === 'Asia/Saigonn' ? { ok: false, error: 'bad_tz' } : { ok: true, items: req.mode === 'due' ? [item(1)] : [] }),
  });
  await h.s.cycle();
  assert.deepEqual(deviceRow(h, bad.id).server_kinds, []);
  assert.equal(deviceRow(h, bad.id).lease_until, iso(T0 + H));
  assert.deepEqual(h.sent.map((x) => x.device), [good.id]);
  const line = h.logs.find((l) => l.event === 'bad_tz');
  assert.equal(line.device, bad.id.slice(0, 8));
  assert.doesNotMatch(JSON.stringify(h.logs), new RegExp(bad.id));
  h.advance(CYCLE_MS);
  await h.s.cycle();
  assert.deepEqual(deviceRow(h, bad.id).server_kinds, []);
  assert.equal(h.calls('PATCH', 'push_devices').filter((c) => c.path.endsWith(bad.id)).length, 1, 'không lật đi lật lại');
});

test('mỗi múi giờ một lần gọi helper; thiết bị khác múi nhận theo múi của nó', async () => {
  const vn = device(1);
  const vn2 = device(2);
  const ar = device(3, { timezone: 'America/Argentina/Buenos_Aires' });
  const h = harness({
    devices: [vn, ar, vn2],
    plan: (req) => ({ ok: true, items: req.mode === 'due' ? [item(req.tz === 'UTC' ? 9 : req.tz.startsWith('Asia') ? 1 : 2)] : [] }),
  });
  await h.s.cycle();
  assert.deepEqual(h.planCalls.map((r) => `${r.mode}:${r.tz}`).sort(), [
    'due:America/Argentina/Buenos_Aires', 'due:Asia/Ho_Chi_Minh', 'upcoming:America/Argentina/Buenos_Aires', 'upcoming:Asia/Ho_Chi_Minh',
  ]);
  const got = Object.fromEntries([vn, vn2, ar].map((d) => [d.id, h.sent.filter((x) => x.device === d.id).map((x) => x.msg.key)]));
  assert.deepEqual(got, { [vn.id]: ['schedule:2026-10-30:1'], [vn2.id]: ['schedule:2026-10-30:1'], [ar.id]: ['schedule:2026-10-30:2'] });
});

// ─── R-F5: một lần đọc mỗi người mỗi chu kỳ, trần song song ──────────────────

test('mỗi người đọc Directus một lần mỗi chu kỳ cho cả hai lượt, đúng fields của helper', async () => {
  const h = harness({ devices: [device(1), device(2, { timezone: 'UTC' })], plan: dueOnly([item(1)]) });
  await h.s.cycle();
  const settingsGets = h.calls('GET', 'notification_settings');
  assert.equal(settingsGets.length, 1);
  assert.equal(settingsGets[0].params.get('fields'), SETTINGS_FIELDS);
  for (const c of COLLECTIONS) {
    const gets = h.calls('GET', c);
    assert.equal(gets.length, 1, c);
    assert.equal(gets[0].params.get('fields'), FIELDS[c]);
  }
  const deliveryGets = h.calls('GET', 'push_deliveries');
  assert.equal(deliveryGets.length, 1);
  assert.equal(deliveryGets[0].params.get('filter[at][_gte]'), iso(T0 - 30 * DAY));
  assert.equal(h.planCalls.length, 4);
});

test('lượt upcoming dùng cùng dữ liệu, kể cả gợi ý vừa gửi ở lượt due', async () => {
  const rec = item(1, { kind: 'recommendation', key: 'rec:2026-10-30' });
  const h = harness({ plan: dueOnly([rec]) });
  await h.s.cycle();
  const upcoming = h.planCalls.find((r) => r.mode === 'upcoming');
  assert.deepEqual(upcoming.sentRecommendations, [{ key: 'rec:2026-10-30', atUtc: iso(T0 - 5 * MIN) }]);
});

test(`giới hạn số người xử lý Directus song song (USER_CONCURRENCY = ${USER_CONCURRENCY})`, async () => {
  const users = Array.from({ length: 10 }, (_, i) => `user-${i}`);
  const h = harness({ devices: users.map((u, i) => device(i, { user: u })), settings: users.map(settingsRow) });
  const inFlight = new Map();
  let max = 0;
  const original = h.fake.handle;
  h.fake.handle = async (url, init) => {
    const u = url.searchParams.get('filter[user_created][_eq]') ?? url.searchParams.get('filter[user][_eq]')
      ?? (url.pathname.endsWith('notification_settings') ? url.searchParams.get('filter[id][_eq]') : null);
    if (u) inFlight.set(u, (inFlight.get(u) ?? 0) + 1);
    max = Math.max(max, [...inFlight.values()].filter((n) => n > 0).length);
    try {
      return await original(url, init);
    } finally {
      if (u) inFlight.set(u, inFlight.get(u) - 1);
    }
  };
  await h.s.cycle();
  assert.equal(USER_CONCURRENCY, 4);
  assert.ok(max <= USER_CONCURRENCY, `thấy ${max} người cùng lúc`);
  assert.ok(max > 1, 'vẫn chạy song song');
  assert.equal(h.calls('GET', 'notification_settings').length, 10);
});

// ─── Hàng đợi và nhịp phút ───────────────────────────────────────────────────

test('hàng đợi: chu kỳ upcoming xếp giờ; nhịp phút chạy đúng người tới giờ, một lần', async () => {
  const da = device(1);
  const db = device(2, { user: 'user-b' });
  const atA = T0 + 10 * MIN;
  const h = harness({
    devices: [da, db], settings: [settingsRow('user-a'), settingsRow('user-b')],
    plan: (req, nowMs = Date.parse(req.nowUtc)) => {
      if (req.userId !== 'user-a') return { ok: true, items: [] };
      const it = item(1, { atUtc: iso(atA), validUntilUtc: iso(atA + H) });
      if (req.mode === 'upcoming') return { ok: true, items: nowMs < atA ? [it] : [] };
      return { ok: true, items: nowMs >= atA ? [it] : [] };
    },
  });
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  const readsAfterCycle = h.fake.calls.length;
  h.advance(5 * MIN);
  await h.s.tick();
  assert.equal(h.fake.calls.length, readsAfterCycle, 'chưa tới giờ: không đọc gì');
  h.advance(5 * MIN);
  await h.s.tick();
  assert.deepEqual(h.sent.map((x) => x.device), [da.id]);
  assert.equal(h.sent[0].at, atA);
  assert.ok(!h.fake.calls.slice(readsAfterCycle).some((c) => c.params.get('filter[user][_eq]') === 'user-b'
    || c.params.get('filter[user_created][_eq]') === 'user-b'), 'không đọc người chưa tới giờ');
  const afterSend = h.fake.calls.length;
  h.advance(MIN);
  await h.s.tick();
  assert.equal(h.fake.calls.length, afterSend, 'đã chạy giờ đó rồi: không chạy lại');
  assert.equal(h.sent.length, 1);
});

test('nhịp phút đọc lại thiết bị: máy vừa bị gỡ thì không gửi', async () => {
  const d = device(1);
  const atA = T0 + 10 * MIN;
  const h = harness({
    devices: [d],
    plan: (req) => {
      const it = item(1, { atUtc: iso(atA), validUntilUtc: iso(atA + H) });
      return { ok: true, items: req.mode === 'upcoming' ? [it] : Date.parse(req.nowUtc) >= atA ? [it] : [] };
    },
  });
  await h.s.cycle();
  h.fake.items.push_devices = [];
  h.advance(10 * MIN);
  await h.s.tick();
  assert.deepEqual(h.sent, []);
});

test('start: chạy chu kỳ ngay, hẹn chu kỳ 15 phút và nhịp 1 phút; stop: huỷ cả hai và đợi việc đang chạy', async () => {
  const h = harness({ plan: dueOnly([item(1)]) });
  h.s.start();
  assert.deepEqual(h.intervals.map((i) => i.ms), [CYCLE_MS, TICK_MS]);
  await new Promise((r) => setImmediate(r)); // chu kỳ đầu đã bắt đầu
  const stopped = h.s.stop();
  assert.ok(stopped instanceof Promise);
  await stopped;
  assert.equal(h.sent.length, 1, 'chu kỳ đầu đã chạy xong trước khi stop trả về');
  assert.deepEqual(h.cleared, [1, 2]);
  h.advance(CYCLE_MS);
  await h.intervals[0].fn();
  await h.s.cycle();
  assert.equal(h.planner.infoCalls, 1, 'sau stop không chạy chu kỳ mới');
});

test('helper không trả info: không gia hạn, không gửi, không đặt lastCycleAt', async () => {
  const d = device(1, { lease_until: iso(T0 + H) });
  const h = harness({ devices: [d], plan: dueOnly([item(1)]) });
  h.planner.info = async () => { throw Object.assign(new Error('exited'), { code: 'exited' }); };
  await h.s.cycle();
  assert.deepEqual(h.sent, []);
  assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
  assert.equal(h.s.lastCycleAt, null);
  assert.ok(h.logs.some((l) => l.event === 'helper_down'));
});

// ─── Helper thật (chỉ khi đặt NOTIFY_PLAN_BIN) ───────────────────────────────

const BIN = process.env.NOTIFY_PLAN_BIN;
test('helper thật: 24 giờ chu kỳ + nhịp, mỗi mục gửi một lần, đúng cửa sổ at ≤ now < validUntil, TTL nguyên', { skip: BIN ? false : 'NOTIFY_PLAN_BIN chưa đặt', timeout: 300_000 }, async () => {
  const { createPlanner } = await import('../src/planner.mjs');
  const real = createPlanner({ bin: BIN });
  try {
    const info = await real.info();
    const d = device(1, { seed_fingerprint: info.fingerprint, lease_until: null });
    // Thứ Sáu 30/10 (day 4) và thứ Bảy (day 5), giờ lẻ để nhắc lịch rơi giữa hai chu kỳ: chỉ nhịp phút gửi đúng giờ.
    const slot = (id, day, time) => ({
      id, user_created: 'user-a', day, time, label: `slot ${id}`, cat: 'aiming', cat_ext: null, cat_ext_at: null,
      updated_at: iso(T0 - 3 * DAY), is_deleted: false,
    });
    const h = harness({ devices: [d], fingerprint: info.fingerprint, extra: { schedule_slots: [slot('s1', 4, '18:07'), slot('s2', 5, '07:22')] } });
    const byDelivery = new Map();
    const dueIds = new Set();
    const upcomingIds = new Set();
    h.planner.info = () => real.info();
    h.planner.plan = async (req) => {
      h.planCalls.push(req);
      const reply = await real.plan(req);
      if (reply.ok) {
        for (const it of reply.items) {
          const id = deliveryIdFor(d.id, it.kind, it.key);
          byDelivery.set(id, it);
          (req.mode === 'due' ? dueIds : upcomingIds).add(id);
        }
      }
      return reply;
    };
    const end = T0 + 24 * H;
    for (let minute = 0; minute < 24 * 60; minute += 1) {
      if (minute % 15 === 0) await h.s.cycle();
      await h.s.tick();
      h.advance(MIN);
    }
    assert.ok(h.sent.length > 0, 'mặc định bật cả bốn loại: có thông báo thật');
    const ids = h.sent.map((x) => x.msg.deliveryId);
    assert.equal(new Set(ids).size, ids.length, 'không gửi trùng');
    for (const x of h.sent) {
      const it = byDelivery.get(x.msg.deliveryId);
      assert.ok(Date.parse(it.atUtc) <= x.at && x.at < Date.parse(it.validUntilUtc), `${it.kind} ngoài cửa sổ`);
      assert.ok(Number.isInteger(x.opts.ttlSeconds) && x.opts.ttlSeconds >= 60);
      assert.equal(x.msg.title, it.title);
      assert.equal(x.msg.notificationId, it.id);
    }
    // Nhắc lịch rơi giữa hai chu kỳ: nhịp phút gửi trong vòng một phút sau giờ hẹn.
    const schedule = h.sent.filter((x) => x.msg.kind === 'schedule');
    assert.equal(schedule.length, 2);
    for (const x of schedule) {
      const lateBy = x.at - Date.parse(byDelivery.get(x.msg.deliveryId).atUtc);
      assert.ok(lateBy >= 0 && lateBy < MIN, `trễ ${lateBy} ms`);
      assert.notEqual((x.at - T0) % CYCLE_MS, 0, 'do nhịp phút gửi, không phải chu kỳ');
    }
    // Đủ: mọi mục helper trả ở lượt due đều được gửi đúng một lần; mọi mục upcoming
    // tới hạn trong 24 giờ mô phỏng cũng vậy.
    const sentIds = new Set(ids);
    assert.deepEqual([...dueIds].filter((id) => !sentIds.has(id)), [], 'mục đến hạn bị bỏ sót');
    const upcomingInWindow = [...upcomingIds].filter((id) => Date.parse(byDelivery.get(id).atUtc) < end);
    assert.ok(upcomingInWindow.length >= 2);
    assert.deepEqual(upcomingInWindow.filter((id) => !sentIds.has(id)), [], 'mục upcoming bị bỏ sót');
    // Gợi ý: một mỗi ngày địa phương. Cửa sổ 09:00 thứ Sáu → 09:00 thứ Bảy (giờ VN) chỉ chứa gợi ý
    // của thứ Sáu; gợi ý thứ Bảy mở lúc 09:00 thứ Bảy = cuối cửa sổ, nên đúng 1.
    const recs = h.sent.filter((x) => x.msg.kind === 'recommendation');
    assert.equal(recs.length, 1);
    assert.match(recs[0].msg.key, /^2026-10-30:/);
    assert.deepEqual(h.logs.filter((l) => l.event === 'plan_failed'), []);
    assert.equal(h.rows('push_deliveries').filter((r) => r.sent_at).length, h.sent.length);
  } finally {
    real.close();
  }
});

test('mục tới hạn trong lúc lượt due chờ thử lại vẫn vào hàng đợi, nhịp phút kế tiếp gửi', async () => {
  const d1 = device(1);
  const d2 = device(2);
  const soon = T0 + 5_000; // tới hạn trong lúc chờ thử lại 5 s
  const later = item(2, { atUtc: iso(soon), validUntilUtc: iso(soon + H) });
  const h = harness({
    devices: [d1, d2],
    plan: (req) => {
      const nowMs = Date.parse(req.nowUtc);
      if (req.mode === 'upcoming') return { ok: true, items: nowMs < soon ? [later] : [] };
      return { ok: true, items: nowMs >= soon ? [later] : [item(1)] };
    },
    send: (dev, msg) => (dev.id === d1.id && msg.key === 'schedule:2026-10-30:1' ? { status: 'retry', code: 503, retryAfterMs: 5000 } : { status: 'sent' }),
  });
  await h.s.cycle(); // lượt due chờ 5 s; mục 2 tới hạn trong lúc đó
  assert.ok(h.now >= soon);
  h.advance(TICK_MS);
  await h.s.tick();
  assert.deepEqual(h.sent.filter((x) => x.msg.key === 'schedule:2026-10-30:2').map((x) => x.device).sort(), [d1.id, d2.id].sort());
});

test('không gia hạn lease khi chưa có notification_settings (app quay về cục bộ khi lease hết)', async () => {
  const d = device(1, { lease_until: iso(T0 + H) });
  const h = harness({ devices: [d], settings: [] });
  await h.s.cycle();
  assert.equal(deviceRow(h, d.id).lease_until, iso(T0 + H));
  assert.deepEqual(h.calls('PATCH', 'push_devices'), []);
});

test('không gia hạn lease cho múi mà lượt due hỏng (bad_data, helper lỗi); múi khác lập được thì vẫn gia hạn', async () => {
  const badData = device(1, { lease_until: iso(T0 + H) });
  const crashed = device(2, { lease_until: iso(T0 + H), timezone: 'UTC' });
  const fine = device(3, { lease_until: iso(T0 + H), timezone: 'America/Argentina/Buenos_Aires' });
  const h = harness({
    devices: [badData, crashed, fine],
    plan: (req) => {
      if (req.tz === 'Asia/Ho_Chi_Minh') return { ok: false, error: 'bad_data', collection: 'drill_logs' };
      if (req.tz === 'UTC') throw Object.assign(new Error('timeout'), { code: 'timeout' });
      return { ok: true, items: [] };
    },
  });
  await h.s.cycle();
  assert.equal(deviceRow(h, badData.id).lease_until, iso(T0 + H));
  assert.equal(deviceRow(h, crashed.id).lease_until, iso(T0 + H));
  assert.equal(deviceRow(h, fine.id).lease_until, iso(T0 + 6 * H));
});

test('chu kỳ đọc lại thiết bị của người đó: máy vừa về local thì không gửi; seed mới thì server_kinds theo seed mới', async () => {
  const goesLocal = device(1, { lease_until: iso(T0 + H) }); // ảnh cũ sẽ gia hạn nó
  const reseeded = device(2, { seed_fingerprint: 'old', server_kinds: ['maintenance', 'schedule', 'streak'] });
  const rec = item(1, { kind: 'recommendation', key: 'rec:2026-10-30' });
  const h = harness({ devices: [goesLocal, reseeded], plan: dueOnly([rec]) });
  h.fake.reply = ({ method, path, url }) => {
    if (method === 'GET' && path === '/items/push_devices' && url.searchParams.get('filter[mode][_eq]') === 'server') {
      const snapshot = h.fake.items.push_devices.map((r) => ({ ...r }));
      // Ngay sau lúc liệt kê: máy 1 chuyển local, máy 2 đăng ký lại với seed khớp helper.
      Object.assign(h.fake.items.push_devices[0], { mode: 'local' });
      Object.assign(h.fake.items.push_devices[1], { seed_fingerprint: 'fp1' });
      return new Response(JSON.stringify({ data: snapshot }), { status: 200, headers: { 'content-type': 'application/json' } });
    }
    return undefined;
  };
  await h.s.cycle();
  assert.deepEqual(h.sent.map((x) => x.device), [reseeded.id]);
  assert.deepEqual(deviceRow(h, reseeded.id).server_kinds, [...KINDS]);
  assert.equal(h.calls('PATCH', 'push_devices').filter((c) => c.path.endsWith(goesLocal.id)).length, 0, 'không đụng máy đã về local');
  assert.equal(h.calls('GET', 'push_devices').filter((c) => c.params.get('filter[user][_eq]') === 'user-a').length, 1, 'một lần đọc thiết bị mỗi người');
});

test('nhịp phút: helper trả bad_tz cho múi của máy thì server_kinds [] cho máy đó, máy khác vẫn gửi', async () => {
  const bad = device(1);
  const good = device(2, { timezone: 'UTC' });
  const atA = T0 + 10 * MIN;
  let badTz = false;
  const h = harness({
    devices: [bad, good],
    plan: (req) => {
      if (badTz && req.tz === 'Asia/Ho_Chi_Minh') return { ok: false, error: 'bad_tz' };
      const it = item(1, { atUtc: iso(atA), validUntilUtc: iso(atA + H) });
      return { ok: true, items: req.mode === 'upcoming' ? [it] : Date.parse(req.nowUtc) >= atA ? [it] : [] };
    },
  });
  await h.s.cycle();
  badTz = true; // bảng múi của helper đổi giữa chừng
  h.advance(10 * MIN);
  await h.s.tick();
  assert.deepEqual(deviceRow(h, bad.id).server_kinds, []);
  assert.deepEqual(h.sent.map((x) => x.device), [good.id]);
  assert.equal(h.logs.find((l) => l.event === 'bad_tz').device, bad.id.slice(0, 8));
});

test('dọn delivery cũ hết cả khi quá 100 dòng (Directus mặc định chỉ 100 dòng mỗi truy vấn)', async () => {
  const old = Array.from({ length: 150 }, (_, i) => ({ id: `o${i}`, user: 'user-a', at: iso(T0 - 40 * DAY), sent_at: null }));
  const h = harness({ enabled: false, deliveries: [...old, { id: 'keep', user: 'user-a', at: iso(T0 - DAY), sent_at: null }] });
  await h.s.cycle();
  assert.deepEqual(h.rows('push_deliveries').map((r) => r.id), ['keep']);
});
