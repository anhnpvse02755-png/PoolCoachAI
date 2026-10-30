import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Dấu vết đồng bộ cài đặt thông báo của một tài khoản trên máy này: lần sửa
/// công tắc gần nhất và phần nào chưa lên server.
final class NotificationSettingsMeta {
  const NotificationSettingsMeta({
    this.prefsUpdatedAt,
    this.prefsDirty = false,
    this.seenDirty = false,
  });

  final DateTime? prefsUpdatedAt;
  final bool prefsDirty;
  final bool seenDirty;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettingsMeta &&
      other.prefsUpdatedAt == prefsUpdatedAt &&
      other.prefsDirty == prefsDirty &&
      other.seenDirty == seenDirty;

  @override
  int get hashCode => Object.hash(prefsUpdatedAt, prefsDirty, seenDirty);
}

abstract class NotificationSettingsMetaStore {
  Future<NotificationSettingsMeta> load(String userId);

  Future<void> save(String userId, NotificationSettingsMeta meta);
}

/// Lưu bằng shared_preferences, một khoá JSON theo tài khoản. Giá trị hỏng đọc
/// ra như mặc định.
class SharedPreferencesNotificationSettingsMetaStore
    implements NotificationSettingsMetaStore {
  static String _key(String userId) =>
      'poolcoachai:notification-settings-sync:v1:$userId';

  @override
  Future<NotificationSettingsMeta> load(String userId) async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_key(userId));
    if (raw == null) return const NotificationSettingsMeta();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const NotificationSettingsMeta();
      final at = json['prefsUpdatedAt'];
      final prefsDirty = json['prefsDirty'];
      final seenDirty = json['seenDirty'];
      return NotificationSettingsMeta(
        prefsUpdatedAt: at is String ? DateTime.tryParse(at) : null,
        prefsDirty: prefsDirty is bool && prefsDirty,
        seenDirty: seenDirty is bool && seenDirty,
      );
    } on FormatException {
      return const NotificationSettingsMeta();
    }
  }

  @override
  Future<void> save(String userId, NotificationSettingsMeta meta) async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _key(userId),
      jsonEncode({
        'prefsUpdatedAt': meta.prefsUpdatedAt?.toUtc().toIso8601String(),
        'prefsDirty': meta.prefsDirty,
        'seenDirty': meta.seenDirty,
      }),
    );
  }
}
