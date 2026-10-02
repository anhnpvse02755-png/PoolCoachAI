import 'dart:math' as math;

import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Ma sát bi–bi ở vận tốc trượt [slipSpeed] cm/s (Alciatore TP A.14).
double throwFriction(double slipSpeed) =>
    throwFrictionA +
    throwFrictionB * math.exp(-throwFrictionC * slipSpeed / 100);

/// Va chạm hai bi cùng khối lượng đang chạm nhau (spec mục 4.4).
///
/// Trả nguyên hai bi khi chúng không lao vào nhau. Xung pháp tuyến phục
/// hồi `ballRestitution`. Ma sát tại điểm chạm — hệ số [throwFriction],
/// chặn trên bởi điều kiện hết trượt — đẩy bi [b] lệch khỏi đường nối
/// tâm: đó là ném (CIT do góc cắt, SIT do áp phê). Cùng ma sát đó tạo
/// mô-men như nhau lên cả hai bi; phần thẳng đứng của xung do mặt bàn
/// nhận, nhưng mô-men của nó vẫn truyền một ít xoáy.
(BallState, BallState) collideBalls(
  BallState a,
  BallState b, {
  required double radius,
}) {
  final n = (b.pos - a.pos).normalized;
  final approach = (a.vel - b.vel).dot(n);
  if (approach <= 0) return (a, b);

  final impulseN = (1 + ballRestitution) / 2 * approach;

  final n3 = Vec3.flat(n);
  final toContact = n3 * radius;
  final rel = Vec3.flat(a.vel) +
      a.spin.cross(toContact) -
      (Vec3.flat(b.vel) + b.spin.cross(-toContact));
  final slip = rel - n3 * rel.dot(n3);
  final slipSpeed = slip.length;
  // Hai bi đặc: một xung tiếp tuyến J đổi vận tốc trượt 7·J, nên 1/7 vận
  // tốc trượt là vừa đủ để hết trượt.
  final impulseT = slipSpeed == 0
      ? 0.0
      : math.min(throwFriction(slipSpeed) * impulseN, slipSpeed / 7);
  final friction =
      slipSpeed == 0 ? Vec3.zero : slip * (-impulseT / slipSpeed);

  final onA = friction - n3 * impulseN;
  final turn = toContact.cross(friction) * (2.5 / (radius * radius));
  return (
    BallState(pos: a.pos, vel: a.vel + onA.xy, spin: a.spin + turn),
    BallState(pos: b.pos, vel: b.vel - onA.xy, spin: b.spin + turn),
  );
}
