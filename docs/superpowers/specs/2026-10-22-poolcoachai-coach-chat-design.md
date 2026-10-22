# Coach Giai đoạn B — Hỏi huấn luyện viên (chat với Claude) — Thiết kế

Ngày: 2026-10-22. Trạng thái: chờ chủ sản phẩm đọc. Người viết: Claude.

Chủ sản phẩm chọn Coach Giai đoạn B là hạng mục roadmap tiếp theo (2026-10-22) và bỏ phần hỏi đáp thiết kế: mọi lựa chọn không có nguồn bên dưới là **[Claude chọn]**, gom lại ở mục 13 để chủ sản phẩm soát.

## 0. Nguồn và luật đã có

| Nguồn | Điều ràng buộc |
|---|---|
| `tong_hop_y_tuong_app_huan_luyen_bi_a_9ball.md` §3.4, §16, quy ước chung điểm 4 (dòng 337) | Coach Chat thuộc "Giai đoạn tiếp theo". LLM "chỉ diễn giải dữ liệu đã tính và đặt câu hỏi; không bịa số, không tự thay thế đánh giá chuyên môn". "Không khẳng định một cú đánh là tối ưu nếu dữ liệu hình/bàn chưa đủ để kết luận." Hỏi gợi mở trước khi cho đáp án. |
| `PRD_PoolCoachAI.md` §8 (dòng 144–157) | Câu hỏi mẫu: "Hôm nay tôi nên tập gì?", "Tại sao tôi thua trận vừa rồi?", "Tôi đang yếu kỹ năng nào?". Tức là hỏi về dữ liệu của chính người chơi, không hỏi tối ưu từng cú. |
| `docs/superpowers/specs/2026-10-21-poolcoachai-coach-design.md` §12 và `lib/domain/coach/coach_context.dart` | Ranh giới đã cài: `CoachContext` + `toFacts()` (JSON khoá ổn định), `buildCoachContext(...)`, `CoachChatTurn`, `CoachChatReply{text, insufficient}`, `CoachChatBackend.reply(context, history, question)`. Bốn luật: (1) LLM chỉ diễn giải, mọi con số trong câu trả lời phải có trong `toFacts`; (2) gọi LLM qua máy chủ trung gian, khoá API không bao giờ nằm trong app; (3) lọc sau câu trả lời: chặn lời khuyên ngắm theo độ và số không có trong facts, bị chặn thì nói "chưa đủ dữ liệu"; (4) câu hỏi về một tình huống được trả lời bằng `Reveal` của Giai đoạn A. |
| Spec shell 2026-09-17 (dòng 123–153) | Quyết định cũ của chủ sản phẩm: app → máy chủ trung gian → Claude API; LLM chỉ đọc bản tóm tắt JSON có cấu trúc. Máy chủ khi đó định là Supabase Edge Function; backend thật đã chuyển sang Directus trên Easypanel (2026-09-23), nên chỗ đặt đổi, nguyên tắc giữ nguyên. |
| Bộ nhớ dự án: không bịa nội dung; lời khuyên phải làm theo được; thuật ngữ bi-a tiếng Việt | Câu trả lời đến từ AI thật (được phép), nhưng không khuyên "ngắm lệch X°", không đưa tỉ lệ BHE/FHE tự chế, dùng đúng từ của chủ sản phẩm (mục 7.4). |
| Ngày 2026-10-21 | Chủ sản phẩm chọn Claude làm LLM cho Giai đoạn B. |

## 1. Mục đích

Người chơi hỏi bằng lời thường về chính việc tập của mình ("tôi yếu gì", "hôm nay tập gì", "vì sao thua trận vừa rồi") và nhận câu trả lời ngắn, đúng số liệu app đã tính, kèm một câu hỏi gợi mở khi hợp. Giai đoạn A đã có thẻ "Trò chuyện (sắp có)" trên màn Coach; Giai đoạn B lấp chỗ đó.

## 2. Mục tiêu, không làm, thất bại dù chạy được

**Mục tiêu**
- Chat trong tab Coach, chạy như nhau trên web, Android, iOS.
- Câu trả lời tiếng Việt, ngắn, chỉ dựa trên dữ kiện app gửi kèm (`toFacts`), dùng đúng thuật ngữ bi-a của chủ sản phẩm.
- Khoá API Anthropic chỉ nằm trên máy chủ; mỗi người chơi có hạn mức câu hỏi mỗi ngày.

**Không làm (Giai đoạn B)**
- Không phân tích cú đánh hay tình huống bàn bi trong chat (luật 4: đã có `Reveal` của Giai đoạn A, Mô phỏng và Kế hoạch dọn bàn).
- Không gửi ảnh, giọng nói, video; không đồng bộ lịch sử chat giữa các máy; không chat khi chưa đăng nhập.
- Không lưu nội dung chat trên máy chủ.

**Thất bại dù chạy được (anti-goals)**
- Chat nói một con số không có trong dữ liệu của người chơi, hoặc khuyên "ngắm lệch X°", hoặc khẳng định cú nào "tối ưu".
- Chat khuyên tập một nhóm khác với thẻ "Hôm nay" trên Trang chủ mà không nói lý do có trong dữ kiện.
- Khoá API lọt vào app, hoặc ai có app cũng dùng được Claude miễn phí qua máy chủ của ta (máy chủ phải tự giữ lời dặn hệ thống và chỉ nhận dữ liệu có cấu trúc).
- Chữ hiện ra rồi bị rút lại.

## 3. Trải nghiệm người dùng

1. **Thẻ trên màn Coach** (thay thẻ `Vi.coachChatSoonTitle`/`Vi.coachComing`): tiêu đề "Hỏi huấn luyện viên", một dòng "Trả lời dựa trên số liệu tập luyện của bạn", ba câu hỏi mẫu dạng chip (ba câu của PRD §8), nút "Mở trò chuyện". Bấm chip thì mở chat và gửi luôn câu đó.
2. **Màn chat** (route mới `Routes.coachChat = '/coach/chat'`):
   - Thanh tiêu đề "Hỏi huấn luyện viên", nút "Xoá cuộc trò chuyện" (có hộp xác nhận).
   - Danh sách tin: người chơi bên phải, huấn luyện viên bên trái. Khi chưa có tin: ba chip câu hỏi mẫu.
   - Ô nhập (tối đa 500 ký tự) và nút gửi; gửi xong thì khoá ô cho tới khi có trả lời.
   - Trong lúc chờ: bong bóng "Huấn luyện viên đang trả lời…" (không truyền dần chữ, xem 6.3).
   - Trả lời bị bộ lọc chặn: bong bóng mờ "Chưa đủ dữ liệu để trả lời câu này." kèm gợi ý ghi thêm dữ liệu (chuỗi cố định, không do LLM viết).
   - Dưới ô nhập: "Còn N lượt hỏi hôm nay". Hết lượt: khoá ô, hiện "Hết lượt hỏi hôm nay, mai hỏi tiếp."
   - Lỗi mạng hay máy chủ: dòng báo lỗi kèm nút "Thử lại", câu hỏi không mất.
   - Một dòng nhỏ cố định: "Huấn luyện viên AI chỉ diễn giải số liệu của bạn và có thể sai."
   - Tin mới đọc được bằng trình đọc màn hình (live region, như màn tình huống của Giai đoạn A).
3. **Lịch sử** giữ trên máy (Drift), không đồng bộ, tối đa 200 lượt mỗi tài khoản **[Claude chọn]**.
4. **Responsive:** màn chat theo quy tắc của nhánh responsive: thân màn trong `PcReadableWidth`, ô nhập luôn nằm trên bàn phím, không tràn ở 360×640 / 740×360 / chữ ×2. Route mới phải vào bảng `signedInRouteCases` để lượt quét phủ nó.

## 4. Kiến trúc

```
App Flutter (web/Android/iOS)
  └─ CoachChatBackend (lib/data/remote/coach_chat_client.dart)
       POST {facts, history, question} + Bearer <access token Directus>
         ▼
Dịch vụ coach-chat (Node, Easypanel, project test-va)      [Claude chọn: dịch vụ riêng]
  ├─ xác thực: GET {DIRECTUS_URL}/users/me bằng token của người chơi
  ├─ hạn mức: collection Directus `coach_chat_usage` (token dịch vụ)
  └─ Claude Messages API (SDK chính thức @anthropic-ai/sdk), khoá trong biến môi trường
         ▼
App: bộ lọc thuần Dart (lib/domain/coach/chat_filter.dart) → hiện hoặc "chưa đủ dữ liệu"
```

**Vì sao dịch vụ riêng, không phải extension Directus [Claude chọn]:** extension chạy chung tiến trình với Directus (lỗi của nó làm sập cả backend), phải đóng gói SDK thành bundle rồi gắn file vào container (repo chưa có bước build nào như thế). Dịch vụ riêng cô lập khoá và lỗi, theo đúng kiểu nhiều dịch vụ đang có trên Easypanel (`poolcoachai`, `api`, `db`, `mailpit`); cái giá là tự xác thực token qua `/users/me` (một lời gọi, có đệm 60 giây).

**Vì sao bộ lọc nằm trong app [Claude chọn]:** luật lọc là logic không bịa số, phải là hàm Dart thuần có test như bộ test không-bịa-nội-dung của Giai đoạn A; facts cũng do app tính. Máy chủ chỉ chuyển tiếp và giữ lời dặn hệ thống.

## 5. Hợp đồng dữ kiện (`CoachContext.toFacts`)

Giữ nguyên mọi khoá hiện có (`skills`, `rank`, `currentStep`, `coach`, `lastSituation`). Thêm hai khoá, vẫn là hàm thuần trong `lib/domain/coach/` (không import Flutter, luật architecture_test):

- **`today`** — đúng gợi ý của thẻ "Hôm nay" trên Trang chủ (`TodayRecommendation`), để chat không nói ngược với app: `{category: cat.name, reason: reason.name, drillId, drillName, articleTitle, streak, practiceMinutesThisWeek, scheduledToday: [nhãn lịch hôm nay]}`; `null` khi không có gợi ý.
- **`matches`** — từ danh sách trận (`matchesProvider`): `{recent: {played, won, lost} trên tối đa 10 trận đã xong gần nhất, last: {gameType, targetRacks, racksWon, racksLost, won, shots: số cú của chính người chơi theo từng MatchShotType × MatchShotOutcome (khoá là .name), positionOutcomes: đếm theo PositionOutcome}}`; `last` là trận đã xong gần nhất, `null` nếu chưa có. Không gửi tên người chơi hay đối thủ.

`buildCoachContext` nhận thêm `TodayRecommendation?` và `List<PoolMatch>`. Đổi tên khoá là đổi hợp đồng; thêm khoá thì được. Builder kiểm tra thang của `CategoryInsight.mastery` (tỉ lệ 0..1 hay phần trăm) vì bộ lọc ở mục 6 cần biết.

## 6. Bộ lọc câu trả lời (app, `lib/domain/coach/chat_filter.dart`)

`CoachChatReply filterCoachReply(String raw, Map<String, Object?> facts)` — hàm thuần.

6.1 **Chặn** (bất kỳ điều nào khớp → `insufficient: true`, text là chuỗi cố định của mục 3):
- ký tự `°` hoặc số kèm "độ" khi nói về ngắm/góc; các cụm `ngắm lệch`, `ngắm dày hơn`, `ngắm mỏng hơn`, `lệch điểm ngắm` — đúng các mẫu cấm của `coach_no_fabrication_test.dart` (dùng chung danh sách, không chép lại);
- chữ `tối ưu`;
- `BHE`, `FHE` (tỉ lệ áp phê chỉ đến từ mẫu SAWS của Giai đoạn A, không do LLM nói);
- bất kỳ con số nào không thuộc **tập số cho phép**.

6.2 **Tập số cho phép**: mọi giá trị số trong facts (cả số nằm trong chuỗi, ví dụ tên bài "Bài 3", nhãn lịch), cộng dạng phần trăm làm tròn của các trường tỉ lệ (`mastery` nếu là 0..1), cộng các số đếm nhỏ trong câu chữ thông thường **0–10** chỉ khi đi với từ đếm không phải đơn vị đo (ví dụ "2 nhóm", "1 câu hỏi") **[Claude chọn: cho phép đếm nhỏ để câu văn tự nhiên; số đo như %, buổi, phút, lần, ngày, chấm vẫn phải có trong facts]**. Số viết dạng `62%`, `62 %`, `0,62`, `0.62` đều được chuẩn hoá trước khi so.

6.3 **Không truyền dần lên màn hình.** Bộ lọc cần cả câu trả lời; hiện dần rồi rút lại là vi phạm mục 2. Máy chủ vẫn gọi Claude dạng stream (tránh hết thời gian chờ) nhưng trả cả câu một lần.

6.4 Chặn thì không thử lại trong Giai đoạn B **[Claude chọn]**; máy chủ ghi lại số lần bị chặn (mục 7.6) để xem có cần một lượt sửa tự động sau này không.

## 7. Dịch vụ coach-chat (`server/coach-chat/`)

7.1 **Công nghệ [Claude chọn]:** Node 24 LTS, JavaScript ESM (`.mjs`) như các script Node sẵn có của repo, `node:http` và `node:test`; một phụ thuộc duy nhất là SDK chính thức `@anthropic-ai/sdk` (có `package.json` + `package-lock.json`); `Dockerfile` dựa trên `node:24-alpine`. Không TypeScript để khỏi thêm bước build.

7.2 **API**
- `POST /v1/coach-chat` — header `Authorization: Bearer <access token Directus>`; body `{facts: object (≤ 16 KB khi tuần tự hoá), history: [{fromPlayer: bool, text: string ≤ 1000}] (≤ 10 lượt), question: string (1–500 ký tự)}`. Trả `200 {text, model, remainingToday, usage: {input, output, cacheRead}}`; `400` body sai; `401` token sai/hết hạn; `429 {error: "quota", limit, resetAt}`; `502` Claude lỗi hoặc từ chối; `503` Claude quá tải.
- `GET /v1/coach-chat/quota` — `{limit, used, remainingToday, resetAt}` để app hiện "Còn N lượt" trước khi hỏi.
- `GET /healthz` — `200 ok`, không gọi Claude.
- CORS theo `ALLOWED_ORIGINS` (web app và `http://localhost:5555`), trả lời preflight `OPTIONS`.

7.3 **Xác thực và hạn mức**
- Token người chơi kiểm bằng `GET {DIRECTUS_URL}/users/me?fields=id`; kết quả đệm 60 giây theo băm SHA-256 của token **[Claude chọn]**.
- Hạn mức `DAILY_QUESTION_LIMIT` câu mỗi người mỗi ngày (mặc định **30** **[Claude chọn]**), ngày tính theo giờ Việt Nam (UTC+7). Đếm trong collection Directus mới `coach_chat_usage` `{user, day, questions, input_tokens, output_tokens, cache_read_tokens}`, duy nhất theo `(user, day)`. Dịch vụ ghi bằng token tĩnh của một người dùng dịch vụ có quyền **chỉ** trên collection này; người chơi không có quyền gì trên nó (không tự xoá được lượt đã dùng). `deploy/directus/bootstrap.mjs` tạo collection, vai trò, quyền; `verify.mjs` kiểm.
- Đếm trước khi gọi Claude; Claude lỗi thì hoàn lại lượt.

7.4 **Lời dặn hệ thống (system prompt)** — nằm trong dịch vụ, không bao giờ do app gửi. Nội dung tiếng Việt:
- Vai trò: huấn luyện viên bi-a 9 bi của PoolCoachAI, nói với chính người chơi đó.
- Chỉ dùng dữ kiện JSON trong tin nhắn; không tự tính số mới; mọi con số phải có sẵn trong dữ kiện; thiếu dữ kiện thì nói thẳng "chưa đủ dữ liệu" và gợi ý ghi thêm loại dữ liệu nào.
- Không khuyên ngắm theo độ, không "ngắm lệch", không đưa tỉ lệ BHE/FHE, không nói "tối ưu"; câu hỏi về một thế bi cụ thể thì chỉ người chơi tới nút "Xem đáp án" của tình huống hoặc Mô phỏng (luật 4).
- Khi khuyên tập, đi theo `today` trong dữ kiện; nếu khác thì nói lý do có trong dữ kiện.
- Ngắn (tối đa khoảng sáu câu), một câu hỏi gợi mở khi hợp (§3.4); từ chối lịch sự câu hỏi ngoài việc tập bi-a.
- Bảng đối chiếu khoá → chữ: `SkillCategory` (aiming · position · breakShot · safety · kick · bank → Ngắm bi · Điều bi/Vị trí · Phá · Phòng thủ · A băng · Cân bi), `Rank`, `CoachTopic`, `StepKind`/`StepStatus`, `PickReason`, `MatchShotType`/`MatchShotOutcome`/`PositionOutcome`, ý nghĩa `mastery`/`trend`.
- Bảng thuật ngữ của chủ sản phẩm: A băng (kick, không phải bank), Cân bi (bank), Đánh trô bi (draw), Đánh cu lê (follow), Đánh đứng bi (stop), Đánh tâm tiến (stun, khác đứng bi), Phá (break), Điều bi/Vị trí, Chết cái (scratch), Bi ảo, Bi cái, Áp phê (đo bằng "lệch 0,5 / 1 / 2 đầu cơ"), Ném, Bị đui / Phòng thủ bắt đui, Chấm, băng dài trên/dưới, băng ngắn trái/phải, Nhảy bi, Mát xê, Ăn bi, Dựng cơ, Dội băng (chỉ một nghĩa), Kế hoạch dọn bàn, Trơn/Sọc.

7.5 **Gọi Claude**
- Model: biến `CLAUDE_MODEL`, mặc định `claude-opus-5` (mặc định theo hướng dẫn của Anthropic, vì chủ sản phẩm chọn "Claude" chứ chưa chọn model; đổi sang `claude-sonnet-5` là quyết định chi phí của chủ sản phẩm, chỉ cần đổi biến).
- `thinking: {type: "adaptive"}`, `output_config.effort` theo biến `CLAUDE_EFFORT`, mặc định `low` **[Claude chọn: chat diễn giải số đã tính thường không cần nghĩ sâu; đo lại trên câu hỏi thật]**; `max_tokens` 4000.
- Gọi dạng stream rồi lấy `finalMessage()`; bỏ các khối `thinking`, ghép các khối `text`.
- Bật dự phòng phía máy chủ: beta `server-side-fallback-2026-07-01`, `fallbacks: "default"` (theo hướng dẫn cho `claude-opus-5`). Luôn kiểm `stop_reason` trước khi đọc nội dung: `refusal` → `502` mã `refused`; `max_tokens` → `502` mã `truncated`; app hiện cả hai như "chưa đủ dữ liệu".
- Prompt caching: lời dặn hệ thống cố định từng byte, đặt trước; lịch sử chỉ nối thêm; dữ kiện và câu hỏi mới nằm ở tin nhắn người dùng cuối (thứ thay đổi mỗi lượt nằm sau điểm đệm). Dùng `cache_control` tự động; kiểm `usage.cache_read_input_tokens` > 0 ở lượt thứ hai trong test sống. Nếu lời dặn ngắn hơn ngưỡng tối thiểu để đệm của model thì ghi nhận, không độn chữ.
- Lỗi SDK bắt theo thứ tự từ cụ thể tới chung (giới hạn tốc độ → `503`, lỗi trạng thái khác → `502`, lỗi kết nối → `503`).

7.6 **Nhật ký** — mỗi yêu cầu một dòng JSON: thời điểm, băm id người dùng, mã trả về, độ trễ, model, token vào/ra/đệm, `stop_reason`. Không ghi câu hỏi, câu trả lời hay dữ kiện.

7.7 **Biến môi trường**: `PORT` (8080), `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`, `CLAUDE_EFFORT`, `DAILY_QUESTION_LIMIT`, `DIRECTUS_URL`, `DIRECTUS_SERVICE_TOKEN`, `ALLOWED_ORIGINS`. Thiếu biến bắt buộc thì dịch vụ không khởi động.

## 8. Phía app

- **Cấu hình:** `coachChatUrl = String.fromEnvironment('COACH_CHAT_URL', defaultValue: <domain dịch vụ khi deploy>)` trong `lib/core/config.dart`, cạnh `apiBaseUrl`; thêm vào bảng `--dart-define` của `docs/mobile.md`.
- **Lớp dữ liệu:** `RemoteCoachChat implements CoachChatBackend` dùng `package:http` như `DirectusClient`, lấy token qua `AuthRepository.accessToken()` (tự làm mới). Lỗi riêng: `CoachChatQuotaExceeded(resetAt)`, `CoachChatUnavailable`, hết phiên → đường hết phiên sẵn có. Kết quả thô đi qua `filterCoachReply` trước khi tới UI.
- **Provider:** `coachChatBackendProvider`, `coachContextProvider` (gom `playerIntelligenceProvider`, `playerRankProvider`, bước hiện tại của `roadmapProvider`, `coachAttemptsProvider`, `todayRecommendationProvider`, `matchesProvider`), `coachChatQuotaProvider`. Không dùng `.invalidate(`/`.refresh(` (luật architecture_test).
- **Lưu trữ:** bảng Drift mới `coach_chat_turns` `{id, userId, createdAt, fromPlayer, text, insufficient}`, chỉ ở máy, tăng phiên bản schema và viết migration; giữ 200 lượt mới nhất mỗi tài khoản; gửi lên máy chủ 10 lượt cuối.
- **Chuỗi:** mọi chữ mới trong `lib/core/strings/vi.dart` (luật không có chuỗi tiếng Việt trong `lib/features/**`).
- **Màn hình:** `lib/features/coach/presentation/coach_chat_screen.dart` và thẻ mới trên `coach_screen.dart`; route trong `lib/core/router/routes.dart`, có trong `Routes.all`, `all_routes_test.dart` và bảng của lượt quét responsive.

## 9. Bảo mật và riêng tư

- Khoá Anthropic chỉ ở biến môi trường của dịch vụ trên Easypanel; không trong repo, không trong app, không trong nhật ký.
- Máy chủ chỉ nhận dữ liệu có cấu trúc với giới hạn kích thước và tự giữ lời dặn hệ thống, nên app bị sửa cũng không biến máy chủ thành cổng Claude miễn phí; hạn mức giới hạn chi phí mỗi tài khoản.
- Không gửi tên người chơi, tên đối thủ, email; không lưu nội dung chat ở máy chủ.
- Người dùng dịch vụ Directus chỉ có quyền trên `coach_chat_usage`.

## 10. Chi phí (ước tính, cần đo lại)

Mỗi câu hỏi khoảng 2–3 nghìn token vào (phần lời dặn được đệm) và vài trăm token ra (gồm phần nghĩ ở mức `low`). Với `claude-opus-5` ($5 / $25 mỗi triệu token) khoảng **2 xu Mỹ một câu**; với `claude-sonnet-5` ($2 / $10) khoảng **1 xu**. 30 câu/ngày là trần khoảng 0,6 đô một người một ngày với Opus 5. Đây là ước tính trên giấy, chưa đo.

## 11. Kiểm thử

- **Dart, miền:** bộ lọc (từng luật chặn; số cho phép kể cả dạng %, dấu phẩy; số trong chuỗi facts; đếm nhỏ; không chặn nhầm câu hợp lệ), khoá `today`/`matches` tất định, `buildCoachContext` mở rộng. Thêm vào tinh thần của `coach_no_fabrication_test.dart`: mọi câu trả lời hiện ra đều đã qua bộ lọc.
- **Dart, dữ liệu:** `RemoteCoachChat` với `MockClient` theo mẫu `test/support/fake_directus.dart`: header, body, 401, 429, mất mạng, trả lời bị chặn.
- **Widget:** thẻ trên màn Coach, màn chat (gửi, đang trả lời, chặn, hết lượt, lỗi + thử lại, xoá), lượt quét responsive có route mới, `all_routes_test`.
- **Máy chủ (`node --test`):** SDK Anthropic và `fetch` tới Directus được tiêm giả: thiếu/sai token, đệm token, hạn mức (tăng, chạm trần, sang ngày theo UTC+7, hoàn lượt khi Claude lỗi), kiểm tra đầu vào, CORS, lời dặn hệ thống giống hệt từng byte giữa các lượt, ánh xạ `refusal`/`max_tokens`/lỗi SDK. Không test nào gọi Claude thật.
- **Sống (`tool/e2e/coach_chat.mjs`), chỉ chạy khi đặt `COACH_CHAT_LIVE=1`:** người dùng thử → 401 khi không có token → một câu hỏi thật trả tiếng Việt → `cache_read_input_tokens` > 0 ở câu thứ hai → xoá người dùng thử. Tốn tiền thật, nên chỉ chạy khi chủ sản phẩm đồng ý.

## 12. Triển khai

1. **Chủ sản phẩm:** tạo khoá API trên Anthropic Console và đặt hạn mức chi tiêu theo tháng cho workspace đó.
2. Chạy `bootstrap.mjs` để tạo `coach_chat_usage`, người dùng dịch vụ và quyền; lấy token tĩnh của người dùng dịch vụ.
3. Tạo dịch vụ Easypanel `coach-chat` trong project `test-va`, build từ repo (thư mục `server/coach-chat`, `Dockerfile`), đặt các biến ở 7.7, gắn domain.
4. Đặt mặc định `COACH_CHAT_URL` của app theo domain đó; build web bằng `deploy/publish.sh`, build APK.
5. Kiểm sống bằng `tool/e2e/coach_chat.mjs` (có đồng ý của chủ sản phẩm) và bằng ảnh màn chat trên Chrome không giao diện.

Bước 1 và việc đặt khoá vào Easypanel cần chủ sản phẩm; các bước còn lại làm được khi có quyền vào Easypanel.

## 13. Quyết định của Claude (chủ sản phẩm soát)

1. Dịch vụ Node riêng trên Easypanel thay vì extension Directus (mục 4).
2. Bộ lọc nằm trong app, là hàm Dart thuần có test (mục 4, 6).
3. Không truyền dần chữ lên màn hình; hiện cả câu sau khi lọc (6.3).
4. Cho phép số đếm nhỏ 0–10 trong câu văn; số đo phải có trong facts (6.2).
5. Bị chặn thì không tự hỏi lại trong Giai đoạn B (6.4).
6. Node 24 LTS, JavaScript ESM, một phụ thuộc `@anthropic-ai/sdk` (7.1).
7. Hạn mức mặc định 30 câu/người/ngày theo giờ Việt Nam, đếm trong Directus (7.3).
8. Model mặc định `claude-opus-5`, effort `low`, `max_tokens` 4000, dự phòng phía máy chủ bật (7.5).
9. Lịch sử chat chỉ ở máy, 200 lượt, gửi 10 lượt cuối (3, 8).
10. Thêm khoá `today` và `matches` vào facts (mục 5).

**Chủ sản phẩm cần làm hoặc quyết (không chặn việc viết code):** khoá API và hạn mức chi tiêu trên Anthropic Console; giữ `claude-opus-5` hay đổi `claude-sonnet-5`; hạn mức 30 câu/ngày có hợp không.

## 14. Ngoài phạm vi

Đồng bộ lịch sử chat giữa các máy; chat bằng giọng nói hay ảnh; LLM phân tích thế bi; tự động hỏi lại khi bị chặn; thông báo đẩy từ chat; bảng điều khiển chi phí.
