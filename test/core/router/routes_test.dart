import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';

void main() {
  group('Routes', () {
    test('có đúng 5 tab, theo đúng thứ tự thiết kế', () {
      expect(Routes.tabs, [
        Routes.home,
        Routes.training,
        Routes.play,
        Routes.stats,
        Routes.profile,
      ]);
    });

    test('mọi đường dẫn đều bắt đầu bằng dấu gạch chéo', () {
      final all = [...Routes.tabs, Routes.coach, Routes.notifications];
      for (final path in all) {
        expect(path, startsWith('/'), reason: path);
      }
    });

    test('không có đường dẫn nào trùng nhau', () {
      final all = [...Routes.tabs, Routes.coach, Routes.notifications];
      expect(all.toSet().length, all.length);
    });
  });
}
