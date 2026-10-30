import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

int fnvReference(String s) {
  var h = BigInt.from(0x811c9dc5);
  for (final u in s.codeUnits) {
    h = ((h ^ BigInt.from(u)) * BigInt.from(0x01000193)) &
        BigInt.from(0xffffffff);
  }
  return (h & BigInt.from(0x7fffffff)).toInt();
}

void main() {
  test('id thông báo là FNV-1a 32 bit chuẩn, đúng trên mọi nền tảng', () {
    final r = Random(7);
    final samples = [
      '',
      'abc',
      '${NotificationKind.streak.name}|2026-10-30|'
          '${DateTime(2026, 10, 30, 20).toIso8601String()}|'
          '${Vi.streakReminderTitle}|${Vi.streakReminderBody(3)}',
      for (var i = 0; i < 300; i++)
        String.fromCharCodes([
          for (var j = 0; j < 1 + r.nextInt(80); j++) r.nextInt(0x10000),
        ]),
    ];
    for (final s in samples) {
      expect(notificationIdHash(s), fnvReference(s), reason: s);
    }
  });

  test('id không đổi so với trước khi sửa (giá trị đo trên VM)', () {
    final streak = '${NotificationKind.streak.name}|2026-10-30|'
        '${DateTime(2026, 10, 30, 20).toIso8601String()}|'
        '${Vi.streakReminderTitle}|${Vi.streakReminderBody(3)}';
    expect(notificationIdHash(streak), 2006115205);
    expect(notificationIdHash(''), 18652613);
    expect(notificationIdHash('abc'), 440920331);
    expect(notificationIdHash('Đường thẳng cơ bản – nhắc tập 🎱'), 2083575381);
  });
}
