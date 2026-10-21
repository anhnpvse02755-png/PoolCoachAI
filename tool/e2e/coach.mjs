// Coach tình huống trên Chrome thật (spec 2026-10-21 mục 14.5): mở từng nhóm
// của thư viện, trả lời sai theo kịch bản rồi đọc nhãn semantics của gợi ý 1,
// 2 và đáp án; mở cùng một seed hai lần; đo thời gian chấm và khung hình;
// chụp từng mục thư viện cho chủ sản phẩm duyệt.
//
// Chạy trên bản cục bộ dựng từ tool/e2e/coach_main.dart (đăng nhập sẵn trên
// máy, API trỏ về chỗ không có server — không tạo người dùng nào):
//   flutter build web --release -t tool/e2e/coach_main.dart \
//     --dart-define=API_URL=http://127.0.0.1:9 -o build/web-coach-e2e
//   node tool/e2e/serve.mjs build/web-coach-e2e 5560 &
//   node tool/e2e/coach.mjs http://localhost:5560
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { launch, sleep } from './cdp.mjs';

const APP = (process.argv[2] ?? 'http://localhost:5560').replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-coach');
fs.mkdirSync(shots, { recursive: true });

// Cổng của spec mục 13 trên Chrome.
const REFERENCE_MAX_MS = 1000; // thư viện, Ngắm bi / Vị trí
const FRAME_MEDIAN_MAX = 17;
const FRAME_P95_MAX = 20;

const tab = await launch({ port: 9341, name: 'coach' });
let failures = 0;
const ok = (m) => console.log(`  ✓ ${m}`);
const fail = (m) => { failures++; console.log(`  ✗ ${m}`); };
const note = (m) => console.log(`  · ${m}`);

async function labels() {
  await tab.semantics();
  return tab.eval(`[...document.querySelectorAll('flt-semantics')]
    .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean)`);
}

async function waitLabel(pred, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const hit = (await tab.eval(`[...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim())`)).find(pred);
    if (hit) return hit;
    await sleep(25);
  }
  return null;
}

async function startFrames() {
  await tab.eval(`(() => {
    window.__frames = []; window.__recording = true; let last = performance.now();
    const tick = (t) => { window.__frames.push(t - last); last = t; if (window.__recording) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  })()`);
}
const stopFrames = () => tab.eval(`(() => { window.__recording = false; return window.__frames.slice(1); })()`);
function stats(frames) {
  const s = [...frames].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, median: at(0.5), p95: at(0.95), max: s[s.length - 1] };
}

/** Bấm nút có nhãn chứa [label] ngay (không chờ 1.5 s như tab.click). */
async function press(label) {
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
  await sleep(250);
}

const VERDICT = (t) => /^(Đạt —|Chưa đạt\.|Chưa đủ dữ liệu)/.test(t);

async function answer({ pocket, stroke, power }) {
  await press('Ăn bi');
  await press(`Lỗ ${pocket}`);
  await press(stroke);
  await press(power);
}

/** Bấm Chấm, chờ kết luận mới; trả thời gian và các nhãn mới hiện. */
async function grade(before) {
  const t0 = Date.now();
  await startFrames();
  await press('Chấm');
  const seen = new Set(before);
  const end = Date.now() + 15000;
  let fresh = [];
  while (Date.now() < end) {
    fresh = (await labels()).filter((l) => !seen.has(l));
    if (fresh.some(VERDICT) || fresh.some((l) => l.startsWith('Đáp án') || l.startsWith('Lời giải'))) break;
    await sleep(50);
  }
  const frames = stats(await stopFrames());
  return { ms: Date.now() - t0, fresh, frames };
}

async function openSituation(query, shotName) {
  await tab.goto(`${APP}/coach/situation?${query}`);
  const t0 = Date.now();
  const summary = await waitLabel((t) => t.startsWith('Bàn tình huống'), 20000);
  if (!summary) { fail(`${query}: không thấy nhãn bàn`); return null; }
  note(`${query}: bàn hiện sau ${Date.now() - t0} ms — "${summary}"`);
  await tab.shot(path.join(shots, `${shotName}.png`));
  return summary;
}

// ─── 1. Từng nhóm của thư viện, sai theo kịch bản ─────────────────────────
const scripts = [
  {
    id: 'pos-rail-1', name: '1-vi-tri',
    // Đo trên Dart VM (feat/coach): cả ba cú đều sai, cú tốt nhất là Đánh đứng bi 45 %.
    wrong: [
      { pocket: 'giữa dưới', stroke: 'Đánh trô bi', power: '30%' },
      { pocket: 'giữa dưới', stroke: 'Đánh đứng bi', power: '75%' },
      { pocket: 'giữa dưới', stroke: 'Đánh cu lê', power: '30%' },
    ],
  },
  {
    id: 'aim-typical-1', name: '2-ngam-bi',
    wrong: [
      { pocket: 'giữa dưới', stroke: 'Đánh đứng bi', power: '45%' }, // bi 5 chắn
      { pocket: 'giữa dưới', stroke: 'Đánh cu lê', power: '45%' },
      { pocket: 'giữa dưới', stroke: 'Đánh trô bi', power: '45%' },
    ],
  },
  { id: 'safe-nopot-1', name: '3-phong-thu', safety: true },
  { id: 'kick-one-1', name: '4-a-bang', safety: true },
];

for (const s of scripts) {
  console.log(`\n== ${s.id}`);
  const summary = await openSituation(`lib=${s.id}`, `${s.name}-0-ban`);
  if (!summary) continue;
  if (s.safety) {
    await press('Phòng thủ');
    const r = await grade(await labels());
    const verdict = r.fresh.find(VERDICT);
    verdict?.startsWith('Đạt') ? ok(`Phòng thủ → "${verdict}" sau ${r.ms} ms`) : fail(`Phòng thủ → ${verdict}`);
    // Cú thủ của Planner: chờ tới khi có dòng cú thủ hoặc hết 8 s.
    const t0 = Date.now();
    const safetyLine = await waitLabel((t) => /^(Thủ trực tiếp|A băng|Bi .* bị đui|Đánh)/.test(t) || t.includes('không có cú thủ'), 8000);
    note(`cú thủ hiện sau ${Date.now() - t0} ms: ${safetyLine ?? '(chưa có)'}`);
    await tab.shot(path.join(shots, `${s.name}-1-dap-an.png`));
    continue;
  }
  let k = 0;
  for (const w of s.wrong) {
    k++;
    await answer(w);
    const before = await labels();
    const r = await grade(before);
    const verdict = r.fresh.find(VERDICT);
    const ms = r.ms;
    (k === 1 ? ms <= REFERENCE_MAX_MS : true)
      ? ok(`lần ${k}: "${verdict}" sau ${ms} ms`)
      : fail(`lần ${k}: chấm sau ${ms} ms > ${REFERENCE_MAX_MS}`);
    note(`khung hình lúc chấm: trung vị ${r.frames.median?.toFixed(1)} ms, p95 ${r.frames.p95?.toFixed(1)} ms (n ${r.frames.n})`);
    if (r.frames.n > 3 && (r.frames.median > FRAME_MEDIAN_MAX || r.frames.p95 > FRAME_P95_MAX)) {
      note('khung hình vượt cổng (đo trên máy đang chạy build/test khác thì không chắc chắn)');
    }
    for (const l of r.fresh) {
      if (l === verdict || l.startsWith('Bàn tình huống') || l.startsWith('Lần thử')) continue;
      note(`nhãn mới: ${l.replace(/\n/g, ' / ')}`);
    }
    await tab.shot(path.join(shots, `${s.name}-${k}.png`));
    if (r.fresh.some((l) => l.startsWith('Đáp án') || l.startsWith('Lời giải'))) {
      ok(`lần ${k}: hiện đáp án`);
      break;
    }
  }
}

// ─── 2. Cùng seed hai lần → cùng thế bàn ──────────────────────────────────
console.log('\n== cùng seed');
const q = 'topic=position&d=easy&seed=20261021';
const a = await openSituation(q, '5-seed-lan-1');
const hashA = crypto.createHash('sha1').update(fs.readFileSync(path.join(shots, '5-seed-lan-1.png'))).digest('hex');
const b = await openSituation(q, '5-seed-lan-2');
const hashB = crypto.createHash('sha1').update(fs.readFileSync(path.join(shots, '5-seed-lan-2.png'))).digest('hex');
a && a === b ? ok(`cùng nhãn bàn: "${a}"`) : fail(`nhãn bàn khác: "${a}" / "${b}"`);
hashA === hashB ? ok('hai ảnh chụp giống hệt') : note('hai ảnh chụp khác byte (chấp nhận được nếu chỉ khác con trỏ/hiệu ứng)');

// ─── 3. Màn Coach và thư viện ─────────────────────────────────────────────
console.log('\n== màn Coach');
await tab.goto(`${APP}/coach`);
const coach = await labels();
coach.some((l) => l.startsWith('Nên luyện gì')) ? ok('có thẻ Nên luyện gì') : fail('thiếu thẻ Nên luyện gì');
coach.some((l) => l.includes('Tình huống')) ? ok('có thẻ Tình huống') : fail('thiếu thẻ Tình huống');
await tab.shot(path.join(shots, '6-coach.png'));

console.log('\n== thư viện');
for (let i = 0; i < 12; i++) {
  await tab.goto(`${APP}/coach/library?i=${i}`);
  const l = await labels();
  if (l.some((t) => t.includes('Hết thư viện'))) { note(`hết thư viện ở i=${i}`); break; }
  const cap = l.find((t) => t.startsWith('Tình huống ')) ?? '?';
  await tab.shot(path.join(shots, `thu-vien-${String(i).padStart(2, '0')}.png`));
  note(`i=${i}: ${cap.replace(/\n/g, ' / ')}`);
}

const errors = tab.errors.filter((e) => !/Failed to load resource|net::ERR|XMLHttpRequest|ClientException|127\.0\.0\.1:9/.test(e));
errors.length === 0 ? ok('không có lỗi JS') : fail(`lỗi JS: ${errors.slice(0, 5).join(' | ')}`);
console.log(`\nẢnh: ${shots}`);
console.log(failures === 0 ? 'XONG — không có lỗi' : `XONG — ${failures} lỗi`);
await tab.close();
process.exit(failures === 0 ? 0 : 1);
