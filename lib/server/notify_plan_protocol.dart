import 'dart:convert';

import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';
import 'package:poolcoachai/domain/notifications/seed_fingerprint.dart';
import 'package:poolcoachai/server/notify_plan.dart';

// Giao thức NDJSON của helper thông báo: mỗi dòng một đối tượng JSON, mỗi
// dòng vào có đúng một dòng ra. Không Flutter, không Drift, không seed (bài
// tập và kiến thức do nơi gọi đưa vào).

const notifyPlanProtocolVersion = 1;

/// Trường dịch vụ phải xin cho `notification_settings`, kèm `user_created`.
/// Nguồn duy nhất cho `info.settingsFields` (dịch vụ Node chỉ dùng giá trị
/// này). Task 6 đặt hằng số của app cho cùng danh sách và test khoá hai bên.
const notifyPlanSettingsFields =
    'id,recommendation,maintenance,schedule,streak,prefs_updated_at,'
    'last_seen_cat,last_seen_drill_id,last_seen_at,timezone,user_created';

/// Xử lý một dòng yêu cầu, trả một dòng JSON (không có xuống dòng). Không bao
/// giờ ném: lỗi bất ngờ cũng thành trả lời có cấu trúc.
String handleNotifyPlanLine(
  String line, {
  required List<Drill> drills,
  required List<KnowledgeArticle> knowledge,
}) {
  String? reqId;
  try {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return _error(null, 'bad_json');
    }
    if (decoded is! Map) return _error(null, 'bad_json');
    final req = Map<String, Object?>.from(decoded);
    final rid = req['reqId'];
    reqId = rid is String ? rid : null;

    final v = req['v'];
    if (v is! int) return _error(reqId, 'bad_request');
    if (v != notifyPlanProtocolVersion) {
      return _error(reqId, 'unsupported_version');
    }

    final fingerprint = seedFingerprint(drills: drills, knowledge: knowledge);
    switch (req['op']) {
      case 'info':
        return jsonEncode({
          'v': notifyPlanProtocolVersion,
          'reqId': reqId,
          'ok': true,
          'fingerprint': fingerprint,
          'kinds': [for (final k in NotificationKind.values) k.name],
          'fields': notifyPlanCollectionFields,
          'settingsFields': notifyPlanSettingsFields,
        });
      case 'plan':
        return _plan(req, reqId, fingerprint, drills, knowledge);
      default:
        return _error(reqId, 'bad_request');
    }
  } on Object {
    return _error(reqId, 'bad_request');
  }
}

String _plan(
  Map<String, Object?> req,
  String? reqId,
  String fingerprint,
  List<Drill> drills,
  List<KnowledgeArticle> knowledge,
) {
  final NotifyPlanRequest parsed;
  try {
    parsed = _parse(req);
  } on FormatException {
    return _error(reqId, 'bad_request');
  } on TypeError {
    return _error(reqId, 'bad_request');
  }

  final WallClock clock;
  try {
    clock = TzWallClock(parsed.tz);
  } on ArgumentError {
    return _error(reqId, 'bad_tz');
  }

  final List<ServerPlannedNotification> items;
  try {
    items = planForUser(parsed, drills: drills, knowledge: knowledge, clock: clock);
  } on NotifyPlanDataError catch (e) {
    return jsonEncode({
      'v': notifyPlanProtocolVersion,
      'reqId': reqId,
      'ok': false,
      'error': 'bad_data',
      'collection': e.collection,
    });
  }
  return jsonEncode({
    'v': notifyPlanProtocolVersion,
    'reqId': reqId,
    'ok': true,
    'fingerprint': fingerprint,
    'items': [
      for (final n in items)
        {
          'id': n.local.id,
          'kind': n.local.kind.name,
          'key': n.local.key,
          'at': n.local.at.toIso8601String(),
          'atUtc': n.atUtc.toIso8601String(),
          'validUntil': n.local.validUntil.toIso8601String(),
          'validUntilUtc': n.validUntilUtc.toIso8601String(),
          'title': n.local.title,
          'body': n.local.body,
          'payload': n.payload,
        },
    ],
  });
}

NotifyPlanRequest _parse(Map<String, Object?> req) {
  final mode = switch (req['mode']) {
    'upcoming' => NotifyPlanMode.upcoming,
    'due' => NotifyPlanMode.due,
    _ => throw const FormatException('mode'),
  };
  final prefs = _map(req['prefs']);
  final seenRaw = req['seen'];
  final seen = seenRaw == null
      ? null
      : seenPairOf(
          cat: _string(_map(seenRaw)['cat']),
          drillId: _string(_map(seenRaw)['drillId']),
          atUtc: _utc(_map(seenRaw)['atUtc']),
        );
  final dataRaw = _map(req['data']);
  return NotifyPlanRequest(
    userId: _string(req['userId']),
    nowUtc: _utc(req['nowUtc']),
    tz: _string(req['tz']),
    mode: mode,
    prefs: NotificationPrefs(
      recommendation: _bool(prefs['recommendation']),
      maintenance: _bool(prefs['maintenance']),
      schedule: _bool(prefs['schedule']),
      streak: _bool(prefs['streak']),
    ),
    seen: seen,
    sentRecommendations: [
      for (final s in _list(req['sentRecommendations']))
        (key: _string(_map(s)['key']), atUtc: _utc(_map(s)['atUtc'])),
    ],
    // Thiếu bất kỳ khoá nào (kể cả bu_*) là yêu cầu hỏng: không lặng lẽ lập
    // thiếu dữ liệu.
    data: {
      for (final c in notifyPlanCollections)
        c: [for (final row in _list(dataRaw[c])) _map(row)],
    },
  );
}

Map<String, Object?> _map(Object? x) =>
    x is Map ? Map<String, Object?>.from(x) : throw const FormatException('map');

List<Object?> _list(Object? x) =>
    x is List ? x : throw const FormatException('list');

String _string(Object? x) =>
    x is String ? x : throw const FormatException('string');

bool _bool(Object? x) => x is bool ? x : throw const FormatException('bool');

DateTime _utc(Object? x) {
  final t = DateTime.parse(_string(x));
  if (!t.isUtc) throw const FormatException('giờ phải là UTC (đuôi Z)');
  return t;
}

String _error(String? reqId, String error) => jsonEncode({
  'v': notifyPlanProtocolVersion,
  'reqId': reqId,
  'ok': false,
  'error': error,
});
