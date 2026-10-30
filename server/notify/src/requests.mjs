// Dựng yêu cầu `op:"plan"` từ dữ liệu Directus của một người dùng. Dữ liệu đọc
// một lần mỗi người mỗi chu kỳ và dùng cho cả hai lượt (upcoming và due).

export class RequestError extends Error {
  constructor(code, detail) {
    super(detail ? `${code}: ${detail}` : code);
    this.name = 'RequestError';
    this.code = code;
  }
}

// Người chưa có dòng notification_settings: app mặc định bật cả bốn loại
// (NotificationPrefs) và chưa có "đã xem".
const DEFAULT_SETTINGS = {
  recommendation: true,
  maintenance: true,
  schedule: true,
  streak: true,
  last_seen_cat: null,
  last_seen_drill_id: null,
  last_seen_at: null,
};

export function settingsPrefs(row) {
  return {
    recommendation: row.recommendation,
    maintenance: row.maintenance,
    schedule: row.schedule,
    streak: row.streak,
  };
}

// Directus có thể trả giờ không đuôi múi giờ; helper đòi UTC có đuôi Z.
function utcIso(value, what) {
  if (typeof value !== 'string' || value === '') throw new RequestError('bad_timestamp', what);
  const withZone = /(?:Z|[+-]\d\d:?\d\d)$/i.test(value) ? value : `${value}Z`;
  const t = new Date(withZone);
  if (Number.isNaN(t.getTime())) throw new RequestError('bad_timestamp', what);
  return t.toISOString();
}

export function buildPlanRequest({ userId, nowUtc, tz, mode, settings, deliveries = [], data }) {
  const s = settings ?? DEFAULT_SETTINGS;
  for (const d of deliveries) {
    // Lỗi của nơi gọi (bộ lọc Directus sai): không lặng lẽ lẫn dữ liệu người khác.
    if (d.user != null && d.user !== userId) throw new RequestError('foreign_delivery');
  }
  const complete = s.last_seen_cat != null
    && s.last_seen_drill_id != null
    && s.last_seen_at != null;
  return {
    op: 'plan',
    userId,
    nowUtc,
    tz,
    mode,
    prefs: settingsPrefs(s),
    seen: complete
      ? { cat: s.last_seen_cat, drillId: s.last_seen_drill_id, atUtc: utcIso(s.last_seen_at, 'last_seen_at') }
      : null,
    sentRecommendations: deliveries
      .filter((d) => d.kind === 'recommendation' && d.sent_at != null)
      .map((d) => ({ key: d.key, atUtc: utcIso(d.at, 'at') })),
    data,
  };
}
