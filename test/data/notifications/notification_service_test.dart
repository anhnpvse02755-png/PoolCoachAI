import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/timer_session.dart';

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
    // Thứ Ba.
    now = DateTime(2026, 10, 13, 8, 59);
  });

  tearDown(() => db.close());

  NotificationService service({
    NotificationPrefs? prefs = const NotificationPrefs(),
    NotificationPlatform? using,
  }) => NotificationService(
    db: db,
    auth: auth,
    now: () => now,
    platform: using ?? platform,
  )..setPrefs(prefs);

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

  Future<void> saveSlot({
    String id = 's1',
    int day = 1,
    String time = '18:00',
    String label = 'Tập ngắm',
  }) => DriftScheduleRepository(db, userId: 'u1', now: () => now).save(
    ScheduleSlot(id: id, day: day, time: time, label: label),
  );

  Future<void> practice(DateTime at) =>
      DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(id: 't$at', date: at, durationSec: 600),
      );

  group('browser (timer)', () {
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
      // Khoá localStorage của bảo dưỡng giữ nguyên dạng cũ.
      expect(
        platform.storedValues.keys.single,
        'poolcoachai:maintenance:v1:u1:cue-1:2026-10-20:7',
      );

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

    test('schedule reminder: once, 30 minutes before the slot', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 17, 29);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      now = DateTime(2026, 10, 13, 17, 30);
      reminders.checkNow();
      reminders.checkNow();
      expect(platform.notifications, hasLength(1));
      expect(platform.notifications.single.body, contains('Tập ngắm'));
      expect(platform.notifications.single.body, contains('18:00'));
    });

    test('schedule reminder is not sent late, after the slot started', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 18, 5);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);
    });

    test('streak reminder at 20:00 only while today is unpracticed', () async {
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 19, 59);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      now = DateTime(2026, 10, 13, 20);
      reminders.checkNow();
      expect(platform.notifications, hasLength(1));
      expect(platform.notifications.single.body, contains('2 ngày'));
    });

    test('no streak reminder once today has a practice session', () async {
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      await practice(DateTime(2026, 10, 13, 12));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 20, 30);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);
    });

    test('a disabled kind is not sent; enabling it later sends it', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service(
        prefs: const NotificationPrefs(schedule: false),
      )..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 17, 40);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      expect(platform.notifications, hasLength(1));
    });

    test('sends nothing until the preferences have loaded', () async {
      await saveCue(dueDate: DateTime(2026, 10, 13));
      platform.permissionValue = 'granted';
      now = DateTime(2026, 10, 13, 9);
      final reminders = service(prefs: null)..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(platform.notifications, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      expect(platform.notifications, hasLength(1));
    });
  });

  group('native scheduling', () {
    late _FakeScheduler scheduler;

    NotificationService scheduling({
      NotificationPrefs? prefs = const NotificationPrefs(),
    }) => service(prefs: prefs, using: _SchedulingPlatform(scheduler));

    setUp(() => scheduler = _FakeScheduler());

    test('schedules nothing until permission is granted', () async {
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(reminders.permission, 'default');
      expect(reminders.schedulesInBackground, isTrue);

      expect(await reminders.requestPermission(), 'granted');
      await pumpEventQueue();
      expect(scheduler.scheduled.map((n) => n.at), [
        DateTime(2026, 10, 13, 9),
        DateTime(2026, 10, 20, 9),
      ]);
    });

    test('picks up an existing grant and reschedules when cues change', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(reminders.permission, 'granted');
      expect(scheduler.scheduled, hasLength(2));

      await saveCue(id: 'cue-2', dueDate: DateTime(2026, 11, 20));
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(4));

      await DriftCueEquipmentRepository(db, userId: 'u1').remove('cue-2');
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(2));
    });

    test('reconcile only touches the difference', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduleCalls, 2);

      await saveSlot(time: '18:00');
      await pumpEventQueue();
      // Chỉ nhắc lịch tập mới được đặt thêm; cái bảo dưỡng giữ nguyên.
      expect(scheduler.scheduleCalls, 3);
      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.scheduled.map((n) => n.kind).toSet(), {
        NotificationKind.maintenance,
        NotificationKind.schedule,
      });
    });

    test('schedules schedule and streak reminders too', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      expect(scheduler.scheduled.map((n) => n.at), [
        DateTime(2026, 10, 13, 17, 30),
        DateTime(2026, 10, 13, 20),
      ]);
    });

    test('logging practice today cancels the pending streak reminder', () async {
      scheduler.granted = true;
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));

      await practice(DateTime(2026, 10, 13, 8));
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, hasLength(1));
    });

    test('turning a kind off cancels it, turning it on schedules it', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));

      reminders.setPrefs(const NotificationPrefs(schedule: false));
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));
    });

    test('does not touch the OS before preferences are loaded', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      final reminders = scheduling(prefs: null)..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduleCalls, 0);
      expect(scheduler.cancelAllCalls, 0);
    });

    test('never schedules more than the pending cap', () async {
      scheduler.granted = true;
      for (var i = 0; i < 35; i++) {
        await saveCue(id: 'cue-$i', dueDate: DateTime(2026, 11, 1 + i % 20));
      }
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(maxPendingNotifications));
    });

    test('cancels everything on sign-out', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, isNotEmpty);

      auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelAllCalls, greaterThan(0));
    });
  });

  group('reconcileNotifications', () {
    PlannedNotification n(int id) => PlannedNotification(
      id: id,
      kind: NotificationKind.schedule,
      key: '$id',
      at: DateTime(2026, 10, 14),
      validUntil: DateTime(2026, 10, 15),
      title: 't',
      body: 'b',
    );

    test('cancels stale ids, schedules missing ones, keeps the rest', () async {
      final scheduler = _FakeScheduler()
        ..pending = {1: n(1), 2: n(2)};
      await reconcileNotifications(scheduler, [n(2), n(3)]);
      expect(scheduler.pending.keys, {2, 3});
      expect(scheduler.cancelled, [1]);
      expect(scheduler.scheduleCalls, 1);
    });
  });
}

class _FakeScheduler implements NotificationScheduler {
  bool granted = false;
  int permissionRequests = 0;
  Map<int, PlannedNotification> pending = {};
  List<int> cancelled = [];
  int scheduleCalls = 0;
  int cancelAllCalls = 0;

  List<PlannedNotification> get scheduled => pending.values.toList();

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted = true;
  }

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();

  @override
  Future<void> schedule(PlannedNotification notification) async {
    scheduleCalls++;
    pending[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending = {};
  }
}

class _SchedulingPlatform extends NotificationPlatform {
  _SchedulingPlatform(NotificationScheduler scheduler)
    : super(scheduler: scheduler);
}

class _FakeNotificationPlatform extends NotificationPlatform {
  @override
  NotificationScheduler? get scheduler => null;

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
