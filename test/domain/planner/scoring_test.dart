import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

void main() {
  group('điểm phạt (spec mục 3, 5)', () {
    test('dội băng 0 · 2 · 7', () {
      expect(bankPenaltyFor(0), 0);
      expect(bankPenaltyFor(1), bankPenaltyOneRail);
      expect(bankPenaltyFor(2), bankPenaltyManyRails);
      expect(bankPenaltyFor(5), bankPenaltyManyRails);
    });

    test('áp phê cộng dồn với kiểu đánh', () {
      expect(techPenaltyFor(Stroke.stun, const SideSpin.none()), techPenaltyStun);
      expect(techPenaltyFor(Stroke.draw, const SideSpin(SpinSide.left, 1)),
          techPenaltyDraw + sidePenaltyOneTip);
      expect(techPenaltyFor(Stroke.follow, const SideSpin(SpinSide.right, 0.5)),
          techPenaltyFollow + sidePenaltyHalfTip);
    });

    test('dội băng không bị coi là khó: phạt băng tối đa vẫn dưới trô', () {
      expect(bankPenaltyFor(9), lessThan(techPenaltyFor(Stroke.draw, const SideSpin.none())));
      expect(techPenaltyFollow + bankPenaltyOneRail, lessThan(techPenaltyDraw));
    });

    test('lực × hệ số', () {
      expect(powerPenaltyFor(75), 75 * powerPenaltyPerPercent);
    });
  });

  test('bestAngleFrom là góc của bestPocket, null khi mọi lỗ bị chắn', () {
    final s = blockedEverywhereTable();
    final ball1 = s.balls.first.pos;
    final ring = [for (final b in s.balls.skip(1)) b.pos];
    expect(bestAngleFrom(s.cue, ball1, ring), isNull);
    expect(bestAngleFrom(s.cue, ball1, const []),
        bestPocket(cue: s.cue, object: ball1)!.angle);
  });

  test('mười lăm phương án tầng 1 rồi sáu mươi phương án áp phê, đúng thứ tự thử', () {
    final g = contextFor(railTable()).geometry;
    final one = tierOneKeys(g);
    expect(one, hasLength(strokeCandidates.length * powerCandidates.length));
    expect(one.first.stroke, Stroke.stun);
    expect(one[powerCandidates.length].stroke, Stroke.follow);
    expect(one.take(powerCandidates.length).map((k) => k.power), powerCandidates);
    final two = tierTwoKeys(g);
    expect(two,
        hasLength(strokeCandidates.length * 2 * sideTipsCandidates.length * powerCandidates.length));
    expect(two.first.spin, const SideSpin(SpinSide.left, 0.5));
    expect(two[powerCandidates.length].spin, const SideSpin(SpinSide.left, 1));
    expect(two.every((k) => !k.spin.isNone), isTrue);
  });

  group('loại phương án (spec mục 4.3)', () {
    test('chết cái, bi mục tiêu không vào, đi qua bi chắn; cú sạch thì không loại', () {
      final corner = contextFor(cornerFollowTable());
      final follow = corner.lookup(shotKey(corner.geometry, Stroke.follow, 45))!;
      expect(rejectionOf(follow, corner.geometry.pocket, corner.obstacles), Rejection.scratch);
      // Đo trên c43c74a: Đánh đứng bi 15 % không đưa bi 1 tới lỗ.
      final weak = corner.lookup(shotKey(corner.geometry, Stroke.stun, 15))!;
      expect(rejectionOf(weak, corner.geometry.pocket, corner.obstacles), Rejection.objectMissed);

      final rail = contextFor(railTable());
      final clean = rail.lookup(shotKey(rail.geometry, Stroke.stun, 45))!;
      expect(rejectionOf(clean, rail.geometry.pocket, rail.obstacles), isNull);
      final onPath = clean.trace.cueAfter[clean.trace.cueAfter.length ~/ 2];
      expect(rejectionOf(clean, rail.geometry.pocket, [onPath]), Rejection.blocked);
    });

    test('đường một điểm vẫn được kiểm chắn', () {
      expect(polylineClear(const [Vec2(50, 50)], const [Vec2(52, 50)]), isFalse);
      expect(polylineClear(const [Vec2(50, 50)], const [Vec2(80, 50)]), isTrue);
    });

    test('lõi quá giờ thì lookup trả null, không ném', () {
      final g = contextFor(railTable()).geometry;
      final lookup = directLookup(aim: timeoutAim((_, _, _, _) => true));
      expect(lookup(shotKey(g, Stroke.stun, 45)), isNull);
    });
  });

  group('chấm điểm (spec mục 5)', () {
    test('hai bi: vị trí là vùng điều chịu sai số, không có diff2', () {
      final c = contextFor(railTable());
      final key = shotKey(c.geometry, Stroke.stun, 45);
      final aimed = c.lookup(key)!;
      final s = scoreOption(c, key, aimed)!;
      final diff1 = c.next.easiest(aimed.trace.cueEnd, c.after)!.angle;
      expect(s.robustDiff1, greaterThanOrEqualTo(diff1));
      expect(s.diff2, isNull);
      expect(s.position, s.robustDiff1);
      expect(s.bank, bankPenaltyFor(aimed.trace.cueRailCount));
      expect(s.distance, c.geometry.ghost.distanceTo(aimed.trace.cueEnd) * distanceWeight);
      expect(s.total, s.position + s.bank + s.tech + s.power + s.distance);
    });

    test('ba bi trở lên: vị trí là max(robustDiff1, diff2) — minimax, không cộng', () {
      final c = contextFor(orderTable(GameType.nineBall));
      final options = scoreTier(c, tierOneKeys(c.geometry));
      expect(options, isNotEmpty);
      for (final scored in options) {
        final s = scored.score;
        expect(s.diff2, isNotNull);
        expect(s.position, math.max(s.robustDiff1!, s.diff2!));
      }
    });

    test('bi cuối: chỉ các khoản phạt', () {
      final c = contextFor(onlyEightTable());
      final key = shotKey(c.geometry, Stroke.stun, 30);
      final s = scoreOption(c, key, c.lookup(key)!)!;
      expect(c.hasNext, isFalse);
      expect(s.position, 0);
      expect(s.distance, 0);
      expect(s.robustDiff1, isNull);
      expect(s.total, s.bank + s.tech + s.power);
    });

    test('từ điểm dừng không lỗ nào cho bi kế tiếp thì loại phương án', () {
      final c = contextFor(fallbackTable());
      final key = shotKey(c.geometry, Stroke.stun, fallbackPower);
      expect(scoreOption(c, key, c.lookup(key)!), isNull);
    });

    test('bằng điểm thì giữ phương án thử trước', () {
      final c = contextFor(railTable());
      final options = scoreTier(c, tierOneKeys(c.geometry));
      final a = options.first;
      // Bản sao khác đối tượng nhưng cùng điểm: ai thử trước thì thắng.
      final b = ScoredOption(a.key, a.aimed, a.score);
      expect(identical(bestOf([a, b]), a), isTrue);
      expect(identical(bestOf([b, a]), b), isTrue);
      expect(bestOf(const []), isNull);
    });

    test('lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức', () {
      final base = directLookup();
      final powers = <double>[];
      final c = contextFor(railTable(), lookup: (k) {
        powers.add(k.power);
        return base(k);
      });
      final key = shotKey(c.geometry, Stroke.stun, 90);
      final aimed = c.lookup(key)!;
      scoreOption(c, key, aimed);
      final t = toleranceOf(c, key);
      expect(t.good + t.fair + t.bad, toleranceSamples);
      expect(powers.reduce(math.max), maxPower);
      expect(jitteredPower(90, powerJitter), maxPower);
      expect(jitteredPower(30, -powerJitter), 30 - powerJitter);
    });
  });

  test('lưới vùng điều: ô trong biên, không đè bi, mức khớp góc dễ nhất', () {
    final s = railTable();
    final finder = CandidateFinder(game: s.game);
    final after = s.without([1]).balls;
    final cells = zoneGrid(after: after, next: finder);
    expect(cells, isNotEmpty);
    for (final cell in cells) {
      expect(s.table.contains(cell.center), isTrue);
      for (final b in after) {
        expect(cell.center.distanceTo(b.pos), greaterThanOrEqualTo(s.table.ballDiameter));
      }
      final angle = finder.easiest(cell.center, after)!.angle;
      expect(angle, lessThanOrEqualTo(cell.level == ZoneLevel.good ? zoneGood : zoneFair));
      if (cell.level == ZoneLevel.fair) expect(angle, greaterThan(zoneGood));
    }
    expect(zoneGrid(after: const [], next: finder), isEmpty);
  });
}
