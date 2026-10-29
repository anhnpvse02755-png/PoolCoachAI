import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Trạng thái rỗng dùng cho các màn chưa có nội dung.
///
/// Mỗi màn ở mức "khung" phải dùng widget này để giải thích rõ sẽ có gì
/// ở bản sau, thay vì để trắng.
class PcEmptyState extends StatelessWidget {
  const PcEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Nút hành động tuỳ chọn, ví dụ "Về trang chủ" ở màn không tìm thấy.
  ///
  /// Vắng mặt thì không chừa khoảng trống nào — trạng thái rỗng bình
  /// thường không có việc gì để người dùng bấm.
  final Widget? action;

  /// Gọn: bỏ biểu tượng và thu đệm, khi chỗ còn lại quá thấp để chữ khỏi bị
  /// nút nổi che.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Cuộn được: máy ngang mà bàn phím mở thì chỗ còn lại thấp hơn nội dung.
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(icon, size: 44, color: AppColors.textDisabled),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
