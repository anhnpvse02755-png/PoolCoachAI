import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const d = 5.715;
  final topRight = table.pocketPosition(Pocket.topRight);

  test('khoảng cách từ điểm tới đoạn thẳng', () {
    const a = Vec2(0, 0);
    const b = Vec2(10, 0);
    expect(distanceToSegment(const Vec2(5, 3), a, b), 3);
    expect(distanceToSegment(const Vec2(-4, 3), a, b), 5); // quá đầu đoạn
    expect(distanceToSegment(const Vec2(1, 1), a, a), closeTo(1.41421356, 1e-8));
    expect(isPathClear(a, b, [const Vec2(5, d)]), isTrue); // đúng D: không chắn
    expect(isPathClear(a, b, [const Vec2(5, d - 0.01)]), isFalse);
  });

  test('bi ảo lùi đúng một đường kính sau bi mục tiêu, trên đường lỗ', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 20);

    expect(g.ghost.distanceTo(tableCenter), closeTo(d, 1e-9));
    expect((tableCenter - g.ghost).cross(topRight - tableCenter),
        closeTo(0, 1e-9));
    expect((tableCenter - g.ghost).dot(topRight - tableCenter),
        greaterThan(0), reason: 'bi ảo phải nằm phía sau, không phải phía lỗ');
    expect(g.objectDir.length, closeTo(1, 1e-12));
  });

  test('góc cắt đúng như dựng', () {
    for (final degrees in <double>[0, 10, 30, 45, 60, 84.9]) {
      final g = geometryFor(tableCenter, Pocket.topRight, degrees);
      expect(g.angle, closeTo(degrees, 1e-5), reason: '$degrees°');
    }
  });

  test('hướng tiếp tuyến vuông góc đường bi mục tiêu, về phía bi cái đi tới',
      () {
    final g = geometryFor(tableCenter, Pocket.topRight, 30);
    expect(g.tangentDir.length, closeTo(1, 1e-12));
    expect(g.tangentDir.dot(g.objectDir), closeTo(0, 1e-12));
    expect(g.tangentDir.dot(g.aimDir), greaterThan(0));
  });

  test('cú thẳng thì không có hướng tiếp tuyến — không để nhiễu số học '
      'đẩy bi cái đi ngang', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 0);
    expect(g.tangentDir, Vec2.zero);
  });

  group('không đánh được', () {
    UnmakeableReason? reasonOf(ShotResult r) =>
        r is Unmakeable ? r.reason : null;

    test('hai bi chồng lên nhau', () {
      final r = evaluateShot(
        cue: tableCenter + const Vec2(d * 0.9, 0),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(reasonOf(r), UnmakeableReason.overlap);
    });

    test('bi mục tiêu sát băng, lỗ đòi bi ảo nằm sau băng', () {
      final r = evaluateShot(
        cue: const Vec2(100, 80),
        object: Vec2(60, table.minY),
        pocket: Pocket.bottomLeft,
      );
      expect(reasonOf(r), UnmakeableReason.ghostOffTable);
    });

    test('quá 85° là quá mỏng; đúng 85° vẫn đánh được', () {
      final over = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, 86),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(reasonOf(over), UnmakeableReason.tooThin);

      final edge = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, maxCutAngle),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(edge, isA<Makeable>());
    });

    test('đường bi cái tới bi ảo bị chắn', () {
      final cue = cueForAngle(tableCenter, Pocket.topRight, 20, distance: 60);
      final ghost = geometryFor(tableCenter, Pocket.topRight, 20).ghost;
      final r = evaluateShot(
        cue: cue,
        object: tableCenter,
        pocket: Pocket.topRight,
        others: [cue + (ghost - cue) * 0.5],
      );
      expect(reasonOf(r), UnmakeableReason.cueBlocked);
    });

    test('đường bi mục tiêu vào lỗ bị chắn', () {
      final u = (topRight - tableCenter).normalized;
      final r = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, 20),
        object: tableCenter,
        pocket: Pocket.topRight,
        others: [tableCenter + u * 30],
      );
      expect(reasonOf(r), UnmakeableReason.objectBlocked);
    });
  });

  test('mức độ khó theo góc cắt, biên dưới thuộc mức trên', () {
    expect(bandFor(0), DifficultyBand.easy);
    expect(bandFor(14.99), DifficultyBand.easy);
    expect(bandFor(15), DifficultyBand.medium);
    expect(bandFor(29.99), DifficultyBand.medium);
    expect(bandFor(30), DifficultyBand.hard);
    expect(bandFor(45), DifficultyBand.veryHard);
    expect(bandFor(60), DifficultyBand.extreme);
    expect(bandFor(85), DifficultyBand.extreme);
    expect(bandFor(85.1), DifficultyBand.impossible);
    expect(bandOf(const Unmakeable(UnmakeableReason.tooThin)),
        DifficultyBand.impossible);
  });
}
