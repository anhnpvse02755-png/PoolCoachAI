// Thông báo "Gợi ý tập mới" trên Chrome thật, một tài khoản thử, đồng hồ trang dời:
//   1) Trước khi tải trang, dời Date của trang tới 07:55:00 hôm nay (giờ máy)
//      bằng Page.addScriptToEvaluateOnNewDocument; cấp quyền thông báo cho APP.
//   2) Trang Thông báo có 'Gợi ý tập mới', 'Đã gửi' và dòng trống của hộp Đã gửi.
//   3) Trang chủ có bài gợi ý; ghi một buổi tập cho bài đó để gợi ý của ngày đổi.
//   4) Qua 08:00 (đồng hồ dời): chuông đọc 'Thông báo, 1 chưa đọc', hộp Đã gửi
//      có 'Có gợi ý tập mới'; mở màn rồi quay lại thì chuông về 'Thông báo'.
//   Nếu Chrome chạy ngầm không cấp được quyền, chỉ kiểm màn hình (bước 2).
//
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/notifications.mjs <appUrl>
//
// Script tạo một user thử thật trên Directus và ghi dữ liệu thật, nên cần xác
// nhận rõ ràng như skill_test.mjs trước khi chạy. User thử và dòng của nó luôn
// được xoá ở finally, kể cả khi có bước nào đó ném lỗi.
//
// Mốc 07:55:00 thay vì 07:58:30: đăng ký user thử và vài lần tải trang có thể
// mất hơn một phút trên đồng hồ dời, nên cần chừa đủ trước 08:00. Bước chờ tính
// theo đồng hồ của trang, không theo giờ thật.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (name) =>
  process.env[name] ?? (() => { throw new Error(`Thiếu ${name}`); })();

if (process.env.PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1') {
  throw new Error(
    'Bài này ghi và xoá dữ liệu qua Directus thật (buổi tập, user thử). ' +
      'Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host';
const DIRECTUS_URL = need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const DIRECTUS = DIRECTUS_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-notifications');
const email = `e2e-notif-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (number, message) => console.log(`\n── Bước ${number}: ${message}`);

fs.rmSync(shots, { recursive: true, force: true });

// Đồng hồ trang: hôm nay 07:55:00 giờ máy. OFFSET tính một lần ở đây và nhúng
// vào mã tiêm, nên tải lại trang vẫn giữ cùng một độ lệch.
const target = new Date();
target.setHours(7, 55, 0, 0);
const OFFSET = target.getTime() - Date.now();
const CLOCK_SOURCE = `(() => {
  const OFFSET = ${OFFSET};
  const Real = Date;
  const realNow = Real.now.bind(Real);
  class Shifted extends Real {
    constructor(...args) {
      if (args.length === 0) super(realNow() + OFFSET);
      else super(...args);
    }
    static now() { return realNow() + OFFSET; }
  }
  window.Date = Shifted;
})();`;

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

/** Cuộn từng đoạn ngắn tới khi [needle] xuất hiện (danh sách lười), trả chữ trên màn. */
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

/** Tên bài và mục tiêu đọc từ seed_drills.dart (cùng repo): tên bài → số mục tiêu hoặc null. */
function seedDrills() {
  const file = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'lib', 'data', 'seed', 'seed_drills.dart');
  const src = fs.readFileSync(file, 'utf8');
  const out = new Map();
  const re = /name:\s*'([^']+)'[\s\S]*?(?:passThreshold:\s*[\d.]+|target:\s*(\d+))/g;
  for (const m of src.matchAll(re)) out.set(m[1], m[2] ? Number(m[2]) : null);
  return out;
}

/** Bài gợi ý trên Trang chủ: tên bài (đọc từ chữ trên màn) và mục tiêu nếu có. */
function homeDrill(text) {
  const drills = seedDrills();
  const start = text.indexOf('Bài tập gợi ý'); // Vi.homeDrillTitle
  const area = start >= 0 ? text.slice(start) : text;
  for (const [name, target] of drills) {
    if (area.includes(name)) return { name, target };
  }
  const bu = area.match(/[^\n]*— bậc [^\n]*/); // seed_drills.dart:194, bài BU sinh theo mẫu
  return bu ? { name: bu[0].trim(), target: null } : null;
}

/** Giây cho tới 08:00:00 trên đồng hồ trang (âm nếu đã qua). */
async function secondsTo0800() {
  const ms = await tab.eval(`(() => {
    const n = new Date(); const t = new Date(n); t.setHours(8, 0, 0, 0);
    return t.getTime() - n.getTime();
  })()`);
  return ms / 1000;
}

try {
  step(1, 'Dời đồng hồ trang và cấp quyền thông báo');
  tab = await launch({ port: 9353, name: 'notif' });
  await tab.send('Page.addScriptToEvaluateOnNewDocument', { source: CLOCK_SOURCE });
  let grantError = null;
  try {
    await tab.send('Browser.grantPermissions', { origin: APP, permissions: ['notifications'] });
  } catch (e) {
    grantError = e;
  }
  await tab.goto(`${APP}/`);
  const permission = await tab.eval('typeof Notification === "undefined" ? "unsupported" : Notification.permission');
  const granted = permission === 'granted';
  await check(
    Math.abs((await secondsTo0800()) - 300) < 120,
    'Đồng hồ trang đã dời tới khoảng 07:55 (còn gần 300 s tới 08:00)',
  );
  if (!granted) {
    console.log(
      `KHÔNG CẤP ĐƯỢC QUYỀN THÔNG BÁO TRONG CHROME CHẠY NGẦM — chỉ kiểm màn hình (quyền: ${permission}${grantError ? `, lỗi: ${grantError}` : ''})`,
    );
  }

  step(2, 'Tạo user thử; Trang chủ có bài gợi ý');
  await registerThrowaway(tab, APP, { email, password });
  await tab.goto(`${APP}/home`);
  await tab.waitForText('Bài tập gợi ý', 45000); // Vi.homeDrillTitle
  const drill = homeDrill(await scrollUntilText('Mở'));
  await check(drill != null, `Trang chủ: đọc được bài gợi ý (${drill?.name})`);

  step(3, 'Màn Thông báo: Gợi ý tập mới, Đã gửi, hộp trống');
  await tab.goto(`${APP}/notifications`);
  await tab.waitForText('Loại thông báo', 45000); // Vi.notificationsSettingsTitle
  if (granted && (await tab.text()).includes('Bật thông báo')) {
    await tab.click('Bật thông báo'); // Vi.equipmentReminderEnable
    await sleep(2000);
  }
  const screen = await scrollUntilText('Chưa có thông báo nào trong 30 ngày qua.');
  for (const piece of ['Gợi ý tập mới', 'Đã gửi', 'Chưa có thông báo nào trong 30 ngày qua.']) {
    await check(screen.includes(piece), `Màn Thông báo có "${piece}"`);
  }

  if (granted && drill) {
    step(4, 'Ghi một buổi tập cho bài gợi ý để gợi ý của ngày đổi sang cặp khác');
    await tab.goto(`${APP}/home`);
    await tab.waitForText('Bài tập gợi ý', 45000);
    await scrollUntilText('Mở');
    await tab.click('Mở'); // Vi.homeDrillOpen: chuyển sang tab Tập luyện, Trang chủ không còn hiện
    await tab.waitForText('Bắt đầu tập', 45000); // Vi.drillStartAction
    await tab.click('Bắt đầu tập');
    await tab.waitForText('Lưu kết quả', 45000); // Vi.sessionSaveAction
    const form = await tab.text();
    if (form.includes('Số lần thử')) { // Vi.sessionAttemptsLabel: bài chấm theo ngưỡng
      await tab.type('Số lần đạt', '10'); // Vi.sessionScoreLabelAttempts
      await tab.type('Số lần thử', '10');
    } else {
      await tab.type('Kết quả', String(drill.target ?? 1)); // Vi.sessionScoreLabelTarget
    }
    await tab.click('Lưu kết quả');
    await tab.waitForText('Đã lưu'); // tiền tố của Vi.sessionSaved / sessionSavedRatio

    step(5, 'Qua 08:00 (đồng hồ trang) và tối đa 90 s cho bộ hẹn mỗi phút');
    const wait = await secondsTo0800();
    await check(wait > -60, `Còn ${Math.round(wait)} s tới 08:00 khi xong buổi tập (nếu âm sâu, gợi ý đã được tính trước)`);
    const deadline = Date.now() + Math.max(0, wait) * 1000 + 90_000;
    let bell = false;
    while (Date.now() < deadline && !bell) {
      bell = (await tab.text()).includes('Thông báo, 1 chưa đọc'); // Vi.notificationsBellTooltip(1)
      if (!bell) await sleep(3000);
    }
    await check(bell, 'Chuông đọc "Thông báo, 1 chưa đọc"');
    await tab.click('Thông báo, 1 chưa đọc');
    await tab.waitForText('Loại thông báo', 45000);
    const inbox = await scrollUntilText('Có gợi ý tập mới'); // Vi.recommendationReminderTitle
    await check(inbox.includes('Có gợi ý tập mới'), 'Đã gửi có "Có gợi ý tập mới"');
    await tab.eval('history.back()');
    await sleep(2500);
    const labels = await tab.labels();
    await check(
      labels.includes('Thông báo') && !labels.some((l) => l.includes('chưa đọc')),
      'Quay lại: chuông đọc "Thông báo", không còn chưa đọc',
    );
  }

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

/**
 * Xoá dòng của user thử bằng quyền admin trước khi xoá user: user_created chỉ
 * là khoá tham chiếu, xoá user không chắc kéo theo dòng. Không bao giờ ném.
 */
async function deleteUserRows(email) {
  try {
    const login = await fetch(`${DIRECTUS}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: process.env.DIRECTUS_ADMIN_EMAIL,
        password: process.env.DIRECTUS_ADMIN_PASSWORD,
      }),
    });
    const token = (await login.json())?.data?.access_token;
    if (!token) throw new Error('Không đăng nhập được Directus admin');
    const found = await fetch(
      `${DIRECTUS}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    const id = (await found.json())?.data?.[0]?.id;
    if (!id) throw new Error('Không thấy user thử trên Directus');
    for (const collection of ['drill_logs', 'timer_sessions', 'schedule_slots', 'player_goals', 'achievements', 'player_ranks']) {
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
