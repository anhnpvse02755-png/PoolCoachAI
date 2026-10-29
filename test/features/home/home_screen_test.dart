import 'dart:async';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        FilledButton,
        ListTile,
        ListView,
        MaterialApp,
        Scaffold;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
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
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/features/home/presentation/skill_test_home_line.dart';
import 'package:poolcoachai/features/training/presentation/skill_test_screen.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';

import '../../support/fake_recommendation_seen_store.dart';
import '../../support/layout_sweep.dart';
import '../../support/roadmap_fixtures.dart';
import '../../support/skill_test_fixtures.dart';
import '../../support/test_data.dart';

/// AI Home — mục 6.1 của thiết kế.
void main() {
  Future<ProviderContainer> openHome(
    WidgetTester tester, {
    List<Drill>? drills,
    List<KnowledgeArticle>? knowledge,
    List<DrillLog>? logs,
    List<TimerSession>? timerSessions,
    List<ScheduleSlot>? schedule,
    GoalRecord? goal,
    PlayerRank? rank,
    BuResult? buResult,
    Stream<List<BuTest>>? buTestsStream,
    List<SkillTest>? skillTests,
    FakeRecommendationSeenStore? seenStore,
    Stream<List<DrillLog>>? logsStream,
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
      buTestsStream: buTestsStream,
      skillTests: skillTests,
      seenStore: seenStore,
      logsStream: logsStream,
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
    return container;
  }

  testWidgets('bài BU đọc lỗi: Home vẫn hiện gợi ý, không báo lỗi', (
    tester,
  ) async {
    await openHome(
      tester,
      buTestsStream: Stream.error(StateError('bu offline')),
    );

    expect(find.text(Vi.dataErrorTitle), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(Vi.homeDrillTitle), findsOneWidget);
  });

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

  testWidgets('Trang chủ hiện gợi ý kiểm tra lại hạng dù chưa có mục tiêu', (
    tester,
  ) async {
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
      buResult: buResultGraded(
        completedAt: testToday.subtract(const Duration(days: 30)),
      ),
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

  testWidgets(
    'bài BU hoàn tất thiếu bản Đề II (dữ liệu đồng bộ hỏng): Trang chủ vẫn dựng xong',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.buTestRows)
          .insert(
            BuTestRowsCompanion.insert(
              id: 'hong',
              userId: 'u1',
              startedAt: testToday,
              tableSize: 'nineFootPlus',
              completedAt: Value(testToday.subtract(const Duration(days: 3))),
              totalScore: const Value(80),
              resultRank: const Value('g'),
            ),
          );
      final container = dbContainer(db);
      addTearDown(container.dispose);
      final router = createAppRouter(auth: signedInGate());
      addTearDown(router.dispose);
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
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(Vi.homeStreakUnit), findsOneWidget);
      expect(find.text(Vi.homeDrillTitle), findsOneWidget);
    },
  );

  testWidgets('360×640 chữ lớn: Trang chủ (chưa có hạng) không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer(logs: threePasses('d1', before: testToday));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Vi.homeRankCardTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      '${width.toInt()} px, chữ thường, chưa có hạng: nút một dòng, cột chữ không bị chia đôi',
      (tester) async {
        applyScreen(tester, Size(width, 640));
        final router = createAppRouter(auth: signedInGate());
        addTearDown(router.dispose);
        final container = testContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: PoolCoachApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, Vi.rankDetermine);
        expect(tester.getSize(button).height, lessThan(50));
        final label = tester.getSize(find.text(Vi.rankDetermine));
        expect(label.height, lessThan(24));
        // Cột chữ nhận phần còn lại của hàng, không phải một nửa.
        final column = tester.getSize(find.text(Vi.homeRankCardBody)).width;
        final row = tester.getSize(find.byType(PcCard).first).width;
        expect(column, greaterThan((row - tester.getSize(button).width) * 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('có bài sẵn sàng kiểm tra: một dòng mở thẳng màn kiểm tra', (
    tester,
  ) async {
    await openHome(tester, logs: threePasses('d1', before: testToday));
    final line = find.text(Vi.homeSkillTestReady('Đường thẳng cơ bản', 0));
    await tester.dragUntilVisible(
      line,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(find.byType(SkillTestScreen), findsOneWidget);
  });

  Future<void> pumpLine(WidgetTester tester, ProviderContainer c) async {
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SkillTestHomeLine())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('đã chứng nhận: không còn dòng sẵn sàng kiểm tra', (
    tester,
  ) async {
    await pumpLine(
      tester,
      testContainer(
        logs: threePasses('d1', before: testToday),
        skillTests: [passedTest('d1', 1, testToday)],
      ),
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('nhiều bài sẵn sàng: nêu bài cấp thấp nhất và số bài còn lại', (
    tester,
  ) async {
    const d7 = Drill(
      id: 'd7',
      cat: SkillCategory.safety,
      name: 'Đẩy sát băng',
      level: 2,
      unit: 'lần / 10',
      passThreshold: 0.7,
      goal: 'g',
      steps: [],
    );
    await pumpLine(
      tester,
      testContainer(
        drills: [...testDrills, d7],
        logs: [
          ...threePasses('d1', before: testToday),
          ...threePasses('d7', before: testToday),
        ],
      ),
    );
    expect(
      find.text(Vi.homeSkillTestReady('Đường thẳng cơ bản', 1)),
      findsOneWidget,
    );
  });

  testWidgets('đọc lỗi: nói thẳng là chưa tải được, không im lặng', (
    tester,
  ) async {
    await pumpLine(
      tester,
      testContainer(
        skillTestsAsync: AsyncError<List<SkillTest>>(
          StateError('x'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text(Vi.skillTestDataError), findsOneWidget);
  });

  testWidgets('đang tải: không hiện dòng nào', (tester) async {
    final c = testContainer(
      skillTestsAsync: const AsyncLoading<List<SkillTest>>(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SkillTestHomeLine())),
      ),
    );
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    expect(find.text(Vi.skillTestDataError), findsNothing);
  });
  group('ghi cặp gợi ý đã thấy', () {
    const bankDrill = Drill(
      id: 'd8',
      cat: SkillCategory.bank,
      name: 'Cân bi một băng',
      level: 4,
      unit: 'lần trúng / 10',
      passThreshold: 0.5,
      goal: 'Mục tiêu.',
      steps: ['Bước 1'],
    );
    final twoDrills = [...testDrills, bankDrill];

    testWidgets('Trang chủ hiện bài gợi ý: ghi (nhóm, bài) đã thấy cho u1', (
      tester,
    ) async {
      final store = FakeRecommendationSeenStore();
      final container = await openHome(tester, seenStore: store);

      final rec = container.read(todayRecommendationProvider).value!;
      expect(rec.drill, isNotNull);
      expect(store.saved['u1']!.sameAs(rec.cat, rec.drill!.id), isTrue);
      expect(store.saved['u1']!.at, testToday);
    });

    testWidgets(
      'đang ở tab khác: gợi ý đổi không được ghi; quay lại Trang chủ thì ghi',
      (tester) async {
        final store = FakeRecommendationSeenStore();
        final logs = StreamController<List<DrillLog>>.broadcast();
        addTearDown(logs.close);
        final container = await openHome(
          tester,
          drills: twoDrills,
          seenStore: store,
          logsStream: () async* {
            yield const <DrillLog>[];
            yield* logs.stream;
          }(),
        );
        final first = store.saved['u1']!;
        expect(first.drillId, 'd1');

        await tester.tap(find.text(Vi.tabTraining));
        await tester.pumpAndSettle();
        logs.add([
          for (var i = 0; i < 3; i++)
            DrillLog(
              id: 'kem-$i',
              drillId: 'd8',
              date: testToday.subtract(Duration(days: 3 - i)),
              score: 1,
              attempts: 10,
            ),
        ]);
        await tester.pumpAndSettle();
        final changed = container.read(todayRecommendationProvider).value!;
        expect(changed.drill!.id, 'd8');
        expect(store.saved['u1'], first);

        await tester.tap(find.text(Vi.tabHome));
        await tester.pumpAndSettle();
        expect(store.saved['u1']!.sameAs(changed.cat, 'd8'), isTrue);
      },
    );

    // Riverpod tạm dừng tab ẩn nên dữ liệu đổi không dựng lại nó; nhưng thứ
    // khác (xoay máy, bàn phím: chỗ nút Coach đổi) vẫn dựng lại được. Lúc đó
    // gợi ý mới nhất hiện ra trong build mà người chơi không thấy: không được
    // ghi.
    testWidgets('tab ẩn dựng lại vì đổi khổ màn: gợi ý mới không được ghi', (
      tester,
    ) async {
      final store = FakeRecommendationSeenStore();
      final logs = StreamController<List<DrillLog>>.broadcast();
      addTearDown(logs.close);
      final container = await openHome(
        tester,
        drills: twoDrills,
        seenStore: store,
        logsStream: () async* {
          yield const <DrillLog>[];
          yield* logs.stream;
        }(),
      );
      final first = store.saved['u1']!;

      await tester.tap(find.text(Vi.tabTraining));
      await tester.pumpAndSettle();
      logs.add([
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: 'kem-$i',
            drillId: 'd8',
            date: testToday.subtract(Duration(days: 3 - i)),
            score: 1,
            attempts: 10,
          ),
      ]);
      await tester.pumpAndSettle();
      expect(container.read(todayRecommendationProvider).value!.drill!.id, 'd8');

      // Khổ điện thoại: shell có nút Coach nổi, Trang chủ (ẩn) dựng lại.
      tester.view.physicalSize = const Size(400, 1000);
      await tester.pumpAndSettle();
      expect(store.saved['u1'], first);
    });

    testWidgets('không có bài gợi ý: không ghi', (tester) async {
      final store = FakeRecommendationSeenStore();
      await openHome(tester, drills: const [], seenStore: store);

      expect(store.saved, isEmpty);
    });
  });
}
