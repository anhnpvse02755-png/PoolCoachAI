import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';

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
            padding: const EdgeInsets.all(16),
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
                      CircleAvatar(
                        radius: 12,
                        child: Text('${entry.$1 + 1}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.$2)),
                    ],
                  ),
                ),
              ),
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
                ...history.reversed.take(_historyLength).map(
                      (log) => _HistoryRow(drill: drill, log: log),
                    ),
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
        ratio == null
            ? Vi.drillRatioUnknown
            : Vi.drillRatioPercent(ratio),
      ),
      subtitle: Text(Vi.shortDate(log.date)),
    );
  }
}
