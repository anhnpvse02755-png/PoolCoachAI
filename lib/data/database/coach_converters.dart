import 'dart:convert';

import 'package:poolcoachai/data/database/database.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _local(Object? s) => s == null ? null : DateTime.parse(s as String).toLocal();

/// Một câu trả lời → JSON, khoá ổn định (spec mục 11.2): `{kind, pocket?,
/// stroke?, power?, spinSide?, spinTips?, outcome, fault?}`. Khoá null không ghi.
Map<String, Object?> coachAnswerToJson(CoachAnswerRecord a) => {
      'kind': a.kind.name,
      if (a.pocket != null) 'pocket': a.pocket!.name,
      if (a.stroke != null) 'stroke': a.stroke!.name,
      if (a.power != null) 'power': a.power,
      if (a.spinSide != null) 'spinSide': a.spinSide!.name,
      if (a.spinTips != null) 'spinTips': a.spinTips,
      'outcome': a.outcome.name,
      if (a.fault != null) 'fault': a.fault!.name,
    };

CoachAnswerRecord coachAnswerFromJson(Map<String, Object?> j) => CoachAnswerRecord(
      kind: CoachAnswerKind.values.byName(j['kind']! as String),
      pocket: j['pocket'] == null ? null : Pocket.values.byName(j['pocket']! as String),
      stroke: j['stroke'] == null ? null : Stroke.values.byName(j['stroke']! as String),
      power: (j['power'] as num?)?.toDouble(),
      spinSide: j['spinSide'] == null ? null : SpinSide.values.byName(j['spinSide']! as String),
      spinTips: (j['spinTips'] as num?)?.toDouble(),
      outcome: CoachOutcome.values.byName(j['outcome']! as String),
      fault: j['fault'] == null ? null : CoachFault.values.byName(j['fault']! as String),
    );

String encodeCoachAnswers(List<CoachAnswerRecord> answers) =>
    jsonEncode([for (final a in answers) coachAnswerToJson(a)]);

List<CoachAnswerRecord> decodeCoachAnswers(String json) => [
      for (final j in jsonDecode(json) as List<Object?>) coachAnswerFromJson(j! as Map<String, Object?>),
    ];

CoachAttempt toCoachAttempt(CoachAttemptRow r) => CoachAttempt(
      id: r.id,
      userId: r.userId,
      situationKey: r.situationKey,
      topic: CoachTopic.values.byName(r.topic),
      difficulty: CoachDifficulty.values.byName(r.difficulty),
      answers: decodeCoachAnswers(r.answers),
      outcome: CoachAttemptOutcome.values.byName(r.outcome),
      firstFault: r.firstFault == null ? null : CoachFault.values.byName(r.firstFault!),
      scoringVersion: r.scoringVersion,
      startedAt: r.startedAt,
      finishedAt: r.finishedAt,
      syncedAt: r.syncedAt,
    );

CoachAttemptRow toCoachAttemptRow(CoachAttempt a) => CoachAttemptRow(
      id: a.id,
      userId: a.userId,
      situationKey: a.situationKey,
      topic: a.topic.name,
      difficulty: a.difficulty.name,
      answers: encodeCoachAnswers(a.answers),
      outcome: a.outcome.name,
      firstFault: a.firstFault?.name,
      scoringVersion: a.scoringVersion,
      startedAt: a.startedAt,
      finishedAt: a.finishedAt,
      syncedAt: a.syncedAt,
    );

const remoteCoachAttemptFields =
    'id,situation_key,topic,difficulty,answers,outcome,first_fault,scoring_version,started_at,finished_at';

/// Dòng cho `POST /items/coach_attempts`. `answers` là JSON thật (cột json).
Map<String, Object?> toRemoteCoachAttempt(CoachAttemptRow r) => {
      'id': r.id,
      'situation_key': r.situationKey,
      'topic': r.topic,
      'difficulty': r.difficulty,
      'answers': jsonDecode(r.answers),
      'outcome': r.outcome,
      'first_fault': r.firstFault,
      'scoring_version': r.scoringVersion,
      'started_at': _iso(r.startedAt),
      'finished_at': _iso(r.finishedAt),
    };

CoachAttemptRow coachAttemptFromRemote(
  Map<String, Object?> j, {
  required String userId,
  required DateTime syncedAt,
}) {
  final answers = j['answers'];
  return CoachAttemptRow(
    id: j['id']! as String,
    userId: userId,
    situationKey: j['situation_key']! as String,
    topic: j['topic']! as String,
    difficulty: j['difficulty']! as String,
    answers: answers is String ? answers : jsonEncode(answers ?? const []),
    outcome: j['outcome']! as String,
    firstFault: j['first_fault'] as String?,
    scoringVersion: (j['scoring_version']! as num).toInt(),
    startedAt: _local(j['started_at'])!,
    finishedAt: _local(j['finished_at'])!,
    syncedAt: syncedAt,
  );
}
