import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis_constants.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/practice_facts.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Lộ trình của [goal], tính lại từ đầu mỗi lần dữ liệu đổi (spec 2026-10-15
/// mục 4). Không lưu bước nào: cùng dữ liệu vào thì cùng lộ trình ra.
Roadmap buildRoadmap({
  required PlayerGoal goal,
  required PlayerRank? rank,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<BuTest> tests,
  required BuResult? latestResult,
  required DateTime today,
  List<PoolMatch> matches = const [],
}) {
  final facts = PracticeFacts(drills: drills, logs: logs, today: today);
  return switch (goal.kind) {
    GoalKind.lenHang => _lenHang(goal, rank, facts, tests, latestResult),
    GoalKind.thuanThucKyNang => _skill(goal, facts),
    GoalKind.chuanBiGiai => _tournament(goal, facts, latestResult, matches),
  };
}

typedef _Lost = ({SkillCategory? cat, int points});

Roadmap _lenHang(
  PlayerGoal goal,
  PlayerRank? rank,
  PracticeFacts facts,
  List<BuTest> tests,
  BuResult? result,
) {
  final from = rank?.rank;
  if (from == null) {
    return Roadmap(goal: goal, blocked: LenHangBlock.noRank, steps: const [
      RoadmapStep(kind: StepKind.xacDinhHang, status: StepStatus.dangLam, reason: NeedRank()),
    ]);
  }
  final target = nextRank(from);
  if (target == null) {
    return Roadmap(goal: goal, blocked: LenHangBlock.topRank, from: from, steps: const []);
  }

  final retestFrom = retestAvailableFrom(tests);
  final needed = result == null ? null : buFloor(target) - result.total;
  final steps = <RoadmapStep>[
    if (result != null) ..._untilEnough(facts, result, needed!) else ..._weakGroups(facts),
    RoadmapStep(kind: StepKind.lamBaiBu, status: StepStatus.chuaToi, reason: RetestFrom(retestFrom)),
  ];
  return Roadmap(
    goal: goal,
    from: from,
    target: target,
    pointsNeeded: needed,
    steps: placeSteps(facts, steps, retestFrom: retestFrom),
  );
}

/// Nhóm dưới 75 hoặc chưa đo, yếu nhất trước (mục 4.1 bước 6).
List<RoadmapStep> _weakGroups(PracticeFacts facts) {
  final weak = SkillCategory.values.where((c) => !facts.atLeastStrong(c)).toList()
    ..sort(facts.compareWeakness);
  return [for (final c in weak) facts.groupStep(c, facts.groupReason(c))];
}

/// Điểm mất giảm dần; bằng nhau thì nhóm yếu hơn trước; S8/S9 sau các nhóm
/// cùng điểm (mục 4.1 bước 4–5).
int _byPointsThenWeakness(PracticeFacts facts, _Lost a, _Lost b) {
  final byPoints = b.points.compareTo(a.points);
  if (byPoints != 0) return byPoints;
  if (a.cat == null) return b.cat == null ? 0 : 1;
  if (b.cat == null) return -1;
  return facts.compareWeakness(a.cat!, b.cat!);
}

RoadmapStep _lostStep(PracticeFacts facts, BuResult result, _Lost e) {
  final cat = e.cat;
  if (cat == null) {
    final ids = lostByCategory(result).unmappedIds;
    return RoadmapStep(
      kind: StepKind.buLe,
      status: StepStatus.dangLam,
      reason: LostBuPoints(e.points, ids),
      buDrillIds: ids,
    );
  }
  return facts.groupStep(
      cat, e.points > 0 ? LostBuPoints(e.points, lostDrillsIn(result, cat)) : facts.groupReason(cat));
}

/// Lấy dần nhóm theo điểm mất cho tới khi tổng điểm mất đã lấy ≥ điểm cần
/// thêm (mục 4.1 bước 4).
List<RoadmapStep> _untilEnough(PracticeFacts facts, BuResult result, int needed) {
  final lost = lostByCategory(result);
  final entries = <_Lost>[
    for (final MapEntry(key: cat, value: points) in lost.byCategory.entries) (cat: cat, points: points),
    if (lost.unmapped > 0) (cat: null, points: lost.unmapped),
  ]..sort((a, b) => _byPointsThenWeakness(facts, a, b));

  final picked = <RoadmapStep>[];
  var sum = 0;
  for (final e in entries) {
    if (sum >= needed) break;
    picked.add(_lostStep(facts, result, e));
    sum += e.points;
  }
  return picked;
}

/// Mỗi bài của nhóm một bước, theo cấp; bước cuối là cả nhóm (R6).
Roadmap _skill(PlayerGoal goal, PracticeFacts facts) {
  final c = goal.category!;
  final inGroup = facts.drills.where((d) => d.cat == c).toList()
    ..sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });
  final steps = <RoadmapStep>[
    for (final d in inGroup)
      RoadmapStep(
        kind: StepKind.baiTap,
        status: facts.drillReady(d) ? StepStatus.xong : StepStatus.chuaToi,
        reason: DrillLevel(d.level),
        category: c,
        drillId: d.id,
        passStreak: facts.passStreak(d),
      ),
    facts.groupStep(c, facts.groupReason(c)),
  ];
  return Roadmap(goal: goal, steps: placeSteps(facts, steps));
}

/// Mọi nhóm dưới 75; có bài BU thì theo điểm mất, không thì theo độ yếu. Không
/// có bước làm BU; bước không kịp trước ngày giải xếp riêng (mục 4.3).
Roadmap _tournament(
  PlayerGoal goal,
  PracticeFacts facts,
  BuResult? result,
  List<PoolMatch> matches,
) {
  final have = recentRecordedMatches(matches, facts.day);
  final fromMatches = <RoadmapStep>[
    if (have < MatchAnalysisConstants.tournamentMinMatches)
      RoadmapStep(
        kind: StepKind.dauTap,
        status: StepStatus.chuaToi,
        reason: NotEnoughMatches(have, MatchAnalysisConstants.tournamentMinMatches),
      ),
    // Nhóm yếu trong trận không bao giờ bắt đầu ở "xong": nó rời danh sách
    // khi dữ liệu trận thôi đánh dấu.
    for (final w in analyzeMatches(matches).weaknesses)
      facts
          .groupStep(w.category, MatchWeakness(w.failures, w.attempts))
          .withStatus(StepStatus.chuaToi),
  ];
  final placed = {for (final s in fromMatches) s.category};
  final below = SkillCategory.values.where((c) => !facts.atLeastStrong(c)).toList();
  final List<RoadmapStep> steps;
  if (result == null) {
    below.sort(facts.compareWeakness);
    steps = [for (final c in below) facts.groupStep(c, facts.groupReason(c))];
  } else {
    final lost = lostByCategory(result);
    final entries = <_Lost>[
      for (final c in below) (cat: c, points: lost.byCategory[c] ?? 0),
      if (lost.unmapped > 0) (cat: null, points: lost.unmapped),
    ]..sort((a, b) => _byPointsThenWeakness(facts, a, b));
    steps = [for (final e in entries) _lostStep(facts, result, e)];
  }
  return Roadmap(
    goal: goal,
    steps: placeSteps(
      facts,
      [...fromMatches, ...steps.where((s) => s.category == null || !placed.contains(s.category))],
      eventDate: goal.eventDate,
    ),
  );
}

/// Số trận hoàn tất có ít nhất một cú ghi, kết thúc trong
/// [MatchAnalysisConstants.matchWindowDays] ngày tính tới [today].
int recentRecordedMatches(List<PoolMatch> matches, DateTime today) {
  final from = DateTime(today.year, today.month, today.day - MatchAnalysisConstants.matchWindowDays);
  return matches.where((m) {
    if (!m.isComplete || m.shots.isEmpty) return false;
    return !(m.completedAt ?? m.startedAt).isBefore(from);
  }).length;
}

/// Đặt ngày dự kiến rồi trạng thái cho cả danh sách (mục 4.4, 4.5).
List<RoadmapStep> placeSteps(
  PracticeFacts facts,
  List<RoadmapStep> steps, {
  DateTime? retestFrom,
  DateTime? eventDate,
}) {
  // Ngày: nối tiếp nhau từ hôm nay. Một bước không đo được tốc độ thì nó và
  // mọi bước sau đều "chưa đủ dữ liệu" — không đoán.
  var cursor = facts.day;
  var known = true;
  final dated = <RoadmapStep>[];
  for (final s in steps) {
    if (s.kind == StepKind.nhom && s.status != StepStatus.xong) {
      final days = known ? daysToStrong(s.mastery, facts.pace(s.category!)) : null;
      if (days == null) {
        known = false;
        dated.add(s.withEstimate(const Estimate.notEnoughData()));
        continue;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + days);
      dated.add(s.withEstimate(Estimate.on(cursor)));
    } else if (s.kind == StepKind.lamBaiBu) {
      final from = retestFrom == null ? null : dateOnly(retestFrom);
      final open = from == null || from.isBefore(cursor) ? cursor : from;
      dated.add(s.withEstimate(known ? Estimate.on(open) : const Estimate.notEnoughData()));
    } else {
      dated.add(s);
    }
  }

  // Trạng thái: bước còn làm đầu tiên là "đang làm"; mục tiêu giải thì bước
  // có ngày sau ngày giải là "không kịp" (mục 4.3). S8/S9 luôn đang làm, không
  // phải bước hiện tại (R5).
  final event = eventDate == null ? null : dateOnly(eventDate);
  var hasCurrent = false;
  final placed = <RoadmapStep>[];
  for (final s in dated) {
    if (s.status == StepStatus.xong || s.kind == StepKind.xacDinhHang) {
      placed.add(s);
    } else if (s.kind == StepKind.buLe) {
      placed.add(s.withStatus(StepStatus.dangLam));
    } else if (event != null && (s.estimate?.date?.isAfter(event) ?? false)) {
      placed.add(s.withStatus(StepStatus.khongKip));
    } else if (!hasCurrent) {
      hasCurrent = true;
      placed.add(s.withStatus(StepStatus.dangLam));
    } else {
      placed.add(s.withStatus(StepStatus.chuaToi));
    }
  }
  return placed;
}
