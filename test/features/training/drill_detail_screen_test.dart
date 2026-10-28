import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';
import 'package:poolcoachai/features/training/presentation/skill_test_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/skill_test_fixtures.dart';
import '../../support/test_data.dart';

/// Chi tiết một bài tập — mục 6.3 của thiết kế.
void main() {
  Future<void> openDrill(
    WidgetTester tester,
    String drillId, {
    List<DrillLog> logs = const [],
    List<Drill>? drills,
    List<SkillTest> skillTests = const [],
    AsyncValue<List<SkillTest>>? skillTestsAsync,
    bool tall = true,
  }) async {
    if (tall) {
      // Thẻ kiểm tra làm trang dài thêm: cao hơn để các khối cũ vẫn được dựng.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer(
      logs: logs,
      drills: drills,
      skillTests: skillTests,
      skillTestsAsync: skillTestsAsync,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.drill(drillId));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện mục tiêu, đơn vị và các bước của bài', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text('Đánh thẳng bi cái.'), findsOneWidget);
    expect(find.text(Vi.drillUnitLabel('lần trúng / 10')), findsOneWidget);
    expect(find.text(Vi.drillStepsTitle), findsOneWidget);
    expect(find.text('Bước 1'), findsOneWidget);
    expect(find.text('Bước 2'), findsOneWidget);
  });

  testWidgets('hiện cấp của bài', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text(Vi.drillLevel(1)), findsOneWidget);
  });

  testWidgets('hiện tiến độ chuỗi buổi đạt từ kết quả thực tế', (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        for (var day = 1; day <= 3; day++)
          DrillLog(
            id: 'l$day',
            drillId: 'd1',
            date: DateTime(2026, 9, day),
            score: day == 2 ? 5 : 8,
            attempts: 10,
          ),
      ],
    );

    expect(find.text(Vi.drillReadinessTitle), findsOneWidget);
    expect(find.text(Vi.drillReadinessProgress(1)), findsOneWidget);
  });

  testWidgets('hiện khi đã đạt chuỗi yêu cầu, không tự cấp chứng nhận',
      (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        for (var day = 1; day <= 3; day++)
          DrillLog(
            id: 'l$day',
            drillId: 'd1',
            date: DateTime(2026, 9, day),
            score: 8,
            attempts: 10,
          ),
      ],
    );

    expect(find.text(Vi.drillReadinessTitle), findsOneWidget);
    expect(find.text(Vi.drillReadinessProgress(3)), findsOneWidget);
    expect(find.text(Vi.drillReadinessQualified), findsOneWidget);
    expect(find.textContaining('chứng nhận'), findsNothing);
  });

  testWidgets('chưa tập lần nào thì không hiện khối lịch sử', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text(Vi.drillHistoryTitle), findsNothing);
  });

  testWidgets('đã tập thì lịch sử hiện tỉ lệ đạt, không phải điểm thô',
      (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        DrillLog(
          id: 'l1',
          drillId: 'd1',
          date: DateTime(2026, 9, 20),
          score: 9,
          attempts: 10,
        ),
      ],
    );

    expect(find.text(Vi.drillHistoryTitle), findsOneWidget);
    expect(find.text('113%'), findsOneWidget);
    expect(find.text(Vi.shortDate(DateTime(2026, 9, 20))), findsOneWidget);
  });

  testWidgets('buổi thiếu dữ liệu chấm thì nói chưa chấm được', (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        DrillLog(
          id: 'l1',
          drillId: 'd1',
          date: DateTime(2026, 9, 20),
          score: 9,
        ),
      ],
    );

    expect(find.text(Vi.drillRatioUnknown), findsOneWidget);
  });

  testWidgets('bấm bắt đầu tập thì sang màn buổi tập của đúng bài đó',
      (tester) async {
    await openDrill(tester, 'd1');

    await tester.tap(find.text(Vi.drillStartAction));
    await tester.pumpAndSettle();

    expect(find.byType(DrillSessionScreen), findsOneWidget);
    expect(find.text(Vi.sessionTitle('Đường thẳng cơ bản')), findsOneWidget);
  });

  testWidgets('id không tồn tại thì ra trạng thái rỗng, không màn trắng',
      (tester) async {
    await openDrill(tester, 'khong-co-that');

    expect(find.byType(PcEmptyState), findsOneWidget);
    expect(find.text(Vi.notFoundTitle), findsOneWidget);
  });

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.dragUntilVisible(
      f,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  testWidgets('đủ 3 buổi đạt: có nút Làm bài kiểm tra, bấm thì mở màn kiểm tra',
      (tester) async {
    await openDrill(tester, 'd1', logs: threePasses('d1', before: testToday));
    final button = find.widgetWithText(FilledButton, Vi.skillTestOpen);
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(SkillTestScreen), findsOneWidget);
  });

  testWidgets('thiếu buổi đạt: không có nút, nói còn thiếu mấy buổi',
      (tester) async {
    await openDrill(tester, 'd1',
        logs: threePasses('d1', before: testToday).skip(1).toList());
    final reason = find.text(
        Vi.skillTestGateLine(const NeedStreak(1), nameOf: (id) => id));
    await reveal(tester, reason);
    expect(reason, findsOneWidget);
    expect(find.widgetWithText(FilledButton, Vi.skillTestOpen), findsNothing);
  });

  testWidgets('cấp cao hơn: nêu tên bài cấp thấp hơn cần chứng nhận',
      (tester) async {
    const d2 = Drill(
        id: 'd2',
        cat: SkillCategory.aiming,
        name: 'Bi ảo',
        level: 3,
        unit: 'lần trúng / 15',
        passThreshold: 0.6,
        goal: 'g',
        steps: ['Bước 1']);
    await openDrill(tester, 'd2',
        drills: [...testDrills, d2],
        logs: threePasses('d2', before: testToday));
    final reason = find.text(Vi.skillTestGateLine(const NeedLowerLevel(['d1']),
        nameOf: (_) => 'Đường thẳng cơ bản'));
    await reveal(tester, reason);
    expect(reason, findsOneWidget);
  });

  testWidgets(
      'đã chứng nhận, 5 buổi gần nhất đều trượt: ngày chứng nhận và Phong độ gần đây chưa đạt',
      (tester) async {
    final certifiedAt = testToday.subtract(const Duration(days: 6));
    await openDrill(tester, 'd1',
        logs: [
          ...threePasses('d1',
              before: testToday.subtract(const Duration(days: 10))),
          for (var i = 5; i >= 1; i--)
            stLog('d1', 5, testToday.subtract(Duration(days: i))),
        ],
        skillTests: [passedTest('d1', 1, certifiedAt)]);
    final certified = find.text(Vi.skillTestGateLine(
        AlreadyCertified(certifiedAt),
        nameOf: (id) => id));
    await reveal(tester, certified);
    expect(certified, findsOneWidget);
    expect(find.text(Vi.skillTestFormSlipped), findsOneWidget);
  });

  testWidgets('đã chứng nhận, phong độ ổn: không có dòng Phong độ gần đây chưa đạt',
      (tester) async {
    final certifiedAt = testToday.subtract(const Duration(days: 6));
    await openDrill(tester, 'd1',
        logs: threePasses('d1', before: testToday),
        skillTests: [passedTest('d1', 1, certifiedAt)]);
    final certified = find.text(Vi.skillTestGateLine(
        AlreadyCertified(certifiedAt),
        nameOf: (id) => id));
    await reveal(tester, certified);
    expect(certified, findsOneWidget);
    expect(find.text(Vi.skillTestFormSlipped), findsNothing);
  });

  testWidgets('đã chứng nhận: thẻ nêu cỡ bàn, kết quả và tiêu chí của lần đạt',
      (tester) async {
    final certifiedAt = testToday.subtract(const Duration(days: 6));
    await openDrill(tester, 'd1',
        logs: threePasses('d1', before: testToday),
        skillTests: [passedTest('d1', 1, certifiedAt)]);
    final evidence = find.text(Vi.certificationEvidence(
        TableSize.nineFootPlus, 9, 10, 'lần trúng / 10'));
    await reveal(tester, evidence);
    expect(evidence, findsOneWidget);
    expect(find.text(Vi.criterionSnapshot(0.8, null, 'lần trúng / 10')!),
        findsOneWidget);
  });

  testWidgets('chưa chứng nhận dù trượt phong độ: không có dòng phong độ',
      (tester) async {
    await openDrill(tester, 'd1', logs: [
      for (var i = 5; i >= 1; i--)
        stLog('d1', 5, testToday.subtract(Duration(days: i))),
    ]);
    await reveal(tester, find.text(Vi.skillTestCardTitle));
    expect(find.text(Vi.skillTestFormSlipped), findsNothing);
  });

  testWidgets('lỗi tải bài kiểm tra: nói thẳng là chưa tải được, không có nút',
      (tester) async {
    await openDrill(tester, 'd1',
        logs: threePasses('d1', before: testToday),
        skillTestsAsync: const AsyncError<List<SkillTest>>('x', StackTrace.empty));
    final err = find.text(Vi.skillTestDataError);
    await reveal(tester, err);
    expect(err, findsOneWidget);
    expect(find.widgetWithText(FilledButton, Vi.skillTestOpen), findsNothing);
  });

  testWidgets('đang tải bài kiểm tra: thẻ gọn, không có nút', (tester) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer(
      logs: threePasses('d1', before: testToday),
      skillTestsAsync: const AsyncLoading<List<SkillTest>>(),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pump();
    router.go(Routes.drill('d1'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.widgetWithText(FilledButton, Vi.skillTestOpen), findsNothing);
    expect(find.text(Vi.skillTestDataError), findsNothing);
  });

  testWidgets('360×640 chữ lớn: thẻ kiểm tra không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    await openDrill(
      tester,
      'd1',
      logs: threePasses('d1', before: testToday),
      tall: false,
    );
    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, Vi.skillTestOpen);
    await reveal(tester, button);
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });
}
