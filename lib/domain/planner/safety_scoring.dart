import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Bi đối thủ phải đánh sau cú thủ (spec 4.4). 9 / 10 bi: bi số nhỏ nhất
/// (chính bi vừa chạm, ở vị trí mới). 8 bi: bi nhóm kia; hết thì bi 8.
List<PlacedBall> opponentTargets(GameType game, List<PlacedBall> balls) {
  if (game != GameType.eightBall) return legalTargetsAmong(game, balls);
  final sorted = [...balls]..sort((a, b) => a.number.compareTo(b.number));
  final theirs = [for (final b in sorted) if (b.role == BallRole.opponent) b];
  return theirs.isNotEmpty ? theirs : [for (final b in sorted) if (b.role == BallRole.eight) b];
}

/// Thế bàn đối thủ nhận với bi cái ở [cue] và các bi ở [balls].
OpponentView opponentView({
  required GameType game,
  required Vec2 cue,
  required List<PlacedBall> balls,
  TableSpec table = TableSpec.nineFoot,
}) {
  final targets = opponentTargets(game, balls);
  if (targets.isEmpty) return const OpponentView(snookered: false);
  final seen = targets.any((t) => canSee(cue, t.pos, obstaclesFor(t, balls), table: table));
  if (!seen) return OpponentView(snookered: true, ball: targets.first);
  PlacedBall? bestBall;
  ShotGeometry? best;
  for (final t in targets) {
    final g = bestPocket(cue: cue, object: t.pos, others: obstaclesFor(t, balls), table: table);
    if (g == null) continue;
    if (best == null || compareShots(g, best, table: table) < 0) {
      best = g;
      bestBall = t;
    }
  }
  return OpponentView(snookered: false, ball: bestBall ?? targets.first, easiest: best);
}

/// Điểm một mức lực (spec 4.1): thấp là tốt.
class SafetyLevel {
  const SafetyLevel({required this.value, this.foul, this.opponent, this.cueEnd});

  /// Phạm luật: phần đối thủ 95, không cộng sát băng và khoảng cách.
  const SafetyLevel.foul(SafetyFoul this.foul)
      : value = blockedAngle,
        opponent = null,
        cueEnd = null;

  final double value;
  final SafetyFoul? foul;
  final OpponentView? opponent;
  final Vec2? cueEnd;
}

/// Chấm vết [t] của phương án [o]; null là lõi quá giờ.
SafetyLevel levelOf(SafetyContext c, SafetyOption o, ShotTrace? t) {
  if (t == null) return const SafetyLevel.foul(SafetyFoul.timeout);
  final foul = safetyFoulOf(t,
      rails: o.rails.length, obstacles: c.obstaclesOf(o.ballNum), table: c.table);
  if (foul != null) return SafetyLevel.foul(foul);
  final view = opponentView(
      game: c.game, cue: t.cueEnd, balls: c.after(o.ballNum, t.objectPath.last), table: c.table);
  var value = view.part;
  if (nearRail(t.cueEnd, table: c.table)) value -= nearRailBonus;
  final ball = view.ball;
  if (ball != null) {
    if (nearRail(ball.pos, table: c.table)) value -= nearRailBonus;
    value -= t.cueEnd.distanceTo(ball.pos) * distanceWeight;
  }
  return SafetyLevel(value: value, opponent: view, cueEnd: t.cueEnd);
}

double kickPenaltyFor(int rails) => rails == 0 ? 0 : kickRailPenalty[rails]!;

/// Phạt kỹ thuật + A băng + lực (spec 4.2).
double safetyPenaltyOf(SafetyOption o) =>
    techPenaltyFor(o.stroke, o.spin) + kickPenaltyFor(o.rails.length) + powerPenaltyFor(o.power);

/// Điểm một mức thấp nhất có thể: đối thủ đui (0), hai bi sát băng, và hai
/// bi xa nhau hết đường chéo bàn. Chặn dưới để bỏ phương án không thể thắng.
double scoreFloor(TableSpec table) {
  final w = table.maxX - table.minX;
  final h = table.maxY - table.minY;
  return -(2 * nearRailBonus + math.sqrt(w * w + h * h) * distanceWeight);
}

/// Tra một lần dò hay một lần mô phỏng. Việc tính chia lát ném lỗi khi chưa
/// có kết quả; test thay bằng tra giả để đếm và điều khiển từng lần gọi.
abstract interface class SafetyLookup {
  AimResult? aim(int index);
  ShotTrace? trace(SimKey key);
}

/// Một phương án đã chấm.
class SafetyEval {
  const SafetyEval({
    required this.option,
    required this.index,
    required this.aim,
    required this.base,
    required this.levels,
    required this.penalty,
  });

  final SafetyOption option;
  final int index;
  final AimResult aim;

  /// Vết ở lực đã chọn.
  final ShotTrace base;

  /// Lực chọn, −15 %, +15 % (kẹp ≤ 100 %).
  final List<SafetyLevel> levels;
  final double penalty;

  double get worst => levels.map((l) => l.value).reduce(math.max);
  double get total => worst + penalty;
}

/// Chấm phương án thứ [index] (spec 4.1–4.2). null khi không hội tụ, lực
/// chọn phạm luật, hay không thể thắng [bound] (điểm tốt nhất tới giờ):
/// bằng điểm thì phương án trước giữ, nên `>=` là đủ để bỏ.
SafetyEval? evaluateOption(SafetyContext c, int index, SafetyOption o, SafetyLookup lookup,
    {double? bound}) {
  final penalty = safetyPenaltyOf(o);
  if (bound != null && penalty + scoreFloor(c.table) >= bound) return null;
  final aim = lookup.aim(index);
  if (aim == null) return null;
  final base = lookup.trace(aim.key);
  final level = levelOf(c, o, base);
  if (base == null || level.foul != null) return null;
  // Mức xấu nhất không tốt hơn mức chọn: mức chọn đã thua thì khỏi thử ±15 %.
  if (bound != null && level.value + penalty >= bound) return null;
  final levels = [level];
  for (final delta in const [-powerJitter, powerJitter]) {
    levels.add(levelOf(c, o, lookup.trace(withSimPower(aim.key, jitteredPower(o.power, delta)))));
  }
  return SafetyEval(option: o, index: index, aim: aim, base: base, levels: levels, penalty: penalty);
}

/// Phương án thứ [index] hợp lệ ở lực đã chọn: dò hội tụ và vết đúng luật —
/// đúng điều kiện [evaluateOption] đòi trước khi chấm, nhưng không cắt tỉa.
/// Áp phê là đường lui (chủ sản phẩm chốt 08/10/2026): biết một bi còn cú
/// không áp phê nào hợp lệ không phải độc lập với cắt tỉa, nếu không thì có
/// cắt tỉa và không cắt tỉa sẽ thử hai tập phương án khác nhau.
bool isLegalOption(SafetyContext c, int index, SafetyOption o, SafetyLookup lookup) {
  final aim = lookup.aim(index);
  if (aim == null) return false;
  final t = lookup.trace(aim.key);
  return t != null &&
      safetyFoulOf(t, rails: o.rails.length, obstacles: c.obstaclesOf(o.ballNum), table: c.table) ==
          null;
}

/// [e] thay được [best]: điểm thấp hơn hẳn. Bằng điểm thì giữ phương án thử
/// trước (spec 4.2), để kết quả tất định.
bool beats(SafetyEval e, SafetyEval? best) => best == null || e.total < best.total;

/// Số mức trong [toleranceSamples] mức lực đều nhau ±[powerJitter] vẫn khó
/// cho đối thủ (spec 4.3) — cùng hàm mô phỏng và chấm với lúc chọn.
int safetyToleranceOf(
    SafetyContext c, SafetyOption o, SimKey key, ShotTrace? Function(SimKey key) trace) {
  var hard = 0;
  const span = 2 * powerJitter;
  for (var k = 0; k < toleranceSamples; k++) {
    final p = jitteredPower(o.power, -powerJitter + k * span / (toleranceSamples - 1));
    final level = levelOf(c, o, trace(withSimPower(key, p)));
    if (level.foul == null && level.opponent!.hard) hard++;
  }
  return hard;
}

/// Dựng bước phòng thủ từ phương án đã chọn (spec 3.7). Độ chịu sai số cần
/// thêm bốn lần mô phỏng: việc tính chia lát tra qua [trace] như mọi lần khác.
SafetyShot buildSafetyShot(
    SafetyContext c, SafetyEval e, ShotTrace? Function(SimKey key) trace) {
  final o = e.option;
  final firstRail =
      e.base.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).firstOrNull;
  final distance = c.cue.distanceTo(o.contact);
  Vec2? endOf(SafetyLevel l) => l.foul == null ? l.cueEnd : null;
  return SafetyShot(
    reason: c.reason,
    kind: o.kind,
    rails: o.rails.length,
    ballNum: o.ballNum,
    thickness: o.thickness,
    side: o.side,
    stroke: o.stroke,
    spin: o.spin,
    power: o.power,
    aimed: AimedShot(
      trace: e.base,
      uncompensated: null,
      aimOffsetDeg: aimOffsetDegOf(o, c.cue, e.aim.key.aim),
      verticalOffset: e.aim.key.b,
      stunReached: e.aim.stunReached,
      converged: true,
    ),
    railAim: firstRail == null
        ? null
        : RailAim(
            rail: firstRail.rail,
            diamond: diamondOf(firstRail.pos, firstRail.rail, table: c.table),
            at: firstRail.pos),
    opponent: e.levels.first.opponent!,
    jitterEnds: (minus: endOf(e.levels[1]), plus: endOf(e.levels[2])),
    tolerance: safetyToleranceOf(c, o, e.aim.key, trace),
    sawsBhePercent: o.spin.isNone
        ? null
        : sawsBhePercent(distance: distance, power: o.power, stroke: o.stroke),
    contactDistance: distance,
    total: e.total,
  );
}
