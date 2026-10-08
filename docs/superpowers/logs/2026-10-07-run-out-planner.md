# Kế hoạch dọn bàn — build log

Plans: `docs/superpowers/plans/2026-10-07-poolcoachai-run-out-planner.md`, `docs/superpowers/plans/2026-10-07-poolcoachai-planner-safety.md`.

## Slice budget (owner decision, 2026-10-07)

- `sliceBudget`: 8 ms → **4 ms**. This supersedes the 8 ms in spec §3 of the run-out planner design.
- Evidence (`.superpowers/sdd/2026-10-07-poolcoachai-run-out-planner/task-14-measure-report.md`, Chrome, table 2, quiet windows):
  - 4 ms: frame median 16.7 ms, p95 16.8–17.0 ms; passed in 7 of 7 computing windows (3 semantics off, 4 on); 0.5–1.8 % of frames over 20 ms; step 1 at 363–458 ms; plan done in 2.7–3.6 s.
  - 8 ms: passed in 3 of 7; 5.2–7.1 % of frames over 20 ms; step 1 at 213–320 ms.
  - Under CPU contention every configuration fails; single 33 ms frames remain from indivisible `aimShot` units.
- Dart VM after the change (`planner_perf_test`), quiet-machine rerun at c672807, three alone-runs against the 6 ms gate: `lát: trung vị 7.132 ms` (fail; ran while another process was starting), `4.172 ms, p95 10.991 ms, dài nhất 60.486 ms, 226 lát` (pass), `4.559 ms, p95 10.823 ms, dài nhất 58.736 ms, 231 lát` (pass). An earlier loaded run (CPU about 79 %, Chrome and node open) read 9.3–9.5 ms.
- Next step if the owner wants zero jank on mid-range phones: a Web Worker, as a separate project after merge.
