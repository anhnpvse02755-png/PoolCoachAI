import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  final normal = CueElevation.normal.radians;

  double aimAt(Vec2 from, Vec2 to) => math.atan2(to.y - from.y, to.x - from.x);

  ShotInput shot(
    Vec2 cue,
    Vec2 object, {
    Vec2? toward,
    double power = 45,
    double b = 0,
    SideSpin spin = const SideSpin.none(),
  }) =>
      ShotInput(
        cue: cue,
        object: object,
        aimAngle: aimAt(cue, toward ?? object),
        power: power,
        verticalOffset: b,
        spin: spin,
        elevation: normal,
      );

  bool onBounds(Vec2 p) =>
      p.x == table.minX ||
      p.x == table.maxX ||
      p.y == table.minY ||
      p.y == table.maxY;

  bool atPocket(Vec2 p) =>
      Pocket.values.any((k) => table.pocketPosition(k) == p);

  test('tất định: cùng đầu vào thì trace bằng nhau tuyệt đối', () {
    final input = shot(const Vec2(60, 90), const Vec2(150, 50),
        power: 75, b: strokeOffset * radius,
        spin: const SideSpin(SpinSide.right, 1));
    final a = simulateShot(input);
    final b = simulateShot(input);
    expect(b.cueBefore, a.cueBefore);
    expect(b.cueAfter, a.cueAfter);
    expect(b.objectPath, a.objectPath);
    expect(b.rails, a.rails);
    expect(b.contactCue, a.contactCue);
    expect(b.cueEnd, a.cueEnd);
    expect(b.cuePocket, a.cuePocket);
    expect(b.objectPocket, a.objectPocket);
  });

  group('cueEnd là đúng đối tượng cuối của đường bi cái', () {
    test('có va chạm', () {
      final t = simulateShot(shot(const Vec2(60, 90), const Vec2(150, 50)));
      expect(t.contactCue, isNotNull);
      expect(identical(t.cueEnd, t.cueAfter.last), isTrue);
      expect(identical(t.cueAfter.first, t.contactCue), isTrue);
      expect(identical(t.cueBefore.last, t.contactCue), isTrue);
    });

    test('trượt bi mục tiêu', () {
      final t = simulateShot(shot(const Vec2(60, 90), const Vec2(150, 50),
          toward: const Vec2(150, 110), power: 30));
      expect(t.contactCue, isNull);
      expect(t.cueAfter, isEmpty);
      expect(identical(t.cueEnd, t.cueBefore.last), isTrue);
      expect(t.objectPath, [const Vec2(150, 50)]);
    });
  });

  group('trô và cu lê sau va chạm', () {
    test('cu lê cắt nửa bi, bi cái đang lăn: hướng cuối lệch 30° ± 3° (quy tắc 30°)',
        () {
      for (final power in [30.0, 45.0]) {
        // Bi cái đi theo +x, cách 60 cm — đủ để lăn đều trước khi chạm.
        // Bi mục tiêu lệch khỏi đường cơ đúng một bán kính: cắt nửa bi.
        const cue = Vec2(30, 100);
        final object = Vec2(90, 100 + radius);
        Vec2? rolling;
        var hit = false;
        final t = simulateShot(
          ShotInput(
              cue: cue,
              object: object,
              aimAngle: 0,
              power: power,
              verticalOffset: strokeOffset * radius,
              elevation: normal),
          onStep: (c, o) {
            if (o.vel.length > 0) hit = true;
            if (hit &&
                rolling == null &&
                c.vel.length > 0 &&
                c.slip(radius).length <= rollingSlip) {
              rolling = c.vel;
            }
          },
        );
        final deg = const Vec2(1, 0).signedAngleTo(rolling!).abs() * 180 / math.pi;
        expect(deg, closeTo(30, 3), reason: '$power%');
        // Có đoạn cong rồi mới thẳng: còn hơn hai điểm trước băng đầu.
        expect(t.cueAfter.length, greaterThan(3));
      }
    });

    test('trô bắn thẳng: bi cái lùi lại trên đường cơ', () {
      const cue = Vec2(60, 63.5);
      const object = Vec2(160, 63.5);
      final t = simulateShot(ShotInput(
          cue: cue,
          object: object,
          aimAngle: 0,
          power: 30,
          verticalOffset: -strokeOffset * radius,
          elevation: normal));
      expect(t.cueEnd.x, lessThan(t.contactCue!.x - 10));
      for (final p in t.cueAfter) {
        expect((p.y - cue.y).abs(), lessThan(0.5), reason: '$p');
      }
    });

    test('swerve: cùng áp phê, bi cái tới bi mục tiêu lệch ngang nhiều hơn ở cơ Dốc',
        () {
      double lateral(CueElevation e) {
        const cue = Vec2(40, 63.5);
        final input = ShotInput(
            cue: cue,
            object: const Vec2(200, 63.5),
            aimAngle: 0,
            power: 45,
            spin: const SideSpin(SpinSide.right, 1),
            elevation: e.radians);
        final t = simulateShot(input);
        final at = t.contactCue ?? t.cueBefore.last;
        // Đo so với đường lệch do áp phê, để chỉ còn phần cong.
        final squirtLine = const Vec2(1, 0)
            .rotated(-squirtAngle(sideOffsetOf(input.spin), radius));
        return (at - cue).dot(squirtLine.rightNormal);
      }

      expect(lateral(CueElevation.steep), greaterThan(lateral(CueElevation.normal)));
      expect(lateral(CueElevation.normal), greaterThan(0));
    });
  });

  test('đường thẳng rút gọn còn hai điểm, đường cong giữ nhiều điểm', () {
    // Cu lê không áp phê: xoáy dọc không làm cong, bi cái tới bi mục tiêu
    // theo đường thẳng.
    final t = simulateShot(shot(const Vec2(40, 63.5), const Vec2(120, 40),
        b: strokeOffset * radius));
    expect(t.cueBefore, hasLength(2));
    // Cu lê cắt: bi cái sau va chạm cong rồi mới thẳng.
    expect(t.cueAfter.length, greaterThan(3));
  });

  test('bi mục tiêu vào lỗ thì đường của nó kết thúc ở tâm lỗ', () {
    final corner = table.pocketPosition(Pocket.topRight);
    const object = Vec2(200, 30);
    final dir = (corner - object).normalized;
    final ghost = object - dir * table.ballDiameter;
    final t = simulateShot(
        shot(ghost - dir * 40, object, toward: object, power: 45));
    expect(t.objectPocket, Pocket.topRight);
    expect(t.objectPath.last, corner);
  });

  test('bi cái rơi lỗ: chết cái, đường kết thúc ở tâm lỗ', () {
    final corner = table.pocketPosition(Pocket.topLeft);
    final t = simulateShot(shot(const Vec2(60, 40), const Vec2(200, 100),
        toward: corner, power: 45));
    expect(t.cuePocket, Pocket.topLeft);
    expect(t.contactCue, isNull);
    expect(t.cueEnd, corner);
    expect(identical(t.cueEnd, t.cueBefore.last), isTrue);
  });

  test('bi nằm sẵn trong vùng lỗ mà đánh ra xa lỗ thì không rơi', () {
    // Tâm bi cách điểm lỗ dưới cornerCapture nhưng vẫn trên bàn.
    final inZone = Vec2(table.minX + 0.5, table.minY + 0.5);
    expect(inZone.distanceTo(table.pocketPosition(Pocket.topLeft)),
        lessThan(cornerCapture));
    final t = simulateShot(shot(inZone, const Vec2(200, 100),
        toward: const Vec2(120, 60), power: 30));
    expect(t.cuePocket, isNull);
  });

  test('hai bi đặt sát nhau: chạm ngay lúc đánh', () {
    const object = Vec2(150, 60);
    final cue = object - Vec2(table.ballDiameter, 0);
    final t = simulateShot(shot(cue, object));
    expect(t.contactCue, isNotNull);
    expect(t.contactCue!.distanceTo(cue), lessThan(1e-9));
    expect(t.objectPath.length, greaterThan(1));
  });

  test('bi sát băng đánh vào chính băng đó: bật ra, không lọt khỏi bàn', () {
    final cue = Vec2(table.minX, 63.5);
    final t = simulateShot(shot(cue, const Vec2(200, 20),
        toward: const Vec2(0, 63.5), power: 60));
    expect(t.rails.first.pos, cue);
    for (final p in t.cueBefore) {
      expect(table.contains(p), isTrue, reason: '$p');
    }
  });

  test('lực 100 % đánh thẳng vào băng: không xuyên băng với bước 1 ms', () {
    for (final from in [const Vec2(240, 63.5), Vec2(table.maxX, 63.5)]) {
      final t = simulateShot(ShotInput(
          cue: from,
          object: const Vec2(30, 20),
          aimAngle: 0,
          power: 100,
          elevation: normal));
      expect(t.rails, isNotEmpty);
      for (final p in [...t.cueBefore, ...t.cueAfter]) {
        expect(table.contains(p) || atPocket(p), isTrue, reason: '$from $p');
      }
    }
  });

  /// Cu lê cắt mỏng lực 90 %: bi cái chạy 5 băng rồi dừng trong bàn (dò
  /// bằng mô phỏng, không đoán).
  final multiRail = ShotInput(
      cue: const Vec2(80, 30),
      object: const Vec2(127, 63.5),
      aimAngle: aimAt(const Vec2(80, 30), const Vec2(127, 63.5)) + 0.04,
      power: 90,
      verticalOffset: strokeOffset * radius,
      elevation: normal);

  test('bi lăn sát qua bi đang đứng không bị kẹt ở bước dài 0', () {
    // Trên prototype: cu lê 100 %, trái 2 đầu cơ — cuối cú, bi cái lăn
    // chậm tiếp tuyến qua bi mục tiêu đang đứng, đúng khoảng cách 2R. Xét
    // va chạm theo quãng đi trong bước thì nó "lao vào" mãi ở f = 0 và
    // đứng hình tới maxSimTime.
    final g = bestPocket(cue: const Vec2(146, 79), object: const Vec2(220, 78))!;
    final t = simulateShot(ShotInput(
        cue: g.cue,
        object: g.object,
        aimAngle: aimAt(g.cue, g.ghost),
        power: 100,
        verticalOffset: strokeOffset * radius,
        spin: const SideSpin(SpinSide.left, 2),
        elevation: normal));
    expect(table.contains(t.cueEnd) || atPocket(t.cueEnd), isTrue);
  });

  test('điểm chạm băng nằm đúng trên biên, đường đi qua chúng theo thứ tự',
      () {
    final t = simulateShot(multiRail);
    expect(t.rails, isNotEmpty);
    for (final ball in ShotBall.values) {
      final path = ball == ShotBall.cue
          ? [...t.cueBefore, ...t.cueAfter]
          : t.objectPath;
      var from = 0;
      for (final hit in t.rails.where((h) => h.ball == ball)) {
        expect(onBounds(hit.pos), isTrue, reason: '${hit.pos}');
        final at = path.indexOf(hit.pos, from);
        expect(at, greaterThanOrEqualTo(from),
            reason: '${hit.pos} phải nằm trên đường, sau điểm chạm trước');
        from = at;
      }
    }
  });

  test('bi cái chạm từ 3 băng trở lên rồi dừng trong bàn', () {
    final t = simulateShot(multiRail);
    expect(t.cueRailCount, greaterThanOrEqualTo(3));
    expect(t.cuePocket, isNull);
    expect(table.contains(t.cueEnd), isTrue);
  });

  test('động năng hai bi không tăng giữa hai bước (trừ lúc cơ chạm)', () {
    final inputs = [
      multiRail,
      for (final spin in [
        const SideSpin.none(),
        const SideSpin(SpinSide.left, 2),
      ])
        for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius])
          shot(const Vec2(60, 90), const Vec2(150, 50),
              power: 90, b: b, spin: spin),
    ];
    for (final input in inputs) {
      var last = double.infinity;
      simulateShot(
        input,
        onStep: (cue, object) {
          final e = cue.kineticEnergy(radius) + object.kineticEnergy(radius);
          // Dung sai làm tròn khi ép lăn đều đúng lúc hết trượt.
          expect(e, lessThanOrEqualTo(last * (1 + 1e-9)),
              reason: '${input.spin} b=${input.verticalOffset}');
          last = e;
        },
      );
    }
  });

  test('lưới vị trí × kiểu đánh × áp phê × lực: mọi cú dừng trước maxSimTime',
      () {
    final shots = gridShots().toList();
    var count = 0;
    for (var i = 0; i < shots.length; i += 3) {
      final g = shots[i];
      for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius]) {
        for (final spin in [
          const SideSpin.none(),
          const SideSpin(SpinSide.right, 1),
          const SideSpin(SpinSide.left, 2),
        ]) {
          for (final power in [30.0, 90.0, 100.0]) {
            final t = simulateShot(ShotInput(
                cue: g.cue,
                object: g.object,
                aimAngle: aimAt(g.cue, g.ghost),
                power: power,
                verticalOffset: b,
                spin: spin,
                elevation: normal));
            count++;
            expect(table.contains(t.cueEnd) || atPocket(t.cueEnd), isTrue,
                reason: '${g.cue}→${g.object} b=$b $spin $power');
          }
        }
      }
    }
    expect(count, greaterThan(500));
  });

  group('probeContact', () {
    test('bi mục tiêu nằm sẵn trên băng, bị đánh vào băng: vẫn dò được chạm',
        () {
      final object = Vec2(table.maxX, 63.5);
      final input = shot(const Vec2(180, 63.5), object);
      final probe = probeContact(input);
      final contact = simulateShot(input).contactCue;
      expect(contact, isNotNull);
      expect(probe, isNotNull);
      expect(probe!.cueAtContact.pos, contact);
    });

    test('bi cái chạm băng trước khi tới bi mục tiêu: không phải cú chạm', () {
      final input = shot(const Vec2(60, 63.5), const Vec2(200, 20),
          toward: const Vec2(0, 63.5));
      expect(probeContact(input), isNull);
    });
  });
}
