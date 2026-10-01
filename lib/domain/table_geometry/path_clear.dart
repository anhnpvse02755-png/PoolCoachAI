import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Khoảng cách từ [p] tới đoạn thẳng [a]–[b].
double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len2 = ab.dot(ab);
  if (len2 == 0) return p.distanceTo(a);
  final t = clampRange((p - a).dot(ab) / len2, 0, 1);
  return p.distanceTo(a + ab * t);
}

/// Một bi lăn từ [from] tới [to] có đi lọt qua các bi [others] không.
///
/// Hai tâm bi cách nhau dưới một đường kính là chạm nhau, nên tâm bi
/// khác cách đoạn đường đi dưới `D` là chắn.
bool isPathClear(
  Vec2 from,
  Vec2 to,
  Iterable<Vec2> others, {
  TableSpec table = TableSpec.nineFoot,
}) =>
    others.every((o) => distanceToSegment(o, from, to) >= table.ballDiameter);
