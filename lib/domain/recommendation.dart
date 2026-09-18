import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Chọn bài tập nên tập trong một nhóm kỹ năng.
///
/// Duyệt theo cấp tăng dần và chọn bài đầu tiên còn cần tập: chưa từng
/// tập, hoặc lần gần nhất chưa đạt mục tiêu. Nếu đã đạt hết thì trả bài
/// cấp cao nhất để giữ phong độ.
///
/// [excludeDrillIds] là các bài đã tập trong hôm nay — không gợi ý lại
/// đúng bài người chơi vừa làm xong.
Drill? pickDrillInCategory({
  required SkillCategory cat,
  required List<Drill> drills,
  required Map<String, List<DrillLog>> logsByDrillOldestFirst,
  required Set<String> excludeDrillIds,
}) {
  final candidates = drills
      .where((d) => d.cat == cat && !excludeDrillIds.contains(d.id))
      .toList()
    ..sort((a, b) => a.level.compareTo(b.level));

  if (candidates.isEmpty) return null;

  for (final drill in candidates) {
    final logs = logsByDrillOldestFirst[drill.id];
    if (logs == null || logs.isEmpty) return drill;

    final lastRatio = drillRatio(drill, logs.last);
    if (lastRatio == null || lastRatio < 1) return drill;
  }

  return candidates.last;
}

/// Vì sao nhóm kỹ năng này được chọn cho hôm nay.
///
/// Lý do đi kèm lựa chọn để màn hình giải thích được cho người chơi
/// thay vì chỉ đưa ra một mệnh lệnh không rõ nguồn gốc.
enum PickReason {
  /// Lịch tập hôm nay đã gắn sẵn nhóm này.
  scheduled,

  /// Hôm nay và hôm qua đều chưa tập — ưu tiên kéo người chơi quay lại.
  streakAtRisk,

  /// Nhóm yếu nhất hiện tại.
  weakest,

  /// Người mới, đi theo thứ tự làm quen.
  newcomer,

  /// Nhóm đang đi xuống dù chưa tới ngưỡng yếu.
  declining,

  /// Không luật nào khớp — luân phiên nhóm lâu chưa đụng tới.
  rotation,
}

/// Thứ tự làm quen cho người mới.
///
/// Phải phủ hết [SkillCategory.values]: luật người mới duyệt danh sách
/// này để tìm nhóm đầu tiên chưa có dữ liệu, thiếu một nhóm là luật đó
/// lặng lẽ rơi xuống luật sau. Cân bi đứng cuối cùng với A băng vì cả
/// hai đều là bài phản băng, khó hơn bốn nhóm còn lại.
const newcomerOrder = <SkillCategory>[
  SkillCategory.aiming,
  SkillCategory.position,
  SkillCategory.breakShot,
  SkillCategory.safety,
  SkillCategory.kick,
  SkillCategory.bank,
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chọn nhóm kỹ năng nên tập hôm nay, kèm lý do.
///
/// Sáu luật xét theo thứ tự, luật khớp đầu tiên thắng — xem
/// Claude_desktop/PoolCoachAI_SPEC.md mục 6.1.
({SkillCategory cat, PickReason reason}) pickCategoryForToday({
  required PlayerIntelligence pi,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required List<ScheduleSlot> schedule,
  required DateTime today,
}) {
  final drillById = {for (final d in drills) d.id: d};

  // Luật 1 — lịch hôm nay có gắn nhóm cụ thể.
  final todayIndex = today.weekday - 1; // DateTime.monday == 1
  for (final slot in schedule) {
    final cat = slot.cat;
    if (slot.day == todayIndex && cat != null) {
      return (cat: cat, reason: PickReason.scheduled);
    }
  }

  final yesterday = today.subtract(const Duration(days: 1));
  final activeDates = <DateTime>[
    ...logs.map((l) => l.date),
    ...timerSessions.map((t) => t.date),
  ];
  final activeTodayOrYesterday =
      activeDates.any((d) => _sameDay(d, today) || _sameDay(d, yesterday));

  // Luật 2 — sắp mất streak.
  if (!activeTodayOrYesterday && activeDates.isNotEmpty) {
    final counts = <SkillCategory, int>{
      for (final cat in SkillCategory.values) cat: 0,
    };
    for (final log in logs) {
      final drill = drillById[log.drillId];
      if (drill != null) counts[drill.cat] = counts[drill.cat]! + 1;
    }
    final easiest = counts.entries.reduce(
      (a, b) => b.value < a.value ? b : a,
    );
    return (cat: easiest.key, reason: PickReason.streakAtRisk);
  }

  // Luật 3 — có nhóm đang yếu.
  if (pi.weak.isNotEmpty) {
    return (cat: pi.weak.first, reason: PickReason.weakest);
  }

  // Luật 4 — người mới.
  if (!pi.hasAnyData) {
    for (final cat in newcomerOrder) {
      if (pi.categories[cat]!.sessionCount == 0) {
        return (cat: cat, reason: PickReason.newcomer);
      }
    }
  }

  // Luật 5 — có nhóm đang đi xuống.
  for (final cat in SkillCategory.values) {
    if (pi.categories[cat]!.trend == SkillTrend.down) {
      return (cat: cat, reason: PickReason.declining);
    }
  }

  // Luật 6 — luân phiên nhóm lâu chưa đụng tới.
  final lastTouched = <SkillCategory, DateTime?>{
    for (final cat in SkillCategory.values) cat: null,
  };
  for (final log in logs) {
    final drill = drillById[log.drillId];
    if (drill == null) continue;
    final current = lastTouched[drill.cat];
    if (current == null || log.date.isAfter(current)) {
      lastTouched[drill.cat] = log.date;
    }
  }

  var oldest = SkillCategory.values.first;
  DateTime? oldestDate;
  for (final cat in SkillCategory.values) {
    final date = lastTouched[cat];
    if (date == null) return (cat: cat, reason: PickReason.rotation);
    if (oldestDate == null || date.isBefore(oldestDate)) {
      oldest = cat;
      oldestDate = date;
    }
  }

  return (cat: oldest, reason: PickReason.rotation);
}
