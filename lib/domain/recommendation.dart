import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Chọn bài tập nên tập trong một nhóm kỹ năng.
///
/// Duyệt theo cấp tăng dần và chọn bài đầu tiên còn cần tập: chưa từng
/// tập, hoặc lần gần nhất chưa đạt mục tiêu. Nếu đã đạt hết thì trả bài
/// cấp cao nhất để giữ phong độ.
///
/// [excludeDrillIds] là các bài đã tập trong hôm nay — không gợi ý lại
/// đúng bài người chơi vừa làm xong.
Drill? pickDrillInCategory({
  required SkillCategory cat,
  required List<Drill> drills,
  required Map<String, List<DrillLog>> logsByDrillOldestFirst,
  required Set<String> excludeDrillIds,
}) {
  final candidates = drills
      .where((d) => d.cat == cat && !excludeDrillIds.contains(d.id))
      .toList()
    ..sort((a, b) => a.level.compareTo(b.level));

  if (candidates.isEmpty) return null;

  for (final drill in candidates) {
    final logs = logsByDrillOldestFirst[drill.id];
    if (logs == null || logs.isEmpty) return drill;

    final lastRatio = drillRatio(drill, logs.last);
    if (lastRatio == null || lastRatio < 1) return drill;
  }

  return candidates.last;
}
