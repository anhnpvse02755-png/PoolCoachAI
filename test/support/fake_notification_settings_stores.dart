import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/data/notifications/notification_settings_meta_store.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Kho dấu vết đồng bộ giả: ghi vào [saved], đếm [saves].
class FakeNotificationSettingsMetaStore
    implements NotificationSettingsMetaStore {
  final saved = <String, NotificationSettingsMeta>{};
  int saves = 0;

  @override
  Future<NotificationSettingsMeta> load(String userId) async =>
      saved[userId] ?? const NotificationSettingsMeta();

  @override
  Future<void> save(String userId, NotificationSettingsMeta meta) async {
    saves++;
    saved[userId] = meta;
  }
}

/// Kho công tắc giả: ghi vào [saved], đếm [saves].
class FakeNotificationPrefsStore implements NotificationPrefsStore {
  final saved = <String, NotificationPrefs>{};
  int saves = 0;

  @override
  Future<NotificationPrefs> load(String userId) async =>
      saved[userId] ?? const NotificationPrefs();

  @override
  Future<void> save(String userId, NotificationPrefs prefs) async {
    saves++;
    saved[userId] = prefs;
  }
}
