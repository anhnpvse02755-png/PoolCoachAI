// Hằng số giới hạn của dịch vụ notify (spec P6b mục 3). Một nơi duy nhất.

export const CYCLE_MS = 15 * 60_000;
export const TICK_MS = 60_000;
export const LEASE_MS = 6 * 3_600_000;
export const LEASE_MARGIN_MS = 5 * 60_000;
export const DAILY_CAP = 12;
export const MAX_DEVICES = 10;
export const REGISTER_PER_HOUR = 30;
export const FAILURES_TO_PRUNE = 5;
export const STALE_DEVICE_DAYS = 60;
export const DELIVERY_KEEP_DAYS = 30;
export const HORIZON_MS = 24 * 3_600_000;
export const HELPER_TIMEOUT_MS = 10_000;
// Số yêu cầu tối đa cùng bay tới helper; phần vượt xếp hàng trong planner.
// Chỉ giới hạn helper, không giới hạn các lần đọc Directus.
export const HELPER_MAX_INFLIGHT = 4;
export const MAX_BODY_BYTES = 8192;
export const MAX_ACK_BYTES = 2048;
export const KINDS = ['recommendation', 'maintenance', 'schedule', 'streak'];
export const CHANNELS = ['web', 'fcm'];
export const PUSH_HOSTS = [
  /^fcm\.googleapis\.com$/,
  /\.push\.services\.mozilla\.com$/,
  /\.notify\.windows\.com$/,
  /\.push\.apple\.com$/,
];
// Trần theo IP cho ack và DELETE (R-F14), cửa sổ một phút.
export const ACK_PER_MIN = 60;
export const DELETE_PER_MIN = 60;
// Trần theo IP cho đăng ký, kiểm TRƯỚC khi hỏi Directus về token (chặn lũ token ngẫu nhiên).
export const REGISTER_IP_PER_MIN = 60;
// Trần số khoá của mỗi bộ đếm giới hạn.
export const LIMITER_MAX_KEYS = 10_000;
// Số dòng giành trước ghi song song khi đăng ký.
export const CLAIM_CONCURRENCY = 4;
// Số người xử lý song song trong một chu kỳ hay một nhịp (mỗi người ~9 lần đọc
// Directus): giữ Directus khỏi bị dội (R-F5).
export const USER_CONCURRENCY = 4;
// Chỉ gia hạn lease khi còn dưới 5 giờ (LEASE_MS − 1 giờ): chu kỳ 15 phút không
// PATCH mọi thiết bị mỗi lần (R-F5).
export const LEASE_RENEW_BELOW_MS = LEASE_MS - 3_600_000;
// Hai lần thử lại sau 429/5xx (★10): chờ ít nhất chừng này, hoặc Retry-After nếu dài hơn.
export const RETRY_FLOORS_MS = [2_000, 8_000];
// Tắt êm: đợi việc đang chạy của bộ lập lịch tối đa chừng này.
export const SHUTDOWN_WAIT_MS = 20_000;
