import 'package:flutter/material.dart';

/// Năm nhóm kỹ năng chính thức theo PRD.
///
/// Khóa giữ tiếng Anh; tên tiếng Việt nằm ở [Vi.skill].
/// Màu xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.1.
enum SkillCategory {
  aiming(
    fg: Color(0xFFE8B44C),
    bg: Color(0xFF4A3A14),
    borderColor: Color(0xFF6B5220),
  ),
  position(
    fg: Color(0xFF6FA8D6),
    bg: Color(0xFF1E3648),
    borderColor: Color(0xFF2F5578),
  ),
  breakShot(
    fg: Color(0xFFE2685C),
    bg: Color(0xFF4A2320),
    borderColor: Color(0xFF7A3A34),
  ),
  safety(
    fg: Color(0xFF9B8BD6),
    bg: Color(0xFF322B4A),
    borderColor: Color(0xFF4B4277),
  ),
  bank(
    fg: Color(0xFF4FB3A5),
    bg: Color(0xFF14403C),
    borderColor: Color(0xFF226B62),
  );

  const SkillCategory({
    required this.fg,
    required this.bg,
    required this.borderColor,
  });

  /// Màu chữ và icon.
  final Color fg;

  /// Màu nền viên thuốc.
  final Color bg;

  /// Màu viền viên thuốc.
  final Color borderColor;
}
