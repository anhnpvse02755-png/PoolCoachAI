import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_panel_layout.dart';

import '../../support/layout_sweep.dart';

void main() {
  final ar = TableLayout.aspectRatio(TableSpec.nineFoot);

  // Thân màn là phần dưới thanh tiêu đề: điện thoại 740×360 có thanh bên
  // còn khoảng 660×304, cửa sổ 1280×800 còn khoảng 1200×744.
  test('điện thoại dọc: bàn trên, bàn rộng hết thân màn', () {
    final a = TablePanelLayout.arrange(const Size(360, 560), ar);
    expect(a.sideBySide, isFalse);
    expect(a.table.width, closeTo(360 - 32, 0.01));
    expect(a.table.width / a.table.height, closeTo(ar, 1e-9));
  });

  test('xếp chồng vẫn giữ trần 55% chiều cao như cũ', () {
    final a = TablePanelLayout.arrange(const Size(590, 400), ar);
    expect(a.sideBySide, isFalse); // hẹp hơn 600
    expect(a.table.height, closeTo(400 * 0.55 - 24, 0.01));
  });

  test('điện thoại ngang: bàn trái, bảng phải rộng 320', () {
    final a = TablePanelLayout.arrange(const Size(660, 304), ar);
    expect(a.sideBySide, isTrue);
    expect(a.panelWidth, 320);
    expect(
      a.table.width,
      closeTo(math.min(660 - 320 - 32, (304 - 32) * ar), 0.01),
    );
  });

  test('máy tính: bảng phải rộng 440', () {
    final a = TablePanelLayout.arrange(const Size(1200, 744), ar);
    expect(a.sideBySide, isTrue);
    expect(a.panelWidth, 440);
    expect(
      a.table.width,
      closeTo(math.min(1200 - 440 - 32, (744 - 32) * ar), 0.01),
    );
  });

  test('máy tính bảng dọc và cửa sổ gần vuông vẫn xếp chồng', () {
    expect(
      TablePanelLayout.arrange(const Size(720, 1224), ar).sideBySide,
      isFalse,
    );
    expect(
      TablePanelLayout.arrange(const Size(900, 800), ar).sideBySide,
      isFalse,
    );
  });

  Future<void> pumpLayout(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TablePanelLayout(
          table: TableSpec.nineFoot,
          tableBuilder: (_) => const SizedBox.expand(key: Key('bàn')),
          panel: const SizedBox(key: Key('bảng'), height: 2000),
        ),
      ),
    ),
  );

  testWidgets('thân ngang: bảng bên phải bàn, cuộn bảng không kéo bàn theo', (
    tester,
  ) async {
    applyScreen(tester, const Size(740, 360));
    await pumpLayout(tester);
    expect(tester.takeException(), isNull);
    final table = find.byKey(const Key('bàn'));
    expect(
      tester.getTopLeft(find.byKey(const Key('bảng'))).dx,
      greaterThanOrEqualTo(tester.getTopRight(table).dx),
    );
    final size = tester.getSize(table);
    expect(size.width / size.height, closeTo(ar, 0.01));
    final top = tester.getTopLeft(table).dy;
    await tester.drag(find.byKey(const Key('bảng')), const Offset(0, -500));
    await tester.pump();
    expect(tester.getTopLeft(table).dy, top);
  });

  testWidgets('thân dọc: bảng nằm dưới bàn', (tester) async {
    applyScreen(tester, const Size(360, 640));
    await pumpLayout(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('bảng'))).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byKey(const Key('bàn'))).dy,
      ),
    );
  });
}
