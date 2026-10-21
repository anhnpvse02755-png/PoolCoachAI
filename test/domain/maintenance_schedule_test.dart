import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/maintenance_schedule.dart';

CueEquipment _cue(String id, DateTime? due) => CueEquipment(
  id: id,
  name: 'Cơ $id',
  type: CueType.playing,
  skillCategories: const [],
  tipMaintenanceDueDate: due,
);

void main() {
  test('schedules 09:00 seven days before and on the due date', () {
    final plan = computeMaintenanceSchedule([
      _cue('a', DateTime(2026, 10, 20)),
    ], now: DateTime(2026, 10, 1, 12));
    expect(plan.map((r) => r.at), [
      DateTime(2026, 10, 13, 9),
      DateTime(2026, 10, 20, 9),
    ]);
    expect(plan.map((r) => r.daysBefore), [7, 0]);
    expect(plan.first.cueName, 'Cơ a');
  });

  test('drops reminders whose time has already passed', () {
    final plan = computeMaintenanceSchedule([
      _cue('a', DateTime(2026, 10, 20)),
    ], now: DateTime(2026, 10, 14));
    expect(plan.map((r) => r.daysBefore), [0]);
  });

  test('ignores cues without a date and ignores the time of day', () {
    final plan = computeMaintenanceSchedule([
      _cue('a', null),
      _cue('b', DateTime(2026, 11, 3, 23, 30)),
    ], now: DateTime(2026, 10, 1));
    expect(plan.map((r) => r.cueId).toSet(), {'b'});
    expect(plan.first.at, DateTime(2026, 10, 27, 9));
  });

  test('ids are unique and ordered by time', () {
    final plan = computeMaintenanceSchedule([
      _cue('a', DateTime(2026, 12, 20)),
      _cue('b', DateTime(2026, 11, 20)),
    ], now: DateTime(2026, 10, 1));
    expect(plan.map((r) => r.id).toSet(), hasLength(4));
    final times = plan.map((r) => r.at).toList();
    expect([...times]..sort(), times);
  });
}
