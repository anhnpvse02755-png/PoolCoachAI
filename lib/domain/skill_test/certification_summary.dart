import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/certification.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

typedef CertifiedDrill = ({Drill drill, Certification certification});

/// Các bài đã chứng nhận của một nhóm. [complete]: mọi bài thư viện của
/// nhóm đều đã chứng nhận.
final class CertificationGroup {
  const CertificationGroup({
    required this.cat,
    required this.entries,
    required this.complete,
  });

  final SkillCategory cat;
  final List<CertifiedDrill> entries;
  final bool complete;
}

/// [ready]: cổng đã mở, bấm vào là làm bài kiểm tra được ngay.
typedef ReadyHint = ({Drill drill, int passCount, bool ready});

final class CertificationSummary {
  const CertificationSummary({required this.groups, required this.closest});

  final List<CertificationGroup> groups;

  /// Bài gần được kiểm tra nhất; `null` khi không có.
  final ReadyHint? closest;
}

int _byLevelThenId(Drill a, Drill b) {
  final byLevel = a.level.compareTo(b.level);
  return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
}

CertificationSummary certificationSummary({
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<SkillTest> tests,
}) {
  final certs = certificationsOf(tests);
  final groups = <CertificationGroup>[];
  for (final cat in SkillCategory.values) {
    final inCat = drills.where((d) => d.cat == cat).toList()
      ..sort(_byLevelThenId);
    final entries = <CertifiedDrill>[
      for (final d in inCat)
        if (certs[d.id] != null) (drill: d, certification: certs[d.id]!),
    ];
    if (entries.isEmpty) continue;
    groups.add(CertificationGroup(
      cat: cat,
      entries: entries,
      complete: entries.length == inCat.length,
    ));
  }

  ReadyHint? closest;
  final ordered = [...drills]..sort(_byLevelThenId);
  for (final d in ordered) {
    final gate = skillTestGate(drill: d, drills: drills, logs: logs, tests: tests);
    if (gate is AlreadyCertified || gate is NeedLowerLevel) continue;
    final count = consecutivePassCount(
      d,
      [for (final l in logs) if (l.drillId == d.id) l],
    );
    if (count < 1) continue;
    // Duyệt theo (cấp, id) nên chỉ thay khi nhiều buổi hơn hẳn.
    if (closest == null || count > closest.passCount) {
      closest = (drill: d, passCount: count, ready: gate is SkillTestOpen);
    }
  }
  return CertificationSummary(groups: groups, closest: closest);
}
