import 'package:poolcoachai/domain/skill_category.dart';

/// Bốn nhóm có tình huống (spec mục 8.1). Phá và Cân bi không có: Planner
/// không tính những cú đó.
enum CoachTopic { aiming, position, safety, kick }

/// Nhóm tình huống của một nhóm kỹ năng; null khi nhóm đó chưa có tình huống.
CoachTopic? coachTopicOf(SkillCategory cat) => switch (cat) {
      SkillCategory.aiming => CoachTopic.aiming,
      SkillCategory.position => CoachTopic.position,
      SkillCategory.safety => CoachTopic.safety,
      SkillCategory.kick => CoachTopic.kick,
      SkillCategory.breakShot ||
      SkillCategory.bank ||
      SkillCategory.dungCo ||
      SkillCategory.nhayBi ||
      SkillCategory.matXe =>
        null,
    };

SkillCategory categoryOf(CoachTopic topic) => switch (topic) {
      CoachTopic.aiming => SkillCategory.aiming,
      CoachTopic.position => SkillCategory.position,
      CoachTopic.safety => SkillCategory.safety,
      CoachTopic.kick => SkillCategory.kick,
    };
