import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

final tToday = DateTime(2026, 10, 28, 10);

DateTime tDay(int offset) => DateTime(2026, 10, 28 + offset);

Tournament tour(
  String id, {
  required DateTime start,
  DateTime? end,
  String? name,
  PoolGameType? gameType,
  String? location,
  String? resultNote,
  String? notes,
}) => Tournament(
  id: id,
  name: name ?? 'Giải $id',
  startDate: start,
  endDate: end,
  gameType: gameType,
  location: location,
  resultNote: resultNote,
  notes: notes,
);

PoolMatch tMatch(
  String id, {
  String? tournamentId,
  String? round,
  int won = 3,
  int lost = 1,
  int? target,
  DateTime? at,
}) {
  final targetRacks = target ?? (won > lost ? won : lost);
  final winners = [
    for (var i = 0; i < won; i++) RackWinner.player,
    for (var i = 0; i < lost; i++) RackWinner.opponent,
  ];
  final startedAt = at ?? tToday;
  final complete = won >= targetRacks || lost >= targetRacks;
  return PoolMatch(
    id: id,
    gameType: PoolGameType.nineBall,
    playerName: 'An',
    opponentName: 'Đối thủ $id',
    targetRacks: targetRacks,
    rackWinners: winners,
    startedAt: startedAt,
    completedAt: complete ? startedAt.add(const Duration(hours: 1)) : null,
    tournamentId: tournamentId,
    roundLabel: round,
  );
}

PlayerGoal prepGoal(DateTime eventDate, {String? tournamentId}) => PlayerGoal(
  goalId: 'g',
  kind: GoalKind.chuanBiGiai,
  eventDate: eventDate,
  createdAt: tToday,
  tournamentId: tournamentId,
);
