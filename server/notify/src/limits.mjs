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
