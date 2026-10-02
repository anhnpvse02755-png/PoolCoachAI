// Mở Mô phỏng góc cắt trên Chrome thật: đọc nhãn semantics của bàn, chụp từng cảnh,
// và đo thời gian khung hình lúc kéo bi trên Chrome giả lập điện thoại.
//   node tool/e2e/simulator.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó: thiếu
// biến thì dừng ngay, đừng để user thử rò rỉ trên bản thật (như accounts.mjs).
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-sim');
const email = `e2e-sim-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

// Bố cục tìm bằng aimShot trên Dart VM với bi cái ở chỗ mở màn (80, 90) —
// không đoán. Bi mục tiêu bắt đầu ở (170, 50).
const START = [170, 50];
const STRAIGHT = [177.81, 110.8]; // thẳng hàng bi cái → lỗ góc dưới phải, góc cắt 0°
const HALF_BALL = [170, 70]; // ~29° vào lỗ góc trên phải
const TWO_RAILS = [150, 40]; // đứng bi 60 %: bi cái chạm 2 băng
const FAR = [220, 40]; // đứng bi 30 %: đặt cơ dưới tâm ~1.25 đầu cơ

// Kéo bi không được rớt khung (spec mục 5): trung vị và p95 khoảng cách
// giữa hai khung hình (ms) lúc kéo, trên Chrome giả lập điện thoại
// (cdp.mjs đặt 412x915, mobile). 60 Hz là 16.7 ms; chừa nhiễu vsync.
const FRAME_MEDIAN_MAX = 17;
const FRAME_P95_MAX = 20;

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

/** Kéo bi từ [fromCm] tới [toCm]; trả khoảng cách giữa các khung hình (ms) lúc kéo. */
async function drag(fromCm, toCm, { moves = 12 } = {}) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.eval(`(() => {
    window.__frames = [];
    window.__recording = true;
    let last = performance.now();
    const tick = (t) => {
      window.__frames.push(t - last);
      last = t;
      if (window.__recording) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  })()`);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= moves; i++) {
    // Dồn hết mouseMoved vào một khung hình thì Flutter không nhận ra kéo.
    await sleep(30);
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / moves, y: y0 + ((y1 - y0) * i) / moves, button: 'left', buttons: 1,
    });
  }
  // Khung đầu đo từ lúc bật bộ ghi, không phải khoảng giữa hai khung: bỏ.
  const frames = await tab.eval(`(() => { window.__recording = false; return window.__frames.slice(1); })()`);
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
  // Thả tay thì gợi ý chống chết cái tính dần: chờ hết "Đang tính…".
  await sleep(500);
  for (let i = 0; i < 30 && (await tab.text()).includes('Đang tính…'); i++) await sleep(500);
  return frames;
}

function stats(frames) {
  const s = [...frames].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, median: at(0.5), p95: at(0.95), max: s[s.length - 1] };
}

async function capture(name, mustInclude = []) {
  const label = await summary();
  console.log(`${name}: ${label}`);
  await tab.shot(path.join(shots, `${name}.png`));
  for (const needle of mustInclude) {
    if (!label?.includes(needle)) throw new Error(`${name}: nhãn của bàn thiếu "${needle}"`);
  }
  return label;
}

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });
  await tab.goto(`${APP}/training/simulator`);
  await tab.waitForText('Bàn mô phỏng');
  await capture('0-mac-dinh-dung-bi-45', ['góc cắt', 'Độ dốc cơ: Thường']);

  // Đo khung hình trước khi chụp các cảnh: kéo qua lại quanh chỗ mở màn.
  const free = stats([
    ...(await drag(START, TWO_RAILS, { moves: 24 })),
    ...(await drag(TWO_RAILS, START, { moves: 24 })),
  ]);
  console.log(`Khung hình lúc kéo (giả lập điện thoại): ${JSON.stringify(free)}`);
  // Thêm một lượt ở CPU chậm 4 lần, chỉ để chủ sản phẩm tham khảo.
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  const slow = stats(await drag(START, TWO_RAILS, { moves: 24 }));
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await drag(TWO_RAILS, START);
  console.log(`Khung hình lúc kéo, CPU chậm 4 lần (tham khảo): ${JSON.stringify(slow)}`);

  // 1. Cu lê bắn thẳng · trô bắn thẳng.
  await drag(START, STRAIGHT);
  await tab.click('Đánh cu lê');
  await capture('1a-cu-le-thang-45', ['góc cắt 0°']);
  await tab.click('Đánh trô bi');
  await capture('1b-tro-thang-45', ['góc cắt 0°']);

  // 2. Cu lê cắt nửa bi: thấy đoạn cong rồi thẳng.
  await drag(STRAIGHT, HALF_BALL);
  await tab.click('Đánh cu lê');
  await capture('2-cu-le-cat-nua-bi-45');

  // 4. Áp phê phải 1 đầu cơ, bật và tắt Xem nếu không bù ném.
  await tab.click('Phải 1');
  await capture('4a-ap-phe-phai-1');
  await tab.click('Xem nếu không bù ném');
  await capture('4b-ap-phe-phai-1-khong-bu-nem', ['Đang xem đường không bù ném']);
  await tab.click('Xem nếu không bù ném');

  // 5. Cùng áp phê, cơ Thường rồi cơ Dốc: thấy swerve.
  await capture('5a-co-thuong', ['Độ dốc cơ: Thường']);
  await tab.click('Dốc');
  await capture('5b-co-doc', ['Độ dốc cơ: Dốc']);
  await tab.click('Thường');

  // 3. Bi cái chạm 2–3 băng.
  await tab.click('Không');
  await tab.click('Đánh đứng bi');
  await tab.click('60%');
  await drag(HALF_BALL, TWO_RAILS);
  await capture('3-dung-bi-60-cham-bang', ['Bi cái chạm băng']);

  // 6. Đánh đứng bi ở xa: dòng đặt cơ dưới tâm.
  await tab.click('30%');
  await drag(TWO_RAILS, FAR);
  await tab.waitForText('Đánh đứng bi: đặt cơ dưới tâm');
  await capture('6-dung-bi-xa-30');

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  if (free.median > FRAME_MEDIAN_MAX || free.p95 > FRAME_P95_MAX) {
    throw new Error(`Kéo bi rớt khung: trung vị ${free.median.toFixed(1)} ms, p95 ${free.p95.toFixed(1)} ms`);
  }
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
