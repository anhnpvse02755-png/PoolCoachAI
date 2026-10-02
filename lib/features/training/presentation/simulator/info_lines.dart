import 'dart:math' as math;

import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';

/// Bù ném nhỏ hơn mức này (độ) thì tay người không chỉnh được: không nói.
const aimOffsetShownDeg = 0.5;

/// Đặt cơ lệch tâm ít hơn mức này (đầu cơ) thì coi như đánh tâm: không nói.
const stunOffsetShownTips = 0.25;

/// Các dòng của bảng thông tin (spec 2026-10-02 mục 6.3).
///
/// Hàm thuần, tách khỏi widget để test thẳng từng ngưỡng. Mọi số đều lấy
/// từ [aimed] và lõi; ở đây chỉ chọn dòng nào hiện. [advice] null nghĩa
/// là gợi ý chống chết cái đang tính.
List<String> simulatorInfoLines({
  required ShotResult? shot,
  required AimedShot? aimed,
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
        if (aimed != null &&
            Vi.simSaysThickness(geometry.angle) &&
            aimed.aimOffsetDeg.abs() >= aimOffsetShownDeg)
          Vi.simAimOffset(aimed.aimOffsetDeg),
        if (aimed != null &&
            stroke == Stroke.stun &&
            aimed.stunReached &&
            aimed.verticalOffset.abs() >= stunOffsetShownTips * tipWidth)
          Vi.simStunOffset(aimed.verticalOffset),
        if (!spin.isNone)
          Vi.simSquirt(
              squirtAngle(sideOffsetOf(spin), table.radius) * 180 / math.pi),
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
