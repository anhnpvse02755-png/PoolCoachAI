import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/cue_performance/cue_win_rate.dart';
import 'package:poolcoachai/domain/training_statistics.dart';
import 'package:poolcoachai/features/stats/presentation/cue_win_rate_block.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillsAsync = ref.watch(drillsProvider);
    final logsAsync = ref.watch(drillLogsProvider);
    final timerSessionsAsync = ref.watch(timerSessionsProvider);
    final matchesAsync = ref.watch(matchesProvider);
    final cues = ref.watch(cueEquipmentProvider).value;

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
          _MetricGrid(
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
                label: Vi.statsDrillDurationTotal,
                value: Vi.statsDrillDurationValue(
                  statistics.totalDrillSeconds,
                  statistics.timedDrillSessionCount,
                ),
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
          _CombinedTrainingPlayCard(stats: statistics.combinedTrainingPlay),
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
          if (cues != null)
            _CueWinRateCard(
              cues: cues,
              report: computeCueWinRates(
                matches: matchesAsync.requireValue,
                knownCueIds: {for (final cue in cues) cue.id},
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
                            const SizedBox(width: 8),
                            // Chưa có buổi chấm điểm thì đây là cả một câu:
                            // xuống dòng trong nửa bên phải, không tràn.
                            Expanded(
                              child: Text(
                                skill.averageTargetRatio == null
                                    ? Vi.statsNoScoredSessions
                                    : Vi.statsPercent(
                                        (skill.averageTargetRatio! * 100)
                                            .round(),
                                      ),
                                textAlign: TextAlign.end,
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

class _CombinedTrainingPlayCard extends StatelessWidget {
  const _CombinedTrainingPlayCard({required this.stats});

  final CombinedTrainingPlayStatistics stats;

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.days.fold<int>(
      1,
      (maxValue, day) => [
        maxValue,
        day.trainingSessions,
        day.matches,
      ].reduce((a, b) => a > b ? a : b),
    );
    final colors = Theme.of(context).colorScheme;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Vi.statsCombinedTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            Vi.statsCombinedSummary(
              stats.trainingSessionCount,
              stats.matchCount,
              stats.activeDays,
              stats.sharedDays,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (stats.trainingSessionCount + stats.matchCount == 0) ...[
            const SizedBox(height: 8),
            const Text(Vi.statsCombinedEmpty),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in stats.days)
                    Expanded(
                      child: Semantics(
                        label: Vi.statsCombinedDaySemantics(
                          day.date.weekday,
                          day.trainingSessions,
                          day.matches,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ActivityBar(
                                    count: day.trainingSessions,
                                    maxCount: maxCount,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  _ActivityBar(
                                    count: day.matches,
                                    maxCount: maxCount,
                                    color: colors.tertiary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(Vi.statsCombinedDayLabel(day.date.weekday)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _ActivityLegend(
                  color: colors.primary,
                  label: Vi.statsCombinedTraining,
                ),
                _ActivityLegend(
                  color: colors.tertiary,
                  label: Vi.statsCombinedPlay,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: count == 0 ? 2 : 8 + 34 * count / maxCount,
    decoration: BoxDecoration(
      color: count == 0 ? color.withValues(alpha: 0.18) : color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _ActivityLegend extends StatelessWidget {
  const _ActivityLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _CueWinRateCard extends StatelessWidget {
  const _CueWinRateCard({required this.cues, required this.report});

  final List<CueEquipment> cues;
  final CueWinRateReport report;

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty && report.unknownCues.isEmpty) {
      return const SizedBox.shrink();
    }
    final sorted = [...cues]..sort((a, b) => a.name.compareTo(b.name));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Vi.cueWinRateTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final cue in sorted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cue.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    CueWinRateBlock(
                      stats: report.statsFor(cue.id),
                      isBest: report.bestCueId == cue.id,
                    ),
                  ],
                ),
              ),
            for (final stats in report.unknownCues)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Vi.equipmentUnknownCue,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    CueWinRateBlock(stats: stats, isBest: false),
                  ],
                ),
              ),
            if (report.bestCueId == null && cues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                Vi.cueVerdictRule(minMatchesForCueVerdict),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lưới ô chỉ số: mỗi ô rộng ít nhất [_minTileWidth], hai tới bốn ô một
/// hàng tuỳ bề ngang. Các ô cùng hàng cao bằng ô nhiều chữ nhất, nên chữ to
/// lên thì ô cao theo chứ không tràn.
class _MetricGrid extends StatefulWidget {
  const _MetricGrid({required this.children});

  static const _minTileWidth = 220.0;

  final List<Widget> children;

  @override
  State<_MetricGrid> createState() => _MetricGridState();
}

class _MetricGridState extends State<_MetricGrid> {
  // Font của app tải lúc chạy và tới sau khung hình đầu. Flutter 3.47 vẽ lại
  // chữ khi font tới nhưng giữ bộ đo kích thước nội tại cũ của chữ
  // (rendering/paragraph.dart, systemFontsDidChange), mà IntrinsicHeight đọc
  // đúng bộ đo đó: hàng ô giữ chiều cao đo bằng font dự phòng, chữ thật rộng
  // hơn thì xuống dòng và tràn khỏi ô. Font đổi thì dựng lại các hàng để chữ
  // được đo lại từ đầu.
  var _fontsVersion = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    super.dispose();
  }

  void _onFontsChanged() => setState(() => _fontsVersion++);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: ValueKey(_fontsVersion),
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / _MetricGrid._minTileWidth)
          .floor()
          .clamp(2, 4);
      return Column(
        children: [
          for (
            var start = 0;
            start < widget.children.length;
            start += columns
          ) ...[
            if (start > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: 8),
                    // Hàng cuối thiếu ô thì chừa chỗ trống cho cột thẳng hàng.
                    Expanded(
                      child: i < widget.children.length
                          ? widget.children[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
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
