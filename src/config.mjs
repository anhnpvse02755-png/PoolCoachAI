// Đọc biến môi trường thành cấu hình dịch vụ notify (spec P6b mục 3). Bí mật
// (token dịch vụ, khoá VAPID riêng) chỉ nằm trong env của Easypanel. Khi báo
// lỗi chỉ nêu tên biến, không bao giờ nêu giá trị, và không log gì ở đây.

function isBlank(v) {
  return v === undefined || v === null || v.trim().length === 0;
}

function parseAllowedOrigins(raw) {
  return raw
    .split(',')
    .map((s) => s.trim().replace(/\/+$/, ''))
    .filter((s) => s.length > 0);
}

/// PORT: số nguyên 1–65535, không lấy phần số đứng trước chữ. `null` khi sai.
function parsePort(raw) {
  const trimmed = raw.trim();
  if (!/^\d+$/.test(trimmed)) return null;
  const n = Number.parseInt(trimmed, 10);
  return n >= 1 && n <= 65535 ? n : null;
}

function hasProtocol(raw, protocols) {
  try {
    return protocols.includes(new URL(raw.trim()).protocol);
  } catch {
    return false;
  }
}

/// Đọc [env] thành cấu hình. Ném lỗi nêu đủ tên biến thiếu hoặc sai.
export function loadConfig(env) {
  const bad = [];
  const need = (name) => {
    if (isBlank(env[name])) {
      bad.push(name);
      return '';
    }
    return env[name];
  };

  const directusUrl = need('DIRECTUS_URL');
  if (directusUrl !== '' && !hasProtocol(directusUrl, ['http:', 'https:'])) bad.push('DIRECTUS_URL');
  const serviceToken = need('PUSH_SERVICE_TOKEN').trim();
  const origins = isBlank(env.ALLOWED_ORIGINS) ? [] : parseAllowedOrigins(env.ALLOWED_ORIGINS);
  if (origins.length === 0) bad.push('ALLOWED_ORIGINS');

  const publicUrl = need('PUBLIC_URL');
  if (publicUrl !== '' && !hasProtocol(publicUrl, ['https:'])) bad.push('PUBLIC_URL');

  const publicKey = need('VAPID_PUBLIC_KEY').trim();
  const privateKey = need('VAPID_PRIVATE_KEY').trim();
  const subject = need('VAPID_SUBJECT');
  if (subject !== '' && !/^(https:|mailto:)\S+$/.test(subject.trim())) bad.push('VAPID_SUBJECT');

  // Công tắc tắt: đúng `true` hoặc `false`, thiếu là lỗi (không đoán mặc định).
  const enabledRaw = env.PUSH_ENABLED;
  if (enabledRaw !== 'true' && enabledRaw !== 'false') bad.push('PUSH_ENABLED');

  const port = parsePort(isBlank(env.PORT) ? '8080' : env.PORT);
  if (port === null) bad.push('PORT');

  if (bad.length > 0) {
    throw new Error(`Thiếu hoặc sai biến môi trường: ${[...new Set(bad)].join(', ')}`);
  }

  return {
    port,
    directusUrl: directusUrl.trim().replace(/\/+$/, ''),
    serviceToken,
    allowedOrigins: origins,
    publicUrl: publicUrl.trim().replace(/\/+$/, ''),
    vapid: { publicKey, privateKey, subject: subject.trim() },
    enabled: enabledRaw === 'true',
    planBin: isBlank(env.NOTIFY_PLAN_BIN) ? '/app/bin/notify_plan' : env.NOTIFY_PLAN_BIN.trim(),
  };
}
