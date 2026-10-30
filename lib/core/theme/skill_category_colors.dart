import 'package:flutter/painting.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Màu giao diện của từng nhóm kỹ năng. Nằm ngoài lib/domain để lõi
/// miền không phải import Flutter (helper máy chủ biên dịch không cần
/// dart:ui). Màu xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md
/// mục 4.1.
extension SkillCategoryColors on SkillCategory {
  /// Màu chữ và icon.
  Color get fg => switch (this) {
        SkillCategory.aiming => const Color(0xFFE8B44C),
        SkillCategory.position => const Color(0xFF6FA8D6),
        SkillCategory.breakShot => const Color(0xFFE2685C),
        SkillCategory.safety => const Color(0xFF9B8BD6),
        SkillCategory.kick => const Color(0xFF4FB3A5),
        SkillCategory.bank => const Color(0xFFD98AC0),
        SkillCategory.dungCo => const Color(0xFFA3C85A),
        SkillCategory.nhayBi => const Color(0xFFF0904A),
        SkillCategory.matXe => const Color(0xFFB4BCCB),
      };

  /// Màu nền viên thuốc.
  Color get bg => switch (this) {
        SkillCategory.aiming => const Color(0xFF4A3A14),
        SkillCategory.position => const Color(0xFF1E3648),
        SkillCategory.breakShot => const Color(0xFF4A2320),
        SkillCategory.safety => const Color(0xFF322B4A),
        SkillCategory.kick => const Color(0xFF14403C),
        SkillCategory.bank => const Color(0xFF43213A),
        SkillCategory.dungCo => const Color(0xFF2F3E17),
        SkillCategory.nhayBi => const Color(0xFF4A2A12),
        SkillCategory.matXe => const Color(0xFF2E333D),
      };

  /// Màu viền viên thuốc.
  Color get borderColor => switch (this) {
        SkillCategory.aiming => const Color(0xFF6B5220),
        SkillCategory.position => const Color(0xFF2F5578),
        SkillCategory.breakShot => const Color(0xFF7A3A34),
        SkillCategory.safety => const Color(0xFF4B4277),
        SkillCategory.kick => const Color(0xFF226B62),
        SkillCategory.bank => const Color(0xFF6F3760),
        SkillCategory.dungCo => const Color(0xFF4C6426),
        SkillCategory.nhayBi => const Color(0xFF7A4620),
        SkillCategory.matXe => const Color(0xFF4A5262),
      };
}
