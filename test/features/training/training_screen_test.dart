import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/drill_log.dart';

import '../../support/test_data.dart';

/// Thư viện bài tập — mục 6.2 của thiết kế.
///
/// Mỗi dòng hiện tỉ lệ đạt của **lần tập gần nhất**. Tỉ lệ là số do
/// [drillRatio] tính ra, không phải điểm thô người chơi nhập: bài d1
/// đạt khi trúng 8 trên 10, nên trúng 9 là 113% mục tiêu chứ không
/// phải "9.0". Hiện điểm thô dưới nhãn tỉ lệ là con số không truy được
/// về logic nào — đúng thứ mục 2.1 của thiết kế cấm.
void main() {
  Future<void> openTraining(WidgetTester tester, List<DrillLog> logs) async {
    final router = createAppRouter();
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
    router.go(Routes.training);
    await tester.pumpAndSettle();
  }

  DrillLog log({
    required String id,
    required DateTime date,
    required num score,
    int? attempts = 10,
  }) =>
      DrillLog(
        id: id,
        drillId: 'd1',
        date: date,
        score: score,
        attempts: attempts,
      );

  testWidgets('bài chưa từng tập thì không hiện con số nào', (tester) async {
    await openTraining(tester, const []);

    expect(find.textContaining('%'), findsNothing);
    expect(find.text(Vi.drillRatioUnknown), findsNothing);
  });

  testWidgets('đã tập thì hiện tỉ lệ đạt mục tiêu, không phải điểm thô',
      (tester) async {
    await openTraining(tester, [
      log(id: 'l1', date: DateTime(2026, 9, 20), score: 9),
    ]);

    // d1 đạt khi trúng 8 trên 10 → trúng 9 là 1.125 lần mục tiêu.
    expect(find.text('113%'), findsOneWidget);
    expect(find.text('9.0'), findsNothing);
  });

  testWidgets('lấy lần tập gần nhất, không phải lần tập đầu tiên',
      (tester) async {
    await openTraining(tester, [
      log(id: 'cu', date: DateTime(2026, 9, 18), score: 4),
      log(id: 'moi', date: DateTime(2026, 9, 21), score: 8),
    ]);

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('50%'), findsNothing);
  });

  testWidgets('thiếu số lần thử thì nói chưa chấm được, không quy về 0',
      (tester) async {
    await openTraining(tester, [
      log(id: 'thieu', date: DateTime(2026, 9, 20), score: 9, attempts: null),
    ]);

    expect(find.text(Vi.drillRatioUnknown), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
}
