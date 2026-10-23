import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/player_intelligence_provider.dart';
import 'package:poolcoachai/core/providers/recommendation_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';

import '../../support/coach_chat_fixtures.dart';
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
}
