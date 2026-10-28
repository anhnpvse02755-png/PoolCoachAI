import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/coach_chat_repository.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';
import '../../support/in_memory_session_store.dart';
import '../../support/skill_test_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addLog(String id, String userId, {bool synced = false}) => db
      .into(db.drillLogRows)
      .insert(
        DrillLogRowsCompanion.insert(
          id: id,
          userId: userId,
          drillId: 'd1',
          date: DateTime(2026, 9, 22),
          score: 7,
          syncedAt: Value(synced ? DateTime(2026, 9, 22) : null),
        ),
      );

  Future<void> insertLog(
    String id, {
    required String userId,
    required double score,
  }) => db
      .into(db.drillLogRows)
      .insert(
        DrillLogRowsCompanion.insert(
          id: id,
          userId: userId,
          drillId: 'd1',
          date: DateTime(2026, 9, 22, 18),
          score: score,
        ),
      );

  test('chỉ đếm buổi chưa đồng bộ của đúng người', () async {
    await addLog('a', 'u1');
    await addLog('b', 'u1', synced: true);
    await addLog('c', 'u2');

    expect(await pendingLogCount(db, 'u1'), 1);
  });

  test(
    'đếm hồ sơ cơ chưa đồng bộ kể cả tombstone và chỉ của đúng tài khoản',
    () async {
      final repository = DriftCueEquipmentRepository(db, userId: 'u1');
      await repository.save(
        const CueEquipment(
          id: 'cue-u1',
          name: 'Cơ của An',
          type: CueType.playing,
          skillCategories: [],
        ),
      );
      await db
          .into(db.cueEquipmentRows)
          .insert(
            CueEquipmentRowsCompanion.insert(
              id: 'cue-u2',
              userId: 'u2',
              name: 'Cơ người khác',
              type: CueType.playing.name,
              skillCategories: '[]',
            ),
          );

      expect(await pendingCueEquipmentCount(db, 'u1'), 1);
      await repository.remove('cue-u1');
      expect(await pendingCueEquipmentCount(db, 'u1'), 1);
    },
  );

  test('đếm trận, buổi tập tự do và lịch chưa đồng bộ của đúng tài khoản, bỏ dòng mồ côi', () async {
    final at = DateTime(2026, 10, 21);
    await db
        .into(db.poolMatchRows)
        .insert(
          PoolMatchRowsCompanion.insert(
            id: 'm1',
            userId: 'u1',
            gameType: 'nineBall',
            playerName: 'An',
            opponentName: 'Bình',
            targetRacks: 3,
            rackWinners: '[]',
            startedAt: at,
          ),
        );
    await db
        .into(db.poolMatchRows)
        .insert(
          PoolMatchRowsCompanion.insert(
            id: 'm-synced',
            userId: 'u1',
            gameType: 'nineBall',
            playerName: 'An',
            opponentName: 'Bình',
            targetRacks: 3,
            rackWinners: '[]',
            startedAt: at,
            syncedAt: Value(at),
          ),
        );
    await db
        .into(db.timerSessionRows)
        .insert(
          TimerSessionRowsCompanion.insert(
            id: 't1',
            userId: const Value('u1'),
            date: at,
            durationSec: 60,
          ),
        );
    await db
        .into(db.timerSessionRows)
        .insert(
          TimerSessionRowsCompanion.insert(
            id: 't-orphan',
            date: at,
            durationSec: 60,
          ),
        );
    await db
        .into(db.scheduleSlotRows)
        .insert(
          ScheduleSlotRowsCompanion.insert(
            id: 's1',
            userId: const Value('u1'),
            day: 0,
            time: '19:00',
            label: 'Tập',
          ),
        );
    await db
        .into(db.scheduleSlotRows)
        .insert(
          ScheduleSlotRowsCompanion.insert(
            id: 's-u2',
            userId: const Value('u2'),
            day: 0,
            time: '19:00',
            label: 'Người khác',
          ),
        );

    expect(await pendingPracticeCount(db, 'u1'), 3);
  });

  test('bấm Đăng xuất thì xoá buổi của người đó, giữ của người khác', () async {
    final auth = FakeAuthRepository.signedIn(userId: 'u1');
    await addLog('a', 'u1');
    await addLog('c', 'u2');
    await db
        .into(db.timerSessionRows)
        .insert(
          TimerSessionRowsCompanion.insert(
            id: 'timer-u1',
            userId: const Value('u1'),
            date: DateTime(2026, 9, 22),
            durationSec: 600,
          ),
        );
    await db
        .into(db.timerSessionRows)
        .insert(
          TimerSessionRowsCompanion.insert(
            id: 'timer-u2',
            userId: const Value('u2'),
            date: DateTime(2026, 9, 22),
            durationSec: 900,
          ),
        );
    await db
        .into(db.scheduleSlotRows)
        .insert(
          ScheduleSlotRowsCompanion.insert(
            id: 'schedule-u1',
            userId: const Value('u1'),
            day: 0,
            time: '19:00',
            label: 'Tập tối',
          ),
        );
    await DriftCueEquipmentRepository(db, userId: 'u1').save(
      const CueEquipment(
        id: 'cue-u1',
        name: 'Cơ của An',
        type: CueType.playing,
        skillCategories: [],
      ),
    );
    await db
        .into(db.cueEquipmentRows)
        .insert(
          CueEquipmentRowsCompanion.insert(
            id: 'cue-u2',
            userId: 'u2',
            name: 'Cơ người khác',
            type: CueType.breakCue.name,
            skillCategories: '[]',
          ),
        );
    await db
        .into(db.poolMatchRows)
        .insert(
          PoolMatchRowsCompanion.insert(
            id: 'match-u1',
            userId: 'u1',
            gameType: 'nineBall',
            playerName: 'An',
            opponentName: 'Bình',
            targetRacks: 5,
            rackWinners: '[]',
            startedAt: DateTime(2026, 9, 22),
          ),
        );
    await db
        .into(db.poolMatchRows)
        .insert(
          PoolMatchRowsCompanion.insert(
            id: 'match-u2',
            userId: 'u2',
            gameType: 'eightBall',
            playerName: 'Người khác',
            opponentName: 'Bạn',
            targetRacks: 3,
            rackWinners: '[]',
            startedAt: DateTime(2026, 9, 22),
          ),
        );

    await signOutAndForget(
      db: db,
      auth: auth,
      userId: 'u1',
      forgetChatInFlight: (_) {},
    );

    final left = await db.select(db.drillLogRows).get();
    expect(left.map((r) => r.id), ['c']);
    expect((await db.select(db.timerSessionRows).get()).map((row) => row.id), [
      'timer-u2',
    ]);
    expect(await db.select(db.scheduleSlotRows).get(), isEmpty);
    expect((await db.select(db.cueEquipmentRows).get()).map((row) => row.id), [
      'cue-u2',
    ]);
    expect((await db.select(db.poolMatchRows).get()).map((row) => row.id), [
      'match-u2',
    ]);
    expect(auth.current, const SignedOut());
  });

  test(
    'kéo về đang chạy dở không dựng lại buổi vừa xoá khi đăng xuất',
    () async {
      final now = DateTime(2026, 9, 23, 10);
      final server = FakeDirectus()..acceptLogin(userId: 'u1', refresh: 'r1');
      final api = DirectusClient(
        client: server.client,
        baseUrl: FakeDirectus.baseUrl,
      );
      final auth = DirectusAuthRepository(
        api: api,
        sessions: InMemorySessionStore(),
        resetUrl: Uri.parse('https://app.test/reset-password'),
        now: () => now,
      );
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      await addLog('a', 'u1', synced: true);

      final pullGate = Completer<void>();
      final logoutGate = Completer<void>();
      server
        ..routes['GET /items/drill_logs'] = ((_) async {
          await pullGate.future;
          return FakeDirectus.ok([
            {
              'id': 'a',
              'drill_id': 'd1',
              'date': '2026-09-22T00:00:00.000Z',
              'score': 7,
              'attempts': null,
              'notes': null,
            },
          ]);
        })
        ..routes['POST /auth/logout'] = ((_) async {
          await logoutGate.future;
          return FakeDirectus.noContent();
        });
      final sync = SyncService(db: db, auth: auth, api: api, now: () => now);
      addTearDown(sync.dispose);

      final pass = sync.syncNow();
      await pumpEventQueue();
      expect(server.sent('GET', '/items/drill_logs'), hasLength(1));

      final signingOut = signOutAndForget(
        db: db,
        auth: auth,
        userId: 'u1',
        forgetChatInFlight: (_) {},
      );
      await pumpEventQueue();
      pullGate.complete(); // server trả dữ liệu của người vừa đăng xuất
      await pass;
      logoutGate.complete();
      await signingOut;

      final left = await (db.select(
        db.drillLogRows,
      )..where((t) => t.userId.equals('u1'))).get();
      expect(left, isEmpty);
      expect(auth.current, const SignedOut());
    },
  );

  group('buổi không đồng bộ được', () {
    test('chỉ đếm buổi chờ có điểm vô hạn của đúng người', () async {
      await insertLog('ok', userId: 'u1', score: 7);
      await insertLog('vo-han', userId: 'u1', score: double.infinity);
      await insertLog(
        'am-vo-han',
        userId: 'u1',
        score: double.negativeInfinity,
      );
      await insertLog('nguoi-khac', userId: 'u2', score: double.infinity);

      expect(await watchUnsyncableCount(db, 'u1').first, 2);
    });

    test(
      'bỏ đi thì chỉ xoá buổi lỗi của đúng người, buổi khác còn nguyên',
      () async {
        await insertLog('ok', userId: 'u1', score: 7);
        await insertLog('vo-han', userId: 'u1', score: double.infinity);
        await insertLog('nguoi-khac', userId: 'u2', score: double.infinity);

        await discardUnsyncableLogs(db, 'u1');

        final ids = (await db.select(db.drillLogRows).get())
            .map((r) => r.id)
            .toSet();
        expect(ids, {'ok', 'nguoi-khac'});
      },
    );
  });

  test('đăng xuất tay xoá cả hạng và bài kiểm tra của người đó, giữ của người khác', () async {
    final at = DateTime(2026, 10, 14);
    for (final user in ['u1', 'u2']) {
      await db
          .into(db.playerRankRows)
          .insert(
            PlayerRankRowsCompanion.insert(
              userId: user,
              onboardingState: 'skipped',
              updatedAt: at,
            ),
          );
      await db
          .into(db.buTestRows)
          .insert(
            BuTestRowsCompanion.insert(
              id: 't-$user',
              userId: user,
              startedAt: at,
              tableSize: 'nineFootPlus',
            ),
          );
      await db
          .into(db.buDrillResultRows)
          .insert(
            BuDrillResultRowsCompanion.insert(
              id: 'r-$user',
              testId: 't-$user',
              drillId: 'F1',
              attempts: '{"shots":[]}',
              recordedAt: at,
            ),
          );
    }

    await signOutAndForget(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      userId: 'u1',
      forgetChatInFlight: (_) {},
    );

    expect((await db.select(db.playerRankRows).get()).map((r) => r.userId), [
      'u2',
    ]);
    expect((await db.select(db.buTestRows).get()).map((r) => r.id), ['t-u2']);
    expect((await db.select(db.buDrillResultRows).get()).map((r) => r.id), [
      'r-u2',
    ]);
  });

  test('đếm thứ chưa đồng bộ được của phần đánh giá, và lần đang dở', () async {
    final at = DateTime(2026, 10, 14);
    expect(await pendingAssessmentCount(db, 'u1'), 0);
    expect(await hasActiveTest(db, 'u1'), isFalse);
    await db
        .into(db.playerRankRows)
        .insert(
          PlayerRankRowsCompanion.insert(
            userId: 'u1',
            onboardingState: 'skipped',
            updatedAt: at,
          ),
        );
    await db
        .into(db.buTestRows)
        .insert(
          BuTestRowsCompanion.insert(
            id: 'xong',
            userId: 'u1',
            startedAt: at,
            tableSize: 'nineFootPlus',
            completedAt: Value(at),
          ),
        );
    await db
        .into(db.buTestRows)
        .insert(
          BuTestRowsCompanion.insert(
            id: 'do',
            userId: 'u1',
            startedAt: at,
            tableSize: 'nineFootPlus',
          ),
        );
    expect(
      await pendingAssessmentCount(db, 'u1'),
      2,
      reason: 'dòng hạng + lần đã hoàn tất; lần đang dở không đồng bộ được',
    );
    expect(await hasActiveTest(db, 'u1'), isTrue);
  });

  test('đăng xuất xoá mục tiêu và thành tích của người đó; đếm được dòng chưa đồng bộ', () async {
    final at = DateTime(2026, 10, 15, 9);
    await db
        .into(db.playerGoalRows)
        .insert(PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: at));
    await db
        .into(db.achievementRows)
        .insert(
          AchievementRowsCompanion.insert(
            id: 'x',
            userId: 'u1',
            kind: 'chuoiNgay',
            refId: '7',
            achievedAt: at,
          ),
        );
    await db
        .into(db.playerGoalRows)
        .insert(PlayerGoalRowsCompanion.insert(userId: 'u2', updatedAt: at));

    expect(await pendingRoadmapCount(db, 'u1'), 2);
    await signOutAndForget(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      userId: 'u1',
      forgetChatInFlight: (_) {},
    );

    expect((await db.select(db.playerGoalRows).get()).map((r) => r.userId), [
      'u2',
    ]);
    expect(await db.select(db.achievementRows).get(), isEmpty);
  });

  test('đăng xuất và quên: xoá lịch sử Coach Chat của người này, giữ của người khác (I1, review cuối)', () async {
    final at = DateTime(2026, 10, 22, 9);
    for (final user in ['u1', 'u2']) {
      await CoachChatRepository(db, userId: user).addExchange(
        question: 'Câu hỏi của $user',
        askedAt: at,
        reply: (text: 'Câu trả lời cho $user', insufficient: false),
        answeredAt: at,
      );
    }
    await signOutAndForget(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      userId: 'u1',
      forgetChatInFlight: (_) {},
    );
    expect((await db.select(db.coachChatTurnRows).get()).map((r) => r.userId), [
      'u2',
      'u2',
    ]);
  });

  test(
    'đăng xuất xoá lần kiểm tra kỹ năng của người đó, giữ của người khác',
    () async {
      await db
          .into(db.skillTestRows)
          .insert(
            toSkillTestRow(
              passedTest('a1', 1, DateTime(2026, 10, 28, 10), id: 'st-u1'),
              userId: 'u1',
            ),
          );
      await db
          .into(db.skillTestRows)
          .insert(
            toSkillTestRow(
              passedTest('a1', 1, DateTime(2026, 10, 28, 10), id: 'st-u2'),
              userId: 'u2',
            ),
          );
      await signOutAndForget(
        db: db,
        auth: FakeAuthRepository.signedIn(),
        userId: 'u1',
        forgetChatInFlight: (_) {},
      );
      expect((await db.select(db.skillTestRows).get()).map((r) => r.id), [
        'st-u2',
      ]);
    },
  );

  test('lần kiểm tra kỹ năng chưa đồng bộ tính vào phần đánh giá', () async {
    final at = DateTime(2026, 10, 28, 10);
    await db
        .into(db.skillTestRows)
        .insert(
          toSkillTestRow(passedTest('a1', 1, at, id: 'cho'), userId: 'u1'),
        );
    await db
        .into(db.skillTestRows)
        .insert(
          toSkillTestRow(
            failedTest('a1', 1, at, id: 'da'),
            userId: 'u1',
            syncedAt: at,
          ),
        );
    await db
        .into(db.skillTestRows)
        .insert(
          toSkillTestRow(passedTest('a1', 1, at, id: 'khac'), userId: 'u2'),
        );
    expect(await pendingAssessmentCount(db, 'u1'), 1);
  });
}
