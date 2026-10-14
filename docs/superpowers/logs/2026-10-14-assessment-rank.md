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
