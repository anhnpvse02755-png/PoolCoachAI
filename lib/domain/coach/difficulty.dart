import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';

/// Ba mức độ khó của tình huống (spec mục 8.4).
enum CoachDifficulty { easy, medium, hard }

/// Mức chọn sẵn theo điểm thuần thục của nhóm: chưa có điểm hoặc dưới
/// [PracticeConstants.weakCutoff] là Dễ, dưới [PracticeConstants.strongCutoff]
/// là Vừa, còn lại là Khó. Người chơi đổi bằng chip.
CoachDifficulty coachDifficultyFor(CategoryInsight? insight) {
  final m = insight?.mastery;
  if (m == null || m < PracticeConstants.weakCutoff) return CoachDifficulty.easy;
  if (m < PracticeConstants.strongCutoff) return CoachDifficulty.medium;
  return CoachDifficulty.hard;
}

/// Số bi mục tiêu của thế bàn sinh ra, cả hai đầu (spec mục 8.4).
({int min, int max}) coachBallCount(CoachDifficulty d) => switch (d) {
      CoachDifficulty.easy => (min: 3, max: 3),
      CoachDifficulty.medium => (min: 4, max: 5),
      CoachDifficulty.hard => (min: 6, max: 7),
    };

/// Dải góc cắt của bi phải chạm cho nhóm Ngắm bi và Vị trí (spec mục 8.4).
List<DifficultyBand> coachCutBands(CoachDifficulty d) => switch (d) {
      CoachDifficulty.easy => const [DifficultyBand.easy, DifficultyBand.medium],
      CoachDifficulty.medium => const [DifficultyBand.medium, DifficultyBand.hard],
      CoachDifficulty.hard => const [DifficultyBand.hard, DifficultyBand.veryHard],
    };

/// Số bi chắn quanh bi phải chạm cho nhóm Phòng thủ và A băng (spec mục 8.4).
({int min, int max}) coachBlockerCount(CoachDifficulty d) => switch (d) {
      CoachDifficulty.easy => (min: 2, max: 2),
      CoachDifficulty.medium => (min: 3, max: 4),
      CoachDifficulty.hard => (min: 5, max: 6),
    };
