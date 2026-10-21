import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/training/presentation/timer_screen.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('timer saves an elapsed free-practice session', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftCueEquipmentRepository(db, userId: 'u1').save(
      const CueEquipment(
        id: 'play-cue',
        name: 'Cơ thi đấu',
        type: CueType.playing,
        skillCategories: [SkillCategory.aiming],
      ),
    );
    var now = testToday;
    final container = dbContainer(db, clock: () => now);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<SkillCategory?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.skill(SkillCategory.aiming)).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cơ thi đấu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.timerStart));
    await tester.pump();
    now = now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(Vi.timerFinish));
    await tester.pumpAndSettle();

    final sessions = await db.select(db.timerSessionRows).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.durationSec, 12);
    expect(sessions.single.userId, 'u1');
    expect(find.text(Vi.timerSaved), findsOneWidget);
    expect(find.textContaining('00:00:12'), findsOneWidget);
    expect(sessions.single.cat, SkillCategory.aiming.name);
    expect(sessions.single.cueId, 'play-cue');
  });

  testWidgets('countdown automatically saves when the target is reached', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    var now = testToday;
    final container = dbContainer(db, clock: () => now);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.timerCountDown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.timerStart));
    await tester.pump();
    now = now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final sessions = await db.select(db.timerSessionRows).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.durationSec, 15 * 60);
    expect(find.text(Vi.timerSaved), findsOneWidget);
  });
}
