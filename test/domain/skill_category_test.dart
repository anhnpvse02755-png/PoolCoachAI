import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/skill_category_colors.dart';
import 'package:poolcoachai/domain/skill_category.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  group('SkillCategory', () {
    test('có đúng 9 nhóm, ba nhóm nâng cao đứng cuối', () {
      expect(SkillCategory.values.length, 9);
      expect(SkillCategory.values.where((c) => c.isAdvanced),
          [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe]);
    });

    test('tên tiếng Việt đúng thuật ngữ cơ thủ đã chốt', () {
      expect(Vi.skill(SkillCategory.aiming), 'Ngắm bi');
      expect(Vi.skill(SkillCategory.position), 'Điều bi / Vị trí');
      expect(Vi.skill(SkillCategory.breakShot), 'Phá');
      expect(Vi.skill(SkillCategory.safety), 'Phòng thủ');
      expect(Vi.skill(SkillCategory.kick), 'A băng');
      expect(Vi.skill(SkillCategory.bank), 'Cân bi');
      expect(Vi.skill(SkillCategory.dungCo), 'Dựng cơ');
      expect(Vi.skill(SkillCategory.nhayBi), 'Nhảy bi');
      expect(Vi.skill(SkillCategory.matXe), 'Mát xê');
    });

    test('mỗi nhóm có một màu chữ riêng biệt', () {
      final colors = SkillCategory.values.map((c) => c.fg).toSet();
      expect(colors.length, 9);
    });

    test('chữ trên nền của nhóm nâng cao đủ tương phản (>= 4.5)', () {
      for (final c in SkillCategory.values.where((c) => c.isAdvanced)) {
        expect(contrast(c.fg, c.bg), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });
  });
}
