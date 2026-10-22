import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_readable_width.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';

/// Mọi sơ đồ bài kiểm tra BU, theo thứ tự đề → bản → bài → hình.
///
/// Có `?i=` thì chỉ hiện sơ đồ thứ i, to: bài chạy Chrome chụp lần lượt từng
/// sơ đồ cho chủ sản phẩm xem (spec mục 5.5).
class LayoutGalleryScreen extends StatelessWidget {
  const LayoutGalleryScreen({this.index, super.key});

  final int? index;

  @override
  Widget build(BuildContext context) {
    final all = allLayouts();
    final i = index;
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.buLayoutsTitle)),
      body: PcReadableWidth(child: i == null
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final (k, l) in all.indexed) _LayoutCard(layout: l, k: k + 1, n: all.length),
              ],
            )
          : i >= 0 && i < all.length
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _LayoutCard(layout: all[i], k: i + 1, n: all.length),
                )
              : const Center(child: Text(Vi.buLayoutsEnd))),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({required this.layout, required this.k, required this.n});

  final BuLayout layout;
  final int k;
  final int n;

  @override
  Widget build(BuildContext context) {
    final caption = Vi.buLayoutCaption(layout, k, n);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          BuLayoutView(layout: layout, semanticLabel: caption),
          const SizedBox(height: AppSpacing.sm),
          Text(Vi.buDrillSetup(layout.drillId, layout.version)),
          const SizedBox(height: AppSpacing.xs),
          Text(Vi.buLayoutSource(layout.source), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
