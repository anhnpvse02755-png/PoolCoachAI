import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';

/// AI Home — mục 6.1 của thiết kế lát dọc Phase 1.
///
/// Đọc [todayRecommendationProvider] và dựng bốn khối. Provider trả
/// `null` khi chưa đủ dữ liệu ba nguồn; lúc đó màn hiện trạng thái
/// đang tải chứ **không** hiện số 0 — số 0 lúc chưa biết là số bịa.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(todayRecommendationProvider);

    return PcRootScaffold(
      title: Vi.homeTitle,
      body: rec == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Chuỗi ngày tập liên tiếp. 0 là con số thật, hiện bình thường.
                PcCard(
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 48),
                      const SizedBox(width: 12),
                      Column(
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Nhóm hôm nay, kèm câu vì sao. Lý do không được nuốt:
                // sáu PickReason ra sáu câu khác nhau ở vi.dart.
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
                        Vi.pickReason(rec.reason, Vi.skill(rec.cat)),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

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
                          leading: CircleAvatar(
                            child: Text('${rec.drill!.level}'),
                          ),
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
                          onTap: () =>
                              context.go(Routes.article(rec.article!.id)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
