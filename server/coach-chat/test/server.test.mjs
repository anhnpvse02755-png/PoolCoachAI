import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createApp } from '../src/server.mjs';
import { SYSTEM_PROMPT } from '../src/prompt.mjs';
import { DIRECTUS, SERVICE_TOKEN, fakeDirectus, fakeFetch, claudeStream, claudeError } from './fakes.mjs';

const WEB = 'https://poolcoachai.kjdybl.easypanel.host';

async function start(t, { config = {}, now = '2026-10-22T03:00:00Z', nowFn, wrapFetch } = {}) {
  const directus = fakeDirectus();
  const claudeBodies = [];
  let reply = () => claudeStream({ text: 'Hôm nay tập Phòng thủ.' });
  const claude = async (url, init) => { claudeBodies.push(JSON.parse(init.body)); return reply(); };
  const lines = [];
  const baseFetch = fakeFetch({ directus, claude });
  const handler = createApp({
    config: { port: 0, anthropicApiKey: 'sk-test-key', model: 'claude-opus-5', effort: 'low', fallbacks: true, dailyLimit: 30,
      directusUrl: DIRECTUS, directusServiceToken: SERVICE_TOKEN, allowedOrigins: [WEB, 'http://localhost:5555'], ...config },
    fetch: wrapFetch ? wrapFetch(baseFetch) : baseFetch,
    now: nowFn ?? (() => new Date(now)), log: (l) => lines.push(l), claudeMaxRetries: 0,
  });
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => server.close(r)));
  return { base: `http://127.0.0.1:${server.address().port}`, directus, claudeBodies, lines, setReply: (f) => { reply = f; } };
}

/// Chuỗi [s] là một mốc thời gian ISO 8601 hợp lệ, lấy từ đồng hồ thật
/// (controller ruling: không lấy từ `now` được tiêm cho test).
function assertIsoAt(s) {
  assert.equal(typeof s, 'string');
  assert.equal(new Date(s).toISOString(), s);
}
const body = { facts: { rank: 'g', marker: 'FACT-MARKER' }, history: [], question: 'Hôm nay tôi nên tập gì?' };
const ask = (base, { token = 'tok-a', origin, payload = body } = {}) => fetch(`${base}/v1/coach-chat`, { method: 'POST',
  headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), ...(origin ? { origin } : {}) },
  body: typeof payload === 'string' ? payload : JSON.stringify(payload) });

test('healthz: ok, không gọi gì, không ghi nhật ký', async (t) => {
  const s = await start(t);
  const r = await fetch(`${s.base}/healthz`);
  assert.deepEqual([r.status, await r.text()], [200, 'ok']);
  assert.deepEqual([s.directus.calls.length, s.claudeBodies.length, s.lines.length], [0, 0, 0]);
});
test('không token hoặc token sai: 401, không gọi Claude', async (t) => {
  const s = await start(t);
  for (const token of [null, 'sai']) assert.equal((await ask(s.base, { token })).status, 401);
  assert.equal(s.claudeBodies.length, 0);
});
test('body sai: 400 kèm trường; thân vượt MAX_BODY_BYTES: 413 (controller ruling 1 — máy chủ đọc hết thân rồi mới trả lời, khách không bị đứt kết nối)', async (t) => {
  const s = await start(t);
  const r1 = await ask(s.base, { payload: '{không phải json' });
  assert.deepEqual([r1.status, (await r1.json()).field], [400, 'body']);
  const r2 = await ask(s.base, { payload: { ...body, question: '' } });
  assert.deepEqual(await r2.json(), { error: 'invalid', field: 'question' });
  // Thân JSON toàn bộ (gồm chuỗi facts 70 000 byte) vượt MAX_BODY_BYTES (65 536) —
  // bị chặn ở bước đọc thân thô, trước cả JSON.parse, nên trả 413, không phải 400.
  const r3 = await ask(s.base, { payload: { ...body, facts: { s: 'x'.repeat(70_000) } } });
  assert.deepEqual([r3.status, (await r3.json()).field], [413, 'body']);
});
test('trả lời: 200 đủ trường, trừ một lượt, cộng token', async (t) => {
  const s = await start(t);
  const r = await ask(s.base);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { text: 'Hôm nay tập Phòng thủ.', model: 'claude-opus-5', remainingToday: 29,
    usage: { input: 900, output: 120, cacheRead: 1800 } });
  const row = s.directus.rows.get('user-a_2026-10-22');
  assert.deepEqual([row.questions, row.input_tokens, row.output_tokens, row.cache_read_tokens], [1, 900, 120, 1800]);
});
test('hết lượt: 429 có limit và resetAt, không gọi Claude', async (t) => {
  const s = await start(t, { config: { dailyLimit: 1 } });
  await ask(s.base);
  const r = await ask(s.base);
  assert.equal(r.status, 429);
  assert.deepEqual(await r.json(), { error: 'quota', limit: 1, resetAt: '2026-10-22T17:00:00.000Z' });
  assert.equal(s.claudeBodies.length, 1);
});
test('Claude quá tải hoặc mất kết nối: 503 và hoàn lượt, nhật ký mang mã lỗi (ruling 5)', async (t) => {
  const s = await start(t);
  for (const [reply, code] of [[() => claudeError(529, 'overloaded_error'), 'busy'], [() => { throw new TypeError('fetch failed'); }, 'unavailable']]) {
    s.setReply(reply);
    const r = await ask(s.base);
    assert.deepEqual([r.status, (await r.json()).error], [503, code]);
    assert.equal(s.directus.rows.get('user-a_2026-10-22').questions, 0);
    const last = JSON.parse(s.lines.at(-1));
    assert.equal(last.error, code);
  }
});
test('Claude vứt lỗi không phân loại được (không phải APIError/APIConnectionError/RateLimitError của SDK): 500 internal, vẫn hoàn lượt (ruling 2)', async (t) => {
  const s = await start(t);
  // Phản hồi 200 nhưng không có đoạn SSE nào: SDK ném AnthropicError (không phải
  // APIError hay APIConnectionError) — classifyClaudeError trả null, rơi vào
  // nhánh mặc định 500/'internal'. Đây là một lỗi "lập trình/giao thức", không
  // phải lỗi mạng hay lỗi do Claude từ chối.
  s.setReply(() => new Response('', { status: 200, headers: { 'content-type': 'text/event-stream' } }));
  const r = await ask(s.base);
  assert.deepEqual([r.status, await r.json()], [500, { error: 'internal' }]);
  assert.equal(s.directus.rows.get('user-a_2026-10-22').questions, 0);
  assert.equal(JSON.parse(s.lines.at(-1)).error, 'internal');
});
test('Claude từ chối hoặc bị cắt: 502 kèm remainingToday, không hoàn lượt (R7)', async (t) => {
  const s = await start(t);
  s.setReply(() => claudeStream({ text: '', stopReason: 'refusal' }));
  const r = await ask(s.base);
  assert.deepEqual([r.status, await r.json()], [502, { error: 'refused', remainingToday: 29 }]);
  s.setReply(() => claudeStream({ text: 'dở', stopReason: 'max_tokens' }));
  assert.deepEqual(await (await ask(s.base)).json(), { error: 'truncated', remainingToday: 28 });
});
test('Directus sập: 503 unavailable', async (t) => {
  const s = await start(t);
  s.directus.down = true;
  assert.deepEqual([(await ask(s.base)).status], [503]);
});
test('R15: addUsage lỗi (chỉ PATCH cộng token sập) vẫn trả lời 200, có dòng nhật ký lỗi riêng', async (t) => {
  const s = await start(t, {
    wrapFetch: (base) => async (input, init) => {
      const method = (init?.method ?? 'GET').toUpperCase();
      if (method === 'PATCH' && init?.body) {
        const patch = JSON.parse(init.body);
        if ('input_tokens' in patch) {
          return new Response(JSON.stringify({ errors: [{ extensions: { code: 'SERVICE_UNAVAILABLE' } }] }),
            { status: 503, headers: { 'content-type': 'application/json' } });
        }
      }
      return base(input, init);
    },
  });
  const r = await ask(s.base);
  assert.equal(r.status, 200);
  assert.equal((await r.json()).text, 'Hôm nay tập Phòng thủ.');
  const row = s.directus.rows.get('user-a_2026-10-22');
  assert.equal(row.questions, 1);
  assert.equal(row.input_tokens, 0);
  const errorLine = s.lines.map((l) => JSON.parse(l)).find((l) => l.event === 'error');
  assert.deepEqual([errorLine.event, errorLine.where], ['error', 'addUsage']);
  assertIsoAt(errorLine.at);
});
test('M11a: Claude lỗi rồi hoàn lượt cũng lỗi — vẫn trả đúng mã đã phân loại từ lỗi Claude, không phải lỗi hoàn lượt; có dòng nhật ký lỗi riêng where:"refund"', async (t) => {
  // Người dùng mới trong ngày: take() tạo dòng bằng POST (createUsage, questions:1 đặt
  // sẵn trong thân tạo), không qua PATCH — nên PATCH mang khoá `questions` duy nhất
  // trong cả lượt hỏi thất bại này là của refund() (server.mjs:188-192), chặn thẳng nó.
  const s = await start(t, {
    wrapFetch: (base) => async (input, init) => {
      const method = (init?.method ?? 'GET').toUpperCase();
      if (method === 'PATCH' && init?.body) {
        const patch = JSON.parse(init.body);
        if ('questions' in patch) {
          return new Response(JSON.stringify({ errors: [{ extensions: { code: 'SERVICE_UNAVAILABLE' } }] }),
            { status: 503, headers: { 'content-type': 'application/json' } });
        }
      }
      return base(input, init);
    },
  });
  s.setReply(() => claudeError(529, 'overloaded_error')); // -> classifyClaudeError: {status:503, code:'busy'}
  const r = await ask(s.base);
  assert.deepEqual([r.status, (await r.json()).error], [503, 'busy']);
  // Hoàn lượt không thành (PATCH của refund() bị chặn), nên lượt đã trừ ở take() còn nguyên.
  assert.equal(s.directus.rows.get('user-a_2026-10-22').questions, 1);
  const errorLine = s.lines.map((l) => JSON.parse(l)).find((l) => l.event === 'error' && l.where === 'refund');
  assert.ok(errorLine, 'thiếu dòng nhật ký lỗi where:"refund"');
  assertIsoAt(errorLine.at);
});
test('hạn mức: GET quota', async (t) => {
  const s = await start(t);
  const r = await fetch(`${s.base}/v1/coach-chat/quota`, { headers: { authorization: 'Bearer tok-a' } });
  assert.deepEqual(await r.json(), { limit: 30, used: 0, remainingToday: 30, resetAt: '2026-10-22T17:00:00.000Z' });
});
test('CORS: preflight của web và localhost:5555; nguồn lạ 403; app điện thoại không gửi Origin vẫn được phục vụ', async (t) => {
  const s = await start(t);
  const pre = await fetch(`${s.base}/v1/coach-chat`, { method: 'OPTIONS', headers: { origin: WEB, 'access-control-request-method': 'POST' } });
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get('access-control-allow-origin'), WEB);
  assert.match(pre.headers.get('access-control-allow-headers'), /authorization/i);
  const evil = await fetch(`${s.base}/v1/coach-chat`, { method: 'OPTIONS', headers: { origin: 'https://evil.example' } });
  assert.deepEqual([evil.status, evil.headers.get('access-control-allow-origin')], [403, null]);
  assert.equal((await ask(s.base, { origin: 'http://localhost:5555' })).headers.get('access-control-allow-origin'), 'http://localhost:5555');
  const native = await ask(s.base);
  assert.deepEqual([native.status, native.headers.get('access-control-allow-origin')], [200, null]);
  // Ruling 6: mỗi yêu cầu OPTIONS cũng ghi một dòng nhật ký (method, path, status, ms, at).
  const optionsLines = s.lines.map((l) => JSON.parse(l)).filter((l) => l.method === 'OPTIONS');
  assert.equal(optionsLines.length, 2);
  assert.deepEqual(optionsLines.map((l) => l.status).sort(), [204, 403]);
  for (const line of optionsLines) {
    assert.equal(line.path, '/v1/coach-chat');
    assert.equal(typeof line.ms, 'number');
    assertIsoAt(line.at);
  }
});
test('lời dặn hệ thống giống hệt từng byte giữa các lượt và giữa người chơi', async (t) => {
  const s = await start(t);
  await ask(s.base);
  await ask(s.base, { token: 'tok-b', payload: { facts: { rank: 'a' }, history: [{ fromPlayer: true, text: 'Q' }, { fromPlayer: false, text: 'A' }], question: 'Khác' } });
  assert.equal(JSON.stringify(s.claudeBodies[0].system), JSON.stringify(s.claudeBodies[1].system));
  assert.equal(s.claudeBodies[0].system[0].text, SYSTEM_PROMPT);
});
test('nhật ký: một dòng JSON mỗi yêu cầu, không câu hỏi, không dữ kiện, không token, không khoá', async (t) => {
  const s = await start(t);
  await ask(s.base);
  await fetch(`${s.base}/v1/coach-chat/quota`, { headers: { authorization: 'Bearer tok-a' } });
  assert.equal(s.lines.length, 2);
  const first = JSON.parse(s.lines[0]);
  assert.deepEqual([first.method, first.path, first.status, first.model, first.stop, first.in, first.out, first.cacheRead],
    ['POST', '/v1/coach-chat', 200, 'claude-opus-5', 'end_turn', 900, 120, 1800]);
  assert.match(first.user, /^[0-9a-f]{16}$/);
  assert.equal(typeof first.ms, 'number');
  // Ruling 1: mỗi dòng nhật ký mang mốc thời gian thật (không phải `now` tiêm cho test).
  assertIsoAt(first.at);
  assert.notEqual(first.at, '2026-10-22T03:00:00.000Z');
  const all = s.lines.join('\n');
  for (const secret of ['Hôm nay tôi nên tập gì', 'Hôm nay tập Phòng thủ', 'FACT-MARKER', 'tok-a', 'sk-test-key', 'service-token-test', 'user-a']) {
    assert.ok(!all.includes(secret), secret);
  }
});
test('báo bị chặn: 204 và một dòng nhật ký có tên luật', async (t) => {
  const s = await start(t);
  const post = (payload, token = 'tok-a') => fetch(`${s.base}/v1/coach-chat/blocked`, { method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(payload) });
  assert.equal((await post({ rule: 'unknownNumber' })).status, 204);
  const blockedLine = JSON.parse(s.lines.at(-1));
  assert.deepEqual([blockedLine.event, blockedLine.rule], ['blocked', 'unknownNumber']);
  assertIsoAt(blockedLine.at);
  assert.equal((await post({ rule: 'có dấu cách' })).status, 400);
  assert.equal((await post({ rule: 'x' }, null)).status, 401);
});
test('đường dẫn lạ: 404, vẫn ghi một dòng nhật ký mỗi yêu cầu (ruling 6)', async (t) => {
  const s = await start(t);
  const r = await fetch(`${s.base}/v1/other`);
  assert.equal(r.status, 404);
  assert.equal(s.lines.length, 1);
  const line = JSON.parse(s.lines[0]);
  assert.deepEqual([line.method, line.path, line.status, line.error], ['GET', '/v1/other', 404, 'not_found']);
  assert.equal(typeof line.ms, 'number');
  assertIsoAt(line.at);
});
test('lỗi không lường được (vd. lỗi lập trình trong auth/quota): 500 internal, vẫn ghi một dòng nhật ký (ruling 6)', async (t) => {
  const s = await start(t, { nowFn: () => { throw new Error('giờ hỏng'); } });
  const r = await ask(s.base);
  assert.deepEqual([r.status, await r.json()], [500, { error: 'internal' }]);
  assert.equal(s.lines.length, 1);
  const line = JSON.parse(s.lines[0]);
  assert.deepEqual([line.method, line.path, line.status, line.error], ['POST', '/v1/coach-chat', 500, 'internal']);
  assert.equal(typeof line.ms, 'number');
  assertIsoAt(line.at);
});
