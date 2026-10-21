import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/test_data.dart';

void main() {
  final at = DateTime(2026, 9, 20, 9);

  Future<void> open(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
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
      expect(
        find.text(Vi.goalBlocked(LenHangBlock.noRank)),
        findsOneWidget,
      );
      expect(find.text(Vi.goalNeedRank), findsOneWidget);
    },
  );

  testWidgets(
    'chọn Thuần thục kỹ năng rồi ghi mục tiêu và hiện lộ trình',
    (tester) async {
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
    },
  );

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

  testWidgets(
    'Lên hạng chưa có BU nói rõ thứ tự nhóm yếu và bước làm BU',
    (tester) async {
      await open(
        tester,
        testContainer(
          goal: goal(
            PlayerGoal(
              goalId: 'g',
              kind: GoalKind.lenHang,
              createdAt: at,
            ),
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
      await tester.scrollUntilVisible(find.text(Vi.stepOpenTest), 200);
      expect(find.text('Làm được ngay.'), findsOneWidget);
    },
  );

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
    );
    expect(
      find.text(Vi.achievement(AchievementKind.chuoiNgay, '7')),
      findsOneWidget,
    );
  });

  testWidgets('Chuẩn bị giải đưa bước không kịp vào mục riêng', (
    tester,
  ) async {
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
    await tester.scrollUntilVisible(
      find.text(Vi.roadmapMissedTitle),
      200,
    );
    expect(find.text(Vi.roadmapMissedTitle), findsOneWidget);
  });
}
