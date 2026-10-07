import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

import '../../support/planner_tables.dart';

void main() {
  const table = TableSpec.nineFoot;
  final rail = planToEnd(railTable());
  final corner = planToEnd(cornerFollowTable());
  final fallback = planToEnd(fallbackTable());
  final ball1 = railTable().balls.first.pos;
  final spin = planToEnd(railTable(),
      aim: scratchingAim((object, _, s, _) => object == ball1 && s.isNone));

  List<String> linesOf(List<PlanStep> plan, int i) =>
      planStepLines(plan[i], index: i, total: plan.length);

  test('bước thường: bi, lỗ, góc cắt, kiểu đánh, lực, rồi sai số, dội băng, nếu trượt', () {
    final s = rail.first;
    final lines = linesOf(rail, 0);
    expect(lines.take(6), [
      Vi.planStepHeader(1, rail.length),
      Vi.planBallLine(1),
      Vi.simPocketLine(s.pocket!),
      Vi.simAngleLine(s.cutAngle!),
      Vi.simStrokeLine(s.stroke),
      Vi.simPowerLine(s.power),
    ]);
    expect(lines, contains(Vi.planTolerance(s.tolerance!.good, toleranceSamples)));
    expect(lines, contains(Vi.planRailInfo(s.trace!.cueRailCount)));
    expect(lines, contains(Vi.planMissAdvice(s.missAdvice!.safer)));
    expect(lines, isNot(contains(Vi.planNoPosition)));
  });

  test('bi cuối: không có dòng sai số lực và nếu trượt', () {
    final lines = linesOf(rail, rail.length - 1);
    expect(rail.last.tolerance, isNull);
    for (var good = 0; good <= toleranceSamples; good++) {
      expect(lines, isNot(contains(Vi.planTolerance(good, toleranceSamples))));
    }
    for (final side in MissSide.values) {
      expect(lines, isNot(contains(Vi.planMissAdvice(side))));
    }
  });

  test('dội băng ở bước cuối: không nói tới vùng điều', () {
    final s = rail.first;
    final rails = s.trace!.cueRailCount;
    expect(rails, greaterThan(0));
    expect(s.nextBallNum, isNotNull);
    expect(linesOf(rail, 0), isNot(contains(Vi.planRailInfoLast(rails))));

    // Cùng cú, nhưng là bi cuối: không có bi kế tiếp.
    final last = PlanStep(
        kind: s.kind,
        cbFrom: s.cbFrom,
        ballNum: s.ballNum,
        geometry: s.geometry,
        stroke: s.stroke,
        power: s.power,
        aimed: s.aimed);
    final lines = planStepLines(last, index: 1, total: 2);
    expect(lines, contains(Vi.planRailInfoLast(rails)));
    expect(lines, isNot(contains(Vi.planRailInfo(rails))));

    for (final plan in [rail, corner, fallback]) {
      final n = plan.last.trace?.cueRailCount ?? 0;
      expect(linesOf(plan, plan.length - 1), isNot(contains(Vi.planRailInfo(n))));
    }
  });

  test('cảnh báo khi lực từ riskPower hoặc dùng trô, không thì không', () {
    expect(corner.first.power, greaterThanOrEqualTo(riskPower));
    expect(linesOf(corner, 0), contains(Vi.planRiskWarning));
    final s = rail.first;
    PlanStep as(Stroke stroke, double power) => PlanStep(
        kind: s.kind,
        cbFrom: s.cbFrom,
        ballNum: s.ballNum,
        geometry: s.geometry,
        stroke: stroke,
        power: power,
        aimed: s.aimed);
    expect(planStepLines(as(Stroke.draw, 45), index: 0, total: 2), contains(Vi.planRiskWarning));
    expect(planStepLines(as(Stroke.stun, 45), index: 0, total: 2),
        isNot(contains(Vi.planRiskWarning)));
  });

  test('áp phê: đúng dòng của màn mô phỏng (đầu cơ, phần con bi, SAWS)', () {
    final s = spin.first;
    expect(s.spin.isNone, isFalse);
    final lines = linesOf(spin, 0);
    expect(lines, contains(Vi.simSpinLine(s.spin)));
    expect(lines, contains(squirtLine(s.spin, s.aimed, s.geometry!, table, s.stroke, s.power)));
  });

  test('bước dự phòng và bước phòng thủ', () {
    expect(linesOf(fallback, 0), contains(Vi.planNoPosition));
    // Bước dự phòng không có sai số lực (spec mục 5.5 bỏ qua phần vị trí).
    expect(fallback.first.kind, PlanStepKind.fallback);
    expect(fallback.first.tolerance, isNull);
    for (var good = 0; good <= toleranceSamples; good++) {
      expect(linesOf(fallback, 0), isNot(contains(Vi.planTolerance(good, toleranceSamples))));
    }
    // Lời khuyên trượt không phụ thuộc vị trí bi cái nên lõi vẫn tính cho bước dự phòng.
    expect(linesOf(fallback, 0),
        contains(Vi.planMissAdvice(fallback.first.missAdvice!.safer)));
    expect(linesOf(fallback, 1), [Vi.planStepHeader(2, 2), Vi.planBallLine(2), Vi.planSafety]);
  });

  test('không câu nào là lời khuyên ngắm theo độ (memory: lời khuyên làm được)', () {
    final aimInDegrees = RegExp(r'ngắm[^.°]*\d+(?:[.,]\d+)?\s*°|(?:dày|mỏng) hơn\s*\d',
        caseSensitive: false);
    final plans = [
      rail,
      corner,
      fallback,
      spin,
      planToEnd(orderTable(GameType.nineBall)),
      planToEnd(eightWithOpponentsTable()),
    ];
    for (final plan in plans) {
      for (var i = 0; i < plan.length; i++) {
        final shown = [
          ...linesOf(plan, i),
          Vi.planSummary(plan[i], index: i, total: plan.length),
        ];
        for (final line in shown) {
          expect(line, isNot(matches(aimInDegrees)), reason: line);
          final offset = plan[i].aimed?.aimOffsetDeg;
          if (offset != null && offset.abs() >= 0.05) {
            expect(line, isNot(contains('${offset.abs().toStringAsFixed(1)}°')), reason: line);
          }
        }
      }
    }
  });
}
