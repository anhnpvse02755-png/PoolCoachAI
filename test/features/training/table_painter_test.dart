import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
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

  /// Dò cú đánh cho bố cục rồi vẽ nó với đường đỏ và vòng nguy cơ bật.
  AimedShot paintShot(ShotGeometry g, Stroke stroke, double power) {
    final aimed = aimShot(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        stroke: stroke,
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
    return aimed;
  }

  // Mỗi cảnh phải thật sự đi qua nhánh mà tên test hứa: lõi đổi mà cảnh
  // không còn chạm băng hay chết cái nữa thì test phải đỏ, không âm thầm
  // xanh với nhánh không ai vẽ tới.
  test('vẽ đủ lớp 1–8: đường đỏ, chạm băng, Bi ảo dời, điểm dừng', () {
    // Đứng bi cắt 40° có áp phê, lực nhẹ: bi cái dội băng rồi dừng trên
    // bàn, ném đủ lớn để Bi ảo lệch khỏi chỗ hình học.
    final g = geometryFor(const Vec2(170, 70), Pocket.topRight, 40);
    final aimed = paintShot(g, Stroke.stun, 30);
    expect(aimed.uncompensated, isNotNull, reason: 'lớp 8: đường đỏ');
    expect(aimed.trace.cueRailCount, greaterThan(0), reason: 'lớp 6');
    expect(aimed.trace.contactCue!.distanceTo(g.ghost), greaterThan(0.1),
        reason: 'lớp 3: chấm Bi ảo hình học');
    expect(aimed.trace.cuePocket, isNull, reason: 'lớp 7: vòng điểm dừng');
  });

  test('chết cái: lỗ tô đỏ, không vòng điểm dừng', () {
    // Cu lê thẳng sát lỗ, lực mạnh: bi cái theo bi mục tiêu rơi lỗ.
    final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);
    final aimed = paintShot(g, Stroke.follow, 90);
    expect(aimed.trace.cuePocket, isNotNull);
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
