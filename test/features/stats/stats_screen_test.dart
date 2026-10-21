import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('shows training totals, skill performance, and drill trends', (
    tester,
  ) async {
    final container = testContainer(
      logs: [
        for (var i = 0; i < 3; i++)
          DrillLog(
            id: 'log-$i',
            drillId: 'd1',
            date: DateTime(2026, 9, 20 + i),
            score: 8 + i,
            attempts: 10,
          ),
      ],
      timerSessions: [
        TimerSession(id: 'timer', date: testToday, durationSec: 3600),
      ],
      matches: [
        PoolMatch(
          id: 'match',
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
              id: 'shot',
              rackNumber: 1,
              shotNumber: 1,
              shooter: RackWinner.player,
              type: MatchShotType.breakShot,
              outcome: MatchShotOutcome.scratch,
              positionOutcome: PositionOutcome.successful,
              recordedAt: testToday,
            ),
          ],
          startedAt: testToday,
          completedAt: testToday,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Vi.statsOverview), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1 giờ 0 phút'), findsNWidgets(2));
    expect(find.text(Vi.statsMatchCount(1, 1)), findsOneWidget);
    expect(find.text('1 / 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Vi.statsMatchDetails),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(Vi.statsNoShotRecords), findsNothing);
    expect(find.text(Vi.statsScratches), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Đường thẳng cơ bản'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đường thẳng cơ bản'), findsOneWidget);
    expect(find.text(Vi.statsPercent(113)), findsOneWidget);
    expect(find.text(Vi.statsRecentResults([100, 113, 125])), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining(Vi.statsMatchAnalysisNotAvailable),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining(Vi.statsMatchAnalysisNotAvailable),
      findsOneWidget,
    );
  });

  testWidgets('explains empty training history and unavailable match data', (
    tester,
  ) async {
    final container = testContainer(logs: const [], timerSessions: const []);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(Vi.statsNoTraining),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(Vi.statsNoTraining), findsOneWidget);
    expect(find.text(Vi.statsNoDrillTrends), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Vi.statsMatchAnalysisNotAvailable),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(Vi.statsMatchAnalysisNotAvailable), findsOneWidget);
  });

  group('win rate per cue', () {
    int n = 0;
    PoolMatch match(String? cueId, {required bool win}) {
      n++;
      return PoolMatch(
        id: 'm$n',
        gameType: PoolGameType.nineBall,
        playerName: 'An',
        opponentName: 'Bình',
        targetRacks: 1,
        rackWinners: [win ? RackWinner.player : RackWinner.opponent],
        startedAt: testToday.subtract(Duration(hours: n)),
        cueId: cueId,
      );
    }

    const cueA = CueEquipment(
      id: 'a',
      name: 'Cơ A',
      type: CueType.playing,
      skillCategories: [],
    );
    const cueB = CueEquipment(
      id: 'b',
      name: 'Cơ B',
      type: CueType.breakJump,
      skillCategories: [],
    );

    Future<void> openCard(WidgetTester tester, ProviderContainer c) async {
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(Vi.cueWinRateTitle),
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('names the best cue once two cues have ten matches', (
      tester,
    ) async {
      await openCard(
        tester,
        testContainer(
          equipment: const [cueA, cueB],
          matches: [
            for (var i = 0; i < 7; i++) match('a', win: true),
            for (var i = 0; i < 3; i++) match('a', win: false),
            for (var i = 0; i < 5; i++) match('b', win: true),
            for (var i = 0; i < 5; i++) match('b', win: false),
          ],
        ),
      );

      expect(
        find.text(Vi.cueWinRateLine(wins: 7, completed: 10, percent: 70)),
        findsOneWidget,
      );
      expect(
        find.text(Vi.cueWinRateLine(wins: 5, completed: 10, percent: 50)),
        findsOneWidget,
      );
      expect(find.text(Vi.cueBestBadge), findsOneWidget);
    });

    testWidgets('shows numbers and matches still needed, no verdict', (
      tester,
    ) async {
      await openCard(
        tester,
        testContainer(
          equipment: const [cueA, cueB],
          matches: [
            for (var i = 0; i < 4; i++) match('a', win: true),
            match('a', win: false),
            match(null, win: true),
          ],
        ),
      );

      expect(
        find.text(Vi.cueWinRateLine(wins: 4, completed: 5, percent: 80)),
        findsOneWidget,
      );
      expect(find.text(Vi.cueMatchesNeeded(5)), findsOneWidget);
      expect(find.text(Vi.cueWinRateNone), findsOneWidget);
      expect(find.text(Vi.cueBestBadge), findsNothing);
      expect(find.text(Vi.cueVerdictRule(10)), findsOneWidget);
    });

    testWidgets('a deleted cue appears as unknown', (tester) async {
      await openCard(
        tester,
        testContainer(
          equipment: const [cueA],
          matches: [match('gone', win: true)],
        ),
      );

      expect(find.text(Vi.equipmentUnknownCue), findsOneWidget);
    });

    testWidgets('is hidden when there is no cue at all', (tester) async {
      final c = testContainer(matches: [match(null, win: true)]);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Vi.cueWinRateTitle), findsNothing);
    });
  });
}
