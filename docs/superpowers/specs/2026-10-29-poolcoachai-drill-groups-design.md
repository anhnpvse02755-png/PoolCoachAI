# PoolCoachAI — Nhóm bài Dựng cơ, Nhảy bi, Mát xê

**Ngày:** 29/10/2026. **Tiền đề:** `main` 6666b86 (Giải đấu, Drift v16).
**Quyết định:** chủ dự án giao toàn quyền ("bạn tự quyết đi"). Mọi lựa chọn dưới đây là **quyết định của Claude**, kèm lý do để chủ dự án sửa khi cần. Ràng buộc của chủ dự án: nội dung chỉ lấy từ nguồn thật, không bịa.

## 1. Mục đích

Spec Lộ trình (2026-10-15, §10) đã để ngoài phạm vi: "bài tập mới cho dựng cơ / nhảy bi / mát xê".

Hệ quả hiện tại:
- Bài BU S8 (Dựng cơ) và S9 (Nhảy bi hoặc Mát xê) được chấm nhưng không nối với nhóm nào (`bu_category_map.dart`: `'S8': null, 'S9': null`).
- Người chơi yếu ở hai bài đó không có bài tập để luyện.

Thuật ngữ, theo chủ dự án:
- **Dựng cơ**: nâng đuôi cơ.
- **Nhảy bi**: jump.
- **Mát xê**: massé, một kỹ thuật **riêng**, không gộp với nhảy bi.

## 2. Nguồn thật có trong dự án

| Nguồn | Nội dung | Dùng cho |
|---|---|---|
| **BU Exam II**, S8 (tr. 12), S9 (tr. 13), đã mã hóa trong `lib/domain/assessment/bu_layouts.dart` và chép lời trong `vi.dart` | Bố cục bi đo được, 1 điểm mỗi cú thành công, 3 bậc | **Bố cục và tiêu chí đạt** |
| **Tổng hợp mẹo** (tài liệu chủ dự án, mục 13.1–13.4, nguồn Dr. Dave Alciatore) | Nhảy bi: ngắm giữa tâm bi cái và điểm bi tiếp xúc nỉ; nhảy cao và ngắn thì nâng cơ cao, nhảy xa thì thêm lực và bớt nâng; cú nhảy hay bị cắt dày hơn dự tính. Mát xê: bẻ cong bi cái sau va chạm | **Cách làm** của nhảy bi và mát xê |
| **Tu-Dien-Kien-Thuc** mục 17 (Jump), 18 (Masse) | Cách làm, lỗi hay gặp, cách sửa, cảnh báo rách nỉ | **Lỗi hay gặp và cảnh báo**. Mục này không ghi nguồn gốc, nên chỉ dùng phần không có con số |

Những gì **không** có nguồn và vì vậy **không** được đưa vào:
- góc nâng cơ cụ thể (con số 30–70° của Tu-Dien 18 tự mâu thuẫn với "gần vuông góc");
- lực đánh;
- khoảng cách đo bằng cm;
- số đầu cơ lệch tâm cho mát xê;
- bất kỳ cách làm nào cho dựng cơ ngoài định nghĩa "nâng đuôi cơ".

## 3. Nhóm kỹ năng mới

Thêm ba thành viên vào `SkillCategory`: `dungCo`, `nhayBi`, `matXe`. Tên Vi lần lượt là "Dựng cơ", "Nhảy bi", "Mát xê".

Lý do không gộp thành một nhóm: theo chủ dự án, mát xê là kỹ thuật riêng. Cơ nhảy (`CueType.jump`) đã là một loại cơ riêng trong app.

**Nhóm nâng cao** (quyết định của Claude). Ý tưởng :130 ghi: "Không yêu cầu người dùng học … jump, masse hoặc kỹ thuật nâng cao quá sớm nếu chưa cần cho mục tiêu hiện tại".

Vì vậy, ba nhóm này **không** được app tự đưa vào gợi ý, trừ khi người chơi đã chủ động với nhóm. Cụ thể:
- Không vào thứ tự gợi ý cho người mới (`newcomerOrder`). Ba nhóm đứng cuối, sau mọi nhóm cơ bản, và chỉ được xét khi có log.
- Không bị coi là "yếu" chỉ vì **chưa có dữ liệu**. Một nhóm nâng cao chưa có buổi tập nào thì không vào danh sách yếu của Player Intelligence, không vào gợi ý Home, và không vào bước "thuần thục" tự động của Lộ trình.
- Khi người chơi **đã ghi buổi tập** của nhóm, nhóm được xét như mọi nhóm khác: mastery, xu hướng, yếu.
- Khi **BU cho thấy yếu ở S8**, Lộ trình lên hạng được giao bài Dựng cơ (xem §5). Đây là dữ liệu thật về kỹ năng đó.
- Người chơi vẫn chọn được ba nhóm ở mọi bộ chọn nhóm: Training, Timer, lịch tập, mục tiêu "Thuần thục một nhóm", và kỹ năng phù hợp của cơ.

Màu nhóm: ba bộ màu mới, khác sáu bộ màu hiện có. Phải đủ tương phản theo kiểm tra màu đang có trong test.

## 4. Bài tập mới (9 bài, 3 mỗi nhóm)

Mỗi nhóm có 3 cấp, ứng với 3 bậc BU: **cấp 1 = Bachelors, cấp 2 = Masters, cấp 3 = Doctorate**.

- **Bố cục:** đúng bố cục BU của bậc đó, lấy từ `bu_layouts.dart`. Bước 1 của bài mô tả cách xếp bi theo lời BU đã có trong `vi.dart`.
- **Tiêu chí đạt:** bài kiểu `target`. `target` bằng **số cú trong bố cục BU của bậc đó**, lấy đúng từ dữ liệu bố cục. `score` là số cú thành công, mỗi cú 1 điểm như BU. Đạt khi `drillRatio ≥ 1`, tức thành công mọi cú của bố cục.
  - Lý do: đây là thang điểm thật của nguồn. App không đặt ngưỡng phần trăm mới nào.
  - Hệ quả: cổng Skill Test (chuỗi 3 buổi đạt) đòi người chơi làm trọn bố cục 3 buổi liên tiếp. Đây là mức chặt, nhưng phù hợp với nhóm nâng cao.
- **Nhảy bi và Mát xê dùng chung bố cục S9.**
  - Bài nhảy bi yêu cầu **chỉ dùng nhảy bi**, bài mát xê yêu cầu **chỉ dùng mát xê**. Cách làm của mỗi bài lấy từ nguồn của riêng kỹ thuật đó.
  - Bậc Doctorate của S9 có yêu cầu "chết cái" (scratch) ở lỗ góc. Giữ nguyên như BU.
- **Dựng cơ dùng bố cục S8.** Phần cách làm chỉ gồm:
  - định nghĩa "nâng đuôi cơ";
  - lời bố cục BU: bi cái áp băng hoặc áp bi chướng ngại.
  - Không thêm mẹo nào vì không có nguồn. App nói thẳng "Chưa có mẹo kỹ thuật có nguồn cho dựng cơ."
- **Cảnh báo an toàn:** cả ba nhóm đều có cảnh báo, theo Tu-Dien 17 và 18: "Nên luyện trên bàn tập hoặc nỉ cũ, dễ làm rách nỉ."
- **Câu chữ:** viết lại bằng tiếng Việt, đúng thuật ngữ đã duyệt. Phải qua bộ lọc từ cấm trong `seed_test.dart`.
- **Id:** `d11`–`d19`, nối tiếp `d1`–`d10`.

## 5. Nguồn hiển thị và nối với BU

**Nguồn trên bài tập.**
- Thêm khai báo nguồn cho bài tập: một bảng hằng trong seed `drillId → nguồn`. Không lưu vào DB, vì bài tập được upsert từ seed mỗi lần mở app.
- Chi tiết bài hiện dòng "Nguồn: …", ví dụ "Billiard University Exam II, S8; mẹo theo Dr. Dave Alciatore".
- Bài cũ `d1`–`d10` không có khai báo nguồn thì không hiện dòng này. App không bịa nguồn cho chúng.

**Nối BU.**
- `bu_category_map.dart`: **S8 → `dungCo`**.
- **S9 vẫn `null`.** Lý do: BU S9 cho phép nhảy bi **hoặc** mát xê, nên điểm S9 không cho biết người chơi yếu kỹ thuật nào. Gán vào một nhóm là đoán.
  - Thay vào đó, khi S9 yếu, Lộ trình hiện một dòng: "Bài S9 chấm nhảy bi hoặc mát xê: chọn nhóm Nhảy bi hoặc Mát xê để luyện". Dòng này mở bộ chọn mục tiêu "Thuần thục".
- Đây là thay đổi so với quyết định cũ "S8, S9 không khớp nhóm nào". Quyết định cũ đúng khi chưa có nhóm. Nay S8 đã có nhóm đúng mục đích.

## 6. Những chỗ khác bị ảnh hưởng

- **Coach** (`coach_topic.dart`): ba nhóm trả `null`. Planner không mô phỏng các cú này (spec Coach :32).
- **Phân tích trận** (`shot_skill_map`): không đổi. `MatchShotType` không có loại nhảy bi hay mát xê.
- **Coach Chat:** prompt hệ thống liệt kê mọi `SkillCategory` bằng tên Vi, nên tự có ba nhóm mới. Dịch vụ chat chưa deploy, nên không cần thêm gì.
- **Đồng bộ:** `cat` là chữ.
  - Bản app cũ kéo về một buổi tập có `cat` lạ (`dungCo`…) **phải không làm hỏng đồng bộ**. Plan phải kiểm tra bộ chuyển đổi hiện tại: `practice_sync`, `cue_equipment_sync`, `roadmap_converters`, Skill Test.
  - Nếu bản cũ đang ném lỗi, đó là rủi ro phát hành. Plan phải có test chứng minh và một quyết định rõ, giống cách đã làm với `chungNhan` (Ruling S13).
- **Tài liệu:** cập nhật PRD (danh sách nhóm), tài liệu ý tưởng (bảng trạng thái) và memory thuật ngữ (từ 6 nhóm lên 9).

## 7. Ngoài phạm vi

- Mô phỏng nhảy bi hoặc mát xê trong bàn mô phỏng và Planner.
- Loại cú nhảy bi hoặc mát xê trong ghi trận.
- Bài tập có con số góc nâng cơ, lực đánh hay khoảng cách. Chưa có nguồn; sẽ thêm khi chủ dự án cung cấp.
- Thêm bài cho sáu nhóm cũ.

## 8. Kiểm thử

- **Domain:**
  - Nhóm nâng cao không vào danh sách yếu hay gợi ý khi chưa có log; vào bình thường khi có log.
  - `newcomerOrder` phủ đủ chín nhóm, ba nhóm nâng cao đứng cuối.
  - S8 → `dungCo`; S9 → null, kèm dòng hướng dẫn.
- **Seed:**
  - 19 bài, id duy nhất, mỗi nhóm có ít nhất một bài.
  - `target` của mỗi bài mới bằng số cú trong bố cục BU tương ứng. Test đọc từ `bu_layouts`, không viết số tay.
  - Câu chữ qua bộ lọc từ cấm.
  - Mỗi bài mới có khai báo nguồn; bài cũ không có.
- **Chống bịa:**
  - Đổi bố cục BU thì `target` đổi theo.
  - Nhóm nâng cao không có log thì không xuất hiện trong gợi ý.
- **Tương thích bản cũ:** test bộ chuyển đổi hiện tại với `cat` lạ. Xem §6.
- **Widget:**
  - Bộ chọn nhóm có ba nhóm mới.
  - Chi tiết bài hiện nguồn và cảnh báo.
  - 360x640 chữ lớn (giới hạn 1.5).
- **E2E:** chạy lại bộ live hiện có. Thêm một bước vào `match_drill_stats.mjs` hoặc script mới: ghi một buổi Dựng cơ, thấy nhóm ở Thống kê và trên Directus.
