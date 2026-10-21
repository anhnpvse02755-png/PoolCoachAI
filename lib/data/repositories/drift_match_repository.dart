import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/match_codec.dart';
import 'package:poolcoachai/data/repositories/match_repository.dart';
import 'package:poolcoachai/domain/pool_match.dart';

class DriftMatchRepository implements MatchRepository {
  DriftMatchRepository(
    this._db, {
    required this._userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;

  @override
  Stream<List<PoolMatch>> watchAll() =>
      (_db.select(_db.poolMatchRows)
            ..where((row) => row.userId.equals(_userId))
            ..orderBy([
              (row) => OrderingTerm.desc(row.startedAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .watch()
          .map((rows) => rows.map(_toDomain).toList(growable: false));

  @override
  Future<void> start(PoolMatch match) async {
    if (match.id.trim().isEmpty ||
        match.playerName.trim().isEmpty ||
        match.opponentName.trim().isEmpty) {
      throw ArgumentError('Trận đấu cần mã và tên hai người chơi');
    }
    if (match.targetRacks <= 0) {
      throw ArgumentError.value(match.targetRacks, 'targetRacks');
    }
    if (match.rackWinners.isNotEmpty || match.completedAt != null) {
      throw ArgumentError('Trận mới không được có kết quả rack');
    }

    final cueId = match.cueId;
    if (cueId != null) {
      final cue =
          await (_db.select(_db.cueEquipmentRows)..where(
                (row) =>
                    row.id.equals(cueId) &
                    row.userId.equals(_userId) &
                    row.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (cue == null) {
        throw StateError('Cơ không tồn tại hoặc không thuộc tài khoản này');
      }
    }

    final existing = await (_db.select(
      _db.poolMatchRows,
    )..where((row) => row.id.equals(match.id))).getSingleOrNull();
    if (existing != null) {
      throw StateError('Mã trận đấu đã được sử dụng');
    }
    await _db
        .into(_db.poolMatchRows)
        .insert(_toCompanion(match, userId: _userId, updatedAt: _now()));
  }

  @override
  Future<void> recordRack(String matchId, RackWinner winner) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId);
      final updatedWinners = [...decodeMatchWinners(match.rackWinners), winner];
      final complete =
          updatedWinners.where((value) => value == winner).length >=
          match.targetRacks;
      await (_db.update(_db.poolMatchRows)..where(
            (row) => row.id.equals(matchId) & row.userId.equals(_userId),
          ))
          .write(
            PoolMatchRowsCompanion(
              rackWinners: Value(encodeMatchWinners(updatedWinners)),
              completedAt: Value(complete ? _now() : null),
              updatedAt: Value(_now()),
              syncedAt: const Value(null),
            ),
          );
    });
  }

  @override
  Future<void> undoLastRack(String matchId) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId, allowCompleted: true);
      final winners = decodeMatchWinners(match.rackWinners);
      if (winners.isEmpty) {
        throw StateError('Trận đấu chưa có rack để hoàn tác');
      }
      final removedRack = winners.length;
      winners.removeLast();
      final shots = decodeMatchShots(match.shots)
          .where((shot) => shot.rackNumber != removedRack)
          .map(
            (shot) => shot.rackNumber > removedRack
                ? MatchShot(
                    id: shot.id,
                    rackNumber: shot.rackNumber - 1,
                    shotNumber: shot.shotNumber,
                    shooter: shot.shooter,
                    type: shot.type,
                    outcome: shot.outcome,
                    positionOutcome: shot.positionOutcome,
                    notes: shot.notes,
                    recordedAt: shot.recordedAt,
                  )
                : shot,
          )
          .toList(growable: false);
      await (_db.update(_db.poolMatchRows)..where(
            (row) => row.id.equals(matchId) & row.userId.equals(_userId),
          ))
          .write(
            PoolMatchRowsCompanion(
              rackWinners: Value(encodeMatchWinners(winners)),
              shots: Value(encodeMatchShots(shots)),
              completedAt: const Value(null),
              updatedAt: Value(_now()),
              syncedAt: const Value(null),
            ),
          );
    });
  }

  @override
  Future<void> recordShot(String matchId, MatchShot shot) async {
    if (shot.id.trim().isEmpty ||
        shot.rackNumber <= 0 ||
        shot.shotNumber <= 0) {
      throw ArgumentError('Cú đánh cần mã và số thứ tự hợp lệ');
    }
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId);
      final winners = decodeMatchWinners(match.rackWinners);
      final rackNumber = winners.length + 1;
      final shots = decodeMatchShots(match.shots);
      final rackShots = shots.where((value) => value.rackNumber == rackNumber);
      final nextShotNumber = rackShots.length + 1;
      if (shot.rackNumber != rackNumber || shot.shotNumber != nextShotNumber) {
        throw StateError('Cú đánh không thuộc ván hiện tại hoặc sai thứ tự');
      }
      if (shots.any((value) => value.id == shot.id)) {
        throw StateError('Mã cú đánh đã được sử dụng');
      }
      shots.add(shot);
      await (_db.update(_db.poolMatchRows)..where(
            (row) => row.id.equals(matchId) & row.userId.equals(_userId),
          ))
          .write(
            PoolMatchRowsCompanion(
              shots: Value(encodeMatchShots(shots)),
              updatedAt: Value(_now()),
              syncedAt: const Value(null),
            ),
          );
    });
  }

  @override
  Future<void> undoLastShot(String matchId) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId);
      final rackNumber = decodeMatchWinners(match.rackWinners).length + 1;
      final shots = decodeMatchShots(match.shots);
      final rackShots = shots
          .where((shot) => shot.rackNumber == rackNumber)
          .toList(growable: false);
      if (rackShots.isEmpty) {
        throw StateError('Ván hiện tại chưa có cú đánh để hoàn tác');
      }
      final lastShot = rackShots.reduce(
        (a, b) => a.shotNumber > b.shotNumber ? a : b,
      );
      shots.removeWhere((shot) => shot.id == lastShot.id);
      await (_db.update(_db.poolMatchRows)..where(
            (row) => row.id.equals(matchId) & row.userId.equals(_userId),
          ))
          .write(
            PoolMatchRowsCompanion(
              shots: Value(encodeMatchShots(shots)),
              updatedAt: Value(_now()),
              syncedAt: const Value(null),
            ),
          );
    });
  }

  Future<PoolMatchRow> _ownedMatch(
    String id, {
    bool allowCompleted = false,
  }) async {
    final match =
        await (_db.select(_db.poolMatchRows)
              ..where((row) => row.id.equals(id) & row.userId.equals(_userId)))
            .getSingleOrNull();
    if (match == null) {
      throw StateError('Trận đấu không tồn tại hoặc không thuộc tài khoản này');
    }
    if (!allowCompleted && _toDomain(match).isComplete) {
      throw StateError('Trận đấu đã kết thúc');
    }
    return match;
  }

  PoolMatch _toDomain(PoolMatchRow row) => PoolMatch(
    id: row.id,
    gameType: PoolGameType.values.firstWhere(
      (type) => type.name == row.gameType,
      orElse: () =>
          throw FormatException('Unknown PoolGameType: ${row.gameType}'),
    ),
    playerName: row.playerName,
    opponentName: row.opponentName,
    targetRacks: row.targetRacks,
    rackWinners: decodeMatchWinners(row.rackWinners),
    startedAt: row.startedAt,
    shots: decodeMatchShots(row.shots),
    completedAt: row.completedAt,
    cueId: row.cueId,
  );

  PoolMatchRowsCompanion _toCompanion(
    PoolMatch match, {
    required String userId,
    required DateTime updatedAt,
  }) => PoolMatchRowsCompanion.insert(
    id: match.id,
    userId: userId,
    gameType: match.gameType.name,
    playerName: match.playerName.trim(),
    opponentName: match.opponentName.trim(),
    targetRacks: match.targetRacks,
    rackWinners: encodeMatchWinners(match.rackWinners),
    startedAt: match.startedAt,
    completedAt: Value(match.completedAt),
    cueId: Value(match.cueId),
    updatedAt: Value(updatedAt),
  );
}
