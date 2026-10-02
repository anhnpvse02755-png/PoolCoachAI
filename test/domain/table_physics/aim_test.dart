import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  const right1 = SideSpin(SpinSide.right, 1);
  const left1 = SideSpin(SpinSide.left, 1);

  AimedShot aim(ShotGeometry g, Stroke stroke,
          {double power = 45,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal,
          bool compensate = true}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          compensate: compensate);

  /// Đường thẳng tâm bi mục tiêu → điểm lỗ chạm biên ở trong vùng lỗ:
  /// bi mục tiêu đi đúng hướng thì rơi lỗ trước khi chạm băng. Cú vào
  /// lỗ giữa ở góc quá xiên thì không — ngoài bàn thật cũng thế.
  bool reachesPocketZone(ShotGeometry g) {
    final p = table.pocketPosition(g.pocket);
    final d = (p - g.object).normalized;
    double toBound(double from, double dir, double lo, double hi) => dir > 0
        ? (hi - from) / dir
        : dir < 0
            ? (lo - from) / dir
            : double.infinity;
    final s = math.min(toBound(g.object.x, d.x, table.minX, table.maxX),
        toBound(g.object.y, d.y, table.minY, table.maxY));
    return (g.object + d * s).distanceTo(p) <= table.captureRadius(g.pocket);
  }

  group('bù ném', () {
    test('lưới: có bù thì hội tụ, và bi mục tiêu vào đúng lỗ đã chọn', () {
      final shots = gridShots().toList();
      var checked = 0;
      for (var i = 0; i < shots.length; i += 4) {
        final g = shots[i];
        for (final stroke in Stroke.values) {
          for (final spin in [
            const SideSpin.none(),
            right1,
            const SideSpin(SpinSide.left, 2),
          ]) {
            for (final power in [30.0, 90.0]) {
              final a = aim(g, stroke, power: power, spin: spin);
              final where = '${g.cue}→${g.object} $stroke $spin $power';
              expect(a.converged, isTrue, reason: where);
              if (!reachesPocketZone(g)) continue;
              checked++;
              expect(a.trace.objectPocket, g.pocket, reason: where);
            }
          }
        }
      }
      expect(checked, greaterThan(1000));
    });

    test('ngay sau va chạm bi mục tiêu chạy vào tâm lỗ, sai dưới aimTolerance',
        () {
      final g = geometryFor(const Vec2(180, 40), Pocket.topRight, 30);
      final s = solveAim(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.follow,
          spin: right1,
          power: 45,
          elevation: CueElevation.normal,
          table: table,
          compensate: true);
      final probe = probeContact(s.aimed)!;
      final error = probe.objectAfter.vel
              .signedAngleTo(table.pocketPosition(g.pocket) - g.object)
              .abs() *
          180 /
          math.pi;
      expect(error, lessThan(aimTolerance));
    });

    test('không áp phê, cắt góc: ném làm bi mục tiêu mỏng đi nên ngắm mỏng hơn',
        () {
      for (final cut in [15.0, 30.0, 45.0, 60.0]) {
        final a = aim(geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut),
            Stroke.stun);
        expect(a.aimOffsetDeg, lessThan(0), reason: '$cut°');
      }
    });

    group('aimOffsetDeg là góc xoay thật, dương là về phía tâm bi mục tiêu',
        () {
      // Cắt 5°, cách 40 cm: hướng hình học lệch tâm bi mục tiêu chưa tới
      // 1°, nên bù ném một độ là đủ vượt qua đường tâm sang phía bên kia.
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 5);
      AimSolution solve(SideSpin spin) => solveAim(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.stun,
          spin: spin,
          power: 45,
          elevation: CueElevation.normal,
          table: table,
          compensate: true);
      Vec2 dir(double a) => Vec2(math.cos(a), math.sin(a));
      double turnDeg(AimSolution s) =>
          dir(s.geometric.aimAngle).signedAngleTo(dir(s.aimed.aimAngle)).abs() *
          180 /
          math.pi;
      // Bên nào của đường tâm cái → bi mục tiêu.
      double sideOf(double aim) => dir(aim).cross(g.object - g.cue).sign;

      test('bù vượt qua đường tâm: đủ độ lớn, chiều dày hơn', () {
        final s = solve(left1);
        expect(sideOf(s.aimed.aimAngle), -sideOf(s.geometric.aimAngle),
            reason: 'bố cục phải có cú bù vượt qua đường tâm');
        expect(s.aimOffsetDeg, greaterThan(0));
        expect(s.aimOffsetDeg, closeTo(turnDeg(s), 1e-9));
      });

      test('áp phê trái và phải cho hai chiều ngược nhau', () {
        final left = solve(left1);
        final right = solve(right1);
        expect(right.aimOffsetDeg, lessThan(0));
        expect(right.aimOffsetDeg.abs(), closeTo(turnDeg(right), 1e-9));
        expect(left.aimOffsetDeg.sign, -right.aimOffsetDeg.sign);
      });

      test('AimedShot dùng đúng aimOffsetDeg của AimSolution', () {
        final s = solve(left1);
        expect(aim(g, Stroke.stun, spin: left1).aimOffsetDeg, s.aimOffsetDeg);
      });
    });

    test('tắt bù, có áp phê: bi mục tiêu lệch đúng chiều, đối xứng hai bên',
        () {
      // Bắn thẳng, 40 cm: áp phê phải làm bi cái lệch sang trái, chạm vào
      // nửa trái bi mục tiêu, nên bi mục tiêu đi lệch sang phải; trái
      // ngược lại. Swerve ở cơ Thường kéo về một phần, không đổi chiều.
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 0);
      double deviation(SideSpin spin) {
        final t = aim(g, Stroke.follow, spin: spin, compensate: false).trace;
        final dir = t.objectPath[1] - t.objectPath[0];
        return g.objectDir.signedAngleTo(dir) * 180 / math.pi;
      }

      final right = deviation(right1);
      final left = deviation(left1);
      expect(right, greaterThan(1));
      // Bàn không đối xứng qua đường bắn nên chỉ gần bằng nhau.
      expect(left, closeTo(-right, 0.01));
    });

    test('đường đỏ là đúng cú ngắm thẳng vào Bi ảo hình học', () {
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 20);
      final on = aim(g, Stroke.follow, spin: right1);
      final off = aim(g, Stroke.follow, spin: right1, compensate: false);
      expect(on.uncompensated!.objectPath, off.trace.objectPath);
      expect(off.uncompensated, isNull);
      expect(off.aimOffsetDeg, 0);
      expect(off.converged, isTrue);
    });

    test('bỏ đường đỏ: cùng cú đánh đã bù, chỉ không mô phỏng thêm', () {
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 20);
      final full = aim(g, Stroke.follow, spin: right1);
      final lean = aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.follow,
          spin: right1,
          power: 45,
          withUncompensated: false);
      expect(lean.uncompensated, isNull);
      expect(lean.trace.objectPath, full.trace.objectPath);
      expect(lean.trace.cueBefore, full.trace.cueBefore);
      expect(lean.trace.cueAfter, full.trace.cueAfter);
      expect(lean.aimOffsetDeg, full.aimOffsetDeg);
    });

    test('cắt rất mỏng gần 85°: không lỗi, bi mục tiêu đi đúng đường lỗ', () {
      for (final cut in [80.0, 84.0, maxCutAngle]) {
        final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut);
        final a = aim(g, Stroke.stun, power: 30);
        expect(a.converged, isTrue, reason: '$cut°');
        expect(a.trace.contactCue, isNotNull, reason: '$cut°');
        // Lực nhẹ thì bi mục tiêu chưa tới lỗ, nhưng dừng trên đúng đường.
        final end = a.trace.objectPath.last;
        expect(
            a.trace.objectPocket == g.pocket ||
                distanceToSegment(
                        end, g.object, table.pocketPosition(g.pocket)) <
                    1,
            isTrue,
            reason: '$cut° dừng ở $end');
      }
    });

    test('áp phê và swerve quá mạnh ở xa: không hội tụ vẫn trả cú tốt nhất',
        () {
      // Dò trên lưới: cơ Dốc, 2 đầu cơ, lực 30 % từ đầu bàn bên kia.
      final g = (evaluateShot(
              cue: const Vec2(20, 15),
              object: const Vec2(220, 20),
              pocket: Pocket.topRight) as Makeable)
          .geometry;
      final a = aim(g, Stroke.stun,
          power: 30,
          spin: const SideSpin(SpinSide.right, 2),
          elevation: CueElevation.steep);
      expect(a.converged, isFalse);
      expect(identical(a.trace.cueEnd,
              a.trace.cueAfter.isEmpty ? a.trace.cueBefore.last : a.trace.cueAfter.last),
          isTrue);
    });
  });

  group('Đánh đứng bi', () {
    /// Bắn thẳng vào lỗ góc dưới trái, bi cái cách bi ảo [d] cm.
    ShotGeometry straight(double d) =>
        geometryFor(const Vec2(40, 110), Pocket.bottomLeft, 0, distance: d);

    test('điểm đặt cơ dò được làm hết xoáy dọc lúc chạm', () {
      for (final d in [3.0, 10.0, 30.0, 60.0, 100.0]) {
        final g = straight(d);
        final s = solveAim(
            cue: g.cue,
            object: g.object,
            pocket: g.pocket,
            stroke: Stroke.stun,
            spin: const SideSpin.none(),
            power: 30,
            elevation: CueElevation.normal,
            table: table,
            compensate: true);
        expect(topspinAtContact(s.aimed)!.abs(), lessThan(stopSpin),
            reason: 'cách $d cm');
      }
    });

    test('càng xa càng phải đặt cơ thấp; sát bi mục tiêu thì gần như tâm', () {
      final offsets = [
        for (final d in [3.0, 10.0, 30.0, 60.0, 100.0])
          aim(straight(d), Stroke.stun, power: 30).verticalOffset,
      ];
      for (var i = 1; i < offsets.length; i++) {
        expect(offsets[i], lessThan(offsets[i - 1]));
      }
      expect(offsets.first.abs(), lessThan(0.05));
      expect(offsets.last, greaterThanOrEqualTo(-stunMaxOffset * radius));
    });

    test('quá xa ở lực nhẹ: đặt cơ thấp nhất cho phép', () {
      expect(aim(straight(150), Stroke.stun, power: 30).verticalOffset,
          -stunMaxOffset * radius);
    });

    test('chạm sàn đặt cơ mà vẫn còn xoáy trên: báo là không đứng được bi',
        () {
      final far = aim(straight(150), Stroke.stun, power: 30);
      expect(far.verticalOffset, -stunMaxOffset * radius);
      final s = solveAim(
          cue: straight(150).cue,
          object: straight(150).object,
          pocket: straight(150).pocket,
          stroke: Stroke.stun,
          spin: const SideSpin.none(),
          power: 30,
          elevation: CueElevation.normal,
          table: table,
          compensate: true);
      expect(topspinAtContact(s.aimed)!, greaterThan(stopSpin),
          reason: 'bố cục phải là cú không đứng bi được');
      expect(s.stunReached, isFalse);
      expect(far.stunReached, isFalse);

      expect(aim(straight(60), Stroke.stun, power: 30).stunReached, isTrue);
      // Không đánh đứng bi thì không có gì để đạt.
      expect(aim(straight(150), Stroke.draw, power: 30).stunReached, isTrue);
    });

    test('bắn thẳng lực nhẹ và vừa: bi cái dừng trong 1 R quanh điểm chạm', () {
      // Từ 60 % trở lên bi cái còn trôi tới (1 − ballRestitution)/2 vận
      // tốc — xem "Deviations from spec" của plan.
      for (final power in [30.0, 45.0]) {
        final t = aim(straight(60), Stroke.stun, power: power).trace;
        expect(t.cueEnd.distanceTo(t.contactCue!), lessThan(radius),
            reason: '$power%');
      }
    });

    test('cắt góc: bi cái rời đi theo tiếp tuyến, chỉ lệch do phục hồi', () {
      for (final cut in [30.0, 45.0, 60.0]) {
        for (final power in [30.0, 45.0, 90.0]) {
          final g =
              geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut,
                  distance: 60);
          final s = solveAim(
              cue: g.cue,
              object: g.object,
              pocket: g.pocket,
              stroke: Stroke.stun,
              spin: const SideSpin.none(),
              power: power,
              elevation: CueElevation.normal,
              table: table,
              compensate: true);
          final probe = probeContact(s.aimed)!;
          // Hai bi cùng khối lượng: bi cái rời đi với v − v_mục tiêu.
          final depart = probe.cueAtContact.vel - probe.objectAfter.vel;
          final n = (g.object - probe.cueAtContact.pos).normalized;
          final tangent = depart - n * depart.dot(n);
          final off = tangent.signedAngleTo(depart).abs() * 180 / math.pi;
          final phi = n.signedAngleTo(probe.cueAtContact.vel).abs();
          final restitution = math.atan(
                  (1 - ballRestitution) / 2 / math.tan(phi)) *
              180 /
              math.pi;
          expect(off, lessThan(restitution + 0.5), reason: '$cut° $power%');
          if (cut >= 45) expect(off, lessThan(2), reason: '$cut° $power%');
        }
      }
    });

    test('trô và cu lê dùng đúng strokeOffset', () {
      final g = straight(40);
      expect(aim(g, Stroke.draw).verticalOffset, -strokeOffset * radius);
      expect(aim(g, Stroke.follow).verticalOffset, strokeOffset * radius);
    });
  });

  test('cueEnd của cú đã dò là đúng đối tượng cuối đường bi cái', () {
    final a = aim(geometryFor(const Vec2(180, 40), Pocket.topRight, 25),
        Stroke.follow, spin: right1);
    expect(identical(a.trace.cueEnd, a.trace.cueAfter.last), isTrue);
  });
}
