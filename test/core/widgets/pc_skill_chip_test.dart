import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_skill_chip.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  group('PcSkillChip', () {
    testWidgets('hiện tên tiếng Việt của nhóm kỹ năng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcSkillChip(category: SkillCategory.kick),
          ),
        ),
      );

      expect(find.text('A băng'), findsOneWidget);
    });

    testWidgets('dùng màu riêng của từng nhóm', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcSkillChip(category: SkillCategory.breakShot),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PcSkillChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, SkillCategory.breakShot.bg);
    });

    testWidgets('dựng được cả 5 nhóm không lỗi', (tester) async {
      for (final category in SkillCategory.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PcSkillChip(category: category)),
          ),
        );
        expect(find.byType(PcSkillChip), findsOneWidget);
      }
    });
  });
}
