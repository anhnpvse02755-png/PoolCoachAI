import 'dart:convert';

import 'package:poolcoachai/data/remote/codecs/remote_values.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/rank.dart';

DateTime? _local(Object? s, ToLocal toLocal) =>
    s == null ? null : toLocal(DateTime.parse(s as String).toUtc());

/// Lần kiểm tra BU kéo từ server. Tên enum lạ thì `byName` ném.
BuTest buTestFromRemote(
  Map<String, Object?> j, {
  ToLocal toLocal = defaultToLocal,
}) => BuTest(
  id: j['id']! as String,
  startedAt: _local(j['started_at'], toLocal)!,
  tableSize: TableSize.values.byName(j['table_size']! as String),
  completedAt: _local(j['completed_at'], toLocal),
  cancelledAt: _local(j['cancelled_at'], toLocal),
  examIScore: j['exam_i_score'] as int?,
  examIIVersion: j['exam_ii_version'] == null
      ? null
      : ExamIIVersion.values.byName(j['exam_ii_version']! as String),
  examIIScore: j['exam_ii_score'] as int?,
  totalScore: j['total_score'] as int?,
  resultRank: j['result_rank'] == null
      ? null
      : Rank.values.byName(j['result_rank']! as String),
);

/// Kết quả một bài của lần kiểm tra BU; `attempts` giữ dạng JSON thô.
({
  String id,
  String testId,
  String drillId,
  String attemptsJson,
  int? score,
  DateTime recordedAt,
})
buDrillResultFromRemote(
  Map<String, Object?> j, {
  ToLocal toLocal = defaultToLocal,
}) => (
  id: j['id']! as String,
  testId: j['test_id']! as String,
  drillId: j['drill_id']! as String,
  attemptsJson: jsonEncode(j['attempts']),
  score: j['score'] as int?,
  recordedAt: _local(j['recorded_at'], toLocal)!,
);

DrillAttempts drillAttemptsFromJson(String attemptsJson) =>
    DrillAttempts.fromJson(jsonDecode(attemptsJson));
