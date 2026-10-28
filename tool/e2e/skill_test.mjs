// Skill Test (kiểm tra kỹ năng) trên Chrome thật, một tài khoản thử:
//   1) Ghi 3 buổi tập đạt bài d1 (Tập luyện → d1 → ghi kết quả).
//   2) Mở thẻ 'Làm bài kiểm tra' ở chi tiết bài d1, chọn bàn, bắt đầu, nhập
//      kết quả đạt, nộp, đọc 'Đã chứng nhận …'.
//   3) Hồ sơ hiện mục Chứng nhận với đúng bài; Tập luyện hiện huy hiệu.
//   4) Directus (quyền admin): đúng một dòng skill_tests của user này với
//      passed=true và ảnh chụp tiêu chí (pass_threshold), cùng achievements
//      kind 'chungNhan' ref_id 'd1'.
//
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/skill_test.mjs <appUrl>
//
// Script tạo một user thử thật trên Directus và ghi dữ liệu thật, nên cần xác
// nhận rõ ràng như match_drill_stats.mjs trước khi chạy. User thử luôn được
// xoá ở finally, kể cả khi có bước nào đó ném lỗi.
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
    'Bài này ghi và xoá dữ liệu qua Directus thật (buổi tập, bài kiểm tra, user thử). ' +
      'Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host';
const DIRECTUS_URL = need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const DIRECTUS = DIRECTUS_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-skill-test');
const email = `e2e-st-${Date.now()}@poolcoachai.example.com`;
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

/** Đợi tối đa [timeoutMs] vì đồng bộ máy → Directus có độ trễ. */
async function waitRows(token, userId, collection, fields, ready, timeoutMs = 60000) {
  const end = Date.now() + timeoutMs;
  let rows = [];
  while (Date.now() < end) {
    const res = await fetch(
      `${DIRECTUS}/items/${collection}?filter[user_created][_eq]=${encodeURIComponent(userId)}&fields=${fields}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    rows = (await res.json())?.data ?? [];
    if (ready(rows)) return rows;
    await sleep(1500);
  }
  return rows;
}

try {
  step(1, 'Tạo user thử và đăng nhập (registerThrowaway)');
  tab = await launch({ port: 9351, name: 'st' });
  await registerThrowaway(tab, APP, { email, password });

  step(2, 'Ghi 3 buổi tập đạt bài d1 (9/10, tiêu chí 80%)');
  for (let i = 0; i < 3; i++) {
    await tab.goto(`${APP}/training/drills/d1/session`);
    await tab.waitForText('Tập: '); // Vi.sessionTitle
    await tab.type('Số lần đạt', '9'); // Vi.sessionScoreLabelAttempts
    await tab.type('Số lần thử', '10'); // Vi.sessionAttemptsLabel
    await tab.click('Lưu kết quả'); // Vi.sessionSaveAction
    await tab.waitForText('Đã lưu'); // tiền tố của Vi.sessionSavedRatio
  }

  step(3, 'Mở thẻ Làm bài kiểm tra, bắt đầu, nhập kết quả đạt, nộp');
  await tab.goto(`${APP}/training/drills/d1`);
  await tab.waitForText('Làm bài kiểm tra', 45000); // Vi.skillTestOpen
  await tab.click('Làm bài kiểm tra');
  await tab.waitForText('Kiểm tra: Đường thẳng cơ bản'); // Vi.skillTestTitle(drill.name)
  await tab.click('8 feet'); // Vi.buTableSize(eightFoot)
  await tab.click('Bắt đầu kiểm tra'); // Vi.skillTestStart
  await tab.type('Số lần đạt', '9');
  await tab.type('Số lần thử', '10');
  await tab.click('Nộp kết quả'); // Vi.skillTestSubmit
  await tab.waitForText('Đã chứng nhận Đường thẳng cơ bản — cấp 1'); // Vi.skillTestPassed
  await check(
    (await tab.text()).includes('Đã chứng nhận Đường thẳng cơ bản — cấp 1'),
    'Kết quả: Đã chứng nhận Đường thẳng cơ bản — cấp 1',
  );

  step(4, 'Hồ sơ: mục Chứng nhận có bài vừa đạt');
  await tab.goto(`${APP}/profile`);
  const profileText = await scrollUntilText('Đường thẳng cơ bản — cấp 1 — ');
  await check(profileText.includes('Chứng nhận'), 'Hồ sơ: có mục Chứng nhận'); // Vi.certificationTitle
  await check(
    profileText.includes('Đường thẳng cơ bản — cấp 1 — '), // Vi.certificationEntry
    'Hồ sơ: dòng chứng nhận Đường thẳng cơ bản — cấp 1 — <ngày>',
  );

  step(5, 'Tập luyện: huy hiệu Đã chứng nhận');
  await tab.goto(`${APP}/training`);
  const trainingText = await scrollUntilText('Đã chứng nhận');
  await check(trainingText.includes('Đã chứng nhận'), 'Tập luyện: có huy hiệu Đã chứng nhận'); // Vi.certifiedBadge

  step(6, 'Directus (quyền admin): skill_tests và achievements của user thử');
  const adminToken = await directusAdminToken();
  const userId = await directusUserId(adminToken);
  const tests = await waitRows(
    adminToken, userId, 'skill_tests',
    'drill_id,drill_level,table_size,score,attempts,passed,pass_threshold,completed_at',
    (rows) => rows.length >= 1,
  );
  await check(tests.length === 1, `Directus skill_tests: đúng 1 dòng (thấy ${tests.length})`);
  const row = tests[0] ?? {};
  await check(
    row.drill_id === 'd1' && row.drill_level === 1 && row.table_size === 'eightFoot' &&
      row.passed === true && row.attempts === 10,
    `Directus skill_tests: d1, cấp 1, eightFoot, passed=true, attempts=10 (thấy ${JSON.stringify(row)})`,
  );
  await check(
    typeof row.pass_threshold === 'number' && row.pass_threshold > 0,
    `Directus skill_tests: ảnh chụp tiêu chí pass_threshold có giá trị (thấy ${row.pass_threshold})`,
  );
  const achievements = await waitRows(
    adminToken, userId, 'achievements', 'kind,ref_id',
    (rows) => rows.some((r) => r.kind === 'chungNhan'),
  );
  await check(
    achievements.some((r) => r.kind === 'chungNhan' && r.ref_id === 'd1'),
    `Directus achievements: có chungNhan / d1 (thấy ${JSON.stringify(achievements)})`,
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
    await deleteUserByEmail(email);
  }
}
if (failed) process.exitCode = 1;
