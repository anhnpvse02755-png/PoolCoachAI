import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

void main() {
  final now = DateTime(2026, 10, 13, 9);
  late AppDatabase db;
  late NotificationLogRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotificationLogRepository(db, userId: 'u1');
  });
  tearDown(() => db.close());

  PlannedNotification planned(
    int id,
    DateTime at, {
    NotificationKind kind = NotificationKind.streak,
    String key = 'k',
  }) => PlannedNotification(
    id: id,
    kind: kind,
    key: key,
    at: at,
    validUntil: at.add(const Duration(hours: 4)),
    title: 'T$id',
    body: 'B$id',
  );

  Future<List<int>> ids() async =>
      (await repo.watchAll().first).map((e) => e.id).toList()..sort();

  test('ghi khi lập kế hoạch: thêm mục mới, giữ mục đã có', () async {
    final a = planned(1, DateTime(2026, 10, 14, 8));
    await repo.syncPlanned([a], now: now);
    await repo.markRead([1], at: now); // dấu đã đọc phải còn sau lần lập tiếp
    await repo.syncPlanned([
      a,
      planned(2, DateTime(2026, 10, 15, 8)),
    ], now: now);
    final all = await repo.watchAll().first;
    expect(all.map((e) => e.id).toList()..sort(), [1, 2]);
    expect(
      all.firstWhere((e) => e.id == 1).readAt,
      now,
      reason: 'mục đã có được giữ nguyên',
    );
    final e2 = all.firstWhere((e) => e.id == 2);
    expect([e2.title, e2.body, e2.kind], ['T2', 'B2', NotificationKind.streak]);
  });

  test('mục tương lai bị huỷ thì xoá; mục đã tới giờ được giữ', () async {
    await db
        .into(db.notificationLogRows)
        .insert(
          NotificationLogRowsCompanion.insert(
            userId: 'u1',
            id: 9,
            kind: 'streak',
            key: 'k',
            at: DateTime(2026, 10, 13, 8),
            title: 'cũ',
            body: 'cũ',
          ),
        );
    await repo.syncPlanned([
      planned(1, DateTime(2026, 10, 14, 8)),
      planned(2, DateTime(2026, 10, 15, 8)),
    ], now: now);
    await repo.syncPlanned([planned(2, DateTime(2026, 10, 15, 8))], now: now);
    expect(await ids(), [2, 9]);
  });

  test(
    'mục đã qua giờ mà bị huỷ khi còn chờ thì xoá; người khác không đụng',
    () async {
      final other = NotificationLogRepository(db, userId: 'u2');
      final past = DateTime(2026, 10, 13, 8);
      for (final r in [repo, other]) {
        await r.recordShown(planned(1, past), at: past);
        await r.recordShown(planned(2, past), at: past);
      }
      // Id 3 bị huỷ nhưng vẫn nằm trong kế hoạch (đặt lại): giữ.
      await repo.syncPlanned(
        [planned(3, DateTime(2026, 10, 14, 8))],
        now: now,
        cancelled: {1, 3},
      );
      expect(await ids(), [2, 3]);
      expect((await other.watchAll().first).map((e) => e.id).toList()..sort(), [
        1,
        2,
      ]);
    },
  );

  test('không đổi gì thì không ghi: luồng theo dõi không phát lại', () async {
    final plan = [planned(1, DateTime(2026, 10, 14, 8))];
    await repo.syncPlanned(plan, now: now);
    var emissions = 0;
    final sub = repo.watchAll().listen((_) => emissions++);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    final before = emissions;
    expect(before, greaterThan(0));
    await repo.syncPlanned(plan, now: now);
    await pumpEventQueue();
    expect(emissions, before);
  });

  test('đánh dấu đã đọc theo id và theo (loại, khoá): chỉ mục đã tới giờ của đúng người', () async {
    final other = NotificationLogRepository(db, userId: 'u2');
    final past = DateTime(2026, 10, 13, 8);
    final future = DateTime(2026, 10, 14, 8);
    for (final r in [repo, other]) {
      await r.recordShown(
        planned(1, past, kind: NotificationKind.recommendation, key: 'x'),
        at: past,
      );
      await r.recordShown(planned(2, past), at: past);
      await r.syncPlanned([
        planned(1, past, kind: NotificationKind.recommendation, key: 'x'),
        planned(2, past),
        planned(3, future, kind: NotificationKind.recommendation, key: 'x'),
      ], now: now);
    }
    await repo.markReadByKey(NotificationKind.recommendation, 'x', now: now);
    var mine = await repo.watchAll().first;
    expect({for (final e in mine) e.id: e.readAt}, {1: now, 2: null, 3: null});
    final theirs = await other.watchAll().first;
    expect(theirs.every((e) => e.readAt == null), isTrue);

    final later = now.add(const Duration(hours: 1));
    await repo.markRead([1, 2], at: later);
    mine = await repo.watchAll().first;
    expect({for (final e in mine) e.id: e.readAt}, {1: now, 2: later, 3: null});
    // Cùng id (id không chứa tài khoản) mà của người khác: không bị đụng.
    final theirsAfter = await other.watchAll().first;
    expect(
      {for (final e in theirsAfter) e.id: e.readAt},
      {1: null, 2: null, 3: null},
    );
  });

  test('mục cũ hơn 30 ngày bị dọn khi ghi', () async {
    final old = now.subtract(const Duration(days: 31));
    await repo.recordShown(planned(1, old), at: old);
    expect(await ids(), [1]);
    await repo.recordShown(planned(2, now), at: now);
    expect(await ids(), [2]);

    await repo.recordShown(
      planned(3, old),
      at: old.subtract(const Duration(days: 1)),
    );
    await repo.syncPlanned([], now: now);
    expect(await ids(), [2]);
  });

  test('dòng có loại lạ bị bỏ qua, dòng của người khác không thấy', () async {
    await db
        .into(db.notificationLogRows)
        .insert(
          NotificationLogRowsCompanion.insert(
            userId: 'u1',
            id: 1,
            kind: 'khongBiet',
            key: 'k',
            at: now,
            title: 't',
            body: 'b',
          ),
        );
    await db
        .into(db.notificationLogRows)
        .insert(
          NotificationLogRowsCompanion.insert(
            userId: 'u2',
            id: 2,
            kind: 'streak',
            key: 'k',
            at: now,
            title: 't',
            body: 'b',
          ),
        );
    await repo.recordShown(planned(3, now), at: now);
    expect(await ids(), [3]);
  });
}
