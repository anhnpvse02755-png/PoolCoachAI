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
              : null) {
    this.scheduler?.onTap = (payload) => onTap?.call(payload);
  }

  final NotificationScheduler? scheduler;

  /// Dịch vụ đặt vào đây để nhận lần chạm thông báo.
  void Function(String payload)? onTap;

  /// Chuỗi của thông báo đã mở app từ trạng thái đóng hẳn, nếu có.
  Future<String?> takeLaunchPayload() =>
      scheduler?.launchPayload() ?? Future.value();
  String _permission = 'default';

  bool get isSupported => scheduler != null;

  String? get permission => _permission;

  /// Đọc quyền hiện tại của hệ điều hành vào [permission]. Gọi lại được: quyền
  /// bị tắt trong Cài đặt thì 'granted' thành 'denied'.
  Future<void> loadPermission() async {
    final scheduler = this.scheduler;
    if (scheduler == null) return;
    if (await scheduler.hasPermission()) {
      _permission = 'granted';
    } else if (_permission == 'granted') {
      _permission = 'denied';
    }
  }

  Future<String?> requestPermission() async {
    _permission = await scheduler!.requestPermission() ? 'granted' : 'denied';
    return _permission;
  }

  void show({
    required String title,
    required String body,
    required String tag,
    required String payload,
  }) {
    throw UnsupportedError('Native platforms schedule instead of showing');
  }

  String? readValue(String key) => null;

  void writeValue(String key, String value) {}
}

NotificationPlatform createNotificationPlatform() =>
    NotificationPlatform();
