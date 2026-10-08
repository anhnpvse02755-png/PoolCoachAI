import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_scoring.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Tra giả: trả đúng một kết quả dò, vết theo lực; ghi lại lần gọi.
class _FakeLookup implements SafetyLookup {
  _FakeLookup(this.result, this.byPower);
  final AimResult? result;
  final ShotTrace? Function(double power) byPower;
  var aimCalls = 0;
  final powers = <double>[];

  @override
  AimResult? aim(int index) {
    aimCalls++;
    return result;
  }

  @override
  ShotTrace? trace(SimKey key) {
    powers.add(key.power);
    return byPower(key.power);
  }
}

void main() {
  const table = TableSpec.nineFoot;

  // Bàn nhỏ: bi cái (30, 80) đánh trọn bi 1 ở (180, 80); bi 2 ở (105, 20).
  const cue = Vec2(30, 80);
  const ball = Vec2(180, 80);
  const contact = Vec2(174.285, 80);
  final ctx = SafetyContext(game: GameType.nineBall, cue: cue, balls: const [
    PlacedBall(number: 1, pos: ball),
    PlacedBall(number: 2, pos: Vec2(105, 20)),
  ]);
  final option = directOption(ctx, ctx.legal.single, 1, ThicknessSide.full, Stroke.stun,
      const SideSpin.none(), 45)!;
  final objectRail = RailHit(
      ball: ShotBall.object, pos: Vec2(table.maxX, 80), rail: Rail.right, afterContact: true);

  ShotTrace traceOf({
    List<Vec2> cueBefore = const [cue, contact],
    List<Vec2> cueAfter = const [contact, Vec2(160, 60)],
    List<Vec2> objectPath = const [ball, Vec2(200, 100)],
    List<RailHit>? rails,
    Pocket? cuePocket,
    Pocket? objectPocket,
    bool touched = true,
  }) =>
      ShotTrace(
        cueBefore: cueBefore,
        cueAfter: touched ? cueAfter : const [],
        objectPath: objectPath,
        contactCue: touched ? cueBefore.last : null,
        rails: rails ?? [objectRail],
        cuePocket: cuePocket,
        objectPocket: objectPocket,
        cueEnd: touched ? cueAfter.last : cueBefore.last,
      );

  group('luật (spec 3.5) trên vết dựng tay', () {
    final obstacles = ctx.obstaclesOf(1);
    SafetyFoul? foul(ShotTrace t, {int rails = 0, List<Vec2>? others}) =>
        safetyFoulOf(t, rails: rails, obstacles: others ?? obstacles);

    test('đúng luật: chạm bi hợp lệ trước, có bi chạm băng sau va chạm', () {
      expect(foul(traceOf()), isNull);
    });

    test('mỗi kiểu phạm lỗi bị gọi đúng tên', () {
      expect(foul(traceOf(touched: false)), SafetyFoul.missed);
      expect(foul(traceOf(), others: const [Vec2(105, 80)]), SafetyFoul.hitOtherFirst);
      expect(foul(traceOf(), rails: 1), SafetyFoul.wrongRailCount);
      final cueRail = RailHit(
          ball: ShotBall.cue, pos: Vec2(105, table.minY), rail: Rail.top, afterContact: false);
      expect(foul(traceOf(rails: [cueRail, objectRail])), SafetyFoul.wrongRailCount);
      expect(foul(traceOf(rails: [cueRail, objectRail]), rails: 1), isNull);
      expect(foul(traceOf(cuePocket: Pocket.topRight)), SafetyFoul.scratch);
      expect(foul(traceOf(objectPocket: Pocket.bottomRight)), SafetyFoul.legalPocketed);
      expect(foul(traceOf(rails: const [])), SafetyFoul.noRail);
      expect(foul(traceOf(), others: const [Vec2(190, 90)]), SafetyFoul.objectBlocked);
      expect(foul(traceOf(), others: const [Vec2(167, 70)]), SafetyFoul.cueAfterBlocked);
    });

    test('phạm luật thì mức đó tính phần đối thủ 95, không cộng sát băng, khoảng cách', () {
      final l = levelOf(ctx, option, traceOf(cuePocket: Pocket.topRight));
      expect(l.foul, SafetyFoul.scratch);
      expect(l.value, blockedAngle);
      expect(l.opponent, isNull);
      expect(levelOf(ctx, option, null).foul, SafetyFoul.timeout);
    });
  });

  group('luật trên lõi vật lý thật (test 9.1.2)', () {
    SafetyFoul? realFoul(TableSetup s, double thickness, Stroke stroke, double power) {
      final c = SafetyContext(game: s.game, cue: s.cue, balls: s.balls);
      final o = directOption(c, c.legal.first, thickness,
          thickness == 1 ? ThicknessSide.full : ThicknessSide.left, stroke,
          const SideSpin.none(), power)!;
      final r = aimSafety(o, cue: c.cue)!;
      return levelOf(c, o, simulateSafety(r.key)).foul;
    }

    test('chạm bi khác trước: đánh thẳng qua bi chắn', () {
      expect(realFoul(snookerOneRailTable(), 1, Stroke.stun, 60), SafetyFoul.hitOtherFirst);
    });

    test('không bi nào chạm băng: chạm rất nhẹ giữa bàn', () {
      const s = TableSetup(
          game: GameType.nineBall,
          cue: Vec2(110, 63.5),
          balls: [PlacedBall(number: 1, pos: Vec2(127, 63.5))]);
      // Cu lê: ở 3 % Đánh đứng bi dò `b` dưới tâm và bi cái không tới bi
      // (kiểm trên a35667b khi viết kế hoạch).
      expect(realFoul(s, 1, Stroke.follow, 3), SafetyFoul.noRail);
    });

    test('chết cái và bi hợp lệ rơi lỗ: bi thẳng lỗ góc', () {
      // Đo trên c43c74a (kế hoạch dọn bàn, test 8): cu lê theo bi vào lỗ ở
      // mọi mức lực; Đánh đứng bi 90 % đưa bi vào mà bi cái không rơi.
      expect(realFoul(cornerFollowTable(), 1, Stroke.follow, 60), SafetyFoul.scratch);
      expect(realFoul(cornerFollowTable(), 1, Stroke.stun, 90), SafetyFoul.legalPocketed);
    });
  });

  group('đối thủ phải đánh bi nào (spec 4.4, test 9.1.8)', () {
    test('9 bi: bi vừa chạm, ở vị trí mới', () {
      const moved = Vec2(200, 100);
      final l = levelOf(ctx, option, traceOf(objectPath: const [ball, moved]));
      expect(l.opponent!.ball!.number, 1);
      expect(l.opponent!.ball!.pos, moved);
    });

    test('8 bi: bi nhóm kia; hết thì bi 8; không còn bi nào thì không lỗi', () {
      const mine = PlacedBall(number: 1, pos: Vec2(100, 60));
      const theirs = PlacedBall(number: 9, pos: Vec2(200, 30), role: BallRole.opponent);
      const eight = PlacedBall(number: 8, pos: Vec2(60, 100), role: BallRole.eight);
      expect(opponentTargets(GameType.eightBall, const [mine, theirs, eight]), [theirs]);
      expect(opponentTargets(GameType.eightBall, const [mine, eight]), [eight]);
      expect(opponentTargets(GameType.eightBall, const [mine]), isEmpty);
      final none = opponentView(game: GameType.eightBall, cue: const Vec2(30, 30), balls: const [mine]);
      expect(none.snookered, isFalse);
      expect(none.ball, isNull);
      expect(none.part, 0);
      expect(none.hard, isTrue);
    });
  });

  group('chấm một mức lực (spec 4.1)', () {
    test('đối thủ bị đui: phần đối thủ 0, sát băng −5, trừ khoảng cách', () {
      // Bi cái dừng sát băng trên, bi 2 nằm giữa bi cái và bi 1.
      const end = Vec2(105, 5);
      const moved = Vec2(105, 60);
      final l = levelOf(ctx, option,
          traceOf(cueAfter: const [contact, end], objectPath: const [ball, moved]));
      expect(l.opponent!.snookered, isTrue);
      expect(l.value, closeTo(-nearRailBonus - end.distanceTo(moved) * distanceWeight, 1e-9));
    });

    test('không đui: 95 − góc cắt dễ nhất, đúng bestPocket với các bi còn lại', () {
      const end = Vec2(160, 60);
      const moved = Vec2(200, 100);
      final l = levelOf(ctx, option, traceOf(objectPath: const [ball, moved]));
      final g = bestPocket(cue: end, object: moved, others: const [Vec2(105, 20)])!;
      expect(l.opponent!.easiest!.pocket, g.pocket);
      expect(l.value, closeTo(blockedAngle - g.angle - end.distanceTo(moved) * distanceWeight, 1e-9));
    });

    test('không lỗ nào thì phần đối thủ là 0', () {
      const v = OpponentView(snookered: false, ball: PlacedBall(number: 1, pos: Vec2(1, 1)));
      expect(v.part, 0);
      expect(v.hard, isTrue);
    });
  });

  group('điểm phương án (spec 4.2)', () {
    test('phạt kỹ thuật, A băng và lực cộng dồn', () {
      final kick = kickOption(SafetyContext(game: GameType.nineBall, cue: cue, balls: snookerOneRailTable().balls),
          const PlacedBall(number: 1, pos: Vec2(180, 80)), const [Rail.top], 1, ThicknessSide.full,
          Stroke.follow, 60)!;
      expect(safetyPenaltyOf(kick),
          closeTo(techPenaltyFollow + kickRailPenalty[1]! + 60 * powerPenaltyPerPercent, 1e-12));
      final spun = directOption(ctx, ctx.legal.single, 0.5, ThicknessSide.left, Stroke.draw,
          const SideSpin(SpinSide.left, 1), 30)!;
      expect(safetyPenaltyOf(spun),
          closeTo(techPenaltyDraw + sidePenaltyOneTip + 30 * powerPenaltyPerPercent, 1e-12));
      expect([for (var n = 1; n <= maxKickRails; n++) kickPenaltyFor(n)],
          [for (var n = 1; n <= maxKickRails; n++) kickRailPenalty[n]]);
      expect(kickPenaltyFor(0), 0);
    });

    test('lấy mức xấu nhất trong ±15 %; mức phạm luật tính 95', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final lookup = _FakeLookup(aim, (p) => p == 60 ? traceOf(cuePocket: Pocket.topRight) : traceOf());
      final e = evaluateOption(ctx, 0, option, lookup)!;
      expect(e.levels, hasLength(3));
      expect(e.worst, blockedAngle);
      expect(e.total, closeTo(blockedAngle + safetyPenaltyOf(option), 1e-12));
      expect(lookup.powers, [45, 30, 60]);
    });

    test('lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức', () {
      final o = directOption(ctx, ctx.legal.single, 1, ThicknessSide.full, Stroke.stun,
          const SideSpin.none(), 90)!;
      const key = (cue: cue, object: ball, aim: 0.0, power: 90.0, b: 0.0, spin: SideSpin.none());
      final powers = <double>[];
      final hard = safetyToleranceOf(ctx, o, key, (k) {
        powers.add(k.power);
        return traceOf();
      });
      expect(powers, hasLength(toleranceSamples));
      expect(powers.reduce(math.max), maxPower);
      expect(hard, inInclusiveRange(0, toleranceSamples));
    });

    test('cắt tỉa đúng: chặn dưới vượt điểm tốt nhất thì không dò, mức chọn đã thua thì không thử ±15 %', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final early = _FakeLookup(aim, (_) => traceOf());
      expect(evaluateOption(ctx, 0, option, early, bound: safetyPenaltyOf(option) + scoreFloor(table)),
          isNull);
      expect(early.aimCalls, 0);

      final base = levelOf(ctx, option, traceOf());
      final late = _FakeLookup(aim, (_) => traceOf());
      expect(evaluateOption(ctx, 0, option, late, bound: base.value + safetyPenaltyOf(option)), isNull);
      expect(late.powers, [45]);
    });

    test('chặn dưới không bao giờ vượt điểm thật', () {
      // Mọi mức: phần đối thủ ≥ 0, hai bi sát băng, khoảng cách ≤ đường chéo.
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final e = evaluateOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf()))!;
      expect(e.total, greaterThanOrEqualTo(safetyPenaltyOf(option) + scoreFloor(table)));
    });

    test('bằng điểm thì giữ phương án thử trước', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final a = evaluateOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf()))!;
      final b = evaluateOption(ctx, 1, option, _FakeLookup(aim, (_) => traceOf()))!;
      expect(b.total, a.total);
      expect(beats(b, a), isFalse);
      expect(beats(a, null), isTrue);
    });

    test('hợp lệ không tuỳ cắt tỉa: hỏi được cả phương án cắt tỉa đã bỏ, chỉ lực chọn', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final skipped = _FakeLookup(aim, (_) => traceOf());
      expect(evaluateOption(ctx, 0, option, skipped, bound: safetyPenaltyOf(option) + scoreFloor(table)),
          isNull);
      expect(isLegalOption(ctx, 0, option, skipped), isTrue);
      expect(skipped.powers, [45]);
      expect(isLegalOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf(cuePocket: Pocket.topRight))),
          isFalse);
      expect(isLegalOption(ctx, 0, option, _FakeLookup(null, (_) => traceOf())), isFalse);
      expect(isLegalOption(ctx, 0, option, _FakeLookup(aim, (_) => null)), isFalse);
    });

    test('cú đơn giản thắng khi gần ngang (test 9.1.7): trực tiếp đứng bi hơn A băng 2 băng', () {
      // Trực tiếp và A băng nay thi trong cùng một lần tìm (chủ sản phẩm chốt
      // 08/10/2026); safety_spec_test kiểm điều đó trên bàn thật. Ở đây kiểm
      // đúng cách cộng điểm qua evaluateOption: cùng kiểu đánh và lực, nên
      // phạt hai phương án chỉ khác nhau đúng phạt A băng. Cú A băng 2 băng
      // chấm vị trí tốt hơn (kickPenaltyFor(2) − 1) vẫn thua; nếu bỏ phạt băng
      // thì nó thắng và test này đỏ.
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final kick = kickOption(ctx, ctx.legal.single, const [Rail.top, Rail.bottom], 1,
          ThicknessSide.full, Stroke.stun, 45)!;
      expect(kick.rails, hasLength(2));
      expect(safetyPenaltyOf(kick) - safetyPenaltyOf(option), closeTo(kickPenaltyFor(2), 1e-12));

      final directEval = evaluateOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf()))!;
      final directValue = directEval.worst;

      // Vết A băng: hai băng bi cái chạm trước va chạm. Đẩy bi chạm tới đâu để
      // điểm vị trí thấp hơn trực tiếp đúng [gap] — chia đôi trên đoạn a → b
      // (điểm vị trí liên tục theo vị trí bi).
      final railA = RailHit(ball: ShotBall.cue, pos: Vec2(60, table.minY), rail: Rail.top, afterContact: false);
      final railB = RailHit(ball: ShotBall.cue, pos: Vec2(120, table.maxY), rail: Rail.bottom, afterContact: false);
      ShotTrace kickTrace(Vec2 moved) =>
          traceOf(rails: [railA, railB, objectRail], objectPath: [ball, moved]);
      double kickValue(Vec2 moved) => levelOf(ctx, kick, kickTrace(moved)).value;
      Vec2 kickEndFor(double gap) {
        // Dưới trực tiếp [gap] điểm.
        var lo = _kickFrom, hi = _kickTo;
        final target = directValue - gap;
        final loBelow = kickValue(lo) < target;
        expect(loBelow != (kickValue(hi) < target), isTrue, reason: 'đoạn dò phải bao điểm cần');
        for (var i = 0; i < 60; i++) {
          final mid = Vec2((lo.x + hi.x) / 2, (lo.y + hi.y) / 2);
          if ((kickValue(mid) < target) == loBelow) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        return lo;
      }

      final near = kickEndFor(kickPenaltyFor(2) - 1);
      expect(directValue - kickValue(near), closeTo(kickPenaltyFor(2) - 1, 1e-6));
      final almost = evaluateOption(ctx, 0, kick, _FakeLookup(aim, (_) => kickTrace(near)))!;
      expect(almost.worst, lessThan(directEval.worst));
      expect(almost.total, greaterThan(directEval.total));
      expect(beats(almost, directEval), isFalse);

      // Đối chứng: tốt hơn (kickPenaltyFor(2) + 1) thì A băng thắng.
      final clear = evaluateOption(
          ctx, 0, kick, _FakeLookup(aim, (_) => kickTrace(kickEndFor(kickPenaltyFor(2) + 1))))!;
      expect(beats(clear, directEval), isTrue);
    });
  });
}

// Đoạn dò vị trí bi chạm cho test 9.1.7 (điểm vị trí ở hai đầu lệch nhau quá 20 điểm nên bao điểm cần).
const _kickFrom = Vec2(170, 100);
const _kickTo = Vec2(190, 100);
