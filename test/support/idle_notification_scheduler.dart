import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';

/// Bộ đặt lịch không làm gì: chỉ để nền tảng giả trông như điện thoại
/// (có lịch hệ điều hành, `schedulesInBackground` đúng). Chưa có quyền; xin
/// thì được.
class IdleNotificationScheduler implements NotificationScheduler {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<Set<int>> pendingIds() async => {};

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required String payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  set onTap(void Function(String payload)? handler) {}

  @override
  Future<String?> launchPayload() async => null;
}
