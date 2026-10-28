import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/coach_fixtures.dart';
import '../../support/match_fixtures.dart';
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

Map<String, Object?> _breakFacts({
  required int shots,
  required int made,
  required int? madePercent,
  required int dry,
  required int racksBroken,
  required int breakAndRuns,
}) =>
    {
      'shots': shots,
      'made': made,
      'madePercent': madePercent,
      'dry': dry,
      'fouls': 0,
      'scratches': 0,
      'racksBroken': racksBroken,
      'breakAndRuns': breakAndRuns,
    };

Map<String, Object?> _positionFacts({
  required int assessed,
  required int failed,
  required int? failedPercent,
  required int nextAfterGood,
}) =>
    {
      'assessed': assessed,
      'failed': failed,
      'failedPercent': failedPercent,
      'nextAfterFailed': 0,
      'missAfterFailed': 0,
      'nextAfterGood': nextAfterGood,
      'missAfterGood': 0,
    };

Map<String, Object?> _noLostRacks() => {for (final c in LostRackCause.values) c.name: 0};

const _weakRule = {
  'minMatches': 3,
  'minAttempts': 10,
  'failPercentFrom': {'breakShot': 50, 'aiming': 35, 'position': 40, 'safety': 50},
};

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
    expect(facts(matches: [openMatch('x', [p], startedAt: DateTime(2026, 10, 1))])['matches'], {
      'recent': {'played': 0, 'won': 0, 'lost': 0},
      'last': null,
      'analysis': {
        'matches': 0,
        'racksWon': 0,
        'racksLost': 0,
        'racksWithShots': 0,
        'fullRacks': 0,
        'runOuts': 0,
        'break': _breakFacts(shots: 0, made: 0, madePercent: null, dry: 0, racksBroken: 0, breakAndRuns: 0),
        'offense': {'shots': 0, 'missed': 0, 'missPercent': null},
        'position': _positionFacts(assessed: 0, failed: 0, failedPercent: null, nextAfterGood: 0),
        'safety': {
          'shots': 0,
          'assessed': 0,
          'successful': 0,
          'successPercent': null,
          'turnovers': 0,
          'proactiveTurnovers': 0,
        },
        'errors': {'shots': 0, 'fouls': 0, 'scratches': 0},
        'lostRackCauses': _noLostRacks(),
        'weak': <Object?>[],
        'weakRule': _weakRule,
      },
    });
  });

  test('matches.analysis có đủ khoá và đúng số của analyzeMatches', () {
    // Ba trận yếu Tấn công: mỗi trận 1 ván thắng do người chơi dọn bàn, đối thủ
    // phá khô; 5 cú thường của người chơi, 3 trượt (60%); 2 điều bi đều tốt.
    final m = facts(matches: matchesWeakAt(SkillCategory.aiming, at: DateTime(2026, 10, 20)))['matches']! as Map;
    final a = m['analysis']! as Map;
    expect(a.keys, [
      'matches', 'racksWon', 'racksLost', 'racksWithShots', 'fullRacks', 'runOuts', 'break', 'offense',
      'position', 'safety', 'errors', 'lostRackCauses', 'weak', 'weakRule',
    ]);
    expect(a, {
      'matches': 3,
      'racksWon': 3,
      'racksLost': 0,
      'racksWithShots': 3,
      'fullRacks': 3,
      'runOuts': 3,
      'break': _breakFacts(shots: 0, made: 0, madePercent: null, dry: 0, racksBroken: 0, breakAndRuns: 0),
      'offense': {'shots': 15, 'missed': 9, 'missPercent': 60},
      'position': _positionFacts(assessed: 6, failed: 0, failedPercent: 0, nextAfterGood: 3),
      'safety': {
        'shots': 0,
        'assessed': 0,
        'successful': 0,
        'successPercent': null,
        'turnovers': 0,
        'proactiveTurnovers': 9,
      },
      'errors': {'shots': 15, 'fouls': 0, 'scratches': 0},
      'lostRackCauses': _noLostRacks(),
      'weak': [
        {'category': 'aiming', 'failures': 9, 'attempts': 15, 'matches': 3, 'failPercent': 60},
      ],
      'weakRule': _weakRule,
    });
    expect((a['lostRackCauses']! as Map).keys, [for (final c in LostRackCause.values) c.name]);
  });

  test('matches.last có nguyên nhân mất ván, phá, điều bi và lỗi của riêng trận đó', () {
    // Ván 1: người chơi phá khô rồi đối thủ dọn bàn -> thua do dryBreak.
    // Ván 2: người chơi phá vào rồi dọn hết (phá-và-dọn), 1 điều bi tốt.
    final one = completedMatch('last', const [o, p], [
      shotAt(1, 1, p, MatchShotType.breakShot, MatchShotOutcome.missed),
      shotAt(1, 2, o, MatchShotType.normal, MatchShotOutcome.made),
      shotAt(2, 1, p, MatchShotType.breakShot, MatchShotOutcome.made),
      shotAt(2, 2, p, MatchShotType.normal, MatchShotOutcome.made, position: PositionOutcome.successful),
    ]);
    final last = (facts(matches: [one])['matches']! as Map)['last']! as Map;
    expect(last.keys, [
      'gameType', 'targetRacks', 'racksWon', 'racksLost', 'won', 'shots', 'positionOutcomes',
      'lostRackCauses', 'break', 'position', 'fouls',
    ]);
    expect(last['lostRackCauses'], {..._noLostRacks(), 'dryBreak': 1});
    expect(last['break'], _breakFacts(shots: 2, made: 1, madePercent: 50, dry: 1, racksBroken: 2, breakAndRuns: 1));
    expect(last['position'], _positionFacts(assessed: 1, failed: 0, failedPercent: 0, nextAfterGood: 0));
    expect(last['fouls'], {'shots': 3, 'fouls': 0, 'scratches': 0});
  });

  test('matches.last dùng phân tích của chính trận đó, không trộn các trận khác', () {
    final newest = completedMatch('b', const [p], [
      shotAt(1, 1, p, MatchShotType.breakShot, MatchShotOutcome.scratch),
      shotAt(1, 2, o, MatchShotType.normal, MatchShotOutcome.foul),
      shotAt(1, 3, p, MatchShotType.normal, MatchShotOutcome.made),
    ], at: DateTime(2026, 10, 20));
    final all = [...matchesWeakAt(SkillCategory.aiming, at: DateTime(2026, 10, 19)), newest];
    final m = facts(matches: all)['matches']! as Map;
    expect((m['last']! as Map)['fouls'], {'shots': 2, 'fouls': 0, 'scratches': 1});
    expect((m['analysis']! as Map)['matches'], 4);
  });

  test('skillLevels: weakSources và buPercent nói nhóm yếu đến từ bài tập hay từ BU', () {
    final f = facts(pi: computePlayerIntelligence(drills: seedDrills, logs: playerWeakAt(SkillCategory.safety)))['skillLevels']! as Map;
    expect(f.keys, ['weak', 'strong', 'weakBelow', 'strongFrom', 'minSessions', 'weakSources', 'buPercent']);
    expect(f['weakSources'], {'safety': 'drills'});
    expect(f['buPercent'], <String, Object?>{});

    const bu = PlayerIntelligence(
      categories: {},
      weak: [SkillCategory.position],
      strong: [],
      readyDrillIds: [],
      hasAnyData: false,
      buPercent: {SkillCategory.position: 40, SkillCategory.aiming: 80},
      weakSources: {SkillCategory.position: WeakSource.bu},
    );
    final g = facts(pi: bu)['skillLevels']! as Map;
    expect(g['weak'], ['position']);
    expect(g['weakSources'], {'position': 'bu'});
    expect(g['buPercent'], {'position': 40, 'aiming': 80});
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

  test(
    'clip không cắt giữa cặp surrogate: emoji nằm đúng ở điểm cắt bị bỏ cả cặp, '
    'không để lại surrogate lẻ (ruling controller Task 9)',
    () {
      // 999 'a', rồi một emoji (2 code unit UTF-16, cặp surrogate), rồi thêm
      // chữ — code unit ở chỉ số 999 (coachChatMaxTurnChars - 1) là nửa đầu
      // (high surrogate) của emoji, đúng ngay điểm cắt.
      final text = '${List.filled(999, 'a').join()}😀${List.filled(200, 'a').join()}';
      expect(text.codeUnitAt(coachChatMaxTurnChars - 1), inInclusiveRange(0xD800, 0xDBFF));

      final entries = [(id: 1, at: DateTime(2026, 10, 22), fromPlayer: true, text: text, insufficient: false)];
      final h = coachChatHistory(entries, insufficientText: 'CHƯA ĐỦ');

      // Lùi điểm cắt về 999 (bỏ cả cặp), không phải cắt ở 1000 (làm rơi mất
      // nửa sau, để lại một high surrogate lẻ không giải mã được).
      expect(h.single.text.length, 999);
      expect(h.single.text, List.filled(999, 'a').join());
      for (final unit in h.single.text.codeUnits) {
        expect(unit, isNot(inInclusiveRange(0xD800, 0xDFFF)), reason: 'không được để lại surrogate lẻ');
      }
    },
  );
}
