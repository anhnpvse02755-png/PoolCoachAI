# PRD — Run-out Planner & Position Play Engine (PoolCoachAI)

> Bổ sung cho `PoolCoachAI_SPEC.md`, thuộc module **Training Center → Cut Angle Simulator** (mục 4.3 trong spec chính). Tài liệu này mô tả một tính năng cụ thể: từ vị trí bi cái + các bi mục tiêu trên bàn, tính ra thứ tự đánh, lỗ, lực, đầu cơ, và vị trí bi cái nên dừng lại cho từng bước, để chạy hết bàn. Toàn bộ là logic thuần (deterministic, rule-based) — không dùng AI/LLM.

---

## 1. Bối cảnh & mục tiêu

Cut Angle Simulator (mục 4.3) hiện chỉ xử lý 1 cú đánh đơn lẻ. Tính năng này mở rộng thành **Run-out Planner**: nhập toàn bộ bố cục bàn, hệ thống tự lên kế hoạch đánh hết bi theo đúng luật của loại bàn đang chơi, kèm gợi ý cụ thể cho từng bước (lực, đầu cơ, vị trí bi cái nên dừng).

Mục tiêu là công cụ **huấn luyện tư duy vị trí (position play)**, không phải một solver vật lý chính xác tuyệt đối. Mọi gợi ý phải nêu rõ đây là ước lượng hình học, người chơi vẫn cần tự canh lực thực tế.

## 2. Luật theo loại bàn

| Loại bàn | Ràng buộc thứ tự |
|---|---|
| 9-bi / 10-bi | **Bắt buộc** đánh đúng thứ tự số bi tăng dần (1→2→3→...). Không được chọn bi khác dễ hơn để đánh trước. |
| 8-bi | Không ràng buộc thứ tự — ở mỗi bước, chọn trong tất cả bi còn lại cú đánh có góc cắt khả thi dễ nhất. |

Người chơi chọn loại bàn trước khi nhập bi; thuật toán tương ứng khác nhau (xem mục 5).

## 3. Nguyên tắc cốt lõi: thứ tự ưu tiên khi chọn cách đánh

Đây là phần quan trọng nhất của toàn bộ tính năng — **phải giữ đúng thứ tự ưu tiên này khi chấm điểm các phương án**, không gộp thành trọng số ngang hàng:

1. **Má bi / góc cắt của CHÍNH cú đánh hiện tại** — chọn lỗ nào cho bi đang đánh dễ vào nhất (góc cắt nhỏ nhất trong số các lỗ khả thi, không bị bi khác chắn đường). Đây là điều kiện tiên quyết: sai má bi thì mọi tính toán vị trí phía sau vô nghĩa.
2. **Độ khó / tỉ lệ thành công của kỹ thuật cần dùng cho vị trí để lại** — thứ tự ưu tiên kỹ thuật từ dễ đến khó: **tâm bi (stun) > cu lê (12h) > trô (6h)**. Dội băng để lên vùng điều **KHÔNG được coi là một kỹ thuật khó** — đánh thẳng (tâm bi hoặc cu lê) rồi để bi tự chạm băng lên vùng điều là cách dễ kiểm soát nhất, dễ hơn nhiều so với dùng trô để "bẻ" bi cái sang một hướng khác. Càng ít thông số phải canh chỉnh (chỉ lực, không xoáy) thì sai số càng thấp, tỉ lệ thành công càng cao. **Tỉ lệ thành công cao luôn được ưu tiên hơn một vị trí "đẹp" nhưng khó thực hiện.**
3. **"Vùng điều tốt" — độ chịu sai số lực** — với cùng một đầu cơ, thử thêm/bớt lực (±15%) xem vị trí kết quả có còn dùng được cho cú kế tiếp không. Phương án mà cả một khoảng lực rộng đều cho vị trí tốt (không chỉ đúng 1 mức lực chính xác tuyệt đối mới ăn) được ưu tiên hơn — vì thực tế người chơi luôn có sai số lực nhất định.
4. **Khoảng cách giữa bi cái và bi mục tiêu kế tiếp** — CHỈ dùng để phân định khi các phương án đã ngang nhau ở (2) và (3). Không được xét trước (2)/(3).

Ngoài ra, khi so sánh vị trí để lại cho cú kế tiếp (bi N+1) và cú kế-kế-tiếp (bi N+2, ước lượng): **ưu tiên cân bằng độ khó giữa 2 vị trí hơn là tối ưu 1 vị trí thật đẹp còn 1 vị trí rất khó.** Dùng `max(diff_N+1, diff_N+2)` để chấm điểm, không dùng tổng — vì hai vị trí ở mức khá tốt hơn một vị trí đẹp + một vị trí khó (minimax thay vì trung bình/tổng).

**Lực và xoáy quá tay cũng là một loại rủi ro, không chỉ là chuyện kỹ thuật khó:** đánh quá mạnh hoặc xoáy quá nhiều (nhất là trô) làm tăng nguy cơ **chết cái (scratch)** và tăng sai số thực hiện. Vì vậy, ngoài thứ tự ưu tiên trên, thuật toán còn: (a) loại thẳng mọi phương án có đường đi lướt qua miệng lỗ nào (nguy cơ chết cái), và (b) cộng thêm điểm phạt tỉ lệ với % lực — không chỉ phạt "có xoáy hay không" mà phạt cả mức độ lực dùng.

## 4. Data model bổ sung

```typescript
interface Ball { num: number; x: number; y: number; }
interface Pocket { x: number; y: number; }

type StrokeType = 'center' | 'follow' | 'draw';
// center = tâm bi; follow = Cu lê (xoáy trên, 12h) — kéo bi cái TIẾN thêm theo hướng bi mục tiêu;
// draw = Trô (xoáy dưới, 6h) — kéo bi cái LÙI lại. (Quy ước tên gọi theo người dùng, không theo thuật ngữ tiếng Anh gốc.)
// Bi cái LĂN THẲNG theo hợp vector (thành phần tiếp tuyến + thành phần xoáy dọc) — KHÔNG mô phỏng bằng
// đường cong "bẻ sang" nhân tạo. Đây là điểm quan trọng: đường cong trước đây không sát thực tế và ngầm
// khiến thuật toán coi trô/cu lê "rẻ" ngang với dội băng, trong khi thực tế đi thẳng rồi dội băng dễ kiểm
// soát lực hơn nhiều so với dùng xoáy mạnh để đổi hướng.

const STROKE_CANDIDATES: StrokeType[] = ['center', 'follow', 'draw'];
const POWER_CANDIDATES = [30, 45, 60, 75, 90]; // % lực, các mức thử khi tìm phương án tốt nhất
const POWER_JITTER = 15; // % dùng để đo "vùng điều tốt" chịu sai số lực
const STROKE_SPIN = {center: 0, follow: 0.55, draw: -0.55}; // hệ số thành phần xoáy dọc theo hướng ux,uy
const RAIL_LOSS = 0.15;   // mỗi lần chạm băng hao ~15% quãng đường còn lại
const MAX_RAILS = 2;      // mô phỏng tối đa 2 lần chạm băng trong 1 cú đánh
const POCKET_DANGER = 20; // bi cái đi qua trong bán kính này quanh tâm lỗ -> coi là nguy cơ chết cái

interface ShotGeometry {
  ghost: {x:number,y:number};   // điểm bi ma (nơi tâm bi cái cần chạm tới)
  ux: number; uy: number;        // hướng bi mục tiêu -> lỗ (đơn vị)
  angle: number;                  // góc cắt (độ)
}

interface LandingCurve {
  pts: {x:number,y:number}[];     // đường đi GẤP KHÚC THẲNG: [ghost, điểm chạm băng 1, điểm chạm băng 2..., end]
  end: {x:number,y:number};        // điểm bi cái thực sự dừng lại
  hits: {x:number,y:number}[];     // các điểm chạm băng dọc đường đi (rỗng nếu không chạm băng)
  bankUsed: boolean;                // = hits.length > 0
  scratch: boolean;                 // đường đi có lướt qua miệng lỗ nào không (POCKET_DANGER)
}

interface PlanStep {
  ballNum: number | null;          // null khi là bước "safety" ở chế độ 8-bi (không có bi cụ thể bị ép)
  pocketIndex: number;             // 0-5, khớp với thứ tự lỗ chuẩn (2 góc trên, 2 giữa băng, 2 góc dưới)
  angle: number;                    // góc cắt của cú đánh (độ)
  stroke: StrokeType;
  power: number;                    // % lực (từ POWER_CANDIDATES)
  bankUsed: boolean;
  cbFrom: {x:number,y:number};      // vị trí bi cái TRƯỚC cú đánh này
  ghost: {x:number,y:number};
  landingCurve: LandingCurve;
  landingPos: {x:number,y:number} | null; // = landingCurve.end; null chỉ khi hoàn toàn không tìm được phương án nào (edge case)
  nextBallHint: number | null;
  safety?: true;
  message?: string;                 // chỉ có khi safety = true
}
```

**Bất biến bắt buộc (invariant) — phải có unit test cho điều này:**
`plan[i].landingPos` (điểm bi cái dừng lại sau bước i) phải **bằng chính xác** `plan[i+1].cbFrom` (điểm bắt đầu của bước i+1). Cách đảm bảo: dùng thẳng `cand.end` làm `cb` cho vòng lặp kế tiếp, không tính lại.

## 5. Thuật toán

### 5.1 Chọn bi + lỗ cho bước hiện tại (Priority 1 — Má bi)

- **9-bi/10-bi**: bi hiện tại = bi có số nhỏ nhất còn lại trên bàn (cố định, không được đổi).
- **8-bi**: bi hiện tại = bi có góc cắt khả thi dễ nhất trong TẤT CẢ bi còn lại (tìm kiếm toàn bộ tổ hợp bi × lỗ).

Trong cả 2 trường hợp: với bi đã chọn, thử cả 6 lỗ, loại lỗ nào góc cắt > 85° hoặc đường bi cái→bi ma hoặc bi→lỗ bị bi khác (còn trên bàn, kể cả bi chưa tới lượt trong chế độ 9/10-bi) chắn ngang. Chọn lỗ có góc cắt nhỏ nhất trong các lỗ hợp lệ. Nếu không lỗ nào hợp lệ → bước này là **safety** (dừng lập kế hoạch tại đây, không đoán tiếp vì kết quả cú safety không xác định trước được).

### 5.2 Mô phỏng thuận đường đi bi cái — ĐƯỜNG THẲNG, có xoáy dọc và dội băng nhiều lần

Với hình học `g` (ghost, ux, uy, hướng tiếp tuyến `tx,ty` = thành phần vận tốc bi cái còn lại sau va chạm, độ lớn `sinT = sin(góc cắt)`):

```
function simulateWithRail(g, stroke, power, bounds):
  s = STROKE_SPIN[stroke]                       // 0 / +0.55 / -0.55
  cosT = sqrt(1 - sinT²)
  v = tangent*sinT + (ux,uy)*s*cosT              // hợp vector: tiếp tuyến + xoáy dọc theo hướng bi mục tiêu
  nếu |v| gần 0 -> bi cái gần như đứng yên tại ghost (tâm bi cắt dày), dừng ở đây

  dir = normalize(v)
  remain = 260 * (power/100) * min(1, |v|)       // quãng đường còn lại để đi
  pts = [ghost]; hits = []; rails = 0; pos = ghost

  lặp trong khi remain > 1:
    rail = tia từ pos theo dir, tìm điểm chạm biên bàn gần nhất
    nếu không có biên trong tầm remain:
      pos = pos + dir*remain; pts.push(pos); DỪNG
    hit = điểm chạm băng
    pts.push(hit)
    nếu rails >= MAX_RAILS: pos = hit; DỪNG        // hết lượt dội cho phép, dừng tại băng
    hits.push(hit); rails++
    remain = (remain - khoảng_cách_tới_hit) * (1 - RAIL_LOSS)   // hao lực mỗi lần dội
    dir = phản xạ dir qua trục vừa chạm (góc tới = góc phản xạ)
    pos = hit

  scratch = có đoạn nào trong pts đi qua trong bán kính POCKET_DANGER quanh 1 miệng lỗ không
  return {pts, end: pts.cuối, hits, bankUsed: hits.length>0, scratch}
```

Quan trọng: đây là đường đi **THẲNG giữa các lần chạm băng** — không có đoạn nào bị uốn cong nhân tạo theo stroke. Hiệu ứng `stroke` chỉ ảnh hưởng tới **hướng ban đầu** (qua thành phần xoáy dọc cộng vào vector vận tốc), không phải một đường cong vẽ thêm sau đó.

### 5.3 Chấm điểm phương án (Priority 2, 3, 4 — theo đúng thứ tự mục 3)

Với mỗi tổ hợp `(stroke, power)` trong `STROKE_CANDIDATES × POWER_CANDIDATES`:

```
curve = simulateWithRail(g, stroke, power, bounds)
nếu curve.scratch -> LOẠI (nguy cơ chết cái)
nếu đường đi bị bi khác chắn -> LOẠI tổ hợp này

E = curve.end
railCount = curve.hits.length
bankPenalty = railCount==0 ? 0 : (railCount==1 ? 2 : 7)     // dội băng gần như KHÔNG bị phạt
techPenalty = stroke==center ? 0 : (stroke==follow ? 3 : 10) // cu lê (12h) nhẹ hơn trô (6h) nhiều
powerPenalty = (power/100) * 4                               // lực càng lớn càng dễ sai số/chết cái

nếu không còn bi tiếp theo (đây là bi cuối):
  score = bankPenalty + techPenalty + powerPenalty
  ghi nhận nếu score thấp nhất, next

diff1 = góc cắt dễ nhất để đánh bi kế tiếp từ E (thử cả 6 lỗ, loại lỗ bị chắn)
nếu không lỗ nào khả thi từ E -> LOẠI tổ hợp này (vị trí này giết chết cú kế tiếp)

// Priority 3 — vùng điều tốt: thử power ± POWER_JITTER (cùng stroke), lấy góc XẤU NHẤT trong 3 mức lực
robustDiff1 = max(diff1(power), diff1(power-15), diff1(power+15))
  // nếu lệch lực bị chắn/không khả thi/chết cái -> tính là 95 (rất khó)

// nhìn thêm 1 bi nữa để tránh "1 đẹp 1 tệ": giả định cú kế tiếp đánh tâm bi lực vừa (55%)
diff2 = góc cắt dễ nhất cho bi kế-kế-tiếp, xuất phát từ vị trí bi cái giả định sau cú kế tiếp đó

posScore = diff2 tồn tại ? max(robustDiff1, diff2) : robustDiff1     // MINIMAX, không phải tổng

// Priority 4 — khoảng cách, trọng số RẤT NHỎ, chỉ có tác dụng phân định khi mọi thứ trên đã ngang nhau
dist = khoảng cách từ ghost tới E

score = posScore + bankPenalty + techPenalty + powerPenalty + dist * 0.01

giữ lại tổ hợp có score thấp nhất
```

**Vì sao đi thẳng-rồi-dội-băng không bị coi là khó:** `bankPenalty` (tối đa 7) nhỏ hơn nhiều so với `techPenalty` của trô (10), và nhỏ hơn cả cu lê (3) cộng dội 1 lần (2) = 5. Điều này đúng với thực tế: đánh tâm bi/cu lê cho bi tự chạy lên băng rồi bật ra vùng điều dễ canh lực hơn nhiều so với dùng trô để chủ động "bẻ" bi cái sang hướng khác — vì đi thẳng chỉ có 1 biến số (lực), còn dùng xoáy mạnh để đổi hướng có cả biến số lực lẫn biến số độ xoáy, sai số cộng dồn của 2 biến số luôn lớn hơn 1 biến số.

Nếu KHÔNG tổ hợp nào hợp lệ (hiếm, toàn bộ bị chắn/nguy cơ chết cái) → dùng phương án dự phòng: `center`, lực 30% (ít chạy nhất, ít rủi ro nhất).

### 5.4 Vòng lặp chính

```
cb = vị trí bi cái ban đầu
lặp qua từng bi (theo 5.1):
  tìm best (bi, lỗ) theo Priority 1
  nếu không tìm được -> đẩy bước safety, DỪNG (không đoán tiếp)
  cand = chấm điểm theo 5.3, dùng nextBall/nextNextBall:
    - 9/10-bi: nextBall/nextNextBall = bi kế tiếp/kế-kế-tiếp theo đúng thứ tự số
    - 8-bi: nextBall/nextNextBall = ước lượng bằng góc dễ nhất trong các bi còn lại (không phải tối ưu toàn cục)
  đẩy PlanStep với cbFrom = cb (giá trị TRƯỚC khi cập nhật)
  cb = cand.end        // bắt buộc: bước sau dùng ĐÚNG điểm này, không tính lại
```

### 5.5 Gợi ý "đánh dư dày / dư mỏng" để nếu trượt vẫn khó cho đối thủ

Đây là một lớp tư vấn **bổ sung, không ảnh hưởng tới việc chọn phương án ở 5.3** — chỉ đưa thêm 1 gợi ý định tính cho người chơi.

```
function missSafetyAdvice(g, ballObj, obstaclesAfter, bounds):
  sensitivity = min(3, 1 / max(0.15, cos(g.angle)))   // cắt càng mỏng càng nhạy sai số ngắm
  errDeg = min(30, MISS_ANGLE_DEG * sensitivity)       // MISS_ANGLE_DEG = 5, sai số ngắm giả định
  travel = 110                                          // quãng đường ước lượng bi mục tiêu trôi nếu trượt

  với mỗi hướng lệch trong {dư dày: -errDeg, dư mỏng: +errDeg}:
    d = xoay vector (ux,uy) theo góc lệch đó
    missPos = ballObj + d * travel                      // bi mục tiêu sẽ trôi tới đâu nếu trượt theo hướng này
    rail = khoảng cách từ missPos tới băng gần nhất
    nearestBallDist = khoảng cách từ missPos tới bi còn lại gần nhất
    hardness = 400/(rail+10) + (nearestBallDist<40 ? 25 : 0)  // sát băng hoặc kẹt gần bi khác = khó cho đối thủ hơn

  saferDirection = hướng có hardness cao hơn   // nên chủ động lệch nhẹ về hướng này làm biên an toàn
  return {thick, thin, saferDirection, errDeg}
```

Hiển thị cho người chơi: **"Nếu trượt, nên đánh dư [dày/mỏng] một chút — bi sẽ trôi về phía khó hơn cho đối thủ."** Đây là gợi ý định hướng dựa trên độ nhạy hình học (cắt mỏng sai số bị khuếch đại), không phải tính toán quỹ đạo trượt chính xác.

## 6. Yêu cầu UI

### 6.1 Chọn loại bàn
Toggle "9-bi / 10-bi" vs "8-bi" trước khi nhập bi. Đổi loại bàn thì xóa kế hoạch đã tính (nếu có), không đổi vị trí bi đã đặt.

### 6.2 Nhập bố cục bàn
- Đặt bi cái trước, sau đó chạm liên tiếp để thêm bi mục tiêu.
- **9/10-bi**: nhắc người dùng chạm theo ĐÚNG thứ tự số bi thật (bi 1 trước, bi 2 sau...), vì số thứ tự bi được gán theo thứ tự chạm.
- **8-bi**: thứ tự chạm không quan trọng vì thuật toán tự chọn bi dễ nhất.
- Có nút "Xóa bi cuối" và "Xóa hết".

### 6.3 Chỉ hiển thị tối đa 3 bi mỗi lần (đỡ rối khi bàn có 9-10 bi)

Sau khi tính kế hoạch, canvas **không vẽ tất cả bi cùng lúc**. Dùng con trỏ `viewIndex` (bắt đầu = 0):
- Chỉ vẽ các bi xuất hiện trong `plan[viewIndex..viewIndex+2]` (tối đa 3 bi liên quan tới bước hiện tại + 2 bước kế tiếp).
- Vẽ đường đánh của `plan[viewIndex]` rõ nét (alpha = 1) và `plan[viewIndex+1]` mờ hơn để xem trước (alpha ~0.45).
- Bi cái vẽ tại `plan[viewIndex].cbFrom`.

### 6.4 Điều hướng từng bước
- Nút **"Đã đánh xong → Bi tiếp theo"**: `viewIndex++` (giới hạn không vượt quá số bước). Mô phỏng đúng trải nghiệm thực tế: người chơi đánh xong 1 bi ngoài đời rồi mới xem gợi ý cho bi kế tiếp.
- Nút **"← Quay lại"**: `viewIndex--` (giới hạn ≥ 0), phòng khi bấm nhầm.
- Hiển thị "Bước X / N".
- Panel thông tin bước hiện tại: tên bi, lỗ, góc cắt, lực, đầu cơ. Panel "XEM TRƯỚC" (viền đứt nét) cho bước kế tiếp với cùng thông tin nhưng nhạt hơn.

### 6.5 Vẽ đường đi bi cái — bắt buộc thể hiện đúng vật lý đã chọn
- Đường ngắm (bi cái → điểm bi ma): nét đứt trắng.
- Đường bi cái sau va chạm: nét đứt màu ngọc (teal), vẽ theo **`landingCurve.pts`** — một đường GẤP KHÚC THẲNG (không phải đường cong), nối lần lượt ghost → (các điểm chạm băng nếu có) → điểm dừng cuối. Mỗi điểm chạm băng trong `landingCurve.hits` đánh dấu 1 chấm vàng nhỏ.
- **Không vẽ đường cong "bẻ sang" theo đầu cơ** — hiệu ứng trô/cu lê chỉ thể hiện qua hướng đi ban đầu (đã tính trong `pts`), không phải một đoạn cong vẽ thêm.
- Khi `bankUsed = true`, hiển thị trong panel: *"Bi cái chạm băng N lần rồi tới vùng điều — mỗi lần chạm hao khoảng 15% lực, lực X% đã tính phần hao này."* (thông tin, không phải cảnh báo — dội băng không phải điều đáng ngại).
- Khi `power ≥ 85%` hoặc `stroke = draw` (trô), hiển thị cảnh báo riêng: *"Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái hoặc sai số lớn hơn bình thường."*
- Khi có bi kế tiếp, hiển thị gợi ý từ `missSafetyAdvice` (mục 5.5): *"Nếu trượt: nên đánh dư [dày/mỏng] một chút — bi sẽ khó cho đối thủ hơn."* Vẽ 2 điểm "nếu trượt" (dư dày/dư mỏng) lên bàn, tô đậm điểm ứng với hướng được khuyến nghị.

### 6.5b Lớp hiển thị bổ sung trên bàn (bước hiện tại)

Ngoài các đường ở 6.5, với **bước đang xem** (không áp dụng cho bước xem trước) phải vẽ thêm, theo thứ tự từ dưới lên trên:

1. **Vùng điều tốt** (vẽ dưới cùng, không che bi/đường): lưới ô ~12px phủ mặt bàn; với mỗi ô, giả sử bi cái đứng ở đó (sau khi bi hiện tại đã vào lỗ), tính góc cắt dễ nhất để đánh bi kế tiếp (dùng đúng `bestAngleFrom`, cùng tập bi cản đường như lúc chấm điểm). Tô **xanh nhạt** nếu góc ≤ 35° (`ZONE_GOOD`), **vàng nhạt** nếu ≤ 55° (`ZONE_FAIR`), bỏ trống nếu xấu hơn/không có đường/đè lên bi khác. Chỉ vẽ khi có bi kế tiếp.
2. Đường bi mục tiêu → lỗ (nét liền), lỗ được chọn (vòng vàng lớn), vị trí bi ma (vòng nét đứt cỡ bi).
3. Vị trí bi cái sẽ dừng (vòng trắng nét đứt cỡ bi thật) + **thanh phạm vi sai số lực**: mô phỏng lại với lực −15% và +15% (`POWER_JITTER`, cùng đầu cơ), nối 2 điểm dừng đó qua điểm dừng chuẩn bằng một thanh vàng bo tròn, hai đầu có vòng nhỏ.
4. Chú giải (legend) dưới canvas giải thích từng lớp màu/ký hiệu.

Panel thông tin bước hiện tại thêm 1 dòng **"Độ chịu sai số lực"**: thử 7 mức lực đều nhau trong khoảng ±15%, với mỗi mức phân loại điểm dừng thành *vùng điều tốt / tạm được / xấu-hoặc-bị-chắn* và hiển thị số lượng (ví dụ "7/7 mức lực vẫn trong vùng điều tốt"). Đây là số liệu **để hiển thị cho người dùng hiểu độ chịu sai số** — dùng cùng các hàm mô phỏng/chấm điểm ở mục 5, không được có logic tính riêng khác đi.

**Lưu ý phân biệt:** chấm điểm ở mục 5.3 hiện dựa trên góc cắt xấu nhất trong 3 mức lực (−15%, chuẩn, +15%), chưa dùng tỉ lệ "phần đường đi của bi cái nằm trong vùng điều tốt". Nếu sau này muốn ưu tiên phương án có đường đi cắt qua vùng tốt nhiều hơn thì đó là thay đổi thuật toán riêng, cần cập nhật mục 3 và 5.3, không phải chỉ là thay đổi hiển thị.

### 6.6 Disclaimer bắt buộc
Luôn hiển thị: *"Lực và đầu cơ là gợi ý định hướng dựa trên hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, người chơi vẫn cần tự canh lực thực tế."* Không được bỏ dòng này — tính năng minh họa nguyên lý, không phải cam kết độ chính xác vật lý.

## 7. Test case bắt buộc (đã verify ở bản prototype, giữ nguyên khi build lại)

```
1. Continuity: với mọi bố cục hợp lệ, plan[i].landingPos === plan[i+1].cbFrom (sai số 0 tuyệt đối, không phải xấp xỉ).

2. Thứ tự 9/10-bi: với 1 bố cục 4 bi cố định, kế hoạch PHẢI đánh đúng thứ tự 1→2→3→4,
   bất kể bi nào trong đó có góc cắt dễ hơn các bi khác.

3. Thứ tự 8-bi: cùng bố cục trên, kế hoạch 8-bi được PHÉP đánh bi dễ nhất trước
   (ví dụ bi 3 trước bi 1), khác thứ tự số.

4. Dội băng: với 1 bố cục mà bi cái cần đi xa để tới vị trí tốt cho bi kế tiếp, ít nhất 1 bước
   trong kế hoạch phải có bankUsed = true, và landingCurve.hits không rỗng với mỗi điểm chạm nằm
   đúng trên biên bàn (bằng bounds.xmin/xmax/ymin/ymax ở 1 trong 2 tọa độ). landingCurve.pts phải
   là một đường gấp khúc thẳng đi qua đúng các điểm đó theo thứ tự.

5. Ưu tiên robustness hơn khoảng cách: dựng 1 bố cục có 2 tổ hợp (stroke, power) khả thi mà
   tổ hợp A cho vị trí gần bi kế tiếp hơn tổ hợp B nhưng A không chịu được sai số lực ±15%
   (robustDiff1 của A cao hơn B nhiều) — thuật toán phải chọn B, không chọn A dù A gần hơn.

6. Safety: bố cục mà bi hiện tại (theo đúng thứ tự bắt buộc, chế độ 9/10-bi) bị bi khác chắn hoàn
   toàn ở mọi lỗ -> bước đó phải là safety:true và kế hoạch dừng lại đúng tại đó (không có bước sau).

7. Dội băng không bị coi là khó: dựng 1 bố cục mà đánh thẳng (tâm bi hoặc cu lê) kèm 1 lần dội băng
   đưa bi cái tới vị trí tốt cho bi kế tiếp, TRONG KHI dùng trô (không cần dội băng) chỉ đưa bi cái
   tới vị trí tốt tương đương hoặc kém hơn một chút — thuật toán phải chọn phương án đánh thẳng + dội
   băng, KHÔNG chọn trô, vì bankPenalty (tối đa 7) luôn nhỏ hơn techPenalty của trô (10).

8. Chết cái: dựng 1 bố cục mà 1 tổ hợp (stroke, power) có đường đi lướt qua miệng 1 lỗ nào đó trong
   bán kính POCKET_DANGER — tổ hợp đó phải bị loại (curve.scratch = true), không được chọn dù điểm số
   vị trí của nó tốt hơn các tổ hợp còn lại.

9. Gợi ý dư dày/mỏng: với 1 cú cắt mỏng (góc cắt > 60°), errDeg tính ra phải lớn hơn rõ rệt so với
   1 cú cắt dày (góc cắt < 20°) với cùng MISS_ANGLE_DEG gốc — vì sensitivity = 1/cos(góc cắt) tăng
   nhanh khi góc cắt tiến gần 90°. Hàm không được trả lỗi khi obstaclesAfter rỗng (bi cuối cùng).
```

## 8. Ngoài phạm vi (không làm ở bản này)
- Không tính toán physics thật (ma sát lăn chi tiết, mất năng lượng khi va bi/va băng, hiệu ứng xoáy 3 chiều thật, squirt/swerve khi dùng áp phê) — đây vẫn là công cụ minh họa hình học.
- Không tối ưu toàn cục (global optimization) cho toàn bộ trình tự bi trong chế độ 8-bi — chỉ dùng lookahead 2 bước (N+1, N+2), không giải toàn bộ bài toán tối ưu thứ tự.
- `missSafetyAdvice` (mục 5.5) là gợi ý định tính, không mô phỏng quỹ đạo trượt thật (không tính bi mục tiêu nảy băng, không tính bi cái sau cú trượt) — nếu cần chính xác hơn, đây là hạng mục riêng cần bàn thêm.
- Chưa đưa đầu cơ có áp phê (side-spin: 3h/9h, trô áp phê, cu lê áp phê — đã có ở Cut Angle Simulator 1 cú đánh) vào candidate set của Run-out Planner nhiều bi; nếu thêm, cần tăng `techPenalty` cho các biến thể này cao hơn cả trô, vì càng nhiều thông số xoáy càng nhiều sai số cộng dồn.
