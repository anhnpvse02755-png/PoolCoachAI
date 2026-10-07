# PoolCoachAI — Thiết kế Kế hoạch dọn bàn (Run-out Planner)

**Ngày:** 07/10/2026 (thiết kế duyệt từng phần ngày 05/10/2026)
**Trạng thái:** đã duyệt hướng từng phần (5 phần), chờ duyệt bản viết
**Tiền đề:** lõi vật lý `lib/domain/table_physics/` và màn Mô phỏng góc cắt đã vào `main`, đã push và deploy (`0e17995`, 546 test + 1 test đo thời gian). PRD gốc là `PRD_RunOutPlanner.md`, bản đã sửa ngày 02/10 cho khớp lõi vật lý.

---

## 1. Mục tiêu

> Người chơi bày bàn (loại bàn, bi cái, các bi) → app tính cách dọn hết bàn. Mỗi bước nói rõ bi nào, lỗ nào, kiểu đánh, lực, bi cái dừng đâu → người chơi đánh xong ngoài đời thì bấm sang bước sau, hoặc đặt lại bi cái theo chỗ nó dừng thật để tính lại.

Tiêu chí thành công: chủ sản phẩm bày vài bàn quen thuộc và thấy kế hoạch giống cách một người chơi giỏi sẽ đi bàn.

Có bốn phần, cùng một kế hoạch:

1. Lõi Planner `lib/domain/planner/`, Dart thuần, không dùng Flutter (mục 4–5).
2. Màn nhập bàn và màn từng bước (mục 6–7).
3. Ba việc mang theo từ dự án lõi vật lý (mục 8).
4. Sửa `PRD_RunOutPlanner.md` cho khớp các quyết định mới (mục 9).

### Không thuộc phạm vi

Tối ưu toàn cục thứ tự bi trong 8 bi (chỉ nhìn trước 2 bi, như PRD §8) · mô phỏng quỹ đạo cú trượt thật cho gợi ý dư dày/mỏng · lập kế hoạch cho cú phòng thủ · bi thứ ba trở lên tham gia va chạm (chỉ kiểm chắn đường, như lõi vật lý) · độ dốc cơ Dốc trong Planner · hiệu chỉnh SAWS theo từng cây cơ · lưu bàn đã bày · chạy trong Web Worker hoặc trên máy chủ.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Áp phê chỉ là đường lui** (chủ sản phẩm chọn C): Planner thường chỉ thử đứng / trô / cu lê. Chỉ khi không phương án nào dùng được, Planner mới thử áp phê ½ và 1 đầu cơ, và bước đó kèm lời khuyên SAWS | Kế hoạch dễ thực hiện và tính nhanh; áp phê chỉ xuất hiện khi thật sự cần, trước khi phải chịu phòng thủ |
| 2 | **8 bi theo luật thật** (chọn A): người chơi chọn nhóm **Trơn** (1–7) hoặc **Sọc** (9–15), bi đối thủ là bi chắn, **bi 8 luôn đánh cuối**, bi áp chót được chọn để có vị trí tốt cho bi 8 | Giống trận thật; PRD gốc coi mọi bi là của mình |
| 3 | **Tính từng bước, đặt lại được bi cái** (chọn C): bước 1 hiện sau khoảng 1 giây, các bước sau tính tiếp trong nền. Khi bấm *Đã đánh xong*, người chơi có thể đặt bi cái đúng chỗ nó dừng ngoài bàn và tính lại từ đó | Không phải chờ cả bàn; ngoài đời bi cái hiếm khi dừng đúng chỗ dự kiến |
| 4 | **Một việc tính chia lát** chạy giữa các khung hình, kèm cắt tỉa sớm bằng hình học và lưu tạm (hướng 1) | Cùng mẫu với gợi ý chống chết cái của màn mô phỏng, tất định, test được trọn, chạy được trên điện thoại sau này. Đổi sang Web Worker sau mà không đổi lõi nếu đo thật thấy chậm |
| 5 | **Phạt áp phê**: ½ đầu cơ = 15, 1 đầu cơ = 20 | PRD §8 chỉ nói "cao hơn trô" (trô = 10) |
| 6 | **Thứ tự dự phòng 1 → 4** (mục 5.5) | Áp phê trước, rồi Đánh đứng bi 30% nếu vẫn vào lỗ an toàn, cuối cùng mới phòng thủ |
| 7 | **Bỏ vế "mỗi lần chạm hao khoảng 15% lực"** trong câu dội băng | Lõi vật lý tính hao lực thật, không còn con số 15% cố định |
| 8 | Đường đi lấy từ `aimShot` của lõi vật lý, cơ luôn ở độ dốc **Thường**, bù ném luôn bật | Đúng PRD đã sửa ngày 02/10 |
| 9 | **Không lời khuyên nào theo độ** | Nguyên tắc lời khuyên làm được. `aimOffsetDeg` chỉ dùng bên trong, không hiện lên màn |

### Thuật ngữ (chủ sản phẩm đã chốt 05/10)

| Trên màn | Nghĩa |
|---|---|
| **Kế hoạch dọn bàn** | Tên tính năng, tên thẻ và tiêu đề màn |
| **Trơn** · **Sọc** | Hai nhóm bi trong 8 bi: 1–7 · 9–15 |

Thuật ngữ cũ giữ nguyên: Đánh đứng bi · Đánh trô bi · Đánh cu lê · Áp phê trái/phải · Lệch N đầu cơ · Bi ảo · Dội băng · Chết cái · Vùng điều. Mọi chữ hiển thị nằm trong `lib/core/strings/vi.dart`.

---

## 3. Hằng số

Đặt ở `lib/domain/planner/planner_constants.dart`, tên bám PRD §4.

| Hằng số | Giá trị | Nguồn |
|---|---|---|
| `strokeCandidates` | đứng, cu lê, trô | PRD |
| `powerCandidates` | dùng lại `powerPresets` (30 · 45 · 60 · 75 · 90 %) | PRD, đã có trong `stroke.dart` |
| `powerJitter` | 15 (%) | PRD |
| `maxCutAngle` | 85° | PRD §5.1 |
| `blockedAngle` | 95° (góc tính cho mức lực bị chắn, chết cái hoặc trượt lỗ) | PRD §5.3 |
| `lookaheadPower` | 55 (%), Đánh đứng bi | PRD §5.3 |
| `zoneGood` · `zoneFair` | 35° · 55° | PRD §6.5b |
| `zoneCell` | 5 cm | PRD §6.5b |
| `bankPenalty` | 0 · 2 · 7 (0, 1, từ 2 băng) | PRD |
| `techPenalty` | đứng 0 · cu lê 3 · trô 10 | PRD |
| `sidePenalty` | ½ đầu cơ 15 · 1 đầu cơ 20 | **mới**, quyết định 5 |
| `powerPenaltyPerPercent` | 0.04 (lực/100 × 4) | PRD |
| `distanceWeight` | 0.01 / cm | PRD |
| `fallbackPower` | 30 (%), Đánh đứng bi | PRD §5.3 |
| `missAngleDeg` · `missTravel` | 5° · 110 cm | PRD §5.5 |
| `toleranceSamples` | 7 mức lực đều nhau trong ±15% | PRD §6.5b |
| `sliceBudget` | 8 ms mỗi lát | quyết định 4 |

---

## 4. Lõi `lib/domain/planner/`

| File | Việc nó làm |
|---|---|
| `table_setup.dart` | Đầu vào: loại bàn (`nineBall`, `tenBall`, `eightBall`), nhóm của người chơi khi 8 bi (`solids` / `stripes`), vị trí bi cái, danh sách bi. Mỗi bi có số, vị trí, vai trò: `mine`, `opponent`, `eight` |
| `legal_targets.dart` | Bi nào được đánh lúc này (mục 4.1) |
| `candidates.dart` | Cắt tỉa bằng hình học, chưa mô phỏng (mục 4.2) |
| `shot_options.dart` | Mô phỏng các phương án cho cặp bi–lỗ đã chọn, loại phương án hỏng, rồi tới các đường lui (mục 4.3, 5.5) |
| `scoring.dart` | Chấm điểm 4 tầng (mục 5), và hàm mới `bestAngleFrom(P, bi, bi chắn)`: góc cắt dễ nhất từ điểm P, dựng trên `bestPocket` |
| `miss_advice.dart` | Gợi ý dư dày / dư mỏng, đúng PRD §5.5 |
| `plan_step.dart` | Một bước của kế hoạch (mục 4.4) |
| `planner_job.dart` | Việc tính chia lát (mục 4.5) |
| `planner_constants.dart` | Hằng số mục 3 |

### 4.1 Bi được đánh

- **9 / 10 bi:** bi số nhỏ nhất còn trên bàn. Không đổi được.
- **8 bi:** mọi bi `mine` còn trên bàn; hết bi `mine` thì tới bi 8. Bi 8 không bao giờ được chọn khi còn bi `mine`.
- **Bi chắn:** mọi bi khác còn trên bàn, gồm bi `opponent`, bi 8 khi chưa tới lượt, và bi chưa tới lượt trong 9 / 10 bi.

### 4.2 Cắt tỉa trước khi mô phỏng

Với mỗi bi được đánh × 6 lỗ, loại cặp nếu góc cắt > `maxCutAngle`, hoặc đường bi cái → bi ảo, hay bi → lỗ bị bi chắn cắt ngang (`isPathClear`). Dùng lại `evaluateShot` / `bestPocket` của `table_geometry`.

- **9 / 10 bi:** với bi bắt buộc, giữ lỗ có góc cắt nhỏ nhất (PRD §5.1). Không lỗ nào còn thì bước này là **phòng thủ** và kế hoạch dừng.
- **8 bi:** chọn cặp bi–lỗ có góc cắt nhỏ nhất trong mọi bi được đánh (PRD §5.1).

Chỉ cặp đã chọn mới được mô phỏng vật lý.

### 4.3 Phương án cho cặp đã chọn

Thử `strokeCandidates × powerCandidates` (15 phương án) bằng `aimShot(... elevation: normal, compensate: true)`. Loại phương án nếu:

- `trace.cuePocket != null` (chết cái);
- `trace.objectPocket` khác lỗ đã chọn;
- `cueBefore`, `cueAfter` hay `objectPath` đi qua bi chắn;
- mô phỏng ném `SimulationTimeout` (coi như không dùng được, không làm hỏng việc tính).

Còn ít nhất một phương án thì chấm điểm theo mục 5. Không còn phương án nào thì đi theo thứ tự dự phòng ở mục 5.5.

### 4.4 `PlanStep`

Bám `PlanStep` của PRD §4, thêm những gì quyết định mới cần:

| Trường | Nghĩa |
|---|---|
| `kind` | `normal` · `fallback` (Đánh đứng bi 30%, không có vị trí tốt) · `safety` (phòng thủ, kế hoạch dừng) |
| `ballNum`, `pocket`, `cutAngle` | Bi, lỗ, góc cắt hình học |
| `stroke`, `power`, `spin` | Kiểu đánh, lực, áp phê (`SideSpin.none()` trừ khi phải dùng đường lui áp phê) |
| `cbFrom` | Điểm bi cái trước cú đánh |
| `trace` | `ShotTrace` của lõi vật lý. Điểm dừng là `trace.cueEnd` |
| `aimed` | `AimedShot`, để màn từng bước dùng lại dòng áp phê của màn mô phỏng. `aimOffsetDeg` không bao giờ hiện lên màn |
| `jitterEnds` | Điểm dừng khi lực −15% và +15% (cho thanh sai số lực); null nếu mức đó hỏng |
| `tolerance` | Số mức lực trong 7 mức còn cho vùng điều tốt / tạm được / xấu (mục 5.4) |
| `missAdvice` | Kết quả `missSafetyAdvice`; null khi là bi cuối |
| `sawsBhePercent` | Chỉ có khi dùng áp phê (lấy từ `saws.dart`) |
| `nextBallNum` | Bi kế tiếp mà vị trí được chấm theo; null khi là bi cuối |

**Bất biến:** `steps[i + 1].cbFrom` là **chính đối tượng** `steps[i].trace.cueEnd` (`identical`, không tính lại, không sao chép).

### 4.5 `PlannerJob`

- Tạo từ một `TableSetup`. Mỗi lần gọi `step(Duration budget)` làm việc tới khi hết `sliceBudget` rồi trả quyền cho giao diện. Mỗi khi xong một bước thì đẩy ra một sự kiện `stepReady(i, step)`; xong cả kế hoạch thì `done`.
- Màn hình gọi `step()` mỗi khung hình (cùng cách gợi ý chống chết cái đang chạy). Chạy từng lát phải cho **đúng y** kết quả như chạy một mạch.
- **Đặt lại bi cái:** tạo `PlannerJob` mới từ vị trí mới, với các bi còn lại sau bước đã đánh. Đó là kế hoạch mới; bất biến chỉ áp trong một kế hoạch.
- **Lưu tạm:** chấm vị trí cần "góc cắt dễ nhất cho bi kế tiếp từ điểm P". Kết quả được nhớ theo (P, bi kế tiếp, tập bi chắn) trong một kế hoạch, để thử lực ±15% và nhìn trước 2 bi không phải tính lại.
- Hủy được: rời màn hoặc sửa bàn thì bỏ việc tính đang chạy.

---

## 5. Chấm điểm (`scoring.dart`), điểm càng thấp càng tốt

Theo đúng PRD §5.3, áp lên lõi vật lý:

| Thành phần | Cách tính |
|---|---|
| Phạt dội băng | `trace.cueRailCount`: 0 → 0, 1 → 2, từ 2 → 7 |
| Phạt kỹ thuật | `techPenalty[stroke]` + `sidePenalty[spin]` (0 khi không áp phê) |
| Phạt lực | lực × 0.04 |
| Vùng điều chịu sai số (`robustDiff1`) | Từ `trace.cueEnd`, góc cắt dễ nhất để đánh bi kế tiếp (6 lỗ, bỏ lỗ bị chắn, `bestAngleFrom`). Đánh lại cùng kiểu đánh với lực −15% và +15%, lấy **góc xấu nhất** trong 3 mức. Mức nào chết cái, bị chắn hay bi mục tiêu không vào thì tính `blockedAngle` |
| Nhìn trước bi thứ 2 (`diff2`) | Giả định cú kế tiếp là Đánh đứng bi 55% vào lỗ dễ nhất. Mô phỏng thật để biết bi cái dừng đâu, rồi lấy góc cắt dễ nhất cho bi kế-kế-tiếp |
| Điểm vị trí | `max(robustDiff1, diff2)` khi có `diff2`, ngược lại `robustDiff1`. Minimax, không cộng |
| Khoảng cách | quãng từ bi ảo tới `trace.cueEnd` (cm) × 0.01 |

**Điểm = vị trí + dội băng + kỹ thuật + lực + khoảng cách.** Chọn phương án điểm thấp nhất; bằng điểm thì giữ phương án thử trước (thứ tự cố định: kiểu đánh theo `strokeCandidates`, rồi lực tăng dần), để kết quả tất định.

- Từ `trace.cueEnd` không lỗ nào khả thi cho bi kế tiếp → loại phương án (PRD).
- **Bi cuối cùng:** không có phần vị trí và khoảng cách, chỉ tính các khoản phạt.

### 5.1 Bi kế tiếp và kế-kế-tiếp

- **9 / 10 bi:** theo thứ tự số.
- **8 bi:** bi kế tiếp là bi được đánh có góc cắt dễ nhất từ điểm dừng (PRD §5.4). Khi còn đúng một bi `mine`, bi kế tiếp **là bi 8**. Nhờ vậy, bi áp chót được chọn theo độ dễ của cú bi 8 mà không cần luật riêng.

### 5.2 Dội băng không bị coi là khó

Giữ đúng lập luận PRD §5.3: phạt dội băng tối đa 7 luôn nhỏ hơn phạt trô 10.

### 5.3 Áp phê

Khi phải dùng đường lui áp phê, thử `strokeCandidates × {trái, phải} × {½, 1 đầu cơ} × powerCandidates` (60 phương án), cùng điều kiện loại ở mục 4.3 và cùng cách chấm. Phạt kỹ thuật cộng dồn: kiểu đánh + áp phê, vì càng nhiều thông số xoáy càng nhiều sai số (PRD §8).

### 5.4 Độ chịu sai số lực (chỉ để hiển thị)

Với phương án đã chọn, thử 7 mức lực đều nhau từ lực −15% tới lực +15%, cùng kiểu đánh và áp phê. Mỗi mức xếp điểm dừng vào: **tốt** (góc dễ nhất cho bi kế tiếp ≤ 35°), **tạm được** (≤ 55°), **xấu hoặc bị chắn**. Dùng đúng các hàm mô phỏng và chấm của mục 5, không có logic riêng (PRD §6.5b). Không ảnh hưởng việc chọn phương án. Tính sau khi bước đã chọn xong, vẫn trong việc tính chia lát.

### 5.5 Thứ tự dự phòng

1. Thử đứng / cu lê / trô × 5 mức lực (mục 4.3).
2. Không còn phương án nào thì thử áp phê (mục 5.3). Bước dùng áp phê có lời khuyên SAWS.
3. Vẫn không còn thì dùng **Đánh đứng bi 30%** nếu cú đó vẫn đưa bi vào đúng lỗ, không chết cái và không đi qua bi chắn. Bỏ qua phần vị trí; `kind = fallback`, màn báo *"Không có vị trí tốt cho bi sau."* Kế hoạch đi tiếp từ điểm dừng của cú đó.
4. Đến cả cú đó cũng không được thì là bước **phòng thủ** (`kind = safety`) và kế hoạch dừng.

Các tầng 2–4 chỉ chạy khi tầng trước không còn phương án nào, không bao giờ để "so" với tầng trước.

---

## 6. Màn nhập bàn

**Vào từ đâu:** trong Luyện tập, thẻ **Kế hoạch dọn bàn** ngay dưới thẻ Mô phỏng góc cắt; đường dẫn `/training/planner` (`Routes.planner`). Màn mở bằng `go_router` như màn mô phỏng.

Dùng lại cái bàn của màn mô phỏng: cùng kích thước bàn, cùng cách vẽ bàn và bi, vùng chạm tối thiểu 24 px, bi đặt chồng thì tự tách.

**Từ trên xuống:**

1. **Loại bàn:** *9 bi · 10 bi · 8 bi*. Đổi loại bàn thì xoá kế hoạch đã tính, giữ vị trí bi đã đặt (PRD §6.1). Đổi giữa 8 bi và 9/10 bi thì gán lại số và vai trò theo thứ tự đã chạm.
2. **Chỉ với 8 bi:**
   - Nhóm của tôi: *Trơn · Sọc*.
   - Đang đặt: *Bi của tôi · Bi đối thủ · Bi 8*.
3. **Bàn:**
   - Chạm lần đầu đặt bi cái, các lần sau đặt bi mục tiêu.
   - **9 / 10 bi:** số gán theo thứ tự chạm, có dòng nhắc *"Chạm theo đúng thứ tự số: bi 1 trước, bi 2 sau…"* (PRD §6.2).
   - **8 bi:** bi của tôi và bi đối thủ tự lấy số nhỏ nhất còn trống trong nhóm mỗi bên. Chỉ có một bi 8.
   - Bi vẽ đúng màu bi thật, có số. Kéo để chỉnh vị trí.
   - Giới hạn: 9 bi tối đa 9 bi mục tiêu, 10 bi tối đa 10, 8 bi tối đa 7 bi mỗi bên cộng bi 8. Đạt giới hạn thì chạm thêm không đặt bi.
4. **Nút:** *Xoá bi cuối · Xoá hết · Lập kế hoạch*. *Lập kế hoạch* chỉ bật khi đã có bi cái và ít nhất một bi đánh được (8 bi: có bi của tôi hoặc bi 8).

Disclaimer PRD §6.6 hiện ở cuối màn, giữ nguyên văn.

---

## 7. Màn từng bước

Theo PRD §6.3–6.5b, kèm quyết định 3.

**Khi đang tính:** bước 1 hiện ngay khi xong; các bước sau tính tiếp trong nền với dòng *"Đang tính bước 3/9…"*. Nút *Đã đánh xong* ở bước cuối đã tính thì chờ bước kế tiếp.

### 7.1 Trên bàn

- Chỉ vẽ tối đa 3 bi: bi của bước đang xem và 2 bước kế tiếp (PRD §6.3). Bi cái ở `cbFrom` của bước đang xem.
- **Bước đang xem**, từ dưới lên:
  1. **Vùng điều tốt:** lưới ô 5 cm, ô **xanh** nếu góc dễ nhất cho bi kế tiếp ≤ 35°, **vàng** nếu ≤ 55°, bỏ trống nếu xấu hơn, không có đường hoặc đè lên bi. Tính bằng hình học (`bestAngleFrom`, cùng tập bi chắn như lúc chấm). Chỉ vẽ khi có bi kế tiếp.
  2. Đường ngắm, bi ảo, đường bi mục tiêu vào lỗ, lỗ đã chọn có vòng vàng.
  3. **Đường bi cái đúng từ mô phỏng:** `cueBefore` nét đứt trắng, `cueAfter` nét đứt ngọc, cong chỗ cong; chấm vàng ở mỗi lần chạm băng; vòng trắng nét đứt ở điểm dừng. Không vẽ đường cong tự chế.
  4. **Thanh sai số lực:** nối hai điểm `jitterEnds` qua điểm dừng chuẩn.
  5. Hai điểm *"nếu trượt"* (dư dày / dư mỏng), tô đậm điểm được khuyên.
- **Bước kế tiếp:** vẽ mờ (alpha khoảng 0.45) để xem trước.
- Chú giải các lớp ngay dưới bàn.

### 7.2 Bảng thông tin bước đang xem

- *Bước 3 / 9*, bi số mấy, lỗ, góc cắt, kiểu đánh, lực.
- **Độ chịu sai số lực:** ví dụ *"6/7 mức lực vẫn trong vùng điều tốt"*.
- **Dội băng** (thông tin, không phải cảnh báo): *"Bi cái chạm băng N lần rồi tới vùng điều."* Không có vế 15%.
- **Cảnh báo** khi lực ≥ 85% hoặc dùng trô, đúng câu PRD §6.5.
- **Khi dùng áp phê:** đúng dòng của màn mô phỏng: độ lệch điểm ngắm theo đầu cơ và phần con bi, và lời khuyên SAWS theo tỉ lệ BHE/FHE. Dùng chung hàm, không viết lại.
- **Nếu trượt:** *"Nếu trượt: nên đánh dư dày/mỏng một chút — bi sẽ khó cho đối thủ hơn."*
- Bước `fallback`: *"Không có vị trí tốt cho bi sau."* Bước `safety`: *"Không có cú nào đưa bi vào lỗ an toàn — nên phòng thủ."* và kế hoạch dừng.
- Ô **XEM TRƯỚC** viền đứt, nhạt hơn, cho bước kế tiếp với cùng thông tin.

Disclaimer PRD §6.6 luôn hiện.

### 7.3 Nút

- **← Quay lại** (không xuống dưới bước 1).
- **Đã đánh xong → Bi tiếp theo.** Bấm thì hỏi *"Bi cái dừng đúng chỗ dự kiến?"*
  - **Đúng:** sang bước sau.
  - **Đặt lại bi cái:** bàn vào chế độ kéo bi cái; bấm *Tính lại từ đây* thì tạo kế hoạch mới với các bi còn lại (mục 4.5).
  - Ở bước cuối, nút đổi thành *Xong bàn*.
- **Sửa bàn:** về màn nhập bàn, giữ nguyên các bi.

### 7.4 Semantics

Bàn có nhãn đọc được tóm tắt bước đang xem (bi, lỗ, kiểu đánh, lực). Mọi nút có nhãn. Giống cách màn mô phỏng đang làm.

---

## 8. Mang theo từ dự án lõi vật lý

1. Chuyển `lib/domain/table_geometry/scratch.dart` sang `lib/domain/table_physics/`, để hết vòng phụ thuộc `table_geometry` → `table_physics`.
2. Màn mô phỏng: `_aimFor` chỉ gán `_aimKey` **sau khi** `aimShot` trả kết quả, để lỗi ném ra không để lại cú cũ dưới khóa mới. Có test đỏ trước khi sửa.
3. Câu `Vi.simCannotSimulate` (*"Không mô phỏng được cú này — chỉ vẽ đường ngắm."*) vẫn là chữ của người viết mã. Hỏi chủ sản phẩm duyệt khi trình kết quả trên Chrome.

---

## 9. Sửa `PRD_RunOutPlanner.md`

Mỗi chỗ sửa đánh dấu *(sửa 2026-10-07: Kế hoạch dọn bàn)*:

- §1, §6: tên tính năng *Kế hoạch dọn bàn*.
- §2, §5.1, §5.4: 8 bi theo luật thật (nhóm Trơn / Sọc, bi đối thủ là bi chắn, bi 8 cuối, bi áp chót chọn theo cú bi 8).
- §4: `PlanStep` thêm `kind`, `spin`, `sawsBhePercent`, `jitterEnds`, `tolerance`; ghi `aimOffsetDeg` chỉ dùng bên trong.
- §5.3: phạt áp phê và thứ tự dự phòng 1 → 4 thay câu "dùng phương án dự phòng: center, lực 30%".
- §6.4: hỏi *"Bi cái dừng đúng chỗ dự kiến?"* và đặt lại bi cái; tính từng bước với dòng *Đang tính bước X/N*.
- §6.5: bỏ vế "mỗi lần chạm hao khoảng 15% lực, lực X% đã tính phần hao này".
- §8: áp phê không còn ngoài phạm vi; ghi rõ chỉ dùng như đường lui.

---

## 10. Kiểm thử

### 10.1 Chín test bắt buộc của PRD §7, chạy trên lõi vật lý thật

1. **Nối liền:** với mọi bàn hợp lệ trong bộ test, `identical(steps[i].trace.cueEnd, steps[i + 1].cbFrom)`.
2. **Thứ tự 9 / 10 bi:** bàn 4 bi cố định đánh đúng 1 → 2 → 3 → 4, kể cả khi bi khác dễ hơn.
3. **8 bi:** cùng bàn đó (mọi bi là bi của tôi) được phép đánh bi dễ trước. Thêm cho luật thật: bi 8 luôn cuối; bi đối thủ chắn đường thì phương án bị loại; bi áp chót được chọn sao cho cú bi 8 dễ hơn.
4. **Dội băng:** bàn có ít nhất một bước chạm băng; mọi điểm chạm nằm đúng trên biên, `cueAfter` đi qua các điểm đó theo thứ tự.
5. **Chịu sai số hơn khoảng cách:** phương án gần bi kế tiếp hơn nhưng không chịu được ±15% lực thì thua.
6. **Phòng thủ:** bi bắt buộc bị chắn ở mọi lỗ → bước đó là `safety` và kế hoạch dừng.
7. **Dội băng không bị coi là khó:** đánh thẳng kèm dội 1 băng thắng trô.
8. **Chết cái:** phương án làm bi cái rơi lỗ bị loại, dù điểm vị trí tốt hơn.
9. **Dư dày / mỏng:** cắt mỏng (> 60°) có `errDeg` lớn hơn rõ rệt cắt dày (< 20°); không lỗi khi là bi cuối.

### 10.2 Test cho quyết định mới

- **Áp phê là đường lui:** chỉ thử khi tầng 1 không còn phương án nào; phạt ½ = 15, 1 = 20, cộng dồn với kiểu đánh; bước đó có `sawsBhePercent`.
- **Thứ tự dự phòng:** đủ 4 tình huống, mỗi tình huống dừng đúng tầng.
- **Việc tính chia lát:** chạy từng lát (nhiều cỡ lát) cho đúng y kết quả như chạy một mạch; bước 1 báo ra trước khi cả kế hoạch xong; đặt lại bi cái thì tính lại đúng với các bi còn lại; hủy giữa chừng không báo thêm bước.
- **Tất định:** cùng bàn chạy hai lần cho cùng kế hoạch.
- **`SimulationTimeout`:** một phương án ném lỗi thì bị loại, kế hoạch vẫn ra.
- **Màn nhập bàn:** gán số theo thứ tự chạm; giới hạn số bi; nhóm Trơn / Sọc gán đúng số; một bi 8; *Lập kế hoạch* tắt khi chưa đủ bi; đổi loại bàn xoá kế hoạch, giữ bi.
- **Màn từng bước:** chỉ vẽ 3 bi; Quay lại / Đã đánh xong đúng giới hạn; câu dội băng không có "15%"; không câu nào chứa "°" như lời khuyên ngắm; dòng *Đang tính bước X/N*; luồng đặt lại bi cái.
- **Mục 8:** test `scratch.dart` chạy ở chỗ mới; test đỏ cho thứ tự `_aimKey`.

### 10.3 Tốc độ

- Bước 1 ra trong khoảng **1 giây** trên Chrome giả lập điện thoại, với bàn 9 bi điển hình.
- Kéo bi và cuộn màn trong lúc đang tính vẫn đạt ngân sách khung hình như màn mô phỏng: trung vị ≤ 17 ms, 95% khung ≤ 20 ms.
- Test đo thời gian riêng, chạy tách khỏi bộ test chính (như test đo của lõi vật lý).

### 10.4 Chrome và chủ sản phẩm

Script mới `tool/e2e/planner.mjs` (cùng khung với `simulator.mjs`) bày bốn bàn: 9 bi dễ, 9 bi có bi chắn, 8 bi kèm bi đối thủ, một bàn buộc phòng thủ. Chụp từng bước, kiểm luồng đặt lại bi cái.

**Dừng lại để chủ sản phẩm xem** kế hoạch có giống cách người chơi giỏi đi bàn không, rồi mới chỉnh điểm phạt nếu cần.

### 10.5 Sau merge

Deploy theo `deploy/publish.sh`, rồi chạy `planner.mjs` trên bản thật.
