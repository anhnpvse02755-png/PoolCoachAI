import 'dart:math' as math;

import 'package:poolcoachai/domain/practice_constants.dart';

/// Xu hướng của một nhóm kỹ năng theo thời gian.
enum SkillTrend {
  up,
  down,
  flat,

  /// Chưa đủ buổi để dám kết luận. Không phải "đi ngang" — khác hẳn.
  notEnoughData,
}

/// Điểm thành thạo 0–100 của một nhóm kỹ năng.
///
/// Nhận danh sách tỉ lệ đạt mục tiêu, **cũ nhất trước**. Buổi càng mới
/// trọng số càng cao theo cấp số nhân [PracticeConstants.recencyDecay],
/// nên tiến bộ gần đây được phản ánh nhanh hơn thành tích cũ.
///
/// Trả `null` khi số buổi ít hơn [PracticeConstants.minSessions] — chưa
/// đủ dữ liệu thì không kết luận, tuyệt đối không suy diễn.
int? categoryMastery(List<double> ratiosOldestFirst) {
  if (ratiosOldestFirst.length < PracticeConstants.minSessions) return null;

  final newestFirst = ratiosOldestFirst.reversed.toList();
  var weightSum = 0.0;
  var valueSum = 0.0;

  for (var i = 0; i < newestFirst.length; i++) {
    final weight = math.pow(PracticeConstants.recencyDecay, i).toDouble();
    weightSum += weight;
    valueSum += weight * math.min(PracticeConstants.ratioCap, newestFirst[i]);
  }

  return (math.min(1.0, valueSum / weightSum) * 100).round();
}

/// Xu hướng: so trung bình nửa buổi gần đây với nửa buổi trước đó.
///
/// Cần ít nhất 4 buổi — với 3 buổi trở xuống, chia đôi không còn ý nghĩa
/// thống kê và một buổi lệch sẽ quyết định cả kết luận.
SkillTrend categoryTrend(List<double> ratiosOldestFirst) {
  final n = ratiosOldestFirst.length;
  if (n < 4) return SkillTrend.notEnoughData;

  final half = n ~/ 2;

  double average(Iterable<double> values) {
    var sum = 0.0;
    for (final v in values) {
      sum += math.min(PracticeConstants.ratioCap, v);
    }
    return sum / values.length;
  }

  final recent = average(ratiosOldestFirst.skip(n - half));
  final earlier = average(ratiosOldestFirst.take(half));
  final diff = recent - earlier;

  if (diff > PracticeConstants.trendThreshold) return SkillTrend.up;
  if (diff < -PracticeConstants.trendThreshold) return SkillTrend.down;
  return SkillTrend.flat;
}
