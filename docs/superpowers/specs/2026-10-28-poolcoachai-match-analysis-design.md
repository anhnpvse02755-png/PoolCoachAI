# PoolCoachAI — Phân tích trận vào Intelligence, Coach và Lộ trình

**Ngày:** 28/10/2026. **Tiền đề:** `main` 0b392d7, gồm quản lý trận (sửa trận, xóa mềm `is_deleted`) và schema 13.
**Quyết định:** chủ dự án giao toàn quyền ("bạn tự quyết đi, làm theo thứ tự đó"). Mọi lựa chọn dưới đây là **quyết định của Claude**, ghi rõ lý do để chủ dự án đọc lại và sửa khi cần.

## 1. Mục đích

Hiện app chỉ *đếm* trận và cú đánh (Statistics). Player Intelligence, gợi ý hôm nay, Coach và Lộ trình chỉ dùng bài tập (DrillLog) và bài BU. Một người chơi tập tốt mà ra trận vẫn thua sẽ không nhận được lời khuyên nào từ chính các trận đó.

Dự án này làm bốn việc:
1. Biến dữ liệu trận thành **kết luận có nguồn**.
2. Trả lời câu hỏi "tại sao tôi thua trận vừa rồi".
3. Đưa các kết luận đó vào gợi ý, Coach và Lộ trình.
4. Hoàn tất ba mục Lộ trình mà spec 15/10 §10 để ngoài phạm vi.

## 2. Nguyên tắc (giữ nguyên, không ngoại lệ)

- **Không bịa** (README quy tắc 1):
  - Mọi kết luận đến từ hàm thuần Dart, có tên và có test.
  - Câu chữ là khuôn có tham số trong `vi.dart`; domain không chứa chuỗi tiếng Việt.
  - Thiếu dữ liệu thì nói thẳng là thiếu.
  - Phép thử của `no_fabrication_test.dart` phải mở rộng sang phân tích trận.
- **Lời khuyên làm được tại bàn:** không có độ, không có "ngắm lệch". Phân tích trận chỉ nói tỷ lệ, số lần và nhóm kỹ năng, kèm bài tập nên làm.
- **Hạng chỉ đổi qua bài BU** (spec hạng Q15). Tín hiệu từ tập luyện và trận đấu chỉ là gợi ý làm lại bài BU, không bao giờ ghi vào `PlayerRank`.
- **LLM không quyết định tiến độ hay hạng** (README quy tắc 2). Chat chỉ diễn giải các fact đã tính sẵn.
- **Cỡ mẫu tối thiểu.** Dưới ngưỡng thì không kết luận, theo mẫu `cue_win_rate.dart`.

## 3. Dữ liệu có sẵn (không đổi mô hình cú đánh)

Mỗi `MatchShot` có các trường: `shooter`, `type` (phá / thường / phòng thủ), `outcome` (vào / trượt / phạm lỗi / chết cái), `positionOutcome?` (tùy chọn), `rackNumber`, `shotNumber`. `PoolMatch` có `rackWinners`.

**Quyết định:** không thêm trường mới vào cú đánh, như số bi, lỗ, hay lý do phạm lỗi.
- Lý do: mỗi trường thêm là một thao tác nữa khi ghi tại bàn, và người chơi sẽ bỏ ghi.
- Các trường hiện có đã đủ cho mọi phân tích ở §4.
- Có thể mở lại khi có Camera/Vision.

Cú đánh là tùy chọn, nên một ván có thể không có cú nào.
- **Ván có ghi cú:** có ít nhất một cú.
- **Ván ghi đủ:** cú đầu của ván là cú phá, và `shotNumber` liên tục.
- Mọi kết luận về chuỗi trong ván chỉ tính trên *ván ghi đủ*, và luôn kèm số ván làm cơ sở.

## 4. Mô-đun `lib/domain/match_analysis/`

Đây là hàm thuần, không phụ thuộc Flutter, Riverpod hay `Vi`. Đầu ra chỉ có enum, số đếm và cỡ mẫu.

### 4.1 Phân tích một ván (`analyzeRack`)

Dựng từ `rackWinners[i]` và các cú có `rackNumber == i + 1`:

| Kết quả | Cách tính |
|---|---|
| `breaker` | Người đánh cú phá đầu ván. Ván không có cú phá thì để `null`. |
| `breakResult` | Kết quả cú phá: vào, trượt (khô), phạm lỗi, chết cái. |
| `breakAndRun` | Người phá thắng ván, và đối thủ không có cú nào trong ván (chỉ xét ván ghi đủ). |
| `runOut` | Người chơi thắng ván bằng một lượt liền, không để đối thủ đánh tiếp, tính từ cú cuối của đối thủ. Chỉ xét ván ghi đủ. |
| `turnovers` | Mỗi lần lượt chuyển từ người chơi sang đối thủ, kèm **nguyên nhân** là kết quả cú cuối của người chơi trước khi mất lượt: trượt tấn công, phòng thủ, phạm lỗi, chết cái, phá khô. |
| `lostRackCause` | Nếu người chơi thua ván: nguyên nhân của lần mất lượt **cuối cùng** trước khi đối thủ đánh tới hết ván. Có thể là `opponentBreakAndRun`, hoặc `unknown` khi ván không ghi đủ. |

### 4.2 Phân tích nhiều trận (`analyzeMatches`)

**Đầu vào:** các trận đã hoàn tất, chưa xóa, của tài khoản; mặc định 10 trận gần nhất, đặt ở hằng `MatchAnalysisConstants.recentMatches`. **Đầu ra:** `MatchAnalysis`.

- **Tổng:** số trận, số ván thắng/thua, số ván có ghi cú, số ván ghi đủ.
- **Phá** (chỉ cú phá của người chơi): số cú, tỷ lệ vào, khô, phạm lỗi, chết cái; số ván phá-và-dọn trên số ván người chơi phá.
- **Tấn công:** tỷ lệ trượt ở cú thường của người chơi.
- **Điều bi:** tỷ lệ điều bi hỏng trên số cú có ghi `positionOutcome`. Thêm **tỷ lệ trượt cú kế tiếp sau một lần điều bi hỏng**, so với sau một lần điều bi tốt. Chỉ số này cho thấy điều bi hỏng có thực sự làm mất lượt hay không.
- **Phòng thủ:**
  - Số cú phòng thủ và tỷ lệ phòng thủ thành công. Thành công là khi cú kế tiếp của đối thủ trượt, phạm lỗi hoặc chết cái.
  - Tỷ lệ cú phòng thủ trên tổng số lần mất lượt chủ động.
- **Lỗi:** số lần phạm lỗi và số lần chết cái trên số cú.
- **Nguyên nhân mất ván:** đếm `lostRackCause` qua các ván thua.
- **Tín hiệu yếu theo nhóm kỹ năng** (`matchWeaknesses`): xem §4.3.

### 4.3 Quy cú đánh về nhóm kỹ năng (`shotSkillMap`, có test)

| Dấu hiệu trong trận | Nhóm |
|---|---|
| Cú phá của người chơi (khô / phạm lỗi / chết cái) | `breakShot` |
| Cú thường trượt | `aiming` |
| Điều bi hỏng, hoặc chết cái ở cú thường | `position` |
| Cú phòng thủ thất bại (đối thủ có cú tiếp theo vào bi) | `safety` |

Phạm lỗi ở cú thường **không** quy về nhóm nào: không biết là lỗi chạm bi hay bị đui. `kick` và `bank` không có tín hiệu trong dữ liệu trận.

Một nhóm là **yếu trong trận** khi đạt cả hai điều kiện:
- **Cỡ mẫu:** có ít nhất 3 trận và ít nhất 10 lần thử thuộc nhóm.
- **Tỷ lệ thất bại** vượt ngưỡng của nhóm:

| Nhóm | Thất bại khi | Ngưỡng |
|---|---|---|
| Phá | khô, phạm lỗi hoặc chết cái | ≥ 50% |
| Tấn công | cú thường trượt | ≥ 35% |
| Điều bi | điều bi hỏng | ≥ 40% |
| Phòng thủ | phòng thủ thất bại | ≥ 50% |

Các ngưỡng là **giá trị khởi điểm**, nằm trong `match_analysis_constants.dart`, và có thể chỉnh khi có dữ liệu thật. Các nhóm yếu được sắp theo mức vượt ngưỡng, nhóm vượt nhiều nhất đứng đầu.

## 5. "Tại sao tôi thua trận vừa rồi" (Play)

Trên thẻ trận **đã hoàn tất** có nút "Phân tích trận" (`Vi.matchAnalysisOpen`). Nút mở bảng phân tích chỉ của trận đó, dùng `analyzeMatches([match])`, gồm:

- **Tỷ số**, cùng số ván có ghi cú và số ván ghi đủ.
- **Nguyên nhân mất ván**, xếp theo số lần. Ví dụ khuôn câu: "Mất {n} ván sau khi trượt cú tấn công".
- **Phá:** phá {a} ván, vào bi {b}, phá-và-dọn {c}. Có thêm số liệu của đối thủ nếu có ghi.
- **Điều bi và lỗi:** điều bi hỏng {x}/{y}, phạm lỗi {f}, chết cái {s}.
- **"Nên luyện":** tối đa 2 nhóm có tỷ lệ thất bại cao nhất trong trận, mỗi nhóm kèm bài tập được chọn bằng `pickDrillInCategory`. Một trận đơn lẻ thì bỏ yêu cầu 3 trận, nhưng vẫn cần ít nhất 5 lần thử trong nhóm. Câu chữ ghi rõ là "trong trận này".
- **Khi trận không có cú nào:** chỉ hiện tỷ số, kèm câu "Trận này chưa ghi cú đánh nên chưa phân tích được nguyên nhân. Ghi cú ở trận sau để xem phân tích."

## 6. Đưa phân tích vào các phần khác

### 6.1 Statistics

Thêm thẻ "Phân tích trận gần đây", dùng `analyzeMatches` trên 10 trận gần nhất:
- các chỉ số ở §4.2;
- các nhóm yếu trong trận;
- dòng cỡ mẫu "dựa trên {n} trận, {r} ván ghi đủ".

### 6.2 Gợi ý hôm nay (Home)

- Thêm `PickReason.matchWeakness` và quy tắc mới trong `pickCategoryForToday`. Thứ tự quy tắc: lịch hôm nay → giữ streak → **yếu trong trận** → yếu nhất theo bài tập → người mới → đang đi xuống → xoay vòng.
- **Lý do xếp quy tắc mới trước "yếu theo bài tập":** trận đấu là kết quả người chơi cần, bài tập chỉ là phương tiện. Một nhóm yếu ngay trong trận là ưu tiên thật.
- Câu hiển thị lấy từ `Vi.pickReason(matchWeakness, skill)` kèm tỷ lệ và cỡ mẫu.
- `todayRecommendationProvider` bắt đầu theo dõi `matchesProvider`, với cùng điều kiện sẵn sàng `hasValue && !isLoading`.

### 6.3 Player Intelligence

- `PlayerIntelligence` có thêm trường `matchWeak` (danh sách nhóm yếu trong trận, có thứ tự).
- Độ thuần thục từ bài tập (`mastery`) **không** trộn với tỷ lệ từ trận, vì hai thang đo khác nhau.
- `computePlayerIntelligence` nhận thêm `matches` (tùy chọn, mặc định rỗng), nên cả 3 nơi gọi hiện có vẫn chạy.
- Từ bài BU: `PlayerIntelligence` có thêm trường `buPercent`, là tỷ lệ điểm theo từng nhóm của bài BU gần nhất, quy về nhóm qua `bu_category_map.dart`. Đây là mục "đổ kết quả BU vào Player Intelligence" của spec 15/10 §10.
- Một nhóm **chưa có `mastery`** (chưa đủ 3 buổi tập) nhưng có `buPercent < 55` sẽ vào danh sách `weak`, kèm nguồn `bu`. Nhóm đã có `mastery` thì giữ `mastery` làm nguồn chính.

### 6.4 Coach

- **Coach tình huống:** thêm `CoachTopicReason.matchWeakness`. Nếu nhóm yếu trong trận có chủ đề Coach (ngắm, điều bi, phòng thủ, a băng), thẻ "Nên luyện gì" ưu tiên chủ đề đó.
- **Hỏi huấn luyện viên:**
  - `matchFactsOf` và `CoachContext.toFacts()` có thêm các khóa sau:
    - `matches.analysis`: các chỉ số ở §4.2 và danh sách nhóm yếu.
    - `matches.last.lostRackCauses` cùng `matches.last.break` / `position` / `fouls`.
  - Bộ lọc câu trả lời (`chat_filter.dart`) cho phép các con số đến từ fact.
  - Prompt và schema fact của `server/coach-chat` được cập nhật cùng lúc. Khóa mới chỉ được thêm vào; khóa cũ giữ nguyên.

### 6.5 Lộ trình

- **Chuẩn bị giải dùng dữ liệu trận:**
  - Trong `_tournament`, nhóm yếu trong trận đứng đầu, rồi đến nhóm mất điểm BU, rồi đến nhóm yếu theo bài tập.
  - Bước tập của nhóm yếu trong trận dùng lý do mới `StepReason.matchWeakness(category, failures, attempts)`.
  - Nếu trong 28 ngày qua có ít hơn 3 trận hoàn tất, thêm bước đầu tiên **"Đấu tập: ghi ít nhất {n} trận có ghi cú"**, với `StepKind.dauTap` và lý do `NotEnoughMatches(have, need)`. Bước này xong khi đủ trận.
- **Mục tiêu lên nhiều hạng một lúc:**
  - `PlayerGoal` có thêm `targetRank?`. Để trống nghĩa là hạng kế tiếp, giữ đúng hành vi cũ.
  - Ô chọn mục tiêu "Lên hạng" cho chọn từ hạng kế tiếp tới hạng A. Hạng A và PRO vẫn bị chặn như cũ (`lenHangBlock`).
  - Số điểm cần thêm bằng `buFloor(targetRank)` trừ tổng điểm hiện có.
  - Với **mỗi hạng trung gian** có một bước "Làm lại bài BU — mốc hạng {X}", đặt sau khối bài tập ứng với số điểm của mốc đó.
- **Gợi ý kiểm tra lại hạng** (`RankCheckSignal`, chỉ là gợi ý):
  - Chỉ phát khi đã có hạng `verified` và bài BU gần nhất cách ít nhất 28 ngày.
  - **Hướng xuống:** ít nhất 2 nhóm mà bài BU từng chấm đang có xu hướng `declining` theo bài tập, **hoặc** có ít nhất 2 nhóm yếu trong trận.
  - **Hướng lên:** ít nhất 2 nhóm `improving` và không nhóm nào `declining`.
  - Hiện ở thẻ hạng và dòng Lộ trình trên Home: "Kết quả tập gần đây ở {nhóm} đang đi xuống — làm lại bài BU để kiểm tra hạng {X}". Hướng lên dùng câu tương ứng.
  - Gợi ý **không** đổi `PlayerRank` và không đặt `warningRank`. Cảnh báo chính thức vẫn chỉ đến từ bài BU, đúng spec hạng Q15.

## 7. Dữ liệu và đồng bộ

- **Drift v14:** `player_goal_rows.target_rank`, nullable. Migration từ 13 → 14; giữ nguyên mục tiêu đang có.
- **Directus:**
  - Thêm `player_goals.target_rank` (string, nullable), cùng quyền create/update cho Player.
  - Kèm một kiểm tra mới trong `verify.mjs`.
  - Chạy bootstrap trên prod trước khi publish web.
- **Không đổi gì ở `pool_matches`:** mọi phân tích tính trên dữ liệu có sẵn.

## 8. Kiểm thử

- **Test domain cho từng hàm ở §4:**
  - ván ghi đủ / không đủ;
  - phá-và-dọn;
  - dọn bàn;
  - nguyên nhân mất lượt;
  - ngưỡng cỡ mẫu (9 lần thử thì không kết luận, 10 thì có);
  - trận không có cú.
- **Phép thử chống bịa:** đổi dữ liệu trận sao cho người chơi yếu điều bi thay vì tấn công. Gợi ý, thẻ Statistics, bảng phân tích trận, fact chat và thứ tự bước Lộ trình đều phải tự đổi theo.
- **Test kiến trúc:** domain không import `Vi` hay Flutter.
- **Test widget:** bảng phân tích trận (đủ dữ liệu, thiếu dữ liệu); thẻ Statistics; ô chọn hạng mục tiêu; gợi ý kiểm tra lại hạng.
- **Migration test:** 13 → 14, và tạo mới ở v14.
- **Coach-chat service:** test cho các khóa fact mới.
- **E2E live:** mở rộng `tool/e2e/match_drill_stats.mjs`:
  - ghi một trận có cú, mở "Phân tích trận", đọc nguyên nhân mất ván;
  - đặt mục tiêu lên 2 hạng và kiểm tra có bước mốc trung gian.

## 9. Thứ tự làm và phát hành

1. Mô-đun `match_analysis` và test.
2. Bảng "Phân tích trận" ở Play; thẻ Statistics.
3. Player Intelligence (`matchWeak`, `buPercent`) và gợi ý hôm nay.
4. Coach tình huống và fact cho chat (cả phía `server/coach-chat`).
5. Lộ trình: chuẩn bị giải, hạng mục tiêu (v14 + Directus), gợi ý kiểm tra lại hạng.
6. Cả bộ test → PR → CI → bootstrap và verify prod → merge → publish → kiểm tra trên Chrome.

## 10. Ngoài phạm vi

- Camera/Vision: chủ dự án để lại.
- Thêm trường cho cú đánh: xem §3.
- Phân tích theo từng đối thủ: tên đối thủ là chữ tự do, chưa có danh tính.
- Giải đấu: dự án 4 riêng.
- Skill Test: dự án 3 riêng.
