import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildPlanRequest, settingsPrefs, RequestError } from '../src/requests.mjs';

const settings = {
  recommendation: true, maintenance: false, schedule: true, streak: false,
  last_seen_cat: 'break', last_seen_drill_id: 'd1', last_seen_at: '2026-10-30T01:02:03Z',
};
const base = { userId: 'u', nowUtc: '2026-10-30T02:00:00Z', tz: 'Asia/Ho_Chi_Minh', mode: 'due', data: { drills: [] } };

test('settingsPrefs keeps booleans as stored', () => {
  assert.deepEqual(settingsPrefs(settings), { recommendation: true, maintenance: false, schedule: true, streak: false });
});

test('maps prefs and seen', () => {
  const r = buildPlanRequest({ ...base, settings, deliveries: [] });
  assert.equal(r.op, 'plan');
  assert.deepEqual(r.prefs, settingsPrefs(settings));
  assert.deepEqual(r.seen, { cat: 'break', drillId: 'd1', atUtc: '2026-10-30T01:02:03.000Z' });
  assert.equal(r.data, base.data);
});

test('seen is null when any last_seen is missing', () => {
  for (const k of ['last_seen_cat', 'last_seen_drill_id', 'last_seen_at']) {
    const r = buildPlanRequest({ ...base, settings: { ...settings, [k]: null }, deliveries: [] });
    assert.equal(r.seen, null, k);
  }
});

test('zone-less Directus time is read as UTC', () => {
  const r = buildPlanRequest({ ...base, settings: { ...settings, last_seen_at: '2026-10-30T01:02:03' }, deliveries: [] });
  assert.equal(r.seen.atUtc, '2026-10-30T01:02:03.000Z');
});

test('only sent recommendations are passed', () => {
  const deliveries = [
    { kind: 'recommendation', key: 'k1', at: '2026-10-29T01:00:00Z', sent_at: '2026-10-29T01:00:05Z' },
    { kind: 'recommendation', key: 'k2', at: '2026-10-29T02:00:00Z', sent_at: null },
    { kind: 'schedule', key: 'k3', at: '2026-10-29T03:00:00Z', sent_at: '2026-10-29T03:00:05Z' },
  ];
  const r = buildPlanRequest({ ...base, settings, deliveries });
  assert.deepEqual(r.sentRecommendations, [{ key: 'k1', atUtc: '2026-10-29T01:00:00.000Z' }]);
});

test('full request object', () => {
  const deliveries = [{ kind: 'recommendation', key: 'k1', at: '2026-10-29T01:00:00Z', sent_at: 'x', user: 'u' }];
  const r = buildPlanRequest({ ...base, settings: { ...settings, id: 'row', timezone: 'x' }, deliveries });
  assert.deepEqual(r, {
    op: 'plan', userId: 'u', nowUtc: '2026-10-30T02:00:00Z', tz: 'Asia/Ho_Chi_Minh', mode: 'due',
    prefs: { recommendation: true, maintenance: false, schedule: true, streak: false },
    seen: { cat: 'break', drillId: 'd1', atUtc: '2026-10-30T01:02:03.000Z' },
    sentRecommendations: [{ key: 'k1', atUtc: '2026-10-29T01:00:00.000Z' }],
    data: base.data,
  });
});

test('null/undefined settings use the app defaults (all on, nothing seen)', () => {
  for (const s of [null, undefined]) {
    const r = buildPlanRequest({ ...base, settings: s });
    assert.deepEqual(r.prefs, { recommendation: true, maintenance: true, schedule: true, streak: true });
    assert.equal(r.seen, null);
    assert.deepEqual(r.sentRecommendations, []);
  }
});

test('bad or missing timestamps throw a typed RequestError', () => {
  const del = (at) => [{ kind: 'recommendation', key: 'k', at, sent_at: 'x' }];
  for (const at of [undefined, null, '', 'not a date']) {
    assert.throws(() => buildPlanRequest({ ...base, settings, deliveries: del(at) }),
      (e) => e instanceof RequestError && e.code === 'bad_timestamp');
  }
  assert.throws(() => buildPlanRequest({ ...base, settings: { ...settings, last_seen_at: 'zzz' } }),
    (e) => e instanceof RequestError && e.code === 'bad_timestamp');
});

test('a delivery of another user is a caller bug and throws', () => {
  const deliveries = [{ kind: 'schedule', key: 'k', at: '2026-10-29T01:00:00Z', sent_at: null, user: 'other' }];
  assert.throws(() => buildPlanRequest({ ...base, settings, deliveries }),
    (e) => e instanceof RequestError && e.code === 'foreign_delivery');
});
