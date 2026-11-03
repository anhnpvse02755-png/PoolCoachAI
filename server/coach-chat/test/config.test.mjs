import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.mjs';

const base = { DIRECTUS_URL: 'https://directus.test/', DIRECTUS_SERVICE_TOKEN: 'service-token-test',
  ALLOWED_ORIGINS: 'https://poolcoachai.kjdybl.easypanel.host, http://localhost:5555,' };

test('mặc định Ollama local và cấu hình theo spec 7.7', () => {
  const c = loadConfig(base);
  assert.deepEqual([c.port, c.ollamaUrl, c.model, c.dailyLimit, c.directusUrl],
    [8080, 'http://127.0.0.1:11434', 'qwen2.5:3b', 30, 'https://directus.test']);
  assert.deepEqual(c.allowedOrigins, ['https://poolcoachai.kjdybl.easypanel.host', 'http://localhost:5555']);
});
test('đổi URL, model và hạn mức bằng biến môi trường', () => {
  const c = loadConfig({ ...base, OLLAMA_URL: 'http://ollama.internal:11434/', OLLAMA_MODEL: 'qwen2.5:7b', DAILY_QUESTION_LIMIT: '10', PORT: '9000' });
  assert.deepEqual([c.ollamaUrl, c.model, c.dailyLimit, c.port], ['http://ollama.internal:11434', 'qwen2.5:7b', 10, 9000]);
});
test('thiếu biến bắt buộc: báo đủ tên, không lộ giá trị', () => {
  assert.throws(() => loadConfig({ DIRECTUS_SERVICE_TOKEN: 'very-secret-value' }), (e) =>
    ['DIRECTUS_URL', 'ALLOWED_ORIGINS'].every((n) => e.message.includes(n)) && !e.message.includes('very-secret-value'));
});
test('giá trị sai cũng là lỗi', () => {
  for (const bad of [{ OLLAMA_URL: 'javascript:alert(1)' }, { OLLAMA_URL: 'http://user:pass@localhost:11434' },
    { DAILY_QUESTION_LIMIT: '0' }, { DAILY_QUESTION_LIMIT: 'abc' }]) {
    assert.throws(() => loadConfig({ ...base, ...bad }), /Thiếu hoặc sai biến môi trường/);
  }
});
test('biến bắt buộc chỉ có khoảng trắng cũng coi là thiếu (spec 7.7)', () => {
  assert.throws(() => loadConfig({ ...base, DIRECTUS_URL: '  ' }), /DIRECTUS_URL/);
  assert.throws(() => loadConfig({ ...base, DIRECTUS_SERVICE_TOKEN: '\t' }), /DIRECTUS_SERVICE_TOKEN/);
});
test('ALLOWED_ORIGINS rút gọn thành rỗng cũng coi là thiếu', () => {
  assert.throws(() => loadConfig({ ...base, ALLOWED_ORIGINS: ' , ,' }), /ALLOWED_ORIGINS/);
});
test('OLLAMA_MODEL rỗng hoặc chỉ khoảng trắng thì dùng mặc định', () => {
  assert.equal(loadConfig({ ...base, OLLAMA_MODEL: '' }).model, 'qwen2.5:3b');
  assert.equal(loadConfig({ ...base, OLLAMA_MODEL: '   ' }).model, 'qwen2.5:3b');
});
test('PORT phải là số nguyên 1–65535', () => {
  for (const bad of ['9000abc', '0', '65536', '-1', '3.5']) {
    assert.throws(() => loadConfig({ ...base, PORT: bad }), /PORT/);
  }
  assert.equal(loadConfig({ ...base, PORT: '65535' }).port, 65535);
  assert.equal(loadConfig({ ...base, PORT: '1' }).port, 1);
});

// Biến tùy chọn để trống phải dùng mặc định thay vì làm dịch vụ crash-loop.
test('M3: biến tuỳ chọn để trống (rỗng hoặc chỉ khoảng trắng) thì dùng mặc định, không crash-loop', () => {
  for (const blank of ['', '   ', '\t']) {
    const c = loadConfig({ ...base, PORT: blank, OLLAMA_URL: blank, OLLAMA_MODEL: blank, DAILY_QUESTION_LIMIT: blank });
    assert.deepEqual([c.port, c.ollamaUrl, c.model, c.dailyLimit], [8080, 'http://127.0.0.1:11434', 'qwen2.5:3b', 30]);
  }
});
test('M3: biến tuỳ chọn có khoảng trắng quanh giá trị hợp lệ thì cắt rồi mới xét', () => {
  const c = loadConfig({ ...base, PORT: ' 9000 ', OLLAMA_URL: ' http://localhost:11434/ ', OLLAMA_MODEL: ' qwen2.5:7b ', DAILY_QUESTION_LIMIT: ' 10 ' });
  assert.deepEqual([c.port, c.ollamaUrl, c.model, c.dailyLimit], [9000, 'http://localhost:11434', 'qwen2.5:7b', 10]);
});
test('M3: DIRECTUS_URL cắt khoảng trắng quanh giá trị rồi mới bỏ "/" cuối', () => {
  const c = loadConfig({ ...base, DIRECTUS_URL: '  https://directus.test/  ' });
  assert.equal(c.directusUrl, 'https://directus.test');
});
test('M3: mỗi origin trong ALLOWED_ORIGINS bị bỏ "/" cuối', () => {
  const c = loadConfig({ ...base, ALLOWED_ORIGINS: 'https://a.test/, https://b.test//, http://localhost:5555' });
  assert.deepEqual(c.allowedOrigins, ['https://a.test', 'https://b.test', 'http://localhost:5555']);
});
