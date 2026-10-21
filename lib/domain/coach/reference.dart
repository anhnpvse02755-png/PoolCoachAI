import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';

/// Vùng vị trí của một cú, theo `score.position` và đúng hai hằng số vùng
/// điều của Planner (spec mục 7.1).
enum CoachZone { good, fair, hard }

CoachZone zoneOf(double position) {
  if (position <= zoneGood) return CoachZone.good;
  if (position <= zoneFair) return CoachZone.fair;
  return CoachZone.hard;
}

/// Tập đạt (spec mục 6.2): mọi cú có `total ≤ best + coachScoreTolerance`
/// (có dấu bằng, không làm tròn), sắp theo điểm tăng dần rồi theo thứ tự
/// thử — sắp ổn định nên hoà điểm vẫn tất định.
List<ScoredOption> acceptedOf(List<ScoredOption> scored) {
  final best = bestOf(scored);
  if (best == null) return const [];
  final limit = best.score.total + coachScoreTolerance;
  final indexed = [
    for (var i = 0; i < scored.length; i++)
      if (scored[i].score.total <= limit) (i, scored[i]),
  ]..sort((a, b) {
      final byScore = a.$2.score.total.compareTo(b.$2.score.total);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
  return List.unmodifiable([for (final e in indexed) e.$2]);
}

/// Đáp án tham chiếu của một tình huống: bước 0 của Planner và các phương án
/// đã chấm của tầng Planner đã dùng (spec mục 6.2).
final class CoachReference {
  CoachReference({
    required this.setup,
    required this.step,
    required this.finder,
    required this.after,
    this.context,
    this.scored = const [],
    this.tier = 0,
    this.safety,
  })  : best = bestOf(scored),
        accepted = acceptedOf(scored);

  final TableSetup setup;

  /// Bước 0 của Planner.
  final PlanStep step;

  /// Bộ tìm cú dễ nhất dùng khi chấm — cùng hàm Planner chọn bi kế tiếp.
  final CandidateFinder finder;

  /// Bi còn trên bàn sau khi bi phải chạm vào lỗ.
  final List<PlacedBall> after;

  /// Ngữ cảnh chấm ở lỗ Planner chọn; null khi bước 0 là phòng thủ.
  final ScoringContext? context;

  /// Phương án dùng được của tầng Planner đã dùng, đúng thứ tự thử. Rỗng khi
  /// bước 0 là dự phòng hay phòng thủ.
  final List<ScoredOption> scored;

  /// Tầng 1 (không áp phê) hay 2 (áp phê); 0 khi [scored] rỗng.
  final int tier;
  final ScoredOption? best;
  final List<ScoredOption> accepted;

  /// Cú thủ, chỉ khi bước 0 là phòng thủ và việc tìm đã ra.
  final SafetyShot? safety;

  /// Bi phải chạm.
  int get ball => step.ballNum ?? legalTargetsAmong(setup.game, setup.balls).first.number;

  /// Bi kế tiếp sau bi phải chạm (bi số nhỏ nhất còn lại); null khi là bi cuối.
  int? get nextBall => legalTargetsAmong(setup.game, after).firstOrNull?.number;

  PlanStepKind get kind => step.kind;

  /// Cùng tham chiếu, có cú thủ.
  CoachReference withSafety(SafetyShot? shot) => CoachReference(
        setup: setup,
        step: PlanStep.safety(cbFrom: step.cbFrom, ballNum: step.ballNum, safety: shot),
        finder: finder,
        after: after,
        context: context,
        scored: scored,
        tier: tier,
        safety: shot,
      );
}

/// Dựng tham chiếu từ bước 0 [step] của Planner (spec mục 5.3 bước 1). Hàm
/// thuần trên [lookup]: mọi lần mô phỏng của tầng Planner đã dùng có sẵn
/// trong bộ nhớ chung; thiếu thì [lookup] ném và người gọi chạy lại.
CoachReference buildReference(TableSetup setup, PlanStep step, ShotLookup lookup) {
  final finder = CandidateFinder(game: setup.game, table: setup.table);
  final target = legalTargetsAmong(setup.game, setup.balls).first;
  final after = [for (final b in setup.balls) if (b.number != target.number) b];
  if (step.kind == PlanStepKind.safety) {
    return CoachReference(
        setup: setup, step: step, finder: finder, after: after, safety: step.safety);
  }
  final g = step.geometry!;
  final ctx = ScoringContext(geometry: g, after: after, lookup: lookup, next: finder);
  if (step.kind == PlanStepKind.fallback) {
    return CoachReference(setup: setup, step: step, finder: finder, after: after, context: ctx);
  }
  final one = scoreTier(ctx, tierOneKeys(g));
  if (one.isNotEmpty) {
    return CoachReference(
        setup: setup, step: step, finder: finder, after: after, context: ctx, scored: one, tier: 1);
  }
  return CoachReference(
    setup: setup,
    step: step,
    finder: finder,
    after: after,
    context: ctx,
    scored: scoreTier(ctx, tierTwoKeys(g)),
    tier: 2,
  );
}
