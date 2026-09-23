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

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  DrillRows,
  KnowledgeRows,
  DrillLogRows,
  ScheduleSlotRows,
  TimerSessionRows,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        // schemaVersion 1: no migrations needed yet
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'poolcoachai_db');
  }

  // ─── DrillLog watch helpers ─────────────────────────────────────────────

  /// Trả log cũ nhất trước — đúng thứ tự categoryMastery() đòi.
  Stream<List<DrillLogRow>> watchAllDrillLogs() {
    return (select(drillLogRows)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }
}
