import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Bản thật của [NotificationScheduler] trên Android/iOS.
///
/// Dùng lịch "không chính xác" (inexactAllowWhileIdle): Android có thể
/// lệch vài phút nhưng không cần quyền báo thức chính xác.
class LocalNotificationsScheduler implements NotificationScheduler {
  LocalNotificationsScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// 'cue_maintenance' giữ nguyên để kênh cũ của người đã cài vẫn dùng được.
  static String _channelId(NotificationKind kind) => switch (kind) {
    NotificationKind.recommendation => 'recommendation_reminder',
    NotificationKind.maintenance => 'cue_maintenance',
    NotificationKind.schedule => 'schedule_reminder',
    NotificationKind.streak => 'streak_reminder',
  };

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;
  void Function(String payload)? _onTap;

  @override
  set onTap(void Function(String payload)? handler) => _onTap = handler;

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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _onTap?.call(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
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
  Future<Set<int>> pendingIds() async {
    await _ensureInit();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> schedule(PlannedNotification notification) async {
    await _ensureInit();
    final at = notification.at;
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId(notification.kind),
          Vi.notificationKind(notification.kind),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notificationPayload(notification.kind, notification.key),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInit();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();
  }
}
