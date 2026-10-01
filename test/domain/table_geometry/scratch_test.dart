import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final corner = table.pocketPosition(Pocket.topRight);
  // Bi mục tiêu sát lỗ góc trên phải, cú thẳng: cu lê đi theo bi vào lỗ.
  final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);

  test('cu lê theo bi vào lỗ là chết cái, và rơi trước khi kịp chạm băng',
      () {
    final path = simulateCueBall(g, stroke: Stroke.follow, power: 95);
    expect(path.scratch, Pocket.topRight);
    expect(path.bankUsed, isFalse);
    expect(path.end.distanceTo(corner), lessThanOrEqualTo(cornerCapture));
  });

  test('đánh đứng bi cú thẳng thì bi cái dừng tại chỗ, không chết cái', () {
    expect(simulateCueBall(g, stroke: Stroke.stun, power: 95).scratch, isNull);
  });

  test('biên lực chết cái: mức lực nguyên đầu tiên đưa bi cái vào vùng lỗ',
      () {
    // Cú thẳng cu lê đi dọc đường lỗ được rollCarry·maxTravel·p/100 cm.
    final need = g.ghost.distanceTo(corner) - cornerCapture;
    final expected = (need / (rollCarry * maxTravel / 100)).ceil();

    final risk = scratchMargin(g, stroke: Stroke.follow, power: 10)!;
    expect(risk.pocket, Pocket.topRight);
    expect(risk.power, expected < 10 ? 10 : expected);
  });

  test('không chết cái tới 100% thì không có biên', () {
    expect(scratchMargin(g, stroke: Stroke.stun, power: 40), isNull);
  });

  test('ngay mức chọn đã chết cái thì biên là chính mức đó', () {
    final risk = scratchMargin(g, stroke: Stroke.follow, power: 95)!;
    expect(risk.power, 95);
  });

  test('trên lưới: chết cái thì điểm dừng nằm trong vùng lỗ đó', () {
    for (final shot in gridShots()) {
      for (final stroke in Stroke.values) {
        final path = simulateCueBall(shot, stroke: stroke, power: 95);
        final pocket = path.scratch;
        if (pocket == null) continue;
        expect(
          path.end.distanceTo(table.pocketPosition(pocket)),
          lessThanOrEqualTo(table.captureRadius(pocket)),
          reason: '${shot.cue}→${shot.object} $stroke',
        );
      }
    }
  });
}
