import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Spec cú phòng thủ mục 9.1, chạy trên lõi vật lý thật. Bàn hết đúng điều
/// kiện thì dò lại bằng safety_probe_test.dart, đừng nới điều kiện.
void main() {
  late Map<String, (SafetyContext, SafetyJob)> runs;

  setUpAll(() {
    (SafetyContext, SafetyJob) run(TableSetup s) {
      final c = SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);
      final job = SafetyJob(c);
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      return (c, job);
    }

    runs = {
      'one': run(snookerOneRailTable()),
      'two': run(snookerTwoRailTable()),
      'three': run(snookerThreeRailTable()),
      'noPot': run(noPotTable()),
      'eight': run(eightSafetyTable()),
    };
  });

  int cueRailsBefore(ShotTrace t) =>
      t.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).length;

  test('mọi cú thủ được chọn đều đúng luật trên chính vết của nó', () {
    for (final MapEntry(:key, value: (c, job)) in runs.entries) {
      final s = job.result!;
      expect(
          safetyFoulOf(s.trace, rails: s.rails, obstacles: c.obstaclesOf(s.ballNum)), isNull,
          reason: key);
      expect(s.tolerance, inInclusiveRange(0, toleranceSamples), reason: key);
    }
  });

  test('3. bàn đui cần 1 băng: đúng 1 băng trước va chạm, chạm bi hợp lệ trước mọi bi khác', () {
    final (c, job) = runs['one']!;
    final s = job.result!;
    expect(s.reason, SafetyReason.snookered);
    expect(s.kind, SafetyKind.kick);
    expect(s.rails, 1);
    expect(cueRailsBefore(s.trace), 1);
    expect(polylineClear(s.trace.cueBefore, c.obstaclesOf(s.ballNum)), isTrue);
  });

  test('3. bàn buộc 2 băng và bàn buộc 3 băng', () {
    for (final (name, rails) in [('two', 2), ('three', 3)]) {
      final s = runs[name]!.$2.result!;
      expect(s.kind, SafetyKind.kick, reason: name);
      expect(s.rails, rails, reason: name);
      expect(cueRailsBefore(s.trace), rails, reason: name);
    }
  });

  test('4. có cú hợp lệ (trực tiếp hay 1–3 băng) thì không mô phỏng chuỗi 4 băng nào', () {
    for (final MapEntry(:key, value: (_, job)) in runs.entries) {
      expect(job.triedRailCounts, isNot(contains(maxKickRails)), reason: key);
      expect(job.openedStages.map((st) => st.tier), isNot(contains(SafetyTier.kickFallback)),
          reason: key);
    }
  });

  test('5. điểm ngắm theo chấm: lần chạm băng đầu của vết, làm tròn nửa chấm, đúng tên băng', () {
    for (final name in ['one', 'two', 'three']) {
      final s = runs[name]!.$2.result!;
      final first = s.trace.rails.firstWhere((h) => h.ball == ShotBall.cue && !h.afterContact);
      expect(s.railAim!.rail, first.rail, reason: name);
      expect(s.railAim!.diamond, diamondOf(first.pos, first.rail), reason: name);
      expect(s.railAim!.diamond * 2, (s.railAim!.diamond * 2).roundToDouble(), reason: name);
    }
  });

  test('7. không đui: trực tiếp và A băng thi trong cùng một lần tìm, cú trực tiếp thắng', () {
    for (final name in ['noPot', 'eight']) {
      final job = runs[name]!.$2;
      final s = job.result!;
      expect(s.reason, SafetyReason.noPot, reason: name);
      // A băng luôn được xét, kể cả khi không đui (chủ sản phẩm chốt
      // 08/10/2026); phạt A băng giữ cú trực tiếp thắng khi gần ngang.
      expect(job.openedStages.map((st) => st.tier), contains(SafetyTier.kick), reason: name);
      expect(job.options.where((o) => o.kind == SafetyKind.kick), isNotEmpty, reason: name);
      expect(s.kind, SafetyKind.direct, reason: name);
      expect(s.rails, 0, reason: name);
      expect(s.railAim, isNull, reason: name);
      expect(cueRailsBefore(s.trace), 0, reason: name);
    }
  });

  test('áp phê là đường lui: còn cú không áp phê hợp lệ thì không xét cú áp phê nào', () {
    for (final MapEntry(:key, value: (_, job)) in runs.entries) {
      expect(job.openedStages.map((st) => st.tier), isNot(contains(SafetyTier.directSpin)),
          reason: key);
      expect(job.options.every((o) => o.spin.isNone), isTrue, reason: key);
    }
  });

  test('8. 9 bi: đối thủ đánh đúng bi vừa chạm, ở vị trí mới', () {
    final s = runs['noPot']!.$2.result!;
    expect(s.opponent.ball!.number, 1);
    expect(s.opponent.ball!.pos, s.trace.objectPath.last);
  });

  test('8. 8 bi: đối thủ đánh bi nhóm kia, không phải bi vừa chạm', () {
    final s = runs['eight']!.$2.result!;
    expect(s.ballNum, 1);
    expect([9, 10], contains(s.opponent.ball!.number));
  });
}
