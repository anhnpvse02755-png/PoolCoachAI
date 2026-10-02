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

  test('scratchAdvice nối đúng với mô phỏng thật', () {
    // Đếm theo kiểu con để khẳng định cả bốn loại lời khuyên đều từng
    // xuất hiện trên lưới thật — review finding 1: trước đây chỉ quét
    // spin: none nên SpinCeiling không thể sinh ra (nó cần chosen.side
    // khác null) và AddSpinToAvoid/NoSpinAvoids không có phép kiểm riêng.
    final counts = <Type, int>{};
    void bump(Advice a) =>
        counts[a.runtimeType] = (counts[a.runtimeType] ?? 0) + 1;

    final shots = gridShots().toList();
    // Sải bước đủ thưa để quét thêm 7 mức áp phê vẫn chạy dưới ~60s;
    // đo lại bằng `time` khi đổi tham số (xem task-7-report.md).
    for (var i = 0; i < shots.length; i += 7) {
      final g = shots[i];
      for (final stroke in [Stroke.stun, Stroke.follow]) {
        // Bỏ mức nhẹ nhất cho đỡ chậm: lực nhẹ hiếm khi tới lỗ.
        for (final p in powerPresets.skip(1)) {
          for (final chosen in SideSpin.all) {
            for (final a in scratchAdvice(g,
                stroke: stroke, power: p, spin: chosen)) {
              bump(a);
              switch (a) {
                case AddSpinToAvoid(:final from, :final to, :final pocket):
                  expect(from, chosen);
                  expect(
                      simulateCueBall(g,
                              stroke: stroke, power: p, spin: chosen)
                          .scratch,
                      pocket);
                  expect(
                      simulateCueBall(g, stroke: stroke, power: p, spin: to)
                          .scratch,
                      isNull);
                  final toRisk =
                      scratchMargin(g, stroke: stroke, power: p, spin: to);
                  expect(toRisk == null || toRisk.power - p > overhitBand,
                      isTrue);

                case NoSpinAvoids(:final pocket):
                  expect(
                      simulateCueBall(g,
                              stroke: stroke, power: p, spin: chosen)
                          .scratch,
                      pocket);
                  for (final s in SideSpin.all) {
                    if (s == chosen) continue;
                    final scratchesNow = simulateCueBall(g,
                            stroke: stroke, power: p, spin: s)
                        .scratch !=
                        null;
                    final risk =
                        scratchMargin(g, stroke: stroke, power: p, spin: s);
                    final unsafe = scratchesNow ||
                        (risk != null && risk.power - p <= overhitBand);
                    expect(unsafe, isTrue,
                        reason:
                            'NoSpinAvoids nghĩa là mọi mức khác đều không an toàn');
                  }

                case OverhitRisk(
                    :final margin,
                    :final fromPower,
                    :final pocket,
                    :final saferSpin
                  ):
                  expect(
                      simulateCueBall(g,
                              stroke: stroke, power: p, spin: chosen)
                          .scratch,
                      isNull);
                  final risk =
                      scratchMargin(g, stroke: stroke, power: p, spin: chosen);
                  expect(risk, isNotNull);
                  expect(risk!.power, fromPower);
                  expect(risk.pocket, pocket);
                  expect(margin, fromPower - p);
                  expect(margin, lessThanOrEqualTo(overhitBand));
                  if (saferSpin != null) {
                    expect(
                        scratchMargin(g,
                            stroke: stroke, power: p, spin: saferSpin),
                        isNull);
                  }

                case SpinCeiling(
                    :final side,
                    :final maxSafeTips,
                    :final pocket
                  ):
                  expect(side, chosen.side);
                  final sideLevels = SideSpin.all
                      .where((s) => s.side == side)
                      .toList()
                    ..sort((x, y) => x.tips.compareTo(y.tips));
                  final above =
                      sideLevels.where((s) => s.tips > maxSafeTips).toList();
                  expect(above, isNotEmpty);
                  expect(
                      simulateCueBall(g,
                              stroke: stroke, power: p, spin: above.first)
                          .scratch,
                      pocket);
                  for (final s in sideLevels) {
                    if (s.tips > chosen.tips && s.tips <= maxSafeTips) {
                      expect(
                          simulateCueBall(g,
                                  stroke: stroke, power: p, spin: s)
                              .scratch,
                          isNull);
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
}
