import 'dart:io' show Platform;

import 'package:poolcoachai/data/notifications/local_notifications_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';

/// Android/iOS: hệ điều hành tự giữ lịch thông báo, nên không cần
/// show/readValue — dịch vụ đặt lịch qua [scheduler]. Trên desktop/test
/// (không phải Android/iOS) không có scheduler nên coi như không hỗ trợ.
class NotificationPlatform {
  NotificationPlatform({NotificationScheduler? scheduler})
    : scheduler =
          scheduler ??
          (Platform.isAndroid || Platform.isIOS
              ? LocalNotificationsScheduler()
              : null);

  final NotificationScheduler? scheduler;
  String _permission = 'default';

  bool get isSupported => scheduler != null;

  String? get permission => _permission;

  /// Đọc quyền hiện tại của hệ điều hành vào [permission].
  Future<void> loadPermission() async {
    if (await scheduler!.hasPermission()) _permission = 'granted';
  }

  Future<String?> requestPermission() async {
    _permission = await scheduler!.requestPermission() ? 'granted' : 'denied';
    return _permission;
  }

  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    throw UnsupportedError('Native platforms schedule instead of showing');
  }

  String? readValue(String key) => null;

  void writeValue(String key, String value) {}
}

NotificationPlatform createNotificationPlatform() =>
    NotificationPlatform();
