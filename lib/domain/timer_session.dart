import 'package:poolcoachai/domain/skill_category.dart';

/// Một buổi tập tự do đo bằng đồng hồ, không gắn bài tập nào.
///
/// Khác hẳn một buổi tập theo bài: không có mục tiêu, không có đạt hay
/// trượt. Nó chỉ tính vào tổng giờ tập và chuỗi ngày liên tiếp.
class TimerSession {
  const TimerSession({
    required this.id,
    required this.date,
    required this.durationSec,
    this.cat,
    this.cueId,
  });

  final String id;
  final DateTime date;
  final int durationSec;
  final SkillCategory? cat;
  final String? cueId;
}
