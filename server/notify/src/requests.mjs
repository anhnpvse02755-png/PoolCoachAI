// Dựng yêu cầu `op:"plan"` từ dữ liệu Directus của một người dùng. Dữ liệu đọc
// một lần mỗi người mỗi chu kỳ và dùng cho cả hai lượt (upcoming và due).

export function settingsPrefs(row) {
  return {
    recommendation: row.recommendation,
    maintenance: row.maintenance,
    schedule: row.schedule,
    streak: row.streak,
  };
}

// Directus có thể trả giờ không đuôi múi giờ; helper đòi UTC có đuôi Z.
function utcIso(value) {
  const s = String(value);
  const withZone = /(?:Z|[+-]\d\d:?\d\d)$/i.test(s) ? s : `${s}Z`;
  return new Date(withZone).toISOString();
}

export function buildPlanRequest({ userId, nowUtc, tz, mode, settings, deliveries = [], data }) {
  const complete = settings.last_seen_cat != null
    && settings.last_seen_drill_id != null
    && settings.last_seen_at != null;
  return {
    op: 'plan',
    userId,
    nowUtc,
    tz,
    mode,
    prefs: settingsPrefs(settings),
    seen: complete
      ? { cat: settings.last_seen_cat, drillId: settings.last_seen_drill_id, atUtc: utcIso(settings.last_seen_at) }
      : null,
    sentRecommendations: deliveries
      .filter((d) => d.kind === 'recommendation' && d.sent_at != null)
      .map((d) => ({ key: d.key, atUtc: utcIso(d.at) })),
    data,
  };
}
