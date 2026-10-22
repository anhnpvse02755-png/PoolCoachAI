import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_layout.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

import '../../support/layout_sweep.dart';

void main() {
  group('PcRootScaffold', () {
    testWidgets('đặt tên màn lên thanh tiêu đề', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PcRootScaffold(title: 'Thống kê', body: SizedBox()),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Thống kê'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dựng phần thân được truyền vào', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PcRootScaffold(
            title: 'Thống kê',
            body: Text('nội dung thân màn'),
          ),
        ),
      );

      expect(find.text('nội dung thân màn'), findsOneWidget);
    });

    testWidgets('có chuông thông báo kèm nhãn trợ năng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PcRootScaffold(title: 'Thống kê', body: SizedBox()),
        ),
      );

      expect(find.byTooltip(Vi.notificationsTitle), findsOneWidget);
    });
  });

  group('bề rộng đọc', () {
    Future<void> pumpRoot(
      WidgetTester tester, {
      required Widget body,
      double maxBodyWidth = AppLayout.readableMaxWidth,
    }) => tester.pumpWidget(
      MaterialApp(
        home: PcRootScaffold(
          title: 'Thống kê',
          body: body,
          maxBodyWidth: maxBodyWidth,
        ),
      ),
    );

    testWidgets('màn rộng 1280: thân màn tối đa 840 và nằm giữa, '
        'thanh tiêu đề vẫn rộng hết', (tester) async {
      applyScreen(tester, const Size(1280, 800));
      await pumpRoot(tester, body: const SizedBox.expand(key: Key('thân')));
      expect(tester.getSize(find.byKey(const Key('thân'))).width, 840);
      expect(
        tester.getTopLeft(find.byKey(const Key('thân'))).dx,
        (1280 - 840) / 2,
      );
      expect(tester.getSize(find.byType(AppBar)).width, 1280);
    });

    testWidgets('điện thoại 360: thân màn rộng hết', (tester) async {
      applyScreen(tester, const Size(360, 640));
      await pumpRoot(tester, body: const SizedBox.expand(key: Key('thân')));
      expect(tester.getSize(find.byKey(const Key('thân'))).width, 360);
    });

    testWidgets('màn có bàn bỏ trần: rộng hết 1280', (tester) async {
      applyScreen(tester, const Size(1280, 800));
      await pumpRoot(
        tester,
        body: const SizedBox.expand(key: Key('thân')),
        maxBodyWidth: double.infinity,
      );
      expect(tester.getSize(find.byKey(const Key('thân'))).width, 1280);
    });

    // Thân màn tự co theo nội dung (cột căn trái) vẫn phải được cả bề
    // ngang: co lại thì cột bị đẩy vào giữa, kể cả trên điện thoại.
    testWidgets('thân màn co theo nội dung vẫn bắt đầu ở mép trái', (
      tester,
    ) async {
      const body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('trái', key: Key('trái'))],
      );
      applyScreen(tester, const Size(360, 640));
      await pumpRoot(tester, body: body);
      expect(tester.getTopLeft(find.byKey(const Key('trái'))).dx, 0);

      applyScreen(tester, const Size(1280, 800));
      await pumpRoot(tester, body: body);
      expect(
        tester.getTopLeft(find.byKey(const Key('trái'))).dx,
        (1280 - 840) / 2,
      );
    });
  });
}
