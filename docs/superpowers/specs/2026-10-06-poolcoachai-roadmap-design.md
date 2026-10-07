# PoolCoachAI — Thiết kế Lộ trình (mục tiêu + khảo sát + thích ứng)

Ngày: 2026-10-06
Trạng thái: đã duyệt hướng, chờ duyệt bản viết (chưa thành kế hoạch triển khai). **Phải viết lại sau khi có dự án con Đánh giá + hạng** (xem mục "Đối chiếu với mã" ngay dưới).

## Đối chiếu với mã (07/10/2026)

Bản này viết ngoài repo (PM qua Claude chat). Đối chiếu với `main` (`d03a55e`), phần Tiền đề và bảng Bối cảnh có mấy chỗ coi là đã có nhưng thật ra chưa có:

| Bản này ghi | Thực tế trong mã |
|---|---|
| Onboarding 4 màn Đầy đủ, có `AssessmentResult` 8 câu | Chưa có. Không có màn Splash, Chào mừng, Đánh giá, Kết quả hạng, cũng không có `AssessmentResult`. `shell-design.md` mới quy hoạch các màn này |
| `/training/ai-path` ở mức Đọc được | Chưa có route, chưa có màn (`lib/core/router/routes.dart`) |
| `weakestSkill()`, `readyForLevelUp` trên Player Intelligence | Tên thật là `PlayerIntelligence.weak` (yếu nhất đứng đầu) và `readyDrillIds`. `readyForLevelUp` xét **từng bài tập**, không phải lên hạng |
| Mục tiêu "lên hạng kế tiếp" | Enum `Rank` có trong `lib/domain/rank.dart` nhưng chưa nơi nào dùng. Người chơi chưa có hạng, chưa có quy tắc lên hạng |
| Thành tựu mốc streak | Chưa có streak theo ngày. Chỉ có `PracticeConstants.readyStreak`, tức chuỗi buổi đạt trong một bài |
| Xếp lộ trình bằng Recommendation Engine, không viết thuật toán mới | Engine chỉ chọn một bài cho hôm nay. Xếp cả chuỗi bước vẫn cần thêm logic, và cần công thức ước lượng mốc thời gian cụ thể |
| "Lập kế hoạch phá bi (đã có)" | Chưa xây. Tên đã chốt là **Kế hoạch dọn bàn**; spec `2026-10-07-poolcoachai-run-out-planner-design.md` |

**Chủ sản phẩm chốt 07/10:**
1. Xây **dự án con Đánh giá + hạng trước**: onboarding 8 câu, tính và lưu hạng cho người chơi, quy tắc lên hạng. Lộ trình dùng kết quả đó, đúng quyết định 1 bên dưới.
2. Thứ tự: **Kế hoạch dọn bàn → Đánh giá + hạng → Lộ trình**.

Các quyết định 1–7 bên dưới giữ nguyên hướng. Khi viết lại, chỉnh tên hàm cho khớp mã và bỏ các giả định "đã có" ở trên.
Tiền đề: 5 tab điều hướng, Player Intelligence + Recommendation Engine, tài khoản/đồng bộ, và mô phỏng góc cắt (nay đã có lõi vật lý tất định) đã vào main. Onboarding 4 màn (Splash → Chào mừng → Đánh giá 8 câu → Kết quả hạng) đã **Đầy đủ**. `/training/ai-path` ("Lộ trình AI") hiện mới ở mức **Đọc được** — đây là tài liệu thiết kế cho phần đó.

## Bối cảnh

Phiên làm việc gần nhất với PM (qua Claude chat) đã liệt kê lại 9 tính năng dự định cho app, không theo đúng cấu trúc 5 tab đã build. Đối chiếu lại:

| PM liệt kê hôm nay | Vị trí thật trong app đã build |
|---|---|
| 1. Tài khoản | Tab Hồ sơ (đã có: cơ bi-a, hồ sơ & hạng, cài đặt) |
| 2. Trung tâm tập luyện — Kiến thức | Tab Luyện tập → Kiến thức (đã có) |
| 2. Trung tâm tập luyện — Bài tập | Tab Luyện tập → Bài tập (đã có) |
| 3. Dashboard | Tab Trang chủ (đã có) |
| 4. Lộ trình tập luyện (mục tiêu → khảo sát → timeline, thành tựu) | **Chưa có — là tài liệu này** |
| 5. Bài tập hôm nay | Đã có, hiển thị trên Trang chủ (output của Recommendation Engine) |
| 6. Coach tình huống | Nút Coach nổi (đã có, trả lời rule-based, chưa nối LLM) |
| 7. Đánh giá năng lực / điểm yếu | Đã có — `weakestSkill()` trong Player Intelligence, hiện lên ở Trang chủ + Thống kê |
| 8. Lộ trình tiến cấp thích ứng | PM xác nhận đây và mục 4 là **MỘT tính năng duy nhất** — gộp vào tài liệu này |
| 9. Giả lập giải hình (runout) | Tab Luyện tập → Mô phỏng góc cắt + Lập kế hoạch phá bi (đã có, đang nâng cấp vật lý) |

Hai mục còn thiếu nhà (Thi đấu, Thống kê chi tiết) **đã có tab riêng**, không nằm trong phạm vi tài liệu này.

**Quyết định điều hướng (đã chốt với PM):** không thêm tab thứ 6. "Lộ trình" = nâng cấp `/training/ai-path` từ Đọc được lên Đầy đủ, nằm trong tab Luyện tập như đã quy hoạch ở `shell-design.md`.

## Mục tiêu

Biến "Lộ trình AI" từ màn tĩnh thành nơi người chơi: đặt 1 mục tiêu cụ thể, thấy lộ trình các bước để tới đó (dựa trên dữ liệu thật, không phải văn bản viết sẵn), thấy thành tựu đã đạt, và thấy lộ trình **tự cập nhật** khi Player Intelligence đổi (giống cách `weakestSkill()` đã tự tính lại từ dữ liệu buổi tập, không phải hằng số).

## Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | Không dựng khảo sát mới. "Khảo sát" trong yêu cầu PM = tái dùng `AssessmentResult` (8 câu, đã Đầy đủ) làm baseline kỹ năng. | Tránh 2 hệ thống đánh giá trình độ song song cho cùng 1 người chơi — đúng nguyên tắc một nguồn sự thật đã áp dụng ở Kế hoạch Vật lý bàn (mục 7). |
| 2 | Thêm 1 bước mới, chưa từng có: **đặt mục tiêu** (`PlayerGoal`) — người chơi chọn 1 trong vài loại mục tiêu định sẵn (lên hạng kế tiếp / thuần thục 1 kỹ năng cụ thể / chuẩn bị 1 giải đấu) + mốc thời gian mong muốn. | Đây là input duy nhất còn thiếu để sinh lộ trình; không có nó thì "lộ trình" chỉ là liệt kê lại Player Intelligence đã có sẵn ở Trang chủ/Thống kê, không có giá trị mới. |
| 3 | Lộ trình (`RoadmapStep[]`) là **suy ra**, không phải nhập tay: với mục tiêu + `PlayerIntelligence` hiện tại (mastery từng `SkillCategory`, `weakestSkill()`, `readyForLevelUp`) + danh sách Bài tập/Kiểm tra kỹ năng theo level, thuật toán xếp các bước còn thiếu để đạt mục tiêu, ưu tiên kỹ năng yếu nhất trước (tái dùng `Recommendation Engine` đã có ở Kế hoạch 2, không viết thuật toán xếp hạng mới). | Giữ đúng nguyên tắc đã lập ở Kế hoạch 2: AI gợi ý, không tự quyết định hộ người chơi; và tránh viết lại logic suy luận đã có. |
| 4 | **Thành tựu** (`Achievement`) được cấp khi: hoàn thành 1 bước trong lộ trình, hoặc Skill Test đạt (dùng `readyForLevelUp` đã có), hoặc đạt mốc streak — KHÔNG có thành tựu tự nhập tay hoặc thành tựu "ảo" không gắn sự kiện dữ liệu thật nào. | Giữ tính nhất quán: cùng dữ liệu phải ra cùng kết quả, giống lý do đã nêu ở mục "AI không được phán lên cấp" tại `shell-design.md`. |
| 5 | Timeline hiển thị mốc thời gian **ước lượng**, tính từ tốc độ tiến bộ trung bình gần đây của người chơi (bao nhiêu buổi/tuần, mastery tăng bao nhiêu/buổi) — không phải ngày cố định app tự đặt ra. | Một mốc ngày cố định do app "đoán" sẽ sai gần như chắc chắn và làm mất lòng tin; ước lượng động, có thể lệch, trung thực hơn. |
| 6 | Mục tiêu có thể đổi/hủy bất kỳ lúc nào (nút trong chính màn Lộ trình); đổi mục tiêu thì tính lại toàn bộ lộ trình từ dữ liệu hiện tại, không cộng dồn lộ trình cũ. | Người chơi thực tế đổi ý thường xuyên; cộng dồn lộ trình cũ sẽ tạo danh sách rác không ai dùng. |
| 7 | Gate lên cấp (Skill Test) dùng đúng `readyForLevelUp` đã có ở Player Intelligence — tài liệu này KHÔNG định nghĩa lại điều kiện lên cấp. | Skill Test/Chứng nhận đã được quy hoạch riêng ở `shell-design.md` (khung, trạng thái "Khung"); tài liệu này chỉ tiêu thụ kết quả, không thiết kế lại luồng Skill Test. |

## Data model mới

```
PlayerGoal
  id, type (lenHang | thuanThucKyNang | chuanBiGiaiDau)
  targetRank?: Rank              // khi type = lenHang
  targetSkill?: SkillCategory    // khi type = thuanThucKyNang
  targetDate?: DateTime          // mốc PM muốn, chỉ để hiển thị cùng ước lượng — không ép thuật toán
  createdAt, status (active | achieved | abandoned)

RoadmapStep
  id, goalId
  kind (baiTap | kiemTraKyNang | on luyện kỹ năng yếu)
  refId                          // id bài tập / skill test liên quan
  order                          // thứ tự trong lộ trình, do thuật toán xếp
  status (chuaToi | dangLam | xong)
  estimatedDate: DateTime        // ước lượng động, tính lại mỗi lần mở màn

Achievement
  id, playerId, type (hoanThanhBuoc | dauSkillTest | mocStreak)
  refId, earnedAt
```

Không thêm field mới vào `Player`/`AssessmentResult`/`PlayerIntelligence` — 3 cái đó đã đủ dữ liệu nền, `PlayerGoal`/`RoadmapStep`/`Achievement` là lớp mỏng phía trên.

## Màn hình (`/training/ai-path`, nâng từ Đọc được → Đầy đủ)

1. **Chưa có mục tiêu** (trạng thái rỗng): nút "Đặt mục tiêu" → chọn loại mục tiêu + (tùy loại) hạng đích/kỹ năng đích + mốc thời gian mong muốn.
2. **Đã có mục tiêu**: hiển thị
   - Mục tiêu hiện tại (sửa/hủy được)
   - Timeline các `RoadmapStep` theo thứ tự, mỗi bước có trạng thái + ngày ước lượng, bấm vào bước = đi thẳng tới Bài tập/Skill Test tương ứng (giống liên kết 2 chiều Kiến thức↔Bài tập đã có)
   - Danh sách Thành tựu đã đạt
   - 1 dòng giải thích ngắn: "Lộ trình này tính lại mỗi khi bạn tập — tiến bộ nhanh hơn thì mốc thời gian sẽ sớm lại."

## Kiểm thử bắt buộc

- Đổi dữ liệu mẫu (buổi tập) → thứ tự `RoadmapStep` và ngày ước lượng phải tự đổi theo, không có chuỗi hard-code nào mô tả lộ trình.
- Đặt 2 loại mục tiêu khác nhau trên cùng 1 người chơi mẫu → ra 2 lộ trình khác nhau, ưu tiên đúng theo loại mục tiêu (lên hạng ưu tiên kỹ năng yếu nhất tổng thể; thuần thục kỹ năng ưu tiên đúng kỹ năng đó).
- Đổi mục tiêu giữa chừng → `RoadmapStep` cũ bị thay hết, không còn sót.
- `Achievement` chỉ được tạo khi có sự kiện dữ liệu thật tương ứng (test: không có cách nào tạo `Achievement` mà không qua 1 trong 3 `type` sự kiện).

## Ngoài phạm vi tài liệu này

- Không thiết kế lại luồng Skill Test/Chứng nhận (đã quy hoạch riêng, còn ở trạng thái Khung).
- Không đổi thuật toán Recommendation Engine (Kế hoạch 2) — chỉ gọi lại.
- Không thêm khảo sát mới ngoài `AssessmentResult` 8 câu đã có.
- Không thiết kế thông báo đẩy nhắc lộ trình (Notifications đã có màn riêng, nối sau nếu cần).
