// Định danh thiết bị và kiểm thân yêu cầu đăng ký (Task 10). Kiểm endpoint dùng
// đúng hàm của webpush.mjs, không có bản sao thứ hai.

import { createHash } from 'node:crypto';
import { KINDS, LIMITER_MAX_KEYS } from './limits.mjs';
import { endpointAllowed } from './webpush.mjs';

export const MAX_ENDPOINT_CHARS = 1024;
export const MAX_SHOWN_TODAY = 50;
export const MAX_KEY_CHARS = 200;
/// Id thiết bị và id bản ghi gửi đều là sha256 hex.
export const HEX64 = /^[0-9a-f]{64}$/;
const B64URL = /^[A-Za-z0-9_-]+$/;

/// Lỗi thân yêu cầu: `field` là trường sai, `code` là mã trả cho khách.
export class RequestError extends Error {
  constructor(field, code = 'invalid') {
    super(`${code}: ${field}`);
    this.field = field;
    this.code = code;
  }
}

/// Id thiết bị: sha256 hex của endpoint (hoặc token).
export function deviceIdFor(endpointOrToken) {
  return createHash('sha256').update(endpointOrToken, 'utf8').digest('hex');
}

/// Id bản ghi gửi, trùng công thức của scheduler.
export function deliveryIdFor(deviceId, kind, key) {
  return deviceIdFor(`${deviceId}|${kind}|${key}`);
}

/// Loại do server lo: rỗng khi tắt; đủ bốn khi vân tay hạt giống khớp helper;
/// còn không thì bỏ `recommendation` (máy này tự lo gợi ý).
export function serverKindsFor({ seedFingerprint, enabled, helperFingerprint }) {
  if (!enabled) return [];
  if (typeof seedFingerprint === 'string' && seedFingerprint === helperFingerprint) return [...KINDS];
  return KINDS.filter((k) => k !== 'recommendation');
}

const isB64 = (v) => typeof v === 'string' && v.length >= 1 && v.length <= MAX_KEY_CHARS && B64URL.test(v);

// Tên IANA dạng Area/Location (hoặc UTC); loại độ lệch như +07:00 và tên cũ không '/' (EST5EDT).
const IANA_NAME = /^(?:UTC|[A-Za-z][A-Za-z_]*(?:\/[A-Za-z0-9_+-]+)+)$/i;

/// Tên múi chuẩn (đúng chữ hoa/thường) hoặc `null` nếu không phải tên IANA.
/// Helper Dart dùng cùng bảng múi nên nhận đúng tên này (xem TzWallClock).
function canonicalTimezone(tz) {
  if (typeof tz !== 'string' || tz.length === 0 || tz.length > 64 || !IANA_NAME.test(tz)) return null;
  try {
    const resolved = new Intl.DateTimeFormat('en', { timeZone: tz }).resolvedOptions().timeZone;
    return IANA_NAME.test(resolved) ? resolved : null;
  } catch {
    return null;
  }
}

/// Ngày hôm nay ở múi [timeZone], dạng khoá của app (không đệm số 0): `2026-10-5`.
export function todayKeyDate(nowDate, timeZone) {
  const parts = new Intl.DateTimeFormat('en', { timeZone, year: 'numeric', month: 'numeric', day: 'numeric' }).formatToParts(nowDate);
  const get = (type) => parts.find((p) => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

const KEY_DATE = /(?:^|:)(\d{4}-\d{1,2}-\d{1,2})(?::|$)/;

/// Bỏ trùng và chỉ giữ thông báo của hôm nay. Khoá của streak, recommendation
/// và schedule mã hoá ngày hiện tại (`y-m-d`, không đệm số 0) nên phải trùng
/// hôm nay ở múi máy. Khoá maintenance mã hoá ngày ĐẾN HẠN nên không ràng ngày.
export function shownTodayOf(list, timeZone, nowDate) {
  const today = todayKeyDate(nowDate, timeZone);
  const seen = new Set();
  const out = [];
  for (const s of list) {
    const id = `${s.kind}|${s.key}`;
    if (seen.has(id)) continue;
    seen.add(id);
    if (s.kind !== 'maintenance' && KEY_DATE.exec(s.key)?.[1] !== today) continue;
    out.push(s);
  }
  return out;
}

/// Khoá giới hạn theo IP: IPv4 giữ nguyên; IPv6 gộp theo /64 (một mạng nhà có
/// cả /64 địa chỉ để xoay); IPv4 ánh xạ trong IPv6 về IPv4.
export function ipBucket(ip) {
  if (typeof ip !== 'string' || !ip.includes(':')) return ip;
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
  if (mapped) return mapped[1];
  const clean = ip.split('%')[0];
  const [head, tail] = clean.split('::');
  const h = head === '' ? [] : head.split(':');
  const t = tail === undefined || tail === '' ? [] : tail.split(':');
  const groups = tail === undefined ? h : [...h, ...Array(Math.max(0, 8 - h.length - t.length)).fill('0'), ...t];
  return `${groups.slice(0, 4).map((g) => Number.parseInt(g || '0', 16).toString(16)).join(':')}::/64`;
}

/// Kiểm thân đăng ký (hình PushSubscription.toJSON(): `keys.{p256dh,auth}`).
export function validateRegister(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) throw new RequestError('body');
  if (body.channel === 'fcm') throw new RequestError('channel', 'unsupported_channel');
  if (body.channel !== 'web') throw new RequestError('channel');
  const { endpoint } = body;
  if (typeof endpoint !== 'string' || endpoint.length === 0 || endpoint.length > MAX_ENDPOINT_CHARS || !endpointAllowed(endpoint)) {
    throw new RequestError('endpoint');
  }
  const { keys } = body;
  if (keys === null || typeof keys !== 'object' || Array.isArray(keys)) throw new RequestError('keys');
  if (!isB64(keys.p256dh)) throw new RequestError('keys.p256dh');
  if (!isB64(keys.auth)) throw new RequestError('keys.auth');
  const timezone = canonicalTimezone(body.timezone);
  if (timezone === null) throw new RequestError('timezone');
  const seed = body.seedFingerprint ?? null;
  if (seed !== null && (typeof seed !== 'string' || seed.length > 64)) throw new RequestError('seedFingerprint');
  const vapid = body.vapidPublicKey;
  if (typeof vapid !== 'string' || vapid.length === 0 || vapid.length > 200) throw new RequestError('vapidPublicKey');

  const shown = body.shownToday ?? [];
  if (!Array.isArray(shown) || shown.length > MAX_SHOWN_TODAY) throw new RequestError('shownToday');
  const shownToday = shown.map((s) => {
    if (s === null || typeof s !== 'object' || !KINDS.includes(s.kind) || typeof s.key !== 'string' || s.key.length === 0 || s.key.length > 200) {
      throw new RequestError('shownToday');
    }
    return { kind: s.kind, key: s.key };
  });

  return {
    channel: 'web', endpoint, p256dh: keys.p256dh, auth: keys.auth,
    timezone, seedFingerprint: seed, vapidPublicKey: vapid, shownToday,
  };
}

/// Bộ đếm cửa sổ trượt trong bộ nhớ: `hit(key)` trả false khi vượt [max]
/// trong [windowMs]. Bị chặn cứng ở [maxKeys] khoá (loại khoá dùng lâu nhất)
/// và quét khoá hết hạn đúng một lần mỗi cửa sổ, nên kẻ xoay địa chỉ nguồn
/// không làm bộ nhớ hay mỗi yêu cầu phình theo.
export function createRateLimiter({ max, windowMs, now, maxKeys = LIMITER_MAX_KEYS }) {
  const hits = new Map(); // thứ tự chèn = thứ tự dùng gần nhất
  let lastSweep = now().getTime();
  return {
    size: () => hits.size,
    hit(key) {
      const t = now().getTime();
      if (t - lastSweep >= windowMs) {
        lastSweep = t;
        for (const [k, list] of hits) if (list[list.length - 1] <= t - windowMs) hits.delete(k);
      }
      const list = (hits.get(key) ?? []).filter((x) => x > t - windowMs);
      hits.delete(key);
      while (hits.size >= maxKeys) hits.delete(hits.keys().next().value);
      hits.set(key, list);
      if (list.length >= max) return false;
      list.push(t);
      return true;
    },
  };
}
