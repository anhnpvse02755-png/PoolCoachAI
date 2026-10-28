import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  final a1 = stById('a1');
  final t2 = stById('t2');
  Drill withThreshold(double t) =>
      stDrill('x', SkillCategory.aiming, 1, passThreshold: t);

  group('skillTestPassed — cùng tiêu chí với buổi tập (drillRatio ≥ 1)', () {
    test('bài đếm cú: 8/10 với ngưỡng 0.8 là đạt, 7/10 là trượt', () {
      expect(skillTestPassed(a1, score: 8, attempts: 10), isTrue);
      expect(skillTestPassed(a1, score: 7, attempts: 10), isFalse);
    });
    test('bài mục tiêu: 25 với mục tiêu 25 là đạt, 24.5 là trượt', () {
      expect(skillTestPassed(t2, score: 25), isTrue);
      expect(skillTestPassed(t2, score: 24.5), isFalse);
    });
    test('thiếu số lần thử thì không chấm được, không quy về trượt', () {
      expect(skillTestPassed(a1, score: 8), isNull);
      expect(skillTestPassed(a1, score: 8, attempts: 0), isNull);
    });
  });

  group('passMark', () {
    test('ngưỡng tỉ lệ ra số lần đạt nhỏ nhất, khớp drillRatio', () {
      expect(passMark(withThreshold(0.8), attempts: 10), 8);
      expect(passMark(withThreshold(0.7), attempts: 10), 7);
      expect(passMark(withThreshold(0.6), attempts: 15), 9);
      expect(passMark(withThreshold(0.5), attempts: 10), 5);
    });
    test('bài mục tiêu trả mục tiêu; bài đếm cú thiếu số lần thử trả null', () {
      expect(passMark(t2), 25);
      expect(passMark(a1), isNull);
    });
  });

  group('checkSkillTestInput', () {
    test('kết quả hợp lệ', () {
      expect(checkSkillTestInput(a1, score: 8, attempts: 10), isNull);
      expect(checkSkillTestInput(t2, score: 22.5), isNull);
    });
    test('mỗi kiểu kết quả bịa ra một lỗi có tên', () {
      expect(checkSkillTestInput(a1, score: 11, attempts: 10),
          SkillTestInputError.scoreAboveAttempts);
      expect(checkSkillTestInput(a1, score: 8.5, attempts: 10),
          SkillTestInputError.scoreNotWhole);
      expect(checkSkillTestInput(a1, score: -1, attempts: 10),
          SkillTestInputError.scoreInvalid);
      expect(checkSkillTestInput(a1, score: double.infinity, attempts: 10),
          SkillTestInputError.scoreInvalid);
      expect(checkSkillTestInput(a1, score: double.nan, attempts: 10),
          SkillTestInputError.scoreInvalid);
      expect(checkSkillTestInput(a1, score: 8),
          SkillTestInputError.attemptsRequired);
      expect(checkSkillTestInput(a1, score: 0, attempts: 0),
          SkillTestInputError.attemptsInvalid);
      expect(checkSkillTestInput(t2, score: 25, attempts: 10),
          SkillTestInputError.attemptsNotAllowed);
    });
  });

  group('SkillTest', () {
    test('chỉ lần hoàn tất, đạt, không huỷ mới chứng nhận', () {
      expect(passedTest('a1', 1, stToday).certifies, isTrue);
      expect([
        failedTest('a1', 1, stToday).certifies,
        failedTest('a1', 1, stToday).failed
      ], [false, true]);
      expect([
        cancelledTest('a1', 1, stToday).certifies,
        cancelledTest('a1', 1, stToday).failed
      ], [false, false]);
    });
    test(
        'lần hoàn tất thiếu kết quả chấm (dữ liệu hỏng) không phải đạt, cũng không phải trượt',
        () {
      final broken = SkillTest(
          id: 'x',
          drillId: 'a1',
          drillLevel: 1,
          tableSize: TableSize.nineFootPlus,
          startedAt: stToday,
          completedAt: stToday);
      expect([broken.isCompleted, broken.certifies, broken.failed],
          [true, false, false]);
    });
    test('== và hashCode theo mọi trường, kể cả ảnh chụp tiêu chí', () {
      final a = passedTest('a1', 1, stToday);
      final b = passedTest('a1', 1, stToday);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.passThreshold, 0.8);
      expect(a.target, isNull);
      expect(passedTest('t2', 2, stToday).target, 25);
    });
  });

  group('ảnh chụp tiêu chí (S4)', () {
    // `passed` đi theo kết quả chấm của chính ảnh chụp, không gán cứng.
    SkillTest completed({
      double? passThreshold,
      num? target,
      num? score = 9,
      bool? passed,
    }) {
      final oneCriterion = (passThreshold == null) != (target == null);
      final verdict = oneCriterion && score != null
          ? skillTestPassed(
              stDrill('x', SkillCategory.aiming, 1,
                  passThreshold: passThreshold, target: target),
              score: score,
              attempts: target == null ? 10 : null)
          : true;
      return SkillTest(
        id: 'x',
        drillId: 'a1',
        drillLevel: 1,
        tableSize: TableSize.nineFootPlus,
        startedAt: stToday,
        completedAt: stToday,
        score: score,
        attempts: target == null ? 10 : null,
        passed: passed ?? verdict,
        passThreshold: passThreshold,
        target: target,
      );
    }

    test('passed mâu thuẫn với chấm lại thì không chứng nhận cũng không trượt',
        () {
      for (final t in [
        completed(passThreshold: 0.8, score: 5, passed: true),
        completed(target: 25, score: 9, passed: true),
        completed(passThreshold: 0.8, score: 9, passed: false),
        completed(target: 25, score: 25, passed: false),
      ]) {
        expect([t.certifies, t.failed], [false, false], reason: '$t');
      }
    });
    test('passed true không có kết quả hoặc không có ảnh chụp thì không chứng nhận',
        () {
      final noScore = SkillTest(
          id: 'x',
          drillId: 'a1',
          drillLevel: 1,
          tableSize: TableSize.nineFootPlus,
          startedAt: stToday,
          completedAt: stToday,
          passed: true);
      expect([noScore.certifies, noScore.failed], [false, false]);
      expect(
          [
            passedTest('t2', 2, stToday).certifies,
            failedTest('t2', 2, stToday).failed,
            failedTest('t2', 2, stToday).certifies,
            passedTest('t2', 2, stToday).failed,
          ],
          [true, true, false, false]);
    });
    test('đổi ngưỡng của bài sau đó không làm đổi kết luận của lần cũ', () {
      final before = stDrill('x', SkillCategory.aiming, 1, passThreshold: 0.8);
      final old = SkillTest(
        id: 'x',
        drillId: 'x',
        drillLevel: 1,
        tableSize: TableSize.nineFootPlus,
        startedAt: stToday,
        completedAt: stToday,
        score: 8,
        attempts: 10,
        passed: skillTestPassed(before, score: 8, attempts: 10),
        passThreshold: before.passThreshold,
      );
      final after = withThreshold(0.9);
      expect(skillTestPassed(after, score: 8, attempts: 10), isFalse);
      expect(skillTestVerdict(old), isTrue);
      expect(old.certifies, isTrue);
      expect(skillTestPassMark(old), 8);
    });

    test('lần hoàn tất có kết quả phải có đúng một trường tiêu chí', () {
      expect(() => completed(), throwsA(isA<AssertionError>()));
      expect(() => completed(passThreshold: 0.8, target: 25),
          throwsA(isA<AssertionError>()));
      expect(completed(passThreshold: 0.8).passThreshold, 0.8);
      expect(completed(target: 25).target, 25);
    });
    test('lần huỷ hoặc hỏng thiếu kết quả có thể không có tiêu chí', () {
      expect(cancelledTest('a1', 1, stToday).passThreshold, isNull);
      expect(completed(score: null).target, isNull);
    });
    test('chấm theo ảnh chụp, không theo bài hiện tại', () {
      // Bài hiện tại có thể đã đổi ngưỡng, nhưng giấy chứng nhận cũ vẫn
      // phản ánh tiêu chí lúc đạt.
      final old = completed(passThreshold: 0.8, score: 8);
      expect(skillTestPassMark(old), 8);
      expect(skillTestVerdict(old), isTrue);
      expect(
          skillTestVerdict(completed(passThreshold: 0.9, score: 8)), isFalse);
      expect(skillTestPassMark(completed(passThreshold: 0.9)), 9);
      final byTarget = completed(target: 25, score: 25).copyForTarget();
      expect(skillTestPassMark(byTarget), 25);
    });
    test('không có ảnh chụp thì không chấm được', () {
      expect(skillTestVerdict(cancelledTest('a1', 1, stToday)), isNull);
      expect(skillTestPassMark(cancelledTest('a1', 1, stToday)), isNull);
    });
  });
}

extension on SkillTest {
  // Bài mục tiêu không có attempts.
  SkillTest copyForTarget() => SkillTest(
        id: id,
        drillId: drillId,
        drillLevel: drillLevel,
        tableSize: tableSize,
        startedAt: startedAt,
        completedAt: completedAt,
        score: score,
        passed: passed,
        target: target,
      );
}
