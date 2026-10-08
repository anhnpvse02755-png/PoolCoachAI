import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// normal: phương án đã chấm (tầng 1 hoặc 2). fallback: Đánh đứng bi
/// [fallbackPower], không có vị trí tốt (tầng 3). safety: phòng thủ — tìm
/// cú thủ rồi kế hoạch dừng, vì tới lượt đối thủ (tầng 4, hoặc không cặp
/// bi–lỗ nào).
enum PlanStepKind { normal, fallback, safety }

/// Điểm dừng khi lực −15 % và +15 %; null ở mức hỏng.
typedef JitterEnds = ({Vec2? minus, Vec2? plus});

/// Một bước của kế hoạch (spec mục 4.4).
class PlanStep {
  const PlanStep({
    required this.kind,
    required this.cbFrom,
    this.ballNum,
    this.geometry,
    this.stroke = Stroke.stun,
    this.power = 0,
    this.spin = const SideSpin.none(),
    this.aimed,
    this.score,
    this.jitterEnds,
    this.tolerance,
    this.missAdvice,
    this.sawsBhePercent,
    this.nextBallNum,
    this.safety,
  });

  const PlanStep.safety({required this.cbFrom, this.ballNum, this.safety})
      : kind = PlanStepKind.safety,
        geometry = null,
        stroke = Stroke.stun,
        power = 0,
        spin = const SideSpin.none(),
        aimed = null,
        score = null,
        jitterEnds = null,
        tolerance = null,
        missAdvice = null,
        sawsBhePercent = null,
        nextBallNum = null;

  final PlanStepKind kind;

  /// Điểm bi cái trước cú đánh — chính đối tượng `cueEnd` của bước trước.
  final Vec2 cbFrom;

  /// null chỉ ở bước phòng thủ 8 bi khi không có bi cụ thể bị ép (PRD §4).
  final int? ballNum;
  final ShotGeometry? geometry;
  final Stroke stroke;
  final double power;
  final SideSpin spin;

  /// Cú đã dò; màn từng bước dùng lại dòng áp phê của màn mô phỏng.
  /// `aimOffsetDeg` của nó không bao giờ hiện lên màn.
  final AimedShot? aimed;
  final OptionScore? score;
  final JitterEnds? jitterEnds;

  /// null khi là bi cuối (không có bi kế tiếp để xếp vùng điều).
  final ToleranceCounts? tolerance;

  /// null khi là bi cuối.
  final MissAdvice? missAdvice;

  /// Chỉ có khi dùng áp phê.
  final int? sawsBhePercent;
  final int? nextBallNum;

  /// Cú thủ đã tìm (spec cú phòng thủ 3.7); null ở bước thường, và ở bước
  /// phòng thủ khi không còn cú thủ hợp lệ nào. 8 bi: [ballNum] vẫn null,
  /// bi được chạm là `safety.ballNum`.
  final SafetyShot? safety;

  ShotTrace? get trace => aimed?.trace;
  Pocket? get pocket => geometry?.pocket;
  double? get cutAngle => geometry?.angle;
}
