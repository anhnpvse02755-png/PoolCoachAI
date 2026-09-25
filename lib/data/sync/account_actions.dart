import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';

/// Số buổi của [userId] chưa lên server.
Future<int> pendingLogCount(AppDatabase db, String userId) async {
  final count = db.drillLogRows.id.count();
  final query = db.selectOnly(db.drillLogRows)
    ..addColumns([count])
    ..where(db.drillLogRows.userId.equals(userId) &
        db.drillLogRows.syncedAt.isNull());
  return (await query.getSingle()).read(count) ?? 0;
}

/// Buổi chờ không bao giờ lên được server: điểm vô hạn nằm được trong
/// SQLite nhưng JSON thì không. Máy chặn buổi mới như vậy từ lúc nhập,
/// nhưng buổi ghi trước đó vẫn có thể còn trên máy.
bool isUnsyncable(DrillLogRow row) => !row.score.isFinite;

SimpleSelectStatement<$DrillLogRowsTable, DrillLogRow> _pendingOf(
        AppDatabase db, String userId) =>
    db.select(db.drillLogRows)
      ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull());

Stream<int> watchUnsyncableCount(AppDatabase db, String userId) =>
    _pendingOf(db, userId)
        .watch()
        .map((rows) => rows.where(isUnsyncable).length);

/// Như [watchUnsyncableCount] nhưng đọc một lần.
Future<int> unsyncableLogCount(AppDatabase db, String userId) async =>
    (await _pendingOf(db, userId).get()).where(isUnsyncable).length;

/// Người chơi bấm bỏ: xoá các buổi đó khỏi máy. Chỉ gọi sau khi họ xác nhận.
Future<void> discardUnsyncableLogs(AppDatabase db, String userId) async {
  final rows = await _pendingOf(db, userId).get();
  final ids = rows.where(isUnsyncable).map((r) => r.id).toList();
  if (ids.isEmpty) return;
  await (db.delete(db.drillLogRows)..where((t) => t.id.isIn(ids))).go();
}

/// Đăng xuất do **người chơi bấm**: xoá buổi tập của họ khỏi máy, để
/// người dùng sau trên cùng máy không thấy.
///
/// Đăng xuất **trước** rồi mới xoá: lượt đồng bộ đang chạy thấy người
/// dùng đổi thì bỏ kết quả kéo về, nên không dựng lại những dòng vừa xoá.
///
/// Tự động đăng xuất không bao giờ đi qua đây — nó giữ nguyên mọi thứ.
Future<void> signOutAndForget({
  required AppDatabase db,
  required AuthRepository auth,
  required String userId,
}) async {
  await auth.signOut();
  await (db.delete(db.drillLogRows)..where((t) => t.userId.equals(userId)))
      .go();
}
