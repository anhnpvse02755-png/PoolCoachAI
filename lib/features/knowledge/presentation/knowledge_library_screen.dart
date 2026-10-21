import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/knowledge_lookup.dart';

/// Thư viện kiến thức: mọi bài đọc, gom theo nhóm kỹ năng.
class KnowledgeLibraryScreen extends ConsumerWidget {
  const KnowledgeLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(knowledgeProvider);

    return PcRootScaffold(
      title: Vi.knowledgeLibraryTitle,
      body: articlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (articles) {
          if (articles.isEmpty) {
            return const PcEmptyState(
              icon: Icons.menu_book_outlined,
              title: Vi.knowledgeLibraryEmpty,
              body: '',
            );
          }
          final groups = groupArticlesByCategory(articles);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (cat, items) in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    Vi.skill(cat),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final article in items)
                  PcCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.article_outlined),
                      title: Text(article.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.article(article.id)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
