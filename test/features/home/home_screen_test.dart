import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/knowledge/presentation/knowledge_screen.dart';

import '../../support/test_data.dart';

/// AI Home — mục 6.1 của thiết kế.
void main() {
  Future<void> openHome(
    WidgetTester tester, {
    List<Drill>? drills,
    List<KnowledgeArticle>? knowledge,
    List<DrillLog>? logs,
  }) async {
    final router = createAppRouter();
    addTearDown(router.dispose);
    final container = testContainer(
      drills: drills,
      knowledge: knowledge,
      logs: logs,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa tập buổi nào thì chuỗi ngày tập là 0, hiện bình thường',
      (tester) async {
    await openHome(tester);

    expect(find.text('0'), findsOneWidget);
    expect(find.text(Vi.homeStreakUnit), findsOneWidget);
  });

  testWidgets('hiện câu lý do của nhóm được chọn, không nuốt lý do',
      (tester) async {
    await openHome(tester);

    expect(
      find.text(Vi.pickReason(
        PickReason.newcomer,
        Vi.skill(SkillCategory.aiming),
      )),
      findsOneWidget,
    );
  });

  testWidgets('có bài gợi ý thì hiện tên bài và nút mở', (tester) async {
    await openHome(tester);

    expect(find.text(Vi.homeDrillTitle), findsOneWidget);
    expect(find.text('Đường thẳng cơ bản'), findsOneWidget);
    expect(find.text(Vi.homeDrillOpen), findsOneWidget);
  });

  testWidgets('hết bài trong nhóm thì nói hết bài, không mượn bài nhóm khác',
      (tester) async {
    await openHome(tester, drills: const []);

    expect(find.text(Vi.homeDrillAllDone), findsOneWidget);
    expect(find.text(Vi.homeDrillTitle), findsNothing);
  });

  testWidgets('không có bài đọc thì ẩn hẳn khối bài đọc', (tester) async {
    await openHome(tester, knowledge: const []);

    expect(find.text(Vi.homeArticleTitle), findsNothing);
  });

  testWidgets('bấm bài đọc thì mở đúng màn đọc kiến thức', (tester) async {
    await openHome(tester);

    expect(find.text(Vi.homeArticleTitle), findsOneWidget);
    await tester.tap(find.text('Nguyên lý bi ảo'));
    await tester.pumpAndSettle();

    expect(find.byType(KnowledgeScreen), findsOneWidget);
  });
}
