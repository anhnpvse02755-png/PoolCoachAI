import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

final _today = DateTime(2026, 9, 17);

/// Dựng người chơi yếu đúng một nhóm: tập kém ở nhóm đó, tốt ở nhóm khác.
///
/// [lapsed] đẩy mọi buổi lùi về hơn một tuần trước, tức người chơi đang
/// đứt chuỗi. Mặc định là vừa tập hôm nay, để luật "sắp mất streak"
/// không che mất luật "nhóm yếu" mà các test dưới đang xét.
List<DrillLog> _playerWeakAt(SkillCategory weakCat, {bool lapsed = false}) {
  final logs = <DrillLog>[];
  var n = 0;

  for (final drill in seedDrills) {
    if (!drill.usesAttempts) continue;
    final poor = drill.cat == weakCat;
    for (var i = 0; i < 3; i++) {
      n++;
      logs.add(
        DrillLog(
          id: 'l$n',
          drillId: drill.id,
          date: _today.subtract(Duration(days: (lapsed ? 10 : 2) - i)),
          score: poor ? 2 : 10,
          attempts: 10,
        ),
      );
    }
  }
  return logs;
}

void main() {
  group('lớp suy luận bám dữ liệu, không viết cứng', () {
    test('đổi nhóm yếu trong dữ liệu thì kết luận đổi theo', () {
      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final pi = computePlayerIntelligence(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
        );

        expect(
          pi.weak.first,
          weakCat,
          reason: 'dữ liệu nói yếu $weakCat nhưng kết luận lại khác',
        );
      }
    });

    test('gợi ý hôm nay đi theo nhóm yếu, không cố định một nhóm', () {
      final picks = <SkillCategory>{};

      for (final weakCat in [SkillCategory.position, SkillCategory.safety]) {
        final rec = computeRecommendation(
          drills: seedDrills,
          logs: _playerWeakAt(weakCat),
          knowledge: seedKnowledge,
          timerSessions: const [],
          schedule: const [],
          today: _today,
        );

        expect(rec.reason, PickReason.weakest);
        expect(rec.cat, weakCat);
        picks.add(rec.cat);
      }

      expect(
        picks.length,
        2,
        reason: 'hai người chơi yếu khác nhau mà nhận cùng một gợi ý',
      );
    });

    test('người đã bỏ tập cả tuần thì luật streak thắng luật nhóm yếu', () {
      // Không phải lỗi: spec xếp luật 2 trên luật 3 có chủ ý — kéo người
      // quay lại bàn quan trọng hơn việc hôm đó tập đúng nhóm yếu.
      final rec = computeRecommendation(
        drills: seedDrills,
        logs: _playerWeakAt(SkillCategory.position, lapsed: true),
        knowledge: seedKnowledge,
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.reason, PickReason.streakAtRisk);
    });

    test('chưa đủ dữ liệu thì nói không biết, không đoán', () {
      final pi = computePlayerIntelligence(
        drills: seedDrills,
        logs: [
          DrillLog(
            id: 'l1',
            drillId: seedDrills.first.id,
            date: _today,
            score: 9,
            attempts: 10,
          ),
        ],
      );

      expect(pi.weak, isEmpty);
      expect(pi.strong, isEmpty);
      for (final insight in pi.categories.values) {
        if (insight.sessionCount < 3) {
          expect(insight.mastery, isNull);
        }
      }
    });
  });

  group('Lộ trình bám dữ liệu, không viết cứng (spec 2026-10-15 mục 9)', () {
    final rank = PlayerRank(
      rank: Rank.h,
      source: RankSource.estimated,
      onboardingState: OnboardingState.done,
      updatedAt: _today,
    );
    final goal = PlayerGoal(
      goalId: 'g',
      kind: GoalKind.lenHang,
      createdAt: _today,
    );

    Roadmap roadmapFor(List<DrillLog> logs, {BuResult? result}) => buildRoadmap(
          goal: goal,
          rank: rank,
          drills: seedDrills,
          logs: logs,
          tests: const [],
          latestResult: result,
          today: _today,
        );

    test('hai người yếu hai nhóm khác nhau nhận hai lộ trình khác nhau', () {
      final position = roadmapFor(_playerWeakAt(SkillCategory.position));
      final safety = roadmapFor(_playerWeakAt(SkillCategory.safety));
      expect(position.steps.first.category, SkillCategory.position);
      expect(safety.steps.first.category, SkillCategory.safety);
      expect(
        Vi.stepTitle(position.steps.first),
        isNot(Vi.stepTitle(safety.steps.first)),
      );
    });

    test('đổi điểm mất BU thì câu lý do đổi theo', () {
      BuResult result(Map<String, int> lost) => BuResult(
            testId: 't',
            completedAt: _today,
            total: 50,
            lost: lost,
          );
      final aiming = roadmapFor(const [], result: result(const {'F7': 20}));
      final safety = roadmapFor(const [], result: result(const {'S5': 12}));
      expect(Vi.stepReason(aiming.steps.first.reason), contains('20'));
      expect(Vi.stepReason(safety.steps.first.reason), contains('12'));
      expect(
        Vi.stepReason(aiming.steps.first.reason),
        isNot(Vi.stepReason(safety.steps.first.reason)),
      );
    });
  });
}
