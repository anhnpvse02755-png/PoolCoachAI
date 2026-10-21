import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

/// Lần mô phỏng [key] chưa có trong [SimCache]: đơn vị việc làm đúng lần đó
/// rồi chạy lại từ đầu (spec Planner mục 4.5, spec Coach mục 5.2).
class MissingSimulation implements Exception {
  const MissingSimulation(this.key);
  final ShotKey key;

  @override
  String toString() => 'MissingSimulation($key)';
}

/// Bộ nhớ mô phỏng của việc tính chia lát. Planner và Coach dùng chung một
/// bộ, để Coach chấm cú người chơi bằng đúng các lần mô phỏng Planner đã chạy.
///
/// Quá giờ được nhớ là null: tra ra null (phương án không dùng được), không
/// ném lại.
class SimCache {
  final _sims = <ShotKey, AimedShot?>{};

  /// Số lần mô phỏng đã nhớ, kể cả lần quá giờ.
  int get length => _sims.length;

  bool contains(ShotKey key) => _sims.containsKey(key);

  /// Tra một lần mô phỏng; chưa có thì ném [MissingSimulation].
  AimedShot? lookup(ShotKey key) {
    if (_sims.containsKey(key)) return _sims[key];
    throw MissingSimulation(key);
  }

  /// Mô phỏng [key] bằng [simulateKey] rồi nhớ lại.
  void fill(ShotKey key, {AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot}) {
    _sims[key] = simulateKey(key, aim: aim, table: table);
  }
}
