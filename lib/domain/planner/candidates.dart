import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một cặp bi–lỗ đánh được, chưa mô phỏng.
class Candidate {
  const Candidate(this.ball, this.geometry);

  final PlacedBall ball;
  final ShotGeometry geometry;

  double get angle => geometry.angle;
}

/// Cú dễ nhất từ một điểm, chỉ bằng hình học (spec mục 4.2).
///
/// Một hàm cho hai việc: chọn cặp bi–lỗ của bước này, và tìm "bi kế tiếp"
/// khi chấm vị trí (mục 5.1). Nhờ vậy điều Planner chấm ở bước trước đúng là
/// điều nó sẽ chọn ở bước sau. Nhớ kết quả theo (điểm, bi, tập bi chắn) —
/// một [CandidateFinder] chỉ dùng trong một kế hoạch, vì khoá dựa vào việc
/// mỗi số bi ở một chỗ cố định.
class CandidateFinder {
  CandidateFinder({required this.game, this.table = TableSpec.nineFoot});

  final GameType game;
  final TableSpec table;
  final _cache = <(Vec2, int, int), ShotGeometry?>{};

  /// Số cặp (điểm, bi) đã tính.
  int get cached => _cache.length;

  /// Cặp bi–lỗ có góc cắt nhỏ nhất trong các bi được đánh của [balls], từ
  /// [from]; hoà thì giữ bi số nhỏ hơn. null khi không cặp nào đánh được.
  Candidate? easiest(Vec2 from, List<PlacedBall> balls) {
    final mask = ballMask(balls);
    Candidate? best;
    for (final target in legalTargetsAmong(game, balls)) {
      final g = _cache.putIfAbsent(
        (from, target.number, mask),
        () => bestPocket(
          cue: from,
          object: target.pos,
          others: obstaclesFor(target, balls),
          table: table,
        ),
      );
      if (g == null) continue;
      final current = best;
      if (current == null || compareShots(g, current.geometry, table: table) < 0) {
        best = Candidate(target, g);
      }
    }
    return best;
  }
}
