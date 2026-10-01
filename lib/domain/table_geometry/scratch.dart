import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Mức lực đầu tiên làm bi cái chết cái, và rơi lỗ nào.
class ScratchRisk {
  const ScratchRisk({required this.power, required this.pocket});
  final double power;
  final Pocket pocket;
}

/// Tăng lực từ [power] lên từng 1% tới 100%, trả mức đầu tiên chết cái.
///
/// Ngay [power] đã chết cái thì trả chính [power] (biên bằng 0). Không
/// mức nào chết cái thì null. Chỉ xét **dư** lực: thiếu lực làm đường
/// đi ngắn lại, hiếm khi chạm tới lỗ (spec mục 1, ngoài phạm vi).
ScratchRisk? scratchMargin(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  TableSpec table = TableSpec.nineFoot,
}) {
  for (var p = power; p <= 100; p += 1) {
    final pocket =
        simulateCueBall(g, stroke: stroke, power: p, spin: spin, table: table)
            .scratch;
    if (pocket != null) return ScratchRisk(power: p, pocket: pocket);
  }
  return null;
}

/// Biên lực dư cho cảnh báo chết cái — trùng `POWER_JITTER` của PRD.
const overhitBand = 15.0;

/// Kết quả của một mức áp phê tại lực đang chọn.
class SpinOutcome {
  const SpinOutcome({this.scratchAtPower, this.risk});

  /// Lỗ bi cái rơi vào ngay tại lực đang chọn; null khi không rơi.
  final Pocket? scratchAtPower;

  /// Mức lực đầu tiên (≥ lực chọn) làm chết cái; null khi không có.
  final ScratchRisk? risk;
}

/// Lời khuyên là dữ liệu có giá trị tính được; `Vi` ghép thành câu.
sealed class Advice {
  const Advice();
}

/// Mức đang chọn chết cái; đổi sang [to] thì tránh được.
final class AddSpinToAvoid extends Advice {
  const AddSpinToAvoid({required this.from, required this.to, required this.pocket});
  final SideSpin from;
  final SideSpin to;
  final Pocket pocket;
}

/// Mức đang chọn chết cái và không mức áp phê nào cứu được.
final class NoSpinAvoids extends Advice {
  const NoSpinAvoids({required this.pocket});
  final Pocket pocket;
}

/// Dư lực [margin]% (từ [fromPower]%) là chết cái; [saferSpin] (nếu có)
/// an toàn tới 100%.
final class OverhitRisk extends Advice {
  const OverhitRisk({
    required this.margin,
    required this.fromPower,
    required this.pocket,
    this.saferSpin,
  });
  final double margin;
  final double fromPower;
  final Pocket pocket;
  final SideSpin? saferSpin;
}

/// Áp phê [side] quá [maxSafeTips] đầu cơ thì chết cái.
final class SpinCeiling extends Advice {
  const SpinCeiling({required this.side, required this.maxSafeTips, required this.pocket});
  final SpinSide side;
  final double maxSafeTips;
  final Pocket pocket;
}

/// Luật chọn lời khuyên (spec mục 4.8), tách khỏi mô phỏng để test thẳng.
List<Advice> chooseAdvice({
  required double power,
  required SideSpin chosen,
  required Map<SideSpin, SpinOutcome> outcomes,
}) {
  bool safe(SpinOutcome o) =>
      o.scratchAtPower == null &&
      (o.risk == null || o.risk!.power - power > overhitBand);

  final current = outcomes[chosen]!;
  final advice = <Advice>[];

  final dropped = current.scratchAtPower;
  if (dropped != null) {
    final fix = _fewestTips(chosen, outcomes, (s, o) => s != chosen && safe(o));
    advice.add(fix == null
        ? NoSpinAvoids(pocket: dropped)
        : AddSpinToAvoid(from: chosen, to: fix, pocket: dropped));
    return advice;
  }

  final risk = current.risk;
  if (risk != null && risk.power - power <= overhitBand) {
    advice.add(OverhitRisk(
      margin: risk.power - power,
      fromPower: risk.power,
      pocket: risk.pocket,
      saferSpin: _fewestTips(
        chosen,
        outcomes,
        (s, o) => s != chosen && o.scratchAtPower == null && o.risk == null,
      ),
    ));
  }

  final side = chosen.side;
  if (side != null) {
    var maxSafe = chosen.tips;
    for (final s in SideSpin.all) {
      if (s.side != side || s.tips <= chosen.tips) continue;
      final drop = outcomes[s]!.scratchAtPower;
      if (drop != null) {
        advice.add(SpinCeiling(side: side, maxSafeTips: maxSafe, pocket: drop));
        break;
      }
      maxSafe = s.tips;
    }
  }

  return advice.take(2).toList();
}

/// Mức thoả [ok] có ít đầu cơ nhất; hoà thì ưu tiên cùng phía [chosen],
/// rồi theo thứ tự [SideSpin.all].
SideSpin? _fewestTips(
  SideSpin chosen,
  Map<SideSpin, SpinOutcome> outcomes,
  bool Function(SideSpin, SpinOutcome) ok,
) {
  SideSpin? best;
  for (final s in SideSpin.all) {
    if (!ok(s, outcomes[s]!)) continue;
    if (best == null ||
        s.tips < best.tips ||
        (s.tips == best.tips &&
            s.side == chosen.side &&
            best.side != chosen.side)) {
      best = s;
    }
  }
  return best;
}

/// Mô phỏng đủ bảy mức áp phê rồi chọn lời khuyên.
List<Advice> scratchAdvice(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  TableSpec table = TableSpec.nineFoot,
}) {
  final outcomes = {
    for (final s in SideSpin.all)
      s: () {
        final risk = scratchMargin(g,
            stroke: stroke, power: power, spin: s, table: table);
        return SpinOutcome(
          scratchAtPower: risk != null && risk.power == power ? risk.pocket : null,
          risk: risk,
        );
      }(),
  };
  return chooseAdvice(power: power, chosen: spin, outcomes: outcomes);
}
