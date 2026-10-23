// Máy chủ HTTP Coach Chat: định tuyến, CORS, hoàn lượt khi Claude lỗi, một
// dòng nhật ký JSON mỗi yêu cầu (spec mục 7, R7, R8, R10, R12, R15, R16,
// R17). Không log câu hỏi, câu trả lời, facts hay token ở đây.

import { createDirectus, DirectusError } from './directus.mjs';
import { createAuth } from './auth.mjs';
import { createQuota } from './quota.mjs';
import { createClaude, classifyClaudeError } from './claude.mjs';
import { parseChatRequest, parseBlockedReport, RequestError, MAX_BODY_BYTES } from './validate.mjs';
import { hashUserId } from './log.mjs';

const PATH_HEALTHZ = '/healthz';
const PATH_QUOTA = '/v1/coach-chat/quota';
const PATH_CHAT = '/v1/coach-chat';
const PATH_BLOCKED = '/v1/coach-chat/blocked';

/// Đọc toàn bộ thân yêu cầu thành `Buffer`, luôn đọc hết luồng tới `end`
/// (controller ruling 1) để phía khách không bị đứt kết nối, dù thân vượt
/// [maxBytes]. Trả `{ overLimit: true }` khi vượt, không giữ các đoạn dữ
/// liệu đã vượt trong bộ nhớ.
function readRawBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    let overLimit = false;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        overLimit = true;
      } else {
        chunks.push(chunk);
      }
    });
    req.on('end', () => resolve(overLimit ? { overLimit: true } : { overLimit: false, buffer: Buffer.concat(chunks) }));
    req.on('error', reject);
  });
}

/// Tiêu đề CORS cho một [origin], chỉ khi nằm trong [allowedOrigins]
/// (spec: mọi phản hồi tới nguồn được phép mang `Access-Control-Allow-Origin`
/// và `Vary: Origin`).
function corsHeaders(origin, allowedOrigins) {
  if (origin && allowedOrigins.includes(origin)) {
    return { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' };
  }
  return {};
}

function sendJson(res, status, body, origin, allowedOrigins) {
  const headers = { 'content-type': 'application/json', ...corsHeaders(origin, allowedOrigins) };
  res.writeHead(status, headers);
  res.end(body === undefined ? '' : JSON.stringify(body));
}

function sendText(res, status, text, origin, allowedOrigins) {
  const headers = { 'content-type': 'text/plain', ...corsHeaders(origin, allowedOrigins) };
  res.writeHead(status, headers);
  res.end(text);
}

function sendNoBody(res, status, headers = {}) {
  res.writeHead(status, headers);
  res.end();
}

/// Tạo đối tượng Coach Chat cho [config, fetch, now, log, claudeMaxRetries]
/// (spec mục 7, hợp đồng dây giữa app và máy chủ). `directus`, `auth`,
/// `quota` và `claude` được tạo đúng một lần mỗi tiến trình (controller
/// ruling 2), không tạo lại mỗi yêu cầu.
export function createApp({ config, fetch = globalThis.fetch, now = () => new Date(), log = (line) => process.stdout.write(`${line}\n`), claudeMaxRetries = 1 }) {
  const directus = createDirectus({ url: config.directusUrl, serviceToken: config.directusServiceToken, fetch });
  const auth = createAuth({ directus, now });
  const quota = createQuota({ directus, limit: config.dailyLimit, now });
  const claude = createClaude({
    apiKey: config.anthropicApiKey,
    model: config.model,
    effort: config.effort,
    fallbacks: config.fallbacks,
    fetch,
    maxRetries: claudeMaxRetries,
  });

  /// Ghi đúng một dòng nhật ký JSON cho yêu cầu — không bao giờ câu hỏi,
  /// câu trả lời, facts hay token (R17); id người dùng luôn được băm.
  function writeLog({ method, path, status, userId, model, stop, usage, startedAt, extra }) {
    log(JSON.stringify({
      method,
      path,
      status,
      ...(userId != null ? { user: hashUserId(userId) } : {}),
      ...(model !== undefined ? { model } : {}),
      ...(stop !== undefined ? { stop } : {}),
      ...(usage ? { in: usage.input, out: usage.output, cacheRead: usage.cacheRead } : {}),
      ...(extra ?? {}),
      ms: Date.now() - startedAt,
    }));
  }

  /// Hồi âm có nhãn lỗi của yêu cầu không phải JSON hợp lệ hoặc không đúng
  /// khuôn: `body` khi JSON.parse hỏng, `e.field` khi [RequestError].
  function invalidField(err, fallback) {
    return err instanceof RequestError ? err.field : fallback;
  }

  async function handleChatPost(req, res, origin) {
    const startedAt = Date.now();

    // 1. Đọc thân thô, giới hạn MAX_BODY_BYTES trước khi parse JSON
    // (controller ruling 1): luôn đọc hết luồng, vượt trần trả 413.
    const raw = await readRawBody(req, MAX_BODY_BYTES);
    if (raw.overLimit) {
      sendJson(res, 413, { error: 'invalid', field: 'body' }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: 413, startedAt });
      return;
    }

    // 2. Xác thực Bearer.
    let userId;
    try {
      userId = await auth.userFor(req.headers.authorization);
    } catch (err) {
      if (err instanceof DirectusError) {
        sendJson(res, 503, { error: 'unavailable' }, origin, config.allowedOrigins);
        writeLog({ method: 'POST', path: PATH_CHAT, status: 503, startedAt });
        return;
      }
      throw err;
    }
    if (userId === null) {
      sendJson(res, 401, { error: 'unauthorized' }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: 401, startedAt });
      return;
    }

    // 3. Parse JSON rồi kiểm khuôn yêu cầu.
    let parsed;
    try {
      const json = JSON.parse(raw.buffer.toString('utf8'));
      parsed = parseChatRequest(json);
    } catch (err) {
      sendJson(res, 400, { error: 'invalid', field: invalidField(err, 'body') }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: 400, userId, startedAt });
      return;
    }

    // 4. Trừ một lượt trước khi gọi Claude (controller ruling 3).
    let take;
    try {
      take = await quota.take(userId);
    } catch (err) {
      if (err instanceof DirectusError) {
        sendJson(res, 503, { error: 'unavailable' }, origin, config.allowedOrigins);
        writeLog({ method: 'POST', path: PATH_CHAT, status: 503, userId, startedAt });
        return;
      }
      throw err;
    }
    if (!take.ok) {
      sendJson(res, 429, { error: 'quota', limit: take.limit, resetAt: take.resetAt }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: 429, userId, startedAt });
      return;
    }
    const { day, remainingToday } = take;

    // 5. Gọi Claude. Lỗi SDK/transport thì hoàn lượt trước (chỉ sau khi
    // chắc đã trừ được — controller ruling 3), ghi lỗi hoàn lượt và nuốt.
    let ask;
    try {
      ask = await claude.ask(parsed);
    } catch (err) {
      try {
        await quota.refund(userId, day);
      } catch (refundErr) {
        log(JSON.stringify({ event: 'error', where: 'refund', message: refundErr.message }));
      }
      const classified = classifyClaudeError(err) ?? { status: 500, code: 'internal' };
      sendJson(res, classified.status, { error: classified.code }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: classified.status, userId, startedAt });
      return;
    }

    // 6. Cộng token đã dùng (ghi lỗi và nuốt, R15). Từ chối/bị cắt vẫn tốn
    // lượt (R7) — không hoàn ở đây.
    try {
      await quota.addUsage(userId, day, ask.usage);
    } catch (err) {
      log(JSON.stringify({ event: 'error', where: 'addUsage', message: err.message }));
    }

    if (ask.kind === 'refused' || ask.kind === 'truncated') {
      sendJson(res, 502, { error: ask.kind, remainingToday }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_CHAT, status: 502, userId, model: ask.model, stop: ask.stopReason, usage: ask.usage, startedAt });
      return;
    }

    sendJson(res, 200, {
      text: ask.text,
      model: ask.model,
      remainingToday,
      usage: { input: ask.usage.input, output: ask.usage.output, cacheRead: ask.usage.cacheRead },
    }, origin, config.allowedOrigins);
    writeLog({ method: 'POST', path: PATH_CHAT, status: 200, userId, model: ask.model, stop: ask.stopReason, usage: ask.usage, startedAt });
  }

  async function handleQuotaGet(req, res, origin) {
    const startedAt = Date.now();

    let userId;
    try {
      userId = await auth.userFor(req.headers.authorization);
    } catch (err) {
      if (err instanceof DirectusError) {
        sendJson(res, 503, { error: 'unavailable' }, origin, config.allowedOrigins);
        writeLog({ method: 'GET', path: PATH_QUOTA, status: 503, startedAt });
        return;
      }
      throw err;
    }
    if (userId === null) {
      sendJson(res, 401, { error: 'unauthorized' }, origin, config.allowedOrigins);
      writeLog({ method: 'GET', path: PATH_QUOTA, status: 401, startedAt });
      return;
    }

    let result;
    try {
      result = await quota.status(userId);
    } catch (err) {
      if (err instanceof DirectusError) {
        sendJson(res, 503, { error: 'unavailable' }, origin, config.allowedOrigins);
        writeLog({ method: 'GET', path: PATH_QUOTA, status: 503, userId, startedAt });
        return;
      }
      throw err;
    }

    sendJson(res, 200, result, origin, config.allowedOrigins);
    writeLog({ method: 'GET', path: PATH_QUOTA, status: 200, userId, startedAt });
  }

  async function handleBlockedPost(req, res, origin) {
    const startedAt = Date.now();

    const raw = await readRawBody(req, MAX_BODY_BYTES);
    if (raw.overLimit) {
      sendJson(res, 413, { error: 'invalid', field: 'body' }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_BLOCKED, status: 413, startedAt });
      return;
    }

    let userId;
    try {
      userId = await auth.userFor(req.headers.authorization);
    } catch (err) {
      if (err instanceof DirectusError) {
        sendJson(res, 503, { error: 'unavailable' }, origin, config.allowedOrigins);
        writeLog({ method: 'POST', path: PATH_BLOCKED, status: 503, startedAt });
        return;
      }
      throw err;
    }
    if (userId === null) {
      sendJson(res, 401, { error: 'unauthorized' }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_BLOCKED, status: 401, startedAt });
      return;
    }

    let parsed;
    try {
      const json = JSON.parse(raw.buffer.toString('utf8'));
      parsed = parseBlockedReport(json);
    } catch (err) {
      sendJson(res, 400, { error: 'invalid', field: invalidField(err, 'body') }, origin, config.allowedOrigins);
      writeLog({ method: 'POST', path: PATH_BLOCKED, status: 400, userId, startedAt });
      return;
    }

    sendNoBody(res, 204, corsHeaders(origin, config.allowedOrigins));
    writeLog({ method: 'POST', path: PATH_BLOCKED, status: 204, userId, startedAt, extra: { event: 'blocked', rule: parsed.rule } });
  }

  /// Preflight CORS (R16): nguồn được phép → 204 kèm tiêu đề CORS; nguồn lạ
  /// → 403, không tiêu đề; không có Origin (app điện thoại) → 204 thường.
  function handleOptions(req, res, origin) {
    if (!origin) {
      sendNoBody(res, 204);
      return;
    }
    if (!config.allowedOrigins.includes(origin)) {
      sendNoBody(res, 403);
      return;
    }
    sendNoBody(res, 204, {
      'Access-Control-Allow-Origin': origin,
      Vary: 'Origin',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'authorization, content-type',
      'Access-Control-Max-Age': '86400',
    });
  }

  async function dispatch(req, res) {
    const origin = req.headers.origin;
    const url = new URL(req.url, 'http://coach-chat.internal');
    const path = url.pathname;

    if (req.method === 'OPTIONS') {
      handleOptions(req, res, origin);
      return;
    }
    if (req.method === 'GET' && path === PATH_HEALTHZ) {
      sendText(res, 200, 'ok', origin, config.allowedOrigins);
      return;
    }
    if (req.method === 'GET' && path === PATH_QUOTA) {
      await handleQuotaGet(req, res, origin);
      return;
    }
    if (req.method === 'POST' && path === PATH_CHAT) {
      await handleChatPost(req, res, origin);
      return;
    }
    if (req.method === 'POST' && path === PATH_BLOCKED) {
      await handleBlockedPost(req, res, origin);
      return;
    }
    sendJson(res, 404, { error: 'not_found' }, origin, config.allowedOrigins);
  }

  return function handler(req, res) {
    dispatch(req, res).catch((err) => {
      if (!res.headersSent) {
        try {
          sendJson(res, 500, { error: 'internal' }, req.headers.origin, config.allowedOrigins);
        } catch {
          // Mất kết nối trước khi trả lời được — không còn gì để làm.
        }
      }
      log(JSON.stringify({ event: 'error', where: 'handler', message: err?.message ?? String(err) }));
    });
  };
}
