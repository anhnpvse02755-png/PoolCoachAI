import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';

import '../../support/layout_sweep.dart';
import '../../support/rich_data.dart';
import '../../support/route_cases.dart';

/// Nút Coach nổi không được che cuối nội dung cuộn của bất kỳ màn nào trong
/// shell. Quét mọi route đã đăng ký: mở ở 360x640, cuộn mọi danh sách dọc tới
/// cùng, rồi phần chữ cuối của danh sách phải nằm trên đỉnh nút. Màn nào quên
/// [pcScrollPadding] sẽ đỏ ở đây.
void main() {
  const size = Size(360, 640);

  /// Route không nằm trong shell nên không có nút Coach: quét bỏ qua, nhưng
  /// danh sách này khoá lại để một route shell không lặng lẽ rơi ra ngoài.
  const rootRoutes = <String>{
    Routes.coach,
    '/coach/situation?lib=pos-rail-1',
    Routes.coachLibrary,
    Routes.coachChat,
    Routes.notifications,
    Routes.rankLayouts,
    Routes.onboardingRank,
    Routes.rankTest,
    Routes.rank,
    Routes.knowledge,
    '/knowledge/k1',
  };

  Future<void> scrollToEnd(WidgetTester tester) async {
    // ListView ước lượng chiều dài theo hàng đã dựng: cuộn lặp tới khi ổn.
    for (var round = 0; round < 6; round++) {
      for (final state in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        if (axisDirectionToAxis(state.axisDirection) != Axis.vertical) continue;
        state.position.jumpTo(state.position.maxScrollExtent);
      }
      await tester.pumpAndSettle();
    }
  }

  for (final scale in [1.0, 1.5]) {
    testWidgets('mọi route trong shell x$scale: cuối danh sách nằm trên nút Coach',
        (tester) async {
      applyScreen(tester, size, textScale: scale);
      final router = await pumpRoutedApp(tester, container: richContainer());
      final failures = <String>[];
      final checked = <String>[];

      for (final route in signedInRouteCases.values) {
        router.go(route.path);
        await tester.pumpAndSettle();
        final fabFinder = find.byTooltip(Vi.coachTitle);
        if (fabFinder.evaluate().isEmpty) {
          if (!rootRoutes.contains(route.path)) {
            failures.add('${route.path}: không có nút Coach mà không phải route gốc');
          }
          continue;
        }
        if (rootRoutes.contains(route.path)) {
          failures.add('${route.path}: có nút Coach nhưng khai là route gốc');
          continue;
        }
        // Nội dung thật đã dựng, không phải màn rỗng hay lỗi.
        if (find.byType(route.screen).evaluate().length != 1) {
          failures.add('${route.path}: không dựng ${route.screen}');
          continue;
        }

        await scrollToEnd(tester);
        final fab = tester.getRect(fabFinder);
        var scrolls = 0;
        var paragraphs = 0;
        for (final scrollable in find.byType(Scrollable).evaluate().toList()) {
          final state = (scrollable as StatefulElement).state as ScrollableState;
          if (axisDirectionToAxis(state.axisDirection) != Axis.vertical) continue;
          final viewport = tester.getRect(find.byElementPredicate((e) => e == scrollable));
          // Chỉ danh sách có đáy chạm vùng nút mới có thể bị nút che.
          if (viewport.bottom < fab.top || viewport.width < 100) continue;
          scrolls++;
          for (final p in find.descendant(
            of: find.byElementPredicate((e) => e == scrollable),
            matching: find.byType(RichText),
          ).evaluate()) {
            final box = p.renderObject! as RenderParagraph;
            if (!box.hasSize) continue;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            if (rect.height == 0 || rect.top < viewport.top - 0.5) continue;
            if (rect.bottom > viewport.bottom + 0.5) continue;
            paragraphs++;
            if (rect.bottom > fab.top + 0.5) {
              failures.add('${route.path}: chữ ở $rect nằm dưới nút $fab');
            }
          }
        }
        // Vùng ghim (không cuộn, như nút Đăng xuất của Hồ sơ): không chữ nào
        // trên màn được giao với nút.
        var onScreen = 0;
        for (final p in find.byType(RichText).evaluate()) {
          final box = p.renderObject! as RenderParagraph;
          if (!box.hasSize) continue;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.height == 0 || rect.top >= fab.bottom) continue;
          onScreen++;
          if (rect.overlaps(fab) &&
              find.descendant(of: fabFinder, matching: find.byWidget(p.widget)).evaluate().isEmpty) {
            failures.add('${route.path}: chữ ghim ở $rect giao với nút $fab');
          }
        }
        if (onScreen < 2 || (scrolls == 0 && paragraphs == 0 && route.path != Routes.profile)) {
          failures.add('${route.path}: không có danh sách cuộn/chữ để kiểm '
              '(cuộn $scrolls, chữ $paragraphs, trên màn $onScreen)');
        }
        checked.add(route.path);
      }
      expect(failures, isEmpty);
      expect(checked, containsAll([Routes.home, Routes.roadmap, '/play/tournaments/t1', '/training/drills/d1']));
    });
  }

  testWidgets('bàn phím mở thì nút Coach ẩn, đóng thì hiện lại', (tester) async {
    applyScreen(tester, size);
    await pumpRoutedApp(tester, container: richContainer());
    expect(find.byTooltip(Vi.coachTitle), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byTooltip(Vi.coachTitle), findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byTooltip(Vi.coachTitle), findsOneWidget);
  });
}
