import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/grading.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

void main() {
  const trace = ShotTrace(
    cueBefore: [Vec2(0, 0)],
    cueAfter: [],
    objectPath: [],
    contactCue: null,
    rails: [],
    cuePocket: null,
    objectPocket: null,
    cueEnd: Vec2(0, 0),
  );
  const aimed = AimedShot(
    trace: trace,
    uncompensated: null,
    aimOffsetDeg: 0,
    verticalOffset: 0,
    stunReached: true,
    converged: true,
  );
  const half = SideSpin(SpinSide.left, 0.5);

  ScoredOption o(Pocket pocket, Stroke stroke, double power, {SideSpin spin = const SideSpin.none()}) =>
      ScoredOption(
        (cue: Vec2.zero, object: Vec2.zero, pocket: pocket, stroke: stroke, spin: spin, power: power),
        aimed,
        const OptionScore(position: 0, bank: 0, tech: 0, power: 0, distance: 0),
      );
  PotAnswer a(Pocket pocket, Stroke stroke, double power, {SideSpin spin = const SideSpin.none()}) =>
      PotAnswer(ball: 1, pocket: pocket, stroke: stroke, power: power, spin: spin);

  test('đổi ít thông số nhất', () {
    final accepted = [
      o(Pocket.topLeft, Stroke.draw, 90),
      o(Pocket.bottomMiddle, Stroke.stun, 60),
    ];
    final n = nearestAccepted(a(Pocket.bottomMiddle, Stroke.stun, 45), accepted)!;
    expect(n.key.power, 60);
  });

  test('hoà số thông số: chỉ khác lực trước, rồi kiểu đánh, rồi áp phê', () {
    final answer = a(Pocket.bottomMiddle, Stroke.stun, 45);
    final spinOnly = o(Pocket.bottomMiddle, Stroke.stun, 45, spin: half);
    final strokeOnly = o(Pocket.bottomMiddle, Stroke.follow, 45);
    final powerOnly = o(Pocket.bottomMiddle, Stroke.stun, 75);
    expect(nearestAccepted(answer, [spinOnly, strokeOnly, powerOnly])!.key.power, 75);
    expect(nearestAccepted(answer, [spinOnly, strokeOnly])!.key.stroke, Stroke.follow);
    expect(nearestAccepted(answer, [o(Pocket.topLeft, Stroke.stun, 45), spinOnly])!.key.spin, half);
  });

  test('hoà hẳn thì theo thứ tự trong tập đạt', () {
    final answer = a(Pocket.bottomMiddle, Stroke.stun, 45);
    final first = o(Pocket.bottomMiddle, Stroke.follow, 60);
    final second = o(Pocket.bottomMiddle, Stroke.draw, 30);
    expect(identical(nearestAccepted(answer, [first, second]), first), isTrue);
    expect(identical(nearestAccepted(answer, [second, first]), second), isTrue);
  });

  test('tập đạt rỗng → null', () {
    expect(nearestAccepted(a(Pocket.topLeft, Stroke.stun, 30), const []), isNull);
  });

  test('lỗi chính theo thứ tự lỗ → áp phê → kiểu đánh → lực, kèm hướng lực', () {
    final n = o(Pocket.bottomMiddle, Stroke.stun, 45).key;
    expect(worseFault(a(Pocket.topLeft, Stroke.draw, 90), n), CoachFault.pocketWorse);
    expect(worseFault(a(Pocket.bottomMiddle, Stroke.draw, 90, spin: half), n), CoachFault.spinUnneeded);
    expect(worseFault(a(Pocket.bottomMiddle, Stroke.draw, 90), n), CoachFault.strokeWorse);
    expect(worseFault(a(Pocket.bottomMiddle, Stroke.stun, 90), n), CoachFault.powerWorse);
    // Cùng có áp phê nhưng khác kiểu: lỗi riêng, không gán nhầm "áp phê thừa".
    final spun = o(Pocket.bottomMiddle, Stroke.stun, 45, spin: half).key;
    expect(worseFault(a(Pocket.bottomMiddle, Stroke.stun, 45, spin: const SideSpin(SpinSide.right, 1)), spun),
        CoachFault.spinWorse);
  });
}
