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
const MAX_LINE_CHARS = 1024 * 1024;

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
    healthy = true; // chỉ khoẻ sau trả lời tốt đầu tiên của con hiện tại
    p.resolve(msg);
  }

  // [onOverflow] chạy khi một dòng chưa có xuống dòng vượt MAX_LINE_CHARS.
  function lineReader(stream, onEach, onOverflow) {
    let buf = '';
    let dead = false;
    stream.setEncoding?.('utf8');
    stream.on('data', (chunk) => {
      if (dead) return;
      buf += chunk;
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i).replace(/\r$/, '');
        buf = buf.slice(i + 1);
        if (line !== '') onEach(line);
      }
      if (buf.length > MAX_LINE_CHARS) {
        dead = true;
        buf = '';
        onOverflow?.();
      }
    });
  }

  function start() {
    const c = spawn(bin, [], { stdio: ['pipe', 'pipe', 'pipe'] });
    child = c;
    healthy = false;
    lineReader(c.stdout, (l) => onLine(l, c), () => {
      log({ event: 'helper_overflow' });
      if (child === c) { child = null; healthy = false; }
      try { c.kill(); } catch { /* đã chết */ }
      failAll('exited', c);
    });
    lineReader(c.stderr, () => log({ event: 'helper_stderr' }));
    c.stdin?.on?.('error', () => {});
    const gone = () => {
      if (child === c) { child = null; healthy = false; }
      failAll('exited', c);
    };
    c.on('error', (err) => {
      log({ event: 'helper_spawn_error', code: typeof err?.code === 'string' ? err.code : null });
      gone();
    });
    // 'close' (không phải 'exit'): đợi stdout đọc hết để không bỏ rơi trả lời
    // helper viết ngay trước khi thoát.
    c.on('close', (code, signal) => {
      log({ event: 'helper_exit', code: code ?? null, signal: signal ?? null });
      gone();
    });
    return c;
  }

  function send(body) {
    return new Promise((resolve, reject) => {
      if (closed) return reject(new PlannerError('closed'));
      const c = child ?? start();
      const reqId = String(++counter);
      // Đồng hồ chỉ chạy từ lúc ghi xuống helper, không tính lúc xếp hàng.
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
    // Nhả chỗ thì chuyển THẲNG cho người chờ, không bao giờ nhả rồi mới đánh
    // thức: người gọi lại ngay lúc đó sẽ chen hàng và vượt trần.
    if (inFlight >= maxInFlight) await new Promise((r) => waiting.push(r));
    else inFlight++;
    try {
      return await send(body);
    } finally {
      const next = waiting.shift();
      if (next) next();
      else inFlight--;
    }
  }

  return {
    get healthy() { return healthy; },
    info: () => limited({ op: 'info' }),
    plan: (request) => limited({ ...request, op: 'plan' }),
    close() {
      closed = true;
      failAll('closed');
      // Người đang xếp hàng: để send() của họ tự từ chối 'closed'.
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
