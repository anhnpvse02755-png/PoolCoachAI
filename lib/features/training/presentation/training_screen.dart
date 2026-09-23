import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Kết quả lần tập gần nhất của một bài.
///
/// Phân biệt ba trạng thái, vì gộp lại là nói dối: chưa từng tập,
/// đã tập mà chưa chấm được, và đã tập có tỉ lệ.
sealed class _LatestResult {
  const _LatestResult();
}

class _NeverTrained extends _LatestResult {
  const _NeverTrained();
}

class _NotScorable extends _LatestResult {
  const _NotScorable();
}

class _Scored extends _LatestResult {
  const _Scored(this.ratio);
  final double ratio;
}

/// Thư viện bài tập — mục 6.2 của thiết kế.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  SkillCategory? _filter;

  /// Lần tập gần nhất của từng bài, quy thành tỉ lệ đạt mục tiêu.
  ///
  /// Log tới đây đã là **cũ nhất trước** theo hợp đồng của repository,
  /// nên ghi đè dần thì cuối vòng còn lại đúng lần gần nhất.
  Map<String, _LatestResult> _latestByDrill(
    List<Drill> drills,
    List<DrillLog> logs,
  ) {
    final drillById = {for (final drill in drills) drill.id: drill};
    final result = <String, _LatestResult>{};
    for (final log in logs) {
      final drill = drillById[log.drillId];
      if (drill == null) continue;
      final ratio = drillRatio(drill, log);
      result[log.drillId] =
          ratio == null ? const _NotScorable() : _Scored(ratio);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final drillsAsync = ref.watch(drillsProvider);
    final logsAsync = ref.watch(drillLogsProvider);

    return PcRootScaffold(
      title: Vi.trainingTitle,
      body: drillsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (drills) {
          final logs = logsAsync.hasValue ? logsAsync.value! : <DrillLog>[];
          final latest = _latestByDrill(drills, logs);
          final filtered = _filter == null
              ? drills
              : drills.where((d) => d.cat == _filter).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text(Vi.trainingFilterAll),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    // Cả sáu nhóm, gồm Cân bi — nhóm thứ sáu mở riêng
                    // chứ không gộp vào A băng.
                    ...SkillCategory.values.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(Vi.skill(cat)),
                          selected: _filter == cat,
                          onSelected: (_) => setState(() => _filter = cat),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final drill = filtered[index];
                    final result = latest[drill.id] ?? const _NeverTrained();

                    return PcCard(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${drill.level}')),
                        title: Text(drill.name),
                        subtitle: Text(drill.unit),
                        trailing: switch (result) {
                          _NeverTrained() =>
                            const Icon(Icons.play_circle_outline),
                          _NotScorable() => Text(
                              Vi.drillRatioUnknown,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          _Scored(:final ratio) => Text(
                              Vi.drillRatioPercent(ratio),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                        },
                        onTap: () => context.go(Routes.drill(drill.id)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
