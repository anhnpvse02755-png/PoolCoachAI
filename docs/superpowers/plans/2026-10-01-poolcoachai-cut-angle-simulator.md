# Cut Angle Simulator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the single-shot Cut Angle Simulator at `/training/simulator`, built on a pure-Dart table geometry core (ghost ball, cut angle, pocket choice, cue-ball path with Dội băng and áp phê, Chết cái detection and advice) that the Run-out Planner will reuse unchanged.

**Architecture:** `lib/domain/table_geometry/` is plain Dart with no Flutter import: one file per concern, every number traceable to a named, tested function. The screen is a `StatefulWidget` (no Riverpod, no Drift — nothing is saved) that calls the core on every change and draws with a `CustomPainter`. All visible text goes through `Vi`.

**Tech Stack:** Flutter 3.47 / Dart 3.13, go_router (`StatefulShellRoute`), `flutter_test`; Node 26 + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** `docs/superpowers/specs/2026-10-01-poolcoachai-cut-angle-simulator-design.md`. The PRD it builds on is `PRD_RunOutPlanner.md`.

## Global Constraints

- Flutter is not on PATH. Discover it (`where flutter.bat`, else `C:\Users\anhnpv\flutter\bin\flutter.bat`; never `D:\flutter`) and use it as `$FLUTTER` / `$DART` in every command below.
- `lib/domain/table_geometry/` never imports `package:flutter` (enforced by `test/architecture_test.dart` from Task 1).
- Units are centimetres on a 9-foot table: 254 × 127, ball diameter 5.715, origin top-left, `y` down.
- Tunable constants keep these names and starting values: `maxTravel = 254.0`, `rollCarry = 0.5`, `spinDegPerRadius = 20.0`, `cornerCapture = 6.0`, `middleCapture = 5.0`, `maxCutAngle = 85.0`, `miscueTips = 2.0`, `overhitBand = 15.0`, `tipWidth = 1.25`. Tests reference the constants, never their literal values, so tuning in Task 10 does not rewrite tests.
- Terms on screen, exactly: **Đánh đứng bi · Đánh trô bi · Đánh cu lê**, **Bi ảo** (never "bi ma"), **Dội băng**, **Áp phê** trái/phải, **Lệch N đầu cơ** (never "đầu gậy"), **Chết cái**, **Trượt cơ**. The stroke picker is labelled **Kiểu đánh**.
- All UI text lives in `lib/core/strings/vi.dart` (an architecture test fails on Vietnamese literals in `lib/features`). Sentences with numbers are templates filled from core results — never pre-written content (memory: no-fabricated-generated-content).
- `maxCutAngle` is inclusive: exactly 85° is makeable.
- At most one Dội băng; a second rail stops the cue ball.
- Comments follow the surrounding code: Vietnamese, explaining *why*.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **A straight shot (cut angle ≈ 0°).** Trô must come straight back, cu lê must go straight forward, and đứng bi must stop at Bi ảo. It must never move sideways because of floating-point noise in the tangent direction. Owner: Task 4 (straight-shot tests, plus the `1e-9` tangent cut-off in Task 2).
2. **The object ball frozen on a cushion.** The pocket would need Bi ảo behind the rail. The screen must say why, never crash or draw a path from off the table. Owner: Task 2 (`ghostOffTable`) and Task 9 (tapping a pocket shows the reason).
3. **A cue ball that follows the object ball into the same pocket.** It must be reported as Chết cái with no Dội băng, because it drops before it reaches the rail. Owner: Task 6.
4. **Dragging a ball onto the other ball, or past the cushion.** The ball must stop touching or at the rail, never overlap or leave the table. Owner: Task 9 (drag test onto the other ball).
5. **Vertical drags on the table.** They must move the ball, not scroll the page. The table therefore sits outside the scroll view. Owner: Task 9 (vertical drag test).

---

## File map

| File | Responsibility |
|---|---|
| `lib/domain/table_geometry/vec2.dart` | `Vec2`, `clampRange` |
| `lib/domain/table_geometry/table_spec.dart` | `TableSpec`, `Pocket`, capture constants |
| `lib/domain/table_geometry/path_clear.dart` | `distanceToSegment`, `isPathClear` |
| `lib/domain/table_geometry/shot_geometry.dart` | `ShotGeometry`, `ShotResult`, `evaluateShot`, `maxCutAngle` |
| `lib/domain/table_geometry/difficulty.dart` | `DifficultyBand`, `bandFor`, `bandOf` |
| `lib/domain/table_geometry/pocket_choice.dart` | `compareShots`, `bestPocket` |
| `lib/domain/table_geometry/stroke.dart` | `Stroke`, `SpinSide`, `SideSpin`, `powerPresets`, `tipWidth`, `miscueTips` |
| `lib/domain/table_geometry/cue_ball_path.dart` | `PathSegment`/`Straight`/`Curve`, `CueBallPath`, `simulateCueBall`, path constants |
| `lib/domain/table_geometry/scratch.dart` | `ScratchRisk`, `scratchMargin`, `SpinOutcome`, `Advice` family, `chooseAdvice`, `scratchAdvice` |
| `test/support/table_layouts.dart` | `cueForAngle`, `geometryFor`, `gridShots` test helpers |
| `test/domain/table_geometry/*_test.dart` | core tests |
| `lib/core/strings/vi.dart` | simulator strings and templates |
| `lib/core/theme/app_colors.dart` | table colours |
| `lib/features/training/presentation/simulator/table_painter.dart` | `TableLayout`, `SimulatorScene`, `TablePainter` |
| `lib/features/training/presentation/simulator/simulator_panel.dart` | pickers, info panel, disclaimer |
| `lib/features/training/presentation/simulator/simulator_screen.dart` | state, gestures, layout |
| `lib/core/router/routes.dart`, `lib/core/router/app_router.dart` | `/training/simulator` |
| `lib/features/training/presentation/training_screen.dart` | entry card |
| `test/features/training/simulator_screen_test.dart`, `test/features/training/table_layout_test.dart` | widget tests |
| `test/smoke/all_routes_test.dart`, `test/features/training/training_screen_test.dart` | route + card coverage |
| `tool/e2e/throwaway_user.mjs`, `tool/e2e/simulator.mjs`, `tool/e2e/accounts.mjs` | browser check |

---

### Task 0: Worktree and baseline

- [ ] **Step 1: Create the worktree** with superpowers:using-git-worktrees, on branch `feat/cut-angle-simulator` from `main`.
- [ ] **Step 2: Generate code and run the baseline**

```bash
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" test
```

Expected: all tests pass (347 at `3c19755`). If not, stop and report: the baseline must be green before any change.

---

### Task 1: `Vec2`, `TableSpec`, and the no-Flutter rule

**Files:**
- Create: `lib/domain/table_geometry/vec2.dart`, `lib/domain/table_geometry/table_spec.dart`
- Test: `test/domain/table_geometry/vec2_table_test.dart`
- Modify: `test/architecture_test.dart` (add one test inside `main`)

**Interfaces:**
- Produces: `class Vec2 { const Vec2(double x, double y); static const zero; + - * unary-; dot; cross; length; distanceTo; isZero; normalized; rightNormal; rotated(double radians); signedAngleTo(Vec2) }`, `double clampRange(double v, double lo, double hi)`, `enum Pocket { topLeft, topMiddle, topRight, bottomLeft, bottomMiddle, bottomRight; bool get isCorner }`, `const cornerCapture = 6.0`, `const middleCapture = 5.0`, `class TableSpec { const TableSpec({double length = 254, double width = 127, double ballDiameter = 5.715}); static const nineFoot; radius; minX; maxX; minY; maxY; contains(Vec2); clamp(Vec2); pocketPosition(Pocket); captureRadius(Pocket) }`

- [ ] **Step 1: Write the failing tests**

`test/domain/table_geometry/vec2_table_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  group('Vec2', () {
    test('phép vector cơ bản', () {
      const a = Vec2(3, 4);
      expect(a.length, 5);
      expect(a + const Vec2(1, 1), const Vec2(4, 5));
      expect(a - const Vec2(1, 1), const Vec2(2, 3));
      expect(a * 2, const Vec2(6, 8));
      expect(-a, const Vec2(-3, -4));
      expect(a.dot(const Vec2(1, 0)), 3);
      expect(const Vec2(1, 0).cross(const Vec2(0, 1)), 1);
      expect(a.distanceTo(Vec2.zero), 5);
      expect(a.normalized.length, closeTo(1, 1e-12));
      expect(Vec2.zero.normalized, Vec2.zero);
    });

    test('bên phải khi nhìn từ trên xuống, với y hướng xuống', () {
      // Đi lên màn hình thì bên phải là hướng đông.
      expect(const Vec2(0, -1).rightNormal, const Vec2(1, 0));
      // Đi về đông thì bên phải là hướng nam (xuống màn hình).
      expect(const Vec2(1, 0).rightNormal, const Vec2(0, 1));
    });

    test('xoay và đo góc có dấu là hai phép ngược nhau', () {
      const v = Vec2(1, 0);
      expect(v.signedAngleTo(v.rotated(0.3)), closeTo(0.3, 1e-12));
      expect(v.signedAngleTo(v.rotated(-1.2)), closeTo(-1.2, 1e-12));
      expect(v.rotated(math.pi / 2).x, closeTo(0, 1e-12));
    });

    test('so sánh chính xác, không dung sai', () {
      expect(const Vec2(1, 2) == const Vec2(1, 2), isTrue);
      expect(const Vec2(1, 2) == const Vec2(1, 2.0000000001), isFalse);
    });

    test('clampRange', () {
      expect(clampRange(5, 0, 3), 3);
      expect(clampRange(-1, 0, 3), 0);
      expect(clampRange(2, 0, 3), 2);
    });
  });

  group('TableSpec', () {
    const table = TableSpec.nineFoot;

    test('biên tâm bi lùi đúng một bán kính khỏi mép', () {
      expect(table.radius, closeTo(2.8575, 1e-12));
      expect(table.minX, closeTo(2.8575, 1e-12));
      expect(table.maxX, closeTo(251.1425, 1e-12));
      expect(table.minY, closeTo(2.8575, 1e-12));
      expect(table.maxY, closeTo(124.1425, 1e-12));
    });

    test('sáu lỗ ở bốn góc và giữa hai băng dài', () {
      expect(table.pocketPosition(Pocket.topLeft), const Vec2(0, 0));
      expect(table.pocketPosition(Pocket.topMiddle), const Vec2(127, 0));
      expect(table.pocketPosition(Pocket.topRight), const Vec2(254, 0));
      expect(table.pocketPosition(Pocket.bottomLeft), const Vec2(0, 127));
      expect(table.pocketPosition(Pocket.bottomMiddle), const Vec2(127, 127));
      expect(table.pocketPosition(Pocket.bottomRight), const Vec2(254, 127));
      expect(Pocket.topMiddle.isCorner, isFalse);
      expect(Pocket.bottomRight.isCorner, isTrue);
    });

    test('contains và clamp theo biên tâm bi', () {
      expect(table.contains(const Vec2(2, 50)), isFalse);
      expect(table.contains(const Vec2(100, 50)), isTrue);
      expect(table.clamp(const Vec2(-5, 200)), Vec2(table.minX, table.maxY));
    });

    test('vùng lọt lỗ khác nhau giữa lỗ góc và lỗ giữa', () {
      expect(table.captureRadius(Pocket.topLeft), cornerCapture);
      expect(table.captureRadius(Pocket.bottomMiddle), middleCapture);
    });
  });
}
```

Append inside `main()` of `test/architecture_test.dart`, after the last existing test:

```dart
  test('lõi hình học bàn không phụ thuộc Flutter', () {
    final offenders = [
      for (final file in dartFilesIn('lib/domain/table_geometry'))
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'Planner và test dùng thẳng lõi này; kéo Flutter vào thì lõi '
          'không còn là logic thuần, và mọi phép tính phải chạy qua widget',
    );
  });
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/vec2_table_test.dart test/architecture_test.dart`
Expected: FAIL. `vec2.dart` is not found, and the architecture test throws because `lib/domain/table_geometry` doesn't exist.

- [ ] **Step 3: Implement**

`lib/domain/table_geometry/vec2.dart`:

```dart
import 'dart:math' as math;

/// Kẹp [v] vào đoạn [lo, hi].
double clampRange(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Điểm hay vector trên mặt bàn, đơn vị cm, y hướng xuống.
///
/// `==` so sánh chính xác, không dung sai: bất biến `landingPos ==
/// cbFrom` của Planner dựa vào việc truyền thẳng cùng một giá trị cho
/// bước sau, không tính lại.
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 other) => x * other.x + y * other.y;
  double cross(Vec2 other) => x * other.y - y * other.x;
  double get length => math.sqrt(x * x + y * y);
  double distanceTo(Vec2 other) => (this - other).length;
  bool get isZero => x == 0 && y == 0;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  /// Bên phải của vector khi nhìn bàn từ trên xuống.
  ///
  /// Với y hướng xuống, quay vector 90° theo chiều kim đồng hồ trên màn
  /// hình là `(-y, x)`. Áp phê dùng hướng này để biết băng đẩy bi về
  /// phía nào.
  Vec2 get rightNormal => Vec2(-y, x);

  Vec2 rotated(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  /// Góc có dấu từ vector này tới [other], radian, cùng chiều với [rotated].
  double signedAngleTo(Vec2 other) => math.atan2(cross(other), dot(other));

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
```

`lib/domain/table_geometry/table_spec.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Sáu lỗ. Mã không bao giờ dựa vào chỉ số 0–5 của PRD.
enum Pocket {
  topLeft,
  topMiddle,
  topRight,
  bottomLeft,
  bottomMiddle,
  bottomRight;

  bool get isCorner => this != topMiddle && this != bottomMiddle;
}

/// Tâm bi cái lọt vào trong bán kính này quanh điểm lỗ là chết cái, cm.
///
/// Giá trị khởi điểm, chỉnh bằng mắt trên màn mô phỏng.
const cornerCapture = 6.0;
const middleCapture = 5.0;

/// Mặt chơi bàn 9 feet, đơn vị cm, gốc ở góc trên trái.
class TableSpec {
  const TableSpec({
    this.length = 254,
    this.width = 127,
    this.ballDiameter = 5.715,
  });

  static const nineFoot = TableSpec();

  final double length;
  final double width;
  final double ballDiameter;

  double get radius => ballDiameter / 2;

  // Biên mà tâm bi chạy được — mọi điểm chạm băng nằm đúng trên biên này.
  double get minX => radius;
  double get maxX => length - radius;
  double get minY => radius;
  double get maxY => width - radius;

  bool contains(Vec2 p) =>
      p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;

  Vec2 clamp(Vec2 p) =>
      Vec2(clampRange(p.x, minX, maxX), clampRange(p.y, minY, maxY));

  Vec2 pocketPosition(Pocket pocket) => switch (pocket) {
        Pocket.topLeft => const Vec2(0, 0),
        Pocket.topMiddle => Vec2(length / 2, 0),
        Pocket.topRight => Vec2(length, 0),
        Pocket.bottomLeft => Vec2(0, width),
        Pocket.bottomMiddle => Vec2(length / 2, width),
        Pocket.bottomRight => Vec2(length, width),
      };

  double captureRadius(Pocket pocket) =>
      pocket.isCorner ? cornerCapture : middleCapture;
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/vec2_table_test.dart test/architecture_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_geometry test/domain/table_geometry test/architecture_test.dart
git commit -m "Add the table geometry foundation: exact vectors, the 9-foot table and its pockets

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Evaluating one shot — Bi ảo, cut angle, blocking, difficulty

**Files:**
- Create: `lib/domain/table_geometry/path_clear.dart`, `lib/domain/table_geometry/shot_geometry.dart`, `lib/domain/table_geometry/difficulty.dart`, `test/support/table_layouts.dart`
- Test: `test/domain/table_geometry/shot_geometry_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `double distanceToSegment(Vec2 p, Vec2 a, Vec2 b)`
  - `bool isPathClear(Vec2 from, Vec2 to, Iterable<Vec2> others, {TableSpec table})`
  - `const maxCutAngle = 85.0`
  - `class ShotGeometry { cue, object, pocket, ghost, objectDir, tangentDir, aimDir, angle }` (public const constructor, all named and required)
  - `enum UnmakeableReason { overlap, ghostOffTable, tooThin, cueBlocked, objectBlocked }`
  - `sealed class ShotResult`, `final class Makeable(ShotGeometry geometry)`, `final class Unmakeable(UnmakeableReason reason)`
  - `ShotResult evaluateShot({required Vec2 cue, required Vec2 object, required Pocket pocket, Iterable<Vec2> others = const [], TableSpec table = TableSpec.nineFoot})`
  - `enum DifficultyBand { easy, medium, hard, veryHard, extreme, impossible }`, `DifficultyBand bandFor(double angle)`, `DifficultyBand bandOf(ShotResult result)`
  - Test helpers: `Vec2 cueForAngle(Vec2 object, Pocket pocket, double degrees, {double distance = 40})`, `ShotGeometry geometryFor(Vec2 object, Pocket pocket, double degrees, {double distance = 40})`, `const tableCenter = Vec2(127, 63.5)`

- [ ] **Step 1: Write the test helpers**

`test/support/table_layouts.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

const tableCenter = Vec2(127, 63.5);

/// Đặt bi cái sao cho cú cắt vào [pocket] có góc đúng [degrees], bi cái
/// cách bi ảo [distance] cm. Dựng ngược từ định nghĩa, nên test không
/// phải tự tính tay toạ độ.
Vec2 cueForAngle(
  Vec2 object,
  Pocket pocket,
  double degrees, {
  double distance = 40,
}) {
  const table = TableSpec.nineFoot;
  final u = (table.pocketPosition(pocket) - object).normalized;
  final ghost = object - u * table.ballDiameter;
  final aim = u.rotated(degrees * math.pi / 180);
  return ghost - aim * distance;
}

/// Hình học của cú dựng bằng [cueForAngle]; ném lỗi nếu cú không hợp lệ.
ShotGeometry geometryFor(
  Vec2 object,
  Pocket pocket,
  double degrees, {
  double distance = 40,
}) {
  final result = evaluateShot(
    cue: cueForAngle(object, pocket, degrees, distance: distance),
    object: object,
    pocket: pocket,
  );
  return switch (result) {
    Makeable(:final geometry) => geometry,
    Unmakeable(:final reason) => throw StateError('bố cục test hỏng: $reason'),
  };
}
```

- [ ] **Step 2: Write the failing tests**

`test/domain/table_geometry/shot_geometry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const d = 5.715;
  final topRight = table.pocketPosition(Pocket.topRight);

  test('khoảng cách từ điểm tới đoạn thẳng', () {
    const a = Vec2(0, 0);
    const b = Vec2(10, 0);
    expect(distanceToSegment(const Vec2(5, 3), a, b), 3);
    expect(distanceToSegment(const Vec2(-4, 3), a, b), 5); // quá đầu đoạn
    expect(distanceToSegment(const Vec2(1, 1), a, a), closeTo(1.41421356, 1e-8));
    expect(isPathClear(a, b, [const Vec2(5, d)]), isTrue); // đúng D: không chắn
    expect(isPathClear(a, b, [const Vec2(5, d - 0.01)]), isFalse);
  });

  test('bi ảo lùi đúng một đường kính sau bi mục tiêu, trên đường lỗ', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 20);

    expect(g.ghost.distanceTo(tableCenter), closeTo(d, 1e-9));
    expect((tableCenter - g.ghost).cross(topRight - tableCenter),
        closeTo(0, 1e-9));
    expect((tableCenter - g.ghost).dot(topRight - tableCenter),
        greaterThan(0), reason: 'bi ảo phải nằm phía sau, không phải phía lỗ');
    expect(g.objectDir.length, closeTo(1, 1e-12));
  });

  test('góc cắt đúng như dựng', () {
    for (final degrees in <double>[0, 10, 30, 45, 60, 84.9]) {
      final g = geometryFor(tableCenter, Pocket.topRight, degrees);
      expect(g.angle, closeTo(degrees, 1e-5), reason: '$degrees°');
    }
  });

  test('hướng tiếp tuyến vuông góc đường bi mục tiêu, về phía bi cái đi tới',
      () {
    final g = geometryFor(tableCenter, Pocket.topRight, 30);
    expect(g.tangentDir.length, closeTo(1, 1e-12));
    expect(g.tangentDir.dot(g.objectDir), closeTo(0, 1e-12));
    expect(g.tangentDir.dot(g.aimDir), greaterThan(0));
  });

  test('cú thẳng thì không có hướng tiếp tuyến — không để nhiễu số học '
      'đẩy bi cái đi ngang', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 0);
    expect(g.tangentDir, Vec2.zero);
  });

  group('không đánh được', () {
    UnmakeableReason? reasonOf(ShotResult r) =>
        r is Unmakeable ? r.reason : null;

    test('hai bi chồng lên nhau', () {
      final r = evaluateShot(
        cue: tableCenter + const Vec2(d * 0.9, 0),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(reasonOf(r), UnmakeableReason.overlap);
    });

    test('bi mục tiêu sát băng, lỗ đòi bi ảo nằm sau băng', () {
      final r = evaluateShot(
        cue: const Vec2(100, 80),
        object: Vec2(60, table.minY),
        pocket: Pocket.bottomLeft,
      );
      expect(reasonOf(r), UnmakeableReason.ghostOffTable);
    });

    test('quá 85° là quá mỏng; đúng 85° vẫn đánh được', () {
      final over = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, 86),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(reasonOf(over), UnmakeableReason.tooThin);

      final edge = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, maxCutAngle),
        object: tableCenter,
        pocket: Pocket.topRight,
      );
      expect(edge, isA<Makeable>());
    });

    test('đường bi cái tới bi ảo bị chắn', () {
      final cue = cueForAngle(tableCenter, Pocket.topRight, 20, distance: 60);
      final ghost = geometryFor(tableCenter, Pocket.topRight, 20).ghost;
      final r = evaluateShot(
        cue: cue,
        object: tableCenter,
        pocket: Pocket.topRight,
        others: [cue + (ghost - cue) * 0.5],
      );
      expect(reasonOf(r), UnmakeableReason.cueBlocked);
    });

    test('đường bi mục tiêu vào lỗ bị chắn', () {
      final u = (topRight - tableCenter).normalized;
      final r = evaluateShot(
        cue: cueForAngle(tableCenter, Pocket.topRight, 20),
        object: tableCenter,
        pocket: Pocket.topRight,
        others: [tableCenter + u * 30],
      );
      expect(reasonOf(r), UnmakeableReason.objectBlocked);
    });
  });

  test('mức độ khó theo góc cắt, biên dưới thuộc mức trên', () {
    expect(bandFor(0), DifficultyBand.easy);
    expect(bandFor(14.99), DifficultyBand.easy);
    expect(bandFor(15), DifficultyBand.medium);
    expect(bandFor(29.99), DifficultyBand.medium);
    expect(bandFor(30), DifficultyBand.hard);
    expect(bandFor(45), DifficultyBand.veryHard);
    expect(bandFor(60), DifficultyBand.extreme);
    expect(bandFor(85), DifficultyBand.extreme);
    expect(bandFor(85.1), DifficultyBand.impossible);
    expect(bandOf(const Unmakeable(UnmakeableReason.tooThin)),
        DifficultyBand.impossible);
  });
}
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/shot_geometry_test.dart`
Expected: FAIL. The imports are missing.

- [ ] **Step 4: Implement**

`lib/domain/table_geometry/path_clear.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Khoảng cách từ [p] tới đoạn thẳng [a]–[b].
double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len2 = ab.dot(ab);
  if (len2 == 0) return p.distanceTo(a);
  final t = clampRange((p - a).dot(ab) / len2, 0, 1);
  return p.distanceTo(a + ab * t);
}

/// Một bi lăn từ [from] tới [to] có đi lọt qua các bi [others] không.
///
/// Hai tâm bi cách nhau dưới một đường kính là chạm nhau, nên tâm bi
/// khác cách đoạn đường đi dưới `D` là chắn.
bool isPathClear(
  Vec2 from,
  Vec2 to,
  Iterable<Vec2> others, {
  TableSpec table = TableSpec.nineFoot,
}) =>
    others.every((o) => distanceToSegment(o, from, to) >= table.ballDiameter);
```

`lib/domain/table_geometry/shot_geometry.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Quá góc này là không đánh được (PRD §5.1). Đúng 85° vẫn đánh được.
const maxCutAngle = 85.0;

/// Dung sai khi so góc với [maxCutAngle]: dựng đúng 85° rồi tính lại
/// qua acos có thể ra 85.0000000001.
const _angleEpsilon = 1e-9;

/// Dưới độ dài này thì thành phần vuông góc chỉ là nhiễu số học của cú
/// thẳng — coi như không có hướng tiếp tuyến.
const _straightCutoff = 1e-9;

/// Hình học của một cú đánh hợp lệ.
class ShotGeometry {
  const ShotGeometry({
    required this.cue,
    required this.object,
    required this.pocket,
    required this.ghost,
    required this.objectDir,
    required this.tangentDir,
    required this.aimDir,
    required this.angle,
  });

  final Vec2 cue;
  final Vec2 object;
  final Pocket pocket;

  /// Bi ảo: nơi tâm bi cái phải tới lúc chạm.
  final Vec2 ghost;

  /// Hướng bi mục tiêu → lỗ, đơn vị.
  final Vec2 objectDir;

  /// Hướng bi cái đi sau va chạm khi đánh đứng bi, đơn vị; vector không
  /// với cú thẳng.
  final Vec2 tangentDir;

  /// Hướng bi cái → bi ảo, đơn vị.
  final Vec2 aimDir;

  /// Góc cắt, độ.
  final double angle;
}

enum UnmakeableReason { overlap, ghostOffTable, tooThin, cueBlocked, objectBlocked }

sealed class ShotResult {
  const ShotResult();
}

final class Makeable extends ShotResult {
  const Makeable(this.geometry);
  final ShotGeometry geometry;
}

final class Unmakeable extends ShotResult {
  const Unmakeable(this.reason);
  final UnmakeableReason reason;
}

/// Đánh [object] vào [pocket] từ [cue], với các bi [others] còn trên bàn
/// (không gồm bi cái và bi mục tiêu).
ShotResult evaluateShot({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  Iterable<Vec2> others = const [],
  TableSpec table = TableSpec.nineFoot,
}) {
  final d = table.ballDiameter;
  if (cue.distanceTo(object) < d) {
    return const Unmakeable(UnmakeableReason.overlap);
  }

  final pocketPos = table.pocketPosition(pocket);
  final u = (pocketPos - object).normalized;
  final ghost = object - u * d;
  if (!table.contains(ghost)) {
    return const Unmakeable(UnmakeableReason.ghostOffTable);
  }

  final toGhost = ghost - cue;
  // Bi cái nằm đúng chỗ bi ảo nghĩa là hai bi dính nhau theo đường lỗ:
  // đó là cú thẳng.
  final aim = toGhost.isZero ? u : toGhost.normalized;
  final angle = math.acos(clampRange(aim.dot(u), -1, 1)) * 180 / math.pi;
  if (angle > maxCutAngle + _angleEpsilon) {
    return const Unmakeable(UnmakeableReason.tooThin);
  }

  if (!isPathClear(cue, ghost, others, table: table)) {
    return const Unmakeable(UnmakeableReason.cueBlocked);
  }
  if (!isPathClear(object, pocketPos, others, table: table)) {
    return const Unmakeable(UnmakeableReason.objectBlocked);
  }

  final perp = aim - u * aim.dot(u);
  return Makeable(
    ShotGeometry(
      cue: cue,
      object: object,
      pocket: pocket,
      ghost: ghost,
      objectDir: u,
      tangentDir: perp.length < _straightCutoff ? Vec2.zero : perp.normalized,
      aimDir: aim,
      angle: angle,
    ),
  );
}
```

`lib/domain/table_geometry/difficulty.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';

/// Độ khó chỉ theo góc cắt — cùng thước đo `diff` mà Planner dùng
/// (PRD §5.4), để hai màn nói cùng một ngôn ngữ.
enum DifficultyBand { easy, medium, hard, veryHard, extreme, impossible }

/// Biên dưới thuộc mức trên: đúng 15° là Vừa. Đúng 85° vẫn Cực khó.
DifficultyBand bandFor(double angle) {
  if (angle > maxCutAngle) return DifficultyBand.impossible;
  if (angle < 15) return DifficultyBand.easy;
  if (angle < 30) return DifficultyBand.medium;
  if (angle < 45) return DifficultyBand.hard;
  if (angle < 60) return DifficultyBand.veryHard;
  return DifficultyBand.extreme;
}

DifficultyBand bandOf(ShotResult result) => switch (result) {
      Makeable(:final geometry) => bandFor(geometry.angle),
      Unmakeable() => DifficultyBand.impossible,
    };
```

`bandFor` deliberately compares with `>` and no epsilon. `evaluateShot` has already decided makeability, and the band only labels it.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/table_geometry test/domain/table_geometry test/support/table_layouts.dart
git commit -m "Evaluate a single shot: Bi ảo, cut angle, blocking and the difficulty bands

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Choosing the pocket (PRD Priority 1)

**Files:**
- Create: `lib/domain/table_geometry/pocket_choice.dart`
- Test: `test/domain/table_geometry/pocket_choice_test.dart`
- Modify: `test/support/table_layouts.dart` (add `gridShots`)

**Interfaces:**
- Consumes: `evaluateShot`, `ShotGeometry`, `TableSpec`.
- Produces: `int compareShots(ShotGeometry a, ShotGeometry b, {TableSpec table})` (negative means `a` is better), `ShotGeometry? bestPocket({required Vec2 cue, required Vec2 object, Iterable<Vec2> others = const [], TableSpec table = TableSpec.nineFoot})`, and the test helper `Iterable<ShotGeometry> gridShots()`.

- [ ] **Step 1: Add the grid helper** to `test/support/table_layouts.dart`. Add the import `package:poolcoachai/domain/table_geometry/pocket_choice.dart`:

```dart
/// Lưới bố cục tất định phủ khắp bàn, mỗi cặp bi lấy lỗ tự chọn.
///
/// Dùng cho test tính chất: một bất biến phải đúng ở mọi chỗ trên bàn,
/// không chỉ ở vài bố cục dựng tay.
Iterable<ShotGeometry> gridShots() sync* {
  for (var cx = 20.0; cx <= 234; cx += 42) {
    for (var cy = 15.0; cy <= 112; cy += 32) {
      for (var ox = 30.0; ox <= 224; ox += 38) {
        for (var oy = 20.0; oy <= 107; oy += 29) {
          final g = bestPocket(cue: Vec2(cx, cy), object: Vec2(ox, oy));
          if (g != null) yield g;
        }
      }
    }
  }
}
```

- [ ] **Step 2: Write the failing tests**

`test/domain/table_geometry/pocket_choice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;

  test('chọn lỗ có góc cắt nhỏ nhất', () {
    final cue = cueForAngle(tableCenter, Pocket.topRight, 0);
    final best = bestPocket(cue: cue, object: tableCenter)!;
    expect(best.pocket, Pocket.topRight);
    expect(best.angle, closeTo(0, 1e-5));
  });

  test('bỏ lỗ bị chắn, lấy lỗ tốt nhất trong các lỗ còn lại', () {
    final cue = cueForAngle(tableCenter, Pocket.topRight, 0);
    final u = (table.pocketPosition(Pocket.topRight) - tableCenter).normalized;
    final blocker = tableCenter + u * 30;

    final best = bestPocket(cue: cue, object: tableCenter, others: [blocker])!;

    final rest = [
      for (final p in Pocket.values)
        if (evaluateShot(cue: cue, object: tableCenter, pocket: p, others: [blocker])
            case Makeable(:final geometry))
          geometry.angle,
    ]..sort();
    expect(best.pocket, isNot(Pocket.topRight));
    expect(best.angle, rest.first);
  });

  test('không lỗ nào được thì trả null', () {
    final blockers = [
      for (final p in Pocket.values)
        tableCenter + (table.pocketPosition(p) - tableCenter).normalized * 15,
    ];
    final best = bestPocket(
      cue: const Vec2(60, 30),
      object: tableCenter,
      others: blockers,
    );
    expect(best, isNull);
  });

  group('so sánh hai cú', () {
    ShotGeometry shot(Pocket pocket, double angle, Vec2 object) => ShotGeometry(
          cue: Vec2.zero,
          object: object,
          pocket: pocket,
          ghost: object,
          objectDir: const Vec2(1, 0),
          tangentDir: Vec2.zero,
          aimDir: const Vec2(1, 0),
          angle: angle,
        );

    test('góc nhỏ hơn thắng', () {
      expect(
        compareShots(shot(Pocket.topLeft, 10, tableCenter),
            shot(Pocket.topRight, 20, tableCenter)),
        lessThan(0),
      );
    });

    test('hoà góc thì lỗ gần bi mục tiêu hơn thắng', () {
      const nearLeft = Vec2(40, 40);
      expect(
        compareShots(shot(Pocket.topLeft, 10, nearLeft),
            shot(Pocket.topRight, 10, nearLeft)),
        lessThan(0),
      );
    });

    test('hoà hết thì bằng nhau — bestPocket giữ lỗ đứng trước trong enum',
        () {
      expect(
        compareShots(shot(Pocket.topLeft, 10, tableCenter),
            shot(Pocket.topRight, 10, tableCenter)),
        0,
      );
    });
  });

  test('lưới bố cục có đủ cú để các test tính chất có ý nghĩa', () {
    expect(gridShots().length, greaterThan(300));
  });
}
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/pocket_choice_test.dart`
Expected: FAIL. `pocket_choice.dart` is missing.

- [ ] **Step 4: Implement**

`lib/domain/table_geometry/pocket_choice.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Âm khi [a] tốt hơn [b]: góc cắt nhỏ hơn, hoà góc thì lỗ gần bi mục
/// tiêu hơn. Bằng 0 khi hoà hết.
int compareShots(
  ShotGeometry a,
  ShotGeometry b, {
  TableSpec table = TableSpec.nineFoot,
}) {
  final byAngle = a.angle.compareTo(b.angle);
  if (byAngle != 0) return byAngle;
  return a.object
      .distanceTo(table.pocketPosition(a.pocket))
      .compareTo(b.object.distanceTo(table.pocketPosition(b.pocket)));
}

/// Lỗ dễ nhất cho bi mục tiêu — Priority 1 của Planner (PRD §5.1).
///
/// Thử cả sáu lỗ, bỏ mọi cú không đánh được, giữ cú tốt nhất theo
/// [compareShots]. Chỉ thay khi tốt hơn hẳn, nên hoà hết thì giữ lỗ
/// đứng trước trong [Pocket.values] — kết quả luôn tất định.
ShotGeometry? bestPocket({
  required Vec2 cue,
  required Vec2 object,
  Iterable<Vec2> others = const [],
  TableSpec table = TableSpec.nineFoot,
}) {
  ShotGeometry? best;
  for (final pocket in Pocket.values) {
    final result = evaluateShot(
      cue: cue,
      object: object,
      pocket: pocket,
      others: others,
      table: table,
    );
    if (result is! Makeable) continue;
    if (best == null || compareShots(result.geometry, best, table: table) < 0) {
      best = result.geometry;
    }
  }
  return best;
}
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/table_geometry/pocket_choice.dart test/domain/table_geometry/pocket_choice_test.dart test/support/table_layouts.dart
git commit -m "Choose the easiest open pocket, deterministically

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Strokes, and the cue-ball path off the rails

**Files:**
- Create: `lib/domain/table_geometry/stroke.dart`, `lib/domain/table_geometry/cue_ball_path.dart`
- Test: `test/domain/table_geometry/cue_ball_path_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `enum Stroke { stun, draw, follow }`, `enum SpinSide { left, right }`, `const tipWidth = 1.25`, `const miscueTips = 2.0`, `const powerPresets = <double>[40, 70, 95]`
  - `class SideSpin { const SideSpin(SpinSide side, double tips); const SideSpin.none(); SpinSide? side; double tips; static const all (7 levels: none, left 0.5/1/2, right 0.5/1/2); isNone; risksMiscue }`
  - `const maxTravel = 254.0`, `const rollCarry = 0.5`, `const spinDegPerRadius = 20.0`
  - `sealed class PathSegment { Vec2 start; Vec2 end; Vec2 pointAt(double t); PathSegment splitAt(double t) }`, `final class Straight(Vec2 start, Vec2 end)`, `final class Curve(Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3)`
  - `class CueBallPath { List<PathSegment> segments; Vec2 end; Vec2? railHit; Vec2? reboundDir; Pocket? scratch; bool get bankUsed }`
  - `CueBallPath simulateCueBall(ShotGeometry g, {required Stroke stroke, required double power, SideSpin spin = const SideSpin.none(), TableSpec table = TableSpec.nineFoot})`

This task writes the full `simulateCueBall`, but its tests cover only the no-rail branch. Task 5 tests Dội băng and áp phê, and Task 6 tests Chết cái. They all live in one function because they share the segment list; the tasks only split the review.

- [ ] **Step 1: Write the failing tests**

`test/domain/table_geometry/cue_ball_path_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const power = 20.0;
  const travel = maxTravel * power / 100;

  CueBallPath run(ShotGeometry g, Stroke stroke, {double p = power}) =>
      simulateCueBall(g, stroke: stroke, power: p);

  group('cú thẳng — PRD cho trô/cu lê đứng im, spec sửa bằng thành phần cos',
      () {
    final g = geometryFor(tableCenter, Pocket.topRight, 0);

    test('đánh đứng bi dừng ngay tại bi ảo', () {
      final path = run(g, Stroke.stun);
      expect(path.end.distanceTo(g.ghost), lessThan(1e-6));
      expect(path.bankUsed, isFalse);
      expect(path.scratch, isNull);
    });

    test('cu lê đi thẳng theo bi mục tiêu', () {
      final moved = run(g, Stroke.follow).end - g.ghost;
      expect(moved.cross(g.objectDir), closeTo(0, 1e-9));
      expect(moved.dot(g.objectDir), closeTo(rollCarry * travel, 1e-9));
    });

    test('trô lùi thẳng về', () {
      final moved = run(g, Stroke.draw).end - g.ghost;
      expect(moved.cross(g.objectDir), closeTo(0, 1e-9));
      expect(moved.dot(g.objectDir), closeTo(-rollCarry * travel, 1e-9));
    });
  });

  group('cú cắt 40°', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 40);

    test('đánh đứng bi đi thẳng theo đường tiếp tuyến', () {
      final path = run(g, Stroke.stun);
      expect(path.segments.single, isA<Straight>());
      final moved = path.end - g.ghost;
      expect(moved.cross(g.tangentDir), closeTo(0, 1e-9));
      expect(moved.length, closeTo(travel * 0.6427876097, 1e-6)); // sin 40°
    });

    test('cu lê cong về phía trước, trô cong về phía sau', () {
      final follow = run(g, Stroke.follow);
      final draw = run(g, Stroke.draw);
      expect((follow.end - g.ghost).dot(g.objectDir), greaterThan(0));
      expect((draw.end - g.ghost).dot(g.objectDir), lessThan(0));

      final curve = follow.segments.single as Curve;
      expect(curve.p0, g.ghost);
      expect(curve.p3, follow.end);
      // Rời bi ảo theo đường tiếp tuyến rồi mới cong.
      expect((curve.p1 - curve.p0).normalized.cross(g.tangentDir),
          closeTo(0, 1e-9));
      expect((curve.p1 - curve.p0).dot(g.tangentDir), greaterThan(0));
    });
  });

  test('cắt đường cong tại t giữ nguyên điểm đầu và trúng điểm giữa đường',
      () {
    const c = Curve(Vec2(0, 0), Vec2(10, 0), Vec2(20, 10), Vec2(20, 20));
    final half = c.splitAt(0.5);
    expect(half.p0, c.p0);
    expect(half.p3.distanceTo(c.pointAt(0.5)), lessThan(1e-12));
    expect(c.splitAt(1).p3, c.p3);
    expect(c.pointAt(1), c.p3);
  });

  group('tính chất trên cả lưới bố cục', () {
    final shots = gridShots().toList();

    test('đường đi liền mạch, kết thúc trong bàn, end là điểm cuối thật', () {
      for (final g in shots) {
        for (final stroke in Stroke.values) {
          for (final p in powerPresets) {
            final path = run(g, stroke, p: p);
            final where = '${g.cue}→${g.object} $stroke $p';
            expect(path.segments.first.start, g.ghost, reason: where);
            for (var i = 0; i + 1 < path.segments.length; i++) {
              expect(path.segments[i].end, path.segments[i + 1].start,
                  reason: where);
            }
            expect(path.end, path.segments.last.end, reason: where);
            if (path.scratch == null) {
              expect(table.contains(path.end), isTrue, reason: where);
            }
          }
        }
      }
    });

    test('điểm điều khiển của đường cong không bao giờ ra ngoài băng', () {
      for (final g in shots) {
        for (final stroke in Stroke.values) {
          for (final p in powerPresets) {
            for (final seg in run(g, stroke, p: p).segments) {
              if (seg is Curve) {
                expect(table.contains(seg.p1) && table.contains(seg.p2),
                    isTrue,
                    reason: '${g.cue}→${g.object} $stroke $p');
              }
            }
          }
        }
      }
    });
  });

  test('SideSpin: bảy mức, 2 đầu cơ là nguy cơ trượt cơ', () {
    expect(SideSpin.all, hasLength(7));
    expect(SideSpin.all.first, const SideSpin.none());
    expect(const SideSpin(SpinSide.right, 2).risksMiscue, isTrue);
    expect(const SideSpin(SpinSide.right, 1).risksMiscue, isFalse);
    expect(const SideSpin(SpinSide.left, 1) == const SideSpin(SpinSide.left, 1),
        isTrue);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/cue_ball_path_test.dart`
Expected: FAIL. The imports are missing.

- [ ] **Step 3: Implement `stroke.dart`**

```dart
/// Ba kiểu đánh theo trục dọc: đứng · trô · cu lê.
enum Stroke { stun, draw, follow }

enum SpinSide { left, right }

/// Bề rộng đầu cơ chuẩn, cm (giữa khoảng 12.2–12.8 mm).
const tipWidth = 1.25;

/// Từ mức lệch này trở lên thì cảnh báo trượt cơ: 2 đầu cơ ≈ 0.87R,
/// quá giới hạn thường gặp 0.5–0.6R.
const miscueTips = 2.0;

/// Ba mức lực trên màn — khớp `POWER_CANDIDATES` của Planner, để điều
/// người chơi thấy ở đây đúng là điều Planner sẽ gợi ý.
const powerPresets = <double>[40, 70, 95];

/// Áp phê, đo bằng số đầu cơ lệch từ tâm bi cái tới tâm đầu cơ.
///
/// Người chơi không đặt đầu cơ chính xác tới milimét được, nhưng tự
/// đối chiếu được "lệch một đầu cơ" bằng mắt — nên chỉ có các mức này.
class SideSpin {
  const SideSpin(SpinSide this.side, this.tips) : assert(tips > 0);
  const SideSpin.none()
      : side = null,
        tips = 0;

  final SpinSide? side;
  final double tips;

  static const all = <SideSpin>[
    SideSpin.none(),
    SideSpin(SpinSide.left, 0.5),
    SideSpin(SpinSide.left, 1),
    SideSpin(SpinSide.left, 2),
    SideSpin(SpinSide.right, 0.5),
    SideSpin(SpinSide.right, 1),
    SideSpin(SpinSide.right, 2),
  ];

  bool get isNone => side == null;
  bool get risksMiscue => tips >= miscueTips;

  @override
  bool operator ==(Object other) =>
      other is SideSpin && other.side == side && other.tips == tips;

  @override
  int get hashCode => Object.hash(side, tips);

  @override
  String toString() => 'SideSpin($side, $tips)';
}
```

- [ ] **Step 4: Implement `cue_ball_path.dart`**

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

// Hằng số khởi điểm — chỉnh bằng mắt trên màn mô phỏng (spec mục 3).

/// Quãng bi cái đi ở lực 100%, cm. Thay `260 px` của prototype.
const maxTravel = 254.0;

/// Tỉ lệ thành phần dọc đường bi mục tiêu của trô/cu lê.
const rollCarry = 0.5;

/// Góc bật băng đổi thêm mỗi một bán kính lệch tâm, độ.
const spinDegPerRadius = 20.0;

/// Góc bật không vượt quá gần song song với băng.
const _maxReboundDeg = 89.0;

sealed class PathSegment {
  const PathSegment();
  Vec2 get start;
  Vec2 get end;
  Vec2 pointAt(double t);

  /// Phần đầu của đoạn, từ 0 tới [t].
  PathSegment splitAt(double t);
}

final class Straight extends PathSegment {
  const Straight(this.start, this.end);

  @override
  final Vec2 start;
  @override
  final Vec2 end;

  @override
  Vec2 pointAt(double t) => start + (end - start) * t;

  @override
  Straight splitAt(double t) => Straight(start, pointAt(t));
}

/// Bézier bậc ba.
final class Curve extends PathSegment {
  const Curve(this.p0, this.p1, this.p2, this.p3);

  final Vec2 p0;
  final Vec2 p1;
  final Vec2 p2;
  final Vec2 p3;

  @override
  Vec2 get start => p0;
  @override
  Vec2 get end => p3;

  @override
  Vec2 pointAt(double t) {
    if (t == 1) return p3;
    final s = 1 - t;
    return p0 * (s * s * s) +
        p1 * (3 * s * s * t) +
        p2 * (3 * s * t * t) +
        p3 * (t * t * t);
  }

  @override
  Curve splitAt(double t) {
    final a = _lerp(p0, p1, t);
    final b = _lerp(p1, p2, t);
    final c = _lerp(p2, p3, t);
    final d = _lerp(a, b, t);
    final e = _lerp(b, c, t);
    return Curve(p0, a, d, _lerp(d, e, t));
  }
}

Vec2 _lerp(Vec2 a, Vec2 b, double t) => a + (b - a) * t;

/// Đường bi cái sau va chạm.
class CueBallPath {
  const CueBallPath({
    required this.segments,
    required this.end,
    this.railHit,
    this.reboundDir,
    this.scratch,
  });

  /// Các đoạn nối liền nhau, bắt đầu tại bi ảo.
  final List<PathSegment> segments;

  /// Điểm bi cái dừng. Planner dùng đúng đối tượng này làm `cbFrom` của
  /// bước sau — không tính lại.
  final Vec2 end;

  /// Điểm chạm băng khi dội băng; null khi không chạm băng.
  final Vec2? railHit;

  /// Hướng bật ra sau khi chạm băng, đã tính áp phê.
  final Vec2? reboundDir;

  /// Lỗ bi cái rơi vào (chết cái); null khi không rơi.
  final Pocket? scratch;

  bool get bankUsed => railHit != null;
}

enum _Wall {
  left(Vec2(-1, 0)),
  right(Vec2(1, 0)),
  top(Vec2(0, -1)),
  bottom(Vec2(0, 1));

  const _Wall(this.outward);

  /// Pháp tuyến hướng từ bi ra băng.
  final Vec2 outward;

  bool get isVertical => this == left || this == right;
}

/// Đường bi cái sau khi chạm bi mục tiêu (spec mục 4.4–4.7).
CueBallPath simulateCueBall(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  TableSpec table = TableSpec.nineFoot,
}) {
  final travel = maxTravel * power / 100;
  final theta = g.angle * math.pi / 180;
  final along = g.tangentDir * (travel * math.sin(theta));
  final rollSign = switch (stroke) {
    Stroke.stun => 0.0,
    Stroke.follow => 1.0,
    Stroke.draw => -1.0,
  };
  // Lệch khỏi PRD (quyết định 9): PRD cho quãng đường tỉ lệ sin, nên
  // cú thẳng thì trô/cu lê cũng đứng im. Thành phần cos theo đường bi
  // mục tiêu giữ cho hai kỹ thuật này đúng bản chất ở cú thẳng.
  final roll =
      g.objectDir * (rollSign * rollCarry * travel * math.cos(theta));
  final ghost = g.ghost;
  final target = ghost + along + roll;

  final segments = <PathSegment>[];
  Vec2? railHit;
  Vec2? reboundDir;

  if (table.contains(target)) {
    segments.add(_leg(ghost, along, roll, table));
  } else {
    // Dội băng: bắn theo hướng bi ảo → điểm dừng chứ không theo tiếp
    // tuyến như PRD §5.2, để tính được cả thành phần dọc của trô/cu lê.
    final chord = target - ghost;
    final total = chord.length;
    final dir = chord.normalized;
    final (hit, wall) = _firstRailHit(ghost, dir, table);
    railHit = hit;
    final rebound = _applySpin(_reflect(dir, wall), wall, spin, table);
    reboundDir = rebound;
    // Hai đoạn tách biệt, không bao giờ gộp thành một đường cong.
    segments.add(Straight(ghost, hit));

    final remaining = total - ghost.distanceTo(hit);
    final second =
        _leg(hit, rebound * remaining, roll * (remaining / total), table);
    if (table.contains(second.end)) {
      segments.add(second);
    } else {
      // PRD §8: tối đa một lần dội — chạm băng thứ hai thì dừng ở đó.
      final (stop, _) =
          _firstRailHit(hit, (second.end - hit).normalized, table);
      segments.add(Straight(hit, stop));
    }
  }

  final cut = _truncateAtScratch(segments, table);
  if (cut.pocket == null) {
    return CueBallPath(
      segments: segments,
      end: segments.last.end,
      railHit: railHit,
      reboundDir: reboundDir,
    );
  }
  // Lọt lỗ trước khi tới băng thì không có cú bật nào.
  final dropsBeforeRail = railHit != null && cut.index == 0;
  return CueBallPath(
    segments: cut.segments,
    end: cut.segments.last.end,
    railHit: dropsBeforeRail ? null : railHit,
    reboundDir: dropsBeforeRail ? null : reboundDir,
    scratch: cut.pocket,
  );
}

/// Một chặng: đi thẳng [straight] rồi cong thêm [bend] (trô/cu lê).
///
/// Bézier tương đương đường bậc hai có điểm điều khiển ở cuối phần đi
/// thẳng: rời [start] theo hướng [straight], tới đích theo hướng [bend].
/// Điểm điều khiển kẹp vào bàn nên đường cong không xuyên băng.
PathSegment _leg(Vec2 start, Vec2 straight, Vec2 bend, TableSpec table) {
  final q = start + straight;
  final end = q + bend;
  if (straight.isZero || bend.isZero) return Straight(start, end);
  return Curve(
    start,
    table.clamp(start + (q - start) * (2 / 3)),
    table.clamp(end + (q - end) * (2 / 3)),
    end,
  );
}

/// Điểm đầu tiên tia [from] + s·[dir] chạm biên tâm bi, và băng nào.
///
/// Toạ độ chạm được gán đúng bằng biên, nên điểm chạm nằm chính xác
/// trên băng (PRD §7 ca 4), không lệch vì số học.
(Vec2, _Wall) _firstRailHit(Vec2 from, Vec2 dir, TableSpec table) {
  final sx = dir.x > 0
      ? (table.maxX - from.x) / dir.x
      : dir.x < 0
          ? (table.minX - from.x) / dir.x
          : double.infinity;
  final sy = dir.y > 0
      ? (table.maxY - from.y) / dir.y
      : dir.y < 0
          ? (table.minY - from.y) / dir.y
          : double.infinity;

  if (sx <= sy) {
    final y = clampRange(from.y + dir.y * sx, table.minY, table.maxY);
    return dir.x > 0
        ? (Vec2(table.maxX, y), _Wall.right)
        : (Vec2(table.minX, y), _Wall.left);
  }
  final x = clampRange(from.x + dir.x * sy, table.minX, table.maxX);
  return dir.y > 0
      ? (Vec2(x, table.maxY), _Wall.bottom)
      : (Vec2(x, table.minY), _Wall.top);
}

/// Góc tới bằng góc phản xạ: trục chạm đổi dấu.
Vec2 _reflect(Vec2 dir, _Wall wall) =>
    wall.isVertical ? Vec2(-dir.x, dir.y) : Vec2(dir.x, -dir.y);

/// Áp phê đổi hướng bật băng (spec mục 4.6).
///
/// Áp phê phải làm bi cái quay ngược chiều kim đồng hồ khi nhìn từ trên
/// xuống, nên ma sát ở điểm chạm đẩy bi về **bên phải của hướng ra
/// băng**. Áp phê trái thì ngược lại. Xoay hướng bật về phía lực đẩy
/// đó: cùng chiều bi đang chạy dọc băng là thuận (mở góc), ngược lại là
/// nghịch (đóng góc).
Vec2 _applySpin(Vec2 rebound, _Wall wall, SideSpin spin, TableSpec table) {
  final side = spin.side;
  if (side == null) return rebound;
  final inward = -wall.outward;
  final push = side == SpinSide.right
      ? wall.outward.rightNormal
      : -wall.outward.rightNormal;
  final sense = inward.cross(push).sign;
  final delta = spinDegPerRadius *
      (spin.tips * tipWidth / table.radius) *
      math.pi /
      180;
  final limit = _maxReboundDeg * math.pi / 180;
  final alpha = clampRange(
    inward.signedAngleTo(rebound) + sense * delta,
    -limit,
    limit,
  );
  return inward.rotated(alpha);
}

typedef _Cut = ({List<PathSegment> segments, Pocket? pocket, int index});

/// Cắt đường đi tại điểm đầu tiên tâm bi cái lọt vùng một lỗ.
///
/// Lấy mẫu mỗi bước ≤ R/2 theo độ dài đa giác điều khiển, vốn không
/// ngắn hơn đường cong — nên không lọt qua vùng lỗ giữa hai mẫu.
_Cut _truncateAtScratch(List<PathSegment> segments, TableSpec table) {
  final step = table.radius / 2;
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final n = math.max(1, (_controlLength(seg) / step).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      final p = seg.pointAt(t);
      for (final pocket in Pocket.values) {
        if (p.distanceTo(table.pocketPosition(pocket)) <=
            table.captureRadius(pocket)) {
          return (
            segments: [...segments.take(i), seg.splitAt(t)],
            pocket: pocket,
            index: i,
          );
        }
      }
    }
  }
  return (segments: segments, pocket: null, index: -1);
}

double _controlLength(PathSegment seg) => switch (seg) {
      Straight(:final start, :final end) => start.distanceTo(end),
      Curve(:final p0, :final p1, :final p2, :final p3) =>
        p0.distanceTo(p1) + p1.distanceTo(p2) + p2.distanceTo(p3),
    };
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/`
Expected: PASS. If a grid property fails, print the `reason` layout and fix the geometry. Never shrink the grid to make it pass.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/table_geometry test/domain/table_geometry
git commit -m "Simulate the cue-ball path for đứng, trô and cu lê, keeping trô and cu lê alive on straight shots

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Dội băng and áp phê

**Files:**
- Test: `test/domain/table_geometry/bank_spin_test.dart`
- Modify only if a test fails: `lib/domain/table_geometry/cue_ball_path.dart`

**Interfaces:**
- Consumes: `simulateCueBall`, `CueBallPath.railHit`, `CueBallPath.reboundDir`, `gridShots`, `SideSpin`.

- [ ] **Step 1: Write the tests**

`test/domain/table_geometry/bank_spin_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final shots = gridShots().toList();

  bool onBounds(Vec2 p) =>
      p.x == table.minX || p.x == table.maxX || p.y == table.minY || p.y == table.maxY;

  /// Pháp tuyến hướng ra băng tại điểm chạm; null khi chạm đúng góc.
  Vec2? outwardAt(Vec2 hit) {
    final onX = hit.x == table.minX || hit.x == table.maxX;
    final onY = hit.y == table.minY || hit.y == table.maxY;
    if (onX == onY) return null;
    if (onX) return Vec2(hit.x == table.maxX ? 1 : -1, 0);
    return Vec2(0, hit.y == table.maxY ? 1 : -1);
  }

  /// Mọi cú dội băng không chết cái trên lưới, đánh đứng bi lực 95%.
  final banked = [
    for (final g in shots)
      if (simulateCueBall(g, stroke: Stroke.stun, power: 95)
          case final path when path.bankUsed && path.scratch == null)
        (g: g, path: path),
  ];

  /// Cú bật gần song song với băng: áp phê bị kẹp ở giới hạn 89°, nên
  /// hướng đổi không còn nói được gì về chiều của áp phê.
  bool grazing(Vec2 hit, Vec2 rebound) {
    final out = outwardAt(hit);
    if (out == null) return true;
    final fromNormal = (-out).signedAngleTo(rebound).abs() * 180 / math.pi;
    return fromNormal > 87;
  }

  test('lưới có đủ cú dội băng để test có ý nghĩa', () {
    expect(banked.length, greaterThan(30));
  });

  test('điểm chạm băng nằm đúng trên biên, đoạn đầu là đường thẳng', () {
    for (final (:g, :path) in banked) {
      expect(onBounds(path.railHit!), isTrue, reason: '${g.cue}→${g.object}');
      final first = path.segments.first;
      expect(first, isA<Straight>());
      expect(first.start, g.ghost);
      expect(first.end, path.railHit);
      expect(path.segments.length, lessThanOrEqualTo(2));
    }
  });

  test('không áp phê thì góc tới bằng góc phản xạ', () {
    for (final (:g, :path) in banked) {
      final hit = path.railHit!;
      final out = outwardAt(hit);
      if (out == null) continue;
      final incoming = (hit - g.ghost).normalized;
      final expected = out.x != 0
          ? Vec2(-incoming.x, incoming.y)
          : Vec2(incoming.x, -incoming.y);
      expect(path.reboundDir!.distanceTo(expected), lessThan(1e-9),
          reason: '${g.cue}→${g.object}');
    }
  });

  test('áp phê phải đẩy về bên phải hướng ra băng, áp phê trái ngược lại',
      () {
    for (final (:g, :path) in banked) {
      final out = outwardAt(path.railHit!);
      if (out == null || grazing(path.railHit!, path.reboundDir!)) continue;
      final none = path.reboundDir!;
      final right = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.right, 1))
          .reboundDir;
      final left = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.left, 1))
          .reboundDir;
      // Rơi lỗ trước băng với áp phê này thì không còn hướng bật để so.
      if (right == null || left == null) continue;
      expect((right - none).dot(out.rightNormal), greaterThan(0),
          reason: '${g.cue}→${g.object}');
      expect((left - none).dot(out.rightNormal), lessThan(0),
          reason: '${g.cue}→${g.object}');
    }
  });

  test('càng lệch nhiều đầu cơ, góc bật càng đổi nhiều', () {
    double turn(Vec2 a, Vec2 b) => a.signedAngleTo(b).abs();
    var strictlyGrew = 0;
    for (final (:g, :path) in banked) {
      if (grazing(path.railHit!, path.reboundDir!)) continue;
      final none = path.reboundDir!;
      final dirs = [
        for (final tips in [0.5, 1.0, 2.0])
          simulateCueBall(g,
                  stroke: Stroke.stun,
                  power: 95,
                  spin: SideSpin(SpinSide.right, tips))
              .reboundDir,
      ];
      if (dirs.contains(null)) continue;
      final turns = [for (final d in dirs) turn(none, d!)];
      expect(turns[0], lessThanOrEqualTo(turns[1] + 1e-12));
      expect(turns[1], lessThanOrEqualTo(turns[2] + 1e-12));
      if (turns[2] > turns[0] + 1e-6) strictlyGrew++;
    }
    expect(strictlyGrew, greaterThan(0));
  });

  test('góc bật không bao giờ quá song song với băng', () {
    for (final (:g, :path) in banked) {
      final out = outwardAt(path.railHit!);
      if (out == null) continue;
      final rebound = simulateCueBall(g,
              stroke: Stroke.stun,
              power: 95,
              spin: const SideSpin(SpinSide.right, 2))
          .reboundDir;
      if (rebound == null) continue;
      expect(rebound.dot(-out), greaterThan(math.cos(89.5 * math.pi / 180)));
    }
  });

  test('không chạm băng thì áp phê không đổi đường đi', () {
    for (final g in shots) {
      final plain = simulateCueBall(g, stroke: Stroke.follow, power: 40);
      if (plain.bankUsed) continue;
      final spun = simulateCueBall(g,
          stroke: Stroke.follow,
          power: 40,
          spin: const SideSpin(SpinSide.left, 2));
      expect(spun.end, plain.end, reason: '${g.cue}→${g.object}');
    }
  });

  test('áp phê không đổi đoạn trước khi chạm băng', () {
    for (final (:g, :path) in banked) {
      final spun = simulateCueBall(g,
          stroke: Stroke.stun,
          power: 95,
          spin: const SideSpin(SpinSide.left, 1));
      // Rơi lỗ trước băng thì không có điểm chạm để so.
      if (spun.railHit != null) expect(spun.railHit, path.railHit);
    }
  });
}
```

- [ ] **Step 2: Run them**

Run: `"$FLUTTER" test test/domain/table_geometry/bank_spin_test.dart`
Expected: PASS against the Task 4 implementation.

If a test fails, it has found a real defect. Fix `cue_ball_path.dart` and keep the test as written. A failure in the áp phê direction test means the `_applySpin` sign is wrong. The physics is in its doc comment: right english → push to the right of the outward rail normal.

- [ ] **Step 3: Revert-check the spin sign.** The direction test must be able to fail. Temporarily swap `wall.outward.rightNormal` and `-wall.outward.rightNormal` in `_applySpin`, run the test, and confirm it goes RED. Then restore the code and confirm it is GREEN again.

- [ ] **Step 4: Commit**

```bash
git add test/domain/table_geometry/bank_spin_test.dart lib/domain/table_geometry/cue_ball_path.dart
git commit -m "Pin Dội băng and áp phê: exact rail contact, reflection, and which way side spin turns the rebound

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Chết cái, and the margin before it

**Files:**
- Create: `lib/domain/table_geometry/scratch.dart` (this task adds only `ScratchRisk` and `scratchMargin`)
- Test: `test/domain/table_geometry/scratch_test.dart`

**Interfaces:**
- Consumes: `simulateCueBall`, `CueBallPath.scratch`.
- Produces: `class ScratchRisk { const ScratchRisk({required double power, required Pocket pocket}) }` and `ScratchRisk? scratchMargin(ShotGeometry g, {required Stroke stroke, required double power, SideSpin spin = const SideSpin.none(), TableSpec table = TableSpec.nineFoot})`.

- [ ] **Step 1: Write the failing tests**

`test/domain/table_geometry/scratch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final corner = table.pocketPosition(Pocket.topRight);
  // Bi mục tiêu sát lỗ góc trên phải, cú thẳng: cu lê đi theo bi vào lỗ.
  final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);

  test('cu lê theo bi vào lỗ là chết cái, và rơi trước khi kịp chạm băng',
      () {
    final path = simulateCueBall(g, stroke: Stroke.follow, power: 95);
    expect(path.scratch, Pocket.topRight);
    expect(path.bankUsed, isFalse);
    expect(path.end.distanceTo(corner), lessThanOrEqualTo(cornerCapture));
  });

  test('đánh đứng bi cú thẳng thì bi cái dừng tại chỗ, không chết cái', () {
    expect(simulateCueBall(g, stroke: Stroke.stun, power: 95).scratch, isNull);
  });

  test('biên lực chết cái: mức lực nguyên đầu tiên đưa bi cái vào vùng lỗ',
      () {
    // Cú thẳng cu lê đi dọc đường lỗ được rollCarry·maxTravel·p/100 cm.
    final need = g.ghost.distanceTo(corner) - cornerCapture;
    final expected = (need / (rollCarry * maxTravel / 100)).ceil();

    final risk = scratchMargin(g, stroke: Stroke.follow, power: 10)!;
    expect(risk.pocket, Pocket.topRight);
    expect(risk.power, expected < 10 ? 10 : expected);
  });

  test('không chết cái tới 100% thì không có biên', () {
    expect(scratchMargin(g, stroke: Stroke.stun, power: 40), isNull);
  });

  test('ngay mức chọn đã chết cái thì biên là chính mức đó', () {
    final risk = scratchMargin(g, stroke: Stroke.follow, power: 95)!;
    expect(risk.power, 95);
  });

  test('trên lưới: chết cái thì điểm dừng nằm trong vùng lỗ đó', () {
    for (final shot in gridShots()) {
      for (final stroke in Stroke.values) {
        final path = simulateCueBall(shot, stroke: stroke, power: 95);
        final pocket = path.scratch;
        if (pocket == null) continue;
        expect(
          path.end.distanceTo(table.pocketPosition(pocket)),
          lessThanOrEqualTo(table.captureRadius(pocket)),
          reason: '${shot.cue}→${shot.object} $stroke',
        );
      }
    }
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/scratch_test.dart`
Expected: FAIL. `scratch.dart` is missing.

- [ ] **Step 3: Implement** `lib/domain/table_geometry/scratch.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Mức lực đầu tiên làm bi cái chết cái, và rơi lỗ nào.
class ScratchRisk {
  const ScratchRisk({required this.power, required this.pocket});
  final double power;
  final Pocket pocket;
}

/// Tăng lực từ [power] lên từng 1% tới 100%, trả mức đầu tiên chết cái.
///
/// Ngay [power] đã chết cái thì trả chính [power] (biên bằng 0). Không
/// mức nào chết cái thì null. Chỉ xét **dư** lực: thiếu lực làm đường
/// đi ngắn lại, hiếm khi chạm tới lỗ (spec mục 1, ngoài phạm vi).
ScratchRisk? scratchMargin(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  TableSpec table = TableSpec.nineFoot,
}) {
  for (var p = power; p <= 100; p += 1) {
    final pocket =
        simulateCueBall(g, stroke: stroke, power: p, spin: spin, table: table)
            .scratch;
    if (pocket != null) return ScratchRisk(power: p, pocket: pocket);
  }
  return null;
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_geometry/scratch.dart test/domain/table_geometry/scratch_test.dart
git commit -m "Detect Chết cái and find the power at which overhitting starts to scratch

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Advice from scanning áp phê

**Files:**
- Modify: `lib/domain/table_geometry/scratch.dart`
- Test: `test/domain/table_geometry/advice_test.dart`

**Interfaces:**
- Consumes: `scratchMargin`, `SideSpin.all`.
- Produces:
  - `const overhitBand = 15.0`
  - `class SpinOutcome { const SpinOutcome({Pocket? scratchAtPower, ScratchRisk? risk}) }`
  - `sealed class Advice`; `final class AddSpinToAvoid({required SideSpin from, required SideSpin to, required Pocket pocket})`; `final class NoSpinAvoids({required Pocket pocket})`; `final class OverhitRisk({required double margin, required double fromPower, required Pocket pocket, SideSpin? saferSpin})`; `final class SpinCeiling({required SpinSide side, required double maxSafeTips, required Pocket pocket})`
  - `List<Advice> chooseAdvice({required double power, required SideSpin chosen, required Map<SideSpin, SpinOutcome> outcomes})`: a pure function holding the rules, with at most 2 items.
  - `List<Advice> scratchAdvice(ShotGeometry g, {required Stroke stroke, required double power, required SideSpin spin, TableSpec table = TableSpec.nineFoot})`

- [ ] **Step 1: Write the failing tests**

`test/domain/table_geometry/advice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

import '../../support/table_layouts.dart';

void main() {
  const none = SideSpin.none();
  const left05 = SideSpin(SpinSide.left, 0.5);
  const left1 = SideSpin(SpinSide.left, 1);
  const right05 = SideSpin(SpinSide.right, 0.5);
  const right1 = SideSpin(SpinSide.right, 1);
  const right2 = SideSpin(SpinSide.right, 2);
  const pocket = Pocket.topRight;

  /// Mọi mức an toàn, trừ các mức ghi đè.
  Map<SideSpin, SpinOutcome> outcomes(Map<SideSpin, SpinOutcome> overrides) =>
      {for (final s in SideSpin.all) s: overrides[s] ?? const SpinOutcome()};

  const drops = SpinOutcome(
    scratchAtPower: pocket,
    risk: ScratchRisk(power: 70, pocket: pocket),
  );
  SpinOutcome riskAt(double p) =>
      SpinOutcome(risk: ScratchRisk(power: p, pocket: pocket));

  group('mức đang chọn chết cái tại lực chọn', () {
    test('khuyên mức an toàn ít đầu cơ nhất', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({
          none: drops,
          left05: drops,
          right05: drops,
          left1: riskAt(80), // dư 10% là chết cái: chưa an toàn
          SideSpin(SpinSide.left, 2): drops,
        }),
      );
      expect(advice.single, isA<AddSpinToAvoid>()
          .having((a) => a.to, 'to', right1)
          .having((a) => a.from, 'from', none)
          .having((a) => a.pocket, 'pocket', pocket));
    });

    test('hoà số đầu cơ thì giữ cùng phía đang chọn', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: right05,
        outcomes: outcomes({none: drops, left05: drops, right05: drops}),
      );
      expect((advice.single as AddSpinToAvoid).to, right1);
    });

    test('không mức nào cứu được thì nói thẳng', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: {for (final s in SideSpin.all) s: drops},
      );
      expect(advice.single,
          isA<NoSpinAvoids>().having((a) => a.pocket, 'pocket', pocket));
    });
  });

  group('mức đang chọn không chết cái tại lực chọn', () {
    test('dư lực trong biên 15% thì cảnh báo, kèm mức áp phê an toàn tới 100%',
        () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({
          none: riskAt(82),
          left05: riskAt(90),
          right05: riskAt(95),
        }),
      );
      expect(advice.single, isA<OverhitRisk>()
          .having((a) => a.margin, 'margin', 12)
          .having((a) => a.fromPower, 'fromPower', 82)
          .having((a) => a.saferSpin, 'saferSpin', left1));
    });

    test('chết cái chỉ khi dư quá 15% thì không cảnh báo', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: none,
        outcomes: outcomes({none: riskAt(90)}),
      );
      expect(advice, isEmpty);
    });

    test('cùng phía, nhiều đầu cơ hơn thì chết cái: báo trần áp phê', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: right05,
        outcomes: outcomes({
          right2: const SpinOutcome(
            scratchAtPower: Pocket.bottomMiddle,
            risk: ScratchRisk(power: 70, pocket: Pocket.bottomMiddle),
          ),
        }),
      );
      expect(advice.single, isA<SpinCeiling>()
          .having((a) => a.side, 'side', SpinSide.right)
          .having((a) => a.maxSafeTips, 'maxSafeTips', 1)
          .having((a) => a.pocket, 'pocket', Pocket.bottomMiddle));
    });

    test('tối đa hai lời khuyên, theo thứ tự', () {
      final advice = chooseAdvice(
        power: 70,
        chosen: right05,
        outcomes: outcomes({
          right05: riskAt(80),
          right1: drops,
        }),
      );
      expect(advice, hasLength(2));
      expect(advice[0], isA<OverhitRisk>());
      expect(advice[1], isA<SpinCeiling>());
    });
  });

  test('scratchAdvice nối đúng với mô phỏng thật', () {
    var checked = 0;
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 7) {
      final g = shots[i];
      for (final stroke in [Stroke.stun, Stroke.follow]) {
        for (final power in [70.0, 95.0]) {
          for (final a in scratchAdvice(g,
              stroke: stroke, power: power, spin: const SideSpin.none())) {
            checked++;
            switch (a) {
              case AddSpinToAvoid(:final to):
                expect(
                    simulateCueBall(g, stroke: stroke, power: power, spin: to)
                        .scratch,
                    isNull);
                final risk =
                    scratchMargin(g, stroke: stroke, power: power, spin: to);
                expect(risk == null || risk.power - power > overhitBand,
                    isTrue);
              case OverhitRisk(:final fromPower):
                expect(scratchMargin(g, stroke: stroke, power: power)!.power,
                    fromPower);
              case NoSpinAvoids() || SpinCeiling():
                break;
            }
          }
        }
      }
    }
    expect(checked, greaterThan(0),
        reason: 'lưới phải sinh ra ít nhất một lời khuyên để nối dây được kiểm');
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/advice_test.dart`
Expected: FAIL. `chooseAdvice` and the related names are undefined.

- [ ] **Step 3: Implement.** Append to `lib/domain/table_geometry/scratch.dart`:

```dart
/// Biên lực dư cho cảnh báo chết cái — trùng `POWER_JITTER` của PRD.
const overhitBand = 15.0;

/// Kết quả của một mức áp phê tại lực đang chọn.
class SpinOutcome {
  const SpinOutcome({this.scratchAtPower, this.risk});

  /// Lỗ bi cái rơi vào ngay tại lực đang chọn; null khi không rơi.
  final Pocket? scratchAtPower;

  /// Mức lực đầu tiên (≥ lực chọn) làm chết cái; null khi không có.
  final ScratchRisk? risk;
}

/// Lời khuyên là dữ liệu có giá trị tính được; `Vi` ghép thành câu.
sealed class Advice {
  const Advice();
}

/// Mức đang chọn chết cái; đổi sang [to] thì tránh được.
final class AddSpinToAvoid extends Advice {
  const AddSpinToAvoid({required this.from, required this.to, required this.pocket});
  final SideSpin from;
  final SideSpin to;
  final Pocket pocket;
}

/// Mức đang chọn chết cái và không mức áp phê nào cứu được.
final class NoSpinAvoids extends Advice {
  const NoSpinAvoids({required this.pocket});
  final Pocket pocket;
}

/// Dư lực [margin]% (từ [fromPower]%) là chết cái; [saferSpin] (nếu có)
/// an toàn tới 100%.
final class OverhitRisk extends Advice {
  const OverhitRisk({
    required this.margin,
    required this.fromPower,
    required this.pocket,
    this.saferSpin,
  });
  final double margin;
  final double fromPower;
  final Pocket pocket;
  final SideSpin? saferSpin;
}

/// Áp phê [side] quá [maxSafeTips] đầu cơ thì chết cái.
final class SpinCeiling extends Advice {
  const SpinCeiling({required this.side, required this.maxSafeTips, required this.pocket});
  final SpinSide side;
  final double maxSafeTips;
  final Pocket pocket;
}

/// Luật chọn lời khuyên (spec mục 4.8), tách khỏi mô phỏng để test thẳng.
List<Advice> chooseAdvice({
  required double power,
  required SideSpin chosen,
  required Map<SideSpin, SpinOutcome> outcomes,
}) {
  bool safe(SpinOutcome o) =>
      o.scratchAtPower == null &&
      (o.risk == null || o.risk!.power - power > overhitBand);

  final current = outcomes[chosen]!;
  final advice = <Advice>[];

  final dropped = current.scratchAtPower;
  if (dropped != null) {
    final fix = _fewestTips(chosen, outcomes, (s, o) => s != chosen && safe(o));
    advice.add(fix == null
        ? NoSpinAvoids(pocket: dropped)
        : AddSpinToAvoid(from: chosen, to: fix, pocket: dropped));
    return advice;
  }

  final risk = current.risk;
  if (risk != null && risk.power - power <= overhitBand) {
    advice.add(OverhitRisk(
      margin: risk.power - power,
      fromPower: risk.power,
      pocket: risk.pocket,
      saferSpin: _fewestTips(
        chosen,
        outcomes,
        (s, o) => s != chosen && o.scratchAtPower == null && o.risk == null,
      ),
    ));
  }

  final side = chosen.side;
  if (side != null) {
    var maxSafe = chosen.tips;
    for (final s in SideSpin.all) {
      if (s.side != side || s.tips <= chosen.tips) continue;
      final drop = outcomes[s]!.scratchAtPower;
      if (drop != null) {
        advice.add(SpinCeiling(side: side, maxSafeTips: maxSafe, pocket: drop));
        break;
      }
      maxSafe = s.tips;
    }
  }

  return advice.take(2).toList();
}

/// Mức thoả [ok] có ít đầu cơ nhất; hoà thì ưu tiên cùng phía [chosen],
/// rồi theo thứ tự [SideSpin.all].
SideSpin? _fewestTips(
  SideSpin chosen,
  Map<SideSpin, SpinOutcome> outcomes,
  bool Function(SideSpin, SpinOutcome) ok,
) {
  SideSpin? best;
  for (final s in SideSpin.all) {
    if (!ok(s, outcomes[s]!)) continue;
    if (best == null ||
        s.tips < best.tips ||
        (s.tips == best.tips &&
            s.side == chosen.side &&
            best.side != chosen.side)) {
      best = s;
    }
  }
  return best;
}

/// Mô phỏng đủ bảy mức áp phê rồi chọn lời khuyên.
List<Advice> scratchAdvice(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  TableSpec table = TableSpec.nineFoot,
}) {
  final outcomes = {
    for (final s in SideSpin.all)
      s: () {
        final risk = scratchMargin(g,
            stroke: stroke, power: power, spin: s, table: table);
        return SpinOutcome(
          scratchAtPower: risk != null && risk.power == power ? risk.pocket : null,
          risk: risk,
        );
      }(),
  };
  return chooseAdvice(power: power, chosen: spin, outcomes: outcomes);
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_geometry/`
Expected: PASS. If the wiring test finds no advice (`checked == 0`), change the sampled powers or strokes in that test to cover more of the grid; never delete the assertion.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_geometry/scratch.dart test/domain/table_geometry/advice_test.dart
git commit -m "Scan every áp phê level and advise how to avoid Chết cái

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Strings and colours

**Files:**
- Modify: `lib/core/strings/vi.dart`, `lib/core/theme/app_colors.dart`
- Test: `test/core/strings/vi_simulator_test.dart`

**Interfaces:**
- Consumes: the core types from Tasks 2–7.
- Produces, on `Vi`:
  - constants: `simTitle`, `simCardBody`, `simHint`, `simStrokeLabel`, `simPowerLabel`, `simSpinLabel`, `simNoPocket`, `simBankWarning`, `simSpinNoRail`, `simDisclaimer`
  - getter: `simMiscue`
  - functions:
    - `simStroke(Stroke)`, `simPowerPreset(double)`, `simTips(double)`, `simSpinChip(SideSpin)`, `simPocket(Pocket)`, `simBand(DifficultyBand)`, `simUnmakeable(UnmakeableReason)`
    - panel lines: `simPocketLine(Pocket)`, `simAngleLine(double)`, `simBandLine(DifficultyBand)`, `simStrokeLine(Stroke)`, `simPowerLine(double)`, `simSpinLine(SideSpin)`
    - `simScratch(Pocket)`, `simAdvice(Advice)`, `simSummary(ShotResult?, CueBallPath?)`
- Produces, on `AppColors`: `tableFelt`, `tableRail`, `cuePath`, `railHit`, `aimLine`, `ballCue`, `ballObject`.

- [ ] **Step 1: Write the failing tests**

`test/core/strings/vi_simulator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);
  const right2 = SideSpin(SpinSide.right, 2);
  const left1 = SideSpin(SpinSide.left, 1);

  test('thuật ngữ đã chốt với chủ sản phẩm', () {
    expect(Vi.simStroke(Stroke.stun), 'Đánh đứng bi');
    expect(Vi.simStroke(Stroke.draw), 'Đánh trô bi');
    expect(Vi.simStroke(Stroke.follow), 'Đánh cu lê');
    expect(Vi.simStrokeLabel, 'Kiểu đánh');
    expect(Vi.simMiscue, 'Lệch 2 đầu cơ dễ trượt cơ.');
  });

  test('số đầu cơ không có số 0 thừa', () {
    expect(Vi.simTips(0.5), '0.5');
    expect(Vi.simTips(1), '1');
    expect(Vi.simTips(2), '2');
    expect(Vi.simSpinChip(none), 'Không');
    expect(Vi.simSpinChip(right1), 'Phải 1');
    expect(Vi.simSpinLine(const SideSpin(SpinSide.left, 0.5)),
        'Áp phê: trái lệch 0.5 đầu cơ');
  });

  test('lời khuyên dùng đúng chiều ít/nhiều áp phê', () {
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: none, to: right1, pocket: Pocket.topRight)),
      'Ít áp phê thì bi cái chết cái ở lỗ góc trên phải — nên áp phê phải '
      'lệch 1 đầu cơ để đổi góc bật tránh lỗ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: right2, to: right1, pocket: Pocket.topMiddle)),
      'Áp phê nhiều quá, bi cái chết cái ở lỗ giữa trên — giảm còn áp phê '
      'phải lệch 1 đầu cơ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: left1, to: right1, pocket: Pocket.topMiddle)),
      'Áp phê trái làm bi cái chết cái ở lỗ giữa trên — nên đổi sang áp phê '
      'phải lệch 1 đầu cơ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: right1, to: none, pocket: Pocket.topMiddle)),
      'Áp phê đang chọn làm bi cái chết cái ở lỗ giữa trên — đánh không áp '
      'phê thì tránh được.',
    );
  });

  test('cảnh báo dư lực ghép số tính ra', () {
    expect(
      Vi.simAdvice(const OverhitRisk(
        margin: 12,
        fromPower: 82,
        pocket: Pocket.topRight,
        saferSpin: left1,
      )),
      'Nếu đánh quá lực khoảng +12% (từ ~82%), bi cái có thể rơi lỗ góc trên '
      'phải (chết cái). Áp phê trái lệch 1 đầu cơ thì vẫn an toàn tới 100%.',
    );
    expect(
      Vi.simAdvice(const SpinCeiling(
          side: SpinSide.right, maxSafeTips: 0.5, pocket: Pocket.bottomMiddle)),
      'Đừng áp phê phải quá 0.5 đầu cơ — bi cái sẽ rơi lỗ giữa dưới.',
    );
  });

  test('nhãn tóm tắt của bàn', () {
    const g = ShotGeometry(
      cue: Vec2(80, 90),
      object: Vec2(170, 50),
      pocket: Pocket.topRight,
      ghost: Vec2(165, 53),
      objectDir: Vec2(1, 0),
      tangentDir: Vec2(0, 1),
      aimDir: Vec2(1, 0),
      angle: 7.4,
    );
    const path = CueBallPath(
      segments: [Straight(Vec2(165, 53), Vec2(170, 60))],
      end: Vec2(170, 60),
    );
    expect(Vi.simSummary(const Makeable(g), path),
        'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ.');
    expect(Vi.simSummary(null, null),
        'Bàn mô phỏng. Không lỗ nào đánh được từ vị trí này.');
    expect(Vi.simSummary(const Unmakeable(UnmakeableReason.tooThin), null),
        'Bàn mô phỏng. Góc cắt quá lớn (>85°).');
    expect(Vi.simBand(bandFor(7.4)), 'Dễ');
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/core/strings/vi_simulator_test.dart`
Expected: FAIL. The members are undefined.

- [ ] **Step 3: Implement.** Add these imports at the top of `lib/core/strings/vi.dart`, next to the existing domain imports:

```dart
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
```

Then add this block inside `abstract final class Vi`, after the training strings:

```dart
  // Mô phỏng góc cắt — docs/superpowers/specs/2026-10-01-poolcoachai-cut-angle-simulator-design.md.
  // Câu nào có số thì số do lõi table_geometry tính ra; ở đây chỉ ghép chữ.
  static const simTitle = 'Mô phỏng góc cắt';
  static const simCardBody = 'Đặt bi, xem bi ảo, góc cắt và đường đi bi cái.';
  static const simHint = 'Kéo bi để đặt lại, chạm vào lỗ để chọn lỗ khác.';
  static const simStrokeLabel = 'Kiểu đánh';
  static const simPowerLabel = 'Lực';
  static const simSpinLabel = 'Áp phê';
  static const simNoPocket = 'Không lỗ nào đánh được từ vị trí này.';
  static const simBankWarning =
      'Bi cái dội băng — cần canh lực chính xác hơn bình thường.';
  static const simSpinNoRail = 'Áp phê chỉ đổi đường bi cái sau khi chạm băng.';

  /// PRD §6.6 — không được bỏ.
  static const simDisclaimer = 'Lực và đầu cơ là gợi ý định hướng dựa trên '
      'hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, '
      'người chơi vẫn cần tự canh lực thực tế.';

  static String get simMiscue => 'Lệch ${simTips(miscueTips)} đầu cơ dễ trượt cơ.';

  static String simStroke(Stroke stroke) => switch (stroke) {
        Stroke.stun => 'Đánh đứng bi',
        Stroke.draw => 'Đánh trô bi',
        Stroke.follow => 'Đánh cu lê',
      };

  static String simPowerPreset(double power) => switch (power.round()) {
        40 => 'Nhẹ 40%',
        70 => 'Vừa 70%',
        95 => 'Mạnh 95%',
        final n => '$n%',
      };

  /// 0.5 → "0.5", 1 → "1": người chơi nói "lệch 1 đầu cơ", không "1.0".
  static String simTips(double tips) =>
      tips == tips.roundToDouble() ? '${tips.round()}' : '$tips';

  static String _side(SpinSide side) => switch (side) {
        SpinSide.left => 'trái',
        SpinSide.right => 'phải',
      };

  static String simSpinChip(SideSpin spin) => switch (spin.side) {
        null => 'Không',
        SpinSide.left => 'Trái ${simTips(spin.tips)}',
        SpinSide.right => 'Phải ${simTips(spin.tips)}',
      };

  static String _spinLong(SideSpin spin) => switch (spin.side) {
        null => 'không áp phê',
        final side => 'áp phê ${_side(side)} lệch ${simTips(spin.tips)} đầu cơ',
      };

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String simPocket(Pocket pocket) => switch (pocket) {
        Pocket.topLeft => 'góc trên trái',
        Pocket.topMiddle => 'giữa trên',
        Pocket.topRight => 'góc trên phải',
        Pocket.bottomLeft => 'góc dưới trái',
        Pocket.bottomMiddle => 'giữa dưới',
        Pocket.bottomRight => 'góc dưới phải',
      };

  static String simBand(DifficultyBand band) => switch (band) {
        DifficultyBand.easy => 'Dễ',
        DifficultyBand.medium => 'Vừa',
        DifficultyBand.hard => 'Khó',
        DifficultyBand.veryHard => 'Rất khó',
        DifficultyBand.extreme => 'Cực khó',
        DifficultyBand.impossible => 'Không đánh được',
      };

  static String simUnmakeable(UnmakeableReason reason) => switch (reason) {
        UnmakeableReason.overlap => 'Hai bi đang chồng lên nhau.',
        UnmakeableReason.ghostOffTable =>
          'Bi ảo nằm ngoài mặt bàn — bi mục tiêu sát băng, lỗ này không đánh được.',
        UnmakeableReason.tooThin =>
          'Góc cắt quá lớn (>${maxCutAngle.round()}°).',
        UnmakeableReason.cueBlocked => 'Đường bi cái tới bi ảo bị bi khác chắn.',
        UnmakeableReason.objectBlocked =>
          'Đường bi mục tiêu vào lỗ bị bi khác chắn.',
      };

  static String simPocketLine(Pocket pocket) => 'Lỗ: ${simPocket(pocket)}';
  static String simAngleLine(double angle) => 'Góc cắt: ${angle.round()}°';
  static String simBandLine(DifficultyBand band) => 'Độ khó: ${simBand(band)}';
  static String simStrokeLine(Stroke stroke) => 'Kiểu đánh: ${simStroke(stroke)}';
  static String simPowerLine(double power) => 'Lực: ${power.round()}%';
  static String simSpinLine(SideSpin spin) => switch (spin.side) {
        null => 'Áp phê: không',
        final side => 'Áp phê: ${_side(side)} lệch ${simTips(spin.tips)} đầu cơ',
      };
  static String simScratch(Pocket pocket) =>
      'Bi cái rơi lỗ ${simPocket(pocket)} (chết cái).';

  static String simAdvice(Advice advice) => switch (advice) {
        AddSpinToAvoid(:final from, :final to, :final pocket) =>
          _avoidText(from, to, pocket),
        NoSpinAvoids(:final pocket) => 'Bi cái chết cái ở lỗ '
            '${simPocket(pocket)}, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
        OverhitRisk(:final margin, :final fromPower, :final pocket, :final saferSpin) =>
          'Nếu đánh quá lực khoảng +${margin.round()}% (từ ~${fromPower.round()}%), '
              'bi cái có thể rơi lỗ ${simPocket(pocket)} (chết cái).'
              '${saferSpin == null ? '' : ' ${_capitalize(_spinLong(saferSpin))} thì vẫn an toàn tới 100%.'}',
        SpinCeiling(:final side, :final maxSafeTips, :final pocket) =>
          'Đừng áp phê ${_side(side)} quá ${simTips(maxSafeTips)} đầu cơ — '
              'bi cái sẽ rơi lỗ ${simPocket(pocket)}.',
      };

  /// Chọn câu theo chiều đổi: thêm đầu cơ, bớt đầu cơ, hay đổi phía.
  static String _avoidText(SideSpin from, SideSpin to, Pocket pocket) {
    final at = 'lỗ ${simPocket(pocket)}';
    if (to.isNone) {
      return 'Áp phê đang chọn làm bi cái chết cái ở $at — đánh không áp phê '
          'thì tránh được.';
    }
    if (from.isNone || (from.side == to.side && to.tips > from.tips)) {
      return 'Ít áp phê thì bi cái chết cái ở $at — nên ${_spinLong(to)} để '
          'đổi góc bật tránh lỗ.';
    }
    if (from.side == to.side) {
      return 'Áp phê nhiều quá, bi cái chết cái ở $at — giảm còn ${_spinLong(to)}.';
    }
    return 'Áp phê ${_side(from.side!)} làm bi cái chết cái ở $at — nên đổi '
        'sang ${_spinLong(to)}.';
  }

  /// Nhãn semantics của bàn: trình đọc màn hình và E2E đọc từ đây.
  static String simSummary(ShotResult? shot, CueBallPath? path) {
    const head = 'Bàn mô phỏng.';
    return switch (shot) {
      null => '$head $simNoPocket',
      Unmakeable(:final reason) => '$head ${simUnmakeable(reason)}',
      Makeable(:final geometry) => [
          '$head Lỗ ${simPocket(geometry.pocket)}, góc cắt '
              '${geometry.angle.round()}°, ${simBand(bandFor(geometry.angle))}.',
          if (path?.bankUsed ?? false) 'Dội băng.',
          if (path?.scratch != null) 'Chết cái.',
        ].join(' '),
    };
  }
```

Append to `AppColors`:

```dart
  // Bàn mô phỏng
  static const tableFelt = Color(0xFF1E6B47);
  static const tableRail = Color(0xFF4A2E1B);
  static const cuePath = Color(0xFF3CC8B4); // màu ngọc, PRD §6.5
  static const railHit = Color(0xFFF2D04B); // chấm vàng điểm chạm băng
  static const aimLine = Color(0xFFF5F1E6);
  static const ballCue = Color(0xFFF7F3E8);
  static const ballObject = Color(0xFFC0392B);
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/core/strings/vi_simulator_test.dart test/architecture_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings/vi.dart lib/core/theme/app_colors.dart test/core/strings/vi_simulator_test.dart
git commit -m "Add the simulator's words and colours, with advice sentences built from computed values

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: The simulator screen, its route and its entry card

**Files:**
- Create: `lib/features/training/presentation/simulator/table_painter.dart`, `lib/features/training/presentation/simulator/simulator_panel.dart`, `lib/features/training/presentation/simulator/simulator_screen.dart`
- Modify: `lib/core/router/routes.dart`, `lib/core/router/app_router.dart`, `lib/features/training/presentation/training_screen.dart`, `test/smoke/all_routes_test.dart`, `test/features/training/training_screen_test.dart`
- Test: `test/features/training/table_layout_test.dart`, `test/features/training/simulator_screen_test.dart`

**Interfaces:**
- Consumes: the whole core, plus `Vi.sim*` and `AppColors` from Task 8.
- Produces:
  - `Routes.simulator = '/training/simulator'`
  - `class TableLayout { const TableLayout({required Size size, TableSpec table}); static const frame = 8.0; static double aspectRatio(TableSpec); double get scale; Offset toCanvas(Vec2); Vec2 toTable(Offset) }`
  - `SimulatorScreen.tableKey`, `SimulatorScreen.initialCue = Vec2(80, 90)`, `SimulatorScreen.initialObject = Vec2(170, 50)`

- [ ] **Step 1: Write the failing tests**

`test/features/training/table_layout_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

void main() {
  const table = TableSpec.nineFoot;
  // (254 + 16) × (127 + 16) cm ở tỉ lệ 2 px/cm.
  const layout = TableLayout(size: Size(540, 286));

  test('khung băng vẽ quanh mặt chơi', () {
    expect(layout.scale, 2);
    expect(layout.toCanvas(const Vec2(-TableLayout.frame, -TableLayout.frame)),
        Offset.zero);
    expect(
      layout.toCanvas(Vec2(table.length + TableLayout.frame,
          table.width + TableLayout.frame)),
      const Offset(540, 286),
    );
    expect(TableLayout.aspectRatio(table), closeTo(540 / 286, 1e-12));
  });

  test('đổi qua đổi lại giữa cm và pixel', () {
    const p = Vec2(123.5, 45.25);
    final back = layout.toTable(layout.toCanvas(p));
    expect(back.distanceTo(p), lessThan(1e-9));
  });
}
```

`test/features/training/simulator_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/test_data.dart';

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5. Mọi con số mong đợi lấy
/// từ chính lõi table_geometry, không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  final initial = bestPocket(
    cue: SimulatorScreen.initialCue,
    object: SimulatorScreen.initialObject,
  )!;

  Future<void> openSimulator(WidgetTester tester) async {
    // Đủ cao để cả bàn lẫn bảng thông tin nằm trong màn.
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: PoolCoachApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(Routes.simulator);
    await tester.pumpAndSettle();
  }

  Offset onTable(WidgetTester tester, Vec2 p) {
    final box = find.byKey(SimulatorScreen.tableKey);
    final layout = TableLayout(size: tester.getSize(box));
    return tester.getTopLeft(box) + layout.toCanvas(p);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('mở màn ra một cú hợp lệ, lỗ tự chọn và góc do lõi tính',
      (tester) async {
    await openSimulator(tester);

    expect(find.text(Vi.simPocketLine(initial.pocket)), findsOneWidget);
    expect(find.text(Vi.simAngleLine(initial.angle)), findsOneWidget);
    expect(find.text(Vi.simBandLine(bandFor(initial.angle))), findsOneWidget);
    expect(find.text(Vi.simStrokeLine(Stroke.stun)), findsOneWidget);
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
  });

  testWidgets('đổi kiểu đánh thì bảng thông tin đổi theo', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simStroke(Stroke.draw));

    expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
    expect(find.text(Vi.simStrokeLine(Stroke.stun)), findsNothing);
  });

  testWidgets('chạm lỗ khác thì dùng lỗ đó, kể cả khi lỗ đó không đánh được',
      (tester) async {
    await openSimulator(tester);

    await tester.tapAt(
        onTable(tester, table.pocketPosition(Pocket.topMiddle)));
    await tester.pumpAndSettle();

    final expected = evaluateShot(
      cue: SimulatorScreen.initialCue,
      object: SimulatorScreen.initialObject,
      pocket: Pocket.topMiddle,
    );
    switch (expected) {
      case Makeable(:final geometry):
        expect(find.text(Vi.simPocketLine(geometry.pocket)), findsOneWidget);
      case Unmakeable(:final reason):
        expect(find.text(Vi.simUnmakeable(reason)), findsOneWidget);
    }
  });

  testWidgets('kéo bi mục tiêu thì quay về tự chọn lỗ theo bố cục mới',
      (tester) async {
    await openSimulator(tester);
    await tester.tapAt(
        onTable(tester, table.pocketPosition(Pocket.topMiddle)));
    await tester.pumpAndSettle();

    const target = Vec2(60, 40);
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();

    final expected =
        bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
    expect(find.text(Vi.simPocketLine(expected.pocket)), findsOneWidget);
  });

  testWidgets('kéo dọc trên bàn là kéo bi, không cuộn trang', (tester) async {
    await openSimulator(tester);

    const target = Vec2(170, 110);
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();

    final expected =
        bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
    expect(find.text(Vi.simAngleLine(expected.angle)), findsOneWidget);
  });

  testWidgets('thả bi đè lên bi kia thì bị đẩy về vừa chạm, không chồng',
      (tester) async {
    await openSimulator(tester);

    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(
        from, onTable(tester, SimulatorScreen.initialCue) - from);
    await tester.pumpAndSettle();

    expect(find.text(Vi.simUnmakeable(UnmakeableReason.overlap)), findsNothing);
  });

  testWidgets('áp phê mà không chạm băng thì nói thẳng là không đổi đường đi',
      (tester) async {
    final path = simulateCueBall(initial, stroke: Stroke.stun, power: 70);
    expect(path.bankUsed, isFalse,
        reason: 'bố cục mở màn phải không dội băng để test này có nghĩa');
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.right, 1)));

    expect(find.text(Vi.simSpinNoRail), findsOneWidget);
  });

  testWidgets('lệch 2 đầu cơ thì cảnh báo trượt cơ', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.left, 2)));

    expect(find.text(Vi.simMiscue), findsOneWidget);
  });

  testWidgets('bàn có nhãn semantics tóm tắt cú đánh', (tester) async {
    final handle = tester.ensureSemantics();
    await openSimulator(tester);

    final path = simulateCueBall(initial, stroke: Stroke.stun, power: 70);
    expect(find.bySemanticsLabel(Vi.simSummary(Makeable(initial), path)),
        findsOneWidget);
    handle.dispose();
  });
}
```

Add one test to `test/features/training/training_screen_test.dart`. Also add the import `package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart`:

```dart
  testWidgets('thẻ Mô phỏng góc cắt mở đúng màn', (tester) async {
    await openTraining(tester, const []);

    await tester.tap(find.text(Vi.simTitle));
    await tester.pumpAndSettle();

    expect(find.byType(SimulatorScreen), findsOneWidget);
  });
```

In `test/smoke/all_routes_test.dart`, add the import for `SimulatorScreen` and this entry to `_routeCases` after `Routes.drillSessionPattern`:

```dart
  Routes.simulator: (path: Routes.simulator, screen: SimulatorScreen),
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `"$FLUTTER" test test/features/training test/smoke`
Expected: FAIL. `SimulatorScreen`, `TableLayout` and `Routes.simulator` are undefined.

- [ ] **Step 3: Add the route.** In `routes.dart`, after `drillSessionPattern`:

```dart
  /// Mô phỏng góc cắt — trong nhánh Luyện tập như các màn bài tập.
  static const simulator = '$training/simulator';
```

Also add `simulator,` to `Routes.all` after `drillSessionPattern`. In `app_router.dart`, add this as the first child route of `Routes.training`, before `'drills/:id'`, and import `SimulatorScreen`:

```dart
                GoRoute(
                  path: 'simulator',
                  builder: (context, state) => const SimulatorScreen(),
                ),
```

- [ ] **Step 4: Write `table_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Quy đổi giữa cm trên mặt bàn và pixel trên canvas.
///
/// Màn và test dùng chung lớp này, nên test chạm đúng chỗ màn vẽ.
class TableLayout {
  const TableLayout({required this.size, this.table = TableSpec.nineFoot});

  /// Khung băng vẽ quanh mặt chơi, cm.
  static const frame = 8.0;

  static double aspectRatio(TableSpec table) =>
      (table.length + 2 * frame) / (table.width + 2 * frame);

  final Size size;
  final TableSpec table;

  double get scale => size.width / (table.length + 2 * frame);

  Offset toCanvas(Vec2 p) =>
      Offset((p.x + frame) * scale, (p.y + frame) * scale);

  Vec2 toTable(Offset o) => Vec2(o.dx / scale - frame, o.dy / scale - frame);
}

/// Mọi thứ cần vẽ của một khung hình — đã tính xong từ lõi.
class SimulatorScene {
  const SimulatorScene({
    required this.cue,
    required this.object,
    this.pocket,
    this.geometry,
    this.path,
    this.riskPocket,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Lỗ đang dùng (tự chọn hoặc người chơi chạm).
  final Pocket? pocket;
  final ShotGeometry? geometry;
  final CueBallPath? path;

  /// Lỗ có nguy cơ chết cái khi dư lực — vẽ vòng nét đứt.
  final Pocket? riskPocket;
}

/// Vẽ bàn theo PRD §6.5.
class TablePainter extends CustomPainter {
  TablePainter(this.scene);

  final SimulatorScene scene;

  static const _pocketDrawRadius = 5.5; // cm
  static const _dash = 2.0; // cm
  static const _gap = 1.5; // cm
  static const _railDot = 1.2; // cm

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final table = layout.table;
    final s = layout.scale;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.tableRail);
    canvas.drawRect(
      Rect.fromPoints(
        layout.toCanvas(Vec2.zero),
        layout.toCanvas(Vec2(table.length, table.width)),
      ),
      Paint()..color = AppColors.tableFelt,
    );

    for (final pocket in Pocket.values) {
      final c = layout.toCanvas(table.pocketPosition(pocket));
      final r = _pocketDrawRadius * s;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = scene.path?.scratch == pocket
              ? AppColors.danger
              : AppColors.bgDeep,
      );
      if (pocket == scene.pocket) {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.accent,
        );
      }
      if (pocket == scene.riskPocket) {
        _dashedCircle(
          canvas,
          c,
          r + 2 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.warning,
        );
      }
    }

    final g = scene.geometry;
    if (g != null) {
      final aim = Paint()
        ..color = AppColors.aimLine
        ..strokeWidth = 1.5;
      _dashedPolyline(
          canvas, [layout.toCanvas(scene.cue), layout.toCanvas(g.ghost)], aim, s);
      canvas.drawLine(
        layout.toCanvas(g.object),
        layout.toCanvas(table.pocketPosition(g.pocket)),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 1,
      );
      // Bi ảo: chỉ có viền.
      canvas.drawCircle(
        layout.toCanvas(g.ghost),
        table.radius * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.aimLine,
      );

      final path = scene.path;
      if (path != null) {
        final teal = Paint()
          ..color = AppColors.cuePath
          ..strokeWidth = 2;
        for (final seg in path.segments) {
          _dashedPolyline(
              canvas, _sample(seg).map(layout.toCanvas).toList(), teal, s);
        }
        final hit = path.railHit;
        if (hit != null) {
          canvas.drawCircle(layout.toCanvas(hit), _railDot * s,
              Paint()..color = AppColors.railHit);
        }
      }
    }

    canvas.drawCircle(layout.toCanvas(scene.object), table.radius * s,
        Paint()..color = AppColors.ballObject);
    canvas.drawCircle(layout.toCanvas(scene.cue), table.radius * s,
        Paint()..color = AppColors.ballCue);
  }

  List<Vec2> _sample(PathSegment seg) => switch (seg) {
        Straight() => [seg.start, seg.end],
        Curve() => [for (var i = 0; i <= 24; i++) seg.pointAt(i / 24)],
      };

  void _dashedPolyline(
      Canvas canvas, List<Offset> points, Paint paint, double scale) {
    final dash = _dash * scale;
    final gap = _gap * scale;
    var drawing = true;
    var left = dash;
    for (var i = 0; i + 1 < points.length; i++) {
      final start = points[i];
      final delta = points[i + 1] - start;
      final len = delta.distance;
      if (len == 0) continue;
      final dir = delta / len;
      var at = 0.0;
      while (at < len) {
        final step = math.min(left, len - at);
        if (drawing) {
          canvas.drawLine(start + dir * at, start + dir * (at + step), paint);
        }
        at += step;
        left -= step;
        if (left <= 0) {
          drawing = !drawing;
          left = drawing ? dash : gap;
        }
      }
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const parts = 16;
    const sweep = 2 * math.pi / parts;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < parts; i += 2) {
      canvas.drawArc(rect, i * sweep, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(TablePainter oldDelegate) => oldDelegate.scene != scene;
}
```

- [ ] **Step 5: Write `simulator_panel.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

/// Phần dưới bàn: chọn kiểu đánh/lực/áp phê, bảng thông tin, disclaimer.
class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({
    required this.shot,
    required this.path,
    required this.advice,
    required this.stroke,
    required this.power,
    required this.spin,
    required this.onStroke,
    required this.onPower,
    required this.onSpin,
    super.key,
  });

  /// null khi không lỗ nào đánh được.
  final ShotResult? shot;
  final CueBallPath? path;
  final List<Advice> advice;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final ValueChanged<Stroke> onStroke;
  final ValueChanged<double> onPower;
  final ValueChanged<SideSpin> onSpin;

  List<String> _infoLines() {
    final shot = this.shot;
    final path = this.path;
    return switch (shot) {
      null => [Vi.simNoPocket],
      // Không đánh được thì chỉ nói lý do (spec mục 5.4).
      Unmakeable(:final reason) => [Vi.simUnmakeable(reason)],
      Makeable(:final geometry) => [
          Vi.simPocketLine(geometry.pocket),
          Vi.simAngleLine(geometry.angle),
          Vi.simBandLine(bandFor(geometry.angle)),
          Vi.simStrokeLine(stroke),
          Vi.simPowerLine(power),
          Vi.simSpinLine(spin),
          if (path?.scratch case final pocket?) Vi.simScratch(pocket),
          if (path != null && path.bankUsed) Vi.simBankWarning,
          if (!spin.isNone && !(path?.bankUsed ?? false)) Vi.simSpinNoRail,
          if (spin.risksMiscue) Vi.simMiscue,
          ...advice.map(Vi.simAdvice),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget chips<T>(String label, List<T> values, T selected,
            String Function(T) name, ValueChanged<T> onPick) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final v in values)
                    ChoiceChip(
                      label: Text(name(v)),
                      selected: v == selected,
                      onSelected: (_) => onPick(v),
                    ),
                ],
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Vi.simHint, style: text.bodySmall),
        chips(Vi.simStrokeLabel, Stroke.values, stroke, Vi.simStroke, onStroke),
        chips(Vi.simPowerLabel, powerPresets, power, Vi.simPowerPreset, onPower),
        chips(Vi.simSpinLabel, SideSpin.all, spin, Vi.simSpinChip, onSpin),
        const SizedBox(height: 12),
        PcCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in _infoLines())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line, style: text.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(Vi.simDisclaimer, style: text.bodySmall),
      ],
    );
  }
}
```

- [ ] **Step 6: Write `simulator_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

enum _Ball { cue, object }

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5.
///
/// State cục bộ: không có gì để lưu hay chia sẻ, rời màn là mất.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  /// Khoá của bàn, để test quy đổi toạ độ bàn ra điểm chạm trên màn.
  static const tableKey = Key('simulator-table');

  /// Bố cục mở màn: một cú cắt nhẹ, hợp lệ.
  static const initialCue = Vec2(80, 90);
  static const initialObject = Vec2(170, 50);

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  static const _table = TableSpec.nineFoot;

  /// Chạm trong 1.5 bán kính quanh tâm bi là bắt được bi — ngón tay
  /// không phải trúng từng milimét.
  static const _grabRadii = 1.5;

  /// Chạm trong bán kính này quanh điểm lỗ là chọn lỗ đó, cm.
  static const _pocketTapRadius = 10.0;

  Vec2 _cue = SimulatorScreen.initialCue;
  Vec2 _object = SimulatorScreen.initialObject;
  Pocket? _pocketOverride;
  Stroke _stroke = Stroke.stun;
  double _power = powerPresets[1];
  SideSpin _spin = const SideSpin.none();
  _Ball? _dragging;

  /// Lỗ người chơi chạm thì dùng lỗ đó; không thì tự chọn (Priority 1).
  ShotResult? _shot() {
    final override = _pocketOverride;
    if (override != null) {
      return evaluateShot(
          cue: _cue, object: _object, pocket: override, table: _table);
    }
    final best = bestPocket(cue: _cue, object: _object, table: _table);
    return best == null ? null : Makeable(best);
  }

  void _onPanStart(DragStartDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final grab = _table.radius * _grabRadii;
    final toCue = p.distanceTo(_cue);
    final toObject = p.distanceTo(_object);
    if (toCue > grab && toObject > grab) return;
    _dragging = toCue <= toObject ? _Ball.cue : _Ball.object;
  }

  void _onPanUpdate(DragUpdateDetails details, TableLayout layout) {
    final dragging = _dragging;
    if (dragging == null) return;
    final other = dragging == _Ball.cue ? _object : _cue;
    final moved =
        _separate(_table.clamp(layout.toTable(details.localPosition)), other);
    setState(() {
      if (dragging == _Ball.cue) {
        _cue = moved;
      } else {
        _object = moved;
      }
      // Kéo bi là bố cục mới: quay về tự chọn lỗ.
      _pocketOverride = null;
    });
  }

  /// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
  ///
  /// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
  /// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
  Vec2 _separate(Vec2 p, Vec2 other) {
    final gap = p - other;
    if (gap.length >= _table.ballDiameter) return p;
    final dir = gap.isZero ? const Vec2(1, 0) : gap.normalized;
    return _table.clamp(other + dir * (_table.ballDiameter + 1e-6));
  }

  void _onTapUp(TapUpDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    for (final pocket in Pocket.values) {
      if (p.distanceTo(_table.pocketPosition(pocket)) <= _pocketTapRadius) {
        setState(() => _pocketOverride = pocket);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot();
    final geometry = switch (shot) {
      Makeable(:final geometry) => geometry,
      _ => null,
    };
    final path = geometry == null
        ? null
        : simulateCueBall(geometry,
            stroke: _stroke, power: _power, spin: _spin, table: _table);
    final advice = geometry == null
        ? const <Advice>[]
        : scratchAdvice(geometry,
            stroke: _stroke, power: _power, spin: _spin, table: _table);
    final scene = SimulatorScene(
      cue: _cue,
      object: _object,
      pocket: geometry?.pocket ?? _pocketOverride,
      geometry: geometry,
      path: path,
      riskPocket: advice.whereType<OverhitRisk>().firstOrNull?.pocket,
    );

    return PcRootScaffold(
      title: Vi.simTitle,
      // Bàn nằm ngoài vùng cuộn: kéo dọc trên bàn là kéo bi, không cuộn trang.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AspectRatio(
              aspectRatio: TableLayout.aspectRatio(_table),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout =
                      TableLayout(size: constraints.biggest, table: _table);
                  return Semantics(
                    label: Vi.simSummary(shot, path),
                    child: GestureDetector(
                      key: SimulatorScreen.tableKey,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) => _onPanStart(d, layout),
                      onPanUpdate: (d) => _onPanUpdate(d, layout),
                      onPanEnd: (_) => _dragging = null,
                      onTapUp: (d) => _onTapUp(d, layout),
                      child: CustomPaint(
                        size: constraints.biggest,
                        painter: TablePainter(scene),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SimulatorPanel(
                shot: shot,
                path: path,
                advice: advice,
                stroke: _stroke,
                power: _power,
                spin: _spin,
                onStroke: (v) => setState(() => _stroke = v),
                onPower: (v) => setState(() => _power = v),
                onSpin: (v) => setState(() => _spin = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

If `flutter analyze` reports `DragStartBehavior` as undefined, add `import 'package:flutter/gestures.dart';`. Normally `material.dart` already provides it, and an extra import would be flagged as unnecessary.

- [ ] **Step 7: Add the entry card.** In `training_screen.dart`, make this the first child of the `Column` inside `data:`, before the filter-chip `SingleChildScrollView`:

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: PcCard(
                  child: ListTile(
                    leading: const Icon(Icons.adjust),
                    title: const Text(Vi.simTitle),
                    subtitle: const Text(Vi.simCardBody),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(Routes.simulator),
                  ),
                ),
              ),
```

- [ ] **Step 8: Run the tests and confirm they pass**

Run: `"$FLUTTER" test test/features/training test/smoke test/architecture_test.dart`
Expected: PASS.

If a drag test fails, check the cause first. Is the drag starting inside `_grabRadii`? Is `DragStartBehavior.down` set? Don't loosen the assertion.

- [ ] **Step 9: Analyze and run the full suite**

Run: `"$FLUTTER" analyze && "$FLUTTER" test`
Expected: no issues; every test passes.

- [ ] **Step 10: Commit**

```bash
git add lib/features/training lib/core/router test/features/training test/smoke
git commit -m "Add the Cut Angle Simulator screen at /training/simulator, opened from the Training tab

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Real Chrome, the owner's eye check, and tuning

**Files:**
- Create: `tool/e2e/throwaway_user.mjs`, `tool/e2e/simulator.mjs`
- Modify: `tool/e2e/accounts.mjs` (use the shared helpers)
- Modify only if the owner asks: the constants in `cue_ball_path.dart`, `table_spec.dart`, and `stroke.dart`

**Interfaces:**
- Produces:
  - `registerThrowaway(tab, app, { email, password, name })`, which registers through the UI and waits for "Xin chào".
  - `deleteUserByEmail(email)`, which needs `DIRECTUS_URL`, `DIRECTUS_ADMIN_EMAIL` and `DIRECTUS_ADMIN_PASSWORD`. It only warns on failure.
  - `node tool/e2e/simulator.mjs [appUrl]`: it prints the table's semantics label for each scenario and writes screenshots to `%TMP%/pcai-sim`.

- [ ] **Step 1: Extract the helpers.** Create `tool/e2e/throwaway_user.mjs` by moving the register steps and the `finally` cleanup out of `accounts.mjs`, unchanged:

```js
// Tạo user thử qua giao diện và xoá nó qua Directus admin — dùng chung cho các bài E2E.
export async function registerThrowaway(tab, app, { email, password, name = 'Người thử E2E' }) {
  await tab.goto(app);
  await tab.waitForText('Đăng nhập');
  await tab.click('Chưa có tài khoản');
  await tab.type('Tên hiển thị', name);
  await tab.type('Email', email);
  await tab.type('Nhập lại mật khẩu', password);
  await tab.type('Mật khẩu', password);
  await tab.click('Tạo tài khoản');
  await tab.waitForText('Xin chào');
}

export async function deleteUserByEmail(email) {
  if (!process.env.DIRECTUS_URL || !process.env.DIRECTUS_ADMIN_PASSWORD) return;
  // Dọn dẹp hỏng thì chỉ cảnh báo: không được che lỗi thật của bài chạy.
  try {
    const base = process.env.DIRECTUS_URL.replace(/\/$/, '');
    const login = await (await fetch(`${base}/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.DIRECTUS_ADMIN_EMAIL, password: process.env.DIRECTUS_ADMIN_PASSWORD }),
    })).json();
    const token = login.data.access_token;
    const users = await (await fetch(`${base}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`, { headers: { Authorization: `Bearer ${token}` } })).json();
    for (const u of users.data) {
      await fetch(`${base}/users/${u.id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
    }
    console.log('Đã xoá user thử');
  } catch (cleanupError) {
    console.warn(`Cảnh báo: không xoá được user thử ${email}: ${cleanupError}`);
  }
}
```

In `accounts.mjs`:
- Import both helpers.
- Replace the seven register lines in step 1 with `await registerThrowaway(one, APP, { email, password: pass1 });`.
- Replace the whole `if (process.env.DIRECTUS_URL …) { … }` block in `finally` with `await deleteUserByEmail(email);`.

- [ ] **Step 2: Write `tool/e2e/simulator.mjs`**

```js
// Mở Mô phỏng góc cắt trên Chrome thật: đọc nhãn semantics của bàn và chụp từng tình huống.
//   node tool/e2e/simulator.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-sim');
const email = `e2e-sim-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

const tab = await launch({ port: 9335, name: 'mo-phong' });

async function summary() {
  return (await tab.labels()).find((l) => l.startsWith('Bàn mô phỏng'));
}

async function tableRect() {
  return tab.eval(`(() => {
    const e = [...document.querySelectorAll('flt-semantics')]
      .find((n) => (n.getAttribute('aria-label') || '').startsWith('Bàn mô phỏng'));
    const r = e.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width };
  })()`);
}

function toPx(r, [x, y]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [r.x + (x + FRAME) * s, r.y + (y + FRAME) * s];
}

async function drag(fromCm, toCm) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= 12; i++) {
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / 12, y: y0 + ((y1 - y0) * i) / 12, button: 'left', buttons: 1,
    });
  }
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(1000);
}

async function capture(name) {
  console.log(`${name}: ${await summary()}`);
  await tab.shot(path.join(shots, `${name}.png`));
}

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });
  await tab.goto(`${APP}/training/simulator`);
  await tab.waitForText('Bàn mô phỏng');
  if (!(await summary()).includes('góc cắt')) throw new Error('nhãn của bàn không có góc cắt');

  await capture('1-mac-dinh-dung-bi-70');
  await tab.click('Đánh trô bi');
  await capture('2-tro-70');
  await tab.click('Đánh cu lê');
  await capture('3-cu-le-70');
  await tab.click('Mạnh 95%');
  await capture('4-cu-le-95');

  await tab.click('Đánh đứng bi');
  await drag([170, 50], [127, 100]);
  await capture('5-dung-bi-95-bi-xuong-duoi');
  await tab.click('Phải 1');
  await capture('6-ap-phe-phai-1');
  await tab.click('Trái 2');
  await capture('7-ap-phe-trai-2');
  await tab.click('Vừa 70%');
  await tab.click('Đánh trô bi');
  await capture('8-tro-70-ap-phe-trai-2');

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
```

- [ ] **Step 3: Build and serve locally, then run it**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/simulator.mjs http://localhost:5555
```

Load the secrets from the main checkout's `.claude/settings.local.json` `env` block with a `node -e` one-liner (memory: poolcoachai-deploy). Expected:
- every scenario prints a label starting with `Bàn mô phỏng.`;
- there are no console errors;
- there are 8 screenshots.

Also re-run `node tool/e2e/accounts.mjs` against the live URL, to prove the helper extraction changed nothing: all 6 steps pass.

- [ ] **Step 4: The owner's eye check: STOP here.**

The controller shows the owner the 8 screenshots with the printed labels and asks them to judge. The spec decided that the physics constants are tuned by eye, and the owner is the billiards expert. Ask specifically:
- Is the travel distance right for each power level?
- Do trô and cu lê curve the right amount?
- Does Dội băng reflect plausibly?
- Do áp phê phải 1 and trái 2 change the rebound by a believable amount?
- Is the Chết cái capture too eager or too lax?

Do not change any constant without the owner's answer.

- [ ] **Step 5: Apply the owner's tuning, if any.**
1. Change only the named constants.
2. Re-run `"$FLUTTER" test`. Tests reference the constants, so they should stay green. A red test means the new value broke an invariant, such as no-bank paths staying inside the table. Report that to the owner rather than relaxing the test.
3. Rebuild, re-run Step 3, and show the new screenshots.
4. Repeat until the owner approves.

- [ ] **Step 6: Commit**

```bash
git add tool/e2e lib/domain/table_geometry
git commit -m "Check the simulator in real Chrome and share the throwaway-user helpers between E2E scripts

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

If tuning changed constants, say which ones and the old → new values in the commit body.

---

### After the branch is reviewed and merged

This is the same sequence as the last feature. Do not deploy from the branch.

1. From a clean `main`, run `FLUTTER=… DART=… bash deploy/publish.sh`.
2. Call the easypanel MCP `deployAppService` {projectName: test-va, serviceName: poolcoachai} through `execute_destructive`.
3. Confirm that `inspectAppService` → `commit.hash` equals the new `deploy-easypanel` head, and that the served `main.dart.js` matches the bundle on that branch.
4. Run `node tool/e2e/simulator.mjs` against the live URL. It must print labels and show no console errors.
5. Re-run `node tool/e2e/accounts.mjs`. All 6 steps must pass.
