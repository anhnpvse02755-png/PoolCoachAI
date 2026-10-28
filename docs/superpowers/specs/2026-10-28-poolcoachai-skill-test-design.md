# PoolCoachAI — Skill Test và chứng nhận

**Ngày:** 28/10/2026. **Tiền đề:** `main` sau PR #4 (phân tích trận, schema v14).
**Quyết định:** chủ dự án giao toàn quyền ("bạn tự quyết đi"). Mọi lựa chọn dưới đây là **quyết định của Claude**, kèm lý do để chủ dự án sửa khi cần.

## 1. Mục đích

PRD §6.7 yêu cầu: "Kiểm tra người chơi đã đạt yêu cầu của một level hay chưa, dựa trên kết quả thực hiện thực tế — không phải một nút 'Hoàn thành Level 1' giả. Certification thể hiện các level/kỹ năng đã đạt, hiển thị lại ở Profile."

Hiện app chỉ có tiến độ sẵn sàng: chuỗi 3 buổi đạt liên tiếp (`isReadyForLevelUp`). Chưa có bài kiểm tra riêng, chưa có chứng nhận, và chưa có quan hệ nào giữa chứng nhận và cấp. Mục 18 câu 4 của tài liệu ý tưởng hỏi: "Cấp Drill mở bằng chuỗi kết quả, Skill Test riêng hay cần cả hai?"

## 2. Nguyên tắc

- **Luật quyết định, không phải mô hình.** Cổng mở cấp do luật, cấm LLM (README quy tắc 2; shell-design: "Skill Test và cổng mở cấp phải do luật quyết định").
- **Không bịa.** Mọi câu chữ là khuôn trong `vi.dart`, điền bằng giá trị domain. Thiếu dữ liệu thì nói thẳng.
- **Bằng chứng có điều kiện đo.** Ý tưởng :303 yêu cầu mỗi lần kiểm tra lưu điều kiện đo, ngày, kết quả và nguồn.
- **Không khóa thư viện.** Ý tưởng :308 và PRD :91: khóa chỉ trong nội bộ một nhánh kỹ năng. Mọi bài vẫn luyện được.
- **Không đặt ngưỡng mới chưa kiểm chứng** (mục 18 câu 4). Bài kiểm tra dùng đúng tiêu chí đạt của bài tập: `passThreshold` hoặc `target`, tức `drillRatio ≥ 1`.

## 3. Trả lời mục 18 câu 4: cần cả hai

Đây là quyết định của Claude.

1. **Chuỗi 3 buổi đạt** (`isReadyForLevelUp`, có sẵn) là điều kiện để **mở bài kiểm tra**.
2. **Skill Test** là **một buổi riêng**, được đánh dấu là buổi kiểm tra và ghi đủ điều kiện đo.
   - Đạt khi `drillRatio ≥ 1`, cùng tiêu chí với buổi tập.
   - Đạt thì được **chứng nhận** bài đó.

Lý do chọn cả hai: chuỗi buổi tập là người chơi tự ghi kết quả, nên không đủ làm bằng chứng. Còn một bài kiểm tra mở bất cứ lúc nào thì không có ý nghĩa sẵn sàng. Ghép hai điều kiện thì vừa có tiến trình vừa có bằng chứng.

## 4. Đơn vị chứng nhận và cấp

- **Chứng nhận theo từng bài tập** (`drillId`), ghi kèm cấp (`drill.level`) lúc đạt. Thư viện mẫu không có thang cấp liên tục trong mỗi nhóm, nên "cấp" là các bài cùng nhóm xếp theo `level`.
- **Cổng mở cấp** trong một nhóm kỹ năng:
  - Bài kiểm tra của một bài cấp L chỉ mở khi mọi bài **cấp thấp hơn L** trong cùng nhóm đã có chứng nhận.
  - Bài cấp thấp nhất của nhóm không cần điều kiện này.
  - Luyện tập vẫn mở cho mọi bài. Chỉ **bài kiểm tra** bị khóa.
- **Nhóm thuần thục** (hiển thị, không lưu): một nhóm hiện "đã chứng nhận toàn nhóm" khi mọi bài của nhóm đều có chứng nhận.
- Khi một nhóm chưa có bài cấp kế tiếp, app nói thẳng: "Chưa có cấp tiếp theo trong nhóm này". Dự án 5 sẽ thêm bài.

## 5. Luồng người chơi

1. **Chi tiết bài tập** (thẻ sẵn sàng hiện có). Khi đủ chuỗi 3 buổi **và** qua cổng cấp, hiện nút **"Làm bài kiểm tra"**. Nếu chưa mở được, hiện lý do, ví dụ: "Cần chứng nhận {bài cấp thấp hơn} trước" hoặc "Cần thêm {n} buổi đạt liên tiếp".
2. **Màn kiểm tra** `/training/skill-test/:drillId`:
   - Hiện điều kiện đo: kích thước bàn (chọn 7/8/9 ft như bài BU), các bước của bài và tiêu chí đạt.
   - Người chơi nhập kết quả theo đúng kiểu của bài (`score` / `attempts`).
   - Có nút hủy. Hủy thì không lưu kết quả.
3. **Kết quả.**
   - **Đạt:** "Đã chứng nhận {bài} — cấp {L}", kèm ngày.
   - **Chưa đạt:** "Chưa đạt: {score}/{mục tiêu}", kèm lời khuyên làm được tại bàn, ví dụ: "Tập thêm bài này rồi kiểm tra lại".
4. **Làm lại sau khi trượt.** Phải có ít nhất **1 buổi tập mới** của bài đó sau lần kiểm tra trượt (quyết định của Claude). Lý do: tránh bấm làm lại liên tục, nhưng không đặt thời gian chờ tùy ý.
5. **Profile** có mục **"Chứng nhận"**, nhóm theo kỹ năng: tên bài, cấp, ngày. Khi chưa có gì, hiện "Chưa có chứng nhận" kèm gợi ý bài gần sẵn sàng nhất (lấy từ `consecutivePassCount`).
6. **Danh sách bài tập** (Training): bài đã chứng nhận có huy hiệu "Đã chứng nhận".
7. **Lộ trình và thành tích:** danh sách thành tích hiện cả chứng nhận.
8. **Home:** khi có bài sẵn sàng kiểm tra (dùng `readyDrillIds` có sẵn và cổng cấp), Home có một dòng "Sẵn sàng kiểm tra: {bài}" mở thẳng màn kiểm tra.

## 6. Khi phong độ tụt

Chứng nhận **không bị thu hồi**. Nó là bằng chứng có ngày, giống lịch sử bài BU.

Nếu `consecutivePassCount` của bài đã chứng nhận về 0 trong 5 buổi gần nhất, chi tiết bài hiện thêm "Phong độ gần đây chưa đạt", dữ liệu tính được. Không có cảnh báo chính thức nào.

## 7. Dữ liệu và đồng bộ

- **Drift v15:** bảng `skill_test_rows`, chỉ thêm, không sửa. Các cột:
  - `id` (uuid), `user_id`, `drill_id`, `drill_level`, `table_size`
  - `started_at`, `completed_at?`, `cancelled_at?`
  - `score?`, `attempts?`, `passed?`, `notes?`
  - `synced_at?`
  - ảnh chụp tiêu chí lúc kiểm tra: `pass_threshold?` / `target?` (đúng một trong hai). Bổ sung 28/10 theo yêu cầu "lưu điều kiện đo": tiêu chí của bài có thể đổi về sau, chứng nhận vẫn phải nói đã đạt theo tiêu chí nào.
- **Chứng nhận:** thêm `AchievementKind.chungNhan` với `refId = drillId`, id tất định.
  - Ghi khi một bài kiểm tra hoàn tất và đạt.
  - Tính lại được từ `skill_test_rows`. Hai nguồn phải khớp, có test.
  - **Không đẩy lên Directus** (sửa 28/10 sau review cuối). Bản app cũ chưa biết `chungNhan` sẽ lỗi khi kéo về một thành tích lạ. Chứng nhận tính lại được hoàn toàn từ `skill_tests` đã đồng bộ, nên mỗi máy tự ghi. Dòng `chungNhan` được đánh dấu đã đồng bộ ngay khi ghi, nên không tính vào số dữ liệu chờ đồng bộ.
- **Directus:**
  - Collection mới `skill_tests` (create/read của chính người chơi, không update/delete).
  - `verify.mjs` kiểm tra: tạo được, không đọc được của người khác, không sửa được.
  - `achievements` không đổi schema và không nhận dòng `chungNhan`. Bên kéo về vẫn bỏ qua kind lạ thay vì lỗi (Ruling S1).
  - Chạy bootstrap trên prod trước khi publish web.
- **Sync:** đẩy và kéo `skill_tests`, theo mẫu `timer_sessions`/`achievements`: chỉ thêm, gặp `RECORD_NOT_UNIQUE` thì coi là đã đồng bộ.

## 8. Kiểm thử

- **Domain:**
  - Cổng kiểm tra (chuỗi buổi đạt + cổng cấp).
  - Đạt/trượt theo `drillRatio`.
  - Điều kiện làm lại sau khi trượt.
  - Thứ tự cấp khi có cấp trùng hoặc cấp không liên tục.
  - Nhóm thuần thục.
  - "Phong độ gần đây chưa đạt".
- **Chống bịa:** đổi dữ liệu thì lý do khóa hoặc mở nút kiểm tra, mục Profile và dòng Home tự đổi theo.
- **Kiến trúc:** domain không chứa tiếng Việt, không import Flutter; domain skill test không tạo `PlayerRank`.
- **Repository/migration:** 14→15; dựng mới ở v15; đồng bộ đẩy/kéo; chứng nhận idempotent.
- **Widget:** nút kiểm tra (mở / khóa với lý do); luồng kiểm tra đạt/trượt/hủy; mục Profile; huy hiệu; 360x640 chữ lớn.
- **E2E live:** `tool/e2e/skill_test.mjs`. Tài khoản tạm ghi 3 buổi đạt cho d1, làm bài kiểm tra đạt, rồi thấy chứng nhận ở Profile và dòng `skill_tests` trên Directus.

## 9. Ngoài phạm vi

- Thêm bài tập mới (dự án 5).
- Camera/Vision để xác minh kết quả tự động.
- Người khác xác nhận hộ (huấn luyện viên chấm).
- Đổi hạng: hạng vẫn chỉ đổi qua bài BU.
