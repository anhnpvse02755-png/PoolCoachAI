import { test } from 'node:test';
import assert from 'node:assert/strict';
import Anthropic from '@anthropic-ai/sdk';
import { buildMessages, createClaude, classifyClaudeError } from '../src/claude.mjs';
import { SYSTEM_PROMPT } from '../src/prompt.mjs';
import { fakeFetch, claudeStream, claudeError, claudeHangingStream } from './fakes.mjs';

function setup({ reply = () => claudeStream(), fallbacks = true } = {}) {
  const requests = [];
  const claude = async (url, init) => {
    requests.push({ url: String(url), headers: new Headers(init.headers), body: JSON.parse(init.body) });
    return reply();
  };
  const c = createClaude({ apiKey: 'sk-test-key', model: 'claude-opus-5', effort: 'low', fallbacks, fetch: fakeFetch({ claude }), maxRetries: 0 });
  return { c, requests };
}
const input = { facts: { rank: 'g' }, history: [], question: 'Hôm nay tôi nên tập gì?' };

test('dạng yêu cầu: stream, adaptive, effort, dự phòng phía máy chủ, cache_control chỉ ở lời dặn', async () => {
  const { c, requests } = setup();
  await c.ask(input);
  const { url, headers, body } = requests[0];
  assert.equal(new URL(url).pathname, '/v1/messages');
  assert.match(headers.get('anthropic-beta'), /server-side-fallback-2026-07-01/);
  assert.equal(body.stream, true);
  assert.equal(body.model, 'claude-opus-5');
  assert.equal(body.max_tokens, 4000);
  assert.deepEqual(body.thinking, { type: 'adaptive' });
  assert.deepEqual(body.output_config, { effort: 'low' });
  assert.equal(body.fallbacks, 'default');
  assert.deepEqual(body.system, [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }]);
  assert.equal(body.cache_control, undefined);
  assert.equal(body.betas, undefined);
});
test('CLAUDE_FALLBACKS=off: không header beta, không fallbacks', async () => {
  const { c, requests } = setup({ fallbacks: false });
  await c.ask(input);
  assert.equal(requests[0].headers.get('anthropic-beta'), null);
  assert.equal(requests[0].body.fallbacks, undefined);
});
test('lịch sử: bỏ lượt huấn luyện viên ở đầu, gộp lượt cùng vai, dữ kiện và câu hỏi ở tin cuối', () => {
  const m = buildMessages([{ fromPlayer: false, text: 'A0' }, { fromPlayer: true, text: 'Q1' }, { fromPlayer: false, text: 'A1' },
    { fromPlayer: true, text: 'Q2 hỏng mạng' }], { rank: 'g' }, 'Q3');
  assert.deepEqual(m.map((x) => x.role), ['user', 'assistant', 'user']);
  assert.deepEqual(m[2].content.map((b) => b.text), ['Q2 hỏng mạng', '<facts>\n{"rank":"g"}\n</facts>', '<question>\nQ3\n</question>']);
});
test('câu trả lời: bỏ khối thinking và fallback, ghép text; model là model đã trả lời; token gồm cả cache', async () => {
  const { c } = setup({ reply: () => claudeStream({ text: 'Tập Phòng thủ.', thinking: true, fallbackTo: 'claude-opus-4-8' }) });
  const r = await c.ask(input);
  assert.deepEqual([r.kind, r.text, r.model, r.stopReason], ['answer', 'Tập Phòng thủ.', 'claude-opus-4-8', 'end_turn']);
  assert.deepEqual(r.usage, { input: 900, output: 120, cacheRead: 1800, cacheWrite: 0 });
});
test('kiểm stop_reason trước nội dung: refusal → refused, max_tokens → truncated, phần chữ dở bị bỏ', async () => {
  for (const [stopReason, kind] of [['refusal', 'refused'], ['max_tokens', 'truncated']]) {
    const { c } = setup({ reply: () => claudeStream({ text: 'Phần đầu', stopReason }) });
    const r = await c.ask(input);
    assert.deepEqual([r.kind, r.text], [kind, '']);
  }
});
test('lỗi SDK theo thứ tự cụ thể tới chung', async () => {
  for (const [reply, expected] of [
    [() => claudeError(429, 'rate_limit_error'), { status: 503, code: 'busy' }],
    [() => claudeError(529, 'overloaded_error'), { status: 503, code: 'busy' }],
    [() => claudeError(500, 'api_error'), { status: 502, code: 'upstream' }],
    [() => claudeError(400, 'invalid_request_error'), { status: 502, code: 'upstream' }],
    [() => { throw new TypeError('fetch failed'); }, { status: 503, code: 'unavailable' }],
  ]) {
    const { c } = setup({ reply });
    const err = await c.ask(input).then(() => null, (e) => e);
    assert.deepEqual(classifyClaudeError(err), expected);
  }
  assert.equal(classifyClaudeError(new Error('lỗi lập trình')), null);
});

// M4: timeout 60s của SDK (claude.mjs cũ) chỉ phủ đợi header, không phủ thân đang stream;
// maxRetries có thể gấp đôi lần đợi. deadlineMs tiêm vào đây mô phỏng AbortSignal.timeout
// phủ toàn bộ lượt gọi (cả khi đang đọc thân), nên phải test riêng, ngắn, không chờ 120s thật.
test('M4: thân luồng treo mãi thì bị huỷ sau deadlineMs, lỗi là APIUserAbortError, phân loại 502 upstream',
  { timeout: 2000 }, async () => {
    const claude = async (_url, init) => claudeHangingStream(init.signal);
    const c = createClaude({
      apiKey: 'sk-test-key', model: 'claude-opus-5', effort: 'low', fallbacks: true,
      fetch: fakeFetch({ claude }), maxRetries: 0, deadlineMs: 30,
    });
    const err = await c.ask(input).then(() => null, (e) => e);
    assert.ok(err instanceof Anthropic.APIUserAbortError, `muốn APIUserAbortError, được ${err?.constructor?.name}: ${err?.message}`);
    assert.deepEqual(classifyClaudeError(err), { status: 502, code: 'upstream' });
  });

// Ruling của Task 2 review: bộ lọc của app chặn chữ Unicode tổ hợp (NFD), nên câu hỏi, từng
// lượt lịch sử, và câu trả lời phải được chuẩn hoá về NFC trước khi dùng. Dùng
// `.normalize('NFD')` trên chuỗi NFC để chắc chắn có chữ tổ hợp thật, không tuỳ vào cách
// editor lưu file nguồn.
test('chuẩn hoá Unicode NFC: câu hỏi/lịch sử NFD gửi đi và câu trả lời NFD nhận về đều thành NFC', async () => {
  const question = 'Hôm nay tôi nên tập gì?';
  const historyText = 'Bạn nên tập Phòng thủ.';
  const replyText = 'Hôm nay tập Phòng thủ.';
  const nfdQuestion = question.normalize('NFD');
  const nfdHistoryText = historyText.normalize('NFD');
  const nfdReplyText = replyText.normalize('NFD');
  assert.notEqual(nfdQuestion, question, 'cần một chuỗi có dấu để phép thử có ý nghĩa');

  const { c, requests } = setup({ reply: () => claudeStream({ text: nfdReplyText }) });
  const r = await c.ask({
    facts: { rank: 'g' },
    history: [{ fromPlayer: true, text: 'Câu hỏi trước' }, { fromPlayer: false, text: nfdHistoryText }],
    question: nfdQuestion,
  });

  const { body } = requests[0];
  const sentTexts = body.messages.flatMap((m) => m.content.map((b) => b.text));
  for (const t of sentTexts) assert.equal(t, t.normalize('NFC'));
  assert.ok(sentTexts.some((t) => t.includes(question)));
  assert.ok(sentTexts.some((t) => t === historyText));

  assert.equal(r.text, replyText);
  assert.equal(r.text, r.text.normalize('NFC'));
});
