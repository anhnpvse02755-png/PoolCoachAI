import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/rank_check.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/match_fixtures.dart';
import '../../support/roadmap_fixtures.dart';

void main() {
  final today = DateTime(2026, 10, 28, 10);
  // Bài BU gần nhất: đúng 28 ngày trước (theo ngày lịch).
  final bu28 = buResultGraded(completedAt: DateTime(2026, 9, 30, 20));
  final bu27 = buResultGraded(completedAt: DateTime(2026, 10, 1, 8));

  PlayerRank rank(Rank r, {RankSource source = RankSource.verified}) => PlayerRank(
        rank: r,
        source: source,
        buScore: source == RankSource.verified ? 120 : null,
        testId: source == RankSource.verified ? 't' : null,
        onboardingState: OnboardingState.done,
        updatedAt: today,
      );

  List<DrillLog> trend(String id, List<int> made) => [
        for (var i = 0; i < made.length; i++)
          ...sessions(id, made[i], [on(10, 1 + i)]).map(
            (l) => DrillLog(
                id: '${l.id}-$i', drillId: l.drillId, date: l.date, score: l.score, attempts: l.attempts),
          ),
      ];

  PlayerIntelligence pi({
    List<DrillLog> logs = const [],
    List<PoolMatch> matches = const [],
    BuResult? bu,
  }) =>
      computePlayerIntelligence(drills: roadmapDrills, logs: logs, matches: matches, latestBu: bu ?? bu28);

  final aimingPositionDown = [
    ...trend('a1', [9, 9, 5, 5]),
    ...trend('p1', [9, 9, 5, 5]),
  ];
  final aimingPositionUp = [
    ...trend('a1', [5, 5, 9, 9]),
    ...trend('p1', [5, 5, 9, 9]),
  ];

  RankCheckSignal? signal({PlayerRank? r, BuResult? bu, PlayerIntelligence? p}) => rankCheckSignal(
        rank: r ?? rank(Rank.d),
        latestBu: bu ?? bu28,
        pi: p ?? pi(logs: aimingPositionDown),
        today: today,
      );

  test('hạng chưa kiểm chứng hoặc chưa có hạng: không gợi ý', () {
    expect(signal(r: rank(Rank.d, source: RankSource.estimated)), isNull);
    expect(rankCheckSignal(rank: null, latestBu: bu28, pi: pi(logs: aimingPositionDown), today: today), isNull);
  });

  test('chưa có bài BU nào: không gợi ý', () {
    expect(rankCheckSignal(rank: rank(Rank.d), latestBu: null, pi: pi(logs: aimingPositionDown), today: today),
        isNull);
  });

  test('bài BU gần nhất mới 27 ngày: không gợi ý; 28 ngày thì có', () {
    expect(signal(bu: bu27), isNull);
    expect(signal(bu: bu28), isNotNull);
  });

  test('2 nhóm BU từng chấm đi xuống: gợi ý kiểm tra hạng hiện tại', () {
    final s = signal()!;
    expect(s.direction, RankCheckDirection.down);
    expect(s.basis, RankCheckBasis.drills);
    expect(s.categories, [SkillCategory.aiming, SkillCategory.position]);
    expect(s.rank, Rank.d);
  });

  test('nhóm đi xuống mà BU chưa chấm nhóm đó: không tính', () {
    final ungraded = BuResult(testId: 't', completedAt: DateTime(2026, 9, 30), total: 100, lost: const {});
    expect(signal(bu: ungraded, p: pi(logs: aimingPositionDown, bu: ungraded)), isNull);
  });

  test('chỉ 1 nhóm đi xuống: không gợi ý', () {
    expect(signal(p: pi(logs: trend('a1', [9, 9, 5, 5]))), isNull);
  });


  test('2 nhóm yếu trong trận: gợi ý hướng xuống theo trận', () {
    // 4 trận, mỗi trận 3 cú trượt và 3 lần điều bi hỏng: cả Tấn công lẫn Điều bi yếu.
    const who = RackWinner.player;
    const nm = MatchShotType.normal;
    final shots = [
      for (var n = 1; n <= 3; n++) shotAt(1, n, who, nm, MatchShotOutcome.missed),
      for (var n = 4; n <= 6; n++)
        shotAt(1, n, who, nm, MatchShotOutcome.made, position: PositionOutcome.unsuccessful),
    ];
    final matches = [
      for (var i = 0; i < 4; i++)
        completedMatch('m$i', const [who], shots, at: DateTime(2026, 10, 20 - i)),
    ];
    final p = pi(matches: matches);
    expect(p.matchWeak.length, 2);
    final s = signal(p: p)!;
    expect(s.direction, RankCheckDirection.down);
    expect(s.basis, RankCheckBasis.matches);
    expect(s.categories, [for (final w in p.matchWeak) w.category]);
    expect(s.rank, Rank.d);
  });

  test('2 nhóm đi lên, không nhóm nào đi xuống: thử hạng kế tiếp', () {
    final s = signal(p: pi(logs: aimingPositionUp))!;
    expect(s.direction, RankCheckDirection.up);
    expect(s.categories, [SkillCategory.aiming, SkillCategory.position]);
    expect(s.rank, Rank.c);
  });

  test('hạng A: đi lên cũng không có hạng kế tiếp để thử', () {
    expect(signal(r: rank(Rank.a), p: pi(logs: aimingPositionUp)), isNull);
  });

  test('đi lên nhưng một nhóm khác đi xuống: không gợi ý hướng lên', () {
    final logs = [
      ...trend('a1', [5, 5, 9, 9]),
      ...trend('p1', [5, 5, 9, 9]),
      ...trend('s1', [9, 9, 5, 5]),
    ];
    expect(signal(p: pi(logs: logs)), isNull);
  });

  test('1 nhóm lên, 1 nhóm xuống: không gợi ý', () {
    final logs = [...trend('a1', [5, 5, 9, 9]), ...trend('p1', [9, 9, 5, 5])];
    expect(signal(p: pi(logs: logs)), isNull);
  });
}
