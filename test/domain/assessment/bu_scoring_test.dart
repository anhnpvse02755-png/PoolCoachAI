// ignore_for_file: constant_identifier_names
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

const V = true; // vào
const T = false; // trượt

void main() {
  group('thang vị trí F1–F5', () {
    // BU_Exam-I_Score_Sheet.pdf trang 1: "position (start: 4)"; "circle every
    // 7 that follows a 7 … The number of circles is the number of bonus
    // points. The maximum score allowed (including bonus points) is 10";
    // "score (10 max) = last pos. + bonus". Vào +1, trượt −1, kẹp 1–7: spec
    // mục 5.3 và BU_Exam-I_Fundamentals.pdf (đối chiếu trang mô tả F1).
    test('ví dụ tính tay: lên 7, ba lần vào ở 7 → 7 + 3 = 10', () {
      final shots = [V, T, V, V, V, V, T, V, V, V];
      expect(ladderPositions(shots), [5, 4, 5, 6, 7, 7, 6, 7, 7, 7]);
      expect(ladderBonus(shots), 3);
      expect(ladderScore(shots), 10);
    });

    test('ví dụ tính tay không chạm trần: 7 + 1 = 8', () {
      final shots = [T, T, V, V, V, V, V, V, T, V];
      expect(ladderPositions(shots), [3, 2, 3, 4, 5, 6, 7, 7, 6, 7]);
      expect(ladderBonus(shots), 1);
      expect(ladderScore(shots), 8);
    });

    test('toàn trượt: kẹp ở 1, điểm 1', () {
      final shots = List.filled(10, T);
      expect(ladderPositions(shots).last, 1);
      expect(ladderScore(shots), 1);
    });

    test('toàn vào: 7 + 7 thưởng, ghi 10', () {
      final shots = List.filled(10, V);
      expect(ladderBonus(shots), 7);
      expect(ladderScore(shots), 10);
    });

    test('cú thứ 10 vẫn được áp dụng', () {
      final nine = [V, V, V, T, T, T, T, T, T];
      expect(ladderScore(nine), 1);
      expect(ladderScore([...nine, V]), 2);
    });

    test('chưa đánh cú nào: đứng ở vị trí 4', () {
      expect(ladderPosition(const []), 4);
      expect(ladderScore(const []), 4);
    });

    test('dừng sớm khi đã chắc chắn 10: tám cú vào liền', () {
      // Sau 8 cú: vị trí 7, thưởng 5, còn 2 cú; trượt cả 2 vẫn 5 + 5 = 10.
      expect(ladderSettled(List.filled(7, V)), isFalse);
      expect(ladderSettled(List.filled(8, V)), isTrue);
      expect(ladderScore(List.filled(8, V)), 10);
    });

    test('chưa chắc 10 thì phải đánh đủ 10 cú', () {
      expect(ladderSettled([V, T, V, V, V, V, T, V, V]), isFalse);
      expect(ladderSettled([V, T, V, V, V, V, T, V, V, V]), isTrue);
      expect(ladderSettled(List.filled(10, T)), isTrue);
    });

    test('quá 10 cú là lỗi lập trình', () {
      expect(() => ladderPositions(List.filled(11, V)), throwsRangeError);
    });
  });

  group('đếm lượt thành công (F6, F7, F8, S5–S9)', () {
    // BU_Exam-I_Score_Sheet.pdf: F6 "score (10 max) = # of balls pocketed",
    // F7 "score (20 max) = total # of hits", F8 "score (20 max) = total # on
    // target"; Exam II sheets: S5 "= # hidden", S6 "= # of hits", S7
    // "= # pocketed", S8/S9 "= # of successes".
    test('mỗi lượt thành công 1 điểm', () {
      expect(successCount([V, T, V, V]), 3);
      expect(successCount(List.filled(20, T)), 0);
      expect(successCount(List.filled(20, V)), 20);
    });
  });

  group('lấy lượt cao hơn trong 2 lượt (S1, S2)', () {
    // Exam II sheets: "score (… max) = best of two".
    test('lấy lượt cao hơn', () {
      expect(bestOfTwo([2, 3]), 3);
      expect(bestOfTwo([4, 1]), 4);
      expect(bestOfTwo([0, 0]), 0);
    });

    test('một lượt (lượt 1 hoàn hảo) cũng chấm được', () {
      expect(bestOfTwo([7]), 7);
    });

    test('không có lượt hay quá 2 lượt là lỗi lập trình', () {
      expect(() => bestOfTwo(const []), throwsArgumentError);
      expect(() => bestOfTwo([1, 2, 3]), throwsArgumentError);
    });
  });

  group('cộng hai thế thấp nhất trong 3 thế (S3, S4)', () {
    // Exam II sheets: "score (… max) = lowest + 2nd lowest".
    test('ví dụ tính tay', () {
      expect(sumOfLowestTwo([5, 2, 4]), 6);
      expect(sumOfLowestTwo([5, 5, 5]), 10);
      expect(sumOfLowestTwo([0, 7, 0]), 0);
    });

    test('phải đủ 3 thế', () {
      expect(() => sumOfLowestTwo([5, 5]), throwsArgumentError);
    });
  });

  group('trung vị 3 lần phá (S10)', () {
    // Exam II sheets: "score (5 max) = median (middle value) of the three
    // break scores"; tiêu chí a–e: spec mục 5.2, đối chiếu trang S10 của
    // BU_Exam-II_Skills-*.pdf.
    const full = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
    const scratch = BreakCriteria(a: false, b: true, c: true, d: true, e: true);
    const twoPoints = BreakCriteria(a: true, d: true);

    test('điểm một lần phá: đếm tiêu chí, nhưng b–e chỉ tính khi đạt a', () {
      expect(full.points, 5);
      expect(twoPoints.points, 2);
      expect(scratch.points, 0, reason: 'phá chết cái thì 0 điểm');
    });

    test('lấy trung vị', () {
      expect(medianOfThreeBreaks([full, scratch, twoPoints]), 2);
      expect(medianOfThreeBreaks([full, full, scratch]), 5);
      expect(medianOfThreeBreaks([scratch, scratch, full]), 0);
    });

    test('phải đủ 3 lần phá', () {
      expect(() => medianOfThreeBreaks([full, full]), throwsArgumentError);
    });
  });

  group('kết quả thô ghi ra JSON rồi đọc lại', () {
    test('ba kiểu, kể cả danh sách rỗng', () {
      final cases = <DrillAttempts>[
        ShotAttempts([V, T, V]),
        ShotAttempts(const []),
        CountAttempts([3, 4]),
        BreakAttempts([const BreakCriteria(a: true, c: true)]),
      ];
      for (final a in cases) {
        expect(DrillAttempts.fromJson(a.toJson()), a, reason: '$a');
      }
    });

    test('add và withoutLast không sửa bản gốc', () {
      final a = ShotAttempts([V]);
      final b = a.add(T);
      expect(a.shots, [V]);
      expect(b.shots, [V, T]);
      expect(b.withoutLast().shots, [V]);
      expect(ShotAttempts(const []).withoutLast().isEmpty, isTrue);
    });

    test('JSON lạ thì ném, không đoán', () {
      expect(() => DrillAttempts.fromJson({'x': 1}), throwsFormatException);
      expect(() => DrillAttempts.fromJson([1]), throwsFormatException);
    });
  });
}
