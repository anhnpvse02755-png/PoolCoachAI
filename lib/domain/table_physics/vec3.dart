import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Vector 3 chiều, bất biến: `x`, `y` như trên mặt bàn, `z` hướng lên.
///
/// Chỉ cần cho vận tốc góc: xoáy của bi có trục bất kỳ, nên không gói
/// được vào [Vec2]. Phép nhân có hướng dùng đúng một công thức ở mọi chỗ
/// (mô-men, vận tốc điểm tiếp xúc), nên vật lý nhất quán dù trục `y`
/// hướng xuống.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  /// Vector nằm ngang ứng với [v].
  Vec3.flat(Vec2 v)
      : x = v.x,
        y = v.y,
        z = 0;

  final double x;
  final double y;
  final double z;

  static const zero = Vec3(0, 0, 0);
  static const up = Vec3(0, 0, 1);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  /// Phần nằm ngang.
  Vec2 get xy => Vec2(x, y);

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
