import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/coach/hints.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/reveal.dart';
import 'package:poolcoachai/domain/coach/session.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';

/// Kết luận chưa đạt gần nhất — nguồn của cả hai gợi ý.
CoachVerdict? lastWrong(CoachSession s) =>
    s.verdicts.where((v) => v.outcome == CoachOutcome.wrong).lastOrNull;

/// Các dòng gợi ý đang hiện (spec mục 4.2): sai 1 → gợi ý 1; sai 2 → thêm
/// gợi ý 2 và câu vùng điều khi có vẽ vùng điều. Hàm thuần, test thẳng.
List<String> hintLines(CoachSession s, CoachReference ref) {
  final level = s.hintLevel;
  final v = lastWrong(s);
  if (level == 0 || v == null) return const [];
  final one = hintOne(v, ref);
  final two = level >= 2 ? hintTwo(v, ref) : null;
  return [
    if (one != null) Vi.coachHintOne(one),
    if (two != null) Vi.coachHintTwo(two.hint),
    if (two?.zoneNext case final next?) Vi.coachHint2Zone(next),
  ];
}

/// Bi kế tiếp để vẽ vùng điều tốt: ở gợi ý 2 khi gợi ý nói về vị trí, và ở
/// đáp án khi có bi kế tiếp. null là không vẽ.
int? zoneBallFor(CoachSession s, CoachReference ref) {
  if (s.ended) return ref.kind == PlanStepKind.safety ? null : ref.nextBall;
  if (s.hintLevel < 2) return null;
  final v = lastWrong(s);
  return v == null ? null : hintTwo(v, ref)?.zoneNext;
}

/// Bỏ dòng có số độ: Coach không nói số độ nào, kể cả để tham khảo (spec
/// D8). Các dòng dùng lại của Kế hoạch dọn bàn (góc cắt của đối thủ, góc bi
/// cái bị lệch do áp phê) có số độ, nên lọc ở đây, một chỗ.
List<String> _withoutDegrees(Iterable<String> lines) => [
      for (final l in lines)
        if (!l.contains('°')) l,
    ];

/// Các dòng đáp án (spec mục 7.3). Hàm thuần: mọi câu là mẫu của `Vi` điền
/// bằng dữ liệu [Reveal]; không câu nào cố định.
List<String> revealLines(Reveal r,
    {required bool searchingSafety, TableSpec table = TableSpec.nineFoot}) {
  final step = r.step;
  if (r.kind == RevealKind.safety) {
    return [
      Vi.coachRevealSafetyNote,
      ..._safetyLines(step, table),
      if (searchingSafety && step.safety == null) Vi.planSearchingSafety,
    ];
  }
  final pocket = step.pocket!;
  final hasNext = step.nextBallNum != null;
  return [
    if (r.kind == RevealKind.potVsSafety) Vi.coachRevealPotVsSafety,
    Vi.coachRevealShot(r.ball, pocket, step.stroke, step.power),
    if (r.spin case final spin?) Vi.coachRevealSpin(spin),
    if (r.toleranceGood case final good?) Vi.planTolerance(good, toleranceSamples),
    if (r.missSide case final side?) Vi.planMissAdvice(side),
    if (step.kind == PlanStepKind.fallback) Vi.planNoPosition,
    if (r.reasons.isNotEmpty || r.railCount > 0) Vi.coachRevealWhy,
    ...r.reasons.map(Vi.coachReason),
    if (r.railCount > 0) hasNext ? Vi.planRailInfo(r.railCount) : Vi.planRailInfoLast(r.railCount),
    if (r.equivalents.isNotEmpty) Vi.coachRevealEquivalents,
    for (final o in r.equivalents) ...[
      Vi.coachRevealShot(r.ball, o.key.pocket, o.key.stroke, o.key.power),
      if (!o.key.spin.isNone) Vi.simSpinLine(o.key.spin),
    ],
    if (r.kind == RevealKind.potVsSafety) ...[
      Vi.coachRevealSafetyNote,
      if (r.safety case final shot?)
        ..._safetyLines(PlanStep.safety(cbFrom: step.cbFrom, ballNum: r.ball, safety: shot), table)
      else if (searchingSafety)
        Vi.planSearchingSafety,
    ],
  ];
}

/// Dòng cú thủ của Kế hoạch dọn bàn, bỏ dòng "Bước 1 / 1".
List<String> _safetyLines(PlanStep step, TableSpec table) =>
    _withoutDegrees(planStepLines(step, index: 0, total: 1, table: table).skip(1));
