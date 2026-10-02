@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

void main() {
  test('aimShot trung vị dưới 8 ms trên Dart VM', () {
    // Bố cục mở màn, đứng bi có áp phê: nhiều vòng dò nhất (b và bù ném),
    // cộng hai lần mô phỏng đầy đủ. Còn chỗ cho dart2js chậm hơn VM.
    for (final stroke in Stroke.values) {
      void once() => aimShot(
          cue: const Vec2(80, 90),
          object: const Vec2(170, 50),
          pocket: Pocket.topRight,
          stroke: stroke,
          spin: const SideSpin(SpinSide.right, 1),
          power: 45);
      for (var i = 0; i < 5; i++) {
        once(); // làm nóng JIT
      }
      final micros = <int>[];
      for (var i = 0; i < 50; i++) {
        final w = Stopwatch()..start();
        once();
        micros.add(w.elapsedMicroseconds);
      }
      micros.sort();
      expect(micros[25] / 1000, lessThan(8), reason: '$stroke');
    }
  });
}
