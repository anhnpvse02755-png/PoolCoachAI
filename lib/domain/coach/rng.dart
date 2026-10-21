/// Bộ sinh số Park–Miller ("minimal standard", hệ số 48271), spec mục 8.2.
///
/// `x ← x × 48271 mod (2³¹ − 1)`. Tích lớn nhất nhỏ hơn 2⁴⁷, nên trên web
/// (số Dart là số thực 53 bit) vẫn ra đúng y như trên Android và iOS. Không
/// dùng `dart:math Random`: không có gì bảo đảm thuật toán của nó giống
/// nhau giữa các nền tảng.
class CoachRng {
  /// [seed] được đưa về khoảng 1 … 2³¹ − 2 (0 không phải trạng thái hợp lệ).
  CoachRng(int seed) : _x = _normalize(seed);

  static const modulus = 2147483647; // 2³¹ − 1
  static const multiplier = 48271;

  int _x;

  static int _normalize(int seed) {
    final s = seed % (modulus - 1);
    return s <= 0 ? s + modulus - 1 : s;
  }

  /// Trạng thái hiện tại, 1 … 2³¹ − 2.
  int get state => _x;

  /// Số kế tiếp của chuỗi, 1 … 2³¹ − 2.
  int next() {
    _x = (_x * multiplier) % modulus;
    return _x;
  }

  /// Số thực trong [0, 1).
  double nextDouble() => (next() - 1) / (modulus - 1);

  /// Số thực trong [lo, hi).
  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  /// Số nguyên trong [lo, hi], cả hai đầu.
  int intIn(int lo, int hi) => lo + (nextDouble() * (hi - lo + 1)).floor().clamp(0, hi - lo);

  /// Đúng với xác suất [p].
  bool chance(double p) => nextDouble() < p;
}

/// Seed mới cho tình huống sinh ngẫu nhiên, lấy từ đồng hồ khi bấm "Bắt đầu".
int coachSeedFrom(DateTime now) => now.microsecondsSinceEpoch % (CoachRng.modulus - 2) + 1;
