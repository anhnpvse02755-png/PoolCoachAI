// Điều khiển Chrome headless qua DevTools Protocol — đủ để lái một app Flutter web.
//
// Flutter vẽ bằng canvas, nên muốn đọc chữ và bấm nút thì phải bật cây
// semantics (bấm flt-semantics-placeholder) rồi làm việc với aria-label.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const CHROME = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Mở một Chrome riêng (profile riêng = một "máy" riêng). */
export async function launch({ port, name }) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), `pcai-${name}-`));
  const proc = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    '--no-first-run',
    'about:blank',
  ], { stdio: 'ignore' });

  let targets = null;
  for (let i = 0; i < 40 && !targets; i++) {
    try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); } catch { await sleep(250); }
  }
  if (!targets) throw new Error(`Chrome ${name} không mở cổng ${port}`);
  const page = targets.find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });

  const tab = new Tab(ws, name);
  await tab.init();
  tab.close = async () => { ws.close(); proc.kill(); };
  return tab;
}

class Tab {
  constructor(ws, name) {
    this.ws = ws;
    this.name = name;
    this.nextId = 0;
    this.pending = new Map();
    this.errors = [];
    ws.onmessage = (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id && this.pending.has(m.id)) { this.pending.get(m.id)(m); this.pending.delete(m.id); return; }
      if (m.method === 'Runtime.exceptionThrown') {
        this.errors.push(m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text);
      }
      if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') {
        this.errors.push(m.params.args.map((a) => a.value ?? a.description).join(' '));
      }
    };
  }

  send(method, params = {}) {
    return new Promise((resolve) => {
      const id = ++this.nextId;
      this.pending.set(id, resolve);
      this.ws.send(JSON.stringify({ id, method, params }));
    }).then((m) => {
      if (m.error) throw new Error(`${method}: ${m.error.message}`);
      return m.result;
    });
  }

  async init() {
    await this.send('Runtime.enable');
    await this.send('Page.enable');
    await this.send('Network.enable');
    await this.send('Emulation.setDeviceMetricsOverride', { width: 412, height: 915, deviceScaleFactor: 1, mobile: true });
  }

  async eval(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    return r.result?.value;
  }

  async semantics() {
    await this.eval(`document.querySelector('flt-semantics-placeholder')?.click()`);
    await sleep(300);
  }

  async goto(url) { await this.send('Page.navigate', { url }); await sleep(8000); await this.semantics(); }
  async reload() { await this.send('Page.reload', {}); await sleep(8000); await this.semantics(); }

  async labels() {
    await this.semantics();
    return this.eval(`[...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean)`);
  }

  async text() { return (await this.labels()).join('\n'); }

  async waitForText(needle, timeoutMs = 30000) {
    const end = Date.now() + timeoutMs;
    while (Date.now() < end) {
      if ((await this.text()).includes(needle)) return;
      await sleep(1000);
    }
    throw new Error(`[${this.name}] không thấy "${needle}" sau ${timeoutMs}ms. Đang thấy:\n${await this.text()}`);
  }

  /** Bấm node semantics khớp [label]; ưu tiên nút, rồi node có nhãn ngắn nhất. */
  async click(label) {
    await this.semantics();
    const r = await this.eval(`(() => {
      const hits = [...document.querySelectorAll('flt-semantics')]
        .map((e) => ({ e, t: (e.getAttribute('aria-label') || e.textContent || '').trim() }))
        .filter((x) => x.t.includes(${JSON.stringify(label)}))
        // Nút trước (tiêu đề AppBar có thể trùng chữ với nút), rồi nhãn ngắn nhất.
        .sort((a, b) => (a.e.getAttribute('role') === 'button' ? 0 : 1) - (b.e.getAttribute('role') === 'button' ? 0 : 1)
          || a.t.length - b.t.length);
      if (!hits.length) return null;
      hits[0].e.click();
      return hits[0].t;
    })()`);
    if (r == null) throw new Error(`[${this.name}] không có nút "${label}". Đang thấy:\n${await this.text()}`);
    await sleep(1500);
  }

  /**
   * Gõ vào ô có nhãn [label]. Lần chèn chữ đầu tiên sau khi điều hướng
   * hay bị Flutter nuốt mất, nên đọc lại giá trị và thử tối đa ba lần.
   */
  async type(label, value) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await this.semantics();
      const found = await this.eval(`(() => {
        const el = [...document.querySelectorAll('input, textarea')]
          .find((e) => (e.getAttribute('aria-label') || '').includes(${JSON.stringify(label)}));
        if (!el) return false;
        el.focus(); el.click(); return true;
      })()`);
      if (!found) await this.click(label);
      await sleep(600);
      await this.eval(`document.activeElement?.select?.()`);
      await this.send('Input.insertText', { text: value });
      await sleep(400);
      if ((await this.eval(`document.activeElement?.value ?? null`)) === value) return;
    }
    throw new Error(`[${this.name}] không gõ được vào ô "${label}"`);
  }

  /** Chặn mọi request tới API — giả lập mất mạng mà app vẫn chạy. */
  async blockApi(on) {
    await this.send('Network.setBlockedURLs', { urls: on ? ['*poolcoachai-api*'] : [] });
  }

  async shot(file) {
    const r = await this.send('Page.captureScreenshot', { format: 'png' });
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
  }
}
