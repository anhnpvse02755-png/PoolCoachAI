import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Dưới mức này (cm/s) coi như điểm chạm khăn không trượt: bi đang lăn.
///
/// Không phải hằng số chỉnh được: chuyển trượt → lăn được bắt đúng thời
/// điểm và ép lăn đều, nên sau đó vận tốc trượt chỉ còn nhiễu làm tròn.
const rollingSlip = 1e-6;

/// Một bước chuyển động trên khăn trong [dt] giây (spec mục 4.2).
///
/// Trong một pha (trượt hoặc lăn) gia tốc không đổi, nên cập nhật theo
/// đúng công thức gia tốc không đổi chứ không cộng dồn Euler: cùng bước
/// 1 ms mà không tích sai số. Chuyển trượt → lăn rơi vào giữa bước thì
/// tách bước tại đúng thời điểm đó.
BallState clothStep(BallState s, double dt, {required double radius}) {
  var state = s;
  var left = dt;

  final u = state.slip(radius);
  final slipSpeed = u.length;
  if (slipSpeed > rollingSlip) {
    // Ma sát trượt kéo vận tốc trượt về 0 theo đường thẳng với gia tốc
    // 7/2·μ·g (bi đặc), nên biết trước lúc nào hết trượt.
    final untilRolling = slipSpeed / (3.5 * muSlide * gravity);
    final t = math.min(untilRolling, left);
    state = _slide(state, t, u * (1 / slipSpeed), radius);
    left -= t;
    if (t == untilRolling) state = _forceRolling(state, radius);
  }
  if (left > 0) state = _roll(state, left, radius);

  return state.copyWith(spin: _decayVerticalSpin(state.spin, dt, radius));
}

/// Trượt [t] giây, ma sát ngược hướng trượt [dir].
///
/// Lực `−μ·g·û` đặt ở điểm chạm khăn đổi cả vận tốc lẫn xoáy ngang
/// (mô-men `R ẑ × F`). Khi xoáy có trục nằm ngang dọc đường đi (cơ dốc
/// có áp phê), hướng trượt lệch khỏi hướng đi và đường đi cong thành
/// parabol — đó là swerve.
BallState _slide(BallState s, double t, Vec2 dir, double radius) {
  final a = dir * (-muSlide * gravity);
  final k = 2.5 * muSlide * gravity / radius;
  return BallState(
    pos: s.pos + s.vel * t + a * (0.5 * t * t),
    vel: s.vel + a * t,
    spin: s.spin + Vec3(-dir.y, dir.x, 0) * (k * t),
  );
}

/// Lăn đều: xoáy ngang khớp `ẑ × v / R`, giữ nguyên xoáy đứng.
BallState _forceRolling(BallState s, double radius) => s.copyWith(
      spin: Vec3(-s.vel.y / radius, s.vel.x / radius, s.spin.z),
    );

/// Lăn [t] giây: giảm tốc `muRoll·g` theo đường thẳng tới khi đứng.
BallState _roll(BallState s, double t, double radius) {
  final speed = s.vel.length;
  if (speed == 0) return s;
  final dir = s.vel * (1 / speed);
  const decel = muRoll * gravity;
  final run = math.min(t, speed / decel);
  final next = speed - decel * run;
  final vel = next <= 0 ? Vec2.zero : dir * next;
  return _forceRolling(
    BallState(
      pos: s.pos + dir * (speed * run - 0.5 * decel * run * run),
      vel: vel,
      spin: s.spin,
    ),
    radius,
  );
}

/// Xoáy quanh trục đứng tắt dần với gia tốc góc `5·muSpin·g / 2R`.
Vec3 _decayVerticalSpin(Vec3 spin, double dt, double radius) {
  final drop = 2.5 * muSpin * gravity / radius * dt;
  final z = spin.z.abs() <= drop ? 0.0 : spin.z - spin.z.sign * drop;
  return Vec3(spin.x, spin.y, z);
}
