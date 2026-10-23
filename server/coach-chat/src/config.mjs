// Đọc biến môi trường thành cấu hình máy chủ Coach Chat (spec mục 7.7, 13.8).
// Không log hay đưa giá trị biến ra ngoài khi báo lỗi — chỉ nêu tên biến.

const EFFORTS = new Set(['low', 'medium', 'high', 'xhigh', 'max']);
const FALLBACKS = new Set(['default', 'off']);

/// Biến bắt buộc thiếu hẳn hay chỉ có khoảng trắng đều coi là thiếu
/// (spec 7.7: máy chủ không khởi động được khi thiếu biến bắt buộc).
function isBlank(v) {
  return v === undefined || v === null || v.trim().length === 0;
}

/// Chuẩn hoá danh sách gốc được phép gọi CORS: tách theo dấu phẩy, cắt
/// khoảng trắng, bỏ phần tử rỗng.
function parseAllowedOrigins(raw) {
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/// Đọc PORT: phải là số nguyên trong khoảng cổng hợp lệ 1–65535. Chuỗi có
/// chữ lẫn số (ví dụ "9000abc") hay số thập phân đều bị coi là sai, không
/// âm thầm lấy phần số đứng trước. Trả `null` khi sai.
function parsePort(raw) {
  const trimmed = raw.trim();
  if (!/^\d+$/.test(trimmed)) return null;
  const n = Number.parseInt(trimmed, 10);
  return n >= 1 && n <= 65535 ? n : null;
}

/// Đọc biến môi trường [env] thành `Config`. Ném lỗi nêu đủ tên biến thiếu
/// hoặc sai, không bao giờ nêu giá trị.
export function loadConfig(env) {
  const missingOrBad = [];

  const anthropicApiKey = env.ANTHROPIC_API_KEY;
  if (isBlank(anthropicApiKey)) missingOrBad.push('ANTHROPIC_API_KEY');

  const directusUrlRaw = env.DIRECTUS_URL;
  if (isBlank(directusUrlRaw)) missingOrBad.push('DIRECTUS_URL');

  const directusServiceToken = env.DIRECTUS_SERVICE_TOKEN;
  if (isBlank(directusServiceToken)) missingOrBad.push('DIRECTUS_SERVICE_TOKEN');

  const allowedOriginsRaw = env.ALLOWED_ORIGINS;
  const allowedOrigins = isBlank(allowedOriginsRaw) ? [] : parseAllowedOrigins(allowedOriginsRaw);
  if (allowedOrigins.length === 0) missingOrBad.push('ALLOWED_ORIGINS');

  const portRaw = env.PORT ?? '8080';
  const port = parsePort(portRaw);
  if (port === null) missingOrBad.push('PORT');

  const modelRaw = env.CLAUDE_MODEL;
  const model = isBlank(modelRaw) ? 'claude-opus-5' : modelRaw.trim();

  const effort = env.CLAUDE_EFFORT ?? 'low';
  if (!EFFORTS.has(effort)) missingOrBad.push('CLAUDE_EFFORT');

  const fallbacksRaw = env.CLAUDE_FALLBACKS ?? 'default';
  if (!FALLBACKS.has(fallbacksRaw)) missingOrBad.push('CLAUDE_FALLBACKS');

  const dailyLimitRaw = env.DAILY_QUESTION_LIMIT ?? '30';
  const dailyLimit = Number.parseInt(dailyLimitRaw, 10);
  if (!Number.isInteger(dailyLimit) || dailyLimit <= 0 || String(dailyLimit) !== dailyLimitRaw.trim()) {
    missingOrBad.push('DAILY_QUESTION_LIMIT');
  }

  if (missingOrBad.length > 0) {
    throw new Error(`Thiếu hoặc sai biến môi trường: ${missingOrBad.join(', ')}`);
  }

  return {
    port,
    anthropicApiKey,
    model,
    effort,
    fallbacks: fallbacksRaw === 'default',
    dailyLimit,
    directusUrl: directusUrlRaw.replace(/\/+$/, ''),
    directusServiceToken,
    allowedOrigins,
  };
}
