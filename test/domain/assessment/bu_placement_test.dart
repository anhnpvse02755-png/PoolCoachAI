import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('xếp bản Đề II — BU_Exam_Instructions.pdf trang 1 mục 5, '
      'BU_Exam-I_Score_Sheet.pdf "Score Ranges for Exam II Placement"', () {
    test('mốc 49/50 và 69/70 trên bàn 9 feet', () {
      const t = TableSize.nineFootPlus;
      expect(placeExamII(0, t), ExamIIVersion.bachelors);
      expect(placeExamII(49, t), ExamIIVersion.bachelors);
      expect(placeExamII(50, t), ExamIIVersion.masters);
      expect(placeExamII(69, t), ExamIIVersion.masters);
      expect(placeExamII(70, t), ExamIIVersion.doctorate);
      expect(placeExamII(100, t), ExamIIVersion.doctorate);
    });

    test('bàn 7–8 feet đạt mức Doctorate thì làm bản Masters', () {
      for (final t in [TableSize.sevenFoot, TableSize.eightFoot]) {
        expect(placeExamII(70, t), ExamIIVersion.masters, reason: '$t');
        expect(placeExamII(100, t), ExamIIVersion.masters, reason: '$t');
        expect(placeExamII(49, t), ExamIIVersion.bachelors, reason: '$t');
        expect(placeExamII(50, t), ExamIIVersion.masters, reason: '$t');
      }
    });

    test('điểm ngoài 0–100 là lỗi lập trình', () {
      expect(() => placeExamII(-1, TableSize.nineFootPlus), throwsRangeError);
      expect(() => placeExamII(101, TableSize.nineFootPlus), throwsRangeError);
    });
  });

  group('quy đổi BU sang hạng — spec mục 5.4 (gộp mức của BU_Rating_Comparisons.pdf)', () {
    test('mọi mốc của bảng', () {
      const cases = {
        0: Rank.k, 19: Rank.k, 20: Rank.i, 39: Rank.i, 40: Rank.h, 54: Rank.h,
        55: Rank.h, 69: Rank.h, 70: Rank.g, 94: Rank.g, 95: Rank.f, 109: Rank.f,
        110: Rank.e, 124: Rank.e, 125: Rank.d, 139: Rank.d, 140: Rank.c,
        154: Rank.c, 155: Rank.b, 174: Rank.b, 175: Rank.a, 200: Rank.a,
      };
      cases.forEach((score, rank) {
        expect(rankForBuScore(score), rank, reason: 'điểm $score');
      });
    });

    test('các dải liền nhau, phủ đúng 0–200, xếp K → A, không có PRO', () {
      expect(buRankBands.first.min, 0);
      expect(buRankBands.last.max, buTotalMax);
      for (var i = 1; i < buRankBands.length; i++) {
        expect(buRankBands[i].min, buRankBands[i - 1].max + 1);
        expect(buRankBands[i].rank.index, buRankBands[i - 1].rank.index + 1);
      }
      expect(buRankBands.map((b) => b.rank), isNot(contains(Rank.pro)));
      expect(buRankBands.map((b) => b.rank).toList(),
          Rank.values.where((r) => r != Rank.pro).toList());
    });

    test('dải mang tên mức BU và Fargo tham chiếu của spec', () {
      expect(bandForBuScore(150).buLevels, 'upper advanced');
      expect(bandForBuScore(150).fargo, '600–649');
      expect(bandForBuScore(10).fargo, '< 200');
      expect(bandForBuScore(180).fargo, '≥ 730');
    });

    test('điểm ngoài 0–200 là lỗi lập trình', () {
      expect(() => rankForBuScore(-1), throwsRangeError);
      expect(() => rankForBuScore(201), throwsRangeError);
    });
  });
}
