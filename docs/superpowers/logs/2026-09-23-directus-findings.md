# Directus Findings — Task 2

Date: 2026-09-23
Directus version: 12.3.1
Server: https://poolcoachai-api.kjdybl.easypanel.host

All checks in verify.mjs passed. Step 3 (session-revoke extension) was NOT needed.

---

## NOTE rows from verify.mjs (with app dependency)

### 1. Duplicate registration → status 204, no error code

```
đăng ký email đã có → status 204, code (không có)
```

**App dependency (Task 4):** Directus returns `204` with no `errors` body when registering an email that already exists. The client must treat `204` with an empty body as `AuthFailure.emailTaken`. There is no `code` field to map — the absence of a 200/204-with-token IS the signal.

---

### 2. Unknown email for password reset → status 204

```
yêu cầu đặt lại cho email không tồn tại → 204
```

**App dependency:** Directus silently accepts password-reset requests for non-existent emails (standard anti-enumeration behaviour). No error is returned to the caller; no email is sent.

---

### 3. Drill log duplicate id → status 400, code RECORD_NOT_UNIQUE

```
gửi lại cùng id → status 400, code RECORD_NOT_UNIQUE
```

**App dependency (Task 7):** When a drill log is submitted with an `id` that already exists, Directus returns `400 RECORD_NOT_UNIQUE`. Task 7 must treat this code as "already synced" and not treat it as an error.

---

### 4. Wrong reset token → status 403, code INVALID_TOKEN

```
token đặt lại sai → status 403, code INVALID_TOKEN
```

**App dependency (Task 4):** A bad reset token returns `403 INVALID_TOKEN`. Map this to `AuthFailure.resetLinkInvalid`.

---

### 5. Reused reset token → status 403, code FORBIDDEN

```
dùng lại link đặt lại → status 403, code FORBIDDEN
```

**App dependency (Task 4):** After a reset token is used once, using it again returns `403 FORBIDDEN`. Map this to `AuthFailure.resetLinkInvalid` (same UX as a bad token — the link is no longer valid).

---

### 6. Old refresh token after password change → status 401, code INVALID_CREDENTIALS

```
làm mới bằng refresh token cũ → status 401, code INVALID_CREDENTIALS
```

**App dependency:** After a successful password reset, Directus immediately invalidates all existing refresh tokens for that user. The old token returns `401 INVALID_CREDENTIALS`. The client must re-authenticate with the new password. This is correct security behaviour — Step 3 hook was NOT required.

---

## Answers to the three spec questions

### Q1: Đăng ký email đã có thì server trả gì?

Status: `204`
Code: none (empty body, no `errors` array)

The response body is empty. The client must detect this by the absence of `data.access_token` on a `2xx` response, or by re-interpreting `204` as `emailTaken`.

### Q2: Token đặt lại sai hoặc đã dùng thì status và code là gì?

Wrong token: `403 INVALID_TOKEN`
Reused token: `403 FORBIDDEN`

Both map to `AuthFailure.resetLinkInvalid` on the client.

### Q3: Gửi lại cùng id buổi tập thì code là gì?

`400 RECORD_NOT_UNIQUE`

Task 7 treats this as "already synced" — no error surface to the user.

---

## Step 3 status

**Step 3 was NOT needed.** Directus 12.3.1 correctly revokes all sessions on password change (old refresh token returns `401 INVALID_CREDENTIALS`). No custom hook required.

---

## Additional observations

- Registration (new email): `204`
- Short password (7 chars): `400 FAILED_VALIDATION`
- Drill log create (valid): `200`
- Drill log list as correct user: returns only own records
- Drill log list as other user: returns empty `[]`
- Drill log list as anonymous: `403`
- Drill log PATCH by Player: `403`
- Drill log DELETE by Player: `403`
- Player reads another user's record: `403`
- Player tries to forge `user_created` on drill_log create: `403 FORBIDDEN`
- Password reset request (valid email): `204`
- Password reset (success): `204`
- Password reset with bad token: `403 INVALID_TOKEN`
- Password reset with reused token: `403 FORBIDDEN`
- Refresh with old token after reset: `401 INVALID_CREDENTIALS`
- Login with new password after reset: `200` with `access_token`
