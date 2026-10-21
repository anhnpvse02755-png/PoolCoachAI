import 'package:poolcoachai/domain/maintenance_schedule.dart';

/// Đặt lịch thông báo của hệ điều hành (Android/iOS). Tách khỏi plugin để
/// test bằng bản giả; bản thật nằm ở local_notifications_scheduler.dart.
abstract class MaintenanceScheduler {
  /// Đã được cấp quyền gửi thông báo chưa. Không hiện hộp thoại.
  Future<bool> hasPermission();

  /// Hiện hộp thoại xin quyền (Android 13+, iOS). Trả về kết quả cuối cùng.
  Future<bool> requestPermission();

  /// Thay toàn bộ lịch đã đặt bằng [reminders].
  Future<void> replaceAll(List<MaintenanceReminder> reminders);

  /// Huỷ mọi thông báo đã đặt.
  Future<void> cancelAll();
}
