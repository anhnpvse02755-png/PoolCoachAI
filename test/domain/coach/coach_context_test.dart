import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/coach_fixtures.dart';
import 'coach_recommendation_test.dart' show playerWeakAt;

Map<String, Object?> facts({
  PlayerIntelligence? pi,
  TodayRecommendation? today,
  List<PoolMatch> matches = const [],
}) =>
    buildCoachContext(
      pi: pi ?? computePlayerIntelligence(drills: seedDrills, logs: const []),
      rank: null,
      currentStep: null,
      attempts: const [],
      today: today,
      matches: matches,
    ).toFacts();

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
      today: null,
      matches: const [],
    );
    final facts = ctx.toFacts();
    expect(facts.keys, ['skills', 'rank', 'currentStep', 'coach', 'lastSituation', 'skillLevels', 'today', 'matches']);
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
      today: null,
      matches: const [],
    ).toFacts();
    expect(facts['lastSituation'], isNull);
    expect(((facts['coach']! as Map)['aiming'] as Map)['total'], 0);
  });

  const p = RackWinner.player, o = RackWinner.opponent;

  test('skillLevels: nhóm yếu/mạnh và ngưỡng đúng của app', () {
    final f = facts(pi: computePlayerIntelligence(drills: seedDrills, logs: playerWeakAt(SkillCategory.safety)))['skillLevels']! as Map;
    expect((f['weak']! as List).first, 'safety');
    expect(f['weakBelow'], 55);
    expect(f['strongFrom'], 75);
    expect(f['minSessions'], 3);
  });

  test('today: đúng thẻ Hôm nay, phút tập tự do tính từ giây', () {
    expect(facts(today: sampleToday())['today'], {
      'category': 'safety', 'reason': 'weakest', 'drillId': 'd7', 'drillName': 'Bài 3: thủ sau bi 9',
      'articleTitle': 'Phòng thủ bắt đui', 'streak': 4, 'practiceMinutesThisWeek': 90, 'scheduledToday': ['Tập thủ 19:00'],
    });
    expect(facts()['today'], isNull);
  });

  test('matches.recent: tối đa 10 trận đã xong gần nhất, bỏ trận đang đánh', () {
    final all = [
      for (var i = 0; i < 12; i++)
        finishedMatch('m$i', i.isEven ? [p, o, p, p] : [o, p, o, o], completedAt: DateTime(2026, 10, 1 + i)),
      openMatch('dang-danh', [p], startedAt: DateTime(2026, 10, 20)),
    ];
    final m = facts(matches: all)['matches']! as Map;
    expect(m['recent'], {'played': 10, 'won': 5, 'lost': 5});
    final last = m['last']! as Map;
    expect([last['gameType'], last['targetRacks'], last['racksWon'], last['racksLost'], last['won']], ['nineBall', 3, 1, 3, false]);
  });

  test('matches.last: chỉ đếm cú của chính người chơi, đủ mọi khoá', () {
    final m = finishedMatch('m', [p, p, p], completedAt: DateTime(2026, 10, 2), shots: [
      matchShot(p, MatchShotType.breakShot, MatchShotOutcome.made),
      matchShot(p, MatchShotType.normal, MatchShotOutcome.missed, position: PositionOutcome.unsuccessful),
      matchShot(p, MatchShotType.normal, MatchShotOutcome.made, position: PositionOutcome.successful),
      matchShot(o, MatchShotType.normal, MatchShotOutcome.made, position: PositionOutcome.successful),
      matchShot(p, MatchShotType.safety, MatchShotOutcome.foul),
    ]);
    final last = (facts(matches: [m])['matches']! as Map)['last']! as Map;
    expect(last['shots'], {
      'breakShot': {'made': 1, 'missed': 0, 'foul': 0, 'scratch': 0},
      'normal': {'made': 1, 'missed': 1, 'foul': 0, 'scratch': 0},
      'safety': {'made': 0, 'missed': 0, 'foul': 1, 'scratch': 0},
    });
    expect(last['positionOutcomes'], {'successful': 1, 'unsuccessful': 1});
    expect(last['won'], isTrue);
  });

  test('chưa có trận nào xong: recent 0, last null', () {
    expect(facts(matches: [openMatch('x', [p], startedAt: DateTime(2026, 10, 1))])['matches'],
        {'recent': {'played': 0, 'won': 0, 'lost': 0}, 'last': null});
  });

  test('không gửi tên người chơi hay đối thủ; facts tất định', () {
    final a = jsonEncode(fullCoachContext().toFacts());
    expect(a, isNot(contains(samplePlayerName)));
    expect(a, isNot(contains(sampleOpponentName)));
    expect(jsonEncode(fullCoachContext().toFacts()), a);
  });

  test('lịch sử gửi lên: 10 lượt cuối, lượt bị chặn gửi đúng câu người chơi đã thấy', () {
    final entries = [
      for (var i = 0; i < 12; i++)
        (id: i + 1, at: DateTime(2026, 10, 22), fromPlayer: i.isEven, text: i == 11 ? '' : 't$i', insufficient: i == 11),
    ];
    final h = coachChatHistory(entries, insufficientText: 'CHƯA ĐỦ');
    expect(h, hasLength(10));
    expect(h.first, (fromPlayer: true, text: 't2'));
    expect(h.last, (fromPlayer: false, text: 'CHƯA ĐỦ'));
  });

  test('lịch sử gửi lên: mỗi lượt bị clip tới coachChatMaxTurnChars ký tự UTF-16 (ruling controller)', () {
    final longText = List.filled(coachChatMaxTurnChars + 200, 'a').join();
    final longInsufficient = List.filled(coachChatMaxTurnChars + 200, 'x').join();
    final entries = [
      (id: 1, at: DateTime(2026, 10, 22), fromPlayer: true, text: longText, insufficient: false),
      (id: 2, at: DateTime(2026, 10, 22), fromPlayer: false, text: '', insufficient: true),
    ];
    final h = coachChatHistory(entries, insufficientText: longInsufficient);
    expect(h[0].text.length, coachChatMaxTurnChars);
    expect(h[0].text, longText.substring(0, coachChatMaxTurnChars));
    expect(h[1].text.length, coachChatMaxTurnChars);
  });
}
