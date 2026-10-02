import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_collision.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;

  // Ba mức tốc độ trong đồ thị ném của Alciatore (TP A.14): 1, 3, 7 mph.
  const slow = 44.7;
  const medium = 134.1;
  const fast = 312.9;

  /// Bi cái đi theo +x, chạm bi mục tiêu ở góc cắt [cutDeg] (dương: bi
  /// mục tiêu nằm bên phải, đi sang phải).
  (BallState, BallState) hit(double cutDeg, double speed,
      {Vec3 spin = Vec3.zero}) {
    final r = cutDeg * math.pi / 180;
    final cue = BallState(pos: Vec2.zero, vel: Vec2(speed, 0), spin: spin);
    final object =
        BallState(pos: Vec2(math.cos(r), math.sin(r)) * (2 * radius));
    return collideBalls(cue, object, radius: radius);
  }

  /// Góc ném, độ: hướng bi mục tiêu đi so với đường nối tâm; dương là
  /// lệch sang phải.
  double throwDeg(double cutDeg, BallState object) {
    final r = cutDeg * math.pi / 180;
    return Vec2(math.cos(r), math.sin(r)).signedAngleTo(object.vel) *
        180 /
        math.pi;
  }

  /// Xoáy đứng của cú áp phê [spin] ở tốc độ [speed], cơ nằm ngang.
  Vec3 englishOf(SideSpin spin, double speed) {
    final s = strikeCue(
        pos: Vec2.zero,
        aimAngle: 0,
        power: 100 * speed / maxCueSpeed,
        verticalOffset: 0,
        spin: spin,
        elevation: 0);
    return Vec3(0, 0, s.spin.z);
  }

  test('bắn thẳng không xoáy: chia vận tốc theo ballRestitution, không ném',
      () {
    final (cue, object) = hit(0, 300);
    expect(object.vel.x, closeTo((1 + ballRestitution) / 2 * 300, 1e-9));
    expect(cue.vel.x, closeTo((1 - ballRestitution) / 2 * 300, 1e-9));
    expect(object.vel.y.abs(), lessThan(1e-9));
  });

  test('hai bi đang rời nhau thì không va chạm', () {
    const cue = BallState(pos: Vec2.zero, vel: Vec2(-100, 0));
    final object = BallState(pos: Vec2(2 * radius, 0));
    final (c, o) = collideBalls(cue, object, radius: radius);
    expect(c, same(cue));
    expect(o, same(object));
  });

  test('cắt nửa bi, lực vừa: ném trong khoảng Alciatore 2–4°', () {
    final (_, object) = hit(30, medium);
    expect(throwDeg(30, object).abs(), inInclusiveRange(2, 4));
  });

  test('ném giảm khi lực tăng', () {
    final throws = [
      for (final v in [slow, medium, fast]) throwDeg(30, hit(30, v).$2).abs(),
    ];
    expect(throws[0], greaterThan(throws[1]));
    expect(throws[1], greaterThan(throws[2]));
  });

  test('ném do góc cắt kéo bi mục tiêu về phía hướng bi cái đi (cắt mỏng đi)',
      () {
    expect(throwDeg(30, hit(30, medium).$2), lessThan(0));
    expect(throwDeg(-30, hit(-30, medium).$2), greaterThan(0));
  });

  test('bắn thẳng có áp phê: bi mục tiêu bị ném ngược phía áp phê', () {
    final right =
        hit(0, medium, spin: englishOf(const SideSpin(SpinSide.right, 1), medium));
    final left =
        hit(0, medium, spin: englishOf(const SideSpin(SpinSide.left, 1), medium));
    expect(throwDeg(0, right.$2), lessThan(0));
    expect(throwDeg(0, left.$2), greaterThan(0));
  });

  test('áp phê ngoài làm giảm ném khi cắt', () {
    // Cắt sang phải (bi mục tiêu đi phải) thì áp phê ngoài là áp phê trái.
    final plain = throwDeg(30, hit(30, medium).$2).abs();
    final outside = throwDeg(
            30,
            hit(30, medium,
                    spin: englishOf(
                        const SideSpin(SpinSide.left, 0.5), medium))
                .$2)
        .abs();
    expect(outside, lessThan(plain));
  });

  test('bảo toàn động lượng ngang, không tăng động năng', () {
    for (final cut in [0.0, 15.0, 30.0, 45.0, 60.0, 80.0]) {
      for (final top in [-1.0, 0.0, 1.0]) {
        for (final side in [-100.0, 0.0, 100.0]) {
          const v = 250.0;
          final spin = Vec3(0, top * v / radius, side);
          final r = cut * math.pi / 180;
          final a = BallState(pos: Vec2.zero, vel: const Vec2(v, 0), spin: spin);
          final b = BallState(pos: Vec2(math.cos(r), math.sin(r)) * (2 * radius));
          final (c, o) = collideBalls(a, b, radius: radius);
          final momentum = c.vel + o.vel;
          expect(momentum.distanceTo(const Vec2(v, 0)), lessThan(1e-9));
          expect(c.kineticEnergy(radius) + o.kineticEnergy(radius),
              lessThanOrEqualTo(a.kineticEnergy(radius)),
              reason: 'cắt $cut° top=$top side=$side');
        }
      }
    }
  });

  test('ma sát truyền một ít xoáy sang bi mục tiêu', () {
    final (_, object) = hit(30, medium);
    expect(object.spin.length, greaterThan(0));
  });

  test('hệ số ma sát bi–bi đúng công thức, đổi cm/s ra m/s', () {
    expect(throwFriction(100),
        throwFrictionA + throwFrictionB * math.exp(-throwFrictionC));
  });
}
