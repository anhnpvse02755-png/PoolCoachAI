import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<(GoRouter, ProviderContainer)> pump(WidgetTester tester,
      {bool withGate = false, String? location, Duration? rankLag}) async {
    final auth = FakeAuthRepository.signedIn();
    final container = dbContainer(db, auth: auth, rankLag: rankLag);
    addTearDown(container.dispose);
    final gate = AuthGate(auth);
    addTearDown(gate.dispose);
    // Như PoolCoachApp khi tự dựng router: có người nghe thì cổng mới chạy
    // (Riverpod 3 tạm dừng provider không ai nghe).
    if (withGate) container.listen(onboardingGateProvider, (_, _) {});
    final router = createAppRouter(
        auth: gate, onboarding: withGate ? container.read(onboardingGateProvider) : null);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    if (location != null) {
      router.go(location);
      await tester.pumpAndSettle();
    }
    return (router, container);
  }

  Future<PlayerRankRow?> row() => db.select(db.playerRankRows).getSingleOrNull();

  Future<void> answer(WidgetTester tester, List<String> picks) async {
    await tester.tap(find.text(Vi.onboardingStart));
    await tester.pumpAndSettle();
    for (final pick in picks) {
      await tester.tap(find.text(pick));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.onboardingNext));
      await tester.pumpAndSettle();
    }
  }

  const toH = [
    'Chưa từng chơi', 'Dưới 2 giờ / tuần', '1', '1', 'Đã từng 1–2 lần', 'Chưa từng',
    'Thường không có bi đánh tiếp', 'Thường xuyên bị khó',
  ];

  testWidgets('Để sau ở màn giới thiệu: ghi bỏ qua rồi về Trang chủ', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await tester.tap(find.text(Vi.onboardingLater));
    await tester.pumpAndSettle();
    expect((await row())!.onboardingState, 'skipped');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('trả lời 8 câu, xác nhận gợi ý: hạng ước lượng, lưu đủ câu trả lời', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await answer(tester, toH);
    expect(find.text(Vi.onboardingSuggestTitle), findsOneWidget);
    expect(find.text(Vi.rankDescription(Rank.h)), findsOneWidget);
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    await tester.tap(find.text(Vi.onboardingConfirm));
    await tester.pumpAndSettle();
    final r = toPlayerRank((await row())!);
    expect(r.rank, Rank.h);
    expect(r.source, RankSource.estimated);
    expect(r.answers!.choices, [0, 0, 0, 0, 1, 0, 0, 0]);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Chọn hạng khác: chọn PRO thì thành tự khai', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await answer(tester, toH);
    await tester.tap(find.text(Vi.onboardingChooseOther));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(Vi.rankDescription(Rank.pro)), 200);
    await tester.tap(find.text(Vi.rankDescription(Rank.pro)));
    await tester.pumpAndSettle();
    final r = toPlayerRank((await row())!);
    expect(r.rank, Rank.pro);
    expect(r.source, RankSource.selfDeclared);
  });

  testWidgets('chưa chọn đáp án thì không bấm Tiếp được', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await tester.tap(find.text(Vi.onboardingStart));
    await tester.pumpAndSettle();
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, Vi.onboardingNext));
    expect(next.onPressed, isNull);
  });

  testWidgets('hạng đã kiểm chứng thì không làm lại được bộ câu hỏi', (tester) async {
    await db.into(db.playerRankRows).insert(toPlayerRankRow(
        PlayerRank(
          rank: Rank.d, source: RankSource.verified, buScore: 130, testId: 't1',
          onboardingState: OnboardingState.done, updatedAt: testToday,
        ),
        userId: 'u1'));
    await pump(tester, location: Routes.onboardingRank);
    expect(find.text(Vi.onboardingLocked), findsOneWidget);
    expect(find.text(Vi.onboardingStart), findsNothing);
  });

  group('chuyển tới onboarding sau khi đăng nhập (spec mục 7.1, 8)', () {
    testWidgets('máy chủ báo chưa có hạng: vào bộ câu hỏi', (tester) async {
      final (_, container) = await pump(tester, withGate: true);
      expect(find.byType(HomeScreen), findsOneWidget);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    // Chrome 14/10/2026: bấm Xác nhận mà vẫn đứng ở màn gợi ý — điều hướng về
    // Trang chủ chạy trước khi stream hạng kịp báo dòng mới, cổng còn đòi
    // onboarding nên đẩy ngược về đây.
    testWidgets('bị đưa vào bộ câu hỏi, xác nhận xong thì về Trang chủ', (tester) async {
      final (_, container) = await pump(tester, withGate: true, rankLag: const Duration(milliseconds: 200));
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      await answer(tester, toH);
      await tester.tap(find.text(Vi.onboardingConfirm));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('bị đưa vào bộ câu hỏi, Để sau thì về Trang chủ', (tester) async {
      final (_, container) = await pump(tester, withGate: true, rankLag: const Duration(milliseconds: 200));
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.onboardingLater));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('máy mới mất mạng: không ép onboarding', (tester) async {
      final (_, container) = await pump(tester, withGate: true);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.failed);
      await tester.pumpAndSettle();
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('đã bấm Để sau từ trước: không vào lại', (tester) async {
      await db.into(db.playerRankRows).insert(toPlayerRankRow(
          PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: testToday),
          userId: 'u1'));
      final (_, container) = await pump(tester, withGate: true);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.found);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
