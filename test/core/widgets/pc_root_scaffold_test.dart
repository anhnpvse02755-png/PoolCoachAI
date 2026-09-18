import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';

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
}
