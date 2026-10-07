import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_setup_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/test_data.dart';

/// Màn nhập bàn (spec mục 6) và việc chuyển qua lại với màn từng bước.
void main() {
  Future<void> open(WidgetTester tester, {SetupDraft draft = const SetupDraft()}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: PlannerScreen(initialDraft: draft),
    ));
    await tester.pumpAndSettle();
  }

  Offset onTable(WidgetTester tester, Vec2 p) {
    final box = find.byKey(PlannerSetupView.tableKey);
    final layout = TableLayout(size: tester.getSize(box));
    return tester.getTopLeft(box) + layout.toCanvas(p);
  }

  PlannerScene setupScene(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(PlannerSetupView.tableKey), matching: find.byType(CustomPaint)))
          .painter! as PlannerPainter)
      .scene;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  bool planEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(PlannerSetupView.planKey)).onPressed != null;

  testWidgets('mở từ router: màn nhập bàn, Lập kế hoạch tắt khi chưa có bi', (tester) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    await tester.pumpAndSettle();
    router.go(Routes.planner);
    await tester.pumpAndSettle();

    expect(find.byType(PlannerScreen), findsOneWidget);
    expect(find.text(Vi.planTitle), findsWidgets);
    expect(find.text(Vi.planCueHint), findsOneWidget);
    expect(planEnabled(tester), isFalse);
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
  });

  testWidgets('chạm đặt bi cái rồi bi theo thứ tự số; đủ bi thì Lập kế hoạch bật',
      (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await tester.tapAt(onTable(tester, const Vec2(190, 40)));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planOrderHint), findsOneWidget);
    expect(planEnabled(tester), isFalse);

    // Dựng lại giữa hai lần chạm: bàn đọc draft của lần dựng gần nhất.
    await tester.tapAt(onTable(tester, const Vec2(144, 107)));
    await tester.pump();
    await tester.tapAt(onTable(tester, const Vec2(146, 79)));
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.map((b) => b.number), [1, 2]);
    expect(find.bySemanticsLabel(Vi.planSetupSummary(hasCue: true, balls: 2)), findsOneWidget);
    expect(planEnabled(tester), isTrue);
    handle.dispose();
  });

  testWidgets('8 bi: hiện Nhóm của tôi và Đang đặt, bi đối thủ lấy số nhóm kia',
      (tester) async {
    await open(tester, draft: const SetupDraft().tap(const Vec2(40, 100)));
    expect(find.text(Vi.planGroup(BallGroup.solids)), findsNothing);
    await tapText(tester, Vi.planGame(GameType.eightBall));
    expect(find.text(Vi.planGroup(BallGroup.solids)), findsOneWidget);
    expect(find.text(Vi.planPlacing(BallRole.opponent)), findsOneWidget);

    await tapText(tester, Vi.planPlacing(BallRole.opponent));
    await tester.tapAt(onTable(tester, const Vec2(120, 60)));
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.single.number, 9);
    // Chỉ có bi đối thủ: chưa lập kế hoạch được.
    expect(planEnabled(tester), isFalse);
  });

  testWidgets('Lập kế hoạch sang màn từng bước; Sửa bàn về lại, giữ nguyên bi', (tester) async {
    final draft = const SetupDraft()
        .tap(const Vec2(190, 40))
        .tap(const Vec2(144, 107))
        .tap(const Vec2(146, 79));
    await open(tester, draft: draft);
    await tester.tap(find.byKey(PlannerSetupView.planKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlannerStepsView), findsOneWidget);
    expect(find.text(Vi.planStepHeader(1, 2)), findsOneWidget);

    await tapText(tester, Vi.planEditTable);
    expect(find.byType(PlannerSetupView), findsOneWidget);
    expect(setupScene(tester).balls.map((b) => b.pos), draft.balls.map((b) => b.pos));

    // Đổi loại bàn: không còn kế hoạch nào, bi vẫn ở chỗ cũ.
    await tapText(tester, Vi.planGame(GameType.tenBall));
    expect(find.byType(PlannerStepsView), findsNothing);
    expect(setupScene(tester).balls.map((b) => b.pos), draft.balls.map((b) => b.pos));
  });

  testWidgets('kéo bi để chỉnh vị trí; Xoá bi cuối và Xoá hết', (tester) async {
    final draft = const SetupDraft().tap(const Vec2(40, 100)).tap(const Vec2(120, 60));
    await open(tester, draft: draft);
    final from = onTable(tester, const Vec2(120, 60));
    await tester.dragFrom(from, onTable(tester, const Vec2(160, 70)) - from);
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.single.pos.distanceTo(const Vec2(160, 70)), lessThan(0.5));

    await tapText(tester, Vi.planUndo);
    expect(setupScene(tester).balls, isEmpty);
    expect(setupScene(tester).cue, isNotNull);
    await tapText(tester, Vi.planClear);
    expect(setupScene(tester).cue, isNull);
  });

  testWidgets('Xong bàn ở bước cuối đóng màn, về lại Luyện tập', (tester) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    await tester.pumpAndSettle();
    router.go(Routes.training);
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planTitle);
    // Một bi một ngọn: kế hoạch có đúng một bước.
    await tester.tapAt(onTable(tester, const Vec2(190, 40)));
    await tester.pump();
    await tester.tapAt(onTable(tester, const Vec2(144, 107)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlannerSetupView.planKey));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30));
    await tapText(tester, Vi.planFinish);

    expect(find.byType(PlannerScreen), findsNothing);
    expect(find.text(Vi.simTitle), findsOneWidget);
  });
}
