import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/notifications/notification_settings_meta_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'poolcoachai:notification-settings-sync:v1:u1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('chưa lưu gì thì đọc ra mặc định', () async {
    final meta = await SharedPreferencesNotificationSettingsMetaStore().load(
      'u1',
    );
    expect(meta, const NotificationSettingsMeta());
  });

  test('lưu rồi đọc lại đúng, theo từng tài khoản', () async {
    final store = SharedPreferencesNotificationSettingsMetaStore();
    final meta = NotificationSettingsMeta(
      prefsUpdatedAt: DateTime.utc(2026, 10, 30, 8),
      prefsDirty: true,
      seenDirty: true,
    );
    await store.save('u1', meta);
    expect(await store.load('u1'), meta);
    expect(await store.load('u2'), const NotificationSettingsMeta());
  });

  test('giá trị hỏng đọc ra như mặc định', () async {
    for (final bad in ['{not json', '[1,2]', '"x"']) {
      SharedPreferences.setMockInitialValues({key: bad});
      expect(
        await SharedPreferencesNotificationSettingsMetaStore().load('u1'),
        const NotificationSettingsMeta(),
        reason: bad,
      );
    }
  });
}
