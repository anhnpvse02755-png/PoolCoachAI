# Đánh giá + hạng — build log

Plan: `docs/superpowers/plans/2026-10-14-poolcoachai-assessment-rank.md`.

## BU sources (checked 2026-10-14)

- Downloaded to a temp dir outside the repo (`%TMP%/bu_src.hEu6`), all HTTP 200: BU_Exam-I_Fundamentals.pdf, BU_Exam-II_Skills-Bachelors.pdf, BU_Exam-II_Skills-Masters.pdf, BU_Exam-II_Skills-Doctorate.pdf, BU_Exam_Instructions.pdf, BU_Rating_Comparisons.pdf, BU_Exam-I_Score_Sheet.pdf, BU_Exam-II_Score_Sheet-Bachelors.pdf, BU_Exam-II_Score_Sheet-Masters.pdf, BU_Exam-II_Score_Sheet-Doctorate.pdf.
- Raw sum: every Exam II sheet ends "Total Score = Exam I: _____ + Exam II: _____ = _________"; Bachelors "TOTAL (max = 54)", Masters "TOTAL (max = 77)", Doctorate "TOTAL (max = 100)". Exam I sheet: "TOTAL (max = 100)".
- Ladder bonus: "In drills F1-F5, circle every 7 that follows a 7, indicating shot success at 7. The number of circles is the number of bonus points. The maximum score allowed (including bonus points) is 10"; each of F1–F5 "score (10 max) = last pos. + bonus", "(start: 4)". F7 "score (20 max) = total # of hits"; F8 "score (20 max) = total # on target".
- S1/S2 second attempt: "*: The 2nd attempt is not required with a perfect score on the 1st attempt." (S1 and S2, all three sheets).
- S9: "jump or massé … score = # of successes" (all three sheets).
- S10: "score (5 max) = median (middle value) of the three break scores".
- pdftoppm: present (Poppler 25.07.0 via winget), but not on PATH; full path `%LOCALAPPDATA%/Microsoft/WinGet/Packages/oschwartz10612.Poppler_…/poppler-25.07.0/Library/bin/pdftoppm.exe`.

## Baseline

- `flutter test`: 794 tests passed, 5 skipped, all green. `flutter analyze`: no issues.

## Layouts (Task 11, 2026-10-14)

Pages rendered with pdftoppm into a temp dir outside the repo and read one by one. Ball gaps ("frozen", "half ball gap", "one ball gap") and the 8.5"×11" paper are converted to *chấm* on the 9-foot table (D5: 1 chấm = 31.75 cm, 1 ball = 0.18 chấm).

- BU_Exam-I_Fundamentals.pdf trang 1–8: F1–F8 — constructed (ladder rows, OB rules, paper targets). F6 split into two layouts (one per CB position).
- BU_Exam-II_Skills-{Bachelors,Masters,Doctorate}.pdf trang 1: S1 — constructed (one-ball gap to the end rail; gaps 3/2/1 balls).
- … trang 2: S2 — transcribed.
- … trang 3–5: S3 layouts 1–3 — transcribed.
- … trang 6–8: S4 layouts 1–3 — transcribed.
- … trang 9: S5 — constructed (one layout per CB position, 3/5/7).
- … trang 10: S6 — transcribed.
- … trang 11: S7 — Bachelors transcribed; Masters/Doctorate constructed (5/7 CB positions).
- … trang 12: S8 — constructed ("OBs are halfway between the CB and pocket"; one layout per CB position).
- … trang 13: S9 — constructed (obstacle on the CB→corner line).
- … trang 14: S10 — constructed (9-ball rack on the foot spot, CB zone chấm 2–6).

**Measured off the figure, not on a line — owner to check at the Task 17 HOLD:** F2–F4 CB/OB row at 0.25 chấm from the top rail (figure ≈ 0.33); F7 balls 4 and 8 at (7.8, 0.15)/(7.8, 3.85); S3 Bachelors layout 3 ball 5 at (5.9, 2.5); S4 Masters/Doctorate layout 3 ball 8 at x 0.4; S4 Doctorate layout 1 stripes at x 4.3; S9 hanger at (7.8, 3.85); S6 kick path rail point x 1.6.

**PDF vs plan wording:** S9 Doctorate is "scratch in the corner" (score "CB pocketed"), no object ball. The plan's line "Bản Doctorate không cho chết cái" was wrong; the app now says the Doctorate shot succeeds by pocketing the cue ball in the corner without touching the obstacle. S3 Doctorate layout 3 (3–4 rails), S4 "allowed to contact the obstacle balls" and S9 "jump or massé" confirmed.

## Directus (14/10/2026)

Run from the main session with the owner's approval. First attempt: `POST /collections → 400` ("Validation failed for field collection / field"), fixed by 1dc7277 (every field sent with its own meta). Second run:

`bootstrap.mjs` (exit 0):
```
Tạo collection player_ranks
Tạo quan hệ player_ranks.user_created → directus_users
Tạo collection bu_tests
Tạo quan hệ bu_tests.user_created → directus_users
Tạo collection bu_drill_results
Tạo quan hệ bu_drill_results.user_created → directus_users
Đặt 11 quyền cho Player policy (xoá 4 quyền cũ)
Xong.
```

`verify.mjs` (exit 0): all 10 new rank/test checks OK, `NOTE gửi lại lần kiểm tra cùng id → status 400, code RECORD_NOT_UNIQUE`, ended with `Tất cả kiểm tra đều qua`. The app treats RECORD_NOT_UNIQUE on a re-push as already synced (test `máy chủ đã có lần kiểm tra và kết quả (RECORD_NOT_UNIQUE): coi như đã đồng bộ`).
