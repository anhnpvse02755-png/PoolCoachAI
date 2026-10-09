import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

enum MissSide { thick, thin }

/// Gợi ý định tính "nếu trượt thì nên trượt về phía nào" (PRD §5.5). Không
/// ảnh hưởng việc chọn phương án; không mô phỏng quỹ đạo trượt thật.
class MissAdvice {
  const MissAdvice({
    required this.thick,
    required this.thin,
    required this.safer,
    required this.errDeg,
  });

  /// Chỗ bi mục tiêu trôi tới nếu trượt dày / mỏng, đã kẹp vào biên bàn.
  final Vec2 thick;
  final Vec2 thin;

  /// Hướng khó cho đối thủ hơn — nên chủ động lệch nhẹ về phía này.
  final MissSide safer;

  /// Sai số ngắm giả định sau khi nhân độ nhạy, độ. Chỉ dùng bên trong:
  /// không bao giờ hiện thành lời khuyên ngắm theo độ.
  final double errDeg;
}

/// Cắt càng mỏng càng nhạy sai số ngắm: `sensitivity = min(3, 1/max(0.15,
/// cos góc cắt))`, `errDeg = min(30, missAngleDeg × sensitivity)`.
double missErrDeg(double cutAngle) {
  final cos = math.cos(cutAngle * math.pi / 180);
  final sensitivity = math.min(3.0, 1 / math.max(0.15, cos));
  return math.min(30.0, missAngleDeg * sensitivity);
}

/// Hướng bi mục tiêu đi nếu trượt về phía [side]. Dày hơn là bi mục tiêu bị
/// đẩy lệch về phía hướng cơ (góc cắt nhỏ đi); mỏng là ngược lại. Cú thẳng
/// không có phía nào: lấy chiều dương làm dày, để kết quả tất định.
Vec2 missDirection(ShotGeometry g, MissSide side) {
  final towardAim = g.objectDir.cross(g.aimDir) >= 0 ? 1.0 : -1.0;
  final turn = missErrDeg(g.angle) * math.pi / 180 * towardAim;
  return g.objectDir.rotated(side == MissSide.thick ? turn : -turn);
}

/// PRD §5.5: điểm trượt sát băng hoặc kẹt gần bi khác thì khó cho đối thủ
/// hơn. [obstaclesAfter] rỗng (bi cuối) vẫn chạy được. Bằng nhau thì dày.
MissAdvice missSafetyAdvice(ShotGeometry g, List<Vec2> obstaclesAfter,
    {TableSpec table = TableSpec.nineFoot}) {
  Vec2 missAt(MissSide side) => table.clamp(g.object + missDirection(g, side) * missTravel);
  double hardness(Vec2 p) {
    final rail = [
      p.x - table.minX,
      table.maxX - p.x,
      p.y - table.minY,
      table.maxY - p.y,
    ].reduce(math.min);
    final nearest = obstaclesAfter.isEmpty
        ? double.infinity
        : obstaclesAfter.map(p.distanceTo).reduce(math.min);
    return 400 / (rail + 10) + (nearest < 40 ? 25 : 0);
  }

  final thick = missAt(MissSide.thick);
  final thin = missAt(MissSide.thin);
  return MissAdvice(
    thick: thick,
    thin: thin,
    safer: hardness(thin) > hardness(thick) ? MissSide.thin : MissSide.thick,
    errDeg: missErrDeg(g.angle),
  );
}
