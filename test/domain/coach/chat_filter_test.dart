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

  group('sửa vòng 1 (review)', () {
    test('1. ký hiệu độ giả º và ˚ cũng bị chặn như °', () {
      expect(coachReplyBlock('Góc nghiêng 4º.', facts), CoachBlockRule.degree);
      expect(coachReplyBlock('Góc nghiêng 4˚.', facts), CoachBlockRule.degree);
    });

    test('1. số viết bằng chữ trước "độ" cũng bị chặn (degree)', () {
      expect(coachReplyBlock('Đánh góc ba mươi độ là được.', facts), CoachBlockRule.degree);
    });

    test('1. số viết bằng chữ không mơ hồ bị chặn dù không đứng trước "độ"', () {
      expect(coachReplyBlock('Bạn đã tập mười lăm buổi tuần này.', facts), CoachBlockRule.unknownNumber);
    });

    test('2. chỉ xoá "N bi" khi có ngữ cảnh ván đấu đứng trước, không ẩn số bịa', () {
      // Có ngữ cảnh ("Luật" ... "và"): vẫn cho qua như cũ.
      expect(coachReplyBlock('Luật 9 bi và 10 bi khác nhau.', facts), isNull);
      // Không có ngữ cảnh: số phải qua kiểm tra như mọi số khác.
      expect(coachReplyBlock('Bạn từng ăn 10 bi liên tiếp.', facts), CoachBlockRule.unknownNumber);
      // "110 bi" không được mất chữ số "10" khi không bị xoá.
      expect(coachReplyBlock('Bạn đang có 110 bi trên bàn.', facts), CoachBlockRule.unknownNumber);
      // 8 không nằm trong facts rút gọn này và không có ngữ cảnh đứng trước "8 bi".
      expect(coachReplyBlock('Còn 8 bi trên bàn.', const <String, Object?>{}), CoachBlockRule.unknownNumber);
    });

    test('3. chữ Unicode tổ hợp sẵn (NFD) bị chặn thẳng, không lách được luật ngắm/tối ưu', () {
      // "Ngắm lệch một chút." với "ắ" ở dạng NFD (a + trăng U+0306 + sắc U+0301).
      const decomposedNgam = 'Ngắm lệch một chút.';
      // "Tối ưu." với "ố" ở dạng NFD (o + mũ U+0302 + sắc U+0301).
      const decomposedToiUu = 'Tối ưu.';
      expect(coachReplyBlock(decomposedNgam, facts), CoachBlockRule.decomposed);
      expect(coachReplyBlock(decomposedToiUu, facts), CoachBlockRule.decomposed);
    });

    test('4. số khổng lồ không làm vỡ bộ lọc (không ném lỗi), chỉ bị chặn', () {
      final huge = List.filled(310, '9').join();
      expect(() => coachReplyBlock('Có 1.000.000.000.000.000.000.000 bi.', facts), returnsNormally);
      expect(coachReplyBlock('Có 1.000.000.000.000.000.000.000 bi.', facts), CoachBlockRule.unknownNumber);
      expect(() => coachReplyBlock('Có $huge buổi.', facts), returnsNormally);
      expect(coachReplyBlock('Có $huge buổi.', facts), CoachBlockRule.unknownNumber);
    });
  });

  group('sửa vòng 2 (review)', () {
    const factsWithNineBall = <String, Object?>{
      'skills': {
        'aiming': {'mastery': 62},
      },
      'matches': {
        'last': {'gameType': 'nineBall'},
      },
    };

    test('1. "phần trăm" không phải chữ số "trăm"; số trước nó vẫn kiểm tra như %', () {
      expect(coachReplyBlock('Tỷ lệ thắng 62 phần trăm.', factsWithNineBall), isNull);
    });

    test('2. tên môn chơi dạng enum (nineBall) cho số của môn đó đi qua ở nơi khác trong câu', () {
      expect(coachReplyBlock('Trận gần nhất là 9 bi.', factsWithNineBall), isNull);
      expect(coachReplyBlock('Bạn mạnh nhất ở 9 bi.', factsWithNineBall), isNull);
    });

    test('3. chuỗi ngữ cảnh ván đấu cho phép dấu phẩy, không chỉ "và"/"hay"', () {
      expect(coachReplyBlock('Luật 8 bi, 9 bi và 10 bi khác nhau.', const <String, Object?>{}), isNull);
    });
  });
}
