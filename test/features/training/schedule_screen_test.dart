import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/training/presentation/schedule_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

void main() {
  /// Mở màn Lịch tập trên một cơ sở dữ liệu trong bộ nhớ.
  Future<AppDatabase> openSchedule(WidgetTester tester) async {
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
    return db;
  }

  testWidgets('bộ chọn nhóm có đủ ba nhóm nâng cao', (tester) async {
    await openSchedule(tester);
    await tester.tap(find.text(Vi.scheduleAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<SkillCategory?>));
    await tester.pumpAndSettle();
    for (final c in [
      SkillCategory.dungCo,
      SkillCategory.nhayBi,
      SkillCategory.matXe,
    ]) {
      expect(find.text(Vi.skill(c)), findsWidgets, reason: '$c');
    }
  });

  testWidgets('weekly schedule can be created, edited and removed', (
    tester,
  ) async {
    final db = await openSchedule(tester);

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
    expect(slots.single.isDeleted, isTrue);
    expect(find.text(Vi.scheduleEmpty), findsOneWidget);
  });

  testWidgets('điện thoại ngang, bàn phím mở: hộp thoại lịch tập cuộn được, '
      'nút Lưu trên bàn phím', (tester) async {
    applyScreen(tester, const Size(740, 360));
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await openSchedule(tester);
    await tester.tap(find.text(Vi.scheduleAdd));
    await tester.pumpAndSettle();
    await expectDialogFitsAboveKeyboard(
      tester,
      screenHeight: 360,
      keyboard: 160,
    );
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('điện thoại ngang: bảng chọn giờ không tràn', (tester) async {
    applyScreen(tester, const Size(740, 360));
    await openSchedule(tester);
    await tester.tap(find.text(Vi.scheduleAdd));
    await tester.pumpAndSettle();
    final timeButton = find.descendant(
      of: find.widgetWithText(ListTile, Vi.scheduleChooseTime),
      matching: find.byType(TextButton),
    );
    await tester.ensureVisible(timeButton);
    await tester.pumpAndSettle();
    await tester.tap(timeButton);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
