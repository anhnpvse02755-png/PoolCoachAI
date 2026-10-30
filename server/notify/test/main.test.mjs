import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

test('env rỗng: không khởi động, stderr nêu tên biến, không lộ giá trị', () => {
  const r = spawnSync(process.execPath, ['src/main.mjs'], { cwd: root, encoding: 'utf8',
    env: { SystemRoot: process.env.SystemRoot ?? '', VAPID_PRIVATE_KEY: 'very-secret-value' } });
  assert.equal(r.status, 1);
  for (const n of ['PUSH_SERVICE_TOKEN', 'DIRECTUS_URL', 'PUSH_ENABLED']) assert.match(r.stderr, new RegExp(n));
  assert.doesNotMatch(r.stdout + r.stderr, /very-secret-value/);
});

test('placeholder planner: không báo helper ok, info() từ chối', async () => {
  const { createPlaceholderPlanner } = await import('../src/placeholders.mjs');
  const p = createPlaceholderPlanner();
  assert.equal(p.healthy, false);
  await assert.rejects(p.info(), /planner not wired \(Task 8\)/);
});
