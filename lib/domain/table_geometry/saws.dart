import 'package:poolcoachai/domain/table_geometry/stroke.dart';

/// Các khoảng cách bi cái → bi mục tiêu (cm) mà bảng SAWS có số liệu.
const sawsRowDistances = <double>[30, 90, 180];

/// Bảng BHE mặc định của chủ sản phẩm, phần trăm: hàng theo
/// [sawsRowDistances], cột Chậm / Vừa / Nhanh. FHE = 100 − BHE. Mỗi cây cơ
/// sẽ cần bảng riêng (hiệu chỉnh trong phần quản lý cơ), nên đây chỉ là
/// mặc định.
const sawsBheTable = <List<int>>[
  [60, 80, 90],
  [40, 70, 85],
  [30, 60, 80],
];

/// Đánh trô bi cộng, đánh cu lê trừ ngần này điểm phần trăm BHE.
const sawsStrokeShift = 10;

/// Cột của bảng cho một mức lực: mức lực gần nhất trong [powerPresets]
/// (30 = Chậm; 45, 60 = Vừa; 75, 90 = Nhanh). Lực lạ lấy mức gần nhất.
int _sawsColumn(double power) {
  var best = 0;
  for (var i = 1; i < powerPresets.length; i++) {
    if ((powerPresets[i] - power).abs() < (powerPresets[best] - power).abs()) {
      best = i;
    }
  }
  return switch (best) { 0 => 0, 1 || 2 => 1, _ => 2 };
}

/// BHE (%) nên dùng để bù áp phê: nội suy tuyến tính theo [distance] giữa
/// các hàng (ngoài hai đầu thì giữ hàng đầu / hàng cuối), chỉnh theo kiểu
/// đánh, kẹp 0..100 rồi làm tròn 5%. Kẹp trước khi làm tròn để kết quả
/// không bao giờ vượt khoảng cho phép.
int sawsBhePercent({
  required double distance,
  required double power,
  required Stroke stroke,
}) {
  final col = _sawsColumn(power);
  final last = sawsRowDistances.length - 1;
  double bhe;
  if (distance <= sawsRowDistances.first) {
    bhe = sawsBheTable.first[col].toDouble();
  } else if (distance >= sawsRowDistances[last]) {
    bhe = sawsBheTable[last][col].toDouble();
  } else {
    var i = 0;
    while (distance > sawsRowDistances[i + 1]) {
      i++;
    }
    final t = (distance - sawsRowDistances[i]) /
        (sawsRowDistances[i + 1] - sawsRowDistances[i]);
    bhe = sawsBheTable[i][col] +
        t * (sawsBheTable[i + 1][col] - sawsBheTable[i][col]);
  }
  bhe += switch (stroke) {
    Stroke.draw => sawsStrokeShift,
    Stroke.follow => -sawsStrokeShift,
    Stroke.stun => 0,
  };
  return ((bhe.clamp(0, 100) / 5).round() * 5);
}
