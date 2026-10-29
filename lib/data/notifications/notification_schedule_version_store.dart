import 'package:shared_preferences/shared_preferences.dart';

/// Phiên bản cách app đặt thông báo vào lịch hệ điều hành.
///
/// Tăng khi thông báo đã đặt cần đặt lại hết, vì đối chiếu theo id giữ
/// nguyên cái cũ:
/// - 2: thông báo mang payload để chạm mở đúng màn (P6a). Thông báo đặt
///   từ bản trước không có payload.
const notificationScheduleVersion = 2;

/// Nơi nhớ phiên bản đặt lịch của máy này (lịch hệ điều hành là của cả máy,
/// không theo tài khoản).
abstract class NotificationScheduleVersionStore {
  /// Null: chưa từng ghi (bản trước khi có cờ này).
  Future<int?> load();

  Future<void> save(int version);
}

class SharedPreferencesNotificationScheduleVersionStore
    implements NotificationScheduleVersionStore {
  static const _key = 'poolcoachai:notification-schedule-version';

  @override
  Future<int?> load() async =>
      (await SharedPreferences.getInstance()).getInt(_key);

  @override
  Future<void> save(int version) async {
    await (await SharedPreferences.getInstance()).setInt(_key, version);
  }
}
