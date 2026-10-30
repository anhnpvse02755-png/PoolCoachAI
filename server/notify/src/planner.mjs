// Cầu nối tới helper Dart (bin/notify_plan): một tiến trình con sống lâu, NDJSON
// qua stdin/stdout, khớp trả lời theo reqId. Khởi động ở lần dùng đầu và sau
// mỗi lần thoát; hết giờ thì giết con và đánh dấu không khoẻ cho tới lần gọi sau.
// Nhật ký không bao giờ chứa nội dung dòng (có thể có dữ liệu người dùng).

import { spawn as nodeSpawn } from 'node:child_process';
import { HELPER_MAX_INFLIGHT, HELPER_TIMEOUT_MS } from './limits.mjs';

export class PlannerError extends Error {
  constructor(code) {
    super(code);
    this.name = 'PlannerError';
    this.code = code;
  }
}

const PROTOCOL_VERSION = 1;

export function createPlanner({
  bin,
  spawn = nodeSpawn,
  timeoutMs = HELPER_TIMEOUT_MS,
  maxInFlight = HELPER_MAX_INFLIGHT,
  log = () => {},
}) {
  let child = null;
  let healthy = false;
  let closed = false;
  let counter = 0;
  const pending = new Map(); // reqId -> { resolve, reject, timer, child }
  const waiting = []; // việc chờ chỗ bay
  let inFlight = 0;

  function failAll(code, which) {
    for (const [id, p] of [...pending]) {
      if (which && p.child !== which) continue;
      pending.delete(id);
      clearTimeout(p.timer);
      p.reject(new PlannerError(code));
    }
  }

  function onLine(line, owner) {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      log({ event: 'helper_bad_line' });
      return;
    }
    const p = msg && typeof msg === 'object' ? pending.get(msg.reqId) : undefined;
    if (!p || p.child !== owner) {
      log({ event: 'helper_bad_line' });
      return;
    }
    pending.delete(msg.reqId);
    clearTimeout(p.timer);
    p.resolve(msg);
  }

  function lineReader(stream, onEach) {
    let buf = '';
    stream.setEncoding?.('utf8');
    stream.on('data', (chunk) => {
      buf += chunk;
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i).replace(/\r$/, '');
        buf = buf.slice(i + 1);
        if (line !== '') onEach(line);
      }
    });
  }

  function start() {
    const c = spawn(bin, [], { stdio: ['pipe', 'pipe', 'pipe'] });
    child = c;
    healthy = true;
    lineReader(c.stdout, (l) => onLine(l, c));
    lineReader(c.stderr, () => log({ event: 'helper_stderr' }));
    c.stdin?.on?.('error', () => {});
    const gone = () => {
      if (child === c) { child = null; healthy = false; }
      failAll('exited', c);
    };
    c.on('error', gone);
    c.on('exit', gone);
    return c;
  }

  function send(body) {
    return new Promise((resolve, reject) => {
      if (closed) return reject(new PlannerError('closed'));
      const c = child ?? start();
      const reqId = String(++counter);
      const timer = setTimeout(() => {
        pending.delete(reqId);
        if (child === c) child = null;
        healthy = false;
        try { c.kill(); } catch { /* đã chết */ }
        failAll('exited', c);
        reject(new PlannerError('timeout'));
      }, timeoutMs);
      pending.set(reqId, { resolve, reject, timer, child: c });
      try {
        c.stdin.write(`${JSON.stringify({ v: PROTOCOL_VERSION, ...body, reqId })}\n`);
      } catch {
        pending.delete(reqId);
        clearTimeout(timer);
        reject(new PlannerError('exited'));
      }
    });
  }

  async function limited(body) {
    if (inFlight >= maxInFlight) await new Promise((r) => waiting.push(r));
    inFlight++;
    try {
      return await send(body);
    } finally {
      inFlight--;
      waiting.shift()?.();
    }
  }

  return {
    get healthy() { return healthy; },
    info: () => limited({ op: 'info' }),
    plan: (request) => limited({ ...request, op: 'plan' }),
    close() {
      closed = true;
      failAll('closed');
      const c = child;
      child = null;
      healthy = false;
      if (c) {
        try { c.stdin.end(); } catch { /* bỏ qua */ }
        try { c.kill(); } catch { /* bỏ qua */ }
      }
    },
  };
}
