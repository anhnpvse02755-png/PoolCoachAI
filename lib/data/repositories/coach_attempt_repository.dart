import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/coach_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';

/// Lần làm tình huống Coach của một người chơi trên máy này. Ghi Drift
/// trước, đồng bộ sau (spec mục 11.4): bên đồng bộ tự thấy dòng có
/// `syncedAt` rỗng.
class CoachAttemptRepository {
  CoachAttemptRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  /// Mọi lần làm của người này, mới nhất trước.
  Stream<List<CoachAttempt>> watchAttempts() => (_db.select(_db.coachAttemptRows)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.finishedAt), (t) => OrderingTerm.asc(t.id)]))
      .watch()
      .map((rows) => rows.map(toCoachAttempt).toList());

  /// Chỉ thêm: cùng id đã có thì bỏ qua.
  Future<void> record(CoachAttempt attempt) => _db.into(_db.coachAttemptRows).insert(
        toCoachAttemptRow(attempt),
        mode: InsertMode.insertOrIgnore,
      );
}
