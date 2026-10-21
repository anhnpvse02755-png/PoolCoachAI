import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một tình huống mẫu của thư viện (spec mục 9.1). Chỉ có vị trí bi, đo bằng
/// chấm như `bu_layouts.dart`. **Không có trường đáp án nào**: lỗ, kiểu đánh
/// hay lực luôn do `CoachJob` tính.
final class CoachLibraryEntry {
  const CoachLibraryEntry({
    required this.id,
    required this.topic,
    this.game = GameType.nineBall,
    required this.cue,
    required this.balls,
    required this.source,
  });

  /// Ổn định: dùng trong đường dẫn và bản ghi lần làm.
  final String id;
  final CoachTopic topic;

  /// 9 bi; 10 bi chỉ khi sơ đồ gốc cần.
  final GameType game;
  final Cham cue;
  final List<(int, Cham)> balls;

  /// Nguồn: sơ đồ BU, bàn test của Planner, hay seed của bộ sinh.
  final String source;

  /// Nguồn là sơ đồ BU (bỏ luật số liên tiếp và luật lỗ khi kiểm, spec 9.5).
  bool get fromBu => source.startsWith('BU_');

  TableSetup setup({TableSpec table = TableSpec.nineFoot}) => TableSetup(
        game: game,
        cue: chamToTable(cue, table),
        balls: [for (final (n, at) in balls) PlacedBall(number: n, pos: chamToTable(at, table))],
        table: table,
      );

  CoachSituation situation(CoachDifficulty difficulty, {TableSpec table = TableSpec.nineFoot}) =>
      CoachSituation(
        key: libraryKey(id),
        topic: topic,
        source: CoachSource.library,
        difficulty: difficulty,
        setup: setup(table: table),
        libraryId: id,
      );
}

/// Một chấm trên bàn 9 feet là 31,75 cm (254 / 8 = 127 / 4).
const _chamCm = 31.75;
Cham _cm(double x, double y) => Cham(x / _chamCm, y / _chamCm);
Cham _v(Vec2 p) => _cm(p.x, p.y);

/// Điểm trên đường bi → lỗ, cách điểm lỗ [distance] cm (như `jawBlocker`
/// của bàn test Planner).
Vec2 _jaw(Vec2 ball, Pocket pocket, {double distance = 14}) {
  final at = TableSpec.nineFoot.pocketPosition(pocket);
  return at + (ball - at).normalized * distance;
}

/// Bi cái thẳng 0° vào [pocket], cách bi ảo [distance] cm (như `cueForAngle`).
Vec2 _straightCue(Vec2 object, Pocket pocket, double distance) {
  final u = (TableSpec.nineFoot.pocketPosition(pocket) - object).normalized;
  return object - u * TableSpec.nineFoot.ballDiameter - u * distance;
}

List<(int, Cham)> _numbered(List<Vec2> at) => [for (var i = 0; i < at.length; i++) (i + 1, _v(at[i]))];

/// Dựng mục thư viện từ đúng sơ đồ BU (bi cái cố định và các bi mục tiêu),
/// không chép lại toạ độ: một nguồn sự thật với màn xem sơ đồ.
CoachLibraryEntry _fromBu(String id, CoachTopic topic, String drillId, int variant,
    {GameType game = GameType.nineBall}) {
  final layout = layoutsFor(drillId, null).firstWhere((l) => l.variant == variant);
  final cue = layout.marks.whereType<CueBall>().single.at;
  return CoachLibraryEntry(
    id: id,
    topic: topic,
    game: game,
    cue: cue,
    balls: [for (final b in layout.marks.whereType<ObjectBall>()) (b.number, b.at)],
    source: '${layout.source}, $drillId thế $variant',
  );
}

/// Thư viện tình huống mẫu (spec mục 9.2). Mục nào không khớp nhóm theo điều
/// kiện mục 8.5 thì bị bỏ khỏi đây (test thư viện), không sửa vị trí bi cho
/// vừa. Đã bỏ lúc làm T5 (21/10/2026): `blockedEverywhereTable` (bi cái bị
/// đui, nên là thế A băng chứ không phải Phòng thủ) và S5 Bachelors thế 1
/// (bi 1 nhìn thấy và có lỗ đánh được theo hình học, Planner ra phòng thủ
/// vì mọi cú hỏng — không phải thế đui).
final List<CoachLibraryEntry> coachLibrary = List.unmodifiable(<CoachLibraryEntry>[
  // ── Điều bi / Vị trí
  CoachLibraryEntry(
    id: 'pos-rail-1',
    topic: CoachTopic.position,
    cue: _cm(190, 40),
    balls: _numbered(const [Vec2(144, 107), Vec2(146, 79)]),
    source: 'planner_tables.dart railTable (c43c74a)',
  ),
  CoachLibraryEntry(
    id: 'pos-corner-1',
    topic: CoachTopic.position,
    cue: _v(_straightCue(const Vec2(224, 97), Pocket.bottomRight, 40)),
    balls: _numbered(const [Vec2(224, 97), Vec2(200, 110)]),
    source: 'planner_tables.dart cornerFollowTable (c43c74a)',
  ),
  _fromBu('pos-f6-1', CoachTopic.position, 'F6', 1),
  // ── Ngắm bi
  CoachLibraryEntry(
    id: 'aim-typical-1',
    topic: CoachTopic.aiming,
    cue: _cm(64, 63.5),
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
    source: 'planner_tables.dart typicalNineBallTable (c43c74a)',
  ),
  _fromBu('aim-f1-1', CoachTopic.aiming, 'F1', 1),
  CoachLibraryEntry(
    id: 'aim-gen-6054',
    topic: CoachTopic.aiming,
    cue: _cm(167.5, 124),
    balls: [
      (6, _cm(149, 101.5)),
      (7, _cm(30, 122)),
      (8, _cm(33, 75.5)),
      (9, _cm(32, 60.5)),
    ],
    source: 'seed gen-v1-aiming-medium-6054',
  ),
  // ── Phòng thủ
  CoachLibraryEntry(
    id: 'safe-nopot-1',
    topic: CoachTopic.safety,
    cue: _cm(60, 100),
    balls: _numbered([
      const Vec2(150, 40),
      _jaw(const Vec2(150, 40), Pocket.topRight),
      _jaw(const Vec2(150, 40), Pocket.bottomRight),
    ]),
    source: 'planner_tables.dart noPotTable (a35667b)',
  ),
  CoachLibraryEntry(
    id: 'safe-gen-1009',
    topic: CoachTopic.safety,
    cue: _cm(101.5, 77),
    balls: [
      (6, _cm(192.5, 80)),
      (7, _cm(240, 18.5)),
      (8, _cm(240, 116.5)),
      (9, _cm(169, 68.5)),
    ],
    source: 'seed gen-v1-safety-medium-1009',
  ),
  // ── A băng
  CoachLibraryEntry(
    id: 'kick-one-1',
    topic: CoachTopic.kick,
    cue: _cm(30, 80),
    balls: _numbered(const [Vec2(180, 80), Vec2(105, 80)]),
    source: 'planner_tables.dart snookerOneRailTable (a35667b)',
  ),
  CoachLibraryEntry(
    id: 'kick-two-1',
    topic: CoachTopic.kick,
    cue: _cm(30, 80),
    balls: _numbered(const [Vec2(180, 80), Vec2(105, 80), Vec2(105, 9), Vec2(105, 118)]),
    source: 'planner_tables.dart snookerTwoRailTable (a35667b)',
  ),
]);

CoachLibraryEntry? coachLibraryEntry(String id) =>
    coachLibrary.where((e) => e.id == id).firstOrNull;

/// Tình huống thư viện cùng nhóm khi bộ sinh hết số lần thử (spec mục 8.6):
/// ưu tiên mục người chơi chưa làm ([doneKeys] là khoá các lần đã làm).
/// null khi nhóm này không có mục nào.
CoachLibraryEntry? fallbackEntry(CoachTopic topic, Set<String> doneKeys) {
  final ofTopic = [for (final e in coachLibrary) if (e.topic == topic) e];
  return ofTopic.where((e) => !doneKeys.contains(libraryKey(e.id))).firstOrNull ??
      ofTopic.firstOrNull;
}
