# Nhóm bài Dựng cơ, Nhảy bi, Mát xê Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three new skill groups (`dungCo`, `nhayBi`, `matXe`) with nine drills `d11`–`d19` built on the BU Exam II S8/S9 layouts, each drill showing its real sources, its cloth warning and its BU diagrams. The groups are "advanced": nothing in the app proposes them until the player has logged a session in them (or, for Dựng cơ, until BU S8 shows real lost points). Builds that already shipped keep syncing.

**Architecture:** `SkillCategory` gets three members and an `isAdvanced` getter. A single predicate, `PlayerIntelligence.inScope`, keeps advanced groups with no scored session out of the weak list, the Home rules and the automatic Roadmap lists. A domain table, `lib/domain/drill_provenance.dart`, maps each new drill id to its BU drill and tier. The seed derives `target` and `level` from that table and the BU score sheet, and the detail screen derives the source line and diagram link from it. Shipped builds throw on an unknown category name in four sync paths. The new build therefore writes the three new names only into new Directus fields (`*_ext`) that shipped builds never request, and keeps the old fields limited to the six names every build parses. `bu_category_map` maps S8 to `dungCo`. S9 stays unmapped, and its Roadmap step gets a hint that opens the Thuần thục picker.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod 3 (no codegen), Drift (SQLite; `NativeDatabase.memory` in tests), go_router, Directus REST sync, Node 24 (`deploy/directus/*.mjs`, `tool/e2e` CDP scripts, `server/coach-chat` tests).

**Spec:** `docs/superpowers/specs/2026-10-29-poolcoachai-drill-groups-design.md`

## Global Constraints

- Work only in the worktree `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\drill-groups` (branch `feat/drill-groups`). Bash cwd resets between calls, so start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/drill-groups && `.
- Prefix every flutter / dart / npm / node command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN`, because the shell exports live secrets. Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat` and Dart is `/c/Users/anhnpv/flutter/bin/dart.bat`; neither is on PATH. Below, `$ENV` stands for that `env -u …` prefix, `$FLUTTER` for the Flutter path and `$DART` for the Dart path. Write them out in full when you run them.
- `*.g.dart` files are gitignored and missing in this fresh worktree. Task 1 Step 1 generates them. The Drift schema does not change in this plan (no migration, `schemaVersion` stays 16).
- Line numbers in this plan and in the spec go stale. Locate code by symbol (function, constant, test name), never by line.
- When a task changes an enum or a list that tests enumerate, the same task updates those tests. A task ends with the touched test files and `$ENV $FLUTTER analyze` green.
- Don't reformat existing files wholesale. Never run `dart format` on a whole file you did not create.
- **No fabrication** (README rule 1, spec §2). Drill content comes only from the texts given in Task 5, which are paraphrased from the three sources in spec §2. Every number shown is computed: shot counts come from `drillFor(buDrillId, version).attemptCount` (BU score sheet), levels from the BU tier. Never add an angle, a power level, a distance in cm or a tip-offset count.
- Owner vocabulary, exactly: Dựng cơ (nâng đuôi cơ), Nhảy bi, Mát xê (a separate technique; never merge it with Nhảy bi), Chết cái (never "Scratch"), bi cái, bi mục tiêu, bi chướng ngại, nỉ, đuôi cơ, trượt cơ (miscue), cơ nhảy. New drill text holds no English technique word (`Jump`, `jump`, `Massé`, `Masse`, `masse`, `Scratch`, `scratch`, `miscue`, `Elevated`). Proper names stay English: "Billiard University Exam II", "Bachelors/Masters/Doctorate", "Dr. Dave Alciatore".
- UI copy goes into `Vi`, using exactly the strings this plan gives. No Vietnamese literal in `lib/features/**`, `lib/core/widgets/**` or `lib/domain/**`; comments may be Vietnamese. Drill texts live in `lib/data/seed/seed_drills.dart`.
- Outside `lib/data/seed/` and `upsert_seed.dart`, nothing in `lib/` reads seed data (`test/architecture_test.dart`). Screens read drills only through `drillsProvider` and provenance only through `drillProvenanceOf`.
- **Category compatibility rule (Task 4):** the Directus fields `timer_sessions.cat`, `schedule_slots.cat`, `cue_equipment.skill_categories` and `player_goals.category`/`kind` only ever carry the six names in `legacyCategoryNames`. Any other category travels in `cat_ext`, `skill_categories_ext` or `category_ext`. A build reads the old field first and falls back to the `_ext` field.
- Riverpod has no codegen. Never call `.invalidate(` or `.refresh(` in `lib/`.
- Test gotchas:
  1. Reading a provider `.future` in a test can hang silently. Use `container.listen(p, (_, _) {})`, then pump the event queue, then `container.read(p)`.
  2. Never write an explicit type on an override list. `<Override>[…]` or `List<Override>` crashes the compiler, so leave the list literal untyped.
  3. Inside `testWidgets`, `await repo.watchX().first` hangs. Read rows with `db.select(db.table).get()`.
  4. Drift `AppDatabase.forTesting(NativeDatabase.memory())` works inside `flutter test`.
  5. Drift stores `DateTime` as whole seconds, so every fixed clock in tests is a whole second.
- No widget measures text intrinsically (`IntrinsicHeight` / `IntrinsicWidth`): Be Vietnam Pro arrives after the first frame, and Flutter 3.47 keeps stale intrinsic sizes.
- The app must keep running on Android, iOS and web, so no web-only code.
- One commit per task. Subjects are in Vietnamese and end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No push, no PR, no deploy, no APK, no Directus or prod call. Do **not** run `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` or any `tool/e2e/*.mjs`; check them with `node --check` only.
- A full-suite `flutter test` takes minutes. Run it in the background and stream the step plus the pass/fail counts every minute with Monitor. Never wait silently.

## Review Focus

1. **A score that is not a shot count.** On a BU drill with 3 shots, "4" or "2.5" must be refused, both in Luyện tập and in Skill Test. "3" passes and "0" is accepted. Tests: Task 2 (`checkShotScore`, `checkSkillTestInput`), Task 7 (session screen).
2. **An advanced group with exactly one session** (mastery still "chưa đo") becomes a normal group. It joins rotation, the streak rule and the automatic Roadmap lists as an `Unmeasured` step, and it is BU-weak when S8 is weak. With zero sessions, none of that happens. Tests: Task 3 (rotation, roadmap), Task 6 (BU-weak with one log).
3. **Mixed builds editing the same row.** An old build changes a slot from (invisible) Dựng cơ to Ngắm bi, edits a cue's skills, or sets a new goal. The new build must show the old build's choice, not the stale `_ext` value, and must keep the advanced skills the old build could not see. Tests: Task 4.
4. **BU S8 points lost, no Dựng cơ log, Chuẩn bị giải goal.** The lost points must not vanish: a Dựng cơ step with `LostBuPoints(…, ['S8'])` appears. Tests: Task 6.
5. **The BU diagram link.** Masters S8 opens exactly its 5 diagrams, numbered 1/5…5/5. S9 Doctorate opens its single diagram. An unknown drill or tier in the query shows "Hết sơ đồ." instead of crashing. Tests: Task 7.

## Plan's calls

The spec is silent or leaves a choice in the places below, so the plan decides. Each call is marked ★ where it applies.

1. **Shot counts** (spec §4 "target = số cú trong bố cục BU"). The count is `drillFor(id, v).attemptCount` from `bu_exams.dart`, the BU score sheet (one point per shot, `maxScore == attemptCount`): **S8 3 / 5 / 7, S9 3 / 5 / 7** for Bachelors / Masters / Doctorate. For S8 this also equals the number of diagrams in `layoutsFor('S8', v)`, one diagram per shot. S9 has **one** diagram per tier, shot 3, 5 or 7 times (`layoutForAttempt` maps every attempt to it). Tests assert both facts, so a change to either BU table moves `target`.
2. **The provenance table lives in `lib/domain/drill_provenance.dart`**, not in `lib/data/seed/` as spec §5 says. `test/architecture_test.dart` forbids screens from reading seed data, and the detail screen and the score check both need the table. It holds ids, BU drill ids and tiers only, with no Vietnamese text, and it is not stored in the DB (spec §5). The seed derives each new drill's `target` and `level` from it, so the table is the only place those facts are written.
3. **Step 1 of every new drill is `Vi.buDrillSetup(buDrillId, version)`**, computed in the seed and never copied, so the drill and the BU runner cannot drift apart. `seed_drills.dart` imports `vi.dart`, and `seedDrills` becomes `final` (the ten old drills stay a `const` list `_baseDrills`).
4. **The detail screen gets a "Xem sơ đồ BU" button** that opens the BU diagram gallery filtered to the drill's BU drill and tier. S8 cue-ball positions exist only on the diagrams, and the BU text says "từ vị trí bi cái đã chỉ".
5. **Shot-count score check:** for a provenance drill the score is a whole number from 0 to `target`. This is enforced in the session screen and in `checkSkillTestInput`, via `checkShotScore`.
6. **"In scope" predicate:** `inScope(c) = !c.isAdvanced || categories[c].sessionCount > 0`. It gates PI `buWeak`, recommendation rules 2 (streak), 5 (newcomer) and 7 (rotation), Roadmap `_weakGroups`, and Roadmap `_tournament` `below`. In `_tournament` with a BU result, a group whose BU lost points are > 0 stays in, because points must not vanish and they are real data (spec §3 bullet 4). Lên hạng with BU already takes groups from lost points.
7. **Names** are computed: `'${Vi.skill(cat)} — bậc ${Vi.buVersionName(v)}'`, for example "Dựng cơ — bậc Masters". Levels are 1 / 2 / 3. Unit: `'cú thành công / $n'`.
8. **Source line** per group, exact text in Task 7. The dictionary is cited as "Từ điển kiến thức Billiard Pool, mục 17/18". Mát xê also uses one non-numeric aiming line from dictionary §18 ("ngắm điểm chạm lệch tâm bi cái về phía muốn bi cái cong tới"), because Dr. Dave's §13.4 gives no aiming guidance. Its source line says so ("cách ngắm"). The spec table limits the dictionary to errors and warnings, so this is flagged for the owner.
9. **The cloth warning** (`Vi.drillClothWarning`) shows for every drill whose `cat.isAdvanced`. "Chưa có mẹo kỹ thuật có nguồn cho dựng cơ." shows for `dungCo` drills.
10. **Colors:** the three new color sets reach ≥ 4.5:1 text-on-chip contrast (6.02, 5.39, 6.64). Existing Phá (4.10) and Phòng thủ (4.47) are below 4.5. That is reported to the owner and left unchanged, since it is out of scope.
11. **Coach chat:** `test/domain/coach/coach_chat_prompt_test.dart` requires `server/coach-chat/src/prompt.mjs` to name every `SkillCategory`. So the prompt's category line gains the three names (Task 3), although spec §6 says nothing is needed.
12. **Old builds** (spec §6, see Task 1 for the evidence). Shipped readers throw on an unknown name in `timer_sessions.cat` and `schedule_slots.cat` (the whole `PracticeSyncService` run fails, so slots and tournaments stop syncing), in `cue_equipment.skill_categories` (cue sync fails), and in `player_goals.category` (`byName`, so goal sync and the achievements pull fail). `drill_logs` and `skill_tests` carry no category and are safe. Ruling: use the compatibility rule in Global Constraints. An advanced Thuần thục goal is sent with legacy `kind` and `category` null and `category_ext` set, so shipped builds read it as "no goal". Shipped builds then see advanced timer sessions and slots without a group, a cue without its advanced skills, an advanced goal as no goal, and an achievement subject as the raw key (for example "nhayBi"). Nothing breaks.
13. **Release order (controller, outside this plan):** run `bootstrap.mjs` then `verify.mjs` on prod **before** the web publish. Every new-build GET asks for the `_ext` fields, and Directus refuses unknown fields, so publishing first breaks timer, slot, cue and goal sync for every user until bootstrap runs. After publish, run `tool/e2e/drill_groups.mjs` and the existing live suite.
14. **Rollback caveat:** once players use the new groups, their local rows hold the new names. A web rollback to a pre-feature build then fails to parse those rows (`_parseCategory` throws) for those players until they clear site data. Only forward fixes are safe.
15. **Spec §6 "memory thuật ngữ" (6 → 9 groups)** is a controller step outside the repo. Task 10 lists the line to add.

---

### Task 1: Characterize how shipped readers handle new names

**Files:**
- Modify: `test/data/sync/old_build_compat_test.dart` (append a `group`)

**Interfaces:**
- Consumes: `PracticeSyncService`, `CueEquipmentSyncService`, `RoadmapSyncService`, `SyncService` (drill logs), `goalFromRemote`, `skillTestFromRemote`, `toSkillTest`, `computePlayerIntelligence`, `certificationSummary`, `FakeDirectus`, `FakeAuthRepository`, all unchanged.
- Produces: two constants at the top of the test file that later tasks edit: `const unknownCategory = 'dungCo';` (Task 3 changes it to `'nhomTuongLai'`) and `const unknownDrillId = 'd11';` (Task 5 changes it to `'d99'`). Each has the comment "tên/mã mà chính bản này chưa biết — với bản đã phát hành đó là tên mới của plan 2026-10-29".

These tests characterize code that already exists, so they pass on the first run. They stay green to the end: the strict readers are not changed, and the new build never sends them a name they do not know (Task 4).

- [ ] **Step 1: Setup.** Run `$ENV $FLUTTER pub get`, then `$ENV $DART run build_runner build --delete-conflicting-outputs`. Expected: both exit 0.

- [ ] **Step 2: Write the tests** in a new `group('bản đã phát hành gặp nhóm kỹ năng nó chưa biết (spec 2026-10-29 §6)', …)`. They reuse the file's `setUp` (every GET returns `[]`). Item maps carry `user_created: 'u1'`.

```dart
test('cat buổi tập lạ: cả lượt practice thất bại, lịch chờ không lên', () async {
  // một dòng schedule_slot_rows của u1, syncedAt null
  server.routes['GET /items/timer_sessions'] = (_) => FakeDirectus.ok([timerJson(cat: unknownCategory)]);
  expect(await service().syncNow(), SyncOutcome.failed);
  expect(server.sent('POST', '/items/schedule_slots'), isEmpty);
  expect(await db.select(db.timerSessionRows).get(), isEmpty);
});
test('cat lịch tập lạ: thất bại, giải không được kéo', () async {
  server.routes['GET /items/schedule_slots'] = (_) => FakeDirectus.ok([slotJson(cat: unknownCategory)]);
  expect(await service().syncNow(), SyncOutcome.failed);
  expect(server.sent('GET', '/items/tournaments'), isEmpty);
});
test('kỹ năng lạ trong hồ sơ cơ: đồng bộ cơ thất bại, không lưu cơ', () async { /* cueJson(skills: ['aiming', unknownCategory]) → failed, cueEquipmentRows empty */ });
test('nhóm lạ trong mục tiêu: goalFromRemote ném, đồng bộ Lộ trình thất bại', () async {
  final bad = {...goalJson, 'kind': 'thuanThucKyNang', 'category': unknownCategory};
  expect(() => goalFromRemote(bad), throwsArgumentError);
  server.routes['GET /items/player_goals'] = (_) => FakeDirectus.ok([bad]);
  expect(await roadmapService().syncNow(), SyncOutcome.failed);
});
test('đường an toàn: trường cũ hợp lệ, trường _ext lạ bị bỏ qua', () async {
  // timerJson(cat: null, extra: {'cat_ext': unknownCategory}) và slotJson(...) tương tự → done, cat null
  // cueJson(skills: ['aiming'], extra: {'skill_categories_ext': [unknownCategory]}) → done, skillCategories '["aiming"]'
  expect(goalFromRemote({...goalJson, 'kind': null, 'category': null, 'goal_id': 'g1', 'category_ext': unknownCategory}).goal, isNull);
});
test('buổi tập của bài lạ: được lưu, Intelligence bỏ qua', () async {
  // SyncService kéo drill_logs [{id:'l1', drill_id: unknownDrillId, date, score: 3, attempts: null, notes: null, duration_sec: 60}]
  // → drillLogRows có l1; computePlayerIntelligence(drills: seedDrills, logs: [l1]).hasAnyData == false,
  //   mọi categories[c].sessionCount == 0
});
test('bài kiểm tra của bài lạ: dựng được, chứng nhận bỏ qua', () {
  // skillTestFromRemote({... 'drill_id': unknownDrillId ...}) isNotNull; toSkillTest(row) isNotNull;
  // certificationSummary(drills: seedDrills, logs: const [], tests: [test]).groups isEmpty
});
```

Helpers in the test: `timerJson({Object? cat, Map<String, Object?> extra = const {}})` returns `{id: 't1', user_created: 'u1', date: '2026-10-27T08:00:00.000Z', duration_sec: 600, cat: cat, cue_id: null, ...extra}`. `slotJson` returns `{id: 's1', user_created: 'u1', day: 2, time: '19:00', label: 'Tập tối', cat: cat, updated_at: '2026-10-27T08:00:00.000Z', is_deleted: false, ...extra}`. `cueJson` uses type `'playing'`, every optional field null, `updated_at` and `is_deleted: false`. The test needs `GET /items/cue_equipment` and `GET /items/drill_logs` routes, with `[]` as the default.

- [ ] **Step 3: Run them.** Run `$ENV $FLUTTER test test/data/sync/old_build_compat_test.dart`. Expected: all PASS. If any "fails" expectation does not hold, stop and report it: the release risk in call ★12 would then differ.

- [ ] **Step 4: Commit.** `git add test/data/sync/old_build_compat_test.dart`, then commit with the message `Nhóm bài nâng cao: test chứng minh bản đã phát hành ném khi gặp tên nhóm lạ (buổi tập, lịch, cơ, mục tiêu), an toàn với bài lạ` and the trailer.

---

### Task 2: Drill provenance and the shot-count score rule

**Files:**
- Create: `lib/domain/drill_provenance.dart`
- Modify: `lib/domain/skill_test/skill_test.dart` (`SkillTestInputError`, `checkSkillTestInput`)
- Modify: `lib/core/strings/vi.dart` (`skillTestInputError`, add `shotScoreError`)
- Test: `test/domain/drill_provenance_test.dart` (create), `test/domain/skill_test/skill_test_test.dart` (or the file that tests `checkSkillTestInput`; find it by grepping)

**Interfaces:**
- Consumes: `ExamIIVersion` (`lib/domain/assessment/bu_placement.dart`), `drillFor` (`lib/domain/assessment/bu_exams.dart`), `Drill`.
- Produces (`drill_provenance.dart`):
  - `final class DrillProvenance { const DrillProvenance({required String buDrillId, required ExamIIVersion version}); int get shots /* drillFor(buDrillId, version).attemptCount */; int get level /* version.index + 1 */; }`
  - `const drillProvenance = <String, DrillProvenance>{…}` with exactly: `d11` S8 bachelors, `d12` S8 masters, `d13` S8 doctorate, `d14` S9 bachelors, `d15` S9 masters, `d16` S9 doctorate, `d17` S9 bachelors, `d18` S9 masters, `d19` S9 doctorate.
  - `DrillProvenance? drillProvenanceOf(String drillId)`
  - `enum ShotScoreError { notWhole, aboveShots }`
  - `ShotScoreError? checkShotScore(Drill drill, num score)`: returns null when `drillProvenanceOf(drill.id)` is null. Otherwise it returns `notWhole` when `score != score.truncate()` and `aboveShots` when `score > drill.target!`. Negative and non-finite scores are left to the existing checks.
  - `SkillTestInputError.scoreAboveShots` (new member, last). `checkSkillTestInput` calls `checkShotScore` after its existing `scoreInvalid` check: `notWhole` becomes `scoreNotWhole` and `aboveShots` becomes `scoreAboveShots`.
  - `Vi.shotScoreError(ShotScoreError e)`: `notWhole` → `'Số cú thành công phải là số nguyên'`, `aboveShots` → `'Số cú thành công không được lớn hơn số cú của bài'`. `Vi.skillTestInputError(SkillTestInputError.scoreAboveShots)` returns `shotScoreError(ShotScoreError.aboveShots)`.

- [ ] **Step 1: Write the failing tests.**

```dart
// test/domain/drill_provenance_test.dart
test('số cú lấy từ phiếu điểm BU: S8 và S9 đều 3 / 5 / 7', () {
  for (final MapEntry(key: id, value: p) in drillProvenance.entries) {
    expect(p.shots, drillFor(p.buDrillId, p.version).attemptCount, reason: id);
    expect(p.shots, drillFor(p.buDrillId, p.version).maxScore, reason: id); // 1 điểm mỗi cú
  }
  expect([for (final id in ['d11', 'd12', 'd13', 'd14', 'd15', 'd16']) drillProvenanceOf(id)!.shots], [3, 5, 7, 3, 5, 7]);
});
test('S8: mỗi cú một sơ đồ; S9: một sơ đồ dùng cho mọi cú', () {
  for (final p in drillProvenance.values) {
    expect(layoutsFor(p.buDrillId, p.version).length, p.buDrillId == 'S8' ? p.shots : 1);
  }
});
test('bảng nguồn: d11–d19, S8 ba bậc, S9 hai lượt ba bậc; cấp = bậc', () {
  expect(drillProvenance.keys, ['d11', 'd12', 'd13', 'd14', 'd15', 'd16', 'd17', 'd18', 'd19']);
  expect(drillProvenance.values.where((p) => p.buDrillId == 'S8').length, 3);
  expect(drillProvenance.values.where((p) => p.buDrillId == 'S9').length, 6);
  expect([for (final p in drillProvenance.values) p.level], [1, 2, 3, 1, 2, 3, 1, 2, 3]);
  expect(drillProvenanceOf('d1'), isNull);
});
test('điểm theo cú: số nguyên từ 0 tới số cú', () {
  final d = Drill(id: 'd11', cat: SkillCategory.aiming, name: 'n', level: 1, unit: 'u', goal: 'g', steps: const [], target: 3);
  expect(checkShotScore(d, 0), isNull);
  expect(checkShotScore(d, 3), isNull);
  expect(checkShotScore(d, 4), ShotScoreError.aboveShots);
  expect(checkShotScore(d, 2.5), ShotScoreError.notWhole);
  expect(checkShotScore(Drill(id: 'd6', /* … */ target: 1), 4), isNull); // bài cũ không đổi
});
// skill test file:
test('Skill Test bài BU: 4/3 cú và 2.5 cú bị từ chối', () {
  expect(checkSkillTestInput(d, score: 4), SkillTestInputError.scoreAboveShots);
  expect(checkSkillTestInput(d, score: 2.5), SkillTestInputError.scoreNotWhole);
  expect(checkSkillTestInput(d, score: 3), isNull);
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/drill_provenance_test.dart` and the skill test file. Expected: compile errors (`drill_provenance.dart` and `scoreAboveShots` do not exist yet).

- [ ] **Step 3: Implement** the Interfaces above. `drill_provenance.dart` imports only domain files and holds no Vietnamese literal.

- [ ] **Step 4: Run the tests and analyze.** Run both test files, `$ENV $FLUTTER test test/architecture_test.dart`, then `$ENV $FLUTTER analyze`. Expected: PASS, no issues.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: bảng nguồn bài BU (d11–d19) và luật điểm theo cú`, plus the trailer.

---

### Task 3: Nine groups and the advanced-group rule

**Files:**
- Modify: `lib/domain/skill_category.dart`, `lib/core/strings/vi.dart` (`Vi.skill`), `lib/domain/coach/coach_topic.dart`
- Modify: `lib/domain/player_intelligence.dart`, `lib/domain/recommendation.dart`, `lib/domain/roadmap/practice_facts.dart`, `lib/domain/roadmap/roadmap_builder.dart`
- Modify: `server/coach-chat/src/prompt.mjs` (the line "Tên nhóm kỹ năng: aiming là Ngắm bi, …")
- Test (update): `test/domain/skill_category_test.dart`, `test/domain/coach/coach_topic_test.dart`, `test/domain/coach/coach_context_test.dart` (the `skills` key list), `test/domain/player_intelligence_test.dart` (the test "các nhóm yếu theo BU bằng điểm nhau xếp theo thứ tự nhóm"), `test/core/widgets/pc_skill_chip_test.dart` (rename to "cả 9 nhóm"), `test/data/sync/old_build_compat_test.dart` (`unknownCategory = 'nhomTuongLai'`), `test/data/seed_test.dart` ("mỗi nhóm kỹ năng có ít nhất một bài tập")
- Test (add): `test/domain/pick_category_test.dart`, `test/domain/player_intelligence_test.dart`, `test/domain/roadmap/roadmap_other_goals_test.dart`, `test/domain/roadmap/roadmap_len_hang_test.dart`, `test/support/roadmap_fixtures.dart`, and picker tests in `test/features/training/training_screen_test.dart`, `timer_screen_test.dart`, `schedule_screen_test.dart`, `test/features/roadmap/roadmap_screen_test.dart`, `test/features/profile/equipment_screen_test.dart`

**Interfaces:**
- Produces:
  - `SkillCategory` members, appended after `bank`, in this order and with these colors:
    - `dungCo(fg: Color(0xFFA3C85A), bg: Color(0xFF2F3E17), borderColor: Color(0xFF4C6426))`
    - `nhayBi(fg: Color(0xFFF0904A), bg: Color(0xFF4A2A12), borderColor: Color(0xFF7A4620))`
    - `matXe(fg: Color(0xFFB4BCCB), bg: Color(0xFF2E333D), borderColor: Color(0xFF4A5262))`
  - `bool get isAdvanced`: true exactly for `dungCo`, `nhayBi`, `matXe`. The doc comment says "nhóm nâng cao (spec 2026-10-29 §3)".
  - `Vi.skill`: `dungCo` → `'Dựng cơ'`, `nhayBi` → `'Nhảy bi'`, `matXe` → `'Mát xê'`.
  - `coachTopicOf` returns `null` for the three new groups.
  - `PlayerIntelligence.inScope(SkillCategory c) => !c.isAdvanced || categories[c]!.sessionCount > 0` (★6).
  - `PracticeFacts.inScope(SkillCategory c)` delegates to `intelligence.inScope(c)`.
  - `newcomerOrder` gains `dungCo, nhayBi, matXe` at the end. Its comment gains "Ba nhóm nâng cao đứng cuối và chỉ được xét khi đã có buổi tập (spec 2026-10-29 §3)." `compareWeakness` keeps working because every group now has an index.
- Behavior:
  - `computePlayerIntelligence`: `buWeak` adds `pi.inScope(cat)` to its condition. `weak` (mastery-based) needs no change because it already needs data.
  - `pickCategoryForToday`: rule 2 counts only in-scope groups, rule 5 skips groups that are not in scope, and rule 7 iterates in-scope groups only (`oldest` starts at the first in-scope group). Rules 1, 3, 4 and 6 are unchanged.
  - `_weakGroups`: `facts.inScope(c) && !facts.atLeastStrong(c)`.
  - `_tournament` `below`: `!facts.atLeastStrong(c) && (facts.inScope(c) || (result != null && (lostByCategory(result).byCategory[c] ?? 0) > 0))`.
  - `prompt.mjs` category line ends `…, bank là Cân bi, dungCo là Dựng cơ, nhayBi là Nhảy bi, matXe là Mát xê.` On the line about "A băng … Cân bi … hai nhóm khác nhau", append the sentence ` Nhảy bi và Mát xê cũng là hai nhóm khác nhau.`

- [ ] **Step 1: Write the failing tests.**

```dart
// skill_category_test.dart
double contrast(Color a, Color b) { final x = a.computeLuminance(), y = b.computeLuminance(); return (max(x, y) + 0.05) / (min(x, y) + 0.05); }
test('có đúng 9 nhóm, ba nhóm nâng cao đứng cuối', () {
  expect(SkillCategory.values.length, 9);
  expect(SkillCategory.values.where((c) => c.isAdvanced), [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe]);
});
// tên: thêm expect(Vi.skill(SkillCategory.dungCo), 'Dựng cơ'); nhayBi 'Nhảy bi'; matXe 'Mát xê'
// màu: colors.length == 9; mỗi nhóm nâng cao contrast(fg, bg) >= 4.5

// coach_topic_test.dart: thêm expect(coachTopicOf(SkillCategory.dungCo), isNull) (cả ba); hasLength(4) giữ nguyên

// pick_category_test.dart (bài nâng cao kiểu target: Drill(id: 'x1', cat: dungCo, level: 1, unit: 'u', goal: 'g', steps: const [], target: 3))
test('thứ tự làm quen phủ chín nhóm, ba nhóm nâng cao đứng cuối', () {
  expect(newcomerOrder.toSet(), SkillCategory.values.toSet());
  expect(newcomerOrder.skip(6), [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe]);
});
test('đã tập đủ sáu nhóm cơ bản, chưa tập nhóm nâng cao: luân phiên không chọn nhóm nâng cao', …); // reason rotation, cat chỉ trong sáu nhóm
test('sắp mất streak: không chọn nhóm nâng cao chưa tập', …);     // reason streakAtRisk, cat không isAdvanced
test('có một buổi Dựng cơ lâu nhất: luân phiên chọn Dựng cơ', …);  // reason rotation, cat dungCo

// player_intelligence_test.dart
// cập nhật: expect(pi.weak, SkillCategory.values.where((c) => !c.isAdvanced));
test('nhóm nâng cao chưa có buổi: không trong phạm vi, không yếu', () { /* logs rỗng → pi.inScope(dungCo) false, inScope(aiming) true */ });
test('ba buổi Nhảy bi kém: Nhảy bi vào danh sách yếu như mọi nhóm', () { /* 3 log score 0/target 3 → weak chứa nhayBi, weakSources drills */ });

// roadmap (roadmap_fixtures.dart thêm: final advancedDrills = [_targetDrill('j1', SkillCategory.nhayBi, 1), _targetDrill('c1', SkillCategory.dungCo, 1)]; target 3)
test('Chuẩn bị giải không có BU: nhóm nâng cao chưa tập không thành bước', …); // drills: [...roadmapDrills, ...advancedDrills], không bước nào có category isAdvanced
test('một buổi Nhảy bi: Nhảy bi thành bước Chưa đo', …);                    // bước nhayBi reason Unmeasured(1)
test('Lên hạng chưa có BU: nhóm nâng cao chưa tập không thành bước', …);     // trong roadmap_len_hang_test.dart

// widget: mỗi bộ chọn có đủ ba tên mới (Vi.skill của dungCo, nhayBi, matXe)
// training_screen_test: ba FilterChip; timer_screen_test & schedule_screen_test: mở dropdown thấy ba mục;
// roadmap_screen_test: chạm Thuần thục kỹ năng thấy ba ActionChip; equipment_screen_test: hộp thoại thêm cơ có ba FilterChip
```

Update the existing enumerating tests: in `coach_context_test.dart` the `skills` keys become `['aiming', 'position', 'breakShot', 'safety', 'kick', 'bank', 'dungCo', 'nhayBi', 'matXe']`. In `seed_test.dart`, "mỗi nhóm kỹ năng có ít nhất một bài tập" loops over `SkillCategory.values.where((c) => !c.isAdvanced)` with the comment `// Nhóm nâng cao có bài từ Task 5 của plan 2026-10-29`. In `old_build_compat_test.dart`, set `unknownCategory = 'nhomTuongLai'`.

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain test/core test/features/training test/features/roadmap test/features/profile test/data/seed_test.dart test/data/sync/old_build_compat_test.dart`. Expected: compile errors for the new members first, then assertion failures.

- [ ] **Step 3: Implement** the Interfaces and Behavior above. Fix any other compile error from an exhaustive `switch` over `SkillCategory` (grep `SkillCategory.bank` in `lib/`) the same way: the new groups take the "no data / null" branch.

- [ ] **Step 4: Run the whole Dart suite and the server tests.** Run the full `$ENV $FLUTTER test` in the background with Monitor (Global Constraints). Expected: green. A failure that enumerates groups is fixed by updating the expected list, and the commit names that test. Then run `$ENV $FLUTTER analyze`, and in `server/coach-chat` run `$ENV npm ci --no-audit --no-fund` (only if `node_modules` is missing) and `$ENV npm test`. Expected: all pass.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: thêm Dựng cơ, Nhảy bi, Mát xê vào SkillCategory; nhóm nâng cao chưa có buổi không vào gợi ý, danh sách yếu hay Lộ trình tự động`, plus the trailer.

---

### Task 4: Two-field category sync and Directus fields

**Files:**
- Create: `lib/data/database/category_compat.dart`
- Modify: `lib/data/sync/practice_sync.dart` (`timerSessionRemoteFields`, `scheduleSlotRemoteFields`, the timer and slot push bodies and pulls)
- Modify: `lib/data/sync/cue_equipment_sync.dart` (`cueEquipmentRemoteFields`, `_toRemote`, `_fromRemote`)
- Modify: `lib/data/database/roadmap_converters.dart` (`remoteGoalFields`, `toRemoteGoal`, `goalFromRemote`)
- Modify: `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs`
- Test: `test/data/database/category_compat_test.dart` (create), `test/data/sync/practice_sync_test.dart`, `test/data/sync/cue_equipment_sync_test.dart`, `test/data/database/roadmap_converters_test.dart`, `test/data/sync/old_build_compat_test.dart`

**Interfaces:**
- Produces (`category_compat.dart`):
  - `const legacyCategoryNames = <String>{'aiming', 'position', 'breakShot', 'safety', 'kick', 'bank'};` A literal, never derived from the enum. Doc comment: "Sáu tên mọi bản đã phát hành đọc được. Đóng băng: không bao giờ thêm tên vào đây."
  - `({String? legacy, String? ext}) splitCategoryName(String? name)`: a legacy name goes to `legacy`, any other non-null name goes to `ext`.
  - `String? joinCategoryName(String? legacy, Object? ext)`: returns `legacy` when it is non-null. Otherwise it returns `ext` when `ext` names a `SkillCategory` this build knows, else null. It throws `FormatException('Nhóm kỹ năng mở rộng từ server không hợp lệ')` when `ext` is neither null nor a `String`.
  - `({List<String> legacy, List<String> ext}) splitCategoryNames(Iterable<String> names)`
  - `List<String> joinCategoryNames(List<String> legacy, Object? ext)`: the union in `SkillCategory` order, without duplicates, with unknown `ext` names dropped. It throws the same `FormatException` when `ext` is neither null nor a `List` of `String`.
- Wire format (★12):
  - `timer_sessions` and `schedule_slots`: the body sends `'cat': split.legacy` and `'cat_ext': split.ext`, and always sends both keys. A pull keeps today's validation of `cat` unchanged, then stores `joinCategoryName(cat, item['cat_ext'])`. The fields constants insert `cat_ext` right after `cat`.
  - `cue_equipment`: the body sends `'skill_categories': split.legacy` and `'skill_categories_ext': split.ext`, with `[]` when empty. A pull keeps today's strict parse of `skill_categories`, then sets skills to the enum values of `joinCategoryNames(legacyNames, item['skill_categories_ext'])`. The fields constant inserts `skill_categories_ext` right after `skill_categories`.
  - `player_goals`: when `r.category` is not in `legacyCategoryNames`, `toRemoteGoal` sends `'kind': null, 'category': null, 'category_ext': r.category`. Otherwise it sends the row as today plus `'category_ext': null`. In `goalFromRemote`, let `ext` be the known category named by `j['category_ext']`. When `kind == null`, the goal is `PlayerGoal(kind: thuanThucKyNang, category: ext, …)` if `goal_id != null && ext != null`, else null. When `kind != null`, `category` is the legacy `category` if non-null, else `ext` when the kind is `thuanThucKyNang`, else null. The legacy `category` keeps today's strict `SkillCategory.values.byName` parse, so the Task 1 test that expects a throw stays green. `remoteGoalFields` gains `,category_ext`.
  - `bootstrap.mjs` adds the fields `nullable('cat_ext', 'string')` to `timer_sessions` and `schedule_slots`, `nullable('skill_categories_ext', 'json')` to `cue_equipment`, and `nullable('category_ext', 'string')` to `player_goals`. Each new field joins the `create` and `update` permission `fields` lists of its collection; `timer_sessions` has `create` only.
  - `verify.mjs` adds a block "Nhóm nâng cao: trường _ext", modeled on the existing `tournament_id` checks. A timer POST with `cat: null, cat_ext: 'dungCo'` reads back the same. A cue POST with `skill_categories_ext: ['nhayBi']` reads back the same. A goal PATCH with `category_ext` set, followed by an old-style PATCH without that key, keeps it. A slot PATCH without `cat_ext` keeps it.

- [ ] **Step 1: Write the failing tests.**

```dart
// category_compat_test.dart
test('sáu tên cũ đóng băng, đúng sáu nhóm đầu của enum', () =>
    expect(legacyCategoryNames, SkillCategory.values.take(6).map((c) => c.name).toSet()));
test('tách và ghép một tên', () {
  expect(splitCategoryName('aiming'), (legacy: 'aiming', ext: null));
  expect(splitCategoryName('dungCo'), (legacy: null, ext: 'dungCo'));
  expect(splitCategoryName(null), (legacy: null, ext: null));
  expect(joinCategoryName('aiming', 'dungCo'), 'aiming');     // bản cũ sửa sau: trường cũ thắng
  expect(joinCategoryName(null, 'nhayBi'), 'nhayBi');
  expect(joinCategoryName(null, 'nhomTuongLai'), isNull);     // bản sau thêm nhóm: bỏ qua, không ném
  expect(() => joinCategoryName(null, 3), throwsFormatException);
});
test('tách và ghép danh sách', () {
  final s = splitCategoryNames(['nhayBi', 'aiming']); // record chứa List: so từng trường, List == là so danh tính
  expect(s.legacy, ['aiming']);
  expect(s.ext, ['nhayBi']);
  expect(joinCategoryNames(['position'], ['nhayBi', 'nhomTuongLai', 'position']), ['position', 'nhayBi']);
  expect(joinCategoryNames(['aiming'], null), ['aiming']);
  expect(() => joinCategoryNames(['aiming'], 'x'), throwsFormatException);
});

// practice_sync_test.dart
test('buổi tập Dựng cơ lên với cat null, cat_ext dungCo; Ngắm bi lên với cat aiming, cat_ext null', …);
test('kéo buổi tập cat null, cat_ext nhayBi: lưu nhóm Nhảy bi', …);
test('lịch Dựng cơ lên với cat null, cat_ext dungCo', …);
test('bản cũ đổi lịch thành Ngắm bi (cat aiming, cat_ext vẫn dungCo): máy mới lưu Ngắm bi', …);
test('xin trường cat_ext khi kéo buổi tập và lịch', …); // queryParameters['fields'] chứa 'cat_ext'

// cue_equipment_sync_test.dart
test('cơ có Ngắm bi và Nhảy bi: skill_categories [aiming], skill_categories_ext [nhayBi]', …);
test('bản cũ sửa kỹ năng thành [position], ext vẫn [nhayBi]: máy mới có [position, nhayBi]', …);

// roadmap_converters_test.dart
test('mục tiêu Thuần thục Nhảy bi: kind, category rỗng; category_ext nhayBi; đọc lại đúng mục tiêu', …);
test('bản cũ đặt Lên hạng sau đó (category_ext còn sót): đọc ra Lên hạng, không nhóm', …);
test('bản cũ bỏ mục tiêu (kind, goal_id rỗng, category_ext còn sót): không có mục tiêu', …);
test('bản cũ chọn Thuần thục Ngắm bi (category_ext còn sót): đọc ra Ngắm bi', …);

// old_build_compat_test.dart
test('máy mới gửi gì thì trường cũ cũng chỉ chứa tên bản cũ đọc được', () async {
  // với từng c trong SkillCategory.values: tạo buổi tập, lịch, cơ (skills [c]), mục tiêu Thuần thục c;
  // đồng bộ; với mọi body đã gửi: cat / category ∈ legacyCategoryNames ∪ {null},
  // mọi phần tử skill_categories ∈ legacyCategoryNames, kind == null khi c.isAdvanced
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data`. Expected: compile errors, then failures in the new tests.

- [ ] **Step 3: Implement** `category_compat.dart` and the wire format above. Then edit `bootstrap.mjs` and `verify.mjs`.

- [ ] **Step 4: Run the tests and checks.** Run `$ENV $FLUTTER test test/data` and `$ENV $FLUTTER analyze`. Expected: PASS, including every Task 1 test and the existing "PATCH chỉ gửi khoá nằm trong danh sách trường" tests. Then run `$ENV node --check deploy/directus/bootstrap.mjs` and `$ENV node --check deploy/directus/verify.mjs`. Expected: exit 0.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: đồng bộ hai trường — trường cũ chỉ chở sáu tên bản cũ đọc được, tên mới đi trong cat_ext / skill_categories_ext / category_ext; thêm trường và quyền Directus`, plus the trailer.

---

### Task 5: Nine BU drills in the seed

**Files:**
- Modify: `lib/data/seed/seed_drills.dart`
- Test: `test/data/seed_test.dart`, `test/data/database/upsert_seed_test.dart`, `test/data/repositories/drift_repositories_test.dart`, `test/core/bootstrap_test.dart`, `test/data/sync/old_build_compat_test.dart` (`unknownDrillId = 'd99'`)

**Interfaces:**
- Consumes: `drillProvenance` and `DrillProvenance.shots/level` (Task 2), `Vi.skill`, `Vi.buVersionName`, `Vi.buDrillSetup`.
- Produces: `final seedDrills = <Drill>[..._baseDrills, …nine drills d11–d19]`. The ten existing drills move unchanged into `const _baseDrills = <Drill>[…]`. Each new drill is built by `Drill _buShotDrill(String id, SkillCategory cat, {required String goal, required List<String> Function(int shots) steps})`, where `p = drillProvenance[id]!` and `n = p.shots`:
  - `name: '${Vi.skill(cat)} — bậc ${Vi.buVersionName(p.version)}'`
  - `level: p.level`, `unit: 'cú thành công / $n'`, `target: n`
  - `steps: [Vi.buDrillSetup(p.buDrillId, p.version), ...steps(n)]`
- Ids and groups: `d11`–`d13` are `dungCo`, `d14`–`d16` are `nhayBi`, `d17`–`d19` are `matXe`, in Bachelors, Masters, Doctorate order.

**Exact texts.** Transcribe them verbatim. "B/M" means Bachelors and Masters; "D" means Doctorate. The source of each line is given in brackets and is not part of the string.

Dựng cơ (`d11`–`d13`):
- goal: `'Dựng cơ (nâng đuôi cơ) để ăn bi khi bi cái áp sát băng hoặc áp sát bi chướng ngại, không chết cái.'` [spec §1, BU S8]
- steps(n):
  1. `'Bậc này có $n cú, mỗi cú một vị trí bi cái. Xem vị trí từng cú trên sơ đồ BU của bài.'` [BU S8 layouts]
  2. `'Dựng cơ là nâng đuôi cơ lên khi đánh. Ở bài này bi cái luôn áp sát băng hoặc áp sát bi chướng ngại.'` [spec §1, `Vi.buDrillSetup('S8')`]
  3. `'Mỗi cú ăn bi mà không chết cái được 1 điểm. Ghi số cú thành công.'` [BU S8 "without scratching", 1 point each]

Nhảy bi (`d14`–`d16`):
- goal B/M: `'Nhảy bi qua bi chướng ngại rồi ăn bi treo miệng lỗ góc, chỉ dùng nhảy bi.'`. Goal D: `'Nhảy bi qua bi chướng ngại và đưa bi cái vào lỗ góc, chỉ dùng nhảy bi.'` [BU S9]
- steps(n):
  1. `'Đánh $n cú trên cùng bố cục này. Bài này chỉ dùng nhảy bi, không dùng mát xê.'` [spec §4]
  2. `'Ngắm vào điểm nằm giữa tâm bi cái và điểm bi cái chạm nỉ.'` [Tổng hợp mẹo 13.1]
  3. `'Cần nhảy cao và ngắn thì nâng cơ cao; cần nhảy xa hơn thì đánh mạnh hơn và bớt nâng cơ.'` [13.2]
  4. B/M only: `'Cú nhảy bi hay chạm bi mục tiêu dày hơn dự tính, vì bi cái còn đang nảy lúc chạm bi.'` [13.3]
  5. `'Lỗi hay gặp: đâm cơ quá thẳng xuống làm bi cái không nhảy mà trượt cơ; đánh quá mạnh làm mất kiểm soát hướng bi cái sau khi bi tiếp đất. Cách sửa: tập nâng cơ từ thấp lên cao dần, tìm độ nâng thấp nhất vẫn đủ để bi cái nhảy qua bi chướng ngại.'` [Từ điển §17]
  6. `'Nhiều giải giới hạn hoặc cấm cơ nhảy chuyên dụng; xem luật trước khi dùng.'` [Từ điển §17]
  7. B/M: `'Mỗi cú ăn được bi treo miệng lỗ được 1 điểm; chết cái vẫn tính. Ghi số cú thành công.'`. D: `'Mỗi cú bi cái vào lỗ góc mà không chạm bi chướng ngại được 1 điểm. Ghi số cú thành công.'` [`Vi.buDrillScoring('S9', v)`]

Mát xê (`d17`–`d19`):
- goal B/M: `'Mát xê cho bi cái đi cong vòng qua bi chướng ngại rồi ăn bi treo miệng lỗ góc, chỉ dùng mát xê.'`. Goal D: `'Mát xê cho bi cái đi cong vòng qua bi chướng ngại và vào lỗ góc, chỉ dùng mát xê.'` [BU S9]
- steps(n):
  1. `'Đánh $n cú trên cùng bố cục này. Bài này chỉ dùng mát xê, không dùng nhảy bi.'` [spec §4]
  2. `'Mát xê làm bi cái đi theo đường cong, né được bi chướng ngại mà không cần chạm băng; bi cái còn cong tiếp được sau khi chạm bi.'` [Từ điển §18 mô tả; Tổng hợp mẹo 13.4]
  3. `'Ngắm điểm chạm lệch tâm bi cái về phía muốn bi cái cong tới.'` [Từ điển §18, bước 2, không con số; ★8]
  4. `'Lỗi hay gặp: nâng cơ quá ít hoặc quá nhiều làm bi cái đi sai đường cong; đẩy cơ quá chậm làm bi cái không đủ xoáy để cong rõ. Cách sửa: bắt đầu với mát xê nhẹ, nâng cơ ít, rồi mới tăng dần.'` [Từ điển §18]
  5. The same scoring step as Nhảy bi step 7, B/M or D.

- [ ] **Step 1: Write the failing tests** in `seed_test.dart`, then update the counts in the three other files (10 → 19).

```dart
test('có đúng 19 bài tập và 6 bài kiến thức', () { expect(seedDrills.length, 19); expect(seedKnowledge.length, 6); });
test('mỗi nhóm kỹ năng có ít nhất một bài tập', () { /* trở lại SkillCategory.values, bỏ dòng chú thích của Task 3 */ });
test('bài mới: nguồn, cấp, số cú, bước 1 đều suy từ bảng nguồn và BU', () {
  for (final d in seedDrills) {
    final p = drillProvenanceOf(d.id);
    if (p == null) { expect(int.parse(d.id.substring(1)), lessThanOrEqualTo(10)); continue; }
    expect(d.cat.isAdvanced, isTrue);
    expect(d.target, drillFor(p.buDrillId, p.version).attemptCount);
    if (p.buDrillId == 'S8') expect(d.target, layoutsFor('S8', p.version).length);
    expect(d.level, p.version.index + 1);
    expect(d.passThreshold, isNull);
    expect(d.name, '${Vi.skill(d.cat)} — bậc ${Vi.buVersionName(p.version)}');
    expect(d.unit, 'cú thành công / ${d.target}');
    expect(d.steps.first, Vi.buDrillSetup(p.buDrillId, p.version));
  }
  expect([for (final d in seedDrills) if (drillProvenanceOf(d.id) != null) d.id],
      ['d11', 'd12', 'd13', 'd14', 'd15', 'd16', 'd17', 'd18', 'd19']);
  expect([for (final id in ['d11', 'd14', 'd17']) seedDrills.firstWhere((d) => d.id == id).cat],
      [SkillCategory.dungCo, SkillCategory.nhayBi, SkillCategory.matXe]);
});
test('số cú không viết tay: file seed chỉ có bốn target số cũ', () {
  final src = File('lib/data/seed/seed_drills.dart').readAsStringSync();
  expect(RegExp(r'target:\s*\d').allMatches(src).length, 4); // d4, d5, d6, d10
});
test('bài nâng cao không có từ kỹ thuật tiếng Anh', () {
  const english = ['Jump', 'jump', 'Massé', 'Masse', 'masse', 'Scratch', 'scratch', 'miscue', 'Elevated'];
  for (final d in seedDrills.where((d) => d.cat.isAdvanced)) {
    final text = '${d.name} ${d.goal} ${d.steps.join(' ')}';
    for (final w in english) { expect(text.contains(w), isFalse, reason: '${d.id}: $w'); }
  }
});
test('bậc Doctorate của S9 giữ yêu cầu đưa bi cái vào lỗ góc', () {
  for (final id in ['d16', 'd19']) { expect(seedDrills.firstWhere((d) => d.id == id).steps.last, contains('bi cái vào lỗ góc')); }
});
```

The existing banned-terms test already covers the new drills. Keep it unchanged, and it must pass.

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/seed_test.dart`. Expected: FAIL (19 vs 10).

- [ ] **Step 3: Implement** `_baseDrills`, `_buShotDrill` and the nine drills with the exact texts above. In `old_build_compat_test.dart`, set `unknownDrillId = 'd99'`.

- [ ] **Step 4: Run the tests.** Run `$ENV $FLUTTER test test/data test/core/bootstrap_test.dart test/architecture_test.dart test/domain` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: 9 bài d11–d19 theo bố cục BU S8/S9, số cú và cấp suy từ phiếu điểm BU`, plus the trailer.

---

### Task 6: BU S8 maps to Dựng cơ

**Files:**
- Modify: `lib/domain/roadmap/bu_category_map.dart` (`'S8': SkillCategory.dungCo`, doc comment), plus comments in `lib/domain/roadmap/bu_gap.dart`, `lib/domain/roadmap/roadmap.dart` and `roadmap_builder.dart` that say "S8/S9", which now say "S9"
- Test: `test/domain/roadmap/bu_gap_test.dart`, `test/domain/roadmap/roadmap_len_hang_test.dart`, `test/domain/roadmap/roadmap_other_goals_test.dart`, `test/domain/player_intelligence_test.dart`

**Interfaces:**
- Produces: `buDrillCategory['S8'] == SkillCategory.dungCo`, `buDrillCategory['S9'] == null`. The doc comment becomes: "S8 (Dựng cơ) nối nhóm Dựng cơ (spec 2026-10-29 §5). S9 chấm nhảy bi **hoặc** mát xê nên không cho biết người chơi yếu kỹ thuật nào: không nối nhóm."

- [ ] **Step 1: Update and add the tests.**

```dart
// bu_gap_test.dart
// bảng: 'S8': SkillCategory.dungCo, 'S9': null
test('cộng dồn theo nhóm; S8 vào Dựng cơ, S9 tính riêng', () {
  // lost {'F1': 5, 'F3': 4, 'F5': 3, 'S5': 6, 'S8': 2, 'S9': 1, 'S10': 0}
  expect(lost.byCategory, {SkillCategory.aiming: 5, SkillCategory.position: 7, SkillCategory.safety: 6, SkillCategory.dungCo: 2});
  expect(lost.unmapped, 1);
  expect(lost.unmappedIds, ['S9']);
  expect(lostDrillsIn(r, SkillCategory.dungCo), ['S8']);
});
// buCategoryPercent: S8 Masters mất hết 5 → expect(p[SkillCategory.dungCo], 0); S9 vẫn không tính

// roadmap_len_hang_test.dart — sửa 'D 120 → C cần 20':
expect(r.steps.map((s) => s.category), [SkillCategory.position, SkillCategory.safety, SkillCategory.aiming, SkillCategory.dungCo, null]);
expect(r.steps[3].reason, isA<LostBuPoints>().having((x) => x.drillIds, 'drillIds', ['S8']));
test('chỉ mất ở S9: bước Tập lại S9 trên bàn BU', …); // buDrillIds ['S9']

// roadmap_other_goals_test.dart
test('Chuẩn bị giải có BU mất ở S8, chưa tập Dựng cơ: có bước Dựng cơ theo điểm mất', …); // LostBuPoints(points, ['S8'])

// player_intelligence_test.dart
test('BU yếu S8, chưa có buổi Dựng cơ: không yếu; có một buổi: yếu theo BU', () {
  // latestBu với S8 mất hết → pi.buPercent[dungCo] == 0, pi.weak không chứa dungCo
  // thêm một log Dựng cơ (mastery vẫn null) → pi.weak chứa dungCo, weakSources[dungCo] == WeakSource.bu
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/roadmap test/domain/player_intelligence_test.dart`. Expected: FAIL on the S8 assertions.

- [ ] **Step 3: Implement.** Change the map entry and the comments.

- [ ] **Step 4: Run the tests.** Run `$ENV $FLUTTER test test/domain test/core/strings` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: BU S8 nối nhóm Dựng cơ; S9 vẫn không nối nhóm`, plus the trailer.

---

### Task 7: Drill detail sources, warning, BU diagrams and the score check

**Files:**
- Modify: `lib/features/training/presentation/drill_detail_screen.dart`, `lib/features/training/presentation/drill_session_screen.dart`
- Modify: `lib/features/rank/presentation/layout_gallery_screen.dart`, `lib/core/router/app_router.dart` (the `Routes.rankLayouts` builder), `lib/core/router/routes.dart`
- Modify: `lib/core/strings/vi.dart`
- Test: `test/features/training/drill_detail_screen_test.dart`, `test/features/training/drill_session_screen_test.dart`, `test/features/rank/layout_gallery_screen_test.dart` (create)

**Interfaces:**
- Consumes: `drillProvenanceOf`, `checkShotScore`, `ShotScoreError` (Task 2), `Vi.shotScoreError` (Task 2), `layoutsFor`.
- Produces:
  - `Routes.rankLayoutsOf(String drillId, ExamIIVersion v) => '$rankLayouts?drill=$drillId&v=${v.name}'`
  - `LayoutGalleryScreen({int? index, String? drillId, ExamIIVersion? version, super.key})`. When `drillId` is non-null, it lists `layoutsFor(drillId, version)` numbered `k / n` within that subset. When that list is empty or `version` is null, it shows `Vi.buLayoutsEnd`. The router passes `drill` and `ExamIIVersion.values.asNameMap()[v]` from the query.
  - Vi strings (★8, ★9):
    - `static String drillSource(SkillCategory cat, DrillProvenance p)`: `'Nguồn: Billiard University Exam II, ${p.buDrillId}, bậc ${buVersionName(p.version)}'` plus a tail by group:
      - `dungCo`: `'. Cảnh báo theo Từ điển kiến thức Billiard Pool, mục 17 và 18.'`
      - `nhayBi`: `'; mẹo theo Dr. Dave Alciatore; lỗi hay gặp và cảnh báo theo Từ điển kiến thức Billiard Pool, mục 17.'`
      - `matXe`: `'; mẹo theo Dr. Dave Alciatore; cách ngắm, lỗi hay gặp và cảnh báo theo Từ điển kiến thức Billiard Pool, mục 18.'`
      - any other group: `'.'`
    - `static const drillClothWarning = 'Nên luyện trên bàn tập hoặc nỉ cũ, dễ làm rách nỉ.';`
    - `static const drillNoSourcedTips = 'Chưa có mẹo kỹ thuật có nguồn cho dựng cơ.';`
    - `static const drillOpenBuLayouts = 'Xem sơ đồ BU';`
    - `static String sessionScoreHintShots(int n) => 'Từ 0 đến $n';`
- Detail layout: directly after the steps list, before "Đọc bài liên quan":
  - When `drill.cat == SkillCategory.dungCo`, show `Text(Vi.drillNoSourcedTips)`.
  - When `drill.cat.isAdvanced`, show a `PcCard` with `Icons.warning_amber_outlined` and `Text(Vi.drillClothWarning)`.
  - When `drillProvenanceOf(drill.id)` is a non-null `p`, show `Text(Vi.drillSource(drill.cat, p), style: bodySmall)` and an `OutlinedButton` labeled `Vi.drillOpenBuLayouts` that calls `context.push(Routes.rankLayoutsOf(p.buDrillId, p.version))`.
  - Every text wraps. Nothing uses intrinsic sizing.
- Session screen: for a provenance drill, the score hint is `Vi.sessionScoreHintShots(drill.target!.toInt())`. After the existing checks pass, the validator returns `Vi.shotScoreError(e)` when `checkShotScore(drill, parsed)` returns an error `e`.

- [ ] **Step 1: Write the failing tests.** Open drills with `drills: seedDrills` (after Task 5).

```dart
testWidgets('bài Dựng cơ: nguồn, cảnh báo nỉ, chưa có mẹo, nút sơ đồ BU', (tester) async {
  await openDrill(tester, 'd12', drills: seedDrills);
  expect(find.text('Nguồn: Billiard University Exam II, S8, bậc Masters. Cảnh báo theo Từ điển kiến thức Billiard Pool, mục 17 và 18.'), findsOneWidget);
  expect(find.text(Vi.drillClothWarning), findsOneWidget);
  expect(find.text(Vi.drillNoSourcedTips), findsOneWidget);
  await tester.tap(find.text(Vi.drillOpenBuLayouts)); await tester.pumpAndSettle();
  expect(find.byType(LayoutGalleryScreen), findsOneWidget);
});
testWidgets('bài Nhảy bi: nguồn có Dr. Dave, có cảnh báo, không có dòng chưa có mẹo', …); // d14, bậc Bachelors
testWidgets('bài cũ d1: không có dòng nguồn, cảnh báo hay nút sơ đồ', …);
testWidgets('360×640 chữ lớn: bài Nhảy bi Bachelors (dài nhất) không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 2.0); // app giới hạn 1.5
  await openDrill(tester, 'd14', drills: seedDrills, tall: false);
  expect(tester.takeException(), isNull); await scrollThroughAll(tester); expect(tester.takeException(), isNull);
});
// drill_session_screen_test.dart
testWidgets('bài BU 3 cú: 4 và 2.5 bị từ chối, 3 lưu được', …); // Vi.shotScoreError(aboveShots / notWhole); gợi ý 'Từ 0 đến 3'
// layout_gallery_screen_test.dart
testWidgets('S8 Masters: đúng 5 sơ đồ, đánh số 1/5…5/5', …);   // find.textContaining('Sơ đồ 1 / 5') … 'Sơ đồ 5 / 5', không có '/ 6'
testWidgets('S9 Doctorate: một sơ đồ', …);                       // 'Sơ đồ 1 / 1'
testWidgets('drill hoặc bậc lạ: Hết sơ đồ.', …);                // drillId 'S8', version null → Vi.buLayoutsEnd; drillId 'X1' → Vi.buLayoutsEnd
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/features/training/drill_detail_screen_test.dart test/features/training/drill_session_screen_test.dart test/features/rank/layout_gallery_screen_test.dart`. Expected: FAIL or compile errors.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run the three files, then `test/architecture_test.dart`, `test/core/router` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: chi tiết bài hiện nguồn, cảnh báo nỉ và sơ đồ BU đúng bậc; điểm theo cú phải là số nguyên không quá số cú`, plus the trailer.

---

### Task 8: Roadmap S9 hint opens the Thuần thục picker

**Files:**
- Modify: `lib/features/roadmap/presentation/step_tile.dart`, `roadmap_screen.dart`, `goal_picker.dart`, `lib/core/strings/vi.dart`
- Test: `test/features/roadmap/step_tile_test.dart`, `test/features/roadmap/roadmap_screen_test.dart`

**Interfaces:**
- Produces:
  - `static const roadmapS9Hint = 'Bài S9 chấm nhảy bi hoặc mát xê: chọn nhóm Nhảy bi hoặc Mát xê để luyện';` (spec §5, verbatim)
  - `static const roadmapS9Pick = 'Chọn nhóm để luyện';`
  - `StepTile({…, VoidCallback? onPickSkill})`: when `step.kind == StepKind.buLe && step.buDrillIds.contains('S9')`, it shows `Text(Vi.roadmapS9Hint, style: bodySmall)` and, when `onPickSkill != null`, a `TextButton(Vi.roadmapS9Pick)` that calls it.
  - `RoadmapView({…, VoidCallback? onPickSkill})` passes it to every `StepTile`.
  - `GoalPicker({…, bool openSkills = false})`: `_pickingCategory` starts as `openSkills`.
  - `_RoadmapScreenState` gains `bool _openSkills = false`. `onPickSkill` sets `_changing = true; _openSkills = true`. Leaving the picker (picked or cancel) resets both. It builds `GoalPicker(openSkills: _openSkills, …)`.

- [ ] **Step 1: Write the failing tests.**

```dart
// step_tile_test.dart
testWidgets('bước Tập lại S9: có dòng hướng dẫn và nút chọn nhóm', …); // RoadmapStep(kind: buLe, buDrillIds: ['S9'], …), onPickSkill được gọi khi chạm
testWidgets('bước nhóm thường: không có dòng S9', …);
// roadmap_screen_test.dart
testWidgets('Lên hạng mất điểm ở S9: chạm Chọn nhóm để luyện mở bộ chọn với các nhóm đã mở sẵn', (tester) async {
  // db: hạng verified D, BU hoàn tất chỉ mất ở S9 đủ để bước buLe được chọn, mục tiêu Lên hạng
  // cuộn tới Vi.roadmapS9Pick, chạm → find.text(Vi.goalPickTitle) và find.text(Vi.skill(SkillCategory.nhayBi)) đều findsOneWidget
  // chạm Nhảy bi → playerGoalRows.kind == 'thuanThucKyNang', category == 'nhayBi'
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/features/roadmap`. Expected: FAIL.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run `$ENV $FLUTTER test test/features/roadmap test/architecture_test.dart` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Nhóm bài nâng cao: bước S9 của Lộ trình có dòng hướng dẫn mở bộ chọn Thuần thục`, plus the trailer.

---

### Task 9: Live E2E script for the new groups

**Files:**
- Create: `tool/e2e/drill_groups.mjs`

**Interfaces:**
- Consumes: `launch`, `sleep` (`tool/e2e/cdp.mjs`) and `registerThrowaway`, `deleteUserByEmail` (`tool/e2e/throwaway_user.mjs`). It follows the structure of `tool/e2e/tournament.mjs`: the `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1` guard, `check()` with screenshots, `scrollUntilText`, and user cleanup in `finally`.
- Steps the script runs:
  1. Register a throwaway user.
  2. `/training`: tap the "Dựng cơ" filter chip and see "Dựng cơ — bậc Bachelors".
  3. `/training/drills/d11`: the page text includes "Nguồn: Billiard University Exam II, S8, bậc Bachelors", `Vi.drillClothWarning` and `Vi.drillNoSourcedTips`. Tap "Xem sơ đồ BU" and see "Sơ đồ 1 / 3" and "Sơ đồ 3 / 3".
  4. `/training/drills/d11/session`: enter score 3, save, then reload `/stats` and see the "Dựng cơ" row with one scored session.
  5. `/training/timer`: choose "Dựng cơ", start, wait about 5 s, stop and save (labels from `timer_screen.dart` / `Vi.timer*`).
  6. Directus as admin, waiting up to 30 s: a `drill_logs` row of this user with `drill_id: 'd11'` and `score: 3`, and a `timer_sessions` row with `cat: null` and `cat_ext: 'dungCo'`.
  7. Exit code 1 when any check failed.

- [ ] **Step 1: Write the script.**
- [ ] **Step 2: Check it.** Run `$ENV node --check tool/e2e/drill_groups.mjs`. Expected: exit 0. Do **not** run it; it hits prod (controller step ★13).
- [ ] **Step 3: Commit.** Message: `Nhóm bài nâng cao: E2E thật cho bài Dựng cơ (nguồn, sơ đồ, Thống kê, drill_logs, cat_ext trên Directus)`, plus the trailer.

---

### Task 10: Docs and full verification

**Files:**
- Modify: `PRD_PoolCoachAI.md`, `tong_hop_y_tuong_app_huan_luyen_bi_a_9ball.md`

**Edits** (locate by text):
- PRD, in the paragraph starting "Đơn vị thực hành chính.", replace the sentence "Danh sách bài tập chia theo **5 nhóm kỹ năng**: Ngắm bi, Đi bi/Vị trí, Giao bóng, Phòng thủ, Bi băng *(…)*." with: "Danh sách bài tập chia theo **9 nhóm kỹ năng**: sáu nhóm cơ bản Ngắm bi, Điều bi / Vị trí, Phá, Phòng thủ, A băng (kick), Cân bi (bank), và ba nhóm nâng cao Dựng cơ, Nhảy bi, Mát xê (spec 2026-10-29; mỗi nhóm ba bài theo bố cục BU S8/S9; app không tự gợi ý nhóm nâng cao khi người chơi chưa tập)."
- PRD, in the Lộ trình paragraph, replace "(qua bảng nối 18 bài BU vào 6 nhóm)" with "(qua bảng nối 18 bài BU vào nhóm; S8 vào Dựng cơ, S9 không nối nhóm nào)".
- Ideas doc, decision item 2: replace it with "**Taxonomy chính thức có chín nhóm:** sáu nhóm cơ bản Ngắm bi, Điều bi/Vị trí, Phá, Phòng thủ, A băng (kick), Cân bi (bank), và ba nhóm nâng cao Dựng cơ, Nhảy bi, Mát xê (spec 2026-10-29). Mát xê là kỹ thuật riêng, không gộp với Nhảy bi. Một tài liệu cũ ghi năm nhóm hoặc “Bi băng”; nội dung đó được thay bằng các nhóm này để không gộp nhầm kick với bank."
- Ideas doc, status table, row "Training/Drill": replace "lọc sáu nhóm" with "lọc chín nhóm (ba nhóm nâng cao Dựng cơ, Nhảy bi, Mát xê, mỗi nhóm ba bài theo bố cục BU S8/S9, có dòng nguồn và cảnh báo nỉ)".

- [ ] **Step 1: Make the doc edits.**
- [ ] **Step 2: Run the full suite in the background**, streaming the step and pass/fail counts every minute with Monitor: `$ENV $FLUTTER test`. Then run `$ENV $FLUTTER analyze`, `npm test` in `server/coach-chat` with `$ENV`, and `$ENV node --check` on `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` and `tool/e2e/drill_groups.mjs`. Expected: all green and no analyzer issue.
- [ ] **Step 3: Grep checks.** `git grep -n "Giao bóng\|Bi băng\|Đi bi" -- PRD_PoolCoachAI.md` finds nothing in the edited sentence. `git grep -n "'S8': null" lib` finds nothing.
- [ ] **Step 4: Commit.** Message: `Nhóm bài nâng cao: PRD và tài liệu ý tưởng ghi chín nhóm, S8 vào Dựng cơ`, plus the trailer.
- [ ] **Step 5: Hand the controller these steps (do not do them yourself):** (a) release order ★13: `bootstrap.mjs`, then `verify.mjs` on prod, then the web publish, then `tool/e2e/drill_groups.mjs` and the existing live suite. (b) In the memory file `poolcoachai-vietnamese-billiards-terms.md`, the taxonomy line becomes "`aiming · position · breakShot · safety · kick · bank` + nhóm nâng cao `dungCo` (Dựng cơ) · `nhayBi` (Nhảy bi) · `matXe` (Mát xê), từ 2026-10-29". (c) Tell the owner about ★8 (dictionary aiming line for Mát xê) and ★10 (Phá and Phòng thủ chip contrast below 4.5:1).
