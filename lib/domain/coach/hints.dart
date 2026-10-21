import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

// Gợi ý trả về **dữ liệu**, không phải chữ (spec mục 7): `Vi.coachHint…`
// dựng câu từ đúng dữ liệu này.

/// Gợi ý 1: hỏi về hậu quả của chính cú người chơi chọn (spec mục 7.1).
sealed class HintOne {
  const HintOne();
}

/// Đường bi cái tới bi ảo, hay đường bi vào lỗ, bị chắn.
final class HintPathBlocked extends HintOne {
  const HintPathBlocked(this.ball, this.pocket);
  final int ball;
  final Pocket pocket;
}

final class HintTooThin extends HintOne {
  const HintTooThin(this.pocket);
  final Pocket pocket;
}

final class HintGhostOff extends HintOne {
  const HintGhostOff(this.pocket);
  final Pocket pocket;
}

final class HintScratch extends HintOne {
  const HintScratch(this.pocket);
  final Pocket pocket;
}

final class HintMissed extends HintOne {
  const HintMissed(this.ball, this.pocket);
  final int ball;
  final Pocket pocket;
}

final class HintBlocker extends HintOne {
  const HintBlocker(this.blocker);
  final int blocker;
}

final class HintNoNext extends HintOne {
  const HintNoNext(this.next);
  final int next;
}

final class HintPosition extends HintOne {
  const HintPosition(this.next);
  final int next;
}

final class HintSimpler extends HintOne {
  const HintSimpler();
}

final class HintShouldPot extends HintOne {
  const HintShouldPot(this.ball);
  final int ball;
}

/// Gợi ý 2: chỉ ra thông số cần đổi, không nói giá trị đúng (spec mục 7.2).
sealed class HintTwo {
  const HintTwo();
}

final class Hint2Pocket extends HintTwo {
  const Hint2Pocket(this.ball);
  final int ball;
}

final class Hint2NoSpin extends HintTwo {
  const Hint2NoSpin();
}

final class Hint2NeedSpin extends HintTwo {
  const Hint2NeedSpin();
}

/// Đổi kiểu áp phê (lỗi [CoachFault.spinWorse]).
final class Hint2Spin extends HintTwo {
  const Hint2Spin();
}

final class Hint2Stroke extends HintTwo {
  const Hint2Stroke();
}

final class Hint2PowerLess extends HintTwo {
  const Hint2PowerLess();
}

final class Hint2PowerMore extends HintTwo {
  const Hint2PowerMore();
}

final class Hint2Pot extends HintTwo {
  const Hint2Pot(this.ball);
  final int ball;
}

final class Hint2Safety extends HintTwo {
  const Hint2Safety(this.ball);
  final int ball;
}

/// Gợi ý 2 kèm bi kế tiếp để vẽ vùng điều tốt; [zoneNext] null là không vẽ.
typedef HintTwoData = ({HintTwo hint, int? zoneNext});

/// Gợi ý 1 cho kết luận [v]; null khi [v] không phải `wrong`.
HintOne? hintOne(CoachVerdict v, CoachReference ref) {
  if (v.outcome != CoachOutcome.wrong) return null;
  final ball = ref.ball;
  final pocket = v.pocket;
  switch (v.consequence) {
    case CoachFault.pocketUnmakeable:
      return switch (v.unmakeable!) {
        UnmakeableReason.cueBlocked || UnmakeableReason.objectBlocked => HintPathBlocked(ball, pocket!),
        UnmakeableReason.tooThin => HintTooThin(pocket!),
        UnmakeableReason.ghostOffTable || UnmakeableReason.overlap => HintGhostOff(pocket!),
      };
    case CoachFault.scratch:
      return HintScratch(v.scratchPocket!);
    case CoachFault.objectMissed:
      return HintMissed(ball, pocket!);
    case CoachFault.blocked:
      return HintBlocker(v.blocker!);
    case CoachFault.noNextShot:
      return HintNoNext(v.nextBall!);
    case CoachFault.shouldPot:
      return HintShouldPot(ball);
    case CoachFault.pocketWorse ||
          CoachFault.strokeWorse ||
          CoachFault.powerWorse ||
          CoachFault.spinWorse:
      final next = v.nextBall;
      final yours = v.playerScore;
      final theirs = v.nearest?.score;
      if (next != null &&
          yours != null &&
          theirs != null &&
          zoneOf(yours.position).index > zoneOf(theirs.position).index) {
        return HintPosition(next);
      }
      return const HintSimpler();
    case CoachFault.spinUnneeded:
      return const HintSimpler();
    case CoachFault.shouldSafety || null:
      // shouldSafety luôn có lỗi hỏng cụ thể; null không xảy ra với `wrong`.
      return null;
  }
}

/// Thông số đầu tiên của [nearest] khác câu trả lời, theo áp phê → kiểu
/// đánh → lực, thành gợi ý 2. Lỗ khác thì gợi ý đổi lỗ.
HintTwo _paramHint(CoachVerdict v, ScoredOption nearest, int ball) {
  final a = v.answer!;
  final k = nearest.key;
  if (a.pocket != k.pocket) return Hint2Pocket(ball);
  if (a.spin != k.spin) {
    if (k.spin.isNone) return const Hint2NoSpin();
    if (a.spin.isNone) return const Hint2NeedSpin();
    return const Hint2Spin();
  }
  if (a.stroke != k.stroke) return const Hint2Stroke();
  return k.power < a.power ? const Hint2PowerLess() : const Hint2PowerMore();
}

/// Gợi ý 2 cho kết luận [v]; null khi [v] không phải `wrong`.
HintTwoData? hintTwo(CoachVerdict v, CoachReference ref) {
  if (v.outcome != CoachOutcome.wrong) return null;
  final ball = ref.ball;
  final next = ref.nextBall;
  final nearest = v.nearest;
  switch (v.fault!) {
    case CoachFault.pocketUnmakeable || CoachFault.pocketWorse:
      return (hint: Hint2Pocket(ball), zoneNext: null);
    case CoachFault.scratch || CoachFault.blocked || CoachFault.objectMissed || CoachFault.noNextShot:
      if (nearest != null && nearest.key.pocket == v.pocket) {
        return (hint: _paramHint(v, nearest, ball), zoneNext: next);
      }
      return (hint: Hint2Pocket(ball), zoneNext: next);
    case CoachFault.spinUnneeded:
      return (hint: const Hint2NoSpin(), zoneNext: null);
    case CoachFault.spinWorse:
      return (hint: const Hint2Spin(), zoneNext: next);
    case CoachFault.strokeWorse:
      return (hint: const Hint2Stroke(), zoneNext: next);
    case CoachFault.powerWorse:
      return (hint: _paramHint(v, nearest!, ball), zoneNext: next);
    case CoachFault.shouldPot:
      return (hint: Hint2Pot(ball), zoneNext: null);
    case CoachFault.shouldSafety:
      return (hint: Hint2Safety(ball), zoneNext: null);
  }
}
