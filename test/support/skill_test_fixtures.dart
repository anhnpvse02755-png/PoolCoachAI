import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

import 'test_data.dart' show testDrills;

final stToday = DateTime(2026, 10, 28, 10);

Drill stDrill(
  String id,
  SkillCategory cat,
  int level, {
  double? passThreshold = 0.8,
  num? target,
}) =>
    Drill(
      id: id,
      cat: cat,
      name: 'Bai $id',
      level: level,
      unit: target == null ? 'lan / 10' : 'cm',
      goal: 'g',
      steps: const [],
      passThreshold: target == null ? passThreshold : null,
      target: target,
    );

final stDrills = <Drill>[
  stDrill('a1', SkillCategory.aiming, 1),
  stDrill('a3', SkillCategory.aiming, 3),
  stDrill('p2a', SkillCategory.position, 2),
  stDrill('p2b', SkillCategory.position, 2),
  stDrill('p3', SkillCategory.position, 3),
  stDrill('t2', SkillCategory.safety, 2, target: 25),
];

Drill stById(String id) =>
    [...stDrills, ...testDrills].firstWhere((d) => d.id == id);

DrillLog stLog(String drillId, num score, DateTime at, {int? attempts = 10}) =>
    DrillLog(
      id: '$drillId@${at.toIso8601String()}',
      drillId: drillId,
      date: at,
      score: score,
      attempts: attempts,
    );

/// Ba buổi đạt liên tiếp, cũ nhất trước.
List<DrillLog> threePasses(String drillId, {DateTime? before}) {
  final end = before ?? stToday;
  return [
    for (final d in [3, 2, 1])
      stLog(drillId, 9, end.subtract(Duration(days: d))),
  ];
}

SkillTest _finished(
  String prefix,
  String drillId,
  int level,
  DateTime at,
  String? id,
  TableSize tableSize,
  num score,
  bool passed,
) {
  // Ảnh chụp tiêu chí lấy từ bài trong thư viện giả, như lúc hoàn tất thật.
  final drill = stById(drillId);
  return SkillTest(
    id: id ?? '$prefix-$drillId-${at.toIso8601String()}',
    drillId: drillId,
    drillLevel: level,
    tableSize: tableSize,
    startedAt: at.subtract(const Duration(minutes: 20)),
    completedAt: at,
    score: drill.usesAttempts ? score : (passed ? drill.target! : drill.target! - 5),
    attempts: drill.usesAttempts ? 10 : null,
    passed: passed,
    passThreshold: drill.passThreshold,
    target: drill.target,
  );
}

SkillTest passedTest(
  String drillId,
  int level,
  DateTime at, {
  String? id,
  TableSize tableSize = TableSize.nineFootPlus,
}) =>
    _finished('pass', drillId, level, at, id, tableSize, 9, true);

SkillTest failedTest(
  String drillId,
  int level,
  DateTime at, {
  String? id,
  TableSize tableSize = TableSize.nineFootPlus,
}) =>
    _finished('fail', drillId, level, at, id, tableSize, 5, false);

SkillTest cancelledTest(String drillId, int level, DateTime at) => SkillTest(
      id: 'cancel-$drillId-${at.toIso8601String()}',
      drillId: drillId,
      drillLevel: level,
      tableSize: TableSize.nineFootPlus,
      startedAt: at.subtract(const Duration(minutes: 5)),
      cancelledAt: at,
    );
