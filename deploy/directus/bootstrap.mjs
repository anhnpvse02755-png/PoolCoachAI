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
      { field: 'duration_sec', type: 'integer', schema: { is_nullable: true } },
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

const hasDrillDuration = await api(
  'GET',
  '/fields/drill_logs/duration_sec',
  undefined,
  token,
).then(
  () => true,
  (e) => (e.status === 403 || e.status === 404 ? false : Promise.reject(e)),
);
if (!hasDrillDuration) {
  await api('POST', '/fields/drill_logs', {
    field: 'duration_sec',
    type: 'integer',
    schema: { is_nullable: true },
  }, token);
  console.log('Tạo trường drill_logs.duration_sec');
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

async function ensureUserRelation(collection, field) {
  if (!(await exists(`/relations/${collection}/${field}`))) {
    // Xoá người dùng thì xoá luôn dữ liệu của họ (CASCADE).
    await api('POST', '/relations', {
      collection,
      field,
      related_collection: 'directus_users',
      schema: { on_delete: 'CASCADE' },
    }, token);
    console.log(`Tạo quan hệ ${collection}.${field} → directus_users`);
  }
}

async function ensureCollection(name, note, fields, { owned = true } = {}) {
  const all = (owned ? [...fields, ...ownerFields] : fields).map((f) => withMeta(name, f));
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
  // owned = false: collection không có user_created (vd. coach_chat_usage,
  // nơi quan hệ tới người dùng là trường `user` do ensureUserRelation riêng lo).
  if (owned) {
    await ensureUserRelation(name, 'user_created');
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
    nullable('target_rank', 'string'),
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

// ─── 1d. Coach tình huống (spec 2026-10-21 mục 11.4) ───────────────────────
// coach_attempts: chỉ thêm, mỗi lần làm tình huống một dòng. Chỉ có câu trả
// lời của người chơi, không có đáp án; không đưa vào điểm thuần thục.
await ensureCollection('coach_attempts', 'Lần làm tình huống Coach — chỉ thêm', [
  pk,
  required('situation_key', 'string'),
  required('topic', 'string'),
  required('difficulty', 'string'),
  required('answers', 'json'),
  required('outcome', 'string'),
  nullable('first_fault', 'string'),
  required('scoring_version', 'integer'),
  required('started_at', 'timestamp'),
  required('finished_at', 'timestamp'),
]);

// ─── 1e. Coach chat usage (spec 2026-10-22, Coach Phase B) ─────────────────
// coach_chat_usage: đếm lượt hỏi và token mỗi người mỗi ngày, id = `${user}_${day}`.
// Chỉ dịch vụ coach-chat (role CoachChatService) đọc/ghi; Player không có quyền
// gì trên collection này — owned: false vì chủ bản ghi không phải người tạo ra
// nó (dịch vụ tạo thay người chơi), nên không có user_created/CASCADE theo kiểu
// thường mà có quan hệ CASCADE riêng theo trường `user`.
await ensureCollection('coach_chat_usage', 'Lượt hỏi Coach Chat mỗi ngày — chỉ dịch vụ coach-chat ghi', [
  { field: 'id', type: 'string', schema: { is_primary_key: true, is_nullable: false, max_length: 64 } },
  required('user', 'uuid'),
  required('day', 'string'),
  required('questions', 'integer'),
  required('input_tokens', 'integer'),
  required('output_tokens', 'integer'),
  required('cache_read_tokens', 'integer'),
], { owned: false });
await ensureUserRelation('coach_chat_usage', 'user');

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

// Trận đấu (kèm rack và cú đánh như app lưu), buổi tập tự do và lịch tập tuần.
// pool_matches và schedule_slots: bản sửa mới nhất thắng (updated_at); trận và
// lịch xóa bằng tombstone (is_deleted). timer_sessions: chỉ thêm. cue_id là chuỗi thường, không phải
// quan hệ: trận và buổi tập giữ cue_id cả khi cơ đã bị xóa mềm.
await ensureCollection('pool_matches', 'Trận đấu của người chơi, gồm rack và cú đánh', [
  pk,
  required('game_type', 'string'),
  required('player_name', 'string'),
  required('opponent_name', 'string'),
  required('target_racks', 'integer'),
  required('rack_winners', 'json'),
  required('shots', 'json'),
  nullable('cue_id', 'string'),
  required('started_at', 'timestamp'),
  nullable('completed_at', 'timestamp'),
  required('updated_at', 'timestamp'),
  // Có default false vì bảng đã có trận trên server: thêm cột NOT NULL không
  // default vào bảng có dữ liệu sẽ lỗi trên Postgres.
  { field: 'is_deleted', type: 'boolean', schema: { is_nullable: false, default_value: false } },
]);
await ensureCollection('timer_sessions', 'Buổi tập tự do đo bằng đồng hồ — chỉ thêm', [
  pk,
  required('date', 'timestamp'),
  required('duration_sec', 'integer'),
  nullable('cat', 'string'),
  nullable('cue_id', 'string'),
]);
await ensureCollection('schedule_slots', 'Khung giờ trong lịch tập hằng tuần', [
  pk,
  required('day', 'integer'),
  required('time', 'string'),
  required('label', 'string'),
  nullable('cat', 'string'),
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

// An toàn: tạo quyền mới trước, xoá cũ sau — nếu tạo thất bại thì quyền cũ vẫn còn.
// Batch POST trả về toàn bộ permissions (không chỉ permission vừa tạo), nên dùng
// oldPermissions.length làm số lượng cũ.
async function replacePermissions(policyId, desired) {
  const oldPermissions = await api('GET', `/permissions?filter[policy][_eq]=${policyId}&limit=-1`, undefined, token);
  const newPerms = desired.map((p) => ({ ...p, policy: policyId }));
  await api('POST', '/permissions', newPerms, token);
  if (oldPermissions.length > 0) {
    await api('DELETE', '/permissions', oldPermissions.map((p) => p.id), token);
  }
  return { newCount: newPerms.length, oldCount: oldPermissions.length };
}

// ─── 3. Quyền Player policy (spec §3.3) ──────────────────────────────────────
const self = { id: { _eq: '$CURRENT_USER' } };
const desiredPermissions = [
  {
    collection: 'drill_logs',
    action: 'create',
    fields: ['id', 'drill_id', 'date', 'score', 'attempts', 'notes', 'duration_sec'],
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
    fields: ['id', 'goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at', 'target_rank'],
    permissions: {},
    validation: { id: { _eq: '$CURRENT_USER' } },
  },
  { collection: 'player_goals', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'player_goals',
    action: 'update',
    fields: ['goal_id', 'kind', 'category', 'event_date', 'created_at', 'updated_at', 'target_rank'],
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
  // Lần làm Coach: chỉ thêm, không sửa, không xoá; chỉ đọc của mình.
  {
    collection: 'coach_attempts',
    action: 'create',
    fields: ['id', 'situation_key', 'topic', 'difficulty', 'answers', 'outcome', 'first_fault',
      'scoring_version', 'started_at', 'finished_at'],
    permissions: {},
    validation: {},
  },
  { collection: 'coach_attempts', action: 'read', fields: ['*'], permissions: { user_created: self } },
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
  // Trận đấu: sửa được (rack, cú đánh); xóa chỉ bằng tombstone is_deleted.
  {
    collection: 'pool_matches',
    action: 'create',
    fields: ['id', 'game_type', 'player_name', 'opponent_name', 'target_racks', 'rack_winners',
      'shots', 'cue_id', 'started_at', 'completed_at', 'updated_at', 'is_deleted'],
    permissions: {},
    validation: {},
  },
  { collection: 'pool_matches', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'pool_matches',
    action: 'update',
    fields: ['game_type', 'player_name', 'opponent_name', 'target_racks', 'rack_winners',
      'shots', 'cue_id', 'started_at', 'completed_at', 'updated_at', 'is_deleted'],
    permissions: { user_created: self },
    validation: {},
  },
  // Buổi tập tự do: chỉ thêm, không sửa, không xoá.
  {
    collection: 'timer_sessions',
    action: 'create',
    fields: ['id', 'date', 'duration_sec', 'cat', 'cue_id'],
    permissions: {},
    validation: {},
  },
  { collection: 'timer_sessions', action: 'read', fields: ['*'], permissions: { user_created: self } },
  // Lịch tập: xoá chỉ bằng tombstone.
  {
    collection: 'schedule_slots',
    action: 'create',
    fields: ['id', 'day', 'time', 'label', 'cat', 'updated_at', 'is_deleted'],
    permissions: {},
    validation: {},
  },
  { collection: 'schedule_slots', action: 'read', fields: ['*'], permissions: { user_created: self } },
  {
    collection: 'schedule_slots',
    action: 'update',
    fields: ['day', 'time', 'label', 'cat', 'updated_at', 'is_deleted'],
    permissions: { user_created: self },
    validation: {},
  },
];

{
  const { newCount, oldCount } = await replacePermissions(policy.id, desiredPermissions);
  console.log(`Đặt ${newCount} quyền cho Player policy (xoá ${oldCount} quyền cũ)`);
}

// ─── 3b. Role CoachChatService và quyền trên coach_chat_usage ─────────────
// server/coach-chat (Node) ghi/đọc coach_chat_usage bằng token tĩnh của một
// user riêng, không phải token người chơi. Player không có quyền gì trên
// collection này (kiểm ở verify.mjs: Player → 403 trên GET/POST/PATCH).
const serviceRole = await findOrCreate('/roles', 'CoachChatService', {
  name: 'CoachChatService',
  icon: 'smart_toy',
  description: 'Dịch vụ coach-chat (server/coach-chat) — chỉ đọc/ghi coach_chat_usage',
});
const servicePolicy = await findOrCreate('/policies', 'CoachChatService', {
  name: 'CoachChatService',
  icon: 'smart_toy',
  admin_access: false,
  app_access: false,
  description: 'Quyền của dịch vụ coach-chat trên coach_chat_usage',
});
const serviceLinks = await api(
  'GET',
  `/access?filter[role][_eq]=${serviceRole.id}&filter[policy][_eq]=${servicePolicy.id}`,
  undefined,
  token,
);
if (!serviceLinks.length) {
  await api('POST', '/access', { role: serviceRole.id, policy: servicePolicy.id }, token);
}

{
  const { newCount, oldCount } = await replacePermissions(servicePolicy.id, [
    {
      collection: 'coach_chat_usage',
      action: 'create',
      fields: ['id', 'user', 'day', 'questions', 'input_tokens', 'output_tokens', 'cache_read_tokens'],
      permissions: {},
      validation: {},
    },
    { collection: 'coach_chat_usage', action: 'read', fields: ['*'], permissions: {} },
    {
      collection: 'coach_chat_usage',
      action: 'update',
      fields: ['questions', 'input_tokens', 'output_tokens', 'cache_read_tokens'],
      permissions: {},
      validation: {},
    },
  ]);
  console.log(`Đặt ${newCount} quyền cho CoachChatService policy (xoá ${oldCount} quyền cũ)`);
}

// Người dùng dịch vụ coach-chat: email cố định, token tĩnh đặt qua
// COACH_CHAT_SERVICE_TOKEN (tuỳ chọn — R9). Không bao giờ in token ra log.
const serviceEmail = 'coach-chat-service@poolcoachai.example.com';
const serviceToken = process.env.COACH_CHAT_SERVICE_TOKEN;
const existingServiceUsers = await api(
  'GET',
  `/users?filter[email][_eq]=${encodeURIComponent(serviceEmail)}&fields=id`,
  undefined,
  token,
);
const existingServiceUser = existingServiceUsers[0] ?? null;
if (!existingServiceUser) {
  await api('POST', '/users', {
    email: serviceEmail,
    role: serviceRole.id,
    status: 'active',
    first_name: 'coach-chat',
    ...(serviceToken ? { token: serviceToken } : {}),
  }, token);
  console.log(`Tạo người dùng dịch vụ ${serviceEmail}`);
} else if (serviceToken) {
  await api('PATCH', `/users/${existingServiceUser.id}`, { token: serviceToken, role: serviceRole.id }, token);
  console.log(`Cập nhật token và role người dùng dịch vụ ${serviceEmail}`);
} else {
  console.log(`Người dùng dịch vụ ${serviceEmail} đã có (bỏ qua — không đặt COACH_CHAT_SERVICE_TOKEN)`);
}
if (!serviceToken) {
  console.log('NOTE người dùng dịch vụ coach-chat chưa có token — chạy lại với COACH_CHAT_SERVICE_TOKEN');
}

// ─── 4. Đăng ký công khai ───────────────────────────────────────────────────
await api('PATCH', '/settings', {
  project_name: 'PoolCoachAI',
  public_registration: true,
  public_registration_verify_email: false,
  public_registration_role: role.id,
  auth_password_policy: '/^.{8,}$/',
}, token);

console.log(`Xong. Role Player = ${role.id}, policy = ${policy.id}`);
