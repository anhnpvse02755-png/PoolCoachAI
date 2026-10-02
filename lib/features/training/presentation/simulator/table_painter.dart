import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Quy đổi giữa cm trên mặt bàn và pixel trên canvas.
///
/// Màn và test dùng chung lớp này, nên test chạm đúng chỗ màn vẽ.
class TableLayout {
  const TableLayout({required this.size, this.table = TableSpec.nineFoot});

  /// Khung băng vẽ quanh mặt chơi, cm.
  static const frame = 8.0;

  static double aspectRatio(TableSpec table) =>
      (table.length + 2 * frame) / (table.width + 2 * frame);

  final Size size;
  final TableSpec table;

  double get scale => size.width / (table.length + 2 * frame);

  Offset toCanvas(Vec2 p) =>
      Offset((p.x + frame) * scale, (p.y + frame) * scale);

  Vec2 toTable(Offset o) => Vec2(o.dx / scale - frame, o.dy / scale - frame);
}

/// Mọi thứ cần vẽ của một khung hình — đã tính xong từ lõi.
class SimulatorScene {
  const SimulatorScene({
    required this.cue,
    required this.object,
    this.pocket,
    this.geometry,
    this.aimed,
    this.showUncompensated = false,
    this.riskPocket,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Lỗ đang dùng (tự chọn hoặc người chơi chạm).
  final Pocket? pocket;
  final ShotGeometry? geometry;

  /// Cú đánh đã dò và mô phỏng; null khi không đánh được, hoặc khi lõi
  /// không mô phỏng được (khi đó chỉ vẽ hình học của [geometry]).
  final AimedShot? aimed;

  /// Công tắc *Xem nếu không bù ném* đang bật (và đang có ném).
  final bool showUncompensated;

  /// Lỗ có nguy cơ chết cái khi dư lực — vẽ vòng nét đứt.
  final Pocket? riskPocket;
}

/// Vẽ bàn theo spec 2026-10-02 mục 6.2, từ dưới lên.
class TablePainter extends CustomPainter {
  TablePainter(this.scene);

  final SimulatorScene scene;

  static const _pocketDrawRadius = 5.5; // cm
  static const _dash = 2.0; // cm
  static const _gap = 1.5; // cm
  static const _railDot = 1.2; // cm
  static const _ghostDot = 0.8; // cm

  /// Bi ảo đã bù lệch khỏi Bi ảo hình học quá mức này (cm) thì chấm thêm
  /// chỗ hình học, để thấy bù ném dời điểm chạm bao nhiêu.
  static const _ghostShift = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final table = layout.table;
    final s = layout.scale;
    final aimed = scene.aimed;
    final trace = aimed?.trace;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.tableRail);
    canvas.drawRect(
      Rect.fromPoints(
        layout.toCanvas(Vec2.zero),
        layout.toCanvas(Vec2(table.length, table.width)),
      ),
      Paint()..color = AppColors.tableFelt,
    );

    for (final pocket in Pocket.values) {
      final c = layout.toCanvas(table.pocketPosition(pocket));
      final r = _pocketDrawRadius * s;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = trace?.cuePocket == pocket
              ? AppColors.danger
              : AppColors.bgDeep,
      );
      if (pocket == scene.pocket) {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.accent,
        );
      }
      if (pocket == scene.riskPocket) {
        _dashedCircle(
          canvas,
          c,
          r + 2 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.warning,
        );
      }
    }

    final g = scene.geometry;
    // 1. Đường ngắm hình học (bi cái → Bi ảo hình học): vạch mờ. Vẽ cả
    // khi lõi không mô phỏng được cú này (quá maxSimTime): còn hình học.
    if (g != null) {
      canvas.drawLine(
        layout.toCanvas(scene.cue),
        layout.toCanvas(g.ghost),
        Paint()
          ..color = AppColors.aimLine.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      if (trace == null) {
        _dashedCircle(
          canvas,
          layout.toCanvas(g.ghost),
          table.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.aimLine,
        );
      }
    }
    if (g != null && aimed != null && trace != null) {
      List<Offset> px(List<Vec2> pts) =>
          [for (final p in pts) layout.toCanvas(p)];

      // 2. Bi cái tới bi mục tiêu: nét đứt trắng — thấy bi cái bị lệch
      // do áp phê và swerve.
      _dashedPolyline(
        canvas,
        px(trace.cueBefore),
        Paint()
          ..color = AppColors.aimLine
          ..strokeWidth = 1.5,
        s,
      );

      // 3. Bi ảo đã bù: vòng nét đứt; lệch xa Bi ảo hình học thì chấm
      // mờ chỗ hình học.
      final contact = trace.contactCue;
      if (contact != null) {
        _dashedCircle(
          canvas,
          layout.toCanvas(contact),
          table.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.aimLine,
        );
        if (contact.distanceTo(g.ghost) > _ghostShift) {
          canvas.drawCircle(layout.toCanvas(g.ghost), _ghostDot * s,
              Paint()..color = AppColors.aimLine.withValues(alpha: 0.4));
        }
      }

      // 8. Bật công tắc: đường bi mục tiêu nếu không bù ném, đỏ mờ. Vẽ
      // trước đường thật để không che nó.
      final red = aimed.uncompensated;
      if (scene.showUncompensated && red != null) {
        _polyline(
          canvas,
          px(red.objectPath),
          Paint()
            ..color = AppColors.danger.withValues(alpha: 0.55)
            ..strokeWidth = 2,
        );
      }

      // 4. Bi mục tiêu: nét liền.
      _polyline(
        canvas,
        px(trace.objectPath),
        Paint()
          ..color = AppColors.textSecondary
          ..strokeWidth = 1.5,
      );

      // 5. Bi cái sau va chạm: nét đứt màu ngọc, đúng chuỗi điểm của
      // mô phỏng — chỗ cong là cong thật.
      _dashedPolyline(
        canvas,
        px(trace.cueAfter),
        Paint()
          ..color = AppColors.cuePath
          ..strokeWidth = 2,
        s,
      );

      // 6. Mỗi lần bi cái chạm băng sau va chạm: chấm vàng. Cú dò không
      // hội tụ có thể dội băng trước khi chạm bi; chấm đó không dòng nào
      // giải thích, vì "Bi cái chạm băng N lần" chỉ đếm sau va chạm.
      for (final hit in trace.rails) {
        if (hit.ball != ShotBall.cue || !hit.afterContact) continue;
        canvas.drawCircle(layout.toCanvas(hit.pos), _railDot * s,
            Paint()..color = AppColors.railHit);
      }

      // 7. Điểm dừng bi cái: vòng trắng cỡ bi. Chết cái thì lỗ đã tô đỏ.
      if (trace.cuePocket == null) {
        canvas.drawCircle(
          layout.toCanvas(trace.cueEnd),
          table.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.ballCue,
        );
      }
    }

    canvas.drawCircle(layout.toCanvas(scene.object), table.radius * s,
        Paint()..color = AppColors.ballObject);
    canvas.drawCircle(layout.toCanvas(scene.cue), table.radius * s,
        Paint()..color = AppColors.ballCue);
  }

  void _polyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  void _dashedPolyline(
      Canvas canvas, List<Offset> points, Paint paint, double scale) {
    final dash = _dash * scale;
    final gap = _gap * scale;
    var drawing = true;
    var left = dash;
    for (var i = 0; i + 1 < points.length; i++) {
      final start = points[i];
      final delta = points[i + 1] - start;
      final len = delta.distance;
      if (len == 0) continue;
      final dir = delta / len;
      var at = 0.0;
      while (at < len) {
        final step = math.min(left, len - at);
        if (drawing) {
          canvas.drawLine(start + dir * at, start + dir * (at + step), paint);
        }
        at += step;
        left -= step;
        if (left <= 0) {
          drawing = !drawing;
          left = drawing ? dash : gap;
        }
      }
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const parts = 16;
    const sweep = 2 * math.pi / parts;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < parts; i += 2) {
      canvas.drawArc(rect, i * sweep, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(TablePainter oldDelegate) => oldDelegate.scene != scene;
}
