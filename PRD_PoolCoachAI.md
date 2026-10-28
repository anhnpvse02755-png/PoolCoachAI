# PoolCoachAI — Bản mô tả sản phẩm kết hợp
### (Luyện Cơ + PoolCoachAI)

Bản này giữ nguyên triết lý và kiến trúc AI của PoolCoachAI, đồng thời đưa vào các chức năng cụ thể đã được xây dựng ở bản Luyện Cơ (mô phỏng góc cắt, đồng hồ + lịch tập, quản lý cơ chi tiết) vào đúng vị trí trong hệ thống. Phần nào của hai bên trùng khái niệm thì được hợp nhất thành một chức năng duy nhất; phần nào chỉ có ở một bên thì được giữ nguyên.

---

## 1. Tầm nhìn sản phẩm

Xây dựng ứng dụng luyện tập bida tốt nhất thế giới.

PoolCoachAI giúp cơ thủ phát triển trình độ qua một vòng lặp:

**Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp**

AI đóng vai trò Coach — gợi ý người chơi nên học gì, tập gì tiếp theo — nhưng không khóa cứng cách người chơi luyện tập. Người chơi luôn có thể tự chọn bài tập, tự đặt lịch, tự dùng công cụ hỗ trợ (mô phỏng góc cắt, đồng hồ luyện tập) mà không cần đi qua AI.

## 2. Triết lý sản phẩm

Hai hoạt động được phân biệt rõ:

- **TẬP** — rèn luyện kỹ năng đơn lẻ, có kiểm soát. Nằm trong **Training Center**.
- **CHƠI** — chơi trận / thi đấu thực tế. Nằm trong **Play**.

Dữ liệu của hai hoạt động không trộn lẫn thành một loại session, nhưng được kết hợp ở tầng **Statistics / Intelligence / Coach** để đánh giá tiến bộ tổng thể.

```
                 PoolCoachAI
                    │
          ┌─────────┴─────────┐
          │                   │
       TRAINING             PLAY
          │                   │
   Drill · Knowledge      Match Recording
   Skill Test             Match History
   Simulator · Timer      Competition
   Schedule · Equipment
          │                   │
          └─────────┬─────────┘
                    ↓
             Intelligence
                    ↓
                 Coach
                    ↓
              Recommendation
```

## 3. Người dùng mục tiêu & hệ rank

PoolCoachAI phục vụ cơ thủ phong trào và người muốn nâng trình, dùng cách hiểu hạng tại Hà Nội làm tham chiếu ban đầu:

- Nhóm nghiệp dư/phong trào: **K → I → H → G**
- Nhóm bước vào sân chơi cạnh tranh: **F → E → D → C → B → A → Professional**

Đây là bảng định nghĩa riêng của PoolCoachAI, không phải chuẩn quốc gia duy nhất — app cần giải thích rõ điều này. "Chưa từng chơi" không được highlight như một cấp rank.

## 4. Onboarding & Skill Assessment

*(Đã xây — spec `docs/superpowers/specs/2026-10-14-poolcoachai-assessment-rank-design.md`.)*

- Sau lần đăng nhập đầu tiên, tài khoản chưa có hạng được đưa tới **8 câu hỏi** (nguyên văn PoolOS v2). Chỉ Q4, Q5, Q6 tính hạng gợi ý, theo bảng quy đổi neo vào mô tả Fargo của Dr. Dave. Người chơi **Xác nhận** (hạng *ước lượng*) hoặc **Chọn hạng khác** (hạng *tự khai*, kể cả PRO). Màn nào cũng có **Để sau**. Máy mới chưa lấy được hạng từ máy chủ thì không bị ép vào bộ câu hỏi.
- **Bài kiểm tra Billiard University** (Đề I + Đề II, thang 200, cộng điểm thô theo phiếu điểm BU) cho hạng *đã kiểm chứng*. Điểm BU quy đổi sang K…A bằng cách gộp các mức của `BU_Rating_Comparisons.pdf`; BU không bao giờ cho PRO. Hai lần hoàn tất cách nhau tối thiểu 14 ngày; lần bị hủy không tính.
- App **không bao giờ tự hạ hạng**: kết quả thấp hơn chỉ đặt cảnh báo. Dữ liệu luyện tập không đổi hạng.
- Mỗi cú ghi xuống máy ngay khi nhập; hạng, câu trả lời và các lần kiểm tra đã xong đồng bộ theo tài khoản. Mọi màn hiện hạng kèm nhãn nguồn, câu miễn trừ và bảng quy đổi.

## 5. AI Home — Dashboard

Trả lời câu hỏi: **"Hôm nay tôi nên làm gì?"**

Gồm:
- **AI Coach recommendation** — gợi ý dựa trên Player Intelligence
- **Today's Goals** — ví dụ: hoàn thành *Position Recovery Lv2*, đọc *Cue Ball Control*, tiếp theo là *Skill Test Lv2*
- **Continue** — quay lại bài đang dở
- **Hôm nay có gì trong lịch** — hiển thị mục lịch tập hằng tuần của người dùng cho đúng ngày hôm nay (từ module Lịch & Đồng hồ)
- **Streak & Progress rút gọn** — số ngày luyện tập liên tiếp, tổng giờ tập tuần này *(từ Luyện Cơ)*
- **Quick Actions** — bắt đầu Drill được gợi ý, mở Mô phỏng góc cắt, bắt đầu Đồng hồ luyện tập
- Thông tin quan trọng sau buổi tập/trận gần nhất

Người dùng bấm trực tiếp vào goal hoặc quick action để đi thẳng đến chức năng tương ứng. Dashboard chỉ đưa kết luận và hành động tiếp theo; dữ liệu chi tiết nằm ở các module chuyên biệt.

## 6. Training Center

Trung tâm của PoolCoachAI, gồm các nhánh sau:

### 6.1 AI Learning Path
Lộ trình (đã làm, spec 2026-10-15): mỗi tài khoản một mục tiêu — Lên hạng (luôn là hạng ngay trên), Thuần thục một nhóm kỹ năng, hoặc Chuẩn bị giải (có ngày giải). App suy các bước từ dữ liệu thật: điểm mất ở bài BU hoàn chỉnh gần nhất (qua bảng nối 18 bài BU vào nhóm; S8 vào Dựng cơ, S9 không nối nhóm nào), Player Intelligence và nhật ký tập; tính lại mỗi khi dữ liệu đổi. Một bước xong khi nhóm đạt 75 và bài của bước có 3 buổi đạt liên tiếp. Ngày dự kiến ước lượng từ tốc độ tiến bộ 28 ngày gần nhất; không đủ dữ liệu thì nói thẳng. Thành tích chỉ đến từ sự kiện thật: xong bước, đủ điều kiện lên cấp, chuỗi 7/14/30/60/100 ngày. AI đề xuất, không khóa người dùng; không dùng LLM. Mục tiêu và thành tích đồng bộ theo tài khoản.

### 6.2 Drill Library
Đơn vị thực hành chính. Danh sách bài tập chia theo **9 nhóm kỹ năng**: sáu nhóm cơ bản Ngắm bi, Điều bi / Vị trí, Phá, Phòng thủ, A băng (kick), Cân bi (bank), và ba nhóm nâng cao Dựng cơ, Nhảy bi, Mát xê (spec 2026-10-29; mỗi nhóm ba bài theo bố cục BU S8/S9; app không tự gợi ý nhóm nâng cao khi người chơi chưa tập). Có thể tìm kiếm, filter theo trình độ hoặc theo kỹ năng, chọn trực tiếp hoặc nhận từ AI Coach.

Một Drill có nhiều **Level** (VD: Stop Shot — Easy/Medium/Hard) với **progression gate**: phải đạt yêu cầu ở Skill Test mới được mở level tiếp theo. Cơ chế này chỉ khóa progression trong nội bộ một Drill, không khóa toàn bộ Training Center.

### 6.3 Drill Recording (luồng thực hiện một bài tập)
```
Drill Detail → Recording Preparation → Drill Session → Completion
```
- **Drill Detail**: tên bài + level, mục tiêu, các bước thực hiện, bài Knowledge liên quan, lịch sử kết quả gần nhất *(nội dung hướng dẫn từng bước lấy từ định dạng Drill của Luyện Cơ)*
- **Recording Preparation**: setup bàn/camera (nếu dùng), checklist, xác nhận "Tôi đã sẵn sàng"
- **Drill Session**: thực hiện bài tập, ghi nhận kết quả theo 1 trong 2 cách:
  1. **Camera/Vision** — tự động nhận diện kết quả cú đánh, người chơi xác nhận/sửa nếu sai
  2. **Ghi nhận thủ công** — hai nút ✓ Thành công / ✗ Thất bại sau mỗi cú đánh, **hoặc** nhập nhanh kết quả tổng (VD: 7/10, hay khoảng cách kéo bi tính bằng cm) cho các bài đo bằng đơn vị khác (thời gian, khoảng cách) *(cách nhập theo đơn vị linh hoạt lấy từ Luyện Cơ, để hỗ trợ các bài không phải dạng đếm cú như Draw/Follow)*
  - Camera là phương thức **tự động hóa việc ghi nhận**, không phải điều kiện để được tập hoặc hoàn thành bài.
- **Completion**: cập nhật tỷ lệ thành công, số cú thành công/thất bại, tiến bộ qua các buổi, mức hoàn thành Drill, và đẩy dữ liệu vào Player Intelligence.

### 6.4 Mô phỏng góc cắt (Cut Angle Simulator)
*(module mới, đưa vào từ Luyện Cơ — không có trong bản PoolCoachAI gốc)*

Công cụ độc lập trong Training Center, không gắn với một Drill hay Recording flow cụ thể — người chơi mở bất cứ lúc nào để luyện cảm giác hình học:
- Đặt bi cái, bi mục tiêu và chọn lỗ trên bàn mô phỏng
- Hệ thống tự vẽ đường ngắm bằng phương pháp bi ma (ghost ball), tính góc cắt và ước lượng độ khó
- Có thể được **AI Learning Path gợi ý sử dụng** trước khi vào một Drill về ngắm bi, hoặc người chơi tự mở qua Quick Actions ở AI Home

### 6.5 Đồng hồ & Lịch tập (Practice Timer & Schedule)
*(module mới, đưa vào từ Luyện Cơ)*

- **Đồng hồ luyện tập**: đếm lên hoặc đếm ngược cho một buổi tập tự do (không gắn Drill cụ thể), gắn nhãn kỹ năng đang tập và cơ đang dùng; buổi tập được lưu và tính vào tổng giờ tập + streak trên AI Home.
- **Lịch tập hằng tuần**: người chơi tự đặt các khung giờ luyện tập định kỳ; AI Home hiển thị đúng phần lịch của ngày hôm nay, và AI Coach có thể dùng lịch này để nhắc nhở hoặc điều chỉnh Today's Goals cho phù hợp thời lượng đã đặt.

**Trạng thái triển khai hiện tại**
- Đã có đồng hồ đếm lên/đếm ngược (15, 30, 45 hoặc 60 phút), gắn nhóm kỹ năng tùy chọn, lưu/xem buổi tập gần đây; dữ liệu được tính vào streak, tổng thời gian tập tự do trong tuần và ưu tiên gợi ý trên Home.
- Đã có tạo/sửa/xóa lịch lặp theo thứ, giờ, tên buổi và nhóm kỹ năng tùy chọn; dữ liệu ngày/giờ được kiểm tra ở tầng lưu trữ. Home hiển thị các khung giờ hôm nay, lịch có nhóm kỹ năng sẽ ưu tiên nhóm đó trong gợi ý.
- Dữ liệu được lưu cục bộ và cô lập theo tài khoản trên cùng thiết bị. Dữ liệu lịch/buổi tập cũ không có chủ được giữ ở trạng thái chưa gán, không tự động tiết lộ cho tài khoản mới.
- Đã đồng bộ buổi đồng hồ (`timer_sessions`) và khung lịch (`schedule_slots`) theo tài khoản qua `practice_sync.dart`.
- Đã có nhắc lịch tập và nhắc giữ streak (`NotificationKind.schedule`, `NotificationKind.streak`), kèm kênh thông báo Android riêng; lịch nhắc được lập cục bộ trên thiết bị (nhắc lịch trước giờ bắt đầu trong 7 ngày tới, nhắc streak lúc 20:00 nếu hôm nay chưa tập).
- **Còn thiếu:** điều chỉnh mục tiêu theo thời lượng dự kiến của khung lịch (hiện lịch chỉ ưu tiên nhóm kỹ năng trong gợi ý); thông báo khi có gợi ý mới từ Coach; push khi ứng dụng đã đóng (thông báo hiện là cục bộ, trên web chỉ hiện khi tab còn mở).

### 6.6 Knowledge
Phần học lý thuyết, không khóa chặt vào Drill: kỹ thuật, cách thực hiện, lỗi thường gặp, nguyên lý, tình huống áp dụng. Một Drill có thể liên kết tới Knowledge và ngược lại (Knowledge ↔ Drill là quan hệ hỗ trợ, không phải dependency cứng). Người dùng có quyền khám phá Knowledge độc lập, tương tự thư viện bài viết ngắn theo từng kỹ năng.

### 6.7 Skill Test / Certification
Kiểm tra người chơi đã đạt yêu cầu của một level hay chưa, dựa trên kết quả thực hiện thực tế — không phải một nút "Hoàn thành Level 1" giả. Certification thể hiện các level/kỹ năng đã đạt, hiển thị lại ở Profile.

**Trạng thái triển khai hiện tại:** Danh sách và chi tiết bài tập hiển thị số buổi đạt liên tiếp gần nhất theo kết quả thực tế, tối đa 3 buổi theo điều kiện readiness hiện có. Đây chỉ là tiến độ sẵn sàng; chưa phải bài Skill Test riêng hay chứng nhận, và chưa tự mở level. Tiêu chí bài kiểm tra/chứng nhận và quan hệ giữa chứng nhận với các level cần được chốt trước khi triển khai.

## 7. Play

Nơi dành cho chơi thực tế, tách biệt hoàn toàn với Drill Session:
- **Match Recording** — ghi nhận rack, shot, kết quả, lỗi, safety, scratch, break, position và các thống kê liên quan. Mục tiêu không chỉ là thắng/thua mà là dữ liệu đủ chi tiết để hiểu cách người chơi đã chơi.
- **Match History**
- **Competition / Tournament**

**Trạng thái triển khai hiện tại**
- Đã có MVP ghi trận 8/9/10 bi theo thể thức race-to-3/5/7/9: lưu tên người chơi/đối thủ, kết quả từng ván, tỷ số, trạng thái trận và lịch sử cục bộ theo tài khoản.
- Có thể hoàn tác ván vừa ghi, kể cả sau khi trận kết thúc, để sửa nhầm kết quả. Đăng xuất chủ động xóa trận của tài khoản khỏi thiết bị.
- Đã có ghi cú theo từng ván: người đánh, phá/cú thường/phòng thủ, có bi/trượt/phạm lỗi/scratch, kết quả vị trí bi cái và ghi chú tùy chọn. Có thể hoàn tác cú cuối của ván đang diễn ra.
- Có thể sửa thể loại, tên hai người chơi và số ván thắng; kết quả rack/cú đã ghi được giữ nguyên, trạng thái hoàn tất được tính lại theo thể thức mới.
- Đã có xóa trận với bước xác nhận. Trận bị ẩn cùng tỷ số và cú đánh, đánh dấu đã xóa (`is_deleted`) và đồng bộ lên server, nên lần đồng bộ sau không kéo trận đó về lại và các thiết bị khác của tài khoản cũng ẩn trận.
- **Còn thiếu:** phân tích sâu chuỗi break/lỗi vị trí/mẫu chiến thuật và giải đấu. Kết quả từng cú là ghi nhận thủ công, chưa tự suy luận luật hay đánh giá AI.

## 8. Intelligence & Coach

```
Match Recording ─┐
                  ├→ Statistics → Player Intelligence → Coach AI → Recommendation
Drill Session ────┘
```

AI có thể phát hiện: easy miss, lỗi vị trí (position error), lỗi giao bóng, lỗi an toàn, scratch, điểm yếu theo mẫu lặp lại (pattern weakness) — rồi chuyển thành đề xuất cho Training.

**Coach** gồm:
- **Coach Chat** — trả lời các câu hỏi như "Hôm nay tôi nên tập gì?", "Tại sao tôi thua trận vừa rồi?", "Tôi đang yếu kỹ năng nào?"
- **Coach Recommendation** — dùng Assessment, lịch sử Drill (bao gồm cả buổi tập tự do qua Đồng hồ), Knowledge, lịch sử trận, Statistics và Player Intelligence để tạo đề xuất, có thể bao gồm cả gợi ý dùng Mô phỏng góc cắt cho các lỗi ngắm bi lặp lại.

## 9. Statistics

Nơi xem dữ liệu chi tiết — Dashboard chỉ đưa insight quan trọng, Statistics hiển thị đầy đủ: lịch sử, performance, thống kê trận đấu, thống kê luyện tập (bao gồm biểu đồ theo từng kỹ năng và xu hướng điểm số theo từng Drill theo thời gian), tổng giờ tập, streak, và các xu hướng kết hợp cả Training lẫn Play.

**Trạng thái triển khai hiện tại**
- Đã có tổng số buổi theo Drill và Timer, tổng thời gian tập tự do, thời gian tập tự do tuần này và streak.
- Đã có trung bình kết quả chuẩn hóa theo mục tiêu cho từng nhóm kỹ năng; các buổi thiếu dữ liệu chấm không bị tính thành 0.
- Đã có xu hướng 5 kết quả chấm gần nhất theo Drill. Giá trị được chuẩn hóa theo mục tiêu riêng của bài để so sánh cùng một Drill qua thời gian, không dùng để so điểm thô giữa các Drill.
- Khi mở màn ghi kết quả Drill, app tự đo thời lượng bằng đồng hồ đơn điệu tới lúc lưu; thời gian ứng dụng ở nền không tính. Tổng thời lượng đã đo được và số log có thời lượng xuất hiện riêng trong Statistics; log cũ không có thời lượng không bị ước lượng.
- Đã có biểu đồ hoạt động theo ngày trong tuần hiện tại, kết hợp số buổi Drill/Timer và số trận bắt đầu; hiển thị ngày tập, ngày thi đấu và ngày có cả hai. Đây là xu hướng hoạt động, không phải đánh giá tác động của luyện tập lên kết quả trận.
- Đã có số trận đã ghi/hoàn tất và tổng trận thắng/thua từ các rack đã nhập; đây là thống kê tỷ số cơ bản, không phải phân tích chất lượng từng cú.
- Đã có tổng hợp số cú đã ghi, break, safety, trượt, phạm lỗi, scratch và tỷ lệ vị trí thành công từ dữ liệu người dùng nhập.
- **Còn thiếu:** phân tích chuỗi/chiến thuật trận. Thời lượng Drill chỉ được đo từ lúc mở màn ghi kết quả đến lúc lưu, không phải cảm biến hoạt động tập thực tế.

## 10. Profile

Trả lời câu hỏi "tôi là ai và tôi đã tiến bộ thế nào" (khác với Dashboard trả lời "hôm nay làm gì"):
- Rank, progress, training history, match history
- Achievements / Certifications
- **Equipment (Cơ bi-a)** — hồ sơ từng cây cơ: loại (cơ chính/break/jump), trọng lượng, kích thước & độ cứng tip, kỹ năng phù hợp, ngày bảo dưỡng tip gần nhất và ngày dự kiến bảo dưỡng tiếp *(chi tiết hóa mục Equipment từ bản PoolCoachAI gốc bằng toàn bộ chức năng quản lý cơ của Luyện Cơ)*.

**Trạng thái triển khai hiện tại**
- Đã có thêm/sửa/xóa hồ sơ cơ với loại, trọng lượng, đường kính/độ cứng tip, kỹ năng phù hợp và ngày bảo dưỡng do người chơi nhập.
- Đã có cảnh báo trực quan khi đến hạn hoặc còn tối đa 7 ngày tới hạn; danh sách ưu tiên cơ quá hạn và sắp đến hạn gần nhất.
- Người chơi có thể bật thông báo trình duyệt: nhắc lúc 09:00 ngày đến hạn và 7 ngày trước đó, chỉ khi ứng dụng đang mở; không gửi khi ứng dụng đã đóng và không thay thế thông báo đẩy.
- Có thể chọn cơ cho buổi tập tự do trong Đồng hồ. Nếu xóa cơ, buổi tập cũ vẫn được giữ nhưng bỏ liên kết tới cơ đã xóa.
- Trang Equipment hiển thị tổng thời gian tập tự do và ngày sử dụng gần nhất theo từng cây cơ, lấy từ các Timer session đã ghi.
- Hồ sơ cơ đồng bộ đa thiết bị qua Directus theo `user_created`; xóa mềm dùng tombstone để không tải hồ sơ đã xóa về lại. Dữ liệu cục bộ cô lập theo tài khoản (schema Drift v9) và được xóa khi người chơi chủ động đăng xuất. Cần chạy bootstrap Directus trên môi trường triển khai để tạo collection và quyền.
- Settings

## 11. Notifications

Smart Notifications — nhắc lịch tập đã đặt, nhắc bảo dưỡng cơ khi quá hạn, nhắc Coach recommendation mới, nhắc streak sắp bị ngắt.

## 12. Backend

Hoạt động trước với local data (giống cách Luyện Cơ lưu trên thiết bị), sau đó kết nối backend (Supabase: Authentication, Database, Sync, Cloud backup) để đồng bộ đa thiết bị và cung cấp dữ liệu cho Player Intelligence. Business logic và UI không phụ thuộc cứng vào backend implementation.

## 13. Sơ đồ module tổng thể

```
PoolCoachAI
│
├── AI Home
│   ├── AI Coach
│   ├── Today's Goals
│   ├── Continue
│   ├── Lịch hôm nay
│   ├── Progress rút gọn (streak, giờ tập)
│   └── Quick Actions
│
├── Training Center
│   ├── AI Learning Path
│   ├── All Drills (search/filter theo trình độ & kỹ năng)
│   ├── Drill Detail
│   ├── Recording Preparation
│   ├── Drill Session (Camera/Vision ↔ Ghi nhận thủ công)
│   ├── Mô phỏng góc cắt (Cut Angle Simulator)
│   ├── Đồng hồ & Lịch tập
│   ├── Knowledge
│   ├── Skill Test
│   └── Certification
│
├── Play
│   ├── Match Recording
│   ├── Match History
│   └── Competition / Tournament
│
├── Coach
│   ├── AI Chat
│   ├── Analysis
│   └── Recommendations
│
├── Statistics
│   └── Performance / Analytics (Training + Play)
│
├── Profile
│   ├── Player Profile & Rank
│   ├── Equipment (Cơ bi-a)
│   ├── History
│   └── Settings
│
└── Notifications
    └── Smart Notifications
```

## 14. Một câu mô tả PoolCoachAI

PoolCoachAI là nền tảng huấn luyện bida cá nhân hóa, kết hợp bộ công cụ luyện tập cụ thể (thư viện Drill, mô phỏng góc cắt, đồng hồ và lịch tập, quản lý cơ) với dữ liệu Assessment, Training và Match để xây dựng Player Intelligence — từ đó AI Coach đề xuất người chơi nên học và tập gì tiếp theo, trong khi người chơi vẫn luôn có quyền tự do khám phá Drill, Knowledge và các công cụ luyện tập theo cách của riêng mình.

**Nguyên tắc business duy nhất:** AI dẫn đường — người chơi vẫn là người quyết định mình học và tập gì.

---

### Ghi chú hợp nhất
- Các phần **in nghiêng có chú thích nguồn** ở trên là nội dung được đưa thêm từ Luyện Cơ, không có trong bản PoolCoachAI gốc: Mô phỏng góc cắt, Đồng hồ & Lịch tập, chi tiết quản lý Equipment/Cơ bi-a, taxonomy 5 kỹ năng cụ thể, và cách ghi nhận kết quả theo đơn vị linh hoạt (không chỉ đếm cú ✓/✗).
- Các phần chỉ có ở PoolCoachAI và được giữ nguyên: Onboarding/Assessment & hệ rank, AI Learning Path, Skill Test/Certification với progression gate, Camera/Vision, toàn bộ Play (Match Recording/History/Tournament), Coach Chat, Player Intelligence, Notifications, kiến trúc Backend/Supabase.
- Các phần trùng khái niệm đã được hợp nhất thành một mục duy nhất: Dashboard/AI Home, Drill Library, Knowledge, Statistics, Equipment.