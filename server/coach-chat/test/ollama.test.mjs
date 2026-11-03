import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildMessages, classifyOllamaError, createOllama, OllamaError, OllamaUnavailableError, OLLAMA_NUM_CTX, OLLAMA_NUM_PREDICT } from '../src/ollama.mjs';
import { SYSTEM_PROMPT } from '../src/prompt.mjs';

const input = { facts: { rank: 'g' }, history: [], question: 'Hôm nay tôi nên tập gì?' };

function setup({ result = {}, status = 200, fetchError } = {}) {
  const requests = [];
  const fetch = async (url, init) => {
    requests.push({ url: String(url), init, body: JSON.parse(init.body) });
    if (fetchError) throw fetchError;
    return new Response(JSON.stringify({
      model: 'qwen2.5:3b',
      done: true,
      done_reason: 'stop',
      message: { role: 'assistant', content: 'Hôm nay tập Phòng thủ.' },
      prompt_eval_count: 900,
      eval_count: 120,
      ...result,
    }), { status, headers: { 'content-type': 'application/json' } });
  };
  return {
    model: createOllama({ baseUrl: 'http://127.0.0.1:11434', model: 'qwen2.5:3b', fetch }),
    requests,
  };
}

test('gửi chat không stream tới Ollama với system prompt, history, facts và giới hạn tài nguyên', async () => {
  const { model, requests } = setup();
  await model.ask(input);
  const { url, init, body } = requests[0];
  assert.equal(new URL(url).pathname, '/api/chat');
  assert.equal(init.method, 'POST');
  assert.equal(init.headers['content-type'], 'application/json');
  assert.equal(body.model, 'qwen2.5:3b');
  assert.equal(body.stream, false);
  assert.deepEqual(body.messages[0], { role: 'system', content: SYSTEM_PROMPT });
  assert.deepEqual(body.options, { temperature: 0.2, num_ctx: OLLAMA_NUM_CTX, num_predict: OLLAMA_NUM_PREDICT });
  assert.equal(body.keep_alive, '5m');
});

test('lịch sử: bỏ lượt trợ lý ở đầu, gộp lượt cùng vai, gắn facts và câu hỏi ở cuối', () => {
  const messages = buildMessages([
    { fromPlayer: false, text: 'A0' },
    { fromPlayer: true, text: 'Q1' },
    { fromPlayer: false, text: 'A1' },
    { fromPlayer: true, text: 'Q2 hỏng mạng' },
  ], { rank: 'g' }, 'Q3');
  assert.deepEqual(messages.map((message) => message.role), ['user', 'assistant', 'user']);
  assert.match(messages[2].content, /Q2 hỏng mạng\n<facts>\n{"rank":"g"}\n<\/facts>\n<question>\nQ3\n<\/question>$/);
});

test('trả lời được chuẩn hóa NFC và ánh xạ usage nội bộ', async () => {
  const reply = 'Hôm nay tập Phòng thủ.';
  const { model } = setup({ result: {
    message: { role: 'assistant', content: reply.normalize('NFD') },
  } });
  const result = await model.ask(input);
  assert.deepEqual([result.kind, result.text, result.model, result.stopReason], ['answer', reply, 'qwen2.5:3b', 'stop']);
  assert.deepEqual(result.usage, { input: 900, output: 120, cacheRead: 0, cacheWrite: 0 });
});

test('đầu ra dừng vì giới hạn token bị đánh dấu truncated, không trả lời dở', async () => {
  const { model } = setup({ result: {
    done_reason: 'length',
    message: { role: 'assistant', content: 'Phần đầu dở dang' },
  } });
  const result = await model.ask(input);
  assert.deepEqual([result.kind, result.text], ['truncated', '']);
});

test('phản hồi lỗi và lỗi mạng được phân loại chính xác', async () => {
  const overloaded = setup({ status: 503 });
  assert.deepEqual(classifyOllamaError(await overloaded.model.ask(input).then(() => null, (error) => error)),
    { status: 503, code: 'busy' });
  const unavailable = setup({ fetchError: new TypeError('fetch failed') });
  assert.deepEqual(classifyOllamaError(await unavailable.model.ask(input).then(() => null, (error) => error)),
    { status: 503, code: 'unavailable' });
  assert.equal(classifyOllamaError(new TypeError('bad response shape')), null);
  assert.deepEqual(classifyOllamaError(new OllamaUnavailableError()), { status: 503, code: 'unavailable' });
  assert.deepEqual(classifyOllamaError(new OllamaError(400)), { status: 502, code: 'upstream' });
  assert.equal(classifyOllamaError(new Error('programming error')), null);
});

test('JSON giao thức sai là lỗi nội bộ, không trả câu trả lời giả', async () => {
  const { model } = setup({ result: { message: { role: 'assistant', content: '' } } });
  const error = await model.ask(input).then(() => null, (err) => err);
  assert.match(error.message, /empty response/);
  assert.equal(classifyOllamaError(error), null);
});
