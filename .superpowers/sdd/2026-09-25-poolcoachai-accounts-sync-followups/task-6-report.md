# Task 6 Report

## What was done

### Step 1 — Live licence shape

Queried GET /server/info on the live server (test-va/api). The redacted `license` object:

```json
{
  "source": "settings",
  "entitlements": {
    "production_enabled": true,
    "ai_translations_enabled": true,
    "display_powered_by": "OIG"
  }
}
```

`source` records provenance only — 'env', 'settings', or null — and carries no tier
information. `display_powered_by` is the only tier signal the client can read from
/server/info (`custom_permission_rules_enabled`, the capability we actually need, is not exposed).
The check combines both: `source != null` confirms a real licence is loaded (not the Core
fallback), and `display_powered_by === 'OIG'` confirms the tier.

### Step 2 — bootstrap.mjs

Replaced the two `display_powered_by` comparisons with a single `isOig(info)` helper:

```js
const isOig = (info) => info.license?.source != null && info.license?.entitlements?.display_powered_by === 'OIG';
```

Both uses (`infoBefore` and `infoAfter`) now call `isOig`. Log line updated to
`Licence đã kích hoạt (OIG)`; the skip line is unchanged.

### Step 3 — verify.mjs

Short password (line 54–55): changed from a lenient `status >= 400` note to an exact
assertion `status === 400 && code === 'FAILED_VALIDATION'`.

Forged `user_created` (lines 94–106): removed the `note(...)` line and restructured the branch
to assert 403 directly, keeping the ownership check for the 200/201 case:

```js
if (forgedRes.status === 403) {
  ok('server từ chối tạo với user_created giả mạo → 403');
} else if (forgedRes.status === 200 || forgedRes.status === 201) {
  // ownership check unchanged
} else {
  fail(`tạo với user_created giả mạo → ${forgedRes.status} ${forgedRes.code}`);
}
```

### Step 4 — Live run results

**bootstrap.mjs** (no DIRECTUS_LICENSE_KEY in env):
```
Licence đã kích hoạt (bỏ qua)
Đặt 4 quyền cho Player policy (xoá 4 quyền cũ)
Xong. Role Player = 4f764dee-c713-4fd0-9e93-169c8e9b859a, policy = 1192dfa0-c432-4716-ae39-ecfa7b6790bb
```

**verify.mjs** — all 20 checks passed:
```
OK   đăng ký verify-98b291ef-a@poolcoachai.example.com → 204
OK   đăng ký verify-98b291ef-b@poolcoachai.example.com → 204
OK   đăng nhập ngay sau đăng ký, không cần xác minh
OK   user mới có role Player
NOTE đăng ký email đã có → status 204, code (không có)
OK   mật khẩu 7 ký tự bị từ chối → 400 FAILED_VALIDATION
OK   A tạo được buổi tập
NOTE gửi lại cùng id → status 400, code RECORD_NOT_UNIQUE
OK   gửi trùng id không tạo bản ghi thứ hai
OK   A đọc được đúng một buổi của mình
OK   B không thấy buổi của A
OK   không token → 403
OK   A không sửa được buổi tập
OK   A không xoá được buổi tập
OK   B không đọc được record user của A
OK   server từ chối tạo với user_created giả mạo → 403
OK   A không tự nâng role được
OK   yêu cầu đặt lại mật khẩu được nhận
NOTE yêu cầu đặt lại cho email không tồn tại → 204
NOTE tiêu đề thư: Password Reset Request
OK   thư dùng template tiếng Việt
OK   link đúng dạng đường dẫn: https://poolcoachai.kjdybl.easypanel.host/reset-password?token=eyJhbGc…
NOTE token đặt lại sai → status 403, code INVALID_TOKEN
OK   đặt lại mật khẩu thành công
NOTE dùng lại link đặt lại → status 403, code FORBIDDEN
NOTE làm mới bằng refresh token cũ → status 401, code INVALID_CREDENTIALS
OK   đổi mật khẩu làm phiên cũ mất hiệu lực
OK   đăng nhập bằng mật khẩu mới

Tất cả kiểm tra đều qua
```

### Step 5 — Commit

Commit `7ae8f5c` on `fix/accounts-sync-followups`:
`deploy/directus/bootstrap.mjs`, `deploy/directus/verify.mjs` (2 files, +17/-9 lines).

---

## Fix round 1 (review findings)

### Finding: `isOig` check was wrong

`source` is purely provenance ('env', 'settings', null) — it carries no tier information.
The original `info.license?.source === 'settings'` would pass for any licence activated through
POST /license, not just OIG. The post-activation guard would become dead code. An OIG licence
set via env would report `source = 'env'` and be refused with a wrong diagnosis.

`/server/info` does not expose `custom_permission_rules_enabled` (the capability we actually need),
so `display_powered_by` is the only tier signal available.

**Fix:** `const isOig = (info) => info.license?.source != null && info.license?.entitlements?.display_powered_by === 'OIG';`

Comment rewritten to explain: `source` records provenance only; `custom_permission_rules_enabled`
is not exposed; the check combines both to cover the gap. Version citation removed (12.3.1 was
never confirmed from `/server/info`).

Report corrected: `source` no longer described as "directly indicating" OIG.

### Live re-run

Command (same env as Step 4, DIRECTUS_LICENSE_KEY removed):
```
node -e "..." (env loaded from settings.local.json, DIRECTUS_LICENSE_KEY deleted)
```

Output:
```
Licence đã kích hoạt (bỏ qua)
Đặt 4 quyền cho Player policy (xoá 4 quyền cũ)
Xong. Role Player = 4f764dee-c713-4fd0-9e93-169c8e9b859a, policy = 1192dfa0-c432-4716-ae39-ecfa7b6790bb
```

Commit `2f1c8a4` on `fix/accounts-sync-followups`.
