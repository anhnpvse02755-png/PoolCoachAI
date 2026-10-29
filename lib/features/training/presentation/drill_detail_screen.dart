import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/knowledge_lookup.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/training/presentation/skill_test_card.dart';

/// Chi tiết một bài tập — mục 6.3 của thiết kế.
class DrillDetailScreen extends ConsumerWidget {
  const DrillDetailScreen({required this.drillId, super.key});

  final String drillId;

  /// Số buổi gần nhất hiện trong khối lịch sử.
  static const _historyLength = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillsAsync = ref.watch(drillsProvider);
    final logsAsync = ref.watch(drillLogsProvider);
    final articles = ref.watch(knowledgeProvider).value ?? const [];
    final related = articlesForDrill(drillId, articles);

    return drillsAsync.when(
      loading: () => const PcRootScaffold(
        title: Vi.trainingTitle,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const PcRootScaffold(
        title: Vi.trainingTitle,
        body: PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
      ),
      data: (drills) {
        final drill = drills.where((d) => d.id == drillId).firstOrNull;
        if (drill == null) {
          return PcRootScaffold(
            title: Vi.trainingTitle,
            body: PcEmptyState(
              icon: Icons.help_outline,
              title: Vi.notFoundTitle,
              body: Vi.notFoundBody,
              action: FilledButton(
                onPressed: () => context.go(Routes.training),
                child: const Text(Vi.notFoundAction),
              ),
            ),
          );
        }

        final logs = logsAsync.hasValue ? logsAsync.value! : <DrillLog>[];
        final history = logs.where((l) => l.drillId == drillId).toList();

        return PcRootScaffold(
          title: drill.name,
          body: ListView(
            padding: pcScrollPadding(context, const EdgeInsets.all(16)),
            children: [
              PcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PcSkillChip(category: drill.cat),
                        const SizedBox(width: 8),
                        Text(
                          Vi.drillLevel(drill.level),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      drill.goal,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Vi.drillUnitLabel(drill.unit),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                Vi.drillStepsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...drill.steps.indexed.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 12, child: Text('${entry.$1 + 1}')),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.$2)),
                    ],
                  ),
                ),
              ),
              ..._advancedBlock(context, drill),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  Vi.drillReadArticles,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...related.map(
                  (article) => PcCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.article_outlined),
                      title: Text(article.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.article(article.id)),
                    ),
                  ),
                ),
              ],
              if (logsAsync.hasValue) ...[
                const SizedBox(height: 16),
                _ReadinessCard(drill: drill, logs: history),
              ],
              SkillTestCard(drill: drill),
              const SizedBox(height: 24),
              // Lịch sử hiện tỉ lệ đạt mục tiêu, không phải điểm thô:
              // "9" một mình không nói lên bài đó cần trúng mấy trên
              // mấy mới gọi là đạt.
              if (history.isNotEmpty) ...[
                Text(
                  Vi.drillHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...history.reversed
                    .take(_historyLength)
                    .map((log) => _HistoryRow(drill: drill, log: log)),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: () => context.go(Routes.drillSession(drill.id)),
                icon: const Icon(Icons.play_arrow),
                label: const Text(Vi.drillStartAction),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Nguồn, cảnh báo nỉ và nút sơ đồ BU của bài nâng cao.
///
/// Cảnh báo nỉ chỉ cho Nhảy bi và Mát xê; Dựng cơ chưa có mẹo kỹ thuật có
/// nguồn nên nói thẳng điều đó. Bài cũ không có gì ở đây.
List<Widget> _advancedBlock(BuildContext context, Drill drill) {
  final provenance = drillProvenanceOf(drill.id);
  final showWarning =
      drill.cat == SkillCategory.nhayBi || drill.cat == SkillCategory.matXe;
  return [
    if (drill.cat == SkillCategory.dungCo) ...[
      const SizedBox(height: 8),
      const Text(Vi.drillNoSourcedTips),
    ],
    if (showWarning) ...[
      const SizedBox(height: 8),
      const PcCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined),
            SizedBox(width: 8),
            Expanded(child: Text(Vi.drillClothWarning)),
          ],
        ),
      ),
    ],
    if (provenance != null) ...[
      const SizedBox(height: 8),
      Text(
        Vi.drillSource(drill.cat, provenance),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () => context.push(
            Routes.rankLayoutsOf(provenance.buDrillId, provenance.version),
          ),
          child: const Text(Vi.drillOpenBuLayouts),
        ),
      ),
    ],
  ];
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.drill, required this.logs});

  final Drill drill;
  final List<DrillLog> logs;

  @override
  Widget build(BuildContext context) {
    final passCount = consecutivePassCount(drill, logs);
    const requiredCount = PracticeConstants.readyStreak;

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Vi.drillReadinessTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: passCount / requiredCount),
          const SizedBox(height: 8),
          Text(Vi.drillReadinessProgress(passCount)),
          if (passCount == requiredCount) ...[
            const SizedBox(height: 4),
            const Text(Vi.drillReadinessQualified),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.drill, required this.log});

  final Drill drill;
  final DrillLog log;

  @override
  Widget build(BuildContext context) {
    final ratio = drillRatio(drill, log);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.history),
      title: Text(
        ratio == null ? Vi.drillRatioUnknown : Vi.drillRatioPercent(ratio),
      ),
      subtitle: Text(Vi.shortDate(log.date)),
    );
  }
}
