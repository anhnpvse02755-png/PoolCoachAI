import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';

void main() {
  testWidgets('PcEmptyState hiển thị icon, tiêu đề và nội dung', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PcEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Chưa có chứng nhận nào',
            body: 'Hoàn thành Kiểm tra kỹ năng để nhận chứng nhận đầu tiên.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    expect(find.text('Chưa có chứng nhận nào'), findsOneWidget);
    expect(
      find.text('Hoàn thành Kiểm tra kỹ năng để nhận chứng nhận đầu tiên.'),
      findsOneWidget,
    );
  });

  testWidgets('PcEmptyState dựng nút hành động khi được truyền vào',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PcEmptyState(
            icon: Icons.help_outline,
            title: 'Không tìm thấy',
            body: 'Đường dẫn này không tồn tại.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('Về trang chủ'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Về trang chủ'), findsOneWidget);
  });

  testWidgets('PcEmptyState không có nút thì không chừa chỗ trống cho nó',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PcEmptyState(
            icon: Icons.help_outline,
            title: 'Không tìm thấy',
            body: 'Đường dẫn này không tồn tại.',
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
