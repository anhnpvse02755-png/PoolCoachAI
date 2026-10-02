import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;
  const pos = Vec2(60, 60);
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);

  double headingDeg(Vec2 v) => math.atan2(v.y, v.x) * 180 / math.pi;

  test('đánh tâm, cơ nằm ngang: bi đi đúng hướng cơ, không xoáy', () {
    final s = strikeCue(
        pos: pos,
        aimAngle: 0.3,
        power: 50,
        verticalOffset: 0,
        spin: none,
        elevation: 0);
    expect(s.pos, pos);
    expect(s.vel.length, closeTo(maxCueSpeed * 0.5, 1e-9));
    expect(s.vel.normalized.distanceTo(const Vec2(1, 0).rotated(0.3)),
        lessThan(1e-12));
    expect(s.spin.length, lessThan(1e-9));
  });

  test('cu lê xoáy lên, trô xoáy xuống, đúng độ lớn 5·v₀·b / 2R²', () {
    final b = strokeOffset * radius;
    const v0 = maxCueSpeed * 0.4;
    for (final sign in [1.0, -1.0]) {
      final s = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 40,
          verticalOffset: sign * b,
          spin: none,
          elevation: 0);
      // Đi theo +x: xoáy lăn đều nằm trên trục +y (ẑ × x̂ = ŷ).
      expect(s.spin.y, closeTo(sign * 5 * v0 * b / (2 * radius * radius), 1e-9));
      expect(s.spin.x.abs() + s.spin.z.abs(), lessThan(1e-9));
    }
  });

  test('bi cái bị lệch do áp phê: ngược phía áp phê, đúng công thức', () {
    var previous = 0.0;
    for (final tips in [0.5, 1.0, 2.0]) {
      final right = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: SideSpin(SpinSide.right, tips),
          elevation: 0);
      final left = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: SideSpin(SpinSide.left, tips),
          elevation: 0);
      final alpha = squirtAngle(tips * tipWidth, radius) * 180 / math.pi;
      // Góc dương là quay sang phải: áp phê phải làm bi lệch sang trái.
      expect(headingDeg(right.vel), closeTo(-alpha, 1e-9));
      expect(headingDeg(left.vel), closeTo(alpha, 1e-9));
      expect(alpha, greaterThan(previous));
      previous = alpha;
    }
  });

  test('công thức lệch do áp phê là Alciatore TP A.31', () {
    const a = 1.25;
    final r = a / radius;
    final expected = math.atan(2.5 * r * math.sqrt(1 - r * r) /
        (1 + 1 / endMassRatio + 2.5 * (1 - r * r)));
    expect(squirtAngle(a, radius), expected);
    expect(squirtAngle(-a, radius), -expected);
    expect(squirtAngle(0, radius), 0);
  });

  test('cơ dốc có áp phê thì xoáy có trục dọc đường đi — nguồn swerve', () {
    double along(CueElevation e) {
      final s = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: right1,
          elevation: e.radians);
      return s.spin.x;
    }

    final flat = strikeCue(
        pos: pos,
        aimAngle: 0,
        power: 50,
        verticalOffset: 0,
        spin: right1,
        elevation: 0);
    expect(flat.spin.x.abs(), lessThan(1e-9));
    expect(along(CueElevation.steep).abs(),
        greaterThan(along(CueElevation.normal).abs()));
    expect(along(CueElevation.normal).abs(), greaterThan(0));
  });

  test('áp phê phải xoáy theo chiều ngược với áp phê trái', () {
    Vec3 spinOf(SideSpin s) => strikeCue(
            pos: pos,
            aimAngle: 0,
            power: 50,
            verticalOffset: 0,
            spin: s,
            elevation: CueElevation.normal.radians)
        .spin;
    final r = spinOf(right1);
    final l = spinOf(const SideSpin(SpinSide.left, 1));
    expect(r.z, closeTo(-l.z, 1e-9));
    expect(r.z, isNot(0));
  });

  test('hai mức độ dốc cơ đổi ra radian từ hằng số độ', () {
    expect(CueElevation.normal.radians, cueElevationNormal * math.pi / 180);
    expect(CueElevation.steep.radians, cueElevationSteep * math.pi / 180);
  });

  test('độ lệch ngang theo số đầu cơ, phải dương', () {
    expect(sideOffsetOf(none), 0);
    expect(sideOffsetOf(right1), tipWidth);
    expect(sideOffsetOf(const SideSpin(SpinSide.left, 2)), -2 * tipWidth);
  });
}
