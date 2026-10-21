import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/library.dart';
import 'package:poolcoachai/features/coach/presentation/coach_painter.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Thư viện tình huống mẫu theo nhóm (spec mục 9.4). Có `?i=` thì chỉ hiện
/// mục thứ i, to — kịch bản Chrome chụp lần lượt từng mục cho chủ sản phẩm
/// duyệt, như `/rank/layouts`.
class CoachLibraryScreen extends StatelessWidget {
  const CoachLibraryScreen({this.index, super.key});

  final int? index;

  @override
  Widget build(BuildContext context) {
    final all = coachLibrary;
    final i = index;
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.coachLibraryTitle)),
      body: i == null
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final topic in CoachTopic.values) ...[
                  Text(Vi.coachTopic(topic), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (k, e) in all.indexed)
                    if (e.topic == topic) _EntryCard(entry: e, k: k + 1, n: all.length),
                ],
              ],
            )
          : i >= 0 && i < all.length
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _EntryCard(entry: all[i], k: i + 1, n: all.length),
                )
              : const Center(child: Text(Vi.coachLibraryEnd)),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.k, required this.n});

  final CoachLibraryEntry entry;
  final int k;
  final int n;

  @override
  Widget build(BuildContext context) {
    final setup = entry.setup();
    final caption = Vi.coachLibraryCaption(entry.id, k, n);
    final ball = setup.balls.map((b) => b.number).reduce((a, b) => a < b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: InkWell(
        onTap: () => context.push(Routes.coachLibraryEntry(entry.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            AspectRatio(
              aspectRatio: TableLayout.aspectRatio(setup.table),
              child: Semantics(
                label: '$caption. ${Vi.coachTableSummary(setup.balls.length, ball)}',
                child: CustomPaint(
                  painter: CoachPainter(CoachScene(setup: setup, target: ball)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(Vi.coachLibrarySource(entry.source), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
