import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

/// Trình duyệt giả: hỗ trợ thông báo, không đặt lịch được.
class _Platform extends NotificationPlatform {
  String value = 'default';
  int requests = 0;

  @override
  NotificationScheduler? get scheduler => null;

  @override
  bool get isSupported => true;

  @override
  String? get permission => value;

  @override
  Future<String?> requestPermission() async {
    requests++;
    return value = 'granted';
  }
}

void main() {
  // testToday = Thứ Ba 2026-09-22 10:00 (day index 1).
  Future<void> open(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerWith({
    Map<String, Object> saved = const {},
    List<ScheduleSlot>? schedule,
  }) {
    SharedPreferences.setMockInitialValues(saved);
    return testContainer(schedule: schedule);
  }

  Finder switchOf(NotificationKind kind) =>
      find.widgetWithText(SwitchListTile, Vi.notificationKind(kind));

  const slots = [
    ScheduleSlot(id: 's1', day: 1, time: '18:00', label: 'Tập ngắm'),
    ScheduleSlot(id: 's2', day: 2, time: '19:00', label: 'Tập phá'),
  ];

  testWidgets('empty plan says there is nothing in the next 7 days', (
    tester,
  ) async {
    await open(tester, containerWith());
    expect(find.text(Vi.notificationsUpcomingEmpty), findsOneWidget);
    for (final kind in NotificationKind.values) {
      expect(switchOf(kind), findsOneWidget);
    }
  });

  testWidgets('lists planned notifications grouped by day', (tester) async {
    await open(tester, containerWith(schedule: slots));

    expect(find.text(Vi.notificationsToday.toUpperCase()), findsOneWidget);
    expect(find.text(Vi.notificationsTomorrow.toUpperCase()), findsOneWidget);
    expect(
      find.text(Vi.scheduleReminderBody('Tập ngắm', '18:00', 30, null)),
      findsOneWidget,
    );
    expect(
      find.text(Vi.scheduleReminderBody('Tập phá', '19:00', 30, null)),
      findsOneWidget,
    );
    expect(find.text('17:30'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);
    expect(find.text(Vi.notificationsUpcomingEmpty), findsNothing);
  });

  testWidgets('turning a kind off removes it from the list and saves it', (
    tester,
  ) async {
    await open(tester, containerWith(schedule: slots));
    expect(find.text(Vi.scheduleReminderTitle), findsNWidgets(2));

    await tester.tap(switchOf(NotificationKind.schedule));
    await tester.pumpAndSettle();

    expect(find.text(Vi.scheduleReminderTitle), findsNothing);
    expect(find.text(Vi.notificationsUpcomingEmpty), findsOneWidget);
    final saved = await SharedPreferencesNotificationPrefsStore().load('u1');
    expect(saved.schedule, isFalse);
    expect(saved.maintenance, isTrue);
    expect(saved.streak, isTrue);
  });

  testWidgets('saved preferences are shown on open', (tester) async {
    await open(
      tester,
      containerWith(
        saved: {'poolcoachai:notification-prefs:v1:u1:streak': false},
      ),
    );
    bool value(NotificationKind kind) =>
        tester.widget<SwitchListTile>(switchOf(kind)).value;
    expect(value(NotificationKind.streak), isFalse);
    expect(value(NotificationKind.schedule), isTrue);
    expect(value(NotificationKind.maintenance), isTrue);
  });

  group('permission', () {
    late AppDatabase db;
    late _Platform platform;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      platform = _Platform();
    });
    tearDown(() => db.close());

    ProviderContainer withService() {
      final service = NotificationService(
        db: db,
        auth: FakeAuthRepository.signedIn(),
        now: () => testToday,
        platform: platform,
      );
      addTearDown(service.dispose);
      return ProviderContainer(
        parent: containerWith(),
        overrides: [notificationServiceProvider.overrideWithValue(service)],
      );
    }

    testWidgets('prompt state: button asks the OS, then shows granted', (
      tester,
    ) async {
      await open(tester, withService());
      expect(find.text(Vi.notificationsPermissionPrompt), findsOneWidget);
      expect(find.text(Vi.notificationsWebOnlyWhileOpen), findsOneWidget);

      await tester.tap(find.text(Vi.equipmentReminderEnable));
      await tester.pumpAndSettle();

      expect(platform.requests, 1);
      expect(find.text(Vi.notificationsPermissionGranted), findsOneWidget);
      expect(find.text(Vi.equipmentReminderEnable), findsNothing);
    });

    testWidgets('denied state explains how to re-enable, without button', (
      tester,
    ) async {
      platform.value = 'denied';
      await open(tester, withService());
      expect(find.text(Vi.notificationsPermissionDenied), findsOneWidget);
      expect(find.text(Vi.equipmentReminderEnable), findsNothing);
    });
  });

  testWidgets('unsupported platform explains it and offers no enable button', (
    tester,
  ) async {
    // flutter test chạy trên VM desktop: nền tảng không hỗ trợ thông báo.
    await open(tester, containerWith());
    expect(find.text(Vi.notificationsPermissionUnsupported), findsOneWidget);
    expect(find.text(Vi.equipmentReminderEnable), findsNothing);
  });
}
