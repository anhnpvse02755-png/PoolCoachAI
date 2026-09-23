import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Nạp seed vào DB — mục 4.3.1 của thiết kế.
///
/// Luật đang được bảo vệ ở đây: mã trong repo là nguồn sự thật cho dữ
/// liệu seed, DB chỉ là bản sao đọc được bằng truy vấn. Dự án đã hai
/// lần phải sửa dữ liệu seed sau khi phát hành (d8 từ a băng sang cân
/// bi, và thuật ngữ tiếng Việt). Nạp một lần lúc cài thì những máy cài
/// trước đợt sửa sẽ giữ bản sai vĩnh viễn mà không ai biết.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('nạp seed lần đầu', () {
    test('ra đủ 10 bài tập và 6 bài đọc', () async {
      await upsertSeed(db);

      final drills = await db.select(db.drillRows).get();
      final articles = await db.select(db.knowledgeRows).get();

      expect(drills.length, 10);
      expect(articles.length, 6);
    });

    test('mọi bài tập đọc lên lại đúng là bài trong seed', () async {
      await upsertSeed(db);

      final rows = await db.select(db.drillRows).get();
      final backById = {for (final row in rows) row.id: toDrill(row)};

      for (final drill in seedDrills) {
        final back = backById[drill.id];
        expect(back, isNotNull, reason: 'thiếu bài ${drill.id}');
        expect(back!.name, drill.name);
        expect(back.cat, drill.cat);
        expect(back.level, drill.level);
        expect(back.steps, drill.steps);
      }
    });

    test('mọi bài đọc lên lại đúng là bài kiến thức trong seed', () async {
      await upsertSeed(db);

      final rows = await db.select(db.knowledgeRows).get();
      final backById = {for (final row in rows) row.id: toKnowledge(row)};

      for (final article in seedKnowledge) {
        final back = backById[article.id];
        expect(back, isNotNull, reason: 'thiếu bài đọc ${article.id}');
        expect(back!.title, article.title);
        expect(back.cat, article.cat);
        expect(back.relatedDrillIds, article.relatedDrillIds);
      }
    });
  });

  group('nạp lại mỗi lần mở app', () {
    test('nạp hai lần không nhân đôi bản ghi nào', () async {
      await upsertSeed(db);
      await upsertSeed(db);

      expect((await db.select(db.drillRows).get()).length, 10);
      expect((await db.select(db.knowledgeRows).get()).length, 6);
    });

    test('bản ghi cũ trên máy đã cài bị bản trong mã ghi đè', () async {
      // Dựng lại đúng tình huống đã xảy ra thật: máy cài trước đợt sửa
      // đang giữ d8 ở nhóm A băng, trong khi mã đã chuyển sang Cân bi.
      await db.into(db.drillRows).insert(
            DrillRowsCompanion.insert(
              id: 'd8',
              cat: SkillCategory.kick.name,
              name: 'Tên cũ đã sai',
              level: 1,
              unit: 'đơn vị cũ',
              goal: 'Mục tiêu cũ.',
              steps: '["bước cũ"]',
              passThreshold: const Value(0.1),
            ),
          );

      await upsertSeed(db);

      final row = await (db.select(db.drillRows)
            ..where((t) => t.id.equals('d8')))
          .getSingle();
      final back = toDrill(row);
      final fromSeed = seedDrills.firstWhere((d) => d.id == 'd8');

      expect(back.cat, fromSeed.cat);
      expect(back.name, fromSeed.name);
      expect(back.level, fromSeed.level);
      expect(back.unit, fromSeed.unit);
    });

    test('nạp seed không đụng tới log người chơi đã ghi', () async {
      await db.into(db.drillLogRows).insert(
            toDrillLogRow(
              DrillLog(
                id: 'log-cua-nguoi-choi',
                drillId: 'd1',
                date: DateTime(2026, 9, 20),
                score: 7,
                attempts: 10,
                notes: 'Ghi chú của người chơi',
              ),
            ),
          );

      await upsertSeed(db);

      final logs = await db.select(db.drillLogRows).get();
      expect(logs.length, 1);
      expect(toDrillLog(logs.single).notes, 'Ghi chú của người chơi');
    });
  });
}
