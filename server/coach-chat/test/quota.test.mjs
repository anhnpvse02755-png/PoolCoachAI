import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createQuota, vnDay, nextResetAt } from '../src/quota.mjs';
import { createDirectus, DirectusError } from '../src/directus.mjs';
import { DIRECTUS, SERVICE_TOKEN, fakeDirectus, fakeFetch } from './fakes.mjs';

function setup({ limit = 2, at = '2026-10-22T03:00:00Z', raceOnCreate = false } = {}) {
  let current = new Date(at);
  const d = fakeDirectus({ raceOnCreate });
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fakeFetch({ directus: d }) });
  return { quota: createQuota({ directus, limit, now: () => current }), d, setNow: (iso) => { current = new Date(iso); } };
}

test('ngày và giờ đặt lại theo giờ Việt Nam', () => {
  assert.equal(vnDay(new Date('2026-10-22T16:59:59Z')), '2026-10-22');
  assert.equal(vnDay(new Date('2026-10-22T17:00:00Z')), '2026-10-23');
  assert.equal(nextResetAt(new Date('2026-10-22T10:00:00Z')).toISOString(), '2026-10-22T17:00:00.000Z');
  assert.equal(nextResetAt(new Date('2026-10-22T17:00:00Z')).toISOString(), '2026-10-23T17:00:00.000Z');
});
test('trừ lượt: tạo dòng, tăng dần, chạm trần thì từ chối', async () => {
  const { quota, d } = setup();
  assert.deepEqual(await quota.take('user-a'), { ok: true, day: '2026-10-22', remainingToday: 1 });
  assert.deepEqual(await quota.take('user-a'), { ok: true, day: '2026-10-22', remainingToday: 0 });
  assert.deepEqual(await quota.take('user-a'), { ok: false, limit: 2, resetAt: '2026-10-22T17:00:00.000Z' });
  assert.equal(d.rows.get('user-a_2026-10-22').questions, 2);
});
test('sang ngày mới theo giờ Việt Nam thì đếm lại', async () => {
  const { quota, setNow } = setup({ limit: 1 });
  await quota.take('user-a');
  setNow('2026-10-22T17:00:01Z');
  assert.equal((await quota.take('user-a')).ok, true);
});
test('hoàn lượt về đúng ngày đã trừ, kể cả khi đã qua nửa đêm', async () => {
  const { quota, d, setNow } = setup({ at: '2026-10-22T16:59:00Z' });
  const { day } = await quota.take('user-a');
  setNow('2026-10-22T17:01:00Z');
  await quota.refund('user-a', day);
  assert.equal(d.rows.get('user-a_2026-10-22').questions, 0);
  assert.equal(d.rows.has('user-a_2026-10-23'), false);
});
test('cộng token vào dòng của ngày đó', async () => {
  const { quota, d } = setup();
  const { day } = await quota.take('user-a');
  await quota.addUsage('user-a', day, { input: 900, output: 120, cacheRead: 1800 });
  await quota.addUsage('user-a', day, { input: 100, output: 30, cacheRead: 1800 });
  const row = d.rows.get('user-a_2026-10-22');
  assert.deepEqual([row.input_tokens, row.output_tokens, row.cache_read_tokens], [1000, 150, 3600]);
});
test('hai lượt cùng lúc ở lượt cuối: đúng một lượt qua', async () => {
  // Trần 2: sau một lượt đã trừ sẵn, chỉ còn đúng 1 chỗ. Khác bài test
  // RECORD_NOT_UNIQUE (vốn tự serialize qua việc đọc lại), ở đây nếu không
  // có khoá theo người dùng (R10) thì cả hai lượt đọc dòng (questions: 1)
  // cùng lúc, cả hai đều thấy 1 < 2 nên cả hai đều tăng lên 2 — qua cả hai,
  // sai hạn mức. Có khoá: lượt thứ hai đợi lượt đầu ghi xong, đọc lại thấy
  // 2 >= 2 nên bị từ chối.
  const { quota, d } = setup({ limit: 2 });
  await quota.take('user-a');
  const results = await Promise.all([quota.take('user-a'), quota.take('user-a')]);
  assert.equal(results.filter((r) => r.ok).length, 1);
  assert.equal(d.rows.get('user-a_2026-10-22').questions, 2);
});
test('dòng vừa được nơi khác tạo (RECORD_NOT_UNIQUE): đọc lại rồi tăng', async () => {
  const { quota, d } = setup({ limit: 5, raceOnCreate: true });
  assert.equal((await quota.take('user-a')).ok, true);
  assert.equal(d.rows.get('user-a_2026-10-22').questions, 2);
});
test('RECORD_NOT_UNIQUE nhưng đọc lại vẫn không thấy dòng: ném DirectusError', async () => {
  const directus = {
    readUsage: async () => null,
    createUsage: async () => { throw new DirectusError(400, 'RECORD_NOT_UNIQUE'); },
    updateUsage: async () => {},
  };
  const quota = createQuota({ directus, limit: 2, now: () => new Date('2026-10-22T03:00:00Z') });
  await assert.rejects(
    quota.take('user-a'),
    (e) => e instanceof DirectusError && e.status === 409 && e.code === 'RECORD_NOT_UNIQUE',
  );
});
test('status: hạn mức, đã dùng, còn lại, giờ đặt lại', async () => {
  const { quota } = setup({ limit: 30 });
  await quota.take('user-a');
  assert.deepEqual(await quota.status('user-a'), { limit: 30, used: 1, remainingToday: 29, resetAt: '2026-10-22T17:00:00.000Z' });
});
