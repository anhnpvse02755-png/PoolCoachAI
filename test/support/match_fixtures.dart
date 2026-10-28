import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';

MatchShot shotAt(
  int rack,
  int n,
  RackWinner who,
  MatchShotType type,
  MatchShotOutcome outcome, {
  PositionOutcome? position,
}) =>
    MatchShot(
      id: 'r$rack-s$n',
      rackNumber: rack,
      shotNumber: n,
      shooter: who,
      type: type,
      outcome: outcome,
      positionOutcome: position,
      recordedAt: DateTime(2026, 10, 1, 20, n),
    );

/// Trận hoàn tất; số ván mục tiêu là điểm cao hơn trong hai bên.
PoolMatch completedMatch(
  String id,
  List<RackWinner> racks,
  List<MatchShot> shots, {
  DateTime? at,
}) {
  final player = racks.where((w) => w == RackWinner.player).length;
  final opponent = racks.length - player;
  final done = at ?? DateTime(2026, 10, 1, 20);
  return PoolMatch(
    id: id,
    gameType: PoolGameType.eightBall,
    playerName: 'Player',
    opponentName: 'Opponent',
    targetRacks: player > opponent ? player : opponent,
    rackWinners: racks,
    startedAt: done.subtract(const Duration(hours: 1)),
    shots: shots,
    completedAt: done,
  );
}

/// [count] trận, mỗi trận yếu đúng nhóm [weak] (`aiming` hoặc `position`),
/// lùi dần 0, 1, 2 ... ngày từ [at]. Không có cú phá của người chơi hay cú
/// phòng thủ nào để các nhóm khác không vượt ngưỡng.
List<PoolMatch> matchesWeakAt(
  SkillCategory weak, {
  int count = 3,
  required DateTime at,
}) {
  if (weak != SkillCategory.aiming && weak != SkillCategory.position) {
    throw ArgumentError.value(weak, 'weak', 'only aiming or position');
  }
  const p = RackWinner.player;
  const o = RackWinner.opponent;
  const b = MatchShotType.breakShot;
  const nm = MatchShotType.normal;
  const made = MatchShotOutcome.made;
  const missed = MatchShotOutcome.missed;
  const ok = PositionOutcome.successful;
  const bad = PositionOutcome.unsuccessful;

  final List<MatchShot> shots;
  if (weak == SkillCategory.aiming) {
    // 5 cú tấn công của người chơi, 3 trượt (60%), mọi điều bi đều tốt.
    shots = [
      shotAt(1, 1, o, b, missed),
      shotAt(1, 2, p, nm, missed),
      shotAt(1, 3, o, nm, missed),
      shotAt(1, 4, p, nm, missed),
      shotAt(1, 5, o, nm, missed),
      shotAt(1, 6, p, nm, missed),
      shotAt(1, 7, o, nm, missed),
      shotAt(1, 8, p, nm, made, position: ok),
      shotAt(1, 9, p, nm, made, position: ok),
    ];
  } else {
    // 5 lần điều bi, 4 hỏng (80%), không cú trượt nào.
    shots = [
      shotAt(1, 1, o, b, missed),
      shotAt(1, 2, p, nm, made, position: bad),
      shotAt(1, 3, p, nm, made, position: bad),
      shotAt(1, 4, p, nm, made, position: bad),
      shotAt(1, 5, p, nm, made, position: bad),
      shotAt(1, 6, p, nm, made, position: ok),
    ];
  }

  return [
    for (var i = 0; i < count; i++)
      completedMatch(
        'weak-${weak.name}-$i',
        const [RackWinner.player],
        shots,
        at: at.subtract(Duration(days: i)),
      ),
  ];
}
