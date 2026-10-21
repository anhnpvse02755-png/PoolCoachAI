import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import 'planner_tables.dart';

/// Câu trả lời Ăn bi cho bi phải chạm của [setup].
PotAnswer pot(TableSetup setup, Pocket pocket, Stroke stroke, double power,
        {SideSpin spin = const SideSpin.none()}) =>
    PotAnswer(
      ball: setup.balls.map((b) => b.number).reduce((a, b) => a < b ? a : b),
      pocket: pocket,
      stroke: stroke,
      power: power,
      spin: spin,
    );

/// Chạy CoachJob trên lõi thật tới hết, chấm lần lượt [answers].
CoachJob gradeAll(TableSetup setup, List<CoachAnswer> answers,
    {AimShotFn aim = aimShot, SafetyPhysics? safety}) {
  final job = CoachJob(setup, aim: aim, safety: safety ?? noSafetyPhysics);
  answers.forEach(job.submit);
  return runCoachJob(job);
}

/// Kết luận của một câu trả lời.
CoachVerdict gradeOne(TableSetup setup, CoachAnswer answer,
        {AimShotFn aim = aimShot, SafetyPhysics? safety}) =>
    gradeAll(setup, [answer], aim: aim, safety: safety).verdicts.single;

/// aimShot thật, nhưng cú nào khớp [when] thì bi mục tiêu không vào lỗ.
AimShotFn missingAim(
        bool Function(Vec2 object, Stroke stroke, SideSpin spin, double power) when) =>
    ({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
      double maxTime = maxSimTime,
    }) {
      final real = aimShot(
          cue: cue,
          object: object,
          pocket: pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          table: table,
          compensate: compensate,
          withUncompensated: withUncompensated,
          maxTime: maxTime);
      if (!when(object, stroke, spin, power)) return real;
      final t = real.trace;
      return AimedShot(
        trace: ShotTrace(
          cueBefore: t.cueBefore,
          cueAfter: t.cueAfter,
          objectPath: t.objectPath,
          contactCue: t.contactCue,
          rails: t.rails,
          cuePocket: null,
          objectPocket: null,
          cueEnd: t.cueEnd,
        ),
        uncompensated: real.uncompensated,
        aimOffsetDeg: real.aimOffsetDeg,
        verticalOffset: real.verticalOffset,
        stunReached: real.stunReached,
        converged: real.converged,
      );
    };

var _attemptCounter = 0;

/// Một lần làm, xong lúc [minute] (số lớn hơn là mới hơn).
CoachAttempt attempt(
  CoachAttemptOutcome outcome, {
  CoachTopic topic = CoachTopic.position,
  CoachFault? fault,
  int minute = 0,
}) {
  _attemptCounter++;
  final at = DateTime(2026, 10, 21, 8).add(Duration(minutes: minute));
  return CoachAttempt(
    id: 'a$_attemptCounter',
    userId: 'u1',
    situationKey: 'lib:x$_attemptCounter',
    topic: topic,
    difficulty: CoachDifficulty.easy,
    answers: const [],
    outcome: outcome,
    firstFault: fault,
    scoringVersion: coachScoringVersion,
    startedAt: at,
    finishedAt: at,
  );
}


/// Lõi giả, tức thì, cho widget test (spec mục 14.4): không chạy vật lý thật.
/// Bi mục tiêu luôn vào đúng lỗ; bi cái từ bi ảo đi theo hướng tiếp tuyến
/// (Đánh đứng bi), về phía lỗ (Đánh cu lê) hay lùi lại (Đánh trô bi), quãng
/// tỉ lệ với lực, kẹp trong mặt bàn. Đủ để mỗi câu trả lời có một điểm
/// dừng khác nhau, nên cách chấm thật của Planner cho kết luận khác nhau.
AimedShot fakeAim({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  SideSpin spin = const SideSpin.none(),
  required double power,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
  bool compensate = true,
  bool withUncompensated = true,
  double maxTime = maxSimTime,
}) {
  final pocketPos = table.pocketPosition(pocket);
  final u = (pocketPos - object).normalized;
  final ghost = object - u * table.ballDiameter;
  final aim = (ghost - cue).normalized;
  final tangent = (aim - u * aim.dot(u));
  final dir = switch (stroke) {
    Stroke.stun => tangent.length < 1e-9 ? Vec2.zero : tangent.normalized,
    Stroke.follow => aim,
    Stroke.draw => -aim,
  };
  final side = spin.isNone ? 0.0 : (spin.side == SpinSide.left ? -1.0 : 1.0) * spin.tips * 8;
  final end = table.clamp(ghost + dir * (power * 1.2) + dir.rightNormal * side);
  return AimedShot(
    trace: ShotTrace(
      cueBefore: [cue, ghost],
      cueAfter: [ghost, end],
      objectPath: [object, pocketPos],
      contactCue: ghost,
      rails: const [],
      cuePocket: null,
      objectPocket: pocket,
      cueEnd: end,
    ),
    uncompensated: null,
    aimOffsetDeg: 0,
    verticalOffset: 0,
    stunReached: true,
    converged: true,
  );
}
