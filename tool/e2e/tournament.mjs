// Giải đấu trên Chrome thật, một tài khoản thử:
//   1) Thẻ Giải đấu ở Thi đấu báo chưa có giải; thêm một giải đang diễn ra.
//   2) Mở giải, bắt đầu trận trong giải (Tứ kết, chạm 3 ván), thắng 3 ván.
//   3) Màn chi tiết giải hiện tổng kết đúng từ trận vừa ghi.
//   4) Thêm giải sắp tới qua Directus REST bằng chính user thử, thấy nó sau
//      khi tải lại, bấm Chuẩn bị cho giải này, Lộ trình có tên giải.
//   5) Directus (quyền admin): tournaments, pool_matches, player_goals khớp.
//
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/tournament.mjs <appUrl>
//
// Script tạo một user thử thật trên Directus và ghi dữ liệu thật, nên cần xác
// nhận rõ ràng như skill_test.mjs trước khi chạy. User thử và dòng của nó luôn
// được xoá ở finally, kể cả khi có bước nào đó ném lỗi.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomBytes, randomUUID } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (name) =>
  process.env[name] ?? (() => { throw new Error(`Thiếu ${name}`); })();

if (process.env.PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1') {
  throw new Error(
    'Bài này ghi và xoá dữ liệu qua Directus thật (giải đấu, trận, mục tiêu, user thử). ' +
      'Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host';
const DIRECTUS_URL = need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const DIRECTUS = DIRECTUS_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-tournament');
const email = `e2e-tour-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const NAME = 'Giải E2E ' + Date.now();
const UP = 'Cúp E2E ' + Date.now();
const step = (number, message) => console.log(`\n── Bước ${number}: ${message}`);
const ymd = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

fs.rmSync(shots, { recursive: true, force: true });

let failed = 0;
let tab;
async function check(ok, what) {
  console.log(`${ok ? 'ĐẠT ' : 'HỎNG'}  ${what}`);
  if (!ok) {
    failed++;
    try {
      await tab?.shot(path.join(shots, `fail-${failed}.png`));
    } catch (shotError) {
      console.warn(`  (không chụp được ảnh lỗi: ${shotError})`);
    }
  }
}

/**
 * Danh sách ListView lười: mục ở xa chưa được dựng nên chưa có node semantics.
 * Cuộn từng đoạn ngắn (không nhảy hẳn xuống cuối, kẻo mục bị gỡ) tới khi
 * [needle] xuất hiện, rồi trả về chữ trên màn.
 */
async function scrollUntilText(needle, maxSteps = 14) {
  let text = await tab.text();
  for (let i = 0; i < maxSteps && !text.includes(needle); i++) {
    await tab.eval(`(() => {
      for (const e of document.querySelectorAll('flt-semantics')) {
        if (e.scrollHeight > e.clientHeight + 1) e.scrollTop += Math.max(200, Math.floor(e.clientHeight * 0.6));
      }
    })()`);
    await sleep(1000);
    text = await tab.text();
  }
  return text;
}

async function directusAdminToken() {
  const res = await fetch(`${DIRECTUS}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: process.env.DIRECTUS_ADMIN_EMAIL,
      password: process.env.DIRECTUS_ADMIN_PASSWORD,
    }),
  });
  const body = await res.json();
  const token = body?.data?.access_token;
  if (!token) {
    throw new Error('Không đăng nhập được Directus admin — kiểm tra DIRECTUS_ADMIN_EMAIL / DIRECTUS_ADMIN_PASSWORD.');
  }
  return token;
}

async function directusUserId(token) {
  const res = await fetch(
    `${DIRECTUS}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const body = await res.json();
  const id = body?.data?.[0]?.id;
  if (!id) throw new Error('Không thấy user thử trên Directus khi tra theo email (quyền admin).');
  return id;
}

/**
 * Đợi đồng bộ máy → Directus: có dòng đầu tiên rồi còn đợi số dòng đứng yên
 * [stableMs] (mặc định 5 s) để bắt được dòng gửi trùng, tối đa [timeoutMs].
 */
async function waitRows(token, userId, collection, fields, ready, timeoutMs = 60000, stableMs = 5000) {
  const end = Date.now() + timeoutMs;
  let rows = [];
  let stableSince = null;
  let lastCount = -1;
  while (Date.now() < end) {
    const res = await fetch(
      `${DIRECTUS}/items/${collection}?filter[user_created][_eq]=${encodeURIComponent(userId)}&fields=${fields}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    rows = (await res.json())?.data ?? [];
    if (ready(rows)) {
      if (rows.length !== lastCount) {
        lastCount = rows.length;
        stableSince = Date.now();
      } else if (Date.now() - stableSince >= stableMs) {
        return rows;
      }
    } else {
      lastCount = -1;
      stableSince = null;
    }
    await sleep(1500);
  }
  return rows;
}

/**
 * Xoá dòng của user thử bằng quyền admin trước khi xoá user: user_created chỉ
 * là khoá tham chiếu, xoá user không chắc kéo theo dòng. Không bao giờ ném.
 */
async function deleteUserRows(email) {
  try {
    const token = await directusAdminToken();
    const id = await directusUserId(token);
    for (const collection of ['tournaments', 'pool_matches', 'player_goals', 'achievements', 'player_ranks']) {
      try {
        const res = await fetch(`${DIRECTUS}/items/${collection}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ query: { filter: { user_created: { _eq: id } } } }),
        });
        if (!res.ok) console.warn(`Cảnh báo: xoá ${collection} → ${res.status}`);
      } catch (e) {
        console.warn(`Cảnh báo: không xoá được dòng ${collection}: ${e}`);
      }
    }
  } catch (e) {
    console.warn(`Cảnh báo: không dọn được dòng của ${email}: ${e}`);
  }
}

try {
  step(1, 'Tạo user thử và đăng nhập (registerThrowaway)');
  tab = await launch({ port: 9352, name: 'tour' });
  await registerThrowaway(tab, APP, { email, password });

  step(2, 'Thi đấu chưa có giải; thêm một giải đang diễn ra');
  await tab.goto(`${APP}/play`);
  await tab.waitForText('Chưa có giải nào'); // Vi.tournamentNone
  await tab.goto(`${APP}/play/tournaments`);
  await tab.click('Thêm giải');
  await tab.type('Tên giải', NAME);
  await tab.type('Thành tích (không bắt buộc)', 'Vào vòng 16');
  await tab.click('Lưu giải');
  await tab.waitForText(NAME);

  step(3, 'Bắt đầu trận Tứ kết trong giải, thắng 3 ván');
  await tab.click(NAME);
  await tab.waitForText('Tổng kết'); // chỉ có ở màn chi tiết (danh sách cũng có 'Đang diễn ra')
  await tab.click('Bắt đầu trận trong giải');
  await tab.type('Tên của bạn', 'An');
  await tab.type('Tên đối thủ', 'Bình');
  await tab.click('Chạm 5 ván thắng');
  await tab.click('Chạm 3 ván thắng');
  await tab.click('Tứ kết');
  await tab.click('Bắt đầu trận');
  await tab.waitForText(`${NAME} · Tứ kết`);
  for (let i = 0; i < 3; i++) {
    await tab.click('Tôi thắng ván');
    await sleep(800);
  }
  await tab.waitForText('Đã kết thúc');

  step(4, 'Chi tiết giải: tổng kết bám trận đã ghi');
  await tab.goto(`${APP}/play/tournaments`);
  await scrollUntilText(NAME);
  await tab.click(NAME);
  await tab.waitForText('Tỷ lệ ván thắng'); // chỉ ở chi tiết; dòng 'Thắng 1 – thua 0 trận' cũng có ở danh sách
  const detail = await scrollUntilText('Kết quả do bạn ghi');
  for (const piece of [
    'Thắng 1 – thua 0 trận',
    'Thắng 3 – thua 0 ván',
    'Tỷ lệ ván thắng: 100%',
    'Thành tích: Vào vòng 16',
    'Kết quả do bạn ghi',
  ]) {
    await check(detail.includes(piece), `Chi tiết giải có "${piece}"`);
  }

  step(5, 'Giải sắp tới qua Directus REST (user thử), chuẩn bị cho giải, Lộ trình');
  const loginRes = await fetch(`${DIRECTUS}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const userToken = (await loginRes.json())?.data?.access_token;
  if (!userToken) throw new Error('Không đăng nhập Directus bằng user thử.');
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const nowIso = new Date().toISOString();
  const postRes = await fetch(`${DIRECTUS}/items/tournaments`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: randomUUID(), name: UP, start_date: ymd(tomorrow), end_date: null, location: null,
      game_type: null, result_note: null, notes: null,
      created_at: nowIso, updated_at: nowIso, is_deleted: false,
    }),
  });
  await check(postRes.ok, `Directus: tạo giải sắp tới (HTTP ${postRes.status})`);
  await tab.reload();
  await tab.goto(`${APP}/play/tournaments`);
  const deadline = Date.now() + 45000;
  let lastReload = Date.now();
  let listText = await scrollUntilText(UP);
  while (!listText.includes(UP) && Date.now() < deadline) {
    if (Date.now() - lastReload >= 15000) {
      await tab.reload();
      await tab.goto(`${APP}/play/tournaments`);
      lastReload = Date.now();
    }
    await sleep(1500);
    listText = await scrollUntilText(UP);
  }
  await check(listText.includes(UP), `Danh sách giải có ${UP}`);
  await tab.click(UP);
  await tab.waitForText('Chuẩn bị cho giải này'); // nút chỉ có ở chi tiết ('Sắp tới' cũng là tiêu đề nhóm ở danh sách)
  await tab.click('Chuẩn bị cho giải này');
  await tab.waitForText('Đang chuẩn bị cho giải này');
  await tab.click('Mở Lộ trình');
  await tab.waitForText(`Chuẩn bị giải ${UP} — ngày `);
  await check(
    (await tab.text()).includes(`Chuẩn bị giải ${UP} — ngày `),
    `Lộ trình: tiêu đề "Chuẩn bị giải ${UP} — ngày …"`,
  );

  step(6, 'Directus (quyền admin): tournaments, pool_matches, player_goals');
  const adminToken = await directusAdminToken();
  const userId = await directusUserId(adminToken);
  const tours = await waitRows(
    adminToken, userId, 'tournaments', 'id,name,start_date,result_note,is_deleted',
    (rows) => rows.length >= 2,
  );
  await check(tours.length === 2, `Directus tournaments: đúng 2 dòng (thấy ${tours.length})`);
  const mine = tours.find((t) => t.name === NAME) ?? {};
  await check(
    mine.start_date === ymd(new Date()) && mine.result_note === 'Vào vòng 16',
    `Directus tournaments: ${NAME} start_date hôm nay, result_note 'Vào vòng 16' (thấy ${JSON.stringify(mine)})`,
  );
  await check(tours.every((t) => t.is_deleted === false), 'Directus tournaments: cả hai is_deleted=false');
  const upRow = tours.find((t) => t.name === UP) ?? {};

  const matches = await waitRows(
    adminToken, userId, 'pool_matches', 'tournament_id,round_label,rack_winners,completed_at',
    (rows) => rows.length >= 1,
  );
  await check(matches.length === 1, `Directus pool_matches: đúng 1 dòng (thấy ${matches.length})`);
  const m = matches[0] ?? {};
  await check(
    m.tournament_id === mine.id && m.round_label === 'Tứ kết' &&
      Array.isArray(m.rack_winners) && m.rack_winners.length === 3 &&
      m.rack_winners.every((w) => w === 'player') && m.completed_at != null,
    `Directus pool_matches: đúng giải, Tứ kết, 3 ván 'player', đã hoàn tất (thấy ${JSON.stringify(m)})`,
  );

  const goals = await waitRows(
    adminToken, userId, 'player_goals', 'kind,tournament_id,event_date',
    (rows) => rows.length >= 1,
  );
  const g = goals[0] ?? {};
  await check(
    goals.length === 1 && g.kind === 'chuanBiGiai' && g.tournament_id === upRow.id,
    `Directus player_goals: chuanBiGiai nối giải sắp tới (thấy ${JSON.stringify(goals)})`,
  );
  console.log(`\n${failed ? `HỎNG ${failed} kiểm tra.` : 'Xong, mọi kiểm tra đạt.'} Ảnh lỗi (nếu có) ở ${shots}`);
} catch (error) {
  failed++;
  console.error(`\nLỗi không bắt được: ${error?.stack ?? error}`);
  try {
    if (tab) await tab.shot(path.join(shots, 'fail-uncaught.png'));
  } catch (shotError) {
    console.warn(`  (không chụp được ảnh lỗi: ${shotError})`);
  }
} finally {
  try {
    if (tab) await tab.close();
  } catch (e) {
    console.warn(`Cảnh báo: không đóng được tab: ${e}`);
  }
  try {
    await deleteUserRows(email);
    await deleteUserByEmail(email);
  } catch (e) {
    console.warn(`Cảnh báo: dọn user thử lỗi: ${e}`);
  }
}
if (failed) process.exitCode = 1;
