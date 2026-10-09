import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Dò hướng cơ cho cú thủ trên lõi vật lý thật (spec cú phòng thủ 3.3–3.4).
void main() {
  const table = TableSpec.nineFoot;
  final tol = contactTolerance * table.ballDiameter;

  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  test('cú trực tiếp: dò xong thì chạm đúng độ dày, không băng nào trước', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final open = openContacts(c.cue, target.pos, c.obstaclesOf(1));
    var converged = 0;
    for (final (f, side) in open) {
      final o = directOption(c, target, f, side, Stroke.follow, const SideSpin.none(), 45)!;
      final r = aimSafety(o, cue: c.cue);
      if (r == null) continue;
      converged++;
      final p = probeKick(inputOf(r.key), maxRails: 0);
      expect(p.railsBefore, isEmpty, reason: '$o');
      expect((lateralAt(p.cueAtContact!, target.pos) - o.lateral).abs(), lessThan(tol),
          reason: '$o');
    }
    // Không áp phê thì đường bi cái trước va chạm gần như thẳng.
    expect(converged, greaterThanOrEqualTo(open.length - 1));
  });

  test('áp phê: dò bù cả lệch do áp phê, vẫn đúng độ dày', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final o = directOption(c, target, 0.5, ThicknessSide.left, Stroke.follow,
        const SideSpin(SpinSide.right, 1), 60)!;
    final r = aimSafety(o, cue: c.cue)!;
    final p = probeKick(inputOf(r.key), maxRails: 0);
    expect((lateralAt(p.cueAtContact!, target.pos) - o.lateral).abs(), lessThan(tol));
    // Hướng cơ đã xoay khỏi hướng hình học: dòng áp phê có lượng dịch để nói.
    expect(aimOffsetDegOf(o, c.cue, r.key.aim).abs(), greaterThan(0));
  });

  test('đánh đứng bi: b dưới tâm, hết xoáy dọc lúc chạm', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final o = directOption(c, target, 1, ThicknessSide.full, Stroke.stun, const SideSpin.none(), 45)!;
    final r = aimSafety(o, cue: c.cue)!;
    expect(r.key.b, lessThanOrEqualTo(0));
    expect(r.stunReached, isTrue);
  });

  test('A băng 1 băng: hội tụ ở phần lớn phương án, mỗi cú hội tụ chạm đúng một băng', () {
    final c = contextOf(snookerOneRailTable());
    final target = c.legal.single;
    var converged = 0;
    for (final stroke in kickStrokes) {
      for (final power in powerCandidates) {
        final o = kickOption(c, target, const [Rail.top], 1, ThicknessSide.full, stroke, power)!;
        final r = aimSafety(o, cue: c.cue);
        if (r == null) continue;
        converged++;
        final p = probeKick(inputOf(r.key), maxRails: 1);
        expect(p.railsBefore, [Rail.top], reason: '$o');
        expect(lateralAt(p.cueAtContact!, target.pos).abs(), lessThan(tol), reason: '$o');
      }
    }
    // Nguyên mẫu trên a35667b: 8/10 hội tụ (đứng bi tính ở b = 0).
    expect(converged, greaterThanOrEqualTo(5));
  });

  test('không hội tụ thì bỏ phương án; chạm thử quá giờ cũng bỏ', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 1, ThicknessSide.full, Stroke.follow,
        const SideSpin.none(), 45)!;
    expect(aimSafety(o, cue: c.cue, physics: noSafetyPhysics), isNull);
    final slow = SafetyPhysics(
      probe: (input, {required maxRails}) => throw SimulationTimeout(input),
    );
    expect(aimSafety(o, cue: c.cue, physics: slow), isNull);
  });

  test('mô phỏng đủ quá giờ thì không có vết', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 1, ThicknessSide.full, Stroke.follow,
        const SideSpin.none(), 45)!;
    final r = aimSafety(o, cue: c.cue)!;
    expect(simulateSafety(r.key), isNotNull);
    expect(simulateSafety(r.key, physics: noSafetyPhysics), isNull);
  });

  test('đổi lực giữ nguyên hướng cơ và b', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 0.5, ThicknessSide.right, Stroke.draw,
        const SideSpin.none(), 45)!;
    final k = aimSafety(o, cue: c.cue)!.key;
    final j = withSimPower(k, 60);
    expect((j.aim, j.b, j.spin, j.power), (k.aim, k.b, k.spin, 60.0));
    expect(keyOf(inputOf(k)), k);
  });
}
