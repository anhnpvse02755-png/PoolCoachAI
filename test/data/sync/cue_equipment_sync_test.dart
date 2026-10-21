import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/sync/cue_equipment_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late DirectusClient api;
  final now = DateTime.utc(2026, 10, 20, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    api = DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);
    server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([]);
  });

  tearDown(() => db.close());

  CueEquipmentSyncService service() =>
      CueEquipmentSyncService(db: db, auth: auth, api: api, now: () => now);

  DriftCueEquipmentRepository repository() =>
      DriftCueEquipmentRepository(db, userId: 'u1', now: () => now);

  test(
    'uploads an edited cue and marks the unchanged local revision synced',
    () async {
      await repository().save(_cue('cue-1'));
      Map<String, Object?>? uploaded;
      server.routes['POST /items/cue_equipment'] = (request) {
        uploaded = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'cue-1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(uploaded, containsPair('id', 'cue-1'));
      expect(uploaded!.containsKey('user_created'), isFalse);
      expect(uploaded, containsPair('is_deleted', false));
      expect(uploaded?['skill_categories'], ['aiming']);
      expect(uploaded?['last_tip_maintenance'], '2026-10-01');
      expect(uploaded?['tip_maintenance_due_date'], '2026-11-01');
      expect((uploaded?['updated_at'] as String).endsWith('Z'), isTrue);
      final stored = (await db.select(db.cueEquipmentRows).get()).single;
      expect(stored.syncedAt, isNotNull);
      expect(stored.updatedAt!.isAtSameMomentAs(now), isTrue);
    },
  );

  test('downloads only the current user cue and stores it as synced', () async {
    server.routes['GET /items/cue_equipment'] = (_) =>
        FakeDirectus.ok([_remoteCue(id: 'from-server')]);

    expect(await service().syncNow(), SyncOutcome.done);

    final cue = (await repository().watchAll().first).single;
    expect(cue.id, 'from-server');
    expect(cue.name, 'Cơ từ server');
    expect(cue.type, CueType.playing);
    expect(cue.lastTipMaintenance, DateTime(2026, 10, 1));
    expect(cue.tipMaintenanceDueDate, DateTime(2026, 11, 1));
    final row = (await db.select(db.cueEquipmentRows).get()).single;
    expect(row.userId, 'u1');
    expect(row.syncedAt, isNotNull);
  });

  test('uploads a tombstone rather than deleting the remote cue', () async {
    await repository().save(_cue('cue-1'));
    await repository().remove('cue-1');
    Map<String, Object?>? uploaded;
    server.routes['POST /items/cue_equipment'] = (request) {
      uploaded = FakeDirectus.body(request);
      return FakeDirectus.ok({'id': 'cue-1'});
    };

    expect(await service().syncNow(), SyncOutcome.done);

    expect(uploaded?['is_deleted'], isTrue);
    expect(server.sent('DELETE', '/items/cue_equipment/cue-1'), isEmpty);
    final row = (await db.select(db.cueEquipmentRows).get()).single;
    expect(row.isDeleted, isTrue);
    expect(row.syncedAt, isNotNull);
  });

  test('pushes a newer local revision to the existing remote record', () async {
    await repository().save(
      const CueEquipment(
        id: 'cue-1',
        name: 'Cơ mới ở máy này',
        type: CueType.playing,
        skillCategories: [SkillCategory.aiming],
      ),
    );
    Map<String, Object?>? updated;
    server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([
      _remoteCue(
        id: 'cue-1',
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
    server.routes['PATCH /items/cue_equipment/cue-1'] = (request) {
      updated = FakeDirectus.body(request);
      return FakeDirectus.ok({'id': 'cue-1'});
    };

    expect(await service().syncNow(), SyncOutcome.done);

    expect(updated?['name'], 'Cơ mới ở máy này');
    expect(updated!.containsKey('id'), isFalse);
    expect(server.sent('POST', '/items/cue_equipment'), isEmpty);
    final local = (await repository().watchAll().first).single;
    expect(local.name, 'Cơ mới ở máy này');
    expect(
      (await db.select(db.cueEquipmentRows).get()).single.syncedAt,
      isNotNull,
    );
  });

  test(
    'replaces an older local revision with the newer remote record',
    () async {
      await repository().save(_cue('cue-1'));
      server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([
        _remoteCue(
          id: 'cue-1',
          name: 'Cơ mới ở server',
          updatedAt: now.add(const Duration(hours: 1)),
        ),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      expect(
        (await repository().watchAll().first).single.name,
        'Cơ mới ở server',
      );
      expect(server.sent('PATCH', '/items/cue_equipment/cue-1'), isEmpty);
    },
  );

  test('does not mutate a remote record owned by another user', () async {
    server.routes['GET /items/cue_equipment'] = (_) =>
        FakeDirectus.ok([_remoteCue(id: 'foreign', owner: 'u2')]);

    expect(await service().syncNow(), SyncOutcome.failed);
    expect(server.sent('POST', '/items/cue_equipment'), isEmpty);
    expect(server.sent('PATCH', '/items/cue_equipment/foreign'), isEmpty);
  });

  test(
    'applies a newer server tombstone and unlinks its practice sessions',
    () async {
      await repository().save(_cue('cue-1'));
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(
          id: 'session-1',
          date: now,
          durationSec: 300,
          cueId: 'cue-1',
        ),
      );
      server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([
        _remoteCue(
          id: 'cue-1',
          name: 'Cơ đã xóa trên máy khác',
          updatedAt: now.add(const Duration(hours: 1)),
          isDeleted: true,
        ),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      expect(await repository().watchAll().first, isEmpty);
      final stored = (await db.select(db.cueEquipmentRows).get()).single;
      expect(stored.isDeleted, isTrue);
      expect((await db.select(db.timerSessionRows).get()).single.cueId, isNull);
      expect(server.sent('PATCH', '/items/cue_equipment/cue-1'), isEmpty);
    },
  );
}

CueEquipment _cue(String id) => CueEquipment(
  id: id,
  name: 'Cơ test',
  type: CueType.playing,
  skillCategories: const [SkillCategory.aiming],
  lastTipMaintenance: DateTime(2026, 10, 1),
  tipMaintenanceDueDate: DateTime(2026, 11, 1),
);

Map<String, Object?> _remoteCue({
  required String id,
  String owner = 'u1',
  String name = 'Cơ từ server',
  DateTime? updatedAt,
  bool isDeleted = false,
}) => {
  'id': id,
  'user_created': owner,
  'name': name,
  'type': 'playing',
  'weight_grams': null,
  'tip_diameter_mm': null,
  'tip_hardness': null,
  'skill_categories': ['aiming'],
  'last_tip_maintenance': '2026-10-01',
  'tip_maintenance_due_date': '2026-11-01',
  'updated_at': (updatedAt ?? DateTime.utc(2026, 10, 20, 8)).toIso8601String(),
  'is_deleted': isDeleted,
};
