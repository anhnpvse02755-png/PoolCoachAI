import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

/// Các dòng của bảng thông tin một bước (spec mục 7.2).
///
/// Hàm thuần, tách khỏi widget để test thẳng. Mọi số lấy từ [step]; dòng
/// áp phê dùng chung [squirtLine] của màn mô phỏng. Không dòng nào nói độ
/// lệch ngắm: `aimOffsetDeg` chỉ dùng bên trong. Bước dự phòng không có
/// điểm, sai số lực hay lời khuyên trượt (spec mục 5.5), nên chỉ có dòng
/// "không có vị trí tốt".
List<String> planStepLines(PlanStep step,
    {required int index, required int total, TableSpec table = TableSpec.nineFoot}) {
  final header = Vi.planStepHeader(index + 1, total);
  if (step.kind == PlanStepKind.safety) {
    return [
      header,
      if (step.ballNum case final n?) Vi.planBallLine(n),
      Vi.planSafety,
    ];
  }
  final g = step.geometry!;
  final railCount = step.trace?.cueRailCount ?? 0;
  return [
    header,
    Vi.planBallLine(step.ballNum!),
    Vi.simPocketLine(g.pocket),
    Vi.simAngleLine(g.angle),
    Vi.simStrokeLine(step.stroke),
    Vi.simPowerLine(step.power),
    if (!step.spin.isNone) ...[
      Vi.simSpinLine(step.spin),
      squirtLine(step.spin, step.aimed, g, table, step.stroke, step.power),
    ],
    if (step.tolerance case final t?) Vi.planTolerance(t.good, toleranceSamples),
    if (railCount > 0) Vi.planRailInfo(railCount),
    if (step.power >= riskPower || step.stroke == Stroke.draw) Vi.planRiskWarning,
    if (step.missAdvice case final m?) Vi.planMissAdvice(m.safer),
    if (step.kind == PlanStepKind.fallback) Vi.planNoPosition,
  ];
}
