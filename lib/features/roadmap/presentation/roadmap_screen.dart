import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/roadmap/presentation/goal_picker.dart';
import 'package:poolcoachai/features/roadmap/presentation/step_tile.dart';

/// `/training/roadmap` — chưa có mục tiêu thì chọn, có rồi thì xem lộ trình.
class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  bool _changing = false;

  @override
  Widget build(BuildContext context) {
    final roadmap = ref.watch(roadmapProvider);
    return PcRootScaffold(
      title: Vi.roadmapTitle,
      body: roadmap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (value) => value == null || _changing
            ? GoalPicker(
                onPicked: () => setState(() => _changing = false),
                onCancel: value == null
                    ? null
                    : () => setState(() => _changing = false),
              )
            : RoadmapView(
                roadmap: value,
                onChange: () => setState(() => _changing = true),
              ),
      ),
    );
  }
}

class RoadmapView extends ConsumerWidget {
  const RoadmapView({
    required this.roadmap,
    required this.onChange,
    super.key,
  });

  final Roadmap roadmap;
  final VoidCallback onChange;

  static String _subject(Achievement achievement, Map<String, Drill> drills) {
    final key = achievement.refId.split(':').last;
    final category = SkillCategory.values.asNameMap()[key];
    if (category != null) return Vi.skill(category);
    return drills[key]?.name ?? key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final drills = {
      for (final drill
          in ref.watch(drillsProvider).value ?? const <Drill>[])
        drill.id: drill,
    };
    final achievements =
        ref.watch(achievementsProvider).value ?? const <Achievement>[];
    final today = ref.watch(nowProvider)();
    final need = Vi.roadmapNeed(roadmap);
    final finish = roadmap.finish;
    final shown =
        roadmap.steps.where((step) => step.status != StepStatus.khongKip);

    Widget tile(RoadmapStep step) => StepTile(
          step: step,
          drill: drills[step.drillId],
          today: today,
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Vi.roadmapHeadline(
                  roadmap,
                  tournamentName: ref
                      .watch(linkedTournamentProvider)
                      .value
                      ?.name,
                ),
                style: theme.textTheme.titleMedium,
              ),
              if (need != null) Text(need),
              if (roadmap.blocked case final block?)
                Text(Vi.goalBlocked(block)),
              if (roadmap.achieved)
                const Text(Vi.roadmapAchieved)
              else if (finish != null)
                Text(Vi.finishLine(finish)),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onChange,
                    child: const Text(Vi.goalChange),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(roadmapRepositoryProvider)!.clearGoal(),
                    child: const Text(Vi.goalClear),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final step in shown) tile(step),
        if (roadmap.missed.isNotEmpty)
          ExpansionTile(
            title: const Text(Vi.roadmapMissedTitle),
            children: [for (final step in roadmap.missed) tile(step)],
          ),
        const SizedBox(height: 16),
        Text(Vi.achievementsTitle, style: theme.textTheme.titleMedium),
        if (achievements.isEmpty)
          const Text(Vi.achievementsEmpty)
        else
          for (final achievement in achievements)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(
                Vi.achievement(
                  achievement.kind,
                  _subject(achievement, drills),
                ),
              ),
              subtitle: Text(Vi.shortDate(achievement.achievedAt)),
            ),
      ],
    );
  }
}
