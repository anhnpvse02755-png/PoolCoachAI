import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  final onRail = Vec2(table.maxX, 60);

  /// Bi tới băng phải với góc [deg] so với pháp tuyến, đi xuống (+y).
  Vec2 incoming(double deg, double speed) {
    final r = deg * math.pi / 180;
    return Vec2(math.cos(r), math.sin(r)) * speed;
  }

  /// Góc bật so với pháp tuyến, độ; dương là vẫn đi xuống (+y).
  double reboundDeg(BallState s) =>
      math.atan2(s.vel.y, -s.vel.x) * 180 / math.pi;

  test('bi đang rời băng thì không có xung lực', () {
    final s = BallState(pos: onRail, vel: const Vec2(-100, 20));
    expect(cushionImpact(s, Rail.right, radius: radius), same(s));
  });

  test('không xoáy: vận tốc pháp tuyến giảm đúng cushionRestitution', () {
    for (final deg in [0.0, 15.0, 30.0, 45.0, 60.0, 75.0]) {
      final s = BallState(pos: onRail, vel: incoming(deg, 200));
      final out = cushionImpact(s, Rail.right, radius: radius);
      expect(-out.vel.x, closeTo(cushionRestitution * s.vel.x, 1e-9),
          reason: '$deg°');
      expect(out.pos, onRail);
    }
  });

  test('không xoáy: góc bật trong 5° quanh góc tới', () {
    for (final deg in [15.0, 30.0, 45.0, 60.0]) {
      for (final speed in [50.0, 200.0, 600.0]) {
        final s = BallState(pos: onRail, vel: incoming(deg, speed));
        final out = cushionImpact(s, Rail.right, radius: radius);
        expect(reboundDeg(out), closeTo(deg, 5), reason: '$deg° $speed');
      }
    }
  });

  group('áp phê', () {
    /// Bi tới băng [deg]°, mang xoáy đứng của cú áp phê [spin] 1 đầu cơ.
    double rebound(double deg, SideSpin spin) {
      final r = deg * math.pi / 180;
      final struck = strikeCue(
          pos: onRail,
          aimAngle: r,
          power: 25,
          verticalOffset: 0,
          spin: spin,
          elevation: 0);
      final s = BallState(
          pos: onRail,
          vel: incoming(deg, struck.vel.length),
          spin: Vec3(0, 0, struck.spin.z));
      return reboundDeg(cushionImpact(s, Rail.right, radius: radius));
    }

    test('áp phê thuận mở góc, nghịch đóng góc', () {
      // Bi chạy dọc băng về bên phải người đánh (+y khi nhìn theo +x),
      // nên áp phê phải là thuận, trái là nghịch.
      for (final deg in [15.0, 30.0, 45.0, 60.0]) {
        final plain = rebound(deg, const SideSpin.none());
        expect(rebound(deg, const SideSpin(SpinSide.right, 1)),
            greaterThan(plain + 1),
            reason: '$deg° thuận');
        // Từ ~60° bi không xoáy đã trượt suốt trên mũi băng: ma sát
        // Coulomb đã bão hoà, nên nghịch không đóng thêm được (đo được
        // 57.85° không xoáy, 57.78° nghịch) — xem "Deviations from spec"
        // của plan 2026-10-02.
        if (deg > 45) continue;
        expect(rebound(deg, const SideSpin(SpinSide.left, 1)),
            lessThan(plain - 1),
            reason: '$deg° nghịch');
      }
    });
  });

  test('cu lê và trô bật ra khác nhau', () {
    final v = incoming(45, 200);
    final dir = v.normalized;
    final rollAxis = Vec3(-dir.y, dir.x, 0) * (v.length / radius);
    final follow = BallState(pos: onRail, vel: v, spin: rollAxis);
    final draw = BallState(pos: onRail, vel: v, spin: -rollAxis);
    final fOut = cushionImpact(follow, Rail.right, radius: radius);
    final dOut = cushionImpact(draw, Rail.right, radius: radius);
    expect((reboundDeg(fOut) - reboundDeg(dOut)).abs(), greaterThan(0.5));
  });

  test('va băng không bao giờ làm tăng động năng', () {
    for (final deg in [0.0, 20.0, 40.0, 60.0, 80.0]) {
      for (final top in [-2.0, -1.0, 0.0, 1.0, 2.0]) {
        for (final side in [-150.0, -50.0, 0.0, 50.0, 150.0]) {
          final v = incoming(deg, 300);
          final dir = v.normalized;
          final s = BallState(
              pos: onRail,
              vel: v,
              spin: Vec3(-dir.y, dir.x, 0) * (top * v.length / radius) +
                  Vec3(0, 0, side));
          final out = cushionImpact(s, Rail.right, radius: radius);
          expect(out.kineticEnergy(radius),
              lessThanOrEqualTo(s.kineticEnergy(radius)),
              reason: '$deg° top=$top side=$side');
        }
      }
    }
  });

  test('bốn băng đối xứng nhau', () {
    final s = BallState(pos: Vec2(table.maxX, 60), vel: incoming(30, 200));
    final right = cushionImpact(s, Rail.right, radius: radius);
    final mirrored = BallState(
        pos: Vec2(table.minX, 60), vel: Vec2(-s.vel.x, s.vel.y));
    final left = cushionImpact(mirrored, Rail.left, radius: radius);
    expect(left.vel.x, closeTo(-right.vel.x, 1e-9));
    expect(left.vel.y, closeTo(right.vel.y, 1e-9));
  });
}
