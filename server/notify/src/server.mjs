// Máy chủ HTTP notify: /healthz, /push/config (Task 7) và đăng ký / huỷ thiết bị
// / ack (Task 10). Không log token, endpoint hay khoá; log chỉ có băm id người dùng.

import { corsHeaders, readRawBody, sendJson, sendNoBody } from './http.mjs';
import { createAuth } from './auth.mjs';
import { DirectusError } from './directus.mjs';
import { hashUserId } from './log.mjs';
import {
  HEX64, RequestError, createRateLimiter, deliveryIdFor, deviceIdFor, serverKindsFor, validateRegister,
} from './devices.mjs';
import {
  ACK_PER_MIN, DELETE_PER_MIN, LEASE_MS, MAX_ACK_BYTES, MAX_BODY_BYTES, MAX_DEVICES, REGISTER_PER_HOUR,
} from './limits.mjs';

const DEVICE_PATH = /^\/push\/devices\/([^/]+)$/;

/// IP của khách: phần tử cuối của X-Forwarded-For (do proxy của chính ta thêm,
/// khách không giả được), không có thì địa chỉ socket.
function clientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (typeof xff === 'string' && xff.trim() !== '') return xff.split(',').at(-1).trim();
  return req.socket?.remoteAddress ?? '-';
}

export function createApp({ config, directus, planner, scheduler, now = () => new Date(), log = (l) => process.stdout.write(`${l}\n`), fetch = globalThis.fetch }) {
  void fetch;
  const auth = createAuth({ directus, now });
  const registerLimiter = createRateLimiter({ max: REGISTER_PER_HOUR, windowMs: 3_600_000, now });
  const ackLimiter = createRateLimiter({ max: ACK_PER_MIN, windowMs: 60_000, now });
  const deleteLimiter = createRateLimiter({ max: DELETE_PER_MIN, windowMs: 60_000, now });

  function writeLog({ method, path, status, startedAt, error, user }) {
    log(JSON.stringify({
      method, path, status, at: new Date().toISOString(), ms: Date.now() - startedAt,
      ...(user ? { user } : {}), ...(error ? { error } : {}),
    }));
  }

  /// Xử lý đăng ký. Trả [status, body, userHash?].
  async function register(req) {
    const raw = await readRawBody(req, MAX_BODY_BYTES);
    if (raw.overLimit) return [413, { error: 'invalid', field: 'body' }];
    let body;
    try {
      body = JSON.parse(raw.buffer.toString('utf8'));
    } catch {
      return [400, { error: 'invalid', field: 'body' }];
    }
    let v;
    try {
      v = validateRegister(body);
    } catch (e) {
      if (!(e instanceof RequestError)) throw e;
      return [400, e.code === 'unsupported_channel' ? { error: 'unsupported_channel' } : { error: 'invalid', field: e.field }];
    }
    const userId = await auth.userFor(req.headers.authorization);
    if (userId === null) return [401, { error: 'unauthorized' }];
    const user = hashUserId(userId);
    if (!registerLimiter.hit(userId)) return [429, { error: 'rate_limited' }, user];
    if (v.vapidPublicKey !== config.vapid.publicKey) return [409, { error: 'vapid_mismatch' }, user];

    let helper;
    try {
      helper = await planner.info();
    } catch {
      return [503, { error: 'helper_down' }, user];
    }
    if (planner.healthy === false) return [503, { error: 'helper_down' }, user];

    const nowDate = now();
    const nowIso = nowDate.toISOString();
    const deviceId = deviceIdFor(v.endpoint);
    const serverKinds = serverKindsFor({ seedFingerprint: v.seedFingerprint, enabled: config.enabled, helperFingerprint: helper?.fingerprint });
    const leaseUntil = config.enabled ? new Date(nowDate.getTime() + LEASE_MS).toISOString() : null;
    // Ghi lại endpoint và khoá ở MỌI lần đăng ký, và gán lại `user` khi khác:
    // chỉ một đăng ký có xác thực cho endpoint này mới chuyển được dòng.
    const fields = {
      user: userId, channel: v.channel, platform: 'web', endpoint: v.endpoint, key_p256dh: v.p256dh, key_auth: v.auth,
      timezone: v.timezone, seed_fingerprint: v.seedFingerprint, mode: 'server', server_kinds: serverKinds,
      lease_until: leaseUntil, last_seen_at: nowIso, failure_count: 0,
    };
    const existing = await directus.getDevice(deviceId);
    if (existing) await directus.updateDevice(deviceId, fields);
    else await directus.createDevice({ id: deviceId, ...fields, created_at: nowIso });

    // Quá MAX_DEVICES thiết bị: bỏ những máy lâu không thấy nhất (không bao giờ bỏ máy này).
    const mine = await directus.devicesOfUser(userId);
    const others = (mine ?? []).filter((d) => d.id !== deviceId)
      .sort((a, b) => String(a.last_seen_at ?? '').localeCompare(String(b.last_seen_at ?? '')));
    const surplus = others.length - (MAX_DEVICES - 1);
    if (surplus > 0) await directus.deleteDevices(others.slice(0, surplus).map((d) => d.id));

    // Thông báo máy này đã hiện hôm nay: giành trước để server không gửi lại.
    // Lỗi ở đây không làm hỏng đăng ký (tệ nhất là gửi trùng một lần).
    for (const s of v.shownToday) {
      if (!serverKinds.includes(s.kind)) continue;
      try {
        await directus.claimDelivery({
          id: deliveryIdFor(deviceId, s.kind, s.key), user: userId, device: deviceId, notification_id: 0,
          kind: s.kind, key: s.key, title: '', body: '', at: nowIso, sent_at: null,
        });
      } catch {
        // bỏ qua
      }
    }
    return [200, { deviceId, serverKinds, leaseUntil, serverNow: nowIso, enabled: config.enabled }, user];
  }

  /// Huỷ: 204 dù dòng có hay không; chỉ xoá khi dòng thuộc người gọi.
  async function unregister(req, id) {
    if (!HEX64.test(id)) return [204, undefined];
    if (!deleteLimiter.hit(clientIp(req))) return [429, { error: 'rate_limited' }];
    const userId = await auth.userFor(req.headers.authorization);
    if (userId === null) return [401, { error: 'unauthorized' }];
    const user = hashUserId(userId);
    const row = await directus.getDevice(id);
    if (row && row.user === userId) await directus.deleteDevices([id]);
    return [204, undefined, user];
  }

  /// Ack không xác thực: chỉ tin khi sha256(endpoint) khớp `device` của bản ghi.
  async function acknowledge(req) {
    const limited = !ackLimiter.hit(clientIp(req));
    const raw = await readRawBody(req, MAX_ACK_BYTES);
    if (limited) return [429, { error: 'rate_limited' }];
    if (raw.overLimit) return [204, undefined];
    let body;
    try {
      body = JSON.parse(raw.buffer.toString('utf8'));
    } catch {
      return [204, undefined];
    }
    const endpoint = body?.endpoint;
    const deliveryId = body?.deliveryId;
    if (typeof endpoint !== 'string' || endpoint.length === 0 || endpoint.length > 1024) return [204, undefined];
    if (typeof deliveryId !== 'string' || !HEX64.test(deliveryId)) return [204, undefined];
    const deviceId = deviceIdFor(endpoint);
    try {
      const delivery = await directus.getDelivery(deliveryId);
      if (delivery && delivery.device === deviceId && !delivery.shown_at) {
        const at = now().toISOString();
        await directus.updateDelivery(deliveryId, { shown_at: at });
        await directus.updateDevice(deviceId, { last_ack_at: at });
      }
    } catch {
      // Ack hỏng chỉ làm hộp thư báo thiếu, không bao giờ báo thừa.
    }
    return [204, undefined];
  }

  async function dispatch(req, res, startedAt, path) {
    const origin = req.headers.origin;
    const deviceMatch = DEVICE_PATH.exec(path);

    if (req.method === 'OPTIONS' && (path === '/push/devices' || path === '/push/ack' || deviceMatch)) {
      const cors = corsHeaders(origin, config.allowedOrigins);
      sendNoBody(res, 204, Object.keys(cors).length === 0 ? {} : {
        ...cors, 'Access-Control-Allow-Methods': 'GET, POST, DELETE', 'Access-Control-Allow-Headers': 'authorization, content-type',
      });
      writeLog({ method: 'OPTIONS', path: deviceMatch ? '/push/devices/:id' : path, status: 204, startedAt });
      return;
    }
    let route = null;
    if (req.method === 'POST' && path === '/push/devices') route = () => register(req);
    else if (req.method === 'POST' && path === '/push/ack') route = () => acknowledge(req);
    else if (req.method === 'DELETE' && deviceMatch) route = () => unregister(req, deviceMatch[1]);
    if (route) {
      let status; let body; let user;
      try {
        [status, body, user] = await route();
      } catch (e) {
        if (!(e instanceof DirectusError)) throw e;
        status = 503; body = { error: 'unavailable' };
      }
      if (body === undefined) sendNoBody(res, status, corsHeaders(origin, config.allowedOrigins));
      else sendJson(res, status, body, origin, config.allowedOrigins);
      writeLog({ method: req.method, path: deviceMatch ? '/push/devices/:id' : path, status, startedAt, user, ...(status >= 400 ? { error: body?.error } : {}) });
      return;
    }

    if (req.method === 'GET' && path === '/healthz') {
      sendJson(res, 200, {
        ok: true,
        enabled: config.enabled,
        lastCycleAt: scheduler.lastCycleAt?.toISOString() ?? null,
        helper: planner.healthy ? 'ok' : 'down',
      }, origin, config.allowedOrigins);
      return; // healthz không ghi nhật ký
    }
    if (req.method === 'GET' && path === '/push/config') {
      sendJson(res, 200, { enabled: config.enabled, publicKey: config.vapid.publicKey }, origin, config.allowedOrigins);
      writeLog({ method: 'GET', path, status: 200, startedAt });
      return;
    }
    sendJson(res, 404, { error: 'not_found' }, origin, config.allowedOrigins);
    writeLog({ method: req.method, path, status: 404, startedAt, error: 'not_found' });
  }

  return function handler(req, res) {
    const startedAt = Date.now();
    // Phân tích URL đúng một lần; request target hỏng → 400, không ném tiếp.
    let path;
    try {
      path = new URL(req.url, 'http://notify.internal').pathname;
    } catch {
      sendJson(res, 400, { error: 'bad_request' }, undefined, config.allowedOrigins);
      writeLog({ method: req.method, path: '-', status: 400, startedAt, error: 'bad_request' });
      return;
    }
    dispatch(req, res, startedAt, path).catch(() => {
      if (!res.headersSent) {
        try {
          sendJson(res, 500, { error: 'internal' }, req.headers.origin, config.allowedOrigins);
        } catch {
          // Mất kết nối trước khi trả lời được.
        }
      }
      writeLog({ method: req.method, path: DEVICE_PATH.test(path) ? '/push/devices/:id' : path, status: res.statusCode, startedAt, error: 'internal' });
    });
  };
}
