import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

class _SpyCanvas implements Canvas {
  final circles = <(Offset, Color)>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add((c, paint.color));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const size = Size(540, 286);
  const layout = BuLayout(
    drillId: 'F1',
    source: 'BU_Exam-I_Fundamentals.pdf, trang 2',
    marks: [
      CueBall(Cham(2, 2)),
      ObjectBall(1, Cham(4, 2)),
      LadderPosition(4, Cham(3, 1)),
      LadderPosition(5, Cham(3.5, 1)),
    ],
  );

  Offset at(Cham c) =>
      const TableLayout(size: size).toCanvas(chamToTable(c, TableSpec.nineFoot));

  bool near(Offset a, Offset b) => (a - b).distance < 0.01;

  test('vẽ bi đúng chỗ của chấm', () {
    final canvas = _SpyCanvas();
    BuLayoutPainter(layout).paint(canvas, size);
    expect(canvas.circles.any((c) => near(c.$1, at(const Cham(2, 2)))), isTrue, reason: 'bi cái');
    expect(canvas.circles.any((c) => near(c.$1, at(const Cham(4, 2)))), isTrue, reason: 'bi 1');
  });

  test('tô vị trí hiện tại của thang bằng màu nhấn, vị trí khác thì không', () {
    final canvas = _SpyCanvas();
    BuLayoutPainter(layout, highlightPosition: 5).paint(canvas, size);
    final five = canvas.circles.where((c) => near(c.$1, at(const Cham(3.5, 1))));
    final four = canvas.circles.where((c) => near(c.$1, at(const Cham(3, 1))));
    expect(five.any((c) => c.$2.toARGB32() == AppColors.accent.toARGB32()), isTrue);
    expect(four.any((c) => c.$2.toARGB32() == AppColors.accent.toARGB32()), isFalse);
  });

  test('vẽ được mọi sơ đồ đã chép mà không lỗi', () {
    for (final l in allLayouts()) {
      final recorder = PictureRecorder();
      BuLayoutPainter(l, highlightPosition: 4).paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }
  });
}
