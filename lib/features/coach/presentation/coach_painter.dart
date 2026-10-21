import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Lỗ người chơi chạm vào: lỗ gần điểm chạm nhất trong vùng chạm của nó
/// (lớn hơn giữa bán kính lỗ vẽ và [TableLayout.minTouchPx]); null khi chạm
/// ngoài mọi vùng (spec mục 4.3).
Pocket? pocketAt(Vec2 p, TableLayout layout) {
  final reach = layout.touchReach(pocketDrawRadius);
  Pocket? best;
  var bestDistance = double.infinity;
  for (final pocket in Pocket.values) {
    final d = p.distanceTo(layout.table.pocketPosition(pocket));
    if (d <= reach && d < bestDistance) {
      best = pocket;
      bestDistance = d;
    }
  }
  return best;
}

/// Mọi thứ cần vẽ của bàn tình huống.
class CoachScene {
  const CoachScene({
    required this.setup,
    required this.target,
    this.pocket,
    this.playerTrace,
    this.answer,
    this.zone = const [],
  });

  final TableSetup setup;

  /// Bi phải chạm: có vòng sáng.
  final int target;

  /// Lỗ người chơi đã chọn: vòng vàng.
  final Pocket? pocket;

  /// Đường đi mô phỏng của chính cú người chơi chọn.
  final ShotTrace? playerTrace;

  /// Bước của đáp án: vẽ y như màn từng bước của Planner; đường của người
  /// chơi khi đó vẽ mờ.
  final PlanStep? answer;
  final List<ZoneCell> zone;
}

/// Bàn tình huống: bọc [PlannerPainter] (bàn, vùng điều, mọi bi đúng màu, cú
/// đáp án), thêm vòng bi phải chạm, vòng lỗ đã chọn và đường cú người chơi.
class CoachPainter extends CustomPainter {
  CoachPainter(this.scene);

  final CoachScene scene;

  static const _fadedAlpha = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size, table: scene.setup.table);
    final s = layout.scale;
    final r = layout.table.radius * s;
    final answer = scene.answer;
    PlannerPainter(PlannerScene(
      cue: scene.setup.cue,
      balls: scene.setup.balls,
      step: answer,
      zone: scene.zone,
    )).paint(canvas, size);

    final pocket = scene.pocket;
    if (pocket != null && answer == null) {
      canvas.drawCircle(
        layout.toCanvas(layout.table.pocketPosition(pocket)),
        pocketDrawRadius * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.accent,
      );
    }

    final trace = scene.playerTrace;
    if (trace != null) {
      final alpha = answer == null ? 1.0 : _fadedAlpha;
      List<Offset> px(List<Vec2> pts) => [for (final p in pts) layout.toCanvas(p)];
      drawDashedPolyline(canvas, px(trace.cueBefore),
          Paint()..color = AppColors.aimLine.withValues(alpha: alpha)..strokeWidth = 1.5, s);
      drawDashedPolyline(canvas, px(trace.cueAfter),
          Paint()..color = AppColors.cuePath.withValues(alpha: alpha)..strokeWidth = 2, s);
      drawPolyline(canvas, px(trace.objectPath),
          Paint()..color = AppColors.textSecondary.withValues(alpha: alpha)..strokeWidth = 1.5);
      final scratch = trace.cuePocket;
      if (scratch != null) {
        canvas.drawCircle(layout.toCanvas(layout.table.pocketPosition(scratch)), pocketDrawRadius * s,
            Paint()..color = AppColors.danger.withValues(alpha: 0.6 * alpha));
      } else {
        // Vòng trắng ở chỗ bi cái dừng — gợi ý 1 hỏi "từ vòng trắng…".
        drawDashedCircle(
            canvas,
            layout.toCanvas(trace.cueEnd),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = AppColors.ballCue.withValues(alpha: alpha));
      }
    }

    // Vòng sáng quanh bi phải chạm.
    final target = scene.setup.balls.where((b) => b.number == scene.target).firstOrNull;
    if (target != null) {
      canvas.drawCircle(
        layout.toCanvas(target.pos),
        r * 1.45,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(CoachPainter oldDelegate) => true;
}
