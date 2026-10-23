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
    if (url.origin === directusOrigin) return directus.handle(url, init ?? {});
    if (claude) return claude(input, init);
    throw new Error(`fakeFetch: không có bộ xử lý cho ${url}`);
  };
}
