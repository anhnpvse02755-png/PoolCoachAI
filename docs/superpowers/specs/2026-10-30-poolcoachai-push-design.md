# PoolCoachAI — Thông báo đẩy từ máy chủ (P6b)

**Ngày:** 30/10/2026. **Tiền đề:** `main` c32147a (P6a: thông báo cục bộ, hộp "Đã gửi", chạm mở đúng màn).

**Quyết định của chủ dự án (30/10):** làm Web Push và Android (FCM). iOS để sau, vì chủ dự án chưa có tài khoản Apple Developer.

**Dự án Firebase:** `poolcoachai`. `google-services.json` có package `vn.poolcoachai.app`.

Mọi lựa chọn khác dưới đây là **quyết định của Claude**. Bằng chứng nằm trong `2026-10-30-poolcoachai-push-research.md`, trích dẫn theo file:dòng.

## 1. Vì sao cần, so với P6a

Thông báo của P6a được lập trên máy, từ dữ liệu có lúc ứng dụng mở lần cuối. Vì vậy:
- Tập trên máy khác thì nhắc streak vẫn kêu.
- Lịch sửa trên web thì điện thoại không biết.
- Trên web, đóng tab là không còn thông báo.

Máy chủ đọc được dữ liệu đã đồng bộ, nên tính được đúng ngay lúc gửi.

## 2. Nguyên tắc

- **Không bịa.** Nội dung do **chính code Dart của ứng dụng** tính ra: `planNotifications`, `computeRecommendation`, khuôn `Vi`, seed bài tập, id FNV, payload v2.
  - Code này chạy trên máy chủ dưới dạng một helper Dart biên dịch AOT (`bin/notify_plan.dart`), giao tiếp với service qua stdin/stdout.
  - Không viết lại logic bằng Node. Viết lại sẽ nhân đôi đúng phần dễ bịa nhất.
  - Thông báo từ máy chủ và từ máy có **cùng id, cùng câu chữ**.
- **Tính lúc gửi, từ dữ liệu mới.** Lập kế hoạch 15 phút một lần để biết *khi nào* gửi. Tới giờ thì tính lại để biết *gửi gì*. Đã quá `validUntil` thì không gửi.
- **Không trùng.** Ở mỗi máy, mỗi loại thông báo hoặc do máy chủ lo, hoặc do máy lo, không bao giờ cả hai.
  - Khi máy còn hợp đồng máy chủ còn hạn (`lease_until`, 6 giờ), ứng dụng tắt việc lập lịch cục bộ cho các loại máy chủ lo, qua `NotificationPrefs.toggled` sẵn có. `planNotifications` không đổi.
  - Hết hạn, bị gỡ, hoặc công tắc tắt máy chủ được bật, thì ứng dụng quay về lập lịch cục bộ như P6a.
- **"Đã gửi" trung thực.** Chỉ ghi khi thông báo thực sự hiện.
  - Service worker hoặc ứng dụng gửi xác nhận lên `push_deliveries`. Ứng dụng kéo về `notification_log_rows` với cùng id.
  - Không đổi schema Drift (vẫn v17), nên vẫn rollback web được ở mức cho phép.
- **Phiên bản seed.** Mỗi lần đăng ký thiết bị kèm `seedFingerprint`. Máy chủ chỉ lo loại "Gợi ý tập mới" cho thiết bị có fingerprint khớp với seed của helper. Không khớp thì loại đó để máy tự lo.

## 3. Thành phần

**Service mới `server/notify`** (Node, Easypanel `test-va/notify`).
- Nhiệm vụ: lập lịch, đọc Directus bằng service token, gửi Web Push (VAPID) và FCM HTTP v1. FCM dùng JWT RS256 tự ký bằng `node:crypto`, không dùng SDK.
- Không gộp vào `coach-chat`, vì service đó chỉ lo chat, giữ khoá Anthropic và có role riêng.
- Image phải dùng glibc (`node:24-bookworm-slim`), vì helper Dart AOT không chạy trên musl (Alpine).
- Helper được biên dịch trên CI hoặc trên máy dev, không bao giờ trên VPS.

**Directus.** Chạy bootstrap và verify trên prod **trước khi đẩy PR**.
- `notification_settings`: Player chỉ đọc/ghi dòng của mình. Lưu bật/tắt từng loại, cặp gợi ý đã thấy, múi giờ IANA. Thay cho phần lưu cục bộ ở P6a, và vẫn đọc được bản cục bộ cũ.
- `push_devices`: Player **không** có quyền. Đăng ký và huỷ đi qua service `notify`, vì một máy có thể đổi chủ. Lưu kênh (web/fcm), endpoint hoặc token, chế độ (server/local), `lease_until`, `seedFingerprint`, nền tảng.
- `push_deliveries`: Player chỉ đọc dòng của mình. Lưu id, kind, key, at, title, body, `shown_at`.
- Role mới `PushService` có user dịch vụ riêng, chỉ được đọc đúng các trường cần trong dữ liệu người chơi.
- `verify.mjs` thêm kiểm tra tương ứng.

**Giới hạn.**
- Tối đa 12 lần gửi mỗi người mỗi ngày.
- Tối đa 10 thiết bị mỗi người.
- Endpoint trả 404/410 hoặc FCM báo UNREGISTERED thì gỡ thiết bị.
- Giờ yên lặng chưa làm, như P6a §7.

**Đăng xuất** thì huỷ đăng ký thiết bị: `deleteToken()` / `unsubscribe()` và gọi service. Làm vậy để máy dùng chung không còn nhận thông báo của tài khoản cũ.

## 4. Web

- Flutter 3.47 tự đăng ký lại `flutter_service_worker.js`, một worker tự gỡ, ở scope `/` mỗi lần tải trang. Một worker push đặt ở `/` sẽ bị thay và mất đăng ký.
  - Vì vậy worker push đặt ở **`/push/sw.js`, scope `/push/`**.
  - Ứng dụng dùng `web/flutter_bootstrap.js` riêng, không có `serviceWorkerSettings`.
- Đăng ký qua `PushManager` bằng `dart:js_interop`, chỉ trong file nền tảng web, theo mẫu conditional import của P6a. Khoá VAPID công khai được nhúng lúc build.
- Chạm thông báo:
  - Đang có tab mở: gửi `BroadcastChannel` tới tab đó.
  - Không có tab: mở `/?n=<payload>`.
  - Bộ định tuyến của P6a xử lý tiếp, không đổi.
- iOS 16.4+ nhận được Web Push khi ứng dụng được thêm vào màn hình chính, vì `manifest.json` đã có `display: standalone`. Đây là cách cho iPhone dùng tạm trước khi có APNs.

## 5. Android (P6b-2)

- Dùng `firebase_core` và `firebase_messaging`, ghim đúng phiên bản vì `pubspec.lock` không được commit.
- Kiểm tra sớm xem plugin Gradle google-services có chạy với AGP 9.1.0 không. Nếu không, viết tay `res/values/firebase.xml`.
- **Commit `google-services.json`.** Firebase coi file này không phải bí mật, và CI Android build APK ở mọi PR. Chủ dự án nên giới hạn API key Android trong GCP.
- Gửi **data message**. Ứng dụng tự hiện bằng `flutter_local_notifications`, cùng id, kênh và payload. Chạm thông báo đi qua đường của P6a.
- Một số hãng (Xiaomi, Oppo, Vivo) chặn chạy nền. Để phát hiện, có ping kiểm tra và xác nhận từng lần giao. Không có xác nhận thì máy đó trở về chế độ cục bộ.
- File service account JSON là **bí mật**. Chỉ đặt vào biến môi trường của service `notify` trên Easypanel, không bao giờ vào repo, chat hay file cấu hình cục bộ.

## 6. Các giai đoạn

1. **P6b-0, chuẩn bị:**
   - Tách `Color` ra khỏi `lib/domain/skill_category.dart`, để domain không còn import Flutter.
   - Tách bộ giải mã dòng Directus thuần (dùng chung cho app và helper).
   - `seedFingerprint`.
   - Helper `bin/notify_plan.dart`, có test so khớp với `planNotifications` của app.
   - Bước biên dịch helper trên CI.
2. **P6b-1, Web Push và backend:**
   - Các collection Directus kèm bootstrap và verify.
   - Service `notify`: lập lịch, gửi Web Push, chống trùng, giới hạn, dọn thiết bị.
   - Service worker `/push/`.
   - Đăng ký và huỷ từ ứng dụng; đồng bộ `notification_settings`; kéo `push_deliveries` về "Đã gửi".
   - E2E `tool/e2e/push.mjs` dùng `ServiceWorker.deliverPushMessage` qua CDP. Chủ dự án tự kiểm một vòng thật trong Chrome thường.
3. **P6b-2, Android FCM:** làm khi có file service account.
4. **P6b-3, iOS:** làm khi có tài khoản Apple Developer và khoá APNs.

## 7. Phát hành

Thứ tự:
1. Bootstrap và verify Directus trên prod.
2. Deploy service `notify`. Easypanel cần domain hoặc đường dẫn mới, và biến môi trường cho VAPID cùng service token. Claude tạo các khoá này.
3. PR, merge, publish web.
4. Chạy e2e trên bản live.

Bản ứng dụng cũ không bị ảnh hưởng, vì chúng không bao giờ đăng ký thiết bị.

Service `notify` có công tắc tắt (`PUSH_ENABLED=false`). Khi tắt, mọi máy tự quay về chế độ cục bộ khi `lease` hết hạn.

## 8. Ngoài phạm vi

- iOS APNs.
- Giờ yên lặng.
- Thông báo từ Coach Chat. Chủ dự án quyết ngày 30/10: chưa dùng AI.
- Thông báo marketing.
