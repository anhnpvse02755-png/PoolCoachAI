# PoolCoachAI — Thông báo gợi ý mới, hộp thông báo, mở đúng màn (P6a)

**Ngày:** 29/10/2026. **Tiền đề:** `main` 349874d.
**Quyết định:** chủ dự án giao toàn quyền ("bạn tự quyết đi"). Mọi lựa chọn dưới đây là **quyết định của Claude**, có ghi lý do để chủ dự án sửa khi cần.

## 1. Hiện trạng và phần còn thiếu

Hiện đã có thông báo **cục bộ** cho ba loại: bảo dưỡng cơ, lịch tập, giữ streak. Logic nằm ở `planNotifications` và `NotificationService`.
- **Android/iOS:** hệ điều hành hẹn giờ, nên thông báo vẫn đến khi ứng dụng đóng.
- **Web:** chỉ đến khi tab còn mở.

Còn thiếu:
- PRD :125 và ý tưởng :394: "thông báo khi có gợi ý mới từ Coach".
- Push khi ứng dụng đóng.
- Spec shell :486/:547: loại `đềXuấtMới` và màn thông báo "đọc được".

## 2. Chia hai phần

| Phần | Nội dung | Cần gì |
|---|---|---|
| **P6a (spec này)** | Loại thông báo **Gợi ý mới**, hộp thông báo đã gửi kèm số chưa đọc, chạm thông báo mở đúng màn, sửa câu chữ cũ | Không cần hạ tầng mới |
| P6b (spec sau) | Push từ máy chủ khi ứng dụng/tab đã đóng: Web Push (VAPID, service worker, dịch vụ gửi) trước; FCM (Android) và APNs (iOS) khi có tài khoản | Dự án Firebase, tài khoản Apple Developer (chủ dự án chưa có), một dịch vụ gửi trên Easypanel |

Lý do chia: P6a dùng được ngay, và trên Android/iOS đã đến được khi ứng dụng đóng. P6b phụ thuộc tài khoản bên ngoài.

## 3. Thông báo "Gợi ý mới"

**Nguồn dữ liệu.** Dùng **đúng** `computeRecommendation`, hàm mà Home dùng, chạy trên dữ liệu thật trên máy, với "hôm nay" là ngày giao thông báo.
- Không có câu chữ cố định.
- Nội dung là khuôn trong `vi.dart`, điền tên bài, nhóm và lý do (`PickReason`), giống thẻ gợi ý ở Home.
- Thiếu dữ liệu, tức gợi ý không có bài, thì **không** gửi.

**Thế nào là "mới".**
- Gợi ý của ngày D được giao lúc **08:00** ngày D (hằng `recommendationReminderHour = 8`) **chỉ khi** cặp (nhóm, bài) của D **khác** cặp người chơi thấy lần cuối.
- "Thấy lần cuối" được ghi khi Home hiển thị thẻ gợi ý, lưu cục bộ theo tài khoản (shared_preferences, như prefs hiện có).
- Lý do: nhắc mỗi sáng một gợi ý không đổi thì thành phiền. "Mới" ở đây nghĩa là có điều người chơi chưa thấy.

**Lập lịch.**
- Lập trong `planNotifications` với tầm hai ngày:
  - hôm nay, nếu chưa tới 08:00;
  - ngày mai.
- Mỗi ngày dùng `today = ngày đó`.
- Dữ liệu thay đổi (buổi tập, trận, BU, lịch) thì kế hoạch được lập lại như các loại khác. Thông báo cũ bị huỷ nhờ id băm theo nội dung.
- Bỏ qua ngày đã có buổi tập của chính bài được gợi ý.

**Giới hạn**, ghi rõ trong màn thông báo:
- Trên máy, gợi ý được tính từ dữ liệu có lúc ứng dụng mở lần cuối. Nếu người chơi tập trên máy khác, thông báo có thể chưa theo kịp.
- Trên web, thông báo chỉ đến khi tab còn mở, cho tới P6b.

**Cài đặt.**
- Thêm `NotificationKind.recommendation`, có công tắc riêng, mặc định bật.
- Kênh Android mới `recommendation_reminder`.

## 4. Hộp thông báo đã gửi

**Lưu.**
- Bảng Drift mới `notification_log_rows` (v17), chỉ trên máy, không đồng bộ. Cột: id, user_id, kind, key, at, title, body, read_at?.
- Khi lập kế hoạch, mỗi mục được ghi vào log, với `at` là thời điểm giao.
- Hộp thông báo chỉ hiện các mục có `at ≤ bây giờ`, tức đã tới giờ.
- Một mục có `at` trong tương lai mà sau đó bị huỷ, vì kế hoạch đổi trước giờ giao, thì bị xoá khỏi log.

Lý do: ứng dụng không biết chắc lúc hệ điều hành giao thông báo trong khi ứng dụng đóng. Mốc "đã tới giờ" là trung thực nhất. Trên web, mục được ghi lúc thông báo thật sự hiện.

**Hiển thị.**
- Màn Thông báo có mục **"Đã gửi"**, xếp mới nhất trước, trong 30 ngày.
- Mục chưa đọc in đậm.
- Mở màn thì đánh dấu đã đọc.
- Chuông ở thanh trên có **số chưa đọc** (huy hiệu). Bằng 0 thì không hiện số.

**Đăng xuất** xoá log của tài khoản, như các bảng khác.

## 5. Chạm thông báo mở đúng màn

Payload của thông báo là `kind|key`. Khi chạm (ứng dụng đang mở, chạy nền hay khởi động từ thông báo), ứng dụng mở màn tương ứng:

| Loại | Mở |
|---|---|
| Gợi ý mới | Chi tiết bài được gợi ý |
| Lịch tập | Lịch tập |
| Bảo dưỡng cơ | Cơ bi-a |
| Streak | Luyện tập |

Đồng thời đánh dấu mục đó đã đọc. Trên web, cùng hành vi qua `onclick` của `Notification`.

## 6. Sửa câu chữ cũ

- `vi.dart` (~:460, :465): "Chỉ hoạt động khi ứng dụng đang mở" sai cho Android/iOS. Thay bằng câu theo nền tảng, dùng cờ `schedulesInBackground` sẵn có.
- PRD :188, :125 và bảng trạng thái ở tài liệu ý tưởng: cập nhật sau khi xong.

## 7. Ngoài phạm vi (P6b)

- Push từ máy chủ.
- Giờ yên lặng do người chơi chọn.
- Đồng bộ cài đặt thông báo giữa các máy.

## 8. Kiểm thử

- **Domain:**
  - "Mới" chỉ khi (nhóm, bài) khác lần thấy cuối.
  - Không gửi khi không có bài.
  - Bỏ qua ngày đã tập bài đó.
  - Tầm hai ngày, giờ 08:00.
  - Id đổi khi nội dung đổi.
- **Chống bịa:** đổi dữ liệu (nhóm yếu khác) thì nội dung thông báo gợi ý đổi theo.
- **Log:**
  - Ghi khi lập kế hoạch.
  - Mục tương lai bị huỷ thì xoá.
  - Chỉ hiện mục đã tới giờ.
  - Đếm chưa đọc.
  - Đăng xuất thì xoá.
  - Migration 16→17, kể cả từ các bản cũ.
- **Widget:**
  - Huy hiệu chuông.
  - Mục "Đã gửi".
  - Công tắc loại mới.
  - Câu chữ theo nền tảng.
  - 360x640 chữ lớn (x1.5).
- **Chạm mở màn:** test bộ định tuyến payload cho từng loại; test payload sai thì không lỗi.
- **E2E web** (tab mở): bật quyền thông báo trong Chrome chạy ngầm nếu được, ghi một buổi khiến gợi ý đổi, rồi thấy mục trong "Đã gửi". Nếu Chrome chạy ngầm không cấp được quyền, ghi rõ và chỉ kiểm phần màn hình.
