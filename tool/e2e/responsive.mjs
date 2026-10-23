// Mở các màn chính ở bốn cỡ màn trên Chrome thật — điện thoại dọc, điện thoại
// ngang, máy tính bảng, máy tính — kiểm tra thẻ viewport, bề ngang cửa sổ và
// không có thanh cuộn ngang, rồi chụp mỗi màn một ảnh.
//   node tool/e2e/responsive.mjs <appUrl>
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
//
// Bản release không báo tràn (Flutter chỉ kiểm tra lúc debug); phần tràn do
// lượt quét widget test lo. Bài này chứng minh cỡ màn trên trình duyệt điện
// thoại thật, và để lại ảnh cho chủ sản phẩm xem.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó. Địa chỉ
// app bắt buộc và không có mặc định: không bao giờ lỡ tạo user trên bản thật.
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');
if (!process.argv[2]) throw new Error('Thiếu địa chỉ app: node tool/e2e/responsive.mjs <appUrl>');

const APP = process.argv[2].replace(/\/$/, '');
const shots = path.join(os.tmpdir(), 'pcai-responsive');
const email = `e2e-responsive-${Date.now()}@poolcoachai.example.com`;

const VIEWPORTS = [
  { name: 'phone', width: 360, height: 640, deviceScaleFactor: 3, mobile: true },
  { name: 'phone-landscape', width: 740, height: 360, deviceScaleFactor: 3, mobile: true },
  { name: 'tablet', width: 800, height: 1280, deviceScaleFactor: 2, mobile: true },
  { name: 'desktop', width: 1280, height: 800, deviceScaleFactor: 1, mobile: false },
];

// Đường dẫn theo lib/core/router/routes.dart; tiêu đề là hằng Vi mà màn đó
// đặt lên thanh tiêu đề.
const ROUTES = [
  { name: 'home', path: '/home', title: 'Xin chào' },
  { name: 'training', path: '/training', title: 'Trung tâm luyện tập' },
  { name: 'simulator', path: '/training/simulator', title: 'Mô phỏng góc cắt' },
  { name: 'planner', path: '/training/planner', title: 'Kế hoạch dọn bàn' },
  { name: 'play', path: '/play', title: 'Thi đấu' },
  { name: 'stats', path: '/stats', title: 'Thống kê' },
  { name: 'profile', path: '/profile', title: 'Hồ sơ' },
  { name: 'equipment', path: '/profile/equipment', title: 'Cơ bi-a' },
  { name: 'knowledge', path: '/knowledge', title: 'Kiến thức' },
  { name: 'notifications', path: '/notifications', title: 'Thông báo' },
  { name: 'rank', path: '/rank', title: 'Hạng của bạn' },
  { name: 'coach', path: '/coach', title: 'Huấn luyện viên AI' },
  { name: 'coach-library', path: '/coach/library', title: 'Thư viện tình huống' },
  { name: 'coach-chat', path: '/coach/chat', title: 'Hỏi huấn luyện viên' },
];

let failed = 0;
function check(ok, what) {
  console.log(`${ok ? 'ĐẠT ' : 'HỎNG'}  ${what}`);
  if (!ok) failed++;
}

// Ảnh của lượt trước nằm lẫn vào thì đếm ảnh không còn đúng.
fs.rmSync(shots, { recursive: true, force: true });
const tab = await launch({ port: 9342, name: 'responsive' });

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });
  for (const vp of VIEWPORTS) {
    await tab.send('Emulation.setDeviceMetricsOverride', {
      width: vp.width, height: vp.height, deviceScaleFactor: vp.deviceScaleFactor, mobile: vp.mobile,
    });
    for (const r of ROUTES) {
      const where = `${vp.name} ${r.path}`;
      await tab.goto(`${APP}${r.path}`);
      await tab.waitForText(r.title);
      const m = await tab.eval(`({
        viewport: document.querySelector('meta[name=viewport]')?.content ?? '',
        inner: window.innerWidth,
        scroll: document.documentElement.scrollWidth,
      })`);
      check(m.viewport.includes('width=device-width'), `${where}: thẻ viewport "${m.viewport}"`);
      check(m.inner === vp.width, `${where}: innerWidth ${m.inner} = ${vp.width}`);
      check(m.scroll <= m.inner, `${where}: scrollWidth ${m.scroll} <= innerWidth ${m.inner}`);
      await tab.shot(path.join(shots, `${vp.name}-${r.name}.png`));
    }
  }
  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  check(errors.length === 0, `không có lỗi trong console${errors.length ? `:\n${errors.join('\n')}` : ''}`);
  console.log(`\n${failed ? `HỎNG ${failed} kiểm tra.` : 'Xong, mọi kiểm tra đạt.'} Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
if (failed) process.exitCode = 1;
