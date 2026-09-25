import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  final today = DateTime(2026, 9, 23, 10);

  Future<(AppDatabase, FakeAuthRepository, FakeDirectus)> openProfile(
    WidgetTester tester, {
    int pending = 0,
    int unsyncable = 0,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);
    for (var i = 0; i < pending; i++) {
      await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: 'p$i', userId: 'u1', drillId: 'd1', date: today, score: 7));
    }
    for (var i = 0; i < unsyncable; i++) {
      await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: 'u$i', userId: 'u1', drillId: 'd1', date: today,
            score: double.infinity));
    }
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'da-len', userId: 'u1', drillId: 'd1', date: today, score: 7,
          syncedAt: Value(today)));

    final auth = FakeAuthRepository.signedIn(userId: 'u1', displayName: 'An');
    final server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok([]));
    final sync = SyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(sync.dispose);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      nowProvider.overrideWithValue(() => today),
      authRepositoryProvider.overrideWithValue(auth),
      syncServiceProvider.overrideWithValue(sync),
    ]);
    addTearDown(container.dispose);
    final gate = AuthGate(auth);
    addTearDown(gate.dispose);
    final router = createAppRouter(auth: gate);
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    await tester.pumpAndSettle();
    router.go(Routes.profile);
    await tester.pumpAndSettle();
    return (db, auth, server);
  }

  testWidgets('hiện tên người đang đăng nhập', (tester) async {
    await openProfile(tester);

    expect(find.text(Vi.profileSignedInAs('An')), findsOneWidget);
  });

  testWidgets('không còn buổi chờ thì đăng xuất ngay, xoá dữ liệu trên máy',
      (tester) async {
    final (db, auth, _) = await openProfile(tester);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('còn buổi chờ thì cảnh báo trước, bấm Vẫn đăng xuất thì mất',
      (tester) async {
    final (db, auth, _) = await openProfile(tester, pending: 2);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutPendingBody(2)), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.tap(find.text(Vi.signOutAnyway));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('chọn Đồng bộ trước thì đẩy lên rồi mới đăng xuất', (tester) async {
    final (_, auth, server) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/drill_logs'), hasLength(1));
    expect(auth.calls, ['signOut']);
  });

  testWidgets('Đồng bộ trước mà mất mạng thì không đăng xuất, báo lỗi',
      (tester) async {
    final (db, auth, server) = await openProfile(tester, pending: 1);
    server.offline = true;

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(find.text(Vi.syncFailed), findsOneWidget);
    expect(auth.calls, isEmpty);
    expect(await db.select(db.drillLogRows).get(), hasLength(2));
  });

  // Buổi điểm vô hạn không bao giờ lên được: báo "kiểm tra mạng" là sai
  // nguyên nhân, người chơi thử mãi không xong. Chỉ đường tới chỗ bỏ chúng.
  testWidgets('Đồng bộ trước mà chỉ còn buổi không đồng bộ được thì chỉ tới cảnh báo',
      (tester) async {
    final (db, auth, server) = await openProfile(tester, pending: 1, unsyncable: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/drill_logs'), hasLength(1)); // buổi thường đã lên
    expect(find.text(Vi.syncBlockedByUnsyncable), findsOneWidget);
    expect(find.text(Vi.syncFailed), findsNothing);
    expect(auth.calls, isEmpty);
    expect((await db.select(db.drillLogRows).get()).where((r) => !r.score.isFinite),
        hasLength(1));
  });

  testWidgets('Đồng bộ trước mất mạng, còn cả buổi thường lẫn buổi lỗi thì vẫn báo mạng',
      (tester) async {
    final (_, auth, server) = await openProfile(tester, pending: 1, unsyncable: 1);
    server.offline = true;

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(find.text(Vi.syncFailed), findsOneWidget);
    expect(find.text(Vi.syncBlockedByUnsyncable), findsNothing);
    expect(auth.calls, isEmpty);
  });

  testWidgets('bỏ qua hộp thoại thì không làm gì', (tester) async {
    final (_, auth, _) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
  });

  testWidgets('có buổi không đồng bộ được thì Hồ sơ báo, bấm Bỏ thì xoá sau khi xác nhận',
      (tester) async {
    final (db, auth, _) = await openProfile(tester, unsyncable: 2);

    expect(find.text(Vi.unsyncableTitle(2)), findsOneWidget);
    await tester.tap(find.text(Vi.unsyncableDiscard));
    await tester.pumpAndSettle();
    expect(find.text(Vi.unsyncableConfirmBody(2)), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, Vi.unsyncableConfirm));
    await tester.pumpAndSettle();

    final left = await db.select(db.drillLogRows).get();
    expect(left.where((r) => !r.score.isFinite), isEmpty);
    expect(left.map((r) => r.id), contains('da-len'));
    expect(find.text(Vi.unsyncableTitle(2)), findsNothing);
    expect(auth.calls, isEmpty);
  });

  testWidgets('Huỷ ở hộp xác nhận thì không xoá gì', (tester) async {
    final (db, _, _) = await openProfile(tester, unsyncable: 1);

    await tester.tap(find.text(Vi.unsyncableDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.cancel));
    await tester.pumpAndSettle();

    expect((await db.select(db.drillLogRows).get()).where((r) => !r.score.isFinite),
        hasLength(1));
  });

  testWidgets('không có buổi lỗi thì không hiện gì', (tester) async {
    await openProfile(tester);
    expect(find.text(Vi.unsyncableDiscard), findsNothing);
  });

  testWidgets('hộp thoại đăng xuất: Đồng bộ trước là nút chính', (tester) async {
    await openProfile(tester, pending: 1);
    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, Vi.signOutSyncFirst), findsOneWidget);
    expect(find.widgetWithText(TextButton, Vi.signOutAnyway), findsOneWidget);
  });
}
