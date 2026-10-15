import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Mục tiêu và thành tích của một người chơi trên máy này. Ghi xuống Drift
/// trước, đồng bộ sau (spec 2026-10-15 mục 6) — bên đồng bộ tự thấy dòng có
/// `syncedAt` rỗng.
class RoadmapRepository {
  RoadmapRepository(
    this._db, {
    required this._userId,
    required this._now,
    required this._newId,
  });

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  SimpleSelectStatement<$PlayerGoalRowsTable, PlayerGoalRow> _goalQuery() =>
      _db.select(_db.playerGoalRows)..where((t) => t.userId.equals(_userId));

  Stream<GoalRecord?> watchGoal() =>
      _goalQuery().watchSingleOrNull().map((r) => r == null ? null : toGoalRecord(r));

  /// Đặt (hoặc đổi) mục tiêu: id mới, tính lại từ đầu (spec mục 2.4).
  Future<void> setGoal({required GoalKind kind, SkillCategory? category, DateTime? eventDate}) {
    final now = _now();
    return _write(GoalRecord(
      updatedAt: now,
      goal: PlayerGoal(
        goalId: _newId(),
        kind: kind,
        category: kind == GoalKind.thuanThucKyNang ? category : null,
        eventDate: kind == GoalKind.chuanBiGiai
            ? DateTime(eventDate!.year, eventDate.month, eventDate.day)
            : null,
        createdAt: now,
      ),
    ));
  }

  Future<void> clearGoal() => _write(GoalRecord(updatedAt: _now()));

  // toCompanion(false): ghi cả cột null. Ghi thẳng dòng dữ liệu thì Drift bỏ
  // cột null, nên bỏ mục tiêu hay đổi sang loại không có nhóm sẽ giữ giá trị cũ.
  Future<void> _write(GoalRecord g) => _db
      .into(_db.playerGoalRows)
      .insertOnConflictUpdate(toGoalRow(g, userId: _userId).toCompanion(false));

  Stream<List<Achievement>> watchAchievements() => (_db.select(_db.achievementRows)
        ..where((t) => t.userId.equals(_userId))
        ..orderBy([(t) => OrderingTerm.desc(t.achievedAt), (t) => OrderingTerm.asc(t.refId)]))
      .watch()
      .map((rows) => rows.map(toAchievement).toList());

  /// Thành tích đã có (cùng id) thì bỏ qua — chỉ thêm, không sửa.
  Future<void> recordAchievements(List<Achievement> list) => _db.batch((b) {
        for (final a in list) {
          b.insert(_db.achievementRows, toAchievementRow(a, userId: _userId),
              mode: InsertMode.insertOrIgnore);
        }
      });
}
