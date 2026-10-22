import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';

import '../support/route_cases.dart';
import '../support/test_data.dart';

void main() {
  group('smoke test mọi route', () {
    testWidgets('mở được mọi đường dẫn mà không crash', (tester) async {
      final router = await pumpRoutedApp(tester, container: testContainer());

      for (final route in signedInRouteCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'màn ${route.path} ném lỗi khi dựng',
        );
      }
    });

    testWidgets('mỗi đường dẫn dựng đúng màn hình của nó', (tester) async {
      final router = await pumpRoutedApp(tester, container: testContainer());

      for (final route in signedInRouteCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();

        expect(
          find.byType(route.screen),
          findsOneWidget,
          reason: 'đường dẫn ${route.path} phải dựng ${route.screen}',
        );
      }
    });

    testWidgets('mở được mọi đường dẫn mà không crash — khi chưa đăng nhập', (
      tester,
    ) async {
      final router = await pumpRoutedApp(
        tester,
        container: testContainer(),
        signedIn: false,
      );

      for (final route in signedOutRouteCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'màn ${route.path} ném lỗi khi dựng',
        );
      }
    });

    testWidgets(
      'mỗi đường dẫn dựng đúng màn hình của nó — khi chưa đăng nhập',
      (tester) async {
        final router = await pumpRoutedApp(
          tester,
          container: testContainer(),
          signedIn: false,
        );

        for (final route in signedOutRouteCases.values) {
          router.go(route.path);
          await tester.pumpAndSettle();

          expect(
            find.byType(route.screen),
            findsOneWidget,
            reason: 'đường dẫn ${route.path} phải dựng ${route.screen}',
          );
        }
      },
    );

    test('bảng smoke test phủ hết mọi đường dẫn đã khai báo', () {
      expect(
        {...signedInRouteCases.keys, ...signedOutRouteCases.keys}.toSet(),
        Routes.all.toSet(),
        reason: 'thêm route vào Routes.all thì phải thêm vào bảng smoke test',
      );
    });

    // Đường dẫn mẫu phải đúng khuôn của route nó đại diện. Lấy mẫu
    // sai khuôn thì smoke test vẫn xanh trong khi route thật hỏng —
    // đúng kiểu lưới trông như có mà không bắt được gì.
    test('đường dẫn mẫu khớp đúng khuôn của route', () {
      for (final entry in {
        ...signedInRouteCases,
        ...signedOutRouteCases,
      }.entries) {
        final patternParts = entry.key.split('/');
        final pathParts = Uri.parse(entry.value.path).path.split('/');

        expect(
          pathParts.length,
          patternParts.length,
          reason: '${entry.value.path} không cùng số đoạn với ${entry.key}',
        );

        for (var i = 0; i < patternParts.length; i++) {
          if (patternParts[i].startsWith(':')) {
            expect(
              pathParts[i],
              isNotEmpty,
              reason: 'đoạn tham số ${patternParts[i]} phải có id mẫu',
            );
          } else {
            expect(
              pathParts[i],
              patternParts[i],
              reason: '${entry.value.path} lệch khuôn ${entry.key}',
            );
          }
        }
      }
    });
  });
}
