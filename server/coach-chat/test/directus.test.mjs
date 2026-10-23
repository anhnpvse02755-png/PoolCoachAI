import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDirectus, DirectusError } from '../src/directus.mjs';
import { DIRECTUS, SERVICE_TOKEN } from './fakes.mjs';

// Review round 1, ruling 3: đọc thân JSON của một phản hồi 200 có thể tự
// nó thất bại (mất kết nối giữa chừng, hoặc thân không phải JSON hợp lệ).
// Cả hai phải thành DirectusError, không ném lỗi thô ra ngoài client.

test('phản hồi 200 nhưng thân không phải JSON hợp lệ: DirectusError BAD_BODY', async () => {
  const fetchFn = async () => new Response('đây không phải JSON', { status: 200 });
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fetchFn });
  await assert.rejects(
    directus.userIdForToken('tok-a'),
    (e) => e instanceof DirectusError && e.status === 502 && e.code === 'BAD_BODY',
  );
  await assert.rejects(
    directus.readUsage('user-a_2026-10-22'),
    (e) => e instanceof DirectusError && e.status === 502 && e.code === 'BAD_BODY',
  );
});

test('mất kết nối khi đang đọc thân JSON của phản hồi 200: DirectusError unreachable', async () => {
  const abortedJson = async () => { throw Object.assign(new Error('hết giờ chờ'), { name: 'AbortError' }); };
  const fetchFn = async () => ({ ok: true, status: 200, json: abortedJson });
  const directus = createDirectus({ url: DIRECTUS, serviceToken: SERVICE_TOKEN, fetch: fetchFn });
  await assert.rejects(
    directus.userIdForToken('tok-a'),
    (e) => e instanceof DirectusError && e.status === 0 && e.code === 'unreachable',
  );
  await assert.rejects(
    directus.readUsage('user-a_2026-10-22'),
    (e) => e instanceof DirectusError && e.status === 0 && e.code === 'unreachable',
  );
});
