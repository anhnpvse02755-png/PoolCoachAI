import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  test('bốn nhóm có tình huống, Phá và Cân bi thì không; hai chiều khớp nhau', () {
    expect(coachTopicOf(SkillCategory.breakShot), isNull);
    expect(coachTopicOf(SkillCategory.bank), isNull);
    for (final t in CoachTopic.values) {
      expect(coachTopicOf(categoryOf(t)), t);
    }
    expect(SkillCategory.values.where((c) => coachTopicOf(c) != null), hasLength(4));
  });

  CategoryInsight at(int? mastery) =>
      CategoryInsight(mastery: mastery, trend: SkillTrend.flat, sessionCount: 5);

  test('độ khó chọn sẵn theo hai ngưỡng sẵn có của lớp suy luận', () {
    expect(coachDifficultyFor(null), CoachDifficulty.easy);
    expect(coachDifficultyFor(at(null)), CoachDifficulty.easy);
    expect(coachDifficultyFor(at(PracticeConstants.weakCutoff - 1)), CoachDifficulty.easy);
    expect(coachDifficultyFor(at(PracticeConstants.weakCutoff)), CoachDifficulty.medium);
    expect(coachDifficultyFor(at(PracticeConstants.strongCutoff - 1)), CoachDifficulty.medium);
    expect(coachDifficultyFor(at(PracticeConstants.strongCutoff)), CoachDifficulty.hard);
    expect(coachDifficultyFor(at(100)), CoachDifficulty.hard);
  });

  test('số bi tăng theo độ khó, không chồng lấn', () {
    var lastMax = 0;
    for (final d in CoachDifficulty.values) {
      final c = coachBallCount(d);
      expect(c.min, greaterThan(lastMax));
      expect(c.max, greaterThanOrEqualTo(c.min));
      lastMax = c.max;
    }
  });

  test('khoá tình huống ổn định', () {
    expect(generatedKey(CoachTopic.position, CoachDifficulty.medium, 123456),
        'gen-v1-position-medium-123456');
    expect(libraryKey('pos-rail-1'), 'lib:pos-rail-1');
  });
}
