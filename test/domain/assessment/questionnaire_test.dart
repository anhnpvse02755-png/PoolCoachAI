import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Bảng quy đổi của spec mục 11.2 — một test cho mỗi dòng.
///
/// Chỉ số lựa chọn (từ 0):
///   Q4: 0 "1", 1 "2", 2 "3", 3 "4", 4 "5", 5 "6+", 6 "Thường xuyên Runout".
///   Q5: 0 "Chưa bao giờ", 1 "Đã từng 1–2 lần", 2 "Thỉnh thoảng",
///       3 "Khá thường xuyên", 4 "Rất thường xuyên".
///   Q6: 0 "Chưa từng", 1 "Hơn 100 rack", 2 "Khoảng 50 rack", 3 "Khoảng 20
///       rack", 4 "Khoảng 10 rack", 5 "Khoảng 5 rack", 6 "Khoảng 2–3 rack",
///       7 "Gần như rack nào cũng có thể".
void main() {
  QuestionnaireAnswers a({int q4 = 0, int q5 = 0, int q6 = 0, int other = 0}) =>
      QuestionnaireAnswers([other, other % 5, other, q4, q5, q6, other % 5, other % 5]);

  test('Q5 "Chưa bao giờ" + Q4 = 1 → K', () {
    expect(suggestRank(a(q5: 0, q4: 0)), Rank.k);
  });

  test('Q5 "Chưa bao giờ" + Q4 = 2 → I', () {
    expect(suggestRank(a(q5: 0, q4: 1)), Rank.i);
  });

  test('Q5 "Chưa bao giờ" + Q4 ≥ 3 → H', () {
    for (var q4 = 2; q4 <= 6; q4++) {
      expect(suggestRank(a(q5: 0, q4: q4)), Rank.h, reason: 'Q4 chỉ số $q4');
    }
  });

  test('Q5 "Đã từng 1–2 lần" → H, bất kể Q4 và Q6', () {
    for (var q4 = 0; q4 <= 6; q4++) {
      for (var q6 = 0; q6 <= 7; q6++) {
        expect(suggestRank(a(q5: 1, q4: q4, q6: q6)), Rank.h, reason: 'Q4 $q4, Q6 $q6');
      }
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Chưa từng / Hơn 100 / Khoảng 50 → G', () {
    for (final q5 in [2, 3, 4]) {
      for (final q6 in [0, 1, 2]) {
        expect(suggestRank(a(q5: q5, q6: q6)), Rank.g, reason: 'Q5 $q5, Q6 $q6');
      }
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 20 rack → F', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 3)), Rank.f);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 10 rack → E', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 4)), Rank.e);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 5 rack → D', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 5)), Rank.d);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 2–3 rack → C', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 6)), Rank.c);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Gần như rack nào cũng có thể → B', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 7)), Rank.b);
    }
  });

  test('không câu trả lời nào dẫn tới A hay PRO', () {
    for (var q4 = 0; q4 < questionOptionCounts[3]; q4++) {
      for (var q5 = 0; q5 < questionOptionCounts[4]; q5++) {
        for (var q6 = 0; q6 < questionOptionCounts[5]; q6++) {
          expect(suggestRank(a(q4: q4, q5: q5, q6: q6)), isNot(anyOf(Rank.a, Rank.pro)));
        }
      }
    }
  });

  test('Q1, Q2, Q3, Q7, Q8 không đổi hạng gợi ý', () {
    for (var other = 0; other <= 4; other++) {
      expect(suggestRank(a(q5: 2, q6: 4, other: other)), Rank.e, reason: 'other $other');
    }
  });
}
