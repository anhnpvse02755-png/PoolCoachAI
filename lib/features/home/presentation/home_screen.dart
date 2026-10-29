import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_fab_inset.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/features/home/presentation/skill_test_home_line.dart';
import 'package:poolcoachai/features/rank/presentation/rank_card.dart';
import 'package:poolcoachai/features/roadmap/presentation/roadmap_home_line.dart';

/// AI Home — mục 6.1 của thiết kế lát dọc Phase 1.
///
/// Đọc [todayRecommendationProvider] và dựng các khối tiến độ, lịch và gợi ý.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(todayRecommendationProvider);

    return PcRootScaffold(
      title: Vi.homeTitle,
      body: recommendation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (rec) => ListView(
          padding: pcScrollPadding(context, const EdgeInsets.all(16)),
          children: [
            const HomeRankHeader(),
            // Chuỗi ngày tập liên tiếp. 0 là con số thật, hiện bình thường.
            PcCard(
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rec.streak}',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        Text(
                          Vi.homeStreakUnit,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 52, child: VerticalDivider(width: 24)),
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      Vi.homePracticeWeek(rec.practiceSecondsThisWeek),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Vi.homeScheduleTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (rec.todaySchedule.isEmpty)
                    const Text(Vi.homeNoScheduleToday)
                  else
                    ...rec.todaySchedule.map(
                      (slot) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Text(slot.time),
                        title: Text(slot.label),
                        subtitle: slot.cat == null
                            ? null
                            : Text(Vi.skill(slot.cat!)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhóm hôm nay, kèm câu vì sao. Lý do không được nuốt:
            // bảy PickReason ra bảy câu khác nhau ở vi.dart.
            PcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline),
                      const SizedBox(width: 8),
                      Text(
                        Vi.homeTodayTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PcSkillChip(category: rec.cat),
                  const SizedBox(height: 8),
                  Text(
                    Vi.pickReason(
                      rec.reason,
                      Vi.skill(rec.cat),
                      signal: rec.matchSignal,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const RoadmapHomeLine(),
            const SkillTestHomeLine(),

            // Bài tập gợi ý. Hết bài thì nói hết bài, không mượn
            // bài của nhóm khác cho khối đỡ trống.
            if (rec.drill != null) ...[
              const SizedBox(height: 16),
              PcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Vi.homeDrillTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${rec.drill!.level}')),
                      title: Text(rec.drill!.name),
                      subtitle: Text(rec.drill!.unit),
                      trailing: FilledButton(
                        onPressed: () =>
                            context.go(Routes.drill(rec.drill!.id)),
                        child: const Text(Vi.homeDrillOpen),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              PcCard(
                child: Text(
                  Vi.homeDrillAllDone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],

            // Bài đọc. Không có thì ẩn hẳn khối, không thay bài
            // của nhóm khác vào.
            if (rec.article != null) ...[
              const SizedBox(height: 16),
              PcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Vi.homeArticleTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.article_outlined),
                      title: Text(rec.article!.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.article(rec.article!.id)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            PcCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text(Vi.knowledgeLibraryTitle),
                subtitle: const Text(Vi.knowledgeLibraryCardBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.knowledge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
