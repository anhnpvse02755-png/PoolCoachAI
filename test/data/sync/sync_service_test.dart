import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late SyncService sync;
  final now = DateTime(2026, 9, 23, 10);

  SyncService build({Duration retryEvery = const Duration(seconds: 30)}) =>
      SyncService(
        db: db,
        auth: auth,
        api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
        now: () => now,
        retryEvery: retryEvery,
      );

  Future<void> addLog(
    String id, {
    String userId = 'u1',
    DateTime? syncedAt,
    double score = 7,
    DateTime? date,
  }) =>
      db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: id,
            userId: userId,
            drillId: 'd1',
            date: date ?? DateTime(2026, 9, 22, 18),
            score: score,
            syncedAt: Value(syncedAt),
          ));

  Future<DrillLogRow> row(String id) =>
      (db.select(db.drillLogRows)..where((t) => t.id.equals(id))).getSingle();

  List<String> pushedIds() => server
      .sent('POST', '/items/drill_logs')
      .map((r) => FakeDirectus.body(r)['id']! as String)
      .toList();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus()
      ..routes['POST /items/drill_logs'] =
          ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok([]));
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    sync = build();
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  group('đẩy lên', () {
    test('gửi buổi chưa đồng bộ kèm token, rồi đánh dấu đã đồng bộ', () async {
      await addLog('a');

      expect(await sync.syncNow(), SyncOutcome.done);

      expect(pushedIds(), ['a']);
      expect(
        server.sent('POST', '/items/drill_logs').single.headers['Authorization'],
        'Bearer access-u1',
      );
      expect((await row('a')).syncedAt, now);
    });

    test('không gửi lại buổi đã đồng bộ', () async {
      await addLog('cu', syncedAt: DateTime(2026, 9, 22));

      await sync.syncNow();

      expect(pushedIds(), isEmpty);
    });

    test('server báo trùng id thì coi như đã lên', () async {
      await addLog('a');
      server.routes['POST /items/drill_logs'] =
          (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');

      expect(await sync.syncNow(), SyncOutcome.done);
      expect((await row('a')).syncedAt, isNotNull);
    });

    test('mất mạng thì giữ trạng thái chờ và vẫn đăng nhập', () async {
      await addLog('a');
      server.offline = true;

      expect(await sync.syncNow(), SyncOutcome.offline);
      expect((await row('a')).syncedAt, isNull);
      expect(auth.current, isA<SignedIn>());
    });

    test('phiên hết hạn thì dừng, buổi tập vẫn nằm chờ trên máy', () async {
      await addLog('a');
      auth.tokenFailure = AuthFailure.sessionExpired;

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect((await row('a')).syncedAt, isNull);
    });

    test('buổi chưa đồng bộ của A không bao giờ đi lên bằng token của B',
        () async {
      await addLog('cua-an', userId: 'u1');
      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await addLog('cua-binh', userId: 'u2');

      await sync.syncNow();

      expect(pushedIds(), ['cua-binh']);
      for (final req in server.requests) {
        expect(req.body, isNot(contains('cua-an')));
      }
      expect((await row('cua-an')).syncedAt, isNull);
    });
  });

  group('một buổi hỏng không chặn cả hàng', () {
    final remote = [
      {
        'id': 'tu-may-khac',
        'drill_id': 'd1',
        'date': '2026-09-21T11:00:00.000Z',
        'score': 9,
        'attempts': 10,
        'notes': null,
      },
    ];

    test('server từ chối buổi 1 thì vẫn đẩy buổi 2 và vẫn kéo về', () async {
      await addLog('hong', date: DateTime(2026, 9, 22, 8));
      await addLog('tot', date: DateTime(2026, 9, 22, 9));
      server
        ..routes['POST /items/drill_logs'] = ((req) {
          final body = FakeDirectus.body(req);
          if (body['id'] == 'hong') {
            return FakeDirectus.error(400, 'FAILED_VALIDATION');
          }
          return FakeDirectus.ok(body);
        })
        ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok(remote));

      expect(await sync.syncNow(), SyncOutcome.failed);

      expect(pushedIds(), ['hong', 'tot']);
      expect((await row('hong')).syncedAt, isNull);
      expect((await row('tot')).syncedAt, now);
      expect((await row('tu-may-khac')).syncedAt, now);
    });

    test('điểm vô hạn thì báo failed, không ném, không chặn buổi sau',
        () async {
      await addLog('vo-han',
          score: double.infinity, date: DateTime(2026, 9, 22, 8));
      await addLog('tot', date: DateTime(2026, 9, 22, 9));

      expect(await sync.syncNow(), SyncOutcome.failed);

      expect(pushedIds(), ['tot']);
      expect((await row('vo-han')).syncedAt, isNull);
      expect((await row('tot')).syncedAt, now);
      expect(server.sent('GET', '/items/drill_logs'), hasLength(1));
    });

    test('server lỗi 5xx thì dừng lượt, không đánh dấu từ chối', () async {
      await addLog('a');
      server.routes['POST /items/drill_logs'] =
          ((_) => FakeDirectus.error(503, 'SERVICE_UNAVAILABLE'));

      expect(await sync.syncNow(), SyncOutcome.failed);
      expect(server.sent('GET', '/items/drill_logs'), isEmpty);
    });

    test('lỗi bất ngờ thì syncNow trả failed, không bao giờ ném', () async {
      server.routes['GET /items/drill_logs'] =
          ((_) => FakeDirectus.ok({'khong': 'phai danh sach'}));

      expect(await sync.syncNow(), SyncOutcome.failed);
    });

    test('buổi bị từ chối không làm lần thử lại định kỳ chạy mãi', () async {
      sync.dispose();
      sync = build(retryEvery: const Duration(milliseconds: 20));
      await addLog('vo-han', score: double.infinity);

      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Lượt lúc start (và có thể một lượt dồn từ stream) — không phải
      // mười mấy lượt, mỗi 20 ms một lượt.
      expect(server.sent('GET', '/items/drill_logs').length, lessThanOrEqualTo(2));
    });
  });

  group('kéo về', () {
    final remote = [
      {
        'id': 'tu-may-khac',
        'drill_id': 'd1',
        'date': '2026-09-21T11:00:00.000Z',
        'score': 9,
        'attempts': 10,
        'notes': 'Ổn',
      },
    ];

    test('ghi buổi từ server cho người đang đăng nhập, đã đồng bộ', () async {
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok(remote);

      await sync.syncNow();

      final r = await row('tu-may-khac');
      expect(r.userId, 'u1');
      expect(r.notes, 'Ổn');
      expect(r.syncedAt, now);
    });

    test('kéo hai lần không sinh bản trùng', () async {
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok(remote);

      await sync.syncNow();
      await sync.syncNow();

      expect(await db.select(db.drillLogRows).get(), hasLength(1));
    });

    test('đổi người giữa chừng thì không ghi gì', () async {
      server.routes['GET /items/drill_logs'] = (_) {
        auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
        return FakeDirectus.ok(remote);
      };

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect(await db.select(db.drillLogRows).get(), isEmpty);
    });
  });

  group('tự chạy', () {
    test('chưa đăng nhập thì không gọi server', () async {
      auth.emit(const SignedOut());

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect(server.requests, isEmpty);
    });

    test('gọi chồng nhau chỉ đẩy mỗi buổi một lần', () async {
      await addLog('a');

      await Future.wait([sync.syncNow(), sync.syncNow(), sync.syncNow()]);

      expect(pushedIds(), ['a']);
    });

    test('có buổi tập mới thì tự đẩy, không cần ai gọi', () async {
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await addLog('moi');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(pushedIds(), contains('moi'));
    });

    test('mất mạng rồi có lại thì lần thử lại định kỳ đẩy lên', () async {
      sync.dispose();
      sync = build(retryEvery: const Duration(milliseconds: 50));
      server.offline = true;
      await addLog('a');
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((await row('a')).syncedAt, isNull);

      server.offline = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect((await row('a')).syncedAt, isNotNull);
    });

    test('buổi chờ của người khác không làm lần thử lại định kỳ chạy',
        () async {
      sync.dispose();
      sync = build(retryEvery: const Duration(milliseconds: 20));
      await addLog('cua-an', userId: 'u1');
      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));

      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(server.sent('GET', '/items/drill_logs').length, lessThanOrEqualTo(2));
      expect(pushedIds(), isEmpty);
    });

    test('buổi mới của người khác không khởi động lượt nào', () async {
      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      server.requests.clear();

      await addLog('cua-an', userId: 'u1');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(server.requests, isEmpty);
    });

    test('vừa đăng nhập thì kéo dữ liệu về', () async {
      auth.emit(const SignedOut());
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      server.requests.clear();

      auth.emit(const SignedIn(userId: 'u1', displayName: 'An'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(server.sent('GET', '/items/drill_logs'), isNotEmpty);
    });
  });
}
