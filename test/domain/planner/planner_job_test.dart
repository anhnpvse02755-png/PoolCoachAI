import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

void main() {
  /// Chạy [setup] từng lát, kiểm thứ tự sự kiện, trả các bước đã báo.
  List<PlanStep> sliced(TableSetup setup,
      {int? maxSimulations, Duration budget = sliceBudget}) {
    final job = PlannerJob(setup);
    final seen = <PlanStep>[];
    var done = 0;
    while (!job.isDone) {
      for (final e in job.step(budget: budget, maxSimulations: maxSimulations)) {
        switch (e) {
          case StepReady(:final index, :final step):
            expect(index, seen.length);
            seen.add(step);
          case PlanDone(:final steps):
            done++;
            expect(steps, seen);
        }
      }
    }
    expect(done, 1);
    return seen;
  }

  test('nối liền: bước sau bắt đầu đúng đối tượng điểm dừng của bước trước', () {
    for (final setup in [orderTable(GameType.nineBall), railTable(), fallbackTable()]) {
      final steps = planToEnd(setup);
      expect(identical(steps.first.cbFrom, setup.cue), isTrue);
      for (var i = 0; i + 1 < steps.length; i++) {
        expect(identical(steps[i].trace!.cueEnd, steps[i + 1].cbFrom), isTrue,
            reason: 'bước $i');
      }
    }
  });

  test('chạy từng lát cho đúng y kết quả chạy một mạch, với mọi cỡ lát', () {
    for (final setup in [orderTable(GameType.nineBall), railTable(), fallbackTable()]) {
      final whole = fingerprint(planToEnd(setup));
      for (final n in [1, 3, 7]) {
        expect(fingerprint(sliced(setup, maxSimulations: n)), whole, reason: 'lát $n');
      }
      expect(fingerprint(sliced(setup, budget: Duration.zero)), whole);
      expect(fingerprint(sliced(setup)), whole);
    }
  });

  test('tất định: cùng bàn chạy hai lần cho cùng kế hoạch', () {
    final setup = typicalNineBallTable();
    expect(fingerprint(planToEnd(setup)), fingerprint(planToEnd(setup)));
  });

  test('bước 1 báo ra trước khi cả kế hoạch xong', () {
    final job = PlannerJob(orderTable(GameType.nineBall));
    var events = <PlannerEvent>[];
    while (events.isEmpty) {
      events = job.step(maxSimulations: 1);
    }
    expect(events.single, isA<StepReady>());
    expect(job.isDone, isFalse);
    expect(job.totalSteps, 4);
  });

  test('hủy giữa chừng thì không báo thêm bước nào', () {
    final job = PlannerJob(orderTable(GameType.nineBall));
    while (job.steps.isEmpty) {
      job.step(maxSimulations: 1);
    }
    job.cancel();
    final sims = job.simulations;
    for (var i = 0; i < 50; i++) {
      expect(job.step(), isEmpty);
    }
    expect(job.simulations, sims);
    expect(job.steps, hasLength(1));
    expect(job.isDone, isFalse);
    expect(job.isCancelled, isTrue);
  });

  test('đặt lại bi cái: kế hoạch mới từ chỗ mới với các bi còn lại', () {
    final setup = orderTable(GameType.nineBall);
    final first = planToEnd(setup).first;
    const placed = Vec2(100, 50);
    final again = setup.without([first.ballNum!]).withCue(placed);
    final steps = planToEnd(again);
    expect(identical(steps.first.cbFrom, again.cue), isTrue);
    expect(steps.first.ballNum, 2);
    expect(steps.map((s) => s.ballNum), isNot(contains(1)));
    expect(fingerprint(steps), fingerprint(planToEnd(again)));
  });

  test('đặt lại bi cái vào chỗ không đánh được: bước đầu là phòng thủ', () {
    final steps = planToEnd(blockedEverywhereTable().withCue(const Vec2(200, 30)));
    expect(steps, hasLength(1));
    expect(steps.single.kind, PlanStepKind.safety);
  });

  test('8 bi chỉ còn bi 8: một bước, không có phần vị trí', () {
    final steps = planToEnd(onlyEightTable());
    expect(steps, hasLength(1));
    final s = steps.single;
    expect(s.ballNum, 8);
    expect(s.kind, PlanStepKind.normal);
    expect(s.nextBallNum, isNull);
    expect(s.tolerance, isNull);
    expect(s.missAdvice, isNull);
    expect(s.score!.position, 0);
  });

  test('bước thường có đủ thông tin hiển thị', () {
    final s = planToEnd(railTable()).first;
    expect(s.kind, PlanStepKind.normal);
    expect(s.nextBallNum, 2);
    final t = s.tolerance!;
    expect(t.good + t.fair + t.bad, toleranceSamples);
    expect(s.missAdvice, isNotNull);
    expect(s.sawsBhePercent, isNull);
    expect(s.jitterEnds, isNotNull);
  });

  group('thứ tự dự phòng (spec mục 5.5)', () {
    test('tầng 1: bàn thường không thử áp phê', () {
      final spins = <SideSpin>[];
      final steps =
          planToEnd(railTable(), aim: recordingAim((_, spin, _) => spins.add(spin)));
      expect(steps.every((s) => s.spin.isNone), isTrue);
      expect(spins.where((s) => !s.isNone), isEmpty);
    });

    test('tầng 2: không phương án thẳng nào dùng được thì áp phê, kèm SAWS, phạt cộng dồn', () {
      final setup = railTable();
      final ball1 = setup.balls.first.pos;
      final steps = planToEnd(setup,
          aim: scratchingAim((object, _, spin, _) => object == ball1 && spin.isNone));
      final s = steps.first;
      expect(s.kind, PlanStepKind.normal);
      expect(s.spin.isNone, isFalse);
      expect(
          s.sawsBhePercent,
          sawsBhePercent(
              distance: s.cbFrom.distanceTo(s.geometry!.ghost),
              power: s.power,
              stroke: s.stroke));
      expect(s.score!.tech, techPenaltyFor(s.stroke, s.spin));
      expect(s.score!.tech, greaterThanOrEqualTo(sidePenaltyHalfTip));
    });

    test('tầng 3: không vị trí nào cho bi sau thì Đánh đứng bi 30 %, kế hoạch đi tiếp', () {
      final steps = planToEnd(fallbackTable());
      expect(steps, hasLength(2));
      final s = steps.first;
      expect(s.kind, PlanStepKind.fallback);
      expect(s.ballNum, 1);
      expect(s.stroke, Stroke.stun);
      expect(s.power, fallbackPower);
      expect(s.spin.isNone, isTrue);
      expect(s.trace!.cuePocket, isNull);
      expect(steps[1].kind, PlanStepKind.safety);
      expect(steps[1].ballNum, 2);
      expect(identical(s.trace!.cueEnd, steps[1].cbFrom), isTrue);
    });

    test('tầng 4: cả cú dự phòng cũng hỏng thì phòng thủ, kế hoạch dừng', () {
      final setup = railTable();
      final ball1 = setup.balls.first.pos;
      final steps =
          planToEnd(setup, aim: scratchingAim((object, _, _, _) => object == ball1));
      expect(steps, hasLength(1));
      expect(steps.single.kind, PlanStepKind.safety);
      expect(steps.single.ballNum, 1);
    });

    test('9 bi: bi bắt buộc bị chắn ở mọi lỗ thì phòng thủ ngay', () {
      final job = PlannerJob(blockedEverywhereTable());
      final events = job.step(budget: const Duration(days: 1));
      expect(job.isDone, isTrue);
      expect(events.whereType<PlanDone>().single.steps.single.kind, PlanStepKind.safety);
      expect(job.simulations, 0);
    });
  });

  test('một phương án ném SimulationTimeout thì bị loại, kế hoạch vẫn ra', () {
    final setup = railTable();
    final ball1 = setup.balls.first.pos;
    final steps = planToEnd(setup,
        aim: timeoutAim((object, stroke, _, power) =>
            object == ball1 && stroke == Stroke.stun && power == 45));
    final s = steps.first;
    expect(s.kind, PlanStepKind.normal);
    expect(s.stroke == Stroke.stun && s.power == 45, isFalse);
  });
}
