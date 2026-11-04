import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/remote/notify_client.dart';
import 'package:poolcoachai/data/push/push_registration_store.dart';
import 'package:poolcoachai/data/push/push_service.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_push_platform.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  final remoteLease = {
    'deviceId': 'device-1',
    'serverKinds': ['streak', 'schedule'],
    'leaseUntil': '2026-11-04T18:00:00.000Z',
    'serverNow': '2026-11-04T12:00:00.000Z',
    'enabled': true,
  };
  final shownRow = {
    'id': 'delivery-1',
    'device': 'device-1',
    'notification_id': 9001,
    'kind': 'streak',
    'key': '2026-11-04',
    'title': 'Giữ chuỗi',
    'body': 'Hãy tập hôm nay',
    'at': '2026-11-04T13:00:00.000Z',
    'shown_at': '2026-11-04T13:01:00.000Z',
  };

  http.Response jsonResponse(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json'},
  );

  late FakeAuthRepository auth;
  late FakePushPlatform platform;
  late _MemoryStore store;
  late List<http.Request> notifyRequests;
  late List<http.Request> directusRequests;
  late List<Object?> deliveries;
  late PushService service;

  PushService makeService({
    Future<http.Response> Function(http.Request)? registerResponse,
    bool enabled = true,
  }) {
    notifyRequests = [];
    directusRequests = [];
    deliveries = [];
    final notify = NotifyClient(
      client: MockClient((request) async {
        notifyRequests.add(request);
        if (request.url.path == '/push/config') {
          return jsonResponse({'enabled': enabled, 'publicKey': 'vapid-pub'});
        }
        if (request.url.path == '/push/devices' && request.method == 'POST') {
          return registerResponse == null
              ? jsonResponse(remoteLease)
              : registerResponse(request);
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        return http.Response('{"error":"not found"}', 404);
      }),
      baseUrl: Uri.parse('https://notify.example'),
    );
    final directus = DirectusClient(
      client: MockClient((request) async {
        directusRequests.add(request);
        return jsonResponse({'data': deliveries});
      }),
      baseUrl: Uri.parse('https://directus.example'),
    );
    return PushService(
      auth: auth,
      notify: notify,
      api: directus,
      platform: platform,
      store: store,
      now: () => now,
      vapidPublicKey: 'vapid-pub',
      permission: () => 'granted',
      resolveTimeout: const Duration(milliseconds: 100),
    )..setCatalog(const [], const []);
  }

  setUp(() {
    auth = FakeAuthRepository.signedIn();
    platform = FakePushPlatform();
    store = _MemoryStore();
  });

  tearDown(() async {
    service.dispose();
    await platform.dispose();
  });

  test(
    'registers the web device, stores the lease and emits server kinds',
    () async {
      service = makeService();

      await service.refresh();

      final state = await service.states.first;
      expect(state, isA<PushServer>());
      final lease = (state as PushServer).lease;
      expect(lease.userId, 'u1');
      expect(lease.deviceId, 'device-1');
      expect(lease.serverKinds, {
        NotificationKind.streak,
        NotificationKind.schedule,
      });
      expect(lease.until, DateTime.utc(2026, 11, 4, 18));
      expect((await store.load('u1'))?.deviceId, 'device-1');
      final request = notifyRequests.singleWhere((r) => r.method == 'POST');
      expect(jsonDecode(request.body)['timezone'], 'Asia/Ho_Chi_Minh');
      expect(jsonDecode(request.body)['seedFingerprint'], isA<String>());
      expect(platform.subscribeCalls, 1);
    },
  );

  test(
    'does not apply a registration result after the account changes',
    () async {
      final gate = Completer<http.Response>();
      service = makeService(registerResponse: (_) => gate.future);
      final initial = service.states.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      service.start();
      final resolution = service.refresh();
      await Future<void>.delayed(Duration.zero);
      auth.emit(const SignedOut());
      await Future<void>.delayed(Duration.zero);
      gate.complete(jsonResponse(remoteLease));
      await resolution;
      await Future<void>.delayed(Duration.zero);

      expect(await store.load('u1'), isNull);
      expect(await service.states.first, isA<PushLocal>());
      await initial.cancel();
    },
  );

  test('unavailable service does not subscribe or register', () async {
    service = makeService(enabled: false);

    await service.refresh();

    expect(await service.states.first, isA<PushLocal>());
    expect(platform.subscribeCalls, 0);
    expect(notifyRequests.map((r) => r.url.path), ['/push/config']);
  });

  test(
    'pulls shown deliveries for the registered device with a 30-day filter',
    () async {
      service = makeService();
      deliveries = [shownRow];
      final received = service.delivered.first;

      await service.refresh();

      expect(directusRequests, hasLength(1));
      final (userId, entries) = await received;
      expect(userId, 'u1');
      expect(entries.single.id, 9001);
      expect(entries.single.kind, NotificationKind.streak);
      expect(entries.single.at.toUtc(), DateTime.utc(2026, 11, 4, 13, 1));
      final query = directusRequests.single.url.queryParameters;
      expect(query['filter[device][_eq]'], 'device-1');
      expect(query['filter[shown_at][_nnull]'], 'true');
      expect(
        query['fields'],
        'id,device,notification_id,kind,key,title,body,at,shown_at',
      );
    },
  );
}

class _MemoryStore implements PushRegistrationStore {
  final values = <String, PushLease>{};

  @override
  Future<PushLease?> load(String userId) async => values[userId];

  @override
  Future<void> save(PushLease lease) async {
    values[lease.userId] = lease;
  }

  @override
  Future<void> forget(String userId) async {
    values.remove(userId);
  }
}
