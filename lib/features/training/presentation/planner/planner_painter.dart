import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/planner/ball_colors.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Mọi thứ cần vẽ của một khung hình màn Kế hoạch dọn bàn — đã tính xong.
class PlannerScene {
  const PlannerScene({
    this.cue,
    this.balls = const [],
    this.step,
    this.preview,
    this.zone = const [],
  });

  /// null khi chưa đặt bi cái (màn nhập bàn).
  final Vec2? cue;
  final List<PlacedBall> balls;

  /// Bước đang xem: vẽ đủ lớp.
  final PlanStep? step;

  /// Bước kế tiếp: vẽ mờ để xem trước.
  final PlanStep? preview;
  final List<ZoneCell> zone;
}

/// Vẽ bàn theo spec 2026-10-07 mục 7.1, từ dưới lên. Mọi đường cong là
/// chuỗi điểm của mô phỏng — không vẽ đường cong tự chế.
class PlannerPainter extends CustomPainter {
  PlannerPainter(this.scene);

  final PlannerScene scene;

  static const _previewAlpha = 0.45;
  static const _zoneAlpha = 0.22;
  static const _railDot = 1.2; // cm
  static const _missDot = 1.4; // cm
  static const _jitterWidth = 1.2; // cm
  static const _jitterEnd = 0.8; // cm

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final s = layout.scale;
    final step = scene.step;
    drawTableBed(canvas, layout, selected: step?.pocket, danger: step?.trace?.cuePocket);

    // 1. Vùng điều, dưới cùng: không che bi hay đường.
    for (final cell in scene.zone) {
      final color = cell.level == ZoneLevel.good ? AppColors.success : AppColors.warning;
      canvas.drawRect(
        Rect.fromCenter(
            center: layout.toCanvas(cell.center), width: zoneCell * s, height: zoneCell * s),
        Paint()..color = color.withValues(alpha: _zoneAlpha),
      );
    }

    final preview = scene.preview;
    if (preview != null) _shot(canvas, layout, preview, alpha: _previewAlpha, full: false);
    if (step != null) _shot(canvas, layout, step, alpha: 1, full: true);

    final r = layout.table.radius * s;
    for (final b in scene.balls) {
      drawPoolBall(canvas, layout.toCanvas(b.pos), r, b.number);
    }
    final cue = scene.cue;
    if (cue != null) {
      canvas.drawCircle(layout.toCanvas(cue), r, Paint()..color = AppColors.ballCue);
    }
  }

  void _shot(Canvas canvas, TableLayout layout, PlanStep step,
      {required double alpha, required bool full}) {
    final trace = step.trace;
    final g = step.geometry;
    if (trace == null || g == null) return;
    final s = layout.scale;
    final r = layout.table.radius * s;
    List<Offset> px(List<Vec2> pts) => [for (final p in pts) layout.toCanvas(p)];

    // 2. Đường ngắm, bi ảo, đường bi mục tiêu vào lỗ (lỗ đã chọn có vòng vàng).
    canvas.drawLine(
      layout.toCanvas(step.cbFrom),
      layout.toCanvas(g.ghost),
      Paint()
        ..color = AppColors.aimLine.withValues(alpha: 0.35 * alpha)
        ..strokeWidth = 1,
    );
    if (full) {
      drawDashedCircle(
        canvas,
        layout.toCanvas(trace.contactCue ?? g.ghost),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.aimLine,
      );
    }
    drawPolyline(
      canvas,
      px(trace.objectPath),
      Paint()
        ..color = AppColors.textSecondary.withValues(alpha: alpha)
        ..strokeWidth = 1.5,
    );

    // 3. Bi cái đúng từ mô phỏng: trước va chạm nét đứt trắng, sau va chạm
    // nét đứt ngọc — cong chỗ cong.
    drawDashedPolyline(
      canvas,
      px(trace.cueBefore),
      Paint()
        ..color = AppColors.aimLine.withValues(alpha: alpha)
        ..strokeWidth = 1.5,
      s,
    );
    drawDashedPolyline(
      canvas,
      px(trace.cueAfter),
      Paint()
        ..color = AppColors.cuePath.withValues(alpha: alpha)
        ..strokeWidth = 2,
      s,
    );
    if (!full) return;

    for (final hit in trace.rails) {
      if (hit.ball != ShotBall.cue || !hit.afterContact) continue;
      canvas.drawCircle(
          layout.toCanvas(hit.pos), _railDot * s, Paint()..color = AppColors.railHit);
    }
    if (trace.cuePocket == null) {
      drawDashedCircle(
        canvas,
        layout.toCanvas(trace.cueEnd),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.ballCue,
      );
    }

    // 4. Thanh sai số lực: nối điểm dừng ±15 % qua điểm dừng chuẩn. Bước dự
    // phòng không có sai số lực (jitterEnds null) nên không có thanh.
    final ends = step.jitterEnds;
    if (ends != null) {
      final bar = Paint()
        ..color = AppColors.railHit.withValues(alpha: 0.8)
        ..strokeWidth = _jitterWidth * s
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final end in [ends.minus, ends.plus]) {
        if (end == null) continue;
        canvas.drawLine(layout.toCanvas(trace.cueEnd), layout.toCanvas(end), bar);
        canvas.drawCircle(
            layout.toCanvas(end), _jitterEnd * s, Paint()..color = AppColors.railHit);
      }
    }

    // 5. Hai điểm "nếu trượt", chấm đặc là hướng được khuyên.
    final miss = step.missAdvice;
    if (miss != null) {
      for (final side in MissSide.values) {
        canvas.drawCircle(
          layout.toCanvas(side == MissSide.thick ? miss.thick : miss.thin),
          _missDot * s,
          Paint()
            ..color = AppColors.warning
            ..strokeWidth = 1.5
            ..style = side == miss.safer ? PaintingStyle.fill : PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PlannerPainter oldDelegate) => oldDelegate.scene != scene;
}

/// Bi đúng màu bi thật, có số (spec mục 6).
void drawPoolBall(Canvas canvas, Offset center, double radius, int number) {
  final color = ballColor(number);
  if (isStripe(number)) {
    canvas.drawCircle(center, radius, Paint()..color = AppColors.ballCue);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawRect(
        Rect.fromCenter(center: center, width: 2 * radius, height: 1.1 * radius),
        Paint()..color = color);
    canvas.restore();
  } else {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }
  canvas.drawCircle(center, radius * 0.55, Paint()..color = AppColors.ballCue);
  final label = TextPainter(
    text: TextSpan(
      text: '$number',
      style: TextStyle(
          color: const Color(0xFF111111), fontSize: radius * 0.8, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
}

/// Viền đứt cho ô XEM TRƯỚC.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    drawDashedPolyline(
      canvas,
      [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft, r.topLeft],
      Paint()
        ..color = AppColors.borderStrong
        ..strokeWidth = 1,
      3,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => false;
}
