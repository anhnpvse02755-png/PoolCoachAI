import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import 'table_layouts.dart';

// Bàn test của Kế hoạch dọn bàn. Kết quả ghi "đo trên c43c74a" là chạy
// aimShot thật với cách chấm của kế hoạch này; chỉnh hằng số vật lý mà một
// bàn hết đúng điều kiện thì dò lại bằng fixture_probe_test.dart, đừng nới
// điều kiện của test. tool/e2e/planner.mjs dùng đúng các toạ độ này.

List<PlacedBall> _numbered(List<Vec2> at) => [
      for (var i = 0; i < at.length; i++) PlacedBall(number: i + 1, pos: at[i]),
    ];

/// Sáu điểm cách [center] đúng [distance] cm trên đường từ [center] tới
/// từng lỗ, theo thứ tự [Pocket.values]: bi đặt ở đó chắn đường vào lỗ đó.
List<Vec2> ringAround(Vec2 center, {double distance = 12}) => [
      for (final p in Pocket.values)
        center +
            (TableSpec.nineFoot.pocketPosition(p) - center).normalized *
                distance,
    ];

/// PRD §7 test 2–3. Từ bi cái: bi 3 thẳng 0° vào lỗ giữa dưới, bi 2 15.6°
/// vào góc trên trái, bi 4 18.0° vào góc dưới phải, bi 1 30.6° vào góc trên
/// phải. 8 bi thì mọi bi là bi của tôi (Trơn 1–4).
TableSetup orderTable(GameType game) => TableSetup(
      game: game,
      cue: const Vec2(127, 63.5),
      balls: _numbered(const [
        Vec2(200, 8),
        Vec2(60, 40),
        Vec2(127, 100),
        Vec2(220, 100),
      ]),
    );

/// PRD §7 test 4, 5, 7. Bi 1 vào lỗ giữa dưới (góc 6.3°). Đo trên c43c74a:
/// chọn Đánh đứng bi 45 %, bi cái chạm 1 băng, vùng điều chịu sai số
/// 21.68°, tổng 25.74; Đánh trô bi 30 % không chạm băng, 26.21°; Đánh đứng
/// bi 30 % dừng gần bi ảo hơn (10.2 so với 26.2 cm) nhưng 15 % thì không vào
/// lỗ nên chịu sai số 95°.
TableSetup railTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(190, 40),
      balls: _numbered(const [Vec2(144, 107), Vec2(146, 79)]),
    );

/// PRD §7 test 8. Bi 1 thẳng 0° vào góc dưới phải, bi cái sau 40 cm. Đo trên
/// c43c74a: Đánh cu lê mọi mức lực theo bi vào lỗ (chết cái) và từ miệng lỗ
/// bi 2 chỉ cắt 12.6°; Đánh trô bi mọi mức chết cái lỗ giữa trên; Đánh đứng
/// bi 90 % được chọn, chịu sai số 18.95°.
TableSetup cornerFollowTable() {
  const object = Vec2(224, 97);
  return TableSetup(
    game: GameType.nineBall,
    cue: cueForAngle(object, Pocket.bottomRight, 0, distance: 40),
    balls: _numbered(const [object, Vec2(200, 110)]),
  );
}

/// PRD §7 test 6: bi 1 giữa bàn, bi 2–7 chắn đúng sáu đường vào lỗ.
TableSetup blockedEverywhereTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(40, 100),
      balls: _numbered([const Vec2(127, 63.5), ...ringAround(const Vec2(127, 63.5))]),
    );

/// Tầng 3 của thứ tự dự phòng, trên vật lý thật. Bi 1 thẳng 0° vào góc dưới
/// trái từ 30 cm; bi 2 giữa bàn bị bi 3–8 chắn mọi lỗ, nên từ bất kỳ chỗ nào
/// cũng không có cú cho bi 2: mọi phương án tầng 1 và 2 bị loại, Đánh đứng
/// bi 30 % vẫn đưa bi 1 vào lỗ (đo trên c43c74a: dừng ở (33.7, 96.7)).
TableSetup fallbackTable() {
  const object = Vec2(30, 100);
  const center = Vec2(127, 63.5);
  return TableSetup(
    game: GameType.nineBall,
    cue: cueForAngle(object, Pocket.bottomLeft, 0, distance: 30),
    balls: _numbered([object, center, ...ringAround(center)]),
  );
}

/// Bàn 9 bi điển hình: đo tốc độ, chạy trên Chrome. Bi 5 chắn bi 1 vào lỗ
/// giữa dưới, nên bước 1 phải đi góc dưới phải (19.6°).
TableSetup typicalNineBallTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(64, 63.5),
      balls: _numbered(const [
        Vec2(127, 100),
        Vec2(200, 8),
        Vec2(60, 40),
        Vec2(220, 100),
        Vec2(127, 115),
        Vec2(40, 105),
        Vec2(175, 60),
        Vec2(95, 20),
        Vec2(230, 40),
      ]),
    );

/// 8 bi: bi 8 thẳng 0° từ bi cái, dễ hơn mọi bi của tôi — vẫn phải cuối.
TableSetup eightLastTable() => const TableSetup(
      game: GameType.eightBall,
      cue: Vec2(127, 63.5),
      balls: [
        PlacedBall(number: 1, pos: Vec2(200, 8)),
        PlacedBall(number: 2, pos: Vec2(60, 40)),
        PlacedBall(number: 8, pos: Vec2(127, 100), role: BallRole.eight),
      ],
    );

/// 8 bi: không có bi 9, bi 1 vào lỗ giữa dưới (29°) là dễ nhất; bi đối thủ
/// 9 nằm trên đường đó thì phải đi góc dưới phải (60°).
TableSetup opponentBlocksTable() => const TableSetup(
      game: GameType.eightBall,
      cue: Vec2(110, 63.5),
      balls: [
        PlacedBall(number: 1, pos: Vec2(127, 100)),
        PlacedBall(number: 9, pos: Vec2(127, 115), role: BallRole.opponent),
      ],
    );

/// 8 bi: còn đúng một bi của tôi, nên bi kế tiếp là bi 8.
TableSetup penultimateTable() => const TableSetup(
      game: GameType.eightBall,
      cue: Vec2(127, 63.5),
      balls: [
        PlacedBall(number: 1, pos: Vec2(60, 40)),
        PlacedBall(number: 8, pos: Vec2(220, 100), role: BallRole.eight),
      ],
    );

/// 8 bi chỉ còn bi 8, thẳng 0° vào lỗ giữa dưới.
TableSetup onlyEightTable() => const TableSetup(
      game: GameType.eightBall,
      cue: Vec2(127, 63.5),
      balls: [PlacedBall(number: 8, pos: Vec2(127, 100), role: BallRole.eight)],
    );

/// 8 bi Trơn kèm bi đối thủ (bàn thứ ba của planner.mjs): bi đối thủ 9 chắn
/// bi 1 vào lỗ giữa dưới.
TableSetup eightWithOpponentsTable() => const TableSetup(
      game: GameType.eightBall,
      cue: Vec2(64, 63.5),
      balls: [
        PlacedBall(number: 1, pos: Vec2(127, 100)),
        PlacedBall(number: 2, pos: Vec2(200, 8)),
        PlacedBall(number: 3, pos: Vec2(95, 20)),
        PlacedBall(number: 9, pos: Vec2(127, 115), role: BallRole.opponent),
        PlacedBall(number: 10, pos: Vec2(175, 60), role: BallRole.opponent),
        PlacedBall(number: 8, pos: Vec2(220, 100), role: BallRole.eight),
      ],
    );
