import 'dart:async';

import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/data/notifications/notification_settings_meta_store.dart';
import 'package:poolcoachai/data/notifications/recommendation_seen_store.dart';
import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ cài đặt thông báo và cặp gợi ý đã thấy với dòng
/// `notification_settings` của người chơi (id = id người dùng).
///
/// Hai nhóm độc lập: công tắc (bản có `prefs_updated_at` mới hơn thắng) và cặp
/// đã thấy (bản có `at` mới hơn thắng). Máy chủ cần dòng này để biết cài đặt
/// của từng người và để gia hạn thiết bị đẩy, nên lượt đầu sau đăng nhập tạo
/// dòng ngay; [syncNow] trả kết quả để chỗ đăng ký thiết bị chờ được.
class NotificationSettingsSyncService {
  NotificationSettingsSyncService({
    required this._auth,
    required this._api,
    required this._prefs,
    required this._seen,
    required this._meta,
    required this._now,
    required this._timeZone,
    required this._onAdopted,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AuthRepository _auth;
  final DirectusClient _api;
  final NotificationPrefsStore _prefs;
  final RecommendationSeenStore _seen;
  final NotificationSettingsMetaStore _meta;
  final DateTime Function() _now;
  final String? Function() _timeZone;
  final void Function(
    String userId, {
    NotificationPrefs? prefs,
    SeenRecommendation? seen,
  })
  _onAdopted;
  final Duration _retryEvery;

  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  Future<void> _metaQueue = Future.value();
  bool _dirty = false;
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSub = _auth.watchSession().listen((s) {
      if (s is SignedIn) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_dirty) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  /// Một lượt đồng bộ (gộp các lời gọi chồng nhau). Không bao giờ ném.
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

  /// Công tắc vừa đổi trên máy này.
  Future<void> localPrefsChanged(String userId) async {
    await _mutate(
      userId,
      (m) => NotificationSettingsMeta(
        prefsUpdatedAt: _now(),
        prefsDirty: true,
        seenDirty: m.seenDirty,
      ),
    );
    _dirty = true;
    if (_started) unawaited(syncNow());
  }

  /// Cặp gợi ý đã thấy vừa đổi trên máy này.
  Future<void> localSeenChanged(String userId) async {
    await _mutate(
      userId,
      (m) => NotificationSettingsMeta(
        prefsUpdatedAt: m.prefsUpdatedAt,
        prefsDirty: m.prefsDirty,
        seenDirty: true,
      ),
    );
    _dirty = true;
    if (_started) unawaited(syncNow());
  }

  /// Đọc-sửa-ghi dấu vết theo hàng đợi, để hai lần sửa chồng nhau không mất
  /// nhau. Không ghi khi kết quả không đổi.
  Future<NotificationSettingsMeta> _mutate(
    String userId,
    NotificationSettingsMeta Function(NotificationSettingsMeta) change,
  ) => _enqueue(() async {
    final before = await _meta.load(userId);
    final after = change(before);
    if (after != before) await _meta.save(userId, after);
    return after;
  });

  /// Chạy [op] sau mọi việc đã xếp hàng trước nó.
  Future<T> _enqueue<T>(Future<T> Function() op) {
    final result = _metaQueue.then((_) => op());
    _metaQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<SyncOutcome> _once() async {
    if (_disposed) return SyncOutcome.stopped;
    final who = _auth.current;
    if (who is! SignedIn) return SyncOutcome.signedOut;
    final userId = who.userId;
    try {
      _dirty = await _pass(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (f) {
      _dirty = true;
      return switch (f) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      _dirty = true;
      return SyncOutcome.offline;
    } on Object {
      // syncNow() chạy từ timer: không bao giờ ném.
      _dirty = true;
      return SyncOutcome.failed;
    }
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
    SignedIn(userId: final id) => id == userId,
    SignedOut() => false,
  };

  void _checkAlive(String userId) {
    if (_disposed) throw const _Stopped();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
  }

  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    _checkAlive(userId);
    return token;
  }

  Future<Map<String, Object?>?> _fetch(String userId) async {
    final token = await _tokenFor(userId);
    final items =
        await _api.get(
              '/items/notification_settings',
              token: token,
              query: {
                'filter[id][_eq]': userId,
                'fields': notificationSettingsRemoteFields,
                'limit': '1',
              },
            )
            as List<Object?>;
    _checkAlive(userId);
    return items.isEmpty ? null : items.first! as Map<String, Object?>;
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static Map<String, Object?> _prefsBody(NotificationPrefs p) => {
    'recommendation': p.recommendation,
    'maintenance': p.maintenance,
    'schedule': p.schedule,
    'streak': p.streak,
  };

  static Map<String, Object?> _seenBody(SeenRecommendation? s) => {
    'last_seen_cat': s?.cat.name,
    'last_seen_drill_id': s?.drillId,
    'last_seen_at': _iso(s?.at),
  };

  static DateTime? _remoteTime(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static NotificationPrefs _remotePrefs(Map<String, Object?> r) {
    bool flag(String k) => r[k] is bool ? r[k]! as bool : true;
    return NotificationPrefs(
      recommendation: flag('recommendation'),
      maintenance: flag('maintenance'),
      schedule: flag('schedule'),
      streak: flag('streak'),
    );
  }

  static SeenRecommendation? _remoteSeen(Map<String, Object?> r) {
    final cat = r['last_seen_cat'];
    final drill = r['last_seen_drill_id'];
    final at = _remoteTime(r['last_seen_at']);
    if (cat is! String || drill is! String || drill.isEmpty || at == null) {
      return null;
    }
    for (final c in SkillCategory.values) {
      if (c.name == cat) {
        return SeenRecommendation(cat: c, drillId: drill, at: at);
      }
    }
    return null;
  }

  static bool _sameSeen(SeenRecommendation? a, SeenRecommendation? b) =>
      a == null || b == null
      ? a == b
      : a.sameAs(b.cat, b.drillId) && a.at.isAtSameMomentAs(b.at);

  /// Có mốc gửi gợi ý (08:00 giờ máy) nào trong khoảng ([from], [to]] không.
  /// Cùng một cặp được thấy lại sau mốc đó thì bản trên server phải cập nhật,
  /// kẻo nền tảng của server lệch với máy (một lần mỗi ngày là cùng).
  static bool _crossesReminder(DateTime from, DateTime to) {
    final end = to.toLocal();
    var boundary = DateTime(
      end.year,
      end.month,
      end.day,
      recommendationReminderHour,
    );
    if (boundary.isAfter(end)) {
      boundary = DateTime(
        end.year,
        end.month,
        end.day - 1,
        recommendationReminderHour,
      );
    }
    return from.isBefore(boundary);
  }

  static bool _sameMoment(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : a.isAtSameMomentAs(b);

  /// Một lượt cho [userId]. Trả true khi còn phần chưa lên server (để hẹn thử
  /// lại).
  Future<bool> _pass(String userId) async {
    var remote = await _fetch(userId);
    final meta = await _meta.load(userId);
    final prefs = await _prefs.load(userId);
    final seen = await _seen.load(userId);
    _checkAlive(userId);

    if (remote == null) {
      final sentAt = meta.prefsUpdatedAt ?? _now();
      final token = await _tokenFor(userId);
      try {
        await _api.post(
          '/items/notification_settings',
          token: token,
          body: {
            'id': userId,
            ..._prefsBody(prefs),
            'prefs_updated_at': _iso(sentAt),
            ..._seenBody(seen),
            'timezone': _timeZone(),
          },
        );
        _checkAlive(userId);
        return await _settle(userId, prefsAt: sentAt, seenAt: seen?.at);
      } on DirectusError catch (e) {
        if (e.code != _duplicateCode) rethrow;
      }
      // Máy khác vừa tạo trước: đọc lại rồi gộp như dòng đã có.
      remote = await _fetch(userId);
      if (remote == null) return true;
    }

    final patch = <String, Object?>{};
    var prefsAt = meta.prefsUpdatedAt;
    var seenAt = seen?.at;
    var pending = false;

    // Nhóm công tắc.
    final remotePrefsAt = _remoteTime(remote['prefs_updated_at']);
    final localAt = meta.prefsUpdatedAt;
    if (meta.prefsDirty &&
        localAt != null &&
        (remotePrefsAt == null || remotePrefsAt.isBefore(localAt))) {
      patch
        ..addAll(_prefsBody(prefs))
        ..['prefs_updated_at'] = _iso(localAt);
    } else if (remotePrefsAt != null &&
        (localAt == null || remotePrefsAt.isAfter(localAt))) {
      final adopted = _remotePrefs(remote);
      // Một việc trên hàng đợi: đọc lại dấu vết và công tắc, và bỏ nhận nếu
      // người chơi vừa đổi trong lúc lượt chạy (lượt sau sẽ đẩy bản của họ).
      final applied = await _enqueue(() async {
        final m = await _meta.load(userId);
        final cur = await _prefs.load(userId);
        if (m.prefsDirty != meta.prefsDirty ||
            !_sameMoment(m.prefsUpdatedAt, meta.prefsUpdatedAt) ||
            cur != prefs) {
          return false;
        }
        await _meta.save(
          userId,
          NotificationSettingsMeta(
            prefsUpdatedAt: remotePrefsAt,
            seenDirty: m.seenDirty,
          ),
        );
        if (adopted != cur) await _prefs.save(userId, adopted);
        return true;
      });
      _checkAlive(userId);
      if (applied) {
        if (adopted != prefs) _onAdopted(userId, prefs: adopted);
        prefsAt = remotePrefsAt;
      } else {
        pending = true;
      }
    }

    // Nhóm cặp đã thấy: bản có `at` mới hơn thắng.
    final remoteSeen = _remoteSeen(remote);
    if (seen != null &&
        (remoteSeen == null ||
            (remoteSeen.sameAs(seen.cat, seen.drillId)
                ? seen.at.isAfter(remoteSeen.at) &&
                      _crossesReminder(remoteSeen.at, seen.at)
                : seen.at.isAfter(remoteSeen.at)))) {
      patch.addAll(_seenBody(seen));
    } else if (remoteSeen != null &&
        (seen == null ||
            (!seen.sameAs(remoteSeen.cat, remoteSeen.drillId) &&
                remoteSeen.at.isAfter(seen.at)))) {
      final applied = await _enqueue(() async {
        final cur = await _seen.load(userId);
        if (!_sameSeen(cur, seen)) return false;
        await _seen.save(userId, remoteSeen);
        return true;
      });
      _checkAlive(userId);
      if (applied) {
        _onAdopted(userId, seen: remoteSeen);
        seenAt = remoteSeen.at;
      } else {
        pending = true;
      }
    }

    // Múi giờ.
    final tz = _timeZone();
    if (tz != null && remote['timezone'] != tz) patch['timezone'] = tz;

    if (patch.isNotEmpty) {
      await _api.patch(
        '/items/notification_settings/$userId',
        token: await _tokenFor(userId),
        body: patch,
      );
      _checkAlive(userId);
    }
    final stillDirty = await _settle(userId, prefsAt: prefsAt, seenAt: seenAt);
    return stillDirty || pending;
  }

  /// Bỏ cờ "bẩn" của phần vừa khớp server, nhưng chỉ khi trong lúc chờ người
  /// chơi chưa đổi tiếp. Trả true khi vẫn còn cờ bẩn.
  Future<bool> _settle(
    String userId, {
    required DateTime? prefsAt,
    required DateTime? seenAt,
  }) async {
    final current = await _seen.load(userId);
    final seenUnchanged = _sameMoment(current?.at, seenAt);
    final after = await _mutate(userId, (m) {
      final prefsUnchanged =
          m.prefsUpdatedAt == null || _sameMoment(m.prefsUpdatedAt, prefsAt);
      return NotificationSettingsMeta(
        prefsUpdatedAt: m.prefsUpdatedAt ?? prefsAt,
        prefsDirty: m.prefsDirty && !prefsUnchanged,
        seenDirty: m.seenDirty && !seenUnchanged,
      );
    });
    return after.prefsDirty || after.seenDirty;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSub?.cancel();
  }
}
