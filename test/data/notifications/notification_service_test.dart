import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncError, AsyncLoading, AsyncValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/notifications/notification_log_repository.dart';
import 'package:poolcoachai/data/notifications/notification_platform.dart';
import 'package:poolcoachai/data/notifications/notification_scheduler.dart';
import 'package:poolcoachai/data/notifications/notification_service.dart';
import 'package:poolcoachai/data/repositories/drift_practice_repositories.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeAuthRepository auth;
  late _FakeNotificationPlatform platform;
  late DateTime now;

  /// Lưới chống vòng lặp: mỗi lần đồng bộ đọc đồng hồ của dịch vụ. Quá
  /// [_maxClockReads] lần trong một test là dịch vụ tự kích mình mãi (đồng bộ
  /// → ghi nhật ký → nhật ký phát → đồng bộ…); ném để vòng dừng ngay và test
  /// đỏ thay vì treo máy.
  var clockReads = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    platform = _FakeNotificationPlatform();
    // Thứ Ba.
    now = DateTime(2026, 10, 13, 8, 59);
    clockReads = 0;
  });

  tearDown(() async {
    await db.close();
    expect(
      clockReads,
      lessThanOrEqualTo(_maxClockReads),
      reason: 'dịch vụ không hội tụ: vòng đồng bộ ↔ nhật ký',
    );
  });

  NotificationService service({
    NotificationPrefs? prefs = const NotificationPrefs(),
    NotificationPlatform? using,
  }) => NotificationService(
    db: db,
    auth: auth,
    now: () {
      if (++clockReads > _maxClockReads) {
        throw StateError('dịch vụ đọc đồng hồ quá $_maxClockReads lần');
      }
      return now;
    },
    platform: using ?? platform,
  )..setPrefs(prefs);

  Future<void> saveCue({String id = 'cue-1', DateTime? dueDate}) =>
      DriftCueEquipmentRepository(db, userId: 'u1', now: () => now).save(
        CueEquipment(
          id: id,
          name: 'Cơ test',
          type: CueType.playing,
          skillCategories: const [],
          tipMaintenanceDueDate: dueDate,
        ),
      );

  Future<void> saveSlot({
    String id = 's1',
    int day = 1,
    String time = '18:00',
    String label = 'Tập ngắm',
  }) => DriftScheduleRepository(db, userId: 'u1', now: () => now).save(
    ScheduleSlot(id: id, day: day, time: time, label: label),
  );

  Future<void> practice(DateTime at) =>
      DriftTimerSessionRepository(db, userId: 'u1').add(
        TimerSession(id: 't$at', date: at, durationSec: 600),
      );

  RecommendationInputs inputsWith(List<Drill> drills) => RecommendationInputs(
    drills: drills,
    logs: const [],
    knowledge: const [],
    timerSessions: const [],
    schedule: const [],
    matches: const [],
  );

  AsyncValue<RecommendationSource> source({
    String userId = 'u1',
    SeenRecommendation? seen,
    List<Drill>? drills,
  }) => AsyncData(
    RecommendationSource(
      userId: userId,
      inputs: inputsWith(drills ?? testDrills),
      seen: seen,
    ),
  );

  /// Cặp (nhóm, bài) của gợi ý ngày [day] lúc 08:00, đúng như bộ lập tính.
  SeenRecommendation pairOf(DateTime day, {required DateTime seenAt}) {
    final rec = inputsWith(testDrills).recommendFor(
      DateTime(day.year, day.month, day.day, recommendationReminderHour),
    );
    return SeenRecommendation(cat: rec.cat, drillId: rec.drill!.id, at: seenAt);
  }

  Future<List<NotificationLogRow>> logRows([String userId = 'u1']) async =>
      (await db.select(db.notificationLogRows).get())
          .where((r) => r.userId == userId)
          .toList();

  group('browser (timer)', () {
    test('sends once at 09:00 seven days before and on the due date', () async {
      await saveCue(dueDate: DateTime(2026, 10, 20));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      expect(platform.notifications, isEmpty);
      now = DateTime(2026, 10, 13, 9);
      reminders.checkNow();
      reminders.checkNow();
      expect(platform.notifications, hasLength(1));
      expect(platform.notifications.single.body, contains('sau 7 ngày'));
      // Khoá localStorage của bảo dưỡng giữ nguyên dạng cũ.
      expect(
        platform.storedValues.keys.single,
        'poolcoachai:maintenance:v1:u1:cue-1:2026-10-20:7',
      );

      now = DateTime(2026, 10, 20, 9);
      reminders.checkNow();
      expect(platform.notifications, hasLength(2));
      expect(platform.notifications.last.body, contains('hôm nay'));
    });

    test(
      'asks permission only on request and notifies after it is granted',
      () async {
        await saveCue(dueDate: DateTime(2026, 10, 13));
        final reminders = service()..start();
        addTearDown(reminders.dispose);
        await pumpEventQueue();
        now = DateTime(2026, 10, 13, 9);
        reminders.checkNow();
        expect(platform.notifications, isEmpty);

        expect(await reminders.requestPermission(), 'granted');
        expect(platform.permissionRequests, 1);
        expect(platform.notifications, hasLength(1));
      },
    );

    test('does not notify for a deleted cue or after sign-out', () async {
      await saveCue(dueDate: DateTime(2026, 10, 20));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      await DriftCueEquipmentRepository(db, userId: 'u1').remove('cue-1');
      await pumpEventQueue();

      now = DateTime(2026, 10, 20, 9);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      auth.emit(const SignedOut());
      await pumpEventQueue();
      await saveCue(id: 'cue-2', dueDate: DateTime(2026, 10, 20));
      await pumpEventQueue();
      reminders.checkNow();
      expect(platform.notifications, isEmpty);
    });

    test('schedule reminder: once, 30 minutes before the slot', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 17, 29);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      now = DateTime(2026, 10, 13, 17, 30);
      reminders.checkNow();
      reminders.checkNow();
      expect(platform.notifications, hasLength(1));
      expect(platform.notifications.single.body, contains('Tập ngắm'));
      expect(platform.notifications.single.body, contains('18:00'));
    });

    test('schedule reminder is not sent late, after the slot started', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 18, 5);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);
    });

    test('streak reminder at 20:00 only while today is unpracticed', () async {
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 19, 59);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      now = DateTime(2026, 10, 13, 20);
      reminders.checkNow();
      expect(platform.notifications, hasLength(1));
      expect(platform.notifications.single.body, contains('2 ngày'));
    });

    test('no streak reminder once today has a practice session', () async {
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      await practice(DateTime(2026, 10, 13, 12));
      platform.permissionValue = 'granted';
      final reminders = service()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 20, 30);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);
    });

    test('a disabled kind is not sent; enabling it later sends it', () async {
      await saveSlot(time: '18:00');
      platform.permissionValue = 'granted';
      final reminders = service(
        prefs: const NotificationPrefs(schedule: false),
      )..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      now = DateTime(2026, 10, 13, 17, 40);
      reminders.checkNow();
      expect(platform.notifications, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      expect(platform.notifications, hasLength(1));
    });

    test('sends nothing until the preferences have loaded', () async {
      await saveCue(dueDate: DateTime(2026, 10, 13));
      platform.permissionValue = 'granted';
      now = DateTime(2026, 10, 13, 9);
      final reminders = service(prefs: null)..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(platform.notifications, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      expect(platform.notifications, hasLength(1));
    });

    test(
      'tab mở trước 08:00: hiện gợi ý lúc 08:00 một lần, ghi nhật ký lúc hiện',
      () async {
        now = DateTime(2026, 10, 13, 7, 59);
        platform.permissionValue = 'granted';
        final s = service()
          ..start()
          ..setRecommendationSource(
            source(
              seen: SeenRecommendation(
                cat: SkillCategory.aiming,
                drillId: 'x',
                at: DateTime(2026, 10, 12),
              ),
            ),
          );
        addTearDown(s.dispose);
        await pumpEventQueue();
        expect(platform.notifications, isEmpty);

        now = DateTime(2026, 10, 13, 8);
        s.checkNow();
        s.checkNow();
        await pumpEventQueue();
        expect(
          platform.notifications.where(
            (n) => n.title == Vi.recommendationReminderTitle,
          ),
          hasLength(1),
        );
        expect((await logRows()).single.at, DateTime(2026, 10, 13, 8));

        // Nhật ký vừa phát lại (dòng mới) cũng không làm hiện lần hai.
        s.checkNow();
        await pumpEventQueue();
        expect(platform.notifications, hasLength(1));
      },
    );

    test('mở tab sau 08:00: không hiện gợi ý của sáng nay', () async {
      now = DateTime(2026, 10, 13, 8, 30);
      platform.permissionValue = 'granted';
      final s = service()
        ..start()
        ..setRecommendationSource(
          source(
            seen: SeenRecommendation(
              cat: SkillCategory.aiming,
              drillId: 'x',
              at: DateTime(2026, 10, 12),
            ),
          ),
        );
      addTearDown(s.dispose);
      await pumpEventQueue();
      s.checkNow();
      await pumpEventQueue();
      expect(
        platform.notifications.where(
          (n) => n.title == Vi.recommendationReminderTitle,
        ),
        isEmpty,
      );
      expect(await logRows(), isEmpty);
    });

    test('nguồn của tài khoản khác không hiện trên web', () async {
      now = DateTime(2026, 10, 13, 7, 59);
      platform.permissionValue = 'granted';
      final s = service()
        ..start()
        ..setRecommendationSource(source(userId: 'u2'));
      addTearDown(s.dispose);
      await pumpEventQueue();
      now = DateTime(2026, 10, 13, 8);
      s.checkNow();
      await pumpEventQueue();
      expect(platform.notifications, isEmpty);
    });
  });

  group('native scheduling', () {
    late _FakeScheduler scheduler;

    NotificationService scheduling({
      NotificationPrefs? prefs = const NotificationPrefs(),
    }) => service(prefs: prefs, using: _SchedulingPlatform(scheduler));

    setUp(() => scheduler = _FakeScheduler());
    tearDown(
      () => expect(
        scheduler.pendingIdsCalls,
        lessThanOrEqualTo(_maxPendingIdsCalls),
        reason: 'dịch vụ không hội tụ: đối chiếu lặp mãi',
      ),
    );

    test('schedules nothing until permission is granted', () async {
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(reminders.permission, 'default');
      expect(reminders.schedulesInBackground, isTrue);

      expect(await reminders.requestPermission(), 'granted');
      await pumpEventQueue();
      expect(scheduler.scheduled.map((n) => n.at), [
        DateTime(2026, 10, 13, 9),
        DateTime(2026, 10, 20, 9),
      ]);
    });

    test('picks up an existing grant and reschedules when cues change', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(reminders.permission, 'granted');
      expect(scheduler.scheduled, hasLength(2));

      await saveCue(id: 'cue-2', dueDate: DateTime(2026, 11, 20));
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(4));

      await DriftCueEquipmentRepository(db, userId: 'u1').remove('cue-2');
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(2));
    });

    test('reconcile only touches the difference', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduleCalls, 2);

      await saveSlot(time: '18:00');
      await pumpEventQueue();
      // Chỉ nhắc lịch tập mới được đặt thêm; cái bảo dưỡng giữ nguyên.
      expect(scheduler.scheduleCalls, 3);
      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.scheduled.map((n) => n.kind).toSet(), {
        NotificationKind.maintenance,
        NotificationKind.schedule,
      });
    });

    test('schedules schedule and streak reminders too', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();

      expect(scheduler.scheduled.map((n) => n.at), [
        DateTime(2026, 10, 13, 17, 30),
        DateTime(2026, 10, 13, 20),
      ]);
    });

    test('logging practice today cancels the pending streak reminder', () async {
      scheduler.granted = true;
      await practice(DateTime(2026, 10, 11, 10));
      await practice(DateTime(2026, 10, 12, 10));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));

      await practice(DateTime(2026, 10, 13, 8));
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, hasLength(1));
    });

    test('turning a kind off cancels it, turning it on schedules it', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));

      reminders.setPrefs(const NotificationPrefs(schedule: false));
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);

      reminders.setPrefs(const NotificationPrefs());
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(1));
    });

    test('does not touch the OS before preferences are loaded', () async {
      scheduler.granted = true;
      await saveSlot(time: '18:00');
      final reminders = scheduling(prefs: null)..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduleCalls, 0);
      expect(scheduler.cancelAllCalls, 0);
    });

    test('never schedules more than the pending cap', () async {
      scheduler.granted = true;
      for (var i = 0; i < 35; i++) {
        await saveCue(id: 'cue-$i', dueDate: DateTime(2026, 11, 1 + i % 20));
      }
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(maxPendingNotifications));
    });

    test('cancels everything on sign-out', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final reminders = scheduling()..start();
      addTearDown(reminders.dispose);
      await pumpEventQueue();
      expect(scheduler.scheduled, isNotEmpty);

      auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelAllCalls, greaterThan(0));
    });

    Iterable<PlannedNotification> recommendations() => scheduler.scheduled
        .where((n) => n.kind == NotificationKind.recommendation);

    test('gợi ý mới được đặt lúc 08:00 ngày mai và ghi vào nhật ký', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      final r = recommendations();
      expect(r.map((n) => n.at), [DateTime(2026, 10, 14, 8)]);
      expect((await logRows()).map((x) => x.id), contains(r.single.id));
      expect(s.recommendationSource.value?.userId, 'u1');
    });

    test('nguồn của tài khoản khác bị bỏ qua', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source(userId: 'u2'));
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(recommendations(), isEmpty);
      expect(await logRows(), isEmpty);
    });

    test(
      'kế hoạch đổi trước giờ giao: huỷ thông báo và xoá mục tương lai',
      () async {
        scheduler.granted = true;
        final s = scheduling()
          ..start()
          ..setRecommendationSource(source());
        addTearDown(s.dispose);
        await pumpEventQueue();
        final id = recommendations().single.id;

        // Trang chủ vừa hiện đúng cặp đó: không còn gì mới để báo.
        s.setRecommendationSource(
          source(seen: pairOf(DateTime(2026, 10, 14), seenAt: now)),
        );
        await pumpEventQueue();
        expect(scheduler.cancelled, contains(id));
        expect(recommendations(), isEmpty);
        expect((await logRows()).map((x) => x.id), isNot(contains(id)));
      },
    );

    test('mục đã tới giờ được giữ khi kế hoạch đổi', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      final id = recommendations().single.id;

      now = DateTime(2026, 10, 14, 8, 1);
      s.setRecommendationSource(
        source(seen: pairOf(DateTime(2026, 10, 14), seenAt: now)),
      );
      await pumpEventQueue();
      final row = (await logRows()).singleWhere((x) => x.id == id);
      expect(row.at, DateTime(2026, 10, 14, 8));
    });

    test(
      'chưa cấp quyền: không đặt gì, nhật ký không có mục tương lai',
      () async {
        // Một lần trước còn quyền đã ghi một mục cho ngày mai.
        await NotificationLogRepository(db, userId: 'u1').syncPlanned([
          PlannedNotification(
            id: 7,
            kind: NotificationKind.streak,
            key: 'k',
            at: DateTime(2026, 10, 14, 20),
            validUntil: DateTime(2026, 10, 15),
            title: 't',
            body: 'b',
          ),
        ], now: now);
        final s = scheduling()
          ..start()
          ..setRecommendationSource(source());
        addTearDown(s.dispose);
        await pumpEventQueue();
        expect(scheduler.scheduled, isEmpty);
        expect((await logRows()).where((x) => x.at.isAfter(now)), isEmpty);
      },
    );

    test('đã giao X: ngày mai cùng X không đặt lại', () async {
      scheduler.granted = true;
      final x = pairOf(DateTime(2026, 10, 14), seenAt: now);
      final delivered = DateTime(2026, 10, 13, 8);
      await NotificationLogRepository(db, userId: 'u1').recordShown(
        PlannedNotification(
          id: 9,
          kind: NotificationKind.recommendation,
          key: recommendationKey(DateTime(2026, 10, 13), x.cat, x.drillId),
          at: delivered,
          validUntil: DateTime(2026, 10, 14),
          title: Vi.recommendationReminderTitle,
          body: 'b',
        ),
        at: delivered,
      );
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(recommendations(), isEmpty);
      // Không phải đặt rồi huỷ khi nhật ký nạp xong: chưa từng được đặt.
      expect(
        scheduler.everScheduled.where(
          (n) => n.kind == NotificationKind.recommendation,
        ),
        isEmpty,
      );
    });

    /// Lần mở app trước: đã đặt gợi ý (và các loại khác) và ghi nhật ký. Trả
    /// về id của gợi ý; bộ đếm của [scheduler] được đặt lại.
    Future<int> previousRun() async {
      scheduler.granted = true;
      final first = scheduling()
        ..start()
        ..setRecommendationSource(source());
      await pumpEventQueue();
      final id = recommendations().single.id;
      first.dispose();
      await pumpEventQueue();
      scheduler
        ..cancelled.clear()
        ..everScheduled.clear()
        ..scheduleCalls = 0
        ..pendingIdsCalls = 0;
      return id;
    }

    test('mở app khi nguồn gợi ý còn đang tải: giữ nguyên gợi ý đã đặt', () async {
      final id = await previousRun();
      final s = scheduling()
        ..start()
        ..setRecommendationSource(const AsyncLoading());
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.everScheduled, isEmpty);
      expect(recommendations().map((n) => n.id), [id]);
      expect((await logRows()).map((x) => x.id), contains(id));
    });

    test('nguồn sẵn sàng với cặp khác: huỷ gợi ý cũ, đặt gợi ý mới', () async {
      final id = await previousRun();
      final s = scheduling()
        ..start()
        ..setRecommendationSource(const AsyncLoading());
      addTearDown(s.dispose);
      await pumpEventQueue();

      s.setRecommendationSource(source(drills: [_otherDrill]));
      await pumpEventQueue();
      expect(scheduler.cancelled, contains(id));
      final next = recommendations().single;
      expect(next.id, isNot(id));
      expect(next.key, contains(_otherDrill.id));
      expect((await logRows()).map((x) => x.id), [next.id]);
    });

    test(
      'nguồn gợi ý lỗi: bỏ gợi ý, các loại khác vẫn được đặt',
      () async {
        await saveCue(dueDate: DateTime(2026, 10, 20));
        await saveSlot(time: '18:00');
        await practice(DateTime(2026, 10, 11, 10));
        await practice(DateTime(2026, 10, 12, 10));
        final id = await previousRun();
        final s = scheduling()
          ..start()
          ..setRecommendationSource(
            AsyncError(StateError('hỏng'), StackTrace.empty),
          );
        addTearDown(s.dispose);
        await pumpEventQueue();
        expect(scheduler.cancelled, [id]);
        expect((await logRows()).map((x) => x.id), isNot(contains(id)));
        expect(scheduler.scheduled.map((n) => n.kind).toSet(), {
          NotificationKind.maintenance,
          NotificationKind.schedule,
          NotificationKind.streak,
        });
      },
    );

    test('nguồn đổi lỗi ↔ đang tải dồn dập: hội tụ về đúng trạng thái', () async {
      await previousRun();
      final s = scheduling()
        ..start()
        ..setRecommendationSource(const AsyncLoading());
      addTearDown(s.dispose);
      await pumpEventQueue();

      // Lỗi xoá gợi ý; đang tải ngay sau đó, khi luồng nhật ký chưa kịp phát
      // bản mới, không được thêm lại cái vừa xoá từ bản cũ.
      for (var i = 0; i < 6; i++) {
        s.setRecommendationSource(
          AsyncError(StateError('hỏng'), StackTrace.empty),
        );
        await Future<void>.delayed(Duration.zero);
        s.setRecommendationSource(const AsyncLoading());
        await Future<void>.delayed(Duration.zero);
      }
      await pumpEventQueue();
      final pendingReco = recommendations().map((n) => n.id).toSet();
      final futureRows = {
        for (final r in await logRows())
          if (r.at.isAfter(now) && r.kind == NotificationKind.recommendation.name)
            r.id,
      };
      // Lịch hệ điều hành và nhật ký khớp nhau, dù cuối cùng giữ hay mất.
      expect(pendingReco, futureRows);
    });

    test('nguồn đang tải mà tắt loại gợi ý: gợi ý đã đặt bị huỷ', () async {
      final id = await previousRun();
      final s = scheduling(
        prefs: const NotificationPrefs(recommendation: false),
      )
        ..start()
        ..setRecommendationSource(const AsyncLoading());
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(scheduler.cancelled, [id]);
      expect(await logRows(), isEmpty);
    });

    test('nguồn đang tải mà mất quyền: gợi ý đã giữ không còn trong nhật ký',
        () async {
      final id = await previousRun();
      scheduler.granted = false;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(const AsyncLoading());
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect((await logRows()).map((x) => x.id), isNot(contains(id)));
    });

    test('mở app: không huỷ rồi đặt lại thông báo bảo dưỡng đang chờ', () async {
      scheduler.granted = true;
      await saveCue(dueDate: DateTime(2026, 10, 20));
      final first = scheduling()..start();
      await pumpEventQueue();
      expect(scheduler.scheduled, hasLength(2));
      first.dispose();
      await pumpEventQueue();
      scheduler
        ..cancelled.clear()
        ..everScheduled.clear();

      final s = scheduling()..start();
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.everScheduled, isEmpty);
      expect(scheduler.scheduled, hasLength(2));
    });

    test('nhiều thay đổi dồn dập: số lần đồng bộ có giới hạn', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      final before = scheduler.pendingIdsCalls;

      for (var i = 0; i < 10; i++) {
        s
          ..setRecommendationSource(source())
          ..setPrefs(NotificationPrefs(streak: i.isEven));
      }
      await pumpEventQueue();
      expect(scheduler.pendingIdsCalls - before, lessThanOrEqualTo(2));
      expect(recommendations(), hasLength(1));
    });

    test('đăng xuất (không quên): mục tương lai của tài khoản cũ bị xoá', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      final id = recommendations().single.id;
      expect((await logRows()).map((x) => x.id), contains(id));

      auth.emit(const SignedOut());
      await pumpEventQueue();
      expect(await logRows(), isEmpty);

      // Quay lại sau giờ giao: hộp thư không được liệt kê cái đã huỷ.
      now = DateTime(2026, 10, 14, 9);
      auth.emit(const SignedIn(userId: 'u1', displayName: 'An'));
      await pumpEventQueue();
      expect((await logRows()).map((x) => x.id), isNot(contains(id)));
    });

    test('đổi thẳng sang tài khoản khác: mục tương lai của u1 bị xoá', () async {
      scheduler.granted = true;
      final s = scheduling()
        ..start()
        ..setRecommendationSource(source());
      addTearDown(s.dispose);
      await pumpEventQueue();
      expect(await logRows(), isNotEmpty);

      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await pumpEventQueue();
      expect(await logRows(), isEmpty);
      // Nguồn của u1 còn giữ nhưng không được dùng cho u2.
      expect(recommendations(), isEmpty);
      expect(await logRows('u2'), isEmpty);
    });
  });

  group('reconcileNotifications', () {
    PlannedNotification n(int id) => PlannedNotification(
      id: id,
      kind: NotificationKind.schedule,
      key: '$id',
      at: DateTime(2026, 10, 14),
      validUntil: DateTime(2026, 10, 15),
      title: 't',
      body: 'b',
    );

    test('cancels stale ids, schedules missing ones, keeps the rest', () async {
      final scheduler = _FakeScheduler()
        ..pending = {1: n(1), 2: n(2)};
      await reconcileNotifications(scheduler, [n(2), n(3)]);
      expect(scheduler.pending.keys, {2, 3});
      expect(scheduler.cancelled, [1]);
      expect(scheduler.scheduleCalls, 1);
    });
  });
}

/// Giới hạn của lưới chống vòng lặp: rộng hơn nhiều so với một test bình
/// thường, đủ hẹp để một vòng tự kích dừng sau vài giây.
const _maxClockReads = 2000;
const _maxPendingIdsCalls = 200;

/// Bài khác `testDrills` (cùng nhóm ngắm): dữ liệu chỉ có bài này thì gợi ý
/// đổi cặp.
const _otherDrill = Drill(
  id: 'd2',
  cat: SkillCategory.aiming,
  name: 'Đường chéo cơ bản',
  level: 1,
  unit: 'lần trúng / 10',
  passThreshold: 0.8,
  goal: 'Đánh chéo bi cái.',
  steps: ['Bước 1'],
);

class _FakeScheduler implements NotificationScheduler {
  bool granted = false;
  int permissionRequests = 0;
  Map<int, PlannedNotification> pending = {};
  List<int> cancelled = [];
  int scheduleCalls = 0;
  int cancelAllCalls = 0;
  int pendingIdsCalls = 0;

  /// Mọi thông báo từng được đặt, kể cả cái đã huỷ sau đó.
  final everScheduled = <PlannedNotification>[];

  List<PlannedNotification> get scheduled => pending.values.toList();

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted = true;
  }

  @override
  Future<Set<int>> pendingIds() async {
    // Lưới chống vòng lặp, như đồng hồ của dịch vụ.
    if (++pendingIdsCalls > _maxPendingIdsCalls) {
      throw StateError('đối chiếu quá $_maxPendingIdsCalls lần');
    }
    return pending.keys.toSet();
  }

  @override
  Future<void> schedule(PlannedNotification notification) async {
    scheduleCalls++;
    everScheduled.add(notification);
    pending[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending = {};
  }
}

class _SchedulingPlatform extends NotificationPlatform {
  _SchedulingPlatform(NotificationScheduler scheduler)
    : super(scheduler: scheduler);
}

class _FakeNotificationPlatform extends NotificationPlatform {
  @override
  NotificationScheduler? get scheduler => null;

  String permissionValue = 'default';
  int permissionRequests = 0;
  final notifications = <({String title, String body, String tag})>[];
  final storedValues = <String, String>{};

  @override
  bool get isSupported => true;

  @override
  String? get permission => permissionValue;

  @override
  Future<String?> requestPermission() async {
    permissionRequests++;
    permissionValue = 'granted';
    return permissionValue;
  }

  @override
  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    notifications.add((title: title, body: body, tag: tag));
  }

  @override
  String? readValue(String key) => storedValues[key];

  @override
  void writeValue(String key, String value) {
    storedValues[key] = value;
  }
}
