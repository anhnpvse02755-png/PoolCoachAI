// Phần HTTP dùng chung: đọc thân thô có trần, CORS, gửi JSON.

/// Đọc toàn bộ thân yêu cầu thành `Buffer`, luôn đọc hết luồng tới `end` để
/// phía khách không bị đứt kết nối, dù thân vượt [maxBytes]. Trả
/// `{ overLimit: true }` khi vượt, không giữ các đoạn đã vượt trong bộ nhớ.
export function readRawBody(req, maxBytes) {
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

/// Tiêu đề CORS cho [origin], chỉ khi nằm trong [allowedOrigins].
export function corsHeaders(origin, allowedOrigins) {
  // Vary: Origin luôn có, kể cả khi origin lạ hay vắng, để bộ đệm chung không
  // lưu nhầm bản không-CORS cho mọi người.
  if (origin && allowedOrigins.includes(origin)) {
    return { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' };
  }
  return { Vary: 'Origin' };
}

export function sendJson(res, status, body, origin, allowedOrigins) {
  const headers = { 'content-type': 'application/json', ...corsHeaders(origin, allowedOrigins) };
  res.writeHead(status, headers);
  res.end(body === undefined ? '' : JSON.stringify(body));
}

export function sendNoBody(res, status, headers = {}) {
  res.writeHead(status, headers);
  res.end();
}
