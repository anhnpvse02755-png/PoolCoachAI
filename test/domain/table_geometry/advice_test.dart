import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/table_layouts.dart';

void main() {
  const none = SideSpin.none();
  const left05 = SideSpin(SpinSide.left, 0.5);
  const left1 = SideSpin(SpinSide.left, 1);
  const right05 = SideSpin(SpinSide.right, 0.5);
  const right1 = SideSpin(SpinSide.right, 1);
  const right2 = SideSpin(SpinSide.right, 2);
  const pocket = Pocket.topRight;

  /// Mọi mức an toàn, trừ các mức ghi đè.
  Map<SideSpin, SpinOutcome> outcomes(Map<SideSpin, SpinOutcome> overrides) =>
      {for (final s in SideSpin.all) s: overrides[s] ?? const SpinOutcome()};

  const drops = SpinOutcome(
    scratchAtPower: pocket,
    risk: ScratchRisk(power: 70, pocket: pocket),
  );
  SpinOutcome riskAt(double p) =>
      SpinOutcome(risk: ScratchRisk(power: p, pocket: pocket));

  group('mức đang chọn chết cái tại lực chọn', () {
    test('khuyên mức an toàn ít đầu cơ nhất', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({
          none: drops,
          left05: drops,
          right05: drops,
          left1: riskAt(80), // dư 10% là chết cái: chưa an toàn
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
        power: 70,
        chosen: right05,
        outcomes: outcomes({none: drops, left05: drops, right05: drops}),
      );
      expect((advice.single as AddSpinToAvoid).to, right1);
    });

    test('không mức nào cứu được thì nói thẳng', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: {for (final s in SideSpin.all) s: drops},
      );
      expect(advice.single,
          isA<NoSpinAvoids>().having((a) => a.pocket, 'pocket', pocket));
    });
  });

  group('mức đang chọn không chết cái tại lực chọn', () {
    test('dư lực trong biên 15% thì cảnh báo, kèm mức áp phê an toàn tới 100%',
        () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({
          none: riskAt(82),
          left05: riskAt(90),
          right05: riskAt(95),
        }),
      );
      expect(advice.single, isA<OverhitRisk>()
          .having((a) => a.margin, 'margin', 12)
          .having((a) => a.fromPower, 'fromPower', 82)
          .having((a) => a.saferSpin, 'saferSpin', left1));
    });

    test('chết cái chỉ khi dư quá 15% thì không cảnh báo', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({none: riskAt(90)}),
      );
      expect(advice, isEmpty);
    });

    test('cùng phía, nhiều đầu cơ hơn thì chết cái: báo trần áp phê', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: right05,
        outcomes: outcomes({
          right2: const SpinOutcome(
            scratchAtPower: Pocket.bottomMiddle,
            risk: ScratchRisk(power: 70, pocket: Pocket.bottomMiddle),
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
        power: 70,
        chosen: right05,
        outcomes: outcomes({
          right05: riskAt(80),
          right1: drops,
        }),
      );
      expect(advice, hasLength(2));
      expect(advice[0], isA<OverhitRisk>());
      expect(advice[1], isA<SpinCeiling>());
    });
  });

  test('scratchAdvice nối đúng với mô phỏng thật', () {
    var checked = 0;
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 7) {
      final g = shots[i];
      for (final stroke in [Stroke.stun, Stroke.follow]) {
        for (final power in [70.0, 95.0]) {
          for (final a in scratchAdvice(g,
              stroke: stroke, power: power, spin: const SideSpin.none())) {
            checked++;
            switch (a) {
              case AddSpinToAvoid(:final to):
                expect(
                    simulateCueBall(g, stroke: stroke, power: power, spin: to)
                        .scratch,
                    isNull);
                final risk =
                    scratchMargin(g, stroke: stroke, power: power, spin: to);
                expect(risk == null || risk.power - power > overhitBand,
                    isTrue);
              case OverhitRisk(:final fromPower):
                expect(scratchMargin(g, stroke: stroke, power: power)!.power,
                    fromPower);
              case NoSpinAvoids() || SpinCeiling():
                break;
            }
          }
        }
      }
    }
    expect(checked, greaterThan(0),
        reason: 'lưới phải sinh ra ít nhất một lời khuyên để nối dây được kiểm');
  });
}
