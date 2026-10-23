import 'package:poolcoachai/domain/coach/coach_context.dart';

// Lọc sau câu trả lời của Coach Chat (spec Giai đoạn B, luật R1, R3–R6).
// Pure Dart — không import Flutter.

/// Lý do Coach Chat chặn một câu trả lời.
enum CoachBlockRule { empty, degree, aimShift, optimal, spinRatio, unknownNumber }

/// Từ chỉ số lượng: một con số 0–10 đứng trước từ này không bị chặn (luật R6).
const coachChatCountWords = <String>[
  'nhóm',
  'câu',
  'cách',
  'điều',
  'ý',
  'việc',
  'kỹ năng',
  'mẹo',
  'gợi ý',
];

final _degreePattern = RegExp(r'\d+(?:[.,]\d+)?\s*độ(?!\p{L})', unicode: true, caseSensitive: false);
final _aimShiftPattern = RegExp(r'ngắm\s+(lệch|dày hơn|mỏng hơn)');
final _spinRatioPattern = RegExp(r'\b(BHE|FHE)\b', caseSensitive: false);

/// Một chuỗi số: số nghìn phân cách bằng dấu chấm, hoặc số thường (thập phân
/// dấu chấm hoặc dấu phẩy).
final _numberTokenPattern = RegExp(r'[1-9]\d{0,2}(?:\.\d{3})+(?!\d|[.,]\d)|\d+(?:[.,]\d+)?');
final _thousandsPattern = RegExp(r'^[1-9]\d{0,2}(?:\.\d{3})+$');
final _gameNamePattern = RegExp(r'(?<![\d.,])(?:8|9|10) bi(?!\p{L})', unicode: true);
final _letterPattern = RegExp(r'^\p{L}$', unicode: true);

/// Mẫu cấm chung của mọi câu Coach (Giai đoạn A và chat): số độ, ngắm lệch,
/// "tối ưu". Không cần facts — dùng cho cả câu Giai đoạn A và từng dòng chat.
CoachBlockRule? coachBannedRule(String line) {
  if (line.contains('°') || _degreePattern.hasMatch(line)) return CoachBlockRule.degree;
  final lower = line.toLowerCase();
  if (_aimShiftPattern.hasMatch(lower) || lower.contains('lệch điểm ngắm')) {
    return CoachBlockRule.aimShift;
  }
  if (lower.contains('tối ưu')) return CoachBlockRule.optimal;
  return null;
}

/// Mọi số (giá trị × 1000, làm tròn) mà câu trả lời được phép nhắc tới: số
/// nằm trong facts, số bên trong chuỗi của facts, và mastery/100 (luật R1).
Set<int> coachAllowedNumbers(Map<String, Object?> facts) {
  final allowed = <int>{};

  void visit(Object? value, {String? key}) {
    if (value is num) {
      allowed.add((value * 1000).round());
      if (key == 'mastery' && value is int) {
        allowed.add(((value / 100) * 1000).round());
      }
    } else if (value is String) {
      for (final m in _numberTokenPattern.allMatches(value)) {
        allowed.add(_scaledNumberOf(m.group(0)!));
      }
    } else if (value is Map) {
      value.forEach((k, v) => visit(v, key: k is String ? k : null));
    } else if (value is Iterable) {
      for (final item in value) {
        visit(item);
      }
    }
  }

  visit(facts);
  return allowed;
}

int _scaledNumberOf(String token) {
  if (_thousandsPattern.hasMatch(token)) {
    return int.parse(token.replaceAll('.', '')) * 1000;
  }
  final value = double.parse(token.replaceAll(',', '.'));
  return (value * 1000).round();
}

bool _isLetter(String ch) => _letterPattern.hasMatch(ch);

bool _followedByCountWord(String rest) {
  final candidates = <String>{rest};
  if (rest.startsWith(' ')) candidates.add(rest.substring(1));
  for (final candidate in candidates) {
    for (final word in coachChatCountWords) {
      if (!candidate.startsWith(word)) continue;
      final next = word.length;
      if (next >= candidate.length || !_isLetter(candidate[next])) return true;
    }
  }
  return false;
}

bool _passesCountException(String rest, int scaled) {
  if (scaled < 0 || scaled > 10000 || scaled % 1000 != 0) return false;
  if (rest.startsWith('%')) return false;
  return _followedByCountWord(rest);
}

CoachBlockRule? _unknownNumberRule(String raw, Map<String, Object?> facts) {
  final cleaned = raw.replaceAll(_gameNamePattern, '');
  final allowed = coachAllowedNumbers(facts);
  for (final m in _numberTokenPattern.allMatches(cleaned)) {
    final scaled = _scaledNumberOf(m.group(0)!);
    if (allowed.contains(scaled)) continue;
    if (_passesCountException(cleaned.substring(m.end), scaled)) continue;
    return CoachBlockRule.unknownNumber;
  }
  return null;
}

/// Lý do chặn một câu trả lời Coach Chat, hoặc `null` nếu cho qua.
CoachBlockRule? coachReplyBlock(String raw, Map<String, Object?> facts) {
  if (raw.trim().isEmpty) return CoachBlockRule.empty;
  final banned = coachBannedRule(raw);
  if (banned != null) return banned;
  if (_spinRatioPattern.hasMatch(raw)) return CoachBlockRule.spinRatio;
  return _unknownNumberRule(raw, facts);
}

/// Lọc câu trả lời Coach Chat: bị chặn thì trả rỗng và `insufficient: true`
/// (luật R5); không thì trả nguyên câu, chỉ bỏ khoảng trắng hai đầu.
CoachChatReply filterCoachReply(String raw, Map<String, Object?> facts) {
  if (coachReplyBlock(raw, facts) != null) return (text: '', insufficient: true);
  return (text: raw.trim(), insufficient: false);
}
