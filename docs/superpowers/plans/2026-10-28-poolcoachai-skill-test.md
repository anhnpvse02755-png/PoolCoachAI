# Skill Test và chứng nhận Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A rule-based Skill Test per drill. The test opens after 3 passing sessions in a row and once every lower level in the group is certified. Passing it records a dated certification with its measuring conditions, synced and shown on drill detail, the Training list, Profile, Home and the achievements list.

**Architecture:** A new pure-Dart module `lib/domain/skill_test/` holds the model, grading (reusing `drillRatio`), the gate, certifications and the Profile summary. It has no Flutter, no `Vi`, no Vietnamese literals and never builds a `PlayerRank`. Data adds one append-only Drift table (v15, `skill_test_rows`), a repository, and push/pull inside the existing `AssessmentSyncService` (Directus `skill_tests`, create/read only). Certifications become `AchievementKind.chungNhan` achievements via the existing `newAchievements` recorder. The UI reads gated providers in `lib/core/providers/skill_test_providers.dart`, and all wording lives in `Vi`.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod 3 (no codegen), Drift (SQLite; `NativeDatabase.memory` in tests), go_router, Directus REST sync, Node 24 (`server/coach-chat` `node --test`, `tool/e2e` CDP scripts).

**Spec:** `docs/superpowers/specs/2026-10-28-poolcoachai-skill-test-design.md`

## Global Constraints

- Work only in the worktree `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\skill-test` (branch `feat/skill-test`). Bash cwd resets between calls: start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/skill-test && `.
- Prefix every flutter / dart / npm command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN`, because the shell exports live secrets. Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat` and Dart is `/c/Users/anhnpv/flutter/bin/dart.bat`. Neither is on PATH.
- `lib/data/database/database.g.dart` is gitignored. Regenerate it with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs` in Task 1 Step 1 and after every edit to `database.dart`.
- README rule 1 (no fabrication): every generated sentence (lock reason, result, Profile hint, Home line, "Phong độ gần đây chưa đạt") is a `Vi` template filled by a named, tested domain function. Missing data is stated as missing.
- README rule 2: the progression gate is rule-based and no LLM ever touches it. Rank changes only through a BU test. `lib/domain/skill_test/` never constructs `PlayerRank(` and never imports `assessment/player_rank.dart` or `assessment/rank_rules.dart`.
- `lib/domain/skill_test/` imports neither `package:flutter` nor `core/strings/vi.dart` and holds no Vietnamese string literal (comments may be Vietnamese). No Vietnamese literal in `lib/features/**` or `lib/core/widgets/**`. All UI copy goes into `Vi`, using exactly the strings this plan gives.
- `Achievement(` is constructed only in `lib/domain/roadmap/achievements.dart` and `lib/data/database/roadmap_converters.dart` (rule enforced by `test/architecture_test.dart`).
- Spec values, verbatim: open the test after `PracticeConstants.readyStreak` (= 3) passing sessions in a row. Pass when `drillRatio ≥ 1`, using the same `passThreshold` / `target` as practice. A retake needs ≥ 1 new practice session of that drill after the failed test (`SkillTestConstants.retakeSessions = 1`). "Phong độ gần đây chưa đạt" uses the 5 most recent sessions (`SkillTestConstants.recentFormWindow = 5`). Table sizes are 7 / 8 / 9 ft, the same as BU (`TableSize`). Drift `schemaVersion` is 15 and the table is `skill_test_rows`. Directus collection `skill_tests` allows create and read of own rows only, with no update and no delete. Achievements use `AchievementKind.chungNhan` with `refId = drillId`. Certifications are never revoked.
- Owner vocabulary, exactly: Ngắm bi, Điều bi, Phá, Phòng thủ, A băng (kick), Cân bi (bank), Chết cái. Never write "Đi bi", "Giao bóng" or "Scratch".
- Riverpod has no codegen. Never call `.invalidate(` or `.refresh(` in `lib/`. **Every provider that combines sources uses `gate()` from `lib/core/providers/async_gate.dart`**, so an upstream error surfaces as `AsyncError` and a source reloading with the previous account's value counts as loading.
- **A completed row always carries what its consumers need.** This is the lesson from the BU `examIIVersion` hang. A completed `skill_test_rows` row always has `drill_level`, `table_size`, `started_at`, `completed_at`, `score` and `passed`, and attempt-scored drills also have `attempts`. Consumers stay total: a completed row lacking `passed` counts as neither pass nor fail, and never throws or hangs.
- Test gotchas:
  1. Reading a provider `.future` in a test can hang silently. Use `container.listen(p, (_, _) {})`, then `await pumpEventQueue()` (five times, see `settle()` in `test/core/providers/roadmap_providers_test.dart:45`), then `container.read(p)`.
  2. Never write an explicit type on an override list. `<Override>[…]` or `List<Override>` crashes the compiler, so leave the list literal untyped.
  3. Inside `testWidgets`, `await repo.watchX().first` and `await watchAll().first` hang. Read rows with `db.select(db.table).get()`.
  4. Drift `AppDatabase.forTesting(NativeDatabase.memory())` works inside `flutter test`.
  5. The "reloading with the old value" state is `const AsyncLoading<T>().copyWithPrevious(AsyncData<T>(…))` preceded by `// ignore: invalid_use_of_internal_member` (see `test/core/providers/coach_chat_providers_test.dart:86-104`).
- Drift stores `DateTime` as whole seconds. Every fixed clock in tests is a whole second.
- The app must keep running on Android, iOS and web, so no web-only code.
- One commit per task. Subjects are in Vietnamese and end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No push, no PR, no deploy, no Directus or prod call, no APK build. Do **not** run `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` or any `tool/e2e/*.mjs`, since they hit prod. Check them with `node --check` only.
- A full-suite `flutter test` takes minutes. Run it in the background and stream the step plus pass/fail counts every minute with Monitor. Never wait silently.

## Review Focus

1. **Double submit, or the gate flipping during the flow.** After a pass, the gate becomes `AlreadyCertified`. The Skill Test screen must keep showing the result, not the locked view. A second submit (double tap, or a second tab) must not write a second row: the repository re-checks the gate inside its transaction. Tests: Task 4 (repository double submit), Task 7 (result stays after the gate flips).
2. **Results that would fake a pass**: hits above attempts (11/10), fractional hits on a count-scored drill, negative, `Infinity` or `NaN`, and attempts on a target drill. Each must be rejected with a named error and nothing written. Tests: Task 1 (`checkSkillTestInput`), Task 4 (repository throws), Task 7 (form error).
3. **Shared device, user switch.** Signing out deletes that player's `skill_test_rows`. Unsynced tests count toward the sign-out warning. A reloading `skillTestsProvider` that still holds the previous account's value makes the gate, the certifications and the Home line loading, never the old player's certificate. Tests: Task 4 (`signOutAndForget`, `pendingAssessmentCount`), Task 6 (reloading and error states).
4. **Partial or foreign data from sync**: a completed row without `passed`, a certification for a drill that is no longer in the library, and a remote row whose id already exists locally. Each must neither crash nor count as pass or fail, and the local row is kept. Tests: Task 1, Task 2 (`certificationSummary` skips unknown drills), Task 5 (pull keeps local).
5. **Non-contiguous or duplicate levels within a group** (seed: Ngắm bi 1 → 3, Điều bi 2, 2 → 3, 3). The lower-level gate must name every uncertified lower drill, same-level drills must not block each other, and "next level" must skip gaps. Tests: Task 2.

## Plan's calls

Where the spec is silent or does not match the code, the plan decides. Each call is marked ★ where it applies.

1. The route is `/training/skill-test/:id` (`Routes.skillTestPattern`), not `:drillId`. `test/core/router/routes_test.dart` asserts that builders substitute only `:id`, and the smoke grid uses the same rule.
2. A `skill_test_rows` row is written **once**, when the test is finished (completed or cancelled). There is no "active" row and no resume. The screen holds table size, start time and entry in memory, so closing the app mid-test leaves no row. This keeps "chỉ thêm, không sửa" literally true both locally and on Directus.
3. Cancelling after "Bắt đầu kiểm tra" writes a cancelled row with no score and no `passed` ("Hủy thì không lưu kết quả"). Cancelling on the prep view writes nothing. A cancelled test never counts as a fail.
4. Sync lives in `AssessmentSyncService` instead of a new service: push after BU tests, pull after BU tests. Pull uses `insertOrIgnore`, so append-only, local wins. Pending rows count in `watchPendingAssessment` and `pendingAssessmentCount`.
5. `chungNhan` achievements are derived by `newAchievements(..., skillTests:)` through `achievementRecorderProvider`, not written by the repository. This keeps the architecture rule on `Achievement(` and makes "tính lại được từ `skill_test_rows`" the only path. The date is the `completedAt` of the earliest passing test.
6. A certified drill shows no test button (gate `AlreadyCertified`). There is no re-certification.
7. Gate precedence: certified, then lower level, then streak, then retake. A missing lower-level certificate is reported even when the drill has never been practised.
8. Retake: at least `retakeSessions` (1) logs of that drill dated **strictly after** the failed test's `completedAt`. The streak rule still applies, so that session effectively has to pass.
9. "Phong độ gần đây chưa đạt" is shown when the drill is certified, it has ≥ 5 sessions, and none of the 5 most recent reaches `drillRatio ≥ 1`. An unscorable session counts as not passing. Fewer than 5 sessions means no conclusion.
10. In "Chưa đạt: {score}/{mục tiêu}", the target for count-scored drills is `passMark`: the smallest whole number of hits that reaches `drillRatio ≥ 1` for the entered attempts. For example, 7 of 10 at 0.8 reads "7/8". Target drills use `target`.
11. Test input is stricter than a practice session: count-scored drills need whole hits ≤ attempts, and target drills take no attempts.
12. Home shows one line naming the testable drill with the lowest (level, id), with "(và N bài khác)" when there are more. It is computed from drills, logs and tests through `skillTestGate`, whose streak rule is the same `isReadyForLevelUp` that produces `readyDrillIds`. It does not read `playerIntelligenceProvider`, because that provider returns `null` on an upstream error and would hide it. A domain test proves the result is a subset of `readyDrillIds`.
13. Profile empty hint: the uncertified drill whose lower-level gate is passed and that has the highest `consecutivePassCount` ≥ 1. Ties go to the lower level, then the id. When there is none, Profile says so (`Vi.certificationNoProgress`).
14. "Chưa có cấp tiếp theo trong nhóm này" appears on the pass result when no higher level exists in the group, and under a fully certified group in Profile. Otherwise the pass result lists the next level's drill names.
15. Table size reuses BU's `TableSize`, `Vi.buTableSizeLabel` and `Vi.buTableSize`. The default is "9 feet trở lên", the same as BU prep. The score and attempts labels reuse the practice-session labels.
16. Achievements still render only in the Roadmap view, which needs a goal. No new achievements surface is added.
17. Certifications of drills missing from the library are skipped in Profile and in badges. They still become achievements, because they are recorded evidence.
18. "Chạy bootstrap trên prod trước khi publish web" is a coordinator release step outside this plan.

---

### Task 1: Skill test model, grading and input check

**Files:**
- Create: `lib/domain/skill_test/skill_test.dart`
- Create: `test/support/skill_test_fixtures.dart`
- Create: `test/domain/skill_test/skill_test_test.dart`
- Modify: `test/architecture_test.dart` (append one test after `'lõi phân tích trận …'` at :295)

**Interfaces:**
- Produces (in `skill_test.dart`):
  - `abstract final class SkillTestConstants { static const retakeSessions = 1; static const recentFormWindow = 5; }`
  - `final class SkillTest { const SkillTest({required String id, required String drillId, required int drillLevel, required TableSize tableSize, required DateTime startedAt, DateTime? completedAt, DateTime? cancelledAt, num? score, int? attempts, bool? passed, String? notes}); bool get isCancelled /* cancelledAt != null */; bool get isCompleted /* completedAt != null && !isCancelled */; bool get certifies /* isCompleted && passed == true */; bool get failed /* isCompleted && passed == false */; }`, with `==` and `hashCode` over every field. `TableSize` comes from `lib/domain/assessment/bu_placement.dart`.
  - `enum SkillTestInputError { scoreInvalid, scoreNotWhole, scoreAboveAttempts, attemptsRequired, attemptsInvalid, attemptsNotAllowed }`
  - `bool? skillTestPassed(Drill drill, {required num score, int? attempts})`: builds a throwaway `DrillLog` and calls `drillRatio`. Returns `null` when the ratio is `null`, else `ratio >= 1`.
  - `num? passMark(Drill drill, {int? attempts})`: for a target drill, returns `drill.target`. For a count-scored drill, returns the smallest `k` in `0..attempts` with `skillTestPassed(drill, score: k, attempts: attempts) == true`, or `null` when `attempts` is null or ≤ 0, or when no `k` passes.
  - `SkillTestInputError? checkSkillTestInput(Drill drill, {required num score, int? attempts})`, checked in this order. First, `!score.isFinite || score < 0` gives `scoreInvalid`. For a count-scored drill: `attempts == null` gives `attemptsRequired`, `attempts <= 0` gives `attemptsInvalid`, `score != score.truncate()` gives `scoreNotWhole`, and `score > attempts` gives `scoreAboveAttempts`. For a target drill, `attempts != null` gives `attemptsNotAllowed`. Otherwise it returns `null`.
- Produces (fixtures, `test/support/skill_test_fixtures.dart`; later tasks use these names):
  - `final stToday = DateTime(2026, 10, 28, 10);`
  - `Drill stDrill(String id, SkillCategory cat, int level, {double? passThreshold = 0.8, num? target})`. Name `'Bai $id'`, unit `target == null ? 'lan / 10' : 'cm'`, goal `'g'`, steps `const []`. Sets `passThreshold` only when `target == null`.
  - `final stDrills = <Drill>[stDrill('a1', SkillCategory.aiming, 1), stDrill('a3', SkillCategory.aiming, 3), stDrill('p2a', SkillCategory.position, 2), stDrill('p2b', SkillCategory.position, 2), stDrill('p3', SkillCategory.position, 3), stDrill('t2', SkillCategory.safety, 2, target: 25)];`
  - `Drill stById(String id)` (looks up in `stDrills`).
  - `DrillLog stLog(String drillId, num score, DateTime at, {int? attempts = 10})`, with id `'$drillId@${at.toIso8601String()}'`.
  - `List<DrillLog> threePasses(String drillId, {DateTime? before})`: three `stLog(drillId, 9, …)` at `before - 3d`, `- 2d`, `- 1d`, oldest first. `before` defaults to `stToday`.
  - `SkillTest passedTest(String drillId, int level, DateTime at, {String? id, TableSize tableSize = TableSize.nineFootPlus})`: `startedAt = at - 20 min`, `completedAt = at`, `score: 9, attempts: 10, passed: true`, id `id ?? 'pass-$drillId-${at.toIso8601String()}'`.
  - `SkillTest failedTest(String drillId, int level, DateTime at, {String? id, TableSize tableSize = TableSize.nineFootPlus})`: same shape with `score: 5, passed: false`, id prefix `'fail-'`.
  - `SkillTest cancelledTest(String drillId, int level, DateTime at)`: `startedAt = at - 5 min`, `cancelledAt = at`, no score, no `passed`, id `'cancel-$drillId-${at.toIso8601String()}'`.

- [ ] **Step 1: Setup.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat pub get`, then `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs`, then `cd server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm ci`. Expected: all three exit 0.

- [ ] **Step 2: Write the failing tests** in `test/domain/skill_test/skill_test_test.dart`:

```dart
final a1 = stById('a1');
final t2 = stById('t2');
Drill withThreshold(double t) => stDrill('x', SkillCategory.aiming, 1, passThreshold: t);

group('skillTestPassed — cùng tiêu chí với buổi tập (drillRatio ≥ 1)', () {
  test('bài đếm cú: 8/10 với ngưỡng 0.8 là đạt, 7/10 là trượt', () {
    expect(skillTestPassed(a1, score: 8, attempts: 10), isTrue);
    expect(skillTestPassed(a1, score: 7, attempts: 10), isFalse);
  });
  test('bài mục tiêu: 25 với mục tiêu 25 là đạt, 24.5 là trượt', () {
    expect(skillTestPassed(t2, score: 25), isTrue);
    expect(skillTestPassed(t2, score: 24.5), isFalse);
  });
  test('thiếu số lần thử thì không chấm được, không quy về trượt', () {
    expect(skillTestPassed(a1, score: 8), isNull);
    expect(skillTestPassed(a1, score: 8, attempts: 0), isNull);
  });
});

group('passMark', () {
  test('ngưỡng tỉ lệ ra số lần đạt nhỏ nhất, khớp drillRatio', () {
    expect(passMark(withThreshold(0.8), attempts: 10), 8);
    expect(passMark(withThreshold(0.7), attempts: 10), 7);
    expect(passMark(withThreshold(0.6), attempts: 15), 9);
    expect(passMark(withThreshold(0.5), attempts: 10), 5);
  });
  test('bài mục tiêu trả mục tiêu; bài đếm cú thiếu số lần thử trả null', () {
    expect(passMark(t2), 25);
    expect(passMark(a1), isNull);
  });
});

// Review Focus 2
group('checkSkillTestInput', () {
  test('kết quả hợp lệ', () {
    expect(checkSkillTestInput(a1, score: 8, attempts: 10), isNull);
    expect(checkSkillTestInput(t2, score: 22.5), isNull);
  });
  test('mỗi kiểu kết quả bịa ra một lỗi có tên', () {
    expect(checkSkillTestInput(a1, score: 11, attempts: 10), SkillTestInputError.scoreAboveAttempts);
    expect(checkSkillTestInput(a1, score: 8.5, attempts: 10), SkillTestInputError.scoreNotWhole);
    expect(checkSkillTestInput(a1, score: -1, attempts: 10), SkillTestInputError.scoreInvalid);
    expect(checkSkillTestInput(a1, score: double.infinity, attempts: 10), SkillTestInputError.scoreInvalid);
    expect(checkSkillTestInput(a1, score: double.nan, attempts: 10), SkillTestInputError.scoreInvalid);
    expect(checkSkillTestInput(a1, score: 8), SkillTestInputError.attemptsRequired);
    expect(checkSkillTestInput(a1, score: 0, attempts: 0), SkillTestInputError.attemptsInvalid);
    expect(checkSkillTestInput(t2, score: 25, attempts: 10), SkillTestInputError.attemptsNotAllowed);
  });
});

group('SkillTest', () {
  test('chỉ lần hoàn tất, đạt, không huỷ mới chứng nhận', () {
    expect(passedTest('a1', 1, stToday).certifies, isTrue);
    expect([failedTest('a1', 1, stToday).certifies, failedTest('a1', 1, stToday).failed], [false, true]);
    expect([cancelledTest('a1', 1, stToday).certifies, cancelledTest('a1', 1, stToday).failed], [false, false]);
  });
  // Review Focus 4
  test('lần hoàn tất thiếu kết quả chấm (dữ liệu hỏng) không phải đạt, cũng không phải trượt', () {
    final broken = SkillTest(id: 'x', drillId: 'a1', drillLevel: 1, tableSize: TableSize.nineFootPlus,
        startedAt: stToday, completedAt: stToday);
    expect([broken.isCompleted, broken.certifies, broken.failed], [true, false, false]);
  });
});
```

Append to `test/architecture_test.dart`: `test('lõi Skill Test không phụ thuộc Flutter, không dùng Vi, không có chuỗi tiếng Việt, không dựng PlayerRank', …)`. It runs over `dartFilesIn('lib/domain/skill_test')` and expects the list to be non-empty. For each file, `codeOnly(source)` must not contain `package:flutter`, `core/strings/vi.dart`, `PlayerRank(`, `player_rank.dart` or `rank_rules.dart`, and must have no `vietnameseLiteral` match. The reason is `'cổng mở cấp do luật quyết định, không đổi hạng (README quy tắc 2; spec skill test mục 2)'`.

- [ ] **Step 3: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/skill_test/skill_test_test.dart test/architecture_test.dart`. Expected: FAIL because `skill_test.dart` is not found, and the new architecture test fails because `lib/domain/skill_test` does not exist.

- [ ] **Step 4: Implement** `skill_test.dart` and the fixtures as in the Interfaces block.

- [ ] **Step 5: Run the same command.** Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/domain/skill_test test/support/skill_test_fixtures.dart test/domain/skill_test test/architecture_test.dart
git commit -m "Skill Test: mô hình, chấm đạt theo drillRatio, kiểm tra kết quả nhập

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Gate, certifications and Profile summary

**Files:**
- Create: `lib/domain/skill_test/certification.dart`
- Create: `lib/domain/skill_test/skill_test_gate.dart`
- Create: `lib/domain/skill_test/certification_summary.dart`
- Create: `test/domain/skill_test/skill_test_gate_test.dart`
- Create: `test/domain/skill_test/certification_test.dart`

**Interfaces:**
- Consumes: Task 1 (`SkillTest`, `SkillTestConstants`, fixtures), `consecutivePassCount` and `computePlayerIntelligence` (`lib/domain/player_intelligence.dart:127-163`), `drillRatio`, `PracticeConstants.readyStreak`.
- Produces (`certification.dart`):
  - `final class Certification { const Certification({required String testId, required String drillId, required int drillLevel, required TableSize tableSize, required DateTime certifiedAt}); }`
  - `Map<String, Certification> certificationsOf(Iterable<SkillTest> tests)`: one entry per `drillId` from tests where `certifies` is true. It keeps the earliest `completedAt`, breaking ties by `id` ascending. Map order follows first certification time.
  - `List<Drill> nextLevelDrills(Drill drill, List<Drill> drills)`: drills with the same `cat` at the smallest `level > drill.level`, sorted by `id`. Empty when there is none.
  - `bool recentFormSlipped(Drill drill, List<DrillLog> logs)`: takes this drill's logs sorted by (`date`, `id`). Returns `false` when there are fewer than `recentFormWindow`. Otherwise returns `true` when none of the last `recentFormWindow` logs has `drillRatio ≥ 1`, where `null` counts as not passing. ★ Plan's call 9.
- Produces (`skill_test_gate.dart`):
  - `sealed class SkillTestGate { const SkillTestGate(); }`, with these subclasses:
    - `final class SkillTestOpen extends SkillTestGate { const SkillTestOpen(); }`
    - `final class AlreadyCertified extends SkillTestGate { const AlreadyCertified(this.at); final DateTime at; }`
    - `final class NeedLowerLevel extends SkillTestGate { const NeedLowerLevel(this.drillIds); final List<String> drillIds; }`
    - `final class NeedStreak extends SkillTestGate { const NeedStreak(this.missing); final int missing; }`
    - `final class NeedPracticeAfterFail extends SkillTestGate { const NeedPracticeAfterFail(this.failedAt); final DateTime failedAt; }`
  - `SkillTestGate skillTestGate({required Drill drill, required List<Drill> drills, required List<DrillLog> logs, required List<SkillTest> tests})`, checked in this order (★ plan's call 7):
    1. If `certificationsOf(tests)[drill.id]` exists, return `AlreadyCertified(certifiedAt)`.
    2. If any drills share `drill.cat`, have `level < drill.level` and are uncertified, return `NeedLowerLevel` with their ids sorted by (level, id).
    3. Compute `n = consecutivePassCount(drill, logs of drill.id)`. If `n < readyStreak`, return `NeedStreak(readyStreak − n)`.
    4. Take the latest test of this drill where `failed` is true (by `completedAt`). If fewer than `retakeSessions` logs of this drill have `date.isAfter(that.completedAt!)`, return `NeedPracticeAfterFail(that.completedAt!)`. ★ Plan's call 8.
    5. Otherwise return `SkillTestOpen()`.
  - `List<String> testableDrillIds({required List<Drill> drills, required List<DrillLog> logs, required List<SkillTest> tests})`: ids whose gate is `SkillTestOpen`, sorted by (level, id).
- Produces (`certification_summary.dart`):
  - `typedef CertifiedDrill = ({Drill drill, Certification certification});`
  - `final class CertificationGroup { const CertificationGroup({required SkillCategory cat, required List<CertifiedDrill> entries, required bool complete}); }`
  - `typedef ReadyHint = ({Drill drill, int passCount});`
  - `final class CertificationSummary { const CertificationSummary({required List<CertificationGroup> groups, required ReadyHint? closest}); }`
  - `CertificationSummary certificationSummary({required List<Drill> drills, required List<DrillLog> logs, required List<SkillTest> tests})`. Groups follow `SkillCategory.values` order, and only categories with ≥ 1 certified library drill appear. Entries are sorted by (level, id), and `complete` means every library drill of the category is certified. Certifications whose `drillId` is not in `drills` are skipped. `closest` is ★ plan's call 13: among library drills whose gate is neither `AlreadyCertified` nor `NeedLowerLevel` and whose `consecutivePassCount ≥ 1`, it takes the highest count, then the lowest level, then the lowest id. It is `null` when there is none.

- [ ] **Step 1: Write the failing tests.**

`test/domain/skill_test/skill_test_gate_test.dart`:

```dart
SkillTestGate g(String id, {List<DrillLog> logs = const [], List<SkillTest> tests = const []}) =>
    skillTestGate(drill: stById(id), drills: stDrills, logs: logs, tests: tests);
Matcher needStreak(int n) => isA<NeedStreak>().having((x) => x.missing, 'missing', n);
Matcher needLower(List<String> ids) => isA<NeedLowerLevel>().having((x) => x.drillIds, 'drillIds', ids);

test('bài thấp nhất nhóm, chưa có buổi: cần thêm 3 buổi đạt liên tiếp', () => expect(g('a1'), needStreak(3)));
test('hai buổi đạt: còn thiếu 1', () => expect(g('a1', logs: threePasses('a1').skip(1).toList()), needStreak(1)));
test('đủ 3 buổi đạt ở bài thấp nhất nhóm: mở', () => expect(g('a1', logs: threePasses('a1')), isA<SkillTestOpen>()));
// Review Focus 5
test('cấp không liên tục: a3 (cấp 3) cần chứng nhận a1 (cấp 1) trước, dù đủ chuỗi', () {
  expect(g('a3', logs: threePasses('a3')), needLower(['a1']));
  expect(g('a3', logs: threePasses('a3'), tests: [passedTest('a1', 1, stToday.subtract(const Duration(days: 5)))]),
      isA<SkillTestOpen>());
});
test('cổng cấp đứng trước chuỗi buổi: a3 chưa tập vẫn báo cần a1', () => expect(g('a3'), needLower(['a1'])));
test('cùng cấp không chặn nhau: p2a mở khi p2b chưa chứng nhận', () => expect(g('p2a', logs: threePasses('p2a')), isA<SkillTestOpen>()));
test('cấp trùng: p3 cần cả hai bài cấp 2, liệt kê bài còn thiếu theo (cấp, id)', () {
  expect(g('p3', logs: threePasses('p3')), needLower(['p2a', 'p2b']));
  expect(g('p3', logs: threePasses('p3'), tests: [passedTest('p2a', 2, stToday)]), needLower(['p2b']));
  expect(g('p3', logs: threePasses('p3'), tests: [passedTest('p2a', 2, stToday), passedTest('p2b', 2, stToday)]),
      isA<SkillTestOpen>());
});
test('đã chứng nhận: ngày của lần đạt sớm nhất, kể cả khi chuỗi đã đứt', () {
  final early = stToday.subtract(const Duration(days: 9));
  final late = stToday.subtract(const Duration(days: 2));
  expect(g('a1', logs: [stLog('a1', 2, stToday.subtract(const Duration(hours: 1)))],
          tests: [passedTest('a1', 1, late), passedTest('a1', 1, early)]),
      isA<AlreadyCertified>().having((x) => x.at, 'at', early));
});
test('vừa trượt, chưa tập thêm: phải tập ít nhất 1 buổi', () {
  final failedAt = stToday.subtract(const Duration(hours: 2));
  expect(g('a1', logs: threePasses('a1'), tests: [failedTest('a1', 1, failedAt)]),
      isA<NeedPracticeAfterFail>().having((x) => x.failedAt, 'failedAt', failedAt));
});
test('trượt rồi tập thêm một buổi đạt: mở lại', () {
  final logs = [...threePasses('a1'), stLog('a1', 9, stToday.subtract(const Duration(hours: 1)))];
  expect(g('a1', logs: logs, tests: [failedTest('a1', 1, stToday.subtract(const Duration(hours: 2)))]), isA<SkillTestOpen>());
});
test('trượt rồi tập thêm một buổi trượt: chuỗi về 0, cần 3 buổi', () {
  final logs = [...threePasses('a1'), stLog('a1', 5, stToday.subtract(const Duration(hours: 1)))];
  expect(g('a1', logs: logs, tests: [failedTest('a1', 1, stToday.subtract(const Duration(hours: 2)))]), needStreak(3));
});
test('lần huỷ không tính là trượt', () {
  expect(g('a1', logs: threePasses('a1'), tests: [cancelledTest('a1', 1, stToday.subtract(const Duration(hours: 2)))]),
      isA<SkillTestOpen>());
});
test('bài mục tiêu: 3 buổi đạt mục tiêu 25 thì mở', () {
  final logs = [for (var i = 3; i >= 1; i--) stLog('t2', 25, stToday.subtract(Duration(days: i)), attempts: null)];
  expect(g('t2', logs: logs), isA<SkillTestOpen>());
});
test('testableDrillIds: chỉ bài mở, xếp (cấp, id), là tập con của readyDrillIds', () {
  final logs = [...threePasses('a1'), ...threePasses('a3'), ...threePasses('p2a')];
  expect(testableDrillIds(drills: stDrills, logs: logs, tests: const []), ['a1', 'p2a']);
  expect(computePlayerIntelligence(drills: stDrills, logs: logs).readyDrillIds, ['a1', 'a3', 'p2a']);
});
```

`test/domain/skill_test/certification_test.dart`:

```dart
test('certificationsOf: mỗi bài một chứng nhận, lấy lần đạt sớm nhất; trượt, huỷ, hỏng không tính', () {
  final early = stToday.subtract(const Duration(days: 9));
  final certs = certificationsOf([
    passedTest('a1', 1, stToday), passedTest('a1', 1, early),
    failedTest('p2a', 2, stToday), cancelledTest('p2b', 2, stToday),
    SkillTest(id: 'broken', drillId: 'p3', drillLevel: 3, tableSize: TableSize.eightFoot, startedAt: stToday, completedAt: stToday),
  ]);
  expect(certs.keys, ['a1']);
  expect([certs['a1']!.certifiedAt, certs['a1']!.drillLevel, certs['a1']!.testId], [early, 1, 'pass-a1-${early.toIso8601String()}']);
});
test('nextLevelDrills: cấp nhỏ nhất lớn hơn, bỏ qua khoảng trống; bài cao nhất nhóm không có cấp tiếp', () {
  expect(nextLevelDrills(stById('a1'), stDrills).map((d) => d.id), ['a3']);
  expect(nextLevelDrills(stById('p2b'), stDrills).map((d) => d.id), ['p3']);
  expect(nextLevelDrills(stById('a3'), stDrills), isEmpty);
  expect(nextLevelDrills(stById('t2'), stDrills), isEmpty);
});
group('recentFormSlipped', () {
  List<DrillLog> after(List<int> made) =>
      [for (final (i, m) in made.indexed) stLog('a1', m, stToday.add(Duration(hours: i + 1)))];
  test('5 buổi gần nhất đều trượt', () => expect(recentFormSlipped(stById('a1'), [...threePasses('a1'), ...after([5, 5, 5, 5, 5])]), isTrue));
  test('4 buổi trượt, cửa sổ 5 còn một buổi đạt', () => expect(recentFormSlipped(stById('a1'), [...threePasses('a1'), ...after([5, 5, 5, 5])]), isFalse));
  test('buổi mới nhất đạt', () => expect(recentFormSlipped(stById('a1'), [...threePasses('a1'), ...after([5, 5, 5, 5, 5, 9])]), isFalse));
  test('chưa đủ 5 buổi thì không kết luận', () => expect(recentFormSlipped(stById('a1'), after([5, 5])), isFalse));
});
group('certificationSummary', () {
  test('nhóm theo thứ tự SkillCategory; nhóm đủ bài là thuần thục', () {
    final s = certificationSummary(drills: stDrills, logs: const [], tests: [
      passedTest('p3', 3, stToday), passedTest('p2b', 2, stToday), passedTest('p2a', 2, stToday), passedTest('a1', 1, stToday)]);
    expect(s.groups.map((g) => g.cat), [SkillCategory.aiming, SkillCategory.position]);
    expect(s.groups[0].complete, isFalse);
    expect(s.groups[1].entries.map((e) => e.drill.id), ['p2a', 'p2b', 'p3']);
    expect(s.groups[1].complete, isTrue);
  });
  test('chưa có chứng nhận: gợi ý bài nhiều buổi đạt liên tiếp nhất mà cổng cấp đã qua', () {
    final logs = [...threePasses('a1').skip(1), ...threePasses('a3'), stLog('p2a', 9, stToday)];
    final s = certificationSummary(drills: stDrills, logs: logs, tests: const []);
    expect(s.groups, isEmpty);
    expect([s.closest!.drill.id, s.closest!.passCount], ['a1', 2]);
  });
  test('hoà số buổi: bài cấp thấp hơn trước', () {
    final s = certificationSummary(drills: stDrills, tests: const [],
        logs: [stLog('p2b', 9, stToday), stLog('a1', 9, stToday), stLog('p2a', 9, stToday)]);
    expect(s.closest!.drill.id, 'a1');
  });
  test('không bài nào có buổi đạt: không gợi ý', () {
    expect(certificationSummary(drills: stDrills, logs: [stLog('a1', 2, stToday)], tests: const []).closest, isNull);
  });
  // Review Focus 4
  test('chứng nhận của bài không còn trong thư viện thì bỏ qua, không ném', () {
    expect(certificationSummary(drills: stDrills, logs: const [], tests: [passedTest('zz', 2, stToday)]).groups, isEmpty);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/skill_test`. Expected: FAIL because the new files are missing.
- [ ] **Step 3: Implement** the three files as in the Interfaces block.
- [ ] **Step 4: Run the same command, plus `test/architecture_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit** with `"Skill Test: cổng mở bài kiểm tra (chuỗi buổi, cổng cấp, làm lại), chứng nhận và tóm tắt"` plus the trailer.

---

### Task 3: `AchievementKind.chungNhan`

**Files:**
- Modify: `lib/domain/roadmap/achievements.dart` (enum :10, `newAchievements` :37)
- Modify: `lib/core/strings/vi.dart` (`Vi.achievement` ~:1891)
- Modify: `test/domain/roadmap/achievements_test.dart`, `test/core/strings/vi_roadmap_test.dart` (~:141), `test/data/database/roadmap_converters_test.dart`, `test/data/sync/roadmap_sync_test.dart` (~:134), `test/data/repositories/roadmap_repository_test.dart`, `test/features/roadmap/roadmap_screen_test.dart` (~:225)

**Interfaces:**
- Consumes: Task 2 `certificationsOf`.
- Produces:
  - `enum AchievementKind { xongBuoc, duDieuKienLenCap, chuoiNgay, chungNhan }`.
  - `List<Achievement> newAchievements({required PlayerGoal? goal, required List<Drill> drills, required List<DrillLog> logs, required Set<String> existing, required DateTime today, List<SkillTest> skillTests = const []})`. For each `Certification c` in `certificationsOf(skillTests).values`, it calls `add(AchievementKind.chungNhan, c.drillId, c.certifiedAt)`. This is ★ plan's calls 5 and 17. Existing callers compile unchanged.
  - `Vi.achievement`: `AchievementKind.chungNhan => 'Chứng nhận: $subject'`. `RoadmapView._subject` already maps a drill-id `refId` to the drill name, so it needs no change.

- [ ] **Step 1: Write the failing tests.**

```dart
// achievements_test.dart — new group
group('chứng nhận (Skill Test)', () {
  List<Achievement> certs(List<SkillTest> tests, {Set<String> existing = const {}}) => newAchievements(
          goal: null, drills: stDrills, logs: const [], existing: existing, today: stToday, skillTests: tests)
      .where((a) => a.kind == AchievementKind.chungNhan)
      .toList();
  test('lần đạt ra đúng một chứng nhận, ngày là ngày hoàn tất; trượt và huỷ không', () {
    final at = stToday.subtract(const Duration(days: 1));
    expect(certs([passedTest('a1', 1, at), failedTest('p2a', 2, at), cancelledTest('p2b', 2, at)]),
        [Achievement(kind: AchievementKind.chungNhan, refId: 'a1', achievedAt: at)]);
  });
  test('đã có thì không ghi lại', () => expect(certs([passedTest('a1', 1, stToday)], existing: {'chungNhan|a1'}), isEmpty));
  test('tính lại từ lần kiểm tra khớp certificationsOf', () {
    final tests = [passedTest('a1', 1, stToday.subtract(const Duration(days: 3))), passedTest('a1', 1, stToday), passedTest('p2a', 2, stToday)];
    expect({for (final a in certs(tests)) a.refId: a.achievedAt},
        {for (final c in certificationsOf(tests).values) c.drillId: c.certifiedAt});
  });
});
// vi_roadmap_test.dart, inside test('thành tích')
expect(Vi.achievement(AchievementKind.chungNhan, 'Bài A'), 'Chứng nhận: Bài A');
// roadmap_converters_test.dart
test('chứng nhận: hai máy cùng người ra cùng id, qua Directus về nguyên vẹn', () {
  final a = Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: at);
  final b = Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: at.add(const Duration(hours: 3)));
  expect(achievementId('u1', a), achievementId('u1', b));
  final row = toAchievementRow(a, userId: 'u1');
  expect(toAchievement(achievementFromRemote(toRemoteAchievement(row), userId: 'u1', syncedAt: at)), a);
});
// roadmap_sync_test.dart
test('kéo thành tích chứng nhận từ máy chủ về', () async {
  final a = Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: older);
  serve(achievements: [toRemoteAchievement(toAchievementRow(a, userId: 'u1'))]);
  await build().syncNow();
  expect(toAchievement(await db.select(db.achievementRows).getSingle()), a);
});
// roadmap_repository_test.dart
test('ghi chứng nhận hai lần (hai máy) chỉ còn một dòng', () async {
  final a = Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: DateTime(2026, 10, 12));
  await repo('u1').recordAchievements([a]);
  await repo('u1').recordAchievements([a]);
  expect(await repo('u1').watchAchievements().first, [a]);
});
// roadmap_screen_test.dart — copy the chuoiNgay test at ~:224, with
//   achievements: [Achievement(kind: AchievementKind.chungNhan, refId: 'd1', achievedAt: at)]
// and scroll to / expect find.text(Vi.achievement(AchievementKind.chungNhan, 'Đường thẳng cơ bản')) findsOneWidget.
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/roadmap test/core/strings test/data/database/roadmap_converters_test.dart test/data/sync/roadmap_sync_test.dart test/data/repositories/roadmap_repository_test.dart test/features/roadmap`. Expected: FAIL because `chungNhan` is not defined.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run the same command, plus `test/architecture_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit** with `"Thành tích chứng nhận (chungNhan) tính từ lần kiểm tra đạt"` plus the trailer.

---

### Task 4: Drift v15, converters, repository, sign-out

**Files:**
- Modify: `lib/data/database/database.dart`: add `SkillTestRows` after `BuDrillResultRows` (~:248), add it to `@DriftDatabase(tables:)` (:345), set `schemaVersion` to 15 (:370), add the migration step after :453.
- Create: `lib/data/database/skill_test_converters.dart`
- Create: `lib/data/repositories/skill_test_repository.dart`
- Modify: `lib/data/sync/account_actions.dart` (`signOutAndForget` :59, `pendingAssessmentCount` :126)
- Modify: `test/data/database/migration_test.dart`. Change every `expect(db.schemaVersion, 14)` to `15`, add two tests, and add the helper `_createV14AchievementTable`.
- Create: `test/data/database/skill_test_converters_test.dart`, `test/data/repositories/skill_test_repository_test.dart`
- Modify: `test/data/sync/account_actions_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2 (`SkillTest`, `checkSkillTestInput`, `skillTestPassed`, `skillTestGate`, `SkillTestGate`).
- Produces:
  - Table `SkillTestRows` (`skill_test_rows`), with columns:
    - `TextColumn id`, `userId`, `drillId`
    - `IntColumn drillLevel`
    - `TextColumn tableSize` (`TableSize.name`)
    - `DateTimeColumn startedAt`
    - `DateTimeColumn completedAt`, `cancelledAt` (nullable)
    - `RealColumn score` (nullable)
    - `IntColumn attempts` (nullable)
    - `BoolColumn passed` (nullable, `boolean().nullable()()`)
    - `TextColumn notes` (nullable)
    - `DateTimeColumn syncedAt` (nullable)
    - primary key `{id}`

    The doc comment reads "chỉ thêm, ghi một lần khi xong (hoàn tất hoặc huỷ)".
  - Migration step: `if (from < 15) { await m.createTable(skillTestRows); }`. This only adds a table, so no existing data is touched.
  - `skill_test_converters.dart` (mirrors `roadmap_converters.dart`):
    - `SkillTest toSkillTest(SkillTestRow r)`, using `TableSize.values.byName`.
    - `SkillTestRow toSkillTestRow(SkillTest t, {required String userId, DateTime? syncedAt})`, with `score: t.score?.toDouble()`.
    - `const remoteSkillTestFields = 'id,drill_id,drill_level,table_size,started_at,completed_at,cancelled_at,score,attempts,passed,notes';`
    - `Map<String, Object?> toRemoteSkillTest(SkillTestRow r)`: the same keys, timestamps as `toUtc().toIso8601String()`, and no `user_created`.
    - `SkillTestRow skillTestFromRemote(Map<String, Object?> j, {required String userId, required DateTime syncedAt})`: timestamps go through `.toLocal()`, and `score` is `(j['score'] as num?)?.toDouble()`.
  - `skill_test_repository.dart`:
    - `sealed class SkillTestOutcome { const SkillTestOutcome(); }`
    - `final class SkillTestRecorded extends SkillTestOutcome { const SkillTestRecorded(this.test); final SkillTest test; }`
    - `final class SkillTestLocked extends SkillTestOutcome { const SkillTestLocked(this.gate); final SkillTestGate gate; }`
    - `class SkillTestRepository { SkillTestRepository(this._db, {required this._userId, required this._now, required this._newId}); … }`, with the same constructor shape as `RoadmapRepository`, and these members:
      - `Stream<List<SkillTest>> watchTests()`: rows of `_userId` only, ordered by `startedAt` descending.
      - `Future<SkillTestOutcome> completeTest({required Drill drill, required List<Drill> drills, required List<DrillLog> logs, required TableSize tableSize, required DateTime startedAt, required num score, int? attempts, String? notes})`. When `checkSkillTestInput` returns non-null, it throws `ArgumentError` **before** writing anything. Then, inside `_db.transaction`, it reads this user's tests with `get()` and recomputes `skillTestGate`. If the gate is not `SkillTestOpen`, it returns `SkillTestLocked(gate)` and writes nothing. Otherwise it inserts one row with:
        - `id: _newId()`
        - `drillLevel: drill.level`
        - `tableSize.name`
        - `startedAt`
        - `completedAt: _now()`
        - `score`
        - `attempts`
        - `passed: skillTestPassed(...)!`
        - `notes`
        - `syncedAt: null`

        It then returns `SkillTestRecorded(test)`.
      - `Future<void> cancelTest({required Drill drill, required TableSize tableSize, required DateTime startedAt})`: inserts a row with `cancelledAt: _now()` and no score, attempts or `passed`. ★ Plan's call 3.
  - `signOutAndForget` also runs `db.delete(db.skillTestRows)..where(userId == userId)`. `pendingAssessmentCount` also adds that user's `skill_test_rows` with `syncedAt IS NULL` (every row is finished, by ★ plan's call 2).

- [ ] **Step 1: Write the failing tests.**

```dart
// migration_test.dart
test('nâng từ v14 lên v15 thêm bảng lần kiểm tra kỹ năng, giữ nguyên thành tích', () async {
  final executor = NativeDatabase.memory(setup: (raw) {
    _createV14AchievementTable(raw);
    raw.execute("INSERT INTO achievement_rows VALUES ('ach1', 'u1', 'chuoiNgay', '7', 1760400000, NULL);");
    raw.execute('PRAGMA user_version = 14;');
  });
  final db = AppDatabase.forTesting(executor);
  addTearDown(db.close);
  expect(db.schemaVersion, 15);
  final kept = (await db.select(db.achievementRows).get()).single;
  expect([kept.id, kept.kind, kept.refId, kept.syncedAt], ['ach1', 'chuoiNgay', '7', null]);
  expect(await db.select(db.skillTestRows).get(), isEmpty);
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, DateTime(2026, 10, 28, 10)), userId: 'u1'));
  expect((await db.select(db.skillTestRows).getSingle()).passed, isTrue);
});
test('tạo mới ở v15 ghi và đọc được lần kiểm tra kỹ năng đã huỷ', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.skillTestRows).insert(toSkillTestRow(cancelledTest('d1', 1, DateTime(2026, 10, 28, 10)), userId: 'u1'));
  final row = await db.select(db.skillTestRows).getSingle();
  expect([row.cancelledAt, row.completedAt, row.score, row.passed], [DateTime(2026, 10, 28, 10), null, null, null]);
});
/// Bảng thành tích đúng hình dạng v14 (có từ v4).
void _createV14AchievementTable(dynamic raw) {
  raw.execute('CREATE TABLE achievement_rows (id TEXT NOT NULL, user_id TEXT NOT NULL, kind TEXT NOT NULL, '
      'ref_id TEXT NOT NULL, achieved_at INTEGER NOT NULL, synced_at INTEGER NULL, '
      'PRIMARY KEY (id), UNIQUE (user_id, kind, ref_id));');
}
```

```dart
// skill_test_converters_test.dart
final t = SkillTest(id: 'st', drillId: 'a1', drillLevel: 1, tableSize: TableSize.eightFoot,
    startedAt: DateTime(2026, 10, 28, 9, 40), completedAt: DateTime(2026, 10, 28, 10), score: 9, attempts: 10, passed: true, notes: 'n');
test('qua dòng Drift, Directus rồi về nguyên vẹn; không gửi chủ', () {
  final row = toSkillTestRow(t, userId: 'u1');
  expect(toSkillTest(row), t);
  final remote = toRemoteSkillTest(row);
  expect(remote.containsKey('user_created'), isFalse);
  expect(remote['completed_at'], DateTime(2026, 10, 28, 10).toUtc().toIso8601String());
  final back = skillTestFromRemote(remote, userId: 'u1', syncedAt: DateTime(2026, 10, 28, 11));
  expect([toSkillTest(back), back.userId, back.syncedAt], [t, 'u1', DateTime(2026, 10, 28, 11)]);
});
test('điểm số nguyên từ máy chủ đọc thành số thực; bài mục tiêu giữ số lẻ', () {
  final remote = toRemoteSkillTest(toSkillTestRow(t, userId: 'u1'))..['score'] = 9;
  expect(skillTestFromRemote(remote, userId: 'u1', syncedAt: DateTime(2026, 10, 28)).score, 9.0);
  final target = SkillTest(id: 'tg', drillId: 't2', drillLevel: 2, tableSize: TableSize.sevenFoot,
      startedAt: DateTime(2026, 10, 28, 9), completedAt: DateTime(2026, 10, 28, 9, 30), score: 22.5, passed: false);
  expect(toSkillTest(skillTestFromRemote(toRemoteSkillTest(toSkillTestRow(target, userId: 'u1')), userId: 'u1', syncedAt: DateTime(2026, 10, 28))), target);
});
```

```dart
// skill_test_repository_test.dart — db memory; ids 'st1', 'st2', …; now = () => stToday
late AppDatabase db; late SkillTestRepository repo; var n = 0;
setUp(() { db = AppDatabase.forTesting(NativeDatabase.memory()); n = 0;
  repo = SkillTestRepository(db, userId: 'u1', now: () => stToday, newId: () => 'st${++n}'); });
tearDown(() => db.close());
Future<SkillTestOutcome> submit(String id, num score, {int? attempts = 10, List<DrillLog>? logs}) => repo.completeTest(
    drill: stById(id), drills: stDrills, logs: logs ?? threePasses(id), tableSize: TableSize.eightFoot,
    startedAt: stToday.subtract(const Duration(minutes: 20)), score: score, attempts: attempts, notes: 'bàn hơi nhanh');

test('đạt: ghi một dòng đủ cột cho mọi nơi đọc', () async {
  expect(await submit('a1', 9), isA<SkillTestRecorded>().having((o) => o.test.passed, 'passed', true));
  final r = await db.select(db.skillTestRows).getSingle();
  expect([r.id, r.userId, r.drillId, r.drillLevel, r.tableSize, r.startedAt, r.completedAt, r.cancelledAt, r.score, r.attempts, r.passed, r.notes, r.syncedAt],
      ['st1', 'u1', 'a1', 1, 'eightFoot', stToday.subtract(const Duration(minutes: 20)), stToday, null, 9.0, 10, true, 'bàn hơi nhanh', null]);
});
test('trượt: passed false, vẫn có điểm', () async {
  await submit('a1', 7);
  final r = await db.select(db.skillTestRows).getSingle();
  expect([r.score, r.passed, r.completedAt], [7.0, false, stToday]);
});
test('cổng chưa mở: không ghi gì, trả lý do', () async {
  expect(await submit('a3', 9), isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<NeedLowerLevel>()));
  expect(await db.select(db.skillTestRows).get(), isEmpty);
});
// Review Focus 1
test('nộp hai lần liền sau khi đạt: lần hai bị chặn vì đã chứng nhận, chỉ một dòng', () async {
  await submit('a1', 9);
  expect(await submit('a1', 9), isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<AlreadyCertified>()));
  expect(await db.select(db.skillTestRows).get(), hasLength(1));
});
test('trượt rồi nộp ngay lần nữa: bị chặn vì chưa tập thêm', () async {
  await submit('a1', 7);
  expect(await submit('a1', 9), isA<SkillTestLocked>().having((o) => o.gate, 'gate', isA<NeedPracticeAfterFail>()));
});
// Review Focus 2
test('kết quả không hợp lệ thì ném, không ghi', () async {
  await expectLater(submit('a1', 11), throwsArgumentError);
  await expectLater(submit('t2', 25, logs: const []), throwsArgumentError); // attempts on a target drill
  expect(await db.select(db.skillTestRows).get(), isEmpty);
});
test('huỷ: dòng huỷ không có kết quả', () async {
  await repo.cancelTest(drill: stById('a1'), tableSize: TableSize.sevenFoot, startedAt: stToday.subtract(const Duration(minutes: 5)));
  final r = await db.select(db.skillTestRows).getSingle();
  expect([r.cancelledAt, r.completedAt, r.score, r.attempts, r.passed, r.drillLevel, r.tableSize], [stToday, null, null, null, null, 1, 'sevenFoot']);
});
test('chỉ thấy lần kiểm tra của chính mình, mới nhất trước', () async {
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('a1', 1, stToday, id: 'old'), userId: 'u1'));
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('p2a', 2, stToday.add(const Duration(hours: 1)), id: 'new'), userId: 'u1'));
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('a1', 1, stToday, id: 'other'), userId: 'u2'));
  expect((await repo.watchTests().first).map((t) => t.id), ['new', 'old']);
});
```

```dart
// account_actions_test.dart — Review Focus 3
test('đăng xuất xoá lần kiểm tra kỹ năng của người đó, giữ của người khác', () async {
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, DateTime(2026, 10, 28, 10), id: 'st-u1'), userId: 'u1'));
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, DateTime(2026, 10, 28, 10), id: 'st-u2'), userId: 'u2'));
  await signOutAndForget(db: db, auth: FakeAuthRepository.signedIn(), userId: 'u1', forgetChatInFlight: (_) {});
  expect((await db.select(db.skillTestRows).get()).map((r) => r.id), ['st-u2']);
});
test('lần kiểm tra kỹ năng chưa đồng bộ tính vào phần đánh giá', () async {
  final at = DateTime(2026, 10, 28, 10);
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, at, id: 'cho'), userId: 'u1'));
  await db.into(db.skillTestRows).insert(toSkillTestRow(failedTest('d1', 1, at, id: 'da'), userId: 'u1', syncedAt: at));
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, at, id: 'khac'), userId: 'u2'));
  expect(await pendingAssessmentCount(db, 'u1'), 1);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/data`. Expected: FAIL because `skillTestRows` and the converters are missing.
- [ ] **Step 3: Implement** as in the Interfaces block. Then run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run the same command.** Expected: PASS, including every existing migration test now expecting 15.
- [ ] **Step 5: Commit** with `"Skill Test: bảng skill_test_rows (Drift v15), repository chỉ thêm, xoá khi đăng xuất"` plus the trailer.

---

### Task 5: Sync and Directus `skill_tests`

**Files:**
- Modify: `lib/data/sync/assessment_sync.dart` (`watchPendingAssessment` :15, `_once` :120-124, new `_pushSkillTests` and `_pullSkillTests`)
- Modify: `deploy/directus/bootstrap.mjs`: collection after `bu_drill_results` (~:270), permissions after `bu_drill_results` (~:490).
- Modify: `deploy/directus/verify.mjs`: inside the "Đánh giá + hạng" block after the `bu_tests` checks (~:154), and in the achievements block (~:468).
- Modify: `test/data/sync/assessment_sync_test.dart` (the `serve()` helper :40 plus new tests), `test/features/profile/profile_screen_test.dart` (fake Directus routes ~:137)

**Interfaces:**
- Consumes: Task 4 converters and table.
- Produces:
  - `watchPendingAssessment(db)` also counts `(SELECT COUNT(*) FROM skill_test_rows WHERE synced_at IS NULL)`. Its `readsFrom` gains `db.skillTestRows`.
  - `_once`: `_pushFinishedTests` → **`_pushSkillTests`** → `_syncRank` → `_pullTests` → **`_pullSkillTests`**.
  - `_pushSkillTests(userId)`: this user's rows with `syncedAt IS NULL`, ordered by `startedAt`. It skips ids in `_rejected` and calls `_create('/items/skill_tests', toRemoteSkillTest(r), userId)`, where `RECORD_NOT_UNIQUE` counts as success. A 4xx other than 401 adds the id to `_rejected` and continues. On success it writes `syncedAt: _now()`.
  - `_pullSkillTests(userId)`: `GET /items/skill_tests` with `limit=-1` and `fields=remoteSkillTestFields`, then `_checkAlive()` and the user check, then a batch `insert(skillTestFromRemote(…), mode: InsertMode.insertOrIgnore)`. ★ Plan's call 4: append-only, local wins.
  - Directus:
    - `ensureCollection('skill_tests', 'Lần kiểm tra kỹ năng (Skill Test) đã xong hoặc đã huỷ — chỉ thêm', [pk, required('drill_id', 'string'), required('drill_level', 'integer'), required('table_size', 'string'), required('started_at', 'timestamp'), nullable('completed_at', 'timestamp'), nullable('cancelled_at', 'timestamp'), nullable('score', 'float'), nullable('attempts', 'integer'), nullable('passed', 'boolean'), nullable('notes', 'text')])`.
    - Permissions are `{ collection: 'skill_tests', action: 'create', fields: [the 11 field names above, id first], permissions: {}, validation: {} }` and `{ collection: 'skill_tests', action: 'read', fields: ['*'], permissions: { user_created: self } }`, with no update and no delete.
    - The `achievements` schema is unchanged.

- [ ] **Step 1: Write the failing tests** in `assessment_sync_test.dart`. Extend `serve()` with `List<Map<String, Object?>> skillTests = const []`, plus `server.routes['GET /items/skill_tests'] = (_) => FakeDirectus.ok(skillTests);` and `server.routes['POST /items/skill_tests'] = (req) => FakeDirectus.ok(jsonDecode(req.body));`. Without these routes every existing test would fail on the new GET.

```dart
test('lần kiểm tra kỹ năng chưa đồng bộ: POST đủ trường, không gửi chủ, rồi đánh dấu', () async {
  serve();
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, older), userId: 'u1'));
  expect(await build().syncNow(), SyncOutcome.done);
  final body = FakeDirectus.body(server.sent('POST', '/items/skill_tests').single);
  expect([body['drill_id'], body['drill_level'], body['table_size'], body['score'], body['attempts'], body['passed']],
      ['d1', 1, 'nineFootPlus', 9.0, 10, true]);
  expect(body.containsKey('user_created'), isFalse);
  expect((await db.select(db.skillTestRows).getSingle()).syncedAt, now);
});
test('máy chủ báo RECORD_NOT_UNIQUE: coi là đã đồng bộ', () async {
  serve();
  server.routes['POST /items/skill_tests'] = (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, older), userId: 'u1'));
  await build().syncNow();
  expect((await db.select(db.skillTestRows).getSingle()).syncedAt, now);
});
test('máy chủ từ chối (403): nằm chờ, hạng vẫn đồng bộ', () async {
  serve();
  server.routes['POST /items/skill_tests'] = (_) => FakeDirectus.error(403, 'FORBIDDEN');
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, older), userId: 'u1'));
  expect(await build().syncNow(), SyncOutcome.done);
  expect((await db.select(db.skillTestRows).getSingle()).syncedAt, isNull);
  expect(fetches, [('u1', RankFetch.foundNone)]);
});
// Review Focus 4
test('kéo lần kiểm tra kỹ năng về; dòng cùng id đã có trên máy giữ nguyên', () async {
  Map<String, Object?> remote(SkillTest t) => toRemoteSkillTest(toSkillTestRow(t, userId: 'u1'));
  serve(skillTests: [remote(passedTest('d1', 1, older, id: 'st-x')), remote(passedTest('d1', 1, older, id: 'st-remote'))]);
  await db.into(db.skillTestRows).insert(toSkillTestRow(failedTest('d1', 1, newer, id: 'st-x'), userId: 'u1'));
  await build().syncNow();
  final rows = {for (final r in await db.select(db.skillTestRows).get()) r.id: r};
  expect(rows['st-x']!.passed, isFalse);
  expect([rows['st-remote']!.passed, rows['st-remote']!.syncedAt, rows['st-remote']!.userId], [true, now, 'u1']);
});
test('đếm dòng chờ gồm lần kiểm tra kỹ năng', () async {
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, older), userId: 'u1'));
  expect(await watchPendingAssessment(db).first, 1);
});
```

In `profile_screen_test.dart` (~:137), add `..routes['GET /items/skill_tests'] = ((_) => FakeDirectus.ok([]))` and `..routes['POST /items/skill_tests'] = ((req) => FakeDirectus.ok(jsonDecode(req.body)))`.

In `verify.mjs`, with the file's own `call` / `ok` / `fail` / `note` helpers:
1. Build `const skill = { id: randomUUID(), drill_id: 'd1', drill_level: 1, table_size: 'eightFoot', started_at: '2026-10-28T02:40:00.000Z', completed_at: '2026-10-28T03:00:00.000Z', cancelled_at: null, score: 9, attempts: 10, passed: true, notes: null }`.
2. A's POST returns 200 (`'A tạo được lần kiểm tra kỹ năng'`).
3. Resending the same POST returns code `RECORD_NOT_UNIQUE` (`'gửi lại lần kiểm tra kỹ năng cùng id → RECORD_NOT_UNIQUE (app coi là đã đồng bộ)'`).
4. A's PATCH `{ passed: false }` returns 403 (`'A không sửa được lần kiểm tra kỹ năng'`).
5. A's DELETE returns 403 (`'A không xoá được lần kiểm tra kỹ năng'`).
6. B's GET `/items/skill_tests` returns empty (`'B không thấy lần kiểm tra kỹ năng của A'`).
7. In the achievements block, A's POST `{ id: randomUUID(), kind: 'chungNhan', ref_id: 'd1', achieved_at: '2026-10-28T03:00:00.000Z' }` returns 200 (`'A tạo được thành tích chứng nhận (kind là chuỗi tự do)'`).

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/data/sync/assessment_sync_test.dart`. Expected: the new tests FAIL with no POST to `/items/skill_tests`.
- [ ] **Step 3: Implement** the sync, `bootstrap.mjs` and `verify.mjs`. Then run `node --check deploy/directus/bootstrap.mjs && node --check deploy/directus/verify.mjs`. Expected: exit 0. Do **not** run them.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/data test/features/profile`. Expected: PASS.
- [ ] **Step 5: Commit** with `"Skill Test: đồng bộ skill_tests (chỉ thêm) và collection Directus"` plus the trailer.

---

### Task 6: Providers and the achievement recorder

**Files:**
- Create: `lib/core/providers/skill_test_providers.dart`
- Modify: `lib/core/providers/roadmap_providers.dart` (`achievementRecorderProvider` :101-117)
- Modify: `test/support/test_data.dart` (`testContainer` :82)
- Create: `test/core/providers/skill_test_providers_test.dart`
- Modify: `test/core/providers/roadmap_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 2 and 4, `gate()`, `drillsProvider`, `drillLogsProvider`, `currentUserIdProvider`, `appDatabaseProvider`, `nowProvider`.
- Produces:
  - `final skillTestRepositoryProvider = Provider<SkillTestRepository?>`. It is `null` when signed out, and otherwise `SkillTestRepository(db, userId:, now: ref.watch(nowProvider), newId: const Uuid().v4)`, the same as `roadmapRepositoryProvider`.
  - `final skillTestsProvider = StreamProvider<List<SkillTest>>`. When the repository is `null` it yields `Stream.value(const [])`, else `repo.watchTests()`.
  - `final certificationsProvider = Provider<AsyncValue<Map<String, Certification>>>`, gated on `[skillTests]`.
  - `final skillTestGateProvider = Provider.family<AsyncValue<SkillTestGate?>, String>`, gated on `[drills, logs, skillTests]`. Its value is `null` when the drill id is not in the library.
  - `final certificationSummaryProvider = Provider<AsyncValue<CertificationSummary>>`, gated on `[drills, logs, skillTests]`.
  - `final testableDrillIdsProvider = Provider<AsyncValue<List<String>>>`, gated on `[drills, logs, skillTests]` (★ plan's call 12).
  - `achievementRecorderProvider` also watches `skillTestsProvider`. Its early return becomes `if (repo == null || gate<void>([goal, drills, logs, existing, skillTests]) != null) return;`, and it passes `skillTests: skillTests.value!` to `newAchievements`.
  - `testContainer({…, List<SkillTest>? skillTests, AsyncValue<List<SkillTest>>? skillTestsAsync})`. `skillTestsAsync` wins and uses `skillTestsProvider.overrideWithValue(...)`. Otherwise it uses `skillTestsProvider.overrideWith((ref) => Stream.value(skillTests ?? const <SkillTest>[]))`. Keep the override list untyped. `dbContainer` stays as is, so it reads the real repository.

- [ ] **Step 1: Write the failing tests.**

```dart
// skill_test_providers_test.dart
Future<void> settle() async { for (var i = 0; i < 5; i++) { await pumpEventQueue(); } }
ProviderContainer make({List<DrillLog>? logs, List<SkillTest>? tests, AsyncValue<List<SkillTest>>? asyncTests}) {
  final c = testContainer(logs: logs, skillTests: tests, skillTestsAsync: asyncTests);
  addTearDown(c.dispose);
  c.listen(skillTestGateProvider('d1'), (_, _) {});
  c.listen(certificationsProvider, (_, _) {});
  c.listen(certificationSummaryProvider, (_, _) {});
  c.listen(testableDrillIdsProvider, (_, _) {});
  return c;
}

test('d1 đủ 3 buổi đạt: cổng mở, có trong danh sách sẵn sàng kiểm tra', () async {
  final c = make(logs: threePasses('d1', before: testToday));
  await settle();
  expect(c.read(skillTestGateProvider('d1')).value, isA<SkillTestOpen>());
  expect(c.read(testableDrillIdsProvider).value, ['d1']);
});
test('đã chứng nhận: cổng báo đã chứng nhận, danh sách sẵn sàng rỗng, có trong chứng nhận', () async {
  final c = make(logs: threePasses('d1', before: testToday), tests: [passedTest('d1', 1, testToday)]);
  await settle();
  expect(c.read(skillTestGateProvider('d1')).value, isA<AlreadyCertified>());
  expect(c.read(testableDrillIdsProvider).value, isEmpty);
  expect(c.read(certificationsProvider).value!.keys, ['d1']);
});
test('bài không có trong thư viện: cổng là null, không ném', () async {
  final c = testContainer();
  addTearDown(c.dispose);
  c.listen(skillTestGateProvider('zz'), (_, _) {});
  await settle();
  expect([c.read(skillTestGateProvider('zz')).hasValue, c.read(skillTestGateProvider('zz')).value], [true, null]);
});
// Review Focus 3
test('nguồn lần kiểm tra lỗi: mọi provider thành lỗi, không quay mãi', () async {
  final c = make(logs: threePasses('d1', before: testToday), asyncTests: AsyncError<List<SkillTest>>(StateError('hỏng'), StackTrace.empty));
  await settle();
  expect([c.read(skillTestGateProvider('d1')).hasError, c.read(certificationsProvider).hasError,
      c.read(certificationSummaryProvider).hasError, c.read(testableDrillIdsProvider).hasError], [true, true, true, true]);
});
test('đang tải lại còn chứng nhận của người trước: là đang tải, không dùng giá trị cũ', () async {
  // ignore: invalid_use_of_internal_member
  final stale = const AsyncLoading<List<SkillTest>>().copyWithPrevious(AsyncData<List<SkillTest>>([passedTest('d1', 1, testToday)]));
  final c = make(logs: threePasses('d1', before: testToday), asyncTests: stale);
  await settle();
  expect([c.read(skillTestGateProvider('d1')).isLoading, c.read(certificationsProvider).isLoading,
      c.read(testableDrillIdsProvider).isLoading], [true, true, true]);
});

// roadmap_providers_test.dart
test('bộ ghi thành tích ghi chứng nhận từ lần kiểm tra đạt, ngày là ngày hoàn tất', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.skillTestRows).insert(toSkillTestRow(passedTest('d1', 1, DateTime(2026, 9, 21, 20)), userId: 'u1'));
  final container = dbContainer(db);
  addTearDown(container.dispose);
  container.listen(achievementRecorderProvider, (_, _) {});
  await settle();
  final row = (await db.select(db.achievementRows).get()).where((r) => r.kind == AchievementKind.chungNhan.name).single;
  expect([row.refId, row.achievedAt], ['d1', DateTime(2026, 9, 21, 20)]);
});
test('lần kiểm tra trượt không ra chứng nhận', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.skillTestRows).insert(toSkillTestRow(failedTest('d1', 1, DateTime(2026, 9, 21, 20)), userId: 'u1'));
  final container = dbContainer(db);
  addTearDown(container.dispose);
  container.listen(achievementRecorderProvider, (_, _) {});
  await settle();
  expect((await db.select(db.achievementRows).get()).where((r) => r.kind == AchievementKind.chungNhan.name), isEmpty);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/core/providers`. Expected: FAIL because `skill_test_providers.dart` is missing.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/core test/features/roadmap`. Expected: PASS.
- [ ] **Step 5: Commit** with `"Skill Test: provider có cổng (gate) và ghi chứng nhận vào thành tích"` plus the trailer.

---

### Task 7: Route and the Skill Test screen

**Files:**
- Modify: `lib/core/router/routes.dart`: `skillTestPattern` and `skillTest()` next to `drillSessionPattern` (:41), and in `all` right after `drillSessionPattern`.
- Modify: `lib/core/router/app_router.dart`: inside the training branch `routes:` list, after `drills/:id` (~:116-131).
- Create: `lib/features/training/presentation/skill_test_screen.dart`
- Modify: `lib/core/strings/vi.dart`: new section `// Skill Test và chứng nhận (spec 2026-10-28)` after the session strings (~:715).
- Modify: `test/core/router/routes_test.dart`, `test/support/route_cases.dart` (`signedInRouteCases`)
- Create: `test/features/training/skill_test_screen_test.dart`

**Interfaces:**
- Consumes: Task 6 providers, Task 4 `SkillTestRepository` / `SkillTestOutcome`, Task 1 `checkSkillTestInput`, `passMark`, Task 2 `nextLevelDrills`.
- Produces:
  - `Routes.skillTestPattern = '$training/skill-test/:id'` and `static String skillTest(String id) => '$training/skill-test/$id';`. ★ Plan's call 1.
  - `GoRoute(path: 'skill-test/:id', builder: (context, state) => SkillTestScreen(drillId: state.pathParameters['id']!))`.
  - `class SkillTestScreen extends ConsumerStatefulWidget { const SkillTestScreen({required this.drillId, super.key}); final String drillId; }`, wrapped in `PcRootScaffold(title: Vi.skillTestTitle(drill.name))`. Drill loading, error and not-found states follow `DrillSessionScreen`. The screen has three phases held in `State` (★ plan's call 2):
    1. **Prep** (`_startedAt == null`) shows:
       - `Vi.skillTestConditionsTitle`
       - `Vi.buTableSizeLabel`, plus one `ChoiceChip(label: Text(Vi.buTableSize(s)))` per `TableSize`, defaulting to `nineFootPlus`
       - `Vi.drillStepsTitle` and the numbered steps
       - `Vi.skillTestCriterion(drill)`
       - `FilledButton(Vi.skillTestStart)`, enabled only when `ref.watch(skillTestGateProvider(drillId)).value is SkillTestOpen`. Pressing it sets `_startedAt = ref.read(nowProvider)()`.
       - When the gate is not open, the line `Vi.skillTestGateLine(gate, nameOf: …)`.
       - `TextButton(Vi.cancel)`, which goes to `Routes.drill(id)` and writes nothing.

       While the gate loads it shows a spinner. On a gate error it shows `PcEmptyState(dataErrorTitle/Body)`.
    2. **Entry** (`_startedAt != null && _result == null`) shows a `Form` with these fields:
       - The score `TextFormField`, labelled `Vi.sessionScoreLabelAttempts` or `Vi.sessionScoreLabelTarget`. Its validator returns `Vi.sessionScoreRequired` or `Vi.sessionScoreInvalid` on a parse failure. Otherwise it returns `Vi.skillTestInputError(e)` when `checkSkillTestInput(drill, score:, attempts: int.tryParse(attemptsText))` gives `scoreInvalid`, `scoreNotWhole` or `scoreAboveAttempts`.
       - An attempts field (`Vi.sessionAttemptsLabel`) only when `drill.usesAttempts`. Its validator returns `Vi.sessionAttemptsRequired` when empty, and `Vi.skillTestInputError(e)` for `attemptsRequired` or `attemptsInvalid`.
       - A notes field (`Vi.sessionNotesLabel`). An empty note is stored as `null`.

       Below the form:
       - `FilledButton(Vi.skillTestSubmit)` calls `repo.completeTest(drill:, drills:, logs: ref.read(drillLogsProvider).value!, tableSize: _size, startedAt: _startedAt!, …)`. It is disabled while busy. A `SkillTestRecorded` result sets `_result`. A `SkillTestLocked(gate)` result shows a SnackBar `Vi.skillTestGateLine(gate, …)` and returns to prep.
       - `OutlinedButton(Vi.skillTestCancel)` calls `repo.cancelTest(...)`, shows a SnackBar `Vi.skillTestCancelled`, then runs `context.go(Routes.drill(id))`.
    3. **Result** (`_result != null`) is shown **regardless of the current gate** (Review Focus 1). Each line below is its own `Text`, so tests can find it with `find.text`.
       - A pass shows `Vi.skillTestPassed(drill.name, drill.level)` and `Vi.shortDate(_result.completedAt!)`. Then it shows `Vi.skillTestNextLevel(names)` when `nextLevelDrills(drill, drills)` is non-empty, else `Vi.skillTestNoNextLevel`.
       - A fail shows `Vi.skillTestFailed(_result.score!, passMark(drill, attempts: _result.attempts)!)`, `Vi.skillTestFailedAdvice` and `Vi.skillTestRetakeRule`.
       - Both cases end with `FilledButton(Vi.skillTestBackToDrill)`, which goes to `Routes.drill(id)`.
  - `Vi` (exact copy):

```dart
static String skillTestTitle(String drillName) => 'Kiểm tra: $drillName';
static const skillTestConditionsTitle = 'Điều kiện đo';
static String skillTestCriterion(Drill drill) => drill.usesAttempts
    ? 'Tiêu chí đạt: từ ${(drill.passThreshold! * 100).round()}% số lần thử'
    : 'Tiêu chí đạt: từ ${skillTestNumber(drill.target!)} — ${drill.unit}';
static const skillTestStart = 'Bắt đầu kiểm tra';
static const skillTestSubmit = 'Nộp kết quả';
static const skillTestCancel = 'Huỷ bài kiểm tra';
static const skillTestCancelled = 'Đã huỷ bài kiểm tra. Không có kết quả nào được lưu.';
static String skillTestPassed(String drillName, int level) => 'Đã chứng nhận $drillName — cấp $level';
static String skillTestFailed(num score, num mark) => 'Chưa đạt: ${skillTestNumber(score)}/${skillTestNumber(mark)}';
static const skillTestFailedAdvice = 'Tập thêm bài này rồi kiểm tra lại';
static const skillTestRetakeRule =
    'Cần ít nhất ${SkillTestConstants.retakeSessions} buổi tập mới của bài này trước lần kiểm tra lại.';
static String skillTestNextLevel(List<String> names) => 'Cấp tiếp theo trong nhóm: ${names.join(', ')}';
static const skillTestNoNextLevel = 'Chưa có cấp tiếp theo trong nhóm này';
static const skillTestBackToDrill = 'Về bài tập';
static String skillTestNumber(num n) => n == n.truncate() ? '${n.truncate()}' : '$n';
static String skillTestGateLine(SkillTestGate gate, {required String Function(String drillId) nameOf}) => switch (gate) {
      SkillTestOpen() => 'Đủ điều kiện làm bài kiểm tra',
      AlreadyCertified(:final at) => 'Đã chứng nhận ngày ${shortDate(at)}',
      NeedLowerLevel(:final drillIds) => 'Cần chứng nhận ${drillIds.map(nameOf).join(', ')} trước',
      NeedStreak(:final missing) => 'Cần thêm $missing buổi đạt liên tiếp',
      NeedPracticeAfterFail() => skillTestRetakeRule,
    };
static String skillTestInputError(SkillTestInputError e) => switch (e) {
      SkillTestInputError.scoreInvalid => sessionScoreInvalid,
      SkillTestInputError.scoreNotWhole => 'Số lần đạt phải là số nguyên',
      SkillTestInputError.scoreAboveAttempts => 'Số lần đạt không được lớn hơn số lần thử',
      SkillTestInputError.attemptsRequired => sessionAttemptsRequired,
      SkillTestInputError.attemptsInvalid => sessionAttemptsInvalid,
      SkillTestInputError.attemptsNotAllowed => 'Bài này không chấm theo số lần thử',
    };
```

- [ ] **Step 1: Write the failing tests.**

In `routes_test.dart`, add `Routes.skillTestPattern` to the expected `all` list right after `Routes.drillSessionPattern`. Then add `expect(Routes.skillTest('d3'), '/training/skill-test/d3');`, `expect(Routes.skillTest('x'), Routes.skillTestPattern.replaceAll(':id', 'x'));` and `test('Skill Test nằm trong nhánh Luyện tập', () => expect(Routes.skillTestPattern, '${Routes.training}/skill-test/:id'));`.

In `route_cases.dart`, add `Routes.skillTestPattern: (path: '/training/skill-test/d1', screen: SkillTestScreen),`.

`skill_test_screen_test.dart` (db memory; `dbContainer(db, logs: …)`; `testDrills` = `d1` 'Đường thẳng cơ bản', level 1, 0.8; `testToday` = 22/09/2026 10:00):

```dart
late AppDatabase db;
setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
tearDown(() => db.close());
Future<GoRouter> open(WidgetTester tester, {List<DrillLog>? logs}) async {
  final container = dbContainer(db, logs: logs ?? threePasses('d1', before: testToday));
  addTearDown(container.dispose);
  final router = createAppRouter(auth: signedInGate());
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: PoolCoachApp(router: router)));
  await tester.pumpAndSettle();
  router.go(Routes.skillTest('d1'));
  await tester.pumpAndSettle();
  return router;
}
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}
Future<void> start(WidgetTester tester, {TableSize size = TableSize.nineFootPlus}) async {
  await tapText(tester, Vi.buTableSize(size));
  await tapText(tester, Vi.skillTestStart);
}
Future<void> enter(WidgetTester tester, String score, String attempts) async {
  await tester.enterText(find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts), score);
  await tester.enterText(find.widgetWithText(TextFormField, Vi.sessionAttemptsLabel), attempts);
  await tapText(tester, Vi.skillTestSubmit);
}

testWidgets('chuẩn bị hiện điều kiện đo: kích thước bàn, các bước, tiêu chí', (tester) async {
  await open(tester);
  expect(find.text(Vi.skillTestTitle('Đường thẳng cơ bản')), findsOneWidget);
  for (final s in TableSize.values) { expect(find.text(Vi.buTableSize(s)), findsOneWidget); }
  expect(find.text('Bước 1'), findsOneWidget);
  expect(find.text(Vi.skillTestCriterion(testDrills.single)), findsOneWidget);
});
// Review Focus 1: after submit the gate is AlreadyCertified, yet the result stays on screen.
testWidgets('đạt: chứng nhận kèm ngày, không có cấp tiếp theo; một dòng đủ cột', (tester) async {
  await open(tester);
  await start(tester, size: TableSize.eightFoot);
  await enter(tester, '9', '10');
  expect(find.text(Vi.skillTestPassed('Đường thẳng cơ bản', 1)), findsOneWidget);
  expect(find.text(Vi.shortDate(testToday)), findsOneWidget);
  expect(find.text(Vi.skillTestNoNextLevel), findsOneWidget);
  expect(find.text(Vi.skillTestGateLine(AlreadyCertified(testToday), nameOf: (id) => id)), findsNothing);
  final r = (await db.select(db.skillTestRows).get()).single;
  expect([r.drillId, r.drillLevel, r.tableSize, r.score, r.attempts, r.passed, r.startedAt, r.completedAt],
      ['d1', 1, 'eightFoot', 9.0, 10, true, testToday, testToday]);
});
testWidgets('trượt: Chưa đạt 7/8, lời khuyên tại bàn và luật làm lại', (tester) async {
  await open(tester);
  await start(tester);
  await enter(tester, '7', '10');
  expect(find.text(Vi.skillTestFailed(7, 8)), findsOneWidget);
  expect(find.text(Vi.skillTestFailedAdvice), findsOneWidget);
  expect(find.text(Vi.skillTestRetakeRule), findsOneWidget);
  expect((await db.select(db.skillTestRows).get()).single.passed, isFalse);
});
testWidgets('huỷ giữa chừng: về chi tiết bài, dòng huỷ không có kết quả', (tester) async {
  await open(tester);
  await start(tester);
  await tester.enterText(find.widgetWithText(TextFormField, Vi.sessionScoreLabelAttempts), '9');
  await tapText(tester, Vi.skillTestCancel);
  expect(find.byType(DrillDetailScreen), findsOneWidget);
  final r = (await db.select(db.skillTestRows).get()).single;
  expect([r.cancelledAt, r.score, r.passed], [testToday, null, null]);
});
testWidgets('huỷ ở bước chuẩn bị: không ghi gì', (tester) async {
  await open(tester);
  await tapText(tester, Vi.cancel);
  expect(find.byType(DrillDetailScreen), findsOneWidget);
  expect(await db.select(db.skillTestRows).get(), isEmpty);
});
// Review Focus 2
testWidgets('số lần đạt lớn hơn số lần thử: báo lỗi, không ghi', (tester) async {
  await open(tester);
  await start(tester);
  await enter(tester, '11', '10');
  expect(find.text(Vi.skillTestInputError(SkillTestInputError.scoreAboveAttempts)), findsOneWidget);
  expect(await db.select(db.skillTestRows).get(), isEmpty);
});
testWidgets('mở thẳng đường dẫn khi chưa đủ điều kiện: hiện lý do, nút bắt đầu bị khoá', (tester) async {
  await open(tester, logs: const []);
  expect(find.text(Vi.skillTestGateLine(const NeedStreak(3), nameOf: (id) => id)), findsOneWidget);
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, Vi.skillTestStart)).onPressed, isNull);
});
testWidgets('360×640 chữ lớn: chuẩn bị và nhập kết quả không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);
  await open(tester);
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
  await start(tester);
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/core/router test/features/training/skill_test_screen_test.dart`. Expected: FAIL because the route and the screen are missing.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/core/router test/features/training test/smoke test/architecture_test.dart`. Expected: PASS. The smoke grid now also opens `/training/skill-test/d1` at every size.
- [ ] **Step 5: Commit** with `"Skill Test: màn kiểm tra (điều kiện đo, nhập kết quả, đạt/trượt/huỷ) tại /training/skill-test/:id"` plus the trailer.

---

### Task 8: Drill detail test card and the Training badge

**Files:**
- Create: `lib/features/training/presentation/skill_test_card.dart`
- Modify: `lib/features/training/presentation/drill_detail_screen.dart`: after the `_ReadinessCard` block (~:142-145), outside the `logsAsync.hasValue` condition.
- Modify: `lib/features/training/presentation/training_screen.dart`: drill tile subtitle (~:213-222).
- Modify: `lib/core/strings/vi.dart` (Skill Test section)
- Modify: `test/features/training/drill_detail_screen_test.dart` (`openDrill` gains `List<Drill>? drills` and `List<SkillTest> skillTests = const []`), `test/features/training/training_screen_test.dart` (`openTraining` gains `{List<SkillTest> skillTests = const []}`)

**Interfaces:**
- Consumes: Task 6 `skillTestGateProvider`, `certificationsProvider`, Task 2 `recentFormSlipped`, Task 7 `Routes.skillTest` and `Vi.skillTestGateLine`.
- Produces:
  - `class SkillTestCard extends ConsumerWidget { const SkillTestCard({required this.drill, super.key}); final Drill drill; }`. It renders nothing while the gate loads or when the gate is `null`. On a gate error it shows `Text(Vi.skillTestDataError)`. Otherwise it renders a `PcCard` with the title `Vi.skillTestCardTitle`, followed by one of:
    - `SkillTestOpen`: the line plus `FilledButton(Vi.skillTestOpen)`, which runs `context.go(Routes.skillTest(drill.id))`.
    - `AlreadyCertified`: the line, plus `Text(Vi.skillTestFormSlipped)` when `recentFormSlipped(drill, logs)`.
    - Any other gate: the line only.

    The line is always `Vi.skillTestGateLine(gate, nameOf: (id) => drills[id]?.name ?? id)`.
  - Training tile: when `ref.watch(certificationsProvider).value?.containsKey(drill.id) == true`, the subtitle gains `Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 16), SizedBox(width: 4), Flexible(child: Text(Vi.certifiedBadge))])`.
  - `Vi`: `static const skillTestCardTitle = 'Bài kiểm tra'; static const skillTestOpen = 'Làm bài kiểm tra'; static const skillTestFormSlipped = 'Phong độ gần đây chưa đạt'; static const certifiedBadge = 'Đã chứng nhận'; static const skillTestDataError = 'Chưa tải được dữ liệu bài kiểm tra.';`

- [ ] **Step 1: Write the failing tests.** In `drill_detail_screen_test.dart`, `ListView` is the only list on the drill detail screen:

```dart
Future<void> reveal(WidgetTester tester, Finder f) =>
    tester.dragUntilVisible(f, find.byType(ListView), const Offset(0, -200));

testWidgets('đủ 3 buổi đạt: có nút Làm bài kiểm tra, bấm thì mở màn kiểm tra', (tester) async {
  await openDrill(tester, 'd1', logs: threePasses('d1', before: testToday));
  final button = find.widgetWithText(FilledButton, Vi.skillTestOpen);
  await reveal(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byType(SkillTestScreen), findsOneWidget);
});
testWidgets('thiếu buổi đạt: không có nút, nói còn thiếu mấy buổi', (tester) async {
  await openDrill(tester, 'd1', logs: threePasses('d1', before: testToday).skip(1).toList());
  final reason = find.text(Vi.skillTestGateLine(const NeedStreak(1), nameOf: (id) => id));
  await reveal(tester, reason);
  expect(reason, findsOneWidget);
  expect(find.widgetWithText(FilledButton, Vi.skillTestOpen), findsNothing);
});
testWidgets('cấp cao hơn: nêu tên bài cấp thấp hơn cần chứng nhận', (tester) async {
  const d2 = Drill(id: 'd2', cat: SkillCategory.aiming, name: 'Bi ảo', level: 3, unit: 'lần trúng / 15',
      passThreshold: 0.6, goal: 'g', steps: ['Bước 1']);
  await openDrill(tester, 'd2', drills: [...testDrills, d2], logs: threePasses('d2', before: testToday));
  final reason = find.text(Vi.skillTestGateLine(const NeedLowerLevel(['d1']), nameOf: (_) => 'Đường thẳng cơ bản'));
  await reveal(tester, reason);
  expect(reason, findsOneWidget);
});
testWidgets('đã chứng nhận, 5 buổi gần nhất đều trượt: ngày chứng nhận và Phong độ gần đây chưa đạt', (tester) async {
  final certifiedAt = testToday.subtract(const Duration(days: 6));
  await openDrill(tester, 'd1',
      logs: [...threePasses('d1', before: testToday.subtract(const Duration(days: 10))),
        for (var i = 5; i >= 1; i--) stLog('d1', 5, testToday.subtract(Duration(days: i)))],
      skillTests: [passedTest('d1', 1, certifiedAt)]);
  final certified = find.text(Vi.skillTestGateLine(AlreadyCertified(certifiedAt), nameOf: (id) => id));
  await reveal(tester, certified);
  expect(certified, findsOneWidget);
  expect(find.text(Vi.skillTestFormSlipped), findsOneWidget);
});
```

In `training_screen_test.dart`:

```dart
testWidgets('bài đã chứng nhận có huy hiệu Đã chứng nhận', (tester) async {
  await openTraining(tester, const [], skillTests: [passedTest('d1', 1, testToday)]);
  expect(find.text(Vi.certifiedBadge), findsOneWidget);
});
testWidgets('bài trượt kiểm tra không có huy hiệu', (tester) async {
  await openTraining(tester, const [], skillTests: [failedTest('d1', 1, testToday)]);
  expect(find.text(Vi.certifiedBadge), findsNothing);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/training/drill_detail_screen_test.dart test/features/training/training_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/training test/smoke test/architecture_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** with `"Skill Test: thẻ kiểm tra ở chi tiết bài (mở/khoá có lý do, phong độ) và huy hiệu Đã chứng nhận"` plus the trailer.

---

### Task 9: Profile "Chứng nhận", Home line, rich data

**Files:**
- Create: `lib/features/profile/presentation/certification_section.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`: after the equipment `Card` (:150-158), as `const SizedBox(height: AppSpacing.lg), const CertificationSection(),`.
- Create: `lib/features/home/presentation/skill_test_home_line.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`: right after `const RoadmapHomeLine(),` (:125).
- Modify: `lib/core/strings/vi.dart` (Skill Test section)
- Modify: `test/support/rich_data.dart` (`richContainer` :50)
- Create: `test/features/profile/certification_section_test.dart`
- Modify: `test/features/home/home_screen_test.dart` (`openHome` gains `List<SkillTest>? skillTests`)

**Interfaces:**
- Consumes: Task 6 `certificationSummaryProvider`, `testableDrillIdsProvider`, Task 7 `Routes.skillTest`, `Vi.skillTestNoNextLevel`, Task 8 `Vi.skillTestDataError`.
- Produces:
  - `class CertificationSection extends ConsumerWidget { const CertificationSection({super.key}); }`. It shows nothing while loading and `Text(Vi.skillTestDataError)` on error. Otherwise it shows the title `Text(Vi.certificationTitle, style: titleMedium)`. When `groups` is empty, it then shows `Vi.certificationEmpty`, followed by `closest == null ? Vi.certificationNoProgress : Vi.certificationClosest(closest.drill.name, closest.passCount)`. Otherwise, for each group it shows `PcSkillChip(category: g.cat)`. A `complete` group also gets `Vi.certificationGroupDone` and `Vi.skillTestNoNextLevel`. Every group then lists one `Text(Vi.certificationEntry(e.drill.name, e.certification.drillLevel, e.certification.certifiedAt))` per entry.
  - `class SkillTestHomeLine extends ConsumerWidget { const SkillTestHomeLine({super.key}); }`. It is hidden while loading or when the list is empty. On error it shows `Padding(top: 16)` around `PcCard(Text(Vi.skillTestDataError))`. Otherwise it shows `Padding(top: 16)` around `PcCard(ListTile(leading: Icon(Icons.verified_outlined), title: Text(Vi.homeSkillTestReady(first.name, ids.length - 1)), trailing: Icon(Icons.chevron_right), onTap: () => context.go(Routes.skillTest(first.id))))`, where `first` is the drill of `ids.first`. ★ Plan's call 12.
  - `Vi` (exact):

```dart
static const certificationTitle = 'Chứng nhận';
static const certificationEmpty = 'Chưa có chứng nhận';
static String certificationClosest(String drillName, int count) =>
    'Gần sẵn sàng nhất: $drillName — $count/${PracticeConstants.readyStreak} buổi đạt liên tiếp';
static const certificationNoProgress = 'Chưa bài nào có buổi đạt liên tiếp.';
static String certificationEntry(String drillName, int level, DateTime at) => '$drillName — cấp $level — ${shortDate(at)}';
static const certificationGroupDone = 'Đã chứng nhận toàn nhóm';
static String homeSkillTestReady(String drillName, int more) =>
    more == 0 ? 'Sẵn sàng kiểm tra: $drillName' : 'Sẵn sàng kiểm tra: $drillName (và $more bài khác)';
```

  - `richContainer()` adds `skillTests: [failedTest('d1', 1, testToday.subtract(const Duration(days: 3, hours: 12)))]`. Its `d1` logs (8/10 daily, `testToday` − 1…7 days) still have three logs after that failure, so in the sweep `d1` is testable and Profile shows the empty state with "3/3".

- [ ] **Step 1: Write the failing tests.**

`certification_section_test.dart`:

```dart
Future<void> pumpSection(WidgetTester tester, ProviderContainer c) async {
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CertificationSection())))));
  await tester.pumpAndSettle();
}

testWidgets('chưa có chứng nhận: nói thẳng và gợi ý bài gần sẵn sàng nhất', (tester) async {
  await pumpSection(tester, testContainer(logs: threePasses('d1', before: testToday).skip(1).toList()));
  expect(find.text(Vi.certificationEmpty), findsOneWidget);
  expect(find.text(Vi.certificationClosest('Đường thẳng cơ bản', 2)), findsOneWidget);
});
testWidgets('chưa có buổi đạt nào: không bịa gợi ý', (tester) async {
  await pumpSection(tester, testContainer(logs: [stLog('d1', 2, testToday)]));
  expect(find.text(Vi.certificationNoProgress), findsOneWidget);
});
testWidgets('có chứng nhận: nhóm kỹ năng, tên bài, cấp, ngày; nhóm đủ bài là thuần thục', (tester) async {
  await pumpSection(tester, testContainer(skillTests: [passedTest('d1', 1, testToday)]));
  expect(find.text(Vi.skill(SkillCategory.aiming)), findsOneWidget);
  expect(find.text(Vi.certificationEntry('Đường thẳng cơ bản', 1, testToday)), findsOneWidget);
  expect(find.text(Vi.certificationGroupDone), findsOneWidget);
  expect(find.text(Vi.skillTestNoNextLevel), findsOneWidget);
});
testWidgets('Hồ sơ có mục Chứng nhận ngay sau thẻ Thiết bị', (tester) async {
  applyScreen(tester, const Size(800, 1600));
  final router = await pumpRoutedApp(tester, container: testContainer(skillTests: [passedTest('d1', 1, testToday)]));
  router.go(Routes.profile);
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(find.text(Vi.certificationTitle)).dy,
      greaterThan(tester.getTopLeft(find.text(Vi.equipmentTitle)).dy));
});
testWidgets('360×640 chữ lớn: Hồ sơ có chứng nhận không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0);
  final router = await pumpRoutedApp(tester, container: testContainer(skillTests: [passedTest('d1', 1, testToday)]));
  router.go(Routes.profile);
  await tester.pumpAndSettle();
  await scrollThroughAll(tester);
  expect(tester.takeException(), isNull);
});
```

In `home_screen_test.dart`:

```dart
testWidgets('có bài sẵn sàng kiểm tra: một dòng mở thẳng màn kiểm tra', (tester) async {
  await openHome(tester, logs: threePasses('d1', before: testToday));
  final line = find.text(Vi.homeSkillTestReady('Đường thẳng cơ bản', 0));
  await tester.dragUntilVisible(line, find.byType(ListView), const Offset(0, -200));
  await tester.tap(line);
  await tester.pumpAndSettle();
  expect(find.byType(SkillTestScreen), findsOneWidget);
});
Future<void> pumpLine(WidgetTester tester, ProviderContainer c) async {
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: SkillTestHomeLine()))));
  await tester.pumpAndSettle();
}
testWidgets('đã chứng nhận: không còn dòng sẵn sàng kiểm tra', (tester) async {
  await pumpLine(tester, testContainer(logs: threePasses('d1', before: testToday), skillTests: [passedTest('d1', 1, testToday)]));
  expect(find.byType(ListTile), findsNothing);
});
testWidgets('nhiều bài sẵn sàng: nêu bài cấp thấp nhất và số bài còn lại', (tester) async {
  const d7 = Drill(id: 'd7', cat: SkillCategory.safety, name: 'Đẩy sát băng', level: 2, unit: 'lần / 10',
      passThreshold: 0.7, goal: 'g', steps: []);
  await pumpLine(tester, testContainer(drills: [...testDrills, d7],
      logs: [...threePasses('d1', before: testToday), ...threePasses('d7', before: testToday)]));
  expect(find.text(Vi.homeSkillTestReady('Đường thẳng cơ bản', 1)), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify they fail.** Run `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features/profile test/features/home`. Expected: FAIL.
- [ ] **Step 3: Implement** as in the Interfaces block.
- [ ] **Step 4: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/features test/smoke test/architecture_test.dart`. Expected: PASS. The sweep now meets the Home line and the Profile empty state at every size.
- [ ] **Step 5: Commit** with `"Skill Test: mục Chứng nhận ở Hồ sơ và dòng Sẵn sàng kiểm tra ở Trang chủ"` plus the trailer.

---

### Task 10: No-fabrication sweep, live E2E script, full suite

**Files:**
- Modify: `test/domain/no_fabrication_test.dart` (new group at the end of `main`)
- Create: `tool/e2e/skill_test.mjs`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the no-fabrication group** `'Skill Test bám dữ liệu, không viết cứng (spec 2026-10-28 skill test mục 8)'`:

```dart
test('lý do khoá hoặc mở bài kiểm tra đổi theo dữ liệu', () {
  String line(String id, List<DrillLog> logs, List<SkillTest> tests) => Vi.skillTestGateLine(
      skillTestGate(drill: stById(id), drills: stDrills, logs: logs, tests: tests), nameOf: (d) => stById(d).name);
  final lines = {
    line('a1', const [], const []),
    line('a1', threePasses('a1').skip(1).toList(), const []),
    line('a1', threePasses('a1'), const []),
    line('a1', threePasses('a1'), [failedTest('a1', 1, stToday.subtract(const Duration(hours: 2)))]),
    line('a1', threePasses('a1'), [passedTest('a1', 1, stToday)]),
  };
  expect(lines, hasLength(5));
  expect(line('a3', threePasses('a3'), const []), contains(stById('a1').name));
  expect(line('p3', threePasses('p3'), [passedTest('p2a', 2, stToday)]), contains(stById('p2b').name));
});
testWidgets('mục Chứng nhận ở Hồ sơ đổi theo dữ liệu', (tester) async {
  for (final (tests, expected) in [
    (const <SkillTest>[], Vi.certificationEmpty),
    ([passedTest('d1', 1, testToday)], Vi.certificationEntry('Đường thẳng cơ bản', 1, testToday)),
  ]) {
    final c = testContainer(skillTests: tests);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CertificationSection())))));
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
  }
});
testWidgets('dòng Home đổi theo dữ liệu', (tester) async {
  for (final (tests, expected) in [
    (const <SkillTest>[], findsOneWidget),
    ([passedTest('d1', 1, testToday)], findsNothing),
  ]) {
    final c = testContainer(logs: threePasses('d1', before: testToday), skillTests: tests);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c,
        child: const MaterialApp(home: Scaffold(body: SkillTestHomeLine()))));
    await tester.pumpAndSettle();
    expect(find.text(Vi.homeSkillTestReady('Đường thẳng cơ bản', 0)), expected);
  }
});
```

- [ ] **Step 2: Run** `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test test/domain/no_fabrication_test.dart`. Expected: PASS, because every producer exists. A failure here is a real hardcoding bug: fix it in the owning file.

- [ ] **Step 3: Write `tool/e2e/skill_test.mjs`.** Copy the structure of `tool/e2e/match_drill_stats.mjs`:
  - the header comment with the run line `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/skill_test.mjs <appUrl>`
  - the same `PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1'` throw, the `need('DIRECTUS_URL' | 'DIRECTUS_ADMIN_EMAIL' | 'DIRECTUS_ADMIN_PASSWORD')` checks and the default `APP_URL`
  - the `check()` helper with a screenshot into `$TMP/pcai-skill-test`
  - `directusAdminToken()` / `directusUserId()`
  - `launch({ port: 9351, name: 'st' })`
  - the throwaway email `e2e-st-${Date.now()}@poolcoachai.example.com`
  - a `finally` block that closes the tab and then calls `deleteUserByEmail(email)`, with `process.exitCode = 1` on any failure

  The steps, with each string's `Vi` source in a comment:
  1. `registerThrowaway(tab, APP, { email, password })`.
  2. Three times: `goto(${APP}/training/drills/d1/session)`, `waitForText('Tập: ')`, `type('Số lần đạt', '9')`, `type('Số lần thử', '10')`, `click('Lưu kết quả')`, `waitForText('Đã lưu')`.
  3. `goto(${APP}/training/drills/d1)`, then `waitForText('Làm bài kiểm tra', 45000)` (`Vi.skillTestOpen`) and click it. Then `waitForText('Kiểm tra: Đường thẳng cơ bản')`, `click('8 feet')`, `click('Bắt đầu kiểm tra')`, `type('Số lần đạt', '9')`, `type('Số lần thử', '10')`, `click('Nộp kết quả')`, and finally `check` that the text includes `'Đã chứng nhận Đường thẳng cơ bản — cấp 1'`.
  4. `goto(${APP}/profile)`. Scroll the way the existing roadmap step does, then `check` that the text includes `'Chứng nhận'` and `'Đường thẳng cơ bản — cấp 1 — '`.
  5. `goto(${APP}/training)`, then `check` that the text includes `'Đã chứng nhận'`.
  6. As Directus admin, poll every 1.5 s for up to 60 s. Check `GET /items/skill_tests?filter[user_created][_eq]=<id>&fields=drill_id,drill_level,table_size,score,attempts,passed,completed_at` and require one row with `drill_id 'd1'`, `drill_level 1`, `table_size 'eightFoot'`, `passed true`, `attempts 10`. Check `GET /items/achievements?filter[user_created][_eq]=<id>&fields=kind,ref_id` and require a row with `kind 'chungNhan'` and `ref_id 'd1'`.

  Run `node --check tool/e2e/skill_test.mjs`. Expected: exit 0. Do **not** run the script: it writes to live Directus and needs the published build.

- [ ] **Step 4: Full suite, analyze and service tests.** Run the suite in the background (`run_in_background`) and Monitor it. Every minute, report the last line of the log, which in the expanded reporter shows the elapsed time, `+passed`, `-failed` and the current test name. Stop when the exit file exists.

```bash
cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/skill-test && rm -f /tmp/pcai-st-full.log /tmp/pcai-st-full.exit && (env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat test --reporter expanded > /tmp/pcai-st-full.log 2>&1; echo $? > /tmp/pcai-st-full.exit)
```

  Expected: `/tmp/pcai-st-full.exit` contains `0` and the log ends with `All tests passed!`.

  Run `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/skill-test && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN /c/Users/anhnpv/flutter/bin/flutter.bat analyze`. Expected: `No issues found!`

  Run `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/skill-test/server/coach-chat && env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN npm test`. Expected: every test passes, 0 fail.

  Run `git status --short`. Expected: only this task's two files.

- [ ] **Step 5: Commit** with `"Skill Test: phép thử chống bịa và kịch bản E2E trên Directus thật"` plus the trailer.

The plan ends here, with the full suite green, analyze clean and `npm test` passing. The coordinator's release steps sit outside this plan: PR, CI, Directus `bootstrap.mjs` then `verify.mjs` on prod (before the web publish, as spec §7 requires), merge, web publish, and the Chrome run of `tool/e2e/skill_test.mjs`.
