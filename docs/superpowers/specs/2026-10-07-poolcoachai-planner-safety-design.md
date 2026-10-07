# PoolCoachAI — Thiết kế cú phòng thủ cho Kế hoạch dọn bàn, và nút Chờ khi mô phỏng quá giờ

**Ngày:** 07/10/2026
**Trạng thái:** đã duyệt bản viết (07/10/2026), gồm cả 5 chỗ người viết tự điền: đui ở 8 bi khi mọi bi nhóm mình bị chắn; 1–3 băng chấm chung; chỉ bỏ đường chạm băng vào miệng lỗ; sát băng và khoảng cách tính với bi đối thủ dễ nhất; thứ tự giữ phương án thử trước
**Tiền đề:** spec gốc `2026-10-07-poolcoachai-run-out-planner-design.md` đã xây xong trên nhánh `feat/run-out-planner` (bước 0–13, bước 14 đang ở vòng chủ sản phẩm xem bằng mắt). Spec gốc để "lập kế hoạch cho cú phòng thủ" **ngoài phạm vi**. Khi xem ảnh, chủ sản phẩm quyết định đưa phần này vào **ngay trên nhánh này, trước khi merge**.

Spec này **bổ sung** spec gốc. Chỗ nào không nói lại thì giữ nguyên spec gốc.

---

## 1. Mục tiêu

> Tới bước mà kế hoạch không còn cú ăn bi chắc chắn, app không dừng trơn nữa mà **chỉ cách thủ**:
> - **Bị đui** (bi cái không nhìn thẳng thấy bi phải đánh): vẽ đường **A băng**, tính lực để chạm bi hợp lệ rồi thủ lại hoặc để lại thế bi khó cho đối thủ.
> - **Không đui nhưng hết đường ăn**: báo cho người chơi biết không còn đường ăn bi, nên thủ, và mô phỏng cú thủ.

Kèm một thay đổi nhỏ ở màn Mô phỏng góc cắt: khi lõi vật lý tính quá giờ, hỏi người chơi muốn **chờ** hay **chỉ vẽ đường ngắm** (mục 7).

Tiêu chí thành công: chủ sản phẩm bày một thế đui và một thế hết đường ăn, và thấy cú thủ giống cách người chơi giỏi sẽ chọn.

### Không thuộc phạm vi

Kế hoạch sau cú thủ (tới lượt đối thủ, kế hoạch dừng) · cú nhảy bi (massé, jump) · bi thứ ba trở lên va chạm (vẫn chỉ là bi chắn, như spec gốc) · luật "bi chạm băng" riêng của từng giải ngoài WPA · nhớ lựa chọn Chờ giữa các cú.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Cú thủ phải đúng luật WPA** (chọn A): bi cái chạm bi hợp lệ trước; sau va chạm có ít nhất một bi chạm băng; không chết cái | App không bao giờ dạy người chơi một cú phạm lỗi |
| 2 | **Chấm "thế khó cho đối thủ"** (chọn C): đối thủ bị đui > cú dễ nhất của đối thủ khó hơn > bi sát băng > bi cái xa bi đối thủ. Mọi tiêu chí lấy mức xấu nhất trong ±15% lực | Cú thủ phải chịu được sai số lực như cú ăn bi |
| 3 | **A băng tới 4 băng** (chọn C, rồi thêm 4 băng): thử 1–3 băng; **chỉ thử 4 băng khi 1–3 băng không có cú hợp lệ nào** | Phần lớn thế đui giải được bằng 1–2 băng; 4 băng là đường lui cuối |
| 4 | **Cú thủ trực tiếp luôn thử cả áp phê** (chọn C), 675 phương án | Thủ cần điều khiển cả hai bi, áp phê là công cụ chính |
| 5 | Điểm ngắm A băng nói bằng **chấm** (chọn A), đếm từ góc trái của băng theo hướng nhìn trên màn, góc là chấm 0, làm tròn nửa chấm; app vẽ điểm ngắm và đánh số chấm | Làm được ngoài bàn; không nói độ |
| 6 | **Cộng điểm, không xếp bậc cứng** (mục 4) | Cú đơn giản thắng khi gần ngang nhau, đúng tinh thần "tỉ lệ thành công trước" của PRD |
| 7 | **Phạt A băng: 1 băng 10, 2 băng 20, 3 băng 45, 4 băng 55** | Chủ sản phẩm cho số; 3 và 4 băng lấy giữa khoảng chủ sản phẩm đưa (40–50, 50–60) |
| 8 | **Sát băng: −5 điểm mỗi bi**, "sát" là cách băng không quá một bi (5,7 cm) | Chủ sản phẩm duyệt |
| 9 | Dòng kết quả cho đối thủ **hiện số độ** của góc cắt | Đây là thông tin về độ khó, không phải lời khuyên ngắm |
| 10 | Màn mô phỏng quá giờ: hỏi **Chờ / Chỉ vẽ đường ngắm**; Chờ tính lại với giới hạn **gấp 3** (60 giây mô phỏng); **không nhớ lựa chọn** (chọn A) | Người chơi tự quyết, nhưng thời gian chờ có giới hạn |
| 11 | Hướng xây: **bộ tìm cú thủ trong lõi Planner** (hướng 1), Dart thuần, chia lát, lưu tạm như phần ăn bi | Dùng lại lõi vật lý, cách chấm đối thủ, ±15%, màn từng bước |

### Thuật ngữ (chủ sản phẩm đã chốt)

| Trên màn | Nghĩa |
|---|---|
| **Bị đui** · **Đối thủ bị đui** | Bi cái không nhìn thẳng thấy bi phải đánh (snookered) |
| **A băng** | Bi cái chạm băng **trước** rồi mới tới bi hợp lệ (kick). Khác **Dội băng** (bi cái chạm băng sau khi chạm bi) |
| **Chấm** | Các mốc trên mép bàn: băng dài 0–8, băng ngắn 0–4 |
| **Băng dài trên / dưới** · **Băng ngắn trái / phải** | Tên băng theo hướng nhìn trên màn |
| **Thủ bi** · **Chơi an toàn (safety)** | Cú phòng thủ |
| **Ăn ½ bi, lệch bên trái** | Độ dày chạm bi, theo hướng nhìn từ bi cái |

---

## 3. Lõi tìm cú thủ (`lib/domain/planner/`, Dart thuần)

### 3.1 Khi nào chạy

Ở bước mà kế hoạch trước đây trả về `PlanStep.safety` (tầng 4 của thứ tự dự phòng, spec gốc mục 5.5). Bước đó giờ đi tìm cú thủ. Kế hoạch **vẫn dừng** sau bước này vì tới lượt đối thủ.

### 3.2 Phân loại

- **Bị đui:** từ bi cái, cả ba đường (tới tâm bi ảo chạm trọn bi, và hai đường chạm mỏng sát hai mép bi hợp lệ) đều bị bi khác chắn → tìm **A băng** (3.4).
- **Không đui:** thấy được ít nhất một phần bi → tìm **cú thủ trực tiếp** (3.3).
- **8 bi:** "bi hợp lệ" là mọi bi nhóm mình (hết nhóm thì bi 8). Đui khi **mọi** bi hợp lệ đều bị chắn theo cách trên; không đui thì cú thủ trực tiếp thử trên mọi bi hợp lệ thấy được.

### 3.3 Cú thủ trực tiếp (`safety_options.dart`)

- **Độ dày:** ăn trọn bi, ¾, ½, ¼, ⅛ (mỏng); trừ trọn bi, mỗi mức lệch hai bên → 9 mức.
- **× kiểu đánh:** đứng / cu lê / trô.
- **× áp phê:** không, trái ½, trái 1, phải ½, phải 1 đầu cơ.
- **× lực:** 30 · 45 · 60 · 75 · 90 %.
- Tổng **675 phương án** mỗi bi hợp lệ. Bỏ trước bằng hình học những độ dày mà đường bi cái tới điểm chạm bị chắn.
- Hướng đánh của mỗi độ dày lấy theo hình học bi ảo, rồi dò bằng mô phỏng thật cho đúng độ dày (bù ném và lệch do áp phê), giống cách `aimShot` dò.

### 3.4 A băng (`kick_search.dart`)

- **Chuỗi băng:** mọi chuỗi không lặp băng liền nhau: 1 băng 4, 2 băng 12, 3 băng 36, 4 băng 108.
- **Hướng ban đầu:** soi gương bi hợp lệ qua từng chuỗi. Bỏ chuỗi mà đường gấp khúc hình học bị chắn, hoặc điểm chạm băng rơi vào miệng lỗ.
- **Mỗi chuỗi còn lại:** đứng / cu lê × 5 mức lực × chạm trọn bi hoặc ½ bi hai bên.
- **Hướng đánh dò chính xác bằng mô phỏng thật** sao cho bi cái thật sự chạm bi hợp lệ ở độ dày định trước, sau đúng số băng của chuỗi. Dò không hội tụ thì bỏ phương án.
- **Thứ tự tầng:** 1–3 băng cùng chấm chung (điểm phạt theo số băng phân định). **Chỉ khi 1–3 băng không còn phương án hợp lệ nào** mới thử 4 băng.

### 3.5 Luật (`safety_rules.dart`)

Loại phương án nếu:
- bi cái chạm bi khác (đường `cueBefore` qua bi chắn) trước bi hợp lệ;
- với A băng: số lần bi cái chạm băng trước va chạm khác số băng của chuỗi;
- sau va chạm không bi nào chạm băng (`rails` sau va chạm của cả hai bi đều rỗng) và bi hợp lệ không vào lỗ;
- chết cái;
- **bi hợp lệ rơi lỗ** (đó là may, không phải cú thủ: phần ăn bi đã không tìm được đường chắc chắn);
- đường bi hợp lệ sau va chạm đi qua bi chắn;
- mô phỏng ném `SimulationTimeout`.

### 3.6 `SafetyJob` (`safety_job.dart`)

Chia lát và lưu tạm đúng cách `PlannerJob` đang làm: mỗi đơn vị việc chạy lại phép tính thuần trên bộ nhớ tạm và làm **đúng một lần mô phỏng mới**, nên chạy từng lát cho kết quả **đúng y** như chạy một mạch. `PlannerJob` gọi vào ở bước phòng thủ và báo bước ra khi xong. Huỷ được.

### 3.7 Bước phòng thủ mang theo

`PlanStep` với `kind = safety` thêm trường `safety` (null khi không tìm được cú hợp lệ):

| Trường | Nghĩa |
|---|---|
| `reason` | `snookered` (bị đui) · `noPot` (không đui, hết đường ăn) |
| `kind` | `direct` · `kick` |
| `rails` | số băng (A băng); 0 khi trực tiếp |
| `ballNum` | bi hợp lệ được chạm |
| `thickness`, `thicknessSide` | độ dày và bên lệch (trực tiếp) |
| `stroke`, `spin`, `power` | kiểu đánh, áp phê, lực |
| `aimed` | cú đã dò (đường đi hai bi, dùng lại dòng áp phê của màn mô phỏng) |
| `railAim` | băng đầu tiên + số chấm (A băng) |
| `opponent` | đối thủ bị đui? · cú dễ nhất: bi, lỗ, góc · hoặc không còn đường ăn |
| `jitterEnds` | điểm dừng bi cái khi lực −15% / +15% |
| `tolerance` | số mức trong 7 mức lực đều nhau ±15% vẫn "khó cho đối thủ" (mục 4.3) |
| `sawsBhePercent` | khi dùng áp phê |

Không tìm được cú thủ hợp lệ nào thì `safety = null`, giữ câu hiện tại (*"Bi N không có đường đánh rõ ràng… nên chơi an toàn (safety) thay vì cố đánh."* / *"Không bi nào…"*) và kế hoạch dừng như bây giờ.

---

## 4. Chấm điểm cú thủ (`safety_scoring.dart`), điểm càng thấp càng tốt

### 4.1 Mỗi mức lực

Với mỗi mức lực (chọn, −15%, +15%, giới hạn 100%; cùng kiểu đánh, áp phê, độ dày):

| Thành phần | Cách tính |
|---|---|
| **Phần đối thủ** | Đối thủ bị đui → **0**. Không đui → **95 − góc cắt dễ nhất của đối thủ** (6 lỗ, bỏ lỗ bị chắn); không lỗ nào ăn được → góc 95°, tức **0** |
| **Sát băng** | **−5** cho mỗi bi cách băng ≤ 5,7 cm: bi cái, và bi đối thủ phải đánh dễ nhất |
| **Khoảng cách** | **− khoảng cách bi cái → bi đối thủ phải đánh dễ nhất (cm) × 0,01** |

Mức lực nào phạm luật (3.5) thì **phần đối thủ = 95**, không cộng sát băng và khoảng cách.

**Lấy mức xấu nhất** (tổng ba thành phần trên lớn nhất) trong ba mức lực.

### 4.2 Điểm phương án

**Điểm = mức xấu nhất (4.1) + phạt kỹ thuật + phạt A băng + phạt lực**

| Phạt | Giá trị |
|---|---|
| Kỹ thuật | đứng 0 · cu lê 3 · trô 10; áp phê ½ đầu cơ 15, 1 đầu cơ 20, cộng dồn (như spec gốc) |
| A băng | 1 băng **10** · 2 băng **20** · 3 băng **45** · 4 băng **55**; trực tiếp 0 |
| Lực | lực × 0,04 |

Chọn điểm thấp nhất. Bằng điểm thì giữ phương án thử trước theo thứ tự cố định: trực tiếp trước A băng; ít băng trước; bi hợp lệ số nhỏ trước; độ dày theo thứ tự 3.3; đứng, cu lê, trô; không áp phê trước; lực tăng dần.

### 4.3 Độ chịu sai số lực (chỉ để hiển thị)

7 mức lực đều nhau trong ±15%; đếm số mức mà đối thủ bị đui hoặc góc cắt dễ nhất của đối thủ > 55° (`zoneFair`) hoặc không còn đường ăn. Dùng đúng hàm mô phỏng và chấm của 4.1.

### 4.4 Đối thủ phải đánh bi nào

- **9 / 10 bi:** bi số nhỏ nhất còn trên bàn, ở **vị trí mới** sau cú thủ (bi vừa bị chạm đã lăn đi).
- **8 bi:** các bi `opponent` còn trên bàn; không còn bi nào thì bi 8.
- Bi mình vừa chạm tính ở vị trí mới khi xét đường chắn.
- "Đối thủ bị đui" dùng đúng định nghĩa 3.2, từ điểm dừng bi cái.

### 4.5 Hằng số mới (`planner_constants.dart`)

`kickRailPenalty = {1: 10, 2: 20, 3: 45, 4: 55}` · `nearRailBonus = 5` · `nearRailDistance = ballDiameter` · `safetyThicknesses = [1, ¾, ½, ¼, ⅛]` · `maxKickRails = 4` · `kickFallbackRails = 4` · `opponentHardAngle = zoneFair`.

---

## 5. Vẽ và lời khuyên cho bước phòng thủ

### 5.1 Trên bàn (màn từng bước), từ dưới lên

1. Các bi khác vẽ mờ (như hiện nay), để thấy vì sao đui.
2. **Đường bi cái đúng từ mô phỏng:** trước va chạm nét đứt trắng (qua các băng, chấm vàng ở mỗi lần chạm băng); sau va chạm nét đứt ngọc; vòng trắng chỗ dừng.
3. **A băng:** vòng vàng đậm ở điểm ngắm trên băng đầu tiên; đánh số chấm ở mép bàn (băng dài 0–8, băng ngắn 0–4).
4. Đường bi hợp lệ sau va chạm và chỗ nó dừng.
5. **Cú dễ nhất của đối thủ**, mờ màu đỏ: bi cái → bi ảo → lỗ. Đối thủ bị đui thì vẽ đường bị chắn và ghi *"Đối thủ bị đui"*.
6. Thanh sai số lực nối hai `jitterEnds` qua điểm dừng.

Chú giải dưới bàn thêm các ký hiệu mới.

### 5.2 Bảng thông tin

- Dòng đầu:
  - bị đui: *"Bi cái bị đui bi N — đánh A băng để thủ."*
  - không đui: *"Không còn đường ăn bi — nên thủ bi."*
- A băng: *"A băng K băng: ngắm chấm X băng Y."* (ví dụ *"A băng 2 băng: ngắm chấm 2,5 băng dài trên."*)
- Trực tiếp: *"Ăn ½ bi, lệch bên trái."* (hoặc *"Ăn trọn bi."*)
- Kiểu đánh, lực. Áp phê: đúng dòng của màn mô phỏng (độ lệch điểm ngắm theo đầu cơ và phần con bi, lời khuyên SAWS).
- Kết quả cho đối thủ:
  - *"Đối thủ bị đui."*
  - hoặc *"Cú dễ nhất của đối thủ: bi N vào lỗ X, góc cắt Y°."*
  - hoặc *"Đối thủ không còn đường ăn."*
- *"k/7 mức lực vẫn để đối thủ khó."*
- Cảnh báo lực ≥ 85% hoặc trô, như spec gốc.

Bước phòng thủ là bước cuối: nút *Xong bàn*. Đặt lại bi cái vẫn dùng được.

**Không câu nào khuyên ngắm theo độ.** Số độ chỉ xuất hiện trong dòng kết quả cho đối thủ (quyết định 9).

### 5.3 Khi đang tìm

Dòng *"Đang tìm cú thủ…"* thay *"Đang tính bước X/N…"* trong lúc `SafetyJob` chạy.

---

## 6. Tốc độ

- Bước thủ ra trong **vài giây** trên Chrome giả lập điện thoại (675 phương án × 3 mức lực cho trực tiếp; A băng tuỳ số chuỗi còn sau cắt tỉa).
- Ngân sách khung hình như spec gốc 10.3. Quyết định về giật hình (đo lại sạch, rồi chấp nhận hoặc Web Worker) áp dụng chung cho cả phần ăn bi lẫn phần thủ.
- Test đo thời gian riêng, gắn tag `perf`.

---

## 7. Nút Chờ ở màn Mô phỏng góc cắt

- Khi `aimShot` ném `SimulationTimeout` (giới hạn `maxSimTime` = 20 giây mô phỏng): bảng thông tin hiện *"Cú này tính quá lâu, bạn muốn chờ hay bỏ qua chỉ vẽ đường ngắm?"* với hai nút **Chờ** và **Chỉ vẽ đường ngắm**. Bàn tạm vẽ đường ngắm.
- **Chờ:** hiện *"Đang tính…"* (vẽ xong khung hình đó rồi mới tính), tính lại đúng cú đó với giới hạn **3 × `maxSimTime`**.
  - Xong: vẽ đủ như mọi cú.
  - Vẫn quá giờ: *"Cú này quá dài để mô phỏng."*, giữ đường ngắm.
  - Lần tính này không chia lát được; màn có thể đứng 1–3 giây.
- **Chỉ vẽ đường ngắm:** giữ đường ngắm, câu thành *"Chỉ vẽ đường ngắm."*
- **Không nhớ lựa chọn:** mỗi cú quá giờ mới đều hỏi lại; đổi bi, kiểu đánh, lực thì câu hỏi biến mất.
- Lõi: `simulateShot` / `aimShot` nhận thêm giới hạn thời gian tuỳ chọn, mặc định `maxSimTime`.
- **Planner không hỏi:** phương án quá giờ vẫn bị bỏ qua lặng lẽ.
- Bỏ `Vi.simCannotSimulate`; chữ mới nằm trong `vi.dart`.

---

## 8. Sửa `PRD_RunOutPlanner.md`

Đánh dấu *(sửa 2026-10-07: cú phòng thủ)*:
- §5.4 / §5.5 bước phòng thủ: tìm cú thủ (mục 3–4 spec này) thay vì dừng trơn.
- §6: vẽ và bảng thông tin bước phòng thủ (mục 5).
- §8: bỏ "cú phòng thủ" khỏi ngoài phạm vi; ghi rõ kế hoạch vẫn dừng sau cú thủ.

---

## 9. Kiểm thử

### 9.1 Lõi, trên lõi vật lý thật

1. **Phân loại đui:** bàn chắn cả trọn bi lẫn hai đường mỏng → đui; hở một mép → không đui, và chỉ thử độ dày nhìn thấy được.
2. **Luật:** bốn bàn, mỗi bàn một kiểu phạm lỗi (chạm bi khác trước; không bi nào chạm băng; chết cái; bi hợp lệ rơi lỗ) → cú đó bị loại.
3. **A băng đúng số băng:** bàn đui cần 1 băng → cú chọn có đúng 1 lần chạm băng trước va chạm và chạm bi hợp lệ trước mọi bi khác. Bàn riêng buộc 2 băng và 3 băng.
4. **4 băng là đường lui:** khi 1–3 băng có cú hợp lệ thì không mô phỏng chuỗi 4 băng nào.
5. **Điểm ngắm theo chấm:** điểm chạm băng đầu đổi đúng ra chấm làm tròn nửa chấm, đếm từ góc trái, đúng tên băng.
6. **Chấm điểm:** đối thủ đui thắng mọi cú không đui có cùng phạt; sát băng −5 mỗi bi; phạt 10/20/45/55 cộng dồn với kỹ thuật và áp phê; mức ±15% phạm luật tính phần đối thủ 95; bằng điểm giữ phương án thử trước.
7. **Cú đơn giản thắng khi gần ngang:** bàn có cú thủ trực tiếp đứng bi gần bằng một cú A băng 2 băng → chọn cú trực tiếp.
8. **Đối thủ đánh đúng bi:** 9 bi tính ở vị trí mới của bi vừa chạm; 8 bi là nhóm đối thủ, hết nhóm thì bi 8.
9. **Chia lát:** nhiều cỡ lát cho đúng y như chạy một mạch; huỷ không báo thêm; tất định.
10. **Không có cú thủ hợp lệ:** giữ đúng câu hiện tại, kế hoạch dừng.

### 9.2 Màn hình

- Bước phòng thủ vẽ đủ lớp: điểm ngắm và số chấm khi A băng, đường đối thủ mờ đỏ hoặc chữ "Đối thủ bị đui".
- Các dòng thông tin đúng câu đã chốt; có số độ cho đối thủ; **không câu nào khuyên ngắm theo độ**.
- Màn mô phỏng: Chờ → ra đường đi; Chờ mà vẫn quá giờ → câu "quá dài"; Chỉ vẽ đường ngắm → giữ đường ngắm; cú quá giờ mới hỏi lại.

### 9.3 Chrome và chủ sản phẩm

`tool/e2e/planner.mjs` thêm ba bàn: thế đui cần A băng; thế không đui nhưng hết đường ăn; bàn 8 bi thủ với bi đối thủ. Chụp từng bước. **Dừng để chủ sản phẩm xem** cú thủ có giống cách người chơi giỏi chọn không, rồi mới chỉnh điểm phạt. Sau đó review cả nhánh, merge và deploy theo quyết định của chủ sản phẩm.
