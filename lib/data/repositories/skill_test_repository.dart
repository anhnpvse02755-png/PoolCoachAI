import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/skill_test_converters.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/skill_test/skill_test.dart';
import 'package:poolcoachai/domain/skill_test/skill_test_gate.dart';

sealed class SkillTestOutcome {
  const SkillTestOutcome();
}

final class SkillTestRecorded extends SkillTestOutcome {
  const SkillTestRecorded(this.test);
  final SkillTest test;
}

final class SkillTestLocked extends SkillTestOutcome {
  const SkillTestLocked(this.gate);
  final SkillTestGate gate;
}

/// Lần kiểm tra kỹ năng của một người chơi trên máy này. Chỉ thêm: mỗi dòng
/// ghi một lần khi xong (hoàn tất hoặc huỷ); bên đồng bộ tự thấy dòng có
/// `syncedAt` rỗng.
class SkillTestRepository {
  SkillTestRepository(
    this._db, {
    required this._userId,
    required this._now,
    required this._newId,
  });

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Lần kiểm tra của chính người này, mới nhất trước. Dòng không dùng được
  /// (dữ liệu lạ từ máy chủ mới hơn) bị bỏ.
  Stream<List<SkillTest>> watchTests() =>
      (_db.select(_db.skillTestRows)
            ..where((t) => t.userId.equals(_userId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch()
          .map(_usable);

  static List<SkillTest> _usable(List<SkillTestRow> rows) => [
    for (final r in rows) ?toSkillTest(r),
  ];

  /// Ghi lần kiểm tra hoàn tất. Ném [ArgumentError] khi kết quả không hợp lệ,
  /// trước khi ghi gì. Trong giao dịch, tính lại cổng: chưa mở thì trả
  /// [SkillTestLocked] và không ghi (chặn nộp hai lần).
  ///
  /// `passed` luôn tính tại đây từ ảnh chụp tiêu chí sẽ được ghi, không nhận
  /// từ người gọi, nên khớp với `skillTestVerdict` của dòng.
  Future<SkillTestOutcome> completeTest({
    required Drill drill,
    required List<Drill> drills,
    required TableSize tableSize,
    required DateTime startedAt,
    required num score,
    int? attempts,
    String? notes,
  }) async {
    final error = checkSkillTestInput(drill, score: score, attempts: attempts);
    if (error != null) {
      throw ArgumentError.value(score, 'score', error.name);
    }
    return _db.transaction<SkillTestOutcome>(() async {
      final rows = await (_db.select(
        _db.skillTestRows,
      )..where((t) => t.userId.equals(_userId))).get();
      // Buổi tập đọc trong cùng giao dịch với cổng: không tin danh sách từ
      // người gọi, và không có khe hở giữa kiểm tra và ghi.
      final logRows = await (_db.select(_db.drillLogRows)
            ..where((t) => t.userId.equals(_userId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();
      final gate = skillTestGate(
        drill: drill,
        drills: drills,
        logs: [for (final l in logRows) toDrillLog(l)],
        tests: _usable(rows),
      );
      if (gate is! SkillTestOpen) return SkillTestLocked(gate);

      final id = _newId();
      final completedAt = _now();
      SkillTest build(bool? passed) => SkillTest(
        id: id,
        drillId: drill.id,
        drillLevel: drill.level,
        tableSize: tableSize,
        startedAt: startedAt,
        completedAt: completedAt,
        score: score,
        attempts: attempts,
        passed: passed,
        notes: notes,
        passThreshold: drill.passThreshold,
        target: drill.target,
      );
      final verdict = skillTestVerdict(build(null));
      if (verdict == null) {
        throw StateError('Không chấm được lần kiểm tra ${drill.id}');
      }
      final test = build(verdict);
      await _db
          .into(_db.skillTestRows)
          .insert(toSkillTestRow(test, userId: _userId));
      return SkillTestRecorded(test);
    });
  }

  /// Huỷ sau "Bắt đầu kiểm tra": dòng huỷ không có kết quả, không tính là trượt.
  Future<void> cancelTest({
    required Drill drill,
    required TableSize tableSize,
    required DateTime startedAt,
  }) => _db
      .into(_db.skillTestRows)
      .insert(
        toSkillTestRow(
          SkillTest(
            id: _newId(),
            drillId: drill.id,
            drillLevel: drill.level,
            tableSize: tableSize,
            startedAt: startedAt,
            cancelledAt: _now(),
          ),
          userId: _userId,
        ),
      );
}
