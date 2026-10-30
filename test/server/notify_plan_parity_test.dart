import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/notification_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/data/repositories/drift_repositories.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/data/sync/assessment_sync.dart';
import 'package:poolcoachai/data/sync/cue_equipment_sync.dart';
import 'package:poolcoachai/data/sync/practice_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/server/notify_plan.dart';

import '../support/fake_auth.dart';
import '../support/fake_directus.dart';
import '../support/fake_recommendation_seen_store.dart';
import '../support/push_fixtures.dart';

/// Đường app thật: dòng Directus → các dịch vụ đồng bộ → Drift → provider và
/// repository mà NotificationService dùng → planNotifications. Đường máy chủ:
/// cùng dòng đó → planForUser. Hai bên phải ra đúng cùng thông báo.
void main() {
  String sig(PlannedNotification n) =>
      '${n.id}|${n.kind.name}|${n.key}|${n.at}|${n.validUntil}|'
      '${n.title}|${n.body}';

  /// Container riêng của test này: chỉ thay DB, tài khoản, giờ và kho "đã
  /// thấy"; bài tập, kiến thức, buổi tập… đều đọc từ DB thật.
  ///
  /// Không thử lại provider lỗi: app thật thử lại (lùi dần, khoảng 40 giây)
  /// rồi mới coi BU là lỗi và tính gợi ý không có nó. Test lấy thẳng trạng
  /// thái cuối đó.
  ProviderContainer appContainer(
    AppDatabase db, {
    required DateTime now,
    required FakeRecommendationSeenStore seenStore,
  }) => ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository.signedIn(userId: 'u1'),
      ),
      nowProvider.overrideWithValue(() => now),
      recommendationSeenStoreProvider.overrideWithValue(seenStore),
    ],
  );

  /// Thân của [appPlan] trên [db]; mọi thứ cần huỷ được ghi vào [disposers].
  Future<List<PlannedNotification>> appPlanIn(
    AppDatabase db,
    List<void Function()> disposers,
    Map<String, List<Map<String, Object?>>> data, {
    required DateTime now,
    required NotifyPlanMode mode,
    required NotificationPrefs prefs,
    required SeenRecommendation? seen,
    required List<PlannedNotification> sent,
  }) async {
    await upsertSeed(db);

    final server = FakeDirectus();
    for (final MapEntry(key: c, value: rows) in data.entries) {
      server.routes['GET /items/$c'] = (_) => FakeDirectus.ok(rows);
    }
    for (final c in ['tournaments', 'player_ranks', 'skill_tests']) {
      server.routes['GET /items/$c'] = (_) => FakeDirectus.ok(<Object?>[]);
    }
    final auth = FakeAuthRepository.signedIn(userId: 'u1');
    final api = DirectusClient(
      client: server.client,
      baseUrl: FakeDirectus.baseUrl,
    );
    DateTime clock() => now;

    final drillSync = SyncService(db: db, auth: auth, api: api, now: clock);
    final practice = PracticeSyncService(
      db: db,
      auth: auth,
      api: api,
      now: clock,
    );
    final cues = CueEquipmentSyncService(
      db: db,
      auth: auth,
      api: api,
      now: clock,
    );
    final assessment = AssessmentSyncService(
      db: db,
      auth: auth,
      api: api,
      now: clock,
      onRankFetch: (_, _) {},
    );
    disposers.addAll([
      drillSync.dispose,
      practice.dispose,
      cues.dispose,
      assessment.dispose,
    ]);
    expect(
      [
        await drillSync.syncNow(),
        await practice.syncNow(),
        await cues.syncNow(),
      ],
      [SyncOutcome.done, SyncOutcome.done, SyncOutcome.done],
    );
    // BU hỏng có thể làm lượt đánh giá hỏng: đúng hành vi của app.
    await assessment.syncNow();

    final log = NotificationLogRepository(db, userId: 'u1');
    for (final n in sent) {
      await log.recordShown(n, at: n.at);
    }

    final seenStore = FakeRecommendationSeenStore();
    if (seen != null) seenStore.saved['u1'] = seen;
    final container = appContainer(db, now: now, seenStore: seenStore);
    disposers.add(container.dispose);
    container.listen(recommendationSourceProvider, (_, _) {});
    var source = container.read(recommendationSourceProvider);
    for (var i = 0; i < 50 && !(source.hasValue && !source.isLoading); i++) {
      await pumpEventQueue();
      source = container.read(recommendationSourceProvider);
    }
    expect(source.hasValue && !source.isLoading, isTrue, reason: '$source');
    final ready = source.requireValue;

    // Đọc như NotificationService._setUser.
    final cueList = await DriftCueEquipmentRepository(
      db,
      userId: 'u1',
      now: clock,
    ).watchAll().first;
    final slots = await DriftScheduleRepository(
      db,
      userId: 'u1',
      now: clock,
    ).watchAll().first;
    final logs = await DriftDrillLogRepository(
      db,
      userId: 'u1',
    ).watchAll().first;
    final timers = await DriftTimerSessionRepository(
      db,
      userId: 'u1',
    ).watchAll().first;

    final from = mode == NotifyPlanMode.due
        ? DateTime(now.year, now.month, now.day)
        : now;
    final plan = planNotifications(
      recommendation: ready.inputs,
      lastSeenRecommendation: recommendationBaseline(
        shownOnHome: ready.seen,
        log: await log.all(),
        now: now,
      ),
      cues: cueList,
      slots: slots,
      streak: streakStateOf(logs: logs, timerSessions: timers, today: from),
      prefs: prefs,
      now: from,
      limit: mode == NotifyPlanMode.due ? 1 << 20 : maxPendingNotifications,
    );
    return [
      for (final n in plan)
        if (mode == NotifyPlanMode.due
            ? !n.at.isAfter(now) && now.isBefore(n.validUntil)
            : n.at.isBefore(now.add(const Duration(hours: 24))))
          n,
    ];
  }

  /// Kế hoạch của app cho [data], như NotificationService: chế độ upcoming
  /// = `_plan(now)` lọc 24 giờ; chế độ due = `checkNow` trên web (lập từ đầu
  /// ngày, giữ mục `at ≤ now < validUntil`). [sent]: gợi ý đã giao, ghi vào
  /// nhật ký thật trước khi lập.
  Future<List<PlannedNotification>> appPlan(
    Map<String, List<Map<String, Object?>>> data, {
    required DateTime now,
    required NotifyPlanMode mode,
    NotificationPrefs prefs = const NotificationPrefs(),
    SeenRecommendation? seen,
    List<PlannedNotification> sent = const [],
  }) async {
    // Đóng ngay khi xong (không đợi tearDown): một test lập nhiều kế hoạch.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final disposers = <void Function()>[];
    try {
      return await appPlanIn(
        db,
        disposers,
        data,
        now: now,
        mode: mode,
        prefs: prefs,
        seen: seen,
        sent: sent,
      );
    } finally {
      for (final dispose in disposers.reversed) {
        dispose();
      }
      await db.close();
    }
  }

  List<ServerPlannedNotification> serverPlan(
    Map<String, List<Map<String, Object?>>> data, {
    required DateTime now,
    required NotifyPlanMode mode,
    NotificationPrefs prefs = const NotificationPrefs(),
    SeenRecommendation? seen,
    List<PlannedNotification> sent = const [],
    WallClock clock = const HostWallClock(),
    String tz = 'Asia/Ho_Chi_Minh',
  }) => planForUser(
    NotifyPlanRequest(
      userId: 'u1',
      nowUtc: now.toUtc(),
      tz: tz,
      mode: mode,
      prefs: prefs,
      seen: seen == null
          ? null
          : (cat: seen.cat, drillId: seen.drillId, atUtc: seen.at.toUtc()),
      sentRecommendations: [
        for (final n in sent) (key: n.key, atUtc: n.at.toUtc()),
      ],
      data: data,
    ),
    drills: seedDrills,
    knowledge: seedKnowledge,
    clock: clock,
  );

  /// So khớp đủ: id, loại, khoá, giờ, hạn, chữ, rồi payload và giờ UTC.
  void expectSame(
    List<ServerPlannedNotification> actual,
    List<PlannedNotification> expected,
  ) {
    expect(actual.map((s) => sig(s.local)), expected.map(sig));
    expect(
      actual.map((s) => s.payload),
      expected.map((n) => notificationPayload(n.kind, n.key, userId: 'u1')),
    );
    expect(actual.map((s) => s.atUtc), expected.map((n) => n.at.toUtc()));
    expect(
      actual.map((s) => s.validUntilUtc),
      expected.map((n) => n.validUntil.toUtc()),
    );
  }

  // 10:00 giờ máy: gợi ý 08:00 đã qua (chỉ còn của ngày mai), bảo dưỡng
  // 09:00 hôm nay đã qua, chuỗi 20:00 và khung chiều hôm nay còn ở phía sau.
  final morning = DateTime(2026, 10, 28, 10);

  test('đường app và đường máy chủ cho cùng kế hoạch: cùng id, kind, key, giờ, chữ', () async {
    final data = richRemoteData(nowUtc: morning.toUtc());
    final expected = await appPlan(
      data,
      now: morning,
      mode: NotifyPlanMode.upcoming,
    );
    final actual = serverPlan(
      data,
      now: morning,
      mode: NotifyPlanMode.upcoming,
    );
    expectSame(actual, expected);
    expect(
      NotificationKind.values.every(
        (k) => actual.any((n) => n.local.kind == k),
      ),
      isTrue,
      reason: actual.map((s) => sig(s.local)).join('\n'),
    );
  });

  test(
    'chế độ due giống web P6a: lập từ đầu ngày, chỉ mục at ≤ now < validUntil',
    () async {
      for (final now in [morning, DateTime(2026, 10, 28, 19, 59)]) {
        final data = richRemoteData(nowUtc: now.toUtc());
        final expected = await appPlan(
          data,
          now: now,
          mode: NotifyPlanMode.due,
        );
        final actual = serverPlan(data, now: now, mode: NotifyPlanMode.due);
        expectSame(actual, expected);
        expect(actual, isNotEmpty, reason: '$now');
      }
    },
  );

  test('tắt từng loại: hai đường vẫn khớp, loại tắt vắng mặt', () async {
    final data = richRemoteData(nowUtc: morning.toUtc());
    for (final kind in NotificationKind.values) {
      final prefs = const NotificationPrefs().toggled(kind, false);
      final expected = await appPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        prefs: prefs,
      );
      final actual = serverPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        prefs: prefs,
      );
      expectSame(actual, expected);
      expect(actual.where((s) => s.local.kind == kind), isEmpty);
    }
  });

  test(
    'cặp đã thấy và gợi ý đã gửi hôm qua: hai đường cùng mốc so sánh',
    () async {
      final data = richRemoteData(nowUtc: morning.toUtc());
      final first = serverPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
      );
      final rec = first.singleWhere(
        (s) => s.local.kind == NotificationKind.recommendation,
      );
      final pair = parseRecommendationKey(rec.local.key)!;

      // Đã thấy đúng cặp sắp gợi ý: gợi ý đó không còn.
      final seen = SeenRecommendation(
        cat: pair.cat,
        drillId: pair.drillId,
        at: morning.subtract(const Duration(hours: 1)),
      );
      final expectedSeen = await appPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        seen: seen,
      );
      final actualSeen = serverPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        seen: seen,
      );
      expectSame(actualSeen, expectedSeen);
      expect(actualSeen.any((s) => s.local.key == rec.local.key), isFalse);

      // Gợi ý của hôm qua đã giao, mới hơn cặp đã thấy cũ.
      final yesterday = morning.subtract(const Duration(days: 1));
      final sentYesterday = serverPlan(
        data,
        now: DateTime(yesterday.year, yesterday.month, yesterday.day, 7),
        mode: NotifyPlanMode.upcoming,
      ).where((s) => s.local.kind == NotificationKind.recommendation).first;
      final oldSeen = SeenRecommendation(
        cat: pair.cat,
        drillId: 'd1',
        at: morning.subtract(const Duration(days: 3)),
      );
      final expectedSent = await appPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        seen: oldSeen,
        sent: [sentYesterday.local],
      );
      final actualSent = serverPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        seen: oldSeen,
        sent: [sentYesterday.local],
      );
      expectSame(actualSent, expectedSent);
    },
  );

  /// Hai đường khớp với BU nguyên vẹn, vắng, và hỏng theo nhiều cách, ở cả
  /// hai chế độ.
  Future<void> expectBuVariantsMatch(
    Map<String, List<Map<String, Object?>>> rich, {
    required DateTime upcomingNow,
  }) async {
    final variants = <String, Map<String, List<Map<String, Object?>>>>{
      'có BU': rich,
      'không BU': {...rich, 'bu_tests': [], 'bu_drill_results': []},
      'enum lạ': {
        ...rich,
        'bu_tests': [
          for (final t in rich['bu_tests']!) {...t, 'table_size': 'tuongLai'},
        ],
      },
      'attempts hỏng': {
        ...rich,
        'bu_drill_results': [
          for (final r in rich['bu_drill_results']!)
            {
              ...r,
              'attempts': {'la': 1},
            },
        ],
      },
      'thiếu bản Đề II': {
        ...rich,
        'bu_tests': [
          for (final t in rich['bu_tests']!) {...t, 'exam_ii_version': null},
        ],
      },
    };
    for (final MapEntry(key: name, value: data) in variants.entries) {
      for (final mode in NotifyPlanMode.values) {
        final now = mode == NotifyPlanMode.due
            ? DateTime(2026, 10, 28, 19)
            : upcomingNow;
        final expected = await appPlan(data, now: now, mode: mode);
        final actual = serverPlan(data, now: now, mode: mode);
        expect(
          actual.map((s) => sig(s.local)),
          expected.map(sig),
          reason: '$name / ${mode.name}',
        );
      }
    }
  }

  test('BU có, không có, hỏng: hai đường vẫn khớp', () async {
    // 07:00: gợi ý 08:00 hôm nay do nhóm yếu theo BU quyết định.
    final early = DateTime(2026, 10, 28, 7);
    final sensitive = buSensitiveRemoteData(nowUtc: early.toUtc());
    List<String> recBodies(Map<String, List<Map<String, Object?>>> data) => [
      for (final s in serverPlan(
        data,
        now: early,
        mode: NotifyPlanMode.upcoming,
      ))
        if (s.local.kind == NotificationKind.recommendation) s.local.body,
    ];
    expect(
      recBodies(sensitive),
      isNot(recBodies({...sensitive, 'bu_tests': [], 'bu_drill_results': []})),
      reason: 'dữ liệu này phải làm BU đổi gợi ý, kẻo so khớp BU vô nghĩa',
    );
    await expectBuVariantsMatch(sensitive, upcomingNow: early);
    await expectBuVariantsMatch(
      richRemoteData(nowUtc: morning.toUtc()),
      upcomingNow: morning,
    );
  });

  test(
    'múi Asia/Ho_Chi_Minh qua TzWallClock: khớp đường app trên máy giờ Việt Nam',
    () async {
      final data = richRemoteData(nowUtc: morning.toUtc());
      final expected = await appPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
      );
      final actual = serverPlan(
        data,
        now: morning,
        mode: NotifyPlanMode.upcoming,
        clock: TzWallClock('Asia/Ho_Chi_Minh'),
      );
      expectSame(actual, expected);
    },
    skip: _hostIsVietnam()
        ? false
        : 'chỉ so được với đường app khi máy chạy test ở giờ Việt Nam',
  );
}

/// Máy chạy test ở UTC+7 quanh năm (đường app dùng giờ của máy).
bool _hostIsVietnam() =>
    [for (var m = 1; m <= 12; m++) DateTime(2026, m, 15).timeZoneOffset]
        .every((o) => o == const Duration(hours: 7));
