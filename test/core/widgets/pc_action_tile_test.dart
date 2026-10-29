import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_action_tile.dart';

import '../../support/layout_sweep.dart';

void main() {
  const family = 'RobotoActionTile';
  const body =
      'Thông báo lúc 09:00 ngày đến hạn và 7 ngày trước đó. Chỉ hoạt động '
      'khi ứng dụng đang mở.';

  Future<void> open(WidgetTester tester, double scale) async {
    applyScreen(tester, const Size(360, 640), textScale: scale);
    final bytes = File('test/fixtures/fonts/roboto-regular.ttf')
        .readAsBytesSync();
    await tester.runAsync(
      () => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: family),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: PcActionTile(
                  icon: const Icon(Icons.notifications_active_outlined),
                  title: 'Nhắc bảo dưỡng đầu cơ',
                  body: body,
                  actionLabel: 'Bật thông báo',
                  onAction: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('x1.5: nút xuống dưới chữ, cột chữ đủ rộng', (tester) async {
    await open(tester, 1.5);
    final text = tester.getRect(find.text(body));
    final button = tester.getRect(find.text('Bật thông báo'));
    expect(text.width, greaterThanOrEqualTo(12 * 1.5 * 11));
    expect(button.top, greaterThanOrEqualTo(text.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('x1.0: nút cùng hàng với chữ', (tester) async {
    await open(tester, 1.0);
    final text = tester.getRect(find.text(body));
    final button = tester.getRect(find.text('Bật thông báo'));
    expect(button.top, lessThan(text.bottom));
    expect(tester.takeException(), isNull);
  });
}
