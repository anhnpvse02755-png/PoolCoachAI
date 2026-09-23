import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';

/// Nang cu v1 → v2 (spec muc 5.1): buoi tap cu khong co chu nen bi bo,
/// va may co cho luu phien dang nhap.
void main() {
  test('nang tu v1 len v2 thi bo buoi tap cu va co bang phien dang nhap',
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
