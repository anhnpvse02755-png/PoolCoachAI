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

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  DrillRows,
  KnowledgeRows,
  DrillLogRows,
  ScheduleSlotRows,
  TimerSessionRows,
  AuthSessionRows,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

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
        },
      );

  static QueryExecutor _openConnection() {
    // Trên web, drift chạy SQLite bằng WebAssembly trong một worker.
    // Hai file nằm trong web/ và phải khớp phiên bản đang khoá:
    // sqlite3.wasm theo package sqlite3, drift_worker.js theo drift.
    return driftDatabase(
      name: 'poolcoachai_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
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

  /// Id các buổi tập chưa lên server, của mọi người dùng trên máy.
  Stream<List<String>> watchPendingLogIds() {
    final query = selectOnly(drillLogRows)
      ..addColumns([drillLogRows.id])
      ..where(drillLogRows.syncedAt.isNull());
    return query.map((row) => row.read(drillLogRows.id)!).watch();
  }
}
