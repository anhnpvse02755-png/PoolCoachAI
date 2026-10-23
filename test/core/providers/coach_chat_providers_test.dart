import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_coach_chat.dart';
import '../../support/test_data.dart';

void main() {
  test('gom sáu nguồn thành CoachContext có today và matches', () async {
    final container = testContainer(
      matches: [finishedMatch('m1', const [RackWinner.player, RackWinner.player, RackWinner.player], completedAt: testToday)],
    );
    addTearDown(container.dispose);
    container.listen(coachContextProvider, (_, _) {});
    await pumpEventQueue();
    final facts = container.read(coachContextProvider).value!.toFacts();
    expect(facts['today'], isNotNull);
    expect(((facts['matches']! as Map)['recent'] as Map)['played'], 1);
  });

  // Mọi nguồn khác rank: "sẵn sàng" (không lỗi, không đang tải), dùng chung
  // cho hai test dưới để chỉ một nguồn khác trạng thái mỗi lần.
  readySourcesExcept({AsyncValue<PlayerRank?>? rank}) => [
        playerIntelligenceProvider.overrideWithValue(computePlayerIntelligence(drills: seedDrills, logs: const [])),
        playerRankProvider.overrideWithValue(
          rank ??
              AsyncData<PlayerRank?>(
                PlayerRank(rank: Rank.g, source: RankSource.estimated, onboardingState: OnboardingState.done, updatedAt: testToday),
              ),
        ),
        roadmapProvider.overrideWithValue(const AsyncData<Roadmap?>(null)),
        coachAttemptsProvider.overrideWithValue(const AsyncData<List<CoachAttempt>>([])),
        todayRecommendationProvider.overrideWithValue(AsyncData<TodayRecommendation>(sampleToday())),
        matchesProvider.overrideWithValue(const AsyncData<List<PoolMatch>>([])),
      ];

  test(
    'một nguồn đang tải lại với giá trị cũ (đổi tài khoản): context vẫn đang '
    'tải, không dùng dữ liệu cũ (controller review R21)',
    () async {
      // Hạng của tài khoản trước vẫn còn trong AsyncValue (hasValue true)
      // nhưng provider đang xây lại (isLoading true) — như khi đổi tài
      // khoản. `!hasValue` một mình sẽ bỏ sót trường hợp này.
      // `copyWithPrevious` là API nội bộ của riverpod (@internal) — cách
      // công khai duy nhất để dựng trạng thái "đang tải lại, còn giá trị
      // cũ" này; vô hại ở đây vì chỉ dùng trong test.
      // ignore: invalid_use_of_internal_member
      final staleRank = const AsyncLoading<PlayerRank?>().copyWithPrevious(
        AsyncData<PlayerRank?>(
          PlayerRank(rank: Rank.h, source: RankSource.estimated, onboardingState: OnboardingState.done, updatedAt: testToday),
        ),
      );
      expect(staleRank.hasValue, isTrue);
      expect(staleRank.isLoading, isTrue);

      final container = ProviderContainer(overrides: readySourcesExcept(rank: staleRank));
      addTearDown(container.dispose);
      container.listen(coachContextProvider, (_, _) {});
      await pumpEventQueue();

      expect(container.read(coachContextProvider).isLoading, isTrue);
    },
  );

  test('một nguồn lỗi: context lỗi luôn, dù các nguồn khác đã sẵn sàng', () async {
    final error = Exception('fx-rank-error');
    final container = ProviderContainer(
      overrides: readySourcesExcept(rank: AsyncError<PlayerRank?>(error, StackTrace.empty)),
    );
    addTearDown(container.dispose);
    container.listen(coachContextProvider, (_, _) {});
    await pumpEventQueue();

    final result = container.read(coachContextProvider);
    expect(result.hasError, isTrue);
    expect(result.error, error);
  });

  test(
    'gửi hai lần liên tiếp không chờ lần đầu xong: chỉ một yêu cầu tới backend (ruling)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CoachChatRepository(db, userId: 'u1');
      final chat = FakeCoachChat()..hold = Completer<void>();

      final container = testContainer(
        coachChat: chat,
        coachChatRepo: repo,
        coachContext: AsyncData(fullCoachContext()),
      );
      addTearDown(container.dispose);
      container.listen(coachChatControllerProvider, (_, _) {});
      await pumpEventQueue();

      final controller = container.read(coachChatControllerProvider.notifier);
      final first = controller.send('Câu hỏi thứ nhất');
      final second = controller.send('Câu hỏi thứ hai'); // không chờ lần đầu

      // Dù chưa mở khoá `hold`, cú gửi thứ hai đã bị chặn ngay từ bước đồng
      // bộ (trước await đầu tiên) của hàm `send` — không cần đợi backend.
      await pumpEventQueue();
      expect(chat.asked, hasLength(1));

      chat.hold!.complete();
      await first;
      await second;

      expect(chat.asked, hasLength(1));
      expect(chat.asked.single.question, 'Câu hỏi thứ nhất');
      expect(container.read(coachChatControllerProvider).status, CoachChatStatus.idle);
    },
  );

  test(
    'đổi tài khoản khi câu hỏi cũ còn đang chờ mạng: trả lời muộn không đè '
    'state của tài khoản mới, lưu đúng vào lịch sử tài khoản cũ, và không mở '
    'lại cổng chặn gửi đôi cho tài khoản mới (I1, review Task 10 fix round 1)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final auth = FakeAuthRepository.signedIn(userId: 'u1');
      final chat = FakeCoachChat();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appDatabaseProvider.overrideWithValue(db),
          coachChatBackendProvider.overrideWithValue(chat),
          coachContextProvider.overrideWithValue(AsyncData(fullCoachContext())),
          nowProvider.overrideWithValue(() => testToday),
        ],
      );
      addTearDown(container.dispose);
      container.listen(coachChatControllerProvider, (_, _) {});
      await pumpEventQueue();

      final controller = container.read(coachChatControllerProvider.notifier);

      // u1 gửi câu hỏi, giữ lại chưa trả lời.
      final hold1 = Completer<void>();
      chat.hold = hold1;
      final send1 = controller.send('Câu hỏi riêng tư của u1');
      await pumpEventQueue();
      expect(chat.asked, hasLength(1));

      // Đổi tài khoản khi câu của u1 còn đang chờ — build() chạy lại trên
      // CÙNG MỘT controller, state về mặc định cho u2.
      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await pumpEventQueue();
      expect(
        container.read(coachChatControllerProvider),
        (status: CoachChatStatus.idle, pending: null, remaining: null),
      );

      // u2 tự gửi câu của mình, cũng giữ lại chưa trả lời.
      final hold2 = Completer<void>();
      chat.hold = hold2;
      final send2 = controller.send('Câu hỏi của u2');
      await pumpEventQueue();
      expect(chat.asked, hasLength(2));

      // Mở khoá câu TRẢ LỜI MUỘN của u1 — chỉ của u1, câu của u2 vẫn treo.
      hold1.complete();
      await send1;
      await pumpEventQueue();

      // Còn bug (I1): state bị đè thành (idle, null, 29) của u1 — mất luôn
      // "đang gửi" của u2. Đã sửa: state của u2 còn nguyên vì câu của u2
      // chưa xong.
      expect(
        container.read(coachChatControllerProvider),
        (status: CoachChatStatus.sending, pending: 'Câu hỏi của u2', remaining: null),
      );

      // Còn bug: cổng chặn gửi đôi (so `state.status == sending`) bị mở lại
      // nhầm bởi state bị đè ở trên — một cú gửi thứ ba lọt qua được. Đã
      // sửa thì không lọt.
      await controller.send('Câu hỏi thứ ba lẽ ra phải bị chặn');
      await pumpEventQueue();
      expect(chat.asked, hasLength(2));

      // Mở khoá câu của u2 — xong việc đúng cho generation của u2.
      hold2.complete();
      await send2;
      await pumpEventQueue();

      expect(
        container.read(coachChatControllerProvider),
        (status: CoachChatStatus.idle, pending: null, remaining: 28),
      );

      // Câu trả lời muộn của u1 phải lưu đúng vào lịch sử của u1, không lẫn
      // sang u2 — và ngược lại.
      final u1Repo = CoachChatRepository(db, userId: 'u1');
      final u2Repo = CoachChatRepository(db, userId: 'u2');
      final u1Turns = await u1Repo.recentTurns(10);
      final u2Turns = await u2Repo.recentTurns(10);
      expect(u1Turns.map((e) => e.text), ['Câu hỏi riêng tư của u1', chat.replyText]);
      expect(u2Turns.map((e) => e.text), ['Câu hỏi của u2', chat.replyText]);
    },
  );

  test(
    'đổi tài khoản khi câu hỏi cũ gửi hỏng muộn: lỗi muộn không đè state của '
    'tài khoản mới và Thử lại không gửi câu riêng tư đó sang tài khoản mới '
    '(I1, review Task 10 fix round 1)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final auth = FakeAuthRepository.signedIn(userId: 'u1');
      final chat = FakeCoachChat();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appDatabaseProvider.overrideWithValue(db),
          coachChatBackendProvider.overrideWithValue(chat),
          coachContextProvider.overrideWithValue(AsyncData(fullCoachContext())),
          nowProvider.overrideWithValue(() => testToday),
        ],
      );
      addTearDown(container.dispose);
      container.listen(coachChatControllerProvider, (_, _) {});
      await pumpEventQueue();

      final controller = container.read(coachChatControllerProvider.notifier);

      final hold1 = Completer<void>();
      chat.hold = hold1;
      chat.nextError = const CoachChatUnavailable('u1 lỗi mạng');
      final send1 = controller.send('Câu hỏi riêng tư của u1');
      await pumpEventQueue();

      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await pumpEventQueue();

      hold1.complete();
      await send1;
      await pumpEventQueue();

      // Còn bug: state bị đè thành (failed, 'Câu hỏi riêng tư của u1', ...)
      // trên tài khoản u2. Đã sửa: u2 vẫn sạch (idle, null, null).
      expect(
        container.read(coachChatControllerProvider),
        (status: CoachChatStatus.idle, pending: null, remaining: null),
      );

      // Thử lại ngay sau đó không được gửi gì thêm (status không phải
      // failed) — còn bug thì đây sẽ gửi LẠI câu riêng tư của u1, lần này
      // trên tài khoản u2 (rò câu hỏi sang tài khoản khác qua Thử lại).
      await controller.retry();
      await pumpEventQueue();
      expect(chat.asked, hasLength(1));

      final u2Repo = CoachChatRepository(db, userId: 'u2');
      expect(await u2Repo.recentTurns(10), isEmpty);
    },
  );

  test(
    'lấy lịch sử để gửi bị ném lỗi: rơi về trạng thái lỗi chung, không kẹt '
    'mãi ở "đang gửi" (M1, review Task 10 fix round 1)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _ThrowingHistoryRepo(db, userId: 'u1');
      final chat = FakeCoachChat();

      final container = testContainer(
        coachChat: chat,
        coachChatRepo: repo,
        coachContext: AsyncData(fullCoachContext()),
      );
      addTearDown(container.dispose);
      container.listen(coachChatControllerProvider, (_, _) {});
      await pumpEventQueue();

      final controller = container.read(coachChatControllerProvider.notifier);

      await controller.send('Câu hỏi khi lấy lịch sử hỏng');
      await pumpEventQueue();

      expect(
        container.read(coachChatControllerProvider).status,
        CoachChatStatus.failed,
      );
      expect(chat.asked, isEmpty); // chưa từng tới được backend
    },
  );
}

/// `recentTurns` luôn ném — dựng lỗi đọc lịch sử có kiểm soát cho test M1,
/// không phụ thuộc hành vi đóng DB thật của Drift.
class _ThrowingHistoryRepo extends CoachChatRepository {
  _ThrowingHistoryRepo(super.db, {required super.userId});

  @override
  Future<List<CoachChatEntry>> recentTurns(int count) async {
    throw Exception('fx-history-read-broken');
  }
}
