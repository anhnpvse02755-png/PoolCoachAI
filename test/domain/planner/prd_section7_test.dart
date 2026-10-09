import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';
import '../../support/table_layouts.dart';

/// PRD §7 — chín test bắt buộc, chạy trên lõi vật lý thật (spec mục 10.1).
/// Bàn hết đúng điều kiện sau khi chỉnh hằng số thì dò lại bằng
/// fixture_probe_test.dart, đừng nới điều kiện.
void main() {
  late Map<String, List<PlanStep>> plans;

  setUpAll(() {
    plans = {
      'order9': planToEnd(orderTable(GameType.nineBall)),
      'order10': planToEnd(orderTable(GameType.tenBall)),
      'order8': planToEnd(orderTable(GameType.eightBall)),
      'rail': planToEnd(railTable()),
      'corner': planToEnd(cornerFollowTable()),
      'blocked': planToEnd(blockedEverywhereTable()),
      'fallback': planToEnd(fallbackTable()),
      'typical9': planToEnd(typicalNineBallTable()),
      'eightLast': planToEnd(eightLastTable()),
      'eight8': planToEnd(eightWithOpponentsTable()),
      'penultimate': planToEnd(penultimateTable()),
    };
  });

  double penalties(ScoredOption o) => o.score.bank + o.score.tech + o.score.power;

  test('1. nối liền trên mọi bàn của bộ test', () {
    for (final MapEntry(:key, :value) in plans.entries) {
      for (var i = 0; i + 1 < value.length; i++) {
        expect(identical(value[i].trace!.cueEnd, value[i + 1].cbFrom), isTrue,
            reason: '$key bước $i');
      }
    }
  });

  for (final (game, plan) in const [(GameType.nineBall, 'order9'), (GameType.tenBall, 'order10')]) {
    test('2. ${game.name}: đánh đúng 1 → 2 → 3 → 4 dù bi 3 dễ hơn bi 1', () {
      final s = orderTable(game);
      double angleOf(int n) => bestAngleFrom(s.cue, s.balls[n - 1].pos,
          [for (final b in s.balls) if (b.number != n) b.pos])!;
      expect(angleOf(3), lessThan(angleOf(1)));
      final steps = plans[plan]!;
      expect(steps.map((x) => x.ballNum), [1, 2, 3, 4]);
      expect(steps.every((x) => x.kind != PlanStepKind.safety), isTrue);
    });
  }

  group('3. 8 bi', () {
    test('mọi bi là của tôi: được đánh bi dễ trước', () {
      final steps = plans['order8']!;
      expect(steps.first.ballNum, 3);
      final hit = [for (final x in steps) if (x.kind != PlanStepKind.safety) x.ballNum];
      expect(hit.toSet().length, hit.length);
    });

    test('bi 8 luôn cuối, kể cả khi dễ nhất', () {
      final s = eightLastTable();
      // Bi 8 thẳng 0° từ bi cái: dễ hơn mọi bi của tôi.
      double angleOf(int n) => bestAngleFrom(s.cue, s.balls.firstWhere((b) => b.number == n).pos,
          [for (final b in s.balls) if (b.number != n) b.pos])!;
      expect(angleOf(8), lessThan(angleOf(1)));
      expect(angleOf(8), lessThan(angleOf(2)));

      final steps = plans['eightLast']!;
      expect(steps.first.ballNum, 2);
      final hit = [for (final x in steps) if (x.kind != PlanStepKind.safety) x.ballNum];
      // Bi 8 được lên kế hoạch đúng một lần, là bước đánh cuối, sau cả 1 và 2:
      // không qua được nếu kế hoạch không bao giờ tới bi 8.
      expect(hit.where((n) => n == 8), hasLength(1));
      expect(hit.last, 8);
      expect(hit.sublist(0, hit.length - 1), containsAll([1, 2]));
    });

    test('không bao giờ đánh bi đối thủ', () {
      final steps = plans['eight8']!;
      expect(steps, isNotEmpty);
      expect(steps.map((x) => x.ballNum), everyElement(isNot(anyOf(9, 10))));
    });

    test('bi đối thủ chắn đường vào lỗ thì cặp bi–lỗ đó bị loại', () {
      expect(planToEnd(opponentBlocksTable()).first.pocket, Pocket.bottomRight);
    });

    test('bi đối thủ trên đường bi cái sau va chạm thì phương án bị loại', () {
      final c = contextFor(railTable());
      final aimed = c.lookup(shotKey(c.geometry, Stroke.stun, 45))!;
      final onPath = aimed.trace.cueAfter[aimed.trace.cueAfter.length ~/ 2];
      expect(rejectionOf(aimed, c.geometry.pocket, [onPath]), Rejection.blocked);
    });

    test('bi áp chót được chọn để bi 8 dễ hơn', () {
      final setup = penultimateTable();
      final eight = setup.balls.firstWhere((b) => b.role == BallRole.eight);
      final c = contextFor(setup);
      expect(c.geometry.object, setup.balls.firstWhere((b) => b.number == 1).pos);

      // Góc cho bi 8 từ điểm dừng của một mức lực; mức hỏng thì blockedAngle.
      // Tính thẳng từ toạ độ bi 8, không qua CandidateFinder.
      double eightAngleAt(ShotKey key) {
        final a = c.lookup(key);
        if (a == null || rejectionOf(a, key.pocket, c.obstacles) != null) return blockedAngle;
        return bestAngleFrom(a.trace.cueEnd, eight.pos, const []) ?? blockedAngle;
      }

      final options = scoreTier(c, tierOneKeys(c.geometry));
      expect(options, isNotEmpty);
      for (final o in options) {
        final why = '${o.key.stroke.name} ${o.key.power}%';
        // Chỉ còn một bi của tôi: không nhìn trước bi thứ hai, vị trí chấm
        // đúng theo cú bi 8 ở cả mức lực danh nghĩa lẫn ±15 %.
        expect(o.score.diff2, isNull, reason: why);
        var expected = eightAngleAt(o.key);
        for (final d in const [-powerJitter, powerJitter]) {
          final j = eightAngleAt(withPower(o.key, jitteredPower(o.key.power, d)));
          if (j > expected) expected = j;
        }
        expect(o.score.position, closeTo(expected, 1e-9), reason: why);
      }

      final chosen = bestOf(options)!;
      final s = plans['penultimate']!.first;
      expect(s.ballNum, 1);
      expect(s.kind, PlanStepKind.normal);
      expect(s.nextBallNum, 8);
      expect(s.stroke, chosen.key.stroke);
      expect(s.power, chosen.key.power);
      expect(plans['penultimate']!.map((x) => x.ballNum), [1, 8]);

      // Có phương án dễ đánh hơn (ít phạt hơn) nhưng để lại bi 8 khó hơn —
      // nó thua chính vì bi 8. Đo trên 6b21317: Đánh cu lê 30 % phạt 6.2,
      // bi 8 chịu sai số 36.50°; phương án chọn Đánh đứng bi 90 % phạt 10.6,
      // 10.28°.
      final cheaperButHarderEight = options.where((o) =>
          penalties(o) < penalties(chosen) &&
          o.score.position > chosen.score.position &&
          o.score.total > chosen.score.total);
      expect(cheaperButHarderEight, isNotEmpty);
    });
  });

  test('4. dội băng: điểm chạm nằm đúng trên biên, đường sau va chạm đi qua theo thứ tự', () {
    const table = TableSpec.nineFoot;
    final trace = plans['rail']!.first.trace!;
    final hits = [
      for (final h in trace.rails)
        if (h.ball == ShotBall.cue && h.afterContact) h.pos,
    ];
    expect(hits, isNotEmpty);
    for (final p in hits) {
      expect(p.x == table.minX || p.x == table.maxX || p.y == table.minY || p.y == table.maxY,
          isTrue,
          reason: '$p');
    }
    var from = 0;
    for (final p in hits) {
      final at = trace.cueAfter.indexOf(p, from);
      expect(at, greaterThanOrEqualTo(from), reason: '$p');
      from = at + 1;
    }
  });

  test('5. chịu sai số lực thắng gần bi kế tiếp', () {
    final setup = railTable();
    final nextBall = setup.balls.firstWhere((b) => b.number == 2).pos;
    final c = contextFor(setup);
    final options = scoreTier(c, tierOneKeys(c.geometry));
    final chosen = bestOf(options)!;

    // Điểm nếu chỉ chấm góc tại điểm dừng danh nghĩa, bỏ ±15 %. Bàn 2 bi nên
    // không có diff2: công thức này đúng y tổng điểm trừ khoản chịu sai số.
    double nominalAngle(ScoredOption o) => c.next.easiest(o.aimed.trace.cueEnd, c.after)!.angle;
    double nominalTotal(ScoredOption o) => nominalAngle(o) + penalties(o) + o.score.distance;
    for (final o in options) {
      expect(o.score.diff2, isNull);
      // Phương trình mà phép so dưới đây dựa vào: thêm khoản điểm mới thì vỡ ở đây.
      expect(o.score.total,
          closeTo(o.score.robustDiff1! + penalties(o) + o.score.distance, 1e-9));
    }

    // Phương án A: dừng gần bi kế tiếp hơn, và chỉ xét góc danh nghĩa thì A
    // thắng. Đo trên 6b21317: Đánh đứng bi 30 % dừng cách bi 2 32.8 cm (phương
    // án chọn 46.9 cm), góc danh nghĩa 0.11° so với 13.24°.
    final closer = options
        .where((a) =>
            a.aimed.trace.cueEnd.distanceTo(nextBall) <
                chosen.aimed.trace.cueEnd.distanceTo(nextBall) &&
            a.score.distance < chosen.score.distance &&
            nominalTotal(a) < nominalTotal(chosen) &&
            nominalTotal(a) < chosen.score.total)
        .toList();
    expect(closer, isNotEmpty);
    final a = closer.reduce((x, y) => nominalTotal(y) < nominalTotal(x) ? y : x);

    // Nhưng A hỏng khi lực lệch 15 %: một mức jitter bị loại, góc tính là
    // blockedAngle, nên vùng điều chịu sai số của A tệ hơn của B.
    expect(a.score.robustDiff1, blockedAngle);
    expect(a.score.robustDiff1!, greaterThan(chosen.score.robustDiff1!));
    final failing = [
      for (final d in const [-powerJitter, powerJitter])
        if (c.angleAt(c.lookup(withPower(a.key, jitteredPower(a.key.power, d)))) ==
            blockedAngle)
          d,
    ];
    expect(failing, isNotEmpty);
    expect(a.score.total, greaterThan(chosen.score.total));

    // B được chọn, cả khi chấm trực tiếp lẫn trong kế hoạch.
    expect(identical(bestOf(options), chosen), isTrue);
    expect(plans['rail']!.first.stroke, chosen.key.stroke);
    expect(plans['rail']!.first.power, chosen.key.power);
    expect(plans['rail']!.first.stroke == a.key.stroke && plans['rail']!.first.power == a.key.power,
        isFalse);
  });

  test('6. bi bắt buộc bị chắn ở mọi lỗ: bước phòng thủ, kế hoạch dừng', () {
    final steps = plans['blocked']!;
    expect(steps, hasLength(1));
    expect(steps.single.kind, PlanStepKind.safety);
    expect(steps.single.ballNum, 1);
  });

  test('7. đánh thẳng kèm dội một băng thắng trô không dội băng', () {
    final c = contextFor(railTable());
    final options = scoreTier(c, tierOneKeys(c.geometry));
    final chosen = bestOf(options)!;
    expect(chosen.key.stroke, isNot(Stroke.draw));
    expect(chosen.aimed.trace.cueRailCount, greaterThanOrEqualTo(1));
    // Đo trên c43c74a: trô 30 % không chạm băng, vùng điều 26.21° so với 21.68°.
    final drawNoRail = options.where((d) =>
        d.key.stroke == Stroke.draw &&
        d.aimed.trace.cueRailCount == 0 &&
        d.score.position >= chosen.score.position &&
        d.score.position - chosen.score.position <= techPenaltyDraw - bankPenaltyOneRail);
    expect(drawNoRail, isNotEmpty);
  });

  test('8. phương án chết cái bị loại dù vị trí tốt hơn', () {
    final c = contextFor(cornerFollowTable());
    final step = plans['corner']!.first;
    expect(step.trace!.cuePocket, isNull);
    expect(step.stroke, Stroke.stun);
    for (final p in powerCandidates) {
      final a = c.lookup(shotKey(c.geometry, Stroke.follow, p))!;
      expect(rejectionOf(a, c.geometry.pocket, c.obstacles), Rejection.scratch);
      // Đo trên c43c74a: từ miệng lỗ bi 2 cắt 12.6°, phương án chọn 18.95°.
      final there = c.next.easiest(a.trace.cueEnd, c.after)!.angle;
      expect(there, lessThan(step.score!.robustDiff1!), reason: 'cu lê $p%');
    }
  });

  test('9. dư dày / mỏng: cắt mỏng nhạy hơn rõ rệt, bi cuối không lỗi', () {
    final thin = geometryFor(tableCenter, Pocket.topRight, 65);
    final thick = geometryFor(tableCenter, Pocket.topRight, 15);
    expect(missErrDeg(thin.angle), greaterThan(2 * missErrDeg(thick.angle)));
    expect(() => missSafetyAdvice(thin, const []), returnsNormally);
    final last = plans['order9']!.last;
    expect(last.missAdvice, isNull);
  });

  test('bàn 9 bi điển hình: bi 5 chắn lỗ giữa dưới nên bước 1 đi góc dưới phải', () {
    final s = plans['typical9']!.first;
    expect(s.ballNum, 1);
    expect(s.pocket, Pocket.bottomRight);
  });
}
