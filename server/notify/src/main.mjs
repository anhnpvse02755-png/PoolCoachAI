// Điểm khởi động dịch vụ notify (spec P6b mục 3): đọc cấu hình, kiểm helper,
// mở cổng HTTP, bật bộ lập lịch, tắt êm khi nhận SIGTERM. Khởi động thất bại
// thì chỉ in tên biến thiếu/sai ra stderr, không bao giờ in giá trị.

import http from 'node:http';
import { loadConfig } from './config.mjs';
import { createDirectus } from './directus.mjs';
import { createApp } from './server.mjs';
import { createPlaceholderPlanner, createPlaceholderScheduler } from './placeholders.mjs';


async function main() {
  let config;
  try {
    config = loadConfig(process.env);
  } catch (err) {
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
  }

  const planner = createPlaceholderPlanner();
  try {
    // Task 8: dùng cả `fields` lẫn `settingsFields` của reply `info` (R-F7).
    await planner.info();
  } catch {
    process.stderr.write('helper không chạy\n');
    process.exit(1);
  }

  const directus = createDirectus({ url: config.directusUrl, serviceToken: config.serviceToken, fetch: globalThis.fetch });
  const scheduler = createPlaceholderScheduler();
  const handler = createApp({ config, directus, planner, scheduler });
  const server = http.createServer(handler);
  server.listen(config.port, () => {
    process.stdout.write(`${JSON.stringify({ event: 'listening', port: config.port, enabled: config.enabled, at: new Date().toISOString() })}\n`);
    scheduler.start();
  });

  process.on('SIGTERM', () => {
    scheduler.stop();
    planner.close();
    server.close(() => process.exit(0));
  });
}

main();
