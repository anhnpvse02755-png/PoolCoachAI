import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  group('Vec2', () {
    test('phép vector cơ bản', () {
      const a = Vec2(3, 4);
      expect(a.length, 5);
      expect(a + const Vec2(1, 1), const Vec2(4, 5));
      expect(a - const Vec2(1, 1), const Vec2(2, 3));
      expect(a * 2, const Vec2(6, 8));
      expect(-a, const Vec2(-3, -4));
      expect(a.dot(const Vec2(1, 0)), 3);
      expect(const Vec2(1, 0).cross(const Vec2(0, 1)), 1);
      expect(a.distanceTo(Vec2.zero), 5);
      expect(a.normalized.length, closeTo(1, 1e-12));
      expect(Vec2.zero.normalized, Vec2.zero);
    });

    test('bên phải khi nhìn từ trên xuống, với y hướng xuống', () {
      // Đi lên màn hình thì bên phải là hướng đông.
      expect(const Vec2(0, -1).rightNormal, const Vec2(1, 0));
      // Đi về đông thì bên phải là hướng nam (xuống màn hình).
      expect(const Vec2(1, 0).rightNormal, const Vec2(0, 1));
    });

    test('xoay và đo góc có dấu là hai phép ngược nhau', () {
      const v = Vec2(1, 0);
      expect(v.signedAngleTo(v.rotated(0.3)), closeTo(0.3, 1e-12));
      expect(v.signedAngleTo(v.rotated(-1.2)), closeTo(-1.2, 1e-12));
      expect(v.rotated(math.pi / 2).x, closeTo(0, 1e-12));
    });

    test('so sánh chính xác, không dung sai', () {
      expect(const Vec2(1, 2) == const Vec2(1, 2), isTrue);
      expect(const Vec2(1, 2) == const Vec2(1, 2.0000000001), isFalse);
    });

    test('clampRange', () {
      expect(clampRange(5, 0, 3), 3);
      expect(clampRange(-1, 0, 3), 0);
      expect(clampRange(2, 0, 3), 2);
    });
  });

  group('TableSpec', () {
    const table = TableSpec.nineFoot;

    test('biên tâm bi lùi đúng một bán kính khỏi mép', () {
      expect(table.radius, closeTo(2.8575, 1e-12));
      expect(table.minX, closeTo(2.8575, 1e-12));
      expect(table.maxX, closeTo(251.1425, 1e-12));
      expect(table.minY, closeTo(2.8575, 1e-12));
      expect(table.maxY, closeTo(124.1425, 1e-12));
    });

    test('sáu lỗ ở bốn góc và giữa hai băng dài', () {
      expect(table.pocketPosition(Pocket.topLeft), const Vec2(0, 0));
      expect(table.pocketPosition(Pocket.topMiddle), const Vec2(127, 0));
      expect(table.pocketPosition(Pocket.topRight), const Vec2(254, 0));
      expect(table.pocketPosition(Pocket.bottomLeft), const Vec2(0, 127));
      expect(table.pocketPosition(Pocket.bottomMiddle), const Vec2(127, 127));
      expect(table.pocketPosition(Pocket.bottomRight), const Vec2(254, 127));
      expect(Pocket.topMiddle.isCorner, isFalse);
      expect(Pocket.bottomRight.isCorner, isTrue);
    });

    test('contains và clamp theo biên tâm bi', () {
      expect(table.contains(const Vec2(2, 50)), isFalse);
      expect(table.contains(const Vec2(100, 50)), isTrue);
      expect(table.clamp(const Vec2(-5, 200)), Vec2(table.minX, table.maxY));
    });

    test('vùng lọt lỗ khác nhau giữa lỗ góc và lỗ giữa', () {
      expect(table.captureRadius(Pocket.topLeft), cornerCapture);
      expect(table.captureRadius(Pocket.bottomMiddle), middleCapture);
    });
  });
}
