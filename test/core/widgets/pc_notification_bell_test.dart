import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

import '../../support/fake_auth.dart';
import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  late NotificationLogRepository repo;
  late DateTime clock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotificationLogRepository(db, userId: 'u1');
    clock = testToday;
  });
  tearDown(() => db.close());

  Future<void> add(int id, DateTime at, {bool read = false}) async {
    await repo.recordShown(
      PlannedNotification(
        id: id,
        kind: NotificationKind.schedule,
        key: 'k$id',
        at: at,
        validUntil: at.add(const Duration(hours: 1)),
        title: 'Tiêu đề $id',
        body: 'Nội dung $id',
      ),
      at: at,
    );
    if (read) await repo.markRead([id], at: at);
  }

  Future<GoRouter> open(
    WidgetTester tester, {
    ProviderContainer? using,
    String title = 'Thống kê',
    String? fontFamily,
  }) async {
    final container = using ?? dbContainer(db, clock: () => clock);
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              PcRootScaffold(title: title, body: const SizedBox()),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (_, _) => const Scaffold(body: Text('màn thông báo')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: fontFamily == null ? null : ThemeData(fontFamily: fontFamily),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  final past = testToday.subtract(const Duration(hours: 1));

  testWidgets(
    'hai mục chưa đọc đã tới giờ: huy hiệu 2; mục tương lai và đã đọc không tính',
    (tester) async {
      await add(1, past);
      await add(2, past.subtract(const Duration(minutes: 5)));
      await add(3, past, read: true);
      await add(4, testToday.add(const Duration(hours: 1)));
      await open(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip(Vi.notificationsBellTooltip(2)), findsOneWidget);
    },
  );

  testWidgets('không có mục chưa đọc: không hiện số', (tester) async {
    await add(1, past, read: true);
    await open(tester);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(find.byTooltip(Vi.notificationsTitle), findsOneWidget);
  });

  testWidgets('trên 99: hiện 99+', (tester) async {
    for (var i = 1; i <= 100; i++) {
      await add(i, past.subtract(Duration(minutes: i)));
    }
    await open(tester);
    expect(find.text('99+'), findsOneWidget);
    expect(find.byTooltip(Vi.notificationsBellTooltip(100)), findsOneWidget);
  });

  testWidgets('tới giờ của mục tương lai thì huy hiệu tự tăng', (tester) async {
    await add(1, clock.add(const Duration(minutes: 1)));
    await open(tester);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    clock = clock.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('1'), findsOneWidget);
  });

  // Máy ngủ thì timer đứng yên: khi mở máy, giờ đã qua mà timer chưa chạy.
  testWidgets('máy ngủ qua giờ giao: quay lại app thì huy hiệu đúng ngay', (
    tester,
  ) async {
    await add(1, clock.add(const Duration(minutes: 1)));
    await open(tester);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    clock = clock.add(const Duration(hours: 8));
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
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('đọc một mục thì số giảm theo', (tester) async {
    await add(1, past);
    await add(2, past.subtract(const Duration(minutes: 5)));
    await open(tester);
    expect(find.text('2'), findsOneWidget);

    await repo.markRead([1], at: clock);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip(Vi.notificationsBellTooltip(1)), findsOneWidget);
  });

  // Nhật ký của tài khoản mới đang tải: provider còn giữ giá trị của người
  // trước, không được hiện.
  testWidgets('đổi tài khoản khi nhật ký đang tải lại: không hiện số cũ', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedIn();
    final never = StreamController<List<NotificationLogEntry>>();
    addTearDown(never.close);
    final ofU1 = [
      for (final id in [1, 2])
        NotificationLogEntry(
          id: id,
          kind: NotificationKind.schedule,
          key: 'k$id',
          at: past,
          title: 'T$id',
          body: 'B$id',
        ),
    ];
    final container = dbContainer(
      db,
      auth: auth,
      clock: () => clock,
      extraOverrides: [
        notificationLogProvider.overrideWith(
          (ref) => ref.watch(currentUserIdProvider) == 'u1'
              ? Stream.value(ofU1)
              : never.stream,
        ),
      ],
    );
    await open(tester, using: container);
    expect(find.text('2'), findsOneWidget);

    auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
    await tester.pump();
    await tester.pump();
    final log = container.read(notificationLogProvider);
    expect(log.isLoading && log.hasValue, isTrue, reason: 'đang tải lại');
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('x1.5 ở 360x640: huy hiệu nằm trọn trong thanh tiêu đề và màn', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 1.5);
    await add(1, past);
    await add(2, past.subtract(const Duration(minutes: 5)));
    await open(tester);
    final appBar = tester.getRect(find.byType(AppBar));
    final badge = tester.getRect(
      find
          .ancestor(of: find.text('2'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(badge.width, greaterThan(0));
    expect(
      appBar.contains(badge.topLeft) && appBar.contains(badge.bottomRight),
      isTrue,
      reason: 'huy hiệu $badge phải nằm trong thanh tiêu đề $appBar',
    );
    expect(
      Offset.zero & const Size(360, 640),
      predicate<Rect>((s) => s.contains(badge.topLeft) && s.contains(badge.bottomRight)),
    );
  });

  for (final c in const [
    (Size(360, 640), 1.0, 1),
    (Size(360, 640), 1.0, 120),
    (Size(360, 640), 1.5, 1),
    (Size(360, 640), 1.5, 120),
    (Size(320, 640), 1.2, 1),
    (Size(320, 640), 1.2, 120),
  ]) {
    testWidgets(
      'huy hiệu ở góc chuông, không che biểu tượng: ${c.$1} x${c.$2}, ${c.$3} mục',
      (tester) async {
        applyScreen(tester, c.$1, textScale: c.$2);
        for (var i = 1; i <= c.$3; i++) {
          await add(i, past.subtract(Duration(minutes: i)));
        }
        await open(tester);
        final label = Vi.notificationsUnreadBadge(c.$3);
        final badge = tester.getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
              .first,
        );
        final appBar = tester.getRect(find.byType(AppBar));
        final screen = Offset.zero & c.$1;
        expect(badge.width, greaterThan(0));
        for (final outer in [appBar, screen]) {
          expect(
            outer.contains(badge.topLeft) && outer.contains(badge.bottomRight),
            isTrue,
            reason: 'huy hiệu $badge phải nằm trong $outer',
          );
        }
        final icon = tester.getRect(find.byIcon(Icons.notifications_none));
        final overlap = icon.intersect(badge);
        final area = overlap.width <= 0 || overlap.height <= 0
            ? 0.0
            : overlap.width * overlap.height;
        expect(
          area,
          lessThan(icon.width * icon.height * 0.25),
          reason: 'huy hiệu $badge che biểu tượng $icon',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final c in const [
    (Size(360, 640), 1.5),
    (Size(320, 640), 1.2),
  ]) {
    for (final unread in const [0, 120]) {
      testWidgets(
        'tiêu đề gốc không bị cắt vì chuông: ${c.$1} x${c.$2}, $unread mục',
        (tester) async {
          applyScreen(tester, c.$1, textScale: c.$2);
          const family = 'RobotoBellTitle';
          final bytes = File(
            'test/fixtures/fonts/roboto-regular.ttf',
          ).readAsBytesSync();
          await tester.runAsync(
            () => (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
          );
          for (var i = 1; i <= unread; i++) {
            await add(i, past.subtract(Duration(minutes: i)));
          }
          await open(tester, title: Vi.trainingTitle, fontFamily: family);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(Vi.trainingTitle),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('chạm chuông mở màn Thông báo', (tester) async {
    await open(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('màn thông báo'), findsOneWidget);
  });

  testWidgets('360×640 chữ x1.5: huy hiệu 99+ không tràn thanh tiêu đề', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 1.5);
    for (var i = 1; i <= 100; i++) {
      await add(i, past.subtract(Duration(minutes: i)));
    }
    await open(tester);
    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
