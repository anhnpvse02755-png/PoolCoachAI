import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final t1 = DateTime(2026, 10, 15, 9);
  final t2 = DateTime(2026, 10, 15, 10);

  PlayerGoal skill(String id) => PlayerGoal(
      goalId: id, kind: GoalKind.thuanThucKyNang, category: SkillCategory.safety, createdAt: t1);

  group('mergeGoal — bản sửa mới nhất thắng (spec mục 6)', () {
    test('một bên trống thì lấy bên còn lại', () {
      final r = GoalRecord(goal: skill('g1'), updatedAt: t1);
      expect(mergeGoal(null, r), same(r));
      expect(mergeGoal(r, null), same(r));
      expect(mergeGoal(null, null), isNull);
    });

    test('bản mới hơn thắng, bất kể ở máy nào', () {
      final older = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final newer = GoalRecord(goal: skill('g2'), updatedAt: t2);
      expect(mergeGoal(older, newer), same(newer));
      expect(mergeGoal(newer, older), same(newer));
    });

    test('bỏ mục tiêu mới hơn thắng mục tiêu cũ', () {
      final goal = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final dropped = GoalRecord(updatedAt: t2);
      expect(mergeGoal(goal, dropped), same(dropped));
      expect(mergeGoal(dropped, goal), same(dropped));
    });

    test('bằng giờ thì giữ bản máy chủ, để hai máy hội tụ về một bản', () {
      final local = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final remote = GoalRecord(goal: skill('g2'), updatedAt: t1);
      expect(mergeGoal(local, remote), same(remote));
    });
  });

  group('ngày giải', () {
    final today = DateTime(2026, 10, 15, 22, 30);
    test('phải sau hôm nay, tính theo ngày', () {
      expect(goalDateValid(DateTime(2026, 10, 16), today), isTrue);
      expect(goalDateValid(DateTime(2026, 10, 15, 23), today), isFalse);
      expect(goalDateValid(DateTime(2026, 10, 1), today), isFalse);
    });
  });

  group('khóa Lên hạng (spec mục 3)', () {
    PlayerRank rank(Rank? r) => PlayerRank(
          rank: r,
          source: r == null ? null : RankSource.estimated,
          onboardingState: r == null ? OnboardingState.skipped : OnboardingState.done,
          updatedAt: t1,
        );

    test('hạng kế tiếp là hạng ngay trên; A và PRO không có', () {
      expect(nextRank(Rank.k), Rank.i);
      expect(nextRank(Rank.d), Rank.c);
      expect(nextRank(Rank.b), Rank.a);
      expect(nextRank(Rank.a), isNull);
      expect(nextRank(Rank.pro), isNull);
    });

    test('chưa có hạng thì khóa noRank; A, PRO khóa topRank; còn lại mở', () {
      expect(lenHangBlock(null), LenHangBlock.noRank);
      expect(lenHangBlock(rank(null)), LenHangBlock.noRank);
      expect(lenHangBlock(rank(Rank.a)), LenHangBlock.topRank);
      expect(lenHangBlock(PlayerRank(
          rank: Rank.pro, source: RankSource.selfDeclared,
          onboardingState: OnboardingState.done, updatedAt: t1)), LenHangBlock.topRank);
      expect(lenHangBlock(rank(Rank.h)), isNull);
    });
  });
}
