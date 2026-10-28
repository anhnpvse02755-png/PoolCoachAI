import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';

import '../../support/skill_test_fixtures.dart';

void main() {
  test('skillTestNumber: số thập phân dùng dấu phẩy như ô nhập', () {
    expect(Vi.skillTestNumber(7.5), '7,5');
    expect(Vi.skillTestNumber(9), '9');
    expect(Vi.skillTestNumber(9.0), '9');
  });

  test('tiêu chí đo bằng đơn vị khác: không có gạch ngang lủng củng', () {
    final fromSnapshot = Vi.criterionSnapshot(null, 25, 'cm')!;
    expect(fromSnapshot, 'Chấm theo tiêu chí: từ 25, đơn vị: cm');
    final fromDrill = Vi.skillTestCriterion(stById('t2'));
    expect(fromDrill, 'Tiêu chí đạt: từ 25, đơn vị: cm');
    expect(fromSnapshot, isNot(contains('—')));
    expect(fromDrill, isNot(contains('—')));
    expect(Vi.criterionSnapshot(null, 7.5, 'cm'), contains('7,5'));
  });

  test('bằng chứng chứng nhận: cỡ bàn và kết quả của lần đạt', () {
    expect(
      Vi.certificationEvidence(TableSize.eightFoot, 9, 10, 'lan / 10'),
      'Bàn 8 feet · 9/10 lần thử',
    );
    expect(
      Vi.certificationEvidence(TableSize.nineFootPlus, 27.5, null, 'cm'),
      'Bàn 9 feet trở lên · 27,5 cm',
    );
    expect(
      Vi.certificationEvidence(TableSize.sevenFoot, null, null, 'cm'),
      'Bàn 7 feet',
    );
  });
}
