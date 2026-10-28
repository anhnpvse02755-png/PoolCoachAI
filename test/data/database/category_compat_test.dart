import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/category_compat.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  test(
    'sáu tên cũ đóng băng, đúng sáu nhóm đầu của enum',
    () => expect(
      legacyCategoryNames,
      SkillCategory.values.take(6).map((c) => c.name).toSet(),
    ),
  );

  test('tách và ghép một tên', () {
    expect(splitCategoryName('aiming'), (legacy: 'aiming', ext: null));
    expect(splitCategoryName('dungCo'), (legacy: null, ext: 'dungCo'));
    expect(splitCategoryName(null), (legacy: null, ext: null));
    expect(joinCategoryName('aiming', 'dungCo'), 'aiming');
    expect(joinCategoryName(null, 'nhayBi'), 'nhayBi');
    expect(joinCategoryName(null, 'nhomTuongLai'), isNull);
    expect(joinCategoryName(null, null), isNull);
    expect(() => joinCategoryName(null, 3), throwsFormatException);
  });

  test('tách và ghép danh sách', () {
    final s = splitCategoryNames(['nhayBi', 'aiming']);
    expect(s.legacy, ['aiming']);
    expect(s.ext, ['nhayBi']);
    expect(
      joinCategoryNames(['position'], ['nhayBi', 'nhomTuongLai', 'position']),
      ['position', 'nhayBi'],
    );
    expect(joinCategoryNames(['aiming'], null), ['aiming']);
    expect(() => joinCategoryNames(['aiming'], 'x'), throwsFormatException);
    expect(() => joinCategoryNames(['aiming'], [1]), throwsFormatException);
  });
}
