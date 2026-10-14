import 'dart:math' as math;

import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

// Thang vị trí F1–F5 — BU_Exam-I_Score_Sheet.pdf và spec mục 5.3.
const ladderStart = 4;
const ladderLowest = 1;
const ladderHighest = 7;
const ladderShotCount = 10;
const ladderCap = 10;

int _step(int position, bool made) =>
    (made ? position + 1 : position - 1).clamp(ladderLowest, ladderHighest);

/// Vị trí sau từng cú — đúng hàng "position" của phiếu điểm Đề I.
List<int> ladderPositions(List<bool> shots) {
  RangeError.checkValueInInterval(shots.length, 0, ladderShotCount, 'shots.length');
  final positions = <int>[];
  var p = ladderStart;
  for (final made in shots) {
    p = _step(p, made);
    positions.add(p);
  }
  return positions;
}

/// Vị trí hiện tại; chưa đánh cú nào thì là vị trí xuất phát.
int ladderPosition(List<bool> shots) {
  final positions = ladderPositions(shots);
  return positions.isEmpty ? ladderStart : positions.last;
}

/// Điểm thưởng: mỗi cú vào khi đang đứng ở vị trí 7 — "mỗi số 7 theo sau
/// một số 7" của phiếu điểm.
int ladderBonus(List<bool> shots) {
  var p = ladderStart;
  var bonus = 0;
  for (final made in shots) {
    if (made && p == ladderHighest) bonus++;
    p = _step(p, made);
  }
  return bonus;
}

/// Vị trí cuối + thưởng, tối đa 10.
int ladderScore(List<bool> shots) =>
    math.min(ladderCap, ladderPosition(shots) + ladderBonus(shots));

/// Bài đã xong: đủ 10 cú, hoặc trượt hết các cú còn lại vẫn được 10 (dừng
/// sớm, spec mục 5.3). Trượt hết là đường tệ nhất: mỗi cú vào chỉ có thể
/// đẩy vị trí lên hoặc cộng thưởng.
bool ladderSettled(List<bool> shots) {
  if (shots.length >= ladderShotCount) return true;
  final left = ladderShotCount - shots.length;
  final worst =
      math.max(ladderLowest, ladderPosition(shots) - left) + ladderBonus(shots);
  return worst >= ladderCap;
}

/// Mỗi lượt thành công 1 điểm.
int successCount(List<bool> shots) => shots.where((s) => s).length;

/// Lượt cao hơn trong (tối đa) 2 lượt.
int bestOfTwo(List<int> counts) {
  if (counts.isEmpty || counts.length > 2) {
    throw ArgumentError.value(counts, 'counts', 'cần 1 hoặc 2 lượt');
  }
  return counts.reduce(math.max);
}

/// Thế thấp nhất + thế thấp nhì trong 3 thế.
int sumOfLowestTwo(List<int> counts) {
  if (counts.length != 3) throw ArgumentError.value(counts, 'counts', 'cần đúng 3 thế');
  final sorted = [...counts]..sort();
  return sorted[0] + sorted[1];
}

/// Trung vị điểm của 3 lần phá.
int medianOfThreeBreaks(List<BreakCriteria> breaks) {
  if (breaks.length != 3) throw ArgumentError.value(breaks, 'breaks', 'cần đúng 3 lần phá');
  final points = [for (final b in breaks) b.points]..sort();
  return points[1];
}
