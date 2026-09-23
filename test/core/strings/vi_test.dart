import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/recommendation.dart';

void main() {
  group('Vi', () {
    test('nhãn 5 tab đúng như thiết kế', () {
      expect(Vi.tabHome, 'Trang chủ');
      expect(Vi.tabTraining, 'Luyện tập');
      expect(Vi.tabPlay, 'Thi đấu');
      expect(Vi.tabStats, 'Thống kê');
      expect(Vi.tabProfile, 'Hồ sơ');
    });

    test('không có nhãn tab nào bị rỗng', () {
      final labels = [
        Vi.tabHome,
        Vi.tabTraining,
        Vi.tabPlay,
        Vi.tabStats,
        Vi.tabProfile,
      ];
      for (final label in labels) {
        expect(label.trim(), isNotEmpty);
      }
    });

    test('tên app giữ nguyên, không dịch', () {
      expect(Vi.appName, 'PoolCoachAI');
    });
  });

  // Sáu lý do chọn nhóm kỹ năng phải ra sáu câu khác nhau.
  //
  // Đây là chỗ dễ hỏng nhất về mặt sản phẩm: nếu hai lý do dùng chung
  // một câu thì người chơi đọc mãi vẫn không biết vì sao hôm nay lại
  // là nhóm này, và lớp suy luận coi như nói mà không ai nghe.
  group('Vi.pickReason', () {
    test('mỗi lý do một câu riêng, không lý do nào dùng chung câu', () {
      final sentences =
          PickReason.values.map((r) => Vi.pickReason(r, 'Ngắm bi')).toSet();
      expect(sentences.length, PickReason.values.length);
    });

    test('câu nào cũng gọi đúng tên nhóm kỹ năng được truyền vào', () {
      for (final reason in PickReason.values) {
        expect(Vi.pickReason(reason, 'Cân bi'), contains('Cân bi'),
            reason: reason.name);
      }
    });

    test('đúng khuôn câu đã chốt ở mục 6.1 của thiết kế', () {
      expect(
        Vi.pickReason(PickReason.scheduled, 'Phá'),
        'Lịch tập hôm nay của bạn là Phá.',
      );
      expect(
        Vi.pickReason(PickReason.streakAtRisk, 'Phá'),
        'Hai hôm rồi bạn chưa tập. Quay lại nhẹ nhàng với Phá.',
      );
      expect(
        Vi.pickReason(PickReason.weakest, 'Phá'),
        'Phá đang là nhóm yếu nhất của bạn.',
      );
      expect(
        Vi.pickReason(PickReason.newcomer, 'Phá'),
        'Bắt đầu với Phá — nền của mọi cú đánh.',
      );
      expect(
        Vi.pickReason(PickReason.declining, 'Phá'),
        'Phá đang đi xuống. Ôn lại trước khi thành điểm yếu.',
      );
      expect(
        Vi.pickReason(PickReason.rotation, 'Phá'),
        'Đã lâu bạn chưa tập Phá.',
      );
    });
  });
}
