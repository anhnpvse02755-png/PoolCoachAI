import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('dữ liệu khởi tạo', () {
    test('có đúng 10 bài tập và 6 bài kiến thức', () {
      expect(seedDrills.length, 10);
      expect(seedKnowledge.length, 6);
    });

    test('mã bài tập không trùng nhau', () {
      final ids = seedDrills.map((d) => d.id).toSet();
      expect(ids.length, seedDrills.length);
    });

    test('mỗi bài tập chấm được điểm', () {
      for (final drill in seedDrills) {
        expect(
          drill.passThreshold != null || drill.target != null,
          isTrue,
          reason: 'bài ${drill.id} không có cách chấm điểm',
        );
      }
    });

    test('cấp độ nằm trong 1..5', () {
      for (final drill in seedDrills) {
        expect(drill.level, inInclusiveRange(1, 5), reason: drill.id);
      }
    });

    test('mỗi bài tập có mục tiêu và ít nhất một bước', () {
      for (final drill in seedDrills) {
        expect(drill.goal.trim(), isNotEmpty, reason: drill.id);
        expect(drill.steps, isNotEmpty, reason: drill.id);
      }
    });

    test('không còn thuật ngữ cũ trong bất kỳ bài tập nào', () {
      const banned = [
        'Stop shot',
        'stop shot',
        'dừng bi',
        'Draw',
        'kéo bi',
        'Follow',
        'đẩy bi cái theo',
        'Bi băng',
        'Giao bóng',
        'giao bóng',
        'Đi bi',
        'đi bi',
      ];
      for (final drill in seedDrills) {
        final haystack =
            '${drill.name} ${drill.goal} ${drill.steps.join(' ')}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${drill.id} còn dùng "$term"',
          );
        }
      }
    });

    test('không còn thuật ngữ cũ trong bài kiến thức', () {
      const banned = [
        'Bi băng',
        'Giao bóng',
        'giao bóng',
        'Đi bi',
        'đi bi',
      ];
      for (final article in seedKnowledge) {
        final haystack = '${article.title} ${article.body}';
        for (final term in banned) {
          expect(
            haystack.contains(term),
            isFalse,
            reason: 'bài ${article.id} còn dùng "$term"',
          );
        }
      }
    });

    test('mỗi nhóm kỹ năng có ít nhất một bài tập', () {
      for (final cat in SkillCategory.values) {
        expect(
          seedDrills.any((d) => d.cat == cat),
          isTrue,
          reason: 'nhóm $cat chưa có bài nào',
        );
      }
    });
  });
}
