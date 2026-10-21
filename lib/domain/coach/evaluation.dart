import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Kết quả chấm một câu trả lời Ăn bi bằng hàm của Planner (spec mục 6.4),
/// trước khi so với tham chiếu.
sealed class CoachEvaluation {
  const CoachEvaluation();
}

/// Hình học: lỗ này không đánh được.
final class EvalUnmakeable extends CoachEvaluation {
  const EvalUnmakeable(this.reason);
  final UnmakeableReason reason;
}

/// Lõi quá giờ ở cú người chơi chọn.
final class EvalTimeout extends CoachEvaluation {
  const EvalTimeout();
}

/// Bị vòng loại của Planner bỏ.
final class EvalRejected extends CoachEvaluation {
  const EvalRejected(this.rejection, this.aimed, {this.scratchPocket, this.blocker});
  final Rejection rejection;
  final AimedShot aimed;
  final Pocket? scratchPocket;
  final int? blocker;
}

/// Qua vòng loại nhưng từ chỗ bi cái dừng, bi kế tiếp không còn lỗ nào.
final class EvalNoNext extends CoachEvaluation {
  const EvalNoNext(this.aimed);
  final AimedShot aimed;
}

/// Có điểm.
final class EvalScored extends CoachEvaluation {
  const EvalScored(this.option);
  final ScoredOption option;
}

/// Số bi chắn đầu tiên trên đường đi của cú: xét [ShotTrace.cueBefore],
/// [ShotTrace.cueAfter] rồi [ShotTrace.objectPath] theo thứ tự, từng đoạn
/// một; trong một đoạn, bi chạm đường sớm nhất. null khi đường thông.
int? firstBlocker(ShotTrace trace, List<PlacedBall> balls, {TableSpec table = TableSpec.nineFoot}) {
  for (final path in [trace.cueBefore, trace.cueAfter, trace.objectPath]) {
    if (path.isEmpty) continue;
    final segments = path.length == 1
        ? [(path.first, path.first)]
        : [for (var i = 0; i + 1 < path.length; i++) (path[i], path[i + 1])];
    for (final (a, b) in segments) {
      PlacedBall? hit;
      var hitAt = double.infinity;
      for (final ball in balls) {
        if (distanceToSegment(ball.pos, a, b) >= table.ballDiameter) continue;
        final along = _alongSegment(ball.pos, a, b);
        if (along < hitAt) {
          hitAt = along;
          hit = ball;
        }
      }
      if (hit != null) return hit.number;
    }
  }
  return null;
}

double _alongSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len2 = ab.dot(ab);
  if (len2 == 0) return 0;
  return clampRange((p - a).dot(ab) / len2, 0, 1);
}

/// Chấm câu trả lời Ăn bi [answer] trên tham chiếu [ref] (spec mục 6.4),
/// dừng ở bước đầu tiên ra kết luận. Hàm thuần trên [lookup]: thiếu lần mô
/// phỏng nào thì [lookup] ném và người gọi chạy lại.
CoachEvaluation evaluateAnswer(PotAnswer answer, CoachReference ref, ShotLookup lookup) {
  final setup = ref.setup;
  final target = legalTargetsAmong(setup.game, setup.balls).first;
  // 1. Hình học.
  final shot = evaluateShot(
    cue: setup.cue,
    object: target.pos,
    pocket: answer.pocket,
    others: obstaclesFor(target, setup.balls),
    table: setup.table,
  );
  final ShotGeometry g;
  switch (shot) {
    case Unmakeable(:final reason):
      return EvalUnmakeable(reason);
    case Makeable(:final geometry):
      g = geometry;
  }
  final key = shotKey(g, answer.stroke, answer.power, spin: answer.spin);
  // Trùng một cú Planner đã chấm: dùng luôn điểm đã có.
  for (final o in ref.scored) {
    if (o.key == key) return EvalScored(o);
  }
  // 2. Mô phỏng.
  final aimed = lookup(key);
  if (aimed == null) return const EvalTimeout();
  // 3. Vòng loại.
  final ctx = ScoringContext(geometry: g, after: ref.after, lookup: lookup, next: ref.finder);
  final rejection = rejectionOf(aimed, answer.pocket, ctx.obstacles, table: setup.table);
  if (rejection != null) {
    return EvalRejected(
      rejection,
      aimed,
      scratchPocket: aimed.trace.cuePocket,
      blocker: rejection == Rejection.blocked
          ? firstBlocker(aimed.trace, ref.after, table: setup.table)
          : null,
    );
  }
  // 4. Chấm điểm.
  final score = scoreOption(ctx, key, aimed);
  if (score == null) return EvalNoNext(aimed);
  return EvalScored(ScoredOption(key, aimed, score));
}
