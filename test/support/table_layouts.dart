import 'dart:math' as math;

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
