import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

import '../../support/planner_tables.dart';

void main() {
  const table = TableSpec.nineFoot;
  final rail = planToEnd(railTable());
  final corner = planToEnd(cornerFollowTable());
  final fallback = planToEnd(fallbackTable(), safety: noSafetyPhysics);
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
    expect(linesOf(fallback, 1),
        [Vi.planStepHeader(2, 2), Vi.planBallLine(2), Vi.planSafety(2)]);
    // 8 bi không có bi cụ thể bị ép: không dòng bi, câu "Không bi nào".
    expect(planStepLines(const PlanStep.safety(cbFrom: Vec2(1, 1)), index: 0, total: 1),
        [Vi.planStepHeader(1, 1), Vi.planSafety(null)]);
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
      planToEnd(snookerOneRailTable()),
      planToEnd(noPotTable()),
    ];
    for (final plan in plans) {
      for (var i = 0; i < plan.length; i++) {
        final shown = [
          ...linesOf(plan, i),
          Vi.planSummary(plan[i], index: i, total: plan.length),
        ];
        for (final line in shown) {
          expect(line, isNot(matches(aimInDegrees)), reason: line);
          final offset = plan[i].aimed?.aimOffsetDeg ?? plan[i].safety?.aimed.aimOffsetDeg;
          if (offset != null && offset.abs() >= 0.05) {
            expect(line, isNot(contains('${offset.abs().toStringAsFixed(1)}°')), reason: line);
          }
          // Số độ chỉ được có ở kết quả cho đối thủ (spec quyết định 9).
          if (line.contains('°') && plan[i].safety != null) {
            expect(line, contains(Vi.safetyOpponent(plan[i].safety!.opponent)), reason: line);
          }
        }
      }
    }
  });

  /// Cú thủ dựng tay: chỉ để kiểm câu chữ, mọi số đã biết trước.
  SafetyShot shot({
    SafetyReason reason = SafetyReason.noPot,
    SafetyKind kind = SafetyKind.direct,
    int rails = 0,
    RailAim? railAim,
    double thickness = 0.5,
    ThicknessSide side = ThicknessSide.left,
    Stroke stroke = Stroke.stun,
    SideSpin spin = const SideSpin.none(),
    double power = 45,
    int? bhe,
    OpponentView opponent = const OpponentView(snookered: true, ball: PlacedBall(number: 1, pos: Vec2(200, 100))),
  }) =>
      SafetyShot(
        reason: reason,
        kind: kind,
        rails: rails,
        ballNum: 1,
        thickness: thickness,
        side: side,
        stroke: stroke,
        spin: spin,
        power: power,
        aimed: const AimedShot(
          trace: ShotTrace(
            cueBefore: [Vec2(60, 100), Vec2(145, 45)],
            cueAfter: [Vec2(145, 45), Vec2(120, 20)],
            objectPath: [Vec2(150, 40), Vec2(200, 100)],
            contactCue: Vec2(145, 45),
            rails: [],
            cuePocket: null,
            objectPocket: null,
            cueEnd: Vec2(120, 20),
          ),
          uncompensated: null,
          aimOffsetDeg: 1.5,
          verticalOffset: 0,
          stunReached: true,
          converged: true,
        ),
        railAim: railAim,
        opponent: opponent,
        jitterEnds: (minus: null, plus: null),
        tolerance: 5,
        sawsBhePercent: bhe,
        contactDistance: 100,
        total: 20,
      );

  List<String> safetyLines(SafetyShot s) => planStepLines(
      PlanStep.safety(cbFrom: const Vec2(60, 100), ballNum: 1, safety: s), index: 0, total: 1);

  group('bước phòng thủ có cú thủ (spec cú phòng thủ 5.2)', () {
    test('không đui: hết đường ăn, bi, độ dày, kiểu đánh, lực, đối thủ, độ chịu sai số', () {
      expect(safetyLines(shot()), [
        Vi.planStepHeader(1, 1),
        Vi.safetyNoPot,
        Vi.planBallLine(1),
        Vi.safetyThickness(0.5, ThicknessSide.left),
        Vi.simStrokeLine(Stroke.stun),
        Vi.simPowerLine(45),
        Vi.safetyOpponent(shot().opponent),
        Vi.safetyTolerance(5, toleranceSamples),
      ]);
    });

    test('bị đui: câu A băng thay câu độ dày', () {
      const aim = RailAim(rail: Rail.top, diamond: 3.5, at: Vec2(110, 3));
      final lines = safetyLines(shot(
          reason: SafetyReason.snookered, kind: SafetyKind.kick, rails: 1, railAim: aim,
          thickness: 1, side: ThicknessSide.full));
      expect(lines[1], Vi.safetySnookered(1));
      expect(lines, contains(Vi.safetyKick(1, aim)));
      expect(lines, isNot(contains(Vi.safetyThickness(1, ThicknessSide.full))));
    });

    test('áp phê: đúng dòng của màn mô phỏng, % BHE đọc từ cú thủ (một nguồn)', () {
      const spin = SideSpin(SpinSide.right, 1);
      // Cố ý đặt số khác số SAWS tính lại để chứng minh dòng theo lõi.
      final s = shot(spin: spin, stroke: Stroke.follow, bhe: 77);
      final lines = safetyLines(s);
      expect(lines, contains(Vi.simSpinLine(s.spin)));
      expect(lines, contains(squirtLineFor(s.spin, 1.5, 100, table, bhePercent: 77)));
      expect(lines.any((l) => l.contains('77')), isTrue);
    });

    test('cảnh báo lực cao hoặc trô như bước thường', () {
      expect(safetyLines(shot(power: riskPower)), contains(Vi.planRiskWarning));
      expect(safetyLines(shot(stroke: Stroke.draw)), contains(Vi.planRiskWarning));
      expect(safetyLines(shot()), isNot(contains(Vi.planRiskWarning)));
    });

    test('nhãn bàn: câu đầu, câu ngắm, kết quả cho đối thủ', () {
      final s = shot();
      expect(Vi.planSummary(PlanStep.safety(cbFrom: const Vec2(1, 1), ballNum: 1, safety: s),
              index: 0, total: 1),
          'Bàn kế hoạch. Bước 1 / 1: ${Vi.safetyNoPot} ${Vi.safetyThickness(0.5, ThicknessSide.left)} '
          '${Vi.safetyOpponent(s.opponent)}');
      expect(Vi.planSummary(null, index: 0, total: 1, searchingSafety: true),
          'Bàn kế hoạch. ${Vi.planSearchingSafety}');
    });
  });
}
