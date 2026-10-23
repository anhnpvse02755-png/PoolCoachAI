import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

test('thiếu biến bắt buộc: không khởi động, chỉ in tên biến', () => {
  const r = spawnSync(process.execPath, ['src/main.mjs'], { cwd: root, encoding: 'utf8',
    env: { SystemRoot: process.env.SystemRoot ?? '', DIRECTUS_SERVICE_TOKEN: 'very-secret-value' } });
  assert.equal(r.status, 1);
  for (const n of ['ANTHROPIC_API_KEY', 'DIRECTUS_URL', 'ALLOWED_ORIGINS']) assert.match(r.stderr, new RegExp(n));
  assert.doesNotMatch(r.stdout + r.stderr, /very-secret-value/);
});
