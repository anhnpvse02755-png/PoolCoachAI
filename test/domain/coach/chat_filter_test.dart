import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/coach/chat_filter.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart' show ThicknessSide;

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

  group('review cuối', () {
    // Facts của người chơi mới: mọi con số chỉ là 0, 3, 35, 55 và 75.
    const newPlayerFacts = <String, Object?>{
      'skills': {
        'aiming': {'mastery': null, 'trend': 'notEnoughData', 'sessions': 0},
      },
      'skillLevels': {'weak': <String>[], 'strong': <String>[], 'weakBelow': 55, 'strongFrom': 75, 'minSessions': 3},
      'today': {'category': 'aiming', 'reason': 'newcomer', 'streak': 0, 'practiceMinutesThisWeek': 35},
    };

    test('facts người mới cho phép đúng 0, 3, 35, 55, 75', () {
      expect(coachAllowedNumbers(newPlayerFacts), {0, 3000, 35000, 55000, 75000});
    });

    group('I2b. danh sách đánh số và "bi-a"', () {
      test('danh sách đánh số đầu dòng cho qua với facts người mới', () {
        expect(
          coachReplyBlock(
            'Bạn mới bắt đầu, nên:\n'
            '1. Ghi vài buổi Ngắm bi.\n'
            '2. Chơi một trận rồi ghi lại.\n'
            '3. Làm một tình huống Coach.',
            newPlayerFacts,
          ),
          isNull,
        );
        expect(coachReplyBlock('Gợi ý:\n  1) Tập Ngắm bi.\n  2) Tập Phòng thủ.', newPlayerFacts), isNull);
        expect(coachReplyBlock('9. Tập Ngắm bi.\n10. Tập Phòng thủ.', newPlayerFacts), isNull);
      });

      test('"1." giữa câu không phải dấu đầu dòng: vẫn bị kiểm tra', () {
        expect(coachReplyBlock('Bạn đang đứng thứ 1. Cố giữ nhé.', newPlayerFacts), CoachBlockRule.unknownNumber);
        expect(coachReplyBlock('Nên tập:\n1.5 giờ mỗi buổi.', newPlayerFacts), CoachBlockRule.unknownNumber);
      });

      test('số bịa trong một mục của danh sách vẫn bị chặn', () {
        expect(
          coachReplyBlock('Kế hoạch:\n1. Tập 5 buổi Ngắm bi.\n2. Chơi một trận.', newPlayerFacts),
          CoachBlockRule.unknownNumber,
        );
      });

      test('"bi-a" là ngữ cảnh ván đấu: "bi-a 9 bi" cho qua', () {
        expect(coachReplyBlock('Bạn đang tập bi-a 9 bi.', newPlayerFacts), isNull);
        expect(coachReplyBlock('Bi-a 9 bi cần Phòng thủ tốt.', newPlayerFacts), isNull);
      });

      test('"trong" không phải ngữ cảnh ván đấu: mẫu số bịa vẫn bị chặn', () {
        expect(coachReplyBlock('Bạn ăn 3 trong 9 bi.', newPlayerFacts), CoachBlockRule.unknownNumber);
      });
    });

    group('M1. chữ số không phải ASCII và ký tự vô hình', () {
      for (final (name, text) in [
        ('"３０ độ" (chữ số toàn chiều rộng)', 'Cắt góc \uFF13\uFF10 độ.'),
        ('"٣٠ độ" (chữ số Ả Rập)', '\u0663\u0660 độ'),
        ('"𝟑𝟎 độ" (chữ số toán học đậm)', '\u{1D7D1}\u{1D7CE} độ'),
        ('"１００ cú" (toàn chiều rộng, không có "độ")', '\uFF11\uFF10\uFF10 cú'),
        ('"③ buổi" (số trong vòng tròn)', 'Tập \u2462 buổi mỗi tuần.'),
        ('"½ độ" (phân số ngoài "N bi")', 'Cắt góc ½ độ.'),
      ]) {
        test('$name bị chặn (fail closed)', () {
          expect(coachReplyBlock(text, facts), CoachBlockRule.unknownNumber);
        });
      }

      test('độ dày chạm bi "¾ / ½ / ¼ / ⅛ bi" (chữ của app) vẫn cho qua', () {
        for (final f in ['¾', '½', '¼', '⅛']) {
          expect(coachReplyBlock('Ăn $f bi, lệch bên phải.', facts), isNull, reason: f);
        }
      });

      test('ký tự vô hình THAY dấu cách hay CHEN giữa chữ không lách được luật chữ', () {
        expect(coachReplyBlock('Cách tối\u200Bưu là đánh trô bi.', facts), CoachBlockRule.optimal);
        expect(coachReplyBlock('Cách tối ư\u00ADu là đánh trô bi.', facts), CoachBlockRule.optimal);
        expect(coachReplyBlock('Ngắm l\u2060ệch một chút.', facts), CoachBlockRule.aimShift);
        expect(coachReplyBlock('Dùng B\u200DHE.', facts), CoachBlockRule.spinRatio);
        expect(coachReplyBlock('Góc 30\u200Bđộ.', facts), CoachBlockRule.degree);
        // 4 và 7 có trong facts, 47 thì không.
        expect(coachReplyBlock('Bạn đã thắng 4\u200C7 trận.', facts), CoachBlockRule.unknownNumber);
        // Xoá ký tự vô hình thì "haimươi" lọt luật chữ số; đọc thêm bản thay
        // bằng dấu cách ("hai mươi") mới chặn được.
        expect(coachReplyBlock('Bạn đã tập hai\u200Bmươi buổi.', facts), CoachBlockRule.unknownNumber);
      });

      test('khoảng trắng không ngắt dòng (U+00A0, U+202F, U+2007) đọc như dấu cách', () {
        expect(coachReplyBlock('Cách tối\u00A0ưu là đánh trô bi.', facts), CoachBlockRule.optimal);
        expect(coachReplyBlock('Đừng lệch\u202Fđiểm ngắm.', facts), CoachBlockRule.aimShift);
        expect(coachReplyBlock('Có 5\u2007nhóm cần xem.', facts), isNull);
      });

      test('câu chỉ có ký tự vô hình là câu rỗng', () {
        expect(coachReplyBlock('\u200B\u200B', facts), CoachBlockRule.empty);
        expect(filterCoachReply('\u200B\u2060', facts), (text: '', insufficient: true));
      });
    });

    group('M2. lượng áp phê bằng đầu cơ', () {
      test('"Áp phê phải 1 đầu cơ" bị chặn như spinRatio', () {
        expect(coachReplyBlock('Áp phê phải 1 đầu cơ.', const <String, Object?>{}), CoachBlockRule.spinRatio);
      });

      test('vẫn bị chặn khi con số có trong facts', () {
        // 2 có trong facts (sessions của safety).
        expect(coachReplyBlock('Áp phê trái 2 đầu cơ là đủ.', facts), CoachBlockRule.spinRatio);
        expect(coachReplyBlock('Lệch 0,62 đầu gậy.', facts), CoachBlockRule.spinRatio);
      });

      test('thứ tự luật F11: độ trước, rồi ngắm lệch, rồi mới tới đầu cơ', () {
        expect(coachReplyBlock('Cắt 30 độ, áp phê 1 đầu cơ.', facts), CoachBlockRule.degree);
        expect(coachReplyBlock('Ngắm lệch 1 đầu cơ.', facts), CoachBlockRule.aimShift);
      });

      test('"đầu cơ" không kèm số vẫn cho qua', () {
        expect(coachReplyBlock('Nhớ bảo dưỡng đầu cơ trước giải.', facts), isNull);
      });
    });

    test('M8. "triệu chứng" không phải số; "hàng chục", "hàng triệu" vẫn bị chặn', () {
      expect(coachReplyBlock('Triệu chứng: bi cái hay bị trôi sau cú đánh.', facts), isNull);
      expect(coachReplyBlock('Bạn đã tập hàng chục buổi.', facts), CoachBlockRule.unknownNumber);
      expect(coachReplyBlock('Có hàng triệu cách tập.', facts), CoachBlockRule.unknownNumber);
    });

    test('chuỗi Vi của huấn luyện viên vẫn cho qua bộ lọc chat', () {
      final lines = [
        ...Vi.coachChatSamples,
        Vi.coachChatInsufficient,
        Vi.coachChatInsufficientHint,
        Vi.coachChatDisclaimer,
        Vi.coachChatQuotaOut,
        Vi.coachChatRemaining(5),
        Vi.coachChatThinking,
        Vi.safetyThickness(1, ThicknessSide.full),
        for (final t in [0.75, 0.5, 0.25, 0.125])
          for (final side in [ThicknessSide.left, ThicknessSide.right]) Vi.safetyThickness(t, side),
      ];
      for (final line in lines) {
        // facts mang chính các số của câu: chỉ còn luật chữ và luật ký tự được thử.
        expect(coachReplyBlock(line, {'line': line}), isNull, reason: line);
      }
    });

    group('vòng sửa cuối', () {
      test('"lựa chọn", "phương án" là từ chỉ số lượng: cho qua với facts người mới', () {
        expect(coachReplyBlock('Bạn có 2 lựa chọn:', newPlayerFacts), isNull);
        expect(coachReplyBlock('Có 2 phương án', newPlayerFacts), isNull);
        expect(
          coachReplyBlock('Bạn có 2 lựa chọn:\n1. Tập Ngắm bi.\n2. Tập Phòng thủ.', newPlayerFacts),
          isNull,
        );
      });

      test('"bước" không phải từ chỉ số lượng: "2 bước" nói về dữ liệu Lộ trình, vẫn bị chặn', () {
        expect(coachReplyBlock('Bạn đã xong 2 bước của Lộ trình.', newPlayerFacts), CoachBlockRule.unknownNumber);
      });

      test('"nửa đầu cơ" là lượng áp phê: bị chặn như spinRatio', () {
        expect(coachReplyBlock('Áp phê trái nửa đầu cơ.', newPlayerFacts), CoachBlockRule.spinRatio);
        expect(coachReplyBlock('Nửa đầu gậy là đủ.', newPlayerFacts), CoachBlockRule.spinRatio);
      });

      test('độ dày chạm bi vẫn cho qua: "Ăn ½ bi", "Ăn nửa bi", "Ăn trọn bi"', () {
        for (final text in ['Ăn ½ bi, lệch bên trái.', 'Ăn nửa bi, lệch bên phải.', 'Ăn trọn bi.', 'Ăn ¼ bi.']) {
          expect(coachReplyBlock(text, newPlayerFacts), isNull, reason: text);
        }
      });
    });
  });
}
