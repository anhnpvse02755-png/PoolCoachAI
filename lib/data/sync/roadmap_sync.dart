import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart'
    show AchievementKind;
import 'package:poolcoachai/domain/roadmap/goal.dart';

/// Số dòng mục tiêu và thành tích chưa lên server, của mọi người trên máy.
Stream<int> watchPendingRoadmap(AppDatabase db) => db
    .customSelect(
      'SELECT (SELECT COUNT(*) FROM player_goal_rows WHERE synced_at IS NULL) '
      '+ (SELECT COUNT(*) FROM achievement_rows WHERE synced_at IS NULL) AS n',
      readsFrom: {db.playerGoalRows, db.achievementRows},
    )
    .watchSingle()
    .map((row) => row.read<int>('n'));

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ mục tiêu và thành tích với Directus (spec 2026-10-15 mục 6).
///
/// Tách khỏi hai service có sẵn vì khác luật: mục tiêu gộp theo [mergeGoal]
/// (mới nhất thắng), thành tích chỉ thêm. Cùng cách sống: chạy khi đăng nhập,
/// khi có dòng mới chờ, và định kỳ khi còn dòng chờ.
class RoadmapSyncService {
  RoadmapSyncService({
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

  /// Mã Directus khi `POST` một id đã có: đã lên từ lần trước, hoặc máy khác
  /// của cùng người đã ghi cùng thành tích (R8).
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  int _pending = 0;

  /// Thành tích server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
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
    _pendingSub = watchPendingRoadmap(_db).listen((n) {
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
      await _pushAchievements(userId);
      await _syncGoal(userId);
      await _pullAchievements(userId);
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

  Future<void> _create(
    String path,
    Map<String, Object?> body,
    String userId,
  ) async {
    final token = await _tokenFor(userId);
    try {
      await _api.post(path, token: token, body: body);
    } on DirectusError catch (e) {
      if (e.code != _duplicateCode) rethrow;
    }
    _checkAlive();
  }

  Future<void> _pushAchievements(String userId) async {
    // Chứng nhận suy ra hoàn toàn từ skill_tests đã đồng bộ nên không đẩy lên:
    // bản cũ đọc loại thành tích bằng byName sẽ ném khi gặp 'chungNhan' (S13).
    final rows =
        await (_db.select(_db.achievementRows)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.syncedAt.isNull() &
                  t.kind.equals(AchievementKind.chungNhan.name).not(),
            ))
            .get();
    for (final r in rows) {
      if (_rejected.contains(r.id)) continue;
      _checkAlive();
      try {
        await _create('/items/achievements', toRemoteAchievement(r), userId);
      } on DirectusError catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401) {
          _rejected.add(r.id);
          continue;
        }
        rethrow;
      }
      await (_db.update(_db.achievementRows)..where((t) => t.id.equals(r.id)))
          .write(AchievementRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Gộp dòng mục tiêu trên máy với trên server theo [mergeGoal], rồi ghi bản
  /// thắng về phía còn thiếu.
  Future<void> _syncGoal(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get(
      '/items/player_goals',
      token: token,
      query: {'limit': '1', 'fields': remoteGoalFields},
    ) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final remote = items.isEmpty
        ? null
        : goalFromRemote(items.first! as Map<String, Object?>);

    final localRow = await (_db.select(
      _db.playerGoalRows,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    final local = localRow == null ? null : toGoalRecord(localRow);
    final picked = mergeGoal(local, remote);
    if (picked == null) return;

    if (identical(picked, remote)) {
      // Gộp lại trong transaction: người chơi vừa đổi mục tiêu trong lúc chờ
      // server thì bản mới đó được xét lại, không bị ghi đè mù.
      await _db.transaction(() async {
        final fresh = await (_db.select(
          _db.playerGoalRows,
        )..where((t) => t.userId.equals(userId))).getSingleOrNull();
        final again = mergeGoal(
          fresh == null ? null : toGoalRecord(fresh),
          remote,
        );
        if (identical(again, remote)) {
          // toCompanion(false): bản máy chủ có cột null (đã bỏ mục tiêu) phải
          // ghi đè được cột cũ — dòng dữ liệu thẳng thì Drift bỏ cột null.
          await _db
              .into(_db.playerGoalRows)
              .insertOnConflictUpdate(
                toGoalRow(
                  remote!,
                  userId: userId,
                  syncedAt: _now(),
                ).toCompanion(false),
              );
        }
      });
      return;
    }

    final row = localRow!;
    if (row.syncedAt != null) return;
    final body = toRemoteGoal(row);
    if (remote == null) {
      await _create('/items/player_goals', body, userId);
    } else {
      body.remove('id');
      await _api.patch(
        '/items/player_goals/$userId',
        token: await _tokenFor(userId),
        body: body,
      );
      _checkAlive();
    }
    await (_db.update(_db.playerGoalRows)..where(
          (t) => t.userId.equals(userId) & t.updatedAt.equals(row.updatedAt),
        ))
        .write(PlayerGoalRowsCompanion(syncedAt: Value(_now())));
  }

  /// Thành tích trên server không đổi nữa: thêm cái còn thiếu, bỏ qua cái đã có.
  Future<void> _pullAchievements(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get(
      '/items/achievements',
      token: token,
      query: {'limit': '-1', 'fields': remoteAchievementFields},
    ) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    await _db.batch((batch) {
      for (final item in items) {
        final row = achievementFromRemote(
          item! as Map<String, Object?>,
          userId: userId,
          syncedAt: at,
        );
        if (row == null) continue;
        batch.insert(_db.achievementRows, row, mode: InsertMode.insertOrIgnore);
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
