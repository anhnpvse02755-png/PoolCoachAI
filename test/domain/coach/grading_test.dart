import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/evaluation.dart';
import 'package:poolcoachai/domain/coach/grading.dart';
import 'package:poolcoachai/domain/coach/reference.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';

void main() {
  group('railTable (đo trên feat/coach T1: stun 45 = 25.74, stun 60 = 26.37, stun 75 = 28.81)', () {
    final s = railTable();
    final job = gradeAll(s, [
      pot(s, Pocket.bottomMiddle, Stroke.stun, 45),
      pot(s, Pocket.bottomMiddle, Stroke.stun, 60),
      pot(s, Pocket.bottomMiddle, Stroke.draw, 30),
      pot(s, Pocket.bottomMiddle, Stroke.stun, 75),
      pot(s, Pocket.bottomLeft, Stroke.stun, 45),
      pot(s, Pocket.bottomLeft, Stroke.follow, 30),
      const SafetyAnswer(),
    ]);
    final ref = job.reference!;
    final v = job.verdicts;

    test('tham chiếu khớp planToEnd(setup).first', () {
      final plan = planToEnd(s, safety: noSafetyPhysics).first;
      expect(ref.step.pocket, plan.pocket);
      expect(ref.best!.key.stroke, plan.stroke);
      expect(ref.best!.key.power, plan.power);
      expect(ref.best!.key.spin, plan.spin);
      expect(ref.best!.score.total, plan.score!.total);
      expect(ref.tier, 1);
    });

    test('đúng cú Planner chọn (Đánh đứng bi 45 %) → best', () {
      expect(v[0].outcome, CoachOutcome.best);
      expect(v[0].passed, isTrue);
    });

    test('Đánh đứng bi 60 % chênh trong dung sai → equivalent', () {
      final stun60 = ref.scored.firstWhere((o) => o.key.stroke == Stroke.stun && o.key.power == 60);
      expect(stun60.score.total - ref.best!.score.total, lessThanOrEqualTo(coachScoreTolerance));
      expect(v[1].outcome, CoachOutcome.equivalent);
      expect(ref.accepted.map((o) => o.key), contains(stun60.key));
    });

    test('Đánh trô bi 30 % ngoài dung sai → wrong, lỗi kiểu đánh', () {
      expect(v[2].outcome, CoachOutcome.wrong);
      expect(v[2].fault, CoachFault.strokeWorse);
      expect(v[2].nearest, isNotNull);
      expect(v[2].playerScore, isNotNull);
    });

    test('chỉ khác lực, vừa quá dung sai → wrong(powerWorse), cú gần nhất lực nhỏ hơn', () {
      final stun75 = ref.scored.firstWhere((o) => o.key.stroke == Stroke.stun && o.key.power == 75);
      expect(stun75.score.total - ref.best!.score.total, greaterThan(coachScoreTolerance));
      expect(v[3].fault, CoachFault.powerWorse);
      expect(v[3].nearest!.key.power, lessThan(75));
    });

    test('lỗ khác, điểm trong dung sai → equivalent', () {
      expect(v[4].outcome, CoachOutcome.equivalent);
    });

    test('bi chắn trên đường → wrong(blocked) đúng số bi chắn', () {
      expect(v[5].fault, CoachFault.blocked);
      expect(v[5].blocker, 2);
      expect(v[5].playerAimed, isNotNull);
    });

    test('Phòng thủ khi cú ăn tốt nhất có vị trí tốt → wrong(shouldPot), có tính lần thử', () {
      expect(ref.best!.score.position, lessThanOrEqualTo(zoneGood));
      expect(v[6].fault, CoachFault.shouldPot);
      expect(v[6].counts, isTrue);
    });
  });

  test('cornerFollowTable: Đánh cu lê → wrong(scratch), đúng lỗ chết cái', () {
    final s = cornerFollowTable();
    final v = gradeOne(s, pot(s, Pocket.bottomRight, Stroke.follow, 45));
    expect(v.fault, CoachFault.scratch);
    expect(v.scratchPocket, Pocket.bottomRight);
  });

  test('lỗ bị chắn → pocketUnmakeable(objectBlocked); lỗ quá mỏng → tooThin', () {
    final t = typicalNineBallTable();
    final blocked = gradeOne(t, pot(t, Pocket.bottomMiddle, Stroke.stun, 45));
    expect(blocked.fault, CoachFault.pocketUnmakeable);
    expect(blocked.unmakeable, UnmakeableReason.objectBlocked);
    final c = cornerFollowTable();
    final thin = gradeOne(c, pot(c, Pocket.topLeft, Stroke.stun, 45));
    expect(thin.fault, CoachFault.pocketUnmakeable);
    expect(thin.unmakeable, UnmakeableReason.tooThin);
  });

  test('chọn lỗ khác có điểm thấp hơn → better (đo: góc trên phải cu lê 45 % = 32.27 < 39.51)', () {
    final s = railTable().withCue(const Vec2(30, 115));
    final job = gradeAll(s, [pot(s, Pocket.topRight, Stroke.follow, 45)]);
    final v = job.verdicts.single;
    expect(job.reference!.step.pocket, isNot(Pocket.topRight));
    expect(v.playerScore!.total, lessThan(job.reference!.best!.score.total));
    expect(v.outcome, CoachOutcome.better);
    expect(v.noPlannerPot, isFalse);
  });

  group('mốc dung sai và hoà điểm, trên tham chiếu dựng tay', () {
    final s = railTable();
    final base = runCoachJob(CoachJob(s, safety: noSafetyPhysics)).reference!;
    final aimed = base.best!.aimed;
    ScoredOption opt(Stroke stroke, double power, double total) => ScoredOption(
          (
            cue: base.best!.key.cue,
            object: base.best!.key.object,
            pocket: base.best!.key.pocket,
            stroke: stroke,
            spin: const SideSpin.none(),
            power: power,
          ),
          aimed,
          OptionScore(position: total, bank: 0, tech: 0, power: 0, distance: 0),
        );
    final a = opt(Stroke.stun, 45, 10);
    final b = opt(Stroke.stun, 60, 10 + coachScoreTolerance);
    final c = opt(Stroke.stun, 75, 10 + coachScoreTolerance + 1e-9);
    final d = opt(Stroke.draw, 30, 10 + coachScoreTolerance);
    final ref = CoachReference(
      setup: s,
      step: base.step,
      finder: base.finder,
      after: base.after,
      context: base.context,
      scored: [a, b, c, d],
      tier: 1,
    );
    PotAnswer answerOf(ScoredOption o) =>
        PotAnswer(ball: 1, pocket: o.key.pocket, stroke: o.key.stroke, power: o.key.power);

    test('chênh đúng bằng coachScoreTolerance → đạt; lớn hơn một chút → sai', () {
      expect(gradeAnswer(ref, answerOf(b), EvalScored(b)).outcome, CoachOutcome.equivalent);
      expect(gradeAnswer(ref, answerOf(c), EvalScored(c)).outcome, CoachOutcome.wrong);
    });

    test('hoà điểm: tập đạt theo điểm rồi theo thứ tự thử', () {
      expect(ref.accepted.map((o) => o.key.power), [45, 60, 30]);
      expect(ref.accepted.map((o) => o.key.stroke), [Stroke.stun, Stroke.stun, Stroke.draw]);
    });
  });

  test('noPotTable: Phòng thủ → best; Ăn bi → wrong(shouldSafety) kèm lỗi hỏng', () {
    final s = noPotTable();
    final job = gradeAll(s, [
      const SafetyAnswer(),
      pot(s, Pocket.topRight, Stroke.stun, 45),
    ]);
    expect(job.reference!.kind, PlanStepKind.safety);
    expect(job.verdicts[0].outcome, CoachOutcome.best);
    final v = job.verdicts[1];
    expect(v.fault, CoachFault.shouldSafety);
    expect(v.breakage, CoachFault.pocketUnmakeable);
    expect(v.consequence, CoachFault.pocketUnmakeable);
  });

  test('Phòng thủ khi vị trí cú ăn tốt nhất không tốt → undecided(potVsSafety), không tính lần thử', () {
    final s = typicalNineBallTable();
    final job = gradeAll(s, [const SafetyAnswer()]);
    expect(job.reference!.best!.score.position, greaterThan(zoneGood));
    final v = job.verdicts.single;
    expect(v.outcome, CoachOutcome.undecided);
    expect(v.undecided, CoachUndecidedReason.potVsSafety);
    expect(v.counts, isFalse);
  });

  test('lõi quá giờ ở cú người chơi chọn → undecided(timeout), không tính lần thử', () {
    final s = railTable();
    final v = gradeOne(s, pot(s, Pocket.bottomMiddle, Stroke.draw, 60),
        aim: timeoutAim((_, stroke, _, power) => stroke == Stroke.draw && power == 60));
    expect(v.outcome, CoachOutcome.undecided);
    expect(v.undecided, CoachUndecidedReason.timeout);
    expect(v.counts, isFalse);
  });

  test('bước 0 là dự phòng: đúng cú dự phòng → best; Phòng thủ → undecided(potVsSafety)', () {
    final s = fallbackTable();
    final job = gradeAll(s, [
      pot(s, Pocket.bottomLeft, Stroke.stun, fallbackPower),
      const SafetyAnswer(),
    ]);
    expect(job.reference!.kind, PlanStepKind.fallback);
    expect(job.verdicts[0].outcome, CoachOutcome.best);
    expect(job.verdicts[1].undecided, CoachUndecidedReason.potVsSafety);
  });

  test('cú bị loại không bao giờ đạt: mọi cú tầng 1 ở lỗ Planner chọn trên railTable', () {
    final s = railTable();
    final answers = [
      for (final st in strokeCandidates)
        for (final p in powerCandidates) pot(s, Pocket.bottomMiddle, st, p),
    ];
    final job = gradeAll(s, answers);
    final ref = job.reference!;
    for (var i = 0; i < answers.length; i++) {
      final a = answers[i];
      final scored = ref.scored.where((o) => a.matches(o.key)).firstOrNull;
      final v = job.verdicts[i];
      if (scored == null) {
        expect(v.passed, isFalse, reason: '${a.stroke} ${a.power}');
      } else {
        expect(v.passed, scored.score.total <= ref.best!.score.total + coachScoreTolerance,
            reason: '${a.stroke} ${a.power}');
      }
    }
  });
}
