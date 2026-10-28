import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/features/play/presentation/play_screen.dart';

import '../../support/layout_sweep.dart';
import '../../support/roadmap_fixtures.dart';
import '../../support/test_data.dart';

final _t0 = DateTime(2026, 10, 1, 9);

MatchShot _shot(
  int rack,
  int n,
  RackWinner who,
  MatchShotType type,
  MatchShotOutcome outcome,
) => MatchShot(
  id: 's$rack-$n',
  rackNumber: rack,
  shotNumber: n,
  shooter: who,
  type: type,
  outcome: outcome,
  recordedAt: _t0,
);

PoolMatch _match(
  String id, {
  required List<RackWinner> racks,
  List<MatchShot> shots = const [],
  int target = 2,
}) => PoolMatch(
  id: id,
  gameType: PoolGameType.nineBall,
  playerName: 'An',
  opponentName: 'Bình',
  targetRacks: target,
  rackWinners: racks,
  startedAt: _t0,
  completedAt: _t0,
  shots: shots,
);

/// Ván 1 thua sau cú tấn công trượt (đủ cú; cả trận 5 lần ngắm, 2 hỏng = 40%);
/// ván 2 thắng bằng phá-và-dọn; ván 3 thắng nhưng chưa ghi cú.
PoolMatch _shotsMatch() {
  const p = RackWinner.player;
  const o = RackWinner.opponent;
  return _match(
    'm',
    racks: [o, p, p],
    shots: [
      _shot(1, 1, p, MatchShotType.breakShot, MatchShotOutcome.made),
      _shot(1, 2, p, MatchShotType.normal, MatchShotOutcome.made),
      _shot(1, 3, p, MatchShotType.normal, MatchShotOutcome.made),
      _shot(1, 4, p, MatchShotType.normal, MatchShotOutcome.missed),
      _shot(1, 5, p, MatchShotType.normal, MatchShotOutcome.missed),
      _shot(1, 6, o, MatchShotType.normal, MatchShotOutcome.made),
      _shot(2, 1, p, MatchShotType.breakShot, MatchShotOutcome.made),
      _shot(2, 2, p, MatchShotType.normal, MatchShotOutcome.made),
    ],
  );
}

Future<void> _pump(WidgetTester tester, List<PoolMatch> matches) async {
  final container = testContainer(matches: matches, drills: roadmapDrills);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAnalysis(WidgetTester tester, String id) async {
  final button = find.byKey(Key('analyze-match-$id'));
  // Danh sách dựng lười: kéo dần cho tới khi nút được dựng.
  for (var i = 0; i < 10 && button.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thẻ trận đã xong có nút Phân tích trận, trận đang đánh thì không',
      (tester) async {
    await _pump(tester, [
      _match('done', racks: [RackWinner.player, RackWinner.player]),
      _match('open', racks: [RackWinner.player], target: 5),
    ]);
    expect(find.byKey(const Key('analyze-match-done')), findsOneWidget);
    expect(find.byKey(const Key('analyze-match-open')), findsNothing);
    expect(find.byKey(const Key('edit-match-done')), findsOneWidget);
    expect(find.byKey(const Key('delete-match-done')), findsOneWidget);
  });

  testWidgets('mở phân tích: thấy nguyên nhân mất ván, phá và bài nên tập',
      (tester) async {
    await _pump(tester, [_shotsMatch()]);
    await _openAnalysis(tester, 'm');
    expect(
      find.text(Vi.lostRackCause(LostRackCause.offensiveMiss, 1)),
      findsOneWidget,
    );
    expect(find.text(Vi.matchAnalysisBreak(2, 2, 1)), findsOneWidget);
    expect(find.text(Vi.matchAnalysisPositionFouls(0, 0, 0, 0)), findsOneWidget);
    expect(find.text(Vi.matchAnalysisFocus('Ngắm bi', 2, 5)), findsOneWidget);
    expect(find.text(Vi.matchAnalysisFocusDrill('Bai a1')), findsOneWidget);
    expect(find.text(Vi.matchAnalysisRacks(2, 2)), findsOneWidget);
  });

  testWidgets('trận không có cú: chỉ tỷ số và câu chưa ghi cú', (tester) async {
    await _pump(tester, [
      _match('m', racks: [RackWinner.player, RackWinner.opponent], target: 1),
    ]);
    await _openAnalysis(tester, 'm');
    expect(find.text(Vi.matchAnalysisNoShots), findsOneWidget);
    expect(find.text(Vi.matchAnalysisLostTitle), findsNothing);
    expect(find.text(Vi.matchAnalysisBreakTitle), findsNothing);
    expect(find.text(Vi.matchAnalysisFocusTitle), findsNothing);
    expect(find.text(Vi.matchAnalysisRacks(0, 0)), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  test('Vi.lostRackCause có câu cho mọi nguyên nhân', () {
    expect(
      Vi.lostRackCause(LostRackCause.notFull, 2),
      '2 ván thua chưa ghi đủ cú',
    );
    expect(
      Vi.lostRackCause(LostRackCause.unclear, 3),
      '3 ván thua chưa rõ nguyên nhân',
    );
    for (final c in LostRackCause.values) {
      expect(Vi.lostRackCause(c, 4), contains('4'));
    }
  });

  testWidgets('360×640 chữ lớn: bảng phân tích không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    await _pump(tester, [_shotsMatch()]);
    await _openAnalysis(tester, 'm');
    expect(find.text(Vi.matchAnalysisFocusTitle), findsWidgets);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });
}
