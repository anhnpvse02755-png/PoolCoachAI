import 'package:poolcoachai/data/database/match_codec.dart';
import 'package:poolcoachai/data/remote/codecs/assessment_codecs.dart';
import 'package:poolcoachai/data/remote/codecs/cue_equipment_codec.dart';
import 'package:poolcoachai/data/remote/codecs/practice_codecs.dart';
import 'package:poolcoachai/data/remote/codecs/remote_fields.dart';
import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_payload.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/recommendation_reminder.dart';
import 'package:poolcoachai/domain/pool_match.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Lõi lập thông báo phía máy chủ: cùng planNotifications của app, chạy trên
// dòng Directus thô của một người. Không Flutter, không Drift, không seed
// (bài tập và kiến thức do nơi gọi đưa vào).

/// Bảy collection helper đọc, đúng thứ tự trong `data` của yêu cầu.
const notifyPlanCollections = <String>[
  'drill_logs',
  'timer_sessions',
  'schedule_slots',
  'cue_equipment',
  'pool_matches',
  'bu_tests',
  'bu_drill_results',
];

/// Trường dịch vụ phải xin cho từng collection: đúng danh sách đồng bộ của
/// app, thêm `user_created` khi danh sách đó chưa có (để lọc theo chủ và để
/// helper kiểm chủ). Nguồn duy nhất cho `info.fields` của helper.
final Map<String, String> notifyPlanCollectionFields = Map.unmodifiable({
  'drill_logs': _withOwner(drillLogRemoteFields),
  'timer_sessions': _withOwner(timerSessionRemoteFields),
  'schedule_slots': _withOwner(scheduleSlotRemoteFields),
  'cue_equipment': _withOwner(cueEquipmentRemoteFields),
  'pool_matches': _withOwner(poolMatchRemoteFields),
  'bu_tests': _withOwner(remoteTestFields),
  'bu_drill_results': _withOwner(remoteResultFields),
});

String _withOwner(String fields) => fields.split(',').contains('user_created')
    ? fields
    : '$fields,user_created';

/// Giờ "trên tường" của thiết bị: đổi qua lại giữa thời điểm UTC và
/// `DateTime` mang đúng các trường ngày giờ địa phương của thiết bị.
abstract interface class WallClock {
  DateTime local(DateTime utc);
  DateTime utc(DateTime local);
}

/// [WallClock] theo một múi IANA, dùng dữ liệu của `package:timezone`.
///
/// [local] trả `DateTime` của tiến trình mang giờ trên tường của múi đó
/// (tiến trình nên chạy ở UTC, không đổi giờ); [utc] làm ngược lại.
final class TzWallClock implements WallClock {
  /// Ném [ArgumentError] khi không có múi tên [ianaName].
  TzWallClock(String ianaName) : _location = _locationOf(ianaName);

  final tz.Location _location;

  static bool _loaded = false;

  static tz.Location _locationOf(String name) {
    if (!_loaded) {
      // App có thể đã nạp (và đặt múi local) trước: nạp lại là xoá mất.
      if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
      _loaded = true;
    }
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      throw ArgumentError.value(name, 'ianaName', 'Không có múi giờ này');
    }
  }

  @override
  DateTime local(DateTime utc) {
    final t = tz.TZDateTime.from(utc, _location);
    return DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
      t.millisecond,
      t.microsecond,
    );
  }

  @override
  DateTime utc(DateTime local) {
    final t = tz.TZDateTime(
      _location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).toUtc();
    return DateTime.fromMicrosecondsSinceEpoch(
      t.microsecondsSinceEpoch,
      isUtc: true,
    );
  }
}

/// `upcoming`: mọi thông báo trong 24 giờ tới (để biết khi nào gửi).
/// `due`: như web P6a, lập từ đầu ngày, giữ mục đã tới giờ mà chưa hết hạn.
enum NotifyPlanMode { upcoming, due }

/// Cặp "đã thấy" từ cài đặt đã đồng bộ. Thiếu bài, hay tên nhóm mà bản này
/// chưa biết (của bản app sau): coi như chưa thấy, không phải yêu cầu hỏng.
({SkillCategory cat, String drillId, DateTime atUtc})? seenPairOf({
  required String cat,
  required String drillId,
  required DateTime atUtc,
}) {
  final category = SkillCategory.values.asNameMap()[cat];
  if (category == null || drillId.isEmpty) return null;
  return (cat: category, drillId: drillId, atUtc: atUtc.toUtc());
}

/// Đầu vào lập thông báo cho một người.
final class NotifyPlanRequest {
  const NotifyPlanRequest({
    required this.userId,
    required this.nowUtc,
    required this.tz,
    required this.mode,
    required this.prefs,
    required this.seen,
    required this.sentRecommendations,
    required this.data,
  });

  final String userId;
  final DateTime nowUtc;

  /// Múi IANA của thiết bị (nơi gọi dựng [WallClock] từ nó).
  final String tz;
  final NotifyPlanMode mode;
  final NotificationPrefs prefs;

  /// Cặp người chơi thấy lần cuối trên Trang chủ; null: chưa thấy lần nào.
  ///
  /// `atUtc` dùng nguyên giá trị đưa vào, KHÔNG cắt lẻ giây như giờ của các
  /// dòng dữ liệu (`wholeSeconds`): nơi gọi muốn khớp tuyệt đối với app thì
  /// đưa giờ đã lưu.
  final ({SkillCategory cat, String drillId, DateTime atUtc})? seen;

  /// Gợi ý máy chủ đã gửi (khoá và giờ), làm mốc "đã báo" như nhật ký app.
  ///
  /// `atUtc` dùng nguyên giá trị đưa vào, không cắt lẻ giây (xem [seen]).
  final List<({String key, DateTime atUtc})> sentRecommendations;

  /// Dòng Directus theo tên collection ([notifyPlanCollections]).
  final Map<String, List<Map<String, Object?>>> data;
}

/// Một thông báo cần gửi: đúng [PlannedNotification] của app (giờ trên
/// tường của thiết bị) cùng giờ UTC và payload.
final class ServerPlannedNotification {
  const ServerPlannedNotification({
    required this.local,
    required this.atUtc,
    required this.validUntilUtc,
    required this.payload,
  });

  final PlannedNotification local;
  final DateTime atUtc;
  final DateTime validUntilUtc;
  final String payload;
}

/// Dòng của [collection] không giải mã được (hoặc thiếu, hoặc của người
/// khác): không lập gì cho người này, không đoán.
final class NotifyPlanDataError implements Exception {
  const NotifyPlanDataError(this.collection);

  final String collection;

  @override
  String toString() => 'NotifyPlanDataError($collection)';
}

/// Lập thông báo cho một người, ra đúng những gì app của họ lập.
///
/// Giải mã từng collection bằng bộ giải mã đồng bộ dùng, lọc và xếp như các
/// repository mà dịch vụ thông báo đọc, rồi gọi [planNotifications]. Kết quả
/// BU mới nhất chỉ bổ sung cho gợi ý: hỏng thì lập như không có BU (như app
/// khi `latestBuResultProvider` lỗi). Collection khác hỏng thì ném
/// [NotifyPlanDataError].
List<ServerPlannedNotification> planForUser(
  NotifyPlanRequest r, {
  required List<Drill> drills,
  required List<KnowledgeArticle> knowledge,
  required WallClock clock,
}) {
  // Drift lưu giờ tới từng giây; app đọc lại thành giờ địa phương.
  DateTime toLocal(DateTime u) => clock.local(wholeSeconds(u));

  final logs = stableSorted(
    _decode(
      r,
      'drill_logs',
      (row) => drillLogFromRemote(row, toLocal: toLocal),
    ),
    (DrillLog a, DrillLog b) => a.date.compareTo(b.date),
  );
  final timerSessions = stableSorted(
    _decode(
      r,
      'timer_sessions',
      (row) => timerSessionFromRemote(row, toLocal: toLocal),
    ),
    (TimerSession a, TimerSession b) => b.date.compareTo(a.date),
  );
  final slots = stableSorted(
    [
      for (final s in _decode(r, 'schedule_slots', scheduleSlotFromRemote))
        if (!s.isDeleted) s.slot,
    ],
    (ScheduleSlot a, ScheduleSlot b) {
      final byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : compareText(a.time, b.time);
    },
  );
  final cues = stableSorted([
    for (final c in _decode(
      r,
      'cue_equipment',
      (row) => cueEquipmentFromRemote(row, toLocal: toLocal),
    ))
      if (!c.isDeleted) c.cue,
  ], (CueEquipment a, CueEquipment b) => compareText(a.name, b.name));
  final matches = stableSorted(
    _decode(r, 'pool_matches', (row) {
      final m = poolMatchFromRemote(row, toLocal: toLocal);
      return m.isDeleted ? null : _matchOf(m);
    }).nonNulls.toList(),
    (PoolMatch a, PoolMatch b) {
      final byStart = b.startedAt.compareTo(a.startedAt);
      return byStart != 0 ? byStart : compareText(a.id, b.id);
    },
  );
  final latestBu = _latestBu(r, toLocal);

  final now = clock.local(r.nowUtc);
  final due = r.mode == NotifyPlanMode.due;
  final from = due ? DateTime(now.year, now.month, now.day) : now;
  final seen = r.seen;
  final baseline = recommendationBaseline(
    shownOnHome: seen == null
        ? null
        : SeenRecommendation(
            cat: seen.cat,
            drillId: seen.drillId,
            at: clock.local(seen.atUtc),
          ),
    log: [
      for (final s in r.sentRecommendations)
        NotificationLogEntry(
          id: 0,
          kind: NotificationKind.recommendation,
          key: s.key,
          at: clock.local(s.atUtc),
          title: '',
          body: '',
        ),
    ],
    now: now,
  );

  final plan = planNotifications(
    cues: cues,
    slots: slots,
    streak: streakStateOf(
      logs: logs,
      timerSessions: timerSessions,
      today: from,
    ),
    prefs: r.prefs,
    now: from,
    recommendation: RecommendationInputs(
      drills: drills,
      logs: logs,
      knowledge: knowledge,
      timerSessions: timerSessions,
      schedule: slots,
      matches: matches,
      latestBu: latestBu,
    ),
    lastSeenRecommendation: baseline,
    limit: due ? 1 << 20 : maxPendingNotifications,
  );

  final horizon = now.add(const Duration(hours: 24));
  return [
    for (final n in plan)
      if (due
          ? !n.at.isAfter(now) && now.isBefore(n.validUntil)
          : n.at.isBefore(horizon))
        ServerPlannedNotification(
          local: n,
          atUtc: clock.utc(n.at),
          validUntilUtc: clock.utc(n.validUntil),
          payload: notificationPayload(n.kind, n.key, userId: r.userId),
        ),
  ];
}

/// Dòng của [collection], đã kiểm chủ là [NotifyPlanRequest.userId].
List<Map<String, Object?>> _ownedRows(NotifyPlanRequest r, String collection) {
  final rows = r.data[collection];
  if (rows == null) {
    throw FormatException('Thiếu collection $collection');
  }
  for (final row in rows) {
    if (remoteOwner(row) != r.userId) {
      throw const FormatException('Dòng không thuộc người được lập');
    }
  }
  return rows;
}

List<T> _decode<T>(
  NotifyPlanRequest r,
  String collection,
  T Function(Map<String, Object?> row) decode,
) {
  try {
    return [for (final row in _ownedRows(r, collection)) decode(row)];
  } on FormatException {
    throw NotifyPlanDataError(collection);
  } on TypeError {
    throw NotifyPlanDataError(collection);
  } on ArgumentError {
    throw NotifyPlanDataError(collection);
  }
}

PoolMatch _matchOf(RemotePoolMatch m) => poolMatchFromColumns(
  id: m.id,
  gameType: m.gameType,
  playerName: m.playerName,
  opponentName: m.opponentName,
  targetRacks: m.targetRacks,
  rackWinnersJson: m.rackWinnersJson,
  shotsJson: m.shotsJson,
  startedAt: m.startedAt,
  completedAt: m.completedAt,
  cueId: m.cueId,
  tournamentId: m.tournamentId,
  roundLabel: m.roundLabel,
);

/// Như `latestBuResultProvider`: lần hoàn tất mới nhất, chấm từ kết quả
/// từng bài của chính lần đó. Mọi lỗi (dòng hỏng, tên enum lạ, thiếu bản Đề
/// II) cho null, như app tính gợi ý khi BU lỗi.
BuResult? _latestBu(NotifyPlanRequest r, ToLocal toLocal) {
  try {
    final tests = [
      for (final row in _ownedRows(r, 'bu_tests'))
        buTestFromRemote(row, toLocal: toLocal),
    ];
    final results = [
      for (final row in _ownedRows(r, 'bu_drill_results'))
        buDrillResultFromRemote(row, toLocal: toLocal),
    ];
    final id = latestCompletedTestId(tests);
    if (id == null) return null;
    // Trùng id thì dòng sau ghi đè dòng trước, như lúc đồng bộ vào DB.
    final test = tests.lastWhere((t) => t.id == id);
    if (!test.isCompleted || test.examIIVersion == null) return null;
    final mine = [
      for (final x in results)
        if (x.testId == id) x,
    ];
    final attempts = <String, DrillAttempts>{
      for (final x in mine) x.drillId: drillAttemptsFromJson(x.attemptsJson),
    };
    final touched = <String, DateTime>{
      for (final x in mine) x.drillId: x.recordedAt,
    };
    return buResultFrom(
      TestSnapshot(test: test, attempts: attempts, touched: touched),
    );
  } on Object {
    return null;
  }
}

/// Sắp xếp giữ nguyên thứ tự gốc của các phần tử bằng nhau (`List.sort` của
/// Dart không bảo đảm điều này với danh sách dài). Công khai để test khoá.
List<T> stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}

/// So chữ như SQLite (BINARY: từng byte UTF-8, tức từng code point), không
/// như `String.compareTo` (từng đơn vị UTF-16). Khác nhau ở ký tự ngoài mặt
/// phẳng cơ bản (emoji…). Công khai để test khoá.
int compareText(String a, String b) {
  final x = a.runes.iterator;
  final y = b.runes.iterator;
  while (true) {
    final hasX = x.moveNext();
    final hasY = y.moveNext();
    if (!hasX || !hasY) return hasX == hasY ? 0 : (hasX ? 1 : -1);
    final c = x.current.compareTo(y.current);
    if (c != 0) return c;
  }
}
