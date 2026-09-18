import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('SkillCategory', () {
    test('có đúng 6 nhóm', () {
      expect(SkillCategory.values.length, 6);
    });

    test('tên tiếng Việt đúng thuật ngữ cơ thủ đã chốt', () {
      expect(Vi.skill(SkillCategory.aiming), 'Ngắm bi');
      expect(Vi.skill(SkillCategory.position), 'Điều bi / Vị trí');
      expect(Vi.skill(SkillCategory.breakShot), 'Phá');
      expect(Vi.skill(SkillCategory.safety), 'Phòng thủ');
      expect(Vi.skill(SkillCategory.kick), 'A băng');
      expect(Vi.skill(SkillCategory.bank), 'Cân bi');
    });

    test('mỗi nhóm có một màu chữ riêng biệt', () {
      final colors = SkillCategory.values.map((c) => c.fg).toSet();
      expect(colors.length, 6);
    });
  });
}
