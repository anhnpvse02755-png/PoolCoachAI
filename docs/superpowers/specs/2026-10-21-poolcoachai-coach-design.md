# PoolCoachAI — Thiết kế Coach tình huống (Giai đoạn A)

**Ngày:** 21/10/2026
**Trạng thái:** đang làm Giai đoạn A. Các quyết định chủ sản phẩm chốt ngày 21/10 ghi ở mục 3.1. Những chỗ người viết tự điền đánh dấu **(đề xuất)** ở mục 3.2. Năm câu hỏi ở mục 16 đã được chủ sản phẩm trả lời ngày 21/10/2026, ghi ở cột cuối của bảng mục 16. Mọi câu tiếng Việt mới ở mục 15 đều **chờ duyệt**.
**Tiền đề:** `main` 1c59f3e. Đã có lõi vật lý, Kế hoạch dọn bàn kèm cú phòng thủ, Đánh giá + hạng, Lộ trình, quản lý cơ, đồng bộ trận đấu và bản Android/iOS. Tài liệu nguồn: `tong_hop_y_tuong_app_huan_luyen_bi_a_9ball.md` §3.4, §9.6, §15.4 và `PRD_PoolCoachAI.md` §8, §13.

---

## 1. Mục tiêu

> App bày một thế bàn 9 bi. Người chơi chọn cú: ăn bi vào lỗ nào, kiểu đánh, lực, áp phê, hoặc chọn phòng thủ. App chấm cú đó bằng chính lõi Kế hoạch dọn bàn. Sai thì app không nói đáp án ngay. Lần sai đầu, app hỏi một câu để người chơi tự thấy hậu quả cú mình chọn. Lần sai thứ hai, app chỉ ra nên đổi thông số nào. Sai lần thứ ba thì app hiện đáp án và lý do. Nút *Xem đáp án* bấm được bất cứ lúc nào.

Tiêu chí thành công:

- Chủ sản phẩm làm 10 tình huống (sinh ngẫu nhiên và lấy từ thư viện) và thấy cách chấm giống cách một người chơi giỏi đánh giá cú đánh.
- Mỗi câu gợi ý nói đúng về cú người chơi vừa chọn, không phải câu chung chung.
- Đổi số liệu luyện tập để người chơi yếu nhóm khác: chủ đề tình huống và thẻ gợi ý trên màn Coach tự đổi theo.

Có năm phần, cùng một kế hoạch:

1. Lõi `lib/domain/coach/`, Dart thuần, không import Flutter (mục 5–9).
2. Màn Coach và màn tình huống, chạy trên Android, iOS và web (mục 4).
3. Thẻ Coach Recommendation (mục 10).
4. Lưu lần làm tình huống và đồng bộ (mục 11, **quyết định cần duyệt**).
5. Ranh giới cho Giai đoạn B, Coach Chat dùng LLM: chỉ phác giao diện (mục 12).

### Không thuộc phạm vi

- Coach Chat với LLM: chỉ phác ranh giới ở mục 12.
- Chấm chi tiết cú thủ: độ dày, bên lệch, A băng mấy băng, ngắm chấm nào. Giai đoạn A chỉ chấm lựa chọn *Ăn bi* hay *Phòng thủ*; đáp án vẫn hiện cú thủ Planner tìm được.
- Tình huống 8 bi và 10 bi sinh ngẫu nhiên. Riêng thư viện được phép có bàn 10 bi, khi sơ đồ gốc cần (mục 9).
- Đánh kết hợp (combo), Cân bi, Phá, Nhảy bi, Mát xê, Dựng cơ: Planner không tính những cú này.
- Cơ Dốc: Planner luôn dùng cơ Thường.
- SAWS hiệu chỉnh theo từng cây cơ.
- Đưa kết quả Coach vào điểm thuần thục của Player Intelligence (mục 11.3).
- Sửa Trang chủ, sửa Recommendation Engine (`recommendation.dart`) hay thêm tab thứ 6.
- Camera và Vision.

---

## 2. Hiện trạng mã (đối chiếu `main` 1c59f3e, 21/10/2026)

| Chỗ | Đã có | Ý nghĩa cho Coach |
|---|---|---|
| `lib/features/coach/presentation/coach_screen.dart` | Chỉ có `PcEmptyState` với `Vi.coachComing`. Màn mở đè lên shell ở `/coach` (`Routes.coach`), từ nút tròn nổi `PcShellScaffold` có trên **mọi tab**. Đây **không phải một tab** | Thẻ gợi ý và lối vào tình huống nằm trên màn này. Không thêm tab |
| `planner_job.dart` | `planStep(...)` trả **một** `PlanStep`: bước tốt nhất. `PlannerJob` chạy chia lát, còn bộ nhớ mô phỏng `_sims` và `CandidateFinder` là **private** | Coach cần cả danh sách phương án đã chấm, và cần chấm thêm cú của người chơi bằng đúng các lần mô phỏng đó. Phải mở một chỗ nối nhỏ (mục 5.2) |
| `scoring.dart` | `ScoringContext`, `scoreOption`, `scoreTier`, `bestOf`, `toleranceOf`, `zoneGrid` / `ZoneGridJob` đều public. `OptionScore` có đủ từng khoản: `position`, `robustDiff1`, `diff2`, `bank`, `tech`, `power`, `distance`, `total` | Chấm cú người chơi bằng **đúng** hàm của Planner, không viết cách chấm thứ hai |
| `shot_options.dart` | `ShotKey`, `tierOneKeys` (3 kiểu đánh × 5 lực), `tierTwoKeys` (60 phương án áp phê), `rejectionOf` → `scratch` / `objectMissed` / `blocked`, `simulateKey` (quá giờ thì null) | Cú người chơi chọn chính là một `ShotKey`. Lý do bị loại có sẵn để dựng gợi ý |
| Planner chọn lỗ | `CandidateFinder.easiest` chọn **lỗ có góc cắt nhỏ nhất** bằng hình học (`bestPocket`). Chỉ cặp bi–lỗ đó được mô phỏng | Người chơi chọn lỗ khác thì Coach phải chấm riêng lỗ đó (mục 6.4) |
| Thông số cú | Kiểu đánh `Stroke` {stun = Đánh đứng bi, follow = Đánh cu lê, draw = Đánh trô bi}; lực `powerPresets` 30 · 45 · 60 · 75 · 90; áp phê ½ và 1 đầu cơ trái/phải (chỉ ở tầng 2); độ dốc luôn Thường | Bảng chọn của người chơi chỉ có **đúng** các thông số này |
| Cú thủ | `SafetyJob` có lượt thô và lượt đầy đủ; `SafetyShot` có `reason` (`snookered`/`noPot`), `kind` (`direct`/`kick`), `rails` | Dùng để hiện đáp án các tình huống Phòng thủ và A băng |
| `miss_advice.dart` | `missSafetyAdvice` → dư dày / dư mỏng | Dùng lại trong đáp án |
| Tốc độ đo được (nhật ký `2026-10-07-run-out-planner.md`) | Bước 1 của bàn 9 bi điển hình trên Chrome: 0,36–0,46 s ở máy yên, 0,5–1,2 s khi máy bận. Lát 4 ms. Một lần `aimShot` không chia nhỏ được, dài nhất khoảng 47–60 ms trên VM. Cú thủ hiện ra sau 0,3–4,9 s trên Chrome | Đủ nhanh để tính đáp án trong lúc người chơi suy nghĩ (mục 13) |
| `player_intelligence.dart` | `weak` (yếu nhất trước), `categories[cat].mastery` (null khi chưa đủ 3 buổi), `trend` | Dùng để chọn chủ đề và độ khó |
| `recommendation.dart` | `computeRecommendation` → `TodayRecommendation{cat, reason, drill, article, …}`. Trang chủ hiện thẻ này qua `todayRecommendationProvider` | Thẻ Coach **không** hiện lại bài tập hay bài đọc hôm nay. Thẻ chỉ lấy `cat` để hai màn nói cùng một nhóm (mục 10) |
| `bu_layouts.dart` | Sơ đồ BU đo bằng **chấm** (`Cham`, `chamToTable`), có màn xem `/rank/layouts`. F1, F6, S5 có bi cái cố định; S1–S4 là bi cái tự do | Thư viện tình huống dùng cùng định dạng chấm (mục 9) |
| `test/support/planner_tables.dart` | Các bàn mẫu đã đo: `railTable`, `cornerFollowTable`, `typicalNineBallTable`, `noPotTable`, `snookerOneRailTable`, … | Nguồn tình huống mẫu đầu tiên, chép sang `lib/` dạng chấm |
| Drift | `schemaVersion` 10 | Bảng mới lên 11 (mục 11) |
| `skill_category.dart` | Import `package:flutter/material.dart` để lấy `Color` | Lõi Lộ trình đã import file này. Test kiến trúc chỉ dò chữ `package:flutter` trong từng file nên vẫn qua; Coach làm giống Lộ trình (mục 5) |
| `Vi.simSquirt` | Dòng áp phê vẫn có vế *"điểm ngắm cần lệch khoảng … đầu cơ"* và *"hoặc ngắm lệch đi để bù trừ áp phê"* | Không khớp mẫu câu chủ sản phẩm chốt 05/10 (*"Hãy ngắm như đánh tâm bi…"*). Coach dùng mẫu câu mới, theo đúng mẫu SAWS (mục 7.3). Không sửa màn Mô phỏng trong dự án này |

---

## 3. Quyết định

### 3.1 Chủ sản phẩm đã chốt (21/10/2026)

| # | Quyết định |
|---|---|
| C1 | **Giai đoạn A**: Coach tình huống chạy hoàn toàn bằng logic tất định, có test: Planner, lõi vật lý, hình học bàn, `miss_advice`, `safety_*`. **Giai đoạn B** (sau): Coach Chat dùng LLM thật (Claude), đọc Player Intelligence. Ở đây chỉ phác ranh giới |
| C2 | Luồng theo tong_hop §3.4: bày thế bàn 2D (dùng lại cái bàn của Planner và màn mô phỏng) → người chơi chọn cú → app chấm → sai thì gợi ý 1 → sai thì gợi ý 2 → sai thì hiện đáp án kèm lý do. Nút *Xem đáp án* bấm được bất cứ lúc nào |
| C3 | Hai nguồn tình huống: **sinh ngẫu nhiên** theo nhóm yếu của người chơi, và **thư viện mẫu** chỉ chứa vị trí bi. Đáp án luôn do Planner tính, không bao giờ viết tay |
| C4 | Có thẻ **Coach Recommendation** (PRD §8, §13), dựng từ `recommendation.dart` và Player Intelligence, không trùng thẻ gợi ý ở Trang chủ |
| C5 | Chạy trên Android, iOS và web; chạm chọn bi và lỗ phải dễ bằng ngón tay |
| C6 | Không bịa: mọi gợi ý, lời giải thích và kết luận là mẫu câu trong `vi.dart`, điền bởi hàm thuần có tên và có test. Planner không phân định được thì nói *chưa đủ dữ liệu*, không nói cú nào là tối ưu |
| C7 | Không có lời khuyên dạng "ngắm lệch X°". Lời khuyên áp phê gồm: số đầu cơ, *"ngắm như đánh tâm bi"*, tỉ lệ BHE/FHE và lực |
| C8 | Lõi domain không import Flutter (`architecture_test.dart`) |

### 3.2 Người viết đề xuất (chờ duyệt)

| # | Đề xuất | Lý do |
|---|---|---|
| D1 | Giai đoạn A chỉ sinh tình huống **9 bi** | App tập trung vào 9 bi (tong_hop §15.1). Trong 9 bi, bi phải chạm luôn là bi số nhỏ nhất |
| D2 | Bi phải chạm **được chọn sẵn** và hiện rõ trên bàn, người chơi không phải chạm chọn | Trong 9 bi, chọn bi chỉ kiểm tra luật, không kiểm tra cách đọc bàn. Bắt chạm chọn chỉ thêm một bước dễ bấm nhầm trên điện thoại. Lỗi chọn thứ tự bi (tong_hop §3.4) để dành cho 8 bi sau này |
| D3 | Người chơi trả lời tối đa **3 lần**: sai lần 1 → gợi ý 1, sai lần 2 → gợi ý 2, sai lần 3 → tự hiện đáp án | Đúng chuỗi ở C2, và đúng tong_hop §3.4: đáp án chỉ tự hiện sau ít nhất hai lần thử. Xem Q1 |
| D4 | Mức chênh điểm cho phép `coachScoreTolerance = 3.0` (mục 6.5) | Bằng phạt Đánh cu lê: một cú cu lê có cùng vị trí với cú đánh đứng bi vẫn được tính đạt. Nhỏ hơn hẳn phạt trô (10) và phạt áp phê (15, 20) |
| D5 | Coach Recommendation lấy **nhóm** từ `TodayRecommendation.cat` khi nhóm đó có tình huống; nếu không thì lấy nhóm yếu có tình huống | Trang chủ và Coach nói cùng một nhóm, không có hai luật chọn nhóm |
| D6 | **Lưu và đồng bộ** từng lần làm tình huống, nhưng **không** đưa vào điểm thuần thục (mục 11) | Thẻ gợi ý cần tỉ lệ giải và lỗi lặp lại; Giai đoạn B cần dữ liệu thật. Chọn cú là năng lực *đọc bàn*, khác năng lực *thực hiện* mà điểm thuần thục đo (tong_hop §15.3). Xem Q2 |
| D7 | Câu áp phê của Coach theo mẫu SAWS của chủ sản phẩm, **không** dùng lại `Vi.simSquirt` | `simSquirt` còn vế "ngắm lệch", trái với C7. **Q5 (21/10/2026) thay đề xuất này:** màn Mô phỏng cũng dùng đúng câu mẫu SAWS đó |
| D8 | Không có số độ nào trong chữ của Coach, kể cả góc cắt để tham khảo. Độ khó vị trí nói bằng **vùng tốt / tạm được / khó** | Quy tắc đơn giản hơn, và test bắt được bằng cách tìm ký tự "°" |

---

## 4. Luồng người dùng và màn hình

### 4.1 Màn Coach (`/coach`, mở từ nút tròn nổi)

Thay `PcEmptyState` hiện có. Từ trên xuống:

1. **Thẻ "Nên luyện gì"** (Coach Recommendation, mục 10).
2. **Thẻ "Tình huống"**:
   - Hàng chip chọn nhóm, chỉ gồm 4 nhóm có tình huống: *Ngắm bi · Điều bi / Vị trí · Phòng thủ · A băng*. Chip được chọn sẵn là nhóm mà thẻ gợi ý đề xuất.
   - Hàng chip độ khó: *Dễ · Vừa · Khó*. Mức chọn sẵn tính bằng `coachDifficultyFor` (mục 8.4).
   - Nút **Bắt đầu**: mở `/coach/situation?topic=…&d=…`, với `seed` sinh mới.
   - Dòng **Thư viện tình huống ›**: mở `/coach/library`, danh sách tình huống mẫu theo nhóm (mục 9.4).
3. **Ô "Trò chuyện với huấn luyện viên (sắp có)"**: giữ câu `Vi.coachComing`. Đây là chữ giao diện thật, không giả làm Chat.

Hai nhóm *Phá* và *Cân bi* không có chip. Khi thẻ gợi ý rơi vào hai nhóm này, thẻ nói thẳng *"Chưa có tình huống cho nhóm …"* rồi đề xuất nhóm kế tiếp có tình huống (mục 10).

### 4.2 Màn tình huống (`/coach/situation`)

Đường dẫn có tham số để mở lại đúng tình huống: tình huống sinh ngẫu nhiên là `?topic=position&d=1&seed=123456`, tình huống thư viện là `?lib=pos-rail-1`. Không có tham số thì sinh tình huống theo nhóm thẻ gợi ý đang đề xuất.

Bố cục `TablePanelLayout`: bàn nằm trên, ngoài vùng cuộn; bảng điều khiển cuộn được ở dưới.

**Trạng thái 1, đang chuẩn bị.** Bàn hiện ngay khi có vị trí bi. Đáp án tính trong nền (mục 13). Người chơi chọn cú được ngay, không phải chờ.

**Trạng thái 2, chọn cú.** Trên bàn vẽ mọi bi (khác màn từng bước của Planner, màn đó chỉ vẽ 3 bi): bi phải chạm có vòng sáng, mọi bi đúng màu và có số. Bảng điều khiển từ trên xuống:

1. Câu đề bài: *"Tới lượt bạn. Bi phải chạm: bi N. Bạn đánh thế nào?"*
2. Chọn **Ăn bi** hay **Phòng thủ** (hai nút ngang nhau).
3. Khi chọn Ăn bi:
   - **Lỗ**: chạm vào lỗ trên bàn. Lỗ được chọn có vòng vàng, giống màn Planner. Dưới bàn có thêm hàng 6 chip tên lỗ (*góc trên trái …*), dùng khi chạm trên bàn khó và cho trình đọc màn hình.
   - **Kiểu đánh**: *Đánh đứng bi · Đánh cu lê · Đánh trô bi*.
   - **Lực**: *30% · 45% · 60% · 75% · 90%*.
   - **Áp phê**: *Không · Trái 0.5 · Trái 1 · Phải 0.5 · Phải 1* (dùng lại `Vi.simSpinChip`), mặc định *Không*.
4. Nút **Chấm**. Nút chỉ bật khi đã đủ lựa chọn. Bên cạnh là dòng *Lần thử k/3*.
5. Nút chữ **Xem đáp án** luôn hiện. Bấm khi chưa sai đủ 3 lần thì hỏi lại một câu (mục 15). Chọn đồng ý thì lần làm này ghi là `revealedEarly`.

**Trạng thái 3, đang chấm.** Đáp án chưa tính xong thì nút Chấm hiện *"Đang tính…"*. Đang chờ cú thủ thì dùng câu sẵn có `Vi.planSearchingSafety`. Có kết quả thì tự chấm, người chơi không phải bấm lại.

**Trạng thái 4, có kết quả** (mục 6–7):

- **Đạt**: hiện câu kết luận, đường đi mô phỏng của cú người chơi, rồi phần đáp án (lý do, các cú khác cũng đạt). Có nút **Tình huống mới**.
- **Sai lần 1**: hiện câu kết luận *Chưa đạt*, câu hỏi gợi ý 1, và vẽ **đường đi mô phỏng của chính cú người chơi chọn**: bi cái nét đứt, điểm dừng hoặc lỗ chết cái. Đường này là hậu quả cú người chơi chọn, không phải đáp án. Lựa chọn cũ còn nguyên để người chơi sửa một thông số rồi bấm Chấm lại.
- **Sai lần 2**: như trên, thêm gợi ý 2, và vẽ **vùng điều tốt** cho bi kế tiếp (`zoneGrid`) khi gợi ý nói về vị trí.
- **Sai lần 3** hoặc bấm Xem đáp án: hiện **đáp án** (mục 7.3), vẽ đường đi của cú tốt nhất y như màn từng bước của Planner (`PlannerPainter`).
- **Chưa đủ dữ liệu**: hiện câu *chưa đủ dữ liệu* kèm lý do. Lần thử không bị tính (mục 6.6).
- **Chọn lại đúng cú vừa sai**: hiện *"Bạn vừa chọn đúng cú này…"*. Lần thử không bị tính.

Disclaimer `Vi.simDisclaimer` và câu `coachModelNote` luôn ở cuối bảng.

### 4.3 Chạm trên điện thoại và trình duyệt

- Vùng chạm lỗ: bán kính bằng giá trị lớn hơn giữa bán kính lỗ vẽ và **24 px logic** (`TableLayout.touchReach`, dùng lại sàn `minTouchPx`). Chạm ở chỗ hai vùng lỗ chồng nhau thì lấy lỗ gần hơn. Trên điện thoại dọc, bàn chỉ còn khoảng 1,3 px/cm, nên hàng chip tên lỗ là đường chọn chắc chắn.
- Mọi chip và nút cao tối thiểu 48 dp (chuẩn Material). Bảng điều khiển cuộn được. Bàn không cuộn theo, để vuốt trên bàn không làm trôi trang.
- Không có thao tác kéo trong Coach: người chơi không đặt bi, chỉ chọn. Nhờ vậy không có xung đột giữa chạm và cuộn trên điện thoại.
- Trên web rộng (≥ 900 px), bàn nằm trái, bảng nằm phải (`TablePanelLayout` đã hỗ trợ). Trên điện thoại, bàn trên, bảng dưới.

### 4.4 Semantics

- Bàn có nhãn đọc được: *"Bàn tình huống: bi cái và N bi. Bi phải chạm: bi K."* Khi đã chọn lỗ thì thêm lỗ.
- Mỗi lỗ là một nút có nhãn *"Lỗ góc trên trái"*.
- Kết luận và gợi ý nằm trong vùng `liveRegion`, để trình đọc màn hình đọc ngay khi có.
- Kịch bản Chrome đọc các nhãn này (mục 14.5).

---

## 5. Lõi `lib/domain/coach/`

Dart thuần, không import Flutter. Lõi được import `skill_category.dart` như lõi Lộ trình đang làm. Thêm test kiến trúc *"lõi Coach không phụ thuộc Flutter"* (mục 14.4).

| File | Việc nó làm |
|---|---|
| `coach_constants.dart` | Hằng số mục 5.1 |
| `coach_topic.dart` | `enum CoachTopic { aiming, position, safety, kick }`, `coachTopicOf(SkillCategory) → CoachTopic?`, `categoryOf(CoachTopic)` |
| `situation.dart` | `CoachSituation{key, topic, source, difficulty, setup: TableSetup, seed?, libraryId?}`. **Không có trường đáp án nào** |
| `answer.dart` | `sealed CoachAnswer`: `PotAnswer{ball, pocket, stroke, power, spin}` · `SafetyAnswer`. `PotAnswer.key(cue) → ShotKey` |
| `coach_job.dart` | Việc tính chia lát: đáp án tham chiếu và chấm từng câu trả lời (mục 5.2) |
| `reference.dart` | `CoachReference`: bước Planner, các phương án đã chấm, tập đạt (mục 6.2) |
| `evaluation.dart` | `evaluateAnswer(...)`: chấm cú người chơi bằng hàm của Planner (mục 6.4) |
| `grading.dart` | `gradeAnswer(reference, evaluation) → CoachVerdict` (mục 6) |
| `verdict.dart` | `CoachOutcome`, `CoachFault`, `CoachVerdict` (mục 6.7) |
| `hints.dart` | `hintOne`, `hintTwo`: trả về **dữ liệu** gợi ý, không phải chữ (mục 7) |
| `reveal.dart` | `buildReveal`: dữ liệu đáp án và lý do (mục 7.3) |
| `rng.dart` | `CoachRng`: bộ sinh số Park–Miller, chạy giống hệt trên web (mục 8.2) |
| `generator.dart` | `proposeLayout` (hình học) và `acceptsForTopic` (sau khi có tham chiếu) (mục 8) |
| `difficulty.dart` | `CoachDifficulty { easy, medium, hard }`, `coachDifficultyFor(CategoryInsight?)` |
| `library.dart` | Thư viện tình huống mẫu, hằng số Dart dạng chấm (mục 9) |
| `attempt.dart` | `CoachAttempt`: bản ghi một lần làm tình huống (mục 11) |
| `coach_stats.dart` | `summarizeCoachAttempts` (mục 10) |
| `coach_recommendation.dart` | `computeCoachRecommendation` (mục 10) |
| `coach_context.dart` | Ranh giới Giai đoạn B (mục 12) |

Mọi câu chữ nằm trong `lib/core/strings/vi.dart`, phần `// ─── Coach tình huống`. Hàm `Vi.coach…` chỉ nhận dữ liệu do các hàm trên trả về.

### 5.1 Hằng số (`coach_constants.dart`)

Test chỉ dùng tên hằng số, không dùng giá trị, như hằng số của Planner.

| Hằng số | Giá trị | Ghi chú |
|---|---|---|
| `coachMaxAnswers` | 3 | D3. Gợi ý 1 sau lần sai 1, gợi ý 2 sau lần sai 2 |
| `coachScoreTolerance` | 3.0 điểm | D4, mục 6.5 |
| `coachEquivalentsShown` | 3 | Số cú "cũng đạt" hiện trong đáp án |
| `coachGeometryTries` | 400 | Số thế bàn thử bằng hình học trước khi bỏ |
| `coachPhysicsTries` | 6 | Số thế bàn được chạy Planner để thử, cho nhóm Ngắm bi và Vị trí |
| `coachMinPocketClearance` | 12 cm | Khoảng cách tối thiểu từ tâm bi tới điểm lỗ, để bi không nằm trong miệng lỗ |
| `coachBallGap` | 0.5 cm | Khe tối thiểu giữa hai bi khi sinh ngẫu nhiên (bi chạm nhau thì đường tính dễ sai lệch) |
| `coachFrozenRailChance` | 0.1 | Xác suất một bi nằm sát băng |
| `coachPositionQuantum` | 0.5 cm | Vị trí sinh ra được làm tròn tới mức này, để khoá tình huống tái tạo được |
| `coachStatsWindow` | 10 | Số lần làm gần nhất dùng cho thẻ gợi ý |
| `coachStatsMin` | 5 | Ít hơn số lần này thì thẻ gợi ý nói *chưa đủ dữ liệu* |
| `coachRecurringMin` | 3 | Một lỗi xuất hiện từ ngần này lần trở lên trong `coachStatsWindow` mới tính là lỗi lặp lại |
| `coachScoringVersion` | 1 | Tăng khi hằng số chấm của Planner hoặc Coach đổi. Lưu trong mỗi lần làm |

### 5.2 Chỗ nối với Planner (sửa nhỏ, không đổi kết quả)

Coach cần **cùng các lần mô phỏng** mà Planner đã chạy cho bước 1, để chấm cú người chơi mà không mô phỏng lại. Hiện bộ nhớ đó là `_sims` private trong `PlannerJob`. Sửa như sau:

1. File mới `lib/domain/planner/sim_cache.dart`, gồm:
   - `class SimCache`, có `lookup(ShotKey) → AimedShot?` ném `MissingSimulation(key)` khi chưa có, và `fill(ShotKey, {aim, table})` chạy `simulateKey`.
   - `class MissingSimulation implements Exception`, thay `_Missing` hiện có.
2. `PlannerJob` nhận thêm tham số tuỳ chọn `SimCache? cache`. Không truyền thì tạo cache riêng như hiện nay. Mọi test Planner phải giữ **đúng y** kết quả.
3. `saws.dart` mở thêm `enum SawsSpeed { slow, medium, fast }` và `sawsSpeed(double power)`, cùng cách chia cột với `_sawsColumn` hiện có (30 → Chậm; 45, 60 → Vừa; 75, 90 → Nhanh). Câu áp phê của Coach cần chữ chỉ lực (mục 7.3), và phải lấy từ đúng một nguồn.

### 5.3 `CoachJob`

Việc tính chia lát, cùng cách làm với `PlannerJob`: `step(budget)` làm tới khi hết `sliceBudget` (4 ms) rồi trả quyền cho giao diện. Gặp `MissingSimulation` thì mô phỏng đúng lần đó rồi chạy lại. Vì vậy chạy từng lát cho **đúng y** kết quả chạy một mạch. Thứ tự việc:

1. **Tham chiếu.** Chạy `PlannerJob(setup, cache: shared)` tới khi bước 0 được báo ra (`StepReady(0, …)`), rồi `cancel()` để không tính bước 2 trở đi.
   - Bước 0 là `normal` hoặc `fallback`: dựng `ScoringContext` với một `CandidateFinder` riêng (chỉ hình học, rẻ), rồi tính `scoreTier` trên tầng mà Planner đã dùng. Mọi lần mô phỏng của tầng đó đã có trong cache.
   - Bước 0 là `safety`: chờ cú thủ theo đúng luật màn Planner. Ở điểm hỏi (thủ tốt) thì giữ cú lượt thô (`keepSafety`). Cú tạm thì để việc tìm chạy tiếp tới khi xong.
2. **Câu trả lời.** `submit(answer)` xếp câu trả lời vào hàng. Câu trả lời được chấm ngay khi tham chiếu xong (mục 6.4). Cú phải mô phỏng thêm thì cũng chia lát.
3. Sự kiện báo ra: `ReferenceReady`, `SafetyReady` (cú thủ có hoặc đổi), `Graded(index, verdict)`.
4. Rời màn hình thì `cancel()`.

---

## 6. Chấm cú (`grading.dart`, `evaluation.dart`)

### 6.1 Nguyên tắc

- **Một cách chấm duy nhất**: điểm của một cú là `OptionScore.total` do `scoreOption` của Planner tính (thấp là tốt). Coach không có công thức chấm riêng.
- **Đáp án** là cú Planner chọn. Lời kết luận không bao giờ dùng chữ *tối ưu*. Câu kết luận luôn ghi rõ *"theo cách chấm của Kế hoạch dọn bàn"*.
- Planner không có cơ sở để so hai lựa chọn thì kết luận là **chưa đủ dữ liệu** (mục 6.6). Không đoán.

### 6.2 Tham chiếu (`CoachReference`)

| Trường | Nghĩa |
|---|---|
| `step` | `PlanStep` bước 0 của Planner |
| `ball` | Bi phải chạm (bi số nhỏ nhất) |
| `scored` | `List<ScoredOption>` của tầng Planner đã dùng ở lỗ Planner chọn, giữ đúng thứ tự thử. Rỗng khi bước 0 là `fallback` hoặc `safety` |
| `best` | `scored` có điểm thấp nhất; hoà điểm thì lấy cú thử trước (`bestOf`). Đây chính là cú của `step` |
| `accepted` | Mọi `o` trong `scored` có `o.score.total ≤ best.score.total + coachScoreTolerance`, sắp theo điểm tăng dần rồi theo thứ tự thử |
| `nextBall` | `step.nextBallNum` |
| `safety` | `SafetyShot?`, chỉ có khi bước 0 là `safety` |

### 6.3 Câu trả lời của người chơi

- `PotAnswer(ball, pocket, stroke, power, spin)` thành `ShotKey(cue, ballPos, pocket, stroke, spin, power)`.
- `SafetyAnswer`: người chơi chọn phòng thủ. Giai đoạn A không chọn chi tiết cú thủ.

### 6.4 Chấm một câu trả lời Ăn bi (`evaluateAnswer`)

Xét lần lượt, dừng ở bước đầu tiên ra kết luận:

1. **Hình học**: `evaluateShot(cue, ball, pocket, others)`. Kết quả `Unmakeable(reason)` thì lỗi là `pocketUnmakeable(reason)`.
2. **Mô phỏng**: tra `cache.lookup(key)`. Chưa có thì mô phỏng; quá giờ (null) thì kết luận *chưa đủ dữ liệu* (`timeout`).
3. **Vòng loại**: `rejectionOf(aimed, pocket, obstacles)`:
   - `scratch` → lỗi `scratch`, kèm lỗ bi cái rơi (`trace.cuePocket`);
   - `objectMissed` → lỗi `objectMissed`;
   - `blocked` → lỗi `blocked`, kèm số bi chắn đầu tiên trên đường (`firstBlocker`, hàm mới, xét `cueBefore`, `cueAfter`, `objectPath` theo thứ tự).
4. **Chấm điểm**: `ScoringContext` với hình học của **lỗ người chơi chọn** (cùng lỗ Planner chọn thì dùng lại context của tham chiếu), rồi `scoreOption`. Kết quả null (từ chỗ bi cái dừng, bi kế tiếp không còn lỗ nào) thì lỗi là `noNextShot`.
5. Có điểm thì so với tham chiếu theo mục 6.5.

Cú người chơi chọn trùng một cú trong `scored` thì dùng luôn điểm đã có, không chấm lại.

### 6.5 Dung sai, hoà điểm và kết luận

Gọi `T*` là `best.score.total` và `T` là điểm cú người chơi.

| Trường hợp | Kết luận |
|---|---|
| Cú người chơi trùng `best.key` | `best` |
| `T ≤ T* + coachScoreTolerance` | `equivalent` |
| Người chơi chọn lỗ khác lỗ Planner và `T < T*` | `better`: đạt. Câu kết luận nói rõ Kế hoạch dọn bàn chỉ xét lỗ có góc cắt dễ nhất |
| Bước 0 là `fallback` hoặc `safety` mà cú người chơi qua vòng loại và có điểm | `better`: Planner không tìm được cú ăn ở lỗ dễ nhất, còn cú người chơi chọn vào lỗ được theo mô phỏng |
| `T > T* + coachScoreTolerance` | `wrong`, lỗi chính xác định ở mục 6.7 |

- So sánh có cả dấu bằng: chênh đúng bằng `coachScoreTolerance` vẫn đạt.
- So điểm bằng số thực của `OptionScore.total`, **không làm tròn**. Hai cú có `total` bằng nhau thì xếp theo thứ tự thử (đúng luật hoà của `bestOf`), nên danh sách *cũng đạt* luôn tất định.
- Có nhiều cú đạt thì đáp án hiện tới `coachEquivalentsShown` cú, dưới tiêu đề *"Các cú cũng đạt"*. Coach không nói cú nào trong số đó *tốt nhất tuyệt đối*.

### 6.6 Khi nào nói "chưa đủ dữ liệu"

| Tình huống | Kết luận | Tính lần thử? |
|---|---|---|
| Lõi quá giờ ở cú người chơi chọn | `undecided(timeout)` | Không |
| Người chơi chọn **Phòng thủ**, Planner có cú ăn, và vị trí sau cú ăn tốt nhất **không tốt** (`best.score.position > zoneGood`) hoặc bước 0 là `fallback` | `undecided(potVsSafety)`: Planner không bao giờ so cú ăn với cú thủ (spec Planner mục 5.5) | Không. Lần làm kết thúc với kết quả `undecided`, và người chơi được xem cú ăn của Planner |
| Người chơi chọn **Phòng thủ**, Planner có cú ăn và vị trí ≤ `zoneGood` | `wrong(shouldPot)` | Có |
| Người chơi chọn **Phòng thủ**, bước 0 là `safety` | `best` | — |
| Người chơi chọn **Ăn bi**, bước 0 là `safety` | Chấm theo mục 6.4. Bị loại thì `wrong` kèm lỗi cụ thể; qua vòng loại thì `better` (mục 6.5) | Có |

Bàn không thật sự cho đủ dữ liệu (ví dụ bi chồng lên nhau) thì không bao giờ được đưa ra làm tình huống: bộ sinh và test thư viện chặn từ trước (mục 8, 9).

### 6.7 Lỗi chính (`CoachFault`) và dữ liệu kết luận

```
enum CoachFault {
  pocketUnmakeable, scratch, objectMissed, blocked, noNextShot,  // hỏng cú
  shouldPot, shouldSafety,                                         // ăn hay thủ
  pocketWorse, spinUnneeded, strokeWorse, powerWorse,              // kém hơn
}
```

`CoachVerdict{outcome, fault?, unmakeable?, scratchPocket?, blocker?, playerTrace?, playerScore?, nearest?}`

- `shouldSafety`: người chơi chọn Ăn bi khi bước 0 là `safety`, và cú đó hỏng ở bước 1–4. Lỗi hỏng cụ thể vẫn giữ trong `verdict`, để gợi ý 1 nói đúng hậu quả.
- Với kết luận `wrong` mà cú vẫn có điểm, **`nearest`** là cú trong `accepted` cần đổi **ít thông số nhất** so với cú người chơi chọn. Đếm thông số khác nhau trong {lỗ, áp phê, kiểu đánh, lực}. Hoà thì ưu tiên chỉ khác lực, rồi chỉ khác kiểu đánh, rồi chỉ khác áp phê, rồi theo thứ tự trong `accepted`. Lỗi chính là thông số đầu tiên khác nhau theo thứ tự lỗ → áp phê → kiểu đánh → lực:
  - lỗ khác → `pocketWorse`;
  - người chơi có áp phê, `nearest` không có → `spinUnneeded`;
  - kiểu đánh khác → `strokeWorse`;
  - chỉ lực khác → `powerWorse`, kèm hướng: `nearest.power` nhỏ hay lớn hơn.
- Hàm `nearestAccepted(answer, accepted)` thuần, có test riêng, và là nguồn duy nhất cho gợi ý 2.

---

## 7. Gợi ý và đáp án (`hints.dart`, `reveal.dart`)

Ba hàm trả **dữ liệu** (sealed class kèm tham số). `Vi.coachHint…` và `Vi.coachReveal…` dựng câu từ dữ liệu đó. Không hàm nào trả `String`.

### 7.1 Gợi ý 1: hỏi về hậu quả (`hintOne(verdict, reference) → HintOne`)

Mục đích: người chơi tự nhìn hậu quả cú mình chọn (tong_hop §3.4). Bàn vẽ đường đi mô phỏng của chính cú người chơi.

| Lỗi | Dữ liệu | Câu hỏi (mục 15) |
|---|---|---|
| `pocketUnmakeable(cueBlocked/objectBlocked)` | bi, lỗ | `coachHint1PathBlocked` |
| `pocketUnmakeable(tooThin)` | lỗ | `coachHint1TooThin` |
| `pocketUnmakeable(ghostOffTable/overlap)` | lỗ | `coachHint1GhostOff` |
| `scratch` | lỗ chết cái | `coachHint1Scratch` |
| `objectMissed` | bi, lỗ | `coachHint1Missed` |
| `blocked` | số bi chắn | `coachHint1Blocker` |
| `noNextShot` | bi kế tiếp | `coachHint1NoNext` |
| `shouldPot` | bi | `coachHint1ShouldPot` |
| `shouldSafety` | dùng dòng của lỗi hỏng cụ thể ở trên | — |
| `pocketWorse` / `strokeWorse` / `powerWorse` mà **vùng vị trí của người chơi kém hơn** vùng của `nearest` | bi kế tiếp | `coachHint1Position` |
| `spinUnneeded`, hoặc các lỗi `…Worse` mà **cùng vùng vị trí** | — | `coachHint1Simpler` |

Vùng vị trí của một cú xếp theo `score.position`: **tốt** khi ≤ `zoneGood`, **tạm được** khi ≤ `zoneFair`, còn lại là **khó**. Hàm `zoneOf(double)` dùng đúng hai hằng số của Planner.

### 7.2 Gợi ý 2: chỉ ra thông số cần đổi (`hintTwo(verdict, reference) → HintTwo`)

Mục đích: thu hẹp chỗ cần nghĩ, nhưng không nói giá trị đúng.

| Lỗi | Gợi ý | Vẽ thêm |
|---|---|---|
| `pocketUnmakeable`, `pocketWorse` | `coachHint2Pocket(bi)` | — |
| `scratch`, `blocked`, `objectMissed`, `noNextShot` | Có `nearest` cùng lỗ thì nói thông số của `nearest` như hàng dưới; không có thì `coachHint2Pocket` | vùng điều tốt nếu có bi kế tiếp |
| `spinUnneeded` | `coachHint2NoSpin` | — |
| `strokeWorse` | `coachHint2Stroke` | vùng điều tốt |
| `powerWorse` | `coachHint2PowerLess` hoặc `coachHint2PowerMore`, theo hướng của `nearest` | vùng điều tốt |
| `shouldPot` | `coachHint2Pot(bi)` | — |
| `shouldSafety` | `coachHint2Safety(bi)` | — |

Vùng điều tốt dùng `ZoneGridJob` với **cùng** `after` và `CandidateFinder` như lúc chấm, nên ô xanh trên bàn đúng là điều cách chấm thưởng điểm. Kèm theo là câu `coachHint2Zone(bi kế tiếp)`.

Khi tầng Planner dùng là tầng 2 (chỉ áp phê mới cứu được cú) mà người chơi không áp phê, `nearest` là cú có áp phê. Gợi ý 2 khi đó là `coachHint2NeedSpin`.

### 7.3 Đáp án (`buildReveal(reference, verdicts) → Reveal`)

Hiện khi trả lời sai lần thứ 3, khi bấm *Xem đáp án*, hoặc sau khi đạt (lúc đó tiêu đề là *Lời giải*).

1. **Cú tốt nhất theo cách chấm của Kế hoạch dọn bàn**: `coachRevealShot(bi, lỗ, kiểu đánh, lực)`.
2. **Áp phê**, chỉ khi `best.key.spin` có áp phê. Mẫu câu của chủ sản phẩm (05/10):
   > *"Cú này cần áp phê {trái/phải} {0.5/1} đầu cơ. Hãy ngắm như đánh tâm bi, bù trừ áp phê bằng {B}% BHE, {100−B}% FHE với lực {nhẹ/trung bình/mạnh}."*

   `B` là `step.sawsBhePercent`: một nguồn, Planner đã tính. Chữ chỉ lực lấy từ `sawsSpeed(power)`. Không có vế "ngắm lệch", không có số độ.
3. **Độ chịu sai số lực**: dùng lại `Vi.planTolerance` với `step.tolerance`.
4. **Nếu trượt**: dùng lại `Vi.planMissAdvice` với `step.missAdvice`.
5. **Vì sao** (`revealReasons`, hàm thuần). Mỗi lý do là một dữ liệu, sinh từ chênh lệch từng khoản của `OptionScore` giữa cú tốt nhất và **cú gần nhất người chơi đã chọn**:
   - vùng vị trí của cú tốt nhất cho bi kế tiếp → `coachReasonZone`;
   - vùng của cú người chơi, hoặc hậu quả hỏng (chết cái, bị chắn, không vào, không còn cú sau) → `coachReasonYour…`;
   - `tech` của người chơi lớn hơn vì có áp phê → `coachReasonNoSpin`;
   - `tech` lớn hơn vì kiểu đánh → `coachReasonStroke`;
   - `power` lớn hơn, cùng vùng vị trí → `coachReasonPower`;
   - số lần chạm băng của bi cái (thông tin, không phải lỗi) → dùng lại `Vi.planRailInfo`.

   Chỉ khoản nào **thật sự khác** mới thành lý do. Không có câu lý do cố định.
6. **Các cú cũng đạt**: tối đa `coachEquivalentsShown` cú trong `accepted`, trừ `best`.
7. **Bước 0 là phòng thủ**: dùng lại `planStepLines` cho bước phòng thủ (câu `Vi.planSafety` và dòng cú thủ có sẵn). Kèm `coachRevealSafetyNote`, nói rõ Giai đoạn A chỉ chấm lựa chọn phòng thủ, chưa chấm cú thủ.
8. **Kết luận `undecided(potVsSafety)`**: hiện cú ăn của Planner kèm `coachRevealPotVsSafety`.

Bàn vẽ cú tốt nhất bằng `PlannerPainter` (`PlannerScene.step = reference.step`), có vùng điều tốt. Đường cú người chơi vẫn giữ, vẽ mờ, để hai cú so được bằng mắt.

---

## 8. Sinh tình huống (`generator.dart`, `rng.dart`)

### 8.1 Nhóm nào có tình huống

| `SkillCategory` | `CoachTopic` | Planner kiểm được gì |
|---|---|---|
| aiming | `aiming` | Chọn lỗ: có nhiều lỗ, có lỗ bị chắn hoặc quá mỏng |
| position | `position` | Kiểu đánh và lực để có vị trí cho bi kế tiếp |
| safety | `safety` | Thấy bi nhưng hết đường ăn (`SafetyReason.noPot`), nên phải phòng thủ |
| kick | `kick` | Bị đui (`snookered`): phải A băng |
| breakShot, bank | — | Planner không tính. Thẻ nói *chưa có tình huống* |

### 8.2 Số ngẫu nhiên tái tạo được

- `CoachRng` là bộ sinh Park–Miller: `x ← x × 48271 mod (2³¹ − 1)`. Tích lớn nhất nhỏ hơn 2⁴⁷, nên trên web (số Dart là số thực 53 bit) vẫn ra **đúng y** như trên Android và iOS. Không dùng `dart:math Random`, vì không có gì bảo đảm thuật toán của nó giống nhau giữa các nền tảng.
- Seed lấy từ đồng hồ khi bấm *Bắt đầu* và nằm trong khoá tình huống: `gen-v1-{topic}-{difficulty}-{seed}`. Cùng khoá thì ra **cùng vị trí bi** trên mọi máy.
- Vị trí bi làm tròn tới `coachPositionQuantum`.
- Lõi vật lý dùng `sin`, `cos`; các hàm này có thể lệch ở chữ số cuối giữa web và máy. Đáp án tính lại trên từng máy nên có thể khác rất nhỏ. Bản ghi lần làm chỉ lưu kết quả của người chơi, không lưu đáp án, nên chuyện này không ảnh hưởng gì.

### 8.3 Ràng buộc cho thế bàn giống thật

Áp cho mọi thế bàn sinh ra:

- 9 bi: các bi mục tiêu là các số liên tiếp từ `k` tới 9 (thế giữa ván). Luôn có bi 9.
- Mọi tâm bi nằm trong mặt chơi (`table.contains`). Hai bi bất kỳ (kể cả bi cái) cách nhau ≥ đường kính bi + `coachBallGap`.
- Tâm bi cách điểm lỗ ≥ `coachMinPocketClearance`.
- Mỗi bi có xác suất `coachFrozenRailChance` nằm sát băng (tâm cách mép băng nửa bi), giống thế bàn thật.
- Bi cái không nằm trên điểm đặt bi (*foot spot*); thế bàn giữa ván không bắt đầu từ thế phá.

### 8.4 Độ khó

`coachDifficultyFor(insight)` trả về:

- mức thuần thục null hoặc < 50 → `easy`;
- từ 50 tới 74 → `medium`;
- từ 75 trở lên → `hard`.

Hai ngưỡng 50 và 75 là `PracticeConstants.weakCutoff` và `strongCutoff`. Spec chỉ đặt tên, không đặt số: dùng đúng hằng số đang có. Người chơi đổi mức bằng chip.

| Mức | Số bi | Góc cắt của bi phải chạm, theo `bandFor` của `difficulty.dart` |
|---|---|---|
| Dễ | 3 | `easy` hoặc `medium` |
| Vừa | 4–5 | `medium` hoặc `hard` |
| Khó | 6–7 | `hard` hoặc `veryHard` |

Riêng nhóm Phòng thủ và A băng, độ khó đổi số bi chắn quanh bi phải chạm (2 / 3–4 / 5–6). Không dùng góc cắt.

### 8.5 Điều kiện theo nhóm

**Lượt hình học** (`proposeLayout`, rẻ, thử tới `coachGeometryTries` lần):

| Nhóm | Điều kiện |
|---|---|
| `aiming` | Bi phải chạm có ≥ 2 lỗ đánh được (`evaluateShot` ra `Makeable`), và có ≥ 1 lỗ bị chắn hoặc quá mỏng. Lỗ có góc cắt nhỏ nhất **không phải** lỗ gần bi nhất, để cách chọn lỗ theo cảm giác không tự ra đúng |
| `position` | Có ≥ 1 lỗ đánh được, góc cắt đúng dải độ khó. Còn ≥ 2 bi sau bi phải chạm, để Planner chấm được vị trí và nhìn trước bi thứ hai |
| `safety` | `canSee(cue, bi)` đúng, `bestPocket` null: bước 0 chắc chắn là phòng thủ với lý do `noPot` |
| `kick` | `canSee` sai với bi phải chạm: bị đui, chỉ còn A băng (Nhảy bi và Mát xê không thuộc phạm vi) |

Cách sinh thế bàn Phòng thủ và A băng có chủ đích, không đợi gặp may: đặt bi phải chạm trước, rồi đặt bi chắn lên đường bi → lỗ (cách điểm lỗ một khoảng, như `jawBlocker` của test), hoặc lên đường bi cái → bi (cho A băng).

**Lượt vật lý** (`acceptsForTopic`, sau khi có `CoachReference`; chỉ cho `aiming` và `position`, tối đa `coachPhysicsTries` thế bàn):

- bước 0 là `normal` (không phải `fallback` hay `safety`);
- `position`: `best.score.position ≤ zoneFair`, **và** ít nhất 1/3 số phương án của tầng bị loại hoặc nằm ngoài `accepted`, để lựa chọn thật sự có ý nghĩa;
- `aiming`: `accepted` có ≥ 1 cú, và mọi cú vào lỗ gần nhất (nếu khác lỗ Planner chọn) bị loại hoặc nằm ngoài `accepted`.

Thế bàn không đạt thì sinh thế khác với seed kế tiếp của cùng `CoachRng`. Vì vậy cùng seed ban đầu vẫn ra cùng tình huống cuối cùng.

### 8.6 Khi không sinh được

Hết số lần thử thì lấy một tình huống **thư viện** cùng nhóm, ưu tiên tình huống người chơi chưa làm (xem bảng lần làm). Màn hình hiện `coachGenerateFailed`. Thư viện cũng không có thì hiện `coachNoSituation`. Không bao giờ hạ điều kiện để cố ra một thế bàn.

### 8.7 Tính trước

Khi tham chiếu của tình huống đang làm đã xong, `CoachJob` sinh sẵn tình huống kế tiếp (cùng nhóm và độ khó) trong nền, lát 4 ms. Bấm *Tình huống mới* thì bàn mới hiện ngay.

---

## 9. Thư viện tình huống mẫu (`library.dart`)

### 9.1 Định dạng

```dart
final class CoachLibraryEntry {
  const CoachLibraryEntry({
    required this.id,        // 'pos-rail-1', ổn định, dùng trong đường dẫn và bản ghi
    required this.topic,     // CoachTopic
    required this.game,      // GameType.nineBall; tenBall chỉ khi sơ đồ gốc cần
    required this.cue,       // Cham
    required this.balls,     // List<(int number, Cham at)>
    required this.source,    // nguồn: 'BU_Exam-I_Fundamentals.pdf, trang 6, hình 1'
                             // hay 'planner_tables.dart railTable (c43c74a)' hay 'seed gen-v1-…'
  });
}
const coachLibrary = <CoachLibraryEntry>[ … ];
```

- Vị trí đo bằng **chấm** như `bu_layouts.dart`, đổi sang cm bằng `chamToTable`. Cùng một sơ đồ vẽ đúng trên bàn 7, 8 và 9 feet.
- **Không có trường đáp án nào**: không lỗ, kiểu đánh hay lực. Đáp án luôn do `CoachJob` tính.
- Hằng số trong mã Dart, không đặt trong cơ sở dữ liệu. Thư viện giống sơ đồ BU: là nội dung của bản app, chủ sản phẩm duyệt qua màn xem; người chơi không sửa được.

### 9.2 Bộ đầu tiên (12 tình huống, 3 mỗi nhóm)

| Nhóm | Lấy từ | Ghi chú |
|---|---|---|
| position | `railTable`, `cornerFollowTable` trong `planner_tables.dart`; F6 hình 1 (bi cái và 3 bi cố định) | Hai bàn Planner đã được chủ sản phẩm xem qua `planner.mjs`. Chép từ cm sang chấm (÷ 31,75) |
| aiming | `typicalNineBallTable` (bi 5 chắn lỗ giữa, phải đi lỗ góc); F1 (bi cái cố định, một bi, lỗ góc dưới phải); một thế do người soạn dựng từ bộ sinh (mục 9.3) | F1 chỉ có một bi, nên không chấm vị trí: chấm lỗ, vòng loại và các khoản phạt |
| safety | `noPotTable`, `blockedEverywhereTable`; một thế do người soạn dựng | |
| kick | `snookerOneRailTable`, bàn hai băng cùng tệp; S5 (bi 1 bị cụm 9 bi che), bản Bachelors vị trí 1 | S5 có bi 1–10, nên là bàn **10 bi** |

Các thế BU có bi cái tự do (S1–S4) không đưa vào bộ đầu: người soạn sẽ phải tự đặt bi cái, tức là thêm một lựa chọn chưa có nguồn. Để sau, khi chủ sản phẩm chỉ chỗ đặt bi cái.

### 9.3 Cách soạn thêm

1. Test dò bàn `test/domain/coach/generator_probe_test.dart` (tag `probe`, bỏ qua mặc định như `fixture_probe_test`) sinh N tình huống mỗi nhóm từ các seed cố định. Với mỗi tình huống, test in khoá, vị trí bi theo chấm và cú tốt nhất.
2. Người soạn mở từng khoá trên Chrome (`/coach/situation?topic=…&seed=…`), rồi đưa những thế đẹp lên màn thư viện để chủ sản phẩm duyệt.
3. Thế được duyệt chép vào `coachLibrary` với `source: 'seed gen-v1-…'`.

### 9.4 Màn xem thư viện (`/coach/library`)

Danh sách theo nhóm. Mỗi dòng có bàn thu nhỏ (`PlannerPainter` không có bước), id và nguồn. Chạm vào dòng thì mở tình huống. Có `?i=` để mở thẳng một mục, giống `/rank/layouts`: kịch bản Chrome chụp lần lượt từng mục cho chủ sản phẩm duyệt.

### 9.5 Test thư viện

Với **mọi** mục trong thư viện:

- vị trí hợp lệ theo mục 8.3, trừ luật số liên tiếp và luật lỗ khi `source` là sơ đồ BU;
- `id` không trùng;
- chạy `CoachJob` tới khi có tham chiếu, và tham chiếu khớp nhóm theo đúng điều kiện mục 8.5. Mục nào không khớp thì **bỏ khỏi thư viện**, không sửa vị trí bi cho vừa.

---

## 10. Coach Recommendation (`coach_stats.dart`, `coach_recommendation.dart`)

### 10.1 Không trùng Trang chủ

Trang chủ đã có *Gợi ý hôm nay*: nhóm, lý do, bài tập, bài đọc, chuỗi ngày và giờ tập. Thẻ Coach **không** hiện lại những thứ đó. Thẻ chỉ dùng `TodayRecommendation.cat` để Coach và Trang chủ cùng nói một nhóm (D5). Phần còn lại của thẻ là dữ liệu chỉ Coach có.

### 10.2 `computeCoachRecommendation`

**Vào:** `TodayRecommendation?`, `PlayerIntelligence`, các lần làm Coach (`CoachAttempt`), các bài kiến thức, `today`.
**Ra:** `CoachRecommendation{topic, topicReason, stats, recurring?, tool?}`:

1. **Chủ đề** (`topic`, `topicReason`):
   - nhóm của gợi ý hôm nay có tình huống → nhóm đó, lý do `sameAsToday`;
   - nếu không → nhóm đầu tiên trong `pi.weak` có tình huống, lý do `weakest`;
   - nếu không → nhóm có tình huống mà mức thuần thục thấp nhất (null đứng trước), theo thứ tự `newcomerOrder`, lý do `lowest`.

   Nhóm của gợi ý hôm nay không có tình huống (Phá, Cân bi) thì thẻ thêm câu `coachTopicUnsupported`.
2. **Số liệu** (`summarizeCoachAttempts`): với từng nhóm, xét `coachStatsWindow` lần làm gần nhất, bỏ các lần `undecided`. `solved` là số lần đạt mà không xem đáp án. Ít hơn `coachStatsMin` lần thì là *chưa đủ dữ liệu*.
3. **Lỗi lặp lại**: lỗi đầu tiên của mỗi lần làm (`firstFault`), gom theo nhóm lỗi:
   - *chọn lỗ*: `pocketUnmakeable`, `pocketWorse`;
   - *chết cái*: `scratch`;
   - *đường bi bị chắn*: `blocked`;
   - *vị trí bi cái*: `noNextShot`, `strokeWorse`, `powerWorse`;
   - *áp phê thừa*: `spinUnneeded`;
   - *chọn ăn hay thủ*: `shouldPot`, `shouldSafety`.

   Nhóm lỗi nhiều nhất, có ≥ `coachRecurringMin` lần trong `coachStatsWindow` lần gần nhất, là lỗi lặp lại. Hoà thì theo thứ tự liệt kê ở trên.
4. **Công cụ** (PRD §8 nêu đích danh Mô phỏng góc cắt cho lỗi ngắm lặp lại):
   - *chọn lỗ* → Mô phỏng góc cắt;
   - *vị trí bi cái*, *chết cái* → Kế hoạch dọn bàn;
   - *áp phê thừa* → bài kiến thức đầu tiên thuộc nhóm `position`, nếu có. Không có thì không gợi ý, không thay bằng bài nhóm khác.

### 10.3 Thẻ trên màn Coach

Từ trên xuống: lý do chọn nhóm, số liệu của nhóm đó (giải k/n hoặc chưa đủ dữ liệu), lỗi lặp lại kèm nút công cụ, và nút **Luyện tình huống {nhóm}**. Nút này mở luôn `/coach/situation`.

---

## 11. Dữ liệu, lưu trữ và đồng bộ (**quyết định cần duyệt**, Q2)

### 11.1 Có nên lưu không

Đề xuất **có lưu và có đồng bộ**:

- Thẻ gợi ý (mục 10) cần tỉ lệ giải và lỗi lặp lại.
- Giai đoạn B: Coach Chat cần dữ liệu thật để trả lời *"Tôi đang yếu kỹ năng nào?"*.
- Bộ sinh cần biết tình huống thư viện nào người chơi đã làm (mục 8.6).
- Lý do đồng bộ: người chơi làm trên điện thoại rồi xem trên web phải thấy cùng số liệu, giống mọi dữ liệu tập khác.

Phương án rẻ hơn là chỉ lưu trên máy, không đồng bộ: đỡ một collection Directus và một dịch vụ đồng bộ. Đổi lại, số liệu khác nhau giữa các máy, và Giai đoạn B phải đồng bộ bù về sau.

### 11.2 Drift, schema 10 → 11 (chỉ thêm bảng)

**`CoachAttemptRows`**, mỗi lần làm một dòng, chỉ thêm, không sửa:

| Cột | Kiểu | Nghĩa |
|---|---|---|
| `id` | text, khoá chính | uuid |
| `userId` | text | |
| `situationKey` | text | `gen-v1-…` hoặc `lib:{id}` |
| `topic` | text | `CoachTopic.name` |
| `difficulty` | text | `CoachDifficulty.name` |
| `answers` | text (JSON) | ≤ 3 câu trả lời: `{kind, pocket?, stroke?, power?, spinSide?, spinTips?, outcome, fault?}` |
| `outcome` | text | `solved1` · `solved2` · `solved3` · `revealed` · `revealedEarly` · `undecided` |
| `firstFault` | text, nullable | `CoachFault.name` của lần sai đầu tiên |
| `scoringVersion` | int | `coachScoringVersion` |
| `startedAt`, `finishedAt` | dateTime | |
| `syncedAt` | dateTime, nullable | |

Một lần làm được ghi khi tình huống **kết thúc**: đạt, đã hiện đáp án, hoặc `undecided`. Rời màn giữa chừng thì không ghi. Bộ mã hoá JSON `answers` là hàm thuần trong `lib/data/database/coach_converters.dart`, có test chạy hai chiều.

### 11.3 Không đưa vào Player Intelligence ở Giai đoạn A

Điểm thuần thục đo năng lực **thực hiện** cú đánh (drill log). Coach đo năng lực **đọc bàn và chọn cú**. tong_hop §15.3: không suy loại năng lực này từ loại kia khi chưa có quy tắc kiểm chứng. Số liệu Coach chỉ dùng ở thẻ gợi ý (mục 10) và ở `CoachContext` (mục 12).

### 11.4 Directus và đồng bộ

- Collection `coach_attempts`: các cột như trên, quyền Player, quan hệ `user_created` CASCADE, giống `achievements`. Thêm vào `deploy/directus/bootstrap.mjs` và `verify.mjs`. Tạo trên production **phải hỏi chủ sản phẩm ngay lúc đó**.
- `CoachSyncService` (`lib/data/sync/coach_sync.dart`) dùng cùng vòng đời với `RoadmapSyncService`:
  - đẩy các dòng có `syncedAt` null; `RECORD_NOT_UNIQUE` coi như đã đồng bộ; lỗi 4xx khác thì đỗ lại như `_rejected`;
  - kéo về khi đăng nhập;
  - thử lại sau 30 s.
- Repository `CoachAttemptRepository` ghi Drift trước, rồi mới đồng bộ. Stream `watchAttempts(userId)` cho thẻ gợi ý.

---

## 12. Ranh giới Giai đoạn B (chỉ phác)

Giai đoạn B thêm **Coach Chat** dùng Claude. Giai đoạn A chỉ chuẩn bị chỗ nối, không gọi LLM nào.

```dart
/// Mọi điều LLM được biết — số đã tính sẵn, LLM không tính lại (PlayerIntelligence doc).
final class CoachContext {
  final Map<SkillCategory, CategoryInsight> skills;   // từ PlayerIntelligence
  final PlayerRank? rank;
  final RoadmapStepFacts? currentStep;                // từ buildRoadmap
  final Map<CoachTopic, CoachTopicStats> coachStats;  // từ summarizeCoachAttempts
  final CoachSituationFacts? lastSituation;           // khoá, kết luận, Reveal (dữ liệu, không câu chữ)
  Map<String, Object?> toFacts();                     // JSON khoá ổn định, có test chụp mẫu
}

abstract interface class CoachChatBackend {
  Future<CoachChatReply> reply(CoachContext context, List<CoachChatTurn> history, String question);
}
```

- `buildCoachContext(...)`, hàm thuần trong `coach_context.dart`, có trong Giai đoạn A, có test. `CoachChatBackend` chỉ có giao diện, chưa có bản cài.
- Luật cho Giai đoạn B, ghi trước để không ai vô tình làm khác:
  1. LLM chỉ diễn giải và đặt câu hỏi (tong_hop §15.4). Mọi con số trong câu trả lời phải có trong `toFacts()`.
  2. Gọi LLM qua máy chủ trung gian. Khoá API không bao giờ nằm trong app.
  3. Có bộ lọc sau câu trả lời: chặn lời khuyên ngắm theo độ (cùng mẫu dò của test mục 14.2) và số không có trong facts. Bị chặn thì trả *chưa đủ dữ liệu*.
  4. Câu hỏi về một tình huống được trả lời bằng `Reveal` của Giai đoạn A. LLM không tự chấm cú.
- Giai đoạn B có spec riêng: chọn model, máy chủ, chi phí, lưu hội thoại.

---

## 13. Tốc độ

Đo trên Chrome giả lập điện thoại (cổng đo của các dự án trước). Android và iOS chạy Dart biên dịch AOT, nhanh hơn web, nên web là chặn trên.

| Việc | Ngân sách | Căn cứ |
|---|---|---|
| Bàn hiện ra sau khi bấm Bắt đầu (lượt hình học) | ≤ 100 ms | `proposeLayout` chỉ dùng `evaluateShot`, `bestPocket`, `canSee` |
| Tham chiếu sẵn sàng, nhóm Ngắm bi / Vị trí, tình huống thư viện | ≤ 1 s | Bước 1 của Planner 0,36–0,46 s trên Chrome |
| Tham chiếu sẵn sàng, sinh ngẫu nhiên kèm lượt vật lý | ≤ 3 s (trung vị ≤ 1,5 s) | Tối đa `coachPhysicsTries` lần chạy bước 1, và có tính trước (mục 8.7) |
| Tham chiếu sẵn sàng, Phòng thủ / A băng | ≤ 5 s tới khi có cú thủ để hiện đáp án | Cổng cú thủ hiện có. Chấm lựa chọn Phòng thủ **không** phải chờ cú thủ |
| Chấm một câu trả lời cùng lỗ Planner, không áp phê | ≤ 50 ms | Mọi lần mô phỏng đã có trong cache |
| Chấm một câu trả lời khác lỗ, hoặc có áp phê khi tầng 1 có phương án | ≤ 500 ms | 4 lần mô phỏng: cú, lực −15 %, lực +15 %, nhìn trước |
| Khung hình trong lúc tính | trung vị ≤ 17 ms, p95 ≤ 20 ms | `sliceBudget` 4 ms, như Planner |

Test đo tốc độ `test/domain/coach/coach_perf_test.dart` (tag `perf`) chạy trên Dart VM, cổng bằng một nửa số Chrome như `planner_perf_test`:

- 20 seed cố định mỗi nhóm: thời gian tới khi có tham chiếu, trung vị ≤ 750 ms và p95 ≤ 1500 ms;
- chấm câu trả lời khác lỗ: trung vị ≤ 250 ms;
- lát trung vị ≤ 1,5 × `sliceBudget`.

---

## 14. Kiểm thử

### 14.1 Lõi (`test/domain/coach/`), trên lõi vật lý thật

- **`coach_job_test`**:
  - chạy từng lát (nhiều cỡ lát) cho đúng y kết quả chạy một mạch;
  - tham chiếu khớp `planToEnd(setup).first` (cùng bi, lỗ, kiểu đánh, lực, áp phê);
  - huỷ giữa chừng thì không báo thêm sự kiện;
  - `PlannerJob` dùng chung `SimCache` vẫn cho kế hoạch y hệt khi không dùng chung (thêm vào `planner_job_test`).
- **`grading_test`**, dùng các bàn của `planner_tables.dart`:
  - `railTable`: chọn đúng cú Planner chọn (Đánh đứng bi 45 %) → `best`; một cú khác có `total` trong dung sai (đo trên bàn lúc viết test, ghi vào chú thích như `planner_tables.dart`) → `equivalent`; một cú ngoài dung sai → `wrong` với đúng lỗi;
  - `cornerFollowTable`: Đánh cu lê → `wrong(scratch)`, lỗ chết cái đúng;
  - bi chắn trên đường → `wrong(blocked)`, đúng số bi chắn;
  - lỗ bị chắn → `pocketUnmakeable(objectBlocked)`; lỗ quá mỏng → `tooThin`;
  - chọn lỗ khác có điểm thấp hơn → `better`;
  - mốc dung sai: chênh đúng bằng `coachScoreTolerance` → đạt; chênh lớn hơn một chút → sai;
  - hoà điểm: thứ tự `accepted` theo thứ tự thử;
  - `noPotTable` + Phòng thủ → `best`; `noPotTable` + Ăn bi → `wrong(shouldSafety)` kèm lỗi hỏng;
  - Phòng thủ khi vị trí cú ăn tốt nhất không tốt → `undecided(potVsSafety)`; khi tốt → `wrong(shouldPot)`;
  - lõi quá giờ (dùng `aim` giả của `planner_tables.dart`) → `undecided(timeout)` và không tính lần thử.
- **`nearest_accepted_test`**: đổi ít thông số nhất; luật hoà; hướng lực.
- **`hints_test`**: mỗi dòng của bảng mục 7.1 và 7.2 có ít nhất một bàn thật cho ra đúng loại gợi ý. Gợi ý 2 không bao giờ chứa giá trị đúng (lỗ, kiểu đánh, mức lực) của `nearest`.
- **`reveal_test`**:
  - lý do chỉ có khi khoản điểm thật sự khác;
  - có áp phê thì câu SAWS dùng đúng `step.sawsBhePercent` và `sawsSpeed`;
  - bước phòng thủ dùng `planStepLines`.
- **`generator_test`**:
  - `CoachRng` khớp chuỗi số chuẩn của Park–Miller (hệ số 48271: giá trị thứ 10 000 từ seed 1 là 399 268 537);
  - cùng seed → cùng thế bàn;
  - mọi thế bàn sinh ra qua ràng buộc mục 8.3;
  - từng nhóm đạt điều kiện mục 8.5;
  - hết số lần thử thì lấy thư viện;
  - độ khó đúng số bi và dải góc.
- **`library_test`**: mục 9.5.
- **`coach_stats_test`**, **`coach_recommendation_test`**:
  - cửa sổ 10 lần; ít hơn 5 lần → chưa đủ dữ liệu;
  - lỗi lặp lại ≥ 3 lần và luật hoà;
  - nhóm Phá / Cân bi → câu nhóm chưa có tình huống, chuyển sang nhóm kế tiếp;
  - công cụ theo nhóm lỗi.
- **`coach_context_test`**: `toFacts()` có khoá ổn định (chụp mẫu).

### 14.2 Không bịa (`test/domain/coach/coach_no_fabrication_test.dart`)

Cùng tinh thần với `test/domain/no_fabrication_test.dart`. Để file riêng để không đụng file của Lộ trình.

1. **Đổi bàn thì câu đổi**: hai bàn chỉ khác vị trí bi chắn → gợi ý 1 nêu đúng số bi chắn khác nhau.
2. **Đổi câu trả lời thì kết luận đổi**: trên cùng một bàn, chạy cả 15 cú tầng 1. Kết luận và gợi ý của mỗi cú phải khớp điểm và lý do loại của cú đó. Cú bị loại không bao giờ được *Đạt*.
3. **Đổi nhóm yếu thì Coach đổi**: dùng `_playerWeakAt` kiểu cũ cho `position` rồi `safety` → `computeCoachRecommendation().topic` đổi theo; trên màn Coach, chip chọn sẵn đổi theo.
4. **Không có số độ**: dựng mọi câu `Vi.coach…` trên một ma trận đầu vào (mọi lỗi × mọi lỗ × mọi kiểu đánh × mọi áp phê × 3 bàn) và kiểm:
   - không câu nào chứa "°";
   - không câu nào khớp `/ngắm\s+(lệch|dày hơn|mỏng hơn)/i` hay chứa "lệch điểm ngắm";
   - không câu nào chứa "tối ưu".
5. **Áp phê theo mẫu SAWS**: mọi câu áp phê của đáp án chứa "ngắm như đánh tâm bi", "% BHE", "% FHE" và một trong *nhẹ / trung bình / mạnh*. Số BHE bằng `sawsBhePercent` tính độc lập với cùng quãng, lực và kiểu đánh.
6. **Chưa đủ dữ liệu là nói thẳng**: các trường hợp mục 6.6 ra đúng câu *chưa đủ dữ liệu*, không bao giờ ra câu *Đạt* hay *Chưa đạt*.
7. **Thư viện không có đáp án**: dời bi cái của một mục thư viện → đáp án đổi. Test chỉ đọc đáp án từ `CoachJob`, không có nơi nào khác để đọc.

### 14.3 Chuỗi tiếng Việt (`test/core/strings/vi_coach_test.dart`)

Mỗi loại lỗi ra câu khác nhau. Thuật ngữ đúng bảng đã chốt: Đánh đứng bi, Đánh cu lê, Đánh trô bi, Áp phê, Chết cái, A băng, đầu cơ, Bị đui. Không có chữ cấm: "bi ma", "lọt bi cái", "đầu gậy".

### 14.4 Kiến trúc

- Thêm test *"lõi Coach không phụ thuộc Flutter"* cho `lib/domain/coach`, cùng mẫu với lõi Lộ trình.
- Test sẵn có *"không màn hình nào chứa chuỗi tiếng Việt viết thẳng"* phủ luôn `lib/features/coach`.
- `Routes.all` có thêm `coachSituation`, `coachLibrary`; smoke test mở được cả hai, bằng một `CoachJob` giả qua provider override để không chạy vật lý trong widget test.

### 14.5 Giao diện, Chrome và điện thoại

- **Widget test** `test/features/coach/`:
  - chọn cú: Chấm chỉ bật khi đủ lựa chọn;
  - chạm lỗ trên bàn và chạm chip lỗ cho cùng kết quả;
  - đủ chuỗi sai 1 → gợi ý 1 → sai 2 → gợi ý 2 → sai 3 → đáp án;
  - *Xem đáp án* sớm → hỏi lại → `revealedEarly`;
  - chọn lại đúng cú vừa sai thì không tính lần thử;
  - `undecided` thì không tính lần thử;
  - thẻ gợi ý hiện đúng số liệu;
  - bàn 360 × 640 dp (điện thoại) không tràn; vùng chạm lỗ ≥ 24 px.
- **`tool/e2e/coach.mjs`**, cùng khung với `planner.mjs`:
  - mở `?lib=` từng nhóm; trả lời sai theo kịch bản rồi đọc nhãn semantics của gợi ý 1, 2 và đáp án;
  - mở `?topic=position&seed=…` hai lần → cùng nhãn bàn;
  - đo thời gian tham chiếu và khung hình;
  - chụp màn `/coach/library?i=` từng mục cho chủ sản phẩm.

  Chạy trên bản cục bộ và trang thật.
- **Điện thoại**: CI Android (`android.yml`) chạy toàn bộ `flutter test`. Chủ sản phẩm thử bản debug APK trên máy thật: chạm chọn lỗ ở bàn dọc, cuộn bảng điều khiển trong lúc đang tính.

### 14.6 Dừng để chủ sản phẩm xem

Sau khi có màn tình huống trên Chrome, **dừng lại**. Chủ sản phẩm làm 10 tình huống, xem gợi ý và đáp án có đúng cách người chơi giỏi đánh giá không, và chỉnh `coachScoreTolerance` nếu cần. Sau đó mới soạn thêm thư viện.

---

## 15. Chuỗi tiếng Việt mới (**chờ chủ sản phẩm duyệt từng dòng**)

Đặt trong `vi.dart`, phần `// ─── Coach tình huống`. `{…}` là tham số do hàm có tên điền vào. Dùng lại câu sẵn có: `coachTitle`, `coachComing`, `simStroke`, `simPowerPreset`, `simSpinChip`, `simSpinLabel`, `simPocket`, `simDisclaimer`, `planTolerance`, `planMissAdvice`, `planRailInfo`, `planSafety`, `planSearchingSafety`, `planStepLines`.

**Màn Coach và thẻ gợi ý**

| Tên | Câu |
|---|---|
| `coachSituationsTitle` | Tình huống |
| `coachSituationsBody` | Xem một thế bàn, chọn cú đánh, app chấm theo cách chấm của Kế hoạch dọn bàn. |
| `coachTopicLabel` | Nhóm kỹ năng |
| `coachDifficultyLabel` | Độ khó |
| `coachDifficulty(d)` | Dễ · Vừa · Khó |
| `coachStart` | Bắt đầu |
| `coachLibraryLink` | Thư viện tình huống › |
| `coachLibraryTitle` | Thư viện tình huống |
| `coachChatSoonTitle` | Trò chuyện với huấn luyện viên (sắp có) |
| `coachRecTitle` | Nên luyện gì |
| `coachRecSameAsToday(skill)` | Cùng nhóm với gợi ý hôm nay: {skill}. |
| `coachRecWeakest(skill)` | {skill} là nhóm yếu nhất có tình huống để luyện. |
| `coachRecLowest(skill)` | Bắt đầu với {skill}. |
| `coachTopicUnsupported(skill)` | Chưa có tình huống cho nhóm {skill}. |
| `coachRecSolved(solved, total)` | Giải được {solved}/{total} tình huống gần nhất mà không xem đáp án. |
| `coachRecNotEnough(n, min)` | Mới làm {n} tình huống — cần {min} để nhận xét. |
| `coachRecRecurring(label, count, total)` | Lỗi lặp lại: {label} ({count}/{total} lần gần nhất). |
| `coachFaultGroup(g)` | chọn lỗ · chết cái · đường bi bị chắn · vị trí bi cái · áp phê thừa · chọn ăn hay thủ |
| `coachRecToolSimulator` | Tập chọn lỗ với Mô phỏng góc cắt |
| `coachRecToolPlanner` | Xem đường bi cái với Kế hoạch dọn bàn |
| `coachRecToolArticle(title)` | Đọc: {title} |
| `coachRecPractice(skill)` | Luyện tình huống {skill} |

**Màn tình huống**

| Tên | Câu |
|---|---|
| `coachSituationTitle(skill)` | Tình huống — {skill} |
| `coachPrompt(n)` | Tới lượt bạn. Bi phải chạm: bi {n}. Bạn đánh thế nào? |
| `coachChoicePot` | Ăn bi |
| `coachChoiceSafety` | Phòng thủ |
| `coachPickPocket` | Chạm vào lỗ bạn chọn. |
| `coachStrokeLabel` | Kiểu đánh |
| `coachPowerLabel` | Lực |
| `coachSubmit` | Chấm |
| `coachComputing` | Đang tính… |
| `coachTryCount(k, max)` | Lần thử {k}/{max} |
| `coachShowAnswer` | Xem đáp án |
| `coachShowAnswerConfirm` | Xem đáp án ngay? Tình huống này sẽ tính là chưa tự giải. |
| `coachShowAnswerYes` | Xem |
| `coachShowAnswerNo` | Tự làm tiếp |
| `coachSameAnswer` | Bạn vừa chọn đúng cú này — thử đổi một thông số. |
| `coachNext` | Tình huống mới |
| `coachGenerateFailed(skill)` | Chưa tạo được tình huống {skill} mới — đây là một tình huống trong thư viện. |
| `coachNoSituation(skill)` | Chưa có tình huống {skill}. |
| `coachModelNote` | Chấm theo mô phỏng và cách chấm của Kế hoạch dọn bàn — bàn thật có thể khác. |
| `coachTableSummary(count, n)` | Bàn tình huống: bi cái và {count} bi. Bi phải chạm: bi {n}. |
| `coachPocketButton(pocket)` | Lỗ {pocket} |

**Kết luận**

| Tên | Câu |
|---|---|
| `coachVerdictBest` | Đạt — đúng cú tốt nhất theo cách chấm của Kế hoạch dọn bàn. |
| `coachVerdictEquivalent` | Đạt — gần bằng cú tốt nhất, chênh trong mức cho phép. |
| `coachVerdictBetter` | Đạt — Kế hoạch dọn bàn chỉ xét lỗ có góc cắt dễ nhất; cú của bạn được chấm tốt hơn cú đó. |
| `coachVerdictBetterNoPot` | Đạt — Kế hoạch dọn bàn không tìm được cú ăn ở lỗ dễ nhất; theo mô phỏng, cú của bạn vào lỗ. |
| `coachVerdictWrong` | Chưa đạt. |
| `coachUndecidedTimeout` | Chưa đủ dữ liệu để chấm: không mô phỏng được cú bạn chọn. Lần này không tính. |
| `coachUndecidedPotVsSafety` | Chưa đủ dữ liệu để chấm: có cú ăn nhưng vị trí sau đó không tốt, và Kế hoạch dọn bàn không so cú ăn với cú thủ. |

**Gợi ý 1: câu hỏi về hậu quả**

| Tên | Câu |
|---|---|
| `coachHint1PathBlocked(n, pocket)` | Từ bi cái, có đường thông tới bi ảo để đưa bi {n} vào lỗ {pocket} không? |
| `coachHint1TooThin(pocket)` | Cắt vào lỗ {pocket} có quá mỏng không? |
| `coachHint1GhostOff(pocket)` | Bi ảo cho lỗ {pocket} nằm ở đâu — bi cái có tới được chỗ đó không? |
| `coachHint1Scratch(pocket)` | Xem đường bi cái của cú bạn chọn: sau khi chạm bi, bi cái đi về đâu? Chuyện gì xảy ra ở lỗ {pocket}? |
| `coachHint1Missed(n, pocket)` | Với cú này, bi {n} có vào lỗ {pocket} không? |
| `coachHint1Blocker(k)` | Đường đi của cú này có lọt qua bi {k} không? |
| `coachHint1NoNext(next)` | Bi cái dừng ở vòng trắng. Từ đó, bi {next} còn lỗ nào đánh được không? |
| `coachHint1Position(next)` | Bi cái dừng ở vòng trắng. Từ đó, đánh bi {next} vào lỗ nào được, và có dễ không? |
| `coachHint1Simpler` | Bi cái tới được vị trí — có cách nào ít xoáy hơn hoặc lực nhẹ hơn mà vẫn tới đó không? |
| `coachHint1ShouldPot(n)` | Bi {n} thật sự không có lỗ nào đánh được sao? Nhìn lại từng lỗ trước khi chọn phòng thủ. |

**Gợi ý 2: thông số cần đổi**

| Tên | Câu |
|---|---|
| `coachHint2Pocket(n)` | Thử lỗ khác cho bi {n}. |
| `coachHint2NoSpin` | Thử không áp phê. |
| `coachHint2NeedSpin` | Không áp phê thì không cú nào ổn ở lỗ này — thử áp phê. |
| `coachHint2Stroke` | Giữ lỗ này, thử đổi kiểu đánh. |
| `coachHint2PowerLess` | Giữ lỗ và kiểu đánh, thử lực nhẹ hơn. |
| `coachHint2PowerMore` | Giữ lỗ và kiểu đánh, thử lực mạnh hơn. |
| `coachHint2Pot(n)` | Bi {n} có cú ăn được — thử chọn Ăn bi. |
| `coachHint2Safety(n)` | Bi {n} không có cú ăn chắc chắn — cân nhắc phòng thủ. |
| `coachHint2Zone(next)` | Ô xanh là chỗ bi cái nên dừng để đánh bi {next} dễ; ô vàng là tạm được. |

**Đáp án**

| Tên | Câu |
|---|---|
| `coachRevealTitle` | Đáp án |
| `coachSolutionTitle` | Lời giải |
| `coachRevealShot(n, pocket, stroke, power)` | Bi {n} vào lỗ {pocket} — {stroke}, lực {power}%. |
| `coachRevealSpin(side, tips, bhe, speed)` | Cú này cần áp phê {trái/phải} {tips} đầu cơ. Hãy ngắm như đánh tâm bi, bù trừ áp phê bằng {bhe}% BHE, {100−bhe}% FHE với lực {nhẹ/trung bình/mạnh}. |
| `coachRevealWhy` | Vì sao |
| `coachZoneWord(z)` | tốt · tạm được · khó |
| `coachReasonZone(zone, next)` | Bi cái dừng ở vùng {zone} cho bi {next}. |
| `coachReasonYourZone(zone, next)` | Cú của bạn: bi cái dừng ở vùng {zone} cho bi {next}. |
| `coachReasonYourScratch(pocket)` | Cú của bạn: bi cái rơi lỗ {pocket} (chết cái). |
| `coachReasonYourBlocked(k)` | Cú của bạn: đường bi đi qua bi {k}. |
| `coachReasonYourMissed(n, pocket)` | Cú của bạn: bi {n} không vào lỗ {pocket}. |
| `coachReasonYourNoNext(next)` | Cú của bạn: từ chỗ bi cái dừng, bi {next} không còn lỗ nào đánh được. |
| `coachReasonYourUnmakeable(n, pocket)` | Cú của bạn: không có đường đưa bi {n} vào lỗ {pocket}. |
| `coachReasonNoSpin` | Không cần áp phê — càng ít xoáy càng ít sai số. |
| `coachReasonStroke(best, yours)` | {best} ít sai số hơn {yours} ở thế này, theo cách chấm của Kế hoạch dọn bàn. |
| `coachReasonPower(best, yours)` | Lực {best}% đã đủ đưa bi cái tới vị trí; lực {yours}% dễ sai số hơn. |
| `coachRevealEquivalents` | Các cú cũng đạt: |
| `coachRevealSafetyNote` | Phần này chỉ chấm lựa chọn phòng thủ; cú thủ bên dưới là cú Kế hoạch dọn bàn tìm được, chưa chấm cú thủ của bạn. |
| `coachRevealPotVsSafety` | Kế hoạch dọn bàn tìm được cú ăn dưới đây, nhưng không so nó với cú thủ — cả hai lựa chọn đều chưa thể chấm là sai. |

---

## 16. Câu hỏi cho chủ sản phẩm

Chủ sản phẩm trả lời cả năm câu ngày **21/10/2026**. Cột cuối là quyết định; nơi nào trong spec còn ghi khác thì cột này thắng.

| # | Câu hỏi | Đề xuất của người viết | Quyết định (21/10/2026) |
|---|---|---|---|
| Q1 | Câu "đáp án sau 2 lần sai" nghĩa là người chơi trả lời tối đa **3 lần** (sai → gợi ý 1 → sai → gợi ý 2 → sai → đáp án), hay đáp án hiện ngay ở **lần sai thứ 2**, tức là bỏ gợi ý 2? | **3 lần**, đủ hai gợi ý (D3). Đổi lại chỉ cần sửa một hằng số `coachMaxAnswers` | **Đã chốt: 3 lần** (sai → gợi ý 1 → sai → gợi ý 2 → sai → đáp án). `coachMaxAnswers = 3`. Nút *Xem đáp án* luôn bấm được |
| Q2 | Lưu và đồng bộ từng lần làm tình huống (bảng `coach_attempts`, mục 11), nhưng không đưa vào điểm thuần thục? | **Có, lưu và đồng bộ, không đưa vào điểm thuần thục.** Thẻ gợi ý và Giai đoạn B cần dữ liệu này; trộn vào điểm thuần thục là suy năng lực đọc bàn ra năng lực thực hiện | **Đã chốt: lưu và đồng bộ**, **không** đưa vào điểm thuần thục |
| Q3 | Mức chênh điểm còn tính là đạt: `coachScoreTolerance = 3` điểm (bằng phạt Đánh cu lê)? | **3 điểm**, rồi chỉnh sau buổi chủ sản phẩm thử 10 tình huống (mục 14.6) | **Đã chốt: `coachScoreTolerance = 3`**, chỉnh sau |
| Q4 | Người chơi chọn Phòng thủ khi Planner có cú ăn nhưng vị trí sau đó không tốt: nói *chưa đủ dữ liệu* (không tính đúng sai)? | **Đúng như vậy.** Planner không so cú ăn với cú thủ, nên chấm là sai thì thành bịa | **Đã chốt: nói *chưa đủ dữ liệu***, không tính là một lần thử, và hiện **cả hai cú**: cú ăn của Planner và cú thủ |
| Q5 | Câu áp phê của Coach theo đúng mẫu 05/10 (*"Hãy ngắm như đánh tâm bi, bù trừ áp phê bằng …% BHE…"*). Có sửa luôn dòng áp phê ở màn Mô phỏng (vẫn còn vế "ngắm lệch đi") cho khớp không? | **Coach dùng mẫu mới ngay.** Sửa màn Mô phỏng là một việc nhỏ, làm riêng sau khi chủ sản phẩm duyệt câu, để dự án này không đụng màn đã chạy thật | **Đã chốt: sửa luôn trong dự án này.** Bỏ vế *"điểm ngắm cần lệch…"* và *"ngắm lệch đi…"* của `Vi.simSquirt`, thay bằng đúng câu áp phê mẫu SAWS mà Coach dùng (một hàm chung), và sửa test của nó. Quyết định này thay D7 và dòng `Vi.simSquirt` ở mục 2 |

---

## 17. Chia việc

Mỗi việc có tệp riêng. Hai việc không cùng sửa một tệp, trừ chỗ ghi rõ thứ tự. `vi.dart` chỉ do **T3** sửa; các việc khác chỉ gọi hàm `Vi` mà T3 đã khai.

| Việc | Nội dung | Tệp sở hữu | Cần xong trước |
|---|---|---|---|
| **T0: Chỗ nối và hợp đồng** | `SimCache`/`MissingSimulation`, `PlannerJob(cache:)`, `sawsSpeed`. Các tệp kiểu dữ liệu: `coach_constants`, `coach_topic`, `situation`, `answer`, `verdict` (enum, class, chưa có logic), `attempt`, `difficulty`. Test kiến trúc lõi Coach | `lib/domain/planner/sim_cache.dart` (mới), `planner_job.dart`, `lib/domain/table_geometry/saws.dart`, `lib/domain/coach/{coach_constants,coach_topic,situation,answer,verdict,attempt,difficulty}.dart`, `test/architecture_test.dart`, `test/domain/planner/sim_cache_test.dart`, `test/domain/table_geometry/saws_test.dart` | — |
| **T1: Việc tính và chấm** | `CoachJob`, `CoachReference`, `evaluateAnswer`, `gradeAnswer`, `nearestAccepted`, `firstBlocker`, `zoneOf` | `lib/domain/coach/{coach_job,reference,evaluation,grading}.dart`, `test/domain/coach/{coach_job,grading,nearest_accepted}_test.dart` | T0 |
| **T2: Gợi ý và đáp án (dữ liệu)** | `hintOne`, `hintTwo`, `buildReveal`, `revealReasons` | `lib/domain/coach/{hints,reveal}.dart`, `test/domain/coach/{hints,reveal}_test.dart` | T0 (dùng T1 khi chạy test trên bàn thật; viết song song, chốt test sau T1) |
| **T3: Chuỗi tiếng Việt** | Mọi câu mục 15, thành hàm nhận dữ liệu T0 và T2 khai | `lib/core/strings/vi.dart` (phần Coach), `test/core/strings/vi_coach_test.dart` | T0 (kiểu dữ liệu gợi ý chốt cùng T2) |
| **T4: Bộ sinh** | `CoachRng`, `proposeLayout`, `acceptsForTopic`, `coachDifficultyFor`, tính trước | `lib/domain/coach/{rng,generator}.dart`, `test/domain/coach/{generator,generator_probe}_test.dart` | T0; `acceptsForTopic` cần `CoachReference` của T1 |
| **T5: Thư viện** | 12 mục đầu, test thư viện | `lib/domain/coach/library.dart`, `test/domain/coach/library_test.dart` | T0; test chạy đủ khi có T1 |
| **T6: Lưu trữ và đồng bộ** | Schema 11, `CoachAttemptRows`, bộ mã hoá, repository, `CoachSyncService`, Directus bootstrap/verify | `lib/data/database/database.dart` (+ `database.g.dart`), `lib/data/database/coach_converters.dart`, `lib/data/repositories/coach_attempt_repository.dart`, `lib/data/sync/coach_sync.dart`, `lib/core/providers/repository_providers.dart` (thêm một provider), `deploy/directus/{bootstrap,verify}.mjs`, `test/data/...` tương ứng, `test/data/database/migration_test.dart` | T0 |
| **T7: Gợi ý Coach và ranh giới B** | `summarizeCoachAttempts`, `computeCoachRecommendation`, `buildCoachContext`, `CoachChatBackend` | `lib/domain/coach/{coach_stats,coach_recommendation,coach_context}.dart`, `test/domain/coach/{coach_stats,coach_recommendation,coach_context}_test.dart` | T0 |
| **T8: Giao diện** | Màn Coach, màn tình huống, `CoachPainter` (bọc `PlannerPainter` + lớp vùng chạm lỗ, đường cú người chơi), bảng chọn cú, thẻ gợi ý, màn thư viện, route, provider | `lib/features/coach/presentation/*`, `lib/core/router/{routes,app_router}.dart`, `lib/core/providers/coach_providers.dart`, `test/features/coach/*`, `test/smoke/all_routes_test.dart` | T1, T2, T3, T4, T5, T6, T7 |
| **T9: Không bịa, tốc độ, Chrome** | Test mục 14.2, `coach_perf_test`, `tool/e2e/coach.mjs` | `test/domain/coach/coach_no_fabrication_test.dart`, `test/domain/coach/coach_perf_test.dart`, `tool/e2e/coach.mjs` | T1–T7 (test không bịa); T8 (Chrome) |

Có thể chạy song song: sau T0, các việc **T1, T4, T5, T6, T7** độc lập về tệp. **T2 và T3** chạy song song với nhau, nhưng chốt kiểu dữ liệu gợi ý trong buổi đầu của T2. **T8, T9** làm sau cùng.

Sau T9: dừng cho chủ sản phẩm xem (mục 14.6) → merge → deploy bằng `deploy/publish.sh` → hỏi chủ sản phẩm trước khi tạo collection `coach_attempts` trên production → chạy `coach.mjs` trên trang thật.
