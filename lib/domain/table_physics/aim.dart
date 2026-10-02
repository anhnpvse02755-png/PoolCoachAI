import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Cú đánh đã dò xong: hướng cơ bù ném và điểm đặt cơ (spec mục 4.6).
class AimedShot {
  const AimedShot({
    required this.trace,
    required this.uncompensated,
    required this.aimOffsetDeg,
    required this.verticalOffset,
    required this.converged,
  });

  /// Cú đánh theo hướng đã bù (hoặc hướng hình học nếu không bù).
  final ShotTrace trace;

  /// Khi bù: cú ngắm thẳng vào Bi ảo hình học, để vẽ đường đỏ.
  final ShotTrace? uncompensated;

  /// Hướng cơ đã bù trừ hướng tới Bi ảo hình học, độ; dương là dày hơn.
  final double aimOffsetDeg;

  /// `b` đã dùng, cm (Đánh đứng bi: `b` dò được).
  final double verticalOffset;

  /// Dò bù ném đạt `aimTolerance` trong `maxAimIterations` vòng.
  final bool converged;
}

/// Kết quả dò, chưa mô phỏng đủ — [aimShot] và `scratchMargin` dùng
/// chung, nên biên chết cái tính đúng trên cú mà màn hình vẽ.
class AimSolution {
  const AimSolution({
    required this.aimed,
    required this.geometric,
    required this.converged,
  });

  /// Cú đánh theo hướng đã bù.
  final ShotInput aimed;

  /// Cùng cú đánh, ngắm thẳng vào Bi ảo hình học.
  final ShotInput geometric;
  final bool converged;

  /// Dương là dày hơn: hướng cơ quay về phía tâm bi mục tiêu.
  double get aimOffsetDeg {
    final toCenter = geometric.object - geometric.cue;
    double offCenter(double aim) =>
        Vec2(math.cos(aim), math.sin(aim)).signedAngleTo(toCenter).abs();
    return (offCenter(geometric.aimAngle) - offCenter(aimed.aimAngle)) *
        180 /
        math.pi;
  }
}

/// Dò hướng cơ và điểm đặt cơ cho cú đánh [object] vào [pocket].
AimSolution solveAim({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  required SideSpin spin,
  required double power,
  required CueElevation elevation,
  required TableSpec table,
  required bool compensate,
}) {
  final radius = table.radius;
  final pocketPos = table.pocketPosition(pocket);
  final ghost =
      object - (pocketPos - object).normalized * table.ballDiameter;
  final toGhost = ghost - cue;
  final aim0 = toGhost.isZero
      ? math.atan2(pocketPos.y - object.y, pocketPos.x - object.x)
      : math.atan2(toGhost.y, toGhost.x);

  var input = ShotInput(
    cue: cue,
    object: object,
    aimAngle: aim0,
    power: power,
    verticalOffset: switch (stroke) {
      Stroke.follow => strokeOffset * radius,
      Stroke.draw => -strokeOffset * radius,
      Stroke.stun => 0,
    },
    spin: spin,
    elevation: elevation.radians,
    table: table,
  );

  if (!compensate) {
    if (stroke == Stroke.stun) input = _solveStun(input);
    return AimSolution(aimed: input, geometric: input, converged: true);
  }

  // Bắt đầu từ hướng đã bù sẵn góc lệch do áp phê: vận tốc ban đầu khi
  // đó chỉ đúng vào Bi ảo hình học. Không có bước này, áp phê nhiều ở
  // xa làm cú dò đầu tiên trượt hẳn bi mục tiêu.
  input = input.copyWith(
      aimAngle: aim0 + squirtAngle(sideOffsetOf(spin), radius));
  var converged = false;
  // Đánh đứng bi: `b` đổi xoáy nên đổi cả swerve, tức đổi hướng cần bù;
  // hướng bù đổi quãng đường nên đổi `b`. Dò xen kẽ hai vòng, kết thúc
  // bằng dò bù ném để hướng cơ khớp đúng `b` cuối cùng.
  for (var round = 0; round < (stroke == Stroke.stun ? 2 : 1); round++) {
    if (stroke == Stroke.stun) input = _solveStun(input);
    final (aim, ok) = _solveThrow(input, pocketPos);
    input = input.copyWith(aimAngle: aim);
    converged = ok;
  }
  return AimSolution(
    aimed: input,
    geometric: input.copyWith(aimAngle: aim0),
    converged: converged,
  );
}

/// Dò bù ném và Đánh đứng bi, rồi mô phỏng đủ (spec mục 4.6).
AimedShot aimShot({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  SideSpin spin = const SideSpin.none(),
  required double power,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
  bool compensate = true,
}) {
  final s = solveAim(
    cue: cue,
    object: object,
    pocket: pocket,
    stroke: stroke,
    spin: spin,
    power: power,
    elevation: elevation,
    table: table,
    compensate: compensate,
  );
  return AimedShot(
    trace: simulateShot(s.aimed),
    uncompensated: compensate ? simulateShot(s.geometric) : null,
    aimOffsetDeg: compensate ? s.aimOffsetDeg : 0,
    verticalOffset: s.aimed.verticalOffset,
    converged: s.converged,
  );
}

/// Xoáy dọc (trên +, dưới −) của bi cái lúc chạm, rad/s; null nếu trượt.
double? topspinAtContact(ShotInput input) {
  final probe = probeContact(input);
  if (probe == null) return null;
  final s = probe.cueAtContact;
  final dir = s.vel.normalized;
  // Xoáy lăn đều là ẑ × v / R: chiếu xoáy lên ẑ × v̂.
  return -s.spin.x * dir.y + s.spin.y * dir.x;
}

/// Đánh đứng bi: `b ∈ [−stunMaxOffset·R, 0]` để bi cái tới bi mục tiêu
/// đúng lúc hết xoáy dọc (spec quyết định 10).
///
/// Xoáy lúc chạm gần như tuyến tính theo `b` (thời gian tới bi mục tiêu
/// không phụ thuộc xoáy khi còn trượt), nên dò kiểu chia đôi có nội suy
/// (Illinois): giữ khoảng kẹp như chia đôi nhưng 2–4 vòng là đủ.
ShotInput _solveStun(ShotInput input) {
  final lo = -stunMaxOffset * input.table.radius;
  double? f(double b) => topspinAtContact(input.copyWith(verticalOffset: b));

  final fHi = f(0);
  if (fHi == null || fHi <= stopSpin / 4) {
    return input.copyWith(verticalOffset: 0);
  }
  final fLo = f(lo);
  // Xa quá, đặt cơ thấp nhất vẫn không kịp hết xoáy dưới: dùng mức đó.
  if (fLo == null || fLo >= 0) return input.copyWith(verticalOffset: lo);

  var a = lo, fa = fLo, b = 0.0, fb = fHi;
  var side = 0;
  var x = (a + b) / 2;
  for (var i = 0; i < 16; i++) {
    x = (a * fb - b * fa) / (fb - fa);
    final fx = f(x);
    if (fx == null) break;
    if (fx.abs() < stopSpin / 4) break;
    if (fx < 0) {
      a = x;
      fa = fx;
      if (side == -1) fb /= 2;
      side = -1;
    } else {
      b = x;
      fb = fx;
      if (side == 1) fa /= 2;
      side = 1;
    }
  }
  return input.copyWith(verticalOffset: x);
}

/// Bù ném: dò hướng cơ bằng cát tuyến, bắt đầu từ `input.aimAngle`, sao
/// cho bi mục tiêu ngay sau va chạm chạy thẳng vào tâm lỗ. Đo kết quả
/// thật nên bù luôn bi cái bị lệch do áp phê và swerve. Trả hướng tốt
/// nhất và có hội tụ không.
(double, bool) _solveThrow(ShotInput input, Vec2 pocketPos) {
  const tol = aimTolerance * math.pi / 180;
  // Mỗi vòng xoay tối đa 6°: cát tuyến không chặn có thể nhảy sang cú
  // chạm phía bên kia bi mục tiêu; chặn chặt hơn (1°, 3°) thì cú swerve
  // mạnh ở xa không kịp bù trong maxAimIterations vòng (đo trên lưới:
  // 407, 83, 68 cú không hội tụ trên 6816 với 1°, 3°, 6°).
  const maxStep = 6 * math.pi / 180;
  var probes = 0;
  double? error(double aim) {
    probes++;
    final p = probeContact(input.copyWith(aimAngle: aim));
    if (p == null) return null;
    return p.objectAfter.vel.signedAngleTo(pocketPos - input.object);
  }

  final start = input.aimAngle;
  final toObject = input.object - input.cue;
  final thicker =
      Vec2(math.cos(start), math.sin(start)).cross(toObject) >= 0 ? 1.0 : -1.0;
  var x0 = start;
  var e0 = error(x0);
  // Vẫn trượt (swerve, cắt rất mỏng): xoay dần về phía tâm bi mục tiêu
  // từng nửa độ tới khi chạm.
  for (var k = 1; e0 == null && probes < maxAimIterations; k++) {
    x0 = start + thicker * k * maxStep / 2;
    e0 = error(x0);
  }
  if (e0 == null) return (start, false);

  var bestX = x0, bestE = e0.abs();
  if (bestE < tol) return (x0, true);

  // Bước đầu nhỏ để có độ dốc; sau đó cát tuyến.
  var x1 = x0 + 1e-3 * thicker;
  var e1 = error(x1);
  if (e1 == null) {
    x1 = x0 - 1e-3 * thicker;
    e1 = error(x1);
  }
  if (e1 == null) return (bestX, false);

  while (true) {
    if (e1!.abs() < bestE) {
      bestX = x1;
      bestE = e1.abs();
    }
    if (bestE < tol || probes >= maxAimIterations || e1 == e0) break;
    var step = -e1 * (x1 - x0) / (e1 - e0!);
    if (step.abs() > maxStep) step = maxStep * step.sign;
    var x2 = x1 + step;
    var e2 = error(x2);
    // Trượt bi mục tiêu: lùi nửa đường về điểm còn chạm.
    while (e2 == null && probes < maxAimIterations) {
      step /= 2;
      x2 = x1 + step;
      e2 = error(x2);
    }
    if (e2 == null) break;
    x0 = x1;
    e0 = e1;
    x1 = x2;
    e1 = e2;
  }
  return (bestX, bestE < tol);
}
