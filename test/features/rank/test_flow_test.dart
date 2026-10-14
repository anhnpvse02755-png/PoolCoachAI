import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';

import '../../support/assessment_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  late AssessmentRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    var n = 0;
    repo = AssessmentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'seed${++n}');
  });
  tearDown(() => db.close());

  Future<GoRouter> open(WidgetTester tester) async {
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
    return router;
  }

  Future<String> examIDone({TableSize size = TableSize.nineFootPlus, bool full = false}) async {
    final id = (await repo.startTest(size) as TestStarted).testId;
    for (final e in examIAttempts(wagonAndTargetMade: full).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    return id;
  }

  testWidgets('xong Đề I: chấm, hiện bản Đề II, Làm Đề II ngay thì vào S1', (tester) async {
    await examIDone();
    await open(tester);
    expect(find.text(Vi.buExamIReadyTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buExamIReadyAction));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buExamIScore(60)), findsOneWidget);
    expect(find.text(Vi.buPlacement(ExamIIVersion.masters)), findsOneWidget);
    await tester.tap(find.text(Vi.buExamIINow));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('S1')), findsOneWidget);
  });

  testWidgets('Để buổi khác: về Hồ sơ; mở lại thì hỏi lại rồi làm tiếp được', (tester) async {
    final id = await examIDone();
    await repo.finishExamI(id);
    final router = await open(tester);
    await tester.tap(find.text(Vi.buExamIILater));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
    expect(find.text(Vi.buExamIINow), findsOneWidget);
  });

  testWidgets('bàn 8 feet, Đề I 100: báo làm bản Masters vì bàn nhỏ', (tester) async {
    final id = await examIDone(size: TableSize.eightFoot, full: true);
    await repo.finishExamI(id);
    await open(tester);
    expect(find.text(Vi.buPlacement(ExamIIVersion.masters)), findsOneWidget);
    expect(find.text(Vi.buPlacementSmallTable), findsOneWidget);
  });

  testWidgets('hoàn tất: điểm từng bài, tổng, mức BU, Fargo và câu lên hạng', (tester) async {
    await repo.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h,
        answers: QuestionnaireAnswers([0, 0, 0, 0, 1, 0, 0, 0]));
    final id = await examIDone();
    await repo.finishExamI(id);
    for (final e in examIIPerfect(ExamIIVersion.masters).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await open(tester);
    expect(find.text(Vi.buFinishTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buFinishAction));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buResultTitle), findsWidgets);
    expect(find.text(Vi.buTotal(137)), findsOneWidget);
    expect(find.text(Vi.buBand(bandForBuScore(137))), findsOneWidget);
    expect(find.text(Vi.buFargo(bandForBuScore(137))), findsOneWidget);
    expect(find.text(Vi.rankOutcome(RankOutcome.promoted, Rank.h, Rank.d)), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Vi.buDrillScoreLine('S10', 5, 5)), 200);
    expect(find.text(Vi.buDrillScoreLine('S10', 5, 5)), findsOneWidget);
  });

  testWidgets('hoàn tất khi chưa đủ 14 ngày: báo ngày được hoàn tất, hạng không đổi', (tester) async {
    final id = await examIDone();
    await repo.finishExamI(id);
    for (final e in examIIPerfect(ExamIIVersion.masters).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'may-khac', userId: 'u1', startedAt: testToday, tableSize: 'nineFootPlus',
        completedAt: Value(testToday.subtract(const Duration(days: 2))),
        totalScore: const Value(80), resultRank: const Value('g')));
    await open(tester);
    await tester.tap(find.text(Vi.buFinishAction));
    await tester.pumpAndSettle();
    final from = DateTime(testToday.year, testToday.month, testToday.day - 2 + 14);
    expect(find.text(Vi.buCompletionTooSoon(from)), findsOneWidget);
    expect(await db.select(db.playerRankRows).getSingleOrNull(), isNull);
  });

  testWidgets('Hủy lần kiểm tra này: xác nhận rồi về Hồ sơ', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts([true]));
    await open(tester);
    await tester.tap(find.byTooltip(Vi.buCancelTest));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buCancelConfirmBody), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Vi.buCancelConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect((await db.select(db.buTestRows).getSingle()).cancelledAt, isNotNull);
  });
}
