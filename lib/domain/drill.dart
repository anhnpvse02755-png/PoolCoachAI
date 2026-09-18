import 'package:poolcoachai/domain/skill_category.dart';

/// Một bài tập.
///
/// Cách chấm điểm quyết định bởi đúng **một** trong hai trường:
/// - [passThreshold] (0–1) cho bài đếm cú — log phải có `attempts`,
///   tỉ lệ đạt tính bằng `score / attempts` so với ngưỡng này.
/// - [target] cho bài đo bằng đơn vị khác — cm, giây, số lần trong
///   60 giây — log không có `attempts`, tỉ lệ tính bằng `score / target`.
///
/// Đặt cả hai hoặc không đặt gì đều là lỗi lập trình, nên dùng assert
/// chứ không im lặng chọn một cái.
class Drill {
  const Drill({
    required this.id,
    required this.cat,
    required this.name,
    required this.level,
    required this.unit,
    required this.goal,
    required this.steps,
    this.passThreshold,
    this.target,
  })  : assert(
          passThreshold == null || target == null,
          'Drill chỉ được có passThreshold hoặc target, không được cả hai',
        ),
        assert(
          passThreshold != null || target != null,
          'Drill phải có passThreshold hoặc target để chấm được điểm',
        );

  final String id;
  final SkillCategory cat;
  final String name;

  /// Cấp độ 1–5.
  final int level;

  /// Nhãn đơn vị hiển thị, ví dụ "lần trúng / 10" hay "khoảng cách kéo (cm)".
  final String unit;

  final String goal;
  final List<String> steps;

  /// Tỉ lệ thành công cần đạt, 0–1. Chỉ dùng cho bài có `attempts`.
  final double? passThreshold;

  /// Mục tiêu tuyệt đối. Chỉ dùng cho bài không có `attempts`.
  final num? target;

  /// Bài này chấm theo tỉ lệ thành công trên số lượt thử.
  bool get usesAttempts => passThreshold != null;
}
