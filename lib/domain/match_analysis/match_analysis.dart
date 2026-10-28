import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/match_analysis/match_analysis_constants.dart';
import 'package:poolcoachai/domain/match_analysis/rack_analysis.dart';
import 'package:poolcoachai/domain/match_analysis/shot_skill_map.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Số lần thử và số lần hỏng của một nhóm kỹ năng qua nhiều trận.
final class SkillSignal {
  const SkillSignal({
    required this.category,
    required this.failures,
    required this.attempts,
    required this.matches,
  });

  final SkillCategory category;
  final int failures;
  final int attempts;

  /// Số trận có ít nhất một lần thử thuộc nhóm này.
  final int matches;
}

/// Thống kê cú phá của một bên.
final class BreakStats {
  const BreakStats({
    required this.shots,
    required this.made,
    required this.dry,
    required this.fouls,
    required this.scratches,
    required this.racksBroken,
    required this.breakAndRuns,
  });

  /// Số cú phá đã ghi.
  final int shots;
  final int made;

  /// Phá khô: cú phá không vào bi.
  final int dry;
  final int fouls;
  final int scratches;

  /// Số ván đủ cú mà bên này phá (mẫu số của phá-và-dọn).
  final int racksBroken;
  final int breakAndRuns;
}

class _BreakTally {
  int shots = 0;
  int made = 0;
  int dry = 0;
  int fouls = 0;
  int scratches = 0;
  int racksBroken = 0;
  int breakAndRuns = 0;

  void add(RackAnalysis rack) {
    shots++;
    switch (rack.breakResult) {
      case MatchShotOutcome.made:
        made++;
      case MatchShotOutcome.missed:
        dry++;
      case MatchShotOutcome.foul:
        fouls++;
      case MatchShotOutcome.scratch:
        scratches++;
      case null:
        break;
    }
    if (rack.isFull) racksBroken++;
    if (rack.breakAndRun) breakAndRuns++;
  }

  BreakStats build() => BreakStats(
        shots: shots,
        made: made,
        dry: dry,
        fouls: fouls,
        scratches: scratches,
        racksBroken: racksBroken,
        breakAndRuns: breakAndRuns,
      );
}

/// Phân tích nhiều trận hoàn tất gần nhất.
final class MatchAnalysis {
  const MatchAnalysis({
    required this.matches,
    required this.racksWon,
    required this.racksLost,
    required this.racksWithShots,
    required this.fullRacks,
    required this.playerBreak,
    required this.opponentBreak,
    required this.runOuts,
    required this.normalShots,
    required this.missedNormal,
    required this.assessedPositions,
    required this.failedPositions,
    required this.nextAfterFailedPosition,
    required this.missAfterFailedPosition,
    required this.nextAfterGoodPosition,
    required this.missAfterGoodPosition,
    required this.safeties,
    required this.assessedSafeties,
    required this.successfulSafeties,
    required this.safetyTurnovers,
    required this.proactiveTurnovers,
    required this.playerShots,
    required this.fouls,
    required this.scratches,
    required this.lostRackCauses,
    required this.signals,
    required this.weaknesses,
  });

  final int matches;
  final int racksWon;
  final int racksLost;
  final int racksWithShots;
  final int fullRacks;
  final BreakStats playerBreak;
  final BreakStats opponentBreak;

  /// Ván người chơi thắng bằng một lượt dọn bàn sau cú cuối của đối thủ.
  final int runOuts;

  /// Cú thường của người chơi vào bi hoặc trượt (không tính lỗi, chết cái).
  final int normalShots;
  final int missedNormal;

  /// Cú của người chơi có chấm điều bi, và số cú bị chấm hỏng.
  final int assessedPositions;
  final int failedPositions;

  /// Cú thường kế tiếp của chính người chơi (ván đủ cú) sau một điều bi hỏng,
  /// và số cú trong đó trượt.
  final int nextAfterFailedPosition;
  final int missAfterFailedPosition;

  /// Như trên nhưng sau một điều bi tốt.
  final int nextAfterGoodPosition;
  final int missAfterGoodPosition;

  /// Mọi cú phòng thủ của người chơi.
  final int safeties;

  /// Phòng thủ chấm được: ván đủ cú và cú kế tiếp là của đối thủ.
  final int assessedSafeties;

  /// Phòng thủ chấm được mà đối thủ kế tiếp trượt, phạm lỗi hoặc chết cái.
  final int successfulSafeties;

  /// Số lần mất lượt do phòng thủ.
  final int safetyTurnovers;

  /// Số lần mất lượt do phòng thủ hoặc tấn công trượt (chủ động).
  final int proactiveTurnovers;

  final int playerShots;
  final int fouls;
  final int scratches;

  /// Nguyên nhân thua ván; mọi giá trị của [LostRackCause] đều có mặt.
  final Map<LostRackCause, int> lostRackCauses;

  /// Bốn nhóm có ngưỡng: Phá, Tấn công, Điều bi, Phòng thủ.
  final Map<SkillCategory, SkillSignal> signals;

  /// Nhóm yếu qua nhiều trận (≥ 3 trận, ≥ 10 lần thử, vượt ngưỡng hỏng).
  final List<SkillSignal> weaknesses;
}

/// Trận đã hoàn tất, mới nhất trước (theo `completedAt`, thiếu thì
/// `startedAt`), hòa thì theo `id` tăng dần, lấy tối đa [limit] trận.
List<PoolMatch> recentCompletedMatches(
  List<PoolMatch> matches, {
  int limit = MatchAnalysisConstants.recentMatches,
}) {
  final finished = matches.where((m) => m.isComplete).toList()
    ..sort((a, b) {
      final atA = a.completedAt ?? a.startedAt;
      final atB = b.completedAt ?? b.startedAt;
      final byDate = atB.compareTo(atA);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  return finished.take(limit).toList();
}

/// Tỉ lệ phần trăm làm tròn; null khi không có mẫu.
int? percentOf(int part, int whole) =>
    whole == 0 ? null : (part * 100 / whole).round();

/// Các nhóm yếu: đủ trận, đủ lần thử và tỉ lệ hỏng chạm ngưỡng của nhóm.
/// Xếp theo mức vượt ngưỡng giảm dần, hòa thì theo thứ tự [SkillCategory].
List<SkillSignal> matchWeaknesses(
  Iterable<SkillSignal> signals, {
  required int minMatches,
  required int minAttempts,
}) {
  const threshold = MatchAnalysisConstants.failPercentFrom;
  final weak = [
    for (final s in signals)
      if (threshold[s.category] != null &&
          s.matches >= minMatches &&
          s.attempts >= minAttempts &&
          s.attempts > 0 &&
          s.failures * 100 >= threshold[s.category]! * s.attempts)
        s,
  ];
  // Mức vượt = failures/attempts - threshold/100 = excessNum / (100 * attempts);
  // so sánh bằng nhân chéo số nguyên để hòa là hòa thật.
  int excessNum(SkillSignal s) =>
      s.failures * 100 - threshold[s.category]! * s.attempts;
  weak.sort((a, b) {
    final byExcess =
        (excessNum(b) * a.attempts).compareTo(excessNum(a) * b.attempts);
    return byExcess != 0
        ? byExcess
        : a.category.index.compareTo(b.category.index);
  });
  return weak;
}

/// Một nhóm cần chú ý trong một trận kèm bài tập nên tập.
typedef MatchFocus = ({SkillSignal signal, Drill? drill});

/// Nhóm cần chú ý của một trận: ≥ 5 lần thử, vượt ngưỡng hỏng, xếp theo tỉ lệ
/// hỏng giảm dần (hòa thì theo thứ tự [SkillCategory]), tối đa 2 nhóm.
List<MatchFocus> singleMatchFocus(
  MatchAnalysis analysis, {
  required List<Drill> drills,
  required List<DrillLog> logs,
}) {
  final candidates = matchWeaknesses(
    analysis.signals.values,
    minMatches: 1,
    minAttempts: MatchAnalysisConstants.singleMatchMinAttempts,
  )..sort((a, b) {
      final byRate = (b.failures * a.attempts).compareTo(a.failures * b.attempts);
      return byRate != 0
          ? byRate
          : a.category.index.compareTo(b.category.index);
    });

  final logsByDrill = <String, List<DrillLog>>{};
  for (final log in logs) {
    logsByDrill.putIfAbsent(log.drillId, () => []).add(log);
  }
  for (final list in logsByDrill.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }

  return [
    for (final s in candidates.take(MatchAnalysisConstants.singleMatchFocusMax))
      (
        signal: s,
        drill: pickDrillInCategory(
          cat: s.category,
          drills: drills,
          logsByDrillOldestFirst: logsByDrill,
          excludeDrillIds: const {},
        ),
      ),
  ];
}

const _mappedCategories = [
  SkillCategory.breakShot,
  SkillCategory.aiming,
  SkillCategory.position,
  SkillCategory.safety,
];

/// Phân tích các trận hoàn tất gần nhất (xem [recentCompletedMatches]).
MatchAnalysis analyzeMatches(
  List<PoolMatch> matches, {
  int limit = MatchAnalysisConstants.recentMatches,
}) {
  final recent = recentCompletedMatches(matches, limit: limit);

  var racksWon = 0, racksLost = 0, racksWithShots = 0, fullRacks = 0;
  final playerBreak = _BreakTally();
  final opponentBreak = _BreakTally();
  var runOuts = 0, normalShots = 0, missedNormal = 0;
  var assessedPositions = 0, failedPositions = 0;
  var nextAfterFailed = 0, missAfterFailed = 0;
  var nextAfterGood = 0, missAfterGood = 0;
  var safeties = 0, assessedSafeties = 0, successfulSafeties = 0;
  var safetyTurnovers = 0, proactiveTurnovers = 0;
  var playerShots = 0, fouls = 0, scratches = 0;
  final lostCauses = {for (final c in LostRackCause.values) c: 0};
  final failures = {for (final c in _mappedCategories) c: 0};
  final attempts = {for (final c in _mappedCategories) c: 0};
  final matchCount = {for (final c in _mappedCategories) c: 0};

  for (final match in recent) {
    final seen = <SkillCategory>{};
    for (final attempt in shotSkillMap(match)) {
      attempts[attempt.category] = attempts[attempt.category]! + 1;
      if (attempt.failed) {
        failures[attempt.category] = failures[attempt.category]! + 1;
      }
      seen.add(attempt.category);
    }
    for (final c in seen) {
      matchCount[c] = matchCount[c]! + 1;
    }

    for (var i = 0; i < match.rackWinners.length; i++) {
      final rack = analyzeRack(match, i);
      if (rack.winner == RackWinner.player) {
        racksWon++;
      } else {
        racksLost++;
      }
      if (rack.hasShots) racksWithShots++;
      if (rack.isFull) fullRacks++;
      if (rack.breaker == RackWinner.player) playerBreak.add(rack);
      if (rack.breaker == RackWinner.opponent) opponentBreak.add(rack);
      if (rack.runOut) runOuts++;
      final lost = rack.lostRackCause;
      if (lost != null) lostCauses[lost] = lostCauses[lost]! + 1;

      for (final cause in rack.turnovers) {
        if (cause == TurnoverCause.safety) safetyTurnovers++;
        if (cause == TurnoverCause.safety ||
            cause == TurnoverCause.offensiveMiss) {
          proactiveTurnovers++;
        }
      }

      for (final shot in rack.shots) {
        if (shot.shooter != RackWinner.player) continue;
        playerShots++;
        if (shot.outcome == MatchShotOutcome.foul) fouls++;
        if (shot.outcome == MatchShotOutcome.scratch) scratches++;
        if (shot.type == MatchShotType.normal) {
          if (shot.outcome == MatchShotOutcome.made) normalShots++;
          if (shot.outcome == MatchShotOutcome.missed) {
            normalShots++;
            missedNormal++;
          }
        }

        final next = followingShotInFullRack(rack, shot);

        final position = shot.positionOutcome;
        if (position != null) {
          assessedPositions++;
          final isFail = position == PositionOutcome.unsuccessful;
          if (isFail) failedPositions++;
          if (next != null &&
              next.shooter == RackWinner.player &&
              next.type == MatchShotType.normal) {
            final miss = next.outcome == MatchShotOutcome.missed;
            if (isFail) {
              nextAfterFailed++;
              if (miss) missAfterFailed++;
            } else {
              nextAfterGood++;
              if (miss) missAfterGood++;
            }
          }
        }

        if (shot.type == MatchShotType.safety) {
          safeties++;
          if (next != null && next.shooter == RackWinner.opponent) {
            assessedSafeties++;
            if (next.outcome != MatchShotOutcome.made) successfulSafeties++;
          }
        }
      }
    }
  }

  final signals = {
    for (final c in _mappedCategories)
      c: SkillSignal(
        category: c,
        failures: failures[c]!,
        attempts: attempts[c]!,
        matches: matchCount[c]!,
      ),
  };

  return MatchAnalysis(
    matches: recent.length,
    racksWon: racksWon,
    racksLost: racksLost,
    racksWithShots: racksWithShots,
    fullRacks: fullRacks,
    playerBreak: playerBreak.build(),
    opponentBreak: opponentBreak.build(),
    runOuts: runOuts,
    normalShots: normalShots,
    missedNormal: missedNormal,
    assessedPositions: assessedPositions,
    failedPositions: failedPositions,
    nextAfterFailedPosition: nextAfterFailed,
    missAfterFailedPosition: missAfterFailed,
    nextAfterGoodPosition: nextAfterGood,
    missAfterGoodPosition: missAfterGood,
    safeties: safeties,
    assessedSafeties: assessedSafeties,
    successfulSafeties: successfulSafeties,
    safetyTurnovers: safetyTurnovers,
    proactiveTurnovers: proactiveTurnovers,
    playerShots: playerShots,
    fouls: fouls,
    scratches: scratches,
    lostRackCauses: Map.unmodifiable(lostCauses),
    signals: Map.unmodifiable(signals),
    weaknesses: List.unmodifiable(matchWeaknesses(
      signals.values,
      minMatches: MatchAnalysisConstants.minMatches,
      minAttempts: MatchAnalysisConstants.minAttempts,
    )),
  );
}
