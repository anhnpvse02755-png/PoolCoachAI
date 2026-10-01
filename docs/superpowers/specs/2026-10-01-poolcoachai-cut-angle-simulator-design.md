# PoolCoachAI — Thiết kế Mô phỏng góc cắt và lõi hình học bàn

**Ngày:** 01/10/2026
**Trạng thái:** đã duyệt hướng từng phần, chờ duyệt bản viết
**Tiền đề:** Tài khoản và đồng bộ đã vào `main` (`a3da44f`), 347 test xanh, bản web đang chạy đúng commit đó và qua E2E 6 bước. `PRD_RunOutPlanner.md` mô tả Run-out Planner, giả định có sẵn Mô phỏng góc cắt — nhưng trong mã chưa có dòng nào.

---

## 1. Mục tiêu

Run-out Planner được tách thành hai dự án con, mỗi dự án một spec → kế hoạch → triển khai:

1. **Dự án con 1 (tài liệu này):** lõi hình học bàn bi-a + màn **Mô phỏng góc cắt** một cú đánh.
2. **Dự án con 2:** Run-out Planner (chấm điểm 4 tầng ưu tiên, vòng lặp kế hoạch, giao diện từng bước) — xây trên lõi này, không tính lại hình học.

Làm mô phỏng trước vì lõi đường đi bi cái có hằng số phải chỉnh bằng mắt. Có màn mô phỏng thì chỉnh được và thấy được trước khi Planner dựa vào nó.

> Đặt bi cái và bi mục tiêu → thấy bi ảo, góc cắt, độ khó → chọn kiểu đánh, lực, áp phê → thấy bi cái đi đâu, có dội băng không, có nguy cơ chết cái không, và nên chỉnh gì.

### Không thuộc phạm vi

Run-out Planner (dự án con 2) · bi chắn đường trên màn mô phỏng (lõi vẫn xử lý và có test) · lưu bố cục · gắn với Drill hay Quick Actions ở AI Home · physics thật (ma sát, mất năng lượng, squirt, throw, xoáy 3 chiều) · quá một lần dội băng · kiểm chết cái khi **thiếu** lực · xoay bàn dọc trên điện thoại.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Mô phỏng trước, Planner sau**, chung một lõi | Lõi được kiểm cả bằng test lẫn bằng mắt trước khi Planner phụ thuộc |
| 2 | **Lõi Dart thuần** trong `lib/domain/table_geometry/`, không import Flutter | Test thẳng, Planner dùng lại nguyên vẹn |
| 3 | **Màn dùng state cục bộ** (`StatefulWidget` + `CustomPainter`), không Riverpod, không Drift | Không có gì để lưu hay chia sẻ |
| 4 | **Không dùng gói physics** (forge2d…) | PRD nói rõ đây là minh hoạ hình học tất định; physics engine phá bất biến `landingPos == cbFrom` của Planner |
| 5 | **Đơn vị là cm** trên bàn 9 feet | Hằng số pixel của prototype không biết canvas bao nhiêu, nên quy về thước thật |
| 6 | **Độ khó chỉ theo góc cắt** | Planner đo `diff` bằng góc cắt (PRD §5.4) — hai màn nói cùng một ngôn ngữ |
| 7 | **Lỗ tự chọn** theo góc nhỏ nhất, chạm lỗ khác thì ghi đè | Chính là Priority 1 của Planner (PRD §5.1), viết và test một lần |
| 8 | **Lực liên tục trong lõi**, 3 chip 40/70/95 trên màn | Chip khớp `POWER_CANDIDATES` của Planner; lõi liên tục thì mới dò được biên lực chết cái |
| 9 | **Trô/cu lê có thành phần dọc đường bi mục tiêu tỉ lệ `cos`** — lệch khỏi PRD | Công thức PRD cho quãng đường tỉ lệ `sin(góc)`, nên cú thẳng thì trô/cu lê cũng đứng im — trái bản chất hai kỹ thuật này |
| 10 | **Bắt chết cái** — thêm vào PRD | Không bắt thì Planner sẽ đề xuất kế hoạch rơi bi cái |
| 11 | **Áp phê đo bằng đầu cơ**: 0 · 0.5 · 1 · 2, trái hoặc phải | Người chơi không đặt đầu cơ chính xác tới milimét được; số đầu cơ thì tự đối chiếu bằng mắt được |
| 12 | **Áp phê chỉ để cảnh báo và khuyên**, Planner không chọn áp phê | Giữ Priority 2 của PRD: thêm một thông số phải canh là thêm khó |

### Thuật ngữ (chủ sản phẩm đã chốt)

| Hiển thị | Nghĩa | Ghi chú |
|---|---|---|
| **Đánh đứng bi** | stroke `center` (stun) | Không dùng "tâm bi" |
| **Đánh trô bi** | draw | |
| **Đánh cu lê** | follow | |
| **Bi ảo** | ghost ball | Không dùng "bi ma" (PRD viết "bi ma" — bỏ) |
| **Dội băng** | bi cái chạm băng **sau** khi chạm bi mục tiêu, để lấy vị trí | Khác A băng (kick) và Cân bi (bank) |
| **Áp phê** trái/phải | side spin | Từ *effet* |
| **Lệch N đầu cơ** | độ lệch tâm đầu cơ so với tâm bi cái, tính bằng bề rộng đầu cơ | Không dùng "đầu gậy" |
| **Chết cái** | bi cái rơi lỗ | |
| **Trượt cơ** | miscue | |

Mọi chữ hiển thị nằm trong `lib/core/strings/vi.dart`.

---

## 3. Hệ toạ độ và hằng số

- Mặt chơi 254 × 127 cm, gốc toạ độ ở góc trên trái, `x` theo chiều dài, `y` hướng xuống. Bi đường kính `D = 5.715`, bán kính `R = D/2`.
- **Biên tâm bi** (`bounds`): `[R, 254−R] × [R, 127−R]`. Mọi điểm chạm băng nằm **đúng** trên biên này (PRD §7 ca 4).
- **Lỗ** là enum `Pocket`, mỗi lỗ một điểm: `topLeft (0,0)`, `topMiddle (127,0)`, `topRight (254,0)`, `bottomLeft (0,127)`, `bottomMiddle (127,127)`, `bottomRight (254,127)`. Không mã nào dựa vào chỉ số 0–5.
- Đầu cơ chuẩn `tipWidth = 1.25` cm (giữa khoảng 12.2–12.8 mm).

Hằng số có tên, giá trị khởi điểm chỉnh bằng mắt trên màn mô phỏng trong lúc triển khai:

| Hằng số | Khởi điểm | Vai trò |
|---|---|---|
| `maxTravel` | 254 cm | Quãng bi cái đi ở lực 100% (thay `260 px` của PRD) |
| `rollCarry` | 0.5 | Tỉ lệ thành phần dọc đường bi mục tiêu của trô/cu lê |
| `spinDegPerRadius` | 20° | Góc bật băng đổi thêm mỗi 1 bán kính lệch tâm |
| `cornerCapture` | 6.0 cm | Tâm bi cái lọt trong bán kính này quanh lỗ góc → chết cái |
| `middleCapture` | 5.0 cm | Như trên, lỗ giữa |
| `maxCutAngle` | 85° | Quá góc này là không đánh được (PRD §5.1) |
| `miscueTips` | 2 | Từ mức lệch này trở lên cảnh báo trượt cơ (2 đầu cơ ≈ 0.87R, quá giới hạn thường gặp 0.5–0.6R) |
| `overhitBand` | 15% | Biên lực dư dùng cho cảnh báo chết cái (trùng `POWER_JITTER` của PRD) |

---

## 4. Lõi `lib/domain/table_geometry/`

Một file một việc. Không file nào import Flutter — thêm luật này vào `test/architecture_test.dart`.

| File | Nội dung |
|---|---|
| `vec2.dart` | `Vec2` bất biến, `==` chính xác, các phép vector cần dùng |
| `table_spec.dart` | `TableSpec` (kích thước, `bounds`, `R`), enum `Pocket` có `position` và `capture` |
| `path_clear.dart` | `isPathClear(from, to, others)` — sai khi tâm một bi khác cách đoạn thẳng dưới `D` |
| `shot_geometry.dart` | `ShotGeometry` và `evaluateShot` (mục 4.1) |
| `difficulty.dart` | `DifficultyBand` và `bandFor(angle)` (mục 4.2) |
| `pocket_choice.dart` | `bestPocket(cue, object, others)` (mục 4.3) |
| `stroke.dart` | `Stroke { stun, draw, follow }`, `SideSpin { side, tips }` |
| `cue_ball_path.dart` | `simulateCueBall` và `CueBallPath` (mục 4.4–4.6) |
| `scratch.dart` | `scratchMargin`, `scratchAdvice` (mục 4.7–4.8) |

Planner ở dự án con 2 chỉ thêm chấm điểm, vòng lặp và `PlanStep`. Nó lấy `CueBallPath.end` làm `cbFrom` của bước sau — **cùng một đối tượng**, không tính lại.

### 4.1 Cú đánh

`evaluateShot(cue, object, pocket, others) → ShotResult`, sealed:

- `Makeable(ShotGeometry)` — `ghost` (bi ảo: lùi đúng `D` sau bi mục tiêu trên đường lỗ→bi mục tiêu), `objectDir` (bi mục tiêu→lỗ, đơn vị), `tangentDir` (đơn vị, vuông góc `objectDir`, về phía bi cái đi tới; vector không khi góc bằng 0), `angle` (độ, giữa cue→ghost và objectDir).
- `Unmakeable(reason)`, mỗi lý do có câu riêng trong `vi.dart`:
  - `overlap` — bi cái và bi mục tiêu cách nhau dưới `D`.
  - `ghostOffTable` — bi ảo nằm ngoài `bounds` (bi mục tiêu sát băng, lỗ đòi bi ảo nằm sau băng).
  - `tooThin` — góc > 85°. Đúng 85° vẫn đánh được.
  - `cueBlocked` / `objectBlocked` — đường bi cái→bi ảo hoặc bi mục tiêu→lỗ bị chắn.

### 4.2 Độ khó

Theo góc **chưa làm tròn**; màn hiện góc làm tròn tới độ.

| Góc cắt | Độ khó |
|---|---|
| < 15° | Dễ |
| 15–30° | Vừa |
| 30–45° | Khó |
| 45–60° | Rất khó |
| 60–85° | Cực khó |
| `Unmakeable` | Không đánh được |

Biên dưới thuộc mức trên: đúng 15° là Vừa.

### 4.3 Chọn lỗ

`bestPocket` thử cả 6 lỗ, bỏ mọi `Unmakeable`, trả lỗ có góc nhỏ nhất; hoà góc thì lấy lỗ gần bi mục tiêu hơn, vẫn hoà thì theo thứ tự enum — kết quả luôn tất định. Không lỗ nào được thì trả `null`.

### 4.4 Đường đi khi không chạm băng

Với `L = maxTravel × power/100`, `θ` là góc cắt, `t = tangentDir`, `u = objectDir`:

- `stun`: điểm dừng `E₀ = ghost + t·L·sin θ`.
- `follow`: `E₀ = ghost + t·L·sin θ + u·rollCarry·L·cos θ`.
- `draw`: `E₀ = ghost + t·L·sin θ − u·rollCarry·L·cos θ`.

Hệ quả cần có test: cú thẳng (`θ = 0`) đánh đứng bi thì bi cái dừng tại bi ảo, cu lê đi thẳng theo bi mục tiêu, trô lùi thẳng về.

Đường vẽ là Bézier bậc ba từ `ghost` tới `E₀`, tiếp tuyến đầu theo `t` (hoặc `±u` khi `θ = 0`), cong về phía `+u` với cu lê và `−u` với trô; `stun` là đoạn thẳng. Điểm điều khiển được kẹp vào `bounds`, nên đường cong không bao giờ xuyên băng (bao lồi nằm trong `bounds`).

### 4.5 Dội băng

Nếu đoạn thẳng `ghost → E₀` ra khỏi `bounds`:

1. **Đoạn 1:** đường **thẳng** từ `ghost` tới điểm chạm `hit` — giao điểm đầu tiên với `bounds`.
2. Phản xạ hướng đi tại `hit` (trục chạm đổi dấu), rồi xoay thêm theo áp phê (mục 4.6).
3. **Đoạn 2:** đi tiếp quãng còn lại `|E₀ − ghost| − |hit − ghost|` từ `hit`, áp hiệu ứng cong của kiểu đánh như 4.4 với độ cong tỉ lệ quãng còn lại. Riêng **đánh trô bi**, đoạn 2 là đường **thẳng** tới cùng điểm dừng: xoáy trô gần như hết trước khi tới băng (chủ dự án chốt sau khi xem trên Chrome, 2026-10-01). Cu lê giữ đường cong.
4. Nếu đoạn 2 chạm băng thứ hai: bi cái dừng tại điểm chạm đó (PRD §8: tối đa một lần dội).

`CueBallPath { segments, end, railHit? }` — `segments` là danh sách sealed `Straight | Curve`; dội băng là `railHit != null`. Hai đoạn **không bao giờ** gộp thành một đường cong.

Đây là cách hiểu lại PRD §5.2: PRD bắn tia theo `t`; ở đây bắn theo hướng `ghost → E₀`. Với đánh đứng bi hai cách trùng nhau; với trô/cu lê, cách này mới tính được cả thành phần dọc `u` của quyết định 9.

### 4.6 Áp phê

- `SideSpin(side: left | right, tips: 0 | 0.5 | 1 | 2)`; trái/phải tính theo hướng nhìn của người đánh (dọc bi cái → bi ảo).
- Áp phê **chỉ** đổi hướng bật băng: lệch tâm `e = tips × tipWidth`, góc đổi thêm `δ = spinDegPerRadius × e/R`.
- **Thuận** (mở góc, bật xa pháp tuyến hơn) khi đường bật rẽ cùng phía với áp phê: bật rẽ phải theo hướng nhìn người đánh + áp phê phải, hoặc rẽ trái + áp phê trái. **Nghịch** thì đóng góc. Góc bật không vượt quá song song với băng.
- Không chạm băng thì đường đi không đổi; màn nói rõ điều đó.

### 4.7 Chết cái

`CueBallPath.scratch` là lỗ đầu tiên mà tâm bi cái đi qua trong vùng `capture` của nó, xét trên mọi đoạn (đường cong lấy mẫu dày tới mức mỗi bước ≤ R/2), **trước** khi xét điểm chạm băng gần lỗ đó — bi lọt lỗ thì không bật nữa. Có `scratch` thì đường đi dừng tại điểm lọt lỗ.

`scratchMargin(geometry, stroke, power, spin, table) → ScratchMargin?`: tăng lực từ mức chọn lên từng 1% tới 100%, trả **mức lực đầu tiên** chết cái và lỗ nào; `null` nếu không có. Nếu ngay mức chọn đã chết cái thì margin bằng 0.

### 4.8 Lời khuyên

`scratchAdvice(geometry, stroke, power, chosenSpin, table) → List<Advice>` mô phỏng đủ 7 mức áp phê (không, trái 0.5/1/2, phải 0.5/1/2), mỗi mức tính chết cái tại lực chọn và `scratchMargin`. Một mức là **an toàn** khi không chết cái tại lực chọn và margin `null` hoặc > `overhitBand`.

Lời khuyên là kiểu dữ liệu có giá trị tính được, `vi.dart` ghép thành câu — **không câu nào viết tay sẵn nội dung**. Trả tối đa 2 lời khuyên, theo thứ tự:

1. **Mức đang chọn chết cái tại lực chọn** → `AddSpinToAvoid(side, tips, pocket)`: mức an toàn có ít đầu cơ nhất (hoà thì giữ cùng phía đang chọn). Không mức nào an toàn → `NoSpinAvoids(pocket)`, khuyên đổi lực hoặc kiểu đánh.
   *"Ít áp phê dễ chết cái ở lỗ góc trên phải — nên áp phê phải lệch 1 đầu cơ để bi cái mở góc tránh lỗ."*
2. **Margin của mức đang chọn ≤ `overhitBand`** → `OverhitRisk(percent, fromPower, pocket)`, kèm mức áp phê ít đầu cơ nhất giữ an toàn tới 100% nếu có.
   *"Nếu đánh quá lực khoảng +12% (từ ~82%), bi cái có thể rơi lỗ góc trên phải (chết cái). Thêm áp phê trái lệch 1 đầu cơ thì vẫn an toàn tới 100%."*
3. **Cùng phía đang chọn, nhiều đầu cơ hơn thì chết cái** → `SpinCeiling(side, maxSafeTips, pocket)`.
   *"Đừng áp phê phải quá 0.5 đầu cơ — bi cái sẽ mở góc vào lỗ giữa dưới."*

Mức chọn ≥ `miscueTips` thêm cảnh báo *"Lệch 2 đầu cơ dễ trượt cơ."* — tách khỏi giới hạn 2 lời khuyên.

---

## 5. Màn Mô phỏng góc cắt

**Đường dẫn:** `Routes.simulator = '$training/simulator'`, nằm trong nhánh Luyện tập của `StatefulShellRoute` như các màn bài tập. Tab Luyện tập có thêm thẻ "Mô phỏng góc cắt" phía trên thư viện bài tập.

**File:** `lib/features/training/presentation/simulator/` — `simulator_screen.dart` (state và bố cục), `table_painter.dart` (vẽ), các widget chọn kiểu đánh/lực/áp phê và bảng thông tin tách file riêng khi dài.

### 5.1 Bố cục

Từ trên xuống: bàn (nằm ngang, tỉ lệ 2:1, rộng hết màn, co lại trên màn hẹp) → kiểu đánh → lực → áp phê → bảng thông tin → disclaimer.

### 5.2 Tương tác

- Bố cục mở màn: bi cái và một bi mục tiêu ở vị trí cố định cho ra một cú hợp lệ.
- Kéo trực tiếp bi cái hoặc bi mục tiêu; chạm trong ~1.5R quanh tâm bi là bắt bi. Bi luôn kẹp trong `bounds`; thả đè lên bi kia thì đẩy về vừa chạm nhau.
- **Lỗ tự chọn** bằng `bestPocket` khi mở màn và sau mỗi lần kéo. Chạm một lỗ khác thì dùng lỗ đó (ghi đè); kéo bi lại thì về tự chọn.
- **Kiểu đánh:** Đánh đứng bi · Đánh trô bi · Đánh cu lê.
- **Lực:** Nhẹ 40% · Vừa 70% · Mạnh 95%.
- **Áp phê:** Không · Trái 0.5 / 1 / 2 · Phải 0.5 / 1 / 2 đầu cơ.

### 5.3 Vẽ (PRD §6.5)

- Đường ngắm bi cái → bi ảo: nét đứt trắng. Bi ảo: viền tròn.
- Bi mục tiêu → lỗ: nét liền mảnh.
- Đường bi cái sau va chạm: nét đứt màu ngọc, đúng kiểu đánh đã chọn. Dội băng: đoạn thẳng tới băng, chấm vàng nhỏ ở điểm chạm, rồi đoạn cong tới điểm dừng.
- Chết cái tại lực chọn: đường vẽ tới lỗ, lỗ đó tô cảnh báo. Có nguy cơ khi quá lực: vòng nét đứt quanh lỗ đó.
- Cú không đánh được: không vẽ đường bi cái.

### 5.4 Bảng thông tin

- Lỗ · góc cắt (làm tròn độ) · độ khó · kiểu đánh · lực · áp phê.
- Dội băng: *"Bi cái dội băng — cần canh lực chính xác hơn bình thường."* (Câu PRD có nhắc "vị trí tốt" chỉ dùng ở Planner, nơi có vị trí đích.)
- Có áp phê mà không chạm băng: *"Áp phê chỉ đổi đường bi cái sau khi chạm băng."*
- Lời khuyên từ 4.8.
- `Unmakeable`: câu lý do tương ứng, không hiện các dòng còn lại.

### 5.5 Disclaimer (PRD §6.6)

Luôn hiện: *"Lực và đầu cơ là gợi ý định hướng dựa trên hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, người chơi vẫn cần tự canh lực thực tế."*

### 5.6 Semantics

Bàn bọc trong `Semantics` có nhãn tóm tắt (lỗ, góc, độ khó, dội băng/chết cái) — để người dùng trình đọc màn hình hiểu được, và để E2E headless Chrome đọc được kết quả.

---

## 6. Kiểm thử

**Lõi** (`test/domain/table_geometry/`):

- Bi ảo cách bi mục tiêu đúng `D`, nằm trên đường lỗ→bi mục tiêu kéo dài; góc 0° với cú thẳng, góc đúng với vài cú dựng tay.
- Từng lý do `Unmakeable`, kể cả đúng 85° vẫn đánh được.
- Biên các mức độ khó (14.99 / 15 / 30 / 45 / 60 / 85).
- `bestPocket` chọn góc nhỏ nhất, bỏ lỗ bị chắn, tất định khi hoà, `null` khi không lỗ nào được.
- Cú thẳng: đứng bi dừng tại bi ảo, cu lê tiến, trô lùi.
- Cú có góc: cu lê cong về `+u`, trô về `−u`, đứng bi đi đúng đường tiếp tuyến.
- Dội băng: `hit` nằm đúng trên `bounds` ở một toạ độ; đoạn 1 là `Straight`; dừng ở băng thứ hai.
- Áp phê: không chạm băng thì đường y hệt không áp phê; thuận mở góc, nghịch đóng góc; góc đổi tăng theo số đầu cơ.
- Chết cái: đường qua vùng `capture` dừng tại lỗ; `scratchMargin` trả đúng mức lực đầu tiên trên một bố cục dựng tay, `null` khi không có.
- `scratchAdvice`: mỗi loại lời khuyên một bố cục dựng tay; mức an toàn ít đầu cơ nhất được chọn; tối đa 2 lời khuyên.
- `architecture_test`: `lib/domain/table_geometry/` không import Flutter.

**Màn** (`test/features/training/`): mở màn ra cú hợp lệ và có bảng thông tin; đổi kiểu đánh/áp phê thì bảng đổi; disclaimer luôn có; chạm lỗ khác thì ghi đè; thẻ trên tab Luyện tập mở đúng màn.

**Sau deploy:** headless Chrome qua CDP mở `/training/simulator`, bật semantics, đọc nhãn tóm tắt của bàn.

---

## 7. Nối sang dự án con 2

Planner dùng `evaluateShot`, `bestPocket`, `simulateCueBall`, `scratchMargin`, `scratchAdvice` như đã có. Đã chốt sẵn cho Planner:

- Chỉ chọn kiểu đánh và lực; áp phê chỉ ở lời khuyên từng bước.
- Phương án có `scratch` tại lực chọn bị loại như đường bị chắn.
- Margin chết cái ≤ 15% thì phương án tính là không chịu sai số: `robustDiff1 = 95`.
- Trọng số khoảng cách quy từ `dist × 0.01` (0–400 px) sang cm sao cho vẫn chỉ góp tối đa ~4 điểm.
