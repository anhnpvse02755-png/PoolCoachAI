import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';

import '../support/layout_sweep.dart';
import '../support/rich_data.dart';
import '../support/route_cases.dart';

void main() {
  Future<void> openHome(WidgetTester tester) async {
    final router = await pumpRoutedApp(tester, container: richContainer());
    router.go(Routes.home);
    await tester.pumpAndSettle();
  }

  double scaleOf(WidgetTester tester, Finder finder) =>
      MediaQuery.textScalerOf(tester.element(finder)).scale(10);

  testWidgets('chữ hệ thống ×3 bị kẹp còn ×1.5 trong thân màn', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 3.0);
    await openHome(tester);
    expect(scaleOf(tester, find.text(Vi.homeStreakUnit)), 15);
  });

  testWidgets('chữ hệ thống ×0.85 giữ nguyên', (tester) async {
    applyScreen(tester, const Size(360, 640), textScale: 0.85);
    await openHome(tester);
    expect(scaleOf(tester, find.text(Vi.homeStreakUnit)), closeTo(8.5, 1e-9));
  });

  testWidgets('nhãn thanh tab dưới không phóng theo chữ hệ thống', (
    tester,
  ) async {
    applyScreen(tester, const Size(360, 640), textScale: 2.0);
    await openHome(tester);
    final label = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Vi.tabTraining),
    );
    expect(scaleOf(tester, label), 10);
  });

  testWidgets('tai thỏ ngang: thân màn không nằm dưới tai thỏ', (tester) async {
    applyScreen(tester, const Size(740, 360));
    tester.view.padding = const FakeViewPadding(left: 44, right: 44);
    tester.view.viewPadding = const FakeViewPadding(left: 44, right: 44);
    await openHome(tester);
    final appBar = find.byType(AppBar).first;
    expect(tester.getTopLeft(appBar).dx, greaterThanOrEqualTo(44));
    expect(tester.getTopRight(appBar).dx, lessThanOrEqualTo(740 - 44));
  });
}
