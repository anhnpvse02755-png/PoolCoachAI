# Accounts & sync follow-ups — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every item parked in `docs/superpowers/logs/2026-09-24-accounts-sync-followups.md`, so accounts and sync have no known open defects.

**Architecture:** Most fixes are local to `DirectusAuthRepository` (session generation and refresh loop) and `SyncService` (pass loop, lifecycle). One small feature is new: Profile shows drill logs that can never sync (a non-finite score) and lets the player discard them. The Directus tooling fixes finish with a real run of `bootstrap.mjs` + `verify.mjs` against a throwaway Postgres + Directus in Easypanel project `test-va`. Those services are deleted afterwards.

**Tech Stack:** Flutter 3.47 / Dart, Riverpod (no codegen), Drift, `package:http` MockClient via `test/support/fake_directus.dart`; Node 26 scripts for Directus 12.3.1; Easypanel MCP.

**Spec:** `docs/superpowers/specs/2026-09-23-poolcoachai-accounts-sync-design.md` (spec §5.4 = sign-out rules), plus the follow-up log above.

## Global Constraints

- All UI text is Vietnamese and lives in `lib/core/strings/vi.dart`. Never show raw server errors.
- Automatic sign-out never deletes drill logs. Only a user-pressed sign-out (`signOutAndForget`) deletes them (spec §5.4).
- Losing the network is never a reason to sign out.
- `SyncService.syncNow()` never throws.
- Riverpod without codegen. Tests override providers with `overrideWithValue`/`overrideWith` and never with an explicitly typed override list. The typed list crashes the compiler (memory: riverpod-drift-test-patterns).
- Flutter is not on PATH. Use `C:\Users\anhnpv\flutter\bin\flutter.bat` / `dart.bat`.
- Every race test must be *discriminating*: revert the fix and watch the test go RED before committing it.
- Comments in the style of the surrounding code: Vietnamese, explaining *why*.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. A player who registers, loses the network at `/users/me`, then taps Register again. They must end up signed in to their own account, not see "email đã có tài khoản" (Task 1).
2. A tab signs out while another tab's refresh is mid-flight. The survivor must show a plain sign-out, not "phiên hết hạn" (Task 2).
3. A player with an old ∞-score log taps "Đồng bộ trước" forever. Profile must show them the way out (Task 4).
4. A log saved while a pass hits a rejected row must not wait 30 s (Task 3).
5. A fresh Directus server built only from `bootstrap.mjs` must pass `verify.mjs` (Task 7).

---

## File map

| File | Change |
|---|---|
| `lib/data/remote/directus_auth_repository.dart` | signIn generation + deferred tokens; register retry; refresh loop rewrite; `_expire(expired:)`; revoke rotated token |
| `test/data/remote/directus_auth_repository_test.dart` | new tests; one existing test's expectation changes (Task 2) |
| `lib/data/sync/sync_service.dart` | loop continues after row rejection; `start()` guard; `dispose()` stops pass; `SyncOutcome.stopped` |
| `lib/core/providers/auth_providers.dart` | provider starts the service it builds |
| `lib/core/bootstrap.dart`, `lib/main.dart` | `startSync(container)` |
| `test/data/sync/sync_service_test.dart`, `test/core/providers/sync_provider_test.dart` (new), `test/core/bootstrap_test.dart` | tests |
| `lib/data/sync/account_actions.dart` | `isUnsyncable`, `watchUnsyncableCount`, `discardUnsyncableLogs` |
| `lib/core/providers/auth_providers.dart` | `unsyncableCountProvider` |
| `lib/features/profile/presentation/profile_screen.dart`, `lib/core/strings/vi.dart` | notice + discard |
| `test/data/sync/account_actions_test.dart`, `test/features/profile/profile_screen_test.dart` | tests |
| `test/app_test.dart`, `test/data/database/converters_test.dart` | hygiene |
| `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` | licence detection; stricter asserts |
| `docs/superpowers/logs/2026-09-24-accounts-sync-followups.md` | mark every item closed |

Item → task map (24 items in the log):

| Log item | Task |
|---|---|
| signIn bumps generation late | 1 |
| signIn takes tokens before `/users/me`; register retry → emailTaken | 1 |
| stale rotated refresh reports `network` | 2 |
| empty store while SignedIn → `expired: true` | 2 |
| retry-path compares to first token | 2 |
| signOut racing refresh success leaves new token valid | 2 |
| `_expire` ordering has no test | 2 |
| log saved during a rejected pass waits 30 s | 3 |
| `start()` guard / `dispose()` in-flight / provider rebuild unstarted | 3 |
| bootstrap test: `restoreSession(` before `runApp(` | 3 |
| ∞-score rows have no discard UI | 4 |
| no test pins the primary sign-out dialog action | 4 |
| `app_test` implicit signed-in auth | 5 |
| `converters_test` shadows `db` | 5 |
| licence detection via `display_powered_by` | 6 |
| `env.example` lacks `DIRECTUS_LICENSE_KEY` | **already done** (lines 44–48). Task 8 records it |
| `verify.mjs` short-password accepts any ≥400 | 6 |
| `verify.mjs` forged `user_created` NOTE before assert | 6 |
| bootstrap create branches never run on a clean server | 7 |

---

### Task 1: Sign-in owns its generation; register survives a retry

**Files:**
- Modify: `lib/data/remote/directus_auth_repository.dart:55-132`
- Test: `test/data/remote/directus_auth_repository_test.dart` (groups `đăng ký`, `phiên`)

**Interfaces:** Produces the unchanged `AuthRepository` API. Internally, `signIn` bumps `_gen` at its start *and* after writing the session, and it nulls `_refreshing`.

- [ ] **Step 1: Write the failing tests**

Add to group `đăng ký`:

```dart
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
```

Replace the existing test `server báo email trùng thì emailTaken` with:

```dart
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
```

Add to group `đăng nhập`:

```dart
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
```

Add to group `phiên`. This test pins the observation-3804 race:

```dart
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
```

Add `import 'package:http/http.dart' as http;` to the test file if it is missing.

- [ ] **Step 2: Run to verify they fail**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/remote/directus_auth_repository_test.dart`
Expected: the register retry test fails with `emailTaken`. The `/users/me` test fails with `access-r1` ≠ `access-r0b`. The re-sign-in test fails because the old refresh wrote `r-cu` / `access-cu` while `signIn` was waiting on `/users/me`. If it passes on the old code, the interleave is wrong: fix the test before touching production code.

- [ ] **Step 3: Implement**

In `register`, a `RECORD_NOT_UNIQUE` is no longer final. Sign-in decides:

```dart
    } on DirectusError catch (e) {
      // Email đã có chủ — có thể chính là người này, từ lần đăng ký trước
      // hỏng mạng sau khi tài khoản đã tạo. Đăng nhập thử bên dưới quyết định.
      if (e.code != 'RECORD_NOT_UNIQUE') {
        throw e.code == 'FAILED_VALIDATION'
            ? AuthFailure.weakPassword
            : AuthFailure.unknown;
      }
    }
```

(The following `signIn` try/catch already maps `wrongCredentials → emailTaken`. Keep it.)

Rewrite `signIn`:

```dart
  @override
  Future<void> signIn({required String email, required String password}) async {
    // Phiên cũ (nếu có) hết hiệu lực ngay từ đây: một lượt làm mới của nó
    // về muộn thấy thế hệ đã đổi và bỏ kết quả, không đè token mới.
    _bumpGen();
    _refreshing = null;

    final Map<String, Object?> tokens;
    try {
      tokens = await _api.post('/auth/login', body: {
        'email': _normalize(email),
        'password': password,
        'mode': 'json',
      }) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw e.status == 401 ? AuthFailure.wrongCredentials : AuthFailure.unknown;
    }

    // Chưa giữ token cho tới khi biết là của ai: /users/me hỏng thì lần
    // đăng nhập này coi như chưa từng có.
    final Map<String, Object?> me;
    try {
      me = await _api.get(
        '/users/me',
        token: tokens['access_token']! as String,
        query: {'fields': 'id,first_name'},
      ) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError {
      throw AuthFailure.unknown;
    }

    final session = StoredSession(
      userId: me['id']! as String,
      displayName: (me['first_name'] as String?) ?? '',
      refreshToken: tokens['refresh_token']! as String,
    );
    _takeTokens(tokens);
    await _sessions.write(session);
    // Lần nữa sau khi ghi: lượt làm mới bắt đầu giữa chừng (đọc phiên cũ)
    // cũng không được ghi đè phiên vừa lưu.
    _bumpGen();
    _emit(SignedIn(userId: session.userId, displayName: session.displayName));
  }
```

- [ ] **Step 4: Run to verify they pass, and that the whole file is green**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/remote/directus_auth_repository_test.dart`
Expected: all PASS.

- [ ] **Step 5: Discrimination check**

Temporarily delete the first `_bumpGen(); _refreshing = null;` in `signIn`. Run the re-sign-in test and confirm it goes RED. Restore it. Then move `_takeTokens(tokens);` back above `/users/me` and confirm the `/users/me` test goes RED. Restore.

- [ ] **Step 6: Commit**

```bash
git add lib/data/remote/directus_auth_repository.dart test/data/remote/directus_auth_repository_test.dart
git commit -m "Let sign-in own its session generation, and let a retried register reach the account it made"
```

---

### Task 2: One refresh loop — try each newer token once, expire on the token just rejected

**Files:**
- Modify: `lib/data/remote/directus_auth_repository.dart:159-237` (`_refresh`, `_expire`)
- Test: `test/data/remote/directus_auth_repository_test.dart` (group `phiên`, plus a new `SerialGatedSessionStore` helper at the top of the file)

**Interfaces:** Consumes Task 1's `signIn`. Changes `_expire({required int ifGen})` to `_expire({required int ifGen, required bool expired})`.

- [ ] **Step 1: Write the failing tests**

Change the expectation of the existing test `401 lần thử lại nhưng máy đã có token khác thì không xoá phiên`. With r3 tried and rejected, and the store still holding r3, the session is dead. Rename it and update the tail:

```dart
    test('token mới hơn cũng bị từ chối thì hết hạn ngay, không tốn thêm lượt network',
        () async {
      // ...same arrange as before...
      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut(expired: true));
      expect(store.session, isNull);
    });
```

Add:

```dart
    test('tab khác đã đăng xuất (máy hết phiên) thì SignedOut thường, không expired',
        () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      store.session = null; // tab khác xoá phiên trên máy dùng chung

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
```

Add this helper next to `GatedReadSessionStore`. The new code reads only twice, so its gate never engages and the test checks the plain contract. Run it on the **old** code first and confirm it is RED (`network`):

```dart
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
```

Also add a second helper next to `GatedReadSessionStore`. It is a first-in-first-out store, like Drift's serialised queue, with a gate on `clear()`:

```dart
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
```

And this test, which covers `_expire`'s post-clear generation check:

```dart
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
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/remote/directus_auth_repository_test.dart`
Expected: the renamed test fails (`network`). The empty-store test fails (`expired: true`). The stale-network test fails (`network`). The revoke test fails (`{r1}`). The `_expire` interleave test may already pass, because it is defence in depth. That is expected; Step 5 proves it discriminates.

- [ ] **Step 3: Implement**

Replace `_refresh` and `_expire`:

```dart
  /// Mỗi lượt làm mới thử tối đa ngần này refresh token khác nhau.
  static const _maxRefreshTokens = 3;

  Future<String> _refresh() async {
    // Lấy thế hệ trước lần chờ đầu tiên: mọi kết luận của lượt này (ghi
    // phiên, hay đăng xuất vì hết hạn) chỉ có hiệu lực nếu phiên chưa đổi.
    // Kiểm lại sau **mỗi** lần chờ — lượt cũ về muộn luôn là sessionExpired.
    final startGen = _gen;
    void stillCurrent() {
      if (_gen != startGen) throw AuthFailure.sessionExpired;
    }

    final tried = <String>{};
    var saved = await _sessions.read();
    stillCurrent();
    while (true) {
      if (saved == null) {
        // Máy hết phiên mà server chưa từ chối gì: tab khác đã đăng xuất.
        await _expire(ifGen: startGen, expired: false);
        throw AuthFailure.sessionExpired;
      }
      final used = saved.refreshToken;
      tried.add(used);

      final Map<String, Object?> tokens;
      try {
        tokens = await _api.post('/auth/refresh', body: {
          'refresh_token': used,
          'mode': 'json',
        }) as Map<String, Object?>;
      } on DirectusUnreachable {
        // Mất mạng không bao giờ là lý do đăng xuất.
        throw AuthFailure.network;
      } on DirectusError catch (e) {
        if (e.status != 401 && e.status != 403) throw AuthFailure.unknown;
        stillCurrent();
        // Một tab khác có thể vừa xoay token. Máy đang cầm token chưa thử
        // thì thử token đó; còn cầm đúng token vừa bị từ chối thì phiên chết.
        final latest = await _sessions.read();
        stillCurrent();
        if (latest == null || latest.refreshToken == used) {
          await _expire(ifGen: startGen, expired: latest != null);
          throw AuthFailure.sessionExpired;
        }
        if (tried.contains(latest.refreshToken) ||
            tried.length >= _maxRefreshTokens) {
          // Các tab đang xoay token liên tục — để lần sau thử lại.
          throw AuthFailure.network;
        }
        saved = latest;
        continue;
      }

      final rotated = tokens['refresh_token']! as String;
      if (_gen != startGen) {
        // Server vừa xoay token cho một phiên đã bỏ: token mới này không ai
        // giữ, báo server bỏ luôn thay vì để nó sống 30 ngày.
        unawaited(_revoke(rotated));
        throw AuthFailure.sessionExpired;
      }
      _takeTokens(tokens);
      await _sessions.write(StoredSession(
        userId: saved.userId,
        displayName: saved.displayName,
        refreshToken: rotated,
      ));
      if (_gen != startGen) {
        unawaited(_revoke(rotated));
        throw AuthFailure.sessionExpired;
      }
      return _accessToken!;
    }
  }

  /// Tự động đăng xuất: chỉ bỏ phiên. **Không** động tới buổi tập nào —
  /// người chơi đăng nhập lại thì mọi thứ còn nguyên (spec mục 5.4).
  ///
  /// [ifGen] là thế hệ lượt refresh bắt đầu. Một lượt cũ về muộn — sau khi
  /// người chơi đã đăng xuất rồi đăng nhập lại — không được đá phiên mới.
  /// [expired] chỉ true khi server thật sự từ chối phiên: màn Đăng nhập
  /// dựa vào nó để nói "phiên hết hạn".
  Future<void> _expire({required int ifGen, required bool expired}) async {
    if (_gen != ifGen) return;
    _bumpGen();
    final mine = _gen;
    await _sessions.clear();
    if (_gen != mine) return;
    _accessToken = null;
    _accessExpiresAt = null;
    _emit(SignedOut(expired: expired));
  }
```

`_genStableRefresh` now calls `_refresh()` with no arguments, which is unchanged at the call site.

- [ ] **Step 4: Run to verify all pass**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/remote/directus_auth_repository_test.dart`
Expected: all PASS.

- [ ] **Step 5: Discrimination matrix**

Make each revert below, run the named test, see RED, then restore:

| Revert | Test that must go RED |
|---|---|
| `expired: latest != null` → `expired: true` in the saved==null path | `tab khác đã đăng xuất…` |
| (checked in Step 2 instead: the new code has no third read, so the test must be RED against the **pre-Task-2** code) | `lượt làm mới cũ về muộn sau khi đổi người…` |
| delete both `unawaited(_revoke(rotated));` | `đăng xuất lúc làm mới đang về…` |
| `latest.refreshToken == used` → `latest.refreshToken == tried.first` | `token mới hơn cũng bị từ chối…` |
| delete `if (_gen != mine) return;` in `_expire` | `đăng nhập chen vào lúc tự đăng xuất…` |
| move `_bumpGen()` in `_expire` after `await _sessions.clear()` | `đăng nhập chen vào lúc tự đăng xuất…` |

If the last two do not go RED, redesign the interleave test until they do. Do not commit a non-discriminating test. Record the matrix outcome in the commit body.

- [ ] **Step 6: Full suite, then commit**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test`
Expected: all PASS.

```bash
git add lib/data/remote/directus_auth_repository.dart test/data/remote/directus_auth_repository_test.dart
git commit -m "Refresh tries each newer token once and expires on the one just rejected"
```

---

### Task 3: Sync keeps going after a rejected row, and has a real lifecycle

**Files:**
- Modify: `lib/data/sync/sync_service.dart`
- Modify: `lib/core/providers/auth_providers.dart:65-74`, `lib/core/bootstrap.dart`, `lib/main.dart`
- Test: `test/data/sync/sync_service_test.dart`, `test/core/providers/sync_provider_test.dart` (new), `test/core/bootstrap_test.dart`

**Interfaces:**
- Produces `enum SyncOutcome { done, offline, signedOut, failed, stopped }`. `stopped` means the service was disposed.
- `SyncService.start()` is idempotent.
- `syncServiceProvider` returns an already-started service.
- `void startSync(ProviderContainer container)` goes in `lib/core/bootstrap.dart`.

- [ ] **Step 1: Write the failing tests**

In `sync_service_test.dart` group `một buổi hỏng không chặn cả hàng`:

```dart
    test('buổi mới ghi trong lượt có buổi bị từ chối thì đi luôn, không chờ 30 giây',
        () async {
      await addLog('xau');
      final gate = Completer<void>();
      server.routes['POST /items/drill_logs'] = (req) async {
        final id = FakeDirectus.body(req)['id'];
        if (id == 'xau') {
          await gate.future;
          return FakeDirectus.error(400, 'FAILED_VALIDATION');
        }
        return FakeDirectus.ok(jsonDecode(req.body));
      };

      final first = sync.syncNow();
      await pumpEventQueue();
      await addLog('moi');
      final second = sync.syncNow(); // đang chạy → hẹn thêm một lượt
      gate.complete();

      await first;
      await second;
      expect(pushedIds(), contains('moi'));
    });
```

(Add `import 'dart:async';` if it is missing.)

In group `tự chạy`:

```dart
    test('start hai lần không nhân đôi lượt chạy', () async {
      await addLog('a');
      sync
        ..start()
        ..start();
      await pumpEventQueue();
      await sync.syncNow();

      expect(pushedIds(), ['a']);
      expect(server.sent('GET', '/items/drill_logs').length, lessThanOrEqualTo(2));
    });

    test('dispose giữa lượt thì không ghi gì thêm vào máy', () async {
      final gate = Completer<void>();
      server.routes['GET /items/drill_logs'] = (_) async {
        await gate.future;
        return FakeDirectus.ok([
          {'id': 'tu-server', 'drill_id': 'd1', 'date': '2026-09-22T11:00:00.000Z', 'score': 5},
        ]);
      };

      final pass = sync.syncNow();
      await pumpEventQueue();
      sync.dispose();
      gate.complete();

      expect(await pass, SyncOutcome.stopped);
      expect(await db.select(db.drillLogRows).get(), isEmpty);
      expect(await sync.syncNow(), SyncOutcome.stopped);
    });
```

`tearDown` calls `sync.dispose()` again, so `dispose()` must be idempotent.

Create `test/core/providers/sync_provider_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  test('service dựng lại (provider rebuild) cũng tự chạy, không nằm im', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok([]));
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      directusClientProvider.overrideWithValue(
          DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl)),
    ]);
    addTearDown(container.dispose);

    final first = container.read(syncServiceProvider);
    await pumpEventQueue();
    container.invalidate(syncServiceProvider);
    final second = container.read(syncServiceProvider);
    server.requests.clear();
    await pumpEventQueue();

    expect(identical(first, second), isFalse);
    expect(server.sent('GET', '/items/drill_logs'), isNotEmpty,
        reason: 'service mới phải tự chạy một lượt ngay khi dựng');
  });
}
```

In `test/core/bootstrap_test.dart`, extend `main nạp seed xong mới dựng app`, or add a sibling test:

```dart
  test('main khôi phục phiên và bật đồng bộ trước khi dựng app', () {
    final source = File('lib/main.dart').readAsStringSync();
    final restoreAt = source.indexOf('await restoreSession(');
    final syncAt = source.indexOf('startSync(');
    final runAt = source.indexOf('runApp(');

    expect(restoreAt, isNonNegative);
    expect(restoreAt, lessThan(runAt),
        reason: 'router phải biết đã đăng nhập hay chưa ngay khung đầu');
    expect(syncAt, greaterThan(restoreAt),
        reason: 'đồng bộ chỉ có nghĩa sau khi biết người đang đăng nhập');
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/sync test/core`
Expected: `moi` is not pushed. `SyncOutcome.stopped` does not exist yet, which is a compile error. The provider test finds no GET. The bootstrap test finds no `startSync(`.

- [ ] **Step 3: Implement `SyncService`**

```dart
enum SyncOutcome {
  done,
  offline,
  signedOut,
  failed,

  /// Service đã dispose — lượt dừng, không ghi gì thêm.
  stopped,
}

/// Service bị dispose giữa lượt.
class _Stopped implements Exception {
  const _Stopped();
}
```

Add the fields `bool _started = false;` and `bool _disposed = false;`.

```dart
  void start() {
    if (_started || _disposed) return;
    _started = true;
    // ...existing body...
  }

  Future<SyncOutcome> syncNow() {
    if (_disposed) return Future.value(SyncOutcome.stopped);
    // ...existing body...
  }

  Future<SyncOutcome> _loop() async {
    ({SyncOutcome outcome, bool reachedEnd}) pass;
    do {
      _again = false;
      pass = await _once();
      // Lượt đi hết đẩy + kéo (kể cả khi có buổi bị từ chối) thì chạy lại
      // ngay cho buổi vừa ghi. Lượt đứt giữa chừng (mạng, phiên, 5xx) thì
      // chờ lần thử lại định kỳ.
    } while (_again && pass.reachedEnd && !_disposed);
    return pass.outcome;
  }
```

`_once` returns the record. The success path is `(outcome: anyRejected ? SyncOutcome.failed : SyncOutcome.done, reachedEnd: true)`. Every catch branch uses `reachedEnd: false`. Add `on _Stopped { return (outcome: SyncOutcome.stopped, reachedEnd: false); }` before `on Object`. Also add at the top of `_once`: `if (_disposed) return (outcome: SyncOutcome.stopped, reachedEnd: false);`.

Add a helper `void _checkAlive() { if (_disposed) throw const _Stopped(); }`. Call it:
- in `_push` at the top of each loop iteration, and after each `await _api.post(...)`;
- in `_pull` right after the `await _api.get(...)` (before `_stillSignedInAs`).

```dart
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
```

- [ ] **Step 4: Implement provider + bootstrap**

`auth_providers.dart`:

```dart
/// Service đã chạy sẵn: dựng lại (provider rebuild) thì bản mới cũng tự
/// chạy, không có lúc nào đồng bộ nằm im mà không ai hay.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  )..start();
  ref.onDispose(service.dispose);
  return service;
});
```

`bootstrap.dart`:

```dart
/// Bật đồng bộ nền suốt đời app. Gọi **sau** [restoreSession]: lượt đầu
/// cần biết ai đang đăng nhập. Màn hình chỉ đọc Drift.
void startSync(ProviderContainer container) {
  container.read(syncServiceProvider);
}
```

`main.dart`: replace the two lines `// Đồng bộ chạy nền…` and `container.read(syncServiceProvider).start();` with `startSync(container);`. Remove the now-unused import of `auth_providers.dart` if the analyzer flags it.

- [ ] **Step 5: Run to verify pass; analyze**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test` then `C:\Users\anhnpv\flutter\bin\flutter.bat analyze`
Expected: all PASS, no issues. The profile tests build `SyncService` directly and override the provider, so they never start timers.

- [ ] **Step 6: Discrimination check**

Revert `pass.reachedEnd` to `pass.outcome == SyncOutcome.done` and confirm the 30 s test goes RED. Remove the `_started` guard and confirm the double-start test goes RED; if it does not, tighten it to `expect(server.sent('GET', '/items/drill_logs'), hasLength(2))` after checking the real count. Remove `..start()` from the provider and confirm the provider test goes RED. Restore all three.

- [ ] **Step 7: Commit**

```bash
git add lib/data/sync/sync_service.dart lib/core/providers/auth_providers.dart lib/core/bootstrap.dart lib/main.dart test/data/sync/sync_service_test.dart test/core/providers/sync_provider_test.dart test/core/bootstrap_test.dart
git commit -m "Keep syncing after a rejected row, and give the sync service a real start and stop"
```

---

### Task 4: Profile shows logs that can never sync, and lets the player drop them

**Files:**
- Modify: `lib/data/sync/account_actions.dart`, `lib/core/providers/auth_providers.dart`, `lib/core/strings/vi.dart:236-244`, `lib/features/profile/presentation/profile_screen.dart`
- Test: `test/data/sync/account_actions_test.dart`, `test/features/profile/profile_screen_test.dart`

**Interfaces:**
- `bool isUnsyncable(DrillLogRow row)` returns true when `!row.score.isFinite`.
- `Stream<int> watchUnsyncableCount(AppDatabase db, String userId)`.
- `Future<void> discardUnsyncableLogs(AppDatabase db, String userId)`.
- `final unsyncableCountProvider = StreamProvider<int>(...)`. It yields 0 when signed out.

- [ ] **Step 1: Write the failing tests**

`account_actions_test.dart` follows that file's existing setUp. Read it first and reuse its db/insert helper names:

```dart
  group('buổi không đồng bộ được', () {
    test('chỉ đếm buổi chờ có điểm vô hạn của đúng người', () async {
      await insertLog('ok', userId: 'u1', score: 7);
      await insertLog('vo-han', userId: 'u1', score: double.infinity);
      await insertLog('am-vo-han', userId: 'u1', score: double.negativeInfinity);
      await insertLog('nguoi-khac', userId: 'u2', score: double.infinity);

      expect(await watchUnsyncableCount(db, 'u1').first, 2);
    });

    test('bỏ đi thì chỉ xoá buổi lỗi của đúng người, buổi khác còn nguyên', () async {
      await insertLog('ok', userId: 'u1', score: 7);
      await insertLog('vo-han', userId: 'u1', score: double.infinity);
      await insertLog('nguoi-khac', userId: 'u2', score: double.infinity);

      await discardUnsyncableLogs(db, 'u1');

      final ids = (await db.select(db.drillLogRows).get()).map((r) => r.id).toSet();
      expect(ids, {'ok', 'nguoi-khac'});
    });
  });
```

If the file has no `insertLog` helper, add one with the signature `Future<void> insertLog(String id, {required String userId, required double score})`, inserting `DrillLogRowsCompanion.insert(id: id, userId: userId, drillId: 'd1', date: DateTime(2026, 9, 22, 18), score: score)`.

`profile_screen_test.dart`: extend `openProfile` with `int unsyncable = 0`, inserting `u{i}` rows with `score: double.infinity`. Then add:

```dart
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
```

- [ ] **Step 2: Run to verify they fail**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/sync/account_actions_test.dart test/features/profile`
Expected: compile errors (missing functions and strings). The primary-button test compiles once the strings exist, and it may already pass because it only pins the current behaviour. That is fine: its job is to fail if someone swaps the buttons.

- [ ] **Step 3: Implement**

`account_actions.dart`:

```dart
/// Buổi chờ không bao giờ lên được server: điểm vô hạn nằm được trong
/// SQLite nhưng JSON thì không. Máy chặn buổi mới như vậy từ lúc nhập,
/// nhưng buổi ghi trước đó vẫn có thể còn trên máy.
bool isUnsyncable(DrillLogRow row) => !row.score.isFinite;

Stream<int> watchUnsyncableCount(AppDatabase db, String userId) {
  return (db.select(db.drillLogRows)
        ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
      .watch()
      .map((rows) => rows.where(isUnsyncable).length);
}

/// Người chơi bấm bỏ: xoá các buổi đó khỏi máy. Chỉ gọi sau khi họ xác nhận.
Future<void> discardUnsyncableLogs(AppDatabase db, String userId) async {
  final rows = await (db.select(db.drillLogRows)
        ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
      .get();
  final ids = rows.where(isUnsyncable).map((r) => r.id).toList();
  if (ids.isEmpty) return;
  await (db.delete(db.drillLogRows)..where((t) => t.id.isIn(ids))).go();
}
```

`auth_providers.dart` (import `account_actions.dart` and `database_provider.dart`, which is already imported):

```dart
/// Số buổi của người đang đăng nhập không bao giờ đồng bộ được.
final unsyncableCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);
  return watchUnsyncableCount(ref.watch(appDatabaseProvider), userId);
});
```

`vi.dart`, after `syncFailed`:

```dart
  static const cancel = 'Huỷ';
  static String unsyncableTitle(int count) =>
      'Có $count buổi tập không đồng bộ được';
  static const unsyncableBody =
      'Điểm của các buổi này không hợp lệ nên máy chủ không nhận. '
      'Chúng chỉ nằm trên máy này và sẽ mất khi đăng xuất.';
  static const unsyncableDiscard = 'Bỏ các buổi này';
  static const unsyncableConfirm = 'Bỏ';
  static String unsyncableConfirmBody(int count) =>
      'Xoá $count buổi lỗi khỏi máy? Không lấy lại được.';
```

`profile_screen.dart`: make the body a `Column`. It shows `_UnsyncableNotice` when the count > 0, then `Expanded(child: PcEmptyState(...))`:

```dart
    final unsyncable = ref.watch(unsyncableCountProvider).value ?? 0;
    ...
      body: Column(
        children: [
          if (unsyncable > 0) _UnsyncableNotice(count: unsyncable),
          Expanded(child: PcEmptyState(/* unchanged */)),
        ],
      ),
```

```dart
class _UnsyncableNotice extends ConsumerWidget {
  const _UnsyncableNotice({required this.count});

  final int count;

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Vi.unsyncableTitle(count)),
        content: Text(Vi.unsyncableConfirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Vi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.unsyncableConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await discardUnsyncableLogs(ref.read(appDatabaseProvider), userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined),
        title: Text(Vi.unsyncableTitle(count)),
        subtitle: const Text(Vi.unsyncableBody),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => _discard(context, ref),
          child: const Text(Vi.unsyncableDiscard),
        ),
      ),
    );
  }
}
```

(Import `package:poolcoachai/core/theme/app_spacing.dart`. If `AppSpacing.md` does not exist, use the nearest existing token. Check `lib/core/theme/app_spacing.dart`.)

The in-test profile uses a real Drift DB and a signed-in fake, so `unsyncableCountProvider` reads real rows with no override needed.

- [ ] **Step 4: Run to verify pass**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/data/sync test/features/profile` and `flutter.bat analyze`
Expected: all PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/account_actions.dart lib/core/providers/auth_providers.dart lib/core/strings/vi.dart lib/features/profile/presentation/profile_screen.dart test/data/sync/account_actions_test.dart test/features/profile/profile_screen_test.dart
git commit -m "Show logs that can never sync on Profile, and let the player drop them"
```

---

### Task 5: Test hygiene

**Files:**
- Modify: `test/app_test.dart:34-40`, `test/data/database/converters_test.dart:230-253`

- [ ] **Step 1: `app_test` states its auth**

In `chuỗi dựng sẵn của Material ra tiếng Việt…`, replace `container: testContainer(),` with:

```dart
          // Không truyền router: app tự dựng router từ authGateProvider,
          // nên phải đăng nhập rõ ràng — không dựa vào mặc định của testContainer.
          container: testContainer(auth: FakeAuthRepository.signedIn()),
```

Add `import 'support/fake_auth.dart';`.

- [ ] **Step 2: `converters_test` stops shadowing**

In the round-trip test at line 230, delete `final db = AppDatabase.forTesting(NativeDatabase.memory());` and `addTearDown(db.close);`. The file-level `setUp` db is used instead. Remove any imports this leaves unused.

- [ ] **Step 3: Run**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat test test/app_test.dart test/data/database/converters_test.dart` and `flutter.bat analyze`
Expected: PASS, no issues.

- [ ] **Step 4: Commit**

```bash
git add test/app_test.dart test/data/database/converters_test.dart
git commit -m "Say which user the router-less app test signs in, and stop shadowing the test database"
```

---

### Task 6: Directus tooling — sturdier licence check, stricter verify

**Files:**
- Modify: `deploy/directus/bootstrap.mjs:50-80`, `deploy/directus/verify.mjs:272-273, 307-327`

- [ ] **Step 1: Find the real licence shape on the live server**

Load the secrets from `.claude/settings.local.json` (`env` block) the same way `poolcoachai-deploy.md` describes. Then run:

```bash
node -e "
const b=process.env.DIRECTUS_URL.replace(/\/$/,'');
const t=(await (await fetch(b+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:process.env.DIRECTUS_ADMIN_EMAIL,password:process.env.DIRECTUS_ADMIN_PASSWORD})})).json()).data.access_token;
const i=(await (await fetch(b+'/server/info',{headers:{Authorization:'Bearer '+t}})).json()).data;
console.log(JSON.stringify(i.license,null,2));
" --input-type=module
```

Expected: a `license` object. Note the exact field that says OIG. The follow-up log suggests `license.source`, but trust only what the server prints. **Do not paste secret values into the plan or commits.**

- [ ] **Step 2: Replace the check with one helper**

In `bootstrap.mjs`:

```js
// Licence OIG đang chạy? Đọc đúng trường server dùng để nói nguồn licence
// (đã kiểm trên Directus 12.3.1 ngày 2026-09-25), không suy từ một
// entitlement phụ như display_powered_by.
const isOig = (info) => info.license?.<FIELD_FROM_STEP_1> === '<VALUE_FROM_STEP_1>';
```

Use `isOig(infoBefore)` and `isOig(infoAfter)` in place of both `display_powered_by` comparisons, and update the two log lines. `<FIELD_FROM_STEP_1>` and `<VALUE_FROM_STEP_1>` are the literal values Step 1 printed. If Step 1 shows no field sturdier than `display_powered_by`, keep that comparison, add a comment saying why, and record it in Task 8.

- [ ] **Step 3: Stricter `verify.mjs` asserts**

Short password: Directus returns `400 FAILED_VALIDATION` (findings log line 106).

```js
  short.status === 400 && short.code === 'FAILED_VALIDATION'
    ? ok('mật khẩu 7 ký tự bị từ chối → 400 FAILED_VALIDATION')
    : fail(`mật khẩu 7 ký tự → ${short.status} ${short.code} (cần 400 FAILED_VALIDATION)`);
```

Forged `user_created`: drop the `note(...)` line before the branch. Directus answers `403 FORBIDDEN` (findings line 114), so assert that directly and keep the ownership check for the 200 case:

```js
    const forgedRes = await call('POST', '/items/drill_logs', forged, a.access_token);
    if (forgedRes.status === 403) {
      ok('server từ chối tạo với user_created giả mạo → 403');
    } else if (forgedRes.status === 200 || forgedRes.status === 201) {
      // ...existing ownership check, unchanged...
    } else {
      fail(`tạo với user_created giả mạo → ${forgedRes.status} ${forgedRes.code}`);
    }
```

- [ ] **Step 4: Run both against live**

Run: `node deploy/directus/bootstrap.mjs` then `node deploy/directus/verify.mjs`, with the env from settings.local.json.
Expected: bootstrap prints `Licence đã kích hoạt (bỏ qua)` and `Xong.`, and verify prints `Tất cả kiểm tra đều qua`. Bootstrap is idempotent. It re-creates the Player permissions (create-then-delete), which is safe on live.

- [ ] **Step 5: Commit**

```bash
git add deploy/directus/bootstrap.mjs deploy/directus/verify.mjs
git commit -m "Detect the OIG licence by its source field, and make verify assert the exact rejections"
```

---

### Task 7: Run bootstrap on a clean Directus (temporary, in test-va)

**Outward-facing:** this creates services in Easypanel and activates a licence. Confirm with the owner right before Step 2, and delete everything in Step 6 even if earlier steps fail.

**Files:** none committed, unless a bug is found. Then fix it in `bootstrap.mjs` and commit it with a message that names the bug.

- [ ] **Step 1: Read the live `api` service config**

Use easypanel MCP `search_procedures` for "inspect app service" and "create postgres service". Read `test-va/api`: its image tag, env and domain. The temp copy must use the **same image tag** (Directus 12.3.1).

- [ ] **Step 2: Create the temporary services**

- Postgres service `bootstrap-check-db` in `test-va`, database `directus`, with a generated password.
- App service `bootstrap-check-api` from the same image. Copy the env from `deploy/directus/env.example` and fill it with a fresh `KEY`/`SECRET`/`ADMIN_PASSWORD`. Point `DB_HOST` at `test-va_bootstrap-check-db`. Set `PUBLIC_URL` to the Easypanel-assigned domain. Point email at the existing `test-va_mailpit` so `verify.mjs` can read the reset email. Set `PASSWORD_RESET_URL_ALLOW_LIST=https://poolcoachai.kjdybl.easypanel.host/reset-password`.
- Deploy it and wait until `GET /server/health` returns `ok`.

- [ ] **Step 3: Run bootstrap on the empty server**

Run: `DIRECTUS_URL=<temp> DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=<temp> DIRECTUS_LICENSE_KEY=<from settings.local.json> node deploy/directus/bootstrap.mjs`
Expected, in order: `Kích hoạt Open Innovation Grant licence…`, `Tạo collection drill_logs`, `Tạo quan hệ…`, `Tạo /roles Player`, `Tạo /policies Player`, `Đặt 4 quyền…`, `Xong.`

**If licence activation fails** because the key is already bound to the live server: stop, go to Step 6, and report to the owner. The create branches for collection, role and policy run *after* the licence check, so they cannot be exercised without a licence. Record that in Task 8 as still open, with the exact error text.

- [ ] **Step 4: Run bootstrap a second time**

Expected: every create branch is skipped (`bỏ qua` / no `Tạo …` lines), and `Đặt 4 quyền… (xoá 4 quyền cũ)`.

- [ ] **Step 5: Run verify against the temp server**

Run: `DIRECTUS_URL=<temp> … MAILPIT_URL=… node deploy/directus/verify.mjs`
Expected: `Tất cả kiểm tra đều qua`. The reset-link check expects the live app domain in the email. That holds because `reset_url` is passed per request and is allow-listed in Step 2.

- [ ] **Step 6: Tear down (always)**

Delete `bootstrap-check-api` and `bootstrap-check-db` through the easypanel MCP (`execute_destructive`, exact names). Then list `test-va` services and confirm only `poolcoachai`, `api`, `db` and `mailpit` remain.

---

### Task 8: Close the log, deploy, prove it live

**Files:**
- Modify: `docs/superpowers/logs/2026-09-24-accounts-sync-followups.md`

- [ ] **Step 1: Full verification**

Run: `C:\Users\anhnpv\flutter\bin\flutter.bat analyze` and `C:\Users\anhnpv\flutter\bin\flutter.bat test`
Expected: no issues. All tests pass, and the count is above 321.

- [ ] **Step 2: Update the log**

Add a `## Closed 2026-09-25` section at the top that maps each item to its commit hash. Mark the `env.example` item "already present before this pass (env.example:44–48)". If Task 7 hit the licence wall, keep that one item under "Still open" with the error text.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/logs/2026-09-24-accounts-sync-followups.md
git commit -m "Close the accounts and sync follow-ups"
```

- [ ] **Step 4: Deploy**

From a clean tree, run `FLUTTER=C:/Users/anhnpv/flutter/bin/flutter.bat DART=C:/Users/anhnpv/flutter/bin/dart.bat bash deploy/publish.sh`. Then call easypanel `deployAppService` {projectName: `test-va`, serviceName: `poolcoachai`}.

- [ ] **Step 5: Prove it live**

Run `node tool/e2e/accounts.mjs https://poolcoachai.kjdybl.easypanel.host` with the MAILPIT env.
Expected: all 6 steps pass. A green build is not proof: the proof is this headless-Chrome run.
