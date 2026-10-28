import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/tournament_converters.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/tournament/tournament.dart';

/// Giải đấu của một người chơi trên máy này. Ghi xuống Drift trước, đồng bộ
/// sau (spec giải đấu §4.1); bên đồng bộ tự thấy dòng có `syncedAt` rỗng.
class TournamentRepository {
  TournamentRepository(
    this._db, {
    required this._userId,
    required this._now,
    required this._newId,
  });

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  SimpleSelectStatement<$TournamentRowsTable, TournamentRow> _liveQuery() =>
      _db.select(_db.tournamentRows)
        ..where((t) => t.userId.equals(_userId) & t.isDeleted.equals(false));

  /// Giải còn sống của người này, ngày bắt đầu mới nhất trước.
  Stream<List<Tournament>> watchAll() =>
      (_liveQuery()..orderBy([
            (t) => OrderingTerm.desc(t.startDate),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch()
          .map((rows) => rows.map(toTournament).toList());

  void _validate(TournamentDraft draft) {
    final errors = tournamentInputErrors(draft);
    if (errors.isNotEmpty) {
      throw ArgumentError.value(errors, 'draft', 'Giải không hợp lệ');
    }
  }

  Future<String> create(TournamentDraft draft) async {
    _validate(draft);
    final id = _newId();
    final now = _now();
    await _db
        .into(_db.tournamentRows)
        .insert(
          TournamentRowsCompanion.insert(
            id: id,
            userId: _userId,
            name: draft.name.trim(),
            startDate: dateOnly(draft.startDate),
            endDate: Value(
              draft.endDate == null ? null : dateOnly(draft.endDate!),
            ),
            location: Value(trimmedOrNull(draft.location)),
            gameType: Value(draft.gameType?.name),
            resultNote: Value(trimmedOrNull(draft.resultNote)),
            notes: Value(trimmedOrNull(draft.notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, TournamentDraft draft) async {
    _validate(draft);
    final changed =
        await (_db.update(_db.tournamentRows)..where(
              (t) =>
                  t.id.equals(id) &
                  t.userId.equals(_userId) &
                  t.isDeleted.equals(false),
            ))
            .write(
              TournamentRowsCompanion(
                name: Value(draft.name.trim()),
                startDate: Value(dateOnly(draft.startDate)),
                endDate: Value(
                  draft.endDate == null ? null : dateOnly(draft.endDate!),
                ),
                location: Value(trimmedOrNull(draft.location)),
                gameType: Value(draft.gameType?.name),
                resultNote: Value(trimmedOrNull(draft.resultNote)),
                notes: Value(trimmedOrNull(draft.notes)),
                updatedAt: Value(_now()),
                syncedAt: const Value(null),
              ),
            );
    if (changed == 0) throw StateError('Không có giải $id để sửa');
  }

  /// Xóa mềm. Không đụng trận hay mục tiêu trỏ tới giải: chúng giữ `tournament_id`.
  Future<void> remove(String id) async {
    final changed =
        await (_db.update(_db.tournamentRows)..where(
              (t) =>
                  t.id.equals(id) &
                  t.userId.equals(_userId) &
                  t.isDeleted.equals(false),
            ))
            .write(
              TournamentRowsCompanion(
                isDeleted: const Value(true),
                updatedAt: Value(_now()),
                syncedAt: const Value(null),
              ),
            );
    if (changed == 0) throw StateError('Không có giải $id để xóa');
  }
}
