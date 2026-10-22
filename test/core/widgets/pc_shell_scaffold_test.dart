import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/core/widgets/pc_shell_scaffold.dart';

import '../../support/layout_sweep.dart';

/// Router tối giản có màn con trong nhánh đầu.
///
/// App thật chưa có màn con nào, nên hành vi "bấm lại tab đang mở để
/// quay về gốc" không quan sát được ở đó. Dựng riêng ở đây để khoá lại
/// trước khi kế hoạch sau cắm màn con vào.
GoRouter _routerWithSubRoute() {
  StatefulShellBranch plain(String path, String label) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => Text(label))],
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

/// Router năm nhánh, gốc nhánh đầu là một bộ đếm giữ trạng thái riêng:
/// xoay máy mà bộ đếm về 0 là shell đã dựng lại nhánh từ đầu.
GoRouter _probeRouter() {
  StatefulShellBranch plain(String path) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => Text(path))],
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
                builder: (context, state) => const _CounterProbe(),
              ),
            ],
          ),
          plain('/hai'),
          plain('/ba'),
          plain('/bon'),
          plain('/nam'),
        ],
      ),
    ],
  );
}

class _CounterProbe extends StatefulWidget {
  const _CounterProbe();

  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  var _n = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('đếm $_n'),
      TextButton(
        onPressed: () => setState(() => _n++),
        child: const Text('tăng'),
      ),
    ],
  );
}

void main() {
  /// Dựng shell với router có màn con, trả router để test tự lái.
  Future<GoRouter> pumpShell(WidgetTester tester) async {
    final router = _routerWithSubRoute();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('bấm lại tab đang mở thì nhánh đó quay về màn gốc', (
    tester,
  ) async {
    final router = await pumpShell(tester);
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

  testWidgets('bấm sang tab khác thì không đụng tới ngăn xếp của tab cũ', (
    tester,
  ) async {
    final router = await pumpShell(tester);

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

  testWidgets('dưới 600: thanh tab dưới và nút Coach nổi', (tester) async {
    applyScreen(tester, const Size(599, 800));
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip(Vi.coachTitle), findsOneWidget);
  });

  testWidgets('từ 600: thanh bên cuộn được, nút Coach ở đầu thanh', (
    tester,
  ) async {
    applyScreen(tester, const Size(600, 800));
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byTooltip(Vi.coachTitle),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).scrollable,
      isTrue,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).labelType,
      NavigationRailLabelType.all,
    );
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'điện thoại ngang có thanh trạng thái, chữ ×$scale: đủ năm mục và nút '
      'Coach trong màn, thanh bên không phải cuộn',
      (tester) async {
        applyScreen(tester, const Size(740, 360), textScale: scale);
        tester.view.padding = const FakeViewPadding(top: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24);
        await pumpShell(tester);
        final rail = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          rail.position.maxScrollExtent,
          0,
          reason: 'mục cuối của thanh bên phải hiện mà không cần cuộn',
        );
      },
    );
  }

  testWidgets('thanh bên chuyển nhánh và giữ ngăn xếp như thanh dưới', (
    tester,
  ) async {
    applyScreen(tester, const Size(1024, 768));
    final router = await pumpShell(tester);
    Finder railLabel(String label) => find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    );

    router.go('/mot/chi-tiet');
    await tester.pumpAndSettle();

    await tester.tap(railLabel(Vi.tabPlay));
    await tester.pumpAndSettle();
    expect(find.text('màn gốc nhánh ba'), findsOneWidget);

    await tester.tap(railLabel(Vi.tabHome));
    await tester.pumpAndSettle();

    expect(
      find.text('màn con'),
      findsOneWidget,
      reason: 'quay lại tab cũ phải thấy nguyên chỗ đang dở',
    );
  });

  testWidgets('xoay máy giữ nguyên trạng thái nhánh', (tester) async {
    applyScreen(tester, const Size(360, 640));
    final router = _probeRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tăng'));
    await tester.tap(find.text('tăng'));
    await tester.pump();

    tester.view.physicalSize = const Size(640, 360);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('đếm 2'), findsOneWidget);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('đếm 2'), findsOneWidget);
  });

  testWidgets('điện thoại ngang, chữ lớn: thanh bên không tràn', (
    tester,
  ) async {
    applyScreen(tester, const Size(740, 360), textScale: 2.0);
    await pumpShell(tester);
    expect(tester.takeException(), isNull);
  });

  test('thanh bên dùng đúng màu của thanh tab dưới', () {
    final theme = AppTheme.dark();
    final rail = theme.navigationRailTheme;
    expect(rail.backgroundColor, theme.navigationBarTheme.backgroundColor);
    expect(rail.indicatorColor, theme.navigationBarTheme.indicatorColor);
    expect(rail.selectedLabelTextStyle?.color, AppColors.accent);
    expect(rail.unselectedLabelTextStyle?.color, AppColors.textMuted);
    expect(rail.selectedIconTheme?.color, AppColors.accent);
    expect(rail.unselectedIconTheme?.color, AppColors.textMuted);
  });
}
