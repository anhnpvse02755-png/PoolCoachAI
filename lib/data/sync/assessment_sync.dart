import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/rank_merge.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Số thứ đang chờ lên server của phần đánh giá, của mọi người trên máy:
/// dòng hạng chưa đồng bộ, lần kiểm tra BU đã xong và lần Skill Test chưa lên
/// (hoàn tất hoặc huỷ; dòng skill_test_rows chỉ được ghi khi đã xong).
Stream<int> watchPendingAssessment(AppDatabase db) => db
    .customSelect(
      'SELECT (SELECT COUNT(*) FROM bu_test_rows WHERE synced_at IS NULL '
      'AND (completed_at IS NOT NULL OR cancelled_at IS NOT NULL)) '
      '+ (SELECT COUNT(*) FROM player_rank_rows WHERE synced_at IS NULL) '
      '+ (SELECT COUNT(*) FROM skill_test_rows WHERE synced_at IS NULL) AS n',
      readsFrom: {db.buTestRows, db.playerRankRows, db.skillTestRows},
    )
    .watchSingle()
    .map((row) => row.read<int>('n'));

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ hạng và bài kiểm tra BU với Directus (spec mục 6.2).
///
/// Tách khỏi [SyncService] của buổi tập: hai luồng dữ liệu khác luật (buổi
/// tập chỉ thêm; hạng gộp theo [mergeRank]), và để luồng buổi tập cùng các
/// test của nó không đổi. Cùng cách sống: chạy khi đăng nhập, khi có thứ
/// mới chờ, và định kỳ khi còn thứ chờ.
class AssessmentSyncService {
  AssessmentSyncService({
    required this._db,
    required this._auth,
    required this._api,
    required this._now,
    required this._onRankFetch,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final void Function(String userId, RankFetch fetch) _onRankFetch;
  final Duration _retryEvery;

  /// Mã Directus khi `POST` một id đã có: đã lên từ lần trước.
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  int _pending = 0;

  /// Lần kiểm tra server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
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
    _pendingSub = watchPendingAssessment(_db).listen((n) {
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
    var rankFetched = false;
    void failed() {
      // Đã lấy được hạng trong lượt này thì giữ kết quả đó: việc kéo bài
      // kiểm tra hỏng sau đó không làm onboarding đổi ý.
      if (!rankFetched && _stillSignedInAs(userId)) _onRankFetch(userId, RankFetch.failed);
    }

    try {
      await _pushFinishedTests(userId);
      final hadRow = await _syncRank(userId);
      rankFetched = true;
      _onRankFetch(userId, hadRow ? RankFetch.found : RankFetch.foundNone);
      // Sau khi đã lấy hạng: đẩy bài kiểm tra bị 5xx không được chặn việc đó.
      await _pushSkillTests(userId);
      await _pullTests(userId);
      await _pullSkillTests(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (f) {
      failed();
      return switch (f) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      failed();
      return SyncOutcome.offline;
    } on Object {
      // Server trả hình dạng lạ hay lỗi chưa lường: lượt này hỏng, nhưng
      // syncNow() không bao giờ ném — nó chạy từ timer.
      failed();
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

  Future<void> _create(String path, Map<String, Object?> body, String userId) async {
    final token = await _tokenFor(userId);
    try {
      await _api.post(path, token: token, body: body);
    } on DirectusError catch (e) {
      if (e.code != _duplicateCode) rethrow;
    }
    _checkAlive();
  }

  /// Lần đã xong lên server cùng mọi kết quả của nó; lần đang dở nằm yên
  /// (D10 của kế hoạch). Kết quả trước, lần kiểm tra sau: lần đã đánh dấu
  /// đồng bộ thì chắc chắn đủ kết quả trên server.
  Future<void> _pushFinishedTests(String userId) async {
    final tests = await (_db.select(_db.buTestRows)
          ..where((t) =>
              t.userId.equals(userId) &
              t.syncedAt.isNull() &
              (t.completedAt.isNotNull() | t.cancelledAt.isNotNull()))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    for (final test in tests) {
      if (_rejected.contains(test.id)) continue;
      _checkAlive();
      try {
        final results = await (_db.select(_db.buDrillResultRows)
              ..where((r) => r.testId.equals(test.id) & r.syncedAt.isNull()))
            .get();
        for (final r in results) {
          await _create('/items/bu_drill_results', toRemoteResult(r), userId);
          await (_db.update(_db.buDrillResultRows)..where((x) => x.id.equals(r.id)))
              .write(BuDrillResultRowsCompanion(syncedAt: Value(_now())));
        }
        await _create('/items/bu_tests', toRemoteTest(test), userId);
      } on DirectusError catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401) {
          _rejected.add(test.id);
          continue;
        }
        rethrow;
      }
      await (_db.update(_db.buTestRows)..where((t) => t.id.equals(test.id)))
          .write(BuTestRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Lần Skill Test đã xong (đạt, trượt hoặc huỷ) lên server. Chỉ thêm: máy
  /// chủ không cho sửa hay xoá, id đã có thì coi là đã lên.
  Future<void> _pushSkillTests(String userId) async {
    final rows = await (_db.select(_db.skillTestRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    for (final row in rows) {
      if (_rejected.contains(row.id)) continue;
      _checkAlive();
      try {
        await _create('/items/skill_tests', toRemoteSkillTest(row), userId);
      } on DirectusError catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401) {
          _rejected.add(row.id);
          continue;
        }
        rethrow;
      }
      await (_db.update(_db.skillTestRows)..where((t) => t.id.equals(row.id)))
          .write(SkillTestRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Lấy dòng hạng trên server, gộp với dòng trên máy theo [mergeRank], rồi
  /// ghi bản thắng về phía còn thiếu. Trả về server có dòng hạng hay không.
  Future<bool> _syncRank(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/player_ranks',
        token: token, query: {'limit': '1', 'fields': remoteRankFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final remoteJson = items.isEmpty ? null : items.first! as Map<String, Object?>;
    final remote = remoteJson == null ? null : rankFromRemote(remoteJson);

    var localRow = await (_db.select(_db.playerRankRows)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    final local = localRow == null ? null : toPlayerRank(localRow);
    final picked = mergeRank(local, remote);
    if (picked == null) return false;
    final winner = warnOfLowerTest(picked, identical(picked, remote) ? local : remote);

    if (!identical(winner, picked)) {
      // Bản gộp mới: hạng của bên thắng + cảnh báo từ lần kiểm chứng thấp
      // hơn bên thua (D4, chủ sản phẩm chọn). Ghi xuống máy như một thay đổi
      // chưa đồng bộ rồi đẩy lên như mọi thay đổi khác.
      final wrote = await _db.transaction(() async {
        final fresh = await (_db.select(_db.playerRankRows)
              ..where((t) => t.userId.equals(userId)))
            .getSingleOrNull();
        // Người chơi vừa đổi hạng trên máy trong lúc chờ server: lượt sau
        // xét lại từ đầu, không ghi đè mù.
        if (fresh?.updatedAt != localRow?.updatedAt) return false;
        await _db
            .into(_db.playerRankRows)
            .insertOnConflictUpdate(toPlayerRankRow(winner, userId: userId));
        return true;
      });
      if (!wrote) {
        _again = true;
        return remoteJson != null;
      }
      localRow = await (_db.select(_db.playerRankRows)
            ..where((t) => t.userId.equals(userId)))
          .getSingle();
    } else if (identical(winner, remote)) {
      // Gộp lại trong transaction: người chơi vừa đổi hạng trên máy trong
      // lúc chờ server thì bản mới đó được xét lại, không bị ghi đè mù.
      await _db.transaction(() async {
        final fresh = await (_db.select(_db.playerRankRows)
              ..where((t) => t.userId.equals(userId)))
            .getSingleOrNull();
        final again = mergeRank(fresh == null ? null : toPlayerRank(fresh), remote);
        if (identical(again, remote)) {
          await _db.into(_db.playerRankRows).insertOnConflictUpdate(
              toPlayerRankRow(remote!, userId: userId, syncedAt: _now()));
        }
      });
      return true;
    }

    final row = localRow!;
    if (row.syncedAt != null) return remoteJson != null;
    final body = toRemoteRank(row);
    final t = await _tokenFor(userId);
    if (remoteJson == null) {
      await _create('/items/player_ranks', body, userId);
    } else {
      body.remove('id');
      await _api.patch('/items/player_ranks/$userId', token: t, body: body);
      _checkAlive();
    }
    await (_db.update(_db.playerRankRows)
          ..where((r) => r.userId.equals(userId) & r.updatedAt.equals(row.updatedAt)))
        .write(PlayerRankRowsCompanion(syncedAt: Value(_now())));
    return remoteJson != null;
  }

  /// Lần kiểm tra trên server đều đã xong và không đổi nữa: ghi đè an toàn.
  Future<void> _pullTests(String userId) async {
    final token = await _tokenFor(userId);
    final tests = await _api.get('/items/bu_tests',
        token: token, query: {'limit': '-1', 'fields': remoteTestFields}) as List<Object?>;
    final results = await _api.get('/items/bu_drill_results',
        token: token, query: {'limit': '-1', 'fields': remoteResultFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    await _db.batch((batch) {
      for (final t in tests) {
        batch.insert(_db.buTestRows,
            fromRemoteTest(t! as Map<String, Object?>, userId: userId, syncedAt: at),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in results) {
        batch.insert(_db.buDrillResultRows,
            fromRemoteResult(r! as Map<String, Object?>, syncedAt: at),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Chỉ thêm, máy thắng: dòng cùng id đã có trên máy giữ nguyên. Dòng máy
  /// chủ không dùng được (dữ liệu lạ) bị bỏ, không làm hỏng cả lượt.
  Future<void> _pullSkillTests(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/skill_tests',
        token: token,
        query: {'limit': '-1', 'fields': remoteSkillTestFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    final rows = <SkillTestRow>[];
    for (final item in items) {
      if (item is! Map<String, Object?>) continue;
      final row = skillTestFromRemote(item, userId: userId, syncedAt: at);
      if (row != null) rows.add(row);
    }
    await _db.batch((batch) {
      for (final row in rows) {
        batch.insert(_db.skillTestRows, row, mode: InsertMode.insertOrIgnore);
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
