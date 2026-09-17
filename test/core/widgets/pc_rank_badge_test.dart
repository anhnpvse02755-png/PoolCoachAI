import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('PcRankBadge', () {
    testWidgets('mặc định chỉ hiện chữ cái hạng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PcRankBadge(rank: Rank.g)),
        ),
      );

      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('showWord hiện thêm chữ "HẠNG"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PcRankBadge(rank: Rank.g, showWord: true)),
        ),
      );

      expect(find.text('HẠNG G'), findsOneWidget);
    });

    testWidgets('hạng phong trào và hạng cạnh tranh khác màu', (tester) async {
      Color backgroundOf(WidgetTester t) {
        final container = t.widget<Container>(
          find.descendant(
            of: find.byType(PcRankBadge),
            matching: find.byType(Container),
          ).first,
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PcRankBadge(rank: Rank.g))),
      );
      final amateur = backgroundOf(tester);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PcRankBadge(rank: Rank.f))),
      );
      final competitive = backgroundOf(tester);

      expect(amateur, isNot(competitive));
    });

    testWidgets('dựng được cả 11 hạng không lỗi', (tester) async {
      for (final rank in Rank.values) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PcRankBadge(rank: rank))),
        );
        expect(find.byType(PcRankBadge), findsOneWidget);
      }
    });
  });
}
