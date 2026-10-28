import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';

import '../../support/roadmap_fixtures.dart';
import '../../support/test_data.dart';

/// AI Home — mục 6.1 của thiết kế.
void main() {
  Future<void> openHome(
    WidgetTester tester, {
    List<Drill>? drills,
    List<KnowledgeArticle>? knowledge,
    List<DrillLog>? logs,
    List<TimerSession>? timerSessions,
    List<ScheduleSlot>? schedule,
    GoalRecord? goal,
    PlayerRank? rank,
    BuResult? buResult,
  }) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer(
      drills: drills,
      knowledge: knowledge,
      logs: logs,
      timerSessions: timerSessions,
      schedule: schedule,
      goal: goal,
      rank: rank,
      buResult: buResult,
    );
    addTearDown(container.dispose);

    // Trang chủ có thêm thẻ hạng ở đầu (spec mục 7.4): màn cao hơn để các
    // thẻ cũ vẫn nằm trong khung, không phải cuộn.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa tập buổi nào thì chuỗi ngày tập là 0, hiện bình thường', (
    tester,
  ) async {
    await openHome(tester);

    expect(find.text('0'), findsOneWidget);
    expect(find.text(Vi.homeStreakUnit), findsOneWidget);
  });

  testWidgets('hiện lịch hôm nay và tổng thời gian tập tự do trong tuần', (
    tester,
  ) async {
    await openHome(
      tester,
      schedule: const [
        ScheduleSlot(
          id: 's1',
          day: 1,
          time: '19:00',
          label: 'Tập điều bi',
          cat: SkillCategory.position,
        ),
      ],
      timerSessions: [
        TimerSession(
          id: 't1',
          date: DateTime(2026, 9, 21, 10),
          durationSec: 1800,
        ),
      ],
    );

    expect(find.text(Vi.homeScheduleTitle), findsOneWidget);
    expect(find.text('Tập điều bi'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text(Vi.homePracticeWeek(1800)), findsOneWidget);
  });

  testWidgets('hiện câu lý do của nhóm được chọn, không nuốt lý do', (
    tester,
  ) async {
    await openHome(tester);

    expect(
      find.text(
        Vi.pickReason(PickReason.newcomer, Vi.skill(SkillCategory.aiming)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('có bài gợi ý thì hiện tên bài và nút mở', (tester) async {
    await openHome(tester);

    expect(find.text(Vi.homeDrillTitle), findsOneWidget);
    expect(find.text('Đường thẳng cơ bản'), findsOneWidget);
    expect(find.text(Vi.homeDrillOpen), findsOneWidget);
  });

  testWidgets('hết bài trong nhóm thì nói hết bài, không mượn bài nhóm khác', (
    tester,
  ) async {
    await openHome(tester, drills: const []);

    expect(find.text(Vi.homeDrillAllDone), findsOneWidget);
    expect(find.text(Vi.homeDrillTitle), findsNothing);
  });

  testWidgets('không có bài đọc thì ẩn hẳn khối bài đọc', (tester) async {
    await openHome(tester, knowledge: const []);

    expect(find.text(Vi.homeArticleTitle), findsNothing);
  });

  testWidgets('bấm bài đọc thì mở đúng màn đọc kiến thức', (tester) async {
    await openHome(tester);

    expect(find.text(Vi.homeArticleTitle), findsOneWidget);
    await tester.tap(find.text('Nguyên lý bi ảo'));
    await tester.pumpAndSettle();

    expect(find.byType(KnowledgeScreen), findsOneWidget);
  });

  testWidgets(
    'có mục tiêu: Trang chủ hiện bước hiện tại, chạm thì mở Lộ trình',
    (tester) async {
      final at = DateTime(2026, 9, 20, 9);
      await openHome(
        tester,
        goal: GoalRecord(
          updatedAt: at,
          goal: PlayerGoal(
            goalId: 'g',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.aiming,
            createdAt: at,
          ),
        ),
      );
      final line = find.text(Vi.homeCurrentStep('Đường thẳng cơ bản'));
      expect(line, findsOneWidget);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(
        find.text('Thuần thục: ${Vi.skill(SkillCategory.aiming)}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('chưa có mục tiêu: Trang chủ không hiện dòng bước hiện tại', (
    tester,
  ) async {
    await openHome(tester);
    expect(find.textContaining('Bước hiện tại'), findsNothing);
  });

  testWidgets('Trang chủ hiện gợi ý kiểm tra lại hạng dù chưa có mục tiêu', (tester) async {
    await openHome(
      tester,
      drills: roadmapDrills,
      logs: decliningLogs(testToday.subtract(const Duration(days: 10))),
      rank: PlayerRank(
        rank: Rank.d,
        source: RankSource.verified,
        buScore: 137,
        testId: 't1',
        onboardingState: OnboardingState.done,
        updatedAt: testToday,
      ),
      buResult: buResultGraded(completedAt: testToday.subtract(const Duration(days: 30))),
    );
    const signal = RankCheckSignal(
      direction: RankCheckDirection.down,
      basis: RankCheckBasis.drills,
      categories: [SkillCategory.aiming, SkillCategory.position],
      rank: Rank.d,
    );
    expect(find.text(Vi.rankCheck(signal)), findsOneWidget);
    expect(find.textContaining('Bước hiện tại'), findsNothing);
  });
}
