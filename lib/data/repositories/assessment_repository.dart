import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:poolcoachai/data/database/assessment_converters.dart';
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_exams.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/assessment/rank_rules.dart';
import 'package:poolcoachai/domain/assessment/retest_gate.dart';
import 'package:poolcoachai/domain/rank.dart';

sealed class StartOutcome {
  const StartOutcome();
}

final class TestStarted extends StartOutcome {
  const TestStarted(this.testId);
  final String testId;
}

final class TestAlreadyActive extends StartOutcome {
  const TestAlreadyActive(this.testId);
  final String testId;
}

final class RetestTooSoon extends StartOutcome {
  const RetestTooSoon(this.from);
  final DateTime from;
}

sealed class CompleteOutcome {
  const CompleteOutcome();
}

final class TestCompleted extends CompleteOutcome {
  const TestCompleted({
    required this.outcome,
    required this.result,
    required this.total,
    required this.before,
  });
  final RankOutcome outcome;
  final Rank result;
  final int total;
  final Rank? before;
}

final class CompletionTooSoon extends CompleteOutcome {
  const CompletionTooSoon(this.from);
  final DateTime from;
}

/// Hạng và bài kiểm tra BU của một người chơi trên máy này.
///
/// Mọi thứ ghi xuống Drift trước, đồng bộ sau (spec mục 8). Lần kiểm tra
/// chưa hoàn tất không bao giờ chạm vào hạng (spec mục 6.1).
class AssessmentRepository {
  AssessmentRepository(
    this._db, {
    required this._userId,
    required this._now,
    required this._newId,
  });

  final AppDatabase _db;
  final String _userId;
  final DateTime Function() _now;
  final String Function() _newId;

  // ─── Hạng ──────────────────────────────────────────────────────────────

  SimpleSelectStatement<$PlayerRankRowsTable, PlayerRankRow> _rankQuery() =>
      _db.select(_db.playerRankRows)..where((t) => t.userId.equals(_userId));

  Stream<PlayerRank?> watchRank() =>
      _rankQuery().watchSingleOrNull().map((r) => r == null ? null : toPlayerRank(r));

  Future<PlayerRank?> _rank() async {
    final r = await _rankQuery().getSingleOrNull();
    return r == null ? null : toPlayerRank(r);
  }

  /// Ghi với `syncedAt` rỗng; bên đồng bộ tự thấy và đẩy lên.
  Future<void> _writeRank(PlayerRank rank) => _db
      .into(_db.playerRankRows)
      .insertOnConflictUpdate(toPlayerRankRow(rank, userId: _userId));

  Future<void> saveQuestionnaire({
    required Rank chosen,
    required Rank suggested,
    required QuestionnaireAnswers answers,
  }) =>
      _db.transaction(() async {
        await _writeRank(rankFromQuestionnaire(await _rank(),
            chosen: chosen, suggested: suggested, answers: answers, now: _now()));
      });

  Future<void> skipOnboarding() => _db.transaction(() async {
        final current = await _rank();
        final next = rankAfterSkip(current, _now());
        if (!identical(next, current)) await _writeRank(next);
      });

  // ─── Bài kiểm tra ──────────────────────────────────────────────────────

  Stream<List<BuTest>> watchTests() => (_db.select(_db.buTestRows)
        ..where((t) => t.userId.equals(_userId))
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch()
      .map((rows) => rows.map(toBuTest).toList());

  Future<List<BuTest>> _tests() async =>
      (await (_db.select(_db.buTestRows)..where((t) => t.userId.equals(_userId))).get())
          .map(toBuTest)
          .toList();

  /// Một lần kiểm tra cùng mọi dòng kết quả của nó: một truy vấn nối hai
  /// bảng, nên ghi vào bảng nào thì stream cũng bắn lại.
  JoinedSelectStatement<HasResultSet, dynamic> _snapshotQuery(
          Expression<bool> Function($BuTestRowsTable t) filter) =>
      _db.select(_db.buTestRows).join([
        leftOuterJoin(_db.buDrillResultRows,
            _db.buDrillResultRows.testId.equalsExp(_db.buTestRows.id)),
      ])
        ..where(_db.buTestRows.userId.equals(_userId) & filter(_db.buTestRows));

  TestSnapshot? _toSnapshot(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    final test = rows.first.readTable(_db.buTestRows);
    final results = [
      for (final r in rows)
        ?r.readTableOrNull(_db.buDrillResultRows),
    ];
    return TestSnapshot(
      test: toBuTest(test),
      attempts: {for (final r in results) r.drillId: attemptsOfRow(r)},
      touched: {for (final r in results) r.drillId: r.recordedAt},
    );
  }

  /// Lần đang làm (chưa hoàn tất, chưa hủy) — mỗi người tối đa một lần.
  Stream<TestSnapshot?> watchActiveTest() => _snapshotQuery(
          (t) => t.completedAt.isNull() & t.cancelledAt.isNull())
      .watch()
      .map(_toSnapshot);

  Stream<TestSnapshot?> watchTest(String testId) =>
      _snapshotQuery((t) => t.id.equals(testId)).watch().map(_toSnapshot);

  /// Đọc một lần bằng `get()` — chạy được trong transaction, không như stream.
  Future<TestSnapshot> _snapshot(String testId) async {
    final snap =
        _toSnapshot(await _snapshotQuery((t) => t.id.equals(testId)).get());
    if (snap == null) throw StateError('Không có lần kiểm tra $testId');
    return snap;
  }

  Future<StartOutcome> startTest(TableSize size) => _db.transaction(() async {
        final tests = await _tests();
        for (final t in tests) {
          if (t.isActive) return TestAlreadyActive(t.id);
        }
        final from = retestAvailableFrom(tests);
        if (from != null && _now().isBefore(from)) return RetestTooSoon(from);
        final id = _newId();
        await _db.into(_db.buTestRows).insert(BuTestRowsCompanion.insert(
              id: id,
              userId: _userId,
              startedAt: _now(),
              tableSize: size.name,
            ));
        return TestStarted(id);
      });

  Future<void> _writeAttempts(TestSnapshot snap, BuDrill drill, DrillAttempts attempts) async {
    final existing = await (_db.select(_db.buDrillResultRows)
          ..where((r) => r.testId.equals(snap.test.id) & r.drillId.equals(drill.id)))
        .getSingleOrNull();
    await _db.into(_db.buDrillResultRows).insertOnConflictUpdate(BuDrillResultRowsCompanion(
          id: Value(existing?.id ?? _newId()),
          testId: Value(snap.test.id),
          drillId: Value(drill.id),
          attempts: Value(jsonEncode(attempts.toJson())),
          score: Value(drillScore(drill, attempts)),
          recordedAt: Value(_now()),
          syncedAt: const Value(null),
        ));
  }

  /// Ghi toàn bộ kết quả thô hiện tại của một bài — gọi sau **mỗi** cú.
  Future<void> recordAttempts(String testId, String drillId, DrillAttempts attempts) =>
      _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.isEditable(drillId)) {
          throw StateError('Bài $drillId của lần $testId không còn sửa được');
        }
        final drill = drillFor(drillId, snap.test.examIIVersion);
        if (!attemptsValid(drill, attempts)) {
          throw ArgumentError.value(attempts, 'attempts', 'không hợp lệ cho $drillId');
        }
        await _writeAttempts(snap, drill, attempts);
      });

  /// Bỏ cú nhập gần nhất trong đề chưa khoá. Trả mã bài vừa hoàn tác, hoặc
  /// null khi không còn gì để hoàn tác. Hoà giờ thì bài đứng sau thắng.
  Future<String?> undoLastShot(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        final order = [
          ...examIDrills,
          if (snap.test.examIIVersion != null) ...examIIDrills(snap.test.examIIVersion!),
        ];
        BuDrill? last;
        for (final d in order) {
          final a = snap.attempts[d.id];
          if (a == null || a.isEmpty || !snap.isEditable(d.id)) continue;
          if (last == null || !snap.touched[d.id]!.isBefore(snap.touched[last.id]!)) last = d;
        }
        if (last == null) return null;
        await _writeAttempts(snap, last, snap.attempts[last.id]!.withoutLast());
        return last.id;
      });

  /// Chốt Đề I: điểm Đề I và bản Đề II (spec mục 5.4).
  Future<ExamIIVersion> finishExamI(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.examIReady) throw StateError('Đề I chưa đủ bài');
        final score = snap.scoreOf(examIDrills);
        final version = placeExamII(score, snap.test.tableSize);
        await (_db.update(_db.buTestRows)..where((t) => t.id.equals(testId)))
            .write(BuTestRowsCompanion(
          examIScore: Value(score),
          examIIVersion: Value(version.name),
        ));
        return version;
      });

  /// Hoàn tất: chỉ lúc này hạng mới đổi (spec mục 4.2, 5.4).
  Future<CompleteOutcome> completeTest(String testId) => _db.transaction(() async {
        final snap = await _snapshot(testId);
        if (!snap.examIIReady) throw StateError('Đề II chưa đủ bài');
        final from = retestAvailableFrom(await _tests(), exceptTestId: testId);
        if (from != null && _now().isBefore(from)) return CompletionTooSoon(from);

        final examII = snap.scoreOf(examIIDrills(snap.test.examIIVersion!));
        final total = snap.test.examIScore! + examII;
        final result = rankForBuScore(total);
        final current = await _rank();
        final change =
            applyTestResult(current, result: result, buScore: total, testId: testId, now: _now());

        await (_db.update(_db.buTestRows)..where((t) => t.id.equals(testId)))
            .write(BuTestRowsCompanion(
          examIIScore: Value(examII),
          totalScore: Value(total),
          resultRank: Value(result.name),
          completedAt: Value(_now()),
          syncedAt: const Value(null),
        ));
        await _writeRank(change.rank);
        return TestCompleted(
            outcome: change.outcome, result: result, total: total, before: current?.rank);
      });

  /// Hủy lần đang làm. Lần bị hủy không tính giãn cách 14 ngày.
  Future<void> cancelTest(String testId) =>
      (_db.update(_db.buTestRows)
            ..where((t) =>
                t.id.equals(testId) &
                t.userId.equals(_userId) &
                t.completedAt.isNull() &
                t.cancelledAt.isNull()))
          .write(BuTestRowsCompanion(cancelledAt: Value(_now())));
}
