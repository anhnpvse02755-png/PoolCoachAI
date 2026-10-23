import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
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
  Future<void> open(WidgetTester tester, {List<DrillLog>? logs, List<CoachAttempt>? attempts}) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = testContainer(drills: seedDrills, logs: logs, coachAttempts: attempts);
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

  testWidgets('bấm câu hỏi mẫu: mở màn chat và gửi đúng câu đó', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.ensureVisible(find.byKey(CoachScreen.chatSampleKey(1)));
    await tester.tap(find.byKey(CoachScreen.chatSampleKey(1)));
    await tester.pumpAndSettle();
    expect(find.byType(CoachChatScreen), findsOneWidget);
    expect(chat.asked.single.question, Vi.coachChatSamples[1]);
  });

  testWidgets('Mở trò chuyện: mở màn chat, không gửi gì', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = FakeCoachChat();
    final router = await pumpRoutedApp(tester, container: testContainer(coachChat: chat));
    router.go(Routes.coach);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(CoachScreen.chatOpenKey));
    await tester.tap(find.byKey(CoachScreen.chatOpenKey));
    await tester.pumpAndSettle();
    expect(find.byType(CoachChatScreen), findsOneWidget);
    expect(chat.asked, isEmpty);
  });
}
