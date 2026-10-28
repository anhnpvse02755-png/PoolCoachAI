import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

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
    for (final path in ['pool_matches', 'timer_sessions', 'schedule_slots', 'tournaments']) {
      server.routes['GET /items/$path'] = (_) => FakeDirectus.ok([]);
    }
  });

  tearDown(() => db.close());

  PracticeSyncService service() =>
      PracticeSyncService(db: db, auth: auth, api: api, now: () => now);

  TournamentRepository tournaments() => TournamentRepository(db, userId: 'u1', now: () => now, newId: () => 't1');

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
    test(
      'uploads a pending match with racks, shots and cue, then marks it synced',
      () async {
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
      },
    );

    test('keeps the cue id of a deleted cue when uploading', () async {
      await matches().start(match('m1'));
      await (db.update(db.poolMatchRows))
          .write(const PoolMatchRowsCompanion(cueId: Value('gone')));
      Map<String, Object?>? uploaded;
      server.routes['POST /items/pool_matches'] = (request) {
        uploaded = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'm1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(uploaded?['cue_id'], 'gone');
    });

    test(
      'patches an existing remote match only when the local one is newer',
      () async {
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
      },
    );

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
      expect((await db.select(db.poolMatchRows).get()).single.syncedAt, isNull);
    });

    test('never uploads another account\'s match', () async {
      await DriftMatchRepository(
        db,
        userId: 'u2',
        now: () => now,
      ).start(match('theirs'));

      expect(await service().syncNow(), SyncOutcome.done);

      expect(server.sent('POST', '/items/pool_matches'), isEmpty);
    });

    test(
      'an edit is pushed and a stale remote copy does not overwrite it',
      () async {
        await matches().start(match('m1'));
        await db
            .update(db.poolMatchRows)
            .write(PoolMatchRowsCompanion(syncedAt: Value(now)));
        await DriftMatchRepository(
          db,
          userId: 'u1',
          now: () => now.add(const Duration(hours: 2)),
        ).updateDetails(
          matchId: 'm1',
          gameType: PoolGameType.tenBall,
          playerName: 'An mới',
          opponentName: 'Bình',
          targetRacks: 5,
          tournamentId: null,
          roundLabel: null,
        );
        server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
          _remoteMatch('m1', updatedAt: now.add(const Duration(hours: 1))),
        ]);
        Map<String, Object?>? patched;
        server.routes['PATCH /items/pool_matches/m1'] = (request) {
          patched = FakeDirectus.body(request);
          return FakeDirectus.ok({'id': 'm1'});
        };

        expect(await service().syncNow(), SyncOutcome.done);

        expect(patched?['player_name'], 'An mới');
        expect(patched?['target_racks'], 5);
        expect(patched?['is_deleted'], false);
        expect((await matches().watchAll().first).single.playerName, 'An mới');
      },
    );

    test('a deleted match is pushed as a tombstone and stays hidden', () async {
      await matches().start(match('m1'));
      await db
          .update(db.poolMatchRows)
          .write(PoolMatchRowsCompanion(syncedAt: Value(now)));
      await DriftMatchRepository(
        db,
        userId: 'u1',
        now: () => now.add(const Duration(hours: 2)),
      ).remove('m1');
      server.routes['GET /items/pool_matches'] = (_) =>
          FakeDirectus.ok([_remoteMatch('m1', updatedAt: now)]);
      Map<String, Object?>? patched;
      server.routes['PATCH /items/pool_matches/m1'] = (request) {
        patched = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 'm1'});
      };

      expect(await service().syncNow(), SyncOutcome.done);

      expect(patched?['is_deleted'], true);
      expect(await matches().watchAll().first, isEmpty);
      final row = (await db.select(db.poolMatchRows).get()).single;
      expect(row.isDeleted, isTrue);
      expect(row.syncedAt, isNotNull);
    });

    test('a pulled tombstone is stored hidden', () async {
      await matches().start(match('m1'));
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        _remoteMatch(
          'm1',
          updatedAt: now.add(const Duration(hours: 1)),
          isDeleted: true,
        ),
        _remoteMatch('m2', isDeleted: true),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      expect(await matches().watchAll().first, isEmpty);
      final rows = await db.select(db.poolMatchRows).get();
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.isDeleted), isTrue);
    });

    test(
      'a newer remote live match wins over an older local tombstone',
      () async {
        await matches().start(match('m1'));
        await matches().remove('m1');
        server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
          _remoteMatch('m1', updatedAt: now.add(const Duration(hours: 1))),
        ]);

        expect(await service().syncNow(), SyncOutcome.done);

        expect(await matches().watchAll().first, hasLength(1));
      },
    );

    test(
      'an older remote live match does not revive a newer local tombstone',
      () async {
        await matches().start(match('m1'));
        await DriftMatchRepository(
          db,
          userId: 'u1',
          now: () => now.add(const Duration(hours: 2)),
        ).remove('m1');
        server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
          _remoteMatch('m1', updatedAt: now.add(const Duration(hours: 1))),
        ]);
        server.routes['PATCH /items/pool_matches/m1'] = (_) =>
            FakeDirectus.ok({'id': 'm1'});

        expect(await service().syncNow(), SyncOutcome.done);

        expect(await matches().watchAll().first, isEmpty);
      },
    );
  });

  group('timer sessions', () {
    test(
      'uploads own sessions only and never the orphan rows without an owner',
      () async {
        await DriftTimerSessionRepository(db, userId: 'u1').add(
          TimerSession(
            id: 't1',
            date: DateTime.utc(2026, 10, 21, 7),
            durationSec: 900,
            cat: SkillCategory.aiming,
          ),
        );
        await db
            .into(db.timerSessionRows)
            .insert(
              TimerSessionRowsCompanion.insert(
                id: 'orphan',
                date: DateTime.utc(2026, 10, 1),
                durationSec: 60,
              ),
            );
        await db
            .into(db.timerSessionRows)
            .insert(
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
      },
    );

    test('a duplicate id counts as already uploaded', () async {
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(
          id: 't1',
          date: DateTime.utc(2026, 10, 21),
          durationSec: 60,
        ),
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
        TimerSession(
          id: 't1',
          date: DateTime.utc(2026, 10, 21),
          durationSec: 60,
        ),
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

  group('nhóm nâng cao: hai trường (spec 2026-10-29 mục 6)', () {
    final slotNow = now;
    DriftScheduleRepository slots() =>
        DriftScheduleRepository(db, userId: 'u1', now: () => slotNow);

    Future<Map<String, Object?>> pushedTimer(SkillCategory? cat) async {
      await DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(
          id: 't1',
          date: DateTime.utc(2026, 10, 21, 7),
          durationSec: 900,
          cat: cat,
        ),
      );
      Map<String, Object?>? body;
      server.routes['POST /items/timer_sessions'] = (request) {
        body = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 't1'});
      };
      expect(await service().syncNow(), SyncOutcome.done);
      return body!;
    }

    test(
      'buổi tập Dựng cơ lên với cat null, cat_ext dungCo',
      () async {
        final adv = await pushedTimer(SkillCategory.dungCo);
        expect(adv, containsPair('cat', null));
        expect(adv, containsPair('cat_ext', 'dungCo'));
      },
    );

    test('buổi tập Ngắm bi lên với cat aiming, cat_ext null', () async {
      final basic = await pushedTimer(SkillCategory.aiming);
      expect(basic, containsPair('cat', 'aiming'));
      expect(basic, containsPair('cat_ext', null));
    });

    test('kéo buổi tập cat null, cat_ext nhayBi: lưu nhóm Nhảy bi', () async {
      server.routes['GET /items/timer_sessions'] = (_) => FakeDirectus.ok([
        {..._remoteTimer('t2'), 'cat_ext': 'nhayBi'},
        {..._remoteTimer('t3'), 'cat_ext': 'nhomTuongLai'},
      ]);
      expect(await service().syncNow(), SyncOutcome.done);
      final rows = {
        for (final r in await db.select(db.timerSessionRows).get()) r.id: r,
      };
      expect(rows['t2']!.cat, 'nhayBi');
      expect(rows['t3']!.cat, isNull);
    });

    test('lịch Dựng cơ lên với cat null, cat_ext dungCo, cat_ext_at = updated_at', () async {
      await slots().save(
        const ScheduleSlot(
          id: 's1',
          day: 2,
          time: '19:00',
          label: 'Tập dựng cơ',
          cat: SkillCategory.dungCo,
        ),
      );
      Map<String, Object?>? body;
      server.routes['POST /items/schedule_slots'] = (request) {
        body = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 's1'});
      };
      expect(await service().syncNow(), SyncOutcome.done);
      expect(body, containsPair('cat', null));
      expect(body, containsPair('cat_ext', 'dungCo'));
      expect(body!['cat_ext_at'], body!['updated_at']);
    });

    test('lịch Ngắm bi lên với cat aiming, cat_ext và cat_ext_at null', () async {
      await slots().save(
        const ScheduleSlot(
          id: 's1',
          day: 2,
          time: '19:00',
          label: 'Tập ngắm',
          cat: SkillCategory.aiming,
        ),
      );
      Map<String, Object?>? body;
      server.routes['POST /items/schedule_slots'] = (request) {
        body = FakeDirectus.body(request);
        return FakeDirectus.ok({'id': 's1'});
      };
      expect(await service().syncNow(), SyncOutcome.done);
      expect(body, containsPair('cat', 'aiming'));
      expect(body, containsPair('cat_ext', null));
      expect(body, containsPair('cat_ext_at', null));
    });

    test('xin trường cat_ext khi kéo buổi tập, cat_ext và cat_ext_at khi kéo lịch', () async {
      await service().syncNow();
      final timerFields = server
          .sent('GET', '/items/timer_sessions')
          .single
          .url
          .queryParameters['fields']!
          .split(',');
      final slotFields = server
          .sent('GET', '/items/schedule_slots')
          .single
          .url
          .queryParameters['fields']!
          .split(',');
      expect(timerFields, contains('cat_ext'));
      expect(slotFields, containsAll(['cat_ext', 'cat_ext_at']));
    });

    // Bốn bước của máy cũ và máy mới trên cùng một khung lịch. Chỉ tin cat_ext
    // khi cat_ext_at == updated_at: bản cũ sửa dòng làm updated_at đổi mà không
    // chạm cat_ext / cat_ext_at.
    Map<String, Object?> remoteSlotAt(
      String updatedAt, {
      String? cat,
      String? catExt,
      String? catExtAt,
      String label = 'Tập',
    }) => {
      ..._remoteSlot('s1', label: label, cat: cat),
      'updated_at': updatedAt,
      'cat_ext': catExt,
      'cat_ext_at': catExtAt,
    };

    Future<ScheduleSlot> pullSlot(Map<String, Object?> remote) async {
      server.routes['GET /items/schedule_slots'] = (_) =>
          FakeDirectus.ok([remote]);
      expect(await service().syncNow(), SyncOutcome.done);
      return (await slots().watchAll().first).single;
    }

    test('kéo lịch cat null, cat_ext dungCo, cat_ext_at = updated_at: nhóm Dựng cơ', () async {
      final slot = await pullSlot(
        remoteSlotAt(
          '2026-10-21T08:00:00.000Z',
          catExt: 'dungCo',
          catExtAt: '2026-10-21T08:00:00.000Z',
        ),
      );
      expect(slot.cat, SkillCategory.dungCo);
    });

    test('bốn bước: máy mới đặt Dựng cơ, máy cũ đổi Ngắm bi rồi Không nhóm: máy mới không còn nhóm', () async {
      const t1 = '2026-10-21T08:00:00.000Z';
      const t2 = '2026-10-21T09:00:00.000Z';
      const t3 = '2026-10-21T10:00:00.000Z';
      expect(
        (await pullSlot(remoteSlotAt(t1, catExt: 'dungCo', catExtAt: t1))).cat,
        SkillCategory.dungCo,
      );
      // Bản cũ đổi sang Ngắm bi: cat aiming, cat_ext và cat_ext_at đứng yên.
      expect(
        (await pullSlot(
          remoteSlotAt(t2, cat: 'aiming', catExt: 'dungCo', catExtAt: t1),
        )).cat,
        SkillCategory.aiming,
      );
      // Bản cũ đổi sang Không nhóm: cat null, cat_ext vẫn dungCo nhưng đã cũ.
      final slots3 = await pullSlot(
        remoteSlotAt(t3, catExt: 'dungCo', catExtAt: t1),
      );
      expect(slots3.cat, isNull);
      expect(
        (await db.select(db.scheduleSlotRows).getSingle()).cat,
        isNull,
      );
    });

    test('bản cũ chỉ sửa tên lịch (gửi cat null): máy mới thấy đúng cái bản cũ thấy, không nhóm', () async {
      const t1 = '2026-10-21T08:00:00.000Z';
      const t2 = '2026-10-21T09:00:00.000Z';
      await pullSlot(remoteSlotAt(t1, catExt: 'dungCo', catExtAt: t1));
      final slot = await pullSlot(
        remoteSlotAt(t2, label: 'Đổi tên', catExt: 'dungCo', catExtAt: t1),
      );
      expect(slot.label, 'Đổi tên');
      expect(slot.cat, isNull);
    });

    test('cat_ext_at thiếu hoặc lệch: bỏ qua cat_ext', () async {
      const t1 = '2026-10-21T08:00:00.000Z';
      const t2 = '2026-10-21T09:00:00.000Z';
      expect(
        (await pullSlot(remoteSlotAt(t1, catExt: 'dungCo'))).cat,
        isNull,
      );
      expect(
        (await pullSlot(remoteSlotAt(t2, catExt: 'dungCo', catExtAt: t1))).cat,
        isNull,
      );
    });

    test('cat_ext_at cùng một thời điểm nhưng khác định dạng (…Z và …000+00:00): vẫn tin cat_ext', () async {
      expect(
        (await pullSlot(
          remoteSlotAt(
            '2026-10-21T08:00:00.000Z',
            catExt: 'dungCo',
            catExtAt: '2026-10-21T08:00:00.000+00:00',
          ),
        )).cat,
        SkillCategory.dungCo,
      );
      expect(
        (await pullSlot(
          remoteSlotAt(
            '2026-10-21T08:00:00+00:00',
            catExt: 'nhayBi',
            catExtAt: '2026-10-21T08:00:00Z',
          ),
        )).cat,
        SkillCategory.nhayBi,
      );
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
      server.routes['GET /items/schedule_slots'] = (_) => FakeDirectus.ok([
        _remoteSlot('s2', label: 'Từ máy khác', cat: 'safety'),
      ]);

      expect(await service().syncNow(), SyncOutcome.done);

      final slot = (await slots().watchAll().first).single;
      expect(slot.label, 'Từ máy khác');
      expect(slot.cat, SkillCategory.safety);
    });

    test('does not upload orphan slots without an owner', () async {
      await db
          .into(db.scheduleSlotRows)
          .insert(
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

  group('tournaments', () {
    test('đẩy giải chưa đồng bộ đủ trường, ngày dạng YYYY-MM-DD, rồi đánh dấu', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2), endDate: DateTime(2026, 11, 3),
          location: 'CLB A', gameType: PoolGameType.nineBall, resultNote: 'Vào vòng 16', notes: 'n'));
      Map<String, Object?>? sent;
      server.routes['POST /items/tournaments'] = (req) {
        sent = FakeDirectus.body(req);
        return FakeDirectus.ok({'id': 't1'});
      };
      expect(await service().syncNow(), SyncOutcome.done);
      expect([sent!['id'], sent!['name'], sent!['start_date'], sent!['end_date'], sent!['location'], sent!['game_type'],
          sent!['result_note'], sent!['notes'], sent!['is_deleted']], ['t1', 'Giải Q1', '2026-11-02', '2026-11-03', 'CLB A', 'nineBall', 'Vào vòng 16', 'n', false]);
      expect(sent!.containsKey('user_created'), isFalse);
      expect((await db.select(db.tournamentRows).getSingle()).syncedAt, isNotNull);
    });

    test('xóa giải gửi tombstone bằng PATCH, không DELETE', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2)));
      await tournaments().remove('t1');
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', updatedAt: now.subtract(const Duration(hours: 1)))]);
      server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      await service().syncNow();
      expect(FakeDirectus.body(server.sent('PATCH', '/items/tournaments/t1').single)['is_deleted'], true);
      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });

    test('kéo giải từ máy khác: ngày về đúng ngày, đánh dấu đã đồng bộ', () async {
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t9', startDate: '2026-11-02', endDate: '2026-11-03')]);
      expect(await service().syncNow(), SyncOutcome.done);
      final r = await db.select(db.tournamentRows).getSingle();
      expect([r.id, r.userId, r.name, r.startDate, r.endDate, r.isDeleted], ['t9', 'u1', 'Giải xa', DateTime(2026, 11, 2), DateTime(2026, 11, 3), false]);
      expect(r.syncedAt, isNotNull);
    });

    test('Directus trả ngày kèm giờ vẫn về đúng ngày', () async {
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t9', startDate: '2026-11-02T00:00:00')]);
      expect(await service().syncNow(), SyncOutcome.done);
      expect((await db.select(db.tournamentRows).getSingle()).startDate, DateTime(2026, 11, 2));
    });

    test('bản máy chủ mới hơn thay bản trên máy; cũ hơn thì không ghi đè bản sửa trên máy', () async {
      await tournaments().create(TournamentDraft(name: 'Tên trên máy', startDate: DateTime(2026, 11, 2)));
      server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Cũ', updatedAt: now.subtract(const Duration(hours: 1)))]);
      await service().syncNow();
      expect((await db.select(db.tournamentRows).getSingle()).name, 'Tên trên máy');
      expect(server.sent('PATCH', '/items/tournaments/t1'), hasLength(1));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Mới', updatedAt: now.add(const Duration(hours: 1)))]);
      await service().syncNow();
      expect((await db.select(db.tournamentRows).getSingle()).name, 'Mới');
    });

    test('bản trên máy chờ đẩy nhưng cũ hơn bản máy chủ: không gửi gì, lấy bản máy chủ', () async {
      await tournaments().create(TournamentDraft(name: 'Tên trên máy', startDate: DateTime(2026, 11, 2)));
      server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Máy khác sửa sau', updatedAt: now.add(const Duration(hours: 1)))]);
      expect(await service().syncNow(), SyncOutcome.done);
      expect(server.sent('PATCH', '/items/tournaments/t1'), isEmpty);
      expect(server.sent('POST', '/items/tournaments'), isEmpty);
      final r = await db.select(db.tournamentRows).getSingle();
      expect([r.name, r.syncedAt != null], ['Máy khác sửa sau', true]);
    });

    test('giải đã đồng bộ không được đẩy lại', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2)));
      await (db.update(db.tournamentRows)).write(TournamentRowsCompanion(syncedAt: Value(now)));
      server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', updatedAt: now.subtract(const Duration(hours: 1)))]);
      expect(await service().syncNow(), SyncOutcome.done);
      expect(server.sent('POST', '/items/tournaments'), isEmpty);
      expect(server.sent('PATCH', '/items/tournaments/t1'), isEmpty);
      expect((await db.select(db.tournamentRows).getSingle()).name, 'Giải Q1');
    });

    test('tombstone từ máy khác được áp lên giải đã đồng bộ trên máy này', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2)));
      await (db.update(db.tournamentRows)).write(TournamentRowsCompanion(syncedAt: Value(now)));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', isDeleted: true, updatedAt: now.add(const Duration(hours: 1)))]);
      expect(await service().syncNow(), SyncOutcome.done);
      final r = await db.select(db.tournamentRows).getSingle();
      expect([r.isDeleted, r.syncedAt != null], [true, true]);
      expect(await tournaments().watchAll().first, isEmpty);
    });

    test('giải của tài khoản khác bị từ chối; trận đã đồng bộ trước đó vẫn lên', () async {
      await matches().start(match('m1'));
      server.routes['POST /items/pool_matches'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t9', owner: 'u2')]);
      expect(await service().syncNow(), SyncOutcome.failed);
      expect((await db.select(db.poolMatchRows).getSingle()).syncedAt, isNotNull);
      expect(await db.select(db.tournamentRows).get(), isEmpty);
    });

    test('id giải đã nằm trên máy dưới tài khoản khác: từ chối, không ghi đè', () async {
      await TournamentRepository(db, userId: 'u2', now: () => now, newId: () => 't1')
          .create(TournamentDraft(name: 'Của u2', startDate: DateTime(2026, 11, 2)));
      server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Của u1')]);
      expect(await service().syncNow(), SyncOutcome.failed);
      final r = await db.select(db.tournamentRows).getSingle();
      expect([r.userId, r.name], ['u2', 'Của u2']);
    });

    test('giải hỏng từ máy chủ (thiếu id, ngày sai) không lưu, sync báo failed, trận vẫn lên', () async {
      await matches().start(match('m1'));
      server.routes['POST /items/pool_matches'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      for (final bad in [
        {..._remoteTournament('t9'), 'id': null},
        {..._remoteTournament('t9'), 'end_date': '2026-13-40'},
        {..._remoteTournament('t9'), 'start_date': '2026-02-30'},
      ]) {
        server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([bad]);
        expect(await service().syncNow(), SyncOutcome.failed);
        expect(await db.select(db.tournamentRows).get(), isEmpty);
      }
      expect((await db.select(db.poolMatchRows).getSingle()).syncedAt, isNotNull);
    });

    test('giải mới tạo trên máy tự kích hoạt đồng bộ (start())', () async {
      server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      final svc = service()..start();
      addTearDown(svc.dispose);
      await pumpEventQueue();
      await tournaments().create(TournamentDraft(name: 'Giải mới', startDate: DateTime(2026, 11, 2)));
      await pumpEventQueue(times: 200);
      expect(server.sent('POST', '/items/tournaments'), hasLength(1));
      expect((await db.select(db.tournamentRows).getSingle()).syncedAt, isNotNull);
    });

    test('lỗi 4xx với giải: không gửi lại tới khi giải đổi', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2)));
      server.routes['POST /items/tournaments'] = (_) => FakeDirectus.error(403, 'FORBIDDEN');
      final svc = service();
      expect(await svc.syncNow(), SyncOutcome.done);
      expect(await svc.syncNow(), SyncOutcome.done);
      expect(server.sent('POST', '/items/tournaments'), hasLength(1));
      expect((await db.select(db.tournamentRows).getSingle()).syncedAt, isNull);
    });
  });

  group('trường giải ở trận', () {
    test('trận mang tournament_id và round_label lên và về', () async {
      await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 10, 21)));
      await matches().start(PoolMatch(id: 'm1', gameType: PoolGameType.nineBall, playerName: 'An', opponentName: 'Bình', targetRacks: 3,
          rackWinners: const [], startedAt: DateTime.utc(2026, 10, 21, 8), tournamentId: 't1', roundLabel: 'Tứ kết'));
      Map<String, Object?>? uploaded;
      server.routes['POST /items/pool_matches'] = (req) {
        uploaded = FakeDirectus.body(req);
        return FakeDirectus.ok({'id': 'm1'});
      };
      server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      await service().syncNow();
      expect([uploaded!['tournament_id'], uploaded!['round_label']], ['t1', 'Tứ kết']);
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        {..._remoteMatch('m2', updatedAt: now.add(const Duration(hours: 1))), 'tournament_id': 't1', 'round_label': 'Bán kết'},
      ]);
      await service().syncNow();
      final m2 = await (db.select(db.poolMatchRows)..where((r) => r.id.equals('m2'))).getSingle();
      expect([m2.tournamentId, m2.roundLabel], ['t1', 'Bán kết']);
    });

    test('PATCH trận cố ý gửi tournament_id và round_label, kể cả null khi không thuộc giải', () async {
      await matches().start(match('m1'));
      server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
        {..._remoteMatch('m1', updatedAt: now.subtract(const Duration(hours: 1))), 'tournament_id': 'cu', 'round_label': 'Cũ'},
      ]);
      server.routes['PATCH /items/pool_matches/m1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
      expect(await service().syncNow(), SyncOutcome.done);
      final body = FakeDirectus.body(server.sent('PATCH', '/items/pool_matches/m1').single);
      expect(body.containsKey('tournament_id'), isTrue);
      expect(body.containsKey('round_label'), isTrue);
      expect([body['tournament_id'], body['round_label']], [null, null]);
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
    expect((await db.select(db.poolMatchRows).get()).single.syncedAt, isNull);
  });
}

Map<String, Object?> _remoteMatch(
  String id, {
  String owner = 'u1',
  DateTime? updatedAt,
  List<String> rackWinners = const [],
  String? cueId,
  bool isDeleted = false,
}) => {
  'id': id,
  'user_created': owner,
  'is_deleted': isDeleted,
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

Map<String, Object?> _remoteTournament(
  String id, {
  String owner = 'u1',
  DateTime? updatedAt,
  bool isDeleted = false,
  String startDate = '2026-11-02',
  String? endDate,
  String name = 'Giải xa',
}) => {
  'id': id,
  'user_created': owner,
  'name': name,
  'start_date': startDate,
  'end_date': endDate,
  'location': null,
  'game_type': null,
  'result_note': null,
  'notes': null,
  'created_at': '2026-10-20T08:00:00.000Z',
  'updated_at': (updatedAt ?? DateTime.utc(2026, 10, 21, 8)).toIso8601String(),
  'is_deleted': isDeleted,
};
