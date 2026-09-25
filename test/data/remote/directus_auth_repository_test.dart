import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_directus.dart';
import '../../support/in_memory_session_store.dart';

/// An in-memory store that blocks inside [clear] until [releaseClear] is called,
/// and blocks inside [write] until [releaseWrite] is called. Used to interleave
/// signOut / _expire with a concurrent refresh.
class DeferredInMemorySessionStore extends InMemorySessionStore {
  final clearGate = Completer<void>();
  final writeGate = Completer<void>();

  @override
  Future<void> clear() async {
    await clearGate.future;
    await super.clear();
  }

  @override
  Future<void> write(StoredSession s) async {
    await writeGate.future;
    await super.write(s);
  }

  void releaseClear() {
    if (!clearGate.isCompleted) clearGate.complete();
  }

  void releaseWrite() {
    if (!writeGate.isCompleted) writeGate.complete();
  }
}

/// Lần đọc bị chặn chụp phiên **lúc bắt đầu đọc** rồi mới chờ — như một
/// lần đọc DB trả về giá trị đã cũ khi code phía sau chạy. [skip] lần đọc
/// đầu tiên đi thẳng; lần kế tiếp chờ [gate], rồi cổng tự gỡ.
class GatedReadSessionStore extends InMemorySessionStore {
  Completer<void>? gate;
  int skip = 0;

  @override
  Future<StoredSession?> read() async {
    final snapshot = session;
    final g = gate;
    if (g != null) {
      if (skip > 0) {
        skip--;
      } else {
        gate = null;
        await g.future;
      }
    }
    return snapshot;
  }
}

/// Như [GatedReadSessionStore] nhưng trả phiên **lúc đọc xong**, không
/// phải lúc bắt đầu — mô phỏng lần đọc thấy thay đổi xảy ra trong lúc chờ.
class LiveGatedReadSessionStore extends InMemorySessionStore {
  Completer<void>? gate;
  int skip = 0;

  @override
  Future<StoredSession?> read() async {
    final g = gate;
    if (g != null) {
      if (skip > 0) {
        skip--;
      } else {
        gate = null;
        await g.future;
      }
    }
    return session;
  }
}

/// Lệnh chạy đúng thứ tự gọi, như hàng đợi của Drift; [clearGate] giữ
/// lệnh clear() — và mọi lệnh gọi sau nó — cho tới khi mở.
class SerialGatedSessionStore extends InMemorySessionStore {
  final clearGate = Completer<void>();
  Future<void> _tail = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<StoredSession?> read() => _enqueue(super.read);
  @override
  Future<void> write(StoredSession s) => _enqueue(() => super.write(s));
  @override
  Future<void> clear() => _enqueue(() async {
        await clearGate.future;
        await super.clear();
      });
}

void main() {
  late FakeDirectus server;
  late InMemorySessionStore store;
  late DateTime now;
  late DirectusAuthRepository auth;

  final resetUrl = Uri.parse('https://app.test/reset-password');

  DirectusAuthRepository build() => DirectusAuthRepository(
        api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
        sessions: store,
        resetUrl: resetUrl,
        now: () => now,
      );

  setUp(() {
    server = FakeDirectus();
    store = InMemorySessionStore();
    now = DateTime(2026, 9, 23, 10);
    auth = build();
  });

  group('đăng nhập', () {
    test('thành công thì lưu phiên và báo SignedIn', () async {
      server.acceptLogin(userId: 'u1', name: 'An', refresh: 'r1');
      final changes = <AuthState>[];
      auth.watchSession().listen(changes.add);

      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      await pumpEventQueue();

      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));
      expect(changes, [const SignedIn(userId: 'u1', displayName: 'An')]);
      expect(store.session?.refreshToken, 'r1');
      expect(FakeDirectus.body(server.sent('POST', '/auth/login').single)['mode'], 'json');
    });

    test('email được cắt khoảng trắng và viết thường', () async {
      server.acceptLogin();

      await auth.signIn(email: '  An@Example.COM ', password: 'matkhau123');

      expect(
        FakeDirectus.body(server.sent('POST', '/auth/login').single)['email'],
        'an@example.com',
      );
    });

    test('sai mật khẩu thì wrongCredentials, không lưu gì', () async {
      server.routes['POST /auth/login'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(
        auth.signIn(email: 'an@example.com', password: 'sai'),
        throwsA(AuthFailure.wrongCredentials),
      );
      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });

    test('mất mạng thì network', () async {
      server.offline = true;

      await expectLater(
        auth.signIn(email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.network),
      );
    });

    test('/users/me hỏng thì không giữ token nào', () async {
      server.acceptLogin(refresh: 'r1');
      server.routes['GET /users/me'] = (_) => FakeDirectus.error(500, 'INTERNAL');

      await expectLater(
        auth.signIn(email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.unknown),
      );
      // Nếu token đã bị giữ, một lần restore() sau đó sẽ trả luôn token của
      // lần đăng nhập hỏng thay vì làm mới.
      store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r0');
      await auth.restore();
      server.routes['POST /auth/refresh'] = (_) => FakeDirectus.ok(
          {'access_token': 'access-r0b', 'expires': 900000, 'refresh_token': 'r0b'});
      expect(await auth.accessToken(), 'access-r0b');
    });
  });

  group('đăng ký', () {
    test('thành công thì đăng nhập luôn, tên được cắt khoảng trắng', () async {
      server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();
      server.acceptLogin();

      await auth.register(
        displayName: '  An  ',
        email: 'An@Example.com',
        password: 'matkhau123',
      );

      final body = FakeDirectus.body(server.sent('POST', '/users/register').single);
      expect(body['first_name'], 'An');
      expect(body['email'], 'an@example.com');
      expect(auth.current, isA<SignedIn>());
    });

    test('server im lặng về email trùng nhưng đăng nhập hỏng thì emailTaken',
        () async {
      server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();
      server.routes['POST /auth/login'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.emailTaken),
      );
    });

    test('đăng ký lại sau khi lần trước hỏng mạng giữa chừng thì vào được tài khoản',
        () async {
      // Lần 1: tài khoản đã tạo, đăng nhập được, nhưng /users/me mất mạng.
      server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();
      server.acceptLogin(userId: 'u1', name: 'An', refresh: 'r1');
      server.routes['GET /users/me'] =
          (req) => throw http.ClientException('offline', req.url);
      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.network),
      );
      expect(auth.current, const SignedOut());

      // Lần 2: server báo email đã có — nhưng đó chính là tài khoản vừa tạo.
      server.routes['POST /users/register'] =
          (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
      server.acceptLogin(userId: 'u1', name: 'An', refresh: 'r1');

      await auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123');

      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));
    });

    test('server báo email trùng và mật khẩu không khớp thì emailTaken', () async {
      server.routes['POST /users/register'] =
          (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
      server.routes['POST /auth/login'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.emailTaken),
      );
    });

    test('mật khẩu dưới 8 ký tự bị chặn trước khi gửi', () async {
      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: '1234567'),
        throwsA(AuthFailure.weakPassword),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('phiên', () {
    Future<void> signedIn() async {
      server.acceptLogin(refresh: 'r1', expiresMs: 15 * 60 * 1000);
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.requests.clear();
    }

    test('token còn hạn thì không làm mới', () async {
      await signedIn();

      expect(await auth.accessToken(), 'access-r1');
      expect(server.requests, isEmpty);
    });

    test('token sắp hết hạn thì làm mới và lưu refresh token mới', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 14, seconds: 30));
      server.routes['POST /auth/refresh'] = (req) {
        expect(FakeDirectus.body(req)['refresh_token'], 'r1');
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      expect(await auth.accessToken(), 'access-r2');
      expect(store.session?.refreshToken, 'r2');
    });

    test('hai lời gọi cùng lúc chỉ làm mới một lần', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      final a = auth.accessToken();
      final b = auth.accessToken();
      gate.complete();

      expect(await Future.wait([a, b]), ['access-r2', 'access-r2']);
      expect(server.sent('POST', '/auth/refresh'), hasLength(1));
    });

    test('server từ chối phiên thì tự đăng xuất, kèm expired', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut(expired: true));
      expect(store.session, isNull);
    });

    test('mất mạng lúc làm mới thì vẫn đăng nhập, phiên còn nguyên', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      server.offline = true;

      await expectLater(auth.accessToken(), throwsA(AuthFailure.network));
      expect(auth.current, isA<SignedIn>());
      expect(store.session?.refreshToken, 'r1');
    });

    test('401 nhưng máy đã có token mới hơn thì thử lại bằng token đó', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      // Tab khác vừa xoay token: r1 đã chết, r2 là token hiện hành trên máy.
      server.routes['POST /auth/refresh'] = (req) {
        final used = FakeDirectus.body(req)['refresh_token'];
        if (used == 'r1') {
          store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2');
          return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
        }
        return FakeDirectus.ok({'access_token': 'access-r3', 'expires': 900000, 'refresh_token': 'r3'});
      };

      expect(await auth.accessToken(), 'access-r3');
      expect(auth.current, isA<SignedIn>());
      expect(store.session?.refreshToken, 'r3');
    });

    test('làm mới đang chạy dở mà người chơi đăng xuất thì phiên không sống lại',
        () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      final tokenFuture = auth.accessToken(); // refresh in flight
      await pumpEventQueue(); // ensure refresh has started
      await auth.signOut();
      gate.complete();

      await expectLater(tokenFuture, throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });

    test('làm mới của người cũ không đè phiên người mới', () async {
      // A signs in
      await signedIn();
      now = now.add(const Duration(minutes: 20));

      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      final aToken = auth.accessToken(); // A's refresh in flight
      await pumpEventQueue();
      await auth.signOut(); // A signs out

      // B signs in
      server.acceptLogin(userId: 'u2', name: 'B', refresh: 'rB');
      await auth.signIn(email: 'b@example.com', password: 'matkhau123');

      gate.complete(); // A's refresh returns

      await expectLater(aToken, throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'B'));
      expect(store.session?.refreshToken, 'rB');
    });

    test(
        'refresh trả về sau khi signOut bắt đầu chờ clear thì không '
        'khôi phục phiên đã xoá', () async {
      // Signed in with an expiring token.
      server.acceptLogin(refresh: 'r1', expiresMs: 15 * 60 * 1000);
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));
      server.requests.clear();

      // Deferred store: clear() and write() block until we release them.
      final deferredStore = DeferredInMemorySessionStore();
      // Fresh copy so deferredStore is completely independent of store.
      deferredStore.session = StoredSession(
        userId: store.session!.userId,
        displayName: store.session!.displayName,
        refreshToken: store.session!.refreshToken,
      );
      final deferredAuth = DirectusAuthRepository(
        api: DirectusClient(
          client: server.client,
          baseUrl: FakeDirectus.baseUrl,
        ),
        sessions: deferredStore,
        resetUrl: resetUrl,
        now: () => now,
      );
      await deferredAuth.restore();

      final refreshGate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await refreshGate.future;
        return FakeDirectus.ok(
          {'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'},
        );
      };

      // Capture the refresh future BEFORE starting signOut so we can register
      // the expectLater expectation before either future resolves.
      final tokenFuture = deferredAuth.accessToken();
      await pumpEventQueue();

      // Attach the expectation early — before releasing any gates.
      final tokenExpectation = expectLater(
        tokenFuture,
        throwsA(AuthFailure.sessionExpired),
      );

      // Start signOut; it bumps gen, then blocks inside clear().
      final signOutDone = deferredAuth.signOut();
      await pumpEventQueue();

      // Release the refresh response so the refresh handler returns.
      refreshGate.complete();

      // Release write() FIRST — it queues a microtask (pending write to r2).
      // Then pump: gen bumps to 2 while write is queued. Then release clear().
      // Fixed: write fires with gen=1, but gen check (gen != 1) rejects it.
      // Buggy: write fires with gen=2, gen check passes, session = r2 → FAIL.
      deferredStore.releaseWrite();
      await pumpEventQueue();
      deferredStore.releaseClear();
      await pumpEventQueue();

      // Session must be gone — no silent re-sign-in on restore().
      expect(deferredStore.session, isNull);
      expect(deferredAuth.current, const SignedOut());
      await tokenExpectation;
      await signOutDone;
    });

    // Lượt A (phiên r1) còn chờ server thì người chơi đăng xuất rồi đăng
    // nhập lại (r2) và lượt B bắt đầu. A về muộn không được xoá chỗ giữ
    // lượt đang chạy của B: lời gọi C sau đó phải dùng chung B.
    test('lượt làm mới cũ về muộn không phá "chỉ làm mới một lần" của phiên mới',
        () async {
      final gateR1 = Completer<void>();
      final gateR2 = Completer<void>();
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] = (req) async {
        if (FakeDirectus.body(req)['refresh_token'] == 'r1') {
          await gateR1.future;
          return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
        }
        await gateR2.future;
        return FakeDirectus.ok(
          {'access_token': 'access-r3', 'expires': 900000, 'refresh_token': 'r3'},
        );
      };

      final a = auth.accessToken();
      final aDone = expectLater(a, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();

      await auth.signOut();
      server.acceptLogin(refresh: 'r2');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));

      final b = auth.accessToken();
      await pumpEventQueue();
      gateR1.complete();
      await aDone;

      final c = auth.accessToken();
      await pumpEventQueue();
      gateR2.complete();

      expect(await b, 'access-r3');
      expect(await c, 'access-r3');
      expect(
        server
            .sent('POST', '/auth/refresh')
            .map((r) => FakeDirectus.body(r)['refresh_token']),
        ['r1', 'r2'],
      );
      expect(auth.current, isA<SignedIn>());
    });

    // Lượt A bắt đầu làm mới, giữ token mới (chưa bump gen). Người chơi
    // đăng nhập lại trong lúc A đang chờ /users/me. A về muộn không đè
    // token mới vì bump gen đã xảy ra giữa lúc A nhận kết quả refresh và
    // lúc nó ghi phiên.
    test('đăng nhập lại khi đang đăng nhập: lượt làm mới cũ không đè token mới',
        () async {
      await signedIn(); // u1, r1
      now = now.add(const Duration(minutes: 20));
      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok(
            {'access_token': 'access-cu', 'expires': 900000, 'refresh_token': 'r-cu'});
      };
      final old = auth.accessToken();
      final oldDone = expectLater(old, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();

      // Lượt cũ phải về đúng lúc signIn đang chờ /users/me — chỗ mã cũ đã
      // giữ token mới nhưng chưa đổi thế hệ.
      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'rB');
      final meGate = Completer<void>();
      server.routes['GET /users/me'] = (_) async {
        await meGate.future;
        return FakeDirectus.ok({'id': 'u2', 'first_name': 'Bình'});
      };
      final b = auth.signIn(email: 'binh@example.com', password: 'matkhau123');
      await pumpEventQueue(); // /auth/login xong, đang chờ /users/me
      gate.complete();
      await pumpEventQueue(); // lượt cũ về
      meGate.complete();
      await b;
      await oldDone;

      expect(await auth.accessToken(), 'access-rB');
      expect(store.session?.refreshToken, 'rB');
    });

    // Lượt cũ bị 401 rồi đứng ở lần đọc phiên sau 401 — lần đọc cuối cùng
    // trước khi quyết định hết hạn. Trong lúc đó người chơi đăng xuất và
    // đăng nhập tài khoản khác: lượt cũ không được tự đăng xuất tài khoản mới.
    test('lượt làm mới cũ bị 401 về muộn không đá phiên của lần đăng nhập mới',
        () async {
      final gated = GatedReadSessionStore();
      store = gated;
      auth = build();
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));

      final gate401 = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate401.future;
        return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
      };

      final a = auth.accessToken();
      final aDone = expectLater(a, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();

      // Lần đọc sau 401 (tìm token mới hơn) chụp r1 rồi đứng chờ.
      gated.gate = Completer<void>();
      final held = gated.gate!;
      gate401.complete();
      await pumpEventQueue();

      await auth.signOut();
      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'r2');
      await auth.signIn(email: 'binh@example.com', password: 'matkhau123');

      held.complete();
      await aDone;
      await pumpEventQueue();

      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'Bình'));
      expect(gated.session?.refreshToken, 'r2');
    });

    test('token mới hơn cũng bị từ chối thì hết hạn ngay, không tốn thêm lượt network',
        () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      // Tab khác vừa xoay: r1 → r2 before first refresh attempt (store already updated)
      store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2');
      server.routes['POST /auth/refresh'] = (req) {
        final used = FakeDirectus.body(req)['refresh_token'];
        // First call uses r2 (token rotated before refresh started)
        // Retry also gets a different token r3 from another tab rotation
        if (used == 'r2') {
          store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r3');
          return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
        }
        // Second retry uses r3 but that also fails on server
        return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
      };

      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut(expired: true));
      expect(store.session, isNull);
    });

    test('tab khác đã đăng xuất (máy hết phiên) thì SignedOut thường, không expired',
        () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      store.session = null; // tab khác xoá phiên trên máy dùng chung

      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut());
    });

    test('401 mà tab khác vừa đăng xuất thì SignedOut thường, không expired',
        () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] = (_) {
        store.session = null; // tab khác đăng xuất trong lúc chờ server
        return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
      };

      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut());
    });

    test('lượt làm mới cũ về muộn sau khi đổi người thì báo sessionExpired, không network',
        () async {
      // Mã cũ đọc phiên ba lần: lấy r1, tìm token mới hơn sau 401 (có kiểm
      // thế hệ), rồi đọc lần ba trước khi hết hạn — lần này **không** kiểm
      // thế hệ. Giữ đúng lần thứ ba, và trả giá trị **lúc đọc xong** (phiên
      // của Bình), để mã cũ thấy token "khác" và báo network.
      final gated = LiveGatedReadSessionStore();
      store = gated;
      auth = build();
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');
      gated
        ..skip = 2
        ..gate = Completer<void>();
      final held = gated.gate!;

      final a = auth.accessToken();
      final aDone = expectLater(a, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();
      // Mã mới chỉ đọc hai lần nên cổng còn nguyên: gỡ đi, kẻo lần đọc của
      // signOut dưới đây đứng chờ mãi. Với mã cũ cổng đã được dùng rồi.
      gated.gate = null;
      await auth.signOut();
      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'rB');
      await auth.signIn(email: 'binh@example.com', password: 'matkhau123');
      held.complete();
      await aDone;

      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'Bình'));
    });

    test('đăng xuất lúc làm mới đang về: báo server bỏ cả token vừa xoay', () async {
      await signedIn(); // r1
      now = now.add(const Duration(minutes: 20));
      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok(
            {'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };
      server.routes['POST /auth/logout'] = (_) => FakeDirectus.noContent();

      final t = auth.accessToken();
      final tDone = expectLater(t, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();
      await auth.signOut();
      gate.complete();
      await tDone;
      await pumpEventQueue();

      final revoked = server
          .sent('POST', '/auth/logout')
          .map((r) => FakeDirectus.body(r)['refresh_token'])
          .toSet();
      expect(revoked, {'r1', 'r2'});
    });

    test('đăng nhập chen vào lúc tự đăng xuất đang xoá phiên thì phiên mới sống',
        () async {
      final serial = SerialGatedSessionStore();
      store = serial;
      auth = build();
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      final a = auth.accessToken();
      final aDone = expectLater(a, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue(); // _expire đang đứng trong clear()

      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'rB');
      final b = auth.signIn(email: 'binh@example.com', password: 'matkhau123');
      await pumpEventQueue(); // write của Bình xếp hàng sau clear
      serial.clearGate.complete();
      await b;
      await aDone;
      await pumpEventQueue();

      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'Bình'));
      expect(serial.session?.refreshToken, 'rB');
      // Nếu _expire lỡ chạy tiếp, nó xoá access token của Bình: lần xin
      // token này sẽ đi làm mới và dính 401 thay vì trả ngay.
      expect(await auth.accessToken(), 'access-rB');
    });

    // signIn giữ token của người mới rồi mới chờ ghi phiên. Một lượt làm mới
    // bắt đầu sau lần đổi thế hệ đầu (lúc signIn còn chờ /users/me) mà về
    // đúng lúc signIn đang chờ ghi thì không được đè token và phiên mới.
    test('lượt làm mới về lúc đăng nhập mới đang ghi phiên thì không đè phiên mới',
        () async {
      final deferred = DeferredInMemorySessionStore()
        ..session =
            const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1');
      store = deferred;
      auth = build();
      await auth.restore(); // An, chưa có access token: xin token là làm mới

      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'rB');
      final meGate = Completer<void>();
      server.routes['GET /users/me'] = (_) async {
        await meGate.future;
        return FakeDirectus.ok({'id': 'u2', 'first_name': 'Bình'});
      };
      final refreshGate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await refreshGate.future;
        return FakeDirectus.ok(
            {'access_token': 'access-cu', 'expires': 900000, 'refresh_token': 'r-cu'});
      };

      final b = auth.signIn(email: 'binh@example.com', password: 'matkhau123');
      await pumpEventQueue(); // /auth/login xong, đang chờ /users/me

      // Vẫn SignedIn(An): lượt này bắt đầu sau lần đổi thế hệ đầu của signIn.
      final old = auth.accessToken();
      final oldDone = expectLater(old, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue(); // đang chờ /auth/refresh

      meGate.complete();
      await pumpEventQueue(); // signIn đã giữ token của Bình, đang chờ ghi
      refreshGate.complete();
      await pumpEventQueue(); // lượt cũ về trong lúc signIn còn chờ ghi

      deferred.releaseWrite();
      await b;
      await oldDone;
      await pumpEventQueue();

      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'Bình'));
      expect(await auth.accessToken(), 'access-rB');
      expect(deferred.session?.refreshToken, 'rB');
    });

    // Drift trên web là một DB chung cho mọi tab. Tab 2 đăng xuất An rồi
    // đăng nhập Bình: tab 1 (vẫn SignedIn(An)) làm mới sẽ đọc phiên của
    // Bình. Dùng nó là đẩy buổi tập của An bằng token của Bình.
    group('phiên trên máy là của người khác', () {
      const binh =
          StoredSession(userId: 'u2', displayName: 'Bình', refreshToken: 'rB');

      void expectBinhUntouched() {
        expect(store.session?.userId, 'u2');
        expect(store.session?.displayName, 'Bình');
        expect(store.session?.refreshToken, 'rB');
      }

      test('lúc bắt đầu làm mới thì đăng xuất, không gửi token của họ, '
          'không xoá phiên của họ', () async {
        await signedIn(); // An, r1
        now = now.add(const Duration(minutes: 20));
        store.session = binh; // tab khác vừa đăng nhập Bình
        server.routes['POST /auth/refresh'] = (_) => FakeDirectus.ok(
            {'access_token': 'access-rB2', 'expires': 900000, 'refresh_token': 'rB2'});

        await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
        expect(auth.current, const SignedOut());
        expect(server.sent('POST', '/auth/refresh'), isEmpty);
        expectBinhUntouched();
      });

      test('sau 401 thì đăng xuất, không thử token của họ, không xoá phiên của họ',
          () async {
        await signedIn(); // An, r1
        now = now.add(const Duration(minutes: 20));
        server.routes['POST /auth/refresh'] = (req) {
          if (FakeDirectus.body(req)['refresh_token'] == 'r1') {
            store.session = binh; // tab khác đổi người trong lúc chờ server
            return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
          }
          return FakeDirectus.ok(
              {'access_token': 'access-rB2', 'expires': 900000, 'refresh_token': 'rB2'});
        };

        await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
        expect(auth.current, const SignedOut());
        expect(server.sent('POST', '/auth/refresh'), hasLength(1));
        expectBinhUntouched();
      });

      // Đã thử đủ số token cho một lượt: nếu kiểm "hết lượt" trước, An vẫn
      // đăng nhập và chỉ nhận network, dù máy đã là của Bình.
      test('sau 401 cuối lượt vẫn đăng xuất ngay, không báo network', () async {
        await signedIn(); // An, r1
        now = now.add(const Duration(minutes: 20));
        server.routes['POST /auth/refresh'] = (req) {
          store.session = switch (FakeDirectus.body(req)['refresh_token']) {
            'r1' => const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2'),
            'r2' => const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r3'),
            _ => binh,
          };
          return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
        };

        await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
        expect(auth.current, const SignedOut());
        expect(
          server
              .sent('POST', '/auth/refresh')
              .map((r) => FakeDirectus.body(r)['refresh_token']),
          ['r1', 'r2', 'r3'],
        );
        expectBinhUntouched();
      });
    });

    // signIn(Bình) đang chờ ghi phiên, trạng thái vẫn là SignedIn(An). Ai
    // xin token lúc này đang làm việc cho An — không được nhận token của Bình,
    // và cũng không được đi làm mới phiên An rồi ghi đè phiên Bình.
    test('đang ghi phiên của lần đăng nhập mới thì người cũ không nhận token mới',
        () async {
      final deferred = DeferredInMemorySessionStore()
        ..session =
            const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1');
      store = deferred;
      auth = build();
      await auth.restore(); // SignedIn(An)

      server.acceptLogin(userId: 'u2', name: 'Bình', refresh: 'rB');
      server.routes['POST /auth/refresh'] = (_) => FakeDirectus.ok(
          {'access_token': 'access-cu', 'expires': 900000, 'refresh_token': 'r-cu'});

      final b = auth.signIn(email: 'binh@example.com', password: 'matkhau123');
      await pumpEventQueue(); // signIn đang đứng trong write()
      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));

      final old = auth.accessToken();
      final oldDone = expectLater(old, throwsA(AuthFailure.sessionExpired));
      await pumpEventQueue();

      deferred.releaseWrite();
      await b;
      await oldDone;
      await pumpEventQueue();

      expect(server.sent('POST', '/auth/refresh'), isEmpty);
      expect(auth.current, const SignedIn(userId: 'u2', displayName: 'Bình'));
      expect(deferred.session?.refreshToken, 'rB');
      expect(await auth.accessToken(), 'access-rB');
    });

    test('khôi phục phiên không cần mạng', () async {
      store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1');
      server.offline = true;

      await auth.restore();

      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));
      expect(server.requests, isEmpty);
    });

    test('chưa đăng nhập mà xin token thì sessionExpired', () async {
      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
    });
  });

  group('đăng xuất do người chơi bấm', () {
    test('báo server, xoá phiên, không kèm expired', () async {
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.routes['POST /auth/logout'] = (_) => FakeDirectus.noContent();

      await auth.signOut();
      await pumpEventQueue(); // báo server chạy nền, sau khi đã đăng xuất

      expect(FakeDirectus.body(server.sent('POST', '/auth/logout').single)['refresh_token'], 'r1');
      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });

    test('đã SignedOut trước khi server trả lời /auth/logout', () async {
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      final gate = Completer<void>();
      server.routes['POST /auth/logout'] = ((_) async {
        await gate.future;
        return FakeDirectus.noContent();
      });

      final changes = <AuthState>[];
      auth.watchSession().listen(changes.add);

      final done = auth.signOut();
      await pumpEventQueue();

      // Server còn treo mà máy đã đăng xuất xong.
      expect(server.sent('POST', '/auth/logout'), hasLength(1));
      expect(auth.current, const SignedOut());
      expect(changes, [const SignedOut()]);
      expect(store.session, isNull);

      gate.complete();
      await done;
    });

    test('server trả lỗi lạ lúc logout cũng không ném', () async {
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.routes['POST /auth/logout'] =
          ((_) => FakeDirectus.error(500, 'INTERNAL'));

      await auth.signOut();
      await pumpEventQueue();

      expect(auth.current, const SignedOut());
    });

    test('mất mạng vẫn đăng xuất được trên máy', () async {
      server.acceptLogin();
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.offline = true;

      await auth.signOut();

      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });
  });

  group('quên và đặt lại mật khẩu', () {
    test('gửi email đã chuẩn hoá kèm reset_url', () async {
      server.routes['POST /auth/password/request'] = (_) => FakeDirectus.noContent();

      await auth.requestPasswordReset(' An@Example.com ');

      final body = FakeDirectus.body(server.sent('POST', '/auth/password/request').single);
      expect(body, {'email': 'an@example.com', 'reset_url': 'https://app.test/reset-password'});
    });

    test('mất mạng thì network', () async {
      server.offline = true;

      await expectLater(auth.requestPasswordReset('an@example.com'), throwsA(AuthFailure.network));
    });

    test('link hết hạn hoặc đã dùng thì resetLinkInvalid', () async {
      for (final status in [401, 403]) {
        server.routes['POST /auth/password/reset'] =
            (_) => FakeDirectus.error(status, 'INVALID_TOKEN');

        await expectLater(
          auth.resetPassword(token: 't', password: 'matkhau123'),
          throwsA(AuthFailure.resetLinkInvalid),
        );
      }
    });

    test('mật khẩu mới dưới 8 ký tự bị chặn trước khi gửi', () async {
      await expectLater(
        auth.resetPassword(token: 't', password: 'ngan'),
        throwsA(AuthFailure.weakPassword),
      );
      expect(server.requests, isEmpty);
    });

    test('đặt lại thành công không tự đăng nhập', () async {
      server.routes['POST /auth/password/reset'] = (_) => FakeDirectus.noContent();

      await auth.resetPassword(token: 't', password: 'matkhau123');

      expect(auth.current, const SignedOut());
    });
  });
}
