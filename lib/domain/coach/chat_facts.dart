import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Thẻ "Hôm nay" cho Coach Chat, dạng dữ liệu (spec Giai đoạn B, luật R2).
typedef TodayFacts = ({
  SkillCategory category,
  PickReason reason,
  String? drillId,
  String? drillName,
  String? articleTitle,
  int streak,
  int practiceMinutesThisWeek,
  List<String> scheduledToday,
});

/// Trận gần nhất, dạng dữ liệu — chỉ tính cú của chính người chơi.
typedef LastMatchFacts = ({
  PoolGameType gameType,
  int targetRacks,
  int racksWon,
  int racksLost,
  bool won,
  Map<MatchShotType, Map<MatchShotOutcome, int>> shots,
  Map<PositionOutcome, int> positionOutcomes,
});

/// Tổng quan các trận gần nhất, dạng dữ liệu (luật R3).
typedef MatchFacts = ({int played, int won, int lost, LastMatchFacts? last});

/// Chuyển gợi ý hôm nay sang dữ liệu cho Coach Chat (luật R2).
TodayFacts todayFactsOf(TodayRecommendation today) => (
      category: today.cat,
      reason: today.reason,
      drillId: today.drill?.id,
      drillName: today.drill?.name,
      articleTitle: today.article?.title,
      streak: today.streak,
      practiceMinutesThisWeek: today.practiceSecondsThisWeek ~/ 60,
      scheduledToday: [for (final slot in today.todaySchedule) slot.label],
    );

/// Chuyển lịch sử trận sang dữ liệu cho Coach Chat (luật R3).
///
/// Chỉ trận đã xong (`isComplete`) được tính; sắp theo `completedAt` (hoặc
/// `startedAt` nếu thiếu), mới nhất trước, hoà ngày thì theo `id`. Tối đa
/// [coachChatRecentMatches] trận gần nhất vào `played`/`won`/`lost`; `last`
/// là trận đầu sau khi sắp.
MatchFacts matchFactsOf(List<PoolMatch> matches) {
  final finished = matches.where((m) => m.isComplete).toList()
    ..sort((a, b) {
      final atA = a.completedAt ?? a.startedAt;
      final atB = b.completedAt ?? b.startedAt;
      final byDate = atB.compareTo(atA);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final recent = finished.take(coachChatRecentMatches).toList();
  final won = recent.where((m) => m.playerScore >= m.targetRacks).length;

  return (
    played: recent.length,
    won: won,
    lost: recent.length - won,
    last: recent.isEmpty ? null : _lastMatchFactsOf(recent.first),
  );
}

LastMatchFacts _lastMatchFactsOf(PoolMatch match) {
  final shots = <MatchShotType, Map<MatchShotOutcome, int>>{
    for (final type in MatchShotType.values)
      type: {for (final outcome in MatchShotOutcome.values) outcome: 0},
  };
  final positionOutcomes = <PositionOutcome, int>{
    for (final outcome in PositionOutcome.values) outcome: 0,
  };

  for (final shot in match.shots) {
    if (shot.shooter != RackWinner.player) continue;
    final byType = shots[shot.type]!;
    byType[shot.outcome] = byType[shot.outcome]! + 1;
    final position = shot.positionOutcome;
    if (position != null) {
      positionOutcomes[position] = positionOutcomes[position]! + 1;
    }
  }

  return (
    gameType: match.gameType,
    targetRacks: match.targetRacks,
    racksWon: match.playerScore,
    racksLost: match.opponentScore,
    won: match.playerScore >= match.targetRacks,
    shots: shots,
    positionOutcomes: positionOutcomes,
  );
}
