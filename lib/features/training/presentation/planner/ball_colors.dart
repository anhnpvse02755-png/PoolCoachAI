import 'package:flutter/painting.dart';

/// Màu bi thật của bộ bi chuẩn: 1 vàng, 2 xanh dương, 3 đỏ, 4 tím, 5 cam,
/// 6 xanh lá, 7 nâu đỏ, 8 đen. Bi 9–15 là bi sọc cùng màu với số trừ 8
/// (bi 10 của 10 bi là sọc xanh dương).
const _solidColors = <Color>[
  Color(0xFFF4C430),
  Color(0xFF1F4FB4),
  Color(0xFFD03030),
  Color(0xFF6B2E8F),
  Color(0xFFF07F1A),
  Color(0xFF1E8A4C),
  Color(0xFF7A1F1F),
  Color(0xFF111111),
];

Color ballColor(int number) => _solidColors[(number > 8 ? number - 8 : number) - 1];

bool isStripe(int number) => number > 8;
