import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/domain/maintenance_schedule.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Bản thật của [NotificationScheduler] trên Android/iOS.
///
/// Dùng lịch "không chính xác" (inexactAllowWhileIdle): Android có thể
/// lệch vài phút nhưng không cần quyền báo thức chính xác.
class LocalNotificationsScheduler implements NotificationScheduler {
  LocalNotificationsScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'cue_maintenance';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Quyền xin sau, khi người dùng bấm "Bật thông báo".
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureInit();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final options = await ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInit();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> replaceAll(List<MaintenanceReminder> reminders) async {
    await _ensureInit();
    await _plugin.cancelAll();
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: Vi.equipmentNotificationTitle,
        body: Vi.equipmentNotificationBody(r.cueName, r.daysBefore),
        scheduledDate: tz.TZDateTime(
          tz.local,
          r.at.year,
          r.at.month,
          r.at.day,
          r.at.hour,
          r.at.minute,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            Vi.equipmentNotificationTitle,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();
  }
}
