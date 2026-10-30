// Client Directus cho dịch vụ notify. Mọi lệnh gọi dịch vụ mang Bearer service
// token (chỉ trong bộ nhớ, không log). 429 được thử lại theo Retry-After với số
// lần có giới hạn (R-F5).

/// Lỗi gọi Directus. `status` 0 nghĩa là không tới được hoặc hết giờ chờ;
/// `code` là mã lỗi Directus, hoặc `'unreachable'`.
export class DirectusError extends Error {
  constructor(status, code) {
    super(`Directus lỗi ${status}: ${code}`);
    this.status = status;
    this.code = code;
  }
}

const MAX_ATTEMPTS = 4; // 1 lần đầu + tối đa 3 lần thử lại sau 429
const DEFAULT_RETRY_MS = 1000;
const MAX_RETRY_MS = 10_000;

async function errorCodeOf(response) {
  try {
    const body = await response.json();
    return body?.errors?.[0]?.extensions?.code ?? String(response.status);
  } catch {
    return String(response.status);
  }
}

async function readJsonBody(response) {
  try {
    return await response.json();
  } catch (e) {
    if (e?.name === 'AbortError' || e?.name === 'TimeoutError') throw new DirectusError(0, 'unreachable');
    throw new DirectusError(502, 'BAD_BODY');
  }
}

/// Thời gian chờ trước lần thử lại, từ `Retry-After` (giây), có chặn trên.
function retryDelayMs(response, nowMs) {
  const raw = response.headers.get('retry-after')?.trim();
  let ms = null;
  if (raw && /^\d+$/.test(raw)) ms = Number.parseInt(raw, 10) * 1000;
  else if (raw) {
    const at = Date.parse(raw);
    if (!Number.isNaN(at)) ms = at - nowMs();
  }
  if (ms === null) return DEFAULT_RETRY_MS;
  return Math.min(Math.max(ms, 1), MAX_RETRY_MS);
}

const sleepReal = (ms) => new Promise((r) => setTimeout(r, ms));

const USER_DATA = ['drill_logs', 'timer_sessions', 'schedule_slots', 'cue_equipment', 'pool_matches', 'bu_tests', 'bu_drill_results'];

const q = encodeURIComponent;

/// Tạo client. [fetch] và [sleep] được tiêm để test không dùng mạng hay giờ thật.
export function createDirectus({ url, serviceToken, fetch, timeoutMs = 10_000, sleep = sleepReal, nowMs = Date.now }) {
  async function request(path, { token = serviceToken, method = 'GET', body } = {}) {
    for (let attempt = 1; ; attempt += 1) {
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
      if (response.status === 429 && attempt < MAX_ATTEMPTS) {
        await sleep(retryDelayMs(response, nowMs));
        continue;
      }
      return response;
    }
  }

  async function fail(response) {
    return new DirectusError(response.status, await errorCodeOf(response));
  }

  async function getData(path) {
    const response = await request(path);
    if (!response.ok) throw await fail(response);
    return (await readJsonBody(response)).data;
  }

  async function send(path, method, body) {
    const response = await request(path, { method, body });
    if (!response.ok) throw await fail(response);
  }

  /// `GET /users/me?fields=id` với Bearer của người chơi; 401/403 → `null`.
  async function userIdForToken(token) {
    const response = await request('/users/me?fields=id', { token });
    if (response.status === 401 || response.status === 403) return null;
    if (!response.ok) throw await fail(response);
    const { data } = await readJsonBody(response);
    return data?.id ?? null;
  }

  const listServerDevices = () => getData(`/items/push_devices?filter[mode][_eq]=server&limit=-1`);
  const devicesOfUser = (userId) => getData(`/items/push_devices?filter[user][_eq]=${q(userId)}&limit=-1`);

  /// Một thiết bị theo id; chỉ 404 là `null`, 403 và lỗi khác ném (403 là quyền hỏng).
  async function getDevice(id) {
    const response = await request(`/items/push_devices/${q(id)}`);
    if (response.status === 404) return null;
    if (!response.ok) throw await fail(response);
    return (await readJsonBody(response)).data ?? null;
  }
  const createDevice = (row) => send('/items/push_devices', 'POST', row);
  const updateDevice = (id, patch) => send(`/items/push_devices/${q(id)}`, 'PATCH', patch);
  async function deleteDevices(ids) {
    if (ids.length === 0) return;
    await send('/items/push_devices', 'DELETE', ids);
  }

  /// Đọc dữ liệu tập của người chơi: mỗi collection một GET theo `fields[c]`.
  async function readUserData(userId, fields) {
    for (const c of USER_DATA) {
      if (typeof fields?.[c] !== 'string' || fields[c] === '') throw new Error(`Thiếu fields cho ${c}`);
    }
    const entries = await Promise.all(USER_DATA.map(async (c) => [
      c,
      await getData(`/items/${c}?filter[user_created][_eq]=${q(userId)}&fields=${q(fields[c])}&limit=-1`),
    ]));
    return Object.fromEntries(entries);
  }

  /// Dòng `notification_settings` của người chơi (id = id người dùng), hoặc `null`.
  async function readSettings(userId, fields) {
    const rows = await getData(`/items/notification_settings?filter[id][_eq]=${q(userId)}&fields=${q(fields)}&limit=1`);
    return rows?.[0] ?? null;
  }

  const deliveriesOfUser = (userId, sinceIso) =>
    getData(`/items/push_deliveries?filter[user][_eq]=${q(userId)}&filter[at][_gte]=${q(sinceIso)}&limit=-1`);

  /// Giành quyền gửi bằng cách tạo dòng nhật ký id cố định: `false` khi đã có
  /// (`RECORD_NOT_UNIQUE`), tức tiến trình khác đã giành trước.
  async function claimDelivery(row) {
    const response = await request('/items/push_deliveries', { method: 'POST', body: row });
    if (response.ok) return true;
    const code = await errorCodeOf(response);
    if (code === 'RECORD_NOT_UNIQUE') return false;
    throw new DirectusError(response.status, code);
  }
  async function getDelivery(id) {
    const response = await request(`/items/push_deliveries/${q(id)}`);
    if (response.status === 404) return null;
    if (!response.ok) throw await fail(response);
    return (await readJsonBody(response)).data ?? null;
  }
  const updateDelivery = (id, patch) => send(`/items/push_deliveries/${q(id)}`, 'PATCH', patch);
  const deleteDeliveriesBefore = (iso) =>
    send('/items/push_deliveries', 'DELETE', { query: { filter: { at: { _lt: iso } } } });

  return {
    userIdForToken, listServerDevices, devicesOfUser, getDevice, createDevice, updateDevice, deleteDevices,
    readUserData, readSettings, deliveriesOfUser, claimDelivery, getDelivery, updateDelivery, deleteDeliveriesBefore,
  };
}
