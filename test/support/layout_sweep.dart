import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rich_data.dart';
import 'route_cases.dart';
import 'test_data.dart';

/// Một cỡ màn của lượt quét: tên để báo lỗi, kích thước, cỡ chữ hệ thống.
typedef SweepConfig = ({String name, Size size, double textScale});

/// Đặt kích thước màn (điểm logic) và cỡ chữ hệ thống cho một test.
void applyScreen(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Cuộn qua mọi danh sách dọc màn đang vẽ.
///
/// `ListView` chỉ dựng những hàng đang hiện, nên hàng ở dưới không
/// bao giờ được dàn trang nếu không có gì cuộn tới nó.
Future<void> scrollThroughAll(WidgetTester tester) async {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical)
      .toList();
  for (final state in states) {
    if (!state.mounted) continue;
    final position = state.position;
    for (var step = 0; step < 50; step++) {
      final target = math.min(
        position.viewportDimension * 0.9 * step,
        position.maxScrollExtent,
      );
      position.jumpTo(target);
      await tester.pump();
      if (target >= position.maxScrollExtent) break;
    }
    position.jumpTo(0);
    await tester.pump();
  }
}

/// Mở lần lượt mọi route ở cỡ màn [config], mỗi route cuộn hết một lượt.
Future<void> sweepRoutes(
  WidgetTester tester,
  SweepConfig config, {
  required bool signedIn,
}) async {
  applyScreen(tester, config.size, textScale: config.textScale);
  final router = await pumpRoutedApp(
    tester,
    container: signedIn ? richContainer() : testContainer(),
    signedIn: signedIn,
  );
  for (final route
      in (signedIn ? signedInRouteCases : signedOutRouteCases).values) {
    router.go(route.path);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '${config.name}: ${route.path} tràn khi mở',
    );
    await scrollThroughAll(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: '${config.name}: ${route.path} tràn khi cuộn',
    );
  }
}

/// Hộp thoại không tràn, nút cuối cùng (nút xác nhận) nằm trên bàn phím,
/// và mọi ô nhập cuộn tới được, bấm được, nằm trọn trên bàn phím.
///
/// Thiếu chỗ thì thân hộp thoại có thể bị ép còn 0 px: ô nhập biến mất
/// mà Flutter không báo tràn, nên phải thử với tới từng ô.
Future<void> expectDialogFitsAboveKeyboard(
  WidgetTester tester, {
  required double screenHeight,
  required double keyboard,
}) async {
  expect(tester.takeException(), isNull);
  final dialog = find.byType(AlertDialog);
  final buttons = find.descendant(
    of: dialog,
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(
    tester.getBottomLeft(buttons.last).dy,
    lessThanOrEqualTo(screenHeight - keyboard),
  );
  final fields = find.descendant(
    of: dialog,
    matching: find.byWidgetPredicate((w) => w is FormField),
  );
  final count = fields.evaluate().length;
  expect(count, greaterThan(0), reason: 'hộp thoại không có ô nhập nào');
  for (var i = 0; i < count; i++) {
    await tester.ensureVisible(fields.at(i));
    await tester.pumpAndSettle();
    expect(
      fields.at(i).hitTestable(),
      findsOneWidget,
      reason: 'ô nhập thứ ${i + 1} không cuộn tới được',
    );
    expect(
      tester.getBottomLeft(fields.at(i)).dy,
      lessThanOrEqualTo(screenHeight - keyboard),
      reason: 'ô nhập thứ ${i + 1} nằm dưới bàn phím',
    );
  }
  expect(tester.takeException(), isNull);
}
