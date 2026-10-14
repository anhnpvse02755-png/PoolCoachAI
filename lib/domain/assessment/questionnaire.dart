import 'package:poolcoachai/domain/rank.dart';

/// Số lựa chọn của từng câu Q1…Q8, đúng thứ tự trong spec mục 11.2.
///
/// Q1 7 · Q2 5 · Q3 9 (1…8 và Dọn bàn) · Q4 7 (1…5, 6+, Thường xuyên
/// Runout) · Q5 5 · Q6 8 · Q7 5 · Q8 5.
const questionOptionCounts = <int>[7, 5, 9, 7, 5, 8, 5, 5];

/// Câu trả lời gần nhất của bộ câu hỏi: chỉ số lựa chọn (từ 0) của Q1…Q8.
///
/// Lưu nguyên cả 8 câu, kể cả 5 câu không dùng để tính hạng, để truy được
/// vì sao app gợi ý hạng đó và để Lộ trình dùng sau (spec mục 4.1, 11.2).
final class QuestionnaireAnswers {
  QuestionnaireAnswers(List<int> choices) : choices = List.unmodifiable(choices) {
    if (choices.length != questionOptionCounts.length) {
      throw ArgumentError.value(
          choices, 'choices', 'cần đúng ${questionOptionCounts.length} câu trả lời');
    }
    for (var i = 0; i < choices.length; i++) {
      RangeError.checkValueInInterval(
          choices[i], 0, questionOptionCounts[i] - 1, 'Q${i + 1}');
    }
  }

  factory QuestionnaireAnswers.fromJson(Object? json) {
    if (json is! List) {
      throw FormatException('Câu trả lời phải là mảng JSON', json);
    }
    return QuestionnaireAnswers([for (final c in json) c as int]);
  }

  final List<int> choices;

  /// Lựa chọn của câu [question], đánh số 1…8 như spec.
  int of(int question) => choices[question - 1];

  List<int> toJson() => choices;

  @override
  bool operator ==(Object other) {
    if (other is! QuestionnaireAnswers) return false;
    for (var i = 0; i < choices.length; i++) {
      if (choices[i] != other.choices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(choices);

  @override
  String toString() => 'QuestionnaireAnswers($choices)';
}

// Chỉ số lựa chọn có tên, để hàm dưới đọc được như bảng của spec mục 11.2.
const _q4One = 0;
const _q4Two = 1;
const _q5Never = 0;
const _q5OnceOrTwice = 1;
const _q6TwentyRacks = 3;
const _q6TenRacks = 4;
const _q6FiveRacks = 5;
const _q6TwoThreeRacks = 6;

/// Hạng bộ câu hỏi gợi ý — đúng từng dòng bảng quy đổi spec mục 11.2.
///
/// Chỉ Q4, Q5, Q6 được dùng. A và PRO không bao giờ được gợi ý: chỉ chọn
/// được qua *Chọn hạng khác* (thành tự khai).
Rank suggestRank(QuestionnaireAnswers answers) {
  final q4 = answers.of(4);
  final q5 = answers.of(5);
  final q6 = answers.of(6);
  if (q5 == _q5Never) {
    return switch (q4) {
      _q4One => Rank.k,
      _q4Two => Rank.i,
      _ => Rank.h,
    };
  }
  if (q5 == _q5OnceOrTwice) return Rank.h;
  return switch (q6) {
    _q6TwentyRacks => Rank.f,
    _q6TenRacks => Rank.e,
    _q6FiveRacks => Rank.d,
    _q6TwoThreeRacks => Rank.c,
    > _q6TwoThreeRacks => Rank.b,
    _ => Rank.g,
  };
}
