// Mở Mô phỏng góc cắt trên Chrome thật: đọc nhãn semantics của bàn và chụp từng tình huống.
//   node tool/e2e/simulator.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-sim');
const email = `e2e-sim-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

const tab = await launch({ port: 9335, name: 'mo-phong' });

async function summary() {
  return (await tab.labels()).find((l) => l.startsWith('Bàn mô phỏng'));
}

async function tableRect() {
  // Đọc nhãn y như cdp.mjs labels(): Flutter web để nhãn ở textContent chứ
  // không phải aria-label. Node cha có textContent bắt đầu bằng chữ AppBar,
  // nên chỉ đúng node của bàn khớp startsWith.
  await tab.semantics();
  return tab.eval(`(() => {
    const e = [...document.querySelectorAll('flt-semantics')]
      .find((n) => (n.getAttribute('aria-label') || n.textContent || '').trim().startsWith('Bàn mô phỏng'));
    const r = e.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width };
  })()`);
}

function toPx(r, [x, y]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [r.x + (x + FRAME) * s, r.y + (y + FRAME) * s];
}

async function drag(fromCm, toCm) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= 12; i++) {
    // Dồn hết mouseMoved vào một khung hình thì Flutter không nhận ra kéo.
    await sleep(30);
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / 12, y: y0 + ((y1 - y0) * i) / 12, button: 'left', buttons: 1,
    });
  }
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(1000);
}

async function capture(name) {
  const label = await summary();
  console.log(`${name}: ${label}`);
  await tab.shot(path.join(shots, `${name}.png`));
  return label;
}

// 5–8 là để chủ app so áp phê: bi cái phải chạm băng thì áp phê mới đổi gì.
async function captureBank(name) {
  const label = await capture(name);
  if (!label?.includes('Dội băng')) throw new Error(`${name}: bi cái không dội băng — không so được áp phê`);
}

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });
  await tab.goto(`${APP}/training/simulator`);
  await tab.waitForText('Bàn mô phỏng');
  if (!(await summary()).includes('góc cắt')) throw new Error('nhãn của bàn không có góc cắt');

  await capture('1-mac-dinh-dung-bi-70');
  await tab.click('Đánh trô bi');
  await capture('2-tro-70');
  await tab.click('Đánh cu lê');
  await capture('3-cu-le-70');
  await tab.click('Mạnh 95%');
  await capture('4-cu-le-95');

  await tab.click('Đánh đứng bi');
  // (150,25): góc cắt ~31° vào góc trên phải; đứng bi 95% dội băng dọc mà
  // không chết cái — tìm bằng bestPocket + simulateCueBall, không đoán.
  await drag([170, 50], [150, 25]);
  await captureBank('5-dung-bi-95-cat-31-doi-bang');
  await tab.click('Phải 1');
  await captureBank('6-ap-phe-phai-1');
  await tab.click('Trái 2');
  await captureBank('7-ap-phe-trai-2');
  await tab.click('Vừa 70%');
  await tab.click('Đánh trô bi');
  await captureBank('8-tro-70-ap-phe-trai-2');

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
