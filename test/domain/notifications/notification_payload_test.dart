import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

void main() {
  test('payload đọc lại được cho mọi loại', () {
    for (final k in NotificationKind.values) {
      expect(
        parseNotificationPayload(notificationPayload(k, 'a|b:c')),
        NotificationTap(k, 'a|b:c'),
      );
    }
  });

  test('payload sai: null, không ném', () {
    for (final bad in [null, '', 'streak', 'nope|k', 'streak|']) {
      expect(parseNotificationPayload(bad), isNull, reason: '$bad');
    }
  });
}
