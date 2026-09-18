import 'package:poolcoachai/domain/skill_category.dart';

/// Một khung giờ trong lịch tập hằng tuần.
class ScheduleSlot {
  const ScheduleSlot({
    required this.id,
    required this.day,
    required this.time,
    required this.label,
    this.cat,
  }) : assert(day >= 0 && day <= 6, 'day phải trong 0..6');

  final String id;

  /// 0 = Thứ Hai … 6 = Chủ nhật.
  final int day;

  /// Giờ bắt đầu dạng "HH:MM".
  final String time;

  final String label;

  /// Nhóm kỹ năng dự định tập. Có thì đây là ý định tường minh của
  /// người chơi và thắng mọi luật gợi ý tự động.
  final SkillCategory? cat;
}
