import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/maintenance_schedule.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

/// Số thông báo chờ tối đa. iOS giữ tối đa 64 thông báo cục bộ; chừa
/// một ít để không chạm trần.
const maxPendingNotifications = 60;

/// Số ngày tới mà nhắc lịch tập được tính.
const scheduleReminderHorizonDays = 7;

/// Một thông báo cần có. Giờ là giờ địa phương.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.key,
    required this.at,
    required this.validUntil,
    required this.title,
    required this.body,
  });

  /// Id số cho hệ điều hành; cùng id nghĩa là cùng giờ, cùng chữ.
  final int id;
  final NotificationKind kind;

  /// Định danh ổn định của thông báo (không đổi theo chữ), dùng để không
  /// báo hai lần trên web.
  final String key;
  final DateTime at;

  /// Quá giờ này thì nhắc không còn nghĩa (web mở app muộn).
  final DateTime validUntil;
  final String title;
  final String body;
}

/// Chuỗi ngày tập hiện tại và hôm nay đã tập chưa.
class StreakState {
  const StreakState({required this.days, required this.practicedToday});

  final int days;
  final bool practicedToday;
}

/// Tính [StreakState] từ nhật ký tập. Dùng đúng [streakDays] của Home và
/// Lộ trình để mọi nơi hiểu "chuỗi" như nhau.
StreakState streakStateOf({
  required List<DrillLog> logs,
  required List<TimerSession> timerSessions,
  required DateTime today,
}) {
  bool isToday(DateTime d) =>
      d.year == today.year && d.month == today.month && d.day == today.day;
  return StreakState(
    days: streakDays(logs: logs, timerSessions: timerSessions, today: today),
    practicedToday:
        logs.any((l) => isToday(l.date)) ||
        timerSessions.any((t) => isToday(t.date)),
  );
}

/// Toàn bộ thông báo còn phải gửi sau [now], xếp theo giờ, tối đa [limit].
///
/// - Gợi ý tập mới: 08:00 hôm nay (nếu chưa tới) và 08:00 ngày mai, tính
///   bằng [RecommendationInputs.recommendFor]. Chỉ khi gợi ý của ngày đó có
///   bài và khác cặp (nhóm, bài) đã thấy lần cuối [lastSeenRecommendation]
///   hoặc của ngày liền trước trong cùng kế hoạch.
/// - Bảo dưỡng: như [computeMaintenanceSchedule], không giới hạn ngày.
/// - Lịch tập: [scheduleReminderLeadMinutes] phút trước giờ bắt đầu của
///   mỗi khung tuần, trong [scheduleReminderHorizonDays] ngày tới.
/// - Chuỗi: 20:00 hôm nay nếu chuỗi từ [streakReminderMinDays] ngày mà
///   hôm nay chưa tập.
///
/// Loại bị tắt trong [prefs] không có mặt.
List<PlannedNotification> planNotifications({
  required List<CueEquipment> cues,
  required List<ScheduleSlot> slots,
  required StreakState streak,
  required NotificationPrefs prefs,
  required DateTime now,
  RecommendationInputs? recommendation,
  SeenRecommendation? lastSeenRecommendation,
  int limit = maxPendingNotifications,
}) {
  final drafts = <_Draft>[];

  if (prefs.recommendation && recommendation != null) {
    // Cặp đã báo/đã thấy; nối tiếp từ ngày này sang ngày sau.
    SkillCategory? baseCat = lastSeenRecommendation?.cat;
    String? baseDrillId = lastSeenRecommendation?.drillId;
    for (var offset = 0; offset <= 1; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        recommendationReminderHour,
      );
      if (!at.isAfter(now)) continue;
      final rec = recommendation.recommendFor(at);
      final drill = rec.drill;
      if (drill == null) continue;
      if (baseCat == rec.cat && baseDrillId == drill.id) continue;
      drafts.add(
        _Draft(
          kind: NotificationKind.recommendation,
          key: recommendationKey(day, rec.cat, drill.id),
          at: at,
          validUntil: DateTime(day.year, day.month, day.day + 1),
          title: Vi.recommendationReminderTitle,
          body: Vi.recommendationReminderBody(
            drill.name,
            rec.cat,
            Vi.pickReason(
              rec.reason,
              Vi.skill(rec.cat),
              signal: rec.matchSignal,
            ),
          ),
        ),
      );
      baseCat = rec.cat;
      baseDrillId = drill.id;
    }
  }

  if (prefs.maintenance) {
    for (final r in computeMaintenanceSchedule(cues, now: now)) {
      final due = r.at.add(Duration(days: r.daysBefore));
      drafts.add(
        _Draft(
          kind: NotificationKind.maintenance,
          key: '${r.cueId}:${due.year}-${due.month}-${due.day}:${r.daysBefore}',
          at: r.at,
          validUntil: DateTime(r.at.year, r.at.month, r.at.day + 1),
          title: Vi.equipmentNotificationTitle,
          body: Vi.equipmentNotificationBody(r.cueName, r.daysBefore),
        ),
      );
    }
  }

  if (prefs.schedule) {
    final horizon = now.add(const Duration(days: scheduleReminderHorizonDays));
    for (final slot in slots) {
      final time = _parseTime(slot.time);
      if (time == null) continue;
      // Quét thừa hai ngày hai đầu: nhắc của khung 00:10 rơi vào hôm trước.
      for (var offset = 0; offset <= scheduleReminderHorizonDays + 1; offset++) {
        final day = DateTime(now.year, now.month, now.day + offset);
        if (day.weekday - 1 != slot.day) continue;
        final start = DateTime(day.year, day.month, day.day, time.$1, time.$2);
        final at = start.subtract(
          const Duration(minutes: scheduleReminderLeadMinutes),
        );
        if (!at.isAfter(now) || !at.isBefore(horizon)) continue;
        drafts.add(
          _Draft(
            kind: NotificationKind.schedule,
            key: '${slot.id}:${start.year}-${start.month}-${start.day}',
            at: at,
            validUntil: start,
            title: Vi.scheduleReminderTitle,
            body: Vi.scheduleReminderBody(
              slot.label,
              slot.time,
              scheduleReminderLeadMinutes,
              slot.cat,
            ),
          ),
        );
      }
    }
  }

  if (prefs.streak &&
      streak.days >= streakReminderMinDays &&
      !streak.practicedToday) {
    final at = DateTime(now.year, now.month, now.day, streakReminderHour);
    if (at.isAfter(now)) {
      drafts.add(
        _Draft(
          kind: NotificationKind.streak,
          key: '${now.year}-${now.month}-${now.day}',
          at: at,
          validUntil: DateTime(now.year, now.month, now.day + 1),
          title: Vi.streakReminderTitle,
          body: Vi.streakReminderBody(streak.days),
        ),
      );
    }
  }

  drafts.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    return '${a.kind.name}:${a.key}'.compareTo('${b.kind.name}:${b.key}');
  });

  final used = <int>{};
  final result = <PlannedNotification>[];
  for (final d in drafts.take(limit)) {
    var id = _hash('${d.kind.name}|${d.key}|${d.at.toIso8601String()}|'
        '${d.title}|${d.body}');
    while (!used.add(id)) {
      id = (id + 1) & _idMask;
    }
    result.add(
      PlannedNotification(
        id: id,
        kind: d.kind,
        key: d.key,
        at: d.at,
        validUntil: d.validUntil,
        title: d.title,
        body: d.body,
      ),
    );
  }
  return result;
}

class _Draft {
  const _Draft({
    required this.kind,
    required this.key,
    required this.at,
    required this.validUntil,
    required this.title,
    required this.body,
  });

  final NotificationKind kind;
  final String key;
  final DateTime at;
  final DateTime validUntil;
  final String title;
  final String body;
}

(int, int)? _parseTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return (hour, minute);
}

const _idMask = 0x7fffffff;

/// FNV-1a 32 bit, bỏ bit dấu: id dương vừa cho cả Android lẫn iOS.
int _hash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & _idMask;
}
