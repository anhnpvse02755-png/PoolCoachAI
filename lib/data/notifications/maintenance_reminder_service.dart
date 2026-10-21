import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/maintenance_notification_platform.dart';
import 'package:poolcoachai/data/notifications/maintenance_scheduler.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/maintenance_schedule.dart';

class MaintenanceReminderService {
  MaintenanceReminderService({
    required this._db,
    required this._auth,
    required this._now,
    MaintenanceNotificationPlatform? platform,
    this._checkEvery = const Duration(minutes: 1),
  }) : _platform = platform ?? createMaintenanceNotificationPlatform();

  final AppDatabase _db;
  final AuthRepository _auth;
  final DateTime Function() _now;
  final MaintenanceNotificationPlatform _platform;
  final Duration _checkEvery;

  bool _started = false;
  bool _disposed = false;
  String? _userId;
  List<CueEquipment> _cues = const [];
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<CueEquipmentRow>>? _equipmentSubscription;
  Timer? _timer;

  bool get isSupported => _platform.isSupported;

  String? get permission => _platform.permission;

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

  MaintenanceScheduler? get _scheduler => _platform.scheduler;

  late final Future<void> _permissionLoaded = _platform.loadPermission();
  Future<void> _syncChain = Future.value();

  /// Android/iOS: đặt lại toàn bộ lịch theo danh sách cơ hiện tại. Xếp
  /// hàng để hai lần đặt không chạy chồng lên nhau.
  void _syncSchedule(MaintenanceScheduler scheduler) {
    _syncChain = _syncChain.then((_) async {
      await _permissionLoaded;
      if (_disposed) return;
      final userId = _userId;
      if (userId == null) {
        await scheduler.cancelAll();
      } else if (_platform.permission == 'granted') {
        await scheduler.replaceAll(
          computeMaintenanceSchedule(_cues, now: _now().toLocal()),
        );
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
        !_platform.isSupported ||
        _platform.permission != 'granted') {
      return;
    }
    final now = _now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    for (final cue in _cues) {
      final dueDate = cue.tipMaintenanceDueDate;
      if (dueDate == null) continue;
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      for (final daysBefore in [7, 0]) {
        final notifyDay = dueDay.subtract(Duration(days: daysBefore));
        if (notifyDay != today ||
            now.isBefore(DateTime(now.year, now.month, now.day, 9))) {
          continue;
        }
        final key = _storageKey(cue.id, dueDay, daysBefore);
        if (_platform.readValue(key) != null) continue;
        _platform.show(
          title: Vi.equipmentNotificationTitle,
          body: Vi.equipmentNotificationBody(cue.name, daysBefore),
          tag: key,
        );
        _platform.writeValue(key, now.toIso8601String());
      }
    }
  }

  String _storageKey(String cueId, DateTime dueDay, int daysBefore) =>
      'poolcoachai:maintenance:v1:$_userId:$cueId:'
      '${dueDay.year}-${dueDay.month}-${dueDay.day}:$daysBefore';

  String? get _signedInUserId => switch (_auth.current) {
    SignedIn(:final userId) => userId,
    SignedOut() => null,
  };

  void _setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _cues = const [];
    unawaited(_equipmentSubscription?.cancel());
    if (userId == null || _disposed) {
      if (_started) checkNow(); // đăng xuất: huỷ lịch đã đặt
      return;
    }
    _equipmentSubscription =
        (_db.select(_db.cueEquipmentRows)..where(
              (row) => row.userId.equals(userId) & row.isDeleted.equals(false),
            ))
            .watch()
            .listen((rows) {
              if (_userId != userId || _disposed) return;
              _cues = rows.map(toCueEquipment).toList(growable: false);
              checkNow();
            });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_authSubscription?.cancel());
    unawaited(_equipmentSubscription?.cancel());
  }
}
