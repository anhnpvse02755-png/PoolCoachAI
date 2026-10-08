# Kế hoạch dọn bàn: cú phòng thủ và nút Chờ — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the branch that already holds *Kế hoạch dọn bàn*, before it merges:
- set the planner's slice to 4 ms (owner decision);
- replace the bare *phòng thủ* step with a real safety-shot search: direct safeties when the cue ball sees a legal ball, *A băng* kicks of 1–3 rails (4 rails as the last resort) when it is *bị đui*;
- ask *Chờ / Chỉ vẽ đường ngắm* when the Cut Angle Simulator times out.

**Architecture:** The safety search is plain Dart in `lib/domain/planner/`, built on the physics core.
- Geometry (`safety_geometry.dart`) classifies *bị đui*, lists the visible thicknesses, unfolds rail sequences by mirror images, and converts rail hits to *chấm*.
- `safety_aim.dart` refines each option's cue direction with real simulation. A secant on the aim angle drives the measured lateral contact offset to its target, after exactly the option's rail sequence, then one full `simulateShot` runs.
- `safety_rules.dart` rejects fouls; `safety_scoring.dart` scores the opponent's position (worst of ±15 %) plus the owner's penalties.
- `SafetyJob` slices the search like `PlannerJob`: every unit re-runs the pure evaluation over a memo and does exactly one new simulation, so slicing never changes the result. A cursor keeps evaluated options, so replay cost stays flat.
- `PlannerJob` hands its safety step to a `SafetyJob` and reports the step when the search ends.
- The simulator gains an optional time limit on `simulateShot` / `aimShot` and a wait flow that paints *Đang tính…* before it computes.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flutter_test`, `package:test` tags via `dart_test.yaml`; Node 26 + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** `docs/superpowers/specs/2026-10-07-poolcoachai-planner-safety-design.md` (binding, approved 2026-10-07). It amends `docs/superpowers/specs/2026-10-07-poolcoachai-run-out-planner-design.md`, which stays binding where the new spec is silent. Task 28 writes the new spec's §8 amendments into `PRD_RunOutPlanner.md`.

**Continues:** `docs/superpowers/plans/2026-10-07-poolcoachai-run-out-planner.md` (Tasks 0–15). That plan's Task 14 is still at the owner's eye check. Its Task 15 (full verification and whole-branch review) **moves to the end of this plan as Task 30** and must not run before Tasks 16–29 are done.

## Deviations from spec and gaps the plan fills

The spec was checked against the code at `a35667b`. The numbers below were measured on the Dart VM with a throwaway prototype in a temporary worktree of `feat/run-out-planner` (detached at `a35667b`, removed afterwards). The prototype ran the real `simulateShot`, `probeContact`, a kick probe equal to Task 17's `probeKick`, the mirror start and secant of Task 20, and a simplified version of the rules and scoring of Task 21. The owner should see this list before execution.

1. **The "vài giây" target (spec §6) is not reachable with 675 direct options per ball on the main thread. Task 25 is a hard stop for the owner.**
   - One full `simulateShot` of a 90 cm safety took 2.4 ms at 30 %, 2.6 ms at 60 % and 4.6 ms at 90 % on the VM. A `probeContact` took 0.08–0.17 ms.
   - The direct search of one legal ball with all 675 options and both ±15 % levels needed 1509 full simulations and 1374 probes: 7.0 s.
   - With the exact pruning of item 4 it needed 602–784 full simulations and 1270–1500 probes: 1.9–11.0 s on nine tables (the machine was noisy; the fast end had only 8 legal options).
   - Kicks: probing 1–3 rails over 52 sequences took about 4.2 s on one table before geometric pruning. The 4-rail tier alone, unpruned, took about 16 s of probes.
   - The plan's own code (see "How this plan was checked") took 1.6–10.2 s per safety step on the VM over the five fixtures, 4.2–5.0 s for the two tables of the perf test.
   - Chrome runs about 2× the VM. With a 4 ms slice per 16.7 ms frame, the wall time is about 4× the CPU time. So one safety step would take roughly 15–90 s in Chrome, and 3–22 s even in a Web Worker.
   - The plan builds what the spec says, measures it in Task 25, and stops there with these numbers. Candidate changes for the owner are listed in Task 25. A Web Worker is a separate project after merge and out of scope here.
2. **Units of work.** One unit is either an *aim* unit or a *sim* unit. An aim unit is a contact refinement (cheap probes, plus a stun solve) for one option, like one `aimShot` is one unit in `PlannerJob`. A sim unit is one full `simulateShot`. Either way, a unit performs exactly one new memo entry.
3. **`SafetyJob` keeps a cursor instead of replaying from step 1.**
   - `PlannerJob` re-runs `planStep` from scratch after each simulation. That costs nothing there (about 60 memo lookups). With about 2000 simulations per search, each full replay would also redo every opponent evaluation, and the cost would grow quadratically.
   - So `SafetyJob` stores each finished option's evaluation and re-runs only the current option's pure evaluation over the memo. The order is fixed and the evaluation is pure, so sliced and one-shot runs stay identical (tested in Task 22).
4. **Exact pruning.** Spec §3.3 "675 phương án": every option is still considered, in the fixed order, but two bounds skip simulations of options that cannot win.
   - Before any simulation: an option's total is at least its penalties plus the lowest possible score (two near-rail bonuses and the table diagonal times `distanceWeight`). If that is not below the best total so far, the option is skipped.
   - After the chosen-power level: the worst of three levels is at least that level. If it plus the penalties is not below the best, the ±15 % levels are not simulated.
   - Ties keep the earlier option, so `>=` is the right test, and the chosen shot is the same as without pruning (tested in Task 22 against `prune: false`).
5. **The cue ball after contact passing through another ball is a foul.** Spec §3.5 does not list it. The two-ball simulation cannot say where the cue ball stops after hitting a third ball, so the scoring would rest on a fiction. The pot planner rejects the same case (spec gốc §4.3). Owner question in Task 29.
6. **An option counts only if its chosen power is legal.** Spec §4.1 gives 95 to an illegal level, but an illegal chosen power would make the option itself a foul (spec §3.5 "loại phương án"). Only the ±15 % levels can be illegal and score 95.
7. **Which ball "near rail" and "distance" use when the opponent is *bị đui* or has no pocket.** The spec's choice is "bi đối thủ phải đánh dễ nhất", which does not exist in those cases. The plan uses the lowest-numbered opponent target. With no target at all (8-ball, no opponent ball and no 8), the opponent part is 0 and both terms are skipped.
8. **"Cách băng ≤ 5,7 cm"** is the gap between the ball and the cushion, i.e. the ball centre's distance to its bound line (`TableSpec.minX` …) is at most `nearRailDiameters × ballDiameter`. `nearRailDistance = ballDiameter` is not a compile-time constant (`TableSpec.nineFoot.ballDiameter` is an instance field), so the constant is `nearRailDiameters = 1.0`.
9. **Counting *chấm* on the short rails.** Spec decision 5 says "đếm từ góc trái của băng theo hướng nhìn trên màn". A vertical rail on the screen has a top and a bottom, not a left. The plan counts long rails from x = 0 (the left corner) and short rails from y = 0 (the top corner). The *chấm* is the projection of the cue-ball centre's contact with the cushion, taken from the simulated trace, not from the mirror start. Owner question in Task 29.
10. **Stun in a safety.** "Đánh đứng bi" uses the stun offset solved by the core's own `solveStun`, made public with a pluggable spin probe so it also works after rails. For a stun option, the aim is refined at `b = 0`, then the stun is solved at that aim, then the aim is refined again: two rounds, like `aimShot`.
11. **The pocket mouth for kicks** (spec §3.4 "điểm chạm băng rơi vào miệng lỗ"): a geometric rail hit closer than `captureRadius(pocket) + ballDiameter` to a pocket point (11.7 cm at a corner, 10.7 cm at a side pocket). No new constant.
12. **Order inside the fixed tie-break order** (spec §4.2 leaves these open):
    - rail sequences of the same length in generation order (left, right, top, bottom at each position);
    - kick contacts: full, then ½ left, then ½ right;
    - direct thicknesses: full, ¾ left, ¾ right, ½ left, ½ right, ¼ left, ¼ right, ⅛ left, ⅛ right;
    - spins: none, left ½, left 1, right ½, right 1.
13. **Direct and kick never compete in one search.** Spec §3.2 searches kicks only when *bị đui* and direct safeties only when not. Spec test 9.1.7 ("cú đơn giản thắng khi gần ngang") therefore cannot happen inside one search, and Task 21 tests it on the scoring itself. Owner question in Task 29: should a not-snookered table also try kicks?
14. **8-ball *bị đui*:** kicks are tried on every legal ball, which multiplies the cost by the number of legal balls.
15. **Thickness side.** "Lệch bên trái" means the cue-ball centre passes to the left of the object-ball centre, seen from behind the cue ball along the shot (the cue ball takes the object's left half). In code a positive lateral offset is left, measured as `(cueAtContact.pos − ball) · leftOf(velocity)` with `leftOf(d) = (d.y, −d.x)` on the y-down screen.
16. **The 8-ball safety step keeps `PlanStep.ballNum == null`** (as before). The touched ball is `safety.ballNum`, and the steps view shows it.
17. **`AimShotFn` gains `double maxTime`.** Every fake in the tests must accept it (three in `test/support/planner_tables.dart`, three in `test/features/training/simulator_screen_test.dart`).
18. **The simulator's *Đang tính…* line reuses `Vi.simComputing`.** The spec's wording is the same text.
19. **PRD:** spec §8 says to amend "§5.4 / §5.5". In `PRD_RunOutPlanner.md` the fallback order lives in §5.3 and the loop in §5.4; §5.5 is the miss advice. The plan amends §4, §5.1, §5.3, §5.4, adds §5.6 and §6.7, and changes §8. §8 has no line that names *cú phòng thủ* as out of scope, so the plan adds one rather than removing one.
20. **"Vài giây"** is read as at most 5 s of wall time in Chrome mobile emulation, from *Lập kế hoạch* to the safety step. Task 25 derives a VM gate of 600 ms from it.

## How this plan was checked

- The sliceBudget change of Task 16 was applied in the temporary worktree. `planner_perf_test.dart` passed four quiet runs, with median slices of 3.4, 4.2, 4.5 and 5.4 ms against the derived gate of 6 ms. One run under CPU contention read 9.0 ms and failed; the perf tag is meant to run alone (see `dart_test.yaml`).
- The geometry of the kick fixtures in Task 19 was checked with the same mirror unfolding, blocking and pocket-mouth rules as Task 19's code:
  - `snookerOneRailTable`: *bị đui*, no pot, open geometric paths 6 / 15 / 23 for 1 / 2 / 3 rails. The 1-rail paths converged in 6–8 of 10 stroke × power options with the secant of Task 20.
  - `snookerTwoRailTable`: *bị đui*, no pot, 0 / 13 / 8.
  - `snookerThreeRailTable`: *bị đui*, no pot, 0 / 0 / 8. The extra blockers were found by a greedy grid search, which Task 22's probe repeats.
- `noPotTable`: no pot, not *bị đui*. The prototype found 233–277 legal direct options under the simplified rules.
- Mirror starts miss: on `snookerOneRailTable`, aiming at the top-rail image hit the object ball after one rail in only 6 of 15 stroke × power cases (rebounds come off shallower than a mirror). That is why the refinement searches outward from the mirror start before the secant.
- **Then the plan's own code was run.** The domain code of Tasks 17 and 19–24 and their test files were copied, as written here, into the same temporary worktree (reset to `a35667b` first) and run on the Dart VM:
  - `flutter analyze` on `lib/domain`, `test/domain/planner` and `test/support`: `No issues found!` (after the `const` fixes already folded into this plan);
  - Task 17's physics tests (48 in the two files), Task 19's geometry tests, Task 20's aim tests, Task 21's rules and scoring tests, Task 22's job tests (11), Task 23's spec tests (8) and Task 24's `planner_job_test.dart` (21): all pass. Task 21's no-rail test needed cu lê instead of đứng bi at 3 %, already folded in.
  - Task 22's probe on the five safety fixtures (one-shot, 8 ms slice build):

    | Fixture | Chosen | Units | VM time |
    |---|---|---|---|
    | `snookerOneRailTable` | A băng 1 băng, băng dài dưới, chấm 3,5, cu lê 90 %, đối thủ 72.7° | 689 | 7.9 s |
    | `snookerTwoRailTable` | A băng 2 băng, băng ngắn trái, chấm 2, cu lê 45 %, đối thủ 15.8° | 399 | 3.4 s |
    | `snookerThreeRailTable` | A băng 3 băng, băng ngắn phải, chấm 0,5, ½ bi phải, đứng bi 75 %, đối thủ bị đui | 137 | 1.6 s |
    | `noPotTable` | ¼ bi lệch phải, đứng bi 45 %, đối thủ không còn đường ăn | 1146 | 3.8 s |
    | `eightSafetyTable` | ¾ bi lệch phải, đứng bi 45 %, đối thủ đánh bi 10 (28.6°) | 1412 | 10.2 s |

  - Task 25's perf test with `sliceBudget` at 4 ms: one-shot searches took 5045 ms (kick table) and 4174 ms (no-pot table) against the 600 ms gate, so it fails as expected. The slice median while searching was 4.9 ms on a quiet run and 7.6 ms on a contended one (gate 6 ms).
  - Tasks 18, 26–29 (screens, strings, PRD, Chrome) were not run at plan time.

## Global Constraints

- **Toolchain.** Flutter is not on PATH. In Git Bash, every command below uses `FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat` and `DART=/c/Users/anhnpv/flutter/bin/dart.bat` (memory: poolcoachai-toolchain-state). Chrome is the only runnable target. There is no `gh`.
- **Branch.** Work happens in the worktree `.claude/worktrees/run-out-planner` on `feat/run-out-planner`. Do not push. Merging and deploying are a separate owner decision.
- **Table.** Units are cm. The 9-foot table is 254 × 127, origin top-left, `y` down. Ball-centre bounds are `[R, 254−R] × [R, 127−R]`, with `R = 5.715/2`. Rails are `Rail.left/right/top/bottom` from `lib/domain/table_physics/cushion.dart`.
- **Slice.** `sliceBudget = Duration(milliseconds: 4)` from Task 16 on (owner decision 2026-10-07).
- **Safety constants** (spec §4.5) live in `lib/domain/planner/planner_constants.dart`:
  - `kickRailPenalty = {1: 10, 2: 20, 3: 45, 4: 55}`;
  - `nearRailBonus = 5`, `nearRailDiameters = 1.0` (`nearRailDistance = ballDiameter`);
  - `safetyThicknesses = [1, ¾, ½, ¼, ⅛]`, `kickThicknesses = [1, ½]`;
  - `maxKickRails = 4`, `kickFallbackRails = 4`, `opponentHardAngle = zoneFair`;
  - `safetySpins` = none, left ½, left 1, right ½, right 1; `kickStrokes` = đứng, cu lê;
  - added by this plan: `contactTolerance = 0.02` (ball diameters), `maxContactProbes = 16`, `contactMaxStepDeg = 2.0`, `contactStartStepDeg = 0.5`, `longRailDiamonds = 8`, `shortRailDiamonds = 4`.
- **Physics constants:** `extendedSimTime = 3 * maxSimTime` (60 s simulated) in `lib/domain/table_physics/constants.dart`.
- **Safety score** (lower is better): worst of three power levels (chosen, −15 %, +15 %, clamped at 100 %) of `opponent part − 5 per near-rail ball − distance × distanceWeight`, plus `techPenaltyFor(stroke, spin) + kickRailPenalty[rails] + power × powerPenaltyPerPercent`. Opponent part = 0 if *bị đui*, else `blockedAngle − easiest cut angle` (0 with no pocket). An illegal ±15 % level scores `blockedAngle` (95).
- **Rules** (spec §3.5 + deviation 5): reject a miss, the cue touching another ball first, a wrong rail count before contact, *chết cái*, the legal ball pocketed, no rail after contact, the object path or the cue path after contact through another ball, and `SimulationTimeout`.
- **Determinism.** No randomness and no wall clock in `lib/domain`. Jobs read a `Stopwatch` only to decide *when* to yield. Sliced and one-shot runs must give the same result.
- **Layering.** `lib/domain/planner/` never imports `package:flutter`; `lib/domain/table_geometry/` never imports `lib/domain/table_physics/` (architecture tests).
- **Terms on screen, exactly:** **Bị đui** · **Đối thủ bị đui** · **A băng** (cue ball hits the rail *before* the ball; not *Dội băng*) · **Chấm** (long rails 0–8, short rails 0–4) · **Băng dài trên / dưới** · **Băng ngắn trái / phải** · **Thủ bi** · **Chơi an toàn (safety)** · **"Ăn ½ bi, lệch bên trái"**. Old terms unchanged: **Đánh đứng bi · Đánh trô bi · Đánh cu lê**, **Áp phê**, **Lệch N đầu cơ**, **Bi ảo**, **Dội băng**, **Chết cái**.
- **Strings.** All visible text lives in `lib/core/strings/vi.dart`. Sentences with numbers are templates filled from the core (memory: no-fabricated-generated-content). The architecture test fails on Vietnamese literals in `lib/features`.
- **No degree aim instructions** reach the screen (memory: poolcoachai-executable-advice). The only degree number added is the opponent's cut angle (spec decision 9), which is information, not aim advice. Áp phê advice reuses the simulator's line: đầu cơ, phần con bi, SAWS BHE/FHE.
- **Tests and constants.** Tests reference constants by name, never their values. Fixture expectations that depend on today's physics say "đo trên a35667b" or "kiểm bằng nguyên mẫu" in a comment.
- **Riverpod pitfalls** (memory: poolcoachai-riverpod-drift-test-patterns): never `await container.read(x.future)`; app widget tests use `UncontrolledProviderScope` with `testContainer()`; never `ProviderScope(overrides: [...])` with an explicit `List<Override>`.
- **Comments** follow the surrounding code: Vietnamese, explaining *why*.
- **Commit messages** are plain English sentences and end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Line endings.** The repo checks out with `core.autocrlf=true`. Do not convert line endings by hand.

## Review Focus

1. **Changing the stroke, power or a ball while *Chờ* is computing, or while the question is shown.**
   - Expected: the late result never lands on the new shot, and a new timeout asks again.
   - Owner: Task 18 (`đổi kiểu đánh trong lúc chờ: kết quả cũ không đè lên cú mới`).
2. **Leaving the planner, pressing *Sửa bàn*, or re-placing the cue ball while the safety search runs.**
   - Expected: the search is cancelled, no `setState` after dispose, no step appears later.
   - Owner: Task 24 (`hủy giữa lúc tìm cú thủ thì không báo thêm gì`) and Task 27 (`rời màn giữa lúc tìm cú thủ: không lỗi`).
3. **The cue ball frozen against the legal ball, or the legal ball frozen on a rail.**
   - Expected: classification and option lists do not throw; the search ends with a shot or with `null`.
   - Owner: Task 19 (`bi cái sát bi hợp lệ: phân loại không lỗi`) and Task 22 (`bi hợp lệ sát băng: tìm xong, không lỗi`).
4. **8-ball where the opponent has no balls left, with or without the 8 on the table.**
   - Expected: the opponent targets the 8; with no 8 either, *"Đối thủ không còn đường ăn."*, no crash.
   - Owner: Task 21 (`8 bi: đối thủ hết bi thì đánh bi 8; không còn bi nào thì không lỗi`).
5. **Power 90 % plus jitter in a safety.**
   - Expected: no 105 % simulation, and the tolerance line still counts out of 7.
   - Owner: Task 21 (`lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức`).

---

## File map

| File | Responsibility |
|---|---|
| `lib/domain/planner/planner_constants.dart` | `sliceBudget` 4 ms; the safety constants |
| `lib/domain/table_physics/constants.dart` | `extendedSimTime` |
| `lib/domain/table_physics/simulate_shot.dart` | `maxTime` on `simulateShot`; `KickProbe`, `probeKick` |
| `lib/domain/table_physics/aim.dart` | `maxTime` on `aimShot` / `AimShotFn`; public `solveStun`, `topspinOf`, `strokeVerticalOffset` |
| `lib/domain/planner/safety_shot.dart` | `SafetyReason`, `SafetyKind`, `ThicknessSide`, `RailAim`, `OpponentView`, `SafetyShot` |
| `lib/domain/planner/safety_geometry.dart` | `leftOf`, `contactLateral`, `directContact`, `canSee`, `openContacts`, contact orders, `railSequences`, `mirrorAcross`, `inPocketMouth`, `KickPath`, `kickPath`, `diamondOf`, `nearRail`, `lateralAt` |
| `lib/domain/planner/safety_options.dart` | `SafetyContext` (classification), `SafetyOption`, `directOption`, `directOptions` |
| `lib/domain/planner/kick_search.dart` | `kickOption`, `kickOptions` |
| `lib/domain/planner/safety_aim.dart` | `SafetyPhysics`, `SimKey`, `AimResult`, `refineContact`, `aimSafety`, `simulateSafety`, `aimOffsetDegOf` |
| `lib/domain/planner/safety_rules.dart` | `SafetyFoul`, `safetyFoulOf` |
| `lib/domain/planner/safety_scoring.dart` | `opponentTargets`, `opponentView`, `SafetyLevel`, `levelOf`, penalties, `scoreFloor`, `SafetyLookup`, `DirectSafetyLookup`, `SafetyEval`, `evaluateOption`, `beats`, `safetyToleranceOf`, `buildSafetyShot` |
| `lib/domain/planner/safety_job.dart` | `SafetyJob`, `searchToEnd` |
| `lib/domain/planner/plan_step.dart` | `PlanStep.safety` field |
| `lib/domain/planner/planner_job.dart` | hands the safety step to a `SafetyJob`; `searchingSafety`; `safety` physics |
| `lib/core/strings/vi.dart` | simulator wait strings (`simCannotSimulate` removed), safety strings, `planSummary` |
| `lib/features/training/presentation/simulator/info_lines.dart` | `SimTimeoutState`, `simTimeoutLine`, `squirtLineFor` |
| `lib/features/training/presentation/simulator/simulator_panel.dart` | *Chờ* / *Chỉ vẽ đường ngắm* buttons |
| `lib/features/training/presentation/simulator/simulator_screen.dart` | the wait flow |
| `lib/features/training/presentation/planner/step_lines.dart` | safety lines |
| `lib/features/training/presentation/planner/planner_painter.dart` | safety layers, *chấm* numbers |
| `lib/features/training/presentation/planner/planner_steps_view.dart` | *Đang tìm cú thủ…*, the touched ball, legend, `safety` passthrough |
| `test/support/planner_tables.dart` | safety fixtures, `noSafetyPhysics`, `safetyFingerprint`, fakes with `maxTime` |
| `test/domain/planner/safety_*_test.dart` | geometry, aim, scoring, options, job, spec §9.1, probe, perf |
| `tool/e2e/planner.mjs` | three safety tables, safety timing gate |
| `PRD_RunOutPlanner.md` | spec §8 amendments |
| `docs/superpowers/logs/2026-10-07-run-out-planner.md` | slice decision, safety measurements, eye check |

---

### Task 16: Slice the planner at 4 ms (owner decision)

**Files:**
- Modify: `lib/domain/planner/planner_constants.dart:72-73`
- Modify: `lib/features/training/presentation/planner/planner_steps_view.dart:62-63` (comment only)
- Create or modify: `docs/superpowers/logs/2026-10-07-run-out-planner.md`

**Interfaces:**
- Consumes: nothing new.
- Produces: `sliceBudget == Duration(milliseconds: 4)`. `PlannerJob.step`, `SafetyJob.step` (Task 22) and the perf gate `median < 1.5 × sliceBudget` (now 6 ms) read it.

The owner chose 4 ms after Task 14's clean Chrome re-measurement (`.superpowers/sdd/2026-10-07-poolcoachai-run-out-planner/task-14-measure-report.md` in the main checkout):
- 4 ms met the frame gate (median ≤ 17 ms, p95 ≤ 20 ms) in all 7 quiet computing windows (3 with semantics off, 4 on), with 0.5–1.8 % of frames over 20 ms and step 1 at 363–458 ms.
- 8 ms met it in 3 of 7 quiet windows, with 5.2–7.1 % of frames over 20 ms.
- A Web Worker is a separate project after merge.

- [ ] **Step 1: Change the constant**

Replace the last two lines of `planner_constants.dart`:

```dart
/// Mỗi lát tính giữa hai khung hình (spec quyết định 4). 4 ms, không phải
/// 8 ms như spec gốc: đo sạch trên Chrome (task 14), 4 ms qua cổng khung
/// hình (trung vị ≤ 17 ms, p95 ≤ 20 ms) ở cả 7 lượt yên máy, 8 ms chỉ 3/7;
/// bước 1 vẫn 0,36–0,46 s. Chủ sản phẩm chốt 07/10/2026.
const sliceBudget = Duration(milliseconds: 4);
```

- [ ] **Step 2: Fix the zone-budget comment that the change makes false**

In `planner_steps_view.dart`, replace the two comment lines above `static const _zoneBudget`:

```dart
  /// Ngân sách lưới vùng điều mỗi khung hình, bằng `sliceBudget`: cùng
  /// khung hình còn một lát kế hoạch và phần vẽ, cộng lại vẫn dưới 16 ms.
```

- [ ] **Step 3: Run the perf test alone**

Run: `"$FLUTTER" test --tags perf --run-skipped test/domain/planner/planner_perf_test.dart`
Expected: PASS. The gate is derived (`sliceBudget × 1.5` = 6 ms), so the test code does not change. At plan time the medians read 3.4–5.4 ms. If it fails with a median near 9 ms, the CPU is shared: close other work and rerun alone before reporting. Copy the printed `lát: …` line for Step 5.

- [ ] **Step 4: Run the planner tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner test/features/training && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`.

- [ ] **Step 5: Record the decision in the build log**

If `docs/superpowers/logs/2026-10-07-run-out-planner.md` does not exist yet (Task 14 Step 5 creates it), create it with this content; otherwise append the `## Slice budget` section at the end:

```markdown
# Kế hoạch dọn bàn — build log

Plans: `docs/superpowers/plans/2026-10-07-poolcoachai-run-out-planner.md`, `docs/superpowers/plans/2026-10-07-poolcoachai-planner-safety.md`.

## Slice budget (owner decision, 2026-10-07)

- `sliceBudget`: 8 ms → **4 ms**. This supersedes the 8 ms in spec §3 of the run-out planner design.
- Evidence (`.superpowers/sdd/2026-10-07-poolcoachai-run-out-planner/task-14-measure-report.md`, Chrome, table 2, quiet windows):
  - 4 ms: frame median 16.7 ms, p95 16.8–17.0 ms; passed in 7 of 7 computing windows (3 semantics off, 4 on); 0.5–1.8 % of frames over 20 ms; step 1 at 363–458 ms; plan done in 2.7–3.6 s.
  - 8 ms: passed in 3 of 7; 5.2–7.1 % of frames over 20 ms; step 1 at 213–320 ms.
  - Under CPU contention every configuration fails; single 33 ms frames remain from indivisible `aimShot` units.
- Dart VM after the change (`planner_perf_test`): <paste the `lát: …` line from Task 16 Step 3>.
- Next step if the owner wants zero jank on mid-range phones: a Web Worker, as a separate project after merge.
```

Fill the `<…>` with the line printed in Step 3. When Task 14 Step 5 later writes its sections, it adds them to this same file.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/planner/planner_constants.dart lib/features/training/presentation/planner/planner_steps_view.dart docs/superpowers/logs/2026-10-07-run-out-planner.md
git commit -m "Slice the planner at 4 ms, which held the Chrome frame gate in every clean window

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Time limits, a kick probe and a public stun solver in the physics core

**Files:**
- Modify: `lib/domain/table_physics/constants.dart` (add `extendedSimTime` after `maxSimTime`)
- Modify: `lib/domain/table_physics/simulate_shot.dart` (`simulateShot`, `_Run`, `probeContact`; add `KickProbe`, `probeKick`)
- Modify: `lib/domain/table_physics/aim.dart` (`strokeVerticalOffset`, `topspinOf`, `solveStun`, `maxTime` on `aimShot` and `AimShotFn`)
- Modify: `test/support/planner_tables.dart` (three fakes), `test/features/training/simulator_screen_test.dart` (three fakes)
- Test: `test/domain/table_physics/simulate_shot_test.dart`, `test/domain/table_physics/aim_test.dart`

**Interfaces:**
- Consumes: `_Run`, `probeContact`, `_solveStun`, `topspinAtContact` (existing).
- Produces:
  - `const extendedSimTime = 3 * maxSimTime;`
  - `ShotTrace simulateShot(ShotInput input, {void Function(BallState cue, BallState object)? onStep, double maxTime = maxSimTime})`
  - `class KickProbe { const KickProbe({required BallState? cueAtContact, required List<Rail> railsBefore, required Pocket? cuePocket}); }`
  - `KickProbe probeKick(ShotInput input, {required int maxRails, double maxTime = maxSimTime})` — simulates until the cue ball touches the object ball, allowing up to `maxRails` cue rails before contact.
  - `double strokeVerticalOffset(Stroke stroke, double radius)`
  - `double topspinOf(BallState s)`
  - `(ShotInput, bool) solveStun(ShotInput input, {double? Function(ShotInput input) topspin = topspinAtContact})`
  - `aimShot(..., double maxTime = maxSimTime)` and `typedef AimShotFn` with the same extra `double maxTime` parameter.

- [ ] **Step 1: Write the failing physics tests**

Append inside `main()` of `test/domain/table_physics/simulate_shot_test.dart`, after the `probeContact` group:

```dart
  group('giới hạn thời gian mô phỏng (spec cú phòng thủ mục 7)', () {
    test('mặc định là maxSimTime; giới hạn ngắn hơn thì ném SimulationTimeout', () {
      final input = shot(const Vec2(60, 63.5), const Vec2(127, 63.5), power: 90);
      expect(() => simulateShot(input), returnsNormally);
      expect(() => simulateShot(input, maxTime: 0.05), throwsA(isA<SimulationTimeout>()));
    });

    test('chờ thì giới hạn gấp ba maxSimTime', () {
      expect(extendedSimTime, 3 * maxSimTime);
    });
  });

  group('probeKick', () {
    // Bi cái và bi mục tiêu cùng y = 80: ngắm điểm soi gương qua băng dài
    // trên. Đo trên a35667b: cu lê 60 % chạm bi sau đúng một băng.
    const cue = Vec2(30, 80);
    const object = Vec2(180, 80);
    final image = Vec2(object.x, 2 * table.minY - object.y);

    test('không chạm băng thì giống probeContact', () {
      final input = shot(const Vec2(60, 63.5), const Vec2(127, 63.5));
      final kick = probeKick(input, maxRails: 0);
      expect(kick.cueAtContact!.pos, probeContact(input)!.cueAtContact.pos);
      expect(kick.railsBefore, isEmpty);
      expect(kick.cuePocket, isNull);
    });

    test('đi qua một băng rồi chạm bi: ghi đúng băng, probeContact coi là hỏng', () {
      final input = shot(cue, object, toward: image, power: 60, b: strokeOffset * radius);
      final kick = probeKick(input, maxRails: 1);
      expect(kick.railsBefore, [Rail.top]);
      expect(kick.cueAtContact, isNotNull);
      expect(probeContact(input), isNull);
    });

    test('chạm quá số băng cho phép thì dừng, không chạm bi', () {
      final input = shot(cue, object, toward: image, power: 60, b: strokeOffset * radius);
      final kick = probeKick(input, maxRails: 0);
      expect(kick.railsBefore, [Rail.top]);
      expect(kick.cueAtContact, isNull);
    });
  });
```

Add `import 'package:poolcoachai/domain/table_physics/cushion.dart';` to the file's imports.

Append inside `main()` of `test/domain/table_physics/aim_test.dart`:

```dart
  group('dùng chung cho Planner thủ bi (spec cú phòng thủ)', () {
    test('aimShot nhận giới hạn thời gian; mặc định maxSimTime', () {
      AimedShot run([double maxTime = maxSimTime]) => aimShot(
          cue: const Vec2(60, 63.5),
          object: const Vec2(127, 63.5),
          pocket: Pocket.topRight,
          stroke: Stroke.stun,
          power: 90,
          maxTime: maxTime);
      expect(() => run(), returnsNormally);
      expect(() => run(0.05), throwsA(isA<SimulationTimeout>()));
    });

    test('kiểu đánh ra b: cu lê trên tâm, trô dưới tâm, đứng bi bắt đầu từ tâm', () {
      const r = 2.8575;
      expect(strokeVerticalOffset(Stroke.follow, r), strokeOffset * r);
      expect(strokeVerticalOffset(Stroke.draw, r), -strokeOffset * r);
      expect(strokeVerticalOffset(Stroke.stun, 0), 0);
    });

    test('solveStun với hàm đo xoáy mặc định cho đúng kết quả cũ', () {
      final input = ShotInput(
        cue: const Vec2(40, 63.5),
        object: const Vec2(160, 63.5),
        aimAngle: 0,
        power: 45,
        elevation: CueElevation.normal.radians,
      );
      final (a, reachedA) = solveStun(input);
      final (b, reachedB) = solveStun(input, topspin: topspinAtContact);
      expect(a.verticalOffset, b.verticalOffset);
      expect(reachedA, reachedB);
      expect(topspinOf(probeContact(a)!.cueAtContact).abs(), lessThan(stopSpin));
    });
  });
```

Add the imports the new tests need if missing: `constants.dart`, `cue_strike.dart`, `simulate_shot.dart`.

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/table_physics/simulate_shot_test.dart test/domain/table_physics/aim_test.dart`
Expected: compile errors: `extendedSimTime`, `maxTime`, `probeKick`, `Rail` usage, `strokeVerticalOffset`, `solveStun`, `topspinOf` are not defined.

- [ ] **Step 3: Add the constant**

In `constants.dart`, directly after `maxSimTime`:

```dart
/// Màn mô phỏng: người chơi bấm *Chờ* thì tính lại với giới hạn này
/// (spec cú phòng thủ mục 7). Planner không bao giờ chờ.
const extendedSimTime = 3 * maxSimTime;
```

- [ ] **Step 4: Add the time limit and the kick probe to `simulate_shot.dart`**

1. Replace `simulateShot`:

```dart
/// Mô phỏng tới khi cả hai bi đứng hẳn hoặc rơi lỗ (spec mục 4.5).
///
/// Tất định: cùng [input] thì cùng trace. [onStep] (cho test) nhận trạng
/// thái hai bi sau mỗi bước. Quá [maxTime] giây mô phỏng thì ném
/// [SimulationTimeout]; màn mô phỏng truyền `extendedSimTime` khi người
/// chơi chọn *Chờ*.
ShotTrace simulateShot(
  ShotInput input, {
  void Function(BallState cue, BallState object)? onStep,
  double maxTime = maxSimTime,
}) {
  final run = _Run(input, record: true, onStep: onStep, maxTime: maxTime);
  run.go(untilContact: false);
  return run.trace();
}
```

2. After `probeContact`, add:

```dart
/// Hai thứ Planner thủ bi cần để dò cú A băng: bi cái lúc chạm bi mục tiêu
/// (null nếu không chạm), các băng bi cái chạm trước đó, và lỗ nếu bi cái
/// rơi trước khi chạm.
class KickProbe {
  const KickProbe({
    required this.cueAtContact,
    required this.railsBefore,
    required this.cuePocket,
  });

  final BallState? cueAtContact;
  final List<Rail> railsBefore;
  final Pocket? cuePocket;
}

/// Như [probeContact] nhưng cho bi cái chạm tới [maxRails] băng trước khi
/// chạm bi mục tiêu (spec cú phòng thủ mục 3.4). Chạm băng thứ
/// [maxRails] + 1 thì dừng ngay: đường đó đã sai chuỗi băng. [maxRails] = 0
/// là cú thẳng.
KickProbe probeKick(ShotInput input,
    {required int maxRails, double maxTime = maxSimTime}) {
  final run = _Run(input, record: false, maxTime: maxTime);
  run.go(untilContact: true, railsAllowed: maxRails);
  return KickProbe(
    cueAtContact: run.probe?.cueAtContact,
    railsBefore: [
      for (final h in run.rails)
        if (h.ball == ShotBall.cue && !h.afterContact) h.rail,
    ],
    cuePocket: run.cue.pocket,
  );
}
```

3. In `_Run`, add a `maxTime` parameter and field, and a rail allowance to `go`:

```dart
  _Run(this.input, {required this.record, this.onStep, this.maxTime = maxSimTime})
```

```dart
  final double maxTime;
```

```dart
  void go({required bool untilContact, int railsAllowed = 0}) {
    var steps = 0;
    final maxSteps = (maxTime / timeStep).round();
    while (cue.moving || object.moving) {
      if (steps++ >= maxSteps) throw SimulationTimeout(input);
      _step();
      // Dò chạm: dừng khi chạm bi, hoặc khi chạm quá số băng cho phép
      // (cú thẳng: băng đầu tiên đã là hỏng).
      if (untilContact && (contact != null || rails.length > railsAllowed)) return;
```

The rest of `go` stays as it is. `probeContact` keeps calling `run.go(untilContact: true)`; with `railsAllowed = 0` the stop condition equals the old `contact != null || rails.isNotEmpty`.

- [ ] **Step 5: Make the stun solver public and add the time limit to `aim.dart`**

1. Add `import 'package:poolcoachai/domain/table_physics/ball_state.dart';`.
2. Add, above `solveAim`:

```dart
/// `b` ban đầu của kiểu đánh, cm: cu lê trên tâm, trô dưới tâm. Đánh đứng
/// bi bắt đầu từ tâm rồi mới dò ([solveStun]).
double strokeVerticalOffset(Stroke stroke, double radius) => switch (stroke) {
      Stroke.follow => strokeOffset * radius,
      Stroke.draw => -strokeOffset * radius,
      Stroke.stun => 0,
    };
```

3. In `solveAim`, replace the `verticalOffset: switch (stroke) {…},` argument with `verticalOffset: strokeVerticalOffset(stroke, radius),`, and both `_solveStun(input)` calls with `solveStun(input)`.
4. Replace `topspinAtContact` and `_solveStun` with:

```dart
/// Xoáy dọc (trên +, dưới −) của bi cái ở trạng thái [s], rad/s.
double topspinOf(BallState s) {
  final dir = s.vel.normalized;
  // Xoáy lăn đều là ẑ × v / R: chiếu xoáy lên ẑ × v̂.
  return -s.spin.x * dir.y + s.spin.y * dir.x;
}

/// Xoáy dọc của bi cái lúc chạm, rad/s; null nếu trượt.
double? topspinAtContact(ShotInput input) {
  final probe = probeContact(input);
  return probe == null ? null : topspinOf(probe.cueAtContact);
}

/// Đánh đứng bi: `b ∈ [−stunMaxOffset·R, 0]` để bi cái tới bi mục tiêu
/// đúng lúc hết xoáy dọc (spec quyết định 10).
///
/// [topspin] đo xoáy lúc chạm cho một `b`; mặc định là cú thẳng. Planner
/// thủ bi truyền hàm đo sau đúng chuỗi băng của cú A băng.
///
/// Xoáy lúc chạm gần như tuyến tính theo `b` (thời gian tới bi mục tiêu
/// không phụ thuộc xoáy khi còn trượt), nên dò kiểu chia đôi có nội suy
/// (Illinois): giữ khoảng kẹp như chia đôi nhưng 2–4 vòng là đủ.
///
/// Trả thêm false khi chạm sàn `b` mà bi cái vẫn tới nơi còn xoáy trên.
(ShotInput, bool) solveStun(ShotInput input,
    {double? Function(ShotInput input) topspin = topspinAtContact}) {
  final lo = -stunMaxOffset * input.table.radius;
  double? f(double b) => topspin(input.copyWith(verticalOffset: b));
```

The body after that line is the old `_solveStun` body, unchanged from `final fHi = f(0);` to the final `return`.

5. Add `double maxTime,` as the last parameter of `typedef AimShotFn`, and `double maxTime = maxSimTime,` as the last parameter of `aimShot`. In `aimShot`'s body use `simulateShot(s.aimed, maxTime: maxTime)` and `simulateShot(s.geometric, maxTime: maxTime)`. Add to `aimShot`'s doc comment:

```dart
/// [maxTime] là giới hạn giây mô phỏng của hai lần mô phỏng đủ; dò bù
/// ném chỉ chạy tới lúc chạm nên không cần.
```

- [ ] **Step 6: Give every `AimShotFn` fake the new parameter**

In `test/support/planner_tables.dart` (`scratchingAim`, `timeoutAim`, `recordingAim`) and in the three fakes of `test/features/training/simulator_screen_test.dart` (`flaky`, `timesOut`, `counting`):
- add `double maxTime = maxSimTime,` after `bool withUncompensated = true,`;
- where the fake calls `aimShot(...)`, add `maxTime: maxTime`.

Add `import 'package:poolcoachai/domain/table_physics/constants.dart';` to both files.

- [ ] **Step 7: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/table_physics test/domain/planner test/features/training && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`. If `đi qua một băng rồi chạm bi` fails, the physics constants changed since `a35667b`: find a power where `probeKick(..., maxRails: 1)` reports `[Rail.top]` with a contact (the probe printed 45, 60, 75, 90 % for follow on `a35667b`), and update the test's comment with the new measurement.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/table_physics test/domain/table_physics test/support/planner_tables.dart test/features/training/simulator_screen_test.dart
git commit -m "Add a time limit to simulateShot and aimShot, a kick probe, and a public stun solver for the safety search

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: *Chờ / Chỉ vẽ đường ngắm* when the simulator times out (spec §7)

**Files:**
- Modify: `lib/core/strings/vi.dart` (remove `simCannotSimulate`; add the wait strings; `simSummary` takes `notice`)
- Modify: `lib/features/training/presentation/simulator/info_lines.dart` (`SimTimeoutState`, `simTimeoutLine`; `simulatorInfoLines` takes `timeout`)
- Modify: `lib/features/training/presentation/simulator/simulator_panel.dart` (buttons)
- Modify: `lib/features/training/presentation/simulator/simulator_screen.dart` (`_aimFor`, `_wait`, `_aimOnly`, build)
- Test: `test/core/strings/vi_simulator_test.dart`, `test/features/training/simulator_screen_test.dart`

**Interfaces:**
- Consumes: `aimShot(..., maxTime:)`, `AimShotFn`, `extendedSimTime` (Task 17).
- Produces:
  - `enum SimTimeoutState { none, asking, waiting, tooLong, aimOnly }` and `String? simTimeoutLine(SimTimeoutState s)` in `info_lines.dart`.
  - `simulatorInfoLines({..., SimTimeoutState timeout = SimTimeoutState.none, ...})` (replaces `bool cannotSimulate`).
  - `SimulatorPanel({..., SimTimeoutState timeout = SimTimeoutState.none, VoidCallback? onWait, VoidCallback? onAimOnly, ...})`, with `SimulatorPanel.waitKey` and `SimulatorPanel.aimOnlyKey`.
  - `Vi.simTimeoutQuestion`, `Vi.simWait`, `Vi.simAimOnly`, `Vi.simAimOnlyLine`, `Vi.simTooLong`; `Vi.simSummary(shot, aimed, {required elevation, bool showingUncompensated = false, String? notice})`.
  - `Vi.simCannotSimulate` no longer exists.

- [ ] **Step 1: Write the failing string tests**

In `test/core/strings/vi_simulator_test.dart`, replace the test `'lõi không mô phỏng được: nói thẳng, không có số nào của lõi'` with:

```dart
    test('lõi quá giờ: câu hỏi chờ nằm cuối nhãn, không có số nào của lõi', () {
      expect(
          Vi.simSummary(const Makeable(g), null,
              elevation: CueElevation.normal, notice: Vi.simTimeoutQuestion),
          'Bàn mô phỏng. Lỗ góc trên phải, góc cắt 7°, Dễ. Độ dốc cơ: '
          'Thường. ${Vi.simTimeoutQuestion}');
    });

    test('câu quá giờ đúng chữ đã chốt (spec cú phòng thủ mục 7)', () {
      expect(Vi.simTimeoutQuestion,
          'Cú này tính quá lâu, bạn muốn chờ hay bỏ qua chỉ vẽ đường ngắm?');
      expect(Vi.simWait, 'Chờ');
      expect(Vi.simAimOnly, 'Chỉ vẽ đường ngắm');
      expect(Vi.simAimOnlyLine, 'Chỉ vẽ đường ngắm.');
      expect(Vi.simTooLong, 'Cú này quá dài để mô phỏng.');
      expect(Vi.simComputing, 'Đang tính…');
    });
```

- [ ] **Step 2: Write the failing screen tests**

In `test/features/training/simulator_screen_test.dart`:
1. Add `import 'package:poolcoachai/domain/table_physics/constants.dart';` if Task 17 did not.
2. Replace the test `'lõi quá maxSimTime: chỉ vẽ hình học, báo một dòng, không vỡ'` with the group below. It reuses the file's `openWithAim`, `sceneOf`, `tapText` and `initial`.

```dart
  group('lõi quá giờ: Chờ hay Chỉ vẽ đường ngắm (spec cú phòng thủ mục 7)', () {
    /// aimShot thật, nhưng ở giới hạn mặc định thì cú khớp [slow] quá giờ;
    /// [alwaysSlow] thì quá giờ cả khi chờ. Ghi lại giới hạn của mọi lần gọi.
    AimShotFn slowAim(List<double> limits,
            {bool Function(Stroke stroke)? slow, bool alwaysSlow = false}) =>
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
          limits.add(maxTime);
          final isSlow = (slow ?? (_) => true)(stroke);
          if (isSlow && (alwaysSlow || maxTime < extendedSimTime)) {
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

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
    }

    testWidgets('hỏi Chờ hay Chỉ vẽ đường ngắm, bàn tạm vẽ đường ngắm, không vỡ',
        (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits));
      expect(tester.takeException(), isNull);
      expect(sceneOf(tester).geometry, isNotNull);
      expect(sceneOf(tester).aimed, isNull);
      expect(find.text(Vi.simTimeoutQuestion), findsOneWidget);
      expect(find.byKey(SimulatorPanel.waitKey), findsOneWidget);
      expect(find.byKey(SimulatorPanel.aimOnlyKey), findsOneWidget);
      expect(find.text(Vi.simPocketLine(initial.pocket)), findsOneWidget);
      expect(limits, everyElement(maxSimTime));
    });

    testWidgets('Chờ: vẽ Đang tính… trước, rồi tính lại gấp ba và vẽ đủ', (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits));
      await tapKey(tester, SimulatorPanel.waitKey);

      // Khung hình đầu chỉ vẽ chữ báo; chưa gọi lõi với giới hạn dài.
      await tester.pump();
      expect(find.text(Vi.simComputing), findsOneWidget);
      expect(find.text(Vi.simTimeoutQuestion), findsNothing);
      expect(limits, isNot(contains(extendedSimTime)));

      // Lần tính chạy trong Timer sau khung hình: pump có thời lượng mới chạy Timer.
      await tester.pump(Duration.zero);
      expect(limits.last, extendedSimTime);
      expect(sceneOf(tester).aimed, isNotNull);
      expect(find.text(Vi.simComputing), findsNothing);
      expect(find.byKey(SimulatorPanel.waitKey), findsNothing);
    });

    testWidgets('Chờ mà vẫn quá giờ: báo quá dài, giữ đường ngắm', (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits, alwaysSlow: true));
      await tapKey(tester, SimulatorPanel.waitKey);
      await tester.pump();
      await tester.pump(Duration.zero);
      expect(limits.last, extendedSimTime);
      expect(find.text(Vi.simTooLong), findsOneWidget);
      expect(sceneOf(tester).aimed, isNull);
      expect(find.byKey(SimulatorPanel.waitKey), findsNothing);
    });

    testWidgets('Chỉ vẽ đường ngắm: giữ đường ngắm, câu đổi thành Chỉ vẽ đường ngắm.',
        (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits));
      await tapKey(tester, SimulatorPanel.aimOnlyKey);
      await tester.pumpAndSettle();
      expect(find.text(Vi.simAimOnlyLine), findsOneWidget);
      expect(find.text(Vi.simTimeoutQuestion), findsNothing);
      expect(sceneOf(tester).aimed, isNull);
      expect(limits, everyElement(maxSimTime));
    });

    testWidgets('không nhớ lựa chọn: đổi kiểu đánh thì câu hỏi biến mất, cú quá giờ mới hỏi lại',
        (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits, slow: (s) => s == Stroke.stun));
      await tapKey(tester, SimulatorPanel.aimOnlyKey);
      await tester.pumpAndSettle();

      await tapText(tester, Vi.simStroke(Stroke.draw));
      expect(find.text(Vi.simAimOnlyLine), findsNothing);
      expect(find.text(Vi.simTimeoutQuestion), findsNothing);
      expect(sceneOf(tester).aimed, isNotNull);

      await tapText(tester, Vi.simStroke(Stroke.stun));
      expect(find.text(Vi.simTimeoutQuestion), findsOneWidget);
    });

    testWidgets('đổi kiểu đánh trong lúc chờ: kết quả cũ không đè lên cú mới', (tester) async {
      final limits = <double>[];
      await openWithAim(tester, slowAim(limits, slow: (s) => s == Stroke.stun));
      await tapKey(tester, SimulatorPanel.waitKey);
      await tester.pump();
      // Chưa tính xong thì đổi sang trô: lần chờ cũ phải bỏ.
      await tapText(tester, Vi.simStroke(Stroke.draw));
      expect(limits, isNot(contains(extendedSimTime)));
      expect(find.text(Vi.simStrokeLine(Stroke.draw)), findsOneWidget);
      expect(find.text(Vi.simComputing), findsNothing);
    });
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `"$FLUTTER" test test/core/strings/vi_simulator_test.dart test/features/training/simulator_screen_test.dart`
Expected: compile errors (`Vi.simTimeoutQuestion`, `SimulatorPanel.waitKey`, `notice` not defined).

- [ ] **Step 4: Strings**

In `vi.dart`:
1. Delete `simCannotSimulate`.
2. Add after `simShowingUncompensated`:

```dart
  // Lõi quá maxSimTime — docs/superpowers/specs/2026-10-07-poolcoachai-planner-safety-design.md mục 7.
  static const simTimeoutQuestion =
      'Cú này tính quá lâu, bạn muốn chờ hay bỏ qua chỉ vẽ đường ngắm?';
  static const simWait = 'Chờ';
  static const simAimOnly = 'Chỉ vẽ đường ngắm';
  static const simAimOnlyLine = 'Chỉ vẽ đường ngắm.';
  static const simTooLong = 'Cú này quá dài để mô phỏng.';
```

3. In `simSummary`, replace the parameter `bool cannotSimulate = false,` with `String? notice,` and the list element `if (cannotSimulate) simCannotSimulate,` with `?notice,` (a null-aware element; the analyzer's `use_null_aware_elements` lint rejects the `if` form). Update its doc comment: "[notice] là câu về lõi quá giờ (`simTimeoutLine`), null khi không có."

- [ ] **Step 5: Info lines**

In `info_lines.dart`, add above `simulatorInfoLines`:

```dart
/// Lõi quá giờ cho cú đang xem (spec cú phòng thủ mục 7): đang hỏi, đang
/// chờ tính lại, chờ rồi vẫn quá giờ, hay người chơi chọn chỉ vẽ đường ngắm.
enum SimTimeoutState { none, asking, waiting, tooLong, aimOnly }

/// Câu của bảng thông tin cho [s]; null khi không quá giờ.
String? simTimeoutLine(SimTimeoutState s) => switch (s) {
      SimTimeoutState.none => null,
      SimTimeoutState.asking => Vi.simTimeoutQuestion,
      SimTimeoutState.waiting => Vi.simComputing,
      SimTimeoutState.tooLong => Vi.simTooLong,
      SimTimeoutState.aimOnly => Vi.simAimOnlyLine,
    };
```

In `simulatorInfoLines`:
- replace the parameter `bool cannotSimulate = false,` with `SimTimeoutState timeout = SimTimeoutState.none,`;
- replace `if (cannotSimulate) Vi.simCannotSimulate,` with `?simTimeoutLine(timeout),`;
- in the doc comment, replace the sentence about `[cannotSimulate]` with "[timeout] là trạng thái lõi quá giờ ([aimed] khi đó null)."

- [ ] **Step 6: Panel buttons**

In `simulator_panel.dart`:
1. Replace `this.cannotSimulate = false,` with `this.timeout = SimTimeoutState.none, this.onWait, this.onAimOnly,`.
2. Replace the field `cannotSimulate` and its comment with:

```dart
  /// Khoá hai nút khi lõi quá giờ, cho test.
  static const waitKey = Key('simulator-wait');
  static const aimOnlyKey = Key('simulator-aim-only');

  /// Lõi quá giờ cho cú này (spec cú phòng thủ mục 7).
  final SimTimeoutState timeout;
  final VoidCallback? onWait;
  final VoidCallback? onAimOnly;
```

3. In `build`, pass `timeout: timeout,` instead of `cannotSimulate: cannotSimulate,` to `simulatorInfoLines`, and add after the `for (final line in …)` element inside the card's `Column`:

```dart
                if (timeout == SimTimeoutState.asking)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          key: waitKey,
                          onPressed: onWait,
                          child: const Text(Vi.simWait),
                        ),
                        OutlinedButton(
                          key: aimOnlyKey,
                          onPressed: onAimOnly,
                          child: const Text(Vi.simAimOnly),
                        ),
                      ],
                    ),
                  ),
```

- [ ] **Step 7: The wait flow in the screen**

In `simulator_screen.dart`:
1. Add `import 'dart:async';` and `import 'package:poolcoachai/domain/table_physics/constants.dart';` and `import 'package:poolcoachai/features/training/presentation/simulator/info_lines.dart';`.
2. Add a field after `_aimed`:

```dart
  /// Lõi quá giờ cho cú đang xem. Mỗi cú mới bắt đầu lại từ đầu: không nhớ
  /// lựa chọn Chờ hay Chỉ vẽ đường ngắm (spec cú phòng thủ quyết định 10).
  SimTimeoutState _timeout = SimTimeoutState.none;
```

3. Replace `_aimFor`:

```dart
  /// Cú đã dò cho [g]; null khi lõi quá maxSimTime.
  AimedShot? _aimFor(ShotGeometry g, bool showRed) {
    final key =
        (g.cue, g.object, g.pocket, _stroke, _spin, _power, _elevation, showRed);
    if (key == _aimKey) return _aimed;
    AimedShot? aimed;
    var timeout = SimTimeoutState.none;
    try {
      aimed = _aim(key, maxSimTime);
    } on SimulationTimeout {
      // Quá giờ (spec mục 4.5): không ném tiếp trong build, vẽ hình học
      // và hỏi người chơi có muốn chờ không (spec cú phòng thủ mục 7).
      timeout = SimTimeoutState.asking;
    }
    // Chỉ gán khoá khi đã có kết quả (spec 2026-10-07 mục 8): lỗi khác ném
    // ra giữa chừng mà khoá đã đổi thì lần dựng sau trả nhầm cú cũ dưới
    // khoá mới.
    _aimKey = key;
    _timeout = timeout;
    return _aimed = aimed;
  }

  AimedShot _aim(
          (Vec2, Vec2, Pocket, Stroke, SideSpin, double, CueElevation, bool) key,
          double maxTime) =>
      widget.aim(
        cue: key.$1,
        object: key.$2,
        pocket: key.$3,
        stroke: key.$4,
        spin: key.$5,
        power: key.$6,
        elevation: key.$7,
        table: _table,
        withUncompensated: key.$8,
        maxTime: maxTime,
      );

  /// *Chờ*: vẽ xong khung hình có chữ "Đang tính…" rồi mới tính — tính
  /// ngay trong lúc bấm thì màn đứng 1–3 giây mà không có chữ nào báo.
  /// Lần tính này không chia lát được.
  void _wait() {
    final key = _aimKey;
    if (key == null) return;
    setState(() => _timeout = SimTimeoutState.waiting);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Sau khung hình, nhường trình duyệt vẽ ra màn rồi mới tính.
      Timer.run(() => _computeLonger(key));
    });
  }

  /// Khoá của cú đang chỉnh trên màn, tính từ trạng thái hiện tại — không từ
  /// [_aimKey], vì đổi nút chỉnh chỉ cập nhật [_aimKey] ở lần dựng sau, mà
  /// lần tính chờ có thể chạy trước lần dựng đó.
  (Vec2, Vec2, Pocket, Stroke, SideSpin, double, CueElevation, bool)? _currentKey() {
    final shot = _shot();
    if (shot is! Makeable) return null;
    final g = shot.geometry;
    final showRed = SimulatorScreen.canShowUncompensated(g, _spin) && _showUncompensated;
    return (g.cue, g.object, g.pocket, _stroke, _spin, _power, _elevation, showRed);
  }

  void _computeLonger(
      (Vec2, Vec2, Pocket, Stroke, SideSpin, double, CueElevation, bool) key) {
    // Đã đổi cú hay rời màn trong lúc chờ: bỏ, không đè lên cú mới.
    if (!mounted || key != _currentKey() || _timeout != SimTimeoutState.waiting) return;
    AimedShot? aimed;
    var timeout = SimTimeoutState.none;
    try {
      aimed = _aim(key, extendedSimTime);
    } on SimulationTimeout {
      timeout = SimTimeoutState.tooLong;
    }
    setState(() {
      _aimed = aimed;
      _timeout = timeout;
    });
  }

  void _aimOnly() => setState(() => _timeout = SimTimeoutState.aimOnly);
```

4. In `build`, replace the line `final cannotSimulate = geometry != null && aimed == null;` with:

```dart
    final timeout = geometry == null ? SimTimeoutState.none : _timeout;
```

and:
- `Vi.simSummary(...)`: replace `cannotSimulate: cannotSimulate` with `notice: simTimeoutLine(timeout)`;
- `SimulatorPanel(...)`: replace `cannotSimulate: cannotSimulate,` with `timeout: timeout, onWait: _wait, onAimOnly: _aimOnly,`.

- [ ] **Step 8: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/core/strings test/features/training && "$FLUTTER" analyze && grep -rn "simCannotSimulate\|cannotSimulate" lib test tool || echo "đã bỏ hết"`
Expected: all pass, `No issues found!`, and `đã bỏ hết`.

- [ ] **Step 9: Commit**

```bash
git add lib/core/strings/vi.dart lib/features/training/presentation/simulator test/core/strings/vi_simulator_test.dart test/features/training/simulator_screen_test.dart
git commit -m "Ask whether to wait or just draw the aim line when the simulator times out

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 19: Safety constants, types, geometry and the kick fixtures

**Files:**
- Modify: `lib/domain/planner/planner_constants.dart` (append the safety constants)
- Create: `lib/domain/planner/safety_shot.dart`, `lib/domain/planner/safety_geometry.dart`, `lib/domain/planner/safety_options.dart`
- Modify: `test/support/planner_tables.dart` (fixtures)
- Test: `test/domain/planner/safety_geometry_test.dart`

**Interfaces:**
- Consumes: `isPathClear` (`path_clear.dart`), `TableSpec`, `Vec2`, `Rail`, `BallState`, `legalTargetsAmong`, `obstaclesFor`, `CandidateFinder`, `blockedAngle`, `zoneFair`.
- Produces:
  - constants: `safetyThicknesses`, `kickThicknesses`, `safetySpins`, `kickStrokes`, `kickRailPenalty` (`Map<int, double>`), `maxKickRails`, `kickFallbackRails`, `nearRailBonus`, `nearRailDiameters`, `opponentHardAngle`, `contactTolerance`, `maxContactProbes`, `contactMaxStepDeg`, `contactStartStepDeg`, `longRailDiamonds`, `shortRailDiamonds`.
  - `safety_shot.dart`: `enum SafetyReason { snookered, noPot }`, `enum SafetyKind { direct, kick }`, `enum ThicknessSide { full, left, right }`, `class RailAim({required Rail rail, required double diamond, required Vec2 at})`, `class OpponentView({required bool snookered, PlacedBall? ball, ShotGeometry? easiest})` with `double get part` and `bool get hard`, `class SafetyShot` (fields below).
  - `safety_geometry.dart`: `Vec2 leftOf(Vec2 dir)`, `double contactLateral(double thickness, ThicknessSide side, {TableSpec table})`, `typedef DirectContact = ({double aim, Vec2 contact})`, `DirectContact? directContact(Vec2 cue, Vec2 ball, double lateral, {TableSpec table})`, `bool canSee(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles, {TableSpec table})`, `final List<(double, ThicknessSide)> directContactOrder`, `final List<(double, ThicknessSide)> kickContactOrder`, `List<(double, ThicknessSide)> openContacts(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles, {TableSpec table})`, `List<List<Rail>> railSequences(int count)`, `Vec2 mirrorAcross(Vec2 p, Rail rail, {TableSpec table})`, `bool inPocketMouth(Vec2 p, {TableSpec table})`, `class KickPath({required double aim, required List<Vec2> hits, required Vec2 contact})`, `KickPath? kickPath({required Vec2 cue, required Vec2 ball, required List<Rail> rails, required double lateral, required List<Vec2> obstacles, TableSpec table})`, `double diamondOf(Vec2 hit, Rail rail, {TableSpec table})`, `bool nearRail(Vec2 p, {TableSpec table})`, `double lateralAt(BallState cueAtContact, Vec2 ball)`.
  - `safety_options.dart`: `class SafetyContext({required GameType game, required Vec2 cue, required List<PlacedBall> balls, TableSpec table})` with `balls` (sorted), `legal`, `visible`, `snookered`, `reason`, `obstaclesOf(int ballNum)`, `after(int ballNum, Vec2 to)`; `class SafetyOption` (fields below).
  - fixtures: `snookerOneRailTable()`, `snookerTwoRailTable()`, `snookerThreeRailTable()`, `partlyVisibleTable()`, `noPotTable()`, `eightSafetyTable()`, `jawBlocker(Vec2 ball, Pocket pocket, {double distance = 14})`.

- [ ] **Step 1: Write the failing geometry tests**

`test/domain/planner/safety_geometry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

import '../../support/planner_tables.dart';

/// Hình học của cú phòng thủ (spec cú phòng thủ mục 3.2–3.4, quyết định 5).
void main() {
  const table = TableSpec.nineFoot;
  final d = table.ballDiameter;

  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  /// Số đường A băng hình học còn mở với [count] băng, cả ba điểm chạm.
  int openPaths(TableSetup s, int count) {
    final c = contextOf(s);
    var n = 0;
    for (final target in c.legal) {
      for (final rails in railSequences(count)) {
        for (final (f, side) in kickContactOrder) {
          final path = kickPath(
              cue: c.cue,
              ball: target.pos,
              rails: rails,
              lateral: contactLateral(f, side),
              obstacles: c.obstaclesOf(target.number));
          if (path != null) n++;
        }
      }
    }
    return n;
  }

  test('độ dày ra độ lệch ngang: trọn bi 0, trái dương, phải âm', () {
    expect(contactLateral(1, ThicknessSide.full), 0);
    expect(contactLateral(0.5, ThicknessSide.left), closeTo(d / 2, 1e-12));
    expect(contactLateral(0.5, ThicknessSide.right), closeTo(-d / 2, 1e-12));
    expect(contactLateral(0.125, ThicknessSide.left), closeTo(d * 0.875, 1e-12));
  });

  test('bi ảo theo độ dày: cách tâm bi đúng một đường kính, lệch đúng bên', () {
    const cue = Vec2(30, 80), ball = Vec2(180, 80);
    for (final lateral in [0.0, d / 2, -d / 2, 0.875 * d]) {
      final c = directContact(cue, ball, lateral)!;
      expect(c.contact.distanceTo(ball), closeTo(d, 1e-9));
      final u = (c.contact - cue).normalized;
      expect((c.contact - ball).dot(leftOf(u)), closeTo(lateral, 1e-9));
    }
    // Bi cái đi sang phải màn: bên trái là phía trên (y nhỏ hơn).
    expect(directContact(cue, ball, d / 2)!.contact.y, lessThan(80));
  });

  test('đo độ lệch ở vết thật: dương là bi cái lệch bên trái', () {
    const s = BallState(pos: Vec2(0, -1), vel: Vec2(10, 0));
    expect(lateralAt(s, Vec2.zero), closeTo(1, 1e-12));
  });

  test('bi cái sát bi hợp lệ: phân loại không lỗi', () {
    const ball = Vec2(100, 60);
    final c = SafetyContext(
      game: GameType.nineBall,
      cue: ball + Vec2(d + 0.001, 0),
      balls: const [PlacedBall(number: 1, pos: ball)],
    );
    expect(() => c.snookered, returnsNormally);
    expect(c.snookered, isFalse);
  });

  group('phân loại đui (spec 3.2, test 9.1.1)', () {
    test('bi chắn giữa đường chắn cả trọn bi lẫn hai đường mỏng: đui', () {
      final c = contextOf(snookerOneRailTable());
      expect(c.snookered, isTrue);
      expect(c.reason, SafetyReason.snookered);
    });

    test('hở một mép: không đui, chỉ thử độ dày nhìn thấy được', () {
      final s = partlyVisibleTable();
      final c = contextOf(s);
      expect(c.snookered, isFalse);
      expect(openContacts(c.cue, c.legal.single.pos, c.obstaclesOf(1)),
          [(0.25, ThicknessSide.left), (0.125, ThicknessSide.left)]);
    });

    test('bàn hết đường ăn và bàn 8 bi: không lỗ nào, nhưng thấy bi', () {
      for (final s in [noPotTable(), eightSafetyTable()]) {
        expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls), isNull);
        expect(contextOf(s).snookered, isFalse);
      }
    });

    test('8 bi: đui chỉ khi mọi bi hợp lệ bị chắn', () {
      final s = snookerOneRailTable();
      final c = SafetyContext(game: GameType.eightBall, cue: s.cue, balls: [
        ...s.balls,
        const PlacedBall(number: 3, pos: Vec2(60, 20)),
      ]);
      // Bi 2 (bi chắn) cũng là bi của tôi trong 8 bi, nên còn thấy bi.
      expect(c.legal.map((b) => b.number), [1, 2, 3]);
      expect(c.snookered, isFalse);
    });
  });

  test('chuỗi băng không lặp băng liền nhau: 4, 12, 36, 108', () {
    for (final (n, count) in [(1, 4), (2, 12), (3, 36), (4, 108)]) {
      final seqs = railSequences(n);
      expect(seqs, hasLength(count));
      for (final s in seqs) {
        for (var i = 0; i + 1 < s.length; i++) {
          expect(s[i], isNot(s[i + 1]));
        }
      }
    }
    expect(railSequences(1), [for (final r in Rail.values) [r]]);
  });

  test('soi gương qua băng: đối xứng qua biên tâm bi', () {
    const p = Vec2(100, 40);
    expect(mirrorAcross(p, Rail.top), Vec2(100, 2 * table.minY - 40));
    expect(mirrorAcross(p, Rail.right), Vec2(2 * table.maxX - 100, 40));
  });

  test('miệng lỗ: điểm chạm băng sát lỗ góc bị bỏ, giữa băng thì không', () {
    expect(inPocketMouth(Vec2(table.minX, 5)), isTrue);
    expect(inPocketMouth(Vec2(table.length / 2 + 3, table.minY)), isTrue);
    expect(inPocketMouth(Vec2(table.minX, 63.5)), isFalse);
  });

  group('A băng hình học trên các bàn đui (kiểm bằng nguyên mẫu trên a35667b)', () {
    test('bàn 1 băng: đi băng dài trên chạm đúng giữa hai bi, băng ngắn bị chắn', () {
      final c = contextOf(snookerOneRailTable());
      final top = kickPath(
          cue: c.cue, ball: c.legal.single.pos, rails: const [Rail.top], lateral: 0,
          obstacles: c.obstaclesOf(1))!;
      expect(top.hits.single.x, closeTo(105, 1e-9));
      expect(top.hits.single.y, table.minY);
      for (final r in [Rail.left, Rail.right]) {
        expect(
            kickPath(cue: c.cue, ball: c.legal.single.pos, rails: [r], lateral: 0,
                obstacles: c.obstaclesOf(1)),
            isNull);
      }
      // Nguyên mẫu đếm 6 / 15 / 23 đường mở cho 1 / 2 / 3 băng.
      expect(openPaths(snookerOneRailTable(), 1), 6);
    });

    test('bàn 2 băng: không còn đường 1 băng nào, còn đường 2 băng', () {
      // Nguyên mẫu: 0 / 13 / 8.
      expect(openPaths(snookerTwoRailTable(), 1), 0);
      expect(openPaths(snookerTwoRailTable(), 2), greaterThan(0));
    });

    test('bàn 3 băng: không còn đường 1 hay 2 băng nào, còn đường 3 băng', () {
      // Nguyên mẫu: 0 / 0 / 8.
      expect(openPaths(snookerThreeRailTable(), 1), 0);
      expect(openPaths(snookerThreeRailTable(), 2), 0);
      expect(openPaths(snookerThreeRailTable(), 3), greaterThan(0));
      for (final s in [snookerTwoRailTable(), snookerThreeRailTable()]) {
        expect(contextOf(s).snookered, isTrue);
        expect(CandidateFinder(game: s.game).easiest(s.cue, s.balls), isNull);
      }
    });
  });

  test('chấm: băng dài 0–8 từ góc trái, băng ngắn 0–4 từ góc trên, làm tròn nửa chấm', () {
    expect(diamondOf(Vec2(table.length / 2, table.minY), Rail.top), 4);
    expect(diamondOf(Vec2(table.length * 2.3 / 8, table.maxY), Rail.bottom), 2.5);
    expect(diamondOf(Vec2(table.length * 2.2 / 8, table.minY), Rail.top), 2);
    expect(diamondOf(Vec2(table.minX, table.width * 3 / 4), Rail.left), 3);
    expect(diamondOf(Vec2(table.maxX, table.width * 0.3 / 4), Rail.right), 0.5);
    expect(longRailDiamonds, 2 * shortRailDiamonds);
  });

  test('sát băng: cách băng không quá một bi', () {
    expect(nearRail(Vec2(table.minX + nearRailDiameters * d, 63.5)), isTrue);
    expect(nearRail(Vec2(table.minX + nearRailDiameters * d + 0.01, 63.5)), isFalse);
    expect(nearRail(Vec2(127, table.maxY - 1)), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$FLUTTER" test test/domain/planner/safety_geometry_test.dart`
Expected: compile errors (the new files do not exist).

- [ ] **Step 3: Constants**

Append to `planner_constants.dart`:

```dart

// Cú phòng thủ — spec 2026-10-07 planner-safety mục 4.5. Test chỉ dùng tên.

/// Độ dày cú thủ trực tiếp: trọn bi, ¾, ½, ¼, ⅛ (mỏng). Trừ trọn bi, mỗi
/// mức lệch hai bên.
const safetyThicknesses = <double>[1, 0.75, 0.5, 0.25, 0.125];

/// A băng: chạm trọn bi hoặc ½ bi hai bên.
const kickThicknesses = <double>[1, 0.5];

/// Cú thủ trực tiếp luôn thử cả áp phê (spec quyết định 4): không, trái ½,
/// trái 1, phải ½, phải 1 đầu cơ — đúng thứ tự thử.
const safetySpins = <SideSpin>[
  SideSpin.none(),
  SideSpin(SpinSide.left, 0.5),
  SideSpin(SpinSide.left, 1),
  SideSpin(SpinSide.right, 0.5),
  SideSpin(SpinSide.right, 1),
];

/// A băng chỉ đánh đứng bi hoặc cu lê (spec 3.4).
const kickStrokes = <Stroke>[Stroke.stun, Stroke.follow];

/// Phạt A băng theo số băng (spec quyết định 7, số của chủ sản phẩm).
const kickRailPenalty = <int, double>{1: 10, 2: 20, 3: 45, 4: 55};

/// Thử tới 4 băng; chuỗi 4 băng chỉ là đường lui khi 1–3 băng không còn
/// phương án hợp lệ nào (spec quyết định 3).
const maxKickRails = 4;
const kickFallbackRails = 4;

/// Thưởng mỗi bi sát băng (bi cái, bi đối thủ phải đánh dễ nhất).
const nearRailBonus = 5.0;

/// "Sát băng" là cách băng không quá ngần này đường kính bi (spec 4.5:
/// nearRailDistance = ballDiameter). Hằng số theo đường kính vì đường kính
/// là trường của TableSpec, không phải hằng số biên dịch.
const nearRailDiameters = 1.0;

/// Đối thủ "khó" khi góc cắt dễ nhất lớn hơn mức này (spec 4.3).
const opponentHardAngle = zoneFair;

/// Dò hướng cơ cho cú thủ: dừng khi độ lệch ngang lúc chạm sai dưới ngần
/// này đường kính bi (≈ 1 mm, khoảng 2 % độ dày).
const contactTolerance = 0.02;

/// Dò tối đa ngần này lần chạm thử mỗi phương án; không hội tụ thì bỏ
/// phương án (spec 3.4). Nguyên mẫu trên a35667b: A băng cần trung vị 9 lần.
const maxContactProbes = 16;

/// Mỗi bước cát tuyến xoay tối đa ngần này độ: bước lớn hơn dễ nhảy sang
/// chuỗi băng khác. Điểm soi gương trượt thì dò dần ra hai bên từng bước
/// [contactStartStepDeg].
const contactMaxStepDeg = 2.0;
const contactStartStepDeg = 0.5;

/// Số khoảng chấm: băng dài 0–8, băng ngắn 0–4 (spec, thuật ngữ "Chấm").
const longRailDiamonds = 8;
const shortRailDiamonds = 4;
```

- [ ] **Step 4: Types**

`lib/domain/planner/safety_shot.dart`:

```dart
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Vì sao phải thủ: bị đui, hay thấy bi mà hết đường ăn (spec 3.2).
enum SafetyReason { snookered, noPot }

/// Cú thủ trực tiếp hay A băng.
enum SafetyKind { direct, kick }

/// Bên lệch khi chạm: bi cái đi qua bên trái hay bên phải tâm bi hợp lệ,
/// nhìn từ sau bi cái theo hướng đánh. Trọn bi thì không lệch.
enum ThicknessSide { full, left, right }

/// Điểm ngắm A băng: băng đầu tiên và số chấm (spec quyết định 5).
class RailAim {
  const RailAim({required this.rail, required this.diamond, required this.at});

  final Rail rail;

  /// Đếm từ góc trái (băng dài) hoặc góc trên (băng ngắn) trên màn, góc là
  /// chấm 0, làm tròn nửa chấm.
  final double diamond;

  /// Tâm bi cái lúc chạm băng — lấy từ vết mô phỏng, đúng trên biên.
  final Vec2 at;
}

/// Thế bàn đối thủ nhận sau cú thủ (spec 4.1, 4.4).
class OpponentView {
  const OpponentView({required this.snookered, this.ball, this.easiest});

  final bool snookered;

  /// Bi đối thủ được tính sát băng và khoảng cách: bi của cú dễ nhất; đui
  /// hoặc không lỗ nào thì bi số nhỏ nhất đối thủ phải đánh; null khi đối
  /// thủ không còn bi nào.
  final PlacedBall? ball;

  /// Cú dễ nhất của đối thủ (góc cắt nhỏ nhất, bỏ lỗ bị chắn).
  final ShotGeometry? easiest;

  /// Phần đối thủ của điểm: đui 0; không đui thì 95 − góc dễ nhất; không lỗ
  /// nào thì cũng 0 (góc coi như 95°).
  double get part {
    final e = easiest;
    return snookered || e == null ? 0 : blockedAngle - e.angle;
  }

  /// Khó cho đối thủ: đui, hết đường ăn, hay góc dễ nhất > [opponentHardAngle].
  bool get hard {
    final e = easiest;
    return snookered || e == null || e.angle > opponentHardAngle;
  }
}

/// Cú thủ đã chọn — trường `safety` của bước phòng thủ (spec 3.7).
class SafetyShot {
  const SafetyShot({
    required this.reason,
    required this.kind,
    required this.rails,
    required this.ballNum,
    required this.thickness,
    required this.side,
    required this.stroke,
    required this.spin,
    required this.power,
    required this.aimed,
    this.railAim,
    required this.opponent,
    required this.jitterEnds,
    required this.tolerance,
    this.sawsBhePercent,
    required this.contactDistance,
    required this.total,
  });

  final SafetyReason reason;
  final SafetyKind kind;

  /// Số băng của A băng; 0 khi trực tiếp.
  final int rails;

  /// Bi hợp lệ được chạm.
  final int ballNum;
  final double thickness;
  final ThicknessSide side;
  final Stroke stroke;
  final SideSpin spin;
  final double power;

  /// Cú đã dò: vết hai bi, và độ xoay hướng cơ để dòng áp phê dùng lại.
  /// `aimOffsetDeg` không bao giờ hiện thành lời khuyên theo độ.
  final AimedShot aimed;

  /// Chỉ có khi A băng.
  final RailAim? railAim;
  final OpponentView opponent;

  /// Điểm dừng bi cái khi lực −15 % / +15 %; null ở mức phạm luật.
  final ({Vec2? minus, Vec2? plus}) jitterEnds;

  /// Số mức trong 7 mức lực đều nhau ±15 % vẫn khó cho đối thủ (spec 4.3).
  final int tolerance;

  /// Chỉ có khi dùng áp phê.
  final int? sawsBhePercent;

  /// Quãng bi cái → bi ảo hình học, cm — cho dòng áp phê (đổi độ lệch
  /// ngắm ra đầu cơ ở đúng quãng này).
  final double contactDistance;

  /// Điểm của phương án (thấp là tốt), để công cụ dò và test đọc.
  final double total;

  ShotTrace get trace => aimed.trace;
}
```

- [ ] **Step 5: Geometry**

`lib/domain/planner/safety_geometry.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/table_geometry/path_clear.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/ball_state.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Phía bên trái khi nhìn dọc [dir] trên màn (y đi xuống).
Vec2 leftOf(Vec2 dir) => Vec2(dir.y, -dir.x);

/// Độ lệch ngang lúc chạm, cm, của độ dày [thickness] lệch [side]: tâm bi
/// cái cách đường tâm bi hợp lệ `D·(1 − độ dày)`; dương là bên trái.
double contactLateral(double thickness, ThicknessSide side,
    {TableSpec table = TableSpec.nineFoot}) {
  final offset = table.ballDiameter * (1 - thickness);
  return switch (side) {
    ThicknessSide.full => 0,
    ThicknessSide.left => offset,
    ThicknessSide.right => -offset,
  };
}

typedef DirectContact = ({double aim, Vec2 contact});

/// Đánh thẳng từ [cue] sao cho tâm bi cái lệch [lateral] khỏi tâm [ball] lúc
/// chạm: hướng cơ (rad) và bi ảo. null khi hai bi chồng nhau hoặc lệch quá
/// một đường kính (trượt bi).
DirectContact? directContact(Vec2 cue, Vec2 ball, double lateral,
    {TableSpec table = TableSpec.nineFoot}) {
  final d = ball - cue;
  final dist = d.length;
  final dd = table.ballDiameter;
  if (dist <= dd || lateral.abs() > dd) return null;
  // (cue − ball)·trái(u) = dist·sin(φ − θ) = lateral.
  final aim = math.atan2(d.y, d.x) - math.asin(lateral / dist);
  final u = Vec2(math.cos(aim), math.sin(aim));
  final along = u.dot(d) - math.sqrt(math.max(0.0, dd * dd - lateral * lateral));
  return (aim: aim, contact: cue + u * along);
}

/// Thấy bi (spec 3.2): một trong ba đường — tới bi ảo trọn bi, và hai đường
/// mỏng sát hai mép — không bị [obstacles] chắn.
bool canSee(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles,
    {TableSpec table = TableSpec.nineFoot}) {
  final dd = table.ballDiameter;
  for (final lateral in [0.0, dd, -dd]) {
    final c = directContact(cue, ball, lateral, table: table);
    if (c != null && isPathClear(cue, c.contact, obstacles, table: table)) return true;
  }
  return false;
}

/// Thứ tự thử độ dày của cú trực tiếp (spec 3.3): trọn bi, rồi mỗi mức trái
/// trước phải.
final directContactOrder = <(double, ThicknessSide)>[
  for (final f in safetyThicknesses)
    if (f == 1)
      (f, ThicknessSide.full)
    else
      ...[(f, ThicknessSide.left), (f, ThicknessSide.right)],
];

/// Thứ tự thử điểm chạm của A băng: trọn bi, ½ trái, ½ phải.
final kickContactOrder = <(double, ThicknessSide)>[
  for (final f in kickThicknesses)
    if (f == 1)
      (f, ThicknessSide.full)
    else
      ...[(f, ThicknessSide.left), (f, ThicknessSide.right)],
];

/// Các độ dày mà đường bi cái tới bi ảo không bị chắn, đúng thứ tự thử.
List<(double, ThicknessSide)> openContacts(Vec2 cue, Vec2 ball, Iterable<Vec2> obstacles,
        {TableSpec table = TableSpec.nineFoot}) =>
    [
      for (final (f, side) in directContactOrder)
        if (directContact(cue, ball, contactLateral(f, side, table: table), table: table)
                case final c?
            when isPathClear(cue, c.contact, obstacles, table: table))
          (f, side),
    ];

/// Mọi chuỗi [count] băng không lặp băng liền nhau, theo thứ tự `Rail.values`
/// ở từng vị trí: 4, 12, 36, 108 chuỗi.
List<List<Rail>> railSequences(int count) {
  var out = <List<Rail>>[const []];
  for (var i = 0; i < count; i++) {
    out = [
      for (final s in out)
        for (final r in Rail.values)
          if (s.isEmpty || s.last != r) [...s, r],
    ];
  }
  return out;
}

/// Ảnh soi gương của [p] qua biên tâm bi của [rail].
Vec2 mirrorAcross(Vec2 p, Rail rail, {TableSpec table = TableSpec.nineFoot}) => switch (rail) {
      Rail.left => Vec2(2 * table.minX - p.x, p.y),
      Rail.right => Vec2(2 * table.maxX - p.x, p.y),
      Rail.top => Vec2(p.x, 2 * table.minY - p.y),
      Rail.bottom => Vec2(p.x, 2 * table.maxY - p.y),
    };

/// Điểm chạm băng rơi vào miệng lỗ (spec 3.4): gần điểm lỗ hơn vùng rơi lỗ
/// cộng một đường kính bi.
bool inPocketMouth(Vec2 p, {TableSpec table = TableSpec.nineFoot}) => Pocket.values.any(
    (k) => p.distanceTo(table.pocketPosition(k)) < table.captureRadius(k) + table.ballDiameter);

/// Đường A băng hình học: hướng cơ ban đầu, các điểm chạm băng, bi ảo.
class KickPath {
  const KickPath({required this.aim, required this.hits, required this.contact});

  /// Hướng cơ (rad) tới ảnh soi gương — chỉ là điểm bắt đầu dò.
  final double aim;
  final List<Vec2> hits;
  final Vec2 contact;
}

/// Soi gương bi hợp lệ qua [rails] (spec 3.4). null khi đường gấp khúc
/// không chạm đúng các băng theo thứ tự, chạm băng ở miệng lỗ, hay đi qua
/// bi khác — trước băng cuối, kể cả chính bi hợp lệ.
KickPath? kickPath({
  required Vec2 cue,
  required Vec2 ball,
  required List<Rail> rails,
  required double lateral,
  required List<Vec2> obstacles,
  TableSpec table = TableSpec.nineFoot,
}) {
  if (rails.isEmpty) return null;
  // Lần đầu soi tâm bi để biết hướng đoạn cuối, rồi dời điểm soi sang bên
  // cho đúng độ lệch ngang.
  final full = _fold(cue, ball, rails, table);
  if (full == null) return null;
  final target = ball + leftOf((ball - full.last).normalized) * lateral;
  final hits = _fold(cue, target, rails, table);
  if (hits == null) return null;
  final u = (target - hits.last).normalized;
  final dd = table.ballDiameter;
  final contact = target - u * math.sqrt(math.max(0.0, dd * dd - lateral * lateral));
  final legs = [cue, ...hits];
  final early = [...obstacles, ball];
  for (var i = 0; i + 1 < legs.length; i++) {
    if (!isPathClear(legs[i], legs[i + 1], early, table: table)) return null;
  }
  if (!isPathClear(hits.last, contact, obstacles, table: table)) return null;
  final first = hits.first;
  return KickPath(
    aim: math.atan2(first.y - cue.y, first.x - cue.x),
    hits: List.unmodifiable(hits),
    contact: contact,
  );
}

List<Vec2>? _fold(Vec2 cue, Vec2 target, List<Rail> rails, TableSpec table) {
  final images = List<Vec2>.filled(rails.length + 1, target);
  for (var j = rails.length - 1; j >= 0; j--) {
    images[j] = mirrorAcross(images[j + 1], rails[j], table: table);
  }
  var from = cue;
  final hits = <Vec2>[];
  for (var j = 0; j < rails.length; j++) {
    final hit = _railCrossing(from, images[j], rails[j], table);
    if (hit == null || inPocketMouth(hit, table: table)) return null;
    hits.add(hit);
    from = hit;
  }
  return hits;
}

/// Chỗ đoạn [from] → [toward] cắt biên của [rail], nếu nó cắt trong đoạn và
/// trong chiều dài băng.
Vec2? _railCrossing(Vec2 from, Vec2 toward, Rail rail, TableSpec table) {
  final vertical = rail == Rail.left || rail == Rail.right;
  final bound = switch (rail) {
    Rail.left => table.minX,
    Rail.right => table.maxX,
    Rail.top => table.minY,
    Rail.bottom => table.maxY,
  };
  final a = vertical ? from.x : from.y;
  final b = vertical ? toward.x : toward.y;
  if (a == b) return null;
  final t = (bound - a) / (b - a);
  if (t <= 1e-9 || t > 1) return null;
  final hit = vertical
      ? Vec2(bound, from.y + (toward.y - from.y) * t)
      : Vec2(from.x + (toward.x - from.x) * t, bound);
  final along = vertical ? hit.y : hit.x;
  final lo = vertical ? table.minY : table.minX;
  final hi = vertical ? table.maxY : table.maxX;
  return along < lo || along > hi ? null : hit;
}

/// Số chấm của điểm chạm [hit] trên [rail]: băng dài 0–8 từ góc trái, băng
/// ngắn 0–4 từ góc trên, làm tròn nửa chấm (spec quyết định 5).
double diamondOf(Vec2 hit, Rail rail, {TableSpec table = TableSpec.nineFoot}) {
  final raw = switch (rail) {
    Rail.top || Rail.bottom => hit.x / table.length * longRailDiamonds,
    Rail.left || Rail.right => hit.y / table.width * shortRailDiamonds,
  };
  return (raw * 2).round() / 2;
}

/// Bi ở [p] cách băng gần nhất không quá [nearRailDiameters] đường kính.
bool nearRail(Vec2 p, {TableSpec table = TableSpec.nineFoot}) {
  final gap = [p.x - table.minX, table.maxX - p.x, p.y - table.minY, table.maxY - p.y]
      .reduce(math.min);
  return gap <= nearRailDiameters * table.ballDiameter;
}

/// Độ lệch ngang đo được lúc chạm: tâm bi cái so với tâm [ball], theo hướng
/// bi cái đang đi; dương là bên trái.
double lateralAt(BallState cueAtContact, Vec2 ball) =>
    (cueAtContact.pos - ball).dot(leftOf(cueAtContact.vel.normalized));
```

- [ ] **Step 6: Context and option type**

`lib/domain/planner/safety_options.dart`:

```dart
import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Bàn lúc phải thủ (spec 3.1–3.2): bi cái, các bi còn lại, bi hợp lệ, và
/// có bị đui không.
class SafetyContext {
  SafetyContext({
    required this.game,
    required this.cue,
    required List<PlacedBall> balls,
    this.table = TableSpec.nineFoot,
  }) : balls = List.unmodifiable([...balls]..sort((a, b) => a.number.compareTo(b.number)));

  final GameType game;
  final Vec2 cue;
  final List<PlacedBall> balls;
  final TableSpec table;

  /// 9 / 10 bi: bi số nhỏ nhất. 8 bi: mọi bi nhóm mình, hết thì bi 8.
  late final List<PlacedBall> legal = legalTargetsAmong(game, balls);

  /// Bi hợp lệ nhìn thấy được (một trong ba đường không bị chắn).
  late final List<PlacedBall> visible = [
    for (final t in legal)
      if (canSee(cue, t.pos, obstaclesFor(t, balls), table: table)) t,
  ];

  /// Đui khi mọi bi hợp lệ đều bị chắn (8 bi: mọi bi nhóm mình).
  bool get snookered => visible.isEmpty;

  SafetyReason get reason => snookered ? SafetyReason.snookered : SafetyReason.noPot;

  /// Bi chắn khi đánh bi [ballNum].
  List<Vec2> obstaclesOf(int ballNum) =>
      [for (final b in balls) if (b.number != ballNum) b.pos];

  /// Bàn sau cú thủ: bi [ballNum] ở [to], các bi khác không đổi (bi thứ ba
  /// không tham gia va chạm, PRD §8).
  List<PlacedBall> after(int ballNum, Vec2 to) => [
        for (final b in balls)
          b.number == ballNum ? PlacedBall(number: b.number, pos: to, role: b.role) : b,
      ];
}

/// Một phương án thủ, chưa mô phỏng (spec 3.3–3.4).
class SafetyOption {
  const SafetyOption({
    required this.kind,
    required this.ballNum,
    required this.ball,
    this.rails = const [],
    required this.thickness,
    required this.side,
    required this.lateral,
    required this.stroke,
    this.spin = const SideSpin.none(),
    required this.power,
    required this.initialAim,
    required this.contact,
  });

  final SafetyKind kind;
  final int ballNum;
  final Vec2 ball;

  /// Chuỗi băng của A băng; rỗng khi trực tiếp.
  final List<Rail> rails;
  final double thickness;
  final ThicknessSide side;

  /// Độ lệch ngang mục tiêu lúc chạm, cm (dương là trái).
  final double lateral;
  final Stroke stroke;
  final SideSpin spin;
  final double power;

  /// Hướng cơ hình học (bi ảo hoặc soi gương), rad — điểm bắt đầu dò.
  final double initialAim;

  /// Bi ảo hình học.
  final Vec2 contact;

  @override
  String toString() => 'SafetyOption(${kind.name} bi $ballNum ${rails.map((r) => r.name).join('-')} '
      '$thickness ${side.name} ${stroke.name} $spin ${power.round()}%)';
}
```

- [ ] **Step 7: Fixtures**

Append to `test/support/planner_tables.dart` (add `import 'package:poolcoachai/domain/table_physics/cushion.dart';` only if a later task needs it here):

```dart
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
```

- [ ] **Step 8: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner/safety_geometry_test.dart && "$FLUTTER" test test/architecture_test.dart && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`.
- If `openPaths(snookerOneRailTable(), 1)` is not 6, compare `kickPath` with Step 5 line by line (target in `early`, the pocket-mouth rule, `t > 1`). The other counts were measured with exactly that code.
- If `hở một mép` fails, print `openContacts(...)` and check the sign convention of `leftOf` (deviation 15) before touching the fixture.

- [ ] **Step 9: Commit**

```bash
git add lib/domain/planner/planner_constants.dart lib/domain/planner/safety_shot.dart lib/domain/planner/safety_geometry.dart lib/domain/planner/safety_options.dart test/support/planner_tables.dart test/domain/planner/safety_geometry_test.dart
git commit -m "Add the safety constants, the snooker classification and the mirror-image kick geometry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 20: Refine safety aims on the real physics core

**Files:**
- Create: `lib/domain/planner/safety_aim.dart`, `lib/domain/planner/kick_search.dart`
- Modify: `lib/domain/planner/safety_options.dart` (add `directOption`)
- Test: `test/domain/planner/safety_aim_test.dart`

**Interfaces:**
- Consumes: `probeKick`, `KickProbe`, `simulateShot`, `solveStun`, `topspinOf`, `strokeVerticalOffset` (Task 17); `SafetyContext`, `SafetyOption`, `directContact`, `contactLateral`, `kickPath`, `lateralAt` (Task 19); `squirtAngle`, `sideOffsetOf`, `CueElevationAngle.radians` (`cue_strike.dart`).
- Produces:
  - `typedef KickProbeFn = KickProbe Function(ShotInput input, {required int maxRails});`
  - `typedef SimulateFn = ShotTrace Function(ShotInput input);`
  - `class SafetyPhysics { const SafetyPhysics({KickProbeFn probe = probeKick, SimulateFn simulate = simulateShot}); }`
  - `typedef SimKey = ({Vec2 cue, Vec2 object, double aim, double power, double b, SideSpin spin});`
  - `ShotInput inputOf(SimKey k, {TableSpec table})`, `SimKey keyOf(ShotInput i)`, `SimKey withSimPower(SimKey k, double power)`
  - `typedef AimResult = ({SimKey key, bool stunReached});`
  - `({double aim, bool converged}) refineContact(ShotInput input, double lateral, List<Rail> rails, KickProbeFn probe)`
  - `AimResult? aimSafety(SafetyOption o, {required Vec2 cue, SafetyPhysics physics = const SafetyPhysics(), TableSpec table = TableSpec.nineFoot})`
  - `ShotTrace? simulateSafety(SimKey key, {SafetyPhysics physics = const SafetyPhysics(), TableSpec table = TableSpec.nineFoot})`
  - `double aimOffsetDegOf(SafetyOption o, Vec2 cue, double aim)`
  - `SafetyOption? directOption(SafetyContext c, PlacedBall target, double thickness, ThicknessSide side, Stroke stroke, SideSpin spin, double power)` (in `safety_options.dart`)
  - `SafetyOption? kickOption(SafetyContext c, PlacedBall target, List<Rail> rails, double thickness, ThicknessSide side, Stroke stroke, double power)` (in `kick_search.dart`)

**The refinement, concretely** (spec §3.3–3.4):
1. Start from the geometric aim: the thickness's ghost for a direct shot, the mirror image for a kick. Add the squirt pre-compensation `squirtAngle(sideOffsetOf(spin), R)`, as `solveAim` does.
2. Error function `e(θ)`: run `probeKick(input with aim θ, maxRails: rails.length)`. The probe is valid only if the cue ball touches the legal ball, did not drop, and hit exactly the option's rail sequence before contact. Then `e = lateralAt(cueAtContact, ball) − targetLateral`. Otherwise `e` is undefined.
3. If `e(θ0)` is undefined, search outward: `θ0 ± k·0.5°` for k = 1, 2, … alternating sides, until a valid probe or the cap.
4. Secant: `θ1 = θ0 ± 1e-3` rad, then `θn+1 = θn − e(θn)·(θn − θn−1)/(e(θn) − e(θn−1))`, each step clamped to `contactMaxStepDeg` (2°). If a step lands on an undefined probe, halve the step until it is valid or the cap is hit.
5. Stop when `|e| < contactTolerance × ballDiameter` (about 1.1 mm), or after `maxContactProbes` (16) probes in total, or when the secant stalls (`e(θn) == e(θn−1)`).
6. Not converged means the option is rejected (`aimSafety` returns `null`). A `SimulationTimeout` from a probe also means `null`.
7. For a stun option: refine at `b = 0`, solve the stun offset with `solveStun` using the same kick probe to measure spin at contact, then refine once more from the refined aim.

- [ ] **Step 1: Write the failing tests**

`test/domain/planner/safety_aim_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Dò hướng cơ cho cú thủ trên lõi vật lý thật (spec cú phòng thủ 3.3–3.4).
void main() {
  const table = TableSpec.nineFoot;
  final tol = contactTolerance * table.ballDiameter;

  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  test('cú trực tiếp: dò xong thì chạm đúng độ dày, không băng nào trước', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final open = openContacts(c.cue, target.pos, c.obstaclesOf(1));
    var converged = 0;
    for (final (f, side) in open) {
      final o = directOption(c, target, f, side, Stroke.follow, const SideSpin.none(), 45)!;
      final r = aimSafety(o, cue: c.cue);
      if (r == null) continue;
      converged++;
      final p = probeKick(inputOf(r.key), maxRails: 0);
      expect(p.railsBefore, isEmpty, reason: '$o');
      expect((lateralAt(p.cueAtContact!, target.pos) - o.lateral).abs(), lessThan(tol),
          reason: '$o');
    }
    // Không áp phê thì đường bi cái trước va chạm gần như thẳng.
    expect(converged, greaterThanOrEqualTo(open.length - 1));
  });

  test('áp phê: dò bù cả lệch do áp phê, vẫn đúng độ dày', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final o = directOption(c, target, 0.5, ThicknessSide.left, Stroke.follow,
        const SideSpin(SpinSide.right, 1), 60)!;
    final r = aimSafety(o, cue: c.cue)!;
    final p = probeKick(inputOf(r.key), maxRails: 0);
    expect((lateralAt(p.cueAtContact!, target.pos) - o.lateral).abs(), lessThan(tol));
    // Hướng cơ đã xoay khỏi hướng hình học: dòng áp phê có lượng dịch để nói.
    expect(aimOffsetDegOf(o, c.cue, r.key.aim).abs(), greaterThan(0));
  });

  test('đánh đứng bi: b dưới tâm, hết xoáy dọc lúc chạm', () {
    final c = contextOf(noPotTable());
    final target = c.legal.single;
    final o = directOption(c, target, 1, ThicknessSide.full, Stroke.stun, const SideSpin.none(), 45)!;
    final r = aimSafety(o, cue: c.cue)!;
    expect(r.key.b, lessThanOrEqualTo(0));
    expect(r.stunReached, isTrue);
  });

  test('A băng 1 băng: hội tụ ở phần lớn phương án, mỗi cú hội tụ chạm đúng một băng', () {
    final c = contextOf(snookerOneRailTable());
    final target = c.legal.single;
    var converged = 0;
    for (final stroke in kickStrokes) {
      for (final power in powerCandidates) {
        final o = kickOption(c, target, const [Rail.top], 1, ThicknessSide.full, stroke, power)!;
        final r = aimSafety(o, cue: c.cue);
        if (r == null) continue;
        converged++;
        final p = probeKick(inputOf(r.key), maxRails: 1);
        expect(p.railsBefore, [Rail.top], reason: '$o');
        expect(lateralAt(p.cueAtContact!, target.pos).abs(), lessThan(tol), reason: '$o');
      }
    }
    // Nguyên mẫu trên a35667b: 8/10 hội tụ (đứng bi tính ở b = 0).
    expect(converged, greaterThanOrEqualTo(5));
  });

  test('không hội tụ thì bỏ phương án; chạm thử quá giờ cũng bỏ', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 1, ThicknessSide.full, Stroke.follow,
        const SideSpin.none(), 45)!;
    expect(aimSafety(o, cue: c.cue, physics: noSafetyPhysics), isNull);
    final slow = SafetyPhysics(
      probe: (input, {required maxRails}) => throw SimulationTimeout(input),
    );
    expect(aimSafety(o, cue: c.cue, physics: slow), isNull);
  });

  test('mô phỏng đủ quá giờ thì không có vết', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 1, ThicknessSide.full, Stroke.follow,
        const SideSpin.none(), 45)!;
    final r = aimSafety(o, cue: c.cue)!;
    expect(simulateSafety(r.key), isNotNull);
    expect(simulateSafety(r.key, physics: noSafetyPhysics), isNull);
  });

  test('đổi lực giữ nguyên hướng cơ và b', () {
    final c = contextOf(noPotTable());
    final o = directOption(c, c.legal.single, 0.5, ThicknessSide.right, Stroke.draw,
        const SideSpin.none(), 45)!;
    final k = aimSafety(o, cue: c.cue)!.key;
    final j = withSimPower(k, 60);
    expect((j.aim, j.b, j.spin, j.power), (k.aim, k.b, k.spin, 60.0));
    expect(keyOf(inputOf(k)), k);
  });
}
```

Add to `test/support/planner_tables.dart`:

```dart
/// Lõi thủ không bao giờ chạm bi và mô phỏng nào cũng quá giờ: mọi phương án
/// thủ bị bỏ nhanh, bước phòng thủ ra với safety = null. Cho test chỉ cần biết
/// kế hoạch dừng (spec cú phòng thủ 9.1.10).
final noSafetyPhysics = SafetyPhysics(
  probe: (input, {required maxRails}) =>
      const KickProbe(cueAtContact: null, railsBefore: [], cuePocket: null),
  simulate: (input) => throw SimulationTimeout(input),
);
```

with `import 'package:poolcoachai/domain/planner/safety_aim.dart';` added to `planner_tables.dart`.

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/safety_aim_test.dart`
Expected: compile errors (`safety_aim.dart`, `kick_search.dart`, `directOption` missing).

- [ ] **Step 3: Option builders**

Append to `safety_options.dart` (add `import 'package:poolcoachai/domain/table_geometry/stroke.dart';` if missing):

```dart
/// Phương án thủ trực tiếp vào [target] với độ dày [thickness] lệch [side];
/// null khi không dựng được bi ảo. Không kiểm đường chắn — [openContacts]
/// đã lọc trước.
SafetyOption? directOption(SafetyContext c, PlacedBall target, double thickness,
    ThicknessSide side, Stroke stroke, SideSpin spin, double power) {
  final lateral = contactLateral(thickness, side, table: c.table);
  final g = directContact(c.cue, target.pos, lateral, table: c.table);
  if (g == null) return null;
  return SafetyOption(
    kind: SafetyKind.direct,
    ballNum: target.number,
    ball: target.pos,
    thickness: thickness,
    side: side,
    lateral: lateral,
    stroke: stroke,
    spin: spin,
    power: power,
    initialAim: g.aim,
    contact: g.contact,
  );
}
```

`lib/domain/planner/kick_search.dart`:

```dart
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';

/// Phương án A băng qua [rails] vào [target] (spec 3.4); null khi đường soi
/// gương bị chắn, sai thứ tự băng hay chạm băng ở miệng lỗ.
SafetyOption? kickOption(SafetyContext c, PlacedBall target, List<Rail> rails,
    double thickness, ThicknessSide side, Stroke stroke, double power) {
  final lateral = contactLateral(thickness, side, table: c.table);
  final path = kickPath(
    cue: c.cue,
    ball: target.pos,
    rails: rails,
    lateral: lateral,
    obstacles: c.obstaclesOf(target.number),
    table: c.table,
  );
  if (path == null) return null;
  return SafetyOption(
    kind: SafetyKind.kick,
    ballNum: target.number,
    ball: target.pos,
    rails: List.unmodifiable(rails),
    thickness: thickness,
    side: side,
    lateral: lateral,
    stroke: stroke,
    power: power,
    initialAim: path.aim,
    contact: path.contact,
  );
}
```

- [ ] **Step 4: The refinement**

`lib/domain/planner/safety_aim.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/cue_strike.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

typedef KickProbeFn = KickProbe Function(ShotInput input, {required int maxRails});
typedef SimulateFn = ShotTrace Function(ShotInput input);

/// Hai hàm lõi vật lý mà việc tìm cú thủ dùng. Mặc định là lõi thật; test
/// thay để ép không hội tụ, quá giờ, hay chỉ cho 4 băng chạm được.
class SafetyPhysics {
  const SafetyPhysics({this.probe = probeKick, this.simulate = simulateShot});

  final KickProbeFn probe;
  final SimulateFn simulate;
}

/// Đầu vào một lần mô phỏng đủ. Record nên so theo giá trị: khoá bộ nhớ
/// đệm, và cú không áp phê ở lực p + 15 % trùng khoá với phương án lực đó.
typedef SimKey = ({Vec2 cue, Vec2 object, double aim, double power, double b, SideSpin spin});

ShotInput inputOf(SimKey k, {TableSpec table = TableSpec.nineFoot}) => ShotInput(
      cue: k.cue,
      object: k.object,
      aimAngle: k.aim,
      power: k.power,
      verticalOffset: k.b,
      spin: k.spin,
      elevation: CueElevation.normal.radians,
      table: table,
    );

SimKey keyOf(ShotInput i) =>
    (cue: i.cue, object: i.object, aim: i.aimAngle, power: i.power, b: i.verticalOffset, spin: i.spin);

/// Cùng hướng cơ, cùng `b`, lực khác — cú người chơi đánh lệch lực.
SimKey withSimPower(SimKey k, double power) =>
    (cue: k.cue, object: k.object, aim: k.aim, power: power, b: k.b, spin: k.spin);

/// Kết quả dò một phương án: khoá mô phỏng đủ, và Đánh đứng bi có thật sự
/// hết xoáy dọc lúc chạm không.
typedef AimResult = ({SimKey key, bool stunReached});

bool _sameRails(List<Rail> a, List<Rail> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Dò hướng cơ để bi cái chạm `input.object` lệch đúng [lateral] cm, sau
/// đúng chuỗi [rails] (spec 3.3–3.4). Bắt đầu từ `input.aimAngle`; điểm
/// đầu trượt thì dò dần ra hai bên, rồi cát tuyến có chặn bước, như bù ném
/// của `aimShot`. Trả hướng tốt nhất và có hội tụ không.
({double aim, bool converged}) refineContact(
    ShotInput input, double lateral, List<Rail> rails, KickProbeFn probe) {
  final tol = contactTolerance * input.table.ballDiameter;
  const maxStep = contactMaxStepDeg * math.pi / 180;
  const startStep = contactStartStepDeg * math.pi / 180;
  var probes = 0;
  double? error(double aim) {
    probes++;
    final p = probe(input.copyWith(aimAngle: aim), maxRails: rails.length);
    final at = p.cueAtContact;
    if (at == null || p.cuePocket != null || !_sameRails(p.railsBefore, rails)) return null;
    return lateralAt(at, input.object) - lateral;
  }

  final start = input.aimAngle;
  var xa = start;
  var maybe = error(xa);
  for (var k = 1; maybe == null && probes < maxContactProbes; k++) {
    xa = start + (k.isOdd ? 1 : -1) * ((k + 1) ~/ 2) * startStep;
    maybe = error(xa);
  }
  if (maybe == null) return (aim: start, converged: false);
  var ea = maybe;
  var bestX = xa, bestE = ea.abs();
  if (bestE < tol) return (aim: xa, converged: true);

  var xb = xa + 1e-3;
  var second = error(xb);
  if (second == null) {
    xb = xa - 1e-3;
    second = error(xb);
  }
  if (second == null) return (aim: bestX, converged: false);
  var eb = second;
  if (eb.abs() < bestE) {
    bestX = xb;
    bestE = eb.abs();
  }

  while (bestE >= tol && probes < maxContactProbes && eb != ea) {
    var step = -eb * (xb - xa) / (eb - ea);
    if (step.abs() > maxStep) step = maxStep * step.sign;
    var xc = xb + step;
    var ec = error(xc);
    // Sai chuỗi băng hay trượt bi: lùi nửa bước về điểm còn đúng.
    while (ec == null && probes < maxContactProbes) {
      step /= 2;
      xc = xb + step;
      ec = error(xc);
    }
    if (ec == null) break;
    xa = xb;
    ea = eb;
    xb = xc;
    eb = ec;
    if (eb.abs() < bestE) {
      bestX = xb;
      bestE = eb.abs();
    }
  }
  return (aim: bestX, converged: bestE < tol);
}

/// Một đơn vị việc "dò": hướng cơ (và `b` khi Đánh đứng bi) của phương án
/// [o]. null khi không hội tụ hay lõi quá giờ — phương án bị bỏ (spec 3.4).
AimResult? aimSafety(SafetyOption o,
    {required Vec2 cue,
    SafetyPhysics physics = const SafetyPhysics(),
    TableSpec table = TableSpec.nineFoot}) {
  try {
    var input = ShotInput(
      cue: cue,
      object: o.ball,
      // Bù sẵn góc lệch do áp phê, như solveAim: không có bước này, áp phê
      // nhiều ở xa làm lần chạm thử đầu trượt hẳn bi.
      aimAngle: o.initialAim + squirtAngle(sideOffsetOf(o.spin), table.radius),
      power: o.power,
      verticalOffset: strokeVerticalOffset(o.stroke, table.radius),
      spin: o.spin,
      elevation: CueElevation.normal.radians,
      table: table,
    );
    var stunReached = true;
    if (o.stroke == Stroke.stun) {
      // Như aimShot: `b` đổi hướng đi (swerve, góc bật băng), hướng đổi
      // quãng đường nên đổi `b`. Dò hướng ở b = 0, dò `b` ở hướng đó, rồi
      // dò hướng lần nữa cho khớp `b` cuối.
      final first = refineContact(input, o.lateral, o.rails, physics.probe);
      if (!first.converged) return null;
      (input, stunReached) = solveStun(input.copyWith(aimAngle: first.aim), topspin: (i) {
        final p = physics.probe(i, maxRails: o.rails.length);
        final s = p.cueAtContact;
        return s == null || p.cuePocket != null ? null : topspinOf(s);
      });
    }
    final r = refineContact(input, o.lateral, o.rails, physics.probe);
    if (!r.converged) return null;
    return (key: keyOf(input.copyWith(aimAngle: r.aim)), stunReached: stunReached);
  } on SimulationTimeout {
    return null;
  }
}

/// Một đơn vị việc "mô phỏng": vết đủ của [key]; null khi lõi quá giờ
/// (Planner không bao giờ hỏi chờ, spec mục 7).
ShotTrace? simulateSafety(SimKey key,
    {SafetyPhysics physics = const SafetyPhysics(), TableSpec table = TableSpec.nineFoot}) {
  try {
    return physics.simulate(inputOf(key, table: table));
  } on SimulationTimeout {
    return null;
  }
}

/// Góc xoay từ hướng hình học sang hướng đã dò, độ, dương là về phía tâm
/// bi (dày hơn) — cùng quy ước `AimSolution.aimOffsetDeg`. Chỉ dùng bên
/// trong (đổi ra đầu cơ ở dòng áp phê), không bao giờ hiện thành độ.
double aimOffsetDegOf(SafetyOption o, Vec2 cue, double aim) {
  Vec2 dir(double a) => Vec2(math.cos(a), math.sin(a));
  final from = dir(o.initialAim);
  final thicker = from.cross(o.ball - cue) >= 0 ? 1.0 : -1.0;
  return thicker * from.signedAngleTo(dir(aim)) * 180 / math.pi;
}
```

- [ ] **Step 5: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner/safety_aim_test.dart && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`.
- If the kick test converges in fewer than 5 of 10 options, print each option's start error and probe count (add a temporary `print` in `refineContact`). The prototype on `a35667b` needed a median of 3 probes for 1 rail. Do not raise `maxContactProbes` or the tolerance without the owner; report the numbers.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/planner/safety_aim.dart lib/domain/planner/kick_search.dart lib/domain/planner/safety_options.dart test/support/planner_tables.dart test/domain/planner/safety_aim_test.dart
git commit -m "Refine safety and kick aims on the real core with a bounded secant on the contact offset

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 21: Safety rules and scoring

**Files:**
- Create: `lib/domain/planner/safety_rules.dart`, `lib/domain/planner/safety_scoring.dart`
- Test: `test/domain/planner/safety_scoring_test.dart`

**Interfaces:**
- Consumes: `polylineClear` (`shot_options.dart`), `jitteredPower`, `techPenaltyFor`, `powerPenaltyFor`, `legalTargetsAmong`, `obstaclesFor`, `bestPocket`, `compareShots`, `sawsBhePercent`; everything from Tasks 19–20.
- Produces:
  - `enum SafetyFoul { missed, hitOtherFirst, wrongRailCount, scratch, legalPocketed, noRail, objectBlocked, cueAfterBlocked, timeout }`
  - `SafetyFoul? safetyFoulOf(ShotTrace t, {required int rails, required List<Vec2> obstacles, TableSpec table})`
  - `List<PlacedBall> opponentTargets(GameType game, List<PlacedBall> balls)`
  - `OpponentView opponentView({required GameType game, required Vec2 cue, required List<PlacedBall> balls, TableSpec table})`
  - `class SafetyLevel({required double value, SafetyFoul? foul, OpponentView? opponent, Vec2? cueEnd})` with `const SafetyLevel.foul(SafetyFoul foul)`
  - `SafetyLevel levelOf(SafetyContext c, SafetyOption o, ShotTrace? t)`
  - `double kickPenaltyFor(int rails)`, `double safetyPenaltyOf(SafetyOption o)`, `double scoreFloor(TableSpec table)`
  - `abstract interface class SafetyLookup { AimResult? aim(int index); ShotTrace? trace(SimKey key); }`
  - `class DirectSafetyLookup implements SafetyLookup` (`DirectSafetyLookup(SafetyContext context, List<SafetyOption> options, {SafetyPhysics physics})`)
  - `class SafetyEval({required SafetyOption option, required int index, required AimResult aim, required ShotTrace base, required List<SafetyLevel> levels, required double penalty})` with `worst`, `total`
  - `SafetyEval? evaluateOption(SafetyContext c, int index, SafetyOption o, SafetyLookup lookup, {double? bound})`
  - `bool beats(SafetyEval e, SafetyEval? best)`
  - `int safetyToleranceOf(SafetyContext c, SafetyOption o, SimKey key, ShotTrace? Function(SimKey key) trace)`
  - `SafetyShot buildSafetyShot(SafetyContext c, SafetyEval e, ShotTrace? Function(SimKey key) trace)`

- [ ] **Step 1: Write the failing tests**

`test/domain/planner/safety_scoring_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_scoring.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/cushion.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Tra giả: trả đúng một kết quả dò, vết theo lực; ghi lại lần gọi.
class _FakeLookup implements SafetyLookup {
  _FakeLookup(this.result, this.byPower);
  final AimResult? result;
  final ShotTrace? Function(double power) byPower;
  var aimCalls = 0;
  final powers = <double>[];

  @override
  AimResult? aim(int index) {
    aimCalls++;
    return result;
  }

  @override
  ShotTrace? trace(SimKey key) {
    powers.add(key.power);
    return byPower(key.power);
  }
}

void main() {
  const table = TableSpec.nineFoot;

  // Bàn nhỏ: bi cái (30, 80) đánh trọn bi 1 ở (180, 80); bi 2 ở (105, 20).
  const cue = Vec2(30, 80);
  const ball = Vec2(180, 80);
  const contact = Vec2(174.285, 80);
  final ctx = SafetyContext(game: GameType.nineBall, cue: cue, balls: const [
    PlacedBall(number: 1, pos: ball),
    PlacedBall(number: 2, pos: Vec2(105, 20)),
  ]);
  final option = directOption(ctx, ctx.legal.single, 1, ThicknessSide.full, Stroke.stun,
      const SideSpin.none(), 45)!;
  final objectRail = RailHit(
      ball: ShotBall.object, pos: Vec2(table.maxX, 80), rail: Rail.right, afterContact: true);

  ShotTrace traceOf({
    List<Vec2> cueBefore = const [cue, contact],
    List<Vec2> cueAfter = const [contact, Vec2(160, 60)],
    List<Vec2> objectPath = const [ball, Vec2(200, 100)],
    List<RailHit>? rails,
    Pocket? cuePocket,
    Pocket? objectPocket,
    bool touched = true,
  }) =>
      ShotTrace(
        cueBefore: cueBefore,
        cueAfter: touched ? cueAfter : const [],
        objectPath: objectPath,
        contactCue: touched ? cueBefore.last : null,
        rails: rails ?? [objectRail],
        cuePocket: cuePocket,
        objectPocket: objectPocket,
        cueEnd: touched ? cueAfter.last : cueBefore.last,
      );

  group('luật (spec 3.5) trên vết dựng tay', () {
    final obstacles = ctx.obstaclesOf(1);
    SafetyFoul? foul(ShotTrace t, {int rails = 0, List<Vec2>? others}) =>
        safetyFoulOf(t, rails: rails, obstacles: others ?? obstacles);

    test('đúng luật: chạm bi hợp lệ trước, có bi chạm băng sau va chạm', () {
      expect(foul(traceOf()), isNull);
    });

    test('mỗi kiểu phạm lỗi bị gọi đúng tên', () {
      expect(foul(traceOf(touched: false)), SafetyFoul.missed);
      expect(foul(traceOf(), others: const [Vec2(105, 80)]), SafetyFoul.hitOtherFirst);
      expect(foul(traceOf(), rails: 1), SafetyFoul.wrongRailCount);
      final cueRail = RailHit(
          ball: ShotBall.cue, pos: Vec2(105, table.minY), rail: Rail.top, afterContact: false);
      expect(foul(traceOf(rails: [cueRail, objectRail])), SafetyFoul.wrongRailCount);
      expect(foul(traceOf(rails: [cueRail, objectRail]), rails: 1), isNull);
      expect(foul(traceOf(cuePocket: Pocket.topRight)), SafetyFoul.scratch);
      expect(foul(traceOf(objectPocket: Pocket.bottomRight)), SafetyFoul.legalPocketed);
      expect(foul(traceOf(rails: const [])), SafetyFoul.noRail);
      expect(foul(traceOf(), others: const [Vec2(190, 90)]), SafetyFoul.objectBlocked);
      expect(foul(traceOf(), others: const [Vec2(167, 70)]), SafetyFoul.cueAfterBlocked);
    });

    test('phạm luật thì mức đó tính phần đối thủ 95, không cộng sát băng, khoảng cách', () {
      final l = levelOf(ctx, option, traceOf(cuePocket: Pocket.topRight));
      expect(l.foul, SafetyFoul.scratch);
      expect(l.value, blockedAngle);
      expect(l.opponent, isNull);
      expect(levelOf(ctx, option, null).foul, SafetyFoul.timeout);
    });
  });

  group('luật trên lõi vật lý thật (test 9.1.2)', () {
    SafetyFoul? realFoul(TableSetup s, double thickness, Stroke stroke, double power) {
      final c = SafetyContext(game: s.game, cue: s.cue, balls: s.balls);
      final o = directOption(c, c.legal.first, thickness,
          thickness == 1 ? ThicknessSide.full : ThicknessSide.left, stroke,
          const SideSpin.none(), power)!;
      final r = aimSafety(o, cue: c.cue)!;
      return levelOf(c, o, simulateSafety(r.key)).foul;
    }

    test('chạm bi khác trước: đánh thẳng qua bi chắn', () {
      expect(realFoul(snookerOneRailTable(), 1, Stroke.stun, 60), SafetyFoul.hitOtherFirst);
    });

    test('không bi nào chạm băng: chạm rất nhẹ giữa bàn', () {
      const s = TableSetup(
          game: GameType.nineBall,
          cue: Vec2(110, 63.5),
          balls: [PlacedBall(number: 1, pos: Vec2(127, 63.5))]);
      // Cu lê: ở 3 % Đánh đứng bi dò `b` dưới tâm và bi cái không tới bi
      // (kiểm trên a35667b khi viết kế hoạch).
      expect(realFoul(s, 1, Stroke.follow, 3), SafetyFoul.noRail);
    });

    test('chết cái và bi hợp lệ rơi lỗ: bi thẳng lỗ góc', () {
      // Đo trên c43c74a (kế hoạch dọn bàn, test 8): cu lê theo bi vào lỗ ở
      // mọi mức lực; Đánh đứng bi 90 % đưa bi vào mà bi cái không rơi.
      expect(realFoul(cornerFollowTable(), 1, Stroke.follow, 60), SafetyFoul.scratch);
      expect(realFoul(cornerFollowTable(), 1, Stroke.stun, 90), SafetyFoul.legalPocketed);
    });
  });

  group('đối thủ phải đánh bi nào (spec 4.4, test 9.1.8)', () {
    test('9 bi: bi vừa chạm, ở vị trí mới', () {
      const moved = Vec2(200, 100);
      final l = levelOf(ctx, option, traceOf(objectPath: const [ball, moved]));
      expect(l.opponent!.ball!.number, 1);
      expect(l.opponent!.ball!.pos, moved);
    });

    test('8 bi: bi nhóm kia; hết thì bi 8; không còn bi nào thì không lỗi', () {
      const mine = PlacedBall(number: 1, pos: Vec2(100, 60));
      const theirs = PlacedBall(number: 9, pos: Vec2(200, 30), role: BallRole.opponent);
      const eight = PlacedBall(number: 8, pos: Vec2(60, 100), role: BallRole.eight);
      expect(opponentTargets(GameType.eightBall, const [mine, theirs, eight]), [theirs]);
      expect(opponentTargets(GameType.eightBall, const [mine, eight]), [eight]);
      expect(opponentTargets(GameType.eightBall, const [mine]), isEmpty);
      final none = opponentView(game: GameType.eightBall, cue: const Vec2(30, 30), balls: const [mine]);
      expect(none.snookered, isFalse);
      expect(none.ball, isNull);
      expect(none.part, 0);
      expect(none.hard, isTrue);
    });
  });

  group('chấm một mức lực (spec 4.1)', () {
    test('đối thủ bị đui: phần đối thủ 0, sát băng −5, trừ khoảng cách', () {
      // Bi cái dừng sát băng trên, bi 2 nằm giữa bi cái và bi 1.
      const end = Vec2(105, 5);
      const moved = Vec2(105, 60);
      final l = levelOf(ctx, option,
          traceOf(cueAfter: const [contact, end], objectPath: const [ball, moved]));
      expect(l.opponent!.snookered, isTrue);
      expect(l.value, closeTo(-nearRailBonus - end.distanceTo(moved) * distanceWeight, 1e-9));
    });

    test('không đui: 95 − góc cắt dễ nhất, đúng bestPocket với các bi còn lại', () {
      const end = Vec2(160, 60);
      const moved = Vec2(200, 100);
      final l = levelOf(ctx, option, traceOf(objectPath: const [ball, moved]));
      final g = bestPocket(cue: end, object: moved, others: const [Vec2(105, 20)])!;
      expect(l.opponent!.easiest!.pocket, g.pocket);
      expect(l.value, closeTo(blockedAngle - g.angle - end.distanceTo(moved) * distanceWeight, 1e-9));
    });

    test('không lỗ nào thì phần đối thủ là 0', () {
      const v = OpponentView(snookered: false, ball: PlacedBall(number: 1, pos: Vec2(1, 1)));
      expect(v.part, 0);
      expect(v.hard, isTrue);
    });
  });

  group('điểm phương án (spec 4.2)', () {
    test('phạt kỹ thuật, A băng và lực cộng dồn', () {
      final kick = kickOption(SafetyContext(game: GameType.nineBall, cue: cue, balls: snookerOneRailTable().balls),
          const PlacedBall(number: 1, pos: Vec2(180, 80)), const [Rail.top], 1, ThicknessSide.full,
          Stroke.follow, 60)!;
      expect(safetyPenaltyOf(kick),
          closeTo(techPenaltyFollow + kickRailPenalty[1]! + 60 * powerPenaltyPerPercent, 1e-12));
      final spun = directOption(ctx, ctx.legal.single, 0.5, ThicknessSide.left, Stroke.draw,
          const SideSpin(SpinSide.left, 1), 30)!;
      expect(safetyPenaltyOf(spun),
          closeTo(techPenaltyDraw + sidePenaltyOneTip + 30 * powerPenaltyPerPercent, 1e-12));
      expect([for (var n = 1; n <= maxKickRails; n++) kickPenaltyFor(n)],
          [for (var n = 1; n <= maxKickRails; n++) kickRailPenalty[n]]);
      expect(kickPenaltyFor(0), 0);
    });

    test('lấy mức xấu nhất trong ±15 %; mức phạm luật tính 95', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final lookup = _FakeLookup(aim, (p) => p == 60 ? traceOf(cuePocket: Pocket.topRight) : traceOf());
      final e = evaluateOption(ctx, 0, option, lookup)!;
      expect(e.levels, hasLength(3));
      expect(e.worst, blockedAngle);
      expect(e.total, closeTo(blockedAngle + safetyPenaltyOf(option), 1e-12));
      expect(lookup.powers, [45, 30, 60]);
    });

    test('lực 90 %: mức +15 % kẹp về 100 %, đủ 7 mức', () {
      final o = directOption(ctx, ctx.legal.single, 1, ThicknessSide.full, Stroke.stun,
          const SideSpin.none(), 90)!;
      const key = (cue: cue, object: ball, aim: 0.0, power: 90.0, b: 0.0, spin: SideSpin.none());
      final powers = <double>[];
      final hard = safetyToleranceOf(ctx, o, key, (k) {
        powers.add(k.power);
        return traceOf();
      });
      expect(powers, hasLength(toleranceSamples));
      expect(powers.reduce(math.max), maxPower);
      expect(hard, inInclusiveRange(0, toleranceSamples));
    });

    test('cắt tỉa đúng: chặn dưới vượt điểm tốt nhất thì không dò, mức chọn đã thua thì không thử ±15 %', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final early = _FakeLookup(aim, (_) => traceOf());
      expect(evaluateOption(ctx, 0, option, early, bound: safetyPenaltyOf(option) + scoreFloor(table)),
          isNull);
      expect(early.aimCalls, 0);

      final base = levelOf(ctx, option, traceOf());
      final late = _FakeLookup(aim, (_) => traceOf());
      expect(evaluateOption(ctx, 0, option, late, bound: base.value + safetyPenaltyOf(option)), isNull);
      expect(late.powers, [45]);
    });

    test('chặn dưới không bao giờ vượt điểm thật', () {
      // Mọi mức: phần đối thủ ≥ 0, hai bi sát băng, khoảng cách ≤ đường chéo.
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final e = evaluateOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf()))!;
      expect(e.total, greaterThanOrEqualTo(safetyPenaltyOf(option) + scoreFloor(table)));
    });

    test('bằng điểm thì giữ phương án thử trước', () {
      const aim = (key: (cue: cue, object: ball, aim: 0.0, power: 45.0, b: 0.0, spin: SideSpin.none()), stunReached: true);
      final a = evaluateOption(ctx, 0, option, _FakeLookup(aim, (_) => traceOf()))!;
      final b = evaluateOption(ctx, 1, option, _FakeLookup(aim, (_) => traceOf()))!;
      expect(b.total, a.total);
      expect(beats(b, a), isFalse);
      expect(beats(a, null), isTrue);
    });

    test('cú đơn giản thắng khi gần ngang (test 9.1.7): trực tiếp đứng bi hơn A băng 2 băng', () {
      // Spec 3.2 không bao giờ để trực tiếp và A băng thi trong cùng một lần
      // tìm (độ lệch 13 của kế hoạch), nên kiểm thẳng trên cách cộng điểm:
      // cùng kiểu đánh và lực, A băng 2 băng chấm vị trí tốt hơn gần bằng
      // phạt của nó vẫn thua.
      final direct = safetyPenaltyOf(option);
      final kick = techPenaltyStun + kickPenaltyFor(2) + option.power * powerPenaltyPerPercent;
      const worst = 30.0;
      final almost = worst - (kickPenaltyFor(2) - 1);
      expect(worst + direct, lessThan(almost + kick));
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/safety_scoring_test.dart`
Expected: compile errors (the new files do not exist).

- [ ] **Step 3: Rules**

`lib/domain/planner/safety_rules.dart`:

```dart
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Vì sao một cú thủ phạm luật WPA (spec quyết định 1, mục 3.5). Thứ tự là
/// thứ tự kiểm: tên lỗi đầu tiên trúng là tên báo ra.
enum SafetyFoul {
  /// Bi cái không chạm bi hợp lệ.
  missed,

  /// Đường bi cái trước va chạm đi qua bi khác: chạm bi khác trước.
  hitOtherFirst,

  /// A băng: số băng bi cái chạm trước va chạm khác số băng của chuỗi.
  wrongRailCount,

  /// Chết cái.
  scratch,

  /// Bi hợp lệ rơi lỗ: là may, không phải cú thủ.
  legalPocketed,

  /// Sau va chạm không bi nào chạm băng.
  noRail,

  /// Đường bi hợp lệ sau va chạm đi qua bi chắn.
  objectBlocked,

  /// Đường bi cái sau va chạm đi qua bi chắn: mô phỏng hai bi không biết bi
  /// cái dừng đâu (độ lệch 5 của kế hoạch, cùng luật với phần ăn bi).
  cueAfterBlocked,

  /// Lõi quá maxSimTime.
  timeout,
}

/// Lỗi của vết [t]; null khi đúng luật. [rails] là số băng của chuỗi (0 khi
/// trực tiếp); [obstacles] là mọi bi khác bi hợp lệ.
SafetyFoul? safetyFoulOf(ShotTrace t,
    {required int rails, required List<Vec2> obstacles, TableSpec table = TableSpec.nineFoot}) {
  if (t.contactCue == null) return SafetyFoul.missed;
  if (!polylineClear(t.cueBefore, obstacles, table: table)) return SafetyFoul.hitOtherFirst;
  final before = t.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).length;
  if (before != rails) return SafetyFoul.wrongRailCount;
  if (t.cuePocket != null) return SafetyFoul.scratch;
  if (t.objectPocket != null) return SafetyFoul.legalPocketed;
  if (!t.rails.any((h) => h.afterContact)) return SafetyFoul.noRail;
  if (!polylineClear(t.objectPath, obstacles, table: table)) return SafetyFoul.objectBlocked;
  if (!polylineClear(t.cueAfter, obstacles, table: table)) return SafetyFoul.cueAfterBlocked;
  return null;
}
```

- [ ] **Step 4: Scoring**

`lib/domain/planner/safety_scoring.dart`:

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/planner/legal_targets.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/scoring.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/pocket_choice.dart';
import 'package:poolcoachai/domain/table_geometry/saws.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/aim.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Bi đối thủ phải đánh sau cú thủ (spec 4.4). 9 / 10 bi: bi số nhỏ nhất
/// (chính bi vừa chạm, ở vị trí mới). 8 bi: bi nhóm kia; hết thì bi 8.
List<PlacedBall> opponentTargets(GameType game, List<PlacedBall> balls) {
  if (game != GameType.eightBall) return legalTargetsAmong(game, balls);
  final sorted = [...balls]..sort((a, b) => a.number.compareTo(b.number));
  final theirs = [for (final b in sorted) if (b.role == BallRole.opponent) b];
  return theirs.isNotEmpty ? theirs : [for (final b in sorted) if (b.role == BallRole.eight) b];
}

/// Thế bàn đối thủ nhận với bi cái ở [cue] và các bi ở [balls].
OpponentView opponentView({
  required GameType game,
  required Vec2 cue,
  required List<PlacedBall> balls,
  TableSpec table = TableSpec.nineFoot,
}) {
  final targets = opponentTargets(game, balls);
  if (targets.isEmpty) return const OpponentView(snookered: false);
  final seen = targets.any((t) => canSee(cue, t.pos, obstaclesFor(t, balls), table: table));
  if (!seen) return OpponentView(snookered: true, ball: targets.first);
  PlacedBall? bestBall;
  ShotGeometry? best;
  for (final t in targets) {
    final g = bestPocket(cue: cue, object: t.pos, others: obstaclesFor(t, balls), table: table);
    if (g == null) continue;
    if (best == null || compareShots(g, best, table: table) < 0) {
      best = g;
      bestBall = t;
    }
  }
  return OpponentView(snookered: false, ball: bestBall ?? targets.first, easiest: best);
}

/// Điểm một mức lực (spec 4.1): thấp là tốt.
class SafetyLevel {
  const SafetyLevel({required this.value, this.foul, this.opponent, this.cueEnd});

  /// Phạm luật: phần đối thủ 95, không cộng sát băng và khoảng cách.
  const SafetyLevel.foul(SafetyFoul this.foul)
      : value = blockedAngle,
        opponent = null,
        cueEnd = null;

  final double value;
  final SafetyFoul? foul;
  final OpponentView? opponent;
  final Vec2? cueEnd;
}

/// Chấm vết [t] của phương án [o]; null là lõi quá giờ.
SafetyLevel levelOf(SafetyContext c, SafetyOption o, ShotTrace? t) {
  if (t == null) return const SafetyLevel.foul(SafetyFoul.timeout);
  final foul = safetyFoulOf(t,
      rails: o.rails.length, obstacles: c.obstaclesOf(o.ballNum), table: c.table);
  if (foul != null) return SafetyLevel.foul(foul);
  final view = opponentView(
      game: c.game, cue: t.cueEnd, balls: c.after(o.ballNum, t.objectPath.last), table: c.table);
  var value = view.part;
  if (nearRail(t.cueEnd, table: c.table)) value -= nearRailBonus;
  final ball = view.ball;
  if (ball != null) {
    if (nearRail(ball.pos, table: c.table)) value -= nearRailBonus;
    value -= t.cueEnd.distanceTo(ball.pos) * distanceWeight;
  }
  return SafetyLevel(value: value, opponent: view, cueEnd: t.cueEnd);
}

double kickPenaltyFor(int rails) => rails == 0 ? 0 : kickRailPenalty[rails]!;

/// Phạt kỹ thuật + A băng + lực (spec 4.2).
double safetyPenaltyOf(SafetyOption o) =>
    techPenaltyFor(o.stroke, o.spin) + kickPenaltyFor(o.rails.length) + powerPenaltyFor(o.power);

/// Điểm một mức thấp nhất có thể: đối thủ đui (0), hai bi sát băng, và hai
/// bi xa nhau hết đường chéo bàn. Chặn dưới để bỏ phương án không thể thắng.
double scoreFloor(TableSpec table) {
  final w = table.maxX - table.minX;
  final h = table.maxY - table.minY;
  return -(2 * nearRailBonus + math.sqrt(w * w + h * h) * distanceWeight);
}

/// Tra một lần dò hay một lần mô phỏng. Việc tính chia lát ném lỗi khi chưa
/// có kết quả; công cụ dò và test tính thẳng ([DirectSafetyLookup]).
abstract interface class SafetyLookup {
  AimResult? aim(int index);
  ShotTrace? trace(SimKey key);
}

class DirectSafetyLookup implements SafetyLookup {
  DirectSafetyLookup(this.context, this.options, {this.physics = const SafetyPhysics()});

  final SafetyContext context;
  final List<SafetyOption> options;
  final SafetyPhysics physics;
  final _aims = <int, AimResult?>{};
  final _sims = <SimKey, ShotTrace?>{};

  @override
  AimResult? aim(int index) => _aims.containsKey(index)
      ? _aims[index]
      : (_aims[index] = aimSafety(options[index],
          cue: context.cue, physics: physics, table: context.table));

  @override
  ShotTrace? trace(SimKey key) => _sims.containsKey(key)
      ? _sims[key]
      : (_sims[key] = simulateSafety(key, physics: physics, table: context.table));
}

/// Một phương án đã chấm.
class SafetyEval {
  const SafetyEval({
    required this.option,
    required this.index,
    required this.aim,
    required this.base,
    required this.levels,
    required this.penalty,
  });

  final SafetyOption option;
  final int index;
  final AimResult aim;

  /// Vết ở lực đã chọn.
  final ShotTrace base;

  /// Lực chọn, −15 %, +15 % (kẹp ≤ 100 %).
  final List<SafetyLevel> levels;
  final double penalty;

  double get worst => levels.map((l) => l.value).reduce(math.max);
  double get total => worst + penalty;
}

/// Chấm phương án thứ [index] (spec 4.1–4.2). null khi không hội tụ, lực
/// chọn phạm luật, hay không thể thắng [bound] (điểm tốt nhất tới giờ):
/// bằng điểm thì phương án trước giữ, nên `>=` là đủ để bỏ.
SafetyEval? evaluateOption(SafetyContext c, int index, SafetyOption o, SafetyLookup lookup,
    {double? bound}) {
  final penalty = safetyPenaltyOf(o);
  if (bound != null && penalty + scoreFloor(c.table) >= bound) return null;
  final aim = lookup.aim(index);
  if (aim == null) return null;
  final base = lookup.trace(aim.key);
  final level = levelOf(c, o, base);
  if (base == null || level.foul != null) return null;
  // Mức xấu nhất không tốt hơn mức chọn: mức chọn đã thua thì khỏi thử ±15 %.
  if (bound != null && level.value + penalty >= bound) return null;
  final levels = [level];
  for (final delta in const [-powerJitter, powerJitter]) {
    levels.add(levelOf(c, o, lookup.trace(withSimPower(aim.key, jitteredPower(o.power, delta)))));
  }
  return SafetyEval(option: o, index: index, aim: aim, base: base, levels: levels, penalty: penalty);
}

/// [e] thay được [best]: điểm thấp hơn hẳn. Bằng điểm thì giữ phương án thử
/// trước (spec 4.2), để kết quả tất định.
bool beats(SafetyEval e, SafetyEval? best) => best == null || e.total < best.total;

/// Số mức trong [toleranceSamples] mức lực đều nhau ±[powerJitter] vẫn khó
/// cho đối thủ (spec 4.3) — cùng hàm mô phỏng và chấm với lúc chọn.
int safetyToleranceOf(
    SafetyContext c, SafetyOption o, SimKey key, ShotTrace? Function(SimKey key) trace) {
  var hard = 0;
  const span = 2 * powerJitter;
  for (var k = 0; k < toleranceSamples; k++) {
    final p = jitteredPower(o.power, -powerJitter + k * span / (toleranceSamples - 1));
    final level = levelOf(c, o, trace(withSimPower(key, p)));
    if (level.foul == null && level.opponent!.hard) hard++;
  }
  return hard;
}

/// Dựng bước phòng thủ từ phương án đã chọn (spec 3.7). Độ chịu sai số cần
/// thêm bốn lần mô phỏng: việc tính chia lát tra qua [trace] như mọi lần khác.
SafetyShot buildSafetyShot(
    SafetyContext c, SafetyEval e, ShotTrace? Function(SimKey key) trace) {
  final o = e.option;
  final firstRail =
      e.base.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).firstOrNull;
  final distance = c.cue.distanceTo(o.contact);
  Vec2? endOf(SafetyLevel l) => l.foul == null ? l.cueEnd : null;
  return SafetyShot(
    reason: c.reason,
    kind: o.kind,
    rails: o.rails.length,
    ballNum: o.ballNum,
    thickness: o.thickness,
    side: o.side,
    stroke: o.stroke,
    spin: o.spin,
    power: o.power,
    aimed: AimedShot(
      trace: e.base,
      uncompensated: null,
      aimOffsetDeg: aimOffsetDegOf(o, c.cue, e.aim.key.aim),
      verticalOffset: e.aim.key.b,
      stunReached: e.aim.stunReached,
      converged: true,
    ),
    railAim: firstRail == null
        ? null
        : RailAim(
            rail: firstRail.rail,
            diamond: diamondOf(firstRail.pos, firstRail.rail, table: c.table),
            at: firstRail.pos),
    opponent: e.levels.first.opponent!,
    jitterEnds: (minus: endOf(e.levels[1]), plus: endOf(e.levels[2])),
    tolerance: safetyToleranceOf(c, o, e.aim.key, trace),
    sawsBhePercent: o.spin.isNone
        ? null
        : sawsBhePercent(distance: distance, power: o.power, stroke: o.stroke),
    contactDistance: distance,
    total: e.total,
  );
}
```

- [ ] **Step 5: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner/safety_scoring_test.dart && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`.
- The real-core rule tests rest on measured facts: `cornerFollowTable` is from the run-out plan's test 8 (measured on `c43c74a`), and the other two are forced by geometry. If `chết cái và bi hợp lệ rơi lỗ` fails after a physics change, print `levelOf(...).foul` for every stroke × power on that table and pick the pair that shows each foul; never change the rule order to make the test pass.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/planner/safety_rules.dart lib/domain/planner/safety_scoring.dart test/domain/planner/safety_scoring_test.dart
git commit -m "Add the WPA safety rules and score safeties by the opponent's worst-case position

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 22: Option lists, the sliced `SafetyJob`, and the safety probe

**Files:**
- Modify: `lib/domain/planner/safety_options.dart` (add `directOptions`), `lib/domain/planner/kick_search.dart` (add `kickOptions`)
- Create: `lib/domain/planner/safety_job.dart`
- Modify: `test/support/planner_tables.dart` (`safetyFingerprint`)
- Create: `test/domain/planner/safety_probe_test.dart` (tag `probe`)
- Test: `test/domain/planner/safety_job_test.dart`

**Interfaces:**
- Consumes: Tasks 19–21.
- Produces:
  - `List<SafetyOption> directOptions(SafetyContext c)` — for each visible legal ball (number ascending), each open thickness in `directContactOrder`, `strokeCandidates × safetySpins × powerCandidates`.
  - `List<SafetyOption> kickOptions(SafetyContext c, {required int fromRails, required int toRails})` — rail count ascending, then ball number, then `railSequences` order, then `kickContactOrder`, then `kickStrokes`, then `powerCandidates`.
  - `class SafetyJob(SafetyContext context, {SafetyPhysics physics = const SafetyPhysics(), bool prune = true, int? maxOptions})` with `bool work()`, `void step({Duration budget = sliceBudget, int? maxSimulations})`, `void cancel()`, `bool get isDone`, `bool get isCancelled`, `SafetyShot? get result`, `int get simulations`, `Set<int> get triedRailCounts`, `List<SafetyOption> get options`.
  - `SafetyShot? searchToEnd(SafetyContext c, {SafetyPhysics physics = const SafetyPhysics()})`
  - `String safetyFingerprint(SafetyShot? s)` in `planner_tables.dart`.

**How the job works.**
- At construction it lists the options: `directOptions` when the cue ball sees a legal ball, `kickOptions(1 … kickFallbackRails − 1)` when *bị đui*.
- `work()` evaluates `options[cursor]` with `evaluateOption` over a lookup that throws `_MissingAim(index)` or `_MissingSim(key)` when a result is not in the memo. On a miss it runs exactly that one unit (`aimSafety` or `simulateSafety`), stores it and returns `true`. Otherwise it keeps the better evaluation (`beats`), advances the cursor and continues.
- When the cursor reaches the end:
  - *bị đui*, no valid option yet, and 4 rails not tried: append `kickOptions(kickFallbackRails … maxKickRails)` and continue;
  - otherwise build the result with `buildSafetyShot` (its four tolerance simulations go through the same memo) and finish.
- `step()` copies `PlannerJob.step`'s budget rule: always at least one unit, never start a unit if the longest unit of this slice no longer fits.

- [ ] **Step 1: Write the failing tests**

`test/domain/planner/safety_job_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Việc tìm cú thủ chia lát (spec cú phòng thủ 3.6, test 9.1.9). Phần lớn
/// test giới hạn số phương án (maxOptions) để chạy nhanh: chia lát và cắt
/// tỉa không phụ thuộc số phương án.
void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  SafetyShot? run(SafetyContext c,
      {int? maxSimulations, Duration budget = const Duration(days: 1), int? maxOptions,
      bool prune = true, SafetyPhysics physics = const SafetyPhysics()}) {
    final job = SafetyJob(c, maxOptions: maxOptions, prune: prune, physics: physics);
    while (!job.isDone) {
      job.step(budget: budget, maxSimulations: maxSimulations);
    }
    return job.result;
  }

  group('danh sách phương án', () {
    test('trực tiếp: mỗi bi thấy được × độ dày mở × kiểu đánh × áp phê × lực, đúng thứ tự', () {
      final c = contextOf(noPotTable());
      final open = openContacts(c.cue, c.legal.single.pos, c.obstaclesOf(1));
      final options = directOptions(c);
      expect(options, hasLength(open.length *
          strokeCandidates.length * safetySpins.length * powerCandidates.length));
      expect(options.every((o) => o.kind == SafetyKind.direct && o.rails.isEmpty), isTrue);
      final first = options.first;
      expect((first.thickness, first.side), open.first);
      expect((first.stroke, first.spin, first.power),
          (strokeCandidates.first, safetySpins.first, powerCandidates.first));
      expect(options[1].power, powerCandidates[1]);
    });

    test('A băng: ít băng trước, rồi bi, chuỗi, điểm chạm, kiểu đánh, lực', () {
      final c = contextOf(snookerOneRailTable());
      final options = kickOptions(c, fromRails: 1, toRails: 3);
      expect(options, isNotEmpty);
      final counts = options.map((o) => o.rails.length).toList();
      expect(counts, [...counts]..sort());
      expect(options.every((o) => o.kind == SafetyKind.kick && kickStrokes.contains(o.stroke)),
          isTrue);
      expect(kickOptions(c, fromRails: 4, toRails: 4).every((o) => o.rails.length == 4), isTrue);
    });

    test('không đui: chỉ thử trực tiếp; đui: chỉ thử A băng 1–3 băng', () {
      expect(SafetyJob(contextOf(noPotTable())).options.every((o) => o.kind == SafetyKind.direct),
          isTrue);
      final kicks = SafetyJob(contextOf(snookerOneRailTable())).options;
      expect(kicks.every((o) => o.kind == SafetyKind.kick && o.rails.length < kickFallbackRails),
          isTrue);
    });
  });

  group('chia lát', () {
    test('chạy từng lát cho đúng y kết quả chạy một mạch, với mọi cỡ lát', () {
      for (final s in [noPotTable(), snookerOneRailTable()]) {
        final c = contextOf(s);
        final whole = safetyFingerprint(run(c, maxOptions: 40));
        for (final n in [1, 3]) {
          expect(safetyFingerprint(run(c, maxOptions: 40, maxSimulations: n)), whole,
              reason: 'lát $n');
        }
        expect(safetyFingerprint(run(c, maxOptions: 40, budget: Duration.zero)), whole);
      }
    });

    test('mỗi đơn vị việc chạy đúng một lần mô phỏng mới, hoặc không lần nào', () {
      final job = SafetyJob(contextOf(noPotTable()), maxOptions: 30);
      while (!job.isDone) {
        final before = job.simulations;
        final ran = job.work();
        expect(job.simulations - before, ran ? 1 : 0);
      }
    });

    test('tất định: cùng bàn chạy hai lần cho cùng cú thủ', () {
      final c = contextOf(noPotTable());
      expect(safetyFingerprint(run(c, maxOptions: 40)), safetyFingerprint(run(c, maxOptions: 40)));
    });

    test('hủy giữa chừng thì không chạy thêm gì', () {
      final job = SafetyJob(contextOf(noPotTable()), maxOptions: 40);
      job.step(maxSimulations: 5);
      job.cancel();
      final sims = job.simulations;
      for (var i = 0; i < 20; i++) {
        job.step();
      }
      expect(job.simulations, sims);
      expect(job.isDone, isFalse);
      expect(job.isCancelled, isTrue);
    });

    test('cắt tỉa không đổi cú được chọn, chỉ bớt mô phỏng', () {
      final c = contextOf(noPotTable());
      final pruned = SafetyJob(c, maxOptions: 75);
      final full = SafetyJob(c, maxOptions: 75, prune: false);
      for (final j in [pruned, full]) {
        while (!j.isDone) {
          j.step(budget: const Duration(days: 1));
        }
      }
      expect(safetyFingerprint(pruned.result), safetyFingerprint(full.result));
      expect(pruned.simulations, lessThanOrEqualTo(full.simulations));
    });
  });

  test('4 băng chỉ là đường lui: 1–3 băng hỏng hết thì mới thử 4 băng', () {
    final c = contextOf(snookerOneRailTable());
    expect(kickOptions(c, fromRails: 4, toRails: 4), isNotEmpty);
    // Lõi thật, nhưng chỉ cho bi cái chạm bi khi được phép 4 băng.
    final onlyFour = SafetyPhysics(
      probe: (input, {required maxRails}) => maxRails < 4
          ? const KickProbe(cueAtContact: null, railsBefore: [], cuePocket: null)
          : probeKick(input, maxRails: maxRails),
    );
    final job = SafetyJob(c, physics: onlyFour);
    while (!job.isDone && !job.triedRailCounts.contains(4)) {
      job.step(budget: const Duration(days: 1), maxSimulations: 1);
    }
    expect(job.triedRailCounts, containsAll([1, 2, 3, 4]));
  });

  test('không có cú thủ hợp lệ nào thì kết quả là null', () {
    expect(run(contextOf(noPotTable()), physics: noSafetyPhysics), isNull);
  });

  test('bi hợp lệ sát băng: tìm xong, không lỗi', () {
    final s = TableSetup(game: GameType.nineBall, cue: const Vec2(60, 60), balls: [
      PlacedBall(number: 1, pos: Vec2(200, TableSpec.nineFoot.minY)),
    ]);
    expect(() => run(contextOf(s), maxOptions: 30), returnsNormally);
  });
}
```

Add to `test/support/planner_tables.dart` (with `import 'package:poolcoachai/domain/planner/safety_shot.dart';`):

```dart
/// Mọi thứ của cú thủ mà người chơi thấy, đủ chính xác để hai lần chạy chỉ
/// trùng khi trùng thật.
String safetyFingerprint(SafetyShot? s) => s == null
    ? 'không có cú thủ'
    : [
        s.reason,
        s.kind,
        s.rails,
        s.ballNum,
        s.thickness,
        s.side,
        s.stroke,
        s.spin,
        s.power,
        s.trace.cueEnd,
        s.trace.objectPath.last,
        s.railAim?.rail,
        s.railAim?.diamond,
        s.opponent.snookered,
        s.opponent.ball?.number,
        s.opponent.easiest?.pocket,
        s.opponent.easiest?.angle,
        s.jitterEnds,
        s.tolerance,
        s.sawsBhePercent,
        s.total,
      ].join('|');
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/safety_job_test.dart`
Expected: compile errors (`directOptions`, `kickOptions`, `SafetyJob` missing).

- [ ] **Step 3: Option lists**

Append to `safety_options.dart` (add `import 'package:poolcoachai/domain/planner/planner_constants.dart';`):

```dart
/// Mọi phương án thủ trực tiếp (spec 3.3), đúng thứ tự thử: bi số nhỏ
/// trước, độ dày theo [directContactOrder] (bỏ độ dày bị chắn), kiểu đánh,
/// áp phê, lực tăng dần.
List<SafetyOption> directOptions(SafetyContext c) => [
      for (final target in c.visible)
        for (final (f, side) in openContacts(c.cue, target.pos, c.obstaclesOf(target.number),
            table: c.table))
          for (final stroke in strokeCandidates)
            for (final spin in safetySpins)
              for (final power in powerCandidates)
                directOption(c, target, f, side, stroke, spin, power)!,
    ];
```

Append to `kick_search.dart` (add `import 'package:poolcoachai/domain/planner/planner_constants.dart';`):

```dart
/// Mọi phương án A băng từ [fromRails] tới [toRails] băng (spec 3.4), đúng
/// thứ tự thử: ít băng trước, bi số nhỏ trước, chuỗi theo [railSequences],
/// điểm chạm theo [kickContactOrder], kiểu đánh, lực tăng dần. Đường soi
/// gương hỏng thì bỏ cả nhóm.
List<SafetyOption> kickOptions(SafetyContext c, {required int fromRails, required int toRails}) {
  final out = <SafetyOption>[];
  for (var n = fromRails; n <= toRails; n++) {
    for (final target in c.legal) {
      for (final rails in railSequences(n)) {
        for (final (f, side) in kickContactOrder) {
          if (kickOption(c, target, rails, f, side, kickStrokes.first, powerCandidates.first) ==
              null) {
            continue;
          }
          for (final stroke in kickStrokes) {
            for (final power in powerCandidates) {
              out.add(kickOption(c, target, rails, f, side, stroke, power)!);
            }
          }
        }
      }
    }
  }
  return out;
}
```

- [ ] **Step 4: The job**

`lib/domain/planner/safety_job.dart`:

```dart
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_aim.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_scoring.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

/// Tìm cú thủ chia lát (spec cú phòng thủ 3.6), cùng mẫu với `PlannerJob`.
///
/// Mỗi đơn vị việc chạy lại phép chấm thuần của phương án đang xét trên bộ
/// nhớ đệm; gặp lần dò hay lần mô phỏng chưa có thì làm đúng lần đó rồi
/// dừng. Khác `PlannerJob` ở chỗ nhớ luôn kết quả các phương án đã chấm (con
/// trỏ): tìm cú thủ cần vài nghìn lần mô phỏng, chạy lại từ đầu mỗi lần thì
/// tốn theo bình phương. Thứ tự cố định và phép chấm thuần, nên chạy từng
/// lát vẫn cho đúng y kết quả chạy một mạch.
class SafetyJob {
  SafetyJob(this.context, {this.physics = const SafetyPhysics(), this.prune = true, this.maxOptions})
      : _options = context.snookered
            ? kickOptions(context, fromRails: 1, toRails: kickFallbackRails - 1)
            : directOptions(context) {
    _truncate();
  }

  final SafetyContext context;
  final SafetyPhysics physics;

  /// Bỏ phương án không thể thắng (độ lệch 4 của kế hoạch). false chỉ để
  /// test kiểm cắt tỉa không đổi kết quả.
  final bool prune;

  /// Chỉ xét ngần này phương án đầu — cho test chạy nhanh.
  final int? maxOptions;

  final List<SafetyOption> _options;
  final _aims = <int, AimResult?>{};
  final _sims = <SimKey, ShotTrace?>{};
  final _tried = <int>{};
  var _cursor = 0;
  SafetyEval? _best;
  var _fallbackAdded = false;
  var _done = false;
  var _cancelled = false;
  SafetyShot? _result;

  bool get isDone => _done;
  bool get isCancelled => _cancelled;

  /// null khi không còn cú thủ hợp lệ nào (spec 3.7).
  SafetyShot? get result => _result;

  /// Số lần dò và mô phỏng đã chạy.
  int get simulations => _aims.length + _sims.length;

  /// Số băng của các phương án đã dò — test 9.1.4 kiểm 4 băng chỉ là đường lui.
  Set<int> get triedRailCounts => Set.unmodifiable(_tried);

  List<SafetyOption> get options => List.unmodifiable(_options);

  void cancel() => _cancelled = true;

  void _truncate() {
    final cap = maxOptions;
    if (cap != null && _options.length > cap) _options.removeRange(cap, _options.length);
  }

  /// Một đơn vị việc. true khi vừa chạy đúng một lần dò hay mô phỏng mới;
  /// false khi xong mà không cần lần nào.
  bool work() {
    while (!_done && !_cancelled) {
      try {
        if (_cursor < _options.length) {
          final e = evaluateOption(context, _cursor, _options[_cursor], _lookup,
              bound: prune ? _best?.total : null);
          if (e != null && beats(e, _best)) _best = e;
          _cursor++;
        } else if (context.snookered && !_fallbackAdded && _best == null) {
          // 1–3 băng không còn phương án hợp lệ nào: mới thử 4 băng
          // (spec quyết định 3).
          _fallbackAdded = true;
          _options.addAll(
              kickOptions(context, fromRails: kickFallbackRails, toRails: maxKickRails));
          _truncate();
        } else {
          final best = _best;
          _result = best == null ? null : buildSafetyShot(context, best, _lookup.trace);
          _done = true;
        }
      } on _MissingAim catch (m) {
        final o = _options[m.index];
        _tried.add(o.rails.length);
        _aims[m.index] =
            aimSafety(o, cue: context.cue, physics: physics, table: context.table);
        return true;
      } on _MissingSim catch (m) {
        _sims[m.key] = simulateSafety(m.key, physics: physics, table: context.table);
        return true;
      }
    }
    return false;
  }

  /// Làm việc tới khi hết [budget] (hoặc đủ [maxSimulations] lần mới, cho
  /// test), luôn ít nhất một đơn vị; không bắt đầu đơn vị mới nếu đơn vị dài
  /// nhất của lát này không còn vừa ngân sách. Stopwatch chỉ quyết định
  /// *khi nào* dừng, không bao giờ quyết định *tính gì*.
  void step({Duration budget = sliceBudget, int? maxSimulations}) {
    final clock = Stopwatch()..start();
    var simulated = 0;
    var longest = Duration.zero;
    while (!_done && !_cancelled) {
      final started = clock.elapsed;
      if (work()) simulated++;
      final unit = clock.elapsed - started;
      if (unit > longest) longest = unit;
      if (maxSimulations != null && simulated >= maxSimulations) break;
      if (clock.elapsed + longest > budget) break;
    }
  }

  late final SafetyLookup _lookup = _JobLookup(this);
}

class _JobLookup implements SafetyLookup {
  _JobLookup(this.job);
  final SafetyJob job;

  @override
  AimResult? aim(int index) {
    if (job._aims.containsKey(index)) return job._aims[index];
    throw _MissingAim(index);
  }

  @override
  ShotTrace? trace(SimKey key) {
    if (job._sims.containsKey(key)) return job._sims[key];
    throw _MissingSim(key);
  }
}

class _MissingAim implements Exception {
  const _MissingAim(this.index);
  final int index;
}

class _MissingSim implements Exception {
  const _MissingSim(this.key);
  final SimKey key;
}

/// Chạy một mạch tới hết — cho test, công cụ dò bàn và đo tốc độ.
SafetyShot? searchToEnd(SafetyContext c, {SafetyPhysics physics = const SafetyPhysics()}) {
  final job = SafetyJob(c, physics: physics);
  while (!job.isDone) {
    job.step(budget: const Duration(days: 1));
  }
  return job.result;
}
```

- [ ] **Step 5: The safety probe**

`test/domain/planner/safety_probe_test.dart`:

```dart
// ignore_for_file: avoid_print
@Tags(['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/candidates.dart';
import 'package:poolcoachai/domain/planner/kick_search.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_geometry/shot_geometry.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

import '../../support/planner_tables.dart';

/// Không phải test: in số liệu để người dò chọn toạ độ bàn thủ bi.
///   flutter test --tags probe --run-skipped test/domain/planner/safety_probe_test.dart
void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  void dump(String name, TableSetup s) {
    final c = contextOf(s);
    final pot = CandidateFinder(game: s.game).easiest(s.cue, s.balls);
    print('== $name: ${c.reason.name}, lỗ ${pot?.geometry.pocket.name ?? 'không'}');
    if (c.snookered) {
      for (var n = 1; n <= 4; n++) {
        final groups = kickOptions(c, fromRails: n, toRails: n).length ~/ 10;
        print('  $n băng: $groups đường hình học mở');
      }
    } else {
      print('  trực tiếp: ${directOptions(c).length} phương án');
    }
    final w = Stopwatch()..start();
    final job = SafetyJob(c);
    while (!job.isDone) {
      job.step(budget: const Duration(days: 1));
    }
    final r = job.result;
    print('  ${job.simulations} lần dò/mô phỏng, ${w.elapsedMilliseconds} ms, '
        'thử ${job.triedRailCounts.toList()..sort()} băng');
    if (r == null) {
      print('  không có cú thủ hợp lệ');
      return;
    }
    final o = r.opponent;
    print('  chọn: ${r.kind.name} ${r.rails} băng, bi ${r.ballNum}, ${r.thickness} ${r.side.name}, '
        '${r.stroke.name} ${r.spin} ${r.power.round()}%, tổng ${r.total.toStringAsFixed(2)}');
    print('  chấm ${r.railAim?.diamond} ${r.railAim?.rail.name}; đối thủ: '
        '${o.snookered ? 'đui' : '${o.easiest?.angle.toStringAsFixed(1)}° bi ${o.ball?.number}'}; '
        'chịu sai số ${r.tolerance}/7');
  }

  test('bảng cú thủ của các bàn test', () {
    dump('snookerOneRailTable', snookerOneRailTable());
    dump('snookerTwoRailTable', snookerTwoRailTable());
    dump('snookerThreeRailTable', snookerThreeRailTable());
    dump('noPotTable', noPotTable());
    dump('eightSafetyTable', eightSafetyTable());
  });

  test('lưới bàn hết đường ăn: bi chắn ở miệng các lỗ đánh được', () {
    const cues = [Vec2(60, 100), Vec2(40, 63.5), Vec2(127, 110)];
    for (final cue in cues) {
      for (var bx = 60.0; bx <= 200; bx += 35) {
        for (var by = 25.0; by <= 105; by += 20) {
          final ball = Vec2(bx, by);
          if (ball.distanceTo(cue) < 20) continue;
          // Mọi lỗ đánh được khi bàn trống đều có một bi chắn ở miệng lỗ.
          final blockers = [
            for (final p in Pocket.values)
              if (evaluateShot(cue: cue, object: ball, pocket: p) is Makeable) jawBlocker(ball, p),
          ];
          final s = TableSetup(game: GameType.nineBall, cue: cue, balls: [
            PlacedBall(number: 1, pos: ball),
            for (var i = 0; i < blockers.length; i++)
              PlacedBall(number: i + 2, pos: blockers[i]),
          ]);
          final c = contextOf(s);
          if (c.snookered || CandidateFinder(game: s.game).easiest(cue, s.balls) != null) continue;
          print('ứng viên: bi cái $cue, bi 1 $ball, chắn $blockers');
        }
      }
    }
  });

  test('lưới tham lam thêm bi chắn để buộc thêm một băng', () {
    // Từ snookerTwoRailTable, thêm từng bi chắn trên lưới 6 cm sao cho hết
    // đường 1 và 2 băng mà còn ít nhất ba đường 3 băng.
    var balls = snookerTwoRailTable().balls;
    const cue = Vec2(30, 80);
    int open(List<PlacedBall> bs, int n) =>
        kickOptions(SafetyContext(game: GameType.nineBall, cue: cue, balls: bs),
                fromRails: n, toRails: n)
            .length;
    for (var round = 0; round < 4 && open(balls, 2) > 0; round++) {
      PlacedBall? pick;
      var best = 1 << 30;
      for (var x = 12.0; x <= 242; x += 6) {
        for (var y = 8.0; y <= 119; y += 6) {
          final at = Vec2(x, y);
          if ([cue, ...balls.map((b) => b.pos)]
              .any((q) => q.distanceTo(at) < TableSpec.nineFoot.ballDiameter + 1)) {
            continue;
          }
          final next = [...balls, PlacedBall(number: balls.length + 1, pos: at)];
          if (open(next, 1) > 0) continue;
          final three = open(next, 3);
          if (three < 30) continue;
          final score = open(next, 2) * 100 - three;
          if (score < best) {
            best = score;
            pick = next.last;
          }
        }
      }
      if (pick == null) break;
      balls = [...balls, pick];
      print('thêm ${pick.pos}: 2 băng còn ${open(balls, 2) ~/ 10} nhóm, 3 băng ${open(balls, 3) ~/ 10}');
    }
  });
}
```

`kickOptions(...).length ~/ 10` counts geometric paths, because each open path yields `kickStrokes.length × powerCandidates.length = 10` options.

- [ ] **Step 6: Run the tests, the probe and the analyzer**

Run:
```bash
"$FLUTTER" test test/domain/planner/safety_job_test.dart
"$FLUTTER" test --tags probe --run-skipped test/domain/planner/safety_probe_test.dart --plain-name "bảng cú thủ"
"$FLUTTER" analyze
```
Expected:
- the job tests pass;
- the probe prints five tables with a chosen shot (or `không có cú thủ hợp lệ`), the number of units and milliseconds. Save that output for Task 23 and Task 25;
- `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/planner/safety_options.dart lib/domain/planner/kick_search.dart lib/domain/planner/safety_job.dart test/support/planner_tables.dart test/domain/planner/safety_job_test.dart test/domain/planner/safety_probe_test.dart
git commit -m "Search safeties in a sliced job that does one simulation per unit, with a probe to re-find fixtures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 23: The spec §9.1 safety tests on the real physics core

**Files:**
- Test: `test/domain/planner/safety_spec_test.dart`

**Interfaces:**
- Consumes: `SafetyJob`, `SafetyContext`, `safetyFoulOf`, `polylineClear`, `diamondOf`, the fixtures (Tasks 19–22).
- Produces: nothing new.

**How the fixtures were found, and what to do if one breaks.**
- The geometric facts (*bị đui*, no pot, which rail counts are geometrically open) are fixed by Task 19's tests and do not depend on physics constants.
- Which shot the search chooses depends on physics and on the penalties. The prototype could not check it: its rules and scoring were simplified. Task 22's probe prints it.

If an assertion below fails (now, or after the owner's tuning in Task 29):
1. Run the probe (`--plain-name "bảng cú thủ"`) and read that table's line.
2. For the kick tables, run the greedy test of the probe and take a layout it prints; for the no-pot tables, run the grid and take a candidate. Then rerun the first probe test on the new layout.
3. Update `planner_tables.dart` (coordinates and comment) and `tool/e2e/planner.mjs` together.
4. Never weaken an assertion to make a fixture pass. A failure that is not about a fixture means the rules or scoring contradict the spec: report it.

- [ ] **Step 1: Write the tests**

`test/domain/planner/safety_spec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/safety_geometry.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/safety_rules.dart';
import 'package:poolcoachai/domain/planner/safety_shot.dart';
import 'package:poolcoachai/domain/planner/shot_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';
import 'package:poolcoachai/domain/table_physics/simulate_shot.dart';

import '../../support/planner_tables.dart';

/// Spec cú phòng thủ mục 9.1, chạy trên lõi vật lý thật. Bàn hết đúng điều
/// kiện thì dò lại bằng safety_probe_test.dart, đừng nới điều kiện.
void main() {
  late Map<String, (SafetyContext, SafetyJob)> runs;

  setUpAll(() {
    (SafetyContext, SafetyJob) run(TableSetup s) {
      final c = SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);
      final job = SafetyJob(c);
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      return (c, job);
    }

    runs = {
      'one': run(snookerOneRailTable()),
      'two': run(snookerTwoRailTable()),
      'three': run(snookerThreeRailTable()),
      'noPot': run(noPotTable()),
      'eight': run(eightSafetyTable()),
    };
  });

  int cueRailsBefore(ShotTrace t) =>
      t.rails.where((h) => h.ball == ShotBall.cue && !h.afterContact).length;

  test('mọi cú thủ được chọn đều đúng luật trên chính vết của nó', () {
    for (final MapEntry(:key, value: (c, job)) in runs.entries) {
      final s = job.result!;
      expect(
          safetyFoulOf(s.trace, rails: s.rails, obstacles: c.obstaclesOf(s.ballNum)), isNull,
          reason: key);
      expect(s.tolerance, inInclusiveRange(0, toleranceSamples), reason: key);
    }
  });

  test('3. bàn đui cần 1 băng: đúng 1 băng trước va chạm, chạm bi hợp lệ trước mọi bi khác', () {
    final (c, job) = runs['one']!;
    final s = job.result!;
    expect(s.reason, SafetyReason.snookered);
    expect(s.kind, SafetyKind.kick);
    expect(s.rails, 1);
    expect(cueRailsBefore(s.trace), 1);
    expect(polylineClear(s.trace.cueBefore, c.obstaclesOf(s.ballNum)), isTrue);
  });

  test('3. bàn buộc 2 băng và bàn buộc 3 băng', () {
    for (final (name, rails) in [('two', 2), ('three', 3)]) {
      final s = runs[name]!.$2.result!;
      expect(s.kind, SafetyKind.kick, reason: name);
      expect(s.rails, rails, reason: name);
      expect(cueRailsBefore(s.trace), rails, reason: name);
    }
  });

  test('4. 1–3 băng có cú hợp lệ thì không mô phỏng chuỗi 4 băng nào', () {
    for (final name in ['one', 'two', 'three']) {
      expect(runs[name]!.$2.triedRailCounts, isNot(contains(maxKickRails)), reason: name);
    }
  });

  test('5. điểm ngắm theo chấm: lần chạm băng đầu của vết, làm tròn nửa chấm, đúng tên băng', () {
    for (final name in ['one', 'two', 'three']) {
      final s = runs[name]!.$2.result!;
      final first = s.trace.rails.firstWhere((h) => h.ball == ShotBall.cue && !h.afterContact);
      expect(s.railAim!.rail, first.rail, reason: name);
      expect(s.railAim!.diamond, diamondOf(first.pos, first.rail), reason: name);
      expect(s.railAim!.diamond * 2, (s.railAim!.diamond * 2).roundToDouble(), reason: name);
    }
  });

  test('không đui, hết đường ăn: cú thủ trực tiếp, không có điểm ngắm băng', () {
    for (final name in ['noPot', 'eight']) {
      final s = runs[name]!.$2.result!;
      expect(s.reason, SafetyReason.noPot, reason: name);
      expect(s.kind, SafetyKind.direct, reason: name);
      expect(s.rails, 0, reason: name);
      expect(s.railAim, isNull, reason: name);
      expect(cueRailsBefore(s.trace), 0, reason: name);
    }
  });

  test('8. 9 bi: đối thủ đánh đúng bi vừa chạm, ở vị trí mới', () {
    final s = runs['noPot']!.$2.result!;
    expect(s.opponent.ball!.number, 1);
    expect(s.opponent.ball!.pos, s.trace.objectPath.last);
  });

  test('8. 8 bi: đối thủ đánh bi nhóm kia, không phải bi vừa chạm', () {
    final s = runs['eight']!.$2.result!;
    expect(s.ballNum, 1);
    expect([9, 10], contains(s.opponent.ball!.number));
  });
}
```

- [ ] **Step 2: Run them**

Run: `"$FLUTTER" test test/domain/planner/safety_spec_test.dart`
Expected: all PASS on the real core. The file runs five full searches; expect it to take tens of seconds on the VM (see deviation 1). A failure in 3, 4, 5 or the no-pot test means a fixture no longer meets its condition: apply the procedure above.

- [ ] **Step 3: Run the domain suite and the analyzer**

Run: `"$FLUTTER" test test/domain && "$FLUTTER" analyze`
Expected: all pass (the probe and perf tags are skipped), `No issues found!`.

- [ ] **Step 4: Commit**

```bash
git add test/domain/planner/safety_spec_test.dart test/support/planner_tables.dart tool/e2e/planner.mjs
git commit -m "Run the safety spec tests on the real physics core: kick rail counts, the 4-rail fallback, diamonds and the opponent's ball

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`planner_tables.dart` and `planner.mjs` are in the commit only if Step 2 moved a fixture.

---

### Task 24: The planner hands its safety step to the search

**Files:**
- Modify: `lib/domain/planner/plan_step.dart` (`safety` field)
- Modify: `lib/domain/planner/planner_job.dart` (`safety` physics, `_search`, `searchingSafety`, `simulations`, `planToEnd`)
- Modify: `lib/features/training/presentation/planner/planner_steps_view.dart` (constructor passthrough only)
- Modify: `test/support/planner_tables.dart` (`fingerprint`)
- Test: `test/domain/planner/planner_job_test.dart`, `test/features/training/planner_step_lines_test.dart`, `test/features/training/planner_steps_view_test.dart`

**Interfaces:**
- Consumes: `SafetyJob`, `SafetyContext`, `SafetyPhysics`, `SafetyShot` (Tasks 19–22).
- Produces:
  - `PlanStep(..., SafetyShot? safety)` and `const PlanStep.safety({required Vec2 cbFrom, int? ballNum, SafetyShot? safety})`; field `final SafetyShot? safety`.
  - `PlannerJob(TableSetup setup, {AimShotFn aim = aimShot, SafetyPhysics safety = const SafetyPhysics()})`; `bool get searchingSafety`; `simulations` counts the search too.
  - `planToEnd(TableSetup setup, {AimShotFn aim = aimShot, SafetyPhysics safety = const SafetyPhysics()})`.
  - `PlannerStepsView({..., SafetyPhysics safety = const SafetyPhysics()})` (`@visibleForTesting`).

- [ ] **Step 1: Write the failing tests and update the safety-only ones**

In `test/domain/planner/planner_job_test.dart`:
1. Add imports: `safety_job.dart`, `safety_options.dart`, `safety_shot.dart`.
2. Pass `safety: noSafetyPhysics` where a test only checks that the plan stops, so it does not run a real search:
   - the `planToEnd` calls in `'nối liền…'`, `'chạy từng lát…'`, `'đặt lại bi cái vào chỗ không đánh được: bước đầu là phòng thủ'`, `'tầng 3: …'`, `'tầng 4: …'` and `'8 bi: có bi đánh được nhưng mọi cú hỏng …'`;
   - the `sliced` helper: create the job as `PlannerJob(setup, safety: noSafetyPhysics)`.
   The new group below covers a plan that ends in a real safety search, sliced and one-shot.
3. Replace the test `'9 bi: bi bắt buộc bị chắn ở mọi lỗ thì phòng thủ ngay'` with:

```dart
    test('9 bi: bi bắt buộc bị chắn ở mọi lỗ thì phòng thủ ngay, không thử cú ăn bi nào', () {
      var calls = 0;
      final job = PlannerJob(blockedEverywhereTable(),
          aim: recordingAim((_, _, _) => calls++), safety: noSafetyPhysics);
      final events = job.step(budget: const Duration(days: 1));
      expect(job.isDone, isTrue);
      expect(events.whereType<PlanDone>().single.steps.single.kind, PlanStepKind.safety);
      expect(calls, 0);
    });
```

4. Append inside `main()`:

```dart
  group('bước phòng thủ tìm cú thủ (spec cú phòng thủ 3.1, 3.6)', () {
    test('không có cú thủ hợp lệ: giữ câu cũ, safety null, kế hoạch dừng', () {
      final steps = planToEnd(blockedEverywhereTable(), safety: noSafetyPhysics);
      expect(steps.single.kind, PlanStepKind.safety);
      expect(steps.single.safety, isNull);
      expect(steps.single.ballNum, 1);
    });

    test('đang tìm cú thủ: chưa báo bước nào, searchingSafety bật; xong thì báo đúng một bước', () {
      final job = PlannerJob(noPotTable(), safety: noSafetyPhysics);
      final first = job.step(maxSimulations: 1);
      expect(first, isEmpty);
      expect(job.searchingSafety, isTrue);
      final events = <PlannerEvent>[];
      while (!job.isDone) {
        events.addAll(job.step(budget: const Duration(days: 1)));
      }
      expect(events.whereType<StepReady>(), hasLength(1));
      expect(events.last, isA<PlanDone>());
      expect(job.searchingSafety, isFalse);
    });

    test('hủy giữa lúc tìm cú thủ thì không báo thêm gì', () {
      final job = PlannerJob(noPotTable());
      while (!job.searchingSafety) {
        job.step(maxSimulations: 1);
      }
      job.step(maxSimulations: 3);
      job.cancel();
      final sims = job.simulations;
      for (var i = 0; i < 20; i++) {
        expect(job.step(), isEmpty);
      }
      expect(job.simulations, sims);
      expect(job.steps, isEmpty);
    });

    group('trên lõi thật, bàn hết đường ăn', () {
      // Một lần tìm đủ tốn vài giây (độ lệch 1 của kế hoạch): tính một lần.
      late List<PlanStep> whole;
      setUpAll(() => whole = planToEnd(noPotTable()));

      test('bước phòng thủ mang đúng cú thủ của lần tìm riêng, cbFrom vẫn là bi cái', () {
        final setup = noPotTable();
        final s = whole.single;
        expect(s.cbFrom, setup.cue);
        final alone = searchToEnd(SafetyContext(
            game: setup.game, cue: setup.cue, balls: setup.balls, table: setup.table));
        expect(safetyFingerprint(s.safety), safetyFingerprint(alone));
        expect(s.safety!.kind, SafetyKind.direct);
      });

      test('chạy từng lát cho đúng y một mạch, cả bước phòng thủ', () {
        final job = PlannerJob(noPotTable());
        while (!job.isDone) {
          job.step(maxSimulations: 7);
        }
        expect(fingerprint(job.steps), fingerprint(whole));
      });
    });
  });
```

In `test/features/training/planner_step_lines_test.dart`, change `final fallback = planToEnd(fallbackTable());` to `final fallback = planToEnd(fallbackTable(), safety: noSafetyPhysics);`.

In `test/features/training/planner_steps_view_test.dart`:
1. Add `SafetyPhysics safety = const SafetyPhysics()` to `open(...)`'s named parameters and pass `safety: safety` to `PlannerStepsView`. Import `safety_aim.dart`.
2. Pass `safety: noSafetyPhysics` in `'bàn phòng thủ: các bi chắn vẫn thấy, vẽ mờ'`, `'bước cuối: nút đổi thành Xong bàn; bước phòng thủ …'` and `'bước dự phòng: …'`.

Update `fingerprint` in `test/support/planner_tables.dart`: add `s.safety == null ? null : safetyFingerprint(s.safety),` as the last element of the per-step list.

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/domain/planner/planner_job_test.dart`
Expected: compile errors (`safety:` parameter, `searchingSafety`, `PlanStep.safety` field missing).

- [ ] **Step 3: `PlanStep` carries the safety**

In `plan_step.dart`:
1. Add `import 'package:poolcoachai/domain/planner/safety_shot.dart';`.
2. Add `this.safety,` to the main constructor's parameters (after `this.nextBallNum,`).
3. Replace the `PlanStep.safety` constructor's first line with `const PlanStep.safety({required this.cbFrom, this.ballNum, this.safety})`.
4. Add the field after `nextBallNum`:

```dart
  /// Cú thủ đã tìm (spec cú phòng thủ 3.7); null ở bước thường, và ở bước
  /// phòng thủ khi không còn cú thủ hợp lệ nào. 8 bi: [ballNum] vẫn null,
  /// bi được chạm là `safety.ballNum`.
  final SafetyShot? safety;
```

5. In the doc comment of `enum PlanStepKind`, replace "safety: phòng thủ, kế hoạch dừng" with "safety: phòng thủ — tìm cú thủ rồi kế hoạch dừng, vì tới lượt đối thủ".

- [ ] **Step 4: `PlannerJob` runs the search**

In `planner_job.dart`:
1. Add imports: `safety_aim.dart`, `safety_job.dart`, `safety_options.dart`.
2. Constructor and fields:

```dart
  PlannerJob(this.setup, {this.aim = aimShot, this.safety = const SafetyPhysics()})
      : _cue = setup.cue,
        _remaining = [...setup.balls]..sort((a, b) => a.number.compareTo(b.number)),
        _finder = CandidateFinder(game: setup.game, table: setup.table);

  final TableSetup setup;
  final AimShotFn aim;

  /// Lõi của việc tìm cú thủ; test thay để bước phòng thủ ra nhanh.
  final SafetyPhysics safety;

  /// Việc tìm cú thủ của bước phòng thủ đang chờ báo ra (spec cú phòng thủ 3.6).
  SafetyJob? _search;
  PlanStep? _bareSafety;
```

3. Getters:

```dart
  /// Đang tìm cú thủ: màn hình nói "Đang tìm cú thủ…" thay "Đang tính bước".
  bool get searchingSafety => _search != null && !_done;

  /// Số lần mô phỏng đã chạy, kể cả lần dò và mô phỏng của việc tìm cú thủ.
  int get simulations => _sims.length + (_search?.simulations ?? 0);
```

(replace the old `simulations` getter).
4. In `step`, replace the body of the `while (!_done)` loop up to `final unit = …` with:

```dart
      final started = clock.elapsed;
      final search = _search;
      if (search != null) {
        if (search.work()) simulated++;
        if (search.isDone) {
          final bare = _bareSafety!;
          _commit(
              PlanStep.safety(cbFrom: bare.cbFrom, ballNum: bare.ballNum, safety: search.result),
              events);
        }
      } else {
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
      }
```

5. At the top of `_commit`, before `_steps.add(step);`:

```dart
    if (step.kind == PlanStepKind.safety && _search == null) {
      // Bước phòng thủ: tìm cú thủ trước khi báo bước ra. Kế hoạch vẫn dừng
      // sau bước này vì tới lượt đối thủ (spec cú phòng thủ 3.1).
      _bareSafety = step;
      _search = SafetyJob(
        SafetyContext(game: setup.game, cue: step.cbFrom, balls: _remaining, table: setup.table),
        physics: safety,
      );
      return;
    }
```

6. In `cancel()`: `void cancel() { _cancelled = true; _search?.cancel(); }`.
7. Replace `planToEnd`:

```dart
/// Chạy một mạch tới hết — cho test, công cụ dò bàn và đo tốc độ.
List<PlanStep> planToEnd(TableSetup setup,
    {AimShotFn aim = aimShot, SafetyPhysics safety = const SafetyPhysics()}) {
  final job = PlannerJob(setup, aim: aim, safety: safety);
  while (!job.isDone) {
    job.step(budget: const Duration(days: 1));
  }
  return job.steps;
}
```

- [ ] **Step 5: Pass the physics through the steps view**

In `planner_steps_view.dart`:
1. Import `package:poolcoachai/domain/planner/safety_aim.dart`.
2. Add `this.safety = const SafetyPhysics(),` to the constructor and the field:

```dart
  /// Lõi của việc tìm cú thủ; test thay để bước phòng thủ ra nhanh.
  @visibleForTesting
  final SafetyPhysics safety;
```

3. In `_start`, create the job with `PlannerJob(setup, aim: widget.aim, safety: widget.safety)`.

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/domain/planner test/features/training && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`. `prd_section7_test.dart` keeps the real core for test 6 (`blockedEverywhereTable`) and for `fallbackTable`; those two plans now run a real safety search and take a few seconds more.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/planner/plan_step.dart lib/domain/planner/planner_job.dart lib/features/training/presentation/planner/planner_steps_view.dart test/support/planner_tables.dart test/domain/planner/planner_job_test.dart test/features/training/planner_step_lines_test.dart test/features/training/planner_steps_view_test.dart
git commit -m "Search a safety shot at the planner's safety step before reporting it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 25: The safety performance test — STOP for the owner if the target is missed

**Files:**
- Test: `test/domain/planner/safety_perf_test.dart` (tag `perf`)
- Modify: `docs/superpowers/logs/2026-10-07-run-out-planner.md` (measurements)

**Interfaces:**
- Consumes: `SafetyJob`, `SafetyContext`, `planToEnd`, `sliceBudget`, the fixtures.
- Produces: `flutter test --tags perf --run-skipped test/domain/planner/safety_perf_test.dart`. It prints, for the kick table and the no-pot table, the one-shot search time on the VM, the number of units, and the slice median, p95 and maximum. It fails if a search takes more than `safetyVmBudgetMs` (600 ms) or the median slice exceeds 1.5 × `sliceBudget`.

**Why 600 ms on the VM.** Deviation 20 reads "vài giây" as at most 5 s in Chrome. Chrome runs about 2× the VM. Sliced at 4 ms per 16.7 ms frame, the search gets about a quarter of each frame, so the wall time is about 4× the CPU time. So 5 s of wall time is about 5000 / (2 × 4.2) ≈ 600 ms on the VM.

**Expected outcome: FAIL.** The prototype measured 4.3–11.0 s for one ball's direct search (deviation 1). This task exists to put the real numbers in front of the owner before any screen work.

- [ ] **Step 1: Write the test**

`test/domain/planner/safety_perf_test.dart`:

```dart
@Tags(['perf'])
library;

// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart';
import 'package:poolcoachai/domain/planner/planner_job.dart';
import 'package:poolcoachai/domain/planner/safety_job.dart';
import 'package:poolcoachai/domain/planner/safety_options.dart';
import 'package:poolcoachai/domain/planner/table_setup.dart';

import '../../support/planner_tables.dart';

/// "Vài giây" trên Chrome giả lập điện thoại (spec cú phòng thủ mục 6), đọc là
/// ≤ 5 s: Chrome chậm khoảng gấp đôi VM, và lát 4 ms mỗi khung 16,7 ms cho
/// việc tìm khoảng một phần tư thời gian — 5000 / (2 × 4,2) ≈ 600 ms trên VM.
const safetyVmBudgetMs = 600;

void main() {
  SafetyContext contextOf(TableSetup s) =>
      SafetyContext(game: s.game, cue: s.cue, balls: s.balls, table: s.table);

  final tables = {
    'đui A băng': snookerOneRailTable(),
    'hết đường ăn': noPotTable(),
  };

  test('tìm cú thủ một mạch trên Dart VM: in thời gian, gác ≤ $safetyVmBudgetMs ms', () {
    planToEnd(railTable()); // làm nóng JIT
    final over = <String>[];
    for (final MapEntry(key: name, value: setup) in tables.entries) {
      final job = SafetyJob(contextOf(setup));
      final w = Stopwatch()..start();
      while (!job.isDone) {
        job.step(budget: const Duration(days: 1));
      }
      final ms = w.elapsedMilliseconds;
      print('$name: $ms ms, ${job.simulations} lần dò/mô phỏng, '
          '${job.options.length} phương án, thử ${job.triedRailCounts.toList()..sort()} băng');
      if (ms > safetyVmBudgetMs) over.add('$name $ms ms');
    }
    expect(over, isEmpty, reason: 'quá $safetyVmBudgetMs ms: $over');
  });

  test('lát lúc tìm cú thủ giữ quanh sliceBudget; in p95 và lát dài nhất', () {
    planToEnd(railTable());
    final job = SafetyJob(contextOf(noPotTable()));
    final micros = <int>[];
    while (!job.isDone) {
      final w = Stopwatch()..start();
      job.step();
      micros.add(w.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2] / 1000;
    final p95 = micros[((micros.length - 1) * 0.95).floor()] / 1000;
    print('lát tìm cú thủ: trung vị $median ms, p95 $p95 ms, '
        'dài nhất ${micros.last / 1000} ms, ${micros.length} lát');
    expect(median, lessThan(sliceBudget.inMicroseconds / 1000 * 1.5));
  });
}
```

- [ ] **Step 2: Run it alone**

Run: `"$FLUTTER" test --tags perf --run-skipped test/domain/planner/safety_perf_test.dart`
Expected: the slice test PASSES on a quiet machine (a unit is one probe series or one simulation; at plan time the median was 4.9 ms against the 6 ms gate, and 7.6 ms under CPU contention — rerun alone before reporting). The first test is expected to FAIL (5045 ms and 4174 ms at plan time); copy both printed lines.

- [ ] **Step 3: Confirm the default run skips it**

Run: `"$FLUTTER" test test/domain/planner`
Expected: PASS, with the perf and probe tests reported as skipped.

- [ ] **Step 4: Log the numbers and commit the test**

Append to the build log:

```markdown
## Safety search speed (Task 25)

- Dart VM, one-shot search: <paste the two lines of the first test>.
- Slices while searching: <paste the `lát tìm cú thủ: …` line>.
- Plan-time prototype (a35667b): one ball's direct search 4.3–11.0 s with exact pruning; Chrome estimate ≈ 2× CPU and ≈ 4× wall at 4 ms slices.
```

```bash
git add test/domain/planner/safety_perf_test.dart docs/superpowers/logs/2026-10-07-run-out-planner.md
git commit -m "Measure the safety search on the Dart VM against a few-seconds Chrome budget

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: STOP if the first test failed**

Report to the owner, through the controller: the two printed lines, the prototype numbers of deviation 1, and these candidate changes. **Do not pick one yourself.**
- **Áp phê as a fallback inside the safety search too:** try the 135 no-spin options per ball first, and the 540 spin options only if none is legal. This changes spec decision 4. It cuts the direct search to roughly a fifth — still several seconds in Chrome at a 4 ms slice.
- **Fewer power levels for safeties** (for example 30 · 60 · 90): cuts direct options and kicks by 40 %.
- **A longer slice only while the safety search runs** (the user is waiting on *Đang tìm cú thủ…*, not dragging). This trades the frame gate during that wait.
- **Accept a long wait** with the progress line, and revisit with the Web Worker after merge.
- **A Web Worker now:** out of scope by the owner's decision; it would still leave about 3–22 s at today's option count.

Continue with Task 26 only after the owner's answer. If the owner changes the search (option count, tiers, slice), do it as a new task inserted here with its own tests, and rerun Tasks 23 and 25.

---

### Task 26: Safety strings and the step's info lines

**Files:**
- Modify: `lib/core/strings/vi.dart` (safety strings, `planSummary`)
- Modify: `lib/features/training/presentation/simulator/info_lines.dart` (`squirtLineFor`)
- Modify: `lib/features/training/presentation/planner/step_lines.dart` (safety branch)
- Test: `test/core/strings/vi_planner_test.dart`, `test/features/training/planner_step_lines_test.dart`

**Interfaces:**
- Consumes: `SafetyShot`, `RailAim`, `OpponentView`, `ThicknessSide`, `SafetyReason` (Task 19); `PlanStep.safety` (Task 24); `PlannerJob.searchingSafety`.
- Produces:
  - `Vi.planSearchingSafety`, `Vi.safetySnookered(int ballNum)`, `Vi.safetyNoPot`, `Vi.safetyRail(Rail rail)`, `Vi.safetyDiamond(double d)`, `Vi.safetyKick(int rails, RailAim aim)`, `Vi.safetyThickness(double thickness, ThicknessSide side)`, `Vi.safetyOpponent(OpponentView o)`, `Vi.safetyTolerance(int hard, int samples)`, `Vi.safetyOpponentSnookered`, `Vi.planSafetyLegend`, `Vi.safetyHeadline(SafetyShot s)`, `Vi.safetyAimLine(SafetyShot s)`.
  - `Vi.planSummary(PlanStep? step, {required int index, required int total, bool searchingSafety = false})`.
  - `String squirtLineFor(SideSpin spin, double? aimOffsetDeg, double distance, TableSpec table, Stroke stroke, double power)`; `squirtLine` delegates to it.
  - `planStepLines` returns the safety lines when `step.safety != null`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/strings/vi_planner_test.dart` (add imports `safety_shot.dart`, `cushion.dart`, `pocket_choice.dart`):

```dart
  group('cú phòng thủ (spec cú phòng thủ mục 5.2, thuật ngữ)', () {
    test('câu đầu: bị đui hay hết đường ăn', () {
      expect(Vi.safetySnookered(3), 'Bi cái bị đui bi 3 — đánh A băng để thủ.');
      expect(Vi.safetyNoPot, 'Không còn đường ăn bi — nên thủ bi.');
      expect(Vi.planSearchingSafety, 'Đang tìm cú thủ…');
    });

    test('A băng: số băng, chấm (dấu phẩy thập phân), tên băng theo hướng nhìn trên màn', () {
      expect(Vi.safetyKick(2, const RailAim(rail: Rail.top, diamond: 2.5, at: Vec2(80, 3))),
          'A băng 2 băng: ngắm chấm 2,5 băng dài trên.');
      expect(Vi.safetyKick(1, const RailAim(rail: Rail.right, diamond: 3, at: Vec2(251, 95))),
          'A băng 1 băng: ngắm chấm 3 băng ngắn phải.');
      expect(Rail.values.map(Vi.safetyRail),
          ['băng ngắn trái', 'băng ngắn phải', 'băng dài trên', 'băng dài dưới']);
    });

    test('độ dày: trọn bi, hoặc phân số kèm bên lệch', () {
      expect(Vi.safetyThickness(1, ThicknessSide.full), 'Ăn trọn bi.');
      expect(Vi.safetyThickness(0.5, ThicknessSide.left), 'Ăn ½ bi, lệch bên trái.');
      expect(Vi.safetyThickness(0.75, ThicknessSide.right), 'Ăn ¾ bi, lệch bên phải.');
      expect(Vi.safetyThickness(0.25, ThicknessSide.left), 'Ăn ¼ bi, lệch bên trái.');
      expect(Vi.safetyThickness(0.125, ThicknessSide.right), 'Ăn ⅛ bi, lệch bên phải.');
    });

    test('kết quả cho đối thủ: đui, cú dễ nhất có số độ, hoặc hết đường ăn', () {
      const ball = PlacedBall(number: 4, pos: Vec2(127, 100));
      expect(Vi.safetyOpponent(const OpponentView(snookered: true, ball: ball)), 'Đối thủ bị đui.');
      expect(Vi.safetyOpponent(const OpponentView(snookered: false, ball: ball)),
          'Đối thủ không còn đường ăn.');
      final g = bestPocket(cue: const Vec2(127, 63.5), object: ball.pos)!;
      expect(Vi.safetyOpponent(OpponentView(snookered: false, ball: ball, easiest: g)),
          'Cú dễ nhất của đối thủ: bi 4 vào lỗ ${Vi.simPocket(g.pocket)}, góc cắt ${g.angle.round()}°.');
      expect(Vi.safetyTolerance(5, 7), '5/7 mức lực vẫn để đối thủ khó.');
    });
  });
```

In `test/features/training/planner_step_lines_test.dart` (add imports `safety_shot.dart`, `cushion.dart`, `aim.dart`, `simulate_shot.dart`):

```dart
  /// Cú thủ dựng tay: chỉ để kiểm câu chữ, mọi số đã biết trước.
  SafetyShot shot({
    SafetyReason reason = SafetyReason.noPot,
    SafetyKind kind = SafetyKind.direct,
    int rails = 0,
    RailAim? railAim,
    double thickness = 0.5,
    ThicknessSide side = ThicknessSide.left,
    Stroke stroke = Stroke.stun,
    SideSpin spin = const SideSpin.none(),
    double power = 45,
    OpponentView opponent = const OpponentView(snookered: true, ball: PlacedBall(number: 1, pos: Vec2(200, 100))),
  }) =>
      SafetyShot(
        reason: reason,
        kind: kind,
        rails: rails,
        ballNum: 1,
        thickness: thickness,
        side: side,
        stroke: stroke,
        spin: spin,
        power: power,
        aimed: AimedShot(
          trace: const ShotTrace(
            cueBefore: [Vec2(60, 100), Vec2(145, 45)],
            cueAfter: [Vec2(145, 45), Vec2(120, 20)],
            objectPath: [Vec2(150, 40), Vec2(200, 100)],
            contactCue: Vec2(145, 45),
            rails: [],
            cuePocket: null,
            objectPocket: null,
            cueEnd: Vec2(120, 20),
          ),
          uncompensated: null,
          aimOffsetDeg: 1.5,
          verticalOffset: 0,
          stunReached: true,
          converged: true,
        ),
        railAim: railAim,
        opponent: opponent,
        jitterEnds: (minus: null, plus: null),
        tolerance: 5,
        contactDistance: 100,
        total: 20,
      );

  List<String> safetyLines(SafetyShot s) => planStepLines(
      PlanStep.safety(cbFrom: const Vec2(60, 100), ballNum: 1, safety: s), index: 0, total: 1);

  group('bước phòng thủ có cú thủ (spec cú phòng thủ 5.2)', () {
    test('không đui: hết đường ăn, bi, độ dày, kiểu đánh, lực, đối thủ, độ chịu sai số', () {
      expect(safetyLines(shot()), [
        Vi.planStepHeader(1, 1),
        Vi.safetyNoPot,
        Vi.planBallLine(1),
        Vi.safetyThickness(0.5, ThicknessSide.left),
        Vi.simStrokeLine(Stroke.stun),
        Vi.simPowerLine(45),
        Vi.safetyOpponent(shot().opponent),
        Vi.safetyTolerance(5, toleranceSamples),
      ]);
    });

    test('bị đui: câu A băng thay câu độ dày', () {
      const aim = RailAim(rail: Rail.top, diamond: 3.5, at: Vec2(110, 3));
      final lines = safetyLines(shot(
          reason: SafetyReason.snookered, kind: SafetyKind.kick, rails: 1, railAim: aim,
          thickness: 1, side: ThicknessSide.full));
      expect(lines[1], Vi.safetySnookered(1));
      expect(lines, contains(Vi.safetyKick(1, aim)));
      expect(lines, isNot(contains(Vi.safetyThickness(1, ThicknessSide.full))));
    });

    test('áp phê: đúng dòng của màn mô phỏng ở đúng quãng bi cái → bi ảo', () {
      final s = shot(spin: const SideSpin(SpinSide.right, 1), stroke: Stroke.follow);
      final lines = safetyLines(s);
      expect(lines, contains(Vi.simSpinLine(s.spin)));
      expect(lines, contains(squirtLineFor(s.spin, 1.5, 100, table, Stroke.follow, 45)));
    });

    test('cảnh báo lực cao hoặc trô như bước thường', () {
      expect(safetyLines(shot(power: riskPower)), contains(Vi.planRiskWarning));
      expect(safetyLines(shot(stroke: Stroke.draw)), contains(Vi.planRiskWarning));
      expect(safetyLines(shot()), isNot(contains(Vi.planRiskWarning)));
    });

    test('nhãn bàn: câu đầu, câu ngắm, kết quả cho đối thủ', () {
      final s = shot();
      expect(Vi.planSummary(PlanStep.safety(cbFrom: const Vec2(1, 1), ballNum: 1, safety: s),
              index: 0, total: 1),
          'Bàn kế hoạch. Bước 1 / 1: ${Vi.safetyNoPot} ${Vi.safetyThickness(0.5, ThicknessSide.left)} '
          '${Vi.safetyOpponent(s.opponent)}');
      expect(Vi.planSummary(null, index: 0, total: 1, searchingSafety: true),
          'Bàn kế hoạch. ${Vi.planSearchingSafety}');
    });
  });
```

Extend the existing test `'không câu nào là lời khuyên ngắm theo độ …'`: add `planToEnd(snookerOneRailTable())` and `planToEnd(noPotTable())` to `plans`, and replace its inner check so the opponent line may carry degrees but nothing else:

```dart
        for (final line in shown) {
          expect(line, isNot(matches(aimInDegrees)), reason: line);
          final offset = plan[i].aimed?.aimOffsetDeg ?? plan[i].safety?.aimed.aimOffsetDeg;
          if (offset != null && offset.abs() >= 0.05) {
            expect(line, isNot(contains('${offset.abs().toStringAsFixed(1)}°')), reason: line);
          }
          // Số độ chỉ được có ở kết quả cho đối thủ (spec quyết định 9).
          if (line.contains('°') && plan[i].safety != null) {
            expect(line, contains(Vi.safetyOpponent(plan[i].safety!.opponent)), reason: line);
          }
        }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/core/strings/vi_planner_test.dart test/features/training/planner_step_lines_test.dart`
Expected: compile errors (new `Vi` members, `squirtLineFor`, `searchingSafety` missing).

- [ ] **Step 3: Strings**

In `vi.dart`, add imports `package:poolcoachai/domain/planner/safety_shot.dart` and `package:poolcoachai/domain/table_physics/cushion.dart`. Then:
1. Replace `planSummary`:

```dart
  /// Nhãn semantics của bàn ở màn từng bước (spec mục 7.4): bi, lỗ, kiểu
  /// đánh, lực của bước đang xem; bước phòng thủ có cú thủ thì câu đầu, câu
  /// ngắm và kết quả cho đối thủ. [step] null khi bước đầu còn đang tính.
  static String planSummary(PlanStep? step,
      {required int index, required int total, bool searchingSafety = false}) {
    const head = 'Bàn kế hoạch.';
    if (step == null) {
      return '$head ${searchingSafety ? planSearchingSafety : planComputing(index + 1, total)}';
    }
    final at = planStepHeader(index + 1, total);
    if (step.kind == PlanStepKind.safety) {
      final s = step.safety;
      if (s == null) return '$head $at: ${planSafety(step.ballNum)}';
      return '$head $at: ${safetyHeadline(s)} ${safetyAimLine(s)} ${safetyOpponent(s.opponent)}';
    }
    return '$head $at: bi ${step.ballNum}, lỗ ${simPocket(step.pocket!)}, '
        '${simStroke(step.stroke)}, lực ${step.power.round()}%.';
  }
```

2. Add after `planRecompute`:

```dart
  // Cú phòng thủ — docs/superpowers/specs/2026-10-07-poolcoachai-planner-safety-design.md.
  // Câu nào có số thì số do lõi tìm cú thủ tính ra; ở đây chỉ ghép chữ.
  static const planSearchingSafety = 'Đang tìm cú thủ…';
  static String safetySnookered(int ballNum) => 'Bi cái bị đui bi $ballNum — đánh A băng để thủ.';
  static const safetyNoPot = 'Không còn đường ăn bi — nên thủ bi.';

  static String safetyHeadline(SafetyShot s) =>
      s.reason == SafetyReason.snookered ? safetySnookered(s.ballNum) : safetyNoPot;

  /// Câu ngắm: A băng nói chấm, trực tiếp nói độ dày. Không bao giờ nói độ.
  static String safetyAimLine(SafetyShot s) => switch (s.railAim) {
        final aim? => safetyKick(s.rails, aim),
        null => safetyThickness(s.thickness, s.side),
      };

  /// Tên băng theo hướng nhìn trên màn.
  static String safetyRail(Rail rail) => switch (rail) {
        Rail.left => 'băng ngắn trái',
        Rail.right => 'băng ngắn phải',
        Rail.top => 'băng dài trên',
        Rail.bottom => 'băng dài dưới',
      };

  /// Số chấm, làm tròn nửa chấm sẵn ở lõi; dấu phẩy thập phân: "2,5".
  static String safetyDiamond(double d) =>
      d == d.roundToDouble() ? '${d.round()}' : '${d.floor()},5';

  static String safetyKick(int rails, RailAim aim) =>
      'A băng $rails băng: ngắm chấm ${safetyDiamond(aim.diamond)} ${safetyRail(aim.rail)}.';

  static String _fraction(double thickness) => switch ((thickness * 8).round()) {
        6 => '¾',
        4 => '½',
        2 => '¼',
        1 => '⅛',
        _ => '${(thickness * 100).round()}%',
      };

  /// Độ dày chạm bi, theo hướng nhìn từ bi cái.
  static String safetyThickness(double thickness, ThicknessSide side) => switch (side) {
        ThicknessSide.full => 'Ăn trọn bi.',
        ThicknessSide.left => 'Ăn ${_fraction(thickness)} bi, lệch bên trái.',
        ThicknessSide.right => 'Ăn ${_fraction(thickness)} bi, lệch bên phải.',
      };

  /// Kết quả cho đối thủ. Số độ ở đây là độ khó của đối thủ, không phải lời
  /// khuyên ngắm (spec quyết định 9).
  static String safetyOpponent(OpponentView o) {
    if (o.snookered) return 'Đối thủ bị đui.';
    final g = o.easiest;
    final ball = o.ball;
    if (g == null || ball == null) return 'Đối thủ không còn đường ăn.';
    return 'Cú dễ nhất của đối thủ: bi ${ball.number} vào lỗ ${simPocket(g.pocket)}, '
        'góc cắt ${g.angle.round()}°.';
  }

  static String safetyTolerance(int hard, int samples) =>
      '$hard/$samples mức lực vẫn để đối thủ khó.';

  /// Chữ trên bàn cạnh đường bị chắn của đối thủ.
  static const safetyOpponentSnookered = 'Đối thủ bị đui';

  /// Chú giải thêm khi bước đang xem là cú thủ (spec mục 5.1).
  static List<String> get planSafetyLegend => const [
        'Vòng vàng đậm: điểm ngắm trên băng đầu tiên (A băng); số ở mép bàn là chấm.',
        'Nét xám và vòng nét đứt xám: bi hợp lệ sau va chạm và chỗ nó dừng.',
        'Nét đỏ mờ: cú dễ nhất của đối thủ sau cú thủ.',
      ];
```

- [ ] **Step 4: One áp phê line for both screens**

In `info_lines.dart`, replace `squirtLine` with:

```dart
/// Dòng áp phê — màn Mô phỏng góc cắt, màn Kế hoạch dọn bàn và cú thủ dùng
/// chung, không viết lại (spec 2026-10-07 mục 7.2).
String squirtLine(SideSpin spin, AimedShot? aimed, ShotGeometry geometry, TableSpec table,
        Stroke stroke, double power) =>
    squirtLineFor(spin, aimed?.aimOffsetDeg, geometry.cue.distanceTo(geometry.ghost), table,
        stroke, power);

/// Dòng áp phê ở quãng [distance] (bi cái → bi ảo hình học, cm). Độ lệch
/// điểm ngắm là bề ngang hướng cơ đã dò xê dịch so với hướng hình học
/// ([aimOffsetDeg]) tại quãng đó: gộp cả squirt, swerve lẫn ném, đúng lượng
/// người chơi phải dịch. Không có [aimOffsetDeg] (không mô phỏng được) thì
/// chỉ nói góc lệch của bi cái; số độ của lệch ngắm không bao giờ nói ra,
/// chỉ đổi thành đầu cơ.
String squirtLineFor(SideSpin spin, double? aimOffsetDeg, double distance, TableSpec table,
    Stroke stroke, double power) {
  final deg = squirtAngle(sideOffsetOf(spin), table.radius) * 180 / math.pi;
  final units = aimOffsetDeg == null
      ? null
      : aimShiftUnits(
          distance * math.tan(aimOffsetDeg.abs() * math.pi / 180), table.ballDiameter);
  // SAWS chỉ đi kèm khi có lượng dịch điểm ngắm để bù.
  final bhe = units == null
      ? null
      : sawsBhePercent(distance: distance, power: power, stroke: stroke);
  return Vi.simSquirt(deg, units?.tips, units?.ballDenominator, bhe, units?.ballCount);
}
```

- [ ] **Step 5: Safety lines**

In `step_lines.dart`, replace the `if (step.kind == PlanStepKind.safety) { … }` block with:

```dart
  if (step.kind == PlanStepKind.safety) {
    final s = step.safety;
    if (s == null) {
      return [
        header,
        if (step.ballNum case final n?) Vi.planBallLine(n),
        Vi.planSafety(step.ballNum),
      ];
    }
    // Cú thủ (spec cú phòng thủ 5.2): không câu nào khuyên ngắm theo độ;
    // số độ chỉ ở kết quả cho đối thủ.
    return [
      header,
      Vi.safetyHeadline(s),
      Vi.planBallLine(s.ballNum),
      Vi.safetyAimLine(s),
      Vi.simStrokeLine(s.stroke),
      Vi.simPowerLine(s.power),
      if (!s.spin.isNone) ...[
        Vi.simSpinLine(s.spin),
        squirtLineFor(s.spin, s.aimed.aimOffsetDeg, s.contactDistance, table, s.stroke, s.power),
      ],
      Vi.safetyOpponent(s.opponent),
      Vi.safetyTolerance(s.tolerance, toleranceSamples),
      if (s.power >= riskPower || s.stroke == Stroke.draw) Vi.planRiskWarning,
    ];
  }
```

Update the function's doc comment: "Bước phòng thủ có cú thủ thì nói cú thủ (spec cú phòng thủ 5.2); không có thì giữ câu cũ."

- [ ] **Step 6: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/core/strings test/features/training && "$FLUTTER" test test/architecture_test.dart && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/core/strings/vi.dart lib/features/training/presentation/simulator/info_lines.dart lib/features/training/presentation/planner/step_lines.dart test/core/strings/vi_planner_test.dart test/features/training/planner_step_lines_test.dart
git commit -m "Say the safety shot in the owner's terms: snookered or no pot, diamonds or thickness, and the opponent's result

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 27: Draw the safety step and show the search

**Files:**
- Modify: `lib/features/training/presentation/planner/planner_painter.dart`
- Modify: `lib/features/training/presentation/planner/planner_steps_view.dart`
- Test: `test/features/training/planner_steps_view_test.dart`

**Interfaces:**
- Consumes: `PlanStep.safety`, `SafetyShot`, `Vi.planSearchingSafety`, `Vi.planSafetyLegend`, `Vi.safetyOpponentSnookered`, `PlannerJob.searchingSafety`, `longRailDiamonds`, `shortRailDiamonds`.
- Produces: `PlannerPainter` draws, for a step with `safety`, from bottom to top (spec §5.1):
  1. other balls faint (existing ghosts);
  2. the opponent's easiest shot in faint red (cue end → ghost, ball → pocket), or a dashed red line to the ball plus *"Đối thủ bị đui"* when snookered;
  3. the cue ball's simulated path: before contact dashed white, after contact dashed jade, a yellow dot at every cue rail hit, a white dashed ring where it stops;
  4. for *A băng*: a thick gold ring at the first rail hit and the *chấm* numbers on the frame (long rails 0–8, short rails 0–4);
  5. the legal ball's path after contact and a dashed grey ring where it stops;
  6. the jitter bar between `jitterEnds` through the stop point.
  The steps view shows *Đang tìm cú thủ…* while searching, shows the touched ball, and adds `Vi.planSafetyLegend` under the legend for a safety step with a shot.

- [ ] **Step 1: Write the failing tests**

In `planner_steps_view_test.dart`:
1. Add to `_SpyCanvas`:

```dart
  var paragraphs = 0;

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => paragraphs++;
```

(and `import 'dart:ui' show Paragraph;` if `Paragraph` is not exported through `material.dart`).
2. Append inside `main()`:

```dart
  group('bước phòng thủ có cú thủ (spec cú phòng thủ 5.1)', () {
    late PlanStep kick;
    late PlanStep direct;

    setUpAll(() {
      kick = planToEnd(snookerOneRailTable()).single;
      direct = planToEnd(noPotTable()).single;
    });

    test('A băng: vòng vàng ở điểm ngắm trên băng, số chấm ở mép bàn', () {
      const size = Size(540, 286);
      const layout = TableLayout(size: size);
      final withKick = _SpyCanvas();
      PlannerPainter(PlannerScene(cue: kick.cbFrom, step: kick)).paint(withKick, size);
      final withDirect = _SpyCanvas();
      PlannerPainter(PlannerScene(cue: direct.cbFrom, step: direct)).paint(withDirect, size);
      final at = layout.toCanvas(kick.safety!.railAim!.at);
      expect(withKick.circles.any((c) => (c.$1 - at).distance < 1e-6), isTrue);
      // Chữ "Đối thủ bị đui" cũng là một đoạn chữ: trừ ra trước khi đếm số chấm.
      int label(PlanStep s) => s.safety!.opponent.snookered && s.safety!.opponent.ball != null ? 1 : 0;
      // 9 + 9 số trên hai băng dài, 5 + 5 trên hai băng ngắn.
      expect((withKick.paragraphs - label(kick)) - (withDirect.paragraphs - label(direct)),
          2 * (longRailDiamonds + 1) + 2 * (shortRailDiamonds + 1));
    });

    test('cú dễ nhất của đối thủ vẽ mờ màu đỏ; đối thủ đui thì ghi chữ', () {
      const size = Size(540, 286);
      for (final step in [kick, direct]) {
        final canvas = _SpyCanvas();
        PlannerPainter(PlannerScene(cue: step.cbFrom, step: step)).paint(canvas, size);
        final red = canvas.lines.where((p) =>
            p.color.toARGB32() & 0xFFFFFF == AppColors.danger.toARGB32() & 0xFFFFFF &&
            p.color.a < 1);
        if (step.safety!.opponent.easiest != null) expect(red, isNotEmpty);
      }
    });

    test('painter vẽ được bước phòng thủ không có cú thủ', () {
      final canvas = _SpyCanvas();
      expect(
          () => PlannerPainter(PlannerScene(
                  cue: const Vec2(40, 100), step: const PlanStep.safety(cbFrom: Vec2(40, 100))))
              .paint(canvas, const Size(540, 286)),
          returnsNormally);
    });
  });

  testWidgets('đang tìm cú thủ: dòng Đang tìm cú thủ… thay Đang tính bước, xong thì hiện bước',
      (tester) async {
    await open(tester, noPotTable(), maxSimulationsPerFrame: 1, safety: noSafetyPhysics);
    await tester.pump();
    await tester.pump();
    expect(find.text(Vi.planSearchingSafety), findsOneWidget);
    expect(find.textContaining('Đang tính bước'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(Vi.planSearchingSafety), findsNothing);
    expect(find.text(Vi.planSafety(1)), findsOneWidget);
  });

  testWidgets('rời màn giữa lúc tìm cú thủ: không lỗi, việc tính bị hủy', (tester) async {
    await open(tester, noPotTable(), maxSimulationsPerFrame: 1);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$FLUTTER" test test/features/training/planner_steps_view_test.dart`
Expected: FAIL — no ring at the rail aim, no diamond paragraphs, no *Đang tìm cú thủ…* line.

- [ ] **Step 3: Painter**

In `planner_painter.dart`, add imports `dart:math as math`, `package:poolcoachai/core/strings/vi.dart`, `package:poolcoachai/domain/planner/safety_shot.dart`. Then:
1. Add constants to `PlannerPainter`:

```dart
  static const _opponentAlpha = 0.45;
  static const _railAimRing = 1.4; // bán kính bi
  static const _railAimWidth = 3.0;
```

2. In `paint`, after `if (step != null) _shot(…);`, add:

```dart
    if (step?.safety case final shot?) _safety(canvas, layout, shot);
```

3. Move the jitter bar code out of `_shot` into a method and call it from `_shot` with `_jitterBar(canvas, layout, trace.cueEnd, step.jitterEnds);`:

```dart
  /// Thanh sai số lực: nối điểm dừng ±15 % qua điểm dừng chuẩn.
  void _jitterBar(Canvas canvas, TableLayout layout, Vec2 from, JitterEnds? ends) {
    if (ends == null) return;
    final s = layout.scale;
    final bar = Paint()
      ..color = AppColors.railHit.withValues(alpha: 0.8)
      ..strokeWidth = _jitterWidth * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final end in [ends.minus, ends.plus]) {
      if (end == null) continue;
      canvas.drawLine(layout.toCanvas(from), layout.toCanvas(end), bar);
      canvas.drawCircle(layout.toCanvas(end), _jitterEnd * s, Paint()..color = AppColors.railHit);
    }
  }
```

4. Add:

```dart
  /// Cú thủ (spec cú phòng thủ 5.1), từ dưới lên. Mọi đường là chuỗi điểm
  /// của mô phỏng.
  void _safety(Canvas canvas, TableLayout layout, SafetyShot shot) {
    final s = layout.scale;
    final r = layout.table.radius * s;
    final trace = shot.trace;
    List<Offset> px(List<Vec2> pts) => [for (final p in pts) layout.toCanvas(p)];

    // Cú dễ nhất của đối thủ, mờ đỏ — dưới đường của mình.
    final opp = Paint()
      ..color = AppColors.danger.withValues(alpha: _opponentAlpha)
      ..strokeWidth = 1.5;
    final view = shot.opponent;
    final easiest = view.easiest;
    if (easiest != null) {
      canvas.drawLine(layout.toCanvas(easiest.cue), layout.toCanvas(easiest.ghost), opp);
      canvas.drawLine(layout.toCanvas(easiest.object),
          layout.toCanvas(layout.table.pocketPosition(easiest.pocket)), opp);
    } else if (view.snookered) {
      final ball = view.ball;
      if (ball != null) {
        drawDashedPolyline(
            canvas, [layout.toCanvas(trace.cueEnd), layout.toCanvas(ball.pos)], opp, s);
        _label(canvas, layout.toCanvas(trace.cueEnd) + Offset(0, -2.4 * r),
            Vi.safetyOpponentSnookered, r, AppColors.danger);
      }
    }

    // Bi cái đúng từ mô phỏng.
    drawDashedPolyline(canvas, px(trace.cueBefore),
        Paint()..color = AppColors.aimLine..strokeWidth = 1.5, s);
    drawDashedPolyline(canvas, px(trace.cueAfter),
        Paint()..color = AppColors.cuePath..strokeWidth = 2, s);
    for (final hit in trace.rails) {
      if (hit.ball != ShotBall.cue) continue;
      canvas.drawCircle(layout.toCanvas(hit.pos), _railDot * s, Paint()..color = AppColors.railHit);
    }
    if (trace.cuePocket == null) {
      drawDashedCircle(canvas, layout.toCanvas(trace.cueEnd), r,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = AppColors.ballCue);
    }

    // A băng: vòng vàng đậm ở điểm ngắm trên băng đầu, số chấm ở mép bàn.
    final aim = shot.railAim;
    if (aim != null) {
      canvas.drawCircle(
          layout.toCanvas(aim.at),
          _railAimRing * r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _railAimWidth
            ..color = AppColors.railHit);
      _diamondNumbers(canvas, layout);
    }

    // Bi hợp lệ sau va chạm và chỗ nó dừng.
    final grey = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.5;
    drawPolyline(canvas, px(trace.objectPath), grey);
    drawDashedCircle(canvas, layout.toCanvas(trace.objectPath.last), r,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = AppColors.textSecondary);

    _jitterBar(canvas, layout, trace.cueEnd, shot.jitterEnds);
  }

  /// Số chấm trên khung bàn: băng dài 0–8 từ góc trái, băng ngắn 0–4 từ góc trên.
  void _diamondNumbers(Canvas canvas, TableLayout layout) {
    final t = layout.table;
    const f = TableLayout.frame;
    final size = math.max(8.0, f * 0.55 * layout.scale);
    void put(int n, Vec2 at) => _label(canvas, layout.toCanvas(at), '$n', size / 0.8, AppColors.textPrimary);
    for (var i = 0; i <= longRailDiamonds; i++) {
      final x = t.length * i / longRailDiamonds;
      put(i, Vec2(x, -f / 2));
      put(i, Vec2(x, t.width + f / 2));
    }
    for (var j = 0; j <= shortRailDiamonds; j++) {
      final y = t.width * j / shortRailDiamonds;
      put(j, Vec2(-f / 2, y));
      put(j, Vec2(t.length + f / 2, y));
    }
  }

  /// Chữ căn giữa tại [center], cỡ theo bán kính [radius] px như số trên bi.
  void _label(Canvas canvas, Offset center, String text, double radius, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
```

- [ ] **Step 4: Steps view**

In `planner_steps_view.dart`:
1. In `_scene()`, replace the `shown` line with:

```dart
    final shown = {
      for (final s in _steps.skip(_view).take(3)) ?s.ballNum,
      // 8 bi: bước phòng thủ không gắn số bi, bi được chạm nằm trong cú thủ.
      ?step.safety?.ballNum,
    };
```

2. In `build`, replace the legend loop and the computing line with:

```dart
          for (final line in [
            ...Vi.planLegend,
            if (step?.safety != null) ...Vi.planSafetyLegend,
          ])
            Text(line, style: text.bodySmall),
          const SizedBox(height: 12),
          if (!_done)
            Text(
                (_job?.searchingSafety ?? false)
                    ? Vi.planSearchingSafety
                    : Vi.planComputing(_steps.length + 1, _total),
                style: text.bodyMedium),
```

3. Pass `searchingSafety: _job?.searchingSafety ?? false` to `Vi.planSummary(...)` in the table's `Semantics` label.

- [ ] **Step 5: Run the tests and the analyzer**

Run: `"$FLUTTER" test test/features/training && "$FLUTTER" test test/architecture_test.dart && "$FLUTTER" analyze`
Expected: all pass, `No issues found!`. The safety group runs two real searches in `setUpAll`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/training/presentation/planner test/features/training/planner_steps_view_test.dart
git commit -m "Draw the safety shot with the rail aim, diamonds and the opponent's easiest shot, and show the search

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 28: Amend `PRD_RunOutPlanner.md` (spec §8)

**Files:**
- Modify: `PRD_RunOutPlanner.md`

**Interfaces:**
- Consumes: the decisions of Tasks 19–27 and the deviations above.
- Produces: PRD text that matches the code; every change carries *(sửa 2026-10-07: cú phòng thủ)*.

- [ ] **Step 1: §4 — `PlanStep`**

In the `PlanStep` block, after the line with `tolerance:`, add:

```
  safety: SafetyShot | null;        // chỉ ở bước kind = 'safety': cú thủ đã tìm; null khi không còn cú thủ hợp lệ (sửa 2026-10-07: cú phòng thủ)
```

and after the block:

```markdown
`SafetyShot` *(sửa 2026-10-07: cú phòng thủ)*: `reason` (`snookered` bị đui · `noPot` không đui, hết đường ăn), `kind` (`direct` · `kick`), `rails` (số băng A băng, 0 khi trực tiếp), `ballNum` (bi hợp lệ được chạm), `thickness` + `side` (trọn bi, ¾, ½, ¼, ⅛; lệch trái/phải), `stroke`, `spin`, `power`, `aimed` (cú đã dò), `railAim` (băng đầu + số chấm, A băng), `opponent` (đối thủ bị đui? · cú dễ nhất: bi, lỗ, góc · hoặc hết đường ăn), `jitterEnds`, `tolerance` (số mức trong 7 mức lực vẫn khó cho đối thủ), `sawsBhePercent` (khi áp phê).
```

- [ ] **Step 2: §5.1, §5.3, §5.4 — the safety step searches**

1. §5.1, at the end of the sentence "Nếu không lỗ nào hợp lệ → bước này là **safety** (…)", add: " Bước safety giờ **tìm cú thủ** (§5.6) rồi kế hoạch mới dừng, vì tới lượt đối thủ *(sửa 2026-10-07: cú phòng thủ)*."
2. §5.3 fallback item 4: replace with "4. Cả cú đó cũng không được thì là bước **phòng thủ**: tìm cú thủ (§5.6); kế hoạch dừng sau bước này *(sửa 2026-10-07: cú phòng thủ)*."
3. §5.4 loop: replace `nếu không tìm được -> đẩy bước safety, DỪNG (không đoán tiếp)` with `nếu không tìm được -> tìm cú thủ (§5.6), đẩy bước safety kèm cú thủ (hoặc null), DỪNG (sửa 2026-10-07: cú phòng thủ)`.

- [ ] **Step 3: §5.6 — new section after §5.5**

```markdown
### 5.6 Cú phòng thủ *(sửa 2026-10-07: cú phòng thủ)*

Chạy ở bước phòng thủ (tầng 4 của §5.3, hoặc khi không có cặp bi–lỗ nào). Kế hoạch vẫn dừng sau bước này vì tới lượt đối thủ.

- **Phân loại.** Bị đui khi từ bi cái cả ba đường — tới bi ảo trọn bi, và hai đường mỏng sát hai mép bi hợp lệ — đều bị bi khác chắn. 8-bi: bi hợp lệ là mọi bi nhóm mình (hết thì bi 8), đui khi mọi bi hợp lệ đều bị chắn.
- **Không đui → cú thủ trực tiếp:** độ dày trọn bi, ¾, ½, ¼, ⅛ (trừ trọn bi, mỗi mức lệch hai bên) × đứng / cu lê / trô × áp phê (không, trái ½, trái 1, phải ½, phải 1 đầu cơ) × 5 mức lực = 675 phương án mỗi bi hợp lệ; bỏ trước độ dày mà đường bi cái tới bi ảo bị chắn.
- **Bị đui → A băng:** mọi chuỗi băng không lặp băng liền nhau (1 băng 4, 2 băng 12, 3 băng 36, 4 băng 108); hướng ban đầu soi gương bi hợp lệ qua chuỗi, bỏ chuỗi bị chắn hoặc chạm băng ở miệng lỗ; mỗi chuỗi: đứng / cu lê × 5 mức lực × chạm trọn bi hoặc ½ bi hai bên. Thử 1–3 băng; chỉ khi không còn phương án hợp lệ nào mới thử 4 băng.
- **Dò hướng cơ bằng mô phỏng thật** cho bi cái chạm bi hợp lệ đúng độ dày, sau đúng chuỗi băng; không hội tụ thì bỏ phương án.
- **Luật WPA:** loại phương án nếu bi cái chạm bi khác trước, sai số băng trước va chạm (A băng), sau va chạm không bi nào chạm băng, chết cái, bi hợp lệ rơi lỗ, đường bi hợp lệ hoặc bi cái sau va chạm đi qua bi chắn, hoặc lõi quá giờ.
- **Chấm điểm** (thấp là tốt), mỗi mức lực (chọn, −15%, +15%, kẹp ≤ 100%): phần đối thủ (đui → 0; không đui → 95 − góc cắt dễ nhất của đối thủ; không lỗ nào → 0) − 5 cho mỗi bi sát băng (cách băng ≤ một bi: bi cái, bi đối thủ phải đánh dễ nhất) − khoảng cách bi cái → bi đó (cm) × 0,01; mức phạm luật tính 95. Lấy mức xấu nhất, cộng phạt kỹ thuật (như §5.3, áp phê cộng dồn) + phạt A băng (1 băng 10, 2 băng 20, 3 băng 45, 4 băng 55) + lực × 0,04. Bằng điểm giữ phương án thử trước.
- **Đối thủ đánh bi nào:** 9/10-bi là bi số nhỏ nhất còn trên bàn ở vị trí mới sau cú thủ; 8-bi là bi nhóm kia, hết thì bi 8.
- **Độ chịu sai số lực** (chỉ hiển thị): số mức trong 7 mức lực đều nhau ±15% mà đối thủ bị đui, hết đường ăn, hay góc dễ nhất > 55°.
```

- [ ] **Step 4: §6.7 — new section after §6.6**

```markdown
### 6.7 Bước phòng thủ *(sửa 2026-10-07: cú phòng thủ)*

- **Trên bàn**, từ dưới lên: bi khác vẽ mờ; cú dễ nhất của đối thủ mờ màu đỏ (bi cái → bi ảo → lỗ), hoặc đường bị chắn kèm chữ *"Đối thủ bị đui"*; đường bi cái đúng từ mô phỏng (trước va chạm nét đứt trắng qua các băng, chấm vàng ở mỗi lần chạm băng; sau va chạm nét đứt ngọc; vòng trắng chỗ dừng); A băng: vòng vàng đậm ở điểm ngắm trên băng đầu và số chấm ở mép bàn (băng dài 0–8, băng ngắn 0–4); đường bi hợp lệ sau va chạm và chỗ nó dừng; thanh sai số lực.
- **Bảng thông tin:** *"Bi cái bị đui bi N — đánh A băng để thủ."* hoặc *"Không còn đường ăn bi — nên thủ bi."*; A băng *"A băng K băng: ngắm chấm X băng Y."*; trực tiếp *"Ăn ½ bi, lệch bên trái."* (hoặc *"Ăn trọn bi."*); kiểu đánh, lực; áp phê như màn mô phỏng; kết quả cho đối thủ (*"Đối thủ bị đui."* · *"Cú dễ nhất của đối thủ: bi N vào lỗ X, góc cắt Y°."* · *"Đối thủ không còn đường ăn."*); *"k/7 mức lực vẫn để đối thủ khó."*; cảnh báo lực ≥ 85% hoặc trô.
- Đang tìm thì hiện *"Đang tìm cú thủ…"*. Không tìm được cú thủ hợp lệ thì giữ câu *"… nên chơi an toàn (safety) thay vì cố đánh."*. Bước phòng thủ là bước cuối: nút *Xong bàn*.
- Không câu nào khuyên ngắm theo độ; số độ chỉ ở kết quả cho đối thủ.
```

- [ ] **Step 5: §8 — out of scope**

Append to §8:

```markdown
- Cú phòng thủ nay **có** trong Planner (§5.6), nhưng kế hoạch vẫn **dừng sau cú thủ** vì tới lượt đối thủ; không lập kế hoạch cho lượt sau, không có cú nhảy bi (massé, jump), và không theo luật "bi chạm băng" riêng của từng giải ngoài WPA *(sửa 2026-10-07: cú phòng thủ)*.
```

- [ ] **Step 6: Check every marker is in place**

Run: `grep -c "sửa 2026-10-07: cú phòng thủ" PRD_RunOutPlanner.md`
Expected: at least 8.

- [ ] **Step 7: Commit**

```bash
git add PRD_RunOutPlanner.md
git commit -m "Write the safety-shot amendments into the run-out planner PRD

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 29: Real Chrome with three safety tables, the owner's eye check, then tuning

**Files:**
- Modify: `tool/e2e/planner.mjs`
- Modify: `docs/superpowers/logs/2026-10-07-run-out-planner.md`
- Modify only if the owner asks: values in `lib/domain/planner/planner_constants.dart` (safety constants)

**Interfaces:**
- Consumes: the labels `Vi.planSummary` (safety form), `Vi.planSearchingSafety`, the fixture coordinates of Task 19.
- Produces: `node tool/e2e/planner.mjs [appUrl]` additionally:
  - lays out `5-9bi-dui-a-bang` (= `snookerOneRailTable`), `6-9bi-het-duong` (= `noPotTable`) and `7-8bi-thu` (= `eightSafetyTable`);
  - prints each safety table's time from *Lập kế hoạch* to the safety step and the card lines; screenshots go to `%TMP%/pcai-planner` as before;
  - records frames while searching on table 6 (with the same input agitation as table 2).
  It also fails when:
  - a safety table's step takes more than `SAFETY_MAX_MS` (5000 ms, deviation 20, or what the owner set at Task 25);
  - table 5's label lacks *"Bi cái bị đui bi 1 — đánh A băng để thủ."* or *"A băng"*; table 6's lacks *"Không còn đường ăn bi — nên thủ bi."* or an *"Ăn … bi"* line; table 7's opponent sentence names ball 1;
  - the frame median exceeds 17 ms or the p95 exceeds 20 ms while searching.

- [ ] **Step 1: Extend `planner.mjs`**

1. After `const FRAME_P95_MAX = 20;` add:

```js
// Spec cú phòng thủ mục 6: bước thủ ra trong "vài giây" — đọc là ≤ 5 s
// (độ lệch 20 của kế hoạch); chủ sản phẩm có thể đổi ở bước dừng Task 25.
const SAFETY_MAX_MS = 5000;

// Bi chắn ở miệng lỗ — đúng jawBlocker của test/support/planner_tables.dart.
const jaw = (ball, [px, py], d = 14) => {
  const dx = ball[0] - px, dy = ball[1] - py, l = Math.hypot(dx, dy);
  return [px + (dx / l) * d, py + (dy / l) * d];
};
const NO_POT_BALL = [150, 40];
```

2. Append three tables to `TABLES`:

```js
  // Cú phòng thủ — đúng toạ độ của snookerOneRailTable, noPotTable, eightSafetyTable.
  { name: '5-9bi-dui-a-bang', game: '9 bi', cue: [30, 80], balls: [[180, 80], [105, 80]], safety: true },
  {
    name: '6-9bi-het-duong', game: '9 bi', cue: [60, 100], safety: true, gateSafety: true,
    balls: [NO_POT_BALL, jaw(NO_POT_BALL, [254, 0]), jaw(NO_POT_BALL, [254, 127])],
  },
  {
    name: '7-8bi-thu', game: '8 bi', group: 'Trơn', cue: [60, 100], safety: true,
    balls: [
      ['Bi của tôi', NO_POT_BALL], ['Bi đối thủ', jaw(NO_POT_BALL, [254, 0])],
      ['Bi đối thủ', jaw(NO_POT_BALL, [254, 127])], ['Bi 8', [40, 20]],
    ],
  },
```

3. Replace `waitPlanDone`:

```js
async function waitPlanDone() {
  for (let i = 0; i < 1200; i++) {
    const text = await tab.text();
    if (!text.includes('Đang tính bước') && !text.includes('Đang tìm cú thủ')) return;
    await sleep(250);
  }
}
```

4. Add `let safetyFrames = null;` next to `let frameStats = null;`.
5. In the table loop, replace the `if (t.gate) await startFrames();` … `const first = await waitLabel(…, 15000);` lines with:

```js
    let stopInput = null;
    if (t.gate || t.gateSafety) await startFrames();
    const t0 = Date.now();
    await clickNow('Lập kế hoạch');
    // Bơm input sau khi bấm: kéo trên màn nhập bàn thì dời bi mất.
    if (t.gate || t.gateSafety) stopInput = agitate(r);
    const first = await waitLabel('Bàn kế hoạch. Bước 1 /', t.safety ? 300000 : 15000);
```

and after the existing `if (t.gate) { … }` block add:

```js
    if (t.gateSafety) {
      safetyFrames = stats(await stopFrames());
      const input = await stopInput();
      console.log(`  khung hình lúc tìm cú thủ: ${JSON.stringify(safetyFrames)}; input ${JSON.stringify(input)}`);
    }
```

6. Replace the table-4 check and add the safety checks, after `results.push(…)`:

```js
    if (t.name.startsWith('4-') && !/nên chơi an toàn \(safety\)|nên thủ bi|để thủ\./.test(labels[0] ?? '')) {
      throw new Error(`bàn phòng thủ: ${labels[0]}`);
    }
    if (t.name.startsWith('5-')) {
      if (!labels[0]?.includes('Bi cái bị đui bi 1 — đánh A băng để thủ.') || !/A băng \d băng: ngắm chấm/.test(labels[0])) {
        throw new Error(`bàn đui: ${labels[0]}`);
      }
    }
    if (t.name.startsWith('6-')) {
      if (!labels[0]?.includes('Không còn đường ăn bi — nên thủ bi.') || !/Ăn (trọn|¾|½|¼|⅛) bi/.test(labels[0])) {
        throw new Error(`bàn hết đường ăn: ${labels[0]}`);
      }
    }
    if (t.name.startsWith('7-')) {
      if (!labels[0]?.includes('nên thủ bi')) throw new Error(`bàn 8 bi thủ: ${labels[0]}`);
      if (/đối thủ: bi 1 /.test(labels[0])) throw new Error('8 bi: đối thủ được tính đánh bi của tôi');
    }
```

7. After the 4× CPU block, before the console-error check, add:

```js
  const slowSafety = results.filter((x) => /^(5|6|7)-/.test(x.table) && x.firstMs > SAFETY_MAX_MS);
  console.log(`Khung hình lúc tìm cú thủ (bàn 6): ${JSON.stringify(safetyFrames)}`);
```

and after the existing frame-gate check:

```js
  if (slowSafety.length) {
    throw new Error(`Bước thủ chậm: ${slowSafety.map((x) => `${x.table} ${x.firstMs} ms`).join(', ')}`);
  }
  if (safetyFrames && (safetyFrames.median > FRAME_MEDIAN_MAX || safetyFrames.p95 > FRAME_P95_MAX)) {
    throw new Error(`Rớt khung lúc tìm cú thủ: trung vị ${safetyFrames.median.toFixed(1)} ms, p95 ${safetyFrames.p95.toFixed(1)} ms`);
  }
```

Check the syntax: `node --check tool/e2e/planner.mjs`. Expected: no output.

- [ ] **Step 2: Build, serve locally, and run it**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/planner.mjs http://localhost:5555
node tool/e2e/simulator.mjs http://localhost:5555
```

Load the secrets from the main checkout's `.claude/settings.local.json` `env` block with a `node -e` one-liner (memory: poolcoachai-deploy). Expected:
- tables 1–4 behave as in the run-out plan's Task 14 (table 4 now shows either the old sentence or a safety shot);
- tables 5–7 each print one `Bàn kế hoạch. Bước 1 / 1: …` label with the safety sentences and their card lines;
- no console errors; `simulator.mjs` passes.
- The safety timing and the frames-while-searching gates are expected to fail unless the owner changed the search at Task 25. If they fail, report the printed lines; do not optimise.

- [ ] **Step 3: The owner's eye check — STOP here.**

The controller shows the owner the screenshots of tables 4–7, the printed labels, the safety times and the frame lines. Spec §9.3 says to stop here for the owner to judge whether each safety looks like how a good player would play it, before tuning any penalty. Ask specifically:
- Tables 5–7: is the chosen safety what the owner would play? Is the *A băng* rail and *chấm* where a good player aims?
- Are the kick penalties (10 / 20 / 45 / 55), `nearRailBonus` and the ±15 % worst case giving the right balance between "simple" and "hard for the opponent"?
- Deviation 5: should a cue ball that runs into a third ball after contact reject the safety?
- Deviation 9: counting *chấm* on the short rails from the top corner, and the *chấm* as the projection of the cue-ball contact.
- Deviation 13: should a not-snookered table also try kicks (cost: about 2× the search)?
- The opponent's degree number on screen (spec decision 9) and the legend wording.

Do not change any constant or string without the owner's answer.

- [ ] **Step 4: Apply the owner's tuning, if any**
1. Change only named values in `planner_constants.dart`.
2. Rerun `"$FLUTTER" test`, `"$FLUTTER" test --tags perf --run-skipped test/domain/planner/safety_perf_test.dart`, and the probe's first test.
   - A red test in `safety_spec_test.dart` means a fixture stopped meeting its condition: re-find it with Task 23's procedure, then update the fixture, its comment and `planner.mjs`.
   - A red test that is not about a fixture means the new weight contradicts a spec rule: report it rather than relaxing the test.
3. Rebuild, rerun Step 2, show the new screenshots, repeat until the owner approves.

- [ ] **Step 5: Log the eye check**

Append to the build log:

```markdown
## Cú phòng thủ — Chrome

- Safety step times (planner.mjs): <paste the "Thời gian ra bước 1" line for tables 5–7>.
- Frames while searching (table 6): <paste the line>.

## Cú phòng thủ — owner's eye check

<the owner's verdict on tables 4–7, verbatim>

## Cú phòng thủ — tuning and open questions

- Constants: <each changed constant: old → new, or "none">.
- Deviation 5 (cue ball into a third ball): <answer>.
- Deviation 9 (short-rail diamonds): <answer>.
- Deviation 13 (kicks when not snookered): <answer>.
```

Fill every `<…>` with what Step 2 printed and what the owner said, verbatim.

- [ ] **Step 6: Commit**

```bash
git add tool/e2e/planner.mjs docs/superpowers/logs/2026-10-07-run-out-planner.md lib/domain/planner/planner_constants.dart
git commit -m "Check the safety step in real Chrome with three safety tables, and log the owner's eye check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If tuning changed constants, list each change with old → new in the commit body.

---

### Task 30: Full verification and the whole-branch review (replaces Task 15 of the run-out plan)

This is the run-out plan's Task 15, moved here so it covers the safety work too. Do not run the old Task 15 separately.

**Files:** none new.

- [ ] **Step 1: Run everything**

```bash
"$FLUTTER" test
"$FLUTTER" test --tags perf --run-skipped
"$FLUTTER" analyze
git status --short
```

Expected:
- All tests pass. Write the count down.
- The perf files pass (`aim_perf_test`, `planner_perf_test`, `safety_perf_test`), or `safety_perf_test` fails exactly as the owner accepted at Task 25 (quote the decision from the log).
- The analyzer prints `No issues found!`.
- `git status` is clean.

- [ ] **Step 2: Whole-branch review**

Use superpowers:requesting-code-review on `main...feat/run-out-planner`, with both specs, both plans and the build log as context. Ask the reviewer to check at least these:
- the plan invariant (`identical(steps[i].trace!.cueEnd, steps[i + 1].cbFrom)`) and determinism;
- that slicing cannot change results, in `PlannerJob` and in `SafetyJob` (one new memo entry per unit, the cursor, exact pruning);
- the safety rules and score against spec §3.5 and §4, with the owner's numbers;
- the 4-rail fallback only after 1–3 rails found nothing;
- every Review Focus item of both plans;
- no degree aim instruction on any screen (the opponent's cut angle is the only degree number added);
- every visible string in `Vi`, and the owner's terms used exactly (*bị đui*, *A băng*, *chấm*, rail names, *"Ăn ½ bi, lệch bên trái"*);
- `Vi.simCannotSimulate` gone, and the wait flow never computing before the *Đang tính…* frame.

Fix findings with superpowers:receiving-code-review, then rerun Step 1.

- [ ] **Step 3: Hand off to the owner**

Use superpowers:finishing-a-development-branch. Merging and deploying are **the owner's decision**, made separately. Do not push or merge without it. There is no `gh`: if the owner wants a pull request, push the branch and give them the `pull/new/feat/run-out-planner` URL.

### After the owner approves the merge

The same sequence as the physics feature (memory: poolcoachai-deploy). Do not deploy from the branch.

1. From a clean `main`, run `FLUTTER=… DART=… bash deploy/publish.sh`.
2. Call the easypanel MCP `deployAppService` {projectName: test-va, serviceName: poolcoachai} through `execute_destructive`.
3. Confirm that `inspectAppService` → `commit.hash` equals the new `deploy-easypanel` head.
4. Run `node tool/e2e/planner.mjs` against the live URL. It must print every table's labels, pass the gates the owner kept, and show no console errors.
5. Rerun `node tool/e2e/simulator.mjs` and `node tool/e2e/accounts.mjs` against the live URL. Both must pass.

---

## Self-review (applied)

1. **Spec coverage.**

   | Spec section | Task |
   |---|---|
   | §1 goal: *bị đui* → A băng; no pot → direct safety; simulator wait | 19–24; 18 |
   | §2 decisions 1 (WPA) · 2 (opponent first, ±15 %) · 3 (1–4 rails, 4 as fallback) · 4 (675 with áp phê) · 5 (*chấm*) · 6 (additive score) · 7 (10/20/45/55) · 8 (−5 near rail) · 9 (opponent degrees) · 10 (wait ×3, no memory) · 11 (sliced core) | 21 · 21 · 22, 23 · 22 · 19, 23, 26 · 21 · 19, 21 · 19, 21 · 26 · 17, 18 · 22, 24 |
   | §2 terms | 26 (string tests), Global Constraints |
   | §3.1 when it runs | 24 |
   | §3.2 classification | 19 |
   | §3.3 direct options, pruning, refinement | 19, 20, 22 |
   | §3.4 kicks: sequences, mirror, refinement, tiers | 19, 20, 22, 23 |
   | §3.5 rules | 21, 23 |
   | §3.6 `SafetyJob` | 22, 24 |
   | §3.7 safety step fields, `null` keeps the old sentence | 19, 21, 24, 26 |
   | §4.1–4.2 scoring | 21 |
   | §4.3 tolerance | 21, 26 |
   | §4.4 which ball the opponent shoots | 21, 23 |
   | §4.5 constants | 19 |
   | §5.1 drawing | 27 |
   | §5.2 panel lines, no degree advice | 26 |
   | §5.3 *Đang tìm cú thủ…* | 26, 27 |
   | §6 speed, frame budget, perf test | 16, 25, 29 |
   | §7 simulator wait | 17, 18 |
   | §8 PRD | 28 |
   | §9.1 tests 1–10 | 1: 19 · 2: 21 · 3: 23 · 4: 22, 23 · 5: 19, 23 · 6: 21 · 7: 21 · 8: 21, 23 · 9: 22, 24 · 10: 22, 24 |
   | §9.2 screens | 18, 26, 27 |
   | §9.3 Chrome and owner | 29 |
   | Owner decision: 4 ms slice | 16 |
   | Run-out Task 15 moved to the end | 30 |

   Gaps the spec leaves open are the Deviations, each with its owner question in Task 25 or Task 29.
2. **Placeholder scan.** The only `<…>` markers are in the build-log templates (Tasks 16, 25, 29), which must hold measured output and the owner's words. No "TBD", no "similar to Task N"; every code step carries its code. Fixture coordinates are either verified at plan time (geometry, prototype convergence) or found by a named probe with fixed acceptance assertions (Task 23), never guessed.
3. **Type consistency.** These names were checked across tasks:
   - `KickProbe({cueAtContact, railsBefore, cuePocket})`, `probeKick(input, {maxRails, maxTime})`, `solveStun(input, {topspin})`, `topspinOf(BallState)`, `strokeVerticalOffset(Stroke, double)`, `extendedSimTime`.
   - `SafetyContext({game, cue, balls, table})` with `legal`, `visible`, `snookered`, `reason`, `obstaclesOf`, `after`.
   - `SafetyOption` fields `kind, ballNum, ball, rails, thickness, side, lateral, stroke, spin, power, initialAim, contact`; builders `directOption(c, target, thickness, side, stroke, spin, power)` and `kickOption(c, target, rails, thickness, side, stroke, power)`.
   - `SafetyPhysics({probe, simulate})`, `SimKey (cue, object, aim, power, b, spin)`, `AimResult (key, stunReached)`, `aimSafety(o, {cue, physics, table})`, `simulateSafety(key, {physics, table})`, `withSimPower`, `inputOf`, `keyOf`.
   - `SafetyFoul` values; `safetyFoulOf(t, {rails, obstacles, table})`; `SafetyLevel`, `levelOf(c, o, t)`; `evaluateOption(c, index, o, lookup, {bound})`; `beats`; `safetyToleranceOf(c, o, key, trace)`; `buildSafetyShot(c, e, trace)`.
   - `SafetyJob(context, {physics, prune, maxOptions})` with `work`, `step({budget, maxSimulations})`, `cancel`, `isDone`, `isCancelled`, `result`, `simulations`, `triedRailCounts`, `options`; `searchToEnd(c, {physics})`.
   - `PlanStep.safety({cbFrom, ballNum, safety})`; `PlannerJob(setup, {aim, safety})`, `searchingSafety`; `planToEnd(setup, {aim, safety})`; `PlannerStepsView(safety:)`.
   - `SimTimeoutState`, `simTimeoutLine`, `SimulatorPanel.waitKey/aimOnlyKey`, `Vi.simSummary(…, notice:)`; `squirtLineFor(spin, aimOffsetDeg, distance, table, stroke, power)`.
   - Fixtures `snookerOneRailTable`, `snookerTwoRailTable`, `snookerThreeRailTable`, `partlyVisibleTable`, `noPotTable`, `eightSafetyTable`, `jawBlocker`, `noSafetyPhysics`, `safetyFingerprint`.
4. **Review Focus.** Each of the five items has its named test in its owning task: 18; 24 and 27; 19 and 22; 21; 21.
