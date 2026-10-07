import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';

void main() {
  const table = TableSpec.nineFoot;
  const cue = Vec2(40, 100);
  final spots = [for (var i = 0; i < 16; i++) Vec2(20.0 + (i % 8) * 28, 30.0 + (i ~/ 8) * 40)];
  SetupDraft tapAll(SetupDraft d, Iterable<Vec2> points) =>
      points.fold(d, (acc, p) => acc.tap(p));

  test('chạm đầu đặt bi cái, các lần sau đặt bi theo thứ tự chạm', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[1], spots[2]]);
    expect(d.cue, cue);
    expect(d.balls.map((b) => b.number), [1, 2, 3]);
    expect(d.balls[1].pos, spots[1]);
    expect(d.balls.every((b) => b.role == BallRole.mine), isTrue);
  });

  test('giới hạn: 9 bi tối đa 9, 10 bi tối đa 10; chạm thêm không đặt', () {
    final ten = tapAll(const SetupDraft(game: GameType.tenBall), [cue, ...spots]);
    expect(ten.balls, hasLength(ballLimit(GameType.tenBall)));
    final nine = tapAll(const SetupDraft(), [cue, ...spots]);
    expect(nine.balls, hasLength(ballLimit(GameType.nineBall)));
  });

  test('đổi loại bàn giữ vị trí bi; bi vượt giới hạn ẩn đi rồi hiện lại', () {
    final ten = tapAll(const SetupDraft(game: GameType.tenBall), [cue, ...spots]);
    final nine = ten.withGame(GameType.nineBall);
    expect(nine.balls, hasLength(9));
    expect(nine.balls.map((b) => b.pos), ten.balls.take(9).map((b) => b.pos));
    expect(nine.withGame(GameType.tenBall).balls, hasLength(10));
    expect(nine.cue, cue);
  });

  test('8 bi: bi của tôi và đối thủ lấy số nhỏ nhất còn trống trong nhóm, một bi 8', () {
    var d = const SetupDraft(game: GameType.eightBall).tap(cue);
    d = d.tap(spots[0]).tap(spots[1]);
    d = d.withPlacing(BallRole.opponent).tap(spots[2]);
    d = d.withPlacing(BallRole.eight).tap(spots[3]).tap(spots[4]);
    expect(d.balls.map((b) => (b.number, b.role)), [
      (1, BallRole.mine),
      (2, BallRole.mine),
      (9, BallRole.opponent),
      (8, BallRole.eight),
    ]);
    expect(d.withGroup(BallGroup.stripes).balls.map((b) => b.number), [9, 10, 1, 8]);
  });

  test('8 bi: tối đa 7 bi mỗi bên', () {
    final d = tapAll(const SetupDraft(game: GameType.eightBall), [cue, ...spots.take(9)]);
    expect(d.balls, hasLength(7));
  });

  test('bi đặt lúc 9 bi là bi của tôi khi sang 8 bi', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[1]]).withGame(GameType.eightBall);
    expect(d.balls.map((b) => (b.number, b.role)), [(1, BallRole.mine), (2, BallRole.mine)]);
  });

  test('Lập kế hoạch chỉ bật khi có bi cái và ít nhất một bi đánh được', () {
    expect(const SetupDraft().canPlan, isFalse);
    expect(const SetupDraft().tap(cue).canPlan, isFalse);
    expect(const SetupDraft().tap(cue).tap(spots[0]).canPlan, isTrue);
    final eight = const SetupDraft(game: GameType.eightBall).tap(cue);
    expect(eight.withPlacing(BallRole.eight).tap(spots[0]).canPlan, isTrue);
  });

  test('chỉ có bi đối thủ thì không lập kế hoạch được', () {
    final d = const SetupDraft(game: GameType.eightBall, placing: BallRole.opponent)
        .tap(cue)
        .tap(spots[0])
        .tap(spots[1]);
    expect(d.balls, hasLength(2));
    expect(d.canPlan, isFalse);
  });

  test('xoá bi cuối bỏ bi chạm sau cùng, hết bi thì bỏ bi cái; xoá hết bỏ tất cả', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[1]]);
    expect(d.undo().balls.map((b) => b.pos), [spots[0]]);
    expect(d.undo().undo().undo().cue, isNull);
    final cleared = d.clear();
    expect(cleared.cue, isNull);
    expect(cleared.balls, isEmpty);
    expect(cleared.game, d.game);
  });

  test('chạm đè lên bi có sẵn thì bi mới nằm sát bên', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[0] + const Vec2(1, 0)]);
    expect(d.balls, hasLength(2));
    expect(d.balls[1].pos.distanceTo(spots[0]), greaterThanOrEqualTo(table.ballDiameter));
  });

  test('chạm vào lỗ thì bi nằm trong biên', () {
    final d = tapAll(const SetupDraft(), [cue, Vec2.zero]);
    expect(d.balls.single.pos, table.clamp(Vec2.zero));
  });

  test('kéo bi hay bi cái lên bi khác thì bị tách ra', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[1]]);
    final moved = d.move(1, spots[0]);
    expect(moved.balls[1].pos.distanceTo(spots[0]), greaterThanOrEqualTo(table.ballDiameter));
    final cueMoved = d.moveCue(spots[1]);
    expect(cueMoved.cue!.distanceTo(spots[1]), greaterThanOrEqualTo(table.ballDiameter));
  });

  test('ballAt tìm bi hiện gần nhất trong tầm chạm', () {
    final d = tapAll(const SetupDraft(), [cue, spots[0], spots[1]]);
    expect(d.ballAt(spots[1] + const Vec2(2, 0), 4), 1);
    expect(d.ballAt(const Vec2(200, 120), 4), isNull);
  });

  test('toSetup mang đúng loại bàn, nhóm, bi cái và bi', () {
    final d = tapAll(const SetupDraft(game: GameType.eightBall, group: BallGroup.stripes),
        [cue, spots[0]]);
    final s = d.toSetup();
    expect(s.game, GameType.eightBall);
    expect(s.group, BallGroup.stripes);
    expect(s.cue, cue);
    expect(s.balls.single.number, 9);
  });
}
