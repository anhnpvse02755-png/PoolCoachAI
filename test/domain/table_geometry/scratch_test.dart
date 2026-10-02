import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final corner = table.pocketPosition(Pocket.topRight);
  // Bi mục tiêu sát lỗ góc trên phải, cú thẳng: cu lê đi theo bi vào lỗ.
  final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);

  AimedShot shot(ShotGeometry g, Stroke stroke, double power,
          {SideSpin spin = const SideSpin.none()}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: power);

  Pocket? dropsAt(Stroke stroke, double power) =>
      cuePocketAt(g, stroke: stroke, power: power, spin: const SideSpin.none());

  test('cu lê theo bi vào lỗ là chết cái, rơi trước khi kịp chạm băng', () {
    final t = shot(g, Stroke.follow, powerPresets.last).trace;
    expect(t.cuePocket, Pocket.topRight);
    expect(t.cueRailCount, 0);
    expect(t.cueEnd, corner);
  });

  test('đánh đứng bi cú thẳng thì bi cái gần như dừng tại chỗ, không chết cái',
      () {
    for (final power in powerPresets) {
      expect(shot(g, Stroke.stun, power).trace.cuePocket, isNull,
          reason: '$power%');
    }
  });

  test('cuePocketAt cho đúng lỗ mà aimShot vẽ', () {
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 23) {
      for (final stroke in Stroke.values) {
        for (final spin in [
          const SideSpin.none(),
          const SideSpin(SpinSide.left, 1),
        ]) {
          expect(
            cuePocketAt(shots[i], stroke: stroke, power: 75, spin: spin),
            shot(shots[i], stroke, 75, spin: spin).trace.cuePocket,
            reason: '${shots[i].cue}→${shots[i].object} $stroke $spin',
          );
        }
      }
    }
  });

  test('biên lực chết cái: dò thưa rồi dò mịn, trả mức đầu tiên tìm thấy', () {
    const from = 30.0;
    final risk = scratchMargin(g, stroke: Stroke.follow, power: from)!;
    expect(risk.pocket, Pocket.topRight);
    expect(dropsAt(Stroke.follow, risk.power), risk.pocket);
    // Mọi mức dò thưa đứng trước biên đều không chết cái…
    for (var p = from; p < risk.power; p += overhitScanStep) {
      expect(dropsAt(Stroke.follow, p), isNull, reason: '$p%');
    }
    // …và mức ngay dưới biên cũng không (đã dò mịn từng 1 %).
    if (risk.power - 1 >= from) {
      expect(dropsAt(Stroke.follow, risk.power - 1), isNull);
    }
  });

  test('không chết cái tới 100% thì không có biên', () {
    expect(scratchMargin(g, stroke: Stroke.stun, power: powerPresets.first),
        isNull);
  });

  test('ngay mức chọn đã chết cái thì biên là chính mức đó', () {
    final risk =
        scratchMargin(g, stroke: Stroke.follow, power: powerPresets.last)!;
    expect(risk.power, powerPresets.last);
  });

  test('dò thưa luôn chạm đúng 100 %, kể cả khi lực đầu không chia hết bước',
      () {
    final seen = <double>[];
    marginWith((s, p) {
      seen.add(p);
      return null;
    }, const SideSpin.none(), 87);
    expect(seen.first, 87);
    expect(seen.last, 100);
    expect(seen.every((p) => p <= 100), isTrue);
  });

  test('trên lưới: chết cái thì bi cái kết thúc ở đúng tâm lỗ đó', () {
    final shots = gridShots().toList();
    var scratches = 0;
    for (var i = 0; i < shots.length; i += 5) {
      for (final stroke in Stroke.values) {
        final t = shot(shots[i], stroke, powerPresets.last).trace;
        final pocket = t.cuePocket;
        if (pocket == null) continue;
        scratches++;
        expect(t.cueEnd, table.pocketPosition(pocket),
            reason: '${shots[i].cue}→${shots[i].object} $stroke');
      }
    }
    expect(scratches, greaterThan(0),
        reason: 'lưới phải có cú chết cái thì test mới có nghĩa');
  });
}
