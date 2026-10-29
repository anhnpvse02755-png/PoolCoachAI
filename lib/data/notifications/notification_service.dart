import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncError, AsyncLoading, AsyncValue;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_schedule_version_store.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Giữ thông báo của người đang đăng nhập khớp với dữ liệu của họ.
///
/// Nguồn sự thật là [planNotifications]. Android/iOS: mỗi lần dữ liệu
/// hoặc cài đặt đổi, đối chiếu lịch của hệ điều hành với kế hoạch
/// ([reconcileNotifications]). Web: trình duyệt không đặt lịch được, nên
/// một timer xem kế hoạch mỗi phút và báo cái nào đến giờ, ghi lại vào
/// localStorage để không báo hai lần. Đăng xuất thì huỷ hết.
///
/// Nhật ký thông báo (`notification_log_rows`) đi cùng: Android/iOS ghi
/// đúng kế hoạch đã đặt, web ghi lúc thông báo thật sự hiện. Mọi lần ghi
/// chỉ ghi phần khác, nên việc dịch vụ tự theo dõi nhật ký không lặp vòng.
class NotificationService {
  NotificationService({
    required this._db,
    required this._auth,
    required this._now,
    NotificationPlatform? platform,
    this._scheduleVersion,
    this._checkEvery = const Duration(minutes: 1),
  }) : _platform = platform ?? createNotificationPlatform();

  final AppDatabase _db;

  /// Null: không kiểm phiên bản đặt lịch (không bao giờ đặt lại hết).
  final NotificationScheduleVersionStore? _scheduleVersion;
  final AuthRepository _auth;
  final DateTime Function() _now;
  final NotificationPlatform _platform;
  final Duration _checkEvery;

  bool _started = false;
  bool _disposed = false;
  String? _userId;

  /// Null: cài đặt chưa nạp xong, chưa được báo gì (tránh báo loại đã tắt).
  NotificationPrefs? _prefs;
  List<CueEquipment> _cues = const [];
  List<ScheduleSlot> _slots = const [];
  List<DrillLog> _logs = const [];
  List<TimerSession> _timerSessions = const [];

  /// Nguồn gợi ý mới nhất Riverpod đưa tới: đang tải, lỗi hay sẵn sàng.
  /// Không xoá khi đổi tài khoản: nguồn sẵn sàng chỉ được dùng khi `userId`
  /// của nó là người đang đăng nhập.
  AsyncValue<RecommendationSource> _source = const AsyncLoading();

  /// Nhật ký của người đang đăng nhập; null tới lần phát đầu tiên.
  List<NotificationLogEntry>? _log;

  /// Số luồng dữ liệu của người hiện tại chưa phát lần đầu. Android/iOS chưa
  /// đồng bộ khi còn luồng chưa phát, kẻo kế hoạch thiếu dữ liệu huỷ rồi đặt
  /// lại thông báo đang chờ.
  int _awaitingFirst = 0;

  /// Đã có một lần đồng bộ xếp hàng chờ chạy (gộp các yêu cầu dồn dập).
  bool _syncQueued = false;

  /// Lúc phiên của người hiện tại bắt đầu trên tab/app này.
  DateTime _userSince = DateTime(0);
  StreamSubscription<AuthState>? _authSubscription;
  final _dataSubscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;

  bool get isSupported => _platform.isSupported;

  String? get permission => _platform.permission;

  /// Android/iOS: hệ điều hành giữ lịch kể cả khi app đóng. Web: chỉ khi
  /// app đang mở.
  bool get schedulesInBackground => _platform.scheduler != null;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (!_platform.isSupported) return;
    _platform.onTap = _onTapPayload;
    unawaited(
      _platform
          .takeLaunchPayload()
          .then((p) {
            if (p != null) _onTapPayload(p);
          })
          .catchError((Object _) {}),
    );
    _setUser(_signedInUserId);
    _authSubscription = _auth.watchSession().listen((state) {
      _setUser(switch (state) {
        SignedIn(:final userId) => userId,
        SignedOut() => null,
      });
    });
    // Android/iOS: hệ điều hành giữ lịch, không cần timer.
    if (_scheduler == null) {
      _timer = Timer.periodic(_checkEvery, (_) => checkNow());
    }
    checkNow();
  }

  void Function(NotificationTap tap)? _tapHandler;

  /// Lần chạm tới khi chưa có ai nhận (khởi động lạnh: thông báo mở app trước
  /// khi widget lắng nghe dựng xong).
  NotificationTap? _bufferedTap;

  /// Đặt nơi nhận lần chạm thông báo. Có lần chạm đang giữ thì giao đúng một
  /// lần rồi xoá.
  void setTapHandler(void Function(NotificationTap tap)? handler) {
    _tapHandler = handler;
    final buffered = _bufferedTap;
    if (handler != null && buffered != null) {
      _bufferedTap = null;
      handler(buffered);
    }
  }

  void _onTapPayload(String payload) {
    final tap = parseNotificationPayload(payload);
    if (tap == null || _disposed) return;
    final userId = _userId;
    if (userId != null) {
      unawaited(
        NotificationLogRepository(_db, userId: userId)
            .markReadByKey(tap.kind, tap.key, now: _now().toLocal())
            .catchError((Object _) {}),
      );
    }
    final handler = _tapHandler;
    if (handler != null) {
      handler(tap);
    } else {
      _bufferedTap = tap;
    }
  }

  /// Đổi cài đặt loại thông báo. Null: chưa nạp xong.
  void setPrefs(NotificationPrefs? prefs) {
    if (_prefs == prefs) return;
    _prefs = prefs;
    if (_started && !_disposed) checkNow();
  }

  /// Đổi nguồn gợi ý.
  ///
  /// - Sẵn sàng (của người đang đăng nhập): lập gợi ý từ nó.
  /// - Đang tải: Android/iOS giữ nguyên gợi ý đã đặt trong nhật ký.
  /// - Lỗi: bỏ gợi ý; các loại khác vẫn chạy.
  void setRecommendationSource(AsyncValue<RecommendationSource> source) {
    _source = source;
    if (_started && !_disposed) checkNow();
  }

  @visibleForTesting
  NotificationPrefs? get prefs => _prefs;

  @visibleForTesting
  AsyncValue<RecommendationSource> get recommendationSource => _source;

  NotificationScheduler? get _scheduler => _platform.scheduler;

  late final Future<void> _permissionLoaded = _platform.loadPermission();
  Future<void> _syncChain = Future.value();

  /// Lịch hệ điều hành do bản cũ đặt (thiếu thứ bản này cần) thì lần đồng bộ
  /// có quyền đầu tiên đặt lại hết. Đọc cờ lỗi thì coi như không cũ: thà
  /// thiếu payload còn hơn đặt lại mỗi lần mở app.
  late Future<bool> _scheduleOutdated = () async {
    final store = _scheduleVersion;
    if (store == null) return false;
    try {
      final version = await store.load();
      return version == null || version < notificationScheduleVersion;
    } on Object {
      return false;
    }
  }();

  Future<void> _markScheduleCurrent() async {
    _scheduleOutdated = Future.value(false);
    try {
      await _scheduleVersion?.save(notificationScheduleVersion);
    } on Object {
      // Không ghi được thì lần mở app sau đặt lại thêm một lần.
    }
  }

  /// Kế hoạch lúc [now]. [current] là nhật ký vừa đọc thẳng từ DB
  /// (Android/iOS); thiếu thì dùng bản của luồng theo dõi.
  List<PlannedNotification> _plan(
    DateTime now, {
    int? limit,
    List<NotificationLogEntry>? current,
  }) {
    final prefs = _prefs;
    if (prefs == null) return const [];
    final cap = limit ?? maxPendingNotifications;
    // Luồng nhật ký chưa phát lần nào: chưa có gì về gợi ý.
    final log = _log == null ? null : current ?? _log;
    final source = _source;
    // Nguồn sẵn sàng của tài khoản khác (Riverpod chưa kịp đổi theo) được coi
    // như đang tải: không dùng, nhưng cũng không huỷ gợi ý của người này.
    final mine = switch (source) {
      AsyncData(:final value) when value.userId == _userId => value,
      _ => null,
    };
    // Gợi ý chỉ khi nguồn là của người đang đăng nhập và nhật ký của họ đã
    // nạp (mốc "đã thấy" cần cả hai).
    final ready = log != null ? mine : null;
    // Android/iOS, nguồn chưa sẵn sàng (không lỗi): giữ gợi ý tương lai đã
    // đặt, để id y nguyên và lịch hệ điều hành lẫn nhật ký không bị đụng.
    final keep =
        log != null &&
        mine == null &&
        source is! AsyncError &&
        prefs.recommendation &&
        _scheduler != null;
    final plan = planNotifications(
      recommendation: ready?.inputs,
      lastSeenRecommendation: ready == null
          ? null
          : recommendationBaseline(
              shownOnHome: ready.seen,
              log: log!,
              now: _now().toLocal(),
            ),
      cues: _cues,
      slots: _slots,
      streak: streakStateOf(
        logs: _logs,
        timerSessions: _timerSessions,
        today: now,
      ),
      prefs: prefs,
      now: now,
      limit: keep ? 1 << 20 : cap,
    );
    if (!keep) return plan;
    return withLoggedRecommendations(plan, log, now: now, limit: cap);
  }

  /// Android/iOS: đưa lịch của hệ điều hành và nhật ký về đúng kế hoạch.
  /// Xếp hàng để hai lần đồng bộ không chạy chồng lên nhau; trong lúc một lần
  /// đang chạy, mọi yêu cầu mới gộp vào đúng một lần chờ (lần đó đọc trạng
  /// thái mới nhất lúc chạy).
  void _syncSchedule(NotificationScheduler scheduler) {
    if (_syncQueued) return;
    _syncQueued = true;
    _syncChain = _syncChain.then((_) async {
      _syncQueued = false;
      await _permissionLoaded;
      if (_disposed) return;
      final userId = _userId;
      if (userId == null) {
        await scheduler.cancelAll();
      } else if (_prefs != null && _awaitingFirst == 0) {
        final now = _now().toLocal();
        final log = NotificationLogRepository(_db, userId: userId);
        if (_platform.permission == 'granted') {
          // Kế hoạch đọc lại chính nhật ký nó ghi (gợi ý giữ lại, mốc đã
          // thấy), nên phải đọc bản hiện tại trong DB. Bản của luồng theo dõi
          // có thể chậm một lần ghi: lập từ nó thì lần này thêm lại cái lần
          // trước vừa xoá, luồng phát bản cũ, lần sau xoá lại… không dừng.
          final current = await log.all();
          if (_disposed || _userId != userId) return;
          final plan = _plan(now, current: current);
          final replaceAll = await _scheduleOutdated;
          if (_disposed || _userId != userId) return;
          // Quá giờ mà hệ điều hành còn chờ (giao muộn) thì để yên trong
          // ngày; cái nào bị huỷ khi chưa hiện thì xoá dòng của nó.
          final cancelled = await reconcileNotifications(
            scheduler,
            plan,
            keep: dueEarlierToday(current, now),
            replaceAll: replaceAll,
          );
          await log.syncPlanned(plan, now: now, cancelled: cancelled);
          if (replaceAll) await _markScheduleCurrent();
        } else {
          // Không có quyền thì không đặt gì: nhật ký không giữ mục tương lai.
          await log.syncPlanned(const [], now: now);
        }
      }
    }).catchError((Object _) {});
  }

  /// Android/iOS: người dùng vừa rời [userId] (đăng xuất, tự đăng xuất, đổi
  /// mật khẩu, đổi thẳng tài khoản). Lịch của họ sắp bị huỷ (chạy trước lần
  /// đồng bộ huỷ nó), nên xoá các mục tương lai trong nhật ký của họ, và cả
  /// mục đã quá giờ mà hệ điều hành còn chờ (chưa hiện), kẻo hộp "Đã gửi"
  /// liệt kê cái chưa từng được gửi.
  void _forgetFuture(String userId, NotificationScheduler scheduler) {
    _syncChain = _syncChain.then((_) async {
      if (_disposed) return;
      final pending = await scheduler.pendingIds();
      await NotificationLogRepository(
        _db,
        userId: userId,
      ).syncPlanned(const [], now: _now().toLocal(), cancelled: pending);
    }).catchError((Object _) {});
  }

  Future<String?> requestPermission() async {
    if (!_platform.isSupported) return null;
    final result = await _platform.requestPermission();
    checkNow();
    return result;
  }

  void checkNow() {
    final scheduler = _scheduler;
    if (scheduler != null) {
      if (!_disposed) _syncSchedule(scheduler);
      return;
    }
    if (_disposed ||
        _userId == null ||
        _prefs == null ||
        !_platform.isSupported ||
        _platform.permission != 'granted') {
      return;
    }
    final now = _now().toLocal();
    final log = NotificationLogRepository(_db, userId: _userId!);
    // Từ đầu ngày: kế hoạch chỉ giữ cái còn ở phía sau "bây giờ", mà web
    // cần cả cái đã đến giờ trong hôm nay.
    final startOfDay = DateTime(now.year, now.month, now.day);
    for (final n in _plan(startOfDay, limit: 1 << 20)) {
      if (n.at.isAfter(now) || !now.isBefore(n.validUntil)) continue;
      // Gợi ý của lúc trước khi mở tab (hay đăng nhập) là thứ Trang chủ
      // đang hiện: không báo lại.
      if (n.kind == NotificationKind.recommendation &&
          !n.at.isAfter(_userSince)) {
        continue;
      }
      final key = _storageKey(n);
      if (_platform.readValue(key) != null) continue;
      _platform.show(
        title: n.title,
        body: n.body,
        tag: key,
        payload: notificationPayload(n.kind, n.key),
      );
      _platform.writeValue(key, now.toIso8601String());
      unawaited(log.recordShown(n, at: now).catchError((Object _) {}));
    }
  }

  /// Khoá bảo dưỡng giữ nguyên dạng cũ để người đã được báo không bị báo
  /// lại sau khi nâng cấp.
  String _storageKey(PlannedNotification n) => switch (n.kind) {
    NotificationKind.maintenance =>
      'poolcoachai:maintenance:v1:$_userId:${n.key}',
    _ => 'poolcoachai:notification:v1:$_userId:${n.kind.name}:${n.key}',
  };

  String? get _signedInUserId => switch (_auth.current) {
    SignedIn(:final userId) => userId,
    SignedOut() => null,
  };

  void _setUser(String? userId) {
    if (_userId == userId) return;
    final previous = _userId;
    _userId = userId;
    _userSince = _now().toLocal();
    _cues = const [];
    _slots = const [];
    _logs = const [];
    _timerSessions = const [];
    _log = null;
    _awaitingFirst = 0;
    final scheduler = _scheduler;
    if (previous != null && scheduler != null && !_disposed) {
      _forgetFuture(previous, scheduler);
    }
    for (final subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
    _dataSubscriptions.clear();
    if (userId == null || _disposed) {
      if (_started) checkNow(); // đăng xuất: huỷ lịch đã đặt
      return;
    }

    void watch<T>(Stream<T> stream, void Function(T value) assign) {
      var first = true;
      _awaitingFirst++;
      _dataSubscriptions.add(
        stream.listen((value) {
          if (_userId != userId || _disposed) return;
          if (first) {
            first = false;
            _awaitingFirst--;
          }
          assign(value);
          checkNow();
        }),
      );
    }

    watch(
      DriftCueEquipmentRepository(_db, userId: userId, now: _now).watchAll(),
      (cues) => _cues = cues,
    );
    watch(
      DriftScheduleRepository(_db, userId: userId, now: _now).watchAll(),
      (slots) => _slots = slots,
    );
    watch(
      DriftDrillLogRepository(_db, userId: userId).watchAll(),
      (logs) => _logs = logs,
    );
    watch(
      DriftTimerSessionRepository(_db, userId: userId).watchAll(),
      (sessions) => _timerSessions = sessions,
    );
    watch(
      NotificationLogRepository(_db, userId: userId).watchAll(),
      (log) => _log = log,
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_authSubscription?.cancel());
    for (final subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
