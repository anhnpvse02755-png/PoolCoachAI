/// Một lần phá của S10: năm tiêu chí a–e (spec mục 5.2).
///
/// a: không chết cái. b–e đều đòi a trước, nên lần phá chết cái được 0 dù
/// các ô khác có đánh dấu.
final class BreakCriteria {
  const BreakCriteria({
    required this.a,
    this.b = false,
    this.c = false,
    this.d = false,
    this.e = false,
  });

  factory BreakCriteria.fromJson(Object? json) {
    if (json is! List || json.length != 5) {
      throw FormatException('Một lần phá phải là mảng 5 giá trị đúng/sai', json);
    }
    final v = [for (final x in json) x as bool];
    return BreakCriteria(a: v[0], b: v[1], c: v[2], d: v[3], e: v[4]);
  }

  final bool a;
  final bool b;
  final bool c;
  final bool d;
  final bool e;

  int get points => a ? 1 + [b, c, d, e].where((x) => x).length : 0;

  List<bool> toJson() => [a, b, c, d, e];

  @override
  bool operator ==(Object other) =>
      other is BreakCriteria &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e;

  @override
  int get hashCode => Object.hash(a, b, c, d, e);

  @override
  String toString() => 'BreakCriteria(${toJson()})';
}

bool _sameList<T>(List<T> x, List<T> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

/// Kết quả thô của một bài: từng cú đúng như người chơi nhập (spec mục 6.1).
///
/// Lưu thô để nếu phát hiện chấm sai một luật BU thì tính lại được.
sealed class DrillAttempts {
  const DrillAttempts();

  factory DrillAttempts.fromJson(Object? json) {
    if (json is! Map) throw FormatException('Kết quả thô phải là object JSON', json);
    final shots = json['shots'];
    if (shots is List) return ShotAttempts([for (final s in shots) s as bool]);
    final counts = json['counts'];
    if (counts is List) return CountAttempts([for (final c in counts) c as int]);
    final breaks = json['breaks'];
    if (breaks is List) {
      return BreakAttempts([for (final b in breaks) BreakCriteria.fromJson(b)]);
    }
    throw FormatException('Kết quả thô không rõ kiểu', json);
  }

  int get length;
  bool get isEmpty => length == 0;

  /// Bỏ lượt cuối — nút *Hoàn tác cú vừa nhập*.
  DrillAttempts withoutLast();

  Map<String, Object?> toJson();
}

/// Mỗi lượt là vào/trượt (thang vị trí và đếm lượt thành công).
final class ShotAttempts extends DrillAttempts {
  ShotAttempts(List<bool> shots) : shots = List.unmodifiable(shots);

  final List<bool> shots;

  @override
  int get length => shots.length;

  ShotAttempts add(bool made) => ShotAttempts([...shots, made]);

  @override
  ShotAttempts withoutLast() =>
      shots.isEmpty ? this : ShotAttempts(shots.sublist(0, shots.length - 1));

  @override
  Map<String, Object?> toJson() => {'shots': shots};

  @override
  bool operator ==(Object other) => other is ShotAttempts && _sameList(shots, other.shots);

  @override
  int get hashCode => Object.hashAll(shots);

  @override
  String toString() => 'ShotAttempts($shots)';
}

/// Mỗi lượt là số bi (lấy lượt cao hơn; cộng hai thế thấp nhất).
final class CountAttempts extends DrillAttempts {
  CountAttempts(List<int> counts) : counts = List.unmodifiable(counts);

  final List<int> counts;

  @override
  int get length => counts.length;

  CountAttempts add(int balls) => CountAttempts([...counts, balls]);

  @override
  CountAttempts withoutLast() =>
      counts.isEmpty ? this : CountAttempts(counts.sublist(0, counts.length - 1));

  @override
  Map<String, Object?> toJson() => {'counts': counts};

  @override
  bool operator ==(Object other) => other is CountAttempts && _sameList(counts, other.counts);

  @override
  int get hashCode => Object.hashAll(counts);

  @override
  String toString() => 'CountAttempts($counts)';
}

/// Mỗi lượt là một lần phá với năm tiêu chí.
final class BreakAttempts extends DrillAttempts {
  BreakAttempts(List<BreakCriteria> breaks) : breaks = List.unmodifiable(breaks);

  final List<BreakCriteria> breaks;

  @override
  int get length => breaks.length;

  BreakAttempts add(BreakCriteria b) => BreakAttempts([...breaks, b]);

  @override
  BreakAttempts withoutLast() =>
      breaks.isEmpty ? this : BreakAttempts(breaks.sublist(0, breaks.length - 1));

  @override
  Map<String, Object?> toJson() => {'breaks': [for (final b in breaks) b.toJson()]};

  @override
  bool operator ==(Object other) => other is BreakAttempts && _sameList(breaks, other.breaks);

  @override
  int get hashCode => Object.hashAll(breaks);

  @override
  String toString() => 'BreakAttempts($breaks)';
}
