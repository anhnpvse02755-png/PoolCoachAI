import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:uuid/uuid.dart';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _local(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();

GoalRecord toGoalRecord(PlayerGoalRow r) => GoalRecord(
      updatedAt: r.updatedAt,
      goal: r.kind == null
          ? null
          : PlayerGoal(
              goalId: r.goalId!,
              kind: GoalKind.values.byName(r.kind!),
              category: r.category == null ? null : SkillCategory.values.byName(r.category!),
              eventDate: r.eventDate,
              createdAt: r.createdAt!,
              targetRank: r.targetRank == null ? null : Rank.values.byName(r.targetRank!),
            ),
    );

PlayerGoalRow toGoalRow(GoalRecord g, {required String userId, DateTime? syncedAt}) => PlayerGoalRow(
      userId: userId,
      goalId: g.goal?.goalId,
      kind: g.goal?.kind.name,
      category: g.goal?.category?.name,
      eventDate: g.goal?.eventDate,
      createdAt: g.goal?.createdAt,
      targetRank: g.goal?.targetRank?.name,
      updatedAt: g.updatedAt,
      syncedAt: syncedAt,
    );

const remoteGoalFields = 'id,goal_id,kind,category,event_date,created_at,updated_at,target_rank';

/// Dòng mục tiêu cho `POST /items/player_goals` (id là id người dùng, R1).
Map<String, Object?> toRemoteGoal(PlayerGoalRow r) => {
      'id': r.userId,
      'goal_id': r.goalId,
      'kind': r.kind,
      'category': r.category,
      'event_date': _iso(r.eventDate),
      'target_rank': r.targetRank,
      'created_at': _iso(r.createdAt),
      'updated_at': _iso(r.updatedAt),
    };

GoalRecord goalFromRemote(Map<String, Object?> j) => GoalRecord(
      updatedAt: _local(j['updated_at'])!,
      goal: j['kind'] == null
          ? null
          : PlayerGoal(
              goalId: j['goal_id']! as String,
              kind: GoalKind.values.byName(j['kind']! as String),
              category: j['category'] == null ? null : SkillCategory.values.byName(j['category']! as String),
              eventDate: _local(j['event_date']),
              createdAt: _local(j['created_at'])!,
              // Máy cũ có thể để target_rank thừa ở dòng không phải Lên hạng.
              targetRank: j['kind'] == GoalKind.lenHang.name && j['target_rank'] != null
                  ? Rank.values.byName(j['target_rank']! as String)
                  : null,
            ),
    );

/// Cùng người, cùng loại, cùng refId thì cùng id, trên mọi máy (R8).
String achievementId(String userId, Achievement a) => const Uuid()
    .v5(Namespace.url.value, 'poolcoachai:achievement:$userId:${a.kind.name}:${a.refId}');

Achievement toAchievement(AchievementRow r) => Achievement(
      kind: AchievementKind.values.byName(r.kind),
      refId: r.refId,
      achievedAt: r.achievedAt,
    );

AchievementRow toAchievementRow(Achievement a, {required String userId, DateTime? syncedAt}) =>
    AchievementRow(
      id: achievementId(userId, a),
      userId: userId,
      kind: a.kind.name,
      refId: a.refId,
      achievedAt: a.achievedAt,
      syncedAt: syncedAt,
    );

const remoteAchievementFields = 'id,kind,ref_id,achieved_at';

Map<String, Object?> toRemoteAchievement(AchievementRow r) => {
      'id': r.id,
      'kind': r.kind,
      'ref_id': r.refId,
      'achieved_at': _iso(r.achievedAt),
    };

AchievementRow achievementFromRemote(
  Map<String, Object?> j, {
  required String userId,
  required DateTime syncedAt,
}) =>
    AchievementRow(
      id: j['id']! as String,
      userId: userId,
      kind: j['kind']! as String,
      refId: j['ref_id']! as String,
      achievedAt: _local(j['achieved_at'])!,
      syncedAt: syncedAt,
    );
