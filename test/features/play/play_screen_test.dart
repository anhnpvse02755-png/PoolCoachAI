import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('starts a race, records racks and can correct the last rack', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchStart));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
    await tester.enterText(
      find.byKey(const Key('match-opponent-name')),
      'Bình',
    );
    await tester.tap(find.text(Vi.matchStartAction));
    await tester.pumpAndSettle();

    var matches = await db.select(db.poolMatchRows).get();
    expect(matches, hasLength(1));
    expect(matches.single.userId, 'u1');
    expect(matches.single.gameType, PoolGameType.nineBall.name);
    expect(find.text(Vi.matchScore('An', 0, 0, 'Bình')), findsOneWidget);

    await tester.tap(find.text(Vi.matchRecordShot));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-shot-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchSafetyShot).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-shot-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchShotScratch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-position-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.matchPositionUnsuccessful).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('match-shot-notes')),
      'Bi cái rơi lỗ',
    );
    await tester.tap(find.text(Vi.matchSaveShot));
    await tester.pumpAndSettle();
    matches = await db.select(db.poolMatchRows).get();
    expect(matches.single.shots, contains('safety'));
    expect(matches.single.shots, contains('scratch'));
    expect(matches.single.shots, contains('unsuccessful'));
    expect(matches.single.shots, contains('Bi cái rơi lỗ'));
    expect(matches.single.shots, contains('rackNumber'));
    expect(find.text(Vi.matchShotCount(1)), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text(Vi.matchPlayerWinsRack));
      await tester.pumpAndSettle();
    }
    expect(find.text(Vi.matchScore('An', 5, 0, 'Bình')), findsOneWidget);
    expect(find.text(Vi.matchCompleted), findsOneWidget);

    await tester.tap(find.text(Vi.matchUndoRack));
    await tester.pumpAndSettle();
    expect(find.text(Vi.matchScore('An', 4, 0, 'Bình')), findsOneWidget);
    expect(find.text(Vi.matchInProgress), findsOneWidget);
    matches = await db.select(db.poolMatchRows).get();
    expect(matches.single.completedAt, isNull);
    expect(matches.single.shots, contains('safety'));
  });

  testWidgets('shows an empty state when there is no match history', (
    tester,
  ) async {
    final container = testContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Vi.matchEmpty), findsOneWidget);
    expect(find.text(Vi.matchStart), findsOneWidget);
  });

  group('cue picker', () {
    late AppDatabase db;
    late ProviderContainer container;
    final at = DateTime(2026, 10, 20, 9);

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = dbContainer(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> addCue(String id, String name) =>
        DriftCueEquipmentRepository(db, userId: 'u1', now: () => at).save(
          CueEquipment(
            id: id,
            name: name,
            type: CueType.playing,
            skillCategories: const [],
          ),
        );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> startWithNames(WidgetTester tester) async {
      await tester.tap(find.text(Vi.matchStart));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
      await tester.enterText(
        find.byKey(const Key('match-opponent-name')),
        'Bình',
      );
    }

    testWidgets('defaults to no cue and lets the player pick one', (
      tester,
    ) async {
      await addCue('c1', 'Cơ Một');
      await addCue('c2', 'Cơ Hai');
      await pump(tester);
      await startWithNames(tester);

      expect(find.text(Vi.timerNoCue), findsOneWidget);
      await tester.tap(find.byKey(const Key('match-cue')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cơ Một'), findsOneWidget);
      await tester.tap(find.textContaining('Cơ Hai').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();

      expect((await db.select(db.poolMatchRows).get()).single.cueId, 'c2');
    });

    testWidgets('defaults to the cue of the most recent match', (tester) async {
      await addCue('c1', 'Cơ Một');
      await addCue('c2', 'Cơ Hai');
      final repository = DriftMatchRepository(db, userId: 'u1', now: () => at);
      await repository.start(
        PoolMatch(
          id: 'old',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 1),
          cueId: 'c1',
        ),
      );
      await repository.start(
        PoolMatch(
          id: 'recent',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 10),
          cueId: 'c2',
        ),
      );
      await pump(tester);
      await startWithNames(tester);

      expect(find.textContaining('Cơ Hai'), findsWidgets);
      await tester.tap(find.text(Vi.matchStartAction));
      await tester.pumpAndSettle();

      final created = (await db.select(db.poolMatchRows).get()).where(
        (row) => row.id != 'old' && row.id != 'recent',
      );
      expect(created.single.cueId, 'c2');
    });

    testWidgets('a deleted cue shows as unknown on the match card', (
      tester,
    ) async {
      await addCue('c1', 'Cơ Một');
      await DriftMatchRepository(db, userId: 'u1', now: () => at).start(
        PoolMatch(
          id: 'm1',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 5,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 10),
          cueId: 'c1',
        ),
      );
      await pump(tester);
      expect(find.text(Vi.matchCueLine('Cơ Một')), findsOneWidget);

      await DriftCueEquipmentRepository(db, userId: 'u1', now: () => at)
          .remove('c1');
      await tester.pumpAndSettle();

      expect(
        find.text(Vi.matchCueLine(Vi.equipmentUnknownCue)),
        findsOneWidget,
      );
      expect((await db.select(db.poolMatchRows).get()).single.cueId, 'c1');
    });
  });
}
