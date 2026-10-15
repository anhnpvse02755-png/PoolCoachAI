import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số ngày lịch giữa hai ngày — làm tròn theo giờ để đổi giờ mùa hè (nếu có)
/// không làm lệch một ngày.
int _daysBetween(DateTime from, DateTime to) =>
    (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

/// Tỉ lệ đạt các buổi của nhóm [cat], cũ nhất trước — đúng đầu vào của
/// [categoryMastery]. Buổi không chấm được thì bỏ, như Player Intelligence.
List<double> categoryRatios(
  SkillCategory cat,
  Map<String, Drill> drillById,
  Iterable<DrillLog> logsOldestFirst,
) =>
    [
      for (final log in logsOldestFirst)
        if (drillById[log.drillId] case final drill? when drill.cat == cat)
          ?drillRatio(drill, log),
    ];

/// Độ thuần thục tăng bao nhiêu mỗi ngày trong [PracticeConstants.paceWindowDays]
/// ngày gần nhất (spec mục 4.5).
///
/// Mốc so sánh là độ thuần thục từ các buổi trước đầu cửa sổ. Trước đó chưa đủ
/// buổi để đo thì mốc là ngày đầu tiên trong cửa sổ đo được (R10). Trả `null`
/// khi hôm nay chưa đo được, chưa có mốc, hoặc mốc chính là hôm nay.
double? categoryPacePerDay({
  required SkillCategory cat,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required DateTime today,
}) {
  final byId = {for (final d in drills) d.id: d};
  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
  final day = dateOnly(today);

  final now = categoryMastery(categoryRatios(cat, byId, sorted));
  if (now == null) return null;

  final windowStart =
      DateTime(day.year, day.month, day.day - PracticeConstants.paceWindowDays);
  var base = categoryMastery(
      categoryRatios(cat, byId, sorted.where((l) => l.date.isBefore(windowStart))));
  var baseDay = windowStart;

  if (base == null) {
    for (final log in sorted) {
      if (log.date.isBefore(windowStart) || byId[log.drillId]?.cat != cat) continue;
      final endOfDay = DateTime(log.date.year, log.date.month, log.date.day + 1);
      final m = categoryMastery(
          categoryRatios(cat, byId, sorted.where((l) => l.date.isBefore(endOfDay))));
      if (m != null) {
        base = m;
        baseDay = dateOnly(log.date);
        break;
      }
    }
  }
  if (base == null) return null;

  final days = _daysBetween(baseDay, day);
  if (days < 1) return null;
  return (now - base) / days;
}

/// Số ngày tới độ thuần thục [PracticeConstants.strongCutoff] với tốc độ
/// [pace]. Đã đạt thì 0. Chưa đo được, hoặc tốc độ không dương, thì `null`:
/// màn hình nói "chưa đủ dữ liệu", không đoán (spec mục 4.5).
int? daysToStrong(int? mastery, double? pace) {
  if (mastery == null) return null;
  final missing = PracticeConstants.strongCutoff - mastery;
  if (missing <= 0) return 0;
  if (pace == null || pace <= 0) return null;
  return (missing / pace).ceil();
}
