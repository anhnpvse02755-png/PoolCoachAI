// Kiểm token Bearer của người chơi qua Directus, đệm kết quả đúng 60 giây
// để không hỏi Directus ở mỗi yêu cầu. Không log token hay id người dùng.

import { createHash } from 'node:crypto';

const MAX_CACHE_ENTRIES = 1000;

function sha256Hex(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

/// Tạo bộ kiểm token. `now` được tiêm vào để test điều khiển được thời
/// gian. Chỉ kết quả thành công (có id) được đệm; token sai hay Directus
/// lỗi không bao giờ được đệm.
export function createAuth({ directus, now, ttlMs = 60_000 }) {
  const cache = new Map(); // sha256(token) hex -> { userId, until }

  function dropExpired(nowMs) {
    for (const [key, entry] of cache) {
      if (entry.until <= nowMs) cache.delete(key);
    }
  }

  /// Lấy id người chơi từ header `Authorization: Bearer <token>`. Không
  /// có Bearer hợp lệ → `null`, không hỏi Directus.
  async function userFor(authorizationHeader) {
    const match = typeof authorizationHeader === 'string' ? /^Bearer (.+)$/.exec(authorizationHeader) : null;
    if (!match) return null;
    const token = match[1];
    const key = sha256Hex(token);
    const nowMs = now().getTime();

    const cached = cache.get(key);
    if (cached && cached.until > nowMs) return cached.userId;

    const userId = await directus.userIdForToken(token);
    if (userId !== null) {
      if (cache.size >= MAX_CACHE_ENTRIES) dropExpired(nowMs);
      cache.set(key, { userId, until: nowMs + ttlMs });
    }
    return userId;
  }

  return { userFor };
}
