import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/sync/cue_equipment_sync.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart'
    show SyncOutcome, SyncService;
import 'package:poolcoachai/domain/assessment/bu_placement.dart' show TableSize;
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/certification_summary.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

// tên/mã mà chính bản này chưa biết — với bản đã phát hành đó là tên mới của plan 2026-10-29
const unknownCategory = 'dungCo';
// tên/mã mà chính bản này chưa biết — với bản đã phát hành đó là tên mới của plan 2026-10-29
const unknownDrillId = 'd11';

/// Bản đã phát hành chưa biết Giải đấu. Các test này chứng minh nó bỏ qua
/// trường mới của Directus (tournament_id, round_label) và chỉ gửi khoá nó
/// biết. Chỉ so các trường bản cũ biết, và phát biểu bất biến chung
/// (danh sách `fields` tường minh, khoá PATCH nằm trong danh sách đó).
void main() {
  late AppDatabase db;
  late FakeDirectus server;
  final now = DateTime(2026, 10, 28, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
    for (final path in [
      'pool_matches',
      'timer_sessions',
      'schedule_slots',
      'tournaments',
      'player_goals',
      'achievements',
    ]) {
      server.routes['GET /items/$path'] = (_) => FakeDirectus.ok([]);
    }
    server.routes['POST /items/achievements'] = (req) =>
        FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/player_goals/u1'] = (req) =>
        FakeDirectus.ok(jsonDecode(req.body));
  });

  tearDown(() => db.close());

  DirectusClient api() =>
      DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);

  PracticeSyncService service() {
    final s = PracticeSyncService(
      db: db,
      auth: FakeAuthRepository.signedIn(userId: 'u1'),
      api: api(),
      now: () => now,
    );
    addTearDown(s.dispose);
    return s;
  }

  RoadmapSyncService roadmapService() {
    final s = RoadmapSyncService(
      db: db,
      auth: FakeAuthRepository.signedIn(userId: 'u1'),
      api: api(),
      now: () => now,
    );
    addTearDown(s.dispose);
    return s;
  }

  List<Object?> shippedGoal(GoalRecord r) => [
    r.updatedAt,
    r.goal?.goalId,
    r.goal?.kind,
    r.goal?.category,
    r.goal?.eventDate,
    r.goal?.createdAt,
    r.goal?.targetRank,
  ];
  const goalJson = {
    'id': 'u1',
    'goal_id': 'g1',
    'kind': 'chuanBiGiai',
    'category': null,
    'event_date': '2026-11-01T17:00:00.000Z',
    'created_at': '2026-10-28T03:00:00.000Z',
    'updated_at': '2026-10-28T03:00:00.000Z',
    'target_rank': null,
  };
  Map<String, Object?> matchJson({Map<String, Object?> extra = const {}}) => {
    'id': 'm1',
    'user_created': 'u1',
    'game_type': 'nineBall',
    'player_name': 'An',
    'opponent_name': 'Bình',
    'target_racks': 3,
    'rack_winners': ['player'],
    'shots': <Object?>[],
    'cue_id': null,
    'started_at': '2026-10-21T08:00:00.000Z',
    'completed_at': null,
    'updated_at': '2026-10-21T08:00:00.000Z',
    'is_deleted': false,
    ...extra,
  };

  test('goalFromRemote bỏ qua tournament_id và trường lạ', () {
    expect(
      shippedGoal(
        goalFromRemote({
          ...goalJson,
          'tournament_id': 't1',
          'x_future_field': 1,
        }),
      ),
      shippedGoal(goalFromRemote(goalJson)),
    );
  });

  test('kéo trận mang tournament_id, round_label và trường lạ: lưu đủ các cột bản cũ biết', () async {
    server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
      matchJson(
        extra: {
          'tournament_id': 't1',
          'round_label': 'Tứ kết',
          'x_future_field': true,
        },
      ),
    ]);
    expect(await service().syncNow(), SyncOutcome.done);
    final r = await db.select(db.poolMatchRows).getSingle();
    expect(
      [
        r.id,
        r.userId,
        r.gameType,
        r.playerName,
        r.opponentName,
        r.targetRacks,
        r.rackWinners,
        r.isDeleted,
      ],
      ['m1', 'u1', 'nineBall', 'An', 'Bình', 3, '["player"]', false],
    );
    expect(r.syncedAt, isNotNull);
  });

  test(
    'mỗi lần kéo xin đúng danh sách trường của chính bản đó, không bao giờ *',
    () async {
      await service().syncNow();
      await roadmapService().syncNow();
      final matchFields = server
          .sent('GET', '/items/pool_matches')
          .single
          .url
          .queryParameters['fields']!;
      final goalFields = server
          .sent('GET', '/items/player_goals')
          .single
          .url
          .queryParameters['fields']!;
      expect(
        [matchFields, goalFields],
        [poolMatchRemoteFields, remoteGoalFields],
      );
      expect(
        [matchFields.contains('*'), goalFields.contains('*')],
        [false, false],
      );
    },
  );

  test(
    'PATCH trận chỉ gửi khoá nằm trong danh sách trường của chính bản đó',
    () async {
      await DriftMatchRepository(db, userId: 'u1', now: () => now).start(
        PoolMatch(
          id: 'm1',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 3,
          rackWinners: const [],
          startedAt: DateTime(2026, 10, 21, 8),
        ),
      );
      // updated_at cũ hơn bản trên máy
      server.routes['GET /items/pool_matches'] = (_) =>
          FakeDirectus.ok([matchJson()]);
      server.routes['PATCH /items/pool_matches/m1'] = (req) =>
          FakeDirectus.ok(jsonDecode(req.body));
      await service().syncNow();
      final keys = FakeDirectus.body(
        server.sent('PATCH', '/items/pool_matches/m1').single,
      ).keys;
      expect(keys, isNotEmpty);
      expect(poolMatchRemoteFields.split(','), containsAll(keys));
    },
  );

  test(
    'PATCH mục tiêu chỉ gửi khoá nằm trong danh sách trường của chính bản đó',
    () async {
      // cũ hơn bản trên máy
      server.routes['GET /items/player_goals'] = (_) =>
          FakeDirectus.ok([goalJson]);
      await RoadmapRepository(
        db,
        userId: 'u1',
        now: () => now,
        newId: () => 'g2',
      ).setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2));
      await roadmapService().syncNow();
      final keys = FakeDirectus.body(
        server.sent('PATCH', '/items/player_goals/u1').single,
      ).keys;
      expect(keys, isNotEmpty);
      expect(remoteGoalFields.split(','), containsAll(keys));
    },
  );

  group('bản đã phát hành gặp nhóm kỹ năng nó chưa biết (spec 2026-10-29 §6)', () {
    setUp(() {
      server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([]);
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok([]);
    });

    Map<String, Object?> timerJson({
      Object? cat,
      Map<String, Object?> extra = const {},
    }) => {
      'id': 't1',
      'user_created': 'u1',
      'date': '2026-10-27T08:00:00.000Z',
      'duration_sec': 600,
      'cat': cat,
      'cue_id': null,
      ...extra,
    };
    Map<String, Object?> slotJson({
      Object? cat,
      Map<String, Object?> extra = const {},
    }) => {
      'id': 's1',
      'user_created': 'u1',
      'day': 2,
      'time': '19:00',
      'label': 'Tập tối',
      'cat': cat,
      'updated_at': '2026-10-27T08:00:00.000Z',
      'is_deleted': false,
      ...extra,
    };
    Map<String, Object?> cueJson({
      required List<String> skills,
      Map<String, Object?> extra = const {},
    }) => {
      'id': 'c1',
      'user_created': 'u1',
      'name': 'Cơ Một',
      'type': 'playing',
      'weight_grams': null,
      'shaft_brand': null,
      'tip_diameter_mm': null,
      'tip_brand': null,
      'tip_hardness': null,
      'butt_brand': null,
      'skill_categories': skills,
      'last_tip_maintenance': null,
      'tip_maintenance_due_date': null,
      'updated_at': '2026-10-27T08:00:00.000Z',
      'is_deleted': false,
      ...extra,
    };

    CueEquipmentSyncService cueService() {
      final s = CueEquipmentSyncService(
        db: db,
        auth: FakeAuthRepository.signedIn(userId: 'u1'),
        api: api(),
        now: () => now,
      );
      addTearDown(s.dispose);
      return s;
    }

    SyncService drillLogService() {
      final s = SyncService(
        db: db,
        auth: FakeAuthRepository.signedIn(userId: 'u1'),
        api: api(),
        now: () => now,
      );
      addTearDown(s.dispose);
      return s;
    }

    Future<void> pendingSlot() => db
        .into(db.scheduleSlotRows)
        .insert(
          ScheduleSlotRowsCompanion.insert(
            id: 'local1',
            userId: const Value('u1'),
            day: 1,
            time: '10:00',
            label: 'Chờ lên',
          ),
        );

    test(
      'cat buổi tập lạ: cả lượt practice thất bại, lịch chờ không lên',
      () async {
        await pendingSlot();
        server.routes['GET /items/timer_sessions'] = (_) =>
            FakeDirectus.ok([timerJson(cat: unknownCategory)]);
        expect(await service().syncNow(), SyncOutcome.failed);
        expect(server.sent('POST', '/items/schedule_slots'), isEmpty);
        expect(await db.select(db.timerSessionRows).get(), isEmpty);
      },
    );

    test('cat lịch tập lạ: thất bại, giải không được kéo', () async {
      server.routes['GET /items/schedule_slots'] = (_) =>
          FakeDirectus.ok([slotJson(cat: unknownCategory)]);
      expect(await service().syncNow(), SyncOutcome.failed);
      expect(server.sent('GET', '/items/tournaments'), isEmpty);
    });

    test(
      'kỹ năng lạ trong hồ sơ cơ: đồng bộ cơ thất bại, không lưu cơ',
      () async {
        server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([
          cueJson(skills: ['aiming', unknownCategory]),
        ]);
        expect(await cueService().syncNow(), SyncOutcome.failed);
        expect(await db.select(db.cueEquipmentRows).get(), isEmpty);
      },
    );

    test(
      'nhóm lạ trong mục tiêu: goalFromRemote ném, đồng bộ Lộ trình thất bại',
      () async {
        final bad = {
          ...goalJson,
          'kind': 'thuanThucKyNang',
          'category': unknownCategory,
        };
        expect(() => goalFromRemote(bad), throwsArgumentError);
        server.routes['GET /items/player_goals'] = (_) =>
            FakeDirectus.ok([bad]);
        expect(await roadmapService().syncNow(), SyncOutcome.failed);
      },
    );

    test('đường an toàn: trường cũ hợp lệ, trường _ext lạ bị bỏ qua', () async {
      server.routes['GET /items/timer_sessions'] = (_) => FakeDirectus.ok([
        timerJson(cat: null, extra: {'cat_ext': unknownCategory}),
      ]);
      server.routes['GET /items/schedule_slots'] = (_) => FakeDirectus.ok([
        slotJson(cat: null, extra: {'cat_ext': unknownCategory}),
      ]);
      expect(await service().syncNow(), SyncOutcome.done);
      expect((await db.select(db.timerSessionRows).getSingle()).cat, isNull);
      expect((await db.select(db.scheduleSlotRows).getSingle()).cat, isNull);

      server.routes['GET /items/cue_equipment'] = (_) => FakeDirectus.ok([
        cueJson(
          skills: ['aiming'],
          extra: {
            'skill_categories_ext': [unknownCategory],
          },
        ),
      ]);
      expect(await cueService().syncNow(), SyncOutcome.done);
      expect(
        (await db.select(db.cueEquipmentRows).getSingle()).skillCategories,
        '["aiming"]',
      );

      expect(
        goalFromRemote({
          ...goalJson,
          'kind': null,
          'category': null,
          'goal_id': 'g1',
          'category_ext': unknownCategory,
        }).goal,
        isNull,
      );
    });

    test('buổi tập của bài lạ: được lưu, Intelligence bỏ qua', () async {
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok([
        {
          'id': 'l1',
          'drill_id': unknownDrillId,
          'date': '2026-10-27T08:00:00.000Z',
          'score': 3,
          'attempts': null,
          'notes': null,
          'duration_sec': 60,
        },
      ]);
      expect(await drillLogService().syncNow(), SyncOutcome.done);
      final rows = await db.select(db.drillLogRows).get();
      expect(rows.map((r) => r.id), ['l1']);
      final pi = computePlayerIntelligence(
        drills: seedDrills,
        logs: [toDrillLog(rows.single)],
      );
      expect(pi.hasAnyData, isFalse);
      for (final c in SkillCategory.values) {
        expect(pi.categories[c]!.sessionCount, 0, reason: c.name);
      }
    });

    test('bài kiểm tra của bài lạ: dựng được, chứng nhận bỏ qua', () {
      final row = skillTestFromRemote(
        {
          'id': 'k1',
          'drill_id': unknownDrillId,
          'drill_level': 1,
          'table_size': TableSize.sevenFoot.name,
          'started_at': '2026-10-27T08:00:00.000Z',
          'completed_at': '2026-10-27T08:10:00.000Z',
          'cancelled_at': null,
          'score': 3,
          'attempts': null,
          'passed': true,
          'notes': null,
          'pass_threshold': null,
          'target': 3,
        },
        userId: 'u1',
        syncedAt: now,
      );
      expect(row, isNotNull);
      final test = toSkillTest(row!);
      expect(test, isNotNull);
      expect(
        certificationSummary(
          drills: seedDrills,
          logs: const [],
          tests: [test!],
        ).groups,
        isEmpty,
      );
    });
  });
}
