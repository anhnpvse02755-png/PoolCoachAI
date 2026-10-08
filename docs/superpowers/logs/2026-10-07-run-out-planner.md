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

## Safety search speed (Task 25)

- Dart VM, one-shot search, three alone-runs (gate 600 ms, FAILED every run):
  - `đui A băng: 4837 ms, 689 lần dò/mô phỏng, 440 phương án, thử [1, 2, 3] băng` / `hết đường ăn: 1114 ms, 394 lần dò/mô phỏng, 505 phương án, thử [0, 1] băng`
  - `đui A băng: 4414 ms, 689 lần dò/mô phỏng, 440 phương án, thử [1, 2, 3] băng` / `hết đường ăn: 928 ms, 394 lần dò/mô phỏng, 505 phương án, thử [0, 1] băng`
  - `đui A băng: 4569 ms, 689 lần dò/mô phỏng, 440 phương án, thử [1, 2, 3] băng` / `hết đường ăn: 1005 ms, 394 lần dò/mô phỏng, 505 phương án, thử [0, 1] băng`
- Slices while searching (gate 6 ms median, passed): `lát tìm cú thủ: trung vị 3.871 ms, p95 7.935 ms, dài nhất 28.302 ms, 227 lát`; `trung vị 3.593 ms, p95 7.498 ms, dài nhất 34.961 ms, 215 lát`; `trung vị 4.059 ms, p95 7.125 ms, dài nhất 39.589 ms, 228 lát`.
- Plan-time prototype (a35667b): one ball's direct search 4.3–11.0 s with exact pruning and all 675 options; Chrome estimate ≈ 2× CPU and ≈ 4× wall at 4 ms slices.
- Search shape (owner decisions 2026-10-08): no-spin direct options first, *áp phê* only as a fallback per ball, kicks of 1–3 rails always, 4 rails last. Plan-time re-run of the amended code: 6242 ms (kick table, noisy) and 1074 ms (no-pot table).
- Status: STOPPED for the owner's decision (Task 25 step 5); search unchanged.

## Safety search speed after the owner's answer (Tasks 25a–25b)

- Owner (2026-10-08): 12 ms slice only while the safety search runs; safety powers 30 · 60 · 90; coarse pass first, pause and ask when it is *thủ tốt* (opponent *bị đui*, no pocket, or easiest cut > `opponentHardAngle`), otherwise show it as a provisional shot and keep searching.
- VM gate re-derived: first shown step ≤ 1800 ms (5 s ÷ (2 × 16.7 / 12)).
- Probe (one-shot, one run): one-rail: coarse 42 options, 83 units, 769 ms, pauses (kick 1 rail, 72.7°); full 388 units, 4792 ms, coarse shot kept. Two-rail: coarse 24 options, 53 units, 494 ms, provisional (39.1°); full 238 units, 4027 ms, kept. Three-rail: coarse 0 options; full 81 units, 1379 ms (kick 3 rails, 44.5°). No-pot: coarse 63 options, 156 units, 1319 ms, pauses (kick, 56.0°); full 428 units, 3786 ms, replaced by direct ¼ right, draw 60 %, no pot left. Eight-ball: coarse 63 options, 150 units, 1113 ms, provisional (0.7°); full 607 units, 9118 ms, replaced by ⅛ right, draw 90 % (23.9°).
- Perf, alone (first shown step ms / full search ms; one-rail, no-pot, 8-ball; slice median / p95 / longest):
  - run 1: 472/5904, 1459/4509, 1432/8716; 10.4 / 36.1 / 103 ms. Passed.
  - run 2: 956/8852, 1338/4892, 1162/8748; 11.5 / 49.5 / 158 ms. Passed.
  - run 3: 927/6585, 1223/3456, 2491/131009 (machine stalled); 13.6 / 49.2 / 213 ms. FAILED the gate on 8-ball only.
  - extra run 4: 1291/9965, 825/3245, 1736/10852; 9.2 / 31.5 / 73 ms. Passed.
  - extra run 5: 358/5356, 1787/7527, 3408/19860; 11.3 / 42.1 / 117 ms. FAILED on 8-ball only.
  - The failures coincide with other sessions loading the machine (full 8-ball search 131 s and 19.9 s against 8.7–10.9 s otherwise); the three-rail path was not in the perf test.
- Chrome estimate (× 2.8) of the first shown step, from the passing runs: one-rail ≈ 1.0–2.7 s, no-pot ≈ 2.3–4.2 s, 8-ball ≈ 3.3–4.9 s (provisional). The 8-ball case sits right at the 1800 ms VM gate on a busy machine.
- Over the gate: 8-ball (coarse pass 150 units) on a loaded machine only (2491 and 3408 ms); within it on quiet runs.
