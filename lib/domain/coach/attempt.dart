import 'package:poolcoachai/domain/coach/coach_topic.dart';
import 'package:poolcoachai/domain/coach/difficulty.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';
import 'package:poolcoachai/domain/table_geometry/stroke.dart';
import 'package:poolcoachai/domain/table_geometry/table_spec.dart';

/// Kết quả của cả lần làm tình huống (spec mục 11.2).
enum CoachAttemptOutcome {
  /// Đạt ở lần trả lời thứ 1 / 2 / 3, không xem đáp án.
  solved1,
  solved2,
  solved3,

  /// Sai đủ [coachMaxAnswers] lần, đáp án tự hiện.
  revealed,

  /// Bấm "Xem đáp án" trước khi sai đủ.
  revealedEarly,

  /// Chưa đủ dữ liệu để chấm (spec mục 6.6).
  undecided,
}

extension CoachAttemptOutcomeX on CoachAttemptOutcome {
  /// Tự giải được, không xem đáp án.
  bool get solved =>
      this == CoachAttemptOutcome.solved1 ||
      this == CoachAttemptOutcome.solved2 ||
      this == CoachAttemptOutcome.solved3;
}

enum CoachAnswerKind { pot, safety }

/// Một câu trả lời đã chấm, dạng lưu được (spec mục 11.2, cột `answers`).
final class CoachAnswerRecord {
  const CoachAnswerRecord({
    required this.kind,
    this.pocket,
    this.stroke,
    this.power,
    this.spinSide,
    this.spinTips,
    required this.outcome,
    this.fault,
  });

  final CoachAnswerKind kind;
  final Pocket? pocket;
  final Stroke? stroke;
  final double? power;
  final SpinSide? spinSide;
  final double? spinTips;
  final CoachOutcome outcome;
  final CoachFault? fault;

  @override
  bool operator ==(Object other) =>
      other is CoachAnswerRecord &&
      other.kind == kind &&
      other.pocket == pocket &&
      other.stroke == stroke &&
      other.power == power &&
      other.spinSide == spinSide &&
      other.spinTips == spinTips &&
      other.outcome == outcome &&
      other.fault == fault;

  @override
  int get hashCode =>
      Object.hash(kind, pocket, stroke, power, spinSide, spinTips, outcome, fault);
}

/// Bản ghi một lần làm tình huống, chỉ thêm, không sửa (spec mục 11.2).
/// Chỉ lưu câu trả lời của người chơi, không lưu đáp án.
final class CoachAttempt {
  const CoachAttempt({
    required this.id,
    required this.userId,
    required this.situationKey,
    required this.topic,
    required this.difficulty,
    required this.answers,
    required this.outcome,
    this.firstFault,
    required this.scoringVersion,
    required this.startedAt,
    required this.finishedAt,
    this.syncedAt,
  });

  final String id;
  final String userId;
  final String situationKey;
  final CoachTopic topic;
  final CoachDifficulty difficulty;
  final List<CoachAnswerRecord> answers;
  final CoachAttemptOutcome outcome;

  /// Lỗi của lần sai đầu tiên.
  final CoachFault? firstFault;
  final int scoringVersion;
  final DateTime startedAt;
  final DateTime finishedAt;
  final DateTime? syncedAt;
}
