# Phân tích trận vào Intelligence, Coach và Lộ trình Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn recorded match shots into sourced conclusions ("why did I lose that match"), then feed them into Statistics, today's pick, Player Intelligence, Coach, chat facts and Lộ trình (tournament prep, multi-rank goals, rank re-check hint).

**Architecture:** A new pure-Dart module `lib/domain/match_analysis/` turns `PoolMatch` shots into counts, sample sizes and `SkillSignal`s (no Flutter, no `Vi`, no Vietnamese literals). Every consumer (Play sheet, Stats card, `computePlayerIntelligence`, `pickCategoryForToday`, `computeCoachRecommendation`, `CoachContext.toFacts`, `buildRoadmap`, `rankCheckSignal`) calls that module; all wording lives in `vi.dart` as parameterised templates. One schema bump (Drift v14 + Directus `player_goals.target_rank`) carries the multi-rank goal.

**Tech Stack:** Flutter 3.47, Dart, Riverpod 3 (no codegen), Drift (SQLite, `NativeDatabase.memory` in tests), Directus sync, Node 24 `server/coach-chat` (`node --test`).

**Spec:** `docs/superpowers/specs/2026-10-28-poolcoachai-match-analysis-design.md`

## Global Constraints

- Work only in the worktree `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\match-analysis` (branch `feat/match-analysis`). Bash cwd resets between calls: start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/match-analysis && `.
- Prefix every flutter / dart / npm command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN` (the shell exports live secrets). Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat`, Dart is `/c/Users/anhnpv/flutter/bin/dart.bat` (not on PATH). Every command below is written out in full.
- `lib/data/database/database.g.dart` is gitignored. Regenerate with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs` once before the first test and after every edit to `database.dart`.
- Coach-chat service tests: `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm ci` once, then `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test`.
- README rule 1 (no fabrication): every conclusion comes from a named, tested pure Dart function; wording is a parameterised template in `lib/core/strings/vi.dart`; missing data is stated as missing. README rule 2: the LLM only interprets precomputed facts.
- `lib/domain/match_analysis/` imports neither `package:flutter` nor `core/strings/vi.dart` and holds no Vietnamese string literal (comments may be Vietnamese). Output is enums, counts and sample sizes only.
- No Vietnamese literal in `lib/features/**` or `lib/core/widgets/**` (architecture test). All new UI copy goes into `Vi`.
- Executable advice only: no degrees, no "ngắm lệch". Match analysis states rates, counts, skill groups and a drill to practise.
- Rank changes only through a BU test (rank spec Q15). `RankCheckSignal` never writes `PlayerRank` and never sets `warningRank`.
- Spec values, verbatim: recent window `MatchAnalysisConstants.recentMatches = 10`; weakness needs ≥ 3 matches and ≥ 10 attempts; single match needs ≥ 5 attempts and shows at most 2 groups; fail thresholds Phá ≥ 50%, Tấn công (aiming) ≥ 35%, Điều bi ≥ 40%, Phòng thủ ≥ 50%; BU-weak when `buPercent < 55` (`PracticeConstants.weakCutoff`); Đấu tập window 28 days, need 3 matches; rank re-check needs BU ≥ 28 days old; Drift `schemaVersion` 14.
- Owner vocabulary, exactly: Phá (break), Điều bi (position), Chết cái (scratch), Phòng thủ (safety), A băng (kick), Cân bi (bank), Đánh trô / Đánh cu lê / Đánh đứng bi, Bị đui, phá-và-dọn (break-and-run), dọn bàn (run-out), phá khô (dry break). Never "Scratch", "đi bi", "giao bóng".
- Chat facts: keys are only added; no existing key renamed or removed. `server/coach-chat/src/prompt.mjs` must describe every key and enum value the facts can carry (`test/domain/coach/coach_chat_prompt_test.dart` enforces it), so any task adding an enum value that reaches facts updates the prompt in the same task.
- Riverpod: no codegen; never `.invalidate(` / `.refresh(` in `lib/`; a provider combining sources treats a source as ready only when `hasValue && !isLoading`.
- Test gotchas: (1) reading a provider `.future` in a test can hang silently — `container.listen(p, (_, _) {})`, `await pumpEventQueue()`, then `container.read(p)`; (2) never write an explicit type on an override list (`<Override>[…]` crashes the compiler) — leave the list literal untyped; (3) inside `testWidgets`, `await repo.watchX().first` hangs — read rows with `db.select(db.table).get()`; (4) Drift `AppDatabase.forTesting(NativeDatabase.memory())` works inside `flutter test`. Stale "reloading with old value" states are built with `const AsyncLoading<T>().copyWithPrevious(AsyncData<T>(…))` plus `// ignore: invalid_use_of_internal_member` (see `test/core/providers/coach_chat_providers_test.dart:80-105`).
- App must keep running on Android + iOS + web: no web-only code.
- One commit per task, Vietnamese subject, ending with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No push, no PR, no deploy, no Directus/prod call, no APK build.
- A full-suite `flutter test` takes minutes: run it in the background and stream step and test counts every minute with Monitor; never a silent wait.

## Review Focus

1. **A rack recorded only partway** (break logged, then "Tôi thắng ván" tapped; or shots stop after a miss) — must not count as phá-và-dọn, dọn bàn or a named lost-rack cause; it is "có ghi cú" but not "ghi đủ". Tests: Task 1.
2. **Matches with no shots, or zero attempts in a group** — every rate is "not shown", never `0%`, `NaN` or `null` on screen; the Play sheet shows only score + the no-shots sentence. Tests: Tasks 2, 3, 4.
3. **In-progress matches and more than 10 completed matches** — open matches never feed analysis, pick, facts or roadmap; the window is the 10 most recent by `completedAt ?? startedAt`. Tests: Task 2.
4. **Account switch while matches reload** — `matchesProvider` holding the previous account's list with `isLoading == true` must keep Player Intelligence, today's pick and the rank re-check hint in their loading state. Tests: Tasks 5, 6, 12.
5. **A target-rank goal the player has already reached or passed** (promoted by BU, or rank re-chosen) — roadmap falls back to the next rank, never shows negative points or an empty step list. Tests: Task 11.

## Plan's calls

Where the spec is silent or does not match the code, the plan decided; each is marked ★ in its task.

1. "Ván ghi đủ" also needs ≥ 2 shots and a closing shot (winner's `made`, or loser's `foul`/`scratch`), so a rack logged only partway is not "full" (a one-shot golden break is therefore not counted).
2. Dọn bàn (`runOut`) requires the opponent to have shot in the rack, so a phá-và-dọn is not counted twice.
3. A turnover right after a `made` shot gets cause `unknown`.
4. `lostRackCause` = cause of the player's last shot in the rack (covers losing on one's own foul/chết cái at the end).
5. Aiming attempts are normal `made`+`missed` (normal fouls count nowhere); position attempts are any player shot with `positionOutcome` plus normal chết cái, counted once.
6. A safety is assessed only when the next shot in the same rack is the opponent's.
7. "Mất lượt chủ động" = turnovers caused by a safety or an offensive miss.
8. Position follow-up looks only at the player's own next shot (`n+1`, normal); a miss is `missed`.
9. "≥ 3 trận" counts the matches that contributed ≥ 1 attempt to that group.
10. Single-match "Nên luyện" also requires the group threshold; sorted by failure rate as the spec says.
11. Spec's `declining`/`improving` are the code's `SkillTrend.down`/`SkillTrend.up`.
12. `BuResult` gains a `max` map (Exam II max depends on version) so `buPercent` can be computed; BU-only weak groups follow drill-weak groups, ascending `buPercent`; `PlayerIntelligence.weakSources` records the source.
13. `computePlayerIntelligence` and `computeRecommendation` also take `latestBu`; both providers watch `latestBuResultProvider` so Home, Coach and PI agree.
14. `TodayRecommendation.matchSignal` carries the rate and sample; `Vi.pickReason` gets an optional `signal` (sentence without numbers when absent).
15. Coach order: today's topic first (reason `matchWeakness` when today's reason is), then the first match-weak topic, then weakest, lowest.
16. `chat_filter.dart` is unchanged: facts carry the integer percents, which the existing "number must be in facts" rule already allows; tests prove it.
17. `StepReason.matchWeakness(category, …)` becomes `MatchWeakness(failures, attempts)` (category is on the step); those steps never start as done.
18. Đấu tập counts completed matches **with recorded shots** in 28 days; the step disappears once enough; title uses `need − have`; its tile button opens Thi đấu.
19. Choosing the next rank stores `targetRank = null` (keeps auto-advance); a target already reached falls back to the next rank.
20. Without a BU result, rank milestones sit after the group steps, before the final BU step (needed for the spec's E2E, whose user has no BU).
21. Milestone steps are `lamBaiBu` with reason `RankMilestone(rank)`.
22. "Nhóm BU từng chấm" = keys of `buPercent`; the upward hint names the next rank; a match-based downward hint has its own sentence; the hint shows on Home even without a goal.
23. Existing `'Scratch'` labels become `'Chết cái'`; the placeholder `statsMatchAnalysisNotAvailable` card is removed.
24. Existing tournament tests are updated for the new leading Đấu tập step.

---

### Task 1: Rack analysis core

**Files:**
- Create: `lib/domain/match_analysis/match_analysis_constants.dart`
- Create: `lib/domain/match_analysis/rack_analysis.dart`
- Create: `test/support/match_fixtures.dart`
- Create: `test/domain/match_analysis/rack_analysis_test.dart`
- Modify: `test/architecture_test.dart` (append one test)

**Interfaces:**
- Produces:
  - `abstract final class MatchAnalysisConstants { static const recentMatches = 10; static const minMatches = 3; static const minAttempts = 10; static const singleMatchMinAttempts = 5; static const singleMatchFocusMax = 2; static const matchWindowDays = 28; static const tournamentMinMatches = 3; static const rankCheckMinDays = 28; static const failPercentFrom = <SkillCategory, int>{SkillCategory.breakShot: 50, SkillCategory.aiming: 35, SkillCategory.position: 40, SkillCategory.safety: 50}; }`
  - `enum TurnoverCause { offensiveMiss, safety, foul, scratch, dryBreak, unknown }`
  - `enum LostRackCause { offensiveMiss, safety, foul, scratch, dryBreak, opponentBreakAndRun, unknown }`
  - `TurnoverCause turnoverCauseOf(MatchShot shot)`
  - `final class RackAnalysis { int rackNumber; RackWinner winner; List<MatchShot> shots /* by shotNumber */; bool hasShots; bool isFull; RackWinner? breaker; MatchShotOutcome? breakResult; bool breakAndRun; bool runOut; List<TurnoverCause> turnovers; LostRackCause? lostRackCause /* null when the player won */; }`
  - `RackAnalysis analyzeRack(PoolMatch match, int rackIndex)` — rack `rackIndex + 1`, winner `match.rackWinners[rackIndex]`.
  - Fixtures: `MatchShot shotAt(int rack, int n, RackWinner who, MatchShotType type, MatchShotOutcome outcome, {PositionOutcome? position})`; `PoolMatch completedMatch(String id, List<RackWinner> racks, List<MatchShot> shots, {DateTime? at})` (target = max of the two scores, `completedAt = at ?? DateTime(2026, 10, 1, 20)`); `List<PoolMatch> matchesWeakAt(SkillCategory weak, {int count = 3, required DateTime at})` (supports `aiming` and `position`, `ArgumentError` otherwise).

Rules `analyzeRack` implements (spec §3, §4.1, with the plan's calls marked ★):
- `breaker`: shooter of the lowest-numbered shot when its type is `breakShot`, else `null`. `breakResult`: that shot's outcome.
- `isFull`: first shot is `breakShot` with `shotNumber == 1`, numbers are `1..n` without gaps, ★ `n >= 2`, and ★ the last shot is the rack winner's with outcome `made`, or the loser's with outcome `foul`/`scratch`.
- `turnoverCauseOf`: `foul`→foul, `scratch`→scratch, `breakShot`+`missed`→dryBreak, type `safety`→safety, `normal`+`missed`→offensiveMiss, ★ any `made`→unknown.
- `turnovers` (full racks only, else empty): for each adjacent pair where shot *i* is the player's and shot *i+1* the opponent's, `turnoverCauseOf(shot i)`.
- `breakAndRun`: full, `breaker != null`, winner == breaker, the other side has no shot.
- `runOut`: winner is the player, full, ★ the opponent has ≥ 1 shot (so break-and-run is not also a run-out), last shot is the player's.
- `lostRackCause` (only when the opponent won): not full → `unknown`; full and the player has no shot → `opponentBreakAndRun`; else ★ the cause of the player's last shot in the rack (mapped by name from `TurnoverCause`).

- [ ] **Step 1: Setup** — `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat pub get`, then `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs`, then `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm ci`. Expected: all exit 0.

- [ ] **Step 2: Write the failing tests** in `test/domain/match_analysis/rack_analysis_test.dart` (`p`/`o` = player/opponent, `B`/`N`/`S` = break/normal/safety):

```dart
test('phá-và-dọn: người phá thắng, đối thủ không có cú nào', () {
  final r = analyzeRack(completedMatch('m', [p], [shotAt(1,1,p,B,made), shotAt(1,2,p,N,made), shotAt(1,3,p,N,made)]), 0);
  expect([r.isFull, r.breaker, r.breakAndRun, r.runOut, r.turnovers], [true, p, true, false, isEmpty]);
});
test('dọn bàn: thắng bằng một lượt sau cú cuối của đối thủ', () {
  final r = analyzeRack(completedMatch('m', [p], [shotAt(1,1,o,B,made), shotAt(1,2,o,N,missed), shotAt(1,3,p,N,made), shotAt(1,4,p,N,made)]), 0);
  expect([r.runOut, r.breakAndRun, r.breaker, r.lostRackCause], [true, false, o, null]);
});
test('mất lượt có nguyên nhân; thua ván lấy nguyên nhân cú cuối của người chơi', () {
  final r = analyzeRack(completedMatch('m', [o], [shotAt(1,1,p,B,missed), shotAt(1,2,o,N,missed), shotAt(1,3,p,N,missed), shotAt(1,4,o,N,made), shotAt(1,5,o,N,made)]), 0);
  expect(r.turnovers, [TurnoverCause.dryBreak, TurnoverCause.offensiveMiss]);
  expect(r.lostRackCause, LostRackCause.offensiveMiss);
});
test('đối thủ phá-và-dọn', () {
  final r = analyzeRack(completedMatch('m', [o], [shotAt(1,1,o,B,made), shotAt(1,2,o,N,made)]), 0);
  expect(r.lostRackCause, LostRackCause.opponentBreakAndRun);
});
test('thua vì chết cái ở cú cuối của chính mình', () {
  final r = analyzeRack(completedMatch('m', [o], [shotAt(1,1,p,B,made), shotAt(1,2,p,N,scratch)]), 0);
  expect([r.isFull, r.lostRackCause, r.turnovers], [true, LostRackCause.scratch, isEmpty]);
});
test('turnoverCauseOf theo bảng', () {
  expect(turnoverCauseOf(shotAt(1,1,p,N,foul)), TurnoverCause.foul);
  expect(turnoverCauseOf(shotAt(1,1,p,S,missed)), TurnoverCause.safety);
  expect(turnoverCauseOf(shotAt(1,1,p,N,made)), TurnoverCause.unknown);
});
// Review Focus 1
test('chỉ ghi cú phá rồi bấm thắng ván: có ghi cú, không ghi đủ, không kết luận', () {
  final r = analyzeRack(completedMatch('m', [p], [shotAt(1,1,p,B,made)]), 0);
  expect([r.hasShots, r.isFull, r.breakAndRun, r.runOut], [true, false, false, false]);
});
test('ngừng ghi sau một cú trượt: không ghi đủ, thua ván là unknown', () {
  final r = analyzeRack(completedMatch('m', [o], [shotAt(1,1,p,B,made), shotAt(1,2,p,N,missed)]), 0);
  expect([r.isFull, r.lostRackCause, r.turnovers], [false, LostRackCause.unknown, isEmpty]);
});
test('thiếu số cú giữa ván thì không ghi đủ', () {
  final r = analyzeRack(completedMatch('m', [p], [shotAt(1,1,p,B,made), shotAt(1,3,p,N,made)]), 0);
  expect(r.isFull, isFalse);
});
test('ván không có cú: không có người phá, thua là unknown', () {
  final r = analyzeRack(completedMatch('m', [o], const []), 0);
  expect([r.hasShots, r.breaker, r.lostRackCause], [false, null, LostRackCause.unknown]);
});
```

Append to `test/architecture_test.dart`, next to the other "lõi … không phụ thuộc Flutter" tests: `'lõi phân tích trận không phụ thuộc Flutter, không dùng Vi, không có chuỗi tiếng Việt'` — over `dartFilesIn('lib/domain/match_analysis')` (expect non-empty), `codeOnly(source)` must not contain `package:flutter` nor `core/strings/vi.dart`, and must not match the existing Vietnamese-literal regex used by `'không màn hình nào chứa chuỗi tiếng Việt viết thẳng'` (hoist that `RegExp` to a top-level `final` and reuse it).

- [ ] **Step 3: Run tests to verify they fail**

Run: `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/match_analysis/rack_analysis_test.dart test/architecture_test.dart`
Expected: FAIL — `rack_analysis.dart` not found; the new architecture test fails on an empty directory.

- [ ] **Step 4: Implement** the constants file, `rack_analysis.dart` and `test/support/match_fixtures.dart` with the interfaces above. `matchesWeakAt(aiming)`: each match has only full racks with ≥ 5 player `normal` shots, ≥ 50% `missed`, every `positionOutcome` `successful`; `matchesWeakAt(position)`: ≥ 5 player shots with `positionOutcome`, ≥ 60% `unsuccessful`, no `missed` normal shot. Both: matches dated `at` minus 0, 1, 2 … days; no breaks or safeties that would cross their thresholds.

- [ ] **Step 5: Run tests to verify they pass**

Run: `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/match_analysis/rack_analysis_test.dart test/architecture_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/domain/match_analysis test/support/match_fixtures.dart test/domain/match_analysis test/architecture_test.dart
git commit -m "Phân tích trận: phân tích một ván (ghi đủ, phá-và-dọn, dọn bàn, nguyên nhân mất lượt)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Shot → skill map and multi-match analysis

**Files:**
- Create: `lib/domain/match_analysis/shot_skill_map.dart`
- Create: `lib/domain/match_analysis/match_analysis.dart`
- Create: `test/domain/match_analysis/shot_skill_map_test.dart`
- Create: `test/domain/match_analysis/match_analysis_test.dart`

**Interfaces:**
- Consumes: Task 1 (`analyzeRack`, `RackAnalysis`, `LostRackCause`, `MatchAnalysisConstants`, fixtures).
- Produces:
  - `typedef SkillAttempt = ({SkillCategory category, bool failed});`
  - `List<SkillAttempt> shotSkillMap(PoolMatch match)`
  - `final class SkillSignal { const SkillSignal({required this.category, required this.failures, required this.attempts, required this.matches}); final SkillCategory category; final int failures; final int attempts; final int matches; }` (`matches` = ★ matches with ≥ 1 attempt in that group)
  - `final class BreakStats { int shots; int made; int dry; int fouls; int scratches; int racksBroken /* full racks this side broke */; int breakAndRuns; }`
  - `final class MatchAnalysis { int matches; int racksWon; int racksLost; int racksWithShots; int fullRacks; BreakStats playerBreak; BreakStats opponentBreak; int runOuts; int normalShots; int missedNormal; int assessedPositions; int failedPositions; int nextAfterFailedPosition; int missAfterFailedPosition; int nextAfterGoodPosition; int missAfterGoodPosition; int safeties; int assessedSafeties; int successfulSafeties; int safetyTurnovers; int proactiveTurnovers; int playerShots; int fouls; int scratches; Map<LostRackCause, int> lostRackCauses /* every value present */; Map<SkillCategory, SkillSignal> signals /* the 4 mapped groups */; List<SkillSignal> weaknesses; }`
  - `List<PoolMatch> recentCompletedMatches(List<PoolMatch> matches, {int limit = MatchAnalysisConstants.recentMatches})` — `isComplete` only, sorted by `completedAt ?? startedAt` desc, ties by `id` asc (same order as `matchFactsOf`).
  - `MatchAnalysis analyzeMatches(List<PoolMatch> matches, {int limit = MatchAnalysisConstants.recentMatches})` — runs on `recentCompletedMatches(matches, limit: limit)`.
  - `List<SkillSignal> matchWeaknesses(Iterable<SkillSignal> signals, {required int minMatches, required int minAttempts})` — keeps `matches >= minMatches && attempts >= minAttempts && failures * 100 >= failPercentFrom[c]! * attempts`; sorted by excess `failures/attempts − threshold/100` desc, ties by `SkillCategory.index`.
  - `typedef MatchFocus = ({SkillSignal signal, Drill? drill});`
  - `List<MatchFocus> singleMatchFocus(MatchAnalysis analysis, {required List<Drill> drills, required List<DrillLog> logs})` — `matchWeaknesses(minMatches: 1, minAttempts: singleMatchMinAttempts)` re-sorted by failure rate desc, first `singleMatchFocusMax`; drill = `pickDrillInCategory(cat:, drills:, logsByDrillOldestFirst: <logs grouped by drillId, oldest first>, excludeDrillIds: const {})`.
  - `int? percentOf(int part, int whole)` — `null` when `whole == 0`, else `(part * 100 / whole).round()`.

Mapping (spec §4.3, with ★ plan's calls), player shots in racks that have a winner:
- `breakShot` → `(breakShot, failed: outcome != made)`.
- `normal`: `scratch` → `(position, true)`; `missed` → `(aiming, true)`; `made` → `(aiming, false)`; ★ `foul` → nothing.
- ★ any shot with `positionOutcome != null` and outcome != `scratch` → `(position, failed: unsuccessful)`.
- `safety` → ★ only when shot `n+1` of the same rack exists and is the opponent's: `(safety, failed: next.outcome == made)`.

Aggregates: `normalShots` = player normal `made`+`missed`; `missedNormal` = player normal `missed`. `nextAfter…Position`: ★ the player's own shot `n+1` in the same rack, type `normal`; miss = `missed`. `successfulSafeties`: assessed safeties whose next opponent shot is `missed`/`foul`/`scratch`. `safetyTurnovers` = turnovers with cause `safety`; ★ `proactiveTurnovers` = turnovers with cause `safety` or `offensiveMiss`. `fouls`/`scratches`/`playerShots` over all player shots. `lostRackCauses` over racks the player lost. `weaknesses = matchWeaknesses(signals.values, minMatches: 3, minAttempts: 10)`.

- [ ] **Step 1: Write the failing tests**

`shot_skill_map_test.dart` — one test per mapping row above, e.g.:

```dart
test('cú thường phạm lỗi không quy về nhóm nào', () {
  expect(shotSkillMap(completedMatch('m', [p], [shotAt(1,1,p,B,made), shotAt(1,2,p,N,foul), shotAt(1,3,p,N,made)]))
      .where((a) => a.category == SkillCategory.aiming).length, 1);
});
test('phòng thủ thất bại khi cú kế tiếp của đối thủ vào bi', () {
  final m = completedMatch('m', [o], [shotAt(1,1,p,B,made), shotAt(1,2,p,S,missed), shotAt(1,3,o,N,made)]);
  expect(shotSkillMap(m), contains((category: SkillCategory.safety, failed: true)));
});
test('phòng thủ là cú cuối ván thì không chấm', () { /* no safety attempt */ });
test('chết cái ở cú thường tính một lần cho Điều bi', () { /* scratch + unsuccessful → exactly one position attempt */ });
test('cú của đối thủ không vào nhóm nào', () { /* only opponent shots → isEmpty */ });
```

`match_analysis_test.dart`:

```dart
test('9 lần thử thì không kết luận, 10 thì có', () {
  SkillSignal s(int attempts) => SkillSignal(category: SkillCategory.aiming, failures: attempts, attempts: attempts, matches: 3);
  expect(matchWeaknesses([s(9)], minMatches: 3, minAttempts: 10), isEmpty);
  expect(matchWeaknesses([s(10)], minMatches: 3, minAttempts: 10).single.category, SkillCategory.aiming);
});
test('đủ 10 lần thử nhưng chỉ 2 trận thì không kết luận', () { /* matches: 2 → isEmpty */ });
test('đúng ngưỡng 35% vẫn là yếu', () { /* aiming 7/20 → weak; 6/20 → not */ });
test('nhóm vượt ngưỡng nhiều nhất đứng đầu', () { /* position 9/10 (+50) before aiming 8/10 (+45) */ });
test('đổi dữ liệu: yếu Ngắm bi rồi yếu Điều bi', () {
  expect(analyzeMatches(matchesWeakAt(SkillCategory.aiming, at: DateTime(2026, 10, 20))).weaknesses.first.category, SkillCategory.aiming);
  expect(analyzeMatches(matchesWeakAt(SkillCategory.position, at: DateTime(2026, 10, 20))).weaknesses.first.category, SkillCategory.position);
});
// Review Focus 3
test('trận đang đánh không tính; chỉ 10 trận hoàn tất gần nhất', () {
  // 12 completed (completedAt 1..12 Oct) + 1 open → analysis.matches == 10, and the two oldest are not counted
});
// Review Focus 2
test('trận không có cú: mọi số đếm 0, không nhóm yếu, percentOf null', () {
  final a = analyzeMatches([completedMatch('m', [p, o, p], const [])]);
  expect([a.matches, a.racksWon, a.racksLost, a.racksWithShots, a.fullRacks, a.playerShots], [1, 2, 1, 0, 0, 0]);
  expect(a.lostRackCauses[LostRackCause.unknown], 1);
  expect(a.weaknesses, isEmpty);
  expect(percentOf(a.missedNormal, a.normalShots), isNull);
});
test('phá: đếm của người chơi và đối thủ tách riêng; phá-và-dọn trên số ván đã phá', () { /* exact BreakStats */ });
test('điều bi hỏng làm trượt cú kế tiếp: đếm sau hỏng và sau tốt', () { /* exact four counts */ });
test('phòng thủ thành công và tỷ lệ trên mất lượt chủ động', () { /* exact counts */ });
test('một trận: 5 lần thử là đủ, 4 thì không; tối đa 2 nhóm; kèm bài tập', () {
  // drills = roadmapDrills (test/support/roadmap_fixtures.dart); expect focus drill ids 'p1' / 'a1'
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/match_analysis`
Expected: FAIL — `shot_skill_map.dart` / `match_analysis.dart` not found.

- [ ] **Step 3: Implement** both files with the interfaces above.

- [ ] **Step 4: Run tests to verify they pass**

Run: `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/match_analysis test/architecture_test.dart`
Expected: PASS

- [ ] **Step 5: Commit** — `git add lib/domain/match_analysis test/domain/match_analysis` then commit `"Phân tích trận: quy cú về nhóm kỹ năng và phân tích nhiều trận"` + trailer.

---

### Task 3: Play — "Phân tích trận" sheet

**Files:**
- Create: `lib/features/play/presentation/match_analysis_sheet.dart`
- Modify: `lib/features/play/presentation/play_screen.dart` (`_matchCard`, ~:595)
- Modify: `lib/core/strings/vi.dart` (new section "Phân tích trận (spec 2026-10-28)")
- Create: `test/features/play/match_analysis_sheet_test.dart`

**Interfaces:**
- Consumes: `analyzeMatches`, `singleMatchFocus`, `MatchFocus`, `LostRackCause`, `percentOf` (Task 2).
- Produces:
  - `class MatchAnalysisView extends StatelessWidget { const MatchAnalysisView({required PoolMatch match, required MatchAnalysis analysis, required List<MatchFocus> focus}); }` — pure, no providers (Task 13 pumps it directly).
  - `class MatchAnalysisSheet extends ConsumerWidget { const MatchAnalysisSheet({required PoolMatch match}); }` — reads `drillsProvider` / `drillLogsProvider` (`.value ?? const []`), builds `analyzeMatches([match])` and `singleMatchFocus(...)`, renders `MatchAnalysisView`.
  - `Future<void> showMatchAnalysis(BuildContext context, PoolMatch match)` — `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` wrapping a scrollable `MatchAnalysisSheet`.

New `Vi` members (exact copy):

| Member | Text |
|---|---|
| `matchAnalysisOpen` | `'Phân tích trận'` |
| `matchAnalysisRacks(int withShots, int full)` | `'$withShots ván có ghi cú · $full ván ghi đủ'` |
| `matchAnalysisNoShots` | `'Trận này chưa ghi cú đánh nên chưa phân tích được nguyên nhân. Ghi cú ở trận sau để xem phân tích.'` |
| `matchAnalysisLostTitle` | `'Nguyên nhân mất ván'` |
| `lostRackCause(LostRackCause c, int n)` | offensiveMiss `'Mất $n ván sau khi trượt cú tấn công'`; safety `'Mất $n ván sau cú phòng thủ'`; foul `'Mất $n ván sau khi phạm lỗi'`; scratch `'Mất $n ván sau khi chết cái'`; dryBreak `'Mất $n ván sau khi phá khô'`; opponentBreakAndRun `'Đối thủ phá-và-dọn $n ván'`; unknown `'$n ván thua chưa ghi đủ cú nên chưa rõ nguyên nhân'` |
| `matchAnalysisBreakTitle` | `'Phá'` |
| `matchAnalysisBreak(int shots, int made, int breakAndRuns)` | `'Phá $shots ván, vào bi $made, phá-và-dọn $breakAndRuns'` |
| `matchAnalysisOpponentBreak(String name, int shots, int made, int breakAndRuns)` | `'$name: phá $shots ván, vào bi $made, phá-và-dọn $breakAndRuns'` |
| `matchAnalysisPositionTitle` | `'Điều bi và lỗi'` |
| `matchAnalysisPositionFouls(int failed, int assessed, int fouls, int scratches)` | `'Điều bi hỏng $failed/$assessed, phạm lỗi $fouls, chết cái $scratches'` |
| `matchAnalysisFocusTitle` | `'Nên luyện'` |
| `matchAnalysisFocus(String skill, int failures, int attempts)` | `'$skill: hỏng $failures/$attempts lần trong trận này'` |
| `matchAnalysisFocusDrill(String drill)` | `'Bài nên tập: $drill'` |
| `matchAnalysisFocusNone` | `'Trong trận này chưa có nhóm nào đủ ${MatchAnalysisConstants.singleMatchMinAttempts} lần thử và vượt ngưỡng yếu.'` |

View layout: score (`Vi.matchScore`) and `matchAnalysisRacks`; if `analysis.racksWithShots == 0` → only `matchAnalysisNoShots`, nothing else. Otherwise: lost-rack causes with `n > 0`, sorted by `n` desc then enum index (section hidden when the player lost no rack); break line (player), opponent line only when `opponentBreak.shots > 0`; position/fouls line (the `x/y` part shows `assessed` even when 0 — counts, never a percent); "Nên luyện" with each focus line plus its drill line when `drill != null`, or `matchAnalysisFocusNone`. On the card, an `OutlinedButton.icon(key: Key('analyze-match-${match.id}'), icon: Icon(Icons.insights_outlined), label: Text(Vi.matchAnalysisOpen))` only when `match.isComplete`.

- [ ] **Step 1: Write the failing tests** (`testContainer(matches: …, drills: roadmapDrills)` from `test/support/test_data.dart`, pump `MaterialApp(home: PlayScreen())`):

```dart
testWidgets('thẻ trận đã xong có nút Phân tích trận, trận đang đánh thì không', ...);  // findsOneWidget for the completed id, findsNothing for the open id
testWidgets('mở phân tích: thấy nguyên nhân mất ván, phá và bài nên tập', (tester) async {
  // one completed match: 1 rack lost to offensiveMiss (full), 1 rack won; ≥5 aiming attempts, ≥35% missed
  await tester.tap(find.byKey(const Key('analyze-match-m')));
  await tester.pumpAndSettle();
  expect(find.text(Vi.lostRackCause(LostRackCause.offensiveMiss, 1)), findsOneWidget);
  expect(find.text(Vi.matchAnalysisFocusDrill('Bai a1')), findsOneWidget);
});
// Review Focus 2
testWidgets('trận không có cú: chỉ tỷ số và câu chưa ghi cú', (tester) async {
  expect(find.text(Vi.matchAnalysisNoShots), findsOneWidget);
  expect(find.text(Vi.matchAnalysisLostTitle), findsNothing);
  expect(find.textContaining('%'), findsNothing);
});
testWidgets('360×640 chữ lớn: bảng phân tích không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);  // test/support/layout_sweep.dart
  // open the sheet, scrollThroughAll(tester); expect(tester.takeException(), isNull)
});
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/play` — Expected: FAIL (`match_analysis_sheet.dart` missing).
- [ ] **Step 3: Implement** the sheet, the card button and the `Vi` members.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/play test/architecture_test.dart test/smoke/responsive_routes_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit** `"Thi đấu: bảng Phân tích trận cho trận đã xong"` + trailer.

---

### Task 4: Statistics — "Phân tích trận gần đây" card

**Files:**
- Create: `lib/features/stats/presentation/match_analysis_card.dart`
- Modify: `lib/features/stats/presentation/stats_screen.dart` (insert the card after the "Chi tiết trận đấu" `PcCard`, ~:158; delete the placeholder card at ~:226-236)
- Modify: `lib/core/strings/vi.dart` (stats section)
- Create: `test/features/stats/match_analysis_card_test.dart`
- Modify: `test/features/stats/stats_screen_test.dart`

**Interfaces:**
- Consumes: `analyzeMatches`, `MatchAnalysis`, `percentOf`, `MatchAnalysisConstants` (Task 2).
- Produces: `class MatchAnalysisCard extends StatelessWidget { const MatchAnalysisCard({required MatchAnalysis analysis}); }` (pure; Task 13 pumps it).

New / changed `Vi` members (exact copy; a line whose denominator is 0 is not rendered):

| Member | Text |
|---|---|
| `statsMatchAnalysisTitle` | `'Phân tích trận gần đây'` |
| `statsMatchAnalysisBasis(int matches, int fullRacks)` | `'Dựa trên $matches trận, $fullRacks ván ghi đủ'` |
| `statsMatchAnalysisEmpty` | `'Chưa có trận hoàn tất nào có ghi cú. Ghi cú trong trận để xem phân tích.'` |
| `statsBreakLine(int shots, int madePercent, int dry, int fouls, int scratches)` | `'Phá: $shots cú · vào bi $madePercent% · phá khô $dry · phạm lỗi $fouls · chết cái $scratches'` |
| `statsBreakAndRun(int breakAndRuns, int racksBroken)` | `'Phá-và-dọn: $breakAndRuns/$racksBroken ván bạn phá'` |
| `statsRunOuts(int n)` | `'Dọn bàn: $n ván'` |
| `statsOffense(int missed, int shots, int percent)` | `'Tấn công: trượt $missed/$shots cú thường ($percent%)'` |
| `statsPositionMiss(int failed, int assessed, int percent)` | `'Điều bi hỏng: $failed/$assessed cú có ghi vị trí ($percent%)'` |
| `statsPositionFollowUp(int afterFailed, int nextFailed, int afterGood, int nextGood)` | `'Trượt cú kế tiếp: $afterFailed/$nextFailed sau điều bi hỏng, $afterGood/$nextGood sau điều bi tốt'` |
| `statsSafety(int successful, int assessed, int safetyTurnovers, int proactive)` | `'Phòng thủ: thành công $successful/$assessed · $safetyTurnovers/$proactive lần mất lượt chủ động là phòng thủ'` |
| `statsErrors(int fouls, int scratches, int shots)` | `'Phạm lỗi $fouls, chết cái $scratches trên $shots cú'` |
| `statsMatchWeakTitle` | `'Nhóm yếu khi thi đấu'` |
| `statsMatchWeak(String skill, int failures, int attempts, int percent)` | `'$skill: hỏng $failures/$attempts lần ($percent%)'` |
| `statsMatchWeakNone` | `'Chưa đủ dữ liệu để kết luận (cần ít nhất ${MatchAnalysisConstants.minMatches} trận và ${MatchAnalysisConstants.minAttempts} lần thử mỗi nhóm).'` |
| `statsScratches`, `matchShotScratch` | ★ `'Chết cái'` (was `'Scratch'`) |
| `statsMatchAnalysisNotAvailable` | ★ delete (placeholder replaced by the real card) |

Card: title; when `analysis.playerShots == 0` → `statsMatchAnalysisEmpty` only; else every line above in that order, then the weak list (`statsMatchWeak` per `analysis.weaknesses`, or `statsMatchWeakNone`), then the basis line last. `StatsScreen` passes `analyzeMatches(matchesAsync.requireValue)`.

- [ ] **Step 1: Write the failing tests** — `match_analysis_card_test.dart`:

```dart
testWidgets('yếu Ngắm bi rồi đổi sang yếu Điều bi: dòng nhóm yếu đổi theo', (tester) async {
  // pump MatchAnalysisCard(analysis: analyzeMatches(matchesWeakAt(aiming, at: testToday)))
  expect(find.textContaining(Vi.skill(SkillCategory.aiming)), findsWidgets);
  // re-pump with matchesWeakAt(position): the statsMatchWeak line names Vi.skill(position), not aiming
});
testWidgets('dòng cỡ mẫu nói số trận và số ván ghi đủ', ...);  // Vi.statsMatchAnalysisBasis(3, a.fullRacks)
// Review Focus 2
testWidgets('không có cú: chỉ câu rỗng, không phần trăm, không NaN', (tester) async {
  expect(find.text(Vi.statsMatchAnalysisEmpty), findsOneWidget);
  expect(find.textContaining('%'), findsNothing);
  expect(find.textContaining('NaN'), findsNothing);
});
testWidgets('có phá nhưng không có cú phòng thủ: dòng phòng thủ ẩn', ...);
```

In `stats_screen_test.dart`: replace any expectation on `statsMatchAnalysisNotAvailable` with `find.text(Vi.statsMatchAnalysisTitle)` findsOneWidget.

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/stats` — Expected: FAIL.
- [ ] **Step 3: Implement** the card, the screen wiring and the `Vi` changes; `grep -rn "statsMatchAnalysisNotAvailable" lib test` must return nothing.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/stats test/features/play test/architecture_test.dart test/smoke/responsive_routes_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit** `"Thống kê: thẻ Phân tích trận gần đây; đổi Scratch thành Chết cái"` + trailer.

---

### Task 5: Player Intelligence — `matchWeak`, `buPercent`, BU-sourced weak groups

**Files:**
- Modify: `lib/domain/player_intelligence.dart` (class :97-120, `computePlayerIntelligence` :151-212)
- Modify: `lib/domain/roadmap/bu_gap.dart` (`BuResult`, `buResultFrom`, new `buCategoryPercent`)
- Modify: `lib/core/providers/player_intelligence_provider.dart`
- Modify: `test/support/roadmap_fixtures.dart` (add `buResultGraded`)
- Modify: `test/domain/player_intelligence_test.dart`, `test/domain/roadmap/bu_gap_test.dart`, `test/core/providers/recommendation_provider_test.dart` (container overrides)

**Interfaces:**
- Consumes: `analyzeMatches`, `SkillSignal` (Task 2).
- Produces:
  - `BuResult({…, Map<String, int> max = const {}})` → `final Map<String, int> max` (unmodifiable; drill id → max score of the version taken). `buResultFrom` fills it from `examIDrills` + `examIIDrills(version)`.
  - `Map<SkillCategory, int> buCategoryPercent(BuResult r)` — per category of `buDrillCategory` with total max > 0: `percentOf(max − lost, max)` summed over its drills; categories with no max absent; S8/S9 ignored.
  - `enum WeakSource { drills, bu }`
  - `PlayerIntelligence({…, List<SkillSignal> matchWeak = const [], Map<SkillCategory, int> buPercent = const {}, Map<SkillCategory, WeakSource> weakSources = const {}})`.
  - `PlayerIntelligence computePlayerIntelligence({required List<Drill> drills, required List<DrillLog> logs, List<PoolMatch> matches = const [], BuResult? latestBu})` — all three existing call sites compile unchanged.
  - `playerIntelligenceProvider` (`Provider<PlayerIntelligence?>`) additionally watches `matchesProvider` and `latestBuResultProvider` (from `roadmap_providers.dart`); returns `null` until drills, logs, matches and BU are each `hasValue && !isLoading`.
  - Fixture `BuResult buResultGraded({required DateTime completedAt, Map<String, int> lost = const {}, int total = 100})` — `max` of Exam I + `examIIDrills(ExamIIVersion.masters)`.

Rules: `matchWeak = analyzeMatches(matches).weaknesses` (mastery is **not** mixed with match rates). `buPercent = latestBu == null ? {} : buCategoryPercent(latestBu)`. `weak` = drill-weak (as today, ascending mastery, source `drills`) followed by ★ categories with `mastery == null` and `buPercent[c]! < PracticeConstants.weakCutoff`, ascending `buPercent`, source `bu`. A category that has mastery keeps mastery as its only source.

- [ ] **Step 1: Write the failing tests**

```dart
// player_intelligence_test.dart
test('matchWeak đến từ phân tích trận và không đổi mastery', () {
  final pi = computePlayerIntelligence(drills: seedDrills, logs: const [], matches: matchesWeakAt(SkillCategory.position, at: DateTime(2026, 10, 20)));
  expect(pi.matchWeak.first.category, SkillCategory.position);
  expect(pi.categories[SkillCategory.position]!.mastery, isNull);
});
test('nhóm chưa có mastery mà BU < 55 thì vào weak, nguồn bu', () {
  // buResultGraded lost F7 = 20 (aiming) → aiming buPercent < 55
  expect(pi.weak, contains(SkillCategory.aiming));
  expect(pi.weakSources[SkillCategory.aiming], WeakSource.bu);
});
test('nhóm đã có mastery giữ mastery làm nguồn; BU không kéo nó vào weak', () { /* aiming mastery 90 + BU aiming 40% → not weak */ });
test('không truyền trận, không truyền BU: kết quả như cũ', () { /* matchWeak, buPercent empty */ });
// bu_gap_test.dart
test('buCategoryPercent theo bản đã làm, S8/S9 không tính', () { /* exact ints for aiming/position/safety */ });
test('buResultFrom điền max của từng bài', () { /* max['F7'] == 20 */ });
// recommendation_provider_test.dart or a new test/core/providers/player_intelligence_provider_test.dart — Review Focus 4
test('trận đang tải lại với giá trị cũ (đổi tài khoản): PI là null', () async {
  // matchesProvider.overrideWithValue(const AsyncLoading<List<PoolMatch>>().copyWithPrevious(AsyncData(old)))
  // latestBuResultProvider.overrideWithValue(const AsyncData<BuResult?>(null))
  expect(container.read(playerIntelligenceProvider), isNull);
});
```

Add `matchesProvider.overrideWith((ref) => Stream.value(const <PoolMatch>[]))` and `latestBuResultProvider.overrideWithValue(const AsyncData<BuResult?>(null))` to `containerWith` in `recommendation_provider_test.dart` (untyped list).

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/player_intelligence_test.dart test/domain/roadmap/bu_gap_test.dart test/core/providers` — Expected: FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain test/core/providers` — Expected: PASS (existing PI, roadmap and coach tests unchanged).
- [ ] **Step 5: Commit** `"Player Intelligence: nhóm yếu trong trận và điểm BU theo nhóm"` + trailer.

---

### Task 6: Today's pick — `PickReason.matchWeakness`

**Files:**
- Modify: `lib/domain/recommendation.dart` (`PickReason` :47, `pickCategoryForToday` :89, `TodayRecommendation` :182, `computeRecommendation` :260)
- Modify: `lib/core/providers/recommendation_provider.dart`
- Modify: `lib/core/strings/vi.dart` (`pickReason` :84)
- Modify: `lib/features/home/presentation/home_screen.dart` (:120)
- Modify: `server/coach-chat/src/prompt.mjs` (`today` bullet: add `matchWeakness`)
- Modify: `test/domain/pick_category_test.dart`, `test/domain/compute_recommendation_test.dart`, `test/core/strings/vi_test.dart`, `test/core/providers/recommendation_provider_test.dart`

**Interfaces:**
- Consumes: `PlayerIntelligence.matchWeak`, `computePlayerIntelligence(matches:, latestBu:)` (Task 5).
- Produces:
  - `PickReason.matchWeakness`, declared between `streakAtRisk` and `weakest`.
  - `TodayRecommendation({…, SkillSignal? matchSignal})` — non-null exactly when `reason == PickReason.matchWeakness`.
  - `TodayRecommendation computeRecommendation({…existing…, List<PoolMatch> matches = const [], BuResult? latestBu})`.
  - `static String Vi.pickReason(PickReason reason, String skill, {SkillSignal? signal})`.
  - `todayRecommendationProvider` also watches `matchesProvider` and `latestBuResultProvider`; error from either is surfaced; loading until each is `hasValue && !isLoading`.

Rule order in `pickCategoryForToday`: scheduled → streakAtRisk → **matchWeakness** (`pi.matchWeak.isNotEmpty` → `pi.matchWeak.first.category`) → weakest → newcomer → declining → rotation. Update the doc comment ("Bảy luật").

`Vi.pickReason` for `matchWeakness`: with signal `'Trong ${s.matches} trận gần đây, $skill hỏng ${s.failures}/${s.attempts} lần (${percentOf(s.failures, s.attempts)}%).'`; ★ without signal `'$skill đang yếu khi thi đấu.'` (keeps the existing "every reason is a distinct sentence containing the skill" tests valid). Home passes `signal: rec.matchSignal`.

Prompt (`today.reason` list): add `matchWeakness (nhóm yếu khi thi đấu, theo phân tích các trận gần đây)`.

- [ ] **Step 1: Write the failing tests**

```dart
// pick_category_test.dart
test('yếu trong trận thắng luật yếu theo bài tập', () { /* pi with weak [aiming] and matchWeak [position] → (position, matchWeakness) */ });
test('lịch hôm nay và sắp mất streak vẫn đứng trên yếu trong trận', () { /* two cases */ });
// compute_recommendation_test.dart
test('gợi ý mang tín hiệu trận khi lý do là yếu trong trận', () {
  final rec = computeRecommendation(..., matches: matchesWeakAt(SkillCategory.position, at: today));
  expect([rec.reason, rec.cat, rec.matchSignal!.category], [PickReason.matchWeakness, SkillCategory.position, SkillCategory.position]);
});
// vi_test.dart
test('lý do yếu trong trận nói số trận, số lần hỏng và tỷ lệ', () {
  expect(Vi.pickReason(PickReason.matchWeakness, 'Điều bi / Vị trí',
      signal: const SkillSignal(category: SkillCategory.position, failures: 6, attempts: 10, matches: 3)),
      'Trong 3 trận gần đây, Điều bi / Vị trí hỏng 6/10 lần (60%).');
});
// recommendation_provider_test.dart — Review Focus 4
test('trận đang tải lại với giá trị cũ: gợi ý vẫn đang tải', ...);
test('lỗi ở trận thì chuyển lỗi', ...);
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/pick_category_test.dart test/domain/compute_recommendation_test.dart test/core/strings/vi_test.dart test/core/providers` — Expected: FAIL.
- [ ] **Step 3: Implement** per Interfaces and the prompt line.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain test/core test/features/home` and `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test` — Expected: PASS (includes `coach_chat_prompt_test.dart`, which now sees `matchWeakness`).
- [ ] **Step 5: Commit** `"Gợi ý hôm nay: luật yếu trong trận đứng trước yếu theo bài tập"` + trailer.

---

### Task 7: Coach situational — `CoachTopicReason.matchWeakness`

**Files:**
- Modify: `lib/domain/coach/coach_recommendation.dart`
- Modify: `lib/core/strings/vi.dart` (`coachRecReason` :1819)
- Modify: `test/domain/coach/coach_recommendation_test.dart`, `test/core/strings/vi_coach_test.dart`

**Interfaces:**
- Consumes: `PlayerIntelligence.matchWeak` (Task 5), `PickReason.matchWeakness` (Task 6).
- Produces: `CoachTopicReason.matchWeakness` (declared after `sameAsToday`).

★ Order in `computeCoachRecommendation`: (1) today has a topic and `today.reason == PickReason.matchWeakness` → that topic, `matchWeakness`; (2) today has a topic → `sameAsToday`; (3) first `pi.matchWeak` category with a topic → `matchWeakness`; (4) `weakest`; (5) `lowest`. Home and Coach therefore agree whenever Home's own match rule fires; Phá (no topic) falls through to step 3.

`Vi.coachRecReason(CoachTopicReason.matchWeakness, t)` → `'${coachTopic(t)} đang yếu trong các trận gần đây.'`

- [ ] **Step 1: Write the failing tests**

```dart
test('gợi ý hôm nay là yếu trong trận: lý do thẻ Coach là matchWeakness', ...);
test('hôm nay là Phá (không có tình huống), trận yếu Điều bi: chọn Điều bi, lý do matchWeakness', ...);
test('trận yếu Phá mà bài tập yếu Phòng thủ: rơi xuống weakest', ...);  // break has no topic
// vi_coach_test.dart 'mỗi loại gợi ý và lý do ra một câu khác nhau' already iterates values — extend if it lists them by hand
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/coach/coach_recommendation_test.dart test/core/strings/vi_coach_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/coach test/core/strings test/features/coach` — Expected: PASS.
- [ ] **Step 5: Commit** `"Coach: thẻ Nên luyện gì ưu tiên nhóm yếu trong trận"` + trailer.

---

### Task 8: Coach chat facts — `matches.analysis` and `matches.last.*`

**Files:**
- Modify: `lib/domain/coach/chat_facts.dart`, `lib/domain/coach/coach_context.dart` (`toFacts`)
- Modify: `server/coach-chat/src/prompt.mjs`
- Modify: `server/coach-chat/test/prompt.test.mjs`, `server/coach-chat/test/validate.test.mjs`
- Modify: `test/support/coach_chat_fixtures.dart` (`fullCoachContext()` gets ≥ 3 completed matches with full racks and shots; new `CoachContext contextWithMatches(List<PoolMatch> matches)` = `fullCoachContext()` inputs with these matches)
- Modify: `test/domain/coach/coach_context_test.dart`, `test/domain/coach/coach_chat_prompt_test.dart`, `test/domain/coach/coach_chat_limits_test.dart`, `test/domain/coach/chat_filter_test.dart`

**Interfaces:**
- Consumes: `analyzeMatches`, `MatchAnalysis`, `percentOf`, `LostRackCause`, `MatchAnalysisConstants` (Task 2).
- Produces:
  - `typedef MatchFacts = ({int played, int won, int lost, LastMatchFacts? last, MatchAnalysis analysis});` (`analysis = analyzeMatches(matches)`)
  - `LastMatchFacts` gains `MatchAnalysis analysis` (`analyzeMatches([thatMatch])`).
  - Facts JSON (keys added, old keys untouched; all percents are ints from `percentOf`, `null` when the denominator is 0):

```
matches.analysis = {
  matches, racksWon, racksLost, racksWithShots, fullRacks, runOuts,
  break: {shots, made, madePercent, dry, fouls, scratches, racksBroken, breakAndRuns},
  offense: {shots, missed, missPercent},
  position: {assessed, failed, failedPercent, nextAfterFailed, missAfterFailed, nextAfterGood, missAfterGood},
  safety: {shots, assessed, successful, successPercent, turnovers, proactiveTurnovers},
  errors: {shots, fouls, scratches},
  lostRackCauses: {<every LostRackCause.name>: int},
  weak: [{category, failures, attempts, matches, failPercent}],
  weakRule: {minMatches, minAttempts, failPercentFrom: {breakShot, aiming, position, safety}},
}
matches.last += { lostRackCauses: {…}, break: {…same as above…}, position: {…same…}, fouls: {shots, fouls, scratches} }
```

★ `chat_filter.dart` needs no code change: it already allows any number present in facts, and the facts carry the integer percents the UI shows. This task adds tests proving it.

Prompt (`ĐỌC DỮ KIỆN`, after the `matches` bullet) explains every key above in Vietnamese, plus `LostRackCause` values (offensiveMiss trượt cú tấn công, safety sau cú phòng thủ, foul phạm lỗi, scratch chết cái, dryBreak phá khô, opponentBreakAndRun đối thủ phá-và-dọn, unknown ván chưa ghi đủ cú), "ván ghi đủ", and that `weak` is decided by the app with `weakRule` (the LLM never decides weakness itself). `THUẬT NGỮ` gains: Phá-và-dọn (người phá ăn hết bàn, đối thủ không được đánh cú nào), Dọn bàn (ăn hết phần bi còn lại trong một lượt), Phá khô (phá không có bi vào). Keep the prompt free of `${` and backticks.

- [ ] **Step 1: Write the failing tests**

```dart
// coach_context_test.dart
test('matches.analysis có đủ khoá và đúng số của analyzeMatches', () { /* exact values for a fixture */ });
test('matches.last có nguyên nhân mất ván, phá, điều bi và lỗi của riêng trận đó', ...);
// update 'chưa có trận nào xong: recent 0, last null' — expected map now also has 'analysis' with zero counts and null percents
// coach_chat_prompt_test.dart — add LostRackCause.values to the enum list
// coach_chat_limits_test.dart
test('facts đầy đủ với 10 trận nhiều cú vẫn dưới MAX_FACTS_BYTES', () {
  final max = serverConstant(File('server/coach-chat/src/validate.mjs').readAsStringSync(), 'MAX_FACTS_BYTES');
  final ten = matchesWeakAt(SkillCategory.aiming, count: 10, at: DateTime(2026, 10, 20));
  expect(utf8.encode(jsonEncode(contextWithMatches(ten).toFacts())).length, lessThan(max));
});
// chat_filter_test.dart
test('số của phân tích trận có trong facts thì cho qua; số bịa thì chặn', () {
  // facts from fullCoachContext(); 'Bạn trượt 6/10 cú thường (60%).' passes when those numbers are in matches.analysis; '73%' blocked
});
```

```js
// server/coach-chat/test/prompt.test.mjs
test('lời dặn giải thích khoá phân tích trận và thuật ngữ phá-và-dọn', () => {
  for (const must of ['lostRackCauses', 'breakAndRuns', 'fullRacks', 'weakRule', 'opponentBreakAndRun', 'Phá-và-dọn', 'Dọn bàn', 'Phá khô']) {
    assert.ok(SYSTEM_PROMPT.includes(must), must);
  }
});
// server/coach-chat/test/validate.test.mjs
test('facts có matches.analysis vẫn hợp lệ', () => { /* parseChatRequest accepts a body whose facts.matches carries an analysis object shaped as above */ });
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/coach` and `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test` — Expected: FAIL.
- [ ] **Step 3: Implement** facts, prompt and fixtures.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/coach test/core/providers test/features/coach` and `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test` — Expected: PASS.
- [ ] **Step 5: Commit** `"Coach Chat: fact phân tích trận, cập nhật lời dặn dịch vụ coach-chat"` + trailer.

---

### Task 9: Lộ trình — tournament prep uses match data

**Files:**
- Modify: `lib/domain/roadmap/roadmap.dart` (`StepKind`, new `StepReason` classes)
- Modify: `lib/domain/roadmap/roadmap_builder.dart` (`buildRoadmap` :15, `_tournament` :143)
- Modify: `lib/core/providers/roadmap_providers.dart` (`roadmapProvider`)
- Modify: `lib/core/strings/vi.dart` (`stepTitle` :1707, `stepReason` :1726)
- Modify: `lib/features/roadmap/presentation/step_tile.dart` (:24-40)
- Modify: `server/coach-chat/src/prompt.mjs` (`currentStep.kind` list: add `dauTap (đấu tập: ghi thêm trận có ghi cú)`)
- Modify: `test/domain/roadmap/roadmap_other_goals_test.dart`, `test/core/strings/vi_roadmap_test.dart`, `test/features/roadmap/roadmap_screen_test.dart`, `test/core/providers/roadmap_providers_test.dart`

**Interfaces:**
- Consumes: `analyzeMatches`, `MatchAnalysisConstants` (Task 2).
- Produces:
  - `StepKind.dauTap` (appended last).
  - `final class MatchWeakness extends StepReason { const MatchWeakness(this.failures, this.attempts); final int failures; final int attempts; }` ★ (spec's `StepReason.matchWeakness(category, …)`; category already lives on `RoadmapStep.category`).
  - `final class NotEnoughMatches extends StepReason { const NotEnoughMatches(this.have, this.need); final int have; final int need; }`
  - `Roadmap buildRoadmap({…existing…, List<PoolMatch> matches = const []})`.
  - `int recentRecordedMatches(List<PoolMatch> matches, DateTime today)` (in `roadmap_builder.dart`) — ★ completed matches with ≥ 1 shot whose `completedAt ?? startedAt` is within the last `MatchAnalysisConstants.matchWindowDays` days.
  - `roadmapProvider` also watches `matchesProvider` (`_ready`).

`_tournament` order: (1) if `recentRecordedMatches < tournamentMinMatches`, first step `RoadmapStep(kind: dauTap, status: chuaToi, reason: NotEnoughMatches(have, 3))` — ★ absent once enough; (2) one step per `analyzeMatches(matches).weaknesses` category: `facts.groupStep(c, MatchWeakness(f, a)).withStatus(StepStatus.chuaToi)` — ★ never starts as `xong`, it leaves the list when the match data stops flagging it; (3) the existing list (BU lost points, then drill weakness) minus categories already placed. `placeSteps` unchanged (a `dauTap` step has no estimate).

`Vi`: `stepTitle` `dauTap` → `'Đấu tập: ghi ít nhất ${need - have} trận có ghi cú'` (read `have`/`need` from `step.reason as NotEnoughMatches`); `stepReason` `MatchWeakness` → `'Hỏng $failures/$attempts lần trong các trận gần đây.'`; `NotEnoughMatches` → `'Có $have/$need trận có ghi cú trong ${MatchAnalysisConstants.matchWindowDays} ngày qua.'`; new `stepRecordMatch = 'Ghi trận'`. Step tile: `case StepKind.dauTap` → `FilledButton(onPressed: () => context.go(Routes.play), child: Text(Vi.stepRecordMatch))`.

- [ ] **Step 1: Write the failing tests** (`roadmap_other_goals_test.dart`, group `'Chuẩn bị giải (mục 4.3)'`; give the file's `build` helper a `List<PoolMatch> matches = const []` parameter passed to `buildRoadmap`):

```dart
test('ít hơn 3 trận có ghi cú trong 28 ngày: bước đầu là Đấu tập', () {
  final r = build(tournamentGoal, matches: [/* 2 recent recorded + 1 recorded 40 days ago + 1 recent without shots */]);
  expect(r.steps.first.kind, StepKind.dauTap);
  expect((r.steps.first.reason as NotEnoughMatches).have, 2);
  expect(r.currentStep!.kind, StepKind.dauTap);
});
test('đủ trận: không có bước Đấu tập; nhóm yếu trong trận đứng đầu, trước nhóm mất điểm BU', () {
  final r = build(tournamentGoal, matches: matchesWeakAt(SkillCategory.position, at: roadmapToday), result: /* lost F7 = 20 (aiming) */);
  expect(r.steps.map((s) => s.category).take(2), [SkillCategory.position, SkillCategory.aiming]);
  expect(r.steps.first.reason, isA<MatchWeakness>());
});
test('nhóm yếu trong trận dù bài tập đã ≥ 75 vẫn chưa xong', ...);
```

Update existing tournament tests (they pass no matches, so they now see a leading `dauTap` step): assert it, then assert the old order from `steps.skip(1)`. `vi_roadmap_test.dart`: exact strings for the two new reasons and the `dauTap` title. `roadmap_screen_test.dart`: the `'Chuẩn bị giải …'` widget test finds `Vi.stepRecordMatch`.

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/roadmap test/core/strings/vi_roadmap_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**, including the prompt line.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain test/core test/features/roadmap` and `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test` — Expected: PASS.
- [ ] **Step 5: Commit** `"Lộ trình: chuẩn bị giải dùng dữ liệu trận, bước Đấu tập"` + trailer.

---

### Task 10: Target rank — data, Drift v14, sync, Directus schema

**Files:**
- Modify: `lib/domain/roadmap/goal.dart` (`PlayerGoal`)
- Modify: `lib/data/database/database.dart` (`PlayerGoalRows` :250, `schemaVersion` :367, migration)
- Modify: `lib/data/database/roadmap_converters.dart` (all goal functions, `remoteGoalFields`)
- Modify: `lib/data/repositories/roadmap_repository.dart` (`setGoal` :31)
- Modify: `deploy/directus/bootstrap.mjs` (`player_goals` fields :276-287; permissions create :494 and update :502)
- Modify: `deploy/directus/verify.mjs` (after the goal checks, ~:211)
- Modify: `test/data/database/migration_test.dart`, `test/data/database/roadmap_converters_test.dart`, `test/data/sync/roadmap_sync_test.dart`, `test/data/repositories/roadmap_repository_test.dart`, `test/domain/roadmap/goal_test.dart`

**Interfaces:**
- Produces:
  - `PlayerGoal({…, Rank? targetRank})` → `final Rank? targetRank;` with `assert(targetRank == null || kind == GoalKind.lenHang)`; included in `==`, `hashCode`, `toString`. Doc: null = next rank (old behaviour).
  - `PlayerGoalRows.targetRank` → `TextColumn get targetRank => text().nullable()();` (`Rank.name`).
  - `schemaVersion => 14`; migration `if (from >= 4 && from < 14) await m.addColumn(playerGoalRows, playerGoalRows.targetRank);` (table created at v4 already carries the column).
  - `remoteGoalFields = 'id,goal_id,kind,category,event_date,created_at,updated_at,target_rank'`; `toRemoteGoal` writes `'target_rank'`; `goalFromRemote` / `toGoalRecord` / `toGoalRow` map it (`Rank.values.byName`).
  - `Future<void> RoadmapRepository.setGoal({required GoalKind kind, SkillCategory? category, DateTime? eventDate, Rank? targetRank})` — stores `targetRank` only for `lenHang`.
  - Directus: `nullable('target_rank', 'string')` in `player_goals`; `'target_rank'` added to the Player create and update `fields` lists. `verify.mjs`: A PATCHes its own goal `{ kind: 'lenHang', category: null, target_rank: 'd', updated_at: … }` → 200, then `GET /items/player_goals/${aId}?fields=target_rank` returns `'d'` (use the file's `call`/`ok`/`fail` helpers).

- [ ] **Step 1: Write the failing tests**

```dart
// migration_test.dart
test('nâng từ v13 lên v14 thêm hạng đích, giữ nguyên mục tiêu đang có', () async {
  // setup: CREATE TABLE player_goal_rows (user_id TEXT NOT NULL PRIMARY KEY, goal_id TEXT NULL, kind TEXT NULL,
  //   category TEXT NULL, event_date INTEGER NULL, created_at INTEGER NULL, updated_at INTEGER NOT NULL, synced_at INTEGER NULL);
  //   INSERT one lenHang row; PRAGMA user_version = 13;
  expect(db.schemaVersion, 14);
  final row = (await db.select(db.playerGoalRows).get()).single;
  expect([row.kind, row.targetRank], ['lenHang', null]);
});
test('tạo mới ở v14 ghi và đọc được hạng đích', () async { /* fresh NativeDatabase.memory(); insert targetRank 'd'; read back */ });
// roadmap_converters_test.dart
test('mục tiêu có hạng đích qua Drift và Directus rồi về nguyên vẹn', ...);
// roadmap_sync_test.dart
test('mục tiêu có hạng đích: POST mang target_rank', ...);  // fake Directus body['target_rank'] == 'd'
// roadmap_repository_test.dart
test('hạng đích chỉ lưu cho Lên hạng', ...);  // setGoal(kind: chuanBiGiai, targetRank: Rank.d, eventDate: …) → null; read with db.select
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/data test/domain/roadmap/goal_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**, then `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs`; then `node --check deploy/directus/bootstrap.mjs && node --check deploy/directus/verify.mjs`.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/data test/domain/roadmap` — Expected: PASS. `node --check` on both scripts exits 0. Do **not** run bootstrap or verify (they hit prod).
- [ ] **Step 5: Commit** `"Mục tiêu Lên hạng có hạng đích: Drift v14, đồng bộ và Directus player_goals.target_rank"` + trailer.

---

### Task 11: Multi-rank roadmap and the target-rank picker

**Files:**
- Modify: `lib/domain/roadmap/roadmap.dart` (new reason), `lib/domain/roadmap/roadmap_builder.dart` (`_lenHang` :34, `_untilEnough` :101), `lib/domain/roadmap/goal.dart` (new helper)
- Modify: `lib/features/roadmap/presentation/goal_picker.dart`
- Modify: `lib/core/strings/vi.dart` (`goalKindBody`, `stepTitle`, `stepReason`, new members)
- Modify: `test/domain/roadmap/roadmap_len_hang_test.dart`, `test/core/strings/vi_roadmap_test.dart`, `test/features/roadmap/roadmap_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerGoal.targetRank`, `RoadmapRepository.setGoal(targetRank:)` (Task 10).
- Produces:
  - `Rank? effectiveTarget(PlayerGoal goal, Rank from)` (goal.dart) — `goal.targetRank` when it is above `from` (and ≤ `Rank.a`), ★ else `nextRank(from)`.
  - `List<Rank> targetRankChoices(Rank from)` (goal.dart) — `nextRank(from)` … `Rank.a` ascending; empty for A/PRO.
  - `final class RankMilestone extends StepReason { const RankMilestone(this.rank); final Rank rank; }` on a `StepKind.lamBaiBu` step.

`_lenHang` with `target = effectiveTarget(goal, from)` (null → `topRank` block as today); intermediates = ranks strictly between `from` and `target`; `pointsNeeded = buFloor(target) − total`.
- With a BU result: walk the points-sorted entries as `_untilEnough` does; after the entry that brings the running sum to ≥ `buFloor(r) − total`, insert `RoadmapStep(kind: lamBaiBu, status: chuaToi, reason: RankMilestone(r))`; a milestone already reached (`≤ 0`) goes first; milestones still unplaced when entries run out go right before the final step. Final step unchanged: `lamBaiBu` + `RetestFrom(retestFrom)`.
- ★ Without a BU result: weak-group steps, then every milestone in rank order, then the final step.
- `placeSteps` unchanged.

`Vi`: `goalKindBody(lenHang)` → `'Chọn hạng đích, từ hạng ngay trên tới hạng A, theo điểm BU còn thiếu.'`; `goalTargetRankTitle = 'Lên tới hạng'`; `stepTitle` for `lamBaiBu` with `RankMilestone(:rank)` → `'Làm lại bài BU — mốc hạng ${rank.label}'`; `stepReason(RankMilestone)` → `'Đạt ${buFloor(rank)} điểm BU là lên hạng ${rank.label}.'`.

Goal picker: tapping "Lên hạng" (unblocked) toggles `_pickingRank` and shows `ActionChip(key: Key('goal-target-${r.name}'), label: Text(r.label))` for each `targetRankChoices(rank)` under a `goalTargetRankTitle` label; a chip calls `_set(GoalKind.lenHang, targetRank: r == nextRank(from) ? null : r)` ★ (next rank stored as null keeps auto-advance).

- [ ] **Step 1: Write the failing tests**

```dart
// roadmap_len_hang_test.dart
test('lên 2 hạng có BU: mốc trung gian sau khối bài đủ điểm của mốc đó', () {
  // rank H (BU total 50); goal targetRank F; lost F7=20 (aiming), F2=15 (position), S5=12 (safety)
  // buFloor(G)=70 → need 20 → milestone G right after aiming (sum 20); buFloor(F)=95 → need 45 → stop after safety (sum 47)
  expect(r.steps.map((s) => (s.kind, s.category, s.reason is RankMilestone ? (s.reason as RankMilestone).rank : null)), [
    (StepKind.nhom, SkillCategory.aiming, null),
    (StepKind.lamBaiBu, null, Rank.g),
    (StepKind.nhom, SkillCategory.position, null),
    (StepKind.nhom, SkillCategory.safety, null),
    (StepKind.lamBaiBu, null, null),
  ]);
  expect([r.target, r.pointsNeeded], [Rank.f, 45]);
});
test('lên 2 hạng chưa có BU: các mốc đứng sau bước nhóm, trước bước BU cuối', ...);
test('targetRank null: hành vi cũ, đích là hạng kế tiếp', ...);
// Review Focus 5
test('đã đạt hoặc vượt hạng đích: quay về hạng kế tiếp, không điểm âm', () {
  // goal targetRank G, rank now F → target E, no milestone, pointsNeeded = buFloor(E) − total
});
test('targetRankChoices(H) = G…A; targetRankChoices(A) rỗng', ...);
// roadmap_screen_test.dart
testWidgets('chọn Lên hạng rồi chọn hạng F: lưu hạng đích F', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // seed rank H: db.into(db.playerRankRows).insert(toPlayerRankRow(...)) as in test/features/rank/onboarding_screen_test.dart:114
  await open(tester, dbContainer(db));
  await tester.tap(find.text(Vi.goalKind(GoalKind.lenHang)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('goal-target-f')));
  await tester.pumpAndSettle();
  expect((await db.select(db.playerGoalRows).get()).single.targetRank, 'f');
  expect(find.text('Lên hạng: H → F'), findsOneWidget);
});
testWidgets('chọn hạng kế tiếp thì lưu hạng đích rỗng', ...);
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/roadmap test/core/strings/vi_roadmap_test.dart test/features/roadmap` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain test/core test/features/roadmap test/smoke` — Expected: PASS.
- [ ] **Step 5: Commit** `"Lộ trình: lên nhiều hạng một lúc, mốc BU cho từng hạng trung gian"` + trailer.

---

### Task 12: Rank re-check hint (`RankCheckSignal`)

**Files:**
- Create: `lib/domain/roadmap/rank_check.dart`
- Create: `test/domain/roadmap/rank_check_test.dart`
- Modify: `lib/core/providers/roadmap_providers.dart`
- Create: `lib/features/rank/presentation/rank_check_line.dart`
- Modify: `lib/features/rank/presentation/rank_card.dart` (after the warning text, ~:44)
- Modify: `lib/features/roadmap/presentation/roadmap_home_line.dart`
- Modify: `lib/core/strings/vi.dart`
- Modify: `test/features/rank/rank_card_test.dart`, `test/features/home/home_screen_test.dart`, `test/core/providers/roadmap_providers_test.dart`

**Interfaces:**
- Consumes: `PlayerIntelligence.buPercent`, `.matchWeak`, `.categories[c].trend` (Task 5); `buResultGraded` fixture (Task 5); `nextRank` (goal.dart).
- Produces:
  - `enum RankCheckDirection { down, up }`; `enum RankCheckBasis { drills, matches }`.
  - `final class RankCheckSignal { RankCheckDirection direction; RankCheckBasis basis; List<SkillCategory> categories; Rank rank; }`
  - `RankCheckSignal? rankCheckSignal({required PlayerRank? rank, required BuResult? latestBu, required PlayerIntelligence pi, required DateTime today})`
  - `final rankCheckSignalProvider = Provider<RankCheckSignal?>(…)` — null unless `playerRankProvider` and `latestBuResultProvider` are `_ready` and `playerIntelligenceProvider` is non-null.
  - `class RankCheckLine extends ConsumerWidget` — `SizedBox.shrink()` when the signal is null, else a warning-coloured `Text`.

Rules (spec §6.5, ★ mapping `declining`/`improving` to `SkillTrend.down`/`SkillTrend.up`): emit only when `rank?.isVerified == true`, `latestBu != null`, and `dateOnly(today)` is ≥ `rankCheckMinDays` days after `dateOnly(latestBu.completedAt)`. ★ "Graded by BU" = keys of `pi.buPercent`. Down/drills: ≥ 2 graded categories with trend `down` → `categories` = those, `rank` = current. Down/matches (checked when down/drills does not fire): `pi.matchWeak.length >= 2` → categories from `matchWeak`, `rank` = current. Up: ≥ 2 graded `up` and no graded `down`, and `nextRank(current) != null` → `rank` = next. Category lists in `SkillCategory` order (matches: `matchWeak` order). The function returns data only — it never builds a `PlayerRank`.

`Vi` (skills joined with `', '` via `Vi.skill`): `rankCheck(RankCheckSignal s)` → down/drills `'Kết quả tập gần đây ở $skills đang đi xuống — làm lại bài BU để kiểm tra hạng ${s.rank.label}.'`; down/matches `'Khi thi đấu gần đây, $skills đang yếu — làm lại bài BU để kiểm tra hạng ${s.rank.label}.'`; up `'Kết quả tập gần đây ở $skills đang đi lên — làm lại bài BU để thử hạng ${s.rank.label}.'`.

Placement: `RankCard` shows `RankCheckLine` under the warning line. ★ `RoadmapHomeLine` shows it under the current-step tile, and alone (inside the same `PcCard` padding) when there is no current step — the hint is about rank, not the goal.

- [ ] **Step 1: Write the failing tests**

```dart
// rank_check_test.dart  (PlayerIntelligence built with computePlayerIntelligence over roadmapDrills + sessions(...))
test('hạng chưa kiểm chứng: không gợi ý', ...);
test('bài BU gần nhất mới 27 ngày: không gợi ý; 28 ngày thì có', ...);
test('2 nhóm BU từng chấm đi xuống: gợi ý kiểm tra hạng hiện tại', () { /* a1 [9,9,5,5], p1 [9,9,5,5] → down, drills, [aiming, position], Rank.d */ });
test('chỉ 1 nhóm đi xuống: không gợi ý', ...);
test('2 nhóm yếu trong trận: gợi ý hướng xuống theo trận', ...);
test('2 nhóm đi lên, không nhóm nào đi xuống: thử hạng kế tiếp', ...);
test('đi lên nhưng một nhóm khác đi xuống: không gợi ý hướng lên', ...);
test('gợi ý không đụng tới hạng: PlayerRank đầu vào giữ nguyên', ...);  // same object, warningRank still null
// roadmap_providers_test.dart — Review Focus 4
test('trận đang tải lại với giá trị cũ: rankCheckSignalProvider là null', ...);
// rank_card_test.dart / home_screen_test.dart
testWidgets('thẻ hạng hiện gợi ý kiểm tra lại hạng', ...);  // testContainer(rank verified D, buResult: buResultGraded(completedAt: now − 30 days), logs declining, drills: roadmapDrills)
testWidgets('Trang chủ hiện gợi ý dù chưa có mục tiêu', ...);
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/roadmap/rank_check_test.dart test/features/rank test/features/home test/core/providers` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain test/core test/features test/smoke` — Expected: PASS.
- [ ] **Step 5: Commit** `"Gợi ý làm lại bài BU khi kết quả tập hoặc trận đổi chiều (không đổi hạng)"` + trailer.

---

### Task 13: No-fabrication sweep, E2E script, full suite

**Files:**
- Modify: `test/domain/no_fabrication_test.dart`
- Modify: `tool/e2e/match_drill_stats.mjs`

**Interfaces:**
- Consumes: everything above — `matchesWeakAt`, `MatchAnalysisView`, `MatchAnalysisCard`, `computeRecommendation(matches:)`, `buildCoachContext(...).toFacts()`, `buildRoadmap(matches:)`.

- [ ] **Step 1: Write the no-fabrication group** `'phân tích trận bám dữ liệu, không viết cứng (spec 2026-10-28 mục 8)'`, each case run once with `matchesWeakAt(SkillCategory.aiming, at: _today)` and once with `matchesWeakAt(SkillCategory.position, at: _today)`, asserting the output names the weak group and the two outputs differ:

```dart
test('gợi ý hôm nay đổi theo nhóm yếu trong trận', ...);              // rec.cat + Vi.pickReason(..., signal:) differ
testWidgets('thẻ Thống kê đổi theo', ...);                              // MatchAnalysisCard text differs, names the group
testWidgets('bảng Phân tích trận đổi theo', ...);                       // MatchAnalysisView over the newest match of each set
test('fact chat đổi theo', ...);                                        // toFacts()['matches']['analysis']['weak'][0]['category']
test('thứ tự bước Lộ trình Chuẩn bị giải đổi theo', ...);               // first step category; Vi.stepTitle differs
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/no_fabrication_test.dart` — Expected: PASS (all producers exist); a failure here is a real hardcoding bug, fix it in the owning file.

- [ ] **Step 3: Extend `tool/e2e/match_drill_stats.mjs`** with two steps after the existing match steps (update the header comment and step numbers; keep the throwaway-user `finally` cleanup):
  - Match C, race-to 3 (`'Chạm 3 ván thắng'`): rack 1 recorded with shots via "Ghi cú đánh" — player Phá / Có bi, player Cú thường / Trượt, opponent Cú thường / Có bi — then "Đối thủ thắng ván"; then two more "Đối thủ thắng ván". Click `'Phân tích trận'` near C's player name; check the text includes `'Mất 1 ván sau khi trượt cú tấn công'` (`Vi.lostRackCause`) and `'Phân tích trận'`.
  - Roadmap: register this user with `keepOnboarding: true` (or redo the questionnaire as `tool/e2e/rank.mjs` step 2 does) to get rank H; open Lộ trình, choose "Lên hạng", choose `'F'`; check `'Lên hạng: H → F'` and `'Làm lại bài BU — mốc hạng G'`.

  Run: `node --check tool/e2e/match_drill_stats.mjs` — Expected: exit 0. Do **not** run it: it writes to live Directus and needs the published build (the coordinator runs it after release).

- [ ] **Step 4: Full suite, analyze, service tests**

Run (background + Monitor every minute, report step and test counts):
`env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat analyze` — Expected: `No issues found!`
`env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test` — Expected: `All tests passed!`
`cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test` — Expected: all pass, 0 fail.
`git status --short` — Expected: only the files of this task.

- [ ] **Step 5: Commit** `"Phép thử chống bịa cho phân tích trận; E2E ghi trận có cú và mục tiêu lên 2 hạng"` + trailer.

The plan ends here. PR, CI, Directus bootstrap + verify on prod, merge, web publish and the Chrome/E2E run are the coordinator's release steps, outside this plan.
