import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);
  final g = geometryFor(const Vec2(170, 50), Pocket.topRight, 20, distance: 90);

  AimedShot aimed(Stroke stroke, {SideSpin spin = none}) => aimShot(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      stroke: stroke,
      spin: spin,
      power: 45);

  List<String> lines({
    required AimedShot? a,
    List<Advice>? advice = const [],
    Stroke stroke = Stroke.stun,
    SideSpin spin = none,
    ShotResult? shot,
  }) =>
      simulatorInfoLines(
        shot: shot ?? Makeable(g),
        aimed: a,
        advice: advice,
        stroke: stroke,
        power: 45,
        spin: spin,
        elevation: CueElevation.normal,
      );

  /// Một trace dựng tay, để bật từng trường hợp hiếm.
  AimedShot fake({
    int rails = 0,
    Pocket? cuePocket,
    Pocket? objectPocket = Pocket.topRight,
    double aimOffsetDeg = 0,
    double verticalOffset = 0,
  }) =>
      AimedShot(
        trace: ShotTrace(
          cueBefore: [g.cue, g.ghost],
          cueAfter: [g.ghost, const Vec2(100, 100)],
          objectPath: [g.object],
          contactCue: g.ghost,
          rails: [
            for (var i = 0; i < rails; i++)
              RailHit(
                  ball: ShotBall.cue,
                  pos: Vec2(table.minX, 50.0 + i),
                  rail: Rail.left,
                  afterContact: true),
          ],
          cuePocket: cuePocket,
          objectPocket: objectPocket,
          cueEnd: const Vec2(100, 100),
        ),
        uncompensated: null,
        aimOffsetDeg: aimOffsetDeg,
        verticalOffset: verticalOffset,
        converged: true,
      );

  test('các dòng cố định, theo thứ tự', () {
    final out = lines(a: fake());
    expect(out.take(7), [
      Vi.simPocketLine(g.pocket),
      Vi.simAngleLine(g.angle),
      Vi.simBandLine(bandFor(g.angle)),
      Vi.simStrokeLine(Stroke.stun),
      Vi.simPowerLine(45),
      Vi.simSpinLine(none),
      Vi.simElevationLine(CueElevation.normal),
    ]);
  });

  test('ngắm dày/mỏng đúng chiều, chỉ khi từ aimOffsetShownDeg trở lên', () {
    expect(lines(a: fake(aimOffsetDeg: 1.2)), contains(Vi.simAimOffset(1.2)));
    expect(Vi.simAimOffset(1.2), startsWith('Ngắm dày hơn'));
    expect(lines(a: fake(aimOffsetDeg: -0.7)), contains(Vi.simAimOffset(-0.7)));
    expect(Vi.simAimOffset(-0.7), startsWith('Ngắm mỏng hơn'));
    final small = lines(a: fake(aimOffsetDeg: aimOffsetShownDeg * 0.9));
    expect(small.where((l) => l.startsWith('Ngắm')), isEmpty);
  });

  test('cú thật có áp phê: dòng bù ném lấy đúng aimOffsetDeg của lõi', () {
    final a = aimed(Stroke.stun, spin: right1);
    expect(a.aimOffsetDeg.abs(), greaterThanOrEqualTo(aimOffsetShownDeg));
    expect(lines(a: a, spin: right1),
        contains(Vi.simAimOffset(a.aimOffsetDeg)));
  });

  test('góc cắt hiện 0° có áp phê: không nói dày/mỏng', () {
    final straight = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 0);
    expect(straight.angle.round(), 0);
    final a = aimShot(
        cue: straight.cue,
        object: straight.object,
        pocket: straight.pocket,
        stroke: Stroke.stun,
        spin: right1,
        power: 45);
    expect(a.aimOffsetDeg.abs(), greaterThanOrEqualTo(aimOffsetShownDeg),
        reason: 'cú thẳng có áp phê vẫn phải bù, đủ ngưỡng để dòng này hiện');
    final out = lines(a: a, spin: right1, shot: Makeable(straight));
    expect(out, contains(Vi.simAngleLine(straight.angle)));
    expect(out.where((l) => l.startsWith('Ngắm')), isEmpty);
  });

  test('dòng Đánh đứng bi chỉ hiện khi đặt cơ đủ xa tâm, và chỉ khi đứng bi',
      () {
    const deep = -stunOffsetShownTips * tipWidth * 2;
    expect(lines(a: fake(verticalOffset: deep)),
        contains(Vi.simStunOffset(deep)));
    expect(
        lines(a: fake(verticalOffset: -stunOffsetShownTips * tipWidth * 0.9))
            .where((l) => l.startsWith('Đánh đứng bi:')),
        isEmpty);
    expect(
        lines(a: fake(verticalOffset: deep), stroke: Stroke.draw)
            .where((l) => l.startsWith('Đánh đứng bi:')),
        isEmpty);
  });

  test('có áp phê thì nói góc bi cái bị lệch do áp phê', () {
    final deg = squirtAngle(tipWidth, table.radius) * 180 / math.pi;
    expect(lines(a: fake(), spin: right1), contains(Vi.simSquirt(deg)));
    expect(lines(a: fake()).where((l) => l.startsWith('Bi cái bị lệch')),
        isEmpty);
  });

  test('số lần chạm băng, chết cái, bi mục tiêu không vào lỗ', () {
    final out = lines(
        a: fake(
            rails: 3,
            cuePocket: Pocket.bottomLeft,
            objectPocket: Pocket.topMiddle));
    expect(out, contains(Vi.simRailCount(3)));
    expect(out, contains(Vi.simScratch(Pocket.bottomLeft)));
    expect(out, contains(Vi.simObjectMissed));
    final clean = lines(a: fake());
    expect(clean, isNot(contains(Vi.simObjectMissed)));
    expect(clean.where((l) => l.startsWith('Bi cái chạm băng')), isEmpty);
  });

  test('gợi ý chống chết cái: Đang tính… khi chưa có, lời khuyên khi có', () {
    expect(lines(a: fake(), advice: null), contains(Vi.simComputing));
    const advice = [NoSpinAvoids(pocket: Pocket.topRight)];
    final out = lines(a: fake(), advice: advice);
    expect(out, isNot(contains(Vi.simComputing)));
    expect(out, contains(Vi.simAdvice(advice.single)));
  });

  test('không đánh được thì chỉ nói lý do', () {
    expect(
        lines(a: null, shot: const Unmakeable(UnmakeableReason.tooThin)),
        [Vi.simUnmakeable(UnmakeableReason.tooThin)]);
    expect(
        simulatorInfoLines(
            shot: null,
            aimed: null,
            advice: null,
            stroke: Stroke.stun,
            power: 45,
            spin: none,
            elevation: CueElevation.normal),
        [Vi.simNoPocket]);
  });
}
