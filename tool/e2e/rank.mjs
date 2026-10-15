// Đánh giá + hạng trên Chrome thật (spec 2026-10-14 mục 9): onboarding, Đề I
// có tải lại giữa bài, Đề II để buổi khác, hoàn tất, lên hạng, máy thứ hai
// thấy hạng; rồi chụp từng sơ đồ BU cho chủ sản phẩm xem.
//   node tool/e2e/rank.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-rank');
const email = `e2e-rank-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (n, msg) => console.log(`\n── Bước ${n}: ${msg}`);

async function times(tab, label, n) {
  for (let i = 0; i < n; i++) await tab.click(label);
}

// Bộ câu hỏi ra H: Q5 "Đã từng 1–2 lần" (spec mục 11.2), các câu khác lựa chọn đầu.
const TO_H = ['Chưa từng chơi', 'Dưới 2 giờ / tuần', '1', '1', 'Đã từng 1–2 lần', 'Chưa từng',
  'Thường không có bi đánh tiếp', 'Thường xuyên bị khó'];

const one = await launch({ port: 9335, name: 'rank-1' });
const two = await launch({ port: 9336, name: 'rank-2' });
try {
  step(1, 'Đăng ký: tài khoản mới vào bộ câu hỏi');
  await registerThrowaway(one, APP, { email, password, keepOnboarding: true });
  await one.shot(path.join(shots, '01-onboarding.png'));

  step(2, 'Trả lời 8 câu, xác nhận hạng gợi ý H (ước lượng)');
  await one.click('Bắt đầu');
  for (const pick of TO_H) {
    await one.click(pick);
    await one.click('Tiếp');
  }
  await one.waitForText('Hạng gợi ý cho bạn');
  await one.waitForText('HẠNG H');
  await one.shot(path.join(shots, '02-goi-y.png'));
  await one.click('Xác nhận');
  await one.waitForText('ước lượng');

  step(3, 'Hồ sơ → Làm bài kiểm tra, bàn 9 feet, bắt đầu Đề I');
  await one.goto(`${APP}/profile`);
  await one.click('Làm bài kiểm tra');
  await one.waitForText('Chuẩn bị');
  await one.click('9 feet trở lên');
  await one.click('Bắt đầu Đề I');
  await one.waitForText('F1 · Cắt góc');

  step(4, 'F1 ba cú vào, tải lại trang: vẫn ở cú 4/10, vị trí 7');
  await times(one, 'Vào', 3);
  await one.reload();
  // Màn làm bài mở bằng push nên URL vẫn là /profile: tải lại thì về Hồ sơ,
  // thẻ hạng có Làm tiếp (như bước 6).
  await one.click('Làm tiếp');
  await one.waitForText('Cú 4 / 10');
  await one.waitForText('Vị trí hiện tại: 7');
  await one.shot(path.join(shots, '03-tai-lai-giua-F1.png'));

  step(5, 'Hết Đề I: F1–F6 trọn điểm, F7 và F8 trượt hết → 60, bản Masters');
  await times(one, 'Vào', 5); // F1 đủ 8 cú vào liền: chắc 10
  for (const id of ['F2', 'F3', 'F4', 'F5']) {
    await one.waitForText(`${id} · `);
    await times(one, 'Vào', 8);
  }
  await one.waitForText('F6 · Ăn bi');
  await times(one, 'Vào', 10);
  await one.waitForText('F7 · Bánh xe');
  await times(one, 'Không đạt', 20);
  await one.waitForText('F8 · Lưới đích');
  await times(one, 'Không đạt', 20);
  await one.waitForText('Xong Đề I');
  await one.click('Chấm Đề I');
  await one.waitForText('Điểm Đề I: 60 / 100');
  await one.waitForText('Bạn làm Đề II bản Masters.');
  await one.shot(path.join(shots, '04-xep-ban.png'));

  step(6, 'Để buổi khác, tải lại, Làm tiếp → Làm Đề II ngay');
  await one.click('Để buổi khác');
  await one.waitForText('Làm tiếp');
  await one.reload();
  await one.click('Làm tiếp');
  await one.click('Làm Đề II ngay');
  await one.waitForText('S1 · Hàng bi');

  step(7, 'Đề II Masters trọn điểm (77)');
  const count = async (id, balls, layouts) => {
    await one.waitForText(`${id} · `);
    for (let k = 0; k < layouts; k++) {
      await times(one, 'Thêm một bi', balls);
      await one.click('Ghi lượt');
    }
  };
  await count('S1', 7, 1);
  await count('S2', 11, 1);
  await count('S3', 6, 3);
  await count('S4', 6, 3);
  await one.waitForText('S5 · ');
  await times(one, 'Bắt đui được', 10);
  await one.waitForText('S6 · ');
  await times(one, 'Chạm bi', 5);
  await one.waitForText('S7 · ');
  await times(one, 'Vào', 5);
  for (const id of ['S8', 'S9']) {
    await one.waitForText(`${id} · `);
    await times(one, 'Đạt', 5);
  }
  await one.waitForText('S10 · Phá');
  for (let k = 0; k < 3; k++) {
    for (const c of ['a: không chết cái', 'b: a,', 'c: a,', 'd: a,', 'e: a,']) await one.click(c);
    await one.click('Ghi lần phá');
  }

  step(8, 'Hoàn tất: 137 điểm, lên hạng H → D, đã kiểm chứng');
  await one.waitForText('Xong Đề II');
  await one.click('Hoàn tất và xem kết quả');
  await one.waitForText('Điểm BU: 137 / 200');
  await one.waitForText('Lên hạng: H → D, đã kiểm chứng.');
  await one.waitForText('Mức BU: mid advanced');
  await one.shot(path.join(shots, '05-ket-qua.png'));

  step(9, 'Hồ sơ: HẠNG D, đã kiểm chứng, ngày kiểm tra lại');
  await one.goto(`${APP}/profile`);
  await one.waitForText('HẠNG D');
  await one.waitForText('đã kiểm chứng');
  await one.waitForText('Lần kế tiếp làm được từ ngày');
  await one.shot(path.join(shots, '06-ho-so.png'));

  step(10, 'Máy thứ hai đăng nhập: thấy HẠNG D, không bị đưa vào bộ câu hỏi');
  await two.goto(APP);
  await two.type('Email', email);
  await two.type('Mật khẩu', password);
  await two.click('Đăng nhập');
  await two.waitForText('Xin chào');
  await two.waitForText('HẠNG D', 45000);
  const twoText = await two.text();
  if (twoText.includes('Trả lời 8 câu hỏi ngắn')) throw new Error('Máy thứ hai bị đưa vào bộ câu hỏi');
  await two.shot(path.join(shots, '07-may-2.png'));

  step(11, 'Chụp từng sơ đồ BU');
  for (let i = 0; ; i++) {
    await one.goto(`${APP}/rank/layouts?i=${i}`);
    const text = await one.text();
    if (text.includes('Hết sơ đồ.')) break;
    const caption = text.split('\n').find((l) => l.startsWith('Sơ đồ ')) ?? `#${i}`;
    console.log(`   ${caption}`);
    await one.shot(path.join(shots, `so-do-${String(i + 1).padStart(3, '0')}.png`));
  }

  const errors = [...one.errors, ...two.errors].filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await one.close();
  await two.close();
  await deleteUserByEmail(email);
}
