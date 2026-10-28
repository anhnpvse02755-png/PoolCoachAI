import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/data/repositories/skill_test_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  late AppDatabase db;
  late SkillTestRepository repo;
  var n = 0;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    n = 0;
    repo = SkillTestRepository(
      db,
      userId: 'u1',
      now: () => stToday,
      newId: () => 'st${++n}',
    );
  });
  tearDown(() => db.close());

  Future<SkillTestOutcome> submit(
    String id,
    num score, {
    int? attempts = 10,
    List<DrillLog>? logs,
  }) => repo.completeTest(
    drill: stById(id),
    drills: stDrills,
    logs: logs ?? threePasses(id),
    tableSize: TableSize.eightFoot,
    startedAt: stToday.subtract(const Duration(minutes: 20)),
    score: score,
    attempts: attempts,
    notes: 'bàn hơi nhanh',
  );

  test('đạt: ghi một dòng đủ cột cho mọi nơi đọc', () async {
    expect(
      await submit('a1', 9),
      isA<SkillTestRecorded>().having((o) => o.test.passed, 'passed', true),
    );
    final r = await db.select(db.skillTestRows).getSingle();
    expect(
      [
        r.id, r.userId, r.drillId, r.drillLevel, r.tableSize, r.startedAt,
        r.completedAt, r.cancelledAt, r.score, r.attempts, r.passed, r.notes,
        r.syncedAt, r.passThreshold, r.target,
      ],
      [
        'st1', 'u1', 'a1', 1, 'eightFoot',
        stToday.subtract(const Duration(minutes: 20)), stToday, null, 9.0, 10,
        true, 'bàn hơi nhanh', null, 0.8, null,
      ],
    );
  });

  test('trượt: passed false, vẫn có điểm và ảnh chụp tiêu chí', () async {
    await submit('a1', 7);
    final r = await db.select(db.skillTestRows).getSingle();
    expect(
      [r.score, r.passed, r.completedAt, r.passThreshold],
      [7.0, false, stToday, 0.8],
    );
  });

  test('bài mục tiêu: ảnh chụp là target, đúng một trong hai cột tiêu chí', () async {
    final logs = [
      for (final d in [3, 2, 1])
        stLog('t2', 30, stToday.subtract(Duration(days: d)), attempts: null),
    ];
    expect(
      await submit('t2', 25, attempts: null, logs: logs),
      isA<SkillTestRecorded>().having((o) => o.test.passed, 'passed', true),
    );
    final r = await db.select(db.skillTestRows).getSingle();
    expect(
      [r.passThreshold, r.target, r.attempts, r.score, r.passed],
      [null, 25.0, null, 25.0, true],
    );
  });

  test('passed ghi ra luôn khớp skillTestVerdict của chính dòng, với mọi điểm 0..10', () async {
    // Mỗi điểm một người chơi riêng trên cùng cơ sở dữ liệu, để cổng luôn mở.
    for (var score = 0; score <= 10; score++) {
      final r = SkillTestRepository(
        db,
        userId: 'p$score',
        now: () => stToday,
        newId: () => 'x$score',
      );
      await r.completeTest(
        drill: stById('a1'),
        drills: stDrills,
        logs: threePasses('a1'),
        tableSize: TableSize.sevenFoot,
        startedAt: stToday,
        score: score,
        attempts: 10,
      );
      final row = await (db.select(db.skillTestRows)
            ..where((t) => t.userId.equals('p$score')))
          .getSingle();
      expect(row.passed, skillTestVerdict(toSkillTest(row)!), reason: 'score $score');
      expect(row.passed, score >= 8, reason: 'score $score');
    }
  });

  test('cổng chưa mở: không ghi gì, trả lý do', () async {
    expect(
      await submit('a3', 9),
      isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<NeedLowerLevel>()),
    );
    expect(await db.select(db.skillTestRows).get(), isEmpty);
  });

  test('nộp hai lần liền sau khi đạt: lần hai bị chặn vì đã chứng nhận, chỉ một dòng', () async {
    await submit('a1', 9);
    expect(
      await submit('a1', 9),
      isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<AlreadyCertified>()),
    );
    expect(await db.select(db.skillTestRows).get(), hasLength(1));
  });

  test('nộp đồng thời hai lần: chỉ một dòng được ghi', () async {
    final results = await Future.wait([submit('a1', 9), submit('a1', 9)]);
    expect(results.whereType<SkillTestRecorded>(), hasLength(1));
    expect(results.whereType<SkillTestLocked>(), hasLength(1));
    expect(await db.select(db.skillTestRows).get(), hasLength(1));
  });

  test('trượt rồi nộp ngay lần nữa: bị chặn vì chưa tập thêm', () async {
    await submit('a1', 7);
    expect(
      await submit('a1', 9),
      isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<NeedPracticeAfterFail>()),
    );
    expect(await db.select(db.skillTestRows).get(), hasLength(1));
  });

  test('kết quả không hợp lệ thì ném, không ghi', () async {
    await expectLater(submit('a1', 11), throwsArgumentError);
    await expectLater(submit('a1', double.nan), throwsArgumentError);
    await expectLater(submit('a1', 8.5), throwsArgumentError);
    // attempts trên bài mục tiêu
    await expectLater(submit('t2', 25, logs: const []), throwsArgumentError);
    expect(await db.select(db.skillTestRows).get(), isEmpty);
  });

  test('huỷ: dòng huỷ không có kết quả', () async {
    await repo.cancelTest(
      drill: stById('a1'),
      tableSize: TableSize.sevenFoot,
      startedAt: stToday.subtract(const Duration(minutes: 5)),
    );
    final r = await db.select(db.skillTestRows).getSingle();
    expect(
      [
        r.cancelledAt, r.completedAt, r.score, r.attempts, r.passed,
        r.passThreshold, r.target, r.drillLevel, r.tableSize,
      ],
      [stToday, null, null, null, null, null, null, 1, 'sevenFoot'],
    );
  });

  test('chỉ thấy lần kiểm tra của chính mình, mới nhất trước', () async {
    await db.into(db.skillTestRows).insert(
      toSkillTestRow(passedTest('a1', 1, stToday, id: 'old'), userId: 'u1'),
    );
    await db.into(db.skillTestRows).insert(
      toSkillTestRow(
        passedTest('p2a', 2, stToday.add(const Duration(hours: 1)), id: 'new'),
        userId: 'u1',
      ),
    );
    await db.into(db.skillTestRows).insert(
      toSkillTestRow(passedTest('a1', 1, stToday, id: 'other'), userId: 'u2'),
    );
    expect((await repo.watchTests().first).map((t) => t.id), ['new', 'old']);
  });

  test('dòng có table_size lạ bị bỏ, dòng khác vẫn qua; completeTest không ném', () async {
    await db.into(db.skillTestRows).insert(
      toSkillTestRow(passedTest('a1', 1, stToday, id: 'ok'), userId: 'u1'),
    );
    await db.into(db.skillTestRows).insert(
      toSkillTestRow(
        passedTest('p2b', 2, stToday, id: 'odd'),
        userId: 'u1',
      ).copyWith(tableSize: 'zzz'),
    );
    expect((await repo.watchTests().first).map((t) => t.id), ['ok']);
    expect(await submit('p2a', 9), isA<SkillTestRecorded>());
  });
}
