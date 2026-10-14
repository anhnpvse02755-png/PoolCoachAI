import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

void main() {
  group('tổng điểm tối đa — dòng TOTAL của các phiếu điểm BU', () {
    test('Đề I 100 (BU_Exam-I_Score_Sheet.pdf "TOTAL (max = 100)")', () {
      expect(examIDrills.map((d) => d.id).toList(),
          ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8']);
      expect(examIDrills.fold<int>(0, (s, d) => s + d.maxScore), examIMax);
    });

    test('Đề II: Bachelors 54, Masters 77, Doctorate 100', () {
      expect(examIIMax(ExamIIVersion.bachelors), 54);
      expect(examIIMax(ExamIIVersion.masters), 77);
      expect(examIIMax(ExamIIVersion.doctorate), 100);
      for (final v in ExamIIVersion.values) {
        expect(examIIDrills(v).map((d) => d.id).toList(),
            ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10'],
            reason: '$v');
      }
    });

    test('tối đa từng bài theo bảng spec mục 5.2', () {
      int max(ExamIIVersion v, String id) => drillFor(id, v).maxScore;
      const b = ExamIIVersion.bachelors, m = ExamIIVersion.masters, d = ExamIIVersion.doctorate;
      expect([max(b, 'S1'), max(m, 'S1'), max(d, 'S1')], [4, 7, 10]);
      expect([max(b, 'S2'), max(m, 'S2'), max(d, 'S2')], [7, 11, 15]);
      expect([max(b, 'S3'), max(m, 'S3'), max(d, 'S3')], [10, 12, 14]);
      expect([max(b, 'S4'), max(m, 'S4'), max(d, 'S4')], [10, 12, 14]);
      expect([max(b, 'S5'), max(m, 'S5'), max(d, 'S5')], [6, 10, 14]);
      for (final id in ['S6', 'S7', 'S8', 'S9']) {
        expect([max(b, id), max(m, id), max(d, id)], [3, 5, 7], reason: id);
      }
      expect([max(b, 'S10'), max(m, 'S10'), max(d, 'S10')], [5, 5, 5]);
    });

    test('S3/S4 mỗi thế tối đa bằng nửa điểm bài (5 / 6 / 7 bi)', () {
      for (final v in ExamIIVersion.values) {
        for (final id in ['S3', 'S4']) {
          final drill = drillFor(id, v);
          expect(drill.perAttemptMax! * 2, drill.maxScore, reason: '$id $v');
        }
      }
    });

    test('S5: mỗi vị trí bi cái 2 lượt (3 / 5 / 7 vị trí)', () {
      expect(drillFor('S5', ExamIIVersion.bachelors).groups, 3);
      expect(drillFor('S5', ExamIIVersion.masters).groups, 5);
      expect(drillFor('S5', ExamIIVersion.doctorate).groups, 7);
      expect(drillFor('S5', ExamIIVersion.doctorate).attemptsPerGroup, 2);
    });
  });

  group('xong bài và điểm bài', () {
    test('thang vị trí: xong khi đủ 10 cú hoặc đã chắc 10', () {
      final f1 = drillFor('F1', null);
      expect(isDrillComplete(f1, ShotAttempts(List.filled(7, true))), isFalse);
      expect(drillScore(f1, ShotAttempts(List.filled(7, true))), isNull);
      expect(isDrillComplete(f1, ShotAttempts(List.filled(8, true))), isTrue);
      expect(drillScore(f1, ShotAttempts(List.filled(8, true))), 10);
    });

    test('F7: 10 bi đích × 2 lượt = 20 ô', () {
      final f7 = drillFor('F7', null);
      expect(f7.groups, 10);
      expect(isDrillComplete(f7, ShotAttempts(List.filled(19, true))), isFalse);
      expect(drillScore(f7, ShotAttempts(List.filled(20, true))), 20);
    });

    // BU_Exam-II_Score_Sheet-*.pdf: "The 2nd attempt is not required with a
    // perfect score on the 1st attempt." (D3 của kế hoạch)
    test('S1/S2: lượt 1 hoàn hảo thì không cần lượt 2', () {
      final s1 = drillFor('S1', ExamIIVersion.masters);
      expect(isDrillComplete(s1, CountAttempts([7])), isTrue);
      expect(drillScore(s1, CountAttempts([7])), 7);
      expect(isDrillComplete(s1, CountAttempts([6])), isFalse);
      expect(drillScore(s1, CountAttempts([6, 3])), 6);
      expect(attemptsValid(s1, CountAttempts([7, 2])), isFalse,
          reason: 'đã xong thì không nhập thêm');
    });

    test('S3: đủ 3 thế mới có điểm', () {
      final s3 = drillFor('S3', ExamIIVersion.bachelors);
      expect(drillScore(s3, CountAttempts([5, 4])), isNull);
      expect(drillScore(s3, CountAttempts([5, 4, 2])), 6);
    });

    test('S10: đủ 3 lần phá, lấy trung vị', () {
      final s10 = drillFor('S10', ExamIIVersion.doctorate);
      const full = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
      const two = BreakCriteria(a: true, d: true);
      expect(drillScore(s10, BreakAttempts([full, two, full])), 5);
      expect(drillScore(s10, BreakAttempts([full, two])), isNull);
    });
  });

  group('chặn nhập sai từ đầu (spec mục 8)', () {
    test('số bi ngoài 0…tối đa một lượt', () {
      final s3 = drillFor('S3', ExamIIVersion.bachelors);
      expect(attemptsValid(s3, CountAttempts([6])), isFalse);
      expect(attemptsValid(s3, CountAttempts([-1])), isFalse);
      expect(attemptsValid(s3, CountAttempts([5, 0, 5])), isTrue);
    });

    test('quá số lượt hoặc nhập sau khi thang đã chắc 10', () {
      final f6 = drillFor('F6', null);
      expect(attemptsValid(f6, ShotAttempts(List.filled(11, true))), isFalse);
      final f2 = drillFor('F2', null);
      expect(attemptsValid(f2, ShotAttempts(List.filled(9, true))), isFalse,
          reason: 'sau 8 cú vào liền bài đã xong');
    });

    test('sai kiểu kết quả thô', () {
      expect(attemptsValid(drillFor('F1', null), CountAttempts([1])), isFalse);
      expect(() => drillScore(drillFor('F1', null), CountAttempts([1])), throwsArgumentError);
    });

    test('lần phá chết cái mà có đánh dấu b–e thì không hợp lệ', () {
      final s10 = drillFor('S10', ExamIIVersion.bachelors);
      expect(attemptsValid(s10, BreakAttempts([const BreakCriteria(a: false, b: true)])), isFalse);
    });

    test('bài rỗng khớp kiểu của bài', () {
      for (final d in [...examIDrills, ...examIIDrills(ExamIIVersion.masters)]) {
        expect(attemptsValid(d, emptyAttemptsFor(d)), isTrue, reason: d.id);
      }
    });
  });

  test('drillFor: bài Đề II cần bản, mã lạ thì ném', () {
    expect(() => drillFor('S1', null), throwsArgumentError);
    expect(() => drillFor('X1', ExamIIVersion.masters), throwsArgumentError);
  });
}
