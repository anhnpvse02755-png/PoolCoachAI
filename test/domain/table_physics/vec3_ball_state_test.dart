import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;

  group('Vec3', () {
    test('phép vector cơ bản', () {
      const a = Vec3(1, 2, 3);
      expect(a + const Vec3(1, 1, 1), const Vec3(2, 3, 4));
      expect(a - const Vec3(1, 1, 1), const Vec3(0, 1, 2));
      expect(a * 2, const Vec3(2, 4, 6));
      expect(-a, const Vec3(-1, -2, -3));
      expect(a.dot(const Vec3(1, 0, 1)), 4);
      expect(const Vec3(2, 3, 6).length, 7);
      expect(a.xy, const Vec2(1, 2));
      expect(Vec3.flat(const Vec2(4, 5)), const Vec3(4, 5, 0));
    });

    test('tích có hướng theo công thức thành phần chuẩn', () {
      const x = Vec3(1, 0, 0);
      const y = Vec3(0, 1, 0);
      expect(x.cross(y), Vec3.up);
      expect(y.cross(Vec3.up), x);
      expect(Vec3.up.cross(x), y);
      expect(y.cross(x), -Vec3.up);
      expect(x.cross(x), Vec3.zero);
    });
  });

  group('BallState', () {
    test('lăn đều thì điểm chạm khăn không trượt', () {
      const vel = Vec2(120, -40);
      // Xoáy lăn đều là ẑ × v / R.
      final rolling = BallState(
        pos: const Vec2(50, 50),
        vel: vel,
        spin: Vec3.up.cross(Vec3.flat(vel)) * (1 / radius),
      );
      expect(rolling.slip(radius).length, lessThan(1e-12));
    });

    test('đứng yên thì vận tốc trượt bằng vận tốc tâm bi', () {
      const s = BallState(pos: Vec2(50, 50), vel: Vec2(100, 0));
      expect(s.slip(radius), const Vec2(100, 0));
    });

    test('dưới cả hai ngưỡng dừng mới là đứng hẳn', () {
      const p = Vec2(10, 10);
      expect(const BallState(pos: p).isStopped, isTrue);
      expect(
          const BallState(pos: p, vel: Vec2(stopSpeed * 0.9, 0)).isStopped,
          isTrue);
      expect(
          const BallState(pos: p, vel: Vec2(stopSpeed * 1.1, 0)).isStopped,
          isFalse);
      expect(
          const BallState(pos: p, spin: Vec3(0, 0, stopSpin * 1.1)).isStopped,
          isFalse);
    });

    test('động năng gồm tịnh tiến và quay của bi đặc', () {
      const v = Vec2(100, 0);
      const w = Vec3(0, 0, 10);
      final e = const BallState(pos: Vec2.zero, vel: v, spin: w)
          .kineticEnergy(radius);
      expect(
          e,
          closeTo(
              0.5 * ballMass * 100 * 100 +
                  0.5 * 0.4 * ballMass * radius * radius * 100,
              1e-6));
    });
  });
}
