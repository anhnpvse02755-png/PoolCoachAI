// Directus giả cho test Coach Chat: không gọi mạng thật, mô phỏng hành vi
// thật đủ để auth.mjs và quota.mjs được kiểm bằng fetch được tiêm vào.

export const DIRECTUS = 'https://directus.test';
export const SERVICE_TOKEN = 'service-token-test';

const ITEMS_PATH = '/items/coach_chat_usage';

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function errorResponse(status, code) {
  return jsonResponse(status, { errors: [{ extensions: { code } }] });
}

function headerValue(headers, name) {
  if (!headers) return undefined;
  if (headers instanceof Headers) return headers.get(name) ?? undefined;
  const key = Object.keys(headers).find((k) => k.toLowerCase() === name.toLowerCase());
  return key === undefined ? undefined : headers[key];
}

function bearerToken(authHeader) {
  const match = typeof authHeader === 'string' ? /^Bearer (.+)$/.exec(authHeader) : null;
  return match ? match[1] : null;
}

/// Directus giả. `users` ánh xạ token người chơi sang id người dùng.
/// `raceOnCreate` mô phỏng một tiến trình khác tạo dòng ngay trước khi
/// `POST` của ta tới, để kiểm nhánh `RECORD_NOT_UNIQUE` trong quota.mjs.
export function fakeDirectus({ users = { 'tok-a': 'user-a', 'tok-b': 'user-b' }, raceOnCreate = false } = {}) {
  const rows = new Map();
  const calls = [];
  const raced = new Set();

  async function handle(url, init = {}) {
    await new Promise((r) => setImmediate(r));
    const method = (init.method ?? 'GET').toUpperCase();
    const path = url.pathname;
    calls.push({ method, path });

    if (state.down) return errorResponse(503, 'SERVICE_UNAVAILABLE');

    const auth = headerValue(init.headers, 'authorization');

    if (method === 'GET' && path === '/users/me') {
      const token = bearerToken(auth);
      const userId = token === null ? undefined : users[token];
      if (userId !== undefined) return jsonResponse(200, { data: { id: userId } });
      return errorResponse(401, 'INVALID_CREDENTIALS');
    }

    if (path === ITEMS_PATH || path.startsWith(`${ITEMS_PATH}/`)) {
      if (auth !== `Bearer ${SERVICE_TOKEN}`) return errorResponse(403, 'FORBIDDEN');

      if (method === 'GET' && path === ITEMS_PATH) {
        const id = url.searchParams.get('filter[id][_eq]');
        const row = id === null ? undefined : rows.get(id);
        return jsonResponse(200, { data: row ? [row] : [] });
      }

      if (method === 'POST' && path === ITEMS_PATH) {
        const body = init.body ? JSON.parse(init.body) : {};
        const id = body.id;
        if (raceOnCreate && !rows.has(id) && !raced.has(id)) {
          raced.add(id);
          rows.set(id, { id, user: body.user, day: body.day, questions: 1, input_tokens: 0, output_tokens: 0, cache_read_tokens: 0 });
          return errorResponse(400, 'RECORD_NOT_UNIQUE');
        }
        if (rows.has(id)) return errorResponse(400, 'RECORD_NOT_UNIQUE');
        rows.set(id, { ...body });
        return jsonResponse(200, { data: rows.get(id) });
      }

      if (method === 'PATCH' && path.startsWith(`${ITEMS_PATH}/`)) {
        const id = decodeURIComponent(path.slice(`${ITEMS_PATH}/`.length));
        if (!rows.has(id)) return errorResponse(403, 'FORBIDDEN');
        const patch = init.body ? JSON.parse(init.body) : {};
        const row = { ...rows.get(id), ...patch };
        rows.set(id, row);
        return jsonResponse(200, { data: row });
      }
    }

    return errorResponse(404, 'NOT_FOUND');
  }

  const state = { rows, calls, down: false, handle };
  return state;
}

/// Định tuyến mọi URL cùng gốc với [DIRECTUS] vào `directus.handle`, phần
/// còn lại vào `claude`. Nhờ vậy một `ANTHROPIC_BASE_URL` ở máy thật không
/// thể phá định tuyến của test.
export function fakeFetch({ directus, claude } = {}) {
  const directusOrigin = new URL(DIRECTUS).origin;
  return async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    if (directus && url.origin === directusOrigin) return directus.handle(url, init ?? {});
    if (claude) return claude(input, init);
    throw new Error(`fakeFetch: không có bộ xử lý cho ${url}`);
  };
}

/// Luồng SSE giả của Claude theo đúng khuôn dạng ở `typescript/claude-api/streaming.md`,
/// Raw SSE Format. Mô phỏng được khối thinking, khối fallback (đổi model giữa
/// luồng) và khối text, theo đúng thứ tự message_start → content_block_* → message_delta → message_stop.
export function claudeStream({ text = 'Hôm nay tập Phòng thủ.', stopReason = 'end_turn', model = 'claude-opus-5',
  thinking = false, fallbackTo = null,
  usage = { input_tokens: 900, output_tokens: 120, cache_creation_input_tokens: 0, cache_read_input_tokens: 1800 } } = {}) {
  const blocks = [];
  if (thinking) blocks.push({ start: { type: 'thinking', thinking: '', signature: 'sig' } });
  if (fallbackTo) blocks.push({ start: { type: 'fallback', from: { model }, to: { model: fallbackTo } } });
  if (text) blocks.push({ start: { type: 'text', text: '' }, delta: { type: 'text_delta', text } });
  const events = [
    ['message_start', { type: 'message_start', message: { id: 'msg_test', type: 'message', role: 'assistant',
      model: fallbackTo ?? model, content: [], stop_reason: null, stop_sequence: null, usage: { ...usage, output_tokens: 1 } } }],
    ...blocks.flatMap((b, index) => [
      ['content_block_start', { type: 'content_block_start', index, content_block: b.start }],
      ...(b.delta ? [['content_block_delta', { type: 'content_block_delta', index, delta: b.delta }]] : []),
      ['content_block_stop', { type: 'content_block_stop', index }],
    ]),
    ['message_delta', { type: 'message_delta', delta: { stop_reason: stopReason, stop_sequence: null }, usage: { output_tokens: usage.output_tokens } }],
    ['message_stop', { type: 'message_stop' }],
  ];
  const body = events.map(([event, data]) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`).join('');
  return new Response(body, { status: 200, headers: { 'content-type': 'text/event-stream' } });
}

/// Luồng Claude giả "treo mãi" (M4): trả `message_start` ngay rồi KHÔNG BAO
/// GIỜ tự đóng hay gửi thêm gì — mô phỏng thân phản hồi bị treo giữa luồng
/// (ví dụ mất kết nối phía Claude sau khi đã bắt đầu trả lời). `fetch` thật
/// tự báo lỗi cho thân đang đọc khi [signal] phát 'abort'; fetch giả ở đây
/// không có tầng mạng thật để làm điều đó, nên phải tự mô phỏng — thiếu bước
/// này thì test treo mãi, không phải lỗi gì khác.
export function claudeHangingStream(signal) {
  const body = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(
        `event: message_start\ndata: ${JSON.stringify({
          type: 'message_start',
          message: { id: 'msg_test', type: 'message', role: 'assistant', model: 'claude-opus-5',
            content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 900, output_tokens: 1 } },
        })}\n\n`,
      ));
      const onAbort = () => controller.error(new DOMException('Hết giờ chờ Claude (giả lập)', 'AbortError'));
      if (signal) {
        if (signal.aborted) onAbort();
        else signal.addEventListener('abort', onAbort, { once: true });
      }
    },
  });
  return new Response(body, { status: 200, headers: { 'content-type': 'text/event-stream' } });
}

/// Phản hồi lỗi giả của Claude: thân JSON `{type: 'error', error: {...}}` với
/// mã trạng thái HTTP [status] và kiểu lỗi Anthropic [type].
export function claudeError(status, type) {
  return new Response(JSON.stringify({ type: 'error', error: { type, message: type } }),
    { status, headers: { 'content-type': 'application/json' } });
}
