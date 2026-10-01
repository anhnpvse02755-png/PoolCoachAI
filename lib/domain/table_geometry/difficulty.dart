import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';

/// Độ khó chỉ theo góc cắt — cùng thước đo `diff` mà Planner dùng
/// (PRD §5.4), để hai màn nói cùng một ngôn ngữ.
enum DifficultyBand { easy, medium, hard, veryHard, extreme, impossible }

/// Biên dưới thuộc mức trên: đúng 15° là Vừa. Đúng 85° vẫn Cực khó.
DifficultyBand bandFor(double angle) {
  if (angle > maxCutAngle) return DifficultyBand.impossible;
  if (angle < 15) return DifficultyBand.easy;
  if (angle < 30) return DifficultyBand.medium;
  if (angle < 45) return DifficultyBand.hard;
  if (angle < 60) return DifficultyBand.veryHard;
  return DifficultyBand.extreme;
}

DifficultyBand bandOf(ShotResult result) => switch (result) {
      Makeable(:final geometry) => bandFor(geometry.angle),
      Unmakeable() => DifficultyBand.impossible,
    };
