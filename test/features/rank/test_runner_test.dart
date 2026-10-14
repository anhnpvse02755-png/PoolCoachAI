import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';

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

  Future<void> open(WidgetTester tester) async {
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
  }

  Future<List<bool>> f1Shots() async {
    final row = await (db.select(db.buDrillResultRows)..where((r) => r.drillId.equals('F1')))
        .getSingleOrNull();
    if (row == null) return [];
    return (DrillAttempts.fromJson(_decode(row.attempts)) as ShotAttempts).shots;
  }

  testWidgets('chưa có lần nào: chọn bàn rồi bắt đầu, vào F1 cú 1/10', (tester) async {
    await open(tester);
    expect(find.text(Vi.buPrepTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buTableSize(TableSize.eightFoot)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.buStart));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F1')), findsOneWidget);
    expect(find.text(Vi.buAttemptLabel(drillFor('F1', null), 0)), findsOneWidget);
    final test = await db.select(db.buTestRows).getSingle();
    expect(test.tableSize, 'eightFoot');
  });

  testWidgets('chưa đủ 14 ngày: nút bắt đầu khoá và báo ngày', (tester) async {
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'cu', userId: 'u1', startedAt: testToday, tableSize: 'nineFootPlus',
        completedAt: Value(testToday.subtract(const Duration(days: 3))),
        totalScore: const Value(80), resultRank: const Value('g')));
    await open(tester);
    final from = DateTime(testToday.year, testToday.month, testToday.day - 3 + 14);
    expect(find.text(Vi.buRetestFrom(from)), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, Vi.buStart)).onPressed, isNull);
  });

  testWidgets('Vào/Trượt ghi ngay xuống máy, thang tự chuyển vị trí', (tester) async {
    await repo.startTest(TableSize.nineFootPlus);
    await open(tester);
    await tester.tap(find.text('Vào'));
    await tester.pumpAndSettle();
    expect(await f1Shots(), [true]);
    expect(find.text(Vi.buLadderPosition(5)), findsOneWidget);
    expect(tester.widget<BuLayoutView>(find.byType(BuLayoutView)).highlightPosition, 5);
    await tester.tap(find.text('Trượt'));
    await tester.pumpAndSettle();
    expect(await f1Shots(), [true, false]);
    expect(find.text(Vi.buLadderPosition(4)), findsOneWidget);
  });

  testWidgets('mở lại màn làm bài thì tiếp đúng cú 4/10, tô vị trí 5', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts([true, false, true]));
    await open(tester);
    expect(find.text(Vi.buAttemptLabel(drillFor('F1', null), 3)), findsOneWidget);
    expect(find.text(Vi.buLadderPosition(5)), findsOneWidget);
    expect(tester.widget<BuLayoutView>(find.byType(BuLayoutView)).highlightPosition, 5);
  });

  testWidgets('Hoàn tác bỏ cú vừa nhập; F1 xong thì sang F2, hoàn tác lùi về F1', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts(List.filled(7, true)));
    await open(tester);
    await tester.tap(find.text('Vào'));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F2')), findsOneWidget, reason: '8 cú vào liền: F1 đã chắc 10');
    await tester.tap(find.text(Vi.buUndo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F1')), findsOneWidget);
    expect(await f1Shots(), List.filled(7, true));
  });

  testWidgets('Đề II: bộ đếm số bi của S1 dừng ở tối đa, lượt 1 trọn điểm thì sang S2', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    for (final e in examIAttempts(wagonAndTargetMade: false).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await repo.finishExamI(id);
    await repo.recordAttempts(id, 'S1', CountAttempts(const [])); // đã bắt đầu Đề II
    await open(tester);
    expect(find.text(Vi.buDrillTitle('S1')), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byTooltip(Vi.buCountMore));
      await tester.pump();
    }
    expect(find.text(Vi.buCountOf(7, 7)), findsOneWidget);
    await tester.tap(find.text(Vi.buCountSubmit));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('S2')), findsOneWidget);
  });

  testWidgets('bàn mặc định là bàn 9 feet chuẩn thi đấu (D5)', (tester) async {
    await open(tester);
    await tester.tap(find.text(Vi.buStart));
    await tester.pumpAndSettle();
    final test = await db.select(db.buTestRows).getSingle();
    expect(test.tableSize, 'nineFootPlus');
  });
}

Object? _decode(String s) => jsonDecode(s);
