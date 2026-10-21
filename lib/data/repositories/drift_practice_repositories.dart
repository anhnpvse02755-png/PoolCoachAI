import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/practice_repository.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/timer_session.dart';

class DriftTimerSessionRepository implements TimerSessionRepository {
  DriftTimerSessionRepository(this._db, {required this._userId});

  final AppDatabase _db;
  final String _userId;

  @override
  Stream<List<TimerSession>> watchAll() =>
      (_db.select(_db.timerSessionRows)
            ..where((row) => row.userId.equals(_userId))
            ..orderBy([(row) => OrderingTerm.desc(row.date)]))
          .watch()
          .map((rows) => rows.map(toTimerSession).toList());

  @override
  Future<void> add(TimerSession session) async {
    if (session.durationSec <= 0) {
      throw ArgumentError.value(
        session.durationSec,
        'durationSec',
        'Thời lượng phải lớn hơn 0',
      );
    }
    if (session.cueId != null) {
      final cue =
          await (_db.select(_db.cueEquipmentRows)..where(
                (row) =>
                    row.id.equals(session.cueId!) &
                    row.userId.equals(_userId) &
                    row.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (cue == null) {
        throw StateError('Cơ không tồn tại hoặc không thuộc tài khoản này');
      }
    }
    await _db
        .into(_db.timerSessionRows)
        .insert(toTimerSessionRow(session).copyWith(userId: Value(_userId)));
  }
}

class DriftCueEquipmentRepository implements CueEquipmentRepository {
  DriftCueEquipmentRepository(
    this._db, {
    required this._userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;

  @override
  Stream<List<CueEquipment>> watchAll() =>
      (_db.select(_db.cueEquipmentRows)
            ..where((row) => row.userId.equals(_userId) & row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch()
          .map((rows) => rows.map(toCueEquipment).toList());

  @override
  Future<void> save(CueEquipment cue) async {
    if (cue.id.trim().isEmpty || cue.name.trim().isEmpty) {
      throw ArgumentError('Cơ phải có mã và tên');
    }
    if (cue.weightGrams != null && cue.weightGrams! <= 0) {
      throw ArgumentError.value(cue.weightGrams, 'weightGrams');
    }
    if (cue.shaftDiameterMm != null &&
        (!cue.shaftDiameterMm!.isFinite || cue.shaftDiameterMm! <= 0)) {
      throw ArgumentError.value(cue.shaftDiameterMm, 'shaftDiameterMm');
    }
    final lastMaintenance = cue.lastTipMaintenance;
    final dueDate = cue.tipMaintenanceDueDate;
    if (!isMaintenanceDueDateValid(
      lastMaintenance: lastMaintenance,
      dueDate: dueDate,
    )) {
      throw ArgumentError.value(
        dueDate,
        'tipMaintenanceDueDate',
        'Ngày bảo dưỡng tiếp theo phải sau lần bảo dưỡng gần nhất',
      );
    }

    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.cueEquipmentRows,
      )..where((row) => row.id.equals(cue.id))).getSingleOrNull();
      if (existing != null && existing.userId != _userId) {
        throw StateError('Cơ không thuộc tài khoản này');
      }
      await _db.into(_db.cueEquipmentRows).insertOnConflictUpdate(
        toCueEquipmentRow(cue, userId: _userId).copyWith(
          updatedAt: Value(_now()),
          syncedAt: const Value(null),
          isDeleted: const Value(false),
        ),
      );
    });
  }

  @override
  Future<void> remove(String id) async {
    await _db.transaction(() async {
      final cue = await (_db.select(
        _db.cueEquipmentRows,
      )..where((row) => row.id.equals(id) & row.userId.equals(_userId)))
          .getSingleOrNull();
      if (cue == null || cue.isDeleted) return;
      await (_db.update(_db.timerSessionRows)
            ..where((row) => row.userId.equals(_userId) & row.cueId.equals(id)))
          .write(const TimerSessionRowsCompanion(cueId: Value(null)));
      await (_db.update(_db.cueEquipmentRows)
            ..where((row) => row.userId.equals(_userId) & row.id.equals(id)))
          .write(
            CueEquipmentRowsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(_now()),
              syncedAt: const Value(null),
            ),
          );
    });
  }
}

class DriftScheduleRepository implements ScheduleRepository {
  DriftScheduleRepository(this._db, {required this._userId});

  final AppDatabase _db;
  final String _userId;

  @override
  Stream<List<ScheduleSlot>> watchAll() =>
      (_db.select(_db.scheduleSlotRows)
            ..where((row) => row.userId.equals(_userId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.day),
              (row) => OrderingTerm.asc(row.time),
            ]))
          .watch()
          .map((rows) => rows.map(toScheduleSlot).toList());

  @override
  Future<void> save(ScheduleSlot slot) async {
    if (slot.id.trim().isEmpty || slot.label.trim().isEmpty) {
      throw ArgumentError('Lịch tập phải có mã và tên');
    }
    if (slot.day < 0 || slot.day > 6) {
      throw ArgumentError.value(slot.day, 'day', 'Ngày phải trong khoảng 0..6');
    }
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(slot.time)) {
      throw ArgumentError.value(
        slot.time,
        'time',
        'Giờ phải có định dạng HH:MM',
      );
    }
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.scheduleSlotRows,
      )..where((row) => row.id.equals(slot.id))).getSingleOrNull();
      if (existing != null && existing.userId != _userId) {
        throw StateError('Lịch tập không thuộc tài khoản này');
      }
      await _db
          .into(_db.scheduleSlotRows)
          .insertOnConflictUpdate(
            toScheduleSlotRow(slot).copyWith(userId: Value(_userId)),
          );
    });
  }

  @override
  Future<void> remove(String id) => (_db.delete(
    _db.scheduleSlotRows,
  )..where((row) => row.userId.equals(_userId) & row.id.equals(id))).go();
}
