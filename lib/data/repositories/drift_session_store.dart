import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';

/// Phiên đăng nhập lưu trong Drift — giống nhau trên web và mobile.
class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  @override
  Future<StoredSession?> read() async {
    final row = await _db.select(_db.authSessionRows).getSingleOrNull();
    if (row == null) return null;
    return StoredSession(
      userId: row.userId,
      displayName: row.displayName,
      refreshToken: row.refreshToken,
    );
  }

  @override
  Future<void> write(StoredSession session) async {
    await _db.into(_db.authSessionRows).insertOnConflictUpdate(
          AuthSessionRowsCompanion.insert(
            userId: session.userId,
            displayName: session.displayName,
            refreshToken: session.refreshToken,
          ),
        );
  }

  @override
  Future<void> clear() => _db.delete(_db.authSessionRows).go();
}
