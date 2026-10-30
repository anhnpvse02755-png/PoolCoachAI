import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { deviceIdFor, serverKindsFor, validateRegister, RequestError } from '../src/devices.mjs';
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
