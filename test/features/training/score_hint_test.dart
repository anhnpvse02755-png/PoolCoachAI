import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/drill_provenance.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/training/presentation/score_hint.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  test('bài có nguồn BU: khoảng 0..số cú của nguồn, không phụ thuộc target', () {
    final shots = drillProvenanceOf('d11')!.shots;
    final d = stDrill('d11', SkillCategory.aiming, 1, target: shots + 5);
    expect(scoreHintFor(d), Vi.sessionScoreHintRange(shots));
  });

  test('bài thường: ví dụ chung', () {
    final d = stDrill('zz', SkillCategory.aiming, 1, target: 20);
    expect(scoreHintFor(d), Vi.sessionScoreHintTarget);
  });
}
