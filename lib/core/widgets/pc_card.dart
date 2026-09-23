import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Thẻ nền chuẩn của PoolCoachAI.
///
/// Trên nền tối, phân tách bằng viền chứ không bằng đổ bóng — đổ bóng
/// gần như vô hình trên nền xanh đậm.
class PcCard extends StatelessWidget {
  const PcCard({
    required this.child,
    this.padding,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );

    // Dùng Material làm nền để InkWell bên trong hoạt động đúng.
    final card = Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: content,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: card,
    );
  }
}
