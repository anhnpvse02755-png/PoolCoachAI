import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Mức lực đầu tiên làm bi cái chết cái, và rơi lỗ nào.
class ScratchRisk {
  const ScratchRisk({required this.power, required this.pocket});
  final double power;
  final Pocket pocket;
}

/// Lỗ bi cái rơi vào khi đánh [g] ở lực [power] với áp phê [spin] —
/// đúng cú mà `aimShot` vẽ (cùng hướng bù ném, cùng `b`), nên
/// `cuePocketAt(...) == aimShot(...).trace.cuePocket`.
Pocket? cuePocketAt(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) =>
    simulateCuePocket(solveAim(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      stroke: stroke,
      spin: spin,
      power: power,
      elevation: elevation,
      table: table,
      compensate: true,
    ).aimed);

/// Tra một lần mô phỏng: lỗ bi cái rơi vào ở áp phê và lực đã cho.
typedef CuePocketLookup = Pocket? Function(SideSpin spin, double power);

/// Mức lực đầu tiên từ [power] trở lên làm bi cái chết cái.
///
/// Dò thưa từng `overhitScanStep` % tới 100 %, gặp mức chết cái thì dò
/// mịn từng 1 % trong khoảng vừa vượt qua: biên chết cái không đơn điệu
/// theo lực (lực khác thì bi cái chạm băng ở chỗ khác), nên không chia
/// đôi được. Ngay [power] đã chết cái thì trả chính [power]. Chỉ xét
/// **dư** lực, như trước.
ScratchRisk? marginWith(CuePocketLookup at, SideSpin spin, double power) {
  final now = at(spin, power);
  if (now != null) return ScratchRisk(power: power, pocket: now);
  var below = power;
  while (below < 100) {
    final p = math.min(below + overhitScanStep, 100.0);
    final pocket = at(spin, p);
    if (pocket != null) {
      for (var q = below + 1; q < p; q++) {
        final fine = at(spin, q);
        if (fine != null) return ScratchRisk(power: q, pocket: fine);
      }
      return ScratchRisk(power: p, pocket: pocket);
    }
    below = p;
  }
  return null;
}

/// [marginWith] trên mô phỏng thật (spec 2026-10-02 mục 4.7).
ScratchRisk? scratchMargin(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) =>
    marginWith(
      (s, p) => cuePocketAt(g,
          stroke: stroke, power: p, spin: s, elevation: elevation, table: table),
      spin,
      power,
    );

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

/// Kết quả của cả bảy mức áp phê, tra qua [at].
Map<SideSpin, SpinOutcome> outcomesWith(CuePocketLookup at, double power) => {
      for (final s in SideSpin.all)
        s: () {
          final risk = marginWith(at, s, power);
          return SpinOutcome(
            scratchAtPower:
                risk != null && risk.power == power ? risk.pocket : null,
            risk: risk,
          );
        }(),
    };

/// Mô phỏng đủ bảy mức áp phê rồi chọn lời khuyên.
List<Advice> scratchAdvice(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) {
  final job = ScratchAdviceJob(g,
      stroke: stroke,
      power: power,
      spin: spin,
      elevation: elevation,
      table: table);
  while (true) {
    if (job.step() case final advice?) return advice;
  }
}

/// [scratchAdvice] chia nhỏ: mỗi [step] chạy đúng một lần mô phỏng mới.
///
/// Gần trăm lần mô phỏng đầy đủ không xong trong một khung hình trên
/// Chrome, nên màn hình gọi [step] từng chút giữa các khung hình và hiện
/// "Đang tính…" trong lúc chờ (spec mục 5). Luật chọn lời khuyên vẫn
/// chạy đúng một chỗ: mỗi [step] chạy lại từ đầu trên bộ nhớ đệm, gặp
/// lần mô phỏng chưa có thì làm đúng lần đó rồi dừng.
class ScratchAdviceJob {
  ScratchAdviceJob(
    this.g, {
    required this.stroke,
    required this.power,
    required this.spin,
    this.elevation = CueElevation.normal,
    this.table = TableSpec.nineFoot,
    this.lookup,
  });

  final ShotGeometry g;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final CueElevation elevation;
  final TableSpec table;

  /// Thay mô phỏng thật (cho test); null là `cuePocketAt` trên [g].
  final CuePocketLookup? lookup;

  final _cache = <(SideSpin, double), Pocket?>{};

  /// Số lần mô phỏng đã chạy.
  int get simulations => _cache.length;

  /// Lời khuyên khi đã đủ dữ liệu; null khi vừa chạy thêm một lần.
  List<Advice>? step() {
    try {
      return chooseAdvice(
        power: power,
        chosen: spin,
        outcomes: outcomesWith(_lookup, power),
      );
    } on _Missing catch (m) {
      _cache[m.key] = _simulate(m.key.$1, m.key.$2);
      return null;
    }
  }

  /// Lõi quá `maxSimTime` thì coi như bi cái không rơi lỗ: ném tiếp ra
  /// khỏi [step] thì chuỗi khung hình của màn hình dừng và "Đang tính…"
  /// treo mãi. Một mức lực thiếu cảnh báo còn hơn mất cả lời khuyên.
  Pocket? _simulate(SideSpin s, double p) {
    try {
      return (lookup ??
          (s, p) => cuePocketAt(g,
              stroke: stroke,
              power: p,
              spin: s,
              elevation: elevation,
              table: table))(s, p);
    } on SimulationTimeout {
      return null;
    }
  }

  Pocket? _lookup(SideSpin s, double p) {
    final key = (s, p);
    if (_cache.containsKey(key)) return _cache[key];
    throw _Missing(key);
  }
}

class _Missing implements Exception {
  const _Missing(this.key);
  final (SideSpin, double) key;
}
