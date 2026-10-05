import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
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
    bool stunReached = true,
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
        stunReached: stunReached,
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

  test('không dòng nào, cũng không nhãn tóm tắt nào, khuyên ngắm lệch theo độ',
      () {
    final a = aimed(Stroke.stun, spin: right1);
    expect(a.aimOffsetDeg.abs(), greaterThan(0.5),
        reason: 'lõi vẫn tính bù ném; chỉ là không nói ra thành lời');
    final out = lines(a: a, spin: right1);
    final summary = Vi.simSummary(Makeable(g), a,
        elevation: CueElevation.normal, showingUncompensated: true);
    for (final text in [...out, summary]) {
      expect(text, isNot(contains('Ngắm dày')));
      expect(text, isNot(contains('Ngắm mỏng')));
      expect(text, isNot(contains('Không cần bù ném')));
    }
    expect(summary, contains(Vi.simShowingUncompensated));
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

  test('đặt cơ thấp nhất vẫn không đứng được bi: không nói điểm đặt cơ', () {
    const floor = -stunOffsetShownTips * tipWidth * 4;
    expect(
        lines(a: fake(verticalOffset: floor, stunReached: false))
            .where((l) => l.startsWith('Đánh đứng bi:')),
        isEmpty);
  });

  test('có áp phê thì nói góc bi cái bị lệch do áp phê', () {
    final deg = squirtAngle(tipWidth, table.radius) * 180 / math.pi;
    expect(lines(a: fake(), spin: right1), contains(Vi.simSquirt(deg)));
    expect(lines(a: fake()).where((l) => l.startsWith('Bi cái bị lệch')),
        isEmpty);
  });

  group('độ lệch điểm ngắm đổi ra đầu cơ và con bi', () {
    test('đúng một đầu cơ thì phần con bi là đường kính chia đầu cơ', () {
      final u = aimShiftUnits(tipWidth, table.ballDiameter)!;
      expect(u.tips, 1);
      expect(u.ballDenominator, 4.5);
      expect(u.ballCount, isNull);
    });

    test('lệch bằng không, hay dưới nửa nấc 0.25 đầu cơ, thì không có số', () {
      expect(aimShiftUnits(0, table.ballDiameter), isNull);
      expect(aimShiftUnits(0.12 * tipWidth, table.ballDiameter), isNull);
    });

    test('làm tròn đầu cơ tới 0.25 và mẫu số con bi tới 0.5', () {
      final u = aimShiftUnits(1.4 * tipWidth, table.ballDiameter)!;
      expect(u.tips, 1.5);
      // Mẫu số tính từ 1.5 đầu cơ đã làm tròn, không từ 1.4 thô.
      final k = table.ballDiameter / (1.5 * tipWidth);
      expect(u.ballDenominator, (k * 2).round() / 2);
    });

    test('mỗi nấc đầu cơ: mẫu số khớp số đầu cơ hiện ra', () {
      for (final tips in [0.25, 0.5, 1.0, 2.0, 3.0]) {
        // Cộng lệch nhỏ để chắc chắn số thô chưa phải nấc tròn.
        final u = aimShiftUnits((tips + 0.05) * tipWidth, table.ballDiameter)!;
        expect(u.tips, tips);
        final k = table.ballDiameter / (tips * tipWidth);
        if (k <= 1) {
          expect(u.ballDenominator, isNull);
        } else {
          expect(u.ballDenominator, (k * 2).round() / 2);
        }
      }
    });

    test('lệch từ một con bi trở lên thì nói "N con bi", không phải 1/k', () {
      final u = aimShiftUnits(table.ballDiameter, table.ballDiameter)!;
      expect(u.ballDenominator, isNull);
      expect(u.ballCount, 1);
      final u2 = aimShiftUnits(1.5 * table.ballDiameter, table.ballDiameter)!;
      expect(u2.ballDenominator, isNull);
      expect(u2.ballCount, 1.5);
      expect(Vi.simSquirt(1.5, u2.tips, null, null, u2.ballCount),
          contains('≈ 1.5 con bi)'));
    });
  });

  test('áp phê thật: dòng kèm độ lệch điểm ngắm tính từ hướng cơ đã bù', () {
    final a = aimed(Stroke.stun, spin: right1);
    // Bi ảo thật gần như trùng bi ảo hình học (cú đã bù để vào lỗ), nên
    // lượng phải dịch là độ xoay hướng cơ nhân quãng tới bi ảo.
    final shift = g.cue.distanceTo(g.ghost) *
        math.tan(a.aimOffsetDeg.abs() * math.pi / 180);
    final u = aimShiftUnits(shift, table.ballDiameter)!;
    final deg = squirtAngle(tipWidth, table.radius) * 180 / math.pi;
    final line = lines(a: a, spin: right1)
        .singleWhere((l) => l.startsWith('Bi cái bị lệch'));
    final bhe = sawsBhePercent(
        distance: g.cue.distanceTo(g.ghost), power: 45, stroke: Stroke.stun);
    expect(line, Vi.simSquirt(
        deg, u.tips, u.ballDenominator, bhe, u.ballCount));
    expect(line, contains('SAWS ($bhe% BHE / ${100 - bhe}% FHE)'));
    expect(line, endsWith('để bù trừ áp phê.'));
    expect(line, contains('đầu cơ'));
    expect(line, contains('con bi'));
  });

  test('lệch dưới nấc nhỏ nhất hoặc không có vết: dòng không có ngoặc', () {
    final deg = squirtAngle(tipWidth, table.radius) * 180 / math.pi;
    expect(lines(a: fake(), spin: right1), contains(Vi.simSquirt(deg)));
    expect(lines(a: null, spin: right1), contains(Vi.simSquirt(deg)));
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
