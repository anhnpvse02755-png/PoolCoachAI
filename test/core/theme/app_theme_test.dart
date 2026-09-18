import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_typography.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('là theme tối', () {
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('nền scaffold là màu nền màn hình của hệ thiết kế', () {
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.bgScreen);
    });

    test('màu nhấn của scheme là vàng đồng', () {
      expect(AppTheme.dark().colorScheme.primary, AppColors.accent);
    });

    test('thanh tab dưới lấy màu từ theme, không để widget tự đặt', () {
      final nav = AppTheme.dark().navigationBarTheme;
      expect(nav.backgroundColor, AppColors.bgDeep);
      expect(
        nav.iconTheme?.resolve({WidgetState.selected})?.color,
        AppColors.accent,
      );
    });

    test('dựng một lần rồi dùng lại, không tạo mới mỗi lần gọi', () {
      // Mỗi lần dựng là một ThemeData đầy đủ cộng tám lượt tra
      // GoogleFonts. Widget gốc hiện không vẽ lại nên chưa tốn gì, nhưng
      // đặt nó dưới một widget cha hay vẽ lại là thành tiền thật.
      expect(identical(AppTheme.dark(), AppTheme.dark()), isTrue);
    });

    test('kiểu chữ số dùng JetBrains Mono để bảng số không nhảy', () {
      expect(AppTypography.mono.fontFamily, contains('JetBrains'));
    });

    test('thang chữ thân bài vào đúng textTheme', () {
      final text = AppTheme.dark().textTheme;
      expect(text.bodyMedium?.fontSize, AppTypography.body.fontSize);
      expect(text.headlineMedium?.fontSize, AppTypography.h2.fontSize);
      expect(text.labelSmall?.fontSize, AppTypography.label.fontSize);
    });

    test('thanh tiêu đề và đường kẻ lấy màu của hệ thiết kế', () {
      final theme = AppTheme.dark();
      expect(theme.appBarTheme.backgroundColor, AppColors.bgScreen);
      expect(theme.appBarTheme.titleTextStyle?.fontSize,
          AppTypography.h2.fontSize);
      expect(theme.dividerTheme.color, AppColors.border);
    });

    test('nhãn tab chưa chọn đạt tương phản AA trên nền thanh', () {
      final nav = AppTheme.dark().navigationBarTheme;
      final fg = nav.labelTextStyle!.resolve({})!.color!.computeLuminance();
      final bg = nav.backgroundColor!.computeLuminance();
      final ratio = (max(fg, bg) + 0.05) / (min(fg, bg) + 0.05);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'năm nhãn này là chữ điều hướng chính của app, cỡ 12px '
            'nên phải đạt ngưỡng chữ thường 4.5:1',
      );
    });
  });
}
