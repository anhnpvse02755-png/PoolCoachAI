import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/separate.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  const table = TableSpec.nineFoot;

  test('không chồng thì giữ nguyên chỗ (đã kẹp vào biên)', () {
    expect(separateFromAll(const Vec2(50, 50), const [Vec2(80, 50)]), const Vec2(50, 50));
    expect(separateFromAll(const Vec2(-5, 300), const []), table.clamp(const Vec2(-5, 300)));
  });

  test('thả giữa hai bi sát nhau thì ra chỗ không chạm bi nào', () {
    const others = [Vec2(100, 50), Vec2(106, 50)];
    final p = separateFromAll(const Vec2(103, 51), others)!;
    for (final o in others) {
      expect(p.distanceTo(o), greaterThanOrEqualTo(table.ballDiameter));
    }
    expect(table.contains(p), isTrue);
  });

  test('separateBalls giữ đúng hành vi cũ của màn mô phỏng', () {
    final p = separateBalls(const Vec2(101, 50), const Vec2(100, 50), const Vec2(90, 50));
    expect(p.distanceTo(const Vec2(100, 50)), greaterThanOrEqualTo(table.ballDiameter));
  });
}
