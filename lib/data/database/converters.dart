import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/codecs/practice_codecs.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/cue_equipment.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';
import 'package:poolcoachai/domain/schedule_slot.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/domain/timer_session.dart';

// ─── Drill ──────────────────────────────────────────────────────────────────

Drill toDrill(DrillRow row) {
  return Drill(
    id: row.id,
    cat: _parseCategory(row.cat),
    name: row.name,
    level: row.level,
    unit: row.unit,
    goal: row.goal,
    steps: _parseStringList(row.steps),
    passThreshold: row.passThreshold,
    target: row.target,
  );
}

DrillRowsCompanion toDrillRow(Drill drill) {
  return DrillRowsCompanion(
    id: drift.Value(drill.id),
    cat: drift.Value(drill.cat.name),
    name: drift.Value(drill.name),
    level: drift.Value(drill.level),
    unit: drift.Value(drill.unit),
    goal: drift.Value(drill.goal),
    steps: drift.Value(_stringListToJson(drill.steps)),
    passThreshold: drill.passThreshold != null
        ? drift.Value(drill.passThreshold)
        : const drift.Value.absent(),
    target: drill.target != null ? drift.Value(drill.target!.toDouble()) : const drift.Value.absent(),
  );
}

// ─── DrillLog ───────────────────────────────────────────────────────────────

DrillLog toDrillLog(DrillLogRow row) {
  return DrillLog(
    id: row.id,
    drillId: row.drillId,
    date: row.date,
    score: row.score,
    attempts: row.attempts,
    notes: row.notes,
    durationSec: row.durationSec,
  );
}

DrillLogRowsCompanion toDrillLogRow(DrillLog log, {required String userId}) {
  return DrillLogRowsCompanion(
    id: drift.Value(log.id),
    userId: drift.Value(userId),
    drillId: drift.Value(log.drillId),
    date: drift.Value(log.date),
    score: drift.Value(log.score.toDouble()),
    attempts: log.attempts != null
        ? drift.Value(log.attempts!)
        : const drift.Value.absent(),
    notes: log.notes != null
        ? drift.Value(log.notes!)
        : const drift.Value.absent(),
    durationSec: log.durationSec != null
        ? drift.Value(log.durationSec!)
        : const drift.Value.absent(),
  );
}

/// Buổi tập dạng JSON cho `POST /items/drill_logs`.
///
/// Không gửi chủ: server tự điền `user_created` từ token, app không
/// giả mạo được.
Map<String, Object?> toRemoteDrillLog(DrillLogRow row) => {
  'id': row.id,
  'drill_id': row.drillId,
  'date': row.date.toUtc().toIso8601String(),
  'score': row.score,
  'attempts': row.attempts,
  'notes': row.notes,
  'duration_sec': row.durationSec,
};

/// Buổi tập kéo từ server về, gắn cho [userId] và đánh dấu đã đồng bộ.
DrillLogRowsCompanion fromRemoteDrillLog(
  Map<String, Object?> json, {
  required String userId,
  required DateTime syncedAt,
}) {
  final log = drillLogFromRemote(json);
  return DrillLogRowsCompanion.insert(
    id: log.id,
    userId: userId,
    drillId: log.drillId,
    date: log.date,
    score: log.score.toDouble(),
    attempts: drift.Value(log.attempts),
    notes: drift.Value(log.notes),
    durationSec: drift.Value(log.durationSec),
    syncedAt: drift.Value(syncedAt),
  );
}

// ─── KnowledgeArticle ────────────────────────────────────────────────────────

KnowledgeArticle toKnowledge(KnowledgeRow row) {
  return KnowledgeArticle(
    id: row.id,
    cat: _parseCategory(row.cat),
    title: row.title,
    body: row.body,
    relatedDrillIds: _parseStringList(row.relatedDrillIds),
  );
}

KnowledgeRowsCompanion toKnowledgeRow(KnowledgeArticle article) {
  return KnowledgeRowsCompanion(
    id: drift.Value(article.id),
    cat: drift.Value(article.cat.name),
    title: drift.Value(article.title),
    body: drift.Value(article.body),
    relatedDrillIds: drift.Value(_stringListToJson(article.relatedDrillIds)),
  );
}

// ─── ScheduleSlot ────────────────────────────────────────────────────────────

ScheduleSlot toScheduleSlot(ScheduleSlotRow row) {
  return ScheduleSlot(
    id: row.id,
    day: row.day,
    time: row.time,
    label: row.label,
    cat: row.cat != null ? _parseCategory(row.cat!) : null,
  );
}

ScheduleSlotRowsCompanion toScheduleSlotRow(ScheduleSlot slot) {
  return ScheduleSlotRowsCompanion(
    id: drift.Value(slot.id),
    day: drift.Value(slot.day),
    time: drift.Value(slot.time),
    label: drift.Value(slot.label),
    cat: slot.cat != null
        ? drift.Value(slot.cat!.name)
        : const drift.Value.absent(),
  );
}

// ─── TimerSession ────────────────────────────────────────────────────────────

TimerSession toTimerSession(TimerSessionRow row) {
  return TimerSession(
    id: row.id,
    date: row.date,
    durationSec: row.durationSec,
    cat: row.cat != null ? _parseCategory(row.cat!) : null,
    cueId: row.cueId,
  );
}

TimerSessionRowsCompanion toTimerSessionRow(TimerSession session) {
  return TimerSessionRowsCompanion(
    id: drift.Value(session.id),
    date: drift.Value(session.date),
    durationSec: drift.Value(session.durationSec),
    cat: session.cat != null
        ? drift.Value(session.cat!.name)
        : const drift.Value.absent(),
    cueId: session.cueId != null
        ? drift.Value(session.cueId!)
        : const drift.Value.absent(),
  );
}

// ─── Cue equipment ─────────────────────────────────────────────────────────

CueEquipment toCueEquipment(CueEquipmentRow row) {
  final type = CueType.values.firstWhere(
    (value) => value.name == row.type,
    orElse: () => throw FormatException('Unknown CueType: ${row.type}'),
  );
  final hardnessName = row.tipHardness;
  final hardness = hardnessName == null
      ? null
      : TipHardness.values.firstWhere(
          (value) => value.name == hardnessName,
          orElse: () =>
              throw FormatException('Unknown TipHardness: $hardnessName'),
        );
  final skills = _parseStringList(row.skillCategories)
      .map(_parseCategory)
      .toList(growable: false);

  return CueEquipment(
    id: row.id,
    name: row.name,
    type: type,
    weightGrams: row.weightGrams,
    shaftBrand: row.shaftBrand,
    shaftDiameterMm: row.shaftDiameterMm,
    tipBrand: row.tipBrand,
    tipHardness: hardness,
    buttBrand: row.buttBrand,
    skillCategories: skills,
    lastTipMaintenance: row.lastTipMaintenance,
    tipMaintenanceDueDate: row.tipMaintenanceDueDate,
    updatedAt: row.updatedAt,
  );
}

CueEquipmentRowsCompanion toCueEquipmentRow(
  CueEquipment cue, {
  required String userId,
  DateTime? syncedAt,
  bool isDeleted = false,
}) =>
    CueEquipmentRowsCompanion(
      id: drift.Value(cue.id),
      userId: drift.Value(userId),
      name: drift.Value(cue.name),
      type: drift.Value(cue.type.name),
      weightGrams: drift.Value(cue.weightGrams),
      shaftBrand: drift.Value(cue.shaftBrand),
      shaftDiameterMm: drift.Value(cue.shaftDiameterMm),
      tipBrand: drift.Value(cue.tipBrand),
      tipHardness: drift.Value(cue.tipHardness?.name),
      buttBrand: drift.Value(cue.buttBrand),
      skillCategories: drift.Value(
        _stringListToJson(cue.skillCategories.map((category) => category.name).toList()),
      ),
      lastTipMaintenance: drift.Value(cue.lastTipMaintenance),
      tipMaintenanceDueDate: drift.Value(cue.tipMaintenanceDueDate),
      updatedAt: drift.Value(cue.updatedAt),
      syncedAt: drift.Value(syncedAt),
      isDeleted: drift.Value(isDeleted),
    );

// ─── Helpers ─────────────────────────────────────────────────────────────────

SkillCategory _parseCategory(String name) {
  return SkillCategory.values.firstWhere(
    (c) => c.name == name,
    orElse: () => throw FormatException('Unknown SkillCategory: $name'),
  );
}

/// Đọc một cột JSON chứa danh sách chuỗi.
///
/// Hỏng thì **ném**, không trả danh sách rỗng. Một bài tập mất sạch
/// các bước mà màn hình vẫn dựng ra bình thường là màn hình nói dối:
/// người chơi thấy bài tập không có bước nào và tin là bài vốn thế.
/// Cùng lý do với assert trong hàm dựng [Drill] — hàng hỏng phải ồn
/// ào ngay lúc đọc.
///
/// Mảng rỗng thật thì [_stringListToJson] ghi ra `[]`, và `[]` đọc
/// lên vẫn là danh sách rỗng. Rỗng thật khác hẳn hỏng.
List<String> _parseStringList(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw FormatException('Cột danh sách phải là mảng JSON', json);
  }
  final list = <String>[];
  for (final item in decoded) {
    if (item is! String) {
      throw FormatException('Phần tử của mảng phải là chuỗi', json);
    }
    list.add(item);
  }
  return list;
}

String _stringListToJson(List<String> list) {
  return jsonEncode(list);
}
