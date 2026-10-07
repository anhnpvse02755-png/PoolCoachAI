import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

enum GameType { nineBall, tenBall, eightBall }

/// Nhóm của người chơi khi 8 bi: Trơn 1–7, Sọc 9–15.
enum BallGroup { solids, stripes }

/// Vai trò của bi khi 8 bi. 9 / 10 bi thì mọi bi là [mine].
enum BallRole { mine, opponent, eight }

/// Một bi mục tiêu trên bàn.
class PlacedBall {
  const PlacedBall({required this.number, required this.pos, this.role = BallRole.mine});

  final int number;
  final Vec2 pos;
  final BallRole role;

  @override
  bool operator ==(Object other) =>
      other is PlacedBall && other.number == number && other.pos == pos && other.role == role;

  @override
  int get hashCode => Object.hash(number, pos, role);

  @override
  String toString() => 'PlacedBall($number, $pos, $role)';
}

/// Đầu vào của Planner (spec mục 4): loại bàn, nhóm khi 8 bi, bi cái, các bi.
class TableSetup {
  const TableSetup({
    required this.game,
    required this.cue,
    required this.balls,
    this.group = BallGroup.solids,
    this.table = TableSpec.nineFoot,
  });

  final GameType game;
  final Vec2 cue;
  final List<PlacedBall> balls;
  final BallGroup group;
  final TableSpec table;

  /// Cùng bàn, bi cái ở [cue] — đặt lại bi cái theo chỗ nó dừng thật.
  TableSetup withCue(Vec2 cue) =>
      TableSetup(game: game, cue: cue, balls: balls, group: group, table: table);

  /// Cùng bàn, bỏ các bi đã vào lỗ.
  TableSetup without(Iterable<int> numbers) {
    final gone = numbers.toSet();
    return TableSetup(
      game: game,
      cue: cue,
      balls: [for (final b in balls) if (!gone.contains(b.number)) b],
      group: group,
      table: table,
    );
  }
}

/// Số bước nếu dọn hết bàn — mẫu số của "Đang tính bước X/N".
int plannedStepCount(TableSetup setup) => switch (setup.game) {
      GameType.eightBall => setup.balls.where((b) => b.role != BallRole.opponent).length,
      GameType.nineBall || GameType.tenBall => setup.balls.length,
    };
