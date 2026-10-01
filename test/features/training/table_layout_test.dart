import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

void main() {
  const table = TableSpec.nineFoot;
  // (254 + 16) × (127 + 16) cm ở tỉ lệ 2 px/cm.
  const layout = TableLayout(size: Size(540, 286));

  test('khung băng vẽ quanh mặt chơi', () {
    expect(layout.scale, 2);
    expect(layout.toCanvas(const Vec2(-TableLayout.frame, -TableLayout.frame)),
        Offset.zero);
    expect(
      layout.toCanvas(Vec2(table.length + TableLayout.frame,
          table.width + TableLayout.frame)),
      const Offset(540, 286),
    );
    expect(TableLayout.aspectRatio(table), closeTo(540 / 286, 1e-12));
  });

  test('đổi qua đổi lại giữa cm và pixel', () {
    const p = Vec2(123.5, 45.25);
    final back = layout.toTable(layout.toCanvas(p));
    expect(back.distanceTo(p), lessThan(1e-9));
  });
}
