// Dựng cấu hình Directus cho PoolCoachAI. Chạy lại bao nhiêu lần cũng ra cùng một kết quả.
//
//   DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… \
//   DIRECTUS_LICENSE_KEY=… node deploy/directus/bootstrap.mjs
//
// DIRECTUS_LICENSE_KEY là khoá Open Innovation Grant (OIG). Script tự gửi nó
// qua POST /license — nó KHÔNG phải biến môi trường của Directus. Chỉ cần ở
// lần chạy đầu: server đã có licence OIG thì bỏ trống cũng được. Không có
// licence OIG thì Directus không cho tạo permission có lọc, nên script dừng
// ngay từ đầu, trước khi tạo bất cứ thứ gì.
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

// ─── 0. Kích hoạt Open Innovation Grant licence ─────────────────────────────────
// OIG bật `custom_permission_rules_enabled`, cho phép tạo filtered/field-limited permissions.
// Thiếu nó thì permission ở bước 3 hỏng giữa chừng, để lại cấu hình dở dang —
// nên kiểm trước, rồi mới tạo gì thì tạo.

// /server/info chỉ expose display_powered_by — không phải custom_permission_rules_enabled,
// flag thực sự cần ở bước 3. Route admin GET /license có đầy đủ entitlement,
// kể cả custom_permission_rules_enabled, nên dùng nó thay vì /server/info.
async function canUseCustomPermissionRules() {
  try {
    const lic = await api('GET', '/license', undefined, token);
    return lic?.status === 'active'
      && lic?.entitlements?.custom_permission_rules_enabled?.default === true;
  } catch (e) {
    throw new Error(`Kiểm tra licence thất bại → ${e.message}`);
  }
}

const licenseKey = process.env.DIRECTUS_LICENSE_KEY;
const activeBefore = await canUseCustomPermissionRules();
if (!activeBefore && !licenseKey) {
  console.error(
    'Server chưa có licence OIG và DIRECTUS_LICENSE_KEY không được đặt. ' +
      'Đặt DIRECTUS_LICENSE_KEY (khoá Open Innovation Grant) rồi chạy lại. ' +
      'Chưa tạo gì trên server.',
  );
  process.exit(1);
}
if (!activeBefore) {
  console.log('Kích hoạt Open Innovation Grant licence…');
  // POST /license trả 403 "A license was already activated" nếu đã có licence.
  const licRaw = await fetch(`${base}/license`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ license_key: licenseKey }),
  });
  const licText = await licRaw.text();
  if (!licRaw.ok && !licText.includes('already activated')) {
    throw new Error(`Kích hoạt licence thất bại → ${licRaw.status} ${licText}`);
  }
  const activeAfter = await canUseCustomPermissionRules();
  if (!activeAfter) {
    const licInfo = await api('GET', '/license', undefined, token).catch(() => null);
    const name = licInfo?.name ?? 'không rõ';
    throw new Error(`Licence đã kích hoạt (${name}) nhưng custom_permission_rules chưa bật`);
  }
  console.log(`Licence đã kích hoạt (${(await api('GET', '/license', undefined, token)).name})`);
} else {
  console.log('Licence đã kích hoạt (bỏ qua)');
}

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

// ─── 3. Quyền Player policy (spec §3.3) ──────────────────────────────────────
// An toàn: tạo quyền mới trước, xoá cũ sau — nếu tạo thất bại thì quyền cũ vẫn còn.
// Batch POST trả về toàn bộ permissions (không chỉ permission vừa tạo), nên dùng
// oldPermissions.length làm số lượng cũ.
const self = { id: { _eq: '$CURRENT_USER' } };
const desiredPermissions = [
  {
    collection: 'drill_logs',
    action: 'create',
    fields: ['id', 'drill_id', 'date', 'score', 'attempts', 'notes'],
    permissions: {},
    validation: {},
  },
  {
    collection: 'drill_logs',
    action: 'read',
    fields: ['*'],
    permissions: { user_created: self },
  },
  {
    collection: 'directus_users',
    action: 'read',
    fields: ['id', 'first_name', 'email'],
    permissions: self,
  },
  {
    collection: 'directus_users',
    action: 'update',
    fields: ['first_name', 'email', 'password'],
    permissions: self,
  },
];

const oldPermissions = await api('GET', `/permissions?filter[policy][_eq]=${policy.id}&limit=-1`, undefined, token);
const oldCount = oldPermissions.length;
const newPerms = desiredPermissions.map((p) => ({ ...p, policy: policy.id }));

// Tạo tất cả quyền mới trước (batch)
await api('POST', '/permissions', newPerms, token);

// Xoá quyền cũ
if (oldCount > 0) {
  await api('DELETE', '/permissions', oldPermissions.map((p) => p.id), token);
}

console.log(`Đặt ${newPerms.length} quyền cho Player policy (xoá ${oldCount} quyền cũ)`);

// ─── 4. Đăng ký công khai ───────────────────────────────────────────────────
await api('PATCH', '/settings', {
  project_name: 'PoolCoachAI',
  public_registration: true,
  public_registration_verify_email: false,
  public_registration_role: role.id,
  auth_password_policy: '/^.{8,}$/',
}, token);

console.log(`Xong. Role Player = ${role.id}, policy = ${policy.id}`);
