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
}
