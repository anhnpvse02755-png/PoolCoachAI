import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/notifications/notification_prefs_store.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to everything on for an account with nothing saved', () async {
    final prefs = await SharedPreferencesNotificationPrefsStore().load('u1');
    expect(prefs, const NotificationPrefs());
  });

  test('saves per account and does not leak between accounts', () async {
    final store = SharedPreferencesNotificationPrefsStore();
    await store.save('u1', const NotificationPrefs(streak: false));
    await store.save('u2', const NotificationPrefs(maintenance: false));

    expect(await store.load('u1'), const NotificationPrefs(streak: false));
    expect(await store.load('u2'), const NotificationPrefs(maintenance: false));
    expect(await store.load('u3'), const NotificationPrefs());
  });
}
