// Định danh thiết bị và kiểm thân yêu cầu đăng ký (Task 10). Kiểm endpoint dùng
// đúng hàm của webpush.mjs, không có bản sao thứ hai.

import { createHash } from 'node:crypto';
import { KINDS } from './limits.mjs';
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

function validTimezone(tz) {
  if (typeof tz !== 'string' || tz.length === 0 || tz.length > 64) return false;
  try {
    new Intl.DateTimeFormat('en', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
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
  if (!validTimezone(body.timezone)) throw new RequestError('timezone');
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
    timezone: body.timezone, seedFingerprint: seed, vapidPublicKey: vapid, shownToday,
  };
}

/// Bộ đếm cửa sổ trượt trong bộ nhớ: `hit(key)` trả false khi vượt [max]
/// trong [windowMs].
export function createRateLimiter({ max, windowMs, now }) {
  const hits = new Map();
  return {
    hit(key) {
      const t = now().getTime();
      if (hits.size > 10_000) {
        for (const [k, list] of hits) if (list.every((x) => x <= t - windowMs)) hits.delete(k);
      }
      const list = (hits.get(key) ?? []).filter((x) => x > t - windowMs);
      if (list.length >= max) {
        hits.set(key, list);
        return false;
      }
      list.push(t);
      hits.set(key, list);
      return true;
    },
  };
}
