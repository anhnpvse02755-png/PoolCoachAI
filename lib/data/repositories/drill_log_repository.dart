import 'package:poolcoachai/domain/drill_log.dart';

/// Repository interface for drill logs — abstracts the storage backend.
///
/// WatchAll trả cũ nhất trước — đúng thứ tự categoryMastery() đòi.
abstract interface class DrillLogRepository {
  Stream<List<DrillLog>> watchAll();
  Future<void> add(DrillLog log);
}
