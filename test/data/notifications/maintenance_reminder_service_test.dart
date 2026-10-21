import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/maintenance_notification_platform.dart';
import 'package:poolcoachai/data/notifications/maintenance_reminder_service.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';

import '../../support/fake_auth.dart';

void main() {
  late AppDatabase db;
  late FakeAuthRepository auth;
  late _FakeNotificationPlatform platform;
  late DateTime now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    platform = _FakeNotificationPlatform();
    now = DateTime(2026, 10, 13, 8, 59);
  });

  tearDown(() => db.close());

  MaintenanceReminderService service() => MaintenanceReminderService(
    db: db,
    auth: auth,
    now: () => now,
    platform: platform,
  );

  Future<void> saveCue({String id = 'cue-1', DateTime? dueDate}) =>
      DriftCueEquipmentRepository(db, userId: 'u1', now: () => now).save(
        CueEquipment(
          id: id,
          name: 'Cơ test',
          type: CueType.playing,
          skillCategories: const [],
          tipMaintenanceDueDate: dueDate,
        ),
      );

  test('sends once at 09:00 seven days before and on the due date', () async {
    await saveCue(dueDate: DateTime(2026, 10, 20));
    platform.permissionValue = 'granted';
    final reminders = service()..start();
    addTearDown(reminders.dispose);
    await pumpEventQueue();

    expect(platform.notifications, isEmpty);
    now = DateTime(2026, 10, 13, 9);
    reminders.checkNow();
    reminders.checkNow();
    expect(platform.notifications, hasLength(1));
    expect(platform.notifications.single.body, contains('sau 7 ngày'));

    now = DateTime(2026, 10, 20, 9);
    reminders.checkNow();
    expect(platform.notifications, hasLength(2));
    expect(platform.notifications.last.body, contains('hôm nay'));
  });

  test(
    'asks permission only on request and notifies after it is granted',
    () async {
      await saveCue(dueDate: DateTime(2026, 10, 13));
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      now = DateTime(2026, 10, 13, 9);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      expect(await reminders.requestPermission(), 'granted');
      expect(platform.permissionRequests, 1);
      expect(platform.notifications, hasLength(1));
    },
  );

  test('does not notify for a deleted cue or after sign-out', () async {
    await saveCue(dueDate: DateTime(2026, 10, 20));
    platform.permissionValue = 'granted';
    final reminders = service()..start();
    addTearDown(reminders.dispose);
    await pumpEventQueue();
    await DriftCueEquipmentRepository(db, userId: 'u1').remove('cue-1');
    await pumpEventQueue();

    now = DateTime(2026, 10, 20, 9);
    reminders.checkNow();
    expect(platform.notifications, isEmpty);

    auth.emit(const SignedOut());
    await pumpEventQueue();
    await saveCue(id: 'cue-2', dueDate: DateTime(2026, 10, 20));
    await pumpEventQueue();
    reminders.checkNow();
    expect(platform.notifications, isEmpty);
  });
}

class _FakeNotificationPlatform extends MaintenanceNotificationPlatform {
  String permissionValue = 'default';
  int permissionRequests = 0;
  final notifications = <({String title, String body, String tag})>[];
  final storedValues = <String, String>{};

  @override
  bool get isSupported => true;

  @override
  String? get permission => permissionValue;

  @override
  Future<String?> requestPermission() async {
    permissionRequests++;
    permissionValue = 'granted';
    return permissionValue;
  }

  @override
  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    notifications.add((title: title, body: body, tag: tag));
  }

  @override
  String? readValue(String key) => storedValues[key];

  @override
  void writeValue(String key, String value) {
    storedValues[key] = value;
  }
}
