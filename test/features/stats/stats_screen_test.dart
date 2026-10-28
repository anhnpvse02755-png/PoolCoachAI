import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/stats/presentation/stats_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

void main() {
  /// Đủ cả ba nguồn: buổi tập bài, buổi bấm giờ và một trận đã xong.
  ProviderContainer fullContainer() => testContainer(
    logs: [
      for (var i = 0; i < 3; i++)
        DrillLog(
          id: 'log-$i',
          drillId: 'd1',
          date: DateTime(2026, 9, 20 + i),
          score: 8 + i,
          attempts: 10,
          durationSec: i == 0 ? 300 : null,
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

  /// Mở màn Thống kê với [fullContainer].
  Future<void> openStats(WidgetTester tester) async {
    final container = fullContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows training totals, skill performance, and drill trends', (
    tester,
  ) async {
    await openStats(tester);

    expect(find.text(Vi.statsOverview), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1 giờ 0 phút'), findsNWidgets(2));
    expect(find.text(Vi.statsDrillDurationValue(300, 1)), findsOneWidget);
    expect(find.text(Vi.statsMatchCount(1, 1)), findsOneWidget);
    expect(find.text('1 / 0'), findsOneWidget);
    expect(find.text(Vi.statsCombinedSummary(3, 1, 2, 1)), findsOneWidget);
    expect(
      find.text(Vi.statsCombinedDayLabel(DateTime.monday)),
      findsOneWidget,
    );
    expect(
      find.text(Vi.statsCombinedDayLabel(DateTime.tuesday)),
      findsOneWidget,
    );
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
    await tester.ensureVisible(
      find.text(Vi.statsMatchAnalysisTitle, skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text(Vi.statsMatchAnalysisTitle), findsOneWidget);
  });

  testWidgets('lưới chỉ số ở 360: hai ô một hàng', (tester) async {
    applyScreen(tester, const Size(360, 640));
    await openStats(tester);
    final top = tester.getTopLeft(find.text(Vi.statsTotalSessions)).dy;
    expect(tester.getTopLeft(find.text(Vi.statsDrillSessions)).dy, top);
    expect(
      tester.getTopLeft(find.text(Vi.statsTimerSessions)).dy,
      greaterThan(top),
    );
  });

  testWidgets('lưới chỉ số ở 800: ba ô một hàng', (tester) async {
    applyScreen(tester, const Size(800, 1280));
    await openStats(tester);
    final top = tester.getTopLeft(find.text(Vi.statsTotalSessions)).dy;
    expect(tester.getTopLeft(find.text(Vi.statsTimerSessions)).dy, top);
    expect(
      tester.getTopLeft(find.text(Vi.statsTimerTotal)).dy,
      greaterThan(top),
    );
  });

  testWidgets('chữ ×1.5 ở 360: ô không tràn, hai ô cùng hàng cao bằng nhau', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 1.5);
    await openStats(tester);
    expect(tester.takeException(), isNull);
    // .first là PcCard gần nhất: ô chỉ số, không phải thẻ bọc ngoài nếu có.
    Size card(String label) => tester.getSize(
      find.ancestor(of: find.text(label), matching: find.byType(PcCard)).first,
    );
    expect(
      card(Vi.statsTotalSessions).height,
      card(Vi.statsDrillSessions).height,
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
    await tester.ensureVisible(
      find.text(Vi.statsMatchAnalysisTitle, skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text(Vi.statsMatchAnalysisTitle), findsOneWidget);
    expect(find.text(Vi.statsMatchAnalysisEmpty), findsOneWidget);
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

  // Font của app tải lúc chạy, sau khung hình đầu. Flutter 3.47 làm mới chữ
  // khi font tới nhưng không làm mới bộ đo kích thước nội tại của chữ
  // (rendering/paragraph.dart, systemFontsDidChange), mà IntrinsicHeight đọc
  // đúng bộ đo đó. Hàng ô vì thế phải cao đúng theo chữ đang hiện.
  testWidgets(
    'font tới sau khung hình đầu: mỗi hàng ô cao đúng bằng ô nhiều chữ nhất',
    (tester) async {
      applyScreen(tester, const Size(360, 640));
      const family = 'FontToiSau';
      final container = fullContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: family),
            home: const StatsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Họ font chưa nạp thì chữ vẽ bằng font dự phòng của test (mỗi chữ rộng
      // 1 em). Giờ font thật tới: Roboto hẹp hơn nhiều. Font này nằm trong
      // repo (test/fixtures/fonts), không đọc từ cache của Flutter SDK, vì
      // bản cache SDK trên CI có thể thiếu material_fonts/roboto-regular.ttf
      // dù máy local luôn có.
      final roboto = File('test/fixtures/fonts/roboto-regular.ttf');
      expect(roboto.existsSync(), isTrue, reason: 'không thấy ${roboto.path}');
      final bytes = roboto.readAsBytesSync();
      await tester.runAsync(
        () => (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
      );
      await tester.pumpAndSettle();

      Finder card(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(PcCard))
          .first;
      double natural(String label) {
        final value = find.descendant(
          of: card(label),
          matching: find.byWidgetPredicate((w) => w is Text && w.data != label),
        );
        return 2 * AppSpacing.md +
            tester.getSize(find.text(label)).height +
            4 +
            tester.getSize(value).height;
      }

      const rows = [
        [Vi.statsTotalSessions, Vi.statsDrillSessions],
        [Vi.statsTimerSessions, Vi.statsTimerTotal],
        [Vi.statsDrillDurationTotal, Vi.statsTimerWeek],
        [Vi.statsStreak, Vi.statsRecordedMatches],
        [Vi.statsMatchWinsLosses, Vi.statsRecordedShots],
      ];
      for (final row in rows) {
        final tallest = row.map(natural).reduce(math.max);
        for (final label in row) {
          expect(
            tester.getSize(card(label)).height,
            closeTo(tallest, 0.5),
            reason: 'hàng ${row.join(' / ')}: ô $label',
          );
        }
      }
    },
  );
}
