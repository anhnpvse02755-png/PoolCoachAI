import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/skill_test_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<GoRouter> open(
    WidgetTester tester, {
    List<DrillLog>? logs,
    bool dropHomeException = false,
  }) async {
    final seeded = logs ?? threePasses('d1', before: testToday);
    // Kho đọc buổi tập thẳng từ DB trong giao dịch, nên ghi cả vào DB.
    for (final l in seeded) {
      await db.into(db.drillLogRows).insert(toDrillLogRow(l, userId: 'u1'));
    }
    final container = dbContainer(db, logs: seeded);
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
    // Trang chủ là điểm vào của router và có tràn riêng ở chữ lớn (RankCard);
    // bỏ ngoại lệ đó để phép đo chỉ tính màn Skill Test.
    if (dropHomeException) tester.takeException();
    router.go(Routes.skillTest('d1'));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> start(
    WidgetTester tester, {
    TableSize size = TableSize.nineFootPlus,
  }) async {
    await tapText(tester, Vi.buTableSize(size));
    await tapText(tester, Vi.skillTestStart);
  }

  Future<void> enter(WidgetTester tester, String score, String attempts) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts),
      score,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionAttemptsLabel),
      attempts,
    );
    await tapText(tester, Vi.skillTestSubmit);
  }

  testWidgets('chuẩn bị hiện điều kiện đo: kích thước bàn, các bước, tiêu chí', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(Vi.skillTestTitle('Đường thẳng cơ bản')), findsOneWidget);
    for (final s in TableSize.values) {
      expect(find.text(Vi.buTableSize(s)), findsOneWidget);
    }
    expect(find.text('Bước 1'), findsOneWidget);
    expect(find.text(Vi.skillTestCriterion(testDrills.single)), findsOneWidget);
  });

  // Review Focus 1: sau khi nộp, cổng thành AlreadyCertified mà kết quả vẫn ở lại.
  testWidgets('đạt: chứng nhận kèm ngày, không có cấp tiếp theo; một dòng đủ cột', (
    tester,
  ) async {
    await open(tester);
    await start(tester, size: TableSize.eightFoot);
    await enter(tester, '9', '10');
    expect(
      find.text(Vi.skillTestPassed('Đường thẳng cơ bản', 1)),
      findsOneWidget,
    );
    expect(find.text(Vi.shortDate(testToday)), findsOneWidget);
    expect(find.text(Vi.skillTestNoNextLevel), findsOneWidget);
    expect(
      find.text(
        Vi.skillTestGateLine(AlreadyCertified(testToday), nameOf: (id) => id),
      ),
      findsNothing,
    );
    expect(find.text('Chấm theo tiêu chí: từ 80% số lần thử'), findsOneWidget);
    final r = (await db.select(db.skillTestRows).get()).single;
    expect(
      [
        r.drillId,
        r.drillLevel,
        r.tableSize,
        r.score,
        r.attempts,
        r.passed,
        r.startedAt,
        r.completedAt,
      ],
      ['d1', 1, 'eightFoot', 9.0, 10, true, testToday, testToday],
    );
  });

  testWidgets('trượt: Chưa đạt 7/8, lời khuyên tại bàn và luật làm lại', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    await enter(tester, '7', '10');
    expect(find.text(Vi.skillTestFailed(7, 8)), findsOneWidget);
    expect(find.text(Vi.skillTestFailedAdvice), findsOneWidget);
    expect(find.text(Vi.skillTestRetakeRule), findsOneWidget);
    expect((await db.select(db.skillTestRows).get()).single.passed, isFalse);
  });

  testWidgets('huỷ giữa chừng: về chi tiết bài, dòng huỷ không có kết quả', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts),
      '9',
    );
    await tapText(tester, Vi.skillTestCancel);
    expect(find.byType(DrillDetailScreen), findsOneWidget);
    final r = (await db.select(db.skillTestRows).get()).single;
    expect([r.cancelledAt, r.score, r.passed], [testToday, null, null]);
  });

  testWidgets('huỷ ở bước chuẩn bị: không ghi gì', (tester) async {
    await open(tester);
    await tapText(tester, Vi.cancel);
    expect(find.byType(DrillDetailScreen), findsOneWidget);
    expect(await db.select(db.skillTestRows).get(), isEmpty);
  });

  // Review Focus 2
  testWidgets('số lần đạt lớn hơn số lần thử: báo lỗi, không ghi', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    await enter(tester, '11', '10');
    expect(
      find.text(Vi.skillTestInputError(SkillTestInputError.scoreAboveAttempts)),
      findsOneWidget,
    );
    expect(await db.select(db.skillTestRows).get(), isEmpty);
  });

  testWidgets(
    'mở thẳng đường dẫn khi chưa đủ điều kiện: hiện lý do, nút bắt đầu bị khoá',
    (tester) async {
      await open(tester, logs: const []);
      expect(
        find.text(
          Vi.skillTestGateLine(const NeedStreak(3), nameOf: (id) => id),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, Vi.skillTestStart),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('bài không có trong thư viện: nói thẳng là không tìm thấy', (
    tester,
  ) async {
    final router = await open(tester);
    router.go(Routes.skillTest('khong-co'));
    await tester.pumpAndSettle();
    expect(find.text(Vi.skillTestNotFoundTitle), findsOneWidget);
    expect(find.text(Vi.skillTestStart), findsNothing);
  });

  testWidgets('360×640 chữ lớn: chuẩn bị và nhập kết quả không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    await open(tester, dropHomeException: true);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
    await start(tester);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });
}
