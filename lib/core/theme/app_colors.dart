import 'package:flutter/material.dart';

/// Bảng màu "Nỉ & Phấn".
/// Xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.1.
abstract final class AppColors {
  // Nền & viền — sắc nỉ bàn bida
  static const bgDeep = Color(0xFF0E1F16);
  static const bgScreen = Color(0xFF12261C);
  static const surface = Color(0xFF18301F);
  static const surfaceRaised = Color(0xFF1B3527);
  static const border = Color(0xFF27462F);
  static const borderStrong = Color(0xFF3A6044);

  // Nhấn & chữ — phấn và đồng
  static const accent = Color(0xFFD9A441);
  static const accentBright = Color(0xFFE8BC63);
  static const textPrimary = Color(0xFFEFE7D6);
  static const textSecondary = Color(0xFFC6D3C6);
  static const textMuted = Color(0xFF9FB0A3);
  static const textDisabled = Color(0xFF6F8677);

  // Trạng thái
  static const success = Color(0xFF5FBF7E);
  static const danger = Color(0xFFE2685C);
  static const warning = Color(0xFFE5A93C);
  static const info = Color(0xFF6FA8D6);
}
