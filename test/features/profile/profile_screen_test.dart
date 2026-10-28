import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/coach_providers.dart';
import 'package:poolcoachai/data/sync/coach_sync.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/coach_chat_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/assessment_sync.dart';
import 'package:poolcoachai/data/sync/cue_equipment_sync.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';
import 'package:poolcoachai/features/profile/presentation/equipment_screen.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';

import '../../support/coach_chat_fixtures.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_coach_chat.dart';
import '../../support/fake_directus.dart';

void main() {
  final today = DateTime(2026, 9, 23, 10);

  Future<(AppDatabase, FakeAuthRepository, FakeDirectus)> openProfile(
    WidgetTester tester, {
    int pending = 0,
    int unsyncable = 0,
    bool pendingRoadmap = false,
    bool pendingPractice = false,
    FakeCoachChat? coachChat,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);
    for (var i = 0; i < pending; i++) {
      await db
          .into(db.drillLogRows)
          .insert(
            DrillLogRowsCompanion.insert(
              id: 'p$i',
              userId: 'u1',
              drillId: 'd1',
              date: today,
              score: 7,
            ),
          );
    }
    for (var i = 0; i < unsyncable; i++) {
      await db
          .into(db.drillLogRows)
          .insert(
            DrillLogRowsCompanion.insert(
              id: 'u$i',
              userId: 'u1',
              drillId: 'd1',
              date: today,
              score: double.infinity,
            ),
          );
    }
    if (pendingPractice) {
      await db
          .into(db.poolMatchRows)
          .insert(
            PoolMatchRowsCompanion.insert(
              id: 'match-pending',
              userId: 'u1',
              gameType: 'nineBall',
              playerName: 'An',
              opponentName: 'Bình',
              targetRacks: 3,
              rackWinners: '[]',
              startedAt: today,
            ),
          );
    }
    if (pendingRoadmap) {
      final goal = GoalRecord(
        updatedAt: today,
        goal: PlayerGoal(
          goalId: 'goal-1',
          kind: GoalKind.thuanThucKyNang,
          category: SkillCategory.aiming,
          createdAt: today,
        ),
      );
      await db.into(db.playerGoalRows).insert(toGoalRow(goal, userId: 'u1'));
    }
    await db
        .into(db.drillLogRows)
        .insert(
          DrillLogRowsCompanion.insert(
            id: 'da-len',
            userId: 'u1',
            drillId: 'd1',
            date: today,
            score: 7,
            syncedAt: Value(today),
          ),
        );

    final auth = FakeAuthRepository.signedIn(userId: 'u1', displayName: 'An');
    final server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/drill_logs'] = ((_) => FakeDirectus.ok([]));
    final sync = SyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(sync.dispose);
    server
      ..routes['GET /items/player_ranks'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/player_ranks'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/skill_tests'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/skill_tests'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/bu_tests'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/bu_drill_results'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/bu_tests'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['POST /items/bu_drill_results'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/player_goals'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/player_goals'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['PATCH /items/player_goals/u1'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/achievements'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/achievements'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/pool_matches'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/timer_sessions'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/schedule_slots'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/tournaments'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/cue_equipment'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/cue_equipment'] = ((req) =>
          FakeDirectus.ok(jsonDecode(req.body)));
    final assessmentSync = AssessmentSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
      onRankFetch: (_, _) {},
    );
    addTearDown(assessmentSync.dispose);
    final roadmapSync = RoadmapSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(roadmapSync.dispose);
    final cueEquipmentSync = CueEquipmentSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(cueEquipmentSync.dispose);
    final practiceSync = PracticeSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(practiceSync.dispose);
    server.routes['GET /items/coach_attempts'] = (_) => FakeDirectus.ok([]);
    final coachSync = CoachSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(coachSync.dispose);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => today),
        authRepositoryProvider.overrideWithValue(auth),
        syncServiceProvider.overrideWithValue(sync),
        cueEquipmentSyncProvider.overrideWithValue(cueEquipmentSync),
        practiceSyncProvider.overrideWithValue(practiceSync),
        assessmentSyncProvider.overrideWithValue(assessmentSync),
        roadmapSyncProvider.overrideWithValue(roadmapSync),
        coachSyncProvider.overrideWithValue(coachSync),
        if (coachChat != null) ...[
          coachChatBackendProvider.overrideWithValue(coachChat),
          coachContextProvider.overrideWithValue(AsyncData(fullCoachContext())),
        ],
      ],
    );
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
    router.go(Routes.profile);
    await tester.pumpAndSettle();
    return (db, auth, server);
  }

  testWidgets('hiện tên người đang đăng nhập', (tester) async {
    await openProfile(tester);

    expect(find.text(Vi.profileSignedInAs('An')), findsOneWidget);
  });

  testWidgets('mở quản lý cơ từ Hồ sơ', (tester) async {
    await openProfile(tester);

    await tester.tap(find.text(Vi.equipmentTitle));
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentScreen), findsOneWidget);
    expect(find.text(Vi.equipmentEmpty), findsOneWidget);
  });

  testWidgets('không còn buổi chờ thì đăng xuất ngay, xoá dữ liệu trên máy', (
    tester,
  ) async {
    final (db, auth, _) = await openProfile(tester);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'đăng xuất khi câu hỏi Coach Chat còn đang chờ: câu trả lời tới sau '
    'không dựng lại lịch sử chat vừa xoá (I1, review cuối)',
    (tester) async {
      final chat = FakeCoachChat()..hold = Completer<void>();
      final (db, _, _) = await openProfile(tester, coachChat: chat);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
      final send = container
          .read(coachChatControllerProvider.notifier)
          .send('Câu hỏi riêng tư của An');
      await tester.pump();
      expect(chat.asked, hasLength(1));

      await tester.tap(find.text(Vi.profileSignOut));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      chat.hold!.complete();
      await send;
      await tester.pumpAndSettle();
      expect(await db.select(db.coachChatTurnRows).get(), isEmpty);
    },
  );

  testWidgets('còn buổi chờ thì cảnh báo trước, bấm Vẫn đăng xuất thì mất', (
    tester,
  ) async {
    final (db, auth, _) = await openProfile(tester, pending: 2);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutPendingBody(2)), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.tap(find.text(Vi.signOutAnyway));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('còn mục tiêu Lộ trình chờ thì cảnh báo và Vẫn đăng xuất xoá', (
    tester,
  ) async {
    final (db, auth, _) = await openProfile(tester, pendingRoadmap: true);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutPendingRoadmap(1)), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.tap(find.text(Vi.signOutAnyway));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.playerGoalRows).get(), isEmpty);
  });

  testWidgets('còn trận chờ đồng bộ thì cảnh báo, Đồng bộ trước đẩy trận lên', (
    tester,
  ) async {
    final (db, auth, server) = await openProfile(tester, pendingPractice: true);
    server.routes['POST /items/pool_matches'] = (req) =>
        FakeDirectus.ok(jsonDecode(req.body));

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutPendingPractice(1)), findsOneWidget);

    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/pool_matches'), hasLength(1));
    expect(auth.calls, ['signOut']);
    expect(await db.select(db.poolMatchRows).get(), isEmpty);
  });

  testWidgets('Đồng bộ trước đẩy mục tiêu Lộ trình rồi mới đăng xuất', (
    tester,
  ) async {
    final (_, auth, server) = await openProfile(tester, pendingRoadmap: true);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/player_goals'), hasLength(1));
    expect(auth.calls, ['signOut']);
  });

  testWidgets('chọn Đồng bộ trước thì đẩy lên rồi mới đăng xuất', (
    tester,
  ) async {
    final (_, auth, server) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/drill_logs'), hasLength(1));
    expect(auth.calls, ['signOut']);
  });

  testWidgets('Đồng bộ trước mà mất mạng thì không đăng xuất, báo lỗi', (
    tester,
  ) async {
    final (db, auth, server) = await openProfile(tester, pending: 1);
    server.offline = true;

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(find.text(Vi.syncFailed), findsOneWidget);
    expect(auth.calls, isEmpty);
    expect(await db.select(db.drillLogRows).get(), hasLength(2));
  });

  // Buổi điểm vô hạn không bao giờ lên được: báo "kiểm tra mạng" là sai
  // nguyên nhân, người chơi thử mãi không xong. Chỉ đường tới chỗ bỏ chúng.
  testWidgets(
    'Đồng bộ trước mà chỉ còn buổi không đồng bộ được thì chỉ tới cảnh báo',
    (tester) async {
      final (db, auth, server) = await openProfile(
        tester,
        pending: 1,
        unsyncable: 1,
      );

      await tester.tap(find.text(Vi.profileSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.signOutSyncFirst));
      await tester.pumpAndSettle();

      expect(
        server.sent('POST', '/items/drill_logs'),
        hasLength(1),
      ); // buổi thường đã lên
      expect(find.text(Vi.syncBlockedByUnsyncable), findsOneWidget);
      expect(find.text(Vi.syncFailed), findsNothing);
      expect(auth.calls, isEmpty);
      expect(
        (await db.select(db.drillLogRows).get()).where(
          (r) => !r.score.isFinite,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'Đồng bộ trước mất mạng, còn cả buổi thường lẫn buổi lỗi thì vẫn báo mạng',
    (tester) async {
      final (_, auth, server) = await openProfile(
        tester,
        pending: 1,
        unsyncable: 1,
      );
      server.offline = true;

      await tester.tap(find.text(Vi.profileSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.signOutSyncFirst));
      await tester.pumpAndSettle();

      expect(find.text(Vi.syncFailed), findsOneWidget);
      expect(find.text(Vi.syncBlockedByUnsyncable), findsNothing);
      expect(auth.calls, isEmpty);
    },
  );

  testWidgets('bỏ qua hộp thoại thì không làm gì', (tester) async {
    final (_, auth, _) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
  });

  testWidgets(
    'có buổi không đồng bộ được thì Hồ sơ báo, bấm Bỏ thì xoá sau khi xác nhận',
    (tester) async {
      final (db, auth, _) = await openProfile(tester, unsyncable: 2);

      expect(find.text(Vi.unsyncableTitle(2)), findsOneWidget);
      await tester.tap(find.text(Vi.unsyncableDiscard));
      await tester.pumpAndSettle();
      expect(find.text(Vi.unsyncableConfirmBody(2)), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, Vi.unsyncableConfirm));
      await tester.pumpAndSettle();

      final left = await db.select(db.drillLogRows).get();
      expect(left.where((r) => !r.score.isFinite), isEmpty);
      expect(left.map((r) => r.id), contains('da-len'));
      expect(find.text(Vi.unsyncableTitle(2)), findsNothing);
      expect(auth.calls, isEmpty);
    },
  );

  testWidgets('Huỷ ở hộp xác nhận thì không xoá gì', (tester) async {
    final (db, _, _) = await openProfile(tester, unsyncable: 1);

    await tester.tap(find.text(Vi.unsyncableDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.cancel));
    await tester.pumpAndSettle();

    expect(
      (await db.select(db.drillLogRows).get()).where((r) => !r.score.isFinite),
      hasLength(1),
    );
  });

  testWidgets('không có buổi lỗi thì không hiện gì', (tester) async {
    await openProfile(tester);
    expect(find.text(Vi.unsyncableDiscard), findsNothing);
  });

  testWidgets('hộp thoại đăng xuất: Đồng bộ trước là nút chính', (
    tester,
  ) async {
    await openProfile(tester, pending: 1);
    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, Vi.signOutSyncFirst),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, Vi.signOutAnyway), findsOneWidget);
  });

  testWidgets(
    'đăng xuất khi có lần kiểm tra dở: cảnh báo sẽ mất, Vẫn đăng xuất thì xoá',
    (tester) async {
      final (db, auth, _) = await openProfile(tester);
      await db
          .into(db.buTestRows)
          .insert(
            BuTestRowsCompanion.insert(
              id: 'do',
              userId: 'u1',
              startedAt: today,
              tableSize: 'nineFootPlus',
            ),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.text(Vi.profileSignOut));
      await tester.pumpAndSettle();
      expect(find.text(Vi.signOutActiveTest), findsOneWidget);
      await tester.tap(find.text(Vi.signOutAnyway));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
      expect(await db.select(db.buTestRows).get(), isEmpty);
    },
  );

  testWidgets('Hồ sơ hiện thẻ hạng thay cho chỗ trống cũ', (tester) async {
    await openProfile(tester);
    expect(find.text(Vi.rankNone), findsOneWidget);
    expect(find.text(Vi.rankDetermine), findsOneWidget);
  });
}
