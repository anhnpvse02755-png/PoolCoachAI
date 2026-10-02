import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/table_layouts.dart';
import '../../support/test_data.dart';

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5 và 2026-10-02 mục 6. Mọi con
/// số mong đợi lấy từ chính lõi, không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  final initial = bestPocket(
    cue: SimulatorScreen.initialCue,
    object: SimulatorScreen.initialObject,
  )!;

  Future<void> openSimulator(WidgetTester tester,
      {Size size = const Size(1200, 1800)}) async {
    // Mặc định đủ cao để cả bàn lẫn bảng thông tin nằm trong màn.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.simulator);
    await tester.pumpAndSettle();
  }

  Offset onTable(WidgetTester tester, Vec2 p) {
    final box = find.byKey(SimulatorScreen.tableKey);
    final layout = TableLayout(size: tester.getSize(box));
    return tester.getTopLeft(box) + layout.toCanvas(p);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('mở màn ra một cú hợp lệ, lỗ tự chọn và góc do lõi tính',
      (tester) async {
    await openSimulator(tester);

    expect(find.text(Vi.simPocketLine(initial.pocket)), findsOneWidget);
    expect(find.text(Vi.simAngleLine(initial.angle)), findsOneWidget);
    expect(find.text(Vi.simBandLine(bandFor(initial.angle))), findsOneWidget);
    expect(find.text(Vi.simStrokeLine(Stroke.stun)), findsOneWidget);
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
  });

  testWidgets('đổi kiểu đánh thì bảng thông tin đổi theo', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simStroke(Stroke.draw));

    expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
    expect(find.text(Vi.simStrokeLine(Stroke.stun)), findsNothing);
  });

  testWidgets('chạm lỗ khác thì dùng lỗ đó, kể cả khi lỗ đó không đánh được',
      (tester) async {
    await openSimulator(tester);

    await tester.tapAt(
        onTable(tester, table.pocketPosition(Pocket.topMiddle)));
    await tester.pumpAndSettle();

    final expected = evaluateShot(
      cue: SimulatorScreen.initialCue,
      object: SimulatorScreen.initialObject,
      pocket: Pocket.topMiddle,
    );
    switch (expected) {
      case Makeable(:final geometry):
        expect(find.text(Vi.simPocketLine(geometry.pocket)), findsOneWidget);
      case Unmakeable(:final reason):
        expect(find.text(Vi.simUnmakeable(reason)), findsOneWidget);
    }
  });

  testWidgets('kéo bi mục tiêu thì quay về tự chọn lỗ theo bố cục mới',
      (tester) async {
    await openSimulator(tester);
    await tester.tapAt(
        onTable(tester, table.pocketPosition(Pocket.topMiddle)));
    await tester.pumpAndSettle();

    const target = Vec2(60, 40);
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();

    final expected =
        bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
    expect(find.text(Vi.simPocketLine(expected.pocket)), findsOneWidget);
  });

  testWidgets('kéo dọc trên bàn là kéo bi, không cuộn trang', (tester) async {
    await openSimulator(tester);

    const target = Vec2(170, 110);
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();

    final expected =
        bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
    expect(find.text(Vi.simAngleLine(expected.angle)), findsOneWidget);
  });

  testWidgets('thả bi đè lên bi kia thì bị đẩy về vừa chạm, không chồng',
      (tester) async {
    await openSimulator(tester);

    // Thả đúng tâm bi cái thì hướng đẩy ra dùng nhánh mặc định (1,0) của
    // _separate — gần như chắc chắn không thẳng hàng với lỗ nào, nên góc
    // cắt nhảy lên ~90° (quá mỏng) cho cả sáu lỗ dù _separate có chạy
    // đúng hay không — "findsNothing" cho overlap không phân biệt được gì.
    // Thả gần bi cái nhưng đúng trên tia bi cái→một lỗ cụ thể thì sau khi
    // tách, bi mục tiêu nằm đúng trên đường đó, góc cắt ~0 — một cú thật
    // đánh được, nên thiếu _separate (bi vẫn chồng) mới lộ ra khác biệt.
    const towardPocket = Pocket.bottomRight;
    final toward =
        (table.pocketPosition(towardPocket) - SimulatorScreen.initialCue)
            .normalized;
    final dropTarget = SimulatorScreen.initialCue + toward * 1.0;

    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, dropTarget) - from);
    await tester.pumpAndSettle();

    expect(find.text(Vi.simUnmakeable(UnmakeableReason.overlap)), findsNothing);
    expect(find.text(Vi.simNoPocket), findsNothing);
    expect(
      Pocket.values.any(
        (p) => find.text(Vi.simPocketLine(p)).evaluate().isNotEmpty,
      ),
      isTrue,
      reason: 'phải có một dòng Lỗ: ... nghĩa là bestPocket tính ra lỗ thật, '
          'chứng tỏ hai bi đã được tách nhau chứ không còn chồng lên nhau',
    );
  });

  // Điện thoại ~390 px: bàn co lại còn ~1.3 px/cm, nên bán kính tính theo cm
  // chỉ còn vài px — ngón tay phải có sàn bán kính trên màn.
  group('điện thoại 390x844', () {
    const phone = Size(390, 844);

    testWidgets('kéo bi bắt đầu lệch tâm ~15 px vẫn bắt được bi',
        (tester) async {
      await openSimulator(tester, size: phone);

      final centre = onTable(tester, SimulatorScreen.initialObject);
      final from = centre + const Offset(15, 0);
      const target = Vec2(170, 110);
      await tester.dragFrom(from, onTable(tester, target) - from);
      await tester.pumpAndSettle();

      final expected =
          bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
      expect(find.text(Vi.simAngleLine(expected.angle)), findsOneWidget);
    });

    testWidgets('chạm lệch tâm lỗ ~15 px vẫn chọn lỗ đó', (tester) async {
      await openSimulator(tester, size: phone);

      final centre =
          onTable(tester, table.pocketPosition(Pocket.topMiddle));
      await tester.tapAt(centre + const Offset(0, 15));
      await tester.pumpAndSettle();

      final expected = evaluateShot(
        cue: SimulatorScreen.initialCue,
        object: SimulatorScreen.initialObject,
        pocket: Pocket.topMiddle,
      );
      switch (expected) {
        case Makeable(:final geometry):
          expect(find.text(Vi.simPocketLine(geometry.pocket)), findsOneWidget);
        case Unmakeable(:final reason):
          expect(find.text(Vi.simUnmakeable(reason)), findsOneWidget);
      }
    });
  });

  // Bi kia cách băng ~1 cm, thả bi này sát nó về phía băng: hướng đẩy ra
  // ngoài bàn, kẹp lại thì chồng ~4.7 cm nếu không có cách xử lý riêng.
  group('tách hai bi chồng nhau sát băng', () {
    final other = Vec2(100, table.minY + 0.6);
    final drop = Vec2(other.x, table.minY);
    const previous = Vec2(40, 60);

    test('đẩy dọc theo băng thì hai bi không còn chồng', () {
      final moved = SimulatorScreen.separate(drop, other, previous);
      expect(moved.distanceTo(other), greaterThanOrEqualTo(table.ballDiameter));
      expect(table.contains(moved), isTrue);
    });

    test('giữa bàn thì vẫn đẩy theo hướng từ bi kia ra', () {
      const centre = Vec2(120, 60);
      final moved =
          SimulatorScreen.separate(centre + const Vec2(1, 0), centre, previous);
      expect(moved.distanceTo(centre), greaterThanOrEqualTo(table.ballDiameter));
      expect(moved.y, centre.y);
      expect(moved.x, greaterThan(centre.x));
    });
  });

  /// Cảnh mà bàn đang vẽ — lấy thẳng từ painter, không đoán.
  SimulatorScene sceneOf(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(SimulatorScreen.tableKey),
              matching: find.byType(CustomPaint)))
          .painter! as TablePainter)
      .scene;

  AimedShot aimedFor(ShotGeometry g,
          {Stroke stroke = Stroke.stun,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: powerPresets[1],
          elevation: elevation);

  testWidgets('có nút Độ dốc cơ và đủ năm mức lực', (tester) async {
    await openSimulator(tester);

    for (final p in powerPresets) {
      expect(find.text(Vi.simPowerPreset(p)), findsOneWidget);
    }
    expect(find.text(Vi.simElevation(CueElevation.normal)), findsOneWidget);
    expect(find.text(Vi.simElevation(CueElevation.steep)), findsOneWidget);

    await tapText(tester, Vi.simElevation(CueElevation.steep));
    expect(find.text(Vi.simElevationLine(CueElevation.steep)), findsOneWidget);
  });

  testWidgets('công tắc bù ném hiện và ẩn đường đỏ', (tester) async {
    await openSimulator(tester);
    expect(sceneOf(tester).showUncompensated, isFalse);

    final toggle = find.byKey(SimulatorPanel.compensateToggleKey);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).showUncompensated, isTrue);
    expect(sceneOf(tester).aimed!.uncompensated, isNotNull);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).showUncompensated, isFalse);
  });

  test('công tắc bù ném chỉ mở khi có ném: có áp phê hoặc góc cắt khác 0', () {
    final straight =
        geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 0);
    final cut = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 20);
    const none = SideSpin.none();
    expect(SimulatorScreen.canShowUncompensated(straight, none), isFalse);
    expect(
        SimulatorScreen.canShowUncompensated(
            straight, const SideSpin(SpinSide.left, 0.5)),
        isTrue);
    expect(SimulatorScreen.canShowUncompensated(cut, none), isTrue);
  });

  testWidgets('bắn thẳng không áp phê thì công tắc bị khoá', (tester) async {
    await openSimulator(tester);
    // Thả bi mục tiêu sát bi cái, đúng trên tia bi cái → lỗ góc dưới
    // phải: sau khi tách, hai bi thẳng hàng với lỗ, góc cắt 0°.
    final toward = (table.pocketPosition(Pocket.bottomRight) -
            SimulatorScreen.initialCue)
        .normalized;
    final drop = SimulatorScreen.initialCue + toward * 1.0;
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, drop) - from);
    await tester.pumpAndSettle();

    expect(sceneOf(tester).geometry!.angle.round(), 0);
    final toggle = find.byKey(SimulatorPanel.compensateToggleKey);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
  });

  testWidgets('hết ném thì công tắc tắt hẳn, có ném lại không tự bật',
      (tester) async {
    await openSimulator(tester);
    // Cú thẳng 0°: chỉ còn áp phê tạo ném.
    final toward = (table.pocketPosition(Pocket.bottomRight) -
            SimulatorScreen.initialCue)
        .normalized;
    final drop = SimulatorScreen.initialCue + toward * 1.0;
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, drop) - from);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).geometry!.angle.round(), 0);

    const spin = SideSpin(SpinSide.right, 1);
    await tapText(tester, Vi.simSpinChip(spin));
    final toggle = find.byKey(SimulatorPanel.compensateToggleKey);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(sceneOf(tester).showUncompensated, isTrue);

    // Bỏ áp phê: hết ném, công tắc khoá và phải đọc là tắt.
    await tapText(tester, Vi.simSpinChip(const SideSpin.none()));
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(sceneOf(tester).showUncompensated, isFalse);

    // Áp phê lại: có ném nhưng người chơi chưa bấm, đường đỏ không tự về.
    await tapText(tester, Vi.simSpinChip(spin));
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(sceneOf(tester).showUncompensated, isFalse);
  });

  testWidgets('dòng ngắm dày/mỏng đúng chiều với aimOffsetDeg của lõi',
      (tester) async {
    const spin = SideSpin(SpinSide.right, 1);
    final expected = aimedFor(initial, spin: spin).aimOffsetDeg;
    expect(expected.abs(), greaterThanOrEqualTo(aimOffsetShownDeg),
        reason: 'bố cục mở màn có áp phê phải đủ bù để dòng này hiện');
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(spin));

    expect(find.text(Vi.simAimOffset(expected)), findsOneWidget);
  });

  testWidgets('dòng Đánh đứng bi chỉ hiện khi đánh đứng bi và đủ ngưỡng',
      (tester) async {
    final b = aimedFor(initial).verticalOffset;
    expect(b.abs(), greaterThanOrEqualTo(stunOffsetShownTips * tipWidth),
        reason: 'bố cục mở màn đủ xa để phải đặt cơ dưới tâm');
    await openSimulator(tester);
    expect(find.text(Vi.simStunOffset(b)), findsOneWidget);

    await tapText(tester, Vi.simStroke(Stroke.follow));
    expect(find.text(Vi.simStunOffset(b)), findsNothing);
  });

  testWidgets('gợi ý chống chết cái hiện Đang tính… khi kéo, cập nhật khi thả',
      (tester) async {
    await openSimulator(tester);
    expect(find.text(Vi.simComputing), findsNothing);

    final gesture = await tester
        .startGesture(onTable(tester, SimulatorScreen.initialObject));
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    expect(find.text(Vi.simComputing), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text(Vi.simComputing), findsNothing);

    final scene = sceneOf(tester);
    final g = scene.geometry!;
    final advice = scratchAdvice(g,
        stroke: Stroke.stun, power: powerPresets[1], spin: const SideSpin.none());
    for (final a in advice) {
      expect(find.text(Vi.simAdvice(a)), findsOneWidget);
    }
  });

  /// Mở thẳng màn mô phỏng với [aim] thay cho `aimShot` thật.
  Future<void> openWithAim(WidgetTester tester, AimShotFn aim) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: SimulatorScreen(aim: aim),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lõi quá maxSimTime: chỉ vẽ hình học, báo một dòng, không vỡ',
      (tester) async {
    AimedShot timesOut({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
    }) =>
        throw SimulationTimeout(
            ShotInput(cue: cue, object: object, aimAngle: 0, power: power));

    await openWithAim(tester, timesOut);

    expect(tester.takeException(), isNull);
    final scene = sceneOf(tester);
    expect(scene.geometry, isNotNull);
    expect(scene.aimed, isNull);
    expect(find.text(Vi.simCannotSimulate), findsOneWidget);
    expect(find.text(Vi.simPocketLine(initial.pocket)), findsOneWidget);
    // Gợi ý vẫn chạy xong trên lõi thật.
    expect(find.text(Vi.simComputing), findsNothing);
  });

  testWidgets('lệch 2 đầu cơ thì cảnh báo trượt cơ', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.left, 2)));

    expect(find.text(Vi.simMiscue), findsOneWidget);
  });

  testWidgets('bàn có nhãn semantics tóm tắt cú đánh', (tester) async {
    final handle = tester.ensureSemantics();
    await openSimulator(tester);

    expect(
        find.bySemanticsLabel(Vi.simSummary(Makeable(initial), aimedFor(initial),
            elevation: CueElevation.normal)),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'màn hình ngang Chrome desktop không tràn, bảng điều khiển vẫn bấm được',
      (tester) async {
    // Chrome là nền chạy được duy nhất, và cửa sổ desktop thường ngang hơn
    // là dọc — 1280x720 lộ ra lỗi mà khung portrait của các test trên
    // không bao giờ thấy: bàn cao vô hạn theo bề ngang, đẩy tràn RenderFlex.
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.simulator);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final tableBox = find.byKey(SimulatorScreen.tableKey);
    final topLeft = tester.getTopLeft(tableBox);
    final bottomRight = tester.getBottomRight(tableBox);
    expect(topLeft.dx, greaterThanOrEqualTo(0));
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    expect(bottomRight.dx, lessThanOrEqualTo(1280));
    expect(bottomRight.dy, lessThanOrEqualTo(720));

    await tapText(tester, Vi.simStroke(Stroke.draw));
    expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
  });

  // Bàn nằm trong Padding 16 px hai bên: tính kích thước theo cả bề ngang
  // thân màn thì SizedBox bị ép hẹp lại mà vẫn giữ chiều cao cũ — băng dưới
  // vẽ dày hơn hẳn. Tỉ lệ khung bàn phải đúng tỉ lệ của TableLayout.
  for (final size in const [Size(1200, 1800), Size(1280, 720)]) {
    testWidgets(
        'khung bàn giữ đúng tỉ lệ TableLayout ở '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final router = createAppRouter(auth: signedInGate());
      addTearDown(router.dispose);
      final container = testContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: PoolCoachApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go(Routes.simulator);
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byKey(SimulatorScreen.tableKey));
      expect(box.width / box.height,
          closeTo(TableLayout.aspectRatio(TableSpec.nineFoot), 0.01));
    });
  }
}
