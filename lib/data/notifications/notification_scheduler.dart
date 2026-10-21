import 'package:poolcoachai/domain/notifications/notification_plan.dart';

/// Đặt lịch thông báo của hệ điều hành (Android/iOS). Tách khỏi plugin để
/// test bằng bản giả; bản thật nằm ở local_notifications_scheduler.dart.
abstract class NotificationScheduler {
  /// Đã được cấp quyền gửi thông báo chưa. Không hiện hộp thoại.
  Future<bool> hasPermission();

  /// Hiện hộp thoại xin quyền (Android 13+, iOS). Trả về kết quả cuối cùng.
  Future<bool> requestPermission();

  /// Id các thông báo đang chờ trong hệ điều hành.
  Future<Set<int>> pendingIds();

  /// Đặt một thông báo vào giờ [PlannedNotification.at].
  Future<void> schedule(PlannedNotification notification);

  /// Huỷ một thông báo đang chờ.
  Future<void> cancel(int id);

  /// Huỷ mọi thông báo đã đặt.
  Future<void> cancelAll();
}

/// Đưa lịch của hệ điều hành về đúng [desired]: huỷ cái thừa, đặt cái
/// thiếu, giữ nguyên cái đã đúng.
///
/// Id sinh từ giờ và chữ của thông báo, nên cùng id là cùng thông báo.
Future<void> reconcileNotifications(
  NotificationScheduler scheduler,
  List<PlannedNotification> desired,
) async {
  final pending = await scheduler.pendingIds();
  final wanted = {for (final n in desired) n.id};
  for (final id in pending.difference(wanted)) {
    await scheduler.cancel(id);
  }
  for (final n in desired) {
    if (!pending.contains(n.id)) await scheduler.schedule(n);
  }
}
