import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  final goal = PlayerGoal(goalId: 'g1', kind: GoalKind.lenHang, createdAt: on(10, 1));

  PlayerRank rank(Rank r, {RankSource source = RankSource.estimated}) => PlayerRank(
        rank: r,
        source: source,
        buScore: source == RankSource.verified ? 120 : null,
        testId: source == RankSource.verified ? 't' : null,
        onboardingState: OnboardingState.done,
        updatedAt: on(10, 1),
      );

  Roadmap build({
    PlayerRank? r,
    List<DrillLog> logs = const [],
    List<BuTest> tests = const [],
    BuResult? result,
    PlayerGoal? target,
  }) =>
      buildRoadmap(
        goal: target ?? goal,
        rank: r,
        drills: roadmapDrills,
        logs: logs,
        tests: tests,
        latestResult: result,
        today: roadmapToday,
      );

  BuResult result(int total, Map<String, int> lost) =>
      BuResult(testId: 't', completedAt: on(10, 1), total: total, lost: lost);

  group('khóa', () {
    test('chưa có hạng: một bước Xác định hạng', () {
      final r = build();
      expect(r.blocked, LenHangBlock.noRank);
      expect(r.steps.single.kind, StepKind.xacDinhHang);
      expect(r.steps.single.status, StepStatus.dangLam);
      expect(r.currentStep!.kind, StepKind.xacDinhHang);
    });

    test('hạng A hoặc PRO: không có bước nào', () {
      expect(build(r: rank(Rank.a)).blocked, LenHangBlock.topRank);
      expect(build(r: rank(Rank.a)).steps, isEmpty);
      expect(build(r: rank(Rank.pro, source: RankSource.selfDeclared)).blocked, LenHangBlock.topRank);
    });
  });

  group('có bài BU hoàn chỉnh: theo điểm mất (spec mục 4.1)', () {
    test('E 120 → D cần 5: lấy Điều bi (mất 7) là đủ', () {
      final r = build(
        r: rank(Rank.e, source: RankSource.verified),
        result: result(120, const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1}),
      );
      expect(r.from, Rank.e);
      expect(r.target, Rank.d);
      expect(r.pointsNeeded, 5);
      expect(r.steps.map((s) => s.kind), [StepKind.nhom, StepKind.lamBaiBu]);
      expect(r.steps.first.category, SkillCategory.position);
      final reason = r.steps.first.reason as LostBuPoints;
      expect(reason.points, 7);
      expect(reason.drillIds, ['F3', 'F5']);
    });

    test('D 120 → C cần 20: lấy dần tới khi đủ, có cả bước S8/S9', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(120, const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1}),
      );
      expect(r.pointsNeeded, 20);
      expect(r.steps.map((s) => s.category), [
        SkillCategory.position, // 7
        SkillCategory.safety, // 6 → 13
        SkillCategory.aiming, // 5 → 18
        null, // S8/S9: 3 → 21 ≥ 20
        null, // Làm bài BU
      ]);
      final buLe = r.steps[3];
      expect(buLe.kind, StepKind.buLe);
      expect(buLe.buDrillIds, ['S8', 'S9']);
      expect(buLe.status, StepStatus.dangLam);
      expect(buLe.estimate, isNull);
    });

    test('bằng điểm mất thì nhóm yếu hơn đi trước', () {
      // Ngắm bi đo được 50, Điều bi chưa đo: nhóm đo được, yếu hơn, đi trước (R4).
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20, 'F8': 20}),
        logs: sessions('a1', 4, [on(10, 10), on(10, 11), on(10, 12)]),
      );
      expect(r.pointsNeeded, 3);
      expect(r.steps.first.category, SkillCategory.aiming);
      expect(r.steps.length, 2);
    });

    test('nhóm đã đạt 75 và bài đã đủ 3 buổi đạt: bước xong, bước sau đang làm', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: [
          ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
          ...sessions('a2', 9, [on(10, 10), on(10, 11), on(10, 12)]),
        ],
      );
      expect(r.steps.first.status, StepStatus.xong);
      expect(r.steps.first.drillId, 'a2');
      expect(r.steps.last.kind, StepKind.lamBaiBu);
      expect(r.steps.last.status, StepStatus.dangLam);
      expect(r.currentStep!.kind, StepKind.lamBaiBu);
    });

    test('tụt dưới 75 thì bước mở lại', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: [
          ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
          ...sessions('a2', 9, [on(10, 4), on(10, 5), on(10, 6)]),
          ...sessions('a2', 2, [on(10, 10), on(10, 11), on(10, 12), on(10, 13)]),
        ],
      );
      expect(r.steps.first.status, StepStatus.dangLam);
    });
  });

  group('chưa có bài BU hoàn chỉnh: xếp theo nhóm yếu nhất', () {
    test('nhóm đo được yếu trước, nhóm chưa đo sau theo thứ tự làm quen; nhóm từ 75 bỏ ra', () {
      final r = build(
        r: rank(Rank.h),
        logs: [
          ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
          ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]), // ~65
          ...sessions('s1', 4, [on(10, 10), on(10, 11), on(10, 12)]), // 50
          ...sessions('k1', 9, [on(10, 10), on(10, 11), on(10, 12)]), // 100
        ],
      );
      expect(r.pointsNeeded, isNull);
      expect(r.steps.map((s) => s.category), [
        SkillCategory.safety,
        SkillCategory.aiming,
        SkillCategory.position,
        SkillCategory.breakShot,
        SkillCategory.bank,
        null,
      ]);
      expect(r.steps.first.reason, isA<BelowStrong>());
      expect(r.steps[2].reason, isA<Unmeasured>());
      expect(r.steps.first.status, StepStatus.dangLam);
      expect(r.steps[1].status, StepStatus.chuaToi);
    });
  });

  group('ngày dự kiến (spec mục 4.5)', () {
    test('cộng dồn từ hôm nay; bước làm BU lấy ngày muộn hơn giữa bước trước và mốc 14 ngày', () {
      final logs = [
        ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final tests = [
        BuTest(
          id: 't',
          startedAt: on(10, 14),
          tableSize: TableSize.nineFootPlus,
          completedAt: on(10, 14),
        ),
      ];
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: logs,
        tests: tests,
      );
      final mastery = computePlayerIntelligence(drills: roadmapDrills, logs: logs)
          .categories[SkillCategory.aiming]!
          .mastery;
      final days = daysToStrong(
          mastery,
          categoryPacePerDay(
              cat: SkillCategory.aiming, drills: roadmapDrills, logs: logs, today: roadmapToday))!;
      final expected = DateTime(2026, 10, 15 + days);
      expect(r.steps.first.estimate!.date, expected);
      final retest = DateTime(2026, 10, 28);
      expect(r.steps.last.estimate!.date, expected.isAfter(retest) ? expected : retest);
      expect((r.steps.last.reason as RetestFrom).from, retest);
      expect(r.finish!.date, r.steps.last.estimate!.date);
    });

    test('tốc độ không đo được: bước đó và mọi bước sau đều chưa đủ dữ liệu', () {
      final r = build(
        r: rank(Rank.h),
        logs: sessions('s1', 4, [on(10, 12), on(10, 13), on(10, 14)]),
      );
      expect(r.steps.first.category, SkillCategory.safety);
      expect(r.steps.first.estimate!.date, isNull);
      expect(r.steps.every((s) => s.kind == StepKind.buLe || s.estimate?.date == null), isTrue);
      expect(r.finish!.date, isNull);
    });

    test('chưa từng làm BU: bước làm BU mở ngay', () {
      final r = build(r: rank(Rank.h));
      expect((r.steps.last.reason as RetestFrom).from, isNull);
    });
  });

  test('Lên hạng không bao giờ đạt xong: lên hạng thì đích tự chuyển', () {
    expect(build(r: rank(Rank.h)).achieved, isFalse);
  });

  group('lên nhiều hạng một lúc', () {
    PlayerGoal to(Rank r) =>
        PlayerGoal(goalId: 'g2', kind: GoalKind.lenHang, createdAt: on(10, 1), targetRank: r);

    (StepKind, SkillCategory?, Rank?) shape(RoadmapStep s) =>
        (s.kind, s.category, s.reason is RankMilestone ? (s.reason as RankMilestone).rank : null);

    test('lên 2 hạng có BU: mốc trung gian sau khối bài đủ điểm của mốc đó', () {
      final r = build(
        r: rank(Rank.h, source: RankSource.verified),
        target: to(Rank.f),
        result: result(50, const {'F7': 20, 'F2': 15, 'S5': 12}),
      );
      expect(r.steps.map(shape), [
        (StepKind.nhom, SkillCategory.aiming, null),
        (StepKind.lamBaiBu, null, Rank.g),
        (StepKind.nhom, SkillCategory.position, null),
        (StepKind.nhom, SkillCategory.safety, null),
        (StepKind.lamBaiBu, null, null),
      ]);
      expect([r.target, r.pointsNeeded], [Rank.f, 45]);
      expect(r.from, Rank.h);
    });

    test('lên 2 hạng chưa có BU: các mốc đứng sau bước nhóm, trước bước BU cuối', () {
      final r = build(r: rank(Rank.h), target: to(Rank.e));
      final shapes = r.steps.map(shape).toList();
      expect(shapes.where((x) => x.$3 != null).map((x) => x.$3), [Rank.g, Rank.f]);
      expect(shapes.last, (StepKind.lamBaiBu, null, null));
      expect(shapes[shapes.length - 2].$3, Rank.f);
      expect(shapes[shapes.length - 3].$3, Rank.g);
      expect(shapes.take(shapes.length - 3).every((x) => x.$1 == StepKind.nhom), isTrue);
      expect(r.target, Rank.e);
      expect(r.pointsNeeded, isNull);
    });

    test('mốc mang cổng làm lại BU; có BU thì làm lại, chưa có BU thì làm', () {
      final gate = DateTime(2026, 11, 3);
      final tests = [
        BuTest(
          id: 't1',
          startedAt: DateTime(2026, 10, 20, 8),
          tableSize: TableSize.nineFootPlus,
          completedAt: DateTime(2026, 10, 20, 9),
        ),
      ];
      final withBu = build(
        r: rank(Rank.h, source: RankSource.verified),
        target: to(Rank.f),
        result: result(50, const {'F7': 20}),
        tests: tests,
      );
      final m1 = withBu.steps.firstWhere((s) => s.reason is RankMilestone).reason as RankMilestone;
      expect([m1.rank, m1.retake, m1.from], [Rank.g, true, gate]);
      final noBu = build(r: rank(Rank.h), target: to(Rank.f));
      final m2 = noBu.steps.firstWhere((s) => s.reason is RankMilestone).reason as RankMilestone;
      expect([m2.rank, m2.retake, m2.from], [Rank.g, false, null]);
    });

    test('BU gần nhất đã vượt sàn hạng đích: điểm còn thiếu là 0, không âm', () {
      final r = build(
        r: rank(Rank.h),
        target: to(Rank.f),
        result: result(100, const {'F7': 5}),
      );
      expect(r.target, Rank.f);
      expect(r.pointsNeeded, 0);
      expect(r.steps.map(shape).first, (StepKind.lamBaiBu, null, Rank.g));
      expect(r.steps.last.reason, isA<RetestFrom>());
    });

    test('mốc đã đủ điểm đứng đầu danh sách', () {
      final r = build(
        r: rank(Rank.h, source: RankSource.verified),
        target: to(Rank.f),
        result: result(75, const {'F7': 20, 'F2': 15}),
      );
      expect(r.steps.map(shape).first, (StepKind.lamBaiBu, null, Rank.g));
      expect(r.pointsNeeded, 20);
    });

    test('mốc chưa xếp khi hết bài thì đứng ngay trước bước BU cuối', () {
      final r = build(
        r: rank(Rank.h, source: RankSource.verified),
        target: to(Rank.f),
        result: result(50, const {'F7': 3}),
      );
      expect(r.steps.map(shape), [
        (StepKind.nhom, SkillCategory.aiming, null),
        (StepKind.lamBaiBu, null, Rank.g),
        (StepKind.lamBaiBu, null, null),
      ]);
    });

    test('targetRank null: hành vi cũ, đích là hạng kế tiếp, không mốc', () {
      final r = build(r: rank(Rank.h));
      expect(r.target, Rank.g);
      expect(r.steps.any((s) => s.reason is RankMilestone), isFalse);
    });

    test('đã đạt hoặc vượt hạng đích: quay về hạng kế tiếp, không điểm âm', () {
      final r = build(
        r: rank(Rank.f, source: RankSource.verified),
        target: to(Rank.g),
        result: result(100, const {'F7': 20}),
      );
      expect(r.target, Rank.e);
      expect(r.steps.any((s) => s.reason is RankMilestone), isFalse);
      expect(r.pointsNeeded, buFloor(Rank.e) - 100);
      expect(r.steps, isNotEmpty);
      final same = build(r: rank(Rank.g), target: to(Rank.g));
      expect(same.target, Rank.f);
    });

    test('effectiveTarget và targetRankChoices', () {
      expect(effectiveTarget(to(Rank.f), Rank.h), Rank.f);
      expect(effectiveTarget(to(Rank.g), Rank.g), Rank.f);
      expect(effectiveTarget(goal, Rank.h), Rank.g);
      expect(effectiveTarget(goal, Rank.a), isNull);
      expect(targetRankChoices(Rank.h), [Rank.g, Rank.f, Rank.e, Rank.d, Rank.c, Rank.b, Rank.a]);
      expect(targetRankChoices(Rank.b), [Rank.a]);
      expect(targetRankChoices(Rank.a), isEmpty);
      expect(targetRankChoices(Rank.pro), isEmpty);
    });
  });
}
