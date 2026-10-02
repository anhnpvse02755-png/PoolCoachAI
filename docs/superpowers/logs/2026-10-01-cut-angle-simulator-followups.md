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
