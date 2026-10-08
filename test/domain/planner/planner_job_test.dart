import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
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
    final job = PlannerJob(setup, safety: noSafetyPhysics);
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
      final steps = planToEnd(setup, safety: noSafetyPhysics);
      expect(identical(steps.first.cbFrom, setup.cue), isTrue);
      for (var i = 0; i + 1 < steps.length; i++) {
        expect(identical(steps[i].trace!.cueEnd, steps[i + 1].cbFrom), isTrue,
            reason: 'bước $i');
      }
    }
  });

  test('chạy từng lát cho đúng y kết quả chạy một mạch, với mọi cỡ lát', () {
    for (final setup in [orderTable(GameType.nineBall), railTable(), fallbackTable()]) {
      final whole = fingerprint(planToEnd(setup, safety: noSafetyPhysics));
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
    final steps = planToEnd(blockedEverywhereTable().withCue(const Vec2(200, 30)),
        safety: noSafetyPhysics);
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
      final steps = planToEnd(fallbackTable(), safety: noSafetyPhysics);
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
      final steps = planToEnd(setup,
          aim: scratchingAim((object, _, _, _) => object == ball1), safety: noSafetyPhysics);
      expect(steps, hasLength(1));
      expect(steps.single.kind, PlanStepKind.safety);
      expect(steps.single.ballNum, 1);
    });

    test('8 bi: có bi đánh được nhưng mọi cú hỏng thì phòng thủ không gắn số bi', () {
      final setup = opponentBlocksTable();
      final ball1 = setup.balls.first.pos;
      final steps = planToEnd(setup,
          aim: scratchingAim((object, _, _, _) => object == ball1), safety: noSafetyPhysics);
      expect(steps, hasLength(1));
      final s = steps.single;
      expect(s.kind, PlanStepKind.safety);
      expect(s.ballNum, isNull);
      expect(Vi.planSummary(s, index: 0, total: 1), contains(Vi.planSafety(null)));
      expect(Vi.planSafety(s.ballNum), startsWith('Không bi nào có đường đánh rõ ràng'));
    });

    test('9 bi: bi bắt buộc bị chắn ở mọi lỗ thì phòng thủ ngay, không thử cú ăn bi nào', () {
      var calls = 0;
      final job = PlannerJob(blockedEverywhereTable(),
          aim: recordingAim((_, _, _) => calls++), safety: noSafetyPhysics);
      final events = job.step(budget: const Duration(days: 1));
      expect(job.isDone, isTrue);
      expect(events.whereType<PlanDone>().single.steps.single.kind, PlanStepKind.safety);
      expect(calls, 0);
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

  group('bước phòng thủ tìm cú thủ (spec cú phòng thủ 3.1, 3.6)', () {
    test('không có cú thủ hợp lệ: giữ câu cũ, safety null, kế hoạch dừng', () {
      final steps = planToEnd(blockedEverywhereTable(), safety: noSafetyPhysics);
      expect(steps.single.kind, PlanStepKind.safety);
      expect(steps.single.safety, isNull);
      expect(steps.single.ballNum, 1);
    });

    test('đang tìm cú thủ: chưa báo bước nào, searchingSafety bật; xong thì báo đúng một bước', () {
      final job = PlannerJob(noPotTable(), safety: noSafetyPhysics);
      final first = job.step(maxSimulations: 1);
      expect(first, isEmpty);
      expect(job.searchingSafety, isTrue);
      final events = <PlannerEvent>[];
      while (!job.isDone) {
        events.addAll(job.step(budget: const Duration(days: 1)));
      }
      expect(events.whereType<StepReady>(), hasLength(1));
      expect(events.last, isA<PlanDone>());
      expect(job.searchingSafety, isFalse);
    });

    test('lát mặc định: sliceBudget khi tính bước, safetySliceBudget khi tìm cú thủ', () {
      final job = PlannerJob(noPotTable(), safety: noSafetyPhysics);
      expect(job.defaultBudget, sliceBudget);
      job.step(maxSimulations: 1);
      expect(job.searchingSafety, isTrue);
      expect(job.defaultBudget, safetySliceBudget);
    });

    test('hủy giữa lúc tìm cú thủ thì không báo thêm gì', () {
      final job = PlannerJob(noPotTable());
      while (!job.searchingSafety) {
        job.step(maxSimulations: 1);
      }
      job.step(maxSimulations: 3);
      job.cancel();
      final sims = job.simulations;
      for (var i = 0; i < 20; i++) {
        expect(job.step(), isEmpty);
      }
      expect(job.simulations, sims);
      expect(job.steps, isEmpty);
    });

    group('trên lõi thật, bàn hết đường ăn', () {
      // Một lần tìm đủ tốn vài giây (độ lệch 1 của kế hoạch): tính một lần.
      late List<PlanStep> whole;
      setUpAll(() => whole = planToEnd(noPotTable()));

      test('bước phòng thủ mang đúng cú thủ của lần tìm riêng, cbFrom vẫn là bi cái', () {
        final setup = noPotTable();
        final s = whole.single;
        expect(s.cbFrom, setup.cue);
        final alone = searchToEnd(SafetyContext(
            game: setup.game, cue: setup.cue, balls: setup.balls, table: setup.table));
        expect(safetyFingerprint(s.safety), safetyFingerprint(alone));
        expect(s.safety!.kind, SafetyKind.direct);
      });

      test('chạy từng lát cho đúng y một mạch, cả bước phòng thủ', () {
        final job = PlannerJob(noPotTable());
        while (!job.isDone) {
          if (job.safetyCheckpoint) job.continueSafety();
          job.step(maxSimulations: 7);
        }
        expect(fingerprint(job.steps), fingerprint(whole));
      });

      // Chủ sản phẩm chốt 08/10/2026 sau Task 25: lượt thô thủ tốt thì báo
      // bước ngay với cú đó và hỏi có tính tiếp không.
      PlannerJob toCheckpoint(List<PlannerEvent> events) {
        final job = PlannerJob(noPotTable());
        while (!job.safetyCheckpoint) {
          events.addAll(job.step(maxSimulations: 7));
        }
        return job;
      }

      test('điểm hỏi: báo bước phòng thủ với cú lượt thô, chưa xong, không tính gì thêm', () {
        final events = <PlannerEvent>[];
        final job = toCheckpoint(events);
        final step = job.steps.single;
        expect(events, [isA<StepReady>()]);
        expect((events.single as StepReady).step, same(step));
        expect(step.kind, PlanStepKind.safety);
        expect(step.safety, isNotNull);
        expect(job.isDone, isFalse);
        expect(job.searchingSafety, isFalse);
        final sims = job.simulations;
        expect(job.step(), isEmpty);
        expect(job.simulations, sims);
      });

      test('Dùng cú này: giữ cú lượt thô, kế hoạch xong', () {
        final job = toCheckpoint([]);
        final step = job.steps.single;
        final events = job.keepSafety();
        expect(events, [isA<PlanDone>()]);
        expect((events.single as PlanDone).steps.single, same(step));
        expect(job.isDone, isTrue);
        expect(job.safetyCheckpoint, isFalse);
        expect(job.step(), isEmpty);
      });

      test('Tính tiếp: tìm tiếp trên cùng việc tìm, báo lại bước khi cú mới tốt hơn hẳn', () {
        final job = toCheckpoint([]);
        final rough = job.steps.single.safety!;
        final sims = job.simulations;
        job.continueSafety();
        expect(job.searchingSafety, isTrue);
        final events = <PlannerEvent>[];
        while (!job.isDone) {
          events.addAll(job.step(maxSimulations: 7));
        }
        // Đo với Task 25a–25b: lượt đầy đủ ra cú trực tiếp tốt hơn hẳn cú A
        // băng của lượt thô.
        final s = job.steps.single.safety!;
        expect(s.total, lessThan(rough.total));
        expect(events, [isA<StepReady>(), isA<PlanDone>()]);
        expect((events.first as StepReady).index, 0);
        expect(fingerprint(job.steps), fingerprint(whole));
        expect(job.simulations, greaterThan(sims));
      });
    });

    // Chủ sản phẩm chốt 08/10/2026 sau Task 25: lượt thô chưa thủ tốt thì
    // hiện cú đó tạm, không hỏi, tự tìm tiếp.
    group('cú tạm', () {
      /// Chạy tới khi bước phòng thủ hiện ra, rồi tới hết; trả sự kiện từ lúc
      /// bước hiện ra và bước lúc đó.
      ({PlannerJob job, PlanStep first, List<PlannerEvent> after}) runProvisional(
          TableSetup setup) {
        final job = PlannerJob(setup);
        while (job.steps.isEmpty) {
          job.step(maxSimulations: 7);
        }
        final first = job.steps.single;
        expect(job.provisionalSafety, isTrue);
        expect(job.searchingSafety, isTrue);
        expect(job.safetyCheckpoint, isFalse);
        expect(job.isDone, isFalse);
        final after = <PlannerEvent>[];
        while (!job.isDone) {
          after.addAll(job.step(maxSimulations: 7));
        }
        expect(job.provisionalSafety, isFalse);
        return (job: job, first: first, after: after);
      }

      test('không có cú tốt hơn hẳn: cú tạm thành cú cuối, không báo lại bước', () {
        // Đo với Task 25a–25b: bàn 2 băng, lượt thô để đối thủ 39.1°, lượt đầy
        // đủ không tốt hơn hẳn.
        final r = runProvisional(snookerTwoRailTable());
        expect(r.after, [isA<PlanDone>()]);
        expect(r.job.steps.single, same(r.first));
        final alone = searchToEnd(SafetyContext(
            game: GameType.nineBall,
            cue: snookerTwoRailTable().cue,
            balls: snookerTwoRailTable().balls));
        expect(safetyFingerprint(r.first.safety), safetyFingerprint(alone));
      });

      test('có cú tốt hơn hẳn: báo lại đúng bước đó với cú của lượt đầy đủ', () {
        // Đo với Task 25a–25b: bàn 8 bi, cú tạm trọn bi đứng bi 30 %, lượt đầy
        // đủ ra ⅛ bi lệch phải tốt hơn hẳn.
        final setup = eightSafetyTable();
        final r = runProvisional(setup);
        expect(r.after, [isA<StepReady>(), isA<PlanDone>()]);
        expect((r.after.first as StepReady).index, 0);
        final s = r.job.steps.single.safety!;
        expect(s.total, lessThan(r.first.safety!.total));
        final alone = searchToEnd(
            SafetyContext(game: setup.game, cue: setup.cue, balls: setup.balls));
        expect(safetyFingerprint(s), safetyFingerprint(alone));
      });
    });
  });
}
