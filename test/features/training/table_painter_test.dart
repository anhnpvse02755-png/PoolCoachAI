import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/table_layouts.dart';

/// Canvas ghi lại các nét cần soi; mọi lệnh vẽ khác bỏ qua.
class _SpyCanvas implements Canvas {
  final lines = <(Offset, Offset)>[];
  final circles = <(Offset, Color)>[];
  final arcs = <Rect>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((c, paint.color));

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle,
          bool useCenter, Paint paint) =>
      arcs.add(rect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

  test('không mô phỏng được: vẫn vẽ đường ngắm và Bi ảo hình học', () {
    final g = geometryFor(const Vec2(170, 70), Pocket.topRight, 30);
    final spy = _SpyCanvas();
    TablePainter(SimulatorScene(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      geometry: g,
    )).paint(spy, size);
    const layout = TableLayout(size: size);
    expect(spy.lines,
        contains((layout.toCanvas(g.cue), layout.toCanvas(g.ghost))));
    expect(spy.arcs.map((r) => r.center), contains(layout.toCanvas(g.ghost)));
  });

  test('chấm chạm băng chỉ cho bi cái sau va chạm, khớp dòng số lần chạm',
      () {
    final g = geometryFor(const Vec2(170, 70), Pocket.topRight, 30);
    const table = TableSpec.nineFoot;
    RailHit hit(ShotBall ball, double y, {required bool after}) => RailHit(
        ball: ball,
        pos: Vec2(table.minX, y),
        rail: Rail.left,
        afterContact: after);
    final aimed = AimedShot(
      trace: ShotTrace(
        cueBefore: [g.cue, g.ghost],
        cueAfter: [g.ghost, const Vec2(100, 100)],
        objectPath: [g.object, const Vec2(200, 40)],
        contactCue: g.ghost,
        rails: [
          hit(ShotBall.cue, 20, after: false),
          hit(ShotBall.object, 30, after: true),
          hit(ShotBall.cue, 40, after: true),
          hit(ShotBall.cue, 50, after: true),
        ],
        cuePocket: null,
        objectPocket: null,
        cueEnd: const Vec2(100, 100),
      ),
      uncompensated: null,
      aimOffsetDeg: 0,
      verticalOffset: 0,
      stunReached: true,
      converged: false,
    );
    final spy = _SpyCanvas();
    TablePainter(SimulatorScene(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      geometry: g,
      aimed: aimed,
    )).paint(spy, size);
    const layout = TableLayout(size: size);
    final dots = [
      for (final (c, color) in spy.circles)
        if (color.toARGB32() == AppColors.railHit.toARGB32()) c,
    ];
    expect(dots.length, aimed.trace.cueRailCount);
    expect(dots, [
      layout.toCanvas(Vec2(table.minX, 40)),
      layout.toCanvas(Vec2(table.minX, 50)),
    ]);
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
