# Table Physics Core and the Simulator's Move onto It — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Bézier cue-ball path with a deterministic, 1 ms-step physics core in `lib/domain/table_physics/` (sliding then rolling, squirt, swerve, throw, spin-dependent cushions, unlimited rails), and move the Cut Angle Simulator onto it with throw compensation, a *Xem nếu không bù ném* toggle, two cue elevations and five power levels.

**Architecture:** `lib/domain/table_physics/` is plain Dart, one file per concern: `Vec3` and `BallState`, named constants, the cue strike, one cloth step, the cushion impulse, the ball–ball impulse with throw, the two-ball event loop that produces a `ShotTrace`, and `aimShot`, which solves throw compensation and the Đánh đứng bi cue height by probing the simulation up to contact. `scratch.dart` keeps its `Advice` API but asks the physics core, and exposes a sliced `ScratchAdviceJob` so the screen can compute advice between frames after the finger lifts. The screen runs one `aimShot` per frame while dragging and draws the trace's own point lists.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flutter_test`, `package:test` tags via `dart_test.yaml`; Node 26 + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** `docs/superpowers/specs/2026-10-02-poolcoachai-table-physics-design.md` (binding). `PRD_RunOutPlanner.md` is context for the Planner that follows; its §7 edits were already committed with the spec in `707940d`, so no task here touches it.

## Deviations from spec

Every number below was measured by running this plan's own code on a throwaway clone of `707940d` (Dart VM unless noted). Each is the smallest correction that keeps the spec's intent; the owner should see them before execution.

1. **Stun cut leaves "along the tangent, under 2°" — only from about 37° up.** The cue ball's departure direction, measured from the line of centres at the real contact, is 2.38–2.45° at a 30° cut (30–90 % power), 1.38–1.41° at 45° and 0.78–0.81° at 60°. That is exactly the inelastic remainder `atan((1 − ballRestitution)/2 · cot φ)` = 2.48° at 30°, 1.43° at 45°, 0.83° at 60°, which `ballRestitution = 0.95` forces. Task 7 pins *departure ≤ that bound + 0.5°* at 30/45/60° and *< 2°* at 45° and 60°.
2. **Stun straight-in "stops within 1 R" — only at 30 % and 45 %.** Stop distance from the contact point: 0.57 cm at 30 %, 1.79 cm at 45 %, 3.51 cm at 60 %, 8.42 cm at 90 % (R = 2.86 cm). The creep is the same `(1 − ballRestitution)/2` of the speed. Task 7 pins 30 % and 45 %.
3. **"Áp phê nghịch đóng góc" — only up to 45° incidence.** At 60° a ball with no spin already slides along the cushion nose for the whole impact, so Coulomb friction is saturated and reverse english cannot close the angle further: 57.85° without spin, 57.78° with 1 tip reverse. Running english still opens it at 60° (65.19°). Task 4 pins reverse english at 15/30/45° and running english at 15–60°.
4. **Cushion normal restitution is exact, not Han's tilted value.** The prototype's first version (Han's tilted contact and friction, normal impulse sized for a ball held on the table) returned 0.871·v_n instead of `cushionRestitution` = 0.85, because friction along the tilted contact plane leaks into the horizontal normal. (Han's own impulse magnitude, which ignores the table under the ball, would give about 0.715·v_n.) The plan keeps Han's contact height and friction for the tangential velocity and the spin, but sets the horizontal normal speed to exactly `−cushionRestitution · v_n` (the table and cushion absorb the rest). No-spin rebound angles then measure 12.69° (15° in), 25.88° (30°), 40.04° (45°), 57.85° (60°): inside the spec's 5°, with only 0.04° to spare at 45°.
5. **The friction torque at ball–ball contact is applied to both balls.** The spec says the cue ball's spin is kept through the collision; the plan applies the same small friction torque to both balls so angular momentum holds. By estimate it is at most ~10 % of a draw shot's backspin; it was not measured separately. Draw and follow still come from the kept spin, and the energy test passes.
6. **Integration is exact per phase, not semi-implicit Euler.** Inside a sliding or rolling phase the acceleration is constant, so each 1 ms step uses `x += v·t + ½·a·t²` and catches the slide→roll moment exactly. Same step size; no accumulated drift.
7. **Đánh đứng bi uses a bracketing interpolated bisection (Illinois), and alternates with the throw solve.** Plain bisection needed ~10 probes for `b`; Illinois keeps the bracket and needs 2–4. Because `b` changes swerve and therefore the aim, a stun shot runs *b → aim → b → aim*, so its aim search can use up to 2 × `maxAimIterations` probes, not 12. Medians stay well inside budget: 3.3 ms stun, 3.8 ms draw, 2.5 ms follow on the VM; 6 / 8 / 7 ms when the same code is compiled with `dart compile js -O2` and run in Node.
8. **A probe whose cue ball hits a rail before the object ball counts as a miss.** Without this, a long shot with english found contacts after a rail bounce and the secant chased them: 17 of 1,224 reachable grid shots failed. With it, plus starting the search from the squirt-compensated aim and limiting each secant step to 6°, all 1,224 converge and pocket the object ball. Extreme combinations still fail: 68 of 6,816 shots with 2 tips on a Dốc cue at 30 % from across the table do not converge. The screen draws the best attempt.
9. **"Bi mục tiêu không vào lỗ" is not only a convergence failure.** The spec says the line appears only when the solve does not converge. It also appears, correctly, when the object ball runs out of speed (80–85° cuts at 30–45 % stop short on the pocket line) or when the straight line to a middle pocket meets the cushion outside the capture circle. Task 7's grid therefore checks `objectPocket == pocket` only for shots whose pocket line reaches the capture zone before the cushion.
10. **The performance test is tagged `perf` and skipped in the default run.** Under `flutter test`'s parallel files the same median measured 13.8 ms (3–5 ms alone). `dart_test.yaml` skips the tag by default and the plan runs it alone with `flutter test --tags perf --run-skipped`.

Measured and inside the spec, for the record: rolling speed 285.709 vs 5/7·v₀ = 285.714 cm/s; half-ball follow final direction 32.82° (30 %) and 32.65° (45 %), inside 30° ± 3° but only 0.2° from the edge; draw straight back with 0.0 cm lateral drift; throw at half ball 4.84° / 3.55° / 1.70° at Alciatore's slow / medium / fast (1 / 3 / 7 mph); squirt 0.83° / 1.55° / 1.74° for 0.5 / 1 / 2 tips, equal to the formula; swerve larger on Dốc than Thường; a 5-rail cue ball that stops on the table; energy never rises between steps; the longest of 11,928 grid shots at 100 % power runs 15.97 s (< `maxSimTime` = 20 s); `scratchAdvice` = 85 simulations, 117 ms on the VM, 206 ms in Node.

Two small additions the spec does not list: the info panel gets a `Độ dốc cơ: Thường/Dốc` line next to Kiểu đánh, Lực and Áp phê; and the toggle counts a cut as "khác 0" when the angle shown on screen (rounded) is not 0°.

## Global Constraints

- Flutter is not on PATH. In Git Bash use `FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat` and `DART=/c/Users/anhnpv/flutter/bin/dart.bat` in every command below. Never use `D:\flutter`.
- Units are cm, s, g, rad (constants named `…Elevation…` and `aimTolerance` are degrees). `g = 981 cm/s²` is `gravity`.
- The table is 254 × 127, origin top-left, `x` along the length, `y` down, `z` up from the cloth. `R = 5.715/2`. Ball-centre bounds are `[R, 254−R] × [R, 127−R]`; every rail hit lies exactly on them.
- Constants in `lib/domain/table_physics/constants.dart`, names and starting values from spec §3: `ballMass = 170.0`, `muSlide = 0.2`, `muRoll = 0.01`, `muSpin = 0.044`, `ballRestitution = 0.95`, `throwFrictionA = 9.951e-3`, `throwFrictionB = 0.108`, `throwFrictionC = 1.088` (s/m), `cushionRestitution = 0.85`, `cushionFriction = 0.2`, `cushionHeight = 0.635` (fraction of the ball diameter), `maxCueSpeed = 800.0` (cm/s), `strokeOffset = 0.5` (× R), `endMassRatio = 0.03`, `cueElevationNormal = 5.0`, `cueElevationSteep = 15.0` (degrees), `timeStep = 0.001`, `stopSpeed = 0.5`, `stopSpin = 0.5`, `maxSimTime = 20.0`, `aimTolerance = 0.05` (degrees), `overhitScanStep = 5.0` (%).
- Named here because the spec gives only their values: `gravity = 981.0`, `maxAimIterations = 12`, `stunMaxOffset = 0.6` (× R), `pathTolerance = 0.05` (cm).
- Unchanged and where they live: `cornerCapture = 6.0`, `middleCapture = 5.0` (`table_spec.dart`); `maxCutAngle = 85.0` (`shot_geometry.dart`); `tipWidth = 1.25`, `miscueTips = 2.0` (`stroke.dart`); `overhitBand = 15.0` (`scratch.dart`). `maxTravel`, `rollCarry` and `spinDegPerRadius` are deleted with `cue_ball_path.dart` in Task 10.
- `powerPresets = [30, 45, 60, 75, 90]`. `enum CueElevation { normal, steep }` lives in `stroke.dart`.
- Tests reference constants by name, never their literal values, so the owner's tuning in Task 11 does not rewrite tests.
- `lib/domain/table_physics/` never imports `package:flutter` (architecture test from Task 1). It may import `table_geometry`.
- Determinism: no randomness and no wall clock in `lib/domain`. The same `ShotInput` gives an identical `ShotTrace`.
- Terms on screen, exactly. New: **Ném**, **Bù ném**, **Xem nếu không bù ném**, **Bi cái bị lệch do áp phê**, **Độ dốc cơ** · **Thường** · **Dốc**. Kept: **Đánh đứng bi · Đánh trô bi · Đánh cu lê**, **Bi ảo** (never "bi ma"), **Dội băng**, **Áp phê** trái/phải, **Lệch N đầu cơ** (never "đầu gậy"), **Chết cái**, **Trượt cơ**, **Kiểu đánh**.
- All visible text lives in `lib/core/strings/vi.dart`. Sentences with numbers are templates filled from core results, never pre-written prose (memory: no fabricated generated content). The architecture test fails on Vietnamese literals in `lib/features`.
- The PRD §6.6 disclaimer (`Vi.simDisclaimer`) stays word for word.
- Comments follow the surrounding code: Vietnamese, explaining *why*.
- Commit messages are plain English sentences and end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The repo checks out with `core.autocrlf=true`. Do not convert line endings by hand.

## Review Focus

1. **Balls that start touching each other or a rail.** Dropping a ball onto the other leaves them exactly one diameter apart (`SimulatorScreen.separate`), and a ball dragged to the cushion sits exactly on the bound. A user expects contact on the first step, a normal bounce off the rail, and never a frozen ball or a ball outside the table. Owner: Task 6 (`hai bi đặt sát nhau: chạm ngay lúc đánh`, `bi sát băng đánh vào chính băng đó…`).
2. **A cue ball that cannot reach the object ball directly.** Heavy english on a Dốc cue from across the table, or a first probe that banks off a rail before the contact. A user expects the screen to keep drawing the best attempt and to say *Bi mục tiêu không vào lỗ*, never to hang or throw. Owner: Task 7 (`áp phê và swerve quá mạnh ở xa: không hội tụ vẫn trả cú tốt nhất`), with Task 6's probe treating rail-first contacts as misses.
3. **A ball resting inside a pocket's capture zone.** Dragging a ball next to a corner puts its centre within `cornerCapture` of the pocket point. A user expects it to stay on the table when struck away from the pocket. Owner: Task 6 (`bi nằm sẵn trong vùng lỗ mà đánh ra xa lỗ thì không rơi`).
4. **Very thin cuts up to `maxCutAngle` at low power.** A user expects a contact and an object ball on the pocket line, even if it stops short. The spec treats 85° as makeable. Owner: Task 7 (`cắt rất mỏng gần 85°…`).
5. **Fast balls at 1 ms steps, and slow balls brushing a resting ball.** At 100 % the cue ball moves 0.8 cm per step straight into a cushion. On the prototype, a slow ball rolling tangentially past a resting ball also froze at a zero-length event until `maxSimTime`. A user expects no tunnelling and no stall. Owner: Task 6 (`lực 100 % đánh thẳng vào băng: không xuyên băng với bước 1 ms`, and `bi lăn sát qua bi đang đứng không bị kẹt ở bước dài 0`, the exact shot that froze; it fails with `SimulationTimeout` if the contact check goes back to using displacement only).

---

## File map

| File | Responsibility |
|---|---|
| `lib/domain/table_physics/vec3.dart` | `Vec3` for spin and cross products |
| `lib/domain/table_physics/ball_state.dart` | `BallState` (pos, vel, spin), `isStopped`, `slip`, `kineticEnergy` |
| `lib/domain/table_physics/constants.dart` | every constant of spec §3 |
| `lib/domain/table_physics/cue_strike.dart` | `strikeCue`, `squirtAngle`, `sideOffsetOf`, `CueElevation.radians` |
| `lib/domain/table_physics/cloth.dart` | `clothStep`, `rollingSlip` |
| `lib/domain/table_physics/cushion.dart` | `Rail`, `cushionImpact` |
| `lib/domain/table_physics/ball_collision.dart` | `collideBalls`, `throwFriction` |
| `lib/domain/table_physics/simulate_shot.dart` | `ShotInput`, `ShotTrace`, `RailHit`, `ShotBall`, `simulateShot`, `probeContact`, `simulateCuePocket`, `SimulationTimeout` |
| `lib/domain/table_physics/aim.dart` | `AimedShot`, `AimSolution`, `solveAim`, `aimShot`, `topspinAtContact` |
| `lib/domain/table_geometry/stroke.dart` | adds `CueElevation`; `powerPresets` 30…90 |
| `lib/domain/table_geometry/scratch.dart` | `cuePocketAt`, `marginWith`, `scratchMargin`, `outcomesWith`, `scratchAdvice`, `ScratchAdviceJob`; `chooseAdvice` unchanged |
| `lib/domain/table_geometry/cue_ball_path.dart` | deleted (Task 10) |
| `lib/core/strings/vi.dart` | new terms and templates; new `simSummary` |
| `lib/features/training/presentation/simulator/info_lines.dart` | `simulatorInfoLines`, display thresholds |
| `lib/features/training/presentation/simulator/table_painter.dart` | `SimulatorScene` with `aimed`; draws spec §6.2 |
| `lib/features/training/presentation/simulator/simulator_panel.dart` | elevation chips, toggle, info lines |
| `lib/features/training/presentation/simulator/simulator_screen.dart` | `aimShot` per frame, sliced advice after pan end |
| `dart_test.yaml` | `perf` tag skipped by default |
| `test/domain/table_physics/*_test.dart` | physics tests |
| `test/domain/table_geometry/{scratch,advice}_test.dart` | rewritten on the new core |
| `test/domain/table_geometry/{cue_ball_path,bank_spin}_test.dart` | deleted (Task 10) |
| `test/features/training/{simulator_screen,simulator_info_lines,table_painter}_test.dart`, `test/core/strings/vi_simulator_test.dart` | screen and strings |
| `tool/e2e/simulator.mjs` | Chrome scenarios and frame-time gate |
| `docs/superpowers/logs/2026-10-01-cut-angle-simulator-followups.md` | what this plan closes |

---

### Task 0: Worktree and baseline

- [ ] **Step 1: Create the worktree** with superpowers:using-git-worktrees, on branch `feat/table-physics` from `main` at `707940d`.
- [ ] **Step 2: Generate code and run the baseline**

```bash
FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat
DART=/c/Users/anhnpv/flutter/bin/dart.bat
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" test
```

Expected: `+443: All tests passed!`. If not, stop and report: the baseline must be green before any change.

---

### Task 1: `Vec3`, `BallState`, the constants, and the no-Flutter rule

**Files:**
- Create: `lib/domain/table_physics/vec3.dart`, `lib/domain/table_physics/constants.dart`, `lib/domain/table_physics/ball_state.dart`
- Test: `test/domain/table_physics/vec3_ball_state_test.dart`
- Modify: `test/architecture_test.dart` (append one test at the end of `main`)

**Interfaces:**
- Consumes: `Vec2` (`lib/domain/table_geometry/vec2.dart`), `TableSpec.nineFoot.radius`.
- Produces:
  - `class Vec3 { const Vec3(double x, double y, double z); Vec3.flat(Vec2 v); static const zero; static const up; + - *(double) unary-; double dot(Vec3); Vec3 cross(Vec3); double get length; Vec2 get xy; == hashCode }`
  - `class BallState { const BallState({required Vec2 pos, Vec2 vel = Vec2.zero, Vec3 spin = Vec3.zero}); bool get isStopped; BallState copyWith({Vec2? pos, Vec2? vel, Vec3? spin}); Vec2 slip(double radius); double kineticEnergy(double radius); == hashCode }`
  - every constant listed in Global Constraints, as top-level `const double` / `const int` in `constants.dart`.

- [ ] **Step 1: Write the failing tests**

`test/domain/table_physics/vec3_ball_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;

  group('Vec3', () {
    test('phép vector cơ bản', () {
      const a = Vec3(1, 2, 3);
      expect(a + const Vec3(1, 1, 1), const Vec3(2, 3, 4));
      expect(a - const Vec3(1, 1, 1), const Vec3(0, 1, 2));
      expect(a * 2, const Vec3(2, 4, 6));
      expect(-a, const Vec3(-1, -2, -3));
      expect(a.dot(const Vec3(1, 0, 1)), 4);
      expect(const Vec3(2, 3, 6).length, 7);
      expect(a.xy, const Vec2(1, 2));
      expect(Vec3.flat(const Vec2(4, 5)), const Vec3(4, 5, 0));
    });

    test('tích có hướng theo công thức thành phần chuẩn', () {
      const x = Vec3(1, 0, 0);
      const y = Vec3(0, 1, 0);
      expect(x.cross(y), Vec3.up);
      expect(y.cross(Vec3.up), x);
      expect(Vec3.up.cross(x), y);
      expect(y.cross(x), -Vec3.up);
      expect(x.cross(x), Vec3.zero);
    });
  });

  group('BallState', () {
    test('lăn đều thì điểm chạm khăn không trượt', () {
      const vel = Vec2(120, -40);
      // Xoáy lăn đều là ẑ × v / R.
      final rolling = BallState(
        pos: const Vec2(50, 50),
        vel: vel,
        spin: Vec3.up.cross(Vec3.flat(vel)) * (1 / radius),
      );
      expect(rolling.slip(radius).length, lessThan(1e-12));
    });

    test('đứng yên thì vận tốc trượt bằng vận tốc tâm bi', () {
      const s = BallState(pos: Vec2(50, 50), vel: Vec2(100, 0));
      expect(s.slip(radius), const Vec2(100, 0));
    });

    test('dưới cả hai ngưỡng dừng mới là đứng hẳn', () {
      const p = Vec2(10, 10);
      expect(const BallState(pos: p).isStopped, isTrue);
      expect(
          const BallState(pos: p, vel: Vec2(stopSpeed * 0.9, 0)).isStopped,
          isTrue);
      expect(
          const BallState(pos: p, vel: Vec2(stopSpeed * 1.1, 0)).isStopped,
          isFalse);
      expect(
          const BallState(pos: p, spin: Vec3(0, 0, stopSpin * 1.1)).isStopped,
          isFalse);
    });

    test('động năng gồm tịnh tiến và quay của bi đặc', () {
      const v = Vec2(100, 0);
      const w = Vec3(0, 0, 10);
      final e = const BallState(pos: Vec2.zero, vel: v, spin: w)
          .kineticEnergy(radius);
      expect(
          e,
          closeTo(
              0.5 * ballMass * 100 * 100 +
                  0.5 * 0.4 * ballMass * radius * radius * 100,
              1e-6));
    });
  });
}
```

Append inside `main` of `test/architecture_test.dart`, after the test `lõi hình học bàn không phụ thuộc Flutter`:

```dart
  test('lõi vật lý bàn không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/table_physics');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'màn mô phỏng và Planner dùng chung lõi này; kéo Flutter vào '
          'thì không còn chạy và đo hiệu năng được trên Dart VM thuần',
    );
  });
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_physics/vec3_ball_state_test.dart test/architecture_test.dart`
Expected: FAIL. The physics test does not compile (`Error when reading 'lib/domain/table_physics/vec3.dart'`), and `lõi vật lý bàn không phụ thuộc Flutter` fails with a `PathNotFoundException` for `lib/domain/table_physics`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/vec3.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Vector 3 chiều, bất biến: `x`, `y` như trên mặt bàn, `z` hướng lên.
///
/// Chỉ cần cho vận tốc góc: xoáy của bi có trục bất kỳ, nên không gói
/// được vào [Vec2]. Phép nhân có hướng dùng đúng một công thức ở mọi chỗ
/// (mô-men, vận tốc điểm tiếp xúc), nên vật lý nhất quán dù trục `y`
/// hướng xuống.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  /// Vector nằm ngang ứng với [v].
  Vec3.flat(Vec2 v)
      : x = v.x,
        y = v.y,
        z = 0;

  final double x;
  final double y;
  final double z;

  static const zero = Vec3(0, 0, 0);
  static const up = Vec3(0, 0, 1);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  /// Phần nằm ngang.
  Vec2 get xy => Vec2(x, y);

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
```

`lib/domain/table_physics/constants.dart`:

```dart
// Hằng số vật lý của bàn — spec 2026-10-02 mục 3.
//
// Giá trị khởi điểm lấy từ tài liệu đã công bố (Alciatore, Han 2005,
// pooltool), rồi chủ sản phẩm chỉnh bằng mắt trên Chrome. Test chỉ dùng
// tên, không dùng giá trị, nên chỉnh hằng số không phải viết lại test.
// Đơn vị: cm, giây, gam, radian (trừ chỗ ghi độ).

/// Gia tốc trọng trường, cm/s².
const gravity = 981.0;

/// Khối lượng bi tiêu chuẩn, g.
const ballMass = 170.0;

/// Ma sát trượt bi–khăn (pooltool `u_s`).
const muSlide = 0.2;

/// Cản lăn (pooltool `u_r`).
const muRoll = 0.01;

/// Ma sát làm tắt xoáy quanh trục đứng (pooltool `u_sp`).
const muSpin = 0.044;

/// Hệ số phục hồi bi–bi.
const ballRestitution = 0.95;

/// Ma sát bi–bi theo vận tốc trượt `v` (m/s): `μ = A + B·e^(−C·v)`
/// (Alciatore TP A.14). `C` tính theo s/m, nên đổi cm/s ra m/s trước.
const throwFrictionA = 9.951e-3;
const throwFrictionB = 0.108;
const throwFrictionC = 1.088;

/// Hệ số phục hồi bi–băng (pooltool `e_c`).
const cushionRestitution = 0.85;

/// Ma sát bi–băng (pooltool `f_c`).
const cushionFriction = 0.2;

/// Độ cao mũi băng, tính theo đường kính bi (WPA 62.5–64.5 %).
const cushionHeight = 0.635;

/// Vận tốc bi cái ở lực 100 %, cm/s.
const maxCueSpeed = 800.0;

/// Độ lệch dọc của đầu cơ khi trô/cu lê, tính theo bán kính bi.
const strokeOffset = 0.5;

/// Khối lượng đầu cơ hiệu dụng chia khối lượng bi — quyết định độ lệch
/// do áp phê.
const endMassRatio = 0.03;

/// Hai mức độ dốc cơ, độ.
const cueElevationNormal = 5.0;
const cueElevationSteep = 15.0;

/// Bước tích phân, s.
const timeStep = 0.001;

/// Dưới cả hai ngưỡng thì bi đứng hẳn: cm/s và rad/s.
const stopSpeed = 0.5;
const stopSpin = 0.5;

/// Trần an toàn, s. Vượt là lỗi chứ không phải kết quả.
const maxSimTime = 20.0;

/// Dừng dò bù ném khi hướng bi mục tiêu sai dưới mức này, độ.
const aimTolerance = 0.05;

/// Dò bù ném tối đa ngần này vòng rồi chấp nhận kết quả tốt nhất.
const maxAimIterations = 12;

/// Đánh đứng bi dò điểm đặt cơ trong `[−stunMaxOffset·R, 0]`.
const stunMaxOffset = 0.6;

/// Bước dò lực khi tìm biên chết cái, %; rồi dò mịn 1 % trong khoảng
/// tìm được.
const overhitScanStep = 5.0;

/// Rút gọn đường đi: bỏ điểm lệch khỏi đoạn thẳng dưới mức này, cm.
const pathTolerance = 0.05;
```

`lib/domain/table_physics/ball_state.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Trạng thái một bi: tâm, vận tốc trên mặt bàn và xoáy 3 chiều.
///
/// Bi không rời khăn (spec mục 1, ngoài phạm vi), nên vận tốc chỉ có hai
/// chiều; xoáy thì có trục bất kỳ — trục nghiêng là nguồn của swerve.
class BallState {
  const BallState({
    required this.pos,
    this.vel = Vec2.zero,
    this.spin = Vec3.zero,
  });

  final Vec2 pos;

  /// cm/s.
  final Vec2 vel;

  /// rad/s.
  final Vec3 spin;

  bool get isStopped => vel.length < stopSpeed && spin.length < stopSpin;

  BallState copyWith({Vec2? pos, Vec2? vel, Vec3? spin}) => BallState(
        pos: pos ?? this.pos,
        vel: vel ?? this.vel,
        spin: spin ?? this.spin,
      );

  /// Vận tốc trượt của điểm bi chạm khăn: `vel + ω × (−R ẑ)`.
  ///
  /// Bằng 0 nghĩa là bi lăn đều; khác 0 thì ma sát khăn đang làm việc.
  Vec2 slip(double radius) =>
      Vec2(vel.x - radius * spin.y, vel.y + radius * spin.x);

  /// Động năng tịnh tiến cộng quay, g·cm²/s². Bi đặc: `I = 2/5·m·R²`.
  double kineticEnergy(double radius) =>
      0.5 * ballMass * vel.dot(vel) +
      0.5 * 0.4 * ballMass * radius * radius * spin.dot(spin);

  @override
  bool operator ==(Object other) =>
      other is BallState &&
      other.pos == pos &&
      other.vel == vel &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(pos, vel, spin);

  @override
  String toString() => 'BallState($pos, $vel, $spin)';
}
```

- [ ] **Step 4: Run them and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_physics/vec3_ball_state_test.dart test/architecture_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics test/domain/table_physics test/architecture_test.dart
git commit -m "Start the table physics core with 3D spin vectors, ball state and the published starting constants

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The cue strike — speed, spin from the tip offset, squirt, and cue elevation

**Files:**
- Modify: `lib/domain/table_geometry/stroke.dart` (add `CueElevation` after `SpinSide`)
- Create: `lib/domain/table_physics/cue_strike.dart`
- Test: `test/domain/table_physics/cue_strike_test.dart`

**Interfaces:**
- Consumes: `BallState`, `Vec3`, constants (Task 1); `SideSpin`, `SpinSide`, `tipWidth` (`stroke.dart`); `TableSpec`.
- Produces:
  - `enum CueElevation { normal, steep }` in `stroke.dart`
  - `extension CueElevationAngle on CueElevation { double get radians }`
  - `double sideOffsetOf(SideSpin spin)`: cm, right is positive
  - `double squirtAngle(double sideOffset, double radius)`: rad, same sign as `sideOffset`
  - `BallState strikeCue({required Vec2 pos, required double aimAngle, required double power, required double verticalOffset, required SideSpin spin, required double elevation, TableSpec table = TableSpec.nineFoot})`

- [ ] **Step 1: Write the failing test**

`test/domain/table_physics/cue_strike_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;
  const pos = Vec2(60, 60);
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);

  double headingDeg(Vec2 v) => math.atan2(v.y, v.x) * 180 / math.pi;

  test('đánh tâm, cơ nằm ngang: bi đi đúng hướng cơ, không xoáy', () {
    final s = strikeCue(
        pos: pos,
        aimAngle: 0.3,
        power: 50,
        verticalOffset: 0,
        spin: none,
        elevation: 0);
    expect(s.pos, pos);
    expect(s.vel.length, closeTo(maxCueSpeed * 0.5, 1e-9));
    expect(s.vel.normalized.distanceTo(const Vec2(1, 0).rotated(0.3)),
        lessThan(1e-12));
    expect(s.spin.length, lessThan(1e-9));
  });

  test('cu lê xoáy lên, trô xoáy xuống, đúng độ lớn 5·v₀·b / 2R²', () {
    final b = strokeOffset * radius;
    const v0 = maxCueSpeed * 0.4;
    for (final sign in [1.0, -1.0]) {
      final s = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 40,
          verticalOffset: sign * b,
          spin: none,
          elevation: 0);
      // Đi theo +x: xoáy lăn đều nằm trên trục +y (ẑ × x̂ = ŷ).
      expect(s.spin.y, closeTo(sign * 5 * v0 * b / (2 * radius * radius), 1e-9));
      expect(s.spin.x.abs() + s.spin.z.abs(), lessThan(1e-9));
    }
  });

  test('bi cái bị lệch do áp phê: ngược phía áp phê, đúng công thức', () {
    var previous = 0.0;
    for (final tips in [0.5, 1.0, 2.0]) {
      final right = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: SideSpin(SpinSide.right, tips),
          elevation: 0);
      final left = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: SideSpin(SpinSide.left, tips),
          elevation: 0);
      final alpha = squirtAngle(tips * tipWidth, radius) * 180 / math.pi;
      // Góc dương là quay sang phải: áp phê phải làm bi lệch sang trái.
      expect(headingDeg(right.vel), closeTo(-alpha, 1e-9));
      expect(headingDeg(left.vel), closeTo(alpha, 1e-9));
      expect(alpha, greaterThan(previous));
      previous = alpha;
    }
  });

  test('công thức lệch do áp phê là Alciatore TP A.31', () {
    const a = 1.25;
    final r = a / radius;
    final expected = math.atan(2.5 * r * math.sqrt(1 - r * r) /
        (1 + 1 / endMassRatio + 2.5 * (1 - r * r)));
    expect(squirtAngle(a, radius), expected);
    expect(squirtAngle(-a, radius), -expected);
    expect(squirtAngle(0, radius), 0);
  });

  test('cơ dốc có áp phê thì xoáy có trục dọc đường đi — nguồn swerve', () {
    double along(CueElevation e) {
      final s = strikeCue(
          pos: pos,
          aimAngle: 0,
          power: 50,
          verticalOffset: 0,
          spin: right1,
          elevation: e.radians);
      return s.spin.x;
    }

    final flat = strikeCue(
        pos: pos,
        aimAngle: 0,
        power: 50,
        verticalOffset: 0,
        spin: right1,
        elevation: 0);
    expect(flat.spin.x.abs(), lessThan(1e-9));
    expect(along(CueElevation.steep).abs(),
        greaterThan(along(CueElevation.normal).abs()));
    expect(along(CueElevation.normal).abs(), greaterThan(0));
  });

  test('áp phê phải xoáy theo chiều ngược với áp phê trái', () {
    Vec3 spinOf(SideSpin s) => strikeCue(
            pos: pos,
            aimAngle: 0,
            power: 50,
            verticalOffset: 0,
            spin: s,
            elevation: CueElevation.normal.radians)
        .spin;
    final r = spinOf(right1);
    final l = spinOf(const SideSpin(SpinSide.left, 1));
    expect(r.z, closeTo(-l.z, 1e-9));
    expect(r.z, isNot(0));
  });

  test('hai mức độ dốc cơ đổi ra radian từ hằng số độ', () {
    expect(CueElevation.normal.radians, cueElevationNormal * math.pi / 180);
    expect(CueElevation.steep.radians, cueElevationSteep * math.pi / 180);
  });

  test('độ lệch ngang theo số đầu cơ, phải dương', () {
    expect(sideOffsetOf(none), 0);
    expect(sideOffsetOf(right1), tipWidth);
    expect(sideOffsetOf(const SideSpin(SpinSide.left, 2)), -2 * tipWidth);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `"$FLUTTER" test test/domain/table_physics/cue_strike_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/cue_strike.dart'`, and `CueElevation` is undefined.

- [ ] **Step 3: Implement**

In `lib/domain/table_geometry/stroke.dart`, insert after `enum SpinSide { left, right }`:

```dart
/// Hai mức độ dốc cơ: Thường và Dốc. Góc của từng mức là hằng số vật lý
/// (`cueElevationNormal`, `cueElevationSteep` trong table_physics), để
/// chủ sản phẩm chỉnh cùng chỗ với các hằng số khác.
enum CueElevation { normal, steep }
```

`lib/domain/table_physics/cue_strike.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Góc của hai mức độ dốc cơ, radian.
extension CueElevationAngle on CueElevation {
  double get radians =>
      (this == CueElevation.normal ? cueElevationNormal : cueElevationSteep) *
      math.pi /
      180;
}

/// Độ lệch ngang `a` của đầu cơ, cm: dương là áp phê phải.
double sideOffsetOf(SideSpin spin) => switch (spin.side) {
      null => 0,
      SpinSide.right => spin.tips * tipWidth,
      SpinSide.left => -spin.tips * tipWidth,
    };

/// Bi cái bị lệch do áp phê: góc giữa hướng cơ và hướng bi đi, radian
/// (Alciatore TP A.31). Cùng dấu với [sideOffset]; bi lệch về phía
/// ngược lại, nên [strikeCue] quay hướng đi một góc âm của giá trị này.
double squirtAngle(double sideOffset, double radius) {
  final r = sideOffset / radius;
  final rest = 1 - r * r;
  return math.atan(2.5 * r * math.sqrt(rest) /
      (1 + 1 / endMassRatio + 2.5 * rest));
}

/// Cơ chạm bi cái: trạng thái ban đầu của bi cái (spec mục 4.1).
///
/// [aimAngle] là hướng cơ trên mặt bàn, radian, cùng chiều với
/// [Vec2.rotated]. [verticalOffset] là `b`, cm, dương là trên tâm.
/// [elevation] là độ dốc cơ, radian.
BallState strikeCue({
  required Vec2 pos,
  required double aimAngle,
  required double power,
  required double verticalOffset,
  required SideSpin spin,
  required double elevation,
  TableSpec table = TableSpec.nineFoot,
}) {
  final radius = table.radius;
  final speed = maxCueSpeed * power / 100;
  final a = sideOffsetOf(spin);
  final heading = Vec2(math.cos(aimAngle), math.sin(aimAngle));

  // Cơ cứng đẩy bi qua điểm chạm r: xung lực J dọc hướng cơ cho
  // m·v = J và I·ω = r × J, nên ω = (5 v₀ / 2R²)·(r × d̂). Cơ dốc thì d̂
  // chúi xuống mặt bàn, áp phê sinh thêm xoáy quanh trục nằm ngang dọc
  // đường đi — chính phần đó làm bi cong (swerve) khi trượt trên khăn.
  final h = Vec3.flat(heading);
  final right = Vec3.flat(heading.rightNormal);
  final c = math.cos(elevation);
  final s = math.sin(elevation);
  final cueDir = h * c - Vec3.up * s;
  final faceUp = h * s + Vec3.up * c;
  final contact = right * a + faceUp * verticalOffset;
  final omega = contact.cross(cueDir) * (5 * speed / (2 * radius * radius));

  // Vận tốc nằm ngang theo hướng cơ chiếu xuống bàn, quay ngược phía áp
  // phê đúng bằng góc lệch.
  final dir = heading.rotated(-squirtAngle(a, radius));
  return BallState(pos: pos, vel: dir * speed, spin: omega);
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `"$FLUTTER" test test/domain/table_physics/cue_strike_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_geometry/stroke.dart lib/domain/table_physics/cue_strike.dart test/domain/table_physics/cue_strike_test.dart
git commit -m "Strike the cue ball from the tip offset, with squirt away from the english and a tilted spin axis for an elevated cue

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Motion on the cloth — sliding into rolling at 5/7, spin decay, and swerve

**Files:**
- Create: `lib/domain/table_physics/cloth.dart`
- Test: `test/domain/table_physics/cloth_test.dart`

**Interfaces:**
- Consumes: `BallState`, `Vec3`, constants (Task 1); `strikeCue`, `CueElevation.radians` (Task 2).
- Produces: `const rollingSlip = 1e-6;` and `BallState clothStep(BallState s, double dt, {required double radius})`.

- [ ] **Step 1: Write the failing test**

`test/domain/table_physics/cloth_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;
  const start = Vec2(30, 63.5);

  BallState strike(
          {double power = 50,
          double b = 0,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal}) =>
      strikeCue(
          pos: start,
          aimAngle: 0,
          power: power,
          verticalOffset: b,
          spin: spin,
          elevation: elevation.radians);

  /// Chạy từng bước tới khi [done], trả trạng thái và thời gian.
  (BallState, double) runUntil(BallState s, bool Function(BallState) done) {
    var t = 0.0;
    var state = s;
    while (!done(state)) {
      state = clothStep(state, timeStep, radius: radius);
      t += timeStep;
      if (t > maxSimTime) fail('không dừng trong maxSimTime');
    }
    return (state, t);
  }

  bool rolling(BallState s) => s.slip(radius).length <= rollingSlip;

  test('đánh tâm: trượt rồi lăn đều ở đúng 5/7 vận tốc ban đầu', () {
    final s0 = strike(elevation: CueElevation.normal);
    final v0 = s0.vel.length;
    final (rolled, t) = runUntil(s0, rolling);
    // Lúc vừa lăn, vận tốc đã giảm thêm do cản lăn trong phần còn lại
    // của bước cuối — tối đa muRoll·g·timeStep.
    expect(rolled.vel.length,
        closeTo(5 / 7 * v0, muRoll * gravity * timeStep + 1e-9));
    // Hết trượt đúng lúc 2·v₀ / (7·μ·g), làm tròn lên một bước.
    final expected = 2 * v0 / (7 * muSlide * gravity);
    expect(t, greaterThanOrEqualTo(expected - 1e-9));
    expect(t, lessThan(expected + timeStep + 1e-9));
  });

  test('chuyển trượt → lăn được bắt giữa bước, không trượt quá', () {
    // Một bước dài gấp nhiều lần thời gian trượt vẫn ra đúng 5/7.
    final s0 = strike(power: 10, elevation: CueElevation.normal);
    final v0 = s0.vel.length;
    final slideTime = 2 * v0 / (7 * muSlide * gravity);
    final after = clothStep(s0, slideTime * 1.5, radius: radius);
    final rollingPart = slideTime * 0.5;
    expect(after.vel.length,
        closeTo(5 / 7 * v0 - muRoll * gravity * rollingPart, 1e-9));
    expect(after.slip(radius).length, lessThan(1e-9));
  });

  test('trô giữ xoáy dưới một quãng rồi mới lăn tới trước', () {
    final s0 = strike(b: -strokeOffset * radius);
    final after = clothStep(s0, 0.05, radius: radius);
    // Còn xoáy dưới: điểm chạm khăn trượt về phía trước nhanh hơn bi.
    expect(after.slip(radius).x, greaterThan(after.vel.x));
    final (rolled, _) = runUntil(s0, rolling);
    expect(rolled.vel.x, greaterThan(0));
  });

  test('lăn thì đi thẳng và giảm tốc đúng muRoll·g tới khi đứng', () {
    final s0 = strike(power: 20);
    final (rolled, _) = runUntil(s0, rolling);
    final next = clothStep(rolled, 0.1, radius: radius);
    expect(rolled.vel.length - next.vel.length,
        closeTo(muRoll * gravity * 0.1, 1e-9));
    expect(next.pos.y, closeTo(rolled.pos.y, 1e-9));
    final (stopped, _) = runUntil(next, (s) => s.vel.length == 0);
    expect(stopped.vel, Vec2.zero);
  });

  test('xoáy đứng tắt dần với gia tốc góc 5·muSpin·g / 2R', () {
    const spinning = BallState(pos: start, spin: Vec3(0, 0, 50));
    final after = clothStep(spinning, 0.1, radius: radius);
    expect(after.spin.z, closeTo(50 - 2.5 * muSpin * gravity / radius * 0.1, 1e-9));
    expect(after.pos, start);
    // Không đổi dấu: tắt hẳn rồi đứng ở 0.
    final gone = clothStep(spinning, 10, radius: radius);
    expect(gone.spin.z, 0);
  });

  test('động năng không bao giờ tăng qua một bước', () {
    for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius]) {
      for (final spin in SideSpin.all) {
        for (final e in CueElevation.values) {
          var s = strike(power: 90, b: b, spin: spin, elevation: e);
          for (var i = 0; i < 3000; i++) {
            final next = clothStep(s, timeStep, radius: radius);
            expect(next.kineticEnergy(radius),
                lessThanOrEqualTo(s.kineticEnergy(radius) * (1 + 1e-12)),
                reason: 'b=$b $spin $e bước $i');
            s = next;
          }
        }
      }
    }
  });

  group('swerve', () {
    /// Độ lệch ngang khỏi đường thẳng ban đầu (đường lệch do áp phê) sau
    /// khi bi đi được [distance] cm; dương là sang phải.
    double curve(SideSpin spin, CueElevation e, double distance) {
      final s0 = strike(power: 45, spin: spin, elevation: e);
      final dir = s0.vel.normalized;
      final (s, _) = runUntil(
          s0, (s) => (s.pos - start).dot(dir) >= distance || s.vel.length == 0);
      return (s.pos - start).dot(dir.rightNormal);
    }

    test('áp phê phải cong về phải, trái cong về trái', () {
      expect(curve(const SideSpin(SpinSide.right, 1), CueElevation.normal, 100),
          greaterThan(0));
      expect(curve(const SideSpin(SpinSide.left, 1), CueElevation.normal, 100),
          lessThan(0));
    });

    test('cơ Dốc cong nhiều hơn cơ Thường', () {
      const spin = SideSpin(SpinSide.right, 1);
      expect(curve(spin, CueElevation.steep, 100),
          greaterThan(curve(spin, CueElevation.normal, 100)));
    });

    test('không áp phê thì không cong', () {
      expect(curve(const SideSpin.none(), CueElevation.steep, 100).abs(),
          lessThan(1e-9));
    });
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `"$FLUTTER" test test/domain/table_physics/cloth_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/cloth.dart'`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/cloth.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Dưới mức này (cm/s) coi như điểm chạm khăn không trượt: bi đang lăn.
///
/// Không phải hằng số chỉnh được: chuyển trượt → lăn được bắt đúng thời
/// điểm và ép lăn đều, nên sau đó vận tốc trượt chỉ còn nhiễu làm tròn.
const rollingSlip = 1e-6;

/// Một bước chuyển động trên khăn trong [dt] giây (spec mục 4.2).
///
/// Trong một pha (trượt hoặc lăn) gia tốc không đổi, nên cập nhật theo
/// đúng công thức gia tốc không đổi chứ không cộng dồn Euler: cùng bước
/// 1 ms mà không tích sai số. Chuyển trượt → lăn rơi vào giữa bước thì
/// tách bước tại đúng thời điểm đó.
BallState clothStep(BallState s, double dt, {required double radius}) {
  var state = s;
  var left = dt;

  final u = state.slip(radius);
  final slipSpeed = u.length;
  if (slipSpeed > rollingSlip) {
    // Ma sát trượt kéo vận tốc trượt về 0 theo đường thẳng với gia tốc
    // 7/2·μ·g (bi đặc), nên biết trước lúc nào hết trượt.
    final untilRolling = slipSpeed / (3.5 * muSlide * gravity);
    final t = math.min(untilRolling, left);
    state = _slide(state, t, u * (1 / slipSpeed), radius);
    left -= t;
    if (t == untilRolling) state = _forceRolling(state, radius);
  }
  if (left > 0) state = _roll(state, left, radius);

  return state.copyWith(spin: _decayVerticalSpin(state.spin, dt, radius));
}

/// Trượt [t] giây, ma sát ngược hướng trượt [dir].
///
/// Lực `−μ·g·û` đặt ở điểm chạm khăn đổi cả vận tốc lẫn xoáy ngang
/// (mô-men `R ẑ × F`). Khi xoáy có trục nằm ngang dọc đường đi (cơ dốc
/// có áp phê), hướng trượt lệch khỏi hướng đi và đường đi cong thành
/// parabol — đó là swerve.
BallState _slide(BallState s, double t, Vec2 dir, double radius) {
  final a = dir * (-muSlide * gravity);
  final k = 2.5 * muSlide * gravity / radius;
  return BallState(
    pos: s.pos + s.vel * t + a * (0.5 * t * t),
    vel: s.vel + a * t,
    spin: s.spin + Vec3(-dir.y, dir.x, 0) * (k * t),
  );
}

/// Lăn đều: xoáy ngang khớp `ẑ × v / R`, giữ nguyên xoáy đứng.
BallState _forceRolling(BallState s, double radius) => s.copyWith(
      spin: Vec3(-s.vel.y / radius, s.vel.x / radius, s.spin.z),
    );

/// Lăn [t] giây: giảm tốc `muRoll·g` theo đường thẳng tới khi đứng.
BallState _roll(BallState s, double t, double radius) {
  final speed = s.vel.length;
  if (speed == 0) return s;
  final dir = s.vel * (1 / speed);
  const decel = muRoll * gravity;
  final run = math.min(t, speed / decel);
  final next = speed - decel * run;
  final vel = next <= 0 ? Vec2.zero : dir * next;
  return _forceRolling(
    BallState(
      pos: s.pos + dir * (speed * run - 0.5 * decel * run * run),
      vel: vel,
      spin: s.spin,
    ),
    radius,
  );
}

/// Xoáy quanh trục đứng tắt dần với gia tốc góc `5·muSpin·g / 2R`.
Vec3 _decayVerticalSpin(Vec3 spin, double dt, double radius) {
  final drop = 2.5 * muSpin * gravity / radius * dt;
  final z = spin.z.abs() <= drop ? 0.0 : spin.z - spin.z.sign * drop;
  return Vec3(spin.x, spin.y, z);
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `"$FLUTTER" test test/domain/table_physics/cloth_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics/cloth.dart test/domain/table_physics/cloth_test.dart
git commit -m "Move a ball on the cloth: friction curves a sliding ball, it rolls at five sevenths, and vertical spin dies away

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The cushion

**Files:**
- Create: `lib/domain/table_physics/cushion.dart`
- Test: `test/domain/table_physics/cushion_test.dart`

**Interfaces:**
- Consumes: `BallState`, `Vec3`, constants (Task 1); `strikeCue` (Task 2, test only).
- Produces: `enum Rail { left, right, top, bottom; final Vec2 outward; }` and `BallState cushionImpact(BallState s, Rail rail, {required double radius})`. The function returns `s` itself when the ball is not moving into the rail.

- [ ] **Step 1: Write the failing test**

`test/domain/table_physics/cushion_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  final onRail = Vec2(table.maxX, 60);

  /// Bi tới băng phải với góc [deg] so với pháp tuyến, đi xuống (+y).
  Vec2 incoming(double deg, double speed) {
    final r = deg * math.pi / 180;
    return Vec2(math.cos(r), math.sin(r)) * speed;
  }

  /// Góc bật so với pháp tuyến, độ; dương là vẫn đi xuống (+y).
  double reboundDeg(BallState s) =>
      math.atan2(s.vel.y, -s.vel.x) * 180 / math.pi;

  test('bi đang rời băng thì không có xung lực', () {
    final s = BallState(pos: onRail, vel: const Vec2(-100, 20));
    expect(cushionImpact(s, Rail.right, radius: radius), same(s));
  });

  test('không xoáy: vận tốc pháp tuyến giảm đúng cushionRestitution', () {
    for (final deg in [0.0, 15.0, 30.0, 45.0, 60.0, 75.0]) {
      final s = BallState(pos: onRail, vel: incoming(deg, 200));
      final out = cushionImpact(s, Rail.right, radius: radius);
      expect(-out.vel.x, closeTo(cushionRestitution * s.vel.x, 1e-9),
          reason: '$deg°');
      expect(out.pos, onRail);
    }
  });

  test('không xoáy: góc bật trong 5° quanh góc tới', () {
    for (final deg in [15.0, 30.0, 45.0, 60.0]) {
      for (final speed in [50.0, 200.0, 600.0]) {
        final s = BallState(pos: onRail, vel: incoming(deg, speed));
        final out = cushionImpact(s, Rail.right, radius: radius);
        expect(reboundDeg(out), closeTo(deg, 5), reason: '$deg° $speed');
      }
    }
  });

  group('áp phê', () {
    /// Bi tới băng [deg]°, mang xoáy đứng của cú áp phê [spin] 1 đầu cơ.
    double rebound(double deg, SideSpin spin) {
      final r = deg * math.pi / 180;
      final struck = strikeCue(
          pos: onRail,
          aimAngle: r,
          power: 25,
          verticalOffset: 0,
          spin: spin,
          elevation: 0);
      final s = BallState(
          pos: onRail,
          vel: incoming(deg, struck.vel.length),
          spin: Vec3(0, 0, struck.spin.z));
      return reboundDeg(cushionImpact(s, Rail.right, radius: radius));
    }

    test('áp phê thuận mở góc, nghịch đóng góc', () {
      // Bi chạy dọc băng về bên phải người đánh (+y khi nhìn theo +x),
      // nên áp phê phải là thuận, trái là nghịch.
      for (final deg in [15.0, 30.0, 45.0, 60.0]) {
        final plain = rebound(deg, const SideSpin.none());
        expect(rebound(deg, const SideSpin(SpinSide.right, 1)),
            greaterThan(plain + 1),
            reason: '$deg° thuận');
        // Từ ~60° bi không xoáy đã trượt suốt trên mũi băng: ma sát
        // Coulomb đã bão hoà, nên nghịch không đóng thêm được (đo được
        // 57.85° không xoáy, 57.78° nghịch) — xem "Deviations from spec"
        // của plan 2026-10-02.
        if (deg > 45) continue;
        expect(rebound(deg, const SideSpin(SpinSide.left, 1)),
            lessThan(plain - 1),
            reason: '$deg° nghịch');
      }
    });
  });

  test('cu lê và trô bật ra khác nhau', () {
    final v = incoming(45, 200);
    final dir = v.normalized;
    final rollAxis = Vec3(-dir.y, dir.x, 0) * (v.length / radius);
    final follow = BallState(pos: onRail, vel: v, spin: rollAxis);
    final draw = BallState(pos: onRail, vel: v, spin: -rollAxis);
    final fOut = cushionImpact(follow, Rail.right, radius: radius);
    final dOut = cushionImpact(draw, Rail.right, radius: radius);
    expect((reboundDeg(fOut) - reboundDeg(dOut)).abs(), greaterThan(0.5));
  });

  test('va băng không bao giờ làm tăng động năng', () {
    for (final deg in [0.0, 20.0, 40.0, 60.0, 80.0]) {
      for (final top in [-2.0, -1.0, 0.0, 1.0, 2.0]) {
        for (final side in [-150.0, -50.0, 0.0, 50.0, 150.0]) {
          final v = incoming(deg, 300);
          final dir = v.normalized;
          final s = BallState(
              pos: onRail,
              vel: v,
              spin: Vec3(-dir.y, dir.x, 0) * (top * v.length / radius) +
                  Vec3(0, 0, side));
          final out = cushionImpact(s, Rail.right, radius: radius);
          expect(out.kineticEnergy(radius),
              lessThanOrEqualTo(s.kineticEnergy(radius)),
              reason: '$deg° top=$top side=$side');
        }
      }
    }
  });

  test('bốn băng đối xứng nhau', () {
    final s = BallState(pos: Vec2(table.maxX, 60), vel: incoming(30, 200));
    final right = cushionImpact(s, Rail.right, radius: radius);
    final mirrored = BallState(
        pos: Vec2(table.minX, 60), vel: Vec2(-s.vel.x, s.vel.y));
    final left = cushionImpact(mirrored, Rail.left, radius: radius);
    expect(left.vel.x, closeTo(-right.vel.x, 1e-9));
    expect(left.vel.y, closeTo(right.vel.y, 1e-9));
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `"$FLUTTER" test test/domain/table_physics/cushion_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/cushion.dart'`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/cushion.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Bốn băng, mỗi băng có pháp tuyến hướng từ bi ra băng.
enum Rail {
  left(Vec2(-1, 0)),
  right(Vec2(1, 0)),
  top(Vec2(0, -1)),
  bottom(Vec2(0, 1));

  const Rail(this.outward);

  final Vec2 outward;
}

/// Xung lực băng lên một bi đang chạm [rail] (spec mục 4.3).
///
/// Mô hình Han 2005 rút gọn. Mũi băng chạm bi ở độ cao `cushionHeight`
/// đường kính, cao hơn tâm bi, nên pháp tuyến tiếp xúc chúi xuống mặt
/// bàn một góc `θ`. Khác Han: bi bị mặt bàn giữ, không đi xuống được,
/// nên chọn xung pháp tuyến để vận tốc pháp tuyến nằm ngang phục hồi
/// đúng `cushionRestitution` — phần thẳng đứng của xung do mặt bàn
/// nhận. Ma sát `cushionFriction` tại điểm chạm, chặn trên bởi điều
/// kiện hết trượt, đổi vận tốc dọc băng và xoáy: đó là chỗ áp phê thuận
/// mở góc, nghịch đóng góc, và trô/cu lê đổi góc bật.
///
/// Xung tính theo đơn vị khối lượng (cm/s), nên không cần `ballMass`.
BallState cushionImpact(BallState s, Rail rail, {required double radius}) {
  final n = rail.outward;
  final approach = s.vel.dot(n);
  if (approach <= 0) return s;

  const sinT = 2 * cushionHeight - 1;
  final cosT = math.sqrt(1 - sinT * sinT);
  final n3 = Vec3.flat(n);
  final toContact = (n3 * cosT + Vec3.up * sinT) * radius;
  final normal = -(n3 * cosT + Vec3.up * sinT);

  final impulseN = (1 + cushionRestitution) * approach / cosT;

  final vContact = Vec3.flat(s.vel) + s.spin.cross(toContact);
  final slip = vContact - normal * vContact.dot(normal);
  final slipSpeed = slip.length;
  // Một xung tiếp tuyến J đổi vận tốc điểm chạm 7/2·J (bi đặc), nên
  // 2/7 vận tốc trượt là vừa đủ để hết trượt.
  final impulseT = slipSpeed == 0
      ? 0.0
      : math.min(cushionFriction * impulseN, slipSpeed * 2 / 7);
  final friction =
      slipSpeed == 0 ? Vec3.zero : slip * (-impulseT / slipSpeed);

  final impulse = normal * impulseN + friction;
  // Vận tốc pháp tuyến chỉ do phục hồi quyết định: phần ma sát chĩa ra
  // khỏi băng (do pháp tuyến tiếp xúc nghiêng) cũng do mặt bàn và băng
  // nhận, nếu không bi bật ra nhanh hơn `cushionRestitution` cho phép.
  final along = Vec2(-n.y, n.x);
  return BallState(
    pos: s.pos,
    vel: s.vel -
        n * ((1 + cushionRestitution) * approach) +
        along * impulse.xy.dot(along),
    spin: s.spin + toContact.cross(impulse) * (2.5 / (radius * radius)),
  );
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `"$FLUTTER" test test/domain/table_physics/cushion_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics/cushion.dart test/domain/table_physics/cushion_test.dart
git commit -m "Bounce a ball off a cushion whose nose sits above its centre, so running english opens the angle and reverse english closes it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Ball–ball collision with throw

**Files:**
- Create: `lib/domain/table_physics/ball_collision.dart`
- Test: `test/domain/table_physics/ball_collision_test.dart`

**Interfaces:**
- Consumes: `BallState`, `Vec3`, constants (Task 1); `strikeCue` (Task 2, test only).
- Produces: `double throwFriction(double slipSpeed)` (cm/s in, converted to m/s for `throwFrictionC`) and `(BallState, BallState) collideBalls(BallState a, BallState b, {required double radius})`. It returns the same two objects when the balls are not closing on each other.

- [ ] **Step 1: Write the failing test**

`test/domain/table_physics/ball_collision_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_collision.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

void main() {
  final radius = TableSpec.nineFoot.radius;

  // Ba mức tốc độ trong đồ thị ném của Alciatore (TP A.14): 1, 3, 7 mph.
  const slow = 44.7;
  const medium = 134.1;
  const fast = 312.9;

  /// Bi cái đi theo +x, chạm bi mục tiêu ở góc cắt [cutDeg] (dương: bi
  /// mục tiêu nằm bên phải, đi sang phải).
  (BallState, BallState) hit(double cutDeg, double speed,
      {Vec3 spin = Vec3.zero}) {
    final r = cutDeg * math.pi / 180;
    final cue = BallState(pos: Vec2.zero, vel: Vec2(speed, 0), spin: spin);
    final object =
        BallState(pos: Vec2(math.cos(r), math.sin(r)) * (2 * radius));
    return collideBalls(cue, object, radius: radius);
  }

  /// Góc ném, độ: hướng bi mục tiêu đi so với đường nối tâm; dương là
  /// lệch sang phải.
  double throwDeg(double cutDeg, BallState object) {
    final r = cutDeg * math.pi / 180;
    return Vec2(math.cos(r), math.sin(r)).signedAngleTo(object.vel) *
        180 /
        math.pi;
  }

  /// Xoáy đứng của cú áp phê [spin] ở tốc độ [speed], cơ nằm ngang.
  Vec3 englishOf(SideSpin spin, double speed) {
    final s = strikeCue(
        pos: Vec2.zero,
        aimAngle: 0,
        power: 100 * speed / maxCueSpeed,
        verticalOffset: 0,
        spin: spin,
        elevation: 0);
    return Vec3(0, 0, s.spin.z);
  }

  test('bắn thẳng không xoáy: chia vận tốc theo ballRestitution, không ném',
      () {
    final (cue, object) = hit(0, 300);
    expect(object.vel.x, closeTo((1 + ballRestitution) / 2 * 300, 1e-9));
    expect(cue.vel.x, closeTo((1 - ballRestitution) / 2 * 300, 1e-9));
    expect(object.vel.y.abs(), lessThan(1e-9));
  });

  test('hai bi đang rời nhau thì không va chạm', () {
    const cue = BallState(pos: Vec2.zero, vel: Vec2(-100, 0));
    final object = BallState(pos: Vec2(2 * radius, 0));
    final (c, o) = collideBalls(cue, object, radius: radius);
    expect(c, same(cue));
    expect(o, same(object));
  });

  test('cắt nửa bi, lực vừa: ném trong khoảng Alciatore 2–4°', () {
    final (_, object) = hit(30, medium);
    expect(throwDeg(30, object).abs(), inInclusiveRange(2, 4));
  });

  test('ném giảm khi lực tăng', () {
    final throws = [
      for (final v in [slow, medium, fast]) throwDeg(30, hit(30, v).$2).abs(),
    ];
    expect(throws[0], greaterThan(throws[1]));
    expect(throws[1], greaterThan(throws[2]));
  });

  test('ném do góc cắt kéo bi mục tiêu về phía hướng bi cái đi (cắt mỏng đi)',
      () {
    expect(throwDeg(30, hit(30, medium).$2), lessThan(0));
    expect(throwDeg(-30, hit(-30, medium).$2), greaterThan(0));
  });

  test('bắn thẳng có áp phê: bi mục tiêu bị ném ngược phía áp phê', () {
    final right =
        hit(0, medium, spin: englishOf(const SideSpin(SpinSide.right, 1), medium));
    final left =
        hit(0, medium, spin: englishOf(const SideSpin(SpinSide.left, 1), medium));
    expect(throwDeg(0, right.$2), lessThan(0));
    expect(throwDeg(0, left.$2), greaterThan(0));
  });

  test('áp phê ngoài làm giảm ném khi cắt', () {
    // Cắt sang phải (bi mục tiêu đi phải) thì áp phê ngoài là áp phê trái.
    final plain = throwDeg(30, hit(30, medium).$2).abs();
    final outside = throwDeg(
            30,
            hit(30, medium,
                    spin: englishOf(
                        const SideSpin(SpinSide.left, 0.5), medium))
                .$2)
        .abs();
    expect(outside, lessThan(plain));
  });

  test('bảo toàn động lượng ngang, không tăng động năng', () {
    for (final cut in [0.0, 15.0, 30.0, 45.0, 60.0, 80.0]) {
      for (final top in [-1.0, 0.0, 1.0]) {
        for (final side in [-100.0, 0.0, 100.0]) {
          const v = 250.0;
          final spin = Vec3(0, top * v / radius, side);
          final r = cut * math.pi / 180;
          final a = BallState(pos: Vec2.zero, vel: const Vec2(v, 0), spin: spin);
          final b = BallState(pos: Vec2(math.cos(r), math.sin(r)) * (2 * radius));
          final (c, o) = collideBalls(a, b, radius: radius);
          final momentum = c.vel + o.vel;
          expect(momentum.distanceTo(const Vec2(v, 0)), lessThan(1e-9));
          expect(c.kineticEnergy(radius) + o.kineticEnergy(radius),
              lessThanOrEqualTo(a.kineticEnergy(radius)),
              reason: 'cắt $cut° top=$top side=$side');
        }
      }
    }
  });

  test('ma sát truyền một ít xoáy sang bi mục tiêu', () {
    final (_, object) = hit(30, medium);
    expect(object.spin.length, greaterThan(0));
  });

  test('hệ số ma sát bi–bi đúng công thức, đổi cm/s ra m/s', () {
    expect(throwFriction(100),
        throwFrictionA + throwFrictionB * math.exp(-throwFrictionC));
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `"$FLUTTER" test test/domain/table_physics/ball_collision_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/ball_collision.dart'`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/ball_collision.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/vec3.dart';

/// Ma sát bi–bi ở vận tốc trượt [slipSpeed] cm/s (Alciatore TP A.14).
double throwFriction(double slipSpeed) =>
    throwFrictionA +
    throwFrictionB * math.exp(-throwFrictionC * slipSpeed / 100);

/// Va chạm hai bi cùng khối lượng đang chạm nhau (spec mục 4.4).
///
/// Trả nguyên hai bi khi chúng không lao vào nhau. Xung pháp tuyến phục
/// hồi `ballRestitution`. Ma sát tại điểm chạm — hệ số [throwFriction],
/// chặn trên bởi điều kiện hết trượt — đẩy bi [b] lệch khỏi đường nối
/// tâm: đó là ném (CIT do góc cắt, SIT do áp phê). Cùng ma sát đó tạo
/// mô-men như nhau lên cả hai bi; phần thẳng đứng của xung do mặt bàn
/// nhận, nhưng mô-men của nó vẫn truyền một ít xoáy.
(BallState, BallState) collideBalls(
  BallState a,
  BallState b, {
  required double radius,
}) {
  final n = (b.pos - a.pos).normalized;
  final approach = (a.vel - b.vel).dot(n);
  if (approach <= 0) return (a, b);

  final impulseN = (1 + ballRestitution) / 2 * approach;

  final n3 = Vec3.flat(n);
  final toContact = n3 * radius;
  final rel = Vec3.flat(a.vel) +
      a.spin.cross(toContact) -
      (Vec3.flat(b.vel) + b.spin.cross(-toContact));
  final slip = rel - n3 * rel.dot(n3);
  final slipSpeed = slip.length;
  // Hai bi đặc: một xung tiếp tuyến J đổi vận tốc trượt 7·J, nên 1/7 vận
  // tốc trượt là vừa đủ để hết trượt.
  final impulseT = slipSpeed == 0
      ? 0.0
      : math.min(throwFriction(slipSpeed) * impulseN, slipSpeed / 7);
  final friction =
      slipSpeed == 0 ? Vec3.zero : slip * (-impulseT / slipSpeed);

  final onA = friction - n3 * impulseN;
  final turn = toContact.cross(friction) * (2.5 / (radius * radius));
  return (
    BallState(pos: a.pos, vel: a.vel + onA.xy, spin: a.spin + turn),
    BallState(pos: b.pos, vel: b.vel - onA.xy, spin: b.spin + turn),
  );
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `"$FLUTTER" test test/domain/table_physics/ball_collision_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics/ball_collision.dart test/domain/table_physics/ball_collision_test.dart
git commit -m "Collide two balls with speed-dependent friction, so the object ball is thrown off the line of centres

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `simulateShot` — the event loop, rails, pockets, the trace and its simplification

**Files:**
- Create: `lib/domain/table_physics/simulate_shot.dart`
- Test: `test/domain/table_physics/simulate_shot_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–5; `Pocket`, `TableSpec.pocketPosition/captureRadius`, `distanceToSegment` (`path_clear.dart`); `gridShots()` (`test/support/table_layouts.dart`, test only).
- Produces:
  - `class ShotInput { const ShotInput({required Vec2 cue, required Vec2 object, required double aimAngle, required double power, double verticalOffset = 0, SideSpin spin = const SideSpin.none(), double elevation = 0, TableSpec table = TableSpec.nineFoot}); ShotInput copyWith({double? aimAngle, double? verticalOffset}); }`
  - `enum ShotBall { cue, object }`
  - `class RailHit { const RailHit({required ShotBall ball, required Vec2 pos, required Rail rail, required bool afterContact}); == hashCode }`
  - `class ShotTrace { const ShotTrace({required List<Vec2> cueBefore, required List<Vec2> cueAfter, required List<Vec2> objectPath, required Vec2? contactCue, required List<RailHit> rails, required Pocket? cuePocket, required Pocket? objectPocket, required Vec2 cueEnd}); bool get bankUsed; int get cueRailCount; }`
  - `class SimulationTimeout implements Exception { final ShotInput input; }`
  - `class ContactProbe { const ContactProbe({required BallState cueAtContact, required BallState objectAfter}); }`
  - `ShotTrace simulateShot(ShotInput input, {void Function(BallState cue, BallState object)? onStep})`
  - `ContactProbe? probeContact(ShotInput input)`: null on a miss, a pocketed cue ball, or a rail before the contact.
  - `Pocket? simulateCuePocket(ShotInput input)`: always equal to `simulateShot(input).cuePocket`.

- [ ] **Step 1: Write the failing test**

`test/domain/table_physics/simulate_shot_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  final normal = CueElevation.normal.radians;

  double aimAt(Vec2 from, Vec2 to) => math.atan2(to.y - from.y, to.x - from.x);

  ShotInput shot(
    Vec2 cue,
    Vec2 object, {
    Vec2? toward,
    double power = 45,
    double b = 0,
    SideSpin spin = const SideSpin.none(),
  }) =>
      ShotInput(
        cue: cue,
        object: object,
        aimAngle: aimAt(cue, toward ?? object),
        power: power,
        verticalOffset: b,
        spin: spin,
        elevation: normal,
      );

  bool onBounds(Vec2 p) =>
      p.x == table.minX ||
      p.x == table.maxX ||
      p.y == table.minY ||
      p.y == table.maxY;

  bool atPocket(Vec2 p) =>
      Pocket.values.any((k) => table.pocketPosition(k) == p);

  test('tất định: cùng đầu vào thì trace bằng nhau tuyệt đối', () {
    final input = shot(const Vec2(60, 90), const Vec2(150, 50),
        power: 75, b: strokeOffset * radius,
        spin: const SideSpin(SpinSide.right, 1));
    final a = simulateShot(input);
    final b = simulateShot(input);
    expect(b.cueBefore, a.cueBefore);
    expect(b.cueAfter, a.cueAfter);
    expect(b.objectPath, a.objectPath);
    expect(b.rails, a.rails);
    expect(b.contactCue, a.contactCue);
    expect(b.cueEnd, a.cueEnd);
    expect(b.cuePocket, a.cuePocket);
    expect(b.objectPocket, a.objectPocket);
  });

  group('cueEnd là đúng đối tượng cuối của đường bi cái', () {
    test('có va chạm', () {
      final t = simulateShot(shot(const Vec2(60, 90), const Vec2(150, 50)));
      expect(t.contactCue, isNotNull);
      expect(identical(t.cueEnd, t.cueAfter.last), isTrue);
      expect(identical(t.cueAfter.first, t.contactCue), isTrue);
      expect(identical(t.cueBefore.last, t.contactCue), isTrue);
    });

    test('trượt bi mục tiêu', () {
      final t = simulateShot(shot(const Vec2(60, 90), const Vec2(150, 50),
          toward: const Vec2(150, 110), power: 30));
      expect(t.contactCue, isNull);
      expect(t.cueAfter, isEmpty);
      expect(identical(t.cueEnd, t.cueBefore.last), isTrue);
      expect(t.objectPath, [const Vec2(150, 50)]);
    });
  });

  group('trô và cu lê sau va chạm', () {
    test('cu lê cắt nửa bi, bi cái đang lăn: hướng cuối lệch 30° ± 3° (quy tắc 30°)',
        () {
      for (final power in [30.0, 45.0]) {
        // Bi cái đi theo +x, cách 60 cm — đủ để lăn đều trước khi chạm.
        // Bi mục tiêu lệch khỏi đường cơ đúng một bán kính: cắt nửa bi.
        const cue = Vec2(30, 100);
        final object = Vec2(90, 100 + radius);
        Vec2? rolling;
        var hit = false;
        final t = simulateShot(
          ShotInput(
              cue: cue,
              object: object,
              aimAngle: 0,
              power: power,
              verticalOffset: strokeOffset * radius,
              elevation: normal),
          onStep: (c, o) {
            if (o.vel.length > 0) hit = true;
            if (hit &&
                rolling == null &&
                c.vel.length > 0 &&
                c.slip(radius).length <= rollingSlip) {
              rolling = c.vel;
            }
          },
        );
        final deg = const Vec2(1, 0).signedAngleTo(rolling!).abs() * 180 / math.pi;
        expect(deg, closeTo(30, 3), reason: '$power%');
        // Có đoạn cong rồi mới thẳng: còn hơn hai điểm trước băng đầu.
        expect(t.cueAfter.length, greaterThan(3));
      }
    });

    test('trô bắn thẳng: bi cái lùi lại trên đường cơ', () {
      const cue = Vec2(60, 63.5);
      const object = Vec2(160, 63.5);
      final t = simulateShot(ShotInput(
          cue: cue,
          object: object,
          aimAngle: 0,
          power: 30,
          verticalOffset: -strokeOffset * radius,
          elevation: normal));
      expect(t.cueEnd.x, lessThan(t.contactCue!.x - 10));
      for (final p in t.cueAfter) {
        expect((p.y - cue.y).abs(), lessThan(0.5), reason: '$p');
      }
    });

    test('swerve: cùng áp phê, bi cái tới bi mục tiêu lệch ngang nhiều hơn ở cơ Dốc',
        () {
      double lateral(CueElevation e) {
        const cue = Vec2(40, 63.5);
        final input = ShotInput(
            cue: cue,
            object: const Vec2(200, 63.5),
            aimAngle: 0,
            power: 45,
            spin: const SideSpin(SpinSide.right, 1),
            elevation: e.radians);
        final t = simulateShot(input);
        final at = t.contactCue ?? t.cueBefore.last;
        // Đo so với đường lệch do áp phê, để chỉ còn phần cong.
        final squirtLine = const Vec2(1, 0)
            .rotated(-squirtAngle(sideOffsetOf(input.spin), radius));
        return (at - cue).dot(squirtLine.rightNormal);
      }

      expect(lateral(CueElevation.steep), greaterThan(lateral(CueElevation.normal)));
      expect(lateral(CueElevation.normal), greaterThan(0));
    });
  });

  test('đường thẳng rút gọn còn hai điểm, đường cong giữ nhiều điểm', () {
    // Cu lê không áp phê: xoáy dọc không làm cong, bi cái tới bi mục tiêu
    // theo đường thẳng.
    final t = simulateShot(shot(const Vec2(40, 63.5), const Vec2(120, 40),
        b: strokeOffset * radius));
    expect(t.cueBefore, hasLength(2));
    // Cu lê cắt: bi cái sau va chạm cong rồi mới thẳng.
    expect(t.cueAfter.length, greaterThan(3));
  });

  test('bi mục tiêu vào lỗ thì đường của nó kết thúc ở tâm lỗ', () {
    final corner = table.pocketPosition(Pocket.topRight);
    const object = Vec2(200, 30);
    final dir = (corner - object).normalized;
    final ghost = object - dir * table.ballDiameter;
    final t = simulateShot(
        shot(ghost - dir * 40, object, toward: object, power: 45));
    expect(t.objectPocket, Pocket.topRight);
    expect(t.objectPath.last, corner);
  });

  test('bi cái rơi lỗ: chết cái, đường kết thúc ở tâm lỗ', () {
    final corner = table.pocketPosition(Pocket.topLeft);
    final t = simulateShot(shot(const Vec2(60, 40), const Vec2(200, 100),
        toward: corner, power: 45));
    expect(t.cuePocket, Pocket.topLeft);
    expect(t.contactCue, isNull);
    expect(t.cueEnd, corner);
    expect(identical(t.cueEnd, t.cueBefore.last), isTrue);
  });

  test('bi nằm sẵn trong vùng lỗ mà đánh ra xa lỗ thì không rơi', () {
    // Tâm bi cách điểm lỗ dưới cornerCapture nhưng vẫn trên bàn.
    final inZone = Vec2(table.minX + 0.5, table.minY + 0.5);
    expect(inZone.distanceTo(table.pocketPosition(Pocket.topLeft)),
        lessThan(cornerCapture));
    final t = simulateShot(shot(inZone, const Vec2(200, 100),
        toward: const Vec2(120, 60), power: 30));
    expect(t.cuePocket, isNull);
  });

  test('hai bi đặt sát nhau: chạm ngay lúc đánh', () {
    const object = Vec2(150, 60);
    final cue = object - Vec2(table.ballDiameter, 0);
    final t = simulateShot(shot(cue, object));
    expect(t.contactCue, isNotNull);
    expect(t.contactCue!.distanceTo(cue), lessThan(1e-9));
    expect(t.objectPath.length, greaterThan(1));
  });

  test('bi sát băng đánh vào chính băng đó: bật ra, không lọt khỏi bàn', () {
    final cue = Vec2(table.minX, 63.5);
    final t = simulateShot(shot(cue, const Vec2(200, 20),
        toward: const Vec2(0, 63.5), power: 60));
    expect(t.rails.first.pos, cue);
    for (final p in t.cueBefore) {
      expect(table.contains(p), isTrue, reason: '$p');
    }
  });

  test('lực 100 % đánh thẳng vào băng: không xuyên băng với bước 1 ms', () {
    for (final from in [const Vec2(240, 63.5), Vec2(table.maxX, 63.5)]) {
      final t = simulateShot(ShotInput(
          cue: from,
          object: const Vec2(30, 20),
          aimAngle: 0,
          power: 100,
          elevation: normal));
      expect(t.rails, isNotEmpty);
      for (final p in [...t.cueBefore, ...t.cueAfter]) {
        expect(table.contains(p) || atPocket(p), isTrue, reason: '$from $p');
      }
    }
  });

  /// Cu lê cắt mỏng lực 90 %: bi cái chạy 5 băng rồi dừng trong bàn (dò
  /// bằng mô phỏng, không đoán).
  final multiRail = ShotInput(
      cue: const Vec2(80, 30),
      object: const Vec2(127, 63.5),
      aimAngle: aimAt(const Vec2(80, 30), const Vec2(127, 63.5)) + 0.04,
      power: 90,
      verticalOffset: strokeOffset * radius,
      elevation: normal);

  test('bi lăn sát qua bi đang đứng không bị kẹt ở bước dài 0', () {
    // Trên prototype: cu lê 100 %, trái 2 đầu cơ — cuối cú, bi cái lăn
    // chậm tiếp tuyến qua bi mục tiêu đang đứng, đúng khoảng cách 2R. Xét
    // va chạm theo quãng đi trong bước thì nó "lao vào" mãi ở f = 0 và
    // đứng hình tới maxSimTime.
    final g = bestPocket(cue: const Vec2(146, 79), object: const Vec2(220, 78))!;
    final t = simulateShot(ShotInput(
        cue: g.cue,
        object: g.object,
        aimAngle: aimAt(g.cue, g.ghost),
        power: 100,
        verticalOffset: strokeOffset * radius,
        spin: const SideSpin(SpinSide.left, 2),
        elevation: normal));
    expect(table.contains(t.cueEnd) || atPocket(t.cueEnd), isTrue);
  });

  test('điểm chạm băng nằm đúng trên biên, đường đi qua chúng theo thứ tự',
      () {
    final t = simulateShot(multiRail);
    expect(t.rails, isNotEmpty);
    for (final ball in ShotBall.values) {
      final path = ball == ShotBall.cue
          ? [...t.cueBefore, ...t.cueAfter]
          : t.objectPath;
      var from = 0;
      for (final hit in t.rails.where((h) => h.ball == ball)) {
        expect(onBounds(hit.pos), isTrue, reason: '${hit.pos}');
        final at = path.indexOf(hit.pos, from);
        expect(at, greaterThanOrEqualTo(from),
            reason: '${hit.pos} phải nằm trên đường, sau điểm chạm trước');
        from = at;
      }
    }
  });

  test('bi cái chạm từ 3 băng trở lên rồi dừng trong bàn', () {
    final t = simulateShot(multiRail);
    expect(t.cueRailCount, greaterThanOrEqualTo(3));
    expect(t.cuePocket, isNull);
    expect(table.contains(t.cueEnd), isTrue);
  });

  test('động năng hai bi không tăng giữa hai bước (trừ lúc cơ chạm)', () {
    final inputs = [
      multiRail,
      for (final spin in [
        const SideSpin.none(),
        const SideSpin(SpinSide.left, 2),
      ])
        for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius])
          shot(const Vec2(60, 90), const Vec2(150, 50),
              power: 90, b: b, spin: spin),
    ];
    for (final input in inputs) {
      var last = double.infinity;
      simulateShot(
        input,
        onStep: (cue, object) {
          final e = cue.kineticEnergy(radius) + object.kineticEnergy(radius);
          // Dung sai làm tròn khi ép lăn đều đúng lúc hết trượt.
          expect(e, lessThanOrEqualTo(last * (1 + 1e-9)),
              reason: '${input.spin} b=${input.verticalOffset}');
          last = e;
        },
      );
    }
  });

  test('lưới vị trí × kiểu đánh × áp phê × lực: mọi cú dừng trước maxSimTime',
      () {
    final shots = gridShots().toList();
    var count = 0;
    for (var i = 0; i < shots.length; i += 3) {
      final g = shots[i];
      for (final b in [-strokeOffset * radius, 0.0, strokeOffset * radius]) {
        for (final spin in [
          const SideSpin.none(),
          const SideSpin(SpinSide.right, 1),
          const SideSpin(SpinSide.left, 2),
        ]) {
          for (final power in [30.0, 90.0, 100.0]) {
            final t = simulateShot(ShotInput(
                cue: g.cue,
                object: g.object,
                aimAngle: aimAt(g.cue, g.ghost),
                power: power,
                verticalOffset: b,
                spin: spin,
                elevation: normal));
            count++;
            expect(table.contains(t.cueEnd) || atPocket(t.cueEnd), isTrue,
                reason: '${g.cue}→${g.object} b=$b $spin $power');
          }
        }
      }
    }
    expect(count, greaterThan(500));
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `"$FLUTTER" test test/domain/table_physics/simulate_shot_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/simulate_shot.dart'`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/simulate_shot.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_collision.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cloth.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Một cú đánh: hai bi, hướng cơ, lực, điểm đặt cơ, độ dốc cơ.
class ShotInput {
  const ShotInput({
    required this.cue,
    required this.object,
    required this.aimAngle,
    required this.power,
    this.verticalOffset = 0,
    this.spin = const SideSpin.none(),
    this.elevation = 0,
    this.table = TableSpec.nineFoot,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Hướng cơ trên mặt bàn, radian.
  final double aimAngle;

  /// %.
  final double power;

  /// `b`, cm, dương là trên tâm.
  final double verticalOffset;
  final SideSpin spin;

  /// Độ dốc cơ, radian.
  final double elevation;
  final TableSpec table;

  ShotInput copyWith({double? aimAngle, double? verticalOffset}) => ShotInput(
        cue: cue,
        object: object,
        aimAngle: aimAngle ?? this.aimAngle,
        power: power,
        verticalOffset: verticalOffset ?? this.verticalOffset,
        spin: spin,
        elevation: elevation,
        table: table,
      );
}

enum ShotBall { cue, object }

/// Một lần chạm băng: bi nào, ở đâu (đúng trên biên), băng nào, và có
/// sau va chạm bi cái–bi mục tiêu không.
class RailHit {
  const RailHit({
    required this.ball,
    required this.pos,
    required this.rail,
    required this.afterContact,
  });

  final ShotBall ball;
  final Vec2 pos;
  final Rail rail;
  final bool afterContact;

  @override
  bool operator ==(Object other) =>
      other is RailHit &&
      other.ball == ball &&
      other.pos == pos &&
      other.rail == rail &&
      other.afterContact == afterContact;

  @override
  int get hashCode => Object.hash(ball, pos, rail, afterContact);
}

/// Kết quả mô phỏng một cú đánh (spec mục 4.5).
class ShotTrace {
  const ShotTrace({
    required this.cueBefore,
    required this.cueAfter,
    required this.objectPath,
    required this.contactCue,
    required this.rails,
    required this.cuePocket,
    required this.objectPocket,
    required this.cueEnd,
  });

  /// Bi cái từ lúc đánh tới lúc chạm bi mục tiêu.
  final List<Vec2> cueBefore;

  /// Bi cái sau va chạm tới khi dừng hoặc rơi lỗ; rỗng nếu trượt bi.
  final List<Vec2> cueAfter;

  /// Bi mục tiêu từ chỗ đứng tới khi dừng hoặc rơi lỗ.
  final List<Vec2> objectPath;

  /// Tâm bi cái lúc chạm (Bi ảo thật); null nếu trượt bi mục tiêu.
  final Vec2? contactCue;

  /// Mọi lần chạm băng, theo thứ tự thời gian.
  final List<RailHit> rails;

  /// Chết cái: lỗ bi cái rơi vào.
  final Pocket? cuePocket;

  /// Lỗ bi mục tiêu rơi vào; null là không vào.
  final Pocket? objectPocket;

  /// Điểm dừng bi cái — đúng đối tượng cuối của [cueAfter] (hoặc của
  /// [cueBefore] khi trượt bi). Planner dùng làm `cbFrom`, không tính lại.
  final Vec2 cueEnd;

  /// Bi cái chạm băng sau va chạm.
  bool get bankUsed => cueRailCount > 0;

  /// Số lần bi cái chạm băng sau va chạm.
  int get cueRailCount =>
      rails.where((h) => h.ball == ShotBall.cue && h.afterContact).length;
}

/// Mô phỏng chạy quá `maxSimTime` — lỗi của lõi, không phải kết quả.
class SimulationTimeout implements Exception {
  const SimulationTimeout(this.input);
  final ShotInput input;

  @override
  String toString() => 'SimulationTimeout: quá $maxSimTime s';
}

/// Hai bi ngay quanh lúc chạm, cho `aimShot` dò.
class ContactProbe {
  const ContactProbe({required this.cueAtContact, required this.objectAfter});

  /// Bi cái ngay trước va chạm.
  final BallState cueAtContact;

  /// Bi mục tiêu ngay sau va chạm.
  final BallState objectAfter;
}

/// Mô phỏng tới khi cả hai bi đứng hẳn hoặc rơi lỗ (spec mục 4.5).
///
/// Tất định: cùng [input] thì cùng trace. [onStep] (cho test) nhận trạng
/// thái hai bi sau mỗi bước.
ShotTrace simulateShot(
  ShotInput input, {
  void Function(BallState cue, BallState object)? onStep,
}) {
  final run = _Run(input, record: true, onStep: onStep);
  run.go(untilContact: false);
  return run.trace();
}

/// Chỉ mô phỏng tới lúc bi cái chạm thẳng bi mục tiêu; null nếu trượt
/// bi, rơi lỗ, hoặc chạm băng trước (cú dội băng không phải cú đang dò).
///
/// Rẻ hơn [simulateShot] nhiều, nên `aimShot` dùng nó để dò.
ContactProbe? probeContact(ShotInput input) {
  final run = _Run(input, record: false);
  run.go(untilContact: true);
  return run.rails.isEmpty ? run.probe : null;
}

/// Chỉ cần biết bi cái có rơi lỗ không: mô phỏng đủ nhưng không ghi
/// đường đi. Cùng kết quả với `simulateShot(input).cuePocket`.
Pocket? simulateCuePocket(ShotInput input) {
  final run = _Run(input, record: false);
  run.go(untilContact: false);
  return run.cue.pocket;
}

class _Ball {
  _Ball(this.state, {required this.moving});

  BallState state;
  bool moving;
  Pocket? pocket;
  List<Vec2> samples = [];

  /// Chỉ số các điểm phải giữ khi rút gọn (điểm chạm băng, chạm bi, lỗ).
  List<int> keep = [];

  bool get inPlay => pocket == null;

  void record(Vec2 p, {bool pinned = false}) {
    if (pinned) keep.add(samples.length);
    samples.add(p);
  }
}

enum _Event { none, balls, rail }

class _Run {
  _Run(this.input, {required this.record, this.onStep})
      : table = input.table,
        radius = input.table.radius,
        cue = _Ball(
          strikeCue(
            pos: input.cue,
            aimAngle: input.aimAngle,
            power: input.power,
            verticalOffset: input.verticalOffset,
            spin: input.spin,
            elevation: input.elevation,
            table: input.table,
          ),
          moving: input.power > 0,
        ),
        object = _Ball(BallState(pos: input.object), moving: false) {
    if (record) {
      cue.record(input.cue);
      object.record(input.object);
    }
  }

  final ShotInput input;
  final bool record;
  final void Function(BallState, BallState)? onStep;
  final TableSpec table;
  final double radius;
  final _Ball cue;
  final _Ball object;

  /// Đường bi cái trước va chạm; khi đã chạm thì [cue] ghi tiếp phần sau.
  _Ball? before;
  Vec2? contact;
  ContactProbe? probe;
  final rails = <RailHit>[];

  void go({required bool untilContact}) {
    var steps = 0;
    final maxSteps = (maxSimTime / timeStep).round();
    while (cue.moving || object.moving) {
      if (steps++ >= maxSteps) throw SimulationTimeout(input);
      _step();
      if (untilContact && (contact != null || rails.isNotEmpty)) return;
      for (final ball in [cue, object]) {
        if (!ball.moving) continue;
        if (ball.state.isStopped) {
          ball.state = BallState(pos: ball.state.pos);
          ball.moving = false;
        }
        if (record) ball.record(ball.state.pos);
      }
      onStep?.call(cue.state, object.state);
    }
  }

  void _step() {
    var left = timeStep;
    // Một bước có thể chứa vài sự kiện (chạm băng rồi chạm bi); trần
    // này chỉ chặn vòng lặp vô hạn nếu số học hỏng.
    for (var events = 0; left > 0 && events < 8; events++) {
      final c1 = cue.moving ? _advance(cue.state, left) : cue.state;
      final o1 = object.moving ? _advance(object.state, left) : object.state;

      var f = 1.0;
      var event = _Event.none;
      _Ball? railBall;
      Rail? rail;

      if (cue.inPlay && object.inPlay) {
        final fb = _ballsMeet(cue.state, c1.pos, object.state, o1.pos);
        if (fb != null && fb < f) {
          f = fb;
          event = _Event.balls;
        }
      }
      for (final (ball, end) in [(cue, c1), (object, o1)]) {
        if (!ball.moving) continue;
        final hit = _railCrossing(ball.state, end.pos);
        if (hit != null && hit.$1 < f) {
          f = hit.$1;
          event = _Event.rail;
          railBall = ball;
          rail = hit.$2;
        }
      }

      if (f == 1) {
        cue.state = c1;
        object.state = o1;
        left = 0;
      } else {
        final dt = left * f;
        if (cue.moving) cue.state = _advance(cue.state, dt);
        if (object.moving) object.state = _advance(object.state, dt);
        left -= dt;
      }

      // Lọt vùng lỗ thì rơi lỗ trước khi xét băng hay bi kia.
      for (final ball in [cue, object]) {
        if (ball.moving) _checkPocket(ball);
      }

      switch (event) {
        case _Event.none:
          break;
        case _Event.balls:
          if (cue.inPlay && object.inPlay) _collide();
        case _Event.rail:
          final ball = railBall!;
          if (ball.inPlay) _bounce(ball, rail!);
      }
      for (final ball in [cue, object]) {
        if (ball.moving) _keepOnTable(ball);
      }
    }
  }

  BallState _advance(BallState s, double dt) =>
      clothStep(s, dt, radius: radius);

  /// Phần bước (0–1) tại đó hai tâm bi cách nhau đúng 2R, coi chuyển
  /// động tương đối trong bước là thẳng; null nếu không lao vào nhau.
  double? _ballsMeet(BallState c0, Vec2 c1, BallState o0, Vec2 o1) {
    final d0 = o0.pos - c0.pos;
    final delta = (o1 - c1) - d0;
    final a = delta.dot(delta);
    final b = 2 * d0.dot(delta);
    final c = d0.dot(d0) - 4 * radius * radius;
    if (b >= 0 || a == 0) return null;
    // Đã chạm sẵn (đặt sát nhau, hoặc vừa va xong): chỉ va khi vận tốc
    // thật sự lao vào nhau. Xét theo quãng đi trong bước thì một bi lăn
    // sát qua bi kia có thể "lao vào" vì sai số, rồi kẹt mãi ở f = 0.
    if (c <= 0) return (c0.vel - o0.vel).dot(d0) > 0 ? 0 : null;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final f = (-b - math.sqrt(disc)) / (2 * a);
    return f <= 1 ? f : null;
  }

  /// Phần bước (0–1) tại đó tâm bi chạm biên, và băng nào.
  ///
  /// Bi đang nằm trên biên mà vận tốc không lao vào băng (chạy sát băng,
  /// swerve ép ra ngoài) thì không phải va băng: [_keepOnTable] giữ nó
  /// lại trên biên.
  (double, Rail)? _railCrossing(BallState s0, Vec2 p1) {
    final p0 = s0.pos;
    (double, Rail)? best;
    void consider(double from, double to, double bound, Rail rail) {
      if (from == bound && s0.vel.dot(rail.outward) <= 0) return;
      final f = ((bound - from) / (to - from)).clamp(0.0, 1.0);
      if (best == null || f < best!.$1) best = (f, rail);
    }

    if (p1.x > table.maxX) consider(p0.x, p1.x, table.maxX, Rail.right);
    if (p1.x < table.minX) consider(p0.x, p1.x, table.minX, Rail.left);
    if (p1.y > table.maxY) consider(p0.y, p1.y, table.maxY, Rail.bottom);
    if (p1.y < table.minY) consider(p0.y, p1.y, table.minY, Rail.top);
    return best;
  }

  /// Bi chạy sát băng mà bị đẩy ra ngoài biên: kéo về đúng biên và bỏ
  /// phần vận tốc chĩa ra ngoài — băng chặn lại, không có cú va.
  void _keepOnTable(_Ball ball) {
    final s = ball.state;
    if (table.contains(s.pos)) return;
    var vel = s.vel;
    for (final rail in Rail.values) {
      final out = vel.dot(rail.outward);
      final beyond = switch (rail) {
        Rail.left => s.pos.x < table.minX,
        Rail.right => s.pos.x > table.maxX,
        Rail.top => s.pos.y < table.minY,
        Rail.bottom => s.pos.y > table.maxY,
      };
      if (beyond && out > 0) vel = vel - rail.outward * out;
    }
    ball.state = s.copyWith(pos: table.clamp(s.pos), vel: vel);
  }

  void _checkPocket(_Ball ball) {
    final s = ball.state;
    for (final pocket in Pocket.values) {
      final at = table.pocketPosition(pocket);
      // Bi nằm sẵn trong vùng lỗ mà đang đi ra thì chưa rơi: ngoài bàn
      // thật bi đó đang nằm trên mép lỗ.
      if (s.pos.distanceTo(at) <= table.captureRadius(pocket) &&
          s.vel.dot(at - s.pos) > 0) {
        ball.pocket = pocket;
        ball.moving = false;
        ball.state = BallState(pos: at);
        if (record) ball.record(at, pinned: true);
        return;
      }
    }
  }

  void _bounce(_Ball ball, Rail rail) {
    final p = ball.state.pos;
    // Điểm chạm nằm đúng trên biên, không lệch vì số học.
    final snapped = switch (rail) {
      Rail.left => Vec2(table.minX, p.y),
      Rail.right => Vec2(table.maxX, p.y),
      Rail.top => Vec2(p.x, table.minY),
      Rail.bottom => Vec2(p.x, table.maxY),
    };
    ball.state = cushionImpact(ball.state.copyWith(pos: snapped), rail,
        radius: radius);
    rails.add(RailHit(
      ball: ball == cue ? ShotBall.cue : ShotBall.object,
      pos: snapped,
      rail: rail,
      afterContact: contact != null,
    ));
    if (record) ball.record(snapped, pinned: true);
  }

  void _collide() {
    final cueBefore = cue.state;
    final (c, o) = collideBalls(cue.state, object.state, radius: radius);
    if (identical(c, cue.state)) return;
    cue.state = c;
    object.state = o;
    object.moving = true;
    cue.moving = true;
    if (contact != null) return;
    final at = cueBefore.pos;
    contact = at;
    probe = ContactProbe(cueAtContact: cueBefore, objectAfter: o);
    if (record) {
      cue.record(at, pinned: true);
      // Từ đây bi cái ghi vào đường sau va chạm, bắt đầu đúng tại bi ảo.
      before = _Ball(cueBefore, moving: false)
        ..samples = cue.samples
        ..keep = cue.keep;
      cue
        ..samples = [at]
        ..keep = [0];
    }
  }

  ShotTrace trace() {
    final beforeBall = before;
    final cueBefore = _simplify(beforeBall ?? cue);
    final cueAfter = beforeBall == null ? const <Vec2>[] : _simplify(cue);
    return ShotTrace(
      cueBefore: cueBefore,
      cueAfter: cueAfter,
      objectPath: _simplify(object),
      contactCue: contact,
      rails: List.unmodifiable(rails),
      cuePocket: cue.pocket,
      objectPocket: object.pocket,
      cueEnd: cueAfter.isEmpty ? cueBefore.last : cueAfter.last,
    );
  }
}

/// Rút gọn chuỗi điểm mỗi bước: bỏ điểm lệch khỏi đoạn thẳng nối hai
/// điểm giữ lại dưới `pathTolerance` (Douglas–Peucker). Đường thẳng còn
/// hai điểm, đường cong giữ đủ để vẽ mượt. Điểm chạm băng, điểm chạm bi
/// và hai đầu giữ nguyên đối tượng — `cueEnd` dựa vào điều đó.
List<Vec2> _simplify(_Ball ball) {
  final pts = ball.samples;
  if (pts.length <= 2) return List.unmodifiable(pts);
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  for (final i in ball.keep) {
    keep[i] = true;
  }
  var start = 0;
  for (var i = 1; i < pts.length; i++) {
    if (!keep[i]) continue;
    _douglasPeucker(pts, start, i, keep);
    start = i;
  }
  return List.unmodifiable([
    for (var i = 0; i < pts.length; i++)
      if (keep[i]) pts[i],
  ]);
}

void _douglasPeucker(List<Vec2> pts, int first, int last, List<bool> keep) {
  final stack = <(int, int)>[(first, last)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    if (b - a < 2) continue;
    var worst = -1;
    var worstDist = pathTolerance;
    for (var i = a + 1; i < b; i++) {
      final d = distanceToSegment(pts[i], pts[a], pts[b]);
      if (d >= worstDist) {
        worstDist = d;
        worst = i;
      }
    }
    if (worst < 0) continue;
    keep[worst] = true;
    stack
      ..add((a, worst))
      ..add((worst, b));
  }
}
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `"$FLUTTER" test test/domain/table_physics/simulate_shot_test.dart`
Expected: `All tests passed!` in about 40 s. The grid test runs more than 500 full simulations, up to 100 % power.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics/simulate_shot.dart test/domain/table_physics/simulate_shot_test.dart
git commit -m "Simulate a two-ball shot step by step until both balls stop or drop, and keep every rail hit exactly on the bounds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `aimShot` — throw compensation, the Đánh đứng bi cue height, and the time budget

**Files:**
- Create: `lib/domain/table_physics/aim.dart`, `dart_test.yaml`
- Test: `test/domain/table_physics/aim_test.dart`, `test/domain/table_physics/aim_perf_test.dart`

**Interfaces:**
- Consumes: `ShotInput`, `ShotTrace`, `probeContact`, `simulateShot` (Task 6); `squirtAngle`, `sideOffsetOf`, `CueElevation.radians` (Task 2); `Stroke`, `SideSpin`, `CueElevation`, `Pocket`, `TableSpec`; `geometryFor`, `gridShots` (test support).
- Produces:
  - `class AimedShot { const AimedShot({required ShotTrace trace, required ShotTrace? uncompensated, required double aimOffsetDeg, required double verticalOffset, required bool converged}); }`
  - `class AimSolution { const AimSolution({required ShotInput aimed, required ShotInput geometric, required bool converged}); double get aimOffsetDeg; }`, where positive means thicker.
  - `AimSolution solveAim({required Vec2 cue, required Vec2 object, required Pocket pocket, required Stroke stroke, required SideSpin spin, required double power, required CueElevation elevation, required TableSpec table, required bool compensate})`
  - `AimedShot aimShot({required Vec2 cue, required Vec2 object, required Pocket pocket, required Stroke stroke, SideSpin spin = const SideSpin.none(), required double power, CueElevation elevation = CueElevation.normal, TableSpec table = TableSpec.nineFoot, bool compensate = true})`
  - `double? topspinAtContact(ShotInput input)`

- [ ] **Step 1: Write the failing tests**

`test/domain/table_physics/aim_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final radius = table.radius;
  const right1 = SideSpin(SpinSide.right, 1);
  const left1 = SideSpin(SpinSide.left, 1);

  AimedShot aim(ShotGeometry g, Stroke stroke,
          {double power = 45,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal,
          bool compensate = true}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: power,
          elevation: elevation,
          compensate: compensate);

  /// Đường thẳng tâm bi mục tiêu → điểm lỗ chạm biên ở trong vùng lỗ:
  /// bi mục tiêu đi đúng hướng thì rơi lỗ trước khi chạm băng. Cú vào
  /// lỗ giữa ở góc quá xiên thì không — ngoài bàn thật cũng thế.
  bool reachesPocketZone(ShotGeometry g) {
    final p = table.pocketPosition(g.pocket);
    final d = (p - g.object).normalized;
    double toBound(double from, double dir, double lo, double hi) => dir > 0
        ? (hi - from) / dir
        : dir < 0
            ? (lo - from) / dir
            : double.infinity;
    final s = math.min(toBound(g.object.x, d.x, table.minX, table.maxX),
        toBound(g.object.y, d.y, table.minY, table.maxY));
    return (g.object + d * s).distanceTo(p) <= table.captureRadius(g.pocket);
  }

  group('bù ném', () {
    test('lưới: có bù thì hội tụ, và bi mục tiêu vào đúng lỗ đã chọn', () {
      final shots = gridShots().toList();
      var checked = 0;
      for (var i = 0; i < shots.length; i += 4) {
        final g = shots[i];
        for (final stroke in Stroke.values) {
          for (final spin in [
            const SideSpin.none(),
            right1,
            const SideSpin(SpinSide.left, 2),
          ]) {
            for (final power in [30.0, 90.0]) {
              final a = aim(g, stroke, power: power, spin: spin);
              final where = '${g.cue}→${g.object} $stroke $spin $power';
              expect(a.converged, isTrue, reason: where);
              if (!reachesPocketZone(g)) continue;
              checked++;
              expect(a.trace.objectPocket, g.pocket, reason: where);
            }
          }
        }
      }
      expect(checked, greaterThan(1000));
    });

    test('ngay sau va chạm bi mục tiêu chạy vào tâm lỗ, sai dưới aimTolerance',
        () {
      final g = geometryFor(const Vec2(180, 40), Pocket.topRight, 30);
      final s = solveAim(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.follow,
          spin: right1,
          power: 45,
          elevation: CueElevation.normal,
          table: table,
          compensate: true);
      final probe = probeContact(s.aimed)!;
      final error = probe.objectAfter.vel
              .signedAngleTo(table.pocketPosition(g.pocket) - g.object)
              .abs() *
          180 /
          math.pi;
      expect(error, lessThan(aimTolerance));
    });

    test('không áp phê, cắt góc: ném làm bi mục tiêu mỏng đi nên ngắm mỏng hơn',
        () {
      for (final cut in [15.0, 30.0, 45.0, 60.0]) {
        final a = aim(geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut),
            Stroke.stun);
        expect(a.aimOffsetDeg, lessThan(0), reason: '$cut°');
      }
    });

    test('tắt bù, có áp phê: bi mục tiêu lệch đúng chiều, đối xứng hai bên',
        () {
      // Bắn thẳng, 40 cm: áp phê phải làm bi cái lệch sang trái, chạm vào
      // nửa trái bi mục tiêu, nên bi mục tiêu đi lệch sang phải; trái
      // ngược lại. Swerve ở cơ Thường kéo về một phần, không đổi chiều.
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 0);
      double deviation(SideSpin spin) {
        final t = aim(g, Stroke.follow, spin: spin, compensate: false).trace;
        final dir = t.objectPath[1] - t.objectPath[0];
        return g.objectDir.signedAngleTo(dir) * 180 / math.pi;
      }

      final right = deviation(right1);
      final left = deviation(left1);
      expect(right, greaterThan(1));
      // Bàn không đối xứng qua đường bắn nên chỉ gần bằng nhau.
      expect(left, closeTo(-right, 0.01));
    });

    test('đường đỏ là đúng cú ngắm thẳng vào Bi ảo hình học', () {
      final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 20);
      final on = aim(g, Stroke.follow, spin: right1);
      final off = aim(g, Stroke.follow, spin: right1, compensate: false);
      expect(on.uncompensated!.objectPath, off.trace.objectPath);
      expect(off.uncompensated, isNull);
      expect(off.aimOffsetDeg, 0);
      expect(off.converged, isTrue);
    });

    test('cắt rất mỏng gần 85°: không lỗi, bi mục tiêu đi đúng đường lỗ', () {
      for (final cut in [80.0, 84.0, maxCutAngle]) {
        final g = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut);
        final a = aim(g, Stroke.stun, power: 30);
        expect(a.converged, isTrue, reason: '$cut°');
        expect(a.trace.contactCue, isNotNull, reason: '$cut°');
        // Lực nhẹ thì bi mục tiêu chưa tới lỗ, nhưng dừng trên đúng đường.
        final end = a.trace.objectPath.last;
        expect(
            a.trace.objectPocket == g.pocket ||
                distanceToSegment(
                        end, g.object, table.pocketPosition(g.pocket)) <
                    1,
            isTrue,
            reason: '$cut° dừng ở $end');
      }
    });

    test('áp phê và swerve quá mạnh ở xa: không hội tụ vẫn trả cú tốt nhất',
        () {
      // Dò trên lưới: cơ Dốc, 2 đầu cơ, lực 30 % từ đầu bàn bên kia.
      final g = (evaluateShot(
              cue: const Vec2(20, 15),
              object: const Vec2(220, 20),
              pocket: Pocket.topRight) as Makeable)
          .geometry;
      final a = aim(g, Stroke.stun,
          power: 30,
          spin: const SideSpin(SpinSide.right, 2),
          elevation: CueElevation.steep);
      expect(a.converged, isFalse);
      expect(identical(a.trace.cueEnd,
              a.trace.cueAfter.isEmpty ? a.trace.cueBefore.last : a.trace.cueAfter.last),
          isTrue);
    });
  });

  group('Đánh đứng bi', () {
    /// Bắn thẳng vào lỗ góc dưới trái, bi cái cách bi ảo [d] cm.
    ShotGeometry straight(double d) =>
        geometryFor(const Vec2(40, 110), Pocket.bottomLeft, 0, distance: d);

    test('điểm đặt cơ dò được làm hết xoáy dọc lúc chạm', () {
      for (final d in [3.0, 10.0, 30.0, 60.0, 100.0]) {
        final g = straight(d);
        final s = solveAim(
            cue: g.cue,
            object: g.object,
            pocket: g.pocket,
            stroke: Stroke.stun,
            spin: const SideSpin.none(),
            power: 30,
            elevation: CueElevation.normal,
            table: table,
            compensate: true);
        expect(topspinAtContact(s.aimed)!.abs(), lessThan(stopSpin),
            reason: 'cách $d cm');
      }
    });

    test('càng xa càng phải đặt cơ thấp; sát bi mục tiêu thì gần như tâm', () {
      final offsets = [
        for (final d in [3.0, 10.0, 30.0, 60.0, 100.0])
          aim(straight(d), Stroke.stun, power: 30).verticalOffset,
      ];
      for (var i = 1; i < offsets.length; i++) {
        expect(offsets[i], lessThan(offsets[i - 1]));
      }
      expect(offsets.first.abs(), lessThan(0.05));
      expect(offsets.last, greaterThanOrEqualTo(-stunMaxOffset * radius));
    });

    test('quá xa ở lực nhẹ: đặt cơ thấp nhất cho phép', () {
      expect(aim(straight(150), Stroke.stun, power: 30).verticalOffset,
          -stunMaxOffset * radius);
    });

    test('bắn thẳng lực nhẹ và vừa: bi cái dừng trong 1 R quanh điểm chạm', () {
      // Từ 60 % trở lên bi cái còn trôi tới (1 − ballRestitution)/2 vận
      // tốc — xem "Deviations from spec" của plan.
      for (final power in [30.0, 45.0]) {
        final t = aim(straight(60), Stroke.stun, power: power).trace;
        expect(t.cueEnd.distanceTo(t.contactCue!), lessThan(radius),
            reason: '$power%');
      }
    });

    test('cắt góc: bi cái rời đi theo tiếp tuyến, chỉ lệch do phục hồi', () {
      for (final cut in [30.0, 45.0, 60.0]) {
        for (final power in [30.0, 45.0, 90.0]) {
          final g =
              geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, cut,
                  distance: 60);
          final s = solveAim(
              cue: g.cue,
              object: g.object,
              pocket: g.pocket,
              stroke: Stroke.stun,
              spin: const SideSpin.none(),
              power: power,
              elevation: CueElevation.normal,
              table: table,
              compensate: true);
          final probe = probeContact(s.aimed)!;
          // Hai bi cùng khối lượng: bi cái rời đi với v − v_mục tiêu.
          final depart = probe.cueAtContact.vel - probe.objectAfter.vel;
          final n = (g.object - probe.cueAtContact.pos).normalized;
          final tangent = depart - n * depart.dot(n);
          final off = tangent.signedAngleTo(depart).abs() * 180 / math.pi;
          final phi = n.signedAngleTo(probe.cueAtContact.vel).abs();
          final restitution = math.atan(
                  (1 - ballRestitution) / 2 / math.tan(phi)) *
              180 /
              math.pi;
          expect(off, lessThan(restitution + 0.5), reason: '$cut° $power%');
          if (cut >= 45) expect(off, lessThan(2), reason: '$cut° $power%');
        }
      }
    });

    test('trô và cu lê dùng đúng strokeOffset', () {
      final g = straight(40);
      expect(aim(g, Stroke.draw).verticalOffset, -strokeOffset * radius);
      expect(aim(g, Stroke.follow).verticalOffset, strokeOffset * radius);
    });
  });

  test('cueEnd của cú đã dò là đúng đối tượng cuối đường bi cái', () {
    final a = aim(geometryFor(const Vec2(180, 40), Pocket.topRight, 25),
        Stroke.follow, spin: right1);
    expect(identical(a.trace.cueEnd, a.trace.cueAfter.last), isTrue);
  });
}
```

`test/domain/table_physics/aim_perf_test.dart`:

```dart
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

void main() {
  test('aimShot trung vị dưới 8 ms trên Dart VM', () {
    // Bố cục mở màn, đứng bi có áp phê: nhiều vòng dò nhất (b và bù ném),
    // cộng hai lần mô phỏng đầy đủ. Còn chỗ cho dart2js chậm hơn VM.
    for (final stroke in Stroke.values) {
      void once() => aimShot(
          cue: const Vec2(80, 90),
          object: const Vec2(170, 50),
          pocket: Pocket.topRight,
          stroke: stroke,
          spin: const SideSpin(SpinSide.right, 1),
          power: 45);
      for (var i = 0; i < 5; i++) {
        once(); // làm nóng JIT
      }
      final micros = <int>[];
      for (var i = 0; i < 50; i++) {
        final w = Stopwatch()..start();
        once();
        micros.add(w.elapsedMicroseconds);
      }
      micros.sort();
      expect(micros[25] / 1000, lessThan(8), reason: '$stroke');
    }
  });
}
```

`dart_test.yaml` (repo root, new):

```yaml
tags:
  # Đo thời gian thật. Chạy cùng các file test khác thì CPU bị chia và
  # trung vị đo được gấp ba (đo được 13.8 ms thay vì 3–5 ms), nên mặc
  # định bỏ qua; chạy riêng bằng:
  #   flutter test --tags perf --run-skipped
  perf:
    skip: "Đo hiệu năng: chạy riêng bằng flutter test --tags perf --run-skipped"
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_physics/aim_test.dart`
Expected: FAIL. It does not compile: `Error when reading 'lib/domain/table_physics/aim.dart'`.

- [ ] **Step 3: Implement**

`lib/domain/table_physics/aim.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Cú đánh đã dò xong: hướng cơ bù ném và điểm đặt cơ (spec mục 4.6).
class AimedShot {
  const AimedShot({
    required this.trace,
    required this.uncompensated,
    required this.aimOffsetDeg,
    required this.verticalOffset,
    required this.converged,
  });

  /// Cú đánh theo hướng đã bù (hoặc hướng hình học nếu không bù).
  final ShotTrace trace;

  /// Khi bù: cú ngắm thẳng vào Bi ảo hình học, để vẽ đường đỏ.
  final ShotTrace? uncompensated;

  /// Hướng cơ đã bù trừ hướng tới Bi ảo hình học, độ; dương là dày hơn.
  final double aimOffsetDeg;

  /// `b` đã dùng, cm (Đánh đứng bi: `b` dò được).
  final double verticalOffset;

  /// Dò bù ném đạt `aimTolerance` trong `maxAimIterations` vòng.
  final bool converged;
}

/// Kết quả dò, chưa mô phỏng đủ — [aimShot] và `scratchMargin` dùng
/// chung, nên biên chết cái tính đúng trên cú mà màn hình vẽ.
class AimSolution {
  const AimSolution({
    required this.aimed,
    required this.geometric,
    required this.converged,
  });

  /// Cú đánh theo hướng đã bù.
  final ShotInput aimed;

  /// Cùng cú đánh, ngắm thẳng vào Bi ảo hình học.
  final ShotInput geometric;
  final bool converged;

  /// Dương là dày hơn: hướng cơ quay về phía tâm bi mục tiêu.
  double get aimOffsetDeg {
    final toCenter = geometric.object - geometric.cue;
    double offCenter(double aim) =>
        Vec2(math.cos(aim), math.sin(aim)).signedAngleTo(toCenter).abs();
    return (offCenter(geometric.aimAngle) - offCenter(aimed.aimAngle)) *
        180 /
        math.pi;
  }
}

/// Dò hướng cơ và điểm đặt cơ cho cú đánh [object] vào [pocket].
AimSolution solveAim({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  required SideSpin spin,
  required double power,
  required CueElevation elevation,
  required TableSpec table,
  required bool compensate,
}) {
  final radius = table.radius;
  final pocketPos = table.pocketPosition(pocket);
  final ghost =
      object - (pocketPos - object).normalized * table.ballDiameter;
  final toGhost = ghost - cue;
  final aim0 = toGhost.isZero
      ? math.atan2(pocketPos.y - object.y, pocketPos.x - object.x)
      : math.atan2(toGhost.y, toGhost.x);

  var input = ShotInput(
    cue: cue,
    object: object,
    aimAngle: aim0,
    power: power,
    verticalOffset: switch (stroke) {
      Stroke.follow => strokeOffset * radius,
      Stroke.draw => -strokeOffset * radius,
      Stroke.stun => 0,
    },
    spin: spin,
    elevation: elevation.radians,
    table: table,
  );

  if (!compensate) {
    if (stroke == Stroke.stun) input = _solveStun(input);
    return AimSolution(aimed: input, geometric: input, converged: true);
  }

  // Bắt đầu từ hướng đã bù sẵn góc lệch do áp phê: vận tốc ban đầu khi
  // đó chỉ đúng vào Bi ảo hình học. Không có bước này, áp phê nhiều ở
  // xa làm cú dò đầu tiên trượt hẳn bi mục tiêu.
  input = input.copyWith(
      aimAngle: aim0 + squirtAngle(sideOffsetOf(spin), radius));
  var converged = false;
  // Đánh đứng bi: `b` đổi xoáy nên đổi cả swerve, tức đổi hướng cần bù;
  // hướng bù đổi quãng đường nên đổi `b`. Dò xen kẽ hai vòng, kết thúc
  // bằng dò bù ném để hướng cơ khớp đúng `b` cuối cùng.
  for (var round = 0; round < (stroke == Stroke.stun ? 2 : 1); round++) {
    if (stroke == Stroke.stun) input = _solveStun(input);
    final (aim, ok) = _solveThrow(input, pocketPos);
    input = input.copyWith(aimAngle: aim);
    converged = ok;
  }
  return AimSolution(
    aimed: input,
    geometric: input.copyWith(aimAngle: aim0),
    converged: converged,
  );
}

/// Dò bù ném và Đánh đứng bi, rồi mô phỏng đủ (spec mục 4.6).
AimedShot aimShot({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  SideSpin spin = const SideSpin.none(),
  required double power,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
  bool compensate = true,
}) {
  final s = solveAim(
    cue: cue,
    object: object,
    pocket: pocket,
    stroke: stroke,
    spin: spin,
    power: power,
    elevation: elevation,
    table: table,
    compensate: compensate,
  );
  return AimedShot(
    trace: simulateShot(s.aimed),
    uncompensated: compensate ? simulateShot(s.geometric) : null,
    aimOffsetDeg: compensate ? s.aimOffsetDeg : 0,
    verticalOffset: s.aimed.verticalOffset,
    converged: s.converged,
  );
}

/// Xoáy dọc (trên +, dưới −) của bi cái lúc chạm, rad/s; null nếu trượt.
double? topspinAtContact(ShotInput input) {
  final probe = probeContact(input);
  if (probe == null) return null;
  final s = probe.cueAtContact;
  final dir = s.vel.normalized;
  // Xoáy lăn đều là ẑ × v / R: chiếu xoáy lên ẑ × v̂.
  return -s.spin.x * dir.y + s.spin.y * dir.x;
}

/// Đánh đứng bi: `b ∈ [−stunMaxOffset·R, 0]` để bi cái tới bi mục tiêu
/// đúng lúc hết xoáy dọc (spec quyết định 10).
///
/// Xoáy lúc chạm gần như tuyến tính theo `b` (thời gian tới bi mục tiêu
/// không phụ thuộc xoáy khi còn trượt), nên dò kiểu chia đôi có nội suy
/// (Illinois): giữ khoảng kẹp như chia đôi nhưng 2–4 vòng là đủ.
ShotInput _solveStun(ShotInput input) {
  final lo = -stunMaxOffset * input.table.radius;
  double? f(double b) => topspinAtContact(input.copyWith(verticalOffset: b));

  final fHi = f(0);
  if (fHi == null || fHi <= stopSpin / 4) {
    return input.copyWith(verticalOffset: 0);
  }
  final fLo = f(lo);
  // Xa quá, đặt cơ thấp nhất vẫn không kịp hết xoáy dưới: dùng mức đó.
  if (fLo == null || fLo >= 0) return input.copyWith(verticalOffset: lo);

  var a = lo, fa = fLo, b = 0.0, fb = fHi;
  var side = 0;
  var x = (a + b) / 2;
  for (var i = 0; i < 16; i++) {
    x = (a * fb - b * fa) / (fb - fa);
    final fx = f(x);
    if (fx == null) break;
    if (fx.abs() < stopSpin / 4) break;
    if (fx < 0) {
      a = x;
      fa = fx;
      if (side == -1) fb /= 2;
      side = -1;
    } else {
      b = x;
      fb = fx;
      if (side == 1) fa /= 2;
      side = 1;
    }
  }
  return input.copyWith(verticalOffset: x);
}

/// Bù ném: dò hướng cơ bằng cát tuyến, bắt đầu từ `input.aimAngle`, sao
/// cho bi mục tiêu ngay sau va chạm chạy thẳng vào tâm lỗ. Đo kết quả
/// thật nên bù luôn bi cái bị lệch do áp phê và swerve. Trả hướng tốt
/// nhất và có hội tụ không.
(double, bool) _solveThrow(ShotInput input, Vec2 pocketPos) {
  const tol = aimTolerance * math.pi / 180;
  // Mỗi vòng xoay tối đa 6°: cát tuyến không chặn có thể nhảy sang cú
  // chạm phía bên kia bi mục tiêu; chặn chặt hơn (1°, 3°) thì cú swerve
  // mạnh ở xa không kịp bù trong maxAimIterations vòng (đo trên lưới:
  // 407, 83, 68 cú không hội tụ trên 6816 với 1°, 3°, 6°).
  const maxStep = 6 * math.pi / 180;
  var probes = 0;
  double? error(double aim) {
    probes++;
    final p = probeContact(input.copyWith(aimAngle: aim));
    if (p == null) return null;
    return p.objectAfter.vel.signedAngleTo(pocketPos - input.object);
  }

  final start = input.aimAngle;
  final toObject = input.object - input.cue;
  final thicker =
      Vec2(math.cos(start), math.sin(start)).cross(toObject) >= 0 ? 1.0 : -1.0;
  var x0 = start;
  var e0 = error(x0);
  // Vẫn trượt (swerve, cắt rất mỏng): xoay dần về phía tâm bi mục tiêu
  // từng nửa độ tới khi chạm.
  for (var k = 1; e0 == null && probes < maxAimIterations; k++) {
    x0 = start + thicker * k * maxStep / 2;
    e0 = error(x0);
  }
  if (e0 == null) return (start, false);

  var bestX = x0, bestE = e0.abs();
  if (bestE < tol) return (x0, true);

  // Bước đầu nhỏ để có độ dốc; sau đó cát tuyến.
  var x1 = x0 + 1e-3 * thicker;
  var e1 = error(x1);
  if (e1 == null) {
    x1 = x0 - 1e-3 * thicker;
    e1 = error(x1);
  }
  if (e1 == null) return (bestX, false);

  while (true) {
    if (e1!.abs() < bestE) {
      bestX = x1;
      bestE = e1.abs();
    }
    if (bestE < tol || probes >= maxAimIterations || e1 == e0) break;
    var step = -e1 * (x1 - x0) / (e1 - e0!);
    if (step.abs() > maxStep) step = maxStep * step.sign;
    var x2 = x1 + step;
    var e2 = error(x2);
    // Trượt bi mục tiêu: lùi nửa đường về điểm còn chạm.
    while (e2 == null && probes < maxAimIterations) {
      step /= 2;
      x2 = x1 + step;
      e2 = error(x2);
    }
    if (e2 == null) break;
    x0 = x1;
    e0 = e1;
    x1 = x2;
    e1 = e2;
  }
  return (bestX, bestE < tol);
}
```

- [ ] **Step 4: Run them and confirm they pass**

Run: `"$FLUTTER" test test/domain/table_physics/aim_test.dart`
Expected: `All tests passed!` in about 15 s.

Run: `"$FLUTTER" test test/domain/table_physics/aim_perf_test.dart`
Expected: `All tests skipped.`, because the `perf` tag is skipped by default.

Run, with nothing else running: `"$FLUTTER" test --tags perf --run-skipped`
Expected: `+1: All tests passed!`. The prototype measured medians of 3.3 ms (stun), 3.8 ms (draw) and 2.5 ms (follow).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_physics/aim.dart dart_test.yaml test/domain/table_physics/aim_test.dart test/domain/table_physics/aim_perf_test.dart
git commit -m "Aim a shot by probing the simulation up to contact, so throw, squirt and swerve are compensated and a stun shot arrives without spin

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Chết cái and advice on the new core, and the five power levels

**Files:**
- Modify: `lib/domain/table_geometry/stroke.dart` (`powerPresets`)
- Modify: `lib/domain/table_geometry/scratch.dart` (whole file below)
- Test: rewrite `test/domain/table_geometry/scratch_test.dart`; rewrite the imports and the last test of `test/domain/table_geometry/advice_test.dart`

**Interfaces:**
- Consumes: `solveAim`, `aimShot` (Task 7); `simulateCuePocket` (Task 6); `overhitScanStep` (Task 1).
- Produces, with the existing `ScratchRisk`, `SpinOutcome`, `Advice` family, `overhitBand` and `chooseAdvice` unchanged:
  - `const powerPresets = <double>[30, 45, 60, 75, 90];`
  - `Pocket? cuePocketAt(ShotGeometry g, {required Stroke stroke, required double power, required SideSpin spin, CueElevation elevation = CueElevation.normal, TableSpec table = TableSpec.nineFoot})`
  - `typedef CuePocketLookup = Pocket? Function(SideSpin spin, double power);`
  - `ScratchRisk? marginWith(CuePocketLookup at, SideSpin spin, double power)`
  - `ScratchRisk? scratchMargin(ShotGeometry g, {required Stroke stroke, required double power, SideSpin spin = const SideSpin.none(), CueElevation elevation = CueElevation.normal, TableSpec table = TableSpec.nineFoot})`
  - `Map<SideSpin, SpinOutcome> outcomesWith(CuePocketLookup at, double power)`
  - `List<Advice> scratchAdvice(ShotGeometry g, {required Stroke stroke, required double power, required SideSpin spin, CueElevation elevation = CueElevation.normal, TableSpec table = TableSpec.nineFoot})`
  - `class ScratchAdviceJob { ScratchAdviceJob(ShotGeometry g, {required Stroke stroke, required double power, required SideSpin spin, CueElevation elevation = CueElevation.normal, TableSpec table = TableSpec.nineFoot}); int get simulations; List<Advice>? step(); }`

The screen keeps calling `scratchAdvice` on every build until Task 10. That is ~85 simulations per frame, so the screen is slow in between. On the prototype this intermediate state (old path tests, rewritten scratch and advice tests) was green.

- [ ] **Step 1: Write the failing tests**

Replace `test/domain/table_geometry/scratch_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  final corner = table.pocketPosition(Pocket.topRight);
  // Bi mục tiêu sát lỗ góc trên phải, cú thẳng: cu lê đi theo bi vào lỗ.
  final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);

  AimedShot shot(ShotGeometry g, Stroke stroke, double power,
          {SideSpin spin = const SideSpin.none()}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: power);

  Pocket? dropsAt(Stroke stroke, double power) =>
      cuePocketAt(g, stroke: stroke, power: power, spin: const SideSpin.none());

  test('cu lê theo bi vào lỗ là chết cái, rơi trước khi kịp chạm băng', () {
    final t = shot(g, Stroke.follow, powerPresets.last).trace;
    expect(t.cuePocket, Pocket.topRight);
    expect(t.cueRailCount, 0);
    expect(t.cueEnd, corner);
  });

  test('đánh đứng bi cú thẳng thì bi cái gần như dừng tại chỗ, không chết cái',
      () {
    for (final power in powerPresets) {
      expect(shot(g, Stroke.stun, power).trace.cuePocket, isNull,
          reason: '$power%');
    }
  });

  test('cuePocketAt cho đúng lỗ mà aimShot vẽ', () {
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 23) {
      for (final stroke in Stroke.values) {
        for (final spin in [
          const SideSpin.none(),
          const SideSpin(SpinSide.left, 1),
        ]) {
          expect(
            cuePocketAt(shots[i], stroke: stroke, power: 75, spin: spin),
            shot(shots[i], stroke, 75, spin: spin).trace.cuePocket,
            reason: '${shots[i].cue}→${shots[i].object} $stroke $spin',
          );
        }
      }
    }
  });

  test('biên lực chết cái: dò thưa rồi dò mịn, trả mức đầu tiên tìm thấy', () {
    const from = 30.0;
    final risk = scratchMargin(g, stroke: Stroke.follow, power: from)!;
    expect(risk.pocket, Pocket.topRight);
    expect(dropsAt(Stroke.follow, risk.power), risk.pocket);
    // Mọi mức dò thưa đứng trước biên đều không chết cái…
    for (var p = from; p < risk.power; p += overhitScanStep) {
      expect(dropsAt(Stroke.follow, p), isNull, reason: '$p%');
    }
    // …và mức ngay dưới biên cũng không (đã dò mịn từng 1 %).
    if (risk.power - 1 >= from) {
      expect(dropsAt(Stroke.follow, risk.power - 1), isNull);
    }
  });

  test('không chết cái tới 100% thì không có biên', () {
    expect(scratchMargin(g, stroke: Stroke.stun, power: powerPresets.first),
        isNull);
  });

  test('ngay mức chọn đã chết cái thì biên là chính mức đó', () {
    final risk =
        scratchMargin(g, stroke: Stroke.follow, power: powerPresets.last)!;
    expect(risk.power, powerPresets.last);
  });

  test('dò thưa luôn chạm đúng 100 %, kể cả khi lực đầu không chia hết bước',
      () {
    final seen = <double>[];
    marginWith((s, p) {
      seen.add(p);
      return null;
    }, const SideSpin.none(), 87);
    expect(seen.first, 87);
    expect(seen.last, 100);
    expect(seen.every((p) => p <= 100), isTrue);
  });

  test('trên lưới: chết cái thì bi cái kết thúc ở đúng tâm lỗ đó', () {
    final shots = gridShots().toList();
    var scratches = 0;
    for (var i = 0; i < shots.length; i += 5) {
      for (final stroke in Stroke.values) {
        final t = shot(shots[i], stroke, powerPresets.last).trace;
        final pocket = t.cuePocket;
        if (pocket == null) continue;
        scratches++;
        expect(t.cueEnd, table.pocketPosition(pocket),
            reason: '${shots[i].cue}→${shots[i].object} $stroke');
      }
    }
    expect(scratches, greaterThan(0),
        reason: 'lưới phải có cú chết cái thì test mới có nghĩa');
  });
}
```

In `test/domain/table_geometry/advice_test.dart`, replace the import block with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';
```

Then replace everything from `  test('scratchAdvice nối đúng với mô phỏng thật', () {` to the end of the file with:

```dart
  /// Mô phỏng thật, mỗi (áp phê, lực) đúng một lần cho một cú đánh.
  CuePocketLookup lookupFor(ShotGeometry g, Stroke stroke) {
    final memo = <(SideSpin, double), Pocket?>{};
    return (s, p) => memo.putIfAbsent(
        (s, p), () => cuePocketAt(g, stroke: stroke, power: p, spin: s));
  }

  String describe(Advice a) => switch (a) {
        AddSpinToAvoid(:final from, :final to, :final pocket) =>
          'add $from→$to $pocket',
        NoSpinAvoids(:final pocket) => 'none $pocket',
        OverhitRisk(:final margin, :final fromPower, :final pocket, :final saferSpin) =>
          'over $margin $fromPower $pocket $saferSpin',
        SpinCeiling(:final side, :final maxSafeTips, :final pocket) =>
          'ceiling $side $maxSafeTips $pocket',
      };

  test('lời khuyên trên lưới khớp mô phỏng thật, đủ cả bốn loại', () {
    // Đếm theo kiểu con để khẳng định cả bốn loại lời khuyên đều từng
    // xuất hiện trên lưới thật, nên nối dây của từng loại đều được kiểm.
    final counts = <Type, int>{};
    final shots = gridShots().toList();
    for (var i = 0; i < shots.length; i += 9) {
      final g = shots[i];
      for (final stroke in [Stroke.stun, Stroke.follow]) {
        // Bỏ hai mức nhẹ nhất cho đỡ chậm: lực nhẹ hiếm khi tới lỗ.
        for (final p in powerPresets.skip(2)) {
          final at = lookupFor(g, stroke);
          ScratchRisk? margin(SideSpin s) => marginWith(at, s, p);
          final outcomes = outcomesWith(at, p);
          for (final chosen in SideSpin.all) {
            for (final a
                in chooseAdvice(power: p, chosen: chosen, outcomes: outcomes)) {
              counts[a.runtimeType] = (counts[a.runtimeType] ?? 0) + 1;
              final where = '${g.cue}→${g.object} $stroke $p $chosen';
              switch (a) {
                case AddSpinToAvoid(:final from, :final to, :final pocket):
                  expect(from, chosen, reason: where);
                  expect(at(chosen, p), pocket, reason: where);
                  expect(at(to, p), isNull, reason: where);
                  final toRisk = margin(to);
                  expect(toRisk == null || toRisk.power - p > overhitBand,
                      isTrue,
                      reason: where);

                case NoSpinAvoids(:final pocket):
                  expect(at(chosen, p), pocket, reason: where);
                  for (final s in SideSpin.all) {
                    if (s == chosen) continue;
                    final risk = margin(s);
                    final unsafe = at(s, p) != null ||
                        (risk != null && risk.power - p <= overhitBand);
                    expect(unsafe, isTrue,
                        reason: '$where: NoSpinAvoids nghĩa là mọi mức khác '
                            'đều không an toàn');
                  }

                case OverhitRisk(
                    :final margin,
                    :final fromPower,
                    :final pocket,
                    :final saferSpin
                  ):
                  expect(at(chosen, p), isNull, reason: where);
                  expect(at(chosen, fromPower), pocket, reason: where);
                  expect(margin, fromPower - p, reason: where);
                  expect(margin, lessThanOrEqualTo(overhitBand), reason: where);
                  if (saferSpin != null) {
                    expect(marginWith(at, saferSpin, p), isNull, reason: where);
                  }

                case SpinCeiling(
                    :final side,
                    :final maxSafeTips,
                    :final pocket
                  ):
                  expect(side, chosen.side, reason: where);
                  final sideLevels = SideSpin.all
                      .where((s) => s.side == side)
                      .toList()
                    ..sort((x, y) => x.tips.compareTo(y.tips));
                  final above =
                      sideLevels.where((s) => s.tips > maxSafeTips).toList();
                  expect(above, isNotEmpty, reason: where);
                  expect(at(above.first, p), pocket, reason: where);
                  for (final s in sideLevels) {
                    if (s.tips > chosen.tips && s.tips <= maxSafeTips) {
                      expect(at(s, p), isNull, reason: where);
                    }
                  }
              }
            }
          }
        }
      }
    }

    for (final type in [AddSpinToAvoid, NoSpinAvoids, OverhitRisk, SpinCeiling]) {
      expect(counts[type] ?? 0, greaterThan(0),
          reason:
              '$type phải xuất hiện ít nhất một lần trên lưới để nối dây được kiểm');
    }
  });

  test('scratchAdvice là luật chọn chạy trên mô phỏng thật', () {
    final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);
    for (final chosen in [none, right1, left1]) {
      final at = lookupFor(g, Stroke.follow);
      expect(
        scratchAdvice(g, stroke: Stroke.follow, power: 75, spin: chosen)
            .map(describe),
        chooseAdvice(
                power: 75, chosen: chosen, outcomes: outcomesWith(at, 75))
            .map(describe),
      );
    }
  });

  test('ScratchAdviceJob: mỗi bước đúng một lần mô phỏng, rồi ra lời khuyên',
      () {
    final g = geometryFor(const Vec2(240, 14), Pocket.topRight, 0);
    final job = ScratchAdviceJob(g,
        stroke: Stroke.follow, power: 60, spin: none);
    List<Advice>? result;
    var steps = 0;
    while (result == null) {
      result = job.step();
      steps++;
      if (result == null) expect(job.simulations, steps);
    }
    expect(job.simulations, steps - 1);
    expect(
      result.map(describe),
      scratchAdvice(g, stroke: Stroke.follow, power: 60, spin: none)
          .map(describe),
    );
  });
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/scratch_test.dart test/domain/table_geometry/advice_test.dart`
Expected: FAIL. They do not compile: `cuePocketAt`, `marginWith`, `outcomesWith` and `ScratchAdviceJob` are undefined.

- [ ] **Step 3: Implement**

In `lib/domain/table_geometry/stroke.dart`, replace the `powerPresets` comment and constant with:

```dart
/// Năm mức lực trên màn — khớp `POWER_CANDIDATES` của Planner, để điều
/// người chơi thấy ở đây đúng là điều Planner sẽ gợi ý.
const powerPresets = <double>[30, 45, 60, 75, 90];
```

Replace `lib/domain/table_geometry/scratch.dart` with:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/constants.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Mức lực đầu tiên làm bi cái chết cái, và rơi lỗ nào.
class ScratchRisk {
  const ScratchRisk({required this.power, required this.pocket});
  final double power;
  final Pocket pocket;
}

/// Lỗ bi cái rơi vào khi đánh [g] ở lực [power] với áp phê [spin] —
/// đúng cú mà `aimShot` vẽ (cùng hướng bù ném, cùng `b`), nên
/// `cuePocketAt(...) == aimShot(...).trace.cuePocket`.
Pocket? cuePocketAt(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) =>
    simulateCuePocket(solveAim(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      stroke: stroke,
      spin: spin,
      power: power,
      elevation: elevation,
      table: table,
      compensate: true,
    ).aimed);

/// Tra một lần mô phỏng: lỗ bi cái rơi vào ở áp phê và lực đã cho.
typedef CuePocketLookup = Pocket? Function(SideSpin spin, double power);

/// Mức lực đầu tiên từ [power] trở lên làm bi cái chết cái.
///
/// Dò thưa từng `overhitScanStep` % tới 100 %, gặp mức chết cái thì dò
/// mịn từng 1 % trong khoảng vừa vượt qua: biên chết cái không đơn điệu
/// theo lực (lực khác thì bi cái chạm băng ở chỗ khác), nên không chia
/// đôi được. Ngay [power] đã chết cái thì trả chính [power]. Chỉ xét
/// **dư** lực, như trước.
ScratchRisk? marginWith(CuePocketLookup at, SideSpin spin, double power) {
  final now = at(spin, power);
  if (now != null) return ScratchRisk(power: power, pocket: now);
  var below = power;
  while (below < 100) {
    final p = math.min(below + overhitScanStep, 100.0);
    final pocket = at(spin, p);
    if (pocket != null) {
      for (var q = below + 1; q < p; q++) {
        final fine = at(spin, q);
        if (fine != null) return ScratchRisk(power: q, pocket: fine);
      }
      return ScratchRisk(power: p, pocket: pocket);
    }
    below = p;
  }
  return null;
}

/// [marginWith] trên mô phỏng thật (spec 2026-10-02 mục 4.7).
ScratchRisk? scratchMargin(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  SideSpin spin = const SideSpin.none(),
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) =>
    marginWith(
      (s, p) => cuePocketAt(g,
          stroke: stroke, power: p, spin: s, elevation: elevation, table: table),
      spin,
      power,
    );

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

/// Kết quả của cả bảy mức áp phê, tra qua [at].
Map<SideSpin, SpinOutcome> outcomesWith(CuePocketLookup at, double power) => {
      for (final s in SideSpin.all)
        s: () {
          final risk = marginWith(at, s, power);
          return SpinOutcome(
            scratchAtPower:
                risk != null && risk.power == power ? risk.pocket : null,
            risk: risk,
          );
        }(),
    };

/// Mô phỏng đủ bảy mức áp phê rồi chọn lời khuyên.
List<Advice> scratchAdvice(
  ShotGeometry g, {
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  CueElevation elevation = CueElevation.normal,
  TableSpec table = TableSpec.nineFoot,
}) {
  final job = ScratchAdviceJob(g,
      stroke: stroke,
      power: power,
      spin: spin,
      elevation: elevation,
      table: table);
  while (true) {
    if (job.step() case final advice?) return advice;
  }
}

/// [scratchAdvice] chia nhỏ: mỗi [step] chạy đúng một lần mô phỏng mới.
///
/// Gần trăm lần mô phỏng đầy đủ không xong trong một khung hình trên
/// Chrome, nên màn hình gọi [step] từng chút giữa các khung hình và hiện
/// "Đang tính…" trong lúc chờ (spec mục 5). Luật chọn lời khuyên vẫn
/// chạy đúng một chỗ: mỗi [step] chạy lại từ đầu trên bộ nhớ đệm, gặp
/// lần mô phỏng chưa có thì làm đúng lần đó rồi dừng.
class ScratchAdviceJob {
  ScratchAdviceJob(
    this.g, {
    required this.stroke,
    required this.power,
    required this.spin,
    this.elevation = CueElevation.normal,
    this.table = TableSpec.nineFoot,
  });

  final ShotGeometry g;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final CueElevation elevation;
  final TableSpec table;

  final _cache = <(SideSpin, double), Pocket?>{};

  /// Số lần mô phỏng đã chạy.
  int get simulations => _cache.length;

  /// Lời khuyên khi đã đủ dữ liệu; null khi vừa chạy thêm một lần.
  List<Advice>? step() {
    try {
      return chooseAdvice(
        power: power,
        chosen: spin,
        outcomes: outcomesWith(_lookup, power),
      );
    } on _Missing catch (m) {
      _cache[m.key] = cuePocketAt(g,
          stroke: stroke,
          power: m.key.$2,
          spin: m.key.$1,
          elevation: elevation,
          table: table);
      return null;
    }
  }

  Pocket? _lookup(SideSpin s, double p) {
    final key = (s, p);
    if (_cache.containsKey(key)) return _cache[key];
    throw _Missing(key);
  }
}

class _Missing implements Exception {
  const _Missing(this.key);
  final (SideSpin, double) key;
}
```

- [ ] **Step 4: Run the whole suite**

Run: `"$FLUTTER" test`
Expected: `All tests passed!`, with one test skipped (`perf`). The old `cue_ball_path_test.dart` and `bank_spin_test.dart` still pass on the old model. Task 10 deletes them along with that model.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/table_geometry/stroke.dart lib/domain/table_geometry/scratch.dart test/domain/table_geometry/scratch_test.dart test/domain/table_geometry/advice_test.dart
git commit -m "Find the Chết cái margin and the áp phê advice with the physics core, scanning power coarse then fine, and offer five power levels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The new strings and the info panel's lines

**Files:**
- Modify: `lib/core/strings/vi.dart` (add a block after `simScratch`; replace `simPowerPreset`)
- Create: `lib/features/training/presentation/simulator/info_lines.dart`
- Test: `test/features/training/simulator_info_lines_test.dart`; add a group to `test/core/strings/vi_simulator_test.dart`

**Interfaces:**
- Consumes: `AimedShot`, `ShotTrace`, `RailHit` (Tasks 6–7); `squirtAngle`, `sideOffsetOf` (Task 2); `Advice` (Task 8).
- Produces:
  - `Vi.simElevationLabel`, `Vi.simCompensateToggle`, `Vi.simComputing`, `Vi.simObjectMissed`, `Vi.simElevation(CueElevation)`, `Vi.simElevationLine(CueElevation)`, `Vi.simAimOffset(double deg)`, `Vi.simStunOffset(double offsetCm)`, `Vi.simSquirt(double deg)`, `Vi.simRailCount(int)`; `Vi.simPowerPreset(double)` now returns `'N%'`
  - `const aimOffsetShownDeg = 0.5;` and `const stunOffsetShownTips = 0.25;`
  - `List<String> simulatorInfoLines({required ShotResult? shot, required AimedShot? aimed, required List<Advice>? advice, required Stroke stroke, required double power, required SideSpin spin, required CueElevation elevation, TableSpec table = TableSpec.nineFoot})`

- [ ] **Step 1: Write the failing tests**

`test/features/training/simulator_info_lines_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  const none = SideSpin.none();
  const right1 = SideSpin(SpinSide.right, 1);
  final g = geometryFor(const Vec2(170, 50), Pocket.topRight, 20, distance: 90);

  AimedShot aimed(Stroke stroke, {SideSpin spin = none}) => aimShot(
      cue: g.cue,
      object: g.object,
      pocket: g.pocket,
      stroke: stroke,
      spin: spin,
      power: 45);

  List<String> lines({
    required AimedShot? a,
    List<Advice>? advice = const [],
    Stroke stroke = Stroke.stun,
    SideSpin spin = none,
    ShotResult? shot,
  }) =>
      simulatorInfoLines(
        shot: shot ?? Makeable(g),
        aimed: a,
        advice: advice,
        stroke: stroke,
        power: 45,
        spin: spin,
        elevation: CueElevation.normal,
      );

  /// Một trace dựng tay, để bật từng trường hợp hiếm.
  AimedShot fake({
    int rails = 0,
    Pocket? cuePocket,
    Pocket? objectPocket = Pocket.topRight,
    double aimOffsetDeg = 0,
    double verticalOffset = 0,
  }) =>
      AimedShot(
        trace: ShotTrace(
          cueBefore: [g.cue, g.ghost],
          cueAfter: [g.ghost, const Vec2(100, 100)],
          objectPath: [g.object],
          contactCue: g.ghost,
          rails: [
            for (var i = 0; i < rails; i++)
              RailHit(
                  ball: ShotBall.cue,
                  pos: Vec2(table.minX, 50.0 + i),
                  rail: Rail.left,
                  afterContact: true),
          ],
          cuePocket: cuePocket,
          objectPocket: objectPocket,
          cueEnd: const Vec2(100, 100),
        ),
        uncompensated: null,
        aimOffsetDeg: aimOffsetDeg,
        verticalOffset: verticalOffset,
        converged: true,
      );

  test('các dòng cố định, theo thứ tự', () {
    final out = lines(a: fake());
    expect(out.take(7), [
      Vi.simPocketLine(g.pocket),
      Vi.simAngleLine(g.angle),
      Vi.simBandLine(bandFor(g.angle)),
      Vi.simStrokeLine(Stroke.stun),
      Vi.simPowerLine(45),
      Vi.simSpinLine(none),
      Vi.simElevationLine(CueElevation.normal),
    ]);
  });

  test('ngắm dày/mỏng đúng chiều, chỉ khi từ aimOffsetShownDeg trở lên', () {
    expect(lines(a: fake(aimOffsetDeg: 1.2)), contains(Vi.simAimOffset(1.2)));
    expect(Vi.simAimOffset(1.2), startsWith('Ngắm dày hơn'));
    expect(lines(a: fake(aimOffsetDeg: -0.7)), contains(Vi.simAimOffset(-0.7)));
    expect(Vi.simAimOffset(-0.7), startsWith('Ngắm mỏng hơn'));
    final small = lines(a: fake(aimOffsetDeg: aimOffsetShownDeg * 0.9));
    expect(small.where((l) => l.startsWith('Ngắm')), isEmpty);
  });

  test('cú thật có áp phê: dòng bù ném lấy đúng aimOffsetDeg của lõi', () {
    final a = aimed(Stroke.stun, spin: right1);
    expect(a.aimOffsetDeg.abs(), greaterThanOrEqualTo(aimOffsetShownDeg));
    expect(lines(a: a, spin: right1),
        contains(Vi.simAimOffset(a.aimOffsetDeg)));
  });

  test('dòng Đánh đứng bi chỉ hiện khi đặt cơ đủ xa tâm, và chỉ khi đứng bi',
      () {
    const deep = -stunOffsetShownTips * tipWidth * 2;
    expect(lines(a: fake(verticalOffset: deep)),
        contains(Vi.simStunOffset(deep)));
    expect(
        lines(a: fake(verticalOffset: -stunOffsetShownTips * tipWidth * 0.9))
            .where((l) => l.startsWith('Đánh đứng bi:')),
        isEmpty);
    expect(
        lines(a: fake(verticalOffset: deep), stroke: Stroke.draw)
            .where((l) => l.startsWith('Đánh đứng bi:')),
        isEmpty);
  });

  test('có áp phê thì nói góc bi cái bị lệch do áp phê', () {
    final deg = squirtAngle(tipWidth, table.radius) * 180 / math.pi;
    expect(lines(a: fake(), spin: right1), contains(Vi.simSquirt(deg)));
    expect(lines(a: fake()).where((l) => l.startsWith('Bi cái bị lệch')),
        isEmpty);
  });

  test('số lần chạm băng, chết cái, bi mục tiêu không vào lỗ', () {
    final out = lines(
        a: fake(
            rails: 3,
            cuePocket: Pocket.bottomLeft,
            objectPocket: Pocket.topMiddle));
    expect(out, contains(Vi.simRailCount(3)));
    expect(out, contains(Vi.simScratch(Pocket.bottomLeft)));
    expect(out, contains(Vi.simObjectMissed));
    final clean = lines(a: fake());
    expect(clean, isNot(contains(Vi.simObjectMissed)));
    expect(clean.where((l) => l.startsWith('Bi cái chạm băng')), isEmpty);
  });

  test('gợi ý chống chết cái: Đang tính… khi chưa có, lời khuyên khi có', () {
    expect(lines(a: fake(), advice: null), contains(Vi.simComputing));
    const advice = [NoSpinAvoids(pocket: Pocket.topRight)];
    final out = lines(a: fake(), advice: advice);
    expect(out, isNot(contains(Vi.simComputing)));
    expect(out, contains(Vi.simAdvice(advice.single)));
  });

  test('không đánh được thì chỉ nói lý do', () {
    expect(
        lines(a: null, shot: const Unmakeable(UnmakeableReason.tooThin)),
        [Vi.simUnmakeable(UnmakeableReason.tooThin)]);
    expect(
        simulatorInfoLines(
            shot: null,
            aimed: null,
            advice: null,
            stroke: Stroke.stun,
            power: 45,
            spin: none,
            elevation: CueElevation.normal),
        [Vi.simNoPocket]);
  });
}
```

In `test/core/strings/vi_simulator_test.dart`, add before the closing `}` of `main`:

```dart
  group('lõi vật lý', () {
    test('thuật ngữ mới đã chốt với chủ sản phẩm', () {
      expect(Vi.simElevationLabel, 'Độ dốc cơ');
      expect(Vi.simElevation(CueElevation.normal), 'Thường');
      expect(Vi.simElevation(CueElevation.steep), 'Dốc');
      expect(Vi.simElevationLine(CueElevation.steep), 'Độ dốc cơ: Dốc');
      expect(Vi.simCompensateToggle, 'Xem nếu không bù ném');
      expect(Vi.simComputing, 'Đang tính…');
      expect(Vi.simObjectMissed, 'Bi mục tiêu không vào lỗ.');
    });

    test('năm mức lực chỉ ghi phần trăm', () {
      expect([for (final p in powerPresets) Vi.simPowerPreset(p)],
          ['30%', '45%', '60%', '75%', '90%']);
    });

    test('ngắm dày/mỏng theo dấu, làm tròn 0.5°', () {
      expect(Vi.simAimOffset(1.24), 'Ngắm dày hơn 1°');
      expect(Vi.simAimOffset(1.26), 'Ngắm dày hơn 1.5°');
      expect(Vi.simAimOffset(-0.6), 'Ngắm mỏng hơn 0.5°');
      expect(Vi.simAimOffset(-2), 'Ngắm mỏng hơn 2°');
    });

    test('đặt cơ dưới tâm tính bằng đầu cơ, làm tròn 0.25', () {
      expect(Vi.simStunOffset(-0.66),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 0.5 đầu cơ');
      expect(Vi.simStunOffset(-1.714),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1.25 đầu cơ');
      expect(Vi.simStunOffset(-1.25),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1 đầu cơ');
    });

    test('lệch do áp phê và số lần chạm băng', () {
      expect(Vi.simSquirt(1.55), 'Bi cái bị lệch do áp phê khoảng 1.5°');
      expect(Vi.simSquirt(0.83), 'Bi cái bị lệch do áp phê khoảng 1°');
      expect(Vi.simRailCount(3), 'Bi cái chạm băng 3 lần.');
    });
  });
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `"$FLUTTER" test test/features/training/simulator_info_lines_test.dart test/core/strings/vi_simulator_test.dart`
Expected: FAIL. They do not compile: `info_lines.dart` is missing and `Vi.simElevation` is undefined.

- [ ] **Step 3: Implement**

In `lib/core/strings/vi.dart`, replace `simPowerPreset` with:

```dart
  /// Năm mức lực đứng cạnh nhau: chỉ số phần trăm là đủ rõ.
  static String simPowerPreset(double power) => '${power.round()}%';
```

Then insert right after `simScratch` (the line ending `'Bi cái rơi lỗ ${simPocket(pocket)} (chết cái).';`):

```dart
  // Lõi vật lý — docs/superpowers/specs/2026-10-02-poolcoachai-table-physics-design.md.
  static const simElevationLabel = 'Độ dốc cơ';
  static const simCompensateToggle = 'Xem nếu không bù ném';
  static const simComputing = 'Đang tính…';
  static const simObjectMissed = 'Bi mục tiêu không vào lỗ.';

  static String simElevation(CueElevation elevation) => switch (elevation) {
        CueElevation.normal => 'Thường',
        CueElevation.steep => 'Dốc',
      };

  static String simElevationLine(CueElevation elevation) =>
      'Độ dốc cơ: ${simElevation(elevation)}';

  /// Làm tròn tới bội số gần nhất của [step], bỏ số 0 thừa: 1.0 → "1".
  static String _rounded(double value, double step) {
    final r = (value / step).round() * step;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }

  /// [deg] dương là dày hơn (spec mục 4.6), làm tròn 0.5°.
  static String simAimOffset(double deg) =>
      '${deg > 0 ? 'Ngắm dày hơn' : 'Ngắm mỏng hơn'} '
      '${_rounded(deg.abs(), 0.5)}°';

  /// [offset] là `b`, cm (âm là dưới tâm), đổi ra đầu cơ, làm tròn 0.25.
  static String simStunOffset(double offset) =>
      'Đánh đứng bi: đặt cơ dưới tâm khoảng '
      '${_rounded(offset.abs() / tipWidth, 0.25)} đầu cơ';

  /// Góc lệch do áp phê, độ, làm tròn 0.5°.
  static String simSquirt(double deg) =>
      'Bi cái bị lệch do áp phê khoảng ${_rounded(deg.abs(), 0.5)}°';

  static String simRailCount(int count) => 'Bi cái chạm băng $count lần.';
```

`lib/features/training/presentation/simulator/info_lines.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';

/// Bù ném nhỏ hơn mức này (độ) thì tay người không chỉnh được: không nói.
const aimOffsetShownDeg = 0.5;

/// Đặt cơ lệch tâm ít hơn mức này (đầu cơ) thì coi như đánh tâm: không nói.
const stunOffsetShownTips = 0.25;

/// Các dòng của bảng thông tin (spec 2026-10-02 mục 6.3).
///
/// Hàm thuần, tách khỏi widget để test thẳng từng ngưỡng. Mọi số đều lấy
/// từ [aimed] và lõi; ở đây chỉ chọn dòng nào hiện. [advice] null nghĩa
/// là gợi ý chống chết cái đang tính.
List<String> simulatorInfoLines({
  required ShotResult? shot,
  required AimedShot? aimed,
  required List<Advice>? advice,
  required Stroke stroke,
  required double power,
  required SideSpin spin,
  required CueElevation elevation,
  TableSpec table = TableSpec.nineFoot,
}) {
  switch (shot) {
    case null:
      return [Vi.simNoPocket];
    // Không đánh được thì chỉ nói lý do.
    case Unmakeable(:final reason):
      return [Vi.simUnmakeable(reason)];
    case Makeable(:final geometry):
      final trace = aimed?.trace;
      return [
        Vi.simPocketLine(geometry.pocket),
        Vi.simAngleLine(geometry.angle),
        Vi.simBandLine(bandFor(geometry.angle)),
        Vi.simStrokeLine(stroke),
        Vi.simPowerLine(power),
        Vi.simSpinLine(spin),
        Vi.simElevationLine(elevation),
        if (aimed != null && aimed.aimOffsetDeg.abs() >= aimOffsetShownDeg)
          Vi.simAimOffset(aimed.aimOffsetDeg),
        if (aimed != null &&
            stroke == Stroke.stun &&
            aimed.verticalOffset.abs() >= stunOffsetShownTips * tipWidth)
          Vi.simStunOffset(aimed.verticalOffset),
        if (!spin.isNone)
          Vi.simSquirt(
              squirtAngle(sideOffsetOf(spin), table.radius) * 180 / math.pi),
        if (trace != null && trace.cueRailCount > 0)
          Vi.simRailCount(trace.cueRailCount),
        if (trace?.cuePocket case final pocket?) Vi.simScratch(pocket),
        if (trace != null && trace.objectPocket != geometry.pocket)
          Vi.simObjectMissed,
        if (spin.risksMiscue) Vi.simMiscue,
        if (advice == null) Vi.simComputing else ...advice.map(Vi.simAdvice),
      ];
  }
}
```

- [ ] **Step 4: Run them and confirm they pass**

Run: `"$FLUTTER" test test/features/training/simulator_info_lines_test.dart test/core/strings/vi_simulator_test.dart test/architecture_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings/vi.dart lib/features/training/presentation/simulator/info_lines.dart test/features/training/simulator_info_lines_test.dart test/core/strings/vi_simulator_test.dart
git commit -m "Word the throw compensation, the stun cue height, squirt and rail count, and choose which info lines the simulator shows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The simulator on the physics core — painter, controls, toggle, and advice after the finger lifts

**Files:**
- Modify: `lib/core/strings/vi.dart` (imports, remove `simBankWarning` and `simSpinNoRail`, new `simSummary`)
- Replace: `lib/features/training/presentation/simulator/table_painter.dart`, `simulator_panel.dart`, `simulator_screen.dart`
- Delete: `lib/domain/table_geometry/cue_ball_path.dart`, `test/domain/table_geometry/cue_ball_path_test.dart`, `test/domain/table_geometry/bank_spin_test.dart`
- Test: replace `test/features/training/simulator_screen_test.dart`; create `test/features/training/table_painter_test.dart`; replace the summary tests in `test/core/strings/vi_simulator_test.dart`

**Interfaces:**
- Consumes: `aimShot`, `AimedShot` (Task 7); `ScratchAdviceJob`, `scratchAdvice` (Task 8); `simulatorInfoLines`, the thresholds and the Task 9 strings.
- Produces:
  - `Vi.simNoAimOffset`, `Vi.simShowingUncompensated`, `static String Vi.simSummary(ShotResult? shot, AimedShot? aimed, {required CueElevation elevation, bool showingUncompensated = false})`
  - `class SimulatorScene { const SimulatorScene({required Vec2 cue, required Vec2 object, Pocket? pocket, ShotGeometry? geometry, AimedShot? aimed, bool showUncompensated = false, Pocket? riskPocket}); }`
  - `SimulatorPanel.compensateToggleKey`; the panel's new parameters `aimed`, `advice` (nullable), `elevation`, `showUncompensated`, `onElevation`, `onShowUncompensated` (null locks the toggle)
  - `SimulatorScreen.adviceSliceMs = 8` and `static bool SimulatorScreen.canShowUncompensated(ShotGeometry g, SideSpin spin)`

- [ ] **Step 1: Write the failing tests**

Replace `test/features/training/simulator_screen_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_screen.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/table_layouts.dart';
import '../../support/test_data.dart';

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5 và 2026-10-02 mục 6. Mọi con
/// số mong đợi lấy từ chính lõi, không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  final initial = bestPocket(
    cue: SimulatorScreen.initialCue,
    object: SimulatorScreen.initialObject,
  )!;

  Future<void> openSimulator(WidgetTester tester,
      {Size size = const Size(1200, 1800)}) async {
    // Mặc định đủ cao để cả bàn lẫn bảng thông tin nằm trong màn.
    tester.view.physicalSize = size;
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

    // Thả đúng tâm bi cái thì hướng đẩy ra dùng nhánh mặc định (1,0) của
    // _separate — gần như chắc chắn không thẳng hàng với lỗ nào, nên góc
    // cắt nhảy lên ~90° (quá mỏng) cho cả sáu lỗ dù _separate có chạy
    // đúng hay không — "findsNothing" cho overlap không phân biệt được gì.
    // Thả gần bi cái nhưng đúng trên tia bi cái→một lỗ cụ thể thì sau khi
    // tách, bi mục tiêu nằm đúng trên đường đó, góc cắt ~0 — một cú thật
    // đánh được, nên thiếu _separate (bi vẫn chồng) mới lộ ra khác biệt.
    const towardPocket = Pocket.bottomRight;
    final toward =
        (table.pocketPosition(towardPocket) - SimulatorScreen.initialCue)
            .normalized;
    final dropTarget = SimulatorScreen.initialCue + toward * 1.0;

    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, dropTarget) - from);
    await tester.pumpAndSettle();

    expect(find.text(Vi.simUnmakeable(UnmakeableReason.overlap)), findsNothing);
    expect(find.text(Vi.simNoPocket), findsNothing);
    expect(
      Pocket.values.any(
        (p) => find.text(Vi.simPocketLine(p)).evaluate().isNotEmpty,
      ),
      isTrue,
      reason: 'phải có một dòng Lỗ: ... nghĩa là bestPocket tính ra lỗ thật, '
          'chứng tỏ hai bi đã được tách nhau chứ không còn chồng lên nhau',
    );
  });

  // Điện thoại ~390 px: bàn co lại còn ~1.3 px/cm, nên bán kính tính theo cm
  // chỉ còn vài px — ngón tay phải có sàn bán kính trên màn.
  group('điện thoại 390x844', () {
    const phone = Size(390, 844);

    testWidgets('kéo bi bắt đầu lệch tâm ~15 px vẫn bắt được bi',
        (tester) async {
      await openSimulator(tester, size: phone);

      final centre = onTable(tester, SimulatorScreen.initialObject);
      final from = centre + const Offset(15, 0);
      const target = Vec2(170, 110);
      await tester.dragFrom(from, onTable(tester, target) - from);
      await tester.pumpAndSettle();

      final expected =
          bestPocket(cue: SimulatorScreen.initialCue, object: target)!;
      expect(find.text(Vi.simAngleLine(expected.angle)), findsOneWidget);
    });

    testWidgets('chạm lệch tâm lỗ ~15 px vẫn chọn lỗ đó', (tester) async {
      await openSimulator(tester, size: phone);

      final centre =
          onTable(tester, table.pocketPosition(Pocket.topMiddle));
      await tester.tapAt(centre + const Offset(0, 15));
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
  });

  // Bi kia cách băng ~1 cm, thả bi này sát nó về phía băng: hướng đẩy ra
  // ngoài bàn, kẹp lại thì chồng ~4.7 cm nếu không có cách xử lý riêng.
  group('tách hai bi chồng nhau sát băng', () {
    final other = Vec2(100, table.minY + 0.6);
    final drop = Vec2(other.x, table.minY);
    const previous = Vec2(40, 60);

    test('đẩy dọc theo băng thì hai bi không còn chồng', () {
      final moved = SimulatorScreen.separate(drop, other, previous);
      expect(moved.distanceTo(other), greaterThanOrEqualTo(table.ballDiameter));
      expect(table.contains(moved), isTrue);
    });

    test('giữa bàn thì vẫn đẩy theo hướng từ bi kia ra', () {
      const centre = Vec2(120, 60);
      final moved =
          SimulatorScreen.separate(centre + const Vec2(1, 0), centre, previous);
      expect(moved.distanceTo(centre), greaterThanOrEqualTo(table.ballDiameter));
      expect(moved.y, centre.y);
      expect(moved.x, greaterThan(centre.x));
    });
  });

  /// Cảnh mà bàn đang vẽ — lấy thẳng từ painter, không đoán.
  SimulatorScene sceneOf(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(SimulatorScreen.tableKey),
              matching: find.byType(CustomPaint)))
          .painter! as TablePainter)
      .scene;

  AimedShot aimedFor(ShotGeometry g,
          {Stroke stroke = Stroke.stun,
          SideSpin spin = const SideSpin.none(),
          CueElevation elevation = CueElevation.normal}) =>
      aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: stroke,
          spin: spin,
          power: powerPresets[1],
          elevation: elevation);

  testWidgets('có nút Độ dốc cơ và đủ năm mức lực', (tester) async {
    await openSimulator(tester);

    for (final p in powerPresets) {
      expect(find.text(Vi.simPowerPreset(p)), findsOneWidget);
    }
    expect(find.text(Vi.simElevation(CueElevation.normal)), findsOneWidget);
    expect(find.text(Vi.simElevation(CueElevation.steep)), findsOneWidget);

    await tapText(tester, Vi.simElevation(CueElevation.steep));
    expect(find.text(Vi.simElevationLine(CueElevation.steep)), findsOneWidget);
  });

  testWidgets('công tắc bù ném hiện và ẩn đường đỏ', (tester) async {
    await openSimulator(tester);
    expect(sceneOf(tester).showUncompensated, isFalse);

    final toggle = find.byKey(SimulatorPanel.compensateToggleKey);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).showUncompensated, isTrue);
    expect(sceneOf(tester).aimed!.uncompensated, isNotNull);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).showUncompensated, isFalse);
  });

  test('công tắc bù ném chỉ mở khi có ném: có áp phê hoặc góc cắt khác 0', () {
    final straight =
        geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 0);
    final cut = geometryFor(const Vec2(150, 63.5), Pocket.bottomRight, 20);
    const none = SideSpin.none();
    expect(SimulatorScreen.canShowUncompensated(straight, none), isFalse);
    expect(
        SimulatorScreen.canShowUncompensated(
            straight, const SideSpin(SpinSide.left, 0.5)),
        isTrue);
    expect(SimulatorScreen.canShowUncompensated(cut, none), isTrue);
  });

  testWidgets('bắn thẳng không áp phê thì công tắc bị khoá', (tester) async {
    await openSimulator(tester);
    // Thả bi mục tiêu sát bi cái, đúng trên tia bi cái → lỗ góc dưới
    // phải: sau khi tách, hai bi thẳng hàng với lỗ, góc cắt 0°.
    final toward = (table.pocketPosition(Pocket.bottomRight) -
            SimulatorScreen.initialCue)
        .normalized;
    final drop = SimulatorScreen.initialCue + toward * 1.0;
    final from = onTable(tester, SimulatorScreen.initialObject);
    await tester.dragFrom(from, onTable(tester, drop) - from);
    await tester.pumpAndSettle();

    expect(sceneOf(tester).geometry!.angle.round(), 0);
    final toggle = find.byKey(SimulatorPanel.compensateToggleKey);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
  });

  testWidgets('dòng ngắm dày/mỏng đúng chiều với aimOffsetDeg của lõi',
      (tester) async {
    const spin = SideSpin(SpinSide.right, 1);
    final expected = aimedFor(initial, spin: spin).aimOffsetDeg;
    expect(expected.abs(), greaterThanOrEqualTo(aimOffsetShownDeg),
        reason: 'bố cục mở màn có áp phê phải đủ bù để dòng này hiện');
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(spin));

    expect(find.text(Vi.simAimOffset(expected)), findsOneWidget);
  });

  testWidgets('dòng Đánh đứng bi chỉ hiện khi đánh đứng bi và đủ ngưỡng',
      (tester) async {
    final b = aimedFor(initial).verticalOffset;
    expect(b.abs(), greaterThanOrEqualTo(stunOffsetShownTips * tipWidth),
        reason: 'bố cục mở màn đủ xa để phải đặt cơ dưới tâm');
    await openSimulator(tester);
    expect(find.text(Vi.simStunOffset(b)), findsOneWidget);

    await tapText(tester, Vi.simStroke(Stroke.follow));
    expect(find.text(Vi.simStunOffset(b)), findsNothing);
  });

  testWidgets('gợi ý chống chết cái hiện Đang tính… khi kéo, cập nhật khi thả',
      (tester) async {
    await openSimulator(tester);
    expect(find.text(Vi.simComputing), findsNothing);

    final gesture = await tester
        .startGesture(onTable(tester, SimulatorScreen.initialObject));
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    expect(find.text(Vi.simComputing), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text(Vi.simComputing), findsNothing);

    final scene = sceneOf(tester);
    final g = scene.geometry!;
    final advice = scratchAdvice(g,
        stroke: Stroke.stun, power: powerPresets[1], spin: const SideSpin.none());
    for (final a in advice) {
      expect(find.text(Vi.simAdvice(a)), findsOneWidget);
    }
  });

  testWidgets('lệch 2 đầu cơ thì cảnh báo trượt cơ', (tester) async {
    await openSimulator(tester);

    await tapText(tester, Vi.simSpinChip(const SideSpin(SpinSide.left, 2)));

    expect(find.text(Vi.simMiscue), findsOneWidget);
  });

  testWidgets('bàn có nhãn semantics tóm tắt cú đánh', (tester) async {
    final handle = tester.ensureSemantics();
    await openSimulator(tester);

    expect(
        find.bySemanticsLabel(Vi.simSummary(Makeable(initial), aimedFor(initial),
            elevation: CueElevation.normal)),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'màn hình ngang Chrome desktop không tràn, bảng điều khiển vẫn bấm được',
      (tester) async {
    // Chrome là nền chạy được duy nhất, và cửa sổ desktop thường ngang hơn
    // là dọc — 1280x720 lộ ra lỗi mà khung portrait của các test trên
    // không bao giờ thấy: bàn cao vô hạn theo bề ngang, đẩy tràn RenderFlex.
    tester.view.physicalSize = const Size(1280, 720);
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

    expect(tester.takeException(), isNull);

    final tableBox = find.byKey(SimulatorScreen.tableKey);
    final topLeft = tester.getTopLeft(tableBox);
    final bottomRight = tester.getBottomRight(tableBox);
    expect(topLeft.dx, greaterThanOrEqualTo(0));
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    expect(bottomRight.dx, lessThanOrEqualTo(1280));
    expect(bottomRight.dy, lessThanOrEqualTo(720));

    await tapText(tester, Vi.simStroke(Stroke.draw));
    expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
  });

  // Bàn nằm trong Padding 16 px hai bên: tính kích thước theo cả bề ngang
  // thân màn thì SizedBox bị ép hẹp lại mà vẫn giữ chiều cao cũ — băng dưới
  // vẽ dày hơn hẳn. Tỉ lệ khung bàn phải đúng tỉ lệ của TableLayout.
  for (final size in const [Size(1200, 1800), Size(1280, 720)]) {
    testWidgets(
        'khung bàn giữ đúng tỉ lệ TableLayout ở '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
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

      final box = tester.getSize(find.byKey(SimulatorScreen.tableKey));
      expect(box.width / box.height,
          closeTo(TableLayout.aspectRatio(TableSpec.nineFoot), 0.01));
    });
  }
}
```

`test/features/training/table_painter_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/table_layouts.dart';

void main() {
  const size = Size(540, 286);

  void paint(SimulatorScene scene) {
    final recorder = PictureRecorder();
    TablePainter(scene).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  test('vẽ đủ mọi lớp: đường đỏ, chạm băng, chết cái, không lỗi', () {
    for (final (object, degrees, power) in [
      // Cu lê cắt có áp phê, bật đường đỏ: đủ lớp 1–8.
      (const Vec2(170, 70), 25.0, 45.0),
      // Cu lê thẳng sát lỗ: chết cái, lỗ tô đỏ, không vòng điểm dừng.
      (const Vec2(240, 14), 0.0, 90.0),
    ]) {
      final g = geometryFor(object, Pocket.topRight, degrees);
      final aimed = aimShot(
          cue: g.cue,
          object: g.object,
          pocket: g.pocket,
          stroke: Stroke.follow,
          spin: const SideSpin(SpinSide.right, 1),
          power: power);
      paint(SimulatorScene(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        geometry: g,
        aimed: aimed,
        showUncompensated: true,
        riskPocket: Pocket.bottomLeft,
      ));
    }
  });

  test('không đánh được thì chỉ vẽ bàn và hai bi', () {
    paint(const SimulatorScene(cue: Vec2(80, 90), object: Vec2(170, 50)));
  });

  test('cú cắt có ném dời Bi ảo khỏi chỗ hình học', () {
    final g = geometryFor(const Vec2(170, 70), Pocket.topRight, 30);
    final aimed = aimShot(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        stroke: Stroke.stun,
        spin: const SideSpin(SpinSide.right, 1),
        power: 45);
    // Lớp 3: lệch quá 0.1 cm thì phải chấm thêm Bi ảo hình học.
    expect(aimed.trace.contactCue!.distanceTo(g.ghost), greaterThan(0.1));
    expect(TableSpec.nineFoot.contains(aimed.trace.contactCue!), isTrue);
  });
}
```

Replace `test/core/strings/vi_simulator_test.dart` with the version below. It keeps every earlier test and the Task 9 group, adds the physics imports, and replaces the three `CueBallPath` summary tests with the group `nhãn tóm tắt của bàn`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/table_geometry/difficulty.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

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

  // Mức đầu cơ gợi ý mà dễ trượt cơ thì câu khuyên phải nói luôn, không đợi
  // người chơi chọn mức đó mới thấy cảnh báo.
  test('lời khuyên gợi ý mức dễ trượt cơ thì kèm cảnh báo Trượt cơ', () {
    expect(const SideSpin(SpinSide.right, 2).risksMiscue, isTrue);
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: none, to: right2, pocket: Pocket.topRight)),
      'Ít áp phê thì bi cái chết cái ở lỗ góc trên phải — nên áp phê phải '
      'lệch 2 đầu cơ (dễ Trượt cơ) để đổi góc bật tránh lỗ.',
    );
    expect(
      Vi.simAdvice(const AddSpinToAvoid(from: left1, to: right2, pocket: Pocket.topMiddle)),
      'Áp phê trái làm bi cái chết cái ở lỗ giữa trên — nên đổi sang áp phê '
      'phải lệch 2 đầu cơ (dễ Trượt cơ).',
    );
    expect(
      Vi.simAdvice(const OverhitRisk(
        margin: 12,
        fromPower: 82,
        pocket: Pocket.topRight,
        saferSpin: right2,
      )),
      'Nếu đánh quá lực khoảng +12% (từ ~82%), bi cái có thể rơi lỗ góc trên '
      'phải (chết cái). Áp phê phải lệch 2 đầu cơ (dễ Trượt cơ) thì vẫn an '
      'toàn tới 100%.',
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

  group('nhãn tóm tắt của bàn', () {
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

    AimedShot aimed({
      List<RailHit> rails = const [],
      Pocket? cuePocket,
      double aimOffsetDeg = 0,
    }) =>
        AimedShot(
          trace: ShotTrace(
            cueBefore: const [Vec2(80, 90), Vec2(165, 53)],
            cueAfter: const [Vec2(165, 53), Vec2(200, 100)],
            objectPath: const [Vec2(170, 50), Vec2(254, 0)],
            contactCue: const Vec2(165, 53),
            rails: rails,
            cuePocket: cuePocket,
            objectPocket: Pocket.topRight,
            cueEnd: const Vec2(200, 100),
          ),
          uncompensated: null,
          aimOffsetDeg: aimOffsetDeg,
          verticalOffset: 0,
          converged: true,
        );

    test('đủ góc cắt, độ dốc cơ và độ bù ném', () {
      expect(
          Vi.simSummary(const Makeable(g), aimed(),
              elevation: CueElevation.normal),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Thường. Không cần bù ném.');
      expect(
          Vi.simSummary(const Makeable(g), aimed(aimOffsetDeg: -1.2),
              elevation: CueElevation.steep),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Dốc. Ngắm mỏng hơn 1°.');
      expect(Vi.simBand(bandFor(7.4)), 'Dễ');
    });

    test('không đánh được thì chỉ nói lý do', () {
      expect(Vi.simSummary(null, null, elevation: CueElevation.normal),
          'Bàn mô phỏng. Không lỗ nào đánh được từ vị trí này.');
      expect(
          Vi.simSummary(const Unmakeable(UnmakeableReason.tooThin), null,
              elevation: CueElevation.normal),
          'Bàn mô phỏng. Góc cắt quá lớn (>85°).');
    });

    test('thêm số lần bi cái chạm băng sau va chạm, chết cái, đường đỏ', () {
      const hit = RailHit(
          ball: ShotBall.cue,
          pos: Vec2(251.1425, 80),
          rail: Rail.right,
          afterContact: true);
      expect(
          Vi.simSummary(
              const Makeable(g),
              aimed(rails: const [hit, hit], cuePocket: Pocket.bottomLeft),
              elevation: CueElevation.normal,
              showingUncompensated: true),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Thường. Không cần bù ném. Bi cái chạm băng 2 lần. Chết cái. '
          'Đang xem đường không bù ném.');
    });
  });

  test('Vi.simAdvice với NoSpinAvoids', () {
    expect(
      Vi.simAdvice(const NoSpinAvoids(pocket: Pocket.topRight)),
      'Bi cái chết cái ở lỗ góc trên phải, áp phê không cứu được — đổi lực hoặc kiểu đánh.',
    );
  });

  group('lõi vật lý', () {
    test('thuật ngữ mới đã chốt với chủ sản phẩm', () {
      expect(Vi.simElevationLabel, 'Độ dốc cơ');
      expect(Vi.simElevation(CueElevation.normal), 'Thường');
      expect(Vi.simElevation(CueElevation.steep), 'Dốc');
      expect(Vi.simElevationLine(CueElevation.steep), 'Độ dốc cơ: Dốc');
      expect(Vi.simCompensateToggle, 'Xem nếu không bù ném');
      expect(Vi.simComputing, 'Đang tính…');
      expect(Vi.simObjectMissed, 'Bi mục tiêu không vào lỗ.');
    });

    test('năm mức lực chỉ ghi phần trăm', () {
      expect([for (final p in powerPresets) Vi.simPowerPreset(p)],
          ['30%', '45%', '60%', '75%', '90%']);
    });

    test('ngắm dày/mỏng theo dấu, làm tròn 0.5°', () {
      expect(Vi.simAimOffset(1.24), 'Ngắm dày hơn 1°');
      expect(Vi.simAimOffset(1.26), 'Ngắm dày hơn 1.5°');
      expect(Vi.simAimOffset(-0.6), 'Ngắm mỏng hơn 0.5°');
      expect(Vi.simAimOffset(-2), 'Ngắm mỏng hơn 2°');
    });

    test('đặt cơ dưới tâm tính bằng đầu cơ, làm tròn 0.25', () {
      expect(Vi.simStunOffset(-0.66),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 0.5 đầu cơ');
      expect(Vi.simStunOffset(-1.714),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1.25 đầu cơ');
      expect(Vi.simStunOffset(-1.25),
          'Đánh đứng bi: đặt cơ dưới tâm khoảng 1 đầu cơ');
    });

    test('lệch do áp phê và số lần chạm băng', () {
      expect(Vi.simSquirt(1.55), 'Bi cái bị lệch do áp phê khoảng 1.5°');
      expect(Vi.simSquirt(0.83), 'Bi cái bị lệch do áp phê khoảng 1°');
      expect(Vi.simRailCount(3), 'Bi cái chạm băng 3 lần.');
    });
  });
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `"$FLUTTER" test test/features/training test/core/strings/vi_simulator_test.dart`
Expected: FAIL. They do not compile: `SimulatorPanel.compensateToggleKey`, `SimulatorScene.aimed` and the new `simSummary` signature are missing.

- [ ] **Step 3: Implement the strings**

In `lib/core/strings/vi.dart`:
1. Replace `import 'package:poolcoachai/domain/table_geometry/cue_ball_path.dart';` by adding `import 'package:poolcoachai/domain/table_physics/aim.dart';` after the `table_spec.dart` import.
2. Delete `simBankWarning` and `simSpinNoRail`. Both statements stop being true on the new core: áp phê now bends the path before any rail, and the rail count is information, not a warning.
3. Replace the whole `simSummary` method (from its doc comment to its closing brace) with:

```dart
  static const simNoAimOffset = 'Không cần bù ném';
  static const simShowingUncompensated = 'Đang xem đường không bù ném.';

  /// Độ bù ném cho nhãn tóm tắt: làm tròn ra 0° thì nói là không cần.
  static String _aimSummary(double deg) =>
      _rounded(deg.abs(), 0.5) == '0' ? simNoAimOffset : simAimOffset(deg);

  /// Nhãn semantics của bàn: trình đọc màn hình và E2E đọc từ đây — nên
  /// có đủ số lần chạm băng, độ bù ném và độ dốc cơ để phân biệt từng cảnh.
  static String simSummary(
    ShotResult? shot,
    AimedShot? aimed, {
    required CueElevation elevation,
    bool showingUncompensated = false,
  }) {
    const head = 'Bàn mô phỏng.';
    return switch (shot) {
      null => '$head $simNoPocket',
      Unmakeable(:final reason) => '$head ${simUnmakeable(reason)}',
      Makeable(:final geometry) => [
          '$head Lỗ ${simPocket(geometry.pocket)}, góc cắt '
              '${geometry.angle.round()}°, ${simBand(bandFor(geometry.angle))}.',
          '${simElevationLine(elevation)}.',
          if (aimed != null)
            '${_aimSummary(aimed.aimOffsetDeg)}.',
          if (aimed != null && aimed.trace.cueRailCount > 0)
            simRailCount(aimed.trace.cueRailCount),
          if (aimed?.trace.cuePocket != null) 'Chết cái.',
          if (showingUncompensated) simShowingUncompensated,
        ].join(' '),
    };
  }
```

- [ ] **Step 4: Implement the painter, the panel and the screen**

`lib/features/training/presentation/simulator/table_painter.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

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
    this.aimed,
    this.showUncompensated = false,
    this.riskPocket,
  });

  final Vec2 cue;
  final Vec2 object;

  /// Lỗ đang dùng (tự chọn hoặc người chơi chạm).
  final Pocket? pocket;
  final ShotGeometry? geometry;

  /// Cú đánh đã dò và mô phỏng; null khi không đánh được.
  final AimedShot? aimed;

  /// Công tắc *Xem nếu không bù ném* đang bật (và đang có ném).
  final bool showUncompensated;

  /// Lỗ có nguy cơ chết cái khi dư lực — vẽ vòng nét đứt.
  final Pocket? riskPocket;
}

/// Vẽ bàn theo spec 2026-10-02 mục 6.2, từ dưới lên.
class TablePainter extends CustomPainter {
  TablePainter(this.scene);

  final SimulatorScene scene;

  static const _pocketDrawRadius = 5.5; // cm
  static const _dash = 2.0; // cm
  static const _gap = 1.5; // cm
  static const _railDot = 1.2; // cm
  static const _ghostDot = 0.8; // cm

  /// Bi ảo đã bù lệch khỏi Bi ảo hình học quá mức này (cm) thì chấm thêm
  /// chỗ hình học, để thấy bù ném dời điểm chạm bao nhiêu.
  static const _ghostShift = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final table = layout.table;
    final s = layout.scale;
    final aimed = scene.aimed;
    final trace = aimed?.trace;

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
          ..color = trace?.cuePocket == pocket
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
    if (g != null && aimed != null && trace != null) {
      List<Offset> px(List<Vec2> pts) =>
          [for (final p in pts) layout.toCanvas(p)];

      // 1. Đường ngắm hình học (bi cái → Bi ảo hình học): vạch mờ.
      canvas.drawLine(
        layout.toCanvas(scene.cue),
        layout.toCanvas(g.ghost),
        Paint()
          ..color = AppColors.aimLine.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );

      // 2. Bi cái tới bi mục tiêu: nét đứt trắng — thấy bi cái bị lệch
      // do áp phê và swerve.
      _dashedPolyline(
        canvas,
        px(trace.cueBefore),
        Paint()
          ..color = AppColors.aimLine
          ..strokeWidth = 1.5,
        s,
      );

      // 3. Bi ảo đã bù: vòng nét đứt; lệch xa Bi ảo hình học thì chấm
      // mờ chỗ hình học.
      final contact = trace.contactCue;
      if (contact != null) {
        _dashedCircle(
          canvas,
          layout.toCanvas(contact),
          table.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.aimLine,
        );
        if (contact.distanceTo(g.ghost) > _ghostShift) {
          canvas.drawCircle(layout.toCanvas(g.ghost), _ghostDot * s,
              Paint()..color = AppColors.aimLine.withValues(alpha: 0.4));
        }
      }

      // 8. Bật công tắc: đường bi mục tiêu nếu không bù ném, đỏ mờ. Vẽ
      // trước đường thật để không che nó.
      final red = aimed.uncompensated;
      if (scene.showUncompensated && red != null) {
        _polyline(
          canvas,
          px(red.objectPath),
          Paint()
            ..color = AppColors.danger.withValues(alpha: 0.55)
            ..strokeWidth = 2,
        );
      }

      // 4. Bi mục tiêu: nét liền.
      _polyline(
        canvas,
        px(trace.objectPath),
        Paint()
          ..color = AppColors.textSecondary
          ..strokeWidth = 1.5,
      );

      // 5. Bi cái sau va chạm: nét đứt màu ngọc, đúng chuỗi điểm của
      // mô phỏng — chỗ cong là cong thật.
      _dashedPolyline(
        canvas,
        px(trace.cueAfter),
        Paint()
          ..color = AppColors.cuePath
          ..strokeWidth = 2,
        s,
      );

      // 6. Mỗi lần bi cái chạm băng: chấm vàng.
      for (final hit in trace.rails) {
        if (hit.ball != ShotBall.cue) continue;
        canvas.drawCircle(layout.toCanvas(hit.pos), _railDot * s,
            Paint()..color = AppColors.railHit);
      }

      // 7. Điểm dừng bi cái: vòng trắng cỡ bi. Chết cái thì lỗ đã tô đỏ.
      if (trace.cuePocket == null) {
        canvas.drawCircle(
          layout.toCanvas(trace.cueEnd),
          table.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.ballCue,
        );
      }
    }

    canvas.drawCircle(layout.toCanvas(scene.object), table.radius * s,
        Paint()..color = AppColors.ballObject);
    canvas.drawCircle(layout.toCanvas(scene.cue), table.radius * s,
        Paint()..color = AppColors.ballCue);
  }

  void _polyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

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

`lib/features/training/presentation/simulator/simulator_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

/// Phần dưới bàn: nút chỉnh, công tắc bù ném, bảng thông tin, disclaimer.
class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({
    required this.shot,
    required this.aimed,
    required this.advice,
    required this.stroke,
    required this.power,
    required this.spin,
    required this.elevation,
    required this.showUncompensated,
    required this.onStroke,
    required this.onPower,
    required this.onSpin,
    required this.onElevation,
    required this.onShowUncompensated,
    super.key,
  });

  /// Khoá của công tắc *Xem nếu không bù ném*, cho test.
  static const compensateToggleKey = Key('simulator-compensate-toggle');

  /// null khi không lỗ nào đánh được.
  final ShotResult? shot;
  final AimedShot? aimed;

  /// null khi gợi ý chống chết cái đang tính.
  final List<Advice>? advice;
  final Stroke stroke;
  final double power;
  final SideSpin spin;
  final CueElevation elevation;
  final bool showUncompensated;
  final ValueChanged<Stroke> onStroke;
  final ValueChanged<double> onPower;
  final ValueChanged<SideSpin> onSpin;
  final ValueChanged<CueElevation> onElevation;

  /// null khi công tắc bị khoá (không có ném để xem).
  final ValueChanged<bool>? onShowUncompensated;

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
        chips(Vi.simElevationLabel, CueElevation.values, elevation,
            Vi.simElevation, onElevation),
        SwitchListTile(
          key: compensateToggleKey,
          contentPadding: EdgeInsets.zero,
          title: Text(Vi.simCompensateToggle, style: text.bodyMedium),
          value: showUncompensated,
          onChanged: onShowUncompensated,
        ),
        PcCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in simulatorInfoLines(
                  shot: shot,
                  aimed: aimed,
                  advice: advice,
                  stroke: stroke,
                  power: power,
                  spin: spin,
                  elevation: elevation,
                ))
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

`lib/features/training/presentation/simulator/simulator_screen.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/scratch.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/simulator/simulator_panel.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

enum _Ball { cue, object }

/// Mô phỏng góc cắt — spec 2026-10-01 mục 5, chạy trên lõi vật lý của
/// spec 2026-10-02 mục 6.
///
/// State cục bộ: không có gì để lưu hay chia sẻ, rời màn là mất.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  /// Khoá của bàn, để test quy đổi toạ độ bàn ra điểm chạm trên màn.
  static const tableKey = Key('simulator-table');

  /// Bố cục mở màn: một cú cắt nhẹ, hợp lệ.
  static const initialCue = Vec2(80, 90);
  static const initialObject = Vec2(170, 50);

  /// Mỗi khung hình chạy gợi ý chống chết cái tối đa ngần này mili giây,
  /// để Chrome vẫn vẽ kịp 60 khung hình/giây trong lúc chờ.
  static const adviceSliceMs = 8;

  /// Có ném thì mới có đường "không bù ném" để xem: cần áp phê (SIT) hoặc
  /// góc cắt hiện trên màn khác 0° (CIT).
  static bool canShowUncompensated(ShotGeometry g, SideSpin spin) =>
      !spin.isNone || g.angle.round() != 0;

  /// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
  ///
  /// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
  /// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
  ///
  /// Sát băng thì hướng đẩy có thể chỉ ra ngoài bàn, kẹp lại là chồng tiếp.
  /// Khi đó thử trượt dọc theo băng (đẩy theo từng trục, về phía điểm thả);
  /// không cách nào tách được thì giữ [previous] — bi không nhảy.
  @visibleForTesting
  static Vec2 separate(Vec2 p, Vec2 other, Vec2 previous,
      {TableSpec table = TableSpec.nineFoot}) {
    final d = table.ballDiameter;
    if ((p - other).length >= d) return p;
    bool clear(Vec2 v) => v.distanceTo(other) >= d;

    final gap = p - other;
    final dir = gap.isZero ? const Vec2(1, 0) : gap.normalized;
    final direct = table.clamp(other + dir * (d + 1e-6));
    if (clear(direct)) return direct;

    final sx = gap.x < 0 ? -1.0 : 1.0;
    final sy = gap.y < 0 ? -1.0 : 1.0;
    final slides = [
      Vec2(sx, 0), Vec2(-sx, 0), Vec2(0, sy), Vec2(0, -sy), //
    ];
    for (final s in slides) {
      final slid = table.clamp(other + s * (d + 1e-6));
      if (clear(slid)) return slid;
    }
    return previous;
  }

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

  /// Sàn bán kính chạm trên màn, tính bằng px logic. Trên điện thoại bàn co
  /// còn ~1.3 px/cm, nên bán kính tính theo cm chỉ còn vài px — nhỏ hơn
  /// đầu ngón tay. Lấy lớn hơn giữa bán kính cm và sàn này.
  static const _minTouchPx = 24.0;

  /// Lề quanh bàn — kích thước bàn tính trên phần còn lại sau lề này.
  static const _tablePadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  Vec2 _cue = SimulatorScreen.initialCue;
  Vec2 _object = SimulatorScreen.initialObject;
  Pocket? _pocketOverride;
  Stroke _stroke = Stroke.stun;
  double _power = powerPresets[1];
  SideSpin _spin = const SideSpin.none();
  CueElevation _elevation = CueElevation.normal;
  bool _showUncompensated = false;
  _Ball? _dragging;

  /// Gợi ý chống chết cái; null khi đang tính (spec mục 5, quyết định 13).
  List<Advice>? _advice;
  ScratchAdviceJob? _job;

  @override
  void initState() {
    super.initState();
    _startAdvice();
  }

  @override
  void dispose() {
    _job = null;
    super.dispose();
  }

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

  /// Bắt đầu tính gợi ý cho bố cục và nút chỉnh hiện tại, từng chút một
  /// giữa các khung hình. Gọi khi thả tay hoặc đổi nút chỉnh — không gọi
  /// mỗi khung hình lúc kéo, vì một lần tính đắt gần trăm lần mô phỏng.
  void _startAdvice() {
    final shot = _shot();
    if (shot is! Makeable) {
      _job = null;
      _advice = const [];
      return;
    }
    final job = ScratchAdviceJob(shot.geometry,
        stroke: _stroke,
        power: _power,
        spin: _spin,
        elevation: _elevation,
        table: _table);
    _job = job;
    _advice = null;
    _scheduleAdvice(job);
  }

  void _scheduleAdvice(ScratchAdviceJob job) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => _pumpAdvice(job));
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pumpAdvice(ScratchAdviceJob job) {
    // Bố cục đã đổi từ lúc bắt đầu: bỏ kết quả cũ.
    if (!mounted || !identical(job, _job)) return;
    final slice = Stopwatch()..start();
    List<Advice>? done;
    while (done == null &&
        slice.elapsedMilliseconds < SimulatorScreen.adviceSliceMs) {
      done = job.step();
    }
    if (done == null) {
      _scheduleAdvice(job);
      return;
    }
    setState(() {
      _advice = done;
      _job = null;
    });
  }

  /// Đổi một nút chỉnh: tính lại cú đánh ngay, gợi ý tính dần.
  void _change(VoidCallback update) {
    setState(() {
      update();
      _startAdvice();
    });
  }

  void _onPanStart(DragStartDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final grab = math.max(_table.radius * _grabRadii, _minTouchPx / layout.scale);
    final toCue = p.distanceTo(_cue);
    final toObject = p.distanceTo(_object);
    if (toCue > grab && toObject > grab) return;
    _dragging = toCue <= toObject ? _Ball.cue : _Ball.object;
  }

  void _onPanUpdate(DragUpdateDetails details, TableLayout layout) {
    final dragging = _dragging;
    if (dragging == null) return;
    final other = dragging == _Ball.cue ? _object : _cue;
    final moved = SimulatorScreen.separate(
        _table.clamp(layout.toTable(details.localPosition)),
        other,
        dragging == _Ball.cue ? _cue : _object);
    setState(() {
      if (dragging == _Ball.cue) {
        _cue = moved;
      } else {
        _object = moved;
      }
      // Kéo bi là bố cục mới: quay về tự chọn lỗ.
      _pocketOverride = null;
      // Lúc kéo chỉ tính cú đang xem; gợi ý chờ tới khi thả tay.
      _job = null;
      _advice = null;
    });
  }

  void _onPanEnd() {
    if (_dragging == null) return;
    _dragging = null;
    setState(_startAdvice);
  }

  void _onTapUp(TapUpDetails details, TableLayout layout) {
    final p = layout.toTable(details.localPosition);
    final reach = math.max(_pocketTapRadius, _minTouchPx / layout.scale);
    for (final pocket in Pocket.values) {
      if (p.distanceTo(_table.pocketPosition(pocket)) <= reach) {
        _change(() => _pocketOverride = pocket);
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
    final aimed = geometry == null
        ? null
        : aimShot(
            cue: geometry.cue,
            object: geometry.object,
            pocket: geometry.pocket,
            stroke: _stroke,
            spin: _spin,
            power: _power,
            elevation: _elevation,
            table: _table,
          );
    final canToggle = geometry != null &&
        SimulatorScreen.canShowUncompensated(geometry, _spin);
    final showRed = canToggle && _showUncompensated;
    final scene = SimulatorScene(
      cue: _cue,
      object: _object,
      pocket: geometry?.pocket ?? _pocketOverride,
      geometry: geometry,
      aimed: aimed,
      showUncompensated: showRed,
      riskPocket: _advice?.whereType<OverhitRisk>().firstOrNull?.pocket,
    );

    return PcRootScaffold(
      title: Vi.simTitle,
      // Bàn nằm ngoài vùng cuộn: kéo dọc trên bàn là kéo bi, không cuộn trang.
      body: LayoutBuilder(
        builder: (context, bodyConstraints) {
          // Trên Chrome desktop, cửa sổ ngang hơn dọc: bàn cao theo chiều
          // rộng mà không trần thì tràn RenderFlex và bảng điều khiển biến
          // mất. Ghim chiều cao bàn theo cái nhỏ hơn giữa "vừa bề ngang" và
          // "tối đa 55% chiều cao thân màn" — còn lại luôn dành cho bảng.
          //
          // Trần tính trên phần còn lại sau Padding của bàn: tính theo cả bề
          // ngang thì SizedBox bị ép hẹp mà giữ chiều cao, bàn méo tỉ lệ.
          final aspectRatio = TableLayout.aspectRatio(_table);
          final availableWidth = (bodyConstraints.maxWidth -
                  _tablePadding.horizontal)
              .clamp(0.0, double.infinity);
          final maxTableHeight = (bodyConstraints.maxHeight * 0.55 -
                  _tablePadding.vertical)
              .clamp(0.0, double.infinity);
          final widthLimitedHeight = availableWidth / aspectRatio;
          final tableHeight = widthLimitedHeight < maxTableHeight
              ? widthLimitedHeight
              : maxTableHeight;
          final tableWidth = tableHeight * aspectRatio;

          return Column(
            children: [
              Padding(
                padding: _tablePadding,
                child: Center(
                  child: SizedBox(
                    width: tableWidth,
                    height: tableHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = TableLayout(
                            size: constraints.biggest, table: _table);
                        return Semantics(
                          label: Vi.simSummary(shot, aimed,
                              elevation: _elevation,
                              showingUncompensated: showRed),
                          child: GestureDetector(
                            key: SimulatorScreen.tableKey,
                            dragStartBehavior: DragStartBehavior.down,
                            onPanStart: (d) => _onPanStart(d, layout),
                            onPanUpdate: (d) => _onPanUpdate(d, layout),
                            onPanEnd: (_) => _onPanEnd(),
                            onPanCancel: _onPanEnd,
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
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SimulatorPanel(
                    shot: shot,
                    aimed: aimed,
                    advice: _advice,
                    stroke: _stroke,
                    power: _power,
                    spin: _spin,
                    elevation: _elevation,
                    showUncompensated: _showUncompensated,
                    onStroke: (v) => _change(() => _stroke = v),
                    onPower: (v) => _change(() => _power = v),
                    onSpin: (v) => _change(() => _spin = v),
                    onElevation: (v) => _change(() => _elevation = v),
                    onShowUncompensated: canToggle
                        ? (v) => setState(() => _showUncompensated = v)
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Delete the old path model and its tests**

```bash
git rm lib/domain/table_geometry/cue_ball_path.dart test/domain/table_geometry/cue_ball_path_test.dart test/domain/table_geometry/bank_spin_test.dart
```

Then confirm that nothing still refers to the old model:

Run: `grep -rn "cue_ball_path\|CueBallPath\|simulateCueBall\|maxTravel\|rollCarry\|spinDegPerRadius\|simBankWarning\|simSpinNoRail" lib test`
Expected: no output.

- [ ] **Step 6: Run the analyzer and the whole suite**

Run: `"$FLUTTER" analyze lib test`
Expected: `No issues found!`

Run: `"$FLUTTER" test`
Expected: `+519 ~1: All tests passed!` (the skipped test is `perf`). This takes about 4 minutes; the slowest files are `advice_test.dart` (~30 s) and the physics grids.

- [ ] **Step 7: Commit**

```bash
git add -A lib test
git commit -m "Draw the simulator from the physics trace, with throw compensation, cue elevation, five powers, and Chết cái advice computed after the finger lifts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Real Chrome, the frame budget, the owner's eye check, and tuning

**Files:**
- Replace: `tool/e2e/simulator.mjs`
- Modify: `docs/superpowers/logs/2026-10-01-cut-angle-simulator-followups.md` (append a section)
- Modify only if the owner asks: values in `lib/domain/table_physics/constants.dart`

**Interfaces:**
- Consumes: `launch`, `sleep` (`tool/e2e/cdp.mjs`); `registerThrowaway`, `deleteUserByEmail` (`tool/e2e/throwaway_user.mjs`); the semantics label from `Vi.simSummary`; the chip and toggle labels from `Vi`.
- Produces: `node tool/e2e/simulator.mjs [appUrl]`. It prints each scene's semantics label and the drag frame statistics `{ n, median, p95, max }`, both unthrottled and at 4× CPU throttling. It writes screenshots to `%TMP%/pcai-sim`, and it fails if the unthrottled median exceeds 17 ms or the p95 exceeds 20 ms.

The layouts below were found by running `aimShot` on the Dart VM with the cue ball at its opening spot `(80, 90)`. `STRAIGHT` is collinear with the bottom-right pocket. On the VM, `HALF_BALL` is a 29.0° cut to the top-right pocket, Đánh cu lê at 45 % hits 4 rails, and Đánh đứng bi at 60 % hits 3. `TWO_RAILS` with Đánh đứng bi at 60 % hits 2 rails. `FAR` with Đánh đứng bi at 30 % needs the cue 1.37 tips below centre, shown as "khoảng 1.25 đầu cơ".

- [ ] **Step 1: Replace `tool/e2e/simulator.mjs`**

```js
// Mở Mô phỏng góc cắt trên Chrome thật: đọc nhãn semantics của bàn, chụp từng cảnh,
// và đo thời gian khung hình lúc kéo bi trên Chrome giả lập điện thoại.
//   node tool/e2e/simulator.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó: thiếu
// biến thì dừng ngay, đừng để user thử rò rỉ trên bản thật (như accounts.mjs).
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-sim');
const email = `e2e-sim-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

// Bố cục tìm bằng aimShot trên Dart VM với bi cái ở chỗ mở màn (80, 90) —
// không đoán. Bi mục tiêu bắt đầu ở (170, 50).
const START = [170, 50];
const STRAIGHT = [177.81, 110.8]; // thẳng hàng bi cái → lỗ góc dưới phải, góc cắt 0°
const HALF_BALL = [170, 70]; // ~29° vào lỗ góc trên phải
const TWO_RAILS = [150, 40]; // đứng bi 60 %: bi cái chạm 2 băng
const FAR = [220, 40]; // đứng bi 30 %: đặt cơ dưới tâm ~1.25 đầu cơ

// Kéo bi không được rớt khung (spec mục 5): trung vị và p95 khoảng cách
// giữa hai khung hình (ms) lúc kéo, trên Chrome giả lập điện thoại
// (cdp.mjs đặt 412x915, mobile). 60 Hz là 16.7 ms; chừa nhiễu vsync.
const FRAME_MEDIAN_MAX = 17;
const FRAME_P95_MAX = 20;

const tab = await launch({ port: 9335, name: 'mo-phong' });

async function summary() {
  return (await tab.labels()).find((l) => l.startsWith('Bàn mô phỏng'));
}

async function tableRect() {
  // Đọc nhãn y như cdp.mjs labels(): Flutter web để nhãn ở textContent chứ
  // không phải aria-label. Node cha có textContent bắt đầu bằng chữ AppBar,
  // nên chỉ đúng node của bàn khớp startsWith.
  await tab.semantics();
  return tab.eval(`(() => {
    const e = [...document.querySelectorAll('flt-semantics')]
      .find((n) => (n.getAttribute('aria-label') || n.textContent || '').trim().startsWith('Bàn mô phỏng'));
    const r = e.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width };
  })()`);
}

function toPx(r, [x, y]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [r.x + (x + FRAME) * s, r.y + (y + FRAME) * s];
}

/** Kéo bi từ [fromCm] tới [toCm]; trả khoảng cách giữa các khung hình (ms) lúc kéo. */
async function drag(fromCm, toCm, { moves = 12 } = {}) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.eval(`(() => {
    window.__frames = [];
    window.__recording = true;
    let last = performance.now();
    const tick = (t) => {
      window.__frames.push(t - last);
      last = t;
      if (window.__recording) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  })()`);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= moves; i++) {
    // Dồn hết mouseMoved vào một khung hình thì Flutter không nhận ra kéo.
    await sleep(30);
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / moves, y: y0 + ((y1 - y0) * i) / moves, button: 'left', buttons: 1,
    });
  }
  // Khung đầu đo từ lúc bật bộ ghi, không phải khoảng giữa hai khung: bỏ.
  const frames = await tab.eval(`(() => { window.__recording = false; return window.__frames.slice(1); })()`);
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
  // Thả tay thì gợi ý chống chết cái tính dần: chờ hết "Đang tính…".
  await sleep(500);
  for (let i = 0; i < 30 && (await tab.text()).includes('Đang tính…'); i++) await sleep(500);
  return frames;
}

function stats(frames) {
  const s = [...frames].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, median: at(0.5), p95: at(0.95), max: s[s.length - 1] };
}

async function capture(name, mustInclude = []) {
  const label = await summary();
  console.log(`${name}: ${label}`);
  await tab.shot(path.join(shots, `${name}.png`));
  for (const needle of mustInclude) {
    if (!label?.includes(needle)) throw new Error(`${name}: nhãn của bàn thiếu "${needle}"`);
  }
  return label;
}

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });
  await tab.goto(`${APP}/training/simulator`);
  await tab.waitForText('Bàn mô phỏng');
  await capture('0-mac-dinh-dung-bi-45', ['góc cắt', 'Độ dốc cơ: Thường']);

  // Đo khung hình trước khi chụp các cảnh: kéo qua lại quanh chỗ mở màn.
  const free = stats([
    ...(await drag(START, TWO_RAILS, { moves: 24 })),
    ...(await drag(TWO_RAILS, START, { moves: 24 })),
  ]);
  console.log(`Khung hình lúc kéo (giả lập điện thoại): ${JSON.stringify(free)}`);
  // Thêm một lượt ở CPU chậm 4 lần, chỉ để chủ sản phẩm tham khảo.
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  const slow = stats(await drag(START, TWO_RAILS, { moves: 24 }));
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await drag(TWO_RAILS, START);
  console.log(`Khung hình lúc kéo, CPU chậm 4 lần (tham khảo): ${JSON.stringify(slow)}`);

  // 1. Cu lê bắn thẳng · trô bắn thẳng.
  await drag(START, STRAIGHT);
  await tab.click('Đánh cu lê');
  await capture('1a-cu-le-thang-45', ['góc cắt 0°']);
  await tab.click('Đánh trô bi');
  await capture('1b-tro-thang-45', ['góc cắt 0°']);

  // 2. Cu lê cắt nửa bi: thấy đoạn cong rồi thẳng.
  await drag(STRAIGHT, HALF_BALL);
  await tab.click('Đánh cu lê');
  await capture('2-cu-le-cat-nua-bi-45');

  // 4. Áp phê phải 1 đầu cơ, bật và tắt Xem nếu không bù ném.
  await tab.click('Phải 1');
  await capture('4a-ap-phe-phai-1');
  await tab.click('Xem nếu không bù ném');
  await capture('4b-ap-phe-phai-1-khong-bu-nem', ['Đang xem đường không bù ném']);
  await tab.click('Xem nếu không bù ném');

  // 5. Cùng áp phê, cơ Thường rồi cơ Dốc: thấy swerve.
  await capture('5a-co-thuong', ['Độ dốc cơ: Thường']);
  await tab.click('Dốc');
  await capture('5b-co-doc', ['Độ dốc cơ: Dốc']);
  await tab.click('Thường');

  // 3. Bi cái chạm 2–3 băng.
  await tab.click('Không');
  await tab.click('Đánh đứng bi');
  await tab.click('60%');
  await drag(HALF_BALL, TWO_RAILS);
  await capture('3-dung-bi-60-cham-bang', ['Bi cái chạm băng']);

  // 6. Đánh đứng bi ở xa: dòng đặt cơ dưới tâm.
  await tab.click('30%');
  await drag(TWO_RAILS, FAR);
  await tab.waitForText('Đánh đứng bi: đặt cơ dưới tâm');
  await capture('6-dung-bi-xa-30');

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  if (free.median > FRAME_MEDIAN_MAX || free.p95 > FRAME_P95_MAX) {
    throw new Error(`Kéo bi rớt khung: trung vị ${free.median.toFixed(1)} ms, p95 ${free.p95.toFixed(1)} ms`);
  }
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
```

Check the syntax: `node --check tool/e2e/simulator.mjs`. Expected: no output.

- [ ] **Step 2: Build, serve locally, and run it**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/simulator.mjs http://localhost:5555
```

Load the secrets from the main checkout's `.claude/settings.local.json` `env` block with a `node -e` one-liner (memory: poolcoachai-deploy). Expected:
- every scene prints a label starting with `Bàn mô phỏng.`;
- scenes 0, 1a/1b, 3, 4b, 5a and 5b pass their label checks;
- scene 6 finds the line `Đánh đứng bi: đặt cơ dưới tâm`;
- there are no console errors;
- there are 10 screenshots;
- the frame line shows median ≤ 17 ms and p95 ≤ 20 ms.

If the frame gate fails, **stop and report** the two printed frame lines to the owner. Do not optimise on your own. The candidate fixes, for the owner to choose: compute `uncompensated` only while the toggle is on, which saves one full simulation per drag frame; or record one sample every two steps. The prototype measured `aimShot` at 6–8 ms median under `dart compile js -O2` in Node, before any Flutter frame cost.

- [ ] **Step 3: The owner's eye check: STOP here.**

The controller shows the owner the 10 screenshots, the printed labels and both frame lines, and asks them to judge. Spec decision 4 says the owner sets the constants of spec §3 by eye. Ask specifically:
- Does each power go a believable distance? On the prototype, Đánh cu lê at 45 % from the opening spot ran 3–4 rails; if that is too lively, the knobs are `muRoll`, `cushionRestitution` and `maxCueSpeed`.
- Do the curves look real: the follow bend in scene 2, the draw back in 1b, and the swerve difference between 5a and 5b?
- Is the throw compensation (*Ngắm dày/mỏng hơn X°*, and the red line in 4b) a believable size?
- Is squirt at 1 tip (*Bi cái bị lệch do áp phê khoảng 1.5°*) right for the owner's cue? `endMassRatio` sets it.
- Is the stun cue height in scene 6 what the owner would actually do?
- Show the owner the "Deviations from spec" section of this plan, and get an explicit OK on items 1–3 and 9.

Do not change any constant without the owner's answer.

- [ ] **Step 4: Apply the owner's tuning, if any**
1. Change only the named values in `constants.dart`.
2. Re-run `"$FLUTTER" test` and `"$FLUTTER" test --tags perf --run-skipped`. Tests reference the constants, so they should stay green. A red test means the new value broke a physical property the spec asks for (for example the 30° rule or the 2–4° throw band). Report that to the owner rather than relaxing the test.
3. Rebuild, re-run Step 2, and show the new screenshots.
4. Repeat until the owner approves.

- [ ] **Step 5: Log what this plan closed**

Append to `docs/superpowers/logs/2026-10-01-cut-angle-simulator-followups.md`:

```markdown
## Update 2026-10-02 — the simulator moved onto the table physics core

Plan: `docs/superpowers/plans/2026-10-02-poolcoachai-table-physics.md`.

### Closed

- Drag frame time on mobile Chrome is now measured by `tool/e2e/simulator.mjs`
  (gate: median ≤ 17 ms, p95 ≤ 20 ms). Measured: <paste the two frame lines>.
  Dragging runs only `aimShot`; `scratchAdvice` runs after the finger lifts,
  sliced across frames by `ScratchAdviceJob`, with "Đang tính…" meanwhile.
- The áp phê effects spec was written and built: squirt, swerve, CIT/SIT throw
  and the post-contact curve come from the physics core.
- The banked trô reading is moot: `cue_ball_path.dart` and its
  straight-after-rail rule are gone; the trace is whatever the physics does.
- `scratchMargin` now always reaches exactly 100 % (coarse scan clamps to 100),
  tested with a start power of 87 %.
- The grid scratch-invariant test now requires at least one scratch.
- Stale `_dragging` after a cancelled pan: `onPanCancel` now ends the drag.
- Scenarios with the same shot no longer share one label: the semantics label
  carries the elevation, the throw compensation, the rail count and the toggle.

### Obsolete with `cue_ball_path.dart`

- Curve-clamp tangent conflict, `_truncateAtScratch` never sampling t = 0,
  `Straight.pointAt(1)`, the second-rail zero-vector edge, the dense-sampling
  guard, the first-segment comparison in the áp phê test, and the corner-hit
  branches of `outwardAt`/`grazing` (Tasks 4–5 of the previous plan).

### Owner's tuning at the eye check

<paste the owner's decision, or "none">

### Still open

- Run `tool/e2e/simulator.mjs` against the live URL after deploy.
- 68 of 6,816 grid shots with 2 tips on a Dốc cue at 30 % from across the
  table do not converge; the screen draws the best attempt and says
  "Bi mục tiêu không vào lỗ". Revisit if the owner meets one in practice.
- `aimShot` measured 6–8 ms in Node (dart2js -O2); on a real phone the drag
  frame may exceed 16 ms even if emulated Chrome passes.
```

Fill the frame-time line with the two lines Step 2 printed, and the tuning line with the owner's decision, both verbatim. Write "none" if nothing changed.

- [ ] **Step 6: Commit**

```bash
git add tool/e2e/simulator.mjs docs/superpowers/logs/2026-10-01-cut-angle-simulator-followups.md lib/domain/table_physics/constants.dart
git commit -m "Check the physics simulator in real Chrome, measure drag frame time on an emulated phone, and log what the move closed

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If tuning changed constants, list each one with its old → new value in the commit body.

---

### After the branch is reviewed and merged

This is the same sequence as the last feature (spec §8.5). Do not deploy from the branch.

1. From a clean `main`, run `FLUTTER=… DART=… bash deploy/publish.sh`.
2. Call the easypanel MCP `deployAppService` {projectName: test-va, serviceName: poolcoachai} through `execute_destructive`.
3. Confirm that `inspectAppService` → `commit.hash` equals the new `deploy-easypanel` head.
4. Run `node tool/e2e/simulator.mjs` against the live URL. It must print labels, pass the frame gate and show no console errors.
5. Re-run `node tool/e2e/accounts.mjs`. All 6 steps must pass.
