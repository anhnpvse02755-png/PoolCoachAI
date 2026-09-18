import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';

/// Quy đổi một lần ghi kết quả thành tỉ lệ đạt mục tiêu của bài đó.
///
/// `1.0` nghĩa là đạt đúng mục tiêu, lớn hơn là vượt, nhỏ hơn là chưa đạt.
/// Trả `null` khi không đủ thông tin để chấm — gọi là "chưa chấm được",
/// **không** quy về 0, vì thiếu dữ liệu khác hẳn với làm kém.
double? drillRatio(Drill drill, DrillLog log) {
  final threshold = drill.passThreshold;
  if (threshold != null) {
    final attempts = log.attempts;
    if (attempts == null || attempts == 0) return null;
    return (log.score / attempts) / threshold;
  }

  final target = drill.target;
  if (target == null || target == 0) return null;
  return log.score / target;
}
