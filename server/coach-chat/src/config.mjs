// Đọc biến môi trường thành cấu hình máy chủ Coach Chat (spec mục 7.7, 13.8).
// Không log hay đưa giá trị biến ra ngoài khi báo lỗi — chỉ nêu tên biến.

const EFFORTS = new Set(['low', 'medium', 'high', 'xhigh', 'max']);
const FALLBACKS = new Set(['default', 'off']);

/// Chuẩn hoá danh sách gốc được phép gọi CORS: tách theo dấu phẩy, cắt
/// khoảng trắng, bỏ phần tử rỗng.
function parseAllowedOrigins(raw) {
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/// Đọc biến môi trường [env] thành `Config`. Ném lỗi nêu đủ tên biến thiếu
/// hoặc sai, không bao giờ nêu giá trị.
export function loadConfig(env) {
  const missingOrBad = [];

  const anthropicApiKey = env.ANTHROPIC_API_KEY;
  if (!anthropicApiKey) missingOrBad.push('ANTHROPIC_API_KEY');

  const directusUrlRaw = env.DIRECTUS_URL;
  if (!directusUrlRaw) missingOrBad.push('DIRECTUS_URL');

  const directusServiceToken = env.DIRECTUS_SERVICE_TOKEN;
  if (!directusServiceToken) missingOrBad.push('DIRECTUS_SERVICE_TOKEN');

  const allowedOriginsRaw = env.ALLOWED_ORIGINS;
  if (!allowedOriginsRaw) missingOrBad.push('ALLOWED_ORIGINS');

  const portRaw = env.PORT ?? '8080';
  const port = Number.parseInt(portRaw, 10);
  if (!Number.isInteger(port) || port <= 0) missingOrBad.push('PORT');

  const model = env.CLAUDE_MODEL ?? 'claude-opus-5';

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
    allowedOrigins: parseAllowedOrigins(allowedOriginsRaw),
  };
}
