// Directus giả cho test dịch vụ notify: không gọi mạng thật. Ghi lại mọi
// yêu cầu (method, path, query, Authorization) để test kiểm đúng dạng gọi.

export const DIRECTUS = 'https://directus.test';
export const SERVICE_TOKEN = 'service-token-test';

export function jsonResponse(status, body, headers = {}) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });
}
export function errorResponse(status, code, headers) {
  return jsonResponse(status, { errors: [{ extensions: { code } }] }, headers);
}
function headerValue(headers, name) {
  if (!headers) return undefined;
  if (headers instanceof Headers) return headers.get(name) ?? undefined;
  const key = Object.keys(headers).find((k) => k.toLowerCase() === name.toLowerCase());
  return key === undefined ? undefined : headers[key];
}
function bearerToken(h) {
  const m = typeof h === 'string' ? /^Bearer (.+)$/.exec(h) : null;
  return m ? m[1] : null;
}

/// Directus giả. `users` ánh xạ token người chơi sang id. `items` là kho
/// dòng theo collection (mảng) dùng cho GET; `reply` cho test ghi đè phản
/// hồi (nhận `{method, path, url, body}`, trả Response hoặc undefined).
export function fakeDirectus({ users = { 'tok-a': 'user-a', 'tok-b': 'user-b' }, items = {} } = {}) {
  const calls = [];
  const state = { calls, items, down: false, reply: null, handle };

  async function handle(url, init = {}) {
    await new Promise((r) => setImmediate(r));
    const method = (init.method ?? 'GET').toUpperCase();
    const path = url.pathname;
    const auth = headerValue(init.headers, 'authorization');
    const body = init.body ? JSON.parse(init.body) : undefined;
    calls.push({ method, path, query: url.search, params: url.searchParams, auth, body });

    if (state.down) return errorResponse(503, 'SERVICE_UNAVAILABLE');
    if (state.reply) {
      const r = state.reply({ method, path, url, body, calls });
      if (r) return r;
    }
    if (method === 'GET' && path === '/users/me') {
      const token = bearerToken(auth);
      const userId = token === null ? undefined : users[token];
      return userId !== undefined ? jsonResponse(200, { data: { id: userId } }) : errorResponse(401, 'INVALID_CREDENTIALS');
    }
    const m = /^\/items\/([a-z_]+)(?:\/(.+))?$/.exec(path);
    if (m) {
      if (auth !== `Bearer ${SERVICE_TOKEN}`) return errorResponse(403, 'FORBIDDEN');
      const [, coll, id] = m;
      if (method === 'GET' && !id) {
        const wanted = url.searchParams.get('filter[id][_eq]');
        const rows = state.items[coll] ?? [];
        return jsonResponse(200, { data: wanted === null ? rows : rows.filter((r) => r.id === wanted) });
      }
      if (method === 'GET') {
        const row = (state.items[coll] ?? []).find((r) => r.id === decodeURIComponent(id));
        return row ? jsonResponse(200, { data: row }) : errorResponse(403, 'FORBIDDEN');
      }
      if (method === 'POST') return jsonResponse(200, { data: body });
      if (method === 'PATCH') return jsonResponse(200, { data: { id, ...body } });
      if (method === 'DELETE') return new Response(null, { status: 204 });
    }
    return errorResponse(404, 'NOT_FOUND');
  }
  return state;
}

/// Định tuyến mọi URL cùng gốc [DIRECTUS] vào `directus.handle`.
export function fakeFetch({ directus } = {}) {
  const origin = new URL(DIRECTUS).origin;
  return async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url);
    if (directus && url.origin === origin) return directus.handle(url, init ?? {});
    throw new Error(`fakeFetch: không có bộ xử lý cho ${url}`);
  };
}
