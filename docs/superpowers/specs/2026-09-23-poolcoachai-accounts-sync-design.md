# PoolCoachAI — Thiết kế tài khoản và đồng bộ lịch sử tập

**Ngày:** 23/09/2026
**Trạng thái:** đã duyệt hướng từng phần, chờ duyệt bản viết
**Tiền đề:** Lát dọc Phase 1 đã vào `main`, 212 test xanh. App chạy trên web tại `poolcoachai.kjdybl.easypanel.host` (Easypanel, project `test-va`). Drift trên web đã chạy thật (commit `74ed066`).

---

## 1. Mục tiêu

Người chơi có tài khoản, và lịch sử tập đi theo tài khoản chứ không nằm chết trong một trình duyệt:

> Đăng ký → tập → đăng nhập ở máy khác → thấy lại lịch sử. Quên mật khẩu → nhận email → đặt lại.

Tài khoản sau này phục vụ ba việc: **giữ dữ liệu theo người**, **cổng vào cho người thử**, và **nền cho Coach AI** (server giữ key Claude, giới hạn tần suất theo người). Lượt này làm hai việc đầu. Kiến trúc phải đỡ được việc thứ ba mà không phải làm lại.

### Không thuộc phạm vi

Coach AI · gửi email thật (lượt này dùng mailpit) · xác minh email · đăng nhập bằng Google/Apple · đồng bộ `ScheduleSlotRows` và `TimerSessionRows` (chưa màn nào ghi hai bảng này) · sửa hay xoá buổi tập đã ghi.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Directus tự host** trên `test-va`, **thay cho Supabase** trong PRD | Chủ sản phẩm chọn: nhẹ (một container cộng Postgres), đã quen từ PoolOS, mailpit chạy được ngay. Xem 2.1 |
| 2 | **Bắt buộc đăng nhập** | Mọi buổi tập luôn thuộc một tài khoản, nên chỉ có một luồng dữ liệu. Không có chế độ khách, không có bước gộp dữ liệu khách vào tài khoản |
| 3 | **Tự đăng ký, không xác minh email** | Người thử vào app nhanh nhất. Đánh đổi đã biết: email gõ sai thì quên mật khẩu cũng không cứu được |
| 4 | **Lưu máy trước, đẩy sau** | Wifi quán bi-a yếu. Buổi tập không bao giờ mất vì mất mạng. Màn hình vẫn đọc Drift, kiến trúc stream của Phase 1 giữ nguyên |
| 5 | **Mailpit trước, SMTP thật sau** | Đổi sang mail thật chỉ là đổi 4 biến `EMAIL_SMTP_*`, không sửa code |
| 6 | **Đăng xuất do người bấm thì xoá dữ liệu trên máy, tự động đăng xuất thì không xoá gì** | Chủ sản phẩm chốt. Xem 5.4 |
| 7 | **Cấu hình server nằm trong repo** | PoolOS mất toàn bộ schema khi xoá server, vì schema chỉ nằm trên server. Lần này server mất thì dựng lại được trong một lệnh |

### 2.1 Vì sao đổi Supabase sang Directus, và cái giá

Spec khung (`2026-09-17-poolcoachai-shell-design.md`) và PRD chọn Supabase. Đổi sang Directus thì mất ba thứ Supabase có sẵn:

- **SDK Dart chính thức.** App tự gọi REST bằng package `http`. Phần cần gọi chỉ gồm auth (6 endpoint) và một collection, nên chấp nhận được.
- **Edge Function cho Coach AI.** Tới lượt Coach AI, phần giữ key Claude sẽ là một *endpoint extension* của Directus, viết bằng Node và dùng `@anthropic-ai/sdk`. Ranh giới trong spec khung vẫn giữ nguyên: key không bao giờ nằm trong app, và server kiểm tra phiên đăng nhập trước khi gọi Claude.
- **Row Level Security của Postgres.** Thay bằng *policy* của Directus lọc theo `$CURRENT_USER`. Tầng 3 của kiểm thử (mục 8) kiểm quyền này bằng request thật, không tin vào cấu hình.

Nguyên tắc *"đổi backend chỉ sửa một dòng provider"* trong spec khung vẫn đúng: màn hình chỉ biết `AuthRepository` và `DrillLogRepository`, không biết Directus.

---

## 3. Server

### 3.1 Các service trong `test-va`

| Service | Image | Ghi chú |
|---|---|---|
| `poolcoachai` | nginx (đã có) | Không đổi, trừ việc build lại app |
| `api` | `directus/directus:12.3.1` | Domain `poolcoachai-api.kjdybl.easypanel.host`. Volume cho `uploads`, file mount cho template email |
| `db` | `postgres:17` | Chỉ nhận kết nối trong mạng nội bộ, không mở cổng ra ngoài |
| `mailpit` | `axllent/mailpit:v1.31.1` | **Có basic auth.** Xem 3.4 |

Không dùng Redis: chỉ có một instance Directus, cache trong bộ nhớ là đủ. Giới hạn tài nguyên:

| Service | CPU tối đa | RAM tối đa |
|---|---|---|
| `api` | 0.5 vCPU | 512 MB |
| `db` | 0.5 vCPU | 512 MB |
| `mailpit` | 0.1 vCPU | 64 MB |

VPS có 2 vCPU và 8 GB RAM; lúc thiết kế đang dùng 1.3 GB, tải 0.05. Phần giới hạn là để giữ an toàn cho `cms` và `website`, hai site production của nexthome.com.vn.

**Biến môi trường chính của `api`:**

- `PUBLIC_URL=https://poolcoachai-api.kjdybl.easypanel.host`
- `CORS_ENABLED=true`, `CORS_ORIGIN` = domain app, cộng `http://localhost:5555` cho lúc phát triển (chạy `flutter run -d chrome --web-port 5555`; Directus không nhận ký tự `*` trong origin). `CORS_CREDENTIALS=false`, vì app không dùng cookie.
- `ACCESS_TOKEN_TTL=15m`, `REFRESH_TOKEN_TTL=30d`
- `PASSWORD_RESET_URL_ALLOW_LIST=https://poolcoachai.kjdybl.easypanel.host/reset-password,http://localhost:5555/reset-password`
- `EMAIL_TRANSPORT=smtp`, `EMAIL_SMTP_HOST=test-va_mailpit`, `EMAIL_SMTP_PORT=1025`, `EMAIL_FROM=no-reply@poolcoachai.local`
- `KEY`, `SECRET`, `ADMIN_PASSWORD`, `DB_PASSWORD`: sinh ngẫu nhiên lúc tạo service, **không bao giờ commit**. Xem 3.5.

### 3.2 Dữ liệu: collection `drill_logs`

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `id` | uuid, khoá chính | **App tạo.** Nhờ vậy gửi trùng một buổi không sinh bản ghi đôi |
| `drill_id` | string | Id bài trong seed (`d1`…). Không có khoá ngoại, vì bài tập không nằm trên server |
| `date` | timestamp | Giờ tập, lấy từ `nowProvider` của app |
| `score` | float | |
| `attempts` | integer, nullable | |
| `notes` | text, nullable | |
| `user_created` | Directus tự điền | Chủ của buổi tập. App không gửi trường này, và không thể giả mạo |
| `date_created` | Directus tự điền | |

Bài tập và bài đọc **không lên server**. Chúng vẫn là seed cục bộ, upsert mỗi lần mở app như Phase 1.

### 3.3 Tài khoản và quyền

- Bật **đăng ký công khai** của Directus (`public_registration=true`, `public_registration_verify_email=false`), gán role `Player`.
- Policy của role `Player`:

| Collection | Được làm | Điều kiện |
|---|---|---|
| `drill_logs` | tạo | chỉ các trường ở 3.2, trừ `user_created` |
| `drill_logs` | đọc | `user_created = $CURRENT_USER` |
| `directus_users` | đọc và sửa chính mình | chỉ `first_name`, `email`, `password`. **Không** được sửa `role`, `status`, `policies` |

- Không ai ngoài admin được sửa hay xoá `drill_logs`.
- Không đăng nhập thì không đọc được gì.

### 3.4 Email

- Email đặt lại mật khẩu dùng **template tiếng Việt** `password-reset.liquid`, gắn vào `/directus/templates/` bằng file mount. Nguồn template nằm trong repo.
- **Mailpit phải có basic auth.** Mailpit chứa mọi link đặt lại mật khẩu, nên ai xem được mailpit là chiếm được tài khoản của bất kỳ ai. Mật khẩu basic auth sinh ngẫu nhiên và chỉ đưa cho chủ sản phẩm.
- Chuyển sang mail thật: đổi `EMAIL_SMTP_HOST/PORT/USER/PASSWORD`, rồi xoá service `mailpit`.

### 3.5 Cấu hình dưới dạng code: `deploy/directus/`

| File | Nội dung |
|---|---|
| `schema.yaml` | Snapshot từ `directus schema snapshot`: collection, trường |
| `bootstrap.sh` | Áp schema, tạo role `Player` và policy, bật đăng ký công khai. **Idempotent:** chạy lần hai không lỗi, không tạo trùng. Đọc URL và token admin từ biến môi trường |
| `templates/password-reset.liquid` | Template email tiếng Việt |
| `env.example` | Danh sách biến ở 3.1, **không có giá trị bí mật** |

Giá trị bí mật chỉ nằm trong Easypanel và trong `.claude/settings.local.json` (đã bị git bỏ qua) của máy dev.

---

## 4. App: xác thực

### 4.1 Interface

```dart
abstract interface class AuthRepository {
  Stream<AuthState> watchSession();          // SignedOut | SignedIn(userId, displayName)
  Future<void> register({required String displayName, required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();                    // chỉ khi người chơi bấm, xem 5.4
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({required String token, required String password});
  Future<String> accessToken();              // cho SyncService; tự làm mới khi sắp hết hạn
}
```

Lỗi đi ra dưới dạng một sealed class `AuthFailure`:

- `wrongCredentials`
- `emailTaken`
- `weakPassword`
- `network`
- `resetLinkInvalid`
- `sessionExpired`

Màn hình ánh xạ mỗi loại sang một câu trong `Vi`. **Không bao giờ hiện nguyên văn lỗi của server.**

Bản cài đặt là `DirectusAuthRepository`, nhận `http.Client` qua constructor để test dùng `MockClient`.

### 4.2 Phiên đăng nhập

- Đăng nhập bằng `mode: json`. Refresh token lưu trong bảng Drift `AuthSessionRows`, một dòng duy nhất. Web và mobile lưu cùng một cách.
- Access token chỉ giữ trong bộ nhớ. Còn dưới 1 phút là làm mới trước khi gọi API. Mỗi lần làm mới, server trả refresh token mới và app ghi đè bản cũ.
- **Vì sao không dùng cookie `httpOnly`:** app và API nằm ở hai subdomain của `easypanel.host`. Trình duyệt có thể coi cookie đó là cookie bên thứ ba và chặn, làm vỡ đăng nhập. Đổi lại, refresh token nằm trong IndexedDB và đọc được nếu app có lỗi XSS. Rủi ro thấp: app không hiển thị HTML do người dùng nhập, và Flutter vẽ bằng canvas.

### 4.3 Màn hình và route

| Route | Màn | Ghi chú |
|---|---|---|
| `/login` | Đăng nhập | Email, mật khẩu, link sang Đăng ký và Quên mật khẩu |
| `/register` | Đăng ký | Tên hiển thị, email, mật khẩu (tối thiểu 8 ký tự), nhập lại mật khẩu. Xong là vào app ngay |
| `/forgot-password` | Quên mật khẩu | Luôn báo *"nếu email này có tài khoản, link đã được gửi"*, để không lộ email nào đã đăng ký |
| `/reset-password?token=…` | Đặt lại mật khẩu | Mở từ email. Xong thì về `/login` kèm thông báo |

- Nút **Đăng xuất** đặt ở tab Hồ sơ.
- `redirect` của go_router:
  - Chưa đăng nhập: chỉ vào được 4 route trên, mọi route khác bị đưa về `/login`.
  - Đã đăng nhập: mở `/login` hoặc `/register` thì bị đưa về `/home`.
  - `/reset-password` mở được ở cả hai trạng thái.
- **Đổi sang URL dạng đường dẫn** (`usePathUrlStrategy`). Link trong email có dạng `…/reset-password?token=…`; ở dạng hash, Directus sẽ chèn `?token` vào trước `#`. nginx đã có fallback về `index.html`.

Mọi chữ đi qua `Vi`. Guard kiến trúc sẵn có sẽ bắt nếu màn mới viết chữ tiếng Việt thẳng trong code.

---

## 5. App: đồng bộ lịch sử tập

### 5.1 Drift schema v2

`DrillLogRows` thêm hai cột:

- `userId` (text, bắt buộc): chủ buổi tập.
- `syncedAt` (datetime, nullable): **rỗng nghĩa là chưa lên server.**

Thêm bảng `AuthSessionRows` (4.2).

**Migration v1 → v2:** xoá hết `DrillLogRows` cũ. Chúng không có chủ, và chủ sản phẩm đã chọn bỏ dữ liệu thử.

### 5.2 Id buổi tập

Chuyển từ `microsecond-random24bit` sang **UUID v4** (package `uuid`). Id cũ chỉ đủ duy nhất trên một máy; trên server chung, nó phải duy nhất giữa mọi người dùng.

### 5.3 `SyncService`

**Ghi:** `DrillLogRepository.add()` ghi vào Drift với `userId` là người đang đăng nhập và `syncedAt = null`, rồi báo cho `SyncService`. Màn hình đọc stream Drift nên cập nhật ngay, không chờ mạng.

**Đẩy lên (push):**
1. Lấy các dòng có `syncedAt IS NULL` **và `userId` = người đang đăng nhập**.
2. `POST /items/drill_logs` từng lô.
3. Thành công thì đặt `syncedAt`. Nếu server trả lỗi trùng khoá chính, buổi đó đã lên từ lần trước, nên cũng đặt `syncedAt`.
4. Lỗi mạng thì giữ nguyên để thử lại.

**Kéo về (pull):**
1. `GET /items/drill_logs`. Policy đã lọc sẵn theo người đang đăng nhập.
2. Upsert vào Drift với `syncedAt` = lúc kéo.
3. Trong lượt này, mỗi lần đều kéo toàn bộ. Một người có vài trăm buổi thì vẫn rất nhỏ. Kéo từng phần theo `date_created` để khi cần.

**Khi nào chạy:**
- ngay sau khi đăng nhập (push rồi pull)
- khi mở app
- ngay sau mỗi buổi tập mới
- mỗi 30 giây khi vẫn còn dòng chờ đẩy

**Đọc:** `watchAll()` chỉ trả dòng có `userId` = người đang đăng nhập.

### 5.4 Hai kiểu đăng xuất

| | Người chơi bấm Đăng xuất | Tự động đăng xuất |
|---|---|---|
| Khi nào | Bấm nút ở tab Hồ sơ | **Chỉ khi** server trả 401 lúc làm mới phiên: quá 30 ngày không mở app, đổi mật khẩu, hoặc admin khoá tài khoản |
| Dữ liệu trên máy | Xoá các dòng của người đó | **Không xoá gì**, kể cả dòng chưa đồng bộ |
| Còn dòng chưa đồng bộ | Cảnh báo *"Còn N buổi chưa đồng bộ, đăng xuất sẽ mất"*, cho chọn **Đồng bộ trước** hoặc **Vẫn đăng xuất** | Giữ nguyên; người đó đăng nhập lại thì đẩy tiếp |
| Sau đó | Về `/login` | Về `/login` kèm câu *"Phiên đăng nhập đã hết, hãy đăng nhập lại"* |

- **Mất mạng không bao giờ gây đăng xuất.** Làm mới thất bại vì mạng thì app vẫn dùng bình thường và ghi vào máy.
- **Nhiều người trên một máy:** A bị tự động đăng xuất, rồi B đăng nhập. B không thấy dữ liệu của A, vì `watchAll` lọc theo người. Dòng chưa đồng bộ của A **không bao giờ được gửi bằng token của B**, vì push lọc theo `userId`. Nếu không chặn, dữ liệu của A sẽ thành của B trên server.

---

## 6. Luồng dữ liệu tổng thể

```
Màn hình ──watch──▶ Drift (DrillLogRows lọc theo userId)
    │                  ▲            ▲
    │ add()            │ upsert     │ syncedAt
    ▼                  │            │
DrillLogRepository ──▶ SyncService ──push/pull──▶ Directus /items/drill_logs
                            │
                            └── accessToken() ◀── AuthRepository ◀──▶ Directus /auth/*
                                                      │
                                                      └── AuthSessionRows (refresh token)
```

---

## 7. Triển khai

1. Tạo `db`, `mailpit` (có basic auth) và `api` trên `test-va`, với giới hạn tài nguyên ở 3.1.
2. Chạy `deploy/directus/bootstrap.sh`, **chạy hai lần** để chứng minh idempotent.
3. Build app với `API_URL` truyền qua `--dart-define`, rồi `deploy/publish.sh` và deploy `poolcoachai`.
4. Chạy tầng 4 của kiểm thử (mục 8) trên bản live.

---

## 8. Kiểm thử

**Tầng 1: unit** (`flutter test`, không mạng)

- `DirectusAuthRepository` với `MockClient`: đăng nhập đúng; sai mật khẩu; email trùng; mật khẩu yếu; làm mới thành công (refresh token được ghi đè); làm mới trả 401 thì chuyển sang `SignedOut` kèm `sessionExpired`; làm mới lỗi mạng thì **vẫn `SignedIn`**; link đặt lại hết hạn.
- `SyncService` với Drift in-memory và `MockClient`: push đặt `syncedAt`; server trả trùng khoá thì coi như đã đồng bộ; lỗi mạng giữ dòng ở trạng thái chờ; pull upsert không sinh trùng.
- **Ba test cho các ràng buộc đã chốt:**
  1. Tự động đăng xuất không xoá dòng nào, kể cả dòng chưa đồng bộ.
  2. Khi B đăng nhập, không request nào mang dòng của A.
  3. Người chơi bấm Đăng xuất thì xoá dòng của đúng người đó; còn dòng chưa đồng bộ thì phải cảnh báo trước.
- Migration v1 → v2: DB v1 có sẵn buổi tập, nâng lên v2 thì schema đúng và bảng buổi tập rỗng.

**Tầng 2: widget**

- Bốn màn tài khoản: validate form, hiện đúng câu lỗi cho mỗi `AuthFailure`.
- `redirect`: chưa đăng nhập mở `/training` thì về `/login`; đã đăng nhập mở `/login` thì về `/home`; `/reset-password?token=abc` đưa `abc` vào màn.
- Smoke test mọi route: thêm 4 route mới.

**Tầng 3: server** (curl vào Directus thật)

- Không có token: đọc `drill_logs` bị từ chối.
- User A không đọc được dòng của user B.
- User không sửa được `role` của chính mình.
- User không sửa hay xoá được `drill_logs`.
- `bootstrap.sh` chạy lần hai: không lỗi, không tạo trùng.

**Tầng 4: chạy thật trên bản live bằng hai trình duyệt** (hai profile Chrome headless qua CDP, tương đương hai máy)

1. Máy 1: đăng ký, ghi một buổi tập.
2. Máy 2: đăng nhập cùng tài khoản; buổi tập đó phải hiện ra.
3. Máy 2: bấm Quên mật khẩu. Script đọc mail qua API của mailpit, lấy link, đặt mật khẩu mới.
4. Máy 1: phiên cũ bị từ chối nên tự động đăng xuất; buổi tập **vẫn còn** trong IndexedDB. Đăng nhập bằng mật khẩu mới thì thấy lại đủ.
5. Máy 1: chặn mạng tới API, ghi một buổi, bỏ chặn; trong vòng 30 giây buổi đó phải hiện ở máy 2.

Mỗi bước có ảnh chụp màn hình.

---

## 9. Rủi ro và việc cần kiểm chứng trước

Ba điểm dưới đây là giả định về Directus 12.3.1, **chưa chạy thử**. Kế hoạch thực thi phải kiểm chúng trên server thật **trước** khi viết màn hình, giống cách Phase 1 kiểm Drift trên web đầu tiên.

| Giả định | Nếu sai |
|---|---|
| `/users/register` có trong 12.3.1 và gán được role qua `public_registration_role` | Dùng một endpoint extension nhỏ để tạo user với role `Player` |
| Đặt lại mật khẩu làm các refresh token cũ mất hiệu lực (bước 4 của tầng 4 dựa vào điều này) | Trong hook đổi mật khẩu, xoá phiên cũ trong `directus_sessions`. Đổi mật khẩu mà phiên cũ vẫn sống là lỗ hổng, không phải chi tiết nhỏ |
| `reset_url` dạng đường dẫn nhận `?token=` đúng chỗ và khớp `PASSWORD_RESET_URL_ALLOW_LIST` | Chỉnh lại allow list hoặc cách app đọc token; không quay lại dạng hash |

Rủi ro khác:

- **Directus cập nhật phá API.** Ghim `12.3.1`; nâng cấp là một việc riêng, có chạy lại tầng 3.
- **Người dùng gõ sai email khi đăng ký** thì không lấy lại được tài khoản. Chấp nhận trong lượt này (quyết định 3). Lượt gửi mail thật nên cân nhắc bật xác minh email.

---

## 10. Xong là khi

- Tầng 1–3 xanh; `flutter analyze` không lỗi; guard kiến trúc xanh.
- Tầng 4 chạy hết 5 bước trên bản live, có ảnh chụp.
- `bootstrap.sh` dựng lại được toàn bộ cấu hình Directus từ một server trống.
- Chủ sản phẩm có mật khẩu mailpit và mật khẩu admin Directus, nhận qua kênh riêng chứ không qua commit.
