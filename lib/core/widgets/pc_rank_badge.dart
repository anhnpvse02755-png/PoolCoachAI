import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Huy hiệu hạng, đổi màu theo nhóm.
///
/// Xám xanh cho nhóm phong trào K→G, vàng đồng từ F trở lên khi bước
/// vào sân chơi cạnh tranh, trắng phấn cho Professional.
class PcRankBadge extends StatelessWidget {
  const PcRankBadge({required this.rank, this.showWord = false, super.key});

  final Rank rank;

  /// Khi bật, hiện "HẠNG G" thay vì chỉ "G".
  final bool showWord;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, borderColor) = switch (rank.group) {
      RankGroup.amateur => (
          const Color(0xFF26412E),
          const Color(0xFF8FA396),
          AppColors.borderStrong,
        ),
      RankGroup.competitive => (
          const Color(0xFF4A3A14),
          const Color(0xFFE8B44C),
          const Color(0xFF6B5220),
        ),
      RankGroup.pro => (
          AppColors.textPrimary,
          AppColors.bgScreen,
          AppColors.textPrimary,
        ),
    };

    final text = showWord
        ? '${Vi.rankWord.toUpperCase()} ${rank.label}'
        : rank.label;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
