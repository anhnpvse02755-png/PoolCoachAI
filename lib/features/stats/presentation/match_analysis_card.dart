import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';

/// Thẻ "Phân tích trận gần đây" trên màn Thống kê; thuần, không đọc provider.
/// Dòng nào có mẫu số 0 thì không vẽ, để không bao giờ hiện 0%, NaN hay null.
class MatchAnalysisCard extends StatelessWidget {
  const MatchAnalysisCard({required this.analysis, super.key});

  final MatchAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = analysis;
    final title = Text(
      Vi.statsMatchAnalysisTitle,
      style: theme.textTheme.titleMedium,
    );

    if (a.playerShots == 0) {
      return PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 8),
            const Text(Vi.statsMatchAnalysisEmpty),
          ],
        ),
      );
    }

    final pb = a.playerBreak;
    final lines = <String>[
      if (pb.shots > 0)
        Vi.statsBreakLine(
          pb.shots,
          percentOf(pb.made, pb.shots)!,
          pb.dry,
          pb.fouls,
          pb.scratches,
        ),
      if (pb.racksBroken > 0)
        Vi.statsBreakAndRun(pb.breakAndRuns, pb.racksBroken),
      if (a.fullRacks > 0) Vi.statsRunOuts(a.runOuts),
      if (a.normalShots > 0)
        Vi.statsOffense(
          a.missedNormal,
          a.normalShots,
          percentOf(a.missedNormal, a.normalShots)!,
        ),
      if (a.assessedPositions > 0)
        Vi.statsPositionMiss(
          a.failedPositions,
          a.assessedPositions,
          percentOf(a.failedPositions, a.assessedPositions)!,
        ),
      if (a.nextAfterFailedPosition > 0 || a.nextAfterGoodPosition > 0)
        Vi.statsPositionFollowUp(
          a.missAfterFailedPosition,
          a.nextAfterFailedPosition,
          a.missAfterGoodPosition,
          a.nextAfterGoodPosition,
        ),
      if (a.assessedSafeties > 0 || a.proactiveTurnovers > 0)
        Vi.statsSafety(
          a.successfulSafeties,
          a.assessedSafeties,
          a.safetyTurnovers,
          a.proactiveTurnovers,
        ),
      Vi.statsErrors(a.fouls, a.scratches, a.playerShots),
    ];

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(line),
            ),
          const SizedBox(height: 8),
          Text(Vi.statsMatchWeakTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (a.weaknesses.isEmpty)
            Text(
              sampledGroups(a).isEmpty
                  ? Vi.statsMatchWeakNone
                  : Vi.statsMatchWeakNoneOverThreshold(a.matches),
            )
          else
            for (final w in a.weaknesses)
              Text(
                Vi.statsMatchWeak(
                  Vi.skill(w.category),
                  w.failures,
                  w.attempts,
                  percentOf(w.failures, w.attempts)!,
                ),
              ),
          const SizedBox(height: 8),
          Text(
            Vi.statsMatchAnalysisBasis(a.matches, a.fullRacks),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
