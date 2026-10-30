import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDirectus, DirectusError } from '../src/directus.mjs';
import { DIRECTUS, SERVICE_TOKEN, fakeDirectus, fakeFetch, errorResponse } from './fakes.mjs';

function setup(opts = {}, extra = {}) {
  const d = fakeDirectus(opts);
  const sleeps = [];
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fakeFetch({ directus: d }),
    sleep: async (ms) => { sleeps.push(ms); }, ...extra });
  return { d, directus, sleeps };
}
const last = (d) => d.calls[d.calls.length - 1];

const FIELDS = {
  drill_logs: 'id,date', timer_sessions: 'id,date', schedule_slots: 'id,day', cue_equipment: 'id,name',
  pool_matches: 'id,game_type', bu_tests: 'id,started_at', bu_drill_results: 'id,score',
};

test('readUserData: mỗi collection một GET với fields và filter[user_created][_eq]', async () => {
  const { d, directus } = setup({ items: { drill_logs: [{ id: 'l1' }], pool_matches: [{ id: 'm1' }] } });
  const data = await directus.readUserData('user-a', FIELDS);
  assert.deepEqual(Object.keys(data).sort(), Object.keys(FIELDS).sort());
  assert.deepEqual(data.drill_logs, [{ id: 'l1' }]);
  assert.deepEqual(data.bu_tests, []);
  assert.equal(d.calls.length, 7);
  for (const c of d.calls) {
    const coll = c.path.replace('/items/', '');
    assert.equal(c.method, 'GET');
    assert.equal(c.params.get('filter[user_created][_eq]'), 'user-a');
    assert.equal(c.params.get('fields'), FIELDS[coll]);
    assert.equal(c.params.get('limit'), '-1');
    assert.equal(c.auth, `Bearer ${SERVICE_TOKEN}`);
  }
});
test('readSettings: dòng của người chơi, hoặc null', async () => {
  const { d, directus } = setup({ items: { notification_settings: [{ id: 'user-a', streak: true }] } });
  assert.deepEqual(await directus.readSettings('user-a', 'id,streak'), { id: 'user-a', streak: true });
  assert.equal(last(d).path, '/items/notification_settings');
  assert.equal(last(d).params.get('filter[id][_eq]'), 'user-a');
  assert.equal(last(d).params.get('fields'), 'id,streak');
  assert.equal(await directus.readSettings('user-b', 'id'), null);
});
test('thiết bị: danh sách server, theo người chơi, một dòng, tạo, sửa, xoá nhiều', async () => {
  const { d, directus } = setup({ items: { push_devices: [{ id: 'dev1' }] } });
  await directus.listServerDevices();
  assert.equal(last(d).path, '/items/push_devices');
  assert.equal(last(d).params.get('filter[mode][_eq]'), 'server');
  assert.equal(last(d).params.get('limit'), '-1');
  await directus.devicesOfUser('user-a');
  assert.equal(last(d).params.get('filter[user][_eq]'), 'user-a');
  assert.deepEqual(await directus.getDevice('dev1'), { id: 'dev1' });
  assert.equal(last(d).path, '/items/push_devices');
  assert.equal(last(d).params.get('filter[id][_eq]'), 'dev1');
  assert.equal(last(d).params.get('limit'), '1');
  await directus.createDevice({ id: 'dev2', user: 'user-a' });
  assert.deepEqual([last(d).method, last(d).path, last(d).body], ['POST', '/items/push_devices', { id: 'dev2', user: 'user-a' }]);
  await directus.updateDevice('dev1', { failure_count: 2 });
  assert.deepEqual([last(d).method, last(d).path, last(d).body], ['PATCH', '/items/push_devices/dev1', { failure_count: 2 }]);
  await directus.deleteDevices(['a', 'b']);
  assert.deepEqual([last(d).method, last(d).path, last(d).body], ['DELETE', '/items/push_devices', ['a', 'b']]);
  const n = d.calls.length;
  await directus.deleteDevices([]);
  assert.equal(d.calls.length, n);
});
test('getDevice/getDelivery dùng truy vấn danh sách: [] là null, 403 trên danh sách là lỗi thật', async () => {
  const { directus } = setup({ items: { push_devices: [], push_deliveries: [] } });
  assert.equal(await directus.getDevice('none'), null);
  assert.equal(await directus.getDelivery('none'), null);
  const { d: d2, directus: dir2 } = setup();
  d2.reply = () => errorResponse(403, 'FORBIDDEN');
  await assert.rejects(dir2.getDevice('x'), (e) => e.status === 403);
  await assert.rejects(dir2.getDelivery('x'), (e) => e.status === 403);
});
test('nhật ký gửi: theo người chơi và mốc, sửa, xoá trước một mốc', async () => {
  const { d, directus } = setup({ items: { push_deliveries: [{ id: 'x1' }] } });
  assert.deepEqual(await directus.deliveriesOfUser('user-a', '2026-10-30T00:00:00.000Z'), [{ id: 'x1' }]);
  assert.equal(last(d).params.get('filter[user][_eq]'), 'user-a');
  assert.equal(last(d).params.get('filter[at][_gte]'), '2026-10-30T00:00:00.000Z');
  await directus.updateDelivery('x1', { shown_at: 'now' });
  assert.deepEqual([last(d).method, last(d).path], ['PATCH', '/items/push_deliveries/x1']);
  await directus.deleteDeliveriesBefore('2026-09-30T00:00:00.000Z');
  assert.equal(last(d).method, 'DELETE');
  assert.equal(last(d).path, '/items/push_deliveries');
  assert.deepEqual(last(d).body, { query: { filter: { at: { _lt: '2026-09-30T00:00:00.000Z' } } } });
  assert.deepEqual(await directus.getDelivery('x1'), { id: 'x1', shown_at: 'now' });
});
test('claimDelivery: true khi tạo được, false khi RECORD_NOT_UNIQUE, lỗi khác ném', async () => {
  const { d, directus } = setup();
  assert.equal(await directus.claimDelivery({ id: 'a' }), true);
  d.reply = ({ method }) => (method === 'POST' ? errorResponse(400, 'RECORD_NOT_UNIQUE') : undefined);
  assert.equal(await directus.claimDelivery({ id: 'a' }), false);
  d.reply = ({ method }) => (method === 'POST' ? errorResponse(500, 'INTERNAL_SERVER_ERROR') : undefined);
  await assert.rejects(directus.claimDelivery({ id: 'a' }), (e) => e instanceof DirectusError && e.status === 500);
});
test('Directus không tới được: DirectusError(0, unreachable)', async () => {
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: async () => { throw new TypeError('fetch failed'); } });
  await assert.rejects(directus.listServerDevices(), (e) => e instanceof DirectusError && e.status === 0 && e.code === 'unreachable');
  await assert.rejects(directus.userIdForToken('t'), (e) => e.status === 0 && e.code === 'unreachable');
});
test('userIdForToken: id, hoặc null khi 401/403', async () => {
  const { directus, d } = setup();
  assert.equal(await directus.userIdForToken('tok-a'), 'user-a');
  assert.equal(await directus.userIdForToken('sai'), null);
  assert.equal(last(d).auth, 'Bearer sai');
});
test('429: thử lại theo Retry-After, giới hạn số lần', async () => {
  const { d, directus, sleeps } = setup({ items: { push_devices: [{ id: 'z' }] } });
  let n = 0;
  d.reply = () => (++n <= 2 ? errorResponse(429, 'REQUESTS_EXCEEDED', { 'retry-after': '2' }) : undefined);
  assert.deepEqual(await directus.listServerDevices(), [{ id: 'z' }]);
  assert.deepEqual(sleeps, [2000, 2000]);
  // Luôn 429: dừng sau số lần tối đa, ném lỗi 429.
  d.calls.length = 0; sleeps.length = 0;
  d.reply = () => errorResponse(429, 'REQUESTS_EXCEEDED', { 'retry-after': '1' });
  await assert.rejects(directus.listServerDevices(), (e) => e.status === 429 && e.code === 'REQUESTS_EXCEEDED');
  assert.equal(d.calls.length, 4);
  assert.equal(sleeps.length, 3);
});
test('429 không có hoặc có Retry-After quá lớn: chờ có chặn trên', async () => {
  const { d, directus, sleeps } = setup({ items: { push_devices: [] } });
  let n = 0;
  d.reply = () => {
    n += 1;
    if (n === 1) return errorResponse(429, 'REQUESTS_EXCEEDED');
    if (n === 2) return errorResponse(429, 'REQUESTS_EXCEEDED', { 'retry-after': '3600' });
    return undefined;
  };
  await directus.listServerDevices();
  assert.equal(sleeps.length, 2);
  assert.deepEqual(sleeps, [1000, 10_000]);
});
test('thân không phải JSON: DirectusError(502, BAD_BODY)', async () => {
  const { d, directus } = setup();
  d.reply = () => new Response('<html>', { status: 200 });
  await assert.rejects(directus.listServerDevices(), (e) => e.status === 502 && e.code === 'BAD_BODY');
});
test('thiếu fields của một collection: ném lỗi, không gọi Directus', async () => {
  const { d, directus } = setup();
  const { bu_tests, ...partial } = FIELDS;
  await assert.rejects(directus.readUserData('user-a', partial), /bu_tests/);
  assert.equal(d.calls.length, 0);
  void bu_tests;
});
test('Retry-After dạng ngày HTTP được hiểu', async () => {
  const fixedNow = Date.parse('2026-10-30T03:00:00Z');
  const { d, directus, sleeps } = setup({ items: { push_devices: [] } }, { nowMs: () => fixedNow });
  let n = 0;
  d.reply = () => (++n === 1 ? errorResponse(429, 'REQUESTS_EXCEEDED', { 'retry-after': new Date(fixedNow + 4000).toUTCString() }) : undefined);
  await directus.listServerDevices();
  assert.deepEqual(sleeps, [4000]);
});
test('hết giờ chờ: DirectusError(0, unreachable)', async () => {
  const slow = (url, init) => new Promise((_, reject) => init.signal.addEventListener('abort', () => reject(init.signal.reason)));
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: slow, timeoutMs: 20 });
  await assert.rejects(directus.listServerDevices(), (e) => e instanceof DirectusError && e.status === 0 && e.code === 'unreachable');
});
