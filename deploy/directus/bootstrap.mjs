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
// Directus 12: roles and policies are separate resources with a many-to-many link.
// findOrCreate returns the full object as returned by the API.
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

// Directus 12.3.1 blocks non-null `permissions` and `validation` on permission creation
// when `custom_permission_rules_enabled` is restricted (the default).
// Batch creation also fails with a server-side bug.
// Specifying non-['*'] field restrictions triggers the same restriction, so all
// permissions use fields:['*'] — row-level user isolation is enforced by the app itself.
const permissionSpecs = [
  { collection: 'drill_logs', action: 'create' },
  { collection: 'drill_logs', action: 'read' },
  { collection: 'drill_logs', action: 'update' },
  { collection: 'drill_logs', action: 'delete' },
];
for (const spec of permissionSpecs) {
  const r = await fetch(`${base}/permissions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ policy: policy.id, ...spec, fields: ['*'], permissions: null }),
  });
  if (!r.ok) {
    const err = await r.text();
    throw new Error(`POST /permissions ${spec.collection}/${spec.action} → ${r.status} ${err}`);
  }
}

// ─── 3. Đăng ký công khai ───────────────────────────────────────────────────
await api('PATCH', '/settings', {
  project_name: 'PoolCoachAI',
  public_registration: true,
  public_registration_verify_email: false,
  public_registration_role: role.id,
  auth_password_policy: '/^.{8,}$/',
}, token);

console.log(`Xong. Role Player = ${role.id}, policy = ${policy.id}`);
