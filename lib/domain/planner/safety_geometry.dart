import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Phía bên trái khi nhìn dọc [dir] trên màn (y đi xuống).
Vec2 leftOf(Vec2 dir) => Vec2(dir.y, -dir.x);

/// Độ lệch ngang lúc chạm, cm, của độ dày [thickness] lệch [side]: tâm bi
/// cái cách đường tâm bi hợp lệ `D·(1 − độ dày)`; dương là bên trái.
double contactLateral(double thickness, ThicknessSide side,
    {TableSpec table = TableSpec.nineFoot}) {
  final offset = table.ballDiameter * (1 - thickness);
  return switch (side) {
    ThicknessSide.full => 0,
    ThicknessSide.left => offset,
    ThicknessSide.right => -offset,
  };
}

typedef DirectContact = ({double aim, Vec2 contact});

/// Đánh thẳng từ [cue] sao cho tâm bi cái lệch [lateral] khỏi tâm [ball] lúc
/// chạm: hướng cơ (rad) và bi ảo. null khi hai bi chồng nhau hoặc lệch quá
/// một đường kính (trượt bi).
DirectContact? directContact(Vec2 cue, Vec2 ball, double lateral,
    {TableSpec table = TableSpec.nineFoot}) {
  final d = ball - cue;
  final dist = d.length;
  final dd = table.ballDiameter;
  if (dist <= dd || lateral.abs() > dd) return null;
  // (cue − ball)·trái(u) = dist·sin(φ − θ) = lateral.
  final aim = math.atan2(d.y, d.x) - math.asin(lateral / dist);
  final u = Vec2(math.cos(aim), math.sin(aim));
  final along = u.dot(d) - math.sqrt(math.max(0.0, dd * dd - lateral * lateral));
  return (aim: aim, contact: cue + u * along);
}

/// Thấy bi (spec 3.2): một trong ba đường — tới bi ảo trọn bi, và hai đường
/// mỏng sát hai mép — không bị [obstacles] chắn.
bool canSee(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  final dd = table.ballDiameter;
  for (final lateral in [0.0, dd, -dd]) {
    final c = directContact(cue, ball, lateral, table: table);
    if (c != null && isPathClear(cue, c.contact, obstacles, table: table)) return true;
  }
  return false;
}

/// Thứ tự thử độ dày: trọn bi, rồi mỗi mức trái trước phải. Một chỗ dựng
/// chung cho cả trực tiếp lẫn A băng, chỉ khác danh sách độ dày nguồn.
List<(double, ThicknessSide)> _contactOrder(List<double> thicknesses) => [
      for (final f in thicknesses)
        if (f == 1)
          (f, ThicknessSide.full)
        else
          ...[(f, ThicknessSide.left), (f, ThicknessSide.right)],
    ];

/// Thứ tự thử độ dày của cú trực tiếp (spec 3.3).
final directContactOrder = _contactOrder(safetyThicknesses);

/// Thứ tự thử điểm chạm của A băng: trọn bi, ½ trái, ½ phải.
final kickContactOrder = _contactOrder(kickThicknesses);

/// Các độ dày mà đường bi cái tới bi ảo không bị chắn, đúng thứ tự thử.
List<(double, ThicknessSide)> openContacts(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles,
        {TableSpec table = TableSpec.nineFoot}) =>
    [
      for (final (f, side) in directContactOrder)
        if (directContact(cue, ball, contactLateral(f, side, table: table), table: table)
                case final c?
            when isPathClear(cue, c.contact, obstacles, table: table))
          (f, side),
    ];

/// Mọi chuỗi [count] băng không lặp băng liền nhau, theo thứ tự `Rail.values`
/// ở từng vị trí: 4, 12, 36, 108 chuỗi.
List<List<Rail>> railSequences(int count) {
  var out = <List<Rail>>[const []];
  for (var i = 0; i < count; i++) {
    out = [
      for (final s in out)
        for (final r in Rail.values)
          if (s.isEmpty || s.last != r) [...s, r],
    ];
  }
  return out;
}

/// Ảnh soi gương của [p] qua biên tâm bi của [rail].
Vec2 mirrorAcross(Vec2 p, Rail rail, {TableSpec table = TableSpec.nineFoot}) => switch (rail) {
      Rail.left => Vec2(2 * table.minX - p.x, p.y),
      Rail.right => Vec2(2 * table.maxX - p.x, p.y),
      Rail.top => Vec2(p.x, 2 * table.minY - p.y),
      Rail.bottom => Vec2(p.x, 2 * table.maxY - p.y),
    };

/// Điểm chạm băng rơi vào miệng lỗ (spec 3.4): gần điểm lỗ hơn vùng rơi lỗ
/// cộng một đường kính bi.
bool inPocketMouth(Vec2 p, {TableSpec table = TableSpec.nineFoot}) => Pocket.values.any(
    (k) => p.distanceTo(table.pocketPosition(k)) < table.captureRadius(k) + table.ballDiameter);

/// Đường A băng hình học: hướng cơ ban đầu, các điểm chạm băng, bi ảo.
class KickPath {
  const KickPath({required this.aim, required this.hits, required this.contact});

  /// Hướng cơ (rad) tới ảnh soi gương — chỉ là điểm bắt đầu dò.
  final double aim;
  final List<Vec2> hits;
  final Vec2 contact;
}

/// Soi gương bi hợp lệ qua [rails] (spec 3.4). null khi đường gấp khúc
/// không chạm đúng các băng theo thứ tự, chạm băng ở miệng lỗ, hay đi qua
/// bi khác — trước băng cuối, kể cả chính bi hợp lệ.
KickPath? kickPath({
  required Vec2 cue,
  required Vec2 ball,
  required List<Rail> rails,
  required double lateral,
  required List<Vec2> obstacles,
  TableSpec table = TableSpec.nineFoot,
}) {
  if (rails.isEmpty) return null;
  // Lần đầu soi tâm bi để biết hướng đoạn cuối, rồi dời điểm soi sang bên
  // cho đúng độ lệch ngang.
  final full = _fold(cue, ball, rails, table);
  if (full == null) return null;
  final target = ball + leftOf((ball - full.last).normalized) * lateral;
  final hits = _fold(cue, target, rails, table);
  if (hits == null) return null;
  final u = (target - hits.last).normalized;
  final dd = table.ballDiameter;
  final contact = target - u * math.sqrt(math.max(0.0, dd * dd - lateral * lateral));
  final legs = [cue, ...hits];
  final early = [...obstacles, ball];
  for (var i = 0; i + 1 < legs.length; i++) {
    if (!isPathClear(legs[i], legs[i + 1], early, table: table)) return null;
  }
  if (!isPathClear(hits.last, contact, obstacles, table: table)) return null;
  final first = hits.first;
  return KickPath(
    aim: math.atan2(first.y - cue.y, first.x - cue.x),
    hits: List.unmodifiable(hits),
    contact: contact,
  );
}

List<Vec2>? _fold(Vec2 cue, Vec2 target, List<Rail> rails, TableSpec table) {
  final images = List<Vec2>.filled(rails.length + 1, target);
  for (var j = rails.length - 1; j >= 0; j--) {
    images[j] = mirrorAcross(images[j + 1], rails[j], table: table);
  }
  var from = cue;
  final hits = <Vec2>[];
  for (var j = 0; j < rails.length; j++) {
    final hit = _railCrossing(from, images[j], rails[j], table);
    if (hit == null || inPocketMouth(hit, table: table)) return null;
    hits.add(hit);
    from = hit;
  }
  return hits;
}

/// Chỗ đoạn [from] → [toward] cắt biên của [rail], nếu nó cắt trong đoạn và
/// trong chiều dài băng.
Vec2? _railCrossing(Vec2 from, Vec2 toward, Rail rail, TableSpec table) {
  final vertical = rail == Rail.left || rail == Rail.right;
  final bound = switch (rail) {
    Rail.left => table.minX,
    Rail.right => table.maxX,
    Rail.top => table.minY,
    Rail.bottom => table.maxY,
  };
  final a = vertical ? from.x : from.y;
  final b = vertical ? toward.x : toward.y;
  if (a == b) return null;
  final t = (bound - a) / (b - a);
  if (t <= 1e-9 || t > 1) return null;
  final hit = vertical
      ? Vec2(bound, from.y + (toward.y - from.y) * t)
      : Vec2(from.x + (toward.x - from.x) * t, bound);
  final along = vertical ? hit.y : hit.x;
  final lo = vertical ? table.minY : table.minX;
  final hi = vertical ? table.maxY : table.maxX;
  return along < lo || along > hi ? null : hit;
}

/// Số chấm của điểm chạm [hit] trên [rail]: băng dài 0–8 từ góc trái, băng
/// ngắn 0–4 từ góc trên, làm tròn nửa chấm (spec quyết định 5).
double diamondOf(Vec2 hit, Rail rail, {TableSpec table = TableSpec.nineFoot}) {
  final raw = switch (rail) {
    Rail.top || Rail.bottom => hit.x / table.length * longRailDiamonds,
    Rail.left || Rail.right => hit.y / table.width * shortRailDiamonds,
  };
  return (raw * 2).round() / 2;
}

/// Bi ở [p] cách băng gần nhất không quá [nearRailDiameters] đường kính.
bool nearRail(Vec2 p, {TableSpec table = TableSpec.nineFoot}) {
  final gap = [p.x - table.minX, table.maxX - p.x, p.y - table.minY, table.maxY - p.y]
      .reduce(math.min);
  return gap <= nearRailDiameters * table.ballDiameter;
}

/// Độ lệch ngang đo được lúc chạm: tâm bi cái so với tâm [ball], theo hướng
/// bi cái đang đi; dương là bên trái.
double lateralAt(BallState cueAtContact, Vec2 ball) =>
    (cueAtContact.pos - ball).dot(leftOf(cueAtContact.vel.normalized));
