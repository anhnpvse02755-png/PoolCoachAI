import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

void main() {
  // Lực đại diện từng cột: Chậm = 30, Vừa = 45, Nhanh = 90.
  final powers = [powerPresets.first, powerPresets[1], powerPresets.last];

  test('cả chín ô của bảng, đúng tại ba khoảng cách mốc, Đánh đứng bi', () {
    for (var r = 0; r < sawsRowDistances.length; r++) {
      for (var c = 0; c < powers.length; c++) {
        expect(
            sawsBhePercent(
                distance: sawsRowDistances[r],
                power: powers[c],
                stroke: Stroke.stun),
            sawsBheTable[r][c],
            reason: 'hàng $r cột $c');
      }
    }
  });

  test('mỗi mức lực vào đúng cột; lực lạ lấy cột của mức gần nhất', () {
    final d = sawsRowDistances[1];
    int at(double p) =>
        sawsBhePercent(distance: d, power: p, stroke: Stroke.stun);
    expect(at(powerPresets[2]), sawsBheTable[1][1]);
    expect(at(powerPresets[3]), sawsBheTable[1][2]);
    expect(at(powerPresets[4]), sawsBheTable[1][2]);
    expect(at(50), sawsBheTable[1][1]);
    expect(at(10), sawsBheTable[1][0]);
    expect(at(200), sawsBheTable[1][2]);
  });

  test('nội suy tuyến tính giữa hai hàng, làm tròn 5%', () {
    final mid = (sawsRowDistances[0] + sawsRowDistances[1]) / 2;
    final raw = (sawsBheTable[0][1] + sawsBheTable[1][1]) / 2;
    expect(
        sawsBhePercent(distance: mid, power: powers[1], stroke: Stroke.stun),
        (raw / 5).round() * 5);
    // Một điểm không rơi đúng bội 5: phải làm tròn về bội 5 gần nhất.
    final d = sawsRowDistances[0] + 0.3 * (sawsRowDistances[1] - sawsRowDistances[0]);
    final r = sawsBheTable[0][0] + 0.3 * (sawsBheTable[1][0] - sawsBheTable[0][0]);
    final got =
        sawsBhePercent(distance: d, power: powers[0], stroke: Stroke.stun);
    expect(got % 5, 0);
    expect((got - r).abs(), lessThanOrEqualTo(2.5));
  });

  test('ngoài hai đầu thì dùng hàng đầu / hàng cuối', () {
    expect(
        sawsBhePercent(
            distance: sawsRowDistances.first / 2,
            power: powers[1],
            stroke: Stroke.stun),
        sawsBheTable.first[1]);
    expect(
        sawsBhePercent(
            distance: sawsRowDistances.last * 2,
            power: powers[1],
            stroke: Stroke.stun),
        sawsBheTable.last[1]);
  });

  test('trô cộng, cu lê trừ sawsStrokeShift BHE, kẹp trong 0..100', () {
    int at(int row, int col, Stroke s) => sawsBhePercent(
        distance: sawsRowDistances[row], power: powers[col], stroke: s);
    expect(at(1, 1, Stroke.draw), sawsBheTable[1][1] + sawsStrokeShift);
    expect(at(1, 1, Stroke.follow), sawsBheTable[1][1] - sawsStrokeShift);
    expect(at(0, 2, Stroke.draw), 100);
    expect(
        sawsBhePercent(
            distance: 100, power: 30, stroke: Stroke.follow, ),
        greaterThanOrEqualTo(0));
  });
}
