import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Những gì dữ liệu tập nói về từng nhóm — dùng chung cho cách suy bước và
/// cách ghi thành tích, để hai nơi không thể hiểu "xong" theo hai kiểu.
final class PracticeFacts {
  PracticeFacts({
    required this.drills,
    required List<DrillLog> logs,
    required DateTime today,
  })  : day = dateOnly(today),
        sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date)),
        intelligence = computePlayerIntelligence(drills: drills, logs: logs) {
    for (final log in sorted) {
      logsByDrill.putIfAbsent(log.drillId, () => <DrillLog>[]).add(log);
    }
  }

  final List<Drill> drills;
  final DateTime day;
  final List<DrillLog> sorted;
  final PlayerIntelligence intelligence;
  final Map<String, List<DrillLog>> logsByDrill = {};
  late final Map<String, Drill> _byId = {for (final d in drills) d.id: d};
  final Map<SkillCategory, double?> _pace = {};

  int? mastery(SkillCategory c) => intelligence.categories[c]!.mastery;
  int sessions(SkillCategory c) => intelligence.categories[c]!.sessionCount;

  bool atLeastStrong(SkillCategory c) =>
      (mastery(c) ?? -1) >= PracticeConstants.strongCutoff;

  List<DrillLog> logsOf(String drillId) => logsByDrill[drillId] ?? const [];

  /// Bài của bước nhóm (R3): bài đầu tiên còn cần tập; đạt hết thì bài cao nhất.
  Drill? stepDrill(SkillCategory c) => pickDrillInCategory(
        cat: c,
        drills: drills,
        logsByDrillOldestFirst: logsByDrill,
        excludeDrillIds: const {},
      );

  bool drillReady(Drill d) => isReadyForLevelUp(d, logsOf(d.id));

  /// Số buổi đạt liên tiếp gần nhất, tối đa [PracticeConstants.readyStreak].
  int passStreak(Drill? d) {
    if (d == null) return 0;
    var n = 0;
    for (final log in logsOf(d.id).reversed) {
      final ratio = drillRatio(d, log);
      if (ratio == null || ratio < 1) break;
      if (++n == PracticeConstants.readyStreak) break;
    }
    return n;
  }

  /// Bước nhóm xong: từ 75 **và** bài của bước đủ điều kiện lên cấp (mục 4.4).
  bool groupDone(SkillCategory c) {
    final d = stepDrill(c);
    return atLeastStrong(c) && d != null && drillReady(d);
  }

  DateTime? lastLogIn(SkillCategory c) {
    DateTime? at;
    for (final log in sorted) {
      if (_byId[log.drillId]?.cat == c) at = log.date;
    }
    return at;
  }

  DateTime? lastLogOf(String drillId) => logsOf(drillId).lastOrNull?.date;

  double? pace(SkillCategory c) => _pace.putIfAbsent(
      c, () => categoryPacePerDay(cat: c, drills: drills, logs: sorted, today: day));

  /// Lý do của bước nhóm khi không có điểm BU để nói.
  StepReason groupReason(SkillCategory c) {
    final m = mastery(c);
    if (m == null) return Unmeasured(sessions(c));
    return m < PracticeConstants.strongCutoff ? BelowStrong(m) : const NeedStreak();
  }

  RoadmapStep groupStep(SkillCategory c, StepReason reason) {
    final d = stepDrill(c);
    return RoadmapStep(
      kind: StepKind.nhom,
      status: groupDone(c) ? StepStatus.xong : StepStatus.chuaToi,
      reason: reason,
      category: c,
      drillId: d?.id,
      mastery: mastery(c),
      passStreak: passStreak(d),
    );
  }

  /// Yếu trước: nhóm đo được xếp theo độ thuần thục tăng dần; nhóm chưa đo
  /// đứng sau, theo [newcomerOrder] (R4).
  int compareWeakness(SkillCategory a, SkillCategory b) {
    final ma = mastery(a);
    final mb = mastery(b);
    if (ma != null && mb != null && ma != mb) return ma.compareTo(mb);
    if (ma != null && mb == null) return -1;
    if (ma == null && mb != null) return 1;
    return newcomerOrder.indexOf(a).compareTo(newcomerOrder.indexOf(b));
  }
}
