import 'dart:math' as math;

/// Kẹp [v] vào đoạn [lo, hi].
double clampRange(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Điểm hay vector trên mặt bàn, đơn vị cm, y hướng xuống.
///
/// `==` so sánh chính xác, không dung sai: bất biến `landingPos ==
/// cbFrom` của Planner dựa vào việc truyền thẳng cùng một giá trị cho
/// bước sau, không tính lại.
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 other) => x * other.x + y * other.y;
  double cross(Vec2 other) => x * other.y - y * other.x;
  double get length => math.sqrt(x * x + y * y);
  double distanceTo(Vec2 other) => (this - other).length;
  bool get isZero => x == 0 && y == 0;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  /// Bên phải của vector khi nhìn bàn từ trên xuống.
  ///
  /// Với y hướng xuống, quay vector 90° theo chiều kim đồng hồ trên màn
  /// hình là `(-y, x)`. Áp phê dùng hướng này để biết băng đẩy bi về
  /// phía nào.
  Vec2 get rightNormal => Vec2(-y, x);

  Vec2 rotated(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  /// Góc có dấu từ vector này tới [other], radian, cùng chiều với [rotated].
  double signedAngleTo(Vec2 other) => math.atan2(cross(other), dot(other));

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
