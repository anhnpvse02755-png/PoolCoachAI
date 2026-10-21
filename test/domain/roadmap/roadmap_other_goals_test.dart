import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  final rank = PlayerRank(
      rank: Rank.h, source: RankSource.estimated,
      onboardingState: OnboardingState.done, updatedAt: on(10, 1));

  Roadmap build(PlayerGoal goal, {List<DrillLog> logs = const [], BuResult? result}) => buildRoadmap(
        goal: goal,
        rank: rank,
        drills: roadmapDrills,
        logs: logs,
        tests: const [],
        latestResult: result,
        today: roadmapToday,
      );

  group('Thuần thục kỹ năng (mục 4.2)', () {
    final goal = PlayerGoal(
        goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: on(10, 1));

    test('một bước mỗi bài theo cấp, cuối là bước nhóm mang ngày dự kiến', () {
      final r = build(goal, logs: sessions('a1', 9, [on(10, 10), on(10, 11), on(10, 12)]));
      expect(r.steps.map((s) => (s.kind, s.drillId)), [
        (StepKind.baiTap, 'a1'),
        (StepKind.baiTap, 'a2'),
        (StepKind.nhom, 'a2'),
      ]);
      expect(r.steps[0].status, StepStatus.xong);
      expect(r.steps[1].status, StepStatus.dangLam);
      expect(r.steps[1].reason, isA<DrillLevel>());
      expect((r.steps[1].reason as DrillLevel).level, 2);
      expect(r.steps[0].estimate, isNull);
      expect(r.steps[2].estimate, isNotNull);
      expect(r.achieved, isFalse);
    });

    test('đủ hai bài và nhóm từ 75: mục tiêu đạt', () {
      final r = build(goal, logs: [
        ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a2', 9, [on(10, 10), on(10, 11), on(10, 12)]),
      ]);
      expect(r.steps.every((s) => s.status == StepStatus.xong), isTrue);
      expect(r.achieved, isTrue);
      expect(r.currentStep, isNull);
      expect(r.finish, isNull);
    });

    test('hai nhóm khác nhau cho hai lộ trình khác nhau', () {
      final safety = build(PlayerGoal(
          goalId: 'g3', kind: GoalKind.thuanThucKyNang, category: SkillCategory.safety, createdAt: on(10, 1)));
      expect(safety.steps.map((s) => s.drillId), ['s1', 's1']);
      expect(build(goal).steps.map((s) => s.drillId), isNot(['s1', 's1']));
    });
  });

  group('Chuẩn bị giải (mục 4.3)', () {
    PlayerGoal tournament(DateTime date) =>
        PlayerGoal(goalId: 'g4', kind: GoalKind.chuanBiGiai, eventDate: date, createdAt: on(10, 1));

    final slowAiming = [
      ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
      ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]),
    ];

    test('bước có ngày sau ngày giải chuyển xuống không kịp; bước chưa đủ dữ liệu vẫn ở lại', () {
      final r = build(tournament(DateTime(2026, 10, 16)), logs: slowAiming);
      expect(r.steps.first.category, SkillCategory.aiming);
      expect(r.steps.first.status, StepStatus.khongKip);
      expect(r.missed.single.category, SkillCategory.aiming);
      expect(r.steps[1].estimate!.date, isNull);
      expect(r.steps[1].status, StepStatus.dangLam);
      expect(r.steps.any((s) => s.kind == StepKind.lamBaiBu), isFalse);
    });

    test('ngày giải xa thì bước đó vẫn kịp', () {
      final r = build(tournament(DateTime(2027, 6, 1)), logs: slowAiming);
      expect(r.steps.first.status, StepStatus.dangLam);
      expect(r.missed, isEmpty);
    });

    test('có bài BU: nhóm dưới 75 xếp theo điểm mất, nhóm không mất điểm theo độ yếu', () {
      final r = build(
        tournament(DateTime(2027, 6, 1)),
        logs: sessions('k1', 9, [on(10, 10), on(10, 11), on(10, 12)]),
        result: BuResult(testId: 't', completedAt: on(10, 1), total: 120, lost: const {'S5': 6, 'F3': 2, 'S9': 3}),
      );
      expect(r.steps.map((s) => s.category), [
        SkillCategory.safety, // 6
        null, // S9: 3
        SkillCategory.position, // 2
        SkillCategory.aiming, // 0, chưa đo — theo thứ tự làm quen
        SkillCategory.breakShot,
        SkillCategory.bank,
      ]);
      expect(r.steps.any((s) => s.category == SkillCategory.kick), isFalse);
    });

    test('mọi nhóm từ 75: không còn bước nào, mục tiêu đạt', () {
      final logs = [
        for (final id in ['a1', 'p1', 'b1', 's1', 'k1', 'n1'])
          ...sessions(id, 9, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final r = build(tournament(DateTime(2027, 6, 1)), logs: logs);
      expect(r.steps, isEmpty);
      expect(r.achieved, isTrue);
    });
  });
}
