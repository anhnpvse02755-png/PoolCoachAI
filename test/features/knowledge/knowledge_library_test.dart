import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_library_screen.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';

import '../../support/test_data.dart';

void main() {
  Future<void> openAt(WidgetTester tester, String path) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(path);
    await tester.pumpAndSettle();
  }

  testWidgets('liệt kê mọi bài, gom theo nhóm kỹ năng', (tester) async {
    await openAt(tester, Routes.knowledge);

    expect(find.byType(KnowledgeLibraryScreen), findsOneWidget);
    expect(find.text('Nguyên lý bi ảo'), findsOneWidget);
    expect(find.text('Cân bi một băng'), findsOneWidget);
    expect(find.text(Vi.skill(testKnowledge[0].cat)), findsWidgets);
    expect(find.text(Vi.skill(testKnowledge[1].cat)), findsWidgets);
  });

  testWidgets('bấm một bài thì mở bài đó', (tester) async {
    await openAt(tester, Routes.knowledge);
    await tester.tap(find.text('Cân bi một băng'));
    await tester.pumpAndSettle();

    expect(find.byType(KnowledgeScreen), findsOneWidget);
    expect(find.text('Thân bài kiến thức về cân bi.'), findsOneWidget);
  });

  testWidgets('Luyện tập có mục Kiến thức dẫn tới thư viện', (tester) async {
    await openAt(tester, Routes.training);
    await tester.tap(find.text(Vi.knowledgeLibraryTitle));
    await tester.pumpAndSettle();
    expect(find.byType(KnowledgeLibraryScreen), findsOneWidget);
  });

  testWidgets('Trang chủ có thẻ Kiến thức dẫn tới thư viện', (tester) async {
    await openAt(tester, Routes.home);
    await tester.tap(find.text(Vi.knowledgeLibraryTitle));
    await tester.pumpAndSettle();
    expect(find.byType(KnowledgeLibraryScreen), findsOneWidget);
  });

  group('bài tập → bài đọc', () {
    testWidgets('chi tiết bài tập liệt kê bài đọc tham chiếu nó', (
      tester,
    ) async {
      await openAt(tester, Routes.drill('d1'));

      expect(find.text(Vi.drillReadArticles), findsOneWidget);
      expect(find.text('Nguyên lý bi ảo'), findsOneWidget);
      expect(find.text('Cân bi một băng'), findsNothing);
    });

    testWidgets('bấm thì mở bài đọc', (tester) async {
      await openAt(tester, Routes.drill('d1'));
      await tester.ensureVisible(find.text('Nguyên lý bi ảo'));
      await tester.tap(find.text('Nguyên lý bi ảo'));
      await tester.pumpAndSettle();
      expect(find.byType(KnowledgeScreen), findsOneWidget);
      expect(find.byType(DrillDetailScreen), findsNothing);
    });
  });
}
