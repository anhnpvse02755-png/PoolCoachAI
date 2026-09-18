import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';

void main() {
  group('categoryMastery', () {
    test('trả null khi chưa đủ số buổi tối thiểu', () {
      expect(categoryMastery([1.0, 1.0]), isNull);
    });

    test('toàn buổi đạt đúng mục tiêu cho 100', () {
      expect(categoryMastery([1.0, 1.0, 1.0]), 100);
    });

    test('bị chặn trên ở 100 dù có buổi vượt mục tiêu', () {
      expect(categoryMastery([1.2, 1.2, 1.2]), 100);
    });

    test('buổi mới có trọng số cao hơn buổi cũ', () {
      // Cùng bộ số, đảo thứ tự: bản có buổi tốt ở cuối phải cao hơn.
      final improving = categoryMastery([0.4, 0.6, 1.0])!;
      final declining = categoryMastery([1.0, 0.6, 0.4])!;
      expect(improving, greaterThan(declining));
    });

    test('một buổi ăn may bị chặn ở trần 1.2', () {
      final capped = categoryMastery([0.5, 0.5, 5.0])!;
      final atCap = categoryMastery([0.5, 0.5, 1.2])!;
      expect(capped, atCap);
    });
  });

  group('categoryTrend', () {
    test('cần ít nhất 4 buổi mới dám kết luận xu hướng', () {
      expect(categoryTrend([0.2, 0.5, 0.9]), SkillTrend.notEnoughData);
    });

    test('nửa sau tốt hơn hẳn nửa trước là đi lên', () {
      expect(categoryTrend([0.3, 0.3, 0.9, 0.9]), SkillTrend.up);
    });

    test('nửa sau kém hơn hẳn nửa trước là đi xuống', () {
      expect(categoryTrend([0.9, 0.9, 0.3, 0.3]), SkillTrend.down);
    });

    test('chênh lệch nhỏ hơn ngưỡng là đi ngang', () {
      expect(categoryTrend([0.5, 0.5, 0.55, 0.55]), SkillTrend.flat);
    });
  });
}
