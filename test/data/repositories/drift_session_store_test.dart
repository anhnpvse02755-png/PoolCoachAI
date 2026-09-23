import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_session_store.dart';

void main() {
  late AppDatabase db;
  late DriftSessionStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSessionStore(db);
  });
  tearDown(() => db.close());

  test('chưa lưu gì thì đọc ra null', () async {
    expect(await store.read(), isNull);
  });

  test('ghi hai lần thì chỉ còn một phiên, là phiên sau', () async {
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1'));
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2'));

    expect((await store.read())?.refreshToken, 'r2');
    expect(await db.select(db.authSessionRows).get(), hasLength(1));
  });

  test('xoá phiên không động tới buổi tập', () async {
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1'));
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'x', userId: 'u1', drillId: 'd1', date: DateTime(2026, 9, 23), score: 7));

    await store.clear();

    expect(await store.read(), isNull);
    expect(await db.select(db.drillLogRows).get(), hasLength(1));
  });
}
