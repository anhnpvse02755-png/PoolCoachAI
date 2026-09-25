import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

enum SyncOutcome { done, offline, signedOut, failed, stopped }

/// Đổi người đăng nhập giữa một lượt đồng bộ — bỏ lượt đó.
class _UserChanged implements Exception {
  const _UserChanged();
}

/// Service bị dispose giữa lượt.
class _Stopped implements Exception {
  const _Stopped();
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

  bool _started = false;
  bool _disposed = false;
  Future<SyncOutcome>? _running;
  bool _again = false;
  /// Buổi chờ đẩy trên máy, của mọi người — id → chủ của buổi.
  Map<String, String> _seenPending = {};

  /// Buổi server từ chối hoặc không mã hoá được thành JSON. Vẫn nằm chờ
  /// (không xoá, vẫn tính là chưa đồng bộ) và mỗi lượt vẫn thử lại, nhưng
  /// không tự khởi động lượt nào: nếu không, lần thử lại định kỳ quay mãi.
  /// Chỉ sống trong bộ nhớ — mở lại app là thử lại từ đầu.
  final Set<String> _rejected = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<({String id, String userId})>>? _pendingSub;

  /// Tự đồng bộ: ngay lúc gọi, khi vừa đăng nhập, khi có buổi tập mới,
  /// và định kỳ khi vẫn còn buổi nằm chờ.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSub = _auth.watchSession().listen((state) {
      if (state is SignedIn) unawaited(syncNow());
    });
    _pendingSub = _db.watchPendingLogs().listen((rows) {
      final fresh = rows.any(
          (r) => !_seenPending.containsKey(r.id) && _worthPushing(r.id, r.userId));
      _seenPending = {for (final r in rows) r.id: r.userId};
      if (fresh) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_seenPending.entries.any((e) => _worthPushing(e.key, e.value))) {
        unawaited(syncNow());
      }
    });
    unawaited(syncNow());
  }

  /// Buổi chờ này có đáng khởi động một lượt không: phải của người đang
  /// đăng nhập (buổi của người khác chỉ đẩy khi chính họ quay lại), và
  /// chưa bị server từ chối trong lần chạy này.
  bool _worthPushing(String id, String userId) =>
      _stillSignedInAs(userId) && !_rejected.contains(id);

  /// Một lượt đẩy rồi kéo. Gọi khi đang chạy thì chạy thêm đúng một lượt
  /// sau lượt hiện tại, để buổi vừa ghi không phải chờ tới lần thử lại.
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

  Future<({SyncOutcome outcome, bool reachedEnd})> _once() async {
    if (_disposed) return (outcome: SyncOutcome.stopped, reachedEnd: false);
    final who = _auth.current;
    if (who is! SignedIn) return (outcome: SyncOutcome.signedOut, reachedEnd: true);
    try {
      final anyRejected = await _push(who.userId);
      // Buổi bị từ chối không phải lý do bỏ kéo về: dữ liệu từ máy khác
      // vẫn phải về. Nhưng lượt này vẫn là failed, vì còn buổi nằm chờ.
      await _pull(who.userId);
      return (outcome: anyRejected ? SyncOutcome.failed : SyncOutcome.done, reachedEnd: true);
    } on AuthFailure catch (failure) {
      return (outcome: switch (failure) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      }, reachedEnd: false);
    } on DirectusUnreachable {
      return (outcome: SyncOutcome.offline, reachedEnd: false);
    } on DirectusError {
      return (outcome: SyncOutcome.failed, reachedEnd: false);
    } on _UserChanged {
      return (outcome: SyncOutcome.signedOut, reachedEnd: false);
    } on _Stopped {
      return (outcome: SyncOutcome.stopped, reachedEnd: false);
    } on Object {
      // Server trả hình dạng lạ, hay bất cứ gì chưa lường: lượt này hỏng,
      // nhưng syncNow() không bao giờ ném — nó chạy từ timer và từ nút bấm.
      return (outcome: SyncOutcome.failed, reachedEnd: false);
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

  /// Ném [_Stopped] nếu service đã bị dispose.
  void _checkAlive() {
    if (_disposed) throw const _Stopped();
  }

  /// Trả `true` nếu có buổi bị từ chối trong lượt này.
  Future<bool> _push(String userId) async {
    final pending = await (_db.select(_db.drillLogRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    var anyRejected = false;
    for (final row in pending) {
      _checkAlive();
      final Map<String, Object?> body;
      try {
        body = toRemoteDrillLog(row);
        // Mã hoá thử trước khi gửi: điểm vô hạn nằm được trong SQLite
        // nhưng JSON thì không, và lỗi đó không được chặn cả hàng.
        jsonEncode(body);
      } on Object {
        _rejected.add(row.id);
        anyRejected = true;
        continue;
      }

      final token = await _tokenFor(userId);
      try {
        await _api.post('/items/drill_logs', token: token, body: body);
        _checkAlive();
      } on DirectusError catch (e) {
        if (e.code == _duplicateCode) {
          // Đã lên từ lần trước mà chưa kịp đánh dấu — không phải lỗi.
        } else if (_rejectsRow(e)) {
          _rejected.add(row.id);
          anyRejected = true;
          continue;
        } else {
          rethrow;
        }
      }
      _rejected.remove(row.id);
      await (_db.update(_db.drillLogRows)..where((t) => t.id.equals(row.id)))
          .write(DrillLogRowsCompanion(syncedAt: Value(_now())));
    }
    return anyRejected;
  }

  /// Server chê chính **buổi này** (4xx) — bỏ qua nó, đẩy buổi kế.
  /// 401 là chuyện phiên chứ không phải chuyện buổi tập, và 5xx là server
  /// đang ốm: cả hai dừng lượt như cũ.
  static bool _rejectsRow(DirectusError e) =>
      e.status >= 400 && e.status < 500 && e.status != 401;

  Future<void> _pull(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/drill_logs', token: token, query: {
      'limit': '-1',
      'fields': 'id,drill_id,date,score,attempts,notes',
    }) as List<Object?>;
    _checkAlive();

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
    _disposed = true;
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
}
