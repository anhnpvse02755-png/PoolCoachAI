import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';

void main() {
  group('PcCard', () {
    testWidgets('hiển thị nội dung con', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcCard(child: Text('Nội dung')),
          ),
        ),
      );

      expect(find.text('Nội dung'), findsOneWidget);
    });

    testWidgets('dùng màu nền surface của hệ thiết kế', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcCard(child: Text('Nội dung')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PcCard),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surface);
    });

    testWidgets('gọi onTap khi được bấm', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcCard(
              onTap: () => tapped = true,
              child: const Text('Nội dung'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PcCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
