# TỔNG HỢP Ý TƯỞNG SẢN PHẨM POOLCOACHAI
**Phiên bản:** 0.2 — Hợp nhất ý tưởng 9-ball với định hướng và thiết kế PoolCoachAI  
**Mục đích:** Tài liệu nền duy nhất để theo dõi ý tưởng sản phẩm, phạm vi, quyết định còn mở và trạng thái triển khai. Đây là một sản phẩm; các tài liệu trước đây là những góc nhìn/phần phát triển khác nhau của cùng ứng dụng.

> **Cách đọc:** Các mục 1–12 giữ lại ý tưởng huấn luyện 9-ball ban đầu. Mục 13 trở đi hợp nhất chúng với các ý tưởng đã có trong PRD, prototype và thiết kế của PoolCoachAI. “Đã có trong dự án” không đồng nghĩa với “đã có trong ứng dụng”: trạng thái mã nguồn được ghi riêng ở mục 17.

---

## 1. Tóm tắt sản phẩm

Xây dựng một ứng dụng giúp người mới tập chơi pool tiến bộ theo lộ trình cá nhân, hướng tới khả năng **chạy rack 9-ball** (đi chấm) thông qua bài tập thực hành, đánh giá kết quả và điều chỉnh lộ trình.

Ứng dụng không nên chỉ là thư viện video hoặc khóa học tuyến tính. Giá trị cốt lõi là trả lời được:

> **Hôm nay người chơi cần tập gì, làm thế nào biết đã đạt, và nếu chưa đạt thì nên tập gì tiếp theo?**

### Nguyên tắc sản phẩm
- Thực hành trước, lý thuyết chỉ xuất hiện khi giúp sửa một lỗi cụ thể.
- Mỗi buổi có một nhiệm vụ chính, có thời lượng và tiêu chí đạt rõ ràng.
- Người dùng tự ghi nhận kết quả ở phiên bản đầu.
- Lộ trình thay đổi theo kết quả thực tế, không chỉ theo số ngày đã học.
- Khi người chơi trả lời sai trong bài tình huống, Coach không đưa đáp án ngay: đặt câu hỏi gợi mở để người chơi tự tìm lỗi.
- Chỉ giải thích đáp án sau khi người chơi đã thử ít nhất hai lần.
- Đánh giá khả năng chuyển kỹ năng vào bàn chơi thực tế, không chỉ dựa trên điểm bài tập đơn lẻ.

---

## 2. Người dùng mục tiêu và mục tiêu học tập

### Người dùng mục tiêu ban đầu
- Người mới hoàn toàn hoặc mới biết các kỹ năng cơ bản.
- Có thể biết một chút áp-phê nhưng thực hiện chưa ổn định.
- Muốn có lộ trình rõ ràng thay vì tự tìm video và tập ngẫu nhiên.
- Có thể tự nhập kết quả luyện tập.

### Mục tiêu người dùng
- **Mốc 3 tháng:** xây nền tảng và có thể chạy các hình đơn giản; mục tiêu cụ thể phải điều chỉnh theo thời lượng tập và kết quả đầu vào.
- **Mốc 6 tháng:** hướng tới khả năng chạy rack trong điều kiện phù hợp và chơi phong trào tốt hơn.
- **Mốc 9 tháng:** hướng tới độ ổn định cao hơn khi chạy rack và thi đấu.

**Lưu ý:** Đây là các mốc định hướng, không phải cam kết chắc chắn. Khả năng đạt mục tiêu phụ thuộc vào trình độ ban đầu, số giờ tập thực tế, chất lượng luyện tập, bàn/cơ/điều kiện chơi và mức độ khó của hình. App phải dùng dữ liệu thực tế để điều chỉnh dự báo.

---

## 3. Năm khu vực chức năng đề xuất cho phiên bản tối ưu

**Quan trọng:** Đây là năm nhóm chức năng được đề xuất trong bản tổng hợp 9-ball; chưa xác minh chúng có phải danh sách năm chức năng gốc hay không. Đây cũng không phải giới hạn số tab hay toàn bộ sơ đồ sản phẩm. Mục 13–15 bổ sung những module cùng sản phẩm đã được nghĩ tới trong PoolCoachAI.

### 3.1. Hồ sơ, đánh giá đầu vào và mục tiêu
- Ghi nhận kinh nghiệm, trình độ tự đánh giá và thời gian tập mỗi ngày/tuần.
- Chọn mục tiêu 3, 6 hoặc 9 tháng.
- Thực hiện bài kiểm tra đầu vào ngắn, tập trung vào kỹ năng thực tế.
- Ghi nhận thành tích hiện tại: số bi chạy liên tục tốt nhất, kết quả qua một số rack, lỗi thường gặp.
- Tạo đường cơ sở để so sánh tiến bộ về sau.

### 3.2. Lộ trình cá nhân thích ứng
- Chia thành các cấp năng lực, không chỉ chia theo ngày.
- Chỉ mở cấp tiếp theo khi đạt tiêu chuẩn đầu ra.
- Nếu chưa đạt, hệ thống giao bài củng cố dựa trên lỗi thường gặp.
- Cho phép lộ trình 3/6/9 tháng thay đổi theo tiến độ thật.
- Ước lượng mục tiêu có khả thi hay không dựa trên số giờ tập thực tế; không hứa chắc chắn kết quả.
- Cho phép đặt mục tiêu theo năng lực/hạng hoặc thời hạn (ví dụ 3, 6, 9 tháng hay ngày thi đấu); các bước và thời gian dự kiến phải tính từ dữ liệu thật, thiếu dữ liệu thì không đoán.

### 3.3. Bài tập hôm nay
- Mỗi ngày hiển thị một nhiệm vụ chính.
- Có thời lượng gợi ý, cách bố trí bi, số lượt, quy trình thực hiện.
- Có tiêu chí đạt định lượng và cách tự kiểm tra.
- Nêu rõ điều không nên làm trong buổi đó để tránh phân tán.
- Cho phép hoàn thành bằng cách tự nhập số lần thành công/thất bại.
- Lưu lịch sử luyện tập và kết quả.

### 3.4. Coach tình huống và sửa lỗi bằng câu hỏi
- Đưa người chơi vào một tình huống cụ thể trên bàn.
- Yêu cầu chọn cú đánh, đường bi cái hoặc chiến thuật.
- Nếu chọn sai, không hiện đáp án ngay; đặt câu hỏi để người chơi tự phân tích hậu quả.
- Cho người chơi thử lại. Chỉ tiết lộ đáp án và giải thích sau ít nhất hai lần thử.
- Phân biệt lỗi ngắm, lực, điểm chạm, áp-phê, đọc đường bi cái và lựa chọn thứ tự bi.
- Không khẳng định một cú đánh là tối ưu nếu dữ liệu hình/bàn chưa đủ để kết luận.

### 3.5. Theo dõi năng lực và kiểm tra chạy rack
- Theo dõi thành tích theo thời gian: best run, số bi chạy liên tục, số rack hoàn tất, số bi trung bình mỗi rack.
- Theo dõi kỹ năng liên quan như ngắm, kiểm soát lực, stop/follow/draw, position play, pattern play và áp-phê.
- Không cho người dùng tăng cấp chỉ vì điểm bài tập riêng lẻ cao; cần kiểm tra chuyển giao sang tình huống tổng hợp.
- Có bài kiểm tra định kỳ và báo cáo tiến bộ.
- Đề xuất bài tiếp theo dựa trên điểm nghẽn lớn nhất hiện tại.

---

## 4. Vòng lặp huấn luyện cốt lõi

```text
Đánh giá đầu vào
      ↓
Xác định mục tiêu và thời gian tập
      ↓
Chọn năng lực cần cải thiện nhất
      ↓
Giao một nhiệm vụ chính
      ↓
Người chơi tập và tự nhập kết quả
      ↓
Đánh giá đạt / chưa đạt
      ↓
Nếu sai: Coach đặt câu hỏi gợi mở
      ↓
Người chơi thử lại ít nhất hai lần
      ↓
Giải thích khi đủ số lần thử
      ↓
Cập nhật hồ sơ năng lực
      ↓
Đạt chuẩn? ── Có → mở bài/cấp tiếp theo
      │
      └── Chưa → giao bài củng cố
```

---

## 5. Khung cấp độ năng lực đề xuất

Các cấp dưới đây là khung ban đầu; ngưỡng đạt phải được thử nghiệm với người chơi thật và điều chỉnh, không nên xem các con số sơ bộ là chuẩn khoa học.

1. **Nền tảng cú đánh:** tư thế, cầu tay, đưa cơ thẳng, ngắm và đánh bi mục tiêu.
2. **Kiểm soát bi cái cơ bản:** điều khiển lực; stop, follow, draw ở các khoảng cách phù hợp.
3. **Chạy 3–5 bi:** chọn bi tiếp theo và đưa bi cái về vùng thuận lợi.
4. **Chạy 6–7 bi:** lập kế hoạch nhiều cú, kiểm soát vị trí và xử lý hình trung bình.
5. **Chạy rack 9-ball:** áp dụng kỹ năng trong hình 9-ball, bao gồm luật chơi và tình huống sau break.
6. **Ổn định và thi đấu:** chạy rack lặp lại, ra quyết định dưới áp lực, học safety và chiến thuật phù hợp.

Không yêu cầu người dùng học áp-phê ngang, jump, masse hoặc kỹ thuật nâng cao quá sớm nếu chưa cần cho mục tiêu hiện tại.

---

## 6. Thiết kế một buổi học

Một buổi có thể mặc định 45 phút, nhưng phải cho người dùng chọn thời lượng thực tế.

### Ví dụ cấu trúc 45 phút
- 5 phút: chuẩn bị bàn và bố trí bi.
- 35 phút: thực hiện nhiệm vụ chính.
- 5 phút: tự nhập kết quả và nhận phản hồi.

### Mẫu hiển thị nhiệm vụ
- **Mục tiêu:** kiểm soát bi cái sau khi ăn bi mục tiêu.
- **Nhiệm vụ:** thực hiện một bài được mô tả bằng hình bố trí bi và hướng dẫn ngắn.
- **Kết quả cần nhập:** số lần thành công / tổng số lần.
- **Tiêu chí đạt:** một ngưỡng cụ thể đã được kiểm chứng hoặc cấu hình cho bài tập.
- **Nếu chưa đạt:** bài củng cố hoặc câu hỏi chẩn đoán.
- **Không làm hôm nay:** những kỹ thuật không liên quan đến mục tiêu buổi tập.

Không nên sử dụng một tiêu chuẩn chung cho mọi người hoặc tuyên bố rằng một bài tập đơn lẻ bảo đảm người chơi sẽ đi chấm sau một khoảng thời gian cố định.

---

## 7. Dữ liệu và chỉ số cần ghi nhận

### Dữ liệu phiên tập
- Ngày giờ, thời lượng thực tế.
- Bài tập và cấp năng lực.
- Số lượt thực hiện.
- Số lần thành công.
- Ghi chú lỗi do người dùng tự chọn.
- Mức độ khó cảm nhận (tùy chọn).

### Dữ liệu chạy rack
- Số rack đã chơi.
- Số bi chạy được trong từng rack.
- Số bi chạy liên tục tốt nhất.
- Số rack hoàn tất.
- Kết quả sau break và các lỗi chính nếu người chơi có ghi nhận.
- Bối cảnh: tập bài, rack đặt sẵn hay rack ngẫu nhiên/thi đấu.

### Chỉ số chính
- **Best run:** số bi chạy liên tục tốt nhất.
- **Average balls per rack:** số bi trung bình mỗi rack.
- **Rack completion rate:** tỷ lệ rack chạy hết.
- **Practice consistency:** số buổi tập hoàn thành so với kế hoạch.
- **Skill transfer:** mức độ kỹ năng bài tập thể hiện trong rack tổng hợp.

Cần ghi rõ điều kiện đo để tránh so sánh kết quả không tương đương.

---

## 8. MVP — nên làm trước

### Bắt buộc
- Hồ sơ người dùng và mục tiêu.
- Bài đánh giá đầu vào.
- Lộ trình theo cấp năng lực.
- Bài tập hôm nay với hướng dẫn và tiêu chí đạt.
- Tự nhập kết quả.
- Lịch sử tập luyện.
- Theo dõi best run và kết quả rack.
- Logic đạt/chưa đạt để chọn bài tiếp theo.
- Coach tình huống theo dạng câu hỏi nhiều bước.

### Chưa cần trong MVP
- Mạng xã hội và cộng đồng.
- Bảng xếp hạng công khai.
- Hệ thống huy hiệu phức tạp.
- Thư viện video khổng lồ.
- Phân tích kỹ thuật tự động bằng camera nếu chưa kiểm chứng được độ chính xác.
- Các kỹ thuật nâng cao không phục vụ mục tiêu chạy rack ở giai đoạn đầu.

---

## 9. Rủi ro sản phẩm cần xử lý

1. **Tự nhập kết quả có thể thiếu chính xác:** cho phép ghi nhận dễ dàng, giữ lịch sử và dùng bài kiểm tra chuẩn định kỳ.
2. **Không thể đảm bảo người chơi tự đánh giá đúng:** cần hướng dẫn bố trí bài rõ ràng, câu hỏi xác minh và các bài kiểm tra tổng hợp.
3. **Mục tiêu thời gian quá lạc quan:** dự báo phải dựa trên trình độ đầu vào và thời lượng tập; hiển thị là mục tiêu, không phải cam kết.
4. **Điểm kỹ năng không có cơ sở:** không tự tạo điểm 0–100 nếu chưa có quy tắc đo và dữ liệu hiệu chuẩn.
5. **Bài tập tốt nhưng không chuyển sang chơi thật:** cần kiểm tra bằng rack tổng hợp và tình huống thực chiến.
6. **Coach đưa đáp án quá sớm:** lưu số lần thử và chỉ tiết lộ đáp án sau ít nhất hai lần thử theo yêu cầu sản phẩm.
7. **Giáo trình tuyến tính:** lộ trình phải quay lại củng cố kỹ năng yếu, không ép người dùng đi tiếp theo lịch.

---

## 10. Quy tắc thiết kế nội dung huấn luyện

Mỗi bài tập phải có:
- Mục tiêu năng lực duy nhất.
- Cách bố trí bi đủ rõ để tái tạo.
- Các bước thực hiện ngắn gọn.
- Số lượt hoặc thời lượng.
- Định nghĩa thành công có thể quan sát.
- Tiêu chí đạt/chưa đạt.
- Lỗi thường gặp và câu hỏi gợi mở.
- Quy tắc chọn bài tiếp theo.
- Mức độ khó và điều kiện để tăng độ khó.

Không đưa vào bài tập nếu không giải thích được bài đó đóng góp thế nào cho khả năng chạy rack 9-ball.

---

## 11. Những điểm cần chốt trước khi viết PRD chính thức

1. Nếu còn bản ghi danh sách **năm chức năng gốc**, đối chiếu với Mục 3; danh sách hiện tại là đề xuất tổng hợp, chưa được xác nhận là danh sách nguyên bản.
2. Chốt nền tảng: mobile app, web app hay cả hai.
3. Chốt phiên bản đầu chỉ hỗ trợ 9-ball hay có kế hoạch mở rộng sang 8-ball.
4. Chốt thời lượng buổi tập mặc định và các lựa chọn thời lượng.
5. Chốt phương pháp kiểm tra đầu vào và ngưỡng đạt qua thử nghiệm thực tế.
6. Chốt cách thể hiện bài bố trí bi: sơ đồ 2D, hình minh họa hay video.
7. Chốt mức độ sử dụng AI: phản hồi theo kịch bản cố định trước, hay tạo câu hỏi động.
8. Xác định cách kiểm chứng tiến bộ khi người dùng tự nhập kết quả.

---

## 12. Định hướng kết luận

Sản phẩm nên được phát triển như một **hệ thống huấn luyện thích ứng**, không chỉ là ứng dụng cung cấp nội dung.

Giá trị cốt lõi:
- Biết người chơi đang ở đâu.
- Biết năng lực nào đang cản trở tiến bộ.
- Giao đúng một nhiệm vụ có thể thực hiện.
- Đo kết quả.
- Dùng câu hỏi giúp người chơi tự phát hiện lỗi.
- Chọn bài tiếp theo dựa trên bằng chứng.
- Đánh giá cuối cùng bằng khả năng chơi rack thực tế.

**Bước tiếp theo:** đối chiếu danh sách năm chức năng gốc nếu tìm lại được, sau đó chuyển tài liệu này thành PRD có user flow, data model, logic chọn bài, acceptance criteria và backlog MVP.

---

## 13. Bức tranh sản phẩm đã hợp nhất

PoolCoachAI là **một ứng dụng huấn luyện bida cá nhân hóa**, trong đó ý tưởng 9-ball là mục tiêu học tập trọng tâm ban đầu, còn các công cụ, đánh giá và hệ thống sản phẩm đã có trong PoolCoachAI là những phần bổ sung của cùng một ứng dụng — không phải sản phẩm khác.

Vòng lặp thống nhất:

**Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp**

- **Tập** là luyện kỹ năng có kiểm soát qua bài tập, bài kiểm tra và buổi tập tự do.
- **Chơi** là chơi rack/trận thực tế và ghi nhận diễn biến. Dữ liệu chơi không bị nhập chung với log bài tập.
- **Intelligence** kết hợp các nguồn để nhận diện tiến bộ và điểm nghẽn.
- **Coach** giúp diễn giải, gợi mở và đề xuất; người chơi vẫn được tự chọn bài, tự mở công cụ và bỏ qua gợi ý.

### Các khu vực/module thống nhất

1. **AI Home:** việc chính nên làm hôm nay, mục tiêu hỗ trợ, tiếp tục việc đang dở, lịch hôm nay, streak/giờ tập, hoạt động gần nhất và lối tắt tới bài tập/công cụ. Chỉ nên có một nhiệm vụ tập trung chính; các mục còn lại là hỗ trợ, không biến trang chủ thành danh sách bắt buộc.
2. **Training Center:** lộ trình cá nhân; thư viện bài tập có tìm kiếm/lọc; hướng dẫn và ghi kết quả; bài kiểm tra kỹ năng/chứng nhận; bài kiến thức; mô phỏng góc cắt; kế hoạch dọn bàn; đồng hồ và lịch tập tự do.
3. **Play:** ghi trận/rack, lịch sử trận và về sau là thi đấu/giải. Đây là nguồn đo khả năng áp dụng kỹ năng vào chơi thật.
4. **Statistics & Player Intelligence:** lịch sử và phân tích riêng cho tập/chơi, đồng thời có chỉ số tổng hợp khi so sánh được điều kiện đo.
5. **Coach & Recommendations:** gợi ý theo dữ liệu, giải thích điểm yếu và coach tình huống nhiều bước.
6. **Profile:** hồ sơ, hạng và nguồn hạng, lịch sử đánh giá, mục tiêu, chứng nhận, thiết bị/cơ và cài đặt.
7. **Notifications:** nhắc lịch, bảo dưỡng cơ, gợi ý mới hoặc streak sắp đứt — chỉ gửi khi có dữ liệu/sự kiện thật.

Các nhóm trên là sơ đồ năng lực sản phẩm, không bắt buộc phải trở thành bảy tab. Điều hướng hiện được thiết kế với năm tab chính; Coach và Notifications có thể là màn riêng.

---

## 14. Ý tưởng PoolCoachAI bổ sung vào bản 9-ball

Các phần sau không được mô tả đầy đủ trong bản ý tưởng 9-ball ban đầu, nhưng thuộc cùng sản phẩm và cần giữ lại:

### 14.1. Đánh giá đầu vào, hạng và kiểm tra kỹ năng là ba khái niệm liên quan nhưng khác nhau

- **Đánh giá đầu vào/hạng:** câu hỏi tự đánh giá cho hạng ước lượng hoặc tự khai; bài kiểm tra Billiard University (BU) có thể tạo hạng đã kiểm chứng. Luôn lưu nguồn hạng; kết quả luyện tập thông thường không tự đổi hoặc hạ hạng.
- **Skill Test/chứng nhận:** đo một kỹ năng hoặc cấp độ bài tập cụ thể, dùng làm bằng chứng tiến bộ và có thể mở cấp tiếp theo.
- **Kiểm tra chạy rack:** đánh giá chuyển giao kỹ năng vào tình huống tổng hợp/trận thực tế; không thể thay bằng điểm một bài tập hoặc hạng BU.

Không gộp ba loại đánh giá thành một điểm duy nhất. Các lần kiểm tra phải lưu điều kiện đo, ngày, kết quả và nguồn.

### 14.2. Drill Library và cách ghi nhận kết quả

- Mỗi bài có mục tiêu, nhóm kỹ năng, cấp độ, cách bày bi có thể lặp lại, các bước, số lượt/thời lượng, tiêu chí đạt và cách tự kiểm tra.
- Một bài có thể có nhiều level. Cổng đạt chỉ điều khiển tiến trình **trong bài/nhánh kỹ năng**, không khóa người chơi khỏi toàn bộ thư viện.
- Hướng dẫn Drill có thể liên kết bài Knowledge; người dùng vẫn được đọc Knowledge độc lập.
- Hỗ trợ cả ghi từng cú thành công/thất bại và nhập kết quả tổng/đơn vị đo phù hợp (ví dụ số lần, khoảng cách, thời gian). Camera là tùy chọn hỗ trợ ghi nhận, không phải điều kiện để tập.
- Lịch sử cần phân biệt bài chưa từng tập, kết quả không chấm được và kết quả có thể so sánh.

### 14.3. Công cụ tập và chơi có thể dùng độc lập với AI

- **Mô phỏng góc cắt:** đặt bi cái/bi mục tiêu/lỗ; hiển thị bi ảo, góc, độ khó và đường đi minh họa của bi cái; có thể giúp luyện ngắm nhưng vẫn mở độc lập.
- **Kế hoạch dọn bàn (Run-out Planner):** bố trí bàn và nhận kế hoạch đánh từng bước; hỗ trợ 9-ball, 10-ball và luật 8-ball theo thiết kế Planner. Người chơi có thể cập nhật vị trí bi cái thực tế sau mỗi cú để tính tiếp. Đây là công cụ mô phỏng/kế hoạch, không thay thế ghi nhận trận thật.
- **Đồng hồ tập tự do:** ghi thời lượng thực tế, nhóm kỹ năng và cây cơ (nếu có); tính vào lịch sử giờ tập/streak nhưng không tự gán kết quả đạt/trượt của Drill.
- **Lịch tập tuần:** người dùng tự tạo các khung giờ; Home và Coach có thể dùng lịch để đề xuất phù hợp.
- **Thiết bị/cơ:** lưu nhiều cây cơ, loại cơ, thông số người dùng nhập, kỹ năng sử dụng và lịch sử/ngày bảo dưỡng đầu cơ; nhắc bảo dưỡng chỉ khi quá hạn theo quy tắc đã định.

### 14.4. Play, phân tích và hệ sinh thái

- Ghi nhận trận/rack cần tách biệt với Drill Session, có thể lưu kết quả từng rack và các sự kiện người dùng ghi nhận (break, số bi chạy, lỗi, scratch, safety, vị trí).
- Thống kê cần nói rõ mẫu số và bối cảnh: rack đặt sẵn hay ngẫu nhiên/thi đấu, số rack, điều kiện bàn và nguồn nhập.
- Notifications, đồng bộ tài khoản/đa thiết bị, sao lưu và backend là các phần của sản phẩm; app cần hoạt động với dữ liệu cục bộ khi offline.
- Camera/Vision, mạng xã hội, bảng xếp hạng và phân tích thi đấu nâng cao là hướng mở rộng, không phải điều kiện để MVP huấn luyện hoạt động.

---

## 15. Quy ước hợp nhất để tránh ý tưởng mâu thuẫn

Đây là cách hiểu thống nhất cho tài liệu và các lần cập nhật tiếp theo:

1. **Định hướng môn chơi:** MVP tập trung huấn luyện 9-ball và mục tiêu chạy rack 9-ball; không xóa khả năng mở rộng. Planner có thể hỗ trợ 8-ball/10-ball như công cụ riêng theo thiết kế hiện có. Chưa coi việc hỗ trợ nhiều luật là cam kết cho mọi module.
2. **Taxonomy chính thức có sáu nhóm:** Ngắm bi, Điều bi/Vị trí, Phá, Phòng thủ, A băng (kick), Cân bi (bank). Một tài liệu cũ ghi năm nhóm hoặc “Bi băng”; nội dung đó được thay bằng sáu nhóm này để không gộp nhầm kick với bank.
3. **Hạng không đồng nghĩa với năng lực từng kỹ năng:** hạng là hồ sơ trình độ tổng thể có nguồn; mastery/drill level là năng lực theo kỹ năng; kết quả rack là khả năng áp dụng. Không suy một loại từ loại còn lại nếu chưa có quy tắc kiểm chứng.
4. **AI gợi ý, người chơi quyết định:** Learning Path/Recommendation ưu tiên luật xác định, kiểm thử được và có lý do. Cổng hạng/cấp không giao cho LLM quyết định. LLM Coach (nếu triển khai) chỉ diễn giải dữ liệu đã tính và đặt câu hỏi; không bịa số, không tự thay thế đánh giá chuyên môn.
5. **Tập trung nhưng không ép:** Home có thể nêu một việc chính trong ngày; người dùng vẫn được tự chọn bài, xem kiến thức, tập tự do và mở công cụ bất cứ lúc nào.
6. **Đạt cấp phải có bằng chứng:** kết quả bài tập có thể cho biết đã sẵn sàng, nhưng yêu cầu kiểm tra/chứng nhận cụ thể cần được chốt; không mở cấp chỉ vì bấm nút hoàn thành.
7. **Không cam kết mốc tiến bộ:** mục tiêu 3/6/9 tháng hoặc ngày thi đấu là mục tiêu cá nhân, dự báo phải dựa trên dữ liệu; hiển thị thiếu dữ liệu khi không đủ căn cứ.
8. **Chuẩn hóa thuật ngữ:** dùng tên tiếng Việt đã chốt trong dự án (Đánh đứng bi, Đánh trô bi, Đánh cu lê, bi ảo, chết cái, A băng, Cân bi). Các tên tiếng Anh có thể để trong tài liệu kỹ thuật, nhưng không thay thế nhãn tiếng Việt trong giao diện.

---

## 16. Phạm vi phát triển theo giai đoạn

### MVP huấn luyện khả dụng

- Hồ sơ, onboarding, đánh giá đầu vào/hạng với nhãn nguồn.
- Thư viện Drill, hướng dẫn, ghi kết quả thủ công và lịch sử.
- Bài kiến thức có liên kết tùy chọn tới Drill.
- Player Intelligence và gợi ý hôm nay có thể giải thích, dựa trên dữ liệu thật.
- Một nhiệm vụ chính/ngày, nhưng cho phép tự chọn bài và luyện tự do.
- Mô phỏng góc cắt và kế hoạch dọn bàn như công cụ độc lập.
- Lưu cục bộ, xử lý trạng thái thiếu dữ liệu và lỗi rõ ràng.

### Giai đoạn tiếp theo

- Lộ trình mục tiêu cá nhân (kỹ năng/hạng/thời hạn), Skill Test và chứng nhận theo tiêu chí đã xác nhận.
- Đồng hồ tập, lịch tuần, giờ tập/streak và tích hợp vào gợi ý.
- Equipment/cơ và nhắc bảo dưỡng.
- Coach Chat/tình huống nhiều lượt theo quy tắc an toàn, có giải thích từ dữ liệu.
- Đồng bộ tài khoản/đa thiết bị và xử lý xung đột dữ liệu.

### Mở rộng sau khi kiểm chứng

- Ghi trận/rack chi tiết, thống kê tổng hợp Training + Play, kiểm tra chạy rack.
- Camera/Vision có bước người chơi xác nhận/sửa kết quả.
- Thi đấu/giải, thông báo thông minh, hỗ trợ luật/bộ môn khác.

Thứ tự trên là cách nhóm ý tưởng để triển khai, không phải khẳng định tất cả đã được chủ sản phẩm chốt về ưu tiên hoặc mốc thời gian.

---

## 17. Đối chiếu với dự án hiện tại

Trạng thái dưới đây là **ảnh chụp mã nguồn và tài liệu trong repository tại ngày 27/10/2026**, không phải cam kết sản phẩm. “Đã có” nghĩa là có một phần triển khai; không mặc nhiên có đủ mọi yêu cầu mô tả ở trên.

| Khu vực | Tình trạng dự án | Khoảng cách đáng chú ý |
|---|---|---|
| Nền tảng/điều hướng | Flutter, giao diện tiếng Việt, năm tab chính; web build tồn tại | Android/iOS và trải nghiệm thực tế cần tiếp tục kiểm tra trên thiết bị |
| Đánh giá/hạng | Có onboarding, câu hỏi, bài kiểm tra BU, lịch sử và đồng bộ hạng | Cần đối chiếu nghiệp vụ/UX khi mở rộng mục tiêu và kiểm tra kỹ năng |
| Training/Drill | Có thư viện seed, lọc sáu nhóm, chi tiết bài, ghi kết quả thủ công/lịch sử; chi tiết bài hiển thị chuỗi buổi đạt gần nhất | Chưa có luồng camera và Recording Preparation; chưa có Skill Test/chứng nhận riêng hoặc tự mở level (tiêu chí cần chốt) |
| Knowledge | Có nội dung seed, trang đọc và liên kết Drill | Có thể mở rộng bộ nội dung và cách tìm/lọc |
| Intelligence/Home | Có tính toán xác định cho năng lực/gợi ý; Home hiện lịch hôm nay, streak, thời lượng tập tuần và bước Lộ trình | Tiếp tục kiểm chứng trên thiết bị thật; không suy rộng từ dữ liệu tập luyện sang kết luận trận đấu |
| Mô phỏng góc cắt | Có màn và lõi hình học/vật lý | Cần tiếp tục kiểm chứng độ chính xác thực tế; đây là mô phỏng, không phải camera/physics đầy đủ |
| Kế hoạch dọn bàn | Có lõi Planner và màn nhập bàn/từng bước | Cần phân biệt rõ kết quả Planner với dữ liệu trận/rack thực tế |
| Coach tình huống/Chat | Có Coach tình huống và Hỏi huấn luyện viên; câu trả lời chat qua dịch vụ trung gian, được lọc theo dữ liệu người chơi | Chat không phân tích tình huống bàn bi; cần triển khai/vận hành dịch vụ theo runbook trước khi xác nhận khả dụng trên production |
| Lộ trình cá nhân | Có giao diện đặt mục tiêu (lên hạng, thuần thục kỹ năng, chuẩn bị giải), suy ra các bước từ dữ liệu thật và đồng bộ mục tiêu/thành tích | Ngày dự kiến chỉ hiện khi đủ dữ liệu; tiếp tục kiểm chứng với người chơi thật |
| Đồng hồ/lịch tập | Có màn hình, repository lưu cục bộ và đồng bộ; lịch hôm nay ảnh hưởng gợi ý, buổi đồng hồ tính vào streak và tổng thời lượng tuần | Tiếp tục kiểm chứng hành vi offline và đồng bộ trên nhiều thiết bị |
| Play/ghi trận/rack | Có ghi trận, kết quả từng rack, ghi nhận cú đánh thủ công, sửa thông tin trận và xóa trận có xác nhận; trận đồng bộ theo tài khoản, trận đã xóa được đánh dấu và đồng bộ để không hiện lại | Chưa có giải đấu hay Camera/Vision; cần phân biệt dữ liệu người chơi tự ghi với kết quả được xác minh tự động |
| Statistics | Có tổng hợp buổi tập, thời lượng Drill/Timer, streak, kết quả trận, chỉ số cú đánh/điều bi và biểu đồ số buổi tập/trận theo ngày trong tuần hiện tại | Thời lượng Drill là thời gian màn ghi kết quả mở (không tính app ở nền), không phải đo hoạt động thực tế; không coi hoạt động cùng ngày là quan hệ nhân quả hay đánh giá chạy rack |
| Equipment/cơ | Có quản lý thông tin cơ, lịch bảo dưỡng, nhắc bảo dưỡng và đồng bộ | Tiếp tục kiểm chứng thông báo trên từng nền tảng |
| Notifications | Có màn hình và thiết lập thông báo; hỗ trợ nhắc bảo dưỡng cục bộ | Chưa có thông báo thông minh cho recommendation hoặc streak |
| Tài khoản/đồng bộ | Có auth, lưu cục bộ và đồng bộ một số dữ liệu | Cần tiếp tục mở rộng các loại dữ liệu cần đồng bộ; ứng dụng cần giữ trải nghiệm offline |
| Vision/AI | Có nguyên tắc kiến trúc và hướng thiết kế | Chưa triển khai; cần chốt tiêu chuẩn độ chính xác và bước người chơi xác nhận/sửa trước khi ảnh hưởng dữ liệu đánh giá |

Nguồn đối chiếu chính: `README.md`, `PRD_PoolCoachAI.md`, tài liệu thiết kế trong `docs/superpowers/specs/`, cùng mã trong `lib/`. Khi trạng thái mã thay đổi, cập nhật bảng này thay vì biến trạng thái triển khai thành yêu cầu sản phẩm.

---

## 18. Những câu hỏi còn cần chốt

Các câu hỏi này không làm mất ý tưởng; chúng đánh dấu điểm chưa đủ thông tin để biến thành tiêu chí nghiệm thu:

1. MVP chính thức tập trung 9-ball tới mức nào? Có cần ghi nhận rack đặt sẵn/ngẫu nhiên ngay từ đầu không?
2. Mục tiêu 3/6/9 tháng là lộ trình cố định, hay người dùng chọn kỹ năng/hạng/ngày thi đấu và ứng dụng chỉ ước lượng thời gian?
3. Phương pháp đánh giá chạy rack nào đủ lặp lại và công bằng để dùng làm chỉ số tiến bộ?
4. Cấp Drill mở bằng chuỗi kết quả, Skill Test riêng hay cần cả hai? Ngưỡng nào được kiểm chứng với người chơi thật?
5. Mỗi buổi tập mặc định bao lâu; cách nhập kết quả nào áp dụng cho từng bài?
6. Bố trí bài và tình huống Coach sẽ dùng sơ đồ 2D, hình hay video?
7. Coach tình huống cần bao nhiêu lượt gợi mở trước khi tiết lộ đáp án, và có ngoại lệ nào?
8. Mốc bảo dưỡng cơ lấy từ chu kỳ do người dùng đặt, hướng dẫn nhà sản xuất hay lựa chọn khác?
9. Phạm vi đồng bộ/offline và cách xử lý khi hai thiết bị cùng sửa một dữ liệu cần được chốt theo từng loại dữ liệu.
10. Khi nào triển khai Camera/Vision, và tiêu chuẩn độ chính xác nào cần đạt trước khi cho phép kết quả tự động ảnh hưởng tới đánh giá?

---

## 19. Kết luận thống nhất

Không cần chọn giữa “ý tưởng 9-ball” và “PoolCoachAI”: đây là **một sản phẩm**. Ý tưởng 9-ball bổ sung mục tiêu huấn luyện rõ ràng, vòng lặp bài tập–phản hồi–chạy rack và Coach tình huống; PoolCoachAI bổ sung nền tảng hạng/đánh giá, hệ thống bài tập/kiến thức, Intelligence, mô phỏng, Planner, lịch/đồng hồ, thiết bị, chơi trận, thống kê và đồng bộ.

Tài liệu này giữ cả hai nhóm ý tưởng nhưng tách bạch:
- **Sản phẩm muốn có gì:** mục 1–16, với các quy ước thống nhất ở mục 15.
- **Dự án đã có gì:** mục 17.
- **Cần hỏi/chốt gì trước khi biến thành tiêu chí cuối:** mục 18.

Khi cập nhật về sau, nên dùng tài liệu này làm bản tổng hợp ý tưởng; PRD và specs tiếp tục là tài liệu chi tiết cho quyết định/triển khai từng module.
