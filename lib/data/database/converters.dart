import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
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
  );
}

DrillLogRowsCompanion toDrillLogRow(DrillLog log) {
  return DrillLogRowsCompanion(
    id: drift.Value(log.id),
    drillId: drift.Value(log.drillId),
    date: drift.Value(log.date),
    score: drift.Value(log.score.toDouble()),
    attempts: log.attempts != null
        ? drift.Value(log.attempts!)
        : const drift.Value.absent(),
    notes: log.notes != null
        ? drift.Value(log.notes!)
        : const drift.Value.absent(),
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
