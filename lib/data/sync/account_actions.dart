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

/// Đăng xuất do **người chơi bấm**: xoá buổi tập của họ khỏi máy, để
/// người dùng sau trên cùng máy không thấy.
///
/// Tự động đăng xuất không bao giờ đi qua đây — nó giữ nguyên mọi thứ.
Future<void> signOutAndForget({
  required AppDatabase db,
  required AuthRepository auth,
  required String userId,
}) async {
  await (db.delete(db.drillLogRows)..where((t) => t.userId.equals(userId)))
      .go();
  await auth.signOut();
}
