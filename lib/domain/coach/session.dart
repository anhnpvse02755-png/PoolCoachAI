import 'package:poolcoachai/domain/coach/answer.dart';
import 'package:poolcoachai/domain/coach/attempt.dart';
import 'package:poolcoachai/domain/coach/coach_constants.dart';
import 'package:poolcoachai/domain/coach/situation.dart';
import 'package:poolcoachai/domain/coach/verdict.dart';

/// Kết quả khi người chơi bấm Chấm (spec mục 4.2).
enum SubmitCheck {
  /// Chấm được.
  ok,

  /// Đúng cú vừa sai: không tính lần thử, nhắc đổi một thông số.
  sameAsLast,

  /// Tình huống đã kết thúc.
  ended,
}

/// Một lần làm tình huống, từ lúc mở tới lúc kết thúc (spec mục 4.2, Q1, Q4).
///
/// Thuần, không phụ thuộc giao diện: chuỗi sai 1 → gợi ý 1 → sai 2 → gợi ý 2
/// → sai 3 → đáp án, "Xem đáp án" sớm, câu trả lời lặp lại và kết luận chưa
/// đủ dữ liệu đều đi qua đây.
class CoachSession {
  CoachSession(this.situation, {required this.startedAt});

  final CoachSituation situation;
  final DateTime startedAt;

  final _answers = <CoachAnswer>[];
  final _verdicts = <CoachVerdict>[];
  bool _revealedEarly = false;

  List<CoachAnswer> get answers => List.unmodifiable(_answers);
  List<CoachVerdict> get verdicts => List.unmodifiable(_verdicts);

  /// Số lần thử đã tính (bỏ lần chưa đủ dữ liệu).
  int get tries => _verdicts.where((v) => v.counts).length;

  int get wrongs => _verdicts.where((v) => v.outcome == CoachOutcome.wrong).length;

  CoachVerdict? get lastVerdict => _verdicts.lastOrNull;

  /// Đã đạt.
  bool get solved => _verdicts.any((v) => v.passed);

  /// Kết luận "chưa đủ dữ liệu" ăn hay thủ: lần làm kết thúc, không tính (Q4).
  bool get undecidedEnd =>
      _verdicts.any((v) => v.undecided == CoachUndecidedReason.potVsSafety);

  /// Hiện đáp án: sai đủ [coachMaxAnswers] lần hay bấm "Xem đáp án".
  bool get revealed => _revealedEarly || wrongs >= coachMaxAnswers;
  bool get revealedEarly => _revealedEarly;
  bool get ended => solved || revealed || undecidedEnd;

  /// Mức gợi ý đang hiện: 0, 1 hay 2 (bằng số lần sai, tới khi hiện đáp án).
  int get hintLevel => revealed || solved ? 0 : wrongs.clamp(0, 2);

  /// Lần thử kế tiếp là lần thứ mấy (cho dòng "Lần thử k/3").
  int get nextTry => (tries + 1).clamp(1, coachMaxAnswers);

  /// Có chấm được [answer] không.
  SubmitCheck check(CoachAnswer answer) {
    if (ended) return SubmitCheck.ended;
    final last = _verdicts.lastOrNull;
    if (last != null && last.outcome == CoachOutcome.wrong && _answers.last == answer) {
      return SubmitCheck.sameAsLast;
    }
    return SubmitCheck.ok;
  }

  /// Ghi câu trả lời [answer] và kết luận của nó.
  void record(CoachAnswer answer, CoachVerdict verdict) {
    if (ended) return;
    _answers.add(answer);
    _verdicts.add(verdict);
  }

  /// "Xem đáp án" trước khi sai đủ: tính là chưa tự giải.
  void revealEarly() {
    if (!ended) _revealedEarly = true;
  }

  CoachAttemptOutcome get outcome {
    if (solved) {
      return switch (tries) {
        1 => CoachAttemptOutcome.solved1,
        2 => CoachAttemptOutcome.solved2,
        _ => CoachAttemptOutcome.solved3,
      };
    }
    if (undecidedEnd) return CoachAttemptOutcome.undecided;
    if (_revealedEarly) return CoachAttemptOutcome.revealedEarly;
    return CoachAttemptOutcome.revealed;
  }

  /// Bản ghi lần làm khi đã kết thúc; null khi chưa (rời màn giữa chừng thì
  /// không ghi, spec mục 11.2).
  CoachAttempt? toAttempt({required String id, required String userId, required DateTime finishedAt}) {
    if (!ended) return null;
    return CoachAttempt(
      id: id,
      userId: userId,
      situationKey: situation.key,
      topic: situation.topic,
      difficulty: situation.difficulty,
      answers: [for (var i = 0; i < _answers.length; i++) answerRecord(_answers[i], _verdicts[i])],
      outcome: outcome,
      firstFault: _verdicts.where((v) => v.outcome == CoachOutcome.wrong).firstOrNull?.fault,
      scoringVersion: coachScoringVersion,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

/// Câu trả lời đã chấm, dạng lưu được.
CoachAnswerRecord answerRecord(CoachAnswer a, CoachVerdict v) => switch (a) {
      PotAnswer() => CoachAnswerRecord(
          kind: CoachAnswerKind.pot,
          pocket: a.pocket,
          stroke: a.stroke,
          power: a.power,
          spinSide: a.spin.side,
          spinTips: a.spin.isNone ? null : a.spin.tips,
          outcome: v.outcome,
          fault: v.fault,
        ),
      SafetyAnswer() => CoachAnswerRecord(kind: CoachAnswerKind.safety, outcome: v.outcome, fault: v.fault),
    };
