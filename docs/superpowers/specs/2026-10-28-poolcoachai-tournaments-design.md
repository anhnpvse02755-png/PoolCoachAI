# PoolCoachAI — Giải đấu

**Ngày:** 28/10/2026. **Tiền đề:** `main` 41d15b6 (Skill Test, Drift v15).
**Quyết định:** chủ dự án giao toàn quyền ("bạn tự quyết đi"). Mọi lựa chọn dưới đây là **quyết định của Claude**, kèm lý do để chủ dự án sửa khi cần.

## 1. Mục đích

- PRD :136-148 liệt kê "Competition / Tournament" trong Play và ghi "Còn thiếu: … giải đấu".
- Ý tưởng :212-213: "Đây là nơi ghi nhận trận đấu thực tế, khác hoàn toàn với Drill Session."
- Lộ trình đã có mục tiêu `chuanBiGiai`, nhưng chỉ lưu một ngày, không biết là giải nào.
- Spec phân tích trận :202: "Giải đấu: dự án 4 riêng."

Không tài liệu nào nói tới nhánh đấu, vòng bảng hay chấp. Tài liệu chủ dự án (Tong-Hop, Tu-Dien) không nhắc giải đấu.

## 2. Phạm vi: nhật ký giải cá nhân

Đây là quyết định của Claude.

- **Mỗi người chơi ghi các giải mình tham gia**, và gắn các trận đã ghi trong Play vào giải đó.
- **Không** làm công cụ tổ chức giải: không chia nhánh, không bốc thăm, không bảng chung cho nhiều người.

Lý do:
1. Không có yêu cầu nào về thể thức nhánh đấu.
2. Directus hiện chỉ cho mỗi người đọc dữ liệu của chính mình. Giải nhiều người cần một mô hình quyền mới, rủi ro cao mà chưa ai yêu cầu.
3. Nhật ký cá nhân dùng ngay được dữ liệu trận và phân tích trận đã có, và nối được với mục tiêu "Chuẩn bị giải".

## 3. Nguyên tắc

- **Không bịa.** Kết quả giải ("Thành tích") là chữ người chơi tự ghi, hiển thị nguyên văn. Mọi con số là tính từ trận đã ghi. Thiếu mẫu thì nói thẳng, dùng đúng ngưỡng của phân tích trận (`minMatches` = 3).
- **Dữ liệu tự ghi.** Ý tưởng :391 yêu cầu phân biệt dữ liệu tự ghi với dữ liệu xác minh. Màn giải ghi rõ "Kết quả do bạn ghi".
- **Không đổi hạng.** Giải không tạo hạng, không đổi hạng.
- **Domain thuần.** Logic giải nằm ở `lib/domain/tournament/`: không Flutter, không tiếng Việt. Câu chữ nằm trong `vi.dart`.

## 4. Dữ liệu

### 4.1 Giải (`tournament_rows`, Drift v16)

| Cột | Ghi chú |
|---|---|
| `id` (uuid), `user_id` | |
| `name` | bắt buộc, cắt khoảng trắng, 1–80 ký tự |
| `start_date` | bắt buộc (chỉ ngày). Được phép ở quá khứ để ghi lại giải cũ |
| `end_date?` | nếu có thì ≥ `start_date` |
| `location?` | chữ tự do, ≤ 120 ký tự |
| `game_type?` | `PoolGameType` (8/9/10 bi); gợi ý mặc định khi bắt đầu trận trong giải |
| `result_note?` | "Thành tích", chữ tự do ≤ 120 ký tự, ví dụ "Vào vòng 16" |
| `notes?` | |
| `created_at`, `updated_at`, `synced_at?`, `is_deleted` | xóa mềm, đồng bộ theo `updated_at` mới hơn thắng (giống `pool_matches`) |

**Trạng thái** được tính, không lưu (đều tính theo ngày địa phương):
- `sapToi`: hôm nay < `start_date`.
- `dangDienRa`: `start_date` ≤ hôm nay ≤ `end_date ?? start_date`.
- `daXong`: còn lại.

### 4.2 Trận thuộc giải

Thêm vào `pool_match_rows` (v16), cả hai đều có thể rỗng:
- `tournament_id?`
- `round_label?`: chữ tự do ≤ 40 ký tự. Có chip gợi ý "Vòng loại", "Vòng bảng", "Tứ kết", "Bán kết", "Chung kết".

Trận không gắn giải giữ nguyên như cũ.

Nếu giải đã bị xóa (mềm), các trận của nó **giữ `tournament_id`**, nhưng hiển thị như trận thường. Lý do: không mất dữ liệu trận, và không phải sửa hàng loạt trận khi xóa.

### 4.3 Mục tiêu nối với giải

Thêm `player_goal_rows.tournament_id?` (v16).

Liên kết chỉ được dùng khi **cả ba** điều kiện đúng:
1. Mục tiêu là `chuanBiGiai`.
2. Giải còn (chưa xóa).
3. `eventDate` của mục tiêu trùng `start_date` của giải.

Sai bất kỳ điều kiện nào thì bỏ qua liên kết và hiển thị như hiện nay. Lý do: bản app cũ sửa mục tiêu sẽ không gửi `tournament_id`, nên liên kết cũ có thể còn sót trên server. Điều kiện trùng ngày giúp không bao giờ hiện sai tên giải.

### 4.4 Directus

- Collection mới `tournaments`, theo quyền của Player:
  - tạo, đọc và sửa dòng của chính mình;
  - không có quyền xóa (chỉ xóa mềm).
- `pool_matches` thêm `tournament_id` và `round_label`, đều có thể rỗng. Thêm cả hai vào danh sách trường được tạo/sửa.
- `player_goals` thêm `tournament_id`, có thể rỗng. Thêm vào danh sách trường được tạo/sửa.
- `verify.mjs` kiểm tra:
  - A tạo được giải;
  - B không đọc, không sửa được giải của A;
  - A xóa mềm được;
  - không xóa hẳn được;
  - trận mang `tournament_id` đọc lại đúng.
- Chạy bootstrap và verify trên prod **trước** khi publish web.

**Tương thích bản cũ:** bản cũ kéo `pool_matches` và `player_goals` sẽ gặp trường lạ. Plan phải có test chứng minh bộ chuyển đổi bỏ qua trường lạ. Khi bản cũ sửa một trận, nó gửi PATCH không có `tournament_id`, nên liên kết trên server được giữ.

### 4.5 Đăng xuất

Đăng xuất xóa `tournament_rows` cùng các bảng khác. Giải chưa đồng bộ được tính vào cảnh báo "dữ liệu chưa đồng bộ".

## 5. Luồng người chơi

1. **Play** có thẻ **"Giải đấu"** ở đầu màn hình.
   - Thẻ hiện giải đang diễn ra; nếu không có thì giải sắp tới gần nhất; nếu không có nữa thì "Chưa có giải nào".
   - Bấm vào thẻ mở danh sách giải `/play/tournaments`.
2. **Danh sách giải** `/play/tournaments`:
   - Chia ba nhóm: Đang diễn ra, Sắp tới, Đã xong. Giải sắp tới xếp theo ngày gần nhất trước, giải đã xong theo ngày mới nhất trước.
   - Mỗi giải hiện tên, ngày, địa điểm, số trận thắng/thua và thành tích.
   - Nút **"Thêm giải"** mở form gồm tên, ngày bắt đầu, ngày kết thúc, địa điểm, loại bi, thành tích và ghi chú.
   - Đầu danh sách là dòng **"Ở giải và trận thường"**, so tỷ lệ ván thắng trong trận thuộc giải với trận thường.
     - Chỉ hiện khi **mỗi bên** có ≥ 3 trận hoàn tất.
     - Nếu chưa đủ: "Cần ít nhất 3 trận hoàn tất ở mỗi bên để so sánh".
3. **Chi tiết giải** `/play/tournaments/:id`:
   - **Thông tin:** tên, ngày, địa điểm, loại bi, trạng thái, thành tích kèm nhãn "Kết quả do bạn ghi", ghi chú. Có nút sửa và xóa; xóa phải xác nhận.
   - **Tổng kết** (tính từ trận): số trận thắng–thua, số ván thắng–thua, tỷ lệ ván thắng.
   - **Các trận:** xếp theo `startedAt`. Mỗi trận hiện vòng, đối thủ, tỷ số và thắng/thua. Bấm vào trận mở phân tích trận hiện có.
   - **Phân tích:** dùng nguyên lõi `match_analysis` trên các trận của giải. Ngưỡng mẫu giữ nguyên, thiếu mẫu thì nói thẳng.
   - **"Bắt đầu trận trong giải"** (khi `start_date` ≤ hôm nay): mở form bắt đầu trận với giải đã chọn sẵn và loại bi điền sẵn từ giải.
   - **"Chuẩn bị cho giải này"** (khi giải còn `sapToi`): đặt mục tiêu `chuanBiGiai` với `eventDate = start_date` và `tournament_id`.
     - Nếu đã có mục tiêu khác, hỏi xác nhận thay, giống bộ chọn mục tiêu hiện có.
     - Nếu mục tiêu hiện tại đã nối với chính giải này: hiện "Đang chuẩn bị cho giải này" và nút mở Lộ trình.
4. **Form bắt đầu trận / sửa trận** (Play) thêm hai trường tùy chọn:
   - **"Giải đấu"** là danh sách chọn.
     - Khi bắt đầu trận, danh sách gồm các giải chưa xóa có `start_date` ≤ hôm nay và kết thúc trong 7 ngày gần đây, tức `(end_date ?? start_date)` ≥ hôm nay − 7.
     - Khi sửa trận, danh sách gồm mọi giải chưa xóa.
     - Có lựa chọn "Không thuộc giải nào".
   - **"Vòng"** dùng chữ tự do kèm chip gợi ý; chỉ hiện khi đã chọn giải.
5. **Thẻ trận** trong Play có thêm nhãn nhỏ `{tên giải} · {vòng}` khi trận thuộc một giải còn tồn tại.
6. **Lộ trình**: khi mục tiêu nối hợp lệ với một giải (§4.3), tiêu đề đổi từ "Chuẩn bị giải ngày …" thành "Chuẩn bị giải {tên} — ngày …". Logic bước (`dauTap`, `khongKip`) không đổi.

## 6. Ngoài phạm vi

- Tổ chức giải: nhánh đấu, vòng bảng, bốc thăm, giải nhiều người, bảng xếp hạng.
- Chấp, tức race lệch (ví dụ 7 chọi 5). `PoolMatch` vẫn chỉ có một `targetRacks`.
- Danh tính đối thủ; đối thủ vẫn là chữ tự do.
- Fact giải đấu cho Coach Chat. Dịch vụ chat chưa được deploy, và thêm khóa fact cần sửa prompt hệ thống.
- Thông báo nhắc giải (dự án 6).

## 7. Kiểm thử

- **Domain:**
  - Trạng thái giải ở các mốc biên: hôm nay = ngày bắt đầu, = ngày kết thúc, không có ngày kết thúc.
  - Kiểm tra dữ liệu nhập: tên, độ dài, ngày kết thúc trước ngày bắt đầu.
  - Danh sách giải chọn được khi bắt đầu trận (biên 7 ngày).
  - Tổng kết trận/ván.
  - So sánh giải với trận thường, kể cả ngưỡng 3 trận mỗi bên.
  - Điều kiện liên kết mục tiêu: trùng ngày, giải bị xóa, sai kind.
  - Giải bị xóa thì trận hiện như trận thường.
- **Chống bịa:** đổi dữ liệu thì tổng kết, dòng so sánh, thẻ Play và tiêu đề Lộ trình đổi theo.
- **Kiến trúc:** `lib/domain/tournament/` không import Flutter, không có tiếng Việt.
- **Repository / migration:**
  - Nâng 15→16, cả từ các bản cũ hơn.
  - Dựng mới ở v16.
  - Xóa mềm.
  - Đồng bộ đẩy/kéo `tournaments` theo `updated_at`.
  - Bộ chuyển đổi bản cũ bỏ qua trường lạ.
- **Widget:**
  - Thẻ Play; danh sách, form, chi tiết giải.
  - Chọn giải trong form trận.
  - Nút chuẩn bị giải.
  - 360x640 chữ lớn (app giới hạn cỡ chữ ở 1.5).
  - Route mới có trong `Routes.all`.
- **E2E live** `tool/e2e/tournament.mjs`: tài khoản tạm thêm giải → bắt đầu trận trong giải → ghi đủ ván → thấy tổng kết → đặt mục tiêu chuẩn bị (với một giải sắp tới) → kiểm tra các dòng trên Directus → dọn dữ liệu.
