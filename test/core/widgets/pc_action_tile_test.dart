import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_action_tile.dart';

import '../../support/layout_sweep.dart';

void main() {
  const family = 'RobotoActionTile';

  Future<void> open(
    WidgetTester tester, {
    required double width,
    required double scale,
    required String title,
    required String body,
    required String label,
  }) async {
    applyScreen(tester, Size(width, 640), textScale: scale);
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
                  title: title,
                  body: body,
                  actionLabel: label,
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

  final cases = <(String, String, String)>[
    (
      Vi.equipmentReminderTitle,
      Vi.equipmentReminderPrompt,
      Vi.equipmentReminderEnable,
    ),
    (Vi.unsyncableTitle(2), Vi.unsyncableBody, Vi.unsyncableDiscard),
  ];

  // Quy tắc: cột chữ rộng ít nhất 11 em (cỡ 12 sp theo chữ người dùng), nếu
  // không thì nút phải nằm dưới chữ.
  for (final (title, body, label) in cases) {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.1, 1.2, 1.3, 1.5]) {
        testWidgets('$label ở rộng $width x$scale: cột chữ >= 11 em hoặc xếp '
            'chồng', (tester) async {
          await open(
            tester,
            width: width,
            scale: scale,
            title: title,
            body: body,
            label: label,
          );
          final text = tester.getRect(find.text(body));
          final button = tester.getRect(find.text(label));
          final stacked = button.top >= text.bottom;
          expect(
            stacked || text.width >= 12 * scale * 11,
            isTrue,
            reason: 'cột chữ ${text.width}, nút $button, chữ $text',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('x1.5 ở 360: nút xuống dưới chữ, cột chữ đủ rộng', (
    tester,
  ) async {
    final (title, body, label) = cases.first;
    await open(
      tester,
      width: 360,
      scale: 1.5,
      title: title,
      body: body,
      label: label,
    );
    final text = tester.getRect(find.text(body));
    final button = tester.getRect(find.text(label));
    expect(text.width, greaterThanOrEqualTo(12 * 1.5 * 11));
    expect(button.top, greaterThanOrEqualTo(text.bottom));
  });

  testWidgets('x1.0 ở 360: nút cùng hàng với chữ', (tester) async {
    final (title, body, label) = cases.first;
    await open(
      tester,
      width: 360,
      scale: 1.0,
      title: title,
      body: body,
      label: label,
    );
    final text = tester.getRect(find.text(body));
    final button = tester.getRect(find.text(label));
    expect(button.top, lessThan(text.bottom));
  });
}
