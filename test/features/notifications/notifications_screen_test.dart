import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/features/notifications/presentation/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth.dart';
import '../../support/layout_sweep.dart';
import '../../support/fake_recommendation_seen_store.dart';
import '../../support/test_data.dart';

/// Trình duyệt giả: hỗ trợ thông báo, không đặt lịch được.
class _Platform extends NotificationPlatform {
  String value = 'default';
  int requests = 0;

  /// Có bộ đặt lịch là điện thoại; không có là trình duyệt.
  @override
  NotificationScheduler? scheduler;

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

  /// Mặc định không có bài nào: không có gợi ý, các test cũ giữ nghĩa.
  ProviderContainer containerWith({
    Map<String, Object> saved = const {},
    List<ScheduleSlot>? schedule,
    List<Drill> drills = const [],
    FakeRecommendationSeenStore? seenStore,
    Stream<List<DrillLog>>? logsStream,
    List<NotificationLogEntry>? notificationLog,
  }) {
    SharedPreferences.setMockInitialValues(saved);
    return testContainer(
      schedule: schedule,
      drills: drills,
      seenStore: seenStore,
      logsStream: logsStream,
      notificationLog: notificationLog,
    );
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

  testWidgets('Sắp tới có Gợi ý tập mới ngày mai lúc 08:00', (tester) async {
    await open(tester, containerWith(drills: testDrills));
    expect(find.text(Vi.recommendationReminderTitle), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text(Vi.notificationsTomorrow.toUpperCase()), findsOneWidget);
  });

  testWidgets('đã thấy đúng cặp ở Trang chủ: Sắp tới không có gợi ý', (
    tester,
  ) async {
    final tomorrow = DateTime(
      testToday.year,
      testToday.month,
      testToday.day + 1,
      recommendationReminderHour,
    );
    final rec = RecommendationInputs(
      drills: testDrills,
      logs: const [],
      knowledge: testKnowledge,
      timerSessions: const [],
      schedule: const [],
      matches: const [],
    ).recommendFor(tomorrow);
    final store = FakeRecommendationSeenStore()
      ..saved['u1'] = SeenRecommendation(
        cat: rec.cat,
        drillId: rec.drill!.id,
        at: testToday,
      );
    await open(tester, containerWith(drills: testDrills, seenStore: store));
    expect(find.text(Vi.recommendationReminderTitle), findsNothing);
    expect(find.text(Vi.notificationsUpcomingEmpty), findsOneWidget);
  });

  group('nguồn gợi ý chưa sẵn sàng', () {
    // Gợi ý đã đặt từ lần mở trước, còn ở tương lai.
    final kept = NotificationLogEntry(
      id: 41,
      kind: NotificationKind.recommendation,
      key: '2026-9-23:aiming:d1',
      at: DateTime(2026, 9, 23, recommendationReminderHour),
      title: Vi.recommendationReminderTitle,
      body: 'Nội dung đã lập lần trước',
    );

    testWidgets('đang tải: Sắp tới vẫn hiện gợi ý đã đặt', (tester) async {
      await open(
        tester,
        containerWith(
          drills: testDrills,
          logsStream: StreamController<List<DrillLog>>().stream,
          notificationLog: [kept],
        ),
      );
      expect(find.text(Vi.recommendationReminderTitle), findsOneWidget);
      expect(find.text(kept.body), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('lỗi: Sắp tới không còn gợi ý', (tester) async {
      await open(
        tester,
        containerWith(
          drills: testDrills,
          logsStream: Stream.error(StateError('hỏng')),
          notificationLog: [kept],
        ),
      );
      expect(find.text(Vi.recommendationReminderTitle), findsNothing);
    });
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

    Future<void> openNarrow(WidgetTester tester) async {
      applyScreen(tester, const Size(360, 640), textScale: 1.5);
      final container = withService();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('web: ghi chú chỉ khi đang mở, không có ghi chú nền', (
      tester,
    ) async {
      await open(tester, withService());
      expect(find.text(Vi.notificationsWebOnlyWhileOpen), findsOneWidget);
      expect(find.text(Vi.notificationsBackgroundNote), findsNothing);
      expect(find.text(Vi.notificationsRecommendationLimit), findsNothing);
      expect(
        Vi.notificationsWebOnlyWhileOpen,
        contains('${recommendationReminderHour.toString().padLeft(2, '0')}:00'),
      );
    });

    testWidgets('điện thoại: ghi chú nền và giới hạn gợi ý, không có ghi chú '
        'web', (tester) async {
      platform.scheduler = _IdleScheduler();
      await open(tester, withService());
      expect(find.text(Vi.notificationsBackgroundNote), findsOneWidget);
      expect(find.text(Vi.notificationsRecommendationLimit), findsOneWidget);
      expect(find.text(Vi.notificationsWebOnlyWhileOpen), findsNothing);
    });

    testWidgets('360x640 x1.5 web: ghi chú đủ chữ, không tràn', (tester) async {
      await openNarrow(tester);
      expect(find.text(Vi.notificationsWebOnlyWhileOpen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 x1.5 điện thoại: hai ghi chú đủ chữ, không tràn', (
      tester,
    ) async {
      platform.scheduler = _IdleScheduler();
      await openNarrow(tester);
      expect(find.text(Vi.notificationsBackgroundNote), findsOneWidget);
      expect(find.text(Vi.notificationsRecommendationLimit), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bật quyền trong cài đặt rồi quay lại: thẻ quyền cập nhật', (
      tester,
    ) async {
      await open(tester, withService());
      expect(find.text(Vi.notificationsPermissionPrompt), findsOneWidget);

      platform.value = 'granted';
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.text(Vi.notificationsPermissionGranted), findsOneWidget);
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

  group('Đã gửi', () {
    late AppDatabase db;
    late NotificationLogRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = NotificationLogRepository(db, userId: 'u1');
    });
    tearDown(() => db.close());

    Future<void> add(
      int id,
      DateTime at, {
      NotificationKind kind = NotificationKind.schedule,
      String? key,
      bool read = false,
    }) async {
      await repo.recordShown(
        PlannedNotification(
          id: id,
          kind: kind,
          key: key ?? 's1:2026-9-22',
          at: at,
          validUntil: at.add(const Duration(hours: 1)),
          title: 'Tiêu đề $id',
          body: 'Nội dung $id',
        ),
        at: at,
      );
      if (read) await repo.markRead([id], at: at);
    }

    Future<void> openDb(WidgetTester tester) async {
      final container = dbContainer(db, drills: const []);
      await open(tester, container);
    }

    final hourAgo = testToday.subtract(const Duration(hours: 1));

    testWidgets(
      'mục đã tới giờ trong 30 ngày, mới nhất trước; không có mục tương lai hay quá 30 ngày',
      (tester) async {
        await add(1, testToday.subtract(const Duration(days: 2)));
        await add(2, hourAgo);
        await add(3, testToday.add(const Duration(hours: 1)));
        await add(4, testToday.subtract(const Duration(days: 31)));
        await openDb(tester);
        expect(find.text('Tiêu đề 2'), findsOneWidget);
        expect(find.text('Tiêu đề 1'), findsOneWidget);
        expect(find.text('Tiêu đề 3'), findsNothing);
        expect(find.text('Tiêu đề 4'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Tiêu đề 2')).dy,
          lessThan(tester.getTopLeft(find.text('Tiêu đề 1')).dy),
        );
        expect(
          find.text(Vi.notificationsSentAt(hourAgo, testToday)),
          findsOneWidget,
        );
        expect(find.text(Vi.notificationsSentEmpty), findsNothing);
      },
    );

    testWidgets('mở màn: chưa đọc in đậm và được đánh dấu đã đọc, vẫn đậm trong '
        'lượt xem này', (tester) async {
      await add(1, hourAgo);
      await add(2, hourAgo.subtract(const Duration(minutes: 5)), read: true);
      await add(3, testToday.add(const Duration(hours: 1)));
      await openDb(tester);
      final rows = {for (final e in await repo.all()) e.id: e.readAt};
      expect(rows[1], isNotNull);
      expect(rows[3], isNull);
      FontWeight? weight(String t) =>
          tester.widget<Text>(find.text(t)).style!.fontWeight;
      expect(weight('Tiêu đề 1'), FontWeight.w700);
      expect(weight('Tiêu đề 2'), FontWeight.w400);
    });

    testWidgets('trống: nói chưa có trong 30 ngày', (tester) async {
      await openDb(tester);
      expect(find.text(Vi.notificationsSentEmpty), findsOneWidget);
    });

    testWidgets('chạm mục Lịch tập: mở Lịch tập', (tester) async {
      await add(1, hourAgo);
      final container = dbContainer(db, drills: const []);
      addTearDown(container.dispose);
      final router = createAppRouter(auth: signedInGate());
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: PoolCoachApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go(Routes.notifications);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiêu đề 1'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        Routes.schedule,
      );
    });
  });

  testWidgets('có công tắc Gợi ý tập mới, bật mặc định', (tester) async {
    await open(tester, containerWith());
    expect(
      tester
          .widget<SwitchListTile>(switchOf(NotificationKind.recommendation))
          .value,
      isTrue,
    );
  });

  testWidgets(
    '360×640 chữ x1.5: màn Thông báo có Đã gửi và Sắp tới không tràn',
    (tester) async {
      applyScreen(tester, const Size(360, 640), textScale: 1.5);
      SharedPreferences.setMockInitialValues({});
      final long = 'Nội dung rất dài ' * 12;
      final container = testContainer(
        drills: testDrills,
        notificationLog: [
          for (var i = 1; i <= 3; i++)
            NotificationLogEntry(
              id: i,
              kind: NotificationKind.schedule,
              key: 's1:2026-9-22',
              at: testToday.subtract(Duration(hours: i)),
              title: 'Tiêu đề rất dài số $i ' * 4,
              body: long,
              readAt: i == 3 ? testToday : null,
            ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollThroughAll(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(Vi.notificationsSentTitle.toUpperCase()), findsOneWidget);
    },
  );
}

/// Bộ đặt lịch giả: chỉ cần có mặt để nền tảng đặt lịch được ở nền.
class _IdleScheduler implements NotificationScheduler {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<Set<int>> pendingIds() async => {};

  @override
  Future<void> schedule(PlannedNotification notification) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  set onTap(void Function(String payload)? handler) {}

  @override
  Future<String?> launchPayload() async => null;
}
