// Tầng 4 của kiểm thử (spec mục 8): hai "máy" là hai profile Chrome.
//
//   MAILPIT_URL=… MAILPIT_USER=… MAILPIT_PASSWORD=… node tool/e2e/accounts.mjs [appUrl]
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
const MAIL = need('MAILPIT_URL').replace(/\/$/, '');
const mailAuth = 'Basic ' + Buffer.from(`${need('MAILPIT_USER')}:${need('MAILPIT_PASSWORD')}`).toString('base64');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-e2e');

const email = `e2e-${Date.now()}@poolcoachai.example.com`;
const pass1 = randomBytes(6).toString('hex');
const pass2 = randomBytes(6).toString('hex');
const step = (n, msg) => console.log(`\n── Bước ${n}: ${msg}`);

async function signIn(tab, password) {
  await tab.type('Email', email);
  await tab.type('Mật khẩu', password);
  await tab.click('Đăng nhập');
  await tab.waitForText('Xin chào');
}

async function record(tab, score) {
  await tab.goto(`${APP}/training/drills/d1/session`);
  await tab.type('Số lần đạt', String(score));
  await tab.type('Số lần thử', '10');
  await tab.click('Lưu kết quả');
  await tab.waitForText('Đã lưu');
}

async function resetLink() {
  for (let i = 0; i < 30; i++) {
    const found = await (await fetch(`${MAIL}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`, { headers: { Authorization: mailAuth } })).json();
    const id = found.messages?.[0]?.ID;
    if (id) {
      const msg = await (await fetch(`${MAIL}/api/v1/message/${id}`, { headers: { Authorization: mailAuth } })).json();
      const link = (msg.HTML + msg.Text).match(/https?:\/\/[^\s"'<]+\/reset-password\?token=[^\s"'<&]+/)?.[0];
      if (link) return link;
    }
    await sleep(1000);
  }
  throw new Error('không thấy thư đặt lại mật khẩu trong mailpit');
}

const one = await launch({ port: 9333, name: 'may-1' });
const two = await launch({ port: 9334, name: 'may-2' });
try {
  step(1, 'Máy 1 đăng ký và ghi buổi 7/10');
  await one.goto(APP);
  await one.waitForText('Đăng nhập');
  await one.click('Chưa có tài khoản');
  await one.type('Tên hiển thị', 'Người thử E2E');
  await one.type('Email', email);
  await one.type('Nhập lại mật khẩu', pass1);
  await one.type('Mật khẩu', pass1);
  await one.click('Tạo tài khoản');
  await one.waitForText('Xin chào');
  await record(one, 7);
  await one.shot(path.join(shots, '1-may1-ghi-7.png'));

  step(2, 'Máy 2 đăng nhập cùng tài khoản và thấy buổi đó');
  await two.goto(APP);
  await signIn(two, pass1);
  await two.goto(`${APP}/training/drills/d1`);
  await two.waitForText('87%', 45000);
  await two.shot(path.join(shots, '2-may2-thay-87.png'));

  step(3, 'Máy 1 mất mạng, ghi buổi 9/10 — chỉ nằm trên máy');
  await one.blockApi(true);
  await record(one, 9);
  await one.shot(path.join(shots, '3-may1-ghi-offline.png'));

  step(4, 'Máy 2 đăng xuất, quên mật khẩu, đặt mật khẩu mới qua mailpit');
  await two.goto(`${APP}/profile`);
  await two.click('Đăng xuất');
  await two.waitForText('Quên mật khẩu');
  await two.click('Quên mật khẩu');
  await two.type('Email', email);
  await two.click('Gửi link');
  await two.waitForText('Nếu email này có tài khoản');
  const link = await resetLink();
  console.log(`   link: ${link.slice(0, 60)}…`);
  await two.goto(link);
  await two.type('Nhập lại mật khẩu', pass2);
  await two.type('Mật khẩu mới', pass2);
  await two.click('Lưu mật khẩu mới');
  await two.waitForText('Đã đổi mật khẩu');
  await two.shot(path.join(shots, '4-may2-doi-mat-khau.png'));

  step(5, 'Máy 1 có mạng lại, mở lại app: tự đăng xuất nhưng buổi offline vẫn còn');
  await one.blockApi(false);
  await one.reload();
  await one.waitForText('Phiên đăng nhập đã hết', 45000);
  await one.shot(path.join(shots, '5a-may1-het-phien.png'));
  await signIn(one, pass2);
  await one.goto(`${APP}/training/drills/d1`);
  await one.waitForText('113%', 45000);
  await one.waitForText('87%');
  await one.shot(path.join(shots, '5b-may1-con-du.png'));

  step(6, 'Máy 2 đăng nhập bằng mật khẩu mới và thấy buổi offline của máy 1');
  await two.goto(APP);
  await signIn(two, pass2);
  await two.goto(`${APP}/training/drills/d1`);
  await two.waitForText('113%', 45000);
  await two.shot(path.join(shots, '6-may2-thay-113.png'));

  const errors = [...one.errors, ...two.errors].filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nTất cả 6 bước qua. Ảnh ở ${shots}`);
} finally {
  await one.close();
  await two.close();
  if (process.env.DIRECTUS_URL && process.env.DIRECTUS_ADMIN_PASSWORD) {
    // Dọn dẹp hỏng thì chỉ cảnh báo: không được che lỗi thật của bài chạy.
    try {
      const base = process.env.DIRECTUS_URL.replace(/\/$/, '');
      const login = await (await fetch(`${base}/auth/login`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: process.env.DIRECTUS_ADMIN_EMAIL, password: process.env.DIRECTUS_ADMIN_PASSWORD }),
      })).json();
      const token = login.data.access_token;
      const users = await (await fetch(`${base}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`, { headers: { Authorization: `Bearer ${token}` } })).json();
      for (const u of users.data) {
        await fetch(`${base}/users/${u.id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
      }
      console.log('Đã xoá user thử');
    } catch (cleanupError) {
      console.warn(`Cảnh báo: không xoá được user thử ${email}: ${cleanupError}`);
    }
  }
}
