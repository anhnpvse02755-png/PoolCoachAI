// Gửi Web Push (VAPID + aes128gcm) bằng thư viện web-push ghim bản 3.6.7 và
// `fetch` được tiêm vào. Kết quả luôn là một đối tượng, không bao giờ ném lỗi, và
// không chứa thông điệp lỗi gốc để khoá riêng VAPID không có đường rò ra ngoài.

import { createHash } from 'node:crypto';
import webPush from 'web-push';
import { PUSH_HOSTS } from './limits.mjs';

export const MAX_MESSAGE_BYTES = 3000;
const MAX_RETRY_AFTER_MS = 60_000;
const DEFAULT_RETRY_AFTER_MS = 5_000;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 2_419_200;

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
  return PUSH_HOSTS.some((re) => re.test(url.hostname));
}

function retryAfterMs(response) {
  const raw = response.headers?.get('retry-after')?.trim();
  if (raw && /^\d+$/.test(raw)) return Math.min(MAX_RETRY_AFTER_MS, Number(raw) * 1000);
  return DEFAULT_RETRY_AFTER_MS;
}

export function createWebPushSender({ vapid, fetch, timeoutMs = 10_000 }) {
  async function send(device, message, { ttlSeconds: ttl, topic, urgency } = {}) {
    if (!endpointAllowed(device?.endpoint)) return { status: 'failed', code: 'bad_endpoint' };
    const json = JSON.stringify(message);
    if (Buffer.byteLength(json, 'utf8') > MAX_MESSAGE_BYTES) return { status: 'failed', code: 'payload_too_large' };

    let details;
    try {
      details = webPush.generateRequestDetails(
        { endpoint: device.endpoint, keys: { p256dh: device.key_p256dh, auth: device.key_auth } },
        json,
        { vapidDetails: vapid, TTL: ttl, topic, urgency, contentEncoding: 'aes128gcm' },
      );
    } catch {
      return { status: 'failed', code: 'bad_request' };
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
      return { status: 'failed', code: timedOut ? 'timeout' : 'network' };
    }

    const code = response.status;
    if (code >= 200 && code < 300) return { status: 'sent' };
    if (code === 404 || code === 410) return { status: 'gone', code };
    if (code === 429 || code >= 500) return { status: 'retry', code, retryAfterMs: retryAfterMs(response) };
    return { status: 'failed', code };
  }
  return { send };
}
