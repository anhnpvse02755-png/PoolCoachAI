import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';

/// Số buổi của [userId] chưa lên server.
Future<int> pendingLogCount(AppDatabase db, String userId) async {
  final count = db.drillLogRows.id.count();
  final query = db.selectOnly(db.drillLogRows)
    ..addColumns([count])
    ..where(
      db.drillLogRows.userId.equals(userId) & db.drillLogRows.syncedAt.isNull(),
    );
  return (await query.getSingle()).read(count) ?? 0;
}

/// Buổi chờ không bao giờ lên được server: điểm vô hạn nằm được trong
/// SQLite nhưng JSON thì không. Máy chặn buổi mới như vậy từ lúc nhập,
/// nhưng buổi ghi trước đó vẫn có thể còn trên máy.
bool isUnsyncable(DrillLogRow row) => !row.score.isFinite;

SimpleSelectStatement<$DrillLogRowsTable, DrillLogRow> _pendingOf(
  AppDatabase db,
  String userId,
) =>
    db.select(db.drillLogRows)
      ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull());

Stream<int> watchUnsyncableCount(AppDatabase db, String userId) => _pendingOf(
  db,
  userId,
).watch().map((rows) => rows.where(isUnsyncable).length);

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

/// Đăng xuất do **người chơi bấm**: xoá dữ liệu luyện tập của họ khỏi máy,
/// để người dùng sau trên cùng máy không thấy.
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
  await (db.delete(
    db.drillLogRows,
  )..where((t) => t.userId.equals(userId))).go();
  await (db.delete(
    db.timerSessionRows,
  )..where((t) => t.userId.equals(userId))).go();
  await (db.delete(
    db.scheduleSlotRows,
  )..where((t) => t.userId.equals(userId))).go();
  await (db.delete(
    db.cueEquipmentRows,
  )..where((t) => t.userId.equals(userId))).go();
  await (db.delete(
    db.poolMatchRows,
  )..where((t) => t.userId.equals(userId))).go();
  // Hạng và bài kiểm tra cũng là dữ liệu riêng của người này.
  await (db.delete(
    db.playerRankRows,
  )..where((t) => t.userId.equals(userId))).go();
  final tests = db.selectOnly(db.buTestRows)
    ..addColumns([db.buTestRows.id])
    ..where(db.buTestRows.userId.equals(userId));
  await (db.delete(
    db.buDrillResultRows,
  )..where((r) => r.testId.isInQuery(tests))).go();
  await (db.delete(db.buTestRows)..where((t) => t.userId.equals(userId))).go();
  // Mục tiêu và thành tích cũng là dữ liệu riêng của người này.
  await (db.delete(
    db.playerGoalRows,
  )..where((t) => t.userId.equals(userId))).go();
  await (db.delete(
    db.achievementRows,
  )..where((t) => t.userId.equals(userId))).go();
  // Lần làm tình huống Coach cũng là dữ liệu riêng của người này.
  await (db.delete(
    db.coachAttemptRows,
  )..where((t) => t.userId.equals(userId))).go();
}

/// Dòng hạng và lần kiểm tra đã xong của [userId] chưa lên server. Lần đang
/// làm dở không tính: nó chỉ lên server khi xong (D10 của kế hoạch).
Future<int> pendingAssessmentCount(AppDatabase db, String userId) async {
  final rank = await (db.select(
    db.playerRankRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  final tests =
      await (db.select(db.buTestRows)..where(
            (t) =>
                t.userId.equals(userId) &
                t.syncedAt.isNull() &
                (t.completedAt.isNotNull() | t.cancelledAt.isNotNull()),
          ))
          .get();
  return rank.length + tests.length;
}

/// Dòng mục tiêu và thành tích của [userId] chưa lên server.
Future<int> pendingRoadmapCount(AppDatabase db, String userId) async {
  final goals = await (db.select(
    db.playerGoalRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  final achievements = await (db.select(
    db.achievementRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  return goals.length + achievements.length;
}

/// Lần làm tình huống Coach của [userId] chưa lên server.
Future<int> pendingCoachCount(AppDatabase db, String userId) async {
  final rows = await (db.select(
    db.coachAttemptRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  return rows.length;
}

Future<int> pendingCueEquipmentCount(AppDatabase db, String userId) async {
  final rows = await (db.select(db.cueEquipmentRows)..where(
        (t) => t.userId.equals(userId) & t.syncedAt.isNull(),
      ))
      .get();
  return rows.length;
}

/// Trận đấu, buổi tập tự do và khung lịch tập của [userId] chưa lên server.
/// Dòng không có chủ không tính: chúng không bao giờ được đẩy lên.
Future<int> pendingPracticeCount(AppDatabase db, String userId) async {
  final matches = await (db.select(
    db.poolMatchRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  final timers = await (db.select(
    db.timerSessionRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  final slots = await (db.select(
    db.scheduleSlotRows,
  )..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())).get();
  return matches.length + timers.length + slots.length;
}

/// [userId] có lần kiểm tra đang làm dở trên máy này không.
Future<bool> hasActiveTest(AppDatabase db, String userId) async {
  final rows =
      await (db.select(db.buTestRows)..where(
            (t) =>
                t.userId.equals(userId) &
                t.completedAt.isNull() &
                t.cancelledAt.isNull(),
          ))
          .get();
  return rows.isNotEmpty;
}
