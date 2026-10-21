import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

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
