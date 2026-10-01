import 'dart:math' as math;

// `Curve` ở đây là PathSegment của lõi, không phải animation curve —
// ẩn tên đó khỏi material.dart để khỏi đụng độ.
import 'package:flutter/material.dart' hide Curve;
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

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
    this.path,
    this.riskPocket,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Lỗ đang dùng (tự chọn hoặc người chơi chạm).
  final Pocket? pocket;
  final ShotGeometry? geometry;
  final CueBallPath? path;

  /// Lỗ có nguy cơ chết cái khi dư lực — vẽ vòng nét đứt.
  final Pocket? riskPocket;
}

/// Vẽ bàn theo PRD §6.5.
class TablePainter extends CustomPainter {
  TablePainter(this.scene);

  final SimulatorScene scene;

  static const _pocketDrawRadius = 5.5; // cm
  static const _dash = 2.0; // cm
  static const _gap = 1.5; // cm
  static const _railDot = 1.2; // cm

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final table = layout.table;
    final s = layout.scale;

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
          ..color = scene.path?.scratch == pocket
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
    if (g != null) {
      final aim = Paint()
        ..color = AppColors.aimLine
        ..strokeWidth = 1.5;
      _dashedPolyline(
          canvas, [layout.toCanvas(scene.cue), layout.toCanvas(g.ghost)], aim, s);
      canvas.drawLine(
        layout.toCanvas(g.object),
        layout.toCanvas(table.pocketPosition(g.pocket)),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 1,
      );
      // Bi ảo: chỉ có viền.
      canvas.drawCircle(
        layout.toCanvas(g.ghost),
        table.radius * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.aimLine,
      );

      final path = scene.path;
      if (path != null) {
        final teal = Paint()
          ..color = AppColors.cuePath
          ..strokeWidth = 2;
        for (final seg in path.segments) {
          _dashedPolyline(
              canvas, _sample(seg).map(layout.toCanvas).toList(), teal, s);
        }
        final hit = path.railHit;
        if (hit != null) {
          canvas.drawCircle(layout.toCanvas(hit), _railDot * s,
              Paint()..color = AppColors.railHit);
        }
      }
    }

    canvas.drawCircle(layout.toCanvas(scene.object), table.radius * s,
        Paint()..color = AppColors.ballObject);
    canvas.drawCircle(layout.toCanvas(scene.cue), table.radius * s,
        Paint()..color = AppColors.ballCue);
  }

  List<Vec2> _sample(PathSegment seg) => switch (seg) {
        Straight() => [seg.start, seg.end],
        Curve() => [for (var i = 0; i <= 24; i++) seg.pointAt(i / 24)],
      };

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
