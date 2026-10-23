# Coach Chat (Hỏi huấn luyện viên) — vận hành và deploy

Sổ tay vận hành cho dịch vụ `server/coach-chat` (chat với Claude trong tab Hỏi
huấn luyện viên) — dành cho chủ sản phẩm, từ lúc chưa deploy lần nào tới việc
đổi model/hạn mức sau này. Thiết kế đầy đủ:
`docs/superpowers/specs/2026-10-22-poolcoachai-coach-chat-design.md`.

**Tình trạng lúc viết bài này:** code đã xong và có test cục bộ (`npm test`
trong `server/coach-chat`, test Dart, hai bài kiểm Chrome Task 12), nhưng
**chưa deploy thật lần nào**. `server/coach-chat/**` chưa đẩy lên `main`,
service Easypanel chưa tồn tại, `bootstrap.mjs`/`verify.mjs` chưa chạy phần
coach-chat trên Directus thật, và vì vậy job CI `coach-chat / test`
(`.github/workflows/coach-chat.yml`, chạy khi push/PR đổi
`server/coach-chat/**`) cũng chưa chạy lần nào. Làm theo thứ tự các mục dưới.

## 1. Dịch vụ này là gì

`server/coach-chat` là một dịch vụ Node riêng (không phải phần mở rộng
Directus) đứng giữa app và Claude: giữ khoá API, đếm hạn mức câu hỏi mỗi
người mỗi ngày, và chỉ nhận dữ liệu có cấu trúc do app tính sẵn — không bao
giờ tự tính số mới. Bốn endpoint:

- `GET /healthz` → `200` chữ thường `ok`; không gọi Claude, không cần đăng nhập.
- `GET /v1/coach-chat/quota` → `200 {limit, used, remainingToday, resetAt}`; cần `Authorization: Bearer <token Directus>`.
- `POST /v1/coach-chat` body `{facts, history, question}` → `200 {text, model, remainingToday, usage: {input, output, cacheRead}}`; `400` body sai; `401` token sai/hết hạn; `429 {error: "quota", limit, resetAt}`; `502` Claude từ chối hoặc lỗi; `503` Claude quá tải.
- `POST /v1/coach-chat/blocked` body `{rule}` — app báo một câu trả lời đã bị bộ lọc phía app (`chat_filter.dart`) chặn → `204`.

Mỗi yêu cầu ghi một dòng log JSON: thời điểm, băm id người dùng (không phải id
thật), mã trả về, độ trễ, model, token vào/ra/đệm, `stop_reason`. Log KHÔNG
chứa câu hỏi, câu trả lời hay dữ kiện của người chơi — để biết câu nào bị
chặn, xem mục 9.

## 2. Biến môi trường

Bảng dưới theo đúng `server/coach-chat/src/config.mjs` (mã thật lúc chạy, có
test), vì mục 7.7 của bản thiết kế không nói rõ biến nào bắt buộc so với có
mặc định, và **bỏ sót `CLAUDE_FALLBACKS`** khỏi danh sách dù mục 7.5/13.8 của
chính bản thiết kế đó vẫn mô tả hành vi của nó. Khác biệt này đã báo lại cho
chủ sản phẩm; bảng này là nguồn đúng để đặt biến trên Easypanel (mục 5).

| Biến | Bắt buộc | Mặc định | Ý nghĩa |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | Có | (không có) | Khoá API Claude, tạo ở mục 3. |
| `DIRECTUS_URL` | Có | (không có) | Địa chỉ Directus (backend chính). |
| `DIRECTUS_SERVICE_TOKEN` | Có | (không có) | Token tĩnh của user dịch vụ coach-chat trên Directus — phải khớp giá trị `COACH_CHAT_SERVICE_TOKEN` đưa cho `bootstrap.mjs` (mục 4). |
| `ALLOWED_ORIGINS` | Có | (không có) | Danh sách origin được phép gọi CORS, phân tách bằng dấu phẩy; rỗng cũng coi là thiếu. |
| `PORT` | Không | `8080` | Cổng HTTP máy chủ lắng nghe (1–65535). |
| `CLAUDE_MODEL` | Không | `claude-opus-5` | Model Claude dùng để trả lời (mục 3, mục 8). |
| `CLAUDE_EFFORT` | Không | `low` | Mức effort: `low`/`medium`/`high`/`xhigh`/`max`. |
| `DAILY_QUESTION_LIMIT` | Không | `30` | Hạn mức câu hỏi mỗi người mỗi ngày, tính theo giờ Việt Nam. |
| `CLAUDE_FALLBACKS` | Không | `default` | `default` (bật dự phòng phía máy chủ) hoặc `off` — dùng `off` khi đổi model mà gặp `502 upstream` (mục 8). |

## 3. Việc chủ sản phẩm cần làm, trước khi deploy

Ba việc sau chỉ chủ sản phẩm làm được (cần đăng nhập Anthropic Console); các
mục dưới không chạy được nếu còn thiếu:

1. Tạo một **API key** trên Anthropic Console, trong một **workspace riêng
   cho PoolCoachAI** — tách khỏi workspace chung/cá nhân để dễ xem chi phí và
   dễ khoá riêng nếu lộ.
2. Đặt **hạn mức chi tiêu theo tháng** (spending limit) cho đúng workspace đó
   — **bắt buộc**, không phải tuỳ chọn (spec issue S5): đây là lớp chặn cuối
   nếu hạn mức 30 câu/ngày trong app bị vượt qua bằng cách nào đó.
3. Quyết giữa `claude-opus-5` (≈ 2 xu Mỹ/câu) và `claude-sonnet-5`
   (≈ 1 xu Mỹ/câu) — mục 11 có ước tính chi phí đầy đủ — và xác nhận hạn mức
   30 câu/người/ngày có hợp không (đổi được sau qua `DAILY_QUESTION_LIMIT`).

## 4. Directus

1. Sinh token dịch vụ:
   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```
2. Đặt giá trị đó vào `COACH_CHAT_SERVICE_TOKEN` trong khối `env` của
   `.claude/settings.local.json` **ở bản checkout chính** (không phải
   worktree).
3. **Thứ tự quan trọng:** đặt `COACH_CHAT_SERVICE_TOKEN` TRƯỚC khi chạy
   `bootstrap.mjs`. Thiếu biến này lúc chạy, user dịch vụ
   `coach-chat-service@poolcoachai.example.com` vẫn được tạo nhưng KHÔNG có
   token — `bootstrap.mjs` tự in `NOTE người dùng dịch vụ coach-chat chưa có
   token — chạy lại với COACH_CHAT_SERVICE_TOKEN`, và kiểm tra cuối của
   `verify.mjs` (user dịch vụ thật phải có role `CoachChatService` **và** có
   token) sẽ hỏng cho tới khi chạy lại `bootstrap.mjs` với biến đó đặt đúng.
4. Với sự đồng ý của chủ sản phẩm — hai lệnh này đổi dữ liệu bản thật:
   ```bash
   COACH_CHAT_SERVICE_TOKEN=… node deploy/directus/bootstrap.mjs
   node deploy/directus/verify.mjs
   ```
   Mong đợi: dòng cuối của `verify.mjs` là `Tất cả kiểm tra đều qua`.
5. **Khớp giá trị:** giá trị `COACH_CHAT_SERVICE_TOKEN` ở bước 4 và giá trị
   biến `DIRECTUS_SERVICE_TOKEN` đặt cho service Easypanel ở mục 5 PHẢI LÀ
   MỘT. Tên biến khác nhau có chủ đích (một bên là lệnh thiết lập Directus,
   một bên là cấu hình máy chủ coach-chat), nhưng giá trị phải khớp, vì
   `bootstrap.mjs` ghi giá trị đó làm `token` tĩnh của chính user Directus mà
   dịch vụ coach-chat dùng để tự giới thiệu.

## 5. Easypanel — service `coach-chat` trong project `test-va`

1. Tạo app service mới:
   - Nguồn: GitHub `anhnpvse02755-png/PoolCoachAI`, nhánh `main`, đường dẫn
     build `/server/coach-chat`, builder **Dockerfile**.
   - Biến môi trường (bảng đầy đủ ở mục 2): bắt buộc `ANTHROPIC_API_KEY`,
     `DIRECTUS_URL=https://poolcoachai-api.kjdybl.easypanel.host`,
     `DIRECTUS_SERVICE_TOKEN` (= giá trị `COACH_CHAT_SERVICE_TOKEN` ở mục 4),
     `ALLOWED_ORIGINS=https://poolcoachai.kjdybl.easypanel.host,http://localhost:5555`;
     tuỳ chọn `CLAUDE_MODEL`, `CLAUDE_EFFORT`, `DAILY_QUESTION_LIMIT`,
     `CLAUDE_FALLBACKS`.
   - Domain: `poolcoachai-coach.kjdybl.easypanel.host` → cổng **8080**.
2. Deploy bằng thủ tục MCP `deployAppService` (qua `execute_destructive` —
   đổi hạ tầng thật, cần chủ sản phẩm đồng ý).
3. Kiểm `inspectAppService` → trường `commit.hash` đúng là đầu `main` hiện
   tại.
4. Kiểm: `curl https://poolcoachai-coach.kjdybl.easypanel.host/healthz` →
   `ok`.

Chưa chạy bước nào ở trên tới giờ viết bài này (xem tình trạng ở đầu bài):
service chưa tồn tại, `Dockerfile` chưa được Easypanel build lần nào.

## 6. Phát hành app, sau khi merge

1. Từ **bản checkout chính** (không phải worktree):
   ```bash
   FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat DART=/c/Users/anhnpv/flutter/bin/dart.bat bash deploy/publish.sh
   ```
2. Deploy bản web vừa đẩy: thủ tục MCP
   `deployAppService {projectName: test-va, serviceName: poolcoachai}`.
3. Build APK, cũng từ bản checkout chính, KHÔNG BAO GIỜ từ một worktree:
   ```bash
   JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" "$FLUTTER" build apk --release
   ```

## 7. Kiểm sống, mỗi lần cần chủ sản phẩm đồng ý riêng

Ba bài sau đều tạo một user thật trên Directus bản thật rồi xoá lại (CASCADE
xoá luôn dòng hạn mức của user đó), và không có mặc định cho địa chỉ — không
bao giờ lỡ chạy nhầm vào bản thật. Hỏi chủ sản phẩm TRƯỚC MỖI LẦN chạy, không
chỉ lần đầu — mỗi bài tốn (hoặc không tốn) khác nhau:

- ```bash
  COACH_CHAT_LIVE=1 COACH_CHAT_URL=… DIRECTUS_URL=… \
    DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… \
    node tool/e2e/coach_chat.mjs
  ```
  Gọi Claude thật **hai lần** (hai câu hỏi) — khoảng **4 xu Mỹ** một lần
  chạy (mục 11).
- `DIRECTUS_URL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/coach_chat_ui.mjs https://poolcoachai.kjdybl.easypanel.host`
  — một câu hỏi thật trên Chrome thật, trừ một lượt hạn mức của tài khoản
  thử.
- `DIRECTUS_URL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/responsive.mjs https://poolcoachai.kjdybl.easypanel.host`
  — không gọi Claude, chỉ mở các màn (kể cả `/coach/chat`) ở bốn cỡ màn; vẫn
  tạo và xoá một user thật.

## 8. Đổi model, effort hay hạn mức

Đổi biến môi trường tương ứng trên Easypanel (mục 2), deploy lại
(`deployAppService`), rồi chạy lại `tool/e2e/coach_chat.mjs` (mục 7, cần
đồng ý riêng) để chắc vẫn trả lời được. Nếu đổi sang `claude-sonnet-5` mà câu
trả lời là `502 upstream` (đọc log, mục 9, để thấy mã lỗi cụ thể), đặt
`CLAUDE_FALLBACKS=off` — dự phòng phía máy chủ mặc định bật theo hướng dẫn
cho `claude-opus-5`, có thể không hợp với model khác.

## 9. Log

Mỗi câu trả lời bị bộ lọc phía app chặn được app báo lên máy chủ qua
`POST /v1/coach-chat/blocked`; máy chủ ghi một dòng log `{"event":"blocked", …}`.
Đếm số lần bị chặn: tìm chuỗi `"event":"blocked"` trong log Easypanel của
service `coach-chat`; trường `rule` trong mỗi dòng nói rõ luật nào ở
`lib/domain/coach/chat_filter.dart` đã chặn câu đó.

## 10. Khi có lỗi

- `503 {error: "busy"}` hoặc tương tự: Claude đang giới hạn tốc độ hoặc quá
  tải — thử lại sau, không phải lỗi của dịch vụ coach-chat.
- `502 {error: "upstream"}` hoặc mã khác: đọc log Easypanel của service để
  thấy lý do cụ thể (`refused`, `truncated`, lỗi SDK…).
- `401`: vấn đề ở token của người chơi (hết phiên), không phải lỗi hạn mức —
  app đã có đường xử lý hết phiên riêng.
- Hạn mức đặt lại lúc **00:00 giờ Việt Nam** (UTC+7), không phải giờ UTC hay
  giờ máy chủ.

## 11. Chi phí

Ước tính trên giấy (spec mục 10, **chưa đo thật**): mỗi câu hỏi khoảng 2–3
nghìn token vào (phần lời dặn hệ thống được đệm) và vài trăm token ra. Với
`claude-opus-5` ($5 / $25 mỗi triệu token vào/ra) ≈ **2 xu Mỹ/câu**; với
`claude-sonnet-5` ($2 / $10) ≈ **1 xu Mỹ/câu**. Ở trần 30 câu/ngày, Opus 5 ra
khoảng **0,6 đô Mỹ/người/ngày** nếu dùng hết hạn mức.

Đo thật bằng hai nguồn:
- Trang usage của Anthropic Console (workspace PoolCoachAI, mục 3).
- Tổng ba cột `input_tokens`/`output_tokens`/`cache_read_tokens` của
  collection Directus `coach_chat_usage` (mỗi dòng là một người một ngày).
