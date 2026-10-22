import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_recommendation.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/rng.dart';

/// Màn Huấn luyện viên, mở đè lên shell từ nút tròn ở mọi tab (spec Coach
/// mục 4.1): thẻ "Nên luyện gì", thẻ "Tình huống", ô Trò chuyện (sắp có).
///
/// Có Scaffold và AppBar riêng vì nó nằm ngoài shell 5 tab.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  static const startKey = Key('coach-start');
  static const libraryKey = Key('coach-library-link');
  static const practiceKey = Key('coach-rec-practice');
  static const toolKey = Key('coach-rec-tool');
  static Key topicKey(CoachTopic t) => Key('coach-topic-${t.name}');
  static Key difficultyKey(CoachDifficulty d) => Key('coach-difficulty-${d.name}');

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  /// Lựa chọn của người chơi; null là theo thẻ gợi ý.
  CoachTopic? _topic;
  CoachDifficulty? _difficulty;

  CoachDifficulty _defaultDifficulty(CoachTopic topic) =>
      coachDifficultyFor(ref.read(playerIntelligenceProvider)?.categories[categoryOf(topic)]);

  void _start(CoachTopic topic, CoachDifficulty d) {
    final seed = coachSeedFrom(ref.read(nowProvider)());
    context.push(Routes.coachGenerated(topic.name, d.name, seed));
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(coachRecommendationProvider);
    ref.watch(playerIntelligenceProvider);
    final topic = _topic ?? rec?.topic ?? CoachTopic.aiming;
    final difficulty = _difficulty ?? _defaultDifficulty(topic);
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(Vi.coachTitle)),
      body: PcReadableWidth(child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (rec != null) ...[
            _RecCard(rec: rec, onPractice: () => _start(rec.topic, _defaultDifficulty(rec.topic))),
            const SizedBox(height: AppSpacing.lg),
          ],
          PcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Vi.coachSituationsTitle, style: theme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(Vi.coachSituationsBody, style: theme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Text(Vi.coachTopicLabel, style: theme.labelLarge),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final t in CoachTopic.values)
                      ChoiceChip(
                        key: CoachScreen.topicKey(t),
                        label: Text(Vi.coachTopic(t)),
                        selected: t == topic,
                        onSelected: (_) => setState(() {
                          _topic = t;
                          _difficulty = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(Vi.coachDifficultyLabel, style: theme.labelLarge),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final d in CoachDifficulty.values)
                      ChoiceChip(
                        key: CoachScreen.difficultyKey(d),
                        label: Text(Vi.coachDifficulty(d)),
                        selected: d == difficulty,
                        onSelected: (_) => setState(() => _difficulty = d),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: CoachScreen.startKey,
                  onPressed: () => _start(topic, difficulty),
                  child: const Text(Vi.coachStart),
                ),
                TextButton(
                  key: CoachScreen.libraryKey,
                  onPressed: () => context.push(Routes.coachLibrary),
                  child: const Text(Vi.coachLibraryLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Vi.coachChatSoonTitle, style: theme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(Vi.coachComing, style: theme.bodySmall),
              ],
            ),
          ),
        ],
      )),
    );
  }
}

/// Thẻ "Nên luyện gì" (spec mục 10.3): lý do chọn nhóm, số liệu của nhóm,
/// lỗi lặp lại kèm công cụ, nút luyện tình huống.
class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, required this.onPractice});

  final CoachRecommendation rec;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final stats = rec.stats;
    final unsupported = rec.unsupported;
    final group = stats.recurring;
    final tool = rec.tool;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Vi.coachRecTitle, style: theme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (unsupported != null) Text(Vi.coachTopicUnsupported(unsupported)),
          Text(Vi.coachRecReason(rec.topicReason, rec.topic)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            stats.enough
                ? Vi.coachRecSolved(stats.solved, stats.total)
                : Vi.coachRecNotEnough(stats.total, coachStatsMin),
            style: theme.bodySmall,
          ),
          if (group != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(Vi.coachRecRecurring(group, stats.recurringCount, stats.total)),
          ],
          if (tool != null)
            TextButton(
              key: CoachScreen.toolKey,
              onPressed: () => switch (tool) {
                CoachTool.simulator => context.go(Routes.simulator),
                CoachTool.planner => context.go(Routes.planner),
                CoachTool.article => context.push(Routes.article(rec.article!.id)),
              },
              child: Text(switch (tool) {
                CoachTool.simulator => Vi.coachRecToolSimulator,
                CoachTool.planner => Vi.coachRecToolPlanner,
                CoachTool.article => Vi.coachRecToolArticle(rec.article!.title),
              }),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(
            key: CoachScreen.practiceKey,
            onPressed: onPractice,
            child: Text(Vi.coachRecPractice(rec.topic)),
          ),
        ],
      ),
    );
  }
}
