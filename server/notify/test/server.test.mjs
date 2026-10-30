import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';
import { createApp } from '../src/server.mjs';

const WEB = 'https://poolcoachai.kjdybl.easypanel.host';

async function start(t, { config = {}, planner = { healthy: true }, scheduler = { lastCycleAt: null }, lines = [] } = {}) {
  const handler = createApp({
    config: { enabled: true, vapid: { publicKey: 'pub-key', privateKey: 'priv', subject: 'mailto:a@b.test' }, allowedOrigins: [WEB, 'http://localhost:5555'], ...config },
    directus: {}, planner, scheduler, now: () => new Date('2026-10-30T03:00:00Z'), log: (l) => lines.push(l), fetch: async () => { throw new Error('no network'); },
  });
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => server.close(r)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('healthz: enabled, lastCycleAt, helper', async (t) => {
  const base = await start(t, { scheduler: { lastCycleAt: new Date('2026-10-30T02:45:00Z') } });
  const r = await fetch(`${base}/healthz`);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { ok: true, enabled: true, lastCycleAt: '2026-10-30T02:45:00.000Z', helper: 'ok' });
});
test('healthz: chưa có chu kỳ và helper chết', async (t) => {
  const base = await start(t, { config: { enabled: false }, planner: { healthy: false } });
  assert.deepEqual(await (await fetch(`${base}/healthz`)).json(), { ok: true, enabled: false, lastCycleAt: null, helper: 'down' });
});
test('push/config: khoá công khai, CORS chỉ cho nguồn được phép', async (t) => {
  const base = await start(t);
  const ok = await fetch(`${base}/push/config`, { headers: { origin: WEB } });
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { enabled: true, publicKey: 'pub-key' });
  assert.equal(ok.headers.get('access-control-allow-origin'), WEB);
  assert.equal(ok.headers.get('vary'), 'Origin');
  const bad = await fetch(`${base}/push/config`, { headers: { origin: 'https://evil.test' } });
  assert.equal(bad.status, 200);
  assert.equal(bad.headers.get('access-control-allow-origin'), null);
  const none = await fetch(`${base}/push/config`);
  assert.equal(none.headers.get('access-control-allow-origin'), null);
});
test('push/config không lộ khoá riêng', async (t) => {
  const base = await start(t);
  const text = await (await fetch(`${base}/push/config`)).text();
  assert.doesNotMatch(text, /priv/);
});
test('đường dẫn lạ: 404 not_found', async (t) => {
  const base = await start(t);
  const r = await fetch(`${base}/nope`);
  assert.deepEqual([r.status, await r.json()], [404, { error: 'not_found' }]);
  const p = await fetch(`${base}/healthz`, { method: 'POST' });
  assert.equal(p.status, 404);
});

test('request target hỏng: trả 400 và máy chủ vẫn sống', async (t) => {
  const base = await start(t);
  const port = Number(new URL(base).port);
  const raw = await new Promise((resolve, reject) => {
    const s = net.connect(port, '127.0.0.1', () => s.write('GET http://%zz/ HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n'));
    let data = '';
    s.on('data', (c) => { data += c; });
    s.on('end', () => resolve(data));
    s.on('error', reject);
  });
  assert.match(raw, /^HTTP\/1\.1 400/);
  const r = await fetch(`${base}/healthz`);
  assert.equal(r.status, 200);
});

// ─── Task 10: đăng ký, huỷ, ack ────────────────────────────────────────────
import { readFileSync } from 'node:fs';
import { createDirectus } from '../src/directus.mjs';
import { deviceIdFor, deliveryIdFor } from '../src/devices.mjs';
import { fakeDirectus, fakeFetch, DIRECTUS, SERVICE_TOKEN } from './fakes.mjs';

const BODY = () => JSON.parse(readFileSync(new URL('../../../test/fixtures/push_register_body.json', import.meta.url), 'utf8'));
const NOW = new Date('2026-10-30T03:00:00Z');

async function startPush(t, { items = {}, config = {}, planner, now = () => NOW, users } = {}) {
  const fake = fakeDirectus({ items, ...(users ? { users } : {}) });
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fakeFetch({ directus: fake }), sleep: async () => {} });
  const lines = [];
  const handler = createApp({
    config: { enabled: true, vapid: { publicKey: 'pub-key', privateKey: 'priv', subject: 'mailto:a@b.test' }, allowedOrigins: [WEB], ...config },
    directus, planner: planner ?? { healthy: true, info: async () => ({ fingerprint: 'seed-fp-0001' }) },
    scheduler: { lastCycleAt: null }, now, log: (l) => lines.push(l), fetch: async () => { throw new Error('no network'); },
  });
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => server.close(r)));
  return { base: `http://127.0.0.1:${server.address().port}`, fake, lines };
}
const post = (base, path, body, token = 'tok-a', extra = {}) => fetch(`${base}${path}`, {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), ...extra },
  body: typeof body === 'string' ? body : JSON.stringify(body),
});
const writes = (fake, coll) => fake.calls.filter((c) => c.path.startsWith(`/items/${coll}`) && c.method !== 'GET');
const ID = deviceIdFor(BODY().endpoint);

test('đăng ký mới: 200, deviceId = sha256(endpoint), lease 6 giờ, đủ bốn loại khi dấu vân tay khớp', async (t) => {
  const { base, fake } = await startPush(t);
  const r = await post(base, '/push/devices', BODY());
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), {
    deviceId: ID, serverKinds: ['recommendation', 'maintenance', 'schedule', 'streak'],
    leaseUntil: '2026-10-30T09:00:00.000Z', serverNow: '2026-10-30T03:00:00.000Z', enabled: true,
  });
  const create = fake.calls.find((c) => c.method === 'POST' && c.path === '/items/push_devices');
  assert.deepEqual(create.body, {
    id: ID, user: 'user-a', channel: 'web', platform: 'web', endpoint: BODY().endpoint,
    key_p256dh: BODY().keys.p256dh, key_auth: BODY().keys.auth, timezone: 'Asia/Ho_Chi_Minh',
    seed_fingerprint: 'seed-fp-0001', mode: 'server', server_kinds: ['recommendation', 'maintenance', 'schedule', 'streak'],
    lease_until: '2026-10-30T09:00:00.000Z', last_seen_at: '2026-10-30T03:00:00.000Z', failure_count: 0, created_at: '2026-10-30T03:00:00.000Z',
  });
});
test('đăng ký lại: PATCH ghi lại endpoint và khoá, không đặt created_at', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_devices: [{ id: ID, user: 'user-a', failure_count: 3 }] } });
  assert.equal((await post(base, '/push/devices', BODY())).status, 200);
  const patch = fake.calls.find((c) => c.method === 'PATCH' && c.path === `/items/push_devices/${ID}`);
  assert.equal(patch.body.endpoint, BODY().endpoint);
  assert.equal(patch.body.key_p256dh, BODY().keys.p256dh);
  assert.equal(patch.body.key_auth, BODY().keys.auth);
  assert.equal(patch.body.failure_count, 0);
  assert.equal('created_at' in patch.body, false);
  assert.equal(writes(fake, 'push_devices').some((c) => c.method === 'POST'), false);
});
test('dấu vân tay khác: serverKinds không có recommendation', async (t) => {
  const { base } = await startPush(t, { planner: { healthy: true, info: async () => ({ fingerprint: 'other' }) } });
  assert.deepEqual((await (await post(base, '/push/devices', BODY())).json()).serverKinds, ['maintenance', 'schedule', 'streak']);
});
test('PUSH_ENABLED=false: 200, serverKinds rỗng, leaseUntil null', async (t) => {
  const { base, fake } = await startPush(t, { config: { enabled: false } });
  const j = await (await post(base, '/push/devices', BODY())).json();
  assert.deepEqual([j.enabled, j.serverKinds, j.leaseUntil], [false, [], null]);
  assert.equal(fake.calls.find((c) => c.method === 'POST' && c.path === '/items/push_devices').body.lease_until, null);
  assert.equal(writes(fake, 'push_deliveries').length, 0);
});
test('máy dùng chung: B đăng ký cùng endpoint thì dòng chuyển sang B', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_devices: [{ id: ID, user: 'user-a' }] } });
  assert.equal((await post(base, '/push/devices', BODY(), 'tok-b')).status, 200);
  assert.equal(fake.calls.find((c) => c.method === 'PATCH').body.user, 'user-b');
});
test('endpoint không phải dịch vụ push: 400 field endpoint, không gọi Directus', async (t) => {
  const { base, fake } = await startPush(t);
  for (const endpoint of ['http://127.0.0.1/x', 'https://evil.example/x']) {
    const r = await post(base, '/push/devices', { ...BODY(), endpoint });
    assert.deepEqual([r.status, await r.json()], [400, { error: 'invalid', field: 'endpoint' }]);
  }
  assert.equal(fake.calls.length, 0);
});
test('thân quá 8 KB: 413; JSON hỏng: 400; tz lạ: 400 timezone; kênh fcm: 400 unsupported_channel', async (t) => {
  const { base, fake } = await startPush(t);
  let r = await post(base, '/push/devices', { ...BODY(), pad: 'x'.repeat(9000) });
  assert.deepEqual([r.status, await r.json()], [413, { error: 'invalid', field: 'body' }]);
  r = await post(base, '/push/devices', '{nope');
  assert.deepEqual([r.status, await r.json()], [400, { error: 'invalid', field: 'body' }]);
  r = await post(base, '/push/devices', { ...BODY(), timezone: 'Mars/Base' });
  assert.deepEqual([r.status, await r.json()], [400, { error: 'invalid', field: 'timezone' }]);
  r = await post(base, '/push/devices', { ...BODY(), channel: 'fcm' });
  assert.deepEqual([r.status, await r.json()], [400, { error: 'unsupported_channel' }]);
  assert.equal(fake.calls.length, 0);
});
test('khoá VAPID khác: 409 vapid_mismatch', async (t) => {
  const { base, fake } = await startPush(t);
  const r = await post(base, '/push/devices', { ...BODY(), vapidPublicKey: 'old' });
  assert.deepEqual([r.status, await r.json()], [409, { error: 'vapid_mismatch' }]);
  assert.equal(writes(fake, 'push_devices').length, 0);
});
test('không token hoặc token sai: 401; Directus sập: 503; helper sập: 503', async (t) => {
  const { base, fake } = await startPush(t);
  assert.equal((await post(base, '/push/devices', BODY(), null)).status, 401);
  assert.equal((await post(base, '/push/devices', BODY(), 'bad')).status, 401);
  assert.equal(writes(fake, 'push_devices').length, 0);
  fake.down = true;
  assert.equal((await post(base, '/push/devices', BODY())).status, 503);
  const h1 = await startPush(t, { planner: { healthy: false, info: async () => { throw new Error('down'); } } });
  assert.equal((await post(h1.base, '/push/devices', BODY())).status, 503);
  const h2 = await startPush(t, { planner: { healthy: false, info: async () => ({ fingerprint: 'seed-fp-0001' }) } });
  assert.equal((await post(h2.base, '/push/devices', BODY())).status, 503);
  assert.equal(writes(h1.fake, 'push_devices').length, 0);
});
test('31 lần đăng ký trong một giờ: lần thứ 31 bị 429; người khác không bị', async (t) => {
  const { base } = await startPush(t);
  for (let i = 0; i < 30; i += 1) assert.equal((await post(base, '/push/devices', BODY())).status, 200, `lần ${i + 1}`);
  const r = await post(base, '/push/devices', BODY());
  assert.deepEqual([r.status, await r.json()], [429, { error: 'rate_limited' }]);
  assert.equal((await post(base, '/push/devices', BODY(), 'tok-b')).status, 200);
});
test('thiết bị thứ 11: xoá thiết bị lâu không thấy nhất của người đó', async (t) => {
  const rows = Array.from({ length: 10 }, (_, i) => ({ id: `d${i}`, user: 'user-a', last_seen_at: `2026-10-${String(10 + i).padStart(2, '0')}T00:00:00Z` }));
  const { base, fake } = await startPush(t, { items: { push_devices: [...rows].reverse() } });
  assert.equal((await post(base, '/push/devices', BODY())).status, 200);
  const dels = fake.calls.filter((c) => c.method === 'DELETE' && c.path === '/items/push_devices');
  assert.equal(dels.length, 1);
  assert.deepEqual(dels[0].body, ['d0']);
});
test('shownToday: giành trước dòng cho loại server lo, bỏ qua loại ngoài serverKinds', async (t) => {
  const { base, fake } = await startPush(t, { planner: { healthy: true, info: async () => ({ fingerprint: 'other' }) } });
  const body = { ...BODY(), shownToday: [{ kind: 'streak', key: '2026-10-30' }, { kind: 'recommendation', key: 'r' }] };
  assert.equal((await post(base, '/push/devices', body)).status, 200);
  const claims = fake.calls.filter((c) => c.method === 'POST' && c.path === '/items/push_deliveries');
  assert.equal(claims.length, 1);
  assert.equal(claims[0].body.id, deliveryIdFor(ID, 'streak', '2026-10-30'));
  assert.equal(claims[0].body.device, ID);
  assert.equal(claims[0].body.user, 'user-a');
});
test('shownToday: giành trước lỗi thì đăng ký vẫn 200', async (t) => {
  const { base, fake } = await startPush(t);
  fake.reply = ({ method, path }) => (method === 'POST' && path === '/items/push_deliveries' ? new Response('{}', { status: 500 }) : undefined);
  assert.equal((await post(base, '/push/devices', BODY())).status, 200);
});

const del = (base, id, token = 'tok-a') => fetch(`${base}/push/devices/${id}`, { method: 'DELETE', headers: token ? { authorization: `Bearer ${token}` } : {} });
test('DELETE thiết bị của mình: 204 và xoá', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_devices: [{ id: ID, user: 'user-a' }] } });
  assert.equal((await del(base, ID)).status, 204);
  assert.deepEqual(fake.calls.find((c) => c.method === 'DELETE').body, [ID]);
});
test('DELETE thiết bị của người khác hoặc không có: 204 nhưng không xoá', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_devices: [{ id: ID, user: 'user-b' }] } });
  assert.equal((await del(base, ID)).status, 204);
  assert.equal((await del(base, 'f'.repeat(64))).status, 204);
  assert.equal(fake.calls.filter((c) => c.method === 'DELETE').length, 0);
});
test('DELETE id sai dạng: 204, không gọi Directus (kể cả xác thực)', async (t) => {
  const { base, fake } = await startPush(t);
  for (const id of ['abc', 'Z'.repeat(64), '..%2F..', 'A'.repeat(64)]) assert.equal((await del(base, id)).status, 204, id);
  assert.equal(fake.calls.length, 0);
});
test('DELETE không token: 401; Directus sập: 503', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_devices: [{ id: ID, user: 'user-a' }] } });
  assert.equal((await del(base, ID, null)).status, 401);
  fake.down = true;
  assert.equal((await del(base, ID)).status, 503);
});

const DID = deliveryIdFor(ID, 'streak', '2026-10-30');
const ack = (base, body) => post(base, '/push/ack', body, null, { 'content-type': 'text/plain' });
test('DELETE và ack bị giới hạn theo IP', async (t) => {
  const { base } = await startPush(t);
  let last;
  for (let i = 0; i < 61; i += 1) last = await del(base, ID, null);
  assert.equal(last.status, 429);
  const a = await startPush(t);
  for (let i = 0; i < 61; i += 1) last = await ack(a.base, { endpoint: BODY().endpoint, deliveryId: DID });
  assert.equal(last.status, 429);
});
test('ack đúng endpoint: ghi shown_at và last_ack_at một lần', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_deliveries: [{ id: DID, device: ID, shown_at: null }] } });
  const r = await ack(base, { endpoint: BODY().endpoint, deliveryId: DID });
  assert.equal(r.status, 204);
  const dp = fake.calls.find((c) => c.method === 'PATCH' && c.path === `/items/push_deliveries/${DID}`);
  assert.deepEqual(dp.body, { shown_at: '2026-10-30T03:00:00.000Z' });
  const vp = fake.calls.find((c) => c.method === 'PATCH' && c.path === `/items/push_devices/${ID}`);
  assert.deepEqual(vp.body, { last_ack_at: '2026-10-30T03:00:00.000Z' });
  assert.equal(fake.calls.some((c) => c.auth !== `Bearer ${SERVICE_TOKEN}`), false);
});
test('ack đã có shown_at: 204, không ghi lại', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_deliveries: [{ id: DID, device: ID, shown_at: '2026-10-30T02:00:00Z' }] } });
  assert.equal((await ack(base, { endpoint: BODY().endpoint, deliveryId: DID })).status, 204);
  assert.equal(writes(fake, 'push_deliveries').length + writes(fake, 'push_devices').length, 0);
});
test('ack giả (endpoint khác), id sai dạng, bản ghi không có: 204, không ghi', async (t) => {
  const { base, fake } = await startPush(t, { items: { push_deliveries: [{ id: DID, device: ID, shown_at: null }] } });
  assert.equal((await ack(base, { endpoint: 'https://fcm.googleapis.com/fcm/send/other', deliveryId: DID })).status, 204);
  assert.equal((await ack(base, { endpoint: BODY().endpoint, deliveryId: 'x' })).status, 204);
  assert.equal((await ack(base, { endpoint: BODY().endpoint, deliveryId: 'a'.repeat(64) })).status, 204);
  assert.equal((await ack(base, '{nope')).status, 204);
  assert.equal((await ack(base, { endpoint: 5, deliveryId: DID })).status, 204);
  assert.equal((await ack(base, { pad: 'x'.repeat(3000) })).status, 204);
  assert.equal(writes(fake, 'push_deliveries').length + writes(fake, 'push_devices').length, 0);
});
test('ack khi Directus sập: vẫn 204', async (t) => {
  const { base, fake } = await startPush(t);
  fake.down = true;
  assert.equal((await ack(base, { endpoint: BODY().endpoint, deliveryId: DID })).status, 204);
});

test('CORS: chỉ origin được phép có Access-Control-Allow-Origin; OPTIONS 204', async (t) => {
  const { base, fake } = await startPush(t);
  for (const path of ['/push/devices', `/push/devices/${ID}`, '/push/ack']) {
    const ok = await fetch(`${base}${path}`, { method: 'OPTIONS', headers: { origin: WEB } });
    assert.equal(ok.status, 204);
    assert.equal(ok.headers.get('access-control-allow-origin'), WEB);
    assert.equal(ok.headers.get('access-control-allow-methods'), 'GET, POST, DELETE');
    assert.equal(ok.headers.get('access-control-allow-headers'), 'authorization, content-type');
    const bad = await fetch(`${base}${path}`, { method: 'OPTIONS', headers: { origin: 'https://evil.test' } });
    assert.equal(bad.status, 204);
    assert.equal(bad.headers.get('access-control-allow-origin'), null);
    assert.equal(bad.headers.get('access-control-allow-methods'), null);
  }
  const post1 = await post(base, '/push/devices', BODY(), 'tok-a', { origin: WEB });
  assert.equal(post1.headers.get('access-control-allow-origin'), WEB);
  const post2 = await post(base, '/push/devices', BODY(), 'tok-a', { origin: 'https://evil.test' });
  assert.equal(post2.headers.get('access-control-allow-origin'), null);
  assert.equal(fake.calls.filter((c) => c.method === 'OPTIONS').length, 0);
});

test('nhật ký không chứa endpoint, khoá hay token', async (t) => {
  const { base, lines } = await startPush(t, { items: { push_deliveries: [{ id: DID, device: ID, shown_at: null }] } });
  await post(base, '/push/devices', BODY());
  await post(base, '/push/devices', { ...BODY(), endpoint: 'https://evil.example/x' });
  await post(base, '/push/devices', BODY(), 'bad-token-xyz');
  await del(base, ID);
  await ack(base, { endpoint: BODY().endpoint, deliveryId: DID });
  assert.ok(lines.length >= 5);
  const all = lines.join('\n');
  for (const secret of [BODY().endpoint, 'evil.example', BODY().keys.p256dh, BODY().keys.auth, 'tok-a', 'bad-token-xyz', 'user-a', ID]) {
    assert.equal(all.includes(secret), false, secret);
  }
  const first = JSON.parse(lines[0]);
  assert.deepEqual([first.method, first.path, first.status], ['POST', '/push/devices', 200]);
  assert.match(first.user, /^[0-9a-f]{16}$/);
  assert.equal(typeof first.ms, 'number');
  assert.ok(lines.some((l) => JSON.parse(l).path === '/push/devices/:id'));
});
