import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
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

/// Ngữ cảnh chấm điểm cho bước đầu của [s], mô phỏng thật (không chia lát).
ScoringContext contextFor(TableSetup s, {ShotLookup? lookup}) {
  final finder = CandidateFinder(game: s.game, table: s.table);
  final c = finder.easiest(s.cue, s.balls)!;
  return ScoringContext(
    geometry: c.geometry,
    after: [for (final b in s.balls) if (b.number != c.ball.number) b],
    lookup: lookup ?? directLookup(table: s.table),
    next: finder,
  );
}

/// aimShot thật, nhưng cú nào khớp [when] thì bi cái rơi vào đúng lỗ của
/// cú đó — để ép Planner xuống từng tầng dự phòng mà vẫn chạy trên lõi thật.
AimShotFn scratchingAim(
        bool Function(Vec2 object, Stroke stroke, SideSpin spin, double power) when) =>
    ({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
      double maxTime = maxSimTime,
    }) {
      final real = aimShot(
          cue: cue,
          object: object,
          pocket: pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          table: table,
          compensate: compensate,
          withUncompensated: withUncompensated,
          maxTime: maxTime);
      if (!when(object, stroke, spin, power)) return real;
      final t = real.trace;
      return AimedShot(
        trace: ShotTrace(
          cueBefore: t.cueBefore,
          cueAfter: t.cueAfter,
          objectPath: t.objectPath,
          contactCue: t.contactCue,
          rails: t.rails,
          cuePocket: pocket,
          objectPocket: t.objectPocket,
          cueEnd: t.cueEnd,
        ),
        uncompensated: real.uncompensated,
        aimOffsetDeg: real.aimOffsetDeg,
        verticalOffset: real.verticalOffset,
        stunReached: real.stunReached,
        converged: real.converged,
      );
    };

/// aimShot thật, nhưng cú nào khớp [when] thì lõi "quá giờ".
AimShotFn timeoutAim(
        bool Function(Vec2 object, Stroke stroke, SideSpin spin, double power) when) =>
    ({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
      double maxTime = maxSimTime,
    }) {
      if (when(object, stroke, spin, power)) {
        throw SimulationTimeout(
            ShotInput(cue: cue, object: object, aimAngle: 0, power: power));
      }
      return aimShot(
          cue: cue,
          object: object,
          pocket: pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          table: table,
          compensate: compensate,
          withUncompensated: withUncompensated,
          maxTime: maxTime);
    };

/// aimShot thật, ghi lại kiểu đánh, áp phê và lực của mọi lần gọi.
AimShotFn recordingAim(void Function(Stroke stroke, SideSpin spin, double power) record) =>
    ({
      required Vec2 cue,
      required Vec2 object,
      required Pocket pocket,
      required Stroke stroke,
      SideSpin spin = const SideSpin.none(),
      required double power,
      CueElevation elevation = CueElevation.normal,
      TableSpec table = TableSpec.nineFoot,
      bool compensate = true,
      bool withUncompensated = true,
      double maxTime = maxSimTime,
    }) {
      record(stroke, spin, power);
      return aimShot(
          cue: cue,
          object: object,
          pocket: pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          table: table,
          compensate: compensate,
          withUncompensated: withUncompensated,
          maxTime: maxTime);
    };

/// Mọi thứ của một kế hoạch mà người chơi thấy hoặc bước sau dựa vào, đủ
/// chính xác để hai lần chạy chỉ trùng khi trùng thật.
String fingerprint(List<PlanStep> steps) => [
      for (final s in steps)
        [
          s.kind,
          s.ballNum,
          s.pocket,
          s.stroke,
          s.power,
          s.spin,
          s.cbFrom,
          s.trace?.cueEnd,
          s.trace?.cueRailCount,
          s.score?.total,
          s.jitterEnds,
          s.tolerance,
          s.missAdvice?.safer,
          s.sawsBhePercent,
          s.nextBallNum,
        ].join('|'),
    ].join('\n');

/// Bi chắn đặt trên đường bi → lỗ, cách điểm lỗ [distance] cm: chắn lỗ đó
/// mà không chắn chỗ bi hợp lệ lăn đi.
Vec2 jawBlocker(Vec2 ball, Pocket pocket, {double distance = 14}) {
  final at = TableSpec.nineFoot.pocketPosition(pocket);
  return at + (ball - at).normalized * distance;
}

/// Thế đui cần A băng 1 băng (spec cú phòng thủ 9.1.3). Bi 2 nằm giữa đường
/// bi cái → bi 1 nên cả trọn bi lẫn hai đường mỏng đều bị chắn, không lỗ
/// nào đánh được. Kiểm bằng nguyên mẫu trên a35667b: đường mở 6 / 15 / 23
/// cho 1 / 2 / 3 băng; đường 1 băng (băng dài trên, dưới) dò hội tụ ở 6–8
/// trên 10 phương án. Đo trên a35667b với mã của kế hoạch: chọn A băng 1
/// băng (băng dài dưới, chấm 3,5), cu lê 90 %.
TableSetup snookerOneRailTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(30, 80),
      balls: _numbered(const [Vec2(180, 80), Vec2(105, 80)]),
    );

/// Như [snookerOneRailTable], thêm bi 3, 4 chắn hai đường 1 băng. Nguyên
/// mẫu: đường mở 0 / 13 / 8. Đo trên a35667b: chọn A băng 2 băng (băng ngắn
/// trái, chấm 2), cu lê 45 %.
TableSetup snookerTwoRailTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(30, 80),
      balls: _numbered(const [Vec2(180, 80), Vec2(105, 80), Vec2(105, 9), Vec2(105, 118)]),
    );

/// Như [snookerTwoRailTable], thêm bi 5–7 chắn mọi đường 2 băng (tìm bằng
/// lưới tham lam, safety_probe_test.dart làm lại được). Nguyên mẫu: đường mở
/// 0 / 0 / 8. Đo trên a35667b: chọn A băng 3 băng (băng ngắn phải, chấm 0,5),
/// đối thủ bị đui.
TableSetup snookerThreeRailTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(30, 80),
      balls: _numbered(const [
        Vec2(180, 80),
        Vec2(105, 80),
        Vec2(105, 9),
        Vec2(105, 118),
        Vec2(42, 68),
        Vec2(120, 104),
        Vec2(12, 50),
      ]),
    );

/// Bi 2 lệch 4 cm khỏi đường bi cái → bi 1: chắn trọn bi và mép phải, hở mép
/// trái — chỉ ¼ và ⅛ bên trái nhìn thấy được (tính tay từ hình học).
TableSetup partlyVisibleTable() => TableSetup(
      game: GameType.nineBall,
      cue: const Vec2(30, 80),
      balls: _numbered(const [Vec2(180, 80), Vec2(105, 84)]),
    );

/// Không đui nhưng hết đường ăn (spec cú phòng thủ 9.3). Từ bi cái chỉ góc
/// trên phải và góc dưới phải đánh được; hai bi chắn ngay miệng hai lỗ đó,
/// nên bi 1 vẫn lăn tự do trên bàn. Nguyên mẫu trên a35667b: 233–277 cú thủ
/// trực tiếp hợp lệ. Đo với mã của kế hoạch: chọn ¼ bi lệch phải, đứng bi
/// 45 %, đối thủ không còn đường ăn.
TableSetup noPotTable() {
  const ball = Vec2(150, 40);
  return TableSetup(
    game: GameType.nineBall,
    cue: const Vec2(60, 100),
    balls: _numbered([
      ball,
      jawBlocker(ball, Pocket.topRight),
      jawBlocker(ball, Pocket.bottomRight),
    ]),
  );
}

/// 8 bi Trơn, cùng thế với [noPotTable]: hai bi chắn miệng lỗ là bi đối thủ 9,
/// 10; bi 8 ở xa. Sau cú thủ đối thủ phải đánh bi 9 hoặc 10, không phải bi 1.
/// Đo trên a35667b: chọn ¾ bi lệch phải, đứng bi 45 %; đối thủ đánh bi 10.
TableSetup eightSafetyTable() {
  const ball = Vec2(150, 40);
  return TableSetup(
    game: GameType.eightBall,
    cue: const Vec2(60, 100),
    balls: [
      const PlacedBall(number: 1, pos: ball),
      PlacedBall(number: 9, pos: jawBlocker(ball, Pocket.topRight), role: BallRole.opponent),
      PlacedBall(number: 10, pos: jawBlocker(ball, Pocket.bottomRight), role: BallRole.opponent),
      const PlacedBall(number: 8, pos: Vec2(40, 20), role: BallRole.eight),
    ],
  );
}

/// Lõi thủ không bao giờ chạm bi và mô phỏng nào cũng quá giờ: mọi phương án
/// thủ bị bỏ nhanh, bước phòng thủ ra với safety = null. Cho test chỉ cần biết
/// kế hoạch dừng (spec cú phòng thủ 9.1.10).
final noSafetyPhysics = SafetyPhysics(
  probe: (input, {required maxRails}) =>
      const KickProbe(cueAtContact: null, railsBefore: [], cuePocket: null),
  simulate: (input) => throw SimulationTimeout(input),
);
