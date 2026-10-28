// Nhóm bài nâng cao (Dựng cơ) trên Chrome thật, một tài khoản thử:
//   1) Tập luyện: cuộn dải chip sang ngang, bấm chip 'Dựng cơ' (chip thứ 8),
//      thấy 'Dựng cơ — bậc Bachelors'.
//   2) Chi tiết d11: dòng nguồn BU S8 Bachelors, dòng 'chưa có mẹo có nguồn',
//      nút 'Xem sơ đồ BU' mở đủ 3 sơ đồ (1 / 3 … 3 / 3).
//   3) Ghi buổi tập d11 với kết quả 3; Thống kê hiện nhóm Dựng cơ có 1 buổi chấm được.
//   4) Đồng hồ luyện tập: chọn nhóm Dựng cơ, bắt đầu, ~5 s, kết thúc và lưu.
//   5) Directus (quyền admin): drill_logs d11 score 3; timer_sessions với
//      cat null (trường cũ để trống vì bản đã phát hành không phân tích được
//      tên mới) và cat_ext 'dungCo'.
//
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/drill_groups.mjs <appUrl>
//
// Script tạo một user thử thật trên Directus và ghi dữ liệu thật, nên cần xác
// nhận rõ ràng như skill_test.mjs trước khi chạy. User thử luôn được xoá ở
// finally, kể cả khi có bước nào đó ném lỗi.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (name) =>
  process.env[name] ?? (() => { throw new Error(`Thiếu ${name}`); })();

if (process.env.PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1') {
  throw new Error(
    'Bài này ghi và xoá dữ liệu qua Directus thật (buổi tập, đồng hồ, user thử). ' +
      'Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host';
const DIRECTUS_URL = need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const DIRECTUS = DIRECTUS_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-drill-groups');
const email = `e2e-dg-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (number, message) => console.log(`\n── Bước ${number}: ${message}`);

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

/**
 * Dải chip lọc nhóm cuộn ngang: chip thứ 8 ('Dựng cơ') nằm ngoài màn 412 px
 * nên chưa có node semantics. Cuộn ngang từng đoạn tới khi có một node mà
 * nhãn đúng bằng [label], rồi để hàm click của tab bấm.
 */
async function scrollChipIntoView(label, maxSteps = 10) {
  const present = () => tab.eval(`(() => [...document.querySelectorAll('flt-semantics')]
    .some((e) => (e.getAttribute('aria-label') || e.textContent || '').trim() === ${JSON.stringify(label)}))()`);
  for (let i = 0; i < maxSteps && !(await present()); i++) {
    await tab.eval(`(() => {
      for (const e of document.querySelectorAll('flt-semantics')) {
        if (e.scrollWidth > e.clientWidth + 1) e.scrollLeft += Math.max(150, Math.floor(e.clientWidth * 0.6));
      }
    })()`);
    await sleep(1000);
  }
  return present();
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
async function waitRows(token, userId, collection, fields, ready, timeoutMs = 30000, stableMs = 5000) {
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
    for (const collection of [
      'drill_logs', 'timer_sessions', 'schedule_slots', 'cue_equipment',
      'player_goals', 'achievements', 'player_ranks', 'skill_tests',
      'tournaments', 'pool_matches',
    ]) {
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
  tab = await launch({ port: 9352, name: 'dg' });
  await registerThrowaway(tab, APP, { email, password });

  step(2, 'Tập luyện: chip Dựng cơ lọc ra bài bậc Bachelors');
  await tab.goto(`${APP}/training`);
  await tab.waitForText('Đồng hồ luyện tập', 45000); // Vi.timerTitle, thẻ có sẵn trên màn
  const chipFound = await scrollChipIntoView('Dựng cơ'); // Vi.skill(dungCo)
  await check(chipFound, 'Tập luyện: chip Dựng cơ hiện sau khi cuộn ngang');
  await tab.click('Dựng cơ');
  const filtered = await scrollUntilText('Dựng cơ — bậc Bachelors'); // seed_drills.dart:194
  await check(
    filtered.includes('Dựng cơ — bậc Bachelors'),
    'Tập luyện: thấy "Dựng cơ — bậc Bachelors"',
  );

  step(3, 'Chi tiết d11: nguồn, dòng chưa có mẹo có nguồn, sơ đồ BU');
  await tab.goto(`${APP}/training/drills/d11`);
  await tab.waitForText('Nguồn: Billiard University Exam II', 45000); // Vi.drillSource
  const detail = await scrollUntilText('Xem sơ đồ BU'); // Vi.drillOpenBuLayouts
  await check(
    detail.includes('Nguồn: Billiard University Exam II, S8, bậc Bachelors'),
    'Chi tiết d11: "Nguồn: Billiard University Exam II, S8, bậc Bachelors"',
  );
  await check(
    detail.includes('Chưa có mẹo kỹ thuật có nguồn cho dựng cơ.'), // Vi.drillNoSourcedTips
    'Chi tiết d11: "Chưa có mẹo kỹ thuật có nguồn cho dựng cơ."',
  );
  await tab.click('Xem sơ đồ BU');
  await tab.waitForText('Sơ đồ 1 / 3', 45000); // Vi.buLayoutCaption, chỉ có ở màn sơ đồ
  const gallery = await scrollUntilText('Sơ đồ 3 / 3');
  await check(gallery.includes('Sơ đồ 1 / 3'), 'Sơ đồ BU: có "Sơ đồ 1 / 3"');
  await check(gallery.includes('Sơ đồ 3 / 3'), 'Sơ đồ BU: có "Sơ đồ 3 / 3"');
  await check(!gallery.includes('Sơ đồ 4 / '), 'Sơ đồ BU: không có sơ đồ thứ 4');

  step(4, 'Ghi buổi tập d11 với kết quả 3 / 3');
  await tab.goto(`${APP}/training/drills/d11/session`);
  await tab.waitForText('Tập: ', 45000); // Vi.sessionTitle
  await tab.type('Kết quả', '3'); // Vi.sessionScoreLabelTarget
  await tab.click('Lưu kết quả'); // Vi.sessionSaveAction
  await tab.waitForText('Đã lưu'); // tiền tố của Vi.sessionSaved / sessionSavedRatio

  step(5, 'Thống kê: nhóm Dựng cơ có 1 buổi chấm được');
  await tab.goto(`${APP}/stats`);
  await tab.waitForText('Tiến bộ theo nhóm kỹ năng', 45000); // Vi.statsSkills
  const stats = await scrollUntilText('1 buổi có thể chấm'); // Vi.statsScoredSessions
  await check(stats.includes('Dựng cơ'), 'Thống kê: có dòng nhóm Dựng cơ');
  await check(
    stats.includes('1 buổi có thể chấm'),
    'Thống kê: nhóm Dựng cơ có "1 buổi có thể chấm"',
  );

  step(6, 'Đồng hồ luyện tập: chọn nhóm Dựng cơ, chạy ~5 s, kết thúc và lưu');
  await tab.goto(`${APP}/training/timer`);
  await tab.waitForText('Nhóm kỹ năng (không bắt buộc)', 45000); // Vi.timerChooseCategory
  await tab.click('Nhóm kỹ năng (không bắt buộc)');
  await tab.click('Dựng cơ'); // mục trong danh sách thả xuống: Vi.skill(dungCo)
  await tab.click('Bắt đầu'); // Vi.timerStart
  await tab.waitForText('Kết thúc và lưu'); // Vi.timerFinish, chỉ hiện khi đã chạy
  await sleep(5000);
  await tab.click('Kết thúc và lưu');
  await tab.waitForText('Đã lưu buổi tập'); // Vi.timerSaved

  step(7, 'Directus (quyền admin): drill_logs và timer_sessions của user thử');
  const adminToken = await directusAdminToken();
  const userId = await directusUserId(adminToken);
  const logs = await waitRows(
    adminToken, userId, 'drill_logs', 'drill_id,score',
    (rows) => rows.some((r) => r.drill_id === 'd11'),
  );
  const logRow = logs.find((r) => r.drill_id === 'd11') ?? {};
  await check(
    logs.length === 1 && Number(logRow.score) === 3,
    `Directus drill_logs: đúng 1 dòng d11, score 3 (thấy ${JSON.stringify(logs)})`,
  );
  const sessions = await waitRows(
    adminToken, userId, 'timer_sessions', 'duration_sec,cat,cat_ext',
    (rows) => rows.length >= 1,
  );
  await check(sessions.length === 1, `Directus timer_sessions: đúng 1 dòng (thấy ${sessions.length})`);
  const session = sessions[0] ?? {};
  await check(
    session.cat === null && session.cat_ext === 'dungCo',
    `Directus timer_sessions: cat null, cat_ext "dungCo" (thấy ${JSON.stringify(session)})`,
  );
  await check(
    Number(session.duration_sec) >= 4,
    `Directus timer_sessions: duration_sec >= 4 (thấy ${session.duration_sec})`,
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
  } finally {
    await deleteUserRows(email);
    await deleteUserByEmail(email);
  }
}
if (failed) process.exitCode = 1;
