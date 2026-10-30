import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import webPush from 'web-push';
import { main, startService } from '../src/main.mjs';
import { CYCLE_MS, KINDS, SHUTDOWN_WAIT_MS, TICK_MS } from '../src/limits.mjs';
import { validInfo } from '../src/planner.mjs';
import { DIRECTUS, SERVICE_TOKEN, fakeDirectus, fakeFetch } from './fakes.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const keys = webPush.generateVAPIDKeys();
const other = webPush.generateVAPIDKeys();
const ENV = {
  DIRECTUS_URL: DIRECTUS, PUSH_SERVICE_TOKEN: SERVICE_TOKEN, ALLOWED_ORIGINS: 'https://app.test', PUBLIC_URL: 'https://notify.test',
  VAPID_PUBLIC_KEY: keys.publicKey, VAPID_PRIVATE_KEY: keys.privateKey, VAPID_SUBJECT: 'mailto:ops@example.com',
  PUSH_ENABLED: 'true', NOTIFY_PLAN_BIN: 'fake-notify-plan',
};
const COLLECTIONS = ['drill_logs', 'timer_sessions', 'schedule_slots', 'cue_equipment', 'pool_matches', 'bu_tests', 'bu_drill_results'];

function runMain(env) {
  return spawnSync(process.execPath, ['src/main.mjs'], {
    cwd: root, encoding: 'utf8', timeout: 30_000, env: { SystemRoot: process.env.SystemRoot ?? '', PATH: process.env.PATH ?? '', ...env },
  });
}

test('env rỗng: không khởi động, stderr nêu tên biến, không lộ giá trị', () => {
  const r = runMain({ VAPID_PRIVATE_KEY: 'very-secret-value' });
  assert.equal(r.status, 1);
  for (const n of ['PUSH_SERVICE_TOKEN', 'DIRECTUS_URL', 'PUSH_ENABLED']) assert.match(r.stderr, new RegExp(n));
  assert.doesNotMatch(r.stdout + r.stderr, /very-secret-value/);
});

test('khoá VAPID không khớp: thoát 1 trước khi chạy helper, log rõ, không lộ bí mật', () => {
  const r = runMain({ ...ENV, VAPID_PRIVATE_KEY: other.privateKey });
  assert.equal(r.status, 1);
  assert.match(r.stderr, /VAPID/);
  assert.doesNotMatch(r.stdout + r.stderr, new RegExp(`${other.privateKey}|${keys.privateKey}|${SERVICE_TOKEN}`));
  assert.doesNotMatch(r.stdout, /helper_spawn_error/, 'không chạy tới helper');
});

test('helper không chạy (NOTIFY_PLAN_BIN sai): thoát 1, log rõ, không lộ bí mật', () => {
  const r = runMain({ ...ENV, NOTIFY_PLAN_BIN: `${root}/does-not-exist/notify_plan` });
  assert.equal(r.status, 1);
  assert.match(r.stderr, /helper/);
  assert.doesNotMatch(r.stdout + r.stderr, new RegExp(`${keys.privateKey}|${SERVICE_TOKEN}`));
});

// Helper giả: trả lời info và plan như helper thật (plan không có mục nào).
function fakeHelperSpawn({ info = {} } = {}) {
  const children = [];
  const spawn = () => {
    const c = new EventEmitter();
    c.stdout = new EventEmitter();
    c.stderr = new EventEmitter();
    c.killed = false;
    c.requests = [];
    c.stdin = {
      write(s) {
        const req = JSON.parse(s);
        c.requests.push(req);
        const reply = req.op === 'info'
          ? { v: 1, reqId: req.reqId, ok: true, fingerprint: 'fp1', kinds: KINDS, fields: Object.fromEntries(COLLECTIONS.map((x) => [x, 'id'])), settingsFields: 'id,streak', ...info }
          : { v: 1, reqId: req.reqId, ok: true, fingerprint: 'fp1', items: [] };
        setImmediate(() => c.stdout.emit('data', `${JSON.stringify(reply)}\n`));
      },
      end() {},
      on() {},
    };
    c.kill = () => { c.killed = true; setImmediate(() => c.emit('close', null, 'SIGTERM')); };
    children.push(c);
    return c;
  };
  return { spawn, children };
}

function fakeTimers() {
  const intervals = [];
  const cleared = [];
  return {
    intervals, cleared,
    setInterval: (fn, ms) => { intervals.push({ fn, ms }); return intervals.length; },
    clearInterval: (h) => cleared.push(h),
  };
}

const DEVICE = {
  id: 'd'.repeat(64), user: 'user-a', channel: 'web', platform: 'web', endpoint: 'https://fcm.googleapis.com/fcm/send/x', key_p256dh: 'p', key_auth: 'a',
  timezone: 'Asia/Ho_Chi_Minh', seed_fingerprint: 'fp1', mode: 'server', server_kinds: [...KINDS], lease_until: null,
  last_seen_at: new Date().toISOString(), failure_count: 0,
};

test('startService: planner thật + sender thật + scheduler + HTTP; healthz ok; tắt êm đóng hết', async () => {
  const helper = fakeHelperSpawn();
  const timers = fakeTimers();
  const fake = fakeDirectus({ filters: true, items: { push_devices: [{ ...DEVICE }], notification_settings: [{ id: 'user-a', streak: true }] } });
  const logs = [];
  const service = await startService({
    env: ENV, fetch: fakeFetch({ directus: fake }), spawn: helper.spawn, port: 0, log: (l) => logs.push(l),
    schedulerOptions: { setInterval: timers.setInterval, clearInterval: timers.clearInterval },
  });
  const base = `http://127.0.0.1:${service.server.address().port}`;
  await service.scheduler.cycle(); // chu kỳ đầu (start) đã xếp trước; đợi cả hai xong
  assert.deepEqual(timers.intervals.map((i) => i.ms), [CYCLE_MS, TICK_MS]);
  const health = await (await fetch(`${base}/healthz`)).json();
  assert.equal(health.helper, 'ok');
  assert.equal(health.push, 'ok');
  assert.equal(health.enabled, true);
  assert.equal(typeof health.lastCycleAt, 'string', 'chu kỳ thật đã chạy');
  // Chu kỳ thật gia hạn lease máy khoẻ và hỏi helper cả hai lượt.
  assert.ok(fake.items.push_devices[0].lease_until);
  assert.deepEqual(helper.children[0].requests.filter((r) => r.op === 'plan').map((r) => r.mode).slice(0, 2), ['due', 'upcoming']);
  const config = await (await fetch(`${base}/push/config`)).json();
  assert.deepEqual(config, { enabled: true, publicKey: keys.publicKey });

  await service.shutdown();
  assert.deepEqual(timers.cleared, [1, 2]);
  assert.equal(service.server.listening, false);
  assert.equal(helper.children[0].killed, true);
  assert.doesNotMatch(JSON.stringify(logs), new RegExp(`${keys.privateKey}|${SERVICE_TOKEN}`));
});

test('startService: info của helper thiếu fields/settingsFields thì không khởi động', async () => {
  const helper = fakeHelperSpawn({ info: { settingsFields: undefined } });
  await assert.rejects(
    startService({ env: ENV, fetch: async () => { throw new Error('no network'); }, spawn: helper.spawn, port: 0 }),
    /helper/,
  );
  assert.equal(helper.children[0].killed, true, 'không để lại tiến trình con');
});

test('main: SIGTERM và SIGINT dừng hẹn giờ, đợi chuỗi, đóng planner và server, thoát 0', async () => {
  for (const signal of ['SIGTERM', 'SIGINT']) {
    const helper = fakeHelperSpawn();
    const timers = fakeTimers();
    const fake = fakeDirectus({ filters: true });
    const proc = new EventEmitter();
    const exited = new Promise((r) => { proc.exit = r; });
    proc.stderr = { write() {} };
    const service = await main({
      env: ENV, proc, fetch: fakeFetch({ directus: fake }), spawn: helper.spawn, port: 0, log: () => {},
      schedulerOptions: { setInterval: timers.setInterval, clearInterval: timers.clearInterval },
    });
    proc.emit(signal);
    proc.emit(signal); // tín hiệu lặp không tắt hai lần
    assert.equal(await exited, 0);
    assert.deepEqual(timers.cleared, [1, 2]);
    assert.equal(service.server.listening, false);
    assert.equal(helper.children[0].killed, true);
  }
});

test('main: khởi động lỗi thì stderr một dòng và thoát 1', async () => {
  const proc = new EventEmitter();
  const lines = [];
  proc.stderr = { write: (s) => lines.push(s) };
  let code = null;
  proc.exit = (c) => { code = c; };
  await main({ env: { ...ENV, VAPID_PRIVATE_KEY: other.privateKey }, proc, port: 0, log: () => {} });
  assert.equal(code, 1);
  assert.equal(lines.length, 1);
  assert.match(lines[0], /^VAPID/);
});

test('tắt êm có giới hạn: chuỗi kẹt (Directus treo) thì vẫn đóng sau shutdownWaitMs', async () => {
  const helper = fakeHelperSpawn();
  const timers = fakeTimers();
  const logs = [];
  const service = await startService({
    env: ENV, fetch: () => new Promise(() => {}), spawn: helper.spawn, port: 0, log: (l) => logs.push(l), shutdownWaitMs: 50,
    schedulerOptions: { setInterval: timers.setInterval, clearInterval: timers.clearInterval },
  });
  const started = Date.now();
  await service.shutdown();
  assert.ok(Date.now() - started < 5_000);
  assert.equal(service.server.listening, false);
  assert.equal(helper.children[0].killed, true);
  assert.ok(logs.some((l) => l.event === 'shutdown_timeout'));
});

test('chờ tắt êm ≤ 8 s: dưới thời gian ân hạn 10 s của Docker/Swarm trước SIGKILL', () => {
  assert.equal(SHUTDOWN_WAIT_MS, 8_000);
});

test('validInfo (một bản duy nhất, planner.mjs): đủ ok, fingerprint, fields, settingsFields', () => {
  const good = { ok: true, fingerprint: 'fp', fields: { a: 'id' }, settingsFields: 'id' };
  assert.equal(validInfo(good), true);
  for (const bad of [null, undefined, { ...good, ok: false }, { ...good, fingerprint: 1 }, { ...good, fields: null }, { ...good, settingsFields: undefined }]) {
    assert.equal(validInfo(bad), false);
  }
});

test('placeholders.mjs đã bỏ: main nối planner và scheduler thật', () => {
  assert.equal(existsSync(`${root}/src/placeholders.mjs`), false);
});

const BIN = process.env.NOTIFY_PLAN_BIN;
test('startService với helper thật: info, chu kỳ, healthz helper ok, tắt êm', { skip: BIN ? false : 'NOTIFY_PLAN_BIN chưa đặt', timeout: 60_000 }, async () => {
  const timers = fakeTimers();
  const fake = fakeDirectus({ filters: true, items: { push_devices: [{ ...DEVICE }], notification_settings: [{ id: 'user-a', recommendation: true, maintenance: true, schedule: true, streak: true }] } });
  const service = await startService({
    env: { ...ENV, NOTIFY_PLAN_BIN: BIN }, fetch: fakeFetch({ directus: fake }), port: 0, log: () => {},
    schedulerOptions: { setInterval: timers.setInterval, clearInterval: timers.clearInterval },
  });
  try {
    await service.scheduler.cycle();
    const health = await (await fetch(`http://127.0.0.1:${service.server.address().port}/healthz`)).json();
    assert.equal(health.helper, 'ok');
    assert.equal(typeof health.lastCycleAt, 'string');
  } finally {
    await service.shutdown();
  }
  assert.equal(service.server.listening, false);
});
