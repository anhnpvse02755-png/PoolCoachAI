import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Quá góc này là không đánh được (PRD §5.1). Đúng 85° vẫn đánh được.
const maxCutAngle = 85.0;

/// Dung sai khi so góc với [maxCutAngle]: dựng đúng 85° rồi tính lại
/// qua acos có thể ra 85.0000000001.
const _angleEpsilon = 1e-9;

/// Dưới độ dài này thì thành phần vuông góc chỉ là nhiễu số học của cú
/// thẳng — coi như không có hướng tiếp tuyến.
const _straightCutoff = 1e-9;

/// Hình học của một cú đánh hợp lệ.
class ShotGeometry {
  const ShotGeometry({
    required this.cue,
    required this.object,
    required this.pocket,
    required this.ghost,
    required this.objectDir,
    required this.tangentDir,
    required this.aimDir,
    required this.angle,
  });

  final Vec2 cue;
  final Vec2 object;
  final Pocket pocket;

  /// Bi ảo: nơi tâm bi cái phải tới lúc chạm.
  final Vec2 ghost;

  /// Hướng bi mục tiêu → lỗ, đơn vị.
  final Vec2 objectDir;

  /// Hướng bi cái đi sau va chạm khi đánh đứng bi, đơn vị; vector không
  /// với cú thẳng.
  final Vec2 tangentDir;

  /// Hướng bi cái → bi ảo, đơn vị.
  final Vec2 aimDir;

  /// Góc cắt, độ.
  final double angle;
}

enum UnmakeableReason { overlap, ghostOffTable, tooThin, cueBlocked, objectBlocked }

sealed class ShotResult {
  const ShotResult();
}

final class Makeable extends ShotResult {
  const Makeable(this.geometry);
  final ShotGeometry geometry;
}

final class Unmakeable extends ShotResult {
  const Unmakeable(this.reason);
  final UnmakeableReason reason;
}

/// Đánh [object] vào [pocket] từ [cue], với các bi [others] còn trên bàn
/// (không gồm bi cái và bi mục tiêu).
ShotResult evaluateShot({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  Iterable<Vec2> others = const [],
  TableSpec table = TableSpec.nineFoot,
}) {
  final d = table.ballDiameter;
  if (cue.distanceTo(object) < d) {
    return const Unmakeable(UnmakeableReason.overlap);
  }

  final pocketPos = table.pocketPosition(pocket);
  final u = (pocketPos - object).normalized;
  final ghost = object - u * d;
  if (!table.contains(ghost)) {
    return const Unmakeable(UnmakeableReason.ghostOffTable);
  }

  final toGhost = ghost - cue;
  // Bi cái nằm đúng chỗ bi ảo nghĩa là hai bi dính nhau theo đường lỗ:
  // đó là cú thẳng.
  final aim = toGhost.isZero ? u : toGhost.normalized;
  final angle = math.acos(clampRange(aim.dot(u), -1, 1)) * 180 / math.pi;
  if (angle > maxCutAngle + _angleEpsilon) {
    return const Unmakeable(UnmakeableReason.tooThin);
  }

  if (!isPathClear(cue, ghost, others, table: table)) {
    return const Unmakeable(UnmakeableReason.cueBlocked);
  }
  if (!isPathClear(object, pocketPos, others, table: table)) {
    return const Unmakeable(UnmakeableReason.objectBlocked);
  }

  final perp = aim - u * aim.dot(u);
  return Makeable(
    ShotGeometry(
      cue: cue,
      object: object,
      pocket: pocket,
      ghost: ghost,
      objectDir: u,
      tangentDir: perp.length < _straightCutoff ? Vec2.zero : perp.normalized,
      aimDir: aim,
      angle: angle,
    ),
  );
}
