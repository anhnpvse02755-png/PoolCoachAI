# Coach Chat (Hỏi huấn luyện viên) — vận hành và deploy

Sổ tay vận hành cho dịch vụ `server/coach-chat` (chat với Claude trong tab Hỏi
huấn luyện viên) — dành cho chủ sản phẩm, từ lúc chưa deploy lần nào tới việc
đổi model/hạn mức sau này. Thiết kế đầy đủ:
`docs/superpowers/specs/2026-10-22-poolcoachai-coach-chat-design.md`.

**Tình trạng lúc viết bài này:** code đã xong và có test cục bộ (`npm test`
trong `server/coach-chat`, test Dart, hai bài kiểm Chrome Task 12), nhưng
**chưa deploy thật lần nào**. `server/coach-chat/**` chưa đẩy lên `main` (mục
5), service Easypanel chưa tồn tại, `bootstrap.mjs`/`verify.mjs` chưa chạy
phần coach-chat trên Directus thật, và vì vậy job CI `coach-chat / test`
(`.github/workflows/coach-chat.yml`, chạy khi push/PR đổi
`server/coach-chat/**`) cũng chưa chạy lần nào. Làm theo thứ tự các mục dưới.

## 1. Dịch vụ này là gì

`server/coach-chat` là một dịch vụ Node riêng (không phải phần mở rộng
Directus) đứng giữa app và Claude: giữ khoá API, đếm hạn mức câu hỏi mỗi
người mỗi ngày, và chỉ nhận dữ liệu có cấu trúc do app tính sẵn — không bao
giờ tự tính số mới. Bốn endpoint:

- `GET /healthz` → `200` chữ thường `ok`; không gọi Claude, không gọi
  Directus, không cần đăng nhập; **KHÔNG ghi dòng log nào** (ngoại lệ so với
  ba endpoint dưới). Vì vậy `/healthz` trả `ok` KHÔNG chứng minh Directus
  hay token đúng — xem mục 11.
- `GET /v1/coach-chat/quota` → `200 {limit, used, remainingToday, resetAt}`;
  `401` token sai/hết hạn; `503 {error: "unavailable"}` khi Directus không
  trả lời được (mục 11); cần `Authorization: Bearer <token Directus>`.
- `POST /v1/coach-chat` body `{facts, history, question}` → `200 {text,
  model, remainingToday, usage: {input, output, cacheRead}}`; `400` body
  sai; `401` token sai/hết hạn; `413 {error: "invalid", field: "body"}` thân
  yêu cầu vượt quá 64 KB; `429 {error: "quota", limit, resetAt}`;
  `502 {error: "refused"|"truncated"|"upstream"}` Claude từ chối, bị cắt,
  hoặc lỗi khác; `503 {error: "busy"|"unavailable"}` Claude quá tải HOẶC
  Directus không trả lời được — hai nguyên nhân khác hẳn nhau, xem mục 11.
- `POST /v1/coach-chat/blocked` body `{rule}` — app báo một câu trả lời đã
  bị bộ lọc phía app (`chat_filter.dart`) chặn → `204`; `400` rule sai;
  `401` token sai; `413` thân yêu cầu vượt quá 64 KB; `503 {error:
  "unavailable"}` khi Directus không trả lời được.

Mỗi yêu cầu (trừ `/healthz`, xem trên) ghi một dòng log JSON:
`method`/`path`/`status`/`at`/`ms` luôn có; `user` (id người chơi đã băm,
không phải id thật) khi đã xác thực; `error` khi có lỗi — mã đã phân loại
(`busy`/`unavailable`/`refused`/`truncated`/`upstream`/`internal`/…), KHÔNG
BAO GIỜ thông báo lỗi gốc; `model`/`stop` (không phải `stop_reason`) khi đã
gọi Claude; `in`/`out`/`cacheRead` khi có usage. Log KHÔNG chứa câu hỏi, câu
trả lời hay dữ kiện của người chơi — để biết câu nào bị chặn, xem mục 10.

## 2. Biến môi trường

Bảng dưới theo đúng `server/coach-chat/src/config.mjs` (mã thật lúc chạy, có
test), vì mục 7.7 của bản thiết kế không nói rõ biến nào bắt buộc so với có
mặc định. `CLAUDE_FALLBACKS` không nằm trong mục 7.7 của bản thiết kế, nhưng
tới từ plan (R13) và spec issue S4 — mục 7.5/13.8 của bản thiết kế cũng mô tả
hành vi của nó. Bảng dưới gộp cả các nguồn này và là nguồn đúng để đặt biến
trên Easypanel (mục 6).

| Biến | Bắt buộc | Mặc định | Ý nghĩa |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | Có | (không có) | Khoá API Claude, tạo ở mục 3. |
| `DIRECTUS_URL` | Có | (không có) | Địa chỉ Directus (backend chính). |
| `DIRECTUS_SERVICE_TOKEN` | Có | (không có) | Token tĩnh của user dịch vụ coach-chat trên Directus — phải khớp giá trị `COACH_CHAT_SERVICE_TOKEN` đưa cho `bootstrap.mjs` (mục 4). |
| `ALLOWED_ORIGINS` | Có | (không có) | Danh sách origin được phép gọi CORS, phân tách bằng dấu phẩy; rỗng cũng coi là thiếu. |
| `PORT` | Không | `8080` | Cổng HTTP máy chủ lắng nghe (1–65535). |
| `CLAUDE_MODEL` | Không | `claude-opus-5` | Model Claude dùng để trả lời (mục 3, mục 9). |
| `CLAUDE_EFFORT` | Không | `low` | Mức effort: `low`/`medium`/`high`/`xhigh`/`max`. |
| `DAILY_QUESTION_LIMIT` | Không | `30` | Hạn mức câu hỏi mỗi người mỗi ngày, tính theo giờ Việt Nam. |
| `CLAUDE_FALLBACKS` | Không | `default` | `default` (bật dự phòng phía máy chủ) hoặc `off` — dùng `off` khi đổi model mà gặp `502 upstream` (mục 9). |

`PORT`, `CLAUDE_EFFORT`, `CLAUDE_FALLBACKS` và `DAILY_QUESTION_LIMIT` đọc
bằng `env.X ?? mặc_định` trong `config.mjs` — chỉ THIẾU HẲN biến mới dùng
mặc định. Đặt biến đó thành chuỗi rỗng vẫn bị coi là "có đặt", rồi hỏng vì
sai khuôn, và dịch vụ không khởi động được: `main.mjs` in
`Thiếu hoặc sai biến môi trường: …` ra stderr rồi thoát mã 1 — trên
Easypanel, service khởi động lại ngay nên nhìn giống crash-loop. **Để trống
một biến tuỳ chọn thì BỎ HẲN biến đó, ĐỪNG đặt giá trị rỗng.** (`CLAUDE_MODEL`
là ngoại lệ — để rỗng vẫn rơi về mặc định.)

## 3. Việc chủ sản phẩm cần làm, trước khi deploy

Ba việc sau chỉ chủ sản phẩm làm được (cần đăng nhập Anthropic Console); các
mục dưới không chạy được nếu còn thiếu:

1. Tạo một **API key** trên Anthropic Console, trong một **workspace riêng
   cho PoolCoachAI** — tách khỏi workspace chung/cá nhân để dễ xem chi phí và
   dễ khoá riêng nếu lộ.
2. Đặt **hạn mức chi tiêu theo tháng** (spending limit) cho đúng workspace đó
   — **bắt buộc**, không phải tuỳ chọn (spec issue S5). Đăng ký Directus mở
   công khai (mục 4), nên hạn mức 30 câu/ngày trong app chỉ chặn MỖI NGƯỜI,
   không chặn TỔNG chi phí — hạn mức chi tiêu ở đây mới là lớp chặn thật duy
   nhất trên tổng tiền chi mỗi tháng (chi tiết ở mục 12).
3. Quyết giữa `claude-opus-5` (≈ 2 xu Mỹ/câu) và `claude-sonnet-5`
   (≈ 1 xu Mỹ/câu) — mục 12 có ước tính chi phí đầy đủ — và xác nhận hạn mức
   30 câu/người/ngày có hợp không (đổi được sau qua `DAILY_QUESTION_LIMIT`).

## 4. Directus

1. Sinh token dịch vụ:
   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```
2. Đặt giá trị đó vào `COACH_CHAT_SERVICE_TOKEN` trong khối `env` của
   `.claude/settings.local.json` **ở bản checkout chính** (không phải
   worktree). Khối `env` đó cũng là nơi đặt sẵn `DIRECTUS_URL`,
   `DIRECTUS_ADMIN_EMAIL`, `DIRECTUS_ADMIN_PASSWORD` (`bootstrap.mjs` cần cả
   ba) và thêm `MAILPIT_URL`, `MAILPIT_USER`, `MAILPIT_PASSWORD` (`verify.mjs`
   cần cả ba biến này nữa) — mục này chỉ nói TÊN biến và nơi đặt, không nói
   giá trị.
3. **Thứ tự quan trọng:** đặt `COACH_CHAT_SERVICE_TOKEN` TRƯỚC khi chạy
   `bootstrap.mjs`. Thiếu biến này lúc chạy, user dịch vụ
   `coach-chat-service@poolcoachai.example.com` vẫn được tạo nhưng KHÔNG có
   token — `bootstrap.mjs` tự in `NOTE người dùng dịch vụ coach-chat chưa có
   token — chạy lại với COACH_CHAT_SERVICE_TOKEN`, và một kiểm tra của
   `verify.mjs` (không phải kiểm cuối — kiểm user dịch vụ thật phải có role
   `CoachChatService` **và** có token) sẽ hỏng cho tới khi chạy lại
   `bootstrap.mjs` với biến đó đặt đúng.
4. Với sự đồng ý của chủ sản phẩm — hai lệnh này đổi dữ liệu bản thật (biến
   đã có sẵn trong `env` của `.claude/settings.local.json`, không cần gõ lại
   trên dòng lệnh):
   ```bash
   node deploy/directus/bootstrap.mjs
   node deploy/directus/verify.mjs
   ```
   Mong đợi: dòng cuối của `verify.mjs` là `Tất cả kiểm tra đều qua`.
5. **Khớp giá trị:** giá trị `COACH_CHAT_SERVICE_TOKEN` ở bước 4 và giá trị
   biến `DIRECTUS_SERVICE_TOKEN` đặt cho service Easypanel ở mục 6 PHẢI LÀ
   MỘT. Tên biến khác nhau có chủ đích (một bên là lệnh thiết lập Directus,
   một bên là cấu hình máy chủ coach-chat), nhưng giá trị phải khớp, vì
   `bootstrap.mjs` ghi giá trị đó làm `token` tĩnh của chính user Directus mà
   dịch vụ coach-chat dùng để tự giới thiệu.

## 5. Gộp nhánh feat/coach-chat vào main

`server/coach-chat` hiện chỉ có trên nhánh `feat/coach-chat`. Mục 6 (service
Easypanel `coach-chat`) build từ `main` tại đường dẫn `/server/coach-chat`,
nên nhánh phải gộp vào `main` trước — không làm được sau hoặc song song với
mục 6.

1. **Cần chủ sản phẩm đồng ý** — đây là lần đổi `main` của bản thật, không
   lùi lại dễ như một worktree.
2. Gộp `feat/coach-chat` vào `main` theo quy ước hiện tại của repo, đẩy
   `main` lên GitHub thật.
3. Xác nhận `main` đã có `server/coach-chat` (ví dụ `git log --oneline -1
   main -- server/coach-chat` ra một dòng) — mục 6 dựa vào đúng điều này.

## 6. Easypanel — service `coach-chat` trong project `test-va`

1. Tạo app service mới (**cần chủ sản phẩm đồng ý** — tạo hạ tầng thật, lưu
   khoá API thật, gắn domain thật):
   - Nguồn: GitHub `anhnpvse02755-png/PoolCoachAI`, nhánh `main` (đã có
     `server/coach-chat` từ mục 5), đường dẫn build `/server/coach-chat`,
     builder **Dockerfile**.
   - Biến môi trường (bảng đầy đủ ở mục 2): bắt buộc `ANTHROPIC_API_KEY`,
     `DIRECTUS_URL=https://poolcoachai-api.kjdybl.easypanel.host`,
     `DIRECTUS_SERVICE_TOKEN` (= giá trị `COACH_CHAT_SERVICE_TOKEN` ở mục 4),
     `ALLOWED_ORIGINS=https://poolcoachai.kjdybl.easypanel.host,http://localhost:5555`;
     tuỳ chọn `CLAUDE_MODEL`, `CLAUDE_EFFORT`, `DAILY_QUESTION_LIMIT`,
     `CLAUDE_FALLBACKS` — để trống thì bỏ hẳn biến, đừng đặt rỗng (mục 2).
   - Domain: `poolcoachai-coach.kjdybl.easypanel.host` → cổng **8080**.
2. Deploy bằng thủ tục MCP `deployAppService` (qua `execute_destructive` —
   đổi hạ tầng thật, **cần chủ sản phẩm đồng ý**).
3. Kiểm `inspectAppService` → trường `commit.hash` đúng là đầu `main` hiện
   tại (sau mục 5). **Bỏ qua kiểm này từng để production cũ sáu ngày** — luôn
   kiểm trước khi coi là xong.
4. Kiểm: `curl https://poolcoachai-coach.kjdybl.easypanel.host/healthz` →
   `ok`.

Chưa chạy bước nào ở trên tới giờ viết bài này (xem tình trạng ở đầu bài):
nhánh `feat/coach-chat` chưa gộp vào `main` (mục 5), service chưa tồn tại,
`Dockerfile` chưa được Easypanel build lần nào.

## 7. Phát hành app, sau khi merge

Đặt `FLUTTER`/`DART` một lần ở đầu — thay bằng đường dẫn Flutter trên máy
đang chạy; dưới đây là đường dẫn của máy này làm ví dụ, máy thứ hai của chủ
sản phẩm có đường dẫn khác:
```bash
export FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat
export DART=/c/Users/anhnpv/flutter/bin/dart.bat
```

1. **Cần chủ sản phẩm đồng ý** — đẩy nhánh `deploy-easypanel` lên GitHub
   thật (`publish.sh:50`). Từ **bản checkout chính** (không phải worktree):
   ```bash
   FLUTTER="$FLUTTER" DART="$DART" bash deploy/publish.sh
   ```
2. **Cần chủ sản phẩm đồng ý** — deploy bản web thật: thủ tục MCP
   `deployAppService {projectName: test-va, serviceName: poolcoachai}` (qua
   `execute_destructive`). Kiểm `inspectAppService` → trường `commit.hash`
   đúng là đầu nhánh `deploy-easypanel` vừa đẩy ở bước 1 — **bỏ qua kiểm này
   từng để production cũ sáu ngày**.
3. Build APK, cũng từ bản checkout chính, KHÔNG BAO GIỜ từ một worktree:
   ```bash
   JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" "$FLUTTER" build apk --release
   ```

## 8. Kiểm sống, mỗi lần cần chủ sản phẩm đồng ý riêng

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
  chạy (mục 12).
- `DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/coach_chat_ui.mjs https://poolcoachai.kjdybl.easypanel.host`
  — một câu hỏi thật trên Chrome thật, trừ một lượt hạn mức của tài khoản
  thử.
- `DIRECTUS_URL=… DIRECTUS_ADMIN_EMAIL=… DIRECTUS_ADMIN_PASSWORD=… node tool/e2e/responsive.mjs https://poolcoachai.kjdybl.easypanel.host`
  — không gọi Claude, chỉ mở các màn (kể cả `/coach/chat`) ở bốn cỡ màn; vẫn
  tạo và xoá một user thật.

## 9. Đổi model, effort hay hạn mức

Đổi biến môi trường tương ứng trên Easypanel (mục 2) rồi deploy lại
(`deployAppService`) — **cần chủ sản phẩm đồng ý**, vì đây là đổi cấu hình
và khởi động lại dịch vụ thật. Sau đó chạy lại `tool/e2e/coach_chat.mjs`
(mục 8, cần đồng ý riêng cho lượt chạy đó) để chắc vẫn trả lời được. Nếu đổi sang `claude-sonnet-5` mà câu
trả lời là `502 upstream`, đọc log Easypanel để xác nhận đúng mã này (mục 11
— log không có lý do cụ thể hơn `upstream`) rồi đặt `CLAUDE_FALLBACKS=off`: dự
phòng phía máy chủ mặc định bật theo hướng dẫn cho `claude-opus-5`, có thể
không hợp với model khác.

## 10. Log

Mỗi câu trả lời bị bộ lọc phía app chặn được app báo lên máy chủ qua
`POST /v1/coach-chat/blocked`; máy chủ ghi một dòng log `{"event":"blocked", …}`.
Đếm số lần bị chặn: tìm chuỗi `"event":"blocked"` trong log Easypanel của
service `coach-chat`; trường `rule` trong mỗi dòng nói rõ luật nào ở
`lib/domain/coach/chat_filter.dart` đã chặn câu đó.

## 11. Khi có lỗi

- `413 {error: "invalid", field: "body"}`: thân yêu cầu vượt quá 64 KB —
  không phải lỗi hạn mức hay lỗi Claude. App không nên gửi facts/history lớn
  đến vậy; nếu gặp liên tục, xem có gì làm facts hay lịch sử chat phình to
  bất thường không (`lib/domain/coach/coach_context.dart`).
- `503 {error: "busy"}`: Claude đang giới hạn tốc độ hoặc quá tải — thử lại
  sau, không phải lỗi của dịch vụ coach-chat hay của Directus.
- `503 {error: "unavailable"}`: KHÔNG phải Claude quá tải. Directus không
  trả lời được lúc xác thực hoặc lúc đọc/ghi hạn mức, HOẶC máy chủ coach-chat
  không kết nối được tới Claude (lỗi mạng/kết nối, không phải Claude từ chối
  hay quá tải). Che cả trường hợp token dịch vụ sai, sai `DIRECTUS_URL`, hay
  `bootstrap.mjs` chưa chạy — **`/healthz` vẫn trả `ok` trong mọi trường hợp
  này**, vì `/healthz` không gọi Directus (mục 1), nên "healthz ok" KHÔNG
  chứng minh token đúng. Kiểm theo thứ tự:
  - `DIRECTUS_URL` đặt trên service Easypanel đúng chưa (mục 6);
  - `DIRECTUS_SERVICE_TOKEN` trên service Easypanel có khớp
    `COACH_CHAT_SERVICE_TOKEN` đưa cho `bootstrap.mjs` không (mục 4 bước 5);
  - `bootstrap.mjs` đã chạy và `verify.mjs` đã báo "Tất cả kiểm tra đều qua"
    chưa (mục 4);
  - log Easypanel của service có đúng dòng `"error":"unavailable"` ở đúng
    thời điểm lỗi không — log trống hẳn quanh đó thì service có thể đang
    không khởi động được (thiếu/sai biến môi trường, mục 2) chứ không phải
    Directus.
- `502 {error: "refused"}`: Claude từ chối trả lời câu đó.
- `502 {error: "truncated"}`: câu trả lời bị cắt trước khi xong (ví dụ chạm
  trần token).
- `502 {error: "upstream"}`: Claude API lỗi không thuộc hai dạng trên — log
  chỉ ghi đúng `"error":"upstream"`, KHÔNG có lý do cụ thể hơn (không phải
  SDK báo "refused", "truncated" hay một thông báo lỗi riêng — log không giữ
  thông báo đó). Lặp lại nhiều lần thì thử đổi model hay effort (mục 9).
- `401`: vấn đề ở token của người chơi (hết phiên), không phải lỗi hạn mức —
  app đã có đường xử lý hết phiên riêng.
- Hạn mức đặt lại lúc **00:00 giờ Việt Nam** (UTC+7), không phải giờ UTC hay
  giờ máy chủ.

## 12. Chi phí

Ước tính trên giấy (spec mục 10, **chưa đo thật**): mỗi câu hỏi khoảng 2–3
nghìn token vào (phần lời dặn hệ thống được đệm) và vài trăm token ra. Với
`claude-opus-5` ($5 / $25 mỗi triệu token vào/ra) ≈ **2 xu Mỹ/câu**; với
`claude-sonnet-5` ($2 / $10) ≈ **1 xu Mỹ/câu**. Ở trần 30 câu/ngày, Opus 5 ra
khoảng **0,6 đô Mỹ/người/ngày** nếu MỘT người dùng hết hạn mức một ngày.

Số đó là chi phí MỖI NGƯỜI, không phải trần tổng chi phí: đăng ký Directus mở
công khai (`deploy/directus/bootstrap.mjs` đặt `public_registration: true`),
nên không có giới hạn tổng số người dùng, và tổng chi phí mỗi ngày tăng theo
số người thật sự hỏi, không chỉ theo hạn mức mỗi người. **Hạn mức chi tiêu
theo tháng ở mục 3 bước 2 mới là lớp chặn thật trên tổng chi phí** — đặt nó
biết trước mức chấp nhận được, không phải một lớp dự phòng cho trường hợp
"lỡ vượt qua hạn mức 30 câu/ngày" (hạn mức 30 câu/ngày không chặn được ai tạo
thêm tài khoản để hỏi tiếp).

Đo thật bằng hai nguồn:
- Trang usage của Anthropic Console (workspace PoolCoachAI, mục 3).
- Tổng ba cột `input_tokens`/`output_tokens`/`cache_read_tokens` của
  collection Directus `coach_chat_usage` (mỗi dòng là một người một ngày).
