import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/coach_job.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/coach_fixtures.dart';
import '../../support/planner_tables.dart';

/// Mọi thứ của tham chiếu và kết luận mà người chơi thấy.
String coachFingerprint(CoachJob job) {
  final r = job.reference!;
  return [
    r.kind,
    r.tier,
    r.step.pocket,
    for (final o in r.scored) '${o.key.stroke}/${o.key.power}/${o.key.spin}/${o.score.total}',
    for (final o in r.accepted) '${o.key.stroke}/${o.key.power}',
    for (final v in job.verdicts)
      '${v.outcome}/${v.fault}/${v.breakage}/${v.blocker}/${v.scratchPocket}/'
          '${v.playerScore?.total}/${v.nearest?.key.stroke}/${v.nearest?.key.power}',
    safetyFingerprint(job.safetyShot),
  ].join('\n');
}

void main() {
  List<CoachAnswer> answersFor(TableSetup s) => [
        pot(s, Pocket.bottomMiddle, Stroke.draw, 30),
        pot(s, Pocket.bottomLeft, Stroke.follow, 30),
        pot(s, Pocket.bottomMiddle, Stroke.stun, 45, spin: const SideSpin(SpinSide.left, 0.5)),
        const SafetyAnswer(),
      ];

  CoachJob sliced(TableSetup s, {int? maxUnits, Duration budget = Duration.zero}) {
    final job = CoachJob(s, safety: noSafetyPhysics);
    answersFor(s).forEach(job.submit);
    var refEvents = 0;
    final graded = <int>[];
    while (!job.isIdle) {
      for (final e in job.step(budget: budget, maxUnits: maxUnits)) {
        switch (e) {
          case ReferenceReady():
            refEvents++;
          case Graded(:final index):
            graded.add(index);
          case SafetyReady():
            break;
        }
      }
    }
    expect(refEvents, 1);
    expect(graded, [0, 1, 2, 3]);
    return job;
  }

  test('chạy từng lát (nhiều cỡ lát) cho đúng y kết quả chạy một mạch', () {
    for (final s in [railTable(), cornerFollowTable()]) {
      final whole = coachFingerprint(gradeAll(s, answersFor(s)));
      for (final n in [1, 3, 7]) {
        expect(coachFingerprint(sliced(s, maxUnits: n)), whole, reason: 'lát $n');
      }
      expect(coachFingerprint(sliced(s, budget: const Duration(milliseconds: 4))), whole);
    }
  });

  test('tham chiếu khớp planToEnd(setup).first: cùng bi, lỗ, kiểu đánh, lực, áp phê', () {
    for (final s in [railTable(), cornerFollowTable(), typicalNineBallTable()]) {
      final ref = runCoachJob(CoachJob(s, safety: noSafetyPhysics)).reference!;
      final plan = planToEnd(s, safety: noSafetyPhysics).first;
      expect(ref.ball, plan.ballNum);
      expect(ref.step.pocket, plan.pocket);
      expect(ref.best!.key.stroke, plan.stroke);
      expect(ref.best!.key.power, plan.power);
      expect(ref.best!.key.spin, plan.spin);
    }
  });

  test('huỷ giữa chừng thì không báo thêm sự kiện', () {
    final s = railTable();
    final job = CoachJob(s, safety: noSafetyPhysics)..submit(pot(s, Pocket.bottomMiddle, Stroke.stun, 45));
    job.step(maxUnits: 2, budget: Duration.zero);
    job.cancel();
    final sims = job.cache.length;
    for (var i = 0; i < 20; i++) {
      expect(job.step(), isEmpty);
    }
    expect(job.cache.length, sims);
    expect(job.isIdle, isTrue);
  });

  test('bước 0 phòng thủ: tham chiếu báo trước cú thủ, Phòng thủ được chấm ngay', () {
    final s = noPotTable();
    final job = CoachJob(s)..submit(const SafetyAnswer());
    final order = <String>[];
    while (!job.isIdle) {
      for (final e in job.step(budget: const Duration(milliseconds: 20))) {
        switch (e) {
          case ReferenceReady(:final reference):
            expect(reference.kind, PlanStepKind.safety);
            order.add('ref');
          case Graded(:final verdict):
            expect(verdict.outcome, CoachOutcome.best);
            order.add('graded');
          case SafetyReady(:final done):
            order.add(done ? 'safetyDone' : 'safety');
        }
      }
    }
    expect(order.take(2), ['ref', 'graded']);
    expect(order.last, 'safetyDone');
    expect(job.safetyShot, isNotNull);
  });

  test('Phòng thủ khi chưa đủ dữ liệu: tìm thêm cú thủ để hiện cả hai cú (Q4)', () {
    final s = typicalNineBallTable();
    final job = runCoachJob(CoachJob(s)..submit(const SafetyAnswer()));
    expect(job.verdicts.single.undecided, CoachUndecidedReason.potVsSafety);
    expect(job.reference!.kind, PlanStepKind.normal);
    expect(job.safetyShot, isNotNull);
  });
}
