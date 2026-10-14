import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/assessment_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  var ids = 0;

  AssessmentRepository repo({String userId = 'u1'}) => AssessmentRepository(db,
      userId: userId, now: () => clock, newId: () => 'id${++ids}');

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = DateTime(2026, 10, 14, 9);
    ids = 0;
  });
  tearDown(() => db.close());

  final answers = QuestionnaireAnswers([2, 1, 3, 2, 1, 0, 1, 1]);

  Future<String> startedTest(AssessmentRepository r, {TableSize size = TableSize.nineFootPlus}) async =>
      (await r.startTest(size) as TestStarted).testId;

  Future<void> record(AssessmentRepository r, String testId, Map<String, DrillAttempts> all) async {
    for (final e in all.entries) {
      await r.recordAttempts(testId, e.key, e.value);
    }
  }

  /// Đề I 60 → Masters (bàn 9 feet), Đề II trọn 77 → 137 → D.
  Future<String> completedTest(AssessmentRepository r) async {
    final id = await startedTest(r);
    await record(r, id, examIAttempts(wagonAndTargetMade: false));
    await r.finishExamI(id);
    await record(r, id, examIIPerfect(ExamIIVersion.masters));
    final out = await r.completeTest(id);
    expect(out, isA<TestCompleted>());
    return id;
  }

  group('hạng', () {
    test('chưa có gì thì không có dòng hạng', () async {
      expect(await repo().watchRank().first, isNull);
    });

    test('bộ câu hỏi ghi hạng ước lượng, chưa đồng bộ', () async {
      await repo().saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final r = await repo().watchRank().first;
      expect(r!.rank, Rank.h);
      expect(r.source, RankSource.estimated);
      final row = await db.select(db.playerRankRows).getSingle();
      expect(row.syncedAt, isNull);
    });

    test('Để sau ghi trạng thái bỏ qua; bấm lần nữa khi đã có hạng thì không đổi', () async {
      final r = repo();
      await r.skipOnboarding();
      expect((await r.watchRank().first)!.onboardingState, OnboardingState.skipped);
      await r.saveQuestionnaire(chosen: Rank.g, suggested: Rank.g, answers: answers);
      clock = clock.add(const Duration(days: 1));
      await r.skipOnboarding();
      final after = await r.watchRank().first;
      expect(after!.rank, Rank.g);
      expect(after.updatedAt, DateTime(2026, 10, 14, 9));
    });

    test('ghi lại hạng thì xoá dấu đã đồng bộ', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      await (db.update(db.playerRankRows)).write(PlayerRankRowsCompanion(syncedAt: Value(clock)));
      await r.saveQuestionnaire(chosen: Rank.g, suggested: Rank.h, answers: answers);
      expect((await db.select(db.playerRankRows).getSingle()).syncedAt, isNull);
    });

    test('mỗi người chỉ thấy hạng của mình', () async {
      await repo(userId: 'u2').saveQuestionnaire(chosen: Rank.c, suggested: Rank.c, answers: answers);
      expect(await repo().watchRank().first, isNull);
    });
  });

  group('làm bài', () {
    test('bắt đầu một lần; đang có lần dở thì không mở lần thứ hai', () async {
      final r = repo();
      final id = await startedTest(r);
      final again = await r.startTest(TableSize.eightFoot);
      expect(again, isA<TestAlreadyActive>());
      expect((again as TestAlreadyActive).testId, id);
    });

    test('đóng app giữa bài: mở lại vẫn còn đủ cú đã nhập, hạng không đổi', () async {
      final first = repo();
      await first.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(first);
      var f1 = ShotAttempts(const []);
      for (final made in [true, false, true]) {
        f1 = f1.add(made);
        await first.recordAttempts(id, 'F1', f1);
      }

      // "Mở lại app": repository mới trên cùng DB.
      final reopened = repo();
      final snap = await reopened.watchActiveTest().first;
      expect(snap!.test.id, id);
      expect((snap.attempts['F1']! as ShotAttempts).shots, [true, false, true]);
      expect(snap.nextDrill!.id, 'F1');
      expect((await reopened.watchRank().first)!.rank, Rank.h);
    });

    test('kết quả thô sai thì không ghi', () async {
      final r = repo();
      final id = await startedTest(r);
      await expectLater(r.recordAttempts(id, 'F1', CountAttempts([1])), throwsArgumentError);
      await expectLater(r.recordAttempts(id, 'F6', ShotAttempts(List.filled(11, true))), throwsArgumentError);
      expect(await db.select(db.buDrillResultRows).get(), isEmpty);
    });

    test('Hoàn tác bỏ cú vừa nhập, kể cả cú cuối của bài trước', () async {
      final r = repo();
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F1');
      var snap = await r.watchActiveTest().first;
      expect(snap!.attempts['F1']!.length, 7);
      expect(snap.nextDrill!.id, 'F1');

      clock = clock.add(const Duration(seconds: 1));
      await r.recordAttempts(id, 'F1', ladderPerfect());
      clock = clock.add(const Duration(seconds: 1));
      await r.recordAttempts(id, 'F2', ShotAttempts([true]));
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F2');
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F1', reason: 'F2 đã rỗng thì lùi về F1');
      snap = await r.watchActiveTest().first;
      expect(snap!.attempts['F1']!.length, 7);
    });

    test('chốt Đề I: xếp bản Đề II, khoá Đề I; bàn 8 feet đạt 100 thì Masters', () async {
      final r = repo();
      final id = await startedTest(r, size: TableSize.eightFoot);
      await record(r, id, examIAttempts(wagonAndTargetMade: true));
      expect(await r.finishExamI(id), ExamIIVersion.masters);
      final snap = await r.watchActiveTest().first;
      expect(snap!.test.examIScore, 100);
      await expectLater(r.recordAttempts(id, 'F8', ShotAttempts(const [])), throwsStateError);
      expect(await r.undoLastShot(id), isNull, reason: 'Đề I đã khoá, Đề II chưa có cú nào');
    });

    test('chưa đủ Đề I thì không chốt được', () async {
      final r = repo();
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      await expectLater(r.finishExamI(id), throwsStateError);
    });
  });

  group('hoàn tất và hạng', () {
    test('hoàn tất: tổng điểm, hạng quy đổi, lên hạng đã kiểm chứng', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      await record(r, id, examIIPerfect(ExamIIVersion.masters));
      final out = await r.completeTest(id) as TestCompleted;
      expect(out.total, 137);
      expect(out.result, Rank.d);
      expect(out.outcome, RankOutcome.promoted);
      expect(out.before, Rank.h);
      final rank = await r.watchRank().first;
      expect(rank!.rank, Rank.d);
      expect(rank.source, RankSource.verified);
      expect(rank.testId, id);
      final row = await (db.select(db.buTestRows)..where((t) => t.id.equals(id))).getSingle();
      expect(row.completedAt, clock);
      expect(row.totalScore, 137);
      expect(row.resultRank, 'd');
      expect(await r.watchActiveTest().first, isNull);
    });

    test('chưa đủ Đề II thì không hoàn tất được', () async {
      final r = repo();
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      await expectLater(r.completeTest(id), throwsStateError);
    });

    test('Đề II để sang buổi khác: hoàn tất được, ngày kiểm tra lại tính từ ngày làm Đề II', () async {
      final r = repo();
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      clock = DateTime(2026, 11, 20, 19); // 37 ngày sau mới làm Đề II
      await record(r, id, examIIPerfect(ExamIIVersion.masters));
      expect(await r.completeTest(id), isA<TestCompleted>());
      clock = DateTime(2026, 12, 3, 23);
      expect(await r.startTest(TableSize.nineFootPlus), isA<RetestTooSoon>());
      clock = DateTime(2026, 12, 4);
      expect(await r.startTest(TableSize.nineFootPlus), isA<TestStarted>());
    });

    test('chưa đủ 14 ngày thì không bắt đầu lần mới, báo ngày được làm', () async {
      final r = repo();
      await completedTest(r);
      clock = DateTime(2026, 10, 20);
      final out = await r.startTest(TableSize.nineFootPlus);
      expect((out as RetestTooSoon).from, DateTime(2026, 10, 28));
    });

    test('lần làm dở trên máy khác hoàn tất trong 14 ngày thì bị chặn tới ngày được phép', () async {
      final r = repo();
      // Lần B bắt đầu 28/9 trên máy này; lần A (bắt đầu trên máy khác) hoàn
      // tất 1/10 rồi được kéo về máy này.
      clock = DateTime(2026, 9, 28, 9);
      final b = await startedTest(r);
      await record(r, b, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(b);
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
            id: 'tA',
            userId: 'u1',
            startedAt: DateTime(2026, 9, 30),
            tableSize: 'nineFootPlus',
            completedAt: Value(DateTime(2026, 10, 1)),
            totalScore: const Value(80),
            resultRank: const Value('g'),
          ));
      clock = DateTime(2026, 10, 5);
      await record(r, b, examIIPerfect(ExamIIVersion.masters));
      final out = await r.completeTest(b);
      expect((out as CompletionTooSoon).from, DateTime(2026, 10, 15));
      expect(await r.watchRank().first, isNull, reason: 'lần chưa hoàn tất không đổi hạng');
      clock = DateTime(2026, 10, 15);
      expect(await r.completeTest(b), isA<TestCompleted>());
    });

    test('kết quả thấp hơn: giữ hạng, đặt cảnh báo', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.b, suggested: Rank.c, answers: answers);
      await completedTest(r);
      final rank = await r.watchRank().first;
      expect(rank!.rank, Rank.b);
      expect(rank.source, RankSource.selfDeclared);
      expect(rank.warningRank, Rank.d);
    });
  });

  group('hủy', () {
    test('hủy rồi bắt đầu lại được ngay, hạng không đổi', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      await r.cancelTest(id);
      expect(await r.watchActiveTest().first, isNull);
      await expectLater(r.recordAttempts(id, 'F2', ShotAttempts([true])), throwsStateError);
      expect(await r.startTest(TableSize.nineFootPlus), isA<TestStarted>());
      expect((await r.watchRank().first)!.rank, Rank.h);
      final tests = await r.watchTests().first;
      expect(tests.where((t) => t.isCancelled), hasLength(1));
    });

    test('lần đã hoàn tất không hủy được', () async {
      final r = repo();
      final id = await completedTest(r);
      await r.cancelTest(id);
      final row = await (db.select(db.buTestRows)..where((t) => t.id.equals(id))).getSingle();
      expect(row.cancelledAt, isNull);
    });
  });

  test('lịch sử: mới nhất trước, chỉ của người đang đăng nhập', () async {
    final r = repo();
    final a = await completedTest(r);
    clock = DateTime(2026, 11, 1);
    final b = await startedTest(r);
    await startedTest(repo(userId: 'u2'));
    final tests = await r.watchTests().first;
    expect(tests.map((t) => t.id).toList(), [b, a]);
  });
}
