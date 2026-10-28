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
const users = ['a', 'b'].map((n) => ({ email: `verify-${tag}-${n}@poolcoachai.example.com`, password: randomBytes(8).toString('hex') }));

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

  const short = await call('POST', '/users/register', { email: `verify-${tag}-c@poolcoachai.example.com`, password: '1234567' });
  short.status === 400 && short.code === 'FAILED_VALIDATION'
    ? ok('mật khẩu 7 ký tự bị từ chối → 400 FAILED_VALIDATION')
    : fail(`mật khẩu 7 ký tự → ${short.status} ${short.code} (cần 400 FAILED_VALIDATION)`);

  // ─── Quyền trên drill_logs ─────────────────────────────────────────────
  const logId = randomUUID();
  const log = { id: logId, drill_id: 'd1', date: '2026-09-23T03:00:00.000Z', score: 7, attempts: 10, notes: null, duration_sec: 300 };
  const created = await call('POST', '/items/drill_logs', log, a.access_token);
  created.status === 200 ? ok('A tạo được buổi tập') : fail(`A tạo buổi tập → ${created.status} ${created.code}`);

  const again = await call('POST', '/items/drill_logs', log, a.access_token);
  note(`gửi lại cùng id → status ${again.status}, code ${again.code}`);
  again.status >= 400 ? ok('gửi trùng id không tạo bản ghi thứ hai') : fail('gửi trùng id tạo được bản ghi thứ hai');

  const aList = await call('GET', '/items/drill_logs?fields=id,user_created', undefined, a.access_token);
  aList.data?.length === 1 ? ok('A đọc được đúng một buổi của mình') : fail(`A đọc được ${aList.data?.length} buổi`);
  const withDuration = await call('GET', `/items/drill_logs/${logId}?fields=id,duration_sec`, undefined, a.access_token);
  withDuration.data?.duration_sec === 300 ? ok('thời lượng Drill được lưu và đọc lại') : fail(`thời lượng Drill = ${withDuration.data?.duration_sec ?? '(thiếu)'}`);
  const bList = await call('GET', '/items/drill_logs', undefined, b.access_token);
  bList.data?.length === 0 ? ok('B không thấy buổi của A') : fail(`B thấy ${bList.data?.length} buổi`);
  const anon = await call('GET', '/items/drill_logs');
  anon.status === 403 || (anon.data ?? []).length === 0 ? ok(`không token → ${anon.status}`) : fail('không token vẫn đọc được');

  const patch = await call('PATCH', `/items/drill_logs/${logId}`, { score: 10 }, a.access_token);
  patch.status === 403 ? ok('A không sửa được buổi tập') : fail(`A sửa buổi tập → ${patch.status}`);
  const del = await call('DELETE', `/items/drill_logs/${logId}`, undefined, a.access_token);
  del.status === 403 ? ok('A không xoá được buổi tập') : fail(`A xoá buổi tập → ${del.status}`);

  // Additional checks beyond brief: B cannot read A's user record
  const adminUserA = await call('GET', `/users?filter[email][_eq]=${encodeURIComponent(users[0].email)}&fields=id`, undefined, admin.access_token);
  const aId = adminUserA.data?.[0]?.id;
  if (aId) {
    const bReadA = await call('GET', `/users/${aId}`, undefined, b.access_token);
    bReadA.status === 403 ? ok('B không đọc được record user của A') : fail(`B đọc user A → ${bReadA.status}`);
  } else {
    fail('không lấy được id của A từ admin');
  }

  // Forged user_created — try to create a drill log "owned" by B (id known from admin query)
  const adminUserB = await call('GET', `/users?filter[email][_eq]=${encodeURIComponent(users[1].email)}&fields=id`, undefined, admin.access_token);
  const bId = adminUserB.data?.[0]?.id;
  if (bId) {
    const forged = { id: randomUUID(), drill_id: 'd1', date: '2026-09-23T04:00:00.000Z', score: 5, attempts: 3, notes: null, user_created: bId };
    const forgedRes = await call('POST', '/items/drill_logs', forged, a.access_token);
    if (forgedRes.status === 403) {
      ok('server từ chối tạo với user_created giả mạo → 403');
    } else if (forgedRes.status === 200 || forgedRes.status === 201) {
      // Check who actually owns the record
      // Chỉ đạt khi chủ đúng là A. Chủ rỗng hay lạ cũng là hỏng: nghĩa là
      // server không tự gán người tạo, và quy tắc "chỉ thấy buổi của mình"
      // dựa trên user_created không còn đứng được.
      const checkOwner = await call('GET', `/items/drill_logs/${forged.id}?fields=id,user_created`, undefined, admin.access_token);
      const owner = checkOwner.data?.user_created;
      if (owner === bId) {
        fail('user_created giả mạo thành công — B sở hữu bản ghi');
      } else if (aId && owner === aId) {
        ok('server bỏ qua user_created, A sở hữu bản ghi');
      } else {
        fail(`server bỏ qua user_created nhưng chủ không phải A: user_created = ${owner ?? '(null)'}`);
      }
    } else {
      fail(`tạo với user_created giả mạo → ${forgedRes.status} ${forgedRes.code}`);
    }
  } else {
    fail('không lấy được id của B từ admin');
  }

  // ─── Đánh giá + hạng: player_ranks, bu_tests, bu_drill_results ──────────
  if (aId && bId) {
    const rank = { id: aId, rank: 'h', source: 'estimated', bu_score: null, test_id: null,
      warning_rank: null, warning_test_id: null, questionnaire_answers: [0, 0, 0, 2, 1, 0, 0, 0],
      onboarding_state: 'done', updated_at: '2026-10-14T03:00:00.000Z' };
    const made = await call('POST', '/items/player_ranks', rank, a.access_token);
    made.status === 200 ? ok('A tạo được dòng hạng của mình') : fail(`A tạo dòng hạng → ${made.status} ${made.code}`);
    const forgedRank = await call('POST', '/items/player_ranks', { ...rank, id: bId }, a.access_token);
    forgedRank.status >= 400 ? ok(`A không tạo được dòng hạng mang id của B → ${forgedRank.status}`) : fail('A tạo được dòng hạng mang id của B');
    const patched = await call('PATCH', `/items/player_ranks/${aId}`, { rank: 'g', updated_at: '2026-10-15T03:00:00.000Z' }, a.access_token);
    patched.status === 200 ? ok('A sửa được dòng hạng của mình') : fail(`A sửa dòng hạng → ${patched.status} ${patched.code}`);
    const bRanks = await call('GET', '/items/player_ranks', undefined, b.access_token);
    (bRanks.data ?? []).length === 0 ? ok('B không thấy hạng của A') : fail(`B thấy ${bRanks.data.length} dòng hạng`);
    const bPatch = await call('PATCH', `/items/player_ranks/${aId}`, { rank: 'a' }, b.access_token);
    bPatch.status === 403 ? ok('B không sửa được hạng của A') : fail(`B sửa hạng của A → ${bPatch.status}`);

    const testId = randomUUID();
    const buTest = { id: testId, started_at: '2026-10-14T02:00:00.000Z', completed_at: '2026-10-14T04:00:00.000Z',
      cancelled_at: null, table_size: 'nineFootPlus', exam_i_score: 60, exam_ii_version: 'masters',
      exam_ii_score: 77, total_score: 137, result_rank: 'd' };
    const tMade = await call('POST', '/items/bu_tests', buTest, a.access_token);
    tMade.status === 200 ? ok('A tạo được lần kiểm tra') : fail(`A tạo lần kiểm tra → ${tMade.status} ${tMade.code}`);
    const tAgain = await call('POST', '/items/bu_tests', buTest, a.access_token);
    note(`gửi lại lần kiểm tra cùng id → status ${tAgain.status}, code ${tAgain.code}`);
    const tPatch = await call('PATCH', `/items/bu_tests/${testId}`, { total_score: 200 }, a.access_token);
    tPatch.status === 403 ? ok('A không sửa được lần kiểm tra đã gửi') : fail(`A sửa lần kiểm tra → ${tPatch.status}`);
    const rMade = await call('POST', '/items/bu_drill_results', { id: randomUUID(), test_id: testId, drill_id: 'S10',
      attempts: { breaks: [[true, true, false, true, false]] }, score: null, recorded_at: '2026-10-14T03:30:00.000Z' }, a.access_token);
    rMade.status === 200 ? ok('A tạo được kết quả bài') : fail(`A tạo kết quả bài → ${rMade.status} ${rMade.code}`);
    const rList = await call('GET', '/items/bu_drill_results?fields=attempts', undefined, a.access_token);
    typeof rList.data?.[0]?.attempts === 'object' ? ok('attempts về dạng JSON, không phải chuỗi') : fail(`attempts về dạng ${typeof rList.data?.[0]?.attempts}`);
    const bTests = await call('GET', '/items/bu_tests', undefined, b.access_token);
    (bTests.data ?? []).length === 0 ? ok('B không thấy lần kiểm tra của A') : fail(`B thấy ${bTests.data.length} lần kiểm tra`);
  } else {
    fail('thiếu id của A hoặc B, bỏ qua phần hạng');
  }

  // ─── Lộ trình: player_goals, achievements ───────────────────────────────
  if (aId && bId) {
    const goal = {
      id: aId,
      goal_id: randomUUID(),
      kind: 'thuanThucKyNang',
      category: 'safety',
      event_date: null,
      created_at: '2026-10-15T03:00:00.000Z',
      updated_at: '2026-10-15T03:00:00.000Z',
    };
    const gMade = await call('POST', '/items/player_goals', goal, a.access_token);
    gMade.status === 200
      ? ok('A tạo được mục tiêu của mình')
      : fail(`A tạo mục tiêu → ${gMade.status} ${gMade.code}`);
    const gForged = await call(
      'POST',
      '/items/player_goals',
      { ...goal, id: bId },
      a.access_token,
    );
    gForged.status >= 400
      ? ok(`A không tạo được mục tiêu mang id của B → ${gForged.status}`)
      : fail('A tạo được mục tiêu mang id của B');
    const gRank = await call(
      'PATCH',
      `/items/player_goals/${aId}`,
      {
        kind: 'lenHang',
        category: null,
        target_rank: 'd',
        updated_at: '2026-10-16T02:00:00.000Z',
      },
      a.access_token,
    );
    gRank.status === 200
      ? ok('A đặt được hạng đích cho mục tiêu Lên hạng')
      : fail(`A đặt hạng đích → ${gRank.status} ${gRank.code}`);
    const gRankBack = await call(
      'GET',
      `/items/player_goals/${aId}?fields=target_rank`,
      undefined,
      a.access_token,
    );
    gRankBack.data?.target_rank === 'd'
      ? ok('A đọc lại được hạng đích')
      : fail(`A đọc hạng đích → ${JSON.stringify(gRankBack.data)}`);
    const gDropped = await call(
      'PATCH',
      `/items/player_goals/${aId}`,
      {
        goal_id: null,
        kind: null,
        category: null,
        created_at: null,
        updated_at: '2026-10-16T03:00:00.000Z',
      },
      a.access_token,
    );
    gDropped.status === 200
      ? ok('A bỏ được mục tiêu (dòng rỗng)')
      : fail(`A bỏ mục tiêu → ${gDropped.status} ${gDropped.code}`);
    const bGoals = await call('GET', '/items/player_goals', undefined, b.access_token);
    (bGoals.data ?? []).length === 0
      ? ok('B không thấy mục tiêu của A')
      : fail(`B thấy ${bGoals.data.length} mục tiêu`);
    const bGoalPatch = await call(
      'PATCH',
      `/items/player_goals/${aId}`,
      { kind: 'lenHang' },
      b.access_token,
    );
    bGoalPatch.status === 403
      ? ok('B không sửa được mục tiêu của A')
      : fail(`B sửa mục tiêu của A → ${bGoalPatch.status}`);

    // ─── Equipment: đồng bộ theo chủ sở hữu, xóa bằng tombstone ─────────
    const cueId = randomUUID();
    const cue = {
      id: cueId,
      name: 'Cơ kiểm thử',
      type: 'breakJump',
      weight_grams: 540,
      shaft_brand: 'Predator',
      tip_diameter_mm: 12.5,
      tip_brand: 'Kamui',
      tip_hardness: 'medium',
      butt_brand: 'Cuetec',
      skill_categories: ['aiming'],
      last_tip_maintenance: '2026-10-01',
      tip_maintenance_due_date: '2026-12-01',
      updated_at: '2026-10-20T03:00:00.000Z',
      is_deleted: false,
    };
    const cueMade = await call('POST', '/items/cue_equipment', cue, a.access_token);
    cueMade.status === 200 || cueMade.status === 201
      ? ok('A tạo được hồ sơ cơ')
      : fail(`A tạo hồ sơ cơ → ${cueMade.status} ${cueMade.code}`);
    const cueOwner = await call(
      'GET',
      `/items/cue_equipment/${cueId}?fields=id,user_created`,
      undefined,
      admin.access_token,
    );
    cueOwner.data?.user_created === aId
      ? ok('server gán chủ hồ sơ cơ là A')
      : fail(`chủ hồ sơ cơ không phải A: ${cueOwner.data?.user_created ?? '(null)'}`);
    const cueFields = await call(
      'GET',
      `/items/cue_equipment/${cueId}?fields=type,shaft_brand,tip_brand,butt_brand,tip_diameter_mm`,
      undefined,
      a.access_token,
    );
    cueFields.data?.type === 'breakJump' &&
    cueFields.data?.shaft_brand === 'Predator' &&
    cueFields.data?.tip_brand === 'Kamui' &&
    cueFields.data?.butt_brand === 'Cuetec'
      ? ok('hồ sơ cơ lưu đủ loại breakJump và hãng ngọn/đầu tẩy/chuôi')
      : fail(`trường cơ mới không đủ: ${JSON.stringify(cueFields.data)}`);
    const aCues = await call(
      'GET',
      '/items/cue_equipment?fields=id,user_created',
      undefined,
      a.access_token,
    );
    aCues.data?.length === 1
      ? ok('A đọc được hồ sơ cơ của mình')
      : fail(`A đọc được ${aCues.data?.length} hồ sơ cơ`);
    const bCues = await call('GET', '/items/cue_equipment', undefined, b.access_token);
    (bCues.data ?? []).length === 0
      ? ok('B không thấy hồ sơ cơ của A')
      : fail(`B thấy ${bCues.data.length} hồ sơ cơ`);
    const cuePatch = await call(
      'PATCH',
      `/items/cue_equipment/${cueId}`,
      { name: 'Cơ đã sửa', updated_at: '2026-10-21T03:00:00.000Z' },
      a.access_token,
    );
    cuePatch.status === 200
      ? ok('A cập nhật được hồ sơ cơ của mình')
      : fail(`A cập nhật hồ sơ cơ → ${cuePatch.status} ${cuePatch.code}`);
    const bCuePatch = await call(
      'PATCH',
      `/items/cue_equipment/${cueId}`,
      { name: 'Ghi đè' },
      b.access_token,
    );
    bCuePatch.status === 403
      ? ok('B không sửa được hồ sơ cơ của A')
      : fail(`B sửa hồ sơ cơ của A → ${bCuePatch.status}`);
    const cueDeleted = await call(
      'PATCH',
      `/items/cue_equipment/${cueId}`,
      { is_deleted: true, updated_at: '2026-10-22T03:00:00.000Z' },
      a.access_token,
    );
    cueDeleted.status === 200
      ? ok('A xóa mềm hồ sơ cơ bằng tombstone')
      : fail(`A xóa mềm hồ sơ cơ → ${cueDeleted.status} ${cueDeleted.code}`);
    const cueHardDelete = await call(
      'DELETE',
      `/items/cue_equipment/${cueId}`,
      undefined,
      a.access_token,
    );
    cueHardDelete.status === 403
      ? ok('A không xóa cứng hồ sơ cơ')
      : fail(`A xóa cứng hồ sơ cơ → ${cueHardDelete.status}`);

    // ─── Trận đấu, buổi tập tự do, lịch tập ─────────────────────────────
    const matchId = randomUUID();
    const matchBody = {
      id: matchId,
      game_type: 'nineBall',
      player_name: 'An',
      opponent_name: 'Bình',
      target_racks: 3,
      rack_winners: ['player'],
      shots: [],
      cue_id: randomUUID(),
      started_at: '2026-10-21T08:00:00.000Z',
      completed_at: null,
      updated_at: '2026-10-21T08:05:00.000Z',
      is_deleted: false,
    };
    const mMade = await call('POST', '/items/pool_matches', matchBody, a.access_token);
    mMade.status === 200 || mMade.status === 201
      ? ok('A tạo được trận đấu')
      : fail(`A tạo trận → ${mMade.status} ${mMade.code}`);
    const mOwner = await call(
      'GET',
      `/items/pool_matches/${matchId}?fields=id,user_created,rack_winners,cue_id`,
      undefined,
      admin.access_token,
    );
    mOwner.data?.user_created === aId && Array.isArray(mOwner.data?.rack_winners)
      ? ok('server gán chủ trận là A, rack_winners về dạng JSON')
      : fail(`chủ/định dạng trận sai: ${JSON.stringify(mOwner.data)}`);
    const bMatches = await call('GET', '/items/pool_matches', undefined, b.access_token);
    (bMatches.data ?? []).length === 0
      ? ok('B không thấy trận của A')
      : fail(`B thấy ${bMatches.data.length} trận`);
    const mPatch = await call(
      'PATCH',
      `/items/pool_matches/${matchId}`,
      { rack_winners: ['player', 'player'], updated_at: '2026-10-21T08:10:00.000Z' },
      a.access_token,
    );
    mPatch.status === 200
      ? ok('A cập nhật được trận của mình')
      : fail(`A cập nhật trận → ${mPatch.status} ${mPatch.code}`);
    const mTomb = await call(
      'PATCH',
      `/items/pool_matches/${matchId}`,
      { is_deleted: true, updated_at: '2026-10-21T08:20:00.000Z' },
      a.access_token,
    );
    mTomb.status === 200
      ? ok('A xóa mềm được trận bằng is_deleted')
      : fail(`A xóa mềm trận → ${mTomb.status} ${mTomb.code}`);
    const mTombRead = await call(
      'GET',
      `/items/pool_matches/${matchId}?fields=id,is_deleted`,
      undefined,
      a.access_token,
    );
    mTombRead.data?.is_deleted === true
      ? ok('tombstone của trận được lưu (is_deleted = true)')
      : fail(`tombstone trận sai: ${JSON.stringify(mTombRead.data)}`);
    const bMatchPatch = await call(
      'PATCH',
      `/items/pool_matches/${matchId}`,
      { player_name: 'Ghi đè' },
      b.access_token,
    );
    bMatchPatch.status === 403
      ? ok('B không sửa được trận của A')
      : fail(`B sửa trận của A → ${bMatchPatch.status}`);
    const mDelete = await call('DELETE', `/items/pool_matches/${matchId}`, undefined, a.access_token);
    mDelete.status === 403
      ? ok('A không xóa cứng trận')
      : fail(`A xóa cứng trận → ${mDelete.status}`);

    const timer = {
      id: randomUUID(),
      date: '2026-10-21T07:00:00.000Z',
      duration_sec: 900,
      cat: 'aiming',
      cue_id: null,
    };
    const tMade = await call('POST', '/items/timer_sessions', timer, a.access_token);
    tMade.status === 200 || tMade.status === 201
      ? ok('A tạo được buổi tập tự do')
      : fail(`A tạo buổi tập tự do → ${tMade.status} ${tMade.code}`);
    const tAgain = await call('POST', '/items/timer_sessions', timer, a.access_token);
    tAgain.code === 'RECORD_NOT_UNIQUE'
      ? ok('gửi lại buổi tập cùng id → RECORD_NOT_UNIQUE (app coi là đã đồng bộ)')
      : fail(`gửi lại buổi tập → ${tAgain.status} ${tAgain.code}`);
    const tPatch = await call(
      'PATCH',
      `/items/timer_sessions/${timer.id}`,
      { duration_sec: 1 },
      a.access_token,
    );
    tPatch.status === 403
      ? ok('A không sửa được buổi tập tự do')
      : fail(`A sửa buổi tập tự do → ${tPatch.status}`);
    const bTimers = await call('GET', '/items/timer_sessions', undefined, b.access_token);
    (bTimers.data ?? []).length === 0
      ? ok('B không thấy buổi tập tự do của A')
      : fail(`B thấy ${bTimers.data.length} buổi tập tự do`);

    const slot = {
      id: randomUUID(),
      day: 2,
      time: '19:00',
      label: 'Tập ngắm',
      cat: 'aiming',
      updated_at: '2026-10-21T08:00:00.000Z',
      is_deleted: false,
    };
    const sMade = await call('POST', '/items/schedule_slots', slot, a.access_token);
    sMade.status === 200 || sMade.status === 201
      ? ok('A tạo được khung lịch tập')
      : fail(`A tạo lịch tập → ${sMade.status} ${sMade.code}`);
    const sTomb = await call(
      'PATCH',
      `/items/schedule_slots/${slot.id}`,
      { is_deleted: true, updated_at: '2026-10-21T09:00:00.000Z' },
      a.access_token,
    );
    sTomb.status === 200
      ? ok('A xóa mềm khung lịch bằng tombstone')
      : fail(`A xóa mềm lịch → ${sTomb.status} ${sTomb.code}`);
    const sHard = await call('DELETE', `/items/schedule_slots/${slot.id}`, undefined, a.access_token);
    sHard.status === 403
      ? ok('A không xóa cứng khung lịch')
      : fail(`A xóa cứng lịch → ${sHard.status}`);
    const bSlots = await call('GET', '/items/schedule_slots', undefined, b.access_token);
    (bSlots.data ?? []).length === 0
      ? ok('B không thấy lịch tập của A')
      : fail(`B thấy ${bSlots.data.length} khung lịch`);

    const ach = {
      id: randomUUID(),
      kind: 'chuoiNgay',
      ref_id: '7',
      achieved_at: '2026-10-15T03:00:00.000Z',
    };
    const aMade = await call('POST', '/items/achievements', ach, a.access_token);
    aMade.status === 200
      ? ok('A tạo được thành tích')
      : fail(`A tạo thành tích → ${aMade.status} ${aMade.code}`);
    const aAgain = await call('POST', '/items/achievements', ach, a.access_token);
    aAgain.code === 'RECORD_NOT_UNIQUE'
      ? ok('gửi lại thành tích cùng id → RECORD_NOT_UNIQUE (app coi là đã đồng bộ)')
      : fail(`gửi lại thành tích cùng id → ${aAgain.status} ${aAgain.code}`);
    const aPatch = await call(
      'PATCH',
      `/items/achievements/${ach.id}`,
      { ref_id: '100' },
      a.access_token,
    );
    aPatch.status === 403
      ? ok('A không sửa được thành tích')
      : fail(`A sửa thành tích → ${aPatch.status}`);
    const bAch = await call('GET', '/items/achievements', undefined, b.access_token);
    (bAch.data ?? []).length === 0
      ? ok('B không thấy thành tích của A')
      : fail(`B thấy ${bAch.data.length} thành tích`);
  } else {
    fail('thiếu id của A hoặc B, bỏ qua phần Lộ trình');
  }

  // ─── Coach tình huống: coach_attempts (spec 2026-10-21 mục 11.4) ─────────
  if (aId && bId) {
    const attempt = {
      id: randomUUID(),
      situation_key: 'lib:pos-rail-1',
      topic: 'position',
      difficulty: 'easy',
      answers: [{ kind: 'pot', pocket: 'bottomMiddle', stroke: 'stun', power: 45, outcome: 'best' }],
      outcome: 'solved1',
      first_fault: null,
      scoring_version: 1,
      started_at: '2026-10-21T03:00:00.000Z',
      finished_at: '2026-10-21T03:01:00.000Z',
    };
    const cMade = await call('POST', '/items/coach_attempts', attempt, a.access_token);
    cMade.status === 200
      ? ok('A tạo được lần làm Coach')
      : fail(`A tạo lần làm Coach → ${cMade.status} ${cMade.code}`);
    const cAgain = await call('POST', '/items/coach_attempts', attempt, a.access_token);
    cAgain.code === 'RECORD_NOT_UNIQUE'
      ? ok('gửi lại lần làm cùng id → RECORD_NOT_UNIQUE (app coi là đã đồng bộ)')
      : fail(`gửi lại lần làm cùng id → ${cAgain.status} ${cAgain.code}`);
    const cList = await call('GET', '/items/coach_attempts', undefined, a.access_token);
    Array.isArray(cList.data?.[0]?.answers)
      ? ok('answers về dạng JSON, không phải chuỗi')
      : fail(`answers về dạng ${typeof cList.data?.[0]?.answers}`);
    const cPatch = await call(
      'PATCH',
      `/items/coach_attempts/${attempt.id}`,
      { outcome: 'revealed' },
      a.access_token,
    );
    cPatch.status === 403
      ? ok('A không sửa được lần làm Coach')
      : fail(`A sửa lần làm Coach → ${cPatch.status}`);
    const cDelete = await call('DELETE', `/items/coach_attempts/${attempt.id}`, undefined, a.access_token);
    cDelete.status === 403
      ? ok('A không xoá được lần làm Coach')
      : fail(`A xoá lần làm Coach → ${cDelete.status}`);
    const bCoach = await call('GET', '/items/coach_attempts', undefined, b.access_token);
    (bCoach.data ?? []).length === 0
      ? ok('B không thấy lần làm Coach của A')
      : fail(`B thấy ${bCoach.data.length} lần làm Coach`);
  } else {
    fail('thiếu id của A hoặc B, bỏ qua phần Coach');
  }

  // ─── Coach chat usage: role CoachChatService, user dịch vụ, quyền ───────
  const serviceRole = (await call('GET', '/roles?filter[name][_eq]=CoachChatService', undefined, admin.access_token)).data?.[0];
  serviceRole?.id ? ok('tìm thấy role CoachChatService') : fail('không tìm thấy role CoachChatService');

  if (serviceRole?.id && aId) {
    const svcEmail = `verify-${tag}-svc@poolcoachai.example.com`;
    const svcToken = randomBytes(24).toString('hex');
    const svcCreated = await call('POST', '/users', {
      email: svcEmail,
      role: serviceRole.id,
      status: 'active',
      token: svcToken,
    }, admin.access_token);
    svcCreated.status === 200 || svcCreated.status === 201
      ? ok('admin tạo được user dịch vụ tạm để kiểm thử')
      : fail(`tạo user dịch vụ tạm → ${svcCreated.status} ${svcCreated.code}`);

    const usageRow = {
      id: `${aId}_2000-01-01`,
      user: aId,
      day: '2000-01-01',
      questions: 1,
      input_tokens: 0,
      output_tokens: 0,
      cache_read_tokens: 0,
    };
    const uMade = await call('POST', '/items/coach_chat_usage', usageRow, svcToken);
    uMade.status === 200
      ? ok('dịch vụ tạo được dòng coach_chat_usage')
      : fail(`dịch vụ tạo dòng coach_chat_usage → ${uMade.status} ${uMade.code}`);

    const uAgain = await call('POST', '/items/coach_chat_usage', usageRow, svcToken);
    uAgain.code === 'RECORD_NOT_UNIQUE'
      ? ok('dịch vụ gửi lại cùng id → RECORD_NOT_UNIQUE')
      : fail(`dịch vụ gửi lại cùng id → ${uAgain.status} ${uAgain.code}`);

    const uList = await call(
      'GET',
      `/items/coach_chat_usage?filter[id][_eq]=${encodeURIComponent(usageRow.id)}`,
      undefined,
      svcToken,
    );
    uList.data?.length === 1
      ? ok('dịch vụ đọc được đúng một dòng coach_chat_usage')
      : fail(`dịch vụ đọc được ${uList.data?.length} dòng coach_chat_usage`);

    const uPatch = await call('PATCH', `/items/coach_chat_usage/${usageRow.id}`, { questions: 2 }, svcToken);
    uPatch.status === 200
      ? ok('dịch vụ sửa được dòng coach_chat_usage')
      : fail(`dịch vụ sửa dòng coach_chat_usage → ${uPatch.status} ${uPatch.code}`);

    const uDelete = await call('DELETE', `/items/coach_chat_usage/${usageRow.id}`, undefined, svcToken);
    uDelete.status === 403
      ? ok('dịch vụ không xoá được dòng coach_chat_usage')
      : fail(`dịch vụ xoá dòng coach_chat_usage → ${uDelete.status}`);

    const uDrill = await call('GET', '/items/drill_logs', undefined, svcToken);
    uDrill.status === 403
      ? ok('dịch vụ không đọc được drill_logs')
      : fail(`dịch vụ đọc drill_logs → ${uDrill.status}`);

    // Player A không có quyền gì trên coach_chat_usage.
    const aUsageGet = await call('GET', '/items/coach_chat_usage', undefined, a.access_token);
    aUsageGet.status === 403
      ? ok('A không đọc được coach_chat_usage')
      : fail(`A đọc coach_chat_usage → ${aUsageGet.status}`);
    const aUsagePost = await call(
      'POST',
      '/items/coach_chat_usage',
      { ...usageRow, id: `${aId}_2000-01-02` },
      a.access_token,
    );
    aUsagePost.status === 403
      ? ok('A không tạo được dòng coach_chat_usage')
      : fail(`A tạo dòng coach_chat_usage → ${aUsagePost.status}`);
    const aUsagePatch = await call(
      'PATCH',
      `/items/coach_chat_usage/${usageRow.id}`,
      { questions: 9 },
      a.access_token,
    );
    aUsagePatch.status === 403
      ? ok('A không sửa được coach_chat_usage')
      : fail(`A sửa coach_chat_usage → ${aUsagePatch.status}`);
  } else {
    fail('thiếu role CoachChatService hoặc id của A, bỏ qua phần coach_chat_usage');
  }

  // User dịch vụ coach-chat thật (không phải user tạm ở trên) phải có role
  // CoachChatService và một token tĩnh (không log giá trị token).
  const realService = (await call(
    'GET',
    `/users?filter[email][_eq]=${encodeURIComponent('coach-chat-service@poolcoachai.example.com')}&fields=token,role.name`,
    undefined,
    admin.access_token,
  )).data?.[0];
  realService?.role?.name === 'CoachChatService' && realService?.token
    ? ok('user dịch vụ coach-chat thật có role CoachChatService và có token')
    : fail(`user dịch vụ coach-chat thật: role=${realService?.role?.name ?? '(không có)'}, token=${realService?.token ? 'có' : 'không có'}`);

  const adminRole = (await call('GET', '/roles?filter[name][_eq]=Administrator', undefined, admin.access_token)).data?.[0]?.id;
  await call('PATCH', '/users/me', { role: adminRole }, a.access_token);
  const roleAfter = await roleOf(users[0].email);
  roleAfter === 'Player' ? ok('A không tự nâng role được') : fail(`A đổi role thành ${roleAfter}`);

  // ─── Giả định 2 và 3: đặt lại mật khẩu ─────────────────────────────────
  const req = await call('POST', '/auth/password/request', { email: users[0].email, reset_url: RESET_URL });
  req.status === 204 || req.status === 200 ? ok('yêu cầu đặt lại mật khẩu được nhận') : fail(`yêu cầu đặt lại → ${req.status} ${req.code}`);
  const unknown = await call('POST', '/auth/password/request', { email: `khong-co-${tag}@poolcoachai.example.com`, reset_url: RESET_URL });
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
  // Dọn user thử; CASCADE xoá luôn buổi tập của họ (và user dịch vụ tạm, nếu có).
  const ids = (await call('GET', `/users?filter[email][_starts_with]=verify-${tag}&fields=id`, undefined, admin.access_token)).data.map((u) => u.id);
  if (ids.length) await call('DELETE', '/users', ids, admin.access_token);

  // Xoá user A (chủ dòng coach_chat_usage) phải CASCADE xoá luôn dòng đó.
  const usageAfter = await call('GET', '/items/coach_chat_usage?filter[day][_eq]=2000-01-01', undefined, admin.access_token);
  (usageAfter.data ?? []).length === 0
    ? ok('xoá user kéo theo xoá dòng coach_chat_usage (CASCADE theo trường user)')
    : fail(`còn ${usageAfter.data?.length} dòng coach_chat_usage sau khi xoá user — CASCADE chưa đúng`);
}

console.log(failures ? `\n${failures} kiểm tra hỏng` : '\nTất cả kiểm tra đều qua');
process.exit(failures ? 1 : 0);
