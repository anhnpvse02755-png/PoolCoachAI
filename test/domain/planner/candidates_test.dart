import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

void main() {
  const a = PlacedBall(number: 3, pos: Vec2(50, 50));
  const b = PlacedBall(number: 1, pos: Vec2(80, 50));
  const opp = PlacedBall(number: 9, pos: Vec2(110, 50), role: BallRole.opponent);
  const eight = PlacedBall(number: 8, pos: Vec2(140, 50), role: BallRole.eight);

  group('bi được đánh (spec mục 4.1)', () {
    test('9 / 10 bi: chỉ bi số nhỏ nhất còn trên bàn', () {
      expect(legalTargetsAmong(GameType.nineBall, [a, b]), [b]);
      expect(legalTargetsAmong(GameType.tenBall, [a]), [a]);
      expect(legalTargetsAmong(GameType.nineBall, const []), isEmpty);
    });

    test('8 bi: mọi bi của tôi theo số, bi 8 chỉ khi hết bi của tôi', () {
      expect(legalTargetsAmong(GameType.eightBall, [eight, opp, a, b]), [b, a]);
      expect(legalTargetsAmong(GameType.eightBall, [eight, opp]), [eight]);
      expect(legalTargetsAmong(GameType.eightBall, [opp]), isEmpty);
    });

    test('bi chắn là mọi bi khác còn trên bàn', () {
      expect(obstaclesFor(b, [a, b, opp, eight]), [a.pos, opp.pos, eight.pos]);
    });
  });

  test('số bước dự kiến: 9 / 10 bi là mọi bi, 8 bi là bi của tôi cộng bi 8', () {
    expect(plannedStepCount(orderTable(GameType.nineBall)), 4);
    expect(plannedStepCount(eightWithOpponentsTable()), 4);
    expect(plannedStepCount(onlyEightTable()), 1);
  });

  test('without bỏ đúng các bi đã đánh, withCue chỉ đổi bi cái', () {
    final s = orderTable(GameType.nineBall);
    expect(s.without([1, 3]).balls.map((x) => x.number), [2, 4]);
    expect(s.withCue(const Vec2(10, 10)).cue, const Vec2(10, 10));
    expect(s.withCue(const Vec2(10, 10)).balls, s.balls);
  });

  group('CandidateFinder (spec mục 4.2)', () {
    test('9 bi: bi 1 dù bi 3 dễ hơn', () {
      final s = orderTable(GameType.nineBall);
      final c = CandidateFinder(game: s.game).easiest(s.cue, s.balls)!;
      expect(c.ball.number, 1);
      expect(c.geometry.pocket, Pocket.topRight);
    });

    test('8 bi: cặp bi–lỗ có góc cắt nhỏ nhất trong mọi bi được đánh', () {
      final s = orderTable(GameType.eightBall);
      final c = CandidateFinder(game: s.game).easiest(s.cue, s.balls)!;
      expect(c.ball.number, 3);
      expect(c.geometry.pocket, Pocket.bottomMiddle);
    });

    test('8 bi: bi 8 dễ nhất vẫn không được chọn khi còn bi của tôi', () {
      final s = eightLastTable();
      double angleOf(int n) => bestPocket(
            cue: s.cue,
            object: s.balls.firstWhere((x) => x.number == n).pos,
            others: [for (final x in s.balls) if (x.number != n) x.pos],
          )!
              .angle;
      expect(angleOf(8), lessThan(angleOf(2)));
      final finder = CandidateFinder(game: s.game);
      expect(finder.easiest(s.cue, s.balls)!.ball.number, 2);
      expect(finder.easiest(s.cue, s.without([1, 2]).balls)!.ball.number, 8);
    });

    test('bi đối thủ chắn đường vào lỗ thì lỗ đó bị loại', () {
      final s = opponentBlocksTable();
      final open = s.without([9]);
      expect(CandidateFinder(game: s.game).easiest(open.cue, open.balls)!.geometry.pocket,
          Pocket.bottomMiddle);
      expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls)!.geometry.pocket,
          Pocket.bottomRight);
    });

    test('bi bắt buộc bị chắn ở mọi lỗ thì không có ứng viên', () {
      final s = blockedEverywhereTable();
      expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls), isNull);
    });

    test('hỏi lại cùng điểm thì dùng bộ nhớ đệm, cùng kết quả', () {
      final s = orderTable(GameType.eightBall);
      final finder = CandidateFinder(game: s.game);
      final first = finder.easiest(s.cue, s.balls)!;
      final cached = finder.cached;
      final again = finder.easiest(s.cue, s.balls)!;
      expect(finder.cached, cached);
      expect(identical(again.geometry, first.geometry), isTrue);
    });
  });
}
