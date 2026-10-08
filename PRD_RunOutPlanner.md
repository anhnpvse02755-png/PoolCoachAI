# PRD — Run-out Planner & Position Play Engine (PoolCoachAI)

> Bổ sung cho `PoolCoachAI_SPEC.md`, thuộc module **Training Center → Cut Angle Simulator** (mục 4.3 trong spec chính). Tài liệu này mô tả một tính năng cụ thể: từ vị trí bi cái + các bi mục tiêu trên bàn, tính ra thứ tự đánh, lỗ, lực, đầu cơ, và vị trí bi cái nên dừng lại cho từng bước, để chạy hết bàn. Toàn bộ là logic thuần (deterministic, rule-based) — không dùng AI/LLM. Đường đi của bi lấy từ **mô phỏng vật lý tất định**, lõi chung với màn Mô phỏng góc cắt (`docs/superpowers/specs/2026-10-02-poolcoachai-table-physics-design.md`) *(sửa 2026-10-02: mô phỏng vật lý)*.

---

## 1. Bối cảnh & mục tiêu

Cut Angle Simulator (mục 4.3) hiện chỉ xử lý 1 cú đánh đơn lẻ. Tính năng này mở rộng thành **Kế hoạch dọn bàn** (Run-out Planner) *(sửa 2026-10-07: Kế hoạch dọn bàn)*: nhập toàn bộ bố cục bàn, hệ thống tự lên kế hoạch đánh hết bi theo đúng luật của loại bàn đang chơi, kèm gợi ý cụ thể cho từng bước (lực, đầu cơ, vị trí bi cái nên dừng).

Mục tiêu là công cụ **huấn luyện tư duy vị trí (position play)**. Đường đi bi được mô phỏng theo vật lý (trượt rồi lăn, xoáy, nảy băng, ném), nhưng hằng số là ước lượng chỉnh bằng mắt, không đo trên bàn thật. Mọi gợi ý phải nêu rõ người chơi vẫn cần tự canh lực thực tế *(sửa 2026-10-02: mô phỏng vật lý)*.

## 2. Luật theo loại bàn

| Loại bàn | Ràng buộc thứ tự |
|---|---|
| 9-bi / 10-bi | **Bắt buộc** đánh đúng thứ tự số bi tăng dần (1→2→3→...). Không được chọn bi khác dễ hơn để đánh trước. |
| 8-bi | Theo luật thật: người chơi chọn nhóm **Trơn** (1–7) hoặc **Sọc** (9–15). Ở mỗi bước, chọn trong các bi của mình cú đánh có góc cắt khả thi dễ nhất; bi đối thủ là bi chắn; **bi 8 luôn đánh cuối**, chỉ khi hết bi của mình. Khi còn đúng một bi của mình, bi kế tiếp là bi 8, nên bi áp chót được chấm theo độ dễ của cú bi 8 *(sửa 2026-10-07: Kế hoạch dọn bàn)* |

Người chơi chọn loại bàn trước khi nhập bi; thuật toán tương ứng khác nhau (xem mục 5).

## 3. Nguyên tắc cốt lõi: thứ tự ưu tiên khi chọn cách đánh

Đây là phần quan trọng nhất của toàn bộ tính năng — **phải giữ đúng thứ tự ưu tiên này khi chấm điểm các phương án**, không gộp thành trọng số ngang hàng:

1. **Má bi / góc cắt của CHÍNH cú đánh hiện tại** — chọn lỗ nào cho bi đang đánh dễ vào nhất (góc cắt nhỏ nhất trong số các lỗ khả thi, không bị bi khác chắn đường). Đây là điều kiện tiên quyết: sai má bi thì mọi tính toán vị trí phía sau vô nghĩa.
2. **Độ khó / tỉ lệ thành công của kỹ thuật cần dùng cho vị trí để lại** — thứ tự ưu tiên kỹ thuật từ dễ đến khó: **tâm bi (stun) > cu lê (12h) > trô (6h)**. Dội băng để lên vùng điều **KHÔNG được coi là một kỹ thuật khó** — đánh thẳng (tâm bi hoặc cu lê) rồi để bi tự chạm băng lên vùng điều là cách dễ kiểm soát nhất, dễ hơn nhiều so với dùng trô để "bẻ" bi cái sang một hướng khác. Càng ít thông số phải canh chỉnh (chỉ lực, không xoáy) thì sai số càng thấp, tỉ lệ thành công càng cao. **Tỉ lệ thành công cao luôn được ưu tiên hơn một vị trí "đẹp" nhưng khó thực hiện.**
3. **"Vùng điều tốt" — độ chịu sai số lực** — với cùng một đầu cơ, thử thêm/bớt lực (±15%) xem vị trí kết quả có còn dùng được cho cú kế tiếp không. Phương án mà cả một khoảng lực rộng đều cho vị trí tốt (không chỉ đúng 1 mức lực chính xác tuyệt đối mới ăn) được ưu tiên hơn — vì thực tế người chơi luôn có sai số lực nhất định.
4. **Khoảng cách giữa bi cái và bi mục tiêu kế tiếp** — CHỈ dùng để phân định khi các phương án đã ngang nhau ở (2) và (3). Không được xét trước (2)/(3).

Ngoài ra, khi so sánh vị trí để lại cho cú kế tiếp (bi N+1) và cú kế-kế-tiếp (bi N+2, ước lượng): **ưu tiên cân bằng độ khó giữa 2 vị trí hơn là tối ưu 1 vị trí thật đẹp còn 1 vị trí rất khó.** Dùng `max(diff_N+1, diff_N+2)` để chấm điểm, không dùng tổng — vì hai vị trí ở mức khá tốt hơn một vị trí đẹp + một vị trí khó (minimax thay vì trung bình/tổng).

**Lực và xoáy quá tay cũng là một loại rủi ro, không chỉ là chuyện kỹ thuật khó:** đánh quá mạnh hoặc xoáy quá nhiều (nhất là trô) làm tăng nguy cơ **chết cái (scratch)** và tăng sai số thực hiện. Vì vậy, ngoài thứ tự ưu tiên trên, thuật toán còn: (a) loại thẳng mọi phương án mà bi cái rơi lỗ trong mô phỏng (chết cái) *(sửa 2026-10-02: mô phỏng vật lý)*, và (b) cộng thêm điểm phạt tỉ lệ với % lực — không chỉ phạt "có xoáy hay không" mà phạt cả mức độ lực dùng.

## 4. Data model bổ sung

```typescript
interface Ball { num: number; x: number; y: number; }
interface Pocket { x: number; y: number; }

type StrokeType = 'center' | 'follow' | 'draw';
// center = tâm bi; follow = Cu lê (xoáy trên, 12h) — kéo bi cái TIẾN thêm theo hướng bi mục tiêu;
// draw = Trô (xoáy dưới, 6h) — kéo bi cái LÙI lại. (Quy ước tên gọi theo người dùng, không theo thuật ngữ tiếng Anh gốc.)
// center hiển thị là "Đánh đứng bi": bi cái tới bi mục tiêu ở trạng thái trượt, không xoáy dọc
// (lõi tự dò điểm đặt cơ dưới tâm cho đúng khoảng cách).
// (sửa 2026-10-02: mô phỏng vật lý) Đường đi bi cái lấy từ mô phỏng vật lý: sau va chạm bi cái rời đi
// theo tiếp tuyến, xoáy trô/cu lê làm nó CONG theo parabol cho tới khi lăn đều, rồi chạy THẲNG. Đường
// cong là cong thật do ma sát khăn, không phải đường "bẻ sang" vẽ tay.

const STROKE_CANDIDATES: StrokeType[] = ['center', 'follow', 'draw'];
const POWER_CANDIDATES = [30, 45, 60, 75, 90]; // % lực, các mức thử khi tìm phương án tốt nhất
const POWER_JITTER = 15; // % dùng để đo "vùng điều tốt" chịu sai số lực
// (sửa 2026-10-02: mô phỏng vật lý) Bỏ STROKE_SPIN, RAIL_LOSS, MAX_RAILS, POCKET_DANGER. Hằng số vật lý
// (ma sát khăn, nảy băng, ném, vận tốc bi cái ở lực 100%...) nằm ở mục 3 của spec lõi vật lý.
// Đơn vị: cm, bàn 254 × 127.

interface ShotGeometry {
  ghost: {x:number,y:number};   // điểm bi ảo hình học (nơi tâm bi cái cần chạm tới nếu không có ném)
  ux: number; uy: number;        // hướng bi mục tiêu -> lỗ (đơn vị)
  angle: number;                  // góc cắt (độ)
}

// (sửa 2026-10-02: mô phỏng vật lý) Thay LandingCurve bằng ShotTrace của lõi vật lý.
interface ShotTrace {
  cueBefore: {x:number,y:number}[];  // bi cái từ lúc đánh tới lúc chạm bi mục tiêu
  cueAfter: {x:number,y:number}[];   // bi cái sau va chạm tới khi dừng/rơi lỗ — cong chỗ cong, thẳng chỗ thẳng
  objectPath: {x:number,y:number}[]; // bi mục tiêu sau va chạm
  contactCue: {x:number,y:number} | null; // tâm bi cái lúc chạm (bi ảo đã bù ném)
  rails: {x:number,y:number}[];      // mọi điểm bi cái chạm băng sau va chạm, theo thứ tự
  cuePocket: number | null;          // bi cái rơi lỗ nào (chết cái), null nếu không
  objectPocket: number | null;       // bi mục tiêu vào lỗ nào, null nếu không vào
  cueEnd: {x:number,y:number};       // điểm bi cái dừng = phần tử cuối của cueAfter
  bankUsed: boolean;                 // = rails.length > 0
}

interface PlanStep {
  ballNum: number | null;          // null khi là bước "safety" ở chế độ 8-bi (không có bi cụ thể bị ép)
  pocketIndex: number;             // 0-5, khớp với thứ tự lỗ chuẩn (2 góc trên, 2 giữa băng, 2 góc dưới)
  angle: number;                    // góc cắt của cú đánh (độ)
  stroke: StrokeType;
  power: number;                    // % lực (từ POWER_CANDIDATES)
  bankUsed: boolean;
  cbFrom: {x:number,y:number};      // vị trí bi cái TRƯỚC cú đánh này
  elevation: 'normal';              // độ dốc cơ — Planner luôn dùng Thường (5°) (sửa 2026-10-02)
  ghost: {x:number,y:number};
  aimOffsetDeg: number;             // ngắm dày(+)/mỏng(−) hơn bi ảo hình học để bù ném (sửa 2026-10-02)
                                    // chỉ dùng bên trong, không bao giờ hiện lên màn (sửa 2026-10-07: Kế hoạch dọn bàn)
  trace: ShotTrace;                 // (sửa 2026-10-02: thay landingCurve)
  landingPos: {x:number,y:number} | null; // = trace.cueEnd; null chỉ khi hoàn toàn không tìm được phương án nào (edge case)
  nextBallHint: number | null;
  safety?: true;
  message?: string;                 // chỉ có khi safety = true
  // (sửa 2026-10-07: Kế hoạch dọn bàn)
  kind: 'normal' | 'fallback' | 'safety'; // fallback = Đánh đứng bi 30%, không có vị trí tốt; safety = phòng thủ, kế hoạch dừng
  spin: { side: 'left' | 'right' | null; tips: 0 | 0.5 | 1 }; // áp phê, chỉ khác 0 khi phải dùng đường lui áp phê
  sawsBhePercent: number | null;    // chỉ có khi dùng áp phê (bảng SAWS)
  jitterEnds: { minus: {x:number,y:number} | null; plus: {x:number,y:number} | null }; // điểm dừng ở lực −15% / +15% (kẹp ≤ 100%); null khi kind = fallback (sửa 2026-10-07: Kế hoạch dọn bàn)
  tolerance: { good: number; fair: number; bad: number } | null; // 7 mức lực trong ±15%; null khi là bi cuối hoặc kind = fallback (sửa 2026-10-07: Kế hoạch dọn bàn)
  safety: SafetyShot | null;        // chỉ ở bước kind = 'safety': cú thủ đã tìm; null khi không còn cú thủ hợp lệ (sửa 2026-10-07: cú phòng thủ)
}
```

`SafetyShot` *(sửa 2026-10-07: cú phòng thủ)*: `reason` (`snookered` bị đui · `noPot` không đui, hết đường ăn), `kind` (`direct` · `kick`), `rails` (số băng A băng, 0 khi trực tiếp), `ballNum` (bi hợp lệ được chạm), `thickness` + `side` (trọn bi, ¾, ½, ¼, ⅛; lệch trái/phải), `stroke`, `spin`, `power`, `aimed` (cú đã dò), `railAim` (băng đầu + số chấm, A băng), `opponent` (đối thủ bị đui? · cú dễ nhất: bi, lỗ, góc · hoặc hết đường ăn), `jitterEnds`, `tolerance` (số mức trong 7 mức lực vẫn khó cho đối thủ), `sawsBhePercent` (khi áp phê).

**Bất biến bắt buộc (invariant) — phải có unit test cho điều này:**
`plan[i].landingPos` (điểm bi cái dừng lại sau bước i) phải **bằng chính xác** `plan[i+1].cbFrom` (điểm bắt đầu của bước i+1). Cách đảm bảo: dùng thẳng `cand.trace.cueEnd` làm `cb` cho vòng lặp kế tiếp, không tính lại.

## 5. Thuật toán

### 5.1 Chọn bi + lỗ cho bước hiện tại (Priority 1 — Má bi)

- **9-bi/10-bi**: bi hiện tại = bi có số nhỏ nhất còn lại trên bàn (cố định, không được đổi).
- **8-bi**: bi hiện tại = bi có góc cắt khả thi dễ nhất trong các bi **của mình** còn lại (tìm kiếm toàn bộ tổ hợp bi × lỗ); bi đối thủ và bi 8 (khi chưa tới lượt) là bi chắn; hết bi của mình thì tới bi 8 *(sửa 2026-10-07: Kế hoạch dọn bàn)*.

Trong cả 2 trường hợp: với bi đã chọn, thử cả 6 lỗ, loại lỗ nào góc cắt > 85° hoặc đường bi cái→bi ảo hoặc bi→lỗ bị bi khác (còn trên bàn, kể cả bi chưa tới lượt trong chế độ 9/10-bi) chắn ngang. Chọn lỗ có góc cắt nhỏ nhất trong các lỗ hợp lệ. Nếu không lỗ nào hợp lệ → bước này là **safety** (dừng lập kế hoạch tại đây, không đoán tiếp vì kết quả cú safety không xác định trước được). Bước safety giờ **tìm cú thủ** (§5.6) rồi kế hoạch mới dừng, vì tới lượt đối thủ *(sửa 2026-10-07: cú phòng thủ)*.

### 5.2 Mô phỏng đường đi bi — vật lý tất định *(sửa 2026-10-02: mô phỏng vật lý)*

Planner không tự tính đường đi. Với mỗi tổ hợp, nó gọi lõi vật lý chung:

```
aimed = aimShot(cue = cb, object = bi đang đánh, pocket = lỗ đã chọn ở 5.1,
                stroke, power, spin = không áp phê, elevation = Thường)
trace = aimed.trace
```

Lõi làm những việc sau (chi tiết ở spec lõi vật lý, mục 4):

- Tích phân từng bước 1 ms vị trí, vận tốc và xoáy 3 chiều của bi cái và bi mục tiêu.
- Bi cái **trượt rồi lăn**: đoạn trượt cong theo parabol do xoáy trô/cu lê, đoạn lăn thẳng và chậm dần.
- Băng: nảy có hao lực, góc bật phụ thuộc xoáy. **Không giới hạn số băng** — bi tự dừng vì mất lực.
- Va chạm bi–bi có **ném**. `aimShot` dò hướng cơ để bi mục tiêu vẫn vào giữa lỗ (bù ném) và báo `aimOffsetDeg`.
- Đánh đứng bi: lõi dò điểm đặt cơ dưới tâm để bi cái tới nơi đúng lúc hết xoáy dọc.
- Chết cái = bi cái **thật sự rơi lỗ** trong mô phỏng.
- Tất định: cùng đầu vào thì cùng kết quả.

Đường đi là chuỗi điểm của mô phỏng: **cong chỗ cong, thẳng chỗ thẳng**. Không có đường cong nào vẽ tay hay cộng thêm bằng công thức.

### 5.3 Chấm điểm phương án (Priority 2, 3, 4 — theo đúng thứ tự mục 3)

Với mỗi tổ hợp `(stroke, power)` trong `STROKE_CANDIDATES × POWER_CANDIDATES`:

```
trace = aimShot(...).trace                         // mục 5.2 (sửa 2026-10-02)
nếu trace.cuePocket != null -> LOẠI (chết cái)
nếu trace.objectPocket != lỗ đã chọn -> LOẠI (bi mục tiêu không vào)
nếu cueBefore / cueAfter / objectPath bị bi khác chắn -> LOẠI tổ hợp này

E = trace.cueEnd
railCount = trace.rails.length                    // số lần bi cái chạm băng sau va chạm
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

Nếu KHÔNG tổ hợp nào hợp lệ, đi theo thứ tự dự phòng, tầng sau chỉ chạy khi tầng trước không còn phương án nào *(sửa 2026-10-07: Kế hoạch dọn bàn)*:

1. Đứng / cu lê / trô × 5 mức lực (như trên).
2. **Áp phê, chỉ như đường lui:** thử kiểu đánh × {trái, phải} × {½, 1 đầu cơ} × 5 mức lực (60 phương án), cùng điều kiện loại và cùng cách chấm. Phạt kỹ thuật cộng dồn: `techPenalty` của kiểu đánh + `sidePenalty` (½ đầu cơ = 15, 1 đầu cơ = 20), ví dụ trô + 1 đầu cơ = 10 + 20. Bước dùng áp phê kèm lời khuyên SAWS (tỉ lệ BHE/FHE), không bao giờ nói độ lệch ngắm theo độ.
3. **Đánh đứng bi 30%** nếu cú đó vẫn đưa bi vào đúng lỗ, không chết cái, không đi qua bi chắn. Bỏ qua phần vị trí; màn báo *"Không có vị trí tốt cho bi sau."*; kế hoạch đi tiếp từ điểm dừng của cú đó.
4. Cả cú đó cũng không được thì là bước **phòng thủ**: tìm cú thủ (§5.6); kế hoạch dừng sau bước này *(sửa 2026-10-07: cú phòng thủ)*.

Bằng điểm thì giữ phương án thử trước (kiểu đánh theo thứ tự đứng, cu lê, trô; rồi lực tăng dần), để kết quả tất định.

### 5.4 Vòng lặp chính

```
cb = vị trí bi cái ban đầu
lặp qua từng bi (theo 5.1):
  tìm best (bi, lỗ) theo Priority 1
  nếu không tìm được -> tìm cú thủ (§5.6), đẩy bước safety kèm cú thủ (hoặc null), DỪNG (sửa 2026-10-07: cú phòng thủ)
  cand = chấm điểm theo 5.3, dùng nextBall/nextNextBall:
    - 9/10-bi: nextBall/nextNextBall = bi kế tiếp/kế-kế-tiếp theo đúng thứ tự số
    - 8-bi: nextBall/nextNextBall = bi của mình có góc cắt dễ nhất từ điểm dừng (không phải tối ưu toàn cục); còn đúng một bi của mình thì bi kế tiếp là bi 8 (sửa 2026-10-07: Kế hoạch dọn bàn)
  đẩy PlanStep với cbFrom = cb (giá trị TRƯỚC khi cập nhật)
  cb = cand.trace.cueEnd   // bắt buộc: bước sau dùng ĐÚNG điểm này, không tính lại (sửa 2026-10-02)
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

### 5.6 Cú phòng thủ *(sửa 2026-10-07: cú phòng thủ)*

Chạy ở bước phòng thủ (tầng 4 của §5.3, hoặc khi không có cặp bi–lỗ nào). Kế hoạch vẫn dừng sau bước này vì tới lượt đối thủ.

- **Phân loại.** Bị đui khi từ bi cái cả ba đường — tới bi ảo trọn bi, và hai đường mỏng sát hai mép bi hợp lệ — đều bị bi khác chắn. 8-bi: bi hợp lệ là mọi bi nhóm mình (hết thì bi 8), đui khi mọi bi hợp lệ đều bị chắn.
- **Cú thủ trực tiếp** (mỗi bi hợp lệ nhìn thấy được, bi số nhỏ trước): độ dày trọn bi, ¾, ½, ¼, ⅛ (trừ trọn bi, mỗi mức lệch hai bên) × đứng / cu lê / trô × 3 mức lực 30 · 60 · 90%, **không áp phê** = tối đa 81 phương án mỗi bi; bỏ trước độ dày mà đường bi cái tới bi ảo bị chắn. Chỉ khi không phương án nào của bi đó hợp lệ mới thử thêm áp phê (trái ½, trái 1, phải ½, phải 1 đầu cơ) = tối đa 324 phương án *(sửa 2026-10-08: áp phê là đường lui; cú thủ chỉ 3 mức lực)*.
- **A băng — luôn thử, kể cả khi không đui** *(sửa 2026-10-08)*: mọi chuỗi băng không lặp băng liền nhau (1 băng 4, 2 băng 12, 3 băng 36, 4 băng 108) vào mọi bi hợp lệ; hướng ban đầu soi gương bi hợp lệ qua chuỗi, bỏ chuỗi bị chắn hoặc chạm băng ở miệng lỗ; mỗi chuỗi: đứng / cu lê × 3 mức lực 30 · 60 · 90% × chạm trọn bi hoặc ½ bi hai bên, không áp phê. Thử 1–3 băng; chỉ khi không còn phương án hợp lệ nào (trực tiếp hay 1–3 băng) mới thử 4 băng. Bị đui thì không có cú trực tiếp, chỉ còn A băng.
- **Thứ tự cố định:** cú trực tiếp trước (từng bi: không áp phê, rồi áp phê nếu cần), rồi A băng 1–3 băng, rồi 4 băng. Cú trực tiếp và A băng chấm cùng một thang điểm; phạt A băng giữ cú trực tiếp thắng khi gần ngang *(sửa 2026-10-08)*.
- **Lượt thô trước** *(sửa 2026-10-08: lượt thô)*: trước hết chỉ thử trực tiếp trọn bi và ½ bi hai bên không áp phê, cùng A băng 1–2 băng chạm trọn bi (đủ kiểu đánh, 30 · 60 · 90%). Cú tốt nhất của lượt thô mà thủ tốt (đối thủ bị đui, hết đường ăn, hay góc dễ nhất > 55°) thì hiện bước ngay với cú đó và hỏi: *"Tính toán cơ bản thì đánh như thế này là thủ tốt, có thể có phương án tối ưu hơn nhưng sẽ mất thời gian tính toán. Bạn muốn tính tiếp hay không?"* — *Tính tiếp* chạy đủ các bước tìm bên dưới (không làm lại phần đã tính) và chỉ đổi cú khi điểm tốt hơn hẳn; *Dùng cú này* giữ cú lượt thô. Lượt thô ra cú mà chưa thủ tốt thì hiện cú đó **tạm** (*"Cú thủ tạm tính — đang tìm cú tốt hơn…"*), tự tìm tiếp không hỏi, xong thì chỉ đổi cú khi tốt hơn hẳn. Lượt thô không ra cú hợp lệ nào thì chờ *"Đang tìm cú thủ…"* tới khi tìm xong. Trong lúc tìm cú thủ, mỗi khung hình tính 12 ms thay 4 ms (người dùng đang chờ, không kéo bi).
- **Dò hướng cơ bằng mô phỏng thật** cho bi cái chạm bi hợp lệ đúng độ dày, sau đúng chuỗi băng; không hội tụ thì bỏ phương án.
- **Luật WPA:** loại phương án nếu bi cái chạm bi khác trước, sai số băng trước va chạm (A băng), sau va chạm không bi nào chạm băng, chết cái, bi hợp lệ rơi lỗ, đường bi hợp lệ hoặc bi cái sau va chạm đi qua bi chắn, hoặc lõi quá giờ.
- **Chấm điểm** (thấp là tốt), mỗi mức lực (chọn, −15%, +15%, kẹp ≤ 100%): phần đối thủ (đui → 0; không đui → 95 − góc cắt dễ nhất của đối thủ; không lỗ nào → 0) − 5 cho mỗi bi sát băng (cách băng ≤ một bi: bi cái, bi đối thủ phải đánh dễ nhất) − khoảng cách bi cái → bi đó (cm) × 0,01; mức phạm luật tính 95. Lấy mức xấu nhất, cộng phạt kỹ thuật (như §5.3, áp phê cộng dồn) + phạt A băng (1 băng 10, 2 băng 20, 3 băng 45, 4 băng 55) + lực × 0,04. Bằng điểm giữ phương án thử trước.
- **Đối thủ đánh bi nào:** 9/10-bi là bi số nhỏ nhất còn trên bàn ở vị trí mới sau cú thủ; 8-bi là bi nhóm kia, hết thì bi 8.
- **Độ chịu sai số lực** (chỉ hiển thị): số mức trong 7 mức lực đều nhau ±15% mà đối thủ bị đui, hết đường ăn, hay góc dễ nhất > 55°.

## 6. Yêu cầu UI

Tên tính năng trên màn là **Kế hoạch dọn bàn**: tên thẻ trong Luyện tập (ngay dưới thẻ Mô phỏng góc cắt) và tiêu đề màn, đường dẫn `/training/planner` *(sửa 2026-10-07: Kế hoạch dọn bàn)*.

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
- Các bi khác còn trên bàn (chưa vào lỗ tính tới bước đang xem — gồm bi chắn và bi đối thủ) vẫn vẽ, nhưng rất mờ như bóng bi, dưới mọi đường đánh: người chơi thấy được bi nào chắn đường mà bàn không rối *(sửa 2026-10-07: Kế hoạch dọn bàn)*.

### 6.4 Điều hướng từng bước
- Nút **"Đã đánh xong → Bi tiếp theo"**: hỏi *"Bi cái dừng đúng chỗ dự kiến?"*. **Đúng** thì `viewIndex++` (giới hạn không vượt quá số bước). **Đặt lại bi cái** thì bàn vào chế độ kéo bi cái; bấm *Tính lại từ đây* thì lập kế hoạch mới từ chỗ bi cái dừng thật, với các bi còn lại. Ở bước cuối nút đổi thành *Xong bàn*, bấm vào thì quay về Luyện tập (sửa 2026-10-07: Kế hoạch dọn bàn). Mô phỏng đúng trải nghiệm thực tế: người chơi đánh xong 1 bi ngoài đời rồi mới xem gợi ý cho bi kế tiếp *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
- Tính từng bước: bước 1 hiện sau khoảng 1 giây, các bước sau tính tiếp trong nền với dòng *"Đang tính bước X/N…"*; nút *Đã đánh xong* ở bước cuối đã tính thì chờ bước kế tiếp *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
- Nút **"← Quay lại"**: `viewIndex--` (giới hạn ≥ 0), phòng khi bấm nhầm.
- Hiển thị "Bước X / N".
- Panel thông tin bước hiện tại: tên bi, lỗ, góc cắt, lực, đầu cơ. Panel "XEM TRƯỚC" (viền đứt nét) cho bước kế tiếp với cùng thông tin nhưng nhạt hơn.

### 6.5 Vẽ đường đi bi cái — bắt buộc thể hiện đúng vật lý đã chọn
- Đường bi cái tới bi mục tiêu (`trace.cueBefore`): nét đứt trắng *(sửa 2026-10-02: Planner không dùng áp phê nên đường này gần như thẳng tới bi ảo đã bù ném)*.
- Đường bi cái sau va chạm: nét đứt màu ngọc (teal), vẽ đúng chuỗi điểm **`trace.cueAfter`** của mô phỏng — cong chỗ cong (đoạn trượt có xoáy), thẳng chỗ thẳng (đoạn lăn), qua các điểm chạm băng tới điểm dừng. Mỗi điểm trong `trace.rails` đánh dấu 1 chấm vàng nhỏ *(sửa 2026-10-02: mô phỏng vật lý)*.
- **Không vẽ đường cong tự chế** — mọi chỗ cong trên màn phải là cong của mô phỏng vật lý, không vẽ thêm bằng công thức.
- Khi `bankUsed = true`, hiển thị trong panel: *"Bi cái chạm băng N lần rồi tới vùng điều."* (bỏ vế "mỗi lần chạm hao khoảng 15% lực": lõi vật lý tính hao lực thật) *(sửa 2026-10-07: Kế hoạch dọn bàn)* (thông tin, không phải cảnh báo — dội băng không phải điều đáng ngại).
- Khi `power ≥ 85%` hoặc `stroke = draw` (trô), hiển thị cảnh báo riêng: *"Lực cao / dùng trô — quá tay hoặc quá áp phê dễ chết cái hoặc sai số lớn hơn bình thường."*
- Khi có bi kế tiếp, hiển thị gợi ý từ `missSafetyAdvice` (mục 5.5): *"Nếu trượt: nên đánh dư [dày/mỏng] một chút — bi sẽ khó cho đối thủ hơn."* Vẽ 2 điểm "nếu trượt" (dư dày/dư mỏng) lên bàn, tô đậm điểm ứng với hướng được khuyến nghị.

### 6.5b Lớp hiển thị bổ sung trên bàn (bước hiện tại)

Ngoài các đường ở 6.5, với **bước đang xem** (không áp dụng cho bước xem trước) phải vẽ thêm, theo thứ tự từ dưới lên trên:

1. **Vùng điều tốt** (vẽ dưới cùng, không che bi/đường): lưới ô ~5 cm phủ mặt bàn *(sửa 2026-10-02: đơn vị cm)*; với mỗi ô, giả sử bi cái đứng ở đó (sau khi bi hiện tại đã vào lỗ), tính góc cắt dễ nhất để đánh bi kế tiếp (dùng đúng `bestAngleFrom`, cùng tập bi cản đường như lúc chấm điểm). Tô **xanh nhạt** nếu góc ≤ 35° (`ZONE_GOOD`), **vàng nhạt** nếu ≤ 55° (`ZONE_FAIR`), bỏ trống nếu xấu hơn/không có đường/đè lên bi khác. Chỉ vẽ khi có bi kế tiếp.
2. Đường bi mục tiêu → lỗ (nét liền), lỗ được chọn (vòng vàng lớn), vị trí bi ảo (vòng nét đứt cỡ bi).
3. Vị trí bi cái sẽ dừng (vòng trắng nét đứt cỡ bi thật) + **thanh phạm vi sai số lực**: mô phỏng lại với lực −15% và +15% (`POWER_JITTER`, cùng đầu cơ), nối 2 điểm dừng đó qua điểm dừng chuẩn bằng một thanh vàng bo tròn, hai đầu có vòng nhỏ.
4. Chú giải (legend) dưới canvas giải thích từng lớp màu/ký hiệu.

Panel thông tin bước hiện tại thêm 1 dòng **"Độ chịu sai số lực"**: thử 7 mức lực đều nhau trong khoảng ±15%, với mỗi mức phân loại điểm dừng thành *vùng điều tốt / tạm được / xấu-hoặc-bị-chắn* và hiển thị số lượng (ví dụ "7/7 mức lực vẫn trong vùng điều tốt"). Đây là số liệu **để hiển thị cho người dùng hiểu độ chịu sai số** — dùng cùng các hàm mô phỏng/chấm điểm ở mục 5, không được có logic tính riêng khác đi.

Với bước `kind = fallback` (Đánh đứng bi 30%, không có vị trí tốt): `score`, `jitterEnds` và `tolerance` đều null; màn không vẽ thanh phạm vi sai số lực và không hiện dòng "Độ chịu sai số lực", nhưng vẫn hiện dòng "Nếu trượt" khi có bi kế tiếp, kèm *"Không có vị trí tốt cho bi sau."* (sửa 2026-10-07: Kế hoạch dọn bàn).

**Lưu ý phân biệt:** chấm điểm ở mục 5.3 hiện dựa trên góc cắt xấu nhất trong 3 mức lực (−15%, chuẩn, +15%), chưa dùng tỉ lệ "phần đường đi của bi cái nằm trong vùng điều tốt". Nếu sau này muốn ưu tiên phương án có đường đi cắt qua vùng tốt nhiều hơn thì đó là thay đổi thuật toán riêng, cần cập nhật mục 3 và 5.3, không phải chỉ là thay đổi hiển thị.

### 6.6 Disclaimer bắt buộc
Luôn hiển thị: *"Lực và đầu cơ là gợi ý định hướng dựa trên hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, người chơi vẫn cần tự canh lực thực tế."* Không được bỏ dòng này — tính năng minh họa nguyên lý, không phải cam kết độ chính xác vật lý.

### 6.7 Bước phòng thủ *(sửa 2026-10-07: cú phòng thủ)*

- **Trên bàn**, từ dưới lên: bi khác vẽ mờ; cú dễ nhất của đối thủ mờ màu đỏ (bi cái → bi ảo → lỗ), hoặc đường bị chắn kèm chữ *"Đối thủ bị đui"*; đường bi cái đúng từ mô phỏng (trước va chạm nét đứt trắng qua các băng, chấm vàng ở mỗi lần chạm băng; sau va chạm nét đứt ngọc; vòng trắng chỗ dừng); A băng: vòng vàng đậm ở điểm ngắm trên băng đầu và số chấm ở mép bàn (băng dài 0–8, băng ngắn 0–4); đường bi hợp lệ sau va chạm và chỗ nó dừng; thanh sai số lực.
- **Bảng thông tin:** *"Bi cái bị đui bi N — đánh A băng để thủ."* hoặc *"Không còn đường ăn bi — nên thủ bi."*; A băng *"A băng K băng: ngắm chấm X băng Y."*; trực tiếp *"Ăn ½ bi, lệch bên trái."* (hoặc *"Ăn trọn bi."*); kiểu đánh, lực; áp phê như màn mô phỏng; kết quả cho đối thủ (*"Đối thủ bị đui."* · *"Cú dễ nhất của đối thủ: bi N vào lỗ X, góc cắt Y°."* · *"Đối thủ không còn đường ăn."*); *"k/7 mức lực vẫn để đối thủ khó."*; cảnh báo lực ≥ 85% hoặc trô.
- Đang tìm thì hiện *"Đang tìm cú thủ…"*. Lượt thô ra cú thủ tốt thì dưới bảng thông tin hiện câu hỏi của chủ sản phẩm và hai nút *Tính tiếp* · *Dùng cú này*; ra cú chưa thủ tốt thì hiện cú tạm kèm *"Cú thủ tạm tính — đang tìm cú tốt hơn…"* *(sửa 2026-10-08: lượt thô)*. Không tìm được cú thủ hợp lệ thì giữ câu *"… nên chơi an toàn (safety) thay vì cố đánh."*. Bước phòng thủ là bước cuối: nút *Xong bàn*.
- Không câu nào khuyên ngắm theo độ; số độ chỉ ở kết quả cho đối thủ.

## 7. Test case bắt buộc (đã verify ở bản prototype, giữ nguyên khi build lại)

```
1. Continuity: với mọi bố cục hợp lệ, plan[i].landingPos === plan[i+1].cbFrom (sai số 0 tuyệt đối, không phải xấp xỉ).

2. Thứ tự 9/10-bi: với 1 bố cục 4 bi cố định, kế hoạch PHẢI đánh đúng thứ tự 1→2→3→4,
   bất kể bi nào trong đó có góc cắt dễ hơn các bi khác.

3. Thứ tự 8-bi: cùng bố cục trên, kế hoạch 8-bi được PHÉP đánh bi dễ nhất trước
   (ví dụ bi 3 trước bi 1), khác thứ tự số.

4. Dội băng: với 1 bố cục mà bi cái cần đi xa để tới vị trí tốt cho bi kế tiếp, ít nhất 1 bước
   trong kế hoạch phải có bankUsed = true, và trace.rails không rỗng với mỗi điểm chạm nằm
   đúng trên biên bàn (bằng bounds.xmin/xmax/ymin/ymax ở 1 trong 2 tọa độ). trace.cueAfter phải
   đi qua đúng các điểm đó theo thứ tự *(sửa 2026-10-02: đường đi là chuỗi điểm mô phỏng, có thể cong)*.

5. Ưu tiên robustness hơn khoảng cách: dựng 1 bố cục có 2 tổ hợp (stroke, power) khả thi mà
   tổ hợp A cho vị trí gần bi kế tiếp hơn tổ hợp B nhưng A không chịu được sai số lực ±15%
   (robustDiff1 của A cao hơn B nhiều) — thuật toán phải chọn B, không chọn A dù A gần hơn.

6. Safety: bố cục mà bi hiện tại (theo đúng thứ tự bắt buộc, chế độ 9/10-bi) bị bi khác chắn hoàn
   toàn ở mọi lỗ -> bước đó phải là safety:true và kế hoạch dừng lại đúng tại đó (không có bước sau).

7. Dội băng không bị coi là khó: dựng 1 bố cục mà đánh thẳng (tâm bi hoặc cu lê) kèm 1 lần dội băng
   đưa bi cái tới vị trí tốt cho bi kế tiếp, TRONG KHI dùng trô (không cần dội băng) chỉ đưa bi cái
   tới vị trí tốt tương đương hoặc kém hơn một chút — thuật toán phải chọn phương án đánh thẳng + dội
   băng, KHÔNG chọn trô, vì bankPenalty (tối đa 7) luôn nhỏ hơn techPenalty của trô (10).

8. Chết cái: dựng 1 bố cục mà 1 tổ hợp (stroke, power) làm bi cái rơi lỗ trong mô phỏng
   (trace.cuePocket != null) — tổ hợp đó phải bị loại, không được chọn dù điểm số
   vị trí của nó tốt hơn các tổ hợp còn lại.

9. Gợi ý dư dày/mỏng: với 1 cú cắt mỏng (góc cắt > 60°), errDeg tính ra phải lớn hơn rõ rệt so với
   1 cú cắt dày (góc cắt < 20°) với cùng MISS_ANGLE_DEG gốc — vì sensitivity = 1/cos(góc cắt) tăng
   nhanh khi góc cắt tiến gần 90°. Hàm không được trả lỗi khi obstaclesAfter rỗng (bi cuối cùng).
```

## 8. Ngoài phạm vi (không làm ở bản này)
- *(sửa 2026-10-02: mô phỏng vật lý)* Bi thứ ba trở lên không tham gia va chạm trong mô phỏng — chỉ dùng để kiểm chắn đường trên `cueBefore`, `cueAfter`, `objectPath`. Không mô phỏng massé, bi nảy khỏi mặt bàn, hay bi va mép miệng lỗ.
- Không tối ưu toàn cục (global optimization) cho toàn bộ trình tự bi trong chế độ 8-bi — chỉ dùng lookahead 2 bước (N+1, N+2), không giải toàn bộ bài toán tối ưu thứ tự.
- `missSafetyAdvice` (mục 5.5) là gợi ý định tính, không mô phỏng quỹ đạo trượt thật (không tính bi mục tiêu nảy băng, không tính bi cái sau cú trượt) — nếu cần chính xác hơn, đây là hạng mục riêng cần bàn thêm.
- ~~Chưa đưa đầu cơ có áp phê vào candidate set~~ — áp phê nay **có** trong Planner, nhưng **chỉ như đường lui** khi không phương án đứng / cu lê / trô nào dùng được, với phạt cộng dồn cao hơn trô (xem §5.3) *(sửa 2026-10-07: Kế hoạch dọn bàn)*.
- Cú phòng thủ nay **có** trong Planner (§5.6), nhưng kế hoạch vẫn **dừng sau cú thủ** vì tới lượt đối thủ; không lập kế hoạch cho lượt sau, không có cú nhảy bi (massé, jump), và không theo luật "bi chạm băng" riêng của từng giải ngoài WPA *(sửa 2026-10-07: cú phòng thủ)*.
