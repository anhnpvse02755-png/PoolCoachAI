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
2. **Độ khó / tỉ lệ thành công của kỹ thuật cần dùng cho vị trí để lại** — thứ tự ưu tiên kỹ thuật từ dễ đến khó: **tâm bi (stun) > trô/cu lê (follow/draw) > phải dội băng**. Lý do: càng ít thông số phải canh chỉnh (chỉ lực, không xoáy, không băng) thì sai số càng thấp, tỉ lệ thực hiện thành công càng cao. **Tỉ lệ thành công cao luôn được ưu tiên hơn một vị trí "đẹp" nhưng khó thực hiện.**
3. **"Vùng điều tốt" — độ chịu sai số lực** — với cùng một đầu cơ, thử thêm/bớt lực (±15%) xem vị trí kết quả có còn dùng được cho cú kế tiếp không. Phương án mà cả một khoảng lực rộng đều cho vị trí tốt (không chỉ đúng 1 mức lực chính xác tuyệt đối mới ăn) được ưu tiên hơn — vì thực tế người chơi luôn có sai số lực nhất định.
4. **Khoảng cách giữa bi cái và bi mục tiêu kế tiếp** — CHỈ dùng để phân định khi các phương án đã ngang nhau ở (2) và (3). Không được xét trước (2)/(3).

Ngoài ra, khi so sánh vị trí để lại cho cú kế tiếp (bi N+1) và cú kế-kế-tiếp (bi N+2, ước lượng): **ưu tiên cân bằng độ khó giữa 2 vị trí hơn là tối ưu 1 vị trí thật đẹp còn 1 vị trí rất khó.** Dùng `max(diff_N+1, diff_N+2)` để chấm điểm, không dùng tổng — vì hai vị trí ở mức khá tốt hơn một vị trí đẹp + một vị trí khó (minimax thay vì trung bình/tổng).

## 4. Data model bổ sung

```typescript
interface Ball { num: number; x: number; y: number; }
interface Pocket { x: number; y: number; }

type StrokeType = 'center' | 'follow' | 'draw';
// center = tâm bi (stun); follow = Cu lê, xoáy trên 12h, bi cái cong tiến tới sau khi cắt qua tiếp tuyến;
// draw = Trô, xoáy dưới 6h, bi cái cong lùi lại. (Quy ước tên gọi theo người dùng, không theo thuật ngữ tiếng Anh gốc.)

const STROKE_CANDIDATES: StrokeType[] = ['center', 'follow', 'draw'];
const POWER_CANDIDATES = [40, 70, 95]; // % lực, các mức thử khi tìm phương án tốt nhất
const POWER_JITTER = 15; // % dùng để đo "vùng điều tốt" chịu sai số lực

interface ShotGeometry {
  ghost: {x:number,y:number};   // điểm bi ma (nơi tâm bi cái cần chạm tới)
  ux: number; uy: number;        // hướng bi mục tiêu -> lỗ (đơn vị)
  angle: number;                  // góc cắt (độ)
}

interface LandingCurve {
  p1: {x:number,y:number}; p2: {x:number,y:number}; // control points để vẽ bezier
  end: {x:number,y:number};       // điểm bi cái thực sự dừng lại
  bankUsed: boolean;               // cú này có cần dội băng mới tới `end` không
  hit?: {x:number,y:number};       // điểm chạm băng, chỉ có khi bankUsed = true
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
`plan[i].landingPos` (điểm bi cái dừng lại sau bước i) phải **bằng chính xác** `plan[i+1].cbFrom` (điểm bắt đầu của bước i+1). Đây là lỗi đã từng xảy ra ở bản trước (2 điểm được tính độc lập rồi vẽ lệch nhau) — không được lặp lại. Cách đảm bảo: dùng thẳng `cand.end` làm `cb` cho vòng lặp kế tiếp, không tính lại.

## 5. Thuật toán

### 5.1 Chọn bi + lỗ cho bước hiện tại (Priority 1 — Má bi)

- **9-bi/10-bi**: bi hiện tại = bi có số nhỏ nhất còn lại trên bàn (cố định, không được đổi).
- **8-bi**: bi hiện tại = bi có góc cắt khả thi dễ nhất trong TẤT CẢ bi còn lại (tìm kiếm toàn bộ tổ hợp bi × lỗ).

Trong cả 2 trường hợp: với bi đã chọn, thử cả 6 lỗ, loại lỗ nào góc cắt > 85° hoặc đường bi cái→bi ma hoặc bi→lỗ bị bi khác (còn trên bàn, kể cả bi chưa tới lượt trong chế độ 9/10-bi) chắn ngang. Chọn lỗ có góc cắt nhỏ nhất trong các lỗ hợp lệ. Nếu không lỗ nào hợp lệ → bước này là **safety** (dừng lập kế hoạch tại đây, không đoán tiếp vì kết quả cú safety không xác định trước được).

### 5.2 Mô phỏng thuận đường đi bi cái, có tính dội băng

Với hình học `g` (ghost, ux, uy, hướng tiếp tuyến `tx,ty` = thành phần vận tốc bi cái còn lại sau va chạm, độ dài tỉ lệ `sin(góc cắt)`):

```
function simulateWithRail(g, stroke, power, bounds):
  segLen = 260 * (power/100) * min(1, perpLen)          // quãng đường đi được, giới hạn bởi vật lý cú cắt
  rail = tia từ ghost theo hướng tiếp tuyến, tìm điểm chạm biên bàn gần nhất
  if không có biên nào trong tầm segLen:
    return đường cong bình thường theo `stroke` (xem 5.3), bankUsed = false
  else:
    // TÁCH 2 ĐOẠN — không được vẽ gộp thành 1 đường cong duy nhất
    đoạn 1: đường THẲNG từ ghost tới điểm chạm băng (hit)
    phản xạ hướng đi tại hit (trục nào chạm thì đảo dấu trục đó — góc tới = góc phản xạ)
    đoạn 2: áp dụng hiệu ứng `stroke` (follow cong tới / draw cong lùi) cho quãng đường CÒN LẠI, bắt đầu từ hit
    return {đoạn 1 + đoạn 2 nối tiếp}, bankUsed = true, hit = điểm chạm
```

### 5.3 Hiệu ứng đầu cơ lên đường đi (không đổi so với Cut Angle Simulator hiện có)

- `center`: đi thẳng theo hướng tiếp tuyến, dừng lại ở cuối quãng đường.
- `follow`: cong vọt qua đường tiếp tuyến, lượn về phía trước theo hướng bi mục tiêu vừa đi (`ux,uy`) — offset về phía trước tỉ lệ với lực.
- `draw`: cong ngược lại, kéo bi cái lùi về phía sau — offset về phía sau tỉ lệ với lực.

### 5.4 Chấm điểm phương án (Priority 2, 3, 4 — theo đúng thứ tự mục 3)

Với mỗi tổ hợp `(stroke, power)` trong `STROKE_CANDIDATES × POWER_CANDIDATES`:

```
curve = simulateWithRail(g, stroke, power, bounds)
nếu đường đi bị bi khác chắn -> LOẠI tổ hợp này

E = curve.end
nếu không còn bi tiếp theo (đây là bi cuối):
  score = (bankUsed ? 20 : 0) + (stroke != center ? 4 : 0)   // chỉ ưu tiên đơn giản, không có gì để canh vị trí
  ghi nhận nếu score thấp nhất, next

diff1 = góc cắt dễ nhất có thể để đánh bi kế tiếp từ E (thử cả 6 lỗ, loại lỗ bị chắn)
nếu không lỗ nào khả thi từ E -> LOẠI tổ hợp này (vị trí này giết chết cú kế tiếp)

// Priority 3 — vùng điều tốt: thử power ± POWER_JITTER (cùng stroke), lấy góc XẤU NHẤT trong 3 mức lực
robustDiff1 = max(diff1(power), diff1(power-15), diff1(power+15))
  // nếu 1 trong 2 mức lệch bị chắn hoặc không khả thi -> tính là 95 (rất khó), không loại hẳn tổ hợp gốc

// nhìn thêm 1 bi nữa để tránh "1 đẹp 1 tệ": giả định cú kế tiếp đánh tâm bi lực 55% mặc định
diff2 = góc cắt dễ nhất cho bi kế-kế-tiếp, xuất phát từ vị trí bi cái giả định sau cú kế tiếp đó

posScore = diff2 tồn tại ? max(robustDiff1, diff2) : robustDiff1     // MINIMAX, không phải tổng

// Priority 2 — chi phí kỹ thuật
bankPenalty = bankUsed ? 15 : 0
techPenalty = stroke != center ? 6 : 0

// Priority 4 — khoảng cách, trọng số RẤT NHỎ, chỉ có tác dụng phân định khi mọi thứ trên đã ngang nhau
dist = khoảng cách từ ghost tới E

score = posScore + bankPenalty + techPenalty + dist * 0.01

giữ lại tổ hợp có score thấp nhất
```

**Vì sao thứ tự trọng số này đúng với mục 3:** `posScore`/`bankPenalty`/`techPenalty` có đơn vị độ (0–95+), chiếm phần lớn thang điểm; `dist*0.01` với khoảng cách thực tế (0–400px) chỉ đóng góp 0–4 điểm — không đủ để lật kết quả trừ khi 2 phương án đã gần như ngang điểm ở các tiêu chí trước. Đây chính là cách hiện thực hóa "khoảng cách là tiêu chí cuối cùng."

Nếu KHÔNG tổ hợp nào hợp lệ (hiếm, toàn bộ bị chắn) → dùng phương án dự phòng: `center`, lực 40%, chấp nhận có thể còn rủi ro nhỏ (edge case, không cần xử lý sâu hơn).

### 5.5 Vòng lặp chính

```
cb = vị trí bi cái ban đầu
lặp qua từng bi (theo 5.1):
  tìm best (bi, lỗ) theo Priority 1
  nếu không tìm được -> đẩy bước safety, DỪNG (không đoán tiếp)
  cand = chấm điểm theo 5.4, dùng nextBall/nextNextBall:
    - 9/10-bi: nextBall/nextNextBall = bi kế tiếp/kế-kế-tiếp theo đúng thứ tự số
    - 8-bi: nextBall/nextNextBall = ước lượng bằng góc dễ nhất trong các bi còn lại (không phải tối ưu toàn cục)
  đẩy PlanStep với cbFrom = cb (giá trị TRƯỚC khi cập nhật)
  cb = cand.end        // bắt buộc: bước sau dùng ĐÚNG điểm này, không tính lại
```

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
- Đường bi cái sau va chạm: nét đứt màu ngọc (teal), theo ĐÚNG `stroke` đã chọn cho bước đó (không được vẽ một đường chung chung rồi ép về đích).
- **Nếu `bankUsed = true`**: vẽ rõ 2 đoạn tách biệt — đoạn thẳng từ điểm va chạm tới điểm chạm băng (đánh dấu chấm vàng nhỏ tại điểm chạm), rồi mới đến đoạn cong (theo hiệu ứng đầu cơ) từ điểm chạm băng tới điểm dừng cuối. Không gộp thành 1 đường cong duy nhất chạy xuyên qua biên bàn.
- Khi `bankUsed = true`, hiển thị cảnh báo trong panel thông tin: *"Cú này cần bi cái dội qua băng mới tới vị trí tốt — cần canh lực chính xác hơn bình thường."*

### 6.6 Disclaimer bắt buộc
Luôn hiển thị: *"Lực và đầu cơ là gợi ý định hướng dựa trên hình học, không phải kết quả đo vật lý chính xác — dùng để tham khảo, người chơi vẫn cần tự canh lực thực tế."* Không được bỏ dòng này — tính năng minh họa nguyên lý, không phải cam kết độ chính xác vật lý.

## 7. Test case bắt buộc (đã verify ở bản prototype, giữ nguyên khi build lại)

```
1. Continuity: với mọi bố cục hợp lệ, plan[i].landingPos === plan[i+1].cbFrom (sai số 0 tuyệt đối, không phải xấp xỉ).

2. Thứ tự 9/10-bi: với 1 bố cục 4 bi cố định, kế hoạch PHẢI đánh đúng thứ tự 1→2→3→4,
   bất kể bi nào trong đó có góc cắt dễ hơn các bi khác.

3. Thứ tự 8-bi: cùng bố cục trên, kế hoạch 8-bi được PHÉP đánh bi dễ nhất trước
   (ví dụ bi 3 trước bi 1), khác thứ tự số.

4. Dội băng: với 1 bố cục mà bi cái ở góc bàn và cần đi xa để tới vị trí tốt cho bi kế tiếp,
   ít nhất 1 bước trong kế hoạch phải có bankUsed = true, và landingCurve.hit nằm trên biên bàn
   (đúng bằng bounds.xmin/xmax/ymin/ymax ở 1 trong 2 tọa độ).

5. Ưu tiên robustness hơn khoảng cách: dựng 1 bố cục có 2 tổ hợp (stroke, power) khả thi mà
   tổ hợp A cho vị trí gần bi kế tiếp hơn tổ hợp B nhưng A không chịu được sai số lực ±15%
   (robustDiff1 của A cao hơn B nhiều) — thuật toán phải chọn B, không chọn A dù A gần hơn.

6. Safety: bố cục mà bi hiện tại (theo đúng thứ tự bắt buộc, chế độ 9/10-bi) bị bi khác chắn hoàn
   toàn ở mọi lỗ -> bước đó phải là safety:true và kế hoạch dừng lại đúng tại đó (không có bước sau).
```

## 8. Ngoài phạm vi (không làm ở bản này)
- Không tính toán physics thật (ma sát lăn chi tiết, mất năng lượng khi va bi/va băng, hiệu ứng xoáy 3 chiều thật) — đây vẫn là công cụ minh họa hình học.
- Không tối ưu toàn cục (global optimization) cho toàn bộ trình tự bi trong chế độ 8-bi — chỉ dùng lookahead 2 bước (N+1, N+2), không giải toàn bộ bài toán tối ưu thứ tự.
- Không xử lý trường hợp nhiều lần dội băng liên tiếp trong 1 cú đánh — chỉ mô phỏng tối đa 1 lần dội.
