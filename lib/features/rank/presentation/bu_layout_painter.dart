import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart'
    show drawPoolBall;
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Vẽ một sơ đồ BU lên mặt bàn của Kế hoạch dọn bàn (spec mục 5.5).
///
/// Thứ tự từ dưới lên: mặt bàn và số chấm, vùng đích và đường đi, vị trí
/// thang, rồi bi — bi luôn nằm trên cùng.
class BuLayoutPainter extends CustomPainter {
  BuLayoutPainter(this.layout, {this.highlightPosition});

  final BuLayout layout;

  /// Vị trí thang đang đứng (F1–F5), tô màu nhấn.
  final int? highlightPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final l = TableLayout(size: size);
    final t = l.table;
    final r = t.radius * l.scale;
    Offset at(Cham c) => l.toCanvas(chamToTable(c, t));

    final pocket = layout.marks.whereType<TargetPocket>().firstOrNull?.pocket;
    drawTableBed(canvas, l, selected: pocket);
    drawDiamondNumbers(canvas, l);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.textPrimary;

    for (final m in layout.marks) {
      switch (m) {
        case TargetZone(:final from, :final to):
          canvas.drawRect(Rect.fromPoints(at(from), at(to)), line);
        case AimPath(:final points, :final dashed):
          final px = [for (final p in points) at(p)];
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.aimLine;
          dashed ? drawDashedPolyline(canvas, px, paint, l.scale) : drawPolyline(canvas, px, paint);
        case SpotRing(at: final c):
          canvas.drawCircle(at(c), r * 0.6, line);
        default:
          break;
      }
    }

    for (final m in layout.marks) {
      if (m case LadderPosition(:final position, at: final c)) {
        final on = position == highlightPosition;
        canvas.drawCircle(
          at(c),
          r * 0.9,
          Paint()
            ..style = on ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = on ? AppColors.accent : AppColors.textMuted,
        );
        drawCenteredLabel(canvas, at(c), '$position', r,
            on ? AppColors.bgDeep : AppColors.textPrimary);
      }
    }

    for (final m in layout.marks) {
      switch (m) {
        case CueBall(at: final c):
          canvas.drawCircle(at(c), r, Paint()..color = AppColors.ballCue);
        case ObjectBall(:final number, at: final c):
          drawPoolBall(canvas, at(c), r, number);
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(BuLayoutPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.highlightPosition != highlightPosition;
}

/// Mặt bàn đúng tỉ lệ bàn 9 feet, vẽ một sơ đồ.
class BuLayoutView extends StatelessWidget {
  const BuLayoutView({
    required this.layout,
    this.highlightPosition,
    this.semanticLabel,
    super.key,
  });

  final BuLayout layout;
  final int? highlightPosition;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: AspectRatio(
        aspectRatio: TableLayout.aspectRatio(TableSpec.nineFoot),
        child: CustomPaint(
          painter: BuLayoutPainter(layout, highlightPosition: highlightPosition),
        ),
      ),
    );
  }
}
