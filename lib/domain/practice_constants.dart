/// Hằng số của lớp suy luận.
///
/// Lấy nguyên từ Claude_desktop/PoolCoachAI_SPEC.md mục 5.1 — đã được
/// kiểm chứng ở prototype, không tự chỉnh.
abstract final class PracticeConstants {
  /// Số buổi tối thiểu trong một nhóm kỹ năng để dám kết luận về nó.
  static const minSessions = 3;

  /// Buổi càng cũ trọng số càng giảm, nhân dồn theo cấp số nhân.
  static const recencyDecay = 0.85;

  /// Dưới ngưỡng này coi là điểm yếu.
  static const weakCutoff = 55;

  /// Từ ngưỡng này trở lên coi là điểm mạnh.
  static const strongCutoff = 75;

  /// Số buổi đạt liên tiếp để coi là sẵn sàng lên cấp.
  static const readyStreak = 3;

  /// Trần khi đưa ratio vào tính mastery, tránh một buổi ăn may kéo
  /// điểm lên quá cao.
  static const ratioCap = 1.2;

  /// Chênh lệch tối thiểu giữa hai nửa để gọi là có xu hướng.
  static const trendThreshold = 0.1;
}
