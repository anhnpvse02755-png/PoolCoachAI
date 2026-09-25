# Accounts & sync — follow-ups left open at merge (2026-09-24)

Small items the reviews found and parked. None blocks use; all were judged
low-risk at the time. Items fixed before the merge are not listed.

## Closed 2026-09-25

### Behaviour

- signIn bumps the session generation only after `_takeTokens`, so a stale
  refresh could overwrite the access token — 3a8e3fc
- A stale refresh whose token was rotated by another tab reports `network`
  instead of `sessionExpired` — 3a8e3fc
- An empty session store while SignedIn emits `SignedOut(expired: true)`
  instead of a plain `SignedOut` — 3a8e3fc
- `signIn` takes tokens before `/users/me` succeeds; register + network
  failure, then retry, yields `emailTaken` — 67db873
- Retry-path expiry compares the store to the first rejected token, not the
  one just used: a dead session costs one extra `network` before expiring —
  3a8e3fc
- `signOut` racing a refresh success can send `/auth/logout` with the old
  refresh token, leaving the new one valid server-side until its TTL —
  3a8e3fc
- `SyncService.start()` has no double-call guard; `dispose()` does not stop
  an in-flight pass; a `syncServiceProvider` rebuild creates an unstarted
  service — 5a92557
- A drill log saved during a sync pass that also hit a server-rejected row
  waits up to 30 s for the next pass (the loop repeated only on `done`) —
  5a92557
- Rows already stored with an infinite score report `failed` on every pass
  and there is no UI to discard them — d547b20 (Profile shows them and lets
  the player drop them; the validator blocks new ones)
- Cross-account token leak. `signIn` while already signed in took the new
  user's tokens while the old `SignedIn` state was still current, so
  SyncService could push the old user's logs with the new user's token.
  The same leak was reachable without that UI path: all browser tabs
  share one session store (Drift web is one DB), so a tab still
  `SignedIn(An)` refreshed with Bình's stored session after another tab
  switched accounts. Both paths are fixed — b73b77e. Refresh now signs the
  tab out (plain `SignedOut`, no logs deleted, the other tab's session left
  in place) without calling the server, and sign-in hands out the new
  token only together with the new state.
- "Đồng bộ trước" blamed the network when the only rows left were ones
  that can never sync; it now points to the Profile warning — c4b4f32

### Server Tooling (deploy/directus)

- Licence detection keyed on `entitlements.display_powered_by === 'OIG'`.
  `license.source` was evaluated and rejected: it records provenance only,
  not what the licence allows. The check now reads
  `entitlements.custom_permission_rules_enabled` through admin
  `GET /license` — ec0bda8
- `bootstrap.mjs` called `GET /license` a third time, without a catch, just
  for the success log line; it now reuses the licence the check fetched —
  9d6955c
- `env.example` does not mention `DIRECTUS_LICENSE_KEY` — already present
  before this pass (env.example:44-48)
- The create branches of `bootstrap.mjs` (licence, collection, role,
  policy) have never run against a clean server — Task 7 clean-server run:
  20/20 verify.mjs passed
- `verify.mjs`: the short-password check accepts any status >= 400
  (including 500); the forged-`user_created` result is logged as NOTE
  before it is asserted — 7ae8f5c..ec0bda8
- `verify.mjs`: in the 200 path, the forged-owner fallback passed on a null
  owner. Only `user_created === A` passes now — 9d6955c (checked with
  `node --check`; not yet run against a server)

### Tests and docs

- No test pins which sign-out dialog action is primary — d547b20
- `app_test`'s router-less test relies on the test container's implicit
  signed-in auth — edf96a3
- `converters_test` round-trip test shadows the file-level `db` — edf96a3
- The bootstrap source-order test could also assert `restoreSession(`
  precedes `runApp(` — 5a92557
- `_expire`'s bump-before-clear ordering and its post-clear generation
  check have no test — 3a8e3fc
- The test "token mới hơn cũng bị từ chối…" did not assert the refresh
  call count and kept English comments — 8519307
- The double-start sync test waited 35 ms of real time, and its comment
  credited the third GET to a periodic timer. `retryEvery` in that suite is
  30 s: the third GET came from the first pending-stream emission
  scheduling one more pass. The test also passed with the `_started` guard
  removed. It now waits for the event queue to go idle and checks that one
  sign-in runs exactly one pass, which fails without the guard — 8519307

## Still open

- A failed signIn while signed in can drop an in-flight refresh rotation,
  which forces a later expiry. Unreachable through the UI, because
  authRedirect keeps signed-in users off /login and /register.
- No test pins `_refreshing = null` in signIn on its own.
