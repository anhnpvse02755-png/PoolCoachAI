/// Chín nhóm kỹ năng: sáu nhóm cơ bản và ba nhóm nâng cao.
///
/// Khóa giữ tiếng Anh; tên tiếng Việt nằm ở [Vi.skill].
/// Màu xem docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md mục 4.1.
///
/// [kick] và [bank] là **hai nhóm riêng**, rất dễ nhầm:
/// - **Kick shot** — bi cái chạm băng trước rồi mới tới bi mục tiêu.
///   Tiếng Việt: *A băng* (từ tiếng Pháp *à bande*).
/// - **Bank shot** — bi cái chạm bi mục tiêu trước, bi mục tiêu mới
///   chạm băng vào lỗ. Tiếng Việt: *Cân bi* / *Cân băng*.
///
/// PRD bản đầu chỉ có năm nhóm và nhét Cân bi chung với A băng. Gộp như
/// vậy khiến lớp suy luận quy lỗi sai: người chơi hỏng Cân bi sẽ bị
/// `weakestSkill()` báo là yếu A băng rồi giao sai bài tập. Chủ sản
/// phẩm chốt tách riêng.
enum SkillCategory {
  aiming,
  position,
  breakShot,
  safety,
  kick,
  bank,
  dungCo,
  nhayBi,
  matXe;

  /// Đây có phải nhóm nâng cao (spec 2026-10-29 §3) không: [dungCo],
  /// [nhayBi], [matXe].
  bool get isAdvanced => switch (this) {
        SkillCategory.dungCo ||
        SkillCategory.nhayBi ||
        SkillCategory.matXe =>
          true,
        SkillCategory.aiming ||
        SkillCategory.position ||
        SkillCategory.breakShot ||
        SkillCategory.safety ||
        SkillCategory.kick ||
        SkillCategory.bank =>
          false,
      };
}
