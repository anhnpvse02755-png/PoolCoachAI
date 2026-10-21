import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nơi lưu cài đặt thông báo theo tài khoản, chỉ trên máy này.
abstract class NotificationPrefsStore {
  Future<NotificationPrefs> load(String userId);

  Future<void> save(String userId, NotificationPrefs prefs);
}

/// Lưu bằng shared_preferences (localStorage trên web). Mỗi loại một khoá
/// theo tài khoản; khoá vắng nghĩa là mặc định (bật).
class SharedPreferencesNotificationPrefsStore
    implements NotificationPrefsStore {
  static String _key(String userId, NotificationKind kind) =>
      'poolcoachai:notification-prefs:v1:$userId:${kind.name}';

  @override
  Future<NotificationPrefs> load(String userId) async {
    final store = await SharedPreferences.getInstance();
    var prefs = const NotificationPrefs();
    for (final kind in NotificationKind.values) {
      final value = store.getBool(_key(userId, kind));
      if (value != null) prefs = prefs.toggled(kind, value);
    }
    return prefs;
  }

  @override
  Future<void> save(String userId, NotificationPrefs prefs) async {
    final store = await SharedPreferences.getInstance();
    for (final kind in NotificationKind.values) {
      await store.setBool(_key(userId, kind), prefs.isEnabled(kind));
    }
  }
}
