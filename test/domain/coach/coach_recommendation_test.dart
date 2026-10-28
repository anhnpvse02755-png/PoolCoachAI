import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/coach_fixtures.dart' show attempt;

final _today = DateTime(2026, 10, 21);

/// Người chơi yếu đúng nhóm [weakCat] (cùng cách dựng với no_fabrication_test).
List<DrillLog> playerWeakAt(SkillCategory weakCat) {
  final logs = <DrillLog>[];
  var n = 0;
  for (final drill in seedDrills) {
    if (!drill.usesAttempts) continue;
    final poor = drill.cat == weakCat;
    for (var i = 0; i < 3; i++) {
      n++;
      logs.add(DrillLog(
        id: 'l$n',
        drillId: drill.id,
        date: _today.subtract(Duration(days: 2 - i)),
        score: poor ? 2 : 10,
        attempts: 10,
      ));
    }
  }
  return logs;
}

TodayRecommendation todayFor(List<DrillLog> logs) => computeRecommendation(
      drills: seedDrills,
      logs: logs,
      knowledge: seedKnowledge,
      timerSessions: const [],
      schedule: const [],
      today: _today,
    );

TodayRecommendation todayAt(SkillCategory cat) => TodayRecommendation(
      cat: cat,
      reason: PickReason.weakest,
      drill: null,
      article: null,
      readyDrillIds: const [],
      streak: 0,
      practiceSecondsThisWeek: 0,
      todaySchedule: const [],
    );

PlayerIntelligence withMatchWeak(PlayerIntelligence base, List<SkillCategory> cats) =>
    PlayerIntelligence(
      categories: base.categories,
      weak: base.weak,
      strong: base.strong,
      readyDrillIds: base.readyDrillIds,
      hasAnyData: base.hasAnyData,
      matchWeak: [
        for (final c in cats)
          SkillSignal(category: c, failures: 4, attempts: 8, matches: 3),
      ],
    );

TodayRecommendation todayMatchWeak(SkillCategory cat) => TodayRecommendation(
      cat: cat,
      reason: PickReason.matchWeakness,
      drill: null,
      article: null,
      readyDrillIds: const [],
      streak: 0,
      practiceSecondsThisWeek: 0,
      todaySchedule: const [],
    );

void main() {
  final emptyPi = computePlayerIntelligence(drills: seedDrills, logs: const []);

  test('đổi nhóm yếu thì chủ đề Coach đổi theo, cùng nhóm với gợi ý hôm nay', () {
    for (final weak in [SkillCategory.position, SkillCategory.safety]) {
      final logs = playerWeakAt(weak);
      final rec = computeCoachRecommendation(
        today: todayFor(logs),
        pi: computePlayerIntelligence(drills: seedDrills, logs: logs),
        attempts: const [],
        articles: seedKnowledge,
      );
      expect(rec.topic, coachTopicOf(weak));
      expect(rec.topicReason, CoachTopicReason.sameAsToday);
      expect(rec.unsupported, isNull);
    }
  });

  test('gợi ý hôm nay là Phá / Cân bi: nói chưa có tình huống, chuyển nhóm kế tiếp', () {
    for (final cat in [SkillCategory.breakShot, SkillCategory.bank]) {
      final rec = computeCoachRecommendation(
        today: todayAt(cat),
        pi: emptyPi,
        attempts: const [],
        articles: seedKnowledge,
      );
      expect(rec.unsupported, cat);
      expect(coachTopicOf(categoryOf(rec.topic)), isNotNull);
      // Chưa có điểm nào: nhóm đầu tiên của thứ tự làm quen có tình huống.
      expect(rec.topic, CoachTopic.aiming);
      expect(rec.topicReason, CoachTopicReason.lowest);
    }
  });

  test('không có gợi ý hôm nay: nhóm yếu nhất có tình huống', () {
    final logs = playerWeakAt(SkillCategory.kick);
    final rec = computeCoachRecommendation(
      today: null,
      pi: computePlayerIntelligence(drills: seedDrills, logs: logs),
      attempts: const [],
      articles: seedKnowledge,
    );
    expect(rec.topic, CoachTopic.kick);
    expect(rec.topicReason, CoachTopicReason.weakest);
  });

  test('gợi ý hôm nay là yếu trong trận: lý do thẻ Coach là matchWeakness', () {
    final rec = computeCoachRecommendation(
      today: todayMatchWeak(SkillCategory.position),
      pi: withMatchWeak(emptyPi, [SkillCategory.position]),
      attempts: const [],
      articles: seedKnowledge,
    );
    expect(rec.topic, CoachTopic.position);
    expect(rec.topicReason, CoachTopicReason.matchWeakness);
    expect(rec.unsupported, isNull);
  });

  test('hôm nay là Phá (không có tình huống), trận yếu Điều bi: chọn Điều bi, lý do matchWeakness', () {
    final rec = computeCoachRecommendation(
      today: todayAt(SkillCategory.breakShot),
      pi: withMatchWeak(emptyPi, [SkillCategory.breakShot, SkillCategory.position]),
      attempts: const [],
      articles: seedKnowledge,
    );
    expect(rec.topic, CoachTopic.position);
    expect(rec.topicReason, CoachTopicReason.matchWeakness);
    expect(rec.unsupported, SkillCategory.breakShot);
  });

  test('trận yếu Phá mà bài tập yếu Phòng thủ: rơi xuống weakest', () {
    final logs = playerWeakAt(SkillCategory.safety);
    final base = computePlayerIntelligence(drills: seedDrills, logs: logs);
    final rec = computeCoachRecommendation(
      today: null,
      pi: withMatchWeak(base, [SkillCategory.breakShot]),
      attempts: const [],
      articles: seedKnowledge,
    );
    expect(rec.topic, CoachTopic.safety);
    expect(rec.topicReason, CoachTopicReason.weakest);
  });

  test('hôm nay yếu theo bài tập, trận yếu nhóm khác: giữ sameAsToday', () {
    final rec = computeCoachRecommendation(
      today: todayAt(SkillCategory.safety),
      pi: withMatchWeak(emptyPi, [SkillCategory.kick]),
      attempts: const [],
      articles: seedKnowledge,
    );
    expect(rec.topic, CoachTopic.safety);
    expect(rec.topicReason, CoachTopicReason.sameAsToday);
  });

  group('công cụ theo nhóm lỗi', () {
    CoachRecommendation withFault(CoachFault f, {List<KnowledgeArticle>? articles}) =>
        computeCoachRecommendation(
          today: todayAt(SkillCategory.position),
          pi: emptyPi,
          attempts: [
            for (var i = 0; i < coachRecurringMin; i++)
              attempt(CoachAttemptOutcome.revealed, fault: f, minute: i),
          ],
          articles: articles ?? seedKnowledge,
        );

    test('chọn lỗ → Mô phỏng góc cắt', () {
      expect(withFault(CoachFault.pocketWorse).tool, CoachTool.simulator);
    });
    test('vị trí bi cái, chết cái → Kế hoạch dọn bàn', () {
      expect(withFault(CoachFault.powerWorse).tool, CoachTool.planner);
      expect(withFault(CoachFault.scratch).tool, CoachTool.planner);
    });
    test('áp phê thừa → bài đọc đầu tiên nhóm Điều bi; không có thì không gợi ý', () {
      final rec = withFault(CoachFault.spinUnneeded);
      final first = seedKnowledge.where((a) => a.cat == SkillCategory.position).firstOrNull;
      if (first != null) {
        expect(rec.tool, CoachTool.article);
        expect(rec.article!.id, first.id);
      }
      final none = withFault(CoachFault.spinUnneeded,
          articles: [for (final a in seedKnowledge) if (a.cat != SkillCategory.position) a]);
      expect(none.tool, isNull);
      expect(none.article, isNull);
    });
    test('không đủ lần lặp thì không có công cụ', () {
      final rec = computeCoachRecommendation(
        today: todayAt(SkillCategory.position),
        pi: emptyPi,
        attempts: [attempt(CoachAttemptOutcome.revealed, fault: CoachFault.pocketWorse)],
        articles: seedKnowledge,
      );
      expect(rec.stats.recurring, isNull);
      expect(rec.tool, isNull);
    });
  });
}
