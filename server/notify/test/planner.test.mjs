import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { createPlanner, PlannerError } from '../src/planner.mjs';

function fakeSpawn() {
  const children = [];
  const spawn = () => {
    const c = new EventEmitter();
    c.stdout = new EventEmitter();
    c.stderr = new EventEmitter();
    c.written = [];
    c.answered = new Set();
    c.stdin = { write: (s) => { c.written.push(JSON.parse(s)); }, end() {}, on() {} };
    c.killed = false;
    c.kill = () => { c.killed = true; c.emit('close', null, 'SIGTERM'); };
    c.raw = (s) => c.stdout.emit('data', s);
    c.reply = (o) => c.raw(`${typeof o === 'string' ? o : JSON.stringify(o)}\n`);
    c.open = () => c.written.filter((w) => !c.answered.has(w.reqId));
    // Trả lời mọi yêu cầu đang mở trong MỘT chunk (nhiều dòng).
    c.replyAllOpen = () => {
      const open = c.open();
      for (const w of open) c.answered.add(w.reqId);
      c.raw(open.map((w) => `${JSON.stringify({ reqId: w.reqId, ok: true })}\n`).join(''));
      return open.length;
    };
    children.push(c);
    return c;
  };
  return { spawn, children };
}
const tick = () => new Promise((r) => setImmediate(r));
const ok = (c, i) => c.reply({ reqId: c.written[i].reqId, ok: true });

test('routes replies by reqId, out of order', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.plan({ userId: 'a' });
  const b = p.plan({ userId: 'b' });
  await tick();
  const [ra, rb] = children[0].written;
  children[0].reply({ reqId: rb.reqId, ok: true, who: 'b' });
  children[0].reply({ reqId: ra.reqId, ok: true, who: 'a' });
  assert.equal((await a).who, 'a');
  assert.equal((await b).who, 'b');
  assert.equal(ra.op, 'plan');
  assert.equal(ra.v, 1);
  p.close();
});

test('line split across chunks and several lines in one chunk', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.info();
  const b = p.info();
  await tick();
  const [ra, rb] = children[0].written;
  const la = JSON.stringify({ reqId: ra.reqId, ok: true, n: 'a' });
  const lb = JSON.stringify({ reqId: rb.reqId, ok: true, n: 'b' });
  children[0].raw(la.slice(0, 7));
  children[0].raw(`${la.slice(7)}\r\n${lb.slice(0, 3)}`);
  children[0].raw(`${lb.slice(3)}\n`);
  assert.equal((await a).n, 'a');
  assert.equal((await b).n, 'b');
  p.close();
});

test('timeout rejects, kills the child, unhealthy, next call respawns', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, timeoutMs: 20 });
  await assert.rejects(p.info(), (e) => e instanceof PlannerError && e.code === 'timeout');
  assert.equal(children[0].killed, true);
  assert.equal(p.healthy, false);
  const next = p.info();
  await tick();
  assert.equal(children.length, 2);
  assert.equal(p.healthy, false, 'healthy only after the first good reply');
  ok(children[1], 0);
  assert.equal((await next).ok, true);
  assert.equal(p.healthy, true);
  p.close();
});

test('late reply after timeout is ignored; other in-flight requests get exited', async () => {
  const { spawn, children } = fakeSpawn();
  const logs = [];
  const p = createPlanner({ bin: 'x', spawn, timeoutMs: 30, log: (l) => logs.push(l) });
  const a = p.info();
  const b = p.info();
  const ra = assert.rejects(a, (e) => e.code === 'timeout');
  const rb = assert.rejects(b, (e) => e.code === 'exited');
  await Promise.all([ra, rb]);
  const c = p.info();
  await tick();
  children[0].reply({ reqId: children[0].written[0].reqId, ok: true, stale: true });
  ok(children[1], 0);
  const r = await c;
  assert.equal(r.stale, undefined);
  assert.ok(logs.some((l) => l.event === 'helper_bad_line'));
  p.close();
});

test('child exit rejects pending, next call respawns', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.info();
  await tick();
  children[0].emit('close', 1, null);
  await assert.rejects(a, (e) => e.code === 'exited');
  assert.equal(p.healthy, false);
  const b = p.info();
  await tick();
  assert.equal(children.length, 2);
  ok(children[1], 0);
  await b;
  p.close();
});

test('reply written right before exit is still delivered (close, not exit)', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.info();
  await tick();
  children[0].emit('exit', 0, null); // 'exit' trước khi stdout đọc hết: không được hỏng yêu cầu
  ok(children[0], 0);
  children[0].emit('close', 0, null);
  assert.equal((await a).ok, true);
  p.close();
});

test('logs exit code/signal and spawn errors without content', async () => {
  const { spawn, children } = fakeSpawn();
  const logs = [];
  const p = createPlanner({ bin: 'x', spawn, log: (l) => logs.push(l) });
  const a = p.info();
  await tick();
  children[0].emit('close', 2, null);
  await assert.rejects(a);
  assert.deepEqual(logs, [{ event: 'helper_exit', code: 2, signal: null }]);
  const b = p.info();
  await tick();
  const err = Object.assign(new Error('boom /secret/path'), { code: 'ENOENT' });
  children[1].emit('error', err);
  await assert.rejects(b, (e) => e.code === 'exited');
  assert.deepEqual(logs[1], { event: 'helper_spawn_error', code: 'ENOENT' });
  assert.ok(!JSON.stringify(logs).includes('secret'));
  p.close();
});

test('real spawn of a missing binary rejects exited, unhealthy, no crash', async () => {
  const p = createPlanner({ bin: 'C:/no/such/notify_plan_xyz' });
  await assert.rejects(p.info(), (e) => e.code === 'exited');
  assert.equal(p.healthy, false);
  p.close();
});

test('non-JSON line is logged without content and does not crash', async () => {
  const { spawn, children } = fakeSpawn();
  const logs = [];
  const p = createPlanner({ bin: 'x', spawn, log: (l) => logs.push(l) });
  const a = p.info();
  await tick();
  children[0].reply('SECRET not json');
  children[0].stderr.emit('data', 'SECRET err\n');
  ok(children[0], 0);
  assert.equal((await a).ok, true);
  assert.deepEqual(logs.map((l) => l.event), ['helper_bad_line', 'helper_stderr']);
  assert.ok(!JSON.stringify(logs).includes('SECRET'));
  p.close();
});

test('stdout line over 1 MiB without newline kills the child and rejects pending', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.info();
  await tick();
  children[0].raw('x'.repeat(1024 * 1024 + 1));
  await assert.rejects(a, (e) => e.code === 'exited');
  assert.equal(children[0].killed, true);
  const b = p.info();
  await tick();
  assert.equal(children.length, 2);
  ok(children[1], 0);
  await b;
  p.close();
});

test('close(): rejects pending and queued with closed, later calls rejected, child killed', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1 });
  const a = p.info();
  const b = p.info(); // xếp hàng sau trần
  await tick();
  p.close();
  await assert.rejects(a, (e) => e.code === 'closed');
  await assert.rejects(b, (e) => e.code === 'closed');
  await assert.rejects(p.info(), (e) => e.code === 'closed');
  assert.equal(children[0].killed, true);
  assert.equal(children.length, 1);
  assert.equal(p.healthy, false);
});

test('caps in-flight requests (single waiter)', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1 });
  const a = p.info();
  const b = p.info();
  await tick();
  assert.equal(children[0].written.length, 1);
  ok(children[0], 0);
  await a;
  await tick();
  assert.equal(children[0].written.length, 2);
  ok(children[0], 1);
  await b;
  p.close();
});

test('cap holds when callers re-call on completion (two-pass pattern, batched replies)', async () => {
  for (const [cap, users] of [[2, 4], [4, 12], [4, 40]]) {
    const { spawn, children } = fakeSpawn();
    const p = createPlanner({ bin: 'x', spawn, maxInFlight: cap });
    let done = 0;
    const all = Array.from({ length: users }, async () => {
      await p.plan({ mode: 'upcoming' });
      await p.plan({ mode: 'due' });
      done++;
    });
    let max = 0;
    for (let guard = 0; done < users && guard < 1000; guard++) {
      await tick();
      const c = children[0];
      max = Math.max(max, c.open().length);
      if (c.open().length) c.replyAllOpen();
    }
    await Promise.all(all);
    assert.ok(max <= cap, `cap ${cap} users ${users}: saw ${max} open`);
    assert.equal(children[0].written.length, users * 2);
    p.close();
  }
});

test('timeout starts when written to the child, not while queued', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1, timeoutMs: 80 });
  const a = p.info();
  const b = p.info();
  await tick();
  await new Promise((r) => setTimeout(r, 50));
  ok(children[0], 0);
  await a;
  await tick();
  await new Promise((r) => setTimeout(r, 50)); // b đã chờ 100ms > 80ms nhưng chỉ ghi được 50ms
  ok(children[0], 1);
  assert.equal((await b).ok, true);
  p.close();
});

test('cap is released on timeout and crash', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1, timeoutMs: 30 });
  // timeout
  await assert.rejects(p.info(), (e) => e.code === 'timeout');
  // crash
  const crash = p.info();
  await tick();
  children[1].emit('close', 1, null);
  await assert.rejects(crash, (e) => e.code === 'exited');
  // sau cả hai, chỗ vẫn còn
  const last = p.info();
  await tick();
  const c = children.at(-1);
  ok(c, c.written.length - 1);
  assert.equal((await last).ok, true);
  p.close();
});

test('queued waiter behind a child that crashes gets the slot and completes on a fresh child', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1, timeoutMs: 5_000 });
  const a = p.plan({ userId: 'a' });
  const b = p.plan({ userId: 'b' });
  await tick();
  assert.equal(children[0].written.length, 1, 'b is queued behind a');
  children[0].emit('close', 1, null); // con chết khi đang xử lý a
  await assert.rejects(a, (e) => e.code === 'exited');
  await tick();
  assert.equal(children.length, 2, 'fresh child for the waiter');
  assert.equal(children[0].written.length, 1, 'nothing written to the dead child');
  assert.equal(children[1].written.length, 1);
  assert.equal(children[1].written[0].userId, 'b');
  ok(children[1], 0);
  assert.equal((await b).ok, true);
  assert.equal(p.healthy, true);
  p.close();
});

test('queued waiter behind a child that times out gets the slot and completes on a fresh child', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1, timeoutMs: 40 });
  const a = p.plan({ userId: 'a' });
  const b = p.plan({ userId: 'b' });
  await tick();
  assert.equal(children[0].written.length, 1, 'b is queued behind a');
  await assert.rejects(a, (e) => e.code === 'timeout');
  assert.equal(children[0].killed, true);
  await tick();
  assert.equal(children.length, 2, 'fresh child for the waiter');
  assert.equal(children[0].written.length, 1, 'nothing written to the killed child');
  assert.equal(children[1].written[0].userId, 'b');
  ok(children[1], 0); // trả lời ngay: b có đồng hồ riêng, bắt đầu khi được ghi
  assert.equal((await b).ok, true);
  p.close();
});
