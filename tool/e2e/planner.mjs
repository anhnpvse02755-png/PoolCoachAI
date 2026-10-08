// Mở Kế hoạch dọn bàn trên Chrome thật: bày bảy bàn (ba bàn cú thủ), đo thời gian ra bước 1
// và thời gian khung hình lúc đang tính, chụp từng bước, kiểm luồng đặt lại
// bi cái.
//   node tool/e2e/planner.mjs [appUrl]
// Chạy local thì serve ở cổng 5555 — Directus chỉ cho CORS từ cổng đó và từ bản thật.
import os from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

// Bài này luôn tạo user thật trên Directus, nên phải có quyền xoá nó (như simulator.mjs).
const need = (n) => process.env[n] ?? (() => { throw new Error(`Thiếu ${n}`); })();
need('DIRECTUS_URL');
need('DIRECTUS_ADMIN_PASSWORD');

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-planner');
const email = `e2e-plan-${Date.now()}@poolcoachai.example.com`;

// Phải khớp TableLayout.frame và TableSpec của app.
const FRAME = 8;
const LENGTH = 254;

// Spec mục 10.3: bước 1 khoảng 1 giây trên Chrome giả lập điện thoại; khung
// hình lúc đang tính như màn mô phỏng.
const FIRST_STEP_MAX_MS = 1000;
const FRAME_MEDIAN_MAX = 17;
const FRAME_P95_MAX = 20;

// Spec cú phòng thủ mục 6: bước thủ ra trong "vài giây" — đọc là ≤ 5 s
// (độ lệch 20 của kế hoạch), tính tới lúc bước thủ hiện ra (điểm hỏi, cú tạm,
// hay hết lượt tìm khi lượt thô không có cú).
const SAFETY_MAX_MS = 5000;

// Bi chắn ở miệng lỗ — đúng jawBlocker của test/support/planner_tables.dart.
const jaw = (ball, [px, py], d = 14) => {
  const dx = ball[0] - px, dy = ball[1] - py, l = Math.hypot(dx, dy);
  return [px + (dx / l) * d, py + (dy / l) * d];
};
const NO_POT_BALL = [150, 40];

// Điểm hỏi và cú tạm của cú thủ (chủ sản phẩm chốt 08/10/2026 sau Task 25).
const CHECKPOINT = 'Bạn muốn tính tiếp hay không?';
const PROVISIONAL = 'đang tìm cú tốt hơn';

// Bảy bàn — đúng toạ độ của test/support/planner_tables.dart.
const RING = [[116.27, 58.13], [127, 51.5], [137.73, 58.13], [116.27, 68.87], [127, 75.5], [137.73, 68.87]];
const TABLES = [
  { name: '1-9bi-de', game: '9 bi', cue: [127, 63.5], balls: [[200, 8], [60, 40], [127, 100], [220, 100]] },
  {
    name: '2-9bi-bi-chan', game: '9 bi', cue: [64, 63.5], gate: true, reset: true,
    balls: [[127, 100], [200, 8], [60, 40], [220, 100], [127, 115], [40, 105], [175, 60], [95, 20], [230, 40]],
  },
  {
    name: '3-8bi-doi-thu', game: '8 bi', group: 'Trơn', cue: [64, 63.5],
    balls: [
      ['Bi của tôi', [127, 100]], ['Bi của tôi', [200, 8]], ['Bi của tôi', [95, 20]],
      ['Bi đối thủ', [127, 115]], ['Bi đối thủ', [175, 60]], ['Bi 8', [220, 100]],
    ],
  },
  { name: '4-phong-thu', game: '9 bi', cue: [40, 100], balls: [[127, 63.5], ...RING] },
  // Cú phòng thủ — đúng toạ độ của snookerOneRailTable, noPotTable, eightSafetyTable.
  // ask: nút bấm ở điểm hỏi; không có thì bàn không được hỏi (đo trên VM, Task 25b).
  { name: '5-9bi-dui-a-bang', game: '9 bi', cue: [30, 80], balls: [[180, 80], [105, 80]], safety: true, ask: 'Dùng cú này' },
  {
    name: '6-9bi-het-duong', game: '9 bi', cue: [60, 100], safety: true, gateSafety: true, ask: 'Tính tiếp',
    balls: [NO_POT_BALL, jaw(NO_POT_BALL, [254, 0]), jaw(NO_POT_BALL, [254, 127])],
  },
  {
    name: '7-8bi-thu', game: '8 bi', group: 'Trơn', cue: [60, 100], safety: true, provisional: true,
    balls: [
      ['Bi của tôi', NO_POT_BALL], ['Bi đối thủ', jaw(NO_POT_BALL, [254, 0])],
      ['Bi đối thủ', jaw(NO_POT_BALL, [254, 127])], ['Bi 8', [40, 20]],
    ],
  },
];

// Chỗ thả bi cái khi đặt lại (spec mục 4.5).
const RESET_TO = [100, 40];

const tab = await launch({ port: 9336, name: 'ke-hoach' });

/** Nhãn đầu tiên bắt đầu bằng [prefix], đọc thẳng không bấm lại semantics. */
async function labelStarting(prefix) {
  return tab.eval(`[...document.querySelectorAll('flt-semantics')]
    .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim())
    .find((t) => t.startsWith(${JSON.stringify(prefix)})) ?? null`);
}

async function waitLabel(prefix, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const hit = await labelStarting(prefix);
    if (hit) return hit;
    await sleep(25);
  }
  return null;
}

/** Như tab.click nhưng không chờ 1.5 s sau khi bấm — để đo thời gian. */
async function clickNow(label) {
  const r = await tab.eval(`(() => {
    const hits = [...document.querySelectorAll('flt-semantics')]
      .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
      .filter((x) => x.t.includes(${JSON.stringify(label)}))
      .sort((a, b) => (a.e.getAttribute('role') === 'button' ? 0 : 1) - (b.e.getAttribute('role') === 'button' ? 0 : 1)
        || a.t.length - b.t.length);
    if (!hits.length) return null;
    hits[0].e.click();
    return hits[0].t;
  })()`);
  if (r == null) throw new Error(`không có nút "${label}"`);
}

async function tableRect() {
  await tab.semantics();
  return tab.eval(`(() => {
    const e = [...document.querySelectorAll('flt-semantics')]
      .find((n) => /^(Bàn bày bi|Bàn kế hoạch)/.test((n.getAttribute('aria-label') || n.textContent || '').trim()));
    const r = e.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height };
  })()`);
}

function toPx(r, [x, y]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [r.x + (x + FRAME) * s, r.y + (y + FRAME) * s];
}

function toCm(r, [px, py]) {
  const s = r.w / (LENGTH + 2 * FRAME);
  return [(px - r.x) / s - FRAME, (py - r.y) / s - FRAME];
}

async function tapCm(r, cm) {
  const [x, y] = toPx(r, cm);
  // Bật semantics thì nút semantics của bàn (có onTapUp) nuốt cú chạm chuột
  // và Flutter coi là SemanticsAction.tap ở giữa bàn: mọi bi rơi vào tâm.
  // Cho chuột xuyên qua node đó để cú chạm tới bàn đúng chỗ, như ngón tay thật.
  await tab.eval(`[...document.querySelectorAll('flt-semantics')]
    .filter((n) => (n.getAttribute('aria-label') || n.textContent || '').trim().startsWith('Bàn bày bi'))
    .forEach((n) => { n.style.pointerEvents = 'none'; })`);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(150);
}

async function startFrames() {
  await tab.eval(`(() => {
    window.__frames = [];
    window.__recording = true;
    let last = performance.now();
    const tick = (t) => { window.__frames.push(t - last); last = t; if (window.__recording) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  })()`);
}

async function stopFrames() {
  // Khung đầu đo từ lúc bật bộ ghi, không phải khoảng giữa hai khung: bỏ.
  return tab.eval(`(() => { window.__recording = false; return window.__frames.slice(1); })()`);
}

function stats(frames) {
  const s = [...frames].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, median: at(0.5), p95: at(0.95), max: s[s.length - 1] };
}

async function dragCm(fromCm, toCm, moves = 16) {
  const r = await tableRect();
  const [x0, y0] = toPx(r, fromCm);
  const [x1, y1] = toPx(r, toCm);
  await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: x0, y: y0, button: 'left', buttons: 1, clickCount: 1 });
  for (let i = 1; i <= moves; i++) {
    // Dồn hết mouseMoved vào một khung hình thì Flutter không nhận ra kéo.
    await sleep(30);
    await tab.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved', x: x0 + ((x1 - x0) * i) / moves, y: y0 + ((y1 - y0) * i) / moves, button: 'left', buttons: 1,
    });
  }
  await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x1, y: y1, button: 'left', buttons: 0, clickCount: 1 });
}

/**
 * Tâm bi cái (cm) đọc từ ảnh chụp: vùng liền lớn nhất màu AppColors.ballCue
 * trong khung bàn. Bi số cũng có vòng tròn trong màu này nhưng chỉ 0.55 bán
 * kính và có chữ số đè lên, nên vùng lớn nhất là bi cái. Bi cái khi đặt lại
 * bắt đầu ở chỗ dừng dự kiến của bước đang xem — nhãn semantics không nói
 * chỗ đó, nên phải nhìn ảnh.
 */
async function findCueCm() {
  const r = await tableRect();
  const shot = await tab.send('Page.captureScreenshot', { format: 'png' });
  const px = await tab.eval(`(async () => {
    const img = new Image();
    img.src = 'data:image/png;base64,${shot.data}';
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const x0 = Math.floor(${r.x}), y0 = Math.floor(${r.y});
    const w = Math.ceil(${r.w}), h = Math.ceil(${r.h});
    const d = g.getImageData(x0, y0, w, h).data;
    const cue = (i) => Math.abs(d[i] - 0xF7) < 14 && Math.abs(d[i + 1] - 0xF3) < 14 && Math.abs(d[i + 2] - 0xE8) < 16;
    const seen = new Uint8Array(w * h);
    let best = null;
    for (let s = 0; s < w * h; s++) {
      if (seen[s] || !cue(s * 4)) continue;
      const stack = [s]; seen[s] = 1;
      let n = 0, sx = 0, sy = 0;
      while (stack.length) {
        const k = stack.pop(); const kx = k % w, ky = (k - kx) / w;
        n++; sx += kx; sy += ky;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = kx + dx, ny = ky + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          const q = ny * w + nx;
          if (!seen[q] && cue(q * 4)) { seen[q] = 1; stack.push(q); }
        }
      }
      if (!best || n > best.n) best = { n, x: x0 + sx / n + 0.5, y: y0 + sy / n + 0.5 };
    }
    return best;
  })()`);
  if (!px) throw new Error('không thấy bi cái trên ảnh');
  return toCm(r, [px.x, px.y]);
}

/**
 * Spec 10.3 đo khung hình "trong lúc kéo và cuộn khi đang tính": bơm input
 * thật cho tới khi gọi hàm trả về. Lăn chuột trên bảng dưới bàn (cuộn bảng
 * thông tin) xen với kéo chuột trên bàn. Trả về hàm dừng; dừng thì cuộn bảng
 * về đầu để ảnh chụp sau đó giống lúc chưa cuộn.
 */
function agitate(r) {
  const panelX = r.x + r.w / 2;
  const panelY = r.y + r.h + 200;
  let running = true;
  let wheels = 0, drags = 0;
  const loop = (async () => {
    let dir = 1;
    while (running) {
      for (let i = 0; i < 8 && running; i++) {
        await tab.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: panelX, y: panelY, deltaX: 0, deltaY: 60 * dir });
        wheels++;
        await sleep(16);
      }
      dir = -dir;
      if (!running) break;
      const [ax, ay] = toPx(r, [60, 30]);
      const [bx, by] = toPx(r, [190, 95]);
      await tab.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: ax, y: ay, button: 'left', buttons: 1, clickCount: 1 });
      for (let i = 1; i <= 8 && running; i++) {
        await sleep(16);
        await tab.send('Input.dispatchMouseEvent', {
          type: 'mouseMoved', x: ax + ((bx - ax) * i) / 8, y: ay + ((by - ay) * i) / 8, button: 'left', buttons: 1,
        });
      }
      await tab.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: bx, y: by, button: 'left', buttons: 0, clickCount: 1 });
      drags++;
    }
  })();
  return async () => {
    running = false;
    await loop;
    for (let i = 0; i < 10; i++) {
      await tab.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: panelX, y: panelY, deltaX: 0, deltaY: -400 });
    }
    await sleep(300);
    return { wheels, drags };
  };
}

/** Các dòng của bảng thông tin bước đang xem (spec 7.2), từ "Bước k / N" tới hết thẻ. */
async function stepCardLines() {
  const all = await tab.labels();
  const start = all.findIndex((t) => /^Bước \d+ \/ \d+/.test(t));
  if (start < 0) return [];
  const out = [];
  for (let i = start; i < all.length; i++) {
    if (i > start && (/^Bước \d+ \/ \d+/.test(all[i]) || all[i] === 'XEM TRƯỚC' || all[i].startsWith('←')
      || all[i].startsWith('Đã đánh xong') || all[i] === 'Xong bàn')) break;
    out.push(all[i]);
  }
  return out;
}

async function waitPlanDone() {
  for (let i = 0; i < 1200; i++) {
    const text = await tab.text();
    if (!text.includes('Đang tính bước') && !text.includes('Đang tìm cú thủ') && !text.includes(PROVISIONAL)) return;
    await sleep(250);
  }
}

const results = [];
let frameStats = null;
let safetyFrames = null;

try {
  await registerThrowaway(tab, APP, { email, password: randomBytes(6).toString('hex') });

  for (const t of TABLES) {
    await tab.goto(`${APP}/training/planner`);
    await tab.waitForText('Bàn bày bi');
    await tab.click(t.game);
    if (t.group) await tab.click(t.group);
    const r = await tableRect();
    await tapCm(r, t.cue);
    for (const b of t.balls) {
      if (typeof b[0] === 'string') {
        await tab.click(b[0]);
        await tapCm(await tableRect(), b[1]);
      } else {
        await tapCm(r, b);
      }
    }
    const setup = await labelStarting('Bàn bày bi');
    if (!setup?.includes(`${t.balls.length} bi mục tiêu`)) throw new Error(`${t.name}: bày bi sai — ${setup}`);
    await tab.shot(path.join(shots, `${t.name}-0-bay-ban.png`));

    let stopInput = null;
    if (t.gate || t.gateSafety) await startFrames();
    const t0 = Date.now();
    await clickNow('Lập kế hoạch');
    // Bơm input sau khi bấm: kéo trên màn nhập bàn thì dời bi mất. Máy bận
    // thì màn nhập bàn còn trên màn sau cú bấm (lăn chuột cuộn nó, bi bị
    // kéo dời), nên đợi màn kế hoạch hiện ra rồi mới bơm.
    if (t.gate || t.gateSafety) {
      await waitLabel('Bàn kế hoạch.', 15000);
      stopInput = agitate(r);
    }
    const first = await waitLabel('Bàn kế hoạch. Bước 1 /', t.safety ? 300000 : 15000);
    const firstMs = Date.now() - t0;
    if (!first) throw new Error(`${t.name}: không thấy bước 1`);
    console.log(`${t.name}: bước 1 sau ${firstMs} ms — ${first}`);
    const sawProvisional = (await tab.text()).includes(PROVISIONAL);
    if (sawProvisional) await tab.shot(path.join(shots, `${t.name}-cu-tam.png`));
    // Bàn 4 cũng đi qua lượt tìm cú thủ nhưng không đo trên VM: chỉ in, không kiểm.
    if (t.safety && Boolean(t.provisional) !== sawProvisional) {
      throw new Error(`${t.name}: ${sawProvisional ? 'có' : 'không có'} cú tạm — khác lúc đo trên VM`);
    }
    await waitPlanDone();
    const doneMs = Date.now() - t0;
    if (t.gate) {
      frameStats = stats(await stopFrames());
      const input = await stopInput();
      console.log(`  khung hình lúc đang tính sau Lập kế hoạch: ${JSON.stringify(frameStats)}; input ${JSON.stringify(input)}`);
    }
    if (t.gateSafety) {
      safetyFrames = stats(await stopFrames());
      const input = await stopInput();
      console.log(`  khung hình lúc tìm cú thủ: ${JSON.stringify(safetyFrames)}; input ${JSON.stringify(input)}`);
    }
    // Lượt thô thủ tốt thì màn hỏi có tính tiếp không. firstMs là tới lúc
    // bước hiện ra; "Tính tiếp" chỉ in thời gian.
    let continueMs = null;
    const asked = (await tab.text()).includes(CHECKPOINT);
    if (t.safety || asked || sawProvisional) {
      if (t.safety && Boolean(t.ask) !== asked) {
        throw new Error(`${t.name}: ${asked ? 'có' : 'không có'} điểm hỏi — khác lúc đo trên VM`);
      }
      if (asked) {
        // Bàn không đo trên VM mà bị hỏi thì tính tiếp — ra cú của lượt tìm đủ.
        const ask = t.ask ?? 'Tính tiếp';
        await tab.shot(path.join(shots, `${t.name}-diem-hoi.png`));
        const t2 = Date.now();
        await clickNow(ask);
        await sleep(100);
        await waitPlanDone();
        continueMs = Date.now() - t2;
        console.log(`  điểm hỏi → ${ask}: xong sau ${continueMs} ms`);
      }
      if (sawProvisional) {
        const last = await labelStarting('Bàn kế hoạch. Bước 1 /');
        console.log(`  cú tạm sau ${firstMs} ms, cú cuối sau ${doneMs} ms — ${last === first ? 'giữ cú tạm' : last}`);
      }
    }

    const labels = [];
    for (let i = 0; i < 16; i++) {
      const label = await labelStarting('Bàn kế hoạch.');
      labels.push(label);
      console.log(`  ${label}`);
      for (const line of await stepCardLines()) console.log(`      ${line}`);
      await tab.shot(path.join(shots, `${t.name}-${i + 1}.png`));
      const text = await tab.text();
      if (text.includes('Xong bàn')) break;
      await tab.click('Đã đánh xong');
      await tab.click('Đúng');
    }
    if (t.reset) {
      // Đi hết kế hoạch để chụp đủ các bước rồi mới quay về bước 1 thử đặt
      // lại bi cái — đặt lại thì kế hoạch cũ mất.
      // Có mũi tên: nút back của AppBar cũng có nhãn "Quay lại".
      for (let k = 1; k < labels.length; k++) await tab.click('← Quay lại');
      const back = await labelStarting('Bàn kế hoạch.');
      if (!back?.startsWith('Bàn kế hoạch. Bước 1 /')) throw new Error(`${t.name}: không về được bước 1 — ${back}`);
      // Luồng đặt lại bi cái: kéo bi cái tới chỗ khác rồi tính lại.
      await tab.click('Đã đánh xong');
      await tab.click('Đặt lại bi cái');
      const from = await findCueCm();
      console.log(`  bi cái lúc đặt lại ở (${from.map((v) => v.toFixed(1)).join(', ')}) cm`);
      await tab.shot(path.join(shots, `${t.name}-dat-lai-truoc-keo.png`));
      await startFrames();
      await dragCm(from, RESET_TO);
      await sleep(300);
      const dropped = await findCueCm();
      console.log(`  kéo tới (${dropped.map((v) => v.toFixed(1)).join(', ')}) cm`);
      if (Math.hypot(dropped[0] - RESET_TO[0], dropped[1] - RESET_TO[1]) > 4) {
        throw new Error(`${t.name}: kéo không bắt được bi cái — vẫn ở (${dropped.join(', ')})`);
      }
      const rr = await tableRect();
      await clickNow('Tính lại từ đây');
      const stop = agitate(rr);
      const again = await waitLabel('Bàn kế hoạch. Bước 1 /', 15000);
      await waitPlanDone();
      const resetFrames = stats(await stopFrames());
      const input = await stop();
      console.log(`  đặt lại bi cái → ${again}; khung hình: ${JSON.stringify(resetFrames)}; input ${JSON.stringify(input)}`);
      for (const line of await stepCardLines()) console.log(`      ${line}`);
      if (!again?.includes('Bước 1 / 8')) throw new Error(`${t.name}: tính lại không bỏ bi đã đánh — ${again}`);
      if (again.includes('bi 1,')) throw new Error(`${t.name}: tính lại vẫn đánh bi 1`);
      await tab.shot(path.join(shots, `${t.name}-dat-lai.png`));
      // Cổng khung hình lấy lượt xấu hơn: đang tính sau Lập kế hoạch, hay
      // kéo bi cái rồi tính lại.
      if (resetFrames.p95 > frameStats.p95) frameStats = resetFrames;
    }
    results.push({ table: t.name, firstMs, doneMs, steps: labels.length, continueMs });

    if (t.name.startsWith('3-')) {
      if (labels.some((l) => /bi (9|10),/.test(l))) throw new Error('8 bi: kế hoạch đánh bi đối thủ');
      const eightAt = labels.findIndex((l) => l.includes('bi 8,'));
      if (eightAt >= 0 && eightAt !== labels.length - 1) throw new Error('8 bi: bi 8 không đánh cuối');
    }
    if (t.name.startsWith('4-') && !/nên chơi an toàn \(safety\)|nên thủ bi|để thủ\./.test(labels[0] ?? '')) {
      throw new Error(`bàn phòng thủ: ${labels[0]}`);
    }
    if (t.name.startsWith('5-')) {
      if (!labels[0]?.includes('Bi cái bị đui bi 1 — đánh A băng để thủ.') || !/A băng \d băng: ngắm chấm/.test(labels[0])) {
        throw new Error(`bàn đui: ${labels[0]}`);
      }
    }
    if (t.name.startsWith('6-')) {
      if (!labels[0]?.includes('Không còn đường ăn bi — nên thủ bi.') || !/Ăn (trọn|¾|½|¼|⅛) bi/.test(labels[0])) {
        throw new Error(`bàn hết đường ăn: ${labels[0]}`);
      }
    }
    if (t.name.startsWith('7-')) {
      if (!labels[0]?.includes('nên thủ bi')) throw new Error(`bàn 8 bi thủ: ${labels[0]}`);
      if (/đối thủ: bi 1 /.test(labels[0])) throw new Error('8 bi: đối thủ được tính đánh bi của tôi');
    }
  }

  console.log(`\nThời gian ra bước 1: ${JSON.stringify(results)}`);
  console.log(`Khung hình lúc đang tính (bàn 2, giả lập điện thoại): ${JSON.stringify(frameStats)}`);

  // Thêm một lượt ở CPU chậm 4 lần, chỉ để chủ sản phẩm tham khảo.
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await tab.goto(`${APP}/training/planner`);
  await tab.waitForText('Bàn bày bi');
  const r2 = await tableRect();
  await tapCm(r2, TABLES[1].cue);
  for (const b of TABLES[1].balls) await tapCm(r2, b);
  const t1 = Date.now();
  await clickNow('Lập kế hoạch');
  await waitLabel('Bàn kế hoạch. Bước 1 /', 30000);
  console.log(`Bước 1 ở CPU chậm 4 lần (tham khảo): ${Date.now() - t1} ms`);
  await tab.send('Emulation.setCPUThrottlingRate', { rate: 1 });

  const slowSafety = results.filter((x) => /^(5|6|7)-/.test(x.table) && x.firstMs > SAFETY_MAX_MS);
  console.log(`Khung hình lúc tìm cú thủ (bàn 6): ${JSON.stringify(safetyFrames)}`);

  const errors = tab.errors.filter((e) => !/favicon/i.test(e));
  if (errors.length) throw new Error(`Lỗi trong console:\n${errors.join('\n')}`);
  const gated = results.find((x) => x.table.startsWith('2-'));
  if (gated.firstMs > FIRST_STEP_MAX_MS) throw new Error(`Bước 1 chậm: ${gated.firstMs} ms`);
  if (frameStats.median > FRAME_MEDIAN_MAX || frameStats.p95 > FRAME_P95_MAX) {
    throw new Error(`Rớt khung lúc đang tính: trung vị ${frameStats.median.toFixed(1)} ms, p95 ${frameStats.p95.toFixed(1)} ms`);
  }
  if (slowSafety.length) {
    throw new Error(`Bước thủ chậm: ${slowSafety.map((x) => `${x.table} ${x.firstMs} ms`).join(', ')}`);
  }
  console.log(`\nXong. Ảnh ở ${shots}`);
} finally {
  await tab.close();
  await deleteUserByEmail(email);
}
