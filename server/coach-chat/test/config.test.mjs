import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.mjs';

const base = { ANTHROPIC_API_KEY: 'sk-test-key', DIRECTUS_URL: 'https://directus.test/', DIRECTUS_SERVICE_TOKEN: 'service-token-test',
  ALLOWED_ORIGINS: 'https://poolcoachai.kjdybl.easypanel.host, http://localhost:5555,' };

test('mặc định theo spec 7.7 và 13.8', () => {
  const c = loadConfig(base);
  assert.deepEqual([c.port, c.model, c.effort, c.fallbacks, c.dailyLimit, c.directusUrl],
    [8080, 'claude-opus-5', 'low', true, 30, 'https://directus.test']);
  assert.deepEqual(c.allowedOrigins, ['https://poolcoachai.kjdybl.easypanel.host', 'http://localhost:5555']);
});
test('đổi model, effort, hạn mức, tắt dự phòng bằng biến môi trường', () => {
  const c = loadConfig({ ...base, CLAUDE_MODEL: 'claude-sonnet-5', CLAUDE_EFFORT: 'medium', DAILY_QUESTION_LIMIT: '10', CLAUDE_FALLBACKS: 'off', PORT: '9000' });
  assert.deepEqual([c.model, c.effort, c.dailyLimit, c.fallbacks, c.port], ['claude-sonnet-5', 'medium', 10, false, 9000]);
});
test('thiếu biến bắt buộc: báo đủ tên, không lộ giá trị', () => {
  assert.throws(() => loadConfig({ DIRECTUS_SERVICE_TOKEN: 'very-secret-value' }), (e) =>
    ['ANTHROPIC_API_KEY', 'DIRECTUS_URL', 'ALLOWED_ORIGINS'].every((n) => e.message.includes(n)) && !e.message.includes('very-secret-value'));
});
test('giá trị sai cũng là lỗi', () => {
  for (const bad of [{ CLAUDE_EFFORT: 'turbo' }, { DAILY_QUESTION_LIMIT: '0' }, { DAILY_QUESTION_LIMIT: 'abc' }, { CLAUDE_FALLBACKS: 'yes' }]) {
    assert.throws(() => loadConfig({ ...base, ...bad }), /Thiếu hoặc sai biến môi trường/);
  }
});
test('biến bắt buộc chỉ có khoảng trắng cũng coi là thiếu (spec 7.7)', () => {
  assert.throws(() => loadConfig({ ...base, ANTHROPIC_API_KEY: '   ' }), /ANTHROPIC_API_KEY/);
  assert.throws(() => loadConfig({ ...base, DIRECTUS_URL: '  ' }), /DIRECTUS_URL/);
  assert.throws(() => loadConfig({ ...base, DIRECTUS_SERVICE_TOKEN: '\t' }), /DIRECTUS_SERVICE_TOKEN/);
});
test('ALLOWED_ORIGINS rút gọn thành rỗng cũng coi là thiếu', () => {
  assert.throws(() => loadConfig({ ...base, ALLOWED_ORIGINS: ' , ,' }), /ALLOWED_ORIGINS/);
});
test('CLAUDE_MODEL rỗng hoặc chỉ khoảng trắng thì dùng mặc định', () => {
  assert.equal(loadConfig({ ...base, CLAUDE_MODEL: '' }).model, 'claude-opus-5');
  assert.equal(loadConfig({ ...base, CLAUDE_MODEL: '   ' }).model, 'claude-opus-5');
});
test('PORT phải là số nguyên 1–65535', () => {
  for (const bad of ['9000abc', '0', '65536', '-1', '3.5', ' ']) {
    assert.throws(() => loadConfig({ ...base, PORT: bad }), /PORT/);
  }
  assert.equal(loadConfig({ ...base, PORT: '65535' }).port, 65535);
  assert.equal(loadConfig({ ...base, PORT: '1' }).port, 1);
});
