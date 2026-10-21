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

/// Lõi quá giờ cho cú đang xem (spec cú phòng thủ mục 7): đang hỏi, đang
/// chờ tính lại, chờ rồi vẫn quá giờ, hay người chơi chọn chỉ vẽ đường ngắm.
enum SimTimeoutState { none, asking, waiting, tooLong, aimOnly }

/// Câu của bảng thông tin cho [s]; null khi không quá giờ.
String? simTimeoutLine(SimTimeoutState s) => switch (s) {
      SimTimeoutState.none => null,
      SimTimeoutState.asking => Vi.simTimeoutQuestion,
      SimTimeoutState.waiting => Vi.simComputing,
      SimTimeoutState.tooLong => Vi.simTooLong,
      SimTimeoutState.aimOnly => Vi.simAimOnlyLine,
    };

/// Các dòng của bảng thông tin (spec 2026-10-02 mục 6.3).
///
/// Hàm thuần, tách khỏi widget để test thẳng từng ngưỡng. Mọi số đều lấy
/// từ [aimed] và lõi; ở đây chỉ chọn dòng nào hiện. [advice] null nghĩa
/// là gợi ý chống chết cái đang tính. [timeout] là trạng thái lõi quá
/// giờ ([aimed] khi đó null).
List<String> simulatorInfoLines({
  required ShotResult? shot,
  required AimedShot? aimed,
  SimTimeoutState timeout = SimTimeoutState.none,
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
        ?simTimeoutLine(timeout),
        if (aimed != null &&
            stroke == Stroke.stun &&
            aimed.stunReached &&
            aimed.verticalOffset.abs() >= stunOffsetShownTips * tipWidth)
          Vi.simStunOffset(aimed.verticalOffset),
        if (!spin.isNone) squirtLine(spin, geometry, table, stroke, power),
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
/// không viết lại (spec 2026-10-07 mục 7.2). Góc bi cái bị lệch là thông
/// tin; lời khuyên là câu mẫu SAWS — ngắm như đánh tâm bi rồi bù bằng
/// BHE/FHE — đúng câu Coach dùng (chủ sản phẩm chốt Q5, 21/10/2026). % BHE
/// tính từ quãng bi cái → bi ảo hình học, lực và kiểu đánh.
String squirtLine(SideSpin spin, ShotGeometry geometry, TableSpec table, Stroke stroke, double power) {
  final distance = geometry.cue.distanceTo(geometry.ghost);
  return squirtLineFor(spin, table,
      bhePercent: sawsBhePercent(distance: distance, power: power, stroke: stroke), power: power);
}

/// Cùng dòng áp phê. % BHE do người gọi đưa vào: cú thủ đọc đúng số lõi đã
/// tính (một nguồn, spec 3.7) thay vì tính lại ở đây. Chữ chỉ lực lấy từ
/// [sawsSpeed] của [power]. Không có số độ nào của lệch ngắm.
String squirtLineFor(SideSpin spin, TableSpec table,
    {required int? bhePercent, required double power}) {
  final deg = squirtAngle(sideOffsetOf(spin), table.radius) * 180 / math.pi;
  return Vi.simSquirt(deg, spin, bhePercent, sawsSpeed(power));
}
