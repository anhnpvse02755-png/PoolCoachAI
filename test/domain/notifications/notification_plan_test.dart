import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

void main() {
  // Thứ Ba 2026-10-13 (weekday 2 -> day index 1).
  final now = DateTime(2026, 10, 13, 10);

  CueEquipment cue(String id, DateTime? due, {String name = 'Cơ A'}) =>
      CueEquipment(
        id: id,
        name: name,
        type: CueType.playing,
        skillCategories: const [],
        tipMaintenanceDueDate: due,
      );

  ScheduleSlot slot(
    String id,
    int day,
    String time, {
    String label = 'Tập ngắm',
    SkillCategory? cat,
  }) => ScheduleSlot(id: id, day: day, time: time, label: label, cat: cat);

  const noStreak = StreakState(days: 0, practicedToday: false);

  List<PlannedNotification> plan({
    List<CueEquipment> cues = const [],
    List<ScheduleSlot> slots = const [],
    StreakState streak = noStreak,
    NotificationPrefs prefs = const NotificationPrefs(),
    DateTime? at,
    int limit = maxPendingNotifications,
  }) => planNotifications(
    cues: cues,
    slots: slots,
    streak: streak,
    prefs: prefs,
    now: at ?? now,
    limit: limit,
  );

  group('maintenance', () {
    test('the 7-days-before slot of today is dropped once 09:00 passed', () {
      final result = plan(cues: [cue('c1', DateTime(2026, 10, 20))]);
      expect(result.map((n) => n.at), [DateTime(2026, 10, 20, 9)]);
    });

    test('a past 09:00 is dropped, a future one is kept', () {
      final result = plan(cues: [cue('c1', DateTime(2026, 10, 21))]);

      expect(result.map((n) => n.at), [
        DateTime(2026, 10, 14, 9),
        DateTime(2026, 10, 21, 9),
      ]);
      expect(result.every((n) => n.kind == NotificationKind.maintenance), true);
      expect(result.first.title, Vi.equipmentNotificationTitle);
      expect(result.first.body, Vi.equipmentNotificationBody('Cơ A', 7));
      expect(result.last.body, Vi.equipmentNotificationBody('Cơ A', 0));
    });

    test('cue without a due date yields nothing', () {
      expect(plan(cues: [cue('c1', null)]), isEmpty);
    });

    test('toggle off removes the kind', () {
      final result = plan(
        cues: [cue('c1', DateTime(2026, 10, 21))],
        prefs: const NotificationPrefs(maintenance: false),
      );
      expect(result, isEmpty);
    });

    test('is not limited to 7 days ahead', () {
      final result = plan(cues: [cue('c1', DateTime(2026, 12, 1))]);
      expect(result.map((n) => n.at), [
        DateTime(2026, 11, 24, 9),
        DateTime(2026, 12, 1, 9),
      ]);
    });
  });

  group('schedule', () {
    test('fires 30 minutes before the slot start', () {
      // day 1 = Thứ Ba = today; 18:00 slot -> 17:30.
      final result = plan(
        slots: [slot('s1', 1, '18:00', cat: SkillCategory.aiming)],
      );
      expect(result.first.at, DateTime(2026, 10, 13, 17, 30));
      expect(result.first.kind, NotificationKind.schedule);
      expect(result.first.title, Vi.scheduleReminderTitle);
      expect(
        result.first.body,
        Vi.scheduleReminderBody('Tập ngắm', '18:00', 30, SkillCategory.aiming),
      );
    });

    test('weekly slot: only the occurrences inside the next 7 days', () {
      // Next Tuesday 17:30 is 7 days and 7.5 hours away: outside.
      expect(plan(slots: [slot('s1', 1, '18:00')]).map((n) => n.at), [
        DateTime(2026, 10, 13, 17, 30),
      ]);
      // Next Tuesday 08:30 is 6 days 22.5 hours away: inside, and the
      // one earlier today has passed.
      expect(plan(slots: [slot('s1', 1, '09:00')]).map((n) => n.at), [
        DateTime(2026, 10, 20, 8, 30),
      ]);
    });

    test('several slots on several days are all listed in order', () {
      final result = plan(slots: [slot('s2', 3, '19:00'), slot('s1', 2, '07:00')]);
      expect(result.map((n) => n.at), [
        DateTime(2026, 10, 14, 6, 30),
        DateTime(2026, 10, 15, 18, 30),
      ]);
    });

    test('a slot today whose reminder time has passed is skipped today', () {
      final result = plan(slots: [slot('s1', 1, '10:20')]);
      // 09:50 today already passed; next Tuesday 09:50 is inside the window.
      expect(result.map((n) => n.at), [DateTime(2026, 10, 20, 9, 50)]);
    });

    test('a slot starting right after midnight reminds the evening before', () {
      // Thứ Tư (day 2) 00:10 -> Thứ Ba 23:40.
      final result = plan(slots: [slot('s1', 2, '00:10')]);
      expect(result.first.at, DateTime(2026, 10, 13, 23, 40));
    });

    test('unparseable time is ignored', () {
      expect(plan(slots: [slot('s1', 1, 'abc'), slot('s2', 1, '25:00')]), isEmpty);
    });

    test('no category line when the slot has none', () {
      final body = plan(slots: [slot('s1', 1, '18:00')]).first.body;
      expect(body, isNot(contains('Nhóm kỹ năng')));
    });

    test('toggle off removes the kind', () {
      expect(
        plan(
          slots: [slot('s1', 1, '18:00')],
          prefs: const NotificationPrefs(schedule: false),
        ),
        isEmpty,
      );
    });
  });

  group('streak', () {
    test('streak >= 2 and not practiced today: 20:00 today', () {
      final result = plan(
        streak: const StreakState(days: 3, practicedToday: false),
      );
      expect(result, hasLength(1));
      expect(result.single.kind, NotificationKind.streak);
      expect(result.single.at, DateTime(2026, 10, 13, 20));
      expect(result.single.title, Vi.streakReminderTitle);
      expect(result.single.body, Vi.streakReminderBody(3));
    });

    test('streak 0, 1: nothing', () {
      for (final days in [0, 1]) {
        expect(
          plan(streak: StreakState(days: days, practicedToday: false)),
          isEmpty,
          reason: 'days=$days',
        );
      }
    });

    test('streak of exactly 2 qualifies', () {
      expect(
        plan(streak: const StreakState(days: 2, practicedToday: false)),
        hasLength(1),
      );
    });

    test('already practiced today: nothing', () {
      expect(
        plan(streak: const StreakState(days: 5, practicedToday: true)),
        isEmpty,
      );
    });

    test('after 20:00 today: nothing', () {
      expect(
        plan(
          streak: const StreakState(days: 5, practicedToday: false),
          at: DateTime(2026, 10, 13, 20, 1),
        ),
        isEmpty,
      );
    });

    test('toggle off removes the kind', () {
      expect(
        plan(
          streak: const StreakState(days: 5, practicedToday: false),
          prefs: const NotificationPrefs(streak: false),
        ),
        isEmpty,
      );
    });
  });

  group('streakStateOf', () {
    DrillLog log(DateTime date) =>
        DrillLog(id: '$date', drillId: 'd1', date: date, score: 1);
    TimerSession timer(DateTime date) =>
        TimerSession(id: '$date', date: date, durationSec: 60);

    test('days counted through yesterday when today is empty', () {
      final state = streakStateOf(
        logs: [log(DateTime(2026, 10, 11, 8)), log(DateTime(2026, 10, 12, 8))],
        timerSessions: const [],
        today: now,
      );
      expect(state.days, 2);
      expect(state.practicedToday, isFalse);
    });

    test('a timer session today counts as practice', () {
      final state = streakStateOf(
        logs: [log(DateTime(2026, 10, 12, 8))],
        timerSessions: [timer(DateTime(2026, 10, 13, 7))],
        today: now,
      );
      expect(state.days, 2);
      expect(state.practicedToday, isTrue);
    });

    test('no activity', () {
      final state = streakStateOf(
        logs: const [],
        timerSessions: const [],
        today: now,
      );
      expect(state.days, 0);
      expect(state.practicedToday, isFalse);
    });
  });

  group('whole plan', () {
    test('sorted by time with distinct, stable ids', () {
      final inputs = (
        cues: [cue('c1', DateTime(2026, 10, 21))],
        slots: [slot('s1', 1, '18:00'), slot('s2', 3, '19:00')],
        streak: const StreakState(days: 4, practicedToday: false),
      );
      List<PlannedNotification> run() => plan(
        cues: inputs.cues,
        slots: inputs.slots,
        streak: inputs.streak,
      );
      final first = run();

      expect(first.map((n) => n.at).toList(), [
        ...first.map((n) => n.at),
      ]..sort());
      expect(first.map((n) => n.id).toSet(), hasLength(first.length));
      expect(run().map((n) => n.id), first.map((n) => n.id));
      expect(first.map((n) => n.kind).toSet(), NotificationKind.values.toSet());
    });

    test('id changes when the text changes (renamed cue)', () {
      final a = plan(cues: [cue('c1', DateTime(2026, 10, 21), name: 'A')]);
      final b = plan(cues: [cue('c1', DateTime(2026, 10, 21), name: 'B')]);
      expect(a.first.id, isNot(b.first.id));
    });

    test('limit keeps the earliest notifications', () {
      final result = plan(
        cues: [cue('c1', DateTime(2026, 10, 21))],
        slots: [slot('s1', 1, '18:00')],
        limit: 2,
      );
      expect(result, hasLength(2));
      expect(result.map((n) => n.at), [
        DateTime(2026, 10, 13, 17, 30),
        DateTime(2026, 10, 14, 9),
      ]);
    });

    test('all toggles off yields an empty plan', () {
      expect(
        plan(
          cues: [cue('c1', DateTime(2026, 10, 21))],
          slots: [slot('s1', 1, '18:00')],
          streak: const StreakState(days: 4, practicedToday: false),
          prefs: const NotificationPrefs(
            maintenance: false,
            schedule: false,
            streak: false,
          ),
        ),
        isEmpty,
      );
    });

    test('validUntil: slot start for schedule, end of day otherwise', () {
      final all = plan(
        cues: [cue('c1', DateTime(2026, 10, 14))],
        slots: [slot('s1', 1, '18:00')],
        streak: const StreakState(days: 4, practicedToday: false),
      );
      for (final n in all) {
        switch (n.kind) {
          case NotificationKind.schedule:
            expect(n.validUntil, DateTime(2026, 10, 13, 18));
          case NotificationKind.maintenance:
            expect(n.validUntil, DateTime(2026, 10, 15));
          case NotificationKind.streak:
            expect(n.validUntil, DateTime(2026, 10, 14));
        }
      }
    });

    test('a nearer-than-7-days horizon does not hide the 20:00 streak', () {
      expect(
        plan(
          streak: const StreakState(days: 4, practicedToday: false),
          at: DateTime(2026, 10, 13, 0, 0),
        ).single.at,
        DateTime(2026, 10, 13, 20),
      );
    });
  });
}
