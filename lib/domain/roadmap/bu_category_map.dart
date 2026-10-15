import 'package:poolcoachai/domain/skill_category.dart';

/// Bài BU nào thuộc nhóm kỹ năng nào (spec 2026-10-15 mục 5, chủ sản phẩm
/// duyệt 15/10/2026). Mỗi bài xếp theo cái BU chấm điểm: bi vào → Ngắm bi;
/// chỗ bi cái dừng → Điều bi / Vị trí. F8 và S4 chấm cả hai, xếp Điều bi.
///
/// S8 (Dựng cơ) và S9 (Nhảy bi / Mát xê) không khớp nhóm nào: tập ngắm không
/// giúp dựng cơ hay nhảy bi, nên không giao bài sai mục đích.
///
/// Thứ tự khoá là thứ tự hiển thị F1…F8, S1…S10.
const buDrillCategory = <String, SkillCategory?>{
  'F1': SkillCategory.aiming,
  'F2': SkillCategory.position,
  'F3': SkillCategory.position,
  'F4': SkillCategory.position,
  'F5': SkillCategory.position,
  'F6': SkillCategory.aiming,
  'F7': SkillCategory.aiming,
  'F8': SkillCategory.position,
  'S1': SkillCategory.aiming,
  'S2': SkillCategory.aiming,
  'S3': SkillCategory.position,
  'S4': SkillCategory.position,
  'S5': SkillCategory.safety,
  'S6': SkillCategory.kick,
  'S7': SkillCategory.bank,
  'S8': null,
  'S9': null,
  'S10': SkillCategory.breakShot,
};
