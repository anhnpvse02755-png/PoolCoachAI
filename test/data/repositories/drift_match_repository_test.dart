import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  PoolMatch newMatch(String id) => PoolMatch(
    id: id,
    gameType: PoolGameType.nineBall,
    playerName: 'An',
    opponentName: 'Bình',
    targetRacks: 2,
    rackWinners: const [],
    startedAt: DateTime(2026, 10, 20, 10),
  );

  test(
    'stores a race by account and completes or reopens rack-by-rack',
    () async {
      var now = DateTime(2026, 10, 20, 11);
      final ownRepository = DriftMatchRepository(
        db,
        userId: 'u1',
        now: () => now,
      );
      await ownRepository.start(newMatch('own'));
      await DriftMatchRepository(db, userId: 'u2').start(newMatch('other'));

      expect((await ownRepository.watchAll().first).map((match) => match.id), [
        'own',
      ]);
      final shot = MatchShot(
        id: 'shot-1',
        rackNumber: 1,
        shotNumber: 1,
        shooter: RackWinner.player,
        type: MatchShotType.breakShot,
        outcome: MatchShotOutcome.made,
        positionOutcome: PositionOutcome.successful,
        notes: 'Break tốt',
        recordedAt: now,
      );
      await ownRepository.recordShot('own', shot);
      expect(
        (await ownRepository.watchAll().first).single.shots.single.notes,
        'Break tốt',
      );
      await ownRepository.undoLastShot('own');
      expect((await ownRepository.watchAll().first).single.shots, isEmpty);
      await ownRepository.recordShot('own', shot);
      await ownRepository.recordRack('own', RackWinner.player);
      await ownRepository.recordRack('own', RackWinner.opponent);
      now = DateTime(2026, 10, 20, 11, 5);
      await ownRepository.recordRack('own', RackWinner.player);

      var match = (await ownRepository.watchAll().first).single;
      expect(match.gameType, PoolGameType.nineBall);
      expect(match.playerScore, 2);
      expect(match.opponentScore, 1);
      expect(match.isComplete, isTrue);
      expect(match.completedAt, now);
      await expectLater(
        ownRepository.recordRack('own', RackWinner.player),
        throwsStateError,
      );

      await ownRepository.undoLastRack('own');
      match = (await ownRepository.watchAll().first).single;
      expect(match.playerScore, 1);
      expect(match.opponentScore, 1);
      expect(match.completedAt, isNull);
      expect(match.isComplete, isFalse);
      expect(match.shots, hasLength(1));
      expect(match.shots.single.rackNumber, 1);

      await expectLater(
        DriftMatchRepository(
          db,
          userId: 'u2',
        ).recordRack('own', RackWinner.player),
        throwsStateError,
      );
      expect(
        (await DriftMatchRepository(
          db,
          userId: 'u2',
        ).watchAll().first).single.id,
        'other',
      );
    },
  );

  test(
    'rejects invalid race setup and undo without any recorded rack',
    () async {
      final repository = DriftMatchRepository(db, userId: 'u1');
      await expectLater(
        repository.start(
          PoolMatch(
            id: 'empty-name',
            gameType: PoolGameType.nineBall,
            playerName: ' ',
            opponentName: 'Bình',
            targetRacks: 2,
            rackWinners: const [],
            startedAt: DateTime(2026, 10, 20),
          ),
        ),
        throwsArgumentError,
      );
      await repository.start(newMatch('new'));
      await expectLater(repository.undoLastRack('new'), throwsStateError);
      await expectLater(repository.undoLastShot('new'), throwsStateError);
    },
  );

  test('removes only a match owned by the account', () async {
    final ownRepository = DriftMatchRepository(db, userId: 'u1');
    final otherRepository = DriftMatchRepository(db, userId: 'u2');
    await ownRepository.start(newMatch('own'));
    await otherRepository.start(newMatch('other'));

    await ownRepository.remove('own');
    expect(
      (await ownRepository.watchAll().first).map((match) => match.id),
      isEmpty,
    );
    expect((await otherRepository.watchAll().first).map((match) => match.id), [
      'other',
    ]);
    await expectLater(ownRepository.remove('other'), throwsStateError);
    await expectLater(ownRepository.remove('missing'), throwsStateError);
  });

  test('remove is a soft delete: hidden, unsynced, updatedAt bumped', () async {
    var now = DateTime(2026, 10, 20, 10);
    final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
    await repository.start(newMatch('m1'));
    await db
        .update(db.poolMatchRows)
        .write(PoolMatchRowsCompanion(syncedAt: Value(now)));
    now = DateTime(2026, 10, 20, 12);

    await repository.remove('m1');

    expect(await repository.watchAll().first, isEmpty);
    final row = (await db.select(db.poolMatchRows).get()).single;
    expect(row.isDeleted, isTrue);
    expect(row.updatedAt, now);
    expect(row.syncedAt, isNull);
    await expectLater(repository.remove('m1'), throwsStateError);
    await expectLater(
      repository.recordRack('m1', RackWinner.player),
      throwsStateError,
    );
    await expectLater(
      repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 3,
        tournamentId: null,
        roundLabel: null,
      ),
      throwsStateError,
    );
  });

  test('updateDetails bumps updatedAt and clears syncedAt', () async {
    var now = DateTime(2026, 10, 20, 10);
    final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
    await repository.start(newMatch('m1'));
    await db
        .update(db.poolMatchRows)
        .write(PoolMatchRowsCompanion(syncedAt: Value(now)));
    now = DateTime(2026, 10, 20, 12);

    await repository.updateDetails(
      matchId: 'm1',
      gameType: PoolGameType.nineBall,
      playerName: 'An',
      opponentName: 'Bình',
      targetRacks: 4,
      tournamentId: null,
      roundLabel: null,
    );

    final row = (await db.select(db.poolMatchRows).get()).single;
    expect(row.updatedAt, now);
    expect(row.syncedAt, isNull);
  });

  test(
    'updates match details without changing recorded racks or shots',
    () async {
      var now = DateTime(2026, 10, 20, 10);
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
      await repository.start(newMatch('m1'));
      await repository.recordRack('m1', RackWinner.player);
      now = DateTime(2026, 10, 20, 11);

      await repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.eightBall,
        playerName: '  An mới ',
        opponentName: ' Bình mới ',
        targetRacks: 3,
        tournamentId: null,
        roundLabel: null,
      );

      final match = (await repository.watchAll().first).single;
      expect(match.gameType, PoolGameType.eightBall);
      expect(match.playerName, 'An mới');
      expect(match.opponentName, 'Bình mới');
      expect(match.targetRacks, 3);
      expect(match.rackWinners, [RackWinner.player]);
      expect(match.isComplete, isFalse);
      expect(match.completedAt, isNull);

      await expectLater(
        DriftMatchRepository(db, userId: 'u2').updateDetails(
          matchId: 'm1',
          gameType: PoolGameType.tenBall,
          playerName: 'Khác',
          opponentName: 'Khác',
          targetRacks: 3,
          tournamentId: null,
          roundLabel: null,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'lowers the target to exactly the leader\'s wins and completes the match',
    () async {
      var now = DateTime(2026, 10, 20, 10);
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
      await repository.start(
        PoolMatch(
          id: 'm1',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: now,
        ),
      );
      await repository.recordRack('m1', RackWinner.player);
      await repository.recordRack('m1', RackWinner.opponent);
      await repository.recordRack('m1', RackWinner.player);
      await repository.recordRack('m1', RackWinner.player);
      // Player đang dẫn 3–1 trong trận chạm 5 ván.
      now = DateTime(2026, 10, 20, 11);

      await repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 3,
        tournamentId: null,
        roundLabel: null,
      );

      final match = (await repository.watchAll().first).single;
      expect(match.targetRacks, 3);
      expect(match.playerScore, 3);
      expect(match.opponentScore, 1);
      expect(match.isComplete, isTrue);
      expect(match.completedAt, now);
    },
  );

  test('raises the target above the winner\'s count on a completed match and reopens it', () async {
    var now = DateTime(2026, 10, 20, 10);
    final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
    await repository.start(
      PoolMatch(
        id: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 3,
        rackWinners: const [],
        startedAt: now,
      ),
    );
    await repository.recordShot(
      'm1',
      MatchShot(
        id: 'shot-1',
        rackNumber: 1,
        shotNumber: 1,
        shooter: RackWinner.player,
        type: MatchShotType.breakShot,
        outcome: MatchShotOutcome.made,
        recordedAt: now,
      ),
    );
    await repository.recordRack('m1', RackWinner.player);
    await repository.recordRack('m1', RackWinner.player);
    await repository.recordRack('m1', RackWinner.player);
    var match = (await repository.watchAll().first).single;
    expect(match.isComplete, isTrue);
    expect(match.completedAt, isNotNull);

    now = DateTime(2026, 10, 20, 12);
    await repository.updateDetails(
      matchId: 'm1',
      gameType: PoolGameType.nineBall,
      playerName: 'An',
      opponentName: 'Bình',
      targetRacks: 5,
      tournamentId: null,
      roundLabel: null,
    );

    match = (await repository.watchAll().first).single;
    expect(match.targetRacks, 5);
    expect(match.isComplete, isFalse);
    expect(match.completedAt, isNull);
    expect(match.playerScore, 3);
    expect(match.shots, hasLength(1));
    expect(match.shots.single.id, 'shot-1');
  });

  test('rejects blank names, a non-positive target, and a target below the '
      'leader\'s wins', () async {
    final repository = DriftMatchRepository(db, userId: 'u1');
    await repository.start(
      PoolMatch(
        id: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 5,
        rackWinners: const [],
        startedAt: DateTime(2026, 10, 20, 10),
      ),
    );
    await repository.recordRack('m1', RackWinner.player);
    await repository.recordRack('m1', RackWinner.player);
    // Player đang dẫn 2–0 trong trận chạm 5 ván.

    await expectLater(
      repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: '  ',
        opponentName: 'Bình',
        targetRacks: 5,
        tournamentId: null,
        roundLabel: null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: ' ',
        targetRacks: 5,
        tournamentId: null,
        roundLabel: null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 0,
        tournamentId: null,
        roundLabel: null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 1,
        tournamentId: null,
        roundLabel: null,
      ),
      throwsArgumentError,
    );

    final match = (await repository.watchAll().first).single;
    expect(match.targetRacks, 5);
    expect(match.playerName, 'An');
    expect(match.opponentName, 'Bình');
    expect(match.playerScore, 2);
  });

  group('cue on a match', () {
    final now = DateTime(2026, 10, 20, 12);

    Future<void> addCue(String id, {String userId = 'u1'}) =>
        DriftCueEquipmentRepository(db, userId: userId, now: () => now).save(
          CueEquipment(
            id: id,
            name: 'Cơ $id',
            type: CueType.playing,
            skillCategories: const [],
          ),
        );

    PoolMatch withCue(String id, String? cueId) => PoolMatch(
      id: id,
      gameType: PoolGameType.nineBall,
      playerName: 'An',
      opponentName: 'Bình',
      targetRacks: 2,
      rackWinners: const [],
      startedAt: DateTime(2026, 10, 20, 10),
      cueId: cueId,
    );

    test('is stored and read back', () async {
      await addCue('c1');
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
      await repository.start(withCue('m1', 'c1'));
      await repository.start(withCue('m2', null));

      final matches = {
        for (final m in await repository.watchAll().first) m.id: m,
      };
      expect(matches['m1']!.cueId, 'c1');
      expect(matches['m2']!.cueId, isNull);
    });

    test('must be an existing cue of this account', () async {
      await addCue('theirs', userId: 'u2');
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);

      await expectLater(
        repository.start(withCue('m1', 'theirs')),
        throwsStateError,
      );
      await expectLater(
        repository.start(withCue('m2', 'nope')),
        throwsStateError,
      );
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    });

    test('is kept when the cue is deleted afterwards', () async {
      await addCue('c1');
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
      await repository.start(withCue('m1', 'c1'));

      await DriftCueEquipmentRepository(
        db,
        userId: 'u1',
        now: () => now,
      ).remove('c1');

      expect((await repository.watchAll().first).single.cueId, 'c1');
    });
  });

  test(
    'every change marks the match as unsynced with a fresh updatedAt',
    () async {
      var now = DateTime(2026, 10, 20, 11);
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => now);
      await repository.start(newMatch('m1'));
      var row = (await db.select(db.poolMatchRows).get()).single;
      expect(row.updatedAt, now);
      expect(row.syncedAt, isNull);
      await (db.update(db.poolMatchRows))
          .write(PoolMatchRowsCompanion(syncedAt: Value(now)));
      now = DateTime(2026, 10, 20, 11, 5);
      await repository.recordRack('m1', RackWinner.player);

      row = (await db.select(db.poolMatchRows).get()).single;
      expect(row.updatedAt, now);
      expect(row.syncedAt, isNull);
    },
  );

  group('giải đấu', () {
    late DriftMatchRepository repo;
    setUp(
      () => repo = DriftMatchRepository(
        db,
        userId: 'u1',
        now: () => DateTime(2026, 10, 20, 11),
      ),
    );

    Future<String> addTournament(String userId, String id) =>
        TournamentRepository(
          db,
          userId: userId,
          now: () => DateTime(2026, 10, 20),
          newId: () => id,
        ).create(
          TournamentDraft(name: 'Giải $id', startDate: DateTime(2026, 10, 20)),
        );

    PoolMatch inTournament(String id, String? tournamentId, {String? round}) =>
        PoolMatch(
          id: id,
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 2,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 20, 10),
          tournamentId: tournamentId,
          roundLabel: round,
        );

    test(
      'bắt đầu trận trong giải: lưu giải và vòng đã cắt khoảng trắng',
      () async {
        await addTournament('u1', 't1');
        await repo.start(inTournament('m1', 't1', round: '  Tứ kết '));
        final m = (await repo.watchAll().first).single;
        expect([m.tournamentId, m.roundLabel], ['t1', 'Tứ kết']);
      },
    );

    test('không có giải thì bỏ vòng; vòng rỗng thành null', () async {
      await repo.start(inTournament('m1', null, round: 'Tứ kết'));
      await addTournament('u1', 't1');
      await repo.start(inTournament('m2', 't1', round: '   '));
      final rows = {
        for (final r in await db.select(db.poolMatchRows).get()) r.id: r,
      };
      expect([rows['m1']!.roundLabel, rows['m2']!.roundLabel], [null, null]);
    });

    test('giải lạ, đã xóa hoặc của người khác: không ghi', () async {
      await addTournament('u2', 'theirs');
      await addTournament('u1', 'gone');
      await TournamentRepository(
        db,
        userId: 'u1',
        now: () => DateTime(2026, 10, 21),
        newId: () => 'x',
      ).remove('gone');
      for (final t in ['nope', 'theirs', 'gone']) {
        await expectLater(
          repo.start(inTournament('m-$t', t)),
          throwsStateError,
        );
      }
      await expectLater(
        repo.start(inTournament('m-long', null, round: 'x' * 41)),
        throwsArgumentError,
      );
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    });

    test('sửa trận: chuyển giải, bỏ giải', () async {
      await addTournament('u1', 't1');
      await addTournament('u1', 't2');
      await repo.start(inTournament('m1', 't1', round: 'Bán kết'));
      Future<void> edit(String? t, String? round) => repo.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 2,
        tournamentId: t,
        roundLabel: round,
      );
      await edit('t2', 'Chung kết');
      var r = await db.select(db.poolMatchRows).getSingle();
      expect([r.tournamentId, r.roundLabel], ['t2', 'Chung kết']);
      await edit(null, 'Chung kết');
      r = await db.select(db.poolMatchRows).getSingle();
      expect([r.tournamentId, r.roundLabel, r.syncedAt], [null, null, null]);
    });

    test('giải của trận đã bị xóa: sửa trận mà giữ nguyên giải thì được, chuyển sang giải đã xóa khác thì không', () async {
      await addTournament('u1', 'gone');
      await addTournament('u1', 'gone2');
      await repo.start(inTournament('m1', 'gone', round: 'Tứ kết'));
      final tours = TournamentRepository(
        db,
        userId: 'u1',
        now: () => DateTime(2026, 10, 21),
        newId: () => 'x',
      );
      await tours.remove('gone');
      await tours.remove('gone2');
      await repo.updateDetails(
        matchId: 'm1',
        gameType: PoolGameType.tenBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 2,
        tournamentId: 'gone',
        roundLabel: 'Tứ kết',
      );
      final r = await db.select(db.poolMatchRows).getSingle();
      expect(
        [r.gameType, r.tournamentId, r.roundLabel],
        ['tenBall', 'gone', 'Tứ kết'],
      );
      await expectLater(
        repo.updateDetails(
          matchId: 'm1',
          gameType: PoolGameType.tenBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 2,
          tournamentId: 'gone2',
          roundLabel: null,
        ),
        throwsStateError,
      );
    });
  });
}
