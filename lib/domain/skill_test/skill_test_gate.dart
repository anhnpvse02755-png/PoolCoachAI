import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_test/certification.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

/// Kết quả cổng mở Skill Test của một bài.
sealed class SkillTestGate {
  const SkillTestGate();
}

final class SkillTestOpen extends SkillTestGate {
  const SkillTestOpen();
}

final class AlreadyCertified extends SkillTestGate {
  const AlreadyCertified(this.at);
  final DateTime at;
}

final class NeedLowerLevel extends SkillTestGate {
  const NeedLowerLevel(this.drillIds);
  final List<String> drillIds;
}

final class NeedStreak extends SkillTestGate {
  const NeedStreak(this.missing);
  final int missing;
}

final class NeedPracticeAfterFail extends SkillTestGate {
  const NeedPracticeAfterFail(this.failedAt);
  final DateTime failedAt;
}

/// Cổng mở bài kiểm tra, xét theo thứ tự: đã chứng nhận, cổng cấp, chuỗi
/// buổi đạt, làm lại sau khi trượt. [logs] có thể gồm mọi bài.
SkillTestGate skillTestGate({
  required Drill drill,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<SkillTest> tests,
}) {
  final certs = certificationsOf(tests);
  final own = certs[drill.id];
  if (own != null) return AlreadyCertified(own.certifiedAt);

  final lower = drills
      .where((d) =>
          d.cat == drill.cat &&
          d.level < drill.level &&
          !certs.containsKey(d.id))
      .toList()
    ..sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });
  if (lower.isNotEmpty) return NeedLowerLevel([for (final d in lower) d.id]);

  final own0 = logs.where((l) => l.drillId == drill.id).toList();
  final streak = consecutivePassCount(drill, own0);
  if (streak < PracticeConstants.readyStreak) {
    return NeedStreak(PracticeConstants.readyStreak - streak);
  }

  DateTime? lastFail;
  for (final t in tests) {
    if (t.drillId != drill.id || !t.failed) continue;
    final at = t.completedAt!;
    if (lastFail == null || at.isAfter(lastFail)) lastFail = at;
  }
  if (lastFail != null) {
    final since = own0.where((l) => l.date.isAfter(lastFail!)).length;
    if (since < SkillTestConstants.retakeSessions) {
      return NeedPracticeAfterFail(lastFail);
    }
  }
  return const SkillTestOpen();
}

/// Mã các bài đang mở kiểm tra, xếp theo (cấp, id).
List<String> testableDrillIds({
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<SkillTest> tests,
}) {
  final open = [
    for (final d in drills)
      if (skillTestGate(drill: d, drills: drills, logs: logs, tests: tests)
          is SkillTestOpen)
        d,
  ]..sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });
  return [for (final d in open) d.id];
}
