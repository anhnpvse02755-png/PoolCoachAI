# Cut angle simulator — follow-ups left open at merge (2026-10-01)

Items the task reviews and the final review parked, plus the decisions the
owner made at the eye check. None blocks the merge. Items fixed before the
merge are not listed, except where noted.

## Closed

- Task 9: the portrait table box ignored the 32 px horizontal padding, so
  the bottom rail was about 17 px thicker — 947f93c, tested at two sizes

## Next steps

- Measure drag frame time on mobile Chrome after deploy. Every drag frame
  runs `bestPocket`, `simulateCueBall` and `scratchAdvice` (about 430
  simulations); it was never measured, because the eye check used static
  screenshots. If it janks, compute only the cheap path during a drag and
  run `scratchAdvice` on `onPanEnd`.
- Run `tool/e2e/simulator.mjs` against the live URL after deploy, with
  `DIRECTUS_URL` and `DIRECTUS_ADMIN_PASSWORD` set (spec section 6).
- Write a new spec for áp phê effects before or at contact without a rail
  (swerve, CIT/SIT throw, curve after contact). The owner decided this
  happens after the merge and before the Planner.
- Show the owner one screenshot of a banked trô shot to confirm the reading
  of "sửa đường cong trô dừng ở băng đầu tiên". The branch reads it as "the
  bend stops at the first rail" (after Dội băng the cue ball runs straight);
  the other reading is "the ball stops at the first rail".

## Deferred minors

### Core (lib/domain/table_geometry)

- `Vec2.isZero` has no direct test (Task 1)
- `UnmakeableReason` enum line is over 80 columns (Task 2)
- `shot_geometry_test` hard-codes `d = 5.715` instead of
  `TableSpec.nineFoot.ballDiameter` (Task 2)
- No end-to-end `bestPocket` test under a genuine full tie; only
  `compareShots == 0` is asserted (Task 3)
- Clamping `p1` can change a curve's starting tangent, an edge case where
  spec 4.4 (clamp) and the tangent conflict (Task 4)
- `_truncateAtScratch` never samples t=0 of segment 0 (the ghost itself)
  (Task 4)
- `Straight.pointAt(1)` lacks the `t == 1` guard that `Curve` has (Task 4)
- A second-rail stop with `second.end == hit` would normalize a zero
  vector; unreachable, because `hit` lies on the bounds so `contains()`
  takes the first branch (Task 4)
- The dense-sampling guard test does not discriminate on the committed
  grid; the bound is proven algebraically (Task 4)
- The test "áp phê không đổi đoạn trước khi chạm băng" compares only
  `railHit`, not the whole first segment (Task 5)
- Corner-hit branches of the test helpers `outwardAt` and `grazing` never
  run on the grid (Task 5)
- `scratchMargin` misses exactly 100 for non-integer start powers; callers
  are integer presets. Note it for the Planner spec if power ever varies
  fractionally (Task 6)
- The grid scratch-invariant test has no "at least one scratch found"
  guard (Task 6)
- With `chosen = none`, `_fewestTips` ties resolve in `SideSpin.all` order
  (left first); the spec does not say (Task 7)
- No `SpinCeiling` test where the first scratching level is directly above
  the chosen one (Task 7)

### Screen and tests

- Stale `_dragging` after a cancelled pan: there is no `onPanCancel` and
  the early return keeps the old value. Setting `_dragging = null` at the
  top of `_onPanStart` would harden it (Task 9)
- `shouldRepaint` compares `SimulatorScene` by identity (Task 9)
- `routes_test` name and the `routes.dart` comment block do not mention the
  simulator route (Task 9)
- No tests for the drag-past-rail clamp or the panel's Dội băng and scratch
  lines; the vertical-drag test cannot tell a drag from a scroll (Task 9)
- Scenarios with the same shot share one semantics label; only the
  screenshots tell spin and stroke apart (Task 10)

## Update 2026-10-02 — the simulator moved onto the table physics core

Plan: `docs/superpowers/plans/2026-10-02-poolcoachai-table-physics.md`.

### Closed

- Drag frame time on mobile Chrome is now measured by `tool/e2e/simulator.mjs`
  (gate: median ≤ 17 ms, p95 ≤ 20 ms). Measured:
  `Khung hình lúc kéo (giả lập điện thoại): {"n":140,"median":16.69999999999891,"p95":16.900000000001455,"max":17}`
  `Khung hình lúc kéo, CPU chậm 4 lần (tham khảo): {"n":33,"median":50.20000000000073,"p95":116.79999999999927,"max":116.79999999999927}`
  The first run failed p95 (33.2 ms). Fix (a), computing the uncompensated
  trace only while it is drawn (3d7b859), made it pass.
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

Constants changed: none. The owner said "tiếp tục" after seeing the
screenshots, and that was read as acceptance of plan deviations 1, 2, 3 and
9; it was not an explicit OK of each. The red uncompensated path stays drawn
under the object path.

### Still open

- Run `tool/e2e/simulator.mjs` against the live URL after deploy.
- 68 of 6,816 grid shots with 2 tips on a Dốc cue at 30 % from across the
  table do not converge; the screen draws the best attempt and says
  "Bi mục tiêu không vào lỗ". Revisit if the owner meets one in practice.
- `aimShot` measured 6–8 ms in Node (dart2js -O2); on a real phone the drag
  frame may exceed 16 ms even if emulated Chrome passes.
- áp phê aiming advice in SAWS form (BHE/FHE split by distance × speed) — next spec.
  The degree-based "Ngắm dày/mỏng hơn X°" line and the "Không cần bù ném"
  summary clause were removed on 2026-10-05 by owner ruling.
- SAWS table per cue (calibration in cue management).
