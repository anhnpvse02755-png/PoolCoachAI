enum PoolGameType { eightBall, nineBall, tenBall }

enum RackWinner { player, opponent }

enum MatchShotType { breakShot, normal, safety }

enum MatchShotOutcome { made, missed, foul, scratch }

enum PositionOutcome { successful, unsuccessful }

class MatchShot {
  const MatchShot({
    required this.id,
    required this.rackNumber,
    required this.shotNumber,
    required this.shooter,
    required this.type,
    required this.outcome,
    required this.recordedAt,
    this.positionOutcome,
    this.notes,
  });

  final String id;
  final int rackNumber;
  final int shotNumber;
  final RackWinner shooter;
  final MatchShotType type;
  final MatchShotOutcome outcome;
  final PositionOutcome? positionOutcome;
  final String? notes;
  final DateTime recordedAt;
}

class PoolMatch {
  const PoolMatch({
    required this.id,
    required this.gameType,
    required this.playerName,
    required this.opponentName,
    required this.targetRacks,
    required this.rackWinners,
    required this.startedAt,
    this.shots = const [],
    this.completedAt,
  });

  final String id;
  final PoolGameType gameType;
  final String playerName;
  final String opponentName;
  final int targetRacks;
  final List<RackWinner> rackWinners;
  final DateTime startedAt;
  final List<MatchShot> shots;
  final DateTime? completedAt;

  int get playerScore =>
      rackWinners.where((winner) => winner == RackWinner.player).length;

  int get opponentScore =>
      rackWinners.where((winner) => winner == RackWinner.opponent).length;

  bool get isComplete =>
      playerScore >= targetRacks || opponentScore >= targetRacks;
}
