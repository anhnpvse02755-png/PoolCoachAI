# Kế hoạch dọn bàn (Run-out Planner) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build *Kế hoạch dọn bàn*. The player lays out a 9-, 10- or 8-ball table. A deterministic planner on the physics core works out how to clear it step by step: ball, pocket, stroke, power, and where the cue ball stops. The player then walks the plan one shot at a time, and can re-place the cue ball where it really stopped to recompute.

**Architecture:** `lib/domain/planner/` is plain Dart. It holds:
- the table setup and the rule for which balls may be hit;
- geometric pruning (`CandidateFinder`, built on `bestPocket`);
- options simulated with `aimShot` and scored in four tiers;
- miss advice and the `PlanStep` record;
- a sliced `PlannerJob`. Like `ScratchAdviceJob`, it re-runs the current step's pure computation over a memo cache and does exactly one new simulation per unit of work, so slicing can never change the result.

Two Flutter views share one route. The setup view edits a pure `SetupDraft`. The steps view pumps the job between frames and draws the trace's own point lists with the simulator's table drawing.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flutter_test`, `package:test` tags via `dart_test.yaml`; Node 26 + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** `docs/superpowers/specs/2026-10-07-poolcoachai-run-out-planner-design.md` (binding, approved 2026-10-07). `PRD_RunOutPlanner.md` is the PRD the spec amends; Task 13 writes the spec §9 amendments into it.

## Deviations from spec and gaps the plan fills

The spec was checked against the code at `c43c74a`. Fixture outcomes quoted below were measured on the Dart VM with a throwaway probe. The probe ran `aimShot` and replicated this plan's scoring: the same rejection rules, ±15 % jitter clamped at 100 %, and distance from the geometric ghost. The owner should see this list before execution and again at the Chrome eye check (Task 14).

1. **`maxCutAngle` is not redefined.**
   - Spec §3 lists it as a planner constant.
   - `lib/domain/table_geometry/shot_geometry.dart` already exports `const maxCutAngle = 85.0`, and `evaluateShot` enforces it.
   - A second constant with the same name would clash on import and create two sources of truth. `planner_constants.dart` says so in a comment.
2. **Jitter and tolerance powers are clamped at 100 %.**
   - Spec §5 says "lực −15 % và +15 %" and §5.4 says "7 mức lực đều nhau". For 90 % that would mean 105 %.
   - `strikeCue` would accept 105 % (840 cm/s), but no cue strikes harder than 100 %.
   - The plan uses `jitteredPower(p, d) = min(p + d, maxPower)` with `maxPower = 100.0`. At 90 % the seven tolerance samples are 75, 80, 85, 90, 95, 100, 100.
3. **`riskPower = 85.0` is a named constant.** It comes from PRD §6.5 ("lực ≥ 85%"); the spec's constant table does not list it.
4. **Look-ahead edge cases (the spec is silent on both).**
   - `diff2` is absent when no legal ball remains after the next one.
   - `diff2 = blockedAngle` when the assumed Đánh đứng bi 55 % shot scratches, misses the pocket, passes an obstacle or times out. It is also `blockedAngle` when, from where that shot stops, no pocket is open for the ball after next. This is the same rule spec §5 gives for jitter levels.
5. **Distance is measured from the geometric ghost** (`ShotGeometry.ghost`), as in PRD §5.3's `dist = ghost → E`, not from the compensated contact point.
6. **One function picks both "bi được đánh" and "bi kế tiếp".**
   - `CandidateFinder.easiest(from, balls)` returns the easiest legal ball–pocket pair from a point.
   - It is the step's candidate (spec §4.2) and also the next ball when scoring position (spec §5.1).
   - In 8-ball, each jitter level therefore scores against the easiest legal ball from *its own* stop point.
   - In 9/10-ball the only legal ball is the lowest number, so nothing changes.
7. **Dư dày / dư mỏng direction.**
   - PRD §5.5 rotates the object direction by "−errDeg for thick, +errDeg for thin". That is only right for cuts to one side.
   - The plan defines thick as the object-ball direction rotated toward the cue's aim direction (a fuller hit cuts less), and thin as rotated away. A dead-straight shot treats `+` as thick.
   - Miss positions are clamped to the ball-centre bounds. Equal hardness picks thick.
8. **`PlanStep.ballNum` on a safety step:**
   - 9/10-ball: the forced ball.
   - 8-ball with no makeable pair: `null` (PRD §4).
   - Tier 4 (spec §5.5): the candidate ball.
9. **What *Xong bàn* does.** The spec only names the button. The plan pops back to *Luyện tập* (`Navigator.maybePop`).
10. **Setup rules the spec leaves open.**
    - Switching game type keeps the list of placed balls. Numbers and roles are derived from tap order.
    - Balls beyond a mode's limit are hidden, not deleted, so switching back restores them.
    - A ball placed while in 9/10-ball mode counts as *Bi của tôi* in 8-ball.
    - *Xoá bi cuối* removes the last visible ball, then the cue ball.
    - In *Đặt lại bi cái* mode, a drag anywhere on the table moves the cue ball to the finger, separated from the remaining balls.
11. **Display details.**
    - `jitterEnds` is computed for every normal step, including the last ball.
    - `tolerance` and `missAdvice` are `null` on the last ball, because there is no next ball to grade against.
    - The zone grid in 8-ball uses the same `CandidateFinder.easiest` as scoring.
12. **Planner simulations skip the uncompensated trace** (`withUncompensated: false`). The steps view never draws the red line, and skipping it halves the simulation cost.
13. **One route, two views.** `/training/planner` builds `PlannerScreen`, which shows `PlannerSetupView` or `PlannerStepsView`, and keeps the `SetupDraft` across *Sửa bàn*.
14. **The legend shows degree thresholds** ("góc cắt bi sau ≤ 35°").
    - These are informational, not aim instructions.
    - Memory `poolcoachai-executable-advice` asks to check with the owner before showing more degree numbers, so Task 14 asks.
15. **The frame gate is at risk, and the plan says so up front.**
    - The smallest unit of sliced work is one `aimShot`. On the VM, one `aimShot` measured a median of 3 ms, a p95 of 6 ms and a maximum of 47–71 ms.
    - With `sliceBudget` = 8 ms, slices measured a median of 6.4 ms but a p95 of 17.6 ms, and dart2js runs about 2× slower.
    - So the Chrome frame gate (p95 ≤ 20 ms while computing) may fail, even though step 1 is fast (90–100 ms on the VM).
    - The plan does not optimise this on its own. Task 14 measures it and, if it fails, stops for the owner's choice. Spec decision 4 already names the escape: move `PlannerJob` into a Web Worker without changing the core.

**How the code in this plan was checked.** Before committing the plan:
- The planner core (Tasks 3–6) and every planner test file (Tasks 3–12) were copied into a throwaway state of `c43c74a` and run there.
- All domain and widget tests passed and the analyzer was clean. Two test fixes found that way are already folded in.
- The perf test passed.
- The plan's own claims checked out:
  - the plan on `orderTable` (9-ball) is 1 → 2 → 3 → 4;
  - `typicalNineBallTable` completes in nine normal steps;
  - sliced runs equal one-shot runs;
  - the áp phê tier picks *Phải 1 đầu cơ* on `railTable` when straight options are forced out.
- The throwaway files were removed; this commit contains only the plan.

## Global Constraints

- **Toolchain.** Flutter is not on PATH. In Git Bash, every command below uses `FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat` and `DART=/c/Users/anhnpv/flutter/bin/dart.bat` (memory: poolcoachai-toolchain-state). On the second machine, discover the path the same way; never use `D:\flutter`. Chrome is the only runnable target. There is no `gh`.
- **Branch.** Work happens in the worktree `.claude/worktrees/run-out-planner` on branch `feat/run-out-planner` (Task 0). Do not push. Merging and deploying are a separate owner decision.
- **Table.** Units are cm. The 9-foot table is 254 × 127, origin top-left, `y` down. Ball-centre bounds are `[R, 254−R] × [R, 127−R]`, with `R = 5.715/2`.
- **Planner constants** live in `lib/domain/planner/planner_constants.dart`, with spec §3's names and values:
  - `strokeCandidates` = đứng, cu lê, trô (`[Stroke.stun, Stroke.follow, Stroke.draw]`).
  - `powerCandidates = powerPresets` (30 · 45 · 60 · 75 · 90 %).
  - `powerJitter = 15.0`, `blockedAngle = 95.0`, `lookaheadPower = 55.0`.
  - `zoneGood = 35.0`, `zoneFair = 55.0`, `zoneCell = 5.0`.
  - `bankPenalty` 0 · 2 · 7, as `bankPenaltyOneRail = 2.0` and `bankPenaltyManyRails = 7.0`.
  - `techPenalty` đứng 0 · cu lê 3 · trô 10, as `techPenaltyStun`, `techPenaltyFollow`, `techPenaltyDraw`.
  - `sidePenalty` ½ đầu cơ 15 · 1 đầu cơ 20, as `sidePenaltyHalfTip`, `sidePenaltyOneTip`.
  - `powerPenaltyPerPercent = 0.04`, `distanceWeight = 0.01`, `fallbackPower = 30.0`.
  - `missAngleDeg = 5.0`, `missTravel = 110.0`, `toleranceSamples = 7`.
  - `sliceBudget = Duration(milliseconds: 8)`.
  - Added by this plan: `maxPower = 100.0`, `riskPower = 85.0`, `sideTipsCandidates = [0.5, 1]`.
  - `maxCutAngle` (85°) stays in `shot_geometry.dart`.
- **Scoring.** Score = vị trí + dội băng + kỹ thuật + lực + khoảng cách; lower is better. Ties keep the option tried first: stroke in `strokeCandidates` order, then (in the áp phê tier) side left → right and tips ½ → 1, then power ascending.
- **Áp phê tier.** The side-spin penalty adds to the stroke penalty (trô + 1 đầu cơ = 10 + 20). The tier tries 3 strokes × {trái, phải} × {½, 1 đầu cơ} × 5 powers = 60 options, and only when tier 1 has none.
- **Simulation call.** Every simulation is `aimShot(..., elevation: CueElevation.normal, compensate: true, withUncompensated: false)`. `SimulationTimeout` makes that option unusable and never breaks the plan.
- **Invariant.** `identical(steps[i].trace!.cueEnd, steps[i + 1].cbFrom)` holds inside one plan. Re-placing the cue ball starts a new plan.
- **Determinism.** No randomness and no wall clock in `lib/domain`. `PlannerJob` reads a `Stopwatch` only to decide *when* to yield, never *what* to compute. Sliced and one-shot runs must give the same plan.
- **Layering.** `lib/domain/planner/` never imports `package:flutter`, and `lib/domain/table_geometry/` never imports `lib/domain/table_physics/` (architecture tests, Tasks 1 and 3).
- **Terms on screen, exactly:** **Kế hoạch dọn bàn**, **Trơn** · **Sọc**, **Đánh đứng bi · Đánh trô bi · Đánh cu lê**, **Áp phê** trái/phải, **Lệch N đầu cơ** (never "đầu gậy"), **Bi ảo** (never "bi ma"), **Dội băng**, **Chết cái**, **Vùng điều**.
- **Strings.** All visible text lives in `lib/core/strings/vi.dart`. Sentences with numbers are templates filled from planner results (memory: no-fabricated-generated-content). The architecture test fails on Vietnamese literals in `lib/features`.
- **No degree aim instructions** ever reach the screen (memory: poolcoachai-executable-advice). `aimOffsetDeg` is internal. Áp phê advice reuses the simulator's line: đầu cơ, phần con bi, and SAWS BHE/FHE.
- **Disclaimer.** The PRD §6.6 disclaimer (`Vi.simDisclaimer`) is always shown, word for word.
- **Tests and constants.** Tests reference constants by name, never their literal values, so tuning after the eye check does not rewrite tests. Fixture expectations that depend on today's constants say "measured on c43c74a" in a comment.
- **Riverpod pitfalls** (memory: poolcoachai-riverpod-drift-test-patterns):
  - Never `await container.read(x.future)`.
  - Widget tests that need the app use `UncontrolledProviderScope` with `testContainer()` from `test/support/test_data.dart`.
  - Never use `ProviderScope(overrides: [...])` with an explicit `List<Override>`.
- **Comments** follow the surrounding code: Vietnamese, explaining *why*.
- **Commit messages** are plain English sentences and end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Line endings.** The repo checks out with `core.autocrlf=true`. Do not convert line endings by hand.

## Review Focus

1. **Leaving the screen, or pressing *Sửa bàn*, while the job is still computing.**
   - Expected: no exception, no `setState` after dispose, and no step appearing on the setup view later.
   - Owner: Task 11 (`rời màn giữa lúc đang tính: không lỗi, việc tính bị hủy`) and Task 6 (`hủy giữa chừng thì không báo thêm bước nào`).
2. **Re-placing the cue ball onto a ball, or where no legal ball has an open pocket.**
   - Expected: the drag stops at touching distance, and the recompute shows a *phòng thủ* step at once — never a hang or an empty screen.
   - Owner: Task 6 (`đặt lại bi cái vào chỗ không đánh được: bước đầu là phòng thủ`) and Task 11 (`kéo bi cái đè lên bi khác thì bị đẩy ra`).
3. **8-ball tables with only the 8, or with only opponent balls.**
   - Expected: a one-step plan on the 8 in the first case, and *Lập kế hoạch* disabled in the second.
   - Owner: Task 6 (`8 bi chỉ còn bi 8: một bước, không có phần vị trí`) and Task 10 (`chỉ có bi đối thủ thì không lập kế hoạch được`).
4. **Power 90 % plus jitter.**
   - Expected: no 105 % shot behind the numbers, and a tolerance line that still counts out of 7.
   - Owner: Task 4 (`lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức`).
5. **Taps on an existing ball, on the rail, or in a pocket.**
   - Expected: the new ball lands touching the others, never overlapping and never outside the table.
   - Owner: Task 10 (`chạm đè lên bi có sẵn thì bi mới nằm sát bên`, `chạm vào lỗ thì bi nằm trong biên`).

---

## File map

| File | Responsibility |
|---|---|
| `lib/domain/table_physics/scratch.dart` | moved from `table_geometry/` unchanged (spec §8.1) |
| `lib/domain/table_physics/aim.dart` | gains `AimShotFn` (moved from the simulator screen) |
| `lib/domain/table_geometry/separate.dart` | `separateBalls`, `separateFromAll` (moved out of `SimulatorScreen.separate`) |
| `lib/domain/planner/planner_constants.dart` | spec §3 constants |
| `lib/domain/planner/table_setup.dart` | `GameType`, `BallGroup`, `BallRole`, `PlacedBall`, `TableSetup`, `plannedStepCount` |
| `lib/domain/planner/legal_targets.dart` | `legalTargetsAmong`, `obstaclesFor`, `ballMask` |
| `lib/domain/planner/candidates.dart` | `Candidate`, `CandidateFinder` (pruning + "easiest next", cached) |
| `lib/domain/planner/shot_options.dart` | `ShotKey`, `ShotLookup`, `simulateKey`, `directLookup`, tier key lists, `Rejection`, `rejectionOf`, `polylineClear` |
| `lib/domain/planner/scoring.dart` | penalties, `bestAngleFrom`, `OptionScore`, `ScoredOption`, `ScoringContext`, `scoreOption`, `scoreTier`, `bestOf`, `toleranceOf`, `ZoneCell`, `zoneGrid` |
| `lib/domain/planner/miss_advice.dart` | `MissSide`, `MissAdvice`, `missErrDeg`, `missDirection`, `missSafetyAdvice` |
| `lib/domain/planner/plan_step.dart` | `PlanStepKind`, `JitterEnds`, `PlanStep` |
| `lib/domain/planner/planner_job.dart` | `planStep`, `PlannerEvent`, `StepReady`, `PlanDone`, `PlannerJob`, `planToEnd` |
| `lib/core/strings/vi.dart` | `plan*` strings and templates |
| `lib/core/router/routes.dart`, `app_router.dart` | `Routes.planner` and its route |
| `lib/features/training/presentation/training_screen.dart` | the card under *Mô phỏng góc cắt* |
| `lib/features/training/presentation/simulator/info_lines.dart` | `_squirtLine` becomes public `squirtLine` |
| `lib/features/training/presentation/simulator/table_drawing.dart` | `TableLayout`, `drawTableBed`, `drawPolyline`, `drawDashedPolyline`, `drawDashedCircle` (extracted from `TablePainter`) |
| `lib/features/training/presentation/simulator/table_painter.dart` | uses `table_drawing.dart`, re-exports `TableLayout` |
| `lib/features/training/presentation/simulator/simulator_screen.dart` | `_aimFor` key fix; `separate` delegates |
| `lib/features/training/presentation/planner/setup_editing.dart` | `DraftBall`, `SetupDraft`, `ballLimit` (pure Dart) |
| `lib/features/training/presentation/planner/ball_colors.dart` | real pool-ball colours |
| `lib/features/training/presentation/planner/step_lines.dart` | `planStepLines` (pure) |
| `lib/features/training/presentation/planner/planner_painter.dart` | `PlannerScene`, `PlannerPainter`, `drawPoolBall`, `DashedBorderPainter` |
| `lib/features/training/presentation/planner/planner_layout.dart` | `PlannerTableLayout`: table on top, panel scrolls |
| `lib/features/training/presentation/planner/planner_steps_view.dart` | steps view: job pumping, navigation, reset flow |
| `lib/features/training/presentation/planner/planner_setup_view.dart` | setup view: chips, taps, drags, buttons |
| `lib/features/training/presentation/planner/planner_screen.dart` | `PlannerScreen`, which switches between the two views |
| `dart_test.yaml` | adds the `probe` tag, skipped by default |
| `test/support/planner_tables.dart` | the fixture tables, aim wrappers, `fingerprint`, `contextFor` |
| `test/domain/planner/*_test.dart` | planner tests, the PRD §7 tests, the probe, the perf test |
| `test/features/training/planner_*_test.dart` | step lines, setup editing, both views |
| `tool/e2e/planner.mjs` | Chrome scenarios, first-step time and frame gates |
| `PRD_RunOutPlanner.md` | spec §9 amendments |
| `docs/superpowers/logs/2026-10-07-run-out-planner.md` | what the eye check decided |

---

### Task 0: Worktree and baseline

- [ ] **Step 1: Create the worktree** with superpowers:using-git-worktrees:
  - path `.claude/worktrees/run-out-planner` (the repo's convention, git-ignored);
  - branch `feat/run-out-planner`;
  - from `main` at the commit that adds this plan.
- [ ] **Step 2: Generate code and run the baseline**

```bash
FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat
DART=/c/Users/anhnpv/flutter/bin/dart.bat
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" test
"$FLUTTER" analyze
```

Expected:
- Every test passes. The spec records 546 tests plus the one `perf` test, which is skipped by default.
- The analyzer prints `No issues found!`.

Write the test count down; later tasks quote growth against it. If anything is red, stop and report: the baseline must be green before any change.

---

### Task 1: Move `scratch.dart` into the physics core (spec §8.1)

**Files:**
- Move: `lib/domain/table_geometry/scratch.dart` → `lib/domain/table_physics/scratch.dart`
- Move: `test/domain/table_geometry/scratch_test.dart` → `test/domain/table_physics/scratch_test.dart`
- Move: `test/domain/table_geometry/advice_test.dart` → `test/domain/table_physics/advice_test.dart`
- Modify the import in each of these files:
  - `lib/core/strings/vi.dart`
  - `lib/features/training/presentation/simulator/info_lines.dart`
  - `lib/features/training/presentation/simulator/simulator_panel.dart`
  - `lib/features/training/presentation/simulator/simulator_screen.dart`
  - `test/core/strings/vi_simulator_test.dart`
  - `test/features/training/simulator_info_lines_test.dart`
  - `test/features/training/simulator_screen_test.dart`
  - the two moved tests
- Modify: `test/architecture_test.dart` (append one test at the end of `main`)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `package:poolcoachai/domain/table_physics/scratch.dart`, with the same public API as before: `ScratchRisk`, `cuePocketAt`, `marginWith`, `scratchMargin`, `overhitBand`, `SpinOutcome`, `Advice` and its subclasses, `chooseAdvice`, `outcomesWith`, `scratchAdvice`, `ScratchAdviceJob`, `CuePocketLookup`.
  - No `table_geometry` file imports `table_physics`.

- [ ] **Step 1: Write the failing architecture test**

Append inside `main()` of `test/architecture_test.dart`, after `'lõi vật lý bàn không phụ thuộc Flutter'`:

```dart
  test('lõi hình học bàn không import lõi vật lý', () {
    // table_physics đã import table_geometry (Vec2, TableSpec, Stroke…).
    // Chiều ngược lại là vòng phụ thuộc: sửa lõi vật lý thì phải dựng lại cả
    // lõi hình học, và Planner không còn biết tầng nào là nền.
    final offenders = [
      for (final file in dartFilesIn('lib/domain/table_geometry'))
        if (codeOnly(file.readAsStringSync())
            .contains('package:poolcoachai/domain/table_physics/'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'table_geometry là nền của table_physics; lõi vật lý được '
          'import hình học, không có chiều ngược lại (spec 2026-10-07 mục 8)',
    );
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$FLUTTER" test test/architecture_test.dart`
Expected: FAIL, with `lib/domain/table_geometry/scratch.dart` in the offenders list. `stroke.dart` mentions `table_physics` only in a doc comment, which `codeOnly` drops.

- [ ] **Step 3: Move the files and rewrite the imports**

```bash
git mv lib/domain/table_geometry/scratch.dart lib/domain/table_physics/scratch.dart
git mv test/domain/table_geometry/scratch_test.dart test/domain/table_physics/scratch_test.dart
git mv test/domain/table_geometry/advice_test.dart test/domain/table_physics/advice_test.dart
grep -rl "domain/table_geometry/scratch.dart" lib test \
  | xargs sed -i 's#domain/table_geometry/scratch.dart#domain/table_physics/scratch.dart#'
grep -rn "table_geometry/scratch" lib test tool || echo "không còn chỗ nào"
```

Expected: the last command prints `không còn chỗ nào`.
- The moved tests import `../../support/table_layouts.dart`. `test/domain/table_physics/` sits at the same depth as `test/domain/table_geometry/`, so that relative import still resolves.
- `scratch.dart`'s own imports are package imports and do not change.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `"$FLUTTER" test && "$FLUTTER" analyze`
Expected: all tests pass (baseline + 1), and `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "Move scratch advice into the physics core so table geometry no longer depends on it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The simulator keeps no stale shot under a new key (spec §8.2), and `AimShotFn` moves to the core

**Files:**
- Modify: `lib/features/training/presentation/simulator/simulator_screen.dart`:
  - fix `_aimFor` (~line 281);
  - delete the `AimShotFn` typedef at lines 21–32.
- Modify: `lib/domain/table_physics/aim.dart` (add `AimShotFn` before `aimShot`)
- Test: `test/features/training/simulator_screen_test.dart` (add one test after `'dựng lại mà đầu vào không đổi thì không dò lại cú đánh'`)

**Interfaces:**
- Consumes: `aimShot`, `AimedShot` (`aim.dart`).
- Produces: `typedef AimShotFn` in `package:poolcoachai/domain/table_physics/aim.dart`, with exactly `aimShot`'s signature.
  - `SimulatorScreen.aim` keeps that type.
  - The planner (Task 4) uses the same typedef.

- [ ] **Step 1: Write the failing test**

Add this test to `test/features/training/simulator_screen_test.dart`, after the `'dựng lại mà đầu vào không đổi…'` test. It reuses the file's `openWithAim`, `tapText` and `sceneOf` helpers:

```dart
  testWidgets('lõi ném lỗi thì không giữ cú cũ dưới khoá mới', (tester) async {
    var calls = 0;
    var failNext = false;
    AimedShot flaky({
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
    }) {
      calls++;
      if (failNext) {
        failNext = false;
        throw StateError('lõi hỏng đúng một lần');
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
          withUncompensated: withUncompensated);
    }

    await openWithAim(tester, flaky);
    expect(calls, 1);
    final stun = sceneOf(tester).aimed;

    // Đổi sang trô: lần dò đầu ném lỗi. Gợi ý chống chết cái tính xong thì
    // setState, dựng lại bàn với cùng đầu vào: phải dò lại, không được trả
    // cú Đánh đứng bi cũ dưới khoá của cú trô.
    failNext = true;
    await tapText(tester, Vi.simStroke(Stroke.draw));
    expect(tester.takeException(), isA<StateError>());
    expect(calls, 3);

    // Dựng lại lần nữa mà không đổi gì: giờ mới được dùng lại kết quả.
    tester.view.physicalSize = const Size(1100, 1800);
    await tester.pumpAndSettle();
    expect(calls, 3);
    final draw = sceneOf(tester).aimed;
    expect(draw, isNotNull);
    expect(identical(draw, stun), isFalse);
    expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$FLUTTER" test test/features/training/simulator_screen_test.dart --plain-name "lõi ném lỗi thì không giữ cú cũ dưới khoá mới"`
Expected: FAIL at `expect(calls, 3)` with `Actual: <2>`. The key was set before `aimShot` threw, so the rebuild returned the old stun shot.

- [ ] **Step 3: Fix `_aimFor` and move the typedef**

In `simulator_screen.dart`, replace `_aimFor` with:

```dart
  /// Cú đã dò cho [g]; null khi lõi quá maxSimTime.
  AimedShot? _aimFor(ShotGeometry g, bool showRed) {
    final key =
        (g.cue, g.object, g.pocket, _stroke, _spin, _power, _elevation, showRed);
    if (key == _aimKey) return _aimed;
    AimedShot? aimed;
    try {
      aimed = widget.aim(
        cue: g.cue,
        object: g.object,
        pocket: g.pocket,
        stroke: _stroke,
        spin: _spin,
        power: _power,
        elevation: _elevation,
        table: _table,
        withUncompensated: showRed,
      );
    } on SimulationTimeout {
      // Lõi chạy quá maxSimTime (spec mục 4.5): không có đường đi để vẽ.
      // Ném tiếp trong build thì cả màn thành ô lỗi; vẽ hình học thôi. Quá
      // giờ là kết quả tất định của cú này nên nhớ được như mọi kết quả.
      aimed = null;
    }
    // Chỉ gán khoá khi đã có kết quả (spec 2026-10-07 mục 8): lỗi khác ném
    // ra giữa chừng mà khoá đã đổi thì lần dựng sau trả nhầm cú cũ dưới
    // khoá mới.
    _aimKey = key;
    return _aimed = aimed;
  }
```

Then move the typedef:
1. Cut the `AimShotFn` typedef and its doc comment from `simulator_screen.dart`. That is everything from `/// Cùng chữ ký với \`aimShot\`, để test thay lõi (vd lõi quá giờ).` through the closing `});`.
2. Paste it into `lib/domain/table_physics/aim.dart`, directly above the doc comment of `aimShot`, with the comment changed:

```dart
/// Cùng chữ ký với [aimShot], để màn mô phỏng, Planner và test thay lõi
/// (vd lõi quá giờ, hay đếm số lần gọi).
typedef AimShotFn = AimedShot Function({
  required Vec2 cue,
  required Vec2 object,
  required Pocket pocket,
  required Stroke stroke,
  SideSpin spin,
  required double power,
  CueElevation elevation,
  TableSpec table,
  bool compensate,
  bool withUncompensated,
});
```

`simulator_screen.dart` and `simulator_screen_test.dart` both already import `aim.dart`, so `AimShotFn` still resolves in both.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/features/training/simulator_screen_test.dart && "$FLUTTER" analyze`
Expected: all pass, including the existing timeout and no-re-aim tests, and `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/training/presentation/simulator/simulator_screen.dart lib/domain/table_physics/aim.dart test/features/training/simulator_screen_test.dart
git commit -m "Set the simulator's aim key only after aimShot returns, and move AimShotFn into the physics core

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Planner constants, table setup, legal targets and the candidate finder

**Files:**
- Create: `lib/domain/planner/planner_constants.dart`, `lib/domain/planner/table_setup.dart`, `lib/domain/planner/legal_targets.dart`, `lib/domain/planner/candidates.dart`
- Create: `test/support/planner_tables.dart` (the tables only; Task 4 appends helpers)
- Test: `test/domain/planner/candidates_test.dart`
- Modify: `test/architecture_test.dart` (append one test)

**Interfaces:**
- Consumes: `bestPocket`, `compareShots` (`pocket_choice.dart`), `ShotGeometry` (`shot_geometry.dart`), `Pocket`, `TableSpec`, `Vec2`, `Stroke`, `powerPresets`.
- Produces:
  - every constant listed in Global Constraints, as top-level `const` in `planner_constants.dart`;
  - `enum GameType { nineBall, tenBall, eightBall }`, `enum BallGroup { solids, stripes }`, `enum BallRole { mine, opponent, eight }`;
  - `class PlacedBall { const PlacedBall({required int number, required Vec2 pos, BallRole role = BallRole.mine}); == hashCode }`;
  - `class TableSetup { const TableSetup({required GameType game, required Vec2 cue, required List<PlacedBall> balls, BallGroup group = BallGroup.solids, TableSpec table = TableSpec.nineFoot}); TableSetup withCue(Vec2 cue); TableSetup without(Iterable<int> numbers); }`;
  - `int plannedStepCount(TableSetup setup)`;
  - `List<PlacedBall> legalTargetsAmong(GameType game, Iterable<PlacedBall> balls)` (sorted by number), `List<Vec2> obstaclesFor(PlacedBall target, Iterable<PlacedBall> balls)`, `int ballMask(Iterable<PlacedBall> balls)`;
  - `class Candidate { const Candidate(PlacedBall ball, ShotGeometry geometry); double get angle; }`;
  - `class CandidateFinder { CandidateFinder({required GameType game, TableSpec table = TableSpec.nineFoot}); final GameType game; final TableSpec table; int get cached; Candidate? easiest(Vec2 from, List<PlacedBall> balls); }`;
  - fixtures in `test/support/planner_tables.dart`: `ringAround`, `orderTable`, `railTable`, `cornerFollowTable`, `blockedEverywhereTable`, `fallbackTable`, `typicalNineBallTable`, `eightLastTable`, `opponentBlocksTable`, `penultimateTable`, `onlyEightTable`, `eightWithOpponentsTable`.

- [ ] **Step 1: Write the fixture tables**

`test/support/planner_tables.dart`:

```dart
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
```

- [ ] **Step 2: Write the failing tests**

`test/domain/planner/candidates_test.dart`:

```dart
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
```

Append to `test/architecture_test.dart`, inside `main()`, after the test from Task 1:

```dart
  test('lõi Planner không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/planner');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'Planner phải chạy và đo được trên Dart VM thuần, và sau này '
          'chuyển sang Web Worker hay điện thoại mà không đổi lõi (spec mục 2)',
    );
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/candidates_test.dart test/architecture_test.dart`
Expected: FAIL to compile, `Error when reading 'lib/domain/planner/candidates.dart'` (and the architecture test fails on a missing directory).

- [ ] **Step 4: Write the implementation**

`lib/domain/planner/planner_constants.dart`:

```dart
import 'package:poolcoachai/domain/table_geometry/stroke.dart';

// Hằng số của Kế hoạch dọn bàn — spec 2026-10-07 mục 3, tên bám PRD §4.
// Test chỉ dùng tên, không dùng giá trị: chỉnh điểm phạt sau buổi chủ sản
// phẩm xem trên Chrome không phải viết lại test.
//
// Góc cắt tối đa dùng chung `maxCutAngle` (85°) của shot_geometry.dart:
// khai báo lại ở đây là hai nguồn sự thật cho cùng một luật PRD §5.1.

/// Thứ tự thử cố định: bằng điểm thì giữ phương án thử trước.
const strokeCandidates = <Stroke>[Stroke.stun, Stroke.follow, Stroke.draw];

/// Năm mức lực — chung với màn Mô phỏng góc cắt.
const powerCandidates = powerPresets;

/// Lệch lực để đo vùng điều chịu sai số, điểm phần trăm.
const powerJitter = 15.0;

/// Cơ không đánh mạnh hơn 100 %: lực + [powerJitter] kẹp về đây.
const maxPower = 100.0;

/// Góc tính cho mức lực bị chắn, chết cái hoặc trượt lỗ, độ.
const blockedAngle = 95.0;

/// Cú kế tiếp giả định khi nhìn trước bi thứ hai: Đánh đứng bi ở lực này.
const lookaheadPower = 55.0;

/// Vùng điều: góc cắt dễ nhất cho bi kế tiếp, độ.
const zoneGood = 35.0;
const zoneFair = 55.0;

/// Cạnh ô lưới vùng điều, cm.
const zoneCell = 5.0;

/// Phạt dội băng: chạm 1 băng, từ 2 băng. Không chạm băng là 0. Tối đa
/// vẫn nhỏ hơn phạt trô: dội băng không bị coi là khó (PRD §5.3).
const bankPenaltyOneRail = 2.0;
const bankPenaltyManyRails = 7.0;

/// Phạt kỹ thuật theo kiểu đánh.
const techPenaltyStun = 0.0;
const techPenaltyFollow = 3.0;
const techPenaltyDraw = 10.0;

/// Phạt áp phê, cộng dồn với phạt kiểu đánh (spec quyết định 5).
const sidePenaltyHalfTip = 15.0;
const sidePenaltyOneTip = 20.0;

/// Hai mức áp phê của đường lui, đầu cơ.
const sideTipsCandidates = <double>[0.5, 1];

/// Lực × hệ số này: lực càng lớn càng dễ sai số và chết cái.
const powerPenaltyPerPercent = 0.04;

/// Quãng bi ảo → điểm dừng (cm) × hệ số này: chỉ để phân định khi hoà.
const distanceWeight = 0.01;

/// Cú dự phòng: Đánh đứng bi ở lực này.
const fallbackPower = 30.0;

/// Gợi ý dư dày / mỏng (PRD §5.5): sai số ngắm giả định, độ; quãng bi mục
/// tiêu trôi nếu trượt, cm.
const missAngleDeg = 5.0;
const missTravel = 110.0;

/// Số mức lực đều nhau trong ±[powerJitter] để đếm độ chịu sai số.
const toleranceSamples = 7;

/// Từ lực này trở lên thì cảnh báo lực cao (PRD §6.5).
const riskPower = 85.0;

/// Mỗi lát tính giữa hai khung hình (spec quyết định 4).
const sliceBudget = Duration(milliseconds: 8);
```

`lib/domain/planner/table_setup.dart`:

```dart
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
```

`lib/domain/planner/legal_targets.dart`:

```dart
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Bi được đánh lúc này, theo số tăng dần (spec mục 4.1).
///
/// 9 / 10 bi: chỉ bi số nhỏ nhất. 8 bi: mọi bi của tôi; hết thì bi 8; bi
/// đối thủ không bao giờ.
List<PlacedBall> legalTargetsAmong(GameType game, Iterable<PlacedBall> balls) {
  final sorted = balls.toList()..sort((a, b) => a.number.compareTo(b.number));
  switch (game) {
    case GameType.nineBall:
    case GameType.tenBall:
      return sorted.isEmpty ? const [] : [sorted.first];
    case GameType.eightBall:
      final mine = [for (final b in sorted) if (b.role == BallRole.mine) b];
      if (mine.isNotEmpty) return mine;
      return [for (final b in sorted) if (b.role == BallRole.eight) b];
  }
}

/// Bi chắn khi đánh [target]: mọi bi khác còn trên bàn.
List<Vec2> obstaclesFor(PlacedBall target, Iterable<PlacedBall> balls) =>
    [for (final b in balls) if (b.number != target.number) b.pos];

/// Tập bi còn trên bàn dưới dạng bit theo số. Trong một kế hoạch, vị trí mỗi
/// số không đổi, nên mặt nạ này đủ làm khoá cho tập bi chắn.
int ballMask(Iterable<PlacedBall> balls) =>
    balls.fold(0, (mask, b) => mask | (1 << b.number));
```

`lib/domain/planner/candidates.dart`:

```dart
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một cặp bi–lỗ đánh được, chưa mô phỏng.
class Candidate {
  const Candidate(this.ball, this.geometry);

  final PlacedBall ball;
  final ShotGeometry geometry;

  double get angle => geometry.angle;
}

/// Cú dễ nhất từ một điểm, chỉ bằng hình học (spec mục 4.2).
///
/// Một hàm cho hai việc: chọn cặp bi–lỗ của bước này, và tìm "bi kế tiếp"
/// khi chấm vị trí (mục 5.1). Nhờ vậy điều Planner chấm ở bước trước đúng là
/// điều nó sẽ chọn ở bước sau. Nhớ kết quả theo (điểm, bi, tập bi chắn) —
/// một [CandidateFinder] chỉ dùng trong một kế hoạch, vì khoá dựa vào việc
/// mỗi số bi ở một chỗ cố định.
class CandidateFinder {
  CandidateFinder({required this.game, this.table = TableSpec.nineFoot});

  final GameType game;
  final TableSpec table;
  final _cache = <(Vec2, int, int), ShotGeometry?>{};

  /// Số cặp (điểm, bi) đã tính.
  int get cached => _cache.length;

  /// Cặp bi–lỗ có góc cắt nhỏ nhất trong các bi được đánh của [balls], từ
  /// [from]; hoà thì giữ bi số nhỏ hơn. null khi không cặp nào đánh được.
  Candidate? easiest(Vec2 from, List<PlacedBall> balls) {
    final mask = ballMask(balls);
    Candidate? best;
    for (final target in legalTargetsAmong(game, balls)) {
      final g = _cache.putIfAbsent(
        (from, target.number, mask),
        () => bestPocket(
          cue: from,
          object: target.pos,
          others: obstaclesFor(target, balls),
          table: table,
        ),
      );
      if (g == null) continue;
      final current = best;
      if (current == null || compareShots(g, current.geometry, table: table) < 0) {
        best = Candidate(target, g);
      }
    }
    return best;
  }
}
```

- [ ] **Step 5: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner/candidates_test.dart test/architecture_test.dart && "$FLUTTER" analyze`
Expected: PASS, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/planner test/support/planner_tables.dart test/domain/planner/candidates_test.dart test/architecture_test.dart
git commit -m "Add the planner's table setup, legal targets and geometric candidate finder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Simulated options, rejection, and four-tier scoring

**Files:**
- Create: `lib/domain/planner/shot_options.dart`, `lib/domain/planner/scoring.dart`
- Modify: `test/support/planner_tables.dart` (append the helpers below)
- Test: `test/domain/planner/scoring_test.dart`

**Interfaces:**
- Consumes: `aimShot`, `AimedShot`, `AimShotFn` (`aim.dart`); `SimulationTimeout` (`simulate_shot.dart`); `isPathClear` (`path_clear.dart`); `bestPocket`; `CandidateFinder`, `Candidate`, `legalTargetsAmong`, `PlacedBall`, constants (Task 3).
- Produces:
  - `typedef ShotKey = ({Vec2 cue, Vec2 object, Pocket pocket, Stroke stroke, SideSpin spin, double power});`
  - `typedef ShotLookup = AimedShot? Function(ShotKey key);` (null = the core timed out)
  - `ShotKey shotKey(ShotGeometry g, Stroke stroke, double power, {SideSpin spin = const SideSpin.none()})`, `ShotKey withPower(ShotKey k, double power)`, `double jitteredPower(double power, double delta)`
  - `List<ShotKey> tierOneKeys(ShotGeometry g)` (15), `List<ShotKey> tierTwoKeys(ShotGeometry g)` (60)
  - `AimedShot? simulateKey(ShotKey k, {AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot})`, `ShotLookup directLookup({AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot})`
  - `enum Rejection { scratch, objectMissed, blocked }`, `Rejection? rejectionOf(AimedShot aimed, Pocket pocket, List<Vec2> obstacles, {TableSpec table = TableSpec.nineFoot})`, `bool polylineClear(List<Vec2> points, List<Vec2> obstacles, {TableSpec table = TableSpec.nineFoot})`
  - `double bankPenaltyFor(int railCount)`, `double techPenaltyFor(Stroke stroke, SideSpin spin)`, `double powerPenaltyFor(double power)`
  - `double? bestAngleFrom(Vec2 from, Vec2 ball, Iterable<Vec2> obstacles, {TableSpec table = TableSpec.nineFoot})`
  - `class OptionScore { position, robustDiff1 (double?), diff2 (double?), bank, tech, power, distance (already × distanceWeight); double get total; }`
  - `class ScoredOption { const ScoredOption(ShotKey key, AimedShot aimed, OptionScore score); }`
  - `class ScoringContext { ScoringContext({required ShotGeometry geometry, required List<PlacedBall> after, required ShotLookup lookup, required CandidateFinder next}); List<Vec2> get obstacles; bool get hasNext; TableSpec get table; double angleAt(AimedShot? aimed); }`
  - `OptionScore? scoreOption(ScoringContext c, ShotKey key, AimedShot aimed)` (null = no pocket for the next ball from the stop point → option rejected)
  - `List<ScoredOption> scoreTier(ScoringContext c, Iterable<ShotKey> keys)` (accepted options in trial order), `ScoredOption? bestOf(List<ScoredOption> options)` (strictly lowest; ties keep the first)
  - `typedef ToleranceCounts = ({int good, int fair, int bad});`, `ToleranceCounts toleranceOf(ScoringContext c, ShotKey key)`
  - `enum ZoneLevel { good, fair }`, `class ZoneCell { const ZoneCell(Vec2 center, ZoneLevel level); }`, `List<ZoneCell> zoneGrid({required List<PlacedBall> after, required CandidateFinder next})`
  - test helpers: `ScoringContext contextFor(TableSetup s, {ShotLookup? lookup})`, `AimShotFn scratchingAim(bool Function(Vec2 object, Stroke stroke, SideSpin spin, double power) when)`, `AimShotFn timeoutAim(bool Function(Vec2 object, Stroke stroke, SideSpin spin, double power) when)`, `AimShotFn recordingAim(void Function(Stroke stroke, SideSpin spin, double power) record)`

- [ ] **Step 1: Append the test helpers**

Append to `test/support/planner_tables.dart`, and add these imports at its top:

```dart
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
```

```dart
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
          withUncompensated: withUncompensated);
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
          withUncompensated: withUncompensated);
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
          withUncompensated: withUncompensated);
    };
```

- [ ] **Step 2: Write the failing tests**

`test/domain/planner/scoring_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

void main() {
  group('điểm phạt (spec mục 3, 5)', () {
    test('dội băng 0 · 2 · 7', () {
      expect(bankPenaltyFor(0), 0);
      expect(bankPenaltyFor(1), bankPenaltyOneRail);
      expect(bankPenaltyFor(2), bankPenaltyManyRails);
      expect(bankPenaltyFor(5), bankPenaltyManyRails);
    });

    test('áp phê cộng dồn với kiểu đánh', () {
      expect(techPenaltyFor(Stroke.stun, const SideSpin.none()), techPenaltyStun);
      expect(techPenaltyFor(Stroke.draw, const SideSpin(SpinSide.left, 1)),
          techPenaltyDraw + sidePenaltyOneTip);
      expect(techPenaltyFor(Stroke.follow, const SideSpin(SpinSide.right, 0.5)),
          techPenaltyFollow + sidePenaltyHalfTip);
    });

    test('dội băng không bị coi là khó: phạt băng tối đa vẫn dưới trô', () {
      expect(bankPenaltyFor(9), lessThan(techPenaltyFor(Stroke.draw, const SideSpin.none())));
      expect(techPenaltyFollow + bankPenaltyOneRail, lessThan(techPenaltyDraw));
    });

    test('lực × hệ số', () {
      expect(powerPenaltyFor(75), 75 * powerPenaltyPerPercent);
    });
  });

  test('bestAngleFrom là góc của bestPocket, null khi mọi lỗ bị chắn', () {
    final s = blockedEverywhereTable();
    final ball1 = s.balls.first.pos;
    final ring = [for (final b in s.balls.skip(1)) b.pos];
    expect(bestAngleFrom(s.cue, ball1, ring), isNull);
    expect(bestAngleFrom(s.cue, ball1, const []),
        bestPocket(cue: s.cue, object: ball1)!.angle);
  });

  test('mười lăm phương án tầng 1 rồi sáu mươi phương án áp phê, đúng thứ tự thử', () {
    final g = contextFor(railTable()).geometry;
    final one = tierOneKeys(g);
    expect(one, hasLength(strokeCandidates.length * powerCandidates.length));
    expect(one.first.stroke, Stroke.stun);
    expect(one[powerCandidates.length].stroke, Stroke.follow);
    expect(one.take(powerCandidates.length).map((k) => k.power), powerCandidates);
    final two = tierTwoKeys(g);
    expect(two, hasLength(60));
    expect(two.first.spin, const SideSpin(SpinSide.left, 0.5));
    expect(two[powerCandidates.length].spin, const SideSpin(SpinSide.left, 1));
    expect(two.every((k) => !k.spin.isNone), isTrue);
  });

  group('loại phương án (spec mục 4.3)', () {
    test('chết cái, bi mục tiêu không vào, đi qua bi chắn; cú sạch thì không loại', () {
      final corner = contextFor(cornerFollowTable());
      final follow = corner.lookup(shotKey(corner.geometry, Stroke.follow, 45))!;
      expect(rejectionOf(follow, corner.geometry.pocket, corner.obstacles), Rejection.scratch);
      // Đo trên c43c74a: Đánh đứng bi 15 % không đưa bi 1 tới lỗ.
      final weak = corner.lookup(shotKey(corner.geometry, Stroke.stun, 15))!;
      expect(rejectionOf(weak, corner.geometry.pocket, corner.obstacles), Rejection.objectMissed);

      final rail = contextFor(railTable());
      final clean = rail.lookup(shotKey(rail.geometry, Stroke.stun, 45))!;
      expect(rejectionOf(clean, rail.geometry.pocket, rail.obstacles), isNull);
      final onPath = clean.trace.cueAfter[clean.trace.cueAfter.length ~/ 2];
      expect(rejectionOf(clean, rail.geometry.pocket, [onPath]), Rejection.blocked);
    });

    test('đường một điểm vẫn được kiểm chắn', () {
      expect(polylineClear(const [Vec2(50, 50)], const [Vec2(52, 50)]), isFalse);
      expect(polylineClear(const [Vec2(50, 50)], const [Vec2(80, 50)]), isTrue);
    });

    test('lõi quá giờ thì lookup trả null, không ném', () {
      final g = contextFor(railTable()).geometry;
      final lookup = directLookup(aim: timeoutAim((_, _, _, _) => true));
      expect(lookup(shotKey(g, Stroke.stun, 45)), isNull);
    });
  });

  group('chấm điểm (spec mục 5)', () {
    test('hai bi: vị trí là vùng điều chịu sai số, không có diff2', () {
      final c = contextFor(railTable());
      final key = shotKey(c.geometry, Stroke.stun, 45);
      final aimed = c.lookup(key)!;
      final s = scoreOption(c, key, aimed)!;
      final diff1 = c.next.easiest(aimed.trace.cueEnd, c.after)!.angle;
      expect(s.robustDiff1, greaterThanOrEqualTo(diff1));
      expect(s.diff2, isNull);
      expect(s.position, s.robustDiff1);
      expect(s.bank, bankPenaltyFor(aimed.trace.cueRailCount));
      expect(s.distance, c.geometry.ghost.distanceTo(aimed.trace.cueEnd) * distanceWeight);
      expect(s.total, s.position + s.bank + s.tech + s.power + s.distance);
    });

    test('ba bi trở lên: vị trí là max(robustDiff1, diff2) — minimax, không cộng', () {
      final c = contextFor(orderTable(GameType.nineBall));
      final options = scoreTier(c, tierOneKeys(c.geometry));
      expect(options, isNotEmpty);
      for (final scored in options) {
        final s = scored.score;
        expect(s.diff2, isNotNull);
        expect(s.position, math.max(s.robustDiff1!, s.diff2!));
      }
    });

    test('bi cuối: chỉ các khoản phạt', () {
      final c = contextFor(onlyEightTable());
      final key = shotKey(c.geometry, Stroke.stun, 30);
      final s = scoreOption(c, key, c.lookup(key)!)!;
      expect(c.hasNext, isFalse);
      expect(s.position, 0);
      expect(s.distance, 0);
      expect(s.robustDiff1, isNull);
      expect(s.total, s.bank + s.tech + s.power);
    });

    test('từ điểm dừng không lỗ nào cho bi kế tiếp thì loại phương án', () {
      final c = contextFor(fallbackTable());
      final key = shotKey(c.geometry, Stroke.stun, fallbackPower);
      expect(scoreOption(c, key, c.lookup(key)!), isNull);
    });

    test('bằng điểm thì giữ phương án thử trước', () {
      final c = contextFor(railTable());
      final options = scoreTier(c, tierOneKeys(c.geometry));
      final tie = [options.first, options.first];
      expect(identical(bestOf(tie), options.first), isTrue);
      expect(bestOf(const []), isNull);
    });

    test('lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức', () {
      final base = directLookup();
      final powers = <double>[];
      final c = contextFor(railTable(), lookup: (k) {
        powers.add(k.power);
        return base(k);
      });
      final key = shotKey(c.geometry, Stroke.stun, 90);
      final aimed = c.lookup(key)!;
      scoreOption(c, key, aimed);
      final t = toleranceOf(c, key);
      expect(t.good + t.fair + t.bad, toleranceSamples);
      expect(powers.reduce(math.max), maxPower);
      expect(jitteredPower(90, powerJitter), maxPower);
      expect(jitteredPower(30, -powerJitter), 15);
    });
  });

  test('lưới vùng điều: ô trong biên, không đè bi, mức khớp góc dễ nhất', () {
    final s = railTable();
    final finder = CandidateFinder(game: s.game);
    final after = s.without([1]).balls;
    final cells = zoneGrid(after: after, next: finder);
    expect(cells, isNotEmpty);
    for (final cell in cells) {
      expect(s.table.contains(cell.center), isTrue);
      for (final b in after) {
        expect(cell.center.distanceTo(b.pos), greaterThanOrEqualTo(s.table.ballDiameter));
      }
      final angle = finder.easiest(cell.center, after)!.angle;
      expect(angle, lessThanOrEqualTo(cell.level == ZoneLevel.good ? zoneGood : zoneFair));
      if (cell.level == ZoneLevel.fair) expect(angle, greaterThan(zoneGood));
    }
    expect(zoneGrid(after: const [], next: finder), isEmpty);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/scoring_test.dart`
Expected: FAIL to compile, `Error when reading 'lib/domain/planner/scoring.dart'`.

- [ ] **Step 4: Write the implementation**

`lib/domain/planner/shot_options.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Đầu vào của một lần mô phỏng. Record nên so sánh theo giá trị: dùng
/// thẳng làm khoá bộ nhớ đệm của việc tính chia lát.
typedef ShotKey = ({
  Vec2 cue,
  Vec2 object,
  Pocket pocket,
  Stroke stroke,
  SideSpin spin,
  double power,
});

/// Tra một lần mô phỏng; null khi lõi quá `maxSimTime` cho cú đó.
typedef ShotLookup = AimedShot? Function(ShotKey key);

ShotKey shotKey(ShotGeometry g, Stroke stroke, double power,
        {SideSpin spin = const SideSpin.none()}) =>
    (cue: g.cue, object: g.object, pocket: g.pocket, stroke: stroke, spin: spin, power: power);

ShotKey withPower(ShotKey k, double power) => (
      cue: k.cue,
      object: k.object,
      pocket: k.pocket,
      stroke: k.stroke,
      spin: k.spin,
      power: power,
    );

/// Lực lệch [delta] điểm phần trăm, không quá [maxPower].
double jitteredPower(double power, double delta) => math.min(power + delta, maxPower);

/// Tầng 1: đứng / cu lê / trô × năm mức lực, đúng thứ tự thử.
List<ShotKey> tierOneKeys(ShotGeometry g) => [
      for (final s in strokeCandidates)
        for (final p in powerCandidates) shotKey(g, s, p),
    ];

/// Tầng 2, đường lui áp phê: kiểu đánh × trái/phải × ½/1 đầu cơ × lực (60).
List<ShotKey> tierTwoKeys(ShotGeometry g) => [
      for (final s in strokeCandidates)
        for (final side in SpinSide.values)
          for (final tips in sideTipsCandidates)
            for (final p in powerCandidates) shotKey(g, s, p, spin: SideSpin(side, tips)),
    ];

/// Một lần mô phỏng của Planner: cơ Thường, luôn bù ném, không mô phỏng cú
/// không bù (màn từng bước không vẽ đường đỏ). Quá giờ thì null: phương án
/// đó không dùng được, kế hoạch vẫn chạy tiếp (spec mục 4.3).
AimedShot? simulateKey(ShotKey k,
    {AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot}) {
  try {
    return aim(
      cue: k.cue,
      object: k.object,
      pocket: k.pocket,
      stroke: k.stroke,
      spin: k.spin,
      power: k.power,
      elevation: CueElevation.normal,
      table: table,
      compensate: true,
      withUncompensated: false,
    );
  } on SimulationTimeout {
    return null;
  }
}

/// Tra thẳng, có nhớ — cho test và công cụ dò bàn. Việc tính chia lát dùng
/// bộ nhớ của riêng nó.
ShotLookup directLookup({AimShotFn aim = aimShot, TableSpec table = TableSpec.nineFoot}) {
  final memo = <ShotKey, AimedShot?>{};
  return (k) => memo.containsKey(k)
      ? memo[k]
      : (memo[k] = simulateKey(k, aim: aim, table: table));
}

/// Vì sao một phương án bị loại (spec mục 4.3). Quá giờ là lookup null.
enum Rejection { scratch, objectMissed, blocked }

Rejection? rejectionOf(AimedShot aimed, Pocket pocket, List<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  final t = aimed.trace;
  if (t.cuePocket != null) return Rejection.scratch;
  if (t.objectPocket != pocket) return Rejection.objectMissed;
  if (!polylineClear(t.cueBefore, obstacles, table: table) ||
      !polylineClear(t.cueAfter, obstacles, table: table) ||
      !polylineClear(t.objectPath, obstacles, table: table)) {
    return Rejection.blocked;
  }
  return null;
}

/// Đường gấp khúc đi lọt qua mọi bi chắn. Bi thứ ba không tham gia va chạm
/// (PRD §8), chỉ dùng để kiểm chắn đường.
bool polylineClear(List<Vec2> points, List<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  if (points.isEmpty || obstacles.isEmpty) return true;
  if (points.length == 1) {
    return isPathClear(points.first, points.first, obstacles, table: table);
  }
  for (var i = 0; i + 1 < points.length; i++) {
    if (!isPathClear(points[i], points[i + 1], obstacles, table: table)) return false;
  }
  return true;
}
```

`lib/domain/planner/scoring.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

double bankPenaltyFor(int railCount) => railCount == 0
    ? 0
    : (railCount == 1 ? bankPenaltyOneRail : bankPenaltyManyRails);

/// Kiểu đánh cộng áp phê: càng nhiều thông số xoáy càng nhiều sai số (PRD §8).
double techPenaltyFor(Stroke stroke, SideSpin spin) {
  final base = switch (stroke) {
    Stroke.stun => techPenaltyStun,
    Stroke.follow => techPenaltyFollow,
    Stroke.draw => techPenaltyDraw,
  };
  if (spin.isNone) return base;
  return base + (spin.tips <= 0.5 ? sidePenaltyHalfTip : sidePenaltyOneTip);
}

double powerPenaltyFor(double power) => power * powerPenaltyPerPercent;

/// Góc cắt dễ nhất từ [from] để đánh [ball], bỏ lỗ bị [obstacles] chắn;
/// null khi không lỗ nào (spec mục 4).
double? bestAngleFrom(Vec2 from, Vec2 ball, Iterable<Vec2> obstacles,
        {TableSpec table = TableSpec.nineFoot}) =>
    bestPocket(cue: from, object: ball, others: obstacles, table: table)?.angle;

/// Điểm của một phương án, từng khoản (spec mục 5). Càng thấp càng tốt.
class OptionScore {
  const OptionScore({
    required this.position,
    this.robustDiff1,
    this.diff2,
    required this.bank,
    required this.tech,
    required this.power,
    required this.distance,
  });

  /// max(robustDiff1, diff2), hoặc robustDiff1; 0 khi là bi cuối.
  final double position;
  final double? robustDiff1;
  final double? diff2;
  final double bank;
  final double tech;
  final double power;

  /// Quãng bi ảo → điểm dừng, đã nhân [distanceWeight].
  final double distance;

  double get total => position + bank + tech + power + distance;
}

class ScoredOption {
  const ScoredOption(this.key, this.aimed, this.score);
  final ShotKey key;
  final AimedShot aimed;
  final OptionScore score;
}

/// Mọi thứ cần để chấm phương án cho một cặp bi–lỗ đã chọn.
class ScoringContext {
  ScoringContext({
    required this.geometry,
    required this.after,
    required this.lookup,
    required this.next,
  });

  /// Cặp bi–lỗ của bước này.
  final ShotGeometry geometry;

  /// Bi còn trên bàn sau khi bi này vào lỗ — cũng là bi chắn của cú này.
  final List<PlacedBall> after;
  final ShotLookup lookup;
  final CandidateFinder next;

  TableSpec get table => next.table;
  late final List<Vec2> obstacles = [for (final b in after) b.pos];

  /// Còn bi để đánh sau bi này không. 8 bi: bi đối thủ không tính.
  late final bool hasNext = legalTargetsAmong(next.game, after).isNotEmpty;

  /// Góc dễ nhất cho bi kế tiếp từ điểm dừng của [aimed]; mức nào quá giờ,
  /// chết cái, bị chắn hay bi mục tiêu không vào thì [blockedAngle].
  double angleAt(AimedShot? aimed) {
    if (aimed == null ||
        rejectionOf(aimed, geometry.pocket, obstacles, table: table) != null) {
      return blockedAngle;
    }
    return next.easiest(aimed.trace.cueEnd, after)?.angle ?? blockedAngle;
  }

  /// Nhìn trước bi thứ hai: cú kế tiếp là Đánh đứng bi [lookaheadPower] vào
  /// lỗ dễ nhất, mô phỏng thật. null khi sau bi kế tiếp không còn bi nào.
  double? lookahead(Candidate first) {
    final after2 = [for (final b in after) if (b.number != first.ball.number) b];
    if (legalTargetsAmong(next.game, after2).isEmpty) return null;
    final a = lookup(shotKey(first.geometry, Stroke.stun, lookaheadPower));
    if (a == null ||
        rejectionOf(a, first.geometry.pocket, [for (final b in after2) b.pos], table: table) !=
            null) {
      return blockedAngle;
    }
    return next.easiest(a.trace.cueEnd, after2)?.angle ?? blockedAngle;
  }
}

/// Chấm một phương án đã qua vòng loại (spec mục 5). null khi từ điểm dừng
/// không lỗ nào khả thi cho bi kế tiếp — vị trí đó giết cú sau (PRD §5.3).
OptionScore? scoreOption(ScoringContext c, ShotKey key, AimedShot aimed) {
  final trace = aimed.trace;
  final bank = bankPenaltyFor(trace.cueRailCount);
  final tech = techPenaltyFor(key.stroke, key.spin);
  final power = powerPenaltyFor(key.power);
  if (!c.hasNext) {
    return OptionScore(position: 0, bank: bank, tech: tech, power: power, distance: 0);
  }
  final first = c.next.easiest(trace.cueEnd, c.after);
  if (first == null) return null;
  var robust = first.angle;
  for (final delta in const [-powerJitter, powerJitter]) {
    robust = math.max(robust, c.angleAt(c.lookup(withPower(key, jitteredPower(key.power, delta)))));
  }
  final diff2 = c.lookahead(first);
  return OptionScore(
    position: diff2 == null ? robust : math.max(robust, diff2),
    robustDiff1: robust,
    diff2: diff2,
    bank: bank,
    tech: tech,
    power: power,
    distance: c.geometry.ghost.distanceTo(trace.cueEnd) * distanceWeight,
  );
}

/// Mô phỏng và chấm các phương án theo đúng thứ tự [keys]; chỉ trả phương
/// án dùng được.
List<ScoredOption> scoreTier(ScoringContext c, Iterable<ShotKey> keys) {
  final out = <ScoredOption>[];
  for (final key in keys) {
    final aimed = c.lookup(key);
    if (aimed == null) continue;
    if (rejectionOf(aimed, c.geometry.pocket, c.obstacles, table: c.table) != null) continue;
    final score = scoreOption(c, key, aimed);
    if (score != null) out.add(ScoredOption(key, aimed, score));
  }
  return out;
}

/// Điểm thấp nhất; bằng điểm thì giữ phương án thử trước, để tất định.
ScoredOption? bestOf(List<ScoredOption> options) {
  ScoredOption? best;
  for (final o in options) {
    final current = best;
    if (current == null || o.score.total < current.score.total) best = o;
  }
  return best;
}

typedef ToleranceCounts = ({int good, int fair, int bad});

/// Độ chịu sai số lực, chỉ để hiển thị (spec mục 5.4): [toleranceSamples]
/// mức đều nhau từ lực − [powerJitter] tới lực + [powerJitter], cùng hàm
/// mô phỏng và chấm với lúc chọn phương án.
ToleranceCounts toleranceOf(ScoringContext c, ShotKey key) {
  var good = 0, fair = 0, bad = 0;
  const span = 2 * powerJitter;
  for (var k = 0; k < toleranceSamples; k++) {
    final p = jitteredPower(key.power, -powerJitter + k * span / (toleranceSamples - 1));
    final angle = c.angleAt(c.lookup(withPower(key, p)));
    if (angle <= zoneGood) {
      good++;
    } else if (angle <= zoneFair) {
      fair++;
    } else {
      bad++;
    }
  }
  return (good: good, fair: fair, bad: bad);
}

enum ZoneLevel { good, fair }

class ZoneCell {
  const ZoneCell(this.center, this.level);
  final Vec2 center;
  final ZoneLevel level;
}

/// Lưới vùng điều tốt (spec mục 7.1): ô [zoneCell] cm; ô xanh nếu góc dễ
/// nhất cho bi kế tiếp ≤ [zoneGood], vàng nếu ≤ [zoneFair]; bỏ ô xấu hơn,
/// ô không có đường, ô đè lên bi. Cùng [CandidateFinder.easiest] với lúc chấm.
List<ZoneCell> zoneGrid({required List<PlacedBall> after, required CandidateFinder next}) {
  if (legalTargetsAmong(next.game, after).isEmpty) return const [];
  final table = next.table;
  final cells = <ZoneCell>[];
  for (var x = zoneCell / 2; x < table.length; x += zoneCell) {
    for (var y = zoneCell / 2; y < table.width; y += zoneCell) {
      final p = Vec2(x, y);
      if (!table.contains(p)) continue;
      if (after.any((b) => b.pos.distanceTo(p) < table.ballDiameter)) continue;
      final angle = next.easiest(p, after)?.angle;
      if (angle == null) continue;
      if (angle <= zoneGood) {
        cells.add(ZoneCell(p, ZoneLevel.good));
      } else if (angle <= zoneFair) {
        cells.add(ZoneCell(p, ZoneLevel.fair));
      }
    }
  }
  return cells;
}
```

- [ ] **Step 5: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner && "$FLUTTER" analyze`
Expected: PASS, `No issues found!`. If `'chết cái, bi mục tiêu không vào…'` fails on `Rejection.objectMissed`, the stun 15 % shot now reaches the pocket after a physics change: run the probe of Task 7 Step 1 on `cornerFollowTable` and pick the weakest power that misses, keeping the assertion's meaning.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/planner test/support/planner_tables.dart test/domain/planner/scoring_test.dart
git commit -m "Simulate, reject and score planner options on the physics core

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Dư dày / dư mỏng advice (PRD §5.5, test 9)

**Files:**
- Create: `lib/domain/planner/miss_advice.dart`
- Test: `test/domain/planner/miss_advice_test.dart`

**Interfaces:**
- Consumes: `ShotGeometry` (`objectDir`, `aimDir`, `object`, `angle`); `missAngleDeg`, `missTravel` (Task 3).
- Produces:
  - `enum MissSide { thick, thin }`
  - `class MissAdvice { const MissAdvice({required Vec2 thick, required Vec2 thin, required MissSide safer, required double errDeg}); }`
  - `double missErrDeg(double cutAngle)`
  - `Vec2 missDirection(ShotGeometry g, MissSide side)` (unit vector)
  - `MissAdvice missSafetyAdvice(ShotGeometry g, List<Vec2> obstaclesAfter, {TableSpec table = TableSpec.nineFoot})`

- [ ] **Step 1: Write the failing tests**

`test/domain/planner/miss_advice_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  const table = TableSpec.nineFoot;
  double deg(Vec2 a, Vec2 b) => math.acos(a.dot(b).clamp(-1.0, 1.0)) * 180 / math.pi;

  test('9. cắt mỏng (> 60°) có errDeg lớn hơn rõ rệt cắt dày (< 20°)', () {
    final thin = geometryFor(tableCenter, Pocket.topRight, 65);
    final thick = geometryFor(tableCenter, Pocket.topRight, 15);
    expect(missErrDeg(thin.angle), greaterThan(2 * missErrDeg(thick.angle)));
    expect(missErrDeg(thick.angle), greaterThanOrEqualTo(missAngleDeg));
  });

  test('errDeg không vượt 3 lần sai số ngắm gốc', () {
    expect(missErrDeg(85), lessThanOrEqualTo(3 * missAngleDeg));
  });

  test('dư dày là lệch về phía hướng cơ: góc cắt nhỏ đi đúng errDeg', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 40);
    final err = missErrDeg(g.angle);
    expect(deg(missDirection(g, MissSide.thick), g.aimDir), closeTo(g.angle - err, 1e-6));
    expect(deg(missDirection(g, MissSide.thin), g.aimDir), closeTo(g.angle + err, 1e-6));
  });

  test('cắt về phía bên kia cũng đúng chiều', () {
    final g = geometryFor(tableCenter, Pocket.topRight, -40);
    final err = missErrDeg(g.angle);
    expect(deg(missDirection(g, MissSide.thick), g.aimDir), closeTo(g.angle - err, 1e-6));
  });

  test('bi cuối (không còn bi nào) không lỗi; điểm trượt nằm trong biên', () {
    final g = geometryFor(const Vec2(220, 30), Pocket.topRight, 30);
    final advice = missSafetyAdvice(g, const []);
    expect(table.contains(advice.thick), isTrue);
    expect(table.contains(advice.thin), isTrue);
    expect(advice.errDeg, missErrDeg(g.angle));
  });

  test('hướng có bi khác sát điểm trượt thì khó cho đối thủ hơn', () {
    // Điểm trượt giữa bàn, xa băng: phần băng của hai hướng gần bằng nhau,
    // nên bi nằm sát một hướng (dưới 40 cm) quyết định.
    final g = geometryFor(const Vec2(60, 63.5), Pocket.bottomRight, 20);
    final open = missSafetyAdvice(g, const []);
    final apart = (open.thick - open.thin).normalized;
    expect(missSafetyAdvice(g, [open.thick + apart * 25]).safer, MissSide.thick);
    expect(missSafetyAdvice(g, [open.thin - apart * 25]).safer, MissSide.thin);
  });
}
```

`geometryFor(object, pocket, degrees)` builds the cue from the definition (`test/support/table_layouts.dart`); a negative angle cuts to the other side.

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/miss_advice_test.dart`
Expected: FAIL to compile, `Error when reading 'lib/domain/planner/miss_advice.dart'`.

- [ ] **Step 3: Write the implementation**

`lib/domain/planner/miss_advice.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

enum MissSide { thick, thin }

/// Gợi ý định tính "nếu trượt thì nên trượt về phía nào" (PRD §5.5). Không
/// ảnh hưởng việc chọn phương án; không mô phỏng quỹ đạo trượt thật.
class MissAdvice {
  const MissAdvice({
    required this.thick,
    required this.thin,
    required this.safer,
    required this.errDeg,
  });

  /// Chỗ bi mục tiêu trôi tới nếu trượt dày / mỏng, đã kẹp vào biên bàn.
  final Vec2 thick;
  final Vec2 thin;

  /// Hướng khó cho đối thủ hơn — nên chủ động lệch nhẹ về phía này.
  final MissSide safer;

  /// Sai số ngắm giả định sau khi nhân độ nhạy, độ. Chỉ dùng bên trong:
  /// không bao giờ hiện thành lời khuyên ngắm theo độ.
  final double errDeg;
}

/// Cắt càng mỏng càng nhạy sai số ngắm: `sensitivity = min(3, 1/max(0.15,
/// cos góc cắt))`, `errDeg = min(30, missAngleDeg × sensitivity)`.
double missErrDeg(double cutAngle) {
  final cos = math.cos(cutAngle * math.pi / 180);
  final sensitivity = math.min(3.0, 1 / math.max(0.15, cos));
  return math.min(30.0, missAngleDeg * sensitivity);
}

/// Hướng bi mục tiêu đi nếu trượt về phía [side]. Dày hơn là bi mục tiêu bị
/// đẩy lệch về phía hướng cơ (góc cắt nhỏ đi); mỏng là ngược lại. Cú thẳng
/// không có phía nào: lấy chiều dương làm dày, để kết quả tất định.
Vec2 missDirection(ShotGeometry g, MissSide side) {
  final towardAim = g.objectDir.cross(g.aimDir) >= 0 ? 1.0 : -1.0;
  final turn = missErrDeg(g.angle) * math.pi / 180 * towardAim;
  return g.objectDir.rotated(side == MissSide.thick ? turn : -turn);
}

/// PRD §5.5: điểm trượt sát băng hoặc kẹt gần bi khác thì khó cho đối thủ
/// hơn. [obstaclesAfter] rỗng (bi cuối) vẫn chạy được. Bằng nhau thì dày.
MissAdvice missSafetyAdvice(ShotGeometry g, List<Vec2> obstaclesAfter,
    {TableSpec table = TableSpec.nineFoot}) {
  Vec2 missAt(MissSide side) => table.clamp(g.object + missDirection(g, side) * missTravel);
  double hardness(Vec2 p) {
    final rail = [
      p.x - table.minX,
      table.maxX - p.x,
      p.y - table.minY,
      table.maxY - p.y,
    ].reduce(math.min);
    final nearest = obstaclesAfter.isEmpty
        ? double.infinity
        : obstaclesAfter.map(p.distanceTo).reduce(math.min);
    return 400 / (rail + 10) + (nearest < 40 ? 25 : 0);
  }

  final thick = missAt(MissSide.thick);
  final thin = missAt(MissSide.thin);
  return MissAdvice(
    thick: thick,
    thin: thin,
    safer: hardness(thin) > hardness(thick) ? MissSide.thin : MissSide.thick,
    errDeg: missErrDeg(g.angle),
  );
}
```

- [ ] **Step 4: Run the tests**

Run: `"$FLUTTER" test test/domain/planner/miss_advice_test.dart && "$FLUTTER" analyze`
Expected: PASS, `No issues found!` (checked against `c43c74a` while writing this plan). In the last test, the two miss points are about 20 cm apart and both are mid-table, so their rail terms are close. An obstacle 25 cm beyond one point is within 40 cm of it but not of the other, and that +25 decides the side.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/planner/miss_advice.dart test/domain/planner/miss_advice_test.dart
git commit -m "Add the planner's thick or thin miss advice from cut sensitivity

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `PlanStep` and the sliced `PlannerJob`

**Files:**
- Create: `lib/domain/planner/plan_step.dart`, `lib/domain/planner/planner_job.dart`
- Modify: `test/support/planner_tables.dart` (append `fingerprint`)
- Test: `test/domain/planner/planner_job_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 3–5; `sawsBhePercent` (`saws.dart`).
- Produces:
  - `enum PlanStepKind { normal, fallback, safety }`
  - `typedef JitterEnds = ({Vec2? minus, Vec2? plus});`
  - `class PlanStep` with fields `kind`, `cbFrom`, `ballNum` (`int?`), `geometry` (`ShotGeometry?`), `stroke`, `power`, `spin`, `aimed` (`AimedShot?`), `score` (`OptionScore?`), `jitterEnds` (`JitterEnds?`), `tolerance` (`ToleranceCounts?`), `missAdvice` (`MissAdvice?`), `sawsBhePercent` (`int?`), `nextBallNum` (`int?`); getters `trace` (`ShotTrace?`), `pocket` (`Pocket?`), `cutAngle` (`double?`); constructor `PlanStep.safety({required Vec2 cbFrom, int? ballNum})`
  - `PlanStep planStep({required GameType game, required Vec2 cue, required List<PlacedBall> remaining, required ShotLookup lookup, required CandidateFinder finder})`
  - `sealed class PlannerEvent`; `final class StepReady extends PlannerEvent { final int index; final PlanStep step; }`; `final class PlanDone extends PlannerEvent { final List<PlanStep> steps; }`
  - `class PlannerJob { PlannerJob(TableSetup setup, {AimShotFn aim = aimShot}); final TableSetup setup; List<PlanStep> get steps; bool get isDone; bool get isCancelled; int get simulations; int get totalSteps; void cancel(); List<PlannerEvent> step({Duration budget = sliceBudget, int? maxSimulations}); }`
  - `List<PlanStep> planToEnd(TableSetup setup, {AimShotFn aim = aimShot})`
  - test helper `String fingerprint(List<PlanStep> steps)`

- [ ] **Step 1: Append the fingerprint helper**

Append to `test/support/planner_tables.dart` (add `import 'package:poolcoachai/domain/planner/plan_step.dart';` at the top):

```dart
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
```

- [ ] **Step 2: Write the failing tests**

`test/domain/planner/planner_job_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

void main() {
  /// Chạy [setup] từng lát, kiểm thứ tự sự kiện, trả các bước đã báo.
  List<PlanStep> sliced(TableSetup setup,
      {int? maxSimulations, Duration budget = sliceBudget}) {
    final job = PlannerJob(setup);
    final seen = <PlanStep>[];
    var done = 0;
    while (!job.isDone) {
      for (final e in job.step(budget: budget, maxSimulations: maxSimulations)) {
        switch (e) {
          case StepReady(:final index, :final step):
            expect(index, seen.length);
            seen.add(step);
          case PlanDone(:final steps):
            done++;
            expect(steps, seen);
        }
      }
    }
    expect(done, 1);
    return seen;
  }

  test('nối liền: bước sau bắt đầu đúng đối tượng điểm dừng của bước trước', () {
    for (final setup in [orderTable(GameType.nineBall), railTable(), fallbackTable()]) {
      final steps = planToEnd(setup);
      expect(identical(steps.first.cbFrom, setup.cue), isTrue);
      for (var i = 0; i + 1 < steps.length; i++) {
        expect(identical(steps[i].trace!.cueEnd, steps[i + 1].cbFrom), isTrue,
            reason: 'bước $i');
      }
    }
  });

  test('chạy từng lát cho đúng y kết quả chạy một mạch, với mọi cỡ lát', () {
    for (final setup in [orderTable(GameType.nineBall), railTable(), fallbackTable()]) {
      final whole = fingerprint(planToEnd(setup));
      for (final n in [1, 3, 7]) {
        expect(fingerprint(sliced(setup, maxSimulations: n)), whole, reason: 'lát $n');
      }
      expect(fingerprint(sliced(setup, budget: Duration.zero)), whole);
      expect(fingerprint(sliced(setup)), whole);
    }
  });

  test('tất định: cùng bàn chạy hai lần cho cùng kế hoạch', () {
    final setup = typicalNineBallTable();
    expect(fingerprint(planToEnd(setup)), fingerprint(planToEnd(setup)));
  });

  test('bước 1 báo ra trước khi cả kế hoạch xong', () {
    final job = PlannerJob(orderTable(GameType.nineBall));
    var events = <PlannerEvent>[];
    while (events.isEmpty) {
      events = job.step(maxSimulations: 1);
    }
    expect(events.single, isA<StepReady>());
    expect(job.isDone, isFalse);
    expect(job.totalSteps, 4);
  });

  test('hủy giữa chừng thì không báo thêm bước nào', () {
    final job = PlannerJob(orderTable(GameType.nineBall));
    while (job.steps.isEmpty) {
      job.step(maxSimulations: 1);
    }
    job.cancel();
    final sims = job.simulations;
    for (var i = 0; i < 50; i++) {
      expect(job.step(), isEmpty);
    }
    expect(job.simulations, sims);
    expect(job.steps, hasLength(1));
    expect(job.isDone, isFalse);
    expect(job.isCancelled, isTrue);
  });

  test('đặt lại bi cái: kế hoạch mới từ chỗ mới với các bi còn lại', () {
    final setup = orderTable(GameType.nineBall);
    final first = planToEnd(setup).first;
    const placed = Vec2(100, 50);
    final again = setup.without([first.ballNum!]).withCue(placed);
    final steps = planToEnd(again);
    expect(identical(steps.first.cbFrom, again.cue), isTrue);
    expect(steps.first.ballNum, 2);
    expect(steps.map((s) => s.ballNum), isNot(contains(1)));
    expect(fingerprint(steps), fingerprint(planToEnd(again)));
  });

  test('đặt lại bi cái vào chỗ không đánh được: bước đầu là phòng thủ', () {
    final steps = planToEnd(blockedEverywhereTable().withCue(const Vec2(200, 30)));
    expect(steps, hasLength(1));
    expect(steps.single.kind, PlanStepKind.safety);
  });

  test('8 bi chỉ còn bi 8: một bước, không có phần vị trí', () {
    final steps = planToEnd(onlyEightTable());
    expect(steps, hasLength(1));
    final s = steps.single;
    expect(s.ballNum, 8);
    expect(s.kind, PlanStepKind.normal);
    expect(s.nextBallNum, isNull);
    expect(s.tolerance, isNull);
    expect(s.missAdvice, isNull);
    expect(s.score!.position, 0);
  });

  test('bước thường có đủ thông tin hiển thị', () {
    final s = planToEnd(railTable()).first;
    expect(s.kind, PlanStepKind.normal);
    expect(s.nextBallNum, 2);
    final t = s.tolerance!;
    expect(t.good + t.fair + t.bad, toleranceSamples);
    expect(s.missAdvice, isNotNull);
    expect(s.sawsBhePercent, isNull);
    expect(s.jitterEnds, isNotNull);
  });

  group('thứ tự dự phòng (spec mục 5.5)', () {
    test('tầng 1: bàn thường không thử áp phê', () {
      final spins = <SideSpin>[];
      final steps =
          planToEnd(railTable(), aim: recordingAim((_, spin, _) => spins.add(spin)));
      expect(steps.every((s) => s.spin.isNone), isTrue);
      expect(spins.where((s) => !s.isNone), isEmpty);
    });

    test('tầng 2: không phương án thẳng nào dùng được thì áp phê, kèm SAWS, phạt cộng dồn', () {
      final setup = railTable();
      final ball1 = setup.balls.first.pos;
      final steps = planToEnd(setup,
          aim: scratchingAim((object, _, spin, _) => object == ball1 && spin.isNone));
      final s = steps.first;
      expect(s.kind, PlanStepKind.normal);
      expect(s.spin.isNone, isFalse);
      expect(
          s.sawsBhePercent,
          sawsBhePercent(
              distance: s.cbFrom.distanceTo(s.geometry!.ghost),
              power: s.power,
              stroke: s.stroke));
      expect(s.score!.tech, techPenaltyFor(s.stroke, s.spin));
      expect(s.score!.tech, greaterThanOrEqualTo(sidePenaltyHalfTip));
    });

    test('tầng 3: không vị trí nào cho bi sau thì Đánh đứng bi 30 %, kế hoạch đi tiếp', () {
      final steps = planToEnd(fallbackTable());
      expect(steps, hasLength(2));
      final s = steps.first;
      expect(s.kind, PlanStepKind.fallback);
      expect(s.ballNum, 1);
      expect(s.stroke, Stroke.stun);
      expect(s.power, fallbackPower);
      expect(s.spin.isNone, isTrue);
      expect(s.trace!.cuePocket, isNull);
      expect(steps[1].kind, PlanStepKind.safety);
      expect(steps[1].ballNum, 2);
      expect(identical(s.trace!.cueEnd, steps[1].cbFrom), isTrue);
    });

    test('tầng 4: cả cú dự phòng cũng hỏng thì phòng thủ, kế hoạch dừng', () {
      final setup = railTable();
      final ball1 = setup.balls.first.pos;
      final steps =
          planToEnd(setup, aim: scratchingAim((object, _, _, _) => object == ball1));
      expect(steps, hasLength(1));
      expect(steps.single.kind, PlanStepKind.safety);
      expect(steps.single.ballNum, 1);
    });

    test('9 bi: bi bắt buộc bị chắn ở mọi lỗ thì phòng thủ ngay', () {
      final job = PlannerJob(blockedEverywhereTable());
      final events = job.step(budget: const Duration(days: 1));
      expect(job.isDone, isTrue);
      expect(events.whereType<PlanDone>().single.steps.single.kind, PlanStepKind.safety);
      expect(job.simulations, 0);
    });
  });

  test('một phương án ném SimulationTimeout thì bị loại, kế hoạch vẫn ra', () {
    final setup = railTable();
    final ball1 = setup.balls.first.pos;
    final steps = planToEnd(setup,
        aim: timeoutAim((object, stroke, _, power) =>
            object == ball1 && stroke == Stroke.stun && power == 45));
    final s = steps.first;
    expect(s.kind, PlanStepKind.normal);
    expect(s.stroke == Stroke.stun && s.power == 45, isFalse);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/planner_job_test.dart`
Expected: FAIL to compile, `Error when reading 'lib/domain/planner/planner_job.dart'`.

- [ ] **Step 4: Write `plan_step.dart`**

```dart
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// normal: phương án đã chấm (tầng 1 hoặc 2). fallback: Đánh đứng bi
/// [fallbackPower], không có vị trí tốt (tầng 3). safety: phòng thủ, kế
/// hoạch dừng (tầng 4, hoặc không cặp bi–lỗ nào).
enum PlanStepKind { normal, fallback, safety }

/// Điểm dừng khi lực −15 % và +15 %; null ở mức hỏng.
typedef JitterEnds = ({Vec2? minus, Vec2? plus});

/// Một bước của kế hoạch (spec mục 4.4).
class PlanStep {
  const PlanStep({
    required this.kind,
    required this.cbFrom,
    this.ballNum,
    this.geometry,
    this.stroke = Stroke.stun,
    this.power = 0,
    this.spin = const SideSpin.none(),
    this.aimed,
    this.score,
    this.jitterEnds,
    this.tolerance,
    this.missAdvice,
    this.sawsBhePercent,
    this.nextBallNum,
  });

  const PlanStep.safety({required this.cbFrom, this.ballNum})
      : kind = PlanStepKind.safety,
        geometry = null,
        stroke = Stroke.stun,
        power = 0,
        spin = const SideSpin.none(),
        aimed = null,
        score = null,
        jitterEnds = null,
        tolerance = null,
        missAdvice = null,
        sawsBhePercent = null,
        nextBallNum = null;

  final PlanStepKind kind;

  /// Điểm bi cái trước cú đánh — chính đối tượng `cueEnd` của bước trước.
  final Vec2 cbFrom;

  /// null chỉ ở bước phòng thủ 8 bi khi không có bi cụ thể bị ép (PRD §4).
  final int? ballNum;
  final ShotGeometry? geometry;
  final Stroke stroke;
  final double power;
  final SideSpin spin;

  /// Cú đã dò; màn từng bước dùng lại dòng áp phê của màn mô phỏng.
  /// `aimOffsetDeg` của nó không bao giờ hiện lên màn.
  final AimedShot? aimed;
  final OptionScore? score;
  final JitterEnds? jitterEnds;

  /// null khi là bi cuối (không có bi kế tiếp để xếp vùng điều).
  final ToleranceCounts? tolerance;

  /// null khi là bi cuối.
  final MissAdvice? missAdvice;

  /// Chỉ có khi dùng áp phê.
  final int? sawsBhePercent;
  final int? nextBallNum;

  ShotTrace? get trace => aimed?.trace;
  Pocket? get pocket => geometry?.pocket;
  double? get cutAngle => geometry?.angle;
}
```

- [ ] **Step 5: Write `planner_job.dart`**

```dart
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';

/// Tính một bước từ bi cái [cue] với các bi [remaining] (spec mục 4–5).
///
/// Hàm thuần trên [lookup]: việc tính chia lát gọi lại nó từ đầu mỗi khi
/// bộ nhớ đệm có thêm một lần mô phỏng, nên thứ tự thử ở đây chính là thứ
/// tự mô phỏng — và kết quả không phụ thuộc cỡ lát.
PlanStep planStep({
  required GameType game,
  required Vec2 cue,
  required List<PlacedBall> remaining,
  required ShotLookup lookup,
  required CandidateFinder finder,
}) {
  final candidate = finder.easiest(cue, remaining);
  if (candidate == null) {
    // 9 / 10 bi: bi bắt buộc bị chắn ở mọi lỗ. 8 bi: không bi nào của mình
    // đánh được — không có bi cụ thể bị ép (PRD §4).
    return PlanStep.safety(
      cbFrom: cue,
      ballNum: game == GameType.eightBall
          ? null
          : legalTargetsAmong(game, remaining).firstOrNull?.number,
    );
  }
  final g = candidate.geometry;
  final ctx = ScoringContext(
    geometry: g,
    after: [for (final b in remaining) if (b.number != candidate.ball.number) b],
    lookup: lookup,
    next: finder,
  );

  // Tầng 2 chỉ chạy khi tầng 1 không còn phương án nào — không bao giờ để
  // "so" với tầng 1 (spec mục 5.5).
  final best = bestOf(scoreTier(ctx, tierOneKeys(g))) ??
      bestOf(scoreTier(ctx, tierTwoKeys(g)));
  if (best != null) return _chosenStep(ctx, cue, candidate, best);

  final fallback = lookup(shotKey(g, Stroke.stun, fallbackPower));
  if (fallback != null &&
      rejectionOf(fallback, g.pocket, ctx.obstacles, table: ctx.table) == null) {
    return PlanStep(
      kind: PlanStepKind.fallback,
      cbFrom: cue,
      ballNum: candidate.ball.number,
      geometry: g,
      stroke: Stroke.stun,
      power: fallbackPower,
      aimed: fallback,
      missAdvice: ctx.hasNext ? missSafetyAdvice(g, ctx.obstacles, table: ctx.table) : null,
      nextBallNum:
          ctx.hasNext ? finder.easiest(fallback.trace.cueEnd, ctx.after)?.ball.number : null,
    );
  }
  return PlanStep.safety(cbFrom: cue, ballNum: candidate.ball.number);
}

PlanStep _chosenStep(ScoringContext ctx, Vec2 cue, Candidate candidate, ScoredOption best) {
  final key = best.key;
  final g = candidate.geometry;
  Vec2? endAt(double delta) {
    final a = ctx.lookup(withPower(key, jitteredPower(key.power, delta)));
    if (a == null || rejectionOf(a, key.pocket, ctx.obstacles, table: ctx.table) != null) {
      return null;
    }
    return a.trace.cueEnd;
  }

  return PlanStep(
    kind: PlanStepKind.normal,
    cbFrom: cue,
    ballNum: candidate.ball.number,
    geometry: g,
    stroke: key.stroke,
    power: key.power,
    spin: key.spin,
    aimed: best.aimed,
    score: best.score,
    jitterEnds: (minus: endAt(-powerJitter), plus: endAt(powerJitter)),
    tolerance: ctx.hasNext ? toleranceOf(ctx, key) : null,
    missAdvice: ctx.hasNext ? missSafetyAdvice(g, ctx.obstacles, table: ctx.table) : null,
    // Cùng quãng cơ → bi ảo hình học như dòng SAWS của màn mô phỏng.
    sawsBhePercent: key.spin.isNone
        ? null
        : sawsBhePercent(distance: cue.distanceTo(g.ghost), power: key.power, stroke: key.stroke),
    nextBallNum: ctx.hasNext
        ? ctx.next.easiest(best.aimed.trace.cueEnd, ctx.after)!.ball.number
        : null,
  );
}

sealed class PlannerEvent {
  const PlannerEvent();
}

/// Bước [index] vừa tính xong.
final class StepReady extends PlannerEvent {
  const StepReady(this.index, this.step);
  final int index;
  final PlanStep step;
}

/// Kế hoạch xong (dọn hết bàn hoặc dừng ở bước phòng thủ).
final class PlanDone extends PlannerEvent {
  const PlanDone(this.steps);
  final List<PlanStep> steps;
}

/// Việc tính chia lát (spec mục 4.5), cùng mẫu với `ScratchAdviceJob`.
///
/// Mỗi đơn vị việc chạy lại [planStep] của bước đang tính trên bộ nhớ đệm;
/// gặp lần mô phỏng chưa có thì làm đúng lần đó rồi dừng. Vì vậy chạy từng
/// lát cho đúng y kết quả như chạy một mạch: Stopwatch chỉ quyết định *khi
/// nào* trả quyền cho giao diện, không bao giờ quyết định *tính gì*.
class PlannerJob {
  PlannerJob(this.setup, {this.aim = aimShot})
      : _cue = setup.cue,
        _remaining = [...setup.balls]..sort((a, b) => a.number.compareTo(b.number)),
        _finder = CandidateFinder(game: setup.game, table: setup.table);

  final TableSetup setup;
  final AimShotFn aim;
  final CandidateFinder _finder;
  final _sims = <ShotKey, AimedShot?>{};
  final _steps = <PlanStep>[];
  Vec2 _cue;
  List<PlacedBall> _remaining;
  bool _done = false;
  bool _cancelled = false;

  List<PlanStep> get steps => List.unmodifiable(_steps);
  bool get isDone => _done;
  bool get isCancelled => _cancelled;

  /// Số lần mô phỏng đã chạy.
  int get simulations => _sims.length;

  /// Mẫu số của "Đang tính bước X/N".
  int get totalSteps => plannedStepCount(setup);

  /// Rời màn hay sửa bàn: bỏ việc đang tính, không báo thêm gì.
  void cancel() => _cancelled = true;

  /// Làm việc tới khi hết [budget] (hoặc đủ [maxSimulations] lần mô phỏng
  /// mới, cho test), luôn ít nhất một đơn vị. Không bắt đầu đơn vị mới nếu
  /// đơn vị dài nhất của lát này không còn vừa ngân sách: một lần mô phỏng
  /// trên Chrome mất vài mili giây, chạy quá là rớt khung hình.
  List<PlannerEvent> step({Duration budget = sliceBudget, int? maxSimulations}) {
    if (_done || _cancelled) return const [];
    final events = <PlannerEvent>[];
    final clock = Stopwatch()..start();
    var simulated = 0;
    var longest = Duration.zero;
    while (!_done) {
      final started = clock.elapsed;
      try {
        _commit(
          planStep(
            game: setup.game,
            cue: _cue,
            remaining: _remaining,
            lookup: _lookup,
            finder: _finder,
          ),
          events,
        );
      } on _Missing catch (m) {
        _sims[m.key] = simulateKey(m.key, aim: aim, table: setup.table);
        simulated++;
      }
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxSimulations != null && simulated >= maxSimulations) break;
      if (clock.elapsed + longest > budget) break;
    }
    return events;
  }

  AimedShot? _lookup(ShotKey key) {
    if (_sims.containsKey(key)) return _sims[key];
    throw _Missing(key);
  }

  void _commit(PlanStep step, List<PlannerEvent> events) {
    _steps.add(step);
    events.add(StepReady(_steps.length - 1, step));
    if (step.kind == PlanStepKind.safety) {
      _finish(events);
      return;
    }
    _remaining = [for (final b in _remaining) if (b.number != step.ballNum) b];
    // Bất biến của kế hoạch: bước sau bắt đầu đúng đối tượng này, không
    // tính lại, không sao chép (spec mục 4.4).
    _cue = step.trace!.cueEnd;
    if (legalTargetsAmong(setup.game, _remaining).isEmpty) _finish(events);
  }

  void _finish(List<PlannerEvent> events) {
    _done = true;
    events.add(PlanDone(List.unmodifiable(_steps)));
  }
}

class _Missing implements Exception {
  const _Missing(this.key);
  final ShotKey key;
}

/// Chạy một mạch tới hết — cho test, công cụ dò bàn và đo tốc độ.
List<PlanStep> planToEnd(TableSetup setup, {AimShotFn aim = aimShot}) {
  final job = PlannerJob(setup, aim: aim);
  while (!job.isDone) {
    job.step(budget: const Duration(days: 1));
  }
  return job.steps;
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner && "$FLUTTER" analyze`
Expected: PASS, `No issues found!`. Rules for a red test:
- If `'tầng 2 …'` fails with `s.spin.isNone == true`: no side-spin option pockets ball 1 cleanly on `railTable`. Run the Task 7 probe and report. Do not change the tier logic.
- If `'tầng 3 …'` fails: the stun 30 % shot no longer pockets ball 1 after a physics change. Shorten `distance` in `fallbackTable` (30 → 20 cm) and re-run.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/planner test/support/planner_tables.dart test/domain/planner/planner_job_test.dart
git commit -m "Add PlanStep and the sliced PlannerJob with the four-tier fallback order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The nine PRD §7 tests on the real physics core, and the fixture probe

**Files:**
- Create: `test/domain/planner/fixture_probe_test.dart` (tag `probe`)
- Test: `test/domain/planner/prd_section7_test.dart`
- Modify: `dart_test.yaml` (add the `probe` tag)

**Interfaces:**
- Consumes: `planToEnd`, `PlanStep`, `scoreTier`, `bestOf`, `tierOneKeys`, `shotKey`, `rejectionOf`, `bestAngleFrom`, `missErrDeg`, `CandidateFinder`, the fixtures and `contextFor` (Tasks 3–6).
- Produces: `flutter test --tags probe --run-skipped test/domain/planner/fixture_probe_test.dart` prints, for each fixture's first step, one row per tier-1 option (rejection or score breakdown), and runs a grid search that prints layouts meeting the conditions of tests 5, 7 and 8.

**How the fixtures were found, and what to do if one breaks.**
- `railTable` and `cornerFollowTable` were found by a grid search on c43c74a with the same scoring, and checked option by option. The numbers are in the comments of `planner_tables.dart`.
- `orderTable`, `blockedEverywhereTable`, `opponentBlocksTable` and the 8-ball tables rest on geometry alone (cut angles from `bestPocket`), which no physics constant changes.
- `orderTable` must also run to four steps on the real core. That depends on physics.

If a physics-dependent assertion fails, or fails after the owner's tuning in Task 14:
1. Run the probe and read the table for that fixture.
2. Move the fixture (or take a layout the grid search prints) until the acceptance assertion below holds.
3. Update `planner_tables.dart`, its comment and `tool/e2e/planner.mjs` together.
4. Never weaken an assertion to make a fixture pass.

- [ ] **Step 1: Add the probe tag and write the probe**

Append under `tags:` in `dart_test.yaml`:

```yaml
  # In bảng phương án của các bàn test Planner, để dò lại toạ độ khi một bàn
  # hết đúng điều kiện. Không phải test; chạy riêng bằng:
  #   flutter test --tags probe --run-skipped test/domain/planner/fixture_probe_test.dart
  probe:
    skip: "Công cụ dò bàn: chạy riêng bằng flutter test --tags probe --run-skipped"
```

`test/domain/planner/fixture_probe_test.dart`:

```dart
// ignore_for_file: avoid_print
@Tags(['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

/// Không phải test: in số liệu để người dò chọn toạ độ bàn.
void main() {
  void dump(String name, TableSetup setup) {
    final c = contextFor(setup);
    print('== $name: lỗ ${c.geometry.pocket.name}, góc ${c.geometry.angle.toStringAsFixed(1)}°');
    for (final key in tierOneKeys(c.geometry)) {
      final a = c.lookup(key);
      final why = a == null ? 'quá giờ' : rejectionOf(a, key.pocket, c.obstacles)?.name;
      final s = (a == null || why != null) ? null : scoreOption(c, key, a);
      final row = why ??
          (s == null
              ? 'không có cú cho bi sau'
              : 'băng ${a!.trace.cueRailCount} · robust ${s.robustDiff1?.toStringAsFixed(2)}'
                  ' · diff2 ${s.diff2?.toStringAsFixed(2)}'
                  ' · cách bi ảo ${(s.distance / distanceWeight).toStringAsFixed(1)} cm'
                  ' · tổng ${s.total.toStringAsFixed(2)}');
      print('  ${key.stroke.name} ${key.power.round()}%: $row');
    }
    final steps = planToEnd(setup);
    print('  kế hoạch: ${steps.map((s) => '${s.ballNum}:${s.kind.name}').join(' → ')}');
  }

  test('bảng phương án của các bàn test', () {
    dump('railTable', railTable());
    dump('cornerFollowTable', cornerFollowTable());
    dump('orderTable 9 bi', orderTable(GameType.nineBall));
    dump('orderTable 8 bi', orderTable(GameType.eightBall));
    dump('typicalNineBallTable', typicalNineBallTable());
  });

  test('lưới bàn 2 bi thoả điều kiện test 5, 7, 8', () {
    const cues = [Vec2(127, 63.5), Vec2(60, 90), Vec2(190, 40)];
    for (var bx = 30.0; bx <= 224; bx += 38) {
      for (var by = 20.0; by <= 107; by += 29) {
        for (var nx = 20.0; nx <= 234; nx += 42) {
          for (var ny = 15.0; ny <= 112; ny += 32) {
            final b1 = Vec2(bx, by), b2 = Vec2(nx, ny);
            if (b1.distanceTo(b2) < 15) continue;
            for (final cue in cues) {
              if (cue.distanceTo(b1) < 10 || cue.distanceTo(b2) < 10) continue;
              final setup = TableSetup(
                game: GameType.nineBall,
                cue: cue,
                balls: [PlacedBall(number: 1, pos: b1), PlacedBall(number: 2, pos: b2)],
              );
              // Không có cặp bi–lỗ nào thì không có gì để chấm.
              if (CandidateFinder(game: setup.game).easiest(cue, setup.balls) == null) {
                continue;
              }
              final c = contextFor(setup);
              final options = scoreTier(c, tierOneKeys(c.geometry));
              final chosen = bestOf(options);
              if (chosen == null) continue;
              final tags = <String>[
                if (options.any((a) =>
                    a.score.distance < chosen.score.distance &&
                    a.score.robustDiff1! - chosen.score.robustDiff1! >
                        (chosen.score.bank + chosen.score.tech + chosen.score.power) -
                            (a.score.bank + a.score.tech + a.score.power)))
                  'test5',
                if (chosen.key.stroke != Stroke.draw &&
                    chosen.aimed.trace.cueRailCount >= 1 &&
                    options.any((d) =>
                        d.key.stroke == Stroke.draw &&
                        d.aimed.trace.cueRailCount == 0 &&
                        d.score.position >= chosen.score.position &&
                        d.score.position - chosen.score.position <=
                            techPenaltyDraw - bankPenaltyOneRail))
                  'test7',
                if (powerCandidates.any((p) {
                  final a = c.lookup(shotKey(c.geometry, Stroke.follow, p));
                  if (a == null || a.trace.cuePocket == null) return false;
                  final there = c.next.easiest(a.trace.cueEnd, c.after)?.angle;
                  return there != null && there < chosen.score.robustDiff1!;
                }))
                  'test8',
              ];
              if (tags.isNotEmpty) {
                print('${tags.join(',')}: bi cái $cue, bi 1 $b1, bi 2 $b2, '
                    'chọn ${chosen.key.stroke.name} ${chosen.key.power.round()}%');
              }
            }
          }
        }
      }
    }
  });
}
```

Run: `"$FLUTTER" test --tags probe --run-skipped test/domain/planner/fixture_probe_test.dart --reporter expanded`

Expected:
- The first test prints, for `railTable`, `stun 45%: băng 1 · robust 21.68 … tổng 25.74` and `draw 30%: băng 0 · robust 26.21 …` (measured on c43c74a), and for `cornerFollowTable` every `follow` row reads `scratch` and `stun 90%` has the lowest total (22.64).
- The grid test prints at least one `test7` line, including `bi cái Vec2(190.0, 40.0), bi 1 Vec2(144.0, 107.0), bi 2 Vec2(146.0, 79.0)`. The grid takes several minutes.

The `kế hoạch:` line for `orderTable 9 bi` is what test 2 checks. If it shows a `safety` before four steps, move ball 2 or ball 4 in 10 cm steps away from the path that the printed steps take, and re-run until it reads `1:normal → 2:… → 3:… → 4:…` with no `safety`.

- [ ] **Step 2: Write the PRD tests**

`test/domain/planner/prd_section7_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';
import '../../support/table_layouts.dart';

/// PRD §7 — chín test bắt buộc, chạy trên lõi vật lý thật (spec mục 10.1).
/// Bàn hết đúng điều kiện sau khi chỉnh hằng số thì dò lại bằng
/// fixture_probe_test.dart, đừng nới điều kiện.
void main() {
  late Map<String, List<PlanStep>> plans;

  setUpAll(() {
    plans = {
      'order9': planToEnd(orderTable(GameType.nineBall)),
      'order8': planToEnd(orderTable(GameType.eightBall)),
      'rail': planToEnd(railTable()),
      'corner': planToEnd(cornerFollowTable()),
      'blocked': planToEnd(blockedEverywhereTable()),
      'fallback': planToEnd(fallbackTable()),
      'typical9': planToEnd(typicalNineBallTable()),
      'eightLast': planToEnd(eightLastTable()),
      'eight8': planToEnd(eightWithOpponentsTable()),
      'penultimate': planToEnd(penultimateTable()),
    };
  });

  test('1. nối liền trên mọi bàn của bộ test', () {
    for (final MapEntry(:key, :value) in plans.entries) {
      for (var i = 0; i + 1 < value.length; i++) {
        expect(identical(value[i].trace!.cueEnd, value[i + 1].cbFrom), isTrue,
            reason: '$key bước $i');
      }
    }
  });

  test('2. 9 bi đánh đúng 1 → 2 → 3 → 4 dù bi 3 dễ hơn bi 1', () {
    final s = orderTable(GameType.nineBall);
    double angleOf(int n) => bestAngleFrom(s.cue, s.balls[n - 1].pos,
        [for (final b in s.balls) if (b.number != n) b.pos])!;
    expect(angleOf(3), lessThan(angleOf(1)));
    final steps = plans['order9']!;
    expect(steps.map((x) => x.ballNum), [1, 2, 3, 4]);
    expect(steps.every((x) => x.kind != PlanStepKind.safety), isTrue);
  });

  group('3. 8 bi', () {
    test('mọi bi là của tôi: được đánh bi dễ trước', () {
      final steps = plans['order8']!;
      expect(steps.first.ballNum, 3);
      final hit = [for (final x in steps) if (x.kind != PlanStepKind.safety) x.ballNum];
      expect(hit.toSet().length, hit.length);
    });

    test('bi 8 luôn cuối, kể cả khi dễ nhất', () {
      final steps = plans['eightLast']!;
      expect(steps.first.ballNum, 2);
      for (var i = 0; i < steps.length; i++) {
        if (steps[i].ballNum != 8) continue;
        expect(steps.take(i).map((x) => x.ballNum), containsAll([1, 2]));
      }
    });

    test('không bao giờ đánh bi đối thủ', () {
      expect(plans['eight8']!.map((x) => x.ballNum), everyElement(isNot(anyOf(9, 10))));
    });

    test('bi đối thủ chắn đường vào lỗ thì cặp bi–lỗ đó bị loại', () {
      expect(planToEnd(opponentBlocksTable()).first.pocket, Pocket.bottomRight);
    });

    test('bi đối thủ trên đường bi cái sau va chạm thì phương án bị loại', () {
      final c = contextFor(railTable());
      final aimed = c.lookup(shotKey(c.geometry, Stroke.stun, 45))!;
      final onPath = aimed.trace.cueAfter[aimed.trace.cueAfter.length ~/ 2];
      expect(rejectionOf(aimed, c.geometry.pocket, [onPath]), Rejection.blocked);
    });

    test('bi áp chót được chấm theo cú bi 8', () {
      final s = plans['penultimate']!.first;
      expect(s.ballNum, 1);
      expect(s.kind, PlanStepKind.normal);
      expect(s.nextBallNum, 8);
    });
  });

  test('4. dội băng: điểm chạm nằm đúng trên biên, đường sau va chạm đi qua theo thứ tự', () {
    const table = TableSpec.nineFoot;
    final trace = plans['rail']!.first.trace!;
    final hits = [
      for (final h in trace.rails)
        if (h.ball == ShotBall.cue && h.afterContact) h.pos,
    ];
    expect(hits, isNotEmpty);
    for (final p in hits) {
      expect(p.x == table.minX || p.x == table.maxX || p.y == table.minY || p.y == table.maxY,
          isTrue,
          reason: '$p');
    }
    var from = 0;
    for (final p in hits) {
      final at = trace.cueAfter.indexOf(p, from);
      expect(at, greaterThanOrEqualTo(from), reason: '$p');
      from = at + 1;
    }
  });

  test('5. chịu sai số lực thắng gần bi kế tiếp', () {
    final c = contextFor(railTable());
    final options = scoreTier(c, tierOneKeys(c.geometry));
    final chosen = bestOf(options)!;
    double penalties(ScoredOption o) => o.score.bank + o.score.tech + o.score.power;
    // Đo trên c43c74a: Đánh đứng bi 30 % dừng cách bi ảo 10.2 cm (phương án
    // chọn 26.2 cm) nhưng chịu sai số 95° so với 21.68°.
    final closerButFragile = options.where((a) =>
        a.score.distance < chosen.score.distance &&
        a.score.robustDiff1! - chosen.score.robustDiff1! > penalties(chosen) - penalties(a));
    expect(closerButFragile, isNotEmpty);
    expect(plans['rail']!.first.stroke, chosen.key.stroke);
    expect(plans['rail']!.first.power, chosen.key.power);
  });

  test('6. bi bắt buộc bị chắn ở mọi lỗ: bước phòng thủ, kế hoạch dừng', () {
    final steps = plans['blocked']!;
    expect(steps, hasLength(1));
    expect(steps.single.kind, PlanStepKind.safety);
    expect(steps.single.ballNum, 1);
  });

  test('7. đánh thẳng kèm dội một băng thắng trô không dội băng', () {
    final c = contextFor(railTable());
    final options = scoreTier(c, tierOneKeys(c.geometry));
    final chosen = bestOf(options)!;
    expect(chosen.key.stroke, isNot(Stroke.draw));
    expect(chosen.aimed.trace.cueRailCount, greaterThanOrEqualTo(1));
    // Đo trên c43c74a: trô 30 % không chạm băng, vùng điều 26.21° so với 21.68°.
    final drawNoRail = options.where((d) =>
        d.key.stroke == Stroke.draw &&
        d.aimed.trace.cueRailCount == 0 &&
        d.score.position >= chosen.score.position &&
        d.score.position - chosen.score.position <= techPenaltyDraw - bankPenaltyOneRail);
    expect(drawNoRail, isNotEmpty);
  });

  test('8. phương án chết cái bị loại dù vị trí tốt hơn', () {
    final c = contextFor(cornerFollowTable());
    final step = plans['corner']!.first;
    expect(step.trace!.cuePocket, isNull);
    expect(step.stroke, Stroke.stun);
    for (final p in powerCandidates) {
      final a = c.lookup(shotKey(c.geometry, Stroke.follow, p))!;
      expect(rejectionOf(a, c.geometry.pocket, c.obstacles), Rejection.scratch);
      // Đo trên c43c74a: từ miệng lỗ bi 2 cắt 12.6°, phương án chọn 18.95°.
      final there = c.next.easiest(a.trace.cueEnd, c.after)!.angle;
      expect(there, lessThan(step.score!.robustDiff1!), reason: 'cu lê $p%');
    }
  });

  test('9. dư dày / mỏng: cắt mỏng nhạy hơn rõ rệt, bi cuối không lỗi', () {
    final thin = geometryFor(tableCenter, Pocket.topRight, 65);
    final thick = geometryFor(tableCenter, Pocket.topRight, 15);
    expect(missErrDeg(thin.angle), greaterThan(2 * missErrDeg(thick.angle)));
    expect(() => missSafetyAdvice(thin, const []), returnsNormally);
    final last = plans['order9']!.last;
    expect(last.missAdvice, isNull);
  });

  test('bàn 9 bi điển hình: bi 5 chắn lỗ giữa dưới nên bước 1 đi góc dưới phải', () {
    final s = plans['typical9']!.first;
    expect(s.ballNum, 1);
    expect(s.pocket, Pocket.bottomRight);
  });
}
```

- [ ] **Step 3: Run the tests**

Run: `"$FLUTTER" test test/domain/planner/prd_section7_test.dart`
Expected: all PASS on the real core. A failure in 2, 4, 5, 7 or 8 means a fixture no longer meets its condition: apply the procedure above (probe, move, update the comment and `planner.mjs`), never the assertion.

- [ ] **Step 4: Run the whole suite and the analyzer**

Run: `"$FLUTTER" test && "$FLUTTER" analyze`
Expected: all pass (the probe is skipped), `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add dart_test.yaml test/domain/planner/prd_section7_test.dart test/domain/planner/fixture_probe_test.dart
git commit -m "Run the nine PRD planner tests on the real physics core, with a probe to re-find fixtures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The planner performance test

**Files:**
- Test: `test/domain/planner/planner_perf_test.dart` (tag `perf`, skipped by default like `aim_perf_test.dart`)

**Interfaces:**
- Consumes: `PlannerJob`, `planToEnd`, `sliceBudget`, `typicalNineBallTable`, `railTable`.
- Produces: `flutter test --tags perf --run-skipped test/domain/planner/planner_perf_test.dart`. It fails if step 1 of the typical 9-ball table takes more than 500 ms on the Dart VM, or if the median slice exceeds 1.5 × `sliceBudget`. It prints the slice p95 and the longest slice.

The spec's gate is "step 1 in about 1 s on Chrome mobile emulation". The physics plan measured dart2js at roughly 2× the VM for `aimShot` (6–8 ms vs 3–4 ms), so the VM gate is half of the Chrome gate. Task 14 measures the real thing.

Measured with this plan's code on `c43c74a`:
- Step 1 took 90–100 ms on the VM (27 simulations).
- Slices had a median of 6.4 ms, a p95 of 17.6 ms and a maximum of 71 ms.

The slice p95 is not gated here because one unit of work is one `aimShot`, which cannot be split further. See Deviation 15.

- [ ] **Step 1: Write the test**

`test/domain/planner/planner_perf_test.dart`:

```dart
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';

import '../../support/planner_tables.dart';

void main() {
  test('bước 1 của bàn 9 bi điển hình ra dưới 500 ms trên Dart VM', () {
    planToEnd(railTable()); // làm nóng JIT
    final millis = <int>[];
    for (var i = 0; i < 3; i++) {
      final job = PlannerJob(typicalNineBallTable());
      final w = Stopwatch()..start();
      while (job.steps.isEmpty) {
        job.step(budget: const Duration(days: 1), maxSimulations: 1);
      }
      millis.add(w.elapsedMilliseconds);
    }
    millis.sort();
    // Chrome chậm khoảng gấp đôi VM (đo ở kế hoạch lõi vật lý): 500 ms ở
    // đây là khoảng 1 giây trên Chrome giả lập điện thoại (spec mục 10.3).
    expect(millis[1], lessThan(500), reason: '$millis');
  });

  test('lát điển hình giữ quanh sliceBudget; in p95 và lát dài nhất', () {
    planToEnd(railTable());
    final job = PlannerJob(typicalNineBallTable());
    final micros = <int>[];
    while (!job.isDone) {
      final w = Stopwatch()..start();
      job.step();
      micros.add(w.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2] / 1000;
    final p95 = micros[((micros.length - 1) * 0.95).floor()] / 1000;
    // Một đơn vị việc là một lần aimShot, không chia nhỏ được nữa: lần dài
    // nhất đo được 47 ms trên VM (c43c74a). Nên chỉ gác trung vị ở đây; p95
    // in ra để ghi vào nhật ký, cổng khung hình thật nằm ở planner.mjs.
    // ignore: avoid_print
    print('lát: trung vị $median ms, p95 $p95 ms, dài nhất ${micros.last / 1000} ms, '
        '${micros.length} lát');
    expect(median, lessThan(sliceBudget.inMicroseconds / 1000 * 1.5));
  });
}
```

- [ ] **Step 2: Run it alone**

Run: `"$FLUTTER" test --tags perf --run-skipped test/domain/planner/planner_perf_test.dart`
Expected: PASS. Copy the printed `lát: …` line and the first test's three times (add `printOnFailure` or a temporary `print`) into the Task 14 log.

If the first test fails, stop and report the three times to the controller. Do not optimise on your own. The candidate fixes, for the owner to choose:
- skip the look-ahead simulation for options whose `robustDiff1` already exceeds the best total so far;
- compute tolerance lazily, when the step is first viewed.

- [ ] **Step 3: Confirm the default run skips it**

Run: `"$FLUTTER" test test/domain/planner`
Expected: PASS, with the perf and probe tests reported as skipped.

- [ ] **Step 4: Commit**

```bash
git add test/domain/planner/planner_perf_test.dart
git commit -m "Measure the planner's first step and slice length on the Dart VM

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Planner strings, the step's info lines, and no degree advice on screen

**Files:**
- Modify: `lib/core/strings/vi.dart` (append a `plan*` section before the closing brace of `Vi`; add four imports)
- Modify: `lib/features/training/presentation/simulator/info_lines.dart` (`_squirtLine` → public `squirtLine`)
- Create: `lib/features/training/presentation/planner/step_lines.dart`
- Test: `test/core/strings/vi_planner_test.dart`, `test/features/training/planner_step_lines_test.dart`

**Interfaces:**
- Consumes: `PlanStep`, `PlanStepKind`, `MissSide`, `GameType`, `BallGroup`, `BallRole`, constants (Tasks 3–6); `Vi.simPocketLine`, `Vi.simAngleLine`, `Vi.simStrokeLine`, `Vi.simPowerLine`, `Vi.simSpinLine`, `Vi.simPocket`, `Vi.simStroke` (existing).
- Produces:
  - `String squirtLine(SideSpin spin, AimedShot? aimed, ShotGeometry geometry, TableSpec table, Stroke stroke, double power)` (the simulator's áp phê + SAWS line, unchanged behaviour)
  - `List<String> planStepLines(PlanStep step, {required int index, required int total, TableSpec table = TableSpec.nineFoot})`
  - in `Vi`: `planTitle`, `planCardBody`, `planGameLabel`, `planGame(GameType)`, `planGroupLabel`, `planGroup(BallGroup)`, `planPlacingLabel`, `planPlacing(BallRole)`, `planCueHint`, `planOrderHint`, `planUndo`, `planClear`, `planStart`, `planComputing(int step, int total)`, `planStepHeader(int step, int total)`, `planBallLine(int)`, `planTolerance(int good, int samples)`, `planRailInfo(int)`, `planRiskWarning`, `planMissAdvice(MissSide)`, `planNoPosition`, `planSafety`, `planPreviewLabel`, `planBack`, `planShotDone`, `planFinish`, `planEditTable`, `planCueStoppedQuestion`, `planYes`, `planResetCue`, `planResetHint`, `planRecompute`, `planLegend` (getter, `List<String>`), `planSetupSummary({required bool hasCue, required int balls})`, `planSummary(PlanStep? step, {required int index, required int total})`, `planResetSummary`.

- [ ] **Step 1: Write the failing tests**

`test/core/strings/vi_planner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/table_layouts.dart';

void main() {
  test('thuật ngữ đã chốt với chủ sản phẩm (05/10)', () {
    expect(Vi.planTitle, 'Kế hoạch dọn bàn');
    expect(Vi.planGroup(BallGroup.solids), 'Trơn');
    expect(Vi.planGroup(BallGroup.stripes), 'Sọc');
    expect(GameType.values.map(Vi.planGame), ['9 bi', '10 bi', '8 bi']);
    expect(BallRole.values.map(Vi.planPlacing), ['Bi của tôi', 'Bi đối thủ', 'Bi 8']);
  });

  test('câu có số là khuôn, số do lõi điền', () {
    expect(Vi.planComputing(3, 9), 'Đang tính bước 3/9…');
    expect(Vi.planStepHeader(3, 9), 'Bước 3 / 9');
    expect(Vi.planBallLine(7), 'Bi 7');
    expect(Vi.planTolerance(6, 7), '6/7 mức lực vẫn trong vùng điều tốt');
  });

  test('dội băng là thông tin, không còn vế 15%', () {
    expect(Vi.planRailInfo(2), 'Bi cái chạm băng 2 lần rồi tới vùng điều.');
    expect(Vi.planRailInfo(2), isNot(contains('15%')));
  });

  test('câu PRD giữ nguyên văn', () {
    expect(Vi.planRiskWarning,
        'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái hoặc sai số lớn hơn bình thường.');
    expect(Vi.planMissAdvice(MissSide.thick),
        'Nếu trượt: nên đánh dư dày một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planMissAdvice(MissSide.thin),
        'Nếu trượt: nên đánh dư mỏng một chút — bi sẽ khó cho đối thủ hơn.');
    expect(Vi.planNoPosition, 'Không có vị trí tốt cho bi sau.');
    expect(Vi.planSafety, 'Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ.');
    expect(Vi.planCueStoppedQuestion, 'Bi cái dừng đúng chỗ dự kiến?');
    expect(Vi.planOrderHint, 'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…');
  });

  test('chú giải lấy ngưỡng từ hằng số, không viết tay', () {
    final legend = Vi.planLegend.join('\n');
    expect(legend, contains('≤ ${zoneGood.round()}°'));
    expect(legend, contains('≤ ${zoneFair.round()}°'));
    expect(legend, contains('±${powerJitter.round()}%'));
  });

  test('nhãn semantics tóm tắt bước đang xem', () {
    final g = geometryFor(tableCenter, Pocket.topRight, 20);
    final step = PlanStep(
        kind: PlanStepKind.normal,
        cbFrom: g.cue,
        ballNum: 3,
        geometry: g,
        stroke: Stroke.draw,
        power: 60);
    expect(Vi.planSummary(step, index: 1, total: 5),
        'Bàn kế hoạch. Bước 2 / 5: bi 3, lỗ góc trên phải, Đánh trô bi, lực 60%.');
    expect(Vi.planSummary(const PlanStep.safety(cbFrom: Vec2(1, 1), ballNum: 2), index: 0, total: 1),
        'Bàn kế hoạch. Bước 1 / 1: Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ.');
    expect(Vi.planSummary(null, index: 0, total: 9), 'Bàn kế hoạch. Đang tính bước 1/9…');
    expect(Vi.planSetupSummary(hasCue: false, balls: 0), 'Bàn bày bi. Chưa đặt bi cái.');
    expect(Vi.planSetupSummary(hasCue: true, balls: 3), 'Bàn bày bi. Đã đặt bi cái, 3 bi mục tiêu.');
  });
}
```

`test/features/training/planner_step_lines_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

import '../../support/planner_tables.dart';

void main() {
  const table = TableSpec.nineFoot;
  final rail = planToEnd(railTable());
  final corner = planToEnd(cornerFollowTable());
  final fallback = planToEnd(fallbackTable());
  final ball1 = railTable().balls.first.pos;
  final spin = planToEnd(railTable(),
      aim: scratchingAim((object, _, s, _) => object == ball1 && s.isNone));

  List<String> linesOf(List<PlanStep> plan, int i) =>
      planStepLines(plan[i], index: i, total: plan.length);

  test('bước thường: bi, lỗ, góc cắt, kiểu đánh, lực, rồi sai số, dội băng, nếu trượt', () {
    final s = rail.first;
    final lines = linesOf(rail, 0);
    expect(lines.take(6), [
      Vi.planStepHeader(1, rail.length),
      Vi.planBallLine(1),
      Vi.simPocketLine(s.pocket!),
      Vi.simAngleLine(s.cutAngle!),
      Vi.simStrokeLine(s.stroke),
      Vi.simPowerLine(s.power),
    ]);
    expect(lines, contains(Vi.planTolerance(s.tolerance!.good, toleranceSamples)));
    expect(lines, contains(Vi.planRailInfo(s.trace!.cueRailCount)));
    expect(lines, contains(Vi.planMissAdvice(s.missAdvice!.safer)));
    expect(lines, isNot(contains(Vi.planNoPosition)));
  });

  test('bi cuối: không có dòng sai số lực và nếu trượt', () {
    final lines = linesOf(rail, rail.length - 1);
    expect(rail.last.tolerance, isNull);
    for (var good = 0; good <= toleranceSamples; good++) {
      expect(lines, isNot(contains(Vi.planTolerance(good, toleranceSamples))));
    }
    for (final side in MissSide.values) {
      expect(lines, isNot(contains(Vi.planMissAdvice(side))));
    }
  });

  test('cảnh báo khi lực từ riskPower hoặc dùng trô, không thì không', () {
    expect(corner.first.power, greaterThanOrEqualTo(riskPower));
    expect(linesOf(corner, 0), contains(Vi.planRiskWarning));
    final s = rail.first;
    PlanStep as(Stroke stroke, double power) => PlanStep(
        kind: s.kind,
        cbFrom: s.cbFrom,
        ballNum: s.ballNum,
        geometry: s.geometry,
        stroke: stroke,
        power: power,
        aimed: s.aimed);
    expect(planStepLines(as(Stroke.draw, 45), index: 0, total: 2), contains(Vi.planRiskWarning));
    expect(planStepLines(as(Stroke.stun, 45), index: 0, total: 2),
        isNot(contains(Vi.planRiskWarning)));
  });

  test('áp phê: đúng dòng của màn mô phỏng (đầu cơ, phần con bi, SAWS)', () {
    final s = spin.first;
    expect(s.spin.isNone, isFalse);
    final lines = linesOf(spin, 0);
    expect(lines, contains(Vi.simSpinLine(s.spin)));
    expect(lines, contains(squirtLine(s.spin, s.aimed, s.geometry!, table, s.stroke, s.power)));
  });

  test('bước dự phòng và bước phòng thủ', () {
    expect(linesOf(fallback, 0), contains(Vi.planNoPosition));
    expect(linesOf(fallback, 1), [Vi.planStepHeader(2, 2), Vi.planBallLine(2), Vi.planSafety]);
  });

  test('không câu nào là lời khuyên ngắm theo độ (memory: lời khuyên làm được)', () {
    final aimInDegrees = RegExp(r'ngắm[^.°]*\d+(?:[.,]\d+)?\s*°|(?:dày|mỏng) hơn\s*\d',
        caseSensitive: false);
    final plans = [
      rail,
      corner,
      fallback,
      spin,
      planToEnd(orderTable(GameType.nineBall)),
      planToEnd(eightWithOpponentsTable()),
    ];
    for (final plan in plans) {
      for (var i = 0; i < plan.length; i++) {
        final shown = [
          ...linesOf(plan, i),
          Vi.planSummary(plan[i], index: i, total: plan.length),
        ];
        for (final line in shown) {
          expect(line, isNot(matches(aimInDegrees)), reason: line);
          final offset = plan[i].aimed?.aimOffsetDeg;
          if (offset != null && offset.abs() >= 0.05) {
            expect(line, isNot(contains('${offset.abs().toStringAsFixed(1)}°')), reason: line);
          }
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/core/strings/vi_planner_test.dart test/features/training/planner_step_lines_test.dart`
Expected: FAIL to compile, `The getter 'planTitle' isn't defined for the type 'Vi'` and `Error when reading '…/planner/step_lines.dart'`.

- [ ] **Step 3: Make `squirtLine` public**

In `info_lines.dart`, rename the private function and its one call:

```bash
sed -i 's/\b_squirtLine(/squirtLine(/g' lib/features/training/presentation/simulator/info_lines.dart
```

Then replace its doc comment's first line (`/// Dòng áp phê. Độ lệch điểm ngắm là bề ngang hướng cơ đã bù xê dịch so với`) with these two lines, keeping the rest of the comment:

```dart
/// Dòng áp phê — màn Mô phỏng góc cắt và màn Kế hoạch dọn bàn dùng chung,
/// không viết lại (spec 2026-10-07 mục 7.2). Độ lệch điểm ngắm là bề ngang hướng cơ đã bù xê dịch so với
```

- [ ] **Step 4: Add the strings**

In `lib/core/strings/vi.dart`, add these imports with the others:

```dart
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
```

and append before the final `}` of `Vi`:

```dart
  // Kế hoạch dọn bàn — docs/superpowers/specs/2026-10-07-poolcoachai-run-out-planner-design.md.
  // Câu nào có số thì số do lõi planner tính ra; ở đây chỉ ghép chữ.
  static const planTitle = 'Kế hoạch dọn bàn';
  static const planCardBody = 'Bày bàn, xem cách dọn hết bi từng bước.';
  static const planGameLabel = 'Loại bàn';
  static const planGroupLabel = 'Nhóm của tôi';
  static const planPlacingLabel = 'Đang đặt';

  static String planGame(GameType game) => switch (game) {
        GameType.nineBall => '9 bi',
        GameType.tenBall => '10 bi',
        GameType.eightBall => '8 bi',
      };

  static String planGroup(BallGroup group) => switch (group) {
        BallGroup.solids => 'Trơn',
        BallGroup.stripes => 'Sọc',
      };

  static String planPlacing(BallRole role) => switch (role) {
        BallRole.mine => 'Bi của tôi',
        BallRole.opponent => 'Bi đối thủ',
        BallRole.eight => 'Bi 8',
      };

  static const planCueHint = 'Chạm lên bàn để đặt bi cái trước.';

  /// PRD §6.2: số bi gán theo thứ tự chạm.
  static const planOrderHint = 'Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…';
  static const planUndo = 'Xoá bi cuối';
  static const planClear = 'Xoá hết';
  static const planStart = 'Lập kế hoạch';

  static String planComputing(int step, int total) => 'Đang tính bước $step/$total…';
  static String planStepHeader(int step, int total) => 'Bước $step / $total';
  static String planBallLine(int number) => 'Bi $number';

  /// Số mức lực (trong [samples] mức) mà điểm dừng vẫn trong vùng điều tốt.
  static String planTolerance(int good, int samples) =>
      '$good/$samples mức lực vẫn trong vùng điều tốt';

  /// Thông tin, không phải cảnh báo. Không còn vế "hao khoảng 15% lực":
  /// lõi vật lý tính hao lực thật (spec quyết định 7).
  static String planRailInfo(int count) => 'Bi cái chạm băng $count lần rồi tới vùng điều.';

  /// PRD §6.5, nguyên văn.
  static const planRiskWarning = 'Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái '
      'hoặc sai số lớn hơn bình thường.';

  static String planMissAdvice(MissSide side) =>
      'Nếu trượt: nên đánh dư ${side == MissSide.thick ? 'dày' : 'mỏng'} một chút — '
      'bi sẽ khó cho đối thủ hơn.';

  static const planNoPosition = 'Không có vị trí tốt cho bi sau.';
  static const planSafety = 'Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ.';
  static const planPreviewLabel = 'XEM TRƯỚC';
  static const planBack = '← Quay lại';
  static const planShotDone = 'Đã đánh xong → Bi tiếp theo';
  static const planFinish = 'Xong bàn';
  static const planEditTable = 'Sửa bàn';
  static const planCueStoppedQuestion = 'Bi cái dừng đúng chỗ dự kiến?';
  static const planYes = 'Đúng';
  static const planResetCue = 'Đặt lại bi cái';
  static const planResetHint = 'Kéo bi cái tới đúng chỗ nó dừng ngoài bàn.';
  static const planRecompute = 'Tính lại từ đây';

  /// Chú giải các lớp trên bàn (spec mục 7.1). Ngưỡng lấy từ hằng số planner.
  static List<String> get planLegend => [
        'Ô xanh: vùng điều tốt — từ đây góc cắt bi sau ≤ ${zoneGood.round()}°.',
        'Ô vàng: tạm được — góc cắt bi sau ≤ ${zoneFair.round()}°.',
        'Nét đứt trắng: bi cái tới bi mục tiêu. Nét đứt ngọc: bi cái sau va chạm.',
        'Chấm vàng: bi cái chạm băng. Vòng trắng nét đứt: chỗ bi cái dừng.',
        'Thanh vàng: chỗ bi cái dừng nếu lực lệch ±${powerJitter.round()}%.',
        'Hai chấm cam: bi mục tiêu trôi tới đâu nếu trượt (dư dày / dư mỏng); '
            'chấm đặc là hướng nên chọn.',
      ];

  /// Nhãn semantics của bàn khi bày bi — E2E đọc từ đây.
  static String planSetupSummary({required bool hasCue, required int balls}) => hasCue
      ? 'Bàn bày bi. Đã đặt bi cái, $balls bi mục tiêu.'
      : 'Bàn bày bi. Chưa đặt bi cái.';

  static const planResetSummary = 'Bàn kế hoạch. Đang đặt lại bi cái.';

  /// Nhãn semantics của bàn ở màn từng bước (spec mục 7.4): bi, lỗ, kiểu
  /// đánh, lực của bước đang xem. [step] null khi bước đầu còn đang tính.
  static String planSummary(PlanStep? step, {required int index, required int total}) {
    const head = 'Bàn kế hoạch.';
    if (step == null) return '$head ${planComputing(index + 1, total)}';
    final at = planStepHeader(index + 1, total);
    if (step.kind == PlanStepKind.safety) return '$head $at: $planSafety';
    return '$head $at: bi ${step.ballNum}, lỗ ${simPocket(step.pocket!)}, '
        '${simStroke(step.stroke)}, lực ${step.power.round()}%.';
  }
```

- [ ] **Step 5: Write `step_lines.dart`**

```dart
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';

/// Các dòng của bảng thông tin một bước (spec mục 7.2).
///
/// Hàm thuần, tách khỏi widget để test thẳng. Mọi số lấy từ [step]; dòng
/// áp phê dùng chung [squirtLine] của màn mô phỏng. Không dòng nào nói độ
/// lệch ngắm: `aimOffsetDeg` chỉ dùng bên trong.
List<String> planStepLines(PlanStep step,
    {required int index, required int total, TableSpec table = TableSpec.nineFoot}) {
  final header = Vi.planStepHeader(index + 1, total);
  if (step.kind == PlanStepKind.safety) {
    return [
      header,
      if (step.ballNum case final n?) Vi.planBallLine(n),
      Vi.planSafety,
    ];
  }
  final g = step.geometry!;
  final trace = step.trace!;
  return [
    header,
    Vi.planBallLine(step.ballNum!),
    Vi.simPocketLine(g.pocket),
    Vi.simAngleLine(g.angle),
    Vi.simStrokeLine(step.stroke),
    Vi.simPowerLine(step.power),
    if (!step.spin.isNone) ...[
      Vi.simSpinLine(step.spin),
      squirtLine(step.spin, step.aimed, g, table, step.stroke, step.power),
    ],
    if (step.tolerance case final t?) Vi.planTolerance(t.good, toleranceSamples),
    if (trace.cueRailCount > 0) Vi.planRailInfo(trace.cueRailCount),
    if (step.power >= riskPower || step.stroke == Stroke.draw) Vi.planRiskWarning,
    if (step.missAdvice case final m?) Vi.planMissAdvice(m.safer),
    if (step.kind == PlanStepKind.fallback) Vi.planNoPosition,
  ];
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/core/strings test/features/training && "$FLUTTER" analyze`
Expected: PASS (the simulator's info-line tests still pass after the rename), `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/core/strings/vi.dart lib/features/training/presentation/simulator/info_lines.dart lib/features/training/presentation/planner/step_lines.dart test/core/strings/vi_planner_test.dart test/features/training/planner_step_lines_test.dart
git commit -m "Add the planner's strings and step lines, reusing the simulator's áp phê line and showing no aim in degrees

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Shared table drawing, ball separation, ball colours, and the setup draft

**Files:**
- Create: `lib/features/training/presentation/simulator/table_drawing.dart`
- Modify: `lib/features/training/presentation/simulator/table_painter.dart` (use the shared drawing, re-export `TableLayout`)
- Create: `lib/domain/table_geometry/separate.dart`
- Modify: `lib/features/training/presentation/simulator/simulator_screen.dart` (`separate` delegates)
- Create: `lib/features/training/presentation/planner/ball_colors.dart`, `lib/features/training/presentation/planner/setup_editing.dart`
- Test: `test/domain/table_geometry/separate_test.dart`, `test/features/training/planner_setup_editing_test.dart`

**Interfaces:**
- Consumes: `TableSpec`, `Vec2`, `AppColors`, `legalTargetsAmong`, `PlacedBall`, `TableSetup`, `GameType`, `BallGroup`, `BallRole`.
- Produces:
  - `class TableLayout` (moved; same API: `TableLayout({required Size size, TableSpec table})`, `frame`, `aspectRatio`, `scale`, `toCanvas`, `toTable`), still importable from `table_painter.dart`
  - `const pocketDrawRadius`, `dashLength`, `dashGap`; `void drawTableBed(Canvas canvas, TableLayout layout, {Pocket? selected, Pocket? danger, Pocket? risk})`, `void drawPolyline(Canvas canvas, List<Offset> points, Paint paint)`, `void drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint, double scale)`, `void drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint)`
  - `Vec2 separateBalls(Vec2 p, Vec2 other, Vec2 previous, {TableSpec table = TableSpec.nineFoot})`, `Vec2? separateFromAll(Vec2 p, List<Vec2> others, {TableSpec table = TableSpec.nineFoot})`
  - `Color ballColor(int number)`, `bool isStripe(int number)`
  - `class DraftBall { const DraftBall(Vec2 pos, BallRole role); }`, `int ballLimit(GameType game)`
  - `class SetupDraft { const SetupDraft({GameType game = GameType.nineBall, BallGroup group = BallGroup.solids, BallRole placing = BallRole.mine, Vec2? cue, List<DraftBall> placed = const [], TableSpec table = TableSpec.nineFoot}); List<(int, PlacedBall)> get numbered; List<PlacedBall> get balls; bool get canPlan; TableSetup toSetup(); SetupDraft tap(Vec2 p); SetupDraft move(int index, Vec2 p); SetupDraft moveCue(Vec2 p); SetupDraft undo(); SetupDraft clear(); SetupDraft withGame(GameType g); SetupDraft withGroup(BallGroup g); SetupDraft withPlacing(BallRole r); int? ballAt(Vec2 p, double grab); }`

- [ ] **Step 1: Write the failing tests**

`test/domain/table_geometry/separate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/table_geometry/separate.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

void main() {
  const table = TableSpec.nineFoot;

  test('không chồng thì giữ nguyên chỗ (đã kẹp vào biên)', () {
    expect(separateFromAll(const Vec2(50, 50), const [Vec2(80, 50)]), const Vec2(50, 50));
    expect(separateFromAll(const Vec2(-5, 300), const []), table.clamp(const Vec2(-5, 300)));
  });

  test('thả giữa hai bi sát nhau thì ra chỗ không chạm bi nào', () {
    const others = [Vec2(100, 50), Vec2(106, 50)];
    final p = separateFromAll(const Vec2(103, 51), others)!;
    for (final o in others) {
      expect(p.distanceTo(o), greaterThanOrEqualTo(table.ballDiameter));
    }
    expect(table.contains(p), isTrue);
  });

  test('separateBalls giữ đúng hành vi cũ của màn mô phỏng', () {
    final p = separateBalls(const Vec2(101, 50), const Vec2(100, 50), const Vec2(90, 50));
    expect(p.distanceTo(const Vec2(100, 50)), greaterThanOrEqualTo(table.ballDiameter));
  });
}
```

`test/features/training/planner_setup_editing_test.dart`:

```dart
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/table_geometry/separate_test.dart test/features/training/planner_setup_editing_test.dart`
Expected: FAIL to compile, `Error when reading 'lib/domain/table_geometry/separate.dart'`.

- [ ] **Step 3: Write `separate.dart` and make the simulator delegate**

`lib/domain/table_geometry/separate.dart` — the body of `SimulatorScreen.separate` moved verbatim, plus the many-ball wrapper:

```dart
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Thả đè lên bi kia thì đẩy về vừa chạm nhau.
///
/// Đẩy xa hơn đúng một đường kính một chút: đặt đúng `D` thì sai số
/// làm tròn có thể cho ra 5.7149999 và lõi báo hai bi chồng nhau.
///
/// Sát băng thì hướng đẩy có thể chỉ ra ngoài bàn, kẹp lại là chồng tiếp.
/// Khi đó thử trượt dọc theo băng (đẩy theo từng trục, về phía điểm thả);
/// không cách nào tách được thì giữ [previous] — bi không nhảy.
Vec2 separateBalls(Vec2 p, Vec2 other, Vec2 previous,
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

/// Tách [p] khỏi mọi bi [others] (màn Kế hoạch dọn bàn có tới 16 bi): đẩy
/// khỏi bi chồng đầu tiên, lặp tới khi hết chồng. null khi không cách nào
/// tách được — chỗ chạm bị bi vây kín, không đặt bi.
Vec2? separateFromAll(Vec2 p, List<Vec2> others, {TableSpec table = TableSpec.nineFoot}) {
  var q = table.clamp(p);
  for (var round = 0; round <= others.length; round++) {
    final hit = others.where((o) => q.distanceTo(o) < table.ballDiameter).firstOrNull;
    if (hit == null) return q;
    q = separateBalls(q, hit, q, table: table);
  }
  return null;
}
```

In `simulator_screen.dart`, replace the body of `static Vec2 separate(...)` (keep its doc comment and `@visibleForTesting`) with a delegation, and import `package:poolcoachai/domain/table_geometry/separate.dart`:

```dart
  @visibleForTesting
  static Vec2 separate(Vec2 p, Vec2 other, Vec2 previous,
          {TableSpec table = TableSpec.nineFoot}) =>
      separateBalls(p, other, previous, table: table);
```

- [ ] **Step 4: Extract the table drawing**

Create `lib/features/training/presentation/simulator/table_drawing.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Quy đổi giữa cm trên mặt bàn và pixel trên canvas.
///
/// Màn mô phỏng, màn Kế hoạch dọn bàn và test dùng chung lớp này, nên test
/// chạm đúng chỗ màn vẽ.
class TableLayout {
  const TableLayout({required this.size, this.table = TableSpec.nineFoot});

  /// Khung băng vẽ quanh mặt chơi, cm.
  static const frame = 8.0;

  static double aspectRatio(TableSpec table) =>
      (table.length + 2 * frame) / (table.width + 2 * frame);

  final Size size;
  final TableSpec table;

  double get scale => size.width / (table.length + 2 * frame);

  Offset toCanvas(Vec2 p) => Offset((p.x + frame) * scale, (p.y + frame) * scale);

  Vec2 toTable(Offset o) => Vec2(o.dx / scale - frame, o.dy / scale - frame);
}

const pocketDrawRadius = 5.5; // cm
const dashLength = 2.0; // cm
const dashGap = 1.5; // cm

/// Băng, mặt bàn và sáu lỗ: [selected] viền vàng, [danger] tô đỏ (chết cái),
/// [risk] vòng nét đứt (nguy cơ chết cái khi dư lực).
void drawTableBed(Canvas canvas, TableLayout layout,
    {Pocket? selected, Pocket? danger, Pocket? risk}) {
  final table = layout.table;
  final s = layout.scale;
  canvas.drawRect(Offset.zero & layout.size, Paint()..color = AppColors.tableRail);
  canvas.drawRect(
    Rect.fromPoints(
      layout.toCanvas(Vec2.zero),
      layout.toCanvas(Vec2(table.length, table.width)),
    ),
    Paint()..color = AppColors.tableFelt,
  );
  for (final pocket in Pocket.values) {
    final c = layout.toCanvas(table.pocketPosition(pocket));
    final r = pocketDrawRadius * s;
    canvas.drawCircle(
        c, r, Paint()..color = pocket == danger ? AppColors.danger : AppColors.bgDeep);
    if (pocket == selected) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent,
      );
    }
    if (pocket == risk) {
      drawDashedCircle(
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
}

void drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length < 2) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint..style = PaintingStyle.stroke);
}

/// Nét đứt theo chuỗi điểm; [scale] là px/cm để nét đứt đều theo cm.
void drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint, double scale) {
  final dash = dashLength * scale;
  final gap = dashGap * scale;
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

void drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
  const parts = 16;
  const sweep = 2 * math.pi / parts;
  final rect = Rect.fromCircle(center: center, radius: radius);
  for (var i = 0; i < parts; i += 2) {
    canvas.drawArc(rect, i * sweep, sweep, false, paint);
  }
}
```

Then edit `table_painter.dart`:
1. Delete the whole `class TableLayout { … }` block (with its doc comment). Add, after the imports:

```dart
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

export 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart'
    show TableLayout;
```

2. In `TablePainter.paint`, replace the two `canvas.drawRect(...)` calls and the whole `for (final pocket in Pocket.values) { … }` loop with:

```dart
    drawTableBed(canvas, layout,
        selected: scene.pocket, danger: trace?.cuePocket, risk: scene.riskPocket);
```

3. Delete the three private methods `_polyline`, `_dashedPolyline`, `_dashedCircle` and the constants `_pocketDrawRadius`, `_dash`, `_gap`. Then point the calls at the shared functions:

```bash
f=lib/features/training/presentation/simulator/table_painter.dart
sed -i 's/\b_polyline(/drawPolyline(/g; s/\b_dashedPolyline(/drawDashedPolyline(/g; s/\b_dashedCircle(/drawDashedCircle(/g' "$f"
grep -n "_polyline\|_dashed\|_pocketDrawRadius\|class TableLayout" "$f" || echo "sạch"
```

Expected: `sạch`. Remove any import the analyzer now reports unused in `table_painter.dart` (likely `dart:math`).

- [ ] **Step 5: Write `ball_colors.dart` and `setup_editing.dart`**

`lib/features/training/presentation/planner/ball_colors.dart`:

```dart
import 'package:flutter/painting.dart';

/// Màu bi thật của bộ bi chuẩn: 1 vàng, 2 xanh dương, 3 đỏ, 4 tím, 5 cam,
/// 6 xanh lá, 7 nâu đỏ, 8 đen. Bi 9–15 là bi sọc cùng màu với số trừ 8
/// (bi 10 của 10 bi là sọc xanh dương).
const _solidColors = <Color>[
  Color(0xFFF4C430),
  Color(0xFF1F4FB4),
  Color(0xFFD03030),
  Color(0xFF6B2E8F),
  Color(0xFFF07F1A),
  Color(0xFF1E8A4C),
  Color(0xFF7A1F1F),
  Color(0xFF111111),
];

Color ballColor(int number) => _solidColors[(number > 8 ? number - 8 : number) - 1];

bool isStripe(int number) => number > 8;
```

`lib/features/training/presentation/planner/setup_editing.dart`:

```dart
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
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test && "$FLUTTER" analyze`
Expected: all pass. The simulator's painter, layout and `separate` tests must stay green; they guard the extraction. The analyzer must print `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/table_geometry/separate.dart lib/features/training/presentation/simulator lib/features/training/presentation/planner test/domain/table_geometry/separate_test.dart test/features/training/planner_setup_editing_test.dart
git commit -m "Share the simulator's table drawing and ball separation, and add the planner's setup draft

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: The steps view — painter, panel, navigation, and the re-placed cue ball

**Files:**
- Create: `lib/features/training/presentation/planner/planner_painter.dart`, `lib/features/training/presentation/planner/planner_layout.dart`, `lib/features/training/presentation/planner/planner_steps_view.dart`
- Test: `test/features/training/planner_steps_view_test.dart`

**Interfaces:**
- Consumes: `PlannerJob`, `StepReady`, `PlanDone`, `PlanStep`, `CandidateFinder`, `zoneGrid`, `ZoneCell`, `ZoneLevel`, `TableSetup`, `PlacedBall`, `separateFromAll`, `planStepLines`, `Vi.plan*`, `TableLayout`, `drawTableBed`, `drawPolyline`, `drawDashedPolyline`, `drawDashedCircle`, `ballColor`, `isStripe`, `AimShotFn`, `aimShot`, `PcCard`.
- Produces:
  - `class PlannerScene { const PlannerScene({Vec2? cue, List<PlacedBall> balls = const [], PlanStep? step, PlanStep? preview, List<ZoneCell> zone = const []}); }`
  - `class PlannerPainter extends CustomPainter { PlannerPainter(PlannerScene scene); final PlannerScene scene; }`
  - `void drawPoolBall(Canvas canvas, Offset center, double radius, int number)`, `class DashedBorderPainter extends CustomPainter { const DashedBorderPainter(); }`
  - `class PlannerTableLayout extends StatelessWidget { const PlannerTableLayout({required TableSpec table, required Widget Function(TableLayout layout) tableBuilder, required Widget panel}); }`
  - `class PlannerStepsView extends StatefulWidget { const PlannerStepsView({required TableSetup setup, required VoidCallback onEditTable, AimShotFn aim = aimShot, int? maxSimulationsPerFrame}); static const tableKey, shotDoneKey, backKey; }`

- [ ] **Step 1: Write the failing tests**

`test/features/training/planner_steps_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/planner_tables.dart';

/// Màn từng bước (spec mục 7). Kế hoạch mong đợi lấy từ chính lõi
/// (planToEnd, tất định), không viết tay.
void main() {
  const table = TableSpec.nineFoot;
  late int edits;

  Future<void> open(WidgetTester tester, TableSetup setup, {int? maxSimulationsPerFrame}) async {
    edits = 0;
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: PlannerStepsView(
          setup: setup,
          onEditTable: () => edits++,
          maxSimulationsPerFrame: maxSimulationsPerFrame,
        ),
      ),
    ));
  }

  PlannerScene sceneOf(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(PlannerStepsView.tableKey), matching: find.byType(CustomPaint)))
          .painter! as PlannerPainter)
      .scene;

  Offset onTable(WidgetTester tester, Vec2 p) {
    final box = find.byKey(PlannerStepsView.tableKey);
    final layout = TableLayout(size: tester.getSize(box));
    return tester.getTopLeft(box) + layout.toCanvas(p);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('bước 1 hiện khi xong, các bước sau tính tiếp với dòng Đang tính bước X/N',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall), maxSimulationsPerFrame: 1);
    expect(find.text(Vi.planComputing(1, 4)), findsOneWidget);
    for (var i = 0; i < 5000 && find.text(Vi.planStepHeader(1, 4)).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(find.text(Vi.planStepHeader(1, 4)), findsOneWidget);
    expect(find.text(Vi.planComputing(2, 4)), findsOneWidget);
    // Bước cuối đã tính: Đã đánh xong chờ bước kế tiếp.
    expect(tester.widget<FilledButton>(find.byKey(PlannerStepsView.shotDoneKey)).onPressed,
        isNull);

    await tester.pumpAndSettle();
    final steps = planToEnd(orderTable(GameType.nineBall));
    expect(find.text(Vi.planComputing(steps.length + 1, 4)), findsNothing);
    expect(find.text(Vi.planComputing(2, 4)), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(PlannerStepsView.shotDoneKey)).onPressed,
        isNotNull);
  });

  testWidgets('chỉ vẽ tối đa 3 bi, bi cái ở cbFrom, bước kế tiếp để xem trước', (tester) async {
    final steps = planToEnd(orderTable(GameType.nineBall));
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    final scene = sceneOf(tester);
    expect(scene.balls.map((b) => b.number), steps.take(3).map((s) => s.ballNum));
    expect(scene.cue, steps.first.cbFrom);
    expect(scene.step!.ballNum, steps.first.ballNum);
    expect(scene.preview!.ballNum, steps[1].ballNum);
    expect(scene.zone, isNotEmpty);
    expect(find.text(Vi.planPreviewLabel), findsOneWidget);
  });

  testWidgets('Quay lại không xuống dưới bước 1; Đã đánh xong → Đúng thì sang bước sau',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(PlannerStepsView.backKey)).onPressed, isNull);

    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planCueStoppedQuestion), findsOneWidget);
    await tapText(tester, Vi.planYes);
    expect(find.text(Vi.planStepHeader(2, 4)), findsOneWidget);

    await tester.tap(find.byKey(PlannerStepsView.backKey));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planStepHeader(1, 4)), findsOneWidget);
  });

  testWidgets('bước cuối: nút đổi thành Xong bàn; bước phòng thủ nói nên phòng thủ',
      (tester) async {
    await open(tester, blockedEverywhereTable());
    await tester.pumpAndSettle();
    expect(find.text(Vi.planStepHeader(1, 1)), findsOneWidget);
    expect(find.text(Vi.planSafety), findsOneWidget);
    expect(find.text(Vi.planFinish), findsOneWidget);
    expect(find.byKey(PlannerStepsView.shotDoneKey), findsNothing);
  });

  testWidgets('bước dự phòng nói không có vị trí tốt cho bi sau', (tester) async {
    await open(tester, fallbackTable());
    await tester.pumpAndSettle();
    expect(find.text(Vi.planNoPosition), findsOneWidget);
  });

  testWidgets('Đặt lại bi cái: kéo tới chỗ dừng thật, Tính lại từ đây với các bi còn lại',
      (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planResetCue);
    expect(find.text(Vi.planResetHint), findsOneWidget);

    const target = Vec2(100, 50);
    final from = onTable(tester, const Vec2(150, 30));
    await tester.dragFrom(from, onTable(tester, target) - from);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).cue!.distanceTo(target), lessThan(0.5));

    await tapText(tester, Vi.planRecompute);
    expect(find.text(Vi.planStepHeader(1, 3)), findsOneWidget);
    final scene = sceneOf(tester);
    expect(scene.step!.ballNum, 2);
    expect(scene.cue!.distanceTo(target), lessThan(0.5));
  });

  testWidgets('kéo bi cái đè lên bi khác thì bị đẩy ra', (tester) async {
    await open(tester, orderTable(GameType.nineBall));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlannerStepsView.shotDoneKey));
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planResetCue);
    const ball2 = Vec2(60, 40);
    final from = onTable(tester, const Vec2(150, 30));
    await tester.dragFrom(from, onTable(tester, ball2) - from);
    await tester.pumpAndSettle();
    expect(sceneOf(tester).cue!.distanceTo(ball2),
        greaterThanOrEqualTo(table.ballDiameter - 1e-6));
  });

  testWidgets('Sửa bàn gọi về màn nhập bàn', (tester) async {
    await open(tester, railTable());
    await tester.pumpAndSettle();
    await tapText(tester, Vi.planEditTable);
    expect(edits, 1);
  });

  testWidgets('rời màn giữa lúc đang tính: không lỗi, việc tính bị hủy', (tester) async {
    await open(tester, typicalNineBallTable(), maxSimulationsPerFrame: 1);
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bàn có nhãn semantics tóm tắt bước đang xem', (tester) async {
    final handle = tester.ensureSemantics();
    final steps = planToEnd(railTable());
    await open(tester, railTable());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(Vi.planSummary(steps.first, index: 0, total: steps.length)),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('chú giải và disclaimer luôn hiện', (tester) async {
    await open(tester, railTable());
    await tester.pumpAndSettle();
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
    for (final line in Vi.planLegend) {
      expect(find.text(line), findsOneWidget);
    }
  });

  test('painter vẽ lại khi cảnh đổi', () {
    const a = PlannerScene(cue: Vec2(10, 10));
    const b = PlannerScene(cue: Vec2(20, 10));
    expect(PlannerPainter(b).shouldRepaint(PlannerPainter(a)), isTrue);
    expect(PlannerPainter(a).shouldRepaint(PlannerPainter(a)), isFalse);
    expect(PlanStepKind.values, hasLength(3));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/features/training/planner_steps_view_test.dart`
Expected: FAIL to compile, `Error when reading '…/planner/planner_steps_view.dart'`.

- [ ] **Step 3: Write `planner_painter.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/planner/miss_advice.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';
import 'package:poolcoachai/features/training/presentation/planner/ball_colors.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Mọi thứ cần vẽ của một khung hình màn Kế hoạch dọn bàn — đã tính xong.
class PlannerScene {
  const PlannerScene({
    this.cue,
    this.balls = const [],
    this.step,
    this.preview,
    this.zone = const [],
  });

  /// null khi chưa đặt bi cái (màn nhập bàn).
  final Vec2? cue;
  final List<PlacedBall> balls;

  /// Bước đang xem: vẽ đủ lớp.
  final PlanStep? step;

  /// Bước kế tiếp: vẽ mờ để xem trước.
  final PlanStep? preview;
  final List<ZoneCell> zone;
}

/// Vẽ bàn theo spec 2026-10-07 mục 7.1, từ dưới lên. Mọi đường cong là
/// chuỗi điểm của mô phỏng — không vẽ đường cong tự chế.
class PlannerPainter extends CustomPainter {
  PlannerPainter(this.scene);

  final PlannerScene scene;

  static const _previewAlpha = 0.45;
  static const _zoneAlpha = 0.22;
  static const _railDot = 1.2; // cm
  static const _missDot = 1.4; // cm
  static const _jitterWidth = 1.2; // cm
  static const _jitterEnd = 0.8; // cm

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TableLayout(size: size);
    final s = layout.scale;
    final step = scene.step;
    drawTableBed(canvas, layout, selected: step?.pocket, danger: step?.trace?.cuePocket);

    // 1. Vùng điều, dưới cùng: không che bi hay đường.
    for (final cell in scene.zone) {
      final color = cell.level == ZoneLevel.good ? AppColors.success : AppColors.warning;
      canvas.drawRect(
        Rect.fromCenter(
            center: layout.toCanvas(cell.center), width: zoneCell * s, height: zoneCell * s),
        Paint()..color = color.withValues(alpha: _zoneAlpha),
      );
    }

    final preview = scene.preview;
    if (preview != null) _shot(canvas, layout, preview, alpha: _previewAlpha, full: false);
    if (step != null) _shot(canvas, layout, step, alpha: 1, full: true);

    final r = layout.table.radius * s;
    for (final b in scene.balls) {
      drawPoolBall(canvas, layout.toCanvas(b.pos), r, b.number);
    }
    final cue = scene.cue;
    if (cue != null) {
      canvas.drawCircle(layout.toCanvas(cue), r, Paint()..color = AppColors.ballCue);
    }
  }

  void _shot(Canvas canvas, TableLayout layout, PlanStep step,
      {required double alpha, required bool full}) {
    final trace = step.trace;
    final g = step.geometry;
    if (trace == null || g == null) return;
    final s = layout.scale;
    final r = layout.table.radius * s;
    List<Offset> px(List<Vec2> pts) => [for (final p in pts) layout.toCanvas(p)];

    // 2. Đường ngắm, bi ảo, đường bi mục tiêu vào lỗ (lỗ đã chọn có vòng vàng).
    canvas.drawLine(
      layout.toCanvas(step.cbFrom),
      layout.toCanvas(g.ghost),
      Paint()
        ..color = AppColors.aimLine.withValues(alpha: 0.35 * alpha)
        ..strokeWidth = 1,
    );
    if (full) {
      drawDashedCircle(
        canvas,
        layout.toCanvas(trace.contactCue ?? g.ghost),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.aimLine,
      );
    }
    drawPolyline(
      canvas,
      px(trace.objectPath),
      Paint()
        ..color = AppColors.textSecondary.withValues(alpha: alpha)
        ..strokeWidth = 1.5,
    );

    // 3. Bi cái đúng từ mô phỏng: trước va chạm nét đứt trắng, sau va chạm
    // nét đứt ngọc — cong chỗ cong.
    drawDashedPolyline(
      canvas,
      px(trace.cueBefore),
      Paint()
        ..color = AppColors.aimLine.withValues(alpha: alpha)
        ..strokeWidth = 1.5,
      s,
    );
    drawDashedPolyline(
      canvas,
      px(trace.cueAfter),
      Paint()
        ..color = AppColors.cuePath.withValues(alpha: alpha)
        ..strokeWidth = 2,
      s,
    );
    if (!full) return;

    for (final hit in trace.rails) {
      if (hit.ball != ShotBall.cue || !hit.afterContact) continue;
      canvas.drawCircle(
          layout.toCanvas(hit.pos), _railDot * s, Paint()..color = AppColors.railHit);
    }
    if (trace.cuePocket == null) {
      drawDashedCircle(
        canvas,
        layout.toCanvas(trace.cueEnd),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.ballCue,
      );
    }

    // 4. Thanh sai số lực: nối điểm dừng ±15 % qua điểm dừng chuẩn.
    final ends = step.jitterEnds;
    if (ends != null) {
      final bar = Paint()
        ..color = AppColors.railHit.withValues(alpha: 0.8)
        ..strokeWidth = _jitterWidth * s
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final end in [ends.minus, ends.plus]) {
        if (end == null) continue;
        canvas.drawLine(layout.toCanvas(trace.cueEnd), layout.toCanvas(end), bar);
        canvas.drawCircle(
            layout.toCanvas(end), _jitterEnd * s, Paint()..color = AppColors.railHit);
      }
    }

    // 5. Hai điểm "nếu trượt", chấm đặc là hướng được khuyên.
    final miss = step.missAdvice;
    if (miss != null) {
      for (final side in MissSide.values) {
        canvas.drawCircle(
          layout.toCanvas(side == MissSide.thick ? miss.thick : miss.thin),
          _missDot * s,
          Paint()
            ..color = AppColors.warning
            ..strokeWidth = 1.5
            ..style = side == miss.safer ? PaintingStyle.fill : PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PlannerPainter oldDelegate) => oldDelegate.scene != scene;
}

/// Bi đúng màu bi thật, có số (spec mục 6).
void drawPoolBall(Canvas canvas, Offset center, double radius, int number) {
  final color = ballColor(number);
  if (isStripe(number)) {
    canvas.drawCircle(center, radius, Paint()..color = AppColors.ballCue);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawRect(
        Rect.fromCenter(center: center, width: 2 * radius, height: 1.1 * radius),
        Paint()..color = color);
    canvas.restore();
  } else {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }
  canvas.drawCircle(center, radius * 0.55, Paint()..color = AppColors.ballCue);
  final label = TextPainter(
    text: TextSpan(
      text: '$number',
      style: TextStyle(
          color: const Color(0xFF111111), fontSize: radius * 0.8, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
}

/// Viền đứt cho ô XEM TRƯỚC.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    drawDashedPolyline(
      canvas,
      [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft, r.topLeft],
      Paint()
        ..color = AppColors.borderStrong
        ..strokeWidth = 1,
      3,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Write `planner_layout.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Bàn ở trên, tối đa 55% chiều cao thân màn, phần còn lại cuộn được —
/// cùng cách chia của màn mô phỏng, để Chrome desktop không tràn và kéo dọc
/// trên bàn là kéo bi chứ không cuộn trang.
class PlannerTableLayout extends StatelessWidget {
  const PlannerTableLayout({
    required this.table,
    required this.tableBuilder,
    required this.panel,
    super.key,
  });

  final TableSpec table;
  final Widget Function(TableLayout layout) tableBuilder;
  final Widget panel;

  static const _padding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, body) {
        final aspectRatio = TableLayout.aspectRatio(table);
        final availableWidth =
            (body.maxWidth - _padding.horizontal).clamp(0.0, double.infinity);
        final maxHeight =
            (body.maxHeight * 0.55 - _padding.vertical).clamp(0.0, double.infinity);
        final widthLimited = availableWidth / aspectRatio;
        final height = widthLimited < maxHeight ? widthLimited : maxHeight;
        return Column(
          children: [
            Padding(
              padding: _padding,
              child: Center(
                child: SizedBox(
                  width: height * aspectRatio,
                  height: height,
                  child: LayoutBuilder(
                    builder: (context, c) =>
                        tableBuilder(TableLayout(size: c.biggest, table: table)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 5: Write `planner_steps_view.dart`**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/plan_step.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/separate.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_layout.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/step_lines.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Màn từng bước — spec 2026-10-07 mục 7.
///
/// Tính từng bước giữa các khung hình (cùng cách gợi ý chống chết cái của
/// màn mô phỏng): bước 1 hiện ngay khi xong, các bước sau tính tiếp.
class PlannerStepsView extends StatefulWidget {
  const PlannerStepsView({
    required this.setup,
    required this.onEditTable,
    this.aim = aimShot,
    this.maxSimulationsPerFrame,
    super.key,
  });

  static const tableKey = Key('planner-steps-table');
  static const shotDoneKey = Key('planner-shot-done');
  static const backKey = Key('planner-back');

  final TableSetup setup;

  /// *Sửa bàn*: về màn nhập bàn, giữ nguyên các bi.
  final VoidCallback onEditTable;

  /// Lõi dò và mô phỏng; test thay để ép lõi quá giờ.
  @visibleForTesting
  final AimShotFn aim;

  /// Giới hạn số lần mô phỏng mỗi khung hình, để test thấy được lúc kế
  /// hoạch mới tính xong một phần. null là theo `sliceBudget`.
  @visibleForTesting
  final int? maxSimulationsPerFrame;

  @override
  State<PlannerStepsView> createState() => _PlannerStepsViewState();
}

class _PlannerStepsViewState extends State<PlannerStepsView> {
  late TableSetup _planned;
  late CandidateFinder _finder;
  PlannerJob? _job;
  List<PlanStep> _steps = const [];
  bool _done = false;
  int _view = 0;

  /// Đang đặt lại bi cái: chỗ bi cái đang kéo tới; null khi không.
  Vec2? _resetCue;
  final _zones = <int, List<ZoneCell>>{};

  @override
  void initState() {
    super.initState();
    _start(widget.setup);
  }

  @override
  void dispose() {
    _job?.cancel();
    _job = null;
    super.dispose();
  }

  /// Kế hoạch mới cho [setup]: bỏ việc tính cũ, bắt đầu lại từ bước 1.
  void _start(TableSetup setup) {
    _job?.cancel();
    final job = PlannerJob(setup, aim: widget.aim);
    _planned = setup;
    _finder = CandidateFinder(game: setup.game, table: setup.table);
    _job = job;
    _steps = const [];
    _done = false;
    _view = 0;
    _resetCue = null;
    _zones.clear();
    _schedule(job);
  }

  void _schedule(PlannerJob job) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => _pump(job));
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pump(PlannerJob job) {
    // Rời màn, sửa bàn hay tính lại từ chỗ mới: bỏ việc cũ.
    if (!mounted || !identical(job, _job)) return;
    final events = job.step(maxSimulations: widget.maxSimulationsPerFrame);
    if (events.isNotEmpty) {
      setState(() {
        for (final e in events) {
          switch (e) {
            case StepReady(:final step):
              _steps = [..._steps, step];
            case PlanDone():
              _done = true;
          }
        }
      });
    }
    if (!job.isDone) _schedule(job);
  }

  int get _total => _done ? _steps.length : (_job?.totalSteps ?? _steps.length);

  /// Bi còn trên bàn trước bước [index].
  List<PlacedBall> _ballsBefore(int index) {
    final gone = {for (final s in _steps.take(index)) ?s.ballNum};
    return [for (final b in _planned.balls) if (!gone.contains(b.number)) b];
  }

  PlacedBall _ball(int number) => _planned.balls.firstWhere((b) => b.number == number);

  /// Vùng điều của bước [index], tính một lần rồi nhớ.
  List<ZoneCell> _zoneFor(int index) {
    if (_steps[index].nextBallNum == null) return const [];
    return _zones.putIfAbsent(
        index, () => zoneGrid(after: _ballsBefore(index + 1), next: _finder));
  }

  PlannerScene _scene() {
    final reset = _resetCue;
    if (reset != null) return PlannerScene(cue: reset, balls: _ballsBefore(_view + 1));
    if (_steps.isEmpty) return PlannerScene(cue: _planned.cue, balls: _planned.balls);
    final step = _steps[_view];
    return PlannerScene(
      cue: step.cbFrom,
      // Chỉ bi của bước đang xem và 2 bước kế tiếp (PRD §6.3).
      balls: [
        for (final s in _steps.skip(_view).take(3))
          if (s.ballNum case final n?) _ball(n),
      ],
      step: step,
      preview: _view + 1 < _steps.length ? _steps[_view + 1] : null,
      zone: _zoneFor(_view),
    );
  }

  Future<void> _askCueStopped() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Vi.planCueStoppedQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Vi.planResetCue),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Vi.planYes),
          ),
        ],
      ),
    );
    if (!mounted || reset == null) return;
    setState(() {
      if (reset) {
        _resetCue = _steps[_view].trace!.cueEnd;
      } else {
        _view++;
      }
    });
  }

  void _dragCue(Offset local, TableLayout layout) {
    final at = separateFromAll(
      layout.toTable(local),
      [for (final b in _ballsBefore(_view + 1)) b.pos],
      table: _planned.table,
    );
    if (at != null) setState(() => _resetCue = at);
  }

  /// Kế hoạch mới từ chỗ bi cái dừng thật, với các bi còn lại (spec 4.5).
  void _recompute() {
    final cue = _resetCue!;
    final pocketed = {for (final s in _steps.take(_view + 1)) ?s.ballNum};
    setState(() => _start(_planned.without(pocketed).withCue(cue)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scene = _scene();
    final resetting = _resetCue != null;
    final step = _steps.isEmpty ? null : _steps[_view];
    final atEnd = _done && _view == _steps.length - 1;

    return PlannerTableLayout(
      table: _planned.table,
      tableBuilder: (layout) => Semantics(
        label: resetting
            ? Vi.planResetSummary
            : Vi.planSummary(step, index: step == null ? _steps.length : _view, total: _total),
        child: GestureDetector(
          key: PlannerStepsView.tableKey,
          dragStartBehavior: DragStartBehavior.down,
          onPanUpdate: resetting ? (d) => _dragCue(d.localPosition, layout) : null,
          child: CustomPaint(size: layout.size, painter: PlannerPainter(scene)),
        ),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_done) Text(Vi.planComputing(_steps.length + 1, _total), style: text.bodyMedium),
          if (step != null && !resetting)
            _LinesCard(
                lines: planStepLines(step, index: _view, total: _total, table: _planned.table)),
          if (scene.preview case final preview?)
            _PreviewCard(
                lines: planStepLines(preview,
                    index: _view + 1, total: _total, table: _planned.table)),
          const SizedBox(height: 8),
          if (resetting) Text(Vi.planResetHint, style: text.bodySmall),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: PlannerStepsView.backKey,
                onPressed: _view > 0 && !resetting ? () => setState(() => _view--) : null,
                child: const Text(Vi.planBack),
              ),
              if (resetting)
                FilledButton(onPressed: _recompute, child: const Text(Vi.planRecompute))
              else if (atEnd)
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(Vi.planFinish),
                )
              else
                FilledButton(
                  key: PlannerStepsView.shotDoneKey,
                  // Bước cuối đã tính mà kế hoạch chưa xong: chờ bước kế tiếp.
                  onPressed: _view + 1 < _steps.length ? _askCueStopped : null,
                  child: const Text(Vi.planShotDone),
                ),
              TextButton(onPressed: widget.onEditTable, child: const Text(Vi.planEditTable)),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in Vi.planLegend) Text(line, style: text.bodySmall),
          const SizedBox(height: 12),
          Text(Vi.simDisclaimer, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return PcCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bước kế tiếp: viền đứt, nhạt hơn (PRD §6.4).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Opacity(
        opacity: 0.6,
        child: CustomPaint(
          painter: const DashedBorderPainter(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Vi.planPreviewLabel, style: theme.labelSmall),
                for (final l in lines) Text(l, style: theme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/features/training/planner_steps_view_test.dart && "$FLUTTER" analyze`
Expected: PASS, `No issues found!`. The architecture test's Vietnamese-literal rule passes because every string comes from `Vi`. These tests passed against `c43c74a` with this plan's code while the plan was written.

- [ ] **Step 7: Commit**

```bash
git add lib/features/training/presentation/planner test/features/training/planner_steps_view_test.dart
git commit -m "Add the planner's step-by-step view with the simulated cue path, preview and re-placed cue ball

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: The setup view, `PlannerScreen`, the route and the Luyện tập card

**Files:**
- Create: `lib/features/training/presentation/planner/planner_setup_view.dart`, `lib/features/training/presentation/planner/planner_screen.dart`
- Modify: `lib/core/router/routes.dart` (add `planner`, add to `all` after `simulator`), `lib/core/router/app_router.dart` (route under `training`), `lib/features/training/presentation/training_screen.dart` (card under the simulator card)
- Test: `test/features/training/planner_screen_test.dart`; modify `test/smoke/all_routes_test.dart`, `test/core/router/routes_test.dart`, `test/features/training/training_screen_test.dart`

**Interfaces:**
- Consumes: `SetupDraft`, `PlannerStepsView`, `PlannerTableLayout`, `PlannerPainter`, `PlannerScene`, `TableLayout`, `Vi.plan*`, `PcRootScaffold`, `PcCard`, `Routes`.
- Produces:
  - `Routes.planner = '$training/planner'`, included in `Routes.all` right after `Routes.simulator`
  - `class PlannerSetupView extends StatefulWidget { const PlannerSetupView({required SetupDraft draft, required ValueChanged<SetupDraft> onChanged, required VoidCallback onPlan}); static const tableKey, planKey; }`
  - `class PlannerScreen extends StatefulWidget { const PlannerScreen({AimShotFn aim = aimShot, SetupDraft initialDraft = const SetupDraft(), int? maxSimulationsPerFrame}); }`

- [ ] **Step 1: Write the failing tests**

`test/features/training/planner_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_theme.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_setup_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_painter.dart';

import '../../support/test_data.dart';

/// Màn nhập bàn (spec mục 6) và việc chuyển qua lại với màn từng bước.
void main() {
  Future<void> open(WidgetTester tester, {SetupDraft draft = const SetupDraft()}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: PlannerScreen(initialDraft: draft),
    ));
    await tester.pumpAndSettle();
  }

  Offset onTable(WidgetTester tester, Vec2 p) {
    final box = find.byKey(PlannerSetupView.tableKey);
    final layout = TableLayout(size: tester.getSize(box));
    return tester.getTopLeft(box) + layout.toCanvas(p);
  }

  PlannerScene setupScene(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(PlannerSetupView.tableKey), matching: find.byType(CustomPaint)))
          .painter! as PlannerPainter)
      .scene;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  bool planEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(PlannerSetupView.planKey)).onPressed != null;

  testWidgets('mở từ router: màn nhập bàn, Lập kế hoạch tắt khi chưa có bi', (tester) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    final container = testContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    await tester.pumpAndSettle();
    router.go(Routes.planner);
    await tester.pumpAndSettle();

    expect(find.byType(PlannerScreen), findsOneWidget);
    expect(find.text(Vi.planTitle), findsWidgets);
    expect(find.text(Vi.planCueHint), findsOneWidget);
    expect(planEnabled(tester), isFalse);
    expect(find.text(Vi.simDisclaimer), findsOneWidget);
  });

  testWidgets('chạm đặt bi cái rồi bi theo thứ tự số; đủ bi thì Lập kế hoạch bật',
      (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await tester.tapAt(onTable(tester, const Vec2(190, 40)));
    await tester.pumpAndSettle();
    expect(find.text(Vi.planOrderHint), findsOneWidget);
    expect(planEnabled(tester), isFalse);

    // Dựng lại giữa hai lần chạm: bàn đọc draft của lần dựng gần nhất.
    await tester.tapAt(onTable(tester, const Vec2(144, 107)));
    await tester.pump();
    await tester.tapAt(onTable(tester, const Vec2(146, 79)));
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.map((b) => b.number), [1, 2]);
    expect(find.bySemanticsLabel(Vi.planSetupSummary(hasCue: true, balls: 2)), findsOneWidget);
    expect(planEnabled(tester), isTrue);
    handle.dispose();
  });

  testWidgets('8 bi: hiện Nhóm của tôi và Đang đặt, bi đối thủ lấy số nhóm kia',
      (tester) async {
    await open(tester, draft: const SetupDraft().tap(const Vec2(40, 100)));
    expect(find.text(Vi.planGroup(BallGroup.solids)), findsNothing);
    await tapText(tester, Vi.planGame(GameType.eightBall));
    expect(find.text(Vi.planGroup(BallGroup.solids)), findsOneWidget);
    expect(find.text(Vi.planPlacing(BallRole.opponent)), findsOneWidget);

    await tapText(tester, Vi.planPlacing(BallRole.opponent));
    await tester.tapAt(onTable(tester, const Vec2(120, 60)));
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.single.number, 9);
    // Chỉ có bi đối thủ: chưa lập kế hoạch được.
    expect(planEnabled(tester), isFalse);
  });

  testWidgets('Lập kế hoạch sang màn từng bước; Sửa bàn về lại, giữ nguyên bi', (tester) async {
    final draft = const SetupDraft()
        .tap(const Vec2(190, 40))
        .tap(const Vec2(144, 107))
        .tap(const Vec2(146, 79));
    await open(tester, draft: draft);
    await tester.tap(find.byKey(PlannerSetupView.planKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlannerStepsView), findsOneWidget);
    expect(find.text(Vi.planStepHeader(1, 2)), findsOneWidget);

    await tapText(tester, Vi.planEditTable);
    expect(find.byType(PlannerSetupView), findsOneWidget);
    expect(setupScene(tester).balls.map((b) => b.pos), draft.balls.map((b) => b.pos));

    // Đổi loại bàn: không còn kế hoạch nào, bi vẫn ở chỗ cũ.
    await tapText(tester, Vi.planGame(GameType.tenBall));
    expect(find.byType(PlannerStepsView), findsNothing);
    expect(setupScene(tester).balls.map((b) => b.pos), draft.balls.map((b) => b.pos));
  });

  testWidgets('kéo bi để chỉnh vị trí; Xoá bi cuối và Xoá hết', (tester) async {
    final draft = const SetupDraft().tap(const Vec2(40, 100)).tap(const Vec2(120, 60));
    await open(tester, draft: draft);
    final from = onTable(tester, const Vec2(120, 60));
    await tester.dragFrom(from, onTable(tester, const Vec2(160, 70)) - from);
    await tester.pumpAndSettle();
    expect(setupScene(tester).balls.single.pos.distanceTo(const Vec2(160, 70)), lessThan(0.5));

    await tapText(tester, Vi.planUndo);
    expect(setupScene(tester).balls, isEmpty);
    expect(setupScene(tester).cue, isNotNull);
    await tapText(tester, Vi.planClear);
    expect(setupScene(tester).cue, isNull);
  });
}
```

Modify `test/smoke/all_routes_test.dart`: add `import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';` and, after the `Routes.simulator` entry of `_routeCases`:

```dart
  Routes.planner: (path: Routes.planner, screen: PlannerScreen),
```

Modify `test/core/router/routes_test.dart`: in the `'all gom đủ …'` expectation, add `Routes.planner,` right after `Routes.simulator,`, and extend the group with:

```dart
    test('Kế hoạch dọn bàn nằm trong nhánh Luyện tập', () {
      expect(Routes.planner, '${Routes.training}/planner');
    });
```

Modify `test/features/training/training_screen_test.dart`: add `import 'package:poolcoachai/features/training/presentation/planner/planner_screen.dart';` and after `'thẻ Mô phỏng góc cắt mở đúng màn'`:

```dart
  testWidgets('thẻ Kế hoạch dọn bàn nằm ngay dưới thẻ mô phỏng và mở đúng màn', (tester) async {
    await openTraining(tester, const []);

    expect(tester.getTopLeft(find.text(Vi.planTitle)).dy,
        greaterThan(tester.getTopLeft(find.text(Vi.simTitle)).dy));
    await tester.tap(find.text(Vi.planTitle));
    await tester.pumpAndSettle();

    expect(find.byType(PlannerScreen), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/features/training/planner_screen_test.dart test/smoke test/core/router test/features/training/training_screen_test.dart`
Expected: FAIL to compile, `Member not found: 'planner'` and `Error when reading '…/planner/planner_screen.dart'`.

- [ ] **Step 3: Add the route and the card**

In `lib/core/router/routes.dart`, after `simulator`:

```dart
  /// Kế hoạch dọn bàn — trong nhánh Luyện tập như màn mô phỏng.
  static const planner = '$training/planner';
```

and in `all`, after `simulator,`:

```dart
    planner,
```

In `lib/core/router/app_router.dart`, import `package:poolcoachai/features/training/presentation/planner/planner_screen.dart` and add after the `'simulator'` `GoRoute`:

```dart
                GoRoute(
                  path: 'planner',
                  builder: (context, state) => const PlannerScreen(),
                ),
```

In `lib/features/training/presentation/training_screen.dart`, add right after the simulator card's `Padding(...)` in the `Column` children:

```dart
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: PcCard(
              child: ListTile(
                leading: const Icon(Icons.route),
                title: const Text(Vi.planTitle),
                subtitle: const Text(Vi.planCardBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.planner),
              ),
            ),
          ),
```

- [ ] **Step 4: Write `planner_setup_view.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_layout.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Màn nhập bàn — spec 2026-10-07 mục 6. Bàn là [draft] của màn cha, nên
/// *Sửa bàn* quay lại thấy nguyên các bi.
class PlannerSetupView extends StatefulWidget {
  const PlannerSetupView({
    required this.draft,
    required this.onChanged,
    required this.onPlan,
    super.key,
  });

  static const tableKey = Key('planner-setup-table');
  static const planKey = Key('planner-plan');

  final SetupDraft draft;
  final ValueChanged<SetupDraft> onChanged;
  final VoidCallback onPlan;

  @override
  State<PlannerSetupView> createState() => _PlannerSetupViewState();
}

class _PlannerSetupViewState extends State<PlannerSetupView> {
  /// Chạm trong 1.5 bán kính quanh tâm bi là bắt được bi, và không dưới
  /// 24 px — cùng luật với màn mô phỏng.
  static const _grabRadii = 1.5;
  static const _minTouchPx = 24.0;

  bool _draggingCue = false;
  int? _dragging;

  double _grab(TableLayout layout) =>
      math.max(widget.draft.table.radius * _grabRadii, _minTouchPx / layout.scale);

  void _onPanStart(DragStartDetails d, TableLayout layout) {
    final p = layout.toTable(d.localPosition);
    final draft = widget.draft;
    final grab = _grab(layout);
    final cue = draft.cue;
    final ball = draft.ballAt(p, grab);
    final toCue = cue == null ? double.infinity : p.distanceTo(cue);
    final toBall = ball == null ? double.infinity : p.distanceTo(draft.placed[ball].pos);
    if (toCue <= grab && toCue <= toBall) {
      _draggingCue = true;
    } else if (ball != null) {
      _dragging = ball;
    }
  }

  void _onPanUpdate(DragUpdateDetails d, TableLayout layout) {
    final p = layout.toTable(d.localPosition);
    if (_draggingCue) {
      widget.onChanged(widget.draft.moveCue(p));
    } else if (_dragging case final i?) {
      widget.onChanged(widget.draft.move(i, p));
    }
  }

  void _onPanEnd() {
    _draggingCue = false;
    _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final text = Theme.of(context).textTheme;

    Widget chips<T>(String label, List<T> values, T selected, String Function(T) name,
            ValueChanged<T> onPick) =>
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

    return PlannerTableLayout(
      table: draft.table,
      tableBuilder: (layout) => Semantics(
        label: Vi.planSetupSummary(hasCue: draft.cue != null, balls: draft.balls.length),
        child: GestureDetector(
          key: PlannerSetupView.tableKey,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => widget.onChanged(draft.tap(layout.toTable(d.localPosition))),
          onPanStart: (d) => _onPanStart(d, layout),
          onPanUpdate: (d) => _onPanUpdate(d, layout),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: CustomPaint(
            size: layout.size,
            painter: PlannerPainter(PlannerScene(cue: draft.cue, balls: draft.balls)),
          ),
        ),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips(Vi.planGameLabel, GameType.values, draft.game, Vi.planGame,
              (g) => widget.onChanged(draft.withGame(g))),
          if (draft.game == GameType.eightBall) ...[
            chips(Vi.planGroupLabel, BallGroup.values, draft.group, Vi.planGroup,
                (g) => widget.onChanged(draft.withGroup(g))),
            chips(Vi.planPlacingLabel, BallRole.values, draft.placing, Vi.planPlacing,
                (r) => widget.onChanged(draft.withPlacing(r))),
          ],
          const SizedBox(height: 12),
          if (draft.cue == null)
            Text(Vi.planCueHint, style: text.bodySmall)
          else if (draft.game != GameType.eightBall)
            Text(Vi.planOrderHint, style: text.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: draft.cue == null ? null : () => widget.onChanged(draft.undo()),
                child: const Text(Vi.planUndo),
              ),
              OutlinedButton(
                onPressed: draft.cue == null ? null : () => widget.onChanged(draft.clear()),
                child: const Text(Vi.planClear),
              ),
              FilledButton(
                key: PlannerSetupView.planKey,
                onPressed: draft.canPlan ? widget.onPlan : null,
                child: const Text(Vi.planStart),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(Vi.simDisclaimer, style: text.bodySmall),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write `planner_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_setup_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_steps_view.dart';
import 'package:poolcoachai/features/training/presentation/planner/setup_editing.dart';

/// Kế hoạch dọn bàn — spec 2026-10-07 mục 6–7. Một đường dẫn, hai màn: nhập
/// bàn và từng bước. State cục bộ: không có gì để lưu (lưu bàn đã bày nằm
/// ngoài phạm vi), rời màn là mất.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    this.aim = aimShot,
    this.initialDraft = const SetupDraft(),
    this.maxSimulationsPerFrame,
  });

  @visibleForTesting
  final AimShotFn aim;

  @visibleForTesting
  final SetupDraft initialDraft;

  @visibleForTesting
  final int? maxSimulationsPerFrame;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late SetupDraft _draft = widget.initialDraft;

  /// Bàn đang lập kế hoạch; null khi ở màn nhập bàn. Về màn nhập bàn là
  /// bỏ kế hoạch (màn từng bước hủy việc tính khi bị gỡ).
  TableSetup? _planned;

  @override
  Widget build(BuildContext context) {
    final planned = _planned;
    return PcRootScaffold(
      title: Vi.planTitle,
      body: planned == null
          ? PlannerSetupView(
              draft: _draft,
              onChanged: (d) => setState(() => _draft = d),
              onPlan: () => setState(() => _planned = _draft.toSetup()),
            )
          : PlannerStepsView(
              key: ObjectKey(planned),
              setup: planned,
              aim: widget.aim,
              maxSimulationsPerFrame: widget.maxSimulationsPerFrame,
              onEditTable: () => setState(() => _planned = null),
            ),
    );
  }
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test && "$FLUTTER" analyze`
Expected: all pass, including the smoke grid, which now opens `/training/planner`. The analyzer must print `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/core/router lib/features/training test/features/training test/smoke test/core/router
git commit -m "Add the planner's setup view, screen, route and the card under the simulator in Luyện tập

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Amend `PRD_RunOutPlanner.md` (spec §9)

**Files:**
- Modify: `PRD_RunOutPlanner.md`

**Interfaces:**
- Consumes: the decisions in spec §2 and §9.
- Produces: the PRD with each amendment marked *(sửa 2026-10-07: Kế hoạch dọn bàn)*. No code depends on it.

Each step below replaces one exact passage, using the Edit tool. Every replacement ends with the marker.

- [ ] **Step 1: §1 — feature name**

Replace `Tính năng này mở rộng thành **Run-out Planner**: nhập toàn bộ bố cục bàn,` with:

```markdown
Tính năng này mở rộng thành **Kế hoạch dọn bàn** (Run-out Planner) *(sửa 2026-10-07: Kế hoạch dọn bàn)*: nhập toàn bộ bố cục bàn,
```

- [ ] **Step 2: §2 — 8-ball by the real rules**

Replace the row `| 8-bi | Không ràng buộc thứ tự — ở mỗi bước, chọn trong tất cả bi còn lại cú đánh có góc cắt khả thi dễ nhất. |` with:

```markdown
| 8-bi | Theo luật thật: người chơi chọn nhóm **Trơn** (1–7) hoặc **Sọc** (9–15). Ở mỗi bước, chọn trong các bi của mình cú đánh có góc cắt khả thi dễ nhất; bi đối thủ là bi chắn; **bi 8 luôn đánh cuối**, chỉ khi hết bi của mình. Khi còn đúng một bi của mình, bi kế tiếp là bi 8, nên bi áp chót được chấm theo độ dễ của cú bi 8 *(sửa 2026-10-07: Kế hoạch dọn bàn)*. |
```

- [ ] **Step 3: §4 — `PlanStep` fields**

Replace the line `  aimOffsetDeg: number;             // ngắm dày(+)/mỏng(−) hơn bi ảo hình học để bù ném (sửa 2026-10-02)` with:

```typescript
  aimOffsetDeg: number;             // ngắm dày(+)/mỏng(−) hơn bi ảo hình học để bù ném (sửa 2026-10-02)
                                    // chỉ dùng bên trong, không bao giờ hiện lên màn (sửa 2026-10-07: Kế hoạch dọn bàn)
```

Replace the line `  message?: string;                 // chỉ có khi safety = true` with:

```typescript
  message?: string;                 // chỉ có khi safety = true
  // (sửa 2026-10-07: Kế hoạch dọn bàn)
  kind: 'normal' | 'fallback' | 'safety'; // fallback = Đánh đứng bi 30%, không có vị trí tốt; safety = phòng thủ, kế hoạch dừng
  spin: { side: 'left' | 'right' | null; tips: 0 | 0.5 | 1 }; // áp phê, chỉ khác 0 khi phải dùng đường lui áp phê
  sawsBhePercent: number | null;    // chỉ có khi dùng áp phê (bảng SAWS)
  jitterEnds: { minus: {x:number,y:number} | null; plus: {x:number,y:number} | null }; // điểm dừng ở lực −15% / +15% (kẹp ≤ 100%)
  tolerance: { good: number; fair: number; bad: number } | null; // 7 mức lực trong ±15%; null khi là bi cuối
```

- [ ] **Step 4: §5.1 — 8-ball candidate**

Replace `- **8-bi**: bi hiện tại = bi có góc cắt khả thi dễ nhất trong TẤT CẢ bi còn lại (tìm kiếm toàn bộ tổ hợp bi × lỗ).` with:

```markdown
- **8-bi**: bi hiện tại = bi có góc cắt khả thi dễ nhất trong các bi **của mình** còn lại (tìm kiếm toàn bộ tổ hợp bi × lỗ); bi đối thủ và bi 8 (khi chưa tới lượt) là bi chắn; hết bi của mình thì tới bi 8 *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
```

- [ ] **Step 5: §5.3 — side-spin penalty and the fallback order**

Replace this line:

```markdown
Nếu KHÔNG tổ hợp nào hợp lệ (hiếm, toàn bộ bị chắn/nguy cơ chết cái) → dùng phương án dự phòng: `center`, lực 30% (ít chạy nhất, ít rủi ro nhất).
```

with:

```markdown
Nếu KHÔNG tổ hợp nào hợp lệ, đi theo thứ tự dự phòng, tầng sau chỉ chạy khi tầng trước không còn phương án nào *(sửa 2026-10-07: Kế hoạch dọn bàn)*:

1. Đứng / cu lê / trô × 5 mức lực (như trên).
2. **Áp phê, chỉ như đường lui:** thử kiểu đánh × {trái, phải} × {½, 1 đầu cơ} × 5 mức lực (60 phương án), cùng điều kiện loại và cùng cách chấm. Phạt kỹ thuật cộng dồn: `techPenalty` của kiểu đánh + `sidePenalty` (½ đầu cơ = 15, 1 đầu cơ = 20), ví dụ trô + 1 đầu cơ = 10 + 20. Bước dùng áp phê kèm lời khuyên SAWS (tỉ lệ BHE/FHE), không bao giờ nói độ lệch ngắm theo độ.
3. **Đánh đứng bi 30%** nếu cú đó vẫn đưa bi vào đúng lỗ, không chết cái, không đi qua bi chắn. Bỏ qua phần vị trí; màn báo *"Không có vị trí tốt cho bi sau."*; kế hoạch đi tiếp từ điểm dừng của cú đó.
4. Cả cú đó cũng không được thì là bước **phòng thủ** và kế hoạch dừng.

Bằng điểm thì giữ phương án thử trước (kiểu đánh theo thứ tự đứng, cu lê, trô; rồi lực tăng dần), để kết quả tất định.
```

- [ ] **Step 6: §5.4 — 8-ball next ball**

Replace `    - 8-bi: nextBall/nextNextBall = ước lượng bằng góc dễ nhất trong các bi còn lại (không phải tối ưu toàn cục)` with:

```text
    - 8-bi: nextBall/nextNextBall = bi của mình có góc cắt dễ nhất từ điểm dừng (không phải tối ưu toàn cục); còn đúng một bi của mình thì bi kế tiếp là bi 8 (sửa 2026-10-07: Kế hoạch dọn bàn)
```

- [ ] **Step 7: §6 — feature name on screen, and §6.4 — ask, re-place, compute progressively**

Replace `## 6. Yêu cầu UI` with:

```markdown
## 6. Yêu cầu UI

Tên tính năng trên màn là **Kế hoạch dọn bàn**: tên thẻ trong Luyện tập (ngay dưới thẻ Mô phỏng góc cắt) và tiêu đề màn, đường dẫn `/training/planner` *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
```

Replace this line:

```markdown
- Nút **"Đã đánh xong → Bi tiếp theo"**: `viewIndex++` (giới hạn không vượt quá số bước). Mô phỏng đúng trải nghiệm thực tế: người chơi đánh xong 1 bi ngoài đời rồi mới xem gợi ý cho bi kế tiếp.
```

with:

```markdown
- Nút **"Đã đánh xong → Bi tiếp theo"**: hỏi *"Bi cái dừng đúng chỗ dự kiến?"*. **Đúng** thì `viewIndex++` (giới hạn không vượt quá số bước). **Đặt lại bi cái** thì bàn vào chế độ kéo bi cái; bấm *Tính lại từ đây* thì lập kế hoạch mới từ chỗ bi cái dừng thật, với các bi còn lại. Ở bước cuối nút đổi thành *Xong bàn*. Mô phỏng đúng trải nghiệm thực tế: người chơi đánh xong 1 bi ngoài đời rồi mới xem gợi ý cho bi kế tiếp *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
- Tính từng bước: bước 1 hiện sau khoảng 1 giây, các bước sau tính tiếp trong nền với dòng *"Đang tính bước X/N…"*; nút *Đã đánh xong* ở bước cuối đã tính thì chờ bước kế tiếp *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
```

- [ ] **Step 8: §6.5 — drop the 15 % clause**

Replace `*"Bi cái chạm băng N lần rồi tới vùng điều — mỗi lần chạm hao khoảng 15% lực, lực X% đã tính phần hao này."*` with:

```markdown
*"Bi cái chạm băng N lần rồi tới vùng điều."* (bỏ vế "mỗi lần chạm hao khoảng 15% lực": lõi vật lý tính hao lực thật) *(sửa 2026-10-07: Kế hoạch dọn bàn)*
```

- [ ] **Step 9: §8 — side spin is no longer out of scope**

Replace the bullet that starts `- Chưa đưa đầu cơ có áp phê (side-spin: 3h/9h, trô áp phê, cu lê áp phê` (the whole line) with:

```markdown
- ~~Chưa đưa đầu cơ có áp phê vào candidate set~~ — áp phê nay **có** trong Planner, nhưng **chỉ như đường lui** khi không phương án đứng / cu lê / trô nào dùng được, với phạt cộng dồn cao hơn trô (xem §5.3) *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
```

- [ ] **Step 10: Check every amendment is marked**

Run: `grep -c "sửa 2026-10-07: Kế hoạch dọn bàn" PRD_RunOutPlanner.md && grep -n "15% lực" PRD_RunOutPlanner.md`
Expected: the count is 11 or more. The second command prints only the struck-out mention inside the new §6.5 text (`bỏ vế "mỗi lần chạm hao khoảng 15% lực"`).

- [ ] **Step 11: Commit**

```bash
git add PRD_RunOutPlanner.md
git commit -m "Amend the Run-out Planner PRD with the Kế hoạch dọn bàn decisions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Real Chrome, the first-step and frame gates, the owner's eye check, then tuning

**Files:**
- Create: `tool/e2e/planner.mjs`
- Create: `docs/superpowers/logs/2026-10-07-run-out-planner.md`
- Modify only if the owner asks: values in `lib/domain/planner/planner_constants.dart`; `Vi.simCannotSimulate` in `lib/core/strings/vi.dart`

**Interfaces:**
- Consumes:
  - `launch`, `sleep` (`tool/e2e/cdp.mjs`);
  - `registerThrowaway`, `deleteUserByEmail` (`tool/e2e/throwaway_user.mjs`);
  - the labels `Vi.planSetupSummary` (`Bàn bày bi.`) and `Vi.planSummary` (`Bàn kế hoạch.`);
  - the chip and button labels from `Vi`;
  - the fixture coordinates of `test/support/planner_tables.dart`.
- Produces: `node tool/e2e/planner.mjs [appUrl]`. For each of four tables it:
  - prints the time from *Lập kế hoạch* to step 1 and every step's semantics label;
  - saves a screenshot per step to `%TMP%/pcai-planner`;
  - runs the re-place flow on the typical 9-ball table and prints frame statistics `{ n, median, p95, max }` while computing.

It fails when:
- step 1 of the typical 9-ball table takes more than 1000 ms;
- the frame median exceeds 17 ms, or the p95 exceeds 20 ms;
- any table's labels break the rules (for example an opponent ball is planned, or the 8 is planned early).

- [ ] **Step 1: Write `tool/e2e/planner.mjs`**

```js
// Mở Kế hoạch dọn bàn trên Chrome thật: bày bốn bàn, đo thời gian ra bước 1
// và thời gian khung hình lúc đang tính, chụp từng bước, kiểm luồng đặt lại
// bi cái.
//   node tool/e2e/planner.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó (như simulator.mjs).
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-planner');
const email = `e2e-plan-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

// Spec mục 10.3: bước 1 khoảng 1 giây trên Chrome giả lập điện thoại; khung
// hình lúc đang tính như màn mô phỏng.
const FIRST_STEP_MAX_MS = 1000;
const FRAME_MEDIAN_MAX = 17;
const FRAME_P95_MAX = 20;

// Bốn bàn — đúng toạ độ của test/support/planner_tables.dart.
const RING = [[116.27, 58.13], [127, 51.5], [137.73, 58.13], [116.27, 68.87], [127, 75.5], [137.73, 68.87]];
const TABLES = [
  { name: '1-9bi-de', game: '9 bi', cue: [127, 63.5], balls: [[200, 8], [60, 40], [127, 100], [220, 100]] },
  {
    name: '2-9bi-bi-chan', game: '9 bi', cue: [64, 63.5], gate: true, reset: true,
    balls: [[127, 100], [200, 8], [60, 40], [220, 100], [127, 115], [40, 105], [175, 60], [95, 20], [230, 40]],
  },
  {
    name: '3-8bi-doi-thu', game: '8 bi', group: 'Trơn', cue: [64, 63.5],
    balls: [
      ['Bi của tôi', [127, 100]], ['Bi của tôi', [200, 8]], ['Bi của tôi', [95, 20]],
      ['Bi đối thủ', [127, 115]], ['Bi đối thủ', [175, 60]], ['Bi 8', [220, 100]],
    ],
  },
  { name: '4-phong-thu', game: '9 bi', cue: [40, 100], balls: [[127, 63.5], ...RING] },
];

const tab = await launch({ port: 9336, name: 'ke-hoach' });

/** Nhãn đầu tiên bắt đầu bằng [prefix], đọc thẳng không bấm lại semantics. */
async function labelStarting(prefix) {
  return tab.eval(`[...document.querySelectorAll('flt-semantics')]
    .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim())
    .find((t) => t.startsWith(${JSON.stringify(prefix)})) ?? null`);
}

async function waitLabel(prefix, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const hit = await labelStarting(prefix);
    if (hit) return hit;
    await sleep(25);
  }
  return null;
}

/** Như tab.click nhưng không chờ 1.5 s sau khi bấm — để đo thời gian. */
async function clickNow(label) {
  const r = await tab.eval(`(() => {
    const hits = [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
      .filter((x) => x.t.includes(${JSON.stringify(label)}))
      .sort((a, b) => (a.e.getAttribute('role') === 'button' ? 0 : 1) - (b.e.getAttribute('role') === 'button' ? 0 : 1)
        || a.t.length - b.t.length);
    if (!hits.length) return null;
    hits[0].e.click();
    return hits[0].t;
  })()`);
  if (r == null) throw new Error(`không có nút "${label}"`);
}

async function tableRect() {
  await tab.semantics();
  return tab.eval(`(() => {
    const e = [...document.querySelectorAll('flt-semantics')]
      .find((n) => /^(Bàn bày bi|Bàn kế hoạch)/.test((n.getAttribute('aria-label') || n.textContent || '').trim()));
    const r = e.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width };
  })()`);
}

function toPx(r, [x, y]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [r.x + (x + FRAME) * s, r.y + (y + FRAME) * s];
}

async function tapCm(r, cm) {
  const [x, y] = toPx(r, cm);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(150);
}

async function startFrames() {
  await tab.eval(`(() => {
    window.__frames = [];
    window.__recording = true;
    let last = performance.now();
    const tick = (t) => { window.__frames.push(t - last); last = t; if (window.__recording) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  })()`);
}

async function stopFrames() {
  // Khung đầu đo từ lúc bật bộ ghi, không phải khoảng giữa hai khung: bỏ.
  return tab.eval(`(() => { window.__recording = false; return window.__frames.slice(1); })()`);
}

function stats(frames) {
  const s = [...frames].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, median: at(0.5), p95: at(0.95), max: s[s.length - 1] };
}

async function dragCm(fromCm, toCm, moves = 16) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= moves; i++) {
    // Dồn hết mouseMoved vào một khung hình thì Flutter không nhận ra kéo.
    await sleep(30);
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / moves, y: y0 + ((y1 - y0) * i) / moves, button: 'left', buttons: 1,
    });
  }
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
}

async function waitPlanDone() {
  for (let i = 0; i < 240 && (await tab.text()).includes('Đang tính bước'); i++) await sleep(250);
}

const results = [];
let frameStats = null;

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });

  for (const t of TABLES) {
    await tab.goto(`${APP}/training/planner`);
    await tab.waitForText('Bàn bày bi');
    await tab.click(t.game);
    if (t.group) await tab.click(t.group);
    const r = await tableRect();
    await tapCm(r, t.cue);
    for (const b of t.balls) {
      if (typeof b[0] === 'string') {
        await tab.click(b[0]);
        await tapCm(await tableRect(), b[1]);
      } else {
        await tapCm(r, b);
      }
    }
    const setup = await labelStarting('Bàn bày bi');
    if (!setup?.includes(`${t.balls.length} bi mục tiêu`)) throw new Error(`${t.name}: bày bi sai — ${setup}`);
    await tab.shot(path.join(shots, `${t.name}-0-bay-ban.png`));

    if (t.gate) await startFrames();
    const t0 = Date.now();
    await clickNow('Lập kế hoạch');
    const first = await waitLabel('Bàn kế hoạch. Bước 1 /', 15000);
    const firstMs = Date.now() - t0;
    if (!first) throw new Error(`${t.name}: không thấy bước 1`);
    console.log(`${t.name}: bước 1 sau ${firstMs} ms — ${first}`);
    await waitPlanDone();
    if (t.gate) frameStats = stats(await stopFrames());

    const labels = [];
    for (let i = 0; i < 16; i++) {
      const label = await labelStarting('Bàn kế hoạch.');
      labels.push(label);
      console.log(`  ${label}`);
      await tab.shot(path.join(shots, `${t.name}-${i + 1}.png`));
      const text = await tab.text();
      if (text.includes('Xong bàn')) break;

      if (t.reset && i === 0) {
        // Luồng đặt lại bi cái: kéo bi cái tới chỗ khác rồi tính lại.
        await tab.click('Đã đánh xong');
        await tab.click('Đặt lại bi cái');
        await startFrames();
        await dragCm([127, 63.5], [100, 40]);
        await tab.click('Tính lại từ đây');
        const again = await waitLabel('Bàn kế hoạch. Bước 1 /', 15000);
        await waitPlanDone();
        const resetFrames = stats(await stopFrames());
        console.log(`  đặt lại bi cái → ${again}; khung hình: ${JSON.stringify(resetFrames)}`);
        if (!again?.includes('Bước 1 / 8')) throw new Error(`${t.name}: tính lại không bỏ bi đã đánh — ${again}`);
        if (again.includes('bi 1,')) throw new Error(`${t.name}: tính lại vẫn đánh bi 1`);
        await tab.shot(path.join(shots, `${t.name}-dat-lai.png`));
        // Cổng khung hình lấy lượt xấu hơn: đang tính sau Lập kế hoạch, hay
        // kéo bi cái rồi tính lại.
        if (resetFrames.p95 > frameStats.p95) frameStats = resetFrames;
        break;
      }
      await tab.click('Đã đánh xong');
      await tab.click('Đúng');
    }
    results.push({ table: t.name, firstMs, steps: labels.length });

    if (t.name.startsWith('3-')) {
      if (labels.some((l) => /bi (9|10),/.test(l))) throw new Error('8 bi: kế hoạch đánh bi đối thủ');
      const eightAt = labels.findIndex((l) => l.includes('bi 8,'));
      if (eightAt >= 0 && eightAt !== labels.length - 1) throw new Error('8 bi: bi 8 không đánh cuối');
    }
    if (t.name.startsWith('4-') && !labels[0]?.includes('nên phòng thủ')) {
      throw new Error(`bàn phòng thủ: ${labels[0]}`);
    }
  }

  console.log(`\nThời gian ra bước 1: ${JSON.stringify(results)}`);
  console.log(`Khung hình lúc đang tính (bàn 2, giả lập điện thoại): ${JSON.stringify(frameStats)}`);

  // Thêm một lượt ở CPU chậm 4 lần, chỉ để chủ sản phẩm tham khảo.
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await tab.goto(`${APP}/training/planner`);
  await tab.waitForText('Bàn bày bi');
  const r2 = await tableRect();
  await tapCm(r2, TABLES[1].cue);
  for (const b of TABLES[1].balls) await tapCm(r2, b);
  const t1 = Date.now();
  await clickNow('Lập kế hoạch');
  await waitLabel('Bàn kế hoạch. Bước 1 /', 30000);
  console.log(`Bước 1 ở CPU chậm 4 lần (tham khảo): ${Date.now() - t1} ms`);
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 1 });

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  const gated = results.find((x) => x.table.startsWith('2-'));
  if (gated.firstMs > FIRST_STEP_MAX_MS) throw new Error(`Bước 1 chậm: ${gated.firstMs} ms`);
  if (frameStats.median > FRAME_MEDIAN_MAX || frameStats.p95 > FRAME_P95_MAX) {
    throw new Error(`Rớt khung lúc đang tính: trung vị ${frameStats.median.toFixed(1)} ms, p95 ${frameStats.p95.toFixed(1)} ms`);
  }
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
```

Check the syntax: `node --check tool/e2e/planner.mjs`. Expected: no output.

- [ ] **Step 2: Build, serve locally, and run it**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/planner.mjs http://localhost:5555
```

Load the secrets from the main checkout's `.claude/settings.local.json` `env` block with a `node -e` one-liner (memory: poolcoachai-deploy). Expected:
- every table prints `bước 1 sau N ms` and one `Bàn kế hoạch. Bước k / N: …` label per step;
- table 2 prints `đặt lại bi cái → Bàn kế hoạch. Bước 1 / 8: …`, not starting with `bi 1`;
- table 3 never plans ball 9 or 10, and plans the 8 last;
- table 4's first label contains `nên phòng thủ`;
- there are no console errors;
- table 2's first-step time is ≤ 1000 ms;
- the frame line shows median ≤ 17 ms and p95 ≤ 20 ms.

Also run the existing check so nothing regressed: `node tool/e2e/simulator.mjs http://localhost:5555`.

If either gate fails, **stop and report** the printed lines to the owner. Do not optimise on your own. The candidate fixes, for the owner to choose:
- skip the look-ahead simulation for options whose `robustDiff1` already exceeds the best total;
- compute tolerance only when a step is first viewed;
- compute the zone grid a few rows per frame;
- move `PlannerJob` into a Web Worker (spec decision 4 allows it without changing the core).

- [ ] **Step 3: The owner's eye check: STOP here.**

The controller shows the owner the screenshots of the four tables, the printed labels, the first-step times and the frame lines. Spec §10.4 says to stop here for the owner to judge whether the plan looks like how a good player would clear the table, before tuning any penalty. Ask specifically:
- On tables 1–3: is each chosen ball, pocket, stroke and power what the owner would play? Would a good player use that cue-ball route?
- Is any position bought with too much power or trô where a stun or follow off a rail would do? The knobs are `techPenalty*`, `bankPenalty*`, `powerPenaltyPerPercent` and `sidePenalty*`.
- Does the tolerance line (`k/7 mức lực…`) and the jitter bar match the owner's sense of a forgiving shot?
- Are the zone colours (≤ 35° green, ≤ 55° yellow) the right thresholds? **And may the legend show these thresholds in degrees?** They are information, not aim instructions (memory: poolcoachai-executable-advice asks before showing more degree numbers).
- **Spec §8.3:** approve or reword `Vi.simCannotSimulate`, currently *"Không mô phỏng được cú này — chỉ vẽ đường ngắm."*
- Show the owner this plan's "Deviations from spec and gaps the plan fills" list, and get an explicit OK on items 2 (clamp at 100 %), 4 (look-ahead failures count as 95°), 7 (thick/thin direction), 9 (*Xong bàn* returns to Luyện tập) and 10 (setup rules).

Do not change any constant or string without the owner's answer.

- [ ] **Step 4: Apply the owner's tuning and wording, if any**
1. Change only named values in `planner_constants.dart`, and `Vi.simCannotSimulate` if the owner rewords it.
2. Re-run `"$FLUTTER" test` and `"$FLUTTER" test --tags perf --run-skipped test/domain/planner/planner_perf_test.dart`. Tests reference the constants by name, so they should stay green.
   - A red PRD §7 test means a fixture stopped meeting its condition under the new weights. Re-find it with the probe (Task 7), then update the fixture, its comment and `planner.mjs`.
   - A red test that is not about a fixture means the new weight contradicts a PRD rule. One example is test 7, where a rail must still beat trô. Report that to the owner rather than relaxing the test.
3. Rebuild, re-run Step 2, show the new screenshots, and repeat until the owner approves.

- [ ] **Step 5: Log what the eye check decided**

Create `docs/superpowers/logs/2026-10-07-run-out-planner.md`:

```markdown
# Kế hoạch dọn bàn — build log

Plan: `docs/superpowers/plans/2026-10-07-poolcoachai-run-out-planner.md`.

## Measured

- Step 1 on the Dart VM (planner_perf_test): <paste>.
- Step 1 on Chrome mobile emulation (planner.mjs): <paste the "Thời gian ra bước 1" line>.
- Frames while computing: <paste the frame line>, and at 4× CPU: <paste>.

## Owner's eye check

<the owner's verdict on tables 1–3, verbatim>

## Tuning

<each changed constant: old → new, or "none">

## Wording

- `Vi.simCannotSimulate`: <approved as is, or the new text>.
- Degree thresholds in the legend: <approved / removed>.

## Still open

- Run `tool/e2e/planner.mjs` against the live URL after deploy.
- Calibrating SAWS per cue and the 8-ball global order stay out of scope (spec §1).
```

Fill every `<…>` with what Step 2 printed and what the owner said, verbatim.

- [ ] **Step 6: Commit**

```bash
git add tool/e2e/planner.mjs docs/superpowers/logs/2026-10-07-run-out-planner.md lib/domain/planner/planner_constants.dart lib/core/strings/vi.dart
git commit -m "Check the planner in real Chrome with first-step and frame gates, and log the owner's eye check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If tuning changed constants or wording, list each change with old → new in the commit body.

---

### Task 15: Full verification and the whole-branch review

**Files:** none new.

- [ ] **Step 1: Run everything**

```bash
"$FLUTTER" test
"$FLUTTER" test --tags perf --run-skipped
"$FLUTTER" analyze
git status --short
```

Expected:
- All tests pass. The count is baseline + the planner tests; write it down.
- Both perf files pass (`aim_perf_test`, `planner_perf_test`).
- The analyzer prints `No issues found!`.
- `git status` is clean.

- [ ] **Step 2: Whole-branch review**

Use superpowers:requesting-code-review on `main...feat/run-out-planner`, with the spec, this plan and the log as context. Ask the reviewer to check at least these:
- the invariant and determinism;
- that slicing cannot change results;
- every Review Focus item;
- no degree aim instruction on any screen;
- every visible string in `Vi`;
- the owner's terms used exactly.

Fix findings with superpowers:receiving-code-review, then re-run Step 1.

- [ ] **Step 3: Hand off to the owner**

Use superpowers:finishing-a-development-branch. Merging and deploying are **the owner's decision**, made separately. Do not push or merge without it. There is no `gh`: if the owner wants a pull request, push the branch and give them the `pull/new/feat/run-out-planner` URL.

### After the owner approves the merge

This is the same sequence as the physics feature (memory: poolcoachai-deploy). Do not deploy from the branch.

1. From a clean `main`, run `FLUTTER=… DART=… bash deploy/publish.sh`.
2. Call the easypanel MCP `deployAppService` {projectName: test-va, serviceName: poolcoachai} through `execute_destructive`.
3. Confirm that `inspectAppService` → `commit.hash` equals the new `deploy-easypanel` head.
4. Run `node tool/e2e/planner.mjs` against the live URL. It must print every table's labels, pass both gates, and show no console errors.
5. Re-run `node tool/e2e/simulator.mjs` and `node tool/e2e/accounts.mjs` against the live URL. Both must pass.

---

## Self-review (applied)

1. **Spec coverage.**

   | Spec section | Task |
   |---|---|
   | §1 four parts | core: Tasks 3–6; screens: 11–12; carry-overs: 1, 2, 14; PRD: 13 |
   | §2 decisions 1–9 | 1 áp phê as fallback: Tasks 4, 6 · 2 8-ball rules: 3, 7 · 3 progressive + re-place: 6, 11 · 4 sliced job: 6 · 5 side penalties: 3, 4 · 6 fallback order: 6 · 7 no 15 %: 9 · 8 `aimShot` normal + compensate: 4 · 9 no degree advice: 9 |
   | §2 terms | 9 (strings test) |
   | §3 constants | 3 |
   | §4.1 legal targets | 3 |
   | §4.2 pruning | 3 |
   | §4.3 options and rejection | 4 |
   | §4.4 `PlanStep` and the invariant | 6, 7 |
   | §4.5 job, re-place, cache, cancel | 6 |
   | §5 scoring | 4 |
   | §5.1 next ball | 3, 4, 7 |
   | §5.2 rail not hard | 4, 7 |
   | §5.3 áp phê | 4, 6 |
   | §5.4 tolerance | 4, 6 |
   | §5.5 fallback order | 6 |
   | §6 setup screen | 10, 12 |
   | §7.1–7.4 steps screen | 9, 11 |
   | §8.1 | 1 |
   | §8.2 | 2 |
   | §8.3 | 14 |
   | §9 | 13 |
   | §10.1 nine PRD tests | 5 (test 9), 7 |
   | §10.2 decision tests | 6, 9, 10, 11, 12 |
   | §10.3 speed | 8, 14 |
   | §10.4 Chrome + owner | 14 |
   | §10.5 after merge | 15 |

   Gaps the spec leaves open are listed under "Deviations from spec", each with its owner question in Task 14.
2. **Placeholder scan.**
   - The only `<…>` markers are in the Task 14 log template. They must be filled with measured output and the owner's words, which cannot be known in advance; Task 14 Step 5 says so.
   - No "TBD", no "similar to Task N"; every code step carries its code.
3. **Type consistency.** These names were checked across tasks:
   - `ShotKey` record fields: `cue, object, pocket, stroke, spin, power`.
   - `CandidateFinder.easiest(Vec2, List<PlacedBall>) → Candidate?`.
   - `ScoringContext({geometry, after, lookup, next})`.
   - `scoreTier`, `bestOf`, `toleranceOf`, `zoneGrid({after, next})`.
   - `PlanStep` fields and the `PlanStep.safety` constructor.
   - `PlannerJob.step({budget, maxSimulations})`, `StepReady(index, step)`, `PlanDone(steps)`, `planToEnd(setup, {aim})`.
   - `SetupDraft` methods; `PlannerScene` fields; `PlannerStepsView`/`PlannerSetupView` keys; `Routes.planner`.
   - `AimShotFn` lives in `aim.dart` from Task 2 on.
   - `squirtLine` is public from Task 9 on.
   - `TableLayout` moves to `table_drawing.dart` in Task 10 and stays importable from `table_painter.dart`.
4. **Review Focus.** Each of the five items has its named test in its owning task: 11 and 6; 6 and 11; 6 and 10; 4; 10.
