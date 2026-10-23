import 'package:poolcoachai/domain/coach/coach_context.dart';

// Lọc sau câu trả lời của Coach Chat (spec Giai đoạn B, luật R1, R3–R6).
// Pure Dart — không import Flutter.

/// Lý do Coach Chat chặn một câu trả lời.
enum CoachBlockRule { empty, decomposed, degree, aimShift, optimal, spinRatio, unknownNumber }

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

/// Số chữ số tối đa của một token số; token dài hơn không bao giờ hợp lệ
/// (chặn thẳng, không cố `parse`) — fix round 1, mục 4.
const _maxTokenDigits = 15;

final _degreePattern = RegExp(r'\d+(?:[.,]\d+)?\s*độ(?!\p{L})', unicode: true, caseSensitive: false);

/// Số viết bằng chữ ngay trước "độ" — fix round 1, mục 1. Để nguyên theo
/// đúng ruling của controller (không thêm biên từ ở đầu).
final _numeralDegreePattern = RegExp(
  r'(?:một|hai|ba|bốn|tư|năm|lăm|sáu|bảy|tám|chín|mười|mươi|trăm|rưỡi)\s+độ(?!\p{L})',
  unicode: true,
  caseSensitive: false,
);

/// Từ chỉ số không mơ hồ (chỉ dùng để đọc số, không có nghĩa khác) — fix
/// round 1, mục 1. một/hai/ba/năm… vẫn được phép vì còn nghĩa khác.
final _numeralWordPattern = RegExp(
  r'(?<!\p{L})(?:mười|mươi|trăm|nghìn|ngàn|triệu|chục|lăm)(?!\p{L})',
  unicode: true,
  caseSensitive: false,
);

final _aimShiftPattern = RegExp(r'ngắm\s+(lệch|dày hơn|mỏng hơn)');
final _spinRatioPattern = RegExp(r'\b(BHE|FHE)\b', caseSensitive: false);

/// Chữ Unicode tổ hợp sẵn (NFD, các dấu tổ hợp U+0300–U+036F) — fix round 1,
/// mục 3. Dart không có bộ chuẩn hoá NFC nên chặn thẳng thay vì cố so khớp
/// chữ đã tổ hợp sẵn với mẫu cấm viết ở dạng NFC.
final _decomposedPattern = RegExp('[̀-ͯ]');

/// Một chuỗi số: số nghìn phân cách bằng dấu chấm, hoặc số thường (thập phân
/// dấu chấm hoặc dấu phẩy).
final _numberTokenPattern = RegExp(r'[1-9]\d{0,2}(?:\.\d{3})+(?!\d|[.,]\d)|\d+(?:[.,]\d+)?');
final _thousandsPattern = RegExp(r'^[1-9]\d{0,2}(?:\.\d{3})+$');
final _letterPattern = RegExp(r'^\p{L}$', unicode: true);
final _separatorPattern = RegExp('[.,]');

/// Chỉ xoá "N bi" khi có ngữ cảnh ván đấu đứng trước (trực tiếp hoặc qua một
/// chuỗi "N bi và/hay N bi") — fix round 1, mục 2. Không có ngữ cảnh thì số
/// phải qua kiểm tra như mọi số khác, để không ẩn số bịa (ví dụ "ăn 10 bi").
final _gameContextChainPattern = RegExp(
  r'(?:luật|pool|ván|trận|giải|chơi|kiểu|môn|loại|bàn)\s+'
  r'(?:(?<![\d.,])(?:8|9|10) bi(?!\p{L})\s+(?:và|hay)\s+)*'
  r'(?<![\d.,])(?:8|9|10) bi(?!\p{L})',
  unicode: true,
);

/// Mẫu cấm chung của mọi câu Coach (Giai đoạn A và chat): số độ (kể cả ký
/// hiệu º/˚ và số viết bằng chữ), ngắm lệch, "tối ưu". Không cần facts —
/// dùng cho cả câu Giai đoạn A và từng dòng chat.
CoachBlockRule? coachBannedRule(String line) {
  if (_hasDegreeSign(line) || _degreePattern.hasMatch(line) || _numeralDegreePattern.hasMatch(line)) {
    return CoachBlockRule.degree;
  }
  final lower = line.toLowerCase();
  if (_aimShiftPattern.hasMatch(lower) || lower.contains('lệch điểm ngắm')) {
    return CoachBlockRule.aimShift;
  }
  if (lower.contains('tối ưu')) return CoachBlockRule.optimal;
  return null;
}

bool _hasDegreeSign(String line) => line.contains('°') || line.contains('º') || line.contains('˚');

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
        final scaled = _scaledNumberOf(m.group(0)!);
        if (scaled != null) allowed.add(scaled);
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

/// Giá trị × 1000, làm tròn, của một token số; `null` nếu token quá dài để
/// parse an toàn — fix round 1, mục 4 (không bao giờ ném lỗi).
int? _scaledNumberOf(String token) {
  if (token.replaceAll(_separatorPattern, '').length > _maxTokenDigits) return null;
  if (_thousandsPattern.hasMatch(token)) {
    final value = int.tryParse(token.replaceAll('.', ''));
    return value == null ? null : value * 1000;
  }
  final value = double.tryParse(token.replaceAll(',', '.'));
  if (value == null || !value.isFinite) return null;
  final scaled = value * 1000;
  return scaled.isFinite ? scaled.round() : null;
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
  final cleaned = raw.toLowerCase().replaceAll(_gameContextChainPattern, '');
  if (_numeralWordPattern.hasMatch(cleaned)) return CoachBlockRule.unknownNumber;
  final allowed = coachAllowedNumbers(facts);
  for (final m in _numberTokenPattern.allMatches(cleaned)) {
    final scaled = _scaledNumberOf(m.group(0)!);
    if (scaled == null) return CoachBlockRule.unknownNumber;
    if (allowed.contains(scaled)) continue;
    if (_passesCountException(cleaned.substring(m.end), scaled)) continue;
    return CoachBlockRule.unknownNumber;
  }
  return null;
}

/// Lý do chặn một câu trả lời Coach Chat, hoặc `null` nếu cho qua. Chữ tổ
/// hợp sẵn (NFD) bị chặn trước cả mẫu cấm chung — fix round 1, mục 3.
CoachBlockRule? coachReplyBlock(String raw, Map<String, Object?> facts) {
  if (raw.trim().isEmpty) return CoachBlockRule.empty;
  if (_decomposedPattern.hasMatch(raw)) return CoachBlockRule.decomposed;
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
