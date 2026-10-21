import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
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

    final existing = await (_db.select(
      _db.poolMatchRows,
    )..where((row) => row.id.equals(match.id))).getSingleOrNull();
    if (existing != null) {
      throw StateError('Mã trận đấu đã được sử dụng');
    }
    await _db
        .into(_db.poolMatchRows)
        .insert(_toCompanion(match, userId: _userId));
  }

  @override
  Future<void> recordRack(String matchId, RackWinner winner) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId);
      final updatedWinners = [..._decodeWinners(match.rackWinners), winner];
      final complete =
          updatedWinners.where((value) => value == winner).length >=
          match.targetRacks;
      await (_db.update(_db.poolMatchRows)..where(
            (row) => row.id.equals(matchId) & row.userId.equals(_userId),
          ))
          .write(
            PoolMatchRowsCompanion(
              rackWinners: Value(_encodeWinners(updatedWinners)),
              completedAt: Value(complete ? _now() : null),
            ),
          );
    });
  }

  @override
  Future<void> undoLastRack(String matchId) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId, allowCompleted: true);
      final winners = _decodeWinners(match.rackWinners);
      if (winners.isEmpty) {
        throw StateError('Trận đấu chưa có rack để hoàn tác');
      }
      final removedRack = winners.length;
      winners.removeLast();
      final shots = _decodeShots(match.shots)
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
              rackWinners: Value(_encodeWinners(winners)),
              shots: Value(_encodeShots(shots)),
              completedAt: const Value(null),
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
      final winners = _decodeWinners(match.rackWinners);
      final rackNumber = winners.length + 1;
      final shots = _decodeShots(match.shots);
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
          .write(PoolMatchRowsCompanion(shots: Value(_encodeShots(shots))));
    });
  }

  @override
  Future<void> undoLastShot(String matchId) async {
    await _db.transaction(() async {
      final match = await _ownedMatch(matchId);
      final rackNumber = _decodeWinners(match.rackWinners).length + 1;
      final shots = _decodeShots(match.shots);
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
          .write(PoolMatchRowsCompanion(shots: Value(_encodeShots(shots))));
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
    rackWinners: _decodeWinners(row.rackWinners),
    startedAt: row.startedAt,
    shots: _decodeShots(row.shots),
    completedAt: row.completedAt,
  );

  PoolMatchRowsCompanion _toCompanion(
    PoolMatch match, {
    required String userId,
  }) => PoolMatchRowsCompanion.insert(
    id: match.id,
    userId: userId,
    gameType: match.gameType.name,
    playerName: match.playerName.trim(),
    opponentName: match.opponentName.trim(),
    targetRacks: match.targetRacks,
    rackWinners: _encodeWinners(match.rackWinners),
    startedAt: match.startedAt,
    completedAt: Value(match.completedAt),
  );

  String _encodeWinners(List<RackWinner> winners) =>
      jsonEncode(winners.map((winner) => winner.name).toList());

  String _encodeShots(List<MatchShot> shots) => jsonEncode([
    for (final shot in shots)
      {
        'id': shot.id,
        'rackNumber': shot.rackNumber,
        'shotNumber': shot.shotNumber,
        'shooter': shot.shooter.name,
        'type': shot.type.name,
        'outcome': shot.outcome.name,
        'positionOutcome': shot.positionOutcome?.name,
        'notes': shot.notes,
        'recordedAt': shot.recordedAt.toIso8601String(),
      },
  ]);

  List<MatchShot> _decodeShots(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw FormatException('Danh sách cú đánh không hợp lệ', json);
    }
    return decoded
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw FormatException('Thông tin cú đánh không hợp lệ', json);
          }
          final shooterName = value['shooter'];
          final typeName = value['type'];
          final outcomeName = value['outcome'];
          final positionName = value['positionOutcome'];
          final id = value['id'];
          final notes = value['notes'];
          final rackNumber = value['rackNumber'];
          final shotNumber = value['shotNumber'];
          final recordedAt = value['recordedAt'];
          if (id is! String ||
              rackNumber is! int ||
              shotNumber is! int ||
              shooterName is! String ||
              typeName is! String ||
              outcomeName is! String ||
              (positionName != null && positionName is! String) ||
              (notes != null && notes is! String) ||
              recordedAt is! String) {
            throw FormatException(
              'Thông tin cú đánh thiếu trường bắt buộc',
              json,
            );
          }
          return MatchShot(
            id: id,
            rackNumber: rackNumber,
            shotNumber: shotNumber,
            shooter: RackWinner.values.firstWhere(
              (winner) => winner.name == shooterName,
              orElse: () =>
                  throw FormatException('Unknown RackWinner: $shooterName'),
            ),
            type: MatchShotType.values.firstWhere(
              (type) => type.name == typeName,
              orElse: () =>
                  throw FormatException('Unknown MatchShotType: $typeName'),
            ),
            outcome: MatchShotOutcome.values.firstWhere(
              (outcome) => outcome.name == outcomeName,
              orElse: () => throw FormatException(
                'Unknown MatchShotOutcome: $outcomeName',
              ),
            ),
            positionOutcome: positionName == null
                ? null
                : PositionOutcome.values.firstWhere(
                    (position) => position.name == positionName,
                    orElse: () => throw FormatException(
                      'Unknown PositionOutcome: $positionName',
                    ),
                  ),
            notes: notes as String?,
            recordedAt: DateTime.parse(recordedAt),
          );
        })
        .toList(growable: true);
  }

  List<RackWinner> _decodeWinners(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List || decoded.any((winner) => winner is! String)) {
      throw FormatException('Danh sách người thắng rack không hợp lệ', json);
    }
    return decoded
        .cast<String>()
        .map(
          (name) => RackWinner.values.firstWhere(
            (winner) => winner.name == name,
            orElse: () => throw FormatException('Unknown RackWinner: $name'),
          ),
        )
        .toList(growable: true);
  }
}
