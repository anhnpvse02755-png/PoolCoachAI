import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';

void main() {
  group('PoolCoachApp quyền sở hữu router', () {
    testWidgets('router truyền từ ngoài vào vẫn dùng được sau khi app rời cây',
        (tester) async {
      final router = createAppRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(PoolCoachApp(router: router));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      void listener() {}
      expect(
        () => router.routerDelegate.addListener(listener),
        returnsNormally,
        reason: 'app không được dispose router mà nó không tự dựng',
      );
      router.routerDelegate.removeListener(listener);
    });
  });

  group('PoolCoachApp ngôn ngữ', () {
    testWidgets('chuỗi dựng sẵn của Material ra tiếng Việt, không phải tiếng Anh',
        (tester) async {
      await tester.pumpWidget(const PoolCoachApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Quay lại'),
        findsOneWidget,
        reason: 'nút back phải lấy nhãn từ bản dịch tiếng Việt của Material',
      );
      expect(find.byTooltip('Back'), findsNothing);
    });
  });
}
