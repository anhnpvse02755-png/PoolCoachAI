import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/coach_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';

/// Số lần làm Coach chưa lên server, của mọi người trên máy.
Stream<int> watchPendingCoach(AppDatabase db) => db
    .customSelect(
      'SELECT COUNT(*) AS n FROM coach_attempt_rows WHERE synced_at IS NULL',
      readsFrom: {db.coachAttemptRows},
    )
    .watchSingle()
    .map((row) => row.read<int>('n'));

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ lần làm tình huống Coach với Directus (spec Coach mục 11.4).
///
/// Cùng vòng đời với `RoadmapSyncService`: chạy khi đăng nhập, khi có dòng
/// mới chờ, và mỗi [_retryEvery] khi còn dòng chờ. Lần làm chỉ thêm, không
/// sửa: đẩy dòng có `syncedAt` rỗng, kéo về dòng còn thiếu.
class CoachSyncService {
  CoachSyncService({
    required this._db,
    required this._auth,
    required this._api,
    required this._now,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final Duration _retryEvery;

  /// Mã Directus khi `POST` một id đã có: đã lên từ lần trước.
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  int _pending = 0;

  /// Dòng server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
  final Set<String> _rejected = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<int>? _pendingSub;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSub = _auth.watchSession().listen((s) {
      if (s is SignedIn) unawaited(syncNow());
    });
    _pendingSub = watchPendingCoach(_db).listen((n) {
      final more = n > _pending;
      _pending = n;
      if (more) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_pending > _rejected.length) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  Future<SyncOutcome> syncNow() {
    if (_disposed) return Future.value(SyncOutcome.stopped);
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<SyncOutcome> _loop() async {
    SyncOutcome outcome;
    do {
      _again = false;
      outcome = await _once();
    } while (_again && outcome == SyncOutcome.done && !_disposed);
    return outcome;
  }

  Future<SyncOutcome> _once() async {
    if (_disposed) return SyncOutcome.stopped;
    final who = _auth.current;
    if (who is! SignedIn) return SyncOutcome.signedOut;
    final userId = who.userId;
    try {
      await _push(userId);
      await _pull(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (f) {
      return switch (f) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      return SyncOutcome.offline;
    } on Object {
      // syncNow() chạy từ timer: không bao giờ ném.
      return SyncOutcome.failed;
    }
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
        SignedIn(userId: final id) => id == userId,
        SignedOut() => false,
      };

  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    return token;
  }

  void _checkAlive() {
    if (_disposed) throw const _Stopped();
  }

  Future<void> _push(String userId) async {
    final rows = await (_db.select(_db.coachAttemptRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
        .get();
    for (final r in rows) {
      if (_rejected.contains(r.id)) continue;
      _checkAlive();
      final token = await _tokenFor(userId);
      try {
        await _api.post('/items/coach_attempts', token: token, body: toRemoteCoachAttempt(r));
      } on DirectusError catch (e) {
        if (e.code != _duplicateCode) {
          if (e.status >= 400 && e.status < 500 && e.status != 401) {
            _rejected.add(r.id);
            continue;
          }
          rethrow;
        }
      }
      _checkAlive();
      await (_db.update(_db.coachAttemptRows)..where((t) => t.id.equals(r.id)))
          .write(CoachAttemptRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Lần làm trên server không đổi nữa: thêm dòng còn thiếu, bỏ qua dòng đã có.
  Future<void> _pull(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/coach_attempts',
        token: token, query: {'limit': '-1', 'fields': remoteCoachAttemptFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(
          _db.coachAttemptRows,
          coachAttemptFromRemote(item! as Map<String, Object?>, userId: userId, syncedAt: at),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
}
