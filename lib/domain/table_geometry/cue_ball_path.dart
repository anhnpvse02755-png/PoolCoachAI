import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

// Hằng số khởi điểm — chỉnh bằng mắt trên màn mô phỏng (spec mục 3).

/// Quãng bi cái đi ở lực 100%, cm. Thay `260 px` của prototype.
const maxTravel = 254.0;

/// Tỉ lệ thành phần dọc đường bi mục tiêu của trô/cu lê.
const rollCarry = 0.5;

/// Góc bật băng đổi thêm mỗi một bán kính lệch tâm, độ.
const spinDegPerRadius = 20.0;

/// Góc bật không vượt quá gần song song với băng.
const _maxReboundDeg = 89.0;

sealed class PathSegment {
  const PathSegment();
  Vec2 get start;
  Vec2 get end;
  Vec2 pointAt(double t);

  /// Phần đầu của đoạn, từ 0 tới [t].
  PathSegment splitAt(double t);
}

final class Straight extends PathSegment {
  const Straight(this.start, this.end);

  @override
  final Vec2 start;
  @override
  final Vec2 end;

  @override
  Vec2 pointAt(double t) => start + (end - start) * t;

  @override
  Straight splitAt(double t) => Straight(start, pointAt(t));
}

/// Bézier bậc ba.
final class Curve extends PathSegment {
  const Curve(this.p0, this.p1, this.p2, this.p3);

  final Vec2 p0;
  final Vec2 p1;
  final Vec2 p2;
  final Vec2 p3;

  @override
  Vec2 get start => p0;
  @override
  Vec2 get end => p3;

  @override
  Vec2 pointAt(double t) {
    if (t == 1) return p3;
    final s = 1 - t;
    return p0 * (s * s * s) +
        p1 * (3 * s * s * t) +
        p2 * (3 * s * t * t) +
        p3 * (t * t * t);
  }

  @override
  Curve splitAt(double t) {
    final a = _lerp(p0, p1, t);
    final b = _lerp(p1, p2, t);
    final c = _lerp(p2, p3, t);
    final d = _lerp(a, b, t);
    final e = _lerp(b, c, t);
    return Curve(p0, a, d, _lerp(d, e, t));
  }
}

Vec2 _lerp(Vec2 a, Vec2 b, double t) => a + (b - a) * t;

/// Đường bi cái sau va chạm.
class CueBallPath {
  const CueBallPath({
    required this.segments,
    required this.end,
    this.railHit,
    this.reboundDir,
    this.scratch,
  });

  /// Các đoạn nối liền nhau, bắt đầu tại bi ảo.
  final List<PathSegment> segments;

  /// Điểm bi cái dừng. Planner dùng đúng đối tượng này làm `cbFrom` của
  /// bước sau — không tính lại.
  final Vec2 end;

  /// Điểm chạm băng khi dội băng; null khi không chạm băng.
  final Vec2? railHit;

  /// Hướng bật ra sau khi chạm băng, đã tính áp phê.
  final Vec2? reboundDir;

  /// Lỗ bi cái rơi vào (chết cái); null khi không rơi.
  final Pocket? scratch;

  bool get bankUsed => railHit != null;
}

enum _Wall {
  left(Vec2(-1, 0)),
  right(Vec2(1, 0)),
  top(Vec2(0, -1)),
  bottom(Vec2(0, 1));

  const _Wall(this.outward);

  /// Pháp tuyến hướng từ bi ra băng.
  final Vec2 outward;

  bool get isVertical => this == left || this == right;
}

/// Đường bi cái sau khi chạm bi mục tiêu (spec mục 4.4–4.7).
CueBallPath simulateCueBall(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  TableSpec table = TableSpec.nineFoot,
}) {
  final travel = maxTravel * power / 100;
  final theta = g.angle * math.pi / 180;
  final along = g.tangentDir * (travel * math.sin(theta));
  final rollSign = switch (stroke) {
    Stroke.stun => 0.0,
    Stroke.follow => 1.0,
    Stroke.draw => -1.0,
  };
  // Lệch khỏi PRD (quyết định 9): PRD cho quãng đường tỉ lệ sin, nên
  // cú thẳng thì trô/cu lê cũng đứng im. Thành phần cos theo đường bi
  // mục tiêu giữ cho hai kỹ thuật này đúng bản chất ở cú thẳng.
  final roll =
      g.objectDir * (rollSign * rollCarry * travel * math.cos(theta));
  final ghost = g.ghost;
  final target = ghost + along + roll;

  final segments = <PathSegment>[];
  Vec2? railHit;
  Vec2? reboundDir;

  if (table.contains(target)) {
    segments.add(_leg(ghost, along, roll, table));
  } else {
    // Dội băng: bắn theo hướng bi ảo → điểm dừng chứ không theo tiếp
    // tuyến như PRD §5.2, để tính được cả thành phần dọc của trô/cu lê.
    final chord = target - ghost;
    final total = chord.length;
    final dir = chord.normalized;
    final (hit, wall) = _firstRailHit(ghost, dir, table);
    railHit = hit;
    final rebound = _applySpin(_reflect(dir, wall), wall, spin, table);
    reboundDir = rebound;
    // Hai đoạn tách biệt, không bao giờ gộp thành một đường cong.
    segments.add(Straight(ghost, hit));

    final remaining = total - ghost.distanceTo(hit);
    final f = remaining / total;
    // Áp phê bật thêm một góc `turn` so với phản xạ thuần tuý (0 khi
    // không xoáy biên). Cả thành phần tiếp tuyến [along] lẫn thành phần
    // trô/cu lê [roll] phải phản xạ qua băng rồi xoay cùng góc đó — chứ
    // không phải giữ nguyên [roll] như cũ — nếu không thành phần cong
    // sẽ ngược hướng với cú bật và triệt tiêu lẫn nhau.
    final turn = _reflect(dir, wall).signedAngleTo(rebound);
    final straight2 = _reflect(along, wall).rotated(turn) * f;
    final bend2 = _reflect(roll, wall).rotated(turn) * f;
    // Chủ dự án duyệt trên Chrome: xoáy trô gần như hết trước khi tới
    // băng, nên sau dội băng bi cái đi thẳng tới cùng điểm dừng. Cu lê
    // vẫn còn xoáy lên nên giữ đường cong.
    final second = stroke == Stroke.draw
        ? Straight(hit, hit + straight2 + bend2)
        : _leg(hit, straight2, bend2, table);
    if (table.contains(second.end)) {
      segments.add(second);
    } else {
      // PRD §8: tối đa một lần dội — chạm băng thứ hai thì dừng ở đó.
      final (stop, _) =
          _firstRailHit(hit, (second.end - hit).normalized, table);
      segments.add(Straight(hit, stop));
    }
  }

  final cut = _truncateAtScratch(segments, table);
  if (cut.pocket == null) {
    return CueBallPath(
      segments: segments,
      end: segments.last.end,
      railHit: railHit,
      reboundDir: reboundDir,
    );
  }
  // Lọt lỗ trước khi tới băng thì không có cú bật nào.
  final dropsBeforeRail = railHit != null && cut.index == 0;
  return CueBallPath(
    segments: cut.segments,
    end: cut.segments.last.end,
    railHit: dropsBeforeRail ? null : railHit,
    reboundDir: dropsBeforeRail ? null : reboundDir,
    scratch: cut.pocket,
  );
}

/// Một chặng: đi thẳng [straight] rồi cong thêm [bend] (trô/cu lê).
///
/// Bézier tương đương đường bậc hai có điểm điều khiển ở cuối phần đi
/// thẳng: rời [start] theo hướng [straight], tới đích theo hướng [bend].
/// Điểm điều khiển kẹp vào bàn nên đường cong không xuyên băng.
PathSegment _leg(Vec2 start, Vec2 straight, Vec2 bend, TableSpec table) {
  final q = start + straight;
  final end = q + bend;
  if (straight.isZero || bend.isZero) return Straight(start, end);
  return Curve(
    start,
    table.clamp(start + (q - start) * (2 / 3)),
    table.clamp(end + (q - end) * (2 / 3)),
    end,
  );
}

/// Điểm đầu tiên tia [from] + s·[dir] chạm biên tâm bi, và băng nào.
///
/// Toạ độ chạm được gán đúng bằng biên, nên điểm chạm nằm chính xác
/// trên băng (PRD §7 ca 4), không lệch vì số học.
(Vec2, _Wall) _firstRailHit(Vec2 from, Vec2 dir, TableSpec table) {
  final sx = dir.x > 0
      ? (table.maxX - from.x) / dir.x
      : dir.x < 0
          ? (table.minX - from.x) / dir.x
          : double.infinity;
  final sy = dir.y > 0
      ? (table.maxY - from.y) / dir.y
      : dir.y < 0
          ? (table.minY - from.y) / dir.y
          : double.infinity;

  if (sx <= sy) {
    final y = clampRange(from.y + dir.y * sx, table.minY, table.maxY);
    return dir.x > 0
        ? (Vec2(table.maxX, y), _Wall.right)
        : (Vec2(table.minX, y), _Wall.left);
  }
  final x = clampRange(from.x + dir.x * sy, table.minX, table.maxX);
  return dir.y > 0
      ? (Vec2(x, table.maxY), _Wall.bottom)
      : (Vec2(x, table.minY), _Wall.top);
}

/// Góc tới bằng góc phản xạ: trục chạm đổi dấu.
Vec2 _reflect(Vec2 dir, _Wall wall) =>
    wall.isVertical ? Vec2(-dir.x, dir.y) : Vec2(dir.x, -dir.y);

/// Áp phê đổi hướng bật băng (spec mục 4.6).
///
/// Áp phê phải làm bi cái quay ngược chiều kim đồng hồ khi nhìn từ trên
/// xuống, nên ma sát ở điểm chạm đẩy bi về **bên phải của hướng ra
/// băng**. Áp phê trái thì ngược lại. Xoay hướng bật về phía lực đẩy
/// đó: cùng chiều bi đang chạy dọc băng là thuận (mở góc), ngược lại là
/// nghịch (đóng góc).
Vec2 _applySpin(Vec2 rebound, _Wall wall, SideSpin spin, TableSpec table) {
  final side = spin.side;
  if (side == null) return rebound;
  final inward = -wall.outward;
  final push = side == SpinSide.right
      ? wall.outward.rightNormal
      : -wall.outward.rightNormal;
  final sense = inward.cross(push).sign;
  final delta = spinDegPerRadius *
      (spin.tips * tipWidth / table.radius) *
      math.pi /
      180;
  const limit = _maxReboundDeg * math.pi / 180;
  final alpha = clampRange(
    inward.signedAngleTo(rebound) + sense * delta,
    -limit,
    limit,
  );
  return inward.rotated(alpha);
}

typedef _Cut = ({List<PathSegment> segments, Pocket? pocket, int index});

/// Cắt đường đi tại điểm đầu tiên tâm bi cái lọt vùng một lỗ.
///
/// Lấy mẫu mỗi bước ≤ R/2. Với đoạn cong, tốc độ |B'(t)| bị chặn trên
/// bởi 3 lần cạnh dài nhất của đa giác điều khiển (tổng trọng số
/// Bernstein bậc hai luôn bằng 3), nên chia đủ bước theo chặn đó —
/// chặn độ dài cung thật chứ không phải chu vi đa giác — để mỗi đoạn
/// mẫu không dài hơn bước, không lọt qua vùng lỗ giữa hai mẫu.
_Cut _truncateAtScratch(List<PathSegment> segments, TableSpec table) {
  final step = table.radius / 2;
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final n = _sampleCount(seg, step);
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      final p = seg.pointAt(t);
      for (final pocket in Pocket.values) {
        if (p.distanceTo(table.pocketPosition(pocket)) <=
            table.captureRadius(pocket)) {
          return (
            segments: [...segments.take(i), seg.splitAt(t)],
            pocket: pocket,
            index: i,
          );
        }
      }
    }
  }
  return (segments: segments, pocket: null, index: -1);
}

/// Số bước lấy mẫu để mỗi bước trên [seg] không dài hơn [step] cm.
int _sampleCount(PathSegment seg, double step) => switch (seg) {
      Straight(:final start, :final end) =>
        math.max(1, (start.distanceTo(end) / step).ceil()),
      Curve(:final p0, :final p1, :final p2, :final p3) => math.max(
          1,
          (3 *
                  math.max(
                    p0.distanceTo(p1),
                    math.max(p1.distanceTo(p2), p2.distanceTo(p3)),
                  ) /
                  step)
              .ceil(),
        ),
    };
