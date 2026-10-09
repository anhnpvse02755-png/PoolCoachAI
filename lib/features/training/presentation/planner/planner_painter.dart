import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
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
    this.ghosts = const [],
    this.step,
    this.preview,
    this.zone = const [],
  });

  /// null khi chưa đặt bi cái (màn nhập bàn).
  final Vec2? cue;
  final List<PlacedBall> balls;

  /// Các bi khác còn trên bàn: vẽ rất mờ, để thấy bi chắn và bi đối thủ
  /// mà bàn không rối (PRD §6.3).
  final List<PlacedBall> ghosts;

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
  static const _ghostAlpha = 0.25;
  static const _zoneAlpha = 0.22;
  static const _railDot = 1.2; // cm
  static const _missDot = 1.4; // cm
  static const _jitterWidth = 1.2; // cm
  static const _jitterEnd = 0.8; // cm
  static const _opponentAlpha = 0.45;

  /// Bán kính vòng vàng A băng, tính theo bán kính bi.
  static const railAimRing = 1.4;
  static const _railAimWidth = 3.0;

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

    final r = layout.table.radius * s;

    // Bi mờ dưới mọi đường: một lớp nhạt cho cả nhóm, không che đường đánh.
    if (scene.ghosts.isNotEmpty) {
      canvas.saveLayer(
          null, Paint()..color = const Color(0xFF000000).withValues(alpha: _ghostAlpha));
      for (final b in scene.ghosts) {
        drawPoolBall(canvas, layout.toCanvas(b.pos), r, b.number);
      }
      canvas.restore();
    }

    final preview = scene.preview;
    if (preview != null) _shot(canvas, layout, preview, alpha: _previewAlpha, full: false);
    if (step != null) _shot(canvas, layout, step, alpha: 1, full: true);
    if (step?.safety case final shot?) _safety(canvas, layout, shot);

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

    // 4. Thanh sai số lực. Bước dự phòng không có sai số lực (jitterEnds
    // null) nên không có thanh.
    _jitterBar(canvas, layout, trace.cueEnd, step.jitterEnds);

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

  /// Thanh sai số lực: nối điểm dừng ±15 % qua điểm dừng chuẩn.
  void _jitterBar(Canvas canvas, TableLayout layout, Vec2 from, JitterEnds? ends) {
    if (ends == null) return;
    final s = layout.scale;
    final bar = Paint()
      ..color = AppColors.railHit.withValues(alpha: 0.8)
      ..strokeWidth = _jitterWidth * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final end in [ends.minus, ends.plus]) {
      if (end == null) continue;
      canvas.drawLine(layout.toCanvas(from), layout.toCanvas(end), bar);
      canvas.drawCircle(layout.toCanvas(end), _jitterEnd * s, Paint()..color = AppColors.railHit);
    }
  }

  /// Cú thủ (spec cú phòng thủ 5.1), từ dưới lên. Mọi đường là chuỗi điểm của
  /// mô phỏng. Thứ tự lớp theo spec: đường đỏ của đối thủ nằm trên đường của
  /// mình để không bị che.
  void _safety(Canvas canvas, TableLayout layout, SafetyShot shot) {
    final s = layout.scale;
    final r = layout.table.radius * s;
    final trace = shot.aimed.trace;
    List<Offset> px(List<Vec2> pts) => [for (final p in pts) layout.toCanvas(p)];

    // 2. Bi cái đúng từ mô phỏng.
    drawDashedPolyline(
        canvas, px(trace.cueBefore), Paint()..color = AppColors.aimLine..strokeWidth = 1.5, s);
    drawDashedPolyline(
        canvas, px(trace.cueAfter), Paint()..color = AppColors.cuePath..strokeWidth = 2, s);
    for (final hit in trace.rails) {
      if (hit.ball != ShotBall.cue) continue;
      canvas.drawCircle(layout.toCanvas(hit.pos), _railDot * s, Paint()..color = AppColors.railHit);
    }
    if (trace.cuePocket == null) {
      drawDashedCircle(
          canvas,
          layout.toCanvas(trace.cueEnd),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.ballCue);
    }

    // 3. A băng: vòng vàng đậm ở điểm ngắm trên băng đầu, số chấm ở mép bàn.
    // Dựa vào railAim, không dựa vào lý do thủ: bàn không đui cũng có thể A băng.
    final aim = shot.railAim;
    if (aim != null) {
      canvas.drawCircle(
          layout.toCanvas(aim.at),
          railAimRing * r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _railAimWidth
            ..color = AppColors.railHit);
      _diamondNumbers(canvas, layout);
    }

    // 4. Bi hợp lệ sau va chạm và chỗ nó dừng.
    drawPolyline(canvas, px(trace.objectPath),
        Paint()..color = AppColors.textSecondary..strokeWidth = 1.5);
    if (trace.objectPath.isNotEmpty) {
      drawDashedCircle(
          canvas,
          layout.toCanvas(trace.objectPath.last),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.textSecondary);
    }

    // 5. Cú dễ nhất của đối thủ, mờ đỏ, trên các đường của mình.
    final opp = Paint()
      ..color = AppColors.danger.withValues(alpha: _opponentAlpha)
      ..strokeWidth = 1.5;
    final view = shot.opponent;
    final easiest = view.easiest;
    if (easiest != null) {
      canvas.drawLine(layout.toCanvas(easiest.cue), layout.toCanvas(easiest.ghost), opp);
      canvas.drawLine(layout.toCanvas(easiest.object),
          layout.toCanvas(layout.table.pocketPosition(easiest.pocket)), opp);
    } else if (view.snookered) {
      final ball = view.ball;
      if (ball != null) {
        drawDashedPolyline(
            canvas, [layout.toCanvas(trace.cueEnd), layout.toCanvas(ball.pos)], opp, s);
        _label(canvas, layout.toCanvas(trace.cueEnd) + Offset(0, -2.4 * r),
            Vi.safetyOpponentSnookered, r, AppColors.danger);
      }
    }

    // 6. Thanh sai số lực.
    _jitterBar(canvas, layout, trace.cueEnd, shot.jitterEnds);
  }

  /// Số chấm trên khung bàn: băng dài 0–8 từ góc trái, băng ngắn 0–4 từ góc trên.
  void _diamondNumbers(Canvas canvas, TableLayout layout) {
    final t = layout.table;
    const f = TableLayout.frame;
    final size = math.max(8.0, f * 0.55 * layout.scale);
    void put(int n, Vec2 at) =>
        _label(canvas, layout.toCanvas(at), '$n', size / 0.8, AppColors.textPrimary);
    for (var i = 0; i <= longRailDiamonds; i++) {
      final x = t.length * i / longRailDiamonds;
      put(i, Vec2(x, -f / 2));
      put(i, Vec2(x, t.width + f / 2));
    }
    for (var j = 0; j <= shortRailDiamonds; j++) {
      final y = t.width * j / shortRailDiamonds;
      put(j, Vec2(-f / 2, y));
      put(j, Vec2(t.length + f / 2, y));
    }
  }

  /// Chữ căn giữa tại [center], cỡ theo bán kính [radius] px như số trên bi.
  void _label(Canvas canvas, Offset center, String text, double radius, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
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
