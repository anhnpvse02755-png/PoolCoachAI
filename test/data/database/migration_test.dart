import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';

/// Nâng từ v1 → v2 (spec mục 5.1): buổi tập cũ không có chủ nên bị bỏ,
/// và máy có chỗ lưu phiên đăng nhập.
void main() {
  test('nâng từ v1 lên v2 thì bỏ buổi tập cũ và có bảng phiên đăng nhập', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
          'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
          'attempts INTEGER NULL, notes TEXT NULL);',
        );
        raw.execute(
          "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1758600000, 7.0, 10, NULL);",
        );
        _createPracticeTables(raw);
        raw.execute('PRAGMA user_version = 1;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(await db.select(db.authSessionRows).get(), isEmpty);

    await db
        .into(db.drillLogRows)
        .insert(
          DrillLogRowsCompanion.insert(
            id: 'moi',
            userId: 'u1',
            drillId: 'd1',
            date: DateTime(2026, 9, 23),
            score: 7,
          ),
        );
    final row = (await db.select(db.drillLogRows).get()).single;
    expect(row.userId, 'u1');
    expect(row.syncedAt, isNull);
  });

  test('nâng từ v2 lên v3 thì có ba bảng hạng/kiểm tra và giữ nguyên buổi tập', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
          'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
          'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
          'synced_at INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
        );
        _createPracticeTables(raw);
        raw.execute('PRAGMA user_version = 2;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final legacyLog = (await db.select(db.drillLogRows).get()).single;
    expect(legacyLog.id, 'cu');
    expect(legacyLog.durationSec, isNull);

    final at = DateTime(2026, 10, 14, 9);
    await db
        .into(db.playerRankRows)
        .insert(
          PlayerRankRowsCompanion.insert(
            userId: 'u1',
            onboardingState: 'skipped',
            updatedAt: at,
          ),
        );
    await db
        .into(db.buTestRows)
        .insert(
          BuTestRowsCompanion.insert(
            id: 't1',
            userId: 'u1',
            startedAt: at,
            tableSize: 'nineFootPlus',
          ),
        );
    await db
        .into(db.buDrillResultRows)
        .insert(
          BuDrillResultRowsCompanion.insert(
            id: 'r1',
            testId: 't1',
            drillId: 'F1',
            attempts: '{"shots":[true]}',
            recordedAt: at,
          ),
        );

    final rank = (await db.select(db.playerRankRows).get()).single;
    expect(rank.rank, isNull);
    expect(rank.syncedAt, isNull);
    final result = (await db.select(db.buDrillResultRows).get()).single;
    expect(result.score, isNull, reason: 'điểm bài null tới khi bài xong (D8)');

    // Một bài chỉ có một dòng kết quả trong một lần kiểm tra.
    await expectLater(
      db
          .into(db.buDrillResultRows)
          .insert(
            BuDrillResultRowsCompanion.insert(
              id: 'r2',
              testId: 't1',
              drillId: 'F1',
              attempts: '{"shots":[]}',
              recordedAt: at,
            ),
          ),
      throwsA(isA<Exception>()), // SqliteException: vi phạm khoá duy nhất
    );
  });

  test('nâng từ v3 lên v4 thì có bảng mục tiêu và thành tích, giữ nguyên buổi tập', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
          'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
          'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
          'synced_at INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
        );
        _createPracticeTables(raw);
        raw.execute('PRAGMA user_version = 3;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final legacyLog = (await db.select(db.drillLogRows).get()).single;
    expect(legacyLog.id, 'cu');
    expect(legacyLog.durationSec, isNull);

    final at = DateTime(2026, 10, 15, 9);
    await db
        .into(db.playerGoalRows)
        .insert(PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: at));
    await db
        .into(db.achievementRows)
        .insert(
          AchievementRowsCompanion.insert(
            id: 'x',
            userId: 'u1',
            kind: 'chuoiNgay',
            refId: '7',
            achievedAt: at,
          ),
        );
    expect((await db.select(db.playerGoalRows).get()).single.kind, isNull);
    expect((await db.select(db.achievementRows).get()).single.refId, '7');
  });

  test(
    'nâng từ v4 lên v10 giữ dữ liệu cũ và thêm bảng Timer, Equipment, Play',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          _createOwnedDrillLogTable(raw);
          _createPracticeTables(raw);
          raw.execute(
            "INSERT INTO schedule_slot_rows VALUES ('s1', 0, '19:00', 'Tập ngắm', 'aiming');",
          );
          raw.execute(
            "INSERT INTO timer_session_rows VALUES ('t1', 1760400000, 900, NULL, NULL);",
          );
          _createV13PlayerGoalTable(raw);
          raw.execute('PRAGMA user_version = 4;');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      expect(db.schemaVersion, 14);
      expect((await db.select(db.scheduleSlotRows).get()).single.userId, '');
      expect((await db.select(db.timerSessionRows).get()).single.userId, '');

      await db
          .into(db.timerSessionRows)
          .insert(
            TimerSessionRowsCompanion.insert(
              id: 't2',
              userId: const Value('u1'),
              date: DateTime(2026, 10, 15, 9),
              durationSec: 1200,
            ),
          );
      final currentUserSessions = await (db.select(
        db.timerSessionRows,
      )..where((row) => row.userId.equals('u1'))).get();
      expect(currentUserSessions.map((row) => row.id), ['t2']);
      expect(await db.select(db.cueEquipmentRows).get(), isEmpty);
      expect(await db.select(db.poolMatchRows).get(), isEmpty);
    },
  );

  test('nâng từ v7 lên v10 thêm nhật ký cú và sync Equipment', () async {
    final startedAt = DateTime.utc(2026, 10, 20);
    final timestamp = startedAt.millisecondsSinceEpoch ~/ 1000;
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE pool_match_rows ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'user_id TEXT NOT NULL, '
          'game_type TEXT NOT NULL, '
          'player_name TEXT NOT NULL, '
          'opponent_name TEXT NOT NULL, '
          'target_racks INTEGER NOT NULL, '
          'rack_winners TEXT NOT NULL, '
          'started_at INTEGER NOT NULL, '
          'completed_at INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO pool_match_rows VALUES "
          "('match-old', 'u1', 'nineBall', 'An', 'Bình', 5, '[]', "
          '$timestamp, NULL);',
        );
        raw.execute(
          'CREATE TABLE cue_equipment_rows ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'user_id TEXT NOT NULL, '
          'name TEXT NOT NULL, '
          'type TEXT NOT NULL, '
          'weight_grams INTEGER NULL, '
          'tip_diameter_mm REAL NULL, '
          'tip_hardness TEXT NULL, '
          'skill_categories TEXT NOT NULL, '
          'last_tip_maintenance INTEGER NULL, '
          'tip_maintenance_due_date INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO cue_equipment_rows VALUES "
          "('cue-v7', 'u1', 'Cơ cũ', 'playing', 540, NULL, NULL, "
          "'[]', NULL, NULL);",
        );
        _createOwnedDrillLogTable(raw);
        _createOwnedPracticeTables(raw);
        _createV13PlayerGoalTable(raw);
        raw.execute('PRAGMA user_version = 7;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final match = (await db.select(db.poolMatchRows).get()).single;
    expect(match.id, 'match-old');
    expect(match.userId, 'u1');
    expect(match.shots, '[]');
    expect(match.isDeleted, isFalse);
    final cue = (await db.select(db.cueEquipmentRows).get()).single;
    expect(cue.id, 'cue-v7');
    expect(cue.name, 'Cơ cũ');
    expect(cue.updatedAt, isNull);
    expect(cue.syncedAt, isNull);
    expect(cue.isDeleted, isFalse);
    final cueColumns = await db
        .customSelect('PRAGMA table_info(cue_equipment_rows)')
        .get();
    expect(
      cueColumns.map((row) => row.read<String>('name')),
      containsAll(['updated_at', 'synced_at', 'is_deleted']),
    );
  });

  test('nâng từ v8 lên v10 thêm metadata sync cho Equipment', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE cue_equipment_rows ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'user_id TEXT NOT NULL, '
          'name TEXT NOT NULL, '
          'type TEXT NOT NULL, '
          'weight_grams INTEGER NULL, '
          'tip_diameter_mm REAL NULL, '
          'tip_hardness TEXT NULL, '
          'skill_categories TEXT NOT NULL, '
          'last_tip_maintenance INTEGER NULL, '
          'tip_maintenance_due_date INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO cue_equipment_rows VALUES "
          "('cue-v8', 'u1', 'Cơ cũ', 'playing', 540, NULL, NULL, "
          "'[\"aiming\"]', NULL, NULL);",
        );
        _createOwnedDrillLogTable(raw);
        _createOwnedPracticeTables(raw);
        raw.execute(
          'CREATE TABLE pool_match_rows ('
          'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
          'game_type TEXT NOT NULL, player_name TEXT NOT NULL, '
          'opponent_name TEXT NOT NULL, target_racks INTEGER NOT NULL, '
          'rack_winners TEXT NOT NULL, '
          "shots TEXT NOT NULL DEFAULT '[]', "
          'started_at INTEGER NOT NULL, completed_at INTEGER NULL);',
        );
        _createV13PlayerGoalTable(raw);
        raw.execute('PRAGMA user_version = 8;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final cue = (await db.select(db.cueEquipmentRows).getSingle());
    expect(cue.id, 'cue-v8');
    expect(cue.updatedAt, isNull);
    expect(cue.syncedAt, isNull);
    expect(cue.isDeleted, isFalse);
  });

  test('nâng từ v9 lên v10 thêm trường cơ, cueId và metadata sync', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE schedule_slot_rows (id TEXT NOT NULL PRIMARY KEY, '
          "user_id TEXT NOT NULL DEFAULT '', day INTEGER NOT NULL, "
          'time TEXT NOT NULL, label TEXT NOT NULL, cat TEXT NULL);',
        );
        raw.execute(
          "INSERT INTO schedule_slot_rows VALUES ('s9', 'u1', 2, '19:00', 'Tập', NULL);",
        );
        raw.execute(
          'CREATE TABLE timer_session_rows (id TEXT NOT NULL PRIMARY KEY, '
          "user_id TEXT NOT NULL DEFAULT '', date INTEGER NOT NULL, "
          'duration_sec INTEGER NOT NULL, cat TEXT NULL, cue_id TEXT NULL);',
        );
        raw.execute(
          "INSERT INTO timer_session_rows VALUES ('t9', 'u1', 1760400000, 900, NULL, NULL);",
        );
        _createOwnedDrillLogTable(raw);
        raw.execute(
          'CREATE TABLE cue_equipment_rows ('
          'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
          'name TEXT NOT NULL, type TEXT NOT NULL, weight_grams INTEGER NULL, '
          'tip_diameter_mm REAL NULL, tip_hardness TEXT NULL, '
          'skill_categories TEXT NOT NULL, last_tip_maintenance INTEGER NULL, '
          'tip_maintenance_due_date INTEGER NULL, updated_at INTEGER NULL, '
          'synced_at INTEGER NULL, is_deleted INTEGER NOT NULL DEFAULT 0);',
        );
        raw.execute(
          "INSERT INTO cue_equipment_rows VALUES ('c9', 'u1', 'Cơ cũ', "
          "'playing', NULL, 12.4, 'hard', '[]', NULL, NULL, NULL, NULL, 0);",
        );
        raw.execute(
          'CREATE TABLE pool_match_rows ('
          'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
          'game_type TEXT NOT NULL, player_name TEXT NOT NULL, '
          'opponent_name TEXT NOT NULL, target_racks INTEGER NOT NULL, '
          'rack_winners TEXT NOT NULL, '
          "shots TEXT NOT NULL DEFAULT '[]', "
          'started_at INTEGER NOT NULL, completed_at INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO pool_match_rows VALUES ('m9', 'u1', 'nineBall', 'An', "
          "'Bình', 5, '[]', '[]', 1760400000, NULL);",
        );
        _createV13PlayerGoalTable(raw);
        raw.execute('PRAGMA user_version = 9;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final cue = (await db.select(db.cueEquipmentRows).getSingle());
    expect(cue.shaftDiameterMm, 12.4);
    expect(cue.shaftBrand, isNull);
    expect(cue.tipBrand, isNull);
    expect(cue.buttBrand, isNull);
    final match = (await db.select(db.poolMatchRows).getSingle());
    expect(match.cueId, isNull);
    expect(match.isDeleted, isFalse);
    expect(match.updatedAt, isNull);
    expect(match.syncedAt, isNull);
    final timer = (await db.select(db.timerSessionRows).getSingle());
    expect(timer.syncedAt, isNull);
    final slot = (await db.select(db.scheduleSlotRows).getSingle());
    expect(slot.updatedAt, isNull);
    expect(slot.syncedAt, isNull);
    expect(slot.isDeleted, isFalse);
  });

  test('nâng từ v10 lên v11 chỉ thêm bảng lần làm Coach, giữ nguyên dữ liệu cũ', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
          'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
          'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
          'synced_at INTEGER NULL);',
        );
        raw.execute(
          "INSERT INTO drill_log_rows VALUES ('v10', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
        );
        _createV12PoolMatchTable(raw);
        _createV13PlayerGoalTable(raw);
        raw.execute('PRAGMA user_version = 10;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    expect((await db.select(db.drillLogRows).get()).single.id, 'v10');
    expect((await db.select(db.poolMatchRows).get()).single.isDeleted, isFalse);
    expect(await db.select(db.coachAttemptRows).get(), isEmpty);
    final at = DateTime(2026, 10, 21, 9);
    await db
        .into(db.coachAttemptRows)
        .insert(
          CoachAttemptRowsCompanion.insert(
            id: 'c1',
            userId: 'u1',
            situationKey: 'lib:pos-rail-1',
            topic: 'position',
            difficulty: 'easy',
            answers: '[]',
            outcome: 'solved1',
            scoringVersion: 1,
            startedAt: at,
            finishedAt: at,
          ),
        );
    final row = (await db.select(db.coachAttemptRows).get()).single;
    expect(row.situationKey, 'lib:pos-rail-1');
    expect(row.firstFault, isNull);
    expect(row.syncedAt, isNull);
  });

  test(
    'nâng từ v11 lên v13 giữ dữ liệu và thêm chat Coach cùng thời lượng Drill',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, drill_id TEXT NOT NULL, date INTEGER NOT NULL, '
            'score REAL NOT NULL, attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, synced_at INTEGER NULL);',
          );
          raw.execute(
            "INSERT INTO drill_log_rows VALUES ('v11', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
          );
          _createV12PoolMatchTable(raw);
          _createV13PlayerGoalTable(raw);
          raw.execute('PRAGMA user_version = 11;');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);
      expect(db.schemaVersion, 14);
      final legacyLog = (await db.select(db.drillLogRows).get()).single;
      expect(legacyLog.id, 'v11');
      expect(legacyLog.durationSec, isNull);
      expect(await db.select(db.coachChatTurnRows).get(), isEmpty);
      await db
          .into(db.coachChatTurnRows)
          .insert(
            CoachChatTurnRowsCompanion.insert(
              userId: 'u1',
              createdAt: DateTime(2026, 10, 22, 9),
              fromPlayer: true,
              message: 'Hôm nay tôi nên tập gì?',
            ),
          );
      final row = (await db.select(db.coachChatTurnRows).get()).single;
      expect([row.id, row.insufficient], [1, false]);
    },
  );

  test('nâng từ v13 lên v14 thêm hạng đích, giữ nguyên mục tiêu đang có', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        _createV13PlayerGoalTable(raw);
        raw.execute(
          "INSERT INTO player_goal_rows VALUES "
          "('u1', 'g1', 'lenHang', NULL, NULL, 1760400000, 1760400000, NULL);",
        );
        raw.execute('PRAGMA user_version = 13;');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 14);
    final row = (await db.select(db.playerGoalRows).get()).single;
    expect([row.kind, row.targetRank], ['lenHang', null]);
  });

  test('tạo mới ở v14 ghi và đọc được hạng đích', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.playerGoalRows).insert(
          PlayerGoalRowsCompanion.insert(
            userId: 'u1',
            updatedAt: DateTime(2026, 10, 28),
            kind: const Value('lenHang'),
            targetRank: const Value('d'),
          ),
        );
    final row = (await db.select(db.playerGoalRows).get()).single;
    expect(row.targetRank, 'd');
  });
}

void _createPracticeTables(dynamic raw) {
  raw.execute(
    'CREATE TABLE schedule_slot_rows (id TEXT NOT NULL PRIMARY KEY, '
    'day INTEGER NOT NULL, time TEXT NOT NULL, label TEXT NOT NULL, '
    'cat TEXT NULL);',
  );
  raw.execute(
    'CREATE TABLE timer_session_rows (id TEXT NOT NULL PRIMARY KEY, '
    'date INTEGER NOT NULL, duration_sec INTEGER NOT NULL, '
    'cat TEXT NULL, cue_id TEXT NULL);',
  );
}

/// Bảng luyện tập từ v5 trở đi: đã có cột chủ.
void _createOwnedPracticeTables(dynamic raw) {
  raw.execute(
    'CREATE TABLE schedule_slot_rows (id TEXT NOT NULL PRIMARY KEY, '
    "user_id TEXT NOT NULL DEFAULT '', day INTEGER NOT NULL, "
    'time TEXT NOT NULL, label TEXT NOT NULL, cat TEXT NULL);',
  );
  raw.execute(
    'CREATE TABLE timer_session_rows (id TEXT NOT NULL PRIMARY KEY, '
    "user_id TEXT NOT NULL DEFAULT '', date INTEGER NOT NULL, "
    'duration_sec INTEGER NOT NULL, cat TEXT NULL, cue_id TEXT NULL);',
  );
}

void _createOwnedDrillLogTable(dynamic raw) {
  raw.execute(
    'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
    'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
    'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
    'synced_at INTEGER NULL);',
  );
}

/// Bảng trận đấu đúng hình dạng v12 (trước cột xóa mềm), kèm một trận cũ.
void _createV12PoolMatchTable(dynamic raw) {
  raw.execute(
    'CREATE TABLE pool_match_rows ('
    'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
    'game_type TEXT NOT NULL, player_name TEXT NOT NULL, '
    'opponent_name TEXT NOT NULL, target_racks INTEGER NOT NULL, '
    'rack_winners TEXT NOT NULL, '
    "shots TEXT NOT NULL DEFAULT '[]', "
    'started_at INTEGER NOT NULL, completed_at INTEGER NULL, '
    'cue_id TEXT NULL, updated_at INTEGER NULL, synced_at INTEGER NULL);',
  );
  raw.execute(
    "INSERT INTO pool_match_rows VALUES ('m12', 'u1', 'nineBall', 'An', "
    "'Bình', 5, '[]', '[]', 1760400000, NULL, NULL, NULL, NULL);",
  );
}

/// Bảng mục tiêu đúng hình dạng v13 (có từ v4, trước cột hạng đích).
void _createV13PlayerGoalTable(dynamic raw) {
  raw.execute(
    'CREATE TABLE player_goal_rows (user_id TEXT NOT NULL PRIMARY KEY, '
    'goal_id TEXT NULL, kind TEXT NULL, category TEXT NULL, '
    'event_date INTEGER NULL, created_at INTEGER NULL, '
    'updated_at INTEGER NOT NULL, synced_at INTEGER NULL);',
  );
}
