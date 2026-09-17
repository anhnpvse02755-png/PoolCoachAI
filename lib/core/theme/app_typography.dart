import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';

/// Thang chữ của PoolCoachAI.
///
/// Be Vietnam Pro cho toàn bộ giao diện — font thiết kế riêng cho tiếng
/// Việt, dấu má cân đối, không vỡ ở chữ hoa có dấu như "MỤC TIÊU".
/// JetBrains Mono cho số liệu vì chữ số đều bề ngang nên bảng thống kê
/// và đồng hồ đếm ngược không bị nhảy.
abstract final class AppTypography {
  static TextStyle get display => GoogleFonts.beVietnamPro(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get h1 => GoogleFonts.beVietnamPro(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.beVietnamPro(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.beVietnamPro(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.beVietnamPro(
        fontSize: 12,
        color: AppColors.textMuted,
      );

  static TextStyle get label => GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.accent,
      );

  /// Dùng cho mọi số liệu: tỷ lệ, streak, giờ tập, đồng hồ đếm.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.accent,
      );
}
