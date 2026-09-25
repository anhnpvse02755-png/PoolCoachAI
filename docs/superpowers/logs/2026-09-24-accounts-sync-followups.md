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

### Server Tooling (deploy/directus)

- Licence detection keys on `entitlements.display_powered_by === 'OIG'`;
  `license.source` would be sturdier — ec0bda8
- `env.example` does not mention `DIRECTUS_LICENSE_KEY` — already present
  before this pass (env.example:44-48)
- The create branches of `bootstrap.mjs` (licence, collection, role,
  policy) have never run against a clean server — Task 7 clean-server run:
  20/20 verify.mjs passed
- `verify.mjs`: the short-password check accepts any status >= 400
  (including 500); the forged-`user_created` result is logged as NOTE
  before it is asserted — 7ae8f5c..ec0bda8

### Tests and docs

- No test pins which sign-out dialog action is primary — d547b20
- `app_test`'s router-less test relies on the test container's implicit
  signed-in auth — edf96a3
- `converters_test` round-trip test shadows the file-level `db` — edf96a3
- The bootstrap source-order test could also assert `restoreSession(`
  precedes `runApp(` — 5a92557
- `_expire`'s bump-before-clear ordering and its post-clear generation
  check have no test — 3a8e3fc

## Still open (found during this pass)

- signIn while already signed in: tokens are taken while the old session
  state is still active, so SyncService could briefly use the new user's
  token to sync the old user's data. Unreachable through the UI because
  authRedirect keeps signed-in users off /login and /register.
- A failed signIn while signed in can drop an in-flight refresh rotation,
  which forces a later expiry. Also unreachable through the UI.
- No test pins `_refreshing = null` in signIn on its own.
- The test "token mới hơn cũng bị từ chối…" does not assert the refresh
  call count, and it keeps English comments.
- The double-start sync test depends on a 35 ms real-time wait for a
  30 ms periodic timer.
- verify.mjs: in the 200 path, the forged-owner fallback passes on a null
  owner.

## Still open

- A drill log saved during a sync pass that also hit a server-rejected row
  waits up to 30 s for the next pass (the loop repeats only on `done`).
- Rows already stored with an infinite score report `failed` on every pass
  and there is no UI to discard them. The validator blocks new ones.
