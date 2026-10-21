import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/coach_fixtures.dart';

void main() {
  test('toFacts(): khoá ổn định (chụp mẫu) — đổi khoá là đổi hợp đồng với Giai đoạn B', () {
    final ctx = buildCoachContext(
      pi: computePlayerIntelligence(drills: seedDrills, logs: const []),
      rank: Rank.g,
      currentStep: null,
      attempts: [
        attempt(CoachAttemptOutcome.solved1, topic: CoachTopic.kick, minute: 1),
        attempt(CoachAttemptOutcome.revealed, topic: CoachTopic.kick, fault: CoachFault.scratch, minute: 2),
      ],
    );
    final facts = ctx.toFacts();
    expect(facts.keys, ['skills', 'rank', 'currentStep', 'coach', 'lastSituation']);
    expect((facts['skills']! as Map).keys,
        ['aiming', 'position', 'breakShot', 'safety', 'kick', 'bank']);
    expect((facts['coach']! as Map).keys, ['aiming', 'position', 'safety', 'kick']);
    final kick = (facts['coach']! as Map)['kick'] as Map;
    expect(kick, {'total': 2, 'solved': 1, 'enough': false, 'recurring': null, 'recurringCount': 0});
    final last = facts['lastSituation']! as Map;
    expect(last.keys, ['key', 'topic', 'outcome', 'firstFaultGroup', 'answers']);
    expect(last['outcome'], 'revealed');
    expect(last['firstFaultGroup'], 'scratch');
    expect(facts['rank'], 'g');
    // JSON được: chỉ số, chữ, null, map.
    expect(() => jsonEncode(facts), returnsNormally);
  });

  test('chưa có lần làm nào: lastSituation null, số liệu 0', () {
    final facts = buildCoachContext(
      pi: computePlayerIntelligence(drills: seedDrills, logs: const []),
      rank: null,
      currentStep: null,
      attempts: const [],
    ).toFacts();
    expect(facts['lastSituation'], isNull);
    expect(((facts['coach']! as Map)['aiming'] as Map)['total'], 0);
  });
}
