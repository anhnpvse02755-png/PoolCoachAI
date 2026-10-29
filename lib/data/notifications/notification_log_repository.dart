import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/notifications/notification_log.dart';
import 'package:poolcoachai/domain/notifications/notification_plan.dart';
import 'package:poolcoachai/domain/notifications/notification_prefs.dart';

/// Nhật ký thông báo của một tài khoản trên máy này — không đồng bộ
/// (spec P6a §4). Chỉ ghi khi có khác biệt, để luồng theo dõi không phát lại
/// vô ích.
class NotificationLogRepository {
  NotificationLogRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  $NotificationLogRowsTable get _t => _db.notificationLogRows;

  Stream<List<NotificationLogEntry>> watchAll() {
    return (_db.select(
      _t,
    )..where((r) => r.userId.equals(userId))).watch().map(_entries);
  }

  /// Nhật ký lúc này, đọc thẳng từ DB (không qua luồng theo dõi, vốn có thể
  /// còn chậm một lần ghi).
  Future<List<NotificationLogEntry>> all() async => _entries(
    await (_db.select(_t)..where((r) => r.userId.equals(userId))).get(),
  );

  static List<NotificationLogEntry> _entries(List<NotificationLogRow> rows) => [
    for (final r in rows)
      if (_kindOf(r.kind) case final kind?)
        NotificationLogEntry(
          id: r.id,
          kind: kind,
          key: r.key,
          at: r.at,
          title: r.title,
          body: r.body,
          readAt: r.readAt,
        ),
  ];

  static NotificationKind? _kindOf(String name) {
    for (final k in NotificationKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }

  DateTime _cutoff(DateTime now) =>
      now.subtract(const Duration(days: notificationInboxDays));

  /// Đưa nhật ký khớp kế hoạch: xoá mục tương lai không còn trong kế hoạch,
  /// xoá mục quá 30 ngày, thêm mục mới của kế hoạch. Không đổi gì thì không
  /// chạy câu lệnh ghi nào.
  ///
  /// [cancelled]: id vừa bị huỷ khỏi lịch hệ điều hành khi còn chờ. Dòng của
  /// chúng bị xoá dù giờ đã qua: thông báo chưa từng hiện, hộp "Đã gửi"
  /// không được nhận là đã gửi.
  Future<void> syncPlanned(
    List<PlannedNotification> planned, {
    required DateTime now,
    Set<int> cancelled = const {},
  }) async {
    final rows = await (_db.select(
      _t,
    )..where((r) => r.userId.equals(userId))).get();
    final plannedIds = {for (final n in planned) n.id};
    final presentIds = {for (final r in rows) r.id};
    final cutoff = _cutoff(now);
    final staleIds = [
      for (final r in rows)
        if ((!plannedIds.contains(r.id) &&
                (r.at.isAfter(now) || cancelled.contains(r.id))) ||
            !r.at.isAfter(cutoff))
          r.id,
    ];
    final toInsert = [
      for (final n in planned)
        if (!presentIds.contains(n.id)) n,
    ];
    if (staleIds.isEmpty && toInsert.isEmpty) return;
    await _db.transaction(() async {
      if (staleIds.isNotEmpty) {
        await (_db.delete(
          _t,
        )..where((r) => r.userId.equals(userId) & r.id.isIn(staleIds))).go();
      }
      for (final n in toInsert) {
        await _db.into(_t).insert(_companion(n, n.at), mode: InsertMode.insertOrIgnore);
      }
    });
  }

  /// Ghi một thông báo vừa hiện (trên web, nơi không có lịch sẵn), kèm dọn
  /// mục quá 30 ngày.
  Future<void> recordShown(
    PlannedNotification n, {
    required DateTime at,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_t)
          .insert(_companion(n, at), mode: InsertMode.insertOrIgnore);
      await (_db.delete(_t)..where(
            (r) => r.userId.equals(userId) & r.at.isSmallerOrEqualValue(_cutoff(at)),
          ))
          .go();
    });
  }

  /// Đánh dấu đã đọc những mục chưa đọc trong [ids].
  Future<void> markRead(Iterable<int> ids, {required DateTime at}) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (_db.update(_t)..where(
          (r) => r.userId.equals(userId) & r.id.isIn(list) & r.readAt.isNull(),
        ))
        .write(NotificationLogRowsCompanion(readAt: Value(at)));
  }

  /// Đánh dấu đã đọc mọi mục đã tới giờ của (loại, khoá) này.
  Future<void> markReadByKey(
    NotificationKind kind,
    String key, {
    required DateTime now,
  }) async {
    await (_db.update(_t)..where(
          (r) =>
              r.userId.equals(userId) &
              r.kind.equals(kind.name) &
              r.key.equals(key) &
              r.at.isSmallerOrEqualValue(now) &
              r.readAt.isNull(),
        ))
        .write(NotificationLogRowsCompanion(readAt: Value(now)));
  }

  NotificationLogRowsCompanion _companion(PlannedNotification n, DateTime at) =>
      NotificationLogRowsCompanion.insert(
        userId: userId,
        id: n.id,
        kind: n.kind.name,
        key: n.key,
        at: at,
        title: n.title,
        body: n.body,
      );
}
