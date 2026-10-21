import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('timer sessions persist by user and reject zero duration', () async {
    final repository = DriftTimerSessionRepository(db, userId: 'u1');
    await repository.add(
      TimerSession(
        id: 'own',
        date: DateTime(2026, 9, 22, 10),
        durationSec: 600,
        cat: SkillCategory.aiming,
      ),
    );
    await db
        .into(db.timerSessionRows)
        .insert(
          TimerSessionRowsCompanion.insert(
            id: 'other',
            userId: const Value('u2'),
            date: DateTime(2026, 9, 22, 11),
            durationSec: 900,
          ),
        );

    final sessions = await repository.watchAll().first;
    expect(sessions.map((session) => session.id), ['own']);
    expect(sessions.single.cat, SkillCategory.aiming);
    await expectLater(
      repository.add(
        TimerSession(id: 'empty', date: DateTime(2026, 9, 22), durationSec: 0),
      ),
      throwsArgumentError,
    );
  });

  test(
    'weekly schedules are sorted and changes stay within the account',
    () async {
      final repository = DriftScheduleRepository(db, userId: 'u1');
      await repository.save(
        const ScheduleSlot(
          id: 'late',
          day: 0,
          time: '19:30',
          label: 'Buổi tối',
        ),
      );
      await repository.save(
        const ScheduleSlot(
          id: 'early',
          day: 0,
          time: '08:00',
          label: 'Buổi sáng',
        ),
      );
      await db
          .into(db.scheduleSlotRows)
          .insert(
            ScheduleSlotRowsCompanion.insert(
              id: 'other',
              userId: const Value('u2'),
              day: 1,
              time: '09:00',
              label: 'Tài khoản khác',
            ),
          );
      await expectLater(
        repository.save(
          const ScheduleSlot(
            id: 'other',
            day: 1,
            time: '10:00',
            label: 'Thử ghi đè',
          ),
        ),
        throwsStateError,
      );

      expect((await repository.watchAll().first).map((slot) => slot.id), [
        'early',
        'late',
      ]);
      await repository.save(
        const ScheduleSlot(
          id: 'early',
          day: 0,
          time: '08:00',
          label: 'Lịch sáng đã sửa',
        ),
      );
      expect(
        (await repository.watchAll().first)
            .singleWhere((slot) => slot.id == 'early')
            .label,
        'Lịch sáng đã sửa',
      );
      expect(
        (await db.select(db.scheduleSlotRows).get())
            .singleWhere((slot) => slot.id == 'other')
            .label,
        'Tài khoản khác',
      );
      await repository.remove('late');
      expect((await repository.watchAll().first).map((slot) => slot.id), [
        'early',
      ]);
      expect((await db.select(db.scheduleSlotRows).get()).length, 2);

      for (final invalidSlot in [
        const ScheduleSlot(
          id: 'invalid-time',
          day: 1,
          time: '24:00',
          label: 'Sai giờ',
        ),
      ]) {
        await expectLater(repository.save(invalidSlot), throwsArgumentError);
      }
    },
  );

  test(
    'equipment is account-scoped and deleting a cue unlinks its sessions',
    () async {
      final repository = DriftCueEquipmentRepository(db, userId: 'u1');
      final cue = CueEquipment(
        id: 'cue-u1',
        name: 'Cơ thi đấu',
        type: CueType.playing,
        weightGrams: 540,
        tipDiameterMm: 12.5,
        tipHardness: TipHardness.medium,
        skillCategories: const [SkillCategory.aiming],
        lastTipMaintenance: DateTime(2026, 9, 1),
        tipMaintenanceDueDate: DateTime(2026, 12, 1),
      );
      await repository.save(cue);
      await db
          .into(db.cueEquipmentRows)
          .insert(
            CueEquipmentRowsCompanion.insert(
              id: 'cue-u2',
              userId: 'u2',
              name: 'Cơ riêng',
              type: CueType.breakCue.name,
              skillCategories: '[]',
            ),
          );
      await expectLater(
        repository.save(
          const CueEquipment(
            id: 'cue-u2',
            name: 'Ghi đè',
            type: CueType.jump,
            skillCategories: [],
          ),
        ),
        throwsStateError,
      );
      expect(
        (await db.select(db.cueEquipmentRows).get())
            .singleWhere((row) => row.id == 'cue-u2')
            .name,
        'Cơ riêng',
      );
      final timerRepository = DriftTimerSessionRepository(db, userId: 'u1');
      await timerRepository.add(
        TimerSession(
          id: 'session',
          date: DateTime(2026, 9, 22),
          durationSec: 300,
          cueId: cue.id,
        ),
      );

      final ownCues = await repository.watchAll().first;
      expect(ownCues, hasLength(1));
      expect(ownCues.single.id, cue.id);
      expect(ownCues.single.name, cue.name);
      expect(ownCues.single.type, CueType.playing);
      expect(ownCues.single.weightGrams, 540);
      expect(ownCues.single.tipDiameterMm, 12.5);
      expect(ownCues.single.tipHardness, TipHardness.medium);
      expect(ownCues.single.skillCategories, [SkillCategory.aiming]);
      expect(ownCues.single.lastTipMaintenance, DateTime(2026, 9, 1));
      expect(ownCues.single.tipMaintenanceDueDate, DateTime(2026, 12, 1));
      await expectLater(
        DriftTimerSessionRepository(db, userId: 'u1').add(
          TimerSession(
            id: 'invalid-cue',
            date: DateTime(2026, 9, 22),
            durationSec: 300,
            cueId: 'cue-u2',
          ),
        ),
        throwsStateError,
      );

      await repository.remove(cue.id);
      expect(await repository.watchAll().first, isEmpty);
      final storedCues = await db.select(db.cueEquipmentRows).get();
      expect(storedCues, hasLength(2));
      expect(
        storedCues.singleWhere((row) => row.id == cue.id).isDeleted,
        isTrue,
      );
      expect(storedCues.singleWhere((row) => row.id == 'cue-u2').userId, 'u2');
      expect((await db.select(db.timerSessionRows).get()).single.cueId, isNull);
    },
  );

  test(
    'equipment rejects non-finite dimensions and invalid maintenance dates',
    () async {
      final repository = DriftCueEquipmentRepository(db, userId: 'u1');
      for (final diameter in [double.nan, double.infinity]) {
        await expectLater(
          repository.save(
            CueEquipment(
              id: 'invalid-diameter',
              name: 'Cơ không hợp lệ',
              type: CueType.playing,
              tipDiameterMm: diameter,
              skillCategories: const [],
            ),
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        repository.save(
          CueEquipment(
            id: 'invalid-dates',
            name: 'Cơ sai ngày',
            type: CueType.playing,
            skillCategories: const [],
            lastTipMaintenance: DateTime(2026, 10, 20),
            tipMaintenanceDueDate: DateTime(2026, 10, 19),
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.save(
          CueEquipment(
            id: 'same-maintenance-date',
            name: 'Cơ cùng ngày bảo dưỡng',
            type: CueType.playing,
            skillCategories: const [],
            lastTipMaintenance: DateTime(2026, 10, 20, 8),
            tipMaintenanceDueDate: DateTime(2026, 10, 20, 18),
          ),
        ),
        throwsArgumentError,
      );
      expect(await repository.watchAll().first, isEmpty);
    },
  );
}
