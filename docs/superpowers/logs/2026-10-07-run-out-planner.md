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

## Cú phòng thủ — Chrome (Task 29)

- Build: `flutter build web --release` of the worktree at 8fea213 plus the `planner.mjs` change, served by `tool/e2e/serve.mjs build/web 5555`, headless Chrome at 412 × 915 mobile. The machine was not quiet: 30–76 % total CPU from other sessions (chroma-mcp, another python process) throughout; it never went quiet.
- Four runs of `planner.mjs`:
  - run 1: stopped on table 4 — table 4 now also goes through the safety search and showed a provisional shot (the brief only expected that on table 7). Fixed in the script: the provisional and checkpoint asserts apply to tables 5–7 only; table 4 prints them, and if it is ever asked it presses *Tính tiếp*.
  - run 2: all safety checks passed; failed the old frame gate on table 2 (p95 33.4 ms, gate 20).
  - run 3 (rerun): failed on table 6 — it planned `Bước 1 / 3: bi 1, lỗ giữa trên` because on the loaded machine the input agitation started while the setup screen was still showing and moved the balls (the setup screenshot shows the correct layout). Fixed in the script: agitation waits for the *Bàn kế hoạch.* label. Table 2 here: step 1 1204 ms, frames p95 66.8 ms.
  - run 4: every safety check passed; failed the old gates on table 2 (step 1 1091 ms against 1000; frames p95 66.8 ms against 20). The safety gate (≤ 5000 ms first shown step) would have passed: 792 / 1248 / 1915 ms.
- Safety step times, run 4 (`Thời gian ra bước 1`): `{"table":"4-phong-thu","firstMs":528,"doneMs":1351}`, `{"table":"5-9bi-dui-a-bang","firstMs":792,"doneMs":1412,"continueMs":409}`, `{"table":"6-9bi-het-duong","firstMs":1248,"doneMs":1875,"continueMs":2343}`, `{"table":"7-8bi-thu","firstMs":1915,"doneMs":6852}`. Run 2: 4 → 350/1153, 5 → 1222/1868 (+428), 6 → 1637/2278 (+2176), 7 → 2525/11901. Run 3: 4 → 960/2433, 5 → 2260 (+703).
- Checkpoint (run 4): `5-9bi-dui-a-bang: điểm hỏi → Dùng cú này: xong sau 409 ms` (kept *A băng 1 băng: ngắm chấm 3,5 băng dài dưới*, opponent 73°); `6-9bi-het-duong: điểm hỏi → Tính tiếp: xong sau 2343 ms` (coarse *A băng 1 băng: ngắm chấm 2,5 băng dài dưới*, opponent 56° → final *Ăn ¼ bi, lệch bên phải. Đối thủ không còn đường ăn.*). Table 7 was not asked. Matches the VM in Task 25b.
- Provisional (run 4): `7-8bi-thu: cú tạm sau 1915 ms, cú cuối sau 6852 ms` — provisional *Ăn trọn bi*, opponent bi 9 at 1°; final *Ăn ⅛ bi, lệch bên phải*, opponent bi 9 at 24°. Run 2: 2525 ms / 11901 ms, same two shots.
- Table 4 (run 4): provisional *A băng 1 băng: ngắm chấm 3 băng dài trên*, opponent bi 1 at 38°, kept as final after 1351 ms; not asked.
- Frames while searching (table 6, printed, not gated): run 4 `{"n":103,"median":16.7,"p95":17,"max":66.8}`; run 2 `{"n":117,"median":16.7,"p95":33.4,"max":83.4}`; run 3 `{"n":96,"median":16.8,"p95":83.6,"max":200}` (that run's balls were moved).
- Table 2 frames (gated, 17 / 20 ms): run 1 p95 49.9; run 2 p95 33.4; run 3 p95 66.8; run 4 p95 66.8, max 183. Step 1 on table 2: 662 / 619 / 1204 / 1091 ms. 4× CPU (reference): 6992 ms (run 2), 2714 ms (run 4).
- `simulator.mjs` (unchanged by this work) failed its own drag frame gate twice on the same machine: p95 33.3 ms, then median 33.3 / p95 50.1 ms — evidence the frame failures are machine load, not the safety search.
- *Đối thủ bị đui* was not seen in Chrome: since the 30 · 60 · 90 power change no fixture leaves the opponent snookered, and none was invented.
- Console errors: not verified. The console check sits after the old frame and step-1 gates in the script, so no run reached it.
- Screenshots for the eye check: `%TMP%/pcai-planner` (run 4); run 2 kept in `%TMP%/pcai-planner-run2`.
- Status: STOPPED for the owner's eye check (Task 29 step 3); no constant or string changed.

## Chrome rerun after layout fix

- Build: `flutter build web --release` at 6b826d8 (checkpoint question and buttons directly under the table, collapsed "Chú thích" legend below, buttons at least 48 px), served by `tool/e2e/serve.mjs build/web 5555`, headless Chrome 412 × 915 mobile. `planner.mjs` unchanged. Total CPU before the run: about 29 % average at first sample (30, 38, 20), about 18 % at the re-check just before the run.
- Run 1: reached the console-error check, no errors; then FAILED the table 2 frame gate: p95 33.3 ms (gate 20), median 16.7, max 116.8; step 1 681 ms. Tables 4–7: 4 first (provisional) 339 ms, not asked, final 1123 ms, kept the provisional shot; 5 first (checkpoint) 783 ms, asked, Dùng cú này done 429 ms, final 1420 ms; 6 first (checkpoint) 1075 ms, asked, Tính tiếp done 2185 ms, final label `Ăn ¼ bi, lệch bên phải. Đối thủ không còn đường ăn.`; 7 first (provisional) 934 ms, not asked, final 4033 ms, final label `Ăn ⅛ bi, lệch bên phải`.
- Run 2: passed everything, "Xong". Table 2 frames: median 16.7, p95 17, max 50.1 ms; step 1 544 ms. Tables 4–7: 4 first (provisional) 273 ms, not asked, final 905 ms, kept the provisional shot; 5 first (checkpoint) 660 ms, asked, Dùng cú này done 416 ms, final 1283 ms; 6 first (checkpoint) 787 ms, asked, Tính tiếp done 1592 ms, final 1406 ms, label `Ăn ¼ bi, lệch bên phải. Đối thủ không còn đường ăn.`; 7 first (provisional) 925 ms, not asked, final 3996 ms, final label `Ăn ⅛ bi, lệch bên phải`. Frames while searching (table 6): p95 16.9, max 50.2. 4× CPU reference 1772 ms.
- Console errors: none in either run (the check was reached in both).
- Screenshots (run 2): `%TEMP%\pcai-planner-layout`. In `5-9bi-dui-a-bang-diem-hoi.png` and `6-9bi-het-duong-diem-hoi.png` the question and both buttons (Tính tiếp, Dùng cú này) are fully visible without scrolling, with "Chú thích ▸" below them; the coach FAB and bottom nav do not cover them.
