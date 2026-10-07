import 'dart:math' as math;

import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_physics/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';

/// Đặt cơ lệch tâm ít hơn mức này (đầu cơ) thì coi như đánh tâm: không nói.
const stunOffsetShownTips = 0.25;

/// Độ lệch điểm ngắm, đổi ra đơn vị người chơi nhìn được. Đúng một trong
/// [ballDenominator] ("1/k con bi") hoặc [ballCount] ("N con bi") có giá trị.
typedef AimShiftUnits = ({
  double tips,
  double? ballDenominator,
  double? ballCount,
});

/// Đổi độ lệch điểm ngắm [shiftCm] (cm) ra đầu cơ (làm tròn 0.25) và phần
/// con bi. Mẫu số k tính từ số đầu cơ ĐÃ làm tròn (k làm tròn 0.5), để câu
/// "1 đầu cơ ≈ 1/4.5 con bi" luôn khớp với số đầu cơ hiện ra. Lệch từ một
/// con bi trở lên (k ≤ 1) thì nói "N con bi" (làm tròn 0.5) vì "1/1 con bi"
/// vô nghĩa. Lệch dưới 0.125 đầu cơ làm tròn về 0: trả null.
AimShiftUnits? aimShiftUnits(double shiftCm, double ballDiameter) {
  final tips = (shiftCm / tipWidth * 4).round() / 4;
  if (tips == 0) return null;
  final k = (ballDiameter / (tips * tipWidth) * 2).round() / 2;
  // So với k ĐÃ làm tròn: k thô 1.02 sẽ hiện "1/1 con bi", vô nghĩa.
  if (k <= 1) {
    return (
      tips: tips,
      ballDenominator: null,
      ballCount: (tips * tipWidth / ballDiameter * 2).round() / 2,
    );
  }
  return (
    tips: tips,
    ballDenominator: k,
    ballCount: null,
  );
}

/// Các dòng của bảng thông tin (spec 2026-10-02 mục 6.3).
///
/// Hàm thuần, tách khỏi widget để test thẳng từng ngưỡng. Mọi số đều lấy
/// từ [aimed] và lõi; ở đây chỉ chọn dòng nào hiện. [advice] null nghĩa
/// là gợi ý chống chết cái đang tính. [cannotSimulate] là lõi chạy quá
/// `maxSimTime` cho cú này ([aimed] khi đó null).
List<String> simulatorInfoLines({
  required ShotResult? shot,
  required AimedShot? aimed,
  bool cannotSimulate = false,
  required List<Advice>? advice,
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  required CueElevation elevation,
  TableSpec table = TableSpec.nineFoot,
}) {
  switch (shot) {
    case null:
      return [Vi.simNoPocket];
    // Không đánh được thì chỉ nói lý do.
    case Unmakeable(:final reason):
      return [Vi.simUnmakeable(reason)];
    case Makeable(:final geometry):
      final trace = aimed?.trace;
      return [
        Vi.simPocketLine(geometry.pocket),
        Vi.simAngleLine(geometry.angle),
        Vi.simBandLine(bandFor(geometry.angle)),
        Vi.simStrokeLine(stroke),
        Vi.simPowerLine(power),
        Vi.simSpinLine(spin),
        Vi.simElevationLine(elevation),
        if (cannotSimulate) Vi.simCannotSimulate,
        if (aimed != null &&
            stroke == Stroke.stun &&
            aimed.stunReached &&
            aimed.verticalOffset.abs() >= stunOffsetShownTips * tipWidth)
          Vi.simStunOffset(aimed.verticalOffset),
        if (!spin.isNone) squirtLine(spin, aimed, geometry, table, stroke, power),
        if (trace != null && trace.cueRailCount > 0)
          Vi.simRailCount(trace.cueRailCount),
        if (trace?.cuePocket case final pocket?) Vi.simScratch(pocket),
        if (trace != null && trace.objectPocket != geometry.pocket)
          Vi.simObjectMissed,
        if (spin.risksMiscue) Vi.simMiscue,
        if (advice == null) Vi.simComputing else ...advice.map(Vi.simAdvice),
      ];
  }
}

/// Dòng áp phê — màn Mô phỏng góc cắt và màn Kế hoạch dọn bàn dùng chung,
/// không viết lại (spec 2026-10-07 mục 7.2). Độ lệch điểm ngắm là bề ngang hướng cơ đã bù xê dịch so với
/// hướng hình học, tại quãng cơ tới bi ảo: gộp cả squirt, swerve lẫn ném,
/// đúng lượng người chơi phải dịch. Không lấy hiệu điểm chạm thật với bi ảo
/// hình học vì cú đã bù để vào lỗ nên hai điểm đó gần như trùng nhau. Không
/// có vết (không mô phỏng được) thì chỉ nói góc; số độ của lệch ngắm không
/// bao giờ nói ra, chỉ đổi thành đầu cơ.
String squirtLine(
    SideSpin spin,
    AimedShot? aimed,
    ShotGeometry geometry,
    TableSpec table,
    Stroke stroke,
    double power) {
  final deg = squirtAngle(sideOffsetOf(spin), table.radius) * 180 / math.pi;
  final distance = geometry.cue.distanceTo(geometry.ghost);
  final units = aimed == null
      ? null
      : aimShiftUnits(
          distance * math.tan(aimed.aimOffsetDeg.abs() * math.pi / 180),
          table.ballDiameter);
  // SAWS chỉ đi kèm khi có lượng dịch điểm ngắm để bù: cùng điều kiện với
  // phần ngoặc, nên không có vết hay lệch bằng 0 thì không gợi ý.
  final bhe = units == null
      ? null
      : sawsBhePercent(distance: distance, power: power, stroke: stroke);
  return Vi.simSquirt(deg, units?.tips, units?.ballDenominator, bhe,
      units?.ballCount);
}
