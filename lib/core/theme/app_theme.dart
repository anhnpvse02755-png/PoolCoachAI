import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/theme/app_typography.dart';

/// Ghép bảng màu, thang chữ và thang khoảng cách thành ThemeData.
abstract final class AppTheme {
  /// Dựng một lần rồi dùng lại.
  ///
  /// Một lần dựng là cả ThemeData cộng tám lượt tra GoogleFonts, mà
  /// theme thì không đổi trong suốt vòng đời app.
  static ThemeData? _dark;

  static ThemeData dark() => _dark ??= _buildDark();

  static ThemeData _buildDark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgScreen,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.accent,
        onPrimary: AppColors.bgScreen,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgScreen,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h2,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        titleMedium: AppTypography.h3,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelSmall: AppTypography.label,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bgScreen,
      ),
      // NavigationBar của Material 3, khớp với useMaterial3 ở trên.
      //
      // Nhãn dùng textMuted chứ không phải textDisabled: năm nhãn này là
      // chữ điều hướng chính của app, cỡ nhỏ, nên phải qua ngưỡng tương
      // phản 4.5:1. textDisabled chỉ đạt 4.36:1 trên nền bgDeep.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgDeep,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.label.copyWith(color: AppColors.accent)
              : AppTypography.label.copyWith(color: AppColors.textMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textMuted,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bgScreen,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}
