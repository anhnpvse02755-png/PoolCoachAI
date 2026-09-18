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

    test('all gom đủ năm tab và hai màn mở đè', () {
      expect(Routes.all, [
        ...Routes.tabs,
        Routes.coach,
        Routes.notifications,
      ]);
    });

    test('mọi đường dẫn đều bắt đầu bằng dấu gạch chéo', () {
      for (final path in Routes.all) {
        expect(path, startsWith('/'), reason: path);
      }
    });

    test('không có đường dẫn nào trùng nhau', () {
      expect(Routes.all.toSet().length, Routes.all.length);
    });
  });
}
