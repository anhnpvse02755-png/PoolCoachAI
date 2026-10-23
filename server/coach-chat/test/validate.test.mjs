import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseChatRequest, parseBlockedReport, RequestError } from '../src/validate.mjs';

const ok = { facts: { rank: 'g' }, history: [{ fromPlayer: true, text: 'Q1' }, { fromPlayer: false, text: 'A1' }], question: '  Hôm nay tôi nên tập gì?  ' };
const field = (body) => { try { parseChatRequest(body); return null; } catch (e) { assert.ok(e instanceof RequestError); return e.field; } };

test('body hợp lệ đi qua, câu hỏi được cắt khoảng trắng', () => {
  assert.equal(parseChatRequest(ok).question, 'Hôm nay tôi nên tập gì?');
});
test('mỗi giới hạn của spec 7.2 trả đúng trường lỗi', () => {
  assert.equal(field(null), 'body');
  assert.equal(field({ ...ok, facts: [] }), 'facts');
  assert.equal(field({ ...ok, facts: { s: 'x'.repeat(16400) } }), 'facts');
  assert.equal(field({ ...ok, history: 'x' }), 'history');
  assert.equal(field({ ...ok, history: Array.from({ length: 11 }, () => ({ fromPlayer: true, text: 'q' })) }), 'history');
  assert.equal(field({ ...ok, history: [{ text: 'q' }] }), 'history');
  assert.equal(field({ ...ok, history: [{ fromPlayer: true, text: '  ' }] }), 'history');
  assert.equal(field({ ...ok, history: [{ fromPlayer: true, text: 'x'.repeat(1001) }] }), 'history');
  assert.equal(field({ ...ok, question: '   ' }), 'question');
  assert.equal(field({ ...ok, question: 'x'.repeat(501) }), 'question');
  assert.equal(field({ ...ok, question: '😀'.repeat(251) }), 'question');   // 502 đơn vị UTF-16
});
test('báo cáo bị chặn: chỉ tên luật', () => {
  assert.deepEqual(parseBlockedReport({ rule: 'unknownNumber' }), { rule: 'unknownNumber' });
  assert.throws(() => parseBlockedReport({ rule: 'x y' }), RequestError);
});
