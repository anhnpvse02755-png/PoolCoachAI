# Tài khoản và đồng bộ lịch sử tập — Kế hoạch thực thi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người chơi đăng ký, đăng nhập, quên và đặt lại mật khẩu qua email (mailpit); lịch sử tập được ghi vào máy trước rồi đồng bộ lên Directus theo tài khoản.

**Architecture:** Directus 12.3.1 và Postgres tự host trên Easypanel (`test-va`), cấu hình dựng lại được bằng `deploy/directus/bootstrap.mjs`. App gọi REST qua một `DirectusClient` mỏng. `DirectusAuthRepository` giữ phiên: refresh token lưu trong Drift, access token chỉ nằm trong bộ nhớ. `SyncService` đẩy các dòng `syncedAt IS NULL` của đúng người đang đăng nhập lên server, rồi kéo dữ liệu về. Màn hình vẫn đọc stream Drift như Phase 1.

**Tech Stack:** Flutter 3.47 · Riverpod 3.4 (không codegen) · go_router 18 · Drift 2.31 · `http` 1.6 · `uuid` 4 · Directus 12.3.1 · Postgres 17 · mailpit · Node (script server và E2E) · Chrome headless điều khiển qua CDP

**Spec:** `docs/superpowers/specs/2026-09-23-poolcoachai-accounts-sync-design.md`

## Global Constraints

- Flutter **không có trên PATH**: gọi `C:/Users/anhnpv/flutter/bin/flutter.bat`, Dart là `C:/Users/anhnpv/flutter/bin/dart.bat`. Trong Bash dùng `F=/c/Users/anhnpv/flutter/bin/flutter.bat` và `D=/c/Users/anhnpv/flutter/bin/dart.bat`.
- `*.g.dart` bị git bỏ qua. Sau mỗi lần sửa bảng Drift, và ngay khi mở một bản checkout mới, phải chạy `$D run build_runner build --delete-conflicting-outputs`.
- Mọi chữ tiếng Việt hiển thị đều đi qua `Vi` (`lib/core/strings/vi.dart`). `test/architecture_test.dart` sẽ đỏ nếu `lib/features/**` hay `lib/core/widgets/**` viết chữ tiếng Việt thẳng trong code.
- Không nơi nào trong `lib/` được gọi `.invalidate(` hay `.refresh(`. Màn hình đổi theo stream (guard kiến trúc).
- Test Riverpod dùng `UncontrolledProviderScope` với `ProviderContainer`. **Không** dùng `container.read(x.future)` vì sẽ treo; thay bằng `container.listen(x, (_, _) {})` rồi `await pumpEventQueue()`. **Không** khai báo kiểu `List<Override>` tường minh, vì trình biên dịch sẽ sập.
- Thời gian luôn lấy từ `nowProvider`, không gọi `DateTime.now()` thẳng trong code có test.
- Directus ghim ở `12.3.1`. Postgres ở `postgres:17`. Mailpit ở `axllent/mailpit:v1.31.1`.
- API mặc định là `https://poolcoachai-api.kjdybl.easypanel.host`, đổi được bằng `--dart-define=API_URL=…`. Lúc phát triển, app chạy ở `http://localhost:5555` (`flutter run -d chrome --web-port 5555`).
- Mật khẩu tối thiểu **8 ký tự**, kiểm ở cả app lẫn server (`auth_password_policy`).
- Chỉ đụng vào project Easypanel **`test-va`**. Không chạm vào `cms` hay `website`: đó là production của nexthome.com.vn.
- **Không commit bí mật** (mật khẩu, `KEY`, `SECRET`, token). Bí mật chỉ nằm trong Easypanel và trong khối `env` của `.claude/settings.local.json` (đã bị git bỏ qua). Giá trị sinh ngẫu nhiên phải là hex, **không được chứa `#`**.
- Commit nào cũng kết thúc bằng dòng `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Làm trên nhánh `feat/accounts-sync`, trong worktree dựng bằng superpowers:using-git-worktrees.

## Review Focus

1. **Hai tab cùng mở trên một trình duyệt.** Tab A làm mới phiên nên xoay refresh token. Tab B vẫn cầm token cũ, làm mới thì bị 401. Người dùng mong **không** bị đăng xuất. Test: Task 4, "401 nhưng máy đã có token mới hơn thì thử lại bằng token đó".
2. **Bấm nút gửi hai lần liên tiếp** (Đăng nhập, Tạo tài khoản). Người dùng mong chỉ có một request. Test: Task 6, "bấm Đăng nhập hai lần chỉ gọi một lần".
3. **Email có khoảng trắng hoặc chữ hoa** (`" An@Example.COM "`). Đăng ký kiểu này thì đăng nhập kiểu kia vẫn phải khớp. Test: Task 4, "email được cắt khoảng trắng và viết thường".
4. **Đổi người dùng giữa lúc đang đồng bộ.** A đang kéo dữ liệu thì bấm Đăng xuất. Dữ liệu kéo về không được ghi xuống máy. Test: Task 7, "đổi người giữa chừng thì không ghi gì".
5. **Mở app khi mất mạng nhưng đã có phiên.** Người dùng mong vào thẳng app, không bị đẩy về màn Đăng nhập. Test: Task 4, "khôi phục phiên không cần mạng".

## Chỗ kế hoạch lệch khỏi spec

- **Spec 3.5 ghi `schema.yaml` và `bootstrap.sh`.** Kế hoạch gộp schema vào `bootstrap.mjs` (Node) và tạo collection bằng REST theo kiểu idempotent. Lý do: máy này không có `jq`, và muốn tạo snapshot thì collection phải tồn tại sẵn trên server. Đảm bảo của spec vẫn giữ nguyên: dựng lại toàn bộ cấu hình từ một server trống bằng một lệnh.
- **`AuthRepository` có thêm `current` và `restore()`** so với spec 4.1. Router cần trạng thái đồng bộ ngay khung hình đầu, và phiên phải khôi phục được mà không cần mạng.
- **`AuthFailure` có thêm `unknown`**, dành cho 5xx hay cấu hình sai: một loại lỗi mà spec chưa đặt tên.

---

## Bản đồ file

| File | Trách nhiệm |
|---|---|
| `deploy/directus/bootstrap.mjs` | Dựng collection, role, policy, quyền, cài đặt đăng ký. Idempotent |
| `deploy/directus/verify.mjs` | Kiểm thử tầng 3 và ba giả định ở mục 9 của spec, bằng request thật |
| `deploy/directus/env.example` | Danh sách biến môi trường của `api`, không có giá trị bí mật |
| `deploy/directus/templates/password-reset.liquid` | Email đặt lại mật khẩu bằng tiếng Việt |
| `deploy/directus/extensions/poolcoachai-revoke-sessions/` | **Chỉ tạo nếu Task 2 thấy cần.** Hook xoá phiên cũ khi đổi mật khẩu |
| `docs/superpowers/logs/2026-09-23-directus-findings.md` | Hành vi thật của Directus mà Task 2 quan sát được |
| `lib/core/config.dart` | `apiBaseUrl`, `resetPasswordUrl()` |
| `lib/domain/auth.dart` | `AuthState` (`SignedOut`/`SignedIn`), `AuthFailure` |
| `lib/data/remote/directus_client.dart` | HTTP gọi Directus; lỗi thành `DirectusError` hoặc `DirectusUnreachable` |
| `lib/data/repositories/auth_repository.dart` | Interface `AuthRepository`, `SessionStore`, `StoredSession` |
| `lib/data/remote/directus_auth_repository.dart` | Cài đặt xác thực |
| `lib/data/repositories/drift_session_store.dart` | `SessionStore` trên bảng `AuthSessionRows` |
| `lib/data/sync/sync_service.dart` | Đẩy và kéo `drill_logs` |
| `lib/data/sync/account_actions.dart` | `pendingLogCount`, `signOutAndForget` |
| `lib/core/auth/auth_gate.dart` | `ChangeNotifier` cho `refreshListenable` của router |
| `lib/core/providers/auth_providers.dart` | Provider cho http, client, auth, trạng thái, user hiện tại, gate, sync |
| `lib/features/auth/presentation/*.dart` | Bốn màn tài khoản, khung chung, hàm kiểm dữ liệu nhập |
| `tool/e2e/cdp.mjs`, `tool/e2e/serve.mjs` (Task 9), `tool/e2e/accounts.mjs` (Task 10) | Điều khiển Chrome; server tĩnh có fallback; kịch bản hai máy |
| `test/support/fake_directus.dart`, `test/support/fake_auth.dart`, `test/support/in_memory_session_store.dart` | Đồ test dùng chung |

---

### Task 1: Dựng Directus trên `test-va` và script bootstrap

**Files:**
- Create: `deploy/directus/env.example`
- Create: `deploy/directus/templates/password-reset.liquid`
- Create: `deploy/directus/bootstrap.mjs`

**Interfaces:**
- Produces: API sống ở `https://poolcoachai-api.kjdybl.easypanel.host`; mailpit ở `https://poolcoachai-mail.kjdybl.easypanel.host` (có basic auth); collection `drill_logs`; role `Player`. Biến trong `.claude/settings.local.json` → `env`: `DIRECTUS_URL`, `DIRECTUS_ADMIN_EMAIL`, `DIRECTUS_ADMIN_PASSWORD`, `MAILPIT_URL`, `MAILPIT_USER`, `MAILPIT_PASSWORD`.

- [ ] **Step 1: Sinh bí mật**

Chạy lệnh dưới 5 lần, mỗi lần lấy một giá trị cho `KEY`, `SECRET`, `ADMIN_PASSWORD`, `DB_PASSWORD`, `MAILPIT_PASSWORD`:

```bash
node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
```

Ghi các giá trị vào khối `env` của `.claude/settings.local.json`. Tuyệt đối không đưa vào bất kỳ file nào được git theo dõi.

- [ ] **Step 2: Viết `deploy/directus/env.example`**

```bash
# Biến môi trường của service `api` (Directus) trong project test-va.
# Giá trị bí mật để trống ở đây — giá trị thật chỉ nằm trong Easypanel.
# Không dùng ký tự '#' trong giá trị: file .env coi đó là chú thích.
TZ=Asia/Ho_Chi_Minh
KEY=
SECRET=
ADMIN_EMAIL=admin@poolcoachai.local
ADMIN_PASSWORD=
PUBLIC_URL=https://poolcoachai-api.kjdybl.easypanel.host
HOST=0.0.0.0
PORT=8055

DB_CLIENT=pg
DB_HOST=test-va_db
DB_PORT=5432
DB_DATABASE=poolcoachai
DB_USER=postgres
DB_PASSWORD=

# Một instance duy nhất: cache bộ nhớ, không Redis.
CACHE_ENABLED=false
RATE_LIMITER_ENABLED=true
RATE_LIMITER_STORE=memory
RATE_LIMITER_POINTS=50
RATE_LIMITER_DURATION=1

# App gọi từ origin khác. Không dùng cookie nên không cần credentials.
CORS_ENABLED=true
CORS_ORIGIN=array:https://poolcoachai.kjdybl.easypanel.host,http://localhost:5555
CORS_CREDENTIALS=false

ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=30d
PASSWORD_RESET_URL_ALLOW_LIST=https://poolcoachai.kjdybl.easypanel.host/reset-password,http://localhost:5555/reset-password

# Mailpit giữ mọi thư. Đổi sang mail thật: sửa bốn biến SMTP rồi xoá service mailpit.
EMAIL_TRANSPORT=smtp
EMAIL_FROM=no-reply@poolcoachai.local
EMAIL_SMTP_HOST=test-va_mailpit
EMAIL_SMTP_PORT=1025
EMAIL_SMTP_SECURE=false
EMAIL_SMTP_IGNORE_TLS=true
EMAIL_SMTP_POOL=false

STORAGE_LOCATIONS=local
STORAGE_LOCAL_DRIVER=local
STORAGE_LOCAL_ROOT=./uploads
```

- [ ] **Step 3: Viết `deploy/directus/templates/password-reset.liquid`**

```liquid
<!doctype html>
<html lang="vi">
  <body style="margin:0;padding:24px;background:#10261c;color:#f1e9d6;font-family:Arial,sans-serif">
    <h2 style="color:#e0b04a">Đặt lại mật khẩu PoolCoachAI</h2>
    <p>Có người vừa yêu cầu đặt lại mật khẩu cho tài khoản <b>{{ email }}</b>.</p>
    <p>
      <a href="{{ url }}"
         style="display:inline-block;padding:12px 20px;background:#e0b04a;color:#10261c;text-decoration:none;border-radius:8px;font-weight:bold">
        Đặt mật khẩu mới
      </a>
    </p>
    <p>Nếu nút không bấm được, mở link này: <br>{{ url }}</p>
    <p>Nếu bạn không yêu cầu, hãy bỏ qua email này. Mật khẩu của bạn không đổi.</p>
  </body>
</html>
```

- [ ] **Step 4: Tạo `db`**

Gọi `mcp__easypanel__search_procedures` với query `"create postgres service"` để lấy đúng schema. Sau đó tạo service `db` trong `test-va`: image `postgres:17`, database `poolcoachai`, user `postgres`, mật khẩu `DB_PASSWORD`, **không** mở cổng ra ngoài (`exposedPort: 0`).

- [ ] **Step 5: Tạo `mailpit`**

Gọi `createAppService` với các trường sau:
- `projectName: "test-va"`, `serviceName: "mailpit"`
- `source: {type: "image", image: "axllent/mailpit:v1.31.1"}`
- `env`: `MP_MAX_MESSAGES=5000`, `MP_SMTP_AUTH_ACCEPT_ANY=1`, `MP_SMTP_AUTH_ALLOW_INSECURE=1`
- `domains: [{host: "poolcoachai-mail.kjdybl.easypanel.host", https: true, port: 8025, path: "/", internalProtocol: "http"}]`
- `basicAuth: [{username: "owner", password: MAILPIT_PASSWORD}]`
- `resources`: giới hạn 0.1 vCPU và 64 MB

Đơn vị của `resources` thì đọc trong schema trả về ở bước tìm kiếm. Tạo xong, gọi `inspectAppService` để xác nhận giới hạn đúng như ý.

- [ ] **Step 6: Tạo `api`**

Gọi `createAppService` với các trường sau:
- `serviceName: "api"`, `source: {type: "image", image: "directus/directus:12.3.1"}`
- `env`: nội dung `env.example`, điền giá trị thật từ Step 1
- `domains: [{host: "poolcoachai-api.kjdybl.easypanel.host", https: true, port: 8055, path: "/", internalProtocol: "http"}]`
- `mounts`:
  - `{type: "volume", name: "uploads", mountPath: "/directus/uploads"}`
  - `{type: "file", mountPath: "/directus/templates/password-reset.liquid", content: <nội dung file Step 3>}`
- `resources`: giới hạn 0.5 vCPU và 512 MB

- [ ] **Step 7: Chờ API sống**

```bash
for i in $(seq 1 30); do c=$(curl -s -o /dev/null -w '%{http_code}' https://poolcoachai-api.kjdybl.easypanel.host/server/ping); echo "$i $c"; [ "$c" = 200 ] && break; sleep 10; done
curl -s -o /dev/null -w 'mailpit không auth: %{http_code}\n' https://poolcoachai-mail.kjdybl.easypanel.host/
```

Expected: ping trả `200`. Mailpit không kèm auth phải trả `401`. Nếu mailpit trả `200` thì **dừng lại**: basic auth chưa được áp dụng.

- [ ] **Step 8: Viết `deploy/directus/bootstrap.mjs`**

```js
// Dựng cấu hình Directus cho PoolCoachAI. Chạy lại bao nhiêu lần cũng ra cùng một kết quả.
//
//   DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node deploy/directus/bootstrap.mjs
//
// Schema sống trong file này chứ không chỉ trên server: PoolOS mất toàn bộ
// cấu hình khi server bị xoá, vì nó chưa từng được ghi lại ở đâu khác.

const base = must('DIRECTUS_URL').replace(/\/$/, '');

function must(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Thiếu biến môi trường ${name}`);
  return value;
}

async function api(method, path, body, token) {
  const res = await fetch(base + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    const error = new Error(`${method} ${path} → ${res.status} ${text}`);
    error.status = res.status;
    throw error;
  }
  return text ? JSON.parse(text).data : null;
}

const { access_token: token } = await api('POST', '/auth/login', {
  email: must('DIRECTUS_ADMIN_EMAIL'),
  password: must('DIRECTUS_ADMIN_PASSWORD'),
});

// ─── 1. Collection drill_logs ───────────────────────────────────────────────
// Directus trả 403 (không phải 404) cho collection chưa có, để không lộ tên.
const hasCollection = await api('GET', '/collections/drill_logs', undefined, token).then(
  () => true,
  (e) => (e.status === 403 || e.status === 404 ? false : Promise.reject(e)),
);
if (!hasCollection) {
  await api('POST', '/collections', {
    collection: 'drill_logs',
    meta: { icon: 'sports_score', note: 'Buổi tập của người chơi PoolCoachAI' },
    schema: {},
    fields: [
      // id do app tạo (UUID v4): gửi trùng một buổi thì server từ chối, không nhân đôi.
      { field: 'id', type: 'uuid', schema: { is_primary_key: true, is_nullable: false } },
      { field: 'drill_id', type: 'string', schema: { is_nullable: false } },
      { field: 'date', type: 'timestamp', schema: { is_nullable: false } },
      { field: 'score', type: 'float', schema: { is_nullable: false } },
      { field: 'attempts', type: 'integer', schema: { is_nullable: true } },
      { field: 'notes', type: 'text', schema: { is_nullable: true } },
      {
        field: 'user_created',
        type: 'uuid',
        meta: { special: ['user-created'], readonly: true, hidden: true },
        schema: {},
      },
      {
        field: 'date_created',
        type: 'timestamp',
        meta: { special: ['date-created'], readonly: true, hidden: true },
        schema: {},
      },
    ],
  }, token);
  console.log('Tạo collection drill_logs');
}

const hasRelation = await api('GET', '/relations/drill_logs/user_created', undefined, token).then(
  () => true,
  (e) => (e.status === 403 || e.status === 404 ? false : Promise.reject(e)),
);
if (!hasRelation) {
  // Xoá người dùng thì xoá luôn buổi tập của họ.
  await api('POST', '/relations', {
    collection: 'drill_logs',
    field: 'user_created',
    related_collection: 'directus_users',
    schema: { on_delete: 'CASCADE' },
  }, token);
  console.log('Tạo quan hệ drill_logs.user_created → directus_users');
}

// ─── 2. Role Player và policy của nó ────────────────────────────────────────
async function findOrCreate(path, name, payload) {
  const found = await api('GET', `${path}?filter[name][_eq]=${encodeURIComponent(name)}`, undefined, token);
  if (found.length) return found[0];
  console.log(`Tạo ${path} ${name}`);
  return api('POST', path, payload, token);
}

const role = await findOrCreate('/roles', 'Player', {
  name: 'Player',
  icon: 'sports',
  description: 'Người chơi PoolCoachAI — chỉ thấy dữ liệu của chính mình',
});
const policy = await findOrCreate('/policies', 'Player', {
  name: 'Player',
  icon: 'sports',
  admin_access: false,
  app_access: false,
  description: 'Quyền của người chơi PoolCoachAI',
});

const links = await api(
  'GET',
  `/access?filter[role][_eq]=${role.id}&filter[policy][_eq]=${policy.id}`,
  undefined,
  token,
);
if (!links.length) await api('POST', '/access', { role: role.id, policy: policy.id }, token);

// Xoá hết quyền cũ rồi tạo lại: chạy lần hai vẫn ra đúng một bộ quyền.
const oldPermissions = await api('GET', `/permissions?filter[policy][_eq]=${policy.id}&limit=-1`, undefined, token);
if (oldPermissions.length) await api('DELETE', '/permissions', oldPermissions.map((p) => p.id), token);

const self = { id: { _eq: '$CURRENT_USER' } };
await api('POST', '/permissions', [
  {
    policy: policy.id,
    collection: 'drill_logs',
    action: 'create',
    fields: ['id', 'drill_id', 'date', 'score', 'attempts', 'notes'],
    permissions: {},
    validation: {},
  },
  {
    policy: policy.id,
    collection: 'drill_logs',
    action: 'read',
    fields: ['*'],
    permissions: { user_created: { _eq: '$CURRENT_USER' } },
  },
  {
    policy: policy.id,
    collection: 'directus_users',
    action: 'read',
    fields: ['id', 'first_name', 'email'],
    permissions: self,
  },
  {
    policy: policy.id,
    collection: 'directus_users',
    action: 'update',
    fields: ['first_name', 'email', 'password'],
    permissions: self,
  },
], token);

// ─── 3. Đăng ký công khai ───────────────────────────────────────────────────
await api('PATCH', '/settings', {
  project_name: 'PoolCoachAI',
  public_registration: true,
  public_registration_verify_email: false,
  public_registration_role: role.id,
  auth_password_policy: '/^.{8,}$/',
}, token);

console.log(`Xong. Role Player = ${role.id}, policy = ${policy.id}`);
```

- [ ] **Step 9: Chạy bootstrap hai lần**

Nạp biến môi trường từ `.claude/settings.local.json` vào shell, rồi chạy:

```bash
node deploy/directus/bootstrap.mjs && node deploy/directus/bootstrap.mjs
```

Expected:
- Lần 1 in các dòng "Tạo …" rồi "Xong".
- Lần 2 **không** in dòng "Tạo" nào, chỉ in "Xong" với đúng hai id như lần 1.
- Không lần nào có exception.

Nếu `PATCH /settings` báo trường `public_registration*` không tồn tại, **dừng lại** và báo chủ sản phẩm: giả định 1 ở mục 9 của spec đã sai.

- [ ] **Step 10: Commit**

```bash
git add deploy/directus/env.example deploy/directus/templates/password-reset.liquid deploy/directus/bootstrap.mjs
git commit -m "Stand up Directus for accounts, with its configuration as code

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Kiểm server bằng request thật, và ghi lại hành vi của Directus

**Files:**
- Create: `deploy/directus/verify.mjs`
- Create: `docs/superpowers/logs/2026-09-23-directus-findings.md`
- Create **chỉ khi Step 3 báo `FAIL phiên cũ còn sống`**: `deploy/directus/extensions/poolcoachai-revoke-sessions/package.json`, `deploy/directus/extensions/poolcoachai-revoke-sessions/index.js`

**Interfaces:**
- Consumes: server và các biến môi trường của Task 1.
- Produces: file findings ghi lại **mã lỗi thật** mà Task 4 và Task 7 ánh xạ: đăng ký email trùng, token đặt lại sai, id trùng. Nếu mã thật khác với giả định trong kế hoạch (`RECORD_NOT_UNIQUE`, 401/403 cho token sai), phải sửa các hằng tương ứng ở Task 4 và Task 7 **trước khi** làm hai task đó.

- [ ] **Step 1: Viết `deploy/directus/verify.mjs`**

```js
// Tầng 3 của kiểm thử: quyền và luồng tài khoản, kiểm bằng request thật.
// Cũng ghi lại hành vi Directus mà app phụ thuộc vào (mục 9 của spec).
//
//   DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=…
//   MAILPIT_URL=… MAILPIT_USER=… MAILPIT_PASSWORD=… node deploy/directus/verify.mjs

import { randomUUID, randomBytes } from 'node:crypto';

const env = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
const base = env('DIRECTUS_URL').replace(/\/$/, '');
const mail = env('MAILPIT_URL').replace(/\/$/, '');
const mailAuth = 'Basic ' + Buffer.from(`${env('MAILPIT_USER')}:${env('MAILPIT_PASSWORD')}`).toString('base64');
const RESET_URL = 'https://poolcoachai.kjdybl.easypanel.host/reset-password';

let failures = 0;
const ok = (msg) => console.log(`OK   ${msg}`);
const fail = (msg) => { failures++; console.log(`FAIL ${msg}`); };
const note = (msg) => console.log(`NOTE ${msg}`);

async function call(method, path, body, token) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  return { status: res.status, data: json?.data, code: json?.errors?.[0]?.extensions?.code };
}

const login = async (email, password) =>
  (await call('POST', '/auth/login', { email, password, mode: 'json' })).data;

const admin = await login(env('DIRECTUS_ADMIN_EMAIL'), env('DIRECTUS_ADMIN_PASSWORD'));
const tag = randomBytes(4).toString('hex');
const users = ['a', 'b'].map((n) => ({ email: `verify-${tag}-${n}@poolcoachai.local`, password: randomBytes(8).toString('hex') }));

try {
  // ─── Giả định 1: đăng ký công khai gán role Player ──────────────────────
  for (const u of users) {
    const r = await call('POST', '/users/register', { email: u.email, password: u.password, first_name: 'Verify' });
    r.status === 204 || r.status === 200 ? ok(`đăng ký ${u.email} → ${r.status}`) : fail(`đăng ký → ${r.status} ${r.code}`);
  }
  const [a, b] = await Promise.all(users.map((u) => login(u.email, u.password)));
  a?.access_token ? ok('đăng nhập ngay sau đăng ký, không cần xác minh') : fail('không đăng nhập được sau đăng ký');
  // Player không được đọc role của chính mình, nên hỏi bằng token admin.
  const roleOf = async (email) => (await call('GET', `/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=role.name`, undefined, admin.access_token)).data?.[0]?.role?.name;
  const roleA = await roleOf(users[0].email);
  roleA === 'Player' ? ok('user mới có role Player') : fail(`role = ${roleA}`);

  const dup = await call('POST', '/users/register', { email: users[0].email, password: 'khac-hoan-toan-1' });
  note(`đăng ký email đã có → status ${dup.status}, code ${dup.code ?? '(không có)'}`);

  const short = await call('POST', '/users/register', { email: `verify-${tag}-c@poolcoachai.local`, password: '1234567' });
  short.status >= 400 ? ok(`mật khẩu 7 ký tự bị từ chối → ${short.status} ${short.code}`) : fail('mật khẩu 7 ký tự vẫn được nhận');

  // ─── Quyền trên drill_logs ─────────────────────────────────────────────
  const logId = randomUUID();
  const log = { id: logId, drill_id: 'd1', date: '2026-09-23T03:00:00.000Z', score: 7, attempts: 10, notes: null };
  const created = await call('POST', '/items/drill_logs', log, a.access_token);
  created.status === 200 ? ok('A tạo được buổi tập') : fail(`A tạo buổi tập → ${created.status} ${created.code}`);

  const again = await call('POST', '/items/drill_logs', log, a.access_token);
  note(`gửi lại cùng id → status ${again.status}, code ${again.code}`);
  again.status >= 400 ? ok('gửi trùng id không tạo bản ghi thứ hai') : fail('gửi trùng id tạo được bản ghi thứ hai');

  const aList = await call('GET', '/items/drill_logs?fields=id,user_created', undefined, a.access_token);
  aList.data?.length === 1 ? ok('A đọc được đúng một buổi của mình') : fail(`A đọc được ${aList.data?.length} buổi`);
  const bList = await call('GET', '/items/drill_logs', undefined, b.access_token);
  bList.data?.length === 0 ? ok('B không thấy buổi của A') : fail(`B thấy ${bList.data?.length} buổi`);
  const anon = await call('GET', '/items/drill_logs');
  anon.status === 403 || (anon.data ?? []).length === 0 ? ok(`không token → ${anon.status}`) : fail('không token vẫn đọc được');

  const patch = await call('PATCH', `/items/drill_logs/${logId}`, { score: 10 }, a.access_token);
  patch.status === 403 ? ok('A không sửa được buổi tập') : fail(`A sửa buổi tập → ${patch.status}`);
  const del = await call('DELETE', `/items/drill_logs/${logId}`, undefined, a.access_token);
  del.status === 403 ? ok('A không xoá được buổi tập') : fail(`A xoá buổi tập → ${del.status}`);

  const adminRole = (await call('GET', '/roles?filter[name][_eq]=Administrator', undefined, admin.access_token)).data?.[0]?.id;
  await call('PATCH', '/users/me', { role: adminRole }, a.access_token);
  const roleAfter = await roleOf(users[0].email);
  roleAfter === 'Player' ? ok('A không tự nâng role được') : fail(`A đổi role thành ${roleAfter}`);

  // ─── Giả định 2 và 3: đặt lại mật khẩu ─────────────────────────────────
  const req = await call('POST', '/auth/password/request', { email: users[0].email, reset_url: RESET_URL });
  req.status === 204 || req.status === 200 ? ok('yêu cầu đặt lại mật khẩu được nhận') : fail(`yêu cầu đặt lại → ${req.status} ${req.code}`);
  const unknown = await call('POST', '/auth/password/request', { email: `khong-co-${tag}@poolcoachai.local`, reset_url: RESET_URL });
  note(`yêu cầu đặt lại cho email không tồn tại → ${unknown.status}`);

  let link = null;
  for (let i = 0; i < 20 && !link; i++) {
    const found = await (await fetch(`${mail}/api/v1/search?query=${encodeURIComponent(`to:${users[0].email}`)}`, { headers: { Authorization: mailAuth } })).json();
    const id = found.messages?.[0]?.ID;
    if (id) {
      const msg = await (await fetch(`${mail}/api/v1/message/${id}`, { headers: { Authorization: mailAuth } })).json();
      link = (msg.HTML + msg.Text).match(/https:\/\/poolcoachai\.kjdybl\.easypanel\.host\/reset-password\?token=[^\s"'<&]+/)?.[0] ?? null;
      note(`tiêu đề thư: ${msg.Subject}`);
      msg.HTML.includes('Đặt lại mật khẩu PoolCoachAI') ? ok('thư dùng template tiếng Việt') : fail('thư không dùng template tiếng Việt');
    } else {
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
  link ? ok(`link đúng dạng đường dẫn: ${link.slice(0, 70)}…`) : fail('không tìm thấy link …/reset-password?token= trong thư');

  if (link) {
    const resetToken = new URL(link).searchParams.get('token');
    const bad = await call('POST', '/auth/password/reset', { token: resetToken + 'x', password: 'mat-khau-moi-123' });
    note(`token đặt lại sai → status ${bad.status}, code ${bad.code}`);

    const oldRefresh = a.refresh_token;
    const reset = await call('POST', '/auth/password/reset', { token: resetToken, password: 'mat-khau-moi-123' });
    reset.status === 204 || reset.status === 200 ? ok('đặt lại mật khẩu thành công') : fail(`đặt lại → ${reset.status} ${reset.code}`);

    const reuse = await call('POST', '/auth/password/reset', { token: resetToken, password: 'mat-khau-khac-456' });
    note(`dùng lại link đặt lại → status ${reuse.status}, code ${reuse.code}`);

    const refresh = await call('POST', '/auth/refresh', { refresh_token: oldRefresh, mode: 'json' });
    note(`làm mới bằng refresh token cũ → status ${refresh.status}, code ${refresh.code}`);
    refresh.status === 401 || refresh.status === 403 ? ok('đổi mật khẩu làm phiên cũ mất hiệu lực') : fail('phiên cũ còn sống sau khi đổi mật khẩu');

    const relogin = await login(users[0].email, 'mat-khau-moi-123');
    relogin?.access_token ? ok('đăng nhập bằng mật khẩu mới') : fail('không đăng nhập được bằng mật khẩu mới');
  }
} finally {
  // Dọn user thử; CASCADE xoá luôn buổi tập của họ.
  const ids = (await call('GET', `/users?filter[email][_starts_with]=verify-${tag}&fields=id`, undefined, admin.access_token)).data.map((u) => u.id);
  if (ids.length) await call('DELETE', '/users', ids, admin.access_token);
}

console.log(failures ? `\n${failures} kiểm tra hỏng` : '\nTất cả kiểm tra đều qua');
process.exit(failures ? 1 : 0);
```

- [ ] **Step 2: Chạy**

```bash
node deploy/directus/verify.mjs | tee "$TMP/directus-verify.log"
```

Expected: mọi dòng đều là `OK` hoặc `NOTE`, dòng cuối là `Tất cả kiểm tra đều qua`.

- [ ] **Step 3: Chỉ làm nếu thấy `FAIL phiên cũ còn sống sau khi đổi mật khẩu`**

Tạo `deploy/directus/extensions/poolcoachai-revoke-sessions/package.json`:

```json
{
  "name": "poolcoachai-revoke-sessions",
  "version": "1.0.0",
  "type": "module",
  "directus:extension": {
    "type": "hook",
    "path": "index.js",
    "source": "index.js",
    "host": "^12.0.0"
  }
}
```

Tạo `deploy/directus/extensions/poolcoachai-revoke-sessions/index.js`:

```js
// Đổi mật khẩu thì mọi phiên cũ phải chết — kể cả phiên trên chiếc máy bị mất,
// vốn là lý do người ta đổi mật khẩu.
export default ({ action }, { database }) => {
  action('users.update', async ({ keys, payload }) => {
    if (!payload || !('password' in payload)) return;
    await database('directus_sessions').whereIn('user', keys).delete();
  });
};
```

Gắn hai file vào service `api` bằng file mount, tại `/directus/extensions/poolcoachai-revoke-sessions/package.json` và `…/index.js`. Deploy lại `api`, rồi chạy lại Step 2. Nếu vẫn `FAIL`, **dừng lại** và báo chủ sản phẩm: để phiên cũ còn sống sau khi đổi mật khẩu là lỗ hổng, không được bỏ qua.

- [ ] **Step 4: Ghi `docs/superpowers/logs/2026-09-23-directus-findings.md`**

Chép mọi dòng `NOTE` từ `$TMP/directus-verify.log` vào file, mỗi dòng kèm một câu nói app dựa vào nó ở đâu. File phải trả lời được ba câu:

- Đăng ký email đã có thì server trả gì? (Task 4 ánh xạ thành `AuthFailure.emailTaken`.)
- Token đặt lại sai hoặc đã dùng thì status và code là gì? (Task 4 ánh xạ thành `AuthFailure.resetLinkInvalid`.)
- Gửi lại cùng id buổi tập thì code là gì? (Task 7 coi là đã đồng bộ.)

Ghi thêm việc Step 3 có cần làm hay không.

- [ ] **Step 5: Commit**

```bash
git add deploy/directus/verify.mjs docs/superpowers/logs/2026-09-23-directus-findings.md
git add deploy/directus/extensions 2>/dev/null || true
git commit -m "Check Directus permissions and account flows against the live server

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Kiểu xác thực và `DirectusClient`

**Files:**
- Modify: `pubspec.yaml` (thêm `http`, `uuid`)
- Create: `lib/domain/auth.dart`
- Create: `lib/data/remote/directus_client.dart`
- Create: `lib/data/repositories/auth_repository.dart`
- Create: `test/support/fake_directus.dart`
- Create: `test/support/in_memory_session_store.dart`
- Test: `test/data/remote/directus_client_test.dart`

**Interfaces:**
- Produces:
  - `sealed class AuthState`, `SignedOut({bool expired = false})`, `SignedIn({required String userId, required String displayName})`
  - `enum AuthFailure implements Exception { wrongCredentials, emailTaken, weakPassword, network, resetLinkInvalid, sessionExpired, unknown }`
  - `DirectusClient({required http.Client client, required Uri baseUrl})` với `get(path, {token, query}) → Future<Object?>` và `post(path, {body, token}) → Future<Object?>`. Cả hai trả về trường `data` của phản hồi.
  - `DirectusError(int status, String? code)`, `DirectusUnreachable(Object cause)`
  - `AuthRepository`, `SessionStore`, `StoredSession` (code bên dưới)
  - Test: `FakeDirectus`, `InMemorySessionStore`

- [ ] **Step 1: Thêm dependency**

Trong `pubspec.yaml`, thêm vào `dependencies:` ngay dưới `path: ^1.9.1`:

```yaml

  # Gọi REST của Directus. Không có SDK Dart chính thức — xem spec mục 2.1.
  http: ^1.6.0
  # Id buổi tập: phải duy nhất giữa mọi người dùng trên server chung.
  uuid: ^4.5.1
```

Run: `$F pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Viết `lib/domain/auth.dart`**

```dart
/// Trạng thái đăng nhập mà router và màn hình đọc.
sealed class AuthState {
  const AuthState();
}

/// Chưa đăng nhập.
///
/// [expired] là true khi server từ chối phiên (tự động đăng xuất). Màn
/// Đăng nhập dựa vào đó để nói lý do, thay vì để người chơi tưởng app
/// tự văng ra.
final class SignedOut extends AuthState {
  const SignedOut({this.expired = false});

  final bool expired;

  @override
  bool operator ==(Object other) =>
      other is SignedOut && other.expired == expired;

  @override
  int get hashCode => expired.hashCode;
}

/// Đang đăng nhập bằng [userId].
final class SignedIn extends AuthState {
  const SignedIn({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is SignedIn &&
      other.userId == userId &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(userId, displayName);
}

/// Lỗi mà màn hình tài khoản biết cách nói bằng tiếng Việt.
///
/// Không bao giờ hiện nguyên văn lỗi server: mỗi loại ở đây có đúng một
/// câu trong `Vi.authFailure`.
enum AuthFailure implements Exception {
  wrongCredentials,
  emailTaken,
  weakPassword,
  network,
  resetLinkInvalid,
  sessionExpired,

  /// Server trả lỗi ngoài dự kiến (5xx, cấu hình sai).
  unknown,
}
```

- [ ] **Step 3: Viết `lib/data/repositories/auth_repository.dart`**

```dart
import 'package:poolcoachai/domain/auth.dart';

/// Xác thực người chơi — màn hình chỉ biết interface này, không biết Directus.
abstract interface class AuthRepository {
  /// Trạng thái hiện tại, đọc đồng bộ để router quyết định ngay khung đầu.
  AuthState get current;

  /// Chỉ phát khi trạng thái **đổi**; giá trị ban đầu đọc ở [current].
  Stream<AuthState> watchSession();

  /// Đọc phiên đã lưu trên máy. Không cần mạng: mở app offline vẫn vào thẳng.
  Future<void> restore();

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  /// Chỉ dùng khi người chơi **bấm** Đăng xuất. Tự động đăng xuất đi
  /// đường khác và không bao giờ gọi hàm này — xem spec mục 5.4.
  Future<void> signOut();

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({required String token, required String password});

  /// Access token còn hạn, tự làm mới khi còn dưới một phút.
  ///
  /// Ném [AuthFailure.network] khi mất mạng (vẫn giữ đăng nhập) và
  /// [AuthFailure.sessionExpired] khi server từ chối phiên.
  Future<String> accessToken();
}

/// Phiên đăng nhập đã lưu trên máy.
class StoredSession {
  const StoredSession({
    required this.userId,
    required this.displayName,
    required this.refreshToken,
  });

  final String userId;
  final String displayName;
  final String refreshToken;
}

/// Nơi giữ [StoredSession] — tách khỏi Drift để test xác thực không cần DB.
abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}
```

- [ ] **Step 4: Viết đồ test dùng chung**

`test/support/in_memory_session_store.dart`:

```dart
import 'package:poolcoachai/data/repositories/auth_repository.dart';

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}
```

`test/support/fake_directus.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef DirectusHandler = FutureOr<http.Response> Function(http.Request req);

/// Directus giả: đăng ký handler theo "METHOD /đường-dẫn".
///
/// Mọi request đều được ghi lại vào [requests] để test đọc lại xem app
/// đã gửi gì — nhất là để chứng minh nó **không** gửi dữ liệu của người khác.
class FakeDirectus {
  final routes = <String, DirectusHandler>{};
  final requests = <http.Request>[];

  /// Bật lên thì mọi request ném như khi mất mạng.
  bool offline = false;

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    if (offline) throw http.ClientException('offline', req.url);
    final handler = routes['${req.method} ${req.url.path}'];
    if (handler == null) return error(404, 'ROUTE_NOT_FOUND');
    return handler(req);
  });

  static final baseUrl = Uri.parse('https://api.test');

  List<http.Request> sent(String method, String path) => requests
      .where((r) => r.method == method && r.url.path == path)
      .toList();

  static Map<String, Object?> body(http.Request req) =>
      jsonDecode(req.body) as Map<String, Object?>;

  static http.Response ok(Object? data) => http.Response.bytes(
        utf8.encode(jsonEncode({'data': data})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static http.Response noContent() => http.Response('', 204);

  static http.Response error(int status, String code) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'errors': [
            {'message': code, 'extensions': {'code': code}},
          ],
        })),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// Đăng nhập nào cũng thành công, trả [refresh] làm refresh token.
  void acceptLogin({
    String userId = 'u1',
    String name = 'An',
    String refresh = 'r1',
    int expiresMs = 900000,
  }) {
    routes['POST /auth/login'] = (_) => ok({
          'access_token': 'access-$refresh',
          'expires': expiresMs,
          'refresh_token': refresh,
        });
    routes['GET /users/me'] = (_) => ok({'id': userId, 'first_name': name});
  }
}
```

- [ ] **Step 5: Viết test thất bại cho `DirectusClient`**

`test/data/remote/directus_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/data/remote/directus_client.dart';

import '../../support/fake_directus.dart';

void main() {
  late FakeDirectus server;
  late DirectusClient api;

  setUp(() {
    server = FakeDirectus();
    api = DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl);
  });

  test('trả trường data của phản hồi, kèm Bearer token', () async {
    server.routes['GET /users/me'] = (_) => FakeDirectus.ok({'id': 'u1'});

    final data = await api.get('/users/me', token: 'abc');

    expect(data, {'id': 'u1'});
    expect(server.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('gửi body JSON và giữ nguyên chữ tiếng Việt', () async {
    server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();

    final data = await api.post('/users/register', body: {'first_name': 'Nguyễn Ân'});

    expect(data, isNull);
    expect(FakeDirectus.body(server.requests.single)['first_name'], 'Nguyễn Ân');
  });

  test('lỗi server thành DirectusError mang mã của Directus', () async {
    server.routes['POST /auth/login'] =
        (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

    expect(
      () => api.post('/auth/login', body: {}),
      throwsA(isA<DirectusError>()
          .having((e) => e.status, 'status', 401)
          .having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
  });

  test('không tới được server thành DirectusUnreachable', () async {
    server.offline = true;

    expect(() => api.get('/users/me'), throwsA(isA<DirectusUnreachable>()));
  });

  test('đọc được tham số query', () async {
    server.routes['GET /items/drill_logs'] = (req) =>
        FakeDirectus.ok([req.url.queryParameters['limit']]);

    expect(await api.get('/items/drill_logs', query: {'limit': '-1'}), ['-1']);
  });

  test('phản hồi không phải JSON thì vẫn ra DirectusError, không nổ', () async {
    server.routes['GET /x'] = (_) => http.Response('<html>502</html>', 502);

    expect(
      () => api.get('/x'),
      throwsA(isA<DirectusError>().having((e) => e.code, 'code', isNull)),
    );
  });
}
```

- [ ] **Step 6: Chạy để thấy test hỏng**

Run: `$F test test/data/remote/directus_client_test.dart`
Expected: FAIL vì `directus_client.dart` chưa tồn tại.

- [ ] **Step 7: Viết `lib/data/remote/directus_client.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Server trả lỗi. [code] là `errors[0].extensions.code` của Directus.
class DirectusError implements Exception {
  const DirectusError(this.status, this.code);

  final int status;
  final String? code;

  @override
  String toString() => 'DirectusError($status, $code)';
}

/// Không tới được server: mất mạng, DNS, CORS, hết giờ.
///
/// Tách khỏi [DirectusError] vì hai loại dẫn tới hai hành vi ngược nhau:
/// mất mạng thì giữ đăng nhập và thử lại sau, còn server từ chối thì
/// mới là lúc đăng xuất.
class DirectusUnreachable implements Exception {
  const DirectusUnreachable(this.cause);

  final Object cause;

  @override
  String toString() => 'DirectusUnreachable($cause)';
}

/// Lớp HTTP mỏng trên REST của Directus — trả thẳng trường `data`.
class DirectusClient {
  DirectusClient({
    required http.Client client,
    required Uri baseUrl,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client,
        _baseUrl = baseUrl,
        _timeout = timeout;

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  Future<Object?> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) =>
      _send('GET', path, token: token, query: query);

  Future<Object?> post(String path, {Object? body, String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? query,
  }) async {
    final request = http.Request(
      method,
      _baseUrl.replace(path: path, queryParameters: query),
    );
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      ).timeout(_timeout);
    } on http.ClientException catch (e) {
      throw DirectusUnreachable(e);
    } on TimeoutException catch (e) {
      throw DirectusUnreachable(e);
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return null;
      return (jsonDecode(text) as Map<String, Object?>)['data'];
    }
    throw DirectusError(response.statusCode, _errorCode(text));
  }

  static String? _errorCode(String text) {
    try {
      final errors = (jsonDecode(text) as Map<String, Object?>)['errors'];
      final first = (errors! as List<Object?>).first! as Map<String, Object?>;
      return (first['extensions']! as Map<String, Object?>)['code'] as String?;
    } on Object {
      return null;
    }
  }
}
```

- [ ] **Step 8: Chạy để thấy test xanh**

Run: `$F test test/data/remote/directus_client_test.dart`
Expected: `All tests passed!` (6 test)

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/domain/auth.dart lib/data/repositories/auth_repository.dart lib/data/remote/directus_client.dart test/support/fake_directus.dart test/support/in_memory_session_store.dart test/data/remote/directus_client_test.dart
git commit -m "Add the auth types and a thin Directus client

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `DirectusAuthRepository`

**Files:**
- Create: `lib/data/remote/directus_auth_repository.dart`
- Test: `test/data/remote/directus_auth_repository_test.dart`

**Interfaces:**
- Consumes: `DirectusClient`, `AuthRepository`, `SessionStore`, `StoredSession`, `AuthState`, `AuthFailure` (Task 3). Mã lỗi thật ở `docs/superpowers/logs/2026-09-23-directus-findings.md` (Task 2).
- Produces: `DirectusAuthRepository({required DirectusClient api, required SessionStore sessions, required Uri resetUrl, required DateTime Function() now})`

Nếu findings ở Task 2 cho thấy mã lỗi thật khác với hằng dưới đây (`RECORD_NOT_UNIQUE`; `401`/`403` cho token đặt lại sai), **sửa hằng và test theo findings** rồi mới làm tiếp.

- [ ] **Step 1: Viết test thất bại**

`test/data/remote/directus_auth_repository_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_directus.dart';
import '../../support/in_memory_session_store.dart';

void main() {
  late FakeDirectus server;
  late InMemorySessionStore store;
  late DateTime now;
  late DirectusAuthRepository auth;

  final resetUrl = Uri.parse('https://app.test/reset-password');

  DirectusAuthRepository build() => DirectusAuthRepository(
        api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
        sessions: store,
        resetUrl: resetUrl,
        now: () => now,
      );

  setUp(() {
    server = FakeDirectus();
    store = InMemorySessionStore();
    now = DateTime(2026, 9, 23, 10);
    auth = build();
  });

  group('đăng nhập', () {
    test('thành công thì lưu phiên và báo SignedIn', () async {
      server.acceptLogin(userId: 'u1', name: 'An', refresh: 'r1');
      final changes = <AuthState>[];
      auth.watchSession().listen(changes.add);

      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      await pumpEventQueue();

      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));
      expect(changes, [const SignedIn(userId: 'u1', displayName: 'An')]);
      expect(store.session?.refreshToken, 'r1');
      expect(FakeDirectus.body(server.sent('POST', '/auth/login').single)['mode'], 'json');
    });

    test('email được cắt khoảng trắng và viết thường', () async {
      server.acceptLogin();

      await auth.signIn(email: '  An@Example.COM ', password: 'matkhau123');

      expect(
        FakeDirectus.body(server.sent('POST', '/auth/login').single)['email'],
        'an@example.com',
      );
    });

    test('sai mật khẩu thì wrongCredentials, không lưu gì', () async {
      server.routes['POST /auth/login'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(
        auth.signIn(email: 'an@example.com', password: 'sai'),
        throwsA(AuthFailure.wrongCredentials),
      );
      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });

    test('mất mạng thì network', () async {
      server.offline = true;

      await expectLater(
        auth.signIn(email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.network),
      );
    });
  });

  group('đăng ký', () {
    test('thành công thì đăng nhập luôn, tên được cắt khoảng trắng', () async {
      server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();
      server.acceptLogin();

      await auth.register(
        displayName: '  An  ',
        email: 'An@Example.com',
        password: 'matkhau123',
      );

      final body = FakeDirectus.body(server.sent('POST', '/users/register').single);
      expect(body['first_name'], 'An');
      expect(body['email'], 'an@example.com');
      expect(auth.current, isA<SignedIn>());
    });

    test('server im lặng về email trùng nhưng đăng nhập hỏng thì emailTaken',
        () async {
      server.routes['POST /users/register'] = (_) => FakeDirectus.noContent();
      server.routes['POST /auth/login'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.emailTaken),
      );
    });

    test('server báo email trùng thì emailTaken', () async {
      server.routes['POST /users/register'] =
          (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');

      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: 'matkhau123'),
        throwsA(AuthFailure.emailTaken),
      );
    });

    test('mật khẩu dưới 8 ký tự bị chặn trước khi gửi', () async {
      await expectLater(
        auth.register(displayName: 'An', email: 'an@example.com', password: '1234567'),
        throwsA(AuthFailure.weakPassword),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('phiên', () {
    Future<void> signedIn() async {
      server.acceptLogin(refresh: 'r1', expiresMs: 15 * 60 * 1000);
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.requests.clear();
    }

    test('token còn hạn thì không làm mới', () async {
      await signedIn();

      expect(await auth.accessToken(), 'access-r1');
      expect(server.requests, isEmpty);
    });

    test('token sắp hết hạn thì làm mới và lưu refresh token mới', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 14, seconds: 30));
      server.routes['POST /auth/refresh'] = (req) {
        expect(FakeDirectus.body(req)['refresh_token'], 'r1');
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      expect(await auth.accessToken(), 'access-r2');
      expect(store.session?.refreshToken, 'r2');
    });

    test('hai lời gọi cùng lúc chỉ làm mới một lần', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      final gate = Completer<void>();
      server.routes['POST /auth/refresh'] = (_) async {
        await gate.future;
        return FakeDirectus.ok({'access_token': 'access-r2', 'expires': 900000, 'refresh_token': 'r2'});
      };

      final a = auth.accessToken();
      final b = auth.accessToken();
      gate.complete();

      expect(await Future.wait([a, b]), ['access-r2', 'access-r2']);
      expect(server.sent('POST', '/auth/refresh'), hasLength(1));
    });

    test('server từ chối phiên thì tự đăng xuất, kèm expired', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      server.routes['POST /auth/refresh'] =
          (_) => FakeDirectus.error(401, 'INVALID_CREDENTIALS');

      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
      expect(auth.current, const SignedOut(expired: true));
      expect(store.session, isNull);
    });

    test('mất mạng lúc làm mới thì vẫn đăng nhập, phiên còn nguyên', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      server.offline = true;

      await expectLater(auth.accessToken(), throwsA(AuthFailure.network));
      expect(auth.current, isA<SignedIn>());
      expect(store.session?.refreshToken, 'r1');
    });

    test('401 nhưng máy đã có token mới hơn thì thử lại bằng token đó', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 20));
      // Tab khác vừa xoay token: r1 đã chết, r2 là token hiện hành trên máy.
      server.routes['POST /auth/refresh'] = (req) {
        final used = FakeDirectus.body(req)['refresh_token'];
        if (used == 'r1') {
          store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2');
          return FakeDirectus.error(401, 'INVALID_CREDENTIALS');
        }
        return FakeDirectus.ok({'access_token': 'access-r3', 'expires': 900000, 'refresh_token': 'r3'});
      };

      expect(await auth.accessToken(), 'access-r3');
      expect(auth.current, isA<SignedIn>());
      expect(store.session?.refreshToken, 'r3');
    });

    test('khôi phục phiên không cần mạng', () async {
      store.session = const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1');
      server.offline = true;

      await auth.restore();

      expect(auth.current, const SignedIn(userId: 'u1', displayName: 'An'));
      expect(server.requests, isEmpty);
    });

    test('chưa đăng nhập mà xin token thì sessionExpired', () async {
      await expectLater(auth.accessToken(), throwsA(AuthFailure.sessionExpired));
    });
  });

  group('đăng xuất do người chơi bấm', () {
    test('báo server, xoá phiên, không kèm expired', () async {
      server.acceptLogin(refresh: 'r1');
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.routes['POST /auth/logout'] = (_) => FakeDirectus.noContent();

      await auth.signOut();

      expect(FakeDirectus.body(server.sent('POST', '/auth/logout').single)['refresh_token'], 'r1');
      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });

    test('mất mạng vẫn đăng xuất được trên máy', () async {
      server.acceptLogin();
      await auth.signIn(email: 'an@example.com', password: 'matkhau123');
      server.offline = true;

      await auth.signOut();

      expect(auth.current, const SignedOut());
      expect(store.session, isNull);
    });
  });

  group('quên và đặt lại mật khẩu', () {
    test('gửi email đã chuẩn hoá kèm reset_url', () async {
      server.routes['POST /auth/password/request'] = (_) => FakeDirectus.noContent();

      await auth.requestPasswordReset(' An@Example.com ');

      final body = FakeDirectus.body(server.sent('POST', '/auth/password/request').single);
      expect(body, {'email': 'an@example.com', 'reset_url': 'https://app.test/reset-password'});
    });

    test('mất mạng thì network', () async {
      server.offline = true;

      await expectLater(auth.requestPasswordReset('an@example.com'), throwsA(AuthFailure.network));
    });

    test('link hết hạn hoặc đã dùng thì resetLinkInvalid', () async {
      for (final status in [401, 403]) {
        server.routes['POST /auth/password/reset'] =
            (_) => FakeDirectus.error(status, 'INVALID_TOKEN');

        await expectLater(
          auth.resetPassword(token: 't', password: 'matkhau123'),
          throwsA(AuthFailure.resetLinkInvalid),
        );
      }
    });

    test('mật khẩu mới dưới 8 ký tự bị chặn trước khi gửi', () async {
      await expectLater(
        auth.resetPassword(token: 't', password: 'ngan'),
        throwsA(AuthFailure.weakPassword),
      );
      expect(server.requests, isEmpty);
    });

    test('đặt lại thành công không tự đăng nhập', () async {
      server.routes['POST /auth/password/reset'] = (_) => FakeDirectus.noContent();

      await auth.resetPassword(token: 't', password: 'matkhau123');

      expect(auth.current, const SignedOut());
    });
  });
}
```

- [ ] **Step 2: Chạy để thấy test hỏng**

Run: `$F test test/data/remote/directus_auth_repository_test.dart`
Expected: FAIL vì `directus_auth_repository.dart` chưa tồn tại.

- [ ] **Step 3: Viết `lib/data/remote/directus_auth_repository.dart`**

```dart
import 'dart:async';

import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Xác thực qua Directus: refresh token trên máy, access token trong bộ nhớ.
class DirectusAuthRepository implements AuthRepository {
  DirectusAuthRepository({
    required DirectusClient api,
    required SessionStore sessions,
    required Uri resetUrl,
    required DateTime Function() now,
  })  : _api = api,
        _sessions = sessions,
        _resetUrl = resetUrl,
        _now = now;

  final DirectusClient _api;
  final SessionStore _sessions;
  final Uri _resetUrl;
  final DateTime Function() _now;

  static const _minPasswordLength = 8;
  static const _refreshMargin = Duration(minutes: 1);

  final _changes = StreamController<AuthState>.broadcast();
  AuthState _state = const SignedOut();
  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<String>? _refreshing;

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watchSession() => _changes.stream;

  void _emit(AuthState state) {
    if (state == _state) return;
    _state = state;
    _changes.add(state);
  }

  static String _normalize(String email) => email.trim().toLowerCase();

  @override
  Future<void> restore() async {
    final saved = await _sessions.read();
    if (saved != null) {
      _emit(SignedIn(userId: saved.userId, displayName: saved.displayName));
    }
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (password.length < _minPasswordLength) throw AuthFailure.weakPassword;
    final normalized = _normalize(email);
    try {
      await _api.post('/users/register', body: {
        'email': normalized,
        'password': password,
        'first_name': displayName.trim(),
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw switch (e.code) {
        'RECORD_NOT_UNIQUE' => AuthFailure.emailTaken,
        'FAILED_VALIDATION' => AuthFailure.weakPassword,
        _ => AuthFailure.unknown,
      };
    }
    try {
      await signIn(email: normalized, password: password);
    } on AuthFailure catch (f) {
      // Directus có thể không báo email trùng khi đăng ký (chống dò
      // email). Đăng ký "thành công" mà đăng nhập hỏng nghĩa là email
      // đã có chủ với mật khẩu khác.
      throw f == AuthFailure.wrongCredentials ? AuthFailure.emailTaken : f;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final Map<String, Object?> tokens;
    try {
      tokens = await _api.post('/auth/login', body: {
        'email': _normalize(email),
        'password': password,
        'mode': 'json',
      }) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw e.status == 401 ? AuthFailure.wrongCredentials : AuthFailure.unknown;
    }
    _takeTokens(tokens);

    final Map<String, Object?> me;
    try {
      me = await _api.get(
        '/users/me',
        token: _accessToken,
        query: {'fields': 'id,first_name'},
      ) as Map<String, Object?>;
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError {
      throw AuthFailure.unknown;
    }

    final session = StoredSession(
      userId: me['id']! as String,
      displayName: (me['first_name'] as String?) ?? '',
      refreshToken: tokens['refresh_token']! as String,
    );
    await _sessions.write(session);
    _emit(SignedIn(userId: session.userId, displayName: session.displayName));
  }

  void _takeTokens(Map<String, Object?> tokens) {
    _accessToken = tokens['access_token']! as String;
    _accessExpiresAt = _now().add(
      Duration(milliseconds: (tokens['expires']! as num).toInt()),
    );
  }

  @override
  Future<String> accessToken() {
    if (_state is! SignedIn) return Future.error(AuthFailure.sessionExpired);
    final token = _accessToken;
    final expiresAt = _accessExpiresAt;
    if (token != null &&
        expiresAt != null &&
        expiresAt.difference(_now()) > _refreshMargin) {
      return Future.value(token);
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh({bool retried = false}) async {
    final saved = await _sessions.read();
    if (saved == null) {
      await _expire();
      throw AuthFailure.sessionExpired;
    }
    try {
      final tokens = await _api.post('/auth/refresh', body: {
        'refresh_token': saved.refreshToken,
        'mode': 'json',
      }) as Map<String, Object?>;
      _takeTokens(tokens);
      await _sessions.write(StoredSession(
        userId: saved.userId,
        displayName: saved.displayName,
        refreshToken: tokens['refresh_token']! as String,
      ));
      return _accessToken!;
    } on DirectusUnreachable {
      // Mất mạng không bao giờ là lý do đăng xuất.
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      if (e.status != 401 && e.status != 403) throw AuthFailure.unknown;
      // Một tab khác có thể vừa xoay token. Máy đã cầm token mới hơn
      // thì thử lại một lần bằng token đó, trước khi kết luận phiên chết.
      final latest = await _sessions.read();
      if (!retried &&
          latest != null &&
          latest.refreshToken != saved.refreshToken) {
        return _refresh(retried: true);
      }
      await _expire();
      throw AuthFailure.sessionExpired;
    }
  }

  /// Tự động đăng xuất: chỉ bỏ phiên. **Không** động tới buổi tập nào —
  /// người chơi đăng nhập lại thì mọi thứ còn nguyên (spec mục 5.4).
  Future<void> _expire() async {
    await _sessions.clear();
    _accessToken = null;
    _accessExpiresAt = null;
    _emit(const SignedOut(expired: true));
  }

  @override
  Future<void> signOut() async {
    final saved = await _sessions.read();
    if (saved != null) {
      try {
        await _api.post('/auth/logout', body: {
          'refresh_token': saved.refreshToken,
          'mode': 'json',
        });
      } on DirectusUnreachable {
        // Không báo được server thì token tự hết hạn sau 30 ngày.
      } on DirectusError {
        // Token đã chết sẵn trên server — đúng thứ ta muốn.
      }
    }
    await _sessions.clear();
    _accessToken = null;
    _accessExpiresAt = null;
    _emit(const SignedOut());
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _api.post('/auth/password/request', body: {
        'email': _normalize(email),
        'reset_url': _resetUrl.toString(),
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError {
      throw AuthFailure.unknown;
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    if (password.length < _minPasswordLength) throw AuthFailure.weakPassword;
    try {
      await _api.post('/auth/password/reset', body: {
        'token': token,
        'password': password,
      });
    } on DirectusUnreachable {
      throw AuthFailure.network;
    } on DirectusError catch (e) {
      throw switch (e.status) {
        401 || 403 => AuthFailure.resetLinkInvalid,
        400 when e.code == 'FAILED_VALIDATION' => AuthFailure.weakPassword,
        _ => AuthFailure.unknown,
      };
    }
  }
}
```

- [ ] **Step 4: Chạy để thấy test xanh**

Run: `$F test test/data/remote/directus_auth_repository_test.dart`
Expected: `All tests passed!` (23 test)

- [ ] **Step 5: Commit**

```bash
git add lib/data/remote/directus_auth_repository.dart test/data/remote/directus_auth_repository_test.dart
git commit -m "Keep the session: refresh on demand, sign out only when the server says so

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Drift v2, buổi tập theo người dùng, và nối provider

**Files:**
- Modify: `lib/data/database/database.dart` (bảng, `schemaVersion`, migration, truy vấn)
- Modify: `lib/data/database/converters.dart` (hàm `toDrillLogRow`, thêm hàm chuyển đổi với server)
- Modify: `lib/data/repositories/drift_repositories.dart` (`DriftDrillLogRepository`)
- Modify: `lib/data/repositories/drill_log_repository.dart` (thêm `SignedOutDrillLogRepository`)
- Create: `lib/data/repositories/drift_session_store.dart`
- Create: `lib/core/config.dart`
- Create: `lib/core/providers/auth_providers.dart`
- Modify: `lib/core/providers/repository_providers.dart`
- Modify: `lib/core/bootstrap.dart`, `lib/main.dart`
- Modify: `lib/features/training/presentation/drill_session_screen.dart` (id dùng UUID)
- Create: `test/support/fake_auth.dart`
- Modify: `test/support/test_data.dart`
- Test: `test/data/database/migration_test.dart`, `test/data/repositories/drift_repositories_test.dart`, `test/data/repositories/drift_session_store_test.dart`, `test/data/database/converters_test.dart`, `test/features/training/drill_session_screen_test.dart`, `test/features/closed_loop_test.dart`, `test/data/database/upsert_seed_test.dart`, `test/core/bootstrap_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `SessionStore`, `DirectusAuthRepository`, `DirectusClient` (Task 3–4).
- Produces:
  - Bảng `AuthSessionRows` (`id` text, mặc định `'current'`; `userId`, `displayName`, `refreshToken`).
  - `DrillLogRows` có thêm `userId` (text) và `syncedAt` (datetime, nullable).
  - `AppDatabase.watchDrillLogsOf(String userId)` và `AppDatabase.watchPendingLogIds()`.
  - `toDrillLogRow(DrillLog log, {required String userId})`, `toRemoteDrillLog(DrillLogRow row)`, `fromRemoteDrillLog(Map<String, Object?> json, {required String userId, required DateTime syncedAt})`.
  - `DriftDrillLogRepository(AppDatabase db, {required String userId})`, `SignedOutDrillLogRepository`, `DriftSessionStore(AppDatabase db)`.
  - Provider: `httpClientProvider`, `directusClientProvider`, `authRepositoryProvider`, `authStateProvider`, `currentUserIdProvider`.
  - `restoreSession(ProviderContainer)`.
  - Test: `FakeAuthRepository`; `testContainer({..., AuthRepository? auth})`.

- [ ] **Step 1: Viết test migration (sẽ hỏng)**

`test/data/database/migration_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';

/// Nâng v1 → v2 (spec mục 5.1): buổi tập cũ không có chủ nên bị bỏ,
/// và máy có chỗ lưu phiên đăng nhập.
void main() {
  test('nâng từ v1 lên v2 thì bỏ buổi tập cũ và có bảng phiên đăng nhập',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute(
        'CREATE TABLE drill_log_rows (id TEXT NOT NULL PRIMARY KEY, '
        'drill_id TEXT NOT NULL, date INTEGER NOT NULL, score REAL NOT NULL, '
        'attempts INTEGER NULL, notes TEXT NULL);',
      );
      raw.execute(
        "INSERT INTO drill_log_rows VALUES ('cu', 'd1', 1758600000, 7.0, 10, NULL);",
      );
      raw.execute('PRAGMA user_version = 1;');
    });
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(await db.select(db.authSessionRows).get(), isEmpty);

    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'moi',
          userId: 'u1',
          drillId: 'd1',
          date: DateTime(2026, 9, 23),
          score: 7,
        ));
    final row = (await db.select(db.drillLogRows).get()).single;
    expect(row.userId, 'u1');
    expect(row.syncedAt, isNull);
  });
}
```

Run: `$F test test/data/database/migration_test.dart`
Expected: FAIL (chưa có `authSessionRows`, `userId`).

- [ ] **Step 2: Sửa bảng và migration trong `lib/data/database/database.dart`**

Trong `DrillLogRows`, thêm hai cột ngay sau `notes`:

```dart
  /// Chủ của buổi tập. Mọi truy vấn buổi tập đều lọc theo cột này.
  TextColumn get userId => text()();

  /// Lúc buổi tập lên server. Null nghĩa là **chưa đồng bộ**.
  DateTimeColumn get syncedAt => dateTime().nullable()();
```

Thêm bảng mới ngay sau `TimerSessionRows`:

```dart
// ─── Phiên đăng nhập ────────────────────────────────────────────────────────

/// Phiên đăng nhập trên máy này — tối đa một dòng, id luôn là 'current'.
class AuthSessionRows extends Table {
  TextColumn get id => text().withDefault(const Constant('current'))();
  TextColumn get userId => text()();
  TextColumn get displayName => text()();
  TextColumn get refreshToken => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Thêm `AuthSessionRows` vào danh sách `@DriftDatabase(tables: [...])`. Đổi `schemaVersion` thành `2` và thay `migration` bằng:

```dart
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Buổi tập v1 không có chủ; chủ sản phẩm chọn bỏ dữ liệu thử
            // thay vì gán bừa cho người đăng nhập đầu tiên.
            await m.deleteTable('drill_log_rows');
            await m.createTable(drillLogRows);
            await m.createTable(authSessionRows);
          }
        },
      );
```

Thay `watchAllDrillLogs()` bằng:

```dart
  /// Buổi tập của [userId], cũ nhất trước — đúng thứ tự categoryMastery() đòi.
  Stream<List<DrillLogRow>> watchDrillLogsOf(String userId) {
    return (select(drillLogRows)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  /// Id các buổi tập chưa lên server, của mọi người dùng trên máy.
  Stream<List<String>> watchPendingLogIds() {
    final query = selectOnly(drillLogRows)
      ..addColumns([drillLogRows.id])
      ..where(drillLogRows.syncedAt.isNull());
    return query.map((row) => row.read(drillLogRows.id)!).watch();
  }
```

Run: `$D run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded`, sinh lại `database.g.dart`.

- [ ] **Step 3: Sửa converters**

Trong `lib/data/database/converters.dart`, thay `toDrillLogRow` và thêm hai hàm cho server ngay sau nó:

```dart
DrillLogRowsCompanion toDrillLogRow(DrillLog log, {required String userId}) {
  return DrillLogRowsCompanion(
    id: drift.Value(log.id),
    userId: drift.Value(userId),
    drillId: drift.Value(log.drillId),
    date: drift.Value(log.date),
    score: drift.Value(log.score.toDouble()),
    attempts: log.attempts != null
        ? drift.Value(log.attempts!)
        : const drift.Value.absent(),
    notes: log.notes != null
        ? drift.Value(log.notes!)
        : const drift.Value.absent(),
  );
}

/// Buổi tập dạng JSON cho `POST /items/drill_logs`.
///
/// Không gửi chủ: server tự điền `user_created` từ token, app không
/// giả mạo được.
Map<String, Object?> toRemoteDrillLog(DrillLogRow row) => {
      'id': row.id,
      'drill_id': row.drillId,
      'date': row.date.toUtc().toIso8601String(),
      'score': row.score,
      'attempts': row.attempts,
      'notes': row.notes,
    };

/// Buổi tập kéo từ server về, gắn cho [userId] và đánh dấu đã đồng bộ.
DrillLogRowsCompanion fromRemoteDrillLog(
  Map<String, Object?> json, {
  required String userId,
  required DateTime syncedAt,
}) {
  return DrillLogRowsCompanion.insert(
    id: json['id']! as String,
    userId: userId,
    drillId: json['drill_id']! as String,
    date: DateTime.parse(json['date']! as String).toLocal(),
    score: (json['score']! as num).toDouble(),
    attempts: drift.Value(json['attempts'] as int?),
    notes: drift.Value(json['notes'] as String?),
    syncedAt: drift.Value(syncedAt),
  );
}
```

- [ ] **Step 4: Sửa repository**

Trong `lib/data/repositories/drift_repositories.dart`, thay `DriftDrillLogRepository` bằng:

```dart
/// Buổi tập của **một** người dùng trên Drift.
///
/// watchAll trả cũ nhất trước — đúng thứ tự categoryMastery() đòi — và
/// chỉ của [userId]: người đăng nhập sau trên cùng máy không thấy buổi
/// của người trước.
class DriftDrillLogRepository implements DrillLogRepository {
  DriftDrillLogRepository(this._db, {required String userId})
      : _userId = userId;

  final AppDatabase _db;
  final String _userId;

  @override
  Stream<List<DrillLog>> watchAll() {
    return _db.watchDrillLogsOf(_userId).map(
          (rows) => rows.map(toDrillLog).toList(),
        );
  }

  /// Ghi vào máy với `syncedAt` rỗng; SyncService tự thấy và đẩy lên.
  @override
  Future<void> add(DrillLog log) async {
    await _db.into(_db.drillLogRows).insert(toDrillLogRow(log, userId: _userId));
  }
}
```

Trong `lib/data/repositories/drill_log_repository.dart`, thêm ở cuối file:

```dart
/// Khi chưa đăng nhập: không có buổi tập nào, và không ghi được.
///
/// Router chặn mọi màn tập khi chưa đăng nhập, nên [add] chỉ chạy khi có
/// lỗi lập trình — ném ra để lỗi hiện ngay, không lặng lẽ mất dữ liệu.
class SignedOutDrillLogRepository implements DrillLogRepository {
  const SignedOutDrillLogRepository();

  @override
  Stream<List<DrillLog>> watchAll() => Stream.value(const []);

  @override
  Future<void> add(DrillLog log) =>
      Future.error(StateError('Chưa đăng nhập thì không ghi buổi tập được'));
}
```

Tạo `lib/data/repositories/drift_session_store.dart`:

```dart
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';

/// Phiên đăng nhập lưu trong Drift — giống nhau trên web và mobile.
class DriftSessionStore implements SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  @override
  Future<StoredSession?> read() async {
    final row = await _db.select(_db.authSessionRows).getSingleOrNull();
    if (row == null) return null;
    return StoredSession(
      userId: row.userId,
      displayName: row.displayName,
      refreshToken: row.refreshToken,
    );
  }

  @override
  Future<void> write(StoredSession session) async {
    await _db.into(_db.authSessionRows).insertOnConflictUpdate(
          AuthSessionRowsCompanion.insert(
            userId: session.userId,
            displayName: session.displayName,
            refreshToken: session.refreshToken,
          ),
        );
  }

  @override
  Future<void> clear() => _db.delete(_db.authSessionRows).go();
}
```

- [ ] **Step 5: Config và provider**

`lib/core/config.dart`:

```dart
/// Địa chỉ Directus. Đổi khi build: `--dart-define=API_URL=…`.
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://poolcoachai-api.kjdybl.easypanel.host',
);

/// Link trong email quên mật khẩu mở về đây.
///
/// Dựng từ origin đang chạy nên đúng cả trên bản live lẫn
/// `localhost:5555`. Cả hai phải có trong `PASSWORD_RESET_URL_ALLOW_LIST`
/// của server, không thì Directus từ chối gửi thư.
Uri resetPasswordUrl() => Uri.base.resolve('/reset-password');
```

`lib/core/providers/auth_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:poolcoachai/core/config.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/data/remote/directus_auth_repository.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_session_store.dart';
import 'package:poolcoachai/domain/auth.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final directusClientProvider = Provider<DirectusClient>((ref) {
  return DirectusClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Uri.parse(apiBaseUrl),
  );
});

/// Một instance cho cả app: nó giữ access token và trạng thái đăng nhập.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DirectusAuthRepository(
    api: ref.watch(directusClientProvider),
    sessions: DriftSessionStore(ref.watch(appDatabaseProvider)),
    resetUrl: resetPasswordUrl(),
    now: ref.watch(nowProvider),
  );
});

/// Trạng thái đăng nhập, đọc đồng bộ — không có pha "đang tải".
final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.watchSession().listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.current;
  }
}

/// Người đang đăng nhập; null khi chưa đăng nhập.
final currentUserIdProvider = Provider<String?>((ref) {
  return switch (ref.watch(authStateProvider)) {
    SignedIn(:final userId) => userId,
    SignedOut() => null,
  };
});
```

Trong `lib/core/providers/repository_providers.dart`, thêm import `package:poolcoachai/core/providers/auth_providers.dart` và thay `drillLogRepositoryProvider` bằng:

```dart
/// Buổi tập của người đang đăng nhập. Đổi người thì provider dựng lại,
/// và mọi màn đọc buổi tập tự đổi theo.
final drillLogRepositoryProvider = Provider<DrillLogRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const SignedOutDrillLogRepository();
  return DriftDrillLogRepository(ref.watch(appDatabaseProvider), userId: userId);
});
```

- [ ] **Step 6: Khôi phục phiên lúc khởi động**

Trong `lib/core/bootstrap.dart`, thêm import `package:poolcoachai/core/providers/auth_providers.dart` và thêm hàm:

```dart
/// Đọc phiên đã lưu **trước** khung hình đầu tiên, để router quyết định
/// ngay: có phiên thì vào thẳng app, kể cả khi đang mất mạng.
Future<void> restoreSession(ProviderContainer container) async {
  await container.read(authRepositoryProvider).restore();
}
```

Trong `lib/main.dart`, ngay sau `await loadSeed(container);`, thêm:

```dart
  await restoreSession(container);
```

- [ ] **Step 7: Id buổi tập dùng UUID**

Trong `lib/features/training/presentation/drill_session_screen.dart`:
- Bỏ `import 'dart:math';`, bỏ trường `_random`, và bỏ hàm `_newLogId` cùng chú thích của nó.
- Thêm `import 'package:uuid/uuid.dart';`.
- Thay `id: _newLogId(now),` bằng:

```dart
        // UUID v4: duy nhất giữa mọi người dùng trên server chung, và
        // không trùng nhau kể cả khi đồng hồ tiêm vào đứng yên trong test.
        id: const Uuid().v4(),
```

- [ ] **Step 8: Đồ test dùng chung cho auth**

`test/support/fake_auth.dart`:

```dart
import 'dart:async';

import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// AuthRepository giả cho widget test và test đồng bộ.
///
/// [nextFailure] làm lời gọi kế tiếp ném lỗi đó. [hold] giữ lời gọi
/// treo lại để test bấm nút hai lần.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthState initial = const SignedOut()]) : _state = initial;

  FakeAuthRepository.signedIn({String userId = 'u1', String displayName = 'An'})
      : this(SignedIn(userId: userId, displayName: displayName));

  AuthState _state;
  final _changes = StreamController<AuthState>.broadcast();
  final calls = <String>[];
  AuthFailure? nextFailure;
  Completer<void>? hold;

  /// Đặt khác null thì accessToken() ném lỗi này.
  AuthFailure? tokenFailure;

  void emit(AuthState state) {
    _state = state;
    _changes.add(state);
  }

  Future<void> _step(String call) async {
    calls.add(call);
    await hold?.future;
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watchSession() => _changes.stream;

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _step('register:$email');
    emit(SignedIn(userId: 'u1', displayName: displayName));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _step('signIn:$email');
    emit(const SignedIn(userId: 'u1', displayName: 'An'));
  }

  @override
  Future<void> signOut() async {
    await _step('signOut');
    emit(const SignedOut());
  }

  @override
  Future<void> requestPasswordReset(String email) => _step('request:$email');

  @override
  Future<void> resetPassword({required String token, required String password}) =>
      _step('reset:$token');

  @override
  Future<String> accessToken() async {
    final failure = tokenFailure;
    if (failure != null) throw failure;
    return switch (_state) {
      SignedIn(:final userId) => 'access-$userId',
      SignedOut() => throw AuthFailure.sessionExpired,
    };
  }
}
```

Trong `test/support/test_data.dart`, thêm import `package:poolcoachai/core/providers/auth_providers.dart`, `package:poolcoachai/data/repositories/auth_repository.dart` và `fake_auth.dart`. Thêm tham số `AuthRepository? auth` vào `testContainer`, và thêm dòng override vào danh sách `overrides`:

```dart
      authRepositoryProvider
          .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
```

- [ ] **Step 9: Sửa test cũ cho hợp với buổi tập theo người**

Run: `grep -rn "DriftDrillLogRepository(db)\|toDrillLogRow(\|DrillLogRowsCompanion.insert(\|appDatabaseProvider.overrideWithValue" test`

Với từng chỗ tìm được:
- `DriftDrillLogRepository(db)` thành `DriftDrillLogRepository(db, userId: 'u1')`.
- `toDrillLogRow(log)` thành `toDrillLogRow(log, userId: 'u1')`.
- `DrillLogRowsCompanion.insert(` thêm `userId: 'u1',`.
- Mỗi `ProviderContainer(overrides: [... appDatabaseProvider.overrideWithValue(db) ...])` trong `test/features/closed_loop_test.dart` và `test/features/training/drill_session_screen_test.dart` thêm một phần tử inline: `authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),`. Nhớ import `fake_auth.dart` và `auth_providers.dart`.

Thêm vào `test/data/repositories/drift_repositories_test.dart`, trong group `DriftDrillLogRepository`:

```dart
    test('chỉ thấy buổi tập của đúng người', () async {
      await DriftDrillLogRepository(db, userId: 'u1').add(logAt('cua-an', DateTime(2026, 9, 20)));
      await DriftDrillLogRepository(db, userId: 'u2').add(logAt('cua-binh', DateTime(2026, 9, 21)));

      final logs = await DriftDrillLogRepository(db, userId: 'u1').watchAll().first;

      expect(logs.map((l) => l.id), ['cua-an']);
    });

    test('ghi mới thì chưa đồng bộ', () async {
      await DriftDrillLogRepository(db, userId: 'u1').add(logAt('moi', DateTime(2026, 9, 20)));

      final row = (await db.select(db.drillLogRows).get()).single;
      expect(row.userId, 'u1');
      expect(row.syncedAt, isNull);
    });
```

Tạo `test/data/repositories/drift_session_store_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/data/repositories/drift_session_store.dart';

void main() {
  late AppDatabase db;
  late DriftSessionStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSessionStore(db);
  });
  tearDown(() => db.close());

  test('chưa lưu gì thì đọc ra null', () async {
    expect(await store.read(), isNull);
  });

  test('ghi hai lần thì chỉ còn một phiên, là phiên sau', () async {
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1'));
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r2'));

    expect((await store.read())?.refreshToken, 'r2');
    expect(await db.select(db.authSessionRows).get(), hasLength(1));
  });

  test('xoá phiên không động tới buổi tập', () async {
    await store.write(const StoredSession(userId: 'u1', displayName: 'An', refreshToken: 'r1'));
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'x', userId: 'u1', drillId: 'd1', date: DateTime(2026, 9, 23), score: 7));

    await store.clear();

    expect(await store.read(), isNull);
    expect(await db.select(db.drillLogRows).get(), hasLength(1));
  });
}
```

Thêm vào `test/data/database/converters_test.dart`:

```dart
  test('buổi tập đi lên server rồi về máy vẫn nguyên, kể cả chữ tiếng Việt',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'x',
          userId: 'u1',
          drillId: 'd1',
          date: DateTime(2026, 9, 23, 10, 30),
          score: 7,
          attempts: const Value(10),
          notes: const Value('Cú đánh hơi lệch phải'),
        ));
    final original = (await db.select(db.drillLogRows).get()).single;

    final json = toRemoteDrillLog(original);
    expect(json.containsKey('user_created'), isFalse);

    await db.delete(db.drillLogRows).go();
    await db.into(db.drillLogRows).insert(
          fromRemoteDrillLog(json, userId: 'u1', syncedAt: DateTime(2026, 9, 23, 11)),
        );
    final back = (await db.select(db.drillLogRows).get()).single;

    expect(back.date, original.date);
    expect(back.score, 7);
    expect(back.attempts, 10);
    expect(back.notes, 'Cú đánh hơi lệch phải');
    expect(back.syncedAt, isNotNull);
  });
```

(Chỉnh import của file này nếu thiếu: `package:drift/drift.dart` show `Value`; `NativeDatabase`.)

Thêm vào `test/features/training/drill_session_screen_test.dart`:

```dart
  testWidgets('buổi tập mới mang id UUID v4', (tester) async {
    final (db, _) = await openSession(tester, 'd1');

    await fill(tester, Vi.sessionScoreLabelAttempts, '7');
    await fill(tester, Vi.sessionAttemptsLabel, '10');
    await tester.tap(find.text(Vi.sessionSaveAction));
    await tester.pumpAndSettle();

    final id = (await db.select(db.drillLogRows).get()).single.id;
    expect(
      id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });
```

Thêm vào `test/core/bootstrap_test.dart`:

```dart
  test('khôi phục phiên trước khung đầu tiên', () async {
    final auth = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await restoreSession(container);

    expect(auth.calls, ['restore']);
  });
```

(Import `fake_auth.dart` và `auth_providers.dart`.)

- [ ] **Step 10: Chạy toàn bộ test**

Run: `$F test`
Expected: `All tests passed!` Số test tăng từ 212 lên đúng bằng số test mới thêm ở Task 3–5.

Run: `$F analyze`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add -A lib test
git commit -m "Give every drill log an owner and a sync mark; schema v2

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Bốn màn tài khoản và cổng đăng nhập của router

**Files:**
- Create: `lib/core/auth/auth_gate.dart`
- Modify: `lib/core/providers/auth_providers.dart` (thêm `authGateProvider`)
- Modify: `lib/core/router/routes.dart`, `lib/core/router/app_router.dart`, `lib/app.dart`
- Modify: `lib/core/strings/vi.dart`
- Create: `lib/features/auth/presentation/auth_form_scaffold.dart`, `auth_validators.dart`, `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`
- Modify: 11 chỗ gọi `createAppRouter()` trong `test/`
- Modify: `test/support/test_data.dart` (thêm `signedInGate()`, `pumpAuthApp`)
- Modify: `test/smoke/all_routes_test.dart`, `test/core/router/routes_test.dart`
- Test: `test/core/router/auth_redirect_test.dart`, `test/features/auth/auth_screens_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthState`, `AuthFailure`, `authRepositoryProvider`, `authStateProvider` (Task 3–5).
- Produces:
  - `AuthGate(AuthRepository)`, `AuthGate.fixed(AuthState)`, `AuthGate.state`, `authGateProvider`
  - `createAppRouter({required AuthGate auth})`, `authRedirect(AuthState auth, Uri location) → String?`
  - `Routes.login` = `/login`, `Routes.register` = `/register`, `Routes.forgotPassword` = `/forgot-password`, `Routes.resetPassword` = `/reset-password`, `Routes.signedOutOnly`
  - `Vi.authFailure(AuthFailure)` cùng các chuỗi `Vi.auth*` bên dưới

- [ ] **Step 1: Chuỗi trong `Vi`**

Thêm vào cuối class `Vi` (và thêm `import 'package:poolcoachai/domain/auth.dart';` ở đầu file):

```dart
  // Tài khoản — spec mục 4.3.
  static const authLoginTitle = 'Đăng nhập';
  static const authLoginAction = 'Đăng nhập';
  static const authEmailLabel = 'Email';
  static const authPasswordLabel = 'Mật khẩu';
  static const authToRegister = 'Chưa có tài khoản? Đăng ký';
  static const authToForgot = 'Quên mật khẩu?';
  static const authToLogin = 'Đã có tài khoản? Đăng nhập';
  static const authSessionExpired =
      'Phiên đăng nhập đã hết, hãy đăng nhập lại.';

  static const authRegisterTitle = 'Tạo tài khoản';
  static const authRegisterAction = 'Tạo tài khoản';
  static const authDisplayNameLabel = 'Tên hiển thị';
  static const authPasswordConfirmLabel = 'Nhập lại mật khẩu';

  static const authForgotTitle = 'Quên mật khẩu';
  static const authForgotHint =
      'Nhập email bạn dùng để đăng ký. Chúng tôi sẽ gửi link đặt lại mật khẩu.';
  static const authForgotAction = 'Gửi link';

  /// Luôn cùng một câu, dù email có tài khoản hay không — để không ai
  /// dùng màn này dò xem email nào đã đăng ký.
  static const authForgotSent =
      'Nếu email này có tài khoản, link đặt lại mật khẩu đã được gửi.';

  static const authResetTitle = 'Đặt lại mật khẩu';
  static const authNewPasswordLabel = 'Mật khẩu mới';
  static const authResetAction = 'Lưu mật khẩu mới';
  static const authResetDone =
      'Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới.';
  static const authResetMissingToken =
      'Link đặt lại mật khẩu không đầy đủ. Hãy mở lại link trong email.';

  static const authFieldRequired = 'Không được để trống';
  static const authEmailInvalid = 'Nhập email hợp lệ';
  static const authPasswordTooShort = 'Mật khẩu cần ít nhất 8 ký tự';
  static const authPasswordMismatch = 'Hai mật khẩu không khớp';

  /// Một câu cho mỗi loại lỗi — không bao giờ hiện nguyên văn lỗi server.
  static String authFailure(AuthFailure failure) => switch (failure) {
        AuthFailure.wrongCredentials => 'Email hoặc mật khẩu không đúng.',
        AuthFailure.emailTaken =>
          'Email này đã có tài khoản. Hãy đăng nhập, hoặc dùng Quên mật khẩu.',
        AuthFailure.weakPassword => 'Mật khẩu cần ít nhất 8 ký tự.',
        AuthFailure.network =>
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        AuthFailure.resetLinkInvalid =>
          'Link đặt lại mật khẩu đã hết hạn hoặc đã dùng. Hãy yêu cầu link mới.',
        AuthFailure.sessionExpired => authSessionExpired,
        AuthFailure.unknown => 'Máy chủ đang gặp lỗi. Hãy thử lại sau.',
      };
```

Thêm vào `test/core/strings/vi_test.dart`:

```dart
    test('mỗi lỗi tài khoản có một câu riêng, không rỗng', () {
      final texts = AuthFailure.values.map(Vi.authFailure).toList();
      for (final t in texts) {
        expect(t.trim(), isNotEmpty);
      }
      expect(texts.toSet().length, AuthFailure.values.length);
    });
```

(Import `package:poolcoachai/domain/auth.dart`.)

- [ ] **Step 2: Route và cổng**

Trong `lib/core/router/routes.dart`, thêm vào trước `/// Năm tab theo đúng thứ tự…`:

```dart
  // Tài khoản — mở khi chưa đăng nhập.
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// Mở từ link trong email; vào được cả khi đã hay chưa đăng nhập.
  static const resetPassword = '/reset-password';

  /// Đã đăng nhập thì không vào lại mấy màn này.
  static const signedOutOnly = <String>[login, register, forgotPassword];
```

Và thêm `login, register, forgotPassword, resetPassword,` vào cuối danh sách `all`.

Trong `test/core/router/routes_test.dart`, test `all gom đủ…` phải liệt kê thêm bốn route này ở cuối, đúng thứ tự trên. Đổi tên test thành `'all gom đủ năm tab, hai màn mở đè, ba đường dẫn có tham số và bốn màn tài khoản'`.

`lib/core/auth/auth_gate.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

/// Cầu nối từ trạng thái đăng nhập sang `refreshListenable` của router.
///
/// Đăng nhập, đăng xuất hay phiên hết hạn đều làm router chạy lại
/// redirect, nên không màn nào phải tự điều hướng sau khi xong việc.
class AuthGate extends ChangeNotifier {
  AuthGate(AuthRepository repo) : _state = repo.current {
    _sub = repo.watchSession().listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  /// Cổng đứng yên — cho test chỉ cần một trạng thái cố định.
  AuthGate.fixed(AuthState state) : _state = state;

  AuthState _state;
  StreamSubscription<AuthState>? _sub;

  AuthState get state => _state;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

Thêm vào `lib/core/providers/auth_providers.dart` (kèm import `auth_gate.dart`):

```dart
final authGateProvider = Provider<AuthGate>((ref) {
  final gate = AuthGate(ref.watch(authRepositoryProvider));
  ref.onDispose(gate.dispose);
  return gate;
});
```

- [ ] **Step 3: Test redirect (sẽ hỏng)**

`test/core/router/auth_redirect_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/domain/auth.dart';

void main() {
  const out = SignedOut();
  const inn = SignedIn(userId: 'u1', displayName: 'An');
  Uri at(String p) => Uri.parse(p);

  test('chưa đăng nhập mở màn tập thì về Đăng nhập', () {
    expect(authRedirect(out, at('/training')), Routes.login);
    expect(authRedirect(out, at('/training/drills/d1/session')), Routes.login);
  });

  test('chưa đăng nhập vẫn mở được ba màn tài khoản', () {
    for (final p in Routes.signedOutOnly) {
      expect(authRedirect(out, at(p)), isNull, reason: p);
    }
  });

  test('đã đăng nhập mà mở màn tài khoản thì về Trang chủ', () {
    for (final p in Routes.signedOutOnly) {
      expect(authRedirect(inn, at(p)), Routes.home, reason: p);
    }
  });

  test('link đặt lại mật khẩu mở được ở cả hai trạng thái', () {
    expect(authRedirect(out, at('/reset-password?token=abc')), isNull);
    expect(authRedirect(inn, at('/reset-password?token=abc')), isNull);
  });

  test('đã đăng nhập thì mọi màn khác giữ nguyên', () {
    expect(authRedirect(inn, at('/training')), isNull);
  });
}
```

Run: `$F test test/core/router/auth_redirect_test.dart`
Expected: FAIL (`authRedirect` chưa tồn tại).

- [ ] **Step 4: Router**

Trong `lib/core/router/app_router.dart`:
- Thêm import `package:poolcoachai/core/auth/auth_gate.dart`, `package:poolcoachai/domain/auth.dart` và bốn màn ở Step 6.
- Đổi chữ ký thành `GoRouter createAppRouter({required AuthGate auth}) => GoRouter(`.
- Thêm vào ngay dưới `initialLocation: Routes.home,`:

```dart
  refreshListenable: auth,
  redirect: (context, state) => authRedirect(auth.state, state.uri),
```

Thêm vào cuối mảng `routes:`:

```dart
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) =>
          ResetPasswordScreen(token: state.uri.queryParameters['token']),
    ),
```

Thêm hàm ở cuối file:

```dart
/// Ai được vào đâu — tách riêng để test không phải dựng router.
///
/// Chưa đăng nhập thì chỉ vào được ba màn tài khoản; đã đăng nhập thì
/// không vào lại chúng. Link đặt lại mật khẩu mở được ở cả hai trạng
/// thái, vì người ta có thể bấm nó trên máy vẫn đang đăng nhập.
String? authRedirect(AuthState auth, Uri location) {
  final path = location.path;
  if (path == Routes.resetPassword) return null;
  final onAuthPage = Routes.signedOutOnly.contains(path);
  return switch (auth) {
    SignedOut() when !onAuthPage => Routes.login,
    SignedIn() when onAuthPage => Routes.home,
    _ => null,
  };
}
```

Trong `lib/app.dart`:
- `PoolCoachApp` thành `ConsumerStatefulWidget`, `_PoolCoachAppState` thành `ConsumerState<PoolCoachApp>`.
- Thêm import `package:flutter_riverpod/flutter_riverpod.dart` và `package:poolcoachai/core/providers/auth_providers.dart`.
- Đổi dòng dựng router thành:

```dart
  late final GoRouter _router =
      widget.router ?? createAppRouter(auth: ref.read(authGateProvider));
```

- [ ] **Step 5: Khung chung và hàm kiểm dữ liệu nhập**

`lib/features/auth/presentation/auth_form_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';

/// Khung chung của bốn màn tài khoản: tiêu đề, form giữa màn, rộng tối đa 420.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dòng báo lỗi dưới form, màu lỗi của theme.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
```

`lib/features/auth/presentation/auth_validators.dart`:

```dart
import 'package:poolcoachai/core/strings/vi.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRequired(String? value) =>
    (value ?? '').trim().isEmpty ? Vi.authFieldRequired : null;

String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return Vi.authFieldRequired;
  return _email.hasMatch(text) ? null : Vi.authEmailInvalid;
}

String? validateNewPassword(String? value) =>
    (value ?? '').length < 8 ? Vi.authPasswordTooShort : null;
```

- [ ] **Step 6: Bốn màn**

`lib/features/auth/presentation/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/auth_form_scaffold.dart';
import 'package:poolcoachai/features/auth/presentation/auth_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Chặn bấm lần hai khi lần đầu chưa xong.
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      // Không điều hướng ở đây: đăng nhập xong thì router tự đưa vào app.
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = switch (ref.watch(authStateProvider)) {
      SignedOut(expired: true) => true,
      _ => false,
    };

    return AuthFormScaffold(
      title: Vi.authLoginTitle,
      children: [
        if (expired)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(Vi.authSessionExpired),
          ),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: Vi.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: Vi.authPasswordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                validator: validateRequired,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authLoginAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.forgotPassword),
          child: const Text(Vi.authToForgot),
        ),
        TextButton(
          onPressed: () => context.go(Routes.register),
          child: const Text(Vi.authToRegister),
        ),
      ],
    );
  }
}
```

`lib/features/auth/presentation/register_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/auth_form_scaffold.dart';
import 'package:poolcoachai/features/auth/presentation/auth_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).register(
            displayName: _name.text,
            email: _email.text,
            password: _password.text,
          );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: Vi.authRegisterTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: Vi.authDisplayNameLabel),
                autofillHints: const [AutofillHints.name],
                validator: validateRequired,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: Vi.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: Vi.authPasswordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: Vi.authPasswordConfirmLabel,
                ),
                obscureText: true,
                validator: (v) =>
                    v == _password.text ? null : Vi.authPasswordMismatch,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authRegisterAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.login),
          child: const Text(Vi.authToLogin),
        ),
      ],
    );
  }
}
```

`lib/features/auth/presentation/forgot_password_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/auth_form_scaffold.dart';
import 'package:poolcoachai/features/auth/presentation/auth_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: Vi.authForgotTitle,
      children: [
        const Text(Vi.authForgotHint),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: Vi.authEmailLabel),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        if (_sent)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Text(Vi.authForgotSent),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(Vi.authForgotAction),
        ),
        TextButton(
          onPressed: () => context.go(Routes.login),
          child: const Text(Vi.authToLogin),
        ),
      ],
    );
  }
}
```

`lib/features/auth/presentation/reset_password_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/theme/app_spacing.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/auth_form_scaffold.dart';
import 'package:poolcoachai/features/auth/presentation/auth_validators.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  /// Token trong link email; null khi link bị cắt cụt.
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(String token) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: token, password: _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Vi.authResetDone)),
      );
      context.go(Routes.login);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = Vi.authFailure(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return AuthFormScaffold(
        title: Vi.authResetTitle,
        children: [
          const Text(Vi.authResetMissingToken),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () => context.go(Routes.forgotPassword),
            child: const Text(Vi.authToForgot),
          ),
        ],
      );
    }

    return AuthFormScaffold(
      title: Vi.authResetTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _password,
                decoration:
                    const InputDecoration(labelText: Vi.authNewPasswordLabel),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: Vi.authPasswordConfirmLabel,
                ),
                obscureText: true,
                validator: (v) =>
                    v == _password.text ? null : Vi.authPasswordMismatch,
                onFieldSubmitted: (_) => _submit(token),
              ),
            ],
          ),
        ),
        if (_error != null) AuthErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : () => _submit(token),
          child: const Text(Vi.authResetAction),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7: Cập nhật 11 chỗ gọi `createAppRouter()` trong test**

Trong `test/support/test_data.dart`, thêm (kèm import `auth_gate.dart`, `domain/auth.dart`):

```dart
/// Cổng đã đăng nhập — cho các test màn tập vốn không quan tâm tài khoản.
AuthGate signedInGate() =>
    AuthGate.fixed(const SignedIn(userId: 'u1', displayName: 'An'));
```

Run: `grep -rln "createAppRouter()" test`

Trong mỗi file tìm được, đổi `createAppRouter()` thành `createAppRouter(auth: signedInGate())` và import `test/support/test_data.dart` nếu file chưa import.

Thêm helper vào `test/support/test_data.dart` (kèm import `flutter_test`, `go_router`, `app.dart`, `app_router.dart`):

```dart
/// Dựng cả app với một AuthRepository giả, cổng nối thật vào nó.
Future<(GoRouter, FakeAuthRepository)> pumpAuthApp(
  WidgetTester tester, {
  AuthState initial = const SignedOut(),
  String? location,
}) async {
  final auth = FakeAuthRepository(initial);
  final container = testContainer(auth: auth);
  addTearDown(container.dispose);
  final gate = AuthGate(auth);
  addTearDown(gate.dispose);
  final router = createAppRouter(auth: gate);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return (router, auth);
}
```

- [ ] **Step 8: Test màn hình (sẽ hỏng cho tới khi Step 4–7 xong)**

`test/features/auth/auth_screens_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/domain/auth.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';
import 'package:poolcoachai/features/auth/presentation/reset_password_screen.dart';
import 'package:poolcoachai/features/home/presentation/home_screen.dart';

import '../../support/test_data.dart';

void main() {
  Future<void> fill(WidgetTester tester, String label, String value) =>
      tester.enterText(find.widgetWithText(TextFormField, label), value);

  Finder button(String text) => find.widgetWithText(FilledButton, text);

  group('Đăng nhập', () {
    testWidgets('chưa đăng nhập thì mở app là vào màn Đăng nhập', (tester) async {
      await pumpAuthApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('email sai dạng thì chặn, không gọi server', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);

      await fill(tester, Vi.authEmailLabel, 'khong-phai-email');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authEmailInvalid), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('đăng nhập đúng thì router tự vào Trang chủ', (tester) async {
      await pumpAuthApp(tester);

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sai mật khẩu thì nói bằng tiếng Việt', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);
      auth.nextFailure = AuthFailure.wrongCredentials;

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'sai');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.wrongCredentials)), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('bấm Đăng nhập hai lần chỉ gọi một lần', (tester) async {
      final (_, auth) = await pumpAuthApp(tester);
      auth.hold = Completer<void>();

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await tester.tap(button(Vi.authLoginAction));
      await tester.pump();
      await tester.tap(button(Vi.authLoginAction));
      await tester.pump();
      auth.hold!.complete();
      await tester.pumpAndSettle();

      expect(auth.calls.where((c) => c.startsWith('signIn')), hasLength(1));
    });

    testWidgets('phiên hết hạn thì màn Đăng nhập nói lý do', (tester) async {
      await pumpAuthApp(tester, initial: const SignedOut(expired: true));

      expect(find.text(Vi.authSessionExpired), findsOneWidget);
    });

    testWidgets('đang đăng nhập mà phiên hết hạn thì về Đăng nhập', (tester) async {
      final (_, auth) = await pumpAuthApp(
        tester,
        initial: const SignedIn(userId: 'u1', displayName: 'An'),
      );
      expect(find.byType(HomeScreen), findsOneWidget);

      auth.emit(const SignedOut(expired: true));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(Vi.authSessionExpired), findsOneWidget);
    });
  });

  group('Đăng ký', () {
    testWidgets('hai mật khẩu không khớp thì chặn', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau124');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authPasswordMismatch), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('mật khẩu dưới 8 ký tự thì chặn', (tester) async {
      await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authPasswordLabel, '1234567');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authPasswordTooShort), findsOneWidget);
    });

    testWidgets('đăng ký xong vào thẳng app', (tester) async {
      await pumpAuthApp(tester, location: Routes.register);

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('email đã có tài khoản thì nói rõ và chỉ đường', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.register);
      auth.nextFailure = AuthFailure.emailTaken;

      await fill(tester, Vi.authDisplayNameLabel, 'An');
      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await fill(tester, Vi.authPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authRegisterAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.emailTaken)), findsOneWidget);
    });
  });

  group('Quên mật khẩu', () {
    testWidgets('gửi xong luôn cùng một câu', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.forgotPassword);

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await tester.tap(button(Vi.authForgotAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authForgotSent), findsOneWidget);
      expect(auth.calls, ['request:an@example.com']);
    });

    testWidgets('mất mạng thì báo mạng, không báo đã gửi', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: Routes.forgotPassword);
      auth.nextFailure = AuthFailure.network;

      await fill(tester, Vi.authEmailLabel, 'an@example.com');
      await tester.tap(button(Vi.authForgotAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.network)), findsOneWidget);
      expect(find.text(Vi.authForgotSent), findsNothing);
    });
  });

  group('Đặt lại mật khẩu', () {
    testWidgets('link mang token thì màn nhận đúng token', (tester) async {
      await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');

      final screen = tester.widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen));
      expect(screen.token, 'abc');
    });

    testWidgets('link thiếu token thì nói rõ, không có form', (tester) async {
      await pumpAuthApp(tester, location: Routes.resetPassword);

      expect(find.text(Vi.authResetMissingToken), findsOneWidget);
      expect(button(Vi.authResetAction), findsNothing);
    });

    testWidgets('đặt lại xong thì về Đăng nhập kèm thông báo', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');

      await fill(tester, Vi.authNewPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authResetAction));
      await tester.pumpAndSettle();

      expect(auth.calls, ['reset:abc']);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(Vi.authResetDone), findsOneWidget);
    });

    testWidgets('link đã dùng thì bảo xin link mới', (tester) async {
      final (_, auth) = await pumpAuthApp(tester, location: '${Routes.resetPassword}?token=abc');
      auth.nextFailure = AuthFailure.resetLinkInvalid;

      await fill(tester, Vi.authNewPasswordLabel, 'matkhau123');
      await fill(tester, Vi.authPasswordConfirmLabel, 'matkhau123');
      await tester.tap(button(Vi.authResetAction));
      await tester.pumpAndSettle();

      expect(find.text(Vi.authFailure(AuthFailure.resetLinkInvalid)), findsOneWidget);
    });
  });
}
```

- [ ] **Step 9: Smoke test phủ bốn route mới**

Trong `test/smoke/all_routes_test.dart`:
- Import bốn màn tài khoản cùng `package:poolcoachai/domain/auth.dart`.
- Thêm một bảng thứ hai ngay dưới `_routeCases`:

```dart
/// Màn tài khoản chỉ mở được khi **chưa** đăng nhập, nên đi lưới riêng.
const _signedOutRouteCases = <String, _RouteCase>{
  Routes.login: (path: Routes.login, screen: LoginScreen),
  Routes.register: (path: Routes.register, screen: RegisterScreen),
  Routes.forgotPassword: (
    path: Routes.forgotPassword,
    screen: ForgotPasswordScreen,
  ),
  Routes.resetPassword: (
    path: '/reset-password?token=abc',
    screen: ResetPasswordScreen,
  ),
};
```

- Trong `pumpApp`, thêm tham số `{bool signedIn = true}`. Dùng `createAppRouter(auth: signedIn ? signedInGate() : AuthGate.fixed(const SignedOut()))`.
- Nhân đôi hai testWidgets `mở được mọi đường dẫn…` và `mỗi đường dẫn dựng đúng màn hình…`. Bản mới gọi `pumpApp(tester, signedIn: false)` và duyệt `_signedOutRouteCases`. Đặt tên bản mới có thêm hậu tố ` — khi chưa đăng nhập`.
- Test `bảng smoke test phủ hết…` so sánh `{..._routeCases.keys, ..._signedOutRouteCases.keys}` với `Routes.all.toSet()`.
- Test `đường dẫn mẫu khớp đúng khuôn…` duyệt `{..._routeCases, ..._signedOutRouteCases}.entries`. Dòng `final pathParts = entry.value.path.split('/');` đổi thành `final pathParts = Uri.parse(entry.value.path).path.split('/');`.

- [ ] **Step 10: Chạy toàn bộ**

Run: `$F test`
Expected: `All tests passed!`

Run: `$F analyze`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add -A lib test
git commit -m "Put the app behind sign-in: four account screens and a router gate

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `SyncService`

**Files:**
- Create: `lib/data/sync/sync_service.dart`
- Modify: `lib/core/providers/auth_providers.dart` (thêm `syncServiceProvider`)
- Modify: `lib/main.dart` (gọi `start()`)
- Test: `test/data/sync/sync_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.watchPendingLogIds()`, `toRemoteDrillLog`, `fromRemoteDrillLog` (Task 5); `AuthRepository.current`, `watchSession`, `accessToken` (Task 3); `DirectusClient` (Task 3). Mã lỗi trùng id lấy theo findings của Task 2 (mặc định `RECORD_NOT_UNIQUE`).
- Produces: `enum SyncOutcome { done, offline, signedOut, failed }`; `SyncService({required AppDatabase db, required AuthRepository auth, required DirectusClient api, required DateTime Function() now, Duration retryEvery})` với `start()`, `syncNow() → Future<SyncOutcome>`, `dispose()`; `syncServiceProvider`.

- [ ] **Step 1: Viết test thất bại**

`test/data/sync/sync_service_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  late AppDatabase db;
  late FakeDirectus server;
  late FakeAuthRepository auth;
  late SyncService sync;
  final now = DateTime(2026, 9, 23, 10);

  SyncService build({Duration retryEvery = const Duration(seconds: 30)}) => SyncService(
        db: db,
        auth: auth,
        api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
        now: () => now,
        retryEvery: retryEvery,
      );

  Future<void> addLog(String id, {String userId = 'u1', DateTime? syncedAt}) =>
      db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: id,
            userId: userId,
            drillId: 'd1',
            date: DateTime(2026, 9, 22, 18),
            score: 7,
            syncedAt: Value(syncedAt),
          ));

  Future<DrillLogRow> row(String id) =>
      (db.select(db.drillLogRows)..where((t) => t.id.equals(id))).getSingle();

  List<String> pushedIds() => server
      .sent('POST', '/items/drill_logs')
      .map((r) => FakeDirectus.body(r)['id']! as String)
      .toList();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = (req) => FakeDirectus.ok(jsonDecode(req.body))
      ..routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok([]);
    auth = FakeAuthRepository.signedIn(userId: 'u1');
    sync = build();
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  group('đẩy lên', () {
    test('gửi buổi chưa đồng bộ kèm token, rồi đánh dấu đã đồng bộ', () async {
      await addLog('a');

      expect(await sync.syncNow(), SyncOutcome.done);

      expect(pushedIds(), ['a']);
      expect(server.sent('POST', '/items/drill_logs').single.headers['Authorization'], 'Bearer access-u1');
      expect((await row('a')).syncedAt, now);
    });

    test('không gửi lại buổi đã đồng bộ', () async {
      await addLog('cu', syncedAt: DateTime(2026, 9, 22));

      await sync.syncNow();

      expect(pushedIds(), isEmpty);
    });

    test('server báo trùng id thì coi như đã lên', () async {
      await addLog('a');
      server.routes['POST /items/drill_logs'] = (_) => FakeDirectus.error(400, 'RECORD_NOT_UNIQUE');

      expect(await sync.syncNow(), SyncOutcome.done);
      expect((await row('a')).syncedAt, isNotNull);
    });

    test('mất mạng thì giữ trạng thái chờ và vẫn đăng nhập', () async {
      await addLog('a');
      server.offline = true;

      expect(await sync.syncNow(), SyncOutcome.offline);
      expect((await row('a')).syncedAt, isNull);
      expect(auth.current, isA<SignedIn>());
    });

    test('phiên hết hạn thì dừng, buổi tập vẫn nằm chờ trên máy', () async {
      await addLog('a');
      auth.tokenFailure = AuthFailure.sessionExpired;

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect((await row('a')).syncedAt, isNull);
    });

    test('buổi chưa đồng bộ của A không bao giờ đi lên bằng token của B', () async {
      await addLog('cua-an', userId: 'u1');
      auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
      await addLog('cua-binh', userId: 'u2');

      await sync.syncNow();

      expect(pushedIds(), ['cua-binh']);
      for (final req in server.requests) {
        expect(req.body, isNot(contains('cua-an')));
      }
      expect((await row('cua-an')).syncedAt, isNull);
    });
  });

  group('kéo về', () {
    final remote = [
      {'id': 'tu-may-khac', 'drill_id': 'd1', 'date': '2026-09-21T11:00:00.000Z', 'score': 9, 'attempts': 10, 'notes': 'Ổn'},
    ];

    test('ghi buổi từ server cho người đang đăng nhập, đã đồng bộ', () async {
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok(remote);

      await sync.syncNow();

      final r = await row('tu-may-khac');
      expect(r.userId, 'u1');
      expect(r.notes, 'Ổn');
      expect(r.syncedAt, now);
    });

    test('kéo hai lần không sinh bản trùng', () async {
      server.routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok(remote);

      await sync.syncNow();
      await sync.syncNow();

      expect(await db.select(db.drillLogRows).get(), hasLength(1));
    });

    test('đổi người giữa chừng thì không ghi gì', () async {
      server.routes['GET /items/drill_logs'] = (_) {
        auth.emit(const SignedIn(userId: 'u2', displayName: 'Bình'));
        return FakeDirectus.ok(remote);
      };

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect(await db.select(db.drillLogRows).get(), isEmpty);
    });
  });

  group('tự chạy', () {
    test('chưa đăng nhập thì không gọi server', () async {
      auth.emit(const SignedOut());

      expect(await sync.syncNow(), SyncOutcome.signedOut);
      expect(server.requests, isEmpty);
    });

    test('gọi chồng nhau chỉ đẩy mỗi buổi một lần', () async {
      await addLog('a');

      await Future.wait([sync.syncNow(), sync.syncNow(), sync.syncNow()]);

      expect(pushedIds(), ['a']);
    });

    test('có buổi tập mới thì tự đẩy, không cần ai gọi', () async {
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await addLog('moi');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(pushedIds(), contains('moi'));
    });

    test('mất mạng rồi có lại thì lần thử lại định kỳ đẩy lên', () async {
      sync.dispose();
      sync = build(retryEvery: const Duration(milliseconds: 50));
      server.offline = true;
      await addLog('a');
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((await row('a')).syncedAt, isNull);

      server.offline = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect((await row('a')).syncedAt, isNotNull);
    });

    test('vừa đăng nhập thì kéo dữ liệu về', () async {
      auth.emit(const SignedOut());
      sync.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      server.requests.clear();

      auth.emit(const SignedIn(userId: 'u1', displayName: 'An'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(server.sent('GET', '/items/drill_logs'), isNotEmpty);
    });
  });
}
```

(Import thêm `package:drift/drift.dart` show `Value`.)

Run: `$F test test/data/sync/sync_service_test.dart`
Expected: FAIL (`sync_service.dart` chưa tồn tại).

- [ ] **Step 2: Viết `lib/data/sync/sync_service.dart`**

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';
import 'package:poolcoachai/domain/auth.dart';

enum SyncOutcome { done, offline, signedOut, failed }

/// Đổi người đăng nhập giữa một lượt đồng bộ — bỏ lượt đó.
class _UserChanged implements Exception {
  const _UserChanged();
}

/// Đẩy buổi tập chưa đồng bộ lên Directus, rồi kéo buổi tập về máy.
///
/// Chỉ làm việc với dữ liệu của **người đang đăng nhập**: dòng chờ của
/// người khác trên cùng máy nằm yên cho tới khi chính họ đăng nhập lại
/// (spec mục 5.4). Màn hình không biết lớp này tồn tại — chúng đọc Drift.
class SyncService {
  SyncService({
    required AppDatabase db,
    required AuthRepository auth,
    required DirectusClient api,
    required DateTime Function() now,
    Duration retryEvery = const Duration(seconds: 30),
  })  : _db = db,
        _auth = auth,
        _api = api,
        _now = now,
        _retryEvery = retryEvery;

  final AppDatabase _db;
  final AuthRepository _auth;
  final DirectusClient _api;
  final DateTime Function() _now;
  final Duration _retryEvery;

  /// Mã Directus khi `POST` một id đã có — xem findings của Task 2.
  static const _duplicateCode = 'RECORD_NOT_UNIQUE';

  Future<SyncOutcome>? _running;
  bool _again = false;
  Set<String> _seenPending = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<String>>? _pendingSub;

  /// Tự đồng bộ: ngay lúc gọi, khi vừa đăng nhập, khi có buổi tập mới,
  /// và định kỳ khi vẫn còn buổi nằm chờ.
  void start() {
    _authSub = _auth.watchSession().listen((state) {
      if (state is SignedIn) unawaited(syncNow());
    });
    _pendingSub = _db.watchPendingLogIds().listen((ids) {
      final fresh = ids.any((id) => !_seenPending.contains(id));
      _seenPending = ids.toSet();
      if (fresh) unawaited(syncNow());
    });
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_seenPending.isNotEmpty) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  /// Một lượt đẩy rồi kéo. Gọi khi đang chạy thì chạy thêm đúng một lượt
  /// sau lượt hiện tại, để buổi vừa ghi không phải chờ tới lần thử lại.
  Future<SyncOutcome> syncNow() {
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
    } while (_again && outcome == SyncOutcome.done);
    return outcome;
  }

  Future<SyncOutcome> _once() async {
    final who = _auth.current;
    if (who is! SignedIn) return SyncOutcome.signedOut;
    try {
      await _push(who.userId);
      await _pull(who.userId);
      return SyncOutcome.done;
    } on AuthFailure catch (failure) {
      return switch (failure) {
        AuthFailure.network => SyncOutcome.offline,
        AuthFailure.sessionExpired => SyncOutcome.signedOut,
        _ => SyncOutcome.failed,
      };
    } on DirectusUnreachable {
      return SyncOutcome.offline;
    } on DirectusError {
      return SyncOutcome.failed;
    } on _UserChanged {
      return SyncOutcome.signedOut;
    }
  }

  bool _stillSignedInAs(String userId) => switch (_auth.current) {
        SignedIn(userId: final id) => id == userId,
        SignedOut() => false,
      };

  /// Lấy token rồi kiểm lại người dùng: token luôn thuộc người đang đăng
  /// nhập, nên người đổi thì dừng, không gửi dữ liệu của người cũ.
  Future<String> _tokenFor(String userId) async {
    final token = await _auth.accessToken();
    if (!_stillSignedInAs(userId)) throw const _UserChanged();
    return token;
  }

  Future<void> _push(String userId) async {
    final pending = await (_db.select(_db.drillLogRows)
          ..where((t) => t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    for (final row in pending) {
      final token = await _tokenFor(userId);
      try {
        await _api.post('/items/drill_logs',
            token: token, body: toRemoteDrillLog(row));
      } on DirectusError catch (e) {
        // Đã lên từ lần trước mà chưa kịp đánh dấu — không phải lỗi.
        if (e.code != _duplicateCode) rethrow;
      }
      await (_db.update(_db.drillLogRows)..where((t) => t.id.equals(row.id)))
          .write(DrillLogRowsCompanion(syncedAt: Value(_now())));
    }
  }

  Future<void> _pull(String userId) async {
    final token = await _tokenFor(userId);
    final items = await _api.get('/items/drill_logs', token: token, query: {
      'limit': '-1',
      'fields': 'id,drill_id,date,score,attempts,notes',
    }) as List<Object?>;

    // Người đổi trong lúc chờ server thì bỏ kết quả: ghi vào là dựng lại
    // dữ liệu mà người cũ vừa xoá khi đăng xuất.
    if (!_stillSignedInAs(userId)) throw const _UserChanged();

    final syncedAt = _now();
    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(
          _db.drillLogRows,
          fromRemoteDrillLog(
            item! as Map<String, Object?>,
            userId: userId,
            syncedAt: syncedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
  }
}
```

- [ ] **Step 3: Chạy để thấy test xanh**

Run: `$F test test/data/sync/sync_service_test.dart`
Expected: `All tests passed!` (14 test)

- [ ] **Step 4: Nối vào app**

Thêm vào `lib/core/providers/auth_providers.dart` (kèm import `sync_service.dart`):

```dart
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(directusClientProvider),
    now: ref.watch(nowProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
```

Trong `lib/main.dart`, ngay sau `await restoreSession(container);`, thêm import `auth_providers.dart` và dòng:

```dart
  // Đồng bộ chạy nền suốt đời app; màn hình chỉ đọc Drift.
  container.read(syncServiceProvider).start();
```

Run: `$F test && $F analyze`
Expected: `All tests passed!` và `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "Sync drill logs: push what is pending, pull what is on the server

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Đăng xuất ở tab Hồ sơ

**Files:**
- Create: `lib/data/sync/account_actions.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/core/strings/vi.dart`
- Test: `test/data/sync/account_actions_test.dart`, `test/features/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `AuthRepository`, `authStateProvider`, `currentUserIdProvider`, `syncServiceProvider`, `appDatabaseProvider`, `SyncOutcome`.
- Produces: `pendingLogCount(AppDatabase db, String userId) → Future<int>`; `signOutAndForget({required AppDatabase db, required AuthRepository auth, required String userId})`.

- [ ] **Step 1: Chuỗi**

Thêm vào cuối `Vi`:

```dart
  // Đăng xuất — spec mục 5.4.
  static String profileSignedInAs(String name) => 'Đang đăng nhập: $name';
  static const profileSignOut = 'Đăng xuất';
  static const signOutPendingTitle = 'Còn buổi tập chưa đồng bộ';
  static String signOutPendingBody(int count) =>
      'Còn $count buổi chưa đồng bộ, đăng xuất sẽ mất.';
  static const signOutSyncFirst = 'Đồng bộ trước';
  static const signOutAnyway = 'Vẫn đăng xuất';
  static const syncFailed = 'Chưa đồng bộ được. Kiểm tra mạng rồi thử lại.';
```

- [ ] **Step 2: Test thất bại cho `account_actions`**

`test/data/sync/account_actions_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/domain/auth.dart';

import '../../support/fake_auth.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addLog(String id, String userId, {bool synced = false}) =>
      db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: id,
            userId: userId,
            drillId: 'd1',
            date: DateTime(2026, 9, 22),
            score: 7,
            syncedAt: Value(synced ? DateTime(2026, 9, 22) : null),
          ));

  test('chỉ đếm buổi chưa đồng bộ của đúng người', () async {
    await addLog('a', 'u1');
    await addLog('b', 'u1', synced: true);
    await addLog('c', 'u2');

    expect(await pendingLogCount(db, 'u1'), 1);
  });

  test('bấm Đăng xuất thì xoá buổi của người đó, giữ của người khác', () async {
    final auth = FakeAuthRepository.signedIn(userId: 'u1');
    await addLog('a', 'u1');
    await addLog('c', 'u2');

    await signOutAndForget(db: db, auth: auth, userId: 'u1');

    final left = await db.select(db.drillLogRows).get();
    expect(left.map((r) => r.id), ['c']);
    expect(auth.current, const SignedOut());
  });
}
```

Run: `$F test test/data/sync/account_actions_test.dart`
Expected: FAIL.

- [ ] **Step 3: Viết `lib/data/sync/account_actions.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/repositories/auth_repository.dart';

/// Số buổi của [userId] chưa lên server.
Future<int> pendingLogCount(AppDatabase db, String userId) async {
  final count = db.drillLogRows.id.count();
  final query = db.selectOnly(db.drillLogRows)
    ..addColumns([count])
    ..where(db.drillLogRows.userId.equals(userId) &
        db.drillLogRows.syncedAt.isNull());
  return (await query.getSingle()).read(count) ?? 0;
}

/// Đăng xuất do **người chơi bấm**: xoá buổi tập của họ khỏi máy, để
/// người dùng sau trên cùng máy không thấy.
///
/// Tự động đăng xuất không bao giờ đi qua đây — nó giữ nguyên mọi thứ.
Future<void> signOutAndForget({
  required AppDatabase db,
  required AuthRepository auth,
  required String userId,
}) async {
  await (db.delete(db.drillLogRows)..where((t) => t.userId.equals(userId)))
      .go();
  await auth.signOut();
}
```

Run: `$F test test/data/sync/account_actions_test.dart`
Expected: PASS.

- [ ] **Step 4: Test màn Hồ sơ (sẽ hỏng)**

`test/features/profile/profile_screen_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poolcoachai/app.dart';
import 'package:poolcoachai/core/auth/auth_gate.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/providers/now_provider.dart';
import 'package:poolcoachai/core/router/app_router.dart';
import 'package:poolcoachai/core/router/routes.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/database/upsert_seed.dart';
import 'package:poolcoachai/data/remote/directus_client.dart';
import 'package:poolcoachai/data/sync/sync_service.dart';
import 'package:poolcoachai/features/auth/presentation/login_screen.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_directus.dart';

void main() {
  final today = DateTime(2026, 9, 23, 10);

  Future<(AppDatabase, FakeAuthRepository, FakeDirectus)> openProfile(
    WidgetTester tester, {
    int pending = 0,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await upsertSeed(db);
    for (var i = 0; i < pending; i++) {
      await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
            id: 'p$i', userId: 'u1', drillId: 'd1', date: today, score: 7));
    }
    await db.into(db.drillLogRows).insert(DrillLogRowsCompanion.insert(
          id: 'da-len', userId: 'u1', drillId: 'd1', date: today, score: 7,
          syncedAt: Value(today)));

    final auth = FakeAuthRepository.signedIn(userId: 'u1', displayName: 'An');
    final server = FakeDirectus()
      ..routes['POST /items/drill_logs'] = (req) => FakeDirectus.ok(jsonDecode(req.body))
      ..routes['GET /items/drill_logs'] = (_) => FakeDirectus.ok([]);
    final sync = SyncService(
      db: db,
      auth: auth,
      api: DirectusClient(client: server.client, baseUrl: FakeDirectus.baseUrl),
      now: () => today,
    );
    addTearDown(sync.dispose);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      nowProvider.overrideWithValue(() => today),
      authRepositoryProvider.overrideWithValue(auth),
      syncServiceProvider.overrideWithValue(sync),
    ]);
    addTearDown(container.dispose);
    final gate = AuthGate(auth);
    addTearDown(gate.dispose);
    final router = createAppRouter(auth: gate);
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: PoolCoachApp(router: router),
    ));
    await tester.pumpAndSettle();
    router.go(Routes.profile);
    await tester.pumpAndSettle();
    return (db, auth, server);
  }

  testWidgets('hiện tên người đang đăng nhập', (tester) async {
    await openProfile(tester);

    expect(find.text(Vi.profileSignedInAs('An')), findsOneWidget);
  });

  testWidgets('không còn buổi chờ thì đăng xuất ngay, xoá dữ liệu trên máy',
      (tester) async {
    final (db, auth, _) = await openProfile(tester);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('còn buổi chờ thì cảnh báo trước, bấm Vẫn đăng xuất thì mất',
      (tester) async {
    final (db, auth, _) = await openProfile(tester, pending: 2);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    expect(find.text(Vi.signOutPendingBody(2)), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.tap(find.text(Vi.signOutAnyway));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(await db.select(db.drillLogRows).get(), isEmpty);
  });

  testWidgets('chọn Đồng bộ trước thì đẩy lên rồi mới đăng xuất', (tester) async {
    final (_, auth, server) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(server.sent('POST', '/items/drill_logs'), hasLength(1));
    expect(auth.calls, ['signOut']);
  });

  testWidgets('Đồng bộ trước mà mất mạng thì không đăng xuất, báo lỗi',
      (tester) async {
    final (db, auth, server) = await openProfile(tester, pending: 1);
    server.offline = true;

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Vi.signOutSyncFirst));
    await tester.pumpAndSettle();

    expect(find.text(Vi.syncFailed), findsOneWidget);
    expect(auth.calls, isEmpty);
    expect(await db.select(db.drillLogRows).get(), hasLength(2));
  });

  testWidgets('bỏ qua hộp thoại thì không làm gì', (tester) async {
    final (_, auth, _) = await openProfile(tester, pending: 1);

    await tester.tap(find.text(Vi.profileSignOut));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
  });
}
```

Run: `$F test test/features/profile/profile_screen_test.dart`
Expected: FAIL.

- [ ] **Step 5: Viết lại `lib/features/profile/presentation/profile_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poolcoachai/core/providers/auth_providers.dart';
import 'package:poolcoachai/core/providers/database_provider.dart';
import 'package:poolcoachai/core/strings/vi.dart';
import 'package:poolcoachai/core/widgets/pc_empty_state.dart';
import 'package:poolcoachai/core/widgets/pc_root_scaffold.dart';
import 'package:poolcoachai/data/sync/account_actions.dart';
import 'package:poolcoachai/domain/auth.dart';

enum _SignOutChoice { syncFirst, anyway }

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final db = ref.read(appDatabaseProvider);

    final pending = await pendingLogCount(db, userId);
    if (pending > 0) {
      if (!context.mounted) return;
      final choice = await showDialog<_SignOutChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Vi.signOutPendingTitle),
          content: Text(Vi.signOutPendingBody(pending)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.anyway),
              child: const Text(Vi.signOutAnyway),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _SignOutChoice.syncFirst),
              child: const Text(Vi.signOutSyncFirst),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == _SignOutChoice.syncFirst) {
        await ref.read(syncServiceProvider).syncNow();
        if (await pendingLogCount(db, userId) > 0) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(Vi.syncFailed)),
          );
          return;
        }
      }
    }

    // Router tự đưa về màn Đăng nhập khi trạng thái đổi.
    await signOutAndForget(
      db: db,
      auth: ref.read(authRepositoryProvider),
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = switch (ref.watch(authStateProvider)) {
      SignedIn(:final displayName) => displayName,
      SignedOut() => '',
    };

    return PcRootScaffold(
      title: Vi.profileTitle,
      body: PcEmptyState(
        icon: Icons.person_outline,
        title: Vi.profileSignedInAs(name),
        body: Vi.profileComing,
        action: OutlinedButton.icon(
          onPressed: () => _signOut(context, ref),
          icon: const Icon(Icons.logout),
          label: const Text(Vi.profileSignOut),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Chạy toàn bộ**

Run: `$F test && $F analyze`
Expected: `All tests passed!` và `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add -A lib test
git commit -m "Sign out from Profile, warning before unsynced sessions are lost

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: URL dạng đường dẫn và đường dẫn tuyệt đối cho file wasm

**Files:**
- Modify: `pubspec.yaml` (thêm `flutter_web_plugins`)
- Modify: `lib/main.dart`
- Modify: `lib/data/database/database.dart` (`_openConnection`)
- Modify: `test/architecture_test.dart`
- Modify: `deploy/publish.sh` (chạy `build_runner`)
- Create: `tool/e2e/serve.mjs`
- Create: `tool/e2e/cdp.mjs`

**Interfaces:**
- Produces: `launch({port, name})` trong `tool/e2e/cdp.mjs`, trả về một tab có `goto`, `reload`, `text`, `waitForText`, `click`, `type`, `blockApi`, `shot`, `eval`, `errors`, `close`. Ngoài ra app đọc URL dạng `/training/drills/d1`; `node tool/e2e/serve.mjs <dir> <port>` là server tĩnh có fallback về `index.html` và MIME `application/wasm`.

**Vì sao task này tồn tại:** chuyển sang URL dạng đường dẫn thì `Uri.parse('sqlite3.wasm')` được hiểu tương đối theo trang đang mở. Mở `/training/drills/d1` sẽ tải `/training/drills/sqlite3.wasm`, và nginx trả về `index.html` thay cho wasm. Kết quả là DB vỡ, nhưng chỉ khi người dùng mở thẳng một link sâu.

- [ ] **Step 1: Sửa guard kiến trúc cho đòi đường dẫn tuyệt đối (sẽ hỏng)**

Trong `test/architecture_test.dart`, trong test `'DB mở được trên web…'`, thay đoạn từ `final assets = …` tới hết vòng `for` bằng:

```dart
    final assets = RegExp(r"Uri\.parse\('([^']+)'\)")
        .allMatches(source)
        .map((m) => m[1]!)
        .toList();
    expect(assets, containsAll(['/sqlite3.wasm', '/drift_worker.js']),
        reason: 'phải là đường dẫn tuyệt đối: app dùng URL dạng đường dẫn, '
            'nên đường dẫn tương đối bị hiểu theo trang đang mở, và mở '
            'thẳng /training/drills/d1 sẽ tải nhầm index.html thay cho wasm');
    for (final asset in assets) {
      expect(
        File('web$asset').existsSync(),
        isTrue,
        reason: 'web$asset không có — build web sẽ không mang theo nó',
      );
    }
```

Thêm test mới ngay sau test đó:

```dart
  test('app dùng URL dạng đường dẫn, để link trong email mở đúng màn', () {
    final main = codeOnly(File('lib/main.dart').readAsStringSync());
    expect(main, contains('usePathUrlStrategy()'),
        reason: 'link đặt lại mật khẩu có dạng /reset-password?token=…; '
            'ở dạng hash, Directus chèn ?token vào trước dấu #');
  });
```

Run: `$F test test/architecture_test.dart`
Expected: FAIL ở cả hai test.

- [ ] **Step 2: Sửa code**

Trong `pubspec.yaml`, thêm vào `dependencies:` ngay dưới `flutter_localizations:`:

```yaml

  # usePathUrlStrategy: URL dạng /reset-password?token=…, không có dấu #.
  flutter_web_plugins:
    sdk: flutter
```

Trong `lib/data/database/database.dart`, trong `_openConnection`, đổi hai dòng `Uri.parse` thành `Uri.parse('/sqlite3.wasm')` và `Uri.parse('/drift_worker.js')`. Sửa dòng chú thích phía trên thành:

```dart
    // Trên web, drift chạy SQLite bằng WebAssembly trong một worker.
    // Hai file nằm trong web/ và phải khớp phiên bản đang khoá:
    // sqlite3.wasm theo package sqlite3, drift_worker.js theo drift.
    // Đường dẫn tuyệt đối: app dùng URL dạng đường dẫn, tương đối thì
    // mở /training/drills/d1 sẽ đi tìm /training/drills/sqlite3.wasm.
```

Trong `lib/main.dart`, thêm `import 'package:flutter_web_plugins/url_strategy.dart';` và gọi ngay sau `WidgetsFlutterBinding.ensureInitialized();`:

```dart
  // URL dạng /training/drills/d1 thay vì /#/training/…: link đặt lại mật
  // khẩu trong email mang ?token=…, và dạng hash làm token lạc chỗ.
  usePathUrlStrategy();
```

Run: `$F pub get && $F test && $F analyze`
Expected: `All tests passed!` và `No issues found!`

- [ ] **Step 3: `publish.sh` tự sinh code Drift**

Trong `deploy/publish.sh`:
- Sửa dòng hướng dẫn cách gọi thành:
  `#   FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat DART=/c/Users/anhnpv/flutter/bin/dart.bat deploy/publish.sh`
- Thêm `DART="${DART:-dart}"` ngay dưới dòng `FLUTTER=…`.
- Ngay trước `"$FLUTTER" build web --release`, thêm:

```bash
# *.g.dart bị git bỏ qua: bản checkout sạch không có, build sẽ hỏng.
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Viết `tool/e2e/serve.mjs`**

```js
// Server tĩnh giống nginx trên Easypanel: fallback về index.html và MIME đúng cho wasm.
//   node tool/e2e/serve.mjs build/web 8765
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [, , dir = 'build/web', port = '8765'] = process.argv;
const root = path.resolve(dir);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.frag': 'application/octet-stream',
};

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  let file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, 'index.html');
  }
  res.writeHead(200, {
    'Content-Type': types[path.extname(file)] ?? 'application/octet-stream',
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(file).pipe(res);
}).listen(Number(port), '127.0.0.1', () => console.log(`http://127.0.0.1:${port}/`));
```

- [ ] **Step 5: Viết `tool/e2e/cdp.mjs`**

```js
// Điều khiển Chrome headless qua DevTools Protocol — đủ để lái một app Flutter web.
//
// Flutter vẽ bằng canvas, nên muốn đọc chữ và bấm nút thì phải bật cây
// semantics (bấm flt-semantics-placeholder) rồi làm việc với aria-label.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const CHROME = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Mở một Chrome riêng (profile riêng = một "máy" riêng). */
export async function launch({ port, name }) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), `pcai-${name}-`));
  const proc = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    '--no-first-run',
    'about:blank',
  ], { stdio: 'ignore' });

  let targets = null;
  for (let i = 0; i < 40 && !targets; i++) {
    try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); } catch { await sleep(250); }
  }
  if (!targets) throw new Error(`Chrome ${name} không mở cổng ${port}`);
  const page = targets.find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });

  const tab = new Tab(ws, name);
  await tab.init();
  tab.close = async () => { ws.close(); proc.kill(); };
  return tab;
}

class Tab {
  constructor(ws, name) {
    this.ws = ws;
    this.name = name;
    this.nextId = 0;
    this.pending = new Map();
    this.errors = [];
    ws.onmessage = (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id && this.pending.has(m.id)) { this.pending.get(m.id)(m); this.pending.delete(m.id); return; }
      if (m.method === 'Runtime.exceptionThrown') {
        this.errors.push(m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text);
      }
      if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') {
        this.errors.push(m.params.args.map((a) => a.value ?? a.description).join(' '));
      }
    };
  }

  send(method, params = {}) {
    return new Promise((resolve) => {
      const id = ++this.nextId;
      this.pending.set(id, resolve);
      this.ws.send(JSON.stringify({ id, method, params }));
    }).then((m) => {
      if (m.error) throw new Error(`${method}: ${m.error.message}`);
      return m.result;
    });
  }

  async init() {
    await this.send('Runtime.enable');
    await this.send('Page.enable');
    await this.send('Network.enable');
    await this.send('Emulation.setDeviceMetricsOverride', { width: 412, height: 915, deviceScaleFactor: 1, mobile: true });
  }

  async eval(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    return r.result?.value;
  }

  async semantics() {
    await this.eval(`document.querySelector('flt-semantics-placeholder')?.click()`);
    await sleep(300);
  }

  async goto(url) { await this.send('Page.navigate', { url }); await sleep(8000); await this.semantics(); }
  async reload() { await this.send('Page.reload', {}); await sleep(8000); await this.semantics(); }

  async labels() {
    await this.semantics();
    return this.eval(`[...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean)`);
  }

  async text() { return (await this.labels()).join('\n'); }

  async waitForText(needle, timeoutMs = 30000) {
    const end = Date.now() + timeoutMs;
    while (Date.now() < end) {
      if ((await this.text()).includes(needle)) return;
      await sleep(1000);
    }
    throw new Error(`[${this.name}] không thấy "${needle}" sau ${timeoutMs}ms. Đang thấy:\n${await this.text()}`);
  }

  /** Bấm node semantics khớp [label]; ưu tiên nút, rồi node có nhãn ngắn nhất. */
  async click(label) {
    await this.semantics();
    const r = await this.eval(`(() => {
      const hits = [...document.querySelectorAll('flt-semantics')]
        .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
        .filter((x) => x.t.includes(${JSON.stringify(label)}))
        // Nút trước (tiêu đề AppBar có thể trùng chữ với nút), rồi nhãn ngắn nhất.
        .sort((a, b) => (a.e.getAttribute('role') === 'button' ? 0 : 1) - (b.e.getAttribute('role') === 'button' ? 0 : 1)
          || a.t.length - b.t.length);
      if (!hits.length) return null;
      hits[0].e.click();
      return hits[0].t;
    })()`);
    if (r == null) throw new Error(`[${this.name}] không có nút "${label}". Đang thấy:\n${await this.text()}`);
    await sleep(1500);
  }

  /**
   * Gõ vào ô có nhãn [label]. Lần chèn chữ đầu tiên sau khi điều hướng
   * hay bị Flutter nuốt mất, nên đọc lại giá trị và thử tối đa ba lần.
   */
  async type(label, value) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await this.semantics();
      const found = await this.eval(`(() => {
        const el = [...document.querySelectorAll('input, textarea')]
          .find((e) => (e.getAttribute('aria-label') || '').includes(${JSON.stringify(label)}));
        if (!el) return false;
        el.focus(); el.click(); return true;
      })()`);
      if (!found) await this.click(label);
      await sleep(600);
      await this.eval(`document.activeElement?.select?.()`);
      await this.send('Input.insertText', { text: value });
      await sleep(400);
      if ((await this.eval(`document.activeElement?.value ?? null`)) === value) return;
    }
    throw new Error(`[${this.name}] không gõ được vào ô "${label}"`);
  }

  /** Chặn mọi request tới API — giả lập mất mạng mà app vẫn chạy. */
  async blockApi(on) {
    await this.send('Network.setBlockedURLs', { urls: on ? ['*poolcoachai-api*'] : [] });
  }

  async shot(file) {
    const r = await this.send('Page.captureScreenshot', { format: 'png' });
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
  }
}
```

- [ ] **Step 6: Kiểm link sâu trên bản build thật**

Chạy:

```bash
$F build web --release --dart-define=API_URL=https://poolcoachai-api.kjdybl.easypanel.host
node tool/e2e/serve.mjs build/web 8765 &
node -e "
import('./tool/e2e/cdp.mjs').then(async ({ launch }) => {
  const tab = await launch({ port: 9333, name: 'deep' });
  await tab.goto('http://127.0.0.1:8765/training/drills/d1');
  console.log('URL:', await tab.eval('location.pathname'));
  console.log('Có màn Đăng nhập:', (await tab.text()).includes('Đăng nhập'));
  console.log('Lỗi:', JSON.stringify(tab.errors));
  await tab.close();
});"
```

Expected:
- `URL: /login`: bị đưa về Đăng nhập vì chưa có phiên, không có `#`.
- `Có màn Đăng nhập: true`.
- `Lỗi: []`, và không có dòng nào nhắc `wasm` hay `CompileError`.

Dừng server `serve.mjs` sau khi kiểm xong.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/data/database/database.dart test/architecture_test.dart deploy/publish.sh tool/e2e/serve.mjs tool/e2e/cdp.mjs
git commit -m "Switch to path URLs, and load the wasm from the root so deep links work

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Deploy và kiểm thật trên hai trình duyệt

**Files:**
- Create: `tool/e2e/accounts.mjs`
- Modify: `C:\Users\anhnpv\.claude\projects\C--Users-anhnpv-Desktop-PoolCoachAI\memory\poolcoachai-deploy.md` (không nằm trong repo)

**Interfaces:**
- Consumes: mọi task trước; biến môi trường `MAILPIT_URL`, `MAILPIT_USER`, `MAILPIT_PASSWORD`, và (tuỳ chọn, để dọn dẹp) `DIRECTUS_URL`, `DIRECTUS_ADMIN_EMAIL`, `DIRECTUS_ADMIN_PASSWORD`.
- Produces: bản live có tài khoản; ảnh chụp ở `$TMP/pcai-e2e/`.

- [ ] **Step 1: Viết `tool/e2e/accounts.mjs`** (dùng `tool/e2e/cdp.mjs` từ Task 9)

```js
// Tầng 4 của kiểm thử (spec mục 8): hai "máy" là hai profile Chrome.
//
//   MAILPIT_URL=… MAILPIT_USER=… MAILPIT_PASSWORD=… node tool/e2e/accounts.mjs [appUrl]
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
const MAIL = need('MAILPIT_URL').replace(/\/$/, '');
const mailAuth = 'Basic ' + Buffer.from(`${need('MAILPIT_USER')}:${need('MAILPIT_PASSWORD')}`).toString('base64');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-e2e');

const email = `e2e-${Date.now()}@poolcoachai.local`;
const pass1 = randomBytes(6).toString('hex');
const pass2 = randomBytes(6).toString('hex');
const step = (n, msg) => console.log(`\n── Bước ${n}: ${msg}`);

async function signIn(tab, password) {
  await tab.type('Email', email);
  await tab.type('Mật khẩu', password);
  await tab.click('Đăng nhập');
  await tab.waitForText('Xin chào');
}

async function record(tab, score) {
  await tab.goto(`${APP}/training/drills/d1/session`);
  await tab.type('Số lần đạt', String(score));
  await tab.type('Số lần thử', '10');
  await tab.click('Lưu kết quả');
  await tab.waitForText('Đã lưu');
}

async function resetLink() {
  for (let i = 0; i < 30; i++) {
    const found = await (await fetch(`${MAIL}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`, { headers: { Authorization: mailAuth } })).json();
    const id = found.messages?.[0]?.ID;
    if (id) {
      const msg = await (await fetch(`${MAIL}/api/v1/message/${id}`, { headers: { Authorization: mailAuth } })).json();
      const link = (msg.HTML + msg.Text).match(/https?:\/\/[^\s"'<]+\/reset-password\?token=[^\s"'<&]+/)?.[0];
      if (link) return link;
    }
    await sleep(1000);
  }
  throw new Error('không thấy thư đặt lại mật khẩu trong mailpit');
}

const one = await launch({ port: 9333, name: 'may-1' });
const two = await launch({ port: 9334, name: 'may-2' });
try {
  step(1, 'Máy 1 đăng ký và ghi buổi 7/10');
  await one.goto(APP);
  await one.waitForText('Đăng nhập');
  await one.click('Chưa có tài khoản');
  await one.type('Tên hiển thị', 'Người thử E2E');
  await one.type('Email', email);
  await one.type('Nhập lại mật khẩu', pass1);
  await one.type('Mật khẩu', pass1);
  await one.click('Tạo tài khoản');
  await one.waitForText('Xin chào');
  await record(one, 7);
  await one.shot(path.join(shots, '1-may1-ghi-7.png'));

  step(2, 'Máy 2 đăng nhập cùng tài khoản và thấy buổi đó');
  await two.goto(APP);
  await signIn(two, pass1);
  await two.goto(`${APP}/training/drills/d1`);
  await two.waitForText('87%', 45000);
  await two.shot(path.join(shots, '2-may2-thay-87.png'));

  step(3, 'Máy 1 mất mạng, ghi buổi 9/10 — chỉ nằm trên máy');
  await one.blockApi(true);
  await record(one, 9);
  await one.shot(path.join(shots, '3-may1-ghi-offline.png'));

  step(4, 'Máy 2 đăng xuất, quên mật khẩu, đặt mật khẩu mới qua mailpit');
  await two.goto(`${APP}/profile`);
  await two.click('Đăng xuất');
  await two.waitForText('Quên mật khẩu');
  await two.click('Quên mật khẩu');
  await two.type('Email', email);
  await two.click('Gửi link');
  await two.waitForText('Nếu email này có tài khoản');
  const link = await resetLink();
  console.log(`   link: ${link.slice(0, 60)}…`);
  await two.goto(link);
  await two.type('Nhập lại mật khẩu', pass2);
  await two.type('Mật khẩu mới', pass2);
  await two.click('Lưu mật khẩu mới');
  await two.waitForText('Đã đổi mật khẩu');
  await two.shot(path.join(shots, '4-may2-doi-mat-khau.png'));

  step(5, 'Máy 1 có mạng lại, mở lại app: tự đăng xuất nhưng buổi offline vẫn còn');
  await one.blockApi(false);
  await one.reload();
  await one.waitForText('Phiên đăng nhập đã hết', 45000);
  await one.shot(path.join(shots, '5a-may1-het-phien.png'));
  await signIn(one, pass2);
  await one.goto(`${APP}/training/drills/d1`);
  await one.waitForText('113%', 45000);
  await one.waitForText('87%');
  await one.shot(path.join(shots, '5b-may1-con-du.png'));

  step(6, 'Máy 2 đăng nhập bằng mật khẩu mới và thấy buổi offline của máy 1');
  await two.goto(APP);
  await signIn(two, pass2);
  await two.goto(`${APP}/training/drills/d1`);
  await two.waitForText('113%', 45000);
  await two.shot(path.join(shots, '6-may2-thay-113.png'));

  const errors = [...one.errors, ...two.errors].filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nTất cả 6 bước qua. Ảnh ở ${shots}`);
} finally {
  await one.close();
  await two.close();
  if (process.env.DIRECTUS_URL && process.env.DIRECTUS_ADMIN_PASSWORD) {
    const base = process.env.DIRECTUS_URL.replace(/\/$/, '');
    const login = await (await fetch(`${base}/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.DIRECTUS_ADMIN_EMAIL, password: process.env.DIRECTUS_ADMIN_PASSWORD }),
    })).json();
    const token = login.data.access_token;
    const users = await (await fetch(`${base}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`, { headers: { Authorization: `Bearer ${token}` } })).json();
    for (const u of users.data) {
      await fetch(`${base}/users/${u.id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
    }
    console.log('Đã xoá user thử');
  }
}
```

- [ ] **Step 2: Kiểm lần cuối trên máy**

Run: `$F test && $F analyze`
Expected: `All tests passed!` và `No issues found!`

- [ ] **Step 3: Merge vào `main` và deploy**

Làm theo superpowers:finishing-a-development-branch để đưa `feat/accounts-sync` vào `main` và push. Sau đó, từ bản checkout `main` sạch:

```bash
FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat DART=/c/Users/anhnpv/flutter/bin/dart.bat bash deploy/publish.sh
```

Tiếp theo, gọi `mcp__easypanel__execute_destructive` với `deployAppService`, input `{"projectName": "test-va", "serviceName": "poolcoachai"}`. Chờ domain phục vụ `main.dart.js` mới:

```bash
curl -s https://poolcoachai.kjdybl.easypanel.host/version.json
curl -s -o /dev/null -w '%{http_code}\n' https://poolcoachai.kjdybl.easypanel.host/reset-password
```

Expected: link sâu `/reset-password` trả `200` (nginx fallback về `index.html`).

- [ ] **Step 4: Chạy kịch bản hai máy trên bản live**

Run: `node tool/e2e/accounts.mjs`
Expected: sáu dòng `── Bước`, rồi `Tất cả 6 bước qua`, rồi `Đã xoá user thử`.

Mở và xem **từng** ảnh trong `$TMP/pcai-e2e/` bằng Read. Ảnh `5b` phải cho thấy cả `87%` lẫn `113%` trong Lịch sử tập.

- [ ] **Step 5: Commit script E2E**

```bash
git checkout -b chore/e2e-accounts main
git add tool/e2e/accounts.mjs
git commit -m "Add the two-browser end-to-end run for accounts and sync

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git checkout main && git merge --ff-only chore/e2e-accounts && git push origin main && git branch -d chore/e2e-accounts
```

- [ ] **Step 6: Cập nhật memory `poolcoachai-deploy.md`**

Thêm một đoạn vào file:
- `test-va` giờ có `api` (Directus), `db`, `mailpit`, cùng hai domain `poolcoachai-api…` và `poolcoachai-mail…`.
- Bí mật nằm trong `.claude/settings.local.json` → `env`.
- `bootstrap.mjs` dựng lại cấu hình; `verify.mjs` kiểm quyền; `tool/e2e/accounts.mjs` chạy kịch bản hai máy.
- Thay đoạn về CDP bằng: đã có `tool/e2e/cdp.mjs` trong repo, dùng lại thay vì viết script tạm.

- [ ] **Step 7: Báo chủ sản phẩm**

Báo cáo gồm:
- URL mailpit, cùng user/mật khẩu basic auth.
- Email và mật khẩu admin Directus.
- Kết quả `verify.mjs` và `accounts.mjs`.
- Mọi dòng `NOTE` đáng chú ý trong findings, nhất là tiêu đề thư (Directus có thể vẫn để tiêu đề tiếng Anh).
- Step 3 của Task 2 có phải làm không.

Không đưa bí mật vào commit hay vào file nào được git theo dõi.
