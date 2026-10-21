import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/evaluation.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

/// Một thông số của cú Ăn bi, theo thứ tự xét lỗi chính (spec mục 6.7).
enum ShotParam { pocket, spin, stroke, power }

/// Các thông số [answer] khác [key], theo thứ tự lỗ → áp phê → kiểu đánh → lực.
List<ShotParam> differingParams(PotAnswer answer, ShotKey key) => [
      if (answer.pocket != key.pocket) ShotParam.pocket,
      if (answer.spin != key.spin) ShotParam.spin,
      if (answer.stroke != key.stroke) ShotParam.stroke,
      if (answer.power != key.power) ShotParam.power,
    ];

/// Cú trong [accepted] cần đổi ít thông số nhất so với [answer] (spec mục
/// 6.7). Hoà số thông số thì ưu tiên chỉ khác lực, rồi chỉ khác kiểu đánh,
/// rồi chỉ khác áp phê, rồi theo thứ tự trong [accepted]. Nguồn duy nhất
/// cho gợi ý 2. null khi [accepted] rỗng.
ScoredOption? nearestAccepted(PotAnswer answer, List<ScoredOption> accepted) {
  int tieRank(List<ShotParam> d) {
    if (d.length != 1) return 0;
    return switch (d.single) {
      ShotParam.power => 0,
      ShotParam.stroke => 1,
      ShotParam.spin => 2,
      ShotParam.pocket => 3,
    };
  }

  ScoredOption? best;
  (int, int)? bestRank;
  for (final o in accepted) {
    final d = differingParams(answer, o.key);
    final rank = (d.length, tieRank(d));
    final current = bestRank;
    if (current == null ||
        rank.$1 < current.$1 ||
        (rank.$1 == current.$1 && rank.$2 < current.$2)) {
      best = o;
      bestRank = rank;
    }
  }
  return best;
}

/// Lỗi chính khi cú có điểm nhưng ngoài tập đạt: thông số đầu tiên khác
/// [nearest] theo thứ tự lỗ → áp phê → kiểu đánh → lực (spec mục 6.7).
/// Áp phê chỉ là lỗi khi người chơi có áp phê mà [nearest] không có; khác
/// kiểu áp phê thì xét tiếp kiểu đánh và lực.
CoachFault worseFault(PotAnswer answer, ShotKey nearest) {
  final d = differingParams(answer, nearest);
  if (d.contains(ShotParam.pocket)) return CoachFault.pocketWorse;
  if (d.contains(ShotParam.spin) && !answer.spin.isNone && nearest.spin.isNone) {
    return CoachFault.spinUnneeded;
  }
  if (d.contains(ShotParam.stroke)) return CoachFault.strokeWorse;
  if (d.contains(ShotParam.power)) return CoachFault.powerWorse;
  return CoachFault.spinWorse;
}

/// Đúng cú dự phòng của Planner (Đánh đứng bi [fallbackPower], không áp phê).
bool _isFallbackShot(PotAnswer a, PlanStep step) =>
    a.pocket == step.pocket &&
    a.stroke == Stroke.stun &&
    a.power == fallbackPower &&
    a.spin.isNone;

/// Chấm [answer] so với tham chiếu [ref] (spec mục 6.5–6.7). [evaluation]
/// là kết quả [evaluateAnswer] của câu trả lời Ăn bi; null khi Phòng thủ.
CoachVerdict gradeAnswer(CoachReference ref, CoachAnswer answer, CoachEvaluation? evaluation) {
  final next = ref.nextBall;
  switch (answer) {
    case SafetyAnswer():
      return _gradeSafety(ref, next);
    case PotAnswer():
      return _gradePot(ref, answer, evaluation!, next);
  }
}

CoachVerdict _gradeSafety(CoachReference ref, int? next) {
  switch (ref.kind) {
    case PlanStepKind.safety:
      return CoachVerdict(outcome: CoachOutcome.best, nextBall: next);
    case PlanStepKind.fallback:
      return CoachVerdict(
          outcome: CoachOutcome.undecided,
          undecided: CoachUndecidedReason.potVsSafety,
          nextBall: next);
    case PlanStepKind.normal:
      if (ref.best!.score.position > zoneGood) {
        return CoachVerdict(
            outcome: CoachOutcome.undecided,
            undecided: CoachUndecidedReason.potVsSafety,
            nextBall: next);
      }
      return CoachVerdict(outcome: CoachOutcome.wrong, fault: CoachFault.shouldPot, nextBall: next);
  }
}

CoachVerdict _gradePot(CoachReference ref, PotAnswer a, CoachEvaluation e, int? next) {
  final nearest = nearestAccepted(a, ref.accepted);
  final plannerPots = ref.kind != PlanStepKind.safety;

  CoachVerdict broken(CoachFault fault,
      {UnmakeableReason? unmakeable, EvalRejected? rejected, EvalNoNext? noNext}) {
    final aimed = rejected?.aimed ?? noNext?.aimed;
    return CoachVerdict(
      outcome: CoachOutcome.wrong,
      fault: plannerPots ? fault : CoachFault.shouldSafety,
      breakage: fault,
      pocket: a.pocket,
      unmakeable: unmakeable,
      scratchPocket: rejected?.scratchPocket,
      blocker: rejected?.blocker,
      nextBall: next,
      playerAimed: aimed,
      nearest: nearest,
    );
  }

  switch (e) {
    case EvalTimeout():
      return CoachVerdict(
          outcome: CoachOutcome.undecided,
          undecided: CoachUndecidedReason.timeout,
          pocket: a.pocket,
          nextBall: next);
    case EvalUnmakeable():
      return broken(CoachFault.pocketUnmakeable, unmakeable: e.reason);
    case EvalRejected(:final rejection):
      return broken(
          switch (rejection) {
            Rejection.scratch => CoachFault.scratch,
            Rejection.objectMissed => CoachFault.objectMissed,
            Rejection.blocked => CoachFault.blocked,
          },
          rejected: e);
    case EvalNoNext():
      if (ref.kind == PlanStepKind.fallback && _isFallbackShot(a, ref.step)) {
        return CoachVerdict(
            outcome: CoachOutcome.best, pocket: a.pocket, nextBall: next, playerAimed: e.aimed);
      }
      return broken(CoachFault.noNextShot, noNext: e);
    case EvalScored(:final option):
      CoachVerdict verdict(CoachOutcome outcome,
              {CoachFault? fault, bool noPlannerPot = false}) =>
          CoachVerdict(
            outcome: outcome,
            fault: fault,
            pocket: a.pocket,
            nextBall: next,
            playerAimed: option.aimed,
            playerScore: option.score,
            nearest: outcome == CoachOutcome.wrong ? nearest : null,
            noPlannerPot: noPlannerPot,
          );
      final best = ref.best;
      if (best == null) {
        // Dự phòng hay phòng thủ: Planner không có cú ăn có điểm ở lỗ dễ
        // nhất, cú người chơi vào lỗ theo mô phỏng.
        if (ref.kind == PlanStepKind.fallback && _isFallbackShot(a, ref.step)) {
          return verdict(CoachOutcome.best);
        }
        return verdict(CoachOutcome.better, noPlannerPot: true);
      }
      if (option.key == best.key) return verdict(CoachOutcome.best);
      final t = option.score.total;
      final tStar = best.score.total;
      // Lỗ khác mà điểm thấp hơn hẳn thì "tốt hơn", xét trước "gần bằng".
      if (a.pocket != best.key.pocket && t < tStar) return verdict(CoachOutcome.better);
      if (t <= tStar + coachScoreTolerance) return verdict(CoachOutcome.equivalent);
      return verdict(CoachOutcome.wrong, fault: worseFault(a, nearest!.key));
  }
}
