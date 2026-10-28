import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final at = DateTime(2026, 10, 15, 9);
  final goal = GoalRecord(
    updatedAt: at,
    goal: PlayerGoal(
        goalId: 'g1', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), createdAt: at),
  );

  test('mục tiêu qua dòng Drift rồi về nguyên vẹn', () {
    expect(toGoalRecord(toGoalRow(goal, userId: 'u1')), goal);
    final dropped = GoalRecord(updatedAt: at);
    expect(toGoalRecord(toGoalRow(dropped, userId: 'u1')), dropped);
  });

  test('mục tiêu qua Directus rồi về nguyên vẹn; id là id người dùng', () {
    final skill = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.bank, createdAt: at),
    );
    final json = toRemoteGoal(toGoalRow(skill, userId: 'u1'));
    expect(json['id'], 'u1');
    expect(json['kind'], 'thuanThucKyNang');
    expect(json['category'], 'bank');
    expect(goalFromRemote(json), skill);
    expect(goalFromRemote(toRemoteGoal(toGoalRow(GoalRecord(updatedAt: at), userId: 'u1'))).goal, isNull);
  });

  test('hai máy cùng người cùng thành tích ra cùng id', () {
    final a = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at);
    final b = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at.add(const Duration(days: 1)));
    expect(achievementId('u1', a), achievementId('u1', b));
    expect(achievementId('u1', a), isNot(achievementId('u2', a)));
    expect(achievementId('u1', a), isNot(achievementId('u1',
        Achievement(kind: AchievementKind.chuoiNgay, refId: '14', achievedAt: at))));
  });

  test('thành tích qua Drift và Directus rồi về nguyên vẹn', () {
    final a = Achievement(kind: AchievementKind.xongBuoc, refId: 'g1:aiming', achievedAt: at);
    final row = toAchievementRow(a, userId: 'u1');
    expect(toAchievement(row), a);
    final back = achievementFromRemote(toRemoteAchievement(row), userId: 'u1', syncedAt: at);
    expect(toAchievement(back), a);
    expect(back.syncedAt, at);
    expect(back.id, row.id);
  });

  test('mục tiêu có hạng đích qua Drift và Directus rồi về nguyên vẹn', () {
    final target = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g3', kind: GoalKind.lenHang, createdAt: at, targetRank: Rank.d),
    );
    final row = toGoalRow(target, userId: 'u1');
    expect(row.targetRank, 'd');
    expect(toGoalRecord(row), target);
    final json = toRemoteGoal(row);
    expect(json['target_rank'], 'd');
    expect(goalFromRemote(json), target);
    expect(remoteGoalFields, contains('target_rank'));
  });

  test('máy chủ cũ không có target_rank thì coi là null', () {
    final json = toRemoteGoal(toGoalRow(
      GoalRecord(updatedAt: at, goal: PlayerGoal(goalId: 'g4', kind: GoalKind.lenHang, createdAt: at)),
      userId: 'u1',
    ))..remove('target_rank');
    expect(goalFromRemote(json).goal!.targetRank, isNull);
  });

  test('target_rank thừa ở dòng không phải Lên hạng bị bỏ qua', () {
    final json = toRemoteGoal(toGoalRow(
      GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(goalId: 'g5', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: at),
      ),
      userId: 'u1',
    ))..['target_rank'] = 'd';
    final goal = goalFromRemote(json).goal!;
    expect(goal.kind, GoalKind.thuanThucKyNang);
    expect(goal.targetRank, isNull);
  });
}
