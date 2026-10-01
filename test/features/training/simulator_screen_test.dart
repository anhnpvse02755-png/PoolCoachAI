import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/test_data.dart';

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5. Mọi con số mong đợi lấy
/// từ chính lõi table_geometry, không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  final initial = bestPocket(
    cue: SimulatorScreen.initialCue,
    object: SimulatorScreen.initialObject,
  )!;

  Future<void> openSimulator(WidgetTester tester) async {
    // Đủ cao để cả bàn lẫn bảng thông tin nằm trong màn.
    tester.view.physicalSize = const Size(1200, 1800);
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

  testWidgets('áp phê mà không chạm băng thì nói thẳng là không đổi đường đi',
      (tester) async {
    final path = simulateCueBall(initial, stroke: Stroke.stun, power: 70);
    expect(path.bankUsed, isFalse,
        reason: 'bố cục mở màn phải không dội băng để test này có nghĩa');
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.right, 1)));

    expect(find.text(Vi.simSpinNoRail), findsOneWidget);
  });

  testWidgets('lệch 2 đầu cơ thì cảnh báo trượt cơ', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.left, 2)));

    expect(find.text(Vi.simMiscue), findsOneWidget);
  });

  testWidgets('bàn có nhãn semantics tóm tắt cú đánh', (tester) async {
    final handle = tester.ensureSemantics();
    await openSimulator(tester);

    final path = simulateCueBall(initial, stroke: Stroke.stun, power: 70);
    expect(find.bySemanticsLabel(Vi.simSummary(Makeable(initial), path)),
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
