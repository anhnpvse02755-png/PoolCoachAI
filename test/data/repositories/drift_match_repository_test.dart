import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/domain/pool_match.dart';

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
}
