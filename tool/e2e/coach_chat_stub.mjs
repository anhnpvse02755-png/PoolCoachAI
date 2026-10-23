// Máy chủ giả cho dịch vụ Coach Chat (Task 12): dựng lại đúng hợp đồng dây
// Task 6 trong bộ nhớ, không gọi Claude, không cần Directus — dùng để build
// app web trỏ vào đây rồi lái bằng Chrome mà không tốn một câu hỏi thật.
//   node tool/e2e/coach_chat_stub.mjs [port=8787]
import http from 'node:http';

const PORT = Number(process.argv[2] ?? 8787);

// responsive.mjs và serve.mjs luôn phục vụ bản web cục bộ ở cổng này — chỉ
// origin này được phép gọi, như ALLOWED_ORIGINS của máy chủ thật.
const ALLOWED_ORIGIN = 'http://localhost:5555';

// Khớp DAILY_QUESTION_LIMIT mặc định của config.mjs thật; cho đổi qua biến
// môi trường để khớp COACH_CHAT_LIMIT mà coach_chat_ui.mjs đọc.
const LIMIT = Number(process.env.COACH_CHAT_LIMIT ?? 30);

// Không có chữ số nên luôn qua được bộ lọc coachReplyBlock phía app
// (lib/domain/coach/chat_filter.dart) — xem brief Task 12.
const FIXED_TEXT =
  'Theo số liệu của bạn, hôm nay nên tập đúng nhóm trên thẻ Hôm nay. Bạn thấy cú nào hay hỏng nhất?';

const PATH_HEALTHZ = '/healthz';
const PATH_QUOTA = '/v1/coach-chat/quota';
const PATH_CHAT = '/v1/coach-chat';
const PATH_BLOCKED = '/v1/coach-chat/blocked';

// Một bộ đếm mỗi token, sống trong bộ nhớ của tiến trình — không chia theo
// ngày giờ VN như quota.mjs thật: bài này chỉ chạy trong một lượt kiểm tra
// ngắn, không cần bền hay chính xác theo lịch.
const usedByToken = new Map();

/// Lấy token từ header `Authorization: Bearer <token>`, như auth.mjs thật.
function tokenFor(authorizationHeader) {
  const match = typeof authorizationHeader === 'string' ? /^Bearer (.+)$/.exec(authorizationHeader) : null;
  return match ? match[1] : null;
}

/// Giờ đặt lại giả: 00:00 giờ VN (UTC+7) của ngày hôm sau, như nextResetAt
/// thật — chỉ cần có mặt và hợp lệ, không bài nào kiểm tra giá trị chính xác.
function resetAt() {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(17, 0, 0, 0);
  return d.toISOString();
}

/// Tiêu đề CORS cho [origin], chỉ khi đúng origin được phép (R16).
function corsHeaders(origin) {
  return origin === ALLOWED_ORIGIN ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : {};
}

function sendJson(res, status, body, origin) {
  res.writeHead(status, { 'content-type': 'application/json', ...corsHeaders(origin) });
  res.end(JSON.stringify(body));
}

function sendNoBody(res, status, headers = {}) {
  res.writeHead(status, headers);
  res.end();
}

/// Đọc hết thân yêu cầu rồi bỏ: bài này không cần nội dung, nhưng vẫn phải
/// đọc hết luồng tới `end` để phía khách không bị đứt kết nối (như
/// readRawBody của server.mjs thật). Phải bắt cả 'error' — khách bỏ giữa
/// chừng (đóng kết nối sớm) thì luồng không bao giờ bắn 'end', và không có
/// nhánh này thì request treo mãi.
function drain(req) {
  return new Promise((resolve) => {
    req.on('data', () => {});
    req.on('end', resolve);
    req.on('error', resolve);
  });
}

/// Preflight CORS (R16), mirror hệt `handleOptions` của server/coach-chat:
/// nguồn được phép → 204 kèm tiêu đề CORS; nguồn lạ → 403, không tiêu đề;
/// không có Origin → 204 thường.
function handleOptions(res, origin) {
  if (!origin) return sendNoBody(res, 204);
  if (origin !== ALLOWED_ORIGIN) return sendNoBody(res, 403);
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
  const url = new URL(req.url, 'http://coach-chat-stub.internal');
  const path = url.pathname;

  if (req.method === 'OPTIONS') {
    handleOptions(res, origin);
    return;
  }
  if (req.method === 'GET' && path === PATH_HEALTHZ) {
    res.writeHead(200, { 'content-type': 'text/plain', ...corsHeaders(origin) });
    res.end('ok');
    return;
  }

  const token = tokenFor(req.headers.authorization);

  if (req.method === 'GET' && path === PATH_QUOTA) {
    await drain(req);
    if (!token) { sendJson(res, 401, { error: 'unauthorized' }, origin); return; }
    const used = usedByToken.get(token) ?? 0;
    sendJson(res, 200, { limit: LIMIT, used, remainingToday: Math.max(LIMIT - used, 0), resetAt: resetAt() }, origin);
    return;
  }

  if (req.method === 'POST' && path === PATH_CHAT) {
    await drain(req);
    if (!token) { sendJson(res, 401, { error: 'unauthorized' }, origin); return; }
    const used = usedByToken.get(token) ?? 0;
    if (used >= LIMIT) { sendJson(res, 429, { error: 'quota', limit: LIMIT, resetAt: resetAt() }, origin); return; }
    const next = used + 1;
    usedByToken.set(token, next);
    sendJson(
      res,
      200,
      {
        text: FIXED_TEXT,
        model: 'stub',
        remainingToday: Math.max(LIMIT - next, 0),
        usage: { input: 0, output: 0, cacheRead: 0 },
      },
      origin,
    );
    return;
  }

  if (req.method === 'POST' && path === PATH_BLOCKED) {
    await drain(req);
    if (!token) { sendJson(res, 401, { error: 'unauthorized' }, origin); return; }
    sendNoBody(res, 204, corsHeaders(origin));
    return;
  }

  await drain(req);
  sendJson(res, 404, { error: 'not_found' }, origin);
}

http
  .createServer((req, res) => {
    dispatch(req, res).catch((err) => {
      if (!res.headersSent) sendJson(res, 500, { error: 'internal' }, req.headers.origin);
      console.error(`coach-chat stub lỗi không lường được: ${err?.stack ?? err}`);
    });
  })
  .listen(PORT, () => console.log(`coach-chat stub: http://localhost:${PORT}/ (limit=${LIMIT})`));
