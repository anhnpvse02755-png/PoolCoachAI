import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

enum SyncOutcome { done, offline, signedOut, failed }

/// Đổi người đăng nhập giữa một lượt đồng bộ — bỏ lượt đó.
class _UserChanged implements Exception {
  const _UserChanged();
}

/// Đẩy buổi tập chưa đồng bộ lên Directus, rồi kéo buổi tập về máy.
///
/// Chỉ làm việc với dữ liệu của **người đang đăng nhập**: dòng chờ của
/// người khác trên cùng máy nằm yên cho tới khi chính họ đăng nhập lại
/// (spec mục 5.4). Màn hình không biết lớp này tồn tại — chúng đọc Drift.
class SyncService {
  SyncService({
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

  /// Mã Directus khi `POST` một id đã có — đã kiểm trên server thật.
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  Future<SyncOutcome>? _running;
  bool _again = false;
  Set<String> _seenPending = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<String>>? _pendingSub;

  /// Tự đồng bộ: ngay lúc gọi, khi vừa đăng nhập, khi có buổi tập mới,
  /// và định kỳ khi vẫn còn buổi nằm chờ.
  void start() {
    _authSub = _auth.watchSession().listen((state) {
      if (state is SignedIn) unawaited(syncNow());
    });
    _pendingSub = _db.watchPendingLogIds().listen((ids) {
      final fresh = ids.any((id) => !_seenPending.contains(id));
      _seenPending = ids.toSet();
      if (fresh) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_seenPending.isNotEmpty) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  /// Một lượt đẩy rồi kéo. Gọi khi đang chạy thì chạy thêm đúng một lượt
  /// sau lượt hiện tại, để buổi vừa ghi không phải chờ tới lần thử lại.
  Future<SyncOutcome> syncNow() {
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
    } while (_again && outcome == SyncOutcome.done);
    return outcome;
  }

  Future<SyncOutcome> _once() async {
    final who = _auth.current;
    if (who is! SignedIn) return SyncOutcome.signedOut;
    try {
      await _push(who.userId);
      await _pull(who.userId);
      return SyncOutcome.done;
    } on AuthFailure catch (failure) {
      return switch (failure) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      return SyncOutcome.offline;
    } on DirectusError {
      return SyncOutcome.failed;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    }
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
        SignedIn(userId: final id) => id == userId,
        SignedOut() => false,
      };

  /// Lấy token rồi kiểm lại người dùng: token luôn thuộc người đang đăng
  /// nhập, nên người đổi thì dừng, không gửi dữ liệu của người cũ.
  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    return token;
  }

  Future<void> _push(String userId) async {
    final pending = await (_db.select(_db.drillLogRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    for (final row in pending) {
      final token = await _tokenFor(userId);
      try {
        await _api.post('/items/drill_logs',
            token: token, body: toRemoteDrillLog(row));
      } on DirectusError catch (e) {
        // Đã lên từ lần trước mà chưa kịp đánh dấu — không phải lỗi.
        if (e.code != _duplicateCode) rethrow;
      }
      await (_db.update(_db.drillLogRows)..where((t) => t.id.equals(row.id)))
          .write(DrillLogRowsCompanion(syncedAt: Value(_now())));
    }
  }

  Future<void> _pull(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/drill_logs', token: token, query: {
      'limit': '-1',
      'fields': 'id,drill_id,date,score,attempts,notes',
    }) as List<Object?>;

    // Người đổi trong lúc chờ server thì bỏ kết quả: ghi vào là dựng lại
    // dữ liệu mà người cũ vừa xoá khi đăng xuất.
    if (!_stillSignedInAs(userId)) throw const _UserChanged();

    final syncedAt = _now();
    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(
          _db.drillLogRows,
          fromRemoteDrillLog(
            item! as Map<String, Object?>,
            userId: userId,
            syncedAt: syncedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
}
