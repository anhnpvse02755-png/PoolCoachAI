import 'package:poolcoachai/domain/skill_category.dart';

/// Các ngưỡng của phân tích trận (spec 2026-10-28 mục 3 và 4).
abstract final class MatchAnalysisConstants {
  /// Số trận hoàn tất gần nhất đưa vào phân tích.
  static const recentMatches = 10;

  /// Số trận tối thiểu (mỗi trận góp ít nhất một lần thử) để kết luận điểm yếu.
  static const minMatches = 3;

  /// Số lần thử tối thiểu của một nhóm để kết luận điểm yếu.
  static const minAttempts = 10;

  /// Một trận đơn lẻ cần ít nhất ngần này lần thử mới được nói về một nhóm.
  static const singleMatchMinAttempts = 5;

  /// Một trận đơn lẻ nêu nhiều nhất ngần này nhóm.
  static const singleMatchFocusMax = 2;

  /// Cửa sổ ngày của Đấu tập.
  static const matchWindowDays = 28;

  /// Số trận Đấu tập tối thiểu trong cửa sổ.
  static const tournamentMinMatches = 3;

  /// Bài kiểm tra BU phải cũ ít nhất ngần này ngày thì mới gợi ý kiểm tra lại hạng.
  static const rankCheckMinDays = 28;

  /// Tỉ lệ hỏng (phần trăm) từ mức này trở lên thì nhóm bị coi là yếu.
  static const failPercentFrom = <SkillCategory, int>{
    SkillCategory.breakShot: 50,
    SkillCategory.aiming: 35,
    SkillCategory.position: 40,
    SkillCategory.safety: 50,
  };
}
