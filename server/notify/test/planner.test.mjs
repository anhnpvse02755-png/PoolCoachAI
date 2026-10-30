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
    c.stdin = { write: (s) => { c.written.push(JSON.parse(s)); }, end() {}, on() {} };
    c.killed = false;
    c.kill = () => { c.killed = true; c.emit('exit', null, 'SIGTERM'); };
    c.reply = (o) => c.stdout.emit('data', `${typeof o === 'string' ? o : JSON.stringify(o)}\n`);
    children.push(c);
    return c;
  };
  return { spawn, children };
}
const tick = () => new Promise((r) => setImmediate(r));

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

test('timeout rejects, kills the child, unhealthy, next call respawns', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, timeoutMs: 20 });
  await assert.rejects(p.info(), (e) => e instanceof PlannerError && e.code === 'timeout');
  assert.equal(children[0].killed, true);
  assert.equal(p.healthy, false);
  const next = p.info();
  await tick();
  assert.equal(children.length, 2);
  assert.equal(p.healthy, true);
  children[1].reply({ reqId: children[1].written[0].reqId, ok: true });
  assert.equal((await next).ok, true);
  p.close();
});

test('child exit rejects pending, next call respawns', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn });
  const a = p.info();
  await tick();
  assert.equal(p.healthy, true);
  children[0].emit('exit', 1, null);
  await assert.rejects(a, (e) => e.code === 'exited');
  assert.equal(p.healthy, false);
  const b = p.info();
  await tick();
  assert.equal(children.length, 2);
  children[1].reply({ reqId: children[1].written[0].reqId, ok: true });
  await b;
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
  children[0].reply({ reqId: children[0].written[0].reqId, ok: true });
  assert.equal((await a).ok, true);
  assert.deepEqual(logs.map((l) => l.event), ['helper_bad_line', 'helper_stderr']);
  assert.ok(!JSON.stringify(logs).includes('SECRET'));
  p.close();
});

test('caps in-flight requests', async () => {
  const { spawn, children } = fakeSpawn();
  const p = createPlanner({ bin: 'x', spawn, maxInFlight: 1 });
  const a = p.info();
  const b = p.info();
  await tick();
  assert.equal(children[0].written.length, 1);
  children[0].reply({ reqId: children[0].written[0].reqId, ok: true });
  await a;
  await tick();
  assert.equal(children[0].written.length, 2);
  children[0].reply({ reqId: children[0].written[1].reqId, ok: true });
  await b;
  p.close();
});
