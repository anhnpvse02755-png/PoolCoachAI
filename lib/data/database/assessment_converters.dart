import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/assessment/bu_placement.dart';
import 'package:poolcoachai/domain/assessment/bu_test.dart';
import 'package:poolcoachai/domain/assessment/drill_attempts.dart';
import 'package:poolcoachai/domain/assessment/player_rank.dart';
import 'package:poolcoachai/domain/assessment/questionnaire.dart';
import 'package:poolcoachai/domain/rank.dart';

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
    DrillAttempts.fromJson(jsonDecode(r.attempts));
