import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poolcoachai/data/push/push_types.dart';
import 'package:poolcoachai/data/remote/notify_client.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

void main() {
  final base = Uri.parse('https://notify.example.invalid');
  const sub = PushSubscriptionInfo(
    endpoint:
        'https://fcm.googleapis.com/fcm/send/dQw4w9WgXcQ:APA91bExampleEndpointToken',
    p256dh:
        'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM',
    auth: 'tBHItJI5svbpez7KI4CCXg',
  );

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, Object?> okBody() => {
    'deviceId': 'dev1',
    'serverKinds': <String>[],
    'leaseUntil': null,
    'serverNow': '2026-10-30T08:00:00.000Z',
    'enabled': false,
  };

  Future<NotifyRegistration> doRegister(NotifyClient c) => c.register(
    token: 'tok',
    subscription: sub,
    timezone: 'Asia/Ho_Chi_Minh',
    seedFingerprint: 'seed-fp-0001',
    vapidPublicKey: 'pub-key',
    shownToday: const [
      PushShownRef(kind: NotificationKind.streak, key: '2026-10-30'),
      PushShownRef(kind: NotificationKind.maintenance, key: 'cue-1:2026-10-30'),
    ],
  );

  test('đăng ký: gửi đúng thân và Bearer, đọc deviceId, serverKinds, '
      'leaseUntil, serverNow', () async {
    late http.Request seen;
    final c = NotifyClient(
      client: MockClient((req) async {
        seen = req;
        return json(200, {
          'deviceId': 'dev1',
          'serverKinds': ['maintenance', 'streak'],
          'leaseUntil': '2026-10-30T09:00:00.000Z',
          'serverNow': '2026-10-30T08:00:00.000Z',
          'enabled': true,
        });
      }),
      baseUrl: base,
    );
    final r = await doRegister(c);
    expect(seen.method, 'POST');
    expect(seen.url.path, '/push/devices');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['Content-Type'], contains('application/json'));
    final fixture = jsonDecode(
      File('test/fixtures/push_register_body.json').readAsStringSync(),
    );
    expect(jsonDecode(seen.body), fixture);
    expect(r.deviceId, 'dev1');
    expect(r.serverKinds, {
      NotificationKind.maintenance,
      NotificationKind.streak,
    });
    expect(r.leaseUntil, DateTime.utc(2026, 10, 30, 9));
    expect(r.serverNow, DateTime.utc(2026, 10, 30, 8));
    expect(r.enabled, isTrue);
  });

  test('leaseUntil null khi máy chủ tắt', () async {
    final c = NotifyClient(
      client: MockClient((_) async => json(200, okBody())),
      baseUrl: base,
    );
    final r = await doRegister(c);
    expect(r.leaseUntil, isNull);
    expect(r.enabled, isFalse);
    expect(r.serverKinds, isEmpty);
  });

  test('shownToday cắt ở 50 mục, seedFingerprint null được gửi', () async {
    late Map<String, Object?> body;
    final c = NotifyClient(
      client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, Object?>;
        return json(200, okBody());
      }),
      baseUrl: base,
    );
    await c.register(
      token: 't',
      subscription: sub,
      timezone: 'UTC',
      seedFingerprint: null,
      vapidPublicKey: 'k',
      shownToday: [
        for (var i = 0; i < 60; i++)
          PushShownRef(kind: NotificationKind.schedule, key: 'k$i'),
      ],
    );
    expect((body['shownToday'] as List).length, 50);
    expect(body['seedFingerprint'], isNull);
  });

  test('loại lạ trong serverKinds bị bỏ', () async {
    final c = NotifyClient(
      client: MockClient(
        (_) async => json(200, {
          ...okBody(),
          'serverKinds': ['streak', 'bogus'],
          'enabled': true,
        }),
      ),
      baseUrl: base,
    );
    expect((await doRegister(c)).serverKinds, {NotificationKind.streak});
  });

  test('409 vapid_mismatch → NotifyError(409, vapid_mismatch)', () async {
    final c = NotifyClient(
      client: MockClient((_) async => json(409, {'error': 'vapid_mismatch'})),
      baseUrl: base,
    );
    await expectLater(
      doRegister(c),
      throwsA(
        isA<NotifyError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'vapid_mismatch'),
      ),
    );
  });

  test('400 invalid, 503 helper_down, 429 rate_limited, unsupported_channel '
      'đều thành NotifyError có mã', () async {
    for (final (status, body, code) in [
      (400, {'error': 'invalid', 'field': 'timezone'}, 'invalid'),
      (503, {'error': 'helper_down'}, 'helper_down'),
      (429, {'error': 'rate_limited'}, 'rate_limited'),
      (400, {'error': 'unsupported_channel'}, 'unsupported_channel'),
    ]) {
      final c = NotifyClient(
        client: MockClient((_) async => json(status, body)),
        baseUrl: base,
      );
      await expectLater(
        doRegister(c),
        throwsA(
          isA<NotifyError>()
              .having((e) => e.status, 'status', status)
              .having((e) => e.code, 'code', code),
        ),
      );
    }
  });

  test('thân lỗi không phải JSON: NotifyError với code null', () async {
    final c = NotifyClient(
      client: MockClient((_) async => http.Response('<html>', 502)),
      baseUrl: base,
    );
    await expectLater(
      doRegister(c),
      throwsA(
        isA<NotifyError>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.code, 'code', isNull),
      ),
    );
  });

  test('mất mạng và hết giờ → NotifyUnreachable', () async {
    final down = NotifyClient(
      client: MockClient((_) async => throw http.ClientException('x')),
      baseUrl: base,
    );
    await expectLater(doRegister(down), throwsA(isA<NotifyUnreachable>()));
    final slow = NotifyClient(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return json(200, okBody());
      }),
      baseUrl: base,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(doRegister(slow), throwsA(isA<NotifyUnreachable>()));
  });

  test('phản hồi 200 hỏng → NotifyError', () async {
    final c = NotifyClient(
      client: MockClient((_) async => json(200, {'deviceId': 5})),
      baseUrl: base,
    );
    await expectLater(doRegister(c), throwsA(isA<NotifyError>()));
  });

  test('huỷ: DELETE /push/devices/<id> mã hoá đúng', () async {
    late http.Request seen;
    final c = NotifyClient(
      client: MockClient((req) async {
        seen = req;
        return http.Response('', 204);
      }),
      baseUrl: base,
    );
    await c.unregister(token: 'tok', deviceId: 'a/b c');
    expect(seen.method, 'DELETE');
    expect(
      seen.url.toString(),
      'https://notify.example.invalid/push/devices/a%2Fb%20c',
    );
    expect(seen.headers['Authorization'], 'Bearer tok');
  });

  test('huỷ: 401 → NotifyError', () async {
    final c = NotifyClient(
      client: MockClient((_) async => json(401, {'error': 'unauthorized'})),
      baseUrl: base,
    );
    await expectLater(
      c.unregister(token: 't', deviceId: 'x'),
      throwsA(isA<NotifyError>().having((e) => e.status, 'status', 401)),
    );
  });

  test('config: GET /push/config', () async {
    final c = NotifyClient(
      client: MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/push/config');
        return json(200, {'enabled': true, 'publicKey': 'PK'});
      }),
      baseUrl: base,
    );
    final cfg = await c.config();
    expect(cfg.enabled, isTrue);
    expect(cfg.publicKey, 'PK');
  });
}
