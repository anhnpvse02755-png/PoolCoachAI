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

// Bộ lọc kiểu Directus (`filter[f][_eq|_gte|_lt]`), chỉ dùng khi `filters: true`.
function passes(value, op, wanted) {
  if (op === '_eq') return value !== undefined && value !== null && String(value) === String(wanted);
  const a = Date.parse(value);
  const b = Date.parse(wanted);
  if (Number.isNaN(a) || Number.isNaN(b)) return false;
  return op === '_gte' ? a >= b : a < b;
}
function matchesParams(row, params) {
  for (const [k, v] of params) {
    const m = /^filter\[([a-z_]+)\]\[(_eq|_gte|_lt)\]$/.exec(k);
    if (m && !passes(row[m[1]], m[2], v)) return false;
  }
  return true;
}
// Directus thật: không có `limit` thì chỉ 100 dòng (QUERY_LIMIT_DEFAULT); -1 là tất cả.
function applyLimit(rows, raw) {
  const n = raw === undefined || raw === null ? 100 : Number(raw);
  return n < 0 ? rows : rows.slice(0, n);
}
function matchesFilter(row, filter) {
  return Object.entries(filter ?? {}).every(([f, ops]) => Object.entries(ops).every(([op, v]) => passes(row[f], op, v)));
}

/// Directus giả. `users` ánh xạ token người chơi sang id. `items` là kho
/// dòng theo collection (mảng) dùng cho GET; `reply` cho test ghi đè phản
/// hồi (nhận `{method, path, url, body}`, trả Response hoặc undefined).
/// `filters: true` áp đúng các bộ lọc danh sách như Directus thật (mặc định
/// chỉ lọc theo id, để test cũ giữ nguyên hành vi).
export function fakeDirectus({ users = { 'tok-a': 'user-a', 'tok-b': 'user-b' }, items = {}, filters = false } = {}) {
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
        if (filters) {
          const hit = rows.filter((r) => matchesParams(r, url.searchParams)).map((r) => ({ ...r }));
          return jsonResponse(200, { data: applyLimit(hit, url.searchParams.get('limit')) });
        }
        return jsonResponse(200, { data: wanted === null ? rows : rows.filter((r) => r.id === wanted) });
      }
      // Directus thật: một dòng đơn không có (hoặc không đọc được) trả 403, KHÔNG phải 404.
      const rows = (state.items[coll] ??= []);
      const idx = id === undefined ? -1 : rows.findIndex((r) => r.id === decodeURIComponent(id));
      if (method === 'GET') return idx >= 0 ? jsonResponse(200, { data: rows[idx] }) : errorResponse(403, 'FORBIDDEN');
      if (method === 'POST') {
        if (body?.id !== undefined && rows.some((r) => r.id === body.id)) return errorResponse(400, 'RECORD_NOT_UNIQUE');
        rows.push({ ...body });
        return jsonResponse(200, { data: body });
      }
      if (method === 'PATCH') {
        if (idx < 0) return errorResponse(403, 'FORBIDDEN');
        Object.assign(rows[idx], body);
        return jsonResponse(200, { data: rows[idx] });
      }
      if (method === 'DELETE') {
        if (id !== undefined) {
          if (idx < 0) return errorResponse(403, 'FORBIDDEN');
          rows.splice(idx, 1);
        } else if (Array.isArray(body)) {
          state.items[coll] = rows.filter((r) => !body.includes(r.id));
        } else if (filters && body?.query?.filter) {
          const doomed = new Set(applyLimit(rows.filter((r) => matchesFilter(r, body.query.filter)), body.query.limit));
          state.items[coll] = rows.filter((r) => !doomed.has(r));
        }
        return new Response(null, { status: 204 });
      }
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
