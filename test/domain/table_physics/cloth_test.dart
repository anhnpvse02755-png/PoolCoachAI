import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;
  const start = Vec2(30, 63.5);

  BallState strike(
          {double power = 50,
          double b = 0,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal}) =>
      strikeCue(
          pos: start,
          aimAngle: 0,
          power: power,
          verticalOffset: b,
          spin: spin,
          elevation: elevation.radians);

  /// Chạy từng bước tới khi [done], trả trạng thái và thời gian.
  (BallState, double) runUntil(BallState s, bool Function(BallState) done) {
    var t = 0.0;
    var state = s;
    while (!done(state)) {
      state = clothStep(state, timeStep, radius: radius);
      t += timeStep;
      if (t > maxSimTime) fail('không dừng trong maxSimTime');
    }
    return (state, t);
  }

  bool rolling(BallState s) => s.slip(radius).length <= rollingSlip;

  test('đánh tâm: trượt rồi lăn đều ở đúng 5/7 vận tốc ban đầu', () {
    final s0 = strike(elevation: CueElevation.normal);
    final v0 = s0.vel.length;
    final (rolled, t) = runUntil(s0, rolling);
    // Lúc vừa lăn, vận tốc đã giảm thêm do cản lăn trong phần còn lại
    // của bước cuối — tối đa muRoll·g·timeStep.
    expect(rolled.vel.length,
        closeTo(5 / 7 * v0, muRoll * gravity * timeStep + 1e-9));
    // Hết trượt đúng lúc 2·v₀ / (7·μ·g), làm tròn lên một bước.
    final expected = 2 * v0 / (7 * muSlide * gravity);
    expect(t, greaterThanOrEqualTo(expected - 1e-9));
    expect(t, lessThan(expected + timeStep + 1e-9));
  });

  test('chuyển trượt → lăn được bắt giữa bước, không trượt quá', () {
    // Một bước dài gấp nhiều lần thời gian trượt vẫn ra đúng 5/7.
    final s0 = strike(power: 10, elevation: CueElevation.normal);
    final v0 = s0.vel.length;
    final slideTime = 2 * v0 / (7 * muSlide * gravity);
    final after = clothStep(s0, slideTime * 1.5, radius: radius);
    final rollingPart = slideTime * 0.5;
    expect(after.vel.length,
        closeTo(5 / 7 * v0 - muRoll * gravity * rollingPart, 1e-9));
    expect(after.slip(radius).length, lessThan(1e-9));
  });

  test('trô giữ xoáy dưới một quãng rồi mới lăn tới trước', () {
    final s0 = strike(b: -strokeOffset * radius);
    final after = clothStep(s0, 0.05, radius: radius);
    // Còn xoáy dưới: điểm chạm khăn trượt về phía trước nhanh hơn bi.
    expect(after.slip(radius).x, greaterThan(after.vel.x));
    final (rolled, _) = runUntil(s0, rolling);
    expect(rolled.vel.x, greaterThan(0));
  });

  test('lăn thì đi thẳng và giảm tốc đúng muRoll·g tới khi đứng', () {
    final s0 = strike(power: 20);
    final (rolled, _) = runUntil(s0, rolling);
    final next = clothStep(rolled, 0.1, radius: radius);
    expect(rolled.vel.length - next.vel.length,
        closeTo(muRoll * gravity * 0.1, 1e-9));
    expect(next.pos.y, closeTo(rolled.pos.y, 1e-9));
    final (stopped, _) = runUntil(next, (s) => s.vel.length == 0);
    expect(stopped.vel, Vec2.zero);
  });

  test('xoáy đứng tắt dần với gia tốc góc 5·muSpin·g / 2R', () {
    const spinning = BallState(pos: start, spin: Vec3(0, 0, 50));
    final after = clothStep(spinning, 0.1, radius: radius);
    expect(after.spin.z, closeTo(50 - 2.5 * muSpin * gravity / radius * 0.1, 1e-9));
    expect(after.pos, start);
    // Không đổi dấu: tắt hẳn rồi đứng ở 0.
    final gone = clothStep(spinning, 10, radius: radius);
    expect(gone.spin.z, 0);
  });

  test('động năng không bao giờ tăng qua một bước', () {
    for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius]) {
      for (final spin in SideSpin.all) {
        for (final e in CueElevation.values) {
          var s = strike(power: 90, b: b, spin: spin, elevation: e);
          for (var i = 0; i < 3000; i++) {
            final next = clothStep(s, timeStep, radius: radius);
            expect(next.kineticEnergy(radius),
                lessThanOrEqualTo(s.kineticEnergy(radius) * (1 + 1e-12)),
                reason: 'b=$b $spin $e bước $i');
            s = next;
          }
        }
      }
    }
  });

  group('swerve', () {
    /// Độ lệch ngang khỏi đường thẳng ban đầu (đường lệch do áp phê) sau
    /// khi bi đi được [distance] cm; dương là sang phải.
    double curve(SideSpin spin, CueElevation e, double distance) {
      final s0 = strike(power: 45, spin: spin, elevation: e);
      final dir = s0.vel.normalized;
      final (s, _) = runUntil(
          s0, (s) => (s.pos - start).dot(dir) >= distance || s.vel.length == 0);
      return (s.pos - start).dot(dir.rightNormal);
    }

    test('áp phê phải cong về phải, trái cong về trái', () {
      expect(curve(const SideSpin(SpinSide.right, 1), CueElevation.normal, 100),
          greaterThan(0));
      expect(curve(const SideSpin(SpinSide.left, 1), CueElevation.normal, 100),
          lessThan(0));
    });

    test('cơ Dốc cong nhiều hơn cơ Thường', () {
      const spin = SideSpin(SpinSide.right, 1);
      expect(curve(spin, CueElevation.steep, 100),
          greaterThan(curve(spin, CueElevation.normal, 100)));
    });

    test('không áp phê thì không cong', () {
      expect(curve(const SideSpin.none(), CueElevation.steep, 100).abs(),
          lessThan(1e-9));
    });
  });
}
