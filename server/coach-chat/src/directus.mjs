// Gọi Directus cho Coach Chat: kiểm token của người chơi và đọc/ghi dòng
// hạn mức câu hỏi theo ngày (spec mục 7.x). Không log token, câu hỏi hay
// câu trả lời ở đây hay ở nơi gọi.

/// Lỗi gọi Directus. `status` 0 nghĩa là không tới được Directus hoặc hết
/// giờ chờ (R15); `code` là mã lỗi Directus trả về, hoặc `'unreachable'`.
export class DirectusError extends Error {
  constructor(status, code) {
    super(`Directus lỗi ${status}: ${code}`);
    this.status = status;
    this.code = code;
  }
}

async function errorCodeOf(response) {
  try {
    const body = await response.json();
    return body?.errors?.[0]?.extensions?.code ?? String(response.status);
  } catch {
    return String(response.status);
  }
}

/// Tạo client Directus. [fetch] được tiêm vào để test không gọi Directus
/// thật (global-constraints: tests offline).
export function createDirectus({ url, serviceToken, fetch, timeoutMs = 10_000 }) {
  async function request(path, { token, method = 'GET', body } = {}) {
    let response;
    try {
      response = await fetch(`${url}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          ...(body === undefined ? {} : { 'content-type': 'application/json' }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch {
      throw new DirectusError(0, 'unreachable');
    }
    return response;
  }

  /// `GET /users/me?fields=id` với Bearer của người chơi. Token sai hoặc
  /// hết hạn (401/403) trả `null`, không ném lỗi.
  async function userIdForToken(token) {
    const response = await request('/users/me?fields=id', { token });
    if (response.status === 401 || response.status === 403) return null;
    if (!response.ok) throw new DirectusError(response.status, await errorCodeOf(response));
    const { data } = await response.json();
    return data?.id ?? null;
  }

  /// `GET /items/coach_chat_usage?filter[id][_eq]=<id>&limit=1` với Bearer
  /// dịch vụ. Không có dòng → `null`.
  async function readUsage(id) {
    const response = await request(`/items/coach_chat_usage?filter[id][_eq]=${encodeURIComponent(id)}&limit=1`, {
      token: serviceToken,
    });
    if (!response.ok) throw new DirectusError(response.status, await errorCodeOf(response));
    const { data } = await response.json();
    return data?.[0] ?? null;
  }

  /// `POST /items/coach_chat_usage`. Dòng đã có id thì Directus trả
  /// `RECORD_NOT_UNIQUE`, ở đây thành `DirectusError(400, 'RECORD_NOT_UNIQUE')`.
  async function createUsage(row) {
    const response = await request('/items/coach_chat_usage', { method: 'POST', token: serviceToken, body: row });
    if (!response.ok) throw new DirectusError(response.status, await errorCodeOf(response));
  }

  /// `PATCH /items/coach_chat_usage/<encodeURIComponent(id)>` với Bearer
  /// dịch vụ.
  async function updateUsage(id, patch) {
    const response = await request(`/items/coach_chat_usage/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      token: serviceToken,
      body: patch,
    });
    if (!response.ok) throw new DirectusError(response.status, await errorCodeOf(response));
  }

  return { userIdForToken, readUsage, createUsage, updateUsage };
}
