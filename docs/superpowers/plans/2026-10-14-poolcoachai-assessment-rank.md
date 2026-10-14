# Đánh giá + hạng Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every account a rank on the existing K…A / PRO scale. New players get a suggested rank from the 8-question onboarding questionnaire (*ước lượng* / *tự khai*). Any player can take the Billiard University (BU) Exam I + Exam II on a real table inside the app, with every shot written to Drift as it is entered, and get a *đã kiểm chứng* rank traced to the published BU tables. The rank, the questionnaire answers and the finished tests sync per account through Directus, and the rank shows on Hồ sơ, Trang chủ and a new `/rank` screen with the PoolCoachAI disclaimer and the BU source.

**Architecture:** A separate assessment module, never mixed into `Drill` / `DrillLog` (spec Q14).
- `lib/domain/assessment/` is plain Dart (no Flutter, enforced by the architecture test): the rank record and its six rules, the questionnaire and its answer→rank table, the five BU scoring kinds, the F1–F8 / S1–S10 definitions for the three Exam II versions, placement and the BU→rank table, the test life cycle and the 14-day gap, the sync merge rule, and the BU table layouts in *chấm* coordinates.
- `lib/data/` adds three Drift tables (schema 2 → 3, add-only), `AssessmentRepository` (every write goes to Drift first) and `AssessmentSyncService`, a second sync service beside the existing `SyncService` so the drill-log sync and its tests stay untouched.
- `lib/features/rank/presentation/` holds the onboarding questionnaire, the test runner, the result view, the rank card, the rank detail screen, the ⓘ sheet and the layout painter. The painter reuses the planner's table drawing (`drawTableBed`, `drawPoolBall`, and the diamond numbers, which this plan moves into `table_drawing.dart`).
- The router gains an `OnboardingGate` (a `ChangeNotifier` like `AuthGate`). `authRedirect` sends a signed-in player to `/onboarding/rank` only when the account is known to have no rank row: from Drift, or after the server answered.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3, Drift 2.27 (`drift_dev` + `build_runner`), go_router 18, `http` + Directus REST, `uuid`; `flutter_test`; Node 26 + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** docs/superpowers/specs/2026-10-14-poolcoachai-assessment-rank-design.md

## Global Constraints

- **Toolchain.** Flutter is not on PATH. In Git Bash, every command below uses `FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat` and `DART=/c/Users/anhnpv/flutter/bin/dart.bat` (memory: poolcoachai-toolchain-state). On another machine, discover the path the same way (`ls /c/Users/*/flutter/bin/flutter.bat`); never use `D:\flutter`. There is no `gh`.
- **Target.** Chrome is the only runnable target. "`flutter build web` succeeded" proves nothing: the final check is headless Chrome over CDP with `tool/e2e/rank.mjs` (Task 17).
- **Branch.** Work in the worktree `.claude/worktrees/assessment-rank` on branch `feat/assessment-rank` (Task 0). Do not push, merge or deploy; that is a separate owner decision.
- **Rank scale (Q2).** K < I < H < G < F < E < D < C < B < A < PRO — the existing `Rank` enum in `lib/domain/rank.dart`, unchanged.
- **Sources (spec §4.1).** `RankSource.estimated` (*ước lượng*), `RankSource.selfDeclared` (*tự khai*), `RankSource.verified` (*đã kiểm chứng*). PRO only by self-declaration; a BU test never yields PRO (Q3, rule 5).
- **Six rank rules (spec §4.2).** Questionnaire sets estimated/selfDeclared and is locked once verified; BU higher → promote, verified; equal → keep, verified; lower → keep rank and source, set `warningRank`/`warningTestId`, cleared by a later equal-or-higher result; BU max is A; no rank + BU → verified. The app never lowers a rank (Q5).
- **Exam I placement (spec §5.4).** 0–49 Bachelors, 50–69 Masters, 70–100 Doctorate; Doctorate only on a 9-foot-or-larger table, otherwise Masters.
- **BU score = Exam I + Exam II, raw sum.** Confirmed at plan time by the official score sheets (`BU_Exam-II_Score_Sheet-*.pdf`: "Total Score = Exam I: ___ + Exam II: ___"; totals 54 / 77 / 100).
- **BU → rank (spec §5.4).** K 0–19, I 20–39, H 40–69, G 70–94, F 95–109, E 110–124, D 125–139, C 140–154, B 155–174, A 175–200.
- **Maxima.** Exam I 100 (F1–F5 10 each, F6 10, F7 20, F8 20). Exam II Bachelors 54, Masters 77, Doctorate 100 (spec §5.2 table).
- **Retest gap (Q12).** Two *completed* tests at least 14 days apart (`retestGapDays = 14`); cancelled tests do not count.
- **Directus (spec §6.2).** Creating collections on the live server is an outward action: Task 10 STOPS for the owner before `bootstrap.mjs` runs against production. Secrets live only in `.claude/settings.local.json` `env`; never print them, never commit them.
- **BU PDFs.** Never commit a BU PDF (the repo is public). Download into a fresh temp directory outside the repo (cached copies may already be at `C:\Users\anhnpv\AppData\Local\Temp\bu_pdfs\` and the score sheets at `C:\Users\anhnpv\AppData\Local\Temp\bu_sheets.DOzC\`), and read pages with the Read tool.
- **Layouts.** Stored in *chấm* on the 8 × 4 grid: x 0–8 along the long rail from the left corner, y 0–4 from the top rail down (spec §5.5). Nobody invents a coordinate. The owner eye-checks every drawn layout in Chrome before layouts are final (Task 17 HOLD).
- **No fabricated content** (memory: no-fabricated-generated-content). The suggested rank, the result line, the outcome line and the warning come from named, tested functions (`suggestRank`, `applyTestResult`, `bandForBuScore`, `retestAvailableFrom`). Every visible sentence is a template in `lib/core/strings/vi.dart`; the architecture test fails on Vietnamese literals in `lib/features` and `lib/core/widgets`.
- **Billiards terms, exactly** (spec §5.1, §5.2, §11.3; memory: poolcoachai-vietnamese-billiards-terms): Đánh đứng bi, Đánh tâm tiến, Đánh cu lê, Đánh trô bi, Ăn bi, A băng, Cân bi, Phòng thủ / bắt đui, Dựng cơ, Nhảy bi (Jump), Mát xê (Massé), Phá, chấm, bi ảo, chết cái. Never "kim cương", "bi ma", "lọt bi cái".
- **Disclaimer (spec §4.3).** Every screen that shows a rank uses `PcRankBadge` plus the source label and an ⓘ button that opens the disclaimer, the BU→rank table and the BU source line.
- **Riverpod pitfalls** (memory: poolcoachai-riverpod-drift-test-patterns): never `await container.read(p.future)` — use `container.listen(p, (_, _) {}); await pumpEventQueue();`. Widget tests use `UncontrolledProviderScope` + `ProviderContainer` (or `testContainer()`), never `ProviderScope(overrides: [...])` with an explicit `List<Override>`. Drift tests use `AppDatabase.forTesting(NativeDatabase.memory())`.
- **Layering.** `lib/domain/assessment/` never imports `package:flutter` (architecture test, Task 1).
- **Generated code.** After any change to `database.dart`, run `"$DART" run build_runner build --delete-conflicting-outputs` and commit `database.g.dart` with it.
- **Comments** follow the surrounding code: Vietnamese, explaining *why*.
- **Commit messages** are plain English sentences and end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Line endings.** The repo checks out with `core.autocrlf=true`. Do not convert line endings by hand.

## Review Focus

1. **The app is closed in the middle of a drill and opened again.**
   - Expected: every shot entered before closing is still there; the runner reopens on the same drill at the next attempt (F1–F5: the right ladder position highlighted); nothing touches the rank.
   - Owner: Task 8 (`đóng app giữa bài: mở lại vẫn còn đủ cú đã nhập, hạng không đổi`), Task 14 (`mở lại màn làm bài thì tiếp đúng cú 4/10, tô vị trí 5`), Task 17 (reload in Chrome mid-F1).
2. **A second device syncs a self-declared or estimated rank over a verified one.**
   - Expected: the verified row is never overwritten by an estimated/selfDeclared row, whichever is newer; between two verified rows the newer wins (spec §6.2; see decision D4).
   - Owner: Task 9 (`mergeRank` table, and `máy chủ có hạng đã kiểm chứng, máy này tự khai mới hơn: máy chủ thắng, không gửi PATCH`).
3. **Exam II is deferred to another session across the 14-day window.**
   - Expected: the gap counts from *completion* (the Exam II day), not from the start; a test started on another device before the last completion is blocked at completion until the allowed day.
   - Owner: Task 6 (`ngày kiểm tra lại tính từ ngày hoàn tất, theo nửa đêm`), Task 8 (`Đề II để sang buổi khác: hoàn tất được, ngày kiểm tra lại tính từ ngày làm Đề II` and `lần làm dở trên máy khác hoàn tất trong 14 ngày thì bị chặn tới ngày được phép`).
4. **A test is cancelled.**
   - Expected: it leaves the rank and the 14-day gap alone; a new test can start at once; it still appears in the history as cancelled.
   - Owner: Task 6 (`lần bị hủy không tính vào giãn cách`), Task 8 (`hủy rồi bắt đầu lại được ngay, hạng không đổi`), Task 15 (`Hủy lần kiểm tra này: xác nhận rồi về Hồ sơ`).
5. **Signing in on a new device while offline.**
   - Expected: no redirect to onboarding (the server never answered); Trang chủ shows the *Xác định hạng của bạn* card; a later successful fetch in the same session does not yank the player into onboarding.
   - Owner: Task 9 (`mất mạng thì báo RankFetch.failed`, `đã hỏng một lần thì giữ nguyên trong phiên (spec mục 8)`), Task 13 (`decideOnboarding` table incl. `máy mới mất mạng: không ép onboarding`, and the widget test `máy mới mất mạng: không ép onboarding` that reports `failed` then `foundNone` and stays on Trang chủ), Task 16 (`chưa có hạng: Trang chủ hiện thẻ Xác định hạng của bạn`). Task 9 also pins the related trap: `Để sau trên máy mới (mất mạng lúc đó) không xoá hạng của máy chủ` (D16).

---

## Deviations from spec, gaps the plan fills, and owner decisions

The spec was checked against `main` at `01ecd96`. Items marked **OWNER** need the owner's answer before the task named; the plan implements the default shown and says exactly what to change for the alternative.

- **D1. Raw sum confirmed — no stop needed.** The four official score sheets exist at `https://billiarduniversity.org/documents/BU_Exam-I_Score_Sheet.pdf` and `BU_Exam-II_Score_Sheet-{Bachelors,Masters,Doctorate}.pdf` (HTTP 200 on 2026-10-14; the `/documents/` index itself returns 403). Each Exam II sheet ends with "Total Score = Exam I: _____ + Exam II: _____ = _________" and "TOTAL (max = 54)" / "(max = 77)" / "(max = 100)". `BU_Exam_Instructions.pdf` item 8: "Total up your two exam scores at the bottom of the Exam II score sheet." No scaling exists. Task 0 re-reads them and records the quotes in the log.
- **D2. S9 is "jump or massé"** on all three score sheets ("S9 jump or massé … score = # of successes"). Task 11 re-checks the S9 exam pages.
- **D3. Gap the spec does not mention: S1/S2 second attempt.** Every Exam II score sheet says for S1 and S2: "*: The 2nd attempt is not required with a perfect score on the 1st attempt." The plan encodes it (`isDrillComplete`, Task 4).
- **D4. OWNER (before Task 9): the merge rule can lower a rank.** Spec §6.2 says "giữa hai bản verified thì bản mới hơn thắng". Device A is verified B at t1; device B, offline with an older verified D, completes a test that confirms D at t2 > t1. The literal rule makes the account D: the app lowered the rank, against Q5 and rule 4. Default in this plan: the literal spec rule (`mergeRank`, Task 9). Alternative the plan recommends: between two verified rows the higher rank wins, equal ranks take the newer row, and the losing row's test becomes the warning when lower. Task 9 Step 7 has the exact replacement code and test for the alternative.
- **D5. OWNER (before Task 17): spec §5.4 "Muốn từ C trở lên phải làm bản Doctorate" is arithmetically false.** Masters is taken with Exam I 50–69 on a 9-foot table (max 69 + 77 = 146 = C), or with Exam I 70–100 on a 7–8-foot table (max 100 + 77 = 177 = **A**). So a Masters taker can reach C, and on a small table even A. BU itself does not cap the rating (only the diploma: "the highest diploma that can be achieved is a Masters with Honors", Instructions p.2). Default: follow BU, no cap; the spec's "Hệ quả" sentence is wrong, not the table. If the owner wants a cap, it is a new rule and needs his numbers.
- **D6. Q12 read as: the gap gates both *starting* and *completing* a test.** "Bài kiểm tra luôn được làm" contrasts with gating by practice data (Q12 second sentence). Starting is blocked before `retestAvailableFrom`; completing is checked again because a test started on another device can finish inside the window (Review Focus 3). The day is the local calendar day: completed 1 Oct 21:00 → allowed from 15 Oct 00:00.
- **D7. Nullable `rank` and `source`.** Spec §6.1 lists `rank`/`source` as plain columns, but rule 6 and §7.4 need "no rank yet" (*Để sau*). Both are nullable, and null together (asserted).
- **D8. `BuDrillResultRows.score` is nullable:** null until the drill is complete (S3/S4 have no meaningful score before the third layout). The raw attempts are always stored, as the spec asks.
- **D9. Directus collection names follow the existing convention** (`DrillLogRows` ↔ `drill_logs`): `player_ranks`, `bu_tests`, `bu_drill_results`, snake_case fields. "Cùng tên" in spec §6.2 is read as "same tables", not literal class names.
- **D10. Only finished tests sync.** `bu_tests` and `bu_drill_results` are create-only on the server (spec §6.2 "chỉ thêm"), so a test is pushed once it is completed or cancelled, with its results. An in-progress test (including Exam I done, Exam II deferred) lives on the device that started it. A manual sign-out warns that it will be lost (Task 16).
- **D11. Retaking the questionnaire keeps an open warning only if the new rank is still above the warning rank.** Spec §4.2 is silent; keeping "lower than current" true is the only reading that keeps the warning meaningful.
- **D12. New route `/rank/layouts`** (*Sơ đồ bài kiểm tra*): one screen that draws every layout, reachable from `/rank`. The owner eye-check (spec §5.5) needs every layout in Chrome; players can preview drills there too.
- **D13. Drill instructions are a translation of the PDF text**, transcribed with the layouts in Task 11 and checked by the owner at the Task 17 HOLD. The scoring line per drill is the spec's own wording (§5.1, §5.2).
- **D14. Existing E2E scripts.** `tool/e2e/throwaway_user.mjs` waits for *Xin chào* after registering; a new account is now redirected to onboarding. Task 17 makes it press *Để sau*, so `accounts.mjs`, `simulator.mjs` and `planner.mjs` keep working.
- **D15. PDF page rendering.** At plan time `pdftoppm` is not installed, so the Read tool's `pages` parameter fails. Reading a whole PDF of ≤ 10 pages works (the score sheets, the instructions, `BU_Exam-I_Fundamentals.pdf` with 8 pages). The three Exam II PDFs have 14 pages and need `pages`. Task 0 checks; if `pdftoppm` is still missing, STOP and ask the owner to install Poppler before Task 11.
- **D16. Gap the spec does not cover: a row without a rank never beats a row with one** in `mergeRank`. Without it, a player on a new device whose rank fetch failed (Review Focus 5) who taps *Xác định hạng* → *Để sau* writes a newer `skipped` row that would erase the account's rank on the next sync.

## File Structure

| File | Responsibility |
|---|---|
| `lib/domain/assessment/questionnaire.dart` | `questionOptionCounts`, `QuestionnaireAnswers`, `suggestRank` (spec §11.2) |
| `lib/domain/assessment/player_rank.dart` | `RankSource`, `OnboardingState`, `PlayerRank` (spec §4.1) |
| `lib/domain/assessment/rank_rules.dart` | `RankOutcome`, `canUseQuestionnaire`, `rankFromQuestionnaire`, `rankAfterSkip`, `applyTestResult` (spec §4.2) |
| `lib/domain/assessment/bu_placement.dart` | `TableSize`, `ExamIIVersion`, `placeExamII`, `BuRankBand`, `buRankBands`, `bandForBuScore`, `rankForBuScore` (spec §5.4) |
| `lib/domain/assessment/drill_attempts.dart` | `BreakCriteria`, `DrillAttempts` (`ShotAttempts`, `CountAttempts`, `BreakAttempts`) with JSON |
| `lib/domain/assessment/bu_scoring.dart` | the five scoring kinds (spec §5.3) |
| `lib/domain/assessment/bu_exams.dart` | `BuExam`, `ScoringKind`, `BuDrill`, `examIDrills`, `examIIDrills`, `drillFor`, `isDrillComplete`, `drillScore`, `attemptsValid`, `emptyAttemptsFor` |
| `lib/domain/assessment/bu_test.dart` | `BuTest`, `TestSnapshot` (progress of one test) |
| `lib/domain/assessment/retest_gate.dart` | `retestGapDays`, `retestAvailableFrom`, `retestAllowed` |
| `lib/domain/assessment/rank_merge.dart` | `mergeRank` (spec §6.2) |
| `lib/domain/assessment/onboarding_check.dart` | `RankFetch`, `OnboardingCheck`, `decideOnboarding` (spec §8) |
| `lib/domain/assessment/bu_layouts.dart` | `Cham`, layout marks, `BuLayout`, `chamToTable`, `pocketCham`, `lerpCham`, `evenlySpaced`, `layoutsFor`, `allLayouts`, `layoutForAttempt` (spec §5.5) |
| `lib/data/database/database.dart` (+ `.g.dart`) | `PlayerRankRows`, `BuTestRows`, `BuDrillResultRows`; schema 3 |
| `lib/data/database/assessment_converters.dart` | row ↔ domain, and domain ↔ Directus JSON |
| `lib/data/repositories/assessment_repository.dart` | `AssessmentRepository`, `StartOutcome`, `CompleteOutcome` |
| `lib/data/sync/assessment_sync.dart` | `AssessmentSyncService`, `watchPendingAssessment` |
| `lib/data/sync/account_actions.dart` | sign-out also forgets assessment rows; `pendingAssessmentCount`, `hasActiveTest` |
| `lib/data/remote/directus_client.dart` | adds `patch` |
| `lib/core/providers/assessment_providers.dart` | repository, stream providers, `RankFetchNotifier`, sync service, `OnboardingGate` |
| `lib/core/bootstrap.dart` | `startSync` also starts the assessment sync |
| `lib/core/router/routes.dart`, `app_router.dart` | four routes; `authRedirect` + `OnboardingGate` |
| `lib/app.dart` | passes the onboarding gate to the router |
| `lib/core/strings/vi.dart` | every rank/assessment string |
| `lib/features/training/presentation/simulator/table_drawing.dart` | gains `drawDiamondNumbers`, `drawCenteredLabel` (moved from `PlannerPainter`) |
| `lib/features/training/presentation/planner/planner_painter.dart` | calls the moved functions |
| `lib/features/rank/presentation/bu_layout_painter.dart` | `BuLayoutPainter`, `BuLayoutView` |
| `lib/features/rank/presentation/layout_gallery_screen.dart` | `/rank/layouts` |
| `lib/features/rank/presentation/onboarding_screen.dart` | `/onboarding/rank` |
| `lib/features/rank/presentation/drill_inputs.dart` | `ShotInput`, `CountInput`, `BreakInput` |
| `lib/features/rank/presentation/test_screen.dart` | `/rank/test`: prep, runner, Exam I end, finish, result |
| `lib/features/rank/presentation/test_result_view.dart` | per-drill scores, total, band, Fargo, outcome |
| `lib/features/rank/presentation/rank_badge_line.dart` | badge + source label + ⓘ, `showRankInfoSheet` |
| `lib/features/rank/presentation/rank_card.dart` | profile rank card and test history |
| `lib/features/rank/presentation/rank_screen.dart` | `/rank` |
| `lib/features/profile/presentation/profile_screen.dart` | card replaces `PcEmptyState`; sign-out warning for assessment data |
| `lib/features/home/presentation/home_screen.dart` | small badge / *Xác định hạng của bạn* card |
| `deploy/directus/bootstrap.mjs`, `verify.mjs` | three collections, relations, permissions, checks |
| `test/support/test_data.dart` | `testContainer` overrides the new stream providers |
| `test/support/assessment_fixtures.dart` | attempt sequences and helpers that play a whole exam |
| `test/domain/assessment/*_test.dart` | domain tests |
| `test/data/...`, `test/core/...`, `test/features/rank/*_test.dart` | data, router and widget tests |
| `tool/e2e/rank.mjs`, `tool/e2e/throwaway_user.mjs` | Chrome scenario; skip onboarding for other scripts |
| `docs/superpowers/logs/2026-10-14-assessment-rank.md` | verifications, measured numbers, owner's eye check |
| `PRD_PoolCoachAI.md` | §3–§4 describe what shipped |

---

### Task 0: Worktree, baseline and BU source checks

**Files:**
- Create: `docs/superpowers/logs/2026-10-14-assessment-rank.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the worktree, a green baseline with its test count, and the log with the BU quotes every later test cites.

- [ ] **Step 1: Create the worktree** with superpowers:using-git-worktrees: path `.claude/worktrees/assessment-rank` (the repo's convention, git-ignored), branch `feat/assessment-rank`, from `main` at the commit that adds this plan.

- [ ] **Step 2: Generate code and run the baseline**

```bash
FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat
DART=/c/Users/anhnpv/flutter/bin/dart.bat
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" test
"$FLUTTER" analyze
```

Expected: every test passes (perf and probe tags are skipped by default) and the analyzer prints `No issues found!`. Write the test count down. If anything is red, stop and report: the baseline must be green before any change.

- [ ] **Step 3: Download the BU documents into a fresh temp directory outside the repo**

```bash
D=$(mktemp -d "$TMP/bu_src.XXXX"); echo "$D"
for n in BU_Exam-I_Fundamentals.pdf BU_Exam-II_Skills-Bachelors.pdf BU_Exam-II_Skills-Masters.pdf \
         BU_Exam-II_Skills-Doctorate.pdf BU_Exam_Instructions.pdf BU_Rating_Comparisons.pdf \
         BU_Exam-I_Score_Sheet.pdf BU_Exam-II_Score_Sheet-Bachelors.pdf \
         BU_Exam-II_Score_Sheet-Masters.pdf BU_Exam-II_Score_Sheet-Doctorate.pdf; do
  printf '%s ' "$(curl -s -A 'Mozilla/5.0' -o "$D/$n" -w '%{http_code}' "https://billiarduniversity.org/documents/$n")"; echo "$n"
done
git -C . status --short   # must print nothing: no PDF may land in the repo
```

Expected: `200` for all ten. If a download fails, use the cached copies listed in Global Constraints. Never copy a PDF into the worktree.

- [ ] **Step 4: Re-confirm D1 and D2 and check page rendering**
1. Read the four score sheets with the Read tool (one page each; no `pages` needed). Confirm: Exam II sheets say "Total Score = Exam I: … + Exam II: …" with totals 54 / 77 / 100; Exam I sheet says "circle every 7 that follows a 7 … score (10 max) = last pos. + bonus", F7 "score (20 max) = total # of hits", F8 "score (20 max) = total # on target"; S1/S2 "The 2nd attempt is not required with a perfect score on the 1st attempt"; S9 "jump or massé"; S10 "score (5 max) = median (middle value) of the three break scores".
2. If any of these differs, **stop and report to the owner** with the exact quote. Do not adapt the scoring on your own.
3. Run `pdftoppm -v`. If the command is missing, the Read tool cannot render pages of the 14-page Exam II PDFs: **stop and ask the owner** to install Poppler (for example `winget install oschwartz10612.Poppler`) before Task 11. Tasks 1–10 do not need it.

- [ ] **Step 5: Write the log**

Create `docs/superpowers/logs/2026-10-14-assessment-rank.md`:

```markdown
# Đánh giá + hạng — build log

Plan: `docs/superpowers/plans/2026-10-14-poolcoachai-assessment-rank.md`.

## BU sources (checked <date>)

- Downloaded to a temp dir outside the repo: <list the ten files with HTTP codes>.
- Raw sum: <quote the "Total Score = Exam I + Exam II" line of each Exam II sheet, with its TOTAL (max = …)>.
- Ladder bonus: <quote the Exam I sheet note>.
- S1/S2 second attempt: <quote>.
- S9: <quote>.
- S10: <quote>.
- pdftoppm: <present / missing → owner asked on <date>>.

## Baseline

- `flutter test`: <N> tests, all green. `flutter analyze`: no issues.
```

Fill every `<…>` with what you read, verbatim.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/logs/2026-10-14-assessment-rank.md
git commit -m "Record the BU score-sheet checks and the baseline for the assessment work

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 1: The rank record and the six rank rules (spec §4.1, §4.2)

**Files:**
- Create: `lib/domain/assessment/questionnaire.dart` (answers only; Task 5 adds `suggestRank`)
- Create: `lib/domain/assessment/player_rank.dart`
- Create: `lib/domain/assessment/rank_rules.dart`
- Modify: `test/architecture_test.dart` (append one test before the closing `}` of `main`, after the test `lõi Planner không phụ thuộc Flutter` that ends at line 223)
- Test: `test/domain/assessment/rank_rules_test.dart`

**Interfaces:**
- Consumes: `Rank` (`lib/domain/rank.dart`).
- Produces:
  - `const List<int> questionOptionCounts`;
  - `final class QuestionnaireAnswers { QuestionnaireAnswers(List<int> choices); factory QuestionnaireAnswers.fromJson(Object? json); final List<int> choices; int of(int question); List<int> toJson(); }`;
  - `enum RankSource { estimated, selfDeclared, verified }`, `enum OnboardingState { notStarted, skipped, done }`;
  - `final class PlayerRank { const PlayerRank({required OnboardingState onboardingState, required DateTime updatedAt, Rank? rank, RankSource? source, int? buScore, String? testId, Rank? warningRank, String? warningTestId, QuestionnaireAnswers? answers}); bool get isVerified; bool get hasRank; }`;
  - `enum RankOutcome { firstRank, promoted, confirmed, warned }`;
  - `bool canUseQuestionnaire(PlayerRank? current)`;
  - `PlayerRank rankFromQuestionnaire(PlayerRank? current, {required Rank chosen, required Rank suggested, required QuestionnaireAnswers answers, required DateTime now})`;
  - `PlayerRank rankAfterSkip(PlayerRank? current, DateTime now)`;
  - `({PlayerRank rank, RankOutcome outcome}) applyTestResult(PlayerRank? current, {required Rank result, required int buScore, required String testId, required DateTime now})`.

- [ ] **Step 1: Write the failing tests**

Create `test/domain/assessment/rank_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Sáu luật đổi hạng — spec mục 4.2, mỗi luật ít nhất một test.
void main() {
  final t0 = DateTime(2026, 10, 14, 9);
  final t1 = DateTime(2026, 10, 30, 9);
  final answers = QuestionnaireAnswers([2, 1, 3, 2, 1, 0, 1, 1]);

  PlayerRank ranked(Rank rank, RankSource source,
          {String? testId, int? buScore, Rank? warning, String? warningTestId}) =>
      PlayerRank(
        rank: rank,
        source: source,
        testId: testId ?? (source == RankSource.verified ? 't-cu' : null),
        buScore: buScore ?? (source == RankSource.verified ? 100 : null),
        warningRank: warning,
        warningTestId: warningTestId,
        answers: answers,
        onboardingState: OnboardingState.done,
        updatedAt: t0,
      );

  group('QuestionnaireAnswers', () {
    test('cần đúng 8 câu, mỗi câu trong số lựa chọn của nó', () {
      expect(() => QuestionnaireAnswers([0, 0, 0]), throwsArgumentError);
      expect(() => QuestionnaireAnswers([7, 0, 0, 0, 0, 0, 0, 0]), throwsRangeError,
          reason: 'Q1 chỉ có 7 lựa chọn (0…6)');
    });

    test('ghi ra JSON rồi đọc lại vẫn y nguyên', () {
      expect(QuestionnaireAnswers.fromJson(answers.toJson()), answers);
      expect(answers.of(5), 1);
    });
  });

  group('luật 1: bộ câu hỏi', () {
    test('chấp nhận hạng gợi ý thì nguồn là ước lượng', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.h, suggested: Rank.h, answers: answers, now: t0);
      expect(r.rank, Rank.h);
      expect(r.source, RankSource.estimated);
      expect(r.onboardingState, OnboardingState.done);
      expect(r.answers, answers);
    });

    test('chọn hạng khác gợi ý thì nguồn là tự khai', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.f, suggested: Rank.h, answers: answers, now: t0);
      expect(r.source, RankSource.selfDeclared);
    });

    test('chọn PRO luôn là tự khai', () {
      final r = rankFromQuestionnaire(null,
          chosen: Rank.pro, suggested: Rank.b, answers: answers, now: t0);
      expect(r.rank, Rank.pro);
      expect(r.source, RankSource.selfDeclared);
    });

    test('làm lại được khi hạng chưa kiểm chứng', () {
      final cur = ranked(Rank.g, RankSource.estimated);
      expect(canUseQuestionnaire(cur), isTrue);
      final r = rankFromQuestionnaire(cur,
          chosen: Rank.f, suggested: Rank.f, answers: answers, now: t1);
      expect(r.rank, Rank.f);
      expect(r.updatedAt, t1);
    });

    test('hạng đã kiểm chứng thì khoá bộ câu hỏi, kể cả tự khai PRO', () {
      final cur = ranked(Rank.d, RankSource.verified);
      expect(canUseQuestionnaire(cur), isFalse);
      expect(
        () => rankFromQuestionnaire(cur,
            chosen: Rank.pro, suggested: Rank.d, answers: answers, now: t1),
        throwsStateError,
      );
    });

    test('bộ câu hỏi không bao giờ gợi ý A hay PRO', () {
      expect(
        () => rankFromQuestionnaire(null,
            chosen: Rank.a, suggested: Rank.a, answers: answers, now: t0),
        throwsArgumentError,
      );
    });

    // D11 của kế hoạch: cảnh báo chỉ còn nghĩa khi hạng mới vẫn cao hơn nó.
    test('làm lại bộ câu hỏi: giữ cảnh báo nếu hạng mới vẫn cao hơn, bỏ nếu không', () {
      final warned = ranked(Rank.e, RankSource.estimated,
          warning: Rank.g, warningTestId: 't9');
      final higher = rankFromQuestionnaire(warned,
          chosen: Rank.f, suggested: Rank.f, answers: answers, now: t1);
      expect(higher.warningRank, Rank.g);
      expect(higher.warningTestId, 't9');
      final same = rankFromQuestionnaire(warned,
          chosen: Rank.g, suggested: Rank.g, answers: answers, now: t1);
      expect(same.warningRank, isNull);
      expect(same.warningTestId, isNull);
    });
  });

  group('Để sau', () {
    test('chưa có gì thì thành bỏ qua, không có hạng', () {
      final r = rankAfterSkip(null, t0);
      expect(r.onboardingState, OnboardingState.skipped);
      expect(r.rank, isNull);
      expect(r.source, isNull);
    });

    test('đã có hạng mà bấm Để sau khi làm lại thì không mất gì', () {
      final cur = ranked(Rank.g, RankSource.estimated);
      expect(identical(rankAfterSkip(cur, t1), cur), isTrue);
    });
  });

  group('luật 2–6: kết quả bài kiểm tra BU', () {
    test('luật 2: cao hơn thì lên hạng, kể cả nhảy nhiều hạng, thành đã kiểm chứng', () {
      final cur = ranked(Rank.h, RankSource.estimated);
      final r = applyTestResult(cur, result: Rank.e, buScore: 112, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.promoted);
      expect(r.rank.rank, Rank.e);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.buScore, 112);
      expect(r.rank.testId, 't2');
      expect(r.rank.answers, answers, reason: 'câu trả lời vẫn giữ để truy vết');
    });

    test('luật 3: bằng thì giữ hạng, thành đã kiểm chứng', () {
      final cur = ranked(Rank.g, RankSource.selfDeclared);
      final r = applyTestResult(cur, result: Rank.g, buScore: 80, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.confirmed);
      expect(r.rank.rank, Rank.g);
      expect(r.rank.source, RankSource.verified);
    });

    test('luật 4: thấp hơn thì giữ hạng và nguồn, đặt cảnh báo', () {
      final cur = ranked(Rank.e, RankSource.verified, testId: 't1', buScore: 115);
      final r = applyTestResult(cur, result: Rank.g, buScore: 80, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.warned);
      expect(r.rank.rank, Rank.e);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.testId, 't1', reason: 'lần kiểm chứng hạng vẫn là lần cũ');
      expect(r.rank.buScore, 115);
      expect(r.rank.warningRank, Rank.g);
      expect(r.rank.warningTestId, 't2');
    });

    test('luật 4: lần sau bằng hoặc cao hơn thì xoá cảnh báo', () {
      final warned = ranked(Rank.e, RankSource.verified,
          testId: 't1', buScore: 115, warning: Rank.g, warningTestId: 't2');
      final r = applyTestResult(warned, result: Rank.e, buScore: 118, testId: 't3', now: t1);
      expect(r.rank.warningRank, isNull);
      expect(r.rank.warningTestId, isNull);
      expect(r.rank.testId, 't3');
    });

    test('luật 5: BU không bao giờ ra PRO; người tự khai PRO ra A thì bị cảnh báo', () {
      expect(
        () => applyTestResult(null, result: Rank.pro, buScore: 200, testId: 't', now: t1),
        throwsArgumentError,
      );
      final pro = ranked(Rank.pro, RankSource.selfDeclared);
      final r = applyTestResult(pro, result: Rank.a, buScore: 190, testId: 't2', now: t1);
      expect(r.outcome, RankOutcome.warned);
      expect(r.rank.rank, Rank.pro);
      expect(r.rank.source, RankSource.selfDeclared);
      expect(r.rank.warningRank, Rank.a);
    });

    test('luật 6: chưa có hạng (đã bỏ qua) thì nhận hạng từ kết quả', () {
      final skipped = rankAfterSkip(null, t0);
      final r = applyTestResult(skipped, result: Rank.h, buScore: 50, testId: 't1', now: t1);
      expect(r.outcome, RankOutcome.firstRank);
      expect(r.rank.rank, Rank.h);
      expect(r.rank.source, RankSource.verified);
      expect(r.rank.onboardingState, OnboardingState.skipped,
          reason: 'trạng thái onboarding không bị viết lại');
      final none = applyTestResult(null, result: Rank.k, buScore: 5, testId: 't1', now: t1);
      expect(none.outcome, RankOutcome.firstRank);
      expect(none.rank.onboardingState, OnboardingState.done);
    });

    test('app không bao giờ tự hạ hạng: mọi kết quả thấp hơn đều giữ hạng', () {
      for (final current in Rank.values) {
        for (final result in Rank.values.where((r) => r != Rank.pro)) {
          final cur = ranked(current, RankSource.selfDeclared);
          final r = applyTestResult(cur, result: result, buScore: 1, testId: 't', now: t1);
          expect(r.rank.rank!.index, greaterThanOrEqualTo(current.index),
              reason: '$current → $result');
        }
      }
    });
  });
}
```

Append to `test/architecture_test.dart`, inside `main`, after the test `lõi Planner không phụ thuộc Flutter`:

```dart
  test('lõi đánh giá không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/assessment');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'luật hạng và bộ chấm BU phải chạy và test được trên Dart VM '
          'thuần (spec 2026-10-14 mục 5)',
    );
  });
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
"$FLUTTER" test test/domain/assessment/rank_rules_test.dart test/architecture_test.dart
```

Expected: FAIL — the imports `package:poolcoachai/domain/assessment/...` do not exist, and the architecture test fails on `expect(files, isNotEmpty)` (the directory listing throws `PathNotFoundException`).

- [ ] **Step 3: Write `questionnaire.dart` (answers part)**

```dart
/// Số lựa chọn của từng câu Q1…Q8, đúng thứ tự trong spec mục 11.2.
///
/// Q1 7 · Q2 5 · Q3 9 (1…8 và Dọn bàn) · Q4 7 (1…5, 6+, Thường xuyên
/// Runout) · Q5 5 · Q6 8 · Q7 5 · Q8 5.
const questionOptionCounts = <int>[7, 5, 9, 7, 5, 8, 5, 5];

/// Câu trả lời gần nhất của bộ câu hỏi: chỉ số lựa chọn (từ 0) của Q1…Q8.
///
/// Lưu nguyên cả 8 câu, kể cả 5 câu không dùng để tính hạng, để truy được
/// vì sao app gợi ý hạng đó và để Lộ trình dùng sau (spec mục 4.1, 11.2).
final class QuestionnaireAnswers {
  QuestionnaireAnswers(List<int> choices) : choices = List.unmodifiable(choices) {
    if (choices.length != questionOptionCounts.length) {
      throw ArgumentError.value(
          choices, 'choices', 'cần đúng ${questionOptionCounts.length} câu trả lời');
    }
    for (var i = 0; i < choices.length; i++) {
      RangeError.checkValueInInterval(
          choices[i], 0, questionOptionCounts[i] - 1, 'Q${i + 1}');
    }
  }

  factory QuestionnaireAnswers.fromJson(Object? json) {
    if (json is! List) {
      throw FormatException('Câu trả lời phải là mảng JSON', json);
    }
    return QuestionnaireAnswers([for (final c in json) c as int]);
  }

  final List<int> choices;

  /// Lựa chọn của câu [question], đánh số 1…8 như spec.
  int of(int question) => choices[question - 1];

  List<int> toJson() => choices;

  @override
  bool operator ==(Object other) {
    if (other is! QuestionnaireAnswers) return false;
    for (var i = 0; i < choices.length; i++) {
      if (choices[i] != other.choices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(choices);

  @override
  String toString() => 'QuestionnaireAnswers($choices)';
}
```

- [ ] **Step 4: Write `player_rank.dart`**

```dart
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Hạng đến từ đâu (spec mục 4.1).
enum RankSource {
  /// Người chơi chấp nhận hạng bộ câu hỏi gợi ý.
  estimated,

  /// Người chơi chọn hạng khác gợi ý, hoặc chọn PRO.
  selfDeclared,

  /// Hạng có từ bài kiểm tra BU.
  verified,
}

enum OnboardingState { notStarted, skipped, done }

/// Bản ghi hạng của một tài khoản (spec mục 4.1).
///
/// [rank] và [source] cùng null khi người chơi đã bấm *Để sau* mà chưa
/// làm bài kiểm tra nào (luật 6 cần trạng thái "chưa có hạng").
final class PlayerRank {
  const PlayerRank({
    required this.onboardingState,
    required this.updatedAt,
    this.rank,
    this.source,
    this.buScore,
    this.testId,
    this.warningRank,
    this.warningTestId,
    this.answers,
  })  : assert((rank == null) == (source == null), 'hạng và nguồn đi cùng nhau'),
        assert(source != RankSource.verified || (buScore != null && testId != null),
            'hạng đã kiểm chứng phải truy được về một lần kiểm tra'),
        assert((warningRank == null) == (warningTestId == null),
            'cảnh báo phải chỉ ra lần kiểm tra gây ra nó');

  final Rank? rank;
  final RankSource? source;

  /// Điểm BU và lần kiểm tra đã kiểm chứng hạng.
  final int? buScore;
  final String? testId;

  /// Cảnh báo đang hiện: một lần kiểm tra cho hạng thấp hơn (luật 4).
  final Rank? warningRank;
  final String? warningTestId;

  final QuestionnaireAnswers? answers;
  final OnboardingState onboardingState;
  final DateTime updatedAt;

  bool get hasRank => rank != null;
  bool get isVerified => source == RankSource.verified;

  @override
  bool operator ==(Object other) =>
      other is PlayerRank &&
      other.rank == rank &&
      other.source == source &&
      other.buScore == buScore &&
      other.testId == testId &&
      other.warningRank == warningRank &&
      other.warningTestId == warningTestId &&
      other.answers == answers &&
      other.onboardingState == onboardingState &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(rank, source, buScore, testId, warningRank,
      warningTestId, answers, onboardingState, updatedAt);

  @override
  String toString() => 'PlayerRank($rank, $source, bu=$buScore, test=$testId, '
      'warning=$warningRank/$warningTestId, $onboardingState, $updatedAt)';
}
```

- [ ] **Step 5: Write `rank_rules.dart`**

```dart
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Hạng đổi thế nào sau một lần kiểm tra BU hoàn tất (spec mục 4.2).
enum RankOutcome {
  /// Chưa có hạng, nhận hạng từ kết quả (luật 6).
  firstRank,

  /// Kết quả cao hơn: lên hạng (luật 2).
  promoted,

  /// Kết quả bằng: giữ hạng, thành đã kiểm chứng (luật 3).
  confirmed,

  /// Kết quả thấp hơn: giữ hạng và nguồn, đặt cảnh báo (luật 4, 5).
  warned,
}

/// Bộ câu hỏi còn đổi được hạng không. Hạng đã kiểm chứng thì chỉ bài
/// kiểm tra BU đổi được, kể cả tự khai PRO cũng khoá (luật 1).
bool canUseQuestionnaire(PlayerRank? current) =>
    current?.source != RankSource.verified;

/// Người chơi chốt hạng ở cuối bộ câu hỏi (luật 1, spec mục 7.2 bước 4).
PlayerRank rankFromQuestionnaire(
  PlayerRank? current, {
  required Rank chosen,
  required Rank suggested,
  required QuestionnaireAnswers answers,
  required DateTime now,
}) {
  if (!canUseQuestionnaire(current)) {
    throw StateError('Hạng đã kiểm chứng chỉ đổi được bằng bài kiểm tra BU');
  }
  if (suggested == Rank.a || suggested == Rank.pro) {
    throw ArgumentError.value(
        suggested, 'suggested', 'bộ câu hỏi không bao giờ gợi ý A hay PRO');
  }
  // Cảnh báo nói "lần kiểm tra cho hạng thấp hơn hạng hiện tại". Hạng mới
  // không còn cao hơn nó thì câu đó sai, nên bỏ (D11 của kế hoạch).
  final warning = current?.warningRank;
  final keepWarning = warning != null && chosen.index > warning.index;
  return PlayerRank(
    rank: chosen,
    source: chosen == suggested ? RankSource.estimated : RankSource.selfDeclared,
    answers: answers,
    warningRank: keepWarning ? warning : null,
    warningTestId: keepWarning ? current!.warningTestId : null,
    onboardingState: OnboardingState.done,
    updatedAt: now,
  );
}

/// Bấm *Để sau*. Đã có bản ghi (đang làm lại bộ câu hỏi) thì không đổi gì:
/// trả đúng [current] để bên ghi biết khỏi ghi.
PlayerRank rankAfterSkip(PlayerRank? current, DateTime now) {
  if (current != null && current.onboardingState != OnboardingState.notStarted) {
    return current;
  }
  return PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: now);
}

/// Áp kết quả một lần kiểm tra BU vừa hoàn tất (luật 2–6).
({PlayerRank rank, RankOutcome outcome}) applyTestResult(
  PlayerRank? current, {
  required Rank result,
  required int buScore,
  required String testId,
  required DateTime now,
}) {
  if (result == Rank.pro) {
    throw ArgumentError.value(result, 'result', 'bài kiểm tra BU không bao giờ ra PRO');
  }
  final before = current?.rank;
  final outcome = before == null
      ? RankOutcome.firstRank
      : result.index > before.index
          ? RankOutcome.promoted
          : result == before
              ? RankOutcome.confirmed
              : RankOutcome.warned;

  if (outcome == RankOutcome.warned) {
    final c = current!;
    return (
      rank: PlayerRank(
        rank: c.rank,
        source: c.source,
        buScore: c.buScore,
        testId: c.testId,
        answers: c.answers,
        onboardingState: c.onboardingState,
        warningRank: result,
        warningTestId: testId,
        updatedAt: now,
      ),
      outcome: outcome,
    );
  }

  return (
    rank: PlayerRank(
      rank: result,
      source: RankSource.verified,
      buScore: buScore,
      testId: testId,
      answers: current?.answers,
      onboardingState: current == null ||
              current.onboardingState == OnboardingState.notStarted
          ? OnboardingState.done
          : current.onboardingState,
      updatedAt: now,
    ),
    outcome: outcome,
  );
}
```

- [ ] **Step 6: Run the tests to see them pass**

```bash
"$FLUTTER" test test/domain/assessment/rank_rules_test.dart test/architecture_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/assessment test/domain/assessment/rank_rules_test.dart test/architecture_test.dart
git commit -m "Add the player rank record and the six rank rules of the assessment spec

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The BU → rank table and Exam II placement (spec §5.4)

**Files:**
- Create: `lib/domain/assessment/bu_placement.dart`
- Test: `test/domain/assessment/bu_placement_test.dart`

**Interfaces:**
- Consumes: `Rank`.
- Produces:
  - `enum TableSize { sevenFoot, eightFoot, nineFootPlus }`, `enum ExamIIVersion { bachelors, masters, doctorate }`;
  - `const examIMax = 100`, `const buTotalMax = 200`;
  - `ExamIIVersion placeExamII(int examIScore, TableSize table)`;
  - `final class BuRankBand { final Rank rank; final int min; final int max; final String buLevels; final String fargo; }`, `const List<BuRankBand> buRankBands`;
  - `BuRankBand bandForBuScore(int total)`, `Rank rankForBuScore(int total)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/rank.dart';

void main() {
  group('xếp bản Đề II — BU_Exam_Instructions.pdf trang 1 mục 5, '
      'BU_Exam-I_Score_Sheet.pdf "Score Ranges for Exam II Placement"', () {
    test('mốc 49/50 và 69/70 trên bàn 9 feet', () {
      const t = TableSize.nineFootPlus;
      expect(placeExamII(0, t), ExamIIVersion.bachelors);
      expect(placeExamII(49, t), ExamIIVersion.bachelors);
      expect(placeExamII(50, t), ExamIIVersion.masters);
      expect(placeExamII(69, t), ExamIIVersion.masters);
      expect(placeExamII(70, t), ExamIIVersion.doctorate);
      expect(placeExamII(100, t), ExamIIVersion.doctorate);
    });

    test('bàn 7–8 feet đạt mức Doctorate thì làm bản Masters', () {
      for (final t in [TableSize.sevenFoot, TableSize.eightFoot]) {
        expect(placeExamII(70, t), ExamIIVersion.masters, reason: '$t');
        expect(placeExamII(100, t), ExamIIVersion.masters, reason: '$t');
        expect(placeExamII(49, t), ExamIIVersion.bachelors, reason: '$t');
        expect(placeExamII(50, t), ExamIIVersion.masters, reason: '$t');
      }
    });

    test('điểm ngoài 0–100 là lỗi lập trình', () {
      expect(() => placeExamII(-1, TableSize.nineFootPlus), throwsRangeError);
      expect(() => placeExamII(101, TableSize.nineFootPlus), throwsRangeError);
    });
  });

  group('quy đổi BU sang hạng — spec mục 5.4 (gộp mức của BU_Rating_Comparisons.pdf)', () {
    test('mọi mốc của bảng', () {
      const cases = {
        0: Rank.k, 19: Rank.k, 20: Rank.i, 39: Rank.i, 40: Rank.h, 54: Rank.h,
        55: Rank.h, 69: Rank.h, 70: Rank.g, 94: Rank.g, 95: Rank.f, 109: Rank.f,
        110: Rank.e, 124: Rank.e, 125: Rank.d, 139: Rank.d, 140: Rank.c,
        154: Rank.c, 155: Rank.b, 174: Rank.b, 175: Rank.a, 200: Rank.a,
      };
      cases.forEach((score, rank) {
        expect(rankForBuScore(score), rank, reason: 'điểm $score');
      });
    });

    test('các dải liền nhau, phủ đúng 0–200, xếp K → A, không có PRO', () {
      expect(buRankBands.first.min, 0);
      expect(buRankBands.last.max, buTotalMax);
      for (var i = 1; i < buRankBands.length; i++) {
        expect(buRankBands[i].min, buRankBands[i - 1].max + 1);
        expect(buRankBands[i].rank.index, buRankBands[i - 1].rank.index + 1);
      }
      expect(buRankBands.map((b) => b.rank), isNot(contains(Rank.pro)));
      expect(buRankBands.map((b) => b.rank).toList(),
          Rank.values.where((r) => r != Rank.pro).toList());
    });

    test('dải mang tên mức BU và Fargo tham chiếu của spec', () {
      expect(bandForBuScore(150).buLevels, 'upper advanced');
      expect(bandForBuScore(150).fargo, '600–649');
      expect(bandForBuScore(10).fargo, '< 200');
      expect(bandForBuScore(180).fargo, '≥ 730');
    });

    test('điểm ngoài 0–200 là lỗi lập trình', () {
      expect(() => rankForBuScore(-1), throwsRangeError);
      expect(() => rankForBuScore(201), throwsRangeError);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
"$FLUTTER" test test/domain/assessment/bu_placement_test.dart
```

Expected: FAIL — `bu_placement.dart` does not exist.

- [ ] **Step 3: Write `bu_placement.dart`**

```dart
import 'package:poolcoachai/domain/rank.dart';

/// Kích thước bàn khi làm bài (spec mục 7.3 bước 1).
enum TableSize { sevenFoot, eightFoot, nineFootPlus }

/// Ba bản Đề II của BU.
enum ExamIIVersion { bachelors, masters, doctorate }

const examIMax = 100;
const buTotalMax = 200;

/// Điểm Đề I xếp bản Đề II (BU_Exam_Instructions.pdf trang 1 mục 5).
///
/// Bản Doctorate phải đánh trên bàn 9 feet trở lên; bàn nhỏ hơn mà Đề I đạt
/// mức Doctorate thì làm bản Masters.
ExamIIVersion placeExamII(int examIScore, TableSize table) {
  RangeError.checkValueInInterval(examIScore, 0, examIMax, 'examIScore');
  if (examIScore <= 49) return ExamIIVersion.bachelors;
  if (examIScore <= 69) return ExamIIVersion.masters;
  return table == TableSize.nineFootPlus
      ? ExamIIVersion.doctorate
      : ExamIIVersion.masters;
}

/// Một dòng của bảng quy đổi BU sang hạng (spec mục 5.4).
///
/// [buLevels] và [fargo] là chữ của BU_Rating_Comparisons.pdf, giữ nguyên
/// tiếng Anh vì đó là tên mức của BU.
final class BuRankBand {
  const BuRankBand({
    required this.rank,
    required this.min,
    required this.max,
    required this.buLevels,
    required this.fargo,
  });

  final Rank rank;
  final int min;
  final int max;
  final String buLevels;
  final String fargo;
}

/// Bảng chủ sản phẩm chốt ngày 14/10/2026: chỉ gộp các mức có sẵn của BU.
const buRankBands = <BuRankBand>[
  BuRankBand(rank: Rank.k, min: 0, max: 19, buLevels: 'novice', fargo: '< 200'),
  BuRankBand(rank: Rank.i, min: 20, max: 39, buLevels: 'lower + mid beginner', fargo: '200–299'),
  BuRankBand(rank: Rank.h, min: 40, max: 69, buLevels: 'upper beginner + lower intermediate', fargo: '300–399'),
  BuRankBand(rank: Rank.g, min: 70, max: 94, buLevels: 'mid intermediate', fargo: '400–449'),
  BuRankBand(rank: Rank.f, min: 95, max: 109, buLevels: 'upper intermediate', fargo: '450–499'),
  BuRankBand(rank: Rank.e, min: 110, max: 124, buLevels: 'lower advanced', fargo: '500–549'),
  BuRankBand(rank: Rank.d, min: 125, max: 139, buLevels: 'mid advanced', fargo: '550–599'),
  BuRankBand(rank: Rank.c, min: 140, max: 154, buLevels: 'upper advanced', fargo: '600–649'),
  BuRankBand(rank: Rank.b, min: 155, max: 174, buLevels: 'lower + upper shortstop', fargo: '650–729'),
  BuRankBand(rank: Rank.a, min: 175, max: 200, buLevels: 'semipro/pro + world class pro', fargo: '≥ 730'),
];

BuRankBand bandForBuScore(int total) {
  RangeError.checkValueInInterval(total, 0, buTotalMax, 'total');
  return buRankBands.firstWhere((b) => total >= b.min && total <= b.max);
}

Rank rankForBuScore(int total) => bandForBuScore(total).rank;
```

- [ ] **Step 4: Run it to see it pass**

```bash
"$FLUTTER" test test/domain/assessment/bu_placement_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/assessment/bu_placement.dart test/domain/assessment/bu_placement_test.dart
git commit -m "Add Exam II placement and the BU score to rank table

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Raw attempts and the five scoring kinds (spec §5.3)

**Files:**
- Create: `lib/domain/assessment/drill_attempts.dart`
- Create: `lib/domain/assessment/bu_scoring.dart`
- Test: `test/domain/assessment/bu_scoring_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `final class BreakCriteria { const BreakCriteria({required bool a, bool b, bool c, bool d, bool e}); factory BreakCriteria.fromJson(Object? json); int get points; List<bool> toJson(); }`;
  - `sealed class DrillAttempts { factory DrillAttempts.fromJson(Object? json); int get length; bool get isEmpty; DrillAttempts withoutLast(); Map<String, Object?> toJson(); }` with `ShotAttempts(List<bool> shots)` (+ `ShotAttempts add(bool made)`), `CountAttempts(List<int> counts)` (+ `add(int)`), `BreakAttempts(List<BreakCriteria> breaks)` (+ `add(BreakCriteria)`);
  - constants `ladderStart = 4`, `ladderLowest = 1`, `ladderHighest = 7`, `ladderShotCount = 10`, `ladderCap = 10`;
  - `List<int> ladderPositions(List<bool> shots)`, `int ladderPosition(List<bool> shots)`, `int ladderBonus(List<bool> shots)`, `int ladderScore(List<bool> shots)`, `bool ladderSettled(List<bool> shots)`;
  - `int successCount(List<bool> shots)`, `int bestOfTwo(List<int> counts)`, `int sumOfLowestTwo(List<int> counts)`, `int medianOfThreeBreaks(List<BreakCriteria> breaks)`.

Every expectation below cites the BU document it came from. While writing these tests, **re-read the cited page** and fix the test (never the citation) if the PDF says otherwise; if the PDF contradicts spec §5.3, stop and report to the owner.

- [ ] **Step 1: Write the failing test**

```dart
// ignore_for_file: constant_identifier_names
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

const V = true; // vào
const T = false; // trượt

void main() {
  group('thang vị trí F1–F5', () {
    // BU_Exam-I_Score_Sheet.pdf trang 1: "position (start: 4)"; "circle every
    // 7 that follows a 7 … The number of circles is the number of bonus
    // points. The maximum score allowed (including bonus points) is 10";
    // "score (10 max) = last pos. + bonus". Vào +1, trượt −1, kẹp 1–7: spec
    // mục 5.3 và BU_Exam-I_Fundamentals.pdf (đối chiếu trang mô tả F1).
    test('ví dụ tính tay: lên 7, ba lần vào ở 7 → 7 + 3 = 10', () {
      final shots = [V, T, V, V, V, V, T, V, V, V];
      expect(ladderPositions(shots), [5, 4, 5, 6, 7, 7, 6, 7, 7, 7]);
      expect(ladderBonus(shots), 3);
      expect(ladderScore(shots), 10);
    });

    test('ví dụ tính tay không chạm trần: 7 + 1 = 8', () {
      final shots = [T, T, V, V, V, V, V, V, T, V];
      expect(ladderPositions(shots), [3, 2, 3, 4, 5, 6, 7, 7, 6, 7]);
      expect(ladderBonus(shots), 1);
      expect(ladderScore(shots), 8);
    });

    test('toàn trượt: kẹp ở 1, điểm 1', () {
      final shots = List.filled(10, T);
      expect(ladderPositions(shots).last, 1);
      expect(ladderScore(shots), 1);
    });

    test('toàn vào: 7 + 7 thưởng, ghi 10', () {
      final shots = List.filled(10, V);
      expect(ladderBonus(shots), 7);
      expect(ladderScore(shots), 10);
    });

    test('cú thứ 10 vẫn được áp dụng', () {
      final nine = [V, V, V, T, T, T, T, T, T];
      expect(ladderScore(nine), 1);
      expect(ladderScore([...nine, V]), 2);
    });

    test('chưa đánh cú nào: đứng ở vị trí 4', () {
      expect(ladderPosition(const []), 4);
      expect(ladderScore(const []), 4);
    });

    test('dừng sớm khi đã chắc chắn 10: tám cú vào liền', () {
      // Sau 8 cú: vị trí 7, thưởng 5, còn 2 cú; trượt cả 2 vẫn 5 + 5 = 10.
      expect(ladderSettled(List.filled(7, V)), isFalse);
      expect(ladderSettled(List.filled(8, V)), isTrue);
      expect(ladderScore(List.filled(8, V)), 10);
    });

    test('chưa chắc 10 thì phải đánh đủ 10 cú', () {
      expect(ladderSettled([V, T, V, V, V, V, T, V, V]), isFalse);
      expect(ladderSettled([V, T, V, V, V, V, T, V, V, V]), isTrue);
      expect(ladderSettled(List.filled(10, T)), isTrue);
    });

    test('quá 10 cú là lỗi lập trình', () {
      expect(() => ladderPositions(List.filled(11, V)), throwsRangeError);
    });
  });

  group('đếm lượt thành công (F6, F7, F8, S5–S9)', () {
    // BU_Exam-I_Score_Sheet.pdf: F6 "score (10 max) = # of balls pocketed",
    // F7 "score (20 max) = total # of hits", F8 "score (20 max) = total # on
    // target"; Exam II sheets: S5 "= # hidden", S6 "= # of hits", S7
    // "= # pocketed", S8/S9 "= # of successes".
    test('mỗi lượt thành công 1 điểm', () {
      expect(successCount([V, T, V, V]), 3);
      expect(successCount(List.filled(20, T)), 0);
      expect(successCount(List.filled(20, V)), 20);
    });
  });

  group('lấy lượt cao hơn trong 2 lượt (S1, S2)', () {
    // Exam II sheets: "score (… max) = best of two".
    test('lấy lượt cao hơn', () {
      expect(bestOfTwo([2, 3]), 3);
      expect(bestOfTwo([4, 1]), 4);
      expect(bestOfTwo([0, 0]), 0);
    });

    test('một lượt (lượt 1 hoàn hảo) cũng chấm được', () {
      expect(bestOfTwo([7]), 7);
    });

    test('không có lượt hay quá 2 lượt là lỗi lập trình', () {
      expect(() => bestOfTwo(const []), throwsArgumentError);
      expect(() => bestOfTwo([1, 2, 3]), throwsArgumentError);
    });
  });

  group('cộng hai thế thấp nhất trong 3 thế (S3, S4)', () {
    // Exam II sheets: "score (… max) = lowest + 2nd lowest".
    test('ví dụ tính tay', () {
      expect(sumOfLowestTwo([5, 2, 4]), 6);
      expect(sumOfLowestTwo([5, 5, 5]), 10);
      expect(sumOfLowestTwo([0, 7, 0]), 0);
    });

    test('phải đủ 3 thế', () {
      expect(() => sumOfLowestTwo([5, 5]), throwsArgumentError);
    });
  });

  group('trung vị 3 lần phá (S10)', () {
    // Exam II sheets: "score (5 max) = median (middle value) of the three
    // break scores"; tiêu chí a–e: spec mục 5.2, đối chiếu trang S10 của
    // BU_Exam-II_Skills-*.pdf.
    const full = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
    const scratch = BreakCriteria(a: false, b: true, c: true, d: true, e: true);
    const twoPoints = BreakCriteria(a: true, d: true);

    test('điểm một lần phá: đếm tiêu chí, nhưng b–e chỉ tính khi đạt a', () {
      expect(full.points, 5);
      expect(twoPoints.points, 2);
      expect(scratch.points, 0, reason: 'phá chết cái thì 0 điểm');
    });

    test('lấy trung vị', () {
      expect(medianOfThreeBreaks([full, scratch, twoPoints]), 2);
      expect(medianOfThreeBreaks([full, full, scratch]), 5);
      expect(medianOfThreeBreaks([scratch, scratch, full]), 0);
    });

    test('phải đủ 3 lần phá', () {
      expect(() => medianOfThreeBreaks([full, full]), throwsArgumentError);
    });
  });

  group('kết quả thô ghi ra JSON rồi đọc lại', () {
    test('ba kiểu, kể cả danh sách rỗng', () {
      final cases = <DrillAttempts>[
        ShotAttempts([V, T, V]),
        ShotAttempts(const []),
        CountAttempts([3, 4]),
        BreakAttempts([const BreakCriteria(a: true, c: true)]),
      ];
      for (final a in cases) {
        expect(DrillAttempts.fromJson(a.toJson()), a, reason: '$a');
      }
    });

    test('add và withoutLast không sửa bản gốc', () {
      final a = ShotAttempts([V]);
      final b = a.add(T);
      expect(a.shots, [V]);
      expect(b.shots, [V, T]);
      expect((b.withoutLast() as ShotAttempts).shots, [V]);
      expect(ShotAttempts(const []).withoutLast().isEmpty, isTrue);
    });

    test('JSON lạ thì ném, không đoán', () {
      expect(() => DrillAttempts.fromJson({'x': 1}), throwsFormatException);
      expect(() => DrillAttempts.fromJson([1]), throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
"$FLUTTER" test test/domain/assessment/bu_scoring_test.dart
```

Expected: FAIL — the files do not exist.

- [ ] **Step 3: Write `drill_attempts.dart`**

```dart
/// Một lần phá của S10: năm tiêu chí a–e (spec mục 5.2).
///
/// a: không chết cái. b–e đều đòi a trước, nên lần phá chết cái được 0 dù
/// các ô khác có đánh dấu.
final class BreakCriteria {
  const BreakCriteria({
    required this.a,
    this.b = false,
    this.c = false,
    this.d = false,
    this.e = false,
  });

  factory BreakCriteria.fromJson(Object? json) {
    if (json is! List || json.length != 5) {
      throw FormatException('Một lần phá phải là mảng 5 giá trị đúng/sai', json);
    }
    final v = [for (final x in json) x as bool];
    return BreakCriteria(a: v[0], b: v[1], c: v[2], d: v[3], e: v[4]);
  }

  final bool a;
  final bool b;
  final bool c;
  final bool d;
  final bool e;

  int get points => a ? 1 + [b, c, d, e].where((x) => x).length : 0;

  List<bool> toJson() => [a, b, c, d, e];

  @override
  bool operator ==(Object other) =>
      other is BreakCriteria &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e;

  @override
  int get hashCode => Object.hash(a, b, c, d, e);

  @override
  String toString() => 'BreakCriteria(${toJson()})';
}

bool _sameList<T>(List<T> x, List<T> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

/// Kết quả thô của một bài: từng cú đúng như người chơi nhập (spec mục 6.1).
///
/// Lưu thô để nếu phát hiện chấm sai một luật BU thì tính lại được.
sealed class DrillAttempts {
  const DrillAttempts();

  factory DrillAttempts.fromJson(Object? json) {
    if (json is! Map) throw FormatException('Kết quả thô phải là object JSON', json);
    final shots = json['shots'];
    if (shots is List) return ShotAttempts([for (final s in shots) s as bool]);
    final counts = json['counts'];
    if (counts is List) return CountAttempts([for (final c in counts) c as int]);
    final breaks = json['breaks'];
    if (breaks is List) {
      return BreakAttempts([for (final b in breaks) BreakCriteria.fromJson(b)]);
    }
    throw FormatException('Kết quả thô không rõ kiểu', json);
  }

  int get length;
  bool get isEmpty => length == 0;

  /// Bỏ lượt cuối — nút *Hoàn tác cú vừa nhập*.
  DrillAttempts withoutLast();

  Map<String, Object?> toJson();
}

/// Mỗi lượt là vào/trượt (thang vị trí và đếm lượt thành công).
final class ShotAttempts extends DrillAttempts {
  ShotAttempts(List<bool> shots) : shots = List.unmodifiable(shots);

  final List<bool> shots;

  @override
  int get length => shots.length;

  ShotAttempts add(bool made) => ShotAttempts([...shots, made]);

  @override
  ShotAttempts withoutLast() =>
      shots.isEmpty ? this : ShotAttempts(shots.sublist(0, shots.length - 1));

  @override
  Map<String, Object?> toJson() => {'shots': shots};

  @override
  bool operator ==(Object other) => other is ShotAttempts && _sameList(shots, other.shots);

  @override
  int get hashCode => Object.hashAll(shots);

  @override
  String toString() => 'ShotAttempts($shots)';
}

/// Mỗi lượt là số bi (lấy lượt cao hơn; cộng hai thế thấp nhất).
final class CountAttempts extends DrillAttempts {
  CountAttempts(List<int> counts) : counts = List.unmodifiable(counts);

  final List<int> counts;

  @override
  int get length => counts.length;

  CountAttempts add(int balls) => CountAttempts([...counts, balls]);

  @override
  CountAttempts withoutLast() =>
      counts.isEmpty ? this : CountAttempts(counts.sublist(0, counts.length - 1));

  @override
  Map<String, Object?> toJson() => {'counts': counts};

  @override
  bool operator ==(Object other) => other is CountAttempts && _sameList(counts, other.counts);

  @override
  int get hashCode => Object.hashAll(counts);

  @override
  String toString() => 'CountAttempts($counts)';
}

/// Mỗi lượt là một lần phá với năm tiêu chí.
final class BreakAttempts extends DrillAttempts {
  BreakAttempts(List<BreakCriteria> breaks) : breaks = List.unmodifiable(breaks);

  final List<BreakCriteria> breaks;

  @override
  int get length => breaks.length;

  BreakAttempts add(BreakCriteria b) => BreakAttempts([...breaks, b]);

  @override
  BreakAttempts withoutLast() =>
      breaks.isEmpty ? this : BreakAttempts(breaks.sublist(0, breaks.length - 1));

  @override
  Map<String, Object?> toJson() => {'breaks': [for (final b in breaks) b.toJson()]};

  @override
  bool operator ==(Object other) => other is BreakAttempts && _sameList(breaks, other.breaks);

  @override
  int get hashCode => Object.hashAll(breaks);

  @override
  String toString() => 'BreakAttempts($breaks)';
}
```

- [ ] **Step 4: Write `bu_scoring.dart`**

```dart
import 'dart:math' as math;

import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

// Thang vị trí F1–F5 — BU_Exam-I_Score_Sheet.pdf và spec mục 5.3.
const ladderStart = 4;
const ladderLowest = 1;
const ladderHighest = 7;
const ladderShotCount = 10;
const ladderCap = 10;

int _step(int position, bool made) =>
    (made ? position + 1 : position - 1).clamp(ladderLowest, ladderHighest);

/// Vị trí sau từng cú — đúng hàng "position" của phiếu điểm Đề I.
List<int> ladderPositions(List<bool> shots) {
  RangeError.checkValueInInterval(shots.length, 0, ladderShotCount, 'shots.length');
  final positions = <int>[];
  var p = ladderStart;
  for (final made in shots) {
    p = _step(p, made);
    positions.add(p);
  }
  return positions;
}

/// Vị trí hiện tại; chưa đánh cú nào thì là vị trí xuất phát.
int ladderPosition(List<bool> shots) {
  final positions = ladderPositions(shots);
  return positions.isEmpty ? ladderStart : positions.last;
}

/// Điểm thưởng: mỗi cú vào khi đang đứng ở vị trí 7 — "mỗi số 7 theo sau
/// một số 7" của phiếu điểm.
int ladderBonus(List<bool> shots) {
  var p = ladderStart;
  var bonus = 0;
  for (final made in shots) {
    if (made && p == ladderHighest) bonus++;
    p = _step(p, made);
  }
  return bonus;
}

/// Vị trí cuối + thưởng, tối đa 10.
int ladderScore(List<bool> shots) =>
    math.min(ladderCap, ladderPosition(shots) + ladderBonus(shots));

/// Bài đã xong: đủ 10 cú, hoặc trượt hết các cú còn lại vẫn được 10 (dừng
/// sớm, spec mục 5.3). Trượt hết là đường tệ nhất: mỗi cú vào chỉ có thể
/// đẩy vị trí lên hoặc cộng thưởng.
bool ladderSettled(List<bool> shots) {
  if (shots.length >= ladderShotCount) return true;
  final left = ladderShotCount - shots.length;
  final worst =
      math.max(ladderLowest, ladderPosition(shots) - left) + ladderBonus(shots);
  return worst >= ladderCap;
}

/// Mỗi lượt thành công 1 điểm.
int successCount(List<bool> shots) => shots.where((s) => s).length;

/// Lượt cao hơn trong (tối đa) 2 lượt.
int bestOfTwo(List<int> counts) {
  if (counts.isEmpty || counts.length > 2) {
    throw ArgumentError.value(counts, 'counts', 'cần 1 hoặc 2 lượt');
  }
  return counts.reduce(math.max);
}

/// Thế thấp nhất + thế thấp nhì trong 3 thế.
int sumOfLowestTwo(List<int> counts) {
  if (counts.length != 3) throw ArgumentError.value(counts, 'counts', 'cần đúng 3 thế');
  final sorted = [...counts]..sort();
  return sorted[0] + sorted[1];
}

/// Trung vị điểm của 3 lần phá.
int medianOfThreeBreaks(List<BreakCriteria> breaks) {
  if (breaks.length != 3) throw ArgumentError.value(breaks, 'breaks', 'cần đúng 3 lần phá');
  final points = [for (final b in breaks) b.points]..sort();
  return points[1];
}
```

- [ ] **Step 5: Run it to see it pass**

```bash
"$FLUTTER" test test/domain/assessment/bu_scoring_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/assessment/drill_attempts.dart lib/domain/assessment/bu_scoring.dart test/domain/assessment/bu_scoring_test.dart
git commit -m "Add raw BU attempts and the five scoring kinds, tested against the score sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Exam definitions F1–F8 and S1–S10 for the three versions (spec §5.1, §5.2)

**Files:**
- Create: `lib/domain/assessment/bu_exams.dart`
- Modify: `lib/core/strings/vi.dart` (add an import of `bu_exams.dart`, and a new section `// Đánh giá + hạng — tên bài BU` before the final `}` of `Vi`)
- Test: `test/domain/assessment/bu_exams_test.dart`
- Test: `test/core/strings/vi_assessment_test.dart`

**Interfaces:**
- Consumes: `ExamIIVersion`, `examIMax` (Task 2); `DrillAttempts` family, scoring functions, `ladderShotCount` (Task 3).
- Produces:
  - `enum BuExam { fundamentals, skills }`, `enum ScoringKind { positionLadder, successCount, bestOfTwo, sumOfLowestTwo, medianBreak }`;
  - `final class BuDrill { const BuDrill({required String id, required ScoringKind kind, required int maxScore, required int attemptCount, int? perAttemptMax, int groups = 1}); BuExam get exam; int get attemptsPerGroup; }`;
  - `const List<BuDrill> examIDrills`, `List<BuDrill> examIIDrills(ExamIIVersion v)`, `int examIIMax(ExamIIVersion v)`, `BuDrill drillFor(String id, ExamIIVersion? version)`;
  - `DrillAttempts emptyAttemptsFor(BuDrill d)`, `bool isDrillComplete(BuDrill d, DrillAttempts a)`, `int? drillScore(BuDrill d, DrillAttempts a)`, `bool attemptsValid(BuDrill d, DrillAttempts a)`;
  - `Vi.buDrillName(String id)`, `Vi.buDrillTitle(String id)`, `Vi.buExamName(BuExam exam)`, `Vi.buVersionName(ExamIIVersion v)`.

- [ ] **Step 1: Write the failing tests**

`test/domain/assessment/bu_exams_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

void main() {
  group('tổng điểm tối đa — dòng TOTAL của các phiếu điểm BU', () {
    test('Đề I 100 (BU_Exam-I_Score_Sheet.pdf "TOTAL (max = 100)")', () {
      expect(examIDrills.map((d) => d.id).toList(),
          ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8']);
      expect(examIDrills.fold<int>(0, (s, d) => s + d.maxScore), examIMax);
    });

    test('Đề II: Bachelors 54, Masters 77, Doctorate 100', () {
      expect(examIIMax(ExamIIVersion.bachelors), 54);
      expect(examIIMax(ExamIIVersion.masters), 77);
      expect(examIIMax(ExamIIVersion.doctorate), 100);
      for (final v in ExamIIVersion.values) {
        expect(examIIDrills(v).map((d) => d.id).toList(),
            ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10'],
            reason: '$v');
      }
    });

    test('tối đa từng bài theo bảng spec mục 5.2', () {
      int max(ExamIIVersion v, String id) => drillFor(id, v).maxScore;
      const b = ExamIIVersion.bachelors, m = ExamIIVersion.masters, d = ExamIIVersion.doctorate;
      expect([max(b, 'S1'), max(m, 'S1'), max(d, 'S1')], [4, 7, 10]);
      expect([max(b, 'S2'), max(m, 'S2'), max(d, 'S2')], [7, 11, 15]);
      expect([max(b, 'S3'), max(m, 'S3'), max(d, 'S3')], [10, 12, 14]);
      expect([max(b, 'S4'), max(m, 'S4'), max(d, 'S4')], [10, 12, 14]);
      expect([max(b, 'S5'), max(m, 'S5'), max(d, 'S5')], [6, 10, 14]);
      for (final id in ['S6', 'S7', 'S8', 'S9']) {
        expect([max(b, id), max(m, id), max(d, id)], [3, 5, 7], reason: id);
      }
      expect([max(b, 'S10'), max(m, 'S10'), max(d, 'S10')], [5, 5, 5]);
    });

    test('S3/S4 mỗi thế tối đa bằng nửa điểm bài (5 / 6 / 7 bi)', () {
      for (final v in ExamIIVersion.values) {
        for (final id in ['S3', 'S4']) {
          final drill = drillFor(id, v);
          expect(drill.perAttemptMax! * 2, drill.maxScore, reason: '$id $v');
        }
      }
    });

    test('S5: mỗi vị trí bi cái 2 lượt (3 / 5 / 7 vị trí)', () {
      expect(drillFor('S5', ExamIIVersion.bachelors).groups, 3);
      expect(drillFor('S5', ExamIIVersion.masters).groups, 5);
      expect(drillFor('S5', ExamIIVersion.doctorate).groups, 7);
      expect(drillFor('S5', ExamIIVersion.doctorate).attemptsPerGroup, 2);
    });
  });

  group('xong bài và điểm bài', () {
    test('thang vị trí: xong khi đủ 10 cú hoặc đã chắc 10', () {
      final f1 = drillFor('F1', null);
      expect(isDrillComplete(f1, ShotAttempts(List.filled(7, true))), isFalse);
      expect(drillScore(f1, ShotAttempts(List.filled(7, true))), isNull);
      expect(isDrillComplete(f1, ShotAttempts(List.filled(8, true))), isTrue);
      expect(drillScore(f1, ShotAttempts(List.filled(8, true))), 10);
    });

    test('F7: 10 bi đích × 2 lượt = 20 ô', () {
      final f7 = drillFor('F7', null);
      expect(f7.groups, 10);
      expect(isDrillComplete(f7, ShotAttempts(List.filled(19, true))), isFalse);
      expect(drillScore(f7, ShotAttempts(List.filled(20, true))), 20);
    });

    // BU_Exam-II_Score_Sheet-*.pdf: "The 2nd attempt is not required with a
    // perfect score on the 1st attempt." (D3 của kế hoạch)
    test('S1/S2: lượt 1 hoàn hảo thì không cần lượt 2', () {
      final s1 = drillFor('S1', ExamIIVersion.masters);
      expect(isDrillComplete(s1, CountAttempts([7])), isTrue);
      expect(drillScore(s1, CountAttempts([7])), 7);
      expect(isDrillComplete(s1, CountAttempts([6])), isFalse);
      expect(drillScore(s1, CountAttempts([6, 3])), 6);
      expect(attemptsValid(s1, CountAttempts([7, 2])), isFalse,
          reason: 'đã xong thì không nhập thêm');
    });

    test('S3: đủ 3 thế mới có điểm', () {
      final s3 = drillFor('S3', ExamIIVersion.bachelors);
      expect(drillScore(s3, CountAttempts([5, 4])), isNull);
      expect(drillScore(s3, CountAttempts([5, 4, 2])), 6);
    });

    test('S10: đủ 3 lần phá, lấy trung vị', () {
      final s10 = drillFor('S10', ExamIIVersion.doctorate);
      const full = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
      const two = BreakCriteria(a: true, d: true);
      expect(drillScore(s10, BreakAttempts([full, two, full])), 5);
      expect(drillScore(s10, BreakAttempts([full, two])), isNull);
    });
  });

  group('chặn nhập sai từ đầu (spec mục 8)', () {
    test('số bi ngoài 0…tối đa một lượt', () {
      final s3 = drillFor('S3', ExamIIVersion.bachelors);
      expect(attemptsValid(s3, CountAttempts([6])), isFalse);
      expect(attemptsValid(s3, CountAttempts([-1])), isFalse);
      expect(attemptsValid(s3, CountAttempts([5, 0, 5])), isTrue);
    });

    test('quá số lượt hoặc nhập sau khi thang đã chắc 10', () {
      final f6 = drillFor('F6', null);
      expect(attemptsValid(f6, ShotAttempts(List.filled(11, true))), isFalse);
      final f2 = drillFor('F2', null);
      expect(attemptsValid(f2, ShotAttempts(List.filled(9, true))), isFalse,
          reason: 'sau 8 cú vào liền bài đã xong');
    });

    test('sai kiểu kết quả thô', () {
      expect(attemptsValid(drillFor('F1', null), CountAttempts([1])), isFalse);
      expect(() => drillScore(drillFor('F1', null), CountAttempts([1])), throwsArgumentError);
    });

    test('lần phá chết cái mà có đánh dấu b–e thì không hợp lệ', () {
      final s10 = drillFor('S10', ExamIIVersion.bachelors);
      expect(attemptsValid(s10, BreakAttempts([const BreakCriteria(a: false, b: true)])), isFalse);
    });

    test('bài rỗng khớp kiểu của bài', () {
      for (final d in [...examIDrills, ...examIIDrills(ExamIIVersion.masters)]) {
        expect(attemptsValid(d, emptyAttemptsFor(d)), isTrue, reason: d.id);
      }
    });
  });

  test('drillFor: bài Đề II cần bản, mã lạ thì ném', () {
    expect(() => drillFor('S1', null), throwsArgumentError);
    expect(() => drillFor('X1', ExamIIVersion.masters), throwsArgumentError);
  });
}
```

`test/core/strings/vi_assessment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';

void main() {
  test('tên bài đúng thuật ngữ chủ sản phẩm đã chốt (spec mục 5.1, 5.2, 11.3)', () {
    expect(Vi.buDrillName('F2'), 'Đánh đứng bi (Stop Shot)');
    expect(Vi.buDrillName('F3'), 'Đánh cu lê (Follow Shot)');
    expect(Vi.buDrillName('F4'), 'Đánh trô bi (Draw Shot)');
    expect(Vi.buDrillName('F5'), 'Đánh tâm tiến (Stun Shot)');
    expect(Vi.buDrillName('F6'), 'Ăn bi (Ball Pocketing)');
    expect(Vi.buDrillName('S5'), 'Phòng thủ / bắt đui (Safety)');
    expect(Vi.buDrillName('S6'), 'A băng (Kicks)');
    expect(Vi.buDrillName('S7'), 'Cân bi (Banks)');
    expect(Vi.buDrillName('S8'), 'Dựng cơ (Elevated cue)');
    expect(Vi.buDrillName('S9'), 'Nhảy bi (Jump) hoặc Mát xê (Massé)');
    expect(Vi.buDrillName('S10'), 'Phá (Break)');
  });

  test('mọi bài đều có tên, không dùng từ cấm', () {
    final all = [...examIDrills, ...examIIDrills(ExamIIVersion.doctorate)];
    for (final d in all) {
      final name = Vi.buDrillName(d.id).toLowerCase();
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(name, isNot(contains(banned)), reason: d.id);
      }
      expect(Vi.buDrillTitle(d.id), startsWith('${d.id} · '));
    }
  });
}
```

- [ ] **Step 2: Run them to see them fail**

```bash
"$FLUTTER" test test/domain/assessment/bu_exams_test.dart test/core/strings/vi_assessment_test.dart
```

Expected: FAIL — `bu_exams.dart` and the `Vi` members do not exist.

- [ ] **Step 3: Write `bu_exams.dart`**

```dart
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

enum BuExam { fundamentals, skills }

/// Năm kiểu chấm của spec mục 5.3.
enum ScoringKind { positionLadder, successCount, bestOfTwo, sumOfLowestTwo, medianBreak }

/// Một bài của đề BU, đúng như phiếu điểm.
final class BuDrill {
  const BuDrill({
    required this.id,
    required this.kind,
    required this.maxScore,
    required this.attemptCount,
    this.perAttemptMax,
    this.groups = 1,
  });

  /// 'F1'…'F8', 'S1'…'S10'.
  final String id;
  final ScoringKind kind;
  final int maxScore;

  /// Số lượt phải nhập đủ: 10 cú của thang, số ô của bài đếm, 2 lượt, 3 thế,
  /// 3 lần phá. Thang và S1/S2 có thể xong sớm hơn (xem [isDrillComplete]).
  final int attemptCount;

  /// Số bi tối đa một lượt — chỉ bài nhập số bi.
  final int? perAttemptMax;

  /// Bài đếm lượt chia nhóm: F7 10 bi đích × 2, F8 5 đích × 4, S5 n vị trí
  /// bi cái × 2. Bài khác là 1 nhóm.
  final int groups;

  BuExam get exam => id.startsWith('F') ? BuExam.fundamentals : BuExam.skills;
  int get attemptsPerGroup => attemptCount ~/ groups;
}

const _ladder = ScoringKind.positionLadder;

/// Đề I — BU_Exam-I_Score_Sheet.pdf.
const examIDrills = <BuDrill>[
  BuDrill(id: 'F1', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F2', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F3', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F4', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F5', kind: _ladder, maxScore: 10, attemptCount: ladderShotCount),
  BuDrill(id: 'F6', kind: ScoringKind.successCount, maxScore: 10, attemptCount: 10),
  BuDrill(id: 'F7', kind: ScoringKind.successCount, maxScore: 20, attemptCount: 20, groups: 10),
  BuDrill(id: 'F8', kind: ScoringKind.successCount, maxScore: 20, attemptCount: 20, groups: 5),
];

int _by(ExamIIVersion v, int bachelors, int masters, int doctorate) => switch (v) {
      ExamIIVersion.bachelors => bachelors,
      ExamIIVersion.masters => masters,
      ExamIIVersion.doctorate => doctorate,
    };

/// Đề II — BU_Exam-II_Score_Sheet-{Bachelors,Masters,Doctorate}.pdf.
List<BuDrill> examIIDrills(ExamIIVersion v) {
  final line = _by(v, 4, 7, 10);
  final rail = _by(v, 7, 11, 15);
  final pattern = _by(v, 5, 6, 7);
  final positions = _by(v, 3, 5, 7);
  final shots = _by(v, 3, 5, 7);
  return [
    BuDrill(id: 'S1', kind: ScoringKind.bestOfTwo, maxScore: line, attemptCount: 2, perAttemptMax: line),
    BuDrill(id: 'S2', kind: ScoringKind.bestOfTwo, maxScore: rail, attemptCount: 2, perAttemptMax: rail),
    BuDrill(id: 'S3', kind: ScoringKind.sumOfLowestTwo, maxScore: 2 * pattern, attemptCount: 3, perAttemptMax: pattern),
    BuDrill(id: 'S4', kind: ScoringKind.sumOfLowestTwo, maxScore: 2 * pattern, attemptCount: 3, perAttemptMax: pattern),
    BuDrill(id: 'S5', kind: ScoringKind.successCount, maxScore: 2 * positions, attemptCount: 2 * positions, groups: positions),
    for (final id in const ['S6', 'S7', 'S8', 'S9'])
      BuDrill(id: id, kind: ScoringKind.successCount, maxScore: shots, attemptCount: shots, groups: shots),
    const BuDrill(id: 'S10', kind: ScoringKind.medianBreak, maxScore: 5, attemptCount: 3),
  ];
}

int examIIMax(ExamIIVersion v) => examIIDrills(v).fold(0, (s, d) => s + d.maxScore);

/// Bài theo mã. Bài Đề II cần biết bản.
BuDrill drillFor(String id, ExamIIVersion? version) {
  for (final d in examIDrills) {
    if (d.id == id) return d;
  }
  if (version == null) throw ArgumentError.value(id, 'id', 'bài Đề II cần biết bản');
  for (final d in examIIDrills(version)) {
    if (d.id == id) return d;
  }
  throw ArgumentError.value(id, 'id', 'không có bài này');
}

DrillAttempts emptyAttemptsFor(BuDrill d) => switch (d.kind) {
      ScoringKind.positionLadder || ScoringKind.successCount => ShotAttempts(const []),
      ScoringKind.bestOfTwo || ScoringKind.sumOfLowestTwo => CountAttempts(const []),
      ScoringKind.medianBreak => BreakAttempts(const []),
    };

bool _kindMatches(BuDrill d, DrillAttempts a) => switch (a) {
      ShotAttempts() => d.kind == ScoringKind.positionLadder || d.kind == ScoringKind.successCount,
      CountAttempts() => d.kind == ScoringKind.bestOfTwo || d.kind == ScoringKind.sumOfLowestTwo,
      BreakAttempts() => d.kind == ScoringKind.medianBreak,
    };

/// Bài đã đủ lượt để chấm chưa (spec mục 7.3: không chấm khi chưa đủ lượt).
bool isDrillComplete(BuDrill d, DrillAttempts a) {
  if (!_kindMatches(d, a)) {
    throw ArgumentError('Kết quả thô không đúng kiểu chấm của ${d.id}');
  }
  return switch (a) {
    ShotAttempts(:final shots) => d.kind == ScoringKind.positionLadder
        ? ladderSettled(shots)
        : shots.length >= d.attemptCount,
    CountAttempts(:final counts) => d.kind == ScoringKind.bestOfTwo
        ? counts.length >= 2 || (counts.length == 1 && counts.first == d.perAttemptMax)
        : counts.length >= d.attemptCount,
    BreakAttempts(:final breaks) => breaks.length >= d.attemptCount,
  };
}

/// Điểm bài; null khi chưa xong.
int? drillScore(BuDrill d, DrillAttempts a) {
  if (!isDrillComplete(d, a)) return null;
  return switch (a) {
    ShotAttempts(:final shots) =>
      d.kind == ScoringKind.positionLadder ? ladderScore(shots) : successCount(shots),
    CountAttempts(:final counts) =>
      d.kind == ScoringKind.bestOfTwo ? bestOfTwo(counts) : sumOfLowestTwo(counts),
    BreakAttempts(:final breaks) => medianOfThreeBreaks(breaks),
  };
}

/// Kết quả thô này ghi xuống được không: đúng kiểu, số bi trong khoảng,
/// lần phá chết cái không có b–e, và không lượt nào nằm sau lúc bài đã xong.
bool attemptsValid(BuDrill d, DrillAttempts a) {
  if (!_kindMatches(d, a)) return false;
  if (a.length > d.attemptCount) return false;
  switch (a) {
    case CountAttempts(:final counts):
      if (counts.any((c) => c < 0 || c > d.perAttemptMax!)) return false;
    case BreakAttempts(:final breaks):
      if (breaks.any((b) => !b.a && (b.b || b.c || b.d || b.e))) return false;
    case ShotAttempts():
      break;
  }
  var prefix = a;
  final prefixes = <DrillAttempts>[];
  while (!prefix.isEmpty) {
    prefix = prefix.withoutLast();
    prefixes.add(prefix);
  }
  return !prefixes.any((p) => isDrillComplete(d, p));
}
```

- [ ] **Step 4: Add the `Vi` names**

In `lib/core/strings/vi.dart`, add the imports `package:poolcoachai/domain/assessment/bu_exams.dart` and `package:poolcoachai/domain/assessment/bu_placement.dart` (alphabetical with the others), and before the final `}`:

```dart
  // ─── Đánh giá + hạng — tên bài BU (spec mục 5.1, 5.2, 11.3) ───────────────
  //
  // Tên tiếng Việt do chủ sản phẩm chốt ngày 14/10/2026; tên tiếng Anh trong
  // ngoặc là tên bài của Billiard University, để đối chiếu với đề.

  static String buDrillName(String drillId) => switch (drillId) {
        'F1' => 'Cắt góc (Cut Shot)',
        'F2' => 'Đánh đứng bi (Stop Shot)',
        'F3' => 'Đánh cu lê (Follow Shot)',
        'F4' => 'Đánh trô bi (Draw Shot)',
        'F5' => 'Đánh tâm tiến (Stun Shot)',
        'F6' => 'Ăn bi (Ball Pocketing)',
        'F7' => 'Bánh xe (Wagon Wheel)',
        'F8' => 'Lưới đích (Grid Target)',
        'S1' => 'Hàng bi (Line of Balls)',
        'S2' => 'Ngắm bi sát băng (Rail Cuts)',
        'S3' => 'Thế 9 bi (9-Ball Patterns)',
        'S4' => 'Thế 8 bi (8-Ball Patterns)',
        'S5' => 'Phòng thủ / bắt đui (Safety)',
        'S6' => 'A băng (Kicks)',
        'S7' => 'Cân bi (Banks)',
        'S8' => 'Dựng cơ (Elevated cue)',
        'S9' => 'Nhảy bi (Jump) hoặc Mát xê (Massé)',
        'S10' => 'Phá (Break)',
        _ => throw ArgumentError.value(drillId, 'drillId', 'không có bài này'),
      };

  static String buDrillTitle(String drillId) => '$drillId · ${buDrillName(drillId)}';

  static String buExamName(BuExam exam) => switch (exam) {
        BuExam.fundamentals => 'Đề I — Cơ bản',
        BuExam.skills => 'Đề II — Kỹ năng',
      };

  static String buVersionName(ExamIIVersion v) => switch (v) {
        ExamIIVersion.bachelors => 'Bachelors',
        ExamIIVersion.masters => 'Masters',
        ExamIIVersion.doctorate => 'Doctorate',
      };
```

- [ ] **Step 5: Run the tests to see them pass**

```bash
"$FLUTTER" test test/domain/assessment test/core/strings/vi_assessment_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/assessment/bu_exams.dart lib/core/strings/vi.dart test/domain/assessment/bu_exams_test.dart test/core/strings/vi_assessment_test.dart
git commit -m "Define BU Exam I and the three Exam II versions with completion and validation rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The questionnaire and its answer → rank table (spec §11.1, §11.2)

**Files:**
- Modify: `lib/domain/assessment/questionnaire.dart` (append `suggestRank` and the named choice constants after `QuestionnaireAnswers`)
- Modify: `lib/core/strings/vi.dart` (add the import of `package:poolcoachai/domain/rank.dart`, and a section `// Đánh giá + hạng — bộ câu hỏi và mô tả hạng` before the final `}`)
- Test: `test/domain/assessment/questionnaire_test.dart`
- Modify: `test/core/strings/vi_assessment_test.dart` (append tests inside `main`)

**Interfaces:**
- Consumes: `QuestionnaireAnswers`, `questionOptionCounts` (Task 1); `Rank`.
- Produces:
  - `Rank suggestRank(QuestionnaireAnswers answers)`;
  - `Vi.rankQuestion(int question)`, `Vi.rankQuestionOptions(int question)` (1-based), `Vi.rankDescription(Rank rank)`, `Vi.rankGroupName(RankGroup group)`.

- [ ] **Step 1: Write the failing tests**

`test/domain/assessment/questionnaire_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Bảng quy đổi của spec mục 11.2 — một test cho mỗi dòng.
///
/// Chỉ số lựa chọn (từ 0):
///   Q4: 0 "1", 1 "2", 2 "3", 3 "4", 4 "5", 5 "6+", 6 "Thường xuyên Runout".
///   Q5: 0 "Chưa bao giờ", 1 "Đã từng 1–2 lần", 2 "Thỉnh thoảng",
///       3 "Khá thường xuyên", 4 "Rất thường xuyên".
///   Q6: 0 "Chưa từng", 1 "Hơn 100 rack", 2 "Khoảng 50 rack", 3 "Khoảng 20
///       rack", 4 "Khoảng 10 rack", 5 "Khoảng 5 rack", 6 "Khoảng 2–3 rack",
///       7 "Gần như rack nào cũng có thể".
void main() {
  QuestionnaireAnswers a({int q4 = 0, int q5 = 0, int q6 = 0, int other = 0}) =>
      QuestionnaireAnswers([other, other % 5, other, q4, q5, q6, other % 5, other % 5]);

  test('Q5 "Chưa bao giờ" + Q4 = 1 → K', () {
    expect(suggestRank(a(q5: 0, q4: 0)), Rank.k);
  });

  test('Q5 "Chưa bao giờ" + Q4 = 2 → I', () {
    expect(suggestRank(a(q5: 0, q4: 1)), Rank.i);
  });

  test('Q5 "Chưa bao giờ" + Q4 ≥ 3 → H', () {
    for (var q4 = 2; q4 <= 6; q4++) {
      expect(suggestRank(a(q5: 0, q4: q4)), Rank.h, reason: 'Q4 chỉ số $q4');
    }
  });

  test('Q5 "Đã từng 1–2 lần" → H, bất kể Q4 và Q6', () {
    for (var q4 = 0; q4 <= 6; q4++) {
      for (var q6 = 0; q6 <= 7; q6++) {
        expect(suggestRank(a(q5: 1, q4: q4, q6: q6)), Rank.h, reason: 'Q4 $q4, Q6 $q6');
      }
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Chưa từng / Hơn 100 / Khoảng 50 → G', () {
    for (final q5 in [2, 3, 4]) {
      for (final q6 in [0, 1, 2]) {
        expect(suggestRank(a(q5: q5, q6: q6)), Rank.g, reason: 'Q5 $q5, Q6 $q6');
      }
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 20 rack → F', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 3)), Rank.f);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 10 rack → E', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 4)), Rank.e);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 5 rack → D', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 5)), Rank.d);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Khoảng 2–3 rack → C', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 6)), Rank.c);
    }
  });

  test('Q5 "Thỉnh thoảng" trở lên + Q6 Gần như rack nào cũng có thể → B', () {
    for (final q5 in [2, 3, 4]) {
      expect(suggestRank(a(q5: q5, q6: 7)), Rank.b);
    }
  });

  test('không câu trả lời nào dẫn tới A hay PRO', () {
    for (var q4 = 0; q4 < questionOptionCounts[3]; q4++) {
      for (var q5 = 0; q5 < questionOptionCounts[4]; q5++) {
        for (var q6 = 0; q6 < questionOptionCounts[5]; q6++) {
          expect(suggestRank(a(q4: q4, q5: q5, q6: q6)), isNot(anyOf(Rank.a, Rank.pro)));
        }
      }
    }
  });

  test('Q1, Q2, Q3, Q7, Q8 không đổi hạng gợi ý', () {
    for (var other = 0; other <= 4; other++) {
      expect(suggestRank(a(q5: 2, q6: 4, other: other)), Rank.e, reason: 'other $other');
    }
  });
}
```

Append to `test/core/strings/vi_assessment_test.dart`, inside `main`:

```dart
  test('8 câu hỏi, số lựa chọn khớp questionOptionCounts', () {
    for (var q = 1; q <= 8; q++) {
      expect(Vi.rankQuestion(q), isNotEmpty);
      expect(Vi.rankQuestionOptions(q).length, questionOptionCounts[q - 1], reason: 'Q$q');
    }
  });

  test('câu hỏi nguyên văn PoolOS v2 (spec mục 11.2)', () {
    expect(Vi.rankQuestion(5), 'Bạn đã từng Runout (đi chấm) chưa?');
    expect(Vi.rankQuestionOptions(6).last, 'Gần như rack nào cũng có thể');
    expect(Vi.rankQuestionOptions(3).last, 'Dọn bàn (Run Out)');
  });

  test('mỗi hạng có mô tả nguyên văn (spec mục 11.1)', () {
    expect(Vi.rankDescription(Rank.k), 'Người mới làm quen với Pool');
    expect(Vi.rankDescription(Rank.a), 'Top đầu trong nước');
    expect(Vi.rankDescription(Rank.pro), 'Thi đấu chuyên nghiệp');
    for (final r in Rank.values) {
      expect(Vi.rankDescription(r), isNotEmpty);
    }
  });
```

and the imports `package:poolcoachai/domain/assessment/questionnaire.dart` and `package:poolcoachai/domain/rank.dart` at the top of that file.

- [ ] **Step 2: Run them to see them fail**

```bash
"$FLUTTER" test test/domain/assessment/questionnaire_test.dart test/core/strings/vi_assessment_test.dart
```

Expected: FAIL — `suggestRank` and the `Vi` members do not exist.

- [ ] **Step 3: Append `suggestRank` to `questionnaire.dart`**

Add `import 'package:poolcoachai/domain/rank.dart';` at the top, then append:

```dart
// Chỉ số lựa chọn có tên, để hàm dưới đọc được như bảng của spec mục 11.2.
const _q4One = 0;
const _q4Two = 1;
const _q5Never = 0;
const _q5OnceOrTwice = 1;
const _q6TwentyRacks = 3;
const _q6TenRacks = 4;
const _q6FiveRacks = 5;
const _q6TwoThreeRacks = 6;

/// Hạng bộ câu hỏi gợi ý — đúng từng dòng bảng quy đổi spec mục 11.2.
///
/// Chỉ Q4, Q5, Q6 được dùng. A và PRO không bao giờ được gợi ý: chỉ chọn
/// được qua *Chọn hạng khác* (thành tự khai).
Rank suggestRank(QuestionnaireAnswers answers) {
  final q4 = answers.of(4);
  final q5 = answers.of(5);
  final q6 = answers.of(6);
  if (q5 == _q5Never) {
    return switch (q4) {
      _q4One => Rank.k,
      _q4Two => Rank.i,
      _ => Rank.h,
    };
  }
  if (q5 == _q5OnceOrTwice) return Rank.h;
  return switch (q6) {
    _q6TwentyRacks => Rank.f,
    _q6TenRacks => Rank.e,
    _q6FiveRacks => Rank.d,
    _q6TwoThreeRacks => Rank.c,
    > _q6TwoThreeRacks => Rank.b,
    _ => Rank.g,
  };
}
```

- [ ] **Step 4: Add the `Vi` questionnaire and rank descriptions**

Add `import 'package:poolcoachai/domain/rank.dart';` to `vi.dart`, then before the final `}`:

```dart
  // ─── Đánh giá + hạng — bộ câu hỏi và mô tả hạng ────────────────────────────
  //
  // Nguyên văn PoolOS v2 (AppConstants.assessmentQuestions và
  // AppConstants.playerLevels), chủ sản phẩm duyệt ngày 14/10/2026 —
  // spec mục 11.1, 11.2. Không sửa chữ ở đây mà không hỏi chủ sản phẩm.

  static String rankQuestion(int question) => switch (question) {
        1 => 'Bạn đã chơi Pool được bao lâu?',
        2 => 'Trung bình bạn chơi Pool bao nhiêu?',
        3 => 'Trong một lượt cơ, bạn đã từng đi được nhiều nhất bao nhiêu bi?',
        4 => 'Trong những thế bi bình thường, bạn thường đi được bao nhiêu bi?',
        5 => 'Bạn đã từng Runout (đi chấm) chưa?',
        6 => 'Trung bình bao nhiêu rack bạn có thể đi được một chấm?',
        7 => 'Sau cú phá bi, bạn thường còn thế bi như thế nào?',
        8 => 'Sau khi ăn một bi, bạn thường điều bi cái ở mức nào?',
        _ => throw RangeError.range(question, 1, 8, 'question'),
      };

  static List<String> rankQuestionOptions(int question) => switch (question) {
        1 => const ['Chưa từng chơi', 'Dưới 3 tháng', '3 – 6 tháng', '6 tháng – 1 năm',
            '1 – 2 năm', '2 – 5 năm', 'Trên 5 năm'],
        2 => const ['Dưới 2 giờ / tuần', '2 – 5 giờ / tuần', '5 – 10 giờ / tuần',
            '10 – 20 giờ / tuần', 'Trên 20 giờ / tuần'],
        3 => const ['1', '2', '3', '4', '5', '6', '7', '8', 'Dọn bàn (Run Out)'],
        4 => const ['1', '2', '3', '4', '5', '6+', 'Thường xuyên Runout'],
        5 => const ['Chưa bao giờ', 'Đã từng 1–2 lần', 'Thỉnh thoảng',
            'Khá thường xuyên', 'Rất thường xuyên'],
        6 => const ['Chưa từng', 'Hơn 100 rack', 'Khoảng 50 rack', 'Khoảng 20 rack',
            'Khoảng 10 rack', 'Khoảng 5 rack', 'Khoảng 2–3 rack',
            'Gần như rack nào cũng có thể'],
        7 => const ['Thường không có bi đánh tiếp', 'Thường chỉ có 1 bi',
            'Có thể đi tiếp 2–3 bi', 'Thường có layout thuận lợi',
            'Thường có cơ hội đi chấm'],
        8 => const ['Thường xuyên bị khó', 'Có lúc dễ, có lúc khó',
            'Phần lớn còn bi đánh tiếp', 'Thường chủ động điều được bi cái',
            'Có thể điều bi chính xác theo ý muốn'],
        _ => throw RangeError.range(question, 1, 8, 'question'),
      };

  static String rankDescription(Rank rank) => switch (rank) {
        Rank.k => 'Người mới làm quen với Pool',
        Rank.i => 'Đã biết luật chơi, kỹ thuật cơ bản',
        Rank.h => 'Người chơi phong trào phổ biến, bắt đầu có khả năng điều bi',
        Rank.g => 'Người chơi phong trào khá, có thể thi đấu ổn định với đa số CLB',
        Rank.f => 'Bước đầu tham gia sân chơi thi đấu, trình độ cao trong nhóm phong trào',
        Rank.e => 'Người chơi bán chuyên',
        Rank.d => 'Người chơi mạnh, thường xuyên thi đấu',
        Rank.c => 'Vận động viên trình độ cao',
        Rank.b => 'Vận động viên rất mạnh',
        Rank.a => 'Top đầu trong nước',
        Rank.pro => 'Thi đấu chuyên nghiệp',
      };

  static String rankGroupName(RankGroup group) => switch (group) {
        RankGroup.amateur => 'phong trào',
        RankGroup.competitive => 'thi đấu',
        RankGroup.pro => 'chuyên nghiệp',
      };
```

- [ ] **Step 5: Run the tests to see them pass**

```bash
"$FLUTTER" test test/domain/assessment test/core/strings
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/assessment/questionnaire.dart lib/core/strings/vi.dart test/domain/assessment/questionnaire_test.dart test/core/strings/vi_assessment_test.dart
git commit -m "Add the onboarding questions, rank descriptions and the answer to rank table

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: The test life cycle and the 14-day gap, in the domain (spec §5.4, §7.3, Q12)

**Files:**
- Create: `lib/domain/assessment/bu_test.dart`
- Create: `lib/domain/assessment/retest_gate.dart`
- Create: `test/support/assessment_fixtures.dart`
- Test: `test/domain/assessment/bu_test_test.dart`

**Interfaces:**
- Consumes: `TableSize`, `ExamIIVersion`, `placeExamII` (Task 2); `DrillAttempts`, `BreakCriteria` (Task 3); `BuDrill`, `BuExam`, `examIDrills`, `examIIDrills`, `isDrillComplete`, `drillScore`, `emptyAttemptsFor` (Task 4); `Rank`.
- Produces:
  - `final class BuTest { const BuTest({required String id, required DateTime startedAt, required TableSize tableSize, DateTime? completedAt, DateTime? cancelledAt, int? examIScore, ExamIIVersion? examIIVersion, int? examIIScore, int? totalScore, Rank? resultRank}); bool get isActive; bool get isCompleted; bool get isCancelled; }`;
  - `final class TestSnapshot { TestSnapshot({required BuTest test, required Map<String, DrillAttempts> attempts, Map<String, DateTime> touched = const {}}); BuExam get currentExam; List<BuDrill> get currentDrills; DrillAttempts attemptsOf(BuDrill d); BuDrill? get nextDrill; bool get examIReady; bool get examIIReady; bool isEditable(String drillId); int scoreOf(List<BuDrill> drills); int get runningScore; bool get examIIStarted; }`;
  - `const retestGapDays = 14`, `DateTime? retestAvailableFrom(Iterable<BuTest> tests, {String? exceptTestId})`, `bool retestAllowed(Iterable<BuTest> tests, DateTime now, {String? exceptTestId})`;
  - test support: `ShotAttempts ladderPerfect()`, `Map<String, DrillAttempts> examIAttempts({required bool wagonAndTargetMade})`, `Map<String, DrillAttempts> examIIPerfect(ExamIIVersion v)`.

- [ ] **Step 1: Write the fixtures and the failing test**

`test/support/assessment_fixtures.dart`:

```dart
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

/// Tám cú vào liền: thang đã chắc 10, bài xong sớm.
ShotAttempts ladderPerfect() => ShotAttempts(List.filled(8, true));

/// Đề I với F1–F6 trọn điểm (60). [wagonAndTargetMade] = true thì F7, F8
/// cũng trọn (100); false thì trượt hết (60 → Masters trên bàn 9 feet).
Map<String, DrillAttempts> examIAttempts({required bool wagonAndTargetMade}) => {
      for (final id in ['F1', 'F2', 'F3', 'F4', 'F5']) id: ladderPerfect(),
      'F6': ShotAttempts(List.filled(10, true)),
      'F7': ShotAttempts(List.filled(20, wagonAndTargetMade)),
      'F8': ShotAttempts(List.filled(20, wagonAndTargetMade)),
    };

/// Đề II trọn điểm của bản [v].
Map<String, DrillAttempts> examIIPerfect(ExamIIVersion v) {
  const fullBreak = BreakCriteria(a: true, b: true, c: true, d: true, e: true);
  return {
    for (final d in examIIDrills(v))
      d.id: switch (d.kind) {
        ScoringKind.bestOfTwo => CountAttempts([d.perAttemptMax!]),
        ScoringKind.sumOfLowestTwo => CountAttempts(List.filled(3, d.perAttemptMax!)),
        ScoringKind.successCount => ShotAttempts(List.filled(d.attemptCount, true)),
        ScoringKind.medianBreak => BreakAttempts(List.filled(3, fullBreak)),
        ScoringKind.positionLadder => throw StateError('Đề II không có thang vị trí'),
      },
  };
}
```

`test/domain/assessment/bu_test_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';

import '../../support/assessment_fixtures.dart';

void main() {
  final start = DateTime(2026, 10, 14, 9);
  BuTest test0({int? examI, ExamIIVersion? v, DateTime? completed, DateTime? cancelled, String id = 't1'}) =>
      BuTest(
        id: id,
        startedAt: start,
        tableSize: TableSize.nineFootPlus,
        examIScore: examI,
        examIIVersion: v,
        completedAt: completed,
        cancelledAt: cancelled,
      );

  group('TestSnapshot', () {
    test('lần mới: đang ở Đề I, bài kế là F1', () {
      final s = TestSnapshot(test: test0(), attempts: const {});
      expect(s.currentExam, BuExam.fundamentals);
      expect(s.nextDrill!.id, 'F1');
      expect(s.examIReady, isFalse);
      expect(s.runningScore, 0);
    });

    test('đang dở F1 thì bài kế vẫn là F1; F1 xong thì sang F2', () {
      final mid = TestSnapshot(test: test0(), attempts: {'F1': ShotAttempts([true, false])});
      expect(mid.nextDrill!.id, 'F1');
      final done = TestSnapshot(test: test0(), attempts: {'F1': ladderPerfect()});
      expect(done.nextDrill!.id, 'F2');
      expect(done.runningScore, 10);
    });

    test('đủ 8 bài Đề I thì sẵn sàng chấm Đề I, chưa có bài kế', () {
      final s = TestSnapshot(test: test0(), attempts: examIAttempts(wagonAndTargetMade: false));
      expect(s.examIReady, isTrue);
      expect(s.nextDrill, isNull);
      expect(s.scoreOf(examIDrills), 60);
    });

    test('đã có điểm Đề I: sang Đề II đúng bản, Đề I bị khoá', () {
      final s = TestSnapshot(
        test: test0(examI: 60, v: ExamIIVersion.masters),
        attempts: examIAttempts(wagonAndTargetMade: false),
      );
      expect(s.currentExam, BuExam.skills);
      expect(s.nextDrill!.id, 'S1');
      expect(s.isEditable('F8'), isFalse);
      expect(s.isEditable('S1'), isTrue);
      expect(s.examIIStarted, isFalse);
    });

    test('đủ Đề II thì sẵn sàng hoàn tất', () {
      final s = TestSnapshot(
        test: test0(examI: 60, v: ExamIIVersion.masters),
        attempts: {
          ...examIAttempts(wagonAndTargetMade: false),
          ...examIIPerfect(ExamIIVersion.masters),
        },
      );
      expect(s.examIIReady, isTrue);
      expect(s.scoreOf(examIIDrills(ExamIIVersion.masters)), 77);
    });

    test('lần đã hoàn tất hay đã hủy thì không sửa được bài nào', () {
      final done = TestSnapshot(test: test0(completed: start), attempts: const {});
      final gone = TestSnapshot(test: test0(cancelled: start), attempts: const {});
      expect(done.isEditable('F1'), isFalse);
      expect(gone.isEditable('F1'), isFalse);
    });
  });

  group('giãn cách 14 ngày (Q12, D6 của kế hoạch)', () {
    test('chưa hoàn tất lần nào thì làm được ngay', () {
      expect(retestAvailableFrom(const []), isNull);
      expect(retestAllowed(const [], start), isTrue);
    });

    test('ngày kiểm tra lại tính từ ngày hoàn tất, theo nửa đêm', () {
      final done = test0(completed: DateTime(2026, 10, 1, 21));
      expect(retestAvailableFrom([done]), DateTime(2026, 10, 15));
      expect(retestAllowed([done], DateTime(2026, 10, 14, 23, 59)), isFalse);
      expect(retestAllowed([done], DateTime(2026, 10, 15)), isTrue);
    });

    test('lấy lần hoàn tất gần nhất', () {
      final older = test0(id: 'a', completed: DateTime(2026, 9, 1));
      final newer = test0(id: 'b', completed: DateTime(2026, 10, 1));
      expect(retestAvailableFrom([newer, older]), DateTime(2026, 10, 15));
    });

    test('lần bị hủy không tính vào giãn cách', () {
      final cancelled = test0(id: 'c', cancelled: DateTime(2026, 10, 10));
      expect(retestAvailableFrom([cancelled]), isNull);
    });

    test('lần đang làm dở không tính', () {
      expect(retestAvailableFrom([test0()]), isNull);
    });

    test('bỏ qua chính lần đang xét khi hoàn tất', () {
      final self = test0(id: 'me', completed: DateTime(2026, 10, 1));
      expect(retestAvailableFrom([self], exceptTestId: 'me'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
"$FLUTTER" test test/domain/assessment/bu_test_test.dart
```

Expected: FAIL — `bu_test.dart` and `retest_gate.dart` do not exist.

- [ ] **Step 3: Write `bu_test.dart`**

```dart
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Một lần kiểm tra BU = Đề I + Đề II (spec mục 5.4, 6.1).
final class BuTest {
  const BuTest({
    required this.id,
    required this.startedAt,
    required this.tableSize,
    this.completedAt,
    this.cancelledAt,
    this.examIScore,
    this.examIIVersion,
    this.examIIScore,
    this.totalScore,
    this.resultRank,
  });

  final String id;
  final DateTime startedAt;
  final TableSize tableSize;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// Có điểm Đề I nghĩa là Đề I đã chốt và bản Đề II đã được xếp.
  final int? examIScore;
  final ExamIIVersion? examIIVersion;
  final int? examIIScore;
  final int? totalScore;
  final Rank? resultRank;

  bool get isCompleted => completedAt != null;
  bool get isCancelled => cancelledAt != null;
  bool get isActive => !isCompleted && !isCancelled;

  @override
  bool operator ==(Object other) =>
      other is BuTest &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.tableSize == tableSize &&
      other.completedAt == completedAt &&
      other.cancelledAt == cancelledAt &&
      other.examIScore == examIScore &&
      other.examIIVersion == examIIVersion &&
      other.examIIScore == examIIScore &&
      other.totalScore == totalScore &&
      other.resultRank == resultRank;

  @override
  int get hashCode => Object.hash(id, startedAt, tableSize, completedAt, cancelledAt,
      examIScore, examIIVersion, examIIScore, totalScore, resultRank);
}

/// Một lần kiểm tra cùng kết quả thô của từng bài — đủ để màn làm bài biết
/// đang ở đâu sau khi mở lại app (spec mục 6.1).
final class TestSnapshot {
  TestSnapshot({
    required this.test,
    required Map<String, DrillAttempts> attempts,
    Map<String, DateTime> touched = const {},
  })  : attempts = Map.unmodifiable(attempts),
        touched = Map.unmodifiable(touched);

  final BuTest test;
  final Map<String, DrillAttempts> attempts;

  /// Lúc ghi gần nhất của từng bài — để *Hoàn tác* biết cú nào vừa nhập.
  final Map<String, DateTime> touched;

  BuExam get currentExam =>
      test.examIScore == null ? BuExam.fundamentals : BuExam.skills;

  List<BuDrill> get currentDrills => currentExam == BuExam.fundamentals
      ? examIDrills
      : examIIDrills(test.examIIVersion!);

  DrillAttempts attemptsOf(BuDrill d) => attempts[d.id] ?? emptyAttemptsFor(d);

  bool _complete(BuDrill d) => isDrillComplete(d, attemptsOf(d));

  /// Bài đầu tiên chưa xong của đề đang làm; null khi đề đã đủ.
  BuDrill? get nextDrill {
    if (!test.isActive) return null;
    for (final d in currentDrills) {
      if (!_complete(d)) return d;
    }
    return null;
  }

  bool get examIReady =>
      test.isActive && test.examIScore == null && examIDrills.every(_complete);

  bool get examIIReady =>
      test.isActive &&
      test.examIIVersion != null &&
      examIIDrills(test.examIIVersion!).every(_complete);

  /// Bài này còn nhập được không: lần còn đang làm, và đề của bài chưa khoá
  /// (Đề I khoá khi đã có điểm Đề I, để bản Đề II đã xếp không đổi theo).
  bool isEditable(String drillId) {
    if (!test.isActive) return false;
    return drillId.startsWith('F')
        ? test.examIScore == null
        : test.examIIVersion != null;
  }

  /// Đề II đã bắt đầu: có dòng kết quả của một bài S, kể cả dòng đã hoàn
  /// tác về rỗng. Màn làm bài dựa vào đây để thôi hỏi "làm ngay hay để sau".
  bool get examIIStarted => attempts.keys.any((k) => k.startsWith('S'));

  /// Tổng điểm các bài đã xong trong [drills].
  int scoreOf(List<BuDrill> drills) =>
      drills.fold(0, (s, d) => s + (drillScore(d, attemptsOf(d)) ?? 0));

  /// "Điểm hiện tại" của đề đang làm (spec mục 7.3).
  int get runningScore => scoreOf(currentDrills);
}
```

- [ ] **Step 4: Write `retest_gate.dart`**

```dart
import 'package:poolcoachai/domain/assessment/bu_test.dart';

/// Hai lần hoàn tất cách nhau tối thiểu 14 ngày — quy định của app, không
/// phải luật BU (spec Q12).
const retestGapDays = 14;

/// Ngày sớm nhất được làm (và được hoàn tất) lần kế tiếp: nửa đêm của ngày
/// thứ 14 sau lần hoàn tất gần nhất. Lần bị hủy và lần đang dở không tính.
DateTime? retestAvailableFrom(Iterable<BuTest> tests, {String? exceptTestId}) {
  DateTime? last;
  for (final t in tests) {
    final done = t.completedAt;
    if (done == null || t.isCancelled || t.id == exceptTestId) continue;
    if (last == null || done.isAfter(last)) last = done;
  }
  if (last == null) return null;
  return DateTime(last.year, last.month, last.day + retestGapDays);
}

bool retestAllowed(Iterable<BuTest> tests, DateTime now, {String? exceptTestId}) {
  final from = retestAvailableFrom(tests, exceptTestId: exceptTestId);
  return from == null || !now.isBefore(from);
}
```

- [ ] **Step 5: Run it to see it pass**

```bash
"$FLUTTER" test test/domain/assessment
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/assessment/bu_test.dart lib/domain/assessment/retest_gate.dart test/support/assessment_fixtures.dart test/domain/assessment/bu_test_test.dart
git commit -m "Track a BU test's progress and the 14-day gap between completed tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Drift schema 3 — three add-only tables (spec §6.1)

**Files:**
- Modify: `lib/data/database/database.dart` (three table classes after `AuthSessionRows` at lines 81–92; the `@DriftDatabase` list at lines 96–103; `schemaVersion` at line 111; `onUpgrade` at lines 118–126)
- Regenerate: `lib/data/database/database.g.dart`
- Modify: `test/data/database/migration_test.dart` (append a second test inside `main`, after the one ending at line 37)

**Interfaces:**
- Consumes: nothing new.
- Produces: tables `PlayerRankRows` (`player_rank_rows`), `BuTestRows` (`bu_test_rows`), `BuDrillResultRows` (`bu_drill_result_rows`); data classes `PlayerRankRow`, `BuTestRow`, `BuDrillResultRow` and their companions; `AppDatabase.schemaVersion == 3`.

- [ ] **Step 1: Write the failing migration test**

Append inside `main` of `test/data/database/migration_test.dart`:

```dart
  test('nâng từ v2 lên v3 thì có ba bảng hạng/kiểm tra và giữ nguyên buổi tập',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(
        'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
        'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
        'attempts INTEGER NULL, notes TEXT NULL, user_id TEXT NOT NULL, '
        'synced_at INTEGER NULL);',
      );
      raw.execute(
        "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1760400000, 7.0, 10, NULL, 'u1', NULL);",
      );
      raw.execute('PRAGMA user_version = 2;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 3);
    expect((await db.select(db.drillLogRows).get()).single.id, 'cu');

    final at = DateTime(2026, 10, 14, 9);
    await db.into(db.playerRankRows).insert(PlayerRankRowsCompanion.insert(
          userId: 'u1',
          onboardingState: 'skipped',
          updatedAt: at,
        ));
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 't1',
          userId: 'u1',
          startedAt: at,
          tableSize: 'nineFootPlus',
        ));
    await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
          id: 'r1',
          testId: 't1',
          drillId: 'F1',
          attempts: '{"shots":[true]}',
          recordedAt: at,
        ));

    final rank = (await db.select(db.playerRankRows).get()).single;
    expect(rank.rank, isNull);
    expect(rank.syncedAt, isNull);
    final result = (await db.select(db.buDrillResultRows).get()).single;
    expect(result.score, isNull, reason: 'điểm bài null tới khi bài xong (D8)');

    // Một bài chỉ có một dòng kết quả trong một lần kiểm tra.
    await expectLater(
      db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
            id: 'r2',
            testId: 't1',
            drillId: 'F1',
            attempts: '{"shots":[]}',
            recordedAt: at,
          )),
      throwsA(isA<Exception>()), // SqliteException: vi phạm khoá duy nhất
    );
  });
```

- [ ] **Step 2: Run it to see it fail**

```bash
"$FLUTTER" test test/data/database/migration_test.dart
```

Expected: FAIL to compile — `playerRankRows` and the companions do not exist.

- [ ] **Step 3: Add the tables**

In `lib/data/database/database.dart`, after `AuthSessionRows` (line 92) and before `// ─── Database ───`:

```dart
// ─── Đánh giá + hạng (spec 2026-10-14 mục 6.1) ─────────────────────────────

/// Hạng của một tài khoản — mỗi tài khoản một dòng.
class PlayerRankRows extends Table {
  TextColumn get userId => text()();

  /// `Rank.name`; null cùng [source] khi chưa có hạng (đã bấm Để sau).
  TextColumn get rank => text().nullable()();

  /// `RankSource.name`.
  TextColumn get source => text().nullable()();
  IntColumn get buScore => integer().nullable()();
  TextColumn get testId => text().nullable()();
  TextColumn get warningRank => text().nullable()();
  TextColumn get warningTestId => text().nullable()();

  /// JSON `List<int>` — chỉ số lựa chọn của Q1…Q8.
  TextColumn get questionnaireAnswers => text().nullable()();

  /// `OnboardingState.name`.
  TextColumn get onboardingState => text()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Null nghĩa là bản trên máy chưa lên server.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Một lần kiểm tra BU (Đề I + Đề II).
class BuTestRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();

  /// `TableSize.name`.
  TextColumn get tableSize => text()();
  IntColumn get examIScore => integer().nullable()();

  /// `ExamIIVersion.name`.
  TextColumn get examIIVersion => text().nullable()();
  IntColumn get examIIScore => integer().nullable()();
  IntColumn get totalScore => integer().nullable()();

  /// `Rank.name` quy đổi từ tổng điểm.
  TextColumn get resultRank => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kết quả thô của một bài trong một lần kiểm tra. Ghi lại sau mỗi cú, nên
/// đóng app giữa chừng vẫn làm tiếp được.
class BuDrillResultRows extends Table {
  TextColumn get id => text()();
  TextColumn get testId => text()();

  /// 'F1'…'S10'.
  TextColumn get drillId => text()();

  /// JSON của `DrillAttempts` — kết quả thô từng cú.
  TextColumn get attempts => text()();

  /// Điểm bài; null tới khi bài đủ lượt.
  IntColumn get score => integer().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {testId, drillId},
      ];
}
```

Add the three tables to the `@DriftDatabase(tables: [...])` list after `AuthSessionRows`. Change `schemaVersion` to `3`. Append to `onUpgrade`, after the `if (from < 2) { … }` block:

```dart
          if (from < 3) {
            // Chỉ thêm bảng: không đụng dữ liệu cũ (spec mục 6.1).
            await m.createTable(playerRankRows);
            await m.createTable(buTestRows);
            await m.createTable(buDrillResultRows);
          }
```

- [ ] **Step 4: Regenerate and run**

```bash
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" test test/data/database
```

Expected: PASS, including the old v1 → v2 test (it now also runs the `from < 3` block).

- [ ] **Step 5: Commit**

```bash
git add lib/data/database/database.dart lib/data/database/database.g.dart test/data/database/migration_test.dart
git commit -m "Add the rank, BU test and drill result tables in Drift schema 3

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `AssessmentRepository` — every shot to Drift first (spec §6.1, §7.3, §4.2)

**Files:**
- Create: `lib/data/database/assessment_converters.dart` (row ↔ domain part; Task 9 appends the remote part)
- Create: `lib/data/repositories/assessment_repository.dart`
- Create: `lib/core/providers/assessment_providers.dart` (repository and stream providers; Tasks 9 and 13 append)
- Modify: `lib/data/sync/account_actions.dart` (`signOutAndForget` at lines 49–56; append `pendingAssessmentCount`, `hasActiveTest`)
- Modify: `test/support/test_data.dart` (`testContainer` at lines 45–64)
- Test: `test/data/repositories/assessment_repository_test.dart`
- Modify: `test/data/sync/account_actions_test.dart` (append tests)
- Test: `test/core/providers/assessment_providers_test.dart`

**Interfaces:**
- Consumes: everything in `lib/domain/assessment/` so far; `AppDatabase` tables (Task 7); `currentUserIdProvider`, `appDatabaseProvider`, `nowProvider`.
- Produces:
  - converters: `PlayerRank toPlayerRank(PlayerRankRow r)`, `PlayerRankRowsCompanion toPlayerRankRow(PlayerRank p, {required String userId, DateTime? syncedAt})`, `BuTest toBuTest(BuTestRow r)`, `DrillAttempts attemptsOfRow(BuDrillResultRow r)`;
  - `sealed class StartOutcome` = `TestStarted(String testId)` | `TestAlreadyActive(String testId)` | `RetestTooSoon(DateTime from)`;
  - `sealed class CompleteOutcome` = `TestCompleted({required RankOutcome outcome, required Rank result, required int total, required Rank? before})` | `CompletionTooSoon(DateTime from)`;
  - `class AssessmentRepository { AssessmentRepository(AppDatabase db, {required String userId, required DateTime Function() now, required String Function() newId}); Stream<PlayerRank?> watchRank(); Future<void> saveQuestionnaire({required Rank chosen, required Rank suggested, required QuestionnaireAnswers answers}); Future<void> skipOnboarding(); Stream<List<BuTest>> watchTests(); Stream<TestSnapshot?> watchActiveTest(); Stream<TestSnapshot?> watchTest(String testId); Future<StartOutcome> startTest(TableSize size); Future<void> recordAttempts(String testId, String drillId, DrillAttempts attempts); Future<String?> undoLastShot(String testId); Future<ExamIIVersion> finishExamI(String testId); Future<CompleteOutcome> completeTest(String testId); Future<void> cancelTest(String testId); }`;
  - `Future<int> pendingAssessmentCount(AppDatabase db, String userId)`, `Future<bool> hasActiveTest(AppDatabase db, String userId)`;
  - providers: `assessmentRepositoryProvider` (`Provider<AssessmentRepository?>`), `playerRankProvider` (`StreamProvider<PlayerRank?>`), `buTestsProvider` (`StreamProvider<List<BuTest>>`), `activeTestProvider` (`StreamProvider<TestSnapshot?>`), `testSnapshotProvider` (`StreamProvider.family<TestSnapshot?, String>`);
  - `testContainer({..., PlayerRank? rank, List<BuTest>? tests, TestSnapshot? activeTest})`.

- [ ] **Step 1: Write the failing repository test**

`test/data/repositories/assessment_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/assessment_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  var ids = 0;

  AssessmentRepository repo({String userId = 'u1'}) => AssessmentRepository(db,
      userId: userId, now: () => clock, newId: () => 'id${++ids}');

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = DateTime(2026, 10, 14, 9);
    ids = 0;
  });
  tearDown(() => db.close());

  final answers = QuestionnaireAnswers([2, 1, 3, 2, 1, 0, 1, 1]);

  Future<String> startedTest(AssessmentRepository r, {TableSize size = TableSize.nineFootPlus}) async =>
      (await r.startTest(size) as TestStarted).testId;

  Future<void> record(AssessmentRepository r, String testId, Map<String, DrillAttempts> all) async {
    for (final e in all.entries) {
      await r.recordAttempts(testId, e.key, e.value);
    }
  }

  /// Đề I 60 → Masters (bàn 9 feet), Đề II trọn 77 → 137 → D.
  Future<String> completedTest(AssessmentRepository r) async {
    final id = await startedTest(r);
    await record(r, id, examIAttempts(wagonAndTargetMade: false));
    await r.finishExamI(id);
    await record(r, id, examIIPerfect(ExamIIVersion.masters));
    final out = await r.completeTest(id);
    expect(out, isA<TestCompleted>());
    return id;
  }

  group('hạng', () {
    test('chưa có gì thì không có dòng hạng', () async {
      expect(await repo().watchRank().first, isNull);
    });

    test('bộ câu hỏi ghi hạng ước lượng, chưa đồng bộ', () async {
      await repo().saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final r = await repo().watchRank().first;
      expect(r!.rank, Rank.h);
      expect(r.source, RankSource.estimated);
      final row = await db.select(db.playerRankRows).getSingle();
      expect(row.syncedAt, isNull);
    });

    test('Để sau ghi trạng thái bỏ qua; bấm lần nữa khi đã có hạng thì không đổi', () async {
      final r = repo();
      await r.skipOnboarding();
      expect((await r.watchRank().first)!.onboardingState, OnboardingState.skipped);
      await r.saveQuestionnaire(chosen: Rank.g, suggested: Rank.g, answers: answers);
      clock = clock.add(const Duration(days: 1));
      await r.skipOnboarding();
      final after = await r.watchRank().first;
      expect(after!.rank, Rank.g);
      expect(after.updatedAt, DateTime(2026, 10, 14, 9));
    });

    test('ghi lại hạng thì xoá dấu đã đồng bộ', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      await (db.update(db.playerRankRows)).write(PlayerRankRowsCompanion(syncedAt: Value(clock)));
      await r.saveQuestionnaire(chosen: Rank.g, suggested: Rank.h, answers: answers);
      expect((await db.select(db.playerRankRows).getSingle()).syncedAt, isNull);
    });

    test('mỗi người chỉ thấy hạng của mình', () async {
      await repo(userId: 'u2').saveQuestionnaire(chosen: Rank.c, suggested: Rank.c, answers: answers);
      expect(await repo().watchRank().first, isNull);
    });
  });

  group('làm bài', () {
    test('bắt đầu một lần; đang có lần dở thì không mở lần thứ hai', () async {
      final r = repo();
      final id = await startedTest(r);
      final again = await r.startTest(TableSize.eightFoot);
      expect(again, isA<TestAlreadyActive>());
      expect((again as TestAlreadyActive).testId, id);
    });

    test('đóng app giữa bài: mở lại vẫn còn đủ cú đã nhập, hạng không đổi', () async {
      final first = repo();
      await first.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(first);
      var f1 = ShotAttempts(const []);
      for (final made in [true, false, true]) {
        f1 = f1.add(made);
        await first.recordAttempts(id, 'F1', f1);
      }

      // "Mở lại app": repository mới trên cùng DB.
      final reopened = repo();
      final snap = await reopened.watchActiveTest().first;
      expect(snap!.test.id, id);
      expect((snap.attempts['F1']! as ShotAttempts).shots, [true, false, true]);
      expect(snap.nextDrill!.id, 'F1');
      expect((await reopened.watchRank().first)!.rank, Rank.h);
    });

    test('kết quả thô sai thì không ghi', () async {
      final r = repo();
      final id = await startedTest(r);
      await expectLater(r.recordAttempts(id, 'F1', CountAttempts([1])), throwsArgumentError);
      await expectLater(r.recordAttempts(id, 'F6', ShotAttempts(List.filled(11, true))), throwsArgumentError);
      expect(await db.select(db.buDrillResultRows).get(), isEmpty);
    });

    test('Hoàn tác bỏ cú vừa nhập, kể cả cú cuối của bài trước', () async {
      final r = repo();
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F1');
      var snap = await r.watchActiveTest().first;
      expect(snap!.attempts['F1']!.length, 7);
      expect(snap.nextDrill!.id, 'F1');

      clock = clock.add(const Duration(seconds: 1));
      await r.recordAttempts(id, 'F1', ladderPerfect());
      clock = clock.add(const Duration(seconds: 1));
      await r.recordAttempts(id, 'F2', ShotAttempts([true]));
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F2');
      clock = clock.add(const Duration(seconds: 1));
      expect(await r.undoLastShot(id), 'F1', reason: 'F2 đã rỗng thì lùi về F1');
      snap = await r.watchActiveTest().first;
      expect(snap!.attempts['F1']!.length, 7);
    });

    test('chốt Đề I: xếp bản Đề II, khoá Đề I; bàn 8 feet đạt 100 thì Masters', () async {
      final r = repo();
      final id = await startedTest(r, size: TableSize.eightFoot);
      await record(r, id, examIAttempts(wagonAndTargetMade: true));
      expect(await r.finishExamI(id), ExamIIVersion.masters);
      final snap = await r.watchActiveTest().first;
      expect(snap!.test.examIScore, 100);
      await expectLater(r.recordAttempts(id, 'F8', ShotAttempts(const [])), throwsStateError);
      expect(await r.undoLastShot(id), isNull, reason: 'Đề I đã khoá, Đề II chưa có cú nào');
    });

    test('chưa đủ Đề I thì không chốt được', () async {
      final r = repo();
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      await expectLater(r.finishExamI(id), throwsStateError);
    });
  });

  group('hoàn tất và hạng', () {
    test('hoàn tất: tổng điểm, hạng quy đổi, lên hạng đã kiểm chứng', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      await record(r, id, examIIPerfect(ExamIIVersion.masters));
      final out = await r.completeTest(id) as TestCompleted;
      expect(out.total, 137);
      expect(out.result, Rank.d);
      expect(out.outcome, RankOutcome.promoted);
      expect(out.before, Rank.h);
      final rank = await r.watchRank().first;
      expect(rank!.rank, Rank.d);
      expect(rank.source, RankSource.verified);
      expect(rank.testId, id);
      final row = await (db.select(db.buTestRows)..where((t) => t.id.equals(id))).getSingle();
      expect(row.completedAt, clock);
      expect(row.totalScore, 137);
      expect(row.resultRank, 'd');
      expect(await r.watchActiveTest().first, isNull);
    });

    test('chưa đủ Đề II thì không hoàn tất được', () async {
      final r = repo();
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      await expectLater(r.completeTest(id), throwsStateError);
    });

    test('Đề II để sang buổi khác: hoàn tất được, ngày kiểm tra lại tính từ ngày làm Đề II', () async {
      final r = repo();
      final id = await startedTest(r);
      await record(r, id, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(id);
      clock = DateTime(2026, 11, 20, 19); // 37 ngày sau mới làm Đề II
      await record(r, id, examIIPerfect(ExamIIVersion.masters));
      expect(await r.completeTest(id), isA<TestCompleted>());
      clock = DateTime(2026, 12, 3, 23);
      expect(await r.startTest(TableSize.nineFootPlus), isA<RetestTooSoon>());
      clock = DateTime(2026, 12, 4);
      expect(await r.startTest(TableSize.nineFootPlus), isA<TestStarted>());
    });

    test('chưa đủ 14 ngày thì không bắt đầu lần mới, báo ngày được làm', () async {
      final r = repo();
      await completedTest(r);
      clock = DateTime(2026, 10, 20);
      final out = await r.startTest(TableSize.nineFootPlus);
      expect((out as RetestTooSoon).from, DateTime(2026, 10, 28));
    });

    test('lần làm dở trên máy khác hoàn tất trong 14 ngày thì bị chặn tới ngày được phép', () async {
      final r = repo();
      // Lần B bắt đầu 28/9 trên máy này; lần A (bắt đầu trên máy khác) hoàn
      // tất 1/10 rồi được kéo về máy này.
      clock = DateTime(2026, 9, 28, 9);
      final b = await startedTest(r);
      await record(r, b, examIAttempts(wagonAndTargetMade: false));
      await r.finishExamI(b);
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
            id: 'tA',
            userId: 'u1',
            startedAt: DateTime(2026, 9, 30),
            tableSize: 'nineFootPlus',
            completedAt: Value(DateTime(2026, 10, 1)),
            totalScore: const Value(80),
            resultRank: const Value('g'),
          ));
      clock = DateTime(2026, 10, 5);
      await record(r, b, examIIPerfect(ExamIIVersion.masters));
      final out = await r.completeTest(b);
      expect((out as CompletionTooSoon).from, DateTime(2026, 10, 15));
      expect(await r.watchRank().first, isNull, reason: 'lần chưa hoàn tất không đổi hạng');
      clock = DateTime(2026, 10, 15);
      expect(await r.completeTest(b), isA<TestCompleted>());
    });

    test('kết quả thấp hơn: giữ hạng, đặt cảnh báo', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.b, suggested: Rank.c, answers: answers);
      await completedTest(r);
      final rank = await r.watchRank().first;
      expect(rank!.rank, Rank.b);
      expect(rank.source, RankSource.selfDeclared);
      expect(rank.warningRank, Rank.d);
    });
  });

  group('hủy', () {
    test('hủy rồi bắt đầu lại được ngay, hạng không đổi', () async {
      final r = repo();
      await r.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h, answers: answers);
      final id = await startedTest(r);
      await r.recordAttempts(id, 'F1', ladderPerfect());
      await r.cancelTest(id);
      expect(await r.watchActiveTest().first, isNull);
      await expectLater(r.recordAttempts(id, 'F2', ShotAttempts([true])), throwsStateError);
      expect(await r.startTest(TableSize.nineFootPlus), isA<TestStarted>());
      expect((await r.watchRank().first)!.rank, Rank.h);
      final tests = await r.watchTests().first;
      expect(tests.where((t) => t.isCancelled), hasLength(1));
    });

    test('lần đã hoàn tất không hủy được', () async {
      final r = repo();
      final id = await completedTest(r);
      await r.cancelTest(id);
      final row = await (db.select(db.buTestRows)..where((t) => t.id.equals(id))).getSingle();
      expect(row.cancelledAt, isNull);
    });
  });

  test('lịch sử: mới nhất trước, chỉ của người đang đăng nhập', () async {
    final r = repo();
    final a = await completedTest(r);
    clock = DateTime(2026, 11, 1);
    final b = await startedTest(r);
    await startedTest(repo(userId: 'u2'));
    final tests = await r.watchTests().first;
    expect(tests.map((t) => t.id).toList(), [b, a]);
  });
}
```

Add `import 'package:drift/drift.dart' show Value;` to the imports.

- [ ] **Step 2: Run it to see it fail**

```bash
"$FLUTTER" test test/data/repositories/assessment_repository_test.dart
```

Expected: FAIL — `assessment_repository.dart` does not exist.

- [ ] **Step 3: Write `assessment_converters.dart` (row ↔ domain)**

```dart
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

// Tên enum lạ thì byName ném — hàng hỏng phải ồn ào ngay lúc đọc, như
// _parseCategory của converters.dart.

Rank? _rank(String? name) => name == null ? null : Rank.values.byName(name);

PlayerRank toPlayerRank(PlayerRankRow r) => PlayerRank(
      rank: _rank(r.rank),
      source: r.source == null ? null : RankSource.values.byName(r.source!),
      buScore: r.buScore,
      testId: r.testId,
      warningRank: _rank(r.warningRank),
      warningTestId: r.warningTestId,
      answers: r.questionnaireAnswers == null
          ? null
          : QuestionnaireAnswers.fromJson(jsonDecode(r.questionnaireAnswers!)),
      onboardingState: OnboardingState.values.byName(r.onboardingState),
      updatedAt: r.updatedAt,
    );

/// Mọi cột đều đặt rõ, kể cả null: ghi đè dòng cũ thì cột vắng mặt sẽ giữ
/// giá trị cũ — `syncedAt` cũ còn đó là dòng mới bị coi như đã đồng bộ.
PlayerRankRowsCompanion toPlayerRankRow(PlayerRank p,
        {required String userId, DateTime? syncedAt}) =>
    PlayerRankRowsCompanion(
      userId: drift.Value(userId),
      rank: drift.Value(p.rank?.name),
      source: drift.Value(p.source?.name),
      buScore: drift.Value(p.buScore),
      testId: drift.Value(p.testId),
      warningRank: drift.Value(p.warningRank?.name),
      warningTestId: drift.Value(p.warningTestId),
      questionnaireAnswers:
          drift.Value(p.answers == null ? null : jsonEncode(p.answers!.toJson())),
      onboardingState: drift.Value(p.onboardingState.name),
      updatedAt: drift.Value(p.updatedAt),
      syncedAt: drift.Value(syncedAt),
    );

BuTest toBuTest(BuTestRow r) => BuTest(
      id: r.id,
      startedAt: r.startedAt,
      tableSize: TableSize.values.byName(r.tableSize),
      completedAt: r.completedAt,
      cancelledAt: r.cancelledAt,
      examIScore: r.examIScore,
      examIIVersion:
          r.examIIVersion == null ? null : ExamIIVersion.values.byName(r.examIIVersion!),
      examIIScore: r.examIIScore,
      totalScore: r.totalScore,
      resultRank: _rank(r.resultRank),
    );

DrillAttempts attemptsOfRow(BuDrillResultRow r) =>
    DrillAttempts.fromJson(jsonDecode(r.attempts));
```

- [ ] **Step 4: Write `assessment_repository.dart`**

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/domain/rank.dart';

sealed class StartOutcome {
  const StartOutcome();
}

final class TestStarted extends StartOutcome {
  const TestStarted(this.testId);
  final String testId;
}

final class TestAlreadyActive extends StartOutcome {
  const TestAlreadyActive(this.testId);
  final String testId;
}

final class RetestTooSoon extends StartOutcome {
  const RetestTooSoon(this.from);
  final DateTime from;
}

sealed class CompleteOutcome {
  const CompleteOutcome();
}

final class TestCompleted extends CompleteOutcome {
  const TestCompleted({
    required this.outcome,
    required this.result,
    required this.total,
    required this.before,
  });
  final RankOutcome outcome;
  final Rank result;
  final int total;
  final Rank? before;
}

final class CompletionTooSoon extends CompleteOutcome {
  const CompletionTooSoon(this.from);
  final DateTime from;
}

/// Hạng và bài kiểm tra BU của một người chơi trên máy này.
///
/// Mọi thứ ghi xuống Drift trước, đồng bộ sau (spec mục 8). Lần kiểm tra
/// chưa hoàn tất không bao giờ chạm vào hạng (spec mục 6.1).
class AssessmentRepository {
  AssessmentRepository(
    this._db, {
    required String userId,
    required DateTime Function() now,
    required String Function() newId,
  })  : _userId = userId,
        _now = now,
        _newId = newId;

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  // ─── Hạng ──────────────────────────────────────────────────────────────

  SimpleSelectStatement<$PlayerRankRowsTable, PlayerRankRow> _rankQuery() =>
      _db.select(_db.playerRankRows)..where((t) => t.userId.equals(_userId));

  Stream<PlayerRank?> watchRank() =>
      _rankQuery().watchSingleOrNull().map((r) => r == null ? null : toPlayerRank(r));

  Future<PlayerRank?> _rank() async {
    final r = await _rankQuery().getSingleOrNull();
    return r == null ? null : toPlayerRank(r);
  }

  /// Ghi với `syncedAt` rỗng; bên đồng bộ tự thấy và đẩy lên.
  Future<void> _writeRank(PlayerRank rank) => _db
      .into(_db.playerRankRows)
      .insertOnConflictUpdate(toPlayerRankRow(rank, userId: _userId));

  Future<void> saveQuestionnaire({
    required Rank chosen,
    required Rank suggested,
    required QuestionnaireAnswers answers,
  }) =>
      _db.transaction(() async {
        await _writeRank(rankFromQuestionnaire(await _rank(),
            chosen: chosen, suggested: suggested, answers: answers, now: _now()));
      });

  Future<void> skipOnboarding() => _db.transaction(() async {
        final current = await _rank();
        final next = rankAfterSkip(current, _now());
        if (!identical(next, current)) await _writeRank(next);
      });

  // ─── Bài kiểm tra ──────────────────────────────────────────────────────

  Stream<List<BuTest>> watchTests() => (_db.select(_db.buTestRows)
        ..where((t) => t.userId.equals(_userId))
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch()
      .map((rows) => rows.map(toBuTest).toList());

  Future<List<BuTest>> _tests() async =>
      (await (_db.select(_db.buTestRows)..where((t) => t.userId.equals(_userId))).get())
          .map(toBuTest)
          .toList();

  /// Một lần kiểm tra cùng mọi dòng kết quả của nó: một truy vấn nối hai
  /// bảng, nên ghi vào bảng nào thì stream cũng bắn lại.
  JoinedSelectStatement<$BuTestRowsTable, BuTestRow> _snapshotQuery(
          Expression<bool> Function($BuTestRowsTable t) filter) =>
      _db.select(_db.buTestRows).join([
        leftOuterJoin(_db.buDrillResultRows,
            _db.buDrillResultRows.testId.equalsExp(_db.buTestRows.id)),
      ])
        ..where(_db.buTestRows.userId.equals(_userId) & filter(_db.buTestRows));

  TestSnapshot? _toSnapshot(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    final test = rows.first.readTable(_db.buTestRows);
    final results = [
      for (final r in rows)
        if (r.readTableOrNull(_db.buDrillResultRows) case final result?) result,
    ];
    return TestSnapshot(
      test: toBuTest(test),
      attempts: {for (final r in results) r.drillId: attemptsOfRow(r)},
      touched: {for (final r in results) r.drillId: r.recordedAt},
    );
  }

  /// Lần đang làm (chưa hoàn tất, chưa hủy) — mỗi người tối đa một lần.
  Stream<TestSnapshot?> watchActiveTest() => _snapshotQuery(
          (t) => t.completedAt.isNull() & t.cancelledAt.isNull())
      .watch()
      .map(_toSnapshot);

  Stream<TestSnapshot?> watchTest(String testId) =>
      _snapshotQuery((t) => t.id.equals(testId)).watch().map(_toSnapshot);

  /// Đọc một lần bằng `get()` — chạy được trong transaction, không như stream.
  Future<TestSnapshot> _snapshot(String testId) async {
    final snap =
        _toSnapshot(await _snapshotQuery((t) => t.id.equals(testId)).get());
    if (snap == null) throw StateError('Không có lần kiểm tra $testId');
    return snap;
  }

  Future<StartOutcome> startTest(TableSize size) => _db.transaction(() async {
        final tests = await _tests();
        for (final t in tests) {
          if (t.isActive) return TestAlreadyActive(t.id);
        }
        final from = retestAvailableFrom(tests);
        if (from != null && _now().isBefore(from)) return RetestTooSoon(from);
        final id = _newId();
        await _db.into(_db.buTestRows).insert(BuTestRowsCompanion.insert(
              id: id,
              userId: _userId,
              startedAt: _now(),
              tableSize: size.name,
            ));
        return TestStarted(id);
      });

  Future<void> _writeAttempts(TestSnapshot snap, BuDrill drill, DrillAttempts attempts) async {
    final existing = await (_db.select(_db.buDrillResultRows)
          ..where((r) => r.testId.equals(snap.test.id) & r.drillId.equals(drill.id)))
        .getSingleOrNull();
    await _db.into(_db.buDrillResultRows).insertOnConflictUpdate(BuDrillResultRowsCompanion(
          id: Value(existing?.id ?? _newId()),
          testId: Value(snap.test.id),
          drillId: Value(drill.id),
          attempts: Value(jsonEncode(attempts.toJson())),
          score: Value(drillScore(drill, attempts)),
          recordedAt: Value(_now()),
          syncedAt: const Value(null),
        ));
  }

  /// Ghi toàn bộ kết quả thô hiện tại của một bài — gọi sau **mỗi** cú.
  Future<void> recordAttempts(String testId, String drillId, DrillAttempts attempts) =>
      _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.isEditable(drillId)) {
          throw StateError('Bài $drillId của lần $testId không còn sửa được');
        }
        final drill = drillFor(drillId, snap.test.examIIVersion);
        if (!attemptsValid(drill, attempts)) {
          throw ArgumentError.value(attempts, 'attempts', 'không hợp lệ cho $drillId');
        }
        await _writeAttempts(snap, drill, attempts);
      });

  /// Bỏ cú nhập gần nhất trong đề chưa khoá. Trả mã bài vừa hoàn tác, hoặc
  /// null khi không còn gì để hoàn tác. Hoà giờ thì bài đứng sau thắng.
  Future<String?> undoLastShot(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        final order = [
          ...examIDrills,
          if (snap.test.examIIVersion != null) ...examIIDrills(snap.test.examIIVersion!),
        ];
        BuDrill? last;
        for (final d in order) {
          final a = snap.attempts[d.id];
          if (a == null || a.isEmpty || !snap.isEditable(d.id)) continue;
          if (last == null || !snap.touched[d.id]!.isBefore(snap.touched[last.id]!)) last = d;
        }
        if (last == null) return null;
        await _writeAttempts(snap, last, snap.attempts[last.id]!.withoutLast());
        return last.id;
      });

  /// Chốt Đề I: điểm Đề I và bản Đề II (spec mục 5.4).
  Future<ExamIIVersion> finishExamI(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.examIReady) throw StateError('Đề I chưa đủ bài');
        final score = snap.scoreOf(examIDrills);
        final version = placeExamII(score, snap.test.tableSize);
        await (_db.update(_db.buTestRows)..where((t) => t.id.equals(testId)))
            .write(BuTestRowsCompanion(
          examIScore: Value(score),
          examIIVersion: Value(version.name),
        ));
        return version;
      });

  /// Hoàn tất: chỉ lúc này hạng mới đổi (spec mục 4.2, 5.4).
  Future<CompleteOutcome> completeTest(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.examIIReady) throw StateError('Đề II chưa đủ bài');
        final from = retestAvailableFrom(await _tests(), exceptTestId: testId);
        if (from != null && _now().isBefore(from)) return CompletionTooSoon(from);

        final examII = snap.scoreOf(examIIDrills(snap.test.examIIVersion!));
        final total = snap.test.examIScore! + examII;
        final result = rankForBuScore(total);
        final current = await _rank();
        final change =
            applyTestResult(current, result: result, buScore: total, testId: testId, now: _now());

        await (_db.update(_db.buTestRows)..where((t) => t.id.equals(testId)))
            .write(BuTestRowsCompanion(
          examIIScore: Value(examII),
          totalScore: Value(total),
          resultRank: Value(result.name),
          completedAt: Value(_now()),
          syncedAt: const Value(null),
        ));
        await _writeRank(change.rank);
        return TestCompleted(
            outcome: change.outcome, result: result, total: total, before: current?.rank);
      });

  /// Hủy lần đang làm. Lần bị hủy không tính giãn cách 14 ngày.
  Future<void> cancelTest(String testId) =>
      (_db.update(_db.buTestRows)
            ..where((t) =>
                t.id.equals(testId) &
                t.userId.equals(_userId) &
                t.completedAt.isNull() &
                t.cancelledAt.isNull()))
          .write(BuTestRowsCompanion(cancelledAt: Value(_now())));
}
```

- [ ] **Step 5: Run the repository test**

```bash
"$FLUTTER" test test/data/repositories/assessment_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Sign-out forgets assessment data — failing test first**

Append inside `main` of `test/data/sync/account_actions_test.dart` (reuse that file's `db` / `auth` setup; read the top of the file and match its names):

```dart
  test('đăng xuất tay xoá cả hạng và bài kiểm tra của người đó, giữ của người khác',
      () async {
    final at = DateTime(2026, 10, 14);
    for (final user in ['u1', 'u2']) {
      await db.into(db.playerRankRows).insert(PlayerRankRowsCompanion.insert(
          userId: user, onboardingState: 'skipped', updatedAt: at));
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 't-$user', userId: user, startedAt: at, tableSize: 'nineFootPlus'));
      await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
          id: 'r-$user', testId: 't-$user', drillId: 'F1',
          attempts: '{"shots":[]}', recordedAt: at));
    }

    await signOutAndForget(db: db, auth: FakeAuthRepository.signedIn(), userId: 'u1');

    expect((await db.select(db.playerRankRows).get()).map((r) => r.userId), ['u2']);
    expect((await db.select(db.buTestRows).get()).map((r) => r.id), ['t-u2']);
    expect((await db.select(db.buDrillResultRows).get()).map((r) => r.id), ['r-u2']);
  });

  test('đếm thứ chưa đồng bộ được của phần đánh giá, và lần đang dở', () async {
    final at = DateTime(2026, 10, 14);
    expect(await pendingAssessmentCount(db, 'u1'), 0);
    expect(await hasActiveTest(db, 'u1'), isFalse);
    await db.into(db.playerRankRows).insert(PlayerRankRowsCompanion.insert(
        userId: 'u1', onboardingState: 'skipped', updatedAt: at));
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'xong', userId: 'u1', startedAt: at, tableSize: 'nineFootPlus',
        completedAt: Value(at)));
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'do', userId: 'u1', startedAt: at, tableSize: 'nineFootPlus'));
    expect(await pendingAssessmentCount(db, 'u1'), 2,
        reason: 'dòng hạng + lần đã hoàn tất; lần đang dở không đồng bộ được');
    expect(await hasActiveTest(db, 'u1'), isTrue);
  });
```

(Add `import 'package:drift/drift.dart' show Value;` and the `fake_auth.dart` import if the file lacks them.) Run `"$FLUTTER" test test/data/sync/account_actions_test.dart`: expected FAIL — the rows survive and the two functions do not exist.

- [ ] **Step 7: Implement it**

In `lib/data/sync/account_actions.dart`, replace the body of `signOutAndForget` after `await auth.signOut();`:

```dart
  await (db.delete(db.drillLogRows)..where((t) => t.userId.equals(userId)))
      .go();
  // Hạng và bài kiểm tra cũng là dữ liệu riêng của người này.
  await (db.delete(db.playerRankRows)..where((t) => t.userId.equals(userId)))
      .go();
  final tests = db.selectOnly(db.buTestRows)
    ..addColumns([db.buTestRows.id])
    ..where(db.buTestRows.userId.equals(userId));
  await (db.delete(db.buDrillResultRows)..where((r) => r.testId.isInQuery(tests)))
      .go();
  await (db.delete(db.buTestRows)..where((t) => t.userId.equals(userId))).go();
```

and append:

```dart
/// Dòng hạng và lần kiểm tra đã xong của [userId] chưa lên server. Lần đang
/// làm dở không tính: nó chỉ lên server khi xong (D10 của kế hoạch).
Future<int> pendingAssessmentCount(AppDatabase db, String userId) async {
  final rank = await (db.select(db.playerRankRows)
        ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
      .get();
  final tests = await (db.select(db.buTestRows)
        ..where((t) =>
            t.userId.equals(userId) &
            t.syncedAt.isNull() &
            (t.completedAt.isNotNull() | t.cancelledAt.isNotNull())))
      .get();
  return rank.length + tests.length;
}

/// [userId] có lần kiểm tra đang làm dở trên máy này không.
Future<bool> hasActiveTest(AppDatabase db, String userId) async {
  final rows = await (db.select(db.buTestRows)
        ..where((t) =>
            t.userId.equals(userId) & t.completedAt.isNull() & t.cancelledAt.isNull()))
      .get();
  return rows.isNotEmpty;
}
```

Run `"$FLUTTER" test test/data/sync`: expected PASS.

- [ ] **Step 8: Providers and `testContainer` — failing test first**

`test/core/providers/assessment_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/fake_auth.dart';

void main() {
  test('hạng của người đang đăng nhập; đăng xuất thì không còn', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = FakeAuthRepository.signedIn();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(auth),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 14)),
    ]);
    addTearDown(container.dispose);

    container.listen(playerRankProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(playerRankProvider).value, isNull);

    await container.read(assessmentRepositoryProvider)!.saveQuestionnaire(
        chosen: Rank.g, suggested: Rank.g,
        answers: QuestionnaireAnswers([0, 0, 0, 0, 2, 0, 0, 0]));
    await pumpEventQueue();
    expect(container.read(playerRankProvider).value!.rank, Rank.g);

    auth.emit(const SignedOut());
    await pumpEventQueue();
    expect(container.read(assessmentRepositoryProvider), isNull);
    expect(container.read(playerRankProvider).value, isNull);
  });
}
```

Run it: expected FAIL — `assessment_providers.dart` does not exist.

Create `lib/core/providers/assessment_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:uuid/uuid.dart';

/// Hạng và bài kiểm tra của người đang đăng nhập; null khi chưa đăng nhập.
/// Đổi người thì provider dựng lại, mọi màn đọc hạng tự đổi theo.
final assessmentRepositoryProvider = Provider<AssessmentRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return AssessmentRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final playerRankProvider = StreamProvider<PlayerRank?>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchRank();
});

/// Mọi lần kiểm tra, mới nhất trước — lịch sử và giãn cách 14 ngày.
final buTestsProvider = StreamProvider<List<BuTest>>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchTests();
});

final activeTestProvider = StreamProvider<TestSnapshot?>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchActiveTest();
});

final testSnapshotProvider = StreamProvider.family<TestSnapshot?, String>((ref, testId) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchTest(testId);
});
```

In `test/support/test_data.dart`, extend `testContainer` with three optional parameters and three overrides, so widget tests never open a real SQLite file for the rank:

```dart
ProviderContainer testContainer({
  List<Drill>? drills,
  List<KnowledgeArticle>? knowledge,
  List<DrillLog>? logs,
  DateTime? now,
  AuthRepository? auth,
  PlayerRank? rank,
  List<BuTest>? tests,
  TestSnapshot? activeTest,
}) {
  return ProviderContainer(
    overrides: [
      nowProvider.overrideWithValue(() => now ?? testToday),
      drillsProvider.overrideWith((ref) => Stream.value(drills ?? testDrills)),
      knowledgeProvider
          .overrideWith((ref) => Stream.value(knowledge ?? testKnowledge)),
      drillLogsProvider
          .overrideWith((ref) => Stream.value(logs ?? const <DrillLog>[])),
      authRepositoryProvider
          .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
      playerRankProvider.overrideWith((ref) => Stream.value(rank)),
      buTestsProvider.overrideWith((ref) => Stream.value(tests ?? const <BuTest>[])),
      activeTestProvider.overrideWith((ref) => Stream.value(activeTest)),
    ],
  );
}
```

with the imports `package:poolcoachai/core/providers/assessment_providers.dart`, `package:poolcoachai/domain/assessment/bu_test.dart`, `package:poolcoachai/domain/assessment/player_rank.dart`.

- [ ] **Step 9: Run everything touched, then the whole suite**

```bash
"$FLUTTER" test test/core/providers test/data
"$FLUTTER" test
```

Expected: PASS everywhere (the suite proves the `testContainer` change broke nothing).

- [ ] **Step 10: Commit**

```bash
git add lib/data/database/assessment_converters.dart lib/data/repositories/assessment_repository.dart lib/data/sync/account_actions.dart lib/core/providers/assessment_providers.dart test/data/repositories/assessment_repository_test.dart test/data/sync/account_actions_test.dart test/core/providers/assessment_providers_test.dart test/support/test_data.dart
git commit -m "Add the assessment repository that writes every shot to Drift first

Sign-out now also forgets the player's rank and tests on this device.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 9: The merge rule and `AssessmentSyncService` (spec §6.2, §8)

> **Before this task:** the owner has answered D4 (merge between two verified rows). Without an answer, build the default below.

**Files:**
- Create: `lib/domain/assessment/rank_merge.dart`
- Create: `lib/domain/assessment/onboarding_check.dart` (the `RankFetch` enum only; Task 13 appends)
- Modify: `lib/data/remote/directus_client.dart` (add `patch` after `post`, at lines 50–51)
- Modify: `lib/data/database/assessment_converters.dart` (append the Directus part)
- Create: `lib/data/sync/assessment_sync.dart`
- Modify: `lib/core/providers/assessment_providers.dart` (append `RankFetchNotifier`, `rankFetchProvider`, `assessmentSyncProvider`)
- Modify: `lib/core/bootstrap.dart` (`startSync` at lines 27–29)
- Test: `test/domain/assessment/rank_merge_test.dart`
- Test: `test/data/sync/assessment_sync_test.dart`
- Modify: `test/data/remote/directus_client_test.dart` (append one test)
- Modify: `test/core/providers/assessment_providers_test.dart` (append tests)

**Interfaces:**
- Consumes: `PlayerRank` (Task 1); converters and tables (Tasks 7–8); `SyncOutcome` (`lib/data/sync/sync_service.dart`); `DirectusClient`, `DirectusError`, `DirectusUnreachable`; `AuthRepository`, `AuthFailure`, `SignedIn`.
- Produces:
  - `PlayerRank? mergeRank(PlayerRank? local, PlayerRank? remote)` — always returns one of its arguments (identity matters to the sync);
  - `enum RankFetch { pending, foundNone, found, failed }` — `foundNone` and `found` are told apart so the onboarding gate never races the Drift stream: when the server has a row, the gate never asks for onboarding even if the local stream has not caught up yet;
  - `Future<Object?> DirectusClient.patch(String path, {Object? body, String? token})`;
  - converters: `remoteRankFields`, `remoteTestFields`, `remoteResultFields`, `Map<String, Object?> toRemoteRank(PlayerRankRow r)`, `PlayerRank rankFromRemote(Map<String, Object?> json)`, `Map<String, Object?> toRemoteTest(BuTestRow r)`, `BuTestRowsCompanion fromRemoteTest(Map<String, Object?> json, {required String userId, required DateTime syncedAt})`, `Map<String, Object?> toRemoteResult(BuDrillResultRow r)`, `BuDrillResultRowsCompanion fromRemoteResult(Map<String, Object?> json, {required DateTime syncedAt})`;
  - `Stream<int> watchPendingAssessment(AppDatabase db)`;
  - `Future<bool> _syncRank(String userId)` returns whether the server had a row;
  - `class AssessmentSyncService { AssessmentSyncService({required AppDatabase db, required AuthRepository auth, required DirectusClient api, required DateTime Function() now, required void Function(String userId, RankFetch fetch) onRankFetch, Duration retryEvery}); void start(); Future<SyncOutcome> syncNow(); void dispose(); }`;
  - `typedef RankFetchState = ({String userId, RankFetch fetch})`, `class RankFetchNotifier extends Notifier<RankFetchState?> { void report(String userId, RankFetch fetch); }`, `RankFetch rankFetchFor(RankFetchState? state, String userId)`, `rankFetchProvider`, `assessmentSyncProvider`.

**Server shape (D9).** `player_ranks` (one row per account, `id` = the Directus user id), `bu_tests`, `bu_drill_results`; snake_case fields; `user_created` filled by the server. Tests and results are create-only; the rank row is created once, then patched.

- [ ] **Step 1: Write the failing merge test**

`test/domain/assessment/rank_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/rank_merge.dart';
import 'package:poolcoachai/domain/rank.dart';

/// Quy tắc gộp của spec mục 6.2: bản mới nhất thắng, trừ bản đã kiểm
/// chứng không bao giờ bị bản ước lượng/tự khai ghi đè.
void main() {
  final older = DateTime(2026, 10, 1);
  final newer = DateTime(2026, 10, 9);

  PlayerRank r(Rank? rank, RankSource? source, DateTime at) => PlayerRank(
        rank: rank,
        source: source,
        buScore: source == RankSource.verified ? 120 : null,
        testId: source == RankSource.verified ? 't-$rank' : null,
        onboardingState: rank == null ? OnboardingState.skipped : OnboardingState.done,
        updatedAt: at,
      );

  test('một bên trống thì lấy bên kia', () {
    final x = r(Rank.g, RankSource.estimated, older);
    expect(mergeRank(null, null), isNull);
    expect(identical(mergeRank(x, null), x), isTrue);
    expect(identical(mergeRank(null, x), x), isTrue);
  });

  test('máy khác tự khai mới hơn không ghi đè hạng đã kiểm chứng', () {
    final verified = r(Rank.e, RankSource.verified, older);
    final declared = r(Rank.pro, RankSource.selfDeclared, newer);
    expect(identical(mergeRank(declared, verified), verified), isTrue);
    expect(identical(mergeRank(verified, declared), verified), isTrue);
  });

  test('ước lượng mới hơn cũng không ghi đè hạng đã kiểm chứng', () {
    final verified = r(Rank.e, RankSource.verified, older);
    final estimated = r(Rank.c, RankSource.estimated, newer);
    expect(identical(mergeRank(estimated, verified), verified), isTrue);
  });

  test('hai bản cùng chưa kiểm chứng: mới hơn thắng', () {
    final a = r(Rank.g, RankSource.estimated, older);
    final b = r(Rank.f, RankSource.selfDeclared, newer);
    expect(identical(mergeRank(a, b), b), isTrue);
    expect(identical(mergeRank(b, a), b), isTrue);
  });

  test('hai bản đã kiểm chứng: mới hơn thắng (spec 6.2; xem D4)', () {
    final a = r(Rank.d, RankSource.verified, older);
    final b = r(Rank.c, RankSource.verified, newer);
    expect(identical(mergeRank(a, b), b), isTrue);
  });

  test('bản chưa có hạng (Để sau) không xoá hạng đã có, dù mới hơn (D16)', () {
    final skipped = r(null, null, newer);
    final estimated = r(Rank.h, RankSource.estimated, older);
    expect(identical(mergeRank(skipped, estimated), estimated), isTrue);
    expect(identical(mergeRank(estimated, skipped), estimated), isTrue);
  });

  test('hoà giờ: giữ bản trên máy', () {
    final local = r(Rank.g, RankSource.estimated, older);
    final remote = r(Rank.f, RankSource.estimated, older);
    expect(identical(mergeRank(local, remote), local), isTrue);
  });
}
```

Run `"$FLUTTER" test test/domain/assessment/rank_merge_test.dart`. Expected: FAIL — `rank_merge.dart` does not exist.

- [ ] **Step 2: Write `rank_merge.dart` and `onboarding_check.dart`**

`lib/domain/assessment/rank_merge.dart`:

```dart
import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Bản hạng nào thắng khi máy này và máy chủ khác nhau (spec mục 6.2).
///
/// Luôn trả **một trong hai** đối số: bên đồng bộ dựa vào đó để biết phải
/// ghi bản máy chủ xuống máy hay đẩy bản máy lên.
///
/// 1. Bản có hạng thắng bản chưa có hạng: bấm *Để sau* trên máy mới đang
///    mất mạng không được xoá hạng đã có (D16 của kế hoạch).
/// 2. Bản đã kiểm chứng không bao giờ thua bản ước lượng / tự khai.
/// 3. Còn lại bản mới hơn thắng; hoà giờ giữ bản trên máy.
PlayerRank? mergeRank(PlayerRank? local, PlayerRank? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  if (local.hasRank != remote.hasRank) return local.hasRank ? local : remote;
  if (local.isVerified != remote.isVerified) return local.isVerified ? local : remote;
  return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
}
```

`lib/domain/assessment/onboarding_check.dart`:

```dart
/// Lần lấy hạng từ máy chủ của người đang đăng nhập (spec mục 8).
enum RankFetch {
  /// Chưa có lượt đồng bộ nào trả lời.
  pending,

  /// Máy chủ trả lời: tài khoản chưa có dòng hạng nào.
  foundNone,

  /// Máy chủ trả lời: có dòng hạng (đã gộp xuống máy).
  found,

  /// Lượt đồng bộ hỏng trước khi lấy được hạng.
  failed,
}
```

Run the merge test: expected PASS.

Rule 1 of `mergeRank` is the plan's D16 (not in the spec); Task 18 asks the reviewer to check it.

- [ ] **Step 3: `DirectusClient.patch` — failing test, then code**

Append inside `main` of `test/data/remote/directus_client_test.dart` (match that file's helper names):

```dart
  test('patch gửi PATCH kèm token và thân JSON, trả trường data', () async {
    final server = FakeDirectus()
      ..routes['PATCH /items/player_ranks/u1'] =
          ((req) => FakeDirectus.ok({'id': 'u1', ...FakeDirectus.body(req)}));
    final api = DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);

    final data = await api.patch('/items/player_ranks/u1', token: 'tk', body: {'rank': 'g'});

    expect(data, {'id': 'u1', 'rank': 'g'});
    final req = server.sent('PATCH', '/items/player_ranks/u1').single;
    expect(req.headers['Authorization'], 'Bearer tk');
  });
```

Run it: FAIL (`patch` is not defined). Add to `DirectusClient`, after `post`:

```dart
  Future<Object?> patch(String path, {Object? body, String? token}) =>
      _send('PATCH', path, body: body, token: token);
```

Run it: PASS.

- [ ] **Step 4: Append the Directus converters**

Append to `lib/data/database/assessment_converters.dart`:

```dart
// ─── Directus (spec mục 6.2; tên collection theo D9 của kế hoạch) ─────────
//
// Không gửi chủ: server tự điền `user_created` từ token, như drill_logs.

const remoteRankFields = 'id,rank,source,bu_score,test_id,warning_rank,'
    'warning_test_id,questionnaire_answers,onboarding_state,updated_at';
const remoteTestFields = 'id,started_at,completed_at,cancelled_at,table_size,'
    'exam_i_score,exam_ii_version,exam_ii_score,total_score,result_rank';
const remoteResultFields = 'id,test_id,drill_id,attempts,score,recorded_at';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _local(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();

/// Dòng hạng cho `POST /items/player_ranks` (id là id người dùng).
Map<String, Object?> toRemoteRank(PlayerRankRow r) => {
      'id': r.userId,
      'rank': r.rank,
      'source': r.source,
      'bu_score': r.buScore,
      'test_id': r.testId,
      'warning_rank': r.warningRank,
      'warning_test_id': r.warningTestId,
      'questionnaire_answers':
          r.questionnaireAnswers == null ? null : jsonDecode(r.questionnaireAnswers!),
      'onboarding_state': r.onboardingState,
      'updated_at': _iso(r.updatedAt),
    };

PlayerRank rankFromRemote(Map<String, Object?> j) => PlayerRank(
      rank: _rank(j['rank'] as String?),
      source: j['source'] == null ? null : RankSource.values.byName(j['source']! as String),
      buScore: j['bu_score'] as int?,
      testId: j['test_id'] as String?,
      warningRank: _rank(j['warning_rank'] as String?),
      warningTestId: j['warning_test_id'] as String?,
      answers: j['questionnaire_answers'] == null
          ? null
          : QuestionnaireAnswers.fromJson(j['questionnaire_answers']),
      onboardingState: OnboardingState.values.byName(j['onboarding_state']! as String),
      updatedAt: _local(j['updated_at'])!,
    );

Map<String, Object?> toRemoteTest(BuTestRow r) => {
      'id': r.id,
      'started_at': _iso(r.startedAt),
      'completed_at': _iso(r.completedAt),
      'cancelled_at': _iso(r.cancelledAt),
      'table_size': r.tableSize,
      'exam_i_score': r.examIScore,
      'exam_ii_version': r.examIIVersion,
      'exam_ii_score': r.examIIScore,
      'total_score': r.totalScore,
      'result_rank': r.resultRank,
    };

BuTestRowsCompanion fromRemoteTest(Map<String, Object?> j,
        {required String userId, required DateTime syncedAt}) =>
    BuTestRowsCompanion.insert(
      id: j['id']! as String,
      userId: userId,
      startedAt: _local(j['started_at'])!,
      tableSize: j['table_size']! as String,
      completedAt: drift.Value(_local(j['completed_at'])),
      cancelledAt: drift.Value(_local(j['cancelled_at'])),
      examIScore: drift.Value(j['exam_i_score'] as int?),
      examIIVersion: drift.Value(j['exam_ii_version'] as String?),
      examIIScore: drift.Value(j['exam_ii_score'] as int?),
      totalScore: drift.Value(j['total_score'] as int?),
      resultRank: drift.Value(j['result_rank'] as String?),
      syncedAt: drift.Value(syncedAt),
    );

Map<String, Object?> toRemoteResult(BuDrillResultRow r) => {
      'id': r.id,
      'test_id': r.testId,
      'drill_id': r.drillId,
      'attempts': jsonDecode(r.attempts),
      'score': r.score,
      'recorded_at': _iso(r.recordedAt),
    };

BuDrillResultRowsCompanion fromRemoteResult(Map<String, Object?> j,
        {required DateTime syncedAt}) =>
    BuDrillResultRowsCompanion.insert(
      id: j['id']! as String,
      testId: j['test_id']! as String,
      drillId: j['drill_id']! as String,
      attempts: jsonEncode(j['attempts']),
      score: drift.Value(j['score'] as int?),
      recordedAt: _local(j['recorded_at'])!,
      syncedAt: drift.Value(syncedAt),
    );
```

- [ ] **Step 5: Write the failing sync test**

`test/data/sync/assessment_sync_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/assessment_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late List<(String, RankFetch)> fetches;
  final now = DateTime(2026, 10, 14, 10);
  final older = DateTime(2026, 10, 1, 9);
  final newer = DateTime(2026, 10, 9, 9);

  AssessmentSyncService build() {
    final s = AssessmentSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => now,
      onRankFetch: (u, f) => fetches.add((u, f)),
    );
    addTearDown(s.dispose);
    return s;
  }

  void serve({
    List<Map<String, Object?>> ranks = const [],
    List<Map<String, Object?>> tests = const [],
    List<Map<String, Object?>> results = const [],
  }) {
    server.routes['GET /items/player_ranks'] = (_) => FakeDirectus.ok(ranks);
    server.routes['POST /items/player_ranks'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/player_ranks/u1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/bu_tests'] = (_) => FakeDirectus.ok(tests);
    server.routes['GET /items/bu_drill_results'] = (_) => FakeDirectus.ok(results);
    server.routes['POST /items/bu_tests'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['POST /items/bu_drill_results'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  }

  Map<String, Object?> remoteRank(Rank? rank, RankSource? source, DateTime at) => {
        'id': 'u1',
        'rank': rank?.name,
        'source': source?.name,
        'bu_score': source == RankSource.verified ? 130 : null,
        'test_id': source == RankSource.verified ? 'tv' : null,
        'warning_rank': null,
        'warning_test_id': null,
        'questionnaire_answers': [0, 0, 0, 0, 2, 4, 0, 0],
        'onboarding_state': rank == null ? 'skipped' : 'done',
        'updated_at': at.toUtc().toIso8601String(),
      };

  Future<void> localRank(Rank? rank, RankSource? source, DateTime at, {DateTime? syncedAt}) =>
      db.into(db.playerRankRows).insertOnConflictUpdate(toPlayerRankRow(
            PlayerRank(
              rank: rank,
              source: source,
              buScore: source == RankSource.verified ? 100 : null,
              testId: source == RankSource.verified ? 'tl' : null,
              onboardingState: rank == null ? OnboardingState.skipped : OnboardingState.done,
              updatedAt: at,
            ),
            userId: 'u1',
            syncedAt: syncedAt,
          ));

  Future<PlayerRankRow> rankRow() => db.select(db.playerRankRows).getSingle();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
    auth = FakeAuthRepository.signedIn();
    fetches = [];
  });
  tearDown(() => db.close());

  test('chưa có hạng ở đâu: báo máy chủ chưa có, không gửi gì', () async {
    serve();
    expect(await build().syncNow(), SyncOutcome.done);
    expect(fetches, [('u1', RankFetch.foundNone)]);
    expect(server.sent('POST', '/items/player_ranks'), isEmpty);
    expect(await db.select(db.playerRankRows).get(), isEmpty);
  });

  test('máy có hạng chưa đồng bộ, máy chủ chưa có: POST rồi đánh dấu', () async {
    serve();
    await localRank(Rank.h, RankSource.estimated, older);
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('POST', '/items/player_ranks').single);
    expect(body['id'], 'u1');
    expect(body['rank'], 'h');
    expect(body.containsKey('user_created'), isFalse);
    expect((await rankRow()).syncedAt, now);
  });

  test('máy chủ có hạng đã kiểm chứng, máy này tự khai mới hơn: máy chủ thắng, không gửi PATCH',
      () async {
    serve(ranks: [remoteRank(Rank.e, RankSource.verified, older)]);
    await localRank(Rank.pro, RankSource.selfDeclared, newer);
    await build().syncNow();
    expect(fetches, [('u1', RankFetch.found)]);
    expect(server.sent('PATCH', '/items/player_ranks/u1'), isEmpty);
    final row = await rankRow();
    expect(row.rank, 'e');
    expect(row.source, 'verified');
    expect(row.syncedAt, now);
  });

  test('máy này đã kiểm chứng, máy chủ ước lượng mới hơn: gửi PATCH, máy giữ nguyên', () async {
    serve(ranks: [remoteRank(Rank.c, RankSource.estimated, newer)]);
    await localRank(Rank.f, RankSource.verified, older);
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_ranks/u1').single);
    expect(body['rank'], 'f');
    expect(body.containsKey('id'), isFalse, reason: 'không sửa khoá chính');
    expect((await rankRow()).rank, 'f');
    expect((await rankRow()).syncedAt, now);
  });

  test('Để sau trên máy mới (mất mạng lúc đó) không xoá hạng của máy chủ', () async {
    serve(ranks: [remoteRank(Rank.h, RankSource.estimated, older)]);
    await localRank(null, null, newer);
    await build().syncNow();
    expect(server.sent('PATCH', '/items/player_ranks/u1'), isEmpty);
    expect((await rankRow()).rank, 'h');
  });

  test('chỉ đẩy lần đã xong cùng kết quả; lần đang dở nằm yên', () async {
    serve();
    for (final (id, done) in [('xong', true), ('do', false)]) {
      await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
            id: id,
            userId: 'u1',
            startedAt: older,
            tableSize: 'nineFootPlus',
            completedAt: Value(done ? newer : null),
            totalScore: Value(done ? 137 : null),
            resultRank: Value(done ? 'd' : null),
          ));
      await db.into(db.buDrillResultRows).insert(BuDrillResultRowsCompanion.insert(
            id: 'r-$id',
            testId: id,
            drillId: 'F1',
            attempts: '{"shots":[true,true,true,true,true,true,true,true]}',
            score: const Value(10),
            recordedAt: older,
          ));
    }
    await build().syncNow();

    final tests = server.sent('POST', '/items/bu_tests').map(FakeDirectus.body).toList();
    expect(tests.map((b) => b['id']), ['xong']);
    final results = server.sent('POST', '/items/bu_drill_results').map(FakeDirectus.body).toList();
    expect(results.map((b) => b['id']), ['r-xong']);
    expect(results.single['attempts'], isA<Map<String, Object?>>(),
        reason: 'gửi JSON thật, không gửi chuỗi');
    final rows = await db.select(db.buTestRows).get();
    expect(rows.firstWhere((r) => r.id == 'xong').syncedAt, now);
    expect(rows.firstWhere((r) => r.id == 'do').syncedAt, isNull);
  });

  test('kéo lần kiểm tra và kết quả từ máy chủ về', () async {
    serve(tests: [
      {
        'id': 't9', 'started_at': older.toUtc().toIso8601String(),
        'completed_at': newer.toUtc().toIso8601String(), 'cancelled_at': null,
        'table_size': 'eightFoot', 'exam_i_score': 100, 'exam_ii_version': 'masters',
        'exam_ii_score': 77, 'total_score': 177, 'result_rank': 'a',
      },
    ], results: [
      {
        'id': 'r9', 'test_id': 't9', 'drill_id': 'S10',
        'attempts': {'breaks': [[true, true, true, true, true]]}, 'score': null,
        'recorded_at': newer.toUtc().toIso8601String(),
      },
    ]);
    await build().syncNow();
    final t = await db.select(db.buTestRows).getSingle();
    expect(t.userId, 'u1');
    expect(t.totalScore, 177);
    expect(t.syncedAt, now);
    final r = await db.select(db.buDrillResultRows).getSingle();
    expect(jsonDecode(r.attempts), {'breaks': [[true, true, true, true, true]]});
  });

  test('mất mạng thì báo RankFetch.failed', () async {
    serve();
    server.offline = true;
    expect(await build().syncNow(), SyncOutcome.offline);
    expect(fetches, [('u1', RankFetch.failed)]);
  });

  test('chưa đăng nhập thì không gọi máy chủ, không báo gì', () async {
    serve();
    auth = FakeAuthRepository();
    expect(await build().syncNow(), SyncOutcome.signedOut);
    expect(server.requests, isEmpty);
    expect(fetches, isEmpty);
  });

  test('có lần mới hoàn tất trên máy thì tự đồng bộ', () async {
    serve();
    build().start();
    await pumpEventQueue();
    server.requests.clear();
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
          id: 'moi', userId: 'u1', startedAt: older, tableSize: 'nineFootPlus',
          cancelledAt: Value(newer)));
    await pumpEventQueue(times: 50);
    expect(server.sent('POST', '/items/bu_tests'), hasLength(1));
  });
}
```

Run `"$FLUTTER" test test/data/sync/assessment_sync_test.dart`. Expected: FAIL — `assessment_sync.dart` does not exist.

- [ ] **Step 6: Write `assessment_sync.dart`**

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/rank_merge.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Số thứ đang chờ lên server của phần đánh giá, của mọi người trên máy:
/// dòng hạng chưa đồng bộ và lần kiểm tra đã xong (hoàn tất hoặc hủy).
Stream<int> watchPendingAssessment(AppDatabase db) => db
    .customSelect(
      'SELECT (SELECT COUNT(*) FROM bu_test_rows WHERE synced_at IS NULL '
      'AND (completed_at IS NOT NULL OR cancelled_at IS NOT NULL)) '
      '+ (SELECT COUNT(*) FROM player_rank_rows WHERE synced_at IS NULL) AS n',
      readsFrom: {db.buTestRows, db.playerRankRows},
    )
    .watchSingle()
    .map((row) => row.read<int>('n'));

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ hạng và bài kiểm tra BU với Directus (spec mục 6.2).
///
/// Tách khỏi [SyncService] của buổi tập: hai luồng dữ liệu khác luật (buổi
/// tập chỉ thêm; hạng gộp theo [mergeRank]), và để luồng buổi tập cùng các
/// test của nó không đổi. Cùng cách sống: chạy khi đăng nhập, khi có thứ
/// mới chờ, và định kỳ khi còn thứ chờ.
class AssessmentSyncService {
  AssessmentSyncService({
    required AppDatabase db,
    required AuthRepository auth,
    required DirectusClient api,
    required DateTime Function() now,
    required void Function(String userId, RankFetch fetch) onRankFetch,
    Duration retryEvery = const Duration(seconds: 30),
  })  : _db = db,
        _auth = auth,
        _api = api,
        _now = now,
        _onRankFetch = onRankFetch,
        _retryEvery = retryEvery;

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final void Function(String userId, RankFetch fetch) _onRankFetch;
  final Duration _retryEvery;

  /// Mã Directus khi `POST` một id đã có: đã lên từ lần trước.
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  int _pending = 0;

  /// Lần kiểm tra server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
  final Set<String> _rejected = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<int>? _pendingSub;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authSub = _auth.watchSession().listen((s) {
      if (s is SignedIn) unawaited(syncNow());
    });
    _pendingSub = watchPendingAssessment(_db).listen((n) {
      final more = n > _pending;
      _pending = n;
      if (more) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_pending > _rejected.length) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  Future<SyncOutcome> syncNow() {
    if (_disposed) return Future.value(SyncOutcome.stopped);
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<SyncOutcome> _loop() async {
    SyncOutcome outcome;
    do {
      _again = false;
      outcome = await _once();
    } while (_again && outcome == SyncOutcome.done && !_disposed);
    return outcome;
  }

  Future<SyncOutcome> _once() async {
    if (_disposed) return SyncOutcome.stopped;
    final who = _auth.current;
    if (who is! SignedIn) return SyncOutcome.signedOut;
    final userId = who.userId;
    var rankFetched = false;
    void failed() {
      // Đã lấy được hạng trong lượt này thì giữ kết quả đó: việc kéo bài
      // kiểm tra hỏng sau đó không làm onboarding đổi ý.
      if (!rankFetched && _stillSignedInAs(userId)) _onRankFetch(userId, RankFetch.failed);
    }

    try {
      await _pushFinishedTests(userId);
      final hadRow = await _syncRank(userId);
      rankFetched = true;
      _onRankFetch(userId, hadRow ? RankFetch.found : RankFetch.foundNone);
      await _pullTests(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (f) {
      failed();
      return switch (f) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      failed();
      return SyncOutcome.offline;
    } on Object {
      // Server trả hình dạng lạ hay lỗi chưa lường: lượt này hỏng, nhưng
      // syncNow() không bao giờ ném — nó chạy từ timer.
      failed();
      return SyncOutcome.failed;
    }
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
        SignedIn(userId: final id) => id == userId,
        SignedOut() => false,
      };

  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    return token;
  }

  void _checkAlive() {
    if (_disposed) throw const _Stopped();
  }

  Future<void> _create(String path, Map<String, Object?> body, String userId) async {
    final token = await _tokenFor(userId);
    try {
      await _api.post(path, token: token, body: body);
    } on DirectusError catch (e) {
      if (e.code != _duplicateCode) rethrow;
    }
    _checkAlive();
  }

  /// Lần đã xong lên server cùng mọi kết quả của nó; lần đang dở nằm yên
  /// (D10 của kế hoạch). Kết quả trước, lần kiểm tra sau: lần đã đánh dấu
  /// đồng bộ thì chắc chắn đủ kết quả trên server.
  Future<void> _pushFinishedTests(String userId) async {
    final tests = await (_db.select(_db.buTestRows)
          ..where((t) =>
              t.userId.equals(userId) &
              t.syncedAt.isNull() &
              (t.completedAt.isNotNull() | t.cancelledAt.isNotNull()))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    for (final test in tests) {
      if (_rejected.contains(test.id)) continue;
      _checkAlive();
      try {
        final results = await (_db.select(_db.buDrillResultRows)
              ..where((r) => r.testId.equals(test.id) & r.syncedAt.isNull()))
            .get();
        for (final r in results) {
          await _create('/items/bu_drill_results', toRemoteResult(r), userId);
          await (_db.update(_db.buDrillResultRows)..where((x) => x.id.equals(r.id)))
              .write(BuDrillResultRowsCompanion(syncedAt: Value(_now())));
        }
        await _create('/items/bu_tests', toRemoteTest(test), userId);
      } on DirectusError catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401) {
          _rejected.add(test.id);
          continue;
        }
        rethrow;
      }
      await (_db.update(_db.buTestRows)..where((t) => t.id.equals(test.id)))
          .write(BuTestRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Lấy dòng hạng trên server, gộp với dòng trên máy theo [mergeRank], rồi
  /// ghi bản thắng về phía còn thiếu. Trả về server có dòng hạng hay không.
  Future<bool> _syncRank(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/player_ranks',
        token: token, query: {'limit': '1', 'fields': remoteRankFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final remoteJson = items.isEmpty ? null : items.first! as Map<String, Object?>;
    final remote = remoteJson == null ? null : rankFromRemote(remoteJson);

    final localRow = await (_db.select(_db.playerRankRows)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    final local = localRow == null ? null : toPlayerRank(localRow);
    final winner = mergeRank(local, remote);
    if (winner == null) return false;

    if (identical(winner, remote)) {
      // Gộp lại trong transaction: người chơi vừa đổi hạng trên máy trong
      // lúc chờ server thì bản mới đó được xét lại, không bị ghi đè mù.
      await _db.transaction(() async {
        final fresh = await (_db.select(_db.playerRankRows)
              ..where((t) => t.userId.equals(userId)))
            .getSingleOrNull();
        final again = mergeRank(fresh == null ? null : toPlayerRank(fresh), remote);
        if (identical(again, remote)) {
          await _db.into(_db.playerRankRows).insertOnConflictUpdate(
              toPlayerRankRow(remote!, userId: userId, syncedAt: _now()));
        }
      });
      return true;
    }

    if (localRow!.syncedAt != null) return remoteJson != null;
    final body = toRemoteRank(localRow);
    final t = await _tokenFor(userId);
    if (remoteJson == null) {
      await _create('/items/player_ranks', body, userId);
    } else {
      body.remove('id');
      await _api.patch('/items/player_ranks/$userId', token: t, body: body);
      _checkAlive();
    }
    await (_db.update(_db.playerRankRows)
          ..where((r) => r.userId.equals(userId) & r.updatedAt.equalsValue(localRow.updatedAt)))
        .write(PlayerRankRowsCompanion(syncedAt: Value(_now())));
    return remoteJson != null;
  }

  /// Lần kiểm tra trên server đều đã xong và không đổi nữa: ghi đè an toàn.
  Future<void> _pullTests(String userId) async {
    final token = await _tokenFor(userId);
    final tests = await _api.get('/items/bu_tests',
        token: token, query: {'limit': '-1', 'fields': remoteTestFields}) as List<Object?>;
    final results = await _api.get('/items/bu_drill_results',
        token: token, query: {'limit': '-1', 'fields': remoteResultFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    await _db.batch((batch) {
      for (final t in tests) {
        batch.insert(_db.buTestRows,
            fromRemoteTest(t! as Map<String, Object?>, userId: userId, syncedAt: at),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in results) {
        batch.insert(_db.buDrillResultRows,
            fromRemoteResult(r! as Map<String, Object?>, syncedAt: at),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
}
```

Note: the PATCH marks the row synced only if `updatedAt` is still the pushed one, so a change made while the request was in flight stays pending.

Run `"$FLUTTER" test test/data/sync/assessment_sync_test.dart`. Expected: PASS. If `equalsValue` is not available on `DateTimeColumn` in the locked drift version, use `r.updatedAt.equals(localRow.updatedAt)`.

- [ ] **Step 7: Only if the owner chose the D4 alternative**

Replace the last line of `mergeRank` with:

```dart
  if (local.isVerified && remote.isVerified && local.rank != remote.rank) {
    // Hai lần kiểm chứng khác nhau: hạng cao hơn thắng, app không tự hạ hạng (Q5).
    return local.rank!.index > remote.rank!.index ? local : remote;
  }
  return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
```

and replace the test `hai bản đã kiểm chứng: mới hơn thắng` with:

```dart
  test('hai bản đã kiểm chứng khác hạng: hạng cao hơn thắng, dù cũ hơn (D4)', () {
    final high = r(Rank.b, RankSource.verified, older);
    final low = r(Rank.d, RankSource.verified, newer);
    expect(identical(mergeRank(high, low), high), isTrue);
    expect(identical(mergeRank(low, high), high), isTrue);
  });
```

Run the merge and sync tests again: PASS. Skip this step if the owner kept the spec rule.

- [ ] **Step 8: Providers and start-up — failing test first**

Append inside `main` of `test/core/providers/assessment_providers_test.dart`:

```dart
  group('RankFetchNotifier', () {
    test('báo theo người; người khác thì coi như chưa lấy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      final state = container.read(rankFetchProvider);
      expect(rankFetchFor(state, 'u1'), RankFetch.foundNone);
      expect(rankFetchFor(state, 'u2'), RankFetch.pending);
    });

    test('đã hỏng một lần thì giữ nguyên trong phiên (spec mục 8)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(rankFetchProvider.notifier);
      n.report('u1', RankFetch.failed);
      n.report('u1', RankFetch.foundNone);
      expect(rankFetchFor(container.read(rankFetchProvider), 'u1'), RankFetch.failed);
      n.report('u2', RankFetch.foundNone);
      expect(rankFetchFor(container.read(rankFetchProvider), 'u2'), RankFetch.foundNone,
          reason: 'người khác đăng nhập thì bắt đầu lại');
    });
  });
```

(import `package:poolcoachai/domain/assessment/onboarding_check.dart`). Run: FAIL.

Append to `lib/core/providers/assessment_providers.dart`:

```dart
typedef RankFetchState = ({String userId, RankFetch fetch});

/// Lần lấy hạng gần nhất từ máy chủ, do [AssessmentSyncService] báo.
///
/// Đã hỏng một lần cho người này thì giữ "hỏng" tới khi đổi người: spec
/// mục 8 nói lấy không được thì không ép onboarding — một lượt thành công
/// về sau không được kéo người chơi vào onboarding giữa lúc đang dùng app.
class RankFetchNotifier extends Notifier<RankFetchState?> {
  @override
  RankFetchState? build() => null;

  void report(String userId, RankFetch fetch) {
    final s = state;
    if (s != null && s.userId == userId && s.fetch == RankFetch.failed) return;
    state = (userId: userId, fetch: fetch);
  }
}

RankFetch rankFetchFor(RankFetchState? state, String userId) =>
    state != null && state.userId == userId ? state.fetch : RankFetch.pending;

final rankFetchProvider =
    NotifierProvider<RankFetchNotifier, RankFetchState?>(RankFetchNotifier.new);

/// Service đã chạy sẵn, như [syncServiceProvider].
final assessmentSyncProvider = Provider<AssessmentSyncService>((ref) {
  final service = AssessmentSyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
    onRankFetch: ref.read(rankFetchProvider.notifier).report,
  )..start();
  ref.onDispose(service.dispose);
  return service;
});
```

with the imports `package:poolcoachai/data/sync/assessment_sync.dart` and `package:poolcoachai/domain/assessment/onboarding_check.dart`.

In `lib/core/bootstrap.dart`, `startSync` becomes:

```dart
/// Bật đồng bộ nền suốt đời app — buổi tập và phần đánh giá. Gọi **sau**
/// [restoreSession]: lượt đầu cần biết ai đang đăng nhập. Màn hình chỉ đọc Drift.
void startSync(ProviderContainer container) {
  container.read(syncServiceProvider);
  container.read(assessmentSyncProvider);
}
```

and add the import `package:poolcoachai/core/providers/assessment_providers.dart`.

- [ ] **Step 9: Run and commit**

```bash
"$FLUTTER" test test/domain/assessment test/data test/core
```

Expected: PASS.

```bash
git add lib/domain/assessment/rank_merge.dart lib/domain/assessment/onboarding_check.dart lib/data/remote/directus_client.dart lib/data/database/assessment_converters.dart lib/data/sync/assessment_sync.dart lib/core/providers/assessment_providers.dart lib/core/bootstrap.dart test/domain/assessment/rank_merge_test.dart test/data/sync/assessment_sync_test.dart test/data/remote/directus_client_test.dart test/core/providers/assessment_providers_test.dart
git commit -m "Sync ranks and finished BU tests with Directus, never letting an unverified rank overwrite a verified one

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Directus collections and permissions — STOP for the owner before production

**Files:**
- Modify: `deploy/directus/bootstrap.mjs` (new section after the `drill_logs` relation block that ends at line 147; `desiredPermissions` at lines 183–209)
- Modify: `deploy/directus/verify.mjs` (new block before the line `const adminRole = (await call('GET', '/roles?filter[name][_eq]=Administrator', …` at line 120)

**Interfaces:**
- Consumes: the field names of Task 9's converters (`remoteRankFields`, `remoteTestFields`, `remoteResultFields`) — they must match one to one.
- Produces: collections `player_ranks`, `bu_tests`, `bu_drill_results`, each with `user_created` → `directus_users` (CASCADE); Player permissions: rank create (only its own id) / read own / update own; tests and results create / read own, no update, no delete.

- [ ] **Step 1: Add the collections to `bootstrap.mjs`**

After the `drill_logs` relation block (line 147) and before `// ─── 2. Role Player và policy của nó`:

```js
// ─── 1b. Đánh giá + hạng (spec 2026-10-14 mục 6.2) ─────────────────────────
// player_ranks: mỗi tài khoản một dòng, id = id người dùng (D9 của kế hoạch).
// bu_tests, bu_drill_results: chỉ thêm — app chỉ đẩy lần đã xong.
const ownerFields = [
  { field: 'user_created', type: 'uuid', meta: { special: ['user-created'], readonly: true, hidden: true }, schema: {} },
  { field: 'date_created', type: 'timestamp', meta: { special: ['date-created'], readonly: true, hidden: true }, schema: {} },
];

async function exists(path) {
  // Directus trả 403 (không phải 404) cho thứ chưa có, để không lộ tên.
  return api('GET', path, undefined, token).then(
    () => true,
    (e) => (e.status === 403 || e.status === 404 ? false : Promise.reject(e)),
  );
}

async function ensureCollection(name, note, fields) {
  if (!(await exists(`/collections/${name}`))) {
    await api('POST', '/collections', {
      collection: name,
      meta: { icon: 'military_tech', note },
      schema: {},
      fields: [...fields, ...ownerFields],
    }, token);
    console.log(`Tạo collection ${name}`);
  }
  if (!(await exists(`/relations/${name}/user_created`))) {
    // Xoá người dùng thì xoá luôn hạng và bài kiểm tra của họ.
    await api('POST', '/relations', {
      collection: name,
      field: 'user_created',
      related_collection: 'directus_users',
      schema: { on_delete: 'CASCADE' },
    }, token);
    console.log(`Tạo quan hệ ${name}.user_created → directus_users`);
  }
}

const nullable = (field, type) => ({ field, type, schema: { is_nullable: true } });
const required = (field, type) => ({ field, type, schema: { is_nullable: false } });
const pk = { field: 'id', type: 'uuid', schema: { is_primary_key: true, is_nullable: false } };

await ensureCollection('player_ranks', 'Hạng người chơi PoolCoachAI — mỗi tài khoản một dòng, id = id người dùng', [
  pk,
  nullable('rank', 'string'),
  nullable('source', 'string'),
  nullable('bu_score', 'integer'),
  nullable('test_id', 'uuid'),
  nullable('warning_rank', 'string'),
  nullable('warning_test_id', 'uuid'),
  nullable('questionnaire_answers', 'json'),
  required('onboarding_state', 'string'),
  required('updated_at', 'timestamp'),
]);
await ensureCollection('bu_tests', 'Lần kiểm tra Billiard University đã xong (hoàn tất hoặc hủy)', [
  pk,
  required('started_at', 'timestamp'),
  nullable('completed_at', 'timestamp'),
  nullable('cancelled_at', 'timestamp'),
  required('table_size', 'string'),
  nullable('exam_i_score', 'integer'),
  nullable('exam_ii_version', 'string'),
  nullable('exam_ii_score', 'integer'),
  nullable('total_score', 'integer'),
  nullable('result_rank', 'string'),
]);
await ensureCollection('bu_drill_results', 'Kết quả thô từng bài của một lần kiểm tra BU', [
  pk,
  required('test_id', 'uuid'),
  required('drill_id', 'string'),
  required('attempts', 'json'),
  nullable('score', 'integer'),
  required('recorded_at', 'timestamp'),
]);
```

Append to `desiredPermissions`, after the `drill_logs` read entry:

```js
  // Hạng: tạo đúng một dòng của chính mình, đọc và sửa dòng của mình.
  {
    collection: 'player_ranks',
    action: 'create',
    fields: ['id', 'rank', 'source', 'bu_score', 'test_id', 'warning_rank', 'warning_test_id',
      'questionnaire_answers', 'onboarding_state', 'updated_at'],
    permissions: {},
    validation: { id: { _eq: '$CURRENT_USER' } },
  },
  { collection: 'player_ranks', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'player_ranks',
    action: 'update',
    fields: ['rank', 'source', 'bu_score', 'test_id', 'warning_rank', 'warning_test_id',
      'questionnaire_answers', 'onboarding_state', 'updated_at'],
    permissions: { user_created: self },
    validation: {},
  },
  // Bài kiểm tra và kết quả: chỉ thêm, không sửa, không xoá.
  {
    collection: 'bu_tests',
    action: 'create',
    fields: ['id', 'started_at', 'completed_at', 'cancelled_at', 'table_size', 'exam_i_score',
      'exam_ii_version', 'exam_ii_score', 'total_score', 'result_rank'],
    permissions: {},
    validation: {},
  },
  { collection: 'bu_tests', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'bu_drill_results',
    action: 'create',
    fields: ['id', 'test_id', 'drill_id', 'attempts', 'score', 'recorded_at'],
    permissions: {},
    validation: {},
  },
  { collection: 'bu_drill_results', action: 'read', fields: ['*'], permissions: { user_created: self } },
```

- [ ] **Step 2: Add the checks to `verify.mjs`**

Insert before the line `const adminRole = (await call('GET', '/roles?filter[name][_eq]=Administrator', undefined, admin.access_token)).data?.[0]?.id;`:

```js
  // ─── Đánh giá + hạng: player_ranks, bu_tests, bu_drill_results ──────────
  if (aId && bId) {
    const rank = { id: aId, rank: 'h', source: 'estimated', bu_score: null, test_id: null,
      warning_rank: null, warning_test_id: null, questionnaire_answers: [0, 0, 0, 2, 1, 0, 0, 0],
      onboarding_state: 'done', updated_at: '2026-10-14T03:00:00.000Z' };
    const made = await call('POST', '/items/player_ranks', rank, a.access_token);
    made.status === 200 ? ok('A tạo được dòng hạng của mình') : fail(`A tạo dòng hạng → ${made.status} ${made.code}`);
    const forgedRank = await call('POST', '/items/player_ranks', { ...rank, id: bId }, a.access_token);
    forgedRank.status >= 400 ? ok(`A không tạo được dòng hạng mang id của B → ${forgedRank.status}`) : fail('A tạo được dòng hạng mang id của B');
    const patched = await call('PATCH', `/items/player_ranks/${aId}`, { rank: 'g', updated_at: '2026-10-15T03:00:00.000Z' }, a.access_token);
    patched.status === 200 ? ok('A sửa được dòng hạng của mình') : fail(`A sửa dòng hạng → ${patched.status} ${patched.code}`);
    const bRanks = await call('GET', '/items/player_ranks', undefined, b.access_token);
    (bRanks.data ?? []).length === 0 ? ok('B không thấy hạng của A') : fail(`B thấy ${bRanks.data.length} dòng hạng`);
    const bPatch = await call('PATCH', `/items/player_ranks/${aId}`, { rank: 'a' }, b.access_token);
    bPatch.status === 403 ? ok('B không sửa được hạng của A') : fail(`B sửa hạng của A → ${bPatch.status}`);

    const testId = randomUUID();
    const buTest = { id: testId, started_at: '2026-10-14T02:00:00.000Z', completed_at: '2026-10-14T04:00:00.000Z',
      cancelled_at: null, table_size: 'nineFootPlus', exam_i_score: 60, exam_ii_version: 'masters',
      exam_ii_score: 77, total_score: 137, result_rank: 'd' };
    const tMade = await call('POST', '/items/bu_tests', buTest, a.access_token);
    tMade.status === 200 ? ok('A tạo được lần kiểm tra') : fail(`A tạo lần kiểm tra → ${tMade.status} ${tMade.code}`);
    const tAgain = await call('POST', '/items/bu_tests', buTest, a.access_token);
    note(`gửi lại lần kiểm tra cùng id → status ${tAgain.status}, code ${tAgain.code}`);
    const tPatch = await call('PATCH', `/items/bu_tests/${testId}`, { total_score: 200 }, a.access_token);
    tPatch.status === 403 ? ok('A không sửa được lần kiểm tra đã gửi') : fail(`A sửa lần kiểm tra → ${tPatch.status}`);
    const rMade = await call('POST', '/items/bu_drill_results', { id: randomUUID(), test_id: testId, drill_id: 'S10',
      attempts: { breaks: [[true, true, false, true, false]] }, score: null, recorded_at: '2026-10-14T03:30:00.000Z' }, a.access_token);
    rMade.status === 200 ? ok('A tạo được kết quả bài') : fail(`A tạo kết quả bài → ${rMade.status} ${rMade.code}`);
    const rList = await call('GET', '/items/bu_drill_results?fields=attempts', undefined, a.access_token);
    typeof rList.data?.[0]?.attempts === 'object' ? ok('attempts về dạng JSON, không phải chuỗi') : fail(`attempts về dạng ${typeof rList.data?.[0]?.attempts}`);
    const bTests = await call('GET', '/items/bu_tests', undefined, b.access_token);
    (bTests.data ?? []).length === 0 ? ok('B không thấy lần kiểm tra của A') : fail(`B thấy ${bTests.data.length} lần kiểm tra`);
  } else {
    fail('thiếu id của A hoặc B, bỏ qua phần hạng');
  }
```

- [ ] **Step 3: Syntax check only**

```bash
node --check deploy/directus/bootstrap.mjs
node --check deploy/directus/verify.mjs
```

Expected: no output.

- [ ] **Step 4: Commit the scripts**

```bash
git add deploy/directus/bootstrap.mjs deploy/directus/verify.mjs
git commit -m "Provision the rank and BU test collections in Directus and verify their permissions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: STOP — ask the owner before touching the live server**

Creating collections is an outward action on the production Directus (`test-va`, the only server). Show the owner, verbatim:
- the three collections and their fields (Step 1);
- the seven new permissions;
- that `bootstrap.mjs` replaces the Player policy's permissions by creating the new set first and deleting the old set after (existing behaviour, lines 172–197);
- that `verify.mjs` registers two throwaway users and deletes them at the end.

Ask: *"Chạy bootstrap.mjs rồi verify.mjs trên Directus thật bây giờ được không?"* Do nothing until the owner says yes. Tasks 11–16 can proceed while waiting; Task 17 cannot.

- [ ] **Step 6: After the owner says yes — run against production**

Load the secrets from the main checkout without printing them:

```bash
eval "$(node -e "const e=require('C:/Users/anhnpv/Desktop/PoolCoachAI/.claude/settings.local.json').env;for(const k of ['DIRECTUS_URL','DIRECTUS_ADMIN_EMAIL','DIRECTUS_ADMIN_PASSWORD','MAILPIT_URL','MAILPIT_USER','MAILPIT_PASSWORD'])if(e[k])console.log('export '+k+'='+JSON.stringify(e[k]))")"
node deploy/directus/bootstrap.mjs
node deploy/directus/verify.mjs
```

Expected: `bootstrap.mjs` prints `Tạo collection …` three times (or nothing new on a re-run) and `Xong. …`; `verify.mjs` ends with `Tất cả kiểm tra đều qua`. If the rank-id validation check fails (`A tạo được dòng hạng mang id của B`), **stop and report** — do not loosen the permission. Paste both outputs into the log under `## Directus (<date>)` and commit the log:

```bash
git add docs/superpowers/logs/2026-10-14-assessment-rank.md
git commit -m "Log the Directus bootstrap and verification of the assessment collections

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 11: BU layouts in *chấm*, drill set-up text, and the scoring lines (spec §5.5, §5.1, §5.2)

> **Needs:** `pdftoppm` for the 14-page Exam II PDFs (Task 0 Step 4). Exam I (8 pages) can be read whole without `pages`.

**Files:**
- Create: `lib/domain/assessment/bu_layouts.dart`
- Modify: `lib/core/strings/vi.dart` (section `// Đánh giá + hạng — cách chấm và cách xếp bài` before the final `}`)
- Test: `test/domain/assessment/bu_layouts_test.dart`
- Modify: `test/core/strings/vi_assessment_test.dart` (append tests)
- Modify: `docs/superpowers/logs/2026-10-14-assessment-rank.md` (one line per transcribed page)

**Interfaces:**
- Consumes: `BuDrill`, `examIDrills`, `examIIDrills` (Task 4); `ExamIIVersion` (Task 2); `Pocket`, `TableSpec` (`lib/domain/table_geometry/table_spec.dart`); `Vec2`; `longRailDiamonds`, `shortRailDiamonds` (`lib/domain/planner/planner_constants.dart`, both already 8 and 4).
- Produces:
  - `final class Cham { const Cham(double x, double y); }`;
  - `Vec2 chamToTable(Cham c, TableSpec table)`, `Cham pocketCham(Pocket p)`, `Cham lerpCham(Cham a, Cham b, double t)`, `List<Cham> evenlySpaced(Cham from, Cham to, int count)`;
  - `sealed class LayoutMark` with `ObjectBall(int number, Cham at)`, `CueBall(Cham at)`, `CueBallInHand()`, `SpotRing(Cham at)`, `TargetZone(Cham from, Cham to)`, `LadderPosition(int position, Cham at)`, `AimPath(List<Cham> points, {bool dashed})`, `TargetPocket(Pocket pocket)`;
  - `final class BuLayout { const BuLayout({required String drillId, required List<LayoutMark> marks, required String source, ExamIIVersion? version, int variant = 1}); }`;
  - `List<BuLayout> layoutsFor(String drillId, ExamIIVersion? version)`, `List<BuLayout> allLayouts()`, `BuLayout layoutForAttempt(BuDrill drill, ExamIIVersion? version, int attemptIndex)`;
  - `Vi.buDrillScoring(String drillId, ExamIIVersion? v)`, `Vi.buDrillSetup(String drillId, ExamIIVersion? v)`, `Vi.buBreakCriterion(int index)`.

**Coordinate format (spec §5.5).** A point is `Cham(x, y)`: `x` 0–8 along the long rail from the **left** corner, `y` 0–4 from the **top** rail down, origin top-left, in table-diagram orientation exactly as printed in the PDF (head of the table on the side the PDF draws it). Halves and quarters are allowed (`Cham(2.5, 1)`); anything finer must be justified in a comment quoting the PDF's own measurement. `chamToTable` turns it into cm on the app's table (`x · length / 8`, `y · width / 4`), so the same layout draws on any table size.

**Two kinds of layout.**
- *Transcribed* (S2, S3, S4, S6, S7, S10, every version, every numbered diagram): each ball sits on or between diamond lines in the PDF figure. Read the coordinates off the figure.
- *Constructed by rule* (F1–F8, S5, S8): the PDF gives the set-up as a rule (ladder positions 1–7, the paper target, "object ball halfway between the cue ball and the pocket"). Write each as a function that builds the marks with `lerpCham`, `evenlySpaced` and `pocketCham`, and put the PDF's rule sentence, verbatim in English, in its doc comment.

**Nobody invents a coordinate.** If a figure is ambiguous (a ball not on a line, a rule that does not fix a position), stop and ask the owner with a screenshot of the page; do not guess.

- [ ] **Step 1: Write the failing test**

`test/domain/assessment/bu_layouts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

Iterable<Cham> _points(LayoutMark m) => switch (m) {
      ObjectBall(:final at) || CueBall(:final at) || SpotRing(:final at) || LadderPosition(:final at) => [at],
      TargetZone(:final from, :final to) => [from, to],
      AimPath(:final points) => points,
      CueBallInHand() || TargetPocket() => const [],
    };

void main() {
  const table = TableSpec.nineFoot;

  group('toạ độ chấm (spec mục 5.5)', () {
    test('gốc trên trái, x dọc băng dài 0–8, y từ băng trên 0–4', () {
      expect(chamToTable(const Cham(0, 0), table), const Vec2(0, 0));
      expect(chamToTable(const Cham(8, 4), table), Vec2(table.length, table.width));
      expect(chamToTable(const Cham(4, 2), table), Vec2(table.length / 2, table.width / 2));
    });

    test('chấm của sáu lỗ khớp vị trí lỗ của bàn', () {
      for (final p in Pocket.values) {
        expect(chamToTable(pocketCham(p), table), table.pocketPosition(p), reason: '$p');
      }
    });

    test('lerpCham và evenlySpaced', () {
      expect(lerpCham(const Cham(0, 0), const Cham(8, 4), 0.5), const Cham(4, 2));
      expect(evenlySpaced(const Cham(1, 1), const Cham(7, 1), 4),
          const [Cham(1, 1), Cham(3, 1), Cham(5, 1), Cham(7, 1)]);
      expect(evenlySpaced(const Cham(1, 1), const Cham(7, 1), 1), const [Cham(1, 1)]);
    });
  });

  test('ví dụ đã đo của spec: Bachelors S3 thế 1 (trang 3)', () {
    final s3 = layoutsFor('S3', ExamIIVersion.bachelors).firstWhere((l) => l.variant == 1);
    expect(s3.source, 'BU_Exam-II_Skills-Bachelors.pdf, trang 3');
    expect(s3.marks, const [
      CueBallInHand(),
      ObjectBall(5, Cham(1, 1)),
      ObjectBall(8, Cham(3, 1)),
      ObjectBall(9, Cham(5, 1)),
      ObjectBall(7, Cham(1, 3)),
      ObjectBall(6, Cham(3, 3)),
      SpotRing(Cham(6, 2)),
    ]);
  });

  group('đủ sơ đồ cho mọi bài', () {
    test('mỗi bài Đề I và mỗi bài của từng bản Đề II có ít nhất một sơ đồ', () {
      for (final d in examIDrills) {
        expect(layoutsFor(d.id, null), isNotEmpty, reason: d.id);
      }
      for (final v in ExamIIVersion.values) {
        for (final d in examIIDrills(v)) {
          expect(layoutsFor(d.id, v), isNotEmpty, reason: '${d.id} $v');
        }
      }
    });

    test('S3, S4: đúng 3 thế mỗi bản (phiếu điểm "layout 1 2 3")', () {
      for (final v in ExamIIVersion.values) {
        for (final id in ['S3', 'S4']) {
          expect(layoutsFor(id, v).map((l) => l.variant).toList(), [1, 2, 3], reason: '$id $v');
        }
      }
    });

    test('thang vị trí F1–F5: đủ vị trí 1–7, mỗi vị trí một lần', () {
      for (final id in ['F1', 'F2', 'F3', 'F4', 'F5']) {
        for (final l in layoutsFor(id, null)) {
          final positions = l.marks.whereType<LadderPosition>().map((m) => m.position).toList()..sort();
          expect(positions, [1, 2, 3, 4, 5, 6, 7], reason: id);
        }
      }
    });
  });

  group('mọi sơ đồ đều hợp lệ', () {
    final source = RegExp(
        r'^BU_Exam-(I_Fundamentals|II_Skills-(Bachelors|Masters|Doctorate))\.pdf, trang \d+$');

    test('nguồn ghi đúng file và trang', () {
      for (final l in allLayouts()) {
        expect(l.source, matches(source), reason: '${l.drillId} ${l.version} ${l.variant}');
        if (l.version != null) {
          final name = switch (l.version!) {
            ExamIIVersion.bachelors => 'Bachelors',
            ExamIIVersion.masters => 'Masters',
            ExamIIVersion.doctorate => 'Doctorate',
          };
          expect(l.source, contains(name), reason: '${l.drillId} ${l.version}');
        } else {
          expect(l.source, contains('Fundamentals'), reason: l.drillId);
        }
      }
    });

    test('mọi điểm nằm trong lưới 8 × 4', () {
      for (final l in allLayouts()) {
        for (final p in l.marks.expand(_points)) {
          expect(p.x, inInclusiveRange(0, 8), reason: '${l.drillId} $p');
          expect(p.y, inInclusiveRange(0, 4), reason: '${l.drillId} $p');
        }
      }
    });

    test('số bi 1–15, không trùng; nhiều nhất một bi cái', () {
      for (final l in allLayouts()) {
        final numbers = l.marks.whereType<ObjectBall>().map((b) => b.number).toList();
        expect(numbers.every((n) => n >= 1 && n <= 15), isTrue, reason: l.drillId);
        expect(numbers.toSet().length, numbers.length, reason: l.drillId);
        final cues = l.marks.where((m) => m is CueBall || m is CueBallInHand).length;
        expect(cues, lessThanOrEqualTo(1), reason: l.drillId);
      }
    });

    test('các bi không chồng lên nhau', () {
      for (final l in allLayouts()) {
        final centres = [
          for (final m in l.marks)
            if (m case ObjectBall(:final at) || CueBall(:final at)) chamToTable(at, table),
        ];
        for (var i = 0; i < centres.length; i++) {
          for (var j = i + 1; j < centres.length; j++) {
            expect(centres[i].distanceTo(centres[j]), greaterThanOrEqualTo(table.ballDiameter - 0.01),
                reason: '${l.drillId} ${l.version} ${l.variant}');
          }
        }
      }
    });
  });

  test('chọn sơ đồ theo lượt: S3 lượt 1, 2, 3 → thế 1, 2, 3', () {
    final s3 = drillFor('S3', ExamIIVersion.masters);
    expect([for (var i = 0; i < 3; i++) layoutForAttempt(s3, ExamIIVersion.masters, i).variant], [1, 2, 3]);
    final f1 = drillFor('F1', null);
    expect(layoutForAttempt(f1, null, 9).drillId, 'F1');
  });
}
```

If `Vec2` has no `distanceTo`, use the method the planner uses for distances (`lib/domain/table_geometry/vec2.dart`; `separate.dart` calls `q.distanceTo(o)`).

Run `"$FLUTTER" test test/domain/assessment/bu_layouts_test.dart`. Expected: FAIL — the file does not exist.

- [ ] **Step 2: Write the skeleton of `bu_layouts.dart` with the worked example**

```dart
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/planner/planner_constants.dart'
    show longRailDiamonds, shortRailDiamonds;
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/domain/table_geometry/vec2.dart';

/// Một điểm trên mặt bàn đo bằng chấm (spec mục 5.5): x 0–8 dọc băng dài
/// từ góc trái, y 0–4 từ băng trên xuống. Đo theo chấm thì cùng một sơ đồ vẽ
/// đúng trên bàn 7, 8 hay 9 feet.
final class Cham {
  const Cham(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is Cham && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Cham($x, $y)';
}

Vec2 chamToTable(Cham c, TableSpec table) => Vec2(
    table.length * c.x / longRailDiamonds, table.width * c.y / shortRailDiamonds);

Cham pocketCham(Pocket p) => switch (p) {
      Pocket.topLeft => const Cham(0, 0),
      Pocket.topMiddle => const Cham(4, 0),
      Pocket.topRight => const Cham(8, 0),
      Pocket.bottomLeft => const Cham(0, 4),
      Pocket.bottomMiddle => const Cham(4, 4),
      Pocket.bottomRight => const Cham(8, 4),
    };

/// Điểm ở [t] phần đường từ [a] tới [b] — "bi mục tiêu nằm giữa bi cái và
/// lỗ" là `lerpCham(cue, pocketCham(pocket), 0.5)`.
Cham lerpCham(Cham a, Cham b, double t) =>
    Cham(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

/// [count] điểm cách đều từ [from] tới [to], gồm cả hai đầu.
List<Cham> evenlySpaced(Cham from, Cham to, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count');
  if (count == 1) return [from];
  return [for (var i = 0; i < count; i++) lerpCham(from, to, i / (count - 1))];
}

/// Một thứ vẽ trên sơ đồ.
sealed class LayoutMark {
  const LayoutMark();
}

final class ObjectBall extends LayoutMark {
  const ObjectBall(this.number, this.at);
  final int number;
  final Cham at;

  @override
  bool operator ==(Object other) => other is ObjectBall && other.number == number && other.at == at;
  @override
  int get hashCode => Object.hash(number, at);
}

final class CueBall extends LayoutMark {
  const CueBall(this.at);
  final Cham at;

  @override
  bool operator ==(Object other) => other is CueBall && other.at == at;
  @override
  int get hashCode => at.hashCode;
}

/// Bi cái đặt tự do (ball in hand): không vẽ bi cái.
final class CueBallInHand extends LayoutMark {
  const CueBallInHand();

  @override
  bool operator ==(Object other) => other is CueBallInHand;
  @override
  int get hashCode => 0;
}

/// Vòng giấy dán / chấm đặt bi.
final class SpotRing extends LayoutMark {
  const SpotRing(this.at);
  final Cham at;

  @override
  bool operator ==(Object other) => other is SpotRing && other.at == at;
  @override
  int get hashCode => at.hashCode;
}

/// Vùng đích hình chữ nhật (khung giấy đích, ô 2 × 1 chấm …).
final class TargetZone extends LayoutMark {
  const TargetZone(this.from, this.to);
  final Cham from;
  final Cham to;

  @override
  bool operator ==(Object other) => other is TargetZone && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

/// Vị trí 1–7 của thang vị trí F1–F5.
final class LadderPosition extends LayoutMark {
  const LadderPosition(this.position, this.at);
  final int position;
  final Cham at;

  @override
  bool operator ==(Object other) =>
      other is LadderPosition && other.position == position && other.at == at;
  @override
  int get hashCode => Object.hash(position, at);
}

/// Đường đi PDF vẽ (đường bi cái, đường bi mục tiêu).
final class AimPath extends LayoutMark {
  const AimPath(this.points, {this.dashed = false});
  final List<Cham> points;
  final bool dashed;

  @override
  bool operator ==(Object other) {
    if (other is! AimPath || other.dashed != dashed || other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (points[i] != other.points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(points), dashed);
}

/// Lỗ đích của bài.
final class TargetPocket extends LayoutMark {
  const TargetPocket(this.pocket);
  final Pocket pocket;

  @override
  bool operator ==(Object other) => other is TargetPocket && other.pocket == pocket;
  @override
  int get hashCode => pocket.hashCode;
}

/// Một sơ đồ xếp bi của đề BU. [source] là file PDF và trang đã đo, dạng
/// `'BU_Exam-II_Skills-Bachelors.pdf, trang 3'`.
final class BuLayout {
  const BuLayout({
    required this.drillId,
    required this.marks,
    required this.source,
    this.version,
    this.variant = 1,
  });

  final String drillId;
  final ExamIIVersion? version;

  /// Thế / hình số mấy của bài (S3, S4: 1–3).
  final int variant;
  final List<LayoutMark> marks;
  final String source;
}

// ─── Sơ đồ chép từ PDF (S2, S3, S4, S6, S7, S10) ────────────────────────────

const _transcribed = <BuLayout>[
  // Ví dụ đã đo trong spec mục 5.5.
  BuLayout(
    drillId: 'S3',
    version: ExamIIVersion.bachelors,
    variant: 1,
    source: 'BU_Exam-II_Skills-Bachelors.pdf, trang 3',
    marks: [
      CueBallInHand(),
      ObjectBall(5, Cham(1, 1)),
      ObjectBall(8, Cham(3, 1)),
      ObjectBall(9, Cham(5, 1)),
      ObjectBall(7, Cham(1, 3)),
      ObjectBall(6, Cham(3, 3)),
      SpotRing(Cham(6, 2)),
    ],
  ),
];

// ─── Sơ đồ dựng theo luật (F1–F8, S5, S8) ───────────────────────────────────

List<BuLayout> _constructed() => [];

List<BuLayout> allLayouts() {
  final all = [..._transcribed, ..._constructed()];
  int examRank(BuLayout l) => l.version?.index ?? -1;
  int drillRank(BuLayout l) =>
      [...examIDrills.map((d) => d.id), for (var i = 1; i <= 10; i++) 'S$i'].indexOf(l.drillId);
  all.sort((a, b) {
    final byExam = (a.drillId.startsWith('F') ? -1 : examRank(a))
        .compareTo(b.drillId.startsWith('F') ? -1 : examRank(b));
    if (byExam != 0) return byExam;
    final byDrill = drillRank(a).compareTo(drillRank(b));
    return byDrill != 0 ? byDrill : a.variant.compareTo(b.variant);
  });
  return all;
}

List<BuLayout> layoutsFor(String drillId, ExamIIVersion? version) => [
      for (final l in allLayouts())
        if (l.drillId == drillId && (drillId.startsWith('F') || l.version == version)) l,
    ];

/// Sơ đồ cho lượt thứ [attemptIndex] (từ 0): chia đều số lượt của bài cho
/// số sơ đồ đã chép — S3 lượt 2 là thế 2, bài một sơ đồ thì luôn sơ đồ đó.
BuLayout layoutForAttempt(BuDrill drill, ExamIIVersion? version, int attemptIndex) {
  final layouts = layoutsFor(drill.id, version);
  if (layouts.isEmpty) throw StateError('Chưa có sơ đồ cho ${drill.id} $version');
  final i = attemptIndex * layouts.length ~/ drill.attemptCount;
  return layouts[i.clamp(0, layouts.length - 1)];
}
```

Run the test: the coordinate, example, `layoutForAttempt` and validity groups pass; the coverage group fails (only one layout exists). That failure is this task's to-do list.

- [ ] **Step 3: Transcribe every layout from the PDFs**

Procedure, one page at a time:
1. Read the page with the Read tool (`pages: "<n>"`) from the temp directory of Task 0. Never copy a PDF into the repo.
2. For a transcribed drill, add one `BuLayout` constant per numbered diagram to `_transcribed`, in the shape of the S3 example: `drillId`, `version`, `variant`, `source: '<file>, trang <n>'`, and the marks in reading order — `CueBall` or `CueBallInHand` first, then `ObjectBall`s by number, then `SpotRing` / `TargetZone` / `AimPath` / `TargetPocket` as printed.
3. For a constructed drill, add a function and call it from `_constructed()`:

   ```dart
   /// <drill id> — "<the PDF's set-up sentence, verbatim>"
   /// (<file>, trang <n>).
   BuLayout _<id>() { … marks built with pocketCham / lerpCham / evenlySpaced … }
   ```

   For example, the illustrative rule "object ball halfway between the cue ball and the top-right pocket", with the cue ball at a position the PDF fixes, is written `ObjectBall(1, lerpCham(cue, pocketCham(Pocket.topRight), 0.5))` — the helper call *is* the rule, so a reviewer can check it against the sentence. F1–F5 must contain `LadderPosition` 1–7 (spec §5.5).
4. While on each drill's page, also write its set-up text (Step 4) and re-check its scoring rule against spec §5.1–§5.2. Confirm that the S9 pages allow either jump or massé (D2), that S9 Doctorate lacks the "được chết cái" line (spec §5.2), S3 Doctorate layout 3 ("3–4 băng"), and S4 "được chạm bi chướng ngại". A disagreement with the spec: stop and report to the owner.
5. Append one line per page to the log: `- <file> trang <n>: <drill ids> — <transcribed | constructed>`.

Re-run `"$FLUTTER" test test/domain/assessment/bu_layouts_test.dart` after each drill. Done when every group passes.

- [ ] **Step 4: Scoring lines, set-up text and S10 criteria — failing test first**

Append inside `main` of `test/core/strings/vi_assessment_test.dart`:

```dart
  test('mọi bài, mọi bản đều có cách chấm và cách xếp bài', () {
    for (final d in examIDrills) {
      expect(Vi.buDrillScoring(d.id, null), isNotEmpty, reason: d.id);
      expect(Vi.buDrillSetup(d.id, null), isNotEmpty, reason: d.id);
    }
    for (final v in ExamIIVersion.values) {
      for (final d in examIIDrills(v)) {
        expect(Vi.buDrillScoring(d.id, v), isNotEmpty, reason: '${d.id} $v');
        expect(Vi.buDrillSetup(d.id, v), isNotEmpty, reason: '${d.id} $v');
      }
    }
  });

  test('cách chấm theo đúng chữ của spec', () {
    expect(Vi.buDrillScoring('S3', ExamIIVersion.doctorate), contains('3–4 băng'));
    expect(Vi.buDrillScoring('S3', ExamIIVersion.bachelors), isNot(contains('3–4 băng')));
    expect(Vi.buDrillScoring('S4', ExamIIVersion.masters), contains('chướng ngại'));
    expect(Vi.buDrillScoring('S1', ExamIIVersion.masters), contains('không cần lượt 2'));
    expect(Vi.buBreakCriterion(0), 'a: không chết cái');
    expect(Vi.buBreakCriterion(4),
        'e: a, và có ít nhất 3 bi mục tiêu vào lỗ hoặc vượt qua vạch đầu bàn');
  });

  test('không chữ nào dùng từ cấm', () {
    final all = <String>[
      for (final d in examIDrills) ...[Vi.buDrillScoring(d.id, null), Vi.buDrillSetup(d.id, null)],
      for (final v in ExamIIVersion.values)
        for (final d in examIIDrills(v)) ...[Vi.buDrillScoring(d.id, v), Vi.buDrillSetup(d.id, v)],
    ];
    for (final s in all) {
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(s.toLowerCase(), isNot(contains(banned)), reason: s);
      }
    }
  });
```

Run: FAIL (members missing). Then add to `vi.dart`:

```dart
  // ─── Đánh giá + hạng — cách chấm và cách xếp bài ───────────────────────────
  //
  // Cách chấm: chữ của spec mục 5.1, 5.2 (đã đối chiếu PDF ở Task 11).
  // Cách xếp bài: dịch từ PDF của Billiard University, chủ sản phẩm duyệt
  // khi xem sơ đồ trên Chrome (D13 của kế hoạch).

  static const _ladderRule = 'Thang vị trí: bắt đầu ở vị trí 4, vào thì lên một vị trí, '
      'trượt thì xuống một (trong khoảng 1–7). Đánh đủ 10 cú. Điểm = vị trí cuối + '
      'số lần vào khi đang ở vị trí 7, tối đa 10.';

  static String buDrillScoring(String drillId, ExamIIVersion? v) => switch (drillId) {
        'F1' => _ladderRule,
        'F2' => '$_ladderRule Bi mục tiêu phải vào và bi cái dừng chồng lên vòng bi ảo.',
        'F3' => '$_ladderRule Bi cái dừng trong hoặc chồng lên khung giấy đích.',
        'F4' => '$_ladderRule Tâm bi cái dừng trong hình chữ nhật 2×1 chấm cạnh lỗ giữa.',
        'F5' => '$_ladderRule Đích di chuyển thay cho bi cái: vị trí 1–3 đi thẳng tới đích, '
            '5–7 phải bật băng cuối.',
        'F6' => '10 cú, mỗi cú 1 lượt, không được chết cái. Mỗi bi vào 1 điểm.',
        'F7' => '10 bi đích trên băng, mỗi bi 2 lượt. Vào lỗ và chạm đúng bi đích được 1 điểm.',
        'F8' => '5 đích, mỗi đích 4 lượt. Vào lỗ và bi cái dừng trong hoặc chồng lên đích '
            'được 1 điểm.',
        'S1' => 'Đánh theo thứ tự số, 2 lượt, lấy lượt cao hơn. Lượt 1 trọn điểm thì '
            'không cần lượt 2.',
        'S2' => '2 lượt, thứ tự tùy ý, lấy lượt cao hơn. Lượt 1 trọn điểm thì không cần lượt 2.',
        'S3' => '3 thế, mỗi bi hợp lệ theo thứ tự được 1 điểm, cộng 2 thế thấp nhất. Bi 9 '
            'vào sớm thì vẫn đánh nốt các bi còn lại theo thứ tự.'
            '${v == ExamIIVersion.doctorate ? ' Thế 3: phải tới bi 7 và bi 9 bằng 3–4 băng.' : ''}',
        'S4' => '3 thế, mỗi bi trước khi trượt được 1 điểm, cộng 2 thế thấp nhất. '
            'Được chạm bi chướng ngại.',
        'S5' => 'Mỗi vị trí bi cái 2 lượt, mỗi lần bắt đui được 1 điểm.',
        'S6' || 'S7' || 'S8' => 'Mỗi cú thành công 1 điểm.',
        'S9' => 'Dùng nhảy bi (Jump) hoặc mát xê (Massé). Mỗi cú thành công 1 điểm.'
            '${v == ExamIIVersion.doctorate ? ' Bản Doctorate không cho chết cái.' : ''}',
        'S10' => '3 lần phá, mỗi lần chấm 5 tiêu chí a–e, lấy trung vị điểm của 3 lần.',
        _ => throw ArgumentError.value(drillId, 'drillId'),
      };

  static String buBreakCriterion(int index) => switch (index) {
        0 => 'a: không chết cái',
        1 => 'b: a, và bi cái không chạm băng',
        2 => 'c: a, và bi cái dừng trong vùng 4 chấm ở giữa bàn',
        3 => 'd: a, và có ít nhất 1 bi vào',
        4 => 'e: a, và có ít nhất 3 bi mục tiêu vào lỗ hoặc vượt qua vạch đầu bàn',
        _ => throw RangeError.range(index, 0, 4, 'index'),
      };

  /// Cách xếp bài, dịch từ PDF (Task 11 Step 3). Một nhánh cho mỗi bài; bài
  /// Đề II mà các bản khác nhau thì rẽ theo [v].
  static String buDrillSetup(String drillId, ExamIIVersion? v) => switch (drillId) {
        _ => throw ArgumentError.value(drillId, 'drillId', 'chưa dịch cách xếp bài'),
      };
```

The S9 Doctorate sentence must match what the Doctorate PDF actually says (Step 3 point 4); fix the wording to the PDF if it differs, and tell the owner. Then fill `buDrillSetup` with one arm per drill (above the `_` arm), translating the PDF's set-up paragraph into Vietnamese with the owner's terms (Global Constraints). Run until PASS:

```bash
"$FLUTTER" test test/domain/assessment test/core/strings
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/assessment/bu_layouts.dart lib/core/strings/vi.dart test/domain/assessment/bu_layouts_test.dart test/core/strings/vi_assessment_test.dart docs/superpowers/logs/2026-10-14-assessment-rank.md
git commit -m "Transcribe every BU table layout in diamond coordinates with its set-up and scoring text

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Drawing the layouts, and the `/rank/layouts` gallery (spec §5.5, D12)

**Files:**
- Modify: `lib/features/training/presentation/simulator/table_drawing.dart` (append `drawDiamondNumbers`, `drawCenteredLabel`)
- Modify: `lib/features/training/presentation/planner/planner_painter.dart` (delete `_diamondNumbers` and `_label` at lines 297–326; call sites at lines 256 and 288)
- Create: `lib/features/rank/presentation/bu_layout_painter.dart`
- Create: `lib/features/rank/presentation/layout_gallery_screen.dart`
- Modify: `lib/core/router/routes.dart` (constant + `Routes.all`), `lib/core/router/app_router.dart` (route after `Routes.notifications` at lines 129–132)
- Modify: `lib/core/strings/vi.dart` (gallery strings)
- Modify: `test/smoke/all_routes_test.dart` (`_routeCases` at lines 15–37)
- Test: `test/features/rank/bu_layout_painter_test.dart`

**Interfaces:**
- Consumes: `TableLayout`, `drawTableBed` (`table_drawing.dart`); `drawPoolBall` (`planner_painter.dart`); `BuLayout`, marks, `chamToTable`, `allLayouts` (Task 11); `Vi.buDrillTitle`, `Vi.buVersionName`, `Vi.buDrillSetup`.
- Produces:
  - `void drawDiamondNumbers(Canvas canvas, TableLayout layout)`, `void drawCenteredLabel(Canvas canvas, Offset center, String text, double radius, Color color)`;
  - `class BuLayoutPainter extends CustomPainter { BuLayoutPainter(BuLayout layout, {int? highlightPosition}); }`;
  - `class BuLayoutView extends StatelessWidget { const BuLayoutView({required BuLayout layout, int? highlightPosition, String? semanticLabel}); }`;
  - `class LayoutGalleryScreen extends StatelessWidget { const LayoutGalleryScreen({int? index}); }`;
  - `Routes.rankLayouts = '/rank/layouts'`, `Routes.rankLayoutAt(int i)`;
  - `Vi.buLayoutsTitle`, `Vi.buLayoutCaption(BuLayout l, int k, int n)`, `Vi.buLayoutSource(String source)`, `Vi.buLayoutsEnd`.

- [ ] **Step 1: Move the diamond numbers into `table_drawing.dart`**

Append to `table_drawing.dart` (add the import `package:poolcoachai/domain/planner/planner_constants.dart` for `longRailDiamonds` / `shortRailDiamonds`):

```dart
/// Số chấm trên khung bàn: băng dài 0–8 từ góc trái, băng ngắn 0–4 từ góc
/// trên. Dùng chung cho Kế hoạch dọn bàn và sơ đồ bài kiểm tra BU.
void drawDiamondNumbers(Canvas canvas, TableLayout layout) {
  final t = layout.table;
  const f = TableLayout.frame;
  final size = math.max(8.0, f * 0.55 * layout.scale);
  void put(int n, Vec2 at) =>
      drawCenteredLabel(canvas, layout.toCanvas(at), '$n', size / 0.8, AppColors.textPrimary);
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
void drawCenteredLabel(Canvas canvas, Offset center, String text, double radius, Color color) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}
```

In `planner_painter.dart` delete the methods `_diamondNumbers` and `_label`, replace `_diamondNumbers(canvas, layout)` with `drawDiamondNumbers(canvas, layout)` and `_label(` with `drawCenteredLabel(`. Remove imports that become unused.

Run `"$FLUTTER" test test/features/training`: expected PASS (pure move). Commit:

```bash
git add lib/features/training/presentation/simulator/table_drawing.dart lib/features/training/presentation/planner/planner_painter.dart
git commit -m "Move the diamond numbers into the shared table drawing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Write the failing painter test**

`test/features/rank/bu_layout_painter_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

class _SpyCanvas implements Canvas {
  final circles = <(Offset, Color)>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add((c, paint.color));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const size = Size(540, 286);
  const layout = BuLayout(
    drillId: 'F1',
    source: 'BU_Exam-I_Fundamentals.pdf, trang 2',
    marks: [
      CueBall(Cham(2, 2)),
      ObjectBall(1, Cham(4, 2)),
      LadderPosition(4, Cham(3, 1)),
      LadderPosition(5, Cham(3.5, 1)),
    ],
  );

  Offset at(Cham c) =>
      const TableLayout(size: size).toCanvas(chamToTable(c, TableSpec.nineFoot));

  bool near(Offset a, Offset b) => (a - b).distance < 0.01;

  test('vẽ bi đúng chỗ của chấm', () {
    final canvas = _SpyCanvas();
    BuLayoutPainter(layout).paint(canvas, size);
    expect(canvas.circles.any((c) => near(c.$1, at(const Cham(2, 2)))), isTrue, reason: 'bi cái');
    expect(canvas.circles.any((c) => near(c.$1, at(const Cham(4, 2)))), isTrue, reason: 'bi 1');
  });

  test('tô vị trí hiện tại của thang bằng màu nhấn, vị trí khác thì không', () {
    final canvas = _SpyCanvas();
    BuLayoutPainter(layout, highlightPosition: 5).paint(canvas, size);
    final five = canvas.circles.where((c) => near(c.$1, at(const Cham(3.5, 1))));
    final four = canvas.circles.where((c) => near(c.$1, at(const Cham(3, 1))));
    expect(five.any((c) => c.$2 == AppColors.accent), isTrue);
    expect(four.any((c) => c.$2 == AppColors.accent), isFalse);
  });

  test('vẽ được mọi sơ đồ đã chép mà không lỗi', () {
    for (final l in allLayouts()) {
      final recorder = PictureRecorder();
      BuLayoutPainter(l, highlightPosition: 4).paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }
  });
}
```

Run `"$FLUTTER" test test/features/rank/bu_layout_painter_test.dart`. Expected: FAIL — the painter does not exist.

- [ ] **Step 3: Write `bu_layout_painter.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';
import 'package:poolcoachai/features/training/presentation/planner/planner_painter.dart'
    show drawPoolBall;
import 'package:poolcoachai/features/training/presentation/simulator/table_drawing.dart';

/// Vẽ một sơ đồ BU lên mặt bàn của Kế hoạch dọn bàn (spec mục 5.5).
///
/// Thứ tự từ dưới lên: mặt bàn và số chấm, vùng đích và đường đi, vị trí
/// thang, rồi bi — bi luôn nằm trên cùng.
class BuLayoutPainter extends CustomPainter {
  BuLayoutPainter(this.layout, {this.highlightPosition});

  final BuLayout layout;

  /// Vị trí thang đang đứng (F1–F5), tô màu nhấn.
  final int? highlightPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final l = TableLayout(size: size);
    final t = l.table;
    final r = t.radius * l.scale;
    Offset at(Cham c) => l.toCanvas(chamToTable(c, t));

    final pocket = layout.marks.whereType<TargetPocket>().firstOrNull?.pocket;
    drawTableBed(canvas, l, selected: pocket);
    drawDiamondNumbers(canvas, l);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.textPrimary;

    for (final m in layout.marks) {
      switch (m) {
        case TargetZone(:final from, :final to):
          canvas.drawRect(Rect.fromPoints(at(from), at(to)), line);
        case AimPath(:final points, :final dashed):
          final px = [for (final p in points) at(p)];
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.aimLine;
          dashed ? drawDashedPolyline(canvas, px, paint, l.scale) : drawPolyline(canvas, px, paint);
        case SpotRing(at: final c):
          canvas.drawCircle(at(c), r * 0.6, line);
        default:
          break;
      }
    }

    for (final m in layout.marks) {
      if (m case LadderPosition(:final position, at: final c)) {
        final on = position == highlightPosition;
        canvas.drawCircle(
          at(c),
          r * 0.9,
          Paint()
            ..style = on ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = on ? AppColors.accent : AppColors.textMuted,
        );
        drawCenteredLabel(canvas, at(c), '$position', r,
            on ? AppColors.bgDeep : AppColors.textPrimary);
      }
    }

    for (final m in layout.marks) {
      switch (m) {
        case CueBall(at: final c):
          canvas.drawCircle(at(c), r, Paint()..color = AppColors.ballCue);
        case ObjectBall(:final number, at: final c):
          drawPoolBall(canvas, at(c), r, number);
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(BuLayoutPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.highlightPosition != highlightPosition;
}

/// Mặt bàn đúng tỉ lệ bàn 9 feet, vẽ một sơ đồ.
class BuLayoutView extends StatelessWidget {
  const BuLayoutView({
    required this.layout,
    this.highlightPosition,
    this.semanticLabel,
    super.key,
  });

  final BuLayout layout;
  final int? highlightPosition;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: AspectRatio(
        aspectRatio: TableLayout.aspectRatio(TableSpec.nineFoot),
        child: CustomPaint(
          painter: BuLayoutPainter(layout, highlightPosition: highlightPosition),
        ),
      ),
    );
  }
}
```

The local helper is named `at`, so every pattern binds the mark's `at` field to `c` (`CueBall(at: final c)`), never `:final at`. Run the painter test: expected PASS.

- [ ] **Step 4: The gallery — strings, route, screen, smoke test**

Add to `vi.dart` (import `package:poolcoachai/domain/assessment/bu_layouts.dart`):

```dart
  // Sơ đồ bài kiểm tra — D12 của kế hoạch.
  static const buLayoutsTitle = 'Sơ đồ bài kiểm tra';
  static const buLayoutsEnd = 'Hết sơ đồ.';

  static String buLayoutCaption(BuLayout l, int k, int n) =>
      'Sơ đồ $k / $n · ${buDrillTitle(l.drillId)}'
      '${l.version == null ? '' : ' · ${buVersionName(l.version!)}'} · hình ${l.variant}';

  static String buLayoutSource(String source) => 'Nguồn: Billiard University — $source';
```

In `routes.dart`, after `planner`:

```dart
  /// Sơ đồ mọi bài kiểm tra BU — mở đè lên shell (D12 của kế hoạch).
  static const rankLayouts = '/rank/layouts';

  /// Một sơ đồ theo thứ tự của `allLayouts()` — để chụp từng sơ đồ trên Chrome.
  static String rankLayoutAt(int i) => '$rankLayouts?i=$i';
```

and add `rankLayouts` to `Routes.all` after `planner`. In `app_router.dart`, after the `Routes.notifications` route:

```dart
    GoRoute(
      path: Routes.rankLayouts,
      builder: (context, state) => LayoutGalleryScreen(
        index: int.tryParse(state.uri.queryParameters['i'] ?? ''),
      ),
    ),
```

In `test/smoke/all_routes_test.dart`, add to `_routeCases` (and the import of `layout_gallery_screen.dart`):

```dart
  Routes.rankLayouts: (path: Routes.rankLayouts, screen: LayoutGalleryScreen),
```

Run `"$FLUTTER" test test/smoke`: expected FAIL — `LayoutGalleryScreen` does not exist. Create `lib/features/rank/presentation/layout_gallery_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';

/// Mọi sơ đồ bài kiểm tra BU, theo thứ tự đề → bản → bài → hình.
///
/// Có `?i=` thì chỉ hiện sơ đồ thứ i, to: bài chạy Chrome chụp lần lượt từng
/// sơ đồ cho chủ sản phẩm xem (spec mục 5.5).
class LayoutGalleryScreen extends StatelessWidget {
  const LayoutGalleryScreen({this.index, super.key});

  final int? index;

  @override
  Widget build(BuildContext context) {
    final all = allLayouts();
    final i = index;
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.buLayoutsTitle)),
      body: i == null
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final (k, l) in all.indexed) _LayoutCard(layout: l, k: k + 1, n: all.length),
              ],
            )
          : i >= 0 && i < all.length
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _LayoutCard(layout: all[i], k: i + 1, n: all.length),
                )
              : const Center(child: Text(Vi.buLayoutsEnd)),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({required this.layout, required this.k, required this.n});

  final BuLayout layout;
  final int k;
  final int n;

  @override
  Widget build(BuildContext context) {
    final caption = Vi.buLayoutCaption(layout, k, n);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          BuLayoutView(layout: layout, semanticLabel: caption),
          const SizedBox(height: AppSpacing.sm),
          Text(Vi.buDrillSetup(layout.drillId, layout.version)),
          const SizedBox(height: AppSpacing.xs),
          Text(Vi.buLayoutSource(layout.source), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run and commit**

```bash
"$FLUTTER" test test/features/rank test/smoke test/architecture_test.dart
```

Expected: PASS.

```bash
git add lib/features/rank/presentation/bu_layout_painter.dart lib/features/rank/presentation/layout_gallery_screen.dart lib/core/router/routes.dart lib/core/router/app_router.dart lib/core/strings/vi.dart test/features/rank/bu_layout_painter_test.dart test/smoke/all_routes_test.dart
git commit -m "Draw BU layouts on the planner's table and add the layout gallery screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: The onboarding gate, the redirect and the questionnaire screen (spec §7.1, §7.2, §8)

**Files:**
- Modify: `lib/domain/assessment/onboarding_check.dart` (append)
- Modify: `lib/core/providers/assessment_providers.dart` (append `OnboardingGate`, `onboardingGateProvider`)
- Modify: `lib/core/router/routes.dart` (`onboardingRank` + `Routes.all`)
- Modify: `lib/core/router/app_router.dart` (`createAppRouter` at lines 36–39, a route, `authRedirect` at lines 165–174)
- Modify: `lib/app.dart` (`_router` at lines 35–36)
- Modify: `lib/core/strings/vi.dart` (onboarding strings)
- Create: `lib/features/rank/presentation/onboarding_screen.dart`
- Modify: `test/support/test_data.dart` (append `dbContainer`)
- Modify: `test/core/router/auth_redirect_test.dart` (append tests)
- Modify: `test/smoke/all_routes_test.dart`
- Test: `test/domain/assessment/onboarding_check_test.dart`
- Test: `test/features/rank/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `RankFetch` (Task 9); `PlayerRank`, `OnboardingState`, `canUseQuestionnaire` (Task 1); `suggestRank`, `QuestionnaireAnswers`, `questionOptionCounts` (Tasks 1, 5); `playerRankProvider`, `assessmentRepositoryProvider`, `rankFetchProvider`, `rankFetchFor` (Tasks 8–9); `PcRankBadge`.
- Produces:
  - `enum OnboardingCheck { required, notRequired }`, `OnboardingCheck decideOnboarding({required bool rankLoaded, required PlayerRank? local, required RankFetch fetch})`;
  - `class OnboardingGate extends ChangeNotifier { OnboardingCheck get check; void update(OnboardingCheck next); }`, `onboardingGateProvider`;
  - `String? authRedirect(AuthState auth, Uri location, {OnboardingCheck onboarding = OnboardingCheck.notRequired})`;
  - `GoRouter createAppRouter({required AuthGate auth, OnboardingGate? onboarding})`;
  - `Routes.onboardingRank = '/onboarding/rank'`;
  - `class OnboardingScreen extends ConsumerStatefulWidget`;
  - test support `ProviderContainer dbContainer(AppDatabase db, {AuthRepository? auth, DateTime? now})`.

- [ ] **Step 1: Failing tests for the decision and the redirect**

`test/domain/assessment/onboarding_check_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Spec mục 7.1 và 8: chỉ ép onboarding khi chắc chắn tài khoản chưa có dòng
/// hạng nào — trên máy, hoặc máy chủ đã trả lời là không có.
void main() {
  final at = DateTime(2026, 10, 14);
  final skipped = PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: at);
  final notStarted = PlayerRank(onboardingState: OnboardingState.notStarted, updatedAt: at);

  OnboardingCheck d(PlayerRank? local, RankFetch fetch, {bool loaded = true}) =>
      decideOnboarding(rankLoaded: loaded, local: local, fetch: fetch);

  test('máy đã có dòng hạng: theo trạng thái của dòng đó', () {
    expect(d(skipped, RankFetch.pending), OnboardingCheck.notRequired);
    expect(d(notStarted, RankFetch.pending), OnboardingCheck.required);
  });

  test('máy chưa có gì, máy chủ trả lời không có: vào onboarding', () {
    expect(d(null, RankFetch.foundNone), OnboardingCheck.required);
  });

  test('máy chưa có gì, chưa hỏi xong máy chủ: chưa quyết, không chuyển', () {
    expect(d(null, RankFetch.pending), OnboardingCheck.notRequired);
  });

  test('máy mới mất mạng: không ép onboarding', () {
    expect(d(null, RankFetch.failed), OnboardingCheck.notRequired);
  });

  test('máy chủ có dòng hạng mà Drift chưa kịp bắn lại: không chuyển', () {
    expect(d(null, RankFetch.found), OnboardingCheck.notRequired);
  });

  test('Drift chưa trả lời: không chuyển', () {
    expect(d(null, RankFetch.foundNone, loaded: false), OnboardingCheck.notRequired);
  });
}
```

Append inside `main` of `test/core/router/auth_redirect_test.dart` (import `package:poolcoachai/domain/assessment/onboarding_check.dart`):

```dart
  test('cần onboarding thì mọi màn đã đăng nhập chuyển tới /onboarding/rank', () {
    const need = OnboardingCheck.required;
    expect(authRedirect(inn, at('/home'), onboarding: need), Routes.onboardingRank);
    expect(authRedirect(inn, at('/profile'), onboarding: need), Routes.onboardingRank);
    expect(authRedirect(inn, at(Routes.onboardingRank), onboarding: need), isNull);
  });

  test('cần onboarding mà đang ở màn tài khoản: về Trang chủ trước, lượt sau mới sang onboarding', () {
    expect(authRedirect(inn, at('/login'), onboarding: OnboardingCheck.required), Routes.home);
  });

  test('chưa đăng nhập thì onboarding không quan trọng', () {
    expect(authRedirect(out, at(Routes.onboardingRank), onboarding: OnboardingCheck.required),
        Routes.login);
  });

  test('không cần onboarding thì vẫn vào lại được màn câu hỏi (làm lại)', () {
    expect(authRedirect(inn, at(Routes.onboardingRank)), isNull);
  });
```

Run `"$FLUTTER" test test/domain/assessment/onboarding_check_test.dart test/core/router/auth_redirect_test.dart`. Expected: FAIL.

- [ ] **Step 2: Implement the decision, the gate and the redirect**

Append to `onboarding_check.dart` (import `player_rank.dart`):

```dart
enum OnboardingCheck { required, notRequired }

/// Có chuyển người chơi tới bộ câu hỏi không (spec mục 7.1, 8).
///
/// Chỉ khi chắc chắn tài khoản chưa có dòng hạng: dòng trên máy còn ở
/// `notStarted`, hoặc máy chưa có dòng và máy chủ đã trả lời là không có.
/// Chưa biết (Drift chưa trả lời, máy chủ chưa trả lời, mất mạng, hay máy
/// chủ có dòng mà stream chưa kịp bắn) thì không chuyển.
OnboardingCheck decideOnboarding({
  required bool rankLoaded,
  required PlayerRank? local,
  required RankFetch fetch,
}) {
  if (!rankLoaded) return OnboardingCheck.notRequired;
  if (local != null) {
    return local.onboardingState == OnboardingState.notStarted
        ? OnboardingCheck.required
        : OnboardingCheck.notRequired;
  }
  return fetch == RankFetch.foundNone ? OnboardingCheck.required : OnboardingCheck.notRequired;
}
```

Append to `assessment_providers.dart` (imports `package:flutter/foundation.dart` and `onboarding_check.dart` if missing):

```dart
/// Cầu nối từ trạng thái hạng sang `refreshListenable` của router, như
/// [AuthGate] với trạng thái đăng nhập.
class OnboardingGate extends ChangeNotifier {
  OnboardingCheck _check = OnboardingCheck.notRequired;

  OnboardingCheck get check => _check;

  void update(OnboardingCheck next) {
    if (next == _check) return;
    _check = next;
    notifyListeners();
  }
}

final onboardingGateProvider = Provider<OnboardingGate>((ref) {
  final gate = OnboardingGate();
  void recompute() {
    final userId = ref.read(currentUserIdProvider);
    final rank = ref.read(playerRankProvider);
    gate.update(userId == null
        ? OnboardingCheck.notRequired
        : decideOnboarding(
            // Đang tải lại (vừa đổi người) thì giá trị cũ là của người trước.
            rankLoaded: rank.hasValue && !rank.isLoading,
            local: rank.value,
            fetch: rankFetchFor(ref.read(rankFetchProvider), userId),
          ));
  }

  ref.listen(playerRankProvider, (_, _) => recompute());
  ref.listen(rankFetchProvider, (_, _) => recompute());
  ref.listen(currentUserIdProvider, (_, _) => recompute());
  recompute();
  ref.onDispose(gate.dispose);
  return gate;
});
```

In `routes.dart`, under the account routes:

```dart
  /// Bộ câu hỏi xác định hạng — mở đè lên shell (spec mục 7.1).
  static const onboardingRank = '/onboarding/rank';
```

and add it to `Routes.all`. In `app_router.dart`, change the signature and redirect:

```dart
GoRouter createAppRouter({required AuthGate auth, OnboardingGate? onboarding}) => GoRouter(
  initialLocation: Routes.home,
  refreshListenable: onboarding == null ? auth : Listenable.merge([auth, onboarding]),
  redirect: (context, state) => authRedirect(auth.state, state.uri,
      onboarding: onboarding?.check ?? OnboardingCheck.notRequired),
```

add the route after the `Routes.rankLayouts` route:

```dart
    GoRoute(
      path: Routes.onboardingRank,
      builder: (context, state) => const OnboardingScreen(),
    ),
```

and replace `authRedirect`:

```dart
/// Ai được vào đâu — tách riêng để test không phải dựng router.
///
/// Chưa đăng nhập thì chỉ vào được ba màn tài khoản; đã đăng nhập thì
/// không vào lại chúng. Link đặt lại mật khẩu mở được ở cả hai trạng
/// thái. Đã đăng nhập mà tài khoản chắc chắn chưa có hạng thì vào bộ câu
/// hỏi trước (spec mục 7.1); go_router chạy lại redirect trên đích mới,
/// nên từ màn tài khoản sẽ đi Trang chủ rồi mới sang bộ câu hỏi.
String? authRedirect(
  AuthState auth,
  Uri location, {
  OnboardingCheck onboarding = OnboardingCheck.notRequired,
}) {
  final path = location.path;
  if (path == Routes.resetPassword) return null;
  final onAuthPage = Routes.signedOutOnly.contains(path);
  return switch (auth) {
    SignedOut() when !onAuthPage => Routes.login,
    SignedIn() when onAuthPage => Routes.home,
    SignedIn() when onboarding == OnboardingCheck.required && path != Routes.onboardingRank =>
      Routes.onboardingRank,
    _ => null,
  };
}
```

with the imports of `assessment_providers.dart` (for `OnboardingGate`), `onboarding_check.dart` and `onboarding_screen.dart`. In `lib/app.dart`:

```dart
  late final GoRouter _router = widget.router ??
      createAppRouter(
        auth: ref.read(authGateProvider),
        onboarding: ref.read(onboardingGateProvider),
      );
```

(import `assessment_providers.dart`). Run the two tests: expected PASS once `OnboardingScreen` exists (Step 4). Until then the app does not compile — keep going.

- [ ] **Step 3: Onboarding strings**

Add to `vi.dart`:

```dart
  // Bộ câu hỏi xác định hạng — spec mục 7.2.
  static const onboardingTitle = 'Xác định hạng';
  static const onboardingLater = 'Để sau';
  static const onboardingIntroTitle = 'Xác định hạng của bạn';
  static const onboardingIntroBody = 'Trả lời 8 câu hỏi ngắn, app gợi ý một hạng. Bạn '
      'xác nhận hoặc tự chọn hạng khác. Muốn có hạng đã kiểm chứng, hãy làm bài kiểm tra '
      'Billiard University ở mục Hồ sơ.';
  static const onboardingStart = 'Bắt đầu';
  static String onboardingQuestionCounter(int q) => 'Câu $q / 8';
  static const onboardingBack = 'Quay lại';
  static const onboardingNext = 'Tiếp';
  static const onboardingSuggestTitle = 'Hạng gợi ý cho bạn';
  static const onboardingConfirm = 'Xác nhận';
  static const onboardingChooseOther = 'Chọn hạng khác';
  static const onboardingChooseTitle = 'Chọn hạng của bạn';
  static const onboardingLocked = 'Hạng của bạn đã được kiểm chứng bằng bài kiểm tra '
      'Billiard University. Từ giờ chỉ bài kiểm tra mới đổi được hạng.';

  /// Câu miễn trừ bắt buộc ở mọi màn hiện hạng (spec mục 4.3).
  static const rankDisclaimer =
      'Đây là bảng hạng riêng của PoolCoachAI, tham khảo cách hiểu ở Hà Nội.';
```

- [ ] **Step 4: Failing widget test, then the screen**

Append to `test/support/test_data.dart` (imports `package:poolcoachai/core/providers/database_provider.dart` and `package:poolcoachai/data/database/database.dart`):

```dart
/// Như [testContainer] nhưng hạng và bài kiểm tra đọc từ [db] thật (SQLite
/// trong bộ nhớ) — cho widget test cần ghi rồi đọc lại.
ProviderContainer dbContainer(AppDatabase db, {AuthRepository? auth, DateTime? now}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      nowProvider.overrideWithValue(() => now ?? testToday),
      drillsProvider.overrideWith((ref) => Stream.value(testDrills)),
      knowledgeProvider.overrideWith((ref) => Stream.value(testKnowledge)),
      drillLogsProvider.overrideWith((ref) => Stream.value(const <DrillLog>[])),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
    ],
  );
}
```

`test/features/rank/onboarding_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/onboarding_check.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<(GoRouter, ProviderContainer)> pump(WidgetTester tester,
      {bool withGate = false, String? location}) async {
    final auth = FakeAuthRepository.signedIn();
    final container = dbContainer(db, auth: auth);
    addTearDown(container.dispose);
    final gate = AuthGate(auth);
    addTearDown(gate.dispose);
    final router = createAppRouter(
        auth: gate, onboarding: withGate ? container.read(onboardingGateProvider) : null);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    if (location != null) {
      router.go(location);
      await tester.pumpAndSettle();
    }
    return (router, container);
  }

  Future<PlayerRankRow?> row() => db.select(db.playerRankRows).getSingleOrNull();

  Future<void> answer(WidgetTester tester, List<String> picks) async {
    await tester.tap(find.text(Vi.onboardingStart));
    await tester.pumpAndSettle();
    for (final pick in picks) {
      await tester.tap(find.text(pick));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Vi.onboardingNext));
      await tester.pumpAndSettle();
    }
  }

  const toH = [
    'Chưa từng chơi', 'Dưới 2 giờ / tuần', '1', '1', 'Đã từng 1–2 lần', 'Chưa từng',
    'Thường không có bi đánh tiếp', 'Thường xuyên bị khó',
  ];

  testWidgets('Để sau ở màn giới thiệu: ghi bỏ qua rồi về Trang chủ', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await tester.tap(find.text(Vi.onboardingLater));
    await tester.pumpAndSettle();
    expect((await row())!.onboardingState, 'skipped');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('trả lời 8 câu, xác nhận gợi ý: hạng ước lượng, lưu đủ câu trả lời', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await answer(tester, toH);
    expect(find.text(Vi.onboardingSuggestTitle), findsOneWidget);
    expect(find.text(Vi.rankDescription(Rank.h)), findsOneWidget);
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    await tester.tap(find.text(Vi.onboardingConfirm));
    await tester.pumpAndSettle();
    final r = toPlayerRank((await row())!);
    expect(r.rank, Rank.h);
    expect(r.source, RankSource.estimated);
    expect(r.answers!.choices, [0, 0, 0, 0, 1, 0, 0, 0]);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Chọn hạng khác: chọn PRO thì thành tự khai', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await answer(tester, toH);
    await tester.tap(find.text(Vi.onboardingChooseOther));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(Vi.rankDescription(Rank.pro)), 200);
    await tester.tap(find.text(Vi.rankDescription(Rank.pro)));
    await tester.pumpAndSettle();
    final r = toPlayerRank((await row())!);
    expect(r.rank, Rank.pro);
    expect(r.source, RankSource.selfDeclared);
  });

  testWidgets('chưa chọn đáp án thì không bấm Tiếp được', (tester) async {
    await pump(tester, location: Routes.onboardingRank);
    await tester.tap(find.text(Vi.onboardingStart));
    await tester.pumpAndSettle();
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, Vi.onboardingNext));
    expect(next.onPressed, isNull);
  });

  testWidgets('hạng đã kiểm chứng thì không làm lại được bộ câu hỏi', (tester) async {
    await db.into(db.playerRankRows).insert(toPlayerRankRow(
        PlayerRank(
          rank: Rank.d, source: RankSource.verified, buScore: 130, testId: 't1',
          onboardingState: OnboardingState.done, updatedAt: testToday,
        ),
        userId: 'u1'));
    await pump(tester, location: Routes.onboardingRank);
    expect(find.text(Vi.onboardingLocked), findsOneWidget);
    expect(find.text(Vi.onboardingStart), findsNothing);
  });

  group('chuyển tới onboarding sau khi đăng nhập (spec mục 7.1, 8)', () {
    testWidgets('máy chủ báo chưa có hạng: vào bộ câu hỏi', (tester) async {
      final (_, container) = await pump(tester, withGate: true);
      expect(find.byType(HomeScreen), findsOneWidget);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('máy mới mất mạng: không ép onboarding', (tester) async {
      final (_, container) = await pump(tester, withGate: true);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.failed);
      await tester.pumpAndSettle();
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.foundNone);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('đã bấm Để sau từ trước: không vào lại', (tester) async {
      await db.into(db.playerRankRows).insert(toPlayerRankRow(
          PlayerRank(onboardingState: OnboardingState.skipped, updatedAt: testToday),
          userId: 'u1'));
      final (_, container) = await pump(tester, withGate: true);
      container.read(rankFetchProvider.notifier).report('u1', RankFetch.found);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
```

Add `Routes.onboardingRank: (path: Routes.onboardingRank, screen: OnboardingScreen),` to `_routeCases` in the smoke test (with the import).

Run `"$FLUTTER" test test/features/rank/onboarding_screen_test.dart`. Expected: FAIL — `onboarding_screen.dart` does not exist.

Create `lib/features/rank/presentation/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';

enum _Step { intro, questions, suggestion, choose }

/// Bộ câu hỏi xác định hạng — spec mục 7.2. Màn nào cũng có *Để sau*.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro;
  int _question = 1;
  final _choices = List<int?>.filled(questionOptionCounts.length, null);
  Rank? _suggested;
  bool _saving = false;

  QuestionnaireAnswers get _answers => QuestionnaireAnswers([for (final c in _choices) c!]);

  /// Mở từ màn Hạng (làm lại) thì quay về đó; bị chuyển tới sau đăng nhập
  /// thì không có gì để quay lại, nên về Trang chủ.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await ref.read(assessmentRepositoryProvider)?.skipOnboarding();
    if (mounted) _leave();
  }

  Future<void> _save(Rank chosen) async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(assessmentRepositoryProvider)!
        .saveQuestionnaire(chosen: chosen, suggested: _suggested!, answers: _answers);
    if (mounted) _leave();
  }

  void _next() {
    if (_question < questionOptionCounts.length) {
      setState(() => _question++);
      return;
    }
    setState(() {
      _suggested = suggestRank(_answers);
      _step = _Step.suggestion;
    });
  }

  void _back() => setState(() {
        if (_question > 1) {
          _question--;
        } else {
          _step = _Step.intro;
        }
      });

  @override
  Widget build(BuildContext context) {
    final rank = ref.watch(playerRankProvider);
    final locked = rank.hasValue && !canUseQuestionnaire(rank.value);
    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.onboardingTitle),
        actions: [
          if (!locked)
            TextButton(
              onPressed: _saving ? null : _skip,
              child: const Text(Vi.onboardingLater),
            ),
        ],
      ),
      body: SafeArea(
        child: locked
            ? _padded([
                const Text(Vi.onboardingLocked),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: _leave, child: const Text(Vi.onboardingBack)),
              ])
            : switch (_step) {
                _Step.intro => _intro(context),
                _Step.questions => _questionPage(context),
                _Step.suggestion => _suggestion(context),
                _Step.choose => _choose(context),
              },
      ),
    );
  }

  Widget _padded(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: children,
      );

  Widget _intro(BuildContext context) => _padded([
        Text(Vi.onboardingIntroTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.onboardingIntroBody),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.rankDisclaimer),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          onPressed: () => setState(() => _step = _Step.questions),
          child: const Text(Vi.onboardingStart),
        ),
      ]);

  Widget _questionPage(BuildContext context) {
    final chosen = _choices[_question - 1];
    return _padded([
      Text(Vi.onboardingQuestionCounter(_question),
          style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(Vi.rankQuestion(_question), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      for (final (i, option) in Vi.rankQuestionOptions(_question).indexed)
        ListTile(
          leading: Icon(chosen == i ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          title: Text(option),
          selected: chosen == i,
          onTap: () => setState(() => _choices[_question - 1] = i),
        ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          OutlinedButton(onPressed: _back, child: const Text(Vi.onboardingBack)),
          const Spacer(),
          FilledButton(
            onPressed: chosen == null ? null : _next,
            child: const Text(Vi.onboardingNext),
          ),
        ],
      ),
    ]);
  }

  Widget _suggestion(BuildContext context) {
    final s = _suggested!;
    return _padded([
      Text(Vi.onboardingSuggestTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.lg),
      Align(alignment: Alignment.centerLeft, child: PcRankBadge(rank: s, showWord: true)),
      const SizedBox(height: AppSpacing.md),
      Text(Vi.rankDescription(s)),
      const SizedBox(height: AppSpacing.md),
      Text(Vi.rankDisclaimer, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xxl),
      FilledButton(
        onPressed: _saving ? null : () => _save(s),
        child: const Text(Vi.onboardingConfirm),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: _saving ? null : () => setState(() => _step = _Step.choose),
        child: const Text(Vi.onboardingChooseOther),
      ),
    ]);
  }

  Widget _choose(BuildContext context) => _padded([
        Text(Vi.onboardingChooseTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final r in Rank.values)
          ListTile(
            leading: PcRankBadge(rank: r),
            title: Text(Vi.rankDescription(r)),
            subtitle: Text(Vi.rankGroupName(r.group)),
            onTap: _saving ? null : () => _save(r),
          ),
      ]);
}
```

- [ ] **Step 5: Run and commit**

```bash
"$FLUTTER" test test/domain/assessment test/core test/features/rank test/smoke test/app_test.dart
"$FLUTTER" test
```

Expected: PASS everywhere.

```bash
git add lib/domain/assessment/onboarding_check.dart lib/core/providers/assessment_providers.dart lib/core/router lib/app.dart lib/core/strings/vi.dart lib/features/rank/presentation/onboarding_screen.dart test/support/test_data.dart test/domain/assessment/onboarding_check_test.dart test/core/router/auth_redirect_test.dart test/features/rank/onboarding_screen_test.dart test/smoke/all_routes_test.dart
git commit -m "Add the rank questionnaire and send new accounts to it only once the server confirms they have no rank

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 14: The test runner — preparation, per-kind inputs, undo, ladder position, resume (spec §7.3)

**Files:**
- Create: `lib/features/rank/presentation/drill_inputs.dart`
- Create: `lib/features/rank/presentation/test_screen.dart` (prep + runner; Task 15 adds the Exam I end, finish and result)
- Modify: `lib/core/router/routes.dart` (`rankTest` + `Routes.all`), `lib/core/router/app_router.dart` (route after `Routes.onboardingRank`)
- Modify: `lib/core/strings/vi.dart` (runner strings)
- Modify: `test/smoke/all_routes_test.dart`
- Test: `test/features/rank/drill_inputs_test.dart`
- Test: `test/features/rank/test_runner_test.dart`

**Interfaces:**
- Consumes: `activeTestProvider`, `buTestsProvider`, `assessmentRepositoryProvider` (Task 8); `TestSnapshot` (Task 6); `BuDrill`, `ScoringKind` (Task 4); `ladderPosition` (Task 3); `layoutForAttempt` (Task 11); `BuLayoutView` (Task 12); `retestAvailableFrom` (Task 6); `nowProvider`.
- Produces:
  - `class ShotInput extends StatelessWidget { const ShotInput({required String drillId, required ValueChanged<bool> onShot, bool enabled = true}); }`;
  - `class CountInput extends StatefulWidget { const CountInput({required int max, required ValueChanged<int> onSubmit, bool enabled = true}); }`;
  - `class BreakInput extends StatefulWidget { const BreakInput({required ValueChanged<BreakCriteria> onSubmit, bool enabled = true}); }`;
  - `class TestScreen extends ConsumerStatefulWidget`, `class DrillRunner extends ConsumerStatefulWidget { const DrillRunner({required TestSnapshot snap}); }`;
  - `Routes.rankTest = '/rank/test'`;
  - `Vi.buShotYes`, `Vi.buShotNo`, `Vi.buCountLess`, `Vi.buCountMore`, `Vi.buCountOf`, `Vi.buCountSubmit`, `Vi.buBreakSubmit`, `Vi.buUndo`, `Vi.buAttemptLabel`, `Vi.buLadderPosition`, `Vi.buRunnerHeader`, `Vi.buRunningScore`, `Vi.buTestTitle`, `Vi.buPrepTitle`, `Vi.buPrepIntro`, `Vi.buSourceLine`, `Vi.buTableSizeLabel`, `Vi.buTableSize`, `Vi.buDoctorateNeedsNine`, `Vi.buStart`, `Vi.buRetestFrom`, `Vi.buLoadFailed`.

- [ ] **Step 1: Runner strings**

Add to `vi.dart`:

```dart
  // Làm bài kiểm tra — spec mục 7.3.
  static const buTestTitle = 'Bài kiểm tra BU';
  static const buPrepTitle = 'Chuẩn bị';
  static const buPrepIntro = 'Bài kiểm tra gồm Đề I (Cơ bản) và Đề II (Kỹ năng) của '
      'Billiard University. Mỗi đề mất khoảng 40–60 phút. Điểm Đề I quyết định bản '
      'Đề II (Bachelors, Masters hoặc Doctorate). Đề II làm ngay hoặc để buổi khác đều được.';
  static const buSourceLine = 'Đề bài: Billiard University (billiarduniversity.org) — '
      'Dr. Dave Alciatore và Bob Jewett.';
  static const buTableSizeLabel = 'Kích thước bàn';
  static String buTableSize(TableSize s) => switch (s) {
        TableSize.sevenFoot => '7 feet',
        TableSize.eightFoot => '8 feet',
        TableSize.nineFootPlus => '9 feet trở lên',
      };
  static const buDoctorateNeedsNine = 'Bản Doctorate chỉ làm trên bàn 9 feet trở lên.';
  static const buStart = 'Bắt đầu Đề I';
  static String buRetestFrom(DateTime d) => 'Lần kiểm tra trước đã hoàn tất. '
      'Lần kế tiếp làm được từ ngày ${shortDate(d)}.';
  static const buLoadFailed = 'Không đọc được bài kiểm tra trên máy.';

  static String buRunnerHeader(BuExam exam, ExamIIVersion? v, int k, int n) =>
      '${buExamName(exam)}${v == null ? '' : ' · ${buVersionName(v)}'} · bài $k / $n';
  static String buRunningScore(BuExam exam, int score) =>
      'Điểm ${exam == BuExam.fundamentals ? 'Đề I' : 'Đề II'} hiện tại: $score';
  static String buLadderPosition(int p) => 'Vị trí hiện tại: $p';

  /// Lượt đang nhập, theo cách phiếu điểm BU chia ô.
  static String buAttemptLabel(BuDrill d, int index) {
    final i = index.clamp(0, d.attemptCount - 1);
    final group = i ~/ d.attemptsPerGroup + 1;
    final within = i % d.attemptsPerGroup + 1;
    return switch (d.kind) {
      ScoringKind.bestOfTwo => 'Lượt ${i + 1} / 2',
      ScoringKind.sumOfLowestTwo => 'Thế ${i + 1} / 3',
      ScoringKind.medianBreak => 'Lần phá ${i + 1} / 3',
      _ when d.id == 'F7' => 'Bi đích $group · lượt $within',
      _ when d.id == 'F8' => 'Đích $group · lượt $within',
      _ when d.id == 'S5' => 'Vị trí bi cái $group · lượt $within',
      _ => 'Cú ${i + 1} / ${d.attemptCount}',
    };
  }

  static String buShotYes(String drillId) => switch (drillId) {
        'S5' => 'Bắt đui được',
        'S6' => 'Chạm bi',
        'F7' || 'F8' || 'S8' || 'S9' => 'Đạt',
        _ => 'Vào',
      };

  static String buShotNo(String drillId) => switch (drillId) {
        'S5' => 'Không bắt đui',
        'F7' || 'F8' || 'S8' || 'S9' => 'Không đạt',
        _ => 'Trượt',
      };

  static const buCountLess = 'Bớt một bi';
  static const buCountMore = 'Thêm một bi';
  static String buCountOf(int n, int max) => '$n / $max bi';
  static const buCountSubmit = 'Ghi lượt';
  static const buBreakSubmit = 'Ghi lần phá';
  static const buUndo = 'Hoàn tác cú vừa nhập';
```

(import `bu_placement.dart` for `TableSize` if not already imported.)

- [ ] **Step 2: Failing tests for the three inputs**

`test/features/rank/drill_inputs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/features/rank/presentation/drill_inputs.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: ListView(children: [child])));

void main() {
  testWidgets('Vào / Trượt: hai nút cao ít nhất 48 px, báo đúng kết quả', (tester) async {
    final got = <bool>[];
    await tester.pumpWidget(_host(ShotInput(drillId: 'F1', onShot: got.add)));
    expect(tester.getSize(find.widgetWithText(FilledButton, 'Vào')).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(OutlinedButton, 'Trượt')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Vào'));
    await tester.tap(find.text('Trượt'));
    expect(got, [true, false]);
  });

  testWidgets('S5 gọi đúng tên: bắt đui', (tester) async {
    await tester.pumpWidget(_host(ShotInput(drillId: 'S5', onShot: (_) {})));
    expect(find.text(Vi.buShotYes('S5')), findsOneWidget);
    expect(find.text(Vi.buShotNo('S5')), findsOneWidget);
  });

  testWidgets('bộ đếm số bi không xuống dưới 0, không vượt tối đa', (tester) async {
    int? got;
    await tester.pumpWidget(_host(CountInput(max: 4, onSubmit: (n) => got = n)));
    expect(tester.widget<IconButton>(find.byTooltip(Vi.buCountLess)).onPressed, isNull);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip(Vi.buCountMore));
      await tester.pump();
    }
    expect(find.text(Vi.buCountOf(4, 4)), findsOneWidget);
    expect(tester.widget<IconButton>(find.byTooltip(Vi.buCountMore)).onPressed, isNull);
    await tester.tap(find.text(Vi.buCountSubmit));
    expect(got, 4);
  });

  testWidgets('lần phá: b–e khoá khi chưa chọn a; bỏ a thì xoá b–e', (tester) async {
    BreakCriteria? got;
    await tester.pumpWidget(_host(BreakInput(onSubmit: (b) => got = b)));
    CheckboxListTile tile(int i) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, Vi.buBreakCriterion(i)));
    expect(tile(1).onChanged, isNull);
    await tester.tap(find.text(Vi.buBreakCriterion(0)));
    await tester.pump();
    await tester.tap(find.text(Vi.buBreakCriterion(3)));
    await tester.pump();
    await tester.tap(find.text(Vi.buBreakSubmit));
    expect(got, const BreakCriteria(a: true, d: true));

    await tester.tap(find.text(Vi.buBreakCriterion(0)));
    await tester.pump();
    expect(tile(3).value, isFalse);
  });
}
```

Run `"$FLUTTER" test test/features/rank/drill_inputs_test.dart`. Expected: FAIL — `drill_inputs.dart` does not exist.

- [ ] **Step 3: Write `drill_inputs.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';

/// Nút cao 48 px: bấm được bằng ngón tay khi đang cầm cơ (spec mục 7.3).
const _tall = Size.fromHeight(48);

/// Một lượt thành công / không — thang vị trí và các bài đếm lượt.
class ShotInput extends StatelessWidget {
  const ShotInput({
    required this.drillId,
    required this.onShot,
    this.enabled = true,
    super.key,
  });

  final String drillId;
  final ValueChanged<bool> onShot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: _tall),
            onPressed: enabled ? () => onShot(true) : null,
            child: Text(Vi.buShotYes(drillId)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: _tall),
            onPressed: enabled ? () => onShot(false) : null,
            child: Text(Vi.buShotNo(drillId)),
          ),
        ),
      ],
    );
  }
}

/// Số bi của một lượt, giới hạn 0…[max] từ đầu — không nhập sai được.
class CountInput extends StatefulWidget {
  const CountInput({required this.max, required this.onSubmit, this.enabled = true, super.key});

  final int max;
  final ValueChanged<int> onSubmit;
  final bool enabled;

  @override
  State<CountInput> createState() => _CountInputState();
}

class _CountInputState extends State<CountInput> {
  int _n = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: Vi.buCountLess,
              iconSize: 32,
              onPressed: _n > 0 ? () => setState(() => _n--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 96,
              child: Text(
                Vi.buCountOf(_n, widget.max),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: Vi.buCountMore,
              iconSize: 32,
              onPressed: _n < widget.max ? () => setState(() => _n++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: _tall),
          onPressed: widget.enabled ? () => widget.onSubmit(_n) : null,
          child: const Text(Vi.buCountSubmit),
        ),
      ],
    );
  }
}

/// Năm tiêu chí của một lần phá S10. b–e đòi a, nên khoá khi chưa chọn a.
class BreakInput extends StatefulWidget {
  const BreakInput({required this.onSubmit, this.enabled = true, super.key});

  final ValueChanged<BreakCriteria> onSubmit;
  final bool enabled;

  @override
  State<BreakInput> createState() => _BreakInputState();
}

class _BreakInputState extends State<BreakInput> {
  final _v = List<bool>.filled(5, false);

  void _set(int i, bool value) => setState(() {
        _v[i] = value;
        if (i == 0 && !value) {
          for (var j = 1; j < 5; j++) {
            _v[j] = false;
          }
        }
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 5; i++)
          CheckboxListTile(
            value: _v[i],
            title: Text(Vi.buBreakCriterion(i)),
            onChanged: i == 0 || _v[0] ? (x) => _set(i, x ?? false) : null,
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: _tall),
          onPressed: widget.enabled
              ? () => widget.onSubmit(
                  BreakCriteria(a: _v[0], b: _v[1], c: _v[2], d: _v[3], e: _v[4]))
              : null,
          child: const Text(Vi.buBreakSubmit),
        ),
      ],
    );
  }
}
```

Run the input test: PASS.

- [ ] **Step 4: Failing runner tests**

`test/features/rank/test_runner_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';

import '../../support/assessment_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  late AssessmentRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    var n = 0;
    repo = AssessmentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'seed${++n}');
  });
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester) async {
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
  }

  Future<List<bool>> f1Shots() async {
    final row = await (db.select(db.buDrillResultRows)..where((r) => r.drillId.equals('F1')))
        .getSingleOrNull();
    if (row == null) return [];
    return (DrillAttempts.fromJson(_decode(row.attempts)) as ShotAttempts).shots;
  }

  testWidgets('chưa có lần nào: chọn bàn rồi bắt đầu, vào F1 cú 1/10', (tester) async {
    await open(tester);
    expect(find.text(Vi.buPrepTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buTableSize(TableSize.eightFoot)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.buStart));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F1')), findsOneWidget);
    expect(find.text(Vi.buAttemptLabel(drillFor('F1', null), 0)), findsOneWidget);
    final test = await db.select(db.buTestRows).getSingle();
    expect(test.tableSize, 'eightFoot');
  });

  testWidgets('chưa đủ 14 ngày: nút bắt đầu khoá và báo ngày', (tester) async {
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'cu', userId: 'u1', startedAt: testToday, tableSize: 'nineFootPlus',
        completedAt: Value(testToday.subtract(const Duration(days: 3))),
        totalScore: const Value(80), resultRank: const Value('g')));
    await open(tester);
    final from = DateTime(testToday.year, testToday.month, testToday.day - 3 + 14);
    expect(find.text(Vi.buRetestFrom(from)), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, Vi.buStart)).onPressed, isNull);
  });

  testWidgets('Vào/Trượt ghi ngay xuống máy, thang tự chuyển vị trí', (tester) async {
    await repo.startTest(TableSize.nineFootPlus);
    await open(tester);
    await tester.tap(find.text('Vào'));
    await tester.pumpAndSettle();
    expect(await f1Shots(), [true]);
    expect(find.text(Vi.buLadderPosition(5)), findsOneWidget);
    expect(tester.widget<BuLayoutView>(find.byType(BuLayoutView)).highlightPosition, 5);
    await tester.tap(find.text('Trượt'));
    await tester.pumpAndSettle();
    expect(await f1Shots(), [true, false]);
    expect(find.text(Vi.buLadderPosition(4)), findsOneWidget);
  });

  testWidgets('mở lại màn làm bài thì tiếp đúng cú 4/10, tô vị trí 5', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts([true, false, true]));
    await open(tester);
    expect(find.text(Vi.buAttemptLabel(drillFor('F1', null), 3)), findsOneWidget);
    expect(find.text(Vi.buLadderPosition(5)), findsOneWidget);
    expect(tester.widget<BuLayoutView>(find.byType(BuLayoutView)).highlightPosition, 5);
  });

  testWidgets('Hoàn tác bỏ cú vừa nhập; F1 xong thì sang F2, hoàn tác lùi về F1', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts(List.filled(7, true)));
    await open(tester);
    await tester.tap(find.text('Vào'));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F2')), findsOneWidget, reason: '8 cú vào liền: F1 đã chắc 10');
    await tester.tap(find.text(Vi.buUndo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('F1')), findsOneWidget);
    expect(await f1Shots(), List.filled(7, true));
  });

  testWidgets('Đề II: bộ đếm số bi của S1 dừng ở tối đa, lượt 1 trọn điểm thì sang S2', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    for (final e in examIAttempts(wagonAndTargetMade: false).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await repo.finishExamI(id);
    await repo.recordAttempts(id, 'S1', CountAttempts(const [])); // đã bắt đầu Đề II
    await open(tester);
    expect(find.text(Vi.buDrillTitle('S1')), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byTooltip(Vi.buCountMore));
      await tester.pump();
    }
    expect(find.text(Vi.buCountOf(7, 7)), findsOneWidget);
    await tester.tap(find.text(Vi.buCountSubmit));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('S2')), findsOneWidget);
  });
}
```

with `import 'dart:convert';`, `import 'package:drift/drift.dart' show Value;` and the helper `Object? _decode(String s) => jsonDecode(s);` at the bottom of the file.

The S1 test records an empty S1 first so the placement view of Task 15 (shown while Exam II has no attempt) is skipped; that is what "already started Exam II" looks like in data. Until Task 15 exists, that line is harmless.

Add to the smoke test's `_routeCases`: `Routes.rankTest: (path: Routes.rankTest, screen: TestScreen),` (import `test_screen.dart`).

Run `"$FLUTTER" test test/features/rank/test_runner_test.dart`. Expected: FAIL — `TestScreen` and the route do not exist.

- [ ] **Step 5: Route and `test_screen.dart`**

`routes.dart`, after `rankLayouts`:

```dart
  /// Làm bài kiểm tra BU — mở đè lên shell (spec mục 7.1).
  static const rankTest = '/rank/test';
```

and add `rankTest` to `Routes.all`. `app_router.dart`, after the onboarding route:

```dart
    GoRoute(
      path: Routes.rankTest,
      builder: (context, state) => const TestScreen(),
    ),
```

`lib/features/rank/presentation/test_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_layouts.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_scoring.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/features/rank/presentation/bu_layout_painter.dart';
import 'package:poolcoachai/features/rank/presentation/drill_inputs.dart';

/// Làm bài kiểm tra BU (spec mục 7.3). Màn chỉ đọc Drift: mỗi cú ghi xuống
/// máy ngay, stream bắn lại, màn tự sang cú / bài kế.
class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeTestProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.buTestTitle)),
      body: SafeArea(
        child: switch (active) {
          AsyncData(value: final snap?) => _activeBody(snap),
          AsyncData() => const _PrepView(),
          AsyncError() => const Center(child: Text(Vi.buLoadFailed)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _activeBody(TestSnapshot snap) => DrillRunner(snap: snap);
}

/// Bước chuẩn bị: kích thước bàn, giới thiệu đề và nguồn, giãn cách 14 ngày.
class _PrepView extends ConsumerStatefulWidget {
  const _PrepView();

  @override
  ConsumerState<_PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends ConsumerState<_PrepView> {
  TableSize _size = TableSize.nineFootPlus;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await ref.read(assessmentRepositoryProvider)!.startTest(_size);
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final tests = ref.watch(buTestsProvider).value ?? const <BuTest>[];
    final now = ref.watch(nowProvider)();
    final from = retestAvailableFrom(tests);
    final blocked = from != null && now.isBefore(from);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(Vi.buPrepTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const Text(Vi.buPrepIntro),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buSourceLine, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Text(Vi.buTableSizeLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in TableSize.values)
              ChoiceChip(
                label: Text(Vi.buTableSize(s)),
                selected: _size == s,
                onSelected: (_) => setState(() => _size = s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(Vi.buDoctorateNeedsNine, style: Theme.of(context).textTheme.bodySmall),
        if (blocked) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(Vi.buRetestFrom(from)),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: blocked || _starting ? null : _start,
          child: const Text(Vi.buStart),
        ),
      ],
    );
  }
}

/// Một bài đang làm: sơ đồ, hướng dẫn, nguồn, điểm hiện tại, ô nhập theo
/// kiểu chấm và nút hoàn tác (spec mục 7.3 bước 2).
class DrillRunner extends ConsumerStatefulWidget {
  const DrillRunner({required this.snap, super.key});

  final TestSnapshot snap;

  @override
  ConsumerState<DrillRunner> createState() => _DrillRunnerState();
}

class _DrillRunnerState extends ConsumerState<DrillRunner> {
  /// Đang ghi một cú: khoá ô nhập, để hai lần bấm nhanh không cùng dựa
  /// trên một bản kết quả cũ mà làm mất một cú.
  bool _busy = false;

  Future<void> _write(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    final drill = snap.nextDrill;
    if (drill == null) return const SizedBox.shrink();
    final version = snap.test.examIIVersion;
    final attempts = snap.attemptsOf(drill);
    final repo = ref.read(assessmentRepositoryProvider)!;
    final layout = layoutForAttempt(drill, version, attempts.length.clamp(0, drill.attemptCount - 1));
    final position = switch (attempts) {
      ShotAttempts(:final shots) when drill.kind == ScoringKind.positionLadder => ladderPosition(shots),
      _ => null,
    };
    final drills = snap.currentDrills;
    final canUndo = drills.any((d) => !snap.attemptsOf(d).isEmpty);

    Future<void> record(DrillAttempts next) =>
        _write(() => repo.recordAttempts(snap.test.id, drill.id, next));

    final input = switch (attempts) {
      ShotAttempts a => ShotInput(drillId: drill.id, enabled: !_busy, onShot: (made) => record(a.add(made))),
      CountAttempts a => CountInput(
          key: ValueKey('${drill.id}-${a.length}'),
          max: drill.perAttemptMax!,
          enabled: !_busy,
          onSubmit: (n) => record(a.add(n)),
        ),
      BreakAttempts a => BreakInput(
          key: ValueKey('${drill.id}-${a.length}'),
          enabled: !_busy,
          onSubmit: (b) => record(a.add(b)),
        ),
    };

    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(Vi.buRunnerHeader(snap.currentExam, version, drills.indexOf(drill) + 1, drills.length),
            style: text.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(Vi.buDrillTitle(drill.id), style: text.titleMedium),
        Text(Vi.buRunningScore(snap.currentExam, snap.runningScore)),
        const SizedBox(height: AppSpacing.md),
        BuLayoutView(layout: layout, highlightPosition: position),
        if (position != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(Vi.buLadderPosition(position), style: text.titleSmall),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buAttemptLabel(drill, attempts.length), style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        input,
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: canUndo && !_busy ? () => _write(() => repo.undoLastShot(snap.test.id)) : null,
            icon: const Icon(Icons.undo),
            label: const Text(Vi.buUndo),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buDrillScoring(drill.id, version)),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buDrillSetup(drill.id, version)),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buLayoutSource(layout.source), style: text.bodySmall),
      ],
    );
  }
}
```

Every import above is used in this task; Task 15 adds `assessment_repository.dart`, `go_router`, `routes.dart` and `test_result_view.dart`.

- [ ] **Step 6: Run and commit**

```bash
"$FLUTTER" test test/features/rank test/smoke test/architecture_test.dart
```

Expected: PASS (in the S1 test the placement view does not exist yet, so the runner opens directly).

```bash
git add lib/features/rank/presentation/drill_inputs.dart lib/features/rank/presentation/test_screen.dart lib/core/router lib/core/strings/vi.dart test/features/rank/drill_inputs_test.dart test/features/rank/test_runner_test.dart test/smoke/all_routes_test.dart
git commit -m "Add the BU test runner with per-kind inputs, undo and the live ladder position

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: End of Exam I, Exam II now or later, completion, result and cancel (spec §7.3 steps 3–4, §4.2)

**Files:**
- Modify: `lib/features/rank/presentation/test_screen.dart` (`_TestScreenState`)
- Create: `lib/features/rank/presentation/test_result_view.dart`
- Modify: `lib/core/strings/vi.dart`
- Test: `test/features/rank/test_flow_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository.finishExamI`, `.completeTest`, `.cancelTest`, `TestCompleted`, `CompletionTooSoon` (Task 8); `testSnapshotProvider` (Task 8); `bandForBuScore`, `examIIMax`, `examIMax` (Tasks 2, 4); `RankOutcome` (Task 1); `Routes.profile`.
- Produces:
  - `class TestResultView extends ConsumerWidget { const TestResultView({required String testId, TestCompleted? outcome}); }`;
  - `Vi.buExamIReadyTitle`, `Vi.buExamIReadyAction`, `Vi.buExamIScore`, `Vi.buPlacement`, `Vi.buPlacementSmallTable`, `Vi.buExamIINow`, `Vi.buExamIILater`, `Vi.buFinishTitle`, `Vi.buFinishAction`, `Vi.buCompletionTooSoon`, `Vi.buResultTitle`, `Vi.buDrillScoreLine`, `Vi.buExamScoreLine`, `Vi.buTotal`, `Vi.buBand`, `Vi.buFargo`, `Vi.rankOutcome`, `Vi.buResultDone`, `Vi.buCancelTest`, `Vi.buCancelConfirmBody`, `Vi.buCancelConfirm`.

- [ ] **Step 1: Strings**

Add to `vi.dart` (import `rank_rules.dart` for `RankOutcome`):

```dart
  static const buExamIReadyTitle = 'Xong Đề I';
  static const buExamIReadyAction = 'Chấm Đề I';
  static String buExamIScore(int s) => 'Điểm Đề I: $s / $examIMax';
  static String buPlacement(ExamIIVersion v) => 'Bạn làm Đề II bản ${buVersionName(v)}.';
  static const buPlacementSmallTable =
      'Đề I đạt mức Doctorate nhưng bàn nhỏ hơn 9 feet, nên làm bản Masters.';
  static const buExamIINow = 'Làm Đề II ngay';
  static const buExamIILater = 'Để buổi khác';
  static const buFinishTitle = 'Xong Đề II';
  static const buFinishAction = 'Hoàn tất và xem kết quả';
  static String buCompletionTooSoon(DateTime d) => 'Lần kiểm tra trước hoàn tất chưa đủ 14 '
      'ngày. Lần này hoàn tất được từ ngày ${shortDate(d)}; các cú đã nhập vẫn còn nguyên.';
  static const buResultTitle = 'Kết quả kiểm tra';
  static String buDrillScoreLine(String id, int score, int max) =>
      '${buDrillTitle(id)}: $score / $max';
  static String buExamScoreLine(BuExam e, int s, int max) => '${buExamName(e)}: $s / $max';
  static String buTotal(int total) => 'Điểm BU: $total / $buTotalMax';
  static String buBand(BuRankBand b) => 'Mức BU: ${b.buLevels}';
  static String buFargo(BuRankBand b) => 'Fargo tham chiếu: ${b.fargo}';
  static const buResultDone = 'Xong';

  /// Câu kết quả hạng — đúng một câu cho mỗi luật của spec mục 4.2.
  static String rankOutcome(RankOutcome o, Rank? before, Rank result) => switch (o) {
        RankOutcome.firstRank => 'Bạn nhận hạng ${result.label}, đã kiểm chứng.',
        RankOutcome.promoted => 'Lên hạng: ${before!.label} → ${result.label}, đã kiểm chứng.',
        RankOutcome.confirmed => 'Giữ hạng ${result.label}, nay đã kiểm chứng.',
        RankOutcome.warned => 'Kết quả tương đương hạng ${result.label}, thấp hơn hạng hiện '
            'tại ${before!.label}. Hạng giữ nguyên và có cảnh báo cho tới khi một lần sau '
            'đạt ${before.label} trở lên.',
      };

  static const buCancelTest = 'Hủy lần kiểm tra này';
  static const buCancelConfirmBody =
      'Hủy lần này? Các cú đã nhập không được tính và hạng không đổi.';
  static const buCancelConfirm = 'Hủy lần này';
```

- [ ] **Step 2: Failing flow tests**

`test/features/rank/test_flow_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/profile/presentation/profile_screen.dart';

import '../../support/assessment_fixtures.dart';
import '../../support/test_data.dart';

void main() {
  late AppDatabase db;
  late AssessmentRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    var n = 0;
    repo = AssessmentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'seed${++n}');
  });
  tearDown(() => db.close());

  Future<GoRouter> open(WidgetTester tester) async {
    final container = dbContainer(db);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
    return router;
  }

  Future<String> examIDone({TableSize size = TableSize.nineFootPlus, bool full = false}) async {
    final id = (await repo.startTest(size) as TestStarted).testId;
    for (final e in examIAttempts(wagonAndTargetMade: full).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    return id;
  }

  testWidgets('xong Đề I: chấm, hiện bản Đề II, Làm Đề II ngay thì vào S1', (tester) async {
    await examIDone();
    await open(tester);
    expect(find.text(Vi.buExamIReadyTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buExamIReadyAction));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buExamIScore(60)), findsOneWidget);
    expect(find.text(Vi.buPlacement(ExamIIVersion.masters)), findsOneWidget);
    await tester.tap(find.text(Vi.buExamIINow));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buDrillTitle('S1')), findsOneWidget);
  });

  testWidgets('Để buổi khác: về Hồ sơ; mở lại thì hỏi lại rồi làm tiếp được', (tester) async {
    final id = await examIDone();
    await repo.finishExamI(id);
    final router = await open(tester);
    await tester.tap(find.text(Vi.buExamIILater));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    router.go(Routes.rankTest);
    await tester.pumpAndSettle();
    expect(find.text(Vi.buExamIINow), findsOneWidget);
  });

  testWidgets('bàn 8 feet, Đề I 100: báo làm bản Masters vì bàn nhỏ', (tester) async {
    final id = await examIDone(size: TableSize.eightFoot, full: true);
    await repo.finishExamI(id);
    await open(tester);
    expect(find.text(Vi.buPlacement(ExamIIVersion.masters)), findsOneWidget);
    expect(find.text(Vi.buPlacementSmallTable), findsOneWidget);
  });

  testWidgets('hoàn tất: điểm từng bài, tổng, mức BU, Fargo và câu lên hạng', (tester) async {
    await repo.saveQuestionnaire(chosen: Rank.h, suggested: Rank.h,
        answers: QuestionnaireAnswers([0, 0, 0, 0, 1, 0, 0, 0]));
    final id = await examIDone();
    await repo.finishExamI(id);
    for (final e in examIIPerfect(ExamIIVersion.masters).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await open(tester);
    expect(find.text(Vi.buFinishTitle), findsOneWidget);
    await tester.tap(find.text(Vi.buFinishAction));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buResultTitle), findsWidgets);
    expect(find.text(Vi.buTotal(137)), findsOneWidget);
    expect(find.text(Vi.buBand(bandForBuScore(137))), findsOneWidget);
    expect(find.text(Vi.buFargo(bandForBuScore(137))), findsOneWidget);
    expect(find.text(Vi.rankOutcome(RankOutcome.promoted, Rank.h, Rank.d)), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Vi.buDrillScoreLine('S10', 5, 5)), 200);
    expect(find.text(Vi.buDrillScoreLine('S10', 5, 5)), findsOneWidget);
  });

  testWidgets('hoàn tất khi chưa đủ 14 ngày: báo ngày được hoàn tất, hạng không đổi', (tester) async {
    final id = await examIDone();
    await repo.finishExamI(id);
    for (final e in examIIPerfect(ExamIIVersion.masters).entries) {
      await repo.recordAttempts(id, e.key, e.value);
    }
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'may-khac', userId: 'u1', startedAt: testToday, tableSize: 'nineFootPlus',
        completedAt: Value(testToday.subtract(const Duration(days: 2))),
        totalScore: const Value(80), resultRank: const Value('g')));
    await open(tester);
    await tester.tap(find.text(Vi.buFinishAction));
    await tester.pumpAndSettle();
    final from = DateTime(testToday.year, testToday.month, testToday.day - 2 + 14);
    expect(find.text(Vi.buCompletionTooSoon(from)), findsOneWidget);
    expect(await db.select(db.playerRankRows).getSingleOrNull(), isNull);
  });

  testWidgets('Hủy lần kiểm tra này: xác nhận rồi về Hồ sơ', (tester) async {
    final id = (await repo.startTest(TableSize.nineFootPlus) as TestStarted).testId;
    await repo.recordAttempts(id, 'F1', ShotAttempts([true]));
    await open(tester);
    await tester.tap(find.byTooltip(Vi.buCancelTest));
    await tester.pumpAndSettle();
    expect(find.text(Vi.buCancelConfirmBody), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Vi.buCancelConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect((await db.select(db.buTestRows).getSingle()).cancelledAt, isNotNull);
  });
}
```

Run `"$FLUTTER" test test/features/rank/test_flow_test.dart`. Expected: FAIL — the views do not exist (the runner shows nothing after Exam I).

- [ ] **Step 3: Write `test_result_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/data/repositories/assessment_repository.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';

/// Kết quả một lần kiểm tra đã hoàn tất (spec mục 7.3 bước 4): điểm từng
/// bài, tổng điểm BU, mức BU, Fargo tham chiếu và câu kết quả hạng.
class TestResultView extends ConsumerWidget {
  const TestResultView({required this.testId, this.outcome, super.key});

  final String testId;

  /// Có khi vừa hoàn tất trong phiên này; null khi xem lại.
  final TestCompleted? outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(testSnapshotProvider(testId)).value;
    if (snap == null || !snap.test.isCompleted) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = snap.test;
    final version = t.examIIVersion!;
    final band = bandForBuScore(t.totalScore!);
    final text = Theme.of(context).textTheme;
    final o = outcome;

    List<Widget> lines(List<BuDrill> drills) => [
          for (final d in drills)
            Text(Vi.buDrillScoreLine(d.id, snap.scoreOf([d]), d.maxScore)),
        ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(Vi.buResultTitle, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Align(alignment: Alignment.centerLeft, child: PcRankBadge(rank: band.rank, showWord: true)),
        const SizedBox(height: AppSpacing.sm),
        Text(Vi.buTotal(t.totalScore!), style: text.titleMedium),
        Text(Vi.buBand(band)),
        Text(Vi.buFargo(band)),
        if (o != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(Vi.rankOutcome(o.outcome, o.before, o.result), style: text.titleSmall),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(Vi.buExamScoreLine(BuExam.fundamentals, t.examIScore!, examIMax), style: text.titleSmall),
        ...lines(examIDrills),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buExamScoreLine(BuExam.skills, t.examIIScore!, examIIMax(version)),
            style: text.titleSmall),
        ...lines(examIIDrills(version)),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.rankDisclaimer, style: text.bodySmall),
        Text(Vi.buSourceLine, style: text.bodySmall),
      ],
    );
  }
}
```

- [ ] **Step 4: Extend `_TestScreenState`**

Replace the `_TestScreenState` class of Task 14 with:

```dart
class _TestScreenState extends ConsumerState<TestScreen> {
  /// Lần vừa hoàn tất trong phiên này: nó không còn "đang làm", nên giữ id
  /// để tiếp tục hiện kết quả.
  ({String testId, TestCompleted outcome})? _finished;

  /// Đã bấm *Làm Đề II ngay* cho lần này.
  String? _examIINow;
  DateTime? _tooSoon;
  bool _busy = false;

  AssessmentRepository get _repo => ref.read(assessmentRepositoryProvider)!;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(String testId) => _run(() async {
        final out = await _repo.completeTest(testId);
        if (!mounted) return;
        setState(() {
          switch (out) {
            case TestCompleted():
              _finished = (testId: testId, outcome: out);
            case CompletionTooSoon(:final from):
              _tooSoon = from;
          }
        });
      });

  Future<void> _cancel(String testId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(Vi.buCancelConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Vi.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Vi.buCancelConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.cancelTest(testId);
    if (mounted) context.go(Routes.profile);
  }

  @override
  Widget build(BuildContext context) {
    final finished = _finished;
    if (finished != null) {
      return Scaffold(
        appBar: AppBar(title: const Text(Vi.buResultTitle)),
        body: SafeArea(child: TestResultView(testId: finished.testId, outcome: finished.outcome)),
      );
    }
    final active = ref.watch(activeTestProvider);
    final snap = active.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Vi.buTestTitle),
        actions: [
          if (snap != null)
            IconButton(
              tooltip: Vi.buCancelTest,
              icon: const Icon(Icons.close),
              onPressed: () => _cancel(snap.test.id),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (active) {
          AsyncData(value: final s?) => _activeBody(s),
          AsyncData() => const _PrepView(),
          AsyncError() => const Center(child: Text(Vi.buLoadFailed)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _activeBody(TestSnapshot snap) {
    final t = snap.test;
    final text = Theme.of(context).textTheme;
    final button = FilledButton.styleFrom(minimumSize: const Size.fromHeight(48));

    if (snap.examIReady) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(Vi.buExamIReadyTitle, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buExamIScore(snap.scoreOf(examIDrills))),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          style: button,
          onPressed: _busy ? null : () => _run(() => _repo.finishExamI(t.id)),
          child: const Text(Vi.buExamIReadyAction),
        ),
      ]);
    }

    // Đề I đã chốt mà Đề II chưa có cú nào: hỏi làm ngay hay để buổi khác.
    if (t.examIScore != null && !snap.examIIStarted && _examIINow != t.id) {
      final small = t.tableSize != TableSize.nineFootPlus && t.examIScore! >= 70;
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(Vi.buExamIScore(t.examIScore!), style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buPlacement(t.examIIVersion!)),
        if (small) Text(Vi.buPlacementSmallTable),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          style: button,
          onPressed: () => setState(() => _examIINow = t.id),
          child: const Text(Vi.buExamIINow),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.go(Routes.profile),
          child: const Text(Vi.buExamIILater),
        ),
      ]);
    }

    if (snap.examIIReady) {
      final from = _tooSoon;
      return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(Vi.buFinishTitle, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(Vi.buExamScoreLine(
            BuExam.skills, snap.scoreOf(examIIDrills(t.examIIVersion!)), examIIMax(t.examIIVersion!))),
        if (from != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(Vi.buCompletionTooSoon(from)),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          style: button,
          onPressed: _busy ? null : () => _complete(t.id),
          child: const Text(Vi.buFinishAction),
        ),
      ]);
    }

    return DrillRunner(snap: snap);
  }
}
```

Add the imports `package:go_router/go_router.dart`, `package:poolcoachai/core/router/routes.dart`, `package:poolcoachai/data/repositories/assessment_repository.dart` and `test_result_view.dart`. Note the screen pre-counts nothing: every score on these views comes from `TestSnapshot.scoreOf`, i.e. from `drillScore`.

- [ ] **Step 5: Run and commit**

```bash
"$FLUTTER" test test/features/rank test/smoke
```

Expected: PASS, including Task 14's S1 test (it records an empty S1 first, so the placement view is skipped).

```bash
git add lib/features/rank/presentation/test_screen.dart lib/features/rank/presentation/test_result_view.dart lib/core/strings/vi.dart test/features/rank/test_flow_test.dart
git commit -m "Finish a BU test: Exam II now or later, the 14-day completion check, the result and cancel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Rank on Hồ sơ, Trang chủ and `/rank`, with the ⓘ sheet (spec §4.3, §7.4)

**Files:**
- Create: `lib/features/rank/presentation/rank_badge_line.dart`
- Create: `lib/features/rank/presentation/rank_card.dart`
- Create: `lib/features/rank/presentation/rank_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart` (`_signOut` at lines 17–67; `build` at lines 69–98)
- Modify: `lib/features/home/presentation/home_screen.dart` (first child of the `ListView` at line 29)
- Modify: `lib/core/router/routes.dart` (`rank` + `Routes.all`), `lib/core/router/app_router.dart`
- Modify: `lib/core/strings/vi.dart`
- Modify: `test/features/profile/profile_screen_test.dart` (`openProfile` at lines 9–64; append tests)
- Modify: `test/features/home/home_screen_test.dart` (append tests)
- Modify: `test/smoke/all_routes_test.dart`
- Test: `test/features/rank/rank_card_test.dart`

**Interfaces:**
- Consumes: `playerRankProvider`, `buTestsProvider`, `activeTestProvider`, `assessmentSyncProvider` (Tasks 8–9); `canUseQuestionnaire` (Task 1); `retestAvailableFrom` (Task 6); `buRankBands` (Task 2); `pendingAssessmentCount`, `hasActiveTest` (Task 8); `PcRankBadge`, `PcCard`.
- Produces:
  - `class RankBadgeLine extends StatelessWidget { const RankBadgeLine({required PlayerRank rank}); }`, `Future<void> showRankInfoSheet(BuildContext context)`, `class RankInfoSheet extends StatelessWidget`;
  - `class RankCard extends ConsumerWidget { const RankCard({bool showDetailsLink = true}); }`, `class TestHistoryList extends ConsumerWidget`, `class HomeRankHeader extends ConsumerWidget`;
  - `class RankScreen extends ConsumerWidget`, `Routes.rank = '/rank'`;
  - strings listed in Step 1.

- [ ] **Step 1: Strings**

Add to `vi.dart` (import `player_rank.dart`):

```dart
  // Hạng trên Hồ sơ, Trang chủ và màn Hạng — spec mục 4.3, 7.4.
  static String rankSource(RankSource s) => switch (s) {
        RankSource.estimated => 'ước lượng',
        RankSource.selfDeclared => 'tự khai',
        RankSource.verified => 'đã kiểm chứng',
      };
  static const rankInfo = 'Về bảng hạng';
  static const rankInfoTitle = 'Bảng hạng PoolCoachAI';
  static const rankTableTitle = 'Quy đổi điểm Billiard University sang hạng';
  static String rankBandRange(BuRankBand b) => '${b.min}–${b.max} điểm';
  static String rankBandLevels(BuRankBand b) => 'Mức BU: ${b.buLevels} · Fargo ${b.fargo}';
  static const rankProNote = 'PRO chỉ có khi tự khai. Bài kiểm tra BU cao nhất ra hạng A.';
  static const rankNone = 'Bạn chưa có hạng.';
  static String rankWarning(Rank w) => 'Lần kiểm tra gần nhất cho kết quả tương đương hạng '
      '${w.label}, thấp hơn hạng hiện tại.';
  static String rankLastTest(DateTime d, int total, Rank r) =>
      'Lần kiểm tra gần nhất: ${shortDate(d)} · $total điểm · hạng ${r.label}';
  static const rankContinueTest = 'Làm tiếp';
  static const rankDetermine = 'Xác định hạng';
  static const rankTakeTest = 'Làm bài kiểm tra';
  static const rankDetails = 'Xem chi tiết hạng';
  static const rankScreenTitle = 'Hạng của bạn';
  static const rankRetakeQuestionnaire = 'Làm lại bộ câu hỏi';
  static const rankShowLayouts = 'Xem sơ đồ các bài';
  static const rankHistoryTitle = 'Lịch sử kiểm tra';
  static const rankHistoryEmpty = 'Chưa có lần kiểm tra nào.';
  static String rankHistoryCompleted(DateTime d, int total, Rank r) =>
      '${shortDate(d)} · $total điểm · hạng ${r.label}';
  static String rankHistoryCancelled(DateTime d) => '${shortDate(d)} · đã hủy';
  static const homeRankCardTitle = 'Xác định hạng của bạn';
  static const homeRankCardBody = 'Trả lời 8 câu hỏi để có hạng gợi ý, hoặc làm bài kiểm tra '
      'Billiard University để có hạng đã kiểm chứng.';
  static String signOutPendingAssessment(int n) =>
      'Còn $n mục hạng hoặc bài kiểm tra chưa đồng bộ, đăng xuất sẽ mất.';
  static const signOutActiveTest = 'Lần kiểm tra đang làm dở sẽ mất khi đăng xuất.';
```

- [ ] **Step 2: Failing widget tests for the card, the sheet and the home header**

`test/features/rank/rank_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/features/rank/presentation/onboarding_screen.dart';
import 'package:poolcoachai/features/rank/presentation/test_screen.dart';

import '../../support/test_data.dart';

void main() {
  final verifiedD = PlayerRank(
    rank: Rank.d, source: RankSource.verified, buScore: 137, testId: 't1',
    warningRank: Rank.g, warningTestId: 't2',
    onboardingState: OnboardingState.done, updatedAt: testToday,
  );
  final done = BuTest(
    id: 't1', startedAt: testToday.subtract(const Duration(days: 4)),
    tableSize: TableSize.nineFootPlus,
    completedAt: testToday.subtract(const Duration(days: 3)),
    examIScore: 60, examIIVersion: ExamIIVersion.masters, examIIScore: 77,
    totalScore: 137, resultRank: Rank.d,
  );
  final cancelled = BuTest(
    id: 't0', startedAt: testToday.subtract(const Duration(days: 9)),
    tableSize: TableSize.eightFoot, cancelledAt: testToday.subtract(const Duration(days: 9)),
  );

  Future<void> pump(WidgetTester tester, String location,
      {PlayerRank? rank, List<BuTest> tests = const [], TestSnapshot? active}) async {
    final container = testContainer(rank: rank, tests: tests, activeTest: active);
    addTearDown(container.dispose);
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: PoolCoachApp(router: router)));
    await tester.pumpAndSettle();
    router.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('Hồ sơ: huy hiệu, nhãn nguồn, cảnh báo, lần gần nhất, ngày kiểm tra lại', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD, tests: [done, cancelled]);
    expect(find.text('HẠNG D'), findsOneWidget);
    expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
    expect(find.text(Vi.rankWarning(Rank.g)), findsOneWidget);
    expect(find.text(Vi.rankLastTest(done.completedAt!, 137, Rank.d)), findsOneWidget);
    final from = DateTime(testToday.year, testToday.month, testToday.day - 3 + 14);
    expect(find.text(Vi.buRetestFrom(from)), findsOneWidget);
    expect(find.text(Vi.rankTakeTest), findsOneWidget);
  });

  testWidgets('Hồ sơ: lịch sử có cả lần hoàn tất và lần đã hủy', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD, tests: [done, cancelled]);
    await tester.scrollUntilVisible(find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)), 200);
    expect(find.text(Vi.rankHistoryCompleted(done.completedAt!, 137, Rank.d)), findsOneWidget);
    expect(find.text(Vi.rankHistoryCancelled(cancelled.cancelledAt!)), findsOneWidget);
  });

  testWidgets('chưa có hạng: Xác định hạng mở bộ câu hỏi', (tester) async {
    await pump(tester, Routes.profile);
    expect(find.text(Vi.rankNone), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Vi.rankDetermine));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('có lần làm dở: Làm tiếp mở màn làm bài', (tester) async {
    final active = TestSnapshot(
      test: BuTest(id: 'ta', startedAt: testToday, tableSize: TableSize.nineFootPlus),
      attempts: const {},
    );
    await pump(tester, Routes.profile, rank: verifiedD, active: active);
    await tester.tap(find.text(Vi.rankContinueTest));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen), findsOneWidget);
  });

  testWidgets('ⓘ mở câu miễn trừ, bảng quy đổi và nguồn BU', (tester) async {
    await pump(tester, Routes.profile, rank: verifiedD);
    await tester.tap(find.byTooltip(Vi.rankInfo));
    await tester.pumpAndSettle();
    expect(find.text(Vi.rankDisclaimer), findsOneWidget);
    expect(find.text(Vi.rankTableTitle), findsOneWidget);
    expect(find.text(Vi.rankBandRange(buRankBands.first)), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Vi.buSourceLine), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(Vi.buSourceLine), findsOneWidget);
  });

  testWidgets('chưa có hạng: Trang chủ hiện thẻ Xác định hạng của bạn', (tester) async {
    await pump(tester, Routes.home);
    expect(find.text(Vi.homeRankCardTitle), findsOneWidget);
  });

  testWidgets('có hạng: Trang chủ hiện huy hiệu nhỏ và nhãn nguồn', (tester) async {
    await pump(tester, Routes.home, rank: verifiedD);
    expect(find.text('HẠNG D'), findsOneWidget);
    expect(find.text(Vi.rankSource(RankSource.verified)), findsOneWidget);
    expect(find.text(Vi.homeRankCardTitle), findsNothing);
  });

  testWidgets('màn Hạng: hạng đã kiểm chứng thì không có Làm lại bộ câu hỏi', (tester) async {
    await pump(tester, Routes.rank, rank: verifiedD);
    expect(find.text(Vi.rankRetakeQuestionnaire), findsNothing);
    expect(find.text(Vi.rankShowLayouts), findsOneWidget);
  });

  testWidgets('màn Hạng: hạng ước lượng thì làm lại được', (tester) async {
    await pump(tester, Routes.rank, rank: PlayerRank(
      rank: Rank.h, source: RankSource.estimated,
      onboardingState: OnboardingState.done, updatedAt: testToday,
    ));
    expect(find.text(Vi.rankRetakeQuestionnaire), findsOneWidget);
  });
}
```

Add `Routes.rank: (path: Routes.rank, screen: RankScreen),` to the smoke test (import `rank_screen.dart`).

Run `"$FLUTTER" test test/features/rank/rank_card_test.dart`. Expected: FAIL.

- [ ] **Step 3: Write `rank_badge_line.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_rank_badge.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';

/// Huy hiệu + nhãn nguồn + ⓘ — cách duy nhất app hiện một hạng (spec mục 4.3).
class RankBadgeLine extends StatelessWidget {
  const RankBadgeLine({required this.rank, super.key})
      : assert(rank.rank != null, 'chỉ dùng khi đã có hạng');

  final PlayerRank rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PcRankBadge(rank: rank.rank!, showWord: true),
        const SizedBox(width: AppSpacing.sm),
        Text(Vi.rankSource(rank.source!), style: Theme.of(context).textTheme.bodySmall),
        IconButton(
          tooltip: Vi.rankInfo,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showRankInfoSheet(context),
        ),
      ],
    );
  }
}

Future<void> showRankInfoSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RankInfoSheet(),
    );

/// Câu miễn trừ, bảng quy đổi BU sang hạng và dòng nguồn (spec mục 4.3).
class RankInfoSheet extends StatelessWidget {
  const RankInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(Vi.rankInfoTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text(Vi.rankDisclaimer),
          const SizedBox(height: AppSpacing.lg),
          Text(Vi.rankTableTitle, style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final b in buRankBands)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: PcRankBadge(rank: b.rank),
              title: Text(Vi.rankBandRange(b)),
              subtitle: Text(Vi.rankBandLevels(b)),
            ),
          const SizedBox(height: AppSpacing.sm),
          const Text(Vi.rankProNote),
          const SizedBox(height: AppSpacing.sm),
          Text(Vi.buSourceLine, style: text.bodySmall),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write `rank_card.dart` and `rank_screen.dart`, route, Home, Hồ sơ**

`lib/features/rank/presentation/rank_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_colors.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/features/rank/presentation/rank_badge_line.dart';

/// Thẻ hạng của Hồ sơ (spec mục 7.4).
class RankCard extends ConsumerWidget {
  const RankCard({this.showDetailsLink = true, super.key});

  final bool showDetailsLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(playerRankProvider).value;
    final tests = ref.watch(buTestsProvider).value ?? const <BuTest>[];
    final active = ref.watch(activeTestProvider).value;
    final now = ref.watch(nowProvider)();
    BuTest? last;
    for (final t in tests) {
      if (t.isCompleted && (last == null || t.completedAt!.isAfter(last.completedAt!))) last = t;
    }
    final from = retestAvailableFrom(tests);
    final hasRank = rank?.rank != null;
    const tall = Size.fromHeight(48);

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasRank) RankBadgeLine(rank: rank!) else const Text(Vi.rankNone),
          if (rank?.warningRank != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(Vi.rankWarning(rank!.warningRank!),
                style: const TextStyle(color: AppColors.warning)),
          ],
          if (last != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(Vi.rankLastTest(last.completedAt!, last.totalScore!, last.resultRank!)),
          ],
          if (from != null && now.isBefore(from)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(Vi.buRetestFrom(from)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (active != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: () => context.push(Routes.rankTest),
              child: const Text(Vi.rankContinueTest),
            )
          else ...[
            if (!hasRank) ...[
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: tall),
                onPressed: () => context.push(Routes.onboardingRank),
                child: const Text(Vi.rankDetermine),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: tall),
              onPressed: () => context.push(Routes.rankTest),
              child: const Text(Vi.rankTakeTest),
            ),
          ],
          if (showDetailsLink)
            TextButton(
              onPressed: () => context.push(Routes.rank),
              child: const Text(Vi.rankDetails),
            ),
        ],
      ),
    );
  }
}

/// Lịch sử các lần kiểm tra đã xong (hoàn tất hoặc hủy), mới nhất trước.
class TestHistoryList extends ConsumerWidget {
  const TestHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = [
      for (final t in ref.watch(buTestsProvider).value ?? const <BuTest>[])
        if (!t.isActive) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Vi.rankHistoryTitle, style: Theme.of(context).textTheme.titleSmall),
        if (tests.isEmpty) const Text(Vi.rankHistoryEmpty),
        for (final t in tests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(t.isCompleted ? Icons.verified_outlined : Icons.cancel_outlined),
            title: Text(t.isCompleted
                ? Vi.rankHistoryCompleted(t.completedAt!, t.totalScore!, t.resultRank!)
                : Vi.rankHistoryCancelled(t.cancelledAt!)),
          ),
      ],
    );
  }
}

/// Đầu Trang chủ: huy hiệu nhỏ, hoặc thẻ *Xác định hạng của bạn* (spec mục 7.4).
class HomeRankHeader extends ConsumerWidget {
  const HomeRankHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerRankProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final rank = async.value;
    if (rank?.rank != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: RankBadgeLine(rank: rank!),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Vi.homeRankCardTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const Text(Vi.homeRankCardBody),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.push(Routes.onboardingRank),
              child: const Text(Vi.rankDetermine),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/rank/presentation/rank_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/features/rank/presentation/rank_card.dart';

/// Chi tiết hạng và lịch sử kiểm tra (spec mục 7.1).
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(playerRankProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Vi.rankScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const RankCard(showDetailsLink: false),
          const SizedBox(height: AppSpacing.md),
          if (rank.hasValue && rank.value?.rank != null && canUseQuestionnaire(rank.value))
            OutlinedButton(
              onPressed: () => context.push(Routes.onboardingRank),
              child: const Text(Vi.rankRetakeQuestionnaire),
            ),
          TextButton(
            onPressed: () => context.push(Routes.rankLayouts),
            child: const Text(Vi.rankShowLayouts),
          ),
          const SizedBox(height: AppSpacing.md),
          const TestHistoryList(),
        ],
      ),
    );
  }
}
```

`routes.dart`: add `static const rank = '/rank';` (doc: "Chi tiết hạng — mở đè lên shell (spec mục 7.1).") before `rankLayouts`, and to `Routes.all`. `app_router.dart`: add before the `Routes.rankLayouts` route:

```dart
    GoRoute(
      path: Routes.rank,
      builder: (context, state) => const RankScreen(),
    ),
```

`home_screen.dart`: insert `const HomeRankHeader(),` as the first child of the `ListView` (before the streak `PcCard`), with the import of `rank_card.dart`.

`profile_screen.dart`: replace the `Expanded(child: PcEmptyState(...))` in `build` with:

```dart
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(Vi.profileSignedInAs(name)),
                const SizedBox(height: AppSpacing.md),
                const RankCard(),
                const SizedBox(height: AppSpacing.lg),
                const TestHistoryList(),
                const SizedBox(height: AppSpacing.xxl),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text(Vi.profileSignOut),
                ),
              ],
            ),
          ),
```

and in `_signOut` replace the block from `final pending = await pendingLogCount(db, userId);` to the end of the `if (pending > 0) { … }` block with:

```dart
    final pending = await pendingLogCount(db, userId);
    final pendingRank = await pendingAssessmentCount(db, userId);
    final active = await hasActiveTest(db, userId);
    if (pending > 0 || pendingRank > 0 || active) {
      if (!context.mounted) return;
      final choice = await showDialog<_SignOutChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Vi.signOutPendingTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending > 0) Text(Vi.signOutPendingBody(pending)),
              if (pendingRank > 0) Text(Vi.signOutPendingAssessment(pendingRank)),
              if (active) const Text(Vi.signOutActiveTest),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.anyway),
              child: const Text(Vi.signOutAnyway),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.syncFirst),
              child: const Text(Vi.signOutSyncFirst),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == _SignOutChoice.syncFirst) {
        await ref.read(syncServiceProvider).syncNow();
        await ref.read(assessmentSyncProvider).syncNow();
        final left = await pendingLogCount(db, userId);
        final leftRank = await pendingAssessmentCount(db, userId);
        if (left > 0 || leftRank > 0) {
          // Chỉ còn buổi không bao giờ lên được thì mạng không phải lý do:
          // thử lại mãi cũng vậy, phải chỉ người chơi tới chỗ bỏ chúng.
          final unsyncable = await unsyncableLogCount(db, userId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(left == unsyncable && leftRank == 0
                ? Vi.syncBlockedByUnsyncable
                : Vi.syncFailed),
          ));
          return;
        }
      }
    }
```

(A test in progress cannot be synced, so it never blocks *Đồng bộ trước*; the dialog only warns about it.) Update the imports: drop `pc_empty_state.dart`; add `assessment_providers.dart`, `app_spacing.dart` (already there), `rank_card.dart`.

- [ ] **Step 5: Keep the profile tests hermetic and add the sign-out cases**

In `test/features/profile/profile_screen_test.dart`, inside `openProfile`, register the assessment routes on the fake server and override the assessment sync with a non-started service on it, so no real HTTP client and no periodic timer ever exist in these tests:

```dart
    server
      ..routes['GET /items/player_ranks'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/player_ranks'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['GET /items/bu_tests'] = ((_) => FakeDirectus.ok([]))
      ..routes['GET /items/bu_drill_results'] = ((_) => FakeDirectus.ok([]))
      ..routes['POST /items/bu_tests'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))
      ..routes['POST /items/bu_drill_results'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)));
    final assessmentSync = AssessmentSyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
      onRankFetch: (_, _) {},
    );
    addTearDown(assessmentSync.dispose);
```

and add `assessmentSyncProvider.overrideWithValue(assessmentSync),` to the container's overrides (imports `assessment_providers.dart`, `assessment_sync.dart`). Then append:

```dart
  testWidgets('đăng xuất khi có lần kiểm tra dở: cảnh báo sẽ mất, Vẫn đăng xuất thì xoá', (tester) async {
    final (db, auth, _) = await openProfile(tester);
    await db.into(db.buTestRows).insert(BuTestRowsCompanion.insert(
        id: 'do', userId: 'u1', startedAt: today, tableSize: 'nineFootPlus'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutActiveTest), findsOneWidget);
    await tester.tap(find.text(Vi.signOutAnyway));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.buTestRows).get(), isEmpty);
  });

  testWidgets('Hồ sơ hiện thẻ hạng thay cho chỗ trống cũ', (tester) async {
    await openProfile(tester);
    expect(find.text(Vi.rankNone), findsOneWidget);
    expect(find.text(Vi.rankDetermine), findsOneWidget);
    expect(find.text(Vi.profileComing), findsNothing);
  });
```

- [ ] **Step 6: Run everything touched, then the whole suite**

```bash
"$FLUTTER" test test/features test/smoke test/app_test.dart test/architecture_test.dart
"$FLUTTER" test
"$FLUTTER" analyze
```

Expected: PASS and `No issues found!`. Existing profile tests (sign-out, unsyncable notice) must stay green untouched apart from `openProfile`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/rank/presentation/rank_badge_line.dart lib/features/rank/presentation/rank_card.dart lib/features/rank/presentation/rank_screen.dart lib/features/profile/presentation/profile_screen.dart lib/features/home/presentation/home_screen.dart lib/core/router lib/core/strings/vi.dart test/features test/smoke/all_routes_test.dart
git commit -m "Show the rank with its source and disclaimer on Hồ sơ, Trang chủ and the new rank screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 17: Real Chrome — the whole flow, every layout photographed, then HOLD for the owner's eye check (spec §9, §5.5)

> **Needs:** Task 10 Step 6 done (the three collections exist on the server).

**Files:**
- Create: `tool/e2e/rank.mjs`
- Modify: `tool/e2e/throwaway_user.mjs` (`registerThrowaway` at lines 2–12)
- Modify: `docs/superpowers/logs/2026-10-14-assessment-rank.md`
- Modify only if the owner asks: `lib/domain/assessment/bu_layouts.dart`, `lib/core/strings/vi.dart`

**Interfaces:**
- Consumes: `launch`, `sleep` (`tool/e2e/cdp.mjs`); `deleteUserByEmail`; the `Vi` texts of Tasks 5, 11–16 (quoted literally below — if a `Vi` string changes, change it here too); `Routes.rankLayoutAt`.
- Produces: `node tool/e2e/rank.mjs [appUrl]` — onboarding to *ước lượng* H, Exam I with a reload in the middle of F1, *Để buổi khác*, a reload, Exam II Masters, completion to *đã kiểm chứng* D (Exam I 60 + Exam II 77 = 137), the 14-day line, the rank on a second Chrome profile, and one screenshot per layout in `%TMP%/pcai-rank`. It fails on any missing text or any console error. `registerThrowaway(tab, app, {email, password, name, keepOnboarding})`.

- [ ] **Step 1: Make `registerThrowaway` get past onboarding (D14)**

Replace the end of `registerThrowaway` (`await tab.click('Tạo tài khoản'); await tab.waitForText('Xin chào');`) with:

```js
  await tab.click('Tạo tài khoản');
  // Tài khoản mới được đưa vào bộ câu hỏi xác định hạng khi máy chủ báo chưa
  // có hạng (spec 2026-10-14 mục 7.1). "câu hỏi ngắn" chỉ có ở màn giới thiệu
  // của bộ câu hỏi, không có ở thẻ trên Trang chủ.
  await tab.waitForText('Trả lời 8 câu hỏi ngắn', 45000);
  if (keepOnboarding) return;
  await tab.click('Để sau');
  await tab.waitForText('Xin chào');
}
```

and the signature to `export async function registerThrowaway(tab, app, { email, password, name = 'Người thử E2E', keepOnboarding = false })`.

- [ ] **Step 2: Write `tool/e2e/rank.mjs`**

```js
// Đánh giá + hạng trên Chrome thật (spec 2026-10-14 mục 9): onboarding, Đề I
// có tải lại giữa bài, Đề II để buổi khác, hoàn tất, lên hạng, máy thứ hai
// thấy hạng; rồi chụp từng sơ đồ BU cho chủ sản phẩm xem.
//   node tool/e2e/rank.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-rank');
const email = `e2e-rank-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (n, msg) => console.log(`\n── Bước ${n}: ${msg}`);

async function times(tab, label, n) {
  for (let i = 0; i < n; i++) await tab.click(label);
}

// Bộ câu hỏi ra H: Q5 "Đã từng 1–2 lần" (spec mục 11.2), các câu khác lựa chọn đầu.
const TO_H = ['Chưa từng chơi', 'Dưới 2 giờ / tuần', '1', '1', 'Đã từng 1–2 lần', 'Chưa từng',
  'Thường không có bi đánh tiếp', 'Thường xuyên bị khó'];

const one = await launch({ port: 9335, name: 'rank-1' });
const two = await launch({ port: 9336, name: 'rank-2' });
try {
  step(1, 'Đăng ký: tài khoản mới vào bộ câu hỏi');
  await registerThrowaway(one, APP, { email, password, keepOnboarding: true });
  await one.shot(path.join(shots, '01-onboarding.png'));

  step(2, 'Trả lời 8 câu, xác nhận hạng gợi ý H (ước lượng)');
  await one.click('Bắt đầu');
  for (const pick of TO_H) {
    await one.click(pick);
    await one.click('Tiếp');
  }
  await one.waitForText('Hạng gợi ý cho bạn');
  await one.waitForText('HẠNG H');
  await one.shot(path.join(shots, '02-goi-y.png'));
  await one.click('Xác nhận');
  await one.waitForText('ước lượng');

  step(3, 'Hồ sơ → Làm bài kiểm tra, bàn 9 feet, bắt đầu Đề I');
  await one.goto(`${APP}/profile`);
  await one.click('Làm bài kiểm tra');
  await one.waitForText('Chuẩn bị');
  await one.click('9 feet trở lên');
  await one.click('Bắt đầu Đề I');
  await one.waitForText('F1 · Cắt góc');

  step(4, 'F1 ba cú vào, tải lại trang: vẫn ở cú 4/10, vị trí 7');
  await times(one, 'Vào', 3);
  await one.reload();
  await one.waitForText('Cú 4 / 10');
  await one.waitForText('Vị trí hiện tại: 7');
  await one.shot(path.join(shots, '03-tai-lai-giua-F1.png'));

  step(5, 'Hết Đề I: F1–F6 trọn điểm, F7 và F8 trượt hết → 60, bản Masters');
  await times(one, 'Vào', 5); // F1 đủ 8 cú vào liền: chắc 10
  for (const id of ['F2', 'F3', 'F4', 'F5']) {
    await one.waitForText(`${id} · `);
    await times(one, 'Vào', 8);
  }
  await one.waitForText('F6 · Ăn bi');
  await times(one, 'Vào', 10);
  await one.waitForText('F7 · Bánh xe');
  await times(one, 'Không đạt', 20);
  await one.waitForText('F8 · Lưới đích');
  await times(one, 'Không đạt', 20);
  await one.waitForText('Xong Đề I');
  await one.click('Chấm Đề I');
  await one.waitForText('Điểm Đề I: 60 / 100');
  await one.waitForText('Bạn làm Đề II bản Masters.');
  await one.shot(path.join(shots, '04-xep-ban.png'));

  step(6, 'Để buổi khác, tải lại, Làm tiếp → Làm Đề II ngay');
  await one.click('Để buổi khác');
  await one.waitForText('Làm tiếp');
  await one.reload();
  await one.click('Làm tiếp');
  await one.click('Làm Đề II ngay');
  await one.waitForText('S1 · Hàng bi');

  step(7, 'Đề II Masters trọn điểm (77)');
  const count = async (id, balls, layouts) => {
    await one.waitForText(`${id} · `);
    for (let k = 0; k < layouts; k++) {
      await times(one, 'Thêm một bi', balls);
      await one.click('Ghi lượt');
    }
  };
  await count('S1', 7, 1);
  await count('S2', 11, 1);
  await count('S3', 6, 3);
  await count('S4', 6, 3);
  await one.waitForText('S5 · ');
  await times(one, 'Bắt đui được', 10);
  await one.waitForText('S6 · ');
  await times(one, 'Chạm bi', 5);
  await one.waitForText('S7 · ');
  await times(one, 'Vào', 5);
  for (const id of ['S8', 'S9']) {
    await one.waitForText(`${id} · `);
    await times(one, 'Đạt', 5);
  }
  await one.waitForText('S10 · Phá');
  for (let k = 0; k < 3; k++) {
    for (const c of ['a: không chết cái', 'b: a,', 'c: a,', 'd: a,', 'e: a,']) await one.click(c);
    await one.click('Ghi lần phá');
  }

  step(8, 'Hoàn tất: 137 điểm, lên hạng H → D, đã kiểm chứng');
  await one.waitForText('Xong Đề II');
  await one.click('Hoàn tất và xem kết quả');
  await one.waitForText('Điểm BU: 137 / 200');
  await one.waitForText('Lên hạng: H → D, đã kiểm chứng.');
  await one.waitForText('Mức BU: mid advanced');
  await one.shot(path.join(shots, '05-ket-qua.png'));

  step(9, 'Hồ sơ: HẠNG D, đã kiểm chứng, ngày kiểm tra lại');
  await one.goto(`${APP}/profile`);
  await one.waitForText('HẠNG D');
  await one.waitForText('đã kiểm chứng');
  await one.waitForText('Lần kế tiếp làm được từ ngày');
  await one.shot(path.join(shots, '06-ho-so.png'));

  step(10, 'Máy thứ hai đăng nhập: thấy HẠNG D, không bị đưa vào bộ câu hỏi');
  await two.goto(APP);
  await two.type('Email', email);
  await two.type('Mật khẩu', password);
  await two.click('Đăng nhập');
  await two.waitForText('Xin chào');
  await two.waitForText('HẠNG D', 45000);
  const twoText = await two.text();
  if (twoText.includes('Trả lời 8 câu hỏi ngắn')) throw new Error('Máy thứ hai bị đưa vào bộ câu hỏi');
  await two.shot(path.join(shots, '07-may-2.png'));

  step(11, 'Chụp từng sơ đồ BU');
  for (let i = 0; ; i++) {
    await one.goto(`${APP}/rank/layouts?i=${i}`);
    const text = await one.text();
    if (text.includes('Hết sơ đồ.')) break;
    const caption = text.split('\n').find((l) => l.startsWith('Sơ đồ ')) ?? `#${i}`;
    console.log(`   ${caption}`);
    await one.shot(path.join(shots, `so-do-${String(i + 1).padStart(3, '0')}.png`));
  }

  const errors = [...one.errors, ...two.errors].filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await one.close();
  await two.close();
  await deleteUserByEmail(email);
}
```

Check the syntax: `node --check tool/e2e/rank.mjs`. Expected: no output.

- [ ] **Step 3: Build, serve locally, run everything**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
eval "$(node -e "const e=require('C:/Users/anhnpv/Desktop/PoolCoachAI/.claude/settings.local.json').env;for(const k of ['DIRECTUS_URL','DIRECTUS_ADMIN_EMAIL','DIRECTUS_ADMIN_PASSWORD','MAILPIT_URL','MAILPIT_USER','MAILPIT_PASSWORD'])if(e[k])console.log('export '+k+'='+JSON.stringify(e[k]))")"
node tool/e2e/rank.mjs http://localhost:5555
node tool/e2e/accounts.mjs http://localhost:5555
node tool/e2e/simulator.mjs http://localhost:5555
node tool/e2e/planner.mjs http://localhost:5555
```

Expected: `rank.mjs` prints all 11 steps, one `Sơ đồ k / n · …` line per layout, and `Xong.`; the three older scripts pass as before (they now press *Để sau* inside `registerThrowaway`). A build that succeeds is not proof — only these runs are. If a step fails, fix the app (not the script's expectations) unless the script quotes a string wrongly.

- [ ] **Step 4: HOLD — the owner's eye check. STOP here.**

Show the owner:
- every `so-do-*.png` beside the PDF page named in its caption source line;
- `01`–`07` screenshots;
- the set-up texts of Task 11 (`Vi.buDrillSetup`), which are the plan's translation of BU's text (D13);
- the open owner decisions if still unanswered: D4 (merge between two verified rows) and D5 (Masters can reach C, and A on a small table).

Ask, specifically:
1. *"Từng sơ đồ có khớp hình trong PDF BU không? Bi nào lệch chấm, thiếu vòng giấy, khung đích hay vị trí thang?"*
2. *"Cách xếp bài tiếng Việt có đúng thuật ngữ và dễ làm theo không?"*
3. *"Các câu kết quả (lên hạng, giữ hạng, cảnh báo) và nhãn nguồn có ổn không?"*

Change nothing until the owner answers.

- [ ] **Step 5: Apply the owner's corrections and repeat**

Correct only the coordinates or texts the owner names (keep the PDF citation; a new coordinate needs the page it came from). Re-run `"$FLUTTER" test test/domain/assessment test/core/strings test/features/rank`, rebuild, re-run Step 3, show the new screenshots. Repeat until the owner approves every layout.

- [ ] **Step 6: Log and commit**

Append to the log:

```markdown
## Chrome (<date>)

- rank.mjs: <paste the step lines and the layout count>.
- accounts.mjs / simulator.mjs / planner.mjs: <pass / fail lines>.

## Owner's eye check

<the owner's verdict on the layouts, the texts and the result lines, verbatim>

## Corrections

<each corrected layout or text: drill, version, variant, old → new, page; or "none">

## Owner decisions

- D4: <answer>. D5: <answer>.
```

```bash
git add tool/e2e/rank.mjs tool/e2e/throwaway_user.mjs docs/superpowers/logs/2026-10-14-assessment-rank.md lib/domain/assessment/bu_layouts.dart lib/core/strings/vi.dart
git commit -m "Check the rank flow in real Chrome, photograph every BU layout, and log the owner's eye check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If corrections changed layouts or texts, list each change in the commit body.

---

### Task 18: Full verification, the PRD, and the whole-branch review

**Files:**
- Modify: `PRD_PoolCoachAI.md` (§4 at lines 57–59)
- Modify: `docs/superpowers/logs/2026-10-14-assessment-rank.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a green branch, the PRD describing what shipped, and a reviewed hand-off.

- [ ] **Step 1: Run everything**

```bash
"$FLUTTER" test
"$FLUTTER" analyze
git status --short
```

Expected: all tests pass (write the count next to the Task 0 baseline in the log); `No issues found!`; a clean tree.

- [ ] **Step 2: Bring the PRD up to date**

Replace PRD §4 (the heading `## 4. Onboarding & Skill Assessment` and its one paragraph, lines 57–59) with:

```markdown
## 4. Onboarding & Skill Assessment

*(Đã xây — spec `docs/superpowers/specs/2026-10-14-poolcoachai-assessment-rank-design.md`.)*

- Sau lần đăng nhập đầu tiên, tài khoản chưa có hạng được đưa tới **8 câu hỏi** (nguyên văn PoolOS v2). Chỉ Q4, Q5, Q6 tính hạng gợi ý, theo bảng quy đổi neo vào mô tả Fargo của Dr. Dave. Người chơi **Xác nhận** (hạng *ước lượng*) hoặc **Chọn hạng khác** (hạng *tự khai*, kể cả PRO). Màn nào cũng có **Để sau**. Máy mới chưa lấy được hạng từ máy chủ thì không bị ép vào bộ câu hỏi.
- **Bài kiểm tra Billiard University** (Đề I + Đề II, thang 200, cộng điểm thô theo phiếu điểm BU) cho hạng *đã kiểm chứng*. Điểm BU quy đổi sang K…A bằng cách gộp các mức của `BU_Rating_Comparisons.pdf`; BU không bao giờ cho PRO. Hai lần hoàn tất cách nhau tối thiểu 14 ngày; lần bị hủy không tính.
- App **không bao giờ tự hạ hạng**: kết quả thấp hơn chỉ đặt cảnh báo. Dữ liệu luyện tập không đổi hạng.
- Mỗi cú ghi xuống máy ngay khi nhập; hạng, câu trả lời và các lần kiểm tra đã xong đồng bộ theo tài khoản. Mọi màn hiện hạng kèm nhãn nguồn, câu miễn trừ và bảng quy đổi.
```

(The old sentence "trình độ thực tế được điều chỉnh liên tục từ dữ liệu Training và Play" contradicts Q5 and Q15 and goes.) Commit:

```bash
git add PRD_PoolCoachAI.md docs/superpowers/logs/2026-10-14-assessment-rank.md
git commit -m "Describe the shipped questionnaire, BU tests and rank rules in the PRD

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3: Whole-branch review**

Use superpowers:requesting-code-review on `main...feat/assessment-rank`, with the spec, this plan and the log as context. Ask the reviewer to check at least:
- every Review Focus item and its pinning tests;
- the six rank rules, and that no code path lowers a rank;
- `mergeRank` (D4 as the owner decided, D16) and that `AssessmentSyncService` never PATCHes a verified row with an unverified one;
- every scoring function against the cited score-sheet lines;
- no coordinate without a PDF page; no BU PDF in the repo (`git log --all --stat -- '*.pdf'` prints nothing);
- every visible string in `Vi`, the owner's terms exactly, no "kim cương", "bi ma", "lọt bi cái";
- the disclaimer and ⓘ on every screen that shows a rank;
- `lib/domain/assessment` free of Flutter.

Fix findings with superpowers:receiving-code-review, then re-run Step 1.

- [ ] **Step 4: Hand off to the owner**

Use superpowers:finishing-a-development-branch. Merging and deploying are **the owner's decision**. Do not push or merge without it. There is no `gh`: if the owner wants a pull request, push the branch and give them the `pull/new/feat/assessment-rank` URL.

### After the owner approves the merge

Same sequence as earlier features (memory: poolcoachai-deploy). Do not deploy from the branch.
1. From a clean `main`, run `FLUTTER=… DART=… bash deploy/publish.sh`.
2. Call the easypanel MCP `deployAppService` {projectName: test-va, serviceName: poolcoachai} through `execute_destructive`.
3. Confirm `inspectAppService` → `commit.hash` equals the new `deploy-easypanel` head.
4. Run `node tool/e2e/rank.mjs` against the live URL, then `accounts.mjs`, `simulator.mjs` and `planner.mjs`. All must pass with no console errors.

---

## Self-review (applied)

**Spec coverage.**

| Spec | Task |
|---|---|
| §1 goals, §3 Q1–Q15 | Q2/Q3/Q5 → 1; Q4/Q10/Q13 → 5, 13; Q6/Q9/Q11 → 2–4; Q7 → 8–10; Q8 → 11–12, 17; Q12 → 6, 8, 14, 15; Q14 → module layout; Q15 → 1 (`warned`), 16 |
| §2 code state | Global Constraints, File Structure (verified against `01ecd96`) |
| §4.1 record | 1 (`PlayerRank`), 7 (table), D7 |
| §4.2 six rules | 1 |
| §4.3 display | 13 (disclaimer on suggestion), 15 (result), 16 (badge line, ⓘ sheet) |
| §5.1, §5.2 drills, special rules | 4 (definitions), 11 (scoring lines, PDF re-check, S9 / S3 Doctorate / S4 / S9 Doctorate) |
| §5.3 five kinds | 3 |
| §5.4 placement, raw sum, table, consequences | 2, D1, D5 |
| §5.5 layouts | 11, 12, 17 |
| §5.6 domain tests | 1, 2, 3, 4, 5, 6 |
| §6.1 Drift | 7, 8 |
| §6.2 Directus, merge | 9, 10, D4, D9, D10, D16 |
| §7.1 routes, redirect | 12 (`/rank/layouts`), 13 (`/onboarding/rank`, redirect), 14 (`/rank/test`), 16 (`/rank`) |
| §7.2 onboarding | 13 |
| §7.3 test flow | 14, 15 |
| §7.4 profile and home | 16 |
| §8 errors | 8 (Drift first), 9 (fetch failure), 13 (no forced onboarding), 4/14 (inputs blocked), 8/14 (undo) |
| §9 tests | every task; Chrome in 17 |
| §10 out of scope | nothing built for it; PRD §4 says nothing about Lộ trình |
| §11 owner inputs | 5 (descriptions, questions, table), 4 (names) |

No spec section is left without a task.

**Placeholder scan.** Two places are deliberately data-entry, not code-to-be-designed: `_transcribed` / `_constructed()` in Task 11 and the arms of `Vi.buDrillSetup`. Both have the procedure, the data shape, a fully worked example (the spec's S3 Bachelors layout 1), and a failing test that lists exactly what is missing; the plan forbids inventing their content. Everything else is complete code.

**Type and name consistency** (checked across tasks): `RankFetch { pending, foundNone, found, failed }`; `TestSnapshot.examIIStarted`; `StartOutcome` = `TestStarted` | `TestAlreadyActive` | `RetestTooSoon`; `CompleteOutcome` = `TestCompleted` | `CompletionTooSoon`; `layoutForAttempt(BuDrill, ExamIIVersion?, int)`; `Vi.buAttemptLabel(BuDrill, int)`; `Routes.onboardingRank`, `rank`, `rankTest`, `rankLayouts`; `dbContainer` / `testContainer` overrides; `examIAttempts({required bool wagonAndTargetMade})`, `examIIPerfect(ExamIIVersion)`.

**Review Focus pins.** Each of the five lines names tests that exist in the task it cites (Tasks 6, 8, 9, 13, 14, 15, 16, 17).
