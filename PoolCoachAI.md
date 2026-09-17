Dưới đây là bản mô tả sản phẩm PoolCoachAI cuối cùng, tôi tổng hợp theo những gì chúng ta đã chốt qua các lần trao đổi, ưu tiên các quyết định mới nhất và loại bỏ những ý tưởng V1 đã bị thay đổi.
PoolCoachAI — Product Description
1. Product Vision
Build the world's best billiards training app.
PoolCoachAI là ứng dụng hỗ trợ cơ thủ bida phát triển trình độ thông qua một vòng lặp:
Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp
AI đóng vai trò Coach, giúp người chơi biết nên học gì và nên tập gì tiếp theo, nhưng không khóa cứng cách người chơi học.
________________________________________
2. Triết lý sản phẩm
PoolCoachAI phân biệt rõ hai hoạt động:
TẬP
Là quá trình rèn luyện kỹ năng.
→ Tất cả nằm trong Training Center.
CHƠI
Là chơi trận / thi đấu thực tế.
→ Tất cả nằm trong Play.
Hai loại dữ liệu không trộn lẫn thành một loại session.
Chúng có thể được kết hợp ở tầng Statistics / Intelligence / Coach để đánh giá sự tiến bộ.
                 PoolOS
                    │
          ┌─────────┴─────────┐
          │                   │
       TRAINING             PLAY
          │                   │
       Drill              Match
       Knowledge          Recording
       Skill Test         History
          │                   │
          └─────────┬─────────┘
                    ↓
             Intelligence
                    ↓
                 Coach
                    ↓
              Recommendation
________________________________________
3. Người dùng mục tiêu
PoolOS phục vụ cơ thủ phong trào và người chơi muốn nâng trình.
Hệ thống phân hạng sử dụng cách hiểu hạng tại Hà Nội làm tham chiếu ban đầu.
Cách trình bày hạng
Các hạng thấp như:
K → I → H → G
được xem là nhóm người chơi nghiệp dư/phong trào.
F là bước đầu của nhóm người chơi bước vào sân chơi cạnh tranh, tiếp theo:
F → E → D → C → B → A → Professional
Đây là bảng định nghĩa của PoolOS, không phải một chuẩn xếp hạng quốc gia duy nhất.
App cần giải thích điều này để tránh tranh cãi vì cách gọi hạng có thể khác giữa các CLB, khu vực và cộng đồng.
“Chưa từng chơi” không được coi là một cấp độ để highlight như rank.
________________________________________
4. Onboarding & Skill Assessment
Mục tiêu của onboarding không phải bắt người dùng trả lời hàng chục câu hỏi.
PoolOS sử dụng 8 câu hỏi ngắn để ước lượng trình độ ban đầu.
Các nhóm thông tin chính:
1.	Đã chơi bao lâu?
2.	Tần suất chơi — giờ/ngày hoặc giờ/tuần.
3.	Một lượt cơ đi được nhiều nhất bao nhiêu bi?
4.	Một lượt cơ thông thường đi được bao nhiêu bi trong các tình huống cơ bản?
5.	Đã từng runout/chấm chưa?
6.	Nếu có, tần suất runout.
7.	Khả năng kiểm soát/cue-ball và các kỹ năng thực tế.
8.	Một câu hỏi bổ sung để phân biệt trình độ thực tế.
Điểm quan trọng:
Assessment chỉ là baseline ban đầu.
Không nên coi kết quả onboarding là “định mệnh” của người chơi.
Trình độ thực tế sẽ tiếp tục được điều chỉnh từ dữ liệu tập luyện và chơi trận.
________________________________________
5. AI Home — Dashboard
Dashboard là AI Home, không phải một menu tổng hợp.
Mục tiêu của màn hình:
“Hôm nay tôi nên làm gì?”
Dashboard tập trung vào:
•	AI Coach recommendation
•	Today's Goals
•	Continue
•	Progress
•	Quick Actions
•	thông tin quan trọng sau các buổi tập/trận
Ví dụ:
Today's Goal

Complete:
Position Recovery Lv2

Read:
Cue Ball Control

Next:
Skill Test Lv2
Người dùng có thể bấm trực tiếp vào goal để đi đến chức năng tương ứng.
Dashboard hiển thị kết luận và hành động tiếp theo, còn dữ liệu chi tiết nằm trong các module chuyên biệt.
________________________________________
6. Training Center
Training Center là trung tâm của PoolOS.
Bao gồm:
AI Learning Path
AI xây dựng lộ trình tập dựa trên:
•	trình độ
•	kỹ năng
•	điểm yếu
•	lịch sử tập
•	kết quả skill test
•	dữ liệu chơi trận
•	knowledge liên quan
Nhưng:
AI đề xuất, không khóa người dùng.
Người chơi có thể:
AI Learning Path
       ↓
Recommended Drill
hoặc bỏ qua và vào:
All Drills
       ↓
Search / Filter
       ↓
Chọn bài muốn tập
Người chơi hạng I vẫn có thể tự tìm và học một bài nhảy bi hoặc masse nếu họ muốn.
________________________________________
7. Drill Library
Drill là đơn vị thực hành chính.
Người chơi có thể:
•	xem danh sách bài tập
•	tìm kiếm
•	filter theo trình độ
•	chọn drill trực tiếp
•	hoặc nhận drill từ AI Coach.
Drill có Level
Một drill có thể được chia thành nhiều level.
Ví dụ:
Stop Shot

Level 1 — Easy
Level 2 — Medium
Level 3 — Hard
Level có progression gate.
Người chơi phải đạt yêu cầu của level hiện tại trước khi chuyển level tiếp theo.
Đây là cơ chế progression của một drill, không phải khóa toàn bộ Training Center.
________________________________________
8. Drill Recording
Flow chính thức:
Drill Detail
      ↓
Recording Preparation
      ↓
Drill Session
      ↓
Completion
Recording Preparation
Là màn hình chuẩn bị trước khi tập:
•	tên drill + level
•	mục tiêu
•	setup bàn/camera
•	checklist
•	xác nhận “Tôi đã sẵn sàng”
•	nút bắt đầu ghi
Chỉ sau khi xác nhận sẵn sàng mới bắt đầu Drill Session.
Drill Session
Là nơi người chơi thực hiện bài tập và ghi nhận kết quả.
Completion
Ghi nhận kết quả và cập nhật progress.
Trong mỗi Drill Session, hệ thống hỗ trợ 2 cách ghi nhận:
1.	Camera/Vision 
o	Nếu người chơi setup được camera và camera hoạt động → hệ thống tự động nhận diện kết quả cú đánh. 
o	Người chơi có thể xác nhận/chỉnh sửa kết quả nếu nhận diện sai. 
2.	Ghi nhận thủ công 
o	Nếu người chơi không setup được camera, không có camera hoặc không muốn sử dụng camera → vẫn có thể tập bình thường. 
o	Mỗi cú đánh có 2 nút rõ ràng: 
	✓ Thành công 
	✗ Thất bại 
o	Người chơi bấm sau mỗi cú đánh để ghi nhận kết quả. 
o	Hệ thống lưu kết quả từng cú đánh và dùng dữ liệu đó để tính: 
	tỷ lệ thành công 
	số cú thành công/thất bại 
	tiến bộ qua các buổi tập 
	mức độ hoàn thành Drill 
	dữ liệu đầu vào cho Player Intelligence / Coach AI. 
Business rule quan trọng:
Camera là phương thức tự động hóa việc ghi nhận, không phải điều kiện để người chơi được thực hiện hoặc hoàn thành bài tập.
Như vậy flow vẫn là:
Drill Detail → Recording Preparation → Drill Session → Completion
nhưng trong Drill Session có thể chọn:
Camera tự động ↔ Nút bấm thủ công
________________________________________
9. Knowledge
Knowledge là phần học lý thuyết, nhưng không được khóa chặt vào Drill.
Triết lý:
Học đi đôi với hành.
Một Drill có thể liên kết tới Knowledge để hướng dẫn:
•	kỹ thuật
•	cách thực hiện
•	lỗi thường gặp
•	nguyên lý
•	tình huống áp dụng
Đồng thời Knowledge cũng có thể liên kết ngược tới các Drill liên quan.
Knowledge
   ↕
Drill
Nhưng đây là mối quan hệ hỗ trợ, không phải dependency cứng.
Người dùng có quyền khám phá Knowledge độc lập.
________________________________________
10. Skill Test / Certification
Skill Test dùng để kiểm tra người chơi đã đạt yêu cầu của một level hay chưa.
Quan trọng:
Người chơi không được chỉ bấm “Hoàn thành Level 1” để mở Level 2.
Progression phải dựa trên kết quả thực hiện/đánh giá, không phải một nút xác nhận giả.
Certification thể hiện những level/kỹ năng mà người chơi đã đạt.
________________________________________
11. Play
Play là nơi dành cho Chơi thực tế.
Bao gồm:
•	Match Recording
•	Match History
•	Competition / Tournament
Đây là nơi ghi nhận trận đấu thực tế, khác hoàn toàn với Drill Session.
________________________________________
12. Match Recording
Match Recording ghi nhận dữ liệu của trận:
•	rack
•	shot
•	kết quả
•	lỗi
•	safety
•	scratch
•	break
•	position
•	các thống kê liên quan
Mục tiêu không chỉ là lưu:
thắng / thua
mà tạo ra dữ liệu đủ để PoolOS hiểu người chơi đã chơi như thế nào.
________________________________________
13. Match Intelligence
Dữ liệu Match Recording đi vào tầng phân tích:
Match Recording
      ↓
Match Statistics
      ↓
Player Intelligence
      ↓
Coach AI
Ví dụ AI có thể phát hiện:
•	easy miss
•	position error
•	break issue
•	safety
•	scratch
•	pattern weakness
•	các xu hướng lặp lại
Sau đó chuyển thành recommendation cho Training.
________________________________________
14. Coach
Coach là lớp AI đứng trên dữ liệu của người chơi.
Coach có:
Coach Chat
Người chơi có thể hỏi:
Hôm nay tôi nên tập gì?
Tại sao tôi thua trận vừa rồi?
Tôi đang yếu kỹ năng nào?
Nên tập bài nào?
Coach Recommendation
Coach không chỉ đưa lời khuyên chung chung.
Nó sử dụng:
•	Assessment
•	Drill history
•	Knowledge
•	Match history
•	Statistics
•	Player Intelligence
để tạo recommendation.
________________________________________
15. Vòng lặp quan trọng nhất của PoolOS
Đây là business loop cốt lõi:
             ┌──────────────┐
             │  Assessment  │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │ AI Learning  │
             │    Path      │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │    Drill     │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │   Knowledge  │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │    Play      │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │ Match Data   │
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │ Intelligence│
             └──────┬───────┘
                    ↓
             ┌──────────────┐
             │    Coach     │
             └──────┬───────┘
                    ↓
              Recommendation
                    ↓
                  Drill
Đây là điểm tạo khác biệt của PoolOS: không chỉ là thư viện bài tập, mà là hệ thống tạo vòng lặp cải thiện kỹ năng.
________________________________________
16. Profile
Profile là nơi người chơi xem thông tin cá nhân và lịch sử của mình.
Bao gồm:
•	rank
•	progress
•	training history
•	match history
•	achievements/certifications
•	equipment
•	settings
Profile không phải Dashboard.
Dashboard trả lời “hôm nay làm gì”.
Profile trả lời “tôi là ai và tôi đã tiến bộ thế nào”.
________________________________________
17. Statistics
Statistics là nơi xem dữ liệu chi tiết.
Dashboard chỉ đưa ra insight quan trọng.
Statistics mới hiển thị:
•	lịch sử
•	performance
•	match statistics
•	training statistics
•	trends
•	analytics
Đây cũng là nơi kết hợp dữ liệu Training và Play.
________________________________________
18. Backend
PoolCoachAI được xây theo hướng có thể hoạt động trước với local data và sau đó kết nối backend.
Backend dự kiến sử dụng:
•	Authentication
•	Database
•	Sync
•	Cloud backup
Supabase là backend mục tiêu.
Business logic và UI không nên phụ thuộc cứng vào backend implementation.
________________________________________
19. Các module chính
Bản sản phẩm cuối có thể mô tả ngắn gọn như sau:
PoolCoachAI
│
├── AI Home
│   ├── AI Coach
│   ├── Today's Goals
│   ├── Continue
│   ├── Progress
│   └── Quick Actions
│
├── Training Center
│   ├── AI Learning Path
│   ├── All Drills
│   ├── Drill Detail
│   ├── Recording Preparation
│   ├── Drill Session
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
│   └── Performance / Analytics
│
├── Profile
│   ├── Player Profile
│   ├── Equipment
│   ├── History
│   └── Settings
│
└── Notifications
    └── Smart Notifications
________________________________________
20. Một câu mô tả PoolCoachAI
Nếu cần mô tả cực ngắn cho tài liệu sản phẩm:
PoolCoachAI là nền tảng huấn luyện bida cá nhân hóa, sử dụng dữ liệu Assessment, Training và Match để xây dựng Player Intelligence, từ đó AI Coach đề xuất người chơi nên học và tập gì tiếp theo. Người chơi được AI dẫn dắt nhưng luôn có quyền tự do khám phá Drill và Knowledge.
Và nếu chỉ giữ một nguyên tắc business duy nhất, thì tôi sẽ giữ:
AI dẫn đường — người chơi vẫn là người quyết định mình học và tập gì.

