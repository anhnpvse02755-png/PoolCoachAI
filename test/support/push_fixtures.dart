import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/server/notify_plan.dart';

import 'assessment_fixtures.dart';

/// Đồng hồ theo múi của chính tiến trình test: helper và đường app (Drift,
/// `toLocal`) cùng hiểu "giờ địa phương" như nhau, nên so khớp được.
final class HostWallClock implements WallClock {
  const HostWallClock();

  @override
  DateTime local(DateTime utc) => utc.toLocal();

  @override
  DateTime utc(DateTime local) => local.toUtc();
}

/// Đủ bảy collection, collection nào cũng rỗng.
Map<String, List<Map<String, Object?>>> emptyRemoteData() => {
  for (final c in notifyPlanCollections) c: <Map<String, Object?>>[],
};

String _iso(DateTime d) => d.toUtc().toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

/// Ngày-chỉ-ngày như Directus trả cho trường kiểu `date`.
String remoteDay(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

Map<String, Object?> drillLogRow({
  required String id,
  required String drillId,
  required DateTime date,
  double score = 0.5,
  int? attempts,
  String? notes,
  int? durationSec,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'drill_id': drillId,
  'date': _iso(date),
  'score': score,
  'attempts': attempts,
  'notes': notes,
  'duration_sec': durationSec,
};

Map<String, Object?> timerSessionRow({
  required String id,
  required DateTime date,
  int durationSec = 1800,
  String? cat,
  String? catExt,
  String? cueId,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'date': _iso(date),
  'duration_sec': durationSec,
  'cat': cat,
  'cat_ext': catExt,
  'cue_id': cueId,
};

/// Ô lịch. [extTrusted] = false: `cat_ext_at` lệch `updated_at` (bản cũ sửa
/// dòng sau bản mới), nên `cat_ext` không được tin.
Map<String, Object?> slotRow({
  required String id,
  required int day,
  required String time,
  required String label,
  required DateTime updatedAt,
  String? cat,
  String? catExt,
  bool extTrusted = true,
  bool deleted = false,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'day': day,
  'time': time,
  'label': label,
  'cat': cat,
  'cat_ext': catExt,
  'cat_ext_at': catExt == null
      ? null
      : _iso(
          extTrusted
              ? updatedAt
              : updatedAt.subtract(const Duration(minutes: 5)),
        ),
  'updated_at': _iso(updatedAt),
  'is_deleted': deleted,
};

Map<String, Object?> cueRow({
  required String id,
  required String name,
  required DateTime updatedAt,
  String type = 'playing',
  DateTime? lastMaintenance,
  DateTime? dueDate,
  List<String> skills = const [],
  List<String>? skillsExt,
  bool deleted = false,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'name': name,
  'type': type,
  'weight_grams': 539,
  'shaft_brand': 'Predator',
  'tip_diameter_mm': 12.5,
  'tip_brand': 'Kamui',
  'tip_hardness': 'medium',
  'butt_brand': null,
  'skill_categories': skills,
  'skill_categories_ext': skillsExt,
  'last_tip_maintenance': lastMaintenance == null
      ? null
      : remoteDay(lastMaintenance),
  'tip_maintenance_due_date': dueDate == null ? null : remoteDay(dueDate),
  'updated_at': _iso(updatedAt),
  'is_deleted': deleted,
};

Map<String, Object?> matchRow({
  required String id,
  required DateTime startedAt,
  String gameType = 'nineBall',
  DateTime? completedAt,
  List<String> winners = const [],
  List<Map<String, Object?>> shots = const [],
  String? cueId,
  String? tournamentId,
  String? roundLabel,
  bool deleted = false,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'game_type': gameType,
  'player_name': 'An',
  'opponent_name': 'Bình',
  'target_racks': 3,
  'rack_winners': winners,
  'shots': shots,
  'cue_id': cueId,
  'started_at': _iso(startedAt),
  'completed_at': completedAt == null ? null : _iso(completedAt),
  'updated_at': _iso(completedAt ?? startedAt),
  'is_deleted': deleted,
  'tournament_id': tournamentId,
  'round_label': roundLabel,
};

Map<String, Object?> shotRow({
  required String id,
  required int rack,
  required int shot,
  required DateTime at,
  String shooter = 'player',
  String type = 'normal',
  String outcome = 'made',
  String? position,
}) => {
  'id': id,
  'rackNumber': rack,
  'shotNumber': shot,
  'shooter': shooter,
  'type': type,
  'outcome': outcome,
  'positionOutcome': position,
  'notes': null,
  'recordedAt': _iso(at),
};

Map<String, Object?> buTestRow({
  required String id,
  required DateTime startedAt,
  DateTime? completedAt,
  DateTime? cancelledAt,
  String tableSize = 'nineFootPlus',
  int? examIScore,
  String? examIIVersion,
  int? examIIScore,
  int? totalScore,
  String? resultRank,
  String userId = 'u1',
}) => {
  'id': id,
  'user_created': userId,
  'started_at': _iso(startedAt),
  'completed_at': completedAt == null ? null : _iso(completedAt),
  'cancelled_at': cancelledAt == null ? null : _iso(cancelledAt),
  'table_size': tableSize,
  'exam_i_score': examIScore,
  'exam_ii_version': examIIVersion,
  'exam_ii_score': examIIScore,
  'total_score': totalScore,
  'result_rank': resultRank,
};

/// Dòng kết quả của mọi bài trong [attempts], điểm chấm bằng [drillScore].
List<Map<String, Object?>> buResultRows({
  required String testId,
  required Map<String, DrillAttempts> attempts,
  required ExamIIVersion version,
  required DateTime recordedAt,
  String userId = 'u1',
}) => [
  for (final MapEntry(key: drillId, value: a) in attempts.entries)
    {
      'id': '$testId-$drillId',
      'user_created': userId,
      'test_id': testId,
      'drill_id': drillId,
      'attempts': a.toJson(),
      'score': drillScore(drillFor(drillId, version), a),
      'recorded_at': _iso(recordedAt),
    },
];

/// Bài BU đã hoàn tất: Đề I mất F7, F8 (60), Đề II bản Masters trọn điểm
/// trừ S1 (hai lần đều 0).
({List<Map<String, Object?>> tests, List<Map<String, Object?>> results})
completedBuRows({required DateTime completedAt}) {
  const version = ExamIIVersion.masters;
  final attempts = {
    ...examIAttempts(wagonAndTargetMade: false),
    ...examIIPerfect(version),
    'S1': CountAttempts([0, 0]),
  };
  return (
    tests: [
      buTestRow(
        id: 'bu-old',
        startedAt: completedAt.subtract(const Duration(days: 40)),
        cancelledAt: completedAt.subtract(const Duration(days: 39)),
      ),
      buTestRow(
        id: 'bu1',
        startedAt: completedAt.subtract(const Duration(hours: 2)),
        completedAt: completedAt,
        examIScore: 60,
        examIIVersion: version.name,
        examIIScore: 70,
        totalScore: 130,
        resultRank: 'e',
      ),
    ],
    results: buResultRows(
      testId: 'bu1',
      attempts: attempts,
      version: version,
      recordedAt: completedAt.subtract(const Duration(minutes: 30)),
    ),
  );
}

/// Chỉ buổi tập (hôm qua, không đủ để chấm nhóm) và bài BU: gợi ý hôm nay
/// do nhóm yếu theo BU quyết định, nên có BU hay không làm đổi gợi ý.
Map<String, List<Map<String, Object?>>> buSensitiveRemoteData({
  required DateTime nowUtc,
}) {
  final rich = richRemoteData(nowUtc: nowUtc);
  return {
    ...emptyRemoteData(),
    'drill_logs': rich['drill_logs']!,
    'bu_tests': rich['bu_tests']!,
    'bu_drill_results': rich['bu_drill_results']!,
  };
}

/// Dòng Directus làm mọi loại thông báo xuất hiện trong 24 giờ tới, tính
/// theo giờ địa phương của tiến trình tại [nowUtc] (giờ đó phải trước 20:00
/// để còn nhắc chuỗi):
/// - buổi tập hai ngày trước liền nhau, hôm nay chưa tập (chuỗi ≥ 2);
/// - khung lịch hôm nay sau giờ hiện tại hơn 30 phút (nhóm nâng cao qua
///   `cat_ext`), khung sáng mai, khung có `cat_ext` không được tin;
/// - cơ tới hạn ngày mai (trong 7 ngày) và cơ tới hạn sau 7 ngày;
/// - hai trận (một trận thuộc giải), bài BU hoàn tất có kết quả;
/// - một khung, một trận, một cơ đã xoá mềm.
Map<String, List<Map<String, Object?>>> richRemoteData({
  required DateTime nowUtc,
}) {
  final local = nowUtc.toLocal();
  if (local.hour >= 20) {
    throw ArgumentError.value(nowUtc, 'nowUtc', 'phải trước 20:00 địa phương');
  }
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(local.year, local.month, local.day + offset, hour, minute);
  final laterToday = local.add(const Duration(hours: 3));
  final slotTime = laterToday.day == local.day
      ? '${_two(laterToday.hour)}:${_two(laterToday.minute)}'
      : '23:59';
  final edited = day(-3, 12);
  final bu = completedBuRows(completedAt: day(-10, 16));
  return {
    'drill_logs': [
      drillLogRow(
        id: 'l1',
        drillId: 'd1',
        date: day(-1, 19),
        score: 0.4,
        attempts: 10,
        notes: 'tay run',
        durationSec: 900,
      ),
      drillLogRow(id: 'l2', drillId: 'd3', date: day(-2, 19, 30), score: 0.9),
      drillLogRow(id: 'l3', drillId: 'd2', date: day(-4, 18), score: 0.3),
    ],
    'timer_sessions': [
      timerSessionRow(
        id: 't1',
        date: day(-3, 18),
        catExt: 'dungCo',
        cueId: 'c1',
      ),
      timerSessionRow(
        id: 't2',
        date: day(-6, 18),
        durationSec: 1200,
        cat: 'aiming',
      ),
    ],
    'schedule_slots': [
      slotRow(
        id: 's1',
        day: local.weekday - 1,
        time: slotTime,
        label: 'Tập tối',
        catExt: 'nhayBi',
        updatedAt: edited,
      ),
      slotRow(
        id: 's2',
        day: day(1).weekday - 1,
        time: '07:00',
        label: 'Tập sáng',
        cat: 'position',
        updatedAt: edited,
      ),
      slotRow(
        id: 's3',
        day: day(2).weekday - 1,
        time: '18:15',
        label: 'Khung bản cũ sửa',
        catExt: 'matXe',
        extTrusted: false,
        updatedAt: edited,
      ),
      // Đã bắt đầu từ sáng sớm nay: nhắc đã hết hạn.
      slotRow(
        id: 's5',
        day: local.weekday - 1,
        time: '00:40',
        label: 'Khung sáng sớm',
        updatedAt: edited,
      ),
      slotRow(
        id: 's4',
        day: local.weekday - 1,
        time: slotTime,
        label: 'Khung đã xoá',
        cat: 'safety',
        updatedAt: edited,
        deleted: true,
      ),
    ],
    'cue_equipment': [
      cueRow(
        id: 'c1',
        name: 'Cơ chơi',
        updatedAt: edited,
        lastMaintenance: day(-60),
        dueDate: day(1),
        skills: ['aiming', 'position'],
        skillsExt: ['matXe'],
      ),
      cueRow(
        id: 'c2',
        name: 'Cơ phá',
        type: 'breakCue',
        updatedAt: edited,
        dueDate: day(7),
      ),
      cueRow(
        id: 'c3',
        name: 'Cơ đã bán',
        updatedAt: edited,
        dueDate: day(1),
        deleted: true,
      ),
    ],
    'pool_matches': [
      matchRow(
        id: 'm1',
        startedAt: day(-1, 14),
        completedAt: day(-1, 15),
        winners: ['player', 'opponent', 'player', 'opponent', 'opponent'],
        shots: [
          shotRow(id: 'x1', rack: 1, shot: 1, at: day(-1, 14, 5)),
          shotRow(
            id: 'x2',
            rack: 2,
            shot: 1,
            at: day(-1, 14, 20),
            outcome: 'missed',
            position: 'unsuccessful',
          ),
          shotRow(
            id: 'x3',
            rack: 3,
            shot: 1,
            at: day(-1, 14, 40),
            type: 'safety',
            outcome: 'foul',
          ),
        ],
        cueId: 'c1',
        tournamentId: 'tour1',
        roundLabel: 'Tứ kết',
      ),
      matchRow(
        id: 'm2',
        gameType: 'tenBall',
        startedAt: day(-2, 20),
        winners: ['opponent'],
      ),
      matchRow(
        id: 'm3',
        gameType: 'eightBall',
        startedAt: day(0, 1),
        winners: ['player'],
        deleted: true,
      ),
    ],
    'bu_tests': bu.tests,
    'bu_drill_results': bu.results,
  };
}
