import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Viên thuốc hiển thị một nhóm kỹ năng, màu theo đúng nhóm đó.
///
/// Màu giữ nguyên ở mọi nơi — bộ lọc bài tập, biểu đồ thống kê, nhãn
/// đồng hồ luyện tập — để người chơi nhìn màu là biết nhóm nào.
class PcSkillChip extends StatelessWidget {
  const PcSkillChip({required this.category, super.key});

  final SkillCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: category.bg,
        border: Border.all(color: category.borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        Vi.skill(category),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: category.fg,
        ),
      ),
    );
  }
}
