import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAuth } from '../src/auth.mjs';
import { createDirectus, DirectusError } from '../src/directus.mjs';
import { DIRECTUS, SERVICE_TOKEN, fakeDirectus, fakeFetch } from './fakes.mjs';

function setup() {
  let ms = 0;
  const now = () => new Date(Date.UTC(2026, 9, 22, 3) + ms);
  const d = fakeDirectus();
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fakeFetch({ directus: d }) });
  return { auth: createAuth({ directus, now }), d, tick: (m) => { ms += m; } };
}
const meCalls = (d) => d.calls.filter((c) => c.path === '/users/me').length;

test('không có Bearer: null, không hỏi Directus', async () => {
  const { auth, d } = setup();
  assert.equal(await auth.userFor(undefined), null);
  assert.equal(await auth.userFor('Basic abc'), null);
  assert.equal(meCalls(d), 0);
});
test('token đúng: id người chơi, đệm 60 giây', async () => {
  const { auth, d, tick } = setup();
  assert.equal(await auth.userFor('Bearer tok-a'), 'user-a');
  tick(59_000); assert.equal(await auth.userFor('Bearer tok-a'), 'user-a');
  assert.equal(meCalls(d), 1);
  tick(2_000); await auth.userFor('Bearer tok-a');
  assert.equal(meCalls(d), 2);
});
test('token sai: null và không đệm', async () => {
  const { auth, d } = setup();
  assert.equal(await auth.userFor('Bearer sai'), null);
  assert.equal(await auth.userFor('Bearer sai'), null);
  assert.equal(meCalls(d), 2);
});
test('Directus sập: ném DirectusError', async () => {
  const { auth, d } = setup();
  d.down = true;
  await assert.rejects(auth.userFor('Bearer tok-a'), DirectusError);
});
