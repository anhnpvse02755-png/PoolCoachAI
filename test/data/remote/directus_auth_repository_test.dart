import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_directus.dart';
import '../../support/in_memory_session_store.dart';

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

    test('server báo email trùng thì emailTaken', () async {
      server.routes['POST /users/register'] =
          (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');

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

    test('401 lần thử lại nhưng máy đã có token khác thì không xoá phiên', () async {
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

      await expectLater(auth.accessToken(), throwsA(AuthFailure.network));
      expect(auth.current, isA<SignedIn>());
      expect(store.session?.refreshToken, 'r3'); // store unchanged (not cleared)
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
