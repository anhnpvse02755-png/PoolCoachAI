import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/coach/coach_stats.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/coach/presentation/coach_chat_screen.dart';
import 'package:poolcoachai/features/coach/presentation/coach_screen.dart';

import '../../support/coach_fixtures.dart';
import '../../support/fake_coach_chat.dart';
import '../../support/route_cases.dart';
import '../../support/test_data.dart';

/// Người chơi yếu đúng nhóm [weak] trên bộ bài tập seed (cùng cách dựng với
/// no_fabrication_test): tập kém nhóm đó, tốt các nhóm khác.
List<DrillLog> weakAt(SkillCategory weak) {
  final logs = <DrillLog>[];
  var n = 0;
  for (final d in seedDrills) {
    if (!d.usesAttempts) continue;
    for (var i = 0; i < 3; i++) {
      n++;
      logs.add(DrillLog(
        id: 'l$n',
        drillId: d.id,
        date: testToday.subtract(Duration(days: 2 - i)),
        score: d.cat == weak ? 2 : 10,
        attempts: 10,
      ));
    }
  }
  return logs;
}

void main() {
  Future<void> open(
    WidgetTester tester, {
    List<DrillLog>? logs,
    List<CoachAttempt>? attempts,
    Size viewportSize = const Size(900, 2000),
    AsyncValue<CoachContext>? coachContext,
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = testContainer(
      drills: seedDrills,
      logs: logs,
      coachAttempts: attempts,
      coachContext: coachContext,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CoachScreen()),
    ));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, Key key) => tester.widget<ChoiceChip>(find.byKey(key)).selected;

  testWidgets('thẻ gợi ý hiện đúng số liệu Coach: chưa đủ dữ liệu rồi giải k/n và lỗi lặp lại',
      (tester) async {
    await open(tester, attempts: [attempt(CoachAttemptOutcome.solved1, topic: CoachTopic.aiming)]);
    expect(find.text(Vi.coachRecTitle), findsOneWidget);
    expect(find.text(Vi.coachRecNotEnough(1, coachStatsMin)), findsOneWidget);
  });

  testWidgets('đủ lần làm: giải k/n và lỗi lặp lại kèm công cụ', (tester) async {
    final attempts = [
      for (var i = 0; i < coachStatsMin; i++)
        attempt(
          i == 0 ? CoachAttemptOutcome.solved2 : CoachAttemptOutcome.revealed,
          topic: CoachTopic.aiming,
          fault: CoachFault.pocketWorse,
          minute: i,
        ),
    ];
    await open(tester, attempts: attempts);
    expect(find.text(Vi.coachRecSolved(1, coachStatsMin)), findsOneWidget);
    expect(find.text(Vi.coachRecRecurring(CoachFaultGroup.pocketChoice, coachStatsMin, coachStatsMin)),
        findsOneWidget);
    expect(find.text(Vi.coachRecToolSimulator), findsOneWidget);
  });

  testWidgets('đổi nhóm yếu thì chip nhóm chọn sẵn đổi theo', (tester) async {
    for (final weak in [SkillCategory.position, SkillCategory.safety]) {
      await open(tester, logs: weakAt(weak));
      expect(selected(tester, CoachScreen.topicKey(coachTopicOf(weak)!)), isTrue, reason: '$weak');
    }
  });

  testWidgets('chip độ khó và nhóm chọn được; có lối vào thư viện', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(CoachScreen.topicKey(CoachTopic.kick)));
    await tester.pumpAndSettle();
    expect(selected(tester, CoachScreen.topicKey(CoachTopic.kick)), isTrue);
    expect(find.text(Vi.coachLibraryLink), findsOneWidget);
  });

  testWidgets('thẻ Hỏi huấn luyện viên thay thẻ sắp có', (tester) async {
    await open(tester);
    expect(find.text(Vi.coachChatTitle), findsOneWidget);
    expect(find.text(Vi.coachChatSubtitle), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(CoachScreen.chatSampleKey(i)), findsOneWidget);
    }
    expect(find.byKey(CoachScreen.chatOpenKey), findsOneWidget);
  });

  testWidgets(
    'ba nút câu hỏi mẫu rộng bằng khung nội dung của thẻ ở màn hình rộng, '
    'như mẫu đã dùng ở màn chat (I1, review Task 11 fix round 1, probe R23)',
    (tester) async {
      // Màn hình rộng, thấp (kiểu điện thoại ngang) — đúng kích thước
      // reviewer đo được 372/471/400 px lệch nhau trong thẻ 708 px. Thấp
      // nên thẻ chat nằm ngoài khung nhìn ban đầu — cuộn tới bằng
      // scrollUntilVisible (M2 cùng kỹ thuật) thay vì phồng viewport lên.
      await open(tester, viewportSize: const Size(740, 360));
      await tester.scrollUntilVisible(
        find.byKey(CoachScreen.chatSampleKey(0)),
        50,
        scrollable: find.descendant(of: find.byType(CoachScreen), matching: find.byType(Scrollable)),
      );

      final cardFinder = find.ancestor(
        of: find.byKey(CoachScreen.chatSampleKey(0)),
        matching: find.byType(PcCard),
      );
      final cardWidth = tester.getSize(cardFinder).width;
      final expectedWidth = cardWidth - 2 * AppSpacing.md;

      for (var i = 0; i < 3; i++) {
        final sampleWidth = tester.getSize(find.byKey(CoachScreen.chatSampleKey(i))).width;
        expect(sampleWidth, closeTo(expectedWidth, 0.5), reason: 'sample $i phải rộng bằng khung nội dung của thẻ');
      }
    },
  );

  testWidgets(
    'ngữ cảnh đang tải (coachContextProvider = AsyncLoading): ba nút câu hỏi '
    'mẫu bị khoá (M3, review Task 11 fix round 1)',
    (tester) async {
      await open(tester, coachContext: const AsyncLoading());
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(CoachScreen.chatSampleKey(i))).onPressed,
          isNull,
          reason: 'sample $i phải bị khoá khi ngữ cảnh chưa sẵn sàng',
        );
      }
    },
  );

  testWidgets(
    'ngữ cảnh lỗi (coachContextProvider = AsyncError): ba nút câu hỏi mẫu bị '
    'khoá (M3, review Task 11 fix round 1)',
    (tester) async {
      await open(
        tester,
        coachContext: AsyncError(Exception('ngữ cảnh lỗi giả (M3)'), StackTrace.empty),
      );
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(CoachScreen.chatSampleKey(i))).onPressed,
          isNull,
          reason: 'sample $i phải bị khoá khi ngữ cảnh lỗi',
        );
      }
    },
  );

  testWidgets('bấm câu hỏi mẫu: mở màn chat và gửi đúng câu đó', (tester) async {
    final chat = FakeCoachChat();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final router = await pumpRoutedApp(
      tester,
      container: testContainer(
        coachChat: chat,
        coachChatRepo: CoachChatRepository(db, userId: 'u1'),
      ),
    );
    router.go(Routes.coach);
    await tester.pumpAndSettle();
    // Viewport mặc định (800×600): thẻ chat nằm dưới khung nhìn của
    // CoachScreen, nên `skipOffstage` (mặc định của mọi Finder) chưa thấy
    // nó. `scrollUntilVisible` kéo `Scrollable` của CoachScreen tới khi thẻ
    // lộ ra, rồi tự gọi `Scrollable.ensureVisible` để nhảy thẻ vào hẳn khung
    // nhìn — nhưng sau cú nhảy cuối đó nó KHÔNG pump frame nào: bố cục vẫn
    // là bố cục cũ, `tap()` tính tâm thẻ ở (400, 699), ngoài Size(800, 600),
    // và chạm hụt. `pumpAndSettle` dựng frame sau cú nhảy, nên `tap()` chạm
    // đúng chỗ thẻ đang nằm. Gọi thêm `ensureVisible` không giúp gì: nó cũng
    // chỉ nhảy, không pump (M2, review Task 11 fix round 1; M9, review cuối).
    await tester.scrollUntilVisible(
      find.byKey(CoachScreen.chatSampleKey(1)),
      50,
      scrollable: find.descendant(of: find.byType(CoachScreen), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CoachScreen.chatSampleKey(1)));
    await tester.pumpAndSettle();
    expect(find.byType(CoachChatScreen), findsOneWidget);
    expect(chat.asked.single.question, Vi.coachChatSamples[1]);
  });

  testWidgets('Mở trò chuyện: mở màn chat, không gửi gì', (tester) async {
    final chat = FakeCoachChat();
    final router = await pumpRoutedApp(tester, container: testContainer(coachChat: chat));
    router.go(Routes.coach);
    await tester.pumpAndSettle();
    // Xem giải thích ở test "bấm câu hỏi mẫu" ngay trên (M2, review Task 11
    // fix round 1, probe A) — cùng kỹ thuật, viewport mặc định.
    await tester.scrollUntilVisible(
      find.byKey(CoachScreen.chatOpenKey),
      50,
      scrollable: find.descendant(of: find.byType(CoachScreen), matching: find.byType(Scrollable)),
    );
    await tester.ensureVisible(find.byKey(CoachScreen.chatOpenKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CoachScreen.chatOpenKey));
    await tester.pumpAndSettle();
    expect(find.byType(CoachChatScreen), findsOneWidget);
    expect(chat.asked, isEmpty);
  });
}
