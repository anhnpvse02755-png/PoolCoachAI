import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  final now = DateTime(2026, 10, 15, 12);
  final older = DateTime(2026, 10, 14, 9);
  final newer = DateTime(2026, 10, 15, 9);

  RoadmapSyncService build() {
    final s = RoadmapSyncService(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => now,
    );
    addTearDown(s.dispose);
    return s;
  }

  void serve({List<Map<String, Object?>> goals = const [], List<Map<String, Object?>> achievements = const []}) {
    server.routes['GET /items/player_goals'] = (_) => FakeDirectus.ok(goals);
    server.routes['POST /items/player_goals'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/player_goals/u1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/achievements'] = (_) => FakeDirectus.ok(achievements);
    server.routes['POST /items/achievements'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  }

  GoalRecord skill(SkillCategory c, DateTime at) => GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g-${c.name}', kind: GoalKind.thuanThucKyNang, category: c, createdAt: at));

  Future<void> local(GoalRecord g, {DateTime? syncedAt}) => db
      .into(db.playerGoalRows)
      .insertOnConflictUpdate(toGoalRow(g, userId: 'u1', syncedAt: syncedAt));

  Map<String, Object?> remote(GoalRecord g) => toRemoteGoal(toGoalRow(g, userId: 'u1'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
  });
  tearDown(() => db.close());

  test('máy chủ chưa có: POST mục tiêu rồi đánh dấu đã đồng bộ', () async {
    serve();
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.done);
    final body = FakeDirectus.body(server.sent('POST', '/items/player_goals').single);
    expect(body['id'], 'u1');
    expect(body['kind'], 'thuanThucKyNang');
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('máy chủ mới hơn: ghi đè máy này, không gửi gì', () async {
    serve(goals: [remote(skill(SkillCategory.bank, newer))]);
    await local(skill(SkillCategory.kick, older), syncedAt: older);
    await build().syncNow();
    final row = await db.select(db.playerGoalRows).getSingle();
    expect(row.category, 'bank');
    expect(row.syncedAt, now);
    expect(server.sent('POST', '/items/player_goals'), isEmpty);
    expect(server.sent('PATCH', '/items/player_goals/u1'), isEmpty);
  });

  test('máy chủ bỏ mục tiêu sau: máy này cũng thành dòng rỗng', () async {
    // Bản máy chủ có cột null phải ghi đè được cột cũ trên máy này (R2).
    serve(goals: [remote(GoalRecord(updatedAt: newer))]);
    await local(skill(SkillCategory.kick, older), syncedAt: older);
    await build().syncNow();
    final row = await db.select(db.playerGoalRows).getSingle();
    expect(row.kind, isNull);
    expect(row.category, isNull);
    expect(row.updatedAt, newer);
  });

  test('máy này bỏ mục tiêu sau: PATCH dòng rỗng lên máy chủ', () async {
    serve(goals: [remote(skill(SkillCategory.bank, older))]);
    await local(GoalRecord(updatedAt: newer));
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_goals/u1').single);
    expect(body.containsKey('id'), isFalse);
    expect(body['kind'], isNull);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('thành tích chưa đồng bộ được gửi lên; trùng trên máy chủ vẫn coi là đã đồng bộ', () async {
    serve();
    var first = true;
    server.routes['POST /items/achievements'] = (req) {
      if (first) {
        first = false;
        return FakeDirectus.ok(jsonDecode(req.body));
      }
      return FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    };
    for (final ref in ['7', '14']) {
      await db.into(db.achievementRows).insert(toAchievementRow(
          Achievement(kind: AchievementKind.chuoiNgay, refId: ref, achievedAt: newer),
          userId: 'u1'));
    }
    await build().syncNow();
    expect(server.sent('POST', '/items/achievements'), hasLength(2));
    expect((await db.select(db.achievementRows).get()).every((r) => r.syncedAt == now), isTrue);
  });

  test('chứng nhận không bao giờ được gửi lên; loại khác vẫn gửi (S13)', () async {
    serve();
    await db.into(db.achievementRows).insert(toAchievementRow(
        Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: newer),
        userId: 'u1'));
    await db.into(db.achievementRows).insert(toAchievementRow(
        Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: newer),
        userId: 'u1'));
    await build().syncNow();
    final posts = server.sent('POST', '/items/achievements');
    expect(posts, hasLength(1));
    expect(jsonDecode(posts.single.body)['kind'], 'chuoiNgay');
  });

  test('thành tích bị máy chủ từ chối (4xx khác) nằm chờ, không chặn mục tiêu', () async {
    serve();
    server.routes['POST /items/achievements'] = (_) => FakeDirectus.error(403, 'FORBIDDEN');
    await db.into(db.achievementRows).insert(toAchievementRow(
        Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: newer), userId: 'u1'));
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.done);
    expect((await db.select(db.achievementRows).getSingle()).syncedAt, isNull);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('kéo thành tích từ máy chủ về', () async {
    final a = Achievement(kind: AchievementKind.duDieuKienLenCap, refId: 'd1', achievedAt: older);
    serve(achievements: [toRemoteAchievement(toAchievementRow(a, userId: 'u1'))]);
    await build().syncNow();
    final row = await db.select(db.achievementRows).getSingle();
    expect(toAchievement(row), a);
    expect(row.syncedAt, now);
  });

  test('kéo thành tích: loại lạ bị bỏ qua, các dòng còn lại vẫn về', () async {
    final a = Achievement(kind: AchievementKind.duDieuKienLenCap, refId: 'd1', achievedAt: older);
    serve(achievements: [
      {...toRemoteAchievement(toAchievementRow(a, userId: 'u1')), 'id': 'unknown-1', 'kind': 'zzz'},
      toRemoteAchievement(toAchievementRow(a, userId: 'u1')),
    ]);
    expect(await build().syncNow(), SyncOutcome.done);
    expect(toAchievement(await db.select(db.achievementRows).getSingle()), a);
  });

  test('mất mạng: không ném, trả offline', () async {
    serve();
    server.offline = true;
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.offline);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, isNull);
  });

  test('đếm dòng chờ của mọi người trên máy', () async {
    await local(skill(SkillCategory.kick, newer));
    expect(await watchPendingRoadmap(db).first, 1);
  });

  test('mục tiêu có hạng đích: POST mang target_rank', () async {
    serve();
    await local(GoalRecord(
        updatedAt: newer,
        goal: PlayerGoal(goalId: 'g-rank', kind: GoalKind.lenHang, createdAt: newer, targetRank: Rank.d)));
    expect(await build().syncNow(), SyncOutcome.done);
    final body = FakeDirectus.body(server.sent('POST', '/items/player_goals').single);
    expect(body['target_rank'], 'd');
  });

  test('kéo mục tiêu có hạng đích về; dòng máy chủ cũ không có target_rank vẫn đọc được', () async {
    final withRank = GoalRecord(
        updatedAt: newer,
        goal: PlayerGoal(goalId: 'g-rank', kind: GoalKind.lenHang, createdAt: newer, targetRank: Rank.c));
    serve(goals: [remote(withRank)]);
    await build().syncNow();
    expect((await db.select(db.playerGoalRows).getSingle()).targetRank, 'c');

    final legacy = remote(GoalRecord(
        updatedAt: newer.add(const Duration(hours: 1)),
        goal: PlayerGoal(goalId: 'g-old', kind: GoalKind.lenHang, createdAt: newer)))
      ..remove('target_rank');
    serve(goals: [legacy]);
    await build().syncNow();
    expect((await db.select(db.playerGoalRows).getSingle()).targetRank, isNull);
  });
}
