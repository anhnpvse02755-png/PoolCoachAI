import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

import '../../support/planner_tables.dart';

/// Canvas ghi lại các nét thẳng kèm Paint, và độ mờ của lớp đang vẽ mỗi
/// hình tròn; mọi lệnh vẽ khác bỏ qua.
class _SpyCanvas implements Canvas {
  final lines = <Paint>[];
  final _layers = <double>[];

  /// Tâm mỗi hình tròn kèm độ mờ của lớp bọc nó (1 khi không có lớp).
  final circles = <(Offset, double)>[];

  /// Bán kính mọi hình tròn, theo thứ tự vẽ — để thấy vòng vàng 1,4 bán kính bi.
  final radii = <double>[];

  /// Paint của mọi nét/đường/hình tròn theo thứ tự vẽ, để kiểm thứ tự lớp.
  final order = <Paint>[];
  var paragraphs = 0;

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => paragraphs++;

  @override
  void drawPath(Path path, Paint paint) => order.add(paint);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add(paint);
    order.add(paint);
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) => _layers.add(paint.color.a);

  @override
  void save() => _layers.add(1);

  @override
  void restore() => _layers.removeLast();

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add((c, _layers.fold(1.0, (a, b) => a * b)));
    radii.add(radius);
    order.add(paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Màn từng bước (spec mục 7). Kế hoạch mong đợi lấy từ chính lõi
/// (planToEnd, tất định), không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  late int edits;

  // Mô phỏng thật nhưng nhớ theo đầu vào (tất định): cùng một bàn bị tìm cú
  // thủ nhiều lần trong file này (lõi tính sẵn kết quả mong đợi, rồi màn tính
  // lại), mỗi lần chỉ cần trả lời một lần.
  final simCache = <SimKey, ShotTrace>{};
  final cachedSafety = SafetyPhysics(
    simulate: (input) => simCache.putIfAbsent(keyOf(input), () => simulateShot(input)),
  );

  Future<void> open(WidgetTester tester, TableSetup setup,
      {int? maxSimulationsPerFrame,
      int? maxZoneRowsPerFrame,
      SafetyPhysics safety = const SafetyPhysics()}) async {
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
          safety: safety,
          maxSimulationsPerFrame: maxSimulationsPerFrame,
          maxZoneRowsPerFrame: maxZoneRowsPerFrame,
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

  testWidgets('vùng điều hiện dần vài hàng mỗi khung hình, xong thì đúng y lưới một mạch',
      (tester) async {
    final setup = orderTable(GameType.nineBall);
    final steps = planToEnd(setup);
    final whole = zoneGrid(
        after: setup.without([steps.first.ballNum!]).balls,
        next: CandidateFinder(game: setup.game, table: setup.table));
    List<(Vec2, ZoneLevel)> flat(List<ZoneCell> cells) =>
        [for (final c in cells) (c.center, c.level)];

    await open(tester, setup, maxZoneRowsPerFrame: 1);
    for (var i = 0; i < 5000 && find.text(Vi.planStepHeader(1, 4)).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(sceneOf(tester).zone.length, lessThan(whole.length));
    await tester.pumpAndSettle();
    expect(flat(sceneOf(tester).zone), flat(whole));
  });

  testWidgets('các bi khác còn trên bàn vẽ mờ: không phải 3 bi đang xem, không phải bi đã vào',
      (tester) async {
    final setup = typicalNineBallTable();
    final steps = planToEnd(setup);
    List<int> ghostsAt(int view) {
      final gone = {for (final s in steps.take(view)) s.ballNum};
      final shown = {for (final s in steps.skip(view).take(3)) s.ballNum};
      return [
        for (final b in setup.balls)
          if (!gone.contains(b.number) && !shown.contains(b.number)) b.number,
      ];
    }

    await open(tester, setup);
    await tester.pumpAndSettle();
    var scene = sceneOf(tester);
    expect(scene.balls.map((b) => b.number), steps.take(3).map((s) => s.ballNum));
    expect(ghostsAt(0), isNotEmpty);
    expect(scene.ghosts.map((b) => b.number), ghostsAt(0));

    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planYes);
    scene = sceneOf(tester);
    expect(scene.ghosts.map((b) => b.number), ghostsAt(1));
    expect(scene.ghosts.map((b) => b.number), isNot(contains(steps.first.ballNum)));
  });

  testWidgets('bàn phòng thủ: các bi chắn vẫn thấy, vẽ mờ', (tester) async {
    final setup = blockedEverywhereTable();
    await open(tester, setup, safety: noSafetyPhysics);
    await tester.pumpAndSettle();
    final scene = sceneOf(tester);
    expect(scene.balls.map((b) => b.number), [1]);
    expect(scene.ghosts.map((b) => b.number), setup.balls.skip(1).map((b) => b.number));
  });

  test('painter vẽ bi mờ trong một lớp nhạt, bi đang xem thì rõ', () {
    final setup = typicalNineBallTable();
    const size = Size(540, 286);
    const layout = TableLayout(size: size);
    final canvas = _SpyCanvas();
    PlannerPainter(PlannerScene(
      cue: setup.cue,
      balls: setup.balls.take(1).toList(),
      ghosts: setup.balls.skip(1).toList(),
    )).paint(canvas, size);
    double alphaAt(Vec2 p) =>
        canvas.circles.lastWhere((c) => (c.$1 - layout.toCanvas(p)).distance < 1e-6).$2;
    expect(alphaAt(setup.balls.first.pos), 1);
    for (final b in setup.balls.skip(1)) {
      expect(alphaAt(b.pos), lessThanOrEqualTo(0.3));
    }
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

  testWidgets('bước cuối: nút đổi thành Xong bàn; bước phòng thủ nói bi nào và nên chơi an toàn',
      (tester) async {
    await open(tester, blockedEverywhereTable(), safety: noSafetyPhysics);
    await tester.pumpAndSettle();
    expect(find.text(Vi.planStepHeader(1, 1)), findsOneWidget);
    expect(find.text(Vi.planSafety(1)), findsOneWidget);
    expect(find.text(Vi.planFinish), findsOneWidget);
    expect(find.byKey(PlannerStepsView.shotDoneKey), findsNothing);
  });

  testWidgets('bước dự phòng: nói không có vị trí tốt, không có dòng chịu sai số, '
      'không có thanh sai số lực', (tester) async {
    await open(tester, fallbackTable(), safety: noSafetyPhysics);
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

      final fallback = planToEnd(fallbackTable(), safety: noSafetyPhysics).first;
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

  group('cú thủ: lượt thô và điểm hỏi (chủ sản phẩm chốt 08/10/2026 sau Task 25)', () {
    testWidgets('đang tìm cú thủ: dòng Đang tìm cú thủ… thay Đang tính bước, xong thì hiện bước',
        (tester) async {
      await open(tester, noPotTable(), maxSimulationsPerFrame: 1, safety: noSafetyPhysics);
      await tester.pump();
      await tester.pump();
      expect(find.text(Vi.planSearchingSafety), findsOneWidget);
      expect(find.textContaining('Đang tính bước'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(Vi.planSearchingSafety), findsNothing);
      expect(find.text(Vi.planSafety(1)), findsOneWidget);
      expect(find.text(Vi.planSafetyCheckpoint), findsNothing);
    });

    testWidgets('lượt thô thủ tốt: hiện bước và câu hỏi, không tính gì thêm; Dùng cú này thì xong',
        (tester) async {
      await open(tester, noPotTable(), safety: cachedSafety);
      await tester.pumpAndSettle();
      expect(find.text(Vi.planSafetyCheckpoint), findsOneWidget);
      expect(find.text(Vi.planSafetyContinue), findsOneWidget);
      expect(find.text(Vi.planSafetyKeep), findsOneWidget);
      expect(find.text(Vi.planSearchingSafety), findsNothing);
      expect(find.textContaining('Đang tính bước'), findsNothing);
      // Kế hoạch dừng sau bước phòng thủ: bước 1 / 1, dù còn đang hỏi.
      expect(find.text(Vi.planStepHeader(1, 1)), findsOneWidget);
      final rough = sceneOf(tester).step!.safety!;
      await tester.ensureVisible(find.byKey(PlannerStepsView.keepSafetyKey));
      await tester.tap(find.byKey(PlannerStepsView.keepSafetyKey));
      await tester.pumpAndSettle();
      expect(find.text(Vi.planSafetyCheckpoint), findsNothing);
      expect(find.text(Vi.planFinish), findsOneWidget);
      expect(sceneOf(tester).step!.safety, same(rough));
    });

    testWidgets('Tính tiếp: Đang tìm cú thủ…, rồi cú của lượt đầy đủ khi tốt hơn hẳn',
        (tester) async {
      final expected = planToEnd(noPotTable(), safety: cachedSafety).single.safety;
      await open(tester, noPotTable(), safety: cachedSafety);
      await tester.pumpAndSettle();
      final rough = sceneOf(tester).step!.safety!;
      await tester.ensureVisible(find.byKey(PlannerStepsView.continueSafetyKey));
      await tester.tap(find.byKey(PlannerStepsView.continueSafetyKey));
      await tester.pump();
      expect(find.text(Vi.planSafetyCheckpoint), findsNothing);
      expect(find.text(Vi.planSearchingSafety), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(Vi.planSearchingSafety), findsNothing);
      expect(find.text(Vi.planFinish), findsOneWidget);
      final shown = sceneOf(tester).step!.safety;
      expect(safetyFingerprint(shown), safetyFingerprint(expected));
      // Đo với Task 25a–25b: trên bàn này lượt đầy đủ tốt hơn hẳn lượt thô.
      expect(shown!.total, lessThan(rough.total));
    });

    testWidgets('lượt thô chưa thủ tốt: hiện cú tạm và dòng đang tìm, không hỏi; xong thì tắt dòng',
        (tester) async {
      await open(tester, snookerTwoRailTable(), safety: cachedSafety);
      for (var i = 0; i < 2000 && sceneOf(tester).step == null; i++) {
        await tester.pump();
      }
      final first = sceneOf(tester).step!;
      expect(first.safety, isNotNull);
      expect(find.text(Vi.planSafetyProvisional), findsOneWidget);
      expect(find.text(Vi.planSafetyCheckpoint), findsNothing);
      expect(find.text(Vi.planSearchingSafety), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(Vi.planSafetyProvisional), findsNothing);
      expect(find.text(Vi.planFinish), findsOneWidget);
      // Đo với Task 25a–25b: bàn này không có cú tốt hơn hẳn, cú tạm ở lại.
      expect(sceneOf(tester).step!.safety, same(first.safety));
    });

    testWidgets('rời màn ở điểm hỏi hay giữa lúc tìm tiếp: không lỗi', (tester) async {
      await open(tester, noPotTable(), safety: cachedSafety);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await open(tester, noPotTable(), safety: cachedSafety);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(PlannerStepsView.continueSafetyKey));
      await tester.tap(find.byKey(PlannerStepsView.continueSafetyKey));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  test('painter vẽ lại khi cảnh đổi', () {
    const a = PlannerScene(cue: Vec2(10, 10));
    const b = PlannerScene(cue: Vec2(20, 10));
    expect(PlannerPainter(b).shouldRepaint(PlannerPainter(a)), isTrue);
    expect(PlannerPainter(a).shouldRepaint(PlannerPainter(a)), isFalse);
  });

  group('bước phòng thủ có cú thủ (spec cú phòng thủ 5.1)', () {
    late PlanStep kick;
    late PlanStep direct;
    late PlanStep snookered;

    setUpAll(() {
      // planToEnd bấm "Tính tiếp" ở điểm hỏi; bàn 1 băng giữ cú lượt thô.
      kick = planToEnd(snookerOneRailTable()).single;
      // A băng nay cũng được xét ở bàn hết đường ăn (chủ sản phẩm chốt
      // 08/10/2026), nhưng cú trực tiếp vẫn thắng — test 7 của
      // safety_spec_test giữ điều đó, nên bước này không có điểm ngắm băng.
      direct = planToEnd(noPotTable()).single;
      // Không bàn mẫu nào của lõi chọn cú thủ để đối thủ bị đui (đo lại sau
      // Task 25: bàn 3 băng còn 44,5°), nên dựng cú thủ có đối thủ bị đui từ
      // cú A băng thật — painter chỉ vẽ lại những gì SafetyShot nói.
      final k = kick.safety!;
      snookered = PlanStep.safety(
        cbFrom: kick.cbFrom,
        ballNum: kick.ballNum,
        safety: SafetyShot(
          reason: k.reason,
          kind: k.kind,
          rails: k.rails,
          ballNum: k.ballNum,
          thickness: k.thickness,
          side: k.side,
          stroke: k.stroke,
          spin: k.spin,
          power: k.power,
          aimed: k.aimed,
          railAim: k.railAim,
          opponent: OpponentView(snookered: true, ball: k.opponent.ball),
          jitterEnds: k.jitterEnds,
          tolerance: k.tolerance,
          sawsBhePercent: k.sawsBhePercent,
          contactDistance: k.contactDistance,
          total: k.total,
        ),
      );
    });

    const size = Size(540, 286);
    const layout = TableLayout(size: size);

    _SpyCanvas draw(PlanStep s) {
      final canvas = _SpyCanvas();
      PlannerPainter(PlannerScene(cue: s.cbFrom, step: s)).paint(canvas, size);
      return canvas;
    }

    test('A băng: vòng vàng 1,4 bán kính bi ở điểm ngắm trên băng, số chấm ở mép bàn', () {
      final withKick = draw(kick);
      final withDirect = draw(direct);
      final at = layout.toCanvas(kick.safety!.railAim!.at);
      final r = layout.table.radius * layout.scale;
      final ring = [
        for (var i = 0; i < withKick.circles.length; i++)
          if ((withKick.circles[i].$1 - at).distance < 1e-6 &&
              (withKick.radii[i] - PlannerPainter.railAimRing * r).abs() < 1e-6)
            i
      ];
      expect(PlannerPainter.railAimRing, 1.4);
      expect(ring, isNotEmpty);
      expect(withDirect.radii.where((x) => (x - 1.4 * r).abs() < 1e-6), isEmpty);
      // Chữ "Đối thủ bị đui" cũng là một đoạn chữ: trừ ra trước khi đếm số chấm.
      int label(PlanStep s) => s.safety!.opponent.snookered && s.safety!.opponent.ball != null ? 1 : 0;
      // 9 + 9 số trên hai băng dài, 5 + 5 trên hai băng ngắn.
      expect((withKick.paragraphs - label(kick)) - (withDirect.paragraphs - label(direct)),
          2 * (longRailDiamonds + 1) + 2 * (shortRailDiamonds + 1));
    });

    test('cú dễ nhất của đối thủ vẽ mờ màu đỏ; đối thủ đui thì ghi chữ', () {
      var reds = 0;
      for (final step in [kick, direct]) {
        final red = draw(step).lines.where((p) =>
            p.color.toARGB32() & 0xFFFFFF == AppColors.danger.toARGB32() & 0xFFFFFF &&
            p.color.a < 1);
        if (step.safety!.opponent.easiest != null) {
          expect(red, isNotEmpty);
          reds += red.length;
        }
      }
      // Phải có ít nhất một bước thật sự cho nét đỏ, không để test qua suông.
      expect(reds, greaterThan(0));
      final op = snookered.safety!.opponent;
      expect(op.snookered, isTrue);
      expect(op.ball, isNotNull);
      // Đoạn chữ duy nhất ngoài số chấm là "Đối thủ bị đui".
      final diamonds = snookered.safety!.railAim == null
          ? 0
          : 2 * (longRailDiamonds + 1) + 2 * (shortRailDiamonds + 1);
      expect(draw(snookered).paragraphs, 1 + diamonds);
    });

    test('thứ tự lớp theo spec 5.1: đường đỏ của đối thủ nằm trên đường bi cái, bi hợp lệ', () {
      bool isRed(Paint p) =>
          p.color.toARGB32() & 0xFFFFFF == AppColors.danger.toARGB32() & 0xFFFFFF &&
          p.color.a < 1;
      var checked = 0;
      for (final step in [kick, direct, snookered]) {
        final order = draw(step).order;
        final firstRed = order.indexWhere(isRed);
        // Bước có cú dễ nhất hay đối thủ đui đều phải có nét đỏ.
        final op = step.safety!.opponent;
        if (op.easiest != null || (op.snookered && op.ball != null)) {
          expect(firstRed, greaterThanOrEqualTo(0));
        }
        if (firstRed < 0) continue;
        checked++;
        final lastCue = order.lastIndexWhere((p) => p.color == AppColors.cuePath);
        final lastGrey = order.lastIndexWhere((p) => p.color == AppColors.textSecondary);
        expect(lastCue, lessThan(firstRed));
        expect(lastGrey, lessThan(firstRed));
        final jitter = order.indexWhere((p) =>
            p.strokeCap == StrokeCap.round &&
            p.color.toARGB32() == AppColors.railHit.withValues(alpha: 0.8).toARGB32());
        if (jitter >= 0) expect(jitter, greaterThan(order.lastIndexWhere(isRed)));
      }
      // Cú dễ nhất (kick) và đường đỏ nét đứt của đối thủ đui đều được kiểm.
      expect(checked, greaterThanOrEqualTo(2));
    });

    test('painter vẽ được bước phòng thủ không có cú thủ', () {
      final canvas = _SpyCanvas();
      expect(
          () => PlannerPainter(const PlannerScene(
                  cue: Vec2(40, 100), step: PlanStep.safety(cbFrom: Vec2(40, 100))))
              .paint(canvas, const Size(540, 286)),
          returnsNormally);
    });
  });
}
