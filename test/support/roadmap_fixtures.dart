import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Hôm nay cố định cho các test Lộ trình.
final roadmapToday = DateTime(2026, 10, 15, 10);

Drill _drill(String id, SkillCategory cat, int level) => Drill(
      id: id,
      cat: cat,
      name: 'Bai $id',
      level: level,
      unit: 'lan / 10',
      passThreshold: 0.8,
      goal: 'g',
      steps: const [],
    );

/// Một bài mỗi nhóm, riêng Ngắm bi có hai cấp — đủ để thấy bài của bước
/// đi lên khi người chơi tiến bộ (R3).
final roadmapDrills = <Drill>[
  _drill('a1', SkillCategory.aiming, 1),
  _drill('a2', SkillCategory.aiming, 2),
  _drill('p1', SkillCategory.position, 1),
  _drill('b1', SkillCategory.breakShot, 1),
  _drill('s1', SkillCategory.safety, 1),
  _drill('k1', SkillCategory.kick, 1),
  _drill('n1', SkillCategory.bank, 1),
];

/// Mỗi ngày trong [days] một buổi [made]/10. Ngưỡng đạt 0.8: 8 trở lên là đạt.
List<DrillLog> sessions(String drillId, int made, List<DateTime> days) => [
      for (final d in days)
        DrillLog(
          id: '$drillId-${d.toIso8601String()}-$made',
          drillId: drillId,
          date: d,
          score: made,
          attempts: 10,
        ),
    ];

/// Ngày [day] của tháng [month] năm 2026, 9 giờ sáng.
DateTime on(int month, int day) => DateTime(2026, month, day, 9);

/// Kết quả BU có đủ điểm tối đa của Đề I + Đề II bản Thạc sĩ.
BuResult buResultGraded({
  required DateTime completedAt,
  Map<String, int> lost = const {},
  int total = 100,
}) =>
    BuResult(
      testId: 't-graded',
      completedAt: completedAt,
      total: total,
      lost: lost,
      max: {
        for (final d in [...examIDrills, ...examIIDrills(ExamIIVersion.masters)])
          d.id: d.maxScore,
      },
    );

/// Hai nhóm Ngắm bi và Điều bi cùng đi xuống: 9, 9, 5, 5 trên bốn ngày liền
/// từ [from] (hai bài `a1`, `p1` của [roadmapDrills]).
List<DrillLog> decliningLogs(DateTime from) => [
      for (final id in ['a1', 'p1'])
        for (var i = 0; i < 4; i++)
          DrillLog(
            id: '$id-$i',
            drillId: id,
            date: from.add(Duration(days: i)),
            score: i < 2 ? 9 : 5,
            attempts: 10,
          ),
    ];
