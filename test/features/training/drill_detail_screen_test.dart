import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/features/training/presentation/drill_session_screen.dart';

import '../../support/test_data.dart';

/// Chi tiết một bài tập — mục 6.3 của thiết kế.
void main() {
  Future<void> openDrill(
    WidgetTester tester,
    String drillId, {
    List<DrillLog> logs = const [],
  }) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer(logs: logs);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.drill(drillId));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện mục tiêu, đơn vị và các bước của bài', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text('Đánh thẳng bi cái.'), findsOneWidget);
    expect(find.text(Vi.drillUnitLabel('lần trúng / 10')), findsOneWidget);
    expect(find.text(Vi.drillStepsTitle), findsOneWidget);
    expect(find.text('Bước 1'), findsOneWidget);
    expect(find.text('Bước 2'), findsOneWidget);
  });

  testWidgets('hiện cấp của bài', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text(Vi.drillLevel(1)), findsOneWidget);
  });

  testWidgets('chưa tập lần nào thì không hiện khối lịch sử', (tester) async {
    await openDrill(tester, 'd1');

    expect(find.text(Vi.drillHistoryTitle), findsNothing);
  });

  testWidgets('đã tập thì lịch sử hiện tỉ lệ đạt, không phải điểm thô',
      (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        DrillLog(
          id: 'l1',
          drillId: 'd1',
          date: DateTime(2026, 9, 20),
          score: 9,
          attempts: 10,
        ),
      ],
    );

    expect(find.text(Vi.drillHistoryTitle), findsOneWidget);
    expect(find.text('113%'), findsOneWidget);
    expect(find.text(Vi.shortDate(DateTime(2026, 9, 20))), findsOneWidget);
  });

  testWidgets('buổi thiếu dữ liệu chấm thì nói chưa chấm được', (tester) async {
    await openDrill(
      tester,
      'd1',
      logs: [
        DrillLog(
          id: 'l1',
          drillId: 'd1',
          date: DateTime(2026, 9, 20),
          score: 9,
        ),
      ],
    );

    expect(find.text(Vi.drillRatioUnknown), findsOneWidget);
  });

  testWidgets('bấm bắt đầu tập thì sang màn buổi tập của đúng bài đó',
      (tester) async {
    await openDrill(tester, 'd1');

    await tester.tap(find.text(Vi.drillStartAction));
    await tester.pumpAndSettle();

    expect(find.byType(DrillSessionScreen), findsOneWidget);
    expect(find.text(Vi.sessionTitle('Đường thẳng cơ bản')), findsOneWidget);
  });

  testWidgets('id không tồn tại thì ra trạng thái rỗng, không màn trắng',
      (tester) async {
    await openDrill(tester, 'khong-co-that');

    expect(find.byType(PcEmptyState), findsOneWidget);
    expect(find.text(Vi.notFoundTitle), findsOneWidget);
  });
}
