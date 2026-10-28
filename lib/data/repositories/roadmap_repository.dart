import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/domain/rank.dart';
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

  Stream<GoalRecord?> watchGoal() => _goalQuery().watchSingleOrNull().map(
    (r) => r == null ? null : toGoalRecord(r),
  );

  /// Đặt (hoặc đổi) mục tiêu: id mới, tính lại từ đầu (spec mục 2.4).
  Future<void> setGoal({
    required GoalKind kind,
    SkillCategory? category,
    DateTime? eventDate,
    Rank? targetRank,
    String? tournamentId,
  }) {
    final now = _now();
    return _write(
      GoalRecord(
        updatedAt: now,
        goal: PlayerGoal(
          goalId: _newId(),
          kind: kind,
          category: kind == GoalKind.thuanThucKyNang ? category : null,
          eventDate: kind == GoalKind.chuanBiGiai
              ? DateTime(eventDate!.year, eventDate.month, eventDate.day)
              : null,
          targetRank: kind == GoalKind.lenHang ? targetRank : null,
          createdAt: now,
          tournamentId: kind == GoalKind.chuanBiGiai ? tournamentId : null,
        ),
      ),
    );
  }

  /// Gắn giải vào mục tiêu Chuẩn bị giải hiện có (đã đúng ngày giải): không
  /// đổi `goalId` hay `createdAt`, không tính lại từ đầu. Mục tiêu không phải
  /// Chuẩn bị giải thì ném, để khỏi gắn nhầm.
  Future<void> linkTournament(String tournamentId) async {
    final changed =
        await (_db.update(_db.playerGoalRows)..where(
              (t) =>
                  t.userId.equals(_userId) &
                  t.kind.equals(GoalKind.chuanBiGiai.name),
            ))
            .write(
              PlayerGoalRowsCompanion(
                tournamentId: Value(tournamentId),
                updatedAt: Value(_now()),
                syncedAt: const Value(null),
              ),
            );
    if (changed == 0) throw StateError('Không có mục tiêu Chuẩn bị giải');
  }

  Future<void> clearGoal() => _write(GoalRecord(updatedAt: _now()));

  // toCompanion(false): ghi cả cột null. Ghi thẳng dòng dữ liệu thì Drift bỏ
  // cột null, nên bỏ mục tiêu hay đổi sang loại không có nhóm sẽ giữ giá trị cũ.
  Future<void> _write(GoalRecord g) => _db
      .into(_db.playerGoalRows)
      .insertOnConflictUpdate(toGoalRow(g, userId: _userId).toCompanion(false));

  Stream<List<Achievement>> watchAchievements() =>
      (_db.select(_db.achievementRows)
            ..where((t) => t.userId.equals(_userId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.achievedAt),
              (t) => OrderingTerm.asc(t.refId),
            ]))
          .watch()
          .map((rows) => rows.map(toAchievement).nonNulls.toList());

  /// Thành tích đã có (cùng id) thì bỏ qua — chỉ thêm, không sửa.
  ///
  /// Chứng nhận suy ra từ skill_tests nên không đẩy lên server (S13): đánh dấu
  /// đã đồng bộ ngay, để không hiện cảnh báo "chưa đồng bộ" mãi mãi.
  Future<void> recordAchievements(List<Achievement> list) => _db.batch((b) {
    for (final a in list) {
      final local = a.kind == AchievementKind.chungNhan;
      b.insert(
        _db.achievementRows,
        toAchievementRow(a, userId: _userId, syncedAt: local ? _now() : null),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}
