import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Bốn băng, mỗi băng có pháp tuyến hướng từ bi ra băng.
enum Rail {
  left(Vec2(-1, 0)),
  right(Vec2(1, 0)),
  top(Vec2(0, -1)),
  bottom(Vec2(0, 1));

  const Rail(this.outward);

  final Vec2 outward;
}

/// Xung lực băng lên một bi đang chạm [rail] (spec mục 4.3).
///
/// Mô hình Han 2005 rút gọn. Mũi băng chạm bi ở độ cao `cushionHeight`
/// đường kính, cao hơn tâm bi, nên pháp tuyến tiếp xúc chúi xuống mặt
/// bàn một góc `θ`. Khác Han: bi bị mặt bàn giữ, không đi xuống được,
/// nên chọn xung pháp tuyến để vận tốc pháp tuyến nằm ngang phục hồi
/// đúng `cushionRestitution` — phần thẳng đứng của xung do mặt bàn
/// nhận. Ma sát `cushionFriction` tại điểm chạm, chặn trên bởi điều
/// kiện hết trượt, đổi vận tốc dọc băng và xoáy: đó là chỗ áp phê thuận
/// mở góc, nghịch đóng góc, và trô/cu lê đổi góc bật.
///
/// Xung tính theo đơn vị khối lượng (cm/s), nên không cần `ballMass`.
BallState cushionImpact(BallState s, Rail rail, {required double radius}) {
  final n = rail.outward;
  final approach = s.vel.dot(n);
  if (approach <= 0) return s;

  const sinT = 2 * cushionHeight - 1;
  final cosT = math.sqrt(1 - sinT * sinT);
  final n3 = Vec3.flat(n);
  final toContact = (n3 * cosT + Vec3.up * sinT) * radius;
  final normal = -(n3 * cosT + Vec3.up * sinT);

  final impulseN = (1 + cushionRestitution) * approach / cosT;

  final vContact = Vec3.flat(s.vel) + s.spin.cross(toContact);
  final slip = vContact - normal * vContact.dot(normal);
  final slipSpeed = slip.length;
  // Một xung tiếp tuyến J đổi vận tốc điểm chạm 7/2·J (bi đặc), nên
  // 2/7 vận tốc trượt là vừa đủ để hết trượt.
  final impulseT = slipSpeed == 0
      ? 0.0
      : math.min(cushionFriction * impulseN, slipSpeed * 2 / 7);
  final friction =
      slipSpeed == 0 ? Vec3.zero : slip * (-impulseT / slipSpeed);

  final impulse = normal * impulseN + friction;
  // Vận tốc pháp tuyến chỉ do phục hồi quyết định: phần ma sát chỉa ra
  // khỏi băng (do pháp tuyến tiếp xúc nghiêng) cũng do mặt bàn và băng
  // nhận, nếu không bi bật ra nhanh hơn `cushionRestitution` cho phép.
  final along = Vec2(-n.y, n.x);
  return BallState(
    pos: s.pos,
    vel: s.vel -
        n * ((1 + cushionRestitution) * approach) +
        along * impulse.xy.dot(along),
    spin: s.spin + toContact.cross(impulse) * (2.5 / (radius * radius)),
  );
}
