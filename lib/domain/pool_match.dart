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
    this.cueId,
    this.tournamentId,
    this.roundLabel,
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

  /// Cây cơ người chơi dùng trong trận; null là không ghi cơ. Giữ nguyên cả
  /// khi cơ bị xóa sau đó.
  final String? cueId;

  /// Giải đấu của trận; null là trận thường. Giữ nguyên cả khi giải bị xóa mềm.
  final String? tournamentId;

  /// Vòng đấu trong giải (ví dụ bán kết); giữ nguyên cả khi giải bị xóa mềm.
  final String? roundLabel;

  int get playerScore =>
      rackWinners.where((winner) => winner == RackWinner.player).length;

  int get opponentScore =>
      rackWinners.where((winner) => winner == RackWinner.opponent).length;

  bool get isComplete =>
      playerScore >= targetRacks || opponentScore >= targetRacks;
}
