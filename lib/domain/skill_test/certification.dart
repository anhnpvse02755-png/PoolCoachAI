import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

/// Giấy chứng nhận một bài. Không bao giờ bị thu hồi.
final class Certification {
  const Certification({
    required this.testId,
    required this.drillId,
    required this.drillLevel,
    required this.tableSize,
    required this.certifiedAt,
    this.passThreshold,
    this.target,
    this.score,
    this.attempts,
  });

  final String testId;
  final String drillId;
  final int drillLevel;
  final TableSize tableSize;
  final DateTime certifiedAt;

  /// Tiêu chí lần kiểm tra đã được chấm theo, từ ảnh chụp lúc hoàn tất (không
  /// phải bài hiện tại). Cả hai null khi bản ghi không có ảnh chụp.
  final double? passThreshold;
  final num? target;

  /// Kết quả của lần đạt (bằng chứng: cùng cỡ bàn với [tableSize]).
  final num? score;
  final int? attempts;
}

/// Mỗi bài một chứng nhận, lấy từ lần đạt sớm nhất (hoà thì id nhỏ hơn).
/// Thứ tự map theo thời điểm chứng nhận (hoà thì theo mã bài).
Map<String, Certification> certificationsOf(Iterable<SkillTest> tests) {
  final earliest = <String, SkillTest>{};
  for (final t in tests) {
    if (!t.certifies) continue;
    final best = earliest[t.drillId];
    if (best == null || _earlier(t, best)) earliest[t.drillId] = t;
  }
  final ordered = earliest.values.toList()
    ..sort((a, b) {
      final byTime = a.completedAt!.compareTo(b.completedAt!);
      return byTime != 0 ? byTime : a.drillId.compareTo(b.drillId);
    });
  return {
    for (final t in ordered)
      t.drillId: Certification(
        testId: t.id,
        drillId: t.drillId,
        drillLevel: t.drillLevel,
        tableSize: t.tableSize,
        certifiedAt: t.completedAt!,
        passThreshold: t.passThreshold,
        target: t.target,
        score: t.score,
        attempts: t.attempts,
      ),
  };
}

bool _earlier(SkillTest a, SkillTest b) {
  final byTime = a.completedAt!.compareTo(b.completedAt!);
  return byTime != 0 ? byTime < 0 : a.id.compareTo(b.id) < 0;
}

/// Các bài cùng nhóm ở cấp nhỏ nhất lớn hơn cấp của [drill], xếp theo id.
List<Drill> nextLevelDrills(Drill drill, List<Drill> drills) {
  final higher = drills.where(
    (d) => d.cat == drill.cat && d.level > drill.level,
  );
  if (higher.isEmpty) return const [];
  final next = higher.map((d) => d.level).reduce((a, b) => a < b ? a : b);
  return higher.where((d) => d.level == next).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}

/// Phong độ gần đây chưa đạt: [logs] là buổi của đúng bài này. Đúng khi đủ
/// [SkillTestConstants.recentFormWindow] buổi và không buổi nào trong cửa sổ
/// gần nhất đạt (`drillRatio >= 1`); buổi không chấm được không tính là đạt.
bool recentFormSlipped(Drill drill, List<DrillLog> logs) {
  const window = SkillTestConstants.recentFormWindow;
  if (logs.length < window) return false;
  final ordered = [...logs]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final recent = ordered.sublist(ordered.length - window);
  return !recent.any((log) => (drillRatio(drill, log) ?? 0) >= 1);
}
