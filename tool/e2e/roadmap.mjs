// Lộ trình trên Chrome thật (spec 2026-10-15 mục 9): chọn mục tiêu → thấy
// bước → ghi một buổi tập → lộ trình đổi → đổi mục tiêu → máy thứ hai thấy
// cùng mục tiêu.
//   PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 node tool/e2e/roadmap.mjs <appUrl>
// Script tạo tài khoản thử và ghi dữ liệu qua Directus, nên cần xác nhận rõ ràng.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (name) =>
  process.env[name] ?? (() => { throw new Error(`Thiếu ${name}`); })();

if (process.env.PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1') {
  throw new Error(
    'E2E Lộ trình ghi dữ liệu qua Directus. Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP_URL = process.argv[2];
if (!APP_URL) throw new Error('Cần truyền URL app làm đối số.');
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = APP_URL.replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-roadmap');
const email = `e2e-roadmap-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const step = (number, message) => console.log(`\n── Bước ${number}: ${message}`);

let one;
let two;
try {
  one = await launch({ port: 9337, name: 'roadmap-1' });
  two = await launch({ port: 9338, name: 'roadmap-2' });

  step(1, 'Đăng ký (Để sau bộ câu hỏi): chưa có hạng');
  await registerThrowaway(one, APP, { email, password });

  step(2, 'Lộ trình: bảng chọn mục tiêu, Lên hạng bị khóa vì chưa có hạng');
  await one.goto(`${APP}/training/roadmap`);
  await one.waitForText('Chọn mục tiêu');
  await one.waitForText('Cần có hạng trước khi đặt mục tiêu lên hạng.');
  await one.shot(path.join(shots, '01-chon-muc-tieu.png'));

  step(3, 'Thuần thục kỹ năng → Ngắm bi: thấy các bước');
  await one.click('Thuần thục kỹ năng');
  await one.click('Ngắm bi');
  await one.waitForText('Thuần thục: Ngắm bi');
  await one.waitForText('Đang làm');
  await one.waitForText('Buổi đạt liên tiếp: 0 / 3');
  await one.shot(path.join(shots, '02-lo-trinh.png'));

  step(4, 'Tập ngay: ghi một buổi 9/10');
  await one.click('Tập ngay');
  await one.waitForText('Tập: ');
  await one.type('Số lần đạt', '9');
  await one.type('Số lần thử', '10');
  await one.click('Lưu kết quả');
  await one.waitForText('Đã lưu');

  step(5, 'Quay lại Lộ trình: bước đổi theo buổi vừa ghi');
  await one.goto(`${APP}/training/roadmap`);
  await one.waitForText('Buổi đạt liên tiếp: 1 / 3');
  await one.waitForText('Chưa có thành tích');
  await one.shot(path.join(shots, '03-sau-buoi-tap.png'));

  step(6, 'Đổi mục tiêu sang Thuần thục Phòng thủ');
  await one.click('Đổi mục tiêu');
  await one.click('Thuần thục kỹ năng');
  await one.click('Phòng thủ');
  await one.waitForText('Thuần thục: Phòng thủ');
  await one.shot(path.join(shots, '04-doi-muc-tieu.png'));

  step(7, 'Máy thứ hai đăng nhập: thấy cùng mục tiêu');
  await two.goto(APP);
  await two.type('Email', email);
  await two.type('Mật khẩu', password);
  await two.click('Đăng nhập');
  await two.waitForText('Xin chào');
  await two.goto(`${APP}/training/roadmap`);
  await two.waitForText('Thuần thục: Phòng thủ', 45000);
  await two.shot(path.join(shots, '05-may-2.png'));

  const errors = [...one.errors, ...two.errors].filter((error) => !/favicon/i.test(error));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  try {
    if (two) await two.close();
  } finally {
    try {
      if (one) await one.close();
    } finally {
      await deleteUserByEmail(email);
    }
  }
}
