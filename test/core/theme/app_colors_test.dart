import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('màu nhấn là vàng đồng của hệ Nỉ & Phấn', () {
      expect(AppColors.accent, const Color(0xFFD9A441));
    });

    test('nền màn hình là xanh nỉ', () {
      expect(AppColors.bgScreen, const Color(0xFF12261C));
    });

    test('chữ chính là màu phấn', () {
      expect(AppColors.textPrimary, const Color(0xFFEFE7D6));
    });

    test('thành công và thất bại là hai màu khác nhau', () {
      expect(AppColors.success, isNot(AppColors.danger));
    });
  });
}
