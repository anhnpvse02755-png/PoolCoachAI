import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late DirectusClient api;
  final now = DateTime.utc(2026, 10, 21, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    api = DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);
    for (final path in ['pool_matches', 'timer_sessions', 'schedule_slots']) {
      server.routes['GET /items/$path'] = (_) => FakeDirectus.ok([]);
    }
  });

  tearDown(() => db.close());

  PracticeSyncService service() =>
      PracticeSyncService(db: db, auth: auth, api: api, now: () => now);

  DriftMatchRepository matches() =>
      DriftMatchRepository(db, userId: 'u1', now: () => now);

  PoolMatch match(String id, {String? cueId}) => PoolMatch(
    id: id,
    gameType: PoolGameType.nineBall,
    playerName: 'An',
    opponentName: 'Bình',
    targetRacks: 3,
    rackWinners: const [],
    startedAt: DateTime.utc(2026, 10, 21, 8),
    cueId: cueId,
  );

  group('matches', () {
    test('uploads a pending match with racks, shots and cue, then marks it synced', () async {
      await matches().start(match('m1'));
      await matches().recordShot(
        'm1',
        MatchShot(
          id: 's1',
          rackNumber: 1,
          shotNumber: 1,
          shooter: RackWinner.player,
          type: MatchShotType.breakShot,
          outcome: MatchShotOutcome.made,
          recordedAt: DateTime.utc(2026, 10, 21, 8, 1),
        ),
      );
      await matches().recordRack('m1', RackWinner.player);
      Map<String, Object?>? uploaded;
      server.routes['POST /items/pool_matches'] = (request) {
        uploaded = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'm1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(uploaded, containsPair('id', 'm1'));
      expect(uploaded!.containsKey('user_created'), isFalse);
      expect(uploaded, containsPair('game_type', 'nineBall'));
      expect(uploaded, containsPair('target_racks', 3));
      expect(uploaded?['rack_winners'], ['player']);
      expect((uploaded?['shots'] as List).single['type'], 'breakShot');
      expect(uploaded?['cue_id'], isNull);
      expect((uploaded?['updated_at'] as String).endsWith('Z'), isTrue);
      expect(
        (await db.select(db.poolMatchRows).get()).single.syncedAt,
        isNotNull,
      );
    });

    test('keeps the cue id of a deleted cue when uploading', () async {
      await matches().start(match('m1'));
      await (db.update(db.poolMatchRows)).write(
        const PoolMatchRowsCompanion(cueId: Value('gone')),
      );
      Map<String, Object?>? uploaded;
      server.routes['POST /items/pool_matches'] = (request) {
        uploaded = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'm1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(uploaded?['cue_id'], 'gone');
    });

    test('patches an existing remote match only when the local one is newer', () async {
      await matches().start(match('m1'));
      await matches().start(match('m2'));
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        _remoteMatch('m1', updatedAt: now.subtract(const Duration(hours: 1))),
        _remoteMatch('m2', updatedAt: now.add(const Duration(hours: 1))),
      ]);
      Map<String, Object?>? patched;
      server.routes['PATCH /items/pool_matches/m1'] = (request) {
        patched = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'm1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(patched, isNotNull);
      expect(patched!.containsKey('id'), isFalse);
      expect(server.sent('POST', '/items/pool_matches'), isEmpty);
      expect(server.sent('PATCH', '/items/pool_matches/m2'), isEmpty);
    });

    test('a newer remote match replaces the local copy', () async {
      await matches().start(match('m1'));
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        _remoteMatch(
          'm1',
          updatedAt: now.add(const Duration(hours: 1)),
          rackWinners: ['player', 'opponent'],
          cueId: 'c9',
        ),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      final stored = (await matches().watchAll().first).single;
      expect(stored.rackWinners, [RackWinner.player, RackWinner.opponent]);
      expect(stored.cueId, 'c9');
      expect(
        (await db.select(db.poolMatchRows).get()).single.syncedAt,
        isNotNull,
      );
    });

    test('downloads a match from another device as synced', () async {
      server.routes['GET /items/pool_matches'] = (_) =>
          FakeDirectus.ok([_remoteMatch('from-server')]);

      expect(await service().syncNow(), SyncOutcome.done);

      final row = (await db.select(db.poolMatchRows).get()).single;
      expect(row.id, 'from-server');
      expect(row.userId, 'u1');
      expect(row.syncedAt, isNotNull);
    });

    test('refuses a remote match owned by someone else', () async {
      server.routes['GET /items/pool_matches'] = (_) =>
          FakeDirectus.ok([_remoteMatch('foreign', owner: 'u2')]);

      expect(await service().syncNow(), SyncOutcome.failed);
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    });

    test('rejects a malformed remote match without storing it', () async {
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        _remoteMatch('bad', rackWinners: ['nobody']),
      ]);

      expect(await service().syncNow(), SyncOutcome.failed);
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    });

    test('a 4xx rejection is not retried until the match changes', () async {
      await matches().start(match('m1'));
      server.routes['POST /items/pool_matches'] = (_) =>
          FakeDirectus.error(403, 'FORBIDDEN');
      final svc = service();

      expect(await svc.syncNow(), SyncOutcome.done);
      expect(await svc.syncNow(), SyncOutcome.done);

      expect(server.sent('POST', '/items/pool_matches'), hasLength(1));
      expect(
        (await db.select(db.poolMatchRows).get()).single.syncedAt,
        isNull,
      );
    });

    test('never uploads another account\'s match', () async {
      await DriftMatchRepository(db, userId: 'u2', now: () => now)
          .start(match('theirs'));

      expect(await service().syncNow(), SyncOutcome.done);

      expect(server.sent('POST', '/items/pool_matches'), isEmpty);
    });
  });

  group('timer sessions', () {
    test('uploads own sessions only and never the orphan rows without an owner', () async {
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(
          id: 't1',
          date: DateTime.utc(2026, 10, 21, 7),
          durationSec: 900,
          cat: SkillCategory.aiming,
        ),
      );
      await db.into(db.timerSessionRows).insert(
        TimerSessionRowsCompanion.insert(
          id: 'orphan',
          date: DateTime.utc(2026, 10, 1),
          durationSec: 60,
        ),
      );
      await db.into(db.timerSessionRows).insert(
        TimerSessionRowsCompanion.insert(
          id: 'other',
          userId: const Value('u2'),
          date: DateTime.utc(2026, 10, 1),
          durationSec: 60,
        ),
      );
      final uploaded = <Map<String, Object?>>[];
      server.routes['POST /items/timer_sessions'] = (request) {
        uploaded.add(FakeDirectus.body(request));
        return FakeDirectus.ok({'id': 't1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(uploaded, hasLength(1));
      expect(uploaded.single, containsPair('id', 't1'));
      expect(uploaded.single, containsPair('duration_sec', 900));
      expect(uploaded.single, containsPair('cat', 'aiming'));
      final rows = {
        for (final r in await db.select(db.timerSessionRows).get()) r.id: r,
      };
      expect(rows['t1']!.syncedAt, isNotNull);
      expect(rows['orphan']!.syncedAt, isNull);
      expect(rows['other']!.syncedAt, isNull);
    });

    test('a duplicate id counts as already uploaded', () async {
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(id: 't1', date: DateTime.utc(2026, 10, 21), durationSec: 60),
      );
      server.routes['POST /items/timer_sessions'] = (_) =>
          FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');

      expect(await service().syncNow(), SyncOutcome.done);

      expect(
        (await db.select(db.timerSessionRows).get()).single.syncedAt,
        isNotNull,
      );
    });

    test('pulls sessions add-only and never overwrites a local one', () async {
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(id: 't1', date: DateTime.utc(2026, 10, 21), durationSec: 60),
      );
      server.routes['POST /items/timer_sessions'] = (_) =>
          FakeDirectus.ok({'id': 't1'});
      server.routes['GET /items/timer_sessions'] = (_) => FakeDirectus.ok([
        _remoteTimer('t1', durationSec: 9999),
        _remoteTimer('t2', durationSec: 300),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      final rows = {
        for (final r in await db.select(db.timerSessionRows).get()) r.id: r,
      };
      expect(rows['t1']!.durationSec, 60);
      expect(rows['t2']!.durationSec, 300);
      expect(rows['t2']!.userId, 'u1');
      expect(rows['t2']!.syncedAt, isNotNull);
    });

    test('refuses a remote session owned by someone else', () async {
      server.routes['GET /items/timer_sessions'] = (_) =>
          FakeDirectus.ok([_remoteTimer('x', owner: 'u2')]);

      expect(await service().syncNow(), SyncOutcome.failed);
      expect(await db.select(db.timerSessionRows).get(), isEmpty);
    });
  });

  group('schedule slots', () {
    var slotNow = now;
    DriftScheduleRepository slots() =>
        DriftScheduleRepository(db, userId: 'u1', now: () => slotNow);

    test('uploads a slot and later a tombstone instead of a DELETE', () async {
      await slots().save(
        const ScheduleSlot(id: 's1', day: 2, time: '19:00', label: 'Tập ngắm'),
      );
      final bodies = <Map<String, Object?>>[];
      server.routes['POST /items/schedule_slots'] = (request) {
        bodies.add(FakeDirectus.body(request));
        return FakeDirectus.ok({'id': 's1'});
      };
      final svc = service();
      expect(await svc.syncNow(), SyncOutcome.done);
      expect(bodies.single, containsPair('is_deleted', false));
      expect(bodies.single, containsPair('day', 2));
      expect(bodies.single, containsPair('time', '19:00'));

      slotNow = now.add(const Duration(minutes: 5));
      await slots().remove('s1');
      server.routes['GET /items/schedule_slots'] = (_) =>
          FakeDirectus.ok([_remoteSlot('s1', updatedAt: now)]);
      Map<String, Object?>? patched;
      server.routes['PATCH /items/schedule_slots/s1'] = (request) {
        patched = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 's1'});
      };
      expect(await svc.syncNow(), SyncOutcome.done);

      expect(patched?['is_deleted'], isTrue);
      expect(server.sent('DELETE', '/items/schedule_slots/s1'), isEmpty);
    });

    test('applies a newer remote tombstone', () async {
      await slots().save(
        const ScheduleSlot(id: 's1', day: 2, time: '19:00', label: 'Tập ngắm'),
      );
      server.routes['GET /items/schedule_slots'] = (_) => FakeDirectus.ok([
        _remoteSlot(
          's1',
          updatedAt: now.add(const Duration(hours: 1)),
          isDeleted: true,
        ),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      expect(await slots().watchAll().first, isEmpty);
      expect(server.sent('PATCH', '/items/schedule_slots/s1'), isEmpty);
    });

    test('downloads a slot made on another device', () async {
      server.routes['GET /items/schedule_slots'] = (_) =>
          FakeDirectus.ok([_remoteSlot('s2', label: 'Từ máy khác', cat: 'safety')]);

      expect(await service().syncNow(), SyncOutcome.done);

      final slot = (await slots().watchAll().first).single;
      expect(slot.label, 'Từ máy khác');
      expect(slot.cat, SkillCategory.safety);
    });

    test('does not upload orphan slots without an owner', () async {
      await db.into(db.scheduleSlotRows).insert(
        ScheduleSlotRowsCompanion.insert(
          id: 'orphan',
          day: 1,
          time: '10:00',
          label: 'Mồ côi',
        ),
      );

      expect(await service().syncNow(), SyncOutcome.done);

      expect(server.sent('POST', '/items/schedule_slots'), isEmpty);
    });

    test('refuses a remote slot owned by someone else', () async {
      server.routes['GET /items/schedule_slots'] = (_) =>
          FakeDirectus.ok([_remoteSlot('x', owner: 'u2')]);

      expect(await service().syncNow(), SyncOutcome.failed);
    });
  });

  test('start() uploads a row that becomes pending later', () async {
    server.routes['POST /items/pool_matches'] = (request) =>
        FakeDirectus.ok(FakeDirectus.body(request));
    final svc = service()..start();
    addTearDown(svc.dispose);
    await pumpEventQueue();

    await matches().start(match('late'));
    await pumpEventQueue(times: 200);

    expect(server.sent('POST', '/items/pool_matches'), hasLength(1));
    expect(
      (await db.select(db.poolMatchRows).get()).single.syncedAt,
      isNotNull,
    );
  });

  test('does nothing when signed out', () async {
    auth.emit(const SignedOut());
    expect(await service().syncNow(), SyncOutcome.signedOut);
    expect(server.requests, isEmpty);
  });

  test('reports offline without losing pending rows', () async {
    await matches().start(match('m1'));
    server.offline = true;

    expect(await service().syncNow(), SyncOutcome.offline);
    expect(
      (await db.select(db.poolMatchRows).get()).single.syncedAt,
      isNull,
    );
  });
}

Map<String, Object?> _remoteMatch(
  String id, {
  String owner = 'u1',
  DateTime? updatedAt,
  List<String> rackWinners = const [],
  String? cueId,
}) => {
  'id': id,
  'user_created': owner,
  'game_type': 'nineBall',
  'player_name': 'An',
  'opponent_name': 'Bình',
  'target_racks': 3,
  'rack_winners': rackWinners,
  'shots': <Object?>[],
  'cue_id': cueId,
  'started_at': '2026-10-21T08:00:00.000Z',
  'completed_at': null,
  'updated_at': (updatedAt ?? DateTime.utc(2026, 10, 21, 8)).toIso8601String(),
};

Map<String, Object?> _remoteTimer(
  String id, {
  String owner = 'u1',
  int durationSec = 120,
}) => {
  'id': id,
  'user_created': owner,
  'date': '2026-10-20T07:00:00.000Z',
  'duration_sec': durationSec,
  'cat': null,
  'cue_id': null,
};

Map<String, Object?> _remoteSlot(
  String id, {
  String owner = 'u1',
  String label = 'Tập',
  String? cat,
  DateTime? updatedAt,
  bool isDeleted = false,
}) => {
  'id': id,
  'user_created': owner,
  'day': 2,
  'time': '19:00',
  'label': label,
  'cat': cat,
  'updated_at': (updatedAt ?? DateTime.utc(2026, 10, 21, 8)).toIso8601String(),
  'is_deleted': isDeleted,
};
