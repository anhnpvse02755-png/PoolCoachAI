import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('Rank', () {
    test('có đúng 11 hạng', () {
      expect(Rank.values.length, 11);
    });

    test('K I H G thuộc nhóm phong trào', () {
      for (final rank in [Rank.k, Rank.i, Rank.h, Rank.g]) {
        expect(rank.group, RankGroup.amateur, reason: 'hạng ${rank.label}');
      }
    });

    test('F đến A thuộc nhóm cạnh tranh', () {
      for (final rank in [Rank.f, Rank.e, Rank.d, Rank.c, Rank.b, Rank.a]) {
        expect(rank.group, RankGroup.competitive, reason: 'hạng ${rank.label}');
      }
    });

    test('professional đứng riêng một nhóm', () {
      expect(Rank.pro.group, RankGroup.pro);
    });

    test('nhãn hiển thị là chữ hoa, riêng pro là PRO', () {
      expect(Rank.k.label, 'K');
      expect(Rank.g.label, 'G');
      expect(Rank.pro.label, 'PRO');
    });

    test('thứ tự từ thấp lên cao', () {
      expect(Rank.values.first, Rank.k);
      expect(Rank.values.last, Rank.pro);
      expect(Rank.g.index, lessThan(Rank.f.index));
    });
  });
}
