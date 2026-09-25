import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  test('service dựng lại (provider rebuild) cũng tự chạy, không nằm im', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok([]));
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      directusClientProvider.overrideWithValue(
          DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl)),
    ]);
    addTearDown(container.dispose);

    final first = container.read(syncServiceProvider);
    await pumpEventQueue();
    container.invalidate(syncServiceProvider);
    final second = container.read(syncServiceProvider);
    server.requests.clear();
    await pumpEventQueue();

    expect(identical(first, second), isFalse);
    expect(server.sent('GET', '/items/drill_logs'), isNotEmpty,
        reason: 'service mới phải tự chạy một lượt ngay khi dựng');
  });
}
