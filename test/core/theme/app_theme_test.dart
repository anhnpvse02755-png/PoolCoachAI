import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
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
      final nav = AppTheme.dark().bottomNavigationBarTheme;
      expect(nav.backgroundColor, AppColors.bgDeep);
      expect(nav.selectedItemColor, AppColors.accent);
      expect(nav.type, BottomNavigationBarType.fixed);
    });

    test('nhãn tab chưa chọn đạt tương phản AA trên nền thanh', () {
      final nav = AppTheme.dark().bottomNavigationBarTheme;
      final fg = nav.unselectedItemColor!.computeLuminance();
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
