import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

/// Ngày từ máy chủ; null khi thiếu hoặc không đọc được.
DateTime? _local(Object? s) =>
    s is String ? DateTime.tryParse(s)?.toLocal() : null;

/// Dựng [SkillTest] từ các trường, hoặc null khi dòng không dùng được. Dòng
/// lạ (máy chủ mới hơn, dữ liệu hỏng) bị bỏ chứ không ném, để các dòng còn
/// lại vẫn đi qua (forward-compat).
///
/// Không dùng được khi: `table_size` lạ, cả hai trường tiêu chí cùng có, hoặc
/// lần hoàn tất có điểm mà thiếu ảnh chụp tiêu chí (không chấm lại được).
SkillTest? _build({
  required String id,
  required String drillId,
  required int drillLevel,
  required String tableSize,
  required DateTime startedAt,
  required DateTime? completedAt,
  required DateTime? cancelledAt,
  required num? score,
  required int? attempts,
  required bool? passed,
  required String? notes,
  required double? passThreshold,
  required num? target,
}) {
  final size = TableSize.values.asNameMap()[tableSize];
  if (size == null) return null;
  if (passThreshold != null && target != null) return null;
  if (completedAt != null &&
      cancelledAt == null &&
      score != null &&
      passThreshold == null &&
      target == null) {
    return null;
  }
  return SkillTest(
    id: id,
    drillId: drillId,
    drillLevel: drillLevel,
    tableSize: size,
    startedAt: startedAt,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    score: score,
    attempts: attempts,
    passed: passed,
    notes: notes,
    passThreshold: passThreshold,
    target: target,
  );
}

/// Null khi dòng không dùng được (xem `_build`).
SkillTest? toSkillTest(SkillTestRow r) => _build(
  id: r.id,
  drillId: r.drillId,
  drillLevel: r.drillLevel,
  tableSize: r.tableSize,
  startedAt: r.startedAt,
  completedAt: r.completedAt,
  cancelledAt: r.cancelledAt,
  score: r.score,
  attempts: r.attempts,
  passed: r.passed,
  notes: r.notes,
  passThreshold: r.passThreshold,
  target: r.target,
);

SkillTestRow toSkillTestRow(
  SkillTest t, {
  required String userId,
  DateTime? syncedAt,
}) => SkillTestRow(
  id: t.id,
  userId: userId,
  drillId: t.drillId,
  drillLevel: t.drillLevel,
  tableSize: t.tableSize.name,
  startedAt: t.startedAt,
  completedAt: t.completedAt,
  cancelledAt: t.cancelledAt,
  score: t.score?.toDouble(),
  attempts: t.attempts,
  passed: t.passed,
  notes: t.notes,
  passThreshold: t.passThreshold,
  target: t.target?.toDouble(),
  syncedAt: syncedAt,
);

const remoteSkillTestFields =
    'id,drill_id,drill_level,table_size,started_at,completed_at,cancelled_at,'
    'score,attempts,passed,notes,pass_threshold,target';

/// Dòng cho `POST /items/skill_tests`. Không gửi chủ (`user_created` do máy
/// chủ điền).
Map<String, Object?> toRemoteSkillTest(SkillTestRow r) => {
  'id': r.id,
  'drill_id': r.drillId,
  'drill_level': r.drillLevel,
  'table_size': r.tableSize,
  'started_at': _iso(r.startedAt),
  'completed_at': _iso(r.completedAt),
  'cancelled_at': _iso(r.cancelledAt),
  'score': r.score,
  'attempts': r.attempts,
  'passed': r.passed,
  'notes': r.notes,
  'pass_threshold': r.passThreshold,
  'target': r.target,
};

/// Null khi dòng máy chủ không dùng được: table_size lạ, trường sai kiểu hay
/// thiếu, hoặc tiêu chí mâu thuẫn. Người gọi bỏ qua dòng đó.
SkillTestRow? skillTestFromRemote(
  Map<String, Object?> j, {
  required String userId,
  required DateTime syncedAt,
}) {
  // Trường có thể vắng (null) nhưng nếu có thì phải đúng kiểu.
  bool ok<T>(String k) => j[k] == null || j[k] is T;
  if (j['id'] is! String ||
      j['drill_id'] is! String ||
      j['drill_level'] is! int ||
      j['table_size'] is! String) {
    return null;
  }
  if (!ok<num>('score') ||
      !ok<int>('attempts') ||
      !ok<bool>('passed') ||
      !ok<String>('notes') ||
      !ok<num>('pass_threshold') ||
      !ok<num>('target')) {
    return null;
  }
  final startedAt = _local(j['started_at']);
  final completedAt = _local(j['completed_at']);
  final cancelledAt = _local(j['cancelled_at']);
  if (startedAt == null ||
      (j['completed_at'] != null && completedAt == null) ||
      (j['cancelled_at'] != null && cancelledAt == null)) {
    return null;
  }
  final row = SkillTestRow(
    id: j['id']! as String,
    userId: userId,
    drillId: j['drill_id']! as String,
    drillLevel: j['drill_level']! as int,
    tableSize: j['table_size']! as String,
    startedAt: startedAt,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    score: (j['score'] as num?)?.toDouble(),
    attempts: j['attempts'] as int?,
    passed: j['passed'] as bool?,
    notes: j['notes'] as String?,
    passThreshold: (j['pass_threshold'] as num?)?.toDouble(),
    target: (j['target'] as num?)?.toDouble(),
    syncedAt: syncedAt,
  );
  return toSkillTest(row) == null ? null : row;
}
