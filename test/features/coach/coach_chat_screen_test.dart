import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/features/coach/presentation/coach_chat_screen.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/fake_coach_chat.dart';
import '../../support/route_cases.dart';
import '../../support/test_data.dart';

/// Giờ mẫu cho mọi lượt chat dựng tay trong file này.
final t0 = DateTime(2026, 10, 22, 9);

/// Câu hỏi/trả lời dài cho lượt quét chiều ngang + bàn phím + chữ lớn —
/// bong bóng phải co giãn thật, không chỉ màn trống.
const _sweepQuestion =
    'Tuần này tôi tập Ngắm bi và Vị trí đều đặn mỗi tối, nhưng trận vừa rồi '
    'vẫn thua liên tiếp ba rack vì hỏng bi cắt mỏng và không giữ được vị trí '
    'cho cú kế tiếp, vậy tôi nên đổi cách tập thế nào cho tuần sau?';
const _sweepAnswer =
    'Theo số liệu bạn ghi lại, nhóm Ngắm bi của bạn đạt 7 trên 10 lần gần '
    'nhất còn nhóm Vị trí chỉ đạt 4 trên 10, nên phần hỏng vị trí đang kéo '
    'điểm xuống nhiều hơn phần ngắm bi. Trận vừa rồi cả ba rack thua đều có '
    'ít nhất một cú hỏng vị trí ngay trước cú hỏng bi cuối cùng. Tuần sau '
    'nên ưu tiên bài tập Vị trí thêm hai buổi, giữ nguyên lịch Ngắm bi đang '
    'có, và ghi lại từng buổi để tuần sau nữa so sánh được số liệu thật.';

/// DB riêng + repository của `u1`, dọn sau mỗi test.
CoachChatRepository newRepo() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return CoachChatRepository(db, userId: 'u1');
}

/// Dựng app, mở `/coach/chat`. [turnsAsync] (khi có) ghi đè thẳng
/// `coachChatTurnsProvider` bằng một `AsyncValue` dựng tay — dùng cho test
/// trạng thái "đang tải lại" mà một `Stream` bình thường không dựng được.
Future<GoRouter> openChat(
  WidgetTester tester, {
  required CoachChatRepository repo,
  FakeCoachChat? chat,
  AsyncValue<CoachContext>? coachContext,
  AsyncValue<List<CoachChatEntry>>? turnsAsync,
}) async {
  final router = await pumpRoutedApp(
    tester,
    container: testContainer(
      coachChat: chat,
      coachChatRepo: repo,
      coachContext: coachContext ?? AsyncData(fullCoachContext()),
      coachChatTurnsAsync: turnsAsync,
    ),
  );
  router.go(Routes.coachChat);
  await tester.pumpAndSettle();
  return router;
}

/// Gõ [text] vào ô nhập rồi bấm Gửi; dừng lại một khung hình sau khi bấm,
/// để gọi còn thấy trạng thái "đang gửi" nếu cần — gọi `pumpAndSettle()`
/// riêng khi cần trạng thái cuối.
Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(CoachChatScreen.inputKey), text);
  await tester.pump();
  await tester.tap(find.byKey(CoachChatScreen.sendKey));
  await tester.pump();
}

void main() {
  testWidgets('màn trống hiện ba câu mẫu và lời miễn trừ trách nhiệm, chưa xoá được gì', (
    tester,
  ) async {
    await openChat(tester, repo: newRepo());

    for (final sample in Vi.coachChatSamples) {
      expect(find.text(sample), findsOneWidget);
    }
    expect(find.text(Vi.coachChatDisclaimer), findsOneWidget);
    // FakeCoachChat() mặc định còn 30 lượt; loadQuota() gọi từ initState
    // phải tới đích và hiện ra ở helperText trước khi test này đọc màn.
    expect(find.text(Vi.coachChatRemaining(30)), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(CoachChatScreen.clearKey)).onPressed,
      isNull,
    );
  });

  testWidgets('bấm một câu mẫu gửi đúng câu đó', (tester) async {
    final chat = FakeCoachChat();
    await openChat(tester, repo: newRepo(), chat: chat);

    await tester.tap(find.byKey(CoachChatScreen.sampleKey(0)));
    await tester.pumpAndSettle();

    expect(chat.asked.single.question, Vi.coachChatSamples[0]);
    expect(find.text(Vi.coachChatSamples[0]), findsOneWidget);
    expect(find.text(chat.replyText), findsOneWidget);
  });

  testWidgets(
    'gõ câu hỏi rồi bấm Gửi: ô nhập xoá ngay, hiện bong bóng câu hỏi và '
    '"đang trả lời", rồi hiện câu trả lời khi xong',
    (tester) async {
      final repo = newRepo();
      final chat = FakeCoachChat()..hold = Completer<void>();
      await openChat(tester, repo: repo, chat: chat);

      await typeAndSend(tester, 'Hôm nay tôi nên tập gì cho đúng?');

      expect(
        tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).controller!.text,
        isEmpty,
      );
      expect(find.text('Hôm nay tôi nên tập gì cho đúng?'), findsOneWidget);
      expect(find.text(Vi.coachChatThinking), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
        isFalse,
      );

      chat.hold!.complete();
      await tester.pumpAndSettle();

      expect(find.text(Vi.coachChatThinking), findsNothing);
      expect(find.text(chat.replyText), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
        isTrue,
      );
      // FakeCoachChat bắt đầu ở 30, trừ 1 sau một câu trả lời — số hiện ra
      // phải theo đúng `answer.remainingToday`, không phải số tải trước đó.
      expect(find.text(Vi.coachChatRemaining(29)), findsOneWidget);
      expect(
        (await repo.recentTurns(10)).map((e) => e.fromPlayer),
        [true, false],
      );
    },
  );

  testWidgets('bấm Gửi hai lần liên tiếp không rời khung hình chỉ gửi một lần (ruling)', (
    tester,
  ) async {
    final chat = FakeCoachChat()..hold = Completer<void>();
    await openChat(tester, repo: newRepo(), chat: chat);

    await tester.enterText(find.byKey(CoachChatScreen.inputKey), 'câu hỏi mẫu');
    await tester.pump();
    await tester.tap(find.byKey(CoachChatScreen.sendKey));
    await tester.tap(find.byKey(CoachChatScreen.sendKey));

    expect(chat.asked, hasLength(1));

    chat.hold!.complete();
    await tester.pumpAndSettle();

    expect(chat.asked, hasLength(1));
  });

  testWidgets('câu trả lời bị chặn hiện đúng câu chưa đủ dữ liệu và gợi ý ghi thêm', (
    tester,
  ) async {
    final repo = newRepo();
    final chat = FakeCoachChat()..nextInsufficient = true;
    await openChat(tester, repo: repo, chat: chat);

    await typeAndSend(tester, 'Tôi hợp cơ nào nhất?');
    await tester.pumpAndSettle();

    expect(find.text(Vi.coachChatInsufficient), findsOneWidget);
    expect(find.text(Vi.coachChatInsufficientHint), findsOneWidget);
    expect((await repo.recentTurns(1)).single.insufficient, isTrue);
  });

  testWidgets('hết lượt ngay khi câu đang hỏi: còn 0, ô nhập bị khoá, không có Thử lại', (
    tester,
  ) async {
    final chat = FakeCoachChat()..nextError = CoachChatQuotaExceeded(DateTime(2026, 10, 24));
    await openChat(tester, repo: newRepo(), chat: chat);

    await typeAndSend(tester, 'Câu hỏi khi hết lượt');
    await tester.pumpAndSettle();

    expect(find.text(Vi.coachChatQuotaOut), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
      isFalse,
    );
    expect(find.byKey(CoachChatScreen.retryKey), findsNothing);
  });

  testWidgets('mở màn khi đã hết lượt từ trước: ô nhập khoá ngay, không cần hỏi', (
    tester,
  ) async {
    final chat = FakeCoachChat(remaining: 0);
    await openChat(tester, repo: newRepo(), chat: chat);

    expect(find.text(Vi.coachChatQuotaOut), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
      isFalse,
    );

    // Hết lượt từ trước: câu hỏi mẫu vẫn hiện (chưa có lượt nào) nhưng bấm
    // vào không được gửi gì — chốt chặn `remaining == 0` trong `send()`.
    await tester.tap(find.byKey(CoachChatScreen.sampleKey(0)));
    await tester.pumpAndSettle();
    expect(chat.asked, isEmpty);
  });

  testWidgets(
    'gửi hỏng vì lỗi khác (vd. truncated) hiện câu lỗi chung, không in lỗi thật; '
    'Thử lại gửi lại đúng câu đó',
    (tester) async {
      final chat = FakeCoachChat()..nextError = const CoachChatUnavailable('truncated');
      await openChat(tester, repo: newRepo(), chat: chat);

      await typeAndSend(tester, 'Câu hỏi bị lỗi mạng');
      await tester.pumpAndSettle();

      expect(find.text(Vi.coachChatError), findsOneWidget);
      expect(find.text('truncated'), findsNothing);
      expect(find.text('Câu hỏi bị lỗi mạng'), findsOneWidget);
      expect(chat.asked, hasLength(1));

      await tester.tap(find.byKey(CoachChatScreen.retryKey));
      await tester.pumpAndSettle();

      expect(chat.asked, hasLength(2));
      expect(chat.asked.last.question, 'Câu hỏi bị lỗi mạng');
      expect(find.text(chat.replyText), findsOneWidget);
      expect(find.text(Vi.coachChatError), findsNothing);
    },
  );

  testWidgets(
    'phiên hết hạn khi đang gửi: không hiện lỗi, hết chờ, ô nhập dùng lại được',
    (tester) async {
      final chat = FakeCoachChat()..nextError = AuthFailure.sessionExpired;
      await openChat(tester, repo: newRepo(), chat: chat);

      await typeAndSend(tester, 'Câu hỏi khi phiên hết hạn');
      await tester.pumpAndSettle();

      expect(find.text(Vi.coachChatError), findsNothing);
      expect(find.byKey(CoachChatScreen.retryKey), findsNothing);
      expect(find.text('Câu hỏi khi phiên hết hạn'), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
        isTrue,
      );
    },
  );

  testWidgets('bấm Xoá cuộc trò chuyện: Huỷ thì còn, Xoá thì mất hết', (tester) async {
    final repo = newRepo();
    await repo.addExchange(
      question: 'Q1',
      askedAt: t0,
      reply: (text: 'A1', insufficient: false),
      answeredAt: t0,
    );
    await openChat(tester, repo: repo);
    expect(find.text('Q1'), findsOneWidget);

    await tester.tap(find.byKey(CoachChatScreen.clearKey));
    await tester.pumpAndSettle();
    expect(find.text(Vi.coachChatClearBody), findsOneWidget);

    await tester.tap(find.text(Vi.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Q1'), findsOneWidget);

    await tester.tap(find.byKey(CoachChatScreen.clearKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.coachChatClearYes));
    await tester.pumpAndSettle();

    expect(find.text('Q1'), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(CoachChatScreen.clearKey)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'lịch sử gửi lên là 10 lượt gần nhất, lượt bị chặn gửi đúng câu chưa đủ dữ liệu',
    (tester) async {
      final repo = newRepo();
      for (var i = 0; i < 5; i++) {
        await repo.addExchange(
          question: 'Câu hỏi số $i',
          askedAt: t0.add(Duration(minutes: i * 2)),
          reply: (text: 'Trả lời số $i', insufficient: false),
          answeredAt: t0.add(Duration(minutes: i * 2 + 1)),
        );
      }
      // Lượt thứ 6 bị chặn — message rỗng, insufficient true.
      await repo.addExchange(
        question: 'Câu hỏi số 5',
        askedAt: t0.add(const Duration(minutes: 12)),
        reply: (text: '', insufficient: true),
        answeredAt: t0.add(const Duration(minutes: 13)),
      );
      // 6 cặp = 12 lượt đã lưu, nhiều hơn coachChatHistoryTurns (10).

      final chat = FakeCoachChat();
      await openChat(tester, repo: repo, chat: chat);
      await typeAndSend(tester, 'Câu hỏi mới nhất');
      await tester.pumpAndSettle();

      final sentHistory = chat.asked.single.history;
      expect(sentHistory, hasLength(coachChatHistoryTurns));
      // 2 lượt cũ nhất (Q0, A0) đã bị bỏ, còn lại từ Q1.
      expect(sentHistory.first, (fromPlayer: true, text: 'Câu hỏi số 1'));
      expect(sentHistory[8], (fromPlayer: true, text: 'Câu hỏi số 5'));
      expect(sentHistory.last, (fromPlayer: false, text: Vi.coachChatInsufficient));
    },
  );

  testWidgets('câu hỏi dài hơn 500 ký tự (UTF-16) khoá nút Gửi', (tester) async {
    await openChat(tester, repo: newRepo());

    await tester.enterText(find.byKey(CoachChatScreen.inputKey), 'a' * coachChatMaxQuestion);
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(CoachChatScreen.sendKey)).onPressed,
      isNotNull,
    );

    // Đặt thẳng vào controller, bỏ qua `maxLength` của TextField — kiểm
    // đúng chốt chặn trong `canSend`/`send()`, không phải việc TextField tự
    // cắt chữ.
    final controller = tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).controller!;
    controller.text = 'a' * (coachChatMaxQuestion + 1);
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(CoachChatScreen.sendKey)).onPressed,
      isNull,
    );
  });

  testWidgets('rời màn khi câu trả lời đang chờ vẫn lưu được câu trả lời (R20, giữ sống)', (
    tester,
  ) async {
    final repo = newRepo();
    final chat = FakeCoachChat()..hold = Completer<void>();
    final router = await openChat(tester, repo: repo, chat: chat);

    await typeAndSend(tester, 'Câu hỏi trước khi rời màn');

    router.go(Routes.coach);
    await tester.pumpAndSettle();
    expect(find.byType(CoachChatScreen), findsNothing);

    chat.hold!.complete();
    await tester.pump();
    await tester.pump();

    final saved = await repo.recentTurns(10);
    expect(saved.last.fromPlayer, isFalse);
    expect(saved.last.text, chat.replyText);

    // Mở lại màn chat: câu hỏi và câu trả lời đã lưu phải hiện ra, không
    // còn kẹt ở "đang trả lời" — `coachChatTurnsProvider` đọc thẳng từ DB.
    router.go(Routes.coachChat);
    await tester.pumpAndSettle();
    expect(find.text(chat.replyText), findsOneWidget);
    expect(find.text(Vi.coachChatThinking), findsNothing);
  });

  testWidgets('dòng "đang trả lời" và bong bóng câu trả lời mới là vùng loa (live region)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final chat = FakeCoachChat()..hold = Completer<void>();
    await openChat(tester, repo: newRepo(), chat: chat);

    await typeAndSend(tester, 'Câu hỏi kiểm vùng loa');

    // `bySemanticsLabel` đòi khớp đúng hệt nhãn gộp (label của Semantics
    // bọc ngoài gộp xuống dòng với label mặc định của Text con) — dùng
    // `find.text` rồi để `getSemantics` tự leo lên nút gộp gần nhất thì ổn
    // định hơn, không phụ thuộc cách Flutter gộp nhãn.
    final pending = tester.getSemantics(find.text('Câu hỏi kiểm vùng loa'));
    expect(pending.flagsCollection.isLiveRegion, isTrue);
    final thinking = tester.getSemantics(find.text(Vi.coachChatThinking));
    expect(thinking.flagsCollection.isLiveRegion, isTrue);

    chat.hold!.complete();
    await tester.pumpAndSettle();

    final coachBubble = tester.getSemantics(find.text(chat.replyText));
    expect(coachBubble.flagsCollection.isLiveRegion, isTrue);

    handle.dispose();
  });

  testWidgets('ngữ cảnh lỗi khoá ô nhập và hiện đúng câu lỗi ngữ cảnh', (tester) async {
    await openChat(
      tester,
      repo: newRepo(),
      coachContext: AsyncError(Exception('fx-context-error'), StackTrace.empty),
    );

    expect(find.text(Vi.coachChatContextError), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(CoachChatScreen.inputKey)).enabled,
      isFalse,
    );
  });

  testWidgets(
    'điện thoại ngang, bàn phím mở, chữ lớn: ô nhập và nút Gửi vẫn bấm được, không tràn',
    (tester) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final repo = newRepo();
      await repo.addExchange(
        question: _sweepQuestion,
        askedAt: t0,
        reply: (text: _sweepAnswer, insufficient: false),
        answeredAt: t0,
      );
      await openChat(tester, repo: repo);
      expect(tester.takeException(), isNull);

      // 160 là độ cao bàn phím đã dùng cho đúng cỡ màn 740×360 này ở các
      // màn khác (play/equipment/schedule) — giữ cùng giá trị cho nhất quán.
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(CoachChatScreen.inputKey).hitTestable(), findsOneWidget);
      expect(find.byKey(CoachChatScreen.sendKey).hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byKey(CoachChatScreen.sendKey)).dy,
        lessThanOrEqualTo(360 - 160),
      );
    },
  );

  testWidgets(
    'coachChatTurnsProvider đang tải lại (đổi tài khoản): không hiện lượt cũ dù '
    'còn hasValue, chỉ hiện khi isLoading false (ruling controller Task 9/10)',
    (tester) async {
      // `copyWithPrevious` là API nội bộ của riverpod (@internal) — cách công
      // khai duy nhất để dựng trạng thái "đang tải lại, còn giá trị cũ" này;
      // vô hại ở đây vì chỉ dùng trong test (cùng cách
      // coach_chat_providers_test.dart đã dùng cho coachContextProvider).
      // ignore: invalid_use_of_internal_member
      final stale = const AsyncLoading<List<CoachChatEntry>>().copyWithPrevious(
        AsyncData<List<CoachChatEntry>>([
          (
            id: 1,
            at: t0,
            fromPlayer: true,
            text: 'Câu hỏi của tài khoản trước',
            insufficient: false,
          ),
        ]),
      );
      expect(stale.hasValue, isTrue);
      expect(stale.isLoading, isTrue);

      await openChat(tester, repo: newRepo(), turnsAsync: stale);

      expect(find.text('Câu hỏi của tài khoản trước'), findsNothing);
      // Coi như chưa có lượt nào trong lúc đang tải lại — hiện câu mẫu.
      expect(find.text(Vi.coachChatSamples.first), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(CoachChatScreen.clearKey)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
