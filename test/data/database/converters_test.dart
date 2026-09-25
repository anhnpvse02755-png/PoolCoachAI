import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Vòng chuyển đổi miền → SQLite → miền.
///
/// Mục 4.2 của thiết kế liệt kê ba chỗ mất mát khi đi vòng qua SQLite.
/// Test ở đây chốt đúng ba chỗ đó lại: biết trước thì không ai ngồi
/// truy vì sao `Drill == Drill` lại sai giữa lúc gỡ lỗi.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Drill> roundTripDrill(Drill drill) async {
    await db.into(db.drillRows).insertOnConflictUpdate(toDrillRow(drill));
    final row = await (db.select(db.drillRows)
          ..where((t) => t.id.equals(drill.id)))
        .getSingle();
    return toDrill(row);
  }

  Future<DrillLog> roundTripLog(DrillLog log) async {
    await db.into(db.drillLogRows).insert(toDrillLogRow(log, userId: 'u1'));
    final row = await (db.select(db.drillLogRows)
          ..where((t) => t.id.equals(log.id)))
        .getSingle();
    return toDrillLog(row);
  }

  group('vòng chuyển đổi Drill', () {
    test('giữ nguyên mọi trường của bài chấm theo tỉ lệ', () async {
      final back = await roundTripDrill(
        const Drill(
          id: 'd1',
          cat: SkillCategory.bank,
          name: 'Cân bi một băng',
          level: 3,
          unit: 'lần trúng / 10',
          goal: 'Đưa bi mục tiêu chạm băng rồi vào lỗ.',
          steps: ['Bước một', 'Bước hai'],
          passThreshold: 0.6,
        ),
      );

      expect(back.id, 'd1');
      expect(back.cat, SkillCategory.bank);
      expect(back.name, 'Cân bi một băng');
      expect(back.level, 3);
      expect(back.unit, 'lần trúng / 10');
      expect(back.goal, 'Đưa bi mục tiêu chạm băng rồi vào lỗ.');
      expect(back.steps, ['Bước một', 'Bước hai']);
      expect(back.passThreshold, 0.6);
      expect(back.target, isNull);
    });

    test('target kiểu num quay về thành double — chỗ mất mát đã biết',
        () async {
      final back = await roundTripDrill(
        const Drill(
          id: 'd2',
          cat: SkillCategory.position,
          name: 'Kéo bi cái',
          level: 2,
          unit: 'cm',
          goal: 'Kéo bi cái về đúng cự ly.',
          steps: ['Bước một'],
          target: 25,
        ),
      );

      expect(back.target, 25);
      expect(back.target, isA<double>(),
          reason: 'cột real đọc lên luôn là double, dù seed ghi số nguyên');
    });

    test('danh sách bước rỗng quay về rỗng, không phải null', () async {
      final back = await roundTripDrill(
        const Drill(
          id: 'd3',
          cat: SkillCategory.aiming,
          name: 'Bài không có bước',
          level: 1,
          unit: 'lần trúng / 10',
          goal: 'Mục tiêu.',
          steps: [],
          passThreshold: 0.8,
        ),
      );

      expect(back.steps, isEmpty);
    });
  });

  // Một hàng hỏng phải ồn ào ngay lúc đọc. Đọc êm rồi dựng màn hình
  // thiếu nội dung là màn hình nói dối mà không test nào biết.
  group('hàng hỏng trong bảng', () {
    Future<DrillRow> insertRaw(DrillRowsCompanion row) async {
      await db.into(db.drillRows).insert(row);
      return (db.select(db.drillRows)..where((t) => t.id.equals(row.id.value)))
          .getSingle();
    }

    test('có cả passThreshold lẫn target thì ném ngay lúc đọc', () async {
      final row = await insertRaw(
        DrillRowsCompanion.insert(
          id: 'hong',
          cat: SkillCategory.aiming.name,
          name: 'Hàng hỏng',
          level: 1,
          unit: 'cm',
          goal: 'Mục tiêu.',
          steps: '[]',
          passThreshold: const Value(0.8),
          target: const Value(25),
        ),
      );

      expect(() => toDrill(row), throwsA(isA<AssertionError>()));
    });

    test('không có cách chấm điểm nào thì cũng ném ngay lúc đọc', () async {
      final row = await insertRaw(
        DrillRowsCompanion.insert(
          id: 'khong-cham-duoc',
          cat: SkillCategory.aiming.name,
          name: 'Không chấm được',
          level: 1,
          unit: 'cm',
          goal: 'Mục tiêu.',
          steps: '[]',
        ),
      );

      expect(() => toDrill(row), throwsA(isA<AssertionError>()));
    });

    test('tên nhóm kỹ năng lạ thì ném, không im lặng chọn bừa một nhóm',
        () async {
      final row = await insertRaw(
        DrillRowsCompanion.insert(
          id: 'nhom-la',
          cat: 'khong-phai-nhom-nao',
          name: 'Nhóm lạ',
          level: 1,
          unit: 'cm',
          goal: 'Mục tiêu.',
          steps: '[]',
          target: const Value(10),
        ),
      );

      expect(() => toDrill(row), throwsA(isA<FormatException>()));
    });

    test('steps hỏng JSON thì ném, không âm thầm thành danh sách rỗng',
        () async {
      final row = await insertRaw(
        DrillRowsCompanion.insert(
          id: 'json-hong',
          cat: SkillCategory.aiming.name,
          name: 'JSON hỏng',
          level: 1,
          unit: 'cm',
          goal: 'Mục tiêu.',
          steps: '{khong phai json}',
          target: const Value(10),
        ),
      );

      expect(() => toDrill(row), throwsA(isA<FormatException>()));
    });
  });

  group('vòng chuyển đổi DrillLog', () {
    test('score kiểu num quay về thành double — chỗ mất mát đã biết',
        () async {
      final back = await roundTripLog(
        DrillLog(
          id: 'l1',
          drillId: 'd1',
          date: DateTime(2026, 9, 20),
          score: 8,
          attempts: 10,
        ),
      );

      expect(back.score, 8);
      expect(back.score, isA<double>());
    });

    test('attempts và notes vắng mặt vẫn vắng mặt sau vòng đi về', () async {
      final back = await roundTripLog(
        DrillLog(
          id: 'l2',
          drillId: 'd2',
          date: DateTime(2026, 9, 20),
          score: 22,
        ),
      );

      expect(back.attempts, isNull);
      expect(back.notes, isNull);
    });

    test('ngày giữ nguyên tới từng phút', () async {
      final back = await roundTripLog(
        DrillLog(
          id: 'l3',
          drillId: 'd1',
          date: DateTime(2026, 9, 20, 14, 30),
          score: 5,
          attempts: 10,
          notes: 'Hơi lệch phải',
        ),
      );

      expect(back.date, DateTime(2026, 9, 20, 14, 30));
      expect(back.notes, 'Hơi lệch phải');
    });
  });

  test('buổi tập đi lên server rồi về máy vẫn nguyên, kể cả chữ tiếng Việt',
      () async {
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'x',
          userId: 'u1',
          drillId: 'd1',
          date: DateTime(2026, 9, 23, 10, 30),
          score: 7,
          attempts: const Value(10),
          notes: const Value('Cú đánh hơi lệch phải'),
        ));
    final original = (await db.select(db.drillLogRows).get()).single;

    final json = toRemoteDrillLog(original);
    expect(json.containsKey('user_created'), isFalse);

    await db.delete(db.drillLogRows).go();
    await db.into(db.drillLogRows).insert(
          fromRemoteDrillLog(json, userId: 'u1', syncedAt: DateTime(2026, 9, 23, 11)),
        );
    final back = (await db.select(db.drillLogRows).get()).single;

    expect(back.date, original.date);
    expect(back.score, 7);
    expect(back.attempts, 10);
    expect(back.notes, 'Cú đánh hơi lệch phải');
    expect(back.syncedAt, isNotNull);
  });

  group('vòng chuyển đổi KnowledgeArticle', () {
    Future<KnowledgeArticle> roundTrip(KnowledgeArticle article) async {
      await db
          .into(db.knowledgeRows)
          .insertOnConflictUpdate(toKnowledgeRow(article));
      final row = await (db.select(db.knowledgeRows)
            ..where((t) => t.id.equals(article.id)))
          .getSingle();
      return toKnowledge(row);
    }

    test('giữ nguyên mọi trường, kể cả danh sách bài tập liên quan',
        () async {
      final back = await roundTrip(
        const KnowledgeArticle(
          id: 'k1',
          cat: SkillCategory.kick,
          title: 'A băng cơ bản',
          body: 'Bi cái chạm băng trước rồi mới tới bi mục tiêu.',
          relatedDrillIds: ['d1', 'd2'],
        ),
      );

      expect(back.id, 'k1');
      expect(back.cat, SkillCategory.kick);
      expect(back.title, 'A băng cơ bản');
      expect(back.body, 'Bi cái chạm băng trước rồi mới tới bi mục tiêu.');
      expect(back.relatedDrillIds, ['d1', 'd2']);
    });

    test('không có bài tập liên quan thì quay về rỗng, không phải null',
        () async {
      final back = await roundTrip(
        const KnowledgeArticle(
          id: 'k2',
          cat: SkillCategory.safety,
          title: 'Phòng thủ',
          body: 'Thân bài.',
        ),
      );

      expect(back.relatedDrillIds, isEmpty);
    });
  });
}
