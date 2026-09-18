import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';

/// Router tối giản có màn con trong nhánh đầu.
///
/// App thật chưa có màn con nào, nên hành vi "bấm lại tab đang mở để
/// quay về gốc" không quan sát được ở đó. Dựng riêng ở đây để khoá lại
/// trước khi kế hoạch sau cắm màn con vào.
GoRouter _routerWithSubRoute() {
  StatefulShellBranch plain(String path, String label) => StatefulShellBranch(
        routes: [
          GoRoute(path: path, builder: (context, state) => Text(label)),
        ],
      );

  return GoRouter(
    initialLocation: '/mot',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            PcShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mot',
                builder: (context, state) => const Text('màn gốc nhánh một'),
                routes: [
                  GoRoute(
                    path: 'chi-tiet',
                    builder: (context, state) => const Text('màn con'),
                  ),
                ],
              ),
            ],
          ),
          plain('/hai', 'màn gốc nhánh hai'),
          plain('/ba', 'màn gốc nhánh ba'),
          plain('/bon', 'màn gốc nhánh bốn'),
          plain('/nam', 'màn gốc nhánh năm'),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('bấm lại tab đang mở thì nhánh đó quay về màn gốc',
      (tester) async {
    final router = _routerWithSubRoute();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('màn gốc nhánh một'), findsOneWidget);

    router.go('/mot/chi-tiet');
    await tester.pumpAndSettle();
    expect(find.text('màn con'), findsOneWidget);

    await tester.tap(find.text(Vi.tabHome));
    await tester.pumpAndSettle();

    expect(
      find.text('màn gốc nhánh một'),
      findsOneWidget,
      reason: 'bấm lại chính tab đang mở phải đẩy nhánh về gốc',
    );
    expect(find.text('màn con'), findsNothing);
  });

  testWidgets('bấm sang tab khác thì không đụng tới ngăn xếp của tab cũ',
      (tester) async {
    final router = _routerWithSubRoute();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/mot/chi-tiet');
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.tabPlay));
    await tester.pumpAndSettle();
    expect(find.text('màn gốc nhánh ba'), findsOneWidget);

    await tester.tap(find.text(Vi.tabHome));
    await tester.pumpAndSettle();

    expect(
      find.text('màn con'),
      findsOneWidget,
      reason: 'quay lại tab cũ phải thấy nguyên chỗ đang dở',
    );
  });
}
