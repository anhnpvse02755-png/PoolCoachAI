import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../support/match_fixtures.dart';

final _today = DateTime(2026, 9, 17);

const _aimDrill = Drill(
  id: 'aim1',
  cat: SkillCategory.aiming,
  name: 'Đường thẳng cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  goal: 'g',
  steps: ['s'],
  passThreshold: 0.8,
);

const _aimArticle = KnowledgeArticle(
  id: 'k1',
  cat: SkillCategory.aiming,
  title: 'Nguyên lý bi ảo',
  body: 'b',
);

void main() {
  group('computeRecommendation', () {
    test('gợi ý mang tín hiệu trận khi lý do là yếu trong trận', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [],
        timerSessions: const [],
        schedule: const [],
        today: _today,
        matches: matchesWeakAt(SkillCategory.position, at: _today),
      );
      expect(
        [rec.reason, rec.cat, rec.matchSignal!.category],
        [
          PickReason.matchWeakness,
          SkillCategory.position,
          SkillCategory.position,
        ],
      );
    });

    test('lý do khác yếu trong trận thì không mang tín hiệu trận', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );
      expect(rec.reason, PickReason.newcomer);
      expect(rec.matchSignal, isNull);
    });

    test('người mới nhận bài Ngắm bi cấp 1 và bài đọc cùng nhóm', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [_aimArticle],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.cat, SkillCategory.aiming);
      expect(rec.drill?.id, 'aim1');
      expect(rec.article?.id, 'k1');
      expect(rec.reason, PickReason.newcomer);
    });

    test('không có bài kiến thức cùng nhóm thì article là null, không bịa', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.article, isNull);
    });

    test('bài đã tập hôm nay không được gợi ý lại', () {
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: [
          DrillLog(
            id: 'l1',
            drillId: 'aim1',
            date: _today,
            score: 9,
            attempts: 10,
          ),
        ],
        knowledge: const [_aimArticle],
        timerSessions: const [],
        schedule: const [],
        today: _today,
      );

      expect(rec.drill, isNull);
    });

    test('lịch đúng thứ hiện ở Home và điều khiển nhóm gợi ý', () {
      final slot = ScheduleSlot(
        id: 's1',
        day: _today.weekday - 1,
        time: '19:00',
        label: 'Tập cân bi',
        cat: SkillCategory.bank,
      );
      final rec = computeRecommendation(
        drills: const [_aimDrill],
        logs: const [],
        knowledge: const [],
        timerSessions: const [],
        schedule: [slot],
        today: _today,
      );

      expect(rec.todaySchedule, [slot]);
      expect(rec.cat, SkillCategory.bank);
      expect(rec.reason, PickReason.scheduled);
    });
  });

  group('streakDays', () {
    test('không có buổi nào thì streak bằng 0', () {
      expect(
        streakDays(logs: const [], timerSessions: const [], today: _today),
        0,
      );
    });

    test('tập hôm nay và hai hôm trước liên tiếp cho streak 3', () {
      final logs = [
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: 'l$i',
            drillId: 'aim1',
            date: _today.subtract(Duration(days: i)),
            score: 9,
            attempts: 10,
          ),
      ];

      expect(streakDays(logs: logs, timerSessions: const [], today: _today), 3);
    });

    test('buổi tập tự do cũng tính vào streak', () {
      expect(
        streakDays(
          logs: const [],
          timerSessions: [
            TimerSession(id: 't1', date: _today, durationSec: 600),
          ],
          today: _today,
        ),
        1,
      );
    });

    test('đứt một ngày thì streak dừng lại ở đó', () {
      final logs = [
        DrillLog(
          id: 'l1',
          drillId: 'aim1',
          date: _today,
          score: 9,
          attempts: 10,
        ),
        DrillLog(
          id: 'l2',
          drillId: 'aim1',
          date: _today.subtract(const Duration(days: 2)),
          score: 9,
          attempts: 10,
        ),
      ];

      expect(streakDays(logs: logs, timerSessions: const [], today: _today), 1);
    });

    test('tập hôm qua nhưng chưa tập hôm nay vẫn giữ streak', () {
      final logs = [
        DrillLog(
          id: 'l1',
          drillId: 'aim1',
          date: _today.subtract(const Duration(days: 1)),
          score: 9,
          attempts: 10,
        ),
      ];

      expect(streakDays(logs: logs, timerSessions: const [], today: _today), 1);
    });
  });

  group('freePracticeSecondsThisWeek', () {
    test('chỉ cộng buổi từ thứ Hai đến hết hôm nay', () {
      final seconds = freePracticeSecondsThisWeek(
        timerSessions: [
          TimerSession(
            id: 'monday',
            date: DateTime(2026, 9, 14, 9),
            durationSec: 900,
          ),
          TimerSession(
            id: 'today',
            date: DateTime(2026, 9, 17, 21),
            durationSec: 1800,
          ),
          TimerSession(
            id: 'last-week',
            date: DateTime(2026, 9, 13, 21),
            durationSec: 3000,
          ),
          TimerSession(
            id: 'future',
            date: DateTime(2026, 9, 18, 8),
            durationSec: 6000,
          ),
        ],
        today: _today,
      );

      expect(seconds, 2700);
    });
  });
}
