import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';
import 'package:poolcoachai/features/training/presentation/drill_detail_screen.dart';

import '../../support/test_data.dart';

void main() {
  /// Mở app rồi đi tới [path], trả router để test tự dọn.
  Future<void> openAt(WidgetTester tester, String path) async {
    final router = createAppRouter();
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);

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

  // Mục 6.5 của thiết kế: TodayRecommendation.article đã có sẵn tên
  // bài đọc từ lâu. Hiện tên mà bấm vào không ra gì còn tệ hơn không
  // hiện — màn này là thứ đóng lại chỗ hở đó.
  group('màn đọc kiến thức', () {
    testWidgets('hiện tiêu đề và thân bài của đúng bài theo id',
        (tester) async {
      await openAt(tester, Routes.article('k1'));

      expect(find.byType(KnowledgeScreen), findsOneWidget);
      expect(find.text('Nguyên lý bi ảo'), findsOneWidget);
      expect(find.text('Thân bài kiến thức về bi ảo.'), findsOneWidget);
    });

    testWidgets('hiện nhóm kỹ năng của bài đọc', (tester) async {
      await openAt(tester, Routes.article('k2'));

      expect(find.text(Vi.skill(testKnowledge[1].cat)), findsOneWidget);
    });

    testWidgets('có bài tập liên quan thì hiện tên bài tập đó',
        (tester) async {
      await openAt(tester, Routes.article('k1'));

      expect(find.text(Vi.knowledgeRelatedTitle), findsOneWidget);
      expect(find.text('Đường thẳng cơ bản'), findsOneWidget);
    });

    testWidgets('không có bài tập liên quan thì ẩn hẳn khối liên quan',
        (tester) async {
      await openAt(tester, Routes.article('k2'));

      expect(find.text(Vi.knowledgeRelatedTitle), findsNothing);
    });

    testWidgets('bấm bài tập liên quan thì sang chi tiết bài đó',
        (tester) async {
      await openAt(tester, Routes.article('k1'));

      await tester.tap(find.text('Đường thẳng cơ bản'));
      await tester.pumpAndSettle();

      expect(find.byType(DrillDetailScreen), findsOneWidget);
    });

    testWidgets('id không tồn tại thì ra trạng thái rỗng, không màn trắng',
        (tester) async {
      await openAt(tester, Routes.article('khong-co-that'));

      expect(find.byType(PcEmptyState), findsOneWidget);
      expect(find.text(Vi.notFoundTitle), findsOneWidget);
    });
  });
}
