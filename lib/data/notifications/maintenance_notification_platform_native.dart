import 'package:poolcoachai/data/notifications/local_notifications_scheduler.dart';
import 'package:poolcoachai/data/notifications/maintenance_scheduler.dart';

/// Android/iOS: hệ điều hành tự giữ lịch thông báo, nên không cần
/// show/readValue — dịch vụ đặt lịch qua [scheduler].
class MaintenanceNotificationPlatform {
  MaintenanceNotificationPlatform({MaintenanceScheduler? scheduler})
    : scheduler = scheduler ?? LocalNotificationsScheduler();

  final MaintenanceScheduler? scheduler;
  String _permission = 'default';

  bool get isSupported => true;

  String? get permission => _permission;

  /// Đọc quyền hiện tại của hệ điều hành vào [permission].
  Future<void> refresh() async {
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

MaintenanceNotificationPlatform createMaintenanceNotificationPlatform() =>
    MaintenanceNotificationPlatform();
