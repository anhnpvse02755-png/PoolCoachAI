import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

import '../../support/planner_tables.dart';

/// Canvas ghi lại các nét thẳng kèm Paint; mọi lệnh vẽ khác bỏ qua.
class _SpyCanvas implements Canvas {
  final lines = <Paint>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Màn từng bước (spec mục 7). Kế hoạch mong đợi lấy từ chính lõi
/// (planToEnd, tất định), không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  late int edits;

  Future<void> open(WidgetTester tester, TableSetup setup, {int? maxSimulationsPerFrame}) async {
    edits = 0;
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: PlannerStepsView(
          setup: setup,
          onEditTable: () => edits++,
          maxSimulationsPerFrame: maxSimulationsPerFrame,
        ),
      ),
    ));
  }

  PlannerScene sceneOf(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(PlannerStepsView.tableKey), matching: find.byType(CustomPaint)))
          .painter! as PlannerPainter)
      .scene;

  TableLayout layoutOf(WidgetTester tester) =>
      TableLayout(size: tester.getSize(find.byKey(PlannerStepsView.tableKey)));

  Offset onTable(WidgetTester tester, Vec2 p) =>
      tester.getTopLeft(find.byKey(PlannerStepsView.tableKey)) + layoutOf(tester).toCanvas(p);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Bước 1 → Đã đánh xong → Đặt lại bi cái.
  Future<void> startReset(WidgetTester tester) async {
    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planResetCue);
  }

  testWidgets('bước 1 hiện khi xong, các bước sau tính tiếp với dòng Đang tính bước X/N',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall), maxSimulationsPerFrame: 1);
    expect(find.text(Vi.planComputing(1, 4)), findsOneWidget);
    for (var i = 0; i < 5000 && find.text(Vi.planStepHeader(1, 4)).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(find.text(Vi.planStepHeader(1, 4)), findsOneWidget);
    expect(find.text(Vi.planComputing(2, 4)), findsOneWidget);
    // Bước cuối đã tính: Đã đánh xong chờ bước kế tiếp.
    expect(tester.widget<FilledButton>(find.byKey(PlannerStepsView.shotDoneKey)).onPressed,
        isNull);

    await tester.pumpAndSettle();
    final steps = planToEnd(orderTable(GameType.nineBall));
    expect(find.text(Vi.planComputing(steps.length + 1, 4)), findsNothing);
    expect(find.text(Vi.planComputing(2, 4)), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(PlannerStepsView.shotDoneKey)).onPressed,
        isNotNull);
  });

  testWidgets('chỉ vẽ tối đa 3 bi, bi cái ở cbFrom, bước kế tiếp để xem trước', (tester) async {
    final steps = planToEnd(orderTable(GameType.nineBall));
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    final scene = sceneOf(tester);
    expect(scene.balls.map((b) => b.number), steps.take(3).map((s) => s.ballNum));
    expect(scene.cue, steps.first.cbFrom);
    expect(scene.step!.ballNum, steps.first.ballNum);
    expect(scene.preview!.ballNum, steps[1].ballNum);
    expect(scene.zone, isNotEmpty);
    expect(find.text(Vi.planPreviewLabel), findsOneWidget);
  });

  testWidgets('Quay lại không xuống dưới bước 1; Đã đánh xong → Đúng thì sang bước sau',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(PlannerStepsView.backKey)).onPressed, isNull);

    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planCueStoppedQuestion), findsOneWidget);
    await tapText(tester, Vi.planYes);
    expect(find.text(Vi.planStepHeader(2, 4)), findsOneWidget);

    await tester.tap(find.byKey(PlannerStepsView.backKey));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planStepHeader(1, 4)), findsOneWidget);
  });

  testWidgets('bước cuối: nút đổi thành Xong bàn; bước phòng thủ nói nên phòng thủ',
      (tester) async {
    await open(tester, blockedEverywhereTable());
    await tester.pumpAndSettle();
    expect(find.text(Vi.planStepHeader(1, 1)), findsOneWidget);
    expect(find.text(Vi.planSafety), findsOneWidget);
    expect(find.text(Vi.planFinish), findsOneWidget);
    expect(find.byKey(PlannerStepsView.shotDoneKey), findsNothing);
  });

  testWidgets('bước dự phòng: nói không có vị trí tốt, không có dòng chịu sai số, '
      'không có thanh sai số lực', (tester) async {
    await open(tester, fallbackTable());
    await tester.pumpAndSettle();
    final step = sceneOf(tester).step!;
    expect(step.kind, PlanStepKind.fallback);
    expect(find.text(Vi.planNoPosition), findsOneWidget);
    for (var good = 0; good <= toleranceSamples; good++) {
      expect(find.text(Vi.planTolerance(good, toleranceSamples)), findsNothing);
    }
    // Vẽ được cả bước dự phòng (điểm, sai số lực, độ chịu đều null).
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('thanh sai số lực', () {
    const size = Size(540, 286);

    /// Nét thẳng của thanh sai số lực: vàng, đầu tròn.
    List<Paint> jitterBars(PlanStep step) {
      final canvas = _SpyCanvas();
      PlannerPainter(PlannerScene(cue: step.cbFrom, step: step)).paint(canvas, size);
      return [
        for (final p in canvas.lines)
          if (p.strokeCap == StrokeCap.round && p.color.toARGB32() ==
              AppColors.railHit.withValues(alpha: 0.8).toARGB32())
            p,
      ];
    }

    test('bước thường có thanh, bước dự phòng thì không', () {
      final normal = planToEnd(railTable()).first;
      expect(normal.kind, PlanStepKind.normal);
      expect(jitterBars(normal), isNotEmpty);

      final fallback = planToEnd(fallbackTable()).first;
      expect(fallback.kind, PlanStepKind.fallback);
      expect(fallback.jitterEnds, isNull);
      expect(jitterBars(fallback), isEmpty);
    });
  });

  testWidgets('Đặt lại bi cái: kéo tới chỗ dừng thật, Tính lại từ đây với các bi còn lại',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    await startReset(tester);
    expect(find.text(Vi.planResetHint), findsOneWidget);

    const target = Vec2(100, 50);
    final from = onTable(tester, sceneOf(tester).cue!);
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).cue!.distanceTo(target), lessThan(0.5));

    await tapText(tester, Vi.planRecompute);
    expect(find.text(Vi.planStepHeader(1, 3)), findsOneWidget);
    final scene = sceneOf(tester);
    expect(scene.step!.ballNum, 2);
    expect(scene.cue!.distanceTo(target), lessThan(0.5));
  });

  testWidgets('Đặt lại bi cái: bắt bi trong 24 px quanh tâm, kéo chỗ xa thì bi không nhảy',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    await startReset(tester);
    final start = sceneOf(tester).cue!;
    final layout = layoutOf(tester);

    // Chạm cách tâm 22 px (ngoài 1.5 bán kính bi trên khung này) vẫn bắt.
    expect(layout.table.radius * 1.5 * layout.scale, lessThan(22));
    final near = onTable(tester, start) + const Offset(0, -22);
    await tester.dragFrom(near, const Offset(-60, 0));
    await tester.pumpAndSettle();
    final moved = sceneOf(tester).cue!;
    expect(moved.distanceTo(start), greaterThan(10));

    // Chạm xa bi (30 cm, vẫn trên mặt bàn) rồi kéo: bi cái đứng yên.
    final far = onTable(tester, Vec2(moved.x + (moved.x < 127 ? 30 : -30), moved.y));
    await tester.dragFrom(far, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(sceneOf(tester).cue, moved);
  });

  testWidgets('kéo bi cái đè lên bi khác thì bị đẩy ra', (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    await startReset(tester);
    const ball2 = Vec2(60, 40);
    final from = onTable(tester, sceneOf(tester).cue!);
    await tester.dragFrom(from, onTable(tester, ball2) - from);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).cue!.distanceTo(ball2),
        greaterThanOrEqualTo(table.ballDiameter - 1e-6));
  });

  testWidgets('Sửa bàn gọi về màn nhập bàn', (tester) async {
    await open(tester, railTable());
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planEditTable);
    expect(edits, 1);
  });

  testWidgets('rời màn giữa lúc đang tính: không lỗi, việc tính bị hủy', (tester) async {
    await open(tester, typicalNineBallTable(), maxSimulationsPerFrame: 1);
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bàn có nhãn semantics tóm tắt bước đang xem', (tester) async {
    final handle = tester.ensureSemantics();
    final steps = planToEnd(railTable());
    await open(tester, railTable());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(Vi.planSummary(steps.first, index: 0, total: steps.length)),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('chú giải ngay dưới bàn, trước bảng thông tin; disclaimer luôn hiện',
      (tester) async {
    await open(tester, railTable());
    await tester.pumpAndSettle();
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
    for (final line in Vi.planLegend) {
      expect(find.text(line), findsOneWidget);
    }
    final tableBottom = tester.getBottomLeft(find.byKey(PlannerStepsView.tableKey)).dy;
    final legendTop = tester.getTopLeft(find.text(Vi.planLegend.first)).dy;
    final legendBottom = tester.getBottomLeft(find.text(Vi.planLegend.last)).dy;
    final headerTop = tester.getTopLeft(find.text(Vi.planStepHeader(1, 2))).dy;
    expect(legendTop, greaterThan(tableBottom));
    expect(legendTop - tableBottom, lessThan(40));
    expect(legendBottom, lessThan(headerTop));
  });

  test('painter vẽ lại khi cảnh đổi', () {
    const a = PlannerScene(cue: Vec2(10, 10));
    const b = PlannerScene(cue: Vec2(20, 10));
    expect(PlannerPainter(b).shouldRepaint(PlannerPainter(a)), isTrue);
    expect(PlannerPainter(a).shouldRepaint(PlannerPainter(a)), isFalse);
  });
}
