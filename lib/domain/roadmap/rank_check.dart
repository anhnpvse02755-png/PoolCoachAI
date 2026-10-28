import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis_constants.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Hướng của gợi ý làm lại bài BU.
enum RankCheckDirection { down, up }

/// Gợi ý dựa trên bài tập hay dựa trên các trận.
enum RankCheckBasis { drills, matches }

/// Gợi ý làm lại bài BU (spec 2026-10-28 mục 6.5). Chỉ là một lời nhắc: hạng
/// chỉ đổi qua một bài BU (rank spec Q15), hàm này không đụng tới hạng.
final class RankCheckSignal {
  const RankCheckSignal({
    required this.direction,
    required this.basis,
    required this.categories,
    required this.rank,
  });

  final RankCheckDirection direction;
  final RankCheckBasis basis;

  /// Các nhóm làm nên gợi ý.
  final List<SkillCategory> categories;

  /// Hạng nên kiểm tra: hạng hiện tại khi đi xuống, hạng kế tiếp khi đi lên.
  final Rank rank;
}

const _minGroups = 2;

/// Null khi chưa nên gợi ý: hạng chưa kiểm chứng, chưa có BU, BU còn mới
/// (dưới [MatchAnalysisConstants.rankCheckMinDays] ngày), hoặc tín hiệu lẫn.
RankCheckSignal? rankCheckSignal({
  required PlayerRank? rank,
  required BuResult? latestBu,
  required PlayerIntelligence pi,
  required DateTime today,
}) {
  final current = rank?.rank;
  if (rank == null || !rank.isVerified || current == null || latestBu == null) return null;
  final age = dateOnly(today).difference(dateOnly(latestBu.completedAt)).inDays;
  if (age < MatchAnalysisConstants.rankCheckMinDays) return null;

  // Chỉ nhóm BU từng chấm mới nói được điều gì về hạng.
  List<SkillCategory> graded(SkillTrend trend) => [
        for (final cat in SkillCategory.values)
          if (pi.buPercent.containsKey(cat) && pi.categories[cat]?.trend == trend) cat,
      ];

  final down = graded(SkillTrend.down);
  if (down.length >= _minGroups) {
    return RankCheckSignal(
      direction: RankCheckDirection.down,
      basis: RankCheckBasis.drills,
      categories: down,
      rank: current,
    );
  }
  if (pi.matchWeak.length >= _minGroups) {
    return RankCheckSignal(
      direction: RankCheckDirection.down,
      basis: RankCheckBasis.matches,
      categories: [for (final w in pi.matchWeak) w.category],
      rank: current,
    );
  }
  final up = graded(SkillTrend.up);
  final next = nextRank(current);
  if (up.length >= _minGroups && down.isEmpty && next != null) {
    return RankCheckSignal(
      direction: RankCheckDirection.up,
      basis: RankCheckBasis.drills,
      categories: up,
      rank: next,
    );
  }
  return null;
}
