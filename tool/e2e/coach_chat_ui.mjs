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
import { launch } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó. Địa chỉ
// app bắt buộc và không có mặc định: không bao giờ lỡ chạy nhầm vào bản thật.
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');
if (!process.argv[2]) throw new Error('Thiếu địa chỉ app: node tool/e2e/coach_chat_ui.mjs <appUrl>');

const APP = process.argv[2].replace(/\/$/, '');
const LIMIT = Number(process.env.COACH_CHAT_LIMIT ?? 30);
const SAMPLE_QUESTION = 'Hôm nay tôi nên tập gì?';
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

const tab = await launch({ port: 9343, name: 'coach-chat' });

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });

  await tab.goto(`${APP}/coach`);
  await tab.waitForText('Hỏi huấn luyện viên');
  await tab.click(SAMPLE_QUESTION);

  // `_askSample` gửi câu hỏi nền rồi chuyển ngay sang /coach/chat — hạn mức
  // mới cập nhật khi câu trả lời về, nên chờ tới 120 s (có thể là gọi Claude
  // thật).
  await tab.waitForText(`Còn ${LIMIT - 1} lượt hỏi hôm nay`, 120000);

  const text = await tab.text();
  check(text.includes(SAMPLE_QUESTION), `câu hỏi "${SAMPLE_QUESTION}" hiện trong hội thoại`);
  check(!text.includes('Huấn luyện viên đang trả lời…'), 'không còn trạng thái "đang trả lời"');
  check(!text.includes('Chưa gửi được câu hỏi.'), 'không còn lỗi "Chưa gửi được câu hỏi."');

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
