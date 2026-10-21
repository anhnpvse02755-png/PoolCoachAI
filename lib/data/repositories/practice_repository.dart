import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/timer_session.dart';

abstract interface class TimerSessionRepository {
  Stream<List<TimerSession>> watchAll();
  Future<void> add(TimerSession session);
}

abstract interface class ScheduleRepository {
  Stream<List<ScheduleSlot>> watchAll();
  Future<void> save(ScheduleSlot slot);
  Future<void> remove(String id);
}

abstract interface class CueEquipmentRepository {
  Stream<List<CueEquipment>> watchAll();
  Future<void> save(CueEquipment cue);
  Future<void> remove(String id);
}

class SignedOutCueEquipmentRepository implements CueEquipmentRepository {
  const SignedOutCueEquipmentRepository();

  @override
  Stream<List<CueEquipment>> watchAll() => Stream.value(const []);

  @override
  Future<void> save(CueEquipment cue) =>
      Future.error(StateError('Chưa đăng nhập thì không lưu hồ sơ cơ được'));

  @override
  Future<void> remove(String id) =>
      Future.error(StateError('Chưa đăng nhập thì không xóa hồ sơ cơ được'));
}

class SignedOutTimerSessionRepository implements TimerSessionRepository {
  const SignedOutTimerSessionRepository();

  @override
  Stream<List<TimerSession>> watchAll() => Stream.value(const []);

  @override
  Future<void> add(TimerSession session) =>
      Future.error(StateError('Chưa đăng nhập thì không ghi buổi tập được'));
}

class SignedOutScheduleRepository implements ScheduleRepository {
  const SignedOutScheduleRepository();

  @override
  Stream<List<ScheduleSlot>> watchAll() => Stream.value(const []);

  @override
  Future<void> save(ScheduleSlot slot) =>
      Future.error(StateError('Chưa đăng nhập thì không lưu lịch tập được'));

  @override
  Future<void> remove(String id) =>
      Future.error(StateError('Chưa đăng nhập thì không xóa lịch tập được'));
}
