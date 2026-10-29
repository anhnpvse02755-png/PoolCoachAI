import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Đúng các đầu vào Trang chủ đưa cho [computeRecommendation]; bộ lập
/// lịch tính gợi ý của ngày khác bằng cùng hàm đó.
final class RecommendationInputs {
  const RecommendationInputs({
    required this.drills,
    required this.logs,
    required this.knowledge,
    required this.timerSessions,
    required this.schedule,
    required this.matches,
    this.latestBu,
  });

  final List<Drill> drills;
  final List<DrillLog> logs;
  final List<KnowledgeArticle> knowledge;
  final List<TimerSession> timerSessions;
  final List<ScheduleSlot> schedule;
  final List<PoolMatch> matches;
  final BuResult? latestBu;

  TodayRecommendation recommendFor(DateTime today) => computeRecommendation(
    drills: drills,
    logs: logs,
    knowledge: knowledge,
    timerSessions: timerSessions,
    schedule: schedule,
    today: today,
    matches: matches,
    latestBu: latestBu,
  );
}

/// Cặp (nhóm, bài) mà người chơi thấy lần cuối, và lúc thấy.
final class SeenRecommendation {
  const SeenRecommendation({
    required this.cat,
    required this.drillId,
    required this.at,
  });

  final SkillCategory cat;
  final String drillId;
  final DateTime at;

  bool sameAs(SkillCategory cat, String drillId) =>
      this.cat == cat && this.drillId == drillId;

  @override
  bool operator ==(Object other) =>
      other is SeenRecommendation &&
      other.cat == cat &&
      other.drillId == drillId &&
      other.at == at;

  @override
  int get hashCode => Object.hash(cat, drillId, at);
}

/// Mọi thứ dịch vụ thông báo cần để lập gợi ý: tài khoản, đầu vào gợi ý và
/// cặp người chơi đã thấy lần cuối ([seen] null: chưa thấy lần nào).
final class RecommendationSource {
  const RecommendationSource({
    required this.userId,
    required this.inputs,
    required this.seen,
  });

  final String userId;
  final RecommendationInputs inputs;
  final SeenRecommendation? seen;
}

/// Khoá của thông báo gợi ý: `năm-tháng-ngày:nhóm:idBài`, không đệm số 0.
/// Id bài là mọi thứ sau dấu `:` thứ hai.
String recommendationKey(DateTime day, SkillCategory cat, String drillId) =>
    '${day.year}-${day.month}-${day.day}:${cat.name}:$drillId';

/// Đọc lại khoá của [recommendationKey]; `null` khi khoá không đúng dạng.
({DateTime day, SkillCategory cat, String drillId})? parseRecommendationKey(
  String key,
) {
  final first = key.indexOf(':');
  if (first < 0) return null;
  final second = key.indexOf(':', first + 1);
  if (second < 0) return null;
  final date = key.substring(0, first).split('-');
  if (date.length != 3) return null;
  final y = int.tryParse(date[0]);
  final m = int.tryParse(date[1]);
  final d = int.tryParse(date[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final catName = key.substring(first + 1, second);
  SkillCategory? cat;
  for (final c in SkillCategory.values) {
    if (c.name == catName) cat = c;
  }
  if (cat == null) return null;
  final drillId = key.substring(second + 1);
  if (drillId.isEmpty) return null;
  return (day: DateTime(y, m, d), cat: cat, drillId: drillId);
}
