import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/stats/presentation/match_analysis_card.dart';

import '../../support/layout_sweep.dart';
import '../../support/match_fixtures.dart';
import '../../support/test_data.dart';

Future<void> pumpCard(WidgetTester tester, MatchAnalysis analysis) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchAnalysisCard(analysis: analysis),
          ),
        ),
      ),
    );

void main() {
  testWidgets('yếu Ngắm bi rồi yếu Điều bi: dòng nhóm yếu đổi theo', (
    tester,
  ) async {
    final aiming = analyzeMatches(
      matchesWeakAt(SkillCategory.aiming, at: testToday),
    );
    await pumpCard(tester, aiming);
    expect(
      find.text(Vi.statsMatchWeak(Vi.skill(SkillCategory.aiming), 9, 15, 60)),
      findsOneWidget,
    );
    expect(
      find.textContaining('${Vi.skill(SkillCategory.position)}: hỏng'),
      findsNothing,
    );
    expect(find.text(Vi.statsMatchWeakNone), findsNothing);

    final position = analyzeMatches(
      matchesWeakAt(SkillCategory.position, at: testToday),
    );
    await pumpCard(tester, position);
    final s = position.signals[SkillCategory.position]!;
    expect(
      find.text(
        Vi.statsMatchWeak(
          Vi.skill(SkillCategory.position),
          s.failures,
          s.attempts,
          percentOf(s.failures, s.attempts)!,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('${Vi.skill(SkillCategory.aiming)}: hỏng'),
      findsNothing,
    );
  });

  testWidgets('dòng cỡ mẫu nói số trận và số ván ghi đủ', (tester) async {
    final a = analyzeMatches(
      matchesWeakAt(SkillCategory.aiming, at: testToday),
    );
    expect(a.matches, 3);
    await pumpCard(tester, a);
    expect(find.text(Vi.statsMatchAnalysisTitle), findsOneWidget);
    expect(
      find.text(Vi.statsMatchAnalysisBasis(3, a.fullRacks)),
      findsOneWidget,
    );
    expect(
      find.text('Dựa trên 3 trận, ${a.fullRacks} ván ghi đủ'),
      findsOneWidget,
    );
  });

  testWidgets('không có cú: chỉ câu rỗng, không phần trăm, không NaN', (
    tester,
  ) async {
    final a = analyzeMatches([
      completedMatch('m', const [RackWinner.player], const []),
    ]);
    expect(a.playerShots, 0);
    await pumpCard(tester, a);
    expect(find.text(Vi.statsMatchAnalysisTitle), findsOneWidget);
    expect(find.text(Vi.statsMatchAnalysisEmpty), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Dựa trên'), findsNothing);
  });

  testWidgets('có phá nhưng không có cú phòng thủ: dòng phòng thủ ẩn', (
    tester,
  ) async {
    final a = analyzeMatches([
      completedMatch('m', const [RackWinner.player], [
        shotAt(
          1,
          1,
          RackWinner.player,
          MatchShotType.breakShot,
          MatchShotOutcome.made,
        ),
        shotAt(
          1,
          2,
          RackWinner.player,
          MatchShotType.normal,
          MatchShotOutcome.made,
        ),
      ]),
    ]);
    expect(a.safeties, 0);
    expect(a.proactiveTurnovers, 0);
    await pumpCard(tester, a);
    expect(find.text(Vi.statsBreakLine(1, 100, 0, 0, 0)), findsOneWidget);
    expect(find.textContaining('Phòng thủ:'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('chưa có ván ghi đủ: ẩn dọn bàn, phá-và-dọn và nửa kế tiếp', (
    tester,
  ) async {
    // Ván chỉ ghi nửa chừng: có cú nhưng chưa "ghi đủ".
    final a = analyzeMatches([
      completedMatch('m', const [RackWinner.player], [
        shotAt(
          1,
          1,
          RackWinner.player,
          MatchShotType.breakShot,
          MatchShotOutcome.made,
        ),
        shotAt(
          1,
          2,
          RackWinner.player,
          MatchShotType.normal,
          MatchShotOutcome.missed,
        ),
      ]),
    ]);
    expect(a.playerShots, greaterThan(0));
    expect(a.fullRacks, 0);
    await pumpCard(tester, a);
    expect(find.textContaining('Dọn bàn:'), findsNothing);
    expect(find.textContaining('Phá-và-dọn'), findsNothing);
    expect(find.textContaining('Trượt cú kế tiếp'), findsNothing);
    expect(find.text(Vi.statsMatchAnalysisBasis(1, 0)), findsOneWidget);
  });

  testWidgets('chỉ có cú sau điều bi tốt: ẩn nửa sau điều bi hỏng', (
    tester,
  ) async {
    final a = analyzeMatches(
      matchesWeakAt(SkillCategory.aiming, at: testToday),
    );
    expect(a.nextAfterFailedPosition, 0);
    expect(a.nextAfterGoodPosition, greaterThan(0));
    await pumpCard(tester, a);
    expect(
      find.text(
        Vi.statsPositionFollowUp(
          0,
          0,
          a.missAfterGoodPosition,
          a.nextAfterGoodPosition,
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('sau điều bi hỏng'), findsNothing);
    expect(find.textContaining('sau điều bi tốt'), findsOneWidget);
  });

  group('Vi: dòng hai mẫu số ẩn nửa không có mẫu', () {
    test('statsPositionFollowUp', () {
      expect(
        Vi.statsPositionFollowUp(1, 2, 3, 4),
        'Trượt cú kế tiếp: 1/2 sau điều bi hỏng, 3/4 sau điều bi tốt',
      );
      expect(
        Vi.statsPositionFollowUp(1, 2, 0, 0),
        'Trượt cú kế tiếp: 1/2 sau điều bi hỏng',
      );
      expect(
        Vi.statsPositionFollowUp(0, 0, 3, 4),
        'Trượt cú kế tiếp: 3/4 sau điều bi tốt',
      );
      expect(Vi.statsPositionFollowUp(0, 0, 0, 0), '');
    });
    test('statsSafety', () {
      expect(
        Vi.statsSafety(2, 3, 1, 4),
        'Phòng thủ: thành công 2/3 · 1/4 lần mất lượt chủ động là phòng thủ',
      );
      expect(Vi.statsSafety(2, 3, 0, 0), 'Phòng thủ: thành công 2/3');
      expect(
        Vi.statsSafety(0, 0, 1, 4),
        'Phòng thủ: 1/4 lần mất lượt chủ động là phòng thủ',
      );
      expect(Vi.statsSafety(0, 0, 0, 0), '');
    });
  });

  group('dòng nhóm yếu khi không có nhóm yếu', () {
    testWidgets('đủ mẫu mà không nhóm nào vượt ngưỡng: nói không vượt ngưỡng, không nói thiếu dữ liệu', (
      tester,
    ) async {
      final a = analyzeMatches([
        for (var i = 0; i < 3; i++)
          completedMatch('ok-$i', const [RackWinner.player], [
            for (var n = 1; n <= 5; n++)
              shotAt(1, n, RackWinner.player, MatchShotType.normal, MatchShotOutcome.made),
          ]),
      ]);
      expect(a.weaknesses, isEmpty);
      expect(sampledGroups(a), isNotEmpty);
      await pumpCard(tester, a);
      expect(find.text(Vi.statsMatchWeakNoneOverThreshold(3)), findsOneWidget);
      expect(find.text(Vi.statsMatchWeakNone), findsNothing);
    });

    testWidgets('chưa nhóm nào đủ mẫu: vẫn nói chưa đủ dữ liệu', (tester) async {
      final a = analyzeMatches([
        completedMatch('m', const [RackWinner.player], [
          shotAt(1, 1, RackWinner.player, MatchShotType.normal, MatchShotOutcome.made),
        ]),
      ]);
      expect(sampledGroups(a), isEmpty);
      await pumpCard(tester, a);
      expect(find.text(Vi.statsMatchWeakNone), findsOneWidget);
      expect(find.textContaining('vượt ngưỡng yếu'), findsNothing);
    });
  });

  testWidgets('360x640 chữ lớn: thẻ đầy đủ không tràn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    const p = RackWinner.player;
    const o = RackWinner.opponent;
    const nm = MatchShotType.normal;
    final withSafety = completedMatch('safe', const [p], [
      shotAt(1, 1, p, MatchShotType.breakShot, MatchShotOutcome.made),
      shotAt(1, 2, p, nm, MatchShotOutcome.made, position: PositionOutcome.unsuccessful),
      shotAt(1, 3, p, nm, MatchShotOutcome.missed),
      shotAt(1, 4, o, nm, MatchShotOutcome.missed),
      shotAt(1, 5, p, MatchShotType.safety, MatchShotOutcome.made),
      shotAt(1, 6, o, nm, MatchShotOutcome.missed),
      shotAt(1, 7, p, nm, MatchShotOutcome.made, position: PositionOutcome.successful),
    ]);
    final a = analyzeMatches([
      ...matchesWeakAt(SkillCategory.aiming, at: testToday),
      withSafety,
    ]);
    // Dòng phòng thủ là dòng dài nhất: thẻ phải thật sự dựng nó.
    expect(a.assessedSafeties, greaterThan(0));
    expect(a.weaknesses, isNotEmpty);
    await pumpCard(tester, a);
    await tester.pumpAndSettle();
    expect(find.textContaining('Phòng thủ:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
