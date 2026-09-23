import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/drill_log_repository.dart';
import 'package:poolcoachai/data/repositories/seed_repositories.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/knowledge_article.dart';

/// Drift implementation of DrillRepository.
class DriftDrillRepository implements DrillRepository {
  DriftDrillRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Drill>> watchAll() {
    return _db.select(_db.drillRows).watch().map(
          (rows) => rows.map(toDrill).toList(),
        );
  }
}

/// Drift implementation of KnowledgeRepository.
class DriftKnowledgeRepository implements KnowledgeRepository {
  DriftKnowledgeRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<KnowledgeArticle>> watchAll() {
    return _db.select(_db.knowledgeRows).watch().map(
          (rows) => rows.map(toKnowledge).toList(),
        );
  }
}

/// Buổi tập của **một** người dùng trên Drift.
///
/// watchAll trả cũ nhất trước — đúng thứ tự categoryMastery() đòi — và
/// chỉ của [userId]: người đăng nhập sau trên cùng máy không thấy buổi
/// của người trước.
class DriftDrillLogRepository implements DrillLogRepository {
  DriftDrillLogRepository(this._db, {required this._userId});

  final AppDatabase _db;
  final String _userId;

  @override
  Stream<List<DrillLog>> watchAll() {
    return _db.watchDrillLogsOf(_userId).map(
          (rows) => rows.map(toDrillLog).toList(),
        );
  }

  /// Ghi vào máy với `syncedAt` rỗng; SyncService tự thấy và đẩy lên.
  @override
  Future<void> add(DrillLog log) async {
    await _db.into(_db.drillLogRows).insert(toDrillLogRow(log, userId: _userId));
  }
}
