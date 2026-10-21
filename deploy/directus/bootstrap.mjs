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
// Trả cả licence đã đọc để dòng log dùng lại, không gọi GET /license thêm lần nữa.
async function customPermissionRules() {
  try {
    const licence = await api('GET', '/license', undefined, token);
    const ok = licence?.status === 'active'
      && licence?.entitlements?.custom_permission_rules_enabled?.default === true;
    return { ok, licence };
  } catch (e) {
    throw new Error(`Kiểm tra licence thất bại → ${e.message}`);
  }
}

const licenseKey = process.env.DIRECTUS_LICENSE_KEY;
const before = await customPermissionRules();
if (!before.ok && !licenseKey) {
  console.error(
    'Server chưa có licence OIG và DIRECTUS_LICENSE_KEY không được đặt. ' +
      'Đặt DIRECTUS_LICENSE_KEY (khoá Open Innovation Grant) rồi chạy lại. ' +
      'Chưa tạo gì trên server.',
  );
  process.exit(1);
}
if (!before.ok) {
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
  const after = await customPermissionRules();
  const name = after.licence?.name ?? 'không rõ';
  if (!after.ok) {
    throw new Error(`Licence đã kích hoạt (${name}) nhưng custom_permission_rules chưa bật`);
  }
  console.log(`Licence đã kích hoạt (${name})`);
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

// ─── 1b. Đánh giá + hạng (spec 2026-10-14 mục 6.2) ─────────────────────────
// player_ranks: mỗi tài khoản một dòng, id = id người dùng (D9 của kế hoạch).
// bu_tests, bu_drill_results: chỉ thêm — app chỉ đẩy lần đã xong.
const ownerFields = [
  { field: 'user_created', type: 'uuid', meta: { special: ['user-created'], readonly: true, hidden: true }, schema: {} },
  { field: 'date_created', type: 'timestamp', meta: { special: ['date-created'], readonly: true, hidden: true }, schema: {} },
];

async function exists(path) {
  // Directus trả 403 (không phải 404) cho thứ chưa có, để không lộ tên.
  return api('GET', path, undefined, token).then(
    () => true,
    (e) => (e.status === 403 || e.status === 404 ? false : Promise.reject(e)),
  );
}

// Mỗi trường mang sẵn meta có `collection` và `field`. Directus tự thêm cờ
// (vd. cờ ngày giờ cho trường timestamp) vào meta SAU bước tự điền
// collection/field; trường gửi lên không có meta thì meta mới đó thiếu hai
// khoá này và POST /collections trả 400 "Validation failed for field
// collection / field" (lần chạy 14/10/2026).
const withMeta = (name, f) => ({
  ...f,
  collection: name,
  meta: { ...(f.meta ?? {}), collection: name, field: f.field },
});

async function ensureCollection(name, note, fields) {
  const all = [...fields, ...ownerFields].map((f) => withMeta(name, f));
  if (!(await exists(`/collections/${name}`))) {
    await api('POST', '/collections', {
      collection: name,
      meta: { icon: 'military_tech', note },
      schema: {},
      fields: all,
    }, token);
    console.log(`Tạo collection ${name}`);
  } else {
    // Collection có từ lần chạy trước mà thiếu trường (lần đó hỏng giữa
    // chừng, hoặc file này thêm trường mới): bù từng trường còn thiếu.
    for (const f of all) {
      if (!(await exists(`/fields/${name}/${f.field}`))) {
        await api('POST', `/fields/${name}`, f, token);
        console.log(`Thêm trường ${name}.${f.field}`);
      }
    }
  }
  if (!(await exists(`/relations/${name}/user_created`))) {
    // Xoá người dùng thì xoá luôn hạng và bài kiểm tra của họ.
    await api('POST', '/relations', {
      collection: name,
      field: 'user_created',
      related_collection: 'directus_users',
      schema: { on_delete: 'CASCADE' },
    }, token);
    console.log(`Tạo quan hệ ${name}.user_created → directus_users`);
  }
}

const nullable = (field, type) => ({ field, type, schema: { is_nullable: true } });
const required = (field, type) => ({ field, type, schema: { is_nullable: false } });
const pk = { field: 'id', type: 'uuid', schema: { is_primary_key: true, is_nullable: false } };

await ensureCollection('player_ranks', 'Hạng người chơi PoolCoachAI — mỗi tài khoản một dòng, id = id người dùng', [
  pk,
  nullable('rank', 'string'),
  nullable('source', 'string'),
  nullable('bu_score', 'integer'),
  nullable('test_id', 'uuid'),
  nullable('warning_rank', 'string'),
  nullable('warning_test_id', 'uuid'),
  nullable('questionnaire_answers', 'json'),
  required('onboarding_state', 'string'),
  required('updated_at', 'timestamp'),
]);
await ensureCollection('bu_tests', 'Lần kiểm tra Billiard University đã xong (hoàn tất hoặc hủy)', [
  pk,
  required('started_at', 'timestamp'),
  nullable('completed_at', 'timestamp'),
  nullable('cancelled_at', 'timestamp'),
  required('table_size', 'string'),
  nullable('exam_i_score', 'integer'),
  nullable('exam_ii_version', 'string'),
  nullable('exam_ii_score', 'integer'),
  nullable('total_score', 'integer'),
  nullable('result_rank', 'string'),
]);
await ensureCollection('bu_drill_results', 'Kết quả thô từng bài của một lần kiểm tra BU', [
  pk,
  required('test_id', 'uuid'),
  required('drill_id', 'string'),
  required('attempts', 'json'),
  nullable('score', 'integer'),
  required('recorded_at', 'timestamp'),
]);

// ─── 1c. Lộ trình (spec 2026-10-15 mục 6) ─────────────────────────────────
// player_goals: mỗi tài khoản một dòng, id = id người dùng; bỏ mục tiêu thì
// kind rỗng. achievements: chỉ thêm; id tính từ (người, loại, ref_id).
await ensureCollection(
  'player_goals',
  'Mục tiêu Lộ trình — mỗi tài khoản một dòng, id = id người dùng',
  [
    pk,
    nullable('goal_id', 'uuid'),
    nullable('kind', 'string'),
    nullable('category', 'string'),
    nullable('event_date', 'timestamp'),
    nullable('created_at', 'timestamp'),
    required('updated_at', 'timestamp'),
  ],
);
await ensureCollection('achievements', 'Thành tích Lộ trình — chỉ thêm', [
  pk,
  required('kind', 'string'),
  required('ref_id', 'string'),
  required('achieved_at', 'timestamp'),
]);

// Equipment dùng updated_at/is_deleted để đồng bộ và xóa mềm đa thiết bị.
await ensureCollection('cue_equipment', 'Hồ sơ cơ và lịch bảo dưỡng của người chơi', [
  pk,
  required('name', 'string'),
  required('type', 'string'),
  nullable('weight_grams', 'integer'),
  nullable('shaft_brand', 'string'),
  // Size ngọn (đường kính ngọn, mm). Giữ tên trường cũ để không phải đổi tên trên server.
  nullable('tip_diameter_mm', 'decimal'),
  nullable('tip_brand', 'string'),
  nullable('tip_hardness', 'string'),
  nullable('butt_brand', 'string'),
  required('skill_categories', 'json'),
  nullable('last_tip_maintenance', 'date'),
  nullable('tip_maintenance_due_date', 'date'),
  required('updated_at', 'timestamp'),
  required('is_deleted', 'boolean'),
]);

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
  // Hạng: tạo đúng một dòng của chính mình, đọc và sửa dòng của mình.
  {
    collection: 'player_ranks',
    action: 'create',
    fields: ['id', 'rank', 'source', 'bu_score', 'test_id', 'warning_rank', 'warning_test_id',
      'questionnaire_answers', 'onboarding_state', 'updated_at'],
    permissions: {},
    validation: { id: { _eq: '$CURRENT_USER' } },
  },
  { collection: 'player_ranks', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'player_ranks',
    action: 'update',
    fields: ['rank', 'source', 'bu_score', 'test_id', 'warning_rank', 'warning_test_id',
      'questionnaire_answers', 'onboarding_state', 'updated_at'],
    permissions: { user_created: self },
    validation: {},
  },
  // Bài kiểm tra và kết quả: chỉ thêm, không sửa, không xoá.
  {
    collection: 'bu_tests',
    action: 'create',
    fields: ['id', 'started_at', 'completed_at', 'cancelled_at', 'table_size', 'exam_i_score',
      'exam_ii_version', 'exam_ii_score', 'total_score', 'result_rank'],
    permissions: {},
    validation: {},
  },
  { collection: 'bu_tests', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'bu_drill_results',
    action: 'create',
    fields: ['id', 'test_id', 'drill_id', 'attempts', 'score', 'recorded_at'],
    permissions: {},
    validation: {},
  },
  { collection: 'bu_drill_results', action: 'read', fields: ['*'], permissions: { user_created: self } },
  // Mục tiêu: tạo đúng một dòng của chính mình, đọc và sửa dòng của mình.
  {
    collection: 'player_goals',
    action: 'create',
    fields: ['id', 'goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at'],
    permissions: {},
    validation: { id: { _eq: '$CURRENT_USER' } },
  },
  { collection: 'player_goals', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'player_goals',
    action: 'update',
    fields: ['goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at'],
    permissions: { user_created: self },
    validation: {},
  },
  // Thành tích: chỉ thêm, không sửa, không xoá.
  {
    collection: 'achievements',
    action: 'create',
    fields: ['id', 'kind', 'ref_id', 'achieved_at'],
    permissions: {},
    validation: {},
  },
  { collection: 'achievements', action: 'read', fields: ['*'], permissions: { user_created: self } },
  // Equipment: đồng bộ CRUD theo quyền sở hữu; xóa chỉ bằng tombstone.
  {
    collection: 'cue_equipment',
    action: 'create',
    fields: [
      'id', 'name', 'type', 'weight_grams', 'shaft_brand', 'tip_diameter_mm',
      'tip_brand', 'tip_hardness', 'butt_brand',
      'skill_categories', 'last_tip_maintenance', 'tip_maintenance_due_date',
      'updated_at', 'is_deleted',
    ],
    permissions: {},
    validation: {},
  },
  {
    collection: 'cue_equipment',
    action: 'read',
    fields: ['*'],
    permissions: { user_created: self },
  },
  {
    collection: 'cue_equipment',
    action: 'update',
    fields: [
      'name', 'type', 'weight_grams', 'shaft_brand', 'tip_diameter_mm',
      'tip_brand', 'tip_hardness', 'butt_brand',
      'skill_categories', 'last_tip_maintenance', 'tip_maintenance_due_date',
      'updated_at', 'is_deleted',
    ],
    permissions: { user_created: self },
    validation: {},
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
