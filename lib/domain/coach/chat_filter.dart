import 'package:poolcoachai/domain/coach/coach_context.dart';

// Lọc sau câu trả lời của Coach Chat (spec Giai đoạn B, luật R1, R3–R6).
// Pure Dart — không import Flutter.

/// Lý do Coach Chat chặn một câu trả lời.
enum CoachBlockRule { empty, decomposed, degree, aimShift, optimal, spinRatio, unknownNumber }

/// Từ chỉ số lượng: một con số 0–10 đứng trước từ này không bị chặn (luật R6).
/// "lựa chọn", "phương án" thêm ở vòng sửa cuối ("Bạn có 2 lựa chọn:" hay
/// đứng trước một danh sách đánh số). Cố ý KHÔNG có "bước": "2 bước" là nói
/// về dữ liệu Lộ trình của người chơi, con số đó phải có trong facts.
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
  'lựa chọn',
  'phương án',
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
/// "triệu chứng" (dấu hiệu) không phải số (M8, review cuối); "hàng chục"
/// thì vẫn là số, vẫn chặn.
final _numeralWordPattern = RegExp(
  r'(?<!\p{L})(?:mười|mươi|trăm|nghìn|ngàn|triệu(?!\s+chứng)|chục|lăm)(?!\p{L})',
  unicode: true,
  caseSensitive: false,
);

/// "phần trăm" là từ chỉ phần trăm, không phải chữ số "trăm" — fix round 2,
/// mục 1. Thay bằng "%" để số đứng trước được kiểm tra đúng như "N%", và để
/// "trăm" không còn khớp [_numeralWordPattern] nữa.
final _percentWordPattern = RegExp(r'phần\s+trăm');

final _aimShiftPattern = RegExp(r'ngắm\s+(lệch|dày hơn|mỏng hơn)');
final _spinRatioPattern = RegExp(r'\b(BHE|FHE)\b', caseSensitive: false);

/// Lượng áp phê nói bằng số đầu cơ ("1 đầu cơ", "0,5 đầu gậy", "nửa đầu
/// cơ"): Coach Chat không bao giờ nói lượng áp phê, kể cả khi con số có trong
/// facts — chỉ Mô phỏng và tình huống Coach nói (M2, review cuối; "nửa" thêm
/// ở vòng sửa cuối). Độ dày chạm bi ("ăn nửa bi") không có "đầu cơ" nên
/// không dính. So trên chữ thường.
final _spinAmountPattern = RegExp(r'(?:\d+(?:[.,]\d+)?|nửa)\s*đầu\s+(?:cơ|gậy)');

/// Khoảng trắng không ngắt dòng (U+00A0, U+202F, U+2007): đọc như dấu cách.
final _noBreakSpacePattern = RegExp(r'[\u00A0\u202F\u2007]');

/// Ký tự vô hình (U+200B–U+200D, U+2060, U+FEFF, gạch nối mềm U+00AD) — có
/// thể chen vào để lách luật chữ (M1, review cuối).
final _invisiblePattern = RegExp(r'[\u200B-\u200D\u2060\uFEFF\u00AD]');

/// Ký tự số không phải 0–9 (toàn chiều rộng, Ả Rập, toán học, số trong vòng
/// tròn, phân số…): luật số chỉ đọc được 0–9, nên gặp là chặn thẳng (fail
/// closed, M1 review cuối).
final _nonAsciiNumberPattern = RegExp(r'(?![0-9])\p{N}', unicode: true);

/// Độ dày chạm bi viết bằng phân số ("Ăn ½ bi") — chữ của chính app
/// (`Vi.safetyThickness`), nên không tính là số lạ ở luật trên. Phân số ở
/// chỗ khác ("½ độ", "½ đầu cơ") vẫn bị chặn.
final _ballFractionPattern = RegExp(r'[¼½¾⅛]\s*bi(?!\p{L})', unicode: true);

/// Dấu đầu dòng của danh sách đánh số ("1. ", "2) " … "10. "): không phải
/// con số cần kiểm với facts (I2b, review cuối). Chỉ ở đầu dòng và có khoảng
/// trắng theo sau, nên "thứ 1." giữa câu hay "1.5 giờ" vẫn bị kiểm.
final _listMarkerPattern = RegExp(r'^\s*(?:[1-9]|10)[.)](?=\s)', multiLine: true);

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
/// chuỗi "N bi và/hay/, N bi") — fix round 1, mục 2; dấu phẩy trong chuỗi
/// thêm ở fix round 2, mục 3 ("Luật 8 bi, 9 bi và 10 bi"); "bi-a" thêm ở
/// review cuối, I2b ("bi-a 9 bi"). Không có ngữ cảnh thì số phải qua kiểm
/// tra như mọi số khác, để không ẩn số bịa (ví dụ "ăn 10 bi"). Không thêm
/// "trong": "ăn 3 trong 9 bi" sẽ giấu mất một mẫu số bịa.
final _gameContextChainPattern = RegExp(
  r'(?:luật|pool|ván|trận|giải|chơi|kiểu|môn|loại|bàn|bi-a)\s+'
  r'(?:(?<![\d.,])(?:8|9|10) bi(?!\p{L})(?:,\s+|\s+(?:và|hay)\s+))*'
  r'(?<![\d.,])(?:8|9|10) bi(?!\p{L})',
  unicode: true,
);

/// Tên môn chơi dạng enum — tên các giá trị `PoolGameType` trong
/// `lib/domain/pool_match.dart`, được serialize bằng `.name` (xem
/// `lib/domain/coach/coach_context.dart`, khoá "gameType"). Dùng để cho số
/// của môn chơi đi qua dù "N bi" ở xa từ ngữ cảnh ván đấu trong câu (ví dụ
/// "Trận gần nhất là 9 bi.") — fix round 2, mục 2.
const _gameTypeNumbers = <String, int>{
  'eightBall': 8,
  'nineBall': 9,
  'tenBall': 10,
};

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
      final gameNumber = _gameTypeNumbers[value];
      if (gameNumber != null) allowed.add(gameNumber * 1000);
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
  final cleaned = raw
      .toLowerCase()
      .replaceAll(_listMarkerPattern, '')
      .replaceAll(_gameContextChainPattern, '')
      .replaceAll(_percentWordPattern, '%');
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

/// Lý do chặn một câu trả lời Coach Chat, hoặc `null` nếu cho qua.
///
/// Trước mọi luật: khoảng trắng không ngắt dòng thành dấu cách, rồi đọc câu
/// theo hai cách — xoá ký tự vô hình (bắt kiểu chen giữa chữ: "tối ư\u00ADu")
/// và thay chúng bằng dấu cách (bắt kiểu thay dấu cách: "tối\u200Bưu"). Chặn
/// nếu một trong hai cách đọc bị chặn (M1, review cuối).
CoachBlockRule? coachReplyBlock(String raw, Map<String, Object?> facts) {
  final spaced = raw.replaceAll(_noBreakSpacePattern, ' ');
  final joined = spaced.replaceAll(_invisiblePattern, '');
  final rule = _replyBlock(joined, facts);
  if (rule != null) return rule;
  final split = spaced.replaceAll(_invisiblePattern, ' ');
  return split == joined ? null : _replyBlock(split, facts);
}

/// Các luật theo thứ tự: rỗng; chữ tổ hợp sẵn (NFD) — fix round 1, mục 3;
/// mẫu cấm chung (độ, rồi ngắm lệch, rồi "tối ưu" — F11); BHE/FHE và lượng
/// áp phê bằng đầu cơ; ký tự số không phải 0–9; số không có trong facts.
CoachBlockRule? _replyBlock(String text, Map<String, Object?> facts) {
  if (text.trim().isEmpty) return CoachBlockRule.empty;
  if (_decomposedPattern.hasMatch(text)) return CoachBlockRule.decomposed;
  final banned = coachBannedRule(text);
  if (banned != null) return banned;
  final lower = text.toLowerCase();
  if (_spinRatioPattern.hasMatch(text) || _spinAmountPattern.hasMatch(lower)) return CoachBlockRule.spinRatio;
  if (_nonAsciiNumberPattern.hasMatch(lower.replaceAll(_ballFractionPattern, ''))) {
    return CoachBlockRule.unknownNumber;
  }
  return _unknownNumberRule(text, facts);
}

/// Lọc câu trả lời Coach Chat: bị chặn thì trả rỗng và `insufficient: true`
/// (luật R5); không thì trả nguyên câu, chỉ bỏ khoảng trắng hai đầu.
CoachChatReply filterCoachReply(String raw, Map<String, Object?> facts) {
  if (coachReplyBlock(raw, facts) != null) return (text: '', insufficient: true);
  return (text: raw.trim(), insufficient: false);
}
