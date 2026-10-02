import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const none = SideSpin.none();
  const left05 = SideSpin(SpinSide.left, 0.5);
  const left1 = SideSpin(SpinSide.left, 1);
  const right05 = SideSpin(SpinSide.right, 0.5);
  const right1 = SideSpin(SpinSide.right, 1);
  const right2 = SideSpin(SpinSide.right, 2);
  const pocket = Pocket.topRight;
  const power = 70.0;

  /// Mọi mức an toàn, trừ các mức ghi đè.
  Map<SideSpin, SpinOutcome> outcomes(Map<SideSpin, SpinOutcome> overrides) =>
      {for (final s in SideSpin.all) s: overrides[s] ?? const SpinOutcome()};

  const drops = SpinOutcome(
    scratchAtPower: pocket,
    risk: ScratchRisk(power: power, pocket: pocket),
  );
  SpinOutcome riskAt(double p) =>
      SpinOutcome(risk: ScratchRisk(power: p, pocket: pocket));

  group('mức đang chọn chết cái tại lực chọn', () {
    test('khuyên mức an toàn ít đầu cơ nhất', () {
      final advice = chooseAdvice(
        power: power,
        chosen: none,
        outcomes: outcomes({
          none: drops,
          left05: drops,
          right05: drops,
          // dư (overhitBand - 5)%, vẫn trong biên overhitBand: chưa an toàn
          left1: riskAt(power + overhitBand - 5),
          const SideSpin(SpinSide.left, 2): drops,
        }),
      );
      expect(advice.single, isA<AddSpinToAvoid>()
          .having((a) => a.to, 'to', right1)
          .having((a) => a.from, 'from', none)
          .having((a) => a.pocket, 'pocket', pocket));
    });

    test('hoà số đầu cơ thì giữ cùng phía đang chọn', () {
      final advice = chooseAdvice(
        power: power,
        chosen: right05,
        outcomes: outcomes({none: drops, left05: drops, right05: drops}),
      );
      expect((advice.single as AddSpinToAvoid).to, right1);
    });

    test('không mức nào cứu được thì nói thẳng', () {
      final advice = chooseAdvice(
        power: power,
        chosen: none,
        outcomes: {for (final s in SideSpin.all) s: drops},
      );
      expect(advice.single,
          isA<NoSpinAvoids>().having((a) => a.pocket, 'pocket', pocket));
    });
  });

  group('mức đang chọn không chết cái tại lực chọn', () {
    test(
        'dư lực trong biên overhitBand thì cảnh báo, kèm mức áp phê an toàn tới 100%',
        () {
      final advice = chooseAdvice(
        power: power,
        chosen: none,
        outcomes: outcomes({
          none: riskAt(power + overhitBand - 3),
          left05: riskAt(power + overhitBand + 5),
          right05: riskAt(power + overhitBand + 10),
        }),
      );
      expect(advice.single, isA<OverhitRisk>()
          .having((a) => a.margin, 'margin', overhitBand - 3)
          .having((a) => a.fromPower, 'fromPower', power + overhitBand - 3)
          .having((a) => a.saferSpin, 'saferSpin', left1));
    });

    test('dư đúng bằng overhitBand vẫn cảnh báo, vì quy tắc là ≤', () {
      final advice = chooseAdvice(
        power: power,
        chosen: none,
        outcomes: outcomes({none: riskAt(power + overhitBand)}),
      );
      expect(advice.single, isA<OverhitRisk>()
          .having((a) => a.margin, 'margin', overhitBand)
          .having((a) => a.fromPower, 'fromPower', power + overhitBand));
    });

    test('chết cái chỉ khi dư quá overhitBand thì không cảnh báo', () {
      final advice = chooseAdvice(
        power: power,
        chosen: none,
        outcomes: outcomes({none: riskAt(power + overhitBand + 5)}),
      );
      expect(advice, isEmpty);
    });

    test('cùng phía, nhiều đầu cơ hơn thì chết cái: báo trần áp phê', () {
      final advice = chooseAdvice(
        power: power,
        chosen: right05,
        outcomes: outcomes({
          right2: const SpinOutcome(
            scratchAtPower: Pocket.bottomMiddle,
            risk: ScratchRisk(power: power, pocket: Pocket.bottomMiddle),
          ),
        }),
      );
      expect(advice.single, isA<SpinCeiling>()
          .having((a) => a.side, 'side', SpinSide.right)
          .having((a) => a.maxSafeTips, 'maxSafeTips', 1)
          .having((a) => a.pocket, 'pocket', Pocket.bottomMiddle));
    });

    test('tối đa hai lời khuyên, theo thứ tự', () {
      final advice = chooseAdvice(
        power: power,
        chosen: right05,
        outcomes: outcomes({
          right05: riskAt(power + overhitBand - 5),
          right1: drops,
        }),
      );
      expect(advice, hasLength(2));
      expect(advice[0], isA<OverhitRisk>());
      expect(advice[1], isA<SpinCeiling>());
    });
  });

  /// Mô phỏng thật, mỗi (áp phê, lực) đúng một lần cho một cú đánh.
  CuePocketLookup lookupFor(ShotGeometry g, Stroke stroke) {
    final memo = <(SideSpin, double), Pocket?>{};
    return (s, p) => memo.putIfAbsent(
        (s, p), () => cuePocketAt(g, stroke: stroke, power: p, spin: s));
  }

  String describe(Advice a) => switch (a) {
        AddSpinToAvoid(:final from, :final to, :final pocket) =>
          'add $from→$to $pocket',
        NoSpinAvoids(:final pocket) => 'none $pocket',
        OverhitRisk(:final margin, :final fromPower, :final pocket, :final saferSpin) =>
          'over $margin $fromPower $pocket $saferSpin',
        SpinCeiling(:final side, :final maxSafeTips, :final pocket) =>
          'ceiling $side $maxSafeTips $pocket',
      };

  test('lời khuyên trên lưới khớp mô phỏng thật, đủ cả bốn loại', () {
    // Đếm theo kiểu con để khẳng định cả bốn loại lời khuyên đều từng
    // xuất hiện trên lưới thật, nên nối dây của từng loại đều được kiểm.
    final counts = <Type, int>{};
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 9) {
      final g = shots[i];
      for (final stroke in [Stroke.stun, Stroke.follow]) {
        // Bỏ hai mức nhẹ nhất cho đỡ chậm: lực nhẹ hiếm khi tới lỗ.
        for (final p in powerPresets.skip(2)) {
          final at = lookupFor(g, stroke);
          ScratchRisk? margin(SideSpin s) => marginWith(at, s, p);
          final outcomes = outcomesWith(at, p);
          for (final chosen in SideSpin.all) {
            for (final a
                in chooseAdvice(power: p, chosen: chosen, outcomes: outcomes)) {
              counts[a.runtimeType] = (counts[a.runtimeType] ?? 0) + 1;
              final where = '${g.cue}→${g.object} $stroke $p $chosen';
              switch (a) {
                case AddSpinToAvoid(:final from, :final to, :final pocket):
                  expect(from, chosen, reason: where);
                  expect(at(chosen, p), pocket, reason: where);
                  expect(at(to, p), isNull, reason: where);
                  final toRisk = margin(to);
                  expect(toRisk == null || toRisk.power - p > overhitBand,
                      isTrue,
                      reason: where);

                case NoSpinAvoids(:final pocket):
                  expect(at(chosen, p), pocket, reason: where);
                  for (final s in SideSpin.all) {
                    if (s == chosen) continue;
                    final risk = margin(s);
                    final unsafe = at(s, p) != null ||
                        (risk != null && risk.power - p <= overhitBand);
                    expect(unsafe, isTrue,
                        reason: '$where: NoSpinAvoids nghĩa là mọi mức khác '
                            'đều không an toàn');
                  }

                case OverhitRisk(
                    :final margin,
                    :final fromPower,
                    :final pocket,
                    :final saferSpin
                  ):
                  expect(at(chosen, p), isNull, reason: where);
                  expect(at(chosen, fromPower), pocket, reason: where);
                  expect(margin, fromPower - p, reason: where);
                  expect(margin, lessThanOrEqualTo(overhitBand), reason: where);
                  if (saferSpin != null) {
                    expect(marginWith(at, saferSpin, p), isNull, reason: where);
                  }

                case SpinCeiling(
                    :final side,
                    :final maxSafeTips,
                    :final pocket
                  ):
                  expect(side, chosen.side, reason: where);
                  final sideLevels = SideSpin.all
                      .where((s) => s.side == side)
                      .toList()
                    ..sort((x, y) => x.tips.compareTo(y.tips));
                  final above =
                      sideLevels.where((s) => s.tips > maxSafeTips).toList();
                  expect(above, isNotEmpty, reason: where);
                  expect(at(above.first, p), pocket, reason: where);
                  for (final s in sideLevels) {
                    if (s.tips > chosen.tips && s.tips <= maxSafeTips) {
                      expect(at(s, p), isNull, reason: where);
                    }
                  }
              }
            }
          }
        }
      }
    }

    for (final type in [AddSpinToAvoid, NoSpinAvoids, OverhitRisk, SpinCeiling]) {
      expect(counts[type] ?? 0, greaterThan(0),
          reason:
              '$type phải xuất hiện ít nhất một lần trên lưới để nối dây được kiểm');
    }
  });

  test('scratchAdvice là luật chọn chạy trên mô phỏng thật', () {
    final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);
    for (final chosen in [none, right1, left1]) {
      final at = lookupFor(g, Stroke.follow);
      expect(
        scratchAdvice(g, stroke: Stroke.follow, power: 75, spin: chosen)
            .map(describe),
        chooseAdvice(
                power: 75, chosen: chosen, outcomes: outcomesWith(at, 75))
            .map(describe),
      );
    }
  });

  test('ScratchAdviceJob: mỗi bước đúng một lần mô phỏng, rồi ra lời khuyên',
      () {
    final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);
    final job = ScratchAdviceJob(g,
        stroke: Stroke.follow, power: 60, spin: none);
    List<Advice>? result;
    var steps = 0;
    while (result == null) {
      result = job.step();
      steps++;
      if (result == null) expect(job.simulations, steps);
    }
    expect(job.simulations, steps - 1);
    expect(
      result.map(describe),
      scratchAdvice(g, stroke: Stroke.follow, power: 60, spin: none)
          .map(describe),
    );
  });
}
