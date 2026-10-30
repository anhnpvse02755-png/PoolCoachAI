import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.mjs';

const base = {
  DIRECTUS_URL: 'https://directus.test/',
  PUSH_SERVICE_TOKEN: 'secret-service-token',
  ALLOWED_ORIGINS: 'https://poolcoachai.kjdybl.easypanel.host, http://localhost:5555,',
  PUBLIC_URL: 'https://notify.example.test/',
  VAPID_PUBLIC_KEY: 'pub-key-value',
  VAPID_PRIVATE_KEY: 'secret-private-key',
  VAPID_SUBJECT: 'mailto:owner@example.test',
  PUSH_ENABLED: 'true',
};
const REQUIRED = ['DIRECTUS_URL', 'PUSH_SERVICE_TOKEN', 'ALLOWED_ORIGINS', 'PUBLIC_URL', 'VAPID_PUBLIC_KEY', 'VAPID_PRIVATE_KEY', 'VAPID_SUBJECT', 'PUSH_ENABLED'];

test('cấu hình đầy đủ, mặc định cổng và helper', () => {
  const c = loadConfig(base);
  assert.deepEqual([c.port, c.directusUrl, c.serviceToken, c.enabled, c.planBin, c.publicUrl],
    [8080, 'https://directus.test', 'secret-service-token', true, '/app/bin/notify_plan', 'https://notify.example.test']);
  assert.deepEqual(c.allowedOrigins, ['https://poolcoachai.kjdybl.easypanel.host', 'http://localhost:5555']);
  assert.deepEqual(c.vapid, { publicKey: 'pub-key-value', privateKey: 'secret-private-key', subject: 'mailto:owner@example.test' });
});
test('PUSH_ENABLED=false và NOTIFY_PLAN_BIN, PORT tuỳ chọn', () => {
  const c = loadConfig({ ...base, PUSH_ENABLED: 'false', NOTIFY_PLAN_BIN: 'bin/x', PORT: '9000', VAPID_SUBJECT: 'https://x.test' });
  assert.deepEqual([c.enabled, c.planBin, c.port], [false, 'bin/x', 9000]);
});
test('thiếu hết: báo đủ tên', () => {
  assert.throws(() => loadConfig({}), (e) => REQUIRED.every((n) => e.message.includes(n)) && e.message.startsWith('Thiếu hoặc sai biến môi trường: '));
});
test('mỗi biến bắt buộc thiếu hoặc trắng đều bị nêu tên', () => {
  for (const n of REQUIRED) {
    for (const v of [undefined, '   ']) {
      const env = { ...base, [n]: v };
      assert.throws(() => loadConfig(env), (e) => e.message.includes(n));
    }
  }
});
test('lỗi không bao giờ chứa giá trị bí mật hay giá trị sai', () => {
  assert.throws(() => loadConfig({ ...base, PUBLIC_URL: 'http://insecure.test', PUSH_ENABLED: 'yes' }), (e) =>
    !e.message.includes('secret-service-token') && !e.message.includes('secret-private-key') && !e.message.includes('insecure') && !e.message.includes('yes'));
});
test('PUSH_ENABLED chỉ nhận đúng true hoặc false', () => {
  for (const bad of ['yes', '', 'TRUE', '1', 'True']) {
    assert.throws(() => loadConfig({ ...base, PUSH_ENABLED: bad }), /PUSH_ENABLED/);
  }
});
test('PUBLIC_URL phải https, VAPID_SUBJECT phải https: hoặc mailto:', () => {
  assert.throws(() => loadConfig({ ...base, PUBLIC_URL: 'http://x.test' }), /PUBLIC_URL/);
  assert.throws(() => loadConfig({ ...base, PUBLIC_URL: 'không phải url' }), /PUBLIC_URL/);
  assert.throws(() => loadConfig({ ...base, VAPID_SUBJECT: 'http://x.test' }), /VAPID_SUBJECT/);
  assert.throws(() => loadConfig({ ...base, VAPID_SUBJECT: 'owner@x.test' }), /VAPID_SUBJECT/);
});
test('ALLOWED_ORIGINS rút gọn thành rỗng là thiếu', () => {
  assert.throws(() => loadConfig({ ...base, ALLOWED_ORIGINS: ' , ,' }), /ALLOWED_ORIGINS/);
});
test('PORT phải là số nguyên 1–65535', () => {
  for (const bad of ['9000abc', '0', '65536', '-1', '3.5']) {
    assert.throws(() => loadConfig({ ...base, PORT: bad }), /PORT/);
  }
  assert.equal(loadConfig({ ...base, PORT: '' }).port, 8080);
});
