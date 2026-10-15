import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
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
  }) : lost = Map.unmodifiable(lost);

  final String testId;
  final DateTime completedAt;
  final int total;

  /// 'F1'…'S10' → tối đa của bản đã làm trừ điểm đạt.
  final Map<String, int> lost;
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
