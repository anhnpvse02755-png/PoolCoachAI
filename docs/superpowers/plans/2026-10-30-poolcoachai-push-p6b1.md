# Thông báo đẩy từ máy chủ: chuẩn bị (P6b-0) và Web Push kèm backend (P6b-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web notifications arrive with the tab closed. A new Node service `server/notify` plans and sends them over Web Push (VAPID), from data already synced to Directus. Every title, body, id and payload is computed by the app's own Dart code, compiled into a Linux helper. Android FCM (P6b-2) plugs into the same interfaces later.

**Architecture:**
- **P6b-0, enablers (Tasks 1–5), no behaviour change for players:**
  - `lib/domain` becomes Flutter-free.
  - The notification id hash becomes exact on web too.
  - A `seedFingerprint` is added.
  - Pure Directus-row codecs are extracted and the sync code uses them.
  - A helper `bin/notify_plan.dart` runs `planNotifications` on raw Directus rows and talks NDJSON on stdin/stdout. A parity test proves it gives the app's output.
- **Backend (Tasks 6–11):**
  - Directus gains `notification_settings`, `push_devices`, `push_deliveries`, a `PushService` role and a service user.
  - `server/notify` (Node 24) does the rest:
    - verifies player tokens against Directus;
    - registers devices;
    - runs a 15-minute planning cycle plus a one-minute due tick, both through the helper;
    - claims then sends (at most once), within limits, pruning dead devices, behind a kill switch.
  - The sender is chosen per device channel (`web` now, `fcm` in P6b-2).
- **App (Tasks 12–17):**
  - Prefs and the last-seen pair sync through `notification_settings`.
  - A web service worker lives at `/push/sw.js` (scope `/push/`), with a custom `flutter_bootstrap.js`.
  - A `PushService` subscribes and registers, and holds a lease.
  - While the lease is valid, `NotificationService` stops showing server-owned kinds locally.
  - Delivered pushes are pulled into `notification_log_rows`. There is no Drift schema change.

**Tech Stack:** Flutter 3.47 / Dart 3.13 (Riverpod 3.4.3, Drift, `package:web`, `package:timezone`), `dart compile exe` (also cross-compiled to linux-x64), Node 24 (`node:test`, `web-push` pinned exactly), Directus 12 (OIG licence for filtered permissions), Chrome DevTools Protocol for e2e.

**Spec:** `docs/superpowers/specs/2026-10-30-poolcoachai-push-design.md` (binding). Evidence with file:line: `docs/superpowers/specs/2026-10-30-poolcoachai-push-research.md`.

## Global Constraints

- **Workspace.** Work only in `C:\Users\anhnpv\Desktop\PoolCoachAI\.claude\worktrees\push` (branch `feat/push`).
  - The Bash cwd resets between calls, so start every command with `cd /c/Users/anhnpv/Desktop/PoolCoachAI/.claude/worktrees/push && `.
  - Never touch `.mcp.json`, nor the owner's untracked files in the main checkout (`google-services.json` and the two `.md` notes).
- **Command prefix.** The shell exports live secrets. Prefix every flutter / dart / node / npm command with `env -u ANTHROPIC_API_KEY -u DIRECTUS_URL -u DIRECTUS_ADMIN_EMAIL -u DIRECTUS_ADMIN_PASSWORD -u DIRECTUS_SERVICE_TOKEN -u COACH_CHAT_SERVICE_TOKEN -u PUSH_SERVICE_TOKEN -u VAPID_PRIVATE_KEY -u VAPID_PUBLIC_KEY -u VAPID_SUBJECT -u EASYPANEL_MCP_URL`.
  - Below, that prefix is written `$ENV`.
  - Flutter is `/c/Users/anhnpv/flutter/bin/flutter.bat` (`$FLUTTER`) and Dart is `/c/Users/anhnpv/flutter/bin/dart.bat` (`$DART`). Neither is on PATH. Write them out in full when you run them.
- **Generated files.** `*.g.dart` files are gitignored and missing in this worktree. Task 1 Step 1 runs `$ENV $FLUTTER pub get` and `$ENV $DART run build_runner build --delete-conflicting-outputs`. Drift stays at **v17**: no task changes a table.
- **Finding code.** Line numbers in the spec and research go stale. Locate code by symbol (function, constant, test name), never by line.
- **Task boundaries.**
  - A task that changes a constructor, a required parameter or a provider that existing tests use also updates those tests.
  - A task ends with its touched tests green, `$ENV $FLUTTER analyze` clean, and (for Node tasks) `npm test` green in `server/notify`.
  - Never run `dart format` on a whole file you did not create.
- **Values from the spec.** Use these exactly:
  - `lease_until` lasts **6 h**.
  - The planning cycle runs every **15 min**. The due tick runs every **1 min**.
  - At most **12 sends per person per day** and at most **10 devices per person**.
  - Prune a device on HTTP **404/410** (FCM `UNREGISTERED` in P6b-2).
  - The worker is **`/push/sw.js` with scope `/push/`**. `web/flutter_bootstrap.js` has **no `serviceWorkerSettings`**.
  - The image is **`node:24-bookworm-slim`**. The kill switch is **`PUSH_ENABLED=false`**.
  - Collections: `notification_settings`, `push_devices`, `push_deliveries`. Role: `PushService`. Easypanel service: `test-va/notify`.
  - Delivery channels are the strings `'web'` and `'fcm'`.
  - From the research (spec §3 leaves them open): device pruned after `failure_count ≥ 5` or 60 days without `last_seen_at`; deliveries kept 30 days (`notificationInboxDays`); register calls limited to 30 per person per hour.
- **No fabrication** (spec §2, memory rule).
  - Every title, body, key, id and payload sent or stored comes from `planNotifications` (and `computeRecommendation`, `Vi`, the seed, `notificationPayload`) running in the helper.
  - Node never builds or edits notification text.
  - Tests derive expected text from `Vi` and from the Dart functions, never hand-written. The only literal titles allowed are e2e fixtures that are clearly marked as such.
  - When data cannot be decoded, nothing is sent (★7).
- **UI copy.** All copy goes into `Vi`, using exactly the strings in Task 17. No Vietnamese literal appears in `lib/features/**` or `lib/core/widgets/**`. Operator messages in `server/notify` (config errors, stderr) may be Vietnamese, as in coach-chat, but no notification text is ever written there.
- **Mobile target.**
  - Every platform file has stub, web and native variants behind a conditional export, like `notification_platform.dart`.
  - `package:web` and `dart:js_interop` appear only in `notification_platform_web.dart` and `push_platform_web.dart`.
  - The native push variant is a stub in P6b-1. Native behaviour must stay byte-identical: existing native tests unchanged.
- **Riverpod** (lessons from P6a):
  - Long-lived services are held by `container.listen(...)` in bootstrap, never `container.read` (★12 of P6a).
  - Readiness is `hasValue && !isLoading`.
  - An async `Notifier` uses a per-build token. Data handed to a service carries its `userId`, and the service ignores data for another user.
  - Services create timers only in `start()`, which only bootstrap calls. No provider body creates a timer.
- **Writes are diff-based.** A sync or ingest that has nothing new runs no write statement and issues no PATCH. Service tests include a loop guard: a request or emission counter stays at its expected value after extra events.
- **Mutation-proof guards.** Every user-id, lease or claim guard has a test that fails when the guard is deleted. Check this by deleting the guard locally and running the test (do not commit the mutation).
- **Test gotchas.**
  1. `container.read(p.future)` hangs. Use `container.listen(p, (_, _) {})`, then `pumpEventQueue()`, then `container.read(p)`.
  2. Never write a type on an override list.
  3. Inside `testWidgets`, `await repo.watchX().first` hangs.
  4. Drift `AppDatabase.forTesting(NativeDatabase.memory())` works in `flutter test`.
  5. Drift stores `DateTime` as whole seconds.
  6. A timer owned by a provider fails widget tests.
- **Node service rules.**
  - Mirror `server/coach-chat`. `fetch`, `now`, `spawn` and timers are injected, and tests never touch the network.
  - Never log a token, endpoint, `p256dh`/`auth` key, VAPID key, title or body. User ids are hashed (`hashUserId`).
  - Config errors name variables, never values.
- **Low-memory test discipline.**
  - Run only the task's files plus the listed neighbours, and never two `flutter test` processes at once.
  - The full suite runs only in Task 18, as `$ENV $FLUTTER test --concurrency=2` in the background, with Monitor streaming the step and pass/fail counts every minute.
- **Commits and runs.**
  - One commit per task. Messages are in Vietnamese, written to a file and committed with `git commit -F <file>`. They end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - No push, PR, deploy, `bootstrap.mjs`/`verify.mjs` run, `publish*.sh` run, or `tool/e2e/*.mjs` run. Check scripts with `node --check` or `bash -n`.

## Review Focus

1. **Mode boundary.** Examples: the tab opens after the server has already pushed today's streak; the lease expires while the tab is open; the server's push arrives while the tab is open. The player must never see the same (kind, key) twice, and must not lose one either.
   - Covered by: the web gating until push state resolves (★4), the `shown` broadcast and ingest marking the localStorage key, and the lease check at every `checkNow`.
   - Tests: Task 16 (`mở tab sau khi máy chủ đã gửi: không hiện lại`, `hết hạn lease khi tab đang mở: loại máy chủ quay về cục bộ đúng lúc`, `máy chủ gửi khi tab đang mở: không hiện hai lần`).
2. **Shared browser, account switch, sign-out.** User B must never receive A's notifications, and an offline sign-out must still stop delivery.
   - Server: register by B re-assigns the row (Task 10). App: any `SignedOut` unsubscribes locally (Task 15). A late register response for the previous user is dropped (Task 15).
3. **Data the helper cannot read, or a non-Vietnamese timezone.** Bad rows must never be guessed at, and DST zones must get correct wall-clock times.
   - Tests: Task 4 (`dữ liệu hỏng`, `múi giờ có đổi giờ`) and Task 5 (`bad_data`, `bad_tz`).
4. **Restart, outage, double tick.** Nothing is sent twice. Late items go out only while `now < validUntil`.
   - Test: Task 11 (`hai nhịp chạy chồng / khởi động lại giữa lúc gửi: không gửi lần hai`, `quá validUntil: không gửi`).
5. **Hostile input to the public endpoints.** Cases: a register `endpoint` on a non-push host (SSRF), oversized bodies, a bad timezone, a DELETE of someone else's device id, a forged ack.
   - Tests: Task 10.

## Plan's calls

The spec leaves these choices open; the plan decides. Tasks cite them as ★n.

1. **Exact id hash on web.**
   - `planNotifications` hashes with FNV-1a, using `(h ^ u) * 0x01000193`. Under dart2js the product exceeds 2^53 and loses bits.
   - Measured on 2026-10-30 with the same three strings: VM gives `584550035, 440920331, 1740249913`; JS gives `1534211584, 944940448, 1825882112`.
   - So the spec's "cùng id" is false on web today. Task 2 makes the multiply exact (split into two products below 2^53). VM output is unchanged, so native ids do not move.
   - Web ids change, which is harmless: web de-duplicates by the localStorage key `kind:key`, not by id.
2. **`seedFingerprint` is computed from what the device actually plans with.**
   - The app hashes the drills and knowledge in its DB, in DB order. The helper hashes `seedDrills`/`seedKnowledge`.
   - `pickDrillInCategory` sorts by level with an unstable sort, so list order matters. Old devices whose DB order or rows differ get a different fingerprint, and keep `recommendation` local.
   - Numbers enter the canonical string as `(x * 1000).round()`, because `1.0.toString()` differs between VM and web.
3. **Lease.**
   - The server sets `lease_until = now + 6 h` on register and renews it each cycle for healthy devices (`failure_count == 0`) while enabled. It sends to a device only while `now < lease_until − 5 min`.
   - The app learns the lease from register responses (launch, resume, sign-in, permission grant, every 30 min while open). It masks server kinds until `localNow + (leaseUntil − serverNow)`, which absorbs clock skew.
   - Accepted residue: an open app that cannot reach the server for over 6 h while the server can still push may overlap. The `shown` broadcast (★4) still stops a second display in that tab.
4. **Web start gating.**
   - Until `PushService` resolves (refresh and deliveries pull done, or 10 s timeout), the web `checkNow` shows nothing. A still-valid stored lease resolves immediately.
   - Ingested deliveries write the same localStorage key P6a uses, so a local re-show of a server-delivered (kind, key) cannot happen.
   - The service worker posts `{type:'shown',…}` on `BroadcastChannel('pcai-push')`. Open tabs record it at once.
5. **Due-time recompute uses P6a's web algorithm.**
   - At a due instant the helper plans from the device's local start of day and keeps items with `at ≤ now < validUntil`. The recommendation baseline uses the real `now`, as `NotificationService.checkNow` does on web.
   - The 15-minute cycle runs the same `due` pass, as catch-up after a restart, and an `upcoming` pass (next 24 h) to fill the due queue.
6. **No `notification_settings` row means no server sends** for that person. Server defaults could contradict a choice the device has not synced yet.
7. **Undecodable data means nothing is sent.** The helper returns `bad_data` for that person and the cycle skips them.
   - Exception, mirroring the app: if the BU snapshot fails to assemble, plan without BU. The app does this when `latestBuResultProvider` errors (`buFailed` in `recommendationInputsProvider`).
8. **Daily cap.** At most 12 distinct (kind, key) claims per person in the trailing 24 h, across all devices. It is a bug guard.
9. **Inbox truth.**
   - A row reaches "Đã gửi" only when `shown_at` is set (the service worker acknowledged) or when the open tab received the `shown` broadcast.
   - A failed ack means the inbox under-reports. It never over-claims.
   - The recommendation baseline counts deliveries with `sent_at` set, so the same pair is not pushed on two days.
10. **Retries.** On 429/5xx (the push service definitely did not accept), retry twice: after 2 s, then after 8 s (`Retry-After` honoured up to 60 s). On network errors or timeouts, do not retry (the outcome is ambiguous, and at-most-once wins).
11. **Endpoints.**
    - `GET /push/devices/current` from the research is dropped: register returns the full state.
    - `DELETE /push/devices/:id` always answers 204 and deletes only the caller's own row.
    - `POST /push/ack` always answers 204.
    - A register `endpoint` must be https on an allow-listed push host: `fcm.googleapis.com`, `*.push.services.mozilla.com`, `*.notify.windows.com`, `*.push.apple.com`.
12. **Settings sync.**
    - One row per person: `id` is the user id, owned like `player_goals`.
    - Two last-writer-wins groups: the prefs (`prefs_updated_at`) and the seen pair (`last_seen_at`). Each PATCH sends only the changed group.
    - The P6a shared_preferences stores stay as the offline cache and as the migration source. If the remote row is absent, the local values are uploaded once; otherwise the remote wins.
    - Category names are stored whole (no `_ext` split): the collection is new and no old build reads it.
13. **Sign-out.** Any `SignedOut` (auto or pressed) unsubscribes locally, which works offline and makes the next send 404/410. The pressed sign-out also calls `DELETE` first, with the token, under a 5 s timeout.
14. **VAPID public key.**
    - It is embedded at build (spec §4) via `--dart-define=VAPID_PUBLIC_KEY`. `deploy/publish.sh` requires it from the environment.
    - An empty key (CI, previews) means push is unavailable, so the app stays local.
    - If `/push/config.publicKey` differs from the build key, the app stays local. The server also returns 409 `vapid_mismatch`.
15. **Helper build.** Cross-compiling works from this Windows machine (verified, see Task 5). So:
    - `deploy/publish-notify.sh` builds `--target-os linux --target-arch x64` locally from a clean commit.
    - CI compiles natively on ubuntu for tests.
    - The Dockerfile refuses a non-x86_64 host and runs `--self-test` at build time.
16. **Timezone in the helper.**
    - The container runs with `TZ=UTC`. The helper builds device wall-clock `DateTime`s with `package:timezone`.
    - The helper refuses to start in a process zone that has DST transitions.
    - Accepted: in DST zones, wall-clock arithmetic across a transition (for example the schedule horizon edge) can differ from the device by an hour. Vietnam has no DST.
17. **Service-worker tests** live in `server/notify/test/sw.test.mjs` and load `web/push/sw.js` into a `node:vm` context with fakes. Nothing test-only ships in `build/web`.
18. **Taps with several tabs.** The worker focuses one tab and broadcasts `{type:'tap', payload}`. Only a tab with `document.visibilityState === 'visible'` acts on it.
19. **The P6b-2 seams.**
    - Dart: `PushChannel { web, fcm }` and `PushPlatform.channel`.
    - Directus: `push_devices.channel`, `fcm_token`, `verified_at`, `last_ack_at`.
    - Node: `createSenders({web, fcm})` keyed by `device.channel`. Register answers 400 `unsupported_channel` for `fcm` until P6b-2.

---

## P6b-0: chuẩn bị

### Task 1: lib/domain không còn phụ thuộc Flutter

**Files:**
- Create: `lib/core/theme/skill_category_colors.dart`
- Modify: `lib/domain/skill_category.dart`, `lib/core/widgets/pc_skill_chip.dart`
- Test: `test/domain/skill_category_test.dart`, `test/core/widgets/pc_skill_chip_test.dart`, `test/architecture_test.dart`

**Interfaces:**
- Produces:
  - `extension SkillCategoryColors on SkillCategory { Color get fg; Color get bg; Color get borderColor; }`, using the exact nine colour triples now in the enum constructor (spec 2026-09-17 §4.1).
  - `enum SkillCategory` keeps its members, its order and `isAdvanced`. It loses its constructor fields and its `package:flutter` import.

- [ ] **Step 1: Setup.** Run `$ENV $FLUTTER pub get`, then `$ENV $DART run build_runner build --delete-conflicting-outputs`. Expected: both exit 0.
- [ ] **Step 2: Write the failing test.** In `test/architecture_test.dart` add:

```dart
test('lib/domain, lib/core/strings, lib/data/seed không phụ thuộc Flutter (helper máy chủ biên dịch được)', () {
  final files = [...dartFilesIn('lib/domain'), ...dartFilesIn('lib/core/strings'), ...dartFilesIn('lib/data/seed')];
  final offenders = [for (final f in files) if (RegExp(r"package:flutter|dart:ui").hasMatch(codeOnly(f.readAsStringSync()))) f.path.replaceAll(r'\', '/')];
  expect(files, isNotEmpty);
  expect(offenders, isEmpty);
});
```

  Add `import 'package:poolcoachai/core/theme/skill_category_colors.dart';` to the two colour tests.
- [ ] **Step 3: Run it to verify it fails.** Run `$ENV $FLUTTER test test/architecture_test.dart`. Expected: FAIL, offender `lib/domain/skill_category.dart`.
- [ ] **Step 4: Implement** the Interfaces. `pc_skill_chip.dart` imports the extension.
- [ ] **Step 5: Run the tests.** Run `$ENV $FLUTTER test test/architecture_test.dart test/domain/skill_category_test.dart test/core/widgets`, then `$ENV $FLUTTER analyze`. Expected: PASS, no issues.
- [ ] **Step 6: Commit.** Message: `P6b-0: màu nhóm kỹ năng chuyển sang extension giao diện, lib/domain không còn import Flutter`, plus the trailer.

---

### Task 2: Exact notification id on web, and seedFingerprint

**Files:**
- Modify: `lib/domain/notifications/notification_plan.dart`, `.github/workflows/android.yml`
- Create: `lib/domain/notifications/seed_fingerprint.dart`
- Test: `test/domain/notifications/notification_id_test.dart` (create), `test/domain/notifications/seed_fingerprint_test.dart` (create)

**Interfaces:**
- Produces:
  - `int notificationIdHash(String text)` in `notification_plan.dart`. It replaces the private `_hash`, and `planNotifications` calls it. It is FNV-1a 32 bit with the sign bit dropped, computed exactly on every platform:

```dart
// prime 0x01000193 = 2^24 + 0x193; mỗi tích < 2^53 nên đúng cả trên dart2js.
final x = hash ^ unit;
hash = ((x & 0xff) * 0x1000000 + x * 0x193) & 0xffffffff;
```

  - `String seedFingerprint({required List<Drill> drills, required List<KnowledgeArticle> knowledge})` in `seed_fingerprint.dart` (no Flutter, no `Vi`).
    - The canonical string has one line per drill in list order: `d|<id>|<cat.name>|<name>|<level>|<milli(passThreshold)>|<milli(target)>`. `milli(x)` is `(x * 1000).round()`, or empty when null.
    - Then one line per article: `k|<id>|<cat.name>|<relatedDrillIds joined by ','>`.
    - Lines are joined with `\n`. The result is `'v1-<drill count>-<knowledge count>-<8 lowercase hex digits of the FNV-1a 32-bit hash of the canonical string>'`. Use `notificationIdHash`'s arithmetic without the sign mask; factor a private `_fnv32` shared by both.

- [ ] **Step 1: Write the failing tests.**

```dart
// notification_id_test.dart
int fnvReference(String s) { var h = BigInt.from(0x811c9dc5); for (final u in s.codeUnits) { h = ((h ^ BigInt.from(u)) * BigInt.from(0x01000193)) & BigInt.from(0xffffffff); } return (h & BigInt.from(0x7fffffff)).toInt(); }
test('id thông báo là FNV-1a 32 bit chuẩn, đúng trên mọi nền tảng', () {
  final r = Random(7);
  final samples = ['', 'abc', '${NotificationKind.streak.name}|2026-10-30|${DateTime(2026, 10, 30, 20).toIso8601String()}|${Vi.streakReminderTitle}|${Vi.streakReminderBody(3)}',
    for (var i = 0; i < 300; i++) String.fromCharCodes([for (var j = 0; j < 1 + r.nextInt(80); j++) r.nextInt(0x10000)])];
  for (final s in samples) { expect(notificationIdHash(s), fnvReference(s), reason: s); }
});
// seed_fingerprint_test.dart (testDrills/testKnowledge từ test/support/test_data.dart)
test('dấu vân tay: theo đúng dạng chuẩn', …);        // tự dựng chuỗi chuẩn theo Interfaces, so với 'v1-…-${hex(fnvReference-không-mask)}'
test('đổi thứ tự, tên, cấp, ngưỡng, target hoặc liên kết bài đọc: dấu đổi', …);
test('đổi bước tập hay mục tiêu chữ: dấu giữ nguyên', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/notifications`. Expected: compile errors (`notificationIdHash` and `seedFingerprint` are undefined).
- [ ] **Step 3: Implement** the Interfaces. In `android.yml`, after `flutter test`, add the step `- run: flutter test --platform chrome test/domain/notifications/notification_id_test.dart test/domain/notifications/seed_fingerprint_test.dart`.
- [ ] **Step 4: Run the tests on the VM and in Chrome.** Run `$ENV $FLUTTER test test/domain/notifications`, then `$ENV $FLUTTER test --platform chrome test/domain/notifications/notification_id_test.dart test/domain/notifications/seed_fingerprint_test.dart`, then `$ENV $FLUTTER analyze`.
  - Expected: PASS in both runs. The existing `notification_plan_test.dart` id tests stay green unchanged, which proves the VM ids did not move.
  - Before implementing, the Chrome run of the first test must FAIL. Record that.
- [ ] **Step 5: Commit.** Message: `P6b-0: id thông báo tính đúng cả trên web (FNV không mất bit), thêm seedFingerprint`, plus the trailer.

---

### Task 3: Pure Directus codecs, shared by sync and helper

**Files:**
- Create: `lib/data/remote/codecs/remote_values.dart`, `remote_fields.dart`, `practice_codecs.dart`, `cue_equipment_codec.dart`, `assessment_codecs.dart`
- Modify:
  - `lib/data/database/converters.dart` (`fromRemoteDrillLog`)
  - `lib/data/database/match_codec.dart` (gains `poolMatchFromColumns`)
  - `lib/data/database/assessment_converters.dart` (`fromRemoteTest`, `fromRemoteResult`, `attemptsOfRow`; the field constants move)
  - `lib/data/repositories/drift_match_repository.dart` (`_toDomain` calls `poolMatchFromColumns`)
  - `lib/data/sync/practice_sync.dart` (`_matchFromRemote` and the timer/slot pull loops)
  - `lib/data/sync/cue_equipment_sync.dart` (`_fromRemote`, `_remoteDeleted`)
  - `lib/data/sync/sync_service.dart` (inline drill-log fields)
- Test: `test/data/remote/codecs/practice_codecs_test.dart`, `cue_equipment_codec_test.dart`, `assessment_codecs_test.dart` (create); `test/architecture_test.dart`

**Interfaces:**
- Shared rule: `typedef ToLocal = DateTime Function(DateTime utc);`. The default `defaultToLocal` is `(u) => u.toLocal()`, so the app path is unchanged. Every instant a codec returns as "local" goes through `toLocal`; UTC metadata (`updated_at`) stays UTC. Codecs do not truncate. The helper (Task 4) passes a `toLocal` that truncates to whole seconds, as Drift does on the app path.
  - The validation rules and `FormatException` messages move verbatim from the sync code. Behaviour does not change.
- `remote_values.dart`: `String remoteString(Map<String, Object?> item, String key)`, `String? remoteNullableString(...)`, `DateTime remoteInstant(...)` (UTC), `DateTime? remoteNullableInstant(...)`, `String remoteOwner(...)`, `DateTime wholeSeconds(DateTime d)`. These are the bodies of `_string`/`_nullableString`/`_date`/`_owner` in `practice_sync.dart`.
- `remote_fields.dart` holds the field-list constants, moved from the sync files with their names and values unchanged: `poolMatchRemoteFields`, `timerSessionRemoteFields`, `scheduleSlotRemoteFields`, `cueEquipmentRemoteFields`, `remoteTestFields`, `remoteResultFields`, and a new `drillLogRemoteFields = 'id,drill_id,date,score,attempts,notes,duration_sec'`. The old files `export` them, so existing imports and tests stay unchanged.
- `practice_codecs.dart`:
  - `DrillLog drillLogFromRemote(Map<String, Object?> json, {ToLocal toLocal = defaultToLocal})`
  - `TimerSession timerSessionFromRemote(Map<String, Object?> item, {ToLocal toLocal = defaultToLocal})`, with the duration and `cat` validation and `joinCategoryName`.
  - `({ScheduleSlot slot, DateTime updatedAtUtc, bool isDeleted}) scheduleSlotFromRemote(Map<String, Object?> item)`, with the `cat_ext_at == updated_at` trust rule.
  - `final class RemotePoolMatch { id, gameType, playerName, opponentName, targetRacks, rackWinnersJson, shotsJson, cueId, startedAt (local), completedAt (local?), updatedAtUtc, isDeleted, tournamentId, roundLabel }` and `RemotePoolMatch poolMatchFromRemote(Map<String, Object?> item, {ToLocal toLocal = defaultToLocal})`. It re-encodes the raw JSON exactly as `_matchFromRemote` does, and test-decodes it.
- `match_codec.dart`: `PoolMatch poolMatchFromColumns({required String id, required String gameType, …, required String rackWinnersJson, required String shotsJson, required DateTime startedAt, DateTime? completedAt, …})`. This is today's `DriftMatchRepository._toDomain` body; the repository and the helper both call it.
- `cue_equipment_codec.dart`: `({CueEquipment cue, bool isDeleted}) cueEquipmentFromRemote(Map<String, Object?> item, {ToLocal toLocal = defaultToLocal})`. It holds the bodies of `_fromRemote` and `_remoteDeleted`. A date-only value stays local midnight; any other timestamp goes through `toLocal`.
- `assessment_codecs.dart`:
  - `BuTest buTestFromRemote(Map<String, Object?> j, {ToLocal toLocal = defaultToLocal})`
  - `({String id, String testId, String drillId, String attemptsJson, int? score, DateTime recordedAt}) buDrillResultFromRemote(Map<String, Object?> j, {ToLocal toLocal = defaultToLocal})`
  - `DrillAttempts drillAttemptsFromJson(String attemptsJson)`, which `attemptsOfRow` calls.
  - `fromRemoteTest`/`fromRemoteResult` build their companions from these records.
- Imports: codec files import only `dart:convert`, domain, `category_compat.dart` and `match_codec.dart`. Never drift, `database.dart`, sync or Flutter.

- [ ] **Step 1: Write the failing tests.** Fixed values only. Pass `toLocal: (u) => u.add(const Duration(hours: 7))` so the injection is observable.

```dart
test('buổi tập: đọc đúng trường, giờ qua toLocal được tiêm', …);   // date '2026-10-13T01:02:03.987Z' → DateTime.utc(2026,10,13,8,2,3,987)
test('wholeSeconds: bỏ phần lẻ giây như Drift', …);
test('buổi tập tự do: nhóm _ext lạ bị bỏ, cat lạ hay thời lượng ≤ 0 ném FormatException', …);
test('lịch tập: cat_ext chỉ tin khi cat_ext_at bằng updated_at; giờ sai dạng ném', …);
test('trận: giữ nguyên JSON thô của rack và cú đánh; JSON hỏng ném; poolMatchFromColumns đọc lại đúng', …);
test('cơ: ngày chỉ-ngày giữ nửa đêm; độ cứng lạ ném; is_deleted không phải bool ném', …);
test('BU: lần kiểm tra và kết quả đọc đúng; attempts hỏng ném khi giải mã', …);
// architecture_test.dart
test('bộ giải mã Directus thuần: không import drift, database, sync hay Flutter', () {
  final files = dartFilesIn('lib/data/remote/codecs');
  expect(files, isNotEmpty);
  for (final f in files) { expect(codeOnly(f.readAsStringSync()), isNot(matches(RegExp(r"package:(drift|flutter)|database\.dart|/sync/"))), reason: f.path); }
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/remote/codecs test/architecture_test.dart`. Expected: compile errors.
- [ ] **Step 3: Implement** the Interfaces. Move code; do not rewrite it. Each sync call site keeps its own loop, transaction, owner check and comparison logic, and only replaces the inline decoding with the codec call.
- [ ] **Step 4: Run the tests and the behaviour gate.**
  - Run the codec tests, then `$ENV $FLUTTER test test/data/sync test/data/database test/data/repositories`, then `$ENV $FLUTTER analyze`.
  - Expected: PASS with **no change** to any existing test file. That includes `old_build_compat_test.dart`, `practice_sync_test.dart`, `cue_equipment_sync_test.dart` and `assessment_sync_test.dart`.
- [ ] **Step 5: Commit.** Message: `P6b-0: tách bộ giải mã dòng Directus thuần (dùng chung cho đồng bộ và helper), hành vi đồng bộ giữ nguyên`, plus the trailer.

---

### Task 4: The server-side planner core (same output as the app)

**Files:**
- Create: `lib/server/notify_plan.dart`, `test/support/push_fixtures.dart`
- Test: `test/server/notify_plan_test.dart`, `test/server/notify_plan_parity_test.dart` (create)

**Interfaces:**
- Consumes: Task 2 `notificationIdHash`, `seedFingerprint`. Task 3 codecs, `poolMatchFromColumns`, `drillAttemptsFromJson`. Also `planNotifications`, `streakStateOf`, `RecommendationInputs`, `recommendationBaseline`, `notificationPayload`, `latestCompletedTestId`, `buResultFrom`.
- Produces (in `lib/server/notify_plan.dart`; no Flutter, drift or seed import):
  - `abstract interface class WallClock { DateTime local(DateTime utc); DateTime utc(DateTime local); }` and `final class TzWallClock implements WallClock { TzWallClock(String ianaName); }`.
    - The constructor throws `ArgumentError` on an unknown zone, after `initializeTimeZones()` from `package:timezone/data/latest_all.dart`, run once.
    - `local` returns a process-local `DateTime` carrying the zone's wall-clock fields. `utc` goes through `tz.TZDateTime(location, …).toUtc()`.
  - `enum NotifyPlanMode { upcoming, due }`.
  - `final class NotifyPlanRequest { const NotifyPlanRequest({required String userId, required DateTime nowUtc, required String tz, required NotifyPlanMode mode, required NotificationPrefs prefs, required ({SkillCategory cat, String drillId, DateTime atUtc})? seen, required List<({String key, DateTime atUtc})> sentRecommendations, required Map<String, List<Map<String, Object?>>> data}); }`
    - `data` keys are `drill_logs`, `timer_sessions`, `schedule_slots`, `cue_equipment`, `pool_matches`, `bu_tests`, `bu_drill_results`.
  - `final class ServerPlannedNotification { final PlannedNotification local; final DateTime atUtc; final DateTime validUntilUtc; final String payload; }`
  - `final class NotifyPlanDataError implements Exception { const NotifyPlanDataError(this.collection); final String collection; }`
  - `List<ServerPlannedNotification> planForUser(NotifyPlanRequest r, {required List<Drill> drills, required List<KnowledgeArticle> knowledge, required WallClock clock})`. Algorithm:
    1. Decode each collection with the Task 3 codecs, `toLocal: (u) => clock.local(wholeSeconds(u))`. Any `FormatException`/`TypeError` throws `NotifyPlanDataError(collection)` (★7).
    2. Reproduce the repositories' filters and order exactly:
       - drill logs ascending by `date`;
       - timer sessions descending by `date`;
       - slots without `isDeleted`, by (`day`, `time`);
       - cues without `isDeleted`, by `name`;
       - matches without `isDeleted`, by `startedAt` descending then `id` ascending.
       Use a stable sort that keeps input order on ties.
    3. `latestBu`: `latestCompletedTestId` over the decoded tests, then a `TestSnapshot` from that test's results (`attempts`, `touched`), then `buResultFrom`. The whole step sits in try/catch, giving `null` on any error, which mirrors `buFailed` (★7).
    4. Set `now = clock.local(r.nowUtc)`, `from = mode == due ? DateTime(now.year, now.month, now.day) : now`.
    5. `seen` becomes `SeenRecommendation(cat:, drillId:, at: clock.local(atUtc))`. `sentRecommendations` become `NotificationLogEntry(id: 0, kind: recommendation, key:, at: clock.local(atUtc), title: '', body: '')` for `recommendationBaseline(shownOnHome: seen, log: …, now: now)`.
    6. Call `planNotifications(cues:, slots:, streak: streakStateOf(logs:, timerSessions:, today: from), prefs: r.prefs, now: from, recommendation: RecommendationInputs(drills:, logs:, knowledge:, timerSessions:, schedule: slots, matches:, latestBu:), lastSeenRecommendation: baseline, limit: mode == due ? 1 << 20 : maxPendingNotifications)`.
    7. Keep `due`: `!at.isAfter(now) && now.isBefore(validUntil)`. Keep `upcoming`: `at.isBefore(now.add(const Duration(hours: 24)))`.
    8. Map each kept item to `ServerPlannedNotification` with `atUtc: clock.utc(at)`, `validUntilUtc: clock.utc(validUntil)` and `payload: notificationPayload(kind, key, userId: r.userId)`.
- `test/support/push_fixtures.dart`: `Map<String, List<Map<String, Object?>>> richRemoteData({required DateTime nowUtc})`. It returns Directus-shaped rows that make every kind appear:
  - drill logs on the two previous days, none today, for streak ≥ 2;
  - a slot starting later today, more than 30 min ahead;
  - a cue due inside 7 days;
  - two matches;
  - a completed BU test with results;
  - one soft-deleted slot and one soft-deleted match.
  - It also exposes `HostWallClock` (`local = toLocal`, `utc = toUtc`) for parity in the host zone.

- [ ] **Step 1: Write the failing tests.**

```dart
// notify_plan_parity_test.dart: đường app thật
test('đường app và đường máy chủ cho cùng kế hoạch: cùng id, kind, key, giờ, chữ', () async {
  // 1) FakeDirectus trả richRemoteData cho mọi GET; FakeAuthRepository.signedIn('u1');
  // 2) chạy pull thật của SyncService, PracticeSyncService, CueEquipmentSyncService, AssessmentSyncService
  //    vào AppDatabase.forTesting(NativeDatabase.memory()) (như old_build_compat_test); upsertSeed(db);
  // 3) dbContainer(db, clock:) → listen recommendationInputsProvider; đọc cues/slots/logs/timers qua repository như NotificationService;
  // 4) expected = planNotifications(... now: nowLocal ...) lọc < now+24h;
  // 5) actual = planForUser(req(mode: upcoming), drills: seedDrills, knowledge: seedKnowledge, clock: HostWallClock()).map((s) => s.local);
  expect(actual.map(sig), expected.map(sig));   // sig = '${id}|${kind.name}|${key}|${at}|${validUntil}|${title}|${body}'
  expect(NotificationKind.values.every((k) => actual.any((n) => n.kind == k)), isTrue);
});
test('chế độ due giống web P6a: lập từ đầu ngày, chỉ mục at ≤ now < validUntil', …);   // so với planNotifications(now: startOfDay, limit: 1<<20) lọc như checkNow
// notify_plan_test.dart
test('múi giờ Asia/Ho_Chi_Minh: nhắc chuỗi 20:00 là 13:00Z', …);
test('múi giờ có đổi giờ (America/New_York): 20:00 trước và sau 1/11/2026 ra đúng UTC', …);
test('chống bịa: đổi nhóm yếu thì thân thông báo gợi ý đổi theo Vi.skill', …);         // derive bằng RecommendationInputs.recommendFor
test('dữ liệu hỏng ở một collection: ném NotifyPlanDataError, không đoán', …);
test('BU hỏng: lập như không có BU (như app khi latestBuResult lỗi)', …);
test('đã gửi gợi ý X hôm qua: hôm nay cùng X không lập lại', …);
test('payload là v2 mang userId', () { expect(parseNotificationPayload(item.payload)!.userId, 'u1'); });
test('dòng đã xoá mềm không tạo nhắc', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/server`. Expected: compile errors.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Run `$ENV $FLUTTER test test/server test/domain/notifications`, then `$ENV $FLUTTER analyze`. Expected: PASS.
  - If parity fails, fix the helper side: the app is the reference. Never edit a sync path to make parity pass.
- [ ] **Step 5: Commit.** Message: `P6b-0: lõi lập thông báo phía máy chủ chạy đúng planNotifications trên dòng Directus, test so khớp với đường app`, plus the trailer.

---

### Task 5: NDJSON helper, compile checks and architecture rules

**Files:**
- Create: `lib/server/notify_plan_protocol.dart`, `bin/notify_plan.dart`
- Modify: `test/architecture_test.dart`, `.github/workflows/android.yml`
- Test: `test/server/notify_plan_protocol_test.dart` (create)

**Interfaces:**
- Consumes: Task 4 `planForUser`, `NotifyPlanRequest`, `TzWallClock`. Task 2 `seedFingerprint`. Task 3 `remote_fields.dart`.
- Produces:
  - `const notifyPlanProtocolVersion = 1;`
  - `String handleNotifyPlanLine(String line, {required List<Drill> drills, required List<KnowledgeArticle> knowledge})` never throws. Wire format, one JSON object per line:
    - `{"v":1,"op":"info","reqId":"…"}` → `{"v":1,"reqId":"…","ok":true,"fingerprint":"<seedFingerprint>","kinds":["recommendation","maintenance","schedule","streak"],"fields":{"drill_logs":"…","timer_sessions":"…","schedule_slots":"…","cue_equipment":"…","pool_matches":"…","bu_tests":"<remoteTestFields>,user_created","bu_drill_results":"<remoteResultFields>,user_created"}}`. The field strings are the Task 3 constants, with `,user_created` appended only where it is absent (so `pool_matches` equals `poolMatchRemoteFields` exactly).
    - `{"v":1,"op":"plan","reqId":"…","userId":"…","nowUtc":"<ISO Z>","tz":"<IANA>","mode":"upcoming"|"due","prefs":{"recommendation":bool,"maintenance":bool,"schedule":bool,"streak":bool},"seen":{"cat":"…","drillId":"…","atUtc":"…"}|null,"sentRecommendations":[{"key":"…","atUtc":"…"}],"data":{…}}` → `{"v":1,"reqId":"…","ok":true,"fingerprint":"…","items":[{"id":int,"kind":"…","key":"…","at":"<local ISO, no offset>","atUtc":"<ISO Z>","validUntil":"…","validUntilUtc":"…","title":"…","body":"…","payload":"…"}]}`
    - Errors: `{"v":1,"reqId":<string or null>,"ok":false,"error":"bad_json"|"bad_request"|"unsupported_version"|"bad_tz"|"bad_data"}`. `bad_data` adds `"collection":"…"`.
  - `bin/notify_plan.dart` `main(List<String> args)`:
    - **Zone guard (★16).** If the process zone's `timeZoneOffset` differs between any two of the 13 monthly samples from now − 6 months to now + 6 months, write `Múi giờ tiến trình có đổi giờ — chạy với TZ=UTC` to stderr and `exit(2)`.
    - `--self-test`: print the `info` reply and the reply of a `due` plan with empty data, then exit 0 only if both are `ok`.
    - Otherwise read stdin with `utf8.decoder` and `LineSplitter`, and for each non-empty line write `handleNotifyPlanLine(line, drills: seedDrills, knowledge: seedKnowledge)` followed by a newline. Flush. Exit 0 when stdin closes.
    - This is the only file outside `lib/data/seed` and `upsert_seed.dart` that names `seedDrills`/`seedKnowledge`.
- `.github/workflows/android.yml`: after `flutter analyze`, add `- run: dart compile exe bin/notify_plan.dart -o build/notify_plan` and `- run: build/notify_plan --self-test`. This catches any Flutter import leaking into the closure.

- [ ] **Step 1: Write the failing tests.**

```dart
test('info: dấu vân tay của seed, bốn loại, trường đủ cho từng collection', () {
  final r = jsonDecode(handleNotifyPlanLine('{"v":1,"op":"info","reqId":"i"}', drills: seedDrills, knowledge: seedKnowledge));
  expect(r['fingerprint'], seedFingerprint(drills: seedDrills, knowledge: seedKnowledge));
  expect((r['fields'] as Map)['pool_matches'], poolMatchRemoteFields);
});
test('plan: items bằng planForUser cùng đầu vào (TzWallClock)', …);
test('dòng không phải JSON: ok:false bad_json, không ném', …);
test('phiên bản lạ: unsupported_version; thiếu trường: bad_request; tz lạ: bad_tz', …);
test('dữ liệu hỏng: bad_data kèm tên collection', …);
test('reqId được trả lại nguyên vẹn', …);
// architecture_test.dart
test('lib/server thuần: không Flutter, không drift/database/sync, không đọc seed', …);
test('ngoài upsertSeed, chỉ bin/notify_plan.dart (helper máy chủ, không có DB) được đọc seed', () {
  // quét lib/ và bin/; ngoại lệ đúng hai: lib/data/database/upsert_seed.dart và bin/notify_plan.dart; bin/notify_plan.dart phải có mặt
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/server/notify_plan_protocol_test.dart test/architecture_test.dart`. Expected: compile errors or FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests and compile the helper.**
  - Run the two test files and `$ENV $FLUTTER analyze`.
  - Then `$ENV $DART compile exe bin/notify_plan.dart -o build/notify_plan.exe` and `build/notify_plan.exe --self-test`. Expected: exit 0, two `"ok":true` lines.
  - Then cross-compile: `$ENV $DART compile exe bin/notify_plan.dart --target-os linux --target-arch x64 -o build/notify_plan_linux` and `file build/notify_plan_linux`. Expected: `ELF 64-bit LSB pie executable, x86-64 … interpreter /lib64/ld-linux-x86-64.so.2` (glibc, which is why the image is bookworm, not alpine).
  - Plan-time evidence (2026-10-30): the bundled Dart is **3.13.0**. A trivial program cross-compiled from this Windows machine produced exactly that ELF. Compiling `notification_plan.dart` before Task 1 failed on `dart:ui`, through `skill_category.dart`.
- [ ] **Step 5: Commit.** Message: `P6b-0: helper bin/notify_plan.dart nói NDJSON, CI biên dịch và tự kiểm helper, luật kiến trúc cho lib/server`, plus the trailer. Do not commit anything under `build/`.

---

## P6b-1: Web Push và backend

### Task 6: Directus collections, PushService role, bootstrap and verify

**Files:**
- Create: `deploy/directus/push_service_fields.json`
- Modify: `deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs`, `deploy/directus/env.example`, `lib/data/remote/codecs/remote_fields.dart`
- Test: `test/server/push_service_fields_test.dart` (create)

**Interfaces:**
- Produces in `remote_fields.dart`:
  - `const notificationSettingsRemoteFields = 'id,recommendation,maintenance,schedule,streak,prefs_updated_at,last_seen_cat,last_seen_drill_id,last_seen_at,timezone';`
  - `const pushDeliveryRemoteFields = 'id,device,notification_id,kind,key,title,body,at,shown_at';`
- `push_service_fields.json` maps each of the seven helper collections plus `notification_settings` to the field list the service may read. It is the helper `info.fields` list split on `,`, plus `user_created`.
- `bootstrap.mjs`, after `tournaments`, using the existing helpers:
  - `notification_settings`, owned:
    - `pk`
    - `recommendation`/`maintenance`/`schedule`/`streak`: `{type:'boolean', schema:{is_nullable:false, default_value:true}}`
    - nullable `prefs_updated_at` timestamp, `last_seen_cat` string, `last_seen_drill_id` string, `last_seen_at` timestamp, `timezone` string
  - `push_devices`, `{ owned: false }`, plus `ensureUserRelation('push_devices','user')`:
    - `id` string PK `max_length: 64`
    - `user` uuid, required
    - `channel` string, required; `platform` string, required
    - nullable `endpoint` text, `key_p256dh` string, `key_auth` string, `fcm_token` text
    - `timezone` string, required; nullable `seed_fingerprint` string; `mode` string, required
    - `server_kinds` json, required
    - nullable `lease_until`, `verified_at`, `last_success_at`, `last_ack_at` timestamps
    - `last_seen_at` timestamp, required; `failure_count` integer, required, default 0; `created_at` timestamp, required
  - `push_deliveries`, `{ owned: false }`, plus `ensureUserRelation('push_deliveries','user')`:
    - `id` string PK 64; `user` uuid, required; `device` string 64, required
    - `notification_id` integer, required; `kind` string, required; `key` string, required
    - `title` text, required; `body` text, required; `at` timestamp, required
    - nullable `sent_at` and `shown_at` timestamps
  - Player permissions (appended to `desiredPermissions`):
    - `notification_settings`:
      - create: the fields of `notificationSettingsRemoteFields`, `validation: { id: { _eq: '$CURRENT_USER' } }`
      - read: `['*']` where `user_created: self`
      - update: the same fields minus `id`, where `user_created: self`
    - `push_deliveries` read: fields `pushDeliveryRemoteFields` + `user`, `permissions: { user: { _eq: '$CURRENT_USER' } }`
    - **Nothing** on `push_devices`.
  - Role and policy `PushService` (icon `notifications`), linked like CoachChatService. `replacePermissions` with:
    - read on the eight collections, `fields` from the JSON file (read with `fs.readFileSync(new URL('./push_service_fields.json', import.meta.url))`), `permissions: {}`
    - create/read/update/delete on `push_devices` and `push_deliveries`, `fields: ['*']`
  - Service user `push-service@poolcoachai.example.com`, token from `PUSH_SERVICE_TOKEN`. Copy the coach-chat block and never print the token.
- `verify.mjs` block after coach-chat, with a temporary PushService user like the coach-chat block. It checks:
  - (a) A gets 403 on GET/POST/PATCH of `push_devices`.
  - (b) The service creates a delivery for A and one for B. A reads only its own, B sees none of A's, and A cannot POST or PATCH deliveries.
  - (c) `notification_settings`: A creates with `id = A`, gets 403 creating with `id = B`, reads and patches its own, and B cannot read A's.
  - (d) The service GETs each collection with `fields` from the JSON file and a `filter[user_created][_eq]=A`, and gets 200. It gets 403 on PATCH/DELETE of A's `drill_logs`.
  - (e) The service has CRUD on `push_devices`.
  - (f) After the users are deleted in `finally`, no `push_devices` or `push_deliveries` row of A remains (CASCADE).
  - (g) The real `push-service@…` user has role `PushService` and a token. Print only `có`/`không có`.
- `env.example` documents `PUSH_SERVICE_TOKEN=` under the bootstrap-only section.

- [ ] **Step 1: Write the failing test.** In `push_service_fields_test.dart`, `test('quyền đọc của PushService khớp đúng trường helper xin (cộng user_created)', …)`. It parses the JSON file and, for each collection, compares the field set to the `info.fields` value from `handleNotifyPlanLine` (split, plus `user_created`), and `notification_settings` to `notificationSettingsRemoteFields` plus `user_created`.
- [ ] **Step 2: Run it to verify it fails.** Run `$ENV $FLUTTER test test/server/push_service_fields_test.dart`. Expected: FAIL (the file is missing).
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Check.** Run the test, `$ENV node --check deploy/directus/bootstrap.mjs` and `$ENV node --check deploy/directus/verify.mjs`. Expected: PASS, exit 0. **Do not run either script.**
- [ ] **Step 5: Commit.** Message: `P6b-1: Directus thêm notification_settings, push_devices, push_deliveries, role PushService; verify kiểm quyền và CASCADE`, plus the trailer.

---

### Task 7: server/notify scaffold, image, CI and deploy script

**Files:**
- Create in `server/notify/`: `package.json`, `package-lock.json`, `Dockerfile`, `src/config.mjs`, `src/limits.mjs`, `src/directus.mjs`, `src/auth.mjs`, `src/log.mjs`, `src/http.mjs`, `src/server.mjs`, `src/main.mjs`, `test/fakes.mjs`, `test/config.test.mjs`, `test/directus.test.mjs`, `test/auth.test.mjs`, `test/server.test.mjs`, `test/main.test.mjs`
- Create: `.github/workflows/notify.yml`, `deploy/publish-notify.sh`
- Modify: `.gitignore` (add `server/notify/node_modules/`, `server/notify/bin/`, `*service-account*.json`, `*firebase-adminsdk*.json`)

**Interfaces:**
- `package.json`:
  - `"type":"module"`, `engines.node >=24`, scripts `start`/`test` as in coach-chat.
  - The single dependency is `"web-push": "3.6.7"`, installed with `npm install --save-exact web-push@3.6.7`.
  - If `npm view web-push versions --json` shows a later 3.x published at least 14 days ago, pin that one instead and name it in the commit message.
  - Why `web-push`: it implements RFC 8291 (aes128gcm) and RFC 8292 (VAPID ES256) and is the de-facto Node implementation. Hand-rolled crypto is the riskier path. Task 9 proves it offline.
- `limits.mjs` exports:
  - `CYCLE_MS = 15*60_000`, `TICK_MS = 60_000`
  - `LEASE_MS = 6*3_600_000`, `LEASE_MARGIN_MS = 5*60_000`
  - `DAILY_CAP = 12`, `MAX_DEVICES = 10`, `REGISTER_PER_HOUR = 30`
  - `FAILURES_TO_PRUNE = 5`, `STALE_DEVICE_DAYS = 60`, `DELIVERY_KEEP_DAYS = 30`
  - `HORIZON_MS = 24*3_600_000`, `HELPER_TIMEOUT_MS = 10_000`
  - `MAX_BODY_BYTES = 8192`, `MAX_ACK_BYTES = 2048`
  - `KINDS = ['recommendation','maintenance','schedule','streak']`, `CHANNELS = ['web','fcm']`
  - `PUSH_HOSTS = [/^fcm\.googleapis\.com$/, /\.push\.services\.mozilla\.com$/, /\.notify\.windows\.com$/, /\.push\.apple\.com$/]`
- `config.mjs`: `loadConfig(env)` → `{ port, directusUrl, serviceToken, allowedOrigins, publicUrl, vapid: { publicKey, privateKey, subject }, enabled, planBin }`.
  - Required: `DIRECTUS_URL`, `PUSH_SERVICE_TOKEN`, `ALLOWED_ORIGINS`, `PUBLIC_URL` (https), `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (`https:` or `mailto:`), and `PUSH_ENABLED` (exactly `true` or `false`; a missing value is an error).
  - Optional: `PORT` (8080, validated as in coach-chat) and `NOTIFY_PLAN_BIN` (`/app/bin/notify_plan`).
  - On error it throws `Thiếu hoặc sai biến môi trường: <names>`.
- `directus.mjs`: `createDirectus({ url, serviceToken, fetch, timeoutMs = 10_000 })` returns:
  - `userIdForToken(token)`, copied from coach-chat
  - `listServerDevices()`, `devicesOfUser(userId)`, `getDevice(id)`, `createDevice(row)`, `updateDevice(id, patch)`, `deleteDevices(ids)`
  - `readUserData(userId, fields)`, which resolves `{ drill_logs, timer_sessions, schedule_slots, cue_equipment, pool_matches, bu_tests, bu_drill_results }`, each `GET /items/<c>?filter[user_created][_eq]=<id>&fields=<fields[c]>&limit=-1`
  - `readSettings(userId, fields)`, which resolves the row or `null`
  - `deliveriesOfUser(userId, sinceIso)`
  - `claimDelivery(row)`, which resolves `true`, or `false` on `RECORD_NOT_UNIQUE`
  - `getDelivery(id)`, `updateDelivery(id, patch)`, `deleteDeliveriesBefore(iso)`
  - Errors are `DirectusError(status, code)` as in coach-chat. Every service call carries the Bearer service token.
- `auth.mjs`, `log.mjs`, and the body/CORS helpers in `http.mjs` are copied from coach-chat. `readRawBody(req, maxBytes)`, `corsHeaders`, `sendJson` and `sendNoBody` move into `http.mjs`.
- `server.mjs`: `createApp({ config, directus, planner, scheduler, now, log, fetch })` returns the request handler. In this task it serves:
  - `GET /healthz` → 200 `{ ok: true, enabled, lastCycleAt: scheduler.lastCycleAt?.toISOString() ?? null, helper: planner.healthy ? 'ok' : 'down' }`
  - `GET /push/config` → 200 `{ enabled, publicKey }`, with CORS for allowed origins
  - anything else → 404 `{ error: 'not_found' }`
- `main.mjs`:
  - `loadConfig`. On failure, print the message to stderr and `exit(1)`.
  - Create the planner (Task 8), then `await planner.info()`. If that fails, write `helper không chạy` and `exit(1)`.
  - Create the app and the scheduler (Task 11), `listen`, then `scheduler.start()`.
  - On SIGTERM: `scheduler.stop()`, then `planner.close()`, then `server.close`.
  - In this task the planner and scheduler are the minimal objects Tasks 8 and 11 replace. Keep `main.test.mjs` to the env failure path.
- `Dockerfile`:

```dockerfile
# Dịch vụ notify (spec P6b §3). Easypanel build từ nhánh deploy-notify, nơi publish-notify.sh đặt sẵn bin/notify_plan.
FROM node:24-bookworm-slim
WORKDIR /app
ENV TZ=UTC NODE_ENV=production PORT=8080 NOTIFY_PLAN_BIN=/app/bin/notify_plan
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY bin/notify_plan ./bin/notify_plan
RUN chmod +x ./bin/notify_plan && [ "$(uname -m)" = "x86_64" ] && ./bin/notify_plan --self-test >/dev/null
USER node
EXPOSE 8080
CMD ["node", "src/main.mjs"]
```

- `notify.yml`:
  - Triggers: like `coach-chat.yml`, with paths `server/notify/**`, `web/push/**`, `bin/notify_plan.dart`, `lib/server/**`, `.github/workflows/notify.yml`.
  - One job on `ubuntu-latest`: checkout, then `subosito/flutter-action@v2` (3.47.0), then `flutter pub get`, then `dart compile exe bin/notify_plan.dart -o server/notify/bin/notify_plan`, then setup-node 24 with an npm cache on `server/notify/package-lock.json`, then `npm ci`, then `NOTIFY_PLAN_BIN=bin/notify_plan npm test` in `server/notify`.
- `deploy/publish-notify.sh`, modelled on `publish.sh`:
  - Require a clean tree and record `src=$(git rev-parse --short HEAD)`.
  - Run `"$FLUTTER" pub get`.
  - Create a stage worktree of `origin/deploy-notify`, or an orphan if the branch does not exist.
  - Clear the stage. Run `"$DART" compile exe bin/notify_plan.dart --target-os linux --target-arch x64 -o "$stage/bin/notify_plan"`.
  - Fail unless the first 4 bytes are `\x7fELF`.
  - Copy `server/notify/{package.json,package-lock.json,Dockerfile}` and `server/notify/src`.
  - `git add -A && git add --chmod=+x bin/notify_plan`, commit `deploy: notify từ $src`, then `git push origin HEAD:refs/heads/deploy-notify`.

- [ ] **Step 1: Write the failing tests.**
  - `config.test.mjs`: every required name missing is listed, and no value appears in the message. `PUSH_ENABLED` values `yes`/empty are rejected. PORT is validated.
  - `directus.test.mjs`: query strings use the given fields and `filter[user_created][_eq]`. `claimDelivery` returns `false` on RECORD_NOT_UNIQUE. An unreachable Directus gives `DirectusError(0,'unreachable')`.
  - `auth.test.mjs`: copy of coach-chat's.
  - `server.test.mjs`: healthz fields; config with CORS only for allowed origins; 404.
  - `main.test.mjs`: spawned with an empty env → exit 1, stderr names `PUSH_SERVICE_TOKEN`.
- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm install --save-exact web-push@3.6.7 && $ENV npm test`. Expected: FAIL (modules missing).
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests and check the scripts.** Run `cd server/notify && $ENV npm test`, then `bash -n deploy/publish-notify.sh`. Expected: PASS, exit 0.
- [ ] **Step 5: Commit.** Message: `P6b-1: khung dịch vụ server/notify (cấu hình, Directus, healthz, image bookworm, CI, script deploy-notify)`, plus the trailer.

---

### Task 8: The helper bridge and user-data requests

**Files:**
- Create: `server/notify/src/planner.mjs`, `server/notify/src/requests.mjs`
- Test: `server/notify/test/planner.test.mjs`, `server/notify/test/requests.test.mjs`, `server/notify/test/helper.bin.test.mjs`

**Interfaces:**
- Consumes: the Task 5 wire format.
- Produces:
  - `createPlanner({ bin, spawn = child_process.spawn, timeoutMs = HELPER_TIMEOUT_MS, log })` returns `{ info(), plan(request), close(), get healthy() }`.
    - It runs one long-lived child (`stdio: ['pipe','pipe','pipe']`), started on first use and restarted after it exits.
    - Requests are matched by `reqId` (a counter string).
    - On a timeout it rejects with `PlannerError('timeout')`, kills the child and marks it unhealthy. The next call respawns.
    - When the child exits, every pending request rejects with `PlannerError('exited')`.
    - A stdout line that is not JSON is logged as `{event:'helper_bad_line'}`, without content.
    - stderr lines are logged as `{event:'helper_stderr'}`, without content.
  - `buildPlanRequest({ userId, nowUtc, tz, mode, settings, deliveries, data })` returns the `op:"plan"` object.
    - `prefs` comes from the settings booleans (`settingsPrefs`).
    - `seen` comes from `last_seen_*`, or `null` when any of the three is missing.
    - `sentRecommendations` lists deliveries with `kind === 'recommendation'` and `sent_at` set: `{ key, atUtc: at }`.
  - `settingsPrefs(row)` returns `{ recommendation, maintenance, schedule, streak }` with booleans as stored.

- [ ] **Step 1: Write the failing tests.**
  - `planner.test.mjs` uses a fake `spawn` returning EventEmitter streams. Cases:
    - replies are routed by `reqId` even out of order;
    - a timeout rejects and kills the child, and the next call respawns it;
    - a child exit rejects pending requests and the next call respawns;
    - a non-JSON line does not crash anything;
    - `healthy` reflects these states.
  - `requests.test.mjs`: prefs and seen mapping; `seen` is null when incomplete; only sent recommendations are passed.
  - `helper.bin.test.mjs` is skipped unless `process.env.NOTIFY_PLAN_BIN` is set. With the real helper:
    - `info` has 4 kinds and the 7 field lists;
    - a `due` plan with empty data is `ok` with `items: []`;
    - a garbage line returns `bad_json`, and a following `info` still works;
    - the same request twice gives identical output;
    - closing stdin makes the process exit 0.
- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm test`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests, including the real helper on Windows.** Run `cd server/notify && $ENV npm test`. Then build `$ENV $DART compile exe bin/notify_plan.dart -o build/notify_plan.exe` at the repo root, and run `cd server/notify && NOTIFY_PLAN_BIN=../../build/notify_plan.exe $ENV npm test`. Expected: PASS, with `helper.bin.test.mjs` executed rather than skipped in the second run.
- [ ] **Step 5: Commit.** Message: `P6b-1: cầu nối helper (NDJSON, khởi động lại, hết giờ) và dựng yêu cầu lập kế hoạch từ dữ liệu Directus`, plus the trailer.

---

### Task 9: Web Push sender behind a channel abstraction

**Files:**
- Create: `server/notify/src/webpush.mjs`, `server/notify/src/senders.mjs`
- Test: `server/notify/test/webpush.test.mjs`, `server/notify/test/senders.test.mjs`

**Interfaces:**
- Produces:
  - `createWebPushSender({ vapid, fetch, timeoutMs = 10_000 })` returns `{ send(device, message, { ttlSeconds, topic, urgency }) }`.
    - It uses `webPush.generateRequestDetails({ endpoint, keys: { p256dh, auth } }, JSON.stringify(message), { vapidDetails: vapid, TTL: ttlSeconds, topic, urgency, contentEncoding: 'aes128gcm' })`, then the injected `fetch`.
    - It resolves one of `{ status: 'sent' }` (2xx), `{ status: 'gone', code }` (404/410), `{ status: 'retry', code, retryAfterMs }` (429/5xx; `Retry-After` in seconds, capped at 60 000) or `{ status: 'failed', code }` (other 4xx, network error, timeout).
    - `device` is a `push_devices` row (`endpoint`, `key_p256dh`, `key_auth`).
  - `pushTopic(kind, key)` is base64url(sha256(`${kind}:${key}`)) cut to 32 characters. `pushUrgency(kind)` is `'high'` for `schedule`/`streak` and `'normal'` otherwise. `ttlSeconds(validUntilUtcIso, now)` is `max(60, floor((validUntil − now)/1000))`, capped at 2 419 200.
  - `createSenders({ web, fcm = null })` returns `{ senderFor(channel) }`, which gives the sender or `null` (★19).
  - The `message` object is `{ v: 1, deliveryId, notificationId, kind, key, title, body, payload, ackUrl }`. Its JSON must stay at or under 3000 bytes; a larger one is a `failed` with `code: 'payload_too_large'` and is not sent.

- [ ] **Step 1: Write the failing tests** (offline, with a fake `fetch` capturing the request).
  - `test('mã hoá aes128gcm: bên nhận giải mã ra đúng JSON', …)`: generate a receiver P-256 key pair and a 16-byte auth secret with `node:crypto`, then decrypt the captured body per RFC 8291 §3.4 in a test helper:
    1. Parse the header: salt(16), rs(4), idlen(1), keyid = sender public key.
    2. ECDH.
    3. `PRK_key = HMAC-SHA256(auth, ecdh)`.
    4. `IKM = HKDF-Expand(PRK_key, "WebPush: info\0"‖ua_pub‖as_pub, 32)`.
    5. `PRK = HMAC(salt, IKM)`.
    6. `CEK = Expand(PRK, "Content-Encoding: aes128gcm\0", 16)` and `NONCE = Expand(PRK, "Content-Encoding: nonce\0", 12)`.
    7. AES-128-GCM decrypt, then strip the `0x02` delimiter.
  - `test('VAPID: JWT ES256 hợp lệ, aud là origin của endpoint, exp ≤ 24 giờ, sub đúng', …)`: parse `Authorization: vapid t=…, k=…` and verify with `crypto.verify('sha256', …, { key: jwkFromK, dsaEncoding: 'ieee-p1363' }, sig)`.
  - `test('header: Content-Encoding aes128gcm, TTL, Topic ≤ 32 ký tự base64url, Urgency', …)`.
  - `test('201 → sent; 404, 410 → gone; 429 có Retry-After, 503 → retry; 400 → failed; lỗi mạng → failed', …)`.
  - `test('payload quá 3000 byte: failed payload_too_large, không gọi fetch', …)`.
  - `test('senderFor: web có, fcm chưa có thì null', …)`.
- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm test`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: gửi Web Push (web-push ghim bản, aes128gcm + VAPID) sau lớp chọn kênh web|fcm, kiểm giải mã và JWT ngoại tuyến`, plus the trailer.

---

### Task 10: Register, unregister and ack endpoints

**Files:**
- Modify: `server/notify/src/server.mjs`
- Create: `server/notify/src/devices.mjs`
- Test: `server/notify/test/devices.test.mjs`, `server/notify/test/server.test.mjs`

**Interfaces:**
- Consumes: Task 7 `directus`, `auth`, `limits`. Task 8 `planner.info()` (cached fingerprint).
- Produces:
  - `deviceIdFor(endpointOrToken)` is the sha256 hex digest.
  - `serverKindsFor({ seedFingerprint, enabled, helperFingerprint })`: `[]` when disabled; all four `KINDS` when the fingerprints are equal; otherwise all four minus `recommendation`.
  - `validateRegister(body)` returns `{ channel, endpoint, p256dh, auth, timezone, seedFingerprint, vapidPublicKey }` or throws `RequestError(field)`. Rules:
    - `channel === 'web'`; `'fcm'` gives `RequestError('channel', 'unsupported_channel')`.
    - `endpoint`: an https URL of at most 1024 characters whose host matches `PUSH_HOSTS`.
    - `p256dh`/`auth` are base64url strings of 1–200 characters.
    - `timezone` is valid when `new Intl.DateTimeFormat('en', { timeZone })` does not throw.
    - `seedFingerprint` is a string ≤ 64 or null.
  - Routes (CORS for `ALLOWED_ORIGINS`; OPTIONS answers 204 with `Access-Control-Allow-Methods: GET, POST, DELETE` and `Access-Control-Allow-Headers: authorization, content-type`):
    - `POST /push/devices` (Bearer) → 200 `{ deviceId, serverKinds, leaseUntil, serverNow, enabled }`.
      - Order of checks: body over `MAX_BODY_BYTES` → 413 `{ error:'invalid', field:'body' }`. Bad JSON or field → 400 `{ error:'invalid', field }`. Unsupported channel → 400 `{ error:'unsupported_channel' }`. No or bad token → 401. More than 30 calls by this user in the last hour → 429 `{ error:'rate_limited' }`. `vapidPublicKey !== config.vapid.publicKey` → 409 `{ error:'vapid_mismatch' }`. Directus down → 503.
      - Then upsert by `deviceId`, re-assigning `user` when it differs. Set `mode: 'server'`, `server_kinds`, `lease_until` (now + 6 h, or `null` when disabled), `last_seen_at`, `timezone`, `seed_fingerprint`, `platform: 'web'`, `channel`. Reset `failure_count: 0`. Set `created_at` on create only.
      - If the user now has more than 10 devices, delete the least-recently-seen others.
    - `DELETE /push/devices/:id` (Bearer) → always 204. It deletes the row only when `row.user === caller`.
    - `POST /push/ack` (no auth, body ≤ `MAX_ACK_BYTES`, `{ endpoint, deliveryId }`) → always 204. Only when `deviceIdFor(endpoint) === delivery.device` and `shown_at` is null does it PATCH `shown_at = now` on the delivery and `last_ack_at = now` on the device.
  - Each request logs one line: `{ method, path, status, ms, user: hashUserId }`. No endpoint, key or token.

- [ ] **Step 1: Write the failing tests.**

```js
test('đăng ký mới: 200, deviceId = sha256(endpoint), lease 6 giờ, đủ bốn loại khi dấu vân tay khớp', …);
test('dấu vân tay khác: serverKinds không có recommendation', …);
test('PUSH_ENABLED=false: 200, serverKinds rỗng, leaseUntil null', …);
test('máy dùng chung: B đăng ký cùng endpoint thì dòng chuyển sang B', …);
test('endpoint không phải dịch vụ push (http://127.0.0.1, https://evil.example): 400 field endpoint, không gọi Directus', …);
test('thân quá 8 KB: 413; tz lạ: 400 timezone; kênh fcm: 400 unsupported_channel', …);
test('khoá VAPID khác: 409 vapid_mismatch', …);
test('không token hoặc token sai: 401; Directus sập: 503', …);
test('31 lần đăng ký trong một giờ: lần thứ 31 bị 429', …);
test('thiết bị thứ 11: xoá thiết bị lâu không thấy nhất của người đó', …);
test('DELETE thiết bị của người khác: 204 nhưng không xoá', …);
test('ack đúng endpoint: ghi shown_at và last_ack_at một lần; ack giả (endpoint khác): 204, không ghi', …);
test('CORS: chỉ origin được phép có Access-Control-Allow-Origin; OPTIONS 204', …);
test('nhật ký không chứa endpoint, khoá hay token', …);   // quét mọi dòng log
```

- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm test`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: điểm cuối đăng ký/huỷ thiết bị (xác thực qua Directus, chặn host lạ, giới hạn) và xác nhận đã hiện`, plus the trailer.

---

### Task 11: Scheduler: cycle, due tick, claim then send, limits, pruning

**Files:**
- Create: `server/notify/src/scheduler.mjs`
- Modify: `server/notify/src/main.mjs`
- Test: `server/notify/test/scheduler.test.mjs`

**Interfaces:**
- Consumes: Task 7 `directus`. Task 8 `planner`, `buildPlanRequest`. Task 9 `senders`, `pushTopic`, `pushUrgency`, `ttlSeconds`. Task 10 `serverKindsFor`, `deviceIdFor`.
- Produces: `createScheduler({ directus, planner, senders, config, now, log, setInterval = globalThis.setInterval, clearInterval = globalThis.clearInterval, sleep })` returns `{ cycle(), tick(), start(), stop(), get lastCycleAt() }`.
  - **Serialisation.** `cycle` and `tick` run on one promise chain, so they never overlap. A user is never processed twice at once.
  - **`cycle()`:**
    1. Delete deliveries with `at` older than 30 days.
    2. If `!config.enabled`, stop here: no lease renewal, no sends.
    3. List the `mode === 'server'` devices.
    4. Delete devices with `failure_count ≥ 5` or `last_seen_at` older than 60 days.
    5. Get the helper fingerprint from `planner.info()`.
    6. For each device: PATCH `server_kinds` when `serverKindsFor` differs; when `failure_count === 0`, set `lease_until = now + 6 h`.
    7. Group devices by user and, for each user, run `runUser(user, devices, 'due')` then `runUser(user, devices, 'upcoming')`. The second fills `queue` (Map userId → sorted `atUtc` ms within 24 h for kinds some device of the user owns).
    8. Set `lastCycleAt`.
  - **`tick()`:** for each user whose earliest queued time is ≤ now, re-read that user's devices, run `runUser(…, 'due')`, then drop the queued times ≤ now.
  - **`runUser(userId, devices, mode)`:**
    1. Read settings. `null` means return (★6).
    2. Read user data with the helper's `fields`, and deliveries from the last 30 days.
    3. Group devices by `timezone`. For each zone, call `planner.plan(buildPlanRequest({ …, nowUtc: now().toISOString(), tz, mode }))`. On `!ok` or a planner error, log `{ event:'plan_failed', user: hash, error }` and skip the zone.
    4. In `due` mode, for each item and each device of the zone that passes `eligible(device, item, now)`:
       - Check the cap: distinct (kind, key) among this user's deliveries in the last 24 h, plus those claimed in this run. If the item's (kind, key) is not already counted and the count is ≥ 12, skip and log `cap_reached` (★8).
       - Claim: `claimDelivery({ id: sha256hex(`${device.id}|${kind}|${key}`), user, device: device.id, notification_id: id, kind, key, title, body, at: atUtc, sent_at: null })`. On `false`, skip.
       - Send with `{ v:1, deliveryId, notificationId, kind, key, title, body, payload, ackUrl: `${config.publicUrl}/push/ack` }` via `senders.senderFor(device.channel)`. A `null` sender is a failure with `unsupported_channel`.
       - Retry on `retry` twice (★10), after `max(2000, retryAfterMs)` and then `max(8000, retryAfterMs)`, through the injected `sleep`.
       - On `sent`: PATCH the delivery `sent_at = now` and the device `last_success_at = now`, `failure_count = 0`.
       - On `gone`: delete the device.
       - On `failed` or exhausted retries: `failure_count + 1`, deleting the device when it reaches 5.
  - **`eligible(device, item, now)`:** `device.mode === 'server'` and `server_kinds.includes(kind)` and `now < lease_until − 5 min` and `atUtc ≤ now < validUntilUtc`.
  - **`start()`:** run `cycle()` immediately, then `setInterval(cycle, CYCLE_MS)` and `setInterval(tick, TICK_MS)`. **`stop()`** clears both.
  - **`main.mjs`** wires the real objects.

- [ ] **Step 1: Write the failing tests.** Use a fake clock, fake Directus (in-memory rows), a fake planner returning canned helper replies, and a fake sender recording calls. Canned helper replies are copied from the real helper's output in `helper.bin.test.mjs` fixtures or built with neutral placeholder text (`'t1'`, `'b1'`). The scheduler never inspects text.

```js
test('nhịp đến hạn: gửi đúng mục at ≤ now < validUntil, ghi sent_at, đúng TTL/Topic/Urgency', …);
test('quá validUntil (máy chủ vừa sống lại): không gửi', …);
test('hai nhịp chạy chồng / khởi động lại giữa lúc gửi: dòng đã giành thì không gửi lần hai', …); // claim trả false → sender không được gọi
test('loại không thuộc server_kinds của máy, hoặc lease hết (trừ 5 phút): không gửi', …);
test('PUSH_ENABLED=false: không gửi, không gia hạn lease, vẫn dọn delivery cũ', …);
test('chưa có notification_settings: không gửi gì cho người đó', …);
test('helper trả bad_data: bỏ người đó, ghi log plan_failed, người khác vẫn được gửi', …);
test('trần 12 (kind,key) mỗi 24 giờ mỗi người: mục thứ 13 không giành, không gửi', …);
test('404/410: xoá thiết bị; 503 hai lần rồi 201: gửi được, failure_count về 0; lỗi mạng: không thử lại, failure_count +1', …);
test('failure_count lên 5: xoá thiết bị; last_seen_at quá 60 ngày: xoá ở chu kỳ', …);
test('chu kỳ gia hạn lease 6 giờ cho máy khoẻ, không gia hạn máy có lỗi', …);
test('dấu vân tay helper đổi: chu kỳ sửa server_kinds của máy', …);
test('hàng đợi: chu kỳ upcoming xếp giờ; nhịp phút chạy đúng người tới giờ, một lần', …);
test('mỗi múi giờ một lần gọi helper; thiết bị khác múi nhận theo múi của nó', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm test`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Run `cd server/notify && $ENV npm test`, and once more with `NOTIFY_PLAN_BIN=../../build/notify_plan.exe`. Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: bộ lập lịch notify (chu kỳ 15 phút, nhịp phút, giành rồi gửi, trần 12/ngày, dọn thiết bị, công tắc tắt)`, plus the trailer.

---

### Task 12: Sync notification_settings (prefs and last-seen pair)

**Files:**
- Create: `lib/data/sync/notification_settings_sync.dart`, `lib/data/notifications/notification_settings_meta_store.dart`
- Modify: `lib/core/providers/notification_providers.dart` (controllers), `lib/core/bootstrap.dart` (`startSync`)
- Test: `test/data/sync/notification_settings_sync_test.dart`, `test/data/notifications/notification_settings_meta_store_test.dart` (create), `test/core/providers/notification_prefs_provider_test.dart` (create or extend the existing controller tests)

**Interfaces:**
- Consumes: Task 6 `notificationSettingsRemoteFields`. Also the existing `NotificationPrefsStore`, `RecommendationSeenStore`, `DirectusClient`, `AuthRepository` and `SyncOutcome`.
- Produces:
  - `final class NotificationSettingsMeta { const NotificationSettingsMeta({this.prefsUpdatedAt, this.prefsDirty = false, this.seenDirty = false}); }` and `abstract class NotificationSettingsMetaStore { Future<NotificationSettingsMeta> load(String userId); Future<void> save(String userId, NotificationSettingsMeta meta); }`.
    - The shared_preferences version uses the key `'poolcoachai:notification-settings-sync:v1:$userId'` (JSON). A corrupt value loads as the default meta.
  - `class NotificationSettingsSyncService`, constructed with `required AuthRepository auth, required DirectusClient api, required NotificationPrefsStore prefs, required RecommendationSeenStore seen, required NotificationSettingsMetaStore meta, required DateTime Function() now, required String? Function() timeZone, required void Function(String userId, {NotificationPrefs? prefs, SeenRecommendation? seen}) onAdopted, Duration retryEvery = const Duration(seconds: 30)`.
    - `start()` triggers `syncNow` on `SignedIn`, then every `retryEvery` while the meta is dirty. The timer exists only after `start()`.
    - `Future<SyncOutcome> syncNow()` uses the `RoadmapSyncService` loop shape (`_again`, `_UserChanged`, `_Stopped`). One pass, for user `u`:
      1. `GET /items/notification_settings?filter[id][_eq]=u&fields=<notificationSettingsRemoteFields>&limit=1`.
      2. **Absent:** POST the local prefs (from `prefs.load(u)`, which covers the P6a migration), `prefs_updated_at` (`meta.prefsUpdatedAt` or now), the seen pair (from `seen.load(u)`, full `cat.name`) and `timezone`. Then clear both dirty flags. If the POST answers `RECORD_NOT_UNIQUE`, re-GET and merge.
      3. **Present, prefs group:** if `meta.prefsDirty` and (remote `prefs_updated_at` is null or older than the local one), PATCH the prefs group. Else if the remote is newer than the local one (or the local one is null), save it to the store, set the meta, and `onAdopted(u, prefs:)`.
      4. **Present, seen group:** the newer `at` wins. PATCH when the local one is newer. Adopt with `onAdopted(u, seen:)` when the remote one is newer.
      5. **Timezone:** PATCH `timezone` when `timeZone()` is non-null and differs.
      6. Nothing differs → no PATCH, no store write.
    - `Future<void> localPrefsChanged(String userId)` sets `prefsUpdatedAt = now`, `prefsDirty = true`, then `syncNow()` if started. `Future<void> localSeenChanged(String userId)` sets `seenDirty = true`, then `syncNow()` if started.
    - `dispose()`.
  - Providers:
    - `notificationSettingsMetaStoreProvider`.
    - `notificationSettingsSyncProvider = Provider<NotificationSettingsSyncService>(…)`. Not started in the provider. Its `onAdopted` calls `ref.read(notificationPrefsProvider.notifier).adopt(userId, prefs)` and `ref.read(recommendationSeenProvider.notifier).adopt(userId, seen)` when non-null. `timeZone` is wired to `() => null` here; Task 16 rewires it to the push platform.
    - `NotificationPrefsController.setEnabled` and `RecommendationSeenController.markSeen` call `localPrefsChanged`/`localSeenChanged` after saving.
    - `void adopt(String userId, NotificationPrefs prefs)` and `void adopt(String userId, SeenRecommendation seen)` set `state = AsyncData(...)` only when `ref.read(currentUserIdProvider) == userId`. Adopting never calls `local*Changed`.
  - `startSync` holds the service with `container.listen(notificationSettingsSyncProvider, (_, _) {}).read().start();`.

- [ ] **Step 1: Write the failing tests** (`FakeDirectus`, `FakeAuthRepository.signedIn()`, `SharedPreferences.setMockInitialValues`).

```dart
test('lần đầu, máy chủ chưa có dòng: đẩy cài đặt và cặp đã thấy của bản cục bộ cũ (P6a) lên một lần', …);
test('máy chủ đã có dòng, máy này chưa từng đồng bộ: nhận bản máy chủ, gọi onAdopted', …);
test('đổi công tắc khi mất mạng rồi có mạng: PATCH đúng nhóm prefs với prefs_updated_at mới', …);
test('hai máy: bản prefs mới hơn thắng; cặp đã thấy mới hơn thắng, độc lập với prefs', …);
test('không có gì khác: không PATCH, không ghi kho (đếm request)', …);           // vòng lặp: syncNow 3 lần → số PATCH vẫn 0
test('nhận bản máy chủ không làm bẩn lại (không đẩy ngược)', …);
test('đổi tài khoản giữa lượt: kết quả của u1 không ghi vào u2', …);          // giữ GET của u1 bằng Completer, emit SignedIn('u2')
test('RECORD_NOT_UNIQUE khi tạo (máy khác vừa tạo): đọc lại rồi gộp', …);
// provider
test('adopt của người khác bị bỏ qua', …);
test('setEnabled đánh dấu bẩn và gọi localPrefsChanged; markSeen gọi localSeenChanged', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/sync/notification_settings_sync_test.dart test/data/notifications test/core/providers`. Expected: compile errors.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Run the same files, then `test/core/bootstrap_test.dart test/features/notifications test/features/home`, then `$ENV $FLUTTER analyze`. Expected: PASS, and the existing P6a tests stay unchanged.
- [ ] **Step 5: Commit.** Message: `P6b-1: đồng bộ notification_settings (công tắc và cặp gợi ý đã thấy) qua Directus, bản cục bộ P6a được đẩy lên một lần`, plus the trailer.

---

### Task 13: The notify client, the push platform, and build config

**Files:**
- Create:
  - `lib/domain/notifications/push_state.dart`
  - `lib/data/remote/notify_client.dart`
  - `lib/data/push/push_types.dart`, `push_platform.dart`, `push_platform_stub.dart`, `push_platform_web.dart`, `push_platform_native.dart`
- Modify: `lib/core/config.dart`, `deploy/publish.sh`
- Test: `test/data/remote/notify_client_test.dart`, `test/domain/notifications/push_state_test.dart` (create)

**Interfaces:**
- Produces:
  - In `push_state.dart` (pure):
    - `enum PushChannel { web, fcm }`.
    - `final class PushLease { const PushLease({required String userId, required String deviceId, required Set<NotificationKind> serverKinds, required DateTime until}); bool activeAt(DateTime now) => now.isBefore(until); }`
    - `sealed class PushState`, with `PushUnavailable()` (cannot push here: unsupported browser or empty VAPID key), `PushLocal()` (could push, but not now) and `PushServer(PushLease lease)`.
    - `NotificationPrefs localPrefsUnder(NotificationPrefs prefs, PushState? state, {required String? userId, required DateTime now})` turns off each server kind with `toggled(kind, false)`. It does so only when `state is PushServer`, `lease.userId == userId` and `lease.activeAt(now)`. Otherwise it returns `prefs` unchanged.
  - `config.dart`:
    - `const notifyBaseUrl = String.fromEnvironment('NOTIFY_URL', defaultValue: 'https://poolcoachai-notify.kjdybl.easypanel.host');`
    - `const vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');`
  - `notify_client.dart`:
    - `class NotifyClient { NotifyClient({required http.Client client, required Uri baseUrl, Duration timeout = const Duration(seconds: 10)}); Future<NotifyConfig> config(); Future<NotifyRegistration> register({required String token, required PushSubscriptionInfo subscription, required String timezone, required String? seedFingerprint, required String vapidPublicKey}); Future<void> unregister({required String token, required String deviceId}); }`
    - `final class NotifyConfig { final bool enabled; final String? publicKey; }`
    - `final class NotifyRegistration { final String deviceId; final Set<NotificationKind> serverKinds; final DateTime? leaseUntil; final DateTime serverNow; final bool enabled; }`. Unknown kind names are dropped.
    - `class NotifyError implements Exception { final int status; final String? code; }` and `class NotifyUnreachable implements Exception`.
    - `register` posts `{channel:'web', endpoint, keys:{p256dh, auth}, timezone, seedFingerprint, vapidPublicKey}` with a Bearer token. `unregister` sends `DELETE /push/devices/<Uri.encodeComponent(deviceId)>`.
  - `push_platform.dart` exports the stub, `if (dart.library.js_interop)` the web file, `if (dart.library.io)` the native file. Every variant has `class PushPlatform`:
    - `bool get isSupported`
    - `PushChannel get channel`
    - `String? get timeZone`
    - `Future<PushSubscriptionInfo?> current()`
    - `Future<PushSubscriptionInfo> subscribe(String vapidPublicKey)`
    - `Future<void> unsubscribe()`
    - `Stream<PushShown> get shown`
    - plus `PushPlatform createPushPlatform()`.
  - In `lib/data/push/push_types.dart` (pure, imported by every variant and by `notify_client.dart`):
    - `final class PushSubscriptionInfo { endpoint, p256dh, auth, String? applicationServerKey }`. The key is base64url without padding.
    - `final class PushShown { deliveryId, notificationId, kind (NotificationKind), key, title, body, DateTime shownAt }`, with `static PushShown? fromMessage(Object? data)` (null when malformed; test it with a Dart map in `push_state_test.dart`).
  - Web (`push_platform_web.dart`, the only push file with `package:web`/`dart:js_interop`):
    - `isSupported` is `'serviceWorker' in navigator && 'PushManager' in window`.
    - `subscribe` does `navigator.serviceWorker.register('/push/sw.js', RegistrationOptions(scope: '/push/'))`, then waits for `ready` of that registration.
    - If an existing subscription's `applicationServerKey` differs from `vapidPublicKey`, it unsubscribes first.
    - Then `pushManager.subscribe(PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: vapidPublicKey.toJS))`, read through `toJSON()`.
    - `timeZone` is `Intl.DateTimeFormat().resolvedOptions().timeZone`.
    - `shown` listens to `BroadcastChannel('pcai-push')` for `type == 'shown'`.
  - Native (P6b-1) and stub: `isSupported => false`, `channel => PushChannel.fcm` (native) or `web` (stub), `timeZone => null`, `shown => const Stream.empty()`. `subscribe` throws `UnsupportedError`.
  - `deploy/publish.sh`:
    - Require `VAPID_PUBLIC_KEY`: `: "${VAPID_PUBLIC_KEY:?Thiếu VAPID_PUBLIC_KEY (khoá công khai, đặt trong settings.local.json)}"`.
    - Build with `"$FLUTTER" build web --release --dart-define=VAPID_PUBLIC_KEY="$VAPID_PUBLIC_KEY"`.
    - Add `push/sw.js` to the file check loop.
    - Fail if `grep -q serviceWorkerSettings build/web/flutter_bootstrap.js`.

- [ ] **Step 1: Write the failing tests.**

```dart
// push_state_test.dart
test('lease còn hạn của đúng người: tắt các loại máy chủ lo', …);
test('lease của người khác, lease hết hạn, PushLocal hay PushUnavailable: giữ nguyên prefs', …);   // mỗi nhánh một expect (mutation-proof)
// notify_client_test.dart (MockClient của package:http/testing.dart)
test('đăng ký: gửi đúng thân và Bearer, đọc deviceId, serverKinds, leaseUntil, serverNow', …);
test('loại lạ trong serverKinds bị bỏ', …);
test('409 vapid_mismatch → NotifyError(409, vapid_mismatch); mất mạng → NotifyUnreachable', …);
test('huỷ: DELETE /push/devices/<id> mã hoá đúng', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/domain/notifications/push_state_test.dart test/data/remote/notify_client_test.dart`. Expected: compile errors.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests and the web build.** Run the tests and `$ENV $FLUTTER analyze`, then `$ENV $FLUTTER build web --release --dart-define=VAPID_PUBLIC_KEY=BKtest`. The value is any non-empty placeholder: it is only a build input and never reaches a server. Then `bash -n deploy/publish.sh`. Expected: PASS, the build exits 0, and the syntax check is OK.
- [ ] **Step 5: Commit.** Message: `P6b-1: trạng thái push (lease theo người), client dịch vụ notify, nền tảng push web qua dart:js_interop (native là stub), publish.sh nhúng khoá VAPID công khai`, plus the trailer.

---

### Task 14: Service worker, custom bootstrap, web taps and cold start

**Files:**
- Create: `web/push/sw.js`, `web/flutter_bootstrap.js`, `server/notify/test/sw.test.mjs`
- Modify: `lib/data/notifications/notification_platform_web.dart`, `test/architecture_test.dart`

**Interfaces:**
- `web/flutter_bootstrap.js` is exactly these three lines (template tokens verified in Flutter 3.47 `flutter_tools/lib/src/web/bootstrap.dart` `generateDefaultFlutterBootstrapScript`):

```js
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
```

- `web/push/sw.js` (plain JS, no imports):
  - `push`: `msg = event.data?.json()`. If `msg?.v !== 1`, return.
    - Otherwise `event.waitUntil` runs `registration.showNotification(msg.title, { body: msg.body, tag: msg.kind + ':' + msg.key, data: { payload: msg.payload, deliveryId: msg.deliveryId }, icon: '/icons/Icon-192.png' })`.
    - Then it posts `{ type: 'shown', deliveryId, notificationId, kind, key, title, body, shownAt: new Date().toISOString() }` on `new BroadcastChannel('pcai-push')`.
    - Then, when `msg.ackUrl` starts with `https://` and `await registration.pushManager.getSubscription()` is non-null, it does `fetch(msg.ackUrl, { method: 'POST', headers: { 'content-type': 'text/plain' }, body: JSON.stringify({ endpoint: sub.endpoint, deliveryId: msg.deliveryId }) })`. The `text/plain` content type avoids a preflight; errors are swallowed.
  - `notificationclick`: `event.notification.close()`. Then `clients.matchAll({ type: 'window', includeUncontrolled: true })`.
    - With a same-origin client: `focus()` it, then post `{ type: 'tap', payload }` on the channel.
    - Otherwise: `clients.openWindow('/?n=' + encodeURIComponent(payload))`.
  - `install`: `skipWaiting()`. `activate`: `clients.claim()` is **not** called (the worker controls no page).
- `notification_platform_web.dart`:
  - `takeLaunchPayload()` reads `Uri.base.queryParameters['n']` synchronously. When present, it removes `n` with `web.window.history.replaceState(null, '', <same URL without n>)` before returning it. Startup calls this before `runApp`, so the router never sees `n`.
  - The constructor listens to `BroadcastChannel('pcai-push')`. A message `{ type: 'tap', payload: String }` calls `onTap?.call(payload)` only when `web.document.visibilityState == 'visible'` (★18).

- [ ] **Step 1: Write the failing tests.**

```js
// sw.test.mjs: nạp ../../../web/push/sw.js vào vm.createContext với self/registration/clients/fetch/BroadcastChannel giả
test('push hợp lệ: hiện đúng tiêu đề/thân/tag, phát shown, rồi gửi ack text/plain tới ackUrl', …);
test('push sai phiên bản hoặc không JSON: không hiện, không ack', …);
test('ackUrl không phải https hoặc chưa có subscription: không gọi fetch', …);
test('chạm khi có tab: focus tab và phát tap kèm payload; không có tab: mở /?n=<payload mã hoá>', …);
test('fetch ack lỗi: không ném ra ngoài waitUntil', …);
```

```dart
// architecture_test.dart
test('worker đẩy nằm ở /push/, bootstrap không đăng ký service worker của Flutter, không route nào bắt đầu bằng /push', () {
  expect(File('web/push/sw.js').existsSync(), isTrue);
  expect(File('web/flutter_bootstrap.js').readAsStringSync(), isNot(contains('serviceWorkerSettings')));
  expect(File('lib/core/router/routes.dart').readAsStringSync(), isNot(contains("'/push")));
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `cd server/notify && $ENV npm test` and `$ENV $FLUTTER test test/architecture_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests and inspect the build.**
  - Run both test commands and `$ENV $FLUTTER analyze`.
  - Run `$ENV $FLUTTER build web --release --dart-define=VAPID_PUBLIC_KEY=BKtest`.
  - Then `test -f build/web/push/sw.js`, `grep -c serviceWorkerSettings build/web/flutter_bootstrap.js` (expected `0`), and `grep -c "_flutter.buildConfig" build/web/flutter_bootstrap.js` (expected `1`).
  - Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: service worker /push/sw.js (hiện, xác nhận, chạm), flutter_bootstrap.js riêng không đăng ký worker của Flutter, chạm và mở lạnh trên web`, plus the trailer.

---

### Task 15: PushService: subscribe, register, lease, deliveries pull

**Files:**
- Create: `lib/data/push/push_service.dart`, `lib/data/push/push_registration_store.dart`, `lib/core/providers/push_providers.dart`, `test/support/fake_push_platform.dart`
- Modify: `lib/core/bootstrap.dart` (`startPush`)
- Test: `test/data/push/push_service_test.dart`, `test/data/push/push_registration_store_test.dart` (create)

**Interfaces:**
- Consumes: Task 13 `NotifyClient`, `PushPlatform`, `PushState`, `PushLease`, `vapidPublicKey`, `notifyBaseUrl`. Task 2 `seedFingerprint`. Task 6 `pushDeliveryRemoteFields`. Also `DirectusClient` and `AuthRepository`.
- Produces:
  - `abstract class PushRegistrationStore { Future<PushLease?> load(String userId); Future<void> save(PushLease lease); Future<void> forget(String userId); }`. The shared_preferences version uses the key `'poolcoachai:push-registration:v1:$userId'`, storing JSON `{deviceId, kinds, until}`. Corrupt or unknown values load as null.
  - `class PushService`, constructed with `required AuthRepository auth, required NotifyClient notify, required DirectusClient api, required PushPlatform platform, required PushRegistrationStore store, required DateTime Function() now, required String vapidPublicKey, required String? Function() permission, Duration refreshEvery = const Duration(minutes: 30), Duration resolveTimeout = const Duration(seconds: 10), Duration unregisterTimeout = const Duration(seconds: 5)`.
    - `Stream<PushState> get states` is broadcast, and a new listener first receives the latest state. Initial state:
      - unsupported platform or empty key → `PushUnavailable` at once;
      - signed out → `PushLocal`;
      - signed in with a stored lease that is still active → `PushServer(stored)` at once;
      - otherwise nothing until the first resolution (★4).
    - `Stream<(String, List<NotificationLogEntry>)> get delivered`.
    - `void setCatalog(List<Drill> drills, List<KnowledgeArticle> knowledge)` stores `seedFingerprint(...)`. Registration waits for the catalog for at most `resolveTimeout`; without it, it sends `seedFingerprint: null`.
    - `void start()` subscribes to auth and to `platform.shown`, starts the `refreshEvery` timer, and runs `refresh()`.
    - `Future<void> refresh()` uses a per-call token (`userId` plus a generation). After every await, if the user changed, it drops the result (mutation-proof test). For signed-in user `u`:
      1. Unsupported platform or empty key → emit `PushUnavailable`. Permission not `'granted'` → emit `PushLocal`.
      2. `notify.config()`. If `!enabled` or `publicKey != vapidPublicKey` → emit `PushLocal`.
      3. `platform.subscribe(vapidPublicKey)`.
      4. `notify.register(token: await auth.accessToken(), …, timezone: platform.timeZone ?? 'UTC')`.
      5. `until = now() + (leaseUntil − serverNow)`. Save `PushLease(userId: u, deviceId, serverKinds, until)` and emit `PushServer(lease)`, or `PushLocal` when `leaseUntil` is null or `serverKinds` is empty.
      6. Run `pullDeliveries()`.
      - Errors (`NotifyError`, `NotifyUnreachable`, `DirectusError`, a platform exception): keep the stored lease if it is still active (`PushServer(stored)`), else emit `PushLocal`.
      - The whole call races `resolveTimeout` for the first emission only.
    - `Future<void> pullDeliveries()`, with a known `deviceId` for the current user, runs `GET /items/push_deliveries` with `filter[device][_eq]=<id>`, `filter[shown_at][_nnull]=true`, `filter[shown_at][_gte]=<now − 30 days, ISO UTC>`, `fields=pushDeliveryRemoteFields` and `limit=-1`, using the player token. It emits `(u, [NotificationLogEntry(id: notification_id, kind, key, at: shown_at.toLocal(), title, body)])`. Unknown kinds are skipped. Errors are swallowed.
    - A `platform.shown` event emits `(u, [entry at shownAt.toLocal()])` at once, then schedules `pullDeliveries()`, coalesced so a burst triggers one pull.
    - `Future<void> unregister(String userId)` (pressed sign-out): `notify.unregister(token:, deviceId:)` under `unregisterTimeout` (errors swallowed), then `platform.unsubscribe()` (errors swallowed), then `store.forget(userId)`.
    - Auth `SignedOut` (any cause) → `platform.unsubscribe()`, emit `PushLocal`, `store.forget(previousUser)` (★13). A direct `SignedIn(u2)` → `refresh()` for u2; the server re-assigns the row.
    - `dispose()`.
  - `push_providers.dart`:
    - `pushPlatformProvider`, `pushRegistrationStoreProvider`, and `notifyClientProvider` (built on `httpClientProvider` and `notifyBaseUrl`).
    - `pushServiceProvider`. Not started here. It wires `permission: () => ref.read(notificationServiceProvider).permission` through a closure read at call time, so there is no build-time cycle. It calls `ref.listen` on `drillsProvider`/`knowledgeProvider`, and when both are `hasValue && !isLoading` it calls `setCatalog`.
    - `pushStateProvider = StreamProvider<PushState>((ref) => ref.watch(pushServiceProvider).states)`.
    - `pushDeliveredProvider = StreamProvider<(String, List<NotificationLogEntry>)>(…)`.
  - `bootstrap.dart`: `void startPush(ProviderContainer container) { container.listen(pushServiceProvider, (_, _) {}).read().start(); }`. `startSync` calls it before `startNotifications`.
  - `FakePushPlatform` has settable `isSupported`, `subscription`, `timeZone`, an `unsubscribeCalls` counter, a `StreamController<PushShown> shownController`, and an optional `Completer` hold on `subscribe`.

- [ ] **Step 1: Write the failing tests** (`MockClient` routes for notify, `FakeDirectus` for deliveries, `FakeAuthRepository`, in-memory store).

```dart
test('nền tảng không hỗ trợ hoặc khoá rỗng: PushUnavailable ngay, không gọi mạng', …);
test('chưa cấp quyền: PushLocal; cấp quyền rồi refresh: đăng ký, PushServer với lease theo giờ máy chủ', …); // until = now + (leaseUntil − serverNow)
test('máy chủ tắt hoặc khoá khác: PushLocal, không subscribe', …);
test('lease đã lưu còn hạn: PushServer ngay khi start, rồi làm mới', …);
test('lease đã lưu hết hạn: chưa phát gì cho tới khi làm mới xong (hoặc 10 giây)', …);
test('máy chủ không tới được, lease cũ còn hạn: giữ PushServer; hết hạn: PushLocal', …);
test('đổi tài khoản khi đang đăng ký: kết quả của u1 bị bỏ, lease lưu cho u2', …);   // subscribe hold; emit SignedIn('u2')
test('đăng xuất (bất kỳ lý do): unsubscribe, PushLocal, quên lease', …);
test('unregister: DELETE rồi unsubscribe; DELETE lỗi vẫn unsubscribe', …);
test('kéo Đã gửi: chỉ dòng shown của máy này trong 30 ngày, at là shown_at giờ máy', …);
test('shown từ worker: phát ngay một mục, rồi một lần kéo cho cả loạt (đếm GET)', …);
test('không có timer trước start(); dispose huỷ timer', …);
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/push`. Expected: compile errors.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Run `test/data/push test/core/bootstrap_test.dart`, then `$ENV $FLUTTER analyze`. Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: PushService đăng ký thiết bị, giữ lease theo người, kéo thông báo đã hiện, huỷ khi đăng xuất`, plus the trailer.

---

### Task 16: NotificationService under the lease, inbox ingest, sign-out wiring

**Files:**
- Modify:
  - `lib/data/notifications/notification_service.dart`
  - `lib/data/notifications/notification_log_repository.dart`
  - `lib/core/providers/notification_providers.dart` (`notificationServiceProvider`, and the settings sync `timeZone` wiring)
  - `lib/data/sync/account_actions.dart` (`signOutAndForget`)
  - `lib/features/profile/presentation/profile_screen.dart`
- Test: `test/data/notifications/notification_service_test.dart`, `test/data/notifications/notification_log_repository_test.dart`, `test/data/sync/account_actions_test.dart`, plus every `signOutAndForget(` call in `test/` (12 sites; pass `unregisterPush: (_) async {}`)

**Interfaces:**
- Consumes: Task 13 `PushState`, `localPrefsUnder`. Task 15 `pushStateProvider`, `pushDeliveredProvider`, `pushServiceProvider`, `PushService.pullDeliveries`, `refresh`, `unregister`. Task 12 `notificationSettingsSyncProvider`.
- Produces:
  - `NotificationLogRepository.recordDelivered(List<NotificationLogEntry> entries)`. In one transaction it reads the existing ids of those entries for this user, inserts only the missing ones (with `readAt` null), and runs the 30-day prune only when something was inserted. Nothing new → no statement.
  - `NotificationService`:
    - `void setPushState(AsyncValue<PushState> state)`. The default field value is `const AsyncData(PushUnavailable())`, so direct-construction tests keep P6a behaviour. Setting it runs `checkNow()` when started.
    - `@visibleForTesting AsyncValue<PushState> get pushState`.
    - `_plan` uses `localPrefsUnder(prefs, _pushState.value, userId: _userId, now: _now().toLocal())`.
    - Gating (★4): web `checkNow` returns early while `_pushState is AsyncLoading`. The native `ready()` also requires `_pushState is! AsyncLoading`.
    - `Future<void> ingestDelivered(String userId, List<NotificationLogEntry> entries)`. It returns if `userId != _userId` (mutation-proof test). On web it calls `_platform.writeValue(_storageKey…, at.toIso8601String())` for each entry's (kind, key), using the same key function as `checkNow`. Then it calls `recordDelivered`.
    - `Future<void> Function()? beforeMarkRead`. In `_onTapPayload` the handler still runs at once. `markReadByKey` runs after `await beforeMarkRead?.call().timeout(const Duration(seconds: 5))` (errors swallowed).
    - `void Function()? onPermissionChanged` is called after `requestPermission` resolves.
  - `notificationServiceProvider` adds:
    - `ref.listen(pushStateProvider, (_, next) => service.setPushState(next), fireImmediately: true)`;
    - `ref.listen(pushDeliveredProvider, (_, next) { final v = next.value; if (v != null) service.ingestDelivered(v.$1, v.$2); })`;
    - `service.beforeMarkRead = ref.read(pushServiceProvider).pullDeliveries;`
    - `service.onPermissionChanged = () => unawaited(ref.read(pushServiceProvider).refresh());`
    - The settings sync `timeZone` becomes `() => ref.read(pushPlatformProvider).timeZone`.
  - `signOutAndForget` gains `required Future<void> Function(String userId) unregisterPush`. It is awaited right after `forgetChatInFlight` and before `auth.signOut()`, with errors swallowed. The doc comment says why: the DELETE needs the token. `ProfileScreen` passes `ref.read(pushServiceProvider).unregister`.

- [ ] **Step 1: Write the failing tests** (the existing `_FakeNotificationPlatform`; `now` as in that file).

```dart
// notification_service_test.dart, nhóm trình duyệt
test('lease còn hạn của u1: streak/schedule/maintenance/recommendation không hiện cục bộ', …);
test('lease của u2 trong khi u1 đăng nhập: vẫn hiện cục bộ như P6a', …);                 // mutation-proof cho guard userId
test('hết hạn lease khi tab đang mở: loại máy chủ quay về cục bộ đúng lúc', …);           // now vượt until → checkNow hiện streak
test('đang chờ trạng thái push (AsyncLoading): web không hiện gì; có kết quả thì hiện', …);
test('mở tab sau khi máy chủ đã gửi: không hiện lại', () async {
  // setPushState(AsyncLoading) → ingestDelivered('u1', [streak hôm nay]) → setPushState(AsyncData(PushLocal()))
  // → now = 20:01 → checkNow → platform.notifications rỗng; nhật ký có đúng một dòng streak
});
test('máy chủ gửi khi tab đang mở: không hiện hai lần', …);   // ingest qua shown trước, rồi lease hết hạn → không hiện cùng (kind,key)
test('nhận thông báo của tài khoản khác: bỏ qua, không ghi gì', …);
test('chạm khi dòng chưa về: chờ kéo xong rồi mới đánh dấu đã đọc', …);   // beforeMarkRead chèn dòng; sau pumpEventQueue readAt != null
test('vòng lặp: ingest cùng dữ liệu ba lần không phát lại luồng nhật ký', …);   // đếm số lần watchAll() phát
// nhóm native: test có sẵn giữ nguyên, thêm
test('native: trạng thái push mặc định không làm đổi lịch đã đặt', …);
// notification_log_repository_test.dart
test('recordDelivered: chỉ chèn id chưa có, không câu lệnh nào khi không có gì mới', …);
// account_actions_test.dart
test('đăng xuất gọi huỷ push trước khi đăng xuất khỏi Directus; huỷ lỗi vẫn đăng xuất', …);   // FakeAuth.calls ghi thứ tự
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/data/notifications test/data/sync/account_actions_test.dart`. Expected: FAIL or compile errors.
- [ ] **Step 3: Implement** the Interfaces, and update the 12 `signOutAndForget(` call sites in `test/`.
- [ ] **Step 4: Run the tests.** Run the same files, then `test/core test/features/notifications test/features/profile test/data/sync test/app_test.dart test/architecture_test.dart` in the background with Monitor, then `$ENV $FLUTTER analyze`. Expected: PASS. P6a's native and web tests stay unchanged except the sign-out call sites.
- [ ] **Step 5: Commit.** Message: `P6b-1: dịch vụ thông báo nhường loại máy chủ lo khi lease còn hạn, chờ trạng thái push khi mở tab, kéo Đã gửi từ push_deliveries; đăng xuất huỷ đăng ký push`, plus the trailer.

---

### Task 17: Copy that states the mode truthfully

**Files:**
- Modify: `lib/core/strings/vi.dart`, `lib/features/notifications/presentation/notifications_screen.dart` (`_permissionCard`)
- Test: `test/features/notifications/notifications_screen_test.dart`

**Interfaces:**
- Consumes: Task 15 `pushStateProvider`. `NotificationService.schedulesInBackground`.
- Produces (`Vi`, exact strings):
  - `static const notificationsWebPushOn = 'Thông báo được gửi từ máy chủ, nên vẫn đến khi đã đóng tab.';`
  - `static const notificationsWebPushRecommendationLocal = 'Riêng Gợi ý tập mới vẫn được tính trên trình duyệt này, nên chỉ hiện khi tab đang mở.';`
  - `static const notificationsWebPushUnavailable = 'Trình duyệt này chưa nhận được thông báo khi đã đóng tab. Trên iPhone (iOS 16.4 trở lên), hãy thêm ứng dụng vào Màn hình chính rồi mở từ đó.';`
- Behaviour (web only, i.e. `!schedulesInBackground`). The notes under the permission card come from `pushStateProvider` (`hasValue && !isLoading`; while loading, keep the P6a note):
  - `PushServer` whose kinds contain `recommendation` → `[notificationsWebPushOn]`.
  - `PushServer` without `recommendation` → `[notificationsWebPushOn, notificationsWebPushRecommendationLocal]`.
  - `PushLocal` → `[notificationsWebOnlyWhileOpen]`.
  - `PushUnavailable` → `[notificationsWebOnlyWhileOpen, notificationsWebPushUnavailable]`.
  - Native notes are unchanged.

- [ ] **Step 1: Write the failing tests** (override `pushStateProvider` with `Stream.value(...)`, following the file's existing `containerWith`).

```dart
testWidgets('web, máy chủ lo cả bốn loại: chỉ ghi chú đến cả khi đóng tab', …);
testWidgets('web, máy chủ không lo Gợi ý tập mới: thêm ghi chú gợi ý chỉ khi tab mở', …);
testWidgets('web, cục bộ: ghi chú chỉ khi tab mở như P6a', …);
testWidgets('web, trình duyệt không nhận push: thêm hướng dẫn Màn hình chính cho iPhone', …);
testWidgets('điện thoại: ghi chú như P6a, không có ghi chú push web', …);
testWidgets('360×640 chữ x1.5: thẻ quyền có hai ghi chú không tràn', (tester) async {
  applyScreen(tester, const Size(360, 640), textScale: 1.5);
  expect(tester.takeException(), isNull); await scrollThroughAll(tester); expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run them to verify they fail.** Run `$ENV $FLUTTER test test/features/notifications`. Expected: FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Run the tests.** Run the same folder, `test/architecture_test.dart` and `$ENV $FLUTTER analyze`. Expected: PASS.
- [ ] **Step 5: Commit.** Message: `P6b-1: màn Thông báo nói đúng chế độ (máy chủ gửi cả khi đóng tab / chỉ khi tab mở), hướng dẫn iPhone thêm vào Màn hình chính`, plus the trailer.

---

### Task 18: E2E script, docs and full verification

**Files:**
- Create: `tool/e2e/push.mjs`
- Modify: `PRD_PoolCoachAI.md`, `tong_hop_y_tuong_app_huan_luyen_bi_a_9ball.md`

**Interfaces:**
- Consumes: `launch`, `sleep` (`tool/e2e/cdp.mjs`) and `registerThrowaway`, `deleteUserByEmail` (`tool/e2e/throwaway_user.mjs`).
- The script follows `tool/e2e/notifications.mjs`:
  - the `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1` guard;
  - `check()` with screenshots under `%TMP%/pcai-push`;
  - cleanup in `finally` (deleting the user CASCADEs its devices, deliveries and settings);
  - exit 1 on any failed check.
  - It takes `APP_URL` from argv and `NOTIFY_URL` from env, defaulting to `https://poolcoachai-notify.kjdybl.easypanel.host`.
- Steps:
  1. `Browser.grantPermissions` for `notifications` on APP. Register a throwaway user. Open `/notifications` and tap `Vi.equipmentReminderEnable` if present.
  2. Wait up to 20 s for `navigator.serviceWorker.getRegistration('/push/')`, then read `pushManager.getSubscription()`.
     - If there is no subscription, print `KHÔNG ĐĂNG KÝ ĐƯỢC PUSH TRONG CHROME CHẠY NGẦM — chỉ kiểm chế độ cục bộ`. Check that `Vi.notificationsWebPushUnavailable` or `notificationsWebOnlyWhileOpen` is shown, then skip to step 5.
  3. With admin credentials, `GET /items/push_devices?filter[user][_eq]=<uid>` returns one row with `mode` `server` and `lease_until` in the future. The page shows `Vi.notificationsWebPushOn`.
  4. Inject a push.
     - Admin creates a `push_deliveries` row (id `e2e-<random>`, `kind` `streak`, `key` today, fixture title/body clearly prefixed `[e2e]`).
     - `ServiceWorker.enable`. Take the registration id from `ServiceWorker.workerRegistrationUpdated` for scope `<APP>/push/`.
     - `ServiceWorker.deliverPushMessage({ origin: APP, registrationId, data: JSON.stringify({ v: 1, deliveryId, notificationId: 1, kind: 'streak', key, title, body, payload: 'v2|<uid>|streak|<key>', ackUrl: NOTIFY_URL + '/push/ack' }) })`.
     - Check: `registration.getNotifications()` includes the title; within 15 s the row's `shown_at` is set; "Đã gửi" lists the title.
  5. Tap paths.
     - From the page, `new BroadcastChannel('pcai-push').postMessage({ type: 'tap', payload: 'v2|<uid>|streak|<key>' })` → the URL path becomes `/training`.
     - Navigate to `APP + '/?n=' + encodeURIComponent(payload)` → the path is `/training` and `location.search` has no `n`.
  6. Sign out through Profile ("Đăng xuất" flow) → `pushManager.getSubscription()` is null, and (when step 3 ran) the device row is gone.
- What headless cannot check, printed at the end as `KIỂM BẰNG MẮT`:
  - real delivery through Google's push service;
  - the OS notification banner and its click (`notificationclick`);
  - delivery with the browser fully closed;
  - iOS home-screen web push.
- Doc edits (locate by text):
  - PRD: in the bullet `**Còn thiếu:**`, replace `push khi ứng dụng đã đóng (thông báo hiện là cục bộ: Android/iOS vẫn đến khi ứng dụng đóng, web chỉ khi tab còn mở; push từ máy chủ là P6b)` with `push Android từ máy chủ (P6b-2, FCM) và iOS (P6b-3)`.
  - PRD: in the maintenance sentence, replace `trên web chỉ khi tab còn mở (push từ máy chủ là P6b)` with `trên web, máy chủ gửi Web Push nên thông báo đến cả khi đã đóng tab (P6b-1); trình duyệt không hỗ trợ thì chỉ khi tab còn mở`.
  - Ideas doc, row `Notifications`:
    - append to the middle cell `; web nhận push từ máy chủ (Web Push, dịch vụ notify) cả khi đã đóng tab, cài đặt thông báo đồng bộ giữa các máy`;
    - set the right cell to `Android push từ máy chủ (P6b-2, chờ file Firebase); iOS (P6b-3, chờ tài khoản Apple)`.

- [ ] **Step 1: Write the script and make the doc edits.**
- [ ] **Step 2: Check the script.** Run `$ENV node --check tool/e2e/push.mjs`. Expected: exit 0. **Do not run it.**
- [ ] **Step 3: Full verification.**
  - Run `$ENV $FLUTTER test --concurrency=2` in the background with Monitor, streaming the step and pass/fail counts every minute.
  - Then `$ENV $FLUTTER analyze`.
  - Then `$ENV $FLUTTER build web --release --dart-define=VAPID_PUBLIC_KEY=BKtest` and the Task 14 build checks.
  - Then `cd server/notify && $ENV npm test`, and again with `NOTIFY_PLAN_BIN=../../build/notify_plan.exe` after recompiling the Windows helper.
  - Then the Task 5 cross-compile and `file` check.
  - Expected: all green.
- [ ] **Step 4: Grep checks.**
  - `git grep -n "package:web\|dart:js_interop" lib` lists only `notification_platform_web.dart`, `push_platform_web.dart` and the files that used them on `main` (compare with `git grep` on `main`).
  - `git grep -n "seedDrills\|seedKnowledge" lib bin` lists only `lib/data/seed/`, `upsert_seed.dart` and `bin/notify_plan.dart`.
  - `git grep -n "console.log" server/notify/src` finds nothing (logging goes through the injected `log`).
- [ ] **Step 5: Commit.** Message: `P6b-1: E2E Web Push qua CDP (đẩy giả vào worker, chạm, mở lạnh, đăng xuất), cập nhật PRD và tài liệu ý tưởng`, plus the trailer.
- [ ] **Step 6: Hand the controller the release steps below. Do not do them yourself.**

---

## Release steps (not tasks; the controller runs them with the owner's consent)

1. **Keys, generated by Claude and never printed.**
   - With `node -e` and `server/notify/node_modules/web-push`'s `generateVAPIDKeys()`, write `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` and `VAPID_SUBJECT=https://poolcoachai.kjdybl.easypanel.host` into the `env` block of the main checkout's `.claude/settings.local.json`.
   - Do the same for `PUSH_SERVICE_TOKEN`, as 32 random bytes in hex from `node:crypto`.
   - Print only `đã ghi`.
2. **Directus on prod, before the PR is pushed.** Run `node deploy/directus/bootstrap.mjs` with `PUSH_SERVICE_TOKEN` set, then `node deploy/directus/verify.mjs`. Both must pass. The changes are additive, and old builds never touch the new collections.
3. **Deploy `notify` before the web build that registers devices.**
   - From a clean commit, run `FLUTTER=… DART=… bash deploy/publish-notify.sh`.
   - Then through `tool/deploy/easypanel.mjs`:
     - `createAppService` in project `test-va`, name `notify`, **without** a source.
     - `updateAppSourceGit`: repo `anhnpvse02755-png/PoolCoachAI`, branch `deploy-notify`, path `/`, Dockerfile.
     - `updateAppEnv` (this replaces the whole env): `DIRECTUS_URL=https://poolcoachai-api.kjdybl.easypanel.host`, `PUSH_SERVICE_TOKEN`, `ALLOWED_ORIGINS=https://poolcoachai.kjdybl.easypanel.host,http://localhost:5555`, `PUBLIC_URL=https://poolcoachai-notify.kjdybl.easypanel.host`, the three `VAPID_*`, `PUSH_ENABLED=true`, `TZ=UTC`.
     - Domain `poolcoachai-notify.kjdybl.easypanel.host` → port 8080.
     - Resources 0.25 CPU / 256 MB.
     - `deployAppService` through `execute_destructive`.
   - Check:
     - `inspectAppService` `commit.hash` equals the `deploy-notify` head.
     - `getDockerContainers` shows `test-va_notify` running.
     - `/healthz` returns `ok` with a recent `lastCycleAt`.
     - `/push/config` carries the CORS header for the app origin.
     - `POST /push/devices` without a token returns 401.
4. **PR and release.** Open the PR and wait for CI (android, including the helper compile and the Chrome id test; ios; notify). Merge.
   - Publish web with `VAPID_PUBLIC_KEY` in the env (`deploy/publish.sh` refuses without it), then `deployAppService` for `poolcoachai`. Check the `main.dart.js` hash.
   - Re-run `publish-notify.sh` from merged `main` if `server/notify` or the helper changed since step 3.
5. **Live checks.** Run the existing live e2e suite plus `PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/push.mjs`.
6. **Owner eye-check in a normal desktop Chrome (and Android Chrome if possible).**
   - Enable notifications. The screen says "đến cả khi đã đóng tab".
   - Add a schedule slot 40 minutes ahead, close every tab, and wait for the reminder.
   - Click it: it opens Lịch tập, and "Đã gửi" lists it once.
   - Sign out: no further notifications arrive.
7. **Rollback.** Set `PUSH_ENABLED=false` with `updateAppEnv`, then redeploy `notify`. Apps return to local mode on the next refresh or open, at most 6 h for closed tabs. There is no Drift change, so a web rollback to c32147a stays safe.
