import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Gợi ý làm lại bài BU; ẩn khi chưa có tín hiệu. Chỉ là lời nhắc, không đổi hạng.
class RankCheckLine extends ConsumerWidget {
  const RankCheckLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signal = ref.watch(rankCheckSignalProvider);
    if (signal == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(Vi.rankCheck(signal), style: const TextStyle(color: AppColors.warning)),
    );
  }
}
