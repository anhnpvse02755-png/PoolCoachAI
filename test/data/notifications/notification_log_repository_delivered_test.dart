import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

void main() {
  late AppDatabase db;
  late NotificationLogRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotificationLogRepository(db, userId: 'u1');
  });
  tearDown(() => db.close());

  final delivered = NotificationLogEntry(
    id: 501,
    kind: NotificationKind.streak,
    key: '2026-11-04',
    at: DateTime(2026, 11, 4, 20),
    title: 'Nhắc chuỗi',
    body: 'Hôm nay vẫn còn thời gian',
  );

  test(
    'ghi delivery mới một lần và không sửa trạng thái đã đọc khi kéo lặp',
    () async {
      await repository.recordDelivered([delivered]);
      await repository.markRead([
        delivered.id,
      ], at: DateTime(2026, 11, 4, 20, 5));
      await repository.recordDelivered([delivered, delivered]);

      final rows = await repository.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.single.id, delivered.id);
      expect(rows.single.readAt, DateTime(2026, 11, 4, 20, 5));
    },
  );

  test('delivery được ghi theo tài khoản của repository', () async {
    await repository.recordDelivered([delivered]);
    final other = NotificationLogRepository(db, userId: 'u2');
    expect(await other.watchAll().first, isEmpty);
  });
}
