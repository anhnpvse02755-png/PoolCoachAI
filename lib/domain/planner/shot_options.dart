import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Đầu vào của một lần mô phỏng. Record nên so sánh theo giá trị: dùng
/// thẳng làm khoá bộ nhớ đệm của việc tính chia lát.
typedef ShotKey = ({
  Vec2 cue,
  Vec2 object,
  Pocket pocket,
  Stroke stroke,
  SideSpin spin,
  double power,
});

/// Tra một lần mô phỏng; null khi lõi quá `maxSimTime` cho cú đó.
typedef ShotLookup = AimedShot? Function(ShotKey key);

ShotKey shotKey(ShotGeometry g, Stroke stroke, double power,
        {SideSpin spin = const SideSpin.none()}) =>
    (cue: g.cue, object: g.object, pocket: g.pocket, stroke: stroke, spin: spin, power: power);

ShotKey withPower(ShotKey k, double power) => (
      cue: k.cue,
      object: k.object,
      pocket: k.pocket,
      stroke: k.stroke,
      spin: k.spin,
      power: power,
    );

/// Lực lệch [delta] điểm phần trăm, không quá [maxPower].
double jitteredPower(double power, double delta) => math.min(power + delta, maxPower);

/// Tầng 1: đứng / cu lê / trô × năm mức lực, đúng thứ tự thử.
List<ShotKey> tierOneKeys(ShotGeometry g) => [
      for (final s in strokeCandidates)
        for (final p in powerCandidates) shotKey(g, s, p),
    ];

/// Tầng 2, đường lui áp phê: kiểu đánh × trái/phải × ½/1 đầu cơ × lực (60).
List<ShotKey> tierTwoKeys(ShotGeometry g) => [
      for (final s in strokeCandidates)
        for (final side in SpinSide.values)
          for (final tips in sideTipsCandidates)
            for (final p in powerCandidates) shotKey(g, s, p, spin: SideSpin(side, tips)),
    ];

/// Một lần mô phỏng của Planner: cơ Thường, luôn bù ném, không mô phỏng cú
/// không bù (màn từng bước không vẽ đường đỏ). Quá giờ thì null: phương án
/// đó không dùng được, kế hoạch vẫn chạy tiếp (spec mục 4.3).
AimedShot? simulateKey(ShotKey k,
    {AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot}) {
  try {
    return aim(
      cue: k.cue,
      object: k.object,
      pocket: k.pocket,
      stroke: k.stroke,
      spin: k.spin,
      power: k.power,
      elevation: CueElevation.normal,
      table: table,
      compensate: true,
      withUncompensated: false,
    );
  } on SimulationTimeout {
    return null;
  }
}

/// Tra thẳng, có nhớ — cho test và công cụ dò bàn. Việc tính chia lát dùng
/// bộ nhớ của riêng nó.
ShotLookup directLookup({AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot}) {
  final memo = <ShotKey, AimedShot?>{};
  return (k) => memo.containsKey(k)
      ? memo[k]
      : (memo[k] = simulateKey(k, aim: aim, table: table));
}

/// Vì sao một phương án bị loại (spec mục 4.3). Quá giờ là lookup null.
enum Rejection { scratch, objectMissed, blocked }

Rejection? rejectionOf(AimedShot aimed, Pocket pocket, List<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  final t = aimed.trace;
  if (t.cuePocket != null) return Rejection.scratch;
  if (t.objectPocket != pocket) return Rejection.objectMissed;
  if (!polylineClear(t.cueBefore, obstacles, table: table) ||
      !polylineClear(t.cueAfter, obstacles, table: table) ||
      !polylineClear(t.objectPath, obstacles, table: table)) {
    return Rejection.blocked;
  }
  return null;
}

/// Đường gấp khúc đi lọt qua mọi bi chắn. Bi thứ ba không tham gia va chạm
/// (PRD §8), chỉ dùng để kiểm chắn đường.
bool polylineClear(List<Vec2> points, List<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  if (points.isEmpty || obstacles.isEmpty) return true;
  if (points.length == 1) {
    return isPathClear(points.first, points.first, obstacles, table: table);
  }
  for (var i = 0; i + 1 < points.length; i++) {
    if (!isPathClear(points[i], points[i + 1], obstacles, table: table)) return false;
  }
  return true;
}
