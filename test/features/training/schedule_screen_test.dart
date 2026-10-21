import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/features/training/presentation/schedule_screen.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('weekly schedule can be created, edited and removed', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.scheduleAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Tập ngắm bi');
    await tester.tap(find.text(Vi.scheduleSave));
    await tester.pumpAndSettle();

    var slots = await db.select(db.scheduleSlotRows).get();
    expect(slots, hasLength(1));
    final existingId = slots.single.id;
    expect(slots.single.userId, 'u1');
    expect(slots.single.day, 0);
    expect(slots.single.time, '19:00');
    expect(find.text('Tập ngắm bi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Tập điều bi');
    await tester.tap(find.text(Vi.scheduleSave));
    await tester.pumpAndSettle();

    slots = await db.select(db.scheduleSlotRows).get();
    expect(slots, hasLength(1));
    expect(slots.single.id, existingId);
    expect(slots.single.label, 'Tập điều bi');
    expect(find.text('Tập điều bi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.scheduleDelete));
    await tester.pumpAndSettle();

    slots = await db.select(db.scheduleSlotRows).get();
    expect(slots, isEmpty);
    expect(find.text(Vi.scheduleEmpty), findsOneWidget);
  });
}
