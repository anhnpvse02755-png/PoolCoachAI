// Thi đấu + Drill + Thống kê trên Chrome thật, một tài khoản thử:
//   1) Thi đấu (lib/features/play/presentation/play_screen.dart): tạo trận A,
//      ghi 1 ván, sửa (đổi cả hai tên, NÂNG race-to — không bao giờ hạ, vì
//      dialog sửa trận chặn target < leaderWins), tải lại kiểm tra tên mới +
//      race-to mới + tỉ số đã ghi còn nguyên; tạo trận B rồi xoá qua hộp
//      thoại xác nhận, tải lại kiểm tra B mất hẳn mà A vẫn còn.
//   2) Drill (lib/features/training/presentation/drill_session_screen.dart):
//      mở một buổi tập bài d1, giữ mở ~6s rồi lưu; kiểm tra Thống kê thấy
//      thời lượng đã đo (xem lý do chỉ kiểm được ở đó, bên dưới); tải lại
//      trang chi tiết bài d1 kiểm tra buổi vẫn còn; rồi vào Directus bằng
//      quyền admin đọc đúng dòng drill_logs của user này (đợi tối đa ~30s để
//      đồng bộ) và kiểm tra duration_sec là số >= 4.
//   3) Thống kê (lib/features/stats/presentation/stats_screen.dart +
//      lib/domain/training_statistics.dart): mở /stats, đọc nhãn semantics
//      của đúng hôm nay trong biểu đồ tuần, kiểm tra phản ánh đúng 1 buổi tập
//      và ĐÚNG 1 trận — xem bước 9 dưới để biết vì sao phải là 1, không phải 2.
//   4) Phân tích trận (play_screen.dart + match_analysis_sheet.dart): trận C
//      race-to 3, ván 1 ghi đủ cú rồi mất ván; mở 'Phân tích trận' và đọc nguyên
//      nhân mất ván 'Mất 1 ván sau khi trượt cú tấn công'.
//   5) Lộ trình (goal_picker.dart): xác định hạng H, đặt mục tiêu Lên hạng F
//      (2 hạng), kiểm tra tiêu đề 'Lên hạng: H → F' và bước mốc hạng G trung gian.
//
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/match_drill_stats.mjs <appUrl>
//
// Script tạo một user thử thật trên Directus, ghi dữ liệu thật (trận, buổi
// tập) và đọc lại bằng quyền admin, nên cần xác nhận rõ ràng như Lộ trình
// (roadmap.mjs) trước khi chạy. User thử luôn được xoá ở finally, kể cả khi
// có bước nào đó ném lỗi.
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
    'Bài này ghi và xoá dữ liệu qua Directus thật (trận, buổi tập, user thử). ' +
      'Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host';
const DIRECTUS_URL = need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const DIRECTUS = DIRECTUS_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-match-drill-stats');
const email = `e2e-mds-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (number, message) => console.log(`\n── Bước ${number}: ${message}`);

// Tên trận dùng để phân biệt thẻ trận A/B và hộp thoại xác nhận xoá — không
// cái nào là tiền tố của cái khác, vì clickNear() tìm đúng nút bằng cách dò
// xem textContent của tổ tiên gần nhất có chứa tên này hay không.
const A_PLAYER = 'Mai E2E';
const A_OPPONENT = 'Lan E2E';
const A_PLAYER_EDITED = 'Hoa E2E';
const A_OPPONENT_EDITED = 'Tuan E2E';
const B_PLAYER = 'Nam E2E';
const B_OPPONENT = 'Son E2E';
const C_PLAYER = 'Cuc E2E';
const C_OPPONENT = 'Dung E2E';

// Bộ câu hỏi ra hạng H (cùng tool/e2e/rank.mjs, bước 2).
const TO_H = ['Chưa từng chơi', 'Dưới 2 giờ / tuần', '1', '1', 'Đã từng 1–2 lần', 'Chưa từng',
  'Thường không có bi đánh tiếp', 'Thường xuyên bị khó'];

// Ảnh của lượt trước nằm lẫn vào thì ảnh lỗi của lượt này không còn đúng.
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
 * Bấm node semantics khớp [label] mà node đó, hoặc tổ tiên gần nhất của nó,
 * có textContent chứa [nearText].
 *
 * cdp.mjs's click() chỉ ưu tiên role="button" rồi nhãn ngắn nhất — không đủ
 * khi HAI nút khác nhau cùng role="button" và CÙNG CHỮ. Ở màn Thi đấu có
 * đúng hai chỗ như vậy:
 *   - hai thẻ trận cùng lúc đều có icon xoá với tooltip Vi.matchDelete
 *     ('Xóa trận'), nên click('Xóa trận') có thể trúng thẻ sai;
 *   - nút xác nhận trong hộp thoại xoá ghi đúng chữ Vi.matchDeleteConfirm,
 *     mà Vi.matchDeleteConfirm === Vi.matchDelete (cùng là 'Xóa trận' — xem
 *     lib/core/strings/vi.dart dòng 139 và 143), nên nó cũng khớp label đó.
 *
 * Tooltip của IconButton chỉ nằm ở aria-label của node lá, không lan lên
 * tổ tiên (khác Text thường), nên phải: (1) lấy mọi node lá khớp [label]
 * như click() vẫn làm; (2) với mỗi node, đi lên tổ tiên tới khi gặp
 * textContent chứa [nearText]; (3) chọn node tốn ít bước đi lên nhất (rồi
 * tổ tiên có textContent ngắn nhất) — tức là node "gần" [nearText] nhất.
 */
async function clickNear(label, nearText, maxHops = 25) {
  await tab.semantics();
  const found = await tab.eval(`(() => {
    const label = ${JSON.stringify(label)};
    const nearText = ${JSON.stringify(nearText)};
    const maxHops = ${maxHops};
    const hits = [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
      .filter((x) => x.t.includes(label) && !x.t.includes(nearText) && !x.e.querySelector('flt-semantics'));
    // textContent của tổ tiên KHÔNG chứa aria-label của các nút/nhãn con
    // (tên người chơi nằm ở aria-label), nên gộp cả hai khi tìm mốc.
    const fullText = (n) => (n.textContent || '') + ' ' +
      [...n.querySelectorAll('[aria-label]')].map((c) => c.getAttribute('aria-label')).join(' ') +
      ' ' + (n.getAttribute('aria-label') || '');
    let best = null;
    for (const hit of hits) {
      let node = hit.e;
      for (let hops = 0; node && hops <= maxHops; hops++, node = node.parentElement) {
        const txt = fullText(node);
        if (txt.includes(nearText)) {
          if (!best || hops < best.hops || (hops === best.hops && txt.length < best.len)) {
            best = { e: hit.e, hops, len: txt.length, t: hit.t };
          }
          break;
        }
      }
    }
    if (!best) return null;
    best.e.click();
    return best.t;
  })()`);
  if (found == null) {
    throw new Error(`[${tab.name}] không có nút "${label}" gần "${nearText}". Đang thấy:\n${await tab.text()}`);
  }
  await sleep(1500);
}

// ─── Directus, quyền admin (chỉ dùng để đọc drill_logs — không bao giờ in
// token hay mật khẩu ra log, chỉ dùng tên biến môi trường trong thông báo). ──

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
 * drill_logs.user_created là quan hệ hệ thống tới directus_users (xem
 * deploy/directus/bootstrap.mjs, special: ['user-created']) — đây là trường
 * nối một dòng drill_logs với người tạo ra nó. Đợi tối đa [timeoutMs] vì
 * việc đồng bộ từ máy lên Directus (lib/data/sync/practice_sync.dart) có độ
 * trễ, không phải tức thì.
 */
async function waitDrillLogSynced(token, userId, minDurationSec, timeoutMs = 30000) {
  const end = Date.now() + timeoutMs;
  let lastSeen = 'không có dòng nào';
  while (Date.now() < end) {
    const res = await fetch(
      `${DIRECTUS}/items/drill_logs?filter[user_created][_eq]=${encodeURIComponent(userId)}&fields=id,duration_sec,drill_id,score,attempts`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    const body = await res.json();
    const row = body?.data?.[0];
    if (row) lastSeen = JSON.stringify(row);
    if (row && typeof row.duration_sec === 'number' && row.duration_sec >= minDurationSec) return row;
    await sleep(1500);
  }
  throw new Error(`[directus] drill_logs.duration_sec chưa >= ${minDurationSec} sau ${timeoutMs}ms. Dòng cuối thấy: ${lastSeen}`);
}

// Nhãn ngày khớp Vi.statsCombinedDayLabel (lib/core/strings/vi.dart dòng
// 227-235) — hàm đó nhận DateTime.weekday kiểu Dart (Monday=1..Sunday=7).
// Date#getDay() của JS là Sunday=0..Saturday=6, nên bảng này đánh số theo
// getDay() để khỏi phải quy đổi hai lần.
const DAY_LABEL_BY_JS_WEEKDAY = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

try {
  step(1, 'Tạo user thử và đăng nhập (registerThrowaway)');
  tab = await launch({ port: 9344, name: 'mds' });
  await registerThrowaway(tab, APP, { email, password });

  step(2, 'Thi đấu: tạo trận A (hai tên + race-to mặc định), ghi 1 ván');
  await tab.goto(`${APP}/play`);
  await tab.waitForText('Thi đấu'); // Vi.playTitle, vi.dart:122
  await check(
    (await tab.text()).includes('Chưa có trận đấu nào được ghi.'), // Vi.matchEmpty, vi.dart:127
    'Thi đấu: user thử mới, chưa có trận nào (nền sạch trước khi bắt đầu)',
  );
  await tab.click('Ghi trận mới'); // Vi.matchStart, vi.dart:123
  await tab.type('Tên của bạn', A_PLAYER); // Vi.matchPlayerName, vi.dart:132
  await tab.type('Tên đối thủ', A_OPPONENT); // Vi.matchOpponentName, vi.dart:133
  // Không đụng tới dropdown race-to: để mặc định targetRacks=5
  // (play_screen.dart:32) — "có một race-to" là đủ, chưa cần chỉnh.
  await tab.click('Bắt đầu trận'); // Vi.matchStartAction, vi.dart:135
  await tab.waitForText(`${A_PLAYER} 0 – 0 ${A_OPPONENT}`); // Vi.matchScore, vi.dart:171-176
  await tab.click('Tôi thắng ván'); // Vi.matchPlayerWinsRack, vi.dart:136 — chỉ một trận trên màn nên không mơ hồ.
  await check(
    (await tab.text()).includes(`${A_PLAYER} 1 – 0 ${A_OPPONENT}`),
    'Thi đấu: ghi 1 ván cho A, tỉ số đổi thành 1 – 0',
  );

  step(3, 'Thi đấu: sửa trận A (đổi cả hai tên, NÂNG race-to 5 → 7), tải lại kiểm tra còn nguyên');
  await tab.click('Sửa thông tin trận'); // Vi.matchEdit === Vi.matchEditTitle, vi.dart:124-125 — chỉ một trận nên không mơ hồ.
  await tab.type('Tên của bạn', A_PLAYER_EDITED);
  await tab.type('Tên đối thủ', A_OPPONENT_EDITED);
  // Mở dropdown race-to bằng giá trị đang đóng ("Chạm 5 ván thắng"). Thẻ A ở
  // NGAY SAU hộp thoại (nếu semantics nền còn tồn tại) cũng có thể hiện cùng
  // chữ này, nhưng click() của cdp.mjs ưu tiên role="button" trước — ô
  // dropdown là nút bấm được, chữ trên thẻ chỉ là Text thường, nên luôn
  // trúng dropdown bất kể thứ tự DOM (không cần clickNear ở đây).
  await tab.click('Chạm 5 ván thắng'); // Vi.matchRaceTo(5), vi.dart:177
  await tab.click('Chạm 7 ván thắng'); // nâng lên 7 — hợp lệ vì leaderWins=1 <= 7
  // (validator mới: value < leaderWins bị chặn, play_screen.dart:493).
  await tab.click('Lưu thay đổi'); // Vi.matchSaveDetails, vi.dart:126
  await tab.waitForText(`${A_PLAYER_EDITED} 1 – 0 ${A_OPPONENT_EDITED}`);

  await tab.reload();
  const afterEditText = await tab.text();
  await check(
    afterEditText.includes(`${A_PLAYER_EDITED} 1 – 0 ${A_OPPONENT_EDITED}`),
    'Sau tải lại: tên đã sửa và tỉ số 1 ván đã ghi vẫn còn nguyên',
  );
  await check(
    afterEditText.includes('Chạm 7 ván thắng'),
    'Sau tải lại: race-to đã nâng lên 7 vẫn còn nguyên',
  );
  await check(
    !afterEditText.includes(A_PLAYER) && !afterEditText.includes(A_OPPONENT),
    `Sau tải lại: tên cũ ("${A_PLAYER}"/"${A_OPPONENT}") không còn — sửa đã thay hẳn, không phải thêm mới`,
  );

  step(4, 'Thi đấu: tạo trận B rồi xoá qua hộp thoại xác nhận, tải lại kiểm tra B mất mà A còn');
  await tab.click('Ghi trận mới');
  await tab.type('Tên của bạn', B_PLAYER);
  await tab.type('Tên đối thủ', B_OPPONENT);
  // Target B để mặc định 5 — A giờ đã là 7 nên không trùng chữ với dropdown
  // mặc định của hộp thoại B lúc mở lên.
  await tab.click('Bắt đầu trận');
  await tab.waitForText(`${B_PLAYER} 0 – 0 ${B_OPPONENT}`);

  // Giờ có HAI trận cùng lúc, cả hai đều có icon xoá với tooltip 'Xóa trận'
  // (Vi.matchDelete) — phải dùng clickNear, lấy tên B làm mốc để trúng đúng
  // thẻ B (xem lời giải thích đầy đủ ở định nghĩa clickNear() phía trên).
  await clickNear('Xóa trận', B_PLAYER); // Vi.matchDelete, vi.dart:139 (icon trên thẻ B)
  await tab.waitForText('Xóa trận đấu?'); // Vi.matchDeleteTitle, vi.dart:140
  // Nút xác nhận trong hộp thoại CŨNG ghi 'Xóa trận' (Vi.matchDeleteConfirm
  // === Vi.matchDelete) — lấy tiêu đề hộp thoại làm mốc để trúng đúng nút
  // xác nhận, không trúng icon xoá của thẻ A hay B.
  await clickNear('Xóa trận', 'Xóa trận đấu?'); // Vi.matchDeleteConfirm, vi.dart:143

  await tab.reload();
  const afterDeleteText = await tab.text();
  await check(
    !afterDeleteText.includes(B_PLAYER) && !afterDeleteText.includes(B_OPPONENT),
    `Sau tải lại: trận B ("${B_PLAYER}"/"${B_OPPONENT}") đã xoá hẳn, không còn trên màn`,
  );
  await check(
    afterDeleteText.includes(`${A_PLAYER_EDITED} 1 – 0 ${A_OPPONENT_EDITED}`),
    'Sau tải lại: trận A vẫn còn nguyên sau khi xoá trận B',
  );

  step(5, 'Drill: mở buổi tập bài d1, giữ mở ~6s rồi lưu');
  await tab.goto(`${APP}/training/drills/d1/session`);
  await tab.waitForText('Tập: '); // Vi.sessionTitle(drillName), vi.dart:576
  // Stopwatch bắt đầu từ initState() của DrillSessionScreen
  // (drill_session_screen.dart:39) — giữ màn này mở >= 6s trước khi lưu để
  // durationSec ghi được >= 4 (kiểm tra ở Directus, bước 8 dưới).
  await sleep(6000);
  // score=7, attempts=10 trên bài d1 (passThreshold=0.8, seed_drills.dart:17)
  // cho tỉ lệ hiển thị '87%' — cùng cặp số accounts.mjs đã dùng và xác nhận
  // hoạt động, nên không đoán một cặp số mới chưa được kiểm chứng.
  await tab.type('Số lần đạt', '7'); // Vi.sessionScoreLabelAttempts, vi.dart:577
  await tab.type('Số lần thử', '10'); // Vi.sessionAttemptsLabel, vi.dart:581
  await tab.click('Lưu kết quả'); // Vi.sessionSaveAction, vi.dart:585
  await tab.waitForText('Đã lưu'); // tiền tố của Vi.sessionSavedRatio, vi.dart:601-602

  step(6, 'Drill: Thống kê phải hiện thời lượng Drill đã đo');
  // drill_session_screen.dart lưu xong thì chuyển màn ngay (context.go), và
  // drill_detail_screen.dart không hiển thị durationSec ở đâu cả — thẻ
  // statsDrillDurationTotal (stats_screen.dart:81-87) là NƠI DUY NHẤT trong
  // UI hiển thị thời lượng Drill đã đo, nên phải kiểm ở /stats.
  await tab.goto(`${APP}/stats`);
  await tab.waitForText('Thống kê'); // Vi.statsTitle, vi.dart:214
  await check(
    (await tab.text()).includes('Tổng thời lượng Drill đã đo'), // Vi.statsDrillDurationTotal, vi.dart:249
    'Thống kê: thẻ "Tổng thời lượng Drill đã đo" có mặt',
  );
  await check(
    // Vi.statsDrillDurationValue(seconds, sessionCount) — hậu tố cố định,
    // sessionCount=1 vì đây là user thử mới, chỉ một buổi có đo thời lượng.
    (await tab.text()).includes('1 buổi có dữ liệu'), // vi.dart:250-251
    'Thống kê: giá trị thẻ phản ánh đúng 1 buổi đã đo thời lượng',
  );

  step(7, 'Drill: tải lại trang chi tiết bài d1, buổi vừa ghi vẫn còn');
  await tab.goto(`${APP}/training/drills/d1`);
  await tab.waitForText('87%', 45000);
  await tab.reload();
  const afterDrillReloadText = await tab.text();
  await check(afterDrillReloadText.includes('87%'), 'Sau tải lại: buổi tập (87%) vẫn còn trong lịch sử bài d1');
  await check(
    afterDrillReloadText.includes('Lịch sử tập'), // Vi.drillHistoryTitle, vi.dart:559
    'Sau tải lại: mục "Lịch sử tập" có mặt',
  );

  step(8, 'Drill: Directus (quyền admin) — duration_sec của drill_logs phải là số >= 4');
  const adminToken = await directusAdminToken();
  const throwawayUserId = await directusUserId(adminToken);
  const drillLogRow = await waitDrillLogSynced(adminToken, throwawayUserId, 4, 30000);
  await check(
    typeof drillLogRow.duration_sec === 'number' && drillLogRow.duration_sec >= 4,
    `Directus drill_logs: duration_sec = ${drillLogRow.duration_sec} (số, >= 4)`,
  );

  step(9, 'Thống kê: nhãn theo ngày hôm nay phản ánh đúng 1 buổi tập và đúng 1 trận');
  await tab.goto(`${APP}/stats`);
  await tab.waitForText('Thống kê');
  const statsText = await tab.text();
  const todayLabel = DAY_LABEL_BY_JS_WEEKDAY[new Date().getDay()];
  // Semantics(label: Vi.statsCombinedDaySemantics(weekday, trainingSessions,
  // matches), ...) trong _CombinedTrainingPlayCard (stats_screen.dart:292-327)
  // in ra đúng một dòng "<nhãn>: N buổi tập, M trận" cho mỗi ngày của tuần —
  // tìm đúng dòng của hôm nay bằng nhãn ngày.
  const todayLine = statsText.match(new RegExp(`^${todayLabel}: (\\d+) buổi tập, (\\d+) trận$`, 'm'));
  await check(todayLine != null, `Thống kê: thấy dòng semantics "${todayLabel}: N buổi tập, M trận" của hôm nay`);
  if (todayLine) {
    const trainingSessionsToday = Number(todayLine[1]);
    const matchesToday = Number(todayLine[2]);
    await check(
      trainingSessionsToday === 1,
      `Thống kê hôm nay: buổi tập = ${trainingSessionsToday} (đúng 1, từ buổi Drill vừa ghi ở bước 5)`,
    );
    // Trận B đã bị XOÁ CỨNG ở bước 4 (DriftMatchRepository.remove —
    // lib/data/repositories/drift_match_repository.dart — không phải đánh
    // dấu is_deleted). training_statistics.dart, hàm _combinedTrainingPlay(),
    // tính số trận mỗi ngày bằng cách lặp "for (final match in matches)
    // addMatch(match.startedAt)" trực tiếp trên danh sách `matches` truyền
    // vào lúc tính (dòng 280-282) — một trận đã xoá cứng thì đơn giản là
    // KHÔNG CÒN trong danh sách đó nữa, nên không được cộng vào ngày nào cả.
    // Vì vậy hôm nay phải là ĐÚNG 1 trận (chỉ trận A) — ra 2 nghĩa là trận đã
    // xoá vẫn bị tính, tức là lỗi hồi quy.
    await check(
      matchesToday === 1,
      `Thống kê hôm nay: trận = ${matchesToday} (đúng 1 — chỉ trận A; trận B đã xoá không được tính)`,
    );
  }

  step(10, 'Thi đấu: trận C (race-to 3), ván 1 ghi đủ cú rồi mất ván, mở Phân tích trận đọc nguyên nhân mất ván');
  await tab.goto(`${APP}/play`);
  await tab.waitForText('Thi đấu');
  await tab.click('Ghi trận mới');
  await tab.type('Tên của bạn', C_PLAYER);
  await tab.type('Tên đối thủ', C_OPPONENT);
  await tab.click('Chạm 5 ván thắng'); // mặc định; mở dropdown race-to
  await tab.click('Chạm 3 ván thắng'); // Vi.matchRaceTo(3)
  await tab.click('Bắt đầu trận');
  await tab.waitForText(`${C_PLAYER} 0 – 0 ${C_OPPONENT}`);

  // Trận A còn đang mở nên 'Ghi cú đánh' và các nút ván có hai bản: luôn dò theo tên người chơi trận C.
  // Mặc định hộp thoại: người đánh = người chơi, loại = Cú thường, kết quả = Có bi.
  const recordShot = async ({ shooter, type, outcome }) => {
    await clickNear('Ghi cú đánh', C_PLAYER); // Vi.matchRecordShot
    await tab.waitForText('Lưu cú đánh');
    if (shooter) {
      await tab.click('Người đánh'); // Vi.matchShooter
      await tab.click(shooter);
    }
    if (type) {
      await tab.click('Loại cú'); // Vi.matchShotType
      await tab.click(type);
    }
    if (outcome) {
      await tab.click('Kết quả cú'); // Vi.matchShotOutcome
      await tab.click(outcome);
    }
    await tab.click('Lưu cú đánh'); // Vi.matchSaveShot
    await sleep(1000);
  };
  await recordShot({ type: 'Phá' }); // người chơi phá, Có bi (Vi.matchBreakShot, Vi.matchShotMade)
  await recordShot({ outcome: 'Trượt' }); // người chơi Cú thường, Trượt (Vi.matchShotMissed)
  await recordShot({ shooter: C_OPPONENT }); // đối thủ Cú thường, Có bi
  await clickNear('Đối thủ thắng ván', C_PLAYER); // Vi.matchOpponentWinsRack
  await clickNear('Đối thủ thắng ván', C_PLAYER);
  await clickNear('Đối thủ thắng ván', C_PLAYER);
  await tab.waitForText(`${C_PLAYER} 0 – 3 ${C_OPPONENT}`);

  await clickNear('Phân tích trận', C_PLAYER); // Vi.matchAnalysisOpen
  await tab.waitForText('Mất 1 ván sau khi trượt cú tấn công');
  const analysisText = await tab.text();
  await check(
    analysisText.includes('Mất 1 ván sau khi trượt cú tấn công'), // Vi.lostRackCause(offensiveMiss, 1)
    'Phân tích trận: ván 1 mất sau cú tấn công trượt (nguyên nhân đọc từ các cú đã ghi)',
  );
  await check(analysisText.includes('Phân tích trận'), 'Phân tích trận: bảng phân tích đang mở');

  step(11, 'Lộ trình: xác định hạng H, đặt mục tiêu Lên hạng F (2 hạng), thấy bước mốc hạng G');
  await tab.goto(`${APP}/training/roadmap`);
  await tab.waitForText('Chọn mục tiêu');
  await tab.click('Xác định hạng'); // Vi.goalNeedRank, mở bộ câu hỏi (user thử chưa có hạng)
  await tab.click('Bắt đầu');
  for (const pick of TO_H) {
    await tab.click(pick);
    await tab.click('Tiếp');
  }
  await tab.waitForText('HẠNG H');
  await tab.click('Xác nhận');
  // Mở từ Lộ trình thì Xác nhận quay về Lộ trình (nhãn 'ước lượng' chỉ có ở
  // Hồ sơ); chờ ngắn cho hạng lưu xong rồi tải lại để đọc hạng đã lưu.
  await tab.waitForText('Chọn mục tiêu');
  await sleep(2000);
  await tab.goto(`${APP}/training/roadmap`);
  await tab.waitForText('Chọn mục tiêu');
  await tab.click('Lên hạng'); // Vi.goalKind(lenHang)
  await tab.waitForText('Lên tới hạng'); // Vi.goalTargetRankTitle
  await tab.click('F'); // chip hạng đích, Vi: label của Rank.f
  await tab.waitForText('Lên hạng: H → F'); // Vi.roadmapHeadline
  const roadmapText = await tab.text();
  await check(roadmapText.includes('Lên hạng: H → F'), 'Lộ trình: tiêu đề mục tiêu Lên hạng: H → F');
  // Danh sách Lộ trình là ListView lười: bước mốc hạng G là mục thứ 8 trên màn
  // 412x915 nên chưa được dựng, chưa có node semantics. Cuộn từng đoạn ngắn (không nhảy hẳn xuống cuối, kẻo mục bị gỡ) tới khi
  // dựng ra rồi mới đọc chữ.
  const milestone = 'Làm bài BU — mốc hạng G';
  let scrolledText = roadmapText;
  for (let i = 0; i < 12 && !scrolledText.includes(milestone); i++) {
    await tab.eval(`(() => {
      for (const e of document.querySelectorAll('flt-semantics')) {
        if (e.scrollHeight > e.clientHeight + 1) e.scrollTop += Math.max(200, Math.floor(e.clientHeight * 0.6));
      }
    })()`);
    await sleep(1000);
    scrolledText = await tab.text();
  }
  await check(
    // Chưa có kết quả BU nên là "Làm", không phải "Làm lại" (Vi.stepTitle, retake=false).
    scrolledText.includes(milestone),
    'Lộ trình: có bước mốc hạng G trung gian cho mục tiêu lên 2 hạng',
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
