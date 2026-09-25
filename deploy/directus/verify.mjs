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
      const checkOwner = await call('GET', `/items/drill_logs/${forged.id}?fields=id,user_created`, undefined, admin.access_token);
      checkOwner.data?.user_created === bId
        ? fail('user_created giả mạo thành công — B sở hữu bản ghi')
        : checkOwner.data?.user_created === aId
        ? ok('server bỏ qua user_created, A sở hữu bản ghi')
        : ok(`server bỏ qua user_created, user_created = ${checkOwner.data?.user_created ?? '(null)'}`);
    } else {
      fail(`tạo với user_created giả mạo → ${forgedRes.status} ${forgedRes.code}`);
    }
  } else {
    fail('không lấy được id của B từ admin');
  }

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
  // Dọn user thử; CASCADE xoá luôn buổi tập của họ.
  const ids = (await call('GET', `/users?filter[email][_starts_with]=verify-${tag}&fields=id`, undefined, admin.access_token)).data.map((u) => u.id);
  if (ids.length) await call('DELETE', '/users', ids, admin.access_token);
}

console.log(failures ? `\n${failures} kiểm tra hỏng` : '\nTất cả kiểm tra đều qua');
process.exit(failures ? 1 : 0);
