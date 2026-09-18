import 'dart:math' as math;

import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

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

/// Kết luận về một nhóm kỹ năng.
class CategoryInsight {
  const CategoryInsight({
    required this.mastery,
    required this.trend,
    required this.sessionCount,
  });

  /// 0–100, hoặc `null` khi chưa đủ dữ liệu để kết luận.
  final int? mastery;

  final SkillTrend trend;

  /// Số buổi đã chấm được điểm trong nhóm này.
  final int sessionCount;
}

/// Bức tranh trình độ người chơi, tính hoàn toàn bằng công thức xác định.
///
/// Đây là object mà lớp Coach (LLM) sẽ nhận làm ngữ cảnh ở giai đoạn sau.
/// LLM **chỉ được đọc** các con số ở đây, không bao giờ tự tính lại —
/// xem mục 2.2 tài liệu thiết kế.
class PlayerIntelligence {
  const PlayerIntelligence({
    required this.categories,
    required this.weak,
    required this.strong,
    required this.readyDrillIds,
    required this.hasAnyData,
  });

  /// Mọi nhóm kỹ năng đều có mặt, kể cả nhóm chưa tập buổi nào.
  final Map<SkillCategory, CategoryInsight> categories;

  /// Nhóm dưới ngưỡng yếu, sắp xếp tăng dần — yếu nhất đứng đầu.
  final List<SkillCategory> weak;

  /// Nhóm từ ngưỡng mạnh trở lên, sắp xếp giảm dần.
  final List<SkillCategory> strong;

  /// Bài tập đã đủ điều kiện mở cấp tiếp theo.
  final List<String> readyDrillIds;

  /// Đã có bất kỳ buổi tập nào chưa.
  final bool hasAnyData;
}

/// Đã đủ điều kiện mở cấp tiếp theo của bài này chưa.
///
/// Yêu cầu [PracticeConstants.readyStreak] buổi gần nhất đều đạt mục
/// tiêu. Đây là cổng cho Skill Test ở giai đoạn sau: người chơi **không**
/// được tự bấm "hoàn thành cấp" để mở cấp kế tiếp.
bool isReadyForLevelUp(Drill drill, List<DrillLog> logsOldestFirst) {
  if (logsOldestFirst.length < PracticeConstants.readyStreak) return false;

  final lastN = logsOldestFirst
      .sublist(logsOldestFirst.length - PracticeConstants.readyStreak)
      .map((log) => drillRatio(drill, log));

  return lastN.every((ratio) => ratio != null && ratio >= 1);
}

/// Tính toàn bộ bức tranh trình độ từ danh sách bài tập và bản ghi.
PlayerIntelligence computePlayerIntelligence({
  required List<Drill> drills,
  required List<DrillLog> logs,
}) {
  final drillById = {for (final d in drills) d.id: d};

  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));

  final ratiosByCategory = <SkillCategory, List<double>>{
    for (final cat in SkillCategory.values) cat: <double>[],
  };
  final logsByDrill = <String, List<DrillLog>>{};

  for (final log in sorted) {
    final drill = drillById[log.drillId];
    if (drill == null) continue;

    logsByDrill.putIfAbsent(log.drillId, () => <DrillLog>[]).add(log);

    final ratio = drillRatio(drill, log);
    if (ratio != null) ratiosByCategory[drill.cat]!.add(ratio);
  }

  final categories = <SkillCategory, CategoryInsight>{};
  for (final cat in SkillCategory.values) {
    final ratios = ratiosByCategory[cat]!;
    categories[cat] = CategoryInsight(
      mastery: categoryMastery(ratios),
      trend: categoryTrend(ratios),
      sessionCount: ratios.length,
    );
  }

  final scored =
      categories.entries.where((e) => e.value.mastery != null).toList();

  final weak = scored
      .where((e) => e.value.mastery! < PracticeConstants.weakCutoff)
      .toList()
    ..sort((a, b) => a.value.mastery!.compareTo(b.value.mastery!));

  final strong = scored
      .where((e) => e.value.mastery! >= PracticeConstants.strongCutoff)
      .toList()
    ..sort((a, b) => b.value.mastery!.compareTo(a.value.mastery!));

  final readyDrillIds = <String>[];
  for (final entry in logsByDrill.entries) {
    final drill = drillById[entry.key];
    if (drill == null) continue;
    if (isReadyForLevelUp(drill, entry.value)) readyDrillIds.add(entry.key);
  }
  readyDrillIds.sort();

  return PlayerIntelligence(
    categories: categories,
    weak: weak.map((e) => e.key).toList(),
    strong: strong.map((e) => e.key).toList(),
    readyDrillIds: readyDrillIds,
    hasAnyData: logsByDrill.isNotEmpty,
  );
}
