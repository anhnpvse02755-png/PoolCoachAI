import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';
import 'package:poolcoachai/features/rank/presentation/test_screen.dart';

import '../../support/test_data.dart';

void main() {
  final verifiedD = PlayerRank(
    rank: Rank.d, source: RankSource.verified, buScore: 137, testId: 't1',
    warningRank: Rank.g, warningTestId: 't2',
    onboardingState: OnboardingState.done, updatedAt: testToday,
  );
  final done = BuTest(
    id: 't1', startedAt: testToday.subtract(const Duration(days: 4)),
    tableSize: TableSize.nineFootPlus,
    completedAt: testToday.subtract(const Duration(days: 3)),
    examIScore: 60, examIIVersion: ExamIIVersion.masters, examIIScore: 77,
    totalScore: 137, resultRank: Rank.d,
  );
  final cancelled = BuTest(
    id: 't0', startedAt: testToday.subtract(const Duration(days: 9)),
    tableSize: TableSize.eightFoot, cancelledAt: testToday.subtract(const Duration(days: 9)),
  );

  Future<void> pump(WidgetTester tester, String location,
      {PlayerRank? rank, List<BuTest> tests = const [], TestSnapshot? active}) async {
    final container = testContainer(rank: rank, tests: tests, activeTest: active);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('Hồ sơ: huy hiệu, nhãn nguồn, cảnh báo, lần gần nhất, ngày kiểm tra lại', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD, tests: [done, cancelled]);
    expect(find.text('HẠNG D'), findsOneWidget);
    expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
    expect(find.text(Vi.rankWarning(Rank.g)), findsOneWidget);
    expect(find.text(Vi.rankLastTest(done.completedAt!, 137, Rank.d)), findsOneWidget);
    final from = DateTime(testToday.year, testToday.month, testToday.day - 3 + 14);
    expect(find.text(Vi.buRetestFrom(from)), findsOneWidget);
    expect(find.text(Vi.rankTakeTest), findsOneWidget);
  });

  testWidgets('Hồ sơ: lịch sử có cả lần hoàn tất và lần đã hủy', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD, tests: [done, cancelled]);
    await tester.scrollUntilVisible(find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)), 200);
    expect(find.text(Vi.rankHistoryCompleted(done.completedAt!, 137, Rank.d)), findsOneWidget);
    expect(find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)), findsOneWidget);
  });

  testWidgets('chưa có hạng: Xác định hạng mở bộ câu hỏi', (tester) async {
    await pump(tester, Routes.profile);
    expect(find.text(Vi.rankNone), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Vi.rankDetermine));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('có lần làm dở: Làm tiếp mở màn làm bài', (tester) async {
    final active = TestSnapshot(
      test: BuTest(id: 'ta', startedAt: testToday, tableSize: TableSize.nineFootPlus),
      attempts: const {},
    );
    await pump(tester, Routes.profile, rank: verifiedD, active: active);
    await tester.tap(find.text(Vi.rankContinueTest));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen), findsOneWidget);
  });

  testWidgets('ⓘ mở câu miễn trừ, bảng quy đổi và nguồn BU', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD);
    await tester.tap(find.byTooltip(Vi.rankInfo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    expect(find.text(Vi.rankTableTitle), findsOneWidget);
    expect(find.text(Vi.rankBandRange(buRankBands.first)), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Vi.buSourceLine), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(Vi.buSourceLine), findsOneWidget);
  });

  testWidgets('chưa có hạng: Trang chủ hiện thẻ Xác định hạng của bạn', (tester) async {
    await pump(tester, Routes.home);
    expect(find.text(Vi.homeRankCardTitle), findsOneWidget);
  });

  testWidgets('có hạng: Trang chủ hiện huy hiệu nhỏ và nhãn nguồn', (tester) async {
    await pump(tester, Routes.home, rank: verifiedD);
    expect(find.text('HẠNG D'), findsOneWidget);
    expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
    expect(find.text(Vi.homeRankCardTitle), findsNothing);
  });

  testWidgets('màn Hạng: hạng đã kiểm chứng thì không có Làm lại bộ câu hỏi', (tester) async {
    await pump(tester, Routes.rank, rank: verifiedD);
    expect(find.text(Vi.rankRetakeQuestionnaire), findsNothing);
    expect(find.text(Vi.rankShowLayouts), findsOneWidget);
  });

  testWidgets('màn Hạng: hạng ước lượng thì làm lại được', (tester) async {
    await pump(tester, Routes.rank, rank: PlayerRank(
      rank: Rank.h, source: RankSource.estimated,
      onboardingState: OnboardingState.done, updatedAt: testToday,
    ));
    expect(find.text(Vi.rankRetakeQuestionnaire), findsOneWidget);
  });
}
