import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';
import 'package:poolcoachai/features/rank/presentation/rank_card.dart';
import 'package:poolcoachai/features/rank/presentation/test_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/roadmap_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  final verifiedD = PlayerRank(
    rank: Rank.d,
    source: RankSource.verified,
    buScore: 137,
    testId: 't1',
    warningRank: Rank.g,
    warningTestId: 't2',
    onboardingState: OnboardingState.done,
    updatedAt: testToday,
  );
  final done = BuTest(
    id: 't1',
    startedAt: testToday.subtract(const Duration(days: 4)),
    tableSize: TableSize.nineFootPlus,
    completedAt: testToday.subtract(const Duration(days: 3)),
    examIScore: 60,
    examIIVersion: ExamIIVersion.masters,
    examIIScore: 77,
    totalScore: 137,
    resultRank: Rank.d,
  );
  // Các test dưới đây ghi đè kết quả BU để khỏi dựng ảnh chụp bài thi. (Từng treo vì bài hoàn tất
  // thiếu examIIVersion; nay bài như vậy được coi là không có kết quả, xem test CSDL thật cuối file.)
  final recentBu = buResultGraded(
    completedAt: testToday.subtract(const Duration(days: 3)),
  );
  final cancelled = BuTest(
    id: 't0',
    startedAt: testToday.subtract(const Duration(days: 9)),
    tableSize: TableSize.eightFoot,
    cancelledAt: testToday.subtract(const Duration(days: 9)),
  );

  Future<void> pump(
    WidgetTester tester,
    String location, {
    PlayerRank? rank,
    List<BuTest> tests = const [],
    TestSnapshot? active,
    BuResult? buResult,
    List<DrillLog>? logs,
  }) async {
    final container = testContainer(
      rank: rank,
      tests: tests,
      activeTest: active,
      buResult: buResult,
      logs: logs,
      drills: logs == null ? null : roadmapDrills,
    );
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Hồ sơ: huy hiệu, nhãn nguồn, cảnh báo, lần gần nhất, ngày kiểm tra lại',
    (tester) async {
      await pump(
        tester,
        Routes.profile,
        rank: verifiedD,
        tests: [done, cancelled],
        buResult: recentBu,
      );
      expect(find.text('HẠNG D'), findsOneWidget);
      expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
      expect(find.text(Vi.rankWarning(Rank.g)), findsOneWidget);
      expect(
        find.text(Vi.rankLastTest(done.completedAt!, 137, Rank.d)),
        findsOneWidget,
      );
      final from = DateTime(
        testToday.year,
        testToday.month,
        testToday.day - 3 + 14,
      );
      expect(find.text(Vi.buRetestFrom(from)), findsOneWidget);
      expect(find.text(Vi.rankTakeTest), findsOneWidget);
    },
  );

  testWidgets('thẻ hạng hiện gợi ý kiểm tra lại hạng', (tester) async {
    final unwarned = PlayerRank(
      rank: Rank.d,
      source: RankSource.verified,
      buScore: 137,
      testId: 't1',
      onboardingState: OnboardingState.done,
      updatedAt: testToday,
    );
    await pump(
      tester,
      Routes.rank,
      rank: unwarned,
      tests: [done],
      buResult: buResultGraded(
        completedAt: testToday.subtract(const Duration(days: 30)),
      ),
      logs: decliningLogs(testToday.subtract(const Duration(days: 10))),
    );
    const signal = RankCheckSignal(
      direction: RankCheckDirection.down,
      basis: RankCheckBasis.drills,
      categories: [SkillCategory.aiming, SkillCategory.position],
      rank: Rank.d,
    );
    expect(find.text(Vi.rankCheck(signal)), findsOneWidget);
    expect(find.text(Vi.rankWarning(Rank.g)), findsNothing);
  });

  testWidgets('chưa có tín hiệu: thẻ hạng không hiện gợi ý', (tester) async {
    await pump(
      tester,
      Routes.rank,
      rank: PlayerRank(
        rank: Rank.d,
        source: RankSource.verified,
        buScore: 137,
        testId: 't1',
        onboardingState: OnboardingState.done,
        updatedAt: testToday,
      ),
      tests: [done],
      buResult: recentBu,
    );
    expect(find.textContaining('làm lại bài BU'), findsNothing);
  });

  testWidgets('Hồ sơ: lịch sử có cả lần hoàn tất và lần đã hủy', (
    tester,
  ) async {
    await pump(
      tester,
      Routes.profile,
      rank: verifiedD,
      tests: [done, cancelled],
      buResult: recentBu,
    );
    // Thanh điều hướng bên cũng cuộn được: chỉ đúng danh sách của Hồ sơ.
    await tester.scrollUntilVisible(
      find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.text(Vi.rankHistoryCompleted(done.completedAt!, 137, Rank.d)),
      findsOneWidget,
    );
    expect(
      find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)),
      findsOneWidget,
    );
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
      test: BuTest(
        id: 'ta',
        startedAt: testToday,
        tableSize: TableSize.nineFootPlus,
      ),
      attempts: const {},
    );
    await pump(tester, Routes.profile, rank: verifiedD, active: active);
    await tester.tap(find.text(Vi.rankContinueTest));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen), findsOneWidget);
  });

  testWidgets('ⓘ mở trên navigator gốc: nút Coach nằm sau tấm chắn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640));
    await pump(tester, Routes.profile, rank: verifiedD);
    expect(find.byTooltip(Vi.coachTitle).hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip(Vi.rankInfo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    expect(find.byTooltip(Vi.coachTitle).hitTestable(), findsNothing);
  });

  testWidgets('ⓘ mở câu miễn trừ, bảng quy đổi và nguồn BU', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD);
    await tester.tap(find.byTooltip(Vi.rankInfo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    expect(find.text(Vi.rankTableTitle), findsOneWidget);
    expect(find.text(Vi.rankBandRange(buRankBands.first)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Vi.buSourceLine),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(Vi.buSourceLine), findsOneWidget);
  });

  testWidgets('chưa có hạng: Trang chủ hiện thẻ Xác định hạng của bạn', (
    tester,
  ) async {
    await pump(tester, Routes.home);
    expect(find.text(Vi.homeRankCardTitle), findsOneWidget);
  });

  // Font của app tới sau khung hình đầu. Hàng/cột của thẻ phụ thuộc bề rộng
  // nhãn nút, nên phải quyết định lại khi font tới (giống _MetricGrid).
  testWidgets(
    'font tới sau khung hình đầu: thẻ Xác định hạng chọn lại hàng/cột',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(340, 640);
      addTearDown(tester.view.reset);
      const family = 'FontToiSau';
      final container = testContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: family),
            home: const Scaffold(body: HomeRankHeader()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool inRow() =>
          tester.getTopLeft(find.byType(FilledButton)).dx >
          tester.getTopLeft(find.text(Vi.homeRankCardTitle)).dx + 40;
      // Chưa nạp họ font: chữ vẽ bằng font dự phòng của test, rộng 1 em mỗi chữ.
      expect(inRow(), isFalse, reason: 'font dự phòng rộng: phải xuống cột');

      final roboto = File('test/fixtures/fonts/roboto-regular.ttf');
      expect(roboto.existsSync(), isTrue, reason: 'không thấy ${roboto.path}');
      final bytes = roboto.readAsBytesSync();
      await tester.runAsync(
        () => (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
      );
      await tester.pumpAndSettle();
      expect(inRow(), isTrue, reason: 'Roboto hẹp: phải quay về một hàng');
    },
  );

  // Quy tắc hàng/cột: Row chỉ khi cột chữ rộng ít nhất textScaler.scale(12) * 11
  // (11 ký tự cỡ 12, lớn theo chữ hệ thống). Nhỏ hơn thì chữ bị bóp ra từng từ một dòng, nên xuống Column.
  group('thẻ Xác định hạng chọn hàng/cột theo bề rộng cột chữ', () {
    Future<(Rect, Rect, Rect)> measure(
      WidgetTester tester,
      Size size,
      double scale,
    ) async {
      applyScreen(tester, size, textScale: scale);
      const family = 'RobotoThe';
      final bytes = File('test/fixtures/fonts/roboto-regular.ttf')
          .readAsBytesSync();
      await tester.runAsync(
        () => (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
      );
      final container = testContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: family),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [HomeRankHeader()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (
        tester.getRect(find.byType(PcCard)),
        tester.getRect(find.text(Vi.homeRankCardBody)),
        tester.getRect(find.byType(FilledButton)),
      );
    }

    for (final (size, scale, expectRow) in [
      (const Size(360, 640), 1.0, true),
      (const Size(360, 640), 1.5, false),
      (const Size(320, 640), 1.0, false),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}, chữ x$scale: '
          '${expectRow ? "một hàng" : "xuống cột"}', (tester) async {
        final (card, body, button) = await measure(tester, size, scale);
        final inRow = button.left >= body.right;
        expect(
          inRow,
          expectRow,
          reason: 'card $card body $body button $button',
        );
        // Hàng thì cột chữ hơn mức tối thiểu có biên rõ (>= 15 dp); cột thì
        // chữ chiếm cả bề rộng trong của thẻ.
        final minWidth = scale * 12 * 11;
        if (expectRow) {
          expect(body.width, greaterThanOrEqualTo(minWidth + 15));
        } else {
          expect(body.width, greaterThanOrEqualTo(minWidth));
        }
      });
    }
  });

  testWidgets('có hạng: Trang chủ hiện huy hiệu nhỏ và nhãn nguồn', (
    tester,
  ) async {
    await pump(tester, Routes.home, rank: verifiedD);
    expect(find.text('HẠNG D'), findsOneWidget);
    expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
    expect(find.text(Vi.homeRankCardTitle), findsNothing);
  });

  testWidgets('màn Hạng: hạng đã kiểm chứng thì không có Làm lại bộ câu hỏi', (
    tester,
  ) async {
    await pump(tester, Routes.rank, rank: verifiedD);
    expect(find.text(Vi.rankRetakeQuestionnaire), findsNothing);
    expect(find.text(Vi.rankShowLayouts), findsOneWidget);
  });

  testWidgets('màn Hạng: hạng ước lượng thì làm lại được', (tester) async {
    await pump(
      tester,
      Routes.rank,
      rank: PlayerRank(
        rank: Rank.h,
        source: RankSource.estimated,
        onboardingState: OnboardingState.done,
        updatedAt: testToday,
      ),
    );
    expect(find.text(Vi.rankRetakeQuestionnaire), findsOneWidget);
  });

  testWidgets(
    'Hồ sơ: bài BU hoàn tất thật trên CSDL, không ghi đè kết quả BU, vẫn dựng xong',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.playerRankRows)
          .insert(
            PlayerRankRowsCompanion.insert(
              userId: 'u1',
              onboardingState: 'done',
              updatedAt: testToday,
              rank: const Value('d'),
              source: const Value('verified'),
              buScore: const Value(137),
              testId: const Value('t1'),
            ),
          );
      await db
          .into(db.buTestRows)
          .insert(
            BuTestRowsCompanion.insert(
              id: 't1',
              userId: 'u1',
              startedAt: testToday.subtract(const Duration(days: 4)),
              tableSize: 'nineFootPlus',
              completedAt: Value(testToday.subtract(const Duration(days: 3))),
              examIScore: const Value(60),
              examIIVersion: const Value('masters'),
              examIIScore: const Value(77),
              totalScore: const Value(137),
              resultRank: const Value('d'),
            ),
          );
      final container = dbContainer(db);
      addTearDown(container.dispose);
      final router = createAppRouter(auth: signedInGate());
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: PoolCoachApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go(Routes.profile);
      await tester.pumpAndSettle();
      expect(find.text('HẠNG D'), findsOneWidget);
      expect(
        find.text(Vi.rankLastTest(done.completedAt!, 137, Rank.d)),
        findsOneWidget,
      );
    },
  );
}
