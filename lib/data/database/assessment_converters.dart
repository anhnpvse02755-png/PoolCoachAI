import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/data/remote/codecs/assessment_codecs.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

export 'package:poolcoachai/data/remote/codecs/remote_fields.dart'
    show remoteResultFields, remoteTestFields;

// Tên enum lạ thì byName ném — hàng hỏng phải ồn ào ngay lúc đọc, như
// _parseCategory của converters.dart.

Rank? _rank(String? name) => name == null ? null : Rank.values.byName(name);

PlayerRank toPlayerRank(PlayerRankRow r) => PlayerRank(
      rank: _rank(r.rank),
      source: r.source == null ? null : RankSource.values.byName(r.source!),
      buScore: r.buScore,
      testId: r.testId,
      warningRank: _rank(r.warningRank),
      warningTestId: r.warningTestId,
      answers: r.questionnaireAnswers == null
          ? null
          : QuestionnaireAnswers.fromJson(jsonDecode(r.questionnaireAnswers!)),
      onboardingState: OnboardingState.values.byName(r.onboardingState),
      updatedAt: r.updatedAt,
    );

/// Mọi cột đều đặt rõ, kể cả null: ghi đè dòng cũ thì cột vắng mặt sẽ giữ
/// giá trị cũ — `syncedAt` cũ còn đó là dòng mới bị coi như đã đồng bộ.
PlayerRankRowsCompanion toPlayerRankRow(PlayerRank p,
        {required String userId, DateTime? syncedAt}) =>
    PlayerRankRowsCompanion(
      userId: drift.Value(userId),
      rank: drift.Value(p.rank?.name),
      source: drift.Value(p.source?.name),
      buScore: drift.Value(p.buScore),
      testId: drift.Value(p.testId),
      warningRank: drift.Value(p.warningRank?.name),
      warningTestId: drift.Value(p.warningTestId),
      questionnaireAnswers:
          drift.Value(p.answers == null ? null : jsonEncode(p.answers!.toJson())),
      onboardingState: drift.Value(p.onboardingState.name),
      updatedAt: drift.Value(p.updatedAt),
      syncedAt: drift.Value(syncedAt),
    );

BuTest toBuTest(BuTestRow r) => BuTest(
      id: r.id,
      startedAt: r.startedAt,
      tableSize: TableSize.values.byName(r.tableSize),
      completedAt: r.completedAt,
      cancelledAt: r.cancelledAt,
      examIScore: r.examIScore,
      examIIVersion:
          r.examIIVersion == null ? null : ExamIIVersion.values.byName(r.examIIVersion!),
      examIIScore: r.examIIScore,
      totalScore: r.totalScore,
      resultRank: _rank(r.resultRank),
    );

DrillAttempts attemptsOfRow(BuDrillResultRow r) =>
    drillAttemptsFromJson(r.attempts);

// ─── Directus (spec mục 6.2; tên collection theo D9 của kế hoạch) ─────────
//
// Không gửi chủ: server tự điền `user_created` từ token, như drill_logs.

const remoteRankFields = 'id,rank,source,bu_score,test_id,warning_rank,'
    'warning_test_id,questionnaire_answers,onboarding_state,updated_at';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _local(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();

/// Dòng hạng cho `POST /items/player_ranks` (id là id người dùng).
Map<String, Object?> toRemoteRank(PlayerRankRow r) => {
      'id': r.userId,
      'rank': r.rank,
      'source': r.source,
      'bu_score': r.buScore,
      'test_id': r.testId,
      'warning_rank': r.warningRank,
      'warning_test_id': r.warningTestId,
      'questionnaire_answers':
          r.questionnaireAnswers == null ? null : jsonDecode(r.questionnaireAnswers!),
      'onboarding_state': r.onboardingState,
      'updated_at': _iso(r.updatedAt),
    };

PlayerRank rankFromRemote(Map<String, Object?> j) => PlayerRank(
      rank: _rank(j['rank'] as String?),
      source: j['source'] == null ? null : RankSource.values.byName(j['source']! as String),
      buScore: j['bu_score'] as int?,
      testId: j['test_id'] as String?,
      warningRank: _rank(j['warning_rank'] as String?),
      warningTestId: j['warning_test_id'] as String?,
      answers: j['questionnaire_answers'] == null
          ? null
          : QuestionnaireAnswers.fromJson(j['questionnaire_answers']),
      onboardingState: OnboardingState.values.byName(j['onboarding_state']! as String),
      updatedAt: _local(j['updated_at'])!,
    );

Map<String, Object?> toRemoteTest(BuTestRow r) => {
      'id': r.id,
      'started_at': _iso(r.startedAt),
      'completed_at': _iso(r.completedAt),
      'cancelled_at': _iso(r.cancelledAt),
      'table_size': r.tableSize,
      'exam_i_score': r.examIScore,
      'exam_ii_version': r.examIIVersion,
      'exam_ii_score': r.examIIScore,
      'total_score': r.totalScore,
      'result_rank': r.resultRank,
    };

BuTestRowsCompanion fromRemoteTest(Map<String, Object?> j,
        {required String userId, required DateTime syncedAt}) =>
    BuTestRowsCompanion.insert(
      id: j['id']! as String,
      userId: userId,
      startedAt: _local(j['started_at'])!,
      tableSize: j['table_size']! as String,
      completedAt: drift.Value(_local(j['completed_at'])),
      cancelledAt: drift.Value(_local(j['cancelled_at'])),
      examIScore: drift.Value(j['exam_i_score'] as int?),
      examIIVersion: drift.Value(j['exam_ii_version'] as String?),
      examIIScore: drift.Value(j['exam_ii_score'] as int?),
      totalScore: drift.Value(j['total_score'] as int?),
      resultRank: drift.Value(j['result_rank'] as String?),
      syncedAt: drift.Value(syncedAt),
    );

Map<String, Object?> toRemoteResult(BuDrillResultRow r) => {
      'id': r.id,
      'test_id': r.testId,
      'drill_id': r.drillId,
      'attempts': jsonDecode(r.attempts),
      'score': r.score,
      'recorded_at': _iso(r.recordedAt),
    };

BuDrillResultRowsCompanion fromRemoteResult(Map<String, Object?> j,
    {required DateTime syncedAt}) {
  final r = buDrillResultFromRemote(j);
  return BuDrillResultRowsCompanion.insert(
    id: r.id,
    testId: r.testId,
    drillId: r.drillId,
    attempts: r.attemptsJson,
    score: drift.Value(r.score),
    recordedAt: r.recordedAt,
    syncedAt: drift.Value(syncedAt),
  );
}
