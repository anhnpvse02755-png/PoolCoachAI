import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/coach_context.dart';

/// Lịch sử Coach Chat của một tài khoản trên máy này — chỉ trên máy này,
/// không đồng bộ (spec Giai đoạn B mục 8). Giữ tối đa [coachChatKeptTurns]
/// lượt mới nhất của mỗi tài khoản; xoá chỉ đụng tới dòng của tài khoản đó.
class CoachChatRepository {
  CoachChatRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  /// Lượt của người này, cũ nhất trước.
  Stream<List<CoachChatEntry>> watchTurns() =>
      (_db.select(_db.coachChatTurnRows)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]))
          .watch()
          .map((rows) => rows.map(_toEntry).toList());

  /// [count] lượt cuối của người này, cũ trước.
  Future<List<CoachChatEntry>> recentTurns(int count) async {
    final rows = await (_db.select(_db.coachChatTurnRows)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
          ..limit(count))
        .get();
    return rows.reversed.map(_toEntry).toList();
  }

  /// Một giao dịch: câu hỏi, câu trả lời (bị chặn thì message rỗng,
  /// insufficient true), rồi xoá dòng của người này cũ hơn dòng mới thứ
  /// [coachChatKeptTurns].
  Future<void> addExchange({
    required String question,
    required DateTime askedAt,
    required CoachChatReply reply,
    required DateTime answeredAt,
  }) =>
      _db.transaction(() async {
        await _db.into(_db.coachChatTurnRows).insert(
              CoachChatTurnRowsCompanion.insert(
                userId: userId,
                createdAt: askedAt,
                fromPlayer: true,
                message: question,
              ),
            );
        await _db.into(_db.coachChatTurnRows).insert(
              CoachChatTurnRowsCompanion.insert(
                userId: userId,
                createdAt: answeredAt,
                fromPlayer: false,
                message: reply.text,
                insufficient: Value(reply.insufficient),
              ),
            );
        await _trim();
      });

  /// Chỉ xoá dòng của [userId]; tài khoản khác trên cùng máy không bị đụng.
  Future<void> clear() => (_db.delete(_db.coachChatTurnRows)..where((t) => t.userId.equals(userId))).go();

  Future<void> _trim() async {
    final countColumn = _db.coachChatTurnRows.id.count();
    final countQuery = _db.selectOnly(_db.coachChatTurnRows)
      ..addColumns([countColumn])
      ..where(_db.coachChatTurnRows.userId.equals(userId));
    final total = await countQuery.map((row) => row.read(countColumn)!).getSingle();
    final excess = total - coachChatKeptTurns;
    if (excess <= 0) return;

    final staleIds = await (_db.select(_db.coachChatTurnRows)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)])
          ..limit(excess))
        .map((row) => row.id)
        .get();
    await (_db.delete(_db.coachChatTurnRows)..where((t) => t.id.isIn(staleIds))).go();
  }

  CoachChatEntry _toEntry(CoachChatTurnRow row) => (
        id: row.id,
        at: row.createdAt,
        fromPlayer: row.fromPlayer,
        text: row.message,
        insufficient: row.insufficient,
      );
}
