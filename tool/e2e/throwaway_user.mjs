// Tạo user thử qua giao diện và xoá nó qua Directus admin — dùng chung cho các bài E2E.
export async function registerThrowaway(tab, app, { email, password, name = 'Người thử E2E' }) {
  await tab.goto(app);
  await tab.waitForText('Đăng nhập');
  await tab.click('Chưa có tài khoản');
  await tab.type('Tên hiển thị', name);
  await tab.type('Email', email);
  await tab.type('Nhập lại mật khẩu', password);
  await tab.type('Mật khẩu', password);
  await tab.click('Tạo tài khoản');
  await tab.waitForText('Xin chào');
}

export async function deleteUserByEmail(email) {
  if (!process.env.DIRECTUS_URL || !process.env.DIRECTUS_ADMIN_PASSWORD) return;
  // Dọn dẹp hỏng thì chỉ cảnh báo: không được che lỗi thật của bài chạy.
  try {
    const base = process.env.DIRECTUS_URL.replace(/\/$/, '');
    const login = await (await fetch(`${base}/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: process.env.DIRECTUS_ADMIN_EMAIL, password: process.env.DIRECTUS_ADMIN_PASSWORD }),
    })).json();
    const token = login.data.access_token;
    const users = await (await fetch(`${base}/users?filter[email][_eq]=${encodeURIComponent(email)}&fields=id`, { headers: { Authorization: `Bearer ${token}` } })).json();
    for (const u of users.data) {
      await fetch(`${base}/users/${u.id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
    }
    console.log('Đã xoá user thử');
  } catch (cleanupError) {
    console.warn(`Cảnh báo: không xoá được user thử ${email}: ${cleanupError}`);
  }
}
