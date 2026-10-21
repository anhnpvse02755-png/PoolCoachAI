import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/training_statistics.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillsAsync = ref.watch(drillsProvider);
    final logsAsync = ref.watch(drillLogsProvider);
    final timerSessionsAsync = ref.watch(timerSessionsProvider);
    final matchesAsync = ref.watch(matchesProvider);

    if (drillsAsync.hasError ||
        logsAsync.hasError ||
        timerSessionsAsync.hasError ||
        matchesAsync.hasError) {
      return const PcRootScaffold(
        title: Vi.statsTitle,
        body: PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
      );
    }
    if (!drillsAsync.hasValue ||
        !logsAsync.hasValue ||
        !timerSessionsAsync.hasValue ||
        !matchesAsync.hasValue) {
      return const PcRootScaffold(
        title: Vi.statsTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final statistics = computeTrainingStatistics(
      drills: drillsAsync.requireValue,
      logs: logsAsync.requireValue,
      timerSessions: timerSessionsAsync.requireValue,
      matches: matchesAsync.requireValue,
      today: ref.watch(nowProvider)(),
    );

    return PcRootScaffold(
      title: Vi.statsTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(Vi.statsOverview, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _MetricCard(
                label: Vi.statsTotalSessions,
                value: '${statistics.totalSessionCount}',
              ),
              _MetricCard(
                label: Vi.statsDrillSessions,
                value: '${statistics.drillSessionCount}',
              ),
              _MetricCard(
                label: Vi.statsTimerSessions,
                value: '${statistics.timerSessionCount}',
              ),
              _MetricCard(
                label: Vi.statsTimerTotal,
                value: Vi.statsDuration(statistics.totalTimerSeconds),
              ),
              _MetricCard(
                label: Vi.statsTimerWeek,
                value: Vi.statsDuration(statistics.timerSecondsThisWeek),
              ),
              _MetricCard(
                label: Vi.statsStreak,
                value: Vi.statsStreakValue(statistics.streakDays),
              ),
              _MetricCard(
                label: Vi.statsRecordedMatches,
                value: Vi.statsMatchCount(
                  statistics.recordedMatchCount,
                  statistics.completedMatchCount,
                ),
              ),
              _MetricCard(
                label: Vi.statsMatchWinsLosses,
                value: '${statistics.matchWins} / ${statistics.matchLosses}',
              ),
              _MetricCard(
                label: Vi.statsRecordedShots,
                value: '${statistics.recordedShotCount}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          PcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Vi.statsMatchDetails,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (statistics.recordedShotCount == 0)
                  const Text(Vi.statsNoShotRecords)
                else ...[
                  _MatchStatLine(
                    label: Vi.statsBreaks,
                    value: statistics.breakShotCount,
                  ),
                  _MatchStatLine(
                    label: Vi.statsSafeties,
                    value: statistics.safetyShotCount,
                  ),
                  _MatchStatLine(
                    label: Vi.statsMisses,
                    value: statistics.missedShotCount,
                  ),
                  _MatchStatLine(
                    label: Vi.statsFouls,
                    value: statistics.foulCount,
                  ),
                  _MatchStatLine(
                    label: Vi.statsScratches,
                    value: statistics.scratchCount,
                  ),
                  _MatchStatLine(
                    label: Vi.statsPositionSuccess,
                    value: Vi.statsPositionCount(
                      statistics.successfulPositions,
                      statistics.assessedPositions,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(Vi.statsSkills, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          PcCard(
            child: Column(
              children: [
                for (final skill in statistics.skills)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(Vi.skill(skill.category))),
                            Text(
                              skill.averageTargetRatio == null
                                  ? Vi.statsNoScoredSessions
                                  : Vi.statsPercent(
                                      (skill.averageTargetRatio! * 100).round(),
                                    ),
                            ),
                          ],
                        ),
                        if (skill.averageTargetRatio != null) ...[
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: skill.averageTargetRatio!.clamp(0, 1),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${skill.scoredSessions} ${Vi.statsScoredSessions}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            Vi.statsDrillTrends,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (statistics.drillTrends.isEmpty)
            const PcCard(child: Text(Vi.statsNoDrillTrends))
          else
            ...statistics.drillTrends.map(
              (trend) => _DrillTrendCard(trend: trend),
            ),
          const SizedBox(height: 12),
          const PcCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Expanded(child: Text(Vi.statsMatchAnalysisNotAvailable)),
              ],
            ),
          ),
          if (statistics.totalSessionCount == 0) ...[
            const SizedBox(height: 8),
            const PcCard(child: Text(Vi.statsNoTraining)),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => PcCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _MatchStatLine extends StatelessWidget {
  const _MatchStatLine({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$value'),
      ],
    ),
  );
}

class _DrillTrendCard extends StatelessWidget {
  const _DrillTrendCard({required this.trend});

  final DrillTrainingTrend trend;

  @override
  Widget build(BuildContext context) {
    final percentages = trend.targetRatios
        .map((ratio) => (ratio * 100).round())
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trend.drill.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${Vi.skill(trend.drill.cat)} · ${trend.targetRatios.length} ${Vi.statsScoredSessions}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (index, ratio) in trend.targetRatios.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Semantics(
                          label: Vi.statsPercent(percentages[index]),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 8 + 40 * ratio.clamp(0, 1).toDouble(),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Vi.statsRecentResults(percentages),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
