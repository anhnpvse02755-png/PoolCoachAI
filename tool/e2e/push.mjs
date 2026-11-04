import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomBytes, randomUUID, createHash } from 'node:crypto';
import { launch, sleep } from './cdp.mjs';
import { registerThrowaway, deleteUserByEmail } from './throwaway_user.mjs';

const need = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Thiếu ${name}`);
  return value;
};

if (process.env.PCAI_ALLOW_LIVE_DIRECTUS_E2E !== '1') {
  throw new Error(
    'Bài này tạo/xoá user và dữ liệu Directus thật. Đặt PCAI_ALLOW_LIVE_DIRECTUS_E2E=1 sau khi xác nhận môi trường.',
  );
}

const APP = (process.argv[2] ?? 'https://poolcoachai.kjdybl.easypanel.host').replace(/\/$/, '');
const DIRECTUS = need('DIRECTUS_URL').replace(/\/$/, '');
need('DIRECTUS_ADMIN_EMAIL');
need('DIRECTUS_ADMIN_PASSWORD');
const NOTIFY = (
  process.env.NOTIFY_URL ?? 'https://poolcoachai-notify.kjdybl.easypanel.host'
).replace(/\/$/, '');
const shots = path.join(process.env.TMP ?? os.tmpdir(), 'pcai-push');
const email = `e2e-push-${Date.now()}@poolcoachai.example.com`;
const password = randomBytes(6).toString('hex');
const userName = 'Người thử E2E';

fs.mkdirSync(shots, { recursive: true });

let tab;
let failures = 0;
let adminToken;

async function check(ok, label) {
  console.log(`${ok ? 'ĐẠT ' : 'HỎNG'}  ${label}`);
  if (ok) return;
  failures++;
  try {
    await tab?.shot(path.join(shots, `fail-${failures}.png`));
  } catch (error) {
    console.warn(`Không chụp được ảnh lỗi: ${error}`);
  }
}

async function adminRequest(route, options = {}) {
  const response = await fetch(`${DIRECTUS}${route}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${adminToken}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  });
  if (!response.ok) throw new Error(`Directus trả HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
}

async function loginAdmin() {
  const response = await fetch(`${DIRECTUS}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: process.env.DIRECTUS_ADMIN_EMAIL,
      password: process.env.DIRECTUS_ADMIN_PASSWORD,
    }),
  });
  const body = await response.json();
  adminToken = body?.data?.access_token;
  if (!response.ok || !adminToken) {
    throw new Error(`Không đăng nhập được Directus admin (HTTP ${response.status})`);
  }
}

async function getUserId() {
  const result = await adminRequest(
    `/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id&limit=1`,
  );
  const userId = result?.data?.[0]?.id;
  if (typeof userId !== 'string') throw new Error('Không tìm thấy user E2E');
  return userId;
}

async function waitFor(predicate, timeoutMs, intervalMs = 500) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const value = await predicate();
    if (value) return value;
    await sleep(intervalMs);
  }
  return null;
}

async function waitForRoute(route) {
  return waitFor(
    () => tab.eval(`location.pathname === ${JSON.stringify(route)}`),
    15_000,
  );
}

async function injectWorkerPush({ userId, deviceId, key }) {
  const deliveryId = createHash('sha256')
    .update(`e2e:${randomUUID()}`)
    .digest('hex');
  const title = '[e2e] Web Push fixture';
  const body = '[e2e] Kiểm tra worker, inbox và xác nhận đã hiện.';
  const at = new Date().toISOString();
  await adminRequest('/items/push_deliveries', {
    method: 'POST',
    body: JSON.stringify({
      id: deliveryId,
      user: userId,
      device: deviceId,
      notification_id: 1,
      kind: 'streak',
      key,
      title,
      body,
      at,
      sent_at: at,
      shown_at: null,
    }),
  });

  const workerRegistrations = [];
  tab.ws.addEventListener('message', (event) => {
    try {
      const message = JSON.parse(event.data);
      if (message.method === 'ServiceWorker.workerRegistrationUpdated') {
        workerRegistrations.push(...(message.params?.registrations ?? []));
      }
    } catch {
      // Ignore unrelated DevTools frames.
    }
  });
  await tab.send('ServiceWorker.enable');
  const registration = await waitFor(
    () => workerRegistrations.find((r) => r.scopeURL === `${APP}/push/`),
    10_000,
  );
  if (!registration) throw new Error('Không tìm thấy đăng ký Service Worker /push/');

  const payload = `v2|${userId}|streak|${key}`;
  await tab.send('ServiceWorker.deliverPushMessage', {
    origin: APP,
    registrationId: registration.registrationId,
    data: JSON.stringify({
      v: 1,
      deliveryId,
      notificationId: 1,
      kind: 'streak',
      key,
      title,
      body,
      payload,
      ackUrl: `${NOTIFY}/push/ack`,
    }),
  });

  const shown = await waitFor(
    () =>
      tab.eval(`(async () => {
        const registration = await navigator.serviceWorker.getRegistration('/push/');
        const notifications = await registration?.getNotifications() ?? [];
        return notifications.some((notification) => notification.title === ${JSON.stringify(title)});
      })()`),
    10_000,
  );
  await check(shown === true, 'Worker hiển thị thông báo kiểm thử');

  const row = await waitFor(async () => {
    const result = await adminRequest(
      `/items/push_deliveries?filter[id][_eq]=${deliveryId}&fields=id,shown_at&limit=1`,
    );
    return result?.data?.[0]?.shown_at ? result.data[0] : null;
  }, 15_000);
  await check(row != null, 'Worker xác nhận shown_at trong vòng 15 giây');

  await tab.reload();
  await tab.goto(`${APP}/notifications`);
  const inbox = await waitFor(
    async () => (await tab.text()).includes(title),
    15_000,
  );
  await check(inbox === true, 'Hộp Đã gửi hiển thị thông báo kiểm thử');
  return { payload, title };
}

try {
  console.log('\n── Bước 1: Cấp quyền, tạo tài khoản thử và mở Thông báo');
  tab = await launch({ port: 9355, name: 'push' });
  let grantError;
  try {
    await tab.send('Browser.grantPermissions', {
      origin: APP,
      permissions: ['notifications'],
    });
  } catch (error) {
    grantError = error;
  }
  await registerThrowaway(tab, APP, { email, password, name: userName });
  await loginAdmin();
  const userId = await getUserId();
  await tab.goto(`${APP}/notifications`);
  if ((await tab.text()).includes('Bật thông báo')) {
    await tab.click('Bật thông báo');
  }

  console.log('\n── Bước 2: Chờ subscription Web Push');
  const subscription = await waitFor(
    () =>
      tab.eval(`(async () => {
        const registration = await navigator.serviceWorker.getRegistration('/push/');
        return Boolean(await registration?.pushManager.getSubscription());
      })()`),
    20_000,
  );
  let pushTest = null;
  if (!subscription) {
    const screen = await tab.text();
    console.log(
      'KHÔNG ĐĂNG KÝ ĐƯỢC PUSH TRONG CHROME CHẠY NGẦM — chỉ kiểm chế độ cục bộ',
    );
    await check(
      screen.includes('Trình duyệt này chưa nhận được thông báo khi đã đóng tab') ||
        screen.includes('chỉ hiện khi tab còn mở'),
      'Giao diện giải thích chế độ thông báo cục bộ',
    );
    if (grantError) console.warn(`Chrome không cấp được quyền: ${grantError}`);
  } else {
    console.log('\n── Bước 3: Kiểm tra thiết bị và lease trên Directus');
    const devices = await adminRequest(
      `/items/push_devices?filter[user][_eq]=${encodeURIComponent(userId)}&fields=id,mode,lease_until&limit=-1`,
    );
    const device = devices?.data?.find((row) => row.mode === 'server');
    await check(
      device != null && Date.parse(device.lease_until) > Date.now(),
      'Có thiết bị mode=server với lease còn hạn',
    );
    await check(
      (await tab.text()).includes('Thông báo được gửi từ máy chủ'),
      'Màn hình Thông báo xác nhận máy chủ đang gửi',
    );
    if (device) {
      console.log('\n── Bước 4: Đẩy push giả vào Service Worker');
      const key = new Date().toISOString().slice(0, 10);
      pushTest = await injectWorkerPush({ userId, deviceId: device.id, key });
    }
  }

  console.log('\n── Bước 5: Kiểm tra chạm và mở lạnh');
  const payload = pushTest?.payload ?? `v2|${userId}|streak|${new Date().toISOString().slice(0, 10)}`;
  await tab.goto(`${APP}/notifications`);
  await tab.eval(`new BroadcastChannel('pcai-push').postMessage({
    type: 'tap',
    payload: ${JSON.stringify(payload)}
  })`);
  await check(await waitForRoute('/training'), 'Chạm trong tab mở đúng Trung tâm luyện tập');

  await tab.goto(`${APP}/?n=${encodeURIComponent(payload)}`);
  const coldStart = await waitFor(
    () =>
      tab.eval(
        `location.pathname === '/training' && !new URL(location.href).searchParams.has('n')`,
      ),
    15_000,
  );
  await check(coldStart === true, 'Mở lạnh mở đúng màn và xoá payload khỏi URL');

  console.log('\n── Bước 6: Đăng xuất huỷ subscription và thiết bị');
  await tab.goto(`${APP}/profile`);
  await tab.click('Đăng xuất');
  if ((await tab.text()).includes('Vẫn đăng xuất')) await tab.click('Vẫn đăng xuất');
  await tab.waitForText('Đăng nhập', 45_000);
  const subscriptionAfterSignOut = await tab.eval(`(async () => {
    const registration = await navigator.serviceWorker.getRegistration('/push/');
    return Boolean(await registration?.pushManager.getSubscription());
  })()`);
  await check(subscriptionAfterSignOut === false, 'Đăng xuất huỷ subscription Web Push');
  if (pushTest) {
    const devices = await adminRequest(
      `/items/push_devices?filter[user][_eq]=${encodeURIComponent(userId)}&fields=id&limit=-1`,
    );
    await check(devices?.data?.length === 0, 'Đăng xuất xoá thiết bị push trên máy chủ');
  }
} catch (error) {
  failures++;
  console.error(`\nLỗi không bắt được: ${error?.stack ?? error}`);
  try {
    await tab?.shot(path.join(shots, 'fail-uncaught.png'));
  } catch (shotError) {
    console.warn(`Không chụp được ảnh lỗi: ${shotError}`);
  }
} finally {
  try {
    await tab?.close();
  } catch (error) {
    console.warn(`Không đóng được Chrome: ${error}`);
  }
  try {
    await deleteUserByEmail(email);
  } catch (error) {
    console.warn(`Không xoá được user E2E: ${error}`);
  }
}

console.log(`\n${failures ? `HỎNG ${failures} kiểm tra.` : 'Xong, mọi kiểm tra đạt.'} Ảnh lỗi: ${shots}`);
if (failures) process.exitCode = 1;
