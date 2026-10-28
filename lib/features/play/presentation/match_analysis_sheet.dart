import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/pool_match.dart';

/// Nội dung phân tích một trận; thuần, không đọc provider.
class MatchAnalysisView extends StatelessWidget {
  const MatchAnalysisView({
    required this.match,
    required this.analysis,
    required this.focus,
    super.key,
  });

  final PoolMatch match;
  final MatchAnalysis analysis;
  final List<MatchFocus> focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = Vi.matchScore(
      match.playerName,
      match.playerScore,
      match.opponentScore,
      match.opponentName,
    );

    if (analysis.playerShots == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(score, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(Vi.matchAnalysisNoShots),
        ],
      );
    }

    final causes = [
      for (final c in LostRackCause.values)
        if ((analysis.lostRackCauses[c] ?? 0) > 0) c,
    ]..sort((a, b) {
        final byCount = analysis.lostRackCauses[b]!.compareTo(
          analysis.lostRackCauses[a]!,
        );
        return byCount != 0 ? byCount : a.index.compareTo(b.index);
      });
    final pb = analysis.playerBreak;
    final ob = analysis.opponentBreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(score, style: theme.textTheme.titleLarge),
        Text(
          Vi.matchAnalysisRacks(analysis.racksWithShots, analysis.fullRacks),
          style: theme.textTheme.bodySmall,
        ),
        if (causes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(Vi.matchAnalysisLostTitle, style: theme.textTheme.titleMedium),
          for (final c in causes)
            Text(Vi.lostRackCause(c, analysis.lostRackCauses[c]!)),
        ],
        const SizedBox(height: 16),
        Text(Vi.matchAnalysisBreakTitle, style: theme.textTheme.titleMedium),
        Text(Vi.matchAnalysisBreak(pb.shots, pb.made, pb.breakAndRuns)),
        if (ob.shots > 0)
          Text(
            Vi.matchAnalysisOpponentBreak(
              match.opponentName,
              ob.shots,
              ob.made,
              ob.breakAndRuns,
            ),
          ),
        const SizedBox(height: 16),
        Text(Vi.matchAnalysisPositionTitle, style: theme.textTheme.titleMedium),
        Text(
          Vi.matchAnalysisPositionFouls(
            analysis.failedPositions,
            analysis.assessedPositions,
            analysis.fouls,
            analysis.scratches,
          ),
        ),
        const SizedBox(height: 16),
        Text(Vi.matchAnalysisFocusTitle, style: theme.textTheme.titleMedium),
        if (focus.isEmpty)
          const Text(Vi.matchAnalysisFocusNone)
        else
          for (final f in focus) ...[
            Text(
              Vi.matchAnalysisFocus(
                Vi.skill(f.signal.category),
                f.signal.failures,
                f.signal.attempts,
              ),
            ),
            if (f.drill != null)
              Text(Vi.matchAnalysisFocusDrill(f.drill!.name)),
          ],
      ],
    );
  }
}

/// Đọc bài tập và nhật ký luyện rồi dựng [MatchAnalysisView] cho [match].
class MatchAnalysisSheet extends ConsumerWidget {
  const MatchAnalysisSheet({required this.match, super.key});

  final PoolMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drills = ref.watch(drillsProvider).value ?? const [];
    final logs = ref.watch(drillLogsProvider).value ?? const [];
    final analysis = analyzeMatches([match]);
    final focus = singleMatchFocus(analysis, drills: drills, logs: logs);
    return MatchAnalysisView(match: match, analysis: analysis, focus: focus);
  }
}

Future<void> showMatchAnalysis(BuildContext context, PoolMatch match) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Vi.matchAnalysisOpen,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          MatchAnalysisSheet(match: match),
        ],
      ),
    ),
  );
}
