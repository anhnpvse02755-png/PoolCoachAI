import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/domain/drill_log.dart';

/// Repository chạy trên SQLite thật trong bộ nhớ.
///
/// Thứ tự cũ nhất trước là **một phần của hợp đồng**, không phải chi
/// tiết cài đặt: categoryMastery() cho buổi mới trọng số cao hơn buổi
/// cũ, nên đảo thứ tự là điểm mastery sai mà không ai thấy gì lạ.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  DrillLog logAt(String id, DateTime date) =>
      DrillLog(id: id, drillId: 'd1', date: date, score: 7, attempts: 10);

  group('DriftDrillLogRepository', () {
    test('watchAll trả log cũ nhất trước, bất kể thứ tự ghi vào', () async {
      final repo = DriftDrillLogRepository(db);

      await repo.add(logAt('giua', DateTime(2026, 9, 20)));
      await repo.add(logAt('moi-nhat', DateTime(2026, 9, 22)));
      await repo.add(logAt('cu-nhat', DateTime(2026, 9, 18)));

      final logs = await repo.watchAll().first;

      expect(logs.map((l) => l.id).toList(), ['cu-nhat', 'giua', 'moi-nhat']);
    });

    test('ghi thêm một log thì stream bắn lại ngay, không cần gọi lại', () async {
      final repo = DriftDrillLogRepository(db);
      final emissions = <List<DrillLog>>[];
      final sub = repo.watchAll().listen(emissions.add);
      addTearDown(sub.cancel);

      // Lần bắn đầu: bảng còn rỗng.
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await repo.add(logAt('l1', DateTime(2026, 9, 20)));
      await pumpEventQueue();

      expect(emissions.last.length, 1);
      expect(emissions.last.single.id, 'l1');
    });

    test('log ghi xuống rồi đọc lên vẫn còn nguyên sau khi đóng truy vấn',
        () async {
      final repo = DriftDrillLogRepository(db);
      await repo.add(
        DrillLog(
          id: 'l1',
          drillId: 'd3',
          date: DateTime(2026, 9, 21, 9, 15),
          score: 22,
          notes: 'Ghi chú',
        ),
      );

      final log = (await repo.watchAll().first).single;

      expect(log.drillId, 'd3');
      expect(log.date, DateTime(2026, 9, 21, 9, 15));
      expect(log.score, 22);
      expect(log.attempts, isNull);
      expect(log.notes, 'Ghi chú');
    });
  });

  group('DriftDrillRepository và DriftKnowledgeRepository', () {
    test('trả về đúng bộ seed sau khi nạp', () async {
      await upsertSeed(db);

      final drills = await DriftDrillRepository(db).watchAll().first;
      final articles = await DriftKnowledgeRepository(db).watchAll().first;

      expect(drills.length, 10);
      expect(articles.length, 6);
      expect(drills.every((d) => d.steps.isNotEmpty), isTrue);
    });

    test('bảng rỗng thì trả danh sách rỗng, không ném', () async {
      final drills = await DriftDrillRepository(db).watchAll().first;

      expect(drills, isEmpty);
    });
  });
}
