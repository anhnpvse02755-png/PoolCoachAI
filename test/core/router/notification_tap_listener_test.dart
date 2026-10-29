import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/notification_tap_listener.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

/// Trình duyệt giả: hỗ trợ thông báo, không đặt lịch, có thể "mở app từ
/// thông báo".
class _Platform extends NotificationPlatform {
  String? launch;

  @override
  NotificationScheduler? get scheduler => null;

  @override
  bool get isSupported => true;

  @override
  String? get permission => 'default';

  @override
  Future<String?> takeLaunchPayload() async => launch;
}

/// Dịch vụ chỉ đếm số lần được báo app quay lại.
class _ResumeCountingService extends NotificationService {
  _ResumeCountingService(AppDatabase db)
    : super(
        db: db,
        auth: FakeAuthRepository(),
        now: () => testToday,
        platform: _Platform(),
      );

  int resumes = 0;

  @override
  Future<void> resumed() async => resumes++;
}

void main() {
  test('mỗi loại mở đúng màn', () {
    final r = recommendationKey(
      DateTime(2026, 9, 22),
      SkillCategory.aiming,
      'd1',
    );
    expect(
      notificationRoute(NotificationTap(NotificationKind.recommendation, r)),
      Routes.drill('d1'),
    );
    expect(
      notificationRoute(
        const NotificationTap(NotificationKind.schedule, 's1:2026-9-22'),
      ),
      Routes.schedule,
    );
    expect(
      notificationRoute(
        const NotificationTap(NotificationKind.maintenance, 'c1:2026-9-22:0'),
      ),
      Routes.equipment,
    );
    expect(
      notificationRoute(
        const NotificationTap(NotificationKind.streak, '2026-9-22'),
      ),
      Routes.training,
    );
    for (final k in NotificationKind.values) {
      expect(
        notificationRoute(
          NotificationTap(k, k == NotificationKind.recommendation ? r : 'x'),
        ),
        isNotNull,
        reason: k.name,
      );
    }
    expect(
      notificationRoute(
        const NotificationTap(NotificationKind.recommendation, 'rác'),
      ),
      isNull,
    );
  });

  group('nghe chạm thông báo', () {
    late _Platform platform;
    late NotificationService service;
    late GoRouter router;

    /// Dựng listener quanh MaterialApp.router. Dịch vụ đăng xuất nên không
    /// đụng DB; đã start trước khi pump như khi khởi động thật.
    Future<void> open(WidgetTester tester, {String? launch}) async {
      platform = _Platform()..launch = launch;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      service = NotificationService(
        db: db,
        auth: FakeAuthRepository(),
        now: () => testToday,
        platform: platform,
      )..start();
      // Timer định kỳ của nền tảng web: dọn ngay cả khi test hỏng giữa chừng.
      addTearDown(service.dispose);
      router = createAppRouter(auth: signedInGate());
      addTearDown(router.dispose);
      final container = ProviderContainer(
        parent: testContainer(),
        overrides: [notificationServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: NotificationTapListener(
            router: router,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String path() => router.routerDelegate.currentConfiguration.uri.path;

    testWidgets('chạm thông báo lịch tập khi app đang mở: tới Lịch tập', (
      tester,
    ) async {
      await open(tester);
      expect(path(), Routes.home);
      platform.onTap!(
        notificationPayload(NotificationKind.schedule, 's1:2026-9-22'),
      );
      await tester.pumpAndSettle();
      expect(path(), Routes.schedule);
      service.dispose();
    });

    testWidgets(
      'mở app từ thông báo gợi ý (khởi động lạnh): tới chi tiết bài',
      (tester) async {
        final key = recommendationKey(
          DateTime(2026, 9, 22),
          SkillCategory.aiming,
          'd1',
        );
        await open(
          tester,
          launch: notificationPayload(NotificationKind.recommendation, key),
        );
        expect(path(), Routes.drill('d1'));
        service.dispose();
      },
    );

    testWidgets('gợi ý cho bài không còn: mở màn bài, không lỗi', (
      tester,
    ) async {
      await open(tester);
      final key = recommendationKey(
        DateTime(2026, 9, 22),
        SkillCategory.aiming,
        'd404',
      );
      platform.onTap!(
        notificationPayload(NotificationKind.recommendation, key),
      );
      await tester.pumpAndSettle();
      expect(path(), Routes.drill('d404'));
      expect(tester.takeException(), isNull);
      service.dispose();
    });

    testWidgets('payload rác: đứng yên', (tester) async {
      await open(tester);
      platform.onTap!('rác');
      await tester.pumpAndSettle();
      expect(path(), Routes.home);
      service.dispose();
    });
  });

  testWidgets('quay lại app: báo dịch vụ (đọc lại quyền, đồng bộ)', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _ResumeCountingService(db);
    addTearDown(service.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = ProviderContainer(
      parent: testContainer(),
      overrides: [notificationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: NotificationTapListener(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.resumes, 0);
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
    expect(service.resumes, 1);
  });

  testWidgets('PoolCoachApp tự dựng router thì gắn listener chạm thông báo', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = testContainer(
      extraOverrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PoolCoachApp(),
      ),
    );
    expect(find.byType(NotificationTapListener), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
