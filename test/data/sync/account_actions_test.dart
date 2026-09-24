import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';
import '../../support/in_memory_session_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addLog(String id, String userId, {bool synced = false}) =>
      db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: id,
            userId: userId,
            drillId: 'd1',
            date: DateTime(2026, 9, 22),
            score: 7,
            syncedAt: Value(synced ? DateTime(2026, 9, 22) : null),
          ));

  test('chỉ đếm buổi chưa đồng bộ của đúng người', () async {
    await addLog('a', 'u1');
    await addLog('b', 'u1', synced: true);
    await addLog('c', 'u2');

    expect(await pendingLogCount(db, 'u1'), 1);
  });

  test('bấm Đăng xuất thì xoá buổi của người đó, giữ của người khác', () async {
    final auth = FakeAuthRepository.signedIn(userId: 'u1');
    await addLog('a', 'u1');
    await addLog('c', 'u2');

    await signOutAndForget(db: db, auth: auth, userId: 'u1');

    final left = await db.select(db.drillLogRows).get();
    expect(left.map((r) => r.id), ['c']);
    expect(auth.current, const SignedOut());
  });

  test('kéo về đang chạy dở không dựng lại buổi vừa xoá khi đăng xuất',
      () async {
    final now = DateTime(2026, 9, 23, 10);
    final server = FakeDirectus()..acceptLogin(userId: 'u1', refresh: 'r1');
    final api =
        DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);
    final auth = DirectusAuthRepository(
      api: api,
      sessions: InMemorySessionStore(),
      resetUrl: Uri.parse('https://app.test/reset-password'),
      now: () => now,
    );
    await auth.signIn(email: 'an@example.com', password: 'matkhau123');
    await addLog('a', 'u1', synced: true);

    final pullGate = Completer<void>();
    final logoutGate = Completer<void>();
    server
      ..routes['GET /items/drill_logs'] = ((_) async {
        await pullGate.future;
        return FakeDirectus.ok([
          {
            'id': 'a',
            'drill_id': 'd1',
            'date': '2026-09-22T00:00:00.000Z',
            'score': 7,
            'attempts': null,
            'notes': null,
          },
        ]);
      })
      ..routes['POST /auth/logout'] = ((_) async {
        await logoutGate.future;
        return FakeDirectus.noContent();
      });
    final sync = SyncService(db: db, auth: auth, api: api, now: () => now);
    addTearDown(sync.dispose);

    final pass = sync.syncNow();
    await pumpEventQueue();
    expect(server.sent('GET', '/items/drill_logs'), hasLength(1));

    final signingOut = signOutAndForget(db: db, auth: auth, userId: 'u1');
    await pumpEventQueue();
    pullGate.complete(); // server trả dữ liệu của người vừa đăng xuất
    await pass;
    logoutGate.complete();
    await signingOut;

    final left = await (db.select(db.drillLogRows)
          ..where((t) => t.userId.equals('u1')))
        .get();
    expect(left, isEmpty);
    expect(auth.current, const SignedOut());
  });
}
