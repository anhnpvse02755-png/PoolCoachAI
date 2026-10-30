// Điểm khởi động dịch vụ notify (spec P6b mục 3): đọc cấu hình, dựng sender
// Web Push (kiểm VAPID), kiểm helper, mở cổng HTTP, bật bộ lập lịch, tắt êm khi
// nhận SIGTERM/SIGINT. Khởi động thất bại thì in MỘT dòng ra stderr và thoát 1:
// chỉ tên biến hay thông điệp cố định, không bao giờ in giá trị hay khoá.

import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { loadConfig } from './config.mjs';
import { createDirectus } from './directus.mjs';
import { SHUTDOWN_WAIT_MS } from './limits.mjs';
import { createPlanner, validInfo } from './planner.mjs';
import { createScheduler } from './scheduler.mjs';
import { createSenders } from './senders.mjs';
import { createApp } from './server.mjs';
import { createWebPushSender } from './webpush.mjs';

/// Lỗi khởi động có thông điệp an toàn để in.
class StartupError extends Error {}

function jsonLog(line) {
  process.stdout.write(`${JSON.stringify({ ...line, at: new Date().toISOString() })}\n`);
}

/// Dựng và chạy dịch vụ. Ném StartupError khi cấu hình, VAPID hay helper hỏng.
/// Trả `{ config, server, scheduler, planner, shutdown }`.
export async function startService({
  env = process.env, fetch = globalThis.fetch, spawn, log = jsonLog, port,
  schedulerOptions = {}, shutdownWaitMs = SHUTDOWN_WAIT_MS,
} = {}) {
  let config;
  try {
    config = loadConfig(env);
  } catch (e) {
    throw new StartupError(e.message); // chỉ tên biến
  }

  let web;
  try {
    web = createWebPushSender({ vapid: config.vapid, fetch });
  } catch (e) {
    // Thông điệp cố định của webpush.mjs, không bao giờ chứa nội dung khoá.
    throw new StartupError(String(e?.message ?? '').startsWith('VAPID') ? e.message : 'VAPID: cấu hình không hợp lệ');
  }

  const planner = createPlanner({ bin: config.planBin, log, ...(spawn ? { spawn } : {}) });
  let info;
  try {
    info = await planner.info();
  } catch {
    planner.close();
    throw new StartupError('helper không chạy (kiểm NOTIFY_PLAN_BIN)');
  }
  if (!validInfo(info)) {
    planner.close();
    throw new StartupError('helper trả info không hợp lệ');
  }

  const directus = createDirectus({ url: config.directusUrl, serviceToken: config.serviceToken, fetch });
  const senders = createSenders({ web });
  const scheduler = createScheduler({ directus, planner, senders, config, log, ...schedulerOptions });
  const server = http.createServer(createApp({ config, directus, planner, scheduler }));
  const listenPort = port ?? config.port;
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(listenPort, () => {
        server.off('error', reject);
        resolve();
      });
    });
  } catch (e) {
    planner.close();
    throw new StartupError(`không mở được cổng ${listenPort} (${e?.code ?? 'error'})`);
  }
  log({ event: 'listening', port: server.address().port, enabled: config.enabled });
  scheduler.start();

  let closing = null;
  /// Dừng hẹn giờ, đợi chuỗi việc của bộ lập lịch (có giới hạn), rồi đóng planner và server.
  function shutdown() {
    closing ??= (async () => {
      let timer;
      const drained = await Promise.race([
        scheduler.stop().then(() => true),
        new Promise((r) => { timer = setTimeout(() => r(false), shutdownWaitMs); }),
      ]);
      clearTimeout(timer);
      if (!drained) log({ event: 'shutdown_timeout', waitedMs: shutdownWaitMs });
      planner.close();
      await new Promise((r) => {
        server.close(() => r());
        server.closeAllConnections?.();
      });
      log({ event: 'stopped' });
    })();
    return closing;
  }

  return { config, server, scheduler, planner, shutdown };
}

/// Chạy dịch vụ như một tiến trình: lỗi khởi động → một dòng stderr, thoát 1;
/// SIGTERM/SIGINT → tắt êm, thoát 0.
export async function main({ proc = process, ...options } = {}) {
  let service;
  try {
    service = await startService(options);
  } catch (e) {
    proc.stderr.write(`${e instanceof StartupError ? e.message : 'khởi động thất bại'}\n`);
    proc.exit(1);
    return null;
  }
  let signalled = false;
  const onSignal = () => {
    if (signalled) return;
    signalled = true;
    service.shutdown().then(() => proc.exit(0), () => proc.exit(1));
  };
  proc.on('SIGTERM', onSignal);
  proc.on('SIGINT', onSignal);
  return service;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
