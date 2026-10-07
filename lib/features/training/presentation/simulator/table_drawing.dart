import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Quy đổi giữa cm trên mặt bàn và pixel trên canvas.
///
/// Màn mô phỏng, màn Kế hoạch dọn bàn và test dùng chung lớp này, nên test
/// chạm đúng chỗ màn vẽ.
class TableLayout {
  const TableLayout({required this.size, this.table = TableSpec.nineFoot});

  /// Khung băng vẽ quanh mặt chơi, cm.
  static const frame = 8.0;

  static double aspectRatio(TableSpec table) =>
      (table.length + 2 * frame) / (table.width + 2 * frame);

  final Size size;
  final TableSpec table;

  double get scale => size.width / (table.length + 2 * frame);

  Offset toCanvas(Vec2 p) => Offset((p.x + frame) * scale, (p.y + frame) * scale);

  Vec2 toTable(Offset o) => Vec2(o.dx / scale - frame, o.dy / scale - frame);

  /// Chạm trong 1.5 bán kính quanh tâm bi là bắt được bi — ngón tay
  /// không phải trúng từng milimét.
  static const grabRadii = 1.5;

  /// Sàn bán kính chạm trên màn, tính bằng px logic. Trên điện thoại bàn co
  /// còn ~1.3 px/cm, nên bán kính tính theo cm chỉ còn vài px — nhỏ hơn
  /// đầu ngón tay. Lấy lớn hơn giữa bán kính cm và sàn này.
  static const minTouchPx = 24.0;

  /// Bán kính chạm theo cm: lớn hơn giữa [cm] và [minTouchPx] quy ra cm.
  double touchReach(double cm) => math.max(cm, minTouchPx / scale);

  /// Chạm cách tâm bi trong ngần này cm là bắt được bi.
  double get ballGrab => touchReach(table.radius * grabRadii);
}

const pocketDrawRadius = 5.5; // cm
const dashLength = 2.0; // cm
const dashGap = 1.5; // cm

/// Băng, mặt bàn và sáu lỗ: [selected] viền vàng, [danger] tô đỏ (chết cái),
/// [risk] vòng nét đứt (nguy cơ chết cái khi dư lực).
void drawTableBed(Canvas canvas, TableLayout layout,
    {Pocket? selected, Pocket? danger, Pocket? risk}) {
  final table = layout.table;
  final s = layout.scale;
  canvas.drawRect(Offset.zero & layout.size, Paint()..color = AppColors.tableRail);
  canvas.drawRect(
    Rect.fromPoints(
      layout.toCanvas(Vec2.zero),
      layout.toCanvas(Vec2(table.length, table.width)),
    ),
    Paint()..color = AppColors.tableFelt,
  );
  for (final pocket in Pocket.values) {
    final c = layout.toCanvas(table.pocketPosition(pocket));
    final r = pocketDrawRadius * s;
    canvas.drawCircle(
        c, r, Paint()..color = pocket == danger ? AppColors.danger : AppColors.bgDeep);
    if (pocket == selected) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent,
      );
    }
    if (pocket == risk) {
      drawDashedCircle(
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
}

void drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length < 2) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint..style = PaintingStyle.stroke);
}

/// Nét đứt theo chuỗi điểm; [scale] là px/cm để nét đứt đều theo cm.
void drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint, double scale) {
  final dash = dashLength * scale;
  final gap = dashGap * scale;
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

void drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
  const parts = 16;
  const sweep = 2 * math.pi / parts;
  final rect = Rect.fromCircle(center: center, radius: radius);
  for (var i = 0; i < parts; i += 2) {
    canvas.drawArc(rect, i * sweep, sweep, false, paint);
  }
}
