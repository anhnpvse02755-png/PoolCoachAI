import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Một lần thử của người chơi thuộc một nhóm kỹ năng, và có hỏng hay không.
typedef SkillAttempt = ({SkillCategory category, bool failed});

/// Cú ngay sau [shot] trong cùng ván, chỉ khi ván được ghi đủ (spec mục 3:
/// kết luận theo chuỗi chỉ lấy từ ván đủ cú) và cú đó đúng số `shotNumber + 1`.
MatchShot? followingShotInFullRack(RackAnalysis rack, MatchShot shot) {
  if (!rack.isFull) return null;
  // Ván đủ cú có shotNumber liên tục 1..n nên cú kế tiếp nằm ở chỉ số này.
  final index = shot.shotNumber;
  if (index < 0 || index >= rack.shots.length) return null;
  final next = rack.shots[index];
  return next.shotNumber == shot.shotNumber + 1 ? next : null;
}

/// Quy các cú của người chơi (trong ván đã có người thắng) về nhóm kỹ năng.
///
/// Spec mục 4.3. Cú của đối thủ không vào nhóm nào.
List<SkillAttempt> shotSkillMap(PoolMatch match) {
  final attempts = <SkillAttempt>[];
  for (var i = 0; i < match.rackWinners.length; i++) {
    final rack = analyzeRack(match, i);
    for (final shot in rack.shots) {
      if (shot.shooter != RackWinner.player) continue;
      attempts.addAll(_attemptsOf(rack, shot));
    }
  }
  return attempts;
}

List<SkillAttempt> _attemptsOf(RackAnalysis rack, MatchShot shot) {
  final out = <SkillAttempt>[];
  switch (shot.type) {
    case MatchShotType.breakShot:
      out.add((
        category: SkillCategory.breakShot,
        failed: shot.outcome != MatchShotOutcome.made,
      ));
    case MatchShotType.normal:
      switch (shot.outcome) {
        case MatchShotOutcome.scratch:
          out.add((category: SkillCategory.position, failed: true));
        case MatchShotOutcome.missed:
          out.add((category: SkillCategory.aiming, failed: true));
        case MatchShotOutcome.made:
          out.add((category: SkillCategory.aiming, failed: false));
        case MatchShotOutcome.foul:
          break; // lỗi không quy về nhóm nào
      }
    case MatchShotType.safety:
      final next = followingShotInFullRack(rack, shot);
      if (next != null && next.shooter == RackWinner.opponent) {
        out.add((
          category: SkillCategory.safety,
          failed: next.outcome == MatchShotOutcome.made,
        ));
      }
  }
  // Chết cái ở cú thường đã tính là một lần Điều bi ở trên; không tính hai lần.
  if (shot.positionOutcome != null &&
      shot.outcome != MatchShotOutcome.scratch) {
    out.add((
      category: SkillCategory.position,
      failed: shot.positionOutcome == PositionOutcome.unsuccessful,
    ));
  }
  return out;
}
