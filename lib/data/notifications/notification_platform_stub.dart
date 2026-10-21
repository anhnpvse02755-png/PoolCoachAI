import 'package:poolcoachai/data/notifications/notification_scheduler.dart';

class NotificationPlatform {
  // ignore: avoid_unused_constructor_parameters
  NotificationPlatform({NotificationScheduler? scheduler});

  /// Chỉ Android/iOS đặt lịch qua hệ điều hành.
  NotificationScheduler? get scheduler => null;

  Future<void> loadPermission() async {}

  bool get isSupported => false;

  String? get permission => null;

  Future<String?> requestPermission() async => null;

  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    throw UnsupportedError('Notifications are not supported on this platform');
  }

  String? readValue(String key) => null;

  void writeValue(String key, String value) {
    throw UnsupportedError('Persistent browser storage is not supported');
  }
}

NotificationPlatform createNotificationPlatform() =>
    NotificationPlatform();
