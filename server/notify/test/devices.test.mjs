import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { deviceIdFor, serverKindsFor, validateRegister, RequestError, createRateLimiter, ipBucket } from '../src/devices.mjs';
import { KINDS } from '../src/limits.mjs';

const fixture = () => JSON.parse(readFileSync(new URL('../../../test/fixtures/push_register_body.json', import.meta.url), 'utf8'));
const field = (body) => { try { validateRegister(body); } catch (e) { assert.ok(e instanceof RequestError); return [e.field, e.code]; } return null; };

test('deviceIdFor là sha256 hex', () => {
  assert.equal(deviceIdFor('abc'), createHash('sha256').update('abc').digest('hex'));
});
test('serverKindsFor', () => {
  assert.deepEqual(serverKindsFor({ seedFingerprint: 'a', enabled: false, helperFingerprint: 'a' }), []);
  assert.deepEqual(serverKindsFor({ seedFingerprint: 'a', enabled: true, helperFingerprint: 'a' }), KINDS);
  assert.deepEqual(serverKindsFor({ seedFingerprint: 'b', enabled: true, helperFingerprint: 'a' }), ['maintenance', 'schedule', 'streak']);
  assert.deepEqual(serverKindsFor({ seedFingerprint: null, enabled: true, helperFingerprint: 'a' }), ['maintenance', 'schedule', 'streak']);
});
test('validateRegister: thân mẫu hợp lệ, đọc keys.p256dh/keys.auth', () => {
  const f = fixture();
  const v = validateRegister(f);
  assert.equal(v.channel, 'web');
  assert.equal(v.endpoint, f.endpoint);
  assert.equal(v.p256dh, f.keys.p256dh);
  assert.equal(v.auth, f.keys.auth);
  assert.equal(v.timezone, 'Asia/Ho_Chi_Minh');
  assert.equal(v.seedFingerprint, 'seed-fp-0001');
  assert.equal(v.vapidPublicKey, 'pub-key');
  assert.deepEqual(v.shownToday, f.shownToday);
});
test('validateRegister: seedFingerprint thiếu là null, shownToday thiếu là []', () => {
  const f = fixture(); delete f.seedFingerprint; delete f.shownToday;
  const v = validateRegister(f);
  assert.equal(v.seedFingerprint, null);
  assert.deepEqual(v.shownToday, []);
});
test('validateRegister: kênh', () => {
  assert.deepEqual(field({ ...fixture(), channel: 'fcm' }), ['channel', 'unsupported_channel']);
  assert.deepEqual(field({ ...fixture(), channel: 'x' }), ['channel', 'invalid']);
});
test('validateRegister: endpoint lạ', () => {
  for (const endpoint of ['http://fcm.googleapis.com/x', 'https://evil.example/x', 'https://127.0.0.1/x', 'https://fcm.googleapis.com:8443/x',
    'https://u:p@fcm.googleapis.com/x', 'https://fcm.googleapis.com', `https://fcm.googleapis.com/${'a'.repeat(1100)}`, 5, null]) {
    assert.deepEqual(field({ ...fixture(), endpoint }), ['endpoint', 'invalid'], String(endpoint).slice(0, 40));
  }
});
test('validateRegister: khoá, múi giờ, vân tay, vapid', () => {
  assert.deepEqual(field({ ...fixture(), keys: undefined }), ['keys', 'invalid']);
  assert.deepEqual(field({ ...fixture(), keys: { p256dh: 'a b', auth: 'x' } }), ['keys.p256dh', 'invalid']);
  assert.deepEqual(field({ ...fixture(), keys: { p256dh: 'x', auth: '' } }), ['keys.auth', 'invalid']);
  assert.deepEqual(field({ ...fixture(), keys: { p256dh: 'x'.repeat(201), auth: 'x' } }), ['keys.p256dh', 'invalid']);
  assert.deepEqual(field({ ...fixture(), timezone: 'Mars/Base' }), ['timezone', 'invalid']);
  assert.deepEqual(field({ ...fixture(), timezone: 3 }), ['timezone', 'invalid']);
  assert.deepEqual(field({ ...fixture(), seedFingerprint: 'x'.repeat(65) }), ['seedFingerprint', 'invalid']);
  assert.deepEqual(field({ ...fixture(), seedFingerprint: 4 }), ['seedFingerprint', 'invalid']);
  assert.deepEqual(field({ ...fixture(), vapidPublicKey: undefined }), ['vapidPublicKey', 'invalid']);
  assert.deepEqual(field(null), ['body', 'invalid']);
  assert.deepEqual(field([]), ['body', 'invalid']);
});
test('validateRegister: shownToday', () => {
  const bad = [
    'x', [{ kind: 'nope', key: 'k' }], [{ kind: 'streak', key: 5 }], [{ kind: 'streak', key: 'k'.repeat(201) }], [null],
    Array.from({ length: 51 }, () => ({ kind: 'streak', key: 'k' })),
  ];
  for (const shownToday of bad) assert.deepEqual(field({ ...fixture(), shownToday }), ['shownToday', 'invalid']);
  const ok = Array.from({ length: 50 }, (_, i) => ({ kind: 'streak', key: `k${i}` }));
  assert.equal(validateRegister({ ...fixture(), shownToday: ok }).shownToday.length, 50);
});

test('múi giờ: giữ nguyên chữ người gửi, phải đúng chữ hoa/thường IANA, từ chối độ lệch và tên lạ', () => {
  const tz = (timezone) => validateRegister({ ...fixture(), timezone }).timezone;
  assert.equal(tz('Asia/Ho_Chi_Minh'), 'Asia/Ho_Chi_Minh');
  assert.equal(tz('UTC'), 'UTC');
  assert.equal(tz('America/Argentina/Buenos_Aires'), 'America/Argentina/Buenos_Aires');
  for (const bad of ['asia/ho_chi_minh', 'utc', 'ASIA/HO_CHI_MINH', 'Asia/ho_chi_minh', 'A/B/C/D', '+07:00', '-0500', 'GMT+7', 'EST5EDT', 'Mars/Base', '', 'Asia', 'Asia/', '/Asia/Saigon', 'a'.repeat(70)]) {
    assert.deepEqual(field({ ...fixture(), timezone: bad }), ['timezone', 'invalid'], bad);
  }
});
test('ipBucket: IPv4 giữ nguyên, IPv6 gộp theo /64, ánh xạ IPv4 về IPv4', () => {
  assert.equal(ipBucket('203.0.113.9'), '203.0.113.9');
  assert.equal(ipBucket('::ffff:203.0.113.9'), '203.0.113.9');
  assert.equal(ipBucket('2001:db8:1:2:aaaa:bbbb:cccc:dddd'), ipBucket('2001:0DB8:0001:0002::1'));
  assert.notEqual(ipBucket('2001:db8:1:2::1'), ipBucket('2001:db8:1:3::1'));
});
test('rateLimiter: cửa sổ trượt, trần số khoá, quét hết hạn mỗi cửa sổ, loại khoá cũ nhất', () => {
  let t = 0;
  const lim = createRateLimiter({ max: 2, windowMs: 1000, now: () => new Date(t), maxKeys: 3 });
  assert.deepEqual([lim.hit('a'), lim.hit('a'), lim.hit('a')], [true, true, false]);
  t = 1001;
  assert.equal(lim.hit('a'), true);
  for (const k of ['b', 'c', 'd', 'e']) lim.hit(k);
  assert.ok(lim.size() <= 3, 'trần số khoá');
  t = 5000;
  lim.hit('z');
  assert.equal(lim.size(), 1, 'đã quét các khoá hết hạn');
  const l2 = createRateLimiter({ max: 1, windowMs: 100000, now: () => new Date(t), maxKeys: 2 });
  l2.hit('x'); l2.hit('y'); l2.hit('w');
  assert.equal(l2.hit('x'), true, 'x là khoá cũ nhất nên đã bị loại');
  assert.equal(l2.hit('w'), false, 'w còn trong bộ đếm');
});
