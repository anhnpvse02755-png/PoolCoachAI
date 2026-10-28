import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/domain/skill_category.dart';

Drill _drill(String id, num target) => Drill(
  id: id,
  cat: SkillCategory.aiming,
  name: 'n',
  level: 1,
  unit: 'u',
  goal: 'g',
  steps: const [],
  target: target,
);

void main() {
  test('số cú lấy từ phiếu điểm BU, mỗi cú một điểm', () {
    for (final MapEntry(key: id, value: p) in drillProvenance.entries) {
      final bu = drillFor(p.buDrillId, p.version);
      expect(p.shots, bu.attemptCount, reason: id);
      expect(p.shots, bu.maxScore, reason: id);
    }
  });

  test('đặc trưng nguồn BU: S8 và S9 đều 3 / 5 / 7 cú', () {
    expect(
      [
        for (final id in ['d11', 'd12', 'd13', 'd14', 'd15', 'd16'])
          drillProvenanceOf(id)!.shots,
      ],
      [3, 5, 7, 3, 5, 7],
    );
  });

  test('S8: mỗi cú một sơ đồ; S9: một sơ đồ dùng cho mọi cú', () {
    for (final p in drillProvenance.values) {
      expect(
        layoutsFor(p.buDrillId, p.version).length,
        p.buDrillId == 'S8' ? p.shots : 1,
      );
    }
  });

  test('bảng nguồn: d11–d19, S8 ba bậc, S9 hai lượt ba bậc; cấp = bậc', () {
    expect(drillProvenance.keys, [
      'd11', 'd12', 'd13', 'd14', 'd15', 'd16', 'd17', 'd18', 'd19', //
    ]);
    expect(drillProvenance.values.where((p) => p.buDrillId == 'S8').length, 3);
    expect(drillProvenance.values.where((p) => p.buDrillId == 'S9').length, 6);
    expect(
      [for (final p in drillProvenance.values) p.level],
      [
        1, 2, 3, 1, 2, 3, 1, 2, 3, //
      ],
    );
    expect(drillProvenanceOf('d1'), isNull);
  });

  test('điểm theo cú: số nguyên từ 0 tới số cú', () {
    final shots = drillProvenanceOf('d11')!.shots;
    final d = _drill('d11', shots);
    expect(checkShotScore(d, 0), isNull);
    expect(checkShotScore(d, shots), isNull);
    expect(checkShotScore(d, shots + 1), ShotScoreError.aboveShots);
    expect(checkShotScore(d, shots - 0.5), ShotScoreError.notWhole);
    expect(checkShotScore(_drill('d6', 1), 4), isNull); // bài cũ không đổi
  });

  test('điểm âm và không hữu hạn để cho kiểm tra có sẵn', () {
    final d = _drill('d11', drillProvenanceOf('d11')!.shots);
    expect(checkShotScore(d, -1), isNull);
    expect(checkShotScore(d, double.nan), isNull);
    expect(checkShotScore(d, double.infinity), isNull);
  });
}
