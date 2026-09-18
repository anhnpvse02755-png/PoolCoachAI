import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

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

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        3,
      );
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

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        1,
      );
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

      expect(
        streakDays(logs: logs, timerSessions: const [], today: _today),
        1,
      );
    });
  });
}
