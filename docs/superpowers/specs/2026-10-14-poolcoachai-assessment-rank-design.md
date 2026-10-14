# PoolCoachAI — Thiết kế Đánh giá + hạng

Ngày: 2026-10-14
Trạng thái: chủ sản phẩm đã duyệt từng phần thiết kế trong chat (14/10/2026). Bản viết này đang chờ chủ sản phẩm duyệt, sau đó mới lập kế hoạch triển khai.
Thứ tự xây: Kế hoạch dọn bàn (xong, đã lên `main` và deploy) → **Đánh giá + hạng (tài liệu này)** → Lộ trình (spec `2026-10-06-poolcoachai-roadmap-design.md` phải viết lại sau khi phần này xong).

## 1. Mục tiêu

Hạng có hai vai trò:

1. Cho người chơi biết mình đang ở trình nào, theo thang quen thuộc ở quán và giải Việt Nam.
2. Làm **mục tiêu "lên hạng"** cho Lộ trình bám theo.

Thành công nghĩa là:

- Người chơi mới có hạng gợi ý sau vài phút trả lời câu hỏi.
- Người chơi làm bài kiểm tra Billiard University (BU) trên bàn thật thì có **hạng đã kiểm chứng**. Mốc điểm nào cũng truy được về bảng BU đã công bố.
- Không con số nào do app tự bịa: ngưỡng, mốc và nội dung đều có nguồn, hoặc do chủ sản phẩm cung cấp hay duyệt.

## 2. Hiện trạng mã (đối chiếu `main` 0d62e0c, 14/10/2026)

| Thứ | Thực tế |
|---|---|
| Thang hạng | `lib/domain/rank.dart:18`: `k,i,h,g` (nhóm phong trào), `f,e,d,c,b,a` (nhóm thi đấu), `pro`; có `RankGroup`. Chú thích nói đây là "bảng riêng của PoolCoachAI dựa trên cách hiểu ở Hà Nội", màn nào hiện hạng cũng phải kèm câu miễn trừ đó |
| Huy hiệu | `lib/core/widgets/pc_rank_badge.dart` (`PcRankBadge`) đã có test nhưng chưa màn nào dùng |
| Đánh giá / onboarding | Chưa có. Không có `AssessmentResult`, không có route `/assessment`, người chơi chưa có trường hạng |
| Trận đấu | Chưa có. `PlayScreen` mới là trang giữ chỗ |
| Player Intelligence | Chỉ dùng bài tập + `DrillLog`. Có `weak`, `strong`, `readyDrillIds` (xét theo từng bài) |
| LLM | Chưa có. README và shell-design cấm dùng LLM để quyết định hạng hay cổng lên cấp |
| Drift | schemaVersion 2. Nhật ký bài tập đồng bộ Directus theo `userId` (`sync_service.dart`) |
| Hồ sơ | `ProfileScreen` hiện là `PcEmptyState` cùng nút đăng xuất |

## 3. Quyết định đã chốt

| # | Quyết định |
|---|---|
| Q1 | Hạng vừa giúp người chơi tự biết trình mình, vừa là mục tiêu cho Lộ trình |
| Q2 | Thang từ thấp đến cao: **K < I < H < G < F < E < D < C < B < A < PRO** (đúng enum hiện có) |
| Q3 | **PRO chỉ có khi tự khai** lúc làm bộ câu hỏi, luôn kèm nhãn "tự khai". Bài kiểm tra BU không bao giờ cho ra PRO |
| Q4 | Onboarding: bộ câu hỏi gợi ý một hạng, người chơi xác nhận hoặc tự chọn hạng khác |
| Q5 | Lên hạng qua bài kiểm tra. App **không bao giờ tự hạ hạng** |
| Q6 | Bài kiểm tra dựa trên **đề BU** (Dr. Dave Alciatore và Bob Jewett), quy đổi điểm BU sang hạng |
| Q7 | Hạng và kết quả kiểm tra lưu trên máy và **đồng bộ theo tài khoản** |
| Q8 | App **tự vẽ sơ đồ xếp bi BU** trên mặt bàn trong app. Chủ sản phẩm chấp nhận rủi ro bản quyền và deploy luôn, không xin phép BU. Bài nào cũng ghi nguồn BU |
| Q9 | Mỗi lần kiểm tra làm **đủ Đề I + Đề II** (thang 200) |
| Q10 | Câu hỏi onboarding soạn từ **mô tả từng hạng do chủ sản phẩm viết**, chủ sản phẩm duyệt từng dòng |
| Q11 | Quy đổi BU sang hạng: gộp các mức của bảng chính thức cho khớp mô tả hạng (mục 5.4) |
| Q12 | Bài kiểm tra luôn được làm, nhưng hai lần **hoàn tất** phải cách nhau tối thiểu **14 ngày** (quy định của app, không phải luật BU). Dữ liệu luyện tập chỉ dùng để gợi ý kiểm tra lại |
| Q13 | Onboarding hiện sau lần đăng nhập đầu tiên, có nút "Để sau" |
| Q14 | Kiến trúc: module đánh giá riêng, không nhét bài BU vào mô hình `Drill`/`DrillLog` |
| Q15 | Cảnh báo chỉ phát ra khi một lần kiểm tra BU cho hạng thấp hơn hạng hiện tại. Không suy cảnh báo từ dữ liệu luyện tập |

## 4. Hạng của người chơi và luật đổi hạng

### 4.1 Dữ liệu

Mỗi tài khoản có một bản ghi hạng gồm:

- `rank`: K…A hoặc PRO.
- `source`, một trong ba giá trị:
  - `estimated` (**ước lượng**): người chơi chấp nhận hạng bộ câu hỏi gợi ý.
  - `selfDeclared` (**tự khai**): người chơi chọn hạng khác với gợi ý, hoặc chọn PRO.
  - `verified` (**đã kiểm chứng**): hạng có được từ bài kiểm tra BU.
- `buScore?` và `testId?`: lần kiểm tra đã kiểm chứng hạng.
- `warningRank?` và `warningTestId?`: cảnh báo đang hiện, nếu có.
- `questionnaireAnswers`: câu trả lời gần nhất, để truy được vì sao app gợi ý hạng đó.
- `onboardingState`: `notStarted` / `skipped` / `done`.
- `updatedAt`.

### 4.2 Luật

1. **Bộ câu hỏi** đặt hạng với nguồn `estimated` hoặc `selfDeclared`. Người chơi làm lại bất cứ lúc nào được, **trừ khi** hạng đang là `verified`. Từ lúc đó chỉ bài kiểm tra BU mới đổi được hạng, kể cả việc tự khai PRO cũng bị khóa.
2. Kiểm tra BU ra hạng **cao hơn** hạng hiện tại: lên hạng, `source = verified`. Nhảy nhiều hạng một lần cũng được.
3. Kiểm tra BU ra hạng **bằng** hạng hiện tại: giữ hạng, `source = verified`.
4. Kiểm tra BU ra hạng **thấp hơn**: **giữ hạng và giữ nguồn**, đặt `warningRank`/`warningTestId`. Lần hoàn tất sau cho hạng bằng hoặc cao hơn thì xóa cảnh báo.
5. Điểm BU tối đa chỉ ra hạng A. Người tự khai PRO mà kiểm tra ra hạng thấp hơn thì áp dụng luật 4.
6. Người chưa có hạng (đã bỏ qua onboarding) mà hoàn tất kiểm tra BU thì nhận hạng từ kết quả, `source = verified`.

### 4.3 Hiển thị

Mọi chỗ hiện hạng đều dùng `PcRankBadge`, kèm nhãn nguồn ("ước lượng" / "tự khai" / "đã kiểm chứng") và nút ⓘ. Bấm ⓘ sẽ thấy:

- câu miễn trừ "bảng riêng của PoolCoachAI, tham khảo cách hiểu ở Hà Nội";
- bảng quy đổi BU sang hạng (mục 5.4);
- dòng ghi nguồn Billiard University.

## 5. Đề BU và bộ chấm điểm (domain, thuần Dart)

Nguồn: các PDF tại `https://billiarduniversity.org/documents/`, đọc ngày 14/10/2026:

- `BU_Exam-I_Fundamentals.pdf`
- `BU_Exam-II_Skills-{Bachelors,Masters,Doctorate}.pdf`
- `BU_Exam_Instructions.pdf`
- `BU_Rating_Comparisons.pdf`

Không file PDF nào có dòng giấy phép.

### 5.1 Đề I — Cơ bản (tối đa 100)

| Mã | Bài | Cách chấm | Tối đa |
|---|---|---|---|
| F1 | Cắt góc (Cut Shot) | Thang vị trí | 10 |
| F2 | Đánh đứng bi (Stop Shot) | Thang vị trí. Bi mục tiêu phải vào và bi cái dừng chồng lên vòng bi ảo | 10 |
| F3 | Đánh cu lê (Follow Shot) | Thang vị trí. Bi cái dừng trong hoặc chồng lên khung giấy đích | 10 |
| F4 | Đánh trô bi (Draw Shot) | Thang vị trí. Tâm bi cái dừng trong hình chữ nhật 2×1 chấm cạnh lỗ giữa | 10 |
| F5 | Đánh tâm tiến (Stun Shot) | Thang vị trí, nhưng **đích di chuyển** thay cho bi cái. Vị trí 1–3 đi thẳng tới đích, 5–7 phải bật băng cuối | 10 |
| F6 | Ăn bi (Ball Pocketing) | 10 cú, mỗi cú 1 lượt, không được chết cái. Mỗi bi vào 1 điểm | 10 |
| F7 | Bánh xe (Wagon Wheel) | 10 bi đích trên băng, mỗi bi 2 lượt. Vào lỗ **và** chạm đúng bi đích được 1 điểm | 20 |
| F8 | Lưới đích (Grid Target) | 5 đích, mỗi đích 4 lượt. Vào lỗ **và** bi cái dừng trong hoặc chồng lên đích được 1 điểm | 20 |

### 5.2 Đề II — Kỹ năng (ba bản, cùng tên bài)

| Mã | Bài | Cách chấm | Bachelors | Masters | Doctorate |
|---|---|---|---|---|---|
| S1 | Hàng bi (Line of Balls) | Đánh theo thứ tự số, 2 lượt, lấy lượt cao hơn | 4 (bi 1–4, cách 3 bi) | 7 (cách 2 bi) | 10 (cách 1 bi) |
| S2 | Ngắm bi sát băng (Rail Cuts) | 2 lượt, thứ tự tùy ý, lấy lượt cao hơn | 7 | 11 | 15 |
| S3 | Thế 9 bi | 3 thế, mỗi bi hợp lệ theo thứ tự 1 điểm, cộng 2 thế thấp nhất | 10 (bi 5–9) | 12 (bi 4–9) | 14 (bi 3–9) |
| S4 | Thế 8 bi | 3 thế, mỗi bi trước khi trượt 1 điểm, cộng 2 thế thấp nhất | 10 | 12 | 14 |
| S5 | Phòng thủ / bắt đui (Safety) | Mỗi vị trí bi cái 2 lượt, mỗi lần bắt đui được 1 điểm | 6 (3 vị trí) | 10 (5) | 14 (7) |
| S6 | A băng (Kicks) | Mỗi cú thành công 1 điểm | 3 | 5 | 7 |
| S7 | Cân bi (Banks) | Mỗi cú thành công 1 điểm | 3 (bi qua lỗ giữa) | 5 | 7 (bi qua lỗ góc) |
| S8 | Dựng cơ (Elevated cue) | Mỗi cú thành công 1 điểm | 3 | 5 | 7 |
| S9 | Nhảy bi (Jump) hoặc Mát xê (Massé) | Mỗi cú thành công 1 điểm | 3 | 5 | 7 |
| S10 | Phá (Break) | 3 lần phá, mỗi lần chấm 5 tiêu chí a–e (0/1 mỗi tiêu chí), lấy **trung vị** | 5 | 5 | 5 |
| | **Tổng** | | **54** | **77** | **100** |

Tiêu chí của S10:

- a: không chết cái.
- b: a, và bi cái không chạm băng.
- c: a, và bi cái dừng trong vùng 4 chấm ở giữa bàn.
- d: a, và có ít nhất 1 bi vào.
- e: a, và có ít nhất 3 bi mục tiêu vào lỗ hoặc vượt qua vạch đầu bàn (head string).

Các luật riêng cần mã hóa đúng:

- S3: bi 9 vào sớm thì vẫn phải đánh nốt các bi còn lại theo thứ tự.
- S3 bản Doctorate, thế 3: phải tới bi 7 và bi 9 bằng 3–4 băng.
- S4: được chạm bi chướng ngại.
- S9 bản Doctorate: không có dòng "được chết cái".

Bản kế hoạch triển khai phải đối chiếu lại từng luật với PDF.

### 5.3 Năm kiểu chấm (hàm thuần)

1. **Thang vị trí** (F1–F5): nhận chuỗi kết quả vào/trượt. Bắt đầu ở vị trí 4, vào thì +1, trượt thì −1, kẹp trong khoảng 1–7. Tổng cộng 10 cú, kết quả cú thứ 10 vẫn được áp dụng. Điểm = vị trí cuối + số lần vào khi đang ở vị trí 7, tối đa 10. Được **dừng sớm** khi đã chắc chắn đạt 10.
2. **Đếm lượt thành công** (F6, F7, F8, S5–S9): mỗi lượt thành công 1 điểm.
3. **Lấy lượt cao hơn trong 2 lượt** (S1, S2): mỗi lượt là số bi.
4. **Cộng hai lượt thấp nhất trong 3 thế** (S3, S4).
5. **Trung vị 3 lần phá** (S10).

### 5.4 Luật cấp đề và quy đổi hạng

- Làm Đề I trước. Điểm Đề I xếp bản Đề II: **0–49 Bachelors, 50–69 Masters, 70–100 Doctorate**.
- Bản Doctorate phải đánh trên bàn **9 feet trở lên**. Bàn 7–8 feet mà Đề I đạt mức Doctorate thì làm bản Masters.
- Đề II được làm vào buổi khác Đề I. Một lần kiểm tra chỉ **hoàn tất** khi đã có điểm cả hai đề.
- **Điểm BU = Đề I + Đề II, cộng điểm thô.** Đây là **giả định**: PDF không nói có quy đổi bản Bachelors (tối đa 54) và Masters (tối đa 77) sang thang 100 hay không. Hệ quả: người làm bản thấp bị giới hạn tổng điểm, muốn lên tiếp thì phải đạt Đề I cao hơn. Kế hoạch triển khai nên kiểm tra phiếu điểm (score sheet) chính thức nếu tìm được.
- Quy đổi sang hạng theo `BU_Rating_Comparisons.pdf` (không dùng bảng trên trang web, vì hai bảng lệch nhau ở các mức dưới 140). Bảng dưới **chỉ gộp các mức có sẵn của BU**, không thêm mốc tự đặt. Cách gộp bám theo mô tả hạng ở mục 11.1. Chủ sản phẩm chốt ngày 14/10/2026, thay cho bản khớp 1–1 trước đó vì bản đó đặt hạng A ("Top đầu trong nước") ở mức Fargo 600, quá thấp.

| Hạng | Điểm BU | Mức BU | Fargo (tham chiếu) |
|---|---|---|---|
| K | 0–19 | novice | < 200 |
| I | 20–39 | lower + mid beginner | 200–299 |
| H | 40–69 | upper beginner + lower intermediate | 300–399 |
| G | 70–94 | mid intermediate | 400–449 |
| F | 95–109 | upper intermediate | 450–499 |
| E | 110–124 | lower advanced | 500–549 |
| D | 125–139 | mid advanced | 550–599 |
| C | 140–154 | upper advanced | 600–649 |
| B | 155–174 | lower + upper shortstop | 650–729 |
| A | 175–200 | semipro/pro + world class pro | ≥ 730 |

Căn cứ cho mốc A/B (tra ngày 14/10/2026). Dữ liệu còn mỏng; chủ sản phẩm chấp nhận giữ các mốc này:

- Dr. Dave mô tả Fargo 700 là "top player to pro level" và 800 là "top world-class professional" (https://drdavepoolinfo.com/faq/rating/fargorate/).
- Dương Quốc Hoàng có Fargo khoảng 805–839. Con số chỉ thấy qua trích đoạn kết quả tìm kiếm, **chưa kiểm chứng**.
- Không tìm được Fargo của các cơ thủ Việt Nam khác, cũng không có bảng nào quy đổi hạng CLB Việt Nam sang Fargo. Các nguồn Việt Nam hiểu cùng một chữ cái hạng khác nhau, nên câu miễn trừ ở mục 4.3 là bắt buộc.

Hệ quả theo luật BU:

- Muốn từ C trở lên phải làm bản Doctorate, tức phải đánh trên bàn 9 feet.
- Người làm bản Masters tối đa được 177 điểm.

### 5.5 Sơ đồ xếp bi

- Ghi bằng **tọa độ chấm trên lưới 8×4** (chấm 0–8 băng dài, 0–4 băng ngắn). Gốc tọa độ ở góc trên trái, trục x dọc băng dài (0–8), trục y từ băng trên xuống (0–4).
- Vẽ lại chính xác được: S2, S3, S4, S6, S7, S10.
- Phải dựng bằng **luật hình học**: F1–F8, S5, S8. Ví dụ: vị trí 1–7 của thang; khung giấy đích; "bi mục tiêu nằm giữa bi cái và lỗ".
- Ví dụ đã đo: Bachelors S3 thế 1 (trang 3) là bi 5 (1,1), bi 8 (3,1), bi 9 (5,1), bi 7 (1,3), bi 6 (3,3); bi cái tự do; chấm đặt bi ở (6,2).
- Tọa độ đo từ PDF. **Chủ sản phẩm kiểm tra bằng mắt từng sơ đồ trên Chrome** trước khi chốt.
- Dùng lại phần vẽ mặt bàn của Kế hoạch dọn bàn.

### 5.6 Kiểm thử domain

Unit test cho:

- năm kiểu chấm, mỗi kiểu có ví dụ tính tay theo PDF, cộng các trường hợp biên: dừng sớm F1–F5, phá chết cái ở S10, chuỗi toàn trượt hoặc toàn vào;
- luật cấp đề ở các mốc 49/50 và 69/70, cùng trường hợp bàn nhỏ;
- mọi mốc của bảng quy đổi (19/20, 54/55, 139/140…);
- sáu luật đổi hạng ở mục 4.2.

## 6. Lưu trữ và đồng bộ

### 6.1 Drift, schema 2 → 3 (chỉ thêm bảng)

- **`PlayerRankRows`** (mỗi tài khoản một dòng): `userId` (khóa chính), `rank`, `source`, `buScore?`, `testId?`, `warningRank?`, `warningTestId?`, `questionnaireAnswers` (JSON), `onboardingState`, `updatedAt`, `syncedAt?`.
- **`BuTestRows`**: `id`, `userId`, `startedAt`, `completedAt?`, `cancelledAt?`, `tableSize`, `examIScore?`, `examIIVersion?`, `examIIScore?`, `totalScore?`, `resultRank?`, `syncedAt?`.
- **`BuDrillResultRows`**: `id`, `testId`, `drillId`, `attempts` (JSON, **kết quả thô từng cú**), `score`, `recordedAt`, `syncedAt?`.

Lưu kết quả thô để nếu phát hiện chấm sai một luật BU thì tính lại được từ dữ liệu gốc.

Mỗi cú ghi xuống Drift ngay khi nhập, nên đóng app giữa chừng vẫn làm tiếp được. Lần kiểm tra chưa hoàn tất không ảnh hưởng tới hạng.

### 6.2 Directus

Ba collection mới cùng tên. Tạo collection là thao tác trên máy chủ thật, phải hỏi chủ sản phẩm trước khi làm.

- `BuTestRows` và `BuDrillResultRows`: chỉ thêm. Một lần kiểm tra không sửa được nữa sau khi hoàn tất hoặc hủy. Không có xung đột.
- `PlayerRankRows`: **bản mới nhất thắng** theo `updatedAt`, trừ một ngoại lệ: bản `verified` không bao giờ bị bản `estimated`/`selfDeclared` ghi đè. Giữa hai bản `verified` thì bản mới hơn thắng.

## 7. Màn hình và luồng

### 7.1 Route mới

- `/onboarding/rank`: bộ câu hỏi.
- `/rank`: chi tiết hạng và lịch sử kiểm tra.
- `/rank/test`: làm bài kiểm tra.

Mở rộng `authRedirect`: sau khi đăng nhập, nếu `onboardingState = notStarted` thì chuyển tới `/onboarding/rank`.

### 7.2 Onboarding

1. Màn giới thiệu.
2. 8 câu hỏi (mục 11.2).
3. App gợi ý một hạng, kèm mô tả hạng đó.
4. Người chơi bấm **Xác nhận** (thành `estimated`) hoặc **Chọn hạng khác** (danh sách K…PRO kèm mô tả, thành `selfDeclared`).

Màn nào cũng có nút **Để sau** (thành `skipped`).

### 7.3 Làm bài kiểm tra

1. **Chuẩn bị:** chọn kích thước bàn; giới thiệu đề BU, thời gian (mỗi đề khoảng 40–60 phút) và nguồn.
2. **Từng bài:**
   - Sơ đồ trên mặt bàn, hướng dẫn tiếng Việt, ghi nguồn BU, điểm hiện tại.
   - Ô nhập theo kiểu chấm:
     - nút **Vào / Trượt** cỡ 48 px;
     - bộ đếm số bi, giới hạn ở mức tối đa của bài;
     - năm ô tiêu chí cho mỗi lần phá ở S10.
   - F1–F5 tô sáng vị trí hiện tại và tự chuyển vị trí sau mỗi cú.
   - Nút **Hoàn tác cú vừa nhập**.
   - Không chấm được một bài khi chưa nhập đủ số lượt.
3. **Hết Đề I:** hiện điểm và bản Đề II được xếp, cho chọn **Làm Đề II ngay** hoặc **Để buổi khác**.
4. **Kết quả:** điểm từng bài, tổng điểm BU, mức BU, Fargo tham chiếu, và kết quả hạng theo mục 4.2.

Có nút **Hủy lần kiểm tra này**. Lần bị hủy không tính vào giãn cách 14 ngày.

### 7.4 Hồ sơ và màn hình chính

- **Hồ sơ:** thay `PcEmptyState` bằng **thẻ hạng**, gồm:
  - huy hiệu, nhãn nguồn, ⓘ, cảnh báo nếu có;
  - lần kiểm tra gần nhất, ngày được kiểm tra lại;
  - nút **Làm bài kiểm tra**, **Làm tiếp** (khi có lần làm dở) hoặc **Xác định hạng** (khi chưa có hạng).

  Bên dưới thẻ là lịch sử các lần kiểm tra. Nút đăng xuất và thông báo nhật ký chưa đồng bộ giữ nguyên.
- **Màn hình chính:** huy hiệu nhỏ ở đầu trang. Chưa có hạng thì hiện thẻ "Xác định hạng của bạn".

## 8. Xử lý lỗi

- Mọi thứ ghi xuống máy trước, đồng bộ sau.
- **Đăng nhập máy mới:** chờ lấy `PlayerRankRows` từ máy chủ rồi mới quyết định có chuyển sang onboarding hay không. Lấy không được thì **không ép** vào onboarding, chỉ hiện thẻ "Xác định hạng".
- Nhập sai thì giao diện chặn từ đầu; nhập nhầm thì hoàn tác.

## 9. Kiểm thử

- Unit test domain: mục 5.6, cộng quy tắc gộp đồng bộ ở mục 6.2.
- Test migration Drift 2 → 3.
- Widget test cho onboarding, màn làm bài (từng kiểu ô nhập) và thẻ hạng.
- **Chạy thật trên Chrome** toàn bộ luồng: onboarding, làm Đề I, Đề II để buổi khác, hoàn tất, lên hạng. Chủ sản phẩm kiểm tra bằng mắt mọi sơ đồ.

## 10. Ngoài phạm vi

- Lộ trình.
- Dữ liệu trận đấu.
- Đổ kết quả BU vào Player Intelligence.
- Đề III–VIII của BU.
- Hệ số độ khó bàn (Table Difficulty Factor).
- Xin phép BU (chủ sản phẩm đã quyết định không xin).

## 11. Đầu vào từ chủ sản phẩm

Cả ba mục đã chốt ngày 14/10/2026.

1. **Mô tả từng hạng.** Lấy nguyên văn từ PoolOS v2, `lib/core/constants/app_constants.dart` (`AppConstants.playerLevels`, chú thích "HỆ THỐNG XẾP HẠNG - THEO CHUẨN HÀ NỘI / Tham khảo từ cộng đồng Pool Hà Nội"). Chủ sản phẩm chỉ định nguồn này ngày 14/10/2026.

   | Hạng | Nhóm | Mô tả |
   |---|---|---|
   | K | phong trào | Người mới làm quen với Pool |
   | I | phong trào | Đã biết luật chơi, kỹ thuật cơ bản |
   | H | phong trào | Người chơi phong trào phổ biến, bắt đầu có khả năng điều bi |
   | G | phong trào | Người chơi phong trào khá, có thể thi đấu ổn định với đa số CLB |
   | F | thi đấu | Bước đầu tham gia sân chơi thi đấu, trình độ cao trong nhóm phong trào |
   | E | thi đấu | Người chơi bán chuyên |
   | D | thi đấu | Người chơi mạnh, thường xuyên thi đấu |
   | C | thi đấu | Vận động viên trình độ cao |
   | B | thi đấu | Vận động viên rất mạnh |
   | A | thi đấu | Top đầu trong nước |
   | PRO | chuyên nghiệp | Thi đấu chuyên nghiệp |

2. **Bộ câu hỏi và bảng quy đổi.** Chủ sản phẩm đã duyệt ngày 14/10/2026.

   **Câu hỏi:** lấy nguyên văn 8 câu từ PoolOS v2 (`AppConstants.assessmentQuestions`, `lib/core/constants/app_constants.dart`). Không dùng công thức cũ trong `pool_rating_calculator.dart`, vì nó so điểm thang 0–100 với các mốc thang 0–1000.

   - **Q1** "Bạn đã chơi Pool được bao lâu?": Chưa từng chơi / Dưới 3 tháng / 3 – 6 tháng / 6 tháng – 1 năm / 1 – 2 năm / 2 – 5 năm / Trên 5 năm.
   - **Q2** "Trung bình bạn chơi Pool bao nhiêu?": Dưới 2 giờ / tuần · 2 – 5 giờ / tuần · 5 – 10 giờ / tuần · 10 – 20 giờ / tuần · Trên 20 giờ / tuần.
   - **Q3** "Trong một lượt cơ, bạn đã từng đi được nhiều nhất bao nhiêu bi?": 1…8 / Dọn bàn (Run Out).
   - **Q4** "Trong những thế bi bình thường, bạn thường đi được bao nhiêu bi?": 1…5 / 6+ / Thường xuyên Runout.
   - **Q5** "Bạn đã từng Runout (đi chấm) chưa?": Chưa bao giờ / Đã từng 1–2 lần / Thỉnh thoảng / Khá thường xuyên / Rất thường xuyên.
   - **Q6** "Trung bình bao nhiêu rack bạn có thể đi được một chấm?": Chưa từng / Hơn 100 rack / Khoảng 50 rack / Khoảng 20 rack / Khoảng 10 rack / Khoảng 5 rack / Khoảng 2–3 rack / Gần như rack nào cũng có thể.
   - **Q7** "Sau cú phá bi, bạn thường còn thế bi như thế nào?": Thường không có bi đánh tiếp / Thường chỉ có 1 bi / Có thể đi tiếp 2–3 bi / Thường có layout thuận lợi / Thường có cơ hội đi chấm.
   - **Q8** "Sau khi ăn một bi, bạn thường điều bi cái ở mức nào?": Thường xuyên bị khó / Có lúc dễ, có lúc khó / Phần lớn còn bi đánh tiếp / Thường chủ động điều được bi cái / Có thể điều bi chính xác theo ý muốn.

   **Bảng quy đổi:** chỉ Q4, Q5 và Q6 dùng để tính hạng. Các mốc neo vào mô tả Fargo của Dr. Dave (https://drdavepoolinfo.com/faq/rating/fargorate/).

   | Câu trả lời | Hạng gợi ý | Căn cứ |
   |---|---|---|
   | Q5 "Chưa bao giờ" + Q4 = 1 | K | Fargo < 200: "has probably never run a table" |
   | Q5 "Chưa bao giờ" + Q4 = 2 | I | Mô tả I: "Đã biết luật chơi, kỹ thuật cơ bản" |
   | Q5 "Chưa bao giờ" + Q4 ≥ 3, hoặc Q5 "Đã từng 1–2 lần" | H | Fargo 300: "running out is very unlikely" |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Chưa từng" / "Hơn 100 rack" / "Khoảng 50 rack" | G | Fargo 400: "runs out first time at the table infrequently" |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Khoảng 20 rack" | F | **Nội suy giữa 400 và 500, không có nguồn** (chủ sản phẩm chấp nhận) |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Khoảng 10 rack" | E | Fargo 500: "runs out first time at the table occasionally" |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Khoảng 5 rack" | D | **Nội suy giữa 500 và 600, không có nguồn** (chủ sản phẩm chấp nhận) |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Khoảng 2–3 rack" | C | Fargo 600: "has run three-in-a-row multiple times" |
   | Q5 "Thỉnh thoảng" trở lên + Q6 "Gần như rack nào cũng có thể" | B | Fargo 700: "a threat to run six in a row" |
   | (không câu trả lời nào dẫn tới) | A, PRO | Chỉ chọn được qua "Chọn hạng khác", thành `selfDeclared` |

   Q1, Q2, Q3, Q7 và Q8 vẫn được hỏi và lưu trong `questionnaireAnswers` để Lộ trình dùng sau, nhưng **không tính hạng**. Có unit test cho từng dòng của bảng.

3. **Tên bài.** Chủ sản phẩm sửa ngày 14/10/2026:
   - F5 (stun) là **Đánh tâm tiến**: kỹ thuật cao hơn đánh đứng bi (F2), sau va chạm bi cái nhích lên một chút. Không gộp với đánh đứng bi.
   - S5 là **Phòng thủ / bắt đui**.
   - S9 là **Nhảy bi (Jump)** hoặc **Mát xê (Massé)**. Đây là hai kỹ thuật khác nhau; S9 của BU cho phép dùng một trong hai.

   - F6 là **Ăn bi** và S8 là **Dựng cơ** (chủ sản phẩm đồng ý tên Claude đề xuất).

   Các tên khác theo bộ thuật ngữ chủ sản phẩm đã chốt: đánh đứng bi, đánh tâm tiến, đánh cu lê, đánh trô bi, a băng, cân bi, chấm, bi ảo, chết cái, phá.
