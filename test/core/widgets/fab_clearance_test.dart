import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';

import '../../support/layout_sweep.dart';
import '../../support/rich_data.dart';
import '../../support/route_cases.dart';

/// Nút Coach nổi không được che cuối nội dung cuộn của bất kỳ màn nào trong
/// shell: cuộn hết thì mọi chữ nằm ngoài hình chữ nhật của nút.
void main() {
  const size = Size(360, 640);

  final cases = <String, String>{
    'Home': Routes.home,
    'Lộ trình': Routes.roadmap,
    'chi tiết giải đấu': '/play/tournaments/t1',
    'chi tiết bài tập': '/training/drills/d1',
    'Skill Test': '/training/skill-test/d1',
  };

  for (final scale in [1.0, 1.5]) {
    for (final entry in cases.entries) {
      testWidgets('${entry.key} x$scale: cuộn hết thì chữ không dưới nút Coach',
          (tester) async {
        applyScreen(tester, size, textScale: scale);
        final router = await pumpRoutedApp(tester, container: richContainer());
        router.go(entry.value);
        await tester.pumpAndSettle();

        final fab = tester.getRect(find.byType(FloatingActionButton));
        // Mọi danh sách dọc cuộn hết cỡ. ListView ước lượng chiều dài theo
        // hàng đã dựng, nên cuộn lặp tới khi cực đại không đổi nữa.
        for (var round = 0; round < 6; round++) {
          for (final state in tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          )) {
            if (axisDirectionToAxis(state.axisDirection) != Axis.vertical) {
              continue;
            }
            state.position.jumpTo(state.position.maxScrollExtent);
          }
          await tester.pumpAndSettle();
        }

        final offenders = <String>[];
        for (final element in find.byType(Text).evaluate()) {
          final box = element.renderObject! as RenderBox;
          if (!box.attached || !box.hasSize) continue;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.overlaps(fab) && rect.bottom <= size.height) {
            offenders.add('${(element.widget as Text).data} $rect');
          }
        }
        expect(offenders, isEmpty, reason: 'chữ nằm dưới nút Coach $fab');
      });
    }
  }
}
