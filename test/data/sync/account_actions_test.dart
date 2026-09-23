import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_auth.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addLog(String id, String userId, {bool synced = false}) =>
      db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: id,
            userId: userId,
            drillId: 'd1',
            date: DateTime(2026, 9, 22),
            score: 7,
            syncedAt: Value(synced ? DateTime(2026, 9, 22) : null),
          ));

  test('chỉ đếm buổi chưa đồng bộ của đúng người', () async {
    await addLog('a', 'u1');
    await addLog('b', 'u1', synced: true);
    await addLog('c', 'u2');

    expect(await pendingLogCount(db, 'u1'), 1);
  });

  test('bấm Đăng xuất thì xoá buổi của người đó, giữ của người khác', () async {
    final auth = FakeAuthRepository.signedIn(userId: 'u1');
    await addLog('a', 'u1');
    await addLog('c', 'u2');

    await signOutAndForget(db: db, auth: auth, userId: 'u1');

    final left = await db.select(db.drillLogRows).get();
    expect(left.map((r) => r.id), ['c']);
    expect(auth.current, const SignedOut());
  });
}
