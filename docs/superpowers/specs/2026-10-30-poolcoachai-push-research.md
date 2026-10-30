# P6b server push: design research (read-only, origin/main c32147a, 2026-10-30)

## 0. Recommendation in one paragraph

Add a new Node service, `server/notify` (Easypanel `test-va/notify`). It handles scheduling, Directus access, Web Push (VAPID) and FCM HTTP v1. All content comes from the app's own Dart code, built as a Linux AOT helper (`bin/notify_plan.dart` → `dart compile exe`). That helper reuses `planNotifications`, `computeRecommendation`, `Vi` templates, the seed data, and the same id hash and payload v2. Node never interprets domain data, so nothing is ported and nothing can drift.

The server computes content at send time from the data synced to Directus. Web gets standard Web Push from a dedicated service worker at `/push/sw.js` with scope `/push/` (Flutter's loader would otherwise kill it, see §4). Android gets FCM data messages, which the app shows through flutter_local_notifications with the same id, channel and payload, so tap routing stays unchanged.

Dedupe works per device and per kind. While the device's server lease is valid, those kinds are server-owned and the app masks them out of local planning. The inbox is fed from per-device `push_deliveries` rows that the service worker or app acknowledges.

## 1. What to push and why (value over P6a)

**Gaps in P6a, from the code:**
- **Web delivers only while the tab is open.** `NotificationPlatform.scheduler` returns null on web (`notification_platform_web.dart:20`). A one-minute timer drives delivery (`notification_service.dart:117-120`, `:399-436`). P6a spec §3 "Giới hạn" admits this.
- **Native plans go stale.** The OS-scheduled plan is computed from Drift at the last app open (`notification_service.dart:285-361`). Remote data reaches the device only through pull on sign-in or launch (sync `syncNow` on SignedIn, e.g. `cue_equipment_sync.dart:62`). So:
  - **Streak (20:00):** you practise on web at 18:00, and the phone's reminder, planned at 08:00 with `practicedToday=false`, still fires (`notification_plan.dart:185-201`). The server computes at 20:00 from `drill_logs`/`timer_sessions`, which every device pushes on write, so it suppresses the reminder.
  - **Schedule:** a slot edited or deleted on another device keeps firing on the phone until that phone is opened (`:152-183`).
  - **Maintenance:** a due date changed elsewhere (`:136-150`) has the same problem.
  - **Recommendation (08:00):** the local plan uses logs, matches and BU as of the last open (`recommendation_reminder.dart:32-41`). The server computes at about 08:00 with every device's data. The "already seen" baseline also becomes cross-device (see below).

**Server-computable inputs.** All are already in Directus (`deploy/directus/bootstrap.mjs`):

| Input | Directus source |
|---|---|
| Drill logs | `drill_logs`: drill_id, date, score, attempts, duration (:106-131) |
| Timer sessions | `timer_sessions` (:388) |
| Schedule slots | `schedule_slots`, including `cat_ext`/`is_deleted` (:397) |
| Cues | `cue_equipment.tip_maintenance_due_date` (date), `is_deleted` (:346-363) |
| Matches | `pool_matches` with shots json (:368-386) |
| Latest BU | `bu_tests` + `bu_drill_results`, giving `buResultFrom` (:255-273, `bu_gap.dart:36`) |

- Timestamps are stored in UTC (`practice_sync.dart:368`, `:242-244`). The app converts back to local time.
- So all four kinds are server-computable, given the timezone.

**Local-only inputs today:**

| Input | Where it lives | What P6b does |
|---|---|---|
| Seed drills and knowledge | Compiled Dart constants, upserted on every launch (`upsert_seed.dart:10-22`); drills come only from seed (`drift_repositories.dart:10-21`) | The helper exe imports the same `lib/data/seed/*`, so the server runs the identical seed from the same commit |
| Notification prefs | shared_preferences per device (`notification_prefs_store.dart:13-16`) | Move to synced `notification_settings` |
| Last-seen recommendation | shared_preferences (`recommendation_seen_store.dart:20-23`) | Sync it as well |
| Notification log | Drift, not synced (`notification_log_repository.dart:7-9`) | Server keeps its own delivery rows |
| Timezone | Device only (`local_notifications_scheduler.dart:39-40`) | App sends it with registration |

- **Seed and version sync.** Add `seedFingerprint()`: a stable hash over drill id, cat, name, level and threshold plus knowledge id and cat, computed by the same Dart code in the app and the exe. Each device registers its fingerprint.
  - The server owns `recommendation` only for devices whose fingerprint equals its own. For other devices that kind stays local.
  - This covers an old APK paired with a newer server, or a web build running ahead of the APK. Old seed rows are never deleted on devices, so ids can diverge.
- **Architecture test.** `test/architecture_test.dart` has the rule "seed only via upsertSeed". It scans only `lib/`. Document an explicit exception for `bin/notify_plan.dart`: the server has no DB, and the seed constant is the single source.

## 2. How the server computes without fabricating

**(a) Port to Node and add golden parity tests: rejected.**
- `computeRecommendation` pulls in `computePlayerIntelligence`, `pickCategoryForToday`, `pickDrillInCategory`, match analysis, BU gap and drill ratio (`recommendation.dart:1-11`, `:283-352`). It also needs a 2,470-line `vi.dart`, the seed, and the FNV id with collision walk (`notification_plan.dart:209-268`).
- A Node port doubles maintenance on the most fabrication-sensitive code. Every rule change needs two edits plus golden regeneration.

**(b) Run the real Dart domain on the server: recommended.**
- **Flutter-freeness, verified.** Across `lib/domain`, `lib/core/strings` and `lib/data/seed`, the only non-domain imports are `dart:math` and `vi.dart`. The single blocker is `lib/domain/skill_category.dart:1` (`import 'package:flutter/material.dart'`), used for `Color fg/bg/borderColor` (:19-78).
  - **Fix:** move the colours to a UI extension (e.g. `lib/core/theme/skill_category_colors.dart`). They are used only in `lib/core/widgets/pc_skill_chip.dart:23,24,32` and two tests (`test/core/widgets/pc_skill_chip_test.dart:36`, `test/domain/skill_category_test.dart:34,40`).
  - `vi.dart` imports only domain files, and `seed_drills.dart:1` imports `vi.dart`. Both are fine.
- **Decoders.** Remote JSON → domain decoders currently sit inside Drift-coupled sync code: `converters.dart:3-4` imports drift and `database.dart`, which imports `drift_flutter` (`database.dart:2`).
  - Extract pure decoders (Directus row → `DrillLog`/`TimerSession`/`ScheduleSlot`/`CueEquipment`/`PoolMatch`/`TestSnapshot`) into e.g. `lib/data/remote/codecs/`. `match_codec.dart` and `category_compat.dart` are already pure.
  - The sync code and the exe both use them, so parity in the input mapping holds by construction.
- **Timezone.** `package:timezone` is already a dependency (`pubspec.yaml:43`) and is pure Dart. The exe converts UTC instants to the device's IANA zone and builds "wall-clock" `DateTime(y,m,d,h,…)`. The container runs in UTC, so `toIso8601String()` matches the device form, and the ids in `notification_plan.dart:212` come out identical for identical inputs.
- **Protocol.** Node spawns one long-lived exe and exchanges NDJSON on stdin and stdout.
  - Input: `{nowUtc, tz, prefs (masked to server kinds), seen, data:{raw Directus rows…}, recDeliveries}`.
  - Output: `[{id, kind, key, atLocal, atUtc, validUntilUtc, title, body, payload}]`.
  - The `payload` comes from the same `notificationPayload()` (`notification_payload.dart:34-40`). The baseline comes from the same `recommendationBaseline()` (`notification_log.dart:77-98`), fed with the server's past recommendation deliveries.
- **Building and shipping:**
  - The exe is built from a clean commit by a new `deploy/publish-notify.sh`, using `dart compile exe --target-os=linux --target-arch=x64`. Dart 3.13 can cross-compile to Linux; if that fails on Windows, use a CI ubuntu job.
  - The exe and `server/notify` are pushed to a `deploy-notify` branch, the same pattern as `deploy/publish.sh:31-51`.
  - Never compile on the VPS (`deploy/Dockerfile:1-3`).
  - The image must be glibc-based (`node:24-bookworm-slim`). coach-chat's `node:24-alpine` is musl and a Dart AOT exe won't run there.
  - Add a CI step that runs `dart compile exe bin/notify_plan.dart`. It fails if a Flutter or `dart:ui` import leaks into the closure, which is a stronger check than the architecture test.
- **Cost.** An AOT exe uses about 20-40 MB of RAM and milliseconds per user. Under a 0.25 CPU / 256 MB cap like coach-chat's, it stays far from cms/website.

**(c) Data-changed silent pushes, with the app computing locally: rejected as the main path.**
- Web Push requires `userVisibleOnly: true`, so every push must show a notification. A service worker cannot run the Flutter app, Drift or Riverpod. Web gains nothing.
- On Android, a data message reaches a background isolate, but replanning there means running sync, auth and Drift in that isolate. Drift streams don't cross isolates, and Android deprioritises high-priority messages that show nothing. It is fragile.
- Keep only one silent message type: an Android delivery-verification ping (§3).

## 3. Dedupe with P6a local notifications, and inbox truth

**Rule: per-device, per-kind ownership with a server lease.**
- **Registration.** The app calls `POST /push/devices`. The server stores the row and returns `serverKinds`: all four kinds, minus `recommendation` when the seed fingerprint differs, minus everything for an unverified Android device. It also returns `lease_until`, which the server renews to now+6h on each healthy cycle.
- **App behaviour.** While `lease_until > now`, the app plans locally with `prefs` minus `serverKinds`, using the existing `NotificationPrefs.toggled` (`notification_prefs.dart:49-59`), so `planNotifications` needs no change.
  - **Native:** the existing `reconcileNotifications` cancels the pending items of those kinds, and `syncPlanned` deletes their future log rows (`notification_log_repository.dart:64-93`). This is already truthful.
  - **Web:** the timer stops showing those kinds (`notification_service.dart:417-436`).
- **Fallback.** If the lease has expired, the row is missing (pruned after 404/410/UNREGISTERED), or `GET /push/config` returns `enabled:false` (kill switch), the app goes back to full P6a local mode on its next open.
- **Single writer for mode.** The app writes `mode` (`server`/`local`) on its row, and the server sends only to `mode=server` devices. The server never sends kinds the app is still scheduling.
- **Accepted trade-off:** if the server dies, a closed device gets nothing until it is next opened. Mitigations are `/healthz`, the lease, and a 6h bound on how long any one device stays wrong.
- **Bonus from identical ids.** The server's `PlannedNotification.id` equals the local one when inputs are identical, and the Android handler calls `show(id: n.id)`. So at a mode boundary an identical item replaces the local one instead of duplicating it, and the log's `insertOrIgnore` on id also dedupes.

**Android delivery path: FCM data messages, high priority, no `notification` block.**
- `FirebaseMessaging.onBackgroundMessage` (top-level, `@pragma('vm:entry-point')`) and `onMessage` both call `FlutterLocalNotificationsPlugin.show(id, title, body, details(channel = _channelId(kind)), payload: v2…)`. This reuses `local_notifications_scheduler.dart:21-26` and `:128-136`.
- Taps flow through the existing `onDidReceiveNotificationResponse` and `getNotificationAppLaunchDetails` (`:51-64`), so no new routing.
- This works when the app is killed or swiped. It does not work after a force-stop, and some OEMs (Xiaomi/Oppo/Vivo) block background starts; that is a risk, also for local alarms.
- **Verification.** At registration the server sends a non-displayed `type=verify` data message. The handler acknowledges it (`POST /push/ack {fcmToken, nonce}`), and only then does the device get `serverKinds`.
- **Ongoing health.** The handler acknowledges each delivery. If acknowledgements stop for N consecutive sends, the device is marked unverified and its lease is not renewed, so it falls back to local mode.

**Inbox ("Đã gửi") truth:**
- The server writes `push_deliveries` per device and key: id = sha256(device_id|kind|key), with notification_id, kind, key, title, body, sent_at and acked_at.
  - **Web:** the service worker acknowledges after `showNotification`. It authenticates with its own subscription endpoint, a capability URL looked up by sha256 (`pushManager.getSubscription()`), so it needs no token.
  - **Android:** the handler acknowledges with its FCM token.
- The app pulls its own device's acknowledged rows (Player can read only rows for its own user) on launch, resume and push-received. A BroadcastChannel from the service worker triggers the pull on web. Rows are inserted into `notification_log_rows` with `at = acked_at` (local), through the existing `recordShown`-style `insertOrIgnore` (`notification_log_repository.dart:107-122`).
  - The inbox shows exactly what this device displayed, consistent with P6a's per-device log.
  - `syncPlanned` won't delete these rows: they are in the past and not in the `cancelled` set.
- **Tap race:** the tap handler awaits that pull (with a timeout) before `markReadByKey` (`notification_service.dart:140-161`). Otherwise the row may not exist yet.
- **No Drift schema bump:** the rows fit the existing columns. This keeps web rollback safe, given the memory note "never roll back below a1805cc".

## 4. Web Push specifics

- **Critical finding: Flutter's loader would hijack a root-scoped push worker.**
  - `build/web/flutter_bootstrap.js` (local Flutter 3.47 build) calls `_flutter.loader.load({serviceWorkerSettings:{serviceWorkerVersion}})`. Inside `loadServiceWorker`, when no `serviceWorkerUrl` is set, it runs `navigator.serviceWorker.getRegistration().then(r => r ? register('flutter_service_worker.js?v=…') : resolve())`.
  - `build/web/flutter_service_worker.js` is a cleanup worker: on activate it calls `self.registration.unregister()` and navigates its clients.
  - So a push worker registered at scope `/` would be replaced and unregistered on every page load, taking its PushSubscription with it.
  - **Fix:**
    1. Put the worker at `web/push/sw.js` and register it with `{scope: '/push/'}`. `getRegistration()` matches by document URL, so app routes under `/` don't see it, and no route may start with `/push`.
    2. Also ship a custom `web/flutter_bootstrap.js` template (`{{flutter_js}}` `{{flutter_build_config}}` plus `_flutter.loader.load()` without `serviceWorkerSettings`), which also removes the deprecation warning.
  - The worker doesn't need to control pages. `clients.matchAll({type:'window', includeUncontrolled:true})` still finds the tabs.
- **Service worker contents** (plain JS, no Flutter):
  - `push`: parse the JSON, `showNotification(title, {body, tag: kind+':'+key, data: {payload, deliveryId}, icon: '/icons/Icon-192.png'})`, then acknowledge, then post on `BroadcastChannel('pcai-push')`.
  - `notificationclick`: if a tab exists, `focus()` it and post `{type: 'tap', payload}`. Otherwise `clients.openWindow('/?n=' + encodeURIComponent(payload))`.
  - The app implements `takeLaunchPayload()` on web, today `Future.value()` at `notification_platform_web.dart:17`. It reads `n` from `Uri.base`, then strips it with `history.replaceState`.
- **Subscription from Dart** (`package:web`, already a dependency at `pubspec.yaml:41`), in a new `push_platform_web.dart` behind a conditional import, mirroring `notification_platform.dart:1-3` for the mobile-target rule:
  - `navigator.serviceWorker.register('/push/sw.js'.toJS, RegistrationOptions(scope: '/push/'))`
  - `registration.pushManager.subscribe(PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: vapidKeyBytes.toJS))`
  - `subscription.toJSON()` yields endpoint, p256dh and auth, which go to `POST /push/devices` together with the timezone (`Intl.DateTimeFormat().resolvedOptions().timeZone` via js_interop).
- **Permission UX.** Keep the existing "Bật thông báo" button, which runs inside a user gesture. Subscribe right after `granted`.
  - The Notifications screen states the mode truthfully from the lease state, as `vi.dart` templates. Examples: "Thông báo đến cả khi đã đóng tab" in server mode, the current "chỉ khi tab mở" in local mode. The P6a cross-device caveat is shown only in local mode.
- **VAPID:**
  - Generate a P-256 key pair locally and never print it. Store `VAPID_PRIVATE_KEY`, `VAPID_PUBLIC_KEY` and `VAPID_SUBJECT` (an `https://poolcoachai.kjdybl.easypanel.host` URL, so no email is needed) in the Easypanel env and in settings.local.json.
  - The app fetches the public key from `GET /push/config`. If it differs from the subscription's `options.applicationServerKey`, the app resubscribes, which handles rotation.
- **Sending from Node:**
  - Use `web-push`, pinned to an exact version. It handles RFC 8291 aes128gcm plus VAPID ES256. The alternative is about 120 lines of `node:crypto` tested with the RFC 8291 §5 vector.
  - Headers: `TTL` = seconds until `validUntil`, `Topic` = short hash of kind:key (so the push service collapses undelivered duplicates), and `Urgency: high` for schedule/streak.
  - The payload is ≤ 4 KB, which is fine.
- **nginx.** It already works: `/push/sw.js` is a real file (`deploy/nginx.conf:10-12`), `no-cache` applies globally (`:18`), and `.js` maps to `application/javascript`. No `Service-Worker-Allowed` header is needed because the scope is not above the script. Optionally add an explicit `location = /push/sw.js` for clarity.
- **iOS bonus.** iOS 16.4+ supports Web Push for home-screen-installed PWAs. `manifest.json` already has `"display": "standalone"`, so iOS users can get closed-app push with no Apple account. Document it and treat it as optional.

## 5. Android FCM specifics

- **Packages.** Add `firebase_core` and `firebase_messaging` at the latest stable versions that resolve with Flutter 3.47 / Dart 3.13 (`flutter pub add` at implementation time). Pin them exactly, because `pubspec.lock` is git-ignored (`.gitignore:9`).
  - On web, never call `Firebase.initializeApp`; web uses VAPID push (keep it behind a conditional import).
- **Gradle.** The project uses AGP 9.1.0, Kotlin 2.4.0 (`android/settings.gradle.kts:22-23`) and Gradle 9.3.1.
  - Add `id("com.google.gms.google-services") version "<latest>" apply false` there and apply it in `app/build.gradle.kts`.
  - **Risk: google-services plugin compatibility with AGP 9 must be verified first.** The fallback without the plugin is to hand-write `res/values/firebase.xml` with the strings the plugin generates (`google_app_id`, `gcm_defaultSenderId`, `google_api_key`, `project_id`). This keeps native auto-init working for killed-app delivery; Dart-only `initializeApp(options)` is weaker for background messages when the app is terminated.
- **google-services.json: commit it.**
  - Firebase documents these config identifiers as not secret.
  - `.github/workflows/android.yml` builds a debug APK on every PR, so the file must be present or CI breaks.
  - The repo is public, so the owner restricts that API key in GCP: Android app restriction (package `vn.poolcoachai.app` plus release SHA-1) and an API allow-list (FCM Registration, Firebase Installations).
  - One client entry is enough: `applicationId` has no debug suffix (`app/build.gradle.kts:30`).
- **The service-account JSON is secret.**
  - It lives only in the Easypanel env as `FCM_SERVICE_ACCOUNT_B64` and in settings.local.json.
  - Add defensive `.gitignore` lines (`*service-account*.json`, `*firebase-adminsdk*.json`).
  - Add it to the `env -u` list used when running service tests.
- **FCM HTTP v1 from Node, with no SDK:**
  - Sign an RS256 JWT with `node:crypto` (`iss` = client_email, `scope` = `https://www.googleapis.com/auth/firebase.messaging`, `aud` = token URI).
  - Exchange it at `oauth2.googleapis.com/token` and cache the access token for about 55 minutes.
  - `POST https://fcm.googleapis.com/v1/projects/{id}/messages:send` with `{message:{token, data:{…strings}, android:{priority:'HIGH', ttl:'<s>s', collapse_key}}}`.
  - Prune on 404 `UNREGISTERED` and on 400 `INVALID_ARGUMENT` for the token. Use exponential backoff on 429/5xx.
  - About 60 lines, tested with injected fetch like coach-chat.
- **Token lifecycle:**
  - Register on sign-in, launch and resume (idempotent upsert, refreshes `last_seen_at`) and on `onTokenRefresh`.
  - On sign-out, call `deleteToken()`, which invalidates locally and works offline, then `DELETE /push/devices/current`.
  - On web, sign-out calls `subscription.unsubscribe()`. This matters for shared devices: payload v2 only ignores the tap (`notification_service.dart:147`); the notification itself would still display.
- **Permission.** Android 13+ is already handled: `POST_NOTIFICATIONS` is in the manifest (`AndroidManifest.xml:6`) and requested via `requestNotificationsPermission` (`local_notifications_scheduler.dart:85-100`). No `FirebaseMessaging.requestPermission` is needed on Android.
- **iOS later:** it needs an APNs key in Firebase, and visible notification messages (iOS throttles data-only messages). The data-message design is Android-specific by intent.

## 6. Backend

**Directus.** All additions go through `ensureCollection` (`bootstrap.mjs:208-233`); service-only collections follow the `owned:false` pattern (`:333-346`).

- **`notification_settings`** (owned; id = user id, like `player_goals`; Player create/read/update own):
  - Fields: recommendation, maintenance, schedule, streak (bool), last_seen_cat, last_seen_cat_ext, last_seen_drill_id, last_seen_at, updated_at.
  - Last-writer-wins on `updated_at`.
  - First run: if the remote row is absent, upload the local prefs and seen value; otherwise adopt the remote.
  - This replaces the per-device `notification_prefs_store` and `recommendation_seen_store`, which become caches. It also closes the P6a §7 item "đồng bộ cài đặt".
- **`push_devices`** (owned:false; **Player has no access**; PushService full access):
  - Fields: id (sha256 of endpoint or token), user (uuid, CASCADE via `ensureUserRelation`), platform (web/android), endpoint, p256dh, auth, fcm_token, timezone, app_source, seed_fingerprint, planner_version, mode, server_kinds (json), lease_until, verified_at, last_seen_at, last_success_at, last_ack_at, failure_count, created_at.
  - Registration goes through the service, not Player permissions. Holding an endpoint or token proves possession, so on a shared device user B's register call re-assigns the row from A. Player permissions cannot do that, and they would also expose `auth` secrets.
- **`push_deliveries`** (owned:false; Player can read rows where `user = $CURRENT_USER`, which is a filtered permission and needs the OIG licence; PushService has create/read/update/delete):
  - Fields as in §3.
  - The service prunes rows older than 30 days (`notificationInboxDays`, `notification_log.dart:6`).
- **Role `PushService`** and a service user `push-service@poolcoachai.example.com` with `PUSH_SERVICE_TOKEN`, copying `:686-760`.
  - Read access, field-limited, to drill_logs, timer_sessions, schedule_slots, cue_equipment, pool_matches, bu_tests, bu_drill_results and notification_settings.
  - No write access to any player data.
- **`verify.mjs` checks:**
  - Player A gets 403 on GET/POST/PATCH of `push_devices`.
  - A reads only its own `push_deliveries` (B's rows are invisible) and cannot create them.
  - `notification_settings` is own-only, like player_goals.
  - The service can read A's drill_logs but gets 403 on PATCH/DELETE.
  - The service can do CRUD on push_devices.

**Service: a new `server/notify`, not an extension of coach-chat.**
- coach-chat is chat-scoped: it holds the Anthropic key and has the CoachChatService role on `coach_chat_usage` only (`bootstrap.mjs:686-726`). It is also undeployed.
- A separate service gives least privilege and a separate failure domain.
- Copy the small proven modules: `config.mjs` (fail fast on missing variable names, never values, `:34-83`), `auth.mjs` (Directus `/users/me` with a 60 s cache, `:15-44`), the `directus.mjs` fetch wrapper with timeout, and `node --test` with injected fetch and clock.
- Easypanel's build context is the subdirectory, so the modules cannot be shared across directories without the deploy-branch assembly.

**Endpoints** (CORS limited to `ALLOWED_ORIGINS`; Vercel preview origins are not listed, so previews stay in local mode):
- `GET /push/config` (public key, enabled)
- `POST /push/devices`, `GET /push/devices/current`, `DELETE /push/devices/current` (Bearer Directus token)
- `POST /push/ack` (endpoint or token as capability)
- `GET /healthz` (last cycle time)

**Scheduler** (in-process, one replica):
- Every 15 minutes, for each user with `mode=server` devices, the exe plans the next 24 h and the service keeps an in-memory due queue (`atUtc`). This finds *when*.
- At each due instant (checked every minute), it re-fetches that user's data and re-runs the exe with `now` = just before `at`. It sends only items with `at ≤ now < validUntil`. This decides *what*, with the freshest data. Load is a few Directus reads per user, about 4-10 times a day.
- Dedupe is claim-then-send: insert the `push_deliveries` row (id PK) first, then send. That gives at-most-once delivery; a duplicate reminder is worse than a missed one.
- Items found late after an outage are sent only while `now < validUntil`, the same rule web P6a uses (`notification_service.dart:418`).
- **Timezone:** per device, from the app (`FlutterTimezone` on native, `Intl` on web), refreshed on every register call. Each device is planned in its own zone, so "today" for the streak is the device's day.
- **Quiet hours:** defer. P6a §7 lists them out of scope, and every time is either fixed (08/09/20) or chosen by the player (slot minus 30 min). There is no catch-up after `validUntil`.
- **Rate limits:**
  - Hard cap of 12 sends per user per local day, as a bug guard.
  - At most 10 devices per user.
  - Register calls limited to 30 per user per hour.
- **Pruning:**
  - Web 404/410 or FCM UNREGISTERED: delete the row.
  - `failure_count ≥ 5`: delete.
  - `last_seen_at` older than 60 days: delete.
  - Deliveries older than 30 days: delete.

## 7. Release order and safety

1. **Directus first.** Run `bootstrap.mjs` then `verify.mjs` on prod before the PR. New builds request the new collections, and a missing field gets a 403 on the whole GET (memory release rule step 1). Changes are additive.
2. **Deploy notify** from `deploy-notify` via `tool/deploy/easypanel.mjs`.
   - Env: `DIRECTUS_URL`, `PUSH_SERVICE_TOKEN`, `ALLOWED_ORIGINS`, the three `VAPID_*` values, and later `FCM_SERVICE_ACCOUNT_B64` and `FCM_PROJECT_ID`.
   - Caps: 0.25 CPU / 256 MB.
   - Check: container running, `/healthz`, CORS, 401.
3. PR, CI, merge, then publish the web app (memory steps 2-6). Then run a live `tool/e2e/push.mjs`.

- **Old builds are unaffected.** They never register, so the server never sends to them, and their Player permissions don't change.
- **Rollback:**
  - Set `PUSH_ENABLED=false`. Then `/push/config` returns `enabled:false` and the server stops sending; apps return to local mode on their next open.
  - Stopping the service makes leases lapse within 6 h.
  - There is no Drift schema change, so web rollback down to c32147a is safe.
- **Secrets:**
  - VAPID private key, `PUSH_SERVICE_TOKEN` and the FCM service-account JSON live only in the Easypanel env and settings.local.json, and are never printed.
  - Run tests with `env -u` for the ambient variables plus the new names.
- **Tests:**
  - **Dart:**
    - The exe entry point on fixtures.
    - Timezone conversion (Asia/Ho_Chi_Minh and one zone with DST).
    - App path vs server path: Directus JSON through sync, Drift and repository vs Directus JSON through the codecs, giving the same `planNotifications` output.
    - The no-fabrication test: change the weak group and the server's notification body changes.
    - Lease and prefs masking in `NotificationService`, inbox ingest, and the tap-then-mark race.
    - Architecture test for the Flutter-free closure, plus the CI `dart compile exe` step.
  - **Node:**
    - Web Push encryption (RFC 8291 vector and a round-trip decrypt) and the VAPID JWT.
    - FCM JWT and token caching.
    - Scheduler due queue with a fake clock.
    - Claim-then-send, caps, pruning on 404/410/UNREGISTERED, lease renewal, CORS, auth.
  - **e2e on headless Chrome: feasible with a caveat.**
    - Already possible: `Browser.grantPermissions` (as in `tool/e2e/notifications.mjs:136`), register, then assert the `/push/` registration and the device row.
    - The deterministic gate: inject a push with CDP `ServiceWorker.deliverPushMessage` and assert `registration.getNotifications()` and the acknowledgement or delivery row.
    - A real round trip through Google's push service from headless Chrome is uncertain; try `--headless=new`, and otherwise fall back to the owner's eye-check in real Chrome.
    - The tap path is tested by posting the BroadcastChannel tap message and by a `/?n=` cold-start URL.
  - **Android:** check on a device (Play-services emulator plus a real phone) with the app killed: verify ping, then the 08:00 recommendation, then a tap opening the drill. Build the APK only at the end (memory).

## 8. Phased plan

**P6b-0 (enablers; can be their own PR, no behaviour change):**
1. Move the SkillCategory colours to a UI extension.
2. Extract pure remote codecs and make the sync code use them.
3. Add `seedFingerprint()`.
4. Add `bin/notify_plan.dart` with the NDJSON protocol, plus tests.
5. Add the CI compile step and the architecture-test exception.

**P6b-1 (Web Push, backend and server compute):**
1. Directus: notification_settings, push_devices, push_deliveries, the PushService role and user; extend `verify.mjs`.
2. `server/notify`: config, auth, directus, exe bridge, scheduler, web-push, pruning, caps, endpoints, tests, Dockerfile (bookworm-slim), the `coach-chat.yml`-style CI workflow, and `deploy/publish-notify.sh`.
3. App:
   - prefs and seen sync
   - push platform (web plus stub/native stubs)
   - SW at `/push/sw.js` and the custom `flutter_bootstrap.js`
   - lease/mode masking in `NotificationService`
   - inbox ingest
   - web `takeLaunchPayload` and BroadcastChannel taps
   - mode-aware `vi.dart` copy
4. Release in the order of §7, with live `push.mjs`.

**P6b-2 (Android FCM, once the owner delivers the Firebase files):**
1. firebase_core and firebase_messaging, the google-services plugin (or `firebase.xml`), and the committed `google-services.json`.
2. Background and foreground handlers using flutter_local_notifications `show` with the same id and channel, plus acknowledgements and the verify flow.
3. Token register, refresh and delete; the FCM v1 sender, pruning and tests.
4. Device checks, then the APK at the end.

**P6b-3 (later):** iOS via APNs in Firebase, once there is an Apple account. The PWA Web Push bridge on iOS 16.4+ can be documented now.

**Main risks:**
1. Flutter's loader killing the worker. Mitigated by the `/push/` scope and the custom bootstrap.
2. google-services plugin vs AGP 9.1. Verify early; fallback is `firebase.xml`.
3. Dart cross-compile on Windows, or VPS architecture other than x64. Confirm the architecture; fallback is a CI-built exe.
4. OEM background killing of FCM. Mitigated by verify and acknowledgements with fallback to local mode.
5. Server outage leaves closed devices silent for up to the lease. Mitigated by the 6 h lease, `/healthz` and the kill switch.
6. Data still unsynced on an offline device is invisible to the server. Inherent; no worse than P6a.
7. The service token has broad read access to player data. Field-limited, read-only, and the token lives only in env.

**What the owner must provide, and when:**
- **Before P6b-1 goes live:**
  - Consent to create the Easypanel service `test-va/notify` and its domain (e.g. `poolcoachai-notify.kjdybl.easypanel.host`).
  - Consent to run bootstrap and verify on prod and to deploy.
  - Nothing else: Claude generates the VAPID keys and `PUSH_SERVICE_TOKEN` locally and stores them in settings.local.json and the Easypanel env.
  - Optionally, an eye-check in real desktop or Android Chrome.
- **For P6b-2:**
  - A Firebase project with an Android app registered as `vn.poolcoachai.app` and the FCM API (V1) enabled.
  - `google-services.json` (it will be committed).
  - A service-account JSON with the FCM send role, delivered privately into settings.local.json. Never paste it into chat.
  - Restricting the Android API key in GCP.
  - A real Android phone for the killed-app test.
- **Later (iOS):** an Apple Developer account and an APNs .p8 key uploaded to Firebase.
