import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';

/// Nâng từ v1 → v2 (spec mục 5.1): buổi tập cũ không có chủ nên bị bỏ,
/// và máy có chỗ lưu phiên đăng nhập.
void main() {
  test('nâng từ v1 lên v2 thì bỏ buổi tập cũ và có bảng phiên đăng nhập',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(
        'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
        'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
        'attempts INTEGER NULL, notes TEXT NULL);',
      );
      raw.execute(
        "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1758600000, 7.0, 10, NULL);",
      );
      raw.execute('PRAGMA user_version = 1;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(await db.select(db.authSessionRows).get(), isEmpty);

    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'moi',
          userId: 'u1',
          drillId: 'd1',
          date: DateTime(2026, 9, 23),
          score: 7,
        ));
    final row = (await db.select(db.drillLogRows).get()).single;
    expect(row.userId, 'u1');
    expect(row.syncedAt, isNull);
  });

  test('nâng từ v2 lên v3 thì có ba bảng hạng/kiểm tra và giữ nguyên buổi tập',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(
        'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
        'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
        'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
        'synced_at INTEGER NULL);',
      );
      raw.execute(
        "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
      );
      raw.execute('PRAGMA user_version = 2;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 4);
    expect((await db.select(db.drillLogRows).get()).single.id, 'cu');

    final at = DateTime(2026, 10, 14, 9);
    await db.into(db.playerRankRows).insert(PlayerRankRowsCompanion.insert(
          userId: 'u1',
          onboardingState: 'skipped',
          updatedAt: at,
        ));
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 't1',
          userId: 'u1',
          startedAt: at,
          tableSize: 'nineFootPlus',
        ));
    await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
          id: 'r1',
          testId: 't1',
          drillId: 'F1',
          attempts: '{"shots":[true]}',
          recordedAt: at,
        ));

    final rank = (await db.select(db.playerRankRows).get()).single;
    expect(rank.rank, isNull);
    expect(rank.syncedAt, isNull);
    final result = (await db.select(db.buDrillResultRows).get()).single;
    expect(result.score, isNull, reason: 'điểm bài null tới khi bài xong (D8)');

    // Một bài chỉ có một dòng kết quả trong một lần kiểm tra.
    await expectLater(
      db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
            id: 'r2',
            testId: 't1',
            drillId: 'F1',
            attempts: '{"shots":[]}',
            recordedAt: at,
          )),
      throwsA(isA<Exception>()), // SqliteException: vi phạm khoá duy nhất
    );
  });

  test('nâng từ v3 lên v4 thì có bảng mục tiêu và thành tích, giữ nguyên buổi tập',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(
        'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
        'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
        'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
        'synced_at INTEGER NULL);',
      );
      raw.execute(
        "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
      );
      raw.execute('PRAGMA user_version = 3;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 4);
    expect((await db.select(db.drillLogRows).get()).single.id, 'cu');

    final at = DateTime(2026, 10, 15, 9);
    await db.into(db.playerGoalRows).insert(
        PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: at));
    await db.into(db.achievementRows).insert(AchievementRowsCompanion.insert(
        id: 'x', userId: 'u1', kind: 'chuoiNgay', refId: '7', achievedAt: at));
    expect((await db.select(db.playerGoalRows).get()).single.kind, isNull);
    expect((await db.select(db.achievementRows).get()).single.refId, '7');
  });
}
