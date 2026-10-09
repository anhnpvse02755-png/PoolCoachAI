import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  double deg(Vec2 a, Vec2 b) => math.acos(a.dot(b).clamp(-1.0, 1.0)) * 180 / math.pi;

  test('9. cắt mỏng (> 60°) có errDeg lớn hơn rõ rệt cắt dày (< 20°)', () {
    final thin = geometryFor(tableCenter, Pocket.topRight, 65);
    final thick = geometryFor(tableCenter, Pocket.topRight, 15);
    expect(missErrDeg(thin.angle), greaterThan(2 * missErrDeg(thick.angle)));
    expect(missErrDeg(thick.angle), greaterThanOrEqualTo(missAngleDeg));
  });

  test('errDeg không vượt 3 lần sai số ngắm gốc', () {
    expect(missErrDeg(85), lessThanOrEqualTo(3 * missAngleDeg));
  });

  test('dư dày là lệch về phía hướng cơ: góc cắt nhỏ đi đúng errDeg', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 40);
    final err = missErrDeg(g.angle);
    expect(deg(missDirection(g, MissSide.thick), g.aimDir), closeTo(g.angle - err, 1e-6));
    expect(deg(missDirection(g, MissSide.thin), g.aimDir), closeTo(g.angle + err, 1e-6));
  });

  test('cắt về phía bên kia cũng đúng chiều', () {
    final g = geometryFor(tableCenter, Pocket.topRight, -40);
    final err = missErrDeg(g.angle);
    expect(deg(missDirection(g, MissSide.thick), g.aimDir), closeTo(g.angle - err, 1e-6));
  });

  test('bi cuối (không còn bi nào) không lỗi; điểm trượt nằm trong biên', () {
    final g = geometryFor(const Vec2(220, 30), Pocket.topRight, 30);
    final advice = missSafetyAdvice(g, const []);
    expect(table.contains(advice.thick), isTrue);
    expect(table.contains(advice.thin), isTrue);
    expect(advice.errDeg, missErrDeg(g.angle));
  });

  test('hướng có bi khác sát điểm trượt thì khó cho đối thủ hơn', () {
    // Điểm trượt giữa bàn, xa băng: phần băng của hai hướng gần bằng nhau,
    // nên bi nằm sát một hướng (dưới 40 cm) quyết định.
    final g = geometryFor(const Vec2(60, 63.5), Pocket.bottomRight, 20);
    final open = missSafetyAdvice(g, const []);
    final apart = (open.thick - open.thin).normalized;
    expect(missSafetyAdvice(g, [open.thick + apart * 25]).safer, MissSide.thick);
    expect(missSafetyAdvice(g, [open.thin - apart * 25]).safer, MissSide.thin);
  });
}
