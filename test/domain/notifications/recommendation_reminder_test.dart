import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/test_data.dart';

void main() {
  // Thứ Ba 2026-10-13.
  final now = DateTime(2026, 10, 13, 7);
  const noStreak = StreakState(days: 0, practicedToday: false);
  const secondAimingDrill = Drill(
    id: 'd2',
    cat: SkillCategory.aiming,
    name: 'Đường chéo cơ bản',
    level: 1,
    unit: 'lần trúng / 10',
    passThreshold: 0.8,
    goal: 'g',
    steps: [],
  );
  const bankDrill = Drill(
    id: 'b1',
    cat: SkillCategory.bank,
    name: 'Cân bi một băng',
    level: 1,
    unit: 'lần / 10',
    passThreshold: 0.8,
    goal: 'g',
    steps: [],
  );

  RecommendationInputs inputs({
    List<Drill>? drills,
    List<DrillLog> logs = const [],
    List<ScheduleSlot> schedule = const [],
  }) => RecommendationInputs(
    drills: drills ?? testDrills,
    logs: logs,
    knowledge: const [],
    timerSessions: const [],
    schedule: schedule,
    matches: const [],
  );

  List<PlannedNotification> reco(
    RecommendationInputs i, {
    DateTime? at,
    SeenRecommendation? seen,
    NotificationPrefs prefs = const NotificationPrefs(),
  }) => planNotifications(
    cues: const [],
    slots: const [],
    streak: noStreak,
    prefs: prefs,
    now: at ?? now,
    recommendation: i,
    lastSeenRecommendation: seen,
  ).where((n) => n.kind == NotificationKind.recommendation).toList();

  test('trước 08:00: hôm nay và ngày mai lúc 08:00 khi hai ngày khác cặp', () {
    // Khung lịch Thứ Tư (day 2) gắn Cân bi: luật 1 đổi nhóm ngày mai.
    final i = inputs(
      drills: [...testDrills, bankDrill],
      schedule: [
        const ScheduleSlot(
          id: 's',
          day: 2,
          time: '19:00',
          label: 'l',
          cat: SkillCategory.bank,
        ),
      ],
    );
    expect(reco(i).map((n) => n.at), [
      DateTime(2026, 10, 13, 8),
      DateTime(2026, 10, 14, 8),
    ]);
  });

  test('sau 08:00: chỉ ngày mai', () {
    expect(reco(inputs(), at: DateTime(2026, 10, 13, 9)).map((n) => n.at), [
      DateTime(2026, 10, 14, 8),
    ]);
  });

  test('ngày mai trùng cặp hôm nay: không gửi lại', () {
    expect(reco(inputs()).map((n) => n.at), [DateTime(2026, 10, 13, 8)]);
  });

  test('trùng cặp thấy lần cuối: không gửi', () {
    final rec = inputs().recommendFor(DateTime(2026, 10, 13, 8));
    expect(
      reco(
        inputs(),
        seen: SeenRecommendation(
          cat: rec.cat,
          drillId: rec.drill!.id,
          at: DateTime(2026, 10, 12, 20),
        ),
      ),
      isEmpty,
    );
  });

  test('không có bài: không gửi', () {
    expect(reco(inputs(drills: const [])), isEmpty);
  });

  test(
    'đã tập bài được gợi ý trước 08:00: thông báo hôm nay nói về bài khác',
    () {
      // Khung lịch Thứ Ba gắn nhóm ngắm giữ nhóm của hôm nay; nhóm có hai
      // bài, nên bỏ bài đã tập thì vẫn còn bài để gợi ý.
      final drills = [...testDrills, secondAimingDrill];
      const schedule = [
        ScheduleSlot(
          id: 's',
          day: 1,
          time: '19:00',
          label: 'l',
          cat: SkillCategory.aiming,
        ),
      ];
      final before = DateTime(2026, 10, 13, 7, 30);
      final eight = DateTime(2026, 10, 13, 8);
      String drillOf(PlannedNotification n) =>
          parseRecommendationKey(n.key)!.drillId;

      // Cùng dữ liệu mà chưa tập: 08:00 hôm nay nói về x.
      final untouched = reco(
        inputs(drills: drills, schedule: schedule),
        at: before,
      );
      final x = drillOf(untouched.singleWhere((n) => n.at == eight));

      final today = reco(
        inputs(
          schedule: schedule,
          drills: drills,
          logs: [
            DrillLog(
              id: 'l',
              drillId: x,
              date: DateTime(2026, 10, 13, 6, 30),
              score: 1,
            ),
          ],
        ),
        at: before,
      ).singleWhere((n) => n.at == eight);
      expect(drillOf(today), isNot(x));
    },
  );

  test('nội dung là khuôn Vi điền từ computeRecommendation', () {
    final rec = inputs().recommendFor(DateTime(2026, 10, 13, 8));
    final n = reco(inputs()).first;
    expect(n.title, Vi.recommendationReminderTitle);
    expect(
      n.body,
      Vi.recommendationReminderBody(
        rec.drill!.name,
        rec.cat,
        Vi.pickReason(rec.reason, Vi.skill(rec.cat), signal: rec.matchSignal),
      ),
    );
    expect(
      n.key,
      recommendationKey(DateTime(2026, 10, 13), rec.cat, rec.drill!.id),
    );
    expect(n.validUntil, DateTime(2026, 10, 14));
  });

  test('chống bịa: nhóm yếu khác thì nội dung khác', () {
    final drills = [...testDrills, bankDrill];
    List<DrillLog> low(String drillId) => [
      for (var k = 0; k < 3; k++)
        DrillLog(
          id: '$drillId$k',
          drillId: drillId,
          date: DateTime(2026, 10, 12, 20),
          score: 0,
          attempts: 10,
        ),
    ];
    final a = inputs(drills: drills, logs: low('d1'));
    final b = inputs(drills: drills, logs: low('b1'));
    final ra = a.recommendFor(DateTime(2026, 10, 13, 8));
    final rb = b.recommendFor(DateTime(2026, 10, 13, 8));
    expect(ra.reason, PickReason.weakest);
    expect(ra.cat, isNot(rb.cat));
    final na = reco(a).first;
    final nb = reco(b).first;
    expect(na.body, contains(Vi.skill(ra.cat)));
    expect(nb.body, contains(Vi.skill(rb.cat)));
    expect(na.body, isNot(nb.body));
  });

  test('id đổi khi nội dung đổi, giữ nguyên khi không đổi', () {
    final base = reco(inputs()).first;
    expect(reco(inputs()).first.id, base.id);
    final renamed = [
      Drill(
        id: testDrills.first.id,
        cat: testDrills.first.cat,
        name: 'Tên khác',
        level: testDrills.first.level,
        unit: testDrills.first.unit,
        passThreshold: testDrills.first.passThreshold,
        goal: testDrills.first.goal,
        steps: testDrills.first.steps,
      ),
    ];
    expect(reco(inputs(drills: renamed)).first.id, isNot(base.id));
  });

  test('tắt Gợi ý mới hoặc chưa có dữ liệu: không có', () {
    expect(
      reco(inputs(), prefs: const NotificationPrefs(recommendation: false)),
      isEmpty,
    );
    expect(
      planNotifications(
        cues: const [],
        slots: const [],
        streak: noStreak,
        prefs: const NotificationPrefs(),
        now: now,
      ).where((n) => n.kind == NotificationKind.recommendation),
      isEmpty,
    );
  });

  test('khoá gợi ý: đọc lại được; khoá rác thì null', () {
    final k = recommendationKey(
      DateTime(2026, 10, 3),
      SkillCategory.bank,
      'd:7',
    );
    expect(parseRecommendationKey(k), (
      day: DateTime(2026, 10, 3),
      cat: SkillCategory.bank,
      drillId: 'd:7',
    ));
    for (final bad in [
      '',
      'x',
      '2026-10-3:nope:d1',
      '2026-10-3:aiming:',
      'a-b-c:aiming:d1',
    ]) {
      expect(parseRecommendationKey(bad), isNull, reason: bad);
    }
  });
}
