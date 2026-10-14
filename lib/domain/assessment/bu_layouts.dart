import 'dart:math' as math;

import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart'
    show longRailDiamonds, shortRailDiamonds;
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một điểm trên mặt bàn đo bằng chấm (spec mục 5.5): x 0–8 dọc băng dài
/// từ góc trái, y 0–4 từ băng trên xuống. Đo theo chấm thì cùng một sơ đồ vẽ
/// đúng trên bàn 7, 8 hay 9 feet.
final class Cham {
  const Cham(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is Cham && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Cham($x, $y)';
}

Vec2 chamToTable(Cham c, TableSpec table) => Vec2(
    table.length * c.x / longRailDiamonds, table.width * c.y / shortRailDiamonds);

Cham pocketCham(Pocket p) => switch (p) {
      Pocket.topLeft => const Cham(0, 0),
      Pocket.topMiddle => const Cham(4, 0),
      Pocket.topRight => const Cham(8, 0),
      Pocket.bottomLeft => const Cham(0, 4),
      Pocket.bottomMiddle => const Cham(4, 4),
      Pocket.bottomRight => const Cham(8, 4),
    };

/// Điểm ở [t] phần đường từ [a] tới [b] — "bi mục tiêu nằm giữa bi cái và
/// lỗ" là `lerpCham(cue, pocketCham(pocket), 0.5)`.
Cham lerpCham(Cham a, Cham b, double t) =>
    Cham(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

/// [count] điểm cách đều từ [from] tới [to], gồm cả hai đầu.
List<Cham> evenlySpaced(Cham from, Cham to, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count');
  if (count == 1) return [from];
  return [for (var i = 0; i < count; i++) lerpCham(from, to, i / (count - 1))];
}

/// Một thứ vẽ trên sơ đồ.
sealed class LayoutMark {
  const LayoutMark();
}

final class ObjectBall extends LayoutMark {
  const ObjectBall(this.number, this.at);
  final int number;
  final Cham at;

  @override
  bool operator ==(Object other) => other is ObjectBall && other.number == number && other.at == at;
  @override
  int get hashCode => Object.hash(number, at);
}

final class CueBall extends LayoutMark {
  const CueBall(this.at);
  final Cham at;

  @override
  bool operator ==(Object other) => other is CueBall && other.at == at;
  @override
  int get hashCode => at.hashCode;
}

/// Bi cái đặt tự do (ball in hand): không vẽ bi cái.
final class CueBallInHand extends LayoutMark {
  const CueBallInHand();

  @override
  bool operator ==(Object other) => other is CueBallInHand;
  @override
  int get hashCode => 0;
}

/// Vòng giấy dán / chấm đặt bi.
final class SpotRing extends LayoutMark {
  const SpotRing(this.at);
  final Cham at;

  @override
  bool operator ==(Object other) => other is SpotRing && other.at == at;
  @override
  int get hashCode => at.hashCode;
}

/// Vùng đích hình chữ nhật (khung giấy đích, ô 2 × 1 chấm …).
final class TargetZone extends LayoutMark {
  const TargetZone(this.from, this.to);
  final Cham from;
  final Cham to;

  @override
  bool operator ==(Object other) => other is TargetZone && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

/// Vị trí 1–7 của thang vị trí F1–F5.
final class LadderPosition extends LayoutMark {
  const LadderPosition(this.position, this.at);
  final int position;
  final Cham at;

  @override
  bool operator ==(Object other) =>
      other is LadderPosition && other.position == position && other.at == at;
  @override
  int get hashCode => Object.hash(position, at);
}

/// Đường đi PDF vẽ (đường bi cái, đường bi mục tiêu).
final class AimPath extends LayoutMark {
  const AimPath(this.points, {this.dashed = false});
  final List<Cham> points;
  final bool dashed;

  @override
  bool operator ==(Object other) {
    if (other is! AimPath || other.dashed != dashed || other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (points[i] != other.points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(points), dashed);
}

/// Lỗ đích của bài.
final class TargetPocket extends LayoutMark {
  const TargetPocket(this.pocket);
  final Pocket pocket;

  @override
  bool operator ==(Object other) => other is TargetPocket && other.pocket == pocket;
  @override
  int get hashCode => pocket.hashCode;
}

/// Một sơ đồ xếp bi của đề BU. [source] là file PDF và trang đã đo, dạng
/// `'BU_Exam-II_Skills-Bachelors.pdf, trang 3'`.
final class BuLayout {
  const BuLayout({
    required this.drillId,
    required this.marks,
    required this.source,
    this.version,
    this.variant = 1,
  });

  final String drillId;
  final ExamIIVersion? version;

  /// Thế / hình số mấy của bài (S3, S4: 1–3).
  final int variant;
  final List<LayoutMark> marks;
  final String source;
}

// ─── Kích thước đo bằng chấm trên bàn 9 feet chuẩn thi đấu ─────────────────
//
// Bàn mặc định của bài kiểm tra là bàn 9 feet (D5, chủ sản phẩm chốt
// 14/10/2026): một chấm = 254 cm / 8 = 31,75 cm. PDF đo nhiều chỗ bằng bi
// ("one ball gap", "half ball gap", "frozen") và bằng tờ giấy 8.5" × 11";
// đổi các số đó sang chấm ở đây, một lần.

/// Đường kính bi (5,715 cm) tính bằng chấm.
const _d = 5.715 / 31.75;

/// Bi áp sát băng ("frozen to the cushion"): tâm cách mép băng nửa bi.
const _frozen = _d / 2;

/// "half ball gap": khe nửa bi giữa bi và băng → tâm cách băng một bi.
const _halfGap = _d;

/// "one ball gap" / "one-ball gap": khe một bi → tâm cách băng 1,5 bi.
const _oneGap = 1.5 * _d;

/// Khoảng giữa hai cột của cụm bi xếp khít (tam giác đều cạnh một bi).
const _rackStep = 0.8660254037844386 * _d;

/// Tờ giấy đích "8.5”x11” sheet of paper" tính bằng chấm.
const _paperShort = 21.59 / 31.75;
const _paperLong = 27.94 / 31.75;

/// Chấm đặt bi (foot spot) — PDF vẽ nó trên mọi sơ đồ Đề II.
const _foot = Cham(6, 2);

String _e1(int page) => 'BU_Exam-I_Fundamentals.pdf, trang $page';

String _e2(ExamIIVersion v, int page) => 'BU_Exam-II_Skills-${switch (v) {
      ExamIIVersion.bachelors => 'Bachelors',
      ExamIIVersion.masters => 'Masters',
      ExamIIVersion.doctorate => 'Doctorate',
    }}.pdf, trang $page';

/// Ước lượng chung cho mọi bản: giá trị theo bản.
T _by<T>(ExamIIVersion v, T bachelors, T masters, T doctorate) => switch (v) {
      ExamIIVersion.bachelors => bachelors,
      ExamIIVersion.masters => masters,
      ExamIIVersion.doctorate => doctorate,
    };

// ─── Sơ đồ chép từ PDF (S2, S3, S4, S6, S7 Bachelors) ──────────────────────
//
// Đọc trên hình: bi nằm trên đường chấm thì lấy đúng chấm; bi PDF ghi khe
// ("half ball gap", "frozen") thì dùng hằng số ở trên. Vài bi không nằm trên
// đường nào và PDF không ghi số đo: lấy số đo trên hình, làm tròn 0,05 chấm,
// ghi chú "đo trên hình" — chủ sản phẩm duyệt khi xem trên Chrome (Task 17).

const _transcribed = <BuLayout>[
  // ── S2 — "pocket the balls in any order starting with ball in hand" ──
  BuLayout(drillId: 'S2', version: ExamIIVersion.bachelors, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 2', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(2, _frozen)),
    ObjectBall(2, Cham(6, _frozen)),
    ObjectBall(3, Cham(8 - _frozen, 2)),
    ObjectBall(4, Cham(6, 4 - _frozen)),
    ObjectBall(5, Cham(2, 4 - _frozen)),
    ObjectBall(6, Cham(_frozen, 2)),
    ObjectBall(7, Cham(4, 2)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S2', version: ExamIIVersion.masters, source: 'BU_Exam-II_Skills-Masters.pdf, trang 2', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(2, _frozen)),
    ObjectBall(2, Cham(6, _frozen)),
    ObjectBall(3, Cham(8 - _frozen, 1)),
    ObjectBall(4, Cham(8 - _frozen, 2)),
    ObjectBall(5, Cham(8 - _frozen, 3)),
    ObjectBall(6, Cham(6, 4 - _frozen)),
    ObjectBall(7, Cham(2, 4 - _frozen)),
    ObjectBall(8, Cham(_frozen, 3)),
    ObjectBall(9, Cham(_frozen, 2)),
    ObjectBall(10, Cham(_frozen, 1)),
    ObjectBall(11, Cham(4, 2)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S2', version: ExamIIVersion.doctorate, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 2', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(1, _frozen)),
    ObjectBall(2, Cham(2, _frozen)),
    ObjectBall(3, Cham(6, _frozen)),
    ObjectBall(4, Cham(7, _frozen)),
    ObjectBall(5, Cham(8 - _frozen, 1)),
    ObjectBall(6, Cham(8 - _frozen, 2)),
    ObjectBall(7, Cham(8 - _frozen, 3)),
    ObjectBall(8, Cham(7, 4 - _frozen)),
    ObjectBall(9, Cham(6, 4 - _frozen)),
    ObjectBall(10, Cham(2, 4 - _frozen)),
    ObjectBall(11, Cham(1, 4 - _frozen)),
    ObjectBall(12, Cham(_frozen, 3)),
    ObjectBall(13, Cham(_frozen, 2)),
    ObjectBall(14, Cham(_frozen, 1)),
    ObjectBall(15, Cham(4, 2)),
    SpotRing(_foot),
  ]),

  // ── S3 — 9-Ball Pattern Drills, "pocket the balls in rotation starting
  // with ball in hand" ──
  // Ví dụ đã đo trong spec mục 5.5.
  BuLayout(
    drillId: 'S3',
    version: ExamIIVersion.bachelors,
    variant: 1,
    source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 3',
    marks: [
      CueBallInHand(),
      ObjectBall(5, Cham(1, 1)),
      ObjectBall(8, Cham(3, 1)),
      ObjectBall(9, Cham(5, 1)),
      ObjectBall(7, Cham(1, 3)),
      ObjectBall(6, Cham(3, 3)),
      SpotRing(Cham(6, 2)),
    ],
  ),
  BuLayout(drillId: 'S3', version: ExamIIVersion.bachelors, variant: 2, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 4', marks: [
    CueBallInHand(),
    ObjectBall(5, Cham(_halfGap, 1)), // "half ball gap"
    ObjectBall(6, Cham(_halfGap, 3)),
    ObjectBall(7, Cham(8 - _halfGap, 3)),
    ObjectBall(8, Cham(3, 4 - _halfGap)),
    ObjectBall(9, Cham(8 - _halfGap, 1)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S3', version: ExamIIVersion.bachelors, variant: 3, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 5', marks: [
    CueBallInHand(),
    ObjectBall(5, Cham(5.9, 2.5)), // đo trên hình: dưới bi 8, lệch trái
    ObjectBall(6, Cham(7.5, 0.5)),
    ObjectBall(7, Cham(6 + _d, 2)), // áp sát bên phải bi 8
    ObjectBall(8, _foot),
    ObjectBall(9, Cham(1, _halfGap)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S3', version: ExamIIVersion.masters, variant: 1, source: 'BU_Exam-II_Skills-Masters.pdf, trang 3', marks: [
    CueBallInHand(),
    ObjectBall(4, Cham(7, 3)),
    ObjectBall(5, _foot),
    ObjectBall(6, Cham(3, 1)),
    ObjectBall(7, Cham(2, 2)),
    ObjectBall(8, Cham(1, 1)),
    ObjectBall(9, Cham(5, _halfGap)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S3', version: ExamIIVersion.masters, variant: 2, source: 'BU_Exam-II_Skills-Masters.pdf, trang 4', marks: [
    CueBallInHand(),
    ObjectBall(4, Cham(7, 2)),
    ObjectBall(5, Cham(7, 4 - _halfGap)),
    ObjectBall(6, Cham(7, _halfGap)),
    ObjectBall(7, Cham(5, 4 - _halfGap)),
    ObjectBall(8, Cham(5, _halfGap)), // "half ball gap"
    ObjectBall(9, Cham(_halfGap, 2)),
    SpotRing(_foot),
  ]),
  // "the 7 and 8 are frozen to each other and the cushion, with the edge of
  // the 8 aligned with the pocket point": miệng lỗ giữa ≈ 14 cm (WPA 5"–
  // 5 5/8"), mũi lỗ cách tâm lỗ 7 cm = 7 / 31,75 chấm.
  BuLayout(drillId: 'S3', version: ExamIIVersion.masters, variant: 3, source: 'BU_Exam-II_Skills-Masters.pdf, trang 5', marks: [
    CueBallInHand(),
    ObjectBall(4, Cham(5, 1)),
    ObjectBall(5, Cham(4, 3)),
    ObjectBall(6, Cham(1, 1)),
    ObjectBall(7, Cham(4 - 7 / 31.75 - _frozen - _d, 4 - _frozen)),
    ObjectBall(8, Cham(4 - 7 / 31.75 - _frozen, 4 - _frozen)),
    ObjectBall(9, Cham(8 - _halfGap, 1)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S3', version: ExamIIVersion.doctorate, variant: 1, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 3', marks: [
    CueBallInHand(),
    ObjectBall(3, Cham(1, 3)),
    ObjectBall(4, Cham(1, 1)),
    ObjectBall(5, Cham(4, 2)),
    ObjectBall(6, Cham(2, 4 - _halfGap)),
    ObjectBall(7, Cham(3, 2)),
    ObjectBall(8, Cham(5, _halfGap)),
    ObjectBall(9, Cham(8 - _halfGap, 2)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S3', version: ExamIIVersion.doctorate, variant: 2, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 4', marks: [
    CueBallInHand(),
    ObjectBall(3, Cham(4, 1)),
    ObjectBall(4, Cham(4, 3)),
    ObjectBall(5, Cham(_frozen, 3)),
    ObjectBall(6, Cham(1, 4 - _frozen)),
    ObjectBall(7, Cham(6, 4 - _frozen)),
    ObjectBall(8, Cham(3, _frozen)),
    ObjectBall(9, Cham(_frozen, 2)),
    SpotRing(_foot),
  ]),
  // "You must get shape on the 7 and 9 by going off three or four rails from
  // the 6 and 8." Đường đi 3–4 băng trong hình chỉ minh hoạ, không vẽ lại.
  BuLayout(drillId: 'S3', version: ExamIIVersion.doctorate, variant: 3, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 5', marks: [
    CueBallInHand(),
    ObjectBall(3, Cham(5, 1)),
    ObjectBall(4, Cham(5, 3)),
    ObjectBall(5, Cham(4, 1)),
    ObjectBall(6, Cham(7, 1)),
    ObjectBall(7, Cham(_frozen, 3)),
    ObjectBall(8, Cham(7, 3)),
    ObjectBall(9, Cham(_frozen, 1)),
    SpotRing(_foot),
  ]),

  // ── S4 — 8-Ball Pattern Drills, "pocket the stripes in any order, and then
  // the 8, starting with ball in hand" ──
  // PDF không đánh số bi sọc và bi chướng ngại: bi sọc mang số 9–14, bi
  // chướng ngại ("obstacle solids") số 1–5, theo thứ tự đọc hình.
  BuLayout(drillId: 'S4', version: ExamIIVersion.bachelors, variant: 1, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 6', marks: [
    CueBallInHand(),
    ObjectBall(8, Cham(7, 1)),
    ObjectBall(9, Cham(1, 1)),
    ObjectBall(10, Cham(1, 3)),
    ObjectBall(11, Cham(4, 3)),
    ObjectBall(12, Cham(7, 3)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.bachelors, variant: 2, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 7', marks: [
    CueBallInHand(),
    ObjectBall(1, _foot),
    ObjectBall(2, Cham(5, 3)),
    ObjectBall(8, Cham(8 - _frozen, 3)),
    ObjectBall(9, Cham(7, 2)),
    ObjectBall(10, Cham(4, 3)),
    ObjectBall(11, Cham(7, 3)),
    ObjectBall(12, Cham(6, 4 - _halfGap)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.bachelors, variant: 3, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 8', marks: [
    CueBallInHand(),
    // Cụm trái: ba bi khít quanh (2, 2); cụm phải: hai bi khít tại (6, 2).
    ObjectBall(1, Cham(2 - _rackStep, 2 - _d / 2)),
    ObjectBall(2, Cham(2, 2)),
    ObjectBall(3, Cham(2 + _d, 2)),
    ObjectBall(4, _foot),
    ObjectBall(5, Cham(6 + _d, 2)),
    ObjectBall(8, Cham(1, 4 - _halfGap)),
    ObjectBall(9, Cham(_frozen, 1)),
    ObjectBall(10, Cham(_frozen, 3)),
    ObjectBall(11, Cham(7, _halfGap)), // "half ball gap"
    ObjectBall(12, Cham(7, 4 - _halfGap)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.masters, variant: 1, source: 'BU_Exam-II_Skills-Masters.pdf, trang 6', marks: [
    CueBallInHand(),
    ObjectBall(8, Cham(7, 1)),
    ObjectBall(9, Cham(_frozen, 1)),
    ObjectBall(10, Cham(1, 2)),
    ObjectBall(11, Cham(4, 2)),
    ObjectBall(12, Cham(7, 3)),
    ObjectBall(13, Cham(1, 4 - _halfGap)), // "half ball gap"
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.masters, variant: 2, source: 'BU_Exam-II_Skills-Masters.pdf, trang 7', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(2, _halfGap)),
    ObjectBall(2, Cham(1, 1)),
    ObjectBall(8, Cham(_halfGap, 3)), // "half ball gap"
    ObjectBall(9, Cham(4, 1)),
    ObjectBall(10, Cham(7, 1)),
    ObjectBall(11, Cham(4, 2)),
    ObjectBall(12, Cham(7, 2)),
    ObjectBall(13, Cham(4, 3)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.masters, variant: 3, source: 'BU_Exam-II_Skills-Masters.pdf, trang 8', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(1, 2)),
    ObjectBall(2, Cham(2, 2)),
    // Hai bi chướng ngại khít nhau, khe một bi tới băng dưới.
    ObjectBall(3, Cham(3, 4 - _oneGap - _d)),
    ObjectBall(4, Cham(3, 4 - _oneGap)),
    ObjectBall(8, Cham(0.4, 4 - _frozen)), // đo trên hình: x 0,4
    ObjectBall(9, Cham(2, _frozen)),
    ObjectBall(10, Cham(7, 1)),
    ObjectBall(11, _foot),
    ObjectBall(12, Cham(_frozen, 3)),
    ObjectBall(13, Cham(7, 4 - _frozen)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.doctorate, variant: 1, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 6', marks: [
    CueBallInHand(),
    ObjectBall(8, Cham(7, 1)),
    ObjectBall(9, Cham(4.3, _oneGap)), // "one-ball gap"; x 4,3 đo trên hình
    ObjectBall(10, Cham(_frozen, 1)),
    ObjectBall(11, Cham(2, 3)),
    ObjectBall(12, Cham(4, 3)),
    ObjectBall(13, Cham(6, 3)),
    ObjectBall(14, Cham(4.3, 4 - _oneGap)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.doctorate, variant: 2, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 7', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(2, 2)),
    ObjectBall(2, Cham(1, 4 - _oneGap)), // khe một bi tới băng dưới
    ObjectBall(8, Cham(_frozen, 3)),
    ObjectBall(9, Cham(7, _frozen)),
    ObjectBall(10, Cham(1, 1)),
    ObjectBall(11, Cham(8 - _frozen, 1)),
    ObjectBall(12, Cham(1, 3)),
    ObjectBall(13, Cham(4, 3)),
    ObjectBall(14, Cham(7, 3)),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S4', version: ExamIIVersion.doctorate, variant: 3, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 8', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(1, 2)),
    ObjectBall(2, Cham(2, 2)),
    ObjectBall(3, Cham(7, 2)),
    ObjectBall(4, Cham(3, 4 - _oneGap - _d)),
    ObjectBall(5, Cham(3, 4 - _oneGap)),
    ObjectBall(8, Cham(0.4, 4 - _frozen)), // đo trên hình: x 0,4
    ObjectBall(9, Cham(8 - _frozen, 1)),
    ObjectBall(10, Cham(_frozen, 3)),
    ObjectBall(11, Cham(2, 3)),
    ObjectBall(12, Cham(4, 3)),
    ObjectBall(13, Cham(6, 3)),
    ObjectBall(14, Cham(8 - _frozen, 3)),
    SpotRing(_foot),
  ]),

  // ── S6 — "Kick at each OB off the same long rail (as shown), with the CB in
  // the same starting position for each kick". Masters/Doctorate thêm các cú
  // bi cái tự do 2–3 băng vào cùng các bi này. Đường A băng vẽ như hình. ──
  BuLayout(drillId: 'S6', version: ExamIIVersion.bachelors, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 10', marks: [
    CueBall(Cham(1, 1)),
    ObjectBall(1, Cham(2, 2)),
    ObjectBall(2, Cham(3, 2)),
    ObjectBall(3, Cham(4, 2)),
    AimPath([Cham(1, 1), Cham(1.6, 4), Cham(2, 2)]),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S6', version: ExamIIVersion.masters, source: 'BU_Exam-II_Skills-Masters.pdf, trang 10', marks: [
    CueBall(Cham(1, 1)),
    ObjectBall(1, Cham(2, 2)),
    ObjectBall(2, Cham(3, 2)),
    ObjectBall(3, Cham(4, 2)),
    ObjectBall(4, _foot),
    AimPath([Cham(1, 1), Cham(1.6, 4), Cham(2, 2)]),
    SpotRing(_foot),
  ]),
  BuLayout(drillId: 'S6', version: ExamIIVersion.doctorate, source: 'BU_Exam-II_Skills-Doctorate.pdf, trang 10', marks: [
    CueBall(Cham(1, 1)),
    ObjectBall(1, Cham(2, 2)),
    ObjectBall(2, Cham(3, 2)),
    ObjectBall(3, Cham(4, 2)),
    ObjectBall(4, _foot),
    AimPath([Cham(1, 1), Cham(1.6, 4), Cham(2, 2)]),
    SpotRing(_foot),
  ]),

  // ── S7 Bachelors — "With CB in hand for each shot, bank each ball cross
  // side." Bi 1 ở (3, 2), "one-ball gaps" giữa các bi. ──
  BuLayout(drillId: 'S7', version: ExamIIVersion.bachelors, source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 11', marks: [
    CueBallInHand(),
    ObjectBall(1, Cham(3, 2)),
    ObjectBall(2, Cham(3 - 2 * _d, 2)),
    ObjectBall(3, Cham(3 - 4 * _d, 2)),
    TargetPocket(Pocket.topMiddle),
    SpotRing(_foot),
  ]),
];

// ─── Sơ đồ dựng theo luật (F1–F8, S1, S5, S7 Masters/Doctorate, S8, S9, S10)
//
// PDF cho cách xếp bằng một luật (thang vị trí, "halfway between the CB and
// pocket", "one-ball gaps"). Mỗi hàm ghi nguyên câu tiếng Anh của PDF; lời
// gọi lerpCham / evenlySpaced / pocketCham chính là câu đó.

/// Vị trí thang 1–7 trên hàng [y]: vị trí n ở chấm 8 − n (PDF đánh số 7…1 từ
/// trái sang phải trên băng trên).
List<LadderPosition> _ladderRow(double y) =>
    [for (var n = 1; n <= 7; n++) LadderPosition(n, Cham(8.0 - n, y))];

/// Hàng bi cái của F2–F4: PDF vẽ cách băng trên khoảng 1/3 chấm và cho phép
/// "vary the CB and OB positions away from the rail as long as the CB remains
/// within one diamond of the rail"; làm tròn về 1/4 chấm (đo trên hình).
const _railRow = 0.25;

/// F1 — "Start with the cue ball (CB) in position 4. Each time you pocket the
/// object ball (OB), advance the CB one position"; OB "one ball gap" từ băng
/// cuối, trên đường chấm 3, "pocket the OB" vào lỗ góc dưới phải
/// (BU_Exam-I_Fundamentals.pdf, trang 1).
BuLayout _f1() {
  const ob = Cham(8 - _oneGap, 3);
  return BuLayout(drillId: 'F1', source: _e1(1), marks: [
    const CueBall(Cham(4, 1)),
    const ObjectBall(1, ob),
    ..._ladderRow(1),
    AimPath([ob, pocketCham(Pocket.bottomRight)], dashed: true),
    const TargetPocket(Pocket.bottomRight),
  ]);
}

/// F2 — "the stopped CB must overlap at least part of the ghost-ball (GB)
/// outline"; "the OB is at the half-diamond position"
/// (BU_Exam-I_Fundamentals.pdf, trang 2). Vòng bi ảo cách OB một bi.
BuLayout _f2() {
  const ob = Cham(7.5, _railRow);
  return BuLayout(drillId: 'F2', source: _e1(2), marks: [
    const CueBall(Cham(4, _railRow)),
    const ObjectBall(1, ob),
    ..._ladderRow(_railRow),
    const SpotRing(Cham(7.5 - _d, _railRow)),
    AimPath([ob, pocketCham(Pocket.topRight)], dashed: true),
    const TargetPocket(Pocket.topRight),
  ]);
}

/// F3 — "The CB and OB are always 1 diamond apart"; khung giấy "8.5”x11”"
/// đặt ở góc trên phải, cạnh dài dọc băng cuối
/// (BU_Exam-I_Fundamentals.pdf, trang 3).
BuLayout _f3() => BuLayout(drillId: 'F3', source: _e1(3), marks: [
      const CueBall(Cham(4, _railRow)),
      const ObjectBall(1, Cham(5, _railRow)),
      ..._ladderRow(_railRow),
      const TargetZone(Cham(8 - _paperShort, 0), Cham(8, _paperLong)),
      const TargetPocket(Pocket.topRight),
    ]);

/// F4 — "the CB must end up within the 2x1 diamond rectangle adjacent to the
/// side pocket"; "the OB is at the half-diamond position"
/// (BU_Exam-I_Fundamentals.pdf, trang 4).
BuLayout _f4() => BuLayout(drillId: 'F4', source: _e1(4), marks: [
      const CueBall(Cham(4, _railRow)),
      const ObjectBall(1, Cham(7.5, _railRow)),
      ..._ladderRow(_railRow),
      const TargetZone(Cham(4, 0), Cham(6, 1)),
      const TargetPocket(Pocket.topRight),
    ]);

/// F5 — "the OB is one ball below the table center"; "The target centers for
/// the other positions are aligned with the long-rail diamonds"; vị trí 4
/// "with the long edge against the rail cushion"
/// (BU_Exam-I_Fundamentals.pdf, trang 5). Thang ở đây là vị trí của đích.
BuLayout _f5() {
  Cham centre(int position) => switch (position) {
        1 || 7 => const Cham(5, 2),
        2 || 6 => const Cham(6, 2),
        3 || 5 => const Cham(7, 2),
        _ => const Cham(8 - _paperShort / 2, 2),
      };
  TargetZone paper(double x) => TargetZone(
      Cham(x - _paperLong / 2, 2 - _paperShort / 2), Cham(x + _paperLong / 2, 2 + _paperShort / 2));
  return BuLayout(drillId: 'F5', source: _e1(5), marks: [
    const CueBallInHand(),
    const ObjectBall(1, Cham(4, 2 + _d)),
    for (var n = 1; n <= 7; n++) LadderPosition(n, centre(n)),
    paper(5),
    paper(6),
    paper(7),
    const TargetZone(Cham(8 - _paperShort, 2 - _paperLong / 2), Cham(8, 2 + _paperLong / 2)),
    const TargetPocket(Pocket.bottomMiddle),
  ]);
}

/// F6 — "Shoot all 5 shots from each CB position, attempting to pocket the
/// OBs as shown" (BU_Exam-I_Fundamentals.pdf, trang 6). Hai vị trí bi cái
/// nên hai sơ đồ: cú 1–5 và cú 6–10; mỗi đường nét đứt là một cú.
List<BuLayout> _f6() {
  const tm = Cham(4, 0), tr = Cham(8, 0);
  const bm = Cham(4, 4), br = Cham(8, 4);
  AimPath shot(Cham ob, Cham pocket) => AimPath([ob, pocket], dashed: true);
  const mid = Cham(4, 2), far = Cham(6, 2);
  return [
    BuLayout(drillId: 'F6', variant: 1, source: _e1(6), marks: [
      const CueBall(Cham(2, 1)),
      const ObjectBall(1, Cham(3, 1)),
      const ObjectBall(2, mid),
      const ObjectBall(3, far),
      shot(const Cham(3, 1), tm), // 1
      shot(const Cham(3, 1), tr), // 2
      shot(far, br), // 3
      shot(mid, bm), // 4
      shot(mid, br), // 5
    ]),
    BuLayout(drillId: 'F6', variant: 2, source: _e1(6), marks: [
      const CueBall(Cham(2, 3)),
      const ObjectBall(4, Cham(3, 3)),
      const ObjectBall(2, mid),
      const ObjectBall(3, far),
      shot(const Cham(3, 3), bm), // 6
      shot(const Cham(3, 3), br), // 7
      shot(far, tr), // 8
      shot(mid, tm), // 9
      shot(mid, tr), // 10
    ]),
  ];
}

/// F7 — "Pocket the OB and have the CB hit each of the rail target balls";
/// OB trên đường chấm 1 ngay dưới lỗ giữa trên, bi đích áp sát băng
/// (BU_Exam-I_Fundamentals.pdf, trang 7). PDF vẽ OB là bi sọc không số: ở
/// đây mang số 15. Bi 4 và 8 nằm sát góc: đo trên hình.
BuLayout _f7() => BuLayout(drillId: 'F7', source: _e1(7), marks: const [
      CueBallInHand(),
      ObjectBall(15, Cham(4, 1)),
      ObjectBall(1, Cham(5, _frozen)),
      ObjectBall(2, Cham(6, _frozen)),
      ObjectBall(3, Cham(7, _frozen)),
      ObjectBall(4, Cham(7.8, 0.15)),
      ObjectBall(5, Cham(8 - _frozen, 1)),
      ObjectBall(6, Cham(8 - _frozen, 2)),
      ObjectBall(7, Cham(8 - _frozen, 3)),
      ObjectBall(8, Cham(7.8, 3.85)),
      ObjectBall(9, Cham(7, 4 - _frozen)),
      ObjectBall(10, Cham(6, 4 - _frozen)),
      TargetPocket(Pocket.topMiddle),
    ]);

/// F8 — "The OB (1 ball) must be pocketed and the CB must end up within or
/// overlapping each of the targets"; năm khung giấy, tâm trên đường chấm 2
/// và 6 sát băng, và ở giữa bàn (BU_Exam-I_Fundamentals.pdf, trang 8).
BuLayout _f8() {
  TargetZone top(double x) => TargetZone(Cham(x - _paperLong / 2, 0), Cham(x + _paperLong / 2, _paperShort));
  TargetZone bottom(double x) =>
      TargetZone(Cham(x - _paperLong / 2, 4 - _paperShort), Cham(x + _paperLong / 2, 4));
  return BuLayout(drillId: 'F8', source: _e1(8), marks: [
    const CueBall(Cham(1.5, 2)),
    const ObjectBall(1, Cham(1, 1)),
    top(2), // 1
    top(6), // 2
    bottom(6), // 3
    const TargetZone(Cham(4 - _paperLong / 2, 2 - _paperShort / 2), Cham(4 + _paperLong / 2, 2 + _paperShort / 2)), // 4
    bottom(2), // 5
    const TargetPocket(Pocket.topLeft),
  ]);
}

/// S1 — "Pocket the balls in rotation"; bi trên đường giữa bàn, bi 1 "one-ball
/// gap" từ băng cuối, khe giữa các bi: Bachelors "three-ball gaps", Masters
/// "two-ball gaps", Doctorate "one-ball gaps" (BU_Exam-II_Skills-*.pdf,
/// trang 1).
BuLayout _s1(ExamIIVersion v) {
  final count = _by(v, 4, 7, 10);
  final gapBalls = _by(v, 3, 2, 1);
  return BuLayout(drillId: 'S1', version: v, source: _e2(v, 1), marks: [
    const CueBallInHand(),
    for (var n = 1; n <= count; n++)
      ObjectBall(n, Cham(8 - _oneGap - (n - 1) * (gapBalls + 1) * _d, 2)),
  ]);
}

/// Cụm 9 bi xếp khít hình thoi, nằm ngang, tâm ở [c]: cột −2…2 có 1, 2, 3, 2,
/// 1 bi; [numbers] theo thứ tự cột, trên xuống dưới.
List<ObjectBall> _diamondRack(Cham c, List<int> numbers) {
  final cols = [
    [0.0],
    [-_d / 2, _d / 2],
    [-_d, 0.0, _d],
    [-_d / 2, _d / 2],
    [0.0],
  ];
  final balls = <ObjectBall>[];
  var i = 0;
  for (var col = 0; col < cols.length; col++) {
    for (final dy in cols[col]) {
      balls.add(ObjectBall(numbers[i++], Cham(c.x + (col - 2) * _rackStep, c.y + dy)));
    }
  }
  return balls;
}

/// S5 — "Take two attempts from each CB position … where the OB is hidden from
/// the CB"; "tightly-racked obstacle-ball cluster" trong khung giấy
/// "8.5”x11”" tâm (6, 1) (BU_Exam-II_Skills-*.pdf, trang 9). Mỗi vị trí bi
/// cái một sơ đồ, theo số thứ tự PDF ghi.
List<BuLayout> _s5(ExamIIVersion v) {
  final positions = _by(v, const [Cham(1, 2), Cham(1, 3.5), Cham(2, 3.5)], const [
    Cham(2, 2), Cham(1, 2), Cham(1, 3), Cham(1, 3.5), Cham(2, 3.5),
  ], const [
    Cham(2, 2), Cham(1, 2), Cham(1, 2.5), Cham(1, 3), Cham(1, 3.5), Cham(2, 3.5), Cham(2.5, 3.5),
  ]);
  return [
    for (var i = 0; i < positions.length; i++)
      BuLayout(drillId: 'S5', version: v, variant: i + 1, source: _e2(v, 9), marks: [
        CueBall(positions[i]),
        const ObjectBall(1, Cham(2, 3)),
        ..._diamondRack(const Cham(6, 1), const [2, 3, 4, 5, 6, 7, 8, 9, 10]),
        const TargetZone(Cham(6 - _paperLong / 2, 1 - _paperShort / 2),
            Cham(6 + _paperLong / 2, 1 + _paperShort / 2)),
      ]),
  ];
}

/// S7 Masters/Doctorate — Masters "Bank the OB cross side from each of the 5
/// CB positions": bi cái 1–5 khít nhau trên đường giữa bàn, vị trí 3 ở chấm
/// 3, OB ở (3, 3). Doctorate "Bank the OB cross corner from each of the 7 CB
/// positions": bi cái mỗi nửa chấm từ chấm 6 về chấm 3, OB ở (6, 3)
/// (BU_Exam-II_Skills-*.pdf, trang 11).
List<BuLayout> _s7(ExamIIVersion v) {
  if (v == ExamIIVersion.bachelors) return const [];
  final masters = v == ExamIIVersion.masters;
  final cbs = masters
      ? [for (var i = 0; i < 5; i++) Cham(3 + (i - 2) * _d, 2)]
      : evenlySpaced(const Cham(6, 2), const Cham(3, 2), 7);
  final ob = masters ? const Cham(3, 3) : const Cham(6, 3);
  return [
    for (var i = 0; i < cbs.length; i++)
      BuLayout(drillId: 'S7', version: v, variant: i + 1, source: _e2(v, 11), marks: [
        CueBall(cbs[i]),
        ObjectBall(1, ob),
        TargetPocket(masters ? Pocket.topMiddle : Pocket.topRight),
        const SpotRing(_foot),
      ]),
  ];
}

/// Điểm cách [from] một khoảng [dist] chấm về phía [to].
Cham _toward(Cham from, Cham to, double dist) {
  final dx = to.x - from.x, dy = to.y - from.y;
  final len = math.sqrt(dx * dx + dy * dy);
  return Cham(from.x + dx / len * dist, from.y + dy / len * dist);
}

/// S8 — "Pocket each OB from the indicated CB position without scratching";
/// "the OBs are halfway between the CB and pocket"; "the CB is frozen to the
/// cushion"; "the CB is frozen to the obstacle ball in line with the shot"
/// (BU_Exam-II_Skills-*.pdf, trang 12). Lỗ góc dưới phải. Bi chướng ngại
/// (bi sọc không số) mang số 15.
List<BuLayout> _s8(ExamIIVersion v) {
  final pocket = pocketCham(Pocket.bottomRight);
  // (bi cái, bi chướng ngại hoặc null) theo thứ tự cú của PDF.
  (Cham, Cham?) behind(Cham obstacle) => (_toward(obstacle, pocket, _d), obstacle);
  final shots = <(Cham, Cham?)>[
    (const Cham(7, _frozen), null),
    (const Cham(6, _frozen), null),
    behind(const Cham(5, _frozen)),
    if (v != ExamIIVersion.bachelors) ...[
      (const Cham(3, _frozen), null),
      behind(const Cham(3, 1)),
    ],
    if (v == ExamIIVersion.doctorate) ...[
      (const Cham(_frozen, 2), null),
      behind(const Cham(2, 3)),
    ],
  ];
  return [
    for (var i = 0; i < shots.length; i++)
      BuLayout(drillId: 'S8', version: v, variant: i + 1, source: _e2(v, 12), marks: [
        CueBall(shots[i].$1),
        ObjectBall(i + 1, lerpCham(shots[i].$1, pocket, 0.5)),
        if (shots[i].$2 case final o?) ObjectBall(15, o),
        const TargetPocket(Pocket.bottomRight),
      ]),
  ];
}

/// S9 — Bachelors "jump the CB over the gap, or swerve the CB around one of
/// the obstacle balls, and pocket the hanger in the corner" ("1 ball-width
/// gap"); Masters "jump or curve the CB over or around the obstacle ball, and
/// pocket the hanger in the corner"; Doctorate "… and scratch in the corner"
/// ("two ball gap"), không có bi mục tiêu (BU_Exam-II_Skills-*.pdf, trang 13).
/// Bi chướng ngại nằm trên đường bi cái (1, 1) → lỗ góc dưới phải. Bi treo
/// miệng lỗ: đo trên hình.
BuLayout _s9(ExamIIVersion v) {
  const cb = Cham(1, 1);
  final pocket = pocketCham(Pocket.bottomRight);
  // Điểm trên đường bắn ở chấm 2 (PDF kẻ đường chấm 2 tới bi chướng ngại).
  final onLine = Cham(2, cb.y + (pocket.y - cb.y) / (pocket.x - cb.x) * (2 - cb.x));
  final dx = pocket.x - cb.x, dy = pocket.y - cb.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final perp = Cham(-dy / len, dx / len);
  final obstacles = switch (v) {
    // Hai bi cách nhau một bi, đối xứng qua đường bắn.
    ExamIIVersion.bachelors => [
        Cham(onLine.x - perp.x * _d, onLine.y - perp.y * _d),
        Cham(onLine.x + perp.x * _d, onLine.y + perp.y * _d),
      ],
    ExamIIVersion.masters => [onLine],
    // "two ball gap" giữa bi cái và bi chướng ngại: tâm cách nhau 3 bi.
    ExamIIVersion.doctorate => [_toward(cb, pocket, 3 * _d)],
  };
  return BuLayout(drillId: 'S9', version: v, source: _e2(v, 13), marks: [
    const CueBall(cb),
    if (v != ExamIIVersion.doctorate) const ObjectBall(1, Cham(7.8, 3.85)),
    for (var i = 0; i < obstacles.length; i++) ObjectBall(14 + i, obstacles[i]),
    AimPath([cb, pocket]),
    const TargetPocket(Pocket.bottomRight),
  ]);
}

/// S10 — "9-ball break with CB in hand behind the head string"; "CB target
/// zone" giữa vạch đầu bàn (chấm 2) và chấm 6; giá bi 9 đỉnh ở chấm đặt bi
/// (BU_Exam-II_Skills-*.pdf, trang 14). Bi 1 ở đỉnh, bi 9 ở giữa.
BuLayout _s10(ExamIIVersion v) {
  const rows = [
    [0.0],
    [-_d / 2, _d / 2],
    [-_d, 0.0, _d],
    [-_d / 2, _d / 2],
    [0.0],
  ];
  const numbers = [1, 2, 3, 4, 9, 5, 6, 7, 8];
  var i = 0;
  return BuLayout(drillId: 'S10', version: v, source: _e2(v, 14), marks: [
    const CueBallInHand(),
    for (var col = 0; col < rows.length; col++)
      for (final dy in rows[col]) ObjectBall(numbers[i++], Cham(6 + col * _rackStep, 2 + dy)),
    const TargetZone(Cham(2, 0), Cham(6, 4)),
  ]);
}

List<BuLayout> _constructed() => [
      _f1(),
      _f2(),
      _f3(),
      _f4(),
      _f5(),
      ..._f6(),
      _f7(),
      _f8(),
      for (final v in ExamIIVersion.values) ...[
        _s1(v),
        ..._s5(v),
        ..._s7(v),
        ..._s8(v),
        _s9(v),
        _s10(v),
      ],
    ];

List<BuLayout> allLayouts() {
  final all = [..._transcribed, ..._constructed()];
  int examRank(BuLayout l) => l.version?.index ?? -1;
  int drillRank(BuLayout l) =>
      [...examIDrills.map((d) => d.id), for (var i = 1; i <= 10; i++) 'S$i'].indexOf(l.drillId);
  all.sort((a, b) {
    final byExam = (a.drillId.startsWith('F') ? -1 : examRank(a))
        .compareTo(b.drillId.startsWith('F') ? -1 : examRank(b));
    if (byExam != 0) return byExam;
    final byDrill = drillRank(a).compareTo(drillRank(b));
    return byDrill != 0 ? byDrill : a.variant.compareTo(b.variant);
  });
  return all;
}

List<BuLayout> layoutsFor(String drillId, ExamIIVersion? version) => [
      for (final l in allLayouts())
        if (l.drillId == drillId && (drillId.startsWith('F') || l.version == version)) l,
    ];

/// Sơ đồ cho lượt thứ [attemptIndex] (từ 0): chia đều số lượt của bài cho
/// số sơ đồ đã chép — S3 lượt 2 là thế 2, bài một sơ đồ thì luôn sơ đồ đó.
BuLayout layoutForAttempt(BuDrill drill, ExamIIVersion? version, int attemptIndex) {
  final layouts = layoutsFor(drill.id, version);
  if (layouts.isEmpty) throw StateError('Chưa có sơ đồ cho ${drill.id} $version');
  final i = attemptIndex * layouts.length ~/ drill.attemptCount;
  return layouts[i.clamp(0, layouts.length - 1)];
}
