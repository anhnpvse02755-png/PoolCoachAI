import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import webPush from 'web-push';
import { createWebPushSender, pushTopic, pushUrgency, ttlSeconds } from '../src/webpush.mjs';

const ENDPOINT = 'https://fcm.googleapis.com/fcm/send/abc123';
const vapidKeys = webPush.generateVAPIDKeys();
const VAPID = { publicKey: vapidKeys.publicKey, privateKey: vapidKeys.privateKey, subject: 'mailto:ops@example.com' };

const MESSAGE = { v: 1, deliveryId: 'd1', notificationId: 'n1', kind: 'schedule', key: 'k1',
  title: 'Đến giờ tập', body: 'Bài kê gậy 30 phút', payload: { route: '/schedule' }, ackUrl: 'https://x.example/ack/d1' };

function receiver() {
  const ecdh = crypto.createECDH('prime256v1');
  ecdh.generateKeys();
  const auth = crypto.randomBytes(16);
  const device = { endpoint: ENDPOINT, key_p256dh: ecdh.getPublicKey().toString('base64url'), key_auth: auth.toString('base64url') };
  return { ecdh, auth, device };
}

const hmac = (key, data) => crypto.createHmac('sha256', key).update(data).digest();
// HKDF-Expand thuần (một khối T(1), đủ cho độ dài ≤ 32).
function hkdfExpand(prk, info, len) {
  return hmac(prk, Buffer.concat([info, Buffer.from([1])])).subarray(0, len);
}

// RFC 8291 §3.4 giải mã bên nhận.
function decrypt(body, { ecdh, auth }) {
  const salt = body.subarray(0, 16);
  const idlen = body[20];
  const asPub = body.subarray(21, 21 + idlen);
  const cipher = body.subarray(21 + idlen);
  const uaPub = ecdh.getPublicKey();
  const secret = ecdh.computeSecret(asPub);
  const prkKey = hmac(auth, secret);
  const ikm = hkdfExpand(prkKey, Buffer.concat([Buffer.from('WebPush: info\0'), uaPub, asPub]), 32);
  const prk = hmac(salt, ikm);
  const cek = hkdfExpand(prk, Buffer.from('Content-Encoding: aes128gcm\0'), 16);
  const nonce = hkdfExpand(prk, Buffer.from('Content-Encoding: nonce\0'), 12);
  const d = crypto.createDecipheriv('aes-128-gcm', cek, nonce);
  d.setAuthTag(cipher.subarray(cipher.length - 16));
  const plain = Buffer.concat([d.update(cipher.subarray(0, cipher.length - 16)), d.final()]);
  assert.equal(plain[plain.length - 1], 0x02);
  return plain.subarray(0, plain.length - 1).toString('utf8');
}

function capturing(status = 201, headers = {}) {
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, ...init, headers: Object.fromEntries(Object.entries(init.headers).map(([k, v]) => [k.toLowerCase(), v])) });
    return new Response(null, { status, headers });
  };
  return { fetch, calls };
}
const headerOf = (c, n) => c.headers[n.toLowerCase()];

test('mã hoá aes128gcm: bên nhận giải mã ra đúng JSON', async () => {
  const r = receiver();
  const { fetch, calls } = capturing();
  const sender = createWebPushSender({ vapid: VAPID, fetch });
  const res = await sender.send(r.device, MESSAGE, { ttlSeconds: 600, topic: 'abc', urgency: 'high' });
  assert.deepEqual(res, { status: 'sent' });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, ENDPOINT);
  assert.equal(calls[0].method, 'POST');
  assert.equal(decrypt(Buffer.from(calls[0].body), r), JSON.stringify(MESSAGE));
});

test('VAPID: JWT ES256 hợp lệ, aud là origin của endpoint, exp ≤ 24 giờ, sub đúng', async () => {
  const r = receiver();
  const { fetch, calls } = capturing();
  await createWebPushSender({ vapid: VAPID, fetch }).send(r.device, MESSAGE, { ttlSeconds: 60 });
  const m = /^vapid t=([^,]+), k=(.+)$/.exec(headerOf(calls[0], 'authorization'));
  assert.ok(m, 'định dạng vapid');
  const [, jwt, k] = m;
  assert.equal(k, VAPID.publicKey);
  const [h, p, s] = jwt.split('.');
  assert.equal(JSON.parse(Buffer.from(h, 'base64url')).alg, 'ES256');
  const claims = JSON.parse(Buffer.from(p, 'base64url'));
  assert.equal(claims.aud, 'https://fcm.googleapis.com');
  assert.equal(claims.sub, VAPID.subject);
  const now = Date.now() / 1000;
  assert.ok(claims.exp > now && claims.exp <= now + 86400, 'exp trong 24 giờ');
  const raw = Buffer.from(k, 'base64url');
  const key = crypto.createPublicKey({ key: { kty: 'EC', crv: 'P-256', x: raw.subarray(1, 33).toString('base64url'), y: raw.subarray(33).toString('base64url') }, format: 'jwk' });
  const ok = crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'));
  assert.ok(ok, 'chữ ký ES256');
});

test('header: Content-Encoding aes128gcm, TTL, Topic ≤ 32 ký tự base64url, Urgency', async () => {
  const r = receiver();
  const { fetch, calls } = capturing();
  const topic = pushTopic('schedule', 'slot-1');
  await createWebPushSender({ vapid: VAPID, fetch }).send(r.device, MESSAGE, { ttlSeconds: 1234, topic, urgency: 'high' });
  const c = calls[0];
  assert.equal(headerOf(c, 'content-encoding'), 'aes128gcm');
  assert.equal(String(headerOf(c, 'ttl')), '1234');
  assert.equal(headerOf(c, 'topic'), topic);
  assert.match(topic, /^[A-Za-z0-9_-]{32}$/);
  assert.equal(headerOf(c, 'urgency'), 'high');
});

test('pushTopic, pushUrgency, ttlSeconds', () => {
  assert.equal(pushTopic('a', 'b'), crypto.createHash('sha256').update('a:b').digest('base64url').slice(0, 32));
  assert.equal(pushUrgency('schedule'), 'high');
  assert.equal(pushUrgency('streak'), 'high');
  assert.equal(pushUrgency('maintenance'), 'normal');
  assert.equal(pushUrgency('recommendation'), 'normal');
  const now = new Date('2026-10-30T00:00:00Z');
  assert.equal(ttlSeconds('2026-10-30T01:00:00Z', now), 3600);
  assert.equal(ttlSeconds('2026-10-30T00:00:10Z', now), 60);
  assert.equal(ttlSeconds('2026-10-29T00:00:00Z', now), 60);
  assert.equal(ttlSeconds('2030-01-01T00:00:00Z', now), 2_419_200);
});

test('201 → sent; 404, 410 → gone; 429 có Retry-After, 503 → retry; 400 → failed; lỗi mạng → failed', async () => {
  const r = receiver();
  const run = async (status, headers, fetchOverride) => {
    const { fetch } = capturing(status, headers);
    return createWebPushSender({ vapid: VAPID, fetch: fetchOverride ?? fetch }).send(r.device, MESSAGE, { ttlSeconds: 60 });
  };
  assert.deepEqual(await run(201), { status: 'sent' });
  assert.deepEqual(await run(200), { status: 'sent' });
  assert.deepEqual(await run(404), { status: 'gone', code: 404 });
  assert.deepEqual(await run(410), { status: 'gone', code: 410 });
  assert.deepEqual(await run(429, { 'retry-after': '7' }), { status: 'retry', code: 429, retryAfterMs: 7000 });
  assert.deepEqual(await run(429, { 'retry-after': '3600' }), { status: 'retry', code: 429, retryAfterMs: 60_000 });
  assert.equal((await run(503)).status, 'retry');
  assert.equal((await run(503)).code, 503);
  assert.deepEqual(await run(400), { status: 'failed', code: 400 });
  assert.deepEqual(await run(401), { status: 'failed', code: 401 });
  const net = await run(0, {}, async () => { throw new TypeError('fetch failed'); });
  assert.equal(net.status, 'failed');
  assert.equal(net.code, 'network');
});

test('hết giờ chờ: failed timeout', async () => {
  const r = receiver();
  const fetch = (url, init) => new Promise((_, reject) => {
    init.signal.addEventListener('abort', () => reject(init.signal.reason));
  });
  const res = await createWebPushSender({ vapid: VAPID, fetch, timeoutMs: 20 }).send(r.device, MESSAGE, { ttlSeconds: 60 });
  assert.deepEqual(res, { status: 'failed', code: 'timeout' });
});

test('payload quá 3000 byte: failed payload_too_large, không gọi fetch', async () => {
  const r = receiver();
  const { fetch, calls } = capturing();
  const big = { ...MESSAGE, body: 'x'.repeat(3000) };
  const res = await createWebPushSender({ vapid: VAPID, fetch }).send(r.device, big, { ttlSeconds: 60 });
  assert.deepEqual(res, { status: 'failed', code: 'payload_too_large' });
  assert.equal(calls.length, 0);
});

test('endpoint không https, có cổng, có userinfo hoặc ngoài danh sách: failed bad_endpoint, không gọi fetch', async () => {
  const r = receiver();
  const { fetch, calls } = capturing();
  const sender = createWebPushSender({ vapid: VAPID, fetch });
  for (const endpoint of ['http://fcm.googleapis.com/x', 'https://fcm.googleapis.com:8443/x', 'https://u:p@fcm.googleapis.com/x',
    'https://evil.example/x', 'https://fcm.googleapis.com.evil.example/x', 'khong-phai-url', 'https://127.0.0.1/x']) {
    const res = await sender.send({ ...r.device, endpoint }, MESSAGE, { ttlSeconds: 60 });
    assert.deepEqual(res, { status: 'failed', code: 'bad_endpoint' }, endpoint);
  }
  const ok = await sender.send({ ...r.device, endpoint: 'https://updates.push.services.mozilla.com/wpush/v2/x' }, MESSAGE, { ttlSeconds: 60 });
  assert.equal(ok.status, 'sent');
  assert.equal(calls.length, 1);
});

test('khoá riêng VAPID không lọt vào log, kết quả hay thông báo lỗi', async () => {
  const r = receiver();
  const secret = VAPID.privateKey;
  const seen = [];
  const orig = {};
  for (const m of ['log', 'info', 'warn', 'error', 'debug']) {
    orig[m] = console[m];
    console[m] = (...a) => seen.push(a.map(String).join(' '));
  }
  const results = [];
  try {
    // Lỗi mạng mà thông báo lỗi của fetch chứa khoá riêng.
    results.push(await createWebPushSender({ vapid: VAPID, fetch: async () => { throw new Error(`boom ${secret}`); } })
      .send(r.device, MESSAGE, { ttlSeconds: 60 }));
    // Cấu hình VAPID hỏng khiến web-push ném lỗi.
    results.push(await createWebPushSender({ vapid: { ...VAPID, subject: `không hợp lệ ${secret}` }, fetch: capturing().fetch })
      .send(r.device, MESSAGE, { ttlSeconds: 60 }));
    results.push(await createWebPushSender({ vapid: { ...VAPID, privateKey: `ngắn${secret.slice(0, 10)}` }, fetch: capturing().fetch })
      .send(r.device, MESSAGE, { ttlSeconds: 60 }));
  } finally {
    for (const m of Object.keys(orig)) console[m] = orig[m];
  }
  for (const res of results) assert.equal(res.status, 'failed');
  assert.ok(!JSON.stringify(results).includes(secret));
  assert.ok(!JSON.stringify(results).includes(secret.slice(0, 10)));
  assert.ok(!seen.join('\n').includes(secret));
});
