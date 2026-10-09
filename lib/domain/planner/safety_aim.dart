import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

typedef KickProbeFn = KickProbe Function(ShotInput input, {required int maxRails});
typedef SimulateFn = ShotTrace Function(ShotInput input);

/// Hai hàm lõi vật lý mà việc tìm cú thủ dùng. Mặc định là lõi thật; test
/// thay để ép không hội tụ, quá giờ, hay chỉ cho 4 băng chạm được.
class SafetyPhysics {
  const SafetyPhysics({this.probe = probeKick, this.simulate = simulateShot});

  final KickProbeFn probe;
  final SimulateFn simulate;
}

/// Đầu vào một lần mô phỏng đủ. Record nên so theo giá trị: khoá bộ nhớ
/// đệm, và cú không áp phê ở lực p + 15 % trùng khoá với phương án lực đó.
typedef SimKey = ({Vec2 cue, Vec2 object, double aim, double power, double b, SideSpin spin});

ShotInput inputOf(SimKey k, {TableSpec table = TableSpec.nineFoot}) => ShotInput(
      cue: k.cue,
      object: k.object,
      aimAngle: k.aim,
      power: k.power,
      verticalOffset: k.b,
      spin: k.spin,
      elevation: CueElevation.normal.radians,
      table: table,
    );

SimKey keyOf(ShotInput i) =>
    (cue: i.cue, object: i.object, aim: i.aimAngle, power: i.power, b: i.verticalOffset, spin: i.spin);

/// Cùng hướng cơ, cùng `b`, lực khác — cú người chơi đánh lệch lực.
SimKey withSimPower(SimKey k, double power) =>
    (cue: k.cue, object: k.object, aim: k.aim, power: power, b: k.b, spin: k.spin);

/// Kết quả dò một phương án: khoá mô phỏng đủ, và Đánh đứng bi có thật sự
/// hết xoáy dọc lúc chạm không.
typedef AimResult = ({SimKey key, bool stunReached});

bool _sameRails(List<Rail> a, List<Rail> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Dò hướng cơ để bi cái chạm `input.object` lệch đúng [lateral] cm, sau
/// đúng chuỗi [rails] (spec 3.3–3.4). Bắt đầu từ `input.aimAngle`; điểm
/// đầu trượt thì dò dần ra hai bên, rồi cát tuyến có chặn bước, như bù ném
/// của `aimShot`. Trả hướng tốt nhất và có hội tụ không.
({double aim, bool converged}) refineContact(
    ShotInput input, double lateral, List<Rail> rails, KickProbeFn probe) {
  final tol = contactTolerance * input.table.ballDiameter;
  const maxStep = contactMaxStepDeg * math.pi / 180;
  const startStep = contactStartStepDeg * math.pi / 180;
  var probes = 0;
  double? error(double aim) {
    probes++;
    final p = probe(input.copyWith(aimAngle: aim), maxRails: rails.length);
    final at = p.cueAtContact;
    if (at == null || p.cuePocket != null || !_sameRails(p.railsBefore, rails)) return null;
    return lateralAt(at, input.object) - lateral;
  }

  final start = input.aimAngle;
  var xa = start;
  var maybe = error(xa);
  for (var k = 1; maybe == null && probes < maxContactProbes; k++) {
    xa = start + (k.isOdd ? 1 : -1) * ((k + 1) ~/ 2) * startStep;
    maybe = error(xa);
  }
  if (maybe == null) return (aim: start, converged: false);
  var ea = maybe;
  var bestX = xa, bestE = ea.abs();
  if (bestE < tol) return (aim: xa, converged: true);

  var xb = xa + 1e-3;
  var second = error(xb);
  if (second == null) {
    xb = xa - 1e-3;
    second = error(xb);
  }
  if (second == null) return (aim: bestX, converged: false);
  var eb = second;
  if (eb.abs() < bestE) {
    bestX = xb;
    bestE = eb.abs();
  }

  while (bestE >= tol && probes < maxContactProbes && eb != ea) {
    var step = -eb * (xb - xa) / (eb - ea);
    if (step.abs() > maxStep) step = maxStep * step.sign;
    var xc = xb + step;
    var ec = error(xc);
    // Sai chuỗi băng hay trượt bi: lùi nửa bước về điểm còn đúng.
    while (ec == null && probes < maxContactProbes) {
      step /= 2;
      xc = xb + step;
      ec = error(xc);
    }
    if (ec == null) break;
    xa = xb;
    ea = eb;
    xb = xc;
    eb = ec;
    if (eb.abs() < bestE) {
      bestX = xb;
      bestE = eb.abs();
    }
  }
  return (aim: bestX, converged: bestE < tol);
}

/// Một đơn vị việc "dò": hướng cơ (và `b` khi Đánh đứng bi) của phương án
/// [o]. null khi không hội tụ hay lõi quá giờ — phương án bị bỏ (spec 3.4).
AimResult? aimSafety(SafetyOption o,
    {required Vec2 cue,
    SafetyPhysics physics = const SafetyPhysics(),
    TableSpec table = TableSpec.nineFoot}) {
  try {
    var input = ShotInput(
      cue: cue,
      object: o.ball,
      // Bù sẵn góc lệch do áp phê, như solveAim: không có bước này, áp phê
      // nhiều ở xa làm lần chạm thử đầu trượt hẳn bi.
      aimAngle: o.initialAim + squirtAngle(sideOffsetOf(o.spin), table.radius),
      power: o.power,
      verticalOffset: strokeVerticalOffset(o.stroke, table.radius),
      spin: o.spin,
      elevation: CueElevation.normal.radians,
      table: table,
    );
    var stunReached = true;
    if (o.stroke == Stroke.stun) {
      // Như aimShot: `b` đổi hướng đi (swerve, góc bật băng), hướng đổi
      // quãng đường nên đổi `b`. Dò hướng ở b = 0, dò `b` ở hướng đó, rồi
      // dò hướng lần nữa cho khớp `b` cuối.
      final first = refineContact(input, o.lateral, o.rails, physics.probe);
      if (!first.converged) return null;
      (input, stunReached) = solveStun(input.copyWith(aimAngle: first.aim), topspin: (i) {
        final p = physics.probe(i, maxRails: o.rails.length);
        final s = p.cueAtContact;
        return s == null || p.cuePocket != null ? null : topspinOf(s);
      });
    }
    final r = refineContact(input, o.lateral, o.rails, physics.probe);
    if (!r.converged) return null;
    return (key: keyOf(input.copyWith(aimAngle: r.aim)), stunReached: stunReached);
  } on SimulationTimeout {
    return null;
  }
}

/// Một đơn vị việc "mô phỏng": vết đủ của [key]; null khi lõi quá giờ
/// (Planner không bao giờ hỏi chờ, spec mục 7).
ShotTrace? simulateSafety(SimKey key,
    {SafetyPhysics physics = const SafetyPhysics(), TableSpec table = TableSpec.nineFoot}) {
  try {
    return physics.simulate(inputOf(key, table: table));
  } on SimulationTimeout {
    return null;
  }
}
/// Góc xoay từ hướng hình học sang hướng đã dò, độ, dương là về phía tâm
/// bi (dày hơn) — cùng quy ước `AimSolution.aimOffsetDeg`. Chỉ dùng bên
/// trong (đổi ra đầu cơ ở dòng áp phê), không bao giờ hiện thành độ.
double aimOffsetDegOf(SafetyOption o, Vec2 cue, double aim) {
  Vec2 dir(double a) => Vec2(math.cos(a), math.sin(a));
  final from = dir(o.initialAim);
  final thicker = from.cross(o.ball - cue) >= 0 ? 1.0 : -1.0;
  return thicker * from.signedAngleTo(dir(aim)) * 180 / math.pi;
}
