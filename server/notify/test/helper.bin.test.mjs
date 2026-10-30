// Chạy helper Dart thật. Bỏ qua nếu không đặt NOTIFY_PLAN_BIN (npm test thường vẫn xanh).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

const BIN = process.env.NOTIFY_PLAN_BIN;
const skip = BIN ? false : 'NOTIFY_PLAN_BIN chưa đặt: bỏ qua test helper thật';

function run() {
  const c = spawn(BIN, [], { stdio: ['pipe', 'pipe', 'pipe'] });
  const lines = [];
  const waiters = [];
  let buf = '';
  c.stdout.setEncoding('utf8');
  c.stdout.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const l = buf.slice(0, i).replace(/\r$/, '');
      buf = buf.slice(i + 1);
      if (waiters.length) waiters.shift()(l); else lines.push(l);
    }
  });
  c.stderr.resume();
  const next = () => new Promise((r) => (lines.length ? r(lines.shift()) : waiters.push(r)));
  const ask = async (line) => { c.stdin.write(`${line}\n`); return JSON.parse(await next()); };
  return { c, ask };
}

const plan = (data) => JSON.stringify({
  v: 1, op: 'plan', reqId: 'p', userId: 'u', nowUtc: '2026-10-30T02:00:00Z', tz: 'UTC', mode: 'due',
  prefs: { recommendation: true, maintenance: true, schedule: true, streak: true },
  seen: null, sentRecommendations: [], data,
});

test('real helper', { skip, timeout: 60_000 }, async () => {
  const { c, ask } = run();
  try {
    const info = await ask('{"v":1,"op":"info","reqId":"i"}');
    assert.equal(info.ok, true);
    assert.equal(info.kinds.length, 4);
    assert.equal(Object.keys(info.fields).length, 7);
    assert.equal(typeof info.settingsFields, 'string');

    // Mọi khoá collection phải có mặt (thiếu là bad_request): lấy từ info.
    const data = Object.fromEntries(Object.keys(info.fields).map((k) => [k, []]));
    const plan1 = await ask(plan(data));
    assert.equal(plan1.ok, true);
    assert.deepEqual(plan1.items, []);
    assert.deepEqual(await ask(plan(data)), plan1);

    const bad = await ask('{garbage');
    assert.equal(bad.ok, false);
    assert.equal(bad.error, 'bad_json');
    assert.equal((await ask('{"v":1,"op":"info","reqId":"i2"}')).ok, true);

    c.stdin.end();
    const [code] = await once(c, 'exit');
    assert.equal(code, 0);
  } finally {
    if (c.exitCode === null) c.kill();
  }
});
