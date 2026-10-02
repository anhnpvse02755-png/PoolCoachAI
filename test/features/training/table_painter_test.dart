import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/table_layouts.dart';

void main() {
  const size = Size(540, 286);

  void paint(SimulatorScene scene) {
    final recorder = PictureRecorder();
    TablePainter(scene).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  test('vẽ đủ mọi lớp: đường đỏ, chạm băng, chết cái, không lỗi', () {
    for (final (object, degrees, power) in [
      // Cu lê cắt có áp phê, bật đường đỏ: đủ lớp 1–8.
      (const Vec2(170, 70), 25.0, 45.0),
      // Cu lê thẳng sát lỗ: chết cái, lỗ tô đỏ, không vòng điểm dừng.
      (const Vec2(240, 14), 0.0, 90.0),
    ]) {
      final g = geometryFor(object, Pocket.topRight, degrees);
      final aimed = aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.follow,
          spin: const SideSpin(SpinSide.right, 1),
          power: power);
      paint(SimulatorScene(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        geometry: g,
        aimed: aimed,
        showUncompensated: true,
        riskPocket: Pocket.bottomLeft,
      ));
    }
  });

  test('không đánh được thì chỉ vẽ bàn và hai bi', () {
    paint(const SimulatorScene(cue: Vec2(80, 90), object: Vec2(170, 50)));
  });

  test('cú cắt có ném dời Bi ảo khỏi chỗ hình học', () {
    final g = geometryFor(const Vec2(170, 70), Pocket.topRight, 30);
    final aimed = aimShot(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        stroke: Stroke.stun,
        spin: const SideSpin(SpinSide.right, 1),
        power: 45);
    // Lớp 3: lệch quá 0.1 cm thì phải chấm thêm Bi ảo hình học.
    expect(aimed.trace.contactCue!.distanceTo(g.ghost), greaterThan(0.1));
    expect(TableSpec.nineFoot.contains(aimed.trace.contactCue!), isTrue);
  });
}
