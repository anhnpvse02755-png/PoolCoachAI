# Lộ trình Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each account gets one running goal: the next rank, one skill group or a tournament date. The app derives an ordered list of practice steps for that goal from real data: points lost on the latest complete BU test, Player Intelligence and the drill logs. It recomputes the steps whenever the data changes, dates them from the last 28 days of progress, and records achievements only from real practice events. The goal and the achievements sync per account through Directus.

**Architecture:** Approach A from the spec: store only the goal and the achievements; always recompute the steps.
- **`lib/domain/roadmap/`** is plain Dart and imports nothing from Flutter (enforced by the architecture test, Task 1). It holds:
  - the goal, the goal merge rule and the "Lên hạng" lock;
  - the owner's table that maps the 18 BU drills to the six skill groups, and the BU gap;
  - the pace estimate;
  - `PracticeFacts` (the per-group facts the builder and the achievements share);
  - `buildRoadmap`;
  - `newAchievements`.
- **`lib/data/`** adds:
  - two Drift tables (schema 3 → 4, add-only);
  - `RoadmapRepository`, which writes to Drift first;
  - `RoadmapSyncService`, a third sync service beside `SyncService` and `AssessmentSyncService`, so neither of those nor their tests changes.
- **`lib/features/roadmap/presentation/`** holds:
  - the roadmap screen at `/training/roadmap`, inside the Luyện tập branch;
  - the goal picker;
  - the step tile;
  - the Trang chủ line.
- **The achievement recorder** is a provider that the app widget watches, the same way it watches the onboarding gate. Riverpod 3 pauses providers that nobody listens to.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3, Drift 2.27 (`drift_dev` + `build_runner`), go_router 18, `http` + Directus REST, `uuid` 4.5; `flutter_test`; Node + Chrome DevTools Protocol for the browser check (`tool/e2e/`).

**Spec:** docs/superpowers/specs/2026-10-15-poolcoachai-roadmap-design.md (owner approved 15/10/2026, commit 6824c9a)

## Global Constraints

- **Toolchain.** Flutter is not on PATH. In Git Bash use `FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat` and `DART=/c/Users/anhnpv/flutter/bin/dart.bat`. There is no `gh`.
- **Target.** Chrome is the only target that runs. A successful `flutter build web` proves nothing. The final check is headless Chrome over CDP with `tool/e2e/roadmap.mjs` (Task 15).
- **Branch.** Work in the worktree `.claude/worktrees/roadmap` on branch `feat/roadmap` (Task 0). Do not push, merge or deploy; that is the owner's decision at the handoff.
- **Goals (spec §3).** There are exactly three goal kinds, and each account has exactly one running goal.
  - `lenHang` always targets the rank directly above the current one. It is locked when the account has no rank, and when the rank is A or PRO.
  - `thuanThucKyNang` has one of the six groups.
  - `chuanBiGiai` must have a tournament date after today.
- **BU floors (rank spec, `buRankBands`).** K 0, I 20, H 40, G 70, F 95, E 110, D 125, C 140, B 155, A 175.
- **BU → group table (spec §5), verbatim.**
  - aiming: F1, F6, F7, S1, S2.
  - position: F2, F3, F4, F5, F8, S3, S4.
  - safety: S5. kick: S6. bank: S7. breakShot: S10.
  - S8 and S9 map to **no** group.
- **Step done (spec §4.4).** Group mastery ≥ 75 (`PracticeConstants.strongCutoff`) **and** the step's drill `isReadyForLevelUp`, which means 3 passing sessions in a row (`PracticeConstants.readyStreak`). A step reopens when this stops being true.
- **Pace (spec §4.5).** The pace is the change in mastery per day over the last **28 days** (`PracticeConstants.paceWindowDays = 28`, owner-approved 15/10). Days = ⌈(75 − mastery) / pace⌉, and the steps' dates add up in order. If the pace is ≤ 0 or unknown, that step and every later step get "chưa đủ dữ liệu". Never guess a date.
- **Retest gap.** Reuse `retestAvailableFrom` (14 days); never redefine it.
- **Streak milestones (spec §7).** 7 / 14 / 30 / 60 / 100 days, computed with the existing `streakDays`.
- **No LLM anywhere in Lộ trình** (spec §2.2). Every visible sentence is a template in `lib/core/strings/vi.dart`, filled from named, tested functions. The architecture test fails on Vietnamese literals in `lib/features` and `lib/core/widgets`. Missing data reads "chưa đủ dữ liệu"; never show a made-up number (memory: no-fabricated-generated-content).
- **No rank warning from practice data** (rank spec Q15). Lộ trình reads the rank and never writes it.
- **No new tab, no change to the Recommendation Engine, no push notifications** (spec §2.8).
- **Billiards terms.** Use the existing `Vi.skill` names: Ngắm bi, Điều bi / Vị trí, Phá, Phòng thủ, A băng, Cân bi. Never write "kim cương", "bi ma" or "lọt bi cái".
- **Directus.** Creating collections on the live server is an outward action. Task 10 STOPS for the owner before `bootstrap.mjs` runs against production. Secrets live only in `.claude/settings.local.json` `env` of the main checkout; never print or commit them.
- **Riverpod pitfalls** (memory: poolcoachai-riverpod-drift-test-patterns):
  - Never `await container.read(p.future)`. Instead use `container.listen(p, (_, _) {}); await pumpEventQueue();`.
  - Widget tests use `UncontrolledProviderScope` + `testContainer()` / `dbContainer()`.
  - Never write an explicit `List<Override>` type.
  - Drift tests use `AppDatabase.forTesting(NativeDatabase.memory())`.
- **Riverpod 3 pauses unlistened providers.** Anything with a side effect, such as the achievement recorder, must be watched by a widget that is always mounted (`PoolCoachApp`).
- **Drift DateTime precision is whole seconds** (stored as unix seconds). Tests use times with zero milliseconds.
- **Generated code.** After any change to `database.dart`, run `"$DART" run build_runner build --delete-conflicting-outputs`. `database.g.dart` is git-ignored (`.gitignore:35 *.g.dart`); never force-add it.
- **Test surfaces.** Widget tests run at 800×600 unless the test sets a larger surface. Keep inputs and buttons reachable, and use 800×1000 only where a screen is taller by design (the Trang chủ and Luyện tập precedent, Task 16 ruling of the previous plan).
- **Comments** follow the surrounding code: Vietnamese, explaining *why*.
- **Commit messages** are plain English sentences and end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Line endings.** The repo uses `core.autocrlf=true`. Do not convert line endings by hand.

## Review Focus

1. **Two devices change the goal; one of them is offline.**
   - Expected: the newer edit wins on both devices, and "bỏ mục tiêu" made later beats an older goal.
   - Owner: Task 1 (`mergeGoal` table: `bỏ mục tiêu mới hơn thắng mục tiêu cũ`) and Task 9 (`máy này bỏ mục tiêu sau: PATCH dòng rỗng lên máy chủ`, `máy chủ mới hơn: ghi đè máy này, không gửi gì`).
2. **A player who stopped practising more than 28 days ago.**
   - Expected: no date drawn from stale progress; the step says "chưa đủ dữ liệu".
   - Owner: Task 3 (`không tập trong 28 ngày: tốc độ 0, không đoán ngày`).
3. **The first launch after this ships, on two devices of the same account.**
   - Expected: drills that were already ready get their achievement once, dated on the session that completed the streak, not today. A second device recording the same achievement does not duplicate it.
   - Owner: Task 6 (`đủ điều kiện lên cấp ghi đúng ngày buổi đạt thứ ba`), Task 7 (`hai máy cùng người cùng thành tích ra cùng id`), Task 9 (`thành tích trùng trên máy chủ vẫn coi là đã đồng bộ`).
4. **A BU test in progress (Exam II deferred) or cancelled.**
   - Expected: it is ignored. The gap uses the latest *completed* test; with none, the steps follow the weakest groups.
   - Owner: Task 2 (`bỏ qua lần đang làm và lần đã hủy`) and Task 4 (`chưa có bài BU hoàn chỉnh: xếp theo nhóm yếu nhất`).
5. **Switching accounts on one device.**
   - Expected: user B never sees user A's goal or achievements, and nothing derived from A's logs is written into B's rows.
   - Owner: Task 8 (`mục tiêu và thành tích tách theo người`) and Task 11 (`đang đổi người: bộ ghi thành tích không ghi gì`).

---

## Rulings on spec gaps (decided here; each is cheap to change)

- **R1. Goal row key.** `PlayerGoalRows` is keyed by `userId` with a separate `goalId` column, and the Directus row id is the user id. This copies `player_ranks` (spec §6 listed a plain `id`). `goalId` is renewed every time the goal changes, so achievements can name the goal they belong to.
- **R2. "Bỏ mục tiêu" keeps the row with an empty `kind`** instead of deleting it. Spec §6 says "xóa (đồng bộ xóa lên server)". With newest-wins, a deleted row has nothing to compare, so the other device would push its older goal back. An empty row with a newer `updatedAt` carries the deletion. Cost if wrong: one table delete plus a tombstone list.
- **R3. "Bài tập của bước" is `pickDrillInCategory`.** That function picks the first drill that still needs work. So a group step is done only when it has reached the highest drill in the group and that drill has 3 passing sessions in a row. The step's drill therefore moves up as the player progresses.
- **R4. Order without BU results.** Measured groups come first, weakest first. Groups with fewer than 3 sessions follow, in `newcomerOrder`. Spec §4.1.6 says "từ yếu nhất lên" and does not place the unmeasured groups.
- **R5. The S8/S9 step (`buLe`)** is always shown as *Đang làm*. It has no date, takes no days in the date chain, and is never the *Bước hiện tại*. No drill measures it; only the next BU test does.
- **R6. Thuần thục kỹ năng.** One `baiTap` step per drill (done when that drill is ready), then a final group step. Only the final step carries a date; the drill steps have none.
- **R7. `xongBuoc` for lenHang and chuanBiGiai.**
  - **Rule.** These goals earn one for any group that meets the done rule, as long as its last session falls on or after the goal's `createdAt`.
  - **Why.** Without BU results, groups at 75 or above leave the list (spec §4.1.6), so "the step became xong" cannot be seen in the list itself.
  - **Thuần thục kỹ năng** earns one per drill step and one for the group.
  - **Dates.** Each achievement is dated on the session that earned it. Streak achievements are dated today.
- **R8. Achievement ids are deterministic:** UUID v5 of `poolcoachai:achievement:<userId>:<kind>:<refId>`. Two devices that record the same achievement send the same id, so the server answers `RECORD_NOT_UNIQUE`, which counts as synced.
- **R9. "Làm bài kiểm tra" is enabled whenever the 14-day gap allows**, even if the earlier steps are not done. The spec rule is "AI đề xuất, không khóa người dùng".
- **R10. The pace base** is the mastery from logs before the window start. If there were too few sessions then, the base is the first day inside the window on which the group became measurable.
- **R11. Timer sessions are not persisted yet.** `todayRecommendationProvider` already passes `const []`, so streaks count drill logs only.

## File Structure

| File | Responsibility |
|---|---|
| `lib/domain/practice_constants.dart` | adds `paceWindowDays = 28` |
| `lib/domain/roadmap/goal.dart` | `GoalKind`, `PlayerGoal`, `GoalRecord`, `mergeGoal`, `goalDateValid`, `nextRank`, `LenHangBlock`, `lenHangBlock` |
| `lib/domain/roadmap/bu_category_map.dart` | `buDrillCategory` (spec §5) |
| `lib/domain/roadmap/bu_gap.dart` | `buFloor`, `BuResult`, `buResultFrom`, `latestCompletedTestId`, `LostPoints`, `lostByCategory`, `lostDrillsIn` |
| `lib/domain/roadmap/pace.dart` | `dateOnly`, `categoryRatios`, `categoryPacePerDay`, `daysToStrong` |
| `lib/domain/roadmap/roadmap.dart` | `StepKind`, `StepStatus`, `StepReason` and its cases, `Estimate`, `RoadmapStep`, `Roadmap` |
| `lib/domain/roadmap/practice_facts.dart` | `PracticeFacts` — per-group facts the builder and the achievements share |
| `lib/domain/roadmap/roadmap_builder.dart` | `buildRoadmap` |
| `lib/domain/roadmap/achievements.dart` | `AchievementKind`, `Achievement`, `streakMilestones`, `newAchievements` |
| `lib/data/database/database.dart` | `PlayerGoalRows`, `AchievementRows`; schema 4 |
| `lib/data/database/roadmap_converters.dart` | row ↔ domain ↔ Directus JSON, `achievementId` |
| `lib/data/repositories/roadmap_repository.dart` | `RoadmapRepository` |
| `lib/data/sync/roadmap_sync.dart` | `RoadmapSyncService`, `watchPendingRoadmap` |
| `lib/data/sync/account_actions.dart` | sign-out forgets goal + achievements; `pendingRoadmapCount` |
| `lib/core/providers/roadmap_providers.dart` | repository, `goalProvider`, `achievementsProvider`, `latestBuResultProvider`, `roadmapProvider`, `achievementRecorderProvider`, `roadmapSyncProvider` |
| `lib/core/bootstrap.dart` | `startSync` also starts the roadmap sync |
| `lib/app.dart` | watches `achievementRecorderProvider` |
| `lib/core/router/routes.dart`, `app_router.dart` | `Routes.roadmap` = `/training/roadmap` |
| `lib/core/strings/vi.dart` | every Lộ trình string |
| `lib/features/roadmap/presentation/roadmap_screen.dart` | `RoadmapScreen`, `RoadmapView` |
| `lib/features/roadmap/presentation/goal_picker.dart` | `GoalPicker` |
| `lib/features/roadmap/presentation/step_tile.dart` | `StepTile` |
| `lib/features/roadmap/presentation/roadmap_home_line.dart` | `RoadmapHomeLine` |
| `lib/features/training/presentation/training_screen.dart` | Lộ trình card first |
| `lib/features/home/presentation/home_screen.dart` | `RoadmapHomeLine` under the today card |
| `lib/features/profile/presentation/profile_screen.dart` | sign-out warning counts roadmap rows |
| `deploy/directus/bootstrap.mjs`, `verify.mjs` | `player_goals`, `achievements`, permissions, checks |
| `test/support/roadmap_fixtures.dart` | drills and session helpers for domain tests |
| `test/support/test_data.dart` | `testContainer(goal:, achievements:, buResult:)`, `dbContainer(logs:)` |
| `test/domain/roadmap/*_test.dart`, `test/data/...`, `test/core/...`, `test/features/roadmap/*_test.dart` | tests |
| `tool/e2e/roadmap.mjs` | Chrome scenario |
| `docs/superpowers/logs/2026-10-15-roadmap.md` | baseline, Directus, Chrome, owner check |
| `PRD_PoolCoachAI.md` | §6.1 describes what shipped |

---

### Task 0: Worktree, baseline and ledger

**Files:**
- Create: `docs/superpowers/logs/2026-10-15-roadmap.md`
- Create: `.superpowers/sdd/2026-10-15-poolcoachai-roadmap/progress.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the worktree, a green baseline with its test count, the log and the ledger.

- [ ] **Step 1: Create the worktree** with superpowers:using-git-worktrees. Path `.claude/worktrees/roadmap` (git-ignored, the repo's convention), branch `feat/roadmap`, from `main` at the commit that adds this plan.

- [ ] **Step 2: Generate code and run the baseline**

```bash
FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat
DART=/c/Users/anhnpv/flutter/bin/dart.bat
mkdir -p .superpowers/sdd/2026-10-15-poolcoachai-roadmap
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs
"$FLUTTER" analyze > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t0-analyze.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t0-analyze.log
"$FLUTTER" test > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t0-test.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t0-test.log
```

Expected: `No issues found!` and `All tests passed!` with about 1004 tests. Write down the exact count. If anything is red on a clean `main`, STOP and report; do not start Task 1 on a red baseline.

- [ ] **Step 3: Write the log and the ledger**

`docs/superpowers/logs/2026-10-15-roadmap.md`:

```markdown
# Lộ trình — nhật ký thực hiện

Kế hoạch: docs/superpowers/plans/2026-10-15-poolcoachai-roadmap.md
Spec: docs/superpowers/specs/2026-10-15-poolcoachai-roadmap-design.md

## Baseline (<ngày>)

- Nhánh feat/roadmap từ main <hash>.
- flutter analyze: <dòng cuối>
- flutter test: <dòng cuối> (<số> test)
```

`.superpowers/sdd/2026-10-15-poolcoachai-roadmap/progress.md`:

```markdown
# SDD ledger — plan: docs/superpowers/plans/2026-10-15-poolcoachai-roadmap.md
Executor: <chosen by owner>
Task 0: complete (baseline: <dòng cuối của t0-test.log>)
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/logs/2026-10-15-roadmap.md
git commit -m "Record the baseline for the Lộ trình work

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`.superpowers/` is the session's working area. Commit it only if `git check-ignore .superpowers` says it is not ignored, as in the previous plan.)

---

### Task 1: The goal, the merge rule and the "Lên hạng" lock (spec §3, §6)

**Files:**
- Create: `lib/domain/roadmap/goal.dart`
- Create: `test/domain/roadmap/goal_test.dart`
- Modify: `test/architecture_test.dart` (new test after `lõi đánh giá không phụ thuộc Flutter`)

**Interfaces:**
- Consumes: `Rank` (`lib/domain/rank.dart`), `PlayerRank` (`lib/domain/assessment/player_rank.dart`), `SkillCategory`.
- Produces:
  - `enum GoalKind { lenHang, thuanThucKyNang, chuanBiGiai }`
  - `final class PlayerGoal({required String goalId, required GoalKind kind, required DateTime createdAt, SkillCategory? category, DateTime? eventDate})`
  - `final class GoalRecord({required DateTime updatedAt, PlayerGoal? goal})`, where `goal == null` means the goal was dropped
  - `GoalRecord? mergeGoal(GoalRecord? local, GoalRecord? remote)`
  - `bool goalDateValid(DateTime eventDate, DateTime today)`
  - `Rank? nextRank(Rank rank)`
  - `enum LenHangBlock { noRank, topRank }`, `LenHangBlock? lenHangBlock(PlayerRank? rank)`

- [ ] **Step 1: Write the failing tests**

`test/domain/roadmap/goal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final t1 = DateTime(2026, 10, 15, 9);
  final t2 = DateTime(2026, 10, 15, 10);

  PlayerGoal skill(String id) => PlayerGoal(
      goalId: id, kind: GoalKind.thuanThucKyNang, category: SkillCategory.safety, createdAt: t1);

  group('mergeGoal — bản sửa mới nhất thắng (spec mục 6)', () {
    test('một bên trống thì lấy bên còn lại', () {
      final r = GoalRecord(goal: skill('g1'), updatedAt: t1);
      expect(mergeGoal(null, r), same(r));
      expect(mergeGoal(r, null), same(r));
      expect(mergeGoal(null, null), isNull);
    });

    test('bản mới hơn thắng, bất kể ở máy nào', () {
      final older = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final newer = GoalRecord(goal: skill('g2'), updatedAt: t2);
      expect(mergeGoal(older, newer), same(newer));
      expect(mergeGoal(newer, older), same(newer));
    });

    test('bỏ mục tiêu mới hơn thắng mục tiêu cũ', () {
      final goal = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final dropped = GoalRecord(updatedAt: t2);
      expect(mergeGoal(goal, dropped), same(dropped));
      expect(mergeGoal(dropped, goal), same(dropped));
    });

    test('bằng giờ thì giữ bản máy chủ, để hai máy hội tụ về một bản', () {
      final local = GoalRecord(goal: skill('g1'), updatedAt: t1);
      final remote = GoalRecord(goal: skill('g2'), updatedAt: t1);
      expect(mergeGoal(local, remote), same(remote));
    });
  });

  group('ngày giải', () {
    final today = DateTime(2026, 10, 15, 22, 30);
    test('phải sau hôm nay, tính theo ngày', () {
      expect(goalDateValid(DateTime(2026, 10, 16), today), isTrue);
      expect(goalDateValid(DateTime(2026, 10, 15, 23), today), isFalse);
      expect(goalDateValid(DateTime(2026, 10, 1), today), isFalse);
    });
  });

  group('khóa Lên hạng (spec mục 3)', () {
    PlayerRank rank(Rank? r) => PlayerRank(
          rank: r,
          source: r == null ? null : RankSource.estimated,
          onboardingState: r == null ? OnboardingState.skipped : OnboardingState.done,
          updatedAt: t1,
        );

    test('hạng kế tiếp là hạng ngay trên; A và PRO không có', () {
      expect(nextRank(Rank.k), Rank.i);
      expect(nextRank(Rank.d), Rank.c);
      expect(nextRank(Rank.b), Rank.a);
      expect(nextRank(Rank.a), isNull);
      expect(nextRank(Rank.pro), isNull);
    });

    test('chưa có hạng thì khóa noRank; A, PRO khóa topRank; còn lại mở', () {
      expect(lenHangBlock(null), LenHangBlock.noRank);
      expect(lenHangBlock(rank(null)), LenHangBlock.noRank);
      expect(lenHangBlock(rank(Rank.a)), LenHangBlock.topRank);
      expect(lenHangBlock(PlayerRank(
          rank: Rank.pro, source: RankSource.selfDeclared,
          onboardingState: OnboardingState.done, updatedAt: t1)), LenHangBlock.topRank);
      expect(lenHangBlock(rank(Rank.h)), isNull);
    });
  });
}
```

Add to `test/architecture_test.dart`, after the test `lõi đánh giá không phụ thuộc Flutter`:

```dart
  test('lõi Lộ trình không phụ thuộc Flutter', () {
    final files = dartFilesIn('lib/domain/roadmap');
    final offenders = [
      for (final file in files)
        if (codeOnly(file.readAsStringSync()).contains('package:flutter'))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(files, isNotEmpty);
    expect(
      offenders,
      isEmpty,
      reason: 'cách suy bước, ước lượng ngày và thành tích phải chạy và test '
          'được trên Dart VM thuần (spec 2026-10-15 mục 4)',
    );
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/goal_test.dart test/architecture_test.dart`
Expected: FAIL. The goal test does not compile (`goal.dart` is missing), and the architecture test fails with `Directory listing failed` for `lib/domain/roadmap`.

- [ ] **Step 3: Write `lib/domain/roadmap/goal.dart`**

```dart
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Ba loại mục tiêu của Lộ trình (spec 2026-10-15 mục 3).
enum GoalKind { lenHang, thuanThucKyNang, chuanBiGiai }

/// Mục tiêu đang chạy của một tài khoản.
///
/// Lên hạng không lưu hạng đích: đích luôn là hạng ngay trên hạng hiện tại,
/// nên lên được hạng thì đích tự chuyển (spec mục 3).
final class PlayerGoal {
  const PlayerGoal({
    required this.goalId,
    required this.kind,
    required this.createdAt,
    this.category,
    this.eventDate,
  })  : assert(kind != GoalKind.thuanThucKyNang || category != null,
            'thuần thục kỹ năng cần một nhóm'),
        assert(kind != GoalKind.chuanBiGiai || eventDate != null,
            'chuẩn bị giải cần ngày giải');

  /// Đổi mục tiêu là ra id mới: thành tích "xong bước" gắn với id này.
  final String goalId;
  final GoalKind kind;
  final SkillCategory? category;
  final DateTime? eventDate;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is PlayerGoal &&
      other.goalId == goalId &&
      other.kind == kind &&
      other.category == category &&
      other.eventDate == eventDate &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(goalId, kind, category, eventDate, createdAt);

  @override
  String toString() => 'PlayerGoal($goalId, $kind, $category, $eventDate, $createdAt)';
}

/// Dòng mục tiêu của một tài khoản. [goal] null nghĩa là người chơi đã bỏ
/// mục tiêu: dòng vẫn còn, để máy khác biết "đã bỏ" là bản mới hơn (R2).
final class GoalRecord {
  const GoalRecord({required this.updatedAt, this.goal});

  final PlayerGoal? goal;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is GoalRecord && other.goal == goal && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(goal, updatedAt);

  @override
  String toString() => 'GoalRecord($goal, $updatedAt)';
}

/// Bản sửa mới nhất thắng (spec mục 6). Bằng giờ thì giữ bản máy chủ: hai máy
/// cùng chọn một bản thì mới hội tụ được.
GoalRecord? mergeGoal(GoalRecord? local, GoalRecord? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
}

/// Ngày giải phải sau hôm nay, tính theo ngày lịch (spec mục 3).
bool goalDateValid(DateTime eventDate, DateTime today) =>
    DateTime(eventDate.year, eventDate.month, eventDate.day)
        .isAfter(DateTime(today.year, today.month, today.day));

/// Hạng ngay trên. A là trần của bài BU, PRO chỉ tự khai: cả hai không có
/// hạng kế tiếp để nhắm.
Rank? nextRank(Rank rank) => switch (rank) {
      Rank.a || Rank.pro => null,
      _ => Rank.values[rank.index + 1],
    };

/// Vì sao chưa đặt được mục tiêu Lên hạng.
enum LenHangBlock { noRank, topRank }

LenHangBlock? lenHangBlock(PlayerRank? rank) {
  final r = rank?.rank;
  if (r == null) return LenHangBlock.noRank;
  return nextRank(r) == null ? LenHangBlock.topRank : null;
}
```

- [ ] **Step 4: Run the tests again**

Run: `"$FLUTTER" test test/domain/roadmap/goal_test.dart test/architecture_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/roadmap/goal.dart test/domain/roadmap/goal_test.dart test/architecture_test.dart
git commit -m "Add the roadmap goal, its newest-wins merge and the rank-up lock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The BU → group table and the BU gap (spec §4.1, §5)

**Files:**
- Create: `lib/domain/roadmap/bu_category_map.dart`
- Create: `lib/domain/roadmap/bu_gap.dart`
- Create: `test/domain/roadmap/bu_gap_test.dart`

**Interfaces:**
- Consumes:
  - `buRankBands`, `ExamIIVersion`, `TableSize` from `bu_placement.dart`;
  - `examIDrills`, `examIIDrills(v)`, `drillScore(d, a)` from `bu_exams.dart`;
  - `BuTest`, `TestSnapshot` from `bu_test.dart`;
  - `examIAttempts`, `examIIPerfect` from `test/support/assessment_fixtures.dart`.
- Produces:
  - `const Map<String, SkillCategory?> buDrillCategory`, with keys in the order F1…F8, S1…S10
  - `int buFloor(Rank rank)`
  - `final class BuResult({required String testId, required DateTime completedAt, required int total, required Map<String, int> lost})`
  - `BuResult buResultFrom(TestSnapshot s)`
  - `String? latestCompletedTestId(Iterable<BuTest> tests)`
  - `typedef LostPoints = ({Map<SkillCategory, int> byCategory, int unmapped, List<String> unmappedIds})`
  - `LostPoints lostByCategory(BuResult r)`
  - `List<String> lostDrillsIn(BuResult r, SkillCategory c)`

- [ ] **Step 1: Write the failing tests**

`test/domain/roadmap/bu_gap_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_category_map.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/assessment_fixtures.dart';

void main() {
  group('bảng nối 18 bài BU vào 6 nhóm (spec mục 5, chủ sản phẩm duyệt 15/10)', () {
    test('đúng từng dòng của spec', () {
      expect(buDrillCategory, {
        'F1': SkillCategory.aiming,
        'F2': SkillCategory.position,
        'F3': SkillCategory.position,
        'F4': SkillCategory.position,
        'F5': SkillCategory.position,
        'F6': SkillCategory.aiming,
        'F7': SkillCategory.aiming,
        'F8': SkillCategory.position,
        'S1': SkillCategory.aiming,
        'S2': SkillCategory.aiming,
        'S3': SkillCategory.position,
        'S4': SkillCategory.position,
        'S5': SkillCategory.safety,
        'S6': SkillCategory.kick,
        'S7': SkillCategory.bank,
        'S8': null,
        'S9': null,
        'S10': SkillCategory.breakShot,
      });
      expect(buDrillCategory.keys.toList(),
          ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10']);
    });
  });

  test('sàn BU của từng hạng theo bảng đã duyệt', () {
    expect(buFloor(Rank.c), 140);
    expect(buFloor(Rank.d), 125);
    expect(buFloor(Rank.a), 175);
    expect(buFloor(Rank.k), 0);
  });

  group('lần hoàn chỉnh gần nhất', () {
    BuTest test(String id, {DateTime? done, DateTime? cancelled}) => BuTest(
        id: id,
        startedAt: DateTime(2026, 10, 1),
        tableSize: TableSize.nineFootPlus,
        completedAt: done,
        cancelledAt: cancelled);

    test('bỏ qua lần đang làm và lần đã hủy', () {
      expect(latestCompletedTestId([
        test('cu', done: DateTime(2026, 10, 2)),
        test('moi', done: DateTime(2026, 10, 9)),
        test('dang-lam'),
        test('huy', cancelled: DateTime(2026, 10, 12)),
      ]), 'moi');
      expect(latestCompletedTestId([test('dang-lam')]), isNull);
      expect(latestCompletedTestId(const []), isNull);
    });
  });

  group('điểm mất theo bài và theo nhóm', () {
    final snapshot = TestSnapshot(
      test: BuTest(
        id: 't1',
        startedAt: DateTime(2026, 10, 14, 8),
        tableSize: TableSize.nineFootPlus,
        completedAt: DateTime(2026, 10, 14, 11),
        examIScore: 60,
        examIIVersion: ExamIIVersion.masters,
        examIIScore: 77,
        totalScore: 137,
        resultRank: Rank.d,
      ),
      attempts: {
        ...examIAttempts(wagonAndTargetMade: false),
        ...examIIPerfect(ExamIIVersion.masters),
      },
    );

    test('điểm mất = tối đa của bản đã làm − điểm đạt', () {
      final r = buResultFrom(snapshot);
      expect(r.testId, 't1');
      expect(r.total, 137);
      expect(r.lost['F7'], 20);
      expect(r.lost['F8'], 20);
      expect(r.lost['F1'], 0);
      expect(r.lost['S1'], 0);
      expect(r.lost.length, 18);
    });

    test('cộng dồn theo nhóm; S8, S9 tính riêng', () {
      final r = BuResult(
        testId: 't',
        completedAt: DateTime(2026, 10, 14),
        total: 120,
        lost: const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1, 'S10': 0},
      );
      final lost = lostByCategory(r);
      expect(lost.byCategory, {
        SkillCategory.aiming: 5,
        SkillCategory.position: 7,
        SkillCategory.safety: 6,
      });
      expect(lost.unmapped, 3);
      expect(lost.unmappedIds, ['S8', 'S9']);
      expect(lostDrillsIn(r, SkillCategory.position), ['F3', 'F5']);
      expect(lostDrillsIn(r, SkillCategory.breakShot), isEmpty);
    });

    test('tổng điểm theo nhóm cộng S8/S9 bằng tổng điểm mất', () {
      final r = buResultFrom(snapshot);
      final lost = lostByCategory(r);
      final sum = lost.byCategory.values.fold(0, (s, v) => s + v) + lost.unmapped;
      expect(sum, r.lost.values.fold(0, (s, v) => s + v));
    });
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/bu_gap_test.dart`
Expected: FAIL at compile time: `bu_category_map.dart` and `bu_gap.dart` do not exist.

- [ ] **Step 3: Write `lib/domain/roadmap/bu_category_map.dart`**

```dart
import 'package:poolcoachai/domain/skill_category.dart';

/// Bài BU nào thuộc nhóm kỹ năng nào (spec 2026-10-15 mục 5, chủ sản phẩm
/// duyệt 15/10/2026). Mỗi bài xếp theo cái BU chấm điểm: bi vào → Ngắm bi;
/// chỗ bi cái dừng → Điều bi / Vị trí. F8 và S4 chấm cả hai, xếp Điều bi.
///
/// S8 (Dựng cơ) và S9 (Nhảy bi / Mát xê) không khớp nhóm nào: tập ngắm không
/// giúp dựng cơ hay nhảy bi, nên không giao bài sai mục đích.
///
/// Thứ tự khoá là thứ tự hiển thị F1…F8, S1…S10.
const buDrillCategory = <String, SkillCategory?>{
  'F1': SkillCategory.aiming,
  'F2': SkillCategory.position,
  'F3': SkillCategory.position,
  'F4': SkillCategory.position,
  'F5': SkillCategory.position,
  'F6': SkillCategory.aiming,
  'F7': SkillCategory.aiming,
  'F8': SkillCategory.position,
  'S1': SkillCategory.aiming,
  'S2': SkillCategory.aiming,
  'S3': SkillCategory.position,
  'S4': SkillCategory.position,
  'S5': SkillCategory.safety,
  'S6': SkillCategory.kick,
  'S7': SkillCategory.bank,
  'S8': null,
  'S9': null,
  'S10': SkillCategory.breakShot,
};
```

- [ ] **Step 4: Write `lib/domain/roadmap/bu_gap.dart`**

```dart
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_category_map.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Điểm BU thấp nhất của [rank] theo bảng chủ sản phẩm chốt 14/10/2026.
/// PRO không có dòng trong bảng — gọi với PRO là lỗi lập trình.
int buFloor(Rank rank) => buRankBands.firstWhere((b) => b.rank == rank).min;

/// Kết quả của một lần kiểm tra BU hoàn chỉnh: tổng điểm và điểm mất từng bài.
final class BuResult {
  BuResult({
    required this.testId,
    required this.completedAt,
    required this.total,
    required Map<String, int> lost,
  }) : lost = Map.unmodifiable(lost);

  final String testId;
  final DateTime completedAt;
  final int total;

  /// 'F1'…'S10' → tối đa của bản đã làm trừ điểm đạt.
  final Map<String, int> lost;
}

/// Điểm mất từng bài của một lần đã hoàn tất (spec mục 4.1 bước 3).
BuResult buResultFrom(TestSnapshot s) {
  final test = s.test;
  assert(test.isCompleted && test.examIIVersion != null, 'chỉ lần đã hoàn tất mới có điểm mất');
  final drills = [...examIDrills, ...examIIDrills(test.examIIVersion!)];
  final lost = {
    for (final d in drills) d.id: d.maxScore - (drillScore(d, s.attemptsOf(d)) ?? 0),
  };
  return BuResult(
    testId: test.id,
    completedAt: test.completedAt!,
    total: test.totalScore ?? s.scoreOf(drills),
    lost: lost,
  );
}

/// Lần hoàn tất gần nhất. Lần đang làm (kể cả Đề II đang hoãn) và lần đã hủy
/// không tính (spec mục 4.1 bước 6).
String? latestCompletedTestId(Iterable<BuTest> tests) {
  BuTest? best;
  for (final t in tests) {
    if (!t.isCompleted || t.isCancelled) continue;
    if (best == null || t.completedAt!.isAfter(best.completedAt!)) best = t;
  }
  return best?.id;
}

typedef LostPoints = ({
  Map<SkillCategory, int> byCategory,
  int unmapped,
  List<String> unmappedIds,
});

/// Cộng điểm mất theo nhóm qua [buDrillCategory]. Bài không nối nhóm (S8, S9)
/// vẫn tính vào [LostPoints.unmapped] — điểm mất không được biến mất.
LostPoints lostByCategory(BuResult r) {
  final byCategory = <SkillCategory, int>{};
  var unmapped = 0;
  final unmappedIds = <String>[];
  for (final MapEntry(key: id, value: cat) in buDrillCategory.entries) {
    final points = r.lost[id] ?? 0;
    if (points <= 0) continue;
    if (cat == null) {
      unmapped += points;
      unmappedIds.add(id);
    } else {
      byCategory[cat] = (byCategory[cat] ?? 0) + points;
    }
  }
  return (byCategory: byCategory, unmapped: unmapped, unmappedIds: unmappedIds);
}

/// Các bài của nhóm [c] có mất điểm, theo thứ tự F1…S10.
List<String> lostDrillsIn(BuResult r, SkillCategory c) => [
      for (final MapEntry(key: id, value: cat) in buDrillCategory.entries)
        if (cat == c && (r.lost[id] ?? 0) > 0) id,
    ];
```

- [ ] **Step 5: Run the tests again**

Run: `"$FLUTTER" test test/domain/roadmap`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/roadmap/bu_category_map.dart lib/domain/roadmap/bu_gap.dart test/domain/roadmap/bu_gap_test.dart
git commit -m "Map the 18 BU drills to skill groups and compute lost BU points

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The 28-day pace and the days to 75 (spec §4.5)

**Files:**
- Modify: `lib/domain/practice_constants.dart` (append a constant)
- Create: `lib/domain/roadmap/pace.dart`
- Create: `test/support/roadmap_fixtures.dart`
- Create: `test/domain/roadmap/pace_test.dart`

**Interfaces:**
- Consumes: `categoryMastery` (`player_intelligence.dart`), `drillRatio`, `PracticeConstants`.
- Produces:
  - `PracticeConstants.paceWindowDays = 28`
  - `DateTime dateOnly(DateTime d)`
  - `List<double> categoryRatios(SkillCategory cat, Map<String, Drill> drillById, Iterable<DrillLog> logsOldestFirst)`
  - `double? categoryPacePerDay({required SkillCategory cat, required List<Drill> drills, required List<DrillLog> logs, required DateTime today})`
  - `int? daysToStrong(int? mastery, double? pace)`
  - In the test fixtures: `roadmapToday`, `roadmapDrills`, `List<DrillLog> sessions(String drillId, int made, List<DateTime> days)`

- [ ] **Step 1: Write the fixtures**

`test/support/roadmap_fixtures.dart`:

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Hôm nay cố định cho các test Lộ trình.
final roadmapToday = DateTime(2026, 10, 15, 10);

Drill _drill(String id, SkillCategory cat, int level) => Drill(
      id: id,
      cat: cat,
      name: 'Bai $id',
      level: level,
      unit: 'lan / 10',
      passThreshold: 0.8,
      goal: 'g',
      steps: const [],
    );

/// Một bài mỗi nhóm, riêng Ngắm bi có hai cấp — đủ để thấy bài của bước
/// đi lên khi người chơi tiến bộ (R3).
final roadmapDrills = <Drill>[
  _drill('a1', SkillCategory.aiming, 1),
  _drill('a2', SkillCategory.aiming, 2),
  _drill('p1', SkillCategory.position, 1),
  _drill('b1', SkillCategory.breakShot, 1),
  _drill('s1', SkillCategory.safety, 1),
  _drill('k1', SkillCategory.kick, 1),
  _drill('n1', SkillCategory.bank, 1),
];

/// Mỗi ngày trong [days] một buổi [made]/10. Ngưỡng đạt 0.8: 8 trở lên là đạt.
List<DrillLog> sessions(String drillId, int made, List<DateTime> days) => [
      for (final d in days)
        DrillLog(
          id: '$drillId-${d.toIso8601String()}-$made',
          drillId: drillId,
          date: d,
          score: made,
          attempts: 10,
        ),
    ];

/// Ngày [day] của tháng [month] năm 2026, 9 giờ sáng.
DateTime on(int month, int day) => DateTime(2026, month, day, 9);
```

- [ ] **Step 2: Write the failing tests**

`test/domain/roadmap/pace_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  const aiming = SkillCategory.aiming;

  test('cửa sổ là 28 ngày (chủ sản phẩm duyệt 15/10)', () {
    expect(PracticeConstants.paceWindowDays, 28);
  });

  group('tốc độ tiến bộ của một nhóm', () {
    test('đủ buổi trước cửa sổ: mốc là đầu cửa sổ (17/9)', () {
      final logs = [
        ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 8, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final now = categoryMastery([0.5, 0.5, 0.5, 1, 1, 1])!;
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, closeTo((now - 50) / 28, 1e-9));
    });

    test('chưa đủ buổi trước cửa sổ: mốc là ngày đầu tiên đo được', () {
      final logs = [
        ...sessions('a1', 4, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a1', 8, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final now = categoryMastery([0.5, 0.5, 0.5, 1, 1, 1])!;
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, closeTo((now - 50) / 12, 1e-9));
    });

    test('dưới 3 buổi thì không có tốc độ', () {
      final logs = sessions('a1', 8, [on(10, 10), on(10, 11)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });

    test('vừa đo được hôm nay thì chưa có tốc độ (0 ngày)', () {
      final logs = sessions('a1', 8, [on(10, 13), on(10, 14), on(10, 15)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });

    test('không tập trong 28 ngày: tốc độ 0, không đoán ngày', () {
      final logs = sessions('a1', 4, [on(8, 1), on(8, 2), on(8, 3)]);
      final pace = categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday);
      expect(pace, 0);
      expect(daysToStrong(50, pace), isNull);
    });

    test('đang đi xuống thì tốc độ âm', () {
      final logs = [
        ...sessions('a1', 8, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 4, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), lessThan(0));
    });

    test('chỉ tính bài của đúng nhóm', () {
      final logs = sessions('s1', 8, [on(10, 1), on(10, 2), on(10, 3)]);
      expect(categoryPacePerDay(cat: aiming, drills: roadmapDrills, logs: logs, today: roadmapToday), isNull);
    });
  });

  group('số ngày tới 75', () {
    test('làm tròn lên; đã đạt 75 là 0 ngày', () {
      expect(daysToStrong(60, 1.5), 10);
      expect(daysToStrong(74, 0.3), 4);
      expect(daysToStrong(75, null), 0);
      expect(daysToStrong(90, -1), 0);
    });

    test('chưa đo hoặc tốc độ không dương thì không có số ngày', () {
      expect(daysToStrong(null, 2), isNull);
      expect(daysToStrong(60, 0), isNull);
      expect(daysToStrong(60, -0.5), isNull);
      expect(daysToStrong(60, null), isNull);
    });
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/pace_test.dart`
Expected: FAIL at compile time: `pace.dart` and `paceWindowDays` are missing.

- [ ] **Step 4: Add the constant** at the end of `PracticeConstants` in `lib/domain/practice_constants.dart`, before the closing `}`:

```dart

  /// Số ngày gần nhất dùng để đo tốc độ tiến bộ cho ngày dự kiến của Lộ
  /// trình. Không có trong spec prototype: chủ sản phẩm duyệt 15/10/2026
  /// (spec 2026-10-15 mục 4.5).
  static const paceWindowDays = 28;
```

- [ ] **Step 5: Write `lib/domain/roadmap/pace.dart`**

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/skill_category.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số ngày lịch giữa hai ngày — làm tròn theo giờ để đổi giờ mùa hè (nếu có)
/// không làm lệch một ngày.
int _daysBetween(DateTime from, DateTime to) =>
    (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

/// Tỉ lệ đạt các buổi của nhóm [cat], cũ nhất trước — đúng đầu vào của
/// [categoryMastery]. Buổi không chấm được thì bỏ, như Player Intelligence.
List<double> categoryRatios(
  SkillCategory cat,
  Map<String, Drill> drillById,
  Iterable<DrillLog> logsOldestFirst,
) =>
    [
      for (final log in logsOldestFirst)
        if (drillById[log.drillId] case final drill? when drill.cat == cat)
          if (drillRatio(drill, log) case final ratio?) ratio,
    ];

/// Độ thuần thục tăng bao nhiêu mỗi ngày trong [PracticeConstants.paceWindowDays]
/// ngày gần nhất (spec mục 4.5).
///
/// Mốc so sánh là độ thuần thục từ các buổi trước đầu cửa sổ. Trước đó chưa đủ
/// buổi để đo thì mốc là ngày đầu tiên trong cửa sổ đo được (R10). Trả `null`
/// khi hôm nay chưa đo được, chưa có mốc, hoặc mốc chính là hôm nay.
double? categoryPacePerDay({
  required SkillCategory cat,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required DateTime today,
}) {
  final byId = {for (final d in drills) d.id: d};
  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
  final day = dateOnly(today);

  final now = categoryMastery(categoryRatios(cat, byId, sorted));
  if (now == null) return null;

  final windowStart =
      DateTime(day.year, day.month, day.day - PracticeConstants.paceWindowDays);
  var base = categoryMastery(
      categoryRatios(cat, byId, sorted.where((l) => l.date.isBefore(windowStart))));
  var baseDay = windowStart;

  if (base == null) {
    for (final log in sorted) {
      if (log.date.isBefore(windowStart) || byId[log.drillId]?.cat != cat) continue;
      final endOfDay = DateTime(log.date.year, log.date.month, log.date.day + 1);
      final m = categoryMastery(
          categoryRatios(cat, byId, sorted.where((l) => l.date.isBefore(endOfDay))));
      if (m != null) {
        base = m;
        baseDay = dateOnly(log.date);
        break;
      }
    }
  }
  if (base == null) return null;

  final days = _daysBetween(baseDay, day);
  if (days < 1) return null;
  return (now - base) / days;
}

/// Số ngày tới độ thuần thục [PracticeConstants.strongCutoff] với tốc độ
/// [pace]. Đã đạt thì 0. Chưa đo được, hoặc tốc độ không dương, thì `null`:
/// màn hình nói "chưa đủ dữ liệu", không đoán (spec mục 4.5).
int? daysToStrong(int? mastery, double? pace) {
  if (mastery == null) return null;
  final missing = PracticeConstants.strongCutoff - mastery;
  if (missing <= 0) return 0;
  if (pace == null || pace <= 0) return null;
  return (missing / pace).ceil();
}
```

- [ ] **Step 6: Run the tests again**

Run: `"$FLUTTER" test test/domain/roadmap test/domain/player_intelligence_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/practice_constants.dart lib/domain/roadmap/pace.dart test/support/roadmap_fixtures.dart test/domain/roadmap/pace_test.dart
git commit -m "Estimate a skill group's pace over the last 28 days and the days to 75

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Roadmap types, `PracticeFacts` and the Lên hạng roadmap (spec §4.1, §4.4, §4.5)

**Files:**
- Create: `lib/domain/roadmap/roadmap.dart`
- Create: `lib/domain/roadmap/practice_facts.dart`
- Create: `lib/domain/roadmap/roadmap_builder.dart`
- Create: `test/domain/roadmap/roadmap_len_hang_test.dart`

**Interfaces:**
- Consumes:
  - Task 1: `PlayerGoal`, `GoalKind`, `LenHangBlock`, `nextRank`.
  - Task 2: `BuResult`, `buFloor`, `lostByCategory`, `lostDrillsIn`.
  - Task 3: `categoryPacePerDay`, `daysToStrong`, `dateOnly`.
  - Existing: `computePlayerIntelligence`, `isReadyForLevelUp`, `pickDrillInCategory`, `newcomerOrder`, `drillRatio`, `retestAvailableFrom`, `PlayerRank`, `BuTest`.
- Produces:
  - `enum StepKind { xacDinhHang, nhom, buLe, baiTap, lamBaiBu }`
  - `enum StepStatus { dangLam, xong, chuaToi, khongKip }`
  - `sealed class StepReason` with these cases:
    - `LostBuPoints(int points, List<String> drillIds)`
    - `Unmeasured(int sessions)`
    - `BelowStrong(int mastery)`
    - `NeedStreak()`
    - `DrillLevel(int level)`
    - `RetestFrom(DateTime? from)`
    - `NeedRank()`
  - `final class Estimate { const Estimate.on(DateTime date); const Estimate.notEnoughData(); final DateTime? date; }`
  - `final class RoadmapStep`, with fields `kind`, `status`, `reason`, `category?`, `drillId?`, `buDrillIds`, `mastery?`, `passStreak`, `estimate?`, and methods `withStatus` and `withEstimate`.
  - `final class Roadmap`:
    - fields `goal`, `steps`, `blocked?`, `from?`, `target?`, `pointsNeeded?`;
    - getters `currentStep`, `missed`, `finish`, `achieved`.
  - `final class PracticeFacts({required List<Drill> drills, required List<DrillLog> logs, required DateTime today})`
  - `Roadmap buildRoadmap({required PlayerGoal goal, required PlayerRank? rank, required List<Drill> drills, required List<DrillLog> logs, required List<BuTest> tests, required BuResult? latestResult, required DateTime today})`

This task builds the `lenHang` branch fully, with estimates and statuses. Task 5 adds the other two goal kinds. Until then the builder's `thuanThucKyNang` and `chuanBiGiai` cases throw `UnimplementedError('Task 5')`. That is a deliberate, tested stub that Task 5 removes; it is not a placeholder left in shipped code.

- [ ] **Step 1: Write the failing tests**

`test/domain/roadmap/roadmap_len_hang_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  final goal = PlayerGoal(goalId: 'g1', kind: GoalKind.lenHang, createdAt: on(10, 1));

  PlayerRank rank(Rank r, {RankSource source = RankSource.estimated}) => PlayerRank(
        rank: r,
        source: source,
        buScore: source == RankSource.verified ? 120 : null,
        testId: source == RankSource.verified ? 't' : null,
        onboardingState: OnboardingState.done,
        updatedAt: on(10, 1),
      );

  Roadmap build({
    PlayerRank? r,
    List<DrillLog> logs = const [],
    List<BuTest> tests = const [],
    BuResult? result,
  }) =>
      buildRoadmap(
        goal: goal,
        rank: r,
        drills: roadmapDrills,
        logs: logs,
        tests: tests,
        latestResult: result,
        today: roadmapToday,
      );

  BuResult result(int total, Map<String, int> lost) =>
      BuResult(testId: 't', completedAt: on(10, 1), total: total, lost: lost);

  group('khóa', () {
    test('chưa có hạng: một bước Xác định hạng', () {
      final r = build();
      expect(r.blocked, LenHangBlock.noRank);
      expect(r.steps.single.kind, StepKind.xacDinhHang);
      expect(r.steps.single.status, StepStatus.dangLam);
      expect(r.currentStep!.kind, StepKind.xacDinhHang);
    });

    test('hạng A hoặc PRO: không có bước nào', () {
      expect(build(r: rank(Rank.a)).blocked, LenHangBlock.topRank);
      expect(build(r: rank(Rank.a)).steps, isEmpty);
      expect(build(r: rank(Rank.pro, source: RankSource.selfDeclared)).blocked, LenHangBlock.topRank);
    });
  });

  group('có bài BU hoàn chỉnh: theo điểm mất (spec mục 4.1)', () {
    test('E 120 → D cần 5: lấy Điều bi (mất 7) là đủ', () {
      final r = build(
        r: rank(Rank.e, source: RankSource.verified),
        result: result(120, const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1}),
      );
      expect(r.from, Rank.e);
      expect(r.target, Rank.d);
      expect(r.pointsNeeded, 5);
      expect(r.steps.map((s) => s.kind), [StepKind.nhom, StepKind.lamBaiBu]);
      expect(r.steps.first.category, SkillCategory.position);
      final reason = r.steps.first.reason as LostBuPoints;
      expect(reason.points, 7);
      expect(reason.drillIds, ['F3', 'F5']);
    });

    test('D 120 → C cần 20: lấy dần tới khi đủ, có cả bước S8/S9', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(120, const {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1}),
      );
      expect(r.pointsNeeded, 20);
      expect(r.steps.map((s) => s.category), [
        SkillCategory.position, // 7
        SkillCategory.safety, // 6 → 13
        SkillCategory.aiming, // 5 → 18
        null, // S8/S9: 3 → 21 ≥ 20
        null, // Làm bài BU
      ]);
      final buLe = r.steps[3];
      expect(buLe.kind, StepKind.buLe);
      expect(buLe.buDrillIds, ['S8', 'S9']);
      expect(buLe.status, StepStatus.dangLam);
      expect(buLe.estimate, isNull);
    });

    test('bằng điểm mất thì nhóm yếu hơn đi trước', () {
      // Ngắm bi đo được 50, Điều bi chưa đo: nhóm đo được, yếu hơn, đi trước (R4).
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20, 'F8': 20}),
        logs: sessions('a1', 4, [on(10, 10), on(10, 11), on(10, 12)]),
      );
      expect(r.pointsNeeded, 3);
      expect(r.steps.first.category, SkillCategory.aiming);
      expect(r.steps.length, 2);
    });

    test('nhóm đã đạt 75 và bài đã đủ 3 buổi đạt: bước xong, bước sau đang làm', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: [
          ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
          ...sessions('a2', 9, [on(10, 10), on(10, 11), on(10, 12)]),
        ],
      );
      expect(r.steps.first.status, StepStatus.xong);
      expect(r.steps.first.drillId, 'a2');
      expect(r.steps.last.kind, StepKind.lamBaiBu);
      expect(r.steps.last.status, StepStatus.dangLam);
      expect(r.currentStep!.kind, StepKind.lamBaiBu);
    });

    test('tụt dưới 75 thì bước mở lại', () {
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: [
          ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
          ...sessions('a2', 9, [on(10, 4), on(10, 5), on(10, 6)]),
          ...sessions('a2', 2, [on(10, 10), on(10, 11), on(10, 12), on(10, 13)]),
        ],
      );
      expect(r.steps.first.status, StepStatus.dangLam);
    });
  });

  group('chưa có bài BU hoàn chỉnh: xếp theo nhóm yếu nhất', () {
    test('nhóm đo được yếu trước, nhóm chưa đo sau theo thứ tự làm quen; nhóm từ 75 bỏ ra', () {
      final r = build(
        r: rank(Rank.h),
        logs: [
          ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
          ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]), // ~65
          ...sessions('s1', 4, [on(10, 10), on(10, 11), on(10, 12)]), // 50
          ...sessions('k1', 9, [on(10, 10), on(10, 11), on(10, 12)]), // 100
        ],
      );
      expect(r.pointsNeeded, isNull);
      expect(r.steps.map((s) => s.category), [
        SkillCategory.safety,
        SkillCategory.aiming,
        SkillCategory.position,
        SkillCategory.breakShot,
        SkillCategory.bank,
        null,
      ]);
      expect(r.steps.first.reason, isA<BelowStrong>());
      expect(r.steps[2].reason, isA<Unmeasured>());
      expect(r.steps.first.status, StepStatus.dangLam);
      expect(r.steps[1].status, StepStatus.chuaToi);
    });
  });

  group('ngày dự kiến (spec mục 4.5)', () {
    test('cộng dồn từ hôm nay; bước làm BU lấy ngày muộn hơn giữa bước trước và mốc 14 ngày', () {
      final logs = [
        ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final tests = [
        BuTest(
          id: 't',
          startedAt: on(10, 14),
          tableSize: TableSize.nineFootPlus,
          completedAt: on(10, 14),
        ),
      ];
      final r = build(
        r: rank(Rank.d, source: RankSource.verified),
        result: result(137, const {'F7': 20}),
        logs: logs,
        tests: tests,
      );
      final mastery = computePlayerIntelligence(drills: roadmapDrills, logs: logs)
          .categories[SkillCategory.aiming]!
          .mastery;
      final days = daysToStrong(
          mastery,
          categoryPacePerDay(
              cat: SkillCategory.aiming, drills: roadmapDrills, logs: logs, today: roadmapToday))!;
      final expected = DateTime(2026, 10, 15 + days);
      expect(r.steps.first.estimate!.date, expected);
      final retest = DateTime(2026, 10, 28);
      expect(r.steps.last.estimate!.date, expected.isAfter(retest) ? expected : retest);
      expect((r.steps.last.reason as RetestFrom).from, retest);
      expect(r.finish!.date, r.steps.last.estimate!.date);
    });

    test('tốc độ không đo được: bước đó và mọi bước sau đều chưa đủ dữ liệu', () {
      final r = build(
        r: rank(Rank.h),
        logs: sessions('s1', 4, [on(10, 12), on(10, 13), on(10, 14)]),
      );
      expect(r.steps.first.category, SkillCategory.safety);
      expect(r.steps.first.estimate!.date, isNull);
      expect(r.steps.every((s) => s.kind == StepKind.buLe || s.estimate?.date == null), isTrue);
      expect(r.finish!.date, isNull);
    });

    test('chưa từng làm BU: bước làm BU mở ngay', () {
      final r = build(r: rank(Rank.h));
      expect((r.steps.last.reason as RetestFrom).from, isNull);
    });
  });

  test('Lên hạng không bao giờ đạt xong: lên hạng thì đích tự chuyển', () {
    expect(build(r: rank(Rank.h)).achieved, isFalse);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/roadmap_len_hang_test.dart`
Expected: FAIL at compile time: `roadmap.dart` and `roadmap_builder.dart` are missing.

- [ ] **Step 3: Write `lib/domain/roadmap/roadmap.dart`**

```dart
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Loại bước của Lộ trình (spec 2026-10-15 mục 4).
enum StepKind {
  /// Chưa có hạng: làm bộ câu hỏi hoặc bài BU trước.
  xacDinhHang,

  /// Tập một nhóm kỹ năng tới khi xong (mục 4.4).
  nhom,

  /// Điểm mất ở S8/S9 — không nối nhóm nào, không có bài tập đo được (R5).
  buLe,

  /// Một bài tập của mục tiêu Thuần thục kỹ năng (R6).
  baiTap,

  /// Làm lại bài kiểm tra BU — bước cuối của Lên hạng.
  lamBaiBu,
}

enum StepStatus { dangLam, xong, chuaToi, khongKip }

/// Vì sao có bước này — **dữ liệu**, câu chữ dựng ở `Vi.stepReason`.
sealed class StepReason {
  const StepReason();
}

final class LostBuPoints extends StepReason {
  const LostBuPoints(this.points, this.drillIds);
  final int points;
  final List<String> drillIds;
}

final class Unmeasured extends StepReason {
  const Unmeasured(this.sessions);
  final int sessions;
}

final class BelowStrong extends StepReason {
  const BelowStrong(this.mastery);
  final int mastery;
}

/// Đã đạt 75, còn thiếu chuỗi buổi đạt liên tiếp.
final class NeedStreak extends StepReason {
  const NeedStreak();
}

final class DrillLevel extends StepReason {
  const DrillLevel(this.level);
  final int level;
}

/// Ngày được làm bài BU tiếp; null là làm được ngay.
final class RetestFrom extends StepReason {
  const RetestFrom(this.from);
  final DateTime? from;
}

final class NeedRank extends StepReason {
  const NeedRank();
}

/// Ngày dự kiến xong một bước, hoặc "chưa đủ dữ liệu" — không đoán (mục 4.5).
final class Estimate {
  const Estimate.on(DateTime this.date);
  const Estimate.notEnoughData() : date = null;

  final DateTime? date;
}

final class RoadmapStep {
  const RoadmapStep({
    required this.kind,
    required this.status,
    required this.reason,
    this.category,
    this.drillId,
    this.buDrillIds = const [],
    this.mastery,
    this.passStreak = 0,
    this.estimate,
  });

  final StepKind kind;
  final StepStatus status;
  final StepReason reason;
  final SkillCategory? category;

  /// Bài tập của bước (`pickDrillInCategory`, R3) hoặc bài của bước baiTap.
  final String? drillId;
  final List<String> buDrillIds;

  /// Độ thuần thục của nhóm lúc tính; null là chưa đủ 3 buổi.
  final int? mastery;

  /// Số buổi đạt liên tiếp gần nhất của [drillId], tối đa 3.
  final int passStreak;

  /// null: bước không có dòng ngày (đã xong, S8/S9, bài của mục tiêu thuần thục).
  final Estimate? estimate;

  RoadmapStep withStatus(StepStatus s) => _copy(status: s);
  RoadmapStep withEstimate(Estimate e) => _copy(estimate: e);

  RoadmapStep _copy({StepStatus? status, Estimate? estimate}) => RoadmapStep(
        kind: kind,
        status: status ?? this.status,
        reason: reason,
        category: category,
        drillId: drillId,
        buDrillIds: buDrillIds,
        mastery: mastery,
        passStreak: passStreak,
        estimate: estimate ?? this.estimate,
      );
}

final class Roadmap {
  const Roadmap({
    required this.goal,
    required this.steps,
    this.blocked,
    this.from,
    this.target,
    this.pointsNeeded,
  });

  final PlayerGoal goal;
  final List<RoadmapStep> steps;
  final LenHangBlock? blocked;

  /// Lên hạng: hạng hiện tại và hạng đích.
  final Rank? from;
  final Rank? target;

  /// Lên hạng: điểm BU còn thiếu; null khi chưa có bài BU hoàn chỉnh.
  final int? pointsNeeded;

  static bool _progression(RoadmapStep s) => s.kind != StepKind.buLe;

  /// Bước người chơi nên làm bây giờ — Trang chủ hiện bước này.
  RoadmapStep? get currentStep => steps
      .where((s) => _progression(s) && s.status == StepStatus.dangLam)
      .firstOrNull;

  List<RoadmapStep> get missed =>
      steps.where((s) => s.status == StepStatus.khongKip).toList();

  /// Ngày dự kiến của bước cuối còn phải làm và còn kịp; null khi không còn bước nào.
  Estimate? get finish => steps
      .where((s) =>
          _progression(s) &&
          s.status != StepStatus.xong &&
          s.status != StepStatus.khongKip &&
          s.estimate != null)
      .lastOrNull
      ?.estimate;

  /// Mọi bước đã xong. Lên hạng không bao giờ "xong": lên hạng thì đích chuyển.
  bool get achieved =>
      goal.kind != GoalKind.lenHang &&
      steps.where(_progression).every((s) => s.status == StepStatus.xong);
}
```

- [ ] **Step 4: Write `lib/domain/roadmap/practice_facts.dart`**

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/drill_ratio.dart';
import 'package:poolcoachai/domain/player_intelligence.dart';
import 'package:poolcoachai/domain/practice_constants.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Những gì dữ liệu tập nói về từng nhóm — dùng chung cho cách suy bước và
/// cách ghi thành tích, để hai nơi không thể hiểu "xong" theo hai kiểu.
final class PracticeFacts {
  PracticeFacts({
    required this.drills,
    required List<DrillLog> logs,
    required DateTime today,
  })  : day = dateOnly(today),
        sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date)),
        intelligence = computePlayerIntelligence(drills: drills, logs: logs) {
    for (final log in sorted) {
      logsByDrill.putIfAbsent(log.drillId, () => <DrillLog>[]).add(log);
    }
  }

  final List<Drill> drills;
  final DateTime day;
  final List<DrillLog> sorted;
  final PlayerIntelligence intelligence;
  final Map<String, List<DrillLog>> logsByDrill = {};
  late final Map<String, Drill> _byId = {for (final d in drills) d.id: d};
  final Map<SkillCategory, double?> _pace = {};

  int? mastery(SkillCategory c) => intelligence.categories[c]!.mastery;
  int sessions(SkillCategory c) => intelligence.categories[c]!.sessionCount;

  bool atLeastStrong(SkillCategory c) =>
      (mastery(c) ?? -1) >= PracticeConstants.strongCutoff;

  List<DrillLog> logsOf(String drillId) => logsByDrill[drillId] ?? const [];

  /// Bài của bước nhóm (R3): bài đầu tiên còn cần tập; đạt hết thì bài cao nhất.
  Drill? stepDrill(SkillCategory c) => pickDrillInCategory(
        cat: c,
        drills: drills,
        logsByDrillOldestFirst: logsByDrill,
        excludeDrillIds: const {},
      );

  bool drillReady(Drill d) => isReadyForLevelUp(d, logsOf(d.id));

  /// Số buổi đạt liên tiếp gần nhất, tối đa [PracticeConstants.readyStreak].
  int passStreak(Drill? d) {
    if (d == null) return 0;
    var n = 0;
    for (final log in logsOf(d.id).reversed) {
      final ratio = drillRatio(d, log);
      if (ratio == null || ratio < 1) break;
      if (++n == PracticeConstants.readyStreak) break;
    }
    return n;
  }

  /// Bước nhóm xong: từ 75 **và** bài của bước đủ điều kiện lên cấp (mục 4.4).
  bool groupDone(SkillCategory c) {
    final d = stepDrill(c);
    return atLeastStrong(c) && d != null && drillReady(d);
  }

  DateTime? lastLogIn(SkillCategory c) {
    DateTime? at;
    for (final log in sorted) {
      if (_byId[log.drillId]?.cat == c) at = log.date;
    }
    return at;
  }

  DateTime? lastLogOf(String drillId) => logsOf(drillId).lastOrNull?.date;

  double? pace(SkillCategory c) => _pace.putIfAbsent(
      c, () => categoryPacePerDay(cat: c, drills: drills, logs: sorted, today: day));

  /// Lý do của bước nhóm khi không có điểm BU để nói.
  StepReason groupReason(SkillCategory c) {
    final m = mastery(c);
    if (m == null) return Unmeasured(sessions(c));
    return m < PracticeConstants.strongCutoff ? BelowStrong(m) : const NeedStreak();
  }

  RoadmapStep groupStep(SkillCategory c, StepReason reason) {
    final d = stepDrill(c);
    return RoadmapStep(
      kind: StepKind.nhom,
      status: groupDone(c) ? StepStatus.xong : StepStatus.chuaToi,
      reason: reason,
      category: c,
      drillId: d?.id,
      mastery: mastery(c),
      passStreak: passStreak(d),
    );
  }

  /// Yếu trước: nhóm đo được xếp theo độ thuần thục tăng dần; nhóm chưa đo
  /// đứng sau, theo [newcomerOrder] (R4).
  int compareWeakness(SkillCategory a, SkillCategory b) {
    final ma = mastery(a);
    final mb = mastery(b);
    if (ma != null && mb != null && ma != mb) return ma.compareTo(mb);
    if (ma != null && mb == null) return -1;
    if (ma == null && mb != null) return 1;
    return newcomerOrder.indexOf(a).compareTo(newcomerOrder.indexOf(b));
  }
}
```

- [ ] **Step 5: Write `lib/domain/roadmap/roadmap_builder.dart`**

```dart
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/practice_facts.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Lộ trình của [goal], tính lại từ đầu mỗi lần dữ liệu đổi (spec 2026-10-15
/// mục 4). Không lưu bước nào: cùng dữ liệu vào thì cùng lộ trình ra.
Roadmap buildRoadmap({
  required PlayerGoal goal,
  required PlayerRank? rank,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required List<BuTest> tests,
  required BuResult? latestResult,
  required DateTime today,
}) {
  final facts = PracticeFacts(drills: drills, logs: logs, today: today);
  return switch (goal.kind) {
    GoalKind.lenHang => _lenHang(goal, rank, facts, tests, latestResult),
    GoalKind.thuanThucKyNang => throw UnimplementedError('Task 5'),
    GoalKind.chuanBiGiai => throw UnimplementedError('Task 5'),
  };
}

typedef _Lost = ({SkillCategory? cat, int points});

Roadmap _lenHang(
  PlayerGoal goal,
  PlayerRank? rank,
  PracticeFacts facts,
  List<BuTest> tests,
  BuResult? result,
) {
  final from = rank?.rank;
  if (from == null) {
    return Roadmap(goal: goal, blocked: LenHangBlock.noRank, steps: const [
      RoadmapStep(kind: StepKind.xacDinhHang, status: StepStatus.dangLam, reason: NeedRank()),
    ]);
  }
  final target = nextRank(from);
  if (target == null) {
    return Roadmap(goal: goal, blocked: LenHangBlock.topRank, from: from, steps: const []);
  }

  final retestFrom = retestAvailableFrom(tests);
  final needed = result == null ? null : buFloor(target) - result.total;
  final steps = <RoadmapStep>[
    if (result != null) ..._untilEnough(facts, result, needed!) else ..._weakGroups(facts),
    RoadmapStep(kind: StepKind.lamBaiBu, status: StepStatus.chuaToi, reason: RetestFrom(retestFrom)),
  ];
  return Roadmap(
    goal: goal,
    from: from,
    target: target,
    pointsNeeded: needed,
    steps: placeSteps(facts, steps, retestFrom: retestFrom),
  );
}

/// Nhóm dưới 75 hoặc chưa đo, yếu nhất trước (mục 4.1 bước 6).
List<RoadmapStep> _weakGroups(PracticeFacts facts) {
  final weak = SkillCategory.values.where((c) => !facts.atLeastStrong(c)).toList()
    ..sort(facts.compareWeakness);
  return [for (final c in weak) facts.groupStep(c, facts.groupReason(c))];
}

/// Điểm mất giảm dần; bằng nhau thì nhóm yếu hơn trước; S8/S9 sau các nhóm
/// cùng điểm (mục 4.1 bước 4–5).
int _byPointsThenWeakness(PracticeFacts facts, _Lost a, _Lost b) {
  final byPoints = b.points.compareTo(a.points);
  if (byPoints != 0) return byPoints;
  if (a.cat == null) return b.cat == null ? 0 : 1;
  if (b.cat == null) return -1;
  return facts.compareWeakness(a.cat!, b.cat!);
}

RoadmapStep lostStep(PracticeFacts facts, BuResult result, _Lost e) {
  final cat = e.cat;
  if (cat == null) {
    final ids = lostByCategory(result).unmappedIds;
    return RoadmapStep(
      kind: StepKind.buLe,
      status: StepStatus.dangLam,
      reason: LostBuPoints(e.points, ids),
      buDrillIds: ids,
    );
  }
  return facts.groupStep(
      cat, e.points > 0 ? LostBuPoints(e.points, lostDrillsIn(result, cat)) : facts.groupReason(cat));
}

/// Lấy dần nhóm theo điểm mất cho tới khi tổng điểm mất đã lấy ≥ điểm cần
/// thêm (mục 4.1 bước 4).
List<RoadmapStep> _untilEnough(PracticeFacts facts, BuResult result, int needed) {
  final lost = lostByCategory(result);
  final entries = <_Lost>[
    for (final MapEntry(key: cat, value: points) in lost.byCategory.entries) (cat: cat, points: points),
    if (lost.unmapped > 0) (cat: null, points: lost.unmapped),
  ]..sort((a, b) => _byPointsThenWeakness(facts, a, b));

  final picked = <RoadmapStep>[];
  var sum = 0;
  for (final e in entries) {
    if (sum >= needed) break;
    picked.add(lostStep(facts, result, e));
    sum += e.points;
  }
  return picked;
}

/// Đặt ngày dự kiến rồi trạng thái cho cả danh sách (mục 4.4, 4.5).
List<RoadmapStep> placeSteps(
  PracticeFacts facts,
  List<RoadmapStep> steps, {
  DateTime? retestFrom,
  DateTime? eventDate,
}) {
  // Ngày: nối tiếp nhau từ hôm nay. Một bước không đo được tốc độ thì nó và
  // mọi bước sau đều "chưa đủ dữ liệu" — không đoán.
  var cursor = facts.day;
  var known = true;
  final dated = <RoadmapStep>[];
  for (final s in steps) {
    if (s.kind == StepKind.nhom && s.status != StepStatus.xong) {
      final days = known ? daysToStrong(s.mastery, facts.pace(s.category!)) : null;
      if (days == null) {
        known = false;
        dated.add(s.withEstimate(const Estimate.notEnoughData()));
        continue;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + days);
      dated.add(s.withEstimate(Estimate.on(cursor)));
    } else if (s.kind == StepKind.lamBaiBu) {
      final from = retestFrom == null ? null : dateOnly(retestFrom);
      final open = from == null || from.isBefore(cursor) ? cursor : from;
      dated.add(s.withEstimate(known ? Estimate.on(open) : const Estimate.notEnoughData()));
    } else {
      dated.add(s);
    }
  }

  // Trạng thái: bước còn làm đầu tiên là "đang làm"; mục tiêu giải thì bước
  // có ngày sau ngày giải là "không kịp" (mục 4.3). S8/S9 luôn đang làm, không
  // phải bước hiện tại (R5).
  final event = eventDate == null ? null : dateOnly(eventDate);
  var hasCurrent = false;
  final placed = <RoadmapStep>[];
  for (final s in dated) {
    if (s.status == StepStatus.xong || s.kind == StepKind.xacDinhHang) {
      placed.add(s);
    } else if (s.kind == StepKind.buLe) {
      placed.add(s.withStatus(StepStatus.dangLam));
    } else if (event != null && (s.estimate?.date?.isAfter(event) ?? false)) {
      placed.add(s.withStatus(StepStatus.khongKip));
    } else if (!hasCurrent) {
      hasCurrent = true;
      placed.add(s.withStatus(StepStatus.dangLam));
    } else {
      placed.add(s.withStatus(StepStatus.chuaToi));
    }
  }
  return placed;
}
```

- [ ] **Step 6: Run the tests again**

Run: `"$FLUTTER" test test/domain/roadmap`
Expected: PASS.

If `nhóm đo được yếu trước…` fails on `SkillCategory.aiming` vs `safety`, print the two masteries with `computePlayerIntelligence` in a throwaway test before changing anything. The fixture expects aiming ≈ 65 and safety = 50. Fix the fixture's scores, not the ordering rule.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/roadmap/roadmap.dart lib/domain/roadmap/practice_facts.dart lib/domain/roadmap/roadmap_builder.dart test/domain/roadmap/roadmap_len_hang_test.dart
git commit -m "Build the rank-up roadmap from lost BU points, weakest groups and the 28-day pace

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Thuần thục kỹ năng and Chuẩn bị giải (spec §4.2, §4.3)

**Files:**
- Modify: `lib/domain/roadmap/roadmap_builder.dart`
- Create: `test/domain/roadmap/roadmap_other_goals_test.dart`

**Interfaces:**
- Consumes: Task 4 (`PracticeFacts`, `placeSteps`, `lostStep`, `_byPointsThenWeakness`).
- Produces: `buildRoadmap` handles all three `GoalKind`s; nothing throws `UnimplementedError` any more.

- [ ] **Step 1: Write the failing tests**

`test/domain/roadmap/roadmap_other_goals_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  final rank = PlayerRank(
      rank: Rank.h, source: RankSource.estimated,
      onboardingState: OnboardingState.done, updatedAt: on(10, 1));

  Roadmap build(PlayerGoal goal, {List<DrillLog> logs = const [], BuResult? result}) => buildRoadmap(
        goal: goal,
        rank: rank,
        drills: roadmapDrills,
        logs: logs,
        tests: const [],
        latestResult: result,
        today: roadmapToday,
      );

  group('Thuần thục kỹ năng (mục 4.2)', () {
    final goal = PlayerGoal(
        goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: on(10, 1));

    test('một bước mỗi bài theo cấp, cuối là bước nhóm mang ngày dự kiến', () {
      final r = build(goal, logs: sessions('a1', 9, [on(10, 10), on(10, 11), on(10, 12)]));
      expect(r.steps.map((s) => (s.kind, s.drillId)), [
        (StepKind.baiTap, 'a1'),
        (StepKind.baiTap, 'a2'),
        (StepKind.nhom, 'a2'),
      ]);
      expect(r.steps[0].status, StepStatus.xong);
      expect(r.steps[1].status, StepStatus.dangLam);
      expect(r.steps[1].reason, isA<DrillLevel>());
      expect((r.steps[1].reason as DrillLevel).level, 2);
      expect(r.steps[0].estimate, isNull);
      expect(r.steps[2].estimate, isNotNull);
      expect(r.achieved, isFalse);
    });

    test('đủ hai bài và nhóm từ 75: mục tiêu đạt', () {
      final r = build(goal, logs: [
        ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a2', 9, [on(10, 10), on(10, 11), on(10, 12)]),
      ]);
      expect(r.steps.every((s) => s.status == StepStatus.xong), isTrue);
      expect(r.achieved, isTrue);
      expect(r.currentStep, isNull);
      expect(r.finish, isNull);
    });

    test('hai nhóm khác nhau cho hai lộ trình khác nhau', () {
      final safety = build(PlayerGoal(
          goalId: 'g3', kind: GoalKind.thuanThucKyNang, category: SkillCategory.safety, createdAt: on(10, 1)));
      expect(safety.steps.map((s) => s.drillId), ['s1', 's1']);
      expect(build(goal).steps.map((s) => s.drillId), isNot(['s1', 's1']));
    });
  });

  group('Chuẩn bị giải (mục 4.3)', () {
    PlayerGoal tournament(DateTime date) =>
        PlayerGoal(goalId: 'g4', kind: GoalKind.chuanBiGiai, eventDate: date, createdAt: on(10, 1));

    final slowAiming = [
      ...sessions('a1', 4, [on(9, 1), on(9, 2), on(9, 3)]),
      ...sessions('a1', 6, [on(10, 10), on(10, 11), on(10, 12)]),
    ];

    test('bước có ngày sau ngày giải chuyển xuống không kịp; bước chưa đủ dữ liệu vẫn ở lại', () {
      final r = build(tournament(DateTime(2026, 10, 16)), logs: slowAiming);
      expect(r.steps.first.category, SkillCategory.aiming);
      expect(r.steps.first.status, StepStatus.khongKip);
      expect(r.missed.single.category, SkillCategory.aiming);
      expect(r.steps[1].estimate!.date, isNull);
      expect(r.steps[1].status, StepStatus.dangLam);
      expect(r.steps.any((s) => s.kind == StepKind.lamBaiBu), isFalse);
    });

    test('ngày giải xa thì bước đó vẫn kịp', () {
      final r = build(tournament(DateTime(2027, 6, 1)), logs: slowAiming);
      expect(r.steps.first.status, StepStatus.dangLam);
      expect(r.missed, isEmpty);
    });

    test('có bài BU: nhóm dưới 75 xếp theo điểm mất, nhóm không mất điểm theo độ yếu', () {
      final r = build(
        tournament(DateTime(2027, 6, 1)),
        logs: sessions('k1', 9, [on(10, 10), on(10, 11), on(10, 12)]),
        result: BuResult(testId: 't', completedAt: on(10, 1), total: 120, lost: const {'S5': 6, 'F3': 2, 'S9': 3}),
      );
      expect(r.steps.map((s) => s.category), [
        SkillCategory.safety, // 6
        null, // S9: 3
        SkillCategory.position, // 2
        SkillCategory.aiming, // 0, chưa đo — theo thứ tự làm quen
        SkillCategory.breakShot,
        SkillCategory.bank,
      ]);
      expect(r.steps.any((s) => s.category == SkillCategory.kick), isFalse);
    });

    test('mọi nhóm từ 75: không còn bước nào, mục tiêu đạt', () {
      final logs = [
        for (final id in ['a1', 'p1', 'b1', 's1', 'k1', 'n1'])
          ...sessions(id, 9, [on(10, 10), on(10, 11), on(10, 12)]),
      ];
      final r = build(tournament(DateTime(2027, 6, 1)), logs: logs);
      expect(r.steps, isEmpty);
      expect(r.achieved, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/roadmap_other_goals_test.dart`
Expected: FAIL with `UnimplementedError: Task 5`.

- [ ] **Step 3: Implement the two goals.** In `roadmap_builder.dart`, replace the two `throw UnimplementedError('Task 5')` arms:

```dart
    GoalKind.thuanThucKyNang => _skill(goal, facts),
    GoalKind.chuanBiGiai => _tournament(goal, facts, latestResult),
```

and add after `_untilEnough`:

```dart
/// Mỗi bài của nhóm một bước, theo cấp; bước cuối là cả nhóm (R6).
Roadmap _skill(PlayerGoal goal, PracticeFacts facts) {
  final c = goal.category!;
  final inGroup = facts.drills.where((d) => d.cat == c).toList()
    ..sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });
  final steps = <RoadmapStep>[
    for (final d in inGroup)
      RoadmapStep(
        kind: StepKind.baiTap,
        status: facts.drillReady(d) ? StepStatus.xong : StepStatus.chuaToi,
        reason: DrillLevel(d.level),
        category: c,
        drillId: d.id,
        passStreak: facts.passStreak(d),
      ),
    facts.groupStep(c, facts.groupReason(c)),
  ];
  return Roadmap(goal: goal, steps: placeSteps(facts, steps));
}

/// Mọi nhóm dưới 75; có bài BU thì theo điểm mất, không thì theo độ yếu. Không
/// có bước làm BU; bước không kịp trước ngày giải xếp riêng (mục 4.3).
Roadmap _tournament(PlayerGoal goal, PracticeFacts facts, BuResult? result) {
  final below = SkillCategory.values.where((c) => !facts.atLeastStrong(c)).toList();
  final List<RoadmapStep> steps;
  if (result == null) {
    below.sort(facts.compareWeakness);
    steps = [for (final c in below) facts.groupStep(c, facts.groupReason(c))];
  } else {
    final lost = lostByCategory(result);
    final entries = <_Lost>[
      for (final c in below) (cat: c, points: lost.byCategory[c] ?? 0),
      if (lost.unmapped > 0) (cat: null, points: lost.unmapped),
    ]..sort((a, b) => _byPointsThenWeakness(facts, a, b));
    steps = [for (final e in entries) lostStep(facts, result, e)];
  }
  return Roadmap(goal: goal, steps: placeSteps(facts, steps, eventDate: goal.eventDate));
}
```

- [ ] **Step 4: Run every roadmap test**

Run: `"$FLUTTER" test test/domain/roadmap test/architecture_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/roadmap/roadmap_builder.dart test/domain/roadmap/roadmap_other_goals_test.dart
git commit -m "Build the skill-mastery and tournament roadmaps, setting aside steps that miss the date

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Achievements from real events only (spec §7)

**Files:**
- Create: `lib/domain/roadmap/achievements.dart`
- Create: `test/domain/roadmap/achievements_test.dart`
- Modify: `test/architecture_test.dart` (one more test)

**Interfaces:**
- Consumes: `PracticeFacts` (Task 4), `PlayerGoal`/`GoalKind` (Task 1), `streakDays` (`recommendation.dart`).
- Produces:
  - `enum AchievementKind { xongBuoc, duDieuKienLenCap, chuoiNgay }`
  - `const streakMilestones = [7, 14, 30, 60, 100]`
  - `final class Achievement({required AchievementKind kind, required String refId, required DateTime achievedAt})` with `String get key`, which is `'<kind>|<refId>'`
  - `List<Achievement> newAchievements({required PlayerGoal? goal, required List<Drill> drills, required List<DrillLog> logs, required Set<String> existing, required DateTime today})`

- [ ] **Step 1: Write the failing tests**

`test/domain/roadmap/achievements_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/roadmap_fixtures.dart';

void main() {
  List<Achievement> run({PlayerGoal? goal, List<DrillLog> logs = const [], Set<String> existing = const {}}) =>
      newAchievements(goal: goal, drills: roadmapDrills, logs: logs, existing: existing, today: roadmapToday);

  test('mốc chuỗi ngày đúng 7 / 14 / 30 / 60 / 100 (chủ sản phẩm chọn 15/10)', () {
    expect(streakMilestones, [7, 14, 30, 60, 100]);
  });

  group('đủ điều kiện lên cấp', () {
    test('đủ điều kiện lên cấp ghi đúng ngày buổi đạt thứ ba', () {
      final a = run(logs: sessions('a1', 9, [on(10, 1), on(10, 3), on(10, 5)]));
      final ready = a.where((x) => x.kind == AchievementKind.duDieuKienLenCap).single;
      expect(ready.refId, 'a1');
      expect(ready.achievedAt, on(10, 5));
    });

    test('đã ghi rồi thì không ghi lại', () {
      final a = run(
        logs: sessions('a1', 9, [on(10, 1), on(10, 3), on(10, 5)]),
        existing: {'duDieuKienLenCap|a1'},
      );
      expect(a.where((x) => x.kind == AchievementKind.duDieuKienLenCap), isEmpty);
    });

    test('chưa đủ ba buổi đạt thì không có', () {
      expect(run(logs: sessions('a1', 9, [on(10, 1), on(10, 3)])), isEmpty);
    });
  });

  group('chuỗi ngày tập', () {
    test('chuỗi 15 ngày tới hôm nay ghi mốc 7 và 14, ngày hôm nay', () {
      final days = [for (var d = 1; d <= 15; d++) on(10, d)];
      final streak = run(logs: sessions('p1', 2, days)).where((x) => x.kind == AchievementKind.chuoiNgay).toList();
      expect(streak.map((x) => x.refId), ['7', '14']);
      expect(streak.first.achievedAt, DateTime(2026, 10, 15));
    });

    test('mốc đã có thì không ghi lại kể cả khi chuỗi đứt rồi chạm lại', () {
      final days = [for (var d = 1; d <= 8; d++) on(10, d + 7)];
      final streak = run(logs: sessions('p1', 2, days), existing: {'chuoiNgay|7'})
          .where((x) => x.kind == AchievementKind.chuoiNgay);
      expect(streak, isEmpty);
    });
  });

  group('xong bước (R7)', () {
    final lenHang = PlayerGoal(goalId: 'g1', kind: GoalKind.lenHang, createdAt: on(10, 4));

    test('nhóm xong bằng buổi tập từ khi đặt mục tiêu: ghi một lần, gắn mục tiêu', () {
      final logs = [
        ...sessions('a1', 9, [on(10, 1), on(10, 2), on(10, 3)]),
        ...sessions('a2', 9, [on(10, 6), on(10, 7), on(10, 8)]),
      ];
      final done = run(goal: lenHang, logs: logs).where((x) => x.kind == AchievementKind.xongBuoc).single;
      expect(done.refId, 'g1:${SkillCategory.aiming.name}');
      expect(done.achievedAt, on(10, 8));
      expect(
        run(goal: lenHang, logs: logs, existing: {done.key}).where((x) => x.kind == AchievementKind.xongBuoc),
        isEmpty,
      );
    });

    test('nhóm đã xong từ trước khi đặt mục tiêu: không phải sự kiện mới, không ghi', () {
      final logs = [
        ...sessions('a1', 9, [on(9, 1), on(9, 2), on(9, 3)]),
        ...sessions('a2', 9, [on(9, 6), on(9, 7), on(9, 8)]),
      ];
      expect(run(goal: lenHang, logs: logs).where((x) => x.kind == AchievementKind.xongBuoc), isEmpty);
    });

    test('thuần thục: mỗi bài một lần, nhóm một lần', () {
      final goal = PlayerGoal(
          goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: on(10, 1));
      final logs = [
        ...sessions('a1', 9, [on(10, 2), on(10, 3), on(10, 4)]),
        ...sessions('a2', 9, [on(10, 6), on(10, 7), on(10, 8)]),
      ];
      final refs = run(goal: goal, logs: logs)
          .where((x) => x.kind == AchievementKind.xongBuoc)
          .map((x) => x.refId)
          .toList();
      expect(refs, ['g2:a1', 'g2:a2', 'g2:aiming']);
    });

    test('không có mục tiêu: không có thành tích xong bước', () {
      final logs = sessions('a1', 9, [on(10, 6), on(10, 7), on(10, 8)]);
      expect(run(logs: logs).where((x) => x.kind == AchievementKind.xongBuoc), isEmpty);
    });
  });
}
```

Add to `test/architecture_test.dart`:

```dart
  test('thành tích chỉ sinh ra từ newAchievements', () {
    // Thành tích tạo tay là thành tích "ảo" (spec 2026-10-15 mục 2.7). Ngoài
    // lõi và tầng dữ liệu, không nơi nào được dựng Achievement(.
    final offenders = <String>[];
    for (final file in dartFilesIn('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/domain/roadmap/achievements.dart')) continue;
      if (path.endsWith('lib/data/database/roadmap_converters.dart')) continue;
      if (codeOnly(file.readAsStringSync()).contains('Achievement(')) offenders.add(path);
    }
    expect(offenders, isEmpty,
        reason: 'thành tích phải đi từ một sự kiện dữ liệu thật qua newAchievements');
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/domain/roadmap/achievements_test.dart test/architecture_test.dart`
Expected: FAIL at compile time: `achievements.dart` is missing.

- [ ] **Step 3: Write `lib/domain/roadmap/achievements.dart`**

```dart
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/recommendation.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/pace.dart';
import 'package:poolcoachai/domain/roadmap/practice_facts.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Ba loại thành tích — mỗi loại một sự kiện dữ liệu thật (spec mục 7).
enum AchievementKind { xongBuoc, duDieuKienLenCap, chuoiNgay }

/// Mốc chuỗi ngày tập liên tiếp (chủ sản phẩm chọn 15/10/2026).
const streakMilestones = <int>[7, 14, 30, 60, 100];

final class Achievement {
  const Achievement({required this.kind, required this.refId, required this.achievedAt});

  final AchievementKind kind;
  final String refId;
  final DateTime achievedAt;

  /// Mỗi (loại, refId) chỉ có một thành tích.
  String get key => '${kind.name}|$refId';

  @override
  bool operator ==(Object other) =>
      other is Achievement && other.kind == kind && other.refId == refId && other.achievedAt == achievedAt;

  @override
  int get hashCode => Object.hash(kind, refId, achievedAt);

  @override
  String toString() => 'Achievement($key, $achievedAt)';
}

/// Thành tích có sự kiện thật mà chưa nằm trong [existing] (các `key`).
///
/// Ngày ghi là ngày của buổi tập gây ra sự kiện, không phải lúc app nhận ra:
/// mở app lần đầu sau bản cập nhật thì bài đã đủ điều kiện từ tuần trước vẫn
/// mang ngày tuần trước. Riêng chuỗi ngày ghi hôm nay — chuỗi chạm mốc hôm nay.
List<Achievement> newAchievements({
  required PlayerGoal? goal,
  required List<Drill> drills,
  required List<DrillLog> logs,
  required Set<String> existing,
  required DateTime today,
}) {
  final facts = PracticeFacts(drills: drills, logs: logs, today: today);
  final out = <Achievement>[];
  void add(AchievementKind kind, String refId, DateTime at) {
    final a = Achievement(kind: kind, refId: refId, achievedAt: at);
    if (!existing.contains(a.key) && !out.any((o) => o.key == a.key)) out.add(a);
  }

  for (final d in drills) {
    if (facts.drillReady(d)) add(AchievementKind.duDieuKienLenCap, d.id, facts.lastLogOf(d.id)!);
  }

  if (goal != null) {
    // Chỉ tính khi buổi gây ra nó nằm trong thời gian của mục tiêu này (R7).
    void doneUnderGoal(String subject, DateTime? lastLog) {
      if (lastLog == null || lastLog.isBefore(goal.createdAt)) return;
      add(AchievementKind.xongBuoc, '${goal.goalId}:$subject', lastLog);
    }

    if (goal.kind == GoalKind.thuanThucKyNang) {
      final c = goal.category!;
      final inGroup = drills.where((d) => d.cat == c).toList()
        ..sort((a, b) {
          final byLevel = a.level.compareTo(b.level);
          return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
        });
      for (final d in inGroup) {
        if (facts.drillReady(d)) doneUnderGoal(d.id, facts.lastLogOf(d.id));
      }
      if (facts.groupDone(c)) doneUnderGoal(c.name, facts.lastLogIn(c));
    } else {
      for (final c in SkillCategory.values) {
        if (facts.groupDone(c)) doneUnderGoal(c.name, facts.lastLogIn(c));
      }
    }
  }

  final streak = streakDays(logs: logs, timerSessions: const [], today: today);
  for (final m in streakMilestones) {
    if (streak >= m) add(AchievementKind.chuoiNgay, '$m', dateOnly(today));
  }
  return out;
}
```

- [ ] **Step 4: Run the tests again**

Run: `"$FLUTTER" test test/domain/roadmap test/architecture_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/roadmap/achievements.dart test/domain/roadmap/achievements_test.dart test/architecture_test.dart
git commit -m "Record achievements only from finished steps, ready drills and streak milestones

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Drift schema 4 and the converters (spec §6)

**Files:**
- Modify: `lib/data/database/database.dart` (two tables after `BuDrillResultRows`, `@DriftDatabase` list, `schemaVersion`, `onUpgrade`)
- Create: `lib/data/database/roadmap_converters.dart`
- Modify: `test/data/database/migration_test.dart` (the v2 → v3 test checks `schemaVersion`; add a v3 → v4 test)
- Create: `test/data/database/roadmap_converters_test.dart`

**Interfaces:**
- Consumes: `GoalRecord`, `PlayerGoal`, `GoalKind` (Task 1), `Achievement`, `AchievementKind` (Task 6).
- Produces:
  - `PlayerGoalRows` with columns `userId` (PK), `goalId?`, `kind?`, `category?`, `eventDate?`, `createdAt?`, `updatedAt`, `syncedAt?`
  - `AchievementRows` with columns `id` (PK), `userId`, `kind`, `refId`, `achievedAt`, `syncedAt?`, unique on (`userId`, `kind`, `refId`)
  - `GoalRecord toGoalRecord(PlayerGoalRow r)`
  - `PlayerGoalRow toGoalRow(GoalRecord g, {required String userId, DateTime? syncedAt})`
  - `const remoteGoalFields`, `Map<String, Object?> toRemoteGoal(PlayerGoalRow r)`, `GoalRecord goalFromRemote(Map<String, Object?> j)`
  - `String achievementId(String userId, Achievement a)`
  - `Achievement toAchievement(AchievementRow r)`, `AchievementRow toAchievementRow(Achievement a, {required String userId, DateTime? syncedAt})`
  - `const remoteAchievementFields`, `Map<String, Object?> toRemoteAchievement(AchievementRow r)`, `AchievementRow achievementFromRemote(Map<String, Object?> j, {required String userId, required DateTime syncedAt})`

- [ ] **Step 1: Write the failing tests**

In `test/data/database/migration_test.dart`, change the line `expect(db.schemaVersion, 3);` in the v2 → v3 test to `expect(db.schemaVersion, 4);`. Then `grep -rn "schemaVersion, 3" test` and fix any other hit the same way. Append:

```dart
  test('nâng từ v3 lên v4 thì có bảng mục tiêu và thành tích, giữ nguyên buổi tập',
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
      raw.execute('PRAGMA user_version = 3;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(db.schemaVersion, 4);
    expect((await db.select(db.drillLogRows).get()).single.id, 'cu');

    final at = DateTime(2026, 10, 15, 9);
    await db.into(db.playerGoalRows).insert(
        PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: at));
    await db.into(db.achievementRows).insert(AchievementRowsCompanion.insert(
        id: 'x', userId: 'u1', kind: 'chuoiNgay', refId: '7', achievedAt: at));
    expect((await db.select(db.playerGoalRows).get()).single.kind, isNull);
    expect((await db.select(db.achievementRows).get()).single.refId, '7');
  });
```

`test/data/database/roadmap_converters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final at = DateTime(2026, 10, 15, 9);
  final goal = GoalRecord(
    updatedAt: at,
    goal: PlayerGoal(
        goalId: 'g1', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2), createdAt: at),
  );

  test('mục tiêu qua dòng Drift rồi về nguyên vẹn', () {
    expect(toGoalRecord(toGoalRow(goal, userId: 'u1')), goal);
    final dropped = GoalRecord(updatedAt: at);
    expect(toGoalRecord(toGoalRow(dropped, userId: 'u1')), dropped);
  });

  test('mục tiêu qua Directus rồi về nguyên vẹn; id là id người dùng', () {
    final skill = GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g2', kind: GoalKind.thuanThucKyNang, category: SkillCategory.bank, createdAt: at),
    );
    final json = toRemoteGoal(toGoalRow(skill, userId: 'u1'));
    expect(json['id'], 'u1');
    expect(json['kind'], 'thuanThucKyNang');
    expect(json['category'], 'bank');
    expect(goalFromRemote(json), skill);
    expect(goalFromRemote(toRemoteGoal(toGoalRow(GoalRecord(updatedAt: at), userId: 'u1'))).goal, isNull);
  });

  test('hai máy cùng người cùng thành tích ra cùng id', () {
    final a = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at);
    final b = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at.add(const Duration(days: 1)));
    expect(achievementId('u1', a), achievementId('u1', b));
    expect(achievementId('u1', a), isNot(achievementId('u2', a)));
    expect(achievementId('u1', a), isNot(achievementId('u1',
        Achievement(kind: AchievementKind.chuoiNgay, refId: '14', achievedAt: at))));
  });

  test('thành tích qua Drift và Directus rồi về nguyên vẹn', () {
    final a = Achievement(kind: AchievementKind.xongBuoc, refId: 'g1:aiming', achievedAt: at);
    final row = toAchievementRow(a, userId: 'u1');
    expect(toAchievement(row), a);
    final back = achievementFromRemote(toRemoteAchievement(row), userId: 'u1', syncedAt: at);
    expect(toAchievement(back), a);
    expect(back.syncedAt, at);
    expect(back.id, row.id);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/data/database`
Expected: FAIL at compile time: there is no `playerGoalRows` and no `roadmap_converters.dart`.

- [ ] **Step 3: Add the tables to `database.dart`**

After `BuDrillResultRows`, before `// ─── Database ───`:

```dart
// ─── Lộ trình (spec 2026-10-15 mục 6) ──────────────────────────────────────

/// Mục tiêu của một tài khoản — mỗi tài khoản một dòng. Bỏ mục tiêu thì dòng
/// còn đó với [kind] rỗng, để máy khác biết "đã bỏ" là bản mới hơn (R2).
class PlayerGoalRows extends Table {
  TextColumn get userId => text()();

  /// Đổi mục tiêu là ra id mới.
  TextColumn get goalId => text().nullable()();

  /// `GoalKind.name`; null là đã bỏ mục tiêu.
  TextColumn get kind => text().nullable()();

  /// `SkillCategory.name` cho Thuần thục kỹ năng.
  TextColumn get category => text().nullable()();
  DateTimeColumn get eventDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Thành tích — chỉ thêm. Id tính từ (người, loại, refId), nên hai máy ghi
/// cùng một thành tích ra cùng một id (R8).
class AchievementRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// `AchievementKind.name`.
  TextColumn get kind => text()();
  TextColumn get refId => text()();
  DateTimeColumn get achievedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, kind, refId},
      ];
}
```

Add `PlayerGoalRows, AchievementRows,` at the end of the `@DriftDatabase(tables: [...])` list. Change `schemaVersion` to `4`, and add to `onUpgrade` after the `from < 3` block:

```dart
          if (from < 4) {
            // Chỉ thêm bảng (spec 2026-10-15 mục 6).
            await m.createTable(playerGoalRows);
            await m.createTable(achievementRows);
          }
```

Run `"$DART" run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Write `lib/data/database/roadmap_converters.dart`**

```dart
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:uuid/uuid.dart';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _local(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();

GoalRecord toGoalRecord(PlayerGoalRow r) => GoalRecord(
      updatedAt: r.updatedAt,
      goal: r.kind == null
          ? null
          : PlayerGoal(
              goalId: r.goalId!,
              kind: GoalKind.values.byName(r.kind!),
              category: r.category == null ? null : SkillCategory.values.byName(r.category!),
              eventDate: r.eventDate,
              createdAt: r.createdAt!,
            ),
    );

PlayerGoalRow toGoalRow(GoalRecord g, {required String userId, DateTime? syncedAt}) => PlayerGoalRow(
      userId: userId,
      goalId: g.goal?.goalId,
      kind: g.goal?.kind.name,
      category: g.goal?.category?.name,
      eventDate: g.goal?.eventDate,
      createdAt: g.goal?.createdAt,
      updatedAt: g.updatedAt,
      syncedAt: syncedAt,
    );

const remoteGoalFields = 'id,goal_id,kind,category,event_date,created_at,updated_at';

/// Dòng mục tiêu cho `POST /items/player_goals` (id là id người dùng, R1).
Map<String, Object?> toRemoteGoal(PlayerGoalRow r) => {
      'id': r.userId,
      'goal_id': r.goalId,
      'kind': r.kind,
      'category': r.category,
      'event_date': _iso(r.eventDate),
      'created_at': _iso(r.createdAt),
      'updated_at': _iso(r.updatedAt),
    };

GoalRecord goalFromRemote(Map<String, Object?> j) => GoalRecord(
      updatedAt: _local(j['updated_at'])!,
      goal: j['kind'] == null
          ? null
          : PlayerGoal(
              goalId: j['goal_id']! as String,
              kind: GoalKind.values.byName(j['kind']! as String),
              category: j['category'] == null ? null : SkillCategory.values.byName(j['category']! as String),
              eventDate: _local(j['event_date']),
              createdAt: _local(j['created_at'])!,
            ),
    );

/// Cùng người, cùng loại, cùng refId thì cùng id, trên mọi máy (R8).
String achievementId(String userId, Achievement a) => const Uuid()
    .v5(Namespace.url.value, 'poolcoachai:achievement:$userId:${a.kind.name}:${a.refId}');

Achievement toAchievement(AchievementRow r) => Achievement(
      kind: AchievementKind.values.byName(r.kind),
      refId: r.refId,
      achievedAt: r.achievedAt,
    );

AchievementRow toAchievementRow(Achievement a, {required String userId, DateTime? syncedAt}) =>
    AchievementRow(
      id: achievementId(userId, a),
      userId: userId,
      kind: a.kind.name,
      refId: a.refId,
      achievedAt: a.achievedAt,
      syncedAt: syncedAt,
    );

const remoteAchievementFields = 'id,kind,ref_id,achieved_at';

Map<String, Object?> toRemoteAchievement(AchievementRow r) => {
      'id': r.id,
      'kind': r.kind,
      'ref_id': r.refId,
      'achieved_at': _iso(r.achievedAt),
    };

AchievementRow achievementFromRemote(
  Map<String, Object?> j, {
  required String userId,
  required DateTime syncedAt,
}) =>
    AchievementRow(
      id: j['id']! as String,
      userId: userId,
      kind: j['kind']! as String,
      refId: j['ref_id']! as String,
      achievedAt: _local(j['achieved_at'])!,
      syncedAt: syncedAt,
    );
```

`Namespace` is exported by `package:uuid/uuid.dart` in uuid 4.x. If the analyzer reports `Undefined name 'Namespace'`, add `import 'package:uuid/data.dart';` and log the ruling.

- [ ] **Step 5: Run the tests again**

Run: `"$FLUTTER" test test/data/database test/architecture_test.dart`
Expected: PASS. The architecture test allows `Achievement(` in `roadmap_converters.dart` (Task 6).

- [ ] **Step 6: Commit** (`database.g.dart` stays untracked; it is git-ignored)

```bash
git add lib/data/database/database.dart lib/data/database/roadmap_converters.dart test/data/database/migration_test.dart test/data/database/roadmap_converters_test.dart
git commit -m "Add the goal and achievement tables in Drift schema 4 with their converters

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `RoadmapRepository` and sign-out (spec §6)

**Files:**
- Create: `lib/data/repositories/roadmap_repository.dart`
- Modify: `lib/data/sync/account_actions.dart` (`signOutAndForget`, new `pendingRoadmapCount`)
- Create: `test/data/repositories/roadmap_repository_test.dart`
- Modify: `test/data/sync/account_actions_test.dart` (one test)

**Interfaces:**
- Consumes: Task 7 tables and converters.
- Produces:
  - `RoadmapRepository(AppDatabase db, {required String userId, required DateTime Function() now, required String Function() newId})` with these methods:
    - `Stream<GoalRecord?> watchGoal()`
    - `Future<void> setGoal({required GoalKind kind, SkillCategory? category, DateTime? eventDate})`
    - `Future<void> clearGoal()`
    - `Stream<List<Achievement>> watchAchievements()`, newest first
    - `Future<void> recordAchievements(List<Achievement> list)`
  - `Future<int> pendingRoadmapCount(AppDatabase db, String userId)`

- [ ] **Step 1: Write the failing tests**

`test/data/repositories/roadmap_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  late AppDatabase db;
  var clock = DateTime(2026, 10, 15, 9);
  var ids = 0;

  RoadmapRepository repo(String userId) =>
      RoadmapRepository(db, userId: userId, now: () => clock, newId: () => 'g${++ids}');

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = DateTime(2026, 10, 15, 9);
    ids = 0;
  });
  tearDown(() => db.close());

  test('đặt mục tiêu ghi xuống Drift, chưa đồng bộ', () async {
    await repo('u1').setGoal(kind: GoalKind.thuanThucKyNang, category: SkillCategory.kick);
    final g = await repo('u1').watchGoal().first;
    expect(g!.goal!.kind, GoalKind.thuanThucKyNang);
    expect(g.goal!.category, SkillCategory.kick);
    expect(g.goal!.goalId, 'g1');
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, isNull);
  });

  test('đổi mục tiêu ra id mới và ngày tạo mới', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    clock = DateTime(2026, 10, 16, 9);
    await repo('u1').setGoal(kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 11, 2, 18));
    final g = (await repo('u1').watchGoal().first)!.goal!;
    expect(g.goalId, 'g2');
    expect(g.createdAt, clock);
    expect(g.eventDate, DateTime(2026, 11, 2), reason: 'ngày giải chỉ giữ ngày');
  });

  test('bỏ mục tiêu để lại dòng rỗng mới hơn (R2)', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    clock = DateTime(2026, 10, 16, 9);
    await repo('u1').clearGoal();
    final g = await repo('u1').watchGoal().first;
    expect(g!.goal, isNull);
    expect(g.updatedAt, clock);
  });

  test('ghi thành tích hai lần chỉ còn một dòng; mới nhất trước', () async {
    final a = Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: DateTime(2026, 10, 10));
    final b = Achievement(kind: AchievementKind.duDieuKienLenCap, refId: 'd1', achievedAt: DateTime(2026, 10, 12));
    await repo('u1').recordAchievements([a]);
    await repo('u1').recordAchievements([a, b]);
    expect(await repo('u1').watchAchievements().first, [b, a]);
  });

  test('mục tiêu và thành tích tách theo người', () async {
    await repo('u1').setGoal(kind: GoalKind.lenHang);
    await repo('u1').recordAchievements(
        [Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: DateTime(2026, 10, 10))]);
    expect(await repo('u2').watchGoal().first, isNull);
    expect(await repo('u2').watchAchievements().first, isEmpty);
  });
}
```

Append to `test/data/sync/account_actions_test.dart`, inside its `main()`. Use the file's existing `db` setup. If the file builds its own `AppDatabase` per test, follow that pattern, and use its existing fake for `auth`:

```dart
  test('đăng xuất xoá mục tiêu và thành tích của người đó; đếm được dòng chưa đồng bộ', () async {
    final at = DateTime(2026, 10, 15, 9);
    await db.into(db.playerGoalRows).insert(PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: at));
    await db.into(db.achievementRows).insert(AchievementRowsCompanion.insert(
        id: 'x', userId: 'u1', kind: 'chuoiNgay', refId: '7', achievedAt: at));
    await db.into(db.playerGoalRows).insert(PlayerGoalRowsCompanion.insert(userId: 'u2', updatedAt: at));

    expect(await pendingRoadmapCount(db, 'u1'), 2);
    await signOutAndForget(db: db, auth: FakeAuthRepository.signedIn(), userId: 'u1');

    expect((await db.select(db.playerGoalRows).get()).map((r) => r.userId), ['u2']);
    expect(await db.select(db.achievementRows).get(), isEmpty);
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/data/repositories/roadmap_repository_test.dart test/data/sync/account_actions_test.dart`
Expected: FAIL at compile time.

- [ ] **Step 3: Write `lib/data/repositories/roadmap_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Mục tiêu và thành tích của một người chơi trên máy này. Ghi xuống Drift
/// trước, đồng bộ sau (spec 2026-10-15 mục 6) — bên đồng bộ tự thấy dòng có
/// `syncedAt` rỗng.
class RoadmapRepository {
  RoadmapRepository(
    this._db, {
    required this._userId,
    required this._now,
    required this._newId,
  });

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  SimpleSelectStatement<$PlayerGoalRowsTable, PlayerGoalRow> _goalQuery() =>
      _db.select(_db.playerGoalRows)..where((t) => t.userId.equals(_userId));

  Stream<GoalRecord?> watchGoal() =>
      _goalQuery().watchSingleOrNull().map((r) => r == null ? null : toGoalRecord(r));

  /// Đặt (hoặc đổi) mục tiêu: id mới, tính lại từ đầu (spec mục 2.4).
  Future<void> setGoal({required GoalKind kind, SkillCategory? category, DateTime? eventDate}) {
    final now = _now();
    return _write(GoalRecord(
      updatedAt: now,
      goal: PlayerGoal(
        goalId: _newId(),
        kind: kind,
        category: kind == GoalKind.thuanThucKyNang ? category : null,
        eventDate: kind == GoalKind.chuanBiGiai
            ? DateTime(eventDate!.year, eventDate.month, eventDate.day)
            : null,
        createdAt: now,
      ),
    ));
  }

  Future<void> clearGoal() => _write(GoalRecord(updatedAt: _now()));

  Future<void> _write(GoalRecord g) =>
      _db.into(_db.playerGoalRows).insertOnConflictUpdate(toGoalRow(g, userId: _userId));

  Stream<List<Achievement>> watchAchievements() => (_db.select(_db.achievementRows)
        ..where((t) => t.userId.equals(_userId))
        ..orderBy([(t) => OrderingTerm.desc(t.achievedAt), (t) => OrderingTerm.asc(t.refId)]))
      .watch()
      .map((rows) => rows.map(toAchievement).toList());

  /// Thành tích đã có (cùng id) thì bỏ qua — chỉ thêm, không sửa.
  Future<void> recordAchievements(List<Achievement> list) => _db.batch((b) {
        for (final a in list) {
          b.insert(_db.achievementRows, toAchievementRow(a, userId: _userId),
              mode: InsertMode.insertOrIgnore);
        }
      });
}
```

- [ ] **Step 4: Extend `account_actions.dart`**

At the end of `signOutAndForget`, after the `buTestRows` delete:

```dart
  // Mục tiêu và thành tích cũng là dữ liệu riêng của người này.
  await (db.delete(db.playerGoalRows)..where((t) => t.userId.equals(userId))).go();
  await (db.delete(db.achievementRows)..where((t) => t.userId.equals(userId))).go();
```

And after `pendingAssessmentCount`:

```dart
/// Dòng mục tiêu và thành tích của [userId] chưa lên server.
Future<int> pendingRoadmapCount(AppDatabase db, String userId) async {
  final goals = await (db.select(db.playerGoalRows)
        ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
      .get();
  final achievements = await (db.select(db.achievementRows)
        ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
      .get();
  return goals.length + achievements.length;
}
```

- [ ] **Step 5: Run the tests again**

Run: `"$FLUTTER" test test/data`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/roadmap_repository.dart lib/data/sync/account_actions.dart test/data/repositories/roadmap_repository_test.dart test/data/sync/account_actions_test.dart
git commit -m "Store the goal and achievements per account in Drift and forget them on sign-out

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `RoadmapSyncService` (spec §6)

**Files:**
- Create: `lib/data/sync/roadmap_sync.dart`
- Create: `test/data/sync/roadmap_sync_test.dart`

**Interfaces:**
- Consumes: `mergeGoal` (Task 1); the converters (Task 7); `DirectusClient` (`get`, `post`, `patch`), `DirectusError`, `DirectusUnreachable`, `AuthRepository`, `AuthFailure`, `SignedIn`, `SyncOutcome`.
- Produces: `Stream<int> watchPendingRoadmap(AppDatabase db)` and `RoadmapSyncService({required AppDatabase db, required AuthRepository auth, required DirectusClient api, required DateTime Function() now, Duration retryEvery})` with `start()`, `Future<SyncOutcome> syncNow()` and `dispose()`.

- [ ] **Step 1: Write the failing tests**

`test/data/sync/roadmap_sync_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  final now = DateTime(2026, 10, 15, 12);
  final older = DateTime(2026, 10, 14, 9);
  final newer = DateTime(2026, 10, 15, 9);

  RoadmapSyncService build() {
    final s = RoadmapSyncService(
      db: db,
      auth: FakeAuthRepository.signedIn(),
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => now,
    );
    addTearDown(s.dispose);
    return s;
  }

  void serve({List<Map<String, Object?>> goals = const [], List<Map<String, Object?>> achievements = const []}) {
    server.routes['GET /items/player_goals'] = (_) => FakeDirectus.ok(goals);
    server.routes['POST /items/player_goals'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['PATCH /items/player_goals/u1'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
    server.routes['GET /items/achievements'] = (_) => FakeDirectus.ok(achievements);
    server.routes['POST /items/achievements'] = (req) => FakeDirectus.ok(jsonDecode(req.body));
  }

  GoalRecord skill(SkillCategory c, DateTime at) => GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g-${c.name}', kind: GoalKind.thuanThucKyNang, category: c, createdAt: at));

  Future<void> local(GoalRecord g, {DateTime? syncedAt}) => db
      .into(db.playerGoalRows)
      .insertOnConflictUpdate(toGoalRow(g, userId: 'u1', syncedAt: syncedAt));

  Map<String, Object?> remote(GoalRecord g) => toRemoteGoal(toGoalRow(g, userId: 'u1'));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus();
  });
  tearDown(() => db.close());

  test('máy chủ chưa có: POST mục tiêu rồi đánh dấu đã đồng bộ', () async {
    serve();
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.done);
    final body = FakeDirectus.body(server.sent('POST', '/items/player_goals').single);
    expect(body['id'], 'u1');
    expect(body['kind'], 'thuanThucKyNang');
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('máy chủ mới hơn: ghi đè máy này, không gửi gì', () async {
    serve(goals: [remote(skill(SkillCategory.bank, newer))]);
    await local(skill(SkillCategory.kick, older), syncedAt: older);
    await build().syncNow();
    final row = await db.select(db.playerGoalRows).getSingle();
    expect(row.category, 'bank');
    expect(row.syncedAt, now);
    expect(server.sent('POST', '/items/player_goals'), isEmpty);
    expect(server.sent('PATCH', '/items/player_goals/u1'), isEmpty);
  });

  test('máy này bỏ mục tiêu sau: PATCH dòng rỗng lên máy chủ', () async {
    serve(goals: [remote(skill(SkillCategory.bank, older))]);
    await local(GoalRecord(updatedAt: newer));
    await build().syncNow();
    final body = FakeDirectus.body(server.sent('PATCH', '/items/player_goals/u1').single);
    expect(body.containsKey('id'), isFalse);
    expect(body['kind'], isNull);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('thành tích chưa đồng bộ được gửi lên; trùng trên máy chủ vẫn coi là đã đồng bộ', () async {
    serve();
    var first = true;
    server.routes['POST /items/achievements'] = (req) {
      if (first) {
        first = false;
        return FakeDirectus.ok(jsonDecode(req.body));
      }
      return FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');
    };
    for (final ref in ['7', '14']) {
      await db.into(db.achievementRows).insert(toAchievementRow(
          Achievement(kind: AchievementKind.chuoiNgay, refId: ref, achievedAt: newer),
          userId: 'u1'));
    }
    await build().syncNow();
    expect(server.sent('POST', '/items/achievements'), hasLength(2));
    expect((await db.select(db.achievementRows).get()).every((r) => r.syncedAt == now), isTrue);
  });

  test('thành tích bị máy chủ từ chối (4xx khác) nằm chờ, không chặn mục tiêu', () async {
    serve();
    server.routes['POST /items/achievements'] = (_) => FakeDirectus.error(403, 'FORBIDDEN');
    await db.into(db.achievementRows).insert(toAchievementRow(
        Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: newer), userId: 'u1'));
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.done);
    expect((await db.select(db.achievementRows).getSingle()).syncedAt, isNull);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, now);
  });

  test('kéo thành tích từ máy chủ về', () async {
    final a = Achievement(kind: AchievementKind.duDieuKienLenCap, refId: 'd1', achievedAt: older);
    serve(achievements: [toRemoteAchievement(toAchievementRow(a, userId: 'u1'))]);
    await build().syncNow();
    final row = await db.select(db.achievementRows).getSingle();
    expect(toAchievement(row), a);
    expect(row.syncedAt, now);
  });

  test('mất mạng: không ném, trả offline', () async {
    serve();
    server.offline = true;
    await local(skill(SkillCategory.kick, newer));
    expect(await build().syncNow(), SyncOutcome.offline);
    expect((await db.select(db.playerGoalRows).getSingle()).syncedAt, isNull);
  });

  test('đếm dòng chờ của mọi người trên máy', () async {
    await local(skill(SkillCategory.kick, newer));
    expect(await watchPendingRoadmap(db).first, 1);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/data/sync/roadmap_sync_test.dart`
Expected: FAIL at compile time.

- [ ] **Step 3: Write `lib/data/sync/roadmap_sync.dart`**

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/roadmap_converters.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/sync/sync_service.dart' show SyncOutcome;
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';

/// Số dòng mục tiêu và thành tích chưa lên server, của mọi người trên máy.
Stream<int> watchPendingRoadmap(AppDatabase db) => db
    .customSelect(
      'SELECT (SELECT COUNT(*) FROM player_goal_rows WHERE synced_at IS NULL) '
      '+ (SELECT COUNT(*) FROM achievement_rows WHERE synced_at IS NULL) AS n',
      readsFrom: {db.playerGoalRows, db.achievementRows},
    )
    .watchSingle()
    .map((row) => row.read<int>('n'));

class _UserChanged implements Exception {
  const _UserChanged();
}

class _Stopped implements Exception {
  const _Stopped();
}

/// Đồng bộ mục tiêu và thành tích với Directus (spec 2026-10-15 mục 6).
///
/// Tách khỏi hai service có sẵn vì khác luật: mục tiêu gộp theo [mergeGoal]
/// (mới nhất thắng), thành tích chỉ thêm. Cùng cách sống: chạy khi đăng nhập,
/// khi có dòng mới chờ, và định kỳ khi còn dòng chờ.
class RoadmapSyncService {
  RoadmapSyncService({
    required this._db,
    required this._auth,
    required this._api,
    required this._now,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final Duration _retryEvery;

  /// Mã Directus khi `POST` một id đã có: đã lên từ lần trước, hoặc máy khác
  /// của cùng người đã ghi cùng thành tích (R8).
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  bool _started = false;
  bool _disposed = false;
  bool _again = false;
  Future<SyncOutcome>? _running;
  int _pending = 0;

  /// Thành tích server từ chối (4xx): vẫn chờ, không tự khởi động lượt.
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
    _pendingSub = watchPendingRoadmap(_db).listen((n) {
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
    try {
      await _pushAchievements(userId);
      await _syncGoal(userId);
      await _pullAchievements(userId);
      return SyncOutcome.done;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    } on _Stopped {
      return SyncOutcome.stopped;
    } on AuthFailure catch (f) {
      return switch (f) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      return SyncOutcome.offline;
    } on Object {
      // syncNow() chạy từ timer: không bao giờ ném.
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

  Future<void> _pushAchievements(String userId) async {
    final rows = await (_db.select(_db.achievementRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull()))
        .get();
    for (final r in rows) {
      if (_rejected.contains(r.id)) continue;
      _checkAlive();
      try {
        await _create('/items/achievements', toRemoteAchievement(r), userId);
      } on DirectusError catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401) {
          _rejected.add(r.id);
          continue;
        }
        rethrow;
      }
      await (_db.update(_db.achievementRows)..where((t) => t.id.equals(r.id)))
          .write(AchievementRowsCompanion(syncedAt: Value(_now())));
    }
  }

  /// Gộp dòng mục tiêu trên máy với trên server theo [mergeGoal], rồi ghi bản
  /// thắng về phía còn thiếu.
  Future<void> _syncGoal(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/player_goals',
        token: token, query: {'limit': '1', 'fields': remoteGoalFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final remote = items.isEmpty ? null : goalFromRemote(items.first! as Map<String, Object?>);

    final localRow = await (_db.select(_db.playerGoalRows)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    final local = localRow == null ? null : toGoalRecord(localRow);
    final picked = mergeGoal(local, remote);
    if (picked == null) return;

    if (identical(picked, remote)) {
      // Gộp lại trong transaction: người chơi vừa đổi mục tiêu trong lúc chờ
      // server thì bản mới đó được xét lại, không bị ghi đè mù.
      await _db.transaction(() async {
        final fresh = await (_db.select(_db.playerGoalRows)..where((t) => t.userId.equals(userId)))
            .getSingleOrNull();
        final again = mergeGoal(fresh == null ? null : toGoalRecord(fresh), remote);
        if (identical(again, remote)) {
          await _db
              .into(_db.playerGoalRows)
              .insertOnConflictUpdate(toGoalRow(remote!, userId: userId, syncedAt: _now()));
        }
      });
      return;
    }

    final row = localRow!;
    if (row.syncedAt != null) return;
    final body = toRemoteGoal(row);
    if (remote == null) {
      await _create('/items/player_goals', body, userId);
    } else {
      body.remove('id');
      await _api.patch('/items/player_goals/$userId', token: await _tokenFor(userId), body: body);
      _checkAlive();
    }
    await (_db.update(_db.playerGoalRows)
          ..where((t) => t.userId.equals(userId) & t.updatedAt.equals(row.updatedAt)))
        .write(PlayerGoalRowsCompanion(syncedAt: Value(_now())));
  }

  /// Thành tích trên server không đổi nữa: thêm cái còn thiếu, bỏ qua cái đã có.
  Future<void> _pullAchievements(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/achievements',
        token: token, query: {'limit': '-1', 'fields': remoteAchievementFields}) as List<Object?>;
    _checkAlive();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    final at = _now();
    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(
          _db.achievementRows,
          achievementFromRemote(item! as Map<String, Object?>, userId: userId, syncedAt: at),
          mode: InsertMode.insertOrIgnore,
        );
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

- [ ] **Step 4: Run the tests again**

Run: `"$FLUTTER" test test/data/sync`
Expected: PASS. If `FakeAuthRepository.signedIn()` uses a user id other than `u1`, change the route `PATCH /items/player_goals/u1` and the `userId: 'u1'` arguments in this test to match it. Do not change the fake.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/roadmap_sync.dart test/data/sync/roadmap_sync_test.dart
git commit -m "Sync the goal newest-wins and achievements add-only with Directus

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Directus collections and permissions — STOP for the owner before production

**Files:**
- Modify: `deploy/directus/bootstrap.mjs`. Add a new section after the `bu_drill_results` `ensureCollection` call and before `// ─── 2. Role Player và policy của nó`. Add 5 entries at the end of `desiredPermissions`.
- Modify: `deploy/directus/verify.mjs` (new block after the `// ─── Đánh giá + hạng` block, before `const adminRole = …`)
- Modify: `docs/superpowers/logs/2026-10-15-roadmap.md`

**Interfaces:**
- Consumes: `remoteGoalFields` and `remoteAchievementFields` (Task 7). The field names must match one to one.
- Produces:
  - Collections `player_goals` and `achievements`, each with `user_created` → `directus_users` (CASCADE).
  - Player permissions:
    - `player_goals`: create (only its own id), read own, update own.
    - `achievements`: create, read own; no update, no delete.

- [ ] **Step 1: Add the collections to `bootstrap.mjs`**

```js
// ─── 1c. Lộ trình (spec 2026-10-15 mục 6) ─────────────────────────────────
// player_goals: mỗi tài khoản một dòng, id = id người dùng; bỏ mục tiêu thì
// kind rỗng (R1, R2 của kế hoạch). achievements: chỉ thêm; id tính từ
// (người, loại, ref_id) nên hai máy ghi cùng thành tích ra cùng id (R8).
await ensureCollection('player_goals', 'Mục tiêu Lộ trình — mỗi tài khoản một dòng, id = id người dùng', [
  pk,
  nullable('goal_id', 'uuid'),
  nullable('kind', 'string'),
  nullable('category', 'string'),
  nullable('event_date', 'timestamp'),
  nullable('created_at', 'timestamp'),
  required('updated_at', 'timestamp'),
]);
await ensureCollection('achievements', 'Thành tích Lộ trình — chỉ thêm', [
  pk,
  required('kind', 'string'),
  required('ref_id', 'string'),
  required('achieved_at', 'timestamp'),
]);
```

At the end of `desiredPermissions`, before the closing `];`:

```js
  // Mục tiêu: tạo đúng một dòng của chính mình, đọc và sửa dòng của mình.
  {
    collection: 'player_goals',
    action: 'create',
    fields: ['id', 'goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at'],
    permissions: {},
    validation: { id: { _eq: '$CURRENT_USER' } },
  },
  { collection: 'player_goals', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'player_goals',
    action: 'update',
    fields: ['goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at'],
    permissions: { user_created: self },
    validation: {},
  },
  // Thành tích: chỉ thêm, không sửa, không xoá.
  {
    collection: 'achievements',
    action: 'create',
    fields: ['id', 'kind', 'ref_id', 'achieved_at'],
    permissions: {},
    validation: {},
  },
  { collection: 'achievements', action: 'read', fields: ['*'], permissions: { user_created: self } },
```

Then `grep -n "11" deploy/directus/bootstrap.mjs deploy/directus/verify.mjs`. If any line checks the Player permission count (it was 11 after the rank work), change it to 16.

- [ ] **Step 2: Add the checks to `verify.mjs`**

```js
  // ─── Lộ trình: player_goals, achievements ───────────────────────────────
  if (aId && bId) {
    const goal = { id: aId, goal_id: randomUUID(), kind: 'thuanThucKyNang', category: 'safety',
      event_date: null, created_at: '2026-10-15T03:00:00.000Z', updated_at: '2026-10-15T03:00:00.000Z' };
    const gMade = await call('POST', '/items/player_goals', goal, a.access_token);
    gMade.status === 200 ? ok('A tạo được mục tiêu của mình') : fail(`A tạo mục tiêu → ${gMade.status} ${gMade.code}`);
    const gForged = await call('POST', '/items/player_goals', { ...goal, id: bId }, a.access_token);
    gForged.status >= 400 ? ok(`A không tạo được mục tiêu mang id của B → ${gForged.status}`) : fail('A tạo được mục tiêu mang id của B');
    const gDropped = await call('PATCH', `/items/player_goals/${aId}`, { goal_id: null, kind: null, category: null,
      created_at: null, updated_at: '2026-10-16T03:00:00.000Z' }, a.access_token);
    gDropped.status === 200 ? ok('A bỏ được mục tiêu (dòng rỗng)') : fail(`A bỏ mục tiêu → ${gDropped.status} ${gDropped.code}`);
    const bGoals = await call('GET', '/items/player_goals', undefined, b.access_token);
    (bGoals.data ?? []).length === 0 ? ok('B không thấy mục tiêu của A') : fail(`B thấy ${bGoals.data.length} mục tiêu`);
    const bGoalPatch = await call('PATCH', `/items/player_goals/${aId}`, { kind: 'lenHang' }, b.access_token);
    bGoalPatch.status === 403 ? ok('B không sửa được mục tiêu của A') : fail(`B sửa mục tiêu của A → ${bGoalPatch.status}`);

    const ach = { id: randomUUID(), kind: 'chuoiNgay', ref_id: '7', achieved_at: '2026-10-15T03:00:00.000Z' };
    const aMade = await call('POST', '/items/achievements', ach, a.access_token);
    aMade.status === 200 ? ok('A tạo được thành tích') : fail(`A tạo thành tích → ${aMade.status} ${aMade.code}`);
    const aAgain = await call('POST', '/items/achievements', ach, a.access_token);
    aAgain.code === 'RECORD_NOT_UNIQUE'
      ? ok('gửi lại thành tích cùng id → RECORD_NOT_UNIQUE (app coi là đã đồng bộ)')
      : fail(`gửi lại thành tích cùng id → ${aAgain.status} ${aAgain.code}`);
    const aPatch = await call('PATCH', `/items/achievements/${ach.id}`, { ref_id: '100' }, a.access_token);
    aPatch.status === 403 ? ok('A không sửa được thành tích') : fail(`A sửa thành tích → ${aPatch.status}`);
    const bAch = await call('GET', '/items/achievements', undefined, b.access_token);
    (bAch.data ?? []).length === 0 ? ok('B không thấy thành tích của A') : fail(`B thấy ${bAch.data.length} thành tích`);
  } else {
    fail('thiếu id của A hoặc B, bỏ qua phần Lộ trình');
  }
```

- [ ] **Step 3: Syntax check and commit**

```bash
node --check deploy/directus/bootstrap.mjs
node --check deploy/directus/verify.mjs
git add deploy/directus/bootstrap.mjs deploy/directus/verify.mjs
git commit -m "Provision the goal and achievement collections in Directus and verify their permissions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: STOP — ask the owner before touching the live server**

Creating collections is an outward action on the production Directus (`test-va`, the only server). Show the owner, verbatim:
- the two collections and their fields (Step 1);
- the five new permissions;
- that `bootstrap.mjs` replaces the Player policy's permissions by creating the new set first and deleting the old set after (existing behaviour);
- that `verify.mjs` registers two throwaway users and deletes them at the end.

Ask: *"Chạy bootstrap.mjs rồi verify.mjs trên Directus thật bây giờ được không?"* Do nothing until the owner says yes in their own words. An approval relayed by a coordinator or another agent is not the owner's consent (ledger lesson from the rank work). Tasks 11–14 can proceed while waiting; Task 15 cannot.

- [ ] **Step 5: After the owner says yes — run against production**

```bash
eval "$(node -e "const e=require('C:/Users/anhnpv/Desktop/PoolCoachAI/.claude/settings.local.json').env;for(const k of ['DIRECTUS_URL','DIRECTUS_ADMIN_EMAIL','DIRECTUS_ADMIN_PASSWORD','MAILPIT_URL','MAILPIT_USER','MAILPIT_PASSWORD'])if(e[k])console.log('export '+k+'='+JSON.stringify(e[k]))")"
node deploy/directus/bootstrap.mjs
node deploy/directus/verify.mjs
```

Expected:
- `bootstrap.mjs` prints `Tạo collection player_goals` and `Tạo collection achievements` (or nothing new on a re-run), then finishes.
- `verify.mjs` ends with `Tất cả kiểm tra đều qua`.
- If the goal-id validation check fails (`A tạo được mục tiêu mang id của B`), or the duplicate check does not return `RECORD_NOT_UNIQUE`, **stop and report**. Do not loosen a permission.

Paste both outputs, minus secrets, into the log under `## Directus (<ngày>)`, then commit:

```bash
git add docs/superpowers/logs/2026-10-15-roadmap.md
git commit -m "Log the Directus bootstrap and verification of the roadmap collections

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Providers, the achievement recorder and the sync start (spec §4, §7)

**Files:**
- Create: `lib/core/providers/roadmap_providers.dart`
- Modify: `lib/core/bootstrap.dart` (`startSync`)
- Modify: `lib/app.dart` (`build`)
- Modify: `test/support/test_data.dart` (`testContainer`, `dbContainer`)
- Create: `test/core/providers/roadmap_providers_test.dart`

**Interfaces:**
- Consumes:
  - `buTestsProvider`, `testSnapshotProvider`, `playerRankProvider`, `assessmentRepositoryProvider`'s pattern (`assessment_providers.dart`);
  - `drillsProvider`, `drillLogsProvider`, `nowProvider`, `appDatabaseProvider`, `currentUserIdProvider`, `authRepositoryProvider`, `directusClientProvider`;
  - Tasks 2, 4, 6, 8, 9.
- Produces:
  - `roadmapRepositoryProvider: Provider<RoadmapRepository?>`
  - `goalProvider: StreamProvider<GoalRecord?>`
  - `achievementsProvider: StreamProvider<List<Achievement>>`
  - `latestBuResultProvider: Provider<AsyncValue<BuResult?>>`
  - `roadmapProvider: Provider<AsyncValue<Roadmap?>>`, where data `null` means there is no goal
  - `achievementRecorderProvider: Provider<void>`
  - `roadmapSyncProvider: Provider<RoadmapSyncService>`
  - In tests: `testContainer(goal:, achievements:, buResult:)` and `dbContainer(logs:)`

- [ ] **Step 1: Extend the test helpers**

In `test/support/test_data.dart`:
- Add the imports:
  - `package:poolcoachai/core/providers/roadmap_providers.dart`
  - `package:poolcoachai/domain/roadmap/achievements.dart`
  - `package:poolcoachai/domain/roadmap/bu_gap.dart`
  - `package:poolcoachai/domain/roadmap/goal.dart`
- Add three named parameters to `testContainer`: `GoalRecord? goal`, `List<Achievement>? achievements` and `BuResult? buResult`.
- Add these entries at the end of its `overrides:` list:

```dart
      goalProvider.overrideWith((ref) => Stream.value(goal)),
      achievementsProvider
          .overrideWith((ref) => Stream.value(achievements ?? const <Achievement>[])),
      if (buResult != null)
        latestBuResultProvider.overrideWithValue(AsyncData<BuResult?>(buResult)),
```

Add `List<DrillLog>? logs` to `dbContainer`, and change its `drillLogsProvider` override to `Stream.value(logs ?? const <DrillLog>[])`.

- [ ] **Step 2: Write the failing tests**

`test/core/providers/roadmap_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/fake_auth.dart';
import '../../support/test_data.dart';

void main() {
  final at = DateTime(2026, 9, 20, 9);

  List<DrillLog> passes(String drillId) => [
        for (var i = 0; i < 3; i++)
          DrillLog(id: '$drillId-$i', drillId: drillId, date: DateTime(2026, 9, 19 + i, 9), score: 9, attempts: 10),
      ];

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  test('không có mục tiêu: lộ trình là null, không phải đang tải', () async {
    final c = testContainer();
    addTearDown(c.dispose);
    c.listen(roadmapProvider, (_, _) {});
    await settle();
    expect(c.read(roadmapProvider), const AsyncData<Roadmap?>(null));
  });

  test('có mục tiêu thuần thục: lộ trình đi theo dữ liệu tập', () async {
    final c = testContainer(
      goal: GoalRecord(
        updatedAt: at,
        goal: PlayerGoal(goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: at),
      ),
      logs: passes('d1'),
    );
    addTearDown(c.dispose);
    c.listen(roadmapProvider, (_, _) {});
    await settle();
    final r = c.read(roadmapProvider).value!;
    expect(r.steps.first.drillId, 'd1');
    expect(r.steps.first.status, StepStatus.xong);
  });

  test('Lên hạng đọc hạng hiện tại', () async {
    final c = testContainer(
      goal: GoalRecord(updatedAt: at, goal: PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at)),
      rank: PlayerRank(rank: Rank.h, source: RankSource.estimated, onboardingState: OnboardingState.done, updatedAt: at),
    );
    addTearDown(c.dispose);
    c.listen(roadmapProvider, (_, _) {});
    await settle();
    expect(c.read(roadmapProvider).value!.target, Rank.g);
  });

  test('bộ ghi thành tích ghi xuống Drift sự kiện thật, đúng ngày buổi đạt thứ ba', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final c = dbContainer(db, logs: passes('d1'));
    addTearDown(c.dispose);
    c.listen(achievementRecorderProvider, (_, _) {});
    await settle();
    final rows = await db.select(db.achievementRows).get();
    final ready = rows.where((r) => r.kind == AchievementKind.duDieuKienLenCap.name).single;
    expect(ready.refId, 'd1');
    expect(ready.achievedAt, DateTime(2026, 9, 21, 9));
  });

  test('đang đổi người: bộ ghi thành tích không ghi gì', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final c = dbContainer(db, logs: passes('d1'), auth: FakeAuthRepository.signedOut());
    addTearDown(c.dispose);
    c.listen(achievementRecorderProvider, (_, _) {});
    await settle();
    expect(await db.select(db.achievementRows).get(), isEmpty);
  });
}
```

`testDrills` must contain `d1` (aiming, `passThreshold` 0.8); it does today. If `FakeAuthRepository.signedOut()` does not exist, use `FakeAuthRepository(const SignedOut())`, which is the constructor `pumpAuthApp` uses.

- [ ] **Step 3: Run them to see them fail**

Run: `"$FLUTTER" test test/core/providers/roadmap_providers_test.dart`
Expected: FAIL at compile time.

- [ ] **Step 4: Write `lib/core/providers/roadmap_providers.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/data/repositories/roadmap_repository.dart';
import 'package:poolcoachai/data/sync/roadmap_sync.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/bu_gap.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/roadmap/roadmap_builder.dart';
import 'package:uuid/uuid.dart';

/// Mục tiêu và thành tích của người đang đăng nhập; null khi chưa đăng nhập.
final roadmapRepositoryProvider = Provider<RoadmapRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return RoadmapRepository(
    ref.watch(appDatabaseProvider),
    userId: userId,
    now: ref.watch(nowProvider),
    newId: const Uuid().v4,
  );
});

final goalProvider = StreamProvider<GoalRecord?>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchGoal();
});

final achievementsProvider = StreamProvider<List<Achievement>>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchAchievements();
});

/// Đã tải xong và không phải giá trị cũ của người trước (đang tải lại).
bool _ready(AsyncValue<Object?> v) => v.hasValue && !v.isLoading;

/// Kết quả của lần BU hoàn chỉnh gần nhất; data null khi chưa có lần nào.
final latestBuResultProvider = Provider<AsyncValue<BuResult?>>((ref) {
  final tests = ref.watch(buTestsProvider);
  if (!_ready(tests)) return const AsyncLoading();
  final id = latestCompletedTestId(tests.value!);
  if (id == null) return const AsyncData(null);
  final snap = ref.watch(testSnapshotProvider(id));
  if (!_ready(snap)) return const AsyncLoading();
  final s = snap.value;
  return AsyncData(s == null || !s.test.isCompleted ? null : buResultFrom(s));
});

/// Lộ trình tính lại mỗi khi mục tiêu, hạng, bài BU hay buổi tập đổi (spec mục
/// 4). Data null nghĩa là chưa có mục tiêu — khác hẳn đang tải.
final roadmapProvider = Provider<AsyncValue<Roadmap?>>((ref) {
  final goal = ref.watch(goalProvider);
  final rank = ref.watch(playerRankProvider);
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final tests = ref.watch(buTestsProvider);
  final result = ref.watch(latestBuResultProvider);
  if (![goal, rank, drills, logs, tests, result].every(_ready)) return const AsyncLoading();
  final g = goal.value?.goal;
  if (g == null) return const AsyncData(null);
  return AsyncData(buildRoadmap(
    goal: g,
    rank: rank.value,
    drills: drills.value!,
    logs: logs.value!,
    tests: tests.value!,
    latestResult: result.value,
    today: ref.watch(nowProvider)(),
  ));
});

/// Ghi thành tích mới mỗi khi dữ liệu đổi (spec mục 7). App phải nghe provider
/// này thì nó mới chạy — Riverpod 3 tạm dừng provider không ai nghe.
final achievementRecorderProvider = Provider<void>((ref) {
  final repo = ref.watch(roadmapRepositoryProvider);
  final goal = ref.watch(goalProvider);
  final drills = ref.watch(drillsProvider);
  final logs = ref.watch(drillLogsProvider);
  final have = ref.watch(achievementsProvider);
  // Đang đổi người thì các stream còn giữ giá trị của người trước: không ghi.
  if (repo == null || ![goal, drills, logs, have].every(_ready)) return;
  final fresh = newAchievements(
    goal: goal.value?.goal,
    drills: drills.value!,
    logs: logs.value!,
    existing: {for (final a in have.value!) a.key},
    today: ref.watch(nowProvider)(),
  );
  if (fresh.isNotEmpty) unawaited(repo.recordAchievements(fresh));
});

/// Service đã chạy sẵn, như [assessmentSyncProvider].
final roadmapSyncProvider = Provider<RoadmapSyncService>((ref) {
  final service = RoadmapSyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  )..start();
  ref.onDispose(service.dispose);
  return service;
});
```

If `directusClientProvider` lives in another file, import it from wherever `assessment_providers.dart` imports it.

- [ ] **Step 5: Start the sync and watch the recorder**

In `lib/core/bootstrap.dart` `startSync`, add `container.read(roadmapSyncProvider);` after the assessment line. Import `roadmap_providers.dart` and extend the doc comment to read "buổi tập, phần đánh giá và Lộ trình".

In `lib/app.dart` `build`, replace the line `if (_ownsRouter) ref.watch(onboardingGateProvider);` with:

```dart
    if (_ownsRouter) {
      ref.watch(onboardingGateProvider);
      // Bộ ghi thành tích cũng chỉ chạy khi có người nghe (spec Lộ trình mục 7).
      ref.watch(achievementRecorderProvider);
    }
```

and import `roadmap_providers.dart`.

- [ ] **Step 6: Run the tests, then the whole suite**

Run: `"$FLUTTER" test test/core test/data test/domain`
Then: `"$FLUTTER" test > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t11.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t11.log`
Expected: `All tests passed!`

`app_test.dart` and the bootstrap test build the real `PoolCoachApp`. They now also open the roadmap sync. If one of them fails because `roadmapSyncProvider` reaches the network, override it in that test the same way `assessmentSyncProvider` is overridden there, and record the ruling.

- [ ] **Step 7: Commit**

```bash
git add lib/core/providers/roadmap_providers.dart lib/core/bootstrap.dart lib/app.dart test/support/test_data.dart test/core/providers/roadmap_providers_test.dart
git commit -m "Recompute the roadmap from live data, record achievements and start the roadmap sync

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Every Lộ trình string, with the no-fabrication check (spec §2.2, §8)

**Files:**
- Modify: `lib/core/strings/vi.dart` (new section at the end of the class)
- Create: `test/core/strings/vi_roadmap_test.dart`
- Modify: `test/domain/no_fabrication_test.dart` (new group)

**Interfaces:**
- Consumes: Tasks 1, 2, 4 and 6. Also `PracticeConstants`, `Vi.skill` and `Vi.shortDate`.
- Produces these `Vi` members:
  - `roadmapTitle`, `roadmapCardBody`
  - `goalKind(GoalKind)`, `goalKindBody(GoalKind)`, `goalPickTitle`, `goalPickDate`, `goalBlocked(LenHangBlock)`, `goalNeedRank`, `goalChange`, `goalClear`, `goalCancelChange`
  - `roadmapHeadline(Roadmap)`, `String? roadmapNeed(Roadmap)`, `finishLine(Estimate)`, `roadmapAchieved`
  - `stepStatus(StepStatus)`, `stepTitle(RoadmapStep, {String? drillName})`, `stepProgress(int?, int)`, `stepStreak(int)`, `stepReason(StepReason)`, `estimateLine(Estimate)`, `stepTrain`, `stepOpenTest`
  - `roadmapMissedTitle`, `achievementsTitle`, `achievementsEmpty`, `achievement(AchievementKind, String)`, `homeCurrentStep(String)`

- [ ] **Step 1: Write the failing tests**

`test/core/strings/vi_roadmap_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

void main() {
  final at = DateTime(2026, 10, 15);
  RoadmapStep step(StepKind kind, StepReason reason, {SkillCategory? cat, List<String> bu = const []}) =>
      RoadmapStep(kind: kind, status: StepStatus.dangLam, reason: reason, category: cat, buDrillIds: bu);

  test('lý do mang đúng con số của hàm tính', () {
    expect(Vi.stepReason(const LostBuPoints(18, ['F3', 'F5'])), 'Mất 18 điểm BU ở F3, F5.');
    expect(Vi.stepReason(const Unmeasured(1)), 'Tập đủ 3 buổi để đo (đã có 1).');
    expect(Vi.stepReason(const BelowStrong(62)), 'Còn thiếu 13 điểm để đạt 75.');
    expect(Vi.stepReason(const NeedStreak()), 'Đã đạt 75, cần 3 buổi đạt liên tiếp.');
    expect(Vi.stepReason(const DrillLevel(2)), 'Bài cấp 2 của nhóm.');
    expect(Vi.stepReason(const RetestFrom(null)), 'Làm được ngay.');
    expect(Vi.stepReason(RetestFrom(DateTime(2026, 10, 28))), 'Mở từ ngày 28/10/2026.');
  });

  test('tên bước', () {
    expect(Vi.stepTitle(step(StepKind.buLe, const LostBuPoints(3, ['S8', 'S9']), bu: ['S8', 'S9'])),
        'Tập lại S8/S9 trên bàn BU');
    expect(Vi.stepTitle(step(StepKind.nhom, const Unmeasured(0), cat: SkillCategory.kick), drillName: 'Bài A'),
        'A băng · Bài A');
    expect(Vi.stepTitle(step(StepKind.lamBaiBu, const RetestFrom(null))), 'Làm bài BU');
  });

  test('ngày dự kiến: có ngày hoặc nói thẳng chưa đủ dữ liệu', () {
    expect(Vi.estimateLine(Estimate.on(DateTime(2026, 11, 2))), 'Dự kiến: 02/11/2026');
    expect(Vi.estimateLine(const Estimate.notEnoughData()), 'Dự kiến: chưa đủ dữ liệu');
    expect(Vi.finishLine(const Estimate.notEnoughData()), 'Dự kiến xong: chưa đủ dữ liệu');
  });

  test('đầu trang Lên hạng nói điểm còn thiếu và sàn của hạng đích', () {
    final r = Roadmap(
      goal: PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at),
      steps: const [],
      from: Rank.d,
      target: Rank.c,
      pointsNeeded: 3,
    );
    expect(Vi.roadmapHeadline(r), 'Lên hạng: D → C');
    expect(Vi.roadmapNeed(r), 'Cần thêm 3 điểm BU (hạng C từ 140 điểm).');
  });

  test('thành tích', () {
    expect(Vi.achievement(AchievementKind.chuoiNgay, '7'), 'Chuỗi 7 ngày tập liên tiếp');
    expect(Vi.achievement(AchievementKind.duDieuKienLenCap, 'Bài A'), 'Đủ điều kiện lên cấp: Bài A');
  });

  test('không dùng từ đã bị chủ sản phẩm sửa', () {
    final texts = [
      for (final k in GoalKind.values) ...[Vi.goalKind(k), Vi.goalKindBody(k)],
      for (final b in LenHangBlock.values) Vi.goalBlocked(b),
      for (final s in StepStatus.values) Vi.stepStatus(s),
      Vi.roadmapCardBody, Vi.achievementsEmpty, Vi.roadmapMissedTitle,
    ];
    for (final t in texts) {
      for (final banned in ['kim cương', 'bi ma', 'lọt bi cái']) {
        expect(t.toLowerCase(), isNot(contains(banned)), reason: t);
      }
    }
  });
}
```

Append to `test/domain/no_fabrication_test.dart` inside `main()`, and add the imports it needs: `vi.dart`, `player_rank.dart`, `rank.dart`, `roadmap/bu_gap.dart`, `roadmap/goal.dart`, `roadmap/roadmap.dart`, `roadmap/roadmap_builder.dart`.

```dart
  group('Lộ trình bám dữ liệu, không viết cứng (spec 2026-10-15 mục 9)', () {
    final rank = PlayerRank(
        rank: Rank.h, source: RankSource.estimated,
        onboardingState: OnboardingState.done, updatedAt: _today);
    final goal = PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: _today);

    Roadmap roadmapFor(List<DrillLog> logs, {BuResult? result}) => buildRoadmap(
        goal: goal, rank: rank, drills: seedDrills, logs: logs,
        tests: const [], latestResult: result, today: _today);

    test('hai người yếu hai nhóm khác nhau nhận hai lộ trình khác nhau', () {
      final a = roadmapFor(_playerWeakAt(SkillCategory.position));
      final b = roadmapFor(_playerWeakAt(SkillCategory.safety));
      expect(a.steps.first.category, SkillCategory.position);
      expect(b.steps.first.category, SkillCategory.safety);
      expect(Vi.stepTitle(a.steps.first), isNot(Vi.stepTitle(b.steps.first)));
    });

    test('đổi điểm mất BU thì câu lý do đổi theo', () {
      BuResult r(Map<String, int> lost) =>
          BuResult(testId: 't', completedAt: _today, total: 50, lost: lost);
      final a = roadmapFor(const [], result: r(const {'F7': 20}));
      final b = roadmapFor(const [], result: r(const {'S5': 12}));
      expect(Vi.stepReason(a.steps.first.reason), contains('20'));
      expect(Vi.stepReason(b.steps.first.reason), contains('12'));
      expect(Vi.stepReason(a.steps.first.reason), isNot(Vi.stepReason(b.steps.first.reason)));
    });
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/core/strings/vi_roadmap_test.dart test/domain/no_fabrication_test.dart`
Expected: FAIL at compile time (`Vi.stepReason` is undefined).

- [ ] **Step 3: Add the strings to `vi.dart`**

Add the imports for `practice_constants.dart`, `roadmap/achievements.dart`, `roadmap/bu_gap.dart`, `roadmap/goal.dart` and `roadmap/roadmap.dart`. Then append the section at the end of the class:

```dart
  // ─── Lộ trình (spec 2026-10-15) ─────────────────────────────────────────────
  //
  // Mọi câu là khuôn; con số do buildRoadmap, newAchievements và các hàm của
  // lib/domain/roadmap tính ra (spec mục 2.2).

  static const roadmapTitle = 'Lộ trình';
  static const roadmapCardBody = 'Chọn mục tiêu, xem các bước tập dẫn tới đó.';

  static String goalKind(GoalKind kind) => switch (kind) {
        GoalKind.lenHang => 'Lên hạng',
        GoalKind.thuanThucKyNang => 'Thuần thục kỹ năng',
        GoalKind.chuanBiGiai => 'Chuẩn bị giải',
      };

  static String goalKindBody(GoalKind kind) => switch (kind) {
        GoalKind.lenHang => 'Nhắm hạng ngay trên hạng hiện tại, theo điểm BU còn thiếu.',
        GoalKind.thuanThucKyNang =>
          'Chọn một nhóm kỹ năng, tập tới khi đạt ${PracticeConstants.strongCutoff} '
              'và ${PracticeConstants.readyStreak} buổi đạt liên tiếp.',
        GoalKind.chuanBiGiai => 'Chọn ngày giải; bước nào không kịp sẽ được xếp riêng.',
      };

  static const goalPickTitle = 'Chọn mục tiêu';
  static const goalPickDate = 'Chọn ngày giải';

  static String goalBlocked(LenHangBlock block) => switch (block) {
        LenHangBlock.noRank => 'Cần có hạng trước khi đặt mục tiêu lên hạng.',
        LenHangBlock.topRank => 'Hạng A là hạng cao nhất bài BU xác nhận được; PRO chỉ tự khai.',
      };

  static const goalNeedRank = 'Xác định hạng';
  static const goalChange = 'Đổi mục tiêu';
  static const goalClear = 'Bỏ mục tiêu';
  static const goalCancelChange = 'Giữ mục tiêu cũ';

  static String roadmapHeadline(Roadmap r) => switch (r.goal.kind) {
        GoalKind.lenHang => r.from == null || r.target == null
            ? goalKind(GoalKind.lenHang)
            : 'Lên hạng: ${r.from!.label} → ${r.target!.label}',
        GoalKind.thuanThucKyNang => 'Thuần thục: ${skill(r.goal.category!)}',
        GoalKind.chuanBiGiai => 'Chuẩn bị giải ngày ${shortDate(r.goal.eventDate!)}',
      };

  /// Dòng phụ của Lên hạng; null với hai mục tiêu kia.
  static String? roadmapNeed(Roadmap r) {
    if (r.goal.kind != GoalKind.lenHang || r.target == null) return null;
    final need = r.pointsNeeded;
    if (need == null) return 'Chưa có bài BU hoàn chỉnh: xếp bước theo nhóm yếu nhất.';
    if (need <= 0) return 'Điểm BU gần nhất đã đủ, chỉ còn làm bài BU.';
    return 'Cần thêm $need điểm BU (hạng ${r.target!.label} từ ${buFloor(r.target!)} điểm).';
  }

  static String finishLine(Estimate e) =>
      e.date == null ? 'Dự kiến xong: chưa đủ dữ liệu' : 'Dự kiến xong: ${shortDate(e.date!)}';

  static const roadmapAchieved = 'Đã đạt mục tiêu.';

  static String stepStatus(StepStatus s) => switch (s) {
        StepStatus.dangLam => 'Đang làm',
        StepStatus.xong => 'Xong',
        StepStatus.chuaToi => 'Chưa tới',
        StepStatus.khongKip => 'Không kịp trước giải',
      };

  static String stepTitle(RoadmapStep s, {String? drillName}) => switch (s.kind) {
        StepKind.xacDinhHang => 'Xác định hạng',
        StepKind.nhom => drillName == null ? skill(s.category!) : '${skill(s.category!)} · $drillName',
        StepKind.buLe => 'Tập lại ${s.buDrillIds.join('/')} trên bàn BU',
        StepKind.baiTap => drillName ?? s.drillId!,
        StepKind.lamBaiBu => 'Làm bài BU',
      };

  static String stepProgress(int? mastery, int streak) =>
      '${mastery == null ? 'Độ thuần thục: chưa đo' : 'Độ thuần thục: $mastery / ${PracticeConstants.strongCutoff}'}'
      ' · ${stepStreak(streak)}';

  static String stepStreak(int streak) =>
      'Buổi đạt liên tiếp: $streak / ${PracticeConstants.readyStreak}';

  static String stepReason(StepReason r) => switch (r) {
        LostBuPoints(:final points, :final drillIds) => 'Mất $points điểm BU ở ${drillIds.join(', ')}.',
        Unmeasured(:final sessions) =>
          'Tập đủ ${PracticeConstants.minSessions} buổi để đo (đã có $sessions).',
        BelowStrong(:final mastery) =>
          'Còn thiếu ${PracticeConstants.strongCutoff - mastery} điểm để đạt ${PracticeConstants.strongCutoff}.',
        NeedStreak() => 'Đã đạt ${PracticeConstants.strongCutoff}, cần '
            '${PracticeConstants.readyStreak} buổi đạt liên tiếp.',
        DrillLevel(:final level) => 'Bài cấp $level của nhóm.',
        RetestFrom(:final from) => from == null ? 'Làm được ngay.' : 'Mở từ ngày ${shortDate(from)}.',
        NeedRank() => 'Làm bộ câu hỏi hoặc bài BU để có hạng.',
      };

  static String estimateLine(Estimate e) =>
      e.date == null ? 'Dự kiến: chưa đủ dữ liệu' : 'Dự kiến: ${shortDate(e.date!)}';

  static const stepTrain = 'Tập ngay';
  static const stepOpenTest = 'Làm bài kiểm tra';
  static const roadmapMissedTitle = 'Không kịp trước giải';
  static const achievementsTitle = 'Thành tích';
  static const achievementsEmpty = 'Chưa có thành tích. Thành tích chỉ đến từ buổi tập thật.';

  static String achievement(AchievementKind kind, String subject) => switch (kind) {
        AchievementKind.xongBuoc => 'Xong bước: $subject',
        AchievementKind.duDieuKienLenCap => 'Đủ điều kiện lên cấp: $subject',
        AchievementKind.chuoiNgay => 'Chuỗi $subject ngày tập liên tiếp',
      };

  static String homeCurrentStep(String step) => 'Bước hiện tại: $step';
```

- [ ] **Step 4: Run the tests again**

Run: `"$FLUTTER" test test/core/strings test/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings/vi.dart test/core/strings/vi_roadmap_test.dart test/domain/no_fabrication_test.dart
git commit -m "Write every Lộ trình sentence as a template filled from the roadmap functions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: The roadmap screen, the goal picker, the route and the Luyện tập card (spec §8)

**Files:**
- Create: `lib/features/roadmap/presentation/roadmap_screen.dart`
- Create: `lib/features/roadmap/presentation/goal_picker.dart`
- Create: `lib/features/roadmap/presentation/step_tile.dart`
- Modify: `lib/core/router/routes.dart` (`roadmap`, `all`)
- Modify: `lib/core/router/app_router.dart` (training branch)
- Modify: `lib/features/training/presentation/training_screen.dart` (first card)
- Modify: `test/core/router/routes_test.dart` (pinned list)
- Create: `test/features/roadmap/roadmap_screen_test.dart`
- Modify: `test/features/training/training_screen_test.dart` (only if a drill tile is pushed below the fold, as described in Step 6)

**Interfaces:**
- Consumes:
  - Task 11 providers.
  - Task 12 strings.
  - `playerRankProvider`, `drillsProvider`, `nowProvider`, `Routes.drillSession`, `Routes.rankTest`, `Routes.onboardingRank`.
  - `PcRootScaffold`, `PcCard`, `PcEmptyState`.
- Produces: `Routes.roadmap = '/training/roadmap'`, plus `RoadmapScreen`, `RoadmapView`, `GoalPicker` and `StepTile`.

- [ ] **Step 1: Write the failing widget tests**

`test/features/roadmap/roadmap_screen_test.dart`:

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
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/drill_log.dart';
import 'package:poolcoachai/domain/rank.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';

import '../../support/test_data.dart';

void main() {
  final at = DateTime(2026, 9, 20, 9);

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    final router = createAppRouter(auth: signedInGate());
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    router.go(Routes.roadmap);
    await tester.pumpAndSettle();
  }

  GoalRecord goal(PlayerGoal goal) => GoalRecord(updatedAt: at, goal: goal);

  testWidgets('chưa có mục tiêu, chưa có hạng: Lên hạng bị khóa kèm nút Xác định hạng', (tester) async {
    await open(tester, testContainer());
    expect(find.text(Vi.goalPickTitle), findsOneWidget);
    expect(find.text(Vi.goalBlocked(LenHangBlock.noRank)), findsOneWidget);
    expect(find.text(Vi.goalNeedRank), findsOneWidget);
  });

  testWidgets('chọn Thuần thục kỹ năng → Ngắm bi thì ghi mục tiêu và hiện lộ trình', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await open(tester, dbContainer(db));
    await tester.tap(find.text(Vi.goalKind(GoalKind.thuanThucKyNang)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.skill(SkillCategory.aiming)));
    await tester.pumpAndSettle();
    expect(find.text('Thuần thục: ${Vi.skill(SkillCategory.aiming)}'), findsOneWidget);
    expect(find.text(Vi.stepStatus(StepStatus.dangLam)), findsWidgets);
    expect((await db.select(db.playerGoalRows).getSingle()).kind, 'thuanThucKyNang');
  });

  testWidgets('Tập ngay mở buổi tập của bài trong bước', (tester) async {
    await open(tester, testContainer(goal: goal(PlayerGoal(
        goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: at))));
    await tester.tap(find.text(Vi.stepTrain).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(Vi.sessionTitle('')), findsOneWidget);
  });

  testWidgets('Lên hạng chưa có BU: nói rõ xếp theo nhóm yếu nhất, bước làm BU mở ngay', (tester) async {
    await open(tester, testContainer(
      goal: goal(PlayerGoal(goalId: 'g', kind: GoalKind.lenHang, createdAt: at)),
      rank: PlayerRank(rank: Rank.h, source: RankSource.estimated, onboardingState: OnboardingState.done, updatedAt: at),
    ));
    expect(find.text('Lên hạng: H → G'), findsOneWidget);
    expect(find.text('Chưa có bài BU hoàn chỉnh: xếp bước theo nhóm yếu nhất.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Vi.stepOpenTest), 200);
    expect(find.text('Làm được ngay.'), findsOneWidget);
  });

  testWidgets('Đổi mục tiêu mở lại bảng chọn, Giữ mục tiêu cũ quay về', (tester) async {
    await open(tester, testContainer(goal: goal(PlayerGoal(
        goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: at))));
    await tester.tap(find.text(Vi.goalChange));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalPickTitle), findsOneWidget);
    await tester.tap(find.text(Vi.goalCancelChange));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalPickTitle), findsNothing);
  });

  testWidgets('thành tích hiện theo ngày; chưa có thì nói chưa có', (tester) async {
    await open(tester, testContainer(
      goal: goal(PlayerGoal(goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.kick, createdAt: at)),
      achievements: [Achievement(kind: AchievementKind.chuoiNgay, refId: '7', achievedAt: at)],
    ));
    await tester.scrollUntilVisible(find.text(Vi.achievement(AchievementKind.chuoiNgay, '7')), 200);
    expect(find.text(Vi.achievement(AchievementKind.chuoiNgay, '7')), findsOneWidget);
  });

  testWidgets('Chuẩn bị giải: bước không kịp nằm trong mục riêng', (tester) async {
    final logs = <DrillLog>[
      for (final (i, d) in [DateTime(2026, 8, 1), DateTime(2026, 8, 2), DateTime(2026, 8, 3)].indexed)
        DrillLog(id: 'o$i', drillId: 'd1', date: d, score: 4, attempts: 10),
      for (final (i, d) in [DateTime(2026, 9, 17), DateTime(2026, 9, 18), DateTime(2026, 9, 19)].indexed)
        DrillLog(id: 'n$i', drillId: 'd1', date: d, score: 6, attempts: 10),
    ];
    await open(tester, testContainer(
      goal: goal(PlayerGoal(goalId: 'g', kind: GoalKind.chuanBiGiai, eventDate: DateTime(2026, 9, 23), createdAt: at)),
      logs: logs,
    ));
    await tester.scrollUntilVisible(find.text(Vi.roadmapMissedTitle), 200);
    expect(find.text(Vi.roadmapMissedTitle), findsOneWidget);
  });
}
```

(`testToday` is 22/9/2026, so the tournament on 23/9 is one day away. The aiming group (`d1`) has a slow positive pace, so its date falls after that day.)

In `test/core/router/routes_test.dart`, add `Routes.roadmap` to the pinned list right after `Routes.planner`.

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/features/roadmap test/core/router`
Expected: FAIL at compile time (`Routes.roadmap` is undefined).

- [ ] **Step 3: Add the route**

In `routes.dart`, after `planner`:

```dart
  /// Lộ trình — trong nhánh Luyện tập, không thêm tab (spec 2026-10-15 mục 8).
  static const roadmap = '$training/roadmap';
```

and add `roadmap,` after `planner,` in `all`.

In `app_router.dart`, add this inside the training `GoRoute`'s `routes:`, after the `planner` route:

```dart
                GoRoute(
                  path: 'roadmap',
                  builder: (context, state) => const RoadmapScreen(),
                ),
```

and import `package:poolcoachai/features/roadmap/presentation/roadmap_screen.dart`.

- [ ] **Step 4: Write `step_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';

/// Một bước của Lộ trình: tên, trạng thái, tiến độ, lý do, ngày dự kiến và
/// việc làm ngay (spec mục 8).
class StepTile extends StatelessWidget {
  const StepTile({required this.step, required this.drill, required this.today, super.key});

  final RoadmapStep step;
  final Drill? drill;
  final DateTime today;

  Widget? _action(BuildContext context) {
    switch (step.kind) {
      case StepKind.nhom || StepKind.baiTap
          when step.drillId != null && step.status != StepStatus.xong:
        return FilledButton(
          onPressed: () => context.go(Routes.drillSession(step.drillId!)),
          child: const Text(Vi.stepTrain),
        );
      case StepKind.lamBaiBu:
        // Không khóa người chơi: hết 14 ngày là làm được, kể cả khi các bước
        // trước chưa xong (R9).
        final from = (step.reason as RetestFrom).from;
        if (from != null && today.isBefore(from)) return null;
        return FilledButton(
          onPressed: () => context.push(Routes.rankTest),
          child: const Text(Vi.stepOpenTest),
        );
      case StepKind.xacDinhHang:
        return FilledButton(
          onPressed: () => context.push(Routes.onboardingRank),
          child: const Text(Vi.goalNeedRank),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = _action(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(Vi.stepTitle(step, drillName: drill?.name),
                      style: theme.textTheme.titleSmall),
                ),
                Text(Vi.stepStatus(step.status), style: theme.textTheme.labelMedium),
              ],
            ),
            if (step.kind == StepKind.nhom) Text(Vi.stepProgress(step.mastery, step.passStreak)),
            if (step.kind == StepKind.baiTap) Text(Vi.stepStreak(step.passStreak)),
            Text(Vi.stepReason(step.reason), style: theme.textTheme.bodySmall),
            if (step.estimate case final e?) Text(Vi.estimateLine(e), style: theme.textTheme.bodySmall),
            if (action != null) Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write `goal_picker.dart` and `roadmap_screen.dart`**

`goal_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/assessment_providers.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/roadmap/goal.dart';
import 'package:poolcoachai/domain/skill_category.dart';

/// Chọn 1 trong 3 loại mục tiêu (spec mục 3, 8).
class GoalPicker extends ConsumerStatefulWidget {
  const GoalPicker({required this.onPicked, this.onCancel, super.key});

  final VoidCallback onPicked;

  /// Có khi đang đổi mục tiêu: quay về mục tiêu cũ.
  final VoidCallback? onCancel;

  @override
  ConsumerState<GoalPicker> createState() => _GoalPickerState();
}

class _GoalPickerState extends ConsumerState<GoalPicker> {
  bool _pickingCategory = false;

  Future<void> _set(GoalKind kind, {SkillCategory? category, DateTime? eventDate}) async {
    await ref.read(roadmapRepositoryProvider)!.setGoal(kind: kind, category: category, eventDate: eventDate);
    if (mounted) widget.onPicked();
  }

  Future<void> _pickDate() async {
    final today = ref.read(nowProvider)();
    final first = DateTime(today.year, today.month, today.day + 1);
    final date = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: DateTime(first.year + 1, first.month, first.day),
      helpText: Vi.goalPickDate,
    );
    if (date == null || !goalDateValid(date, today)) return;
    await _set(GoalKind.chuanBiGiai, eventDate: date);
  }

  @override
  Widget build(BuildContext context) {
    final block = lenHangBlock(ref.watch(playerRankProvider).value);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(Vi.goalPickTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            enabled: block == null,
            title: Text(Vi.goalKind(GoalKind.lenHang)),
            subtitle: Text(block == null ? Vi.goalKindBody(GoalKind.lenHang) : Vi.goalBlocked(block)),
            onTap: block == null ? () => _set(GoalKind.lenHang) : null,
            trailing: block == LenHangBlock.noRank
                ? TextButton(
                    onPressed: () => context.push(Routes.onboardingRank),
                    child: const Text(Vi.goalNeedRank),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            title: Text(Vi.goalKind(GoalKind.thuanThucKyNang)),
            subtitle: Text(Vi.goalKindBody(GoalKind.thuanThucKyNang)),
            onTap: () => setState(() => _pickingCategory = !_pickingCategory),
          ),
        ),
        if (_pickingCategory)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in SkillCategory.values)
                  ActionChip(
                    label: Text(Vi.skill(c)),
                    onPressed: () => _set(GoalKind.thuanThucKyNang, category: c),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        PcCard(
          child: ListTile(
            title: Text(Vi.goalKind(GoalKind.chuanBiGiai)),
            subtitle: Text(Vi.goalKindBody(GoalKind.chuanBiGiai)),
            onTap: _pickDate,
          ),
        ),
        if (widget.onCancel != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: widget.onCancel, child: const Text(Vi.goalCancelChange)),
          ),
      ],
    );
  }
}
```

`roadmap_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/domain/drill.dart';
import 'package:poolcoachai/domain/roadmap/achievements.dart';
import 'package:poolcoachai/domain/roadmap/roadmap.dart';
import 'package:poolcoachai/domain/skill_category.dart';
import 'package:poolcoachai/features/roadmap/presentation/goal_picker.dart';
import 'package:poolcoachai/features/roadmap/presentation/step_tile.dart';

/// `/training/roadmap` — chưa có mục tiêu thì chọn, có rồi thì xem lộ trình.
class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  bool _changing = false;

  @override
  Widget build(BuildContext context) {
    final roadmap = ref.watch(roadmapProvider);
    return PcRootScaffold(
      title: Vi.roadmapTitle,
      body: roadmap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const PcEmptyState(
          icon: Icons.cloud_off,
          title: Vi.dataErrorTitle,
          body: Vi.dataErrorBody,
        ),
        data: (r) => r == null || _changing
            ? GoalPicker(
                onPicked: () => setState(() => _changing = false),
                onCancel: r == null ? null : () => setState(() => _changing = false),
              )
            : RoadmapView(roadmap: r, onChange: () => setState(() => _changing = true)),
      ),
    );
  }
}

class RoadmapView extends ConsumerWidget {
  const RoadmapView({required this.roadmap, required this.onChange, super.key});

  final Roadmap roadmap;
  final VoidCallback onChange;

  /// Tên hiển thị của refId thành tích: nhóm, bài tập, hoặc mốc chuỗi ngày.
  static String _subject(Achievement a, Map<String, Drill> drills) {
    final key = a.refId.split(':').last;
    final cat = SkillCategory.values.asNameMap()[key];
    if (cat != null) return Vi.skill(cat);
    return drills[key]?.name ?? key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final drills = {for (final d in ref.watch(drillsProvider).value ?? const <Drill>[]) d.id: d};
    final achievements = ref.watch(achievementsProvider).value ?? const <Achievement>[];
    final today = ref.watch(nowProvider)();
    final need = Vi.roadmapNeed(roadmap);
    final finish = roadmap.finish;
    final shown = roadmap.steps.where((s) => s.status != StepStatus.khongKip);

    StepTile tile(RoadmapStep s) => StepTile(step: s, drill: drills[s.drillId], today: today);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Vi.roadmapHeadline(roadmap), style: theme.textTheme.titleMedium),
              if (need != null) Text(need),
              if (roadmap.blocked case final b?) Text(Vi.goalBlocked(b)),
              if (roadmap.achieved)
                const Text(Vi.roadmapAchieved)
              else if (finish != null)
                Text(Vi.finishLine(finish)),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: onChange, child: const Text(Vi.goalChange)),
                  TextButton(
                    onPressed: () => ref.read(roadmapRepositoryProvider)!.clearGoal(),
                    child: const Text(Vi.goalClear),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final s in shown) tile(s),
        if (roadmap.missed.isNotEmpty)
          ExpansionTile(
            title: const Text(Vi.roadmapMissedTitle),
            children: [for (final s in roadmap.missed) tile(s)],
          ),
        const SizedBox(height: 16),
        Text(Vi.achievementsTitle, style: theme.textTheme.titleMedium),
        if (achievements.isEmpty)
          const Text(Vi.achievementsEmpty)
        else
          for (final a in achievements)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(Vi.achievement(a.kind, _subject(a, drills))),
              subtitle: Text(Vi.shortDate(a.achievedAt)),
            ),
      ],
    );
  }
}
```

- [ ] **Step 6: Add the Luyện tập card**

In `training_screen.dart`, insert this as the first child of the outer `Column`, before the simulator card:

```dart
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: PcCard(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text(Vi.roadmapTitle),
                subtitle: const Text(Vi.roadmapCardBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.roadmap),
              ),
            ),
          ),
```

Add a test to `test/features/training/training_screen_test.dart` that uses the file's `openTraining` helper:

```dart
  testWidgets('thẻ Lộ trình mở màn chọn mục tiêu', (tester) async {
    await openTraining(tester, const []);
    await tester.tap(find.text(Vi.roadmapTitle));
    await tester.pumpAndSettle();
    expect(find.text(Vi.goalPickTitle), findsOneWidget);
  });
```

`openTraining` builds `testContainer(logs: logs)`, which overrides `goalProvider` with `null` (Task 11), so the picker shows.

Run `"$FLUTTER" test test/features/training/training_screen_test.dart`. An existing test may now fail only because a drill tile was pushed below the 600 px fold: the finder finds nothing, or `tap` warns that the target is off-screen. In that case, give `openTraining` the taller surface used by `home_screen_test`:

```dart
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
```

Log it as a ruling. Do not change any assertion.

- [ ] **Step 7: Run every touched test, the smoke test and the architecture test**

Run: `"$FLUTTER" test test/features test/core test/smoke test/architecture_test.dart`
Expected: PASS. `all_routes_test` opens `/training/roadmap` through `Routes.all` and sees the picker.

- [ ] **Step 8: Commit**

```bash
git add lib/features/roadmap lib/core/router lib/features/training/presentation/training_screen.dart test/features/roadmap test/features/training/training_screen_test.dart test/core/router/routes_test.dart
git commit -m "Add the Lộ trình screen with the goal picker, steps and achievements under Luyện tập

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: The Trang chủ line and the sign-out warning (spec §8, §6)

**Files:**
- Create: `lib/features/roadmap/presentation/roadmap_home_line.dart`
- Modify: `lib/features/home/presentation/home_screen.dart` (after the today card)
- Modify: `lib/features/profile/presentation/profile_screen.dart` (`_signOut`)
- Modify: `lib/core/strings/vi.dart` (`signOutPendingRoadmap`)
- Modify: `test/features/home/home_screen_test.dart`, `test/features/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `roadmapProvider`, `drillsProvider`, `Vi.homeCurrentStep`, `Vi.stepTitle`, `pendingRoadmapCount`, `roadmapSyncProvider`.
- Produces: `RoadmapHomeLine` and `Vi.signOutPendingRoadmap(int)`.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/home/home_screen_test.dart`, reusing that file's pump helper (it builds the app with `testContainer` on an 800×1000 surface):

```dart
  testWidgets('có mục tiêu: Trang chủ hiện bước hiện tại, chạm thì mở Lộ trình', (tester) async {
    final at = DateTime(2026, 9, 20, 9);
    // dùng helper sẵn có của file, truyền goal vào testContainer
    await pumpHome(tester, testContainer(goal: GoalRecord(
      updatedAt: at,
      goal: PlayerGoal(goalId: 'g', kind: GoalKind.thuanThucKyNang, category: SkillCategory.aiming, createdAt: at),
    )));
    final line = find.text(Vi.homeCurrentStep('Đường thẳng cơ bản'));
    expect(line, findsOneWidget);
    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(find.text('Thuần thục: ${Vi.skill(SkillCategory.aiming)}'), findsOneWidget);
  });

  testWidgets('chưa có mục tiêu: Trang chủ không hiện dòng bước hiện tại', (tester) async {
    await pumpHome(tester, testContainer());
    expect(find.textContaining('Bước hiện tại'), findsNothing);
  });
```

If the file's helper has a different name or signature, rename `pumpHome` to match it and keep the bodies as they are. If the helper builds its own container, give it an optional `ProviderContainer` parameter.

Add to `test/features/profile/profile_screen_test.dart`, next to the existing sign-out-warning test for assessment data, and copy that test's setup (`dbContainer` + rows inserted directly):

```dart
  testWidgets('đăng xuất khi còn mục tiêu chưa đồng bộ thì cảnh báo', (tester) async {
    // như test cảnh báo dữ liệu đánh giá: chèn một dòng mục tiêu chưa đồng bộ
    await db.into(db.playerGoalRows).insert(
        PlayerGoalRowsCompanion.insert(userId: 'u1', updatedAt: DateTime(2026, 9, 20, 9)));
    // ... mở Hồ sơ và bấm Đăng xuất bằng đúng các bước của test đánh giá ...
    expect(find.text(Vi.signOutPendingRoadmap(1)), findsOneWidget);
  });
```

Copy the opening and tapping lines from the neighbouring assessment test word for word; only the inserted row and the expected text differ. The two comment lines in the snippet above mark where those copied lines go. Delete those comments in the final test.

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/features/home test/features/profile`
Expected: FAIL (`RoadmapHomeLine` and `Vi.signOutPendingRoadmap` do not exist yet).

- [ ] **Step 3: Write `roadmap_home_line.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/roadmap_providers.dart';
import 'package:poolcoachai/core/providers/stream_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_card.dart';
import 'package:poolcoachai/domain/drill.dart';

/// "Bước hiện tại: …" trên Trang chủ (spec mục 8). Không có mục tiêu hay
/// không còn bước nào thì không hiện gì — thẻ gợi ý hôm nay giữ nguyên.
class RoadmapHomeLine extends ConsumerWidget {
  const RoadmapHomeLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(roadmapProvider).value?.currentStep;
    if (step == null) return const SizedBox.shrink();
    final drills = ref.watch(drillsProvider).value ?? const <Drill>[];
    final drill = drills.where((d) => d.id == step.drillId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PcCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: Text(Vi.homeCurrentStep(Vi.stepTitle(step, drillName: drill?.name))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.roadmap),
        ),
      ),
    );
  }
}
```

`Vi.stepTitle` for a `baiTap` step returns the drill name, which is why the home test expects `Đường thẳng cơ bản`.

In `home_screen.dart`, insert `const RoadmapHomeLine(),` right after the today card's `PcCard(...)`, the one closed before `// Bài tập gợi ý`, and import the file.

- [ ] **Step 4: Count roadmap rows in the sign-out warning**

In `vi.dart`, next to `signOutPendingAssessment`:

```dart
  static String signOutPendingRoadmap(int count) =>
      'Còn $count mục tiêu hoặc thành tích chưa lên máy chủ — đăng xuất bây giờ sẽ mất.';
```

In `profile_screen.dart` `_signOut`:
- After `final pendingRank = …`, add `final pendingRoadmap = await pendingRoadmapCount(db, userId);`.
- Add `|| pendingRoadmap > 0` to the dialog condition.
- Add `if (pendingRoadmap > 0) Text(Vi.signOutPendingRoadmap(pendingRoadmap)),` to the dialog content.
- In the sync-first branch, add `await ref.read(roadmapSyncProvider).syncNow();` and `final leftRoadmap = await pendingRoadmapCount(db, userId);`.
- Add `|| leftRoadmap > 0` to the "still left" condition.
- Change the snackbar choice to `left == unsyncable && leftRank == 0 && leftRoadmap == 0`.

Import `roadmap_providers.dart`.

- [ ] **Step 5: Run the tests, then the whole suite**

Run: `"$FLUTTER" test test/features test/core`
Then: `"$FLUTTER" test > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t14.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/t14.log`
Expected: `All tests passed!` `closed_loop_test` runs on the 800×1000 surface already, and with no goal the home line renders nothing, so it must stay green unchanged.

- [ ] **Step 6: Commit**

```bash
git add lib/features/roadmap/presentation/roadmap_home_line.dart lib/features/home/presentation/home_screen.dart lib/features/profile/presentation/profile_screen.dart lib/core/strings/vi.dart test/features/home/home_screen_test.dart test/features/profile/profile_screen_test.dart
git commit -m "Show the current roadmap step on Trang chủ and warn about unsynced goals on sign-out

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Real Chrome, then HOLD for the owner's check (spec §9)

> **Needs:** Task 10 Step 5 done (`player_goals` and `achievements` exist on the server).

**Files:**
- Create: `tool/e2e/roadmap.mjs`
- Modify: `docs/superpowers/logs/2026-10-15-roadmap.md`

**Interfaces:**
- Consumes: `launch` (`cdp.mjs`), `registerThrowaway`, `deleteUserByEmail` (`throwaway_user.mjs`), the strings of Task 12.
- Produces: screenshots in `%TMP%/pcai-roadmap` and the log section `## Chrome (<ngày>)`.

- [ ] **Step 1: Write `tool/e2e/roadmap.mjs`**

```js
// Lộ trình trên Chrome thật (spec 2026-10-15 mục 9): chọn mục tiêu → thấy
// bước → ghi một buổi tập → lộ trình đổi → đổi mục tiêu → máy thứ hai thấy
// cùng mục tiêu.
//   node tool/e2e/roadmap.mjs [appUrl]
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
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-roadmap');
const email = `e2e-roadmap-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (n, msg) => console.log(`\n── Bước ${n}: ${msg}`);

const one = await launch({ port: 9337, name: 'roadmap-1' });
const two = await launch({ port: 9338, name: 'roadmap-2' });
try {
  step(1, 'Đăng ký (Để sau bộ câu hỏi): chưa có hạng');
  await registerThrowaway(one, APP, { email, password });

  step(2, 'Lộ trình: bảng chọn mục tiêu, Lên hạng bị khóa vì chưa có hạng');
  await one.goto(`${APP}/training/roadmap`);
  await one.waitForText('Chọn mục tiêu');
  await one.waitForText('Cần có hạng trước khi đặt mục tiêu lên hạng.');
  await one.shot(path.join(shots, '01-chon-muc-tieu.png'));

  step(3, 'Thuần thục kỹ năng → Ngắm bi: thấy các bước');
  await one.click('Thuần thục kỹ năng');
  await one.click('Ngắm bi');
  await one.waitForText('Thuần thục: Ngắm bi');
  await one.waitForText('Đang làm');
  await one.waitForText('Buổi đạt liên tiếp: 0 / 3');
  await one.shot(path.join(shots, '02-lo-trinh.png'));

  step(4, 'Tập ngay: ghi một buổi 9/10');
  await one.click('Tập ngay');
  await one.waitForText('Tập: ');
  await one.type('Số lần đạt', '9');
  await one.type('Số lần thử', '10');
  await one.click('Lưu kết quả');
  await one.waitForText('Đã lưu');

  step(5, 'Quay lại Lộ trình: bước đổi theo buổi vừa ghi');
  await one.goto(`${APP}/training/roadmap`);
  await one.waitForText('Buổi đạt liên tiếp: 1 / 3');
  await one.waitForText('Chưa có thành tích');
  await one.shot(path.join(shots, '03-sau-buoi-tap.png'));

  step(6, 'Đổi mục tiêu sang Thuần thục Phòng thủ');
  await one.click('Đổi mục tiêu');
  await one.click('Thuần thục kỹ năng');
  await one.click('Phòng thủ');
  await one.waitForText('Thuần thục: Phòng thủ');
  await one.shot(path.join(shots, '04-doi-muc-tieu.png'));

  step(7, 'Máy thứ hai đăng nhập: thấy cùng mục tiêu');
  await two.goto(APP);
  await two.type('Email', email);
  await two.type('Mật khẩu', password);
  await two.click('Đăng nhập');
  await two.waitForText('Xin chào');
  await two.goto(`${APP}/training/roadmap`);
  await two.waitForText('Thuần thục: Phòng thủ', 45000);
  await two.shot(path.join(shots, '05-may-2.png'));

  const errors = [...one.errors, ...two.errors].filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await one.close();
  await two.close();
  await deleteUserByEmail(email);
}
```

Run `node --check tool/e2e/roadmap.mjs`.

- [ ] **Step 2: Build, serve locally, run everything**

```bash
"$FLUTTER" build web --release
node tool/e2e/serve.mjs build/web 5555 &   # chạy nền
eval "$(node -e "const e=require('C:/Users/anhnpv/Desktop/PoolCoachAI/.claude/settings.local.json').env;for(const k of ['DIRECTUS_URL','DIRECTUS_ADMIN_EMAIL','DIRECTUS_ADMIN_PASSWORD','MAILPIT_URL','MAILPIT_USER','MAILPIT_PASSWORD'])if(e[k])console.log('export '+k+'='+JSON.stringify(e[k]))")"
node tool/e2e/roadmap.mjs http://localhost:5555
node tool/e2e/rank.mjs http://localhost:5555
node tool/e2e/accounts.mjs http://localhost:5555
node tool/e2e/simulator.mjs http://localhost:5555
node tool/e2e/planner.mjs http://localhost:5555
```

Expected: `roadmap.mjs` prints the 7 steps and `Xong.`, and the four older scripts pass as before. A successful build proves nothing; only these runs do. If a step fails, fix the app, not the script's expectations, unless the script quotes a string wrongly. A wrongly quoted string means the script differs from `Vi`; fix it to match `Vi`. Stop the local server afterwards.

- [ ] **Step 3: Commit the script**

```bash
git add tool/e2e/roadmap.mjs
git commit -m "Add the Lộ trình Chrome scenario across two devices

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: HOLD — the owner's check. STOP here.**

Show the owner:
- the screenshots `01`–`05`;
- the rulings R1–R11 above, especially R2 (bỏ mục tiêu keeps an empty row), R5 (S8/S9 step), R7 (when *Xong bước* is earned) and R9 (the test button is never locked);
- any ruling added during execution.

Ask:
1. *"Màn Lộ trình và bảng chọn mục tiêu có dễ hiểu, đúng thuật ngữ không?"*
2. *"Các câu lý do, ngày dự kiến và thành tích có ổn không?"*
3. *"Các quyết định R1–R11 có cái nào bạn muốn đổi không?"*

Change nothing until the owner answers. Apply only what the owner names, re-run Step 2, show the new screenshots, and repeat until the owner approves.

- [ ] **Step 5: Log and commit**

Append to the log:

```markdown
## Chrome (<ngày>)

- Bản build từ <hash>, chạy local cổng 5555.
- roadmap.mjs: <7 bước, Xong.>
- rank.mjs / accounts.mjs / simulator.mjs / planner.mjs: <kết quả>

## Chủ sản phẩm duyệt

- <câu trả lời nguyên văn>

## Sửa theo chủ sản phẩm

- <không có / danh sách>
```

```bash
git add docs/superpowers/logs/2026-10-15-roadmap.md
git commit -m "Log the Chrome run and the owner's check of Lộ trình

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Full verification, the PRD, and the whole-branch review

**Files:**
- Modify: `PRD_PoolCoachAI.md` (§6.1 Lộ trình)
- Modify: `docs/superpowers/logs/2026-10-15-roadmap.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a green branch ready for the owner's merge decision.

- [ ] **Step 1: Run everything**

```bash
"$FLUTTER" analyze > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/final-analyze.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/final-analyze.log
"$FLUTTER" test > .superpowers/sdd/2026-10-15-poolcoachai-roadmap/final-test.log 2>&1; tail -1 .superpowers/sdd/2026-10-15-poolcoachai-roadmap/final-test.log
```

Expected: `No issues found!` and `All tests passed!`, with more tests than the Task 0 baseline.

- [ ] **Step 2: Update the PRD.** In `PRD_PoolCoachAI.md` §6.1, the Lộ trình section, replace the paragraph with what shipped. Keep the PRD's language and heading.

```markdown
Lộ trình (đã làm, spec 2026-10-15): mỗi tài khoản một mục tiêu — Lên hạng (luôn là hạng ngay trên), Thuần thục một nhóm kỹ năng, hoặc Chuẩn bị giải (có ngày giải). App suy các bước từ dữ liệu thật: điểm mất ở bài BU hoàn chỉnh gần nhất (qua bảng nối 18 bài BU vào 6 nhóm), Player Intelligence và nhật ký tập; tính lại mỗi khi dữ liệu đổi. Một bước xong khi nhóm đạt 75 và bài của bước có 3 buổi đạt liên tiếp. Ngày dự kiến ước lượng từ tốc độ tiến bộ 28 ngày gần nhất; không đủ dữ liệu thì nói thẳng. Thành tích chỉ đến từ sự kiện thật: xong bước, đủ điều kiện lên cấp, chuỗi 7/14/30/60/100 ngày. AI đề xuất, không khóa người dùng; không dùng LLM. Mục tiêu và thành tích đồng bộ theo tài khoản.
```

- [ ] **Step 3: Whole-branch review**

Do a self-review, or use a reviewer if the owner chose one, of `git diff main...HEAD` against the spec and this plan. Check:
- every spec section has code and a test;
- no Vietnamese literal sits in `lib/features`;
- `lib/domain/roadmap` has no Flutter import;
- no `Achievement(` is built outside the domain and the converters;
- the five Review Focus lines each have their test.

Fix real findings test-first, one commit each. Record "Final review: …" in the ledger.

- [ ] **Step 4: Log and commit**

```bash
git add PRD_PoolCoachAI.md docs/superpowers/logs/2026-10-15-roadmap.md
git commit -m "Describe the shipped Lộ trình in the PRD and log the final verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Hand off to the owner.** Use superpowers:finishing-a-development-branch. Report the test count, the analyze result and the Chrome results. Then ask the owner to choose: merge into local `main`, push, and/or deploy (`deploy/publish.sh` + Easypanel, then re-run the five Chrome scripts against the live site). Do none of these without the owner's answer.

---

## Self-review (applied)

**Spec coverage:**
- §1 purpose: Tasks 4–5, 11, 13.
- §2.1 baseline and no new survey: the builder reads rank, BU and Player Intelligence only.
- §2.2 named templates and no LLM: Task 12 and the architecture test.
- §2.3 no rank warning: rank is read-only.
- §2.4 recompute on goal change: `setGoal` makes a new `goalId` and the builder is stateless.
- §2.5 dynamic dates: Task 3 / Task 4.
- §2.6 `isReadyForLevelUp` reused: Task 4.
- §2.7 achievements only from events: Task 6 plus the architecture test.
- §2.8 no new tab, Recommendation Engine untouched: Task 13 / Task 14.
- §3 goals and locks: Task 1, Task 13.
- §4.1: Task 4. §4.2–4.3: Task 5. §4.4: Task 4. §4.5: Task 3 / Task 4.
- §5 table: Task 2.
- §6 data, sync and Directus: Tasks 7–10.
- §7 achievements: Task 6, Task 11.
- §8 UI: Tasks 13–14.
- §9 tests: in each task, plus Chrome in Task 15.
- §10 out of scope: nothing built for it.

**Placeholder scan:**
- The two `UnimplementedError('Task 5')` arms are created and removed inside the plan, and Task 5 tests that they are gone.
- Task 14's profile test says to copy the neighbouring test's setup lines verbatim. Those lines exist in the repo, but their exact helper names were not read at plan time.

**Type consistency:**
- `GoalRecord`, `PlayerGoal`, `BuResult`, `RoadmapStep`, `Roadmap`, `Estimate`, `Achievement`, `PracticeFacts` and `buildRoadmap(...)` keep the same names and parameter lists in every task.
- `placeSteps` and `lostStep` are public in `roadmap_builder.dart` because Task 5 calls them.
- `_byPointsThenWeakness` and `_Lost` stay private, and Task 5 edits the same file.

**Review Focus:** each of the five lines names its test and the task that owns it.
