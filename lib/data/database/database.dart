import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─── Seed data tables ───────────────────────────────────────────────────────

/// Bài tập — seeded từ lib/data/seed/ mỗi lần mở app.
class DrillRows extends Table {
  TextColumn get id => text()();
  TextColumn get cat => text()();
  TextColumn get name => text()();
  IntColumn get level => integer()();
  TextColumn get unit => text()();
  TextColumn get goal => text()();
  TextColumn get steps => text()(); // JSON List<String>
  RealColumn get passThreshold => real().nullable()();
  RealColumn get target => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bài kiến thức — seeded từ lib/data/seed/ mỗi lần mở app.
class KnowledgeRows extends Table {
  TextColumn get id => text()();
  TextColumn get cat => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get relatedDrillIds => text()(); // JSON List<String>

  @override
  Set<Column> get primaryKey => {id};
}

// ─── User-created data tables ───────────────────────────────────────────────

/// Log một lần tập bài.
class DrillLogRows extends Table {
  TextColumn get id => text()();
  TextColumn get drillId => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get score => real()();
  IntColumn get attempts => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get durationSec => integer().nullable()();

  /// Chủ của buổi tập. Mọi truy vấn buổi tập đều lọc theo cột này.
  TextColumn get userId => text()();

  /// Lúc buổi tập lên server. Null nghĩa là **chưa đồng bộ**.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Khung giờ lịch tập hằng tuần.
class ScheduleSlotRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant(''))();
  IntColumn get day => integer()();
  TextColumn get time => text()();
  TextColumn get label => text()();
  TextColumn get cat => text().nullable()();

  /// Lúc sửa gần nhất; bản mới hơn thắng khi đồng bộ. Null = dòng cũ.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Null nghĩa là **chưa đồng bộ**.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Xóa mềm: dòng vẫn ở lại để đồng bộ lệnh xóa sang máy khác.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Buổi tập tự do đo bằng đồng hồ.
class TimerSessionRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSec => integer()();
  TextColumn get cat => text().nullable()();
  TextColumn get cueId => text().nullable()();

  /// Null nghĩa là **chưa đồng bộ**. Buổi tập tự do chỉ thêm, không sửa.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cây cơ của người chơi và thông tin bảo dưỡng đầu cơ.
class CueEquipmentRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get weightGrams => integer().nullable()();

  /// Size ngọn (đường kính ngọn, mm). Cột SQL giữ tên cũ `tip_diameter_mm`
  /// để không phải đổi tên cột trên máy người dùng và trên Directus.
  RealColumn get shaftDiameterMm =>
      real().named('tip_diameter_mm').nullable()();
  TextColumn get shaftBrand => text().nullable()();
  TextColumn get tipBrand => text().nullable()();
  TextColumn get tipHardness => text().nullable()();
  TextColumn get buttBrand => text().nullable()();
  TextColumn get skillCategories => text()();
  DateTimeColumn get lastTipMaintenance => dateTime().nullable()();
  DateTimeColumn get tipMaintenanceDueDate => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Một trận bida đã bắt đầu hoặc hoàn tất.
class PoolMatchRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get gameType => text()();
  TextColumn get playerName => text()();
  TextColumn get opponentName => text()();
  IntColumn get targetRacks => integer()();
  TextColumn get rackWinners => text()();
  TextColumn get shots => text().withDefault(const Constant('[]'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Cây cơ dùng trong trận. Giữ nguyên cả khi cơ bị xóa mềm.
  TextColumn get cueId => text().nullable()();

  /// Giải mà trận thuộc về (spec giải đấu §4.2); giữ nguyên cả khi giải bị xóa mềm.
  TextColumn get tournamentId => text().nullable()();

  /// Nhãn vòng do người chơi gõ, ví dụ "Tứ kết".
  TextColumn get roundLabel => text().nullable()();

  /// Lúc sửa gần nhất (ghi rack, cú đánh...); bản mới hơn thắng khi đồng bộ.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Null nghĩa là **chưa đồng bộ**.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Xóa mềm: dòng ở lại để đồng bộ báo máy khác, mọi truy vấn đọc bỏ qua nó.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Giải đấu ───────────────────────────────────────────────────────────────

/// Giải người chơi tự ghi; xóa mềm, bản sửa mới nhất thắng khi đồng bộ (spec giải đấu §4.1).
class TournamentRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get location => text().nullable()();

  /// `PoolGameType.name`; tên lạ (máy mới hơn) đọc ra là không có.
  TextColumn get gameType => text().nullable()();
  TextColumn get resultNote => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Phiên đăng nhập ────────────────────────────────────────────────────────

/// Phiên đăng nhập trên máy này — tối đa một dòng, id luôn là 'current'.
class AuthSessionRows extends Table {
  TextColumn get id => text().withDefault(const Constant('current'))();
  TextColumn get userId => text()();
  TextColumn get displayName => text()();
  TextColumn get refreshToken => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Đánh giá + hạng (spec 2026-10-14 mục 6.1) ─────────────────────────────

/// Hạng của một tài khoản — mỗi tài khoản một dòng.
class PlayerRankRows extends Table {
  TextColumn get userId => text()();

  /// `Rank.name`; null cùng [source] khi chưa có hạng (đã bấm Để sau).
  TextColumn get rank => text().nullable()();

  /// `RankSource.name`.
  TextColumn get source => text().nullable()();
  IntColumn get buScore => integer().nullable()();
  TextColumn get testId => text().nullable()();
  TextColumn get warningRank => text().nullable()();
  TextColumn get warningTestId => text().nullable()();

  /// JSON `List<int>` — chỉ số lựa chọn của Q1…Q8.
  TextColumn get questionnaireAnswers => text().nullable()();

  /// `OnboardingState.name`.
  TextColumn get onboardingState => text()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Null nghĩa là bản trên máy chưa lên server.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Một lần kiểm tra BU (Đề I + Đề II).
class BuTestRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();

  /// `TableSize.name`.
  TextColumn get tableSize => text()();
  IntColumn get examIScore => integer().nullable()();

  /// `ExamIIVersion.name`.
  TextColumn get examIIVersion => text().nullable()();
  IntColumn get examIIScore => integer().nullable()();
  IntColumn get totalScore => integer().nullable()();

  /// `Rank.name` quy đổi từ tổng điểm.
  TextColumn get resultRank => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kết quả thô của một bài trong một lần kiểm tra. Ghi lại sau mỗi cú, nên
/// đóng app giữa chừng vẫn làm tiếp được.
class BuDrillResultRows extends Table {
  TextColumn get id => text()();
  TextColumn get testId => text()();

  /// 'F1'…'S10'.
  TextColumn get drillId => text()();

  /// JSON của `DrillAttempts` — kết quả thô từng cú.
  TextColumn get attempts => text()();

  /// Điểm bài; null tới khi bài đủ lượt.
  IntColumn get score => integer().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {testId, drillId},
  ];
}

// ─── Skill Test ─────────────────────────────────────────────────────────────

/// Lần kiểm tra kỹ năng — chỉ thêm, ghi một lần khi xong (hoàn tất hoặc huỷ).
///
/// Lần hoàn tất mang kết quả ([score], [passed]) và ảnh chụp tiêu chí đạt của
/// bài lúc đó: đúng một trong [passThreshold] (bài đếm cú, kèm [attempts]) hoặc
/// [target] (bài đo bằng đơn vị khác). Lần huỷ chỉ có [cancelledAt].
class SkillTestRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get drillId => text()();
  IntColumn get drillLevel => integer()();

  /// `TableSize.name`.
  TextColumn get tableSize => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  RealColumn get score => real().nullable()();
  IntColumn get attempts => integer().nullable()();
  BoolColumn get passed => boolean().nullable()();
  TextColumn get notes => text().nullable()();

  /// Ảnh chụp ngưỡng tỉ lệ của bài đếm cú lúc hoàn tất.
  RealColumn get passThreshold => real().nullable()();

  /// Ảnh chụp mục tiêu tuyệt đối của bài lúc hoàn tất.
  RealColumn get target => real().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Lộ trình (spec 2026-10-15 mục 6) ──────────────────────────────────────

/// Mục tiêu của một tài khoản — mỗi tài khoản một dòng. Bỏ mục tiêu thì dòng
/// còn đó với [kind] rỗng, để máy khác biết "đã bỏ" là bản mới hơn (R2).
class PlayerGoalRows extends Table {
  TextColumn get userId => text()();

  /// Đổi mục tiêu là ra id mới.
  TextColumn get goalId => text().nullable()();

  /// `GoalKind.name`; null là đã bỏ mục tiêu.
  TextColumn get kind => text().nullable()();

  /// `SkillCategory.name` cho Thuần thục kỹ năng.
  TextColumn get category => text().nullable()();
  DateTimeColumn get eventDate => dateTime().nullable()();

  /// `Rank.name` của hạng đích Lên hạng; null = hạng kế tiếp.
  TextColumn get targetRank => text().nullable()();

  /// Giải được nối với mục tiêu Chuẩn bị giải (spec giải đấu §4.3).
  TextColumn get tournamentId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Thành tích — chỉ thêm. Id tính từ (người, loại, refId), nên hai máy ghi
/// cùng một thành tích ra cùng một id (R8).
class AchievementRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// `AchievementKind.name`.
  TextColumn get kind => text()();
  TextColumn get refId => text()();
  DateTimeColumn get achievedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, kind, refId},
  ];
}

// ─── Coach tình huống (spec 2026-10-21 mục 11) ─────────────────────────────

/// Một lần làm tình huống Coach — chỉ thêm, không sửa. Ghi khi tình huống
/// kết thúc (đạt, hiện đáp án, hay chưa đủ dữ liệu). Chỉ lưu câu trả lời của
/// người chơi, không lưu đáp án; không đưa vào điểm thuần thục (Q2).
class CoachAttemptRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// `gen-v1-…` hoặc `lib:{id}`.
  TextColumn get situationKey => text()();

  /// `CoachTopic.name`.
  TextColumn get topic => text()();

  /// `CoachDifficulty.name`.
  TextColumn get difficulty => text()();

  /// JSON, tối đa 3 câu trả lời (coach_converters.dart).
  TextColumn get answers => text()();

  /// `CoachAttemptOutcome.name`.
  TextColumn get outcome => text()();

  /// `CoachFault.name` của lần sai đầu tiên.
  TextColumn get firstFault => text().nullable()();
  IntColumn get scoringVersion => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Coach Chat (spec Giai đoạn B 2026-10-22 mục 8) ────────────────────────

/// Một lượt chat với huấn luyện viên (spec 2026-10-22 mục 8) — chỉ trên máy
/// này, không đồng bộ.
class CoachChatTurnRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get fromPlayer => boolean()();
  TextColumn get message => text()();
  BoolColumn get insufficient => boolean().withDefault(const Constant(false))();
}

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    DrillRows,
    KnowledgeRows,
    DrillLogRows,
    ScheduleSlotRows,
    TimerSessionRows,
    CueEquipmentRows,
    AuthSessionRows,
    PlayerRankRows,
    BuTestRows,
    BuDrillResultRows,
    SkillTestRows,
    PlayerGoalRows,
    AchievementRows,
    PoolMatchRows,
    TournamentRows,
    CoachAttemptRows,
    CoachChatTurnRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Buổi tập v1 không có chủ; chủ sản phẩm chọn bỏ dữ liệu thử
        // thay vì gán bừa cho người đăng nhập đầu tiên.
        await m.deleteTable('drill_log_rows');
        await m.createTable(drillLogRows);
        await m.createTable(authSessionRows);
      }
      if (from < 3) {
        // Chỉ thêm bảng: không đụng dữ liệu cũ (spec mục 6.1).
        await m.createTable(playerRankRows);
        await m.createTable(buTestRows);
        await m.createTable(buDrillResultRows);
      }
      if (from < 4) {
        // Chỉ thêm bảng (spec 2026-10-15 mục 6).
        await m.createTable(playerGoalRows);
        await m.createTable(achievementRows);
      }
      if (from < 5) {
        // Gắn buổi tập tự do và lịch tuần với tài khoản để không lộ
        // dữ liệu cho người đăng nhập sau trên cùng thiết bị.
        await m.addColumn(scheduleSlotRows, scheduleSlotRows.userId);
        await m.addColumn(timerSessionRows, timerSessionRows.userId);
      }
      if (from < 6) {
        await m.createTable(cueEquipmentRows);
      }
      if (from < 7) {
        await m.createTable(poolMatchRows);
      } else if (from < 8) {
        await m.addColumn(poolMatchRows, poolMatchRows.shots);
      }
      if (from < 9) {
        if (from >= 6) {
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.updatedAt);
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.syncedAt);
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.isDeleted);
        }
      }
      if (from < 10) {
        // Bảng tạo mới ở bước trên đã có sẵn các cột này, nên chỉ thêm vào
        // bảng đã tồn tại từ trước.
        if (from >= 6) {
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.shaftBrand);
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.tipBrand);
          await m.addColumn(cueEquipmentRows, cueEquipmentRows.buttBrand);
        }
        if (from >= 7) {
          await m.addColumn(poolMatchRows, poolMatchRows.cueId);
          await m.addColumn(poolMatchRows, poolMatchRows.updatedAt);
          await m.addColumn(poolMatchRows, poolMatchRows.syncedAt);
        }
        await m.addColumn(timerSessionRows, timerSessionRows.syncedAt);
        await m.addColumn(scheduleSlotRows, scheduleSlotRows.updatedAt);
        await m.addColumn(scheduleSlotRows, scheduleSlotRows.syncedAt);
        await m.addColumn(scheduleSlotRows, scheduleSlotRows.isDeleted);
      }
      if (from < 11) {
        // Chỉ thêm bảng (spec Coach mục 11.2): không đụng dữ liệu cũ.
        await m.createTable(coachAttemptRows);
      }
      if (from < 12) {
        // Chỉ thêm bảng (spec Giai đoạn B mục 8): không đụng dữ liệu cũ.
        await m.createTable(coachChatTurnRows);
      }
      if (from >= 2 && from < 13) {
        await m.addColumn(drillLogRows, drillLogRows.durationSec);
      }
      if (from >= 7 && from < 13) {
        // Bảng trận đấu có từ v7; cột xóa mềm thêm ở v13.
        await m.addColumn(poolMatchRows, poolMatchRows.isDeleted);
      }
      if (from >= 4 && from < 14) {
        // Bảng mục tiêu có từ v4; bảng tạo mới ở các bước trên đã có cột này.
        await m.addColumn(playerGoalRows, playerGoalRows.targetRank);
      }
      if (from < 15) {
        // Chỉ thêm bảng (spec Skill Test): không đụng dữ liệu cũ.
        await m.createTable(skillTestRows);
      }
      if (from < 16) {
        // spec giải đấu §4: thêm bảng giải, thêm cột rỗng được; không đụng dữ liệu cũ.
        await m.createTable(tournamentRows);
        if (from >= 7) {
          await m.addColumn(poolMatchRows, poolMatchRows.tournamentId);
          await m.addColumn(poolMatchRows, poolMatchRows.roundLabel);
        }
        if (from >= 4) {
          await m.addColumn(playerGoalRows, playerGoalRows.tournamentId);
        }
      }
    },
  );

  static QueryExecutor _openConnection() {
    // Trên web, drift chạy SQLite bằng WebAssembly trong một worker.
    // Hai file nằm trong web/ và phải khớp phiên bản đang khoá:
    // sqlite3.wasm theo package sqlite3, drift_worker.js theo drift.
    // Đường dẫn tuyệt đối: app dùng URL dạng đường dẫn, tương đối thì
    // mở /training/drills/d1 sẽ đi tìm /training/drills/sqlite3.wasm.
    return driftDatabase(
      name: 'poolcoachai_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('/sqlite3.wasm'),
        driftWorker: Uri.parse('/drift_worker.js'),
      ),
    );
  }

  // ─── DrillLog watch helpers ─────────────────────────────────────────────

  /// Buổi tập của [userId], cũ nhất trước — đúng thứ tự categoryMastery() đòi.
  Stream<List<DrillLogRow>> watchDrillLogsOf(String userId) {
    return (select(drillLogRows)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  /// Buổi tập chưa lên server, của mọi người dùng trên máy — kèm chủ của
  /// từng buổi, để bên đồng bộ chỉ để ý tới người đang đăng nhập.
  Stream<List<({String id, String userId})>> watchPendingLogs() {
    final query = selectOnly(drillLogRows)
      ..addColumns([drillLogRows.id, drillLogRows.userId])
      ..where(drillLogRows.syncedAt.isNull());
    return query
        .map(
          (row) => (
            id: row.read(drillLogRows.id)!,
            userId: row.read(drillLogRows.userId)!,
          ),
        )
        .watch();
  }
}
