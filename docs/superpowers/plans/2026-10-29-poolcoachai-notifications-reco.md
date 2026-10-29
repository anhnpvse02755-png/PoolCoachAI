# Thông báo gợi ý mới, hộp thông báo, chạm mở đúng màn (P6a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth local notification kind, **Gợi ý tập mới**, sent at 08:00 only when the day's recommendation (the same `computeRecommendation` Home uses) differs from what the player last saw. Add an inbox, **Đã gửi**, that lists delivered notifications for 30 days, with an unread count on the bell. Tapping a notification, or an inbox entry, opens the matching screen. Fix the old "only while the app is open" copy on Android/iOS.

**Architecture:**
- **Domain.** `planNotifications` gains an optional `RecommendationInputs` (the exact inputs of Home's recommendation) and a last-seen pair. For today (if before 08:00) and tomorrow, it calls `inputs.recommendFor(08:00 of that day)` and emits a draft whose text is a `Vi` template filled from that result. A day is skipped when it has no drill or when its (group, drill) pair equals the baseline. The baseline then chains to the next day.
- **Seen pair.** "Seen" is the newer of two records: the pair Home showed while it was the active tab (stored per account in shared_preferences), and the newest recommendation the log says was delivered.
- **Log.** A local Drift table `notification_log_rows` (schema v17) holds what was planned on Android/iOS, or shown on web. The inbox shows only rows whose time has come. Writes are diff-based.
- **Service.** `NotificationService` receives the recommendation source from Riverpod, tagged with the user id. It is kept permanently listened by `startNotifications`, which fixes a pre-existing pause bug (★12).
- **Tap.** The tap payload is `kind|key`. The plugin callback, the launch details and the web `onclick` all feed `NotificationService.setTapHandler`. `NotificationTapListener` maps the tap to a route and calls `router.go`.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod 3.4.3 (no codegen), Drift (SQLite; `NativeDatabase.memory` in tests), go_router 18, flutter_local_notifications 22.3.x, shared_preferences, `package:web` (web platform only), Node 24 (`tool/e2e` CDP scripts).

**Spec:** `docs/superpowers/specs/2026-10-29-poolcoachai-notifications-reco-design.md`

## Global Constraints

- **Workspace.** Work only in the worktree `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\notifications-reco` (branch `feat/notifications-reco`). The Bash cwd resets between calls, so start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/notifications-reco && `.
- **Command prefix.** The shell exports live secrets, so prefix every flutter / dart / node command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN`.
  - Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat` and Dart is `/c/Users/anhnpv/flutter/bin/dart.bat`. Neither is on PATH.
  - Below, `$ENV`, `$FLUTTER` and `$DART` stand for these. Write them out in full when you run them.
- **Generated files.** `*.g.dart` files are gitignored and missing in this fresh worktree.
  - Task 1 Step 1 generates them.
  - Task 3 changes the Drift schema from **v16 to v17**. Rerun `build_runner` there.
- **Finding code.** Line numbers in this plan and in the spec go stale. Locate code by symbol (function, constant, test name), never by line.
- **Task boundaries.**
  - When a task changes an enum, a constructor or a provider that existing tests enumerate or depend on, the same task updates those tests.
  - A task ends with its touched test files and `$ENV $FLUTTER analyze` green.
  - Don't reformat existing files wholesale. Never run `dart format` on a whole file you did not create.
- **Values from the spec.** Use these exactly (spec §3–§5):
  - `recommendationReminderHour = 8`
  - Android channel `recommendation_reminder`
  - payload `'${kind.name}|$key'`
  - table `notification_log_rows` with columns `id, user_id, kind, key, at, title, body, read_at`
  - inbox window 30 days
  - tap targets: Gợi ý mới → drill detail, Lịch tập → `Routes.schedule`, Bảo dưỡng cơ → `Routes.equipment`, Streak → `Routes.training`
- **No fabrication** (spec §3, memory rule).
  - Every recommendation title and body is a `Vi` template filled by `planNotifications` from the `TodayRecommendation` that `computeRecommendation` returns over real data.
  - When there is no drill, nothing is sent.
  - Never write recommendation prose, a drill name or a reason as a literal.
  - Tests derive expected text from `Vi` and from `inputs.recommendFor(...)`. They never hand-write it.
- **UI copy.**
  - All UI copy goes into `Vi`, using exactly the strings this plan gives.
  - No Vietnamese literal may appear in `lib/features/**` or `lib/core/widgets/**` (`test/architecture_test.dart`).
  - Domain notification files may call `Vi`, as `notification_plan.dart` already does, but hold no Vietnamese literal.
- **Mobile target.**
  - Every platform change has native, web and stub variants behind the conditional export in `notification_platform.dart`.
  - `package:web` and `dart:js_interop` appear only in `notification_platform_web.dart`.
- **Riverpod.**
  - Never call `.invalidate(` or `.refresh(` in `lib/` (architecture test).
  - Readiness is `hasValue && !isLoading` (use `gate()` from `lib/core/providers/async_gate.dart`).
  - An async `Notifier.build` uses a per-build `disposed` flag set in `ref.onDispose`, like `NotificationPrefsController`.
  - Data handed to the service carries the user id it belongs to.
- **Test gotchas:**
  1. `container.read(p.future)` hangs silently. Use `container.listen(p, (_, _) {})`, then `pumpEventQueue()`, then `container.read(p)`.
  2. Never write a type on an override list (`<Override>[…]` or `List<Override>` crashes the compiler).
  3. Inside `testWidgets`, `await repo.watchX().first` hangs. Read rows with `db.select(db.table).get()`.
  4. Drift `AppDatabase.forTesting(NativeDatabase.memory())` works inside `flutter test`.
  5. Drift stores `DateTime` as whole seconds, so every fixed clock in tests is a whole second.
  6. A periodic timer owned by a provider stays pending after a widget test and fails it. Timers live in widget `State` and are cancelled in `dispose`.
- **Layout.**
  - The app clamps text scale at 1.5. New UI is tested at 360×640 with text scale 1.5 (`applyScreen`, `scrollThroughAll` in `test/support/layout_sweep.dart`).
  - `/notifications` is a root route (outside the shell), so its list needs no `pcScrollPadding`.
  - No `IntrinsicHeight` / `IntrinsicWidth`: fonts arrive late.
- **Scope.** No Directus or sync change: the log is local only. Never touch `.mcp.json` or the owner's untracked `.md` files.
- **Commits and runs.**
  - One commit per task. Messages are in Vietnamese and end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - No push, PR, deploy or APK.
  - Do **not** run `tool/e2e/*.mjs`. Check them with `node --check` only.
  - A full `flutter test` takes minutes. Run it in the background and stream the step plus the pass/fail counts every minute with Monitor. Never wait silently.

## Review Focus

1. **Account switch while data reloads.** User u1's recommendation must never be planned, shown or logged for u2.
   - The source carries `userId`. The service ignores a source whose `userId` is not the current user. `recommendationSourceProvider` is null while any input is reloading.
   - Tests: Task 2 (`nguồn gợi ý null khi một nguồn đang tải lại`, controller account-switch test), Task 4 (`nguồn của tài khoản khác bị bỏ qua`).
2. **The same recommendation day after day.**
   - A pair that was already delivered, or that the previous planned day already carries, is not sent again.
   - Home seeing a pair again (switching back to the tab) refreshes "seen".
   - Tests: Task 1 (chain), Task 2 (tab return), Task 4 (`đã giao X: ngày mai cùng X không đặt lại`).
3. **The plan changes before 08:00.** Examples: the player logs the recommended drill at 07:30, turns the kind off, or revokes permission.
   - The OS notification is cancelled and its future row disappears from the log. "Đã gửi" never lists something that was not sent.
   - Tests: Task 4.
4. **A tap with a malformed payload, or for a drill that no longer exists.**
   - A malformed payload causes no crash, no navigation and no row change.
   - An unknown drill id opens the drill route, which shows the existing not-found state.
   - Tests: Task 5.
5. **Web tab opened after 08:00, or Home on screen.** The browser must not pop a notification about the recommendation the player is already looking at.
   - Tests: Task 4 (`mở tab sau 08:00: không hiện gợi ý của sáng nay`), Task 2 (Home records the pair).

## Plan's calls

The spec is silent or leaves a choice in the places below, so the plan decides. Each call is marked ★ where it applies.

1. **Enum order.** `recommendation` is the first member of `NotificationKind`. The switch list on the screen follows enum order, and the spec table lists Gợi ý mới first. Nothing persists the index: prefs keys, the log and the payload use `.name`.
2. **"Bỏ qua ngày đã có buổi tập của chính bài được gợi ý"** is already guaranteed. `computeRecommendation` passes the day's logged drills as `excludeDrillIds`, so `recommendFor(D 08:00)` never names a drill logged on day D. The plan adds no second rule. A Task 1 test pins the behavior.
3. **"Thấy lần cuối"** is the newer (by time) of two records:
   - (a) the pair Home showed while it was the **active tab**. Home records it when the tab becomes visible or when the pair changes while visible. Visibility is `TickerMode.valuesOf(context).enabled`; go_router 18 disables tickers on inactive branches.
   - (b) the newest recommendation row in the log whose time has come. A delivered notification counts as seen.
   - Within one plan, tomorrow's baseline is today's planned pair.
4. **Where recommendation data comes from.** The service does not rebuild Home's inputs from Drift. A new `recommendationInputsProvider` holds the gating and BU logic that used to live in `todayRecommendationProvider`, and both Home and the service read it. So "đúng hàm Home dùng" holds by construction, R21 included. `recommendationSourceProvider` bundles user id, inputs and the seen pair, and is null until all three are ready. The service also waits until its log stream has emitted for the user.
5. **Recommendation timing.** `validUntil` is the end of day D. On web a recommendation is shown only when its `at` is after the moment this tab began the current user's session (`_userSince`). Opening the tab after 08:00 therefore never pops a notification about what Home is showing.
6. **Log keys.**
   - The row id is `PlannedNotification.id`, with primary key `{userId, id}`. `kind` is stored by `.name`, and rows with an unknown kind are skipped on read.
   - Every log write deletes the user's rows older than 30 days.
   - The recommendation key is `'${y}-${m}-${d}:${cat.name}:$drillId'`, without zero padding. The drill id is everything after the second `:`.
7. **No permission on Android/iOS** means nothing is scheduled. The service then syncs the log with an empty plan, so no future rows linger.
8. **Diff-based log writes.** `syncPlanned` deletes and inserts only what differs, and a no-op runs no statement. The service watches the log, so an unconditional write would loop.
9. **Badge.**
   - Material `Badge`, with label `'99+'` above 99, hidden at 0.
   - The tooltip carries the count.
   - The bell and the inbox re-evaluate "đã tới giờ" through `PcRebuildAt`, a widget with a one-shot timer to the next due row. A provider-owned periodic timer would break widget tests (gotcha 6).
10. **Inbox.**
    - Section order: permission → **Đã gửi** → Loại thông báo → Sắp tới.
    - An entry is bold when it was unread the first time this screen visit saw it. All such entries are marked read at once, and they stay bold for the rest of the visit.
    - Tapping an entry opens the same route as tapping the notification.
11. **Tap.**
    - A payload that does not parse, or whose recommendation key does not parse, does nothing.
    - A cold-start payload, from `getNotificationAppLaunchDetails`, is buffered in the service until `NotificationTapListener` registers.
    - Navigation is `router.go(route)` in a post-frame callback.
    - Mark-read touches only the current user's rows with `at ≤ now`.
12. **Pre-existing bug (fixed in Task 4).** `startSync` calls `container.read(notificationServiceProvider)`.
    - In Riverpod 3.4.3, `read` is `listen` followed by `close` (`ProviderContainer.read`). The element goes active→inactive, and `onCancel` deactivates its `ref.listen` subscriptions (`element.dart`).
    - As a result the service misses `notificationPrefsProvider` updates until some screen watches it. On Android/iOS, notifications are scheduled only after the Notifications or Equipment screen opens.
    - Fix: `startNotifications(container)` holds `container.listen(notificationServiceProvider, …)` for the life of the app.
    - The other `container.read(...)` calls in `startSync` may share this issue. They are out of scope and reported in Task 8.
13. **Copy (spec §6).** The two stale equipment strings become functions of `inBackground` (`NotificationService.schedulesInBackground`). The Notifications screen shows a background note and the recommendation limit on Android/iOS, and the web note on web. Exact strings are in Task 7.
14. **Logout.** `signOutAndForget` deletes the account's log rows. The seen pair in shared_preferences is keyed per account and kept, like the notification prefs.
15. **E2E.** Headless Chrome cannot wait for a real 08:00. The script shifts the page clock with `Page.addScriptToEvaluateOnNewDocument` and grants permission with `Browser.grantPermissions`. If permission is not granted, it says so and checks only the screens (spec §8).

---

### Task 1: The Gợi ý mới kind in the notification plan

**Files:**
- Modify: `lib/domain/notifications/notification_prefs.dart`, `lib/domain/notifications/notification_plan.dart`, `lib/core/strings/vi.dart`, `lib/data/notifications/local_notifications_scheduler.dart` (`_channelId`)
- Create: `lib/domain/notifications/recommendation_reminder.dart`
- Test: `test/domain/notifications/recommendation_reminder_test.dart` (create), `test/domain/notifications/notification_plan_test.dart` (update), `test/data/notifications/notification_prefs_store_test.dart` (add)

**Interfaces:**
- Consumes: `computeRecommendation`, `TodayRecommendation`, `PickReason` (`lib/domain/recommendation.dart`), `BuResult`, `SkillCategory`, `Vi.pickReason`, `Vi.skill`.
- Produces:
  - `NotificationKind.recommendation`, the first member, documented "Gợi ý tập mới của ngày (spec P6a §3)".
  - `const recommendationReminderHour = 8;` in `notification_prefs.dart`.
  - `NotificationPrefs({this.recommendation = true, …})`, with the field, `isEnabled`, `toggled`, `==` and `hashCode` covering it. The doc changes to "Mặc định bật cả bốn."
  - In `recommendation_reminder.dart` (no Flutter import, no Vietnamese literal):
    - `final class RecommendationInputs { const RecommendationInputs({required List<Drill> drills, required List<DrillLog> logs, required List<KnowledgeArticle> knowledge, required List<TimerSession> timerSessions, required List<ScheduleSlot> schedule, required List<PoolMatch> matches, BuResult? latestBu}); TodayRecommendation recommendFor(DateTime today); }`. `recommendFor` calls `computeRecommendation` with exactly these fields.
    - `final class SeenRecommendation { const SeenRecommendation({required SkillCategory cat, required String drillId, required DateTime at}); bool sameAs(SkillCategory cat, String drillId); }` with value `==` and `hashCode`.
    - `String recommendationKey(DateTime day, SkillCategory cat, String drillId)`, using the format in ★6.
    - `({DateTime day, SkillCategory cat, String drillId})? parseRecommendationKey(String key)`. It returns null on a bad date, an unknown category, an empty drill id or fewer than three parts.
  - `planNotifications({…existing…, RecommendationInputs? recommendation, SeenRecommendation? lastSeenRecommendation, int limit})`. When `prefs.recommendation && recommendation != null`:
    - For `day` in today and tomorrow, `at = DateTime(day.y, day.m, day.d, recommendationReminderHour)`. Skip the day when `!at.isAfter(now)`.
    - `rec = recommendation.recommendFor(at)`. Skip when `rec.drill == null`, and leave the baseline unchanged.
    - Skip when the baseline `sameAs(rec.cat, rec.drill!.id)`.
    - Otherwise add a draft with kind `recommendation`, key `recommendationKey(day, rec.cat, rec.drill!.id)`, `at`, `validUntil` = start of the next day, title `Vi.recommendationReminderTitle` and body `Vi.recommendationReminderBody(rec.drill!.name, rec.cat, Vi.pickReason(rec.reason, Vi.skill(rec.cat), signal: rec.matchSignal))`. Then set the baseline to this pair.
    - The existing doc list gains a bullet for this rule.
  - `Vi`:
    - `notificationKind(recommendation)` → `'Gợi ý tập mới'`
    - `notificationKindHint(recommendation)` → `'Lúc ${recommendationReminderHour.toString().padLeft(2, '0')}:00, khi gợi ý tập của ngày khác với gợi ý bạn thấy lần cuối ở Trang chủ.'`
    - `static const recommendationReminderTitle = 'Có gợi ý tập mới';`
    - `static String recommendationReminderBody(String drillName, SkillCategory cat, String reason) => '${skill(cat)} · $drillName. $reason';`
  - `_channelId(NotificationKind.recommendation)` → `'recommendation_reminder'`.

- [ ] **Step 1: Setup.** Run `$ENV $FLUTTER pub get`, then `$ENV $DART run build_runner build --delete-conflicting-outputs`. Expected: both exit 0.

- [ ] **Step 2: Write the failing tests.** Fixture: `inputs({drills = testDrills, logs = const [], schedule = const []})` builds `RecommendationInputs` with empty knowledge, timer sessions and matches. `testDrills` (`test/support/test_data.dart`) has one aiming drill `d1`, so the newcomer pick is (aiming, d1). Use `now = DateTime(2026, 10, 13, 7)`, a Tuesday. Define `const bankDrill = Drill(id: 'b1', cat: SkillCategory.bank, name: 'Cân bi một băng', level: 1, unit: 'lần / 10', passThreshold: 0.8, goal: 'g', steps: []);`.

```dart
List<PlannedNotification> reco(RecommendationInputs i, {DateTime? at, SeenRecommendation? seen, NotificationPrefs prefs = const NotificationPrefs()}) =>
    planNotifications(cues: const [], slots: const [], streak: noStreak, prefs: prefs, now: at ?? now,
        recommendation: i, lastSeenRecommendation: seen).where((n) => n.kind == NotificationKind.recommendation).toList();

test('trước 08:00: hôm nay và ngày mai lúc 08:00 khi hai ngày khác cặp', () {
  // khung lịch Thứ Tư (day 2) gắn Cân bi → luật 1 đổi nhóm ngày mai; thêm bài cân bi vào drills
  expect(reco(inputs(drills: [...testDrills, bankDrill], schedule: [ScheduleSlot(id: 's', day: 2, time: '19:00', label: 'l', cat: SkillCategory.bank)])).map((n) => n.at),
      [DateTime(2026, 10, 13, 8), DateTime(2026, 10, 14, 8)]);
});
test('sau 08:00: chỉ ngày mai', () { expect(reco(inputs(), at: DateTime(2026, 10, 13, 9)).map((n) => n.at), [DateTime(2026, 10, 14, 8)]); });
test('ngày mai trùng cặp hôm nay: không gửi lại', () { expect(reco(inputs()).map((n) => n.at), [DateTime(2026, 10, 13, 8)]); });
test('trùng cặp thấy lần cuối: không gửi', () {
  final rec = inputs().recommendFor(DateTime(2026, 10, 13, 8));
  expect(reco(inputs(), seen: SeenRecommendation(cat: rec.cat, drillId: rec.drill!.id, at: DateTime(2026, 10, 12, 20))), isEmpty);
});
test('không có bài: không gửi', () { expect(reco(inputs(drills: const [])), isEmpty); });
test('đã tập bài được gợi ý trước 08:00: thông báo hôm nay không nói về bài đó', () {
  final x = inputs().recommendFor(DateTime(2026, 10, 13, 8)).drill!.id;
  final today = reco(inputs(logs: [DrillLog(id: 'l', drillId: x, date: DateTime(2026, 10, 13, 6, 30), score: 1)]), at: DateTime(2026, 10, 13, 7, 30))
      .where((n) => n.at == DateTime(2026, 10, 13, 8));
  expect(today.where((n) => parseRecommendationKey(n.key)!.drillId == x), isEmpty);
});
test('nội dung là khuôn Vi điền từ computeRecommendation', () {
  final rec = inputs().recommendFor(DateTime(2026, 10, 13, 8));
  final n = reco(inputs()).first;
  expect(n.title, Vi.recommendationReminderTitle);
  expect(n.body, Vi.recommendationReminderBody(rec.drill!.name, rec.cat, Vi.pickReason(rec.reason, Vi.skill(rec.cat), signal: rec.matchSignal)));
  expect(n.key, recommendationKey(DateTime(2026, 10, 13), rec.cat, rec.drill!.id));
  expect(n.validUntil, DateTime(2026, 10, 14));
});
test('chống bịa: nhóm yếu khác thì nội dung khác', () {
  // seedDrills; A: điểm thấp ở bài Ngắm bi đầu, đủ điểm ở bài đầu mỗi nhóm cơ bản khác (log hôm qua);
  // B: như A nhưng điểm thấp ở Cân bi. Chỉnh dữ liệu tới khi hai guard dưới đây xanh.
  final ra = a.recommendFor(DateTime(2026, 10, 13, 8)), rb = b.recommendFor(DateTime(2026, 10, 13, 8));
  expect(ra.reason, PickReason.weakest); expect(ra.cat, isNot(rb.cat));
  final na = reco(a).first, nb = reco(b).first;
  expect(na.body, contains(Vi.skill(ra.cat))); expect(nb.body, contains(Vi.skill(rb.cat))); expect(na.body, isNot(nb.body));
});
test('id đổi khi nội dung đổi, giữ nguyên khi không đổi', () { /* đổi tên d1 → id khác; chạy lại cùng inputs → cùng id */ });
test('tắt Gợi ý mới hoặc chưa có dữ liệu: không có', () {
  expect(reco(inputs(), prefs: const NotificationPrefs(recommendation: false)), isEmpty);
  expect(planNotifications(cues: const [], slots: const [], streak: noStreak, prefs: const NotificationPrefs(), now: now)
      .where((n) => n.kind == NotificationKind.recommendation), isEmpty);
});
test('khoá gợi ý: đọc lại được; khoá rác thì null', () {
  final k = recommendationKey(DateTime(2026, 10, 3), SkillCategory.bank, 'd:7');
  expect(parseRecommendationKey(k), (day: DateTime(2026, 10, 3), cat: SkillCategory.bank, drillId: 'd:7'));
  for (final bad in ['', 'x', '2026-10-3:nope:d1', '2026-10-3:aiming:', 'a-b-c:aiming:d1']) { expect(parseRecommendationKey(bad), isNull, reason: bad); }
});
```

Update `notification_plan_test.dart`:
- `'sorted by time with distinct, stable ids'`: pass `recommendation: RecommendationInputs(drills: testDrills, …)` so every kind is present. Keep `NotificationKind.values.toSet()`.
- `'all toggles off yields an empty plan'`: add `recommendation: false` and the same inputs.
- `'validUntil…'`: add `case NotificationKind.recommendation: expect(n.validUntil, DateTime(2026, 10, 14));`, with inputs passed in.

In `notification_prefs_store_test.dart`, add `test('Gợi ý tập mới lưu theo tài khoản', …)`: save `NotificationPrefs(recommendation: false)` for `u1`. Then `load('u1')` equals it, and `SharedPreferences` holds `poolcoachai:notification-prefs:v1:u1:recommendation` as `false`.

- [ ] **Step 3: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/notifications test/data/notifications/notification_prefs_store_test.dart`. Expected: compile errors (`recommendation_reminder.dart`, `NotificationKind.recommendation` and `RecommendationInputs` do not exist yet).

- [ ] **Step 4: Implement** the Interfaces above.

- [ ] **Step 5: Run the tests and analyze.** Run the same tests, then `$ENV $FLUTTER test test/features/notifications test/data/notifications test/architecture_test.dart`, then `$ENV $FLUTTER analyze`. Expected: PASS, no issues. The screen shows four switches because it iterates `NotificationKind.values`.

- [ ] **Step 6: Commit.** Message: `Thông báo P6a: loại Gợi ý tập mới lập lúc 08:00 từ computeRecommendation, chỉ khi khác cặp đã thấy`, plus the trailer.

---

### Task 2: One set of recommendation inputs, and Home records what it shows

**Files:**
- Modify: `lib/core/providers/recommendation_provider.dart`, `lib/core/providers/notification_providers.dart`, `lib/domain/notifications/recommendation_reminder.dart`, `lib/features/home/presentation/home_screen.dart`
- Create: `lib/data/notifications/recommendation_seen_store.dart`, `test/support/fake_recommendation_seen_store.dart`
- Modify (test support): `test/support/test_data.dart` (`testContainer` gets `RecommendationSeenStore? seenStore` and `Stream<List<DrillLog>>? logsStream`; `dbContainer` gets `RecommendationSeenStore? seenStore`; both always override `recommendationSeenStoreProvider` with `seenStore ?? FakeRecommendationSeenStore()`. `logsStream` wins over `logs`.)
- Test: `test/data/notifications/recommendation_seen_store_test.dart` (create), `test/core/providers/recommendation_provider_test.dart` (add), `test/features/home/home_screen_test.dart` (add)

**Interfaces:**
- Consumes: Task 1 `RecommendationInputs`, `SeenRecommendation`. Also `gate`, `currentUserIdProvider`, `nowProvider`, `latestBuResultProvider`, and the stream providers `todayRecommendationProvider` reads today.
- Produces:
  - `final recommendationInputsProvider = Provider<AsyncValue<RecommendationInputs>>(…)`. It contains the current body of `todayRecommendationProvider` up to the compute call, unchanged: the same gate, and the BU failed/loading rules.
  - `todayRecommendationProvider` maps the inputs' `AsyncData` to `AsyncData(inputs.recommendFor(ref.watch(nowProvider)()))` and passes loading/error through. Existing tests stay green unchanged.
  - `final class RecommendationSource { const RecommendationSource({required String userId, required RecommendationInputs inputs, required SeenRecommendation? seen}); }` in `recommendation_reminder.dart`.
  - `abstract class RecommendationSeenStore { Future<SeenRecommendation?> load(String userId); Future<void> save(String userId, SeenRecommendation seen); }`.
  - `SharedPreferencesRecommendationSeenStore` stores the key `'poolcoachai:recommendation-seen:v1:$userId'` as JSON `{"cat": cat.name, "drillId": …, "at": at.toIso8601String()}`. Unparseable JSON or an unknown category loads as null.
  - `final recommendationSeenStoreProvider = Provider<RecommendationSeenStore>((ref) => SharedPreferencesRecommendationSeenStore());`
  - `final recommendationSeenProvider = NotifierProvider<RecommendationSeenController, AsyncValue<SeenRecommendation?>>(…)`.
    - `build` mirrors `NotificationPrefsController`: no user → `AsyncData(null)`. Otherwise it returns `AsyncLoading`, loads the store, and sets `AsyncData` only `if (!disposed && state is AsyncLoading)`. A load error becomes `AsyncData(null)`.
    - `Future<void> markSeen(SkillCategory cat, String drillId)`: no user → return. Otherwise `seen = SeenRecommendation(cat:, drillId:, at: ref.read(nowProvider)())`, then `state = AsyncData(seen)`, then `try { await store.save(userId, seen) } on Object {}`.
  - `final recommendationSourceProvider = Provider<RecommendationSource?>(…)`: null when there is no user or when `gate([inputs, seen]) != null`. Otherwise it builds the source from `requireValue`.
  - `HomeScreen` becomes a `ConsumerStatefulWidget`. It keeps `({SkillCategory cat, String drillId})? _recorded` and `bool _wasVisible = false`.
    - In `build`, when the recommendation is `AsyncData` with `drill != null`: `visible = TickerMode.valuesOf(context).enabled`.
    - When `visible && (!_wasVisible || pair != _recorded)`, set `_recorded = pair` and call `markSeen` in a post-frame callback.
    - Always set `_wasVisible = visible`.
- `FakeRecommendationSeenStore` has `final saved = <String, SeenRecommendation>{};`, plus an optional `Completer<SeenRecommendation?>? hold` that `load` awaits when set.

- [ ] **Step 1: Write the failing tests.**

```dart
// recommendation_seen_store_test.dart (SharedPreferences.setMockInitialValues({}))
test('lưu và đọc theo tài khoản, không lẫn', …);      // save u1, load u1 == seen, load u2 isNull
test('giá trị hỏng hoặc nhóm lạ: coi như chưa thấy', …); // setMockInitialValues({'…:v1:u1': '{"cat":"nope",…}'}) → null; '{' → null

// recommendation_provider_test.dart
test('nguồn gợi ý null khi một nguồn đang tải lại', …);   // drillLogsProvider.overrideWithValue(AsyncLoading-with-old-value pattern used in this file) → recommendationSourceProvider null
test('nguồn gợi ý có userId, inputs và cặp đã thấy khi mọi thứ sẵn sàng', …);
test('Home và nguồn dùng cùng inputs: recommendFor(now) bằng gợi ý Home', () async {
  // listen cả hai; expect(container.read(recommendationSourceProvider)!.inputs.recommendFor(testToday).drill?.id,
  //   container.read(todayRecommendationProvider).value!.drill?.id);
});
test('đổi tài khoản khi đang đọc: cặp của u1 không lọt sang u2', () async {
  // store.hold = Completer; auth.emit(SignedIn('u2')); hold.complete(seenOfU1) → state của u2 không phải seenOfU1
});

// home_screen_test.dart (testContainer(seenStore: store, logsStream: controller.stream))
testWidgets('Trang chủ hiện bài gợi ý: ghi (nhóm, bài) đã thấy cho u1', (tester) async {
  // openHome; final rec = container.read(todayRecommendationProvider).value!;
  // expect(store.saved['u1']!.sameAs(rec.cat, rec.drill!.id), isTrue); expect(store.saved['u1']!.at, testToday);
});
testWidgets('đang ở tab khác: gợi ý đổi không được ghi; quay lại Trang chủ thì ghi', (tester) async {
  // openHome → X; tap Vi.tabTraining; controller.add(logs khiến gợi ý thành Y); pumpAndSettle → saved vẫn X;
  // tap Vi.tabHome; pumpAndSettle → saved là Y
});
testWidgets('không có bài gợi ý: không ghi', …); // drills: const [] → store.saved isEmpty
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/notifications/recommendation_seen_store_test.dart test/core/providers/recommendation_provider_test.dart test/features/home/home_screen_test.dart`. Expected: compile errors.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run the three files plus `test/core/providers`, `test/features/home`, `test/features/closed_loop_test.dart`, `test/architecture_test.dart` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: một bộ inputs gợi ý cho Trang chủ và thông báo; Trang chủ ghi cặp đã thấy khi là tab đang mở`, plus the trailer.

---

### Task 3: The notification log (Drift v17)

**Files:**
- Modify: `lib/data/database/database.dart`, `lib/data/sync/account_actions.dart` (`signOutAndForget`), `lib/core/providers/notification_providers.dart`, `test/support/test_data.dart` (`testContainer` gets `List<NotificationLogEntry>? notificationLog` and overrides `notificationLogProvider` with `Stream.value(notificationLog ?? const [])`)
- Create: `lib/domain/notifications/notification_log.dart`, `lib/data/notifications/notification_log_repository.dart`
- Test: `test/data/database/migration_test.dart`, `test/data/notifications/notification_log_repository_test.dart` (create), `test/domain/notifications/notification_log_test.dart` (create), `test/data/sync/account_actions_test.dart`

**Interfaces:**
- Consumes: Task 1 `PlannedNotification`, `NotificationKind`, `SeenRecommendation`, `parseRecommendationKey`.
- Produces:
  - Table `NotificationLogRows`, with the doc comment "Nhật ký thông báo đã lập/đã hiện — chỉ trên máy này, không đồng bộ (spec P6a §4)":
    - `TextColumn userId`, `IntColumn id`, `TextColumn kind`, `TextColumn key`, `DateTimeColumn at`, `TextColumn title`, `TextColumn body`, `DateTimeColumn readAt` (nullable).
    - `primaryKey => {userId, id}`.
    - Added to `@DriftDatabase(tables:)`.
    - `schemaVersion => 17`.
    - Migration `if (from < 17) { await m.createTable(notificationLogRows); }` with the comment "Chỉ thêm bảng (spec P6a §4): không đụng dữ liệu cũ."
  - `notification_log.dart`:
    - `final class NotificationLogEntry { const NotificationLogEntry({required int id, required NotificationKind kind, required String key, required DateTime at, required String title, required String body, DateTime? readAt}); }`
    - `const notificationInboxDays = 30;`
    - `List<NotificationLogEntry> inboxEntries(List<NotificationLogEntry> all, DateTime now)`: `at ≤ now` and `at > now − 30 days`, newest first (tie broken by id).
    - `int unreadCount(List<NotificationLogEntry> all, DateTime now)`: inbox entries with `readAt == null`.
    - `DateTime? nextDelivery(List<NotificationLogEntry> all, DateTime now)`: the smallest `at` after `now`.
    - `SeenRecommendation? recommendationBaseline({SeenRecommendation? shownOnHome, required List<NotificationLogEntry> log, required DateTime now})`: the newest by `at` among `shownOnHome` and every recommendation entry with `at ≤ now` whose key parses (★3).
  - `NotificationLogRepository(AppDatabase db, {required String userId})`:
    - `Stream<List<NotificationLogEntry>> watchAll()`: this user's rows, unknown kinds skipped.
    - `Future<void> syncPlanned(List<PlannedNotification> planned, {required DateTime now})`: delete rows with `at > now` whose id is not planned, delete rows older than 30 days, insert planned ids not present (★8; a no-op runs no statement).
    - `Future<void> recordShown(PlannedNotification n, {required DateTime at})`: insert-or-ignore with `at`, plus the 30-day prune.
    - `Future<void> markRead(Iterable<int> ids, {required DateTime at})`: only rows with null `readAt`.
    - `Future<void> markReadByKey(NotificationKind kind, String key, {required DateTime now})`: rows of that kind and key with `at ≤ now` and null `readAt`, setting `readAt = now`.
  - Providers:
    - `final notificationLogRepositoryProvider = Provider<NotificationLogRepository?>(…)`: null when signed out. Otherwise it is built from `appDatabaseProvider` and the user id.
    - `final notificationLogProvider = StreamProvider<List<NotificationLogEntry>>((ref) => ref.watch(notificationLogRepositoryProvider)?.watchAll() ?? Stream.value(const []));`
  - `signOutAndForget` deletes `notificationLogRows` of `userId`, next to `coachChatTurnRows`, with the comment "Nhật ký thông báo chỉ nằm trên máy này."

- [ ] **Step 1: Write the failing tests.**

```dart
// migration_test.dart
// Đổi mọi expect(db.schemaVersion, 16) và expect(version.read<int>('user_version'), 16) thành 17.
// Thêm expect(await db.select(db.notificationLogRows).get(), isEmpty) vào test 'nâng từ v1 lên v2…' và 'nâng từ v11 lên v16…' (đổi tên thành '…lên v17…').
test('nâng từ v16 lên v17 thêm bảng nhật ký thông báo, giữ nguyên dữ liệu', () async {
  // setup: CREATE TABLE coach_chat_turn_rows (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL,
  //   created_at INTEGER NOT NULL, from_player INTEGER NOT NULL CHECK (from_player IN (0, 1)), message TEXT NOT NULL,
  //   insufficient INTEGER NOT NULL DEFAULT 0 CHECK (insufficient IN (0, 1))); một dòng; PRAGMA user_version = 16;
  // → dòng chat còn nguyên; notificationLogRows rỗng; user_version 17
});
test('tạo mới ở v17 ghi và đọc được nhật ký thông báo', …); // cùng id cho u1 và u2 cùng tồn tại (khoá {userId, id})

// notification_log_repository_test.dart (now = DateTime(2026, 10, 13, 9))
test('ghi khi lập kế hoạch: thêm mục mới, giữ mục đã có', …);
test('mục tương lai bị huỷ thì xoá; mục đã tới giờ được giữ', …);
test('không đổi gì thì không ghi: luồng theo dõi không phát lại', () async {
  // đếm số lần watchAll() phát; syncPlanned(cùng kế hoạch) lần hai; pumpEventQueue → số lần không tăng
});
test('đánh dấu đã đọc theo id và theo (loại, khoá): chỉ mục đã tới giờ của đúng người', …);
test('mục cũ hơn 30 ngày bị dọn khi ghi', …);
test('dòng có loại lạ bị bỏ qua, dòng của người khác không thấy', …);

// notification_log_test.dart
test('hộp thư: chỉ mục đã tới giờ trong 30 ngày, mới nhất trước', …);
test('đếm chưa đọc bỏ mục tương lai và mục đã đọc', …);
test('lần giao kế tiếp là mục tương lai sớm nhất', …);
test('mốc đã thấy: mới hơn giữa Trang chủ và gợi ý đã giao; bỏ khoá hỏng và mục tương lai', …);

// account_actions_test.dart
test('đăng xuất xoá nhật ký thông báo của người đó, giữ của người khác', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/database/migration_test.dart test/data/notifications test/domain/notifications test/data/sync/account_actions_test.dart`. Expected: compile errors.

- [ ] **Step 3: Implement** the Interfaces above. Then run `$ENV $DART run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run the tests.** Run the same files, then `test/features test/core` in the background with Monitor. These pick up the new `testContainer` override. Then run `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: bảng notification_log_rows (v17) chỉ trên máy, ghi theo khác biệt, đăng xuất thì xoá`, plus the trailer.

---

### Task 4: The service plans recommendations, keeps the log and stays listening

**Files:**
- Modify: `lib/data/notifications/notification_service.dart`, `lib/core/providers/notification_providers.dart` (`notificationServiceProvider`, `upcomingNotificationsProvider`), `lib/core/bootstrap.dart`
- Test: `test/data/notifications/notification_service_test.dart`, `test/core/bootstrap_test.dart`, `test/features/notifications/notifications_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 `planNotifications(recommendation:, lastSeenRecommendation:)`. Task 2 `RecommendationSource`, `recommendationSourceProvider`. Task 3 `NotificationLogRepository`, `NotificationLogEntry`, `recommendationBaseline`, `notificationLogProvider`.
- Produces:
  - `NotificationService.setRecommendationSource(RecommendationSource? source)`: stores the source, then runs `checkNow()` when started and not disposed.
  - `@visibleForTesting NotificationPrefs? get prefs` and `@visibleForTesting RecommendationSource? get recommendationSource`.
  - `_setUser` also:
    - watches `NotificationLogRepository(_db, userId: userId).watchAll()` into `List<NotificationLogEntry>? _log`, null until the first emission and reset on user change;
    - sets `DateTime _userSince = _now().toLocal()`.
    - The stored source is **not** cleared on user change. It is used only while `source.userId == _userId`.
  - `_plan(from, {limit})` passes `recommendation: source.inputs` and `lastSeenRecommendation: recommendationBaseline(shownOnHome: source.seen, log: _log!, now: _now().toLocal())` only when the source belongs to `_userId` and `_log != null`. Otherwise it passes null (★4).
  - `_syncSchedule`, with a user and loaded prefs:
    - if permission is granted: `plan = _plan(now)`, then `await reconcileNotifications(...)`, then `await repo.syncPlanned(plan, now: now)`;
    - otherwise: `await repo.syncPlanned(const [], now: now)` (★7).
  - Web `checkNow`:
    - skips a recommendation whose `at` is not after `_userSince` (★5);
    - after `show`, `unawaited(repo.recordShown(n, at: now))`.
  - `upcomingNotificationsProvider` passes the same two arguments, built from `recommendationSourceProvider` and `notificationLogProvider` (value). They are null unless the source exists and the log `hasValue && !isLoading`.
  - `notificationServiceProvider` adds `ref.listen(recommendationSourceProvider, (_, next) => service.setRecommendationSource(next), fireImmediately: true)`.
  - `bootstrap.dart`:
    - `void startNotifications(ProviderContainer container)` does `container.listen(notificationServiceProvider, (_, _) {}).read().start();` with a doc comment citing ★12. Never close the subscription.
    - `startSync` calls it instead of `container.read(notificationServiceProvider).start()`.

- [ ] **Step 1: Write the failing tests.** `source({String userId = 'u1', SeenRecommendation? seen})` returns `RecommendationSource(userId: userId, inputs: RecommendationInputs(drills: testDrills, logs: const [], knowledge: const [], timerSessions: const [], schedule: const [], matches: const []), seen: seen)`. The file's `now` is `DateTime(2026, 10, 13, 8, 59)`.

```dart
// native scheduling group
test('gợi ý mới được đặt lúc 08:00 ngày mai và ghi vào nhật ký', () async {
  scheduler.granted = true; final s = scheduling()..start()..setRecommendationSource(source()); addTearDown(s.dispose);
  await pumpEventQueue();
  final r = scheduler.scheduled.where((n) => n.kind == NotificationKind.recommendation);
  expect(r.map((n) => n.at), [DateTime(2026, 10, 14, 8)]);
  expect((await db.select(db.notificationLogRows).get()).map((x) => x.id), contains(r.single.id));
});
test('nguồn của tài khoản khác bị bỏ qua', …);                      // source(userId: 'u2') → không có recommendation
test('kế hoạch đổi trước giờ giao: huỷ thông báo và xoá mục tương lai', …); // setRecommendationSource(source(seen: cặp đó)) → cancelled chứa id, dòng log biến mất
test('mục đã tới giờ được giữ khi kế hoạch đổi', …);                // now = 14/10 08:01, đổi nguồn → dòng 08:00 còn
test('chưa cấp quyền: không đặt gì, nhật ký không có mục tương lai', …);
test('đã giao X: ngày mai cùng X không đặt lại', …);                 // chèn dòng recommendation X at 13/10 08:00 (≤ now), seen null → không có recommendation 14/10
// browser group
test('tab mở trước 08:00: hiện gợi ý lúc 08:00 một lần, ghi nhật ký lúc hiện', () async {
  now = DateTime(2026, 10, 13, 7, 59); platform.permissionValue = 'granted';
  final s = service()..start()..setRecommendationSource(source(seen: SeenRecommendation(cat: SkillCategory.bank, drillId: 'x', at: DateTime(2026, 10, 12))));
  addTearDown(s.dispose); await pumpEventQueue();
  now = DateTime(2026, 10, 13, 8); s.checkNow(); s.checkNow(); await pumpEventQueue();
  expect(platform.notifications.where((n) => n.title == Vi.recommendationReminderTitle), hasLength(1));
  expect((await db.select(db.notificationLogRows).get()).single.at, DateTime(2026, 10, 13, 8));
});
test('mở tab sau 08:00: không hiện gợi ý của sáng nay', …);          // start lúc 08:30 → không có title gợi ý

// bootstrap_test.dart
test('startNotifications giữ dịch vụ luôn nghe: cài đặt nạp xong tới được dịch vụ', () async {
  // overrides: appDatabaseProvider (memory), authRepositoryProvider signedIn, notificationPrefsStoreProvider → store trả NotificationPrefs(streak: false),
  // recommendationSeenStoreProvider → FakeRecommendationSeenStore
  startNotifications(container); await pumpEventQueue();
  expect(container.read(notificationServiceProvider).prefs, const NotificationPrefs(streak: false));
});

// notifications_screen_test.dart: containerWith mặc định drills: const [] để các test cũ giữ nghĩa (không có gợi ý)
testWidgets('Sắp tới có Gợi ý tập mới ngày mai lúc 08:00', …);        // containerWith(drills: testDrills) → find.text(Vi.recommendationReminderTitle) và '08:00'
testWidgets('đã thấy đúng cặp ở Trang chủ: Sắp tới không có gợi ý', …); // seenStore có (aiming, d1)
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/notifications/notification_service_test.dart test/core/bootstrap_test.dart test/features/notifications`. Expected: FAIL or compile errors. The bootstrap test must fail on the old `container.read` path: check that before you implement.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run the same files, `test/core`, `test/architecture_test.dart` and `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: dịch vụ lập gợi ý mới theo tài khoản, giữ nhật ký khớp kế hoạch; startNotifications giữ dịch vụ luôn nghe (sửa lỗi tạm dừng của Riverpod)`, plus the trailer.

---

### Task 5: Tapping a notification opens the right screen

**Files:**
- Create: `lib/domain/notifications/notification_payload.dart`, `lib/core/router/notification_tap_listener.dart`
- Modify: `lib/data/notifications/notification_scheduler.dart`, `local_notifications_scheduler.dart`, `notification_platform_native.dart`, `notification_platform_web.dart`, `notification_platform_stub.dart`, `notification_service.dart`, `lib/app.dart`
- Test: `test/domain/notifications/notification_payload_test.dart` (create), `test/core/router/notification_tap_listener_test.dart` (create), `test/data/notifications/notification_service_test.dart`. Update every test fake that overrides `show` or implements `NotificationScheduler` (`notification_service_test.dart` `_FakeScheduler` and `_FakeNotificationPlatform`; grep `void show(` and `implements NotificationScheduler` under `test/`).

**Interfaces:**
- Consumes: Task 1 `parseRecommendationKey`. Task 3 `NotificationLogRepository.markReadByKey`. Also `Routes.drill`, `Routes.schedule`, `Routes.equipment`, `Routes.training`.
- Produces:
  - `notification_payload.dart`:
    - `final class NotificationTap { const NotificationTap(this.kind, this.key); final NotificationKind kind; final String key; }`, with value `==`.
    - `String notificationPayload(NotificationKind kind, String key) => '${kind.name}|$key';`
    - `NotificationTap? parseNotificationPayload(String? payload)`: split at the **first** `|`. Null when the payload is null, has no `|`, names an unknown kind (`NotificationKind.values.asNameMap()`), or has an empty key.
  - `NotificationScheduler` adds `set onTap(void Function(String payload)? handler);` and `Future<String?> launchPayload();`.
  - `LocalNotificationsScheduler`:
    - `initialize(settings: …, onDidReceiveNotificationResponse: (r) { final p = r.payload; if (p != null) _onTap?.call(p); })`.
    - `launchPayload()` does `_ensureInit()`, then `getNotificationAppLaunchDetails()`, and returns `details.notificationResponse?.payload` when `details?.didNotificationLaunchApp == true`, otherwise null.
    - `zonedSchedule(…, payload: notificationPayload(n.kind, n.key))`.
  - All three `NotificationPlatform` variants:
    - `void Function(String payload)? onTap;` (field).
    - `Future<String?> takeLaunchPayload()`: native returns `scheduler?.launchPayload() ?? Future.value()`; web and stub return `Future.value()`.
    - `show({required String title, required String body, required String tag, required String payload})`.
    - Native wires `scheduler?.onTap = (p) => onTap?.call(p)` in its constructor.
    - Web sets the created notification's `onclick` to a JS function that calls `onTap?.call(payload)`, then `web.window.focus()`, then `notification.close()`.
  - `NotificationService`:
    - `void setTapHandler(void Function(NotificationTap tap)? handler)`. Setting a handler while a tap is buffered delivers it once and clears the buffer.
    - `start()` (supported platforms) sets `_platform.onTap = _onTapPayload` and `unawaited(_platform.takeLaunchPayload().then((p) { if (p != null) _onTapPayload(p); }))`.
    - `_onTapPayload` parses the payload; null → return. With a user, it calls `unawaited(NotificationLogRepository(_db, userId: _userId!).markReadByKey(tap.kind, tap.key, now: _now().toLocal()))`, then delivers the tap or buffers it.
    - Web `checkNow` passes `payload: notificationPayload(n.kind, n.key)` to `show`.
  - `notification_tap_listener.dart`:
    - `String? notificationRoute(NotificationTap tap)`, an exhaustive switch: recommendation → `parseRecommendationKey(tap.key)?.drillId` mapped through `Routes.drill`; schedule → `Routes.schedule`; maintenance → `Routes.equipment`; streak → `Routes.training`.
    - `class NotificationTapListener extends ConsumerStatefulWidget { const NotificationTapListener({required GoRouter router, required Widget child}); }`. `initState` captures the service and calls `setTapHandler(_onTap)`. `dispose` calls `setTapHandler(null)` on the captured service. `_onTap` computes the route, and when it is non-null calls `router.go(route)` in `addPostFrameCallback` if still mounted.
  - `PoolCoachApp.build` wraps `MaterialApp.router` in `NotificationTapListener(router: _router, child: …)` only when `_ownsRouter`.

- [ ] **Step 1: Write the failing tests.**

```dart
// notification_payload_test.dart
test('payload đọc lại được cho mọi loại', () {
  for (final k in NotificationKind.values) { expect(parseNotificationPayload(notificationPayload(k, 'a|b:c')), NotificationTap(k, 'a|b:c')); }
});
test('payload sai: null, không ném', () {
  for (final bad in [null, '', 'streak', 'nope|k', 'streak|']) { expect(parseNotificationPayload(bad), isNull, reason: '$bad'); }
});
// notification_tap_listener_test.dart
test('mỗi loại mở đúng màn', () {
  final r = recommendationKey(DateTime(2026, 9, 22), SkillCategory.aiming, 'd1');
  expect(notificationRoute(NotificationTap(NotificationKind.recommendation, r)), Routes.drill('d1'));
  expect(notificationRoute(const NotificationTap(NotificationKind.schedule, 's1:2026-9-22')), Routes.schedule);
  expect(notificationRoute(const NotificationTap(NotificationKind.maintenance, 'c1:2026-9-22:0')), Routes.equipment);
  expect(notificationRoute(const NotificationTap(NotificationKind.streak, '2026-9-22')), Routes.training);
  for (final k in NotificationKind.values) { expect(notificationRoute(NotificationTap(k, k == NotificationKind.recommendation ? r : 'x')), isNotNull, reason: k.name); }
  expect(notificationRoute(const NotificationTap(NotificationKind.recommendation, 'rác')), isNull);
});
testWidgets('chạm thông báo lịch tập khi app đang mở: tới Lịch tập', …);   // router = createAppRouter(auth: signedInGate()); service với nền tảng giả đã start;
                                                                         // platform.onTap!(notificationPayload(schedule, 's1:2026-9-22')); pumpAndSettle;
                                                                         // router.routerDelegate.currentConfiguration.uri.path == Routes.schedule
testWidgets('mở app từ thông báo gợi ý (khởi động lạnh): tới chi tiết bài', …); // platform.launch = payload d1, start() trước khi pump → Routes.drill('d1')
testWidgets('gợi ý cho bài không còn: mở màn bài, không lỗi', …);              // drillId 'd404' → path Routes.drill('d404'), tester.takeException() isNull
testWidgets('payload rác: đứng yên', …);                                   // onTap!('rác') → path vẫn Routes.home
// notification_service_test.dart
test('chạm đánh dấu đã đọc mục đã tới giờ của đúng (loại, khoá)', …);       // dòng schedule at ≤ now → readAt == now
test('chạm trước khi có handler: giữ lại, giao một lần khi handler tới', …);
test('payload rác: không gọi handler, không đổi dòng nào', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/notifications test/core/router/notification_tap_listener_test.dart test/data/notifications`. Expected: compile errors.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run the same files, then `test/features/notifications`, `test/features/profile`, `test/core/router`, `test/app_test.dart`, `test/architecture_test.dart`, then `$ENV $FLUTTER analyze`. Then `$ENV $FLUTTER build web --release` to prove the web variant compiles. Expected: PASS, and the build exits 0.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: chạm thông báo (đang mở, chạy nền, khởi động lạnh, web onclick) mở đúng màn và đánh dấu đã đọc`, plus the trailer.

---

### Task 6: Bell badge and the "Đã gửi" inbox

**Files:**
- Create: `lib/core/widgets/pc_rebuild_at.dart`, `lib/core/widgets/pc_notification_bell.dart`
- Modify: `lib/core/widgets/pc_root_scaffold.dart`, `lib/features/notifications/presentation/notifications_screen.dart`, `lib/core/strings/vi.dart`
- Test: `test/core/widgets/pc_root_scaffold_test.dart` (wrap each pump in `ProviderScope(overrides: [notificationLogProvider.overrideWith((ref) => Stream.value(const <NotificationLogEntry>[]))])`), `test/core/widgets/pc_notification_bell_test.dart` (create), `test/features/notifications/notifications_screen_test.dart`. Also any test container that overrides `authRepositoryProvider` as signed-in, but neither `appDatabaseProvider` nor `notificationLogProvider`, and pumps a `PcRootScaffold` screen: add the same override. Candidates are the raw `ProviderContainer(` calls in `test/features/play/play_screen_test.dart`, `tournament_list_screen_test.dart` and `training/training_screen_test.dart`. Confirm them by running `test/features`.

**Interfaces:**
- Consumes: Task 3 `notificationLogProvider`, `notificationLogRepositoryProvider`, `inboxEntries`, `unreadCount`, `nextDelivery`, `notificationInboxDays`. Task 5 `notificationRoute`, `NotificationTap`.
- Produces:
  - `class PcRebuildAt extends StatefulWidget { const PcRebuildAt({required DateTime? at, required DateTime now, required WidgetBuilder builder}); }`. When `at != null`, it holds one `Timer(at.difference(now) + const Duration(seconds: 1))` that calls `setState`. It reschedules in `didUpdateWidget` when `at` or `now` changes, and cancels in `dispose`.
  - `class PcNotificationBell extends ConsumerWidget`. It reads `notificationLogProvider.value ?? const []`, then returns `PcRebuildAt(at: nextDelivery(all, now()), now: now(), builder: …)`. Inside the builder, it reads `now = ref.read(nowProvider)()` again and builds `IconButton(tooltip: Vi.notificationsBellTooltip(n), icon: Badge(isLabelVisible: n > 0, label: Text(Vi.notificationsUnreadBadge(n)), child: const Icon(Icons.notifications_none)), onPressed: () => context.push(Routes.notifications))`, where `n = unreadCount(all, now)`.
  - `PcRootScaffold.actions` is `[const PcNotificationBell()]`.
  - `NotificationsScreen`:
    - After `_permissionCard()`, add `PcSectionHeader(title: Vi.notificationsSentTitle)`, then either `Vi.notificationsSentEmpty` (muted text, like the upcoming empty state) or one `PcCard(ListTile(…))` per inbox entry. Each tile has the leading text `Vi.notificationsSentAt(e.at, now)`, the title `Text(e.title, style: TextStyle(fontWeight: _bold.contains(e.id) ? FontWeight.w700 : FontWeight.w400))`, the subtitle `Text(e.body)`, and `onTap` → `notificationRoute(NotificationTap(e.kind, e.key))` → `context.go` when non-null.
    - The section is wrapped in `PcRebuildAt` like the bell.
    - The state holds `final _bold = <int>{}`. In `initState`, `ref.listenManual(notificationLogProvider, (_, next) => _markSeen(next.value), fireImmediately: true)`.
    - `_markSeen` collects inbox entries (`now` from `nowProvider`) with null `readAt` that are not yet in `_bold`, adds their ids to `_bold` (`setState` if mounted), and calls `ref.read(notificationLogRepositoryProvider)?.markRead(ids, at: now)`.
  - `Vi`:
    - `static const notificationsSentTitle = 'Đã gửi';`
    - `static const notificationsSentEmpty = 'Chưa có thông báo nào trong $notificationInboxDays ngày qua.';` (`vi.dart` imports `notification_log.dart`)
    - `static String notificationsUnreadBadge(int n) => n > 99 ? '99+' : '$n';`
    - `static String notificationsBellTooltip(int unread) => unread == 0 ? notificationsTitle : '$notificationsTitle, $unread chưa đọc';`
    - `static String notificationsSentAt(DateTime at, DateTime now) => '${at.year == now.year && at.month == now.month && at.day == now.day ? notificationsToday : notificationsDay(at)}, ${notificationsTime(at)}';` `vi.dart` imports no Flutter, and domain code imports it, so do not use `DateUtils`.

- [ ] **Step 1: Write the failing tests.** Entries are built with `NotificationLogEntry(...)`, and widget tests use `dbContainer(db, clock: () => clock)` with rows inserted through `NotificationLogRepository`.

```dart
// pc_notification_bell_test.dart
testWidgets('hai mục chưa đọc đã tới giờ: huy hiệu 2; mục tương lai và đã đọc không tính', …); // find.text('2'); tooltip Vi.notificationsBellTooltip(2)
testWidgets('không có mục chưa đọc: không hiện số', …);   // tester.widget<Badge>(find.byType(Badge)).isLabelVisible == false
testWidgets('trên 99: hiện 99+', …);
testWidgets('tới giờ của mục tương lai thì huy hiệu tự tăng', (tester) async {
  // dòng at = clock + 1 phút; badge ẩn; clock = clock + 2 phút; await tester.pump(const Duration(minutes: 2)); find.text('1')
});
testWidgets('chạm chuông mở màn Thông báo', …);
// notifications_screen_test.dart
testWidgets('Đã gửi: mục đã tới giờ trong 30 ngày, mới nhất trước; không có mục tương lai hay quá 30 ngày', …);
testWidgets('mở màn: mục chưa đọc in đậm và được đánh dấu đã đọc, vẫn đậm trong lượt xem này', (tester) async {
  // sau pumpAndSettle: readAt của mục đã tới giờ != null, mục tương lai readAt null;
  // tester.widget<Text>(find.text(titleUnread)).style!.fontWeight == FontWeight.w700; mục đã đọc từ trước w400
});
testWidgets('Đã gửi trống: nói chưa có trong 30 ngày', …);       // find.text(Vi.notificationsSentEmpty)
testWidgets('chạm mục Đã gửi Lịch tập: mở Lịch tập', …);          // qua router thật như Task 5
testWidgets('có công tắc Gợi ý tập mới, bật mặc định', …);         // switchOf(NotificationKind.recommendation).value == true
testWidgets('360×640 chữ x1.5: màn Thông báo có Đã gửi và Sắp tới không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 1.5); // ba mục Đã gửi thân dài + một gợi ý Sắp tới
  expect(tester.takeException(), isNull); await scrollThroughAll(tester); expect(tester.takeException(), isNull);
});
// pc_root_scaffold_test.dart: thêm testWidgets('thanh trên có chuông kèm huy hiệu', …)
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/core/widgets test/features/notifications`. Expected: FAIL or compile errors.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests.** Run the same folders. Then run `test/features test/core test/app_test.dart test/architecture_test.dart` in the background with Monitor, and fix any container that still lacks the override. Then run `$ENV $FLUTTER analyze`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: chuông có số chưa đọc, màn Thông báo có mục Đã gửi (30 ngày, chưa đọc in đậm, mở màn là đã đọc)`, plus the trailer.

---

### Task 7: Copy that matches the platform (spec §6)

**Files:**
- Modify: `lib/core/strings/vi.dart`, `lib/features/profile/presentation/equipment_screen.dart` (`_maintenanceReminderCard`), `lib/features/notifications/presentation/notifications_screen.dart` (`_permissionCard`)
- Test: `test/features/profile/equipment_screen_test.dart`, `test/core/widgets/pc_action_tile_test.dart`, `test/features/notifications/notifications_screen_test.dart`

**Interfaces:**
- Consumes: `NotificationService.schedulesInBackground`.
- Produces (`Vi`, exact strings):
  - `static String equipmentReminderEnabled({required bool inBackground}) => inBackground ? 'Điện thoại sẽ nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó, kể cả khi ứng dụng đang đóng.' : 'Trình duyệt sẽ nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó khi ứng dụng đang mở.';`
  - `static String equipmentReminderPrompt({required bool inBackground}) => inBackground ? 'Thông báo lúc 09:00 ngày đến hạn và 7 ngày trước đó, kể cả khi ứng dụng đang đóng.' : 'Thông báo lúc 09:00 ngày đến hạn và 7 ngày trước đó. Chỉ hoạt động khi ứng dụng đang mở.';`
  - `static const notificationsBackgroundNote = 'Trên điện thoại, thông báo vẫn đến khi ứng dụng đang đóng.';`
  - `static const notificationsRecommendationLimit = 'Gợi ý tập mới được tính từ dữ liệu trên máy này lúc ứng dụng mở lần cuối. Nếu bạn tập trên máy khác, thông báo có thể chưa theo kịp.';`
  - `static String get notificationsWebOnlyWhileOpen => 'Trên trình duyệt, thông báo chỉ hiện khi ứng dụng đang mở. Gợi ý tập mới chỉ hiện nếu trang đã mở từ trước ${recommendationReminderHour.toString().padLeft(2, '0')}:00.';`
  - `notificationsPermissionPrompt` becomes `'Bật thông báo để nhận gợi ý tập mới, nhắc bảo dưỡng, nhắc giờ tập và nhắc giữ chuỗi.'`
- Behavior:
  - The equipment card passes `inBackground: reminders.schedulesInBackground`.
  - The permission card shows `Vi.notificationsBackgroundNote` and then `Vi.notificationsRecommendationLimit` when `schedulesInBackground`, and `Vi.notificationsWebOnlyWhileOpen` otherwise. All are muted text, wrapping.

- [ ] **Step 1: Write the failing tests.**

```dart
// equipment_screen_test.dart: mọi Vi.equipmentReminderPrompt cũ → Vi.equipmentReminderPrompt(inBackground: false) (_PromptPlatform không có scheduler)
testWidgets('điện thoại (có lịch nền): thẻ nhắc nói vẫn đến khi ứng dụng đóng', …); // nền tảng có _FakeScheduler → find.text(Vi.equipmentReminderPrompt(inBackground: true)); không có chữ 'Chỉ hoạt động khi'
// pc_action_tile_test.dart: case đầu dùng Vi.equipmentReminderPrompt(inBackground: true) (chuỗi dài hơn)
// notifications_screen_test.dart
testWidgets('web: ghi chú chỉ khi đang mở, không có ghi chú nền', …);              // _Platform hiện có
testWidgets('điện thoại: ghi chú nền và giới hạn gợi ý, không có ghi chú web', …);  // nền tảng có scheduler giả
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/features/profile/equipment_screen_test.dart test/core/widgets/pc_action_tile_test.dart test/features/notifications`. Expected: FAIL or compile errors.

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run the tests and grep.** Run the same files, `test/architecture_test.dart` and `$ENV $FLUTTER analyze`. Then `git grep -n "Chỉ hoạt động khi ứng dụng đang mở" lib` must find only the web branch of `equipmentReminderPrompt`. Expected: PASS.

- [ ] **Step 5: Commit.** Message: `Thông báo P6a: câu chữ theo nền tảng — điện thoại báo cả khi ứng dụng đóng, web chỉ khi trang mở; nêu giới hạn của gợi ý mới`, plus the trailer.

---

### Task 8: Web E2E script, docs and full verification

**Files:**
- Create: `tool/e2e/notifications.mjs`
- Modify: `PRD_PoolCoachAI.md`, `tong_hop_y_tuong_app_huan_luyen_bi_a_9ball.md`

**Interfaces:**
- Consumes: `launch`, `sleep` (`tool/e2e/cdp.mjs`) and `registerThrowaway`, `deleteUserByEmail` (`tool/e2e/throwaway_user.mjs`).
- The script follows `tool/e2e/tournament.mjs`: the `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1` guard, `check()` with screenshots, cleanup in `finally`, and exit code 1 on any failed check.
- Steps the script runs (★15):
  1. Before the first navigation, call `tab.send('Page.addScriptToEvaluateOnNewDocument', { source })`.
     - `source` replaces `Date` with a subclass whose no-argument constructor and `Date.now()` add a fixed `OFFSET`.
     - `OFFSET` is computed in Node as today's local 07:58:30 minus `Date.now()`, and baked into the source so reloads keep the same clock.
  2. Call `tab.send('Browser.grantPermissions', { origin: APP, permissions: ['notifications'] })` inside try/catch. Then read `Notification.permission` with `tab.eval`.
     - If it is not `'granted'`, print `KHÔNG CẤP ĐƯỢC QUYỀN THÔNG BÁO TRONG CHROME CHẠY NGẦM — chỉ kiểm màn hình`, run steps 3, 4 and 7 only, and skip steps 5 and 6.
  3. Register a throwaway user. Home shows a recommended drill: read its name.
  4. Open `/notifications`. Tap "Bật thông báo" when present. The page shows `Gợi ý tập mới`, `Đã gửi` and `Chưa có thông báo nào trong 30 ngày qua.`
  5. Go `/home`, then tap "Mở bài" (`Vi.homeDrillOpen`), which switches to the Training tab, so Home is no longer active. Start a session for that drill, enter its target as the score, and save. This turns today's recommendation into a different pair.
  6. Wait until the shifted clock passes 08:00, plus up to 90 s for the minute timer. The bell's label then reads `Thông báo, 1 chưa đọc`. Open `/notifications`: `Đã gửi` lists `Có gợi ý tập mới`. Go back: the bell's label is `Thông báo`.
  7. Exit code 1 when any check failed.
- Doc edits (locate by text):
  - PRD, at the end of the bullet starting "Đã có nhắc lịch tập và nhắc giữ streak", append: " Có thêm thông báo **Gợi ý tập mới** (`NotificationKind.recommendation`, kênh Android `recommendation_reminder`): 08:00 khi gợi ý của ngày khác gợi ý người chơi thấy lần cuối ở Trang chủ, tính bằng đúng `computeRecommendation`; hộp **Đã gửi** 30 ngày với số chưa đọc trên chuông; chạm thông báo mở đúng màn (spec P6a 2026-10-29)."
  - PRD, in the bullet "**Còn thiếu:**", delete "thông báo khi có gợi ý mới từ Coach; " and change "(thông báo hiện là cục bộ, trên web chỉ hiện khi tab còn mở)" to "(thông báo hiện là cục bộ: Android/iOS vẫn đến khi ứng dụng đóng, web chỉ khi tab còn mở; push từ máy chủ là P6b)".
  - PRD, replace the sentence "Người chơi có thể bật thông báo trình duyệt: nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó, chỉ khi ứng dụng đang mở; không gửi khi ứng dụng đã đóng và không thay thế thông báo đẩy." with "Người chơi có thể bật thông báo: nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó. Trên Android/iOS hệ điều hành giữ lịch nên thông báo đến cả khi ứng dụng đóng; trên web chỉ khi tab còn mở (push từ máy chủ là P6b)."
  - Ideas doc, status-table row "Notifications":
    - middle cell becomes "Có màn hình và thiết lập thông báo; nhắc bảo dưỡng, nhắc lịch tập, nhắc giữ streak và gợi ý tập mới cục bộ; hộp Đã gửi có số chưa đọc; chạm thông báo mở đúng màn".
    - right cell becomes "Chưa có push từ máy chủ khi ứng dụng/tab đã đóng (P6b); trên web chỉ hiện khi tab còn mở".

- [ ] **Step 1: Write the script and make the doc edits.**
- [ ] **Step 2: Check the script.** Run `$ENV node --check tool/e2e/notifications.mjs`. Expected: exit 0. Do **not** run it: it hits prod Directus.
- [ ] **Step 3: Full verification.**
  - Run `$ENV $FLUTTER test` in the background, streaming the step and pass/fail counts every minute with Monitor.
  - Then run `$ENV $FLUTTER analyze` and `$ENV $FLUTTER build web --release`.
  - Expected: all green, no analyzer issue, and the web build exits 0.
- [ ] **Step 4: Grep checks.**
  - `git grep -n "recommendationReminderHour = 8" lib` finds exactly one line.
  - `git grep -n "'recommendation_reminder'" lib` finds exactly one line.
  - `git grep -n "package:web\|dart:js_interop" lib` finds only `notification_platform_web.dart` and the files that already used them on `main`. Compare with `git grep` on `main`.
- [ ] **Step 5: Commit.** Message: `Thông báo P6a: E2E web (đồng hồ dời, quyền thông báo), PRD và tài liệu ý tưởng cập nhật`, plus the trailer.
- [ ] **Step 6: Hand the controller these steps (do not do them yourself):**
  - (a) Publish the web, then run `tool/e2e/notifications.mjs` against it in headless Chrome, along with the existing live suite.
  - (b) Before the APK, eye-check on a real Android phone: an 08:00 recommendation arrives with the app closed, and a tap opens the drill.
  - (c) Tell the owner about ★12, the pre-existing pause bug that this branch fixes for notifications. Also propose checking the other `container.read(...)` calls in `startSync` (sync services that use `ref.listen` internally) the same way.
  - (d) Tell the owner about ★5: on web, a recommendation shows only when the tab was open before 08:00.
