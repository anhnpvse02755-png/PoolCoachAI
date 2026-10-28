import 'package:poolcoachai/domain/skill_category.dart';

/// Bài BU nào thuộc nhóm kỹ năng nào (spec 2026-10-15 mục 5, chủ sản phẩm
/// duyệt 15/10/2026). Mỗi bài xếp theo cái BU chấm điểm: bi vào → Ngắm bi;
/// chỗ bi cái dừng → Điều bi / Vị trí. F8 và S4 chấm cả hai, xếp Điều bi.
///
/// S8 (Dựng cơ) nối nhóm Dựng cơ (spec 2026-10-29 §5). S9 chấm nhảy bi
/// **hoặc** mát xê nên không cho biết người chơi yếu kỹ thuật nào: không nối
/// nhóm.
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
  'S8': SkillCategory.dungCo,
  'S9': null,
  'S10': SkillCategory.breakShot,
};
