// Hợp đồng deviceFault (Task 11 dựa vào đây): mọi kết quả `failed` mang
// `deviceFault: boolean`. true chỉ khi lỗi do thiết bị: bad_endpoint, khoá
// thuê bao hỏng (bad_request) và HTTP 400. false cho 'auth' (401/403, lỗi VAPID
// của server), bad_options (options của người gọi sai, kiểm trước web-push, nên
// bad_request chỉ còn nghĩa là web-push từ chối khoá thuê bao), payload_too_large (kể cả 413), bad_message, network, timeout.
// 404/410 là `gone`; 429/5xx là `retry`. Chỉ deviceFault true mới được tính
// vào failure_count.
//
// Gửi Web Push (VAPID + aes128gcm) bằng thư viện web-push ghim bản 3.6.7 và
// `fetch` được tiêm vào. Kết quả luôn là một đối tượng, không bao giờ ném lỗi, và
// không chứa thông điệp lỗi gốc để khoá riêng VAPID không có đường rò ra ngoài.

import { createECDH, createHash } from 'node:crypto';
import webPush from 'web-push';
import { PUSH_HOSTS } from './limits.mjs';

export const MAX_MESSAGE_BYTES = 3000;
const MAX_RETRY_AFTER_MS = 60_000;
const DEFAULT_RETRY_AFTER_MS = 5_000;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 2_419_200;
const URGENCIES = ['very-low', 'low', 'normal', 'high'];

/// Chủ đề Web Push: base64url(sha256(`kind:key`)) cắt còn 32 ký tự.
export function pushTopic(kind, key) {
  return createHash('sha256').update(`${kind}:${key}`, 'utf8').digest('base64url').slice(0, 32);
}

/// `high` cho lịch tập và chuỗi ngày, còn lại `normal`.
export function pushUrgency(kind) {
  return kind === 'schedule' || kind === 'streak' ? 'high' : 'normal';
}

/// TTL (giây) đến lúc hết hiệu lực: tối thiểu 60, tối đa 28 ngày.
export function ttlSeconds(validUntilUtcIso, now) {
  const seconds = Math.floor((new Date(validUntilUtcIso).getTime() - new Date(now).getTime()) / 1000);
  if (!Number.isFinite(seconds)) return MIN_TTL_SECONDS;
  return Math.min(MAX_TTL_SECONDS, Math.max(MIN_TTL_SECONDS, seconds));
}

/// Endpoint phải là https, không cổng, không userinfo, host thuộc PUSH_HOSTS (R-F14).
function endpointAllowed(endpoint) {
  let url;
  try {
    url = new URL(endpoint);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:' || url.port !== '' || url.username !== '' || url.password !== '') return false;
  if (!endpoint.startsWith(`${url.origin}/`)) return false;
  return PUSH_HOSTS.some((re) => re.test(url.hostname));
}

const B64URL = /^[A-Za-z0-9_-]+$/;

function decodeKey(value, bytes) {
  if (typeof value !== 'string' || !B64URL.test(value)) return null;
  const buf = Buffer.from(value, 'base64url');
  return buf.length === bytes ? buf : null;
}

/// Kiểm cấu hình VAPID lúc dựng sender; ném lỗi với thông điệp cố định, không
/// bao giờ chứa nội dung khoá.
function assertVapid(vapid) {
  if (vapid === null || typeof vapid !== 'object') throw new Error('VAPID: thiếu cấu hình');
  const pub = decodeKey(vapid.publicKey, 65);
  if (!pub || pub[0] !== 0x04) throw new Error('VAPID: khoá công khai không hợp lệ');
  const priv = decodeKey(vapid.privateKey, 32);
  if (!priv) throw new Error('VAPID: khoá riêng không hợp lệ');
  let derived;
  try {
    const ecdh = createECDH('prime256v1');
    ecdh.setPrivateKey(priv);
    derived = ecdh.getPublicKey();
  } catch {
    throw new Error('VAPID: khoá riêng không hợp lệ');
  }
  if (!derived.equals(pub)) throw new Error('VAPID: khoá công khai không khớp khoá riêng');
  const subject = vapid.subject;
  if (typeof subject !== 'string' || !/^(https:|mailto:)/.test(subject)) throw new Error('VAPID: subject phải là https: hoặc mailto:');
}

const failed = (code, deviceFault) => ({ status: 'failed', code, deviceFault });

function retryAfterMs(response) {
  const raw = response.headers?.get('retry-after')?.trim();
  if (raw && /^\d+$/.test(raw)) return Math.min(MAX_RETRY_AFTER_MS, Number(raw) * 1000);
  return DEFAULT_RETRY_AFTER_MS;
}

export function createWebPushSender({ vapid, fetch, timeoutMs = 10_000 }) {
  assertVapid(vapid);
  async function sendUnsafe(device, message, options) {
    const { ttlSeconds: ttl, topic, urgency } = options ?? {};
    if (!endpointAllowed(device?.endpoint)) return failed('bad_endpoint', true);
    if (!Number.isInteger(ttl) || ttl < 0 || ttl > MAX_TTL_SECONDS
      || (topic !== undefined && !(typeof topic === 'string' && /^[A-Za-z0-9_-]{1,32}$/.test(topic)))
      || (urgency !== undefined && !URGENCIES.includes(urgency))) return failed('bad_options', false);
    let json;
    try {
      json = JSON.stringify(message);
    } catch {
      return failed('bad_message', false);
    }
    if (typeof json !== 'string') return failed('bad_message', false);
    if (Buffer.byteLength(json, 'utf8') > MAX_MESSAGE_BYTES) return failed('payload_too_large', false);

    let details;
    try {
      details = webPush.generateRequestDetails(
        { endpoint: device.endpoint, keys: { p256dh: device.key_p256dh, auth: device.key_auth } },
        json,
        { vapidDetails: vapid, TTL: ttl, topic, urgency, contentEncoding: 'aes128gcm' },
      );
    } catch {
      return failed('bad_request', true);
    }

    let response;
    try {
      response = await fetch(details.endpoint, {
        method: details.method,
        headers: details.headers,
        body: details.body,
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (e) {
      const timedOut = e?.name === 'TimeoutError' || e?.name === 'AbortError';
      return failed(timedOut ? 'timeout' : 'network', false);
    }

    if (typeof response?.status !== 'number') return failed('network', false);
    try {
      await response.body?.cancel();
    } catch {
      // thân phản hồi không đọc được thì bỏ qua
    }
    const code = response.status;
    if (code >= 200 && code < 300) return { status: 'sent' };
    if (code === 404 || code === 410) return { status: 'gone', code };
    if (code === 429 || code >= 500) return { status: 'retry', code, retryAfterMs: retryAfterMs(response) };
    if (code === 401 || code === 403) return failed('auth', false);
    if (code === 413) return failed('payload_too_large', false);
    return { status: 'failed', code, deviceFault: code === 400 };
  }
  /// Không bao giờ reject: lỗi bất ngờ thành failed 'internal', không kèm thông điệp.
  async function send(device, message, options) {
    try {
      return await sendUnsafe(device, message, options);
    } catch {
      return failed('internal', false);
    }
  }
  return { send };
}
