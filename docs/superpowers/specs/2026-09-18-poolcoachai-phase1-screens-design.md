# PoolCoachAI — Thiết kế lát dọc Phase 1: từ Drift lên màn hình

**Ngày:** 18/09/2026
**Trạng thái:** đã duyệt hướng, chờ chuyển thành kế hoạch thực thi
**Tiền đề:** Kế hoạch 1 (khung app) và Kế hoạch 2 (lớp suy luận) đã merge vào `main`, 131 test xanh

---

## 1. Mục tiêu

Nối `lib/domain/` với màn hình, qua một lớp dữ liệu thật.

Hiện `computeRecommendation()` tính ra gợi ý đầy đủ nhưng **không màn nào đọc nó**, và không có cách nào tạo ra `DrillLog` để nó có gì mà tính. Lát này đóng vòng đó:

> Xem gợi ý → mở bài tập → ghi kết quả → gợi ý đổi theo.

Đây là lát mỏng nhất mà **dùng thật được**, và nó kiểm chứng cả chồng `domain → data → UI` một lượt.

### Không thuộc phạm vi

Mô phỏng góc cắt · Đồng hồ & Lịch tập · Cơ bi-a · Thống kê · Thi đấu · Hồ sơ · Coach LLM · Thông báo. Các tab đó giữ nguyên trạng thái "Đang xây dựng" của Kế hoạch 1.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | **Lát dọc khép kín**, không làm AI Home một mình | AI Home không có `DrillLog` thì người chơi mãi là "người mới", sáu luật ưu tiên không kiểm chứng được trên màn hình thật |
| 2 | **Drift / SQLite** làm nơi lưu, không phải mock trong bộ nhớ | Đúng đích cuối spec nhắm tới. Đánh đổi đã biết: `build_runner`, migration, và cài WASM cho web |
| 3 | **Drift `watch()` → `StreamProvider`** | Ghi log xong màn hình tự đổi. Lỗi "hiện số cũ" thành không thể xảy ra về cấu trúc, thay vì thành việc phải nhớ gọi `invalidate` |
| 4 | **Có màn đọc bài kiến thức** | `TodayRecommendation.article` đã có sẵn; hiện tên mà bấm không ra gì là thứ tệ hơn không hiện |

### Vì sao bác lối B và C (dòng chảy dữ liệu)

`memory` của dự án cấm mọi con số không truy được về logic thật. **Số cũ cũng là số sai.** Lối B (`invalidate` tay) biến việc đó thành kỷ luật con người — quên một chỗ là màn hình nói dối mà không test nào biết. Lối C giữ hai nguồn sự thật phải tự đồng bộ, hỏng theo cách tệ hơn nữa.

---

## 3. Kiến trúc

### 3.1 Bốn tầng

```
  Màn hình          đọc provider, dựng câu từ dữ liệu
      ↑              (mọi chuỗi tiếng Việt nằm ở vi.dart)
  Provider          ghép seed + log thành TodayRecommendation
      ↑
  Repository        interface thuần Dart, trả Stream
      ↑
  Drift / SQLite    chỉ chứa thứ người chơi tạo ra
```

`lib/domain/` **không đổi một dòng nào** trong lát này. Nó đã đúng và đã được 131 test phủ; nếu thấy mình muốn sửa nó, dừng lại và hỏi.

### 3.2 Cái gì xuống DB, cái gì không

**Tất cả xuống DB.** Chủ sản phẩm chốt ngày 18/09/2026.

| Dữ liệu | Nguồn sự thật | Ghi vào DB khi nào |
|---|---|---|
| 10 bài tập, 6 bài kiến thức | `lib/data/seed/` trong mã | Upsert theo `id` **mỗi lần mở app** |
| `DrillLog` | DB | Người chơi bấm lưu |
| `ScheduleSlot`, `TimerSession` | DB (bảng dựng sẵn, **chưa màn nào dùng**) | Chưa có |

Bảng dựng sẵn mà chưa dùng là cố ý và có giới hạn: **chỉ hai bảng này**, vì chữ ký hàm trong `lib/domain/` đã đòi chúng rồi.

### 3.2.1 Vì sao upsert mỗi lần mở, không phải nạp một lần

Bài tập nằm trong DB thì bản sửa trong mã **không tự tới được máy đã cài**. Dự án này đã dính đúng chuyện đó hai lần: đổi `d8` từ `kick` sang `bank`, và thay "Stop shot" · "Bi băng" · "Giao bóng" bằng thuật ngữ cơ thủ đã chốt. Nếu chỉ nạp lần đầu, những máy cài trước đợt sửa sẽ giữ từ sai vĩnh viễn, và không ai biết.

Upsert theo `id` mỗi lần khởi động làm mã trong repo thành nguồn sự thật cho dữ liệu seed, còn DB là bản sao đọc được bằng truy vấn.

Đánh đổi đã biết: **người chơi không sửa được bài seed**, vì lần mở sau sẽ bị ghi đè. Hiện app không cho sửa nên chưa mất gì. Ngày nào muốn cho sửa, bài tập tự tạo phải nằm ở bảng riêng hoặc mang cờ phân biệt — không được nới luật upsert này.

### 3.3 Đồng hồ tiêm vào, không gọi `DateTime.now()` thẳng

`computeRecommendation()` nhận `today`. Nếu provider gọi `DateTime.now()` thẳng thì test phụ thuộc ngày chạy máy — chạy hôm nay xanh, chạy đúng nửa đêm đỏ.

```dart
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
```

Test ghi đè provider này bằng một ngày cố định. Đây là cùng một nguyên tắc với `PoolCoachApp(router:)` ở Kế hoạch 1: thứ gì mang trạng thái ngoài tầm kiểm soát thì tiêm vào.

---

## 4. Lớp dữ liệu

### 4.1 Bảng Drift

```dart
class DrillLogRows extends Table {
  TextColumn get id => text()();
  TextColumn get drillId => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get score => real()();
  IntColumn get attempts => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
class DrillRows extends Table {
  TextColumn get id => text()();
  TextColumn get cat => text()();            // SkillCategory.name
  TextColumn get name => text()();
  IntColumn get level => integer()();
  TextColumn get unit => text()();
  TextColumn get goal => text()();
  TextColumn get steps => text()();          // JSON: List<String>
  RealColumn get passThreshold => real().nullable()();
  RealColumn get target => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`KnowledgeArticleRows` tương tự, với `relatedDrillIds` cũng là JSON `List<String>`.

`ScheduleSlotRows` và `TimerSessionRows` theo đúng hình dạng lớp tương ứng trong `lib/domain/`.

**`schemaVersion = 1`.** Chưa có migration nào để viết, nhưng `MigrationStrategy` phải được khai báo tường minh ngay từ đầu để lát sau không ai phải đoán bản đầu tiên là gì.

### 4.2 Chuyển đổi hai chiều

Hàng Drift **không phải** là kiểu miền. `DrillLogRow` do `build_runner` sinh ra, `DrillLog` là lớp viết tay trong `lib/domain/`. Giữ chúng tách biệt, nối bằng hàm chuyển đổi:

```dart
DrillLog toDomain(DrillLogRow row);
DrillLogRowsCompanion toRow(DrillLog log);
```

Lý do không dùng chung một lớp: `lib/domain/` cấm phụ thuộc vào hạ tầng. Dùng lớp Drift sinh ra làm kiểu miền sẽ kéo `package:drift` vào tầng suy luận và khoá nó vào SQLite vĩnh viễn.

**Ba chỗ mất mát khi đi vòng qua SQLite, phải có test vòng chuyển đổi:**

| Chỗ | Chuyện gì xảy ra |
|---|---|
| `Drill.target` kiểu `num?` | Cột `real` đọc lên thành `double`. `target: 25` trong seed quay về là `25.0`. `drillRatio()` chia nên không sai kết quả, nhưng so sánh bằng `==` giữa `Drill` gốc và `Drill` đọc từ DB sẽ **không** khớp |
| `DrillLog.score` kiểu `num` | Y hệt: `8` thành `8.0` |
| `steps`, `relatedDrillIds` | `List<String>` qua JSON. Danh sách rỗng phải quay về rỗng, **không** phải `null` |

Ràng buộc "đúng một trong `passThreshold`/`target`" là `assert` trong hàm dựng `Drill`. Đọc lên từ DB vẫn đi qua hàm dựng đó, nên một hàng hỏng sẽ ném ngay lúc đọc chứ không lặng lẽ chạy tiếp. Đó là hành vi mong muốn, và nó có test.

### 4.3 Interface repository

```dart
abstract interface class DrillLogRepository {
  Stream<List<DrillLog>> watchAll();
  Future<void> add(DrillLog log);
}

abstract interface class DrillRepository {
  Stream<List<Drill>> watchAll();
}

abstract interface class KnowledgeRepository {
  Stream<List<KnowledgeArticle>> watchAll();
}
```

`DrillLogRepository.watchAll()` trả **cũ nhất trước** — đúng thứ tự `categoryMastery()` đòi. Thứ tự này là một phần của hợp đồng, không phải chi tiết cài đặt, nên nó có test riêng.

### 4.3.1 Nạp seed lúc khởi động

```dart
Future<void> upsertSeed(AppDatabase db);
```

Chạy một lần khi mở app, **trước** khi màn hình đầu tiên đọc dữ liệu. Ghi đè theo `id`, trong một giao dịch, để app không bao giờ đọc phải bộ seed nạp dở.

Hàm này là điểm nối duy nhất giữa `lib/data/seed/` và DB. Không màn hình nào, không provider nào đọc thẳng `seedDrills` nữa — đọc thẳng là quay lại có hai nguồn sự thật, đúng thứ lối C đã bị bác.

### 4.4 Drift trên web — rủi ro lớn nhất của lát này

Trên máy này Chrome là cách duy nhất chạy được app: chưa có Android SDK (thiếu `cmdline-tools`, chưa nhận license) và chưa cài Visual Studio. Drift chạy web cần:

- `web/sqlite3.wasm`
- `web/drift_worker.js`
- `DatabaseConnection` mở qua `WasmDatabase`

**Việc này phải là task đầu tiên có thể chạy được của kế hoạch**, ngay sau khi dựng bảng. Nếu nó vỡ thì phải biết trước khi dựng ba màn hình, không phải sau.

Nếu WASM không chạy được trong thời gian hợp lý, đây là chỗ dừng lại và hỏi — không tự ý quay về mock trong bộ nhớ, vì như vậy là lặng lẽ đảo ngược một quyết định của chủ sản phẩm.

---

## 5. Provider

```dart
appDatabaseProvider         → AppDatabase
drillRepositoryProvider     → DrillRepository        (đổi một dòng là đổi backend)
knowledgeRepositoryProvider → KnowledgeRepository
drillLogRepositoryProvider  → DrillLogRepository
drillsProvider              → StreamProvider<List<Drill>>
knowledgeProvider           → StreamProvider<List<KnowledgeArticle>>
drillLogsProvider           → StreamProvider<List<DrillLog>>
playerIntelligenceProvider  → Provider<PlayerIntelligence?>
todayRecommendationProvider → Provider<TodayRecommendation?>
nowProvider                 → Provider<DateTime Function()>
```

Hai provider suy luận trả `null` khi **bất kỳ stream nguồn nào chưa có dữ liệu lần đầu** — đó là "chưa biết", khác hẳn "không có gì". Màn hình hiện trạng thái đang tải, **không** hiện số 0.

Bài tập giờ cũng là stream, nên `todayRecommendationProvider` phải chờ **cả ba** nguồn (bài tập, kiến thức, log) rồi mới tính. Thiếu một nguồn mà vẫn tính là ra gợi ý dựa trên danh sách bài rỗng — tức một câu trả lời trông như thật mà sai.

Đây là mục 2.1 tài liệu thiết kế áp cho tầng provider: thiếu dữ liệu thì nói thiếu, không quy về một con số trông như thật.

---

## 6. Màn hình

### 6.1 AI Home — thay `HomeScreen`

Đọc `todayRecommendationProvider`, dựng bốn khối:

| Khối | Nguồn | Khi thiếu |
|---|---|---|
| Chuỗi ngày tập | `rec.streak` | `0` là số thật, hiện bình thường |
| Nhóm hôm nay + **vì sao** | `rec.cat`, `rec.reason` | luôn có |
| Bài tập gợi ý | `rec.drill` | `null` → "hôm nay tập hết bài nhóm này rồi", không thay bài nhóm khác |
| Bài đọc | `rec.article` | `null` → ẩn hẳn khối, không thay bài nhóm khác |

**`reason` phải hiện thành câu, không được nuốt.** Sáu lý do cho sáu câu khác nhau trong `vi.dart`:

```dart
static String pickReason(PickReason reason, String skill) => switch (reason) {
      PickReason.scheduled    => 'Lịch tập hôm nay của bạn là $skill.',
      PickReason.streakAtRisk => 'Hai hôm rồi bạn chưa tập. Quay lại nhẹ nhàng với $skill.',
      PickReason.weakest      => '$skill đang là nhóm yếu nhất của bạn.',
      PickReason.newcomer     => 'Bắt đầu với $skill — nền của mọi cú đánh.',
      PickReason.declining    => '$skill đang đi xuống. Ôn lại trước khi thành điểm yếu.',
      PickReason.rotation     => 'Đã lâu bạn chưa tập $skill.',
    };
```

Đây **không phải** bịa nội dung: khuôn câu cố định, tham số do hàm tính ra. Đúng mục 2.1 — cấm số bịa, không cấm câu chữ có tham số.

### 6.2 Thư viện bài tập — thay `TrainingScreen`

Danh sách 10 bài, lọc theo `SkillCategory` bằng `PcSkillChip` (cả **sáu** nhóm, gồm Cân bi). Mỗi dòng: tên, nhóm, cấp, và tỉ lệ lần gần nhất nếu đã từng tập.

### 6.3 Chi tiết bài — `/training/drills/:id`

Mục tiêu, các bước, đơn vị đo, cách chấm. Nút mở buổi tập. Id không tồn tại → dùng `errorBuilder` đã có từ đợt sửa Minor.

### 6.4 Buổi tập — `/training/drills/:id/session`

Nhập kết quả rồi lưu. Ràng buộc đến thẳng từ kiểu miền:

- `drill.usesAttempts == true` → nhập **cả** `score` và `attempts`; `attempts` bắt buộc, phải `> 0`
- `drill.usesAttempts == false` → chỉ nhập `score`, không hỏi `attempts`

Lưu xong, hiện tỉ lệ đạt từ `drillRatio()` và quay về. AI Home tự đổi qua stream — **không gọi `invalidate` ở đâu cả**, và điều đó phải có test chứng minh.

Dữ liệu vào không hợp lệ thì chặn tại nút lưu kèm câu giải thích, **không** lưu một `DrillLog` méo rồi để `drillRatio()` trả `null` về sau.

### 6.5 Đọc kiến thức — `/knowledge/:id`

Tiêu đề, thân bài, nhóm kỹ năng. Có `relatedDrillIds` thì hiện liên kết sang bài tập.

### 6.6 Route mới

```
/training/drills/:id
/training/drills/:id/session
/knowledge/:id
```

Ba đường dẫn này **phải thêm vào `Routes.all`**. Bảng trong smoke test đối chiếu với nó, nên quên là đỏ ngay — đúng như lưới đã dựng ở đợt sửa review.

Hai route đầu nằm **trong nhánh Luyện tập** của `StatefulShellRoute`, không đè lên shell: đi sâu vào bài tập rồi sang tab khác, quay lại phải thấy nguyên chỗ đang dở. Đây cũng là lần đầu hành vi "bấm lại tab đang mở để về gốc" có tác dụng thật trong app — test cho nó đã có sẵn từ M8.

---

## 7. Kiểm thử

| Tầng | Kiểm cái gì |
|---|---|
| Drift | Ghi rồi đọc lại đúng; `watchAll()` trả cũ nhất trước; `attempts` null và `steps` rỗng sống sót vòng chuyển đổi; hàng vi phạm ràng buộc `passThreshold`/`target` ném ngay lúc đọc |
| Nạp seed | Mở lần đầu ra đủ 10 bài và 6 bài đọc; **sửa một bài trong seed rồi nạp lại thì bản ghi cũ bị ghi đè**; `DrillLog` không bị đụng tới |
| Repository | Thêm một log thì stream bắn lại |
| Provider | Ghi đè `nowProvider` bằng ngày cố định; ghi đè repository bằng bản giả; gợi ý đổi khi log đổi |
| Màn hình | AI Home hiện đúng câu cho từng `PickReason`; `drill` null ra trạng thái rỗng chứ không phải màn trắng |
| **Vòng khép kín** | Mở app → ghi một log kém ở một nhóm → AI Home **tự** đổi sang nhóm đó, không ai gọi `invalidate` |

Hàng cuối là test quan trọng nhất của lát này. Nó là lý do tồn tại của lối A.

Test dùng Drift trong bộ nhớ (`NativeDatabase.memory()`), chạy trên VM, không đụng WASM.

---

## 8. Rủi ro

| Rủi ro | Mức | Xử lý |
|---|---|---|
| Drift WASM không chạy trên Chrome | **Cao** | Task sớm nhất có thể chạy được. Vỡ thì dừng và hỏi, không tự quay về mock |
| `build_runner` sinh mã xung đột lint đang bật | Trung bình | Loại trừ `*.g.dart` khỏi analyze, đúng cách làm chuẩn của Drift |
| Lát phình ra vì thêm màn | Trung bình | Năm màn ở mục 6.1–6.5 là toàn bộ. Màn thứ sáu nghĩa là kế hoạch sai, dừng lại |
| `lib/domain/` bị sửa cho tiện | Thấp nhưng đắt | Nó đã đúng và đã phủ test. Muốn sửa thì dừng và hỏi |
| Upsert seed xoá mất thứ người chơi tạo | Thấp bây giờ, cao về sau | Upsert chỉ đụng bảng bài tập và kiến thức, theo `id`. Ngày nào cho người chơi tự tạo bài, thứ họ tạo phải nằm ngoài tầm với của upsert |
| Còn chỗ nào đọc thẳng `seedDrills` | Trung bình | Sau khi có DB, chỉ `upsertSeed()` được chạm vào seed. Chỗ khác đọc thẳng là hai nguồn sự thật |

---

## 9. Xong là khi

- [ ] Ghi được kết quả buổi tập, đóng app mở lại vẫn còn
- [ ] AI Home đổi gợi ý sau khi ghi, không nơi nào gọi `invalidate`
- [ ] Sáu `PickReason` ra sáu câu tiếng Việt khác nhau
- [ ] Bài tập hoặc bài đọc thiếu thì ra trạng thái rỗng, không ra số bịa và không ra màn trắng
- [ ] `flutter test` xanh, `flutter analyze` sạch, `flutter build web` chạy
- [ ] Ba route mới nằm trong `Routes.all` và trong bảng smoke test
- [ ] Sửa một bài trong `lib/data/seed/` rồi mở lại app thì bản sửa hiện ra, không cần xoá app
- [ ] Ngoài `upsertSeed()`, không nơi nào đọc thẳng `seedDrills` hay `seedKnowledge`
