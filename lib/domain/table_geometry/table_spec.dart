import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Sáu lỗ. Mã không bao giờ dựa vào chỉ số 0–5 của PRD.
enum Pocket {
  topLeft,
  topMiddle,
  topRight,
  bottomLeft,
  bottomMiddle,
  bottomRight;

  bool get isCorner => this != topMiddle && this != bottomMiddle;
}

/// Tâm bi cái lọt vào trong bán kính này quanh điểm lỗ là chết cái, cm.
///
/// Giá trị khởi điểm, chỉnh bằng mắt trên màn mô phỏng.
const cornerCapture = 6.0;
const middleCapture = 5.0;

/// Mặt chơi bàn 9 feet, đơn vị cm, gốc ở góc trên trái.
class TableSpec {
  const TableSpec({
    this.length = 254,
    this.width = 127,
    this.ballDiameter = 5.715,
  });

  static const nineFoot = TableSpec();

  final double length;
  final double width;
  final double ballDiameter;

  double get radius => ballDiameter / 2;

  // Biên mà tâm bi chạy được — mọi điểm chạm băng nằm đúng trên biên này.
  double get minX => radius;
  double get maxX => length - radius;
  double get minY => radius;
  double get maxY => width - radius;

  bool contains(Vec2 p) =>
      p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;

  Vec2 clamp(Vec2 p) =>
      Vec2(clampRange(p.x, minX, maxX), clampRange(p.y, minY, maxY));

  Vec2 pocketPosition(Pocket pocket) => switch (pocket) {
        Pocket.topLeft => const Vec2(0, 0),
        Pocket.topMiddle => Vec2(length / 2, 0),
        Pocket.topRight => Vec2(length, 0),
        Pocket.bottomLeft => Vec2(0, width),
        Pocket.bottomMiddle => Vec2(length / 2, width),
        Pocket.bottomRight => Vec2(length, width),
      };

  double captureRadius(Pocket pocket) =>
      pocket.isCorner ? cornerCapture : middleCapture;
}
