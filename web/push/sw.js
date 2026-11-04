'use strict';

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('push', (event) => {
  let message;
  try {
    message = event.data?.json();
  } catch {
    return;
  }
  if (message?.v !== 1) return;

  event.waitUntil((async () => {
    const tag = `${message.kind}:${message.key}`;
    await self.registration.showNotification(message.title, {
      body: message.body,
      tag,
      data: { payload: message.payload, deliveryId: message.deliveryId },
      icon: '/icons/Icon-192.png',
    });

    try {
      const channel = new BroadcastChannel('pcai-push');
      channel.postMessage({
        v: 1,
        type: 'shown',
        deliveryId: message.deliveryId,
        notificationId: message.notificationId,
        kind: message.kind,
        key: message.key,
        title: message.title,
        body: message.body,
        shownAt: new Date().toISOString(),
      });
      channel.close();
    } catch {
      // Showing the notification takes priority over local inbox updates.
    }

    const ackUrl = message.ackUrl;
    if (typeof ackUrl !== 'string' || !ackUrl.startsWith('https://')) return;
    try {
      const subscription = await self.registration.pushManager.getSubscription();
      if (!subscription) return;
      await fetch(ackUrl, {
        method: 'POST',
        headers: { 'content-type': 'text/plain' },
        body: JSON.stringify({
          endpoint: subscription.endpoint,
          deliveryId: message.deliveryId,
        }),
      });
    } catch {
      // A missed acknowledgement is retried by the next registration cycle.
    }
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const payload = event.notification.data?.payload;
  if (typeof payload !== 'string') return;

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const client = windows.find((candidate) =>
      new URL(candidate.url).origin === self.location.origin);
    if (client) {
      await client.focus();
      try {
        const channel = new BroadcastChannel('pcai-push');
        channel.postMessage({ type: 'tap', payload });
        channel.close();
      } catch {
        // The visible app can still handle taps from its launch URL.
      }
      return;
    }
    await self.clients.openWindow(`/?n=${encodeURIComponent(payload)}`);
  })());
});
