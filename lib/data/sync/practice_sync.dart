import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/category_compat.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/tournament_converters.dart';
import 'package:poolcoachai/data/remote/codecs/practice_codecs.dart';
import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';

export 'package:poolcoachai/data/remote/codecs/remote_fields.dart'
    show
        poolMatchRemoteFields,
        scheduleSlotRemoteFields,
        timerSessionRemoteFields;

const _matchesPath = '/items/pool_matches';
const _timersPath = '/items/timer_sessions';
const _slotsPath = '/items/schedule_slots';
const _tournamentsPath = '/items/tournaments';

/// Mã Directus khi `POST` một id đã có: đã lên từ lần trước, hoặc máy khác
/// của cùng người đã ghi cùng bản ghi.
const _duplicateCode = 'RECORD_NOT_UNIQUE';

class _Stopped implements Exception {
  const _Stopped();
}

class _UserChanged implements Exception {
  const _UserChanged();
}

/// Đồng bộ trận đấu, buổi tập tự do và lịch tập tuần với Directus.
///
/// Cùng cách sống với [CueEquipmentSyncService]: chạy khi đăng nhập, khi có
/// dòng mới chờ và định kỳ khi còn dòng chờ; mỗi bản ghi phải thuộc đúng tài
/// khoản đang đăng nhập (`user_created`) thì mới nhận.
///
/// Luật theo từng loại:
/// - **Trận đấu**: bản sửa mới nhất thắng ([PoolMatchRow.updatedAt]). Không
///   có xóa. `cue_id` giữ nguyên cả khi cơ đã bị xóa.
/// - **Buổi tập tự do**: chỉ thêm, không sửa, không xóa.
/// - **Lịch tập**: bản sửa mới nhất thắng; xóa là tombstone (`is_deleted`).
///
/// Dòng không có chủ (`user_id` rỗng, từ trước khi gắn tài khoản) không bao
/// giờ được đẩy lên.
class PracticeSyncService {
  PracticeSyncService({
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

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;

  /// Bản sửa đang chờ, khóa theo `loại:id`.
  final Map<String, Map<String, String>> _pending = {
    'match': {},
    'timer': {},
    'slot': {},
    'tournament': {},
  };

  /// Bản ghi server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
  final Set<String> _rejected = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  final List<StreamSubscription<Object?>> _pendingSubscriptions = [];

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSubscription = _auth.watchSession().listen((state) {
      if (state is SignedIn) unawaited(syncNow());
    });
    _watch(
      'match',
      (_db.select(_db.poolMatchRows)..where((row) => row.syncedAt.isNull()))
          .watch()
          .map(
            (rows) => {for (final r in rows) r.id: _matchRevision(r)},
          ),
    );
    _watch(
      'timer',
      (_db.select(_db.timerSessionRows)..where((row) => row.syncedAt.isNull()))
          .watch()
          .map(
            (rows) => {for (final r in rows) r.id: '${r.userId}:'},
          ),
    );
    _watch(
      'slot',
      (_db.select(_db.scheduleSlotRows)..where((row) => row.syncedAt.isNull()))
          .watch()
          .map(
            (rows) => {for (final r in rows) r.id: _slotRevision(r)},
          ),
    );
    _watch(
      'tournament',
      (_db.select(_db.tournamentRows)..where((row) => row.syncedAt.isNull()))
          .watch()
          .map(
            (rows) => {for (final r in rows) r.id: _tournamentRevision(r)},
          ),
    );
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_hasActionablePending()) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  void _watch(String kind, Stream<Map<String, String>> stream) {
    _pendingSubscriptions.add(
      stream.listen((current) {
        final before = _pending[kind]!;
        final changed = current.entries.any(
          (entry) =>
              before[entry.key] != entry.value && _isCurrentOwner(entry.value),
        );
        _pending[kind] = current;
        if (changed) unawaited(syncNow());
      }),
    );
  }

  bool _hasActionablePending() => _pending.entries.any(
    (kind) => kind.value.entries.any(
      (entry) =>
          _isCurrentOwner(entry.value) &&
          !_rejected.contains('${kind.key}:${entry.key}:${entry.value}'),
    ),
  );

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
      outcome = await _syncOnce();
    } while (_again && outcome == SyncOutcome.done && !_disposed);
    return outcome;
  }

  Future<SyncOutcome> _syncOnce() async {
    if (_disposed) return SyncOutcome.stopped;
    final state = _auth.current;
    if (state is! SignedIn) return SyncOutcome.signedOut;
    final userId = state.userId;
    try {
      await _syncMatches(userId);
      await _syncTimerSessions(userId);
      await _syncSlots(userId);
      // Cuối cùng: giải hỏng không được chặn đồng bộ trận, buổi tập, lịch.
      await _syncTournaments(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (failure) {
      return switch (failure) {
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

  // ─── Trận đấu ───────────────────────────────────────────────────────────

  Future<void> _syncMatches(String userId) async {
    final remoteItems = await _fetch(_matchesPath, poolMatchRemoteFields, userId);
    final remoteById = {for (final item in remoteItems) remoteString(item, 'id'): item};
    final pending =
        await (_db.select(_db.poolMatchRows)
              ..where((r) => r.userId.equals(userId) & r.syncedAt.isNull())
              ..orderBy([(r) => OrderingTerm.asc(r.startedAt)]))
            .get();

    for (final row in pending) {
      _checkAlive();
      _checkUser(userId);
      final key = 'match:${row.id}:${_matchRevision(row)}';
      if (_rejected.contains(key)) continue;
      final remote = remoteById[row.id];
      final localUpdatedAt = row.updatedAt;
      if (remote != null &&
          (localUpdatedAt == null ||
              !localUpdatedAt.isAfter(remoteInstant(remote, 'updated_at')))) {
        continue;
      }
      final sentAt = localUpdatedAt ?? _now();
      final ok = await _upsert(
        path: _matchesPath,
        id: row.id,
        exists: remote != null,
        body: {
          'id': row.id,
          'game_type': row.gameType,
          'player_name': row.playerName,
          'opponent_name': row.opponentName,
          'target_racks': row.targetRacks,
          'rack_winners': jsonDecode(row.rackWinners),
          'shots': jsonDecode(row.shots),
          'cue_id': row.cueId,
          'started_at': row.startedAt.toUtc().toIso8601String(),
          'completed_at': row.completedAt?.toUtc().toIso8601String(),
          'updated_at': sentAt.toUtc().toIso8601String(),
          'is_deleted': row.isDeleted,
          // Cố ý luôn gửi, kể cả null: trận bỏ giải thì xoá liên kết trên server.
          'tournament_id': row.tournamentId,
          'round_label': row.roundLabel,
        },
        rejectedKey: key,
        userId: userId,
      );
      if (!ok) continue;
      await _db.transaction(() async {
        final current = await (_db.select(
          _db.poolMatchRows,
        )..where((r) => r.id.equals(row.id))).getSingleOrNull();
        if (current == null ||
            current.userId != row.userId ||
            current.updatedAt != row.updatedAt ||
            current.isDeleted != row.isDeleted) {
          return;
        }
        await (_db.update(
          _db.poolMatchRows,
        )..where((r) => r.id.equals(row.id))).write(
          PoolMatchRowsCompanion(
            updatedAt: Value(row.updatedAt ?? sentAt),
            syncedAt: Value(_now()),
          ),
        );
      });
    }

    final receivedAt = _now();
    for (final item in remoteItems) {
      _checkAlive();
      _checkUser(userId);
      final remote = _matchFromRemote(item, userId: userId, syncedAt: receivedAt);
      final remoteUpdatedAt = remoteInstant(item, 'updated_at');
      await _db.transaction(() async {
        final local = await (_db.select(
          _db.poolMatchRows,
        )..where((r) => r.id.equals(remote.id.value))).getSingleOrNull();
        _checkAlive();
        _checkUser(userId);
        if (local != null && local.userId != userId) {
          throw const FormatException('ID trận bị trùng giữa các tài khoản');
        }
        if (local?.updatedAt != null &&
            local!.updatedAt!.isAfter(remoteUpdatedAt)) {
          return;
        }
        await _db.into(_db.poolMatchRows).insertOnConflictUpdate(remote);
      });
    }
  }

  PoolMatchRowsCompanion _matchFromRemote(
    Map<String, Object?> item, {
    required String userId,
    required DateTime syncedAt,
  }) {
    final m = poolMatchFromRemote(item);
    return PoolMatchRowsCompanion(
      id: Value(m.id),
      userId: Value(userId),
      gameType: Value(m.gameType),
      playerName: Value(m.playerName),
      opponentName: Value(m.opponentName),
      targetRacks: Value(m.targetRacks),
      rackWinners: Value(m.rackWinnersJson),
      shots: Value(m.shotsJson),
      cueId: Value(m.cueId),
      startedAt: Value(m.startedAt),
      completedAt: Value(m.completedAt),
      updatedAt: Value(m.updatedAtUtc),
      isDeleted: Value(m.isDeleted),
      tournamentId: Value(m.tournamentId),
      roundLabel: Value(m.roundLabel),
      syncedAt: Value(syncedAt),
    );
  }

  // ─── Buổi tập tự do (chỉ thêm) ──────────────────────────────────────────

  Future<void> _syncTimerSessions(String userId) async {
    final remoteItems = await _fetch(_timersPath, timerSessionRemoteFields, userId);
    final pending = await (_db.select(_db.timerSessionRows)
          ..where((r) => r.userId.equals(userId) & r.syncedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.date)]))
        .get();

    for (final row in pending) {
      _checkAlive();
      _checkUser(userId);
      final key = 'timer:${row.id}:${row.userId}:';
      if (_rejected.contains(key)) continue;
      final ok = await _upsert(
        path: _timersPath,
        id: row.id,
        exists: false,
        addOnly: true,
        body: {
          'id': row.id,
          'date': row.date.toUtc().toIso8601String(),
          'duration_sec': row.durationSec,
          // Tên nhóm nâng cao chỉ đi trong cat_ext; bản đã phát hành ném khi
          // gặp tên lạ ở cat.
          'cat': splitCategoryName(row.cat).legacy,
          'cat_ext': splitCategoryName(row.cat).ext,
          'cue_id': row.cueId,
        },
        rejectedKey: key,
        userId: userId,
      );
      if (!ok) continue;
      await (_db.update(_db.timerSessionRows)
            ..where((r) => r.id.equals(row.id) & r.userId.equals(userId)))
          .write(TimerSessionRowsCompanion(syncedAt: Value(_now())));
    }

    final receivedAt = _now();
    for (final item in remoteItems) {
      _checkAlive();
      _checkUser(userId);
      final session = timerSessionFromRemote(item);
      final id = session.id;
      final duration = session.durationSec;
      final joinedCat = session.cat?.name;
      final date = session.date;
      final cueId = session.cueId;
      await _db.transaction(() async {
        final local = await (_db.select(
          _db.timerSessionRows,
        )..where((r) => r.id.equals(id))).getSingleOrNull();
        _checkAlive();
        _checkUser(userId);
        if (local != null) {
          if (local.userId != userId) {
            throw const FormatException(
              'ID buổi tập bị trùng giữa các tài khoản',
            );
          }
          return; // Chỉ thêm: bản trên máy luôn giữ nguyên.
        }
        await _db.into(_db.timerSessionRows).insert(
          TimerSessionRowsCompanion.insert(
            id: id,
            userId: Value(userId),
            date: date,
            durationSec: duration,
            cat: Value(joinedCat),
            cueId: Value(cueId),
            syncedAt: Value(receivedAt),
          ),
        );
      });
    }
  }

  // ─── Lịch tập tuần ──────────────────────────────────────────────────────

  Future<void> _syncSlots(String userId) async {
    final remoteItems = await _fetch(_slotsPath, scheduleSlotRemoteFields, userId);
    final remoteById = {for (final item in remoteItems) remoteString(item, 'id'): item};
    final pending = await (_db.select(_db.scheduleSlotRows)
          ..where((r) => r.userId.equals(userId) & r.syncedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.updatedAt)]))
        .get();

    for (final row in pending) {
      _checkAlive();
      _checkUser(userId);
      final key = 'slot:${row.id}:${_slotRevision(row)}';
      if (_rejected.contains(key)) continue;
      final remote = remoteById[row.id];
      final localUpdatedAt = row.updatedAt;
      if (remote != null &&
          (localUpdatedAt == null ||
              !localUpdatedAt.isAfter(remoteInstant(remote, 'updated_at')))) {
        continue;
      }
      final sentAt = localUpdatedAt ?? _now();
      final ok = await _upsert(
        path: _slotsPath,
        id: row.id,
        exists: remote != null,
        body: {
          'id': row.id,
          'day': row.day,
          'time': row.time,
          'label': row.label,
          'cat': splitCategoryName(row.cat).legacy,
          'cat_ext': splitCategoryName(row.cat).ext,
          // Dấu thời gian của cat_ext: bằng updated_at khi bản mới ghi. Bản cũ
          // sửa dòng thì updated_at đổi mà trường này đứng yên, nên bản mới
          // biết cat_ext đã cũ (xem phần kéo bên dưới).
          'cat_ext_at': splitCategoryName(row.cat).ext == null
              ? null
              : sentAt.toUtc().toIso8601String(),
          'updated_at': sentAt.toUtc().toIso8601String(),
          'is_deleted': row.isDeleted,
        },
        rejectedKey: key,
        userId: userId,
      );
      if (!ok) continue;
      await _db.transaction(() async {
        final current = await (_db.select(
          _db.scheduleSlotRows,
        )..where((r) => r.id.equals(row.id))).getSingleOrNull();
        if (current == null ||
            current.userId != row.userId ||
            current.updatedAt != row.updatedAt ||
            current.isDeleted != row.isDeleted) {
          return;
        }
        await (_db.update(
          _db.scheduleSlotRows,
        )..where((r) => r.id.equals(row.id))).write(
          ScheduleSlotRowsCompanion(
            updatedAt: Value(row.updatedAt ?? sentAt),
            syncedAt: Value(_now()),
          ),
        );
      });
    }

    final receivedAt = _now();
    for (final item in remoteItems) {
      _checkAlive();
      _checkUser(userId);
      final decoded = scheduleSlotFromRemote(item);
      final id = decoded.slot.id;
      final day = decoded.slot.day;
      final time = decoded.slot.time;
      final label = decoded.slot.label;
      final deleted = decoded.isDeleted;
      final remoteUpdatedAt = decoded.updatedAtUtc;
      final joinedCat = decoded.slot.cat?.name;
      await _db.transaction(() async {
        final local = await (_db.select(
          _db.scheduleSlotRows,
        )..where((r) => r.id.equals(id))).getSingleOrNull();
        _checkAlive();
        _checkUser(userId);
        if (local != null && local.userId != userId) {
          throw const FormatException('ID lịch bị trùng giữa các tài khoản');
        }
        if (local?.updatedAt != null &&
            local!.updatedAt!.isAfter(remoteUpdatedAt)) {
          return;
        }
        await _db.into(_db.scheduleSlotRows).insertOnConflictUpdate(
          ScheduleSlotRowsCompanion(
            id: Value(id),
            userId: Value(userId),
            day: Value(day),
            time: Value(time),
            label: Value(label),
            cat: Value(joinedCat),
            updatedAt: Value(remoteUpdatedAt),
            syncedAt: Value(receivedAt),
            isDeleted: Value(deleted),
          ),
        );
      });
    }
  }

  // ─── Giải đấu ───────────────────────────────────────────────────────────
  // Song song với _syncSlots (cùng luật: bản sửa mới nhất thắng, xóa là
  // tombstone); mỗi loại có hàm riêng trong file này.

  Future<void> _syncTournaments(String userId) async {
    final remoteItems = await _fetch(
      _tournamentsPath,
      tournamentRemoteFields,
      userId,
    );
    final remoteById = {for (final item in remoteItems) remoteString(item, 'id'): item};
    final pending = await (_db.select(_db.tournamentRows)
          ..where((r) => r.userId.equals(userId) & r.syncedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.updatedAt)]))
        .get();

    for (final row in pending) {
      _checkAlive();
      _checkUser(userId);
      final key = 'tournament:${row.id}:${_tournamentRevision(row)}';
      if (_rejected.contains(key)) continue;
      final remote = remoteById[row.id];
      if (remote != null &&
          !row.updatedAt.isAfter(remoteInstant(remote, 'updated_at'))) {
        continue;
      }
      final ok = await _upsert(
        path: _tournamentsPath,
        id: row.id,
        exists: remote != null,
        body: toRemoteTournament(row),
        rejectedKey: key,
        userId: userId,
      );
      if (!ok) continue;
      await _db.transaction(() async {
        final current = await (_db.select(
          _db.tournamentRows,
        )..where((r) => r.id.equals(row.id))).getSingleOrNull();
        if (current == null ||
            current.userId != row.userId ||
            current.updatedAt != row.updatedAt ||
            current.isDeleted != row.isDeleted) {
          return;
        }
        await (_db.update(_db.tournamentRows)..where((r) => r.id.equals(row.id)))
            .write(TournamentRowsCompanion(syncedAt: Value(_now())));
      });
    }

    final receivedAt = _now();
    for (final item in remoteItems) {
      _checkAlive();
      _checkUser(userId);
      final remote = tournamentFromRemote(
        item,
        userId: userId,
        syncedAt: receivedAt,
      );
      final remoteUpdatedAt = remote.updatedAt.value;
      await _db.transaction(() async {
        final local = await (_db.select(
          _db.tournamentRows,
        )..where((r) => r.id.equals(remote.id.value))).getSingleOrNull();
        _checkAlive();
        _checkUser(userId);
        if (local != null && local.userId != userId) {
          throw const FormatException('ID giải bị trùng giữa các tài khoản');
        }
        if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) return;
        await _db.into(_db.tournamentRows).insertOnConflictUpdate(remote);
      });
    }
  }

  // ─── Dùng chung ─────────────────────────────────────────────────────────

  Future<List<Map<String, Object?>>> _fetch(
    String path,
    String fields,
    String userId,
  ) async {
    final token = await _tokenFor(userId);
    final result =
        await _api.get(path, token: token, query: {'limit': '-1', 'fields': fields})
            as List<Object?>;
    _checkAlive();
    _checkUser(userId);
    return result
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Directus trả bản ghi sai định dạng');
          }
          if (remoteOwner(item) != userId) {
            throw const FormatException(
              'Directus trả bản ghi không thuộc tài khoản hiện tại',
            );
          }
          return item;
        })
        .toList(growable: false);
  }

  /// Tạo hoặc cập nhật một bản ghi. Trả `false` khi server từ chối (4xx):
  /// bản ghi vẫn chờ và không bị gửi lại cho tới khi nó đổi.
  Future<bool> _upsert({
    required String path,
    required String id,
    required bool exists,
    required Map<String, Object?> body,
    required String rejectedKey,
    required String userId,
    bool addOnly = false,
  }) async {
    final patchBody = Map<String, Object?>.of(body)..remove('id');
    final itemPath = '$path/${Uri.encodeComponent(id)}';
    try {
      if (exists) {
        await _api.patch(
          itemPath,
          token: await _tokenFor(userId),
          body: patchBody,
        );
      } else {
        try {
          await _api.post(path, token: await _tokenFor(userId), body: body);
        } on DirectusError catch (error) {
          if (error.code != _duplicateCode) rethrow;
          // Máy khác của cùng người đã ghi bản ghi này.
          if (!addOnly) {
            await _api.patch(
              itemPath,
              token: await _tokenFor(userId),
              body: patchBody,
            );
          }
        }
      }
      _checkAlive();
      _checkUser(userId);
      return true;
    } on DirectusError catch (error) {
      if (error.status >= 400 && error.status < 500 && error.status != 401) {
        _rejected.add(rejectedKey);
        return false;
      }
      rethrow;
    }
  }

  String _matchRevision(PoolMatchRow row) =>
      '${row.userId}:${row.updatedAt?.toIso8601String() ?? "unversioned"}:'
      '${row.isDeleted}';

  String _slotRevision(ScheduleSlotRow row) =>
      '${row.userId}:${row.updatedAt?.toIso8601String() ?? "unversioned"}:'
      '${row.isDeleted}';

  String _tournamentRevision(TournamentRow r) =>
      '${r.userId}:${r.updatedAt.toIso8601String()}:${r.isDeleted}';

  /// Dòng không có chủ (`:` đứng đầu) không bao giờ khớp người đang đăng nhập.
  bool _isCurrentOwner(String revision) {
    final userId = switch (_auth.current) {
      SignedIn(:final userId) => userId,
      SignedOut() => null,
    };
    return userId != null && revision.startsWith('$userId:');
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
    SignedIn(userId: final id) => id == userId,
    SignedOut() => false,
  };

  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    _checkUser(userId);
    return token;
  }

  void _checkUser(String userId) {
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
  }

  void _checkAlive() {
    if (_disposed) throw const _Stopped();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSubscription?.cancel();
    for (final subscription in _pendingSubscriptions) {
      subscription.cancel();
    }
  }
}
