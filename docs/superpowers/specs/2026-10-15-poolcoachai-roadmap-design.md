# Lộ trình — thiết kế (viết lại sau Đánh giá + hạng)

Ngày: 15/10/2026. Trạng thái: chủ sản phẩm duyệt từng phần trong buổi thiết kế 15/10; chờ duyệt bản viết.
Thay cho `2026-10-06-poolcoachai-roadmap-design.md` (spec đó tự ghi "phải viết lại sau khi có dự án con Đánh giá + hạng"). Các quyết định cũ còn giữ được nhắc lại ở §2.

## 1. Mục đích

Người chơi có **một mục tiêu**, thấy **chuỗi bước cụ thể** dẫn tới đó, và chuỗi bước **tự đổi theo số liệu tập của chính họ**. AI đề xuất, không khóa người dùng (PRD §6.1).

Thành công khi:
- Chọn mục tiêu xong thấy ngay các bước, mỗi bước có lý do lấy từ số liệu thật.
- Ghi một buổi tập → lộ trình (trạng thái, ngày dự kiến) đổi theo mà không cần bấm gì.
- Mục tiêu và thành tích theo tài khoản, thấy trên máy thứ hai.

## 2. Quy tắc nền (giữ từ spec cũ, rank spec, README)

1. Không bộ câu hỏi mới; điểm xuất phát là hạng + bài BU + Player Intelligence đã có.
2. Mỗi câu chữ sinh ra phải đến từ một hàm có tên, có test, điền vào mẫu trong `vi.dart`. Thiếu dữ liệu → nói "chưa đủ dữ liệu", không đoán. Không LLM trong mọi quyết định của Lộ trình.
3. Hạng chỉ đổi qua bài BU. Lộ trình **không** suy cảnh báo hạng từ dữ liệu luyện tập (rank spec Q15).
4. Đổi mục tiêu là tính lại từ đầu, không cộng dồn.
5. Ngày là ước lượng động từ tốc độ tiến bộ gần đây, không phải ngày cố định.
6. Cổng lên cấp bài tập dùng lại `isReadyForLevelUp` (3 buổi đạt liên tiếp), không định nghĩa lại.
7. Thành tích chỉ đến từ sự kiện dữ liệu thật; không có thành tích tạo bằng tay.
8. Không thêm tab thứ 6; Lộ trình nằm trong tab Luyện tập. Không sửa Recommendation Engine. Không push notification.

## 3. Mục tiêu (quyết định của chủ sản phẩm 15/10)

Ba loại, mỗi tài khoản đúng **một** mục tiêu đang chạy:

| Loại | Người chơi chọn | Ghi chú |
|---|---|---|
| `lenHang` (Lên hạng) | không chọn gì | Đích **luôn là hạng ngay trên** hạng hiện tại; lên được thì tự chuyển sang hạng tiếp theo. Khóa khi chưa có hạng (nút "Xác định hạng") hoặc đang ở A/PRO (PRO chỉ tự khai). |
| `thuanThucKyNang` (Thuần thục kỹ năng) | 1 trong 6 nhóm | |
| `chuanBiGiai` (Chuẩn bị giải) | ngày giải, **bắt buộc**, sau hôm nay | Cắt phần không kịp trước ngày giải. Khi có dữ liệu trận đấu sẽ bổ sung (ngoài phạm vi). |

## 4. `buildRoadmap` — logic tính lộ trình

Hàm thuần Dart trong `lib/domain/roadmap/`, không import Flutter.

**Vào:** mục tiêu, `PlayerIntelligence`, các bài tập (đọc qua Drift), nhật ký tập, `PlayerRank`, các bài BU kèm điểm từng bài, `today`.
**Ra:** `Roadmap{goal, target, steps, estimatedFinish | notEnoughData}`. Mỗi `RoadmapStep` có: `kind` (xacDinhHang / nhom / buLe / lamBaiBu / baiTap), `category` hoặc `drillId` hoặc BU ids, `status` (dangLam / xong / chuaToi / khongKip), `estimatedDate | notEnoughData`, `reason` (giá trị có tên để điền mẫu `vi.dart`).

### 4.1 Lên hạng

1. Chưa có hạng → một bước `xacDinhHang`. Hạng A hoặc PRO → mục tiêu không được chọn.
2. **Điểm cần thêm** = sàn BU của hạng đích − tổng điểm của **bài BU hoàn chỉnh gần nhất** (Exam I + Exam II). Sàn theo bảng đã duyệt: K 0, I 20, H 40, G 70, F 95, E 110, D 125, C 140, B 155, A 175. Ví dụ D với 137 điểm → đích C, cần thêm 3.
3. **Điểm mất** mỗi bài BU = tối đa (theo bản Exam II đã làm) − điểm đạt. Cộng dồn theo nhóm qua bảng §5.
4. Xếp nhóm theo điểm mất giảm dần; bằng nhau thì nhóm có độ thuần thục thấp hơn (Player Intelligence) đi trước. **Lấy dần nhóm cho tới khi tổng điểm mất đã lấy ≥ điểm cần thêm.**
5. Điểm mất ở S8, S9 tính vào tổng nhưng không thuộc nhóm nào (§5): nếu > 0 thêm một bước `buLe` "Tập lại S8/S9 trên bàn BU" (không có bài tập cho kỹ thuật này), đặt theo thứ tự điểm mất như một nhóm.
6. Chưa có bài BU hoàn chỉnh (hạng ước tính / tự khai, hoặc Exam II đang hoãn mà chưa có bài hoàn chỉnh nào trước đó) → các nhóm có độ thuần thục < 75 hoặc chưa đo được, xếp từ yếu nhất lên.
7. Bước cuối luôn là `lamBaiBu`: mở từ `retestAvailableFrom` (mốc 14 ngày đã có); chưa từng làm thì mở ngay.

> Đã thay bởi spec 2026-10-29 §5: S8 nối Dựng cơ; S9 vẫn không nối.

### 4.2 Thuần thục kỹ năng

Mỗi bài tập trong nhóm đã chọn là một bước `baiTap`, xếp theo cấp tăng dần. Bước `baiTap` xong khi bài đó `isReadyForLevelUp`. Mục tiêu xong khi nhóm đạt tiêu chí §4.4.

### 4.3 Chuẩn bị giải

Thứ tự bước như §4.1 bước 3–6 (có BU thì theo điểm mất, không thì theo nhóm yếu), lấy **mọi** nhóm có độ thuần thục < 75, **không** có bước `lamBaiBu`. Bước có ngày dự kiến sau ngày giải → `khongKip`, chuyển xuống mục "Không kịp trước giải", không xóa.

### 4.4 Bước nhóm kỹ năng

- Bài tập của bước: `pickDrillInCategory` có sẵn.
- **Xong** khi độ thuần thục nhóm ≥ 75 (`strongThreshold`) **và** bài tập của bước `isReadyForLevelUp`. Tụt dưới 75 thì bước mở lại.
- Nhóm chưa đủ 3 buổi (mastery null) → bước hiện "Tập đủ 3 buổi để đo".

### 4.5 Ngày dự kiến

- Tốc độ nhóm = mức tăng độ thuần thục mỗi ngày trong **28 ngày** gần nhất (hằng số mới, chủ sản phẩm duyệt 15/10; đặt trong `practice_constants.dart`).
- Số ngày của bước = (75 − độ thuần thục hiện tại) / tốc độ, làm tròn lên. Các bước nối tiếp, ngày cộng dồn từ `today`.
- Tốc độ ≤ 0 hoặc chưa đủ dữ liệu → bước đó và mọi bước sau: "chưa đủ dữ liệu". Không đoán.
- Bước `lamBaiBu`: ngày = muộn hơn giữa ngày xong bước trước và `retestAvailableFrom`.

## 5. Bảng nối 18 bài BU → 6 nhóm (chủ sản phẩm duyệt 15/10)

| Bài | Tên | Nhóm |
|---|---|---|
| F1 | Cắt góc | aiming |
| F2 | Đánh đứng bi | position |
| F3 | Đánh cu lê | position |
| F4 | Đánh trô bi | position |
| F5 | Đánh tâm tiến | position |
| F6 | Ăn bi | aiming |
| F7 | Bánh xe | aiming |
| F8 | Lưới đích | position |
| S1 | Hàng bi | aiming |
| S2 | Ngắm bi sát băng | aiming |
| S3 | Thế 9 bi | position |
| S4 | Thế 8 bi | position |
| S5 | Phòng thủ / bắt đui | safety |
| S6 | A băng | kick |
| S7 | Cân bi | bank |
| S8 | Dựng cơ | — (không nối) |
| S9 | Nhảy bi / Mát xê | — (không nối) |
| S10 | Phá | breakShot |

Lý do: mỗi bài xếp theo cái BU chấm điểm (bi vào → aiming; chỗ bi cái dừng → position). F8 và S4 chấm cả hai, xếp position. S8, S9 không khớp nhóm nào: tập ngắm không giúp dựng cơ hay nhảy bi, nên không giao bài sai mục đích. Bảng nằm trong `lib/domain/roadmap/bu_category_map.dart`, ghim bằng test.

> Đã thay bởi spec 2026-10-29 §5: S8 nối Dựng cơ; S9 vẫn không nối.

## 6. Dữ liệu và đồng bộ

Drift schema 3 → 4, chỉ thêm bảng (`if (from < 4) createTable`).

**`PlayerGoalRows`** — `id`, `userId`, `kind`, `category?`, `eventDate?`, `createdAt`, `updatedAt`, `syncedAt?`. Một dòng mỗi tài khoản. Đổi mục tiêu = ghi đè (cập nhật `updatedAt`, `syncedAt = null`); bỏ mục tiêu = xóa (đồng bộ xóa lên server). Không lưu hạng đích.

**`AchievementRows`** — `id`, `userId`, `kind` (xongBuoc / duDieuKienLenCap / chuoiNgay), `refId`, `achievedAt`, `syncedAt?`. Duy nhất theo (`userId`, `kind`, `refId`). Chỉ thêm.

**Directus:** collection `player_goals`, `achievements` (+ quyền Player, quan hệ `user_created` CASCADE như các collection đánh giá). Tạo trên production **phải hỏi chủ sản phẩm ngay lúc đó**.

**`RoadmapSyncService`** — cùng vòng đời `AssessmentSyncService`: chạy khi đăng nhập, theo dõi dòng chưa đồng bộ, thử lại 30 s. Mục tiêu: bản có `updatedAt` mới nhất thắng (hàm thuần `mergeGoal`). Thành tích: chỉ thêm, `RECORD_NOT_UNIQUE` = đã đồng bộ, 4xx khác đỗ lại như `_rejected`.

Repository ghi Drift trước, rồi đồng bộ.

## 7. Thành tích

Hàm thuần `newAchievements(roadmap, intelligence, logs, timerSessions, existing, today)` trả về các thành tích có sự kiện thật mà chưa ghi:

| Loại | Khi nào | `refId` |
|---|---|---|
| `xongBuoc` | bước nhóm / bài tập chuyển sang xong | `<goalId>:<category hoặc drillId>` — mở lại rồi xong lại không ghi trùng |
| `duDieuKienLenCap` | bài tập vừa `isReadyForLevelUp` | `drillId` |
| `chuoiNgay` | `streakDays` chạm mốc **7 / 14 / 30 / 60 / 100** (chủ sản phẩm chọn 15/10) | mốc |

Chỉ repository gọi được thao tác ghi thành tích; test kiến trúc chặn mọi nơi khác.

## 8. Giao diện

- **Tab Luyện tập:** thẻ "Lộ trình" ở đầu → `/training/roadmap` (thêm vào `Routes.all`).
- **Trang chủ:** một dòng "Bước hiện tại: …" dưới thẻ gợi ý hôm nay; không đổi thẻ gợi ý.
- **Chưa có mục tiêu:** chọn 1 trong 3 loại (khóa và lý do như §3; thuần thục chọn nhóm; giải chọn ngày).
- **Có mục tiêu:**
  - Đầu trang: loại, đích (vd "D → C, cần thêm 3 điểm BU"), ngày dự kiến xong hoặc "chưa đủ dữ liệu", nút "Đổi mục tiêu".
  - Danh sách bước: nhãn trạng thái; nhóm + bài tập; độ thuần thục hiện tại / 75 và số buổi đạt liên tiếp / 3; một dòng lý do (vd "Mất 18 điểm ở F3, F5"); nút "Tập ngay" mở buổi tập.
  - Bước "Làm bài BU": mở màn kiểm tra có sẵn, hoặc "Mở từ ngày …".
  - Mục tiêu giải: mục "Không kịp trước giải" thu gọn ở cuối.
  - Phần Thành tích: theo ngày, mới nhất trên cùng.
- Từ cấm của dự án (vd "kim cương", "bi ma", "lọt bi cái") vẫn áp dụng.

## 9. Kiểm thử

- `buildRoadmap`: đổi dữ liệu mẫu thì bước đổi; hai loại mục tiêu cho hai lộ trình khác nhau; điểm cần thêm và cách lấy dần nhóm (có BU / chưa có BU / Exam II hoãn); khóa lên hạng khi không hạng, A, PRO; mốc 14 ngày; xong cần đủ hai điều kiện và mở lại khi tụt; ngày dự kiến 28 ngày và "chưa đủ dữ liệu" khi tốc độ ≤ 0; bước không kịp của mục tiêu giải; bảng §5 ghim bằng test và tổng điểm theo nhóm + S8/S9 bằng tổng điểm mất.
- Thành tích: chỉ qua 3 loại sự kiện; không trùng khi bước mở lại; đúng 5 mốc chuỗi; test kiến trúc.
- `no_fabrication_test`: câu lý do đổi khi số liệu vào đổi.
- Dữ liệu: migration 3 → 4 giữ dữ liệu cũ; repository; đồng bộ (`mergeGoal`, xóa mục tiêu, thành tích trùng).
- Giao diện: widget test màn Lộ trình và chọn mục tiêu; smoke test route mới; kịch bản Chrome `tool/e2e/roadmap.mjs` (chọn mục tiêu → thấy bước → ghi một buổi tập → lộ trình đổi → đổi mục tiêu → máy thứ hai thấy cùng mục tiêu), chạy trên bản cục bộ và trang thật.

> Đã thay bởi spec 2026-10-29 §5: S8 nối Dựng cơ; S9 vẫn không nối.

## 10. Ngoài phạm vi

Dữ liệu trận đấu (và phần "chuẩn bị giải" dùng nó), push notification, sửa Recommendation Engine, đổ kết quả BU vào Player Intelligence, bài tập mới cho dựng cơ / nhảy bi / mát xê, cảnh báo hạng từ dữ liệu luyện tập, mục tiêu nhiều hạng một lúc.
