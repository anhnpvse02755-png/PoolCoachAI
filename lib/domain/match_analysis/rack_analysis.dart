import 'package:poolcoachai/domain/pool_match.dart';

/// Vì sao người chơi mất lượt sau một cú.
enum TurnoverCause {
  offensiveMiss,
  safety,
  foul,
  scratch,
  dryBreak,

  /// Cú vừa rồi vào bi mà lượt vẫn sang đối thủ; không suy ra được lý do.
  unknown,
}

/// Vì sao người chơi thua một ván.
enum LostRackCause {
  offensiveMiss,
  safety,
  foul,
  scratch,
  dryBreak,
  opponentBreakAndRun,

  /// Ván chưa được ghi đủ cú nên không kết luận.
  notFull,

  /// Ván ghi đủ nhưng không suy ra được nguyên nhân (cú cuối của người chơi
  /// là cú vào bi).
  unclear,
}

/// Nguyên nhân mất lượt sau [shot].
TurnoverCause turnoverCauseOf(MatchShot shot) {
  switch (shot.outcome) {
    case MatchShotOutcome.foul:
      return TurnoverCause.foul;
    case MatchShotOutcome.scratch:
      return TurnoverCause.scratch;
    case MatchShotOutcome.missed:
    case MatchShotOutcome.made:
      break;
  }
  if (shot.type == MatchShotType.breakShot &&
      shot.outcome == MatchShotOutcome.missed) {
    return TurnoverCause.dryBreak;
  }
  if (shot.type == MatchShotType.safety) return TurnoverCause.safety;
  if (shot.type == MatchShotType.normal &&
      shot.outcome == MatchShotOutcome.missed) {
    return TurnoverCause.offensiveMiss;
  }
  return TurnoverCause.unknown;
}

/// Kết quả phân tích một ván của một trận.
final class RackAnalysis {
  const RackAnalysis({
    required this.rackNumber,
    required this.winner,
    required this.shots,
    required this.hasShots,
    required this.isFull,
    required this.breaker,
    required this.breakResult,
    required this.breakAndRun,
    required this.runOut,
    required this.turnovers,
    required this.lostRackCause,
  });

  final int rackNumber;
  final RackWinner winner;

  /// Các cú của ván, theo `shotNumber`.
  final List<MatchShot> shots;

  /// Ván có ghi ít nhất một cú.
  final bool hasShots;

  /// Ván được ghi đủ từ cú phá đến cú chốt ván.
  final bool isFull;

  final RackWinner? breaker;
  final MatchShotOutcome? breakResult;
  final bool breakAndRun;
  final bool runOut;

  /// Nguyên nhân mỗi lần người chơi mất lượt; rỗng khi ván chưa ghi đủ.
  final List<TurnoverCause> turnovers;

  /// Nguyên nhân thua ván; null khi người chơi thắng.
  final LostRackCause? lostRackCause;
}

RackAnalysis analyzeRack(PoolMatch match, int rackIndex) {
  final rackNumber = rackIndex + 1;
  final winner = match.rackWinners[rackIndex];
  final shots = [
    for (final shot in match.shots)
      if (shot.rackNumber == rackNumber) shot,
  ]..sort((a, b) => a.shotNumber.compareTo(b.shotNumber));

  final first = shots.isEmpty ? null : shots.first;
  final breaker = first != null && first.type == MatchShotType.breakShot
      ? first.shooter
      : null;
  final breakResult = breaker == null ? null : first!.outcome;

  final isFull = _isFull(shots, winner);
  final playerShots = [
    for (final s in shots)
      if (s.shooter == RackWinner.player) s,
  ];
  final opponentShots = shots.length - playerShots.length;

  final breakAndRun = isFull &&
      breaker != null &&
      winner == breaker &&
      (winner == RackWinner.player ? opponentShots == 0 : playerShots.isEmpty);
  final runOut = winner == RackWinner.player &&
      isFull &&
      opponentShots >= 1 &&
      shots.last.shooter == RackWinner.player;

  final turnovers = <TurnoverCause>[];
  if (isFull) {
    for (var i = 0; i + 1 < shots.length; i++) {
      if (shots[i].shooter == RackWinner.player &&
          shots[i + 1].shooter == RackWinner.opponent) {
        turnovers.add(turnoverCauseOf(shots[i]));
      }
    }
  }

  LostRackCause? lost;
  if (winner == RackWinner.opponent) {
    if (!isFull) {
      lost = LostRackCause.notFull;
    } else if (playerShots.isEmpty) {
      lost = LostRackCause.opponentBreakAndRun;
    } else {
      lost = switch (turnoverCauseOf(playerShots.last)) {
        TurnoverCause.offensiveMiss => LostRackCause.offensiveMiss,
        TurnoverCause.safety => LostRackCause.safety,
        TurnoverCause.foul => LostRackCause.foul,
        TurnoverCause.scratch => LostRackCause.scratch,
        TurnoverCause.dryBreak => LostRackCause.dryBreak,
        TurnoverCause.unknown => LostRackCause.unclear,
      };
    }
  }

  return RackAnalysis(
    rackNumber: rackNumber,
    winner: winner,
    shots: List.unmodifiable(shots),
    hasShots: shots.isNotEmpty,
    isFull: isFull,
    breaker: breaker,
    breakResult: breakResult,
    breakAndRun: breakAndRun,
    runOut: runOut,
    turnovers: List.unmodifiable(turnovers),
    lostRackCause: lost,
  );
}

bool _isFull(List<MatchShot> shots, RackWinner winner) {
  if (shots.length < 2) return false;
  if (shots.first.type != MatchShotType.breakShot) return false;
  for (var i = 0; i < shots.length; i++) {
    if (shots[i].shotNumber != i + 1) return false;
  }
  final last = shots.last;
  if (last.shooter == winner) return last.outcome == MatchShotOutcome.made;
  return last.outcome == MatchShotOutcome.foul ||
      last.outcome == MatchShotOutcome.scratch;
}
