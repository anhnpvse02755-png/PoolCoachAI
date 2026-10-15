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
  }) =>
      buildRoadmap(
        goal: goal,
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
}
