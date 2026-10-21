import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('creates, edits and deletes cue equipment', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thi đấu');
    await tester.enterText(find.byKey(const Key('cue-weight')), '540');
    await tester.enterText(find.byKey(const Key('cue-shaft-diameter')), '12.5');
    await tester.enterText(find.byKey(const Key('cue-shaft-brand')), 'Predator');
    await tester.enterText(find.byKey(const Key('cue-tip-brand')), 'Kamui');
    await tester.enterText(find.byKey(const Key('cue-butt-brand')), 'Cuetec');
    await tester.ensureVisible(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.tap(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();

    var cues = await db.select(db.cueEquipmentRows).get();
    expect(cues, hasLength(1));
    expect(cues.single.userId, 'u1');
    expect(cues.single.weightGrams, 540);
    expect(cues.single.shaftDiameterMm, 12.5);
    expect(cues.single.shaftBrand, 'Predator');
    expect(cues.single.tipBrand, 'Kamui');
    expect(cues.single.buttBrand, 'Cuetec');
    expect(cues.single.skillCategories, '["aiming"]');
    expect(find.text('Cơ thi đấu'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thi đấu mới');
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.cueEquipmentRows).get()).single.name,
      'Cơ thi đấu mới',
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.equipmentDelete).last);
    await tester.pumpAndSettle();
    cues = await db.select(db.cueEquipmentRows).get();
    expect(cues, hasLength(1));
    expect(cues.single.isDeleted, isTrue);
    expect(find.text(Vi.equipmentEmpty), findsOneWidget);
  });

  testWidgets('shows maintenance warning based on user-set due date', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftCueEquipmentRepository(db, userId: 'u1').save(
      CueEquipment(
        id: 'due-cue',
        name: 'Cơ cần bảo dưỡng',
        type: CueType.playing,
        skillCategories: const [],
        lastTipMaintenance: DateTime(2026, 8, 1),
        tipMaintenanceDueDate: DateTime(2026, 9, 21),
      ),
    );
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(Vi.equipmentDue), findsOneWidget);
    expect(find.textContaining('21/09/2026'), findsOneWidget);
  });

  testWidgets('prioritizes overdue cues and sorts upcoming maintenance', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = DriftCueEquipmentRepository(db, userId: 'u1');
    final cues = [
      CueEquipment(
        id: 'overdue',
        name: 'Z - quá hạn',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 21),
      ),
      CueEquipment(
        id: 'today',
        name: 'Y - đến hạn hôm nay',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 22, 23),
      ),
      CueEquipment(
        id: 'seven-days',
        name: 'X - đến hạn sau 7 ngày',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 29),
      ),
      CueEquipment(
        id: 'eight-days',
        name: 'A - đến hạn sau 8 ngày',
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: DateTime(2026, 9, 30),
      ),
      const CueEquipment(
        id: 'no-date',
        name: 'B - chưa đặt ngày',
        type: CueType.playing,
        skillCategories: [],
      ),
    ];
    for (final cue in cues) {
      await repository.save(cue);
    }
    final container = dbContainer(db, now: testToday);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final orderedNames = [
      'Z - quá hạn',
      'Y - đến hạn hôm nay',
      'X - đến hạn sau 7 ngày',
      'A - đến hạn sau 8 ngày',
      'B - chưa đặt ngày',
    ];
    final positions = orderedNames
        .map((name) => tester.getTopLeft(find.text(name)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('shows accumulated timer practice for each cue', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final equipmentRepository = DriftCueEquipmentRepository(db, userId: 'u1');
    await equipmentRepository.save(
      const CueEquipment(
        id: 'practice-cue',
        name: 'Cơ tập luyện',
        type: CueType.playing,
        skillCategories: [],
      ),
    );
    final timerRepository = DriftTimerSessionRepository(db, userId: 'u1');
    await timerRepository.add(
      TimerSession(
        id: 'practice-one',
        date: DateTime(2026, 9, 20, 10),
        durationSec: 3600,
        cueId: 'practice-cue',
      ),
    );
    await timerRepository.add(
      TimerSession(
        id: 'practice-two',
        date: DateTime(2026, 9, 21, 10),
        durationSec: 1800,
        cueId: 'practice-cue',
      ),
    );
    await timerRepository.add(
      TimerSession(
        id: 'unlinked',
        date: DateTime(2026, 9, 22, 10),
        durationSec: 7200,
      ),
    );
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('${Vi.equipmentPracticeTime}: 1 giờ 30 phút'),
      findsOneWidget,
    );
    expect(find.text('${Vi.equipmentLastUsed}: 21/09/2026'), findsOneWidget);
  });

  testWidgets('rejects non-finite tip diameter values', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = dbContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EquipmentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.equipmentAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ thử nghiệm');
    await tester.enterText(find.byKey(const Key('cue-shaft-diameter')), 'NaN');
    await tester.tap(find.text(Vi.equipmentSave));
    await tester.pumpAndSettle();

    expect(find.text(Vi.equipmentShaftDiameterInvalid), findsOneWidget);
    expect(await db.select(db.cueEquipmentRows).get(), isEmpty);
  });
}
