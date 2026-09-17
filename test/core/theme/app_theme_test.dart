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
  });
}
