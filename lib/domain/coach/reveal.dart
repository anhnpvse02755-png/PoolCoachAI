import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Đáp án là cú ăn, cú thủ, hay cú ăn kèm câu "chưa đủ dữ liệu" (spec mục 7.3).
enum RevealKind { pot, safety, potVsSafety }

/// Câu áp phê theo mẫu SAWS của chủ sản phẩm (05/10/2026): số đầu cơ, "ngắm
/// như đánh tâm bi", % BHE và chữ chỉ lực. [bhe] là `step.sawsBhePercent` —
/// một nguồn, Planner đã tính.
typedef RevealSpin = ({SpinSide side, double tips, int bhe, SawsSpeed speed});

/// Một lý do của đáp án — chỉ khi khoản điểm thật sự khác (spec mục 7.3).
sealed class RevealReason {
  const RevealReason();
}

/// Vùng vị trí của cú tốt nhất cho bi kế tiếp.
final class ReasonZone extends RevealReason {
  const ReasonZone(this.zone, this.next);
  final CoachZone zone;
  final int next;
}

final class ReasonYourZone extends RevealReason {
  const ReasonYourZone(this.zone, this.next);
  final CoachZone zone;
  final int next;
}

final class ReasonYourScratch extends RevealReason {
  const ReasonYourScratch(this.pocket);
  final Pocket pocket;
}

final class ReasonYourBlocked extends RevealReason {
  const ReasonYourBlocked(this.blocker);
  final int blocker;
}

final class ReasonYourMissed extends RevealReason {
  const ReasonYourMissed(this.ball, this.pocket);
  final int ball;
  final Pocket pocket;
}

final class ReasonYourNoNext extends RevealReason {
  const ReasonYourNoNext(this.next);
  final int next;
}

final class ReasonYourUnmakeable extends RevealReason {
  const ReasonYourUnmakeable(this.ball, this.pocket);
  final int ball;
  final Pocket pocket;
}

final class ReasonNoSpin extends RevealReason {
  const ReasonNoSpin();
}

final class ReasonStroke extends RevealReason {
  const ReasonStroke(this.best, this.yours);
  final Stroke best;
  final Stroke yours;
}

final class ReasonPower extends RevealReason {
  const ReasonPower(this.best, this.yours);
  final double best;
  final double yours;
}

/// Dữ liệu đáp án (spec mục 7.3). Không có chữ nào ở đây.
final class Reveal {
  const Reveal({
    required this.kind,
    required this.step,
    required this.ball,
    this.best,
    this.spin,
    this.toleranceGood,
    this.missSide,
    this.railCount = 0,
    this.reasons = const [],
    this.equivalents = const [],
    this.safety,
  });

  final RevealKind kind;

  /// Bước 0 của Planner — bàn vẽ đúng bước này bằng `PlannerPainter`.
  final PlanStep step;
  final int ball;

  /// Cú tốt nhất; null ở bước dự phòng hay phòng thủ.
  final ScoredOption? best;
  final RevealSpin? spin;

  /// Số mức lực trong ±15 % vẫn để bi cái ở vùng tốt (`step.tolerance`).
  final int? toleranceGood;
  final MissSide? missSide;

  /// Số lần bi cái chạm băng sau va chạm (thông tin, không phải lỗi).
  final int railCount;
  final List<RevealReason> reasons;

  /// Tối đa [coachEquivalentsShown] cú trong tập đạt, trừ cú tốt nhất.
  final List<ScoredOption> equivalents;

  /// Cú thủ: của bước phòng thủ, hay của lần tìm riêng khi chưa đủ dữ liệu.
  final SafetyShot? safety;
}

/// Câu trả lời Ăn bi gần nhất người chơi đã chọn mà được chấm (không tính
/// lần chưa đủ dữ liệu).
CoachVerdict? _lastPot(List<CoachVerdict> verdicts) {
  for (final v in verdicts.reversed) {
    if (v.answer != null && v.counts) return v;
  }
  return null;
}

/// Lý do của đáp án, sinh từ chênh lệch từng khoản của `OptionScore` giữa cú
/// tốt nhất và cú gần nhất người chơi đã chọn (spec mục 7.3). Không có câu
/// lý do cố định: khoản nào bằng nhau thì không thành lý do.
List<RevealReason> revealReasons(CoachReference ref, List<CoachVerdict> verdicts) {
  final best = ref.best;
  if (best == null) return const [];
  final next = ref.nextBall;
  final bestZone = zoneOf(best.score.position);
  final zone = next == null ? null : ReasonZone(bestZone, next);
  final last = _lastPot(verdicts);
  if (last == null || last.passed) return [?zone];
  final a = last.answer!;
  switch (last.consequence) {
    case CoachFault.scratch:
      return [?zone, ReasonYourScratch(last.scratchPocket!)];
    case CoachFault.blocked:
      return [?zone, ReasonYourBlocked(last.blocker!)];
    case CoachFault.objectMissed:
      return [?zone, ReasonYourMissed(ref.ball, a.pocket)];
    case CoachFault.noNextShot:
      return [?zone, ReasonYourNoNext(next!)];
    case CoachFault.pocketUnmakeable:
      return [?zone, ReasonYourUnmakeable(ref.ball, a.pocket)];
    default:
      break;
  }
  final yours = last.playerScore;
  if (yours == null) return [?zone];
  final yourZone = zoneOf(yours.position);
  final sameZone = next == null || yourZone == bestZone;
  final b = best.key;
  return [
    if (!sameZone) ...[zone!, ReasonYourZone(yourZone, next)],
    if (yours.tech > best.score.tech && !a.spin.isNone && b.spin.isNone) const ReasonNoSpin(),
    if (yours.tech > best.score.tech &&
        techPenaltyFor(a.stroke, const SideSpin.none()) >
            techPenaltyFor(b.stroke, const SideSpin.none()))
      ReasonStroke(b.stroke, a.stroke),
    if (sameZone && yours.power > best.score.power) ReasonPower(b.power, a.power),
  ];
}

/// Đáp án của tình huống (spec mục 7.3). [safety] là cú thủ để hiện: của
/// bước phòng thủ, hoặc của lần tìm riêng khi kết luận chưa đủ dữ liệu.
Reveal buildReveal(CoachReference ref, List<CoachVerdict> verdicts, {SafetyShot? safety}) {
  final step = ref.step;
  if (ref.kind == PlanStepKind.safety) {
    return Reveal(kind: RevealKind.safety, step: step, ball: ref.ball, safety: safety ?? ref.safety);
  }
  final potVsSafety = verdicts.any((v) => v.undecided == CoachUndecidedReason.potVsSafety);
  final best = ref.best;
  final spin = step.spin;
  return Reveal(
    kind: potVsSafety ? RevealKind.potVsSafety : RevealKind.pot,
    step: step,
    ball: ref.ball,
    best: best,
    spin: spin.isNone
        ? null
        : (side: spin.side!, tips: spin.tips, bhe: step.sawsBhePercent!, speed: sawsSpeed(step.power)),
    toleranceGood: step.tolerance?.good,
    missSide: step.missAdvice?.safer,
    railCount: step.trace?.cueRailCount ?? 0,
    reasons: revealReasons(ref, verdicts),
    equivalents: [
      for (final o in ref.accepted)
        if (!identical(o, best)) o,
    ].take(coachEquivalentsShown).toList(),
    safety: potVsSafety ? safety : null,
  );
}
