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

/// Màn đọc một bài kiến thức — mục 6.5 của thiết kế.
///
/// Quan hệ với bài tập là **hỗ trợ, không phải phụ thuộc cứng**: bài
/// đọc mở được độc lập, và khối bài tập liên quan chỉ hiện khi bài đó
/// thật sự khai báo `relatedDrillIds`.
class KnowledgeScreen extends ConsumerWidget {
  const KnowledgeScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeAsync = ref.watch(knowledgeProvider);

    return knowledgeAsync.when(
      loading: () => const PcRootScaffold(
        title: Vi.knowledgeTitle,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const PcRootScaffold(
        title: Vi.knowledgeTitle,
        body: PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
      ),
      data: (articles) {
        final article = articles.where((a) => a.id == articleId).firstOrNull;
        if (article == null) {
          return PcRootScaffold(
            title: Vi.knowledgeTitle,
            body: PcEmptyState(
              icon: Icons.help_outline,
              title: Vi.notFoundTitle,
              body: Vi.notFoundBody,
              action: FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text(Vi.notFoundAction),
              ),
            ),
          );
        }

        // Bài tập liên quan đọc từ stream bài tập, không từ seed.
        // Id trỏ tới bài không còn tồn tại thì bỏ qua, không dựng một
        // dòng trống mà bấm vào ra màn không tìm thấy.
        final drillsAsync = ref.watch(drillsProvider);
        final allDrills =
            drillsAsync.hasValue ? drillsAsync.value! : const <Drill>[];
        final related = article.relatedDrillIds
            .map((id) => allDrills.where((d) => d.id == id).firstOrNull)
            .nonNulls
            .toList();

        return PcRootScaffold(
          title: article.title,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PcSkillChip(category: article.cat),
                    const SizedBox(height: 12),
                    Text(
                      article.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  Vi.knowledgeRelatedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...related.map(
                  (drill) => PcCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${drill.level}')),
                      title: Text(drill.name),
                      subtitle: Text(drill.unit),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.drill(drill.id)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
