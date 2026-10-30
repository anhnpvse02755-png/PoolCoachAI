// Máy chủ HTTP notify. Task 7: /healthz và /push/config; các endpoint đăng ký
// và ack thêm ở Task 10. Không log token, endpoint hay khoá.

import { sendJson } from './http.mjs';

export function createApp({ config, directus, planner, scheduler, now = () => new Date(), log = (l) => process.stdout.write(`${l}\n`), fetch = globalThis.fetch }) {
  void directus; void now; void fetch; // dùng ở Task 10

  function writeLog({ method, path, status, startedAt, error }) {
    log(JSON.stringify({ method, path, status, at: new Date().toISOString(), ms: Date.now() - startedAt, ...(error ? { error } : {}) }));
  }

  async function dispatch(req, res, startedAt) {
    const origin = req.headers.origin;
    const path = new URL(req.url, 'http://notify.internal').pathname;

    if (req.method === 'GET' && path === '/healthz') {
      sendJson(res, 200, {
        ok: true,
        enabled: config.enabled,
        lastCycleAt: scheduler.lastCycleAt?.toISOString() ?? null,
        helper: planner.healthy ? 'ok' : 'down',
      }, origin, config.allowedOrigins);
      return; // healthz không ghi nhật ký
    }
    if (req.method === 'GET' && path === '/push/config') {
      sendJson(res, 200, { enabled: config.enabled, publicKey: config.vapid.publicKey }, origin, config.allowedOrigins);
      writeLog({ method: 'GET', path, status: 200, startedAt });
      return;
    }
    sendJson(res, 404, { error: 'not_found' }, origin, config.allowedOrigins);
    writeLog({ method: req.method, path, status: 404, startedAt, error: 'not_found' });
  }

  return function handler(req, res) {
    const startedAt = Date.now();
    dispatch(req, res, startedAt).catch(() => {
      if (!res.headersSent) {
        try {
          sendJson(res, 500, { error: 'internal' }, req.headers.origin, config.allowedOrigins);
        } catch {
          // Mất kết nối trước khi trả lời được.
        }
      }
      const path = new URL(req.url, 'http://notify.internal').pathname;
      writeLog({ method: req.method, path, status: res.statusCode, startedAt, error: 'internal' });
    });
  };
}
