import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_match_repository.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

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
}
