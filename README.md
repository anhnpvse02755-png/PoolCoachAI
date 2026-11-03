# PoolCoachAI

Ứng dụng huấn luyện bida cá nhân hoá cho cơ thủ Việt Nam. Giao diện hoàn toàn tiếng Việt.

Vòng lặp cốt lõi: **Đánh giá → Học → Tập → Chơi → Phân tích → Đề xuất → Tập tiếp**

---

## Trạng thái hiện tại

Ứng dụng đã vượt qua giai đoạn khung điều hướng. Các luồng đã có gồm:

- Đăng nhập, hồ sơ người chơi, đánh giá kỹ năng và hạng.
- Thư viện bài tập, ghi kết quả buổi tập, đồng hồ/lịch tập và Lộ trình cá nhân.
- Thư viện Kiến thức; hiện có 11 bài seed trong app, gồm 5 bài mới tóm lược các mục áp phê từ từ điển.
- Ghi trận 8/9/10 bi và ghi cú theo từng ván; phân tích trận được dùng trong Statistics, Intelligence, Coach và Lộ trình.
- Thống kê luyện tập/trận đấu, hồ sơ cơ và đồng bộ dữ liệu theo tài khoản.
- Coach Chat qua dịch vụ riêng dùng Ollama local; mô hình chỉ diễn giải dữ kiện đã tính, không tự quyết định đánh giá hay hạng.

Các luồng chưa hoàn tất hoặc còn giới hạn được liệt kê ở mục **Việc còn treo** và cập nhật chi tiết trong [PRD_PoolCoachAI.md](./PRD_PoolCoachAI.md). Tài liệu triển khai lịch sử trong `docs/superpowers/plans/` có thể mô tả trạng thái tại thời điểm lập kế hoạch; dùng PRD và code hiện tại để xác nhận trạng thái mới nhất.

---

## Chạy trên máy mới

### 1. Flutter

Cần Flutter/Dart theo phiên bản quy định trong `pubspec.yaml`.

```bash
flutter --version
```

Nếu không có, cài từ https://docs.flutter.dev/get-started/install rồi `flutter doctor`.

### 2. Lấy phụ thuộc và kiểm tra

```bash
flutter pub get
flutter analyze
flutter test
```

### 3. Chạy app

```bash
flutter run -d chrome
```

Chạy trên Android/iOS cần cài và cấu hình toolchain nền tảng tương ứng.

---

## Tài liệu — đọc theo thứ tự này

| File | Nội dung |
|---|---|
| `docs/superpowers/specs/2026-09-17-poolcoachai-shell-design.md` | **Tài liệu thiết kế chính.** Đọc mục 2.1 và 2.2 trước bất cứ thứ gì khác |
| `PRD_PoolCoachAI.md` | Mô tả sản phẩm đầy đủ |
| `Claude_desktop/PoolCoachAI_SPEC.md` | Công thức Player Intelligence và recommendation engine, phân kỳ 5 phase |
| `Claude_desktop/poolcoachai-reference.html` | Prototype, chứa dữ liệu khởi tạo (dòng 302–395) |
| `Tu-Dien-Kien-Thuc-Billiard-Pool.md` | Từ điển nội dung tham khảo cho module Kiến thức |
| `PoolCoachAI.md` | Bản mô tả gốc, đã được PRD thay thế |
| `docs/superpowers/plans/` | Kế hoạch triển khai từng phần |

---

## Bốn quy tắc không được phá

### 1. Không bịa, không viết cứng nội dung sinh ra

Chữ cố định của giao diện (nhãn tab, tên nút) nằm trong `vi.dart` — viết sẵn là **đúng**.

Nội dung do hệ thống sinh ra (gợi ý huấn luyện viên, mục tiêu hôm nay, nội dung thông báo, kết luận thống kê) **phải tính từ dữ liệu** bằng hàm có tên, có kiểm thử. Câu chữ là khuôn có tham số, tham số do hàm điền. Thiếu dữ liệu thì nói thẳng là thiếu, không đoán.

*Phép thử:* đổi dữ liệu mẫu cho người chơi yếu nhóm khác — mọi kết luận trong app phải tự đổi theo. Không đổi nghĩa là có chỗ viết cứng.

### 2. Phân tầng AI

| Tầng | Công cụ |
|---|---|
| Player Intelligence | Dart thuần, deterministic |
| Cổng mở cấp (progression gate) | **Rule-based, cấm LLM tuyệt đối** — hỏi hai lần ra hai đáp án thì không còn là xếp hạng |
| Recommendation | Rule trước, ML sau |
| Coach Chat | Ollama local, **chỉ diễn giải** số liệu tầng 1 đã tính, không tự tính |
| Camera/Vision | Computer vision, bài toán riêng, làm sau cùng |

**Không cần API key LLM trong app.** Luồng Coach Chat: `App → Coach Chat service → Ollama chạy cục bộ`.

### 3. Thuật ngữ đã chốt

Cơ thủ đã sửa từng từ. Tiếng bida Việt Nam mượn nhiều từ **tiếng Pháp**, không dịch nghĩa đen từ tiếng Anh.

| Tiếng Việt | Gốc | |
|---|---|---|
| Ngắm bi | aiming | |
| Điều bi / Vị trí | position | *không phải "Đi bi"* |
| Phá | break | *không phải "Giao bóng"* |
| Phòng thủ | safety | |
| **A băng** | **kick** · *à bande* | bi **cái** chạm băng trước |
| **Cân bi** | **bank** | bi **mục tiêu** chạm băng |
| Đánh đứng bi | stop shot | |
| Đánh trô bi | draw · *rétro* | |
| Đánh cu lê | follow · *coulé* | |
| Chết cái | scratch | |
| Bi ảo | ghost ball | |
| Bi cái, gọi tắt "cái" | cue ball | |

⚠️ **Bẫy dễ vấp:** "bank" và "a băng" nhìn như cùng gốc nhưng **ngược nhau**. A băng = kick.

### 4. Kiến trúc

- Mọi màn hình đọc dữ liệu qua **repository interface**, không bao giờ import mock trực tiếp
- `lib/domain/` là pure Dart, không import Flutter
- Mọi màu qua `AppColors`, mọi khoảng cách qua `AppSpacing`, mọi chữ tiếng Việt qua `vi.dart`
- Riverpod **không dùng codegen**

---

## Việc còn treo

- **Kiến thức:** 5 mục mới về áp phê đã vào seed của app. Phần còn lại của từ điển chưa được chuyển thành bài app; cần biên tập/duyệt theo từng nhóm và liên kết với bài tập phù hợp.
- **Skill Test / Certification:** hiện mới hiển thị số buổi đạt liên tiếp; chưa có bài kiểm tra/chứng nhận riêng hoặc cơ chế tự mở cấp.
- **Lịch tập:** lịch đã ảnh hưởng ưu tiên nhóm kỹ năng, nhưng chưa điều chỉnh mục tiêu theo thời lượng dự kiến.
- **Thông báo:** lịch tập và streak có nhắc cục bộ; thông báo gợi ý mới từ Coach và push khi ứng dụng đóng chưa hoàn tất.
- **Play:** chưa có quản lý giải đấu; nhập cú vẫn là thủ công, không có nhận diện Camera/Vision.

---

## Cấu trúc mã

```
lib/
├── main.dart            điểm vào, bọc ProviderScope
├── app.dart             MaterialApp.router
├── core/
│   ├── theme/           AppColors · AppSpacing · AppTypography · AppTheme
│   ├── router/          Routes · createAppRouter()
│   ├── strings/vi.dart  toàn bộ chữ tiếng Việt
│   └── widgets/         PcCard · PcSectionHeader · PcEmptyState
│                        PcSkillChip · PcRankBadge · PcShellScaffold
├── domain/              SkillCategory · Rank  (pure Dart)
└── features/            home · training · play · stats · profile
                         coach · notifications
```
