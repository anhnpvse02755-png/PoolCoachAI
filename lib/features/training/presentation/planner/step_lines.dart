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
/// lệch ngắm: `aimOffsetDeg` chỉ dùng bên trong. Bước phòng thủ có cú thủ
/// thì nói cú thủ (spec cú phòng thủ 5.2); không có thì giữ câu cũ. Bước dự
/// phòng không có điểm và sai số lực (spec mục 5.5), nhưng vẫn giữ dòng "Nếu
/// trượt" khi có bi kế tiếp (chủ sản phẩm chốt 07/10/2026): lỡ đánh đứng bi
/// thì người chơi vẫn cần biết cách trượt an toàn hơn. Cuối cùng là dòng
/// "không có vị trí tốt".
List<String> planStepLines(PlanStep step,
    {required int index, required int total, TableSpec table = TableSpec.nineFoot}) {
  final header = Vi.planStepHeader(index + 1, total);
  if (step.kind == PlanStepKind.safety) {
    final s = step.safety;
    if (s == null) {
      return [
        header,
        if (step.ballNum case final n?) Vi.planBallLine(n),
        Vi.planSafety(step.ballNum),
      ];
    }
    // Cú thủ (spec cú phòng thủ 5.2): không câu nào khuyên ngắm theo độ;
    // số độ chỉ ở kết quả cho đối thủ. % BHE đọc từ cú thủ, không tính lại.
    return [
      header,
      Vi.safetyHeadline(s),
      Vi.planBallLine(s.ballNum),
      Vi.safetyAimLine(s),
      Vi.simStrokeLine(s.stroke),
      Vi.simPowerLine(s.power),
      if (!s.spin.isNone) ...[
        Vi.simSpinLine(s.spin),
        squirtLineFor(s.spin, s.aimed.aimOffsetDeg, s.contactDistance, table,
            bhePercent: s.sawsBhePercent),
      ],
      Vi.safetyOpponent(s.opponent),
      Vi.safetyTolerance(s.tolerance, toleranceSamples),
      if (s.power >= riskPower || s.stroke == Stroke.draw) Vi.planRiskWarning,
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
    // Bước cuối không có bi kế tiếp: chỉ nói số băng, không nói vùng điều.
    if (railCount > 0)
      step.nextBallNum == null ? Vi.planRailInfoLast(railCount) : Vi.planRailInfo(railCount),
    if (step.power >= riskPower || step.stroke == Stroke.draw) Vi.planRiskWarning,
    if (step.missAdvice case final m?) Vi.planMissAdvice(m.safer),
    if (step.kind == PlanStepKind.fallback) Vi.planNoPosition,
  ];
}
