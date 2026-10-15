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
  IntColumn get day => integer()();
  TextColumn get time => text()();
  TextColumn get label => text()();
  TextColumn get cat => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Buổi tập tự do đo bằng đồng hồ.
class TimerSessionRows extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSec => integer()();
  TextColumn get cat => text().nullable()();
  TextColumn get cueId => text().nullable()();

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

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  DrillRows,
  KnowledgeRows,
  DrillLogRows,
  ScheduleSlotRows,
  TimerSessionRows,
  AuthSessionRows,
  PlayerRankRows,
  BuTestRows,
  BuDrillResultRows,
  PlayerGoalRows,
  AchievementRows,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

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
        .map((row) => (
              id: row.read(drillLogRows.id)!,
              userId: row.read(drillLogRows.userId)!,
            ))
        .watch();
  }
}
