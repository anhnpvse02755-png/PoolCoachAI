import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Câu trả lời của người chơi (spec mục 6.3).
sealed class CoachAnswer {
  const CoachAnswer();
}

/// Ăn bi: lỗ, kiểu đánh, lực, áp phê — đúng các thông số của Planner.
final class PotAnswer extends CoachAnswer {
  const PotAnswer({
    required this.ball,
    required this.pocket,
    required this.stroke,
    required this.power,
    this.spin = const SideSpin.none(),
  });

  final int ball;
  final Pocket pocket;
  final Stroke stroke;
  final double power;
  final SideSpin spin;

  /// Khoá mô phỏng của cú này, cùng dạng với khoá của Planner.
  ShotKey key({required Vec2 cue, required Vec2 object}) =>
      (cue: cue, object: object, pocket: pocket, stroke: stroke, spin: spin, power: power);

  /// Cùng cú với [key] (bỏ qua vị trí bi).
  bool matches(ShotKey key) =>
      key.pocket == pocket && key.stroke == stroke && key.spin == spin && key.power == power;

  @override
  bool operator ==(Object other) =>
      other is PotAnswer &&
      other.ball == ball &&
      other.pocket == pocket &&
      other.stroke == stroke &&
      other.power == power &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(ball, pocket, stroke, power, spin);
}

/// Phòng thủ. Giai đoạn A chỉ chấm lựa chọn, không chấm chi tiết cú thủ.
final class SafetyAnswer extends CoachAnswer {
  const SafetyAnswer();

  @override
  bool operator ==(Object other) => other is SafetyAnswer;

  @override
  int get hashCode => 7;
}
