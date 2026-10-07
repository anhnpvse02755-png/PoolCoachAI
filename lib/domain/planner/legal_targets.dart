import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Bi được đánh lúc này, theo số tăng dần (spec mục 4.1).
///
/// 9 / 10 bi: chỉ bi số nhỏ nhất. 8 bi: mọi bi của tôi; hết thì bi 8; bi
/// đối thủ không bao giờ.
List<PlacedBall> legalTargetsAmong(GameType game, Iterable<PlacedBall> balls) {
  final sorted = balls.toList()..sort((a, b) => a.number.compareTo(b.number));
  switch (game) {
    case GameType.nineBall:
    case GameType.tenBall:
      return sorted.isEmpty ? const [] : [sorted.first];
    case GameType.eightBall:
      final mine = [for (final b in sorted) if (b.role == BallRole.mine) b];
      if (mine.isNotEmpty) return mine;
      return [for (final b in sorted) if (b.role == BallRole.eight) b];
  }
}

/// Bi chắn khi đánh [target]: mọi bi khác còn trên bàn.
List<Vec2> obstaclesFor(PlacedBall target, Iterable<PlacedBall> balls) =>
    [for (final b in balls) if (b.number != target.number) b.pos];

/// Tập bi còn trên bàn dưới dạng bit theo số. Trong một kế hoạch, vị trí mỗi
/// số không đổi, nên mặt nạ này đủ làm khoá cho tập bi chắn.
int ballMask(Iterable<PlacedBall> balls) =>
    balls.fold(0, (mask, b) => mask | (1 << b.number));
