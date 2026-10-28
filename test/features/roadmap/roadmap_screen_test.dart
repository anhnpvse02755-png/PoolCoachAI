import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/roadmap/presentation/roadmap_screen.dart';

import '../../support/test_data.dart';

void main() {
  // Danh sách của màn Lộ trình. Từ 600 dp thanh điều hướng bên cũng cuộn
  // được, nên phải chỉ đúng danh sách cần cuộn.
  final roadmapList = find
      .descendant(
        of: find.byType(RoadmapScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  final at = DateTime(2026, 9, 20, 9);

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    router.go(Routes.roadmap);
    await tester.pumpAndSettle();
  }

  GoalRecord goal(PlayerGoal playerGoal) =>
      GoalRecord(updatedAt: at, goal: playerGoal);

  testWidgets(
    'chưa có mục tiêu, chưa có hạng: Lên hạng bị khóa kèm nút Xác định hạng',
    (tester) async {
      await open(tester, testContainer());
      expect(find.text(Vi.goalPickTitle), findsOneWidget);
      expect(find.text(Vi.goalBlocked(LenHangBlock.noRank)), findsOneWidget);
      expect(find.text(Vi.goalNeedRank), findsOneWidget);
    },
  );

  testWidgets('chọn Thuần thục kỹ năng rồi ghi mục tiêu và hiện lộ trình', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await open(tester, dbContainer(db));
    await tester.tap(find.text(Vi.goalKind(GoalKind.thuanThucKyNang)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.pumpAndSettle();
    expect(
      find.text('Thuần thục: ${Vi.skill(SkillCategory.aiming)}'),
      findsOneWidget,
    );
    expect(find.text(Vi.stepStatus(StepStatus.dangLam)), findsWidgets);
    expect(
      (await db.select(db.playerGoalRows).getSingle()).kind,
      GoalKind.thuanThucKyNang.name,
    );
  });

  Future<void> seedRankH(AppDatabase db) => db.into(db.playerRankRows).insert(
        toPlayerRankRow(
          PlayerRank(
            rank: Rank.h,
            source: RankSource.estimated,
            onboardingState: OnboardingState.done,
            updatedAt: testToday,
          ),
          userId: 'u1',
        ),
      );

  testWidgets('chọn Lên hạng rồi chọn hạng F: lưu hạng đích F', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRankH(db);
    await open(tester, dbContainer(db));
    await tester.tap(find.text(Vi.goalKind(GoalKind.lenHang)));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalTargetRankTitle), findsOneWidget);
    expect(find.byKey(const Key('goal-target-a')), findsOneWidget);
    expect(find.byKey(const Key('goal-target-h')), findsNothing);
    await tester.tap(find.byKey(const Key('goal-target-f')));
    await tester.pumpAndSettle();
    expect((await db.select(db.playerGoalRows).get()).single.targetRank, 'f');
    expect(find.text('Lên hạng: H → F'), findsOneWidget);
  });

  testWidgets('chọn hạng kế tiếp thì lưu hạng đích rỗng', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRankH(db);
    await open(tester, dbContainer(db));
    await tester.tap(find.text(Vi.goalKind(GoalKind.lenHang)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-target-g')));
    await tester.pumpAndSettle();
    final row = (await db.select(db.playerGoalRows).get()).single;
    expect(row.kind, GoalKind.lenHang.name);
    expect(row.targetRank, isNull);
    expect(find.text('Lên hạng: H → G'), findsOneWidget);
  });

  testWidgets('mục tiêu lên 2 hạng: màn lộ trình vẽ bước mốc hạng không lỗi', (tester) async {
    await open(
      tester,
      testContainer(
        goal: goal(PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at, targetRank: Rank.f)),
        rank: PlayerRank(
          rank: Rank.h,
          source: RankSource.estimated,
          onboardingState: OnboardingState.done,
          updatedAt: at,
        ),
      ),
    );
    expect(find.text('Lên hạng: H → F'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Làm bài BU — mốc hạng G'),
      200,
      scrollable: roadmapList,
    );
    expect(find.text('Đạt ${buFloor(Rank.g)} điểm BU là lên hạng G.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tập ngay mở buổi tập của bài trong bước', (tester) async {
    await open(
      tester,
      testContainer(
        goal: goal(
          PlayerGoal(
            goalId: 'g',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.aiming,
            createdAt: at,
          ),
        ),
      ),
    );
    await tester.tap(find.text(Vi.stepTrain).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(Vi.sessionTitle('')), findsOneWidget);
  });

  testWidgets('Lên hạng chưa có BU nói rõ thứ tự nhóm yếu và bước làm BU', (
    tester,
  ) async {
    await open(
      tester,
      testContainer(
        goal: goal(
          PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at),
        ),
        rank: PlayerRank(
          rank: Rank.h,
          source: RankSource.estimated,
          onboardingState: OnboardingState.done,
          updatedAt: at,
        ),
      ),
    );
    expect(find.text('Lên hạng: H → G'), findsOneWidget);
    expect(
      find.text('Chưa có bài BU hoàn chỉnh: xếp bước theo nhóm yếu nhất.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text(Vi.stepOpenTest),
      200,
      scrollable: roadmapList,
    );
    expect(find.text('Làm được ngay.'), findsOneWidget);
  });

  testWidgets('Đổi mục tiêu rồi giữ mục tiêu cũ thì quay về lộ trình', (
    tester,
  ) async {
    await open(
      tester,
      testContainer(
        goal: goal(
          PlayerGoal(
            goalId: 'g',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.aiming,
            createdAt: at,
          ),
        ),
      ),
    );
    await tester.tap(find.text(Vi.goalChange));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalPickTitle), findsOneWidget);
    await tester.tap(find.text(Vi.goalCancelChange));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalPickTitle), findsNothing);
  });

  testWidgets('thành tích hiện ngày; nếu chưa có thì hiện trạng thái rỗng', (
    tester,
  ) async {
    await open(
      tester,
      testContainer(
        goal: goal(
          PlayerGoal(
            goalId: 'g',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.kick,
            createdAt: at,
          ),
        ),
        achievements: [
          Achievement(
            kind: AchievementKind.chuoiNgay,
            refId: '7',
            achievedAt: at,
          ),
        ],
      ),
    );
    await tester.scrollUntilVisible(
      find.text(Vi.achievement(AchievementKind.chuoiNgay, '7')),
      200,
      scrollable: roadmapList,
    );
    expect(
      find.text(Vi.achievement(AchievementKind.chuoiNgay, '7')),
      findsOneWidget,
    );
  });

  testWidgets('Chuẩn bị giải đưa bước không kịp vào mục riêng', (tester) async {
    final logs = <DrillLog>[
      for (final (index, date) in [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
        DateTime(2026, 8, 3),
      ].indexed)
        DrillLog(
          id: 'o$index',
          drillId: 'd1',
          date: date,
          score: 4,
          attempts: 10,
        ),
      for (final (index, date) in [
        DateTime(2026, 9, 17),
        DateTime(2026, 9, 18),
        DateTime(2026, 9, 19),
      ].indexed)
        DrillLog(
          id: 'n$index',
          drillId: 'd1',
          date: date,
          score: 6,
          attempts: 10,
        ),
    ];
    await open(
      tester,
      testContainer(
        goal: goal(
          PlayerGoal(
            goalId: 'g',
            kind: GoalKind.chuanBiGiai,
            eventDate: DateTime(2026, 9, 23),
            createdAt: at,
          ),
        ),
        logs: logs,
      ),
    );
    // Chưa có trận nào có ghi cú: bước đầu là Đấu tập, nút mở Thi đấu.
    expect(find.text(Vi.stepRecordMatch), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Vi.roadmapMissedTitle),
      200,
      scrollable: roadmapList,
    );
    expect(find.text(Vi.roadmapMissedTitle), findsOneWidget);
  });
}
