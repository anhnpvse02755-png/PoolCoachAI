import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;

  test('chọn lỗ có góc cắt nhỏ nhất', () {
    final cue = cueForAngle(tableCenter, Pocket.topRight, 0);
    final best = bestPocket(cue: cue, object: tableCenter)!;
    expect(best.pocket, Pocket.topRight);
    expect(best.angle, closeTo(0, 1e-5));
  });

  test('bỏ lỗ bị chắn, lấy lỗ tốt nhất trong các lỗ còn lại', () {
    final cue = cueForAngle(tableCenter, Pocket.topRight, 0);
    final u = (table.pocketPosition(Pocket.topRight) - tableCenter).normalized;
    final blocker = tableCenter + u * 30;

    final best = bestPocket(cue: cue, object: tableCenter, others: [blocker])!;

    final rest = [
      for (final p in Pocket.values)
        if (evaluateShot(cue: cue, object: tableCenter, pocket: p, others: [blocker])
            case Makeable(:final geometry))
          geometry.angle,
    ]..sort();
    expect(best.pocket, isNot(Pocket.topRight));
    expect(best.angle, rest.first);
  });

  test('không lỗ nào được thì trả null', () {
    final blockers = [
      for (final p in Pocket.values)
        tableCenter + (table.pocketPosition(p) - tableCenter).normalized * 15,
    ];
    final best = bestPocket(
      cue: const Vec2(60, 30),
      object: tableCenter,
      others: blockers,
    );
    expect(best, isNull);
  });

  group('so sánh hai cú', () {
    ShotGeometry shot(Pocket pocket, double angle, Vec2 object) => ShotGeometry(
          cue: Vec2.zero,
          object: object,
          pocket: pocket,
          ghost: object,
          objectDir: const Vec2(1, 0),
          tangentDir: Vec2.zero,
          aimDir: const Vec2(1, 0),
          angle: angle,
        );

    test('góc nhỏ hơn thắng', () {
      expect(
        compareShots(shot(Pocket.topLeft, 10, tableCenter),
            shot(Pocket.topRight, 20, tableCenter)),
        lessThan(0),
      );
    });

    test('hoà góc thì lỗ gần bi mục tiêu hơn thắng', () {
      const nearLeft = Vec2(40, 40);
      expect(
        compareShots(shot(Pocket.topLeft, 10, nearLeft),
            shot(Pocket.topRight, 10, nearLeft)),
        lessThan(0),
      );
    });

    test('hoà hết thì bằng nhau — bestPocket giữ lỗ đứng trước trong enum',
        () {
      expect(
        compareShots(shot(Pocket.topLeft, 10, tableCenter),
            shot(Pocket.topRight, 10, tableCenter)),
        0,
      );
    });
  });

  test('lưới bố cục có đủ cú để các test tính chất có ý nghĩa', () {
    expect(gridShots().length, greaterThan(300));
  });
}
