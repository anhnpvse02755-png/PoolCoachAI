import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Việc tìm cú thủ chia lát (spec cú phòng thủ 3.6, test 9.1.9). Phần lớn
/// test giới hạn số phương án mỗi chặng (maxOptions) để chạy nhanh: chia lát,
/// cắt tỉa và thứ tự chặng không phụ thuộc số phương án.
void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  /// Chạy tới hết; ở điểm hỏi thì "Tính tiếp" như người dùng bấm.
  SafetyJob runJob(SafetyContext c,
      {int? maxSimulations, Duration budget = const Duration(days: 1), int? maxOptions,
      bool prune = true, SafetyPhysics physics = const SafetyPhysics(), bool coarse = true}) {
    final job =
        SafetyJob(c, maxOptions: maxOptions, prune: prune, physics: physics, coarse: coarse);
    while (!job.isDone) {
      job.resume();
      job.step(budget: budget, maxSimulations: maxSimulations);
    }
    return job;
  }

  /// Chạy tới lúc lượt thô xong: điểm hỏi, cú tạm, hay không có cú nào.
  SafetyJob runToFirstShot(SafetyContext c,
      {int? maxSimulations, int? maxOptions, bool prune = true,
      SafetyPhysics physics = const SafetyPhysics()}) {
    final job = SafetyJob(c, maxOptions: maxOptions, prune: prune, physics: physics);
    while (!job.coarseDone) {
      job.step(budget: const Duration(days: 1), maxSimulations: maxSimulations ?? 1);
    }
    return job;
  }

  SafetyShot? run(SafetyContext c,
          {int? maxSimulations, Duration budget = const Duration(days: 1), int? maxOptions,
          bool prune = true, SafetyPhysics physics = const SafetyPhysics()}) =>
      runJob(c,
              maxSimulations: maxSimulations,
              budget: budget,
              maxOptions: maxOptions,
              prune: prune,
              physics: physics)
          .result;

  /// Chạy hết lượt đầy đủ (không lượt thô) và ghi thứ tự các lần dò theo chỉ số. Lõi
  /// thật, chỉ bọc hàm dò để biết lần dò nào của phương án nào: lần gọi đầu
  /// của mỗi đơn vị dò dùng đúng hướng cơ, `b`, lực và áp phê ban đầu của
  /// phương án (aimSafety), nên so được bằng giá trị. Con trỏ chấm dò theo
  /// chỉ số tăng dần; chỉ việc hỏi chặng áp phê mới quay lại dò một phương án
  /// đứng trước một phương án đã dò.
  ({SafetyJob job, List<int> aimed}) traceAims(SafetyContext c,
      {required int maxOptions, bool prune = true}) {
    late final SafetyJob job;
    final firstProbe = <int, (ShotInput, int)>{};
    const real = SafetyPhysics();
    job = SafetyJob(c,
        maxOptions: maxOptions,
        prune: prune,
        coarse: false,
        physics: SafetyPhysics(probe: (input, {required maxRails}) {
          // Mỗi đơn vị việc có một giá trị simulations riêng.
          firstProbe.putIfAbsent(job.simulations, () => (input, maxRails));
          return real.probe(input, maxRails: maxRails);
        }));
    while (!job.isDone) {
      job.step(budget: const Duration(days: 1));
    }
    final r = c.table.radius;
    final aimed = <int>[];
    for (final (input, rails) in firstProbe.values) {
      aimed.add(Iterable<int>.generate(job.options.length).firstWhere((i) {
        final o = job.options[i];
        return !aimed.contains(i) &&
            o.rails.length == rails &&
            o.ball == input.object &&
            o.power == input.power &&
            o.spin == input.spin &&
            strokeVerticalOffset(o.stroke, r) == input.verticalOffset &&
            o.initialAim + squirtAngle(sideOffsetOf(o.spin), r) == input.aimAngle;
      }));
    }
    return (job: job, aimed: aimed);
  }

  /// Các phương án được dò sau một phương án có chỉ số lớn hơn.
  List<int> aimedBack(List<int> aimed) {
    final back = <int>[];
    var highest = -1;
    for (final i in aimed) {
      if (i < highest) back.add(i);
      if (i > highest) highest = i;
    }
    return back;
  }

  const direct1 = (tier: SafetyTier.direct, ballNum: 1);
  const directSpin1 = (tier: SafetyTier.directSpin, ballNum: 1);
  const kicks = (tier: SafetyTier.kick, ballNum: null);
  const kickFallback = (tier: SafetyTier.kickFallback, ballNum: null);

  // Lõi thật, trừ cú trực tiếp không áp phê: không bao giờ chạm bi. Ép mọi
  // phương án không áp phê hỏng để thấy đường lui áp phê.
  final noPlain = SafetyPhysics(
    probe: (input, {required maxRails}) => maxRails == 0 && input.spin.isNone
        ? const KickProbe(cueAtContact: null, railsBefore: [], cuePocket: null)
        : probeKick(input, maxRails: maxRails),
  );

  group('danh sách phương án', () {
    test('trực tiếp: độ dày mở × kiểu đánh × áp phê × lực của một bi, đúng thứ tự', () {
      final c = contextOf(noPotTable());
      final target = c.legal.single;
      final open = openContacts(c.cue, target.pos, c.obstaclesOf(1));
      final plain = directOptions(c, target, const [SideSpin.none()]);
      expect(plain, hasLength(open.length * strokeCandidates.length * safetyPowers.length));
      expect(
          plain.every((o) => o.kind == SafetyKind.direct && o.rails.isEmpty && o.spin.isNone),
          isTrue);
      expect((plain.first.thickness, plain.first.side), open.first);
      expect((plain.first.stroke, plain.first.power),
          (strokeCandidates.first, safetyPowers.first));
      expect(plain[1].power, safetyPowers[1]);
      final spun = directOptions(c, target, safetySideSpins);
      expect(spun, hasLength(plain.length * safetySideSpins.length));
      expect(spun.any((o) => o.spin.isNone), isFalse);
      expect((spun.first.spin, spun[safetyPowers.length].spin),
          (safetySideSpins.first, safetySideSpins[1]));
    });

    test('A băng: ít băng trước, rồi bi, chuỗi, điểm chạm, kiểu đánh, lực; không áp phê', () {
      final c = contextOf(snookerOneRailTable());
      final options = kickOptions(c, fromRails: 1, toRails: 3);
      expect(options, isNotEmpty);
      final counts = options.map((o) => o.rails.length).toList();
      expect(counts, [...counts]..sort());
      expect(
          options.every(
              (o) => o.kind == SafetyKind.kick && kickStrokes.contains(o.stroke) && o.spin.isNone),
          isTrue);
      // Lực của cú thủ: 30 · 60 · 90 (chủ sản phẩm chốt 08/10/2026 sau Task 25).
      expect(options.map((o) => o.power).toSet(), safetyPowers.toSet());
      expect(kickOptions(c, fromRails: 4, toRails: 4).every((o) => o.rails.length == 4), isTrue);
    });

    test('thứ tự chặng: trực tiếp, áp phê, A băng 1–3, 4 băng; đui thì chỉ A băng', () {
      expect(SafetyJob(contextOf(noPotTable())).stages,
          [direct1, directSpin1, kicks, kickFallback]);
      expect(SafetyJob(contextOf(snookerOneRailTable())).stages, [kicks, kickFallback]);
      // Chưa làm đơn vị việc nào thì chưa mở chặng nào.
      expect(SafetyJob(contextOf(noPotTable())).options, isEmpty);
    });
  });

  group('áp phê là đường lui (chủ sản phẩm chốt 08/10/2026)', () {
    test('có cú không áp phê hợp lệ: không mở chặng áp phê, không dò cú áp phê nào', () {
      final job = runJob(contextOf(noPotTable()), maxOptions: 30);
      expect(job.result, isNotNull);
      expect(job.openedStages, [direct1, kicks]);
      expect(job.options.every((o) => o.spin.isNone), isTrue);
    });

    test('không cú không áp phê nào hợp lệ: mới thử áp phê, ngay sau bi đó và trước A băng', () {
      final job = runJob(contextOf(noPotTable()), maxOptions: 30, physics: noPlain);
      expect(job.openedStages.take(3), [direct1, directSpin1, kicks]);
      final firstSpun = job.options.indexWhere((o) => !o.spin.isNone);
      expect(firstSpun, 30);
      expect(job.options.skip(firstSpun).take(30).every((o) => o.kind == SafetyKind.direct),
          isTrue);
      expect(job.result, isNotNull);
    });
  });

  group('chia lát', () {
    test('chạy từng lát cho đúng y kết quả chạy một mạch, với mọi cỡ lát', () {
      // eightRingSafetyTable có cú bị cắt tỉa rồi được dò lúc hỏi chặng áp phê
      // (test bên dưới chứng minh), nên đường đó cũng được chạy từng lát.
      for (final s in [noPotTable(), snookerOneRailTable(), eightRingSafetyTable()]) {
        final c = contextOf(s);
        final whole = runJob(c, maxOptions: 40);
        final shot = safetyFingerprint(whole.result);
        for (final n in [1, 3]) {
          final sliced = runJob(c, maxOptions: 40, maxSimulations: n);
          expect(safetyFingerprint(sliced.result), shot, reason: 'lát $n');
          expect(sliced.openedStages, whole.openedStages, reason: 'lát $n');
        }
        expect(safetyFingerprint(run(c, maxOptions: 40, budget: Duration.zero)), shot);
      }
    });

    test('đường lui áp phê: chạy từng lát vẫn mở đúng các chặng như chạy một mạch', () {
      final c = contextOf(noPotTable());
      final whole = runJob(c, maxOptions: 20, physics: noPlain);
      final sliced = runJob(c, maxOptions: 20, physics: noPlain, maxSimulations: 1);
      expect(sliced.openedStages, whole.openedStages);
      expect(safetyFingerprint(sliced.result), safetyFingerprint(whole.result));
    });

    test('mỗi đơn vị việc chạy đúng một lần mô phỏng mới, hoặc không lần nào', () {
      final job = SafetyJob(contextOf(noPotTable()), maxOptions: 30);
      while (!job.isDone) {
        job.resume();
        final before = job.simulations;
        final ran = job.work();
        expect(job.simulations - before, ran ? 1 : 0);
      }
    });

    test('tất định: cùng bàn chạy hai lần cho cùng cú thủ', () {
      final c = contextOf(noPotTable());
      expect(safetyFingerprint(run(c, maxOptions: 40)), safetyFingerprint(run(c, maxOptions: 40)));
    });

    test('hủy giữa chừng thì không chạy thêm gì', () {
      final job = SafetyJob(contextOf(noPotTable()), maxOptions: 40);
      job.step(maxSimulations: 5);
      job.cancel();
      final sims = job.simulations;
      for (var i = 0; i < 20; i++) {
        job.step();
      }
      expect(job.simulations, sims);
      expect(job.isDone, isFalse);
      expect(job.isCancelled, isTrue);
    });

    test('cắt tỉa không đổi cú được chọn và các chặng được mở, chỉ bớt mô phỏng', () {
      for (final (s, physics) in [
        (noPotTable(), const SafetyPhysics()),
        (noPotTable(), noPlain),
        (eightRingSafetyTable(), const SafetyPhysics()),
      ]) {
        final c = contextOf(s);
        final pruned = runJob(c, maxOptions: 75, physics: physics);
        final full = runJob(c, maxOptions: 75, physics: physics, prune: false);
        expect(safetyFingerprint(pruned.result), safetyFingerprint(full.result));
        expect(pruned.openedStages, full.openedStages);
        // Nhỏ hơn hẳn: cắt tỉa thật sự bỏ được mô phỏng, không chỉ vô hại.
        expect(pruned.simulations, lessThan(full.simulations));
      }
    });

    test('cú bị cắt tỉa trước khi dò vẫn được dò khi hỏi bi đó có mở chặng áp phê không', () {
      // Bi 1 cho cú thủ tốt, nên cú trô 90 % (phạt cao) của các bi kẹt trong
      // vòng bị bỏ lúc chấm mà chưa dò; các bi đó không có cú không áp phê
      // nào hợp lệ, nên lúc hỏi chặng áp phê việc tìm phải quay lại dò chúng.
      // Từ 45 phương án mỗi chặng trở lên (lực 30 · 60 · 90).
      final c = contextOf(eightRingSafetyTable());
      for (final cap in [45, 81]) {
        final pruned = traceAims(c, maxOptions: cap);
        final full = traceAims(c, maxOptions: cap, prune: false);
        final back = aimedBack(pruned.aimed);
        expect(back, isNotEmpty, reason: 'mỗi chặng $cap');
        for (final i in back) {
          final o = pruned.job.options[i];
          expect((o.kind, o.spin.isNone), (SafetyKind.direct, true));
          // Chặng áp phê của bi đó đã được hỏi và được mở.
          expect(pruned.job.openedStages,
              contains((tier: SafetyTier.directSpin, ballNum: o.ballNum)));
        }
        // Không cắt tỉa thì mọi lần dò theo đúng thứ tự, không quay lại.
        expect(aimedBack(full.aimed), isEmpty);
        expect(full.aimed.toSet().containsAll(back), isTrue);
        expect(pruned.job.openedStages, full.job.openedStages);
        expect(safetyFingerprint(pruned.job.result), safetyFingerprint(full.job.result));
      }
    });
  });

  group('lượt thô và điểm hỏi (chủ sản phẩm chốt 08/10/2026 sau Task 25)', () {
    test('lượt thô: trọn bi và ½ bi không áp phê, A băng chạm trọn bi 1–2 băng; '
        'cùng đối tượng, cùng thứ tự với lượt đầy đủ', () {
      for (final s in [noPotTable(), snookerOneRailTable()]) {
        final c = contextOf(s);
        final job = runJob(c, maxOptions: 40);
        final rough = job.coarseOptions;
        expect(rough, isNotEmpty);
        for (final o in rough) {
          expect(o.spin.isNone, isTrue);
          if (o.kind == SafetyKind.direct) {
            expect(coarseThicknesses, contains(o.thickness));
          } else {
            expect(o.rails.length, lessThanOrEqualTo(coarseKickRails));
            expect(coarseKickThicknesses, contains(o.thickness));
          }
        }
        // Đúng các đối tượng của lượt đầy đủ, cùng thứ tự: bộ nhớ dò dùng
        // chung theo đối tượng phương án.
        final at = [for (final o in rough) job.options.indexWhere((f) => identical(f, o))];
        expect(at.every((i) => i >= 0), isTrue);
        expect(at, [...at]..sort());
        expect(job.options.where(isCoarseOption), hasLength(rough.length));
      }
    });

    test('thủ tốt: dừng ở điểm hỏi với cú lượt thô, không làm gì thêm cho tới khi tìm tiếp', () {
      final job = runToFirstShot(contextOf(snookerOneRailTable()), maxOptions: 40);
      expect(job.atCheckpoint, isTrue);
      expect(job.isDone, isFalse);
      expect(job.result, isNull);
      final rough = job.coarseResult!;
      expect(isGoodSafety(rough), isTrue);
      final sims = job.simulations;
      job.step();
      expect(job.work(), isFalse);
      expect(job.simulations, sims);
      expect(job.options, isEmpty);
      job.resume();
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      expect(job.result!.total, lessThanOrEqualTo(rough.total));
    });

    test('tìm tiếp ra đúng lượt đầy đủ chạy một mạch, không làm lại lượt thô; '
        'chỉ thay cú khi tốt hơn hẳn', () {
      // 60 phương án mỗi chặng: đủ để lượt thô của cả hai bàn thủ tốt.
      for (final s in [snookerOneRailTable(), noPotTable()]) {
        final c = contextOf(s);
        final paused = runToFirstShot(c, maxOptions: 60);
        expect(paused.atCheckpoint, isTrue, reason: '${s.cue}');
        final atPause = paused.simulations;
        final rough = paused.coarseResult!;
        paused.resume();
        while (!paused.isDone) {
          paused.step(budget: const Duration(days: 1));
        }
        final alone = runJob(c, maxOptions: 60, coarse: false);
        // Lượt đầy đủ giống hệt: cùng phương án, cùng chặng, cùng cú tốt nhất.
        expect(paused.options.map((o) => '$o'), alone.options.map((o) => '$o'));
        expect(paused.openedStages, alone.openedStages);
        expect(paused.bestIndex, alone.bestIndex);
        final full = alone.result!;
        if (full.total < rough.total) {
          expect(safetyFingerprint(paused.result), safetyFingerprint(full));
        } else {
          expect(identical(paused.result, rough), isTrue);
        }
        // Bộ nhớ đệm dùng chung: sau điểm hỏi chạy ít hơn lượt đầy đủ một mình.
        expect(paused.simulations - atPause, lessThan(alone.simulations));
      }
    });

    test('lượt thô không có cú hợp lệ: tìm tiếp luôn, không hỏi, không có cú tạm', () {
      final job = runToFirstShot(contextOf(noPotTable()), maxOptions: 30, physics: noSafetyPhysics);
      expect(job.coarseOptions, isNotEmpty);
      expect(job.coarseResult, isNull);
      expect(job.atCheckpoint, isFalse);
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      expect(job.result, isNull);
    });

    test('lượt thô chưa thủ tốt: không hỏi; cú tạm là cú lượt thô, tự tìm tiếp ra đúng lượt '
        'đầy đủ một mạch, chỉ thay khi tốt hơn hẳn', () {
      // 40 phương án mỗi chặng: cú lượt thô của bàn hết đường ăn để đối thủ
      // cắt 31.4° (đo với Task 25a–25b), chưa thủ tốt.
      final c = contextOf(noPotTable());
      final job = runToFirstShot(c, maxOptions: 40);
      expect(job.atCheckpoint, isFalse);
      final rough = job.coarseResult!;
      expect(isGoodSafety(rough), isFalse);
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      final alone = runJob(c, maxOptions: 40, coarse: false);
      expect(job.options.map((o) => '$o'), alone.options.map((o) => '$o'));
      expect(job.openedStages, alone.openedStages);
      expect(job.bestIndex, alone.bestIndex);
      final full = alone.result!;
      if (full.total < rough.total) {
        expect(safetyFingerprint(job.result), safetyFingerprint(full));
      } else {
        expect(identical(job.result, rough), isTrue);
      }
      // Chạy từng lát: cùng cú tạm, cùng cú cuối.
      for (final n in [1, 3]) {
        final sliced = runToFirstShot(c, maxOptions: 40, maxSimulations: n);
        expect(safetyFingerprint(sliced.coarseResult), safetyFingerprint(rough), reason: 'lát $n');
        while (!sliced.isDone) {
          sliced.step(budget: const Duration(days: 1), maxSimulations: n);
        }
        expect(safetyFingerprint(sliced.result), safetyFingerprint(job.result), reason: 'lát $n');
      }
    });

    test('lượt thô: chạy từng lát và có cắt tỉa hay không đều cho cùng điểm hỏi, '
        'cùng cú lượt thô, cùng cú cuối', () {
      for (final s in [noPotTable(), snookerOneRailTable(), eightRingSafetyTable()]) {
        final c = contextOf(s);
        final whole = runToFirstShot(c, maxOptions: 40);
        for (final other in [
          runToFirstShot(c, maxOptions: 40, maxSimulations: 1),
          runToFirstShot(c, maxOptions: 40, maxSimulations: 3),
          runToFirstShot(c, maxOptions: 40, prune: false),
        ]) {
          expect(other.atCheckpoint, whole.atCheckpoint);
          expect(safetyFingerprint(other.coarseResult), safetyFingerprint(whole.coarseResult));
        }
        final end = safetyFingerprint(runJob(c, maxOptions: 40).result);
        expect(safetyFingerprint(runJob(c, maxOptions: 40, maxSimulations: 3).result), end);
        expect(safetyFingerprint(runJob(c, maxOptions: 40, prune: false).result), end);
      }
    });
  });

  test('4 băng chỉ là đường lui: trực tiếp và 1–3 băng hỏng hết thì mới thử 4 băng', () {
    for (final s in [snookerOneRailTable(), noPotTable()]) {
      final c = contextOf(s);
      expect(kickOptions(c, fromRails: 4, toRails: 4), isNotEmpty);
      // Lõi thật, nhưng chỉ cho bi cái chạm bi khi được phép 4 băng.
      final onlyFour = SafetyPhysics(
        probe: (input, {required maxRails}) => maxRails < 4
            ? const KickProbe(cueAtContact: null, railsBefore: [], cuePocket: null)
            : probeKick(input, maxRails: maxRails),
      );
      final job = SafetyJob(c, physics: onlyFour);
      while (!job.isDone && !job.triedRailCounts.contains(4)) {
        job.step(budget: const Duration(days: 1), maxSimulations: 1);
      }
      expect(job.triedRailCounts, containsAll([1, 2, 3, 4]));
      expect(job.openedStages.last, kickFallback);
    }
  });

  test('không có cú thủ hợp lệ nào thì kết quả là null', () {
    expect(run(contextOf(noPotTable()), physics: noSafetyPhysics), isNull);
  });

  test('bi hợp lệ sát băng: tìm xong, không lỗi', () {
    final s = TableSetup(game: GameType.nineBall, cue: const Vec2(60, 60), balls: [
      PlacedBall(number: 1, pos: Vec2(200, TableSpec.nineFoot.minY)),
    ]);
    expect(() => run(contextOf(s), maxOptions: 30), returnsNormally);
  });
}
