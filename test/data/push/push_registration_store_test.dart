import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/push/push_registration_store.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/push_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and loads a user-scoped registration lease', () async {
    final store = SharedPreferencesPushRegistrationStore();
    final lease = PushLease(
      userId: 'u1',
      deviceId: 'device-1',
      serverKinds: {NotificationKind.streak, NotificationKind.schedule},
      until: DateTime.utc(2026, 11, 4, 18),
    );

    await store.save(lease);

    expect(await store.load('u1'), isA<PushLease>());
    final loaded = await store.load('u1');
    expect(loaded!.deviceId, lease.deviceId);
    expect(loaded.serverKinds, lease.serverKinds);
    expect(loaded.until, lease.until);
    expect(await store.load('u2'), isNull);
  });

  test('corrupt or unknown registrations load as null', () async {
    const key = 'poolcoachai:push-registration:v1:u1';
    SharedPreferences.setMockInitialValues({key: '{'});
    expect(await SharedPreferencesPushRegistrationStore().load('u1'), isNull);

    SharedPreferences.setMockInitialValues({
      key: '{"deviceId":"d","kinds":["future"],"until":"2026-11-04T18:00:00Z"}',
    });
    expect(await SharedPreferencesPushRegistrationStore().load('u1'), isNull);
  });

  test('forget removes only that user registration', () async {
    final store = SharedPreferencesPushRegistrationStore();
    for (final user in ['u1', 'u2']) {
      await store.save(
        PushLease(
          userId: user,
          deviceId: 'device-$user',
          serverKinds: {NotificationKind.streak},
          until: DateTime.utc(2026, 11, 4, 18),
        ),
      );
    }

    await store.forget('u1');

    expect(await store.load('u1'), isNull);
    expect((await store.load('u2'))?.deviceId, 'device-u2');
  });
}
