# Accounts & sync — follow-ups left open at merge (2026-09-24)

Small items the reviews found and parked. None blocks use; all were judged
low-risk at the time. Items fixed before the merge are not listed.

## Behaviour

- A drill log saved during a sync pass that also hit a server-rejected row
  waits up to 30 s for the next pass (the loop repeats only on `done`).
- Rows already stored with an infinite score report `failed` on every pass
  and there is no UI to discard them. The validator blocks new ones.
- `signIn` while already signed in bumps the session generation only after
  `_takeTokens`, so a stale refresh could overwrite the access token.
  Unreachable today: `authRedirect` keeps signed-in users off /login and
  /register.
- A stale refresh whose token was rotated by another tab reports `network`
  instead of `sessionExpired` (no state change).
- An empty session store while SignedIn emits `SignedOut(expired: true)`
  instead of a plain `SignedOut`.
- `signIn` takes tokens before `/users/me` succeeds; register + network
  failure, then retry, yields `emailTaken`.
- Retry-path expiry compares the store to the first rejected token, not the
  one just used: a dead session costs one extra `network` before expiring.
- `signOut` racing a refresh success can send `/auth/logout` with the old
  refresh token, leaving the new one valid server-side until its TTL.
- `SyncService.start()` has no double-call guard; `dispose()` does not stop
  an in-flight pass; a `syncServiceProvider` rebuild creates an unstarted
  service.

## Server tooling (deploy/directus)

- Licence detection keys on `entitlements.display_powered_by === 'OIG'`;
  `license.source` would be sturdier.
- `env.example` does not mention `DIRECTUS_LICENSE_KEY`.
- The create branches of `bootstrap.mjs` (licence, collection, role,
  policy) have never run against a clean server.
- `verify.mjs`: the short-password check accepts any status >= 400
  (including 500); the forged-`user_created` result is logged as NOTE
  before it is asserted.

## Tests and docs

- No test pins which sign-out dialog action is primary.
- `app_test`'s router-less test relies on the test container's implicit
  signed-in auth.
- `converters_test` round-trip test shadows the file-level `db`.
- The bootstrap source-order test could also assert `restoreSession(`
  precedes `runApp(`.
- `_expire`'s bump-before-clear ordering and its post-clear generation
  check have no test: with single-flight refresh no concurrent refresh can
  be writing during `_expire`, so they are defence in depth.
