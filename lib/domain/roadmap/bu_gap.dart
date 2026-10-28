import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart' show percentOf;
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_category_map.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Điểm BU thấp nhất của [rank] theo bảng chủ sản phẩm chốt 14/10/2026.
/// PRO không có dòng trong bảng — gọi với PRO là lỗi lập trình.
int buFloor(Rank rank) => buRankBands.firstWhere((b) => b.rank == rank).min;

/// Kết quả của một lần kiểm tra BU hoàn chỉnh: tổng điểm và điểm mất từng bài.
final class BuResult {
  BuResult({
    required this.testId,
    required this.completedAt,
    required this.total,
    required Map<String, int> lost,
    Map<String, int> max = const {},
  })  : lost = Map.unmodifiable(lost),
        max = Map.unmodifiable(max);

  final String testId;
  final DateTime completedAt;
  final int total;

  /// 'F1'…'S10' → tối đa của bản đã làm trừ điểm đạt.
  final Map<String, int> lost;

  /// 'F1'…'S10' → điểm tối đa của bản đã làm. Rỗng khi không biết.
  final Map<String, int> max;
}

/// Điểm mất từng bài của một lần đã hoàn tất (spec mục 4.1 bước 3).
BuResult buResultFrom(TestSnapshot s) {
  final test = s.test;
  assert(test.isCompleted && test.examIIVersion != null, 'chỉ lần đã hoàn tất mới có điểm mất');
  final drills = [...examIDrills, ...examIIDrills(test.examIIVersion!)];
  final lost = {
    for (final d in drills) d.id: d.maxScore - (drillScore(d, s.attemptsOf(d)) ?? 0),
  };
  return BuResult(
    testId: test.id,
    completedAt: test.completedAt!,
    total: test.totalScore ?? s.scoreOf(drills),
    max: {for (final d in drills) d.id: d.maxScore},
    lost: lost,
  );
}

/// Lần hoàn tất gần nhất. Lần đang làm (kể cả Đề II đang hoãn) và lần đã hủy
/// không tính (spec mục 4.1 bước 6).
String? latestCompletedTestId(Iterable<BuTest> tests) {
  BuTest? best;
  for (final t in tests) {
    if (!t.isCompleted || t.isCancelled) continue;
    if (best == null || t.completedAt!.isAfter(best.completedAt!)) best = t;
  }
  return best?.id;
}

typedef LostPoints = ({
  Map<SkillCategory, int> byCategory,
  int unmapped,
  List<String> unmappedIds,
});

/// Cộng điểm mất theo nhóm qua [buDrillCategory]. Bài không nối nhóm (S8, S9)
/// vẫn tính vào [LostPoints.unmapped] — điểm mất không được biến mất.
LostPoints lostByCategory(BuResult r) {
  final byCategory = <SkillCategory, int>{};
  var unmapped = 0;
  final unmappedIds = <String>[];
  for (final MapEntry(key: id, value: cat) in buDrillCategory.entries) {
    final points = r.lost[id] ?? 0;
    if (points <= 0) continue;
    if (cat == null) {
      unmapped += points;
      unmappedIds.add(id);
    } else {
      byCategory[cat] = (byCategory[cat] ?? 0) + points;
    }
  }
  return (byCategory: byCategory, unmapped: unmapped, unmappedIds: unmappedIds);
}

/// Các bài của nhóm [c] có mất điểm, theo thứ tự F1…S10.
List<String> lostDrillsIn(BuResult r, SkillCategory c) => [
      for (final MapEntry(key: id, value: cat) in buDrillCategory.entries)
        if (cat == c && (r.lost[id] ?? 0) > 0) id,
    ];

/// Phần trăm điểm đạt theo nhóm: (tối đa − mất) / tối đa, cộng qua các bài của
/// nhóm. Nhóm không có điểm tối đa thì vắng mặt; S8, S9 không tính.
Map<SkillCategory, int> buCategoryPercent(BuResult r) {
  final maxByCat = <SkillCategory, int>{};
  final lostByCat = <SkillCategory, int>{};
  for (final MapEntry(key: id, value: cat) in buDrillCategory.entries) {
    final max = r.max[id] ?? 0;
    if (cat == null || max <= 0) continue;
    maxByCat[cat] = (maxByCat[cat] ?? 0) + max;
    lostByCat[cat] = (lostByCat[cat] ?? 0) + (r.lost[id] ?? 0);
  }
  return {
    for (final MapEntry(key: cat, value: max) in maxByCat.entries)
      cat: percentOf(max - lostByCat[cat]!, max)!,
  };
}
