import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30, 8);
  const all = NotificationPrefs();
  PushLease lease({String userId = 'u1', DateTime? until}) => PushLease(
    userId: userId,
    deviceId: 'd1',
    serverKinds: const {
      NotificationKind.maintenance,
      NotificationKind.schedule,
      NotificationKind.streak,
    },
    until: until ?? now.add(const Duration(hours: 1)),
  );

  group('localPrefsUnder', () {
    test('lease còn hạn của đúng người: tắt các loại máy chủ lo', () {
      final out = localPrefsUnder(
        all,
        PushServer(lease()),
        userId: 'u1',
        now: now,
      );
      expect(out.maintenance, isFalse);
      expect(out.schedule, isFalse);
      expect(out.streak, isFalse);
      expect(out.recommendation, isTrue);
    });

    test('lease của người khác: giữ nguyên prefs', () {
      expect(
        localPrefsUnder(all, PushServer(lease()), userId: 'u2', now: now),
        all,
      );
    });

    test('chưa đăng nhập (userId null): giữ nguyên prefs', () {
      expect(
        localPrefsUnder(all, PushServer(lease()), userId: null, now: now),
        all,
      );
    });

    test('lease hết hạn: giữ nguyên prefs', () {
      expect(
        localPrefsUnder(
          all,
          PushServer(lease(until: now)),
          userId: 'u1',
          now: now,
        ),
        all,
      );
    });

    test('PushLocal: giữ nguyên prefs', () {
      expect(
        localPrefsUnder(all, const PushLocal(), userId: 'u1', now: now),
        all,
      );
    });

    test('PushUnavailable: giữ nguyên prefs', () {
      expect(
        localPrefsUnder(all, const PushUnavailable(), userId: 'u1', now: now),
        all,
      );
    });

    test('state null: giữ nguyên prefs', () {
      expect(localPrefsUnder(all, null, userId: 'u1', now: now), all);
    });
  });

  group('decodeVapidKey', () {
    final raw = Uint8List.fromList([4, ...List.generate(64, (i) => i)]);
    test('khoá 65 byte giải mã đúng và mã hoá lại khớp', () {
      final key = encodeBase64Url(raw);
      expect(key.contains('='), isFalse);
      expect(decodeVapidKey(key), raw);
    });
    test('sai độ dài: FormatException', () {
      expect(
        () => decodeVapidKey(encodeBase64Url(Uint8List(10))),
        throwsFormatException,
      );
      expect(() => decodeVapidKey(''), throwsFormatException);
    });
  });

  test('activeAt: đúng trước until, sai tại until', () {
    final l = lease();
    expect(l.activeAt(now), isTrue);
    expect(l.activeAt(l.until), isFalse);
  });

  group('PushShown.fromMessage', () {
    Map<String, Object?> good() => {
      'type': 'shown',
      'deliveryId': 'dl1',
      'notificationId': 7,
      'kind': 'streak',
      'key': '2026-10-30',
      'title': 'T',
      'body': 'B',
      'shownAt': 1793347200000,
    };

    test('thông điệp đúng được đọc', () {
      final s = PushShown.fromMessage(good())!;
      expect(s.deliveryId, 'dl1');
      expect(s.notificationId, 7);
      expect(s.kind, NotificationKind.streak);
      expect(s.key, '2026-10-30');
      expect(s.title, 'T');
      expect(s.body, 'B');
      expect(s.shownAt, DateTime.fromMillisecondsSinceEpoch(1793347200000));
    });

    test('kind lạ: null', () {
      expect(PushShown.fromMessage({...good(), 'kind': 'zzz'}), isNull);
    });
    test('thiếu deliveryId: null', () {
      expect(PushShown.fromMessage({...good()}..remove('deliveryId')), isNull);
    });
    test('không phải map: null', () {
      expect(PushShown.fromMessage('x'), isNull);
      expect(PushShown.fromMessage(null), isNull);
    });
    test('shownAt hỏng: null', () {
      expect(PushShown.fromMessage({...good(), 'shownAt': 'abc'}), isNull);
    });
  });
}
