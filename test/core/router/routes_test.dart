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

    test('all gom đủ năm tab, hai màn mở đè và ba đường dẫn có tham số', () {
      expect(Routes.all, [
        ...Routes.tabs,
        Routes.coach,
        Routes.notifications,
        Routes.drillPattern,
        Routes.drillSessionPattern,
        Routes.articlePattern,
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

  // Ba đường dẫn mới của Phase 1 đều mang tham số, nên ngoài hằng số
  // khuôn còn cần hàm dựng. Widget gọi hàm, không tự nối chuỗi — nối
  // tay là đường dẫn sai chỉ lộ ra lúc chạy.
  group('Routes — đường dẫn có tham số', () {
    test('hàm dựng ra đúng khuôn đã khai báo, chỉ thay :id', () {
      expect(Routes.drill('d3'), '/training/drills/d3');
      expect(Routes.drillSession('d3'), '/training/drills/d3/session');
      expect(Routes.article('k2'), '/knowledge/k2');
    });

    test('mỗi hàm dựng khớp đúng khuôn của nó', () {
      expect(Routes.drill('x'), Routes.drillPattern.replaceAll(':id', 'x'));
      expect(
        Routes.drillSession('x'),
        Routes.drillSessionPattern.replaceAll(':id', 'x'),
      );
      expect(Routes.article('x'), Routes.articlePattern.replaceAll(':id', 'x'));
    });

    test('buổi tập nằm sâu trong chi tiết bài, không phải route rời', () {
      expect(Routes.drillSession('d3'), startsWith(Routes.drill('d3')));
    });

    test('chi tiết bài nằm trong nhánh Luyện tập của shell', () {
      expect(Routes.drill('d3'), startsWith('${Routes.training}/'));
    });
  });
}
