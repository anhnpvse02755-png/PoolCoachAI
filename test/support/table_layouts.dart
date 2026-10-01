import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

const tableCenter = Vec2(127, 63.5);

/// Đặt bi cái sao cho cú cắt vào [pocket] có góc đúng [degrees], bi cái
/// cách bi ảo [distance] cm. Dựng ngược từ định nghĩa, nên test không
/// phải tự tính tay toạ độ.
Vec2 cueForAngle(
  Vec2 object,
  Pocket pocket,
  double degrees, {
  double distance = 40,
}) {
  const table = TableSpec.nineFoot;
  final u = (table.pocketPosition(pocket) - object).normalized;
  final ghost = object - u * table.ballDiameter;
  final aim = u.rotated(degrees * math.pi / 180);
  return ghost - aim * distance;
}

/// Hình học của cú dựng bằng [cueForAngle]; ném lỗi nếu cú không hợp lệ.
ShotGeometry geometryFor(
  Vec2 object,
  Pocket pocket,
  double degrees, {
  double distance = 40,
}) {
  final result = evaluateShot(
    cue: cueForAngle(object, pocket, degrees, distance: distance),
    object: object,
    pocket: pocket,
  );
  return switch (result) {
    Makeable(:final geometry) => geometry,
    Unmakeable(:final reason) => throw StateError('bố cục test hỏng: $reason'),
  };
}

/// Lưới bố cục tất định phủ khắp bàn, mỗi cặp bi lấy lỗ tự chọn.
///
/// Dùng cho test tính chất: một bất biến phải đúng ở mọi chỗ trên bàn,
/// không chỉ ở vài bố cục dựng tay.
Iterable<ShotGeometry> gridShots() sync* {
  for (var cx = 20.0; cx <= 234; cx += 42) {
    for (var cy = 15.0; cy <= 112; cy += 32) {
      for (var ox = 30.0; ox <= 224; ox += 38) {
        for (var oy = 20.0; oy <= 107; oy += 29) {
          final g = bestPocket(cue: Vec2(cx, cy), object: Vec2(ox, oy));
          if (g != null) yield g;
        }
      }
    }
  }
}
