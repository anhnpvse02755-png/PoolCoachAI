import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/seed/seed_drills.dart';
import 'package:poolcoachai/data/seed/seed_knowledge.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/server/notify_plan.dart';

import '../support/push_fixtures.dart';

void main() {
  const onlyStreak = NotificationPrefs(
    recommendation: false,
    maintenance: false,
    schedule: false,
  );
  const onlyRecommendation = NotificationPrefs(
    maintenance: false,
    schedule: false,
    streak: false,
  );

  NotifyPlanRequest request(
    Map<String, List<Map<String, Object?>>> data, {
    required DateTime nowUtc,
    String tz = 'Asia/Ho_Chi_Minh',
    NotifyPlanMode mode = NotifyPlanMode.upcoming,
    NotificationPrefs prefs = const NotificationPrefs(),
    ({SkillCategory cat, String drillId, DateTime atUtc})? seen,
    List<({String key, DateTime atUtc})> sent = const [],
  }) => NotifyPlanRequest(
    userId: 'u1',
    nowUtc: nowUtc,
    tz: tz,
    mode: mode,
    prefs: prefs,
    seen: seen,
    sentRecommendations: sent,
    data: data,
  );

  List<ServerPlannedNotification> plan(
    NotifyPlanRequest r, {
    WallClock? clock,
  }) => planForUser(
    r,
    drills: seedDrills,
    knowledge: seedKnowledge,
    clock: clock ?? TzWallClock(r.tz),
  );

  /// Hai buổi tập ở hai ngày (UTC) cho chuỗi 2 ngày.
  Map<String, List<Map<String, Object?>>> twoDays(DateTime a, DateTime b) => {
    ...emptyRemoteData(),
    'drill_logs': [
      drillLogRow(id: 'l1', drillId: 'd1', date: a),
      drillLogRow(id: 'l2', drillId: 'd3', date: b),
    ],
  };

  test('múi giờ Asia/Ho_Chi_Minh: nhắc chuỗi 20:00 là 13:00Z', () {
    final items = plan(
      request(
        // 19:00 giờ Việt Nam ngày 27 và 26/10.
        twoDays(DateTime.utc(2026, 10, 27, 12), DateTime.utc(2026, 10, 26, 12)),
        nowUtc: DateTime.utc(2026, 10, 28, 3), // 10:00 giờ Việt Nam
        prefs: onlyStreak,
      ),
    );
    final streak = items.single;
    expect(streak.local.kind, NotificationKind.streak);
    expect(streak.local.at, DateTime(2026, 10, 28, 20));
    expect(streak.atUtc, DateTime.utc(2026, 10, 28, 13));
    expect(streak.validUntilUtc, DateTime.utc(2026, 10, 28, 17));
    expect(streak.local.title, Vi.streakReminderTitle);
    expect(streak.local.body, Vi.streakReminderBody(2));
  });

  test('múi giờ có đổi giờ (America/New_York): 20:00 trước và sau 1/11/2026 ra đúng UTC', () {
    // Trước: 31/10 là giờ mùa hè (UTC−4). Buổi tập 12:00 ngày 30 và 29/10.
    final before = plan(
      request(
        twoDays(DateTime.utc(2026, 10, 30, 16), DateTime.utc(2026, 10, 29, 16)),
        nowUtc: DateTime.utc(2026, 10, 31, 14), // 10:00 EDT
        tz: 'America/New_York',
        prefs: onlyStreak,
      ),
    ).single;
    expect(before.local.at, DateTime(2026, 10, 31, 20));
    expect(before.atUtc, DateTime.utc(2026, 11, 1, 0));
    expect(before.validUntilUtc, DateTime.utc(2026, 11, 1, 4));

    // Sau: 1/11 đã về giờ mùa đông (UTC−5). Buổi tập 12:00 ngày 31 và 30/10.
    final after = plan(
      request(
        twoDays(DateTime.utc(2026, 10, 31, 16), DateTime.utc(2026, 10, 30, 16)),
        nowUtc: DateTime.utc(2026, 11, 1, 15), // 10:00 EST
        tz: 'America/New_York',
        prefs: onlyStreak,
      ),
    ).single;
    expect(after.local.at, DateTime(2026, 11, 1, 20));
    expect(after.atUtc, DateTime.utc(2026, 11, 2, 1));
    expect(after.validUntilUtc, DateTime.utc(2026, 11, 2, 5));
  });

  test('TzWallClock: tên múi lạ ném ArgumentError', () {
    expect(() => TzWallClock('Moon/Tranquility'), throwsArgumentError);
    expect(() => TzWallClock(''), throwsArgumentError);
  });

  test(
    'chống bịa: đổi nhóm yếu thì thân thông báo gợi ý đổi theo Vi.skill',
    () {
      // 07:00 giờ máy: gợi ý 08:00 hôm nay còn ở phía sau.
      final now = DateTime(2026, 10, 28, 7);
      ({String body, SkillCategory cat}) scenario(String weak, String strong) {
        final logs = [
          for (var d = 5; d >= 1; d--) ...[
            DrillLog(
              id: 'w$d',
              drillId: weak,
              date: DateTime(2026, 10, 28 - d, 18),
              score: 1,
              attempts: 10,
            ),
            DrillLog(
              id: 's$d',
              drillId: strong,
              date: DateTime(2026, 10, 28 - d, 19),
              score: 10,
              attempts: 10,
            ),
          ],
        ];
        final data = {
          ...emptyRemoteData(),
          'drill_logs': [
            for (final l in logs)
              drillLogRow(
                id: l.id,
                drillId: l.drillId,
                date: l.date,
                score: l.score.toDouble(),
                attempts: l.attempts,
              ),
          ],
        };
        final item = plan(
          request(data, nowUtc: now.toUtc(), prefs: onlyRecommendation),
          clock: const HostWallClock(),
        ).firstWhere((s) => s.local.at == DateTime(2026, 10, 28, 8));
        final rec = RecommendationInputs(
          drills: seedDrills,
          logs: logs,
          knowledge: seedKnowledge,
          timerSessions: const [],
          schedule: const [],
          matches: const [],
        ).recommendFor(item.local.at);
        expect(item.local.title, Vi.recommendationReminderTitle);
        expect(
          item.local.body,
          Vi.recommendationReminderBody(
            rec.drill!.name,
            rec.cat,
            Vi.pickReason(
              rec.reason,
              Vi.skill(rec.cat),
              signal: rec.matchSignal,
            ),
          ),
        );
        expect(item.local.body, startsWith(Vi.skill(rec.cat)));
        return (body: item.local.body, cat: rec.cat);
      }

      final aimingWeak = scenario('d1', 'd3');
      final positionWeak = scenario('d3', 'd1');
      expect(aimingWeak.cat, isNot(positionWeak.cat));
      expect(aimingWeak.body, isNot(positionWeak.body));
    },
  );

  group(
    'dữ liệu hỏng ở một collection: ném NotifyPlanDataError, không đoán',
    () {
      final nowUtc = DateTime.utc(2026, 10, 28, 3);
      final rich = richRemoteData(nowUtc: nowUtc);
      final broken = <String, Map<String, Object?>>{
        'drill_logs': {...rich['drill_logs']!.first, 'date': 'hôm qua'},
        'timer_sessions': {
          ...rich['timer_sessions']!.first,
          'duration_sec': -1,
        },
        'schedule_slots': {...rich['schedule_slots']!.first, 'day': 9},
        'cue_equipment': {...rich['cue_equipment']!.first, 'type': 'laser'},
        'pool_matches': {...rich['pool_matches']!.first, 'shots': 'không'},
      };
      for (final MapEntry(key: collection, value: row) in broken.entries) {
        test(collection, () {
          final data = {
            ...rich,
            collection: [...rich[collection]!, row],
          };
          expect(
            () => plan(request(data, nowUtc: nowUtc)),
            throwsA(
              isA<NotifyPlanDataError>().having(
                (e) => e.collection,
                'collection',
                collection,
              ),
            ),
          );
        });
      }

      test('dòng của người khác', () {
        final data = {
          ...rich,
          'drill_logs': [
            ...rich['drill_logs']!,
            drillLogRow(
              id: 'x',
              drillId: 'd1',
              date: DateTime.utc(2026, 10, 27),
              userId: 'u2',
            ),
          ],
        };
        expect(
          () => plan(request(data, nowUtc: nowUtc)),
          throwsA(
            isA<NotifyPlanDataError>().having(
              (e) => e.collection,
              'collection',
              'drill_logs',
            ),
          ),
        );
      });

      test('thiếu hẳn một collection', () {
        final data = {...rich}..remove('schedule_slots');
        expect(
          () => plan(request(data, nowUtc: nowUtc)),
          throwsA(
            isA<NotifyPlanDataError>().having(
              (e) => e.collection,
              'collection',
              'schedule_slots',
            ),
          ),
        );
      });
    },
  );

  test('BU hỏng: lập như không có BU (như app khi latestBuResult lỗi)', () {
    // 07:00 giờ máy: gợi ý 08:00 hôm nay theo nhóm yếu của BU.
    final nowUtc = DateTime(2026, 10, 28, 7).toUtc();
    final rich = buSensitiveRemoteData(nowUtc: nowUtc);
    List<String> sigs(Map<String, List<Map<String, Object?>>> data) => [
      for (final s in plan(
        request(data, nowUtc: nowUtc),
        clock: const HostWallClock(),
      ))
        '${s.local.id}|${s.local.key}|${s.local.body}',
    ];
    final none = sigs({...rich, 'bu_tests': [], 'bu_drill_results': []});
    expect(sigs(rich), isNot(none), reason: 'BU nguyên vẹn phải đổi gợi ý');
    final brokenVariants = {
      'enum lạ': {
        ...rich,
        'bu_tests': [
          for (final t in rich['bu_tests']!) {...t, 'result_rank': 'zz'},
        ],
      },
      'thiếu ngày': {
        ...rich,
        'bu_drill_results': [
          for (final r in rich['bu_drill_results']!)
            {...r, 'recorded_at': null},
        ],
      },
      'attempts hỏng': {
        ...rich,
        'bu_drill_results': [
          for (final r in rich['bu_drill_results']!) {...r, 'attempts': 7},
        ],
      },
      'của người khác': {
        ...rich,
        'bu_tests': [
          for (final t in rich['bu_tests']!) {...t, 'user_created': 'u2'},
        ],
      },
      'thiếu collection': {...rich}..remove('bu_drill_results'),
    };
    for (final MapEntry(key: name, value: data) in brokenVariants.entries) {
      expect(sigs(data), none, reason: name);
    }
  });

  test('đã gửi gợi ý X hôm qua: hôm nay cùng X không lập lại', () {
    // Cùng dữ liệu, gợi ý hôm qua và hôm nay là cùng cặp (nhóm, bài).
    final data = {
      ...emptyRemoteData(),
      'drill_logs': [
        for (var d = 6; d >= 2; d--)
          drillLogRow(
            id: 'l$d',
            drillId: 'd1',
            date: DateTime(2026, 10, 28 - d, 18),
            score: 0.2,
          ),
      ],
    };
    List<ServerPlannedNotification> at(
      DateTime now, {
      List<({String key, DateTime atUtc})> sent = const [],
    }) => plan(
      request(data, nowUtc: now.toUtc(), prefs: onlyRecommendation, sent: sent),
      clock: const HostWallClock(),
    );
    final yesterday = at(DateTime(2026, 10, 27, 7)).first;
    expect(yesterday.local.at, DateTime(2026, 10, 27, 8));
    final x = parseRecommendationKey(yesterday.local.key)!;
    bool hasX(List<ServerPlannedNotification> items) => items.any((s) {
      final p = parseRecommendationKey(s.local.key)!;
      return p.day == DateTime(2026, 10, 28) &&
          p.cat == x.cat &&
          p.drillId == x.drillId;
    });

    expect(hasX(at(DateTime(2026, 10, 28, 7))), isTrue);
    expect(
      hasX(
        at(
          DateTime(2026, 10, 28, 7),
          sent: [(key: yesterday.local.key, atUtc: yesterday.atUtc)],
        ),
      ),
      isFalse,
    );
  });

  test('payload là v2 mang userId', () {
    final nowUtc = DateTime.utc(2026, 10, 28, 3);
    final items = plan(request(richRemoteData(nowUtc: nowUtc), nowUtc: nowUtc));
    expect(items, isNotEmpty);
    for (final item in items) {
      final tap = parseNotificationPayload(item.payload)!;
      expect(item.payload, startsWith('v2|'));
      expect(tap.userId, 'u1');
      expect(tap.kind, item.local.kind);
      expect(tap.key, item.local.key);
    }
  });

  test('dòng đã xoá mềm không tạo nhắc', () {
    final now = DateTime(2026, 10, 28, 10);
    final rich = richRemoteData(nowUtc: now.toUtc());
    List<ServerPlannedNotification> run(
      Map<String, List<Map<String, Object?>>> data,
    ) => plan(request(data, nowUtc: now.toUtc()), clock: const HostWallClock());
    final items = run(rich);
    expect(items.where((s) => s.local.key.startsWith('s4:')), isEmpty);
    expect(items.where((s) => s.local.key.startsWith('c3:')), isEmpty);
    expect(items.where((s) => s.local.key.startsWith('s1:')), isNotEmpty);

    // Trận đã xoá không đổi gợi ý: như chưa từng có dòng đó.
    List<String> sigs(List<ServerPlannedNotification> l) => [
      for (final s in l) '${s.local.id}|${s.local.key}|${s.local.body}',
    ];
    final withoutDeleted = {
      for (final MapEntry(key: c, value: rows) in rich.entries)
        c: [
          for (final row in rows)
            if (row['is_deleted'] != true) row,
        ],
    };
    expect(sigs(items), sigs(run(withoutDeleted)));
  });

  test('cặp đã thấy: nhóm lạ (của bản sau) thì coi như chưa thấy', () {
    final at = DateTime.utc(2026, 10, 28, 1);
    expect(seenPairOf(cat: 'nhomTuongLai', drillId: 'd1', atUtc: at), isNull);
    expect(seenPairOf(cat: 'aiming', drillId: '', atUtc: at), isNull);
    expect(seenPairOf(cat: 'nhayBi', drillId: 'd1', atUtc: at), (
      cat: SkillCategory.nhayBi,
      drillId: 'd1',
      atUtc: at,
    ));
  });

  test('trường xin cho từng collection: đủ bảy, có user_created', () {
    expect(notifyPlanCollectionFields.keys, notifyPlanCollections);
    for (final fields in notifyPlanCollectionFields.values) {
      expect(fields.split(','), contains('user_created'));
      expect(fields.split(',').where((f) => f == 'user_created'), hasLength(1));
    }
  });
}
