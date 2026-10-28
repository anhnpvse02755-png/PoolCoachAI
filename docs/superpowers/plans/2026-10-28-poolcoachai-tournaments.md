# Giải đấu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A personal tournament log. Each player records the tournaments they enter, attaches matches recorded in Play to a tournament (with an optional round), sees a summary and the existing match analysis per tournament, compares play in tournaments with regular matches, and can link a "Chuẩn bị giải" goal to an upcoming tournament.

**Architecture:** A new pure-Dart module `lib/domain/tournament/` holds the model, input checks, computed status, list grouping, match summaries, the tournament-vs-regular comparison and the goal-link rule. It has no Flutter, no `Vi`, no Vietnamese literals and never touches rank. Data adds Drift v16: a new `tournament_rows` table (soft delete, `updated_at` latest wins), plus nullable `tournament_id` / `round_label` on `pool_match_rows` and `tournament_id` on `player_goal_rows`. Tournaments sync inside the existing `PracticeSyncService` (Directus `tournaments`). The UI lives in the Play branch (`/play/tournaments`, `/play/tournaments/:id`), reads gated providers in `lib/core/providers/tournament_providers.dart`, and all wording is in `Vi`.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod 3 (no codegen), Drift (SQLite; `NativeDatabase.memory` in tests), go_router, Directus REST sync, Node 24 (`deploy/directus/*.mjs`, `tool/e2e` CDP scripts).

**Spec:** `docs/superpowers/specs/2026-10-28-poolcoachai-tournaments-design.md`

## Global Constraints

- Work only in the worktree `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\tournaments` (branch `feat/tournaments`). Bash cwd resets between calls: start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/tournaments && `.
- Prefix every flutter / dart / npm command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN`, because the shell exports live secrets. Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat` and Dart is `/c/Users/anhnpv/flutter/bin/dart.bat`; neither is on PATH. Below, `$ENV` stands for that `env -u …` prefix, `$FLUTTER` for the Flutter path and `$DART` for the Dart path. Write them out in full when you run them.
- `lib/data/database/database.g.dart` is gitignored. Regenerate it with `$ENV $DART run build_runner build --delete-conflicting-outputs` in Task 1 Step 1 and after every edit to `database.dart`.
- No fabrication (README rule 1). The result note ("Thành tích") is the player's own text, shown verbatim, always next to "Kết quả do bạn ghi". Every number (wins, losses, racks, percentages, the comparison line) comes from a named, tested function over recorded matches. Too little data is stated plainly, using the match-analysis threshold `MatchAnalysisConstants.minMatches` (= 3).
- Tournaments never create or change a rank. `lib/domain/tournament/` never constructs `PlayerRank(` and never imports `rank_rules.dart`.
- `lib/domain/tournament/` imports neither `package:flutter` nor `core/strings/vi.dart` and holds no Vietnamese string literal (comments may be Vietnamese). No Vietnamese literal in `lib/features/**` or `lib/core/widgets/**`. All UI copy goes into `Vi`, using exactly the strings this plan gives.
- Spec values, verbatim: name required, trimmed, 1–80 characters; `location` ≤ 120; `result_note` ≤ 120; `round_label` ≤ 40; `end_date` (if set) ≥ `start_date`; `start_date` may be in the past. Status is computed with local dates: `sapToi` when today < start, `dangDienRa` when start ≤ today ≤ (end ?? start), else `daXong`. Start-match picker: non-deleted tournaments with start ≤ today and (end ?? start) ≥ today − 7. Edit-match picker: every non-deleted tournament. Round suggestions: "Vòng loại", "Vòng bảng", "Tứ kết", "Bán kết", "Chung kết". Comparison shows only when **each** side has ≥ 3 completed matches. Drift `schemaVersion` is 16. Directus collection `tournaments`: Player creates, reads and updates own rows, no delete.
- Goal link rule (spec §4.3): a goal's `tournament_id` is used only when all three hold: the goal is `chuanBiGiai`, the tournament exists and is not deleted, and the goal's `eventDate` equals the tournament's `start_date` (date only). Otherwise the link is ignored and everything shows as before. This rule lives in exactly one function, `linkedTournament`, and every consumer goes through it.
- A soft-deleted tournament keeps its matches' `tournament_id`. Those matches show as regular matches everywhere: no Play label, not in "Ở giải" comparisons.
- Compatibility with the shipped build: a build only ever asks Directus for an explicit `fields` list and only PATCHes keys from that list, so it never sees or overwrites fields added later. Task 3 pins this with tests that run on the unchanged code first and must stay green to the end.
- Owner vocabulary, exactly: Phá, Phòng thủ, Chết cái, Điều bi, Ngắm bi. Never write "Giao bóng" or "Scratch".
- Riverpod has no codegen. Never call `.invalidate(` or `.refresh(` in `lib/`. **Every provider that combines sources uses `gate()` from `lib/core/providers/async_gate.dart`**, so an upstream error surfaces as `AsyncError` and a source reloading with the previous account's value counts as loading. Widgets read tournament data only through the gated providers of Task 7, never `tournamentsProvider.value` directly.
- Test gotchas:
  1. Reading a provider `.future` in a test can hang silently. Use `container.listen(p, (_, _) {})`, then `settle()` (five `pumpEventQueue()`, see `test/core/providers/roadmap_providers_test.dart:50`), then `container.read(p)`.
  2. Never write an explicit type on an override list. `<Override>[…]` or `List<Override>` crashes the compiler, so leave the list literal untyped.
  3. Inside `testWidgets`, `await repo.watchX().first` hangs. Read rows with `db.select(db.table).get()`.
  4. Drift `AppDatabase.forTesting(NativeDatabase.memory())` works inside `flutter test`.
  5. The "reloading with the old value" state is `const AsyncLoading<T>().copyWithPrevious(AsyncData<T>(…))` preceded by `// ignore: invalid_use_of_internal_member` (see `test/core/providers/coach_chat_providers_test.dart:86-104`).
  6. `DateTime.utc(…) == DateTime(…)` is false even at the same instant. Compare timestamps read back from Drift with local `DateTime`s, or with `isNotNull`.
- Drift stores `DateTime` as whole seconds. Every fixed clock in tests is a whole second. Date-only values are stored as local midnight.
- No widget measures text intrinsically (`IntrinsicHeight` / `IntrinsicWidth`): Be Vietnam Pro arrives after the first frame and Flutter 3.47 keeps stale intrinsic sizes.
- The app must keep running on Android, iOS and web, so no web-only code.
- One commit per task. Subjects are in Vietnamese and end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No push, no PR, no deploy, no Directus or prod call, no APK build. Do **not** run `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` or any `tool/e2e/*.mjs`, since they hit prod. Check them with `node --check` only.
- A full-suite `flutter test` takes minutes. Run it in the background and stream the step plus pass/fail counts every minute with Monitor. Never wait silently.

## Review Focus

1. **Editing a tournament's start date after linking a goal.** The goal keeps the old `eventDate`, so the link stops matching. The Roadmap title must fall back to "Chuẩn bị giải ngày …" and the detail screen must offer "Chuẩn bị cho giải này" again, never "Đang chuẩn bị" with a wrong date. Tests: Task 2 (`linkedTournament` date mismatch), Task 10 (edit start date, then the button returns).
2. **Editing a match whose tournament was deleted.** The edit dropdown must not crash on an initial value missing from its items, and saving without touching the field keeps `tournament_id` and `round_label` (spec §4.2). Switching to another deleted tournament is refused. Tests: Task 5 (repository), Task 8 (dialog).
3. **Date-only values across time zones and Directus.** `start_date` / `end_date` travel as `YYYY-MM-DD` strings (Directus type `date`) and come back as the same local calendar day, also when Directus returns a full timestamp. Tests: Task 4 (`toRemoteDate` / `fromRemoteDate`), Task 6 (pull keeps the day).
4. **Starting a match from an old tournament's detail page.** That tournament is outside the 7-day picker window, so the start dialog must still contain it as the preselected item instead of asserting. Tests: Task 2 (`pickableForNewMatch(include:)`), Task 10 (start from a tournament that ended 20 days ago).
5. **Shared device, user switch.** Signing out deletes that player's `tournament_rows`, and unsynced tournaments count toward the sign-out warning. A reloading `tournamentsProvider` that still holds the previous account's tournaments makes every tournament provider loading, so no previous-account name appears on Play cards or the Roadmap title. Tests: Task 4 (`signOutAndForget`, `pendingPracticeCount`), Task 7 (stale reload, error).

## Plan's calls

Where the spec is silent or leaves a choice, the plan decides. Each call is marked ★ where it applies.

1. `start_date` / `end_date` are Directus type `date`, sent as the local `YYYY-MM-DD`. A timestamp would shift the day for a player whose time zone differs from UTC.
2. Tournament sync lives in `PracticeSyncService`, next to `pool_matches` and `schedule_slots`, with the same rules: latest `updated_at` wins, deletion is a tombstone. `_syncTournaments` runs **last**, so a malformed remote tournament cannot block match sync. Pending tournaments count in `pendingPracticeCount`, and the sign-out warning copy gains "giải đấu".
3. `tournament_id` on `pool_matches` and `player_goals` is a plain Directus `string`, not a relation, like `cue_id`. Deleting a tournament never touches matches or goals.
4. "Bắt đầu trận trong giải" shows whenever start ≤ today (spec §5.3), also for long-finished tournaments, since the spec allows logging old tournaments. Its dialog lists `pickableForNewMatch(…, include: t.id)`: the 7-day window plus the preselected tournament. Started from Play, only the 7-day window applies.
5. After a match is started from the detail screen, the app goes to `/play`, where racks and shots are recorded. The detail screen has no scoring controls.
6. On the detail screen, tapping a completed match opens the existing analysis sheet. Tapping a match in progress goes to `/play`.
7. Summary, list records and comparison count **completed** matches only, and the racks of those matches only.
8. When a tournament has a game type, it fills the game-type field when the start dialog opens with it preselected, and again whenever the player picks it in the dropdown. The player can still change it.
9. The edit dialog shows "Không thuộc giải nào" for a match whose tournament is deleted. Unless the player changes the dropdown, saving sends the original `tournamentId` and `roundLabel` unchanged.
10. Round label: trimmed, empty becomes `null`, and it is dropped when the match has no tournament. The field is hidden until a tournament is chosen. The tournament field is hidden when there is nothing to pick, like the cue field.
11. Lengths are counted as Unicode code points (`runes`) after trimming. Notes are capped at 500 (spec silent). Text fields also set `maxLength`.
12. Ordering: "Đang diễn ra" by start ascending; "Sắp tới" by start ascending (nearest first); "Đã xong" by (end ?? start) descending, then start descending. Ties go by `id`. The Play card shows the first ongoing tournament, else the first upcoming one, else "Chưa có giải nào". Empty sections are hidden.
13. `PlayerGoal.tournamentId` is stored and synced verbatim, with no constructor assert, because shipped builds can leave a stale value. `RoadmapRepository.setGoal` stores it only for `chuanBiGiai`, and `toRemoteGoal` always sends the key (null included), so the new build clears a stale link whenever it writes the goal.
14. The replace-goal confirmation is a dialog that reuses the goal picker's wording: actions `Vi.goalCancelChange` / `Vi.goalChange`, body naming the current goal kind.
15. The detail "Phân tích" reuses `MatchAnalysisCard` over **all** of the tournament's completed matches (`limit` = their count, not the recent-10 window), with an optional title. Thresholds are unchanged.
16. In the live E2E, the upcoming tournament is created with a Directus REST POST as the throwaway user and then pulled by reloading the app. The Material date picker cannot be driven reliably through CDP, and this also proves tournament pull sync on prod.
17. A detail URL for a deleted or unknown id shows a not-found state, not an error.
18. Running `bootstrap.mjs` then `verify.mjs` on prod before the web publish (spec §4.4) is a coordinator release step outside this plan. Until it has run, the new build's PATCHes carrying `tournament_id` would be refused by field permissions.

---

### Task 1: Tournament model, input check, status and lists

**Files:**
- Create: `lib/domain/tournament/tournament.dart`
- Create: `lib/domain/tournament/tournament_lists.dart`
- Create: `test/support/tournament_fixtures.dart`
- Create: `test/domain/tournament/tournament_test.dart`
- Modify: `test/architecture_test.dart` (append one test after the Skill Test core test at :342-368)

**Interfaces:**
- Consumes: `PoolGameType` (`lib/domain/pool_match.dart`), `dateOnly(DateTime)` (`lib/domain/roadmap/pace.dart:8`).
- Produces (`tournament.dart`):
  - `abstract final class TournamentConstants { static const nameMaxLength = 80; static const locationMaxLength = 120; static const resultNoteMaxLength = 120; static const notesMaxLength = 500; static const roundLabelMaxLength = 40; static const recentDays = 7; }`
  - `enum TournamentStatus { sapToi, dangDienRa, daXong }`
  - `final class Tournament { const Tournament({required String id, required String name, required DateTime startDate, DateTime? endDate, String? location, PoolGameType? gameType, String? resultNote, String? notes}); DateTime get lastDay /* endDate ?? startDate */; }`, with `==`, `hashCode` and `toString` over every field.
  - `final class TournamentDraft { const TournamentDraft({required String name, required DateTime startDate, DateTime? endDate, String? location, PoolGameType? gameType, String? resultNote, String? notes}); }`
  - `enum TournamentInputError { nameRequired, nameTooLong, endBeforeStart, locationTooLong, resultNoteTooLong, notesTooLong }`
  - `Set<TournamentInputError> tournamentInputErrors(TournamentDraft d)`. Lengths are `trim().runes.length` (★ call 11). Empty name after trim gives `nameRequired`. Dates compare with `dateOnly`. Optional texts that are null or blank are never errors. It returns every error, not only the first.
  - `TournamentStatus tournamentStatus(Tournament t, DateTime today)`, comparing `dateOnly` values.
  - `String? trimmedOrNull(String? raw)`: trimmed, or `null` when null or blank.
  - `bool roundLabelValid(String? label)`: `true` for null or blank, else trimmed rune length ≤ `roundLabelMaxLength`.
- Produces (`tournament_lists.dart`, ★ call 12):
  - `typedef TournamentGroups = ({List<Tournament> dangDienRa, List<Tournament> sapToi, List<Tournament> daXong});`
  - `TournamentGroups groupTournaments(Iterable<Tournament> ts, DateTime today)`
  - `Tournament? featuredTournament(Iterable<Tournament> ts, DateTime today)`
  - `List<Tournament> pickableForNewMatch(Iterable<Tournament> ts, DateTime today, {String? include})`: start ≤ today and `lastDay` ≥ today − `recentDays` (date only), plus the tournament whose id is `include` when it is in `ts`, without duplicates. Sorted by start descending, then id.
  - `List<Tournament> pickableForEdit(Iterable<Tournament> ts)`: all of `ts`, start descending, then id.
- Produces (fixtures, `test/support/tournament_fixtures.dart`; later tasks use these names):
  - `final tToday = DateTime(2026, 10, 28, 10);`
  - `DateTime tDay(int offset) => DateTime(2026, 10, 28 + offset);`
  - `Tournament tour(String id, {required DateTime start, DateTime? end, String? name, PoolGameType? gameType, String? location, String? resultNote, String? notes})`, with name defaulting to `'Giải $id'`.

- [ ] **Step 1: Setup.** Run `$ENV $FLUTTER pub get`, then `$ENV $DART run build_runner build --delete-conflicting-outputs`. Expected: both exit 0.

- [ ] **Step 2: Write the failing tests** in `test/domain/tournament/tournament_test.dart`:

```dart
TournamentDraft draft({String name = 'Giải Q1', DateTime? start, DateTime? end, String? location, String? result, String? notes}) =>
    TournamentDraft(name: name, startDate: start ?? tDay(0), endDate: end, location: location, resultNote: result, notes: notes);

group('tournamentStatus — tính theo ngày địa phương', () {
  test('trước ngày bắt đầu là sắp tới', () => expect(tournamentStatus(tour('a', start: tDay(1)), tToday), TournamentStatus.sapToi));
  test('hôm nay là ngày bắt đầu: đang diễn ra từ 00:00 tới 23:59', () {
    final t = tour('a', start: tDay(0));
    expect(tournamentStatus(t, DateTime(2026, 10, 28)), TournamentStatus.dangDienRa);
    expect(tournamentStatus(t, DateTime(2026, 10, 28, 23, 59)), TournamentStatus.dangDienRa);
  });
  test('không có ngày kết thúc: ngày hôm sau là đã xong', () =>
      expect(tournamentStatus(tour('a', start: tDay(-1)), tToday), TournamentStatus.daXong));
  test('hôm nay là ngày kết thúc: vẫn đang diễn ra; hôm sau là đã xong', () {
    final t = tour('a', start: tDay(-2), end: tDay(0));
    expect(tournamentStatus(t, tToday), TournamentStatus.dangDienRa);
    expect(tournamentStatus(t, DateTime(2026, 10, 29, 0, 1)), TournamentStatus.daXong);
  });
});

group('tournamentInputErrors', () {
  test('hợp lệ, kể cả giải ở quá khứ và tên có khoảng trắng hai đầu', () {
    expect(tournamentInputErrors(draft(name: '  Giải Hà Nội  ', start: tDay(-300))), isEmpty);
    expect(tournamentInputErrors(draft(name: '  ${'x' * 80}  ')), isEmpty);
  });
  test('tên rỗng hoặc chỉ khoảng trắng', () => expect(tournamentInputErrors(draft(name: '   ')), {TournamentInputError.nameRequired}));
  test('tên 81 ký tự', () => expect(tournamentInputErrors(draft(name: 'x' * 81)), {TournamentInputError.nameTooLong}));
  test('ngày kết thúc trước ngày bắt đầu; cùng ngày (khác giờ) là hợp lệ', () {
    expect(tournamentInputErrors(draft(start: tDay(0), end: tDay(-1))), {TournamentInputError.endBeforeStart});
    expect(tournamentInputErrors(draft(start: DateTime(2026, 10, 28, 20), end: DateTime(2026, 10, 28, 8))), isEmpty);
  });
  test('địa điểm, thành tích quá 120, ghi chú quá 500; báo đủ mọi lỗi', () {
    expect(tournamentInputErrors(draft(name: '', location: 'x' * 121, result: 'x' * 121, notes: 'x' * 501)), {
      TournamentInputError.nameRequired, TournamentInputError.locationTooLong,
      TournamentInputError.resultNoteTooLong, TournamentInputError.notesTooLong,
    });
    expect(tournamentInputErrors(draft(location: 'x' * 120, result: 'x' * 120, notes: 'x' * 500)), isEmpty);
  });
});

test('trimmedOrNull và roundLabelValid', () {
  expect([trimmedOrNull('  Tứ kết '), trimmedOrNull('   '), trimmedOrNull(null)], ['Tứ kết', null, null]);
  expect([roundLabelValid(null), roundLabelValid('x' * 40), roundLabelValid(' ${'x' * 40} '), roundLabelValid('x' * 41)],
      [true, true, true, false]);
});

final all = [
  tour('up2', start: tDay(5)), tour('up1', start: tDay(2)), tour('on', start: tDay(-1), end: tDay(1)),
  tour('old', start: tDay(-20)), tour('recent', start: tDay(-5), end: tDay(-3)),
];
test('chia ba nhóm, đúng thứ tự', () {
  final g = groupTournaments(all, tToday);
  expect(g.dangDienRa.map((t) => t.id), ['on']);
  expect(g.sapToi.map((t) => t.id), ['up1', 'up2']);
  expect(g.daXong.map((t) => t.id), ['recent', 'old']);
});
test('giải nổi bật: đang diễn ra (bắt đầu sớm nhất), không thì sắp tới gần nhất, không thì null', () {
  expect(featuredTournament([...all, tour('on0', start: tDay(-2), end: tDay(0))], tToday)!.id, 'on0');
  expect(featuredTournament(all.where((t) => t.id != 'on'), tToday)!.id, 'up1');
  expect(featuredTournament([tour('old', start: tDay(-20))], tToday), isNull);
});
group('pickableForNewMatch — biên 7 ngày', () {
  test('đã bắt đầu và kết thúc trong 7 ngày gần đây, mới nhất trước', () {
    final ts = [
      tour('end7', start: tDay(-9), end: tDay(-7)), tour('end8', start: tDay(-9), end: tDay(-8)),
      tour('noEnd7', start: tDay(-7)), tour('noEnd8', start: tDay(-8)),
      tour('today', start: tDay(0)), tour('tomorrow', start: tDay(1)),
    ];
    expect(pickableForNewMatch(ts, tToday).map((t) => t.id), ['today', 'noEnd7', 'end7']);
  });
  // Review Focus 4
  test('include thêm giải cũ được chọn sẵn, không trùng, id lạ bị bỏ qua', () {
    expect(pickableForNewMatch(all, tToday, include: 'old').map((t) => t.id), ['on', 'recent', 'old']);
    expect(pickableForNewMatch(all, tToday, include: 'on').map((t) => t.id), ['on', 'recent']);
    expect(pickableForNewMatch(all, tToday, include: 'zz').map((t) => t.id), ['on', 'recent']);
  });
});
test('pickableForEdit: mọi giải, mới nhất trước', () =>
    expect(pickableForEdit(all).map((t) => t.id), ['up2', 'up1', 'on', 'recent', 'old']));
```

Append to `test/architecture_test.dart`: `test('lõi Giải đấu không phụ thuộc Flutter, không dùng Vi, không có chuỗi tiếng Việt, không đụng hạng', …)`. It runs over `dartFilesIn('lib/domain/tournament')` and expects the list to be non-empty. For each file, `codeOnly(source)` must not contain `package:flutter`, `core/strings/vi.dart`, `PlayerRank(` or `rank_rules.dart`, and must have no `vietnameseLiteral` match. The reason is `'giải đấu chỉ trả enum, số đếm và chữ người chơi tự ghi; câu chữ nằm ở Vi; giải không đổi hạng (spec giải đấu mục 3)'`.

- [ ] **Step 3: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/domain/tournament/tournament_test.dart test/architecture_test.dart`. Expected: FAIL because `tournament.dart` is not found, and the new architecture test fails because `lib/domain/tournament` does not exist.
- [ ] **Step 4: Implement** both domain files and the fixtures as in the Interfaces block.
- [ ] **Step 5: Run the same command.** Expected: PASS.
- [ ] **Step 6: Commit** `lib/domain/tournament test/support/tournament_fixtures.dart test/domain/tournament test/architecture_test.dart` with the message `"Giải đấu: mô hình, kiểm tra dữ liệu nhập, trạng thái theo ngày, nhóm và danh sách chọn"` plus the trailer.

---

### Task 2: Matches and goals point at a tournament; summaries, comparison, goal link

**Files:**
- Modify: `lib/domain/pool_match.dart` (`PoolMatch`: two fields)
- Modify: `lib/domain/roadmap/goal.dart` (`PlayerGoal`: one field, plus `==`, `hashCode`, `toString`)
- Create: `lib/domain/tournament/tournament_results.dart`
- Create: `lib/domain/tournament/tournament_goal.dart`
- Modify: `test/support/tournament_fixtures.dart` (add `tMatch` and `prepGoal`)
- Create: `test/domain/tournament/tournament_results_test.dart`, `test/domain/tournament/tournament_goal_test.dart`

**Interfaces:**
- Consumes: Task 1, `percentOf` and `MatchAnalysisConstants.minMatches` (`lib/domain/match_analysis/`), `GoalKind`, `PlayerGoal`, `dateOnly`.
- Produces:
  - `PoolMatch` gains `this.tournamentId` and `this.roundLabel` (both `String?`, optional named, default null), documented as "giữ nguyên cả khi giải bị xóa mềm".
  - `PlayerGoal` gains `this.tournamentId` (`String?`, optional, **no assert**, ★ call 13), and it is included in `==`, `hashCode` and `toString`.
  - `tournament_results.dart`:
    - `bool playerWon(PoolMatch m)`: `m.isComplete && m.playerScore >= m.targetRacks`.
    - `final class TournamentSummary { const TournamentSummary({required int matchesWon, required int matchesLost, required int racksWon, required int racksLost}); static const empty = TournamentSummary(matchesWon: 0, matchesLost: 0, racksWon: 0, racksLost: 0); int get completedMatches; int? get rackWinPercent /* percentOf(racksWon, racksWon + racksLost) */; }`, with `==` and `hashCode`.
    - `TournamentSummary summarizeMatches(Iterable<PoolMatch> matches)`: completed matches only, and their racks only (★ call 7).
    - `List<PoolMatch> matchesOfTournament(String tournamentId, Iterable<PoolMatch> matches)`: sorted by `startedAt` ascending, then `id`.
    - `Tournament? tournamentOf(PoolMatch m, Map<String, Tournament> liveById)`: `null` when `m.tournamentId` is null or not live.
    - `Map<String, TournamentSummary> summariesByTournament(Iterable<Tournament> live, Iterable<PoolMatch> matches)`: one entry per live tournament, `TournamentSummary.empty` when it has no completed match.
    - `final class TournamentComparison { const TournamentComparison({required TournamentSummary inTournaments, required TournamentSummary regular}); bool get enough; }`. `enough` means both sides have `completedMatches >= MatchAnalysisConstants.minMatches` and non-null `rackWinPercent`.
    - `TournamentComparison compareTournamentPlay(Iterable<PoolMatch> matches, Iterable<Tournament> live)`. A match is "in a tournament" only when `tournamentOf` is non-null, so a match of a deleted tournament counts as regular.
    - `typedef TournamentView = ({Tournament tournament, List<PoolMatch> matches, TournamentSummary summary});`
    - `TournamentView? tournamentView(String id, Iterable<Tournament> live, Iterable<PoolMatch> matches)`: `null` when `id` is not live. `matches` comes from `matchesOfTournament`.
  - `tournament_goal.dart`:
    - `Tournament? linkedTournament(PlayerGoal? goal, Iterable<Tournament> live)`: the triple condition of spec §4.3 (Global Constraints).
    - `enum TournamentGoalState { notUpcoming, linked, otherGoal, noGoal }`
    - `TournamentGoalState tournamentGoalState(Tournament t, {required PlayerGoal? goal, required Iterable<Tournament> live, required DateTime today})`, checked in order: status ≠ `sapToi` gives `notUpcoming`; `linkedTournament(goal, live)?.id == t.id` gives `linked`; a non-null `goal` gives `otherGoal`; otherwise `noGoal`.
  - Fixtures added to `test/support/tournament_fixtures.dart` (later tasks use these names):
    - `PoolMatch tMatch(String id, {String? tournamentId, String? round, int won = 3, int lost = 1, int? target, DateTime? at})`. `rackWinners` is `won` × player then `lost` × opponent, and `targetRacks` is `target ?? max(won, lost)`. It is complete when either side reaches the target. `startedAt` is `at ?? tToday`, `completedAt` is `startedAt + 1 h` when complete, else null. Player `'An'`, opponent `'Đối thủ $id'`, `nineBall`, `tournamentId`, `roundLabel: round`.
    - `PlayerGoal prepGoal(DateTime eventDate, {String? tournamentId})`: `chuanBiGiai`, goalId `'g'`, `createdAt: tToday`.

- [ ] **Step 1: Write the failing tests.**

`tournament_results_test.dart`:

```dart
test('tổng kết chỉ tính trận hoàn tất và ván của chúng', () {
  final s = summarizeMatches([tMatch('w', won: 3, lost: 1), tMatch('l', won: 2, lost: 3), tMatch('live', won: 1, lost: 0, target: 3)]);
  expect([s.matchesWon, s.matchesLost, s.racksWon, s.racksLost, s.completedMatches, s.rackWinPercent], [1, 1, 5, 4, 2, 56]);
  expect(summarizeMatches(const []), TournamentSummary.empty);
  expect(TournamentSummary.empty.rackWinPercent, isNull);
});
test('trận của một giải, theo giờ bắt đầu', () {
  final ms = [tMatch('b', tournamentId: 't1', at: tDay(0)), tMatch('a', tournamentId: 't1', at: tDay(-1)), tMatch('x', tournamentId: 't2')];
  expect(matchesOfTournament('t1', ms).map((m) => m.id), ['a', 'b']);
});
test('giải đã xóa thì trận hiện như trận thường', () {
  final live = {'t1': tour('t1', start: tDay(-1))};
  expect(tournamentOf(tMatch('a', tournamentId: 't1'), live)!.id, 't1');
  expect(tournamentOf(tMatch('b', tournamentId: 'gone'), live), isNull);
  expect(tournamentOf(tMatch('c'), live), isNull);
});
group('so sánh giải với trận thường — ngưỡng 3 trận mỗi bên', () {
  final live = [tour('t1', start: tDay(-3))];
  List<PoolMatch> inT(int n) => [for (var i = 0; i < n; i++) tMatch('t$i', tournamentId: 't1', won: 3, lost: 0)];
  List<PoolMatch> regular(int n) => [for (var i = 0; i < n; i++) tMatch('r$i', won: 1, lost: 3)];
  test('đủ mỗi bên: hai tỷ lệ ván thắng; trận của giải đã xóa tính là trận thường, trận dở không tính', () {
    final c = compareTournamentPlay([...inT(3), ...regular(2), tMatch('g', tournamentId: 'gone', won: 1, lost: 3),
        tMatch('live', tournamentId: 't1', won: 0, lost: 2, target: 3)], live);
    expect([c.enough, c.inTournaments.completedMatches, c.inTournaments.rackWinPercent, c.regular.completedMatches, c.regular.rackWinPercent],
        [true, 3, 100, 3, 25]);
  });
  test('một bên chỉ có 2 trận: chưa đủ', () {
    expect(compareTournamentPlay([...inT(3), ...regular(2)], live).enough, isFalse);
    expect(compareTournamentPlay([...inT(2), ...regular(3)], live).enough, isFalse);
  });
});
test('tournamentView: null khi giải không còn; trận theo thứ tự; tổng kết khớp', () {
  final live = [tour('t1', start: tDay(-1))];
  final v = tournamentView('t1', live, [tMatch('a', tournamentId: 't1'), tMatch('b')])!;
  expect([v.tournament.id, v.matches.map((m) => m.id).toList(), v.summary.matchesWon], ['t1', ['a'], 1]);
  expect(tournamentView('gone', live, const []), isNull);
  expect(summariesByTournament(live, const []), {'t1': TournamentSummary.empty});
});
```

`tournament_goal_test.dart`:

```dart
final up = tour('up', start: tDay(5));
group('linkedTournament — đủ ba điều kiện', () {
  test('chuẩn bị giải, giải còn, cùng ngày (khác giờ vẫn là cùng ngày)', () {
    expect(linkedTournament(prepGoal(tDay(5), tournamentId: 'up'), [up]), up);
    expect(linkedTournament(prepGoal(DateTime(2026, 11, 2, 18), tournamentId: 'up'), [up]), up);
  });
  // Review Focus 1
  test('lệch ngày (đổi ngày giải sau khi đặt mục tiêu): bỏ liên kết', () =>
      expect(linkedTournament(prepGoal(tDay(6), tournamentId: 'up'), [up]), isNull));
  test('giải đã xóa: bỏ liên kết', () => expect(linkedTournament(prepGoal(tDay(5), tournamentId: 'up'), const []), isNull));
  test('sai loại (bản cũ để sót tournament_id): bỏ liên kết', () {
    final stale = PlayerGoal(goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: tToday, tournamentId: 'up');
    expect(linkedTournament(stale, [up]), isNull);
  });
  test('không có mục tiêu hoặc không có tournament_id', () {
    expect(linkedTournament(null, [up]), isNull);
    expect(linkedTournament(prepGoal(tDay(5)), [up]), isNull);
  });
});
test('trạng thái nút Chuẩn bị cho giải này', () {
  TournamentGoalState s(Tournament t, PlayerGoal? g) => tournamentGoalState(t, goal: g, live: [up, t], today: tToday);
  expect(s(tour('on', start: tDay(0)), null), TournamentGoalState.notUpcoming);
  expect(s(up, prepGoal(tDay(5), tournamentId: 'up')), TournamentGoalState.linked);
  expect(s(up, prepGoal(tDay(5))), TournamentGoalState.otherGoal);
  expect(s(up, null), TournamentGoalState.noGoal);
});
test('PlayerGoal so sánh cả tournamentId', () => expect(prepGoal(tDay(5), tournamentId: 'a') == prepGoal(tDay(5), tournamentId: 'b'), isFalse));
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/domain/tournament`. Expected: FAIL because the new files and fields are missing.
- [ ] **Step 3: Implement** as in the Interfaces block, including the two fixtures.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/domain test/architecture_test.dart`. Expected: PASS, including every existing roadmap and match-analysis test.
- [ ] **Step 5: Commit** with `"Giải đấu: trận và mục tiêu trỏ tới giải, tổng kết, so sánh với trận thường, luật nối mục tiêu"` plus the trailer.

---

### Task 3: Proof that the shipped build ignores the new fields

This task pins the spec's compatibility requirement (§4.4) **before** any data-layer change. Its tests are characterization tests: they must PASS on the unchanged data layer, and they must still PASS at the end of the plan. They compare only fields the shipped build knows, and they state the general invariant (explicit `fields` lists, PATCH keys inside that list) instead of today's list.

**Files:**
- Create: `test/data/sync/old_build_compat_test.dart`

**Interfaces:**
- Consumes: `PracticeSyncService`, `poolMatchRemoteFields` (`lib/data/sync/practice_sync.dart`), `RoadmapSyncService`, `goalFromRemote`, `remoteGoalFields`, `toGoalRow`, `toRemoteGoal` (`lib/data/database/roadmap_converters.dart`), `DriftMatchRepository`, `RoadmapRepository`, `FakeDirectus`, `FakeAuthRepository`.
- Produces: nothing new in `lib/`.

- [ ] **Step 1: Write the tests.** In `setUp`, register `GET /items/{pool_matches,timer_sessions,schedule_slots,tournaments}` returning `[]`. `tournaments` is unused today, but registering it keeps the file green after Task 6. Also register `GET /items/player_goals`, `GET /items/achievements`, `POST /items/achievements`, and `PATCH /items/player_goals/u1` echoing the body.

```dart
List<Object?> shippedGoal(GoalRecord r) => [r.updatedAt, r.goal?.goalId, r.goal?.kind, r.goal?.category,
    r.goal?.eventDate, r.goal?.createdAt, r.goal?.targetRank];
const goalJson = {'id': 'u1', 'goal_id': 'g1', 'kind': 'chuanBiGiai', 'category': null,
    'event_date': '2026-11-01T17:00:00.000Z', 'created_at': '2026-10-28T03:00:00.000Z',
    'updated_at': '2026-10-28T03:00:00.000Z', 'target_rank': null};
Map<String, Object?> matchJson({Map<String, Object?> extra = const {}}) => {
  'id': 'm1', 'user_created': 'u1', 'game_type': 'nineBall', 'player_name': 'An', 'opponent_name': 'Bình',
  'target_racks': 3, 'rack_winners': ['player'], 'shots': <Object?>[], 'cue_id': null,
  'started_at': '2026-10-21T08:00:00.000Z', 'completed_at': null, 'updated_at': '2026-10-21T08:00:00.000Z',
  'is_deleted': false, ...extra,
};

test('goalFromRemote bỏ qua tournament_id và trường lạ', () {
  expect(shippedGoal(goalFromRemote({...goalJson, 'tournament_id': 't1', 'x_future_field': 1})),
      shippedGoal(goalFromRemote(goalJson)));
});
test('kéo trận mang tournament_id, round_label và trường lạ: lưu đủ các cột bản cũ biết', () async {
  server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
    matchJson(extra: {'tournament_id': 't1', 'round_label': 'Tứ kết', 'x_future_field': true}),
  ]);
  expect(await service().syncNow(), SyncOutcome.done);
  final r = await db.select(db.poolMatchRows).getSingle();
  expect([r.id, r.userId, r.gameType, r.playerName, r.opponentName, r.targetRacks, r.rackWinners, r.isDeleted],
      ['m1', 'u1', 'nineBall', 'An', 'Bình', 3, '["player"]', false]);
  expect(r.syncedAt, isNotNull);
});
test('mỗi lần kéo xin đúng danh sách trường của chính bản đó, không bao giờ *', () async {
  await service().syncNow();
  await roadmapService().syncNow();
  final matchFields = server.sent('GET', '/items/pool_matches').single.url.queryParameters['fields']!;
  final goalFields = server.sent('GET', '/items/player_goals').single.url.queryParameters['fields']!;
  expect([matchFields, goalFields], [poolMatchRemoteFields, remoteGoalFields]);
  expect([matchFields.contains('*'), goalFields.contains('*')], [false, false]);
});
test('PATCH trận chỉ gửi khoá nằm trong danh sách trường của chính bản đó', () async {
  await DriftMatchRepository(db, userId: 'u1', now: () => now).start(PoolMatch(id: 'm1', gameType: PoolGameType.nineBall,
      playerName: 'An', opponentName: 'Bình', targetRacks: 3, rackWinners: const [], startedAt: DateTime(2026, 10, 21, 8)));
  server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([matchJson()]); // updated_at cũ hơn bản trên máy
  server.routes['PATCH /items/pool_matches/m1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  await service().syncNow();
  final keys = FakeDirectus.body(server.sent('PATCH', '/items/pool_matches/m1').single).keys;
  expect(poolMatchRemoteFields.split(','), containsAll(keys));
});
test('PATCH mục tiêu chỉ gửi khoá nằm trong danh sách trường của chính bản đó', () async {
  server.routes['GET /items/player_goals'] = (_) => FakeDirectus.ok([goalJson]); // cũ hơn bản trên máy
  await RoadmapRepository(db, userId: 'u1', now: () => now, newId: () => 'g2')
      .setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2));
  await roadmapService().syncNow();
  final keys = FakeDirectus.body(server.sent('PATCH', '/items/player_goals/u1').single).keys;
  expect(remoteGoalFields.split(','), containsAll(keys));
});
```

Use `now = DateTime(2026, 10, 28, 12)` (whole second, after every remote `updated_at`). `service()` and `roadmapService()` build the two services on `db`, `FakeAuthRepository.signedIn(userId: 'u1')` and a `DirectusClient` over `server.client`, the same way `practice_sync_test.dart:37` and `roadmap_sync_test.dart:25` do.

- [ ] **Step 2: Run on the unchanged code.** Run `$ENV $FLUTTER test test/data/sync/old_build_compat_test.dart`. Expected: PASS. The shipped converters already behave this way, and this run proves it. A failure here means the premise is wrong: stop and report it, do not edit `lib/`.
- [ ] **Step 3: Commit** with `"Giải đấu: test chứng minh bản cũ bỏ qua trường mới (tournament_id, round_label)"` plus the trailer.

---

### Task 4: Drift v16, tournament converters, repository, sign-out

**Files:**
- Modify: `lib/data/database/database.dart`:
  - add `TournamentRows` after `PoolMatchRows` (:150);
  - add `TextColumn get tournamentId` and `TextColumn get roundLabel` (both `text().nullable()()`) to `PoolMatchRows` after `cueId` (:137);
  - add `TextColumn get tournamentId => text().nullable()();` to `PlayerGoalRows` after `targetRank` (:298);
  - add `TournamentRows` to `@DriftDatabase(tables:)` right after `PoolMatchRows`;
  - set `schemaVersion` to 16;
  - add the migration step after :492.
- Create: `lib/data/database/tournament_converters.dart`
- Create: `lib/data/repositories/tournament_repository.dart`
- Modify: `lib/data/sync/account_actions.dart` (`signOutAndForget` :58-111, `pendingPracticeCount` :162-173)
- Modify: `lib/core/strings/vi.dart` (`signOutPendingPractice` :1870)
- Modify: `test/data/database/migration_test.dart`: change every `expect(db.schemaVersion, 15)` and the `user_version` expectation at :549 to `16`, add three tests, and add helpers `_createV15PoolMatchTable` and `_createV15PlayerGoalTable`.
- Create: `test/data/database/tournament_converters_test.dart`, `test/data/repositories/tournament_repository_test.dart`
- Modify: `test/data/sync/account_actions_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2 (`Tournament`, `TournamentDraft`, `tournamentInputErrors`, `trimmedOrNull`, `dateOnly`).
- Produces:
  - Table `TournamentRows` (`tournament_rows`) with columns `TextColumn id, userId, name`; `DateTimeColumn startDate`; `DateTimeColumn endDate` (nullable); `TextColumn location, gameType, resultNote, notes` (nullable; `gameType` holds `PoolGameType.name`); `DateTimeColumn createdAt, updatedAt`; `DateTimeColumn syncedAt` (nullable); `BoolColumn isDeleted => boolean().withDefault(const Constant(false))()`; primary key `{id}`. The doc comment reads "Giải người chơi tự ghi; xóa mềm, bản sửa mới nhất thắng khi đồng bộ (spec giải đấu §4.1)".
  - Migration step:
    ```dart
    if (from < 16) {
      // spec giải đấu §4: thêm bảng giải, thêm cột rỗng được; không đụng dữ liệu cũ.
      await m.createTable(tournamentRows);
      if (from >= 7) {
        await m.addColumn(poolMatchRows, poolMatchRows.tournamentId);
        await m.addColumn(poolMatchRows, poolMatchRows.roundLabel);
      }
      if (from >= 4) await m.addColumn(playerGoalRows, playerGoalRows.tournamentId);
    }
    ```
  - `tournament_converters.dart`:
    - `Tournament toTournament(TournamentRow r)`. `gameType` goes through `PoolGameType.values.asNameMap()[r.gameType]`, so an unknown name becomes null.
    - `String toRemoteDate(DateTime d)`: `'YYYY-MM-DD'` from the local year, month and day, zero-padded (★ call 1).
    - `DateTime fromRemoteDate(Object? value)`: requires a `String` matching `^(\d{4})-(\d{2})-(\d{2})`. Anything after the date (a time part) is ignored. Returns `DateTime(y, m, d)`, and throws `FormatException` otherwise.
    - `const tournamentRemoteFields = 'id,user_created,name,start_date,end_date,location,game_type,result_note,notes,created_at,updated_at,is_deleted';`
    - `Map<String, Object?> toRemoteTournament(TournamentRow r)`: exactly the keys of `tournamentRemoteFields` minus `user_created`. Dates go through `toRemoteDate`, `created_at` / `updated_at` through `toUtc().toIso8601String()`.
    - `TournamentRowsCompanion tournamentFromRemote(Map<String, Object?> j, {required String userId, required DateTime syncedAt})`. It throws `FormatException` when `id` or `name` is not a non-empty `String`, when either date fails to parse, when `created_at` / `updated_at` is not a `String`, or when `is_deleted` is not a `bool`. An unknown `game_type` is stored as null. Timestamps go through `DateTime.parse(...).toLocal()`. Every column is present (`Value(null)` included), so an older local copy is fully overwritten.
  - `tournament_repository.dart`:
    - `class TournamentRepository { TournamentRepository(this._db, {required this._userId, required this._now, required this._newId}); }`, the same constructor shape as `RoadmapRepository`, with these members:
      - `Stream<List<Tournament>> watchAll()`: rows of `_userId` with `isDeleted == false`, ordered by `startDate` descending, then `id` ascending.
      - `Future<String> create(TournamentDraft draft)`: throws `ArgumentError.value(errors)` **before** writing when `tournamentInputErrors(draft)` is non-empty. Otherwise it inserts `id: _newId()`, the trimmed name, `dateOnly` dates, `trimmedOrNull` texts, `gameType?.name`, `createdAt` and `updatedAt` set to `_now()`, `syncedAt` null and `isDeleted` false, then returns the id.
      - `Future<void> update(String id, TournamentDraft draft)`: same validation, then writes every field. Cleared fields are written as `Value(null)`, never skipped. It sets `updatedAt: _now()` and `syncedAt: null`, and throws `StateError` when no live row of `_userId` has that id.
      - `Future<void> remove(String id)`: soft delete with `isDeleted: true`, `updatedAt: _now()`, `syncedAt: null`. Throws `StateError` when no live row of `_userId` has that id. It never touches `pool_match_rows` or `player_goal_rows`.
  - `signOutAndForget` also deletes `tournament_rows` of `userId`. `pendingPracticeCount` also adds that user's `tournament_rows` with `syncedAt IS NULL`, tombstones included.
  - `Vi.signOutPendingPractice(int count) => 'Còn $count trận, giải đấu, buổi tập tự do hoặc lịch tập chưa đồng bộ — đăng xuất bây giờ sẽ mất.'` (★ call 2).

- [ ] **Step 1: Write the failing tests.**

```dart
// migration_test.dart
test('nâng từ v15 lên v16 thêm bảng giải và cột giải ở trận, mục tiêu; giữ nguyên dữ liệu', () async {
  final executor = NativeDatabase.memory(setup: (raw) {
    _createV15PoolMatchTable(raw);   // v12 + is_deleted, kèm trận m12
    _createV15PlayerGoalTable(raw);  // v13 + target_rank
    raw.execute("INSERT INTO player_goal_rows VALUES ('u1', 'g1', 'chuanBiGiai', NULL, 1762000000, 1760400000, 1760400000, NULL, NULL);");
    raw.execute('PRAGMA user_version = 15;');
  });
  final db = AppDatabase.forTesting(executor);
  addTearDown(db.close);
  expect(db.schemaVersion, 16);
  final m = (await db.select(db.poolMatchRows).get()).single;
  expect([m.id, m.tournamentId, m.roundLabel], ['m12', null, null]);
  final g = (await db.select(db.playerGoalRows).get()).single;
  expect([g.kind, g.tournamentId], ['chuanBiGiai', null]);
  expect(await db.select(db.tournamentRows).get(), isEmpty);
  final version = await db.customSelect('PRAGMA user_version').getSingle();
  expect(version.read<int>('user_version'), 16);
});
test('nâng từ v11 lên v16: trận và mục tiêu ghi được tournament_id', () async {
  final executor = NativeDatabase.memory(setup: (raw) {
    _createV12PoolMatchTable(raw);
    _createV13PlayerGoalTable(raw);
    raw.execute('PRAGMA user_version = 11;');
  });
  final db = AppDatabase.forTesting(executor);
  addTearDown(db.close);
  await (db.update(db.poolMatchRows)).write(const PoolMatchRowsCompanion(tournamentId: Value('t1'), roundLabel: Value('Tứ kết')));
  final m = (await db.select(db.poolMatchRows).get()).single;
  expect([m.tournamentId, m.roundLabel, m.isDeleted], ['t1', 'Tứ kết', false]);
  await db.into(db.playerGoalRows).insert(PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: DateTime(2026, 10, 28), tournamentId: const Value('t1')));
  expect((await db.select(db.playerGoalRows).getSingle()).tournamentId, 't1');
});
test('tạo mới ở v16 ghi và đọc được giải', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.tournamentRows).insert(TournamentRowsCompanion.insert(id: 't1', userId: 'u1', name: 'Giải Q1',
      startDate: DateTime(2026, 11, 2), createdAt: DateTime(2026, 10, 28), updatedAt: DateTime(2026, 10, 28)));
  final r = await db.select(db.tournamentRows).getSingle();
  expect([r.name, r.startDate, r.endDate, r.isDeleted, r.syncedAt], ['Giải Q1', DateTime(2026, 11, 2), null, false, null]);
});
```

The two helpers: `_createV15PoolMatchTable` calls `_createV12PoolMatchTable(raw)` and then `ALTER TABLE pool_match_rows ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;`. `_createV15PlayerGoalTable` calls `_createV13PlayerGoalTable(raw)` and then `ALTER TABLE player_goal_rows ADD COLUMN target_rank TEXT NULL;`.

```dart
// tournament_converters_test.dart
final row = TournamentRow(id: 't1', userId: 'u1', name: 'Giải Q1', startDate: DateTime(2026, 11, 2), endDate: DateTime(2026, 11, 3),
    location: 'CLB A', gameType: 'tenBall', resultNote: 'Vào vòng 16', notes: 'n', createdAt: DateTime(2026, 10, 28, 9),
    updatedAt: DateTime(2026, 10, 28, 10), syncedAt: null, isDeleted: false);
test('dòng Drift ra miền', () => expect(toTournament(row), Tournament(id: 't1', name: 'Giải Q1', startDate: DateTime(2026, 11, 2),
    endDate: DateTime(2026, 11, 3), location: 'CLB A', gameType: PoolGameType.tenBall, resultNote: 'Vào vòng 16', notes: 'n')));
test('loại bi lạ (máy mới hơn) coi là không có', () => expect(toTournament(row.copyWith(gameType: const Value('straight'))).gameType, isNull));
// Review Focus 3
test('ngày chỉ gồm ngày: YYYY-MM-DD đi và về đúng ngày, kể cả khi máy chủ trả kèm giờ', () {
  expect([toRemoteDate(DateTime(2026, 1, 5, 23, 30)), fromRemoteDate('2026-11-02'), fromRemoteDate('2026-11-02T00:00:00')],
      ['2026-01-05', DateTime(2026, 11, 2), DateTime(2026, 11, 2)]);
  expect(() => fromRemoteDate('02/11/2026'), throwsFormatException);
  expect(() => fromRemoteDate(null), throwsFormatException);
});
test('gửi đúng các khoá của danh sách trường, không gửi chủ', () {
  final remote = toRemoteTournament(row);
  expect(remote.keys.toSet(), tournamentRemoteFields.split(',').toSet()..remove('user_created'));
  expect([remote['start_date'], remote['end_date'], remote['game_type'], remote['is_deleted']], ['2026-11-02', '2026-11-03', 'tenBall', false]);
  expect(remote['updated_at'], DateTime(2026, 10, 28, 10).toUtc().toIso8601String());
});
test('đi Directus rồi về nguyên vẹn', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.tournamentRows).insert(tournamentFromRemote({...toRemoteTournament(row), 'user_created': 'u1'},
      userId: 'u1', syncedAt: DateTime(2026, 10, 28, 11)));
  final back = await db.select(db.tournamentRows).getSingle();
  expect(toTournament(back), toTournament(row));
  expect([back.updatedAt, back.syncedAt, back.isDeleted], [DateTime(2026, 10, 28, 10), DateTime(2026, 10, 28, 11), false]);
});
test('dòng hỏng từ máy chủ thì ném', () {
  final ok = toRemoteTournament(row);
  for (final bad in [{...ok, 'name': ''}, {...ok, 'start_date': null}, {...ok, 'is_deleted': null}]) {
    expect(() => tournamentFromRemote(bad, userId: 'u1', syncedAt: DateTime(2026, 10, 28)), throwsFormatException);
  }
});
```

```dart
// tournament_repository_test.dart — db memory; `var now = DateTime(2026, 10, 28, 10); var n = 0;`
// repo = TournamentRepository(db, userId: 'u1', now: () => now, newId: () => 't${++n}'), rebuilt in setUp.
TournamentDraft d({String name = 'Giải Q1', DateTime? end, String? location}) =>
    TournamentDraft(name: name, startDate: DateTime(2026, 11, 2, 18), endDate: end, location: location, gameType: PoolGameType.nineBall);
test('tạo: cắt khoảng trắng, chỉ giữ ngày, chưa đồng bộ', () async {
  expect(await repo.create(d(name: '  Giải Q1  ', location: '   ')), 't1');
  final r = await db.select(db.tournamentRows).getSingle();
  expect([r.userId, r.name, r.startDate, r.location, r.gameType, r.createdAt, r.updatedAt, r.syncedAt, r.isDeleted],
      ['u1', 'Giải Q1', DateTime(2026, 11, 2), null, 'nineBall', DateTime(2026, 10, 28, 10), DateTime(2026, 10, 28, 10), null, false]);
});
test('dữ liệu sai thì ném, không ghi', () async {
  await expectLater(repo.create(d(name: ' ')), throwsArgumentError);
  await expectLater(repo.create(d(end: DateTime(2026, 11, 1))), throwsArgumentError);
  expect(await db.select(db.tournamentRows).get(), isEmpty);
});
test('sửa: xoá được ngày kết thúc và địa điểm, đổi updatedAt, chờ đồng bộ lại', () async {
  await repo.create(d(end: DateTime(2026, 11, 3), location: 'CLB A'));
  await (db.update(db.tournamentRows)).write(TournamentRowsCompanion(syncedAt: Value(DateTime(2026, 10, 28, 10))));
  now = DateTime(2026, 10, 28, 11);
  await repo.update('t1', d());
  final r = await db.select(db.tournamentRows).getSingle();
  expect([r.endDate, r.location, r.updatedAt, r.syncedAt], [null, null, DateTime(2026, 10, 28, 11), null]);
});
test('xóa mềm: ẩn khỏi danh sách, trận của giải giữ tournament_id', () async {
  await repo.create(d());
  await db.into(db.poolMatchRows).insert(PoolMatchRowsCompanion.insert(id: 'm1', userId: 'u1', gameType: 'nineBall', playerName: 'An',
      opponentName: 'Bình', targetRacks: 3, rackWinners: '[]', startedAt: DateTime(2026, 11, 2), tournamentId: const Value('t1')));
  await repo.remove('t1');
  final r = await db.select(db.tournamentRows).getSingle();
  expect([r.isDeleted, r.syncedAt], [true, null]);
  expect(await repo.watchAll().first, isEmpty);
  expect((await db.select(db.poolMatchRows).getSingle()).tournamentId, 't1');
  await expectLater(repo.remove('t1'), throwsStateError);
});
test('chỉ thấy và sửa được giải của mình, mới nhất trước', () async {
  await repo.create(d());
  await repo.create(TournamentDraft(name: 'Giải sau', startDate: DateTime(2026, 12, 1)));
  final other = TournamentRepository(db, userId: 'u2', now: () => now, newId: () => 'x');
  await other.create(d());
  expect((await repo.watchAll().first).map((t) => t.id), ['t2', 't1']);
  await expectLater(other.update('t1', d()), throwsStateError);
  await expectLater(other.remove('t1'), throwsStateError);
});
```

```dart
// account_actions_test.dart — Review Focus 5
test('đăng xuất xoá giải của người đó, giữ của người khác', () async { /* insert t-u1 (u1), t-u2 (u2) via TournamentRowsCompanion.insert */
  await signOutAndForget(db: db, auth: FakeAuthRepository.signedIn(userId: 'u1'), userId: 'u1', forgetChatInFlight: (_) {});
  expect((await db.select(db.tournamentRows).get()).map((r) => r.id), ['t-u2']);
});
test('giải chưa đồng bộ (kể cả đã xóa mềm) tính vào phần luyện tập', () async {
  /* u1: 'cho' syncedAt null, 'xoa' syncedAt null isDeleted true, 'da' syncedAt set; u2: 'khac' syncedAt null */
  expect(await pendingPracticeCount(db, 'u1'), 2);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/data`. Expected: FAIL because `tournamentRows` and the converters are missing.
- [ ] **Step 3: Implement** as in the Interfaces block. Then run `$ENV $DART run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/data test/features/profile`. Expected: PASS, with every existing migration test now expecting 16 and `old_build_compat_test.dart` still green.
- [ ] **Step 5: Commit** with `"Giải đấu: bảng tournament_rows (Drift v16), cột giải ở trận và mục tiêu, repository xóa mềm, xoá khi đăng xuất"` plus the trailer.

---

### Task 5: Match and goal repositories store the tournament

**Files:**
- Modify: `lib/data/repositories/match_repository.dart` (`updateDetails` in the interface and in `SignedOutMatchRepository`)
- Modify: `lib/data/repositories/drift_match_repository.dart` (`start` :93-130, `updateDetails` :133-180, `_toDomain` :353, `_toCompanion` :370)
- Modify: `lib/features/play/presentation/play_screen.dart:525-531`: pass `tournamentId: match.tournamentId, roundLabel: match.roundLabel`. Task 8 replaces this.
- Modify: `lib/data/database/roadmap_converters.dart` (`toGoalRecord`, `toGoalRow`, `remoteGoalFields`, `toRemoteGoal`, `goalFromRemote`)
- Modify: `lib/data/repositories/roadmap_repository.dart` (`setGoal` :33-55)
- Modify: `test/data/repositories/drift_match_repository_test.dart`, `test/data/database/roadmap_converters_test.dart`, `test/data/repositories/roadmap_repository_test.dart`
- Modify (signature only): `test/features/play/play_screen_test.dart` (`_FailingMatchRepository.updateDetails` :32), and every existing `updateDetails(` call in `test/data/repositories/drift_match_repository_test.dart` and `test/data/sync/practice_sync_test.dart:215`, which gain `tournamentId: null, roundLabel: null`.

**Interfaces:**
- Consumes: Task 2 (`PoolMatch.tournamentId/roundLabel`, `PlayerGoal.tournamentId`), Task 4 (`tournamentRows`, `PoolMatchRows.tournamentId/roundLabel`, `PlayerGoalRows.tournamentId`), Task 1 (`roundLabelValid`, `trimmedOrNull`).
- Produces:
  - `MatchRepository.updateDetails({required String matchId, required PoolGameType gameType, required String playerName, required String opponentName, required int targetRacks, required String? tournamentId, required String? roundLabel})`.
  - `DriftMatchRepository.start` additionally:
    - throws `ArgumentError` when `!roundLabelValid(match.roundLabel)`;
    - when `match.tournamentId != null`, throws `StateError` unless a `tournament_rows` row with that id, `userId == _userId` and `isDeleted == false` exists (checked like the cue at :106-119);
    - stores `tournamentId` and `trimmedOrNull(roundLabel)`, with the round forced to `null` when `tournamentId` is null (★ call 10).
  - `DriftMatchRepository.updateDetails` additionally:
    - validates the round the same way;
    - inside the transaction, when `tournamentId != null && tournamentId != current.tournamentId`, requires a live tournament of `_userId` (`StateError` otherwise). Keeping the current, possibly deleted, id is always allowed (★ call 9);
    - writes `tournamentId` and the normalized round.
  - `_toDomain` and `_toCompanion` carry both fields, so `watchAll()` exposes them.
  - Roadmap converters:
    - `remoteGoalFields = 'id,goal_id,kind,category,event_date,created_at,updated_at,target_rank,tournament_id'`;
    - `toRemoteGoal` always includes `'tournament_id': r.tournamentId`, null included;
    - `goalFromRemote` reads `j['tournament_id'] as String?` verbatim, whatever the kind;
    - `toGoalRecord` and `toGoalRow` carry it.
  - `RoadmapRepository.setGoal({required GoalKind kind, SkillCategory? category, DateTime? eventDate, Rank? targetRank, String? tournamentId})` stores `tournamentId` only when `kind == GoalKind.chuanBiGiai`, else `null` (★ call 13).

- [ ] **Step 1: Write the failing tests.**

```dart
// drift_match_repository_test.dart, new group; setUp: repo = DriftMatchRepository(db, userId: 'u1', now: () => DateTime(2026, 10, 20, 11))
Future<String> addTournament(String userId, String id) => TournamentRepository(db, userId: userId, now: () => DateTime(2026, 10, 20), newId: () => id)
    .create(TournamentDraft(name: 'Giải $id', startDate: DateTime(2026, 10, 20)));
PoolMatch inTournament(String id, String? tournamentId, {String? round}) => PoolMatch(id: id, gameType: PoolGameType.nineBall, playerName: 'An',
    opponentName: 'Bình', targetRacks: 2, rackWinners: const [], startedAt: DateTime(2026, 10, 20, 10), tournamentId: tournamentId, roundLabel: round);

test('bắt đầu trận trong giải: lưu giải và vòng đã cắt khoảng trắng', () async {
  await addTournament('u1', 't1');
  await repo.start(inTournament('m1', 't1', round: '  Tứ kết '));
  final m = (await repo.watchAll().first).single;
  expect([m.tournamentId, m.roundLabel], ['t1', 'Tứ kết']);
});
test('không có giải thì bỏ vòng; vòng rỗng thành null', () async {
  await repo.start(inTournament('m1', null, round: 'Tứ kết'));
  await addTournament('u1', 't1');
  await repo.start(inTournament('m2', 't1', round: '   '));
  final rows = {for (final r in await db.select(db.poolMatchRows).get()) r.id: r};
  expect([rows['m1']!.roundLabel, rows['m2']!.roundLabel], [null, null]);
});
test('giải lạ, đã xóa hoặc của người khác: không ghi', () async {
  await addTournament('u2', 'theirs');
  await addTournament('u1', 'gone');
  await TournamentRepository(db, userId: 'u1', now: () => DateTime(2026, 10, 21), newId: () => 'x').remove('gone');
  for (final t in ['nope', 'theirs', 'gone']) {
    await expectLater(repo.start(inTournament('m-$t', t)), throwsStateError);
  }
  await expectLater(repo.start(inTournament('m-long', null, round: 'x' * 41)), throwsArgumentError);
  expect(await db.select(db.poolMatchRows).get(), isEmpty);
});
test('sửa trận: chuyển giải, bỏ giải', () async {
  await addTournament('u1', 't1');
  await addTournament('u1', 't2');
  await repo.start(inTournament('m1', 't1', round: 'Bán kết'));
  Future<void> edit(String? t, String? round) => repo.updateDetails(matchId: 'm1', gameType: PoolGameType.nineBall, playerName: 'An',
      opponentName: 'Bình', targetRacks: 2, tournamentId: t, roundLabel: round);
  await edit('t2', 'Chung kết');
  var r = await db.select(db.poolMatchRows).getSingle();
  expect([r.tournamentId, r.roundLabel], ['t2', 'Chung kết']);
  await edit(null, 'Chung kết');
  r = await db.select(db.poolMatchRows).getSingle();
  expect([r.tournamentId, r.roundLabel, r.syncedAt], [null, null, null]);
});
// Review Focus 2
test('giải của trận đã bị xóa: sửa trận mà giữ nguyên giải thì được, chuyển sang giải đã xóa khác thì không', () async {
  await addTournament('u1', 'gone');
  await addTournament('u1', 'gone2');
  await repo.start(inTournament('m1', 'gone', round: 'Tứ kết'));
  final tours = TournamentRepository(db, userId: 'u1', now: () => DateTime(2026, 10, 21), newId: () => 'x');
  await tours.remove('gone');
  await tours.remove('gone2');
  await repo.updateDetails(matchId: 'm1', gameType: PoolGameType.tenBall, playerName: 'An', opponentName: 'Bình', targetRacks: 2,
      tournamentId: 'gone', roundLabel: 'Tứ kết');
  final r = await db.select(db.poolMatchRows).getSingle();
  expect([r.gameType, r.tournamentId, r.roundLabel], ['tenBall', 'gone', 'Tứ kết']);
  await expectLater(repo.updateDetails(matchId: 'm1', gameType: PoolGameType.tenBall, playerName: 'An', opponentName: 'Bình',
      targetRacks: 2, tournamentId: 'gone2', roundLabel: null), throwsStateError);
});
```

```dart
// roadmap_converters_test.dart
final linked = GoalRecord(updatedAt: at, goal: PlayerGoal(goalId: 'g9', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), createdAt: at, tournamentId: 't1'));
test('mục tiêu nối giải đi Drift và Directus rồi về nguyên vẹn', () {
  expect(toGoalRecord(toGoalRow(linked, userId: 'u1')), linked);
  final json = toRemoteGoal(toGoalRow(linked, userId: 'u1'));
  expect(json['tournament_id'], 't1');
  expect(goalFromRemote(json), linked);
});
test('luôn gửi khoá tournament_id, kể cả null, để xoá liên kết cũ trên máy chủ', () {
  expect(toRemoteGoal(toGoalRow(goal, userId: 'u1')), containsPair('tournament_id', null));
  expect(remoteGoalFields.split(','), contains('tournament_id'));
});
```

```dart
// roadmap_repository_test.dart
test('chuẩn bị giải lưu tournament_id; đổi sang mục tiêu khác thì xoá', () async {
  await repo('u1').setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), tournamentId: 't1');
  expect((await db.select(db.playerGoalRows).getSingle()).tournamentId, 't1');
  await repo('u1').setGoal(kind: GoalKind.thuanThucKyNang, category: SkillCategory.kick, tournamentId: 't1');
  expect((await db.select(db.playerGoalRows).getSingle()).tournamentId, isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/data/repositories test/data/database/roadmap_converters_test.dart`. Expected: FAIL, because the new parameters are missing (a compile error counts).
- [ ] **Step 3: Implement** as in the Interfaces block, including the signature-only test updates listed under Files.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/data test/features/play`. Expected: PASS, including `old_build_compat_test.dart`.
- [ ] **Step 5: Commit** with `"Giải đấu: trận lưu giải và vòng, mục tiêu lưu tournament_id, kiểm tra giải còn và thuộc đúng người"` plus the trailer.

---

### Task 6: Sync and Directus `tournaments`

**Files:**
- Modify: `lib/data/sync/practice_sync.dart`:
  - `poolMatchRemoteFields` (:18-20) and the match body (:218-231) and `_matchFromRemote` (:281-325) carry the two match fields;
  - add the `'tournament'` kind to `_pending` (:73-77) and a `_watch` in `start()` (:85-119);
  - add `_syncTournaments` and call it **last** in `_syncOnce` (:168-170);
  - add `_tournamentRevision`.
- Modify: `deploy/directus/bootstrap.mjs`:
  - add the `tournaments` collection after `schedule_slots` (:391-399);
  - add two fields to `pool_matches` (:368-383) and one to `player_goals` (:291-304);
  - add permissions next to `schedule_slots` (:612-628), and extend the `pool_matches` (:585-602) and `player_goals` (:519-534) field lists.
- Modify: `deploy/directus/verify.mjs`: a tournaments block as the first statements inside the `if (aId && bId) {` that opens at :184 (before the player-goals code, which needs `tour.id`), plus additions to the player-goals block (:185-260) and the pool-matches block (:354-424).
- Modify: `test/data/sync/practice_sync_test.dart` (`setUp` :30-32 adds `'tournaments'` to the GET route list; new `group('tournaments')`; one new match test), `test/data/sync/roadmap_sync_test.dart` (one test), `test/features/profile/profile_screen_test.dart` (fake routes ~:156).

**Interfaces:**
- Consumes: Task 4 (`tournamentRemoteFields`, `toRemoteTournament`, `tournamentFromRemote`, `TournamentRepository`), Task 5 (match columns, goal converters).
- Produces:
  - `poolMatchRemoteFields` ends with `…,updated_at,is_deleted,tournament_id,round_label`. The match body adds `'tournament_id': row.tournamentId, 'round_label': row.roundLabel`. `_matchFromRemote` adds `tournamentId: Value(_nullableString(item, 'tournament_id'))` and `roundLabel: Value(_nullableString(item, 'round_label'))`.
  - `_syncTournaments(String userId)` copies `_syncSlots` (:408-515) with path `/items/tournaments`, fields `tournamentRemoteFields`, rejected key `'tournament:${row.id}:${_tournamentRevision(row)}'`, body `toRemoteTournament(row)` and pull rows from `tournamentFromRemote(item, userId:, syncedAt: receivedAt)`. The rule is latest `updated_at` wins in both directions. A remote id already owned by another local account throws `FormatException`. Order: matches, timers, slots, **tournaments** (★ call 2).
  - `String _tournamentRevision(TournamentRow r) => '${r.userId}:${r.updatedAt.toIso8601String()}:${r.isDeleted}';`
  - Directus `bootstrap.mjs`:
    - `ensureCollection('tournaments', 'Giải người chơi tự ghi — xóa mềm, bản sửa mới nhất thắng', [pk, required('name', 'string'), required('start_date', 'date'), nullable('end_date', 'date'), nullable('location', 'string'), nullable('game_type', 'string'), nullable('result_note', 'string'), nullable('notes', 'text'), required('created_at', 'timestamp'), required('updated_at', 'timestamp'), required('is_deleted', 'boolean')])`.
    - `pool_matches` gains `nullable('tournament_id', 'string'), nullable('round_label', 'string')`. `player_goals` gains `nullable('tournament_id', 'string')`. Both are plain strings (★ call 3).
    - Permissions:
      - `{ collection: 'tournaments', action: 'create', fields: ['id', 'name', 'start_date', 'end_date', 'location', 'game_type', 'result_note', 'notes', 'created_at', 'updated_at', 'is_deleted'], permissions: {}, validation: {} }`
      - `{ collection: 'tournaments', action: 'read', fields: ['*'], permissions: { user_created: self } }`
      - an `update` permission with the same list minus `id` and `permissions: { user_created: self }`
      - no delete
    - Append `'tournament_id', 'round_label'` to both `pool_matches` create and update field lists, and `'tournament_id'` to both `player_goals` lists.

- [ ] **Step 1: Write the failing tests** in `practice_sync_test.dart`. Add helper `_remoteTournament(String id, {String owner = 'u1', DateTime? updatedAt, bool isDeleted = false, String startDate = '2026-11-02', String? endDate, String name = 'Giải xa'})` returning every key of `tournamentRemoteFields`. Add `TournamentRepository tournaments() => TournamentRepository(db, userId: 'u1', now: () => now, newId: () => 't1');`.

```dart
group('tournaments', () {
  test('đẩy giải chưa đồng bộ đủ trường, ngày dạng YYYY-MM-DD, rồi đánh dấu', () async {
    await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2), endDate: DateTime(2026, 11, 3),
        location: 'CLB A', gameType: PoolGameType.nineBall, resultNote: 'Vào vòng 16', notes: 'n'));
    Map<String, Object?>? sent;
    server.routes['POST /items/tournaments'] = (req) { sent = FakeDirectus.body(req); return FakeDirectus.ok({'id': 't1'}); };
    expect(await service().syncNow(), SyncOutcome.done);
    expect([sent!['id'], sent!['name'], sent!['start_date'], sent!['end_date'], sent!['location'], sent!['game_type'],
        sent!['result_note'], sent!['notes'], sent!['is_deleted']], ['t1', 'Giải Q1', '2026-11-02', '2026-11-03', 'CLB A', 'nineBall', 'Vào vòng 16', 'n', false]);
    expect(sent!.containsKey('user_created'), isFalse);
    expect((await db.select(db.tournamentRows).getSingle()).syncedAt, isNotNull);
  });
  test('xóa giải gửi tombstone bằng PATCH, không DELETE', () async {
    await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 11, 2)));
    await tournaments().remove('t1');
    server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', updatedAt: now.subtract(const Duration(hours: 1)))]);
    server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    await service().syncNow();
    expect(FakeDirectus.body(server.sent('PATCH', '/items/tournaments/t1').single)['is_deleted'], true);
    expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
  // Review Focus 3
  test('kéo giải từ máy khác: ngày về đúng ngày, đánh dấu đã đồng bộ', () async {
    server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t9', startDate: '2026-11-02', endDate: '2026-11-03')]);
    expect(await service().syncNow(), SyncOutcome.done);
    final r = await db.select(db.tournamentRows).getSingle();
    expect([r.id, r.userId, r.name, r.startDate, r.endDate, r.isDeleted], ['t9', 'u1', 'Giải xa', DateTime(2026, 11, 2), DateTime(2026, 11, 3), false]);
    expect(r.syncedAt, isNotNull);
  });
  test('bản máy chủ mới hơn thay bản trên máy; cũ hơn thì không ghi đè bản sửa trên máy', () async {
    await tournaments().create(TournamentDraft(name: 'Tên trên máy', startDate: DateTime(2026, 11, 2)));
    server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/tournaments/t1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Cũ', updatedAt: now.subtract(const Duration(hours: 1)))]);
    await service().syncNow();
    expect((await db.select(db.tournamentRows).getSingle()).name, 'Tên trên máy');
    server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t1', name: 'Mới', updatedAt: now.add(const Duration(hours: 1)))]);
    await service().syncNow();
    expect((await db.select(db.tournamentRows).getSingle()).name, 'Mới');
  });
  test('giải của tài khoản khác bị từ chối; trận đã đồng bộ trước đó vẫn lên', () async {
    await matches().start(match('m1'));
    server.routes['POST /items/pool_matches'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/tournaments'] = (_) => FakeDirectus.ok([_remoteTournament('t9', owner: 'u2')]);
    expect(await service().syncNow(), SyncOutcome.failed);
    expect((await db.select(db.poolMatchRows).getSingle()).syncedAt, isNotNull);
    expect(await db.select(db.tournamentRows).get(), isEmpty);
  });
});
test('trận mang tournament_id và round_label lên và về', () async {
  await tournaments().create(TournamentDraft(name: 'Giải Q1', startDate: DateTime(2026, 10, 21)));
  await matches().start(PoolMatch(id: 'm1', gameType: PoolGameType.nineBall, playerName: 'An', opponentName: 'Bình', targetRacks: 3,
      rackWinners: const [], startedAt: DateTime.utc(2026, 10, 21, 8), tournamentId: 't1', roundLabel: 'Tứ kết'));
  Map<String, Object?>? uploaded;
  server.routes['POST /items/pool_matches'] = (req) { uploaded = FakeDirectus.body(req); return FakeDirectus.ok({'id': 'm1'}); };
  server.routes['POST /items/tournaments'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  await service().syncNow();
  expect([uploaded!['tournament_id'], uploaded!['round_label']], ['t1', 'Tứ kết']);
  server.routes['GET /items/pool_matches'] = (_) => FakeDirectus.ok([
    {..._remoteMatch('m2', updatedAt: now.add(const Duration(hours: 1))), 'tournament_id': 't1', 'round_label': 'Bán kết'},
  ]);
  await service().syncNow();
  final m2 = await (db.select(db.poolMatchRows)..where((r) => r.id.equals('m2'))).getSingle();
  expect([m2.tournamentId, m2.roundLabel], ['t1', 'Bán kết']);
});
```

`roadmap_sync_test.dart`:

```dart
test('đẩy mục tiêu chuẩn bị giải kèm tournament_id; kéo về giữ nguyên', () async {
  serve();
  await local(GoalRecord(updatedAt: newer, goal: PlayerGoal(goalId: 'g', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), createdAt: newer, tournamentId: 't1')));
  await build().syncNow();
  expect(FakeDirectus.body(server.sent('POST', '/items/player_goals').single)['tournament_id'], 't1');
});
```

In `profile_screen_test.dart` (~:156), add `..routes['GET /items/tournaments'] = ((_) => FakeDirectus.ok([]))`.

In `verify.mjs`, with the file's own `call` / `ok` / `fail` / `note` helpers:
1. Tournaments block. Build `const tour = { id: randomUUID(), name: 'Giải verify', start_date: '2026-11-02', end_date: null, location: null, game_type: 'nineBall', result_note: 'Vào vòng 16', notes: null, created_at: '2026-10-28T03:00:00.000Z', updated_at: '2026-10-28T03:00:00.000Z', is_deleted: false }`.
   - A's POST returns 200/201 (`'A tạo được giải'`).
   - A's GET `?fields=start_date` returns `'2026-11-02'` (`'ngày giải về đúng dạng YYYY-MM-DD'`).
   - B's GET `/items/tournaments` is empty (`'B không thấy giải của A'`).
   - B's PATCH `{ name: 'Ghi đè' }` returns 403 (`'B không sửa được giải của A'`).
   - A's PATCH `{ is_deleted: true, updated_at: '2026-10-28T04:00:00.000Z' }` returns 200 (`'A xóa mềm được giải'`).
   - A's DELETE returns 403 (`'A không xóa cứng giải'`).
2. In the pool-matches block, add `tournament_id: tour.id, round_label: 'Tứ kết'` to `matchBody`. After the existing `mPatch` (which sends only `rack_winners` and `updated_at`, the way a shipped build does), A's GET `?fields=tournament_id,round_label` returns both unchanged (`'trận mang tournament_id đọc lại đúng; PATCH kiểu bản cũ (không có tournament_id) giữ liên kết'`). A GET with the shipped field list (`fields=id,game_type,updated_at`) returns no `tournament_id` key (`'bản cũ xin danh sách trường riêng nên không nhận trường mới'`).
3. In the player-goals block, A's PATCH `{ kind: 'chuanBiGiai', category: null, target_rank: null, event_date: '2026-11-02T00:00:00.000Z', tournament_id: tour.id, updated_at: '2026-10-16T04:00:00.000Z' }` returns 200. Then the shipped-build PATCH `{ event_date: '2026-11-03T00:00:00.000Z', updated_at: '2026-10-16T05:00:00.000Z' }` returns 200, and the GET `?fields=tournament_id` still returns `tour.id`. Use `note` (`'liên kết cũ còn sót sau PATCH kiểu bản cũ — app bỏ qua nhờ luật ba điều kiện'`) plus `ok` / `fail` on that value. Place this before the existing `gDropped` step.

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/data/sync`. Expected: the new tests FAIL, with no request to `/items/tournaments` and no `tournament_id` in the match body.
- [ ] **Step 3: Implement** the sync, `bootstrap.mjs` and `verify.mjs`. Then run `node --check deploy/directus/bootstrap.mjs && node --check deploy/directus/verify.mjs`. Expected: exit 0. Do **not** run them.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/data test/features/profile`. Expected: PASS, with `old_build_compat_test.dart` still green.
- [ ] **Step 5: Commit** with `"Giải đấu: đồng bộ tournaments (xóa mềm, mới nhất thắng), trường giải ở trận và mục tiêu, collection Directus và kiểm tra quyền"` plus the trailer.

---

### Task 7: Providers

**Files:**
- Create: `lib/core/providers/tournament_providers.dart`
- Modify: `test/support/test_data.dart` (`testContainer` :86-181)
- Create: `test/core/providers/tournament_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2 and 4, plus `gate()`, `currentUserIdProvider`, `appDatabaseProvider`, `nowProvider`, `matchesProvider`, `goalProvider`.
- Produces (every derived provider is gated; `today = ref.watch(nowProvider)()`):
  - `final tournamentRepositoryProvider = Provider<TournamentRepository?>`: `null` when signed out, else `TournamentRepository(db, userId:, now: ref.watch(nowProvider), newId: const Uuid().v4)`.
  - `final tournamentsProvider = StreamProvider<List<Tournament>>`: `Stream.value(const [])` when the repository is null, else `repo.watchAll()`.
  - `final tournamentsByIdProvider = Provider<AsyncValue<Map<String, Tournament>>>`, gated on `[tournaments]`.
  - `final tournamentGroupsProvider = Provider<AsyncValue<TournamentGroups>>`, gated on `[tournaments]`.
  - `final featuredTournamentProvider = Provider<AsyncValue<Tournament?>>`, gated on `[tournaments]`.
  - `final tournamentSummariesProvider = Provider<AsyncValue<Map<String, TournamentSummary>>>`, gated on `[tournaments, matches]`.
  - `final tournamentComparisonProvider = Provider<AsyncValue<TournamentComparison>>`, gated on `[tournaments, matches]`.
  - `final tournamentViewProvider = Provider.family<AsyncValue<TournamentView?>, String>`, gated on `[tournaments, matches]`.
  - `final linkedTournamentProvider = Provider<AsyncValue<Tournament?>>`, gated on `[goal, tournaments]`, giving `linkedTournament(goal.value?.goal, tournaments.value!)`.
  - `final tournamentGoalStateProvider = Provider.family<AsyncValue<TournamentGoalState?>, String>`, gated on `[goal, tournaments]`. Its value is `null` when the id is not live.
  - `testContainer({…, List<Tournament>? tournaments, AsyncValue<List<Tournament>>? tournamentsAsync})`. `tournamentsAsync` wins and uses `tournamentsProvider.overrideWithValue(...)`. Otherwise it uses `tournamentsProvider.overrideWith((ref) => Stream.value(tournaments ?? const <Tournament>[]))`. Keep the override list untyped. `dbContainer` stays as is, so it reads the real repository.

- [ ] **Step 1: Write the failing tests.**

```dart
Future<void> settle() async { for (var i = 0; i < 5; i++) { await pumpEventQueue(); } }
ProviderContainer make({List<Tournament>? ts, List<PoolMatch>? ms, GoalRecord? goal, AsyncValue<List<Tournament>>? async}) {
  final c = testContainer(tournaments: ts, matches: ms, goal: goal, tournamentsAsync: async, now: tToday);
  addTearDown(c.dispose);
  for (final p in [tournamentsByIdProvider, tournamentGroupsProvider, featuredTournamentProvider, tournamentSummariesProvider,
      tournamentComparisonProvider, linkedTournamentProvider]) { c.listen(p, (_, _) {}); }
  c.listen(tournamentViewProvider('on'), (_, _) {});
  c.listen(tournamentGoalStateProvider('up'), (_, _) {});
  return c;
}
final on = tour('on', start: tDay(-1), end: tDay(1));
final up = tour('up', start: tDay(5));

test('nhóm, giải nổi bật, tổng kết và trang giải tính từ dữ liệu', () async {
  final c = make(ts: [on, up], ms: [tMatch('a', tournamentId: 'on'), tMatch('b', tournamentId: 'on', won: 1, lost: 3)]);
  await settle();
  expect(c.read(featuredTournamentProvider).value, on);
  expect(c.read(tournamentGroupsProvider).value!.sapToi, [up]);
  expect(c.read(tournamentSummariesProvider).value!['on']!.matchesWon, 1);
  expect(c.read(tournamentViewProvider('on')).value!.matches.map((m) => m.id), ['a', 'b']);
  expect(c.read(tournamentComparisonProvider).value!.enough, isFalse);
});
test('mục tiêu nối giải sắp tới: liên kết và trạng thái nút', () async {
  final c = make(ts: [on, up], goal: GoalRecord(updatedAt: tToday, goal: prepGoal(tDay(5), tournamentId: 'up')));
  await settle();
  expect(c.read(linkedTournamentProvider).value, up);
  expect(c.read(tournamentGoalStateProvider('up')).value, TournamentGoalState.linked);
});
test('id không còn: trang giải và trạng thái nút là null, không ném', () async {
  final c = make(ts: [on]);
  await settle();
  expect([c.read(tournamentGoalStateProvider('up')).hasValue, c.read(tournamentGoalStateProvider('up')).value], [true, null]);
});
test('nguồn giải lỗi: mọi provider thành lỗi, không quay mãi', () async {
  final c = make(async: AsyncError<List<Tournament>>(StateError('hỏng'), StackTrace.empty));
  await settle();
  expect([c.read(tournamentsByIdProvider).hasError, c.read(featuredTournamentProvider).hasError,
      c.read(tournamentComparisonProvider).hasError, c.read(linkedTournamentProvider).hasError], [true, true, true, true]);
});
// Review Focus 5
test('đang tải lại còn giải của người trước: là đang tải, không lộ tên cũ', () async {
  // ignore: invalid_use_of_internal_member
  final stale = const AsyncLoading<List<Tournament>>().copyWithPrevious(AsyncData<List<Tournament>>([on]));
  final c = make(async: stale, goal: GoalRecord(updatedAt: tToday, goal: prepGoal(tDay(-1), tournamentId: 'on')));
  await settle();
  expect([c.read(tournamentsByIdProvider).isLoading, c.read(tournamentsByIdProvider).value,
      c.read(featuredTournamentProvider).value, c.read(linkedTournamentProvider).value], [true, null, null, null]);
});
test('chưa đăng nhập: không có repository, danh sách rỗng', () async {
  final c = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository(const SignedOut()))]);
  addTearDown(c.dispose);
  c.listen(tournamentsProvider, (_, _) {});
  await settle();
  expect([c.read(tournamentRepositoryProvider), c.read(tournamentsProvider).value], [null, isEmpty]);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/core/providers/tournament_providers_test.dart`. Expected: FAIL because the file is missing.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/core test/smoke`. Expected: PASS.
- [ ] **Step 5: Commit** with `"Giải đấu: provider có cổng (gate) cho danh sách, tổng kết, so sánh và liên kết mục tiêu"` plus the trailer.

---

### Task 8: Match form picks a tournament and round; Play card label

**Files:**
- Create: `lib/features/play/presentation/match_dialogs.dart`. Move the two dialogs out of `play_screen.dart` (`_startMatch` dialog :28-160, `_editMatch` dialog :420-518).
- Modify: `lib/features/play/presentation/play_screen.dart` (`_startMatch`, `_editMatch`, `_matchCard` :545-699)
- Modify: `lib/core/strings/vi.dart` (Play section, after `matchScore` :197-202)
- Modify: `test/support/rich_data.dart` (`richContainer`: tournaments plus a linked match)
- Modify: `test/features/play/play_screen_test.dart` (new `group('giải đấu trong form trận')`)

**Interfaces:**
- Consumes: Task 7 (`tournamentsByIdProvider`), Task 1 (`pickableForNewMatch`, `pickableForEdit`, `roundLabelValid`, `trimmedOrNull`), Task 5 (`updateDetails` with tournament), `defaultMatchCueId`.
- Produces:
  - `typedef MatchStartForm = ({PoolGameType gameType, String playerName, String opponentName, int targetRacks, String? cueId, String? tournamentId, String? roundLabel});`
  - `typedef MatchDetailsForm = ({PoolGameType gameType, String playerName, String opponentName, int targetRacks, String? tournamentId, String? roundLabel});`
  - `Future<MatchStartForm?> showStartMatchDialog(BuildContext context, {required List<CueEquipment> cues, required String? defaultCueId, required List<Tournament> tournaments, Tournament? preselected})`. The existing fields and keys stay unchanged. It adds:
    - **Tournament field.** Only when `tournaments` is non-empty, a `DropdownButtonFormField<String?>(key: Key('match-tournament'), isExpanded: true, labelText: Vi.matchTournament)` with items `null → Vi.matchNoTournament` plus one per tournament (`Text(t.name, overflow: TextOverflow.ellipsis)`). Its initial value is `preselected?.id`.
    - **Round field.** Only when a tournament is selected, a `TextFormField(key: Key('match-round'), labelText: Vi.matchRound, maxLength: TournamentConstants.roundLabelMaxLength, validator: roundLabelValid(v) ? null : Vi.matchRoundTooLong)` with a controller. Under it, a `Wrap` of `ActionChip(key: Key('match-round-$i'), label: Text(Vi.tournamentRoundSuggestions[i]))` that sets the controller text.
    - **Game type.** Initially `preselected?.gameType ?? PoolGameType.nineBall`. Picking a tournament with a non-null `gameType` sets it (★ call 8). Wrap the game-type dropdown in `KeyedSubtree(key: ValueKey(gameTypeRevision))` and bump the revision so `initialValue` re-applies, keeping `Key('match-game-type')` on the dropdown.
    - It returns `roundLabel: tournamentId == null ? null : trimmedOrNull(text)`. Dispose the controller after the dialog closes.
  - `Future<MatchDetailsForm?> showEditMatchDialog(BuildContext context, {required PoolMatch match, required List<Tournament> tournaments})`, using `StatefulBuilder` and keys `edit-match-tournament` / `edit-match-round`. Its initial dropdown value is `match.tournamentId` when that id is in `tournaments`, else `null`. The field shows when `tournaments` is non-empty or `match.tournamentId != null`. When the player never changes the dropdown, the result carries `match.tournamentId` and `match.roundLabel` unchanged (★ call 9). The round field shows only while a **live** tournament is selected.
  - `Future<void> startMatchFromForm(WidgetRef ref, MatchStartForm form)`: builds `PoolMatch(id: const Uuid().v4(), …, rackWinners: const [], startedAt: ref.read(nowProvider)(), cueId:, tournamentId:, roundLabel:)` and calls `ref.read(matchRepositoryProvider).start(...)`.
  - `PlayScreen._startMatch` passes `tournaments: pickableForNewMatch(byId.values, today)`, where `byId = ref.read(tournamentsByIdProvider).value ?? const {}`. `_editMatch` passes `pickableForEdit(byId.values)` and forwards both new fields to `updateDetails`.
  - `_matchCard` shows `Text(Vi.matchTournamentLabel(t.name, match.roundLabel), style: bodySmall)` right under the score when `tournamentOf(match, byId)` is non-null. `byId` comes from `ref.watch(tournamentsByIdProvider).value ?? const {}`.
  - `Vi` (exact):

```dart
static const matchTournament = 'Giải đấu';
static const matchNoTournament = 'Không thuộc giải nào';
static const matchRound = 'Vòng (không bắt buộc)';
static const tournamentRoundSuggestions = <String>['Vòng loại', 'Vòng bảng', 'Tứ kết', 'Bán kết', 'Chung kết'];
static const matchRoundTooLong = 'Vòng tối đa ${TournamentConstants.roundLabelMaxLength} ký tự.';
static String matchTournamentLabel(String name, String? round) => round == null ? name : '$name · $round';
```

  - `richContainer()` adds `tournaments`:
    - `t1`: name `'Giải Vô địch Bida Pool 9 bi Mở rộng Thành phố Hồ Chí Minh lần thứ XII'`, start `testToday − 1 d`, end `testToday + 1 d`, location `'Câu lạc bộ Bida Ngôi Sao, 123 Nguyễn Văn Linh, Quận 7'`, `nineBall`, resultNote `'Vào vòng 16 sau trận căng thẳng với hạt giống số 1'`, notes of about 200 characters;
    - `t2`: name `'Giải Cúp Mùa Đông'`, start `testToday + 10 d`.

    The existing `'match'` gains `tournamentId: 't1', roundLabel: 'Tứ kết'`.

- [ ] **Step 1: Write the failing tests** in `play_screen_test.dart`. Each opens `PlayScreen` on `dbContainer(db)` with `MaterialApp(home: PlayScreen())`, like :63-80. Tournaments are created through `TournamentRepository(db, userId: 'u1', now: () => testToday, newId: …)`.

```dart
Future<void> openStart(WidgetTester tester, AppDatabase db) async { /* pump PlayScreen on dbContainer(db), tap Vi.matchStart, enter An / Bình */ }
Future<void> pick(WidgetTester tester, Key field, String item) async {
  await tester.tap(find.byKey(field)); await tester.pumpAndSettle();
  await tester.tap(find.text(item).last); await tester.pumpAndSettle();
}

testWidgets('chọn giải và vòng gợi ý: lưu vào trận, thẻ hiện "{tên giải} · {vòng}"', (tester) async {
  await addTournament(db, 't1', 'Giải Q1', start: testToday);
  await openStart(tester, db);
  expect(find.byKey(const Key('match-round')), findsNothing);
  await pick(tester, const Key('match-tournament'), 'Giải Q1');
  await tester.tap(find.byKey(const Key('match-round-2'))); // Tứ kết
  await tester.tap(find.text(Vi.matchStartAction));
  await tester.pumpAndSettle();
  final r = await db.select(db.poolMatchRows).getSingle();
  expect([r.tournamentId, r.roundLabel], ['t1', 'Tứ kết']);
  expect(find.text(Vi.matchTournamentLabel('Giải Q1', 'Tứ kết')), findsOneWidget);
});
testWidgets('chỉ giải đã bắt đầu và kết thúc trong 7 ngày gần đây', (tester) async {
  await addTournament(db, 'up', 'Sắp tới', start: testToday.add(const Duration(days: 1)));
  await addTournament(db, 'e8', 'Xong 8 ngày', start: testToday.subtract(const Duration(days: 8)));
  await addTournament(db, 'e7', 'Xong 7 ngày', start: testToday.subtract(const Duration(days: 7)));
  await openStart(tester, db);
  await tester.tap(find.byKey(const Key('match-tournament')));
  await tester.pumpAndSettle();
  expect([find.text('Xong 7 ngày').evaluate().isEmpty, find.text('Xong 8 ngày').evaluate().isEmpty, find.text('Sắp tới').evaluate().isEmpty],
      [false, true, true]);
});
testWidgets('không có giải chọn được thì không có ô Giải đấu', (tester) async {
  await openStart(tester, db);
  expect(find.byKey(const Key('match-tournament')), findsNothing);
});
testWidgets('chọn giải có loại bi thì điền sẵn loại bi', (tester) async {
  await addTournament(db, 't1', 'Giải 10 bi', start: testToday, gameType: PoolGameType.tenBall);
  await openStart(tester, db);
  await pick(tester, const Key('match-tournament'), 'Giải 10 bi');
  await tester.tap(find.text(Vi.matchStartAction));
  await tester.pumpAndSettle();
  expect((await db.select(db.poolMatchRows).getSingle()).gameType, 'tenBall');
});
testWidgets('sửa trận: chuyển sang giải khác rồi bỏ giải', (tester) async { /* start in t1, edit → pick t2, save → t2; edit → pick Vi.matchNoTournament → null, round null */ });
// Review Focus 2
testWidgets('trận của giải đã xóa: hiện như trận thường, sửa không lỗi và vẫn giữ tournament_id', (tester) async {
  await addTournament(db, 'gone', 'Giải đã xóa', start: testToday);
  await DriftMatchRepository(db, userId: 'u1', now: () => testToday).start(PoolMatch(id: 'm1', gameType: PoolGameType.nineBall,
      playerName: 'An', opponentName: 'Bình', targetRacks: 3, rackWinners: const [], startedAt: testToday, tournamentId: 'gone', roundLabel: 'Tứ kết'));
  await TournamentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'x').remove('gone');
  /* pump PlayScreen */
  expect(find.textContaining('Giải đã xóa'), findsNothing);
  await tester.tap(find.byKey(const Key('edit-match-m1')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.enterText(find.byKey(const Key('edit-match-opponent-name')), 'Cường');
  await tester.tap(find.text(Vi.matchSaveDetails));
  await tester.pumpAndSettle();
  final r = await db.select(db.poolMatchRows).getSingle();
  expect([r.opponentName, r.tournamentId, r.roundLabel], ['Cường', 'gone', 'Tứ kết']);
});
```

`addTournament(db, id, name, {required DateTime start, PoolGameType? gameType})` is a file-level helper wrapping `TournamentRepository.create` with `newId: () => id`.

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/features/play/play_screen_test.dart`. Expected: the new tests FAIL, because there is no `match-tournament` field.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/features/play test/smoke test/architecture_test.dart`. Expected: PASS, with every existing Play test unchanged and green.
- [ ] **Step 5: Commit** with `"Giải đấu: chọn giải và vòng trong form trận, nhãn giải trên thẻ trận"` plus the trailer.

---

### Task 9: Play tournament card, tournament list and form

**Files:**
- Modify: `lib/core/router/routes.dart`: add `tournaments`, `tournamentPattern` and `tournament(id)` after `equipment` (:11), and add `tournaments` to `all` right after `equipment`. `tournamentPattern` joins `all` in Task 10.
- Modify: `lib/core/router/app_router.dart`: the Play branch (:139-146) gets `routes: [GoRoute(path: 'tournaments', builder: (_, _) => const TournamentListScreen())]`.
- Create: `lib/features/play/presentation/tournament_play_card.dart`, `lib/features/play/presentation/tournament_list_screen.dart`, `lib/features/play/presentation/tournament_form.dart`
- Modify: `lib/features/play/presentation/play_screen.dart`: `const TournamentPlayCard(), const SizedBox(height: 12),` as the first children of the data `ListView` (:719-721).
- Modify: `lib/core/strings/vi.dart` (new section `// ─── Giải đấu (spec 2026-10-28) ───` after the Play/match-analysis block, ~:233)
- Modify: `test/core/router/routes_test.dart`, `test/support/route_cases.dart`
- Create: `test/features/play/tournament_list_screen_test.dart`

**Interfaces:**
- Consumes: Task 7 providers, Task 4 `TournamentRepository`, Task 1 (`tournamentStatus`, `tournamentInputErrors`, `TournamentConstants`, `trimmedOrNull`).
- Produces:
  - `Routes.tournaments = '$play/tournaments'`, `Routes.tournamentPattern = '$play/tournaments/:id'`, `static String tournament(String id) => '$play/tournaments/$id';`
  - `class TournamentPlayCard extends ConsumerWidget { const TournamentPlayCard({super.key}); }`. It is a `PcCard(key: Key('play-tournament-card'), onTap: () => context.go(Routes.tournaments))` holding a `Row` (`Icon(Icons.emoji_events_outlined)`, `Expanded(Text(Vi.tournamentsTitle, titleMedium))`, `Icon(Icons.chevron_right)`) and, from `featuredTournamentProvider`, one of:
    - loading: nothing;
    - error: `Text(Vi.tournamentDataError)`;
    - `null`: `Text(Vi.tournamentNone)`;
    - a tournament `t`: `Text(t.name, titleSmall)` plus `Text(Vi.tournamentStatusDates(tournamentStatus(t, today), t))`.
  - `class TournamentListScreen extends ConsumerStatefulWidget { const TournamentListScreen({super.key}); }`. It is a `PcRootScaffold(title: Vi.tournamentsTitle)` over `tournamentGroupsProvider`: a spinner while loading, `PcEmptyState(Icons.cloud_off, Vi.dataErrorTitle, Vi.dataErrorBody)` on error, otherwise a `ListView(padding: 12)` of:
    1. `FilledButton.icon(key: Key('tournament-add'), icon: Icon(Icons.add), label: Text(Vi.tournamentAdd))`, disabled while busy. It calls `showTournamentForm`, then `repo.create(draft)`, and shows the SnackBar `Vi.tournamentSaveFailed` on error.
    2. The comparison `PcCard` (`Key('tournament-compare')`) from `tournamentComparisonProvider`: title `Vi.tournamentCompareTitle`, then `enough ? Vi.tournamentCompare(in.rackWinPercent!, in.completedMatches, reg.rackWinPercent!, reg.completedMatches) : Vi.tournamentCompareNotEnough`. Hidden while loading, `Text(Vi.tournamentDataError)` on error.
    3. `Text(Vi.tournamentListEmpty)` when all three groups are empty.
    4. For each non-empty group, in order `dangDienRa`, `sapToi`, `daXong`: a header `Text(Vi.tournamentStatusName(status), titleMedium)`, then one tile per tournament: `PcCard(key: ValueKey('tournament-${t.id}'), onTap: () => context.go(Routes.tournament(t.id)))` with the lines:
       - `Text(t.name, titleSmall)`
       - `Text(Vi.tournamentDates(t))`
       - `Text(location)` when set
       - `Text(Vi.tournamentRecord(s.matchesWon, s.matchesLost))` when `tournamentSummariesProvider` has a value for it
       - `Text(Vi.tournamentResultLine(note))` when set
  - `Future<TournamentDraft?> showTournamentForm(BuildContext context, {Tournament? existing, required DateTime today})`. It is an `AlertDialog(scrollable: true)` titled `existing == null ? Vi.tournamentAddTitle : Vi.tournamentEditTitle`. Its content is a `Form` with:
    - `TextFormField(key 'tournament-name', label Vi.tournamentName, maxLength 80)`;
    - a start-date row (`Key('tournament-start')`, label `Vi.tournamentStartDate`, value `Vi.shortDate(start)`, defaulting to `dateOnly(today)` for a new tournament);
    - an end-date row (`Key('tournament-end')`, label `Vi.tournamentEndDate`, value `Vi.tournamentNoEndDate` when null) with an `IconButton(key 'tournament-clear-end', tooltip Vi.tournamentClearDate)` shown when set;
    - `TextFormField` fields for location (`'tournament-location'`, 120), result (`'tournament-result'`, label `Vi.tournamentResultNote`, `helperText: Vi.tournamentResultHint`, 120) and notes (`'tournament-notes'`, `maxLines: 3`, 500);
    - `DropdownButtonFormField<PoolGameType?>(key 'tournament-game-type', label Vi.tournamentGameType)` with items `null → Vi.tournamentNoGameType` plus `Vi.matchGameTypeName`.

    A date row is a tappable `Row` (`InkWell`) that opens `showDatePicker(initialDate: value ?? start, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: Vi.tournamentPickDate)`. Validators show `Vi.tournamentInputError(e)` for the errors of their own field in `tournamentInputErrors(currentDraft)`. A red `Text(Vi.tournamentInputError(TournamentInputError.endBeforeStart))` appears under the end row after a save attempt that has that error. Actions are `TextButton(Vi.cancel)` and `FilledButton(Vi.tournamentSave)`, which pops the draft only when the error set is empty.
  - `Vi` (exact). `vi.dart` gains imports of `domain/tournament/tournament.dart` and `domain/roadmap/pace.dart` (`show dateOnly`):

```dart
// ─── Giải đấu (spec 2026-10-28) ───
// Thành tích là chữ người chơi tự ghi; mọi con số do lib/domain/tournament tính ra.
static const tournamentsTitle = 'Giải đấu';
static const tournamentNone = 'Chưa có giải nào';
static const tournamentListEmpty = 'Chưa có giải nào. Thêm giải bạn sắp đánh hoặc đã đánh để ghi trận vào đó.';
static const tournamentAdd = 'Thêm giải';
static const tournamentAddTitle = 'Thêm giải';
static const tournamentEditTitle = 'Sửa giải';
static const tournamentSave = 'Lưu giải';
static const tournamentName = 'Tên giải';
static const tournamentStartDate = 'Ngày bắt đầu';
static const tournamentEndDate = 'Ngày kết thúc (không bắt buộc)';
static const tournamentNoEndDate = 'Chưa chọn';
static const tournamentPickDate = 'Chọn ngày';
static const tournamentClearDate = 'Bỏ ngày kết thúc';
static const tournamentLocation = 'Địa điểm (không bắt buộc)';
static const tournamentGameType = 'Thể loại (không bắt buộc)';
static const tournamentNoGameType = 'Chưa chọn';
static const tournamentResultNote = 'Thành tích (không bắt buộc)';
static const tournamentResultHint = 'Ví dụ: Vào vòng 16';
static const tournamentNotes = 'Ghi chú (không bắt buộc)';
static String tournamentInputError(TournamentInputError e) => switch (e) {
  TournamentInputError.nameRequired => 'Nhập tên giải.',
  TournamentInputError.nameTooLong => 'Tên giải tối đa ${TournamentConstants.nameMaxLength} ký tự.',
  TournamentInputError.endBeforeStart => 'Ngày kết thúc không được trước ngày bắt đầu.',
  TournamentInputError.locationTooLong => 'Địa điểm tối đa ${TournamentConstants.locationMaxLength} ký tự.',
  TournamentInputError.resultNoteTooLong => 'Thành tích tối đa ${TournamentConstants.resultNoteMaxLength} ký tự.',
  TournamentInputError.notesTooLong => 'Ghi chú tối đa ${TournamentConstants.notesMaxLength} ký tự.',
};
static const tournamentSaveFailed = 'Không lưu được giải. Vui lòng thử lại.';
static const tournamentDataError = 'Chưa tải được dữ liệu giải đấu.';
static String tournamentStatusName(TournamentStatus s) => switch (s) {
  TournamentStatus.sapToi => 'Sắp tới',
  TournamentStatus.dangDienRa => 'Đang diễn ra',
  TournamentStatus.daXong => 'Đã xong',
};
static String tournamentDates(Tournament t) =>
    t.endDate == null || dateOnly(t.endDate!) == dateOnly(t.startDate)
        ? shortDate(t.startDate)
        : '${shortDate(t.startDate)} – ${shortDate(t.endDate!)}';
static String tournamentStatusDates(TournamentStatus s, Tournament t) => '${tournamentStatusName(s)} · ${tournamentDates(t)}';
static String tournamentRecord(int won, int lost) => 'Thắng $won – thua $lost trận';
static String tournamentResultLine(String note) => 'Thành tích: $note';
static const tournamentCompareTitle = 'Ở giải và trận thường';
static String tournamentCompare(int inPercent, int inMatches, int regularPercent, int regularMatches) =>
    'Ở giải: thắng $inPercent% số ván ($inMatches trận) · Trận thường: thắng $regularPercent% số ván ($regularMatches trận)';
static const tournamentCompareNotEnough =
    'Cần ít nhất ${MatchAnalysisConstants.minMatches} trận hoàn tất ở mỗi bên để so sánh';
```

- [ ] **Step 1: Write the failing tests.**

In `routes_test.dart`, add `Routes.tournaments` right after `Routes.equipment` in the expected `all` list, plus `test('Giải đấu nằm trong nhánh Thi đấu', () => expect(Routes.tournaments, '${Routes.play}/tournaments'))`, `expect(Routes.tournament('t3'), '/play/tournaments/t3')` and `expect(Routes.tournament('x'), Routes.tournamentPattern.replaceAll(':id', 'x'))`.

In `route_cases.dart`, add `Routes.tournaments: (path: Routes.tournaments, screen: TournamentListScreen),`.

`tournament_list_screen_test.dart` (`testToday` = 22/09/2026 10:00; `day(n) => DateTime(2026, 9, 22 + n)`):

```dart
Future<GoRouter> openAt(WidgetTester tester, String path, ProviderContainer c) async {
  final router = await pumpRoutedApp(tester, container: c);
  router.go(path);
  await tester.pumpAndSettle();
  return router;
}

testWidgets('Play có thẻ Giải đấu: chưa có giải thì nói thẳng, bấm mở danh sách', (tester) async {
  await openAt(tester, Routes.play, testContainer());
  expect(find.text(Vi.tournamentNone), findsOneWidget);
  await tester.tap(find.byKey(const Key('play-tournament-card')));
  await tester.pumpAndSettle();
  expect(find.byType(TournamentListScreen), findsOneWidget);
});
testWidgets('thẻ Play: giải đang diễn ra trước giải sắp tới; không có thì giải sắp tới gần nhất', (tester) async {
  await openAt(tester, Routes.play, testContainer(tournaments: [
    Tournament(id: 'u', name: 'Sắp tới', startDate: day(3)), Tournament(id: 'o', name: 'Đang đánh', startDate: day(-1), endDate: day(1))]));
  expect([find.text('Đang đánh').evaluate().length, find.text('Sắp tới').evaluate().length], [1, 0]);
});
testWidgets('ba nhóm theo đúng thứ tự; mỗi giải có ngày, địa điểm, thắng/thua, thành tích', (tester) async {
  await openAt(tester, Routes.tournaments, testContainer(
    tournaments: [
      Tournament(id: 'x', name: 'Xong', startDate: day(-30), resultNote: 'Vào vòng 16'),
      Tournament(id: 's', name: 'Sắp', startDate: day(4)),
      Tournament(id: 'o', name: 'Đang', startDate: day(0), location: 'CLB A'),
    ],
    matches: [/* two completed matches with tournamentId 'x': one won 3–1, one lost 1–3 */],
  ));
  double y(String text) => tester.getTopLeft(find.text(text)).dy;
  expect(y(Vi.tournamentStatusName(TournamentStatus.dangDienRa)) < y(Vi.tournamentStatusName(TournamentStatus.sapToi)), isTrue);
  expect(y(Vi.tournamentStatusName(TournamentStatus.sapToi)) < y(Vi.tournamentStatusName(TournamentStatus.daXong)), isTrue);
  expect(find.text('CLB A'), findsOneWidget);
  expect(find.text(Vi.tournamentRecord(1, 1)), findsOneWidget);
  expect(find.text(Vi.tournamentResultLine('Vào vòng 16')), findsOneWidget);
});
testWidgets('so sánh: thiếu trận thì nói cần ít nhất 3 trận mỗi bên', (tester) async {
  await openAt(tester, Routes.tournaments, testContainer());
  expect(find.text(Vi.tournamentCompareNotEnough), findsOneWidget);
});
testWidgets('so sánh: đủ mỗi bên thì hiện hai tỷ lệ ván thắng', (tester) async {
  /* tournament 'o' (start testToday); 3 completed matches in it, each won 3 lost 0; 3 regular matches, each won 3 lost 2 */
  expect(find.text(Vi.tournamentCompare(100, 3, 60, 3)), findsOneWidget);
});
testWidgets('Thêm giải: cắt khoảng trắng, ngày bắt đầu là hôm nay, hiện trong Đang diễn ra', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await openAt(tester, Routes.tournaments, dbContainer(db));
  await tester.tap(find.byKey(const Key('tournament-add')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('tournament-name')), '  Giải Quận 1  ');
  await tester.tap(find.text(Vi.tournamentSave));
  await tester.pumpAndSettle();
  final r = await db.select(db.tournamentRows).getSingle();
  expect([r.name, r.startDate, r.endDate], ['Giải Quận 1', DateTime(2026, 9, 22), null]);
  expect(find.text('Giải Quận 1'), findsOneWidget);
});
testWidgets('tên rỗng: báo lỗi, không lưu', (tester) async {
  /* dbContainer; open form; tap save */
  expect(find.text(Vi.tournamentInputError(TournamentInputError.nameRequired)), findsOneWidget);
  expect(await db.select(db.tournamentRows).get(), isEmpty);
});
testWidgets('ngày kết thúc trước ngày bắt đầu: báo lỗi, không lưu', (tester) async {
  /* dbContainer; open form; enter name 'Giải'; tap Key('tournament-end'); in the picker tap find.text('21') then
     find.text(MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel); tap save */
  expect(find.text(Vi.tournamentInputError(TournamentInputError.endBeforeStart)), findsOneWidget);
  expect(await db.select(db.tournamentRows).get(), isEmpty);
});
testWidgets('360×640 chữ lớn: Play, danh sách và form không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);
  final router = await pumpRoutedApp(tester, container: richContainer());
  for (final path in [Routes.play, Routes.tournaments]) {
    router.go(path);
    await tester.pumpAndSettle();
    await scrollThroughAll(tester);
    expect(tester.takeException(), isNull, reason: path);
  }
  await tester.tap(find.byKey(const Key('tournament-add')));
  await tester.pumpAndSettle();
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/core/router test/features/play/tournament_list_screen_test.dart`. Expected: FAIL because the route and screens are missing.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/core/router test/features/play test/smoke test/architecture_test.dart`. Expected: PASS. The smoke grid now also opens `/play/tournaments` at every size.
- [ ] **Step 5: Commit** with `"Giải đấu: thẻ Giải đấu ở Thi đấu, danh sách ba nhóm, dòng so sánh và form thêm giải tại /play/tournaments"` plus the trailer.

---

### Task 10: Tournament detail, preparing for a tournament, Roadmap title

**Files:**
- Modify: `lib/core/router/routes.dart` (`tournamentPattern` into `all`, right after `tournaments`), `lib/core/router/app_router.dart` (child `GoRoute(path: ':id', builder: (_, s) => TournamentDetailScreen(tournamentId: s.pathParameters['id']!))` under `'tournaments'`)
- Create: `lib/features/play/presentation/tournament_detail_screen.dart`
- Modify: `lib/features/stats/presentation/match_analysis_card.dart` (optional `title`)
- Modify: `lib/core/strings/vi.dart` (Giải đấu section; `roadmapHeadline` :1913-1920)
- Modify: `lib/features/roadmap/presentation/roadmap_screen.dart:103` (pass the linked tournament's name)
- Modify: `test/core/router/routes_test.dart`, `test/support/route_cases.dart`, `test/core/strings/vi_roadmap_test.dart`
- Create: `test/features/play/tournament_detail_screen_test.dart`

**Interfaces:**
- Consumes: Task 7 (`tournamentViewProvider`, `tournamentGoalStateProvider`, `linkedTournamentProvider`, `tournamentsByIdProvider`, `tournamentRepositoryProvider`), Task 8 (`showStartMatchDialog`, `startMatchFromForm`), Task 9 (`showTournamentForm`, `Vi` tournament strings), `roadmapRepositoryProvider`, `goalProvider`, `showMatchAnalysis`, `analyzeMatches`, `defaultMatchCueId`.
- Produces:
  - `MatchAnalysisCard({required MatchAnalysis analysis, String title = Vi.statsMatchAnalysisTitle, super.key})`.
  - `Vi.roadmapHeadline(Roadmap roadmap, {String? tournamentName})`. For `chuanBiGiai` it returns `tournamentName == null ? 'Chuẩn bị giải ngày ${shortDate(d)}' : 'Chuẩn bị giải $tournamentName — ngày ${shortDate(d)}'`. `RoadmapView` passes `ref.watch(linkedTournamentProvider).value?.name`.
  - `class TournamentDetailScreen extends ConsumerStatefulWidget { const TournamentDetailScreen({required this.tournamentId, super.key}); final String tournamentId; }`. It is a `PcRootScaffold(title: Vi.tournamentsTitle)` over `tournamentViewProvider(tournamentId)`: a spinner while loading, the data-error `PcEmptyState` on error, and `PcEmptyState(Icons.search_off, Vi.tournamentNotFoundTitle, Vi.tournamentNotFoundBody, action: FilledButton(Vi.tournamentBackToList → Routes.tournaments))` for `null` (★ call 17). Otherwise it shows a `ListView(padding: 12)` of:
    1. **Info card.** It holds:
       - `Text(name, titleLarge)` with `IconButton(key 'tournament-edit', tooltip Vi.tournamentEdit)` and `IconButton(key 'tournament-delete', tooltip Vi.tournamentDelete)`;
       - `Text(Vi.tournamentStatusDates(status, t))`;
       - location, if set;
       - `Text(Vi.matchGameTypeName(gameType))`, if set;
       - if `resultNote` is set: `Text(Vi.tournamentResultLine(note))` plus `Text(Vi.tournamentSelfReported, bodySmall)`;
       - notes, if set.

       Edit opens `showTournamentForm(existing: t)` and then `repo.update`. Delete asks `AlertDialog(Vi.tournamentDeleteTitle, Vi.tournamentDeleteBody, [Vi.cancel, Vi.tournamentDeleteConfirm])`, then runs `repo.remove` and `context.go(Routes.tournaments)`. Failures show the SnackBar `Vi.tournamentSaveFailed` / `Vi.tournamentDeleteFailed`.
    2. **Actions.**
       - When status ≠ `sapToi`: `FilledButton.icon(key 'tournament-start-match', Vi.tournamentStartMatch)`. It runs `showStartMatchDialog(…, tournaments: pickableForNewMatch(byId.values, today, include: t.id), preselected: t)`, then `startMatchFromForm`, then `context.go(Routes.play)` (★ calls 4, 5).
       - From `tournamentGoalStateProvider(id).value`:
         - `noGoal` / `otherGoal`: `OutlinedButton(key 'tournament-prepare', Vi.tournamentPrepare)`. For `otherGoal` it first asks `AlertDialog(Vi.tournamentReplaceGoalTitle, Vi.tournamentReplaceGoalBody(Vi.goalKind(currentKind)), [TextButton(Vi.goalCancelChange), FilledButton(Vi.goalChange)])` (★ call 14). It then calls `roadmapRepositoryProvider!.setGoal(kind: GoalKind.chuanBiGiai, eventDate: t.startDate, tournamentId: t.id)`, and shows the SnackBar `Vi.tournamentGoalFailed` on error.
         - `linked`: `Text(Vi.tournamentPreparing)` plus `TextButton(key 'tournament-open-roadmap', Vi.tournamentOpenRoadmap → Routes.roadmap)`.
         - `notUpcoming` or `null`: nothing.
    3. **Summary card.** Title `Vi.tournamentSummaryTitle`. With `summary.completedMatches == 0`, it shows `Vi.tournamentSummaryEmpty`. Otherwise it shows `Vi.tournamentRecord(won, lost)`, `Vi.tournamentRacks(racksWon, racksLost)` and `Vi.tournamentRackRate(rackWinPercent!)`.
    4. **Matches.** Header `Vi.tournamentMatchesTitle`, or `Vi.tournamentMatchesEmpty` when there are none. One `PcCard(key: ValueKey('tournament-match-${m.id}'))` per match, in `view.matches` order, with `Text(Vi.tournamentMatchTitle(m.roundLabel, m.opponentName))`, `Text(Vi.matchScore(...))` and `Text(m.isComplete ? (playerWon(m) ? Vi.tournamentMatchWon : Vi.tournamentMatchLost) : Vi.matchInProgress)`. `onTap` is `showMatchAnalysis(context, m)` when complete, else `context.go(Routes.play)` (★ call 6).
    5. **Analysis.** `MatchAnalysisCard(analysis: analyzeMatches(view.matches, limit: view.matches.length), title: Vi.tournamentAnalysisTitle)` (★ call 15).
  - `Vi` (exact, in the Giải đấu section):

```dart
static const tournamentEdit = 'Sửa giải';
static const tournamentDelete = 'Xóa giải';
static const tournamentDeleteTitle = 'Xóa giải đấu?';
static const tournamentDeleteBody = 'Giải sẽ bị xóa. Các trận đã ghi vẫn còn và hiện như trận thường.';
static const tournamentDeleteConfirm = 'Xóa giải';
static const tournamentDeleteFailed = 'Không xóa được giải. Vui lòng thử lại.';
static const tournamentSelfReported = 'Kết quả do bạn ghi';
static const tournamentSummaryTitle = 'Tổng kết';
static const tournamentSummaryEmpty = 'Chưa có trận hoàn tất nào trong giải này.';
static String tournamentRacks(int won, int lost) => 'Thắng $won – thua $lost ván';
static String tournamentRackRate(int percent) => 'Tỷ lệ ván thắng: $percent%';
static const tournamentMatchesTitle = 'Các trận';
static const tournamentMatchesEmpty = 'Chưa có trận nào trong giải này.';
static String tournamentMatchTitle(String? round, String opponent) => round == null ? 'Gặp $opponent' : '$round · gặp $opponent';
static const tournamentMatchWon = 'Thắng';
static const tournamentMatchLost = 'Thua';
static const tournamentAnalysisTitle = 'Phân tích các trận trong giải';
static const tournamentStartMatch = 'Bắt đầu trận trong giải';
static const tournamentPrepare = 'Chuẩn bị cho giải này';
static const tournamentPreparing = 'Đang chuẩn bị cho giải này';
static const tournamentOpenRoadmap = 'Mở Lộ trình';
static const tournamentReplaceGoalTitle = 'Thay mục tiêu hiện tại?';
static String tournamentReplaceGoalBody(String currentGoal) =>
    'Mục tiêu đang chạy: $currentGoal. Đặt mục tiêu chuẩn bị cho giải này thì mục tiêu cũ sẽ được thay.';
static const tournamentGoalFailed = 'Không đặt được mục tiêu. Vui lòng thử lại.';
static const tournamentNotFoundTitle = 'Không tìm thấy giải';
static const tournamentNotFoundBody = 'Giải này không còn hoặc không thuộc tài khoản của bạn.';
static const tournamentBackToList = 'Về danh sách giải';
```

- [ ] **Step 1: Write the failing tests.**

In `routes_test.dart`, add `Routes.tournamentPattern` right after `Routes.tournaments` in the expected `all`. In `route_cases.dart`, add `Routes.tournamentPattern: (path: '/play/tournaments/t1', screen: TournamentDetailScreen),`. In `vi_roadmap_test.dart`:

```dart
test('tiêu đề chuẩn bị giải có tên khi nối giải hợp lệ', () {
  final r = Roadmap(goal: PlayerGoal(goalId: 'g', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), createdAt: at), steps: const []);
  expect(Vi.roadmapHeadline(r), 'Chuẩn bị giải ngày 02/11/2026');
  expect(Vi.roadmapHeadline(r, tournamentName: 'Cúp Mùa Đông'), 'Chuẩn bị giải Cúp Mùa Đông — ngày 02/11/2026');
});
```

`tournament_detail_screen_test.dart` (`testToday` = 22/09/2026; `day(n)`; `open(tester, container, id)` uses `pumpRoutedApp` and `router.go(Routes.tournament(id))`):

```dart
final on = Tournament(id: 'on', name: 'Giải Q1', startDate: DateTime(2026, 9, 21), endDate: DateTime(2026, 9, 23), location: 'CLB A',
    gameType: PoolGameType.tenBall, resultNote: 'Vào vòng 16', notes: 'Bàn nhanh');
final up = Tournament(id: 'up', name: 'Cúp Mùa Đông', startDate: DateTime(2026, 10, 2));
PoolMatch m(String id, {required int won, required int lost, int? target, required DateTime at, String? round}) => PoolMatch(id: id,
    gameType: PoolGameType.tenBall, playerName: 'An', opponentName: 'Đối thủ $id', targetRacks: target ?? (won > lost ? won : lost),
    rackWinners: [for (var i = 0; i < won; i++) RackWinner.player, for (var i = 0; i < lost; i++) RackWinner.opponent],
    startedAt: at, completedAt: (target == null) ? at.add(const Duration(hours: 1)) : null, tournamentId: 'on', roundLabel: round);

testWidgets('thông tin: ngày, địa điểm, loại bi, trạng thái, thành tích kèm nhãn tự ghi, ghi chú', (tester) async {
  await open(tester, testContainer(tournaments: [on]), 'on');
  for (final s in ['Giải Q1', Vi.tournamentStatusDates(TournamentStatus.dangDienRa, on), 'CLB A', Vi.matchGameTypeName(PoolGameType.tenBall),
      Vi.tournamentResultLine('Vào vòng 16'), Vi.tournamentSelfReported, 'Bàn nhanh']) {
    expect(find.text(s), findsOneWidget, reason: s);
  }
});
testWidgets('không ghi thành tích thì không có nhãn tự ghi', (tester) async {
  await open(tester, testContainer(tournaments: [up]), 'up');
  expect(find.text(Vi.tournamentSelfReported), findsNothing);
});
testWidgets('tổng kết và các trận tính từ trận đã ghi, theo giờ bắt đầu', (tester) async {
  await open(tester, testContainer(tournaments: [on], matches: [
    m('b', won: 1, lost: 3, at: DateTime(2026, 9, 22, 9), round: 'Bán kết'),
    m('a', won: 3, lost: 2, at: DateTime(2026, 9, 21, 9), round: 'Tứ kết'),
    m('c', won: 1, lost: 0, target: 3, at: DateTime(2026, 9, 22, 10)),
  ]), 'on');
  expect(find.text(Vi.tournamentRecord(1, 1)), findsOneWidget);
  expect(find.text(Vi.tournamentRacks(4, 5)), findsOneWidget);
  expect(find.text(Vi.tournamentRackRate(44)), findsOneWidget);
  double y(String id) => tester.getTopLeft(find.byKey(ValueKey('tournament-match-$id'))).dy;
  expect(y('a') < y('b') && y('b') < y('c'), isTrue);
  expect(find.text(Vi.tournamentMatchTitle('Tứ kết', 'Đối thủ a')), findsOneWidget);
  expect(find.text(Vi.tournamentAnalysisTitle), findsOneWidget);
});
testWidgets('chưa có trận hoàn tất: nói thẳng', (tester) async {
  await open(tester, testContainer(tournaments: [on]), 'on');
  expect(find.text(Vi.tournamentSummaryEmpty), findsOneWidget);
});
testWidgets('bấm trận đã xong mở phân tích trận', (tester) async { /* tap tournament-match-a → find.byType(MatchAnalysisView) findsOneWidget */ });
testWidgets('giải sắp tới không có nút bắt đầu trận', (tester) async {
  await open(tester, testContainer(tournaments: [up]), 'up');
  expect(find.byKey(const Key('tournament-start-match')), findsNothing);
});
// Review Focus 4
testWidgets('bắt đầu trận ở giải đã xong 20 ngày: chọn sẵn giải, loại bi theo giải, lưu rồi sang Thi đấu', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await TournamentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'old').create(
      TournamentDraft(name: 'Giải cũ', startDate: DateTime(2026, 9, 1), endDate: DateTime(2026, 9, 2), gameType: PoolGameType.tenBall));
  await open(tester, dbContainer(db), 'old');
  await tester.tap(find.byKey(const Key('tournament-start-match')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.enterText(find.byKey(const Key('match-player-name')), 'An');
  await tester.enterText(find.byKey(const Key('match-opponent-name')), 'Bình');
  await tester.tap(find.text(Vi.matchStartAction));
  await tester.pumpAndSettle();
  final r = await db.select(db.poolMatchRows).getSingle();
  expect([r.tournamentId, r.gameType], ['old', 'tenBall']);
  expect(find.byType(PlayScreen), findsOneWidget);
});
testWidgets('chưa có mục tiêu: Chuẩn bị cho giải này đặt mục tiêu nối giải; Lộ trình có tên giải', (tester) async {
  /* dbContainer(db); create 'up' (start 02/10/2026) via TournamentRepository; open 'up'; tap tournament-prepare */
  final g = await db.select(db.playerGoalRows).getSingle();
  expect([g.kind, g.eventDate, g.tournamentId], ['chuanBiGiai', DateTime(2026, 10, 2), 'up']);
  expect(find.text(Vi.tournamentPreparing), findsOneWidget);
  await tester.tap(find.byKey(const Key('tournament-open-roadmap')));
  await tester.pumpAndSettle();
  expect(find.text('Chuẩn bị giải Cúp Mùa Đông — ngày 02/10/2026'), findsOneWidget);
});
testWidgets('đang có mục tiêu khác: hỏi trước; Giữ mục tiêu cũ thì không đổi, Đổi mục tiêu thì thay', (tester) async {
  /* dbContainer(db); RoadmapRepository.setGoal(thuanThucKyNang, aiming); open 'up'; tap prepare */
  expect(find.text(Vi.tournamentReplaceGoalBody(Vi.goalKind(GoalKind.thuanThucKyNang))), findsOneWidget);
  /* tap Vi.goalCancelChange → kind still thuanThucKyNang; tap prepare again, tap Vi.goalChange → kind chuanBiGiai, tournamentId 'up' */
});
// Review Focus 1
testWidgets('đổi ngày bắt đầu sau khi đã nối mục tiêu: liên kết bỏ, nút Chuẩn bị hiện lại, Lộ trình về tiêu đề cũ', (tester) async {
  /* dbContainer(db); create 'up'; setGoal(chuanBiGiai, eventDate 02/10/2026, tournamentId 'up'); open 'up' → Vi.tournamentPreparing shown */
  await TournamentRepository(db, userId: 'u1', now: () => testToday, newId: () => 'x')
      .update('up', TournamentDraft(name: 'Cúp Mùa Đông', startDate: DateTime(2026, 10, 3)));
  await tester.pumpAndSettle();
  expect(find.text(Vi.tournamentPreparing), findsNothing);
  expect(find.byKey(const Key('tournament-prepare')), findsOneWidget);
  /* go Routes.roadmap → find.text('Chuẩn bị giải ngày 02/10/2026') */
});
testWidgets('xóa giải: hỏi trước, xóa mềm, về danh sách, trận giữ tournament_id', (tester) async { /* … */ });
testWidgets('id không còn: màn không tìm thấy, có nút về danh sách', (tester) async {
  await open(tester, testContainer(), 'zz');
  expect(find.text(Vi.tournamentNotFoundTitle), findsOneWidget);
});
testWidgets('360×640 chữ lớn: chi tiết giải dài không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);
  final router = await pumpRoutedApp(tester, container: richContainer());
  router.go(Routes.tournament('t1'));
  await tester.pumpAndSettle();
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `$ENV $FLUTTER test test/core test/features/play/tournament_detail_screen_test.dart`. Expected: FAIL because the route and screen are missing.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `$ENV $FLUTTER test test/core test/features test/smoke test/architecture_test.dart`. Expected: PASS. The smoke grid opens `/play/tournaments/t1` at every size, in the not-found state with `testContainer()` and fully populated with `richContainer()`.
- [ ] **Step 5: Commit** with `"Giải đấu: màn chi tiết giải (tổng kết, các trận, phân tích, bắt đầu trận, chuẩn bị cho giải) và tên giải trên Lộ trình"` plus the trailer.

---

### Task 11: No-fabrication sweep, live E2E script, full suite

**Files:**
- Modify: `test/domain/no_fabrication_test.dart` (new group at the end of `main`)
- Create: `tool/e2e/tournament.mjs`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the no-fabrication group** `'Giải đấu bám dữ liệu, không viết cứng (spec 2026-10-28 giải đấu mục 7)'`:

```dart
test('tổng kết giải đổi theo trận', () {
  String lines(List<PoolMatch> ms) { final s = summarizeMatches(ms);
    return [Vi.tournamentRecord(s.matchesWon, s.matchesLost), Vi.tournamentRacks(s.racksWon, s.racksLost), Vi.tournamentRackRate(s.rackWinPercent!)].join('|'); }
  expect(lines([tMatch('a', won: 3, lost: 1)]), isNot(lines([tMatch('a', won: 1, lost: 3), tMatch('b', won: 3, lost: 2)])));
});
test('dòng so sánh đổi theo dữ liệu, kể cả khi thiếu mẫu', () {
  final live = [tour('t', start: tDay(-1))];
  String line(List<PoolMatch> ms) { final c = compareTournamentPlay(ms, live);
    return c.enough ? Vi.tournamentCompare(c.inTournaments.rackWinPercent!, c.inTournaments.completedMatches, c.regular.rackWinPercent!, c.regular.completedMatches)
        : Vi.tournamentCompareNotEnough; }
  List<PoolMatch> inT(int lost) => [for (var i = 0; i < 3; i++) tMatch('t$i', tournamentId: 't', won: 3, lost: lost)];
  List<PoolMatch> reg(int lost) => [for (var i = 0; i < 3; i++) tMatch('r$i', won: 3, lost: lost)];
  expect({line(const []), line([...inT(0), ...reg(1)]), line([...inT(2), ...reg(0)])}, hasLength(3));
});
testWidgets('thẻ Giải đấu ở Thi đấu đổi theo dữ liệu', (tester) async {
  for (final (ts, expected) in [
    (const <Tournament>[], Vi.tournamentNone),
    ([Tournament(id: 'a', name: 'Giải A', startDate: DateTime(2026, 9, 22))], 'Giải A'),
    ([Tournament(id: 'b', name: 'Giải B', startDate: DateTime(2026, 9, 30))], 'Giải B'),
  ]) {
    final c = testContainer(tournaments: ts);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: TournamentPlayCard()))));
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
  }
});
test('tiêu đề Lộ trình đổi theo giải nối, về tiêu đề cũ khi giải bị xóa', () {
  final goal = prepGoal(tDay(5), tournamentId: 'up');
  final r = Roadmap(goal: goal, steps: const []);
  String title(List<Tournament> live) => Vi.roadmapHeadline(r, tournamentName: linkedTournament(goal, live)?.name);
  expect({title([tour('up', start: tDay(5), name: 'Cúp A')]), title([tour('up', start: tDay(5), name: 'Cúp B')]), title(const [])},
      hasLength(3));
  expect(title(const []), 'Chuẩn bị giải ngày ${Vi.shortDate(tDay(5))}');
});
```

- [ ] **Step 2: Run** `$ENV $FLUTTER test test/domain/no_fabrication_test.dart`. Expected: PASS, because every producer exists. A failure here is a real hardcoding bug: fix it in the owning file.

- [ ] **Step 3: Write `tool/e2e/tournament.mjs`.** Copy the structure of `tool/e2e/skill_test.mjs`:
  - the header comment with the run line `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/tournament.mjs <appUrl>`;
  - the same `PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1'` throw, the `need(...)` checks and the default `APP_URL`;
  - `check()` with screenshots into `$TMP/pcai-tournament`, `scrollUntilText`, `directusAdminToken()`, `directusUserId()` and `waitRows()`;
  - `launch({ port: 9352, name: 'tour' })`;
  - the throwaway email `e2e-tour-${Date.now()}@poolcoachai.example.com`;
  - a `finally` block that closes the tab and then calls `deleteUserByEmail(email)` (the `user_created` CASCADE removes the tournaments, matches and goal), with `process.exitCode = 1` on any failure.

  The steps, each `Vi` string's source in a comment, with `NAME = 'Giải E2E ' + Date.now()` and `UP = 'Cúp E2E ' + Date.now()`:
  1. `registerThrowaway(tab, APP, { email, password })`.
  2. `goto(${APP}/play)`, then `waitForText('Chưa có giải nào')` (`Vi.tournamentNone`). `goto(${APP}/play/tournaments)`, `click('Thêm giải')`, `type('Tên giải', NAME)`, `type('Thành tích (không bắt buộc)', 'Vào vòng 16')`, `click('Lưu giải')`, `waitForText(NAME)`. The start date keeps its default of today.
  3. `click(NAME)`, `waitForText('Đang diễn ra')`, `click('Bắt đầu trận trong giải')`, `type('Tên của bạn', 'An')`, `type('Tên đối thủ', 'Bình')`, `click('Chạm 5 ván thắng')`, `click('Chạm 3 ván thắng')`, `click('Tứ kết')`, `click('Bắt đầu trận')`. Then `waitForText(`${NAME} · Tứ kết`)` on Play, and `click('Tôi thắng ván')` three times (only one match exists). Finally `waitForText('Đã kết thúc')`.
  4. `goto(${APP}/play/tournaments)`, `click(NAME)`, then `check` that the text includes `'Thắng 1 – thua 0 trận'`, `'Thắng 3 – thua 0 ván'`, `'Tỷ lệ ván thắng: 100%'`, `'Thành tích: Vào vòng 16'` and `'Kết quả do bạn ghi'`.
  5. The upcoming tournament (★ call 16). Log in to Directus REST as the throwaway user (`POST /auth/login` with `email` / `password`). POST `/items/tournaments` with `{ id: randomUUID(), name: UP, start_date: <tomorrow local YYYY-MM-DD>, end_date: null, location: null, game_type: null, result_note: null, notes: null, created_at: now ISO, updated_at: now ISO, is_deleted: false }`. Then `tab.reload()`, `goto(${APP}/play/tournaments)`, `scrollUntilText(UP)` (poll up to 45 s with reloads every 15 s if it is absent), `click(UP)`, `waitForText('Sắp tới')`, `click('Chuẩn bị cho giải này')`, `waitForText('Đang chuẩn bị cho giải này')`, `click('Mở Lộ trình')`, and `check` that the text includes `` `Chuẩn bị giải ${UP} — ngày ` ``.
  6. As Directus admin, use `waitRows`:
     - `tournaments` (`fields=id,name,start_date,result_note,is_deleted`): two rows. `NAME` has `start_date` equal to today's local `YYYY-MM-DD` and `result_note 'Vào vòng 16'`, and both have `is_deleted false`.
     - `pool_matches` (`fields=tournament_id,round_label,rack_winners,completed_at`): one row with `tournament_id` equal to `NAME`'s id, `round_label 'Tứ kết'`, `rack_winners` of three `'player'`, and a non-null `completed_at`.
     - `player_goals` (`fields=kind,tournament_id,event_date`): `kind 'chuanBiGiai'` and `tournament_id` equal to the upcoming tournament's id.

  Run `node --check tool/e2e/tournament.mjs`. Expected: exit 0. Do **not** run the script: it writes to live Directus and needs the published build.

- [ ] **Step 4: Full suite and analyze.** Run the suite in the background (`run_in_background`) and Monitor it. Every minute, report the last line of the log, which in the expanded reporter shows the elapsed time, `+passed`, `-failed` and the current test name. Stop when the exit file exists.

```bash
cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/tournaments && rm -f /tmp/pcai-tour-full.log /tmp/pcai-tour-full.exit && (env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test --reporter expanded > /tmp/pcai-tour-full.log 2>&1; echo $? > /tmp/pcai-tour-full.exit)
```

  Expected: `/tmp/pcai-tour-full.exit` contains `0`, and the log ends with `All tests passed!`.

  Run `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/tournaments && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat analyze`. Expected: `No issues found!`

  Run `git status --short`. Expected: only this task's two files.

- [ ] **Step 5: Commit** with `"Giải đấu: phép thử chống bịa và kịch bản E2E trên Directus thật"` plus the trailer.

The plan ends here, with the full suite green and analyze clean. The coordinator's release steps sit outside this plan: PR, CI, Directus `bootstrap.mjs` then `verify.mjs` on prod (before the web publish, as spec §4.4 requires), merge, web publish, and the Chrome run of `tool/e2e/tournament.mjs`.
