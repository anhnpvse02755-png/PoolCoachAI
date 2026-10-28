import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/features/rank/presentation/layout_gallery_screen.dart';

/// Thư viện sơ đồ BU lọc theo bài + bậc (Task 7).
void main() {
  Future<void> open(
    WidgetTester tester, {
    String? drillId,
    ExamIIVersion? version,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: LayoutGalleryScreen(drillId: drillId, version: version)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S8 Masters: đánh số 1/n…n/n theo layoutsFor', (tester) async {
    final n = layoutsFor('S8', ExamIIVersion.masters).length;
    await open(tester, drillId: 'S8', version: ExamIIVersion.masters);
    for (var k = 1; k <= n; k++) {
      await tester.dragUntilVisible(
        find.textContaining('Sơ đồ $k / $n'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.textContaining('Sơ đồ $k / $n'), findsOneWidget);
    }
    expect(find.textContaining('/ ${n + 1}'), findsNothing);
  });

  testWidgets('S9 Doctorate: số sơ đồ theo layoutsFor', (tester) async {
    final n = layoutsFor('S9', ExamIIVersion.doctorate).length;
    await open(tester, drillId: 'S9', version: ExamIIVersion.doctorate);
    expect(find.textContaining('Sơ đồ 1 / $n'), findsOneWidget);
    expect(find.textContaining('/ ${n + 1}'), findsNothing);
  });

  testWidgets('bậc lạ hoặc bài lạ: Hết sơ đồ.', (tester) async {
    await open(tester, drillId: 'S8');
    expect(find.text(Vi.buLayoutsEnd), findsOneWidget);
    await open(tester, drillId: 'X1', version: ExamIIVersion.masters);
    expect(find.text(Vi.buLayoutsEnd), findsOneWidget);
  });
}
