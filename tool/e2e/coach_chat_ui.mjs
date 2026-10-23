// Hỏi huấn luyện viên trên Chrome thật (Giai đoạn B, Task 12): mở /coach,
// bấm câu hỏi mẫu, chờ câu trả lời và hạn mức giảm, chụp ảnh cho chủ sản
// phẩm xem bong bóng chat ở ba cỡ màn.
//   node tool/e2e/coach_chat_ui.mjs <appUrl>
// Trỏ vào bản build trỏ COACH_CHAT_URL về coach_chat_stub.mjs thì không tốn
// gì; trỏ vào dịch vụ Coach Chat thật thì BÀI NÀY TỐN MỘT CÂU HỎI THẬT (gọi
// Claude thật, trừ một lượt hạn mức của tài khoản thử).
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó. Địa chỉ
// app bắt buộc và không có mặc định: không bao giờ lỡ chạy nhầm vào bản thật.
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');
if (!process.argv[2]) throw new Error('Thiếu địa chỉ app: node tool/e2e/coach_chat_ui.mjs <appUrl>');

const APP = process.argv[2].replace(/\/$/, '');
const LIMIT = Number(process.env.COACH_CHAT_LIMIT ?? 30);
const SAMPLE_QUESTION = 'Hôm nay tôi nên tập gì?';
// Chép đúng từng chữ từ Vi.coachChatInsufficient (lib/core/strings/vi.dart) — I2c.
// Không import được file Dart vào một script Node, nên chép tay; lệch một chữ là
// bài này không còn nhận ra đúng câu app thật hiện khi bộ lọc chặn câu trả lời.
const COACH_CHAT_INSUFFICIENT = 'Chưa đủ dữ liệu để trả lời câu này.';
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-coach-chat');
const email = `e2e-coach-chat-${Date.now()}@poolcoachai.example.com`;

const SHOT_SIZES = [
  { name: 'phone', width: 360, height: 640, deviceScaleFactor: 3, mobile: true },
  { name: 'phone-landscape', width: 740, height: 360, deviceScaleFactor: 3, mobile: true },
  { name: 'desktop', width: 1280, height: 800, deviceScaleFactor: 1, mobile: false },
];

let failed = 0;
function check(ok, what) {
  console.log(`${ok ? 'ĐẠT ' : 'HỎNG'}  ${what}`);
  if (!ok) failed++;
}
// Quan sát mềm (I2c, cùng kiểu controller ruling 2 của coach_chat.mjs): in ra
// để chủ sản phẩm biết, không bao giờ tính hỏng bài — câu trả lời của Claude
// không tất định 100%, và bộ lọc app có thể hợp lệ chặn một câu trả lời.
function note(what) {
  console.log(`GHI NHẬN  ${what}`);
}

/// Chờ tới [timeoutMs] cho nút semantics khớp [label] hết aria-disabled.
///
/// Nút câu hỏi mẫu chỉ bật khi chatContextReady true, tức coachContextProvider
/// đã có đủ dữ liệu (coach_screen.dart:66, :157) — trước đó cdp.mjs's click()
/// vẫn "bấm" được vì nó không kiểm disabled, nhưng Flutter lờ đi, nên phải tự
/// chờ ở đây trước khi bấm. Dò đúng node mà click() sẽ chọn (ưu tiên role
/// button, rồi nhãn ngắn nhất) để không chờ nhầm node khác trùng chữ.
/// Engine Flutter web set aria-disabled="true" lúc khoá và XOÁ HẲN thuộc tính
/// lúc bật (không set "false") — xác nhận bằng cách tìm "aria-disabled" trong
/// build/web/main.dart.js đã build (lớp role tương ứng gọi setAttribute khi
/// khoá, removeAttribute khi bật).
async function waitForEnabled(tab, label, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    await tab.semantics();
    const disabled = await tab.eval(`(() => {
      const hits = [...document.querySelectorAll('flt-semantics')]
        .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
        .filter((x) => x.t.includes(${JSON.stringify(label)}))
        .sort((a, b) => (a.e.getAttribute('role') === 'button' ? 0 : 1) - (b.e.getAttribute('role') === 'button' ? 0 : 1)
          || a.t.length - b.t.length);
      if (!hits.length) return null;
      return hits[0].e.getAttribute('aria-disabled') === 'true';
    })()`);
    if (disabled === false) return true;
    await sleep(1000);
  }
  return false;
}

const tab = await launch({ port: 9343, name: 'coach-chat' });

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });

  await tab.goto(`${APP}/coach`);
  await tab.waitForText('Hỏi huấn luyện viên');

  // Tiêu đề thẻ hiện ngay, nhưng nút câu hỏi mẫu chỉ bật khi coachContextProvider
  // xong — chờ ở đây để không bấm hụt rồi ngồi chờ oan 120 s coi như lỗi backend.
  if (!(await waitForEnabled(tab, SAMPLE_QUESTION, 30000))) {
    throw new Error('nút câu hỏi mẫu vẫn bị khoá (dữ liệu Coach chưa sẵn sàng) sau 30 s');
  }
  await tab.click(SAMPLE_QUESTION);

  // `_askSample` gửi câu hỏi nền rồi chuyển ngay sang /coach/chat — hạn mức
  // mới cập nhật khi câu trả lời về, nên chờ tới 120 s (có thể là gọi Claude
  // thật).
  await tab.waitForText(`Còn ${LIMIT - 1} lượt hỏi hôm nay`, 120000);

  const text = await tab.text();
  check(text.includes(SAMPLE_QUESTION), `câu hỏi "${SAMPLE_QUESTION}" hiện trong hội thoại`);
  check(!text.includes('Huấn luyện viên đang trả lời…'), 'không còn trạng thái "đang trả lời"');
  check(!text.includes('Chưa gửi được câu hỏi.'), 'không còn lỗi "Chưa gửi được câu hỏi."');
  // I2c: quan sát mềm — in ra bong bóng trả lời có phải đúng câu "chưa đủ dữ liệu"
  // của app không (Claude có thể đã từ chối/bị cắt, hoặc bộ lọc Dart đã chặn câu trả
  // lời), không tính hỏng bài vì câu trả lời của Claude không tất định 100%.
  note(
    text.includes(COACH_CHAT_INSUFFICIENT)
      ? `bong bóng trả lời là câu "chưa đủ dữ liệu" của app (Vi.coachChatInsufficient) — xem lại câu hỏi mẫu/facts hoặc log server`
      : 'bong bóng trả lời không phải câu "chưa đủ dữ liệu" của app',
  );

  for (const size of SHOT_SIZES) {
    await tab.send('Emulation.setDeviceMetricsOverride', {
      width: size.width, height: size.height, deviceScaleFactor: size.deviceScaleFactor, mobile: size.mobile,
    });
    await tab.shot(path.join(shots, `${size.name}.png`));
  }

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  check(errors.length === 0, `không có lỗi trong console${errors.length ? `:\n${errors.join('\n')}` : ''}`);

  console.log('\n-- Mọi nhãn trên màn (để chủ sản phẩm đọc câu trả lời) --');
  for (const label of await tab.labels()) console.log(label.replace(/\n/g, ' / '));

  console.log(`\n${failed ? `HỎNG ${failed} kiểm tra.` : 'Xong, mọi kiểm tra đạt.'} Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
if (failed) process.exitCode = 1;
