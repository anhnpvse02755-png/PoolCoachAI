// Điểm khởi động dịch vụ coach-chat (spec mục 7.7): đọc cấu hình, mở cổng
// HTTP, tắt êm khi nhận SIGTERM. Không khởi động được thì chỉ in tên biến
// thiếu/sai ra stderr, không bao giờ in giá trị.

import http from 'node:http';
import { loadConfig } from './config.mjs';
import { createApp } from './server.mjs';

function main() {
  let config;
  try {
    config = loadConfig(process.env);
  } catch (err) {
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
  }

  const handler = createApp({ config });
  const server = http.createServer(handler);
  server.listen(config.port, () => {
    process.stdout.write(`${JSON.stringify({ event: 'listening', port: config.port, model: config.model })}\n`);
  });

  process.on('SIGTERM', () => {
    server.close(() => process.exit(0));
  });
}

main();
