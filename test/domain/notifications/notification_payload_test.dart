import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

void main() {
  test('payload đọc lại được cho mọi loại, kèm tài khoản', () {
    for (final k in NotificationKind.values) {
      for (final user in ['u1', 'a|b c']) {
        final tap = parseNotificationPayload(
          notificationPayload(k, 'a|b:c', userId: user),
        );
        expect(tap, NotificationTap(k, 'a|b:c', userId: user));
        expect(tap!.userId, user);
      }
    }
  });

  test('payload bản cũ (không có tài khoản) vẫn đọc được', () {
    for (final k in NotificationKind.values) {
      final tap = parseNotificationPayload('${k.name}|a|b:c');
      expect(tap, NotificationTap(k, 'a|b:c'));
      expect(tap!.userId, isNull);
    }
  });

  test('cùng (loại, khoá) mà khác tài khoản là khác lần chạm', () {
    expect(
      const NotificationTap(NotificationKind.streak, 'k', userId: 'u1'),
      isNot(const NotificationTap(NotificationKind.streak, 'k', userId: 'u2')),
    );
  });

  test('payload sai: null, không ném', () {
    for (final bad in [
      null,
      '',
      'streak',
      'nope|k',
      'streak|',
      'v2|',
      'v2|u1',
      'v2||streak|k',
      'v2|u1|nope|k',
      'v2|u1|streak|',
      'v2|%E0%A4%A|streak|k', // mã hoá hỏng
      'v2|%FF|streak|k', // hex đúng mà không phải UTF-8
      'v2|%E0%A4|streak|k', // UTF-8 thiếu byte
    ]) {
      expect(parseNotificationPayload(bad), isNull, reason: '$bad');
    }
  });
}
