import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
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
      goalId: 'g1',
      kind: GoalKind.chuanBiGiai,
      eventDate: DateTime(2026, 11, 2),
      createdAt: at,
    ),
  );

  test('mục tiêu qua dòng Drift rồi về nguyên vẹn', () {
    expect(toGoalRecord(toGoalRow(goal, userId: 'u1')), goal);
    final dropped = GoalRecord(updatedAt: at);
    expect(toGoalRecord(toGoalRow(dropped, userId: 'u1')), dropped);
  });

  test('mục tiêu qua Directus rồi về nguyên vẹn; id là id người dùng', () {
    final skill = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(
        goalId: 'g2',
        kind: GoalKind.thuanThucKyNang,
        category: SkillCategory.bank,
        createdAt: at,
      ),
    );
    final json = toRemoteGoal(toGoalRow(skill, userId: 'u1'));
    expect(json['id'], 'u1');
    expect(json['kind'], 'thuanThucKyNang');
    expect(json['category'], 'bank');
    expect(goalFromRemote(json), skill);
    expect(
      goalFromRemote(
        toRemoteGoal(toGoalRow(GoalRecord(updatedAt: at), userId: 'u1')),
      ).goal,
      isNull,
    );
  });

  group('nhóm nâng cao: kind, category chỉ chở tên bản cũ đọc được', () {
    final nhayBi = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(
        goalId: 'g3',
        kind: GoalKind.thuanThucKyNang,
        category: SkillCategory.nhayBi,
        createdAt: at,
      ),
    );

    test(
      'mục tiêu Thuần thục Nhảy bi: kind, category rỗng; category_ext nhayBi; đọc lại đúng mục tiêu',
      () {
        final json = toRemoteGoal(toGoalRow(nhayBi, userId: 'u1'));
        expect(json['kind'], isNull);
        expect(json['category'], isNull);
        expect(json['category_ext'], 'nhayBi');
        expect(json['goal_id'], 'g3');
        expect(goalFromRemote(json), nhayBi);
        expect(remoteGoalFields.split(','), contains('category_ext'));
      },
    );

    test('mục tiêu kiểu khác vẫn gửi kind như cũ, category_ext null', () {
      for (final g in [
        goal,
        GoalRecord(
          updatedAt: at,
          goal: PlayerGoal(
            goalId: 'g4',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.aiming,
            createdAt: at,
          ),
        ),
      ]) {
        final json = toRemoteGoal(toGoalRow(g, userId: 'u1'));
        expect(json['kind'], g.goal!.kind.name);
        expect(json['category_ext'], isNull);
        expect(goalFromRemote(json), g);
      }
    });

    final base = toRemoteGoal(toGoalRow(nhayBi, userId: 'u1'));

    test('bản cũ đặt Lên hạng sau đó (category_ext còn sót): đọc ra Lên hạng, không nhóm', () {
      final r = goalFromRemote({
        ...base,
        'goal_id': 'g5',
        'kind': 'lenHang',
        'category': null,
        'target_rank': null,
      });
      expect(r.goal!.kind, GoalKind.lenHang);
      expect(r.goal!.category, isNull);
    });

    test('bản cũ bỏ mục tiêu (kind, goal_id rỗng, category_ext còn sót): không có mục tiêu', () {
      final r = goalFromRemote({...base, 'goal_id': null, 'kind': null});
      expect(r.goal, isNull);
    });

    test('bản cũ chọn Thuần thục Ngắm bi (category_ext còn sót): đọc ra Ngắm bi', () {
      final r = goalFromRemote({
        ...base,
        'goal_id': 'g6',
        'kind': 'thuanThucKyNang',
        'category': 'aiming',
      });
      expect(r.goal!.category, SkillCategory.aiming);
    });

    test('category_ext là tên lạ của bản sau: không có mục tiêu, không ném', () {
      expect(goalFromRemote({...base, 'category_ext': 'nhomTuongLai'}).goal, isNull);
    });

    test('category_ext sai kiểu: ném', () {
      expect(() => goalFromRemote({...base, 'category_ext': 3}), throwsFormatException);
    });
  });

  test('hai máy cùng người cùng thành tích ra cùng id', () {
    final a = Achievement(
      kind: AchievementKind.chuoiNgay,
      refId: '7',
      achievedAt: at,
    );
    final b = Achievement(
      kind: AchievementKind.chuoiNgay,
      refId: '7',
      achievedAt: at.add(const Duration(days: 1)),
    );
    expect(achievementId('u1', a), achievementId('u1', b));
    expect(achievementId('u1', a), isNot(achievementId('u2', a)));
    expect(
      achievementId('u1', a),
      isNot(
        achievementId(
          'u1',
          Achievement(
            kind: AchievementKind.chuoiNgay,
            refId: '14',
            achievedAt: at,
          ),
        ),
      ),
    );
  });

  test('thành tích qua Drift và Directus rồi về nguyên vẹn', () {
    final a = Achievement(
      kind: AchievementKind.xongBuoc,
      refId: 'g1:aiming',
      achievedAt: at,
    );
    final row = toAchievementRow(a, userId: 'u1');
    expect(toAchievement(row), a);
    final back = achievementFromRemote(
      toRemoteAchievement(row),
      userId: 'u1',
      syncedAt: at,
    )!;
    expect(toAchievement(back), a);
    expect(back.syncedAt, at);
    expect(back.id, row.id);
  });

  test(
    'chứng nhận: hai máy cùng người ra cùng id, qua Directus về nguyên vẹn',
    () {
      final a = Achievement(
        kind: AchievementKind.chungNhan,
        refId: 'd1',
        achievedAt: at,
      );
      final b = Achievement(
        kind: AchievementKind.chungNhan,
        refId: 'd1',
        achievedAt: at.add(const Duration(hours: 3)),
      );
      expect(achievementId('u1', a), achievementId('u1', b));
      final row = toAchievementRow(a, userId: 'u1');
      expect(
        toAchievement(
          achievementFromRemote(
            toRemoteAchievement(row),
            userId: 'u1',
            syncedAt: at,
          )!,
        ),
        a,
      );
    },
  );

  test('loại thành tích lạ (máy chủ mới hơn) bị bỏ qua, không ném', () {
    final row = toAchievementRow(
      Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at),
      userId: 'u1',
    );
    final unknown = AchievementRow(
      id: 'x',
      userId: 'u1',
      kind: 'zzz',
      refId: 'r',
      achievedAt: at,
    );
    expect(toAchievement(unknown), isNull);
    expect(
      achievementFromRemote(
        {...toRemoteAchievement(row), 'kind': 'zzz'},
        userId: 'u1',
        syncedAt: at,
      ),
      isNull,
    );
    expect(
      achievementFromRemote(
        toRemoteAchievement(row),
        userId: 'u1',
        syncedAt: at,
      ),
      isNotNull,
    );
  });

  test('mục tiêu có hạng đích qua Drift và Directus rồi về nguyên vẹn', () {
    final target = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(
        goalId: 'g3',
        kind: GoalKind.lenHang,
        createdAt: at,
        targetRank: Rank.d,
      ),
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
    final json = toRemoteGoal(
      toGoalRow(
        GoalRecord(
          updatedAt: at,
          goal: PlayerGoal(goalId: 'g4', kind: GoalKind.lenHang, createdAt: at),
        ),
        userId: 'u1',
      ),
    )..remove('target_rank');
    expect(goalFromRemote(json).goal!.targetRank, isNull);
  });

  test('target_rank thừa ở dòng không phải Lên hạng bị bỏ qua', () {
    final json = toRemoteGoal(
      toGoalRow(
        GoalRecord(
          updatedAt: at,
          goal: PlayerGoal(
            goalId: 'g5',
            kind: GoalKind.thuanThucKyNang,
            category: SkillCategory.aiming,
            createdAt: at,
          ),
        ),
        userId: 'u1',
      ),
    )..['target_rank'] = 'd';
    final goal = goalFromRemote(json).goal!;
    expect(goal.kind, GoalKind.thuanThucKyNang);
    expect(goal.targetRank, isNull);
  });

  test('target_rank lạ (máy chủ mới hơn) coi là null, không ném', () {
    final lenHang = toRemoteGoal(
      toGoalRow(
        GoalRecord(
          updatedAt: at,
          goal: PlayerGoal(goalId: 'g6', kind: GoalKind.lenHang, createdAt: at),
        ),
        userId: 'u1',
      ),
    )..['target_rank'] = 'xyz';
    expect(goalFromRemote(lenHang).goal!.targetRank, isNull);

    final row = toGoalRow(
      GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(goalId: 'g7', kind: GoalKind.lenHang, createdAt: at),
      ),
      userId: 'u1',
    ).copyWith(targetRank: const Value('xyz'));
    expect(toGoalRecord(row).goal!.targetRank, isNull);
  });

  test('mục tiêu nối giải đi Drift và Directus rồi về nguyên vẹn', () {
    final linked = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(
        goalId: 'g9',
        kind: GoalKind.chuanBiGiai,
        eventDate: DateTime(2026, 11, 2),
        createdAt: at,
        tournamentId: 't1',
      ),
    );
    expect(toGoalRecord(toGoalRow(linked, userId: 'u1')), linked);
    final json = toRemoteGoal(toGoalRow(linked, userId: 'u1'));
    expect(json['tournament_id'], 't1');
    expect(goalFromRemote(json), linked);
  });

  test('goalFromRemote giữ tournament_id nguyên văn cả với mục tiêu không phải chuanBiGiai', () {
    final stale = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(
        goalId: 'g10',
        kind: GoalKind.lenHang,
        createdAt: at,
        tournamentId: 'stale',
      ),
    );
    final json = toRemoteGoal(toGoalRow(stale, userId: 'u1'));
    expect(json['tournament_id'], 'stale');
    expect(goalFromRemote(json).goal!.tournamentId, 'stale');
  });

  test(
    'luôn gửi khoá tournament_id, kể cả null, để xoá liên kết cũ trên máy chủ',
    () {
      expect(
        toRemoteGoal(toGoalRow(goal, userId: 'u1')),
        containsPair('tournament_id', null),
      );
      expect(remoteGoalFields.split(','), contains('tournament_id'));
    },
  );
}
