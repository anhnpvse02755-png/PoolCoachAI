import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
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
}
