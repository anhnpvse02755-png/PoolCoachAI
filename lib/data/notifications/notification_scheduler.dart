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

  /// Nơi nhận chuỗi đi kèm thông báo khi người dùng chạm lúc app đang chạy.
  set onTap(void Function(String payload)? handler);

  /// Chuỗi đi kèm thông báo đã mở app từ trạng thái đóng hẳn; null nếu app
  /// không được mở bằng thông báo.
  Future<String?> launchPayload();
}

/// Đưa lịch của hệ điều hành về đúng [desired]: huỷ cái thừa, đặt cái
/// thiếu, giữ nguyên cái đã đúng. Trả về id đã huỷ.
///
/// Id sinh từ giờ và chữ của thông báo, nên cùng id là cùng thông báo.
/// [keep]: id không có trong [desired] mà vẫn để yên nếu còn chờ (thông báo
/// đã quá giờ nhưng hệ điều hành chưa giao).
///
/// [replaceAll]: đặt lại cả cái đang chờ đúng id (cái cũ thiếu thứ bản mới
/// cần, như payload). Id trả về vẫn chỉ là cái huỷ mà không đặt lại.
Future<Set<int>> reconcileNotifications(
  NotificationScheduler scheduler,
  List<PlannedNotification> desired, {
  Set<int> keep = const {},
  bool replaceAll = false,
}) async {
  final pending = await scheduler.pendingIds();
  final desiredIds = {for (final n in desired) n.id};
  final cancelled = pending.difference({...desiredIds, ...keep});
  for (final id in replaceAll ? pending.difference(keep) : cancelled) {
    await scheduler.cancel(id);
  }
  for (final n in desired) {
    if (replaceAll || !pending.contains(n.id)) await scheduler.schedule(n);
  }
  return cancelled;
}
