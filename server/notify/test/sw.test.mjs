import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../../web/push/sw.js', import.meta.url), 'utf8');

function harness({ subscription = { endpoint: 'https://push.example/device' }, windows = [] } = {}) {
  const listeners = new Map();
  const notifications = [];
  const broadcasts = [];
  const opened = [];
  const ackRequests = [];
  const pending = [];
  const worker = {
    addEventListener(name, callback) {
      listeners.set(name, callback);
    },
    skipWaiting: async () => {},
    registration: {
      showNotification: async (title, options) => notifications.push({ title, options }),
      pushManager: { getSubscription: async () => subscription },
    },
    clients: {
      matchAll: async () => windows,
      openWindow: async (url) => opened.push(url),
    },
    location: { origin: 'https://poolcoachai.example' },
  };
  class Channel {
    constructor(name) { this.name = name; }
    postMessage(data) { broadcasts.push({ name: this.name, data }); }
    close() {}
  }
  const context = vm.createContext({
    self: worker,
    URL,
    Date,
    encodeURIComponent,
    BroadcastChannel: Channel,
    fetch: async (...args) => { ackRequests.push(args); return { ok: true }; },
  });
  vm.runInContext(source, context);

  async function dispatch(name, event) {
    listeners.get(name)(event);
    if (event.promise) await event.promise;
    await Promise.all(pending.splice(0));
  }

  return {
    notifications,
    broadcasts,
    opened,
    ackRequests,
    pending,
    dispatch,
    listeners,
    worker,
  };
}

function pushEvent(data) {
  return {
    data: { json: () => JSON.parse(data) },
    waitUntil(promise) { this.promise = promise; },
  };
}

test('push hợp lệ hiện thông báo, phát shown và xác nhận bằng text/plain', async () => {
  const h = harness();
  const event = pushEvent(JSON.stringify({
    v: 1,
    deliveryId: 'delivery-1',
    notificationId: 7,
    kind: 'streak',
    key: '2026-11-04',
    title: 'Tiêu đề',
    body: 'Nội dung',
    payload: 'v2|user|streak|2026-11-04',
    ackUrl: 'https://notify.example/push/ack',
  }));
  await h.dispatch('push', event);
  assert.deepEqual(JSON.parse(JSON.stringify(h.notifications)), [{
    title: 'Tiêu đề',
    options: {
      body: 'Nội dung',
      tag: 'streak:2026-11-04',
      data: { payload: 'v2|user|streak|2026-11-04', deliveryId: 'delivery-1' },
      icon: '/icons/Icon-192.png',
    },
  }]);
  assert.equal(h.broadcasts[0].name, 'pcai-push');
  assert.equal(h.broadcasts[0].data.type, 'shown');
  assert.equal(h.broadcasts[0].data.v, 1);
  assert.equal(h.broadcasts[0].data.deliveryId, 'delivery-1');
  assert.equal(h.ackRequests.length, 1);
  assert.equal(h.ackRequests[0][0], 'https://notify.example/push/ack');
  assert.equal(h.ackRequests[0][1].headers['content-type'], 'text/plain');
  assert.deepEqual(JSON.parse(h.ackRequests[0][1].body), {
    endpoint: 'https://push.example/device',
    deliveryId: 'delivery-1',
  });
});

test('push sai phiên bản hoặc không JSON không hiện và không xác nhận', async () => {
  const h = harness();
  await h.dispatch('push', pushEvent(JSON.stringify({ v: 2 })));
  await h.dispatch('push', {
    data: { json: () => { throw new SyntaxError('invalid'); } },
    waitUntil(promise) { this.promise = promise; },
  });
  assert.equal(h.notifications.length, 0);
  assert.equal(h.ackRequests.length, 0);
});

test('URL ack không HTTPS hoặc thiếu subscription thì không gọi fetch', async () => {
  const insecure = harness();
  await insecure.dispatch('push', pushEvent(JSON.stringify({
    v: 1, kind: 'streak', key: 'day', title: 'T', body: 'B', payload: 'p',
    ackUrl: 'http://notify.example/push/ack',
  })));
  const unsubscribed = harness({ subscription: null });
  await unsubscribed.dispatch('push', pushEvent(JSON.stringify({
    v: 1, kind: 'streak', key: 'day', title: 'T', body: 'B', payload: 'p',
    ackUrl: 'https://notify.example/push/ack',
  })));
  assert.equal(insecure.ackRequests.length, 0);
  assert.equal(unsubscribed.ackRequests.length, 0);
});

test('chạm tập trung tab và phát tap; không có tab thì mở URL cold-start', async () => {
  const messages = [];
  let focused = 0;
  const client = {
    url: 'https://poolcoachai.example/',
    focus: async () => { focused++; },
  };
  const h = harness({ windows: [client] });
  const event = {
    notification: { data: { payload: 'v2|user|streak|day' }, close() {} },
    waitUntil(promise) { this.promise = promise; },
  };
  await h.dispatch('notificationclick', event);
  assert.equal(focused, 1);
  assert.equal(h.broadcasts[0].data.type, 'tap');
  assert.equal(h.broadcasts[0].data.payload, 'v2|user|streak|day');

  const cold = harness();
  await cold.dispatch('notificationclick', event);
  assert.deepEqual(cold.opened, ['/?n=v2%7Cuser%7Cstreak%7Cday']);
});

test('lỗi ack không làm hỏng sự kiện push', async () => {
  const h = harness();
  h.worker.registration.pushManager.getSubscription = async () => { throw new Error('offline'); };
  const event = pushEvent(JSON.stringify({
    v: 1, deliveryId: 'd', notificationId: 1, kind: 'streak', key: 'day',
    title: 'T', body: 'B', payload: 'p', ackUrl: 'https://notify.example/push/ack',
  }));
  await h.dispatch('push', event);
  await event.promise;
  assert.equal(h.notifications.length, 1);
});

test('install skips waiting and activate does not claim clients', async () => {
  const h = harness();
  let skipped = 0;
  h.worker.skipWaiting = async () => { skipped++; };
  await h.dispatch('install', { waitUntil: (promise) => h.pending.push(promise) });
  assert.equal(skipped, 1);
  assert.equal(h.worker.clients.claim, undefined);
});
