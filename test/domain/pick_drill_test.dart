import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

Drill _drill(String id, int level) => Drill(
      id: id,
      cat: SkillCategory.aiming,
      name: 'Bài $id',
      level: level,
      unit: 'lần trúng / 10',
      goal: 'g',
      steps: const ['s'],
      passThreshold: 0.8,
    );

DrillLog _log(String drillId, num score) => DrillLog(
      id: '$drillId-log',
      drillId: drillId,
      date: DateTime(2026, 9, 1),
      score: score,
      attempts: 10,
    );

void main() {
  group('pickDrillInCategory', () {
    final low = _drill('a', 1);
    final high = _drill('b', 3);

    test('ưu tiên bài chưa từng tập, cấp thấp trước', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [high, low],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'a');
    });

    test('bài lần gần nhất chưa đạt thì vẫn cần tập lại', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: {
          'a': [_log('a', 4)],
        },
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'a');
    });

    test('đã đạt hết thì ôn bài cấp cao nhất', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: {
          'a': [_log('a', 10)],
          'b': [_log('b', 10)],
        },
        excludeDrillIds: const {},
      );

      expect(picked?.id, 'b');
    });

    test('không gợi ý lại bài đã tập hôm nay', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.aiming,
        drills: [low, high],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {'a'},
      );

      expect(picked?.id, 'b');
    });

    test('nhóm không còn bài nào thì trả null', () {
      final picked = pickDrillInCategory(
        cat: SkillCategory.safety,
        drills: [low, high],
        logsByDrillOldestFirst: const {},
        excludeDrillIds: const {},
      );

      expect(picked, isNull);
    });
  });
}
