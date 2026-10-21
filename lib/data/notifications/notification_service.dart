import 'dart:async';

import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Giữ thông báo của người đang đăng nhập khớp với dữ liệu của họ.
///
/// Nguồn sự thật là [planNotifications]. Android/iOS: mỗi lần dữ liệu
/// hoặc cài đặt đổi, đối chiếu lịch của hệ điều hành với kế hoạch
/// ([reconcileNotifications]). Web: trình duyệt không đặt lịch được, nên
/// một timer xem kế hoạch mỗi phút và báo cái nào đến giờ, ghi lại vào
/// localStorage để không báo hai lần. Đăng xuất thì huỷ hết.
class NotificationService {
  NotificationService({
    required this._db,
    required this._auth,
    required this._now,
    NotificationPlatform? platform,
    this._checkEvery = const Duration(minutes: 1),
  }) : _platform = platform ?? createNotificationPlatform();

  final AppDatabase _db;
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

  /// Đổi cài đặt loại thông báo. Null: chưa nạp xong.
  void setPrefs(NotificationPrefs? prefs) {
    if (_prefs == prefs) return;
    _prefs = prefs;
    if (_started && !_disposed) checkNow();
  }

  NotificationScheduler? get _scheduler => _platform.scheduler;

  late final Future<void> _permissionLoaded = _platform.loadPermission();
  Future<void> _syncChain = Future.value();

  List<PlannedNotification> _plan(DateTime now, {int? limit}) {
    final prefs = _prefs;
    if (prefs == null) return const [];
    return planNotifications(
      cues: _cues,
      slots: _slots,
      streak: streakStateOf(
        logs: _logs,
        timerSessions: _timerSessions,
        today: now,
      ),
      prefs: prefs,
      now: now,
      limit: limit ?? maxPendingNotifications,
    );
  }

  /// Android/iOS: đưa lịch của hệ điều hành về đúng kế hoạch. Xếp hàng để
  /// hai lần đồng bộ không chạy chồng lên nhau.
  void _syncSchedule(NotificationScheduler scheduler) {
    _syncChain = _syncChain.then((_) async {
      await _permissionLoaded;
      if (_disposed) return;
      final userId = _userId;
      if (userId == null) {
        await scheduler.cancelAll();
      } else if (_prefs != null && _platform.permission == 'granted') {
        await reconcileNotifications(scheduler, _plan(_now().toLocal()));
      }
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
    // Từ đầu ngày: kế hoạch chỉ giữ cái còn ở phía sau "bây giờ", mà web
    // cần cả cái đã đến giờ trong hôm nay.
    final startOfDay = DateTime(now.year, now.month, now.day);
    for (final n in _plan(startOfDay, limit: 1 << 20)) {
      if (n.at.isAfter(now) || !now.isBefore(n.validUntil)) continue;
      final key = _storageKey(n);
      if (_platform.readValue(key) != null) continue;
      _platform.show(title: n.title, body: n.body, tag: key);
      _platform.writeValue(key, now.toIso8601String());
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
    _userId = userId;
    _cues = const [];
    _slots = const [];
    _logs = const [];
    _timerSessions = const [];
    for (final subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
    _dataSubscriptions.clear();
    if (userId == null || _disposed) {
      if (_started) checkNow(); // đăng xuất: huỷ lịch đã đặt
      return;
    }

    void watch<T>(Stream<T> stream, void Function(T value) assign) {
      _dataSubscriptions.add(
        stream.listen((value) {
          if (_userId != userId || _disposed) return;
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
