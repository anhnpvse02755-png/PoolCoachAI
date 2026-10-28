import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

class SkillTrainingStatistics {
  const SkillTrainingStatistics({
    required this.category,
    required this.scoredSessions,
    required this.averageTargetRatio,
  });

  final SkillCategory category;
  final int scoredSessions;
  final double? averageTargetRatio;
}

class DrillTrainingTrend {
  const DrillTrainingTrend({required this.drill, required this.targetRatios});

  final Drill drill;

  /// Oldest to newest, limited to the five most recent scorable sessions.
  final List<double> targetRatios;
}

class WeeklyTrainingPlayDay {
  const WeeklyTrainingPlayDay({
    required this.date,
    required this.trainingSessions,
    required this.matches,
  });

  final DateTime date;
  final int trainingSessions;
  final int matches;
}

class CombinedTrainingPlayStatistics {
  const CombinedTrainingPlayStatistics({
    required this.days,
    required this.trainingSessionCount,
    required this.matchCount,
    required this.trainingDays,
    required this.playDays,
    required this.sharedDays,
  });

  final List<WeeklyTrainingPlayDay> days;
  final int trainingSessionCount;
  final int matchCount;
  final int trainingDays;
  final int playDays;
  final int sharedDays;

  int get activeDays =>
      days.where((day) => day.trainingSessions > 0 || day.matches > 0).length;
}

class TrainingStatistics {
  const TrainingStatistics({
    required this.drillSessionCount,
    required this.timerSessionCount,
    required this.totalTimerSeconds,
    required this.totalDrillSeconds,
    required this.timedDrillSessionCount,
    required this.timerSecondsThisWeek,
    required this.streakDays,
    required this.recordedMatchCount,
    required this.completedMatchCount,
    required this.matchWins,
    required this.matchLosses,
    required this.recordedShotCount,
    required this.breakShotCount,
    required this.safetyShotCount,
    required this.missedShotCount,
    required this.foulCount,
    required this.scratchCount,
    required this.successfulPositions,
    required this.assessedPositions,
    required this.skills,
    required this.drillTrends,
    required this.combinedTrainingPlay,
  });

  final int drillSessionCount;
  final int timerSessionCount;
  final int totalTimerSeconds;
  final int totalDrillSeconds;
  final int timedDrillSessionCount;
  final int timerSecondsThisWeek;
  final int streakDays;
  final int recordedMatchCount;
  final int completedMatchCount;
  final int matchWins;
  final int matchLosses;
  final int recordedShotCount;
  final int breakShotCount;
  final int safetyShotCount;
  final int missedShotCount;
  final int foulCount;
  final int scratchCount;
  final int successfulPositions;
  final int assessedPositions;
  final List<SkillTrainingStatistics> skills;
  final List<DrillTrainingTrend> drillTrends;
  final CombinedTrainingPlayStatistics combinedTrainingPlay;

  int get totalSessionCount => drillSessionCount + timerSessionCount;
}

TrainingStatistics computeTrainingStatistics({
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required List<PoolMatch> matches,
  required DateTime today,
}) {
  final drillById = {for (final drill in drills) drill.id: drill};
  final ratiosBySkill = {
    for (final category in SkillCategory.values) category: <double>[],
  };
  final ratiosByDrill =
      <String, List<({DateTime date, String id, double ratio})>>{};

  for (final log in logs) {
    final drill = drillById[log.drillId];
    if (drill == null) continue;
    final ratio = drillRatio(drill, log);
    if (ratio == null) continue;
    ratiosBySkill[drill.cat]!.add(ratio);
    ratiosByDrill.putIfAbsent(log.drillId, () => []).add((
      date: log.date,
      id: log.id,
      ratio: ratio,
    ));
  }

  final skills = [
    for (final category in SkillCategory.values)
      SkillTrainingStatistics(
        category: category,
        scoredSessions: ratiosBySkill[category]!.length,
        averageTargetRatio: _average(ratiosBySkill[category]!),
      ),
  ];

  final drillTrends = <DrillTrainingTrend>[];
  for (final entry in ratiosByDrill.entries) {
    final drill = drillById[entry.key]!;
    final results = entry.value
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    drillTrends.add(
      DrillTrainingTrend(
        drill: drill,
        targetRatios: results
            .skip(results.length > 5 ? results.length - 5 : 0)
            .map((result) => result.ratio)
            .toList(growable: false),
      ),
    );
  }
  drillTrends.sort((a, b) => a.drill.name.compareTo(b.drill.name));
  final shots = matches.expand((match) => match.shots);
  final combinedTrainingPlay = _combinedTrainingPlay(
    logs: logs,
    timerSessions: timerSessions,
    matches: matches,
    today: today,
  );

  return TrainingStatistics(
    drillSessionCount: logs.length,
    timerSessionCount: timerSessions.length,
    totalTimerSeconds: timerSessions.fold(
      0,
      (total, session) => total + session.durationSec,
    ),
    totalDrillSeconds: logs.fold(
      0,
      (total, log) => total + (log.durationSec ?? 0),
    ),
    timedDrillSessionCount: logs.where((log) => log.durationSec != null).length,
    timerSecondsThisWeek: freePracticeSecondsThisWeek(
      timerSessions: timerSessions,
      today: today,
    ),
    streakDays: streakDays(
      logs: logs,
      timerSessions: timerSessions,
      today: today,
    ),
    recordedMatchCount: matches.length,
    completedMatchCount: matches.where((match) => match.isComplete).length,
    matchWins: matches
        .where(
          (match) =>
              match.isComplete && match.playerScore > match.opponentScore,
        )
        .length,
    matchLosses: matches
        .where(
          (match) =>
              match.isComplete && match.playerScore < match.opponentScore,
        )
        .length,
    recordedShotCount: shots.length,
    breakShotCount: shots
        .where((shot) => shot.type == MatchShotType.breakShot)
        .length,
    safetyShotCount: shots
        .where((shot) => shot.type == MatchShotType.safety)
        .length,
    missedShotCount: shots
        .where((shot) => shot.outcome == MatchShotOutcome.missed)
        .length,
    foulCount: shots
        .where((shot) => shot.outcome == MatchShotOutcome.foul)
        .length,
    scratchCount: shots
        .where((shot) => shot.outcome == MatchShotOutcome.scratch)
        .length,
    successfulPositions: shots
        .where((shot) => shot.positionOutcome == PositionOutcome.successful)
        .length,
    assessedPositions: shots
        .where((shot) => shot.positionOutcome != null)
        .length,
    skills: skills,
    drillTrends: drillTrends,
    combinedTrainingPlay: combinedTrainingPlay,
  );
}

CombinedTrainingPlayStatistics _combinedTrainingPlay({
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required List<PoolMatch> matches,
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
  final days = [
    for (
      var date = monday;
      !date.isAfter(todayDate);
      date = date.add(const Duration(days: 1))
    )
      WeeklyTrainingPlayDay(date: date, trainingSessions: 0, matches: 0),
  ];
  final trainingCounts = {for (final day in days) day.date: 0};
  final matchCounts = {for (final day in days) day.date: 0};

  void addTraining(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (trainingCounts.containsKey(day)) {
      trainingCounts[day] = trainingCounts[day]! + 1;
    }
  }

  void addMatch(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (matchCounts.containsKey(day)) {
      matchCounts[day] = matchCounts[day]! + 1;
    }
  }

  for (final log in logs) {
    addTraining(log.date);
  }
  for (final session in timerSessions) {
    addTraining(session.date);
  }
  for (final match in matches) {
    addMatch(match.startedAt);
  }

  final populatedDays = [
    for (final day in days)
      WeeklyTrainingPlayDay(
        date: day.date,
        trainingSessions: trainingCounts[day.date]!,
        matches: matchCounts[day.date]!,
      ),
  ];
  return CombinedTrainingPlayStatistics(
    days: populatedDays,
    trainingSessionCount: trainingCounts.values.fold(0, (a, b) => a + b),
    matchCount: matchCounts.values.fold(0, (a, b) => a + b),
    trainingDays: populatedDays.where((day) => day.trainingSessions > 0).length,
    playDays: populatedDays.where((day) => day.matches > 0).length,
    sharedDays: populatedDays
        .where((day) => day.trainingSessions > 0 && day.matches > 0)
        .length,
  );
}

double? _average(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((total, value) => total + value) / values.length;
}
