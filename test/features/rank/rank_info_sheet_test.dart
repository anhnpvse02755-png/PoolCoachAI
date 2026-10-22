import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/rank/presentation/rank_badge_line.dart';

import '../../support/layout_sweep.dart';
import '../../support/test_data.dart';

void main() {
  testWidgets('điện thoại ngang: bảng giải thích hạng không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(740, 360));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: RankBadgeLine(
            rank: PlayerRank(
              rank: Rank.d,
              source: RankSource.verified,
              buScore: 137,
              testId: 't1',
              onboardingState: OnboardingState.done,
              updatedAt: testToday,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(Vi.rankInfo));
    await tester.pumpAndSettle();
    expect(find.byType(RankInfoSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull);
  });
}
