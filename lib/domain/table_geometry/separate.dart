import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
///
/// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
/// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
///
/// Sát băng thì hướng đẩy có thể chỉ ra ngoài bàn, kẹp lại là chồng tiếp.
/// Khi đó thử trượt dọc theo băng (đẩy theo từng trục, về phía điểm thả);
/// không cách nào tách được thì giữ [previous] — bi không nhảy.
Vec2 separateBalls(Vec2 p, Vec2 other, Vec2 previous,
    {TableSpec table = TableSpec.nineFoot}) {
  final d = table.ballDiameter;
  if ((p - other).length >= d) return p;
  bool clear(Vec2 v) => v.distanceTo(other) >= d;

  final gap = p - other;
  final dir = gap.isZero ? const Vec2(1, 0) : gap.normalized;
  final direct = table.clamp(other + dir * (d + 1e-6));
  if (clear(direct)) return direct;

  final sx = gap.x < 0 ? -1.0 : 1.0;
  final sy = gap.y < 0 ? -1.0 : 1.0;
  final slides = [
    Vec2(sx, 0), Vec2(-sx, 0), Vec2(0, sy), Vec2(0, -sy), //
  ];
  for (final s in slides) {
    final slid = table.clamp(other + s * (d + 1e-6));
    if (clear(slid)) return slid;
  }
  return previous;
}

/// Tách [p] khỏi mọi bi [others] (màn Kế hoạch dọn bàn có tới 16 bi): đẩy
/// khỏi bi chồng đầu tiên, lặp tới khi hết chồng. null khi không cách nào
/// tách được — chỗ chạm bị bi vây kín, không đặt bi.
Vec2? separateFromAll(Vec2 p, List<Vec2> others, {TableSpec table = TableSpec.nineFoot}) {
  var q = table.clamp(p);
  for (var round = 0; round <= others.length; round++) {
    final hit = others.where((o) => q.distanceTo(o) < table.ballDiameter).firstOrNull;
    if (hit == null) return q;
    q = separateBalls(q, hit, q, table: table);
  }
  return null;
}
