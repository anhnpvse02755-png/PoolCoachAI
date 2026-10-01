import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Âm khi [a] tốt hơn [b]: góc cắt nhỏ hơn, hoà góc thì lỗ gần bi mục
/// tiêu hơn. Bằng 0 khi hoà hết.
int compareShots(
  ShotGeometry a,
  ShotGeometry b, {
  TableSpec table = TableSpec.nineFoot,
}) {
  final byAngle = a.angle.compareTo(b.angle);
  if (byAngle != 0) return byAngle;
  return a.object
      .distanceTo(table.pocketPosition(a.pocket))
      .compareTo(b.object.distanceTo(table.pocketPosition(b.pocket)));
}

/// Lỗ dễ nhất cho bi mục tiêu — Priority 1 của Planner (PRD §5.1).
///
/// Thử cả sáu lỗ, bỏ mọi cú không đánh được, giữ cú tốt nhất theo
/// [compareShots]. Chỉ thay khi tốt hơn hẳn, nên hoà hết thì giữ lỗ
/// đứng trước trong [Pocket.values] — kết quả luôn tất định.
ShotGeometry? bestPocket({
  required Vec2 cue,
  required Vec2 object,
  Iterable<Vec2> others = const [],
  TableSpec table = TableSpec.nineFoot,
}) {
  ShotGeometry? best;
  for (final pocket in Pocket.values) {
    final result = evaluateShot(
      cue: cue,
      object: object,
      pocket: pocket,
      others: others,
      table: table,
    );
    if (result is! Makeable) continue;
    if (best == null || compareShots(result.geometry, best, table: table) < 0) {
      best = result.geometry;
    }
  }
  return best;
}
