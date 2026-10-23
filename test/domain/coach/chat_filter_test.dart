import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/chat_filter.dart';

const facts = <String, Object?>{
  'skills': {
    'aiming': {'mastery': 62, 'trend': 'up', 'sessions': 8},
    'safety': {'mastery': null, 'trend': 'notEnoughData', 'sessions': 2},
  },
  'today': {
    'category': 'safety',
    'drillName': 'Bài 3: thủ sau bi 9',
    'streak': 4,
    'practiceMinutesThisWeek': 1250,
    'scheduledToday': ['Tập thủ 19:00'],
  },
  'matches': {
    'recent': {'played': 7, 'won': 4, 'lost': 3},
  },
};
// Số được phép: 62, 0,62, 8, 2, 3, 9, 4, 1250, 19, 0, 7. Không được: 5, 6, 10, 11, 30, 57, 70.

void main() {
  group('chặn', () {
    for (final (text, rule) in [
      ('Ngắm lệch 5° sang trái.', CoachBlockRule.degree),
      ('Góc 30 độ là khó.', CoachBlockRule.degree),
      ('Bạn nên ngắm lệch một chút.', CoachBlockRule.aimShift),
      ('Ngắm dày hơn ở cú cắt.', CoachBlockRule.aimShift),
      ('Ngắm mỏng hơn nhé.', CoachBlockRule.aimShift),
      ('Đừng lệch điểm ngắm.', CoachBlockRule.aimShift),
      ('Cách TỐI ƯU là đánh trô bi.', CoachBlockRule.optimal),
      ('Dùng 70% BHE.', CoachBlockRule.spinRatio),
      ('FHE cao hơn thì sao?', CoachBlockRule.spinRatio),
      ('Bạn tập 5 buổi tuần này.', CoachBlockRule.unknownNumber),
      ('Tỉ lệ thắng 57%.', CoachBlockRule.unknownNumber),
      ('Ngắm chấm 6 băng dài trên.', CoachBlockRule.unknownNumber),
      ('Tập 6 ngày liền.', CoachBlockRule.unknownNumber),
      ('Có 11 cách.', CoachBlockRule.unknownNumber),
      ('   ', CoachBlockRule.empty),
    ]) {
      test(text, () {
        expect(coachReplyBlock(text, facts), rule);
        expect(filterCoachReply(text, facts), (text: '', insufficient: true));
      });
    }
    test('số trong câu hỏi của người chơi vẫn bị chặn', () {
      expect(coachReplyBlock('Bạn nói đã tập 5 buổi, nhưng app chưa ghi buổi nào.', facts),
          CoachBlockRule.unknownNumber);
    });
  });

  group('cho qua', () {
    for (final text in [
      'Ngắm bi đang ở mức 62, xu hướng đi lên.',
      'Độ thuần thục Ngắm bi là 62%.',
      'Độ thuần thục Ngắm bi là 62 %.',
      'Tức là 0,62 hay 0.62 của mức tối đa.',
      'Hôm nay tập Bài 3: thủ sau bi 9.',
      'Tuần này bạn tập tự do 1.250 phút.',
      'Số phút tập tự do tuần này là 1.250.',
      'Có 5 nhóm cần xem và 6 câu hỏi cho bạn, thêm 10 cách tập.',
      'Luật 9 bi và 10 bi khác nhau.',
      'Độ khó của bài này vừa phải.',
      'Ăn ½ bi, lệch bên trái.',
    ]) {
      test(text, () => expect(coachReplyBlock(text, facts), isNull));
    }
    test('trả nguyên câu, chỉ bỏ khoảng trắng hai đầu', () {
      expect(filterCoachReply('  Tập Phòng thủ.  ', facts), (text: 'Tập Phòng thủ.', insufficient: false));
    });
  });

  test('mẫu cấm chung với Giai đoạn A', () {
    expect(coachBannedRule('NGẮM LỆCH nửa bi'), CoachBlockRule.aimShift);
    expect(coachBannedRule('lực 45 độ'), CoachBlockRule.degree);
    expect(coachBannedRule('Đánh đứng bi, lực vừa.'), isNull);
  });
}
