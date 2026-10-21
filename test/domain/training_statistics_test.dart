import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/training_statistics.dart';

void main() {
  const drill = Drill(
    id: 'aiming-1',
    cat: SkillCategory.aiming,
    name: 'Đánh thẳng',
    level: 1,
    unit: 'trúng / 10',
    goal: 'Đánh trúng 8 trên 10 cú',
    steps: [],
    passThreshold: 0.8,
  );

  test('aggregates only scorable drill records and recent trends', () {
    final logs = [
      for (var i = 0; i < 7; i++)
        DrillLog(
          id: 'log-$i',
          drillId: 'aiming-1',
          date: DateTime(2026, 10, 1 + i),
          score: i + 1,
          attempts: 10,
        ),
      DrillLog(
        id: 'not-scorable',
        drillId: 'aiming-1',
        date: DateTime(2026, 10, 10),
        score: 5,
      ),
      DrillLog(
        id: 'unknown-drill',
        drillId: 'missing',
        date: DateTime(2026, 10, 11),
        score: 9,
      ),
    ];
    final timerSessions = [
      TimerSession(
        id: 'timer-this-week',
        date: DateTime(2026, 10, 19),
        durationSec: 900,
      ),
      TimerSession(
        id: 'timer-last-week',
        date: DateTime(2026, 10, 12),
        durationSec: 1200,
      ),
    ];

    final statistics = computeTrainingStatistics(
      drills: [drill],
      logs: logs,
      timerSessions: timerSessions,
      matches: [
        PoolMatch(
          id: 'won',
          gameType: PoolGameType.nineBall,
          playerName: 'An',
          opponentName: 'Bình',
          targetRacks: 3,
          rackWinners: const [
            RackWinner.player,
            RackWinner.opponent,
            RackWinner.player,
            RackWinner.player,
          ],
          shots: [
            MatchShot(
              id: 'break',
              rackNumber: 1,
              shotNumber: 1,
              shooter: RackWinner.player,
              type: MatchShotType.breakShot,
              outcome: MatchShotOutcome.made,
              positionOutcome: PositionOutcome.successful,
              recordedAt: DateTime(2026, 10, 10, 10),
            ),
            MatchShot(
              id: 'scratch',
              rackNumber: 1,
              shotNumber: 2,
              shooter: RackWinner.opponent,
              type: MatchShotType.safety,
              outcome: MatchShotOutcome.scratch,
              positionOutcome: PositionOutcome.unsuccessful,
              recordedAt: DateTime(2026, 10, 10, 10, 1),
            ),
            MatchShot(
              id: 'miss',
              rackNumber: 1,
              shotNumber: 3,
              shooter: RackWinner.player,
              type: MatchShotType.normal,
              outcome: MatchShotOutcome.missed,
              recordedAt: DateTime(2026, 10, 10, 10, 2),
            ),
            MatchShot(
              id: 'foul',
              rackNumber: 2,
              shotNumber: 1,
              shooter: RackWinner.opponent,
              type: MatchShotType.normal,
              outcome: MatchShotOutcome.foul,
              recordedAt: DateTime(2026, 10, 10, 11),
            ),
          ],
          startedAt: DateTime(2026, 10, 10),
          completedAt: DateTime(2026, 10, 10, 12),
        ),
        PoolMatch(
          id: 'lost',
          gameType: PoolGameType.eightBall,
          playerName: 'An',
          opponentName: 'Chi',
          targetRacks: 2,
          rackWinners: const [RackWinner.opponent, RackWinner.opponent],
          startedAt: DateTime(2026, 10, 11),
          completedAt: DateTime(2026, 10, 11, 12),
        ),
        PoolMatch(
          id: 'active',
          gameType: PoolGameType.tenBall,
          playerName: 'An',
          opponentName: 'Dung',
          targetRacks: 3,
          rackWinners: const [RackWinner.player, RackWinner.opponent],
          startedAt: DateTime(2026, 10, 12),
        ),
      ],
      today: DateTime(2026, 10, 20),
    );

    expect(statistics.drillSessionCount, 9);
    expect(statistics.timerSessionCount, 2);
    expect(statistics.totalSessionCount, 11);
    expect(statistics.totalTimerSeconds, 2100);
    expect(statistics.timerSecondsThisWeek, 900);
    expect(statistics.recordedMatchCount, 3);
    expect(statistics.completedMatchCount, 2);
    expect(statistics.matchWins, 1);
    expect(statistics.matchLosses, 1);
    expect(statistics.recordedShotCount, 4);
    expect(statistics.breakShotCount, 1);
    expect(statistics.safetyShotCount, 1);
    expect(statistics.missedShotCount, 1);
    expect(statistics.foulCount, 1);
    expect(statistics.scratchCount, 1);
    expect(statistics.successfulPositions, 1);
    expect(statistics.assessedPositions, 2);
    expect(
      statistics.streakDays,
      streakDays(
        logs: logs,
        timerSessions: timerSessions,
        today: DateTime(2026, 10, 20),
      ),
    );
    expect(
      statistics.skills
          .singleWhere((item) => item.category == SkillCategory.aiming)
          .scoredSessions,
      7,
    );
    expect(statistics.drillTrends, hasLength(1));
    expect(statistics.drillTrends.single.targetRatios, [
      closeTo(0.375, 1e-9),
      0.5,
      0.625,
      closeTo(0.75, 1e-9),
      closeTo(0.875, 1e-9),
    ]);
  });

  test('returns empty performance values without inventing scores', () {
    final statistics = computeTrainingStatistics(
      drills: [drill],
      logs: const [],
      timerSessions: const [],
      matches: const [],
      today: DateTime(2026, 10, 20),
    );

    expect(statistics.totalSessionCount, 0);
    expect(
      statistics.skills.every((skill) => skill.averageTargetRatio == null),
      isTrue,
    );
    expect(statistics.drillTrends, isEmpty);
    expect(statistics.streakDays, 0);
  });
}
