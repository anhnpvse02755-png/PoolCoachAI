import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createApp } from '../src/server.mjs';

const WEB = 'https://poolcoachai.kjdybl.easypanel.host';

async function start(t, { config = {}, planner = { healthy: true }, scheduler = { lastCycleAt: null }, lines = [] } = {}) {
  const handler = createApp({
    config: { enabled: true, vapid: { publicKey: 'pub-key', privateKey: 'priv', subject: 'mailto:a@b.test' }, allowedOrigins: [WEB, 'http://localhost:5555'], ...config },
    directus: {}, planner, scheduler, now: () => new Date('2026-10-30T03:00:00Z'), log: (l) => lines.push(l), fetch: async () => { throw new Error('no network'); },
  });
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => server.close(r)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('healthz: enabled, lastCycleAt, helper', async (t) => {
  const base = await start(t, { scheduler: { lastCycleAt: new Date('2026-10-30T02:45:00Z') } });
  const r = await fetch(`${base}/healthz`);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { ok: true, enabled: true, lastCycleAt: '2026-10-30T02:45:00.000Z', helper: 'ok' });
});
test('healthz: chưa có chu kỳ và helper chết', async (t) => {
  const base = await start(t, { config: { enabled: false }, planner: { healthy: false } });
  assert.deepEqual(await (await fetch(`${base}/healthz`)).json(), { ok: true, enabled: false, lastCycleAt: null, helper: 'down' });
});
test('push/config: khoá công khai, CORS chỉ cho nguồn được phép', async (t) => {
  const base = await start(t);
  const ok = await fetch(`${base}/push/config`, { headers: { origin: WEB } });
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { enabled: true, publicKey: 'pub-key' });
  assert.equal(ok.headers.get('access-control-allow-origin'), WEB);
  assert.equal(ok.headers.get('vary'), 'Origin');
  const bad = await fetch(`${base}/push/config`, { headers: { origin: 'https://evil.test' } });
  assert.equal(bad.status, 200);
  assert.equal(bad.headers.get('access-control-allow-origin'), null);
  const none = await fetch(`${base}/push/config`);
  assert.equal(none.headers.get('access-control-allow-origin'), null);
});
test('push/config không lộ khoá riêng', async (t) => {
  const base = await start(t);
  const text = await (await fetch(`${base}/push/config`)).text();
  assert.doesNotMatch(text, /priv/);
});
test('đường dẫn lạ: 404 not_found', async (t) => {
  const base = await start(t);
  const r = await fetch(`${base}/nope`);
  assert.deepEqual([r.status, await r.json()], [404, { error: 'not_found' }]);
  const p = await fetch(`${base}/healthz`, { method: 'POST' });
  assert.equal(p.status, 404);
});
