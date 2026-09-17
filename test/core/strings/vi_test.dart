import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';

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
}
