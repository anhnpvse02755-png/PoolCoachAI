import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
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
}
