import 'package:poolcoachai/domain/drill_log.dart';

/// Repository interface for drill logs — abstracts the storage backend.
///
/// WatchAll trả cũ nhất trước — đúng thứ tự categoryMastery() đòi.
abstract interface class DrillLogRepository {
  Stream<List<DrillLog>> watchAll();
  Future<void> add(DrillLog log);
}

/// Khi chưa đăng nhập: không có buổi tập nào, và không ghi được.
///
/// Router chặn mọi màn tập khi chưa đăng nhập, nên [add] chỉ chạy khi có
/// lỗi lập trình — ném ra để lỗi hiện ngay, không lặng lẽ mất dữ liệu.
class SignedOutDrillLogRepository implements DrillLogRepository {
  const SignedOutDrillLogRepository();

  @override
  Stream<List<DrillLog>> watchAll() => Stream.value(const []);

  @override
  Future<void> add(DrillLog log) =>
      Future.error(StateError('Chưa đăng nhập thì không ghi buổi tập được'));
}
