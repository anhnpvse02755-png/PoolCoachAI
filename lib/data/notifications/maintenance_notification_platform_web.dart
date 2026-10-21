import 'dart:js_interop';

import 'package:poolcoachai/data/notifications/maintenance_scheduler.dart';
import 'package:web/web.dart' as web;

@JS('globalThis.Notification')
external JSFunction? get _browserNotification;

class MaintenanceNotificationPlatform {
  // ignore: avoid_unused_constructor_parameters
  MaintenanceNotificationPlatform({MaintenanceScheduler? scheduler});

  /// Trình duyệt không đặt lịch được: dịch vụ tự kiểm tra bằng timer.
  MaintenanceScheduler? get scheduler => null;

  Future<void> refresh() async {}

  bool get isSupported => _browserNotification != null;

  String? get permission => isSupported ? web.Notification.permission : null;

  Future<String?> requestPermission() async {
    if (!isSupported) return null;
    return (await web.Notification.requestPermission().toDart).toDart;
  }

  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    web.Notification(title, web.NotificationOptions(body: body, tag: tag));
  }

  String? readValue(String key) => web.window.localStorage.getItem(key);

  void writeValue(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }
}

MaintenanceNotificationPlatform createMaintenanceNotificationPlatform() =>
    MaintenanceNotificationPlatform();
