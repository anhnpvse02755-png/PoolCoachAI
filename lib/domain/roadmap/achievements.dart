import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/practice_facts.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Ba loại thành tích — mỗi loại một sự kiện dữ liệu thật (spec mục 7).
enum AchievementKind { xongBuoc, duDieuKienLenCap, chuoiNgay }

/// Mốc chuỗi ngày tập liên tiếp (chủ sản phẩm chọn 15/10/2026).
const streakMilestones = <int>[7, 14, 30, 60, 100];

final class Achievement {
  const Achievement({required this.kind, required this.refId, required this.achievedAt});

  final AchievementKind kind;
  final String refId;
  final DateTime achievedAt;

  /// Mỗi (loại, refId) chỉ có một thành tích.
  String get key => '${kind.name}|$refId';

  @override
  bool operator ==(Object other) =>
      other is Achievement && other.kind == kind && other.refId == refId && other.achievedAt == achievedAt;

  @override
  int get hashCode => Object.hash(kind, refId, achievedAt);

  @override
  String toString() => 'Achievement($key, $achievedAt)';
}

/// Thành tích có sự kiện thật mà chưa nằm trong [existing] (các `key`).
///
/// Ngày ghi là ngày của buổi tập gây ra sự kiện, không phải lúc app nhận ra:
/// mở app lần đầu sau bản cập nhật thì bài đã đủ điều kiện từ tuần trước vẫn
/// mang ngày tuần trước. Riêng chuỗi ngày ghi hôm nay — chuỗi chạm mốc hôm nay.
List<Achievement> newAchievements({
  required PlayerGoal? goal,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required Set<String> existing,
  required DateTime today,
}) {
  final facts = PracticeFacts(drills: drills, logs: logs, today: today);
  final out = <Achievement>[];
  void add(AchievementKind kind, String refId, DateTime at) {
    final a = Achievement(kind: kind, refId: refId, achievedAt: at);
    if (!existing.contains(a.key) && !out.any((o) => o.key == a.key)) out.add(a);
  }

  for (final d in drills) {
    if (facts.drillReady(d)) add(AchievementKind.duDieuKienLenCap, d.id, facts.lastLogOf(d.id)!);
  }

  if (goal != null) {
    // Chỉ tính khi buổi gây ra nó nằm trong thời gian của mục tiêu này (R7).
    void doneUnderGoal(String subject, DateTime? lastLog) {
      if (lastLog == null || lastLog.isBefore(goal.createdAt)) return;
      add(AchievementKind.xongBuoc, '${goal.goalId}:$subject', lastLog);
    }

    if (goal.kind == GoalKind.thuanThucKyNang) {
      final c = goal.category!;
      final inGroup = drills.where((d) => d.cat == c).toList()
        ..sort((a, b) {
          final byLevel = a.level.compareTo(b.level);
          return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
        });
      for (final d in inGroup) {
        if (facts.drillReady(d)) doneUnderGoal(d.id, facts.lastLogOf(d.id));
      }
      if (facts.groupDone(c)) doneUnderGoal(c.name, facts.lastLogIn(c));
    } else {
      for (final c in SkillCategory.values) {
        if (facts.groupDone(c)) doneUnderGoal(c.name, facts.lastLogIn(c));
      }
    }
  }

  final streak = streakDays(logs: logs, timerSessions: const [], today: today);
  for (final m in streakMilestones) {
    if (streak >= m) add(AchievementKind.chuoiNgay, '$m', dateOnly(today));
  }
  return out;
}
