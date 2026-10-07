import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/separate.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một bi đã chạm lên bàn. [role] là vai trò khi 8 bi; bi đặt lúc đang ở
/// 9 / 10 bi là bi của tôi.
class DraftBall {
  const DraftBall(this.pos, this.role);
  final Vec2 pos;
  final BallRole role;
}

/// Số bi mục tiêu tối đa: 9, 10, hoặc 7 + 7 + bi 8.
int ballLimit(GameType game) => switch (game) {
      GameType.nineBall => 9,
      GameType.tenBall => 10,
      GameType.eightBall => 15,
    };

const _groupSize = 7;

/// Bàn đang bày ở màn nhập bàn (spec mục 6) — dữ liệu thuần, không Flutter.
///
/// Giữ danh sách bi theo đúng thứ tự chạm; số và vai trò suy ra theo loại
/// bàn đang chọn. Nhờ vậy đổi loại bàn không mất vị trí bi nào, và bi vượt
/// giới hạn của loại bàn này chỉ ẩn đi, đổi lại thì hiện ra.
class SetupDraft {
  const SetupDraft({
    this.game = GameType.nineBall,
    this.group = BallGroup.solids,
    this.placing = BallRole.mine,
    this.cue,
    this.placed = const [],
    this.table = TableSpec.nineFoot,
  });

  final GameType game;
  final BallGroup group;

  /// 8 bi: chạm tiếp theo đặt loại bi nào.
  final BallRole placing;
  final Vec2? cue;
  final List<DraftBall> placed;
  final TableSpec table;

  /// Bi đang hiện, theo thứ tự chạm, kèm chỉ số trong [placed].
  List<(int, PlacedBall)> get numbered {
    final out = <(int, PlacedBall)>[];
    switch (game) {
      case GameType.nineBall:
      case GameType.tenBall:
        final n = math.min(placed.length, ballLimit(game));
        for (var i = 0; i < n; i++) {
          out.add((i, PlacedBall(number: i + 1, pos: placed[i].pos)));
        }
      case GameType.eightBall:
        final mineFirst = group == BallGroup.solids ? 1 : 9;
        final theirsFirst = group == BallGroup.solids ? 9 : 1;
        var mine = 0, theirs = 0;
        var eight = false;
        for (var i = 0; i < placed.length; i++) {
          final d = placed[i];
          switch (d.role) {
            case BallRole.mine:
              if (mine < _groupSize) {
                out.add((i, PlacedBall(number: mineFirst + mine++, pos: d.pos)));
              }
            case BallRole.opponent:
              if (theirs < _groupSize) {
                out.add((
                  i,
                  PlacedBall(
                      number: theirsFirst + theirs++, pos: d.pos, role: BallRole.opponent),
                ));
              }
            case BallRole.eight:
              if (!eight) {
                eight = true;
                out.add((i, PlacedBall(number: 8, pos: d.pos, role: BallRole.eight)));
              }
          }
        }
    }
    return out;
  }

  List<PlacedBall> get balls => [for (final (_, b) in numbered) b];

  /// Có bi cái và ít nhất một bi đánh được (8 bi: bi của tôi hoặc bi 8).
  bool get canPlan => cue != null && legalTargetsAmong(game, balls).isNotEmpty;

  TableSetup toSetup() =>
      TableSetup(game: game, group: group, cue: cue!, balls: balls, table: table);

  SetupDraft _with({
    GameType? game,
    BallGroup? group,
    BallRole? placing,
    Vec2? cue,
    bool dropCue = false,
    List<DraftBall>? placed,
  }) =>
      SetupDraft(
        game: game ?? this.game,
        group: group ?? this.group,
        placing: placing ?? this.placing,
        cue: dropCue ? null : (cue ?? this.cue),
        placed: placed ?? this.placed,
        table: table,
      );

  List<Vec2> _occupied({int? except, bool withCue = true}) => [
        if (withCue && cue != null) cue!,
        for (final (i, b) in numbered)
          if (i != except) b.pos,
      ];

  /// Chạm lần đầu đặt bi cái, các lần sau đặt bi mục tiêu. Đạt giới hạn,
  /// hay chỗ chạm bị bi vây kín, thì không đặt gì.
  SetupDraft tap(Vec2 p) {
    if (cue == null) {
      final at = separateFromAll(p, _occupied(withCue: false), table: table);
      return at == null ? this : _with(cue: at);
    }
    final role = game == GameType.eightBall ? placing : BallRole.mine;
    final at = separateFromAll(p, _occupied(), table: table);
    if (at == null) return this;
    final next = _with(placed: [...placed, DraftBall(at, role)]);
    return next.numbered.length == numbered.length ? this : next;
  }

  /// Kéo bi thứ [index] trong [placed]; chồng bi khác thì tách ra.
  SetupDraft move(int index, Vec2 p) {
    final at = separateFromAll(p, _occupied(except: index), table: table);
    if (at == null) return this;
    return _with(placed: [
      for (var i = 0; i < placed.length; i++)
        i == index ? DraftBall(at, placed[i].role) : placed[i],
    ]);
  }

  SetupDraft moveCue(Vec2 p) {
    final at = separateFromAll(p, _occupied(withCue: false), table: table);
    return at == null ? this : _with(cue: at);
  }

  /// Bỏ bi đang hiện được chạm sau cùng; hết bi thì bỏ bi cái.
  SetupDraft undo() {
    final shown = numbered;
    if (shown.isNotEmpty) {
      final last = shown.last.$1;
      return _with(placed: [
        for (var i = 0; i < placed.length; i++)
          if (i != last) placed[i],
      ]);
    }
    return cue == null ? this : _with(dropCue: true);
  }

  SetupDraft clear() => _with(dropCue: true, placed: const []);
  SetupDraft withGame(GameType g) => _with(game: g);
  SetupDraft withGroup(BallGroup g) => _with(group: g);
  SetupDraft withPlacing(BallRole r) => _with(placing: r);

  /// Chỉ số trong [placed] của bi đang hiện gần [p] nhất, trong tầm [grab].
  int? ballAt(Vec2 p, double grab) {
    int? best;
    var bestDistance = grab;
    for (final (i, b) in numbered) {
      final d = b.pos.distanceTo(p);
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}
