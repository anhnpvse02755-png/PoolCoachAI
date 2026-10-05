# PoolCoachAI — Thiết kế lõi vật lý bàn và nâng Mô phỏng góc cắt

**Ngày:** 02/10/2026
**Trạng thái:** đã duyệt hướng từng phần (4 phần), chờ duyệt bản viết
**Tiền đề:** Mô phỏng góc cắt đã vào `main` ở máy (`af0fdd2`, 443 test xanh), chưa push `main`. Chủ sản phẩm vừa sửa `PRD_RunOutPlanner.md`: đường bi cái thành đường gấp khúc thẳng, dội tối đa 2 băng có hao lực. Sau khi xem lại, chủ sản phẩm chốt: **không bỏ đường cong, không bỏ áp phê, phải mô phỏng đúng vật lý**.

---

## 1. Mục tiêu

Thay lõi đường đi bi cái bằng **mô phỏng vật lý tất định**. Màn Mô phỏng góc cắt và Run-out Planner cùng dùng lõi này. Gộp luôn dự án áp phê đã hẹn sau merge (bi cái bị lệch do áp phê, swerve, ném).

> Đặt bi cái và bi mục tiêu → chọn kiểu đánh, áp phê, lực, độ dốc cơ → thấy bi cái đi tới bi mục tiêu thế nào, ngắm bù ném bao nhiêu, bi mục tiêu vào lỗ ra sao, bi cái cong, chạm băng và dừng ở đâu — giống ngoài bàn thật.

Có ba phần, cùng một kế hoạch:

1. Lõi vật lý `lib/domain/table_physics/` (mục 4–5).
2. Màn Mô phỏng góc cắt dùng lõi mới (mục 6).
3. Sửa `PRD_RunOutPlanner.md` cho khớp (mục 7).

Run-out Planner **vẫn là spec riêng**, làm ngay sau spec này, dựng trên lõi này.

### Không thuộc phạm vi

Run-out Planner · bi thứ ba trở lên trong mô phỏng (Planner kiểm bi chắn đường bằng `path_clear` trên trace, mục 4.7) · cú massé (cơ dốc trên 15°) · nảy bi trên mặt bàn (bi rời khăn) · bi va vào mép miệng lỗ (jaw) · khăn mòn, nhiệt độ, độ ẩm · lưu bố cục · xoay bàn dọc trên điện thoại.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Mô phỏng vật lý đầy đủ** (chủ sản phẩm chọn C): trượt rồi lăn, bi cái bị lệch do áp phê, swerve, ném, nảy băng phụ thuộc xoáy, nhiều băng có hao lực | "Cần mô phỏng đúng" — đường cong phải là cong thật, không phải vẽ tay |
| 2 | **Tích phân từng bước 1 ms**, tất định | Đúng nhờ mô hình chứ không nhờ công thức vẽ; thêm hiệu ứng chỉ là thêm lực một chỗ. Tất định nên Planner giữ được `landingPos == cbFrom` |
| 3 | **Không dùng gói physics** (forge2d…) | Engine 2D không có xoáy 3 chiều, ma sát khăn hay ném; kết quả không tất định qua các nền |
| 4 | Hằng số khởi điểm từ **tài liệu đã công bố** (Alciatore, Han 2005, pooltool), chỉnh bằng mắt trên Chrome | Bắt đầu gần đúng, chủ sản phẩm là người chốt |
| 5 | **Bù ném mặc định**, có công tắc *Xem nếu không bù ném* (chủ sản phẩm chọn C) | Người chơi học được phải ngắm lệch bao nhiêu, và thấy hậu quả nếu không bù |
| 6 | **Độ dốc cơ hai mức cố định**: *Thường (5°)*, *Dốc (15°)* (chủ sản phẩm chọn C) | Thấy swerve đổi theo độ dốc mà không mở ra massé |
| 7 | **Sửa PRD** §4, §5.2, §5.3, §6.5, §6.5b, §7, §8 (chủ sản phẩm chọn A) | Một nguồn duy nhất, không hai tài liệu nói ngược nhau |
| 8 | **Chết cái là bi cái rơi lỗ thật** trong mô phỏng | Bỏ `POCKET_DANGER` — "đi gần miệng lỗ" không phải chết cái |
| 9 | **Không giới hạn số băng** | Bi tự dừng vì hao lực; Planner phạt theo số lần chạm băng |
| 10 | **Đánh đứng bi = bi cái trượt, không xoáy dọc, lúc chạm bi mục tiêu** | Ngoài bàn, đánh tâm ở khoảng cách xa thì bi kịp lăn và thành cu lê. Lõi dò điểm đặt cơ dưới tâm để bi cái tới nơi đúng lúc hết xoáy |
| 11 | Lực **30 · 45 · 60 · 75 · 90 %** | Trùng `POWER_CANDIDATES` của PRD mới |
| 12 | Hình học thuần (bi ảo, góc cắt, chọn lỗ, bi chắn đường) **giữ nguyên** | Planner chọn lỗ theo góc cắt hình học (PRD Priority 1) — vẫn đúng |
| 13 | Gợi ý chống chết cái tính **khi thả tay**, không tính mỗi khung hình | Mỗi lần mô phỏng đắt hơn lõi cũ hàng trăm lần |

### Thuật ngữ mới (chủ sản phẩm đã chốt)

| Trên màn | Nghĩa |
|---|---|
| **Ném** | Bi mục tiêu bị đẩy lệch khỏi đường hình học do ma sát lúc va chạm (CIT do góc cắt, SIT do áp phê) |
| **Bù ném** · *Xem nếu không bù ném* | Ngắm lệch để bi mục tiêu vẫn vào lỗ · công tắc xem đường không bù |
| **Bi cái bị lệch do áp phê** | Bi cái lệch khỏi hướng cơ ngay khi đánh (squirt) |
| **Độ dốc cơ** · *Thường* · *Dốc* | Góc cơ so với mặt bàn |

Thuật ngữ cũ giữ nguyên: Đánh đứng bi · Đánh trô bi · Đánh cu lê · Bi ảo · Dội băng · Áp phê trái/phải · Lệch N đầu cơ · Chết cái · Trượt cơ · Kiểu đánh. Mọi chữ hiển thị nằm trong `lib/core/strings/vi.dart`.

---

## 3. Hệ toạ độ, đơn vị, hằng số

- Không đổi so với lõi hình học: mặt chơi 254 × 127 cm, gốc góc trên trái, `x` theo chiều dài, `y` hướng xuống, `R = 5.715/2`. Thêm trục `z` hướng **lên** (mặt bàn là `z = 0`).
- Đơn vị: cm, giây, gam. `g = 981 cm/s²`.
- Biên tâm bi `bounds = [R, 254−R] × [R, 127−R]` như cũ. Mọi điểm chạm băng nằm **đúng** trên biên này.

Hằng số có tên, giá trị khởi điểm từ tài liệu, chỉnh bằng mắt. Test chỉ dùng tên.

| Hằng số | Khởi điểm | Vai trò · nguồn |
|---|---|---|
| `ballMass` | 170 g | Bi tiêu chuẩn |
| `muSlide` | 0.2 | Ma sát trượt bi–khăn (pooltool `u_s`) |
| `muRoll` | 0.01 | Cản lăn (pooltool `u_r`) |
| `muSpin` | 0.044 | Ma sát làm tắt xoáy quanh trục đứng (pooltool `u_sp`) |
| `ballRestitution` | 0.95 | Hệ số phục hồi bi–bi |
| `throwFrictionA/B/C` | 9.951e-3 · 0.108 · 1.088 s/m | Ma sát bi–bi theo vận tốc trượt: `μ = A + B·e^(−C·v)` (Alciatore TP A.14) |
| `cushionRestitution` | 0.85 | Hệ số phục hồi bi–băng (pooltool `e_c`) |
| `cushionFriction` | 0.2 | Ma sát bi–băng (pooltool `f_c`) |
| `cushionHeight` | 0.635 · 2R | Độ cao mũi băng (WPA 62.5–64.5 % đường kính) |
| `maxCueSpeed` | 800 cm/s | Vận tốc bi cái ở lực 100 % |
| `strokeOffset` | 0.5 R | Độ lệch dọc của đầu cơ khi trô/cu lê |
| `endMassRatio` | 0.03 | Khối lượng đầu cơ hiệu dụng / khối lượng bi — quyết định độ lệch do áp phê |
| `cueElevationNormal` · `cueElevationSteep` | 5° · 15° | Hai mức độ dốc cơ |
| `timeStep` | 0.001 s | Bước tích phân |
| `stopSpeed` · `stopSpin` | 0.5 cm/s · 0.5 rad/s | Dưới cả hai thì bi đứng hẳn |
| `maxSimTime` | 20 s | Trần an toàn; vượt là lỗi (test bắt) |
| `cornerCapture` · `middleCapture` | 6.0 · 5.0 cm | Giữ nguyên: tâm bi lọt vào bán kính này quanh lỗ là rơi lỗ |
| `maxCutAngle`, `miscueTips`, `tipWidth`, `overhitBand` | giữ nguyên | Như lõi cũ |
| `aimTolerance` | 0.05° | Dừng dò bù ném khi sai số hướng bi mục tiêu dưới mức này |
| `overhitScanStep` | 5 % | Bước dò lực khi tìm biên chết cái, rồi dò mịn 1 % trong khoảng tìm được |

Các hằng số `maxTravel`, `rollCarry`, `spinDegPerRadius` của lõi cũ bị **xoá** cùng `cue_ball_path.dart`.

---

## 4. Lõi `lib/domain/table_physics/`

Dart thuần, không import Flutter (thêm vào `test/architecture_test.dart`). Dùng `Vec2`, `TableSpec`, `Pocket` từ `table_geometry`. Một file một việc.

| File | Nội dung |
|---|---|
| `vec3.dart` | `Vec3` bất biến cho vận tốc góc và tích có hướng |
| `ball_state.dart` | `BallState { pos: Vec2, vel: Vec2, spin: Vec3 }`, `isStopped` |
| `constants.dart` | Mọi hằng số ở mục 3 |
| `cue_strike.dart` | `strikeCue(...)` → `BallState` ban đầu của bi cái (mục 4.1) |
| `cloth.dart` | Một bước chuyển động trên khăn (mục 4.2) |
| `cushion.dart` | Va chạm băng (mục 4.3) |
| `ball_collision.dart` | Va chạm bi cái–bi mục tiêu, có ném (mục 4.4) |
| `simulate_shot.dart` | `simulateShot(ShotInput)` → `ShotTrace` (mục 4.5) |
| `aim.dart` | `aimShot(...)` → `AimedShot`: dò bù ném và dò điểm đặt cơ cho Đánh đứng bi (mục 4.6) |

### 4.1 Cơ chạm bi cái

Đầu vào: hướng cơ (góc trên mặt bàn), lực %, độ lệch dọc `b` (cm, dương là trên tâm), áp phê `SideSpin` (độ lệch ngang `a = tips · tipWidth`, dương là phải), độ dốc cơ `θ`.

- Vận tốc: `v₀ = maxCueSpeed · lực/100`, theo hướng cơ chiếu xuống mặt bàn.
- Xoáy: theo va chạm cơ–bi cứng, `ω = (5 v₀ / 2R²) · (r × d̂)`. Trong đó `r = (a, b)` là điểm chạm trên mặt bi vuông góc với hướng cơ, còn `d̂` là hướng cơ 3 chiều nghiêng `θ`. Cơ dốc làm trục xoáy nghiêng, và đó là nguồn của swerve.
- **Bi cái bị lệch do áp phê:** hướng vận tốc quay ngược phía áp phê một góc
  `α = atan( (5/2)·(a/R)·√(1−(a/R)²) / (1 + 1/endMassRatio + (5/2)·(1−(a/R)²)) )`
  (Alciatore TP A.31).
- Trô/cu lê: `b = ∓strokeOffset`. Đánh đứng bi: `b` do `aimShot` dò (mục 4.6).

### 4.2 Chuyển động trên khăn

Vận tốc trượt tại điểm tiếp xúc: `u = vel + ω × (−R ẑ)`.

- **Trượt** (`|u| > ε`): ma sát `−muSlide · g · û` làm đổi cả vận tốc lẫn xoáy ngang (`Δω` theo mô-men `R ẑ × F`). Đây là chỗ đường đi **cong theo parabol**, kể cả swerve.
- **Lăn** (`|u| ≤ ε`): ép lăn đều (`ω` ngang khớp `vel/R`), giảm tốc `muRoll · g` theo đường thẳng.
- **Xoáy quanh trục đứng** tắt dần với gia tốc góc `5·muSpin·g / 2R`.
- Tích phân Euler bán ẩn, bước `timeStep`. Chuyển trượt → lăn được bắt **đúng thời điểm** trong bước (giải tuyến tính), không để bi "trượt quá".

### 4.3 Băng

Khi tâm bi chạm `bounds`, tính đúng thời điểm chạm trong bước, rồi áp xung lực băng theo mô hình Han 2005 rút gọn:
- điểm tiếp xúc ở độ cao `cushionHeight`;
- thành phần pháp tuyến phục hồi `cushionRestitution`;
- ma sát `cushionFriction` đổi vận tốc tiếp tuyến và xoáy.

Hệ quả cần thấy: không xoáy thì góc bật gần bằng góc tới và mất lực; áp phê thuận mở góc, nghịch đóng góc; trô/cu lê đổi góc bật.

Điểm chạm ghi vào trace, nằm đúng trên biên. Gần miệng lỗ: nếu tâm bi đã lọt vùng `capture` thì rơi lỗ trước khi xét băng.

### 4.4 Va chạm bi–bi và ném

Hai bi cùng khối lượng. Thời điểm chạm (`|p₁ − p₂| = 2R`) giải đúng trong bước bằng phương trình bậc hai trên chuyển động tương đối.

- Xung pháp tuyến với phục hồi `ballRestitution`.
- **Ném:** ma sát tại điểm chạm, hệ số `μ(v_rel)` (mục 3), chặn trên bởi điều kiện hết trượt (Alciatore TP A.14). Ma sát này đẩy bi mục tiêu lệch khỏi đường pháp tuyến (CIT theo góc cắt, SIT theo áp phê) và truyền một ít xoáy.
- Xoáy của bi cái giữ nguyên qua va chạm (khăn tiếp tục xử lý), nên trô/cu lê tự kéo bi cái về sau hoặc về trước.

### 4.5 `simulateShot`

```dart
class ShotInput {
  final Vec2 cue, object;
  final double aimAngle;      // hướng cơ, rad
  final double power;         // %
  final double verticalOffset; // b, cm
  final SideSpin spin;
  final double elevation;     // rad
  final TableSpec table;
}

class ShotTrace {
  final List<Vec2> cueBefore;   // bi cái từ lúc đánh tới lúc chạm bi mục tiêu
  final List<Vec2> cueAfter;    // bi cái sau va chạm tới khi dừng/rơi lỗ
  final List<Vec2> objectPath;  // bi mục tiêu sau va chạm
  final Vec2? contactCue;       // tâm bi cái lúc chạm (bi ảo thật); null nếu trượt bi
  final List<RailHit> rails;    // mọi lần chạm băng, theo thứ tự thời gian, ghi bi nào
  final Pocket? cuePocket;      // chết cái
  final Pocket? objectPocket;   // bi mục tiêu vào lỗ nào (null = không vào)
  final Vec2 cueEnd;            // điểm dừng bi cái — Planner dùng làm cbFrom
  bool get bankUsed;            // bi cái chạm băng sau va chạm
}
```

- Mô phỏng hai bi tới khi cả hai đứng hẳn hoặc rơi lỗ. Vượt `maxSimTime` thì ném lỗi, không trả kết quả.
- Mỗi danh sách điểm lấy mẫu **mỗi bước** rồi rút gọn: bỏ điểm nằm trên đoạn thẳng nối hai điểm kề với sai lệch dưới 0.05 cm. Đường thẳng còn 2 điểm, đường cong giữ đủ điểm để vẽ mượt.
- `cueEnd` **là** điểm cuối của `cueAfter` (cùng đối tượng). Nếu bi cái rơi lỗ, `cueAfter` kết thúc ở tâm lỗ, nên `cueEnd` là tâm lỗ. Nếu bi cái trượt bi mục tiêu (`contactCue == null`), `cueAfter` rỗng và `cueEnd` là điểm cuối của `cueBefore`.
- Tất định: không dùng số ngẫu nhiên, không phụ thuộc thời gian thật; cùng đầu vào thì cùng trace.

### 4.6 `aimShot` — bù ném và Đánh đứng bi

```dart
AimedShot aimShot({cue, object, pocket, stroke, spin, power, elevation, table, compensate = true});

class AimedShot {
  final ShotTrace trace;          // cú đánh theo hướng đã bù (hoặc hình học nếu !compensate)
  final ShotTrace? uncompensated; // khi compensate: cú ngắm theo bi ảo hình học, để vẽ đường đỏ
  final double aimOffsetDeg;      // hướng cơ đã bù − hướng tới bi ảo hình học; dương = dày hơn
  final double verticalOffset;    // b đã dùng (Đánh đứng bi: b dò được)
  final bool converged;
}
```

- **Bù ném:** dò `aimAngle` bằng phương pháp cát tuyến (bắt đầu từ hướng tới bi ảo hình học) sao cho hướng vận tốc **ngay sau va chạm** của bi mục tiêu chỉ vào tâm lỗ. Mỗi vòng chỉ mô phỏng tới lúc va chạm nên rẻ. Dừng khi sai số dưới `aimTolerance` hoặc sau 12 vòng (`converged = false`, màn hình vẫn vẽ kết quả tốt nhất).
- Cách này bù luôn bi cái bị lệch do áp phê và swerve, vì nó đo kết quả thật chứ không cộng công thức.
- **"Dày/mỏng":** dày hơn là `aimAngle` quay về phía tâm bi mục tiêu.
- **Đánh đứng bi:** dò `b ∈ [−0.6R, 0]` (chia đôi) sao cho xoáy dọc của bi cái **lúc chạm** bằng 0. Gần quá thì `b ≈ 0`; xa thì phải đánh dưới tâm.

### 4.7 Thay thế trong `table_geometry`

- **Xoá** `cue_ball_path.dart` (Bézier, `simulateCueBall`, `CueBallPath`) và test của nó.
- `scratch.dart`: `scratchMargin` và `scratchAdvice` giữ API và các kiểu `Advice`, nhưng tính bằng `aimShot`. Dò lực theo `overhitScanStep` rồi dò mịn 1 % trong khoảng vừa tìm (biên chết cái không đơn điệu theo lực nên không chia đôi).
- `stroke.dart`: `powerPresets = [30, 45, 60, 75, 90]`; thêm `enum CueElevation { normal, steep }`.
- Planner sau này kiểm bi chắn đường bằng `isPathClear` trên từng đoạn của `cueBefore`, `cueAfter`, `objectPath`.

---

## 5. Hiệu năng

- Một `aimShot` (≤ 12 lần mô phỏng tới va chạm, cộng 2 lần mô phỏng đầy đủ) phải xong **dưới 8 ms** trên Dart VM. Có test đo, chạy 50 lần lấy trung vị, để còn chỗ cho dart2js chậm hơn.
- Lúc kéo bi: chỉ chạy `aimShot` của cú đang xem.
- Khi thả tay (`onPanEnd`), hoặc khi đổi nút chỉnh: chạy `scratchAdvice`. Trong lúc chờ, dòng gợi ý hiện *"Đang tính…"*.
- Kiểm trên Chrome giả lập điện thoại bằng DevTools: kéo bi không rớt khung (16 ms).

---

## 6. Màn Mô phỏng góc cắt

Giữ bố cục, cách kéo bi, chọn lỗ, vùng chạm tối thiểu 24 px và semantics hiện có.

### 6.1 Nút chỉnh

- **Kiểu đánh:** Đánh đứng bi · Đánh trô bi · Đánh cu lê.
- **Áp phê:** trái/phải, 0.5 · 1 · 2 đầu cơ.
- **Lực:** 30 · 45 · 60 · 75 · 90 %.
- **Độ dốc cơ:** Thường · Dốc.
- Công tắc **Xem nếu không bù ném**, chỉ bật được khi có áp phê hoặc góc cắt khác 0 (khi đó mới có ném).

### 6.2 Vẽ, từ dưới lên

1. Đường ngắm hình học (bi cái → bi ảo hình học): vạch mờ.
2. Đường bi cái tới bi mục tiêu (`cueBefore`): nét đứt trắng — thấy bi cái bị lệch do áp phê và swerve.
3. **Bi ảo** đã bù (`contactCue`): vòng nét đứt. Nếu cách bi ảo hình học trên 0.1 cm thì vẽ thêm chấm mờ ở vị trí hình học.
4. Đường bi mục tiêu (`objectPath`): nét liền.
5. Đường bi cái sau va chạm (`cueAfter`): nét đứt màu ngọc, vẽ đúng chuỗi điểm. Chỗ cong là cong thật.
6. Mỗi lần bi cái chạm băng: chấm vàng.
7. Điểm dừng bi cái: vòng trắng cỡ bi. Chết cái thì lỗ đó tô đỏ như hiện tại.
8. Bật công tắc: `uncompensated.objectPath` vẽ đỏ mờ.

### 6.3 Bảng thông tin

- Góc cắt và mức độ khó: không đổi (vẫn tính theo hình học).
- ~~*"Ngắm dày hơn X°"* / *"Ngắm mỏng hơn X°"* khi `|aimOffsetDeg| ≥ 0.5`, làm tròn 0.5°.~~ (bỏ 2026-10-05: chủ sản phẩm — không đưa lời khuyên ngắm lệch theo độ; lời khuyên áp phê sẽ theo SAWS ở spec sau)
- *"Đánh đứng bi: đặt cơ dưới tâm khoảng N đầu cơ"* khi kiểu đánh là Đánh đứng bi và `|b| ≥ 0.25 tipWidth`, làm tròn 0.25 đầu cơ.
- *"Bi cái bị lệch do áp phê khoảng X°"* khi có áp phê, `X = α`, làm tròn 0.5°.
  (thêm 2026-10-05, chủ sản phẩm: kèm độ lệch điểm ngắm bằng đầu cơ và phần con bi, tính từ độ xoay hướng cơ đã bù nhân quãng tới bi ảo hình học)
- *"Bi cái chạm băng N lần."* — thông tin, không còn là cảnh báo.
- *"Chết cái"* khi `cuePocket != null`.
- *"Bi mục tiêu không vào lỗ"* khi `objectPocket` khác lỗ đã chọn (chỉ xảy ra khi dò không hội tụ).
- Trượt cơ, gợi ý áp phê chống chết cái, disclaimer: như hiện tại.

Mọi câu có số là template trong `vi.dart`, điền từ kết quả lõi.

### 6.4 Semantics

Nhãn tóm tắt bàn thêm số lần chạm băng, độ bù ném và độ dốc cơ, để `simulator.mjs` đọc được từng cảnh.

---

## 7. Sửa `PRD_RunOutPlanner.md`

Commit bản PRD chủ sản phẩm vừa sửa **trước**, nguyên văn. Sau đó commit các chỗ sửa dưới đây, mỗi chỗ ghi *"(sửa 2026-10-02: mô phỏng vật lý)"*.

| Mục | Sửa thành |
|---|---|
| Đầu tài liệu, §1 | Vẫn tất định, không AI. Đường đi bi lấy từ mô phỏng vật lý tất định, lõi chung với màn mô phỏng (spec này) |
| §3 Priority 2 | Giữ nguyên ý và thứ tự. Bỏ câu nói đường cong "không sát thực tế" |
| §4 | Bỏ `STROKE_SPIN`, `RAIL_LOSS`, `MAX_RAILS`, `POCKET_DANGER`, `LandingCurve`. Thay bằng `ShotTrace` (mục 4.5). `PlanStep.landingCurve` → `trace`, thêm `elevation` (Planner luôn dùng Thường). Hằng số trỏ sang mục 3 của spec này. `POWER_CANDIDATES` giữ 30/45/60/75/90 |
| §5.2 | Thay mã giả `simulateWithRail` bằng mô tả `aimShot`/`simulateShot` |
| §5.3 | `curve.scratch` → `trace.cuePocket != null`. `railCount` = số lần bi cái chạm băng sau va chạm. Thêm: bi mục tiêu không vào lỗ đã chọn thì loại phương án. Các tầng điểm khác giữ nguyên |
| §6.5 | Vẽ đúng chuỗi điểm của trace: cong chỗ cong, thẳng chỗ thẳng. Không vẽ đường cong tự chế |
| §6.5b | Ô lưới vùng điều ~12 px → 5 cm |
| §7 test 4 | Mỗi điểm chạm băng nằm đúng trên biên; đường đi đi qua các điểm đó theo thứ tự |
| §7 test 8 | Bi cái rơi lỗ trong mô phỏng → phương án bị loại |
| §8 | Bỏ "không tính physics thật, squirt/swerve". Giữ "Planner chưa đưa áp phê vào phương án thử" và "không tối ưu toàn cục cho 8-bi". Thêm: bi thứ ba trở lên không tham gia va chạm trong mô phỏng, chỉ kiểm chắn đường |
| Dòng "điểm bi ma" | "Bi ảo" |

Không đụng: luật 9/10-bi và 8-bi, bất biến `landingPos == cbFrom`, minimax, gợi ý đánh dư dày/mỏng (§5.5), UI từng bước, disclaimer.

---

## 8. Kiểm thử

### 8.1 Lõi vật lý

| Nhóm | Phải đúng |
|---|---|
| Lăn | Đánh tâm, không xoáy, trên khăn: chuyển sang lăn đều ở `5/7 · v₀` |
| Đánh đứng bi | Bắn thẳng: bi cái dừng trong 1 R quanh điểm chạm. Cắt góc: bi cái rời đi theo tiếp tuyến (lệch dưới 2°) |
| Cu lê | Cắt nửa bi, bi cái đang lăn đều: hướng cuối lệch 30° ± 3° so với đường cơ (quy tắc 30°). Có đoạn cong rồi thẳng |
| Trô | Bắn thẳng: bi cái lùi lại trên đường cơ (lệch ngang dưới 0.5 cm) |
| Ném | Không áp phê, cắt nửa bi, lực vừa: góc ném trong khoảng Alciatore (2–4°). Ném giảm khi lực tăng. Áp phê ngoài làm giảm ném, đúng chiều |
| Bi cái bị lệch do áp phê | Lệch ngược phía áp phê, tăng theo số đầu cơ, bằng công thức mục 4.1 |
| Swerve | Cùng áp phê: độ lệch ngang lúc tới bi mục tiêu ở cơ Dốc lớn hơn cơ Thường |
| Băng | Không xoáy: góc bật trong 5° quanh góc tới, vận tốc pháp tuyến giảm theo `cushionRestitution`. Áp phê thuận mở góc, nghịch đóng góc. Mọi `RailHit` nằm đúng trên biên |
| Nhiều băng | Có ca bi cái chạm 3 băng trở lên rồi dừng trong bàn |
| Năng lượng | Động năng tịnh tiến + quay không tăng giữa hai bước (trừ lúc cơ chạm) |
| Dừng | Lưới vị trí × kiểu đánh × áp phê × lực: mọi cú dừng trước `maxSimTime`; `cueEnd` trong `bounds` hoặc là tâm lỗ |
| Tất định | Cùng `ShotInput` chạy hai lần cho trace bằng nhau tuyệt đối |
| Bù ném | Có bù: `objectPocket` là lỗ đã chọn trên lưới cú đánh khả thi. Tắt bù, có áp phê: bi mục tiêu lệch đúng chiều |
| Đánh đứng bi | `b` dò được làm xoáy dọc lúc chạm dưới `stopSpin`; xa hơn thì `|b|` lớn hơn |
| `cueEnd` | Có va chạm: `identical(trace.cueEnd, trace.cueAfter.last)`. Trượt bi: `identical(trace.cueEnd, trace.cueBefore.last)` |
| Hằng số | Test chỉ dùng tên hằng số |
| Hiệu năng | `aimShot` trung vị dưới 8 ms trên VM |

### 8.2 Test bỏ hoặc viết lại

- Bỏ: `cue_ball_path_test.dart`, phần Bézier/hai đoạn/dừng ở băng thứ hai/trô thẳng sau băng trong `bank_spin_test.dart`.
- Viết lại trên lõi mới: test chết cái, biên lực, lời khuyên (`scratch`, `advice`), giữ đủ các trường hợp và lưới như hiện tại.
- Giữ nguyên: góc cắt, độ khó, chọn lỗ, bi chắn đường, `vec2`, kiến trúc.

### 8.3 Màn hình

- Có nút Độ dốc cơ và 5 nút lực. Công tắc bù ném hiện/ẩn đường đỏ, và bị khoá khi không có ném.
- ~~Dòng *Ngắm dày/mỏng* đúng chiều với `aimOffsetDeg`.~~ (bỏ 2026-10-05: chủ sản phẩm — không đưa lời khuyên ngắm lệch theo độ; lời khuyên áp phê sẽ theo SAWS ở spec sau) Dòng Đánh đứng bi chỉ hiện khi đủ ngưỡng.
- Gợi ý chống chết cái hiện *Đang tính…* khi kéo và cập nhật khi thả tay.
- Khổ 390 × 844: chạm và kéo lệch 15 px vẫn đúng (giữ test hiện có).
- Không có chữ tiếng Việt trong `lib/features` (test kiến trúc hiện có).

### 8.4 Chrome và chủ sản phẩm

Mở rộng `tool/e2e/simulator.mjs`, thêm các cảnh:
1. Cu lê bắn thẳng · trô bắn thẳng.
2. Cu lê cắt nửa bi (thấy đoạn cong rồi thẳng).
3. Bi cái chạm 2–3 băng.
4. Áp phê phải 1 đầu cơ, bật và tắt *Xem nếu không bù ném*.
5. Cùng áp phê, cơ Thường và cơ Dốc (thấy swerve).
6. Đánh đứng bi ở xa (thấy dòng đặt cơ dưới tâm).

Đo thời gian khung hình khi kéo trên Chrome giả lập điện thoại. **Dừng lại để chủ sản phẩm xem ảnh và chỉnh hằng số.** Chủ sản phẩm là người chốt các giá trị ở mục 3.

### 8.5 Sau merge

Deploy theo `deploy/publish.sh`, rồi chạy `simulator.mjs` trên bản thật.

---

## 9. Nối sang Run-out Planner

Planner dùng `evaluateShot`, `bestPocket`, `isPathClear` (hình học), `aimShot` (đường đi), `scratchAdvice` (nếu cần). Nó lấy `AimedShot.trace.cueEnd` làm `cbFrom` của bước sau — cùng một đối tượng, không tính lại. Planner luôn dùng độ dốc cơ Thường và không thử áp phê (PRD §8).
