import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Trạng thái một bi: tâm, vận tốc trên mặt bàn và xoáy 3 chiều.
///
/// Bi không rời khăn (spec mục 1, ngoài phạm vi), nên vận tốc chỉ có hai
/// chiều; xoáy thì có trục bất kỳ — trục nghiêng là nguồn của swerve.
class BallState {
  const BallState({
    required this.pos,
    this.vel = Vec2.zero,
    this.spin = Vec3.zero,
  });

  final Vec2 pos;

  /// cm/s.
  final Vec2 vel;

  /// rad/s.
  final Vec3 spin;

  bool get isStopped => vel.length < stopSpeed && spin.length < stopSpin;

  BallState copyWith({Vec2? pos, Vec2? vel, Vec3? spin}) => BallState(
        pos: pos ?? this.pos,
        vel: vel ?? this.vel,
        spin: spin ?? this.spin,
      );

  /// Vận tốc trượt của điểm bi chạm khăn: `vel + ω × (−R ẑ)`.
  ///
  /// Bằng 0 nghĩa là bi lăn đều; khác 0 thì ma sát khăn đang làm việc.
  Vec2 slip(double radius) =>
      Vec2(vel.x - radius * spin.y, vel.y + radius * spin.x);

  /// Động năng tịnh tiến cộng quay, g·cm²/s². Bi đặc: `I = 2/5·m·R²`.
  double kineticEnergy(double radius) =>
      0.5 * ballMass * vel.dot(vel) +
      0.5 * 0.4 * ballMass * radius * radius * spin.dot(spin);

  @override
  bool operator ==(Object other) =>
      other is BallState &&
      other.pos == pos &&
      other.vel == vel &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(pos, vel, spin);

  @override
  String toString() => 'BallState($pos, $vel, $spin)';
}
