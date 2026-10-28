import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/core/providers/repository_providers.dart';
import 'package:poolcoachai/data/repositories/coach_attempt_repository.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/skill_test_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/providers/tournament_providers.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/tournament_repository.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:poolcoachai/domain/pool_match.dart';

import 'coach_fixtures.dart';
import 'fake_coach_chat.dart';
import 'planner_tables.dart';
import 'fake_auth.dart';

/// Dữ liệu và bộ chứa provider dùng chung cho mọi widget test.
///
/// Widget test không được chạm vào SQLite thật: mỗi test tự dựng dữ
/// liệu của mình rồi ghi đè ba stream nguồn. Gom về một chỗ để thêm
/// một trường vào [Drill] không phải sửa bốn file test.

final testDrills = <Drill>[
  const Drill(
    id: 'd1',
    cat: SkillCategory.aiming,
    name: 'Đường thẳng cơ bản',
    level: 1,
    unit: 'lần trúng / 10',
    passThreshold: 0.8,
    goal: 'Đánh thẳng bi cái.',
    steps: ['Bước 1', 'Bước 2'],
  ),
];

final testKnowledge = <KnowledgeArticle>[
  const KnowledgeArticle(
    id: 'k1',
    cat: SkillCategory.aiming,
    title: 'Nguyên lý bi ảo',
    body: 'Thân bài kiến thức về bi ảo.',
    relatedDrillIds: ['d1'],
  ),
  const KnowledgeArticle(
    id: 'k2',
    cat: SkillCategory.bank,
    title: 'Cân bi một băng',
    body: 'Thân bài kiến thức về cân bi.',
  ),
];

/// Bộ chứa provider đã ghi đè ba stream nguồn bằng dữ liệu test.
/// Hôm nay cố định cho widget test. Đồng hồ máy làm test xanh hôm nay,
/// đỏ vào đúng nửa đêm.
final testToday = DateTime(2026, 9, 22, 10, 0);

ProviderContainer testContainer({
  List<Drill>? drills,
  List<KnowledgeArticle>? knowledge,
  List<DrillLog>? logs,
  List<TimerSession>? timerSessions,
  List<ScheduleSlot>? schedule,
  List<CueEquipment>? equipment,
  Stream<List<CueEquipment>>? equipmentStream,
  List<PoolMatch>? matches,
  Stream<List<PoolMatch>>? matchesStream,
  DateTime? now,
  AuthRepository? auth,
  PlayerRank? rank,
  List<BuTest>? tests,
  Stream<List<BuTest>>? buTestsStream,
  TestSnapshot? activeTest,
  GoalRecord? goal,
  List<Achievement>? achievements,
  BuResult? buResult,
  List<CoachAttempt>? coachAttempts,
  CoachAttemptRepository? coachRepo,
  CoachEngine? coachEngine,
  CoachChatBackend? coachChat,
  CoachChatRepository? coachChatRepo,
  List<CoachChatEntry>? coachChatTurns,
  AsyncValue<List<CoachChatEntry>>? coachChatTurnsAsync,
  AsyncValue<CoachContext>? coachContext,
  List<SkillTest>? skillTests,
  AsyncValue<List<SkillTest>>? skillTestsAsync,
  List<Tournament>? tournaments,
  AsyncValue<List<Tournament>>? tournamentsAsync,
  AsyncValue<GoalRecord?>? goalAsync,
  Map<String, TournamentStatus>? forcedTournamentStatus,
}) {
  return ProviderContainer(
    overrides: [
      // Cho test chứng minh màn hình dùng trạng thái do provider đưa ra, không
      // tự tính lại: ép trạng thái khác với ngày thật của giải.
      if (forcedTournamentStatus != null)
        tournamentStatusProvider.overrideWith(
          (ref, id) => AsyncData(forcedTournamentStatus[id]),
        ),
      coachAttemptsProvider.overrideWith(
        (ref) => Stream.value(coachAttempts ?? const <CoachAttempt>[]),
      ),
      coachAttemptRepositoryProvider.overrideWithValue(coachRepo),
      coachEngineProvider.overrideWithValue(coachEngine ?? fastCoachEngine),
      // Không widget test nào được chạm mạng: luôn thay backend thật.
      coachChatBackendProvider.overrideWithValue(coachChat ?? FakeCoachChat()),
      coachChatRepositoryProvider.overrideWithValue(coachChatRepo),
      // `coachChatTurnsAsync` thắng `coachChatTurns`: test cần dựng thẳng
      // một AsyncValue (vd. đang tải lại còn giá trị cũ, controller review
      // Task 9/10) không đi qua được một Stream bình thường.
      if (coachChatTurnsAsync != null)
        coachChatTurnsProvider.overrideWithValue(coachChatTurnsAsync)
      else if (coachChatTurns != null)
        coachChatTurnsProvider.overrideWith(
          (ref) => Stream.value(coachChatTurns),
        ),
      if (coachContext != null)
        coachContextProvider.overrideWithValue(coachContext),
      nowProvider.overrideWithValue(() => now ?? testToday),
      drillsProvider.overrideWith((ref) => Stream.value(drills ?? testDrills)),
      knowledgeProvider.overrideWith(
        (ref) => Stream.value(knowledge ?? testKnowledge),
      ),
      drillLogsProvider.overrideWith(
        (ref) => Stream.value(logs ?? const <DrillLog>[]),
      ),
      timerSessionsProvider.overrideWith(
        (ref) => Stream.value(timerSessions ?? const <TimerSession>[]),
      ),
      scheduleProvider.overrideWith(
        (ref) => Stream.value(schedule ?? const <ScheduleSlot>[]),
      ),
      cueEquipmentProvider.overrideWith(
        (ref) =>
            equipmentStream ??
            Stream.value(equipment ?? const <CueEquipment>[]),
      ),
      matchesProvider.overrideWith(
        (ref) => matchesStream ?? Stream.value(matches ?? const <PoolMatch>[]),
      ),
      authRepositoryProvider.overrideWithValue(
        auth ?? FakeAuthRepository.signedIn(),
      ),
      playerRankProvider.overrideWith((ref) => Stream.value(rank)),
      buTestsProvider.overrideWith(
        (ref) => buTestsStream ?? Stream.value(tests ?? const <BuTest>[]),
      ),
      activeTestProvider.overrideWith((ref) => Stream.value(activeTest)),
      // `goalAsync` thắng `goal`: dựng thẳng một AsyncValue (đang tải lại còn
      // mục tiêu cũ) mà một Stream bình thường không tạo được.
      if (goalAsync != null)
        goalProvider.overrideWithValue(goalAsync)
      else
        goalProvider.overrideWith((ref) => Stream.value(goal)),
      achievementsProvider.overrideWith(
        (ref) => Stream.value(achievements ?? const <Achievement>[]),
      ),
      // `skillTestsAsync` thắng `skillTests`, như `coachChatTurnsAsync`.
      if (skillTestsAsync != null)
        skillTestsProvider.overrideWithValue(skillTestsAsync)
      else
        skillTestsProvider.overrideWith(
          (ref) => Stream.value(skillTests ?? const <SkillTest>[]),
        ),
      // `tournamentsAsync` thắng `tournaments`, như `skillTestsAsync`.
      if (tournamentsAsync != null)
        tournamentsProvider.overrideWithValue(tournamentsAsync)
      else
        tournamentsProvider.overrideWith(
          (ref) => Stream.value(tournaments ?? const <Tournament>[]),
        ),
      if (buResult != null)
        latestBuResultProvider.overrideWithValue(
          AsyncData<BuResult?>(buResult),
        ),
    ],
  );
}

/// Cổng đã đăng nhập — cho các test màn tập vốn không quan tâm tài khoản.
AuthGate signedInGate() =>
    AuthGate.fixed(const SignedIn(userId: 'u1', displayName: 'An'));

/// Dựng cả app với một AuthRepository giả, cổng nối thật vào nó.
Future<(GoRouter, FakeAuthRepository)> pumpAuthApp(
  WidgetTester tester, {
  AuthState initial = const SignedOut(),
  String? location,
}) async {
  final auth = FakeAuthRepository(initial);
  final container = testContainer(auth: auth);
  addTearDown(container.dispose);
  final gate = AuthGate(auth);
  addTearDown(gate.dispose);
  final router = createAppRouter(auth: gate);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return (router, auth);
}

/// Như [testContainer] nhưng hạng và bài kiểm tra đọc từ [db] thật (SQLite
/// trong bộ nhớ) — cho widget test cần ghi rồi đọc lại.
///
/// [tournamentRepo] thay kho giải (ví dụ kho ghi xong rồi mới trả về chậm).
/// [rankLag] làm stream hạng trễ như Drift trên web (chạy trong worker):
/// dòng vừa ghi tới màn hình sau một nhịp.
ProviderContainer dbContainer(
  AppDatabase db, {
  AuthRepository? auth,
  DateTime? now,
  DateTime Function()? clock,
  Duration? rankLag,
  List<DrillLog>? logs,
  List<Drill>? drills,
  TournamentRepository Function(AppDatabase db)? tournamentRepo,
}) {
  return ProviderContainer(
    overrides: [
      if (tournamentRepo != null)
        tournamentRepositoryProvider.overrideWith(
          (ref) => tournamentRepo(ref.watch(appDatabaseProvider)),
        ),
      if (rankLag != null)
        playerRankProvider.overrideWith((ref) {
          final repo = ref.watch(assessmentRepositoryProvider);
          if (repo == null) return Stream.value(null);
          return repo.watchRank().asyncMap((r) async {
            await Future<void>.delayed(rankLag);
            return r;
          });
        }),
      appDatabaseProvider.overrideWithValue(db),
      // Không widget test nào được chạm mạng: luôn thay backend thật.
      coachChatBackendProvider.overrideWithValue(FakeCoachChat()),
      nowProvider.overrideWithValue(clock ?? () => now ?? testToday),
      drillsProvider.overrideWith((ref) => Stream.value(drills ?? testDrills)),
      knowledgeProvider.overrideWith((ref) => Stream.value(testKnowledge)),
      drillLogsProvider.overrideWith(
        (ref) => Stream.value(logs ?? const <DrillLog>[]),
      ),
      authRepositoryProvider.overrideWithValue(
        auth ?? FakeAuthRepository.signedIn(),
      ),
    ],
  );
}

/// Lõi Coach của widget test: lõi giả tức thì, tính một mạch mỗi khung hình.
final fastCoachEngine = CoachEngine(
  aim: fakeAim,
  safety: noSafetyPhysics,
  budget: const Duration(days: 1),
);
